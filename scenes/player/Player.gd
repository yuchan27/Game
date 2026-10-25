extends CharacterBody2D

const PIXEL := preload("res://scripts/utils/PixelArtFactory.gd")
const PROJECTILE_SCRIPT := preload("res://scripts/components/Projectile.gd")
const ATTACK_FLASH_SCRIPT := preload("res://scripts/components/AttackFlash.gd")
const ASSET_LOADER := preload("res://scripts/utils/RuntimeAssetLoader.gd")
const PLAYER_ATLAS_PATH := "res://assets/sprites/player/recycler_player_multiaction_8dir_preview.png"
const PLAYER_FRAME_DIR := "res://assets/sprites/player/frames"
const PREFER_SPLIT_FRAME_FILES := true
const SPRINT_SPEED_MULTIPLIER := 1.4
const SPRINT_EP_PER_SECOND := 10.0
const EP_REGEN_PER_SECOND := 4.0
const DODGE_DURATION := 0.16
const STRIDE_DISTANCE := 112.0
const MELEE_WINDUP := 0.16
const INPUT_BUFFER_DURATION := 0.12
const SALVAGE_SCAN_RADIUS := 520.0
const SALVAGE_SCAN_MAX_TARGETS := 6
const SALVAGE_SCAN_FLASH_LIFETIME := 1.8
const SALVAGE_SCAN_COOLDOWN := 0.7
const PRESENTATION_PATHS := ["res://data/art/r17_presentation_v2.json", "res://data/art/r17_weapon_families_v2.json"]

@export var move_speed: float = 180.0

enum PlayerState { IDLE, WALK, SHOOT, DRAW_SWORD, SLASH, SWAP_TOOL, INTERACT, HIT, DEAD }

var state := PlayerState.IDLE
var last_direction := Vector2.RIGHT
var attack_timer := 0.0
var ranged_timer := 0.0
var _salvage_scan_timer := 0.0
var action_state_timer := 0.0
var action_state_duration := 0.24
var footstep_timer := 0.0
var slash_combo_step := 0
var slash_combo_reset_timer := 0.0
var current_animation := ""
var has_world_bounds := false
var world_bounds := Rect2()
var camera_base_offset := Vector2.ZERO
var sprite_base_position := Vector2(0, -64)
var shake_timer := 0.0
var shake_strength := 0.0
var weapon_sprite: Sprite2D
var ground_shadow: Polygon2D
var current_weapon_asset_id := ""
var sprint_ep_accumulator := 0.0
var ep_regen_accumulator := 0.0
var dodge_timer := 0.0
var dodge_cooldown := 0.0
var dodge_direction := Vector2.RIGHT
var anim_clock := 0.0
var current_loadout_id := ""
var _loadout_frames_cache: Dictionary = {}
var _step_marks: Array[Dictionary] = []
var _step_side := 1.0
var _hit_flash_timer := 0.0
var _directional_body_frames: Array[Texture2D] = []
var _directional_body_offsets: Array[Vector2] = []
var _directional_hand_offsets: Array[Vector2] = []
var _directional_body_scale := 1.0
var _body_poses: Array[Dictionary] = []
var _salvage_scan_flashes: Array[Node2D] = []
var walk_phase := 0.0
var _pending_melee: Dictionary = {}
var _melee_windup := 0.0
var _melee_buffer := 0.0
var _buffer_mouse_aim := true
var _presentation_families: Dictionary = {}
var _presentation_poses: Dictionary = {}
var _presentation_materials: Dictionary = {}
var _presentation_action_extras: Dictionary = {}
var _presentation_action_angles: Dictionary = {}

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	add_to_group("player")
	add_to_group("map_player")
	set_meta("map_label", "R-17")
	set_meta("map_marker", "player")
	_align_collision_to_feet()

	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite_base_position = sprite.position
	_create_ground_shadow()

	weapon_sprite = Sprite2D.new()
	weapon_sprite.name = "WeaponOverlay"
	weapon_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	weapon_sprite.z_index = 5
	weapon_sprite.centered = true
	weapon_sprite.offset = Vector2(26, 0)
	weapon_sprite.visible = false
	add_child(weapon_sprite)

	camera_base_offset = camera.offset

	if not GameState.feedback_requested.is_connected(_on_feedback_requested):
		GameState.feedback_requested.connect(_on_feedback_requested)

	if not GameState.equipment_changed.is_connected(_update_weapon_overlay):
		GameState.equipment_changed.connect(_update_weapon_overlay)

	_prepare_directional_body()
	_load_presentation_v2()
	_build_sprite_frames()
	_update_weapon_overlay()
	_update_animation()


func _create_ground_shadow() -> void:
	ground_shadow = Polygon2D.new()
	ground_shadow.name = "PlayerGroundShadow"
	ground_shadow.z_index = -2
	var pts := PackedVector2Array()
	for i in range(20):
		var a := float(i) / 20.0 * TAU
		pts.append(Vector2(cos(a) * 26.0, sin(a) * 8.5 - 8.0))
	ground_shadow.polygon = pts
	ground_shadow.color = Color(0.03, 0.02, 0.04, 0.42)
	add_child(ground_shadow)


func _align_collision_to_feet() -> void:
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null or not (collision.shape is CapsuleShape2D):
		return
	var capsule := collision.shape as CapsuleShape2D
	collision.position.y = -capsule.height * 0.5


func _physics_process(delta: float) -> void:
	anim_clock += delta
	_hit_flash_timer = maxf(0.0, _hit_flash_timer - delta)
	for mark in _step_marks:
		mark["age"] = float(mark["age"]) + delta
	_step_marks = _step_marks.filter(func(mark: Dictionary) -> bool: return float(mark["age"]) < 0.3)
	queue_redraw()
	attack_timer = max(0.0, attack_timer - delta)
	_salvage_scan_timer = maxf(0.0, _salvage_scan_timer - delta)
	ranged_timer = max(0.0, ranged_timer - delta)
	action_state_timer = max(0.0, action_state_timer - delta)
	dodge_timer = max(0.0, dodge_timer - delta)
	dodge_cooldown = max(0.0, dodge_cooldown - delta)
	slash_combo_reset_timer = max(0.0, slash_combo_reset_timer - delta)
	if slash_combo_reset_timer <= 0.0:
		slash_combo_step = 0

	var input_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var gameplay_input_blocked := _is_gameplay_input_blocked()
	if gameplay_input_blocked:
		input_direction = Vector2.ZERO
		# A modal can open in the middle of a dodge; its input lock stops the impulse too.
		dodge_timer = 0.0
		_pending_melee.clear()
		_melee_buffer = 0.0

	if state == PlayerState.DEAD:
		velocity = Vector2.ZERO
		_update_weapon_overlay()
		move_and_slide()
		_update_camera_shake(delta)
		_update_animation()
		return

	if dodge_timer > 0.0:
		last_direction = dodge_direction
	elif not _is_action_state_locked():
		_update_locomotion_state(input_direction)
	elif input_direction.length() > 0.05 and not (state in [PlayerState.SHOOT, PlayerState.SLASH, PlayerState.DRAW_SWORD]):
		last_direction = input_direction.normalized()
	var aiming_ranged := state == PlayerState.SHOOT or (GameState.active_attack_mode() == "ranged" and Input.is_action_pressed("primary_attack")) or Input.is_action_pressed("attack_ranged")
	if aiming_ranged and state not in [PlayerState.SLASH, PlayerState.DRAW_SWORD, PlayerState.HIT] and dodge_timer <= 0.0 and not gameplay_input_blocked:
		# Strafing remains independent of aiming between shots.
		last_direction = _aim_direction()

	var speed_bonus: int = GameState.get_stat_bonus("speed")
	var current_speed: float = max(80.0, move_speed + float(speed_bonus))
	if not gameplay_input_blocked and Input.is_action_just_pressed("dash") and input_direction.length() > 0.05 and dodge_cooldown <= 0.0 and GameState.ep >= 6:
		dodge_timer = DODGE_DURATION
		dodge_cooldown = 0.52
		dodge_direction = input_direction.normalized()
		_pending_melee.clear()
		last_direction = dodge_direction
		_add_step_mark(true)
		GameState.ep = max(0, GameState.ep - 6)
		GameState.stats_changed.emit()
		AudioManager.play_sfx("sfx_player_dodge")
		if GameState.has_effective_perk("dodge_blast"):
			_trigger_dodge_blast(global_position)
	var is_sprinting: bool = dodge_timer <= 0.0 and _consume_sprint_energy(input_direction, delta)
	if dodge_timer > 0.0:
		velocity = dodge_direction * (current_speed * 2.15)
	else:
		if is_sprinting:
			current_speed *= SPRINT_SPEED_MULTIPLIER
		else:
			_regenerate_ep(delta)
		velocity = input_direction * current_speed
	move_and_slide()
	if dodge_timer <= 0.0 and velocity.length() > 20.0:
		walk_phase = fposmod(walk_phase + velocity.length() * delta * TAU / STRIDE_DISTANCE, TAU)
	_advance_melee(delta)
	_melee_buffer = maxf(0.0, _melee_buffer - delta)
	if _melee_buffer > 0.0 and attack_timer <= 0.0 and not gameplay_input_blocked:
		_melee_attack(_buffer_mouse_aim)

	if state == PlayerState.WALK and velocity.length() > 20.0:
		footstep_timer += delta
		var interval := 0.22 if is_sprinting else 0.32
		if footstep_timer >= interval:
			footstep_timer = 0.0
			AudioManager.play_sfx("footstep_dust")
			_add_step_mark()
	else:
		footstep_timer = 0.0

	if has_world_bounds:
		global_position = global_position.clamp(world_bounds.position, world_bounds.position + world_bounds.size)

	GameState.player_position = global_position

	if not gameplay_input_blocked and Input.is_action_just_pressed("primary_attack"):
		_primary_attack_pressed()

	if not gameplay_input_blocked and Input.is_action_pressed("primary_attack") and GameState.active_attack_mode() == "ranged":
		_ranged_attack()

	if not gameplay_input_blocked and Input.is_action_just_pressed("attack_melee"):
		_melee_attack(false)

	if not gameplay_input_blocked and (Input.is_action_just_pressed("attack_ranged") or Input.is_action_pressed("attack_ranged")):
		_ranged_attack()

	if not gameplay_input_blocked and Input.is_action_just_pressed("swap_weapon"):
		_set_timed_state(PlayerState.SWAP_TOOL, 0.22)
		AudioManager.play_sfx("ui")
		GameState.use_next_quick_slot()

	for slot_index in range(4):
		if not gameplay_input_blocked and Input.is_action_just_pressed("quick_slot_%d" % [slot_index + 1]):
			_set_timed_state(PlayerState.SWAP_TOOL, 0.22)
			GameState.use_quick_slot(slot_index)

	if Input.is_action_just_pressed("interact"):
		_set_timed_state(PlayerState.INTERACT, 0.18)
		_interact_with_nearest_target(gameplay_input_blocked)

	if not gameplay_input_blocked and Input.is_action_just_pressed("save_game"):
		SaveManager.save_game()

	if not gameplay_input_blocked and Input.is_action_just_pressed("load_game"):
		SaveManager.load_game()

	_update_weapon_overlay()
	_update_camera_shake(delta)
	_update_animation()


func set_world_bounds(bounds: Rect2) -> void:
	world_bounds = bounds
	has_world_bounds = true

	if camera != null:
		camera.limit_left = int(bounds.position.x)
		camera.limit_top = int(bounds.position.y)
		camera.limit_right = int(bounds.position.x + bounds.size.x)
		camera.limit_bottom = int(bounds.position.y + bounds.size.y)
		reset_physics_interpolation()
		camera.reset_smoothing()
		camera.force_update_scroll()


func _is_gameplay_input_blocked() -> bool:
	for blocker: Node in get_tree().get_nodes_in_group("gameplay_input_blocker"):
		if not is_instance_valid(blocker) or not (blocker is Control):
			continue
		if not (blocker as Control).is_visible_in_tree():
			continue
		if bool(blocker.get_meta("gameplay_input_blocked", true)):
			return true
	return false


func _interact_with_nearest_target(gameplay_input_blocked: bool) -> void:
	var dialogue_owner_id := 0
	if gameplay_input_blocked:
		var dialogue_visible := false
		for candidate: Node in get_tree().get_nodes_in_group("dialogue_panel"):
			if candidate is Control and (candidate as Control).is_visible_in_tree():
				dialogue_visible = true
				dialogue_owner_id = int((candidate as Control).get_meta("dialogue_npc_owner_id", 0))
				break
		if not dialogue_visible:
			return
	var nearest := get_nearest_interaction_target(gameplay_input_blocked, dialogue_owner_id)
	if nearest != null and nearest.has_method("interact"):
		nearest.call("interact")


func get_nearest_interaction_target(dialogue_only := false, dialogue_owner_id := 0) -> Node2D:
	# Context hints and E use this same range/filter/order contract.
	var target_group := "dialogue_npc" if dialogue_only else "interactable"
	var nearest: Node2D
	var nearest_distance := INF
	for candidate: Node in get_tree().get_nodes_in_group(target_group):
		if not is_instance_valid(candidate) or not (candidate is Node2D) or not candidate.has_method("can_interact"):
			continue
		if not bool(candidate.call("can_interact")):
			continue
		if dialogue_only and (dialogue_owner_id <= 0 or candidate.get_instance_id() != dialogue_owner_id):
			continue
		if dialogue_only and candidate.has_method("is_dialogue_active") and not bool(candidate.call("is_dialogue_active")):
			continue
		var target := candidate as Node2D
		var distance := global_position.distance_squared_to(target.global_position)
		if distance < nearest_distance:
			nearest = target
			nearest_distance = distance
	return nearest


func _primary_attack_pressed() -> void:
	match GameState.active_attack_mode():
		"ranged":
			_ranged_attack()
		"tool":
			_use_tool_action()
		_:
			_melee_attack(true)


func _melee_attack(use_mouse_aim := true) -> void:
	if state == PlayerState.DEAD or dodge_timer > 0.0:
		return
	if attack_timer > 0.0:
		_melee_buffer = INPUT_BUFFER_DURATION
		_buffer_mouse_aim = use_mouse_aim
		return
	_melee_buffer = 0.0

	if use_mouse_aim:
		last_direction = _aim_direction()

	var weapon_id := GameState.active_attack_item_id()
	var weapon := DataRegistry.get_equipment(weapon_id)

	if String(weapon.get("attack_mode", "melee")) != "melee":
		weapon_id = String(GameState.equipment.get("weapon", "rust_blade"))
		weapon = DataRegistry.get_equipment(weapon_id)

	if slash_combo_reset_timer > 0.0:
		slash_combo_step = (slash_combo_step + 1) % 2
	else:
		slash_combo_step = 0
	slash_combo_reset_timer = 0.85

	var attack_state: int = PlayerState.SLASH if (slash_combo_step == 0) else PlayerState.DRAW_SWORD
	_set_timed_state(attack_state, 0.42)
	attack_timer = float(weapon.get("cooldown", 0.35)) * GameState.get_weapon_cooldown_multiplier(weapon_id)

	var sfx_id := String(weapon.get("sfx_id", "melee"))
	var shake := float(weapon.get("shake_strength", 0.08))
	var vfx_id := String(weapon.get("attack_vfx_id", "slash_rust"))

	var damage := 12 + GameState.get_stat_bonus("attack", weapon_id)
	var reach := float(weapon.get("range", 104.0 if weapon_id == "breaker_hammer" else 92.0))
	var knockback := float(weapon.get("knockback", 150.0))
	_pending_melee = {"damage": damage, "reach": reach, "knockback": knockback, "sfx": sfx_id, "shake": shake, "vfx": vfx_id}
	_melee_windup = MELEE_WINDUP


func _advance_melee(delta: float) -> void:
	if _pending_melee.is_empty():
		return
	if state not in [PlayerState.SLASH, PlayerState.DRAW_SWORD] or dodge_timer > 0.0:
		_pending_melee.clear()
		return
	_melee_windup -= delta
	if _melee_windup > 0.0:
		return
	var strike := _pending_melee.duplicate()
	_pending_melee.clear() # Consume before signals; one strike can resolve only once.
	AudioManager.play_sfx(String(strike["sfx"]))
	GameState.request_feedback("attack", float(strike["shake"]))
	_spawn_attack_flash(String(strike["vfx"]), 1.05, -1.0 if slash_combo_step == 1 else 1.0)
	var damage := int(strike["damage"])
	var reach := float(strike["reach"])
	var knockback := float(strike["knockback"])
	var attack_origin := _attack_anchor_global()
	var attack_direction := last_direction.normalized()
	if attack_direction.length() < 0.1:
		attack_direction = Vector2.RIGHT

	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not (enemy is Node2D):
			continue
		var enemy_center := _enemy_hit_center(enemy)
		var enemy_radius := _enemy_hit_radius(enemy)
		var to_enemy := enemy_center - attack_origin
		var distance := to_enemy.length()
		if distance > reach + enemy_radius:
			continue
		var facing := attack_direction
		if distance > 0.01:
			facing = to_enemy.normalized()
		if attack_direction.dot(facing) > -0.42 and enemy.has_method("take_damage"):
			if enemy.has_method("apply_knockback"):
				enemy.apply_knockback(facing * knockback)
			enemy.take_damage(damage, true)
			if GameState.has_effective_perk("vibro_rend"):
				var rend_dmg := 6 + GameState.get_effective_perk_level("vibro_rend") * 6
				enemy.take_damage(rend_dmg, false)
				if enemy.has_method("apply_knockback"):
					enemy.apply_knockback(facing * 40.0)

func _trigger_dodge_blast(blast_pos: Vector2) -> void:
	var blast_dmg := 14 + GameState.get_effective_perk_level("dodge_blast") * 10
	GameState.request_feedback("attack", 0.12)
	_spawn_attack_flash("slash_spark", 1.2)
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy is Node2D:
			var enemy_node := enemy as Node2D
			var dist := blast_pos.distance_to(enemy_node.global_position)
			if dist <= 100.0:
				var push: Vector2 = (enemy_node.global_position - blast_pos).normalized() * 180.0
				if enemy.has_method("apply_knockback"):
					enemy.apply_knockback(push)
				if enemy.has_method("take_damage"):
					enemy.take_damage(blast_dmg, false)


func _ranged_attack() -> void:
	if ranged_timer > 0.0 or state == PlayerState.DEAD or dodge_timer > 0.0:
		return

	var ranged_id := GameState.active_attack_item_id()
	var ranged := DataRegistry.get_equipment(ranged_id)

	if String(ranged.get("attack_mode", "ranged")) != "ranged":
		ranged_id = String(GameState.equipment.get("ranged", "pipe_rifle"))
		ranged = DataRegistry.get_equipment(ranged_id)

	if not GameState.spend_ammo(1):
		ranged_timer = 0.2 # Holding fire must not flood the HUD with notifications.
		GameState.notify("彈藥不足：按 [Space] 近戰清出空間，或從返村門回村補給。")
		return

	last_direction = _aim_direction()
	_set_timed_state(PlayerState.SHOOT, 0.24)

	var sfx_id := String(ranged.get("sfx_id", "shoot"))
	var shake := float(ranged.get("shake_strength", 0.06))
	var vfx_id := String(ranged.get("attack_vfx_id", "muzzle_pipe"))

	AudioManager.play_sfx(sfx_id)
	GameState.request_feedback("attack", shake)
	_spawn_attack_flash(vfx_id, 0.92)

	ranged_timer = float(ranged.get("cooldown", 0.35)) * GameState.get_weapon_cooldown_multiplier(ranged_id)

	var projectile_damage := 10 + GameState.get_stat_bonus("attack", ranged_id)
	var projectile_count := clampi(int(ranged.get("projectile_count", 1)), 1, 6)
	var spread_deg := float(ranged.get("spread_deg", 0.0))
	if projectile_count > 1:
		projectile_damage = max(4, int(round(float(projectile_damage) * 0.55)))
	var projectile_start := _projectile_spawn_global()
	var pools := get_tree().get_nodes_in_group("projectile_pool")

	var any_fired := false
	for pellet_idx in range(projectile_count):
		var angle_offset := 0.0
		if projectile_count > 1:
			var ratio := float(pellet_idx) / float(projectile_count - 1) - 0.5
			angle_offset = deg_to_rad(ratio * spread_deg)
		var shot_dir := last_direction.rotated(angle_offset)
		if not pools.is_empty() and pools[0].has_method("fire_projectile"):
			if pools[0].fire_projectile(projectile_start, shot_dir, projectile_damage):
				any_fired = true
		else:
			var projectile: Area2D = PROJECTILE_SCRIPT.new()
			projectile.setup(projectile_start, shot_dir, projectile_damage)
			get_tree().current_scene.add_child(projectile)
			any_fired = true
	if not any_fired and not pools.is_empty():
		GameState.refund_ammo(1)


func _use_tool_action() -> void:
	if state == PlayerState.DEAD or GameState.death_pending or GameState.hp <= 0 or dodge_timer > 0.0 or attack_timer > 0.0 or ranged_timer > 0.0 or _salvage_scan_timer > 0.0 or _is_action_state_locked():
		return
	if GameState.current_scene_id != "wasteland":
		GameState.notify("回收掃描僅在荒野出擊時使用；村莊或公會可至工坊整備。")
		return

	_salvage_scan_timer = SALVAGE_SCAN_COOLDOWN
	_set_timed_state(PlayerState.INTERACT, 0.20)

	var tool := DataRegistry.get_equipment(GameState.active_attack_item_id())

	AudioManager.play_sfx(String(tool.get("sfx_id", "interact")))
	_spawn_attack_flash(String(tool.get("attack_vfx_id", "scan_pulse")), 0.8)
	var targets := _nearby_salvage_targets()
	_present_salvage_scan(targets)
	if targets.is_empty():
		GameState.notify("掃描範圍內未發現可拾取物資或未採集資源點。")
		return
	var nearest_label := String(targets[0].get_meta("map_label", "附近物資"))
	GameState.notify("掃描到 %d 處附近物資（最近：%s）；短暫脈衝已標示。靠近即可拾取，採集點按 E；M 查看地圖。" % [targets.size(), nearest_label])


func _nearby_salvage_targets() -> Array[Node2D]:
	var targets: Array[Node2D] = []
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return targets
	var scene: Node = tree.current_scene
	var candidates: Array[Node] = []
	candidates.append_array(tree.get_nodes_in_group("pickup"))
	candidates.append_array(tree.get_nodes_in_group("harvestable_node"))
	var nearby: Array[Dictionary] = []
	var radius_squared := SALVAGE_SCAN_RADIUS * SALVAGE_SCAN_RADIUS
	for candidate in candidates:
		if not is_instance_valid(candidate) or not candidate is Node2D:
			continue
		var target := candidate as Node2D
		if not scene.is_ancestor_of(target) or not target.is_inside_tree() or target.is_queued_for_deletion() or not target.is_visible_in_tree():
			continue
		if target.is_in_group("pickup") and bool(target.get("collected")):
			continue
		if target.is_in_group("harvestable_node") and bool(target.get("harvested")):
			continue
		var source_key := String(target.get("source_key"))
		if not source_key.is_empty() and GameState.has_run_source(source_key):
			continue
		var distance_squared := global_position.distance_squared_to(target.global_position)
		if distance_squared > radius_squared:
			continue
		nearby.append({"target": target, "distance_squared": distance_squared})
	nearby.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["distance_squared"]) < float(b["distance_squared"])
	)
	for index in range(mini(nearby.size(), SALVAGE_SCAN_MAX_TARGETS)):
		targets.append(nearby[index]["target"] as Node2D)
	return targets


func _present_salvage_scan(targets: Array[Node2D]) -> void:
	for flash in _salvage_scan_flashes:
		if is_instance_valid(flash):
			flash.queue_free()
	_salvage_scan_flashes.clear()
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return
	for target in targets:
		if _salvage_scan_flashes.size() >= SALVAGE_SCAN_MAX_TARGETS:
			break
		if not is_instance_valid(target) or not target.is_inside_tree() or target.is_queued_for_deletion():
			continue
		if not tree.current_scene.is_ancestor_of(target) or (not target.is_in_group("pickup") and not target.is_in_group("harvestable_node")):
			continue
		var flash: Node2D = ATTACK_FLASH_SCRIPT.new()
		flash.setup("scan_pulse", Vector2.UP, 1.1)
		flash.lifetime = SALVAGE_SCAN_FLASH_LIFETIME
		flash.z_index = 4
		target.add_child(flash)
		flash.position = Vector2.ZERO
		_salvage_scan_flashes.append(flash)


func _aim_direction() -> Vector2:
	return _aim_direction_from_global_target(get_global_mouse_position())


func _aim_direction_from_global_target(target: Vector2) -> Vector2:
	var aim := target - _attack_anchor_global()

	if aim.length() < 8.0:
		aim = last_direction

	if aim.length() < 0.05:
		return Vector2.RIGHT

	return aim.normalized()


func _direction_index() -> int:
	var angle := last_direction.angle()
	return int(round(angle / (PI / 4.0))) & 7


func _loadout_atlas_path(loadout_key: String) -> String:
	match loadout_key:
		"heavy":
			return "res://assets/sprites/player/r17_loadout_heavy.png"
		"rifle":
			return "res://assets/sprites/player/r17_loadout_rifle.png"
		_:
			return "res://assets/sprites/player/r17_loadout_blade.png"


func _get_or_build_loadout_frames(loadout_key: String) -> SpriteFrames:
	if _loadout_frames_cache.has(loadout_key):
		return _loadout_frames_cache[loadout_key] as SpriteFrames

	var frames := SpriteFrames.new()
	var frame_size := PixelArtFactory.PLAYER_FRAME_SIZE
	var has_anim30 := true
	var body_sheet: Texture2D = null
	if _directional_body_frames.is_empty():
		body_sheet = ASSET_LOADER.load_png("res://assets/sprites/player/anim30/%s/idle.png" % loadout_key)

	for action_index in range(PixelArtFactory.PLAYER_ACTIONS.size()):
		var action_name := String(PixelArtFactory.PLAYER_ACTIONS[action_index])
		var anim30_path := "res://assets/sprites/player/anim30/%s/%s.png" % [loadout_key, action_name]
		var use_authored_body := _directional_body_frames.size() == 8 and action_name != "dead"
		var action_sheet: Texture2D = null
		if not use_authored_body:
			action_sheet = body_sheet if _uses_directional_body(action_name) else ASSET_LOADER.load_png(anim30_path)
		# The existing walk strip cycles through front AND rear reference poses, and
		# combat strips rotate one side pose. Use the actual turnaround rows instead;
		# native stance/weapon motion below supplies movement without a false turn.
		if action_sheet == null and not use_authored_body:
			action_sheet = ASSET_LOADER.load_png(anim30_path)

		if action_sheet == null and not use_authored_body:
			has_anim30 = false
			break

		for direction_index in range(8):
			var animation_name := "%s_%d" % [action_name, direction_index]
			frames.add_animation(animation_name)
			var anim_fps := 30.0
			if action_name in ["slash", "draw_sword"]:
				anim_fps = 36.0
			frames.set_animation_speed(animation_name, anim_fps)
			frames.set_animation_loop(animation_name, action_name in ["idle", "walk"])

			for frame_index in range(3 if use_authored_body and _body_poses.size() == 3 else (1 if use_authored_body else 30)):
				if use_authored_body:
					frames.add_frame(animation_name, _body_poses[frame_index]["frames"][direction_index])
					continue
				var atlas_tex := AtlasTexture.new()
				atlas_tex.atlas = action_sheet
				atlas_tex.region = Rect2(frame_index * frame_size.x, direction_index * frame_size.y, frame_size.x, frame_size.y)
				frames.add_frame(animation_name, atlas_tex)

	if not has_anim30:
		frames = _build_legacy_8frame_loadout(loadout_key)

	_add_presentation_frames(frames, loadout_key)
	_loadout_frames_cache[loadout_key] = frames
	set_meta("animation_source", "authored_8view_with_native_pose" if _directional_body_frames.size() == 8 else ("directional_turnaround_with_native_pose" if has_anim30 else "legacy_8frame"))
	return frames


func _load_presentation_v2() -> void:
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; uniform float alpha_cutoff=0.96; varying vec4 tint; void vertex(){tint=COLOR;} void fragment(){vec4 pixel=texture(TEXTURE,UV); if(pixel.a<alpha_cutoff){discard;} COLOR=vec4(pixel.rgb,1.0)*tint;}"
	for path in PRESENTATION_PATHS:
		if not FileAccess.file_exists(path):
			continue
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not parsed is Dictionary:
			continue
		for family_id in parsed.get("families", {}):
			var family: Dictionary = parsed["families"][family_id]
			if not bool(family.get("enabled", true)):
				continue
			var angles: Array = family.get("facing_angles", [])
			var poses: Dictionary = {}
			for key in family.get("keys", {}):
				var entry: Dictionary = family["keys"][key]
				var atlas := ASSET_LOADER.load_png(String(entry.get("path", "")))
				var cells: Array = entry.get("cells", [])
				if atlas == null or angles.is_empty() or cells.size() != angles.size():
					continue
				var views: Array[Dictionary] = []
				for cell in cells:
					if not cell is Array or cell.size() < 9 or float(cell[8]) <= 0.0:
						break
					var region := Rect2(float(cell[0]), float(cell[1]), float(cell[2]), float(cell[3]))
					if not Rect2(Vector2.ZERO, atlas.get_size()).encloses(region):
						break
					var texture := AtlasTexture.new()
					texture.atlas = atlas
					texture.region = region
					var sole := Vector2(float(cell[4]), float(cell[5]))
					var view := {"texture": texture, "offset": region.get_center() - sole, "scale": 96.0 / float(cell[8]), "hand": Vector2(float(cell[6]), float(cell[7])) - sole}
					if cell.size() >= 11:
						view["muzzle"] = Vector2(float(cell[9]), float(cell[10])) - sole
					views.append(view)
				if views.size() == angles.size():
					poses[key] = views
			var valid := not poses.is_empty()
			for sequence in family.get("actions", {}).values():
				if not sequence is Array or sequence.is_empty():
					valid = false
					break
				for key in sequence:
					if not poses.has(key):
						valid = false
			if valid:
				_presentation_families[family_id] = family
				_presentation_poses[family_id] = poses
				var action_extras := _load_presentation_action_extras(family)
				if not action_extras.is_empty():
					_presentation_action_extras[family_id] = action_extras
				var action_angles: Dictionary = {}
				for action_name in family["actions"]:
					var combined_angles: Array = angles.duplicate()
					for extra in action_extras.get(action_name, []):
						combined_angles.append(float(extra["angle"]))
					action_angles[action_name] = combined_angles
				_presentation_action_angles[family_id] = action_angles
				var material := ShaderMaterial.new()
				material.shader = shader
				material.set_shader_parameter("alpha_cutoff", float(family.get("alpha_cutoff", parsed.get("alpha_cutoff", 0.96))))
				_presentation_materials[family_id] = material


func _load_presentation_action_extras(family: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var raw_actions = family.get("additional_action_facings", {})
	var actions: Dictionary = family.get("actions", {})
	var base_angles: Array = family.get("facing_angles", [])
	if not raw_actions is Dictionary:
		return result
	var base_paths: Array[String] = []
	for raw_key in family.get("keys", {}).values():
		if raw_key is Dictionary:
			var base_path := String(raw_key.get("path", "")).to_lower()
			if not base_path.is_empty():
				base_paths.append(base_path)

	for action_value in raw_actions:
		var action_name := String(action_value)
		if not actions.has(action_name):
			continue
		var sequence = actions[action_name]
		var raw_extras = raw_actions[action_value]
		if not sequence is Array or sequence.is_empty() or not raw_extras is Array:
			continue

		var accepted: Array[Dictionary] = []
		var used_angles: Array = base_angles.duplicate()
		for raw_extra in raw_extras:
			if not raw_extra is Dictionary or not bool(raw_extra.get("enabled", false)):
				continue
			var angle_value = raw_extra.get("angle", null)
			if typeof(angle_value) not in [TYPE_INT, TYPE_FLOAT]:
				continue
			var angle := float(angle_value)
			if not is_finite(angle) or angle < 0.0 or angle >= 360.0 or _presentation_angle_is_listed(used_angles, angle):
				continue
			var raw_frames = raw_extra.get("frames", [])
			if not raw_frames is Array or raw_frames.size() != sequence.size():
				continue

			var views: Array[Dictionary] = []
			var valid_extra := true
			for raw_frame in raw_frames:
				if not raw_frame is Dictionary:
					valid_extra = false
					break
				if base_paths.has(String(raw_frame.get("path", "")).to_lower()):
					valid_extra = false
					break
				var view := _load_presentation_extra_view(raw_frame)
				if view.is_empty():
					valid_extra = false
					break
				views.append(view)
			if not valid_extra:
				continue
			accepted.append({"angle": angle, "views": views})
			used_angles.append(angle)

		if not accepted.is_empty():
			result[action_name] = accepted
	return result


func _load_presentation_extra_view(frame: Dictionary) -> Dictionary:
	var path_value = frame.get("path", "")
	if typeof(path_value) != TYPE_STRING or String(path_value).is_empty():
		return {}
	var atlas := ASSET_LOADER.load_png(String(path_value))
	var cell = frame.get("cell", [])
	if atlas == null or not cell is Array or cell.size() not in [9, 11]:
		return {}
	for value in cell:
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)):
			return {}

	var region := Rect2(float(cell[0]), float(cell[1]), float(cell[2]), float(cell[3]))
	if region.size.x <= 0.0 or region.size.y <= 0.0 or float(cell[8]) <= 0.0 or not Rect2(Vector2.ZERO, atlas.get_size()).encloses(region):
		return {}
	var sole := Vector2(float(cell[4]), float(cell[5]))
	var hand := Vector2(float(cell[6]), float(cell[7]))
	if not _presentation_anchor_in_region(sole, region) or not _presentation_anchor_in_region(hand, region):
		return {}

	var texture := AtlasTexture.new()
	texture.atlas = atlas
	texture.region = region
	var view := {"texture": texture, "offset": region.get_center() - sole, "scale": 96.0 / float(cell[8]), "hand": hand - sole}
	if cell.size() == 11:
		var muzzle := Vector2(float(cell[9]), float(cell[10]))
		if not _presentation_anchor_in_region(muzzle, region):
			return {}
		view["muzzle"] = muzzle - sole
	return view


func _presentation_anchor_in_region(anchor: Vector2, region: Rect2) -> bool:
	var region_end := region.position + region.size
	return anchor.x >= region.position.x and anchor.x <= region_end.x and anchor.y >= region.position.y and anchor.y <= region_end.y


func _presentation_angle_is_listed(angles: Array, candidate: float) -> bool:
	for value in angles:
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)):
			continue
		if absf(angle_difference(deg_to_rad(float(value)), deg_to_rad(candidate))) < 0.0001:
			return true
	return false


func _presentation_angles_for_action(family_id: String, action_name: String) -> Array:
	# All callers have a validated family/action; build the arrays once at load.
	return _presentation_action_angles[family_id][action_name]


func _add_presentation_frames(frames: SpriteFrames, family_id: String) -> void:
	if not _presentation_families.has(family_id):
		return
	var family: Dictionary = _presentation_families[family_id]
	for action in family["actions"]:
		var action_name := String(action)
		var sequence: Array = family["actions"][action_name]
		var base_angles: Array = family["facing_angles"]
		var action_angles := _presentation_angles_for_action(family_id, action_name)
		var extras_by_action: Dictionary = _presentation_action_extras.get(family_id, {})
		var action_extras: Array = extras_by_action.get(action_name, [])
		for facing in action_angles.size():
			var animation := "%s_v2_%d" % [action_name, facing]
			frames.add_animation(animation)
			frames.set_animation_loop(animation, action_name in ["idle", "walk"])
			if facing < base_angles.size():
				for key in sequence:
					frames.add_frame(animation, _presentation_poses[family_id][key][facing]["texture"])
			else:
				var extra: Dictionary = action_extras[facing - base_angles.size()]
				for view in extra["views"]:
					frames.add_frame(animation, view["texture"])


func _presentation_action_name() -> String:
	return ["idle", "walk", "shoot", "draw_sword", "slash", "swap_tool", "interact", "hit", "dead"][state]


func _uses_presentation_v2() -> bool:
	return _presentation_families.has(current_loadout_id) and _presentation_families[current_loadout_id]["actions"].has(_presentation_action_name())


func _presentation_facing_index() -> int:
	var angles := _presentation_angles_for_action(current_loadout_id, _presentation_action_name())
	var facing := 0
	var nearest := INF
	for index in angles.size():
		var distance := absf(angle_difference(last_direction.angle(), deg_to_rad(float(angles[index]))))
		if distance < nearest:
			nearest = distance
			facing = index
	return facing


func _presentation_key_index() -> int:
	var family: Dictionary = _presentation_families[current_loadout_id]
	var sequence: Array = family["actions"][_presentation_action_name()]
	var timings: Array = family.get("action_timing_seconds", {}).get(_presentation_action_name(), [])
	if state != PlayerState.WALK and timings.size() == sequence.size():
		var elapsed := action_state_duration - action_state_timer
		var end := 0.0
		for index in timings.size():
			end += maxf(0.0, float(timings[index]))
			if elapsed < end:
				return index
		return sequence.size() - 1
	var progress := fposmod(walk_phase, TAU) / TAU if state == PlayerState.WALK else clampf(1.0 - action_state_timer / maxf(0.05, action_state_duration), 0.0, 0.9999)
	return mini(int(progress * sequence.size()), sequence.size() - 1)


func _presentation_pose() -> Dictionary:
	if not _uses_presentation_v2():
		return {}
	var family: Dictionary = _presentation_families[current_loadout_id]
	var action_name := _presentation_action_name()
	var sequence: Array = family["actions"][action_name]
	var key_index := _presentation_key_index()
	var facing := _presentation_facing_index()
	var base_angle_count: int = family["facing_angles"].size()
	if facing < base_angle_count:
		return _presentation_poses[current_loadout_id][sequence[key_index]][facing]
	var extras_by_action: Dictionary = _presentation_action_extras.get(current_loadout_id, {})
	var action_extras: Array = extras_by_action.get(action_name, [])
	var extra_index := facing - base_angle_count
	if extra_index >= 0 and extra_index < action_extras.size():
		var views: Array = action_extras[extra_index]["views"]
		if key_index >= 0 and key_index < views.size():
			return views[key_index]
	return {}


func _prepare_directional_body() -> void:
	_body_poses.clear()
	for id in ["player_r17", "player_r17_walk_a", "player_r17_walk_b"]:
		var pose := _load_body_pose(DataRegistry.get_visual_asset(id), "directional_body_path" if id == "player_r17" else "directional_path")
		if pose.is_empty():
			break
		_body_poses.append(pose)
	if _body_poses.is_empty():
		return
	_directional_body_frames.assign(_body_poses[0]["frames"])
	_directional_body_offsets.assign(_body_poses[0]["offsets"])
	_directional_hand_offsets.assign(_body_poses[0]["hands"])
	_directional_body_scale = float(_body_poses[0]["scales"][0])
	set_meta("directional_body_source", DataRegistry.get_visual_asset("player_r17").get("directional_body_path", ""))
	set_meta("directional_body_views", 8)
	set_meta("walk_keypose_count", _body_poses.size())


func _load_body_pose(asset: Dictionary, path_key: String) -> Dictionary:
	var rects: Array = asset.get("directional_rects", [])
	var feet: Array = asset.get("directional_feet", [])
	var hands: Array = asset.get("directional_hands", [])
	if rects.size() != 8 or feet.size() != 8 or hands.size() != 8:
		return {}
	var atlas := ASSET_LOADER.load_png(String(asset.get(path_key, "")))
	if atlas == null:
		return {}
	var pose := {"frames": [], "offsets": [], "hands": [], "scales": []}
	for i in range(8):
		var r: Array = rects[i]
		var region := Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
		if not Rect2(Vector2.ZERO, atlas.get_size()).encloses(region):
			return {}
		var texture := AtlasTexture.new()
		texture.atlas = atlas
		texture.region = region
		var sole := Vector2(float(feet[i][0]), float(feet[i][1]))
		var hand := Vector2(float(hands[i][0]), float(hands[i][1]))
		pose["frames"].append(texture)
		pose["offsets"].append(region.get_center() - sole)
		pose["hands"].append(hand - sole)
		# Normalize each key's head-to-ground height, not its cape width.
		pose["scales"].append(92.0 / maxf(1.0, sole.y - region.position.y))
	return pose


func _body_pose_index() -> int:
	if _body_poses.size() < 3 or velocity.length() <= 20.0 or dodge_timer > 0.0 or state not in [PlayerState.WALK, PlayerState.SHOOT]:
		return 0
	return [0, 1, 0, 2][int(fposmod(walk_phase, TAU) / TAU * 4.0)]


func _body_pose_scale() -> float:
	return float(_body_poses[_body_pose_index()]["scales"][_direction_index()]) if not _body_poses.is_empty() else 1.0


func _body_pose_offset() -> Vector2:
	return _body_poses[_body_pose_index()]["offsets"][_direction_index()] if not _body_poses.is_empty() else Vector2.ZERO


func _uses_directional_body(action_name: String) -> bool:
	return action_name in ["walk", "shoot", "draw_sword", "slash", "hit"]


func _build_legacy_8frame_loadout(loadout_key: String) -> SpriteFrames:
	var frames := SpriteFrames.new()
	var atlas_path := _loadout_atlas_path(loadout_key)
	var atlas: Texture2D = ASSET_LOADER.load_png(atlas_path)

	for action_index in range(PixelArtFactory.PLAYER_ACTIONS.size()):
		var action_name := String(PixelArtFactory.PLAYER_ACTIONS[action_index])

		for direction_index in range(8):
			var animation_name := "%s_%d" % [action_name, direction_index]
			var source_direction_index := _source_direction_index(action_name, direction_index)

			frames.add_animation(animation_name)
			var anim_fps := 14.0
			if action_name == "walk":
				anim_fps = 12.0
			elif action_name == "idle":
				anim_fps = 8.0
			elif action_name == "slash":
				anim_fps = 22.0
			elif action_name in ["draw_sword", "shoot"]:
				anim_fps = 18.0
			frames.set_animation_speed(animation_name, anim_fps)
			frames.set_animation_loop(animation_name, action_name in ["idle", "walk"])

			for frame_index in range(PixelArtFactory.PLAYER_FRAMES_PER_ACTION):
				var tex: Texture2D = null

				if PREFER_SPLIT_FRAME_FILES and loadout_key == "blade":
					tex = _split_frame_texture(action_name, source_direction_index, frame_index)

				if tex != null:
					frames.add_frame(animation_name, tex)
				elif atlas != null:
					frames.add_frame(animation_name, _atlas_frame(atlas, action_index, source_direction_index, frame_index))
				else:
					frames.add_frame(animation_name, PIXEL.new().player_texture(source_direction_index, action_index, frame_index))

	return frames


func _active_loadout_key() -> String:
	var mode := GameState.active_attack_mode()
	if mode == "ranged":
		return "rifle"
	return _melee_loadout_key(GameState.active_attack_item_id())


func _melee_loadout_key(item_id: String) -> String:
	if item_id in ["breaker_hammer", "melee_axe", "power_hammer", "seismic_hammer", "heavy_wrench", "breacher_axe", "scrap_axe"]:
		return "heavy"
	return "blade"


func _apply_loadout(loadout_key: String) -> void:
	current_loadout_id = loadout_key
	var frames := _get_or_build_loadout_frames(loadout_key)
	sprite.sprite_frames = frames
	if not current_animation.is_empty() and frames.has_animation(current_animation):
		sprite.play(current_animation)


func _build_sprite_frames() -> void:
	_apply_loadout(_active_loadout_key())


func _source_direction_index(_action_name: String, direction_index: int) -> int:
	# The atlas row order is the single source of truth.
	# Do not swap rows here; swapping rows caused right-down to display as left-down.
	return direction_index


func _split_frame_texture(action_name: String, direction_index: int, frame_index: int) -> Texture2D:
	var path := "%s/%s/dir_%d/frame_%d.png" % [PLAYER_FRAME_DIR, action_name, direction_index, frame_index]
	return ASSET_LOADER.load_png(path)


func _atlas_frame(atlas: Texture2D, action_index: int, direction_index: int, frame_index: int) -> AtlasTexture:
	var frame_size := PixelArtFactory.PLAYER_FRAME_SIZE
	var texture := AtlasTexture.new()
	texture.atlas = atlas
	texture.region = Rect2((action_index * PixelArtFactory.PLAYER_FRAMES_PER_ACTION + frame_index) * frame_size.x, direction_index * frame_size.y, frame_size.x, frame_size.y)
	return texture


func _update_animation() -> void:
	var direction_index := _direction_index()
	var action_name := _presentation_action_name()

	var next_animation := "%s_%d" % [action_name, direction_index]
	if _uses_presentation_v2():
		next_animation = "%s_v2_%d" % [action_name, _presentation_facing_index()]

	if current_animation != next_animation:
		var preserve_stride := state == PlayerState.WALK and current_animation.begins_with("walk_")
		var previous_frame := sprite.frame
		var previous_progress := sprite.frame_progress
		current_animation = next_animation
		sprite.play(current_animation)
		if preserve_stride:
			sprite.set_frame_and_progress(previous_frame, previous_progress)
	if _uses_presentation_v2():
		sprite.pause()
		sprite.set_frame_and_progress(_presentation_key_index(), 0.0)
		return
	if not _body_poses.is_empty() and state != PlayerState.DEAD:
		sprite.pause()
		sprite.set_frame_and_progress(_body_pose_index(), 0.0)
		return
	if state != PlayerState.DEAD:
		# Finish a timed action's full strip before returning to locomotion.
		var frame_count := sprite.sprite_frames.get_frame_count(current_animation)
		var fps := sprite.sprite_frames.get_animation_speed(current_animation)
		sprite.speed_scale = float(frame_count) / maxf(0.05, action_state_duration) / fps if _is_action_state_locked() else 1.0
	else:
		sprite.speed_scale = 1.0


func _update_locomotion_state(input_direction: Vector2) -> void:
	if input_direction.length() > 0.05:
		last_direction = input_direction.normalized()
		state = PlayerState.WALK
	else:
		state = PlayerState.IDLE


func _consume_sprint_energy(input_direction: Vector2, delta: float) -> bool:
	if input_direction.length() <= 0.05:
		sprint_ep_accumulator = 0.0
		return false
	if not Input.is_action_pressed("dash"):
		sprint_ep_accumulator = 0.0
		return false
	if GameState.ep <= 0:
		sprint_ep_accumulator = 0.0
		return false

	ep_regen_accumulator = 0.0
	sprint_ep_accumulator += SPRINT_EP_PER_SECOND * delta
	var drain_amount: int = int(floor(sprint_ep_accumulator))
	if drain_amount > 0:
		drain_amount = min(drain_amount, GameState.ep)
		GameState.ep = max(0, GameState.ep - drain_amount)
		sprint_ep_accumulator -= float(drain_amount)
		GameState.stats_changed.emit()

	return GameState.ep > 0


func _regenerate_ep(delta: float) -> void:
	var max_ep: int = GameState.get_max_ep()
	if GameState.ep >= max_ep:
		ep_regen_accumulator = 0.0
		if GameState.ep > max_ep:
			GameState.ep = max_ep
			GameState.stats_changed.emit()
		return

	ep_regen_accumulator += EP_REGEN_PER_SECOND * delta
	var recover_amount: int = int(floor(ep_regen_accumulator))
	if recover_amount <= 0:
		return

	var old_ep: int = GameState.ep
	GameState.ep = min(max_ep, GameState.ep + recover_amount)
	ep_regen_accumulator -= float(recover_amount)
	if GameState.ep != old_ep:
		GameState.stats_changed.emit()


func _set_timed_state(next_state: int, duration: float) -> void:
	state = next_state
	action_state_duration = max(0.05, duration)
	action_state_timer = action_state_duration
	if next_state not in [PlayerState.SLASH, PlayerState.DRAW_SWORD]:
		_pending_melee.clear()
	if next_state in [PlayerState.DEAD, PlayerState.HIT, PlayerState.SWAP_TOOL]:
		_melee_buffer = 0.0
	current_animation = ""


func _is_action_state_locked() -> bool:
	return action_state_timer > 0.0 and state in [PlayerState.SHOOT, PlayerState.DRAW_SWORD, PlayerState.SLASH, PlayerState.SWAP_TOOL, PlayerState.INTERACT, PlayerState.HIT, PlayerState.DEAD]


func _get_weapon_muzzle_offset(dir_index: int) -> Vector2:
	match dir_index:
		0: return Vector2(28, -62)   # Right (E)
		1: return Vector2(26, -58)   # Down-Right (SE)
		2: return Vector2(24, -56)   # Down (S)
		3: return Vector2(-24, -56)  # Down-Left (SW)
		4: return Vector2(-28, -62)  # Left (W)
		5: return Vector2(-22, -72)  # Up-Left (NW)
		6: return Vector2(18, -74)   # Up (N)
		7: return Vector2(22, -72)   # Up-Right (NE)
		_: return Vector2(26, -60)


func _attack_anchor_global() -> Vector2:
	return to_global(_weapon_hand_local())


func _weapon_hand_local() -> Vector2:
	var pose := _presentation_pose()
	if not pose.is_empty():
		return sprite.transform * (pose["hand"] as Vector2)
	if _directional_hand_offsets.size() == 8 and state != PlayerState.DEAD:
		return Vector2(0, -8) + (_body_poses[_body_pose_index()]["hands"][_direction_index()] as Vector2) * _body_pose_scale()
	return Vector2(0, -62)


func _projectile_spawn_global() -> Vector2:
	_update_weapon_overlay()
	var pose := _presentation_pose()
	if pose.has("muzzle"):
		return sprite.to_global(pose["muzzle"])
	if weapon_sprite != null and weapon_sprite.visible:
		# The overlays share their hilt at x=22 and muzzle at x=80 (offset +26).
		return weapon_sprite.to_global(Vector2(58, 0))
	var direction := last_direction.normalized()
	if direction.length() < 0.1:
		direction = Vector2.RIGHT
	return _attack_anchor_global() + direction * 46.0


func _spawn_attack_flash(effect_id: String, strength: float, combo_sign := 1.0) -> void:
	if get_tree() == null or get_tree().current_scene == null:
		return
	var flash: Node2D = ATTACK_FLASH_SCRIPT.new()
	flash.setup(effect_id, last_direction, strength, combo_sign)
	if state in [PlayerState.SLASH, PlayerState.DRAW_SWORD]:
		flash.lifetime = action_state_duration
		flash.age = action_state_duration - action_state_timer
	flash.z_index = -1 if last_direction.y < -0.2 else 4
	if effect_id.begins_with("muzzle"):
		flash.global_position = _projectile_spawn_global()
	else:
		flash.global_position = _attack_anchor_global() + last_direction * 12.0
	get_tree().current_scene.add_child(flash)


func get_hit_center() -> Vector2:
	return global_position + Vector2(0, -42)


func get_hit_radius() -> float:
	return 34.0


func _enemy_hit_center(enemy: Node) -> Vector2:
	if enemy.has_method("get_hit_center"):
		return enemy.call("get_hit_center")
	if enemy is Node2D:
		return enemy.global_position
	return global_position


func _enemy_hit_radius(enemy: Node) -> float:
	if enemy.has_method("get_hit_radius"):
		return float(enemy.call("get_hit_radius"))
	return 32.0


func _update_weapon_overlay() -> void:
	var dir_vec := last_direction.normalized()
	if dir_vec.length() < 0.1:
		dir_vec = Vector2.RIGHT

	# Presentation moves the artwork only; the foot collision and saved position stay fixed.
	var progress := clampf(1.0 - (action_state_timer / maxf(0.05, action_state_duration)), 0.0, 1.0)
	sprite.position = sprite_base_position
	sprite.scale = Vector2.ONE
	sprite.rotation = 0.0
	sprite.offset = Vector2.ZERO
	sprite.material = null
	sprite.modulate = Color.WHITE.lerp(Color(1.0, 0.52, 0.38), clampf(_hit_flash_timer / 0.14, 0.0, 1.0))
	if state in [PlayerState.SLASH, PlayerState.DRAW_SWORD]:
		var lunge_env := sin(progress * PI)
		sprite.position += Vector2(dir_vec.x * 7.5, dir_vec.y * 5.0) * lunge_env
		sprite.rotation = dir_vec.x * sin(progress * TAU) * 0.035
	elif state == PlayerState.SHOOT:
		var recoil := pow(1.0 - progress, 3.0)
		sprite.position -= Vector2(dir_vec.x * 4.5, dir_vec.y * 3.0) * recoil
	elif state == PlayerState.HIT:
		sprite.position -= dir_vec * 3.0 * sin(progress * PI)
	elif state == PlayerState.WALK and velocity.length() > 20.0:
		var stride := sin(walk_phase * 2.0)
		sprite.position += Vector2(stride * 0.65, -absf(stride) * 1.5)
		sprite.rotation = stride * 0.012
	elif state == PlayerState.IDLE:
		sprite.position.y -= sin(anim_clock * 3.5) * 0.6
	if dodge_timer > 0.0:
		var dodge_progress := 1.0 - dodge_timer / DODGE_DURATION
		sprite.position += Vector2(dodge_direction.x * 5.0, 3.0) * sin(dodge_progress * PI)
		sprite.rotation = dodge_direction.x * 0.08 * sin(dodge_progress * PI)
		sprite.scale = Vector2(1.04, 0.96)
		sprite.modulate = Color(0.84, 0.84, 0.92, 0.9)

	var target_loadout := _active_loadout_key()
	if state == PlayerState.SHOOT:
		target_loadout = "rifle"
	elif state in [PlayerState.SLASH, PlayerState.DRAW_SWORD]:
		var melee_id := GameState.active_attack_item_id()
		if String(DataRegistry.get_equipment(melee_id).get("attack_mode", "melee")) != "melee":
			melee_id = String(GameState.equipment.get("weapon", "rust_blade"))
		target_loadout = _melee_loadout_key(melee_id)
	if target_loadout != current_loadout_id:
		_apply_loadout(target_loadout)
	var pose := _presentation_pose()
	set_meta("presentation_v2_active", not pose.is_empty())
	if not pose.is_empty():
		var motion := sprite.position - sprite_base_position
		sprite.position = Vector2(0, -8) + motion
		sprite.scale *= float(pose["scale"])
		sprite.offset = pose["offset"]
		sprite.material = _presentation_materials[current_loadout_id]
		weapon_sprite.visible = false
		set_meta("presentation_v2_family", current_loadout_id)
		set_meta("presentation_v2_facings", _presentation_angles_for_action(current_loadout_id, _presentation_action_name()).size())
		var sequence: Array = _presentation_families[current_loadout_id]["actions"][_presentation_action_name()]
		var unique_keys: Dictionary = {}
		for key in sequence:
			unique_keys[key] = true
		set_meta("presentation_v2_action_keys", unique_keys.size())
		set_meta("presentation_v2_frame_slots", sequence.size())
		return
	if _directional_body_frames.size() == 8 and state != PlayerState.DEAD:
		sprite.position += _body_pose_offset() * _body_pose_scale() + Vector2(0, 56)
		sprite.scale *= _body_pose_scale()
	if weapon_sprite == null:
		return
	var item := DataRegistry.get_equipment(GameState.active_attack_item_id())
	if state == PlayerState.SHOOT and String(item.get("attack_mode", "")) != "ranged":
		item = DataRegistry.get_equipment(String(GameState.equipment.get("ranged", "pipe_rifle")))
	elif state in [PlayerState.SLASH, PlayerState.DRAW_SWORD] and String(item.get("attack_mode", "")) != "melee":
		item = DataRegistry.get_equipment(String(GameState.equipment.get("weapon", "rust_blade")))
	var attack_mode := String(item.get("attack_mode", "melee"))
	var asset_id := String(item.get("weapon_sprite_asset_id", ""))
	if asset_id != current_weapon_asset_id:
		current_weapon_asset_id = asset_id
		weapon_sprite.texture = ASSET_LOADER.load_png(DataRegistry.asset_path(asset_id))
	weapon_sprite.visible = weapon_sprite.texture != null and state not in [PlayerState.DEAD, PlayerState.INTERACT]
	var body_motion := sprite.position - sprite_base_position
	if _directional_body_frames.size() == 8 and state != PlayerState.DEAD:
		body_motion -= _body_pose_offset() * _body_pose_scale() + Vector2(0, 56)
	weapon_sprite.position = _weapon_hand_local() + body_motion
	weapon_sprite.z_index = -1 if dir_vec.y < -0.2 else 2
	weapon_sprite.rotation = dir_vec.angle()
	weapon_sprite.scale = Vector2.ONE * (0.6 if attack_mode == "ranged" else 0.82)
	if state in [PlayerState.SLASH, PlayerState.DRAW_SWORD]:
		var sign := -1.0 if state == PlayerState.DRAW_SWORD else 1.0
		var sweep := smoothstep(0.20, 0.58, progress)
		weapon_sprite.rotation += lerpf(-1.50, 1.30, sweep) * sign
	elif state != PlayerState.SHOOT and attack_mode == "melee":
		weapon_sprite.rotation += 0.85 if dir_vec.x >= 0.0 else -0.85
	if state == PlayerState.SWAP_TOOL:
		weapon_sprite.rotation += sin(progress * PI) * 1.4
		weapon_sprite.position.y += sin(progress * PI) * 10.0
		weapon_sprite.scale *= 1.0 - sin(progress * PI) * 0.25
	weapon_sprite.modulate = sprite.modulate


func _add_step_mark(is_dodge := false) -> void:
	_step_side *= -1.0
	_step_marks.append({"position": global_position + Vector2(_step_side * 9.0, -8.0), "age": 0.0, "dodge": is_dodge})
	if _step_marks.size() > 8:
		_step_marks.pop_front()


func _draw() -> void:
	for mark in _step_marks:
		var t := float(mark["age"]) / 0.3
		var at: Vector2 = (mark["position"] as Vector2) - global_position
		var dust := Color(0.58, 0.47, 0.34, (1.0 - t) * 0.42)
		for i in range(3):
			var drift := Vector2(float(i - 1) * (3.0 + t * 7.0), -t * float(i + 1) * 3.0)
			draw_rect(Rect2((at + drift).round(), Vector2(3, 2)), dust)
		if bool(mark["dodge"]):
			draw_line(at.round(), (at - dodge_direction * (15.0 + t * 16.0)).round(), Color(0.72, 0.64, 0.47, (1.0 - t) * 0.4), 2.0)


func _on_feedback_requested(kind: String, strength: float) -> void:
	match kind:
		"player_hit":
			_hit_flash_timer = 0.14
			_set_timed_state(PlayerState.HIT, 0.28)
		"player_dead":
			_set_timed_state(PlayerState.DEAD, 1.20)
	_start_camera_shake(strength)


func _start_camera_shake(strength: float) -> void:
	shake_timer = max(shake_timer, 0.16 + strength * 0.25)
	shake_strength = max(shake_strength, strength * 24.0)


func _update_camera_shake(delta: float) -> void:
	if camera == null:
		return

	if shake_timer <= 0.0:
		camera.offset = camera_base_offset
		shake_strength = 0.0
		return

	shake_timer = max(0.0, shake_timer - delta)
	var falloff: float = shake_timer / max(0.01, 0.20 + shake_strength * 0.01)
	var offset: Vector2 = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_strength * clampf(falloff, 0.0, 1.0)
	camera.offset = camera_base_offset + offset
