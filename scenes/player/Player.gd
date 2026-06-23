extends CharacterBody2D

const PIXEL := preload("res://scripts/utils/PixelArtFactory.gd")
const PROJECTILE_SCRIPT := preload("res://scripts/components/Projectile.gd")
const ATTACK_FLASH_SCRIPT := preload("res://scripts/components/AttackFlash.gd")
const ASSET_LOADER := preload("res://scripts/utils/RuntimeAssetLoader.gd")
const PLAYER_ATLAS_PATH := "res://docs/recycler_player_multiaction_8dir_preview.png"
const PLAYER_FRAME_DIR := "res://assets/sprites/player/frames"
const PREFER_SPLIT_FRAME_FILES := true
const SPRINT_MULTIPLIER := 1.55
const SPRINT_EP_DRAIN_PER_SECOND := 10.0
const SPRINT_REENABLE_EP_RATIO := 0.5
const EP_REGEN_PER_SECOND := 20.0
const EP_REGEN_DELAY_AFTER_COMBAT := 1.0
const SLASH_ANIMATION_SPEED := 10.125
const SLASH_STATE_DURATION := 1.28

@export var move_speed: float = 180.0

enum PlayerState { IDLE, WALK, RUN, SHOOT, DRAW_SWORD, SLASH, SWAP_TOOL, INTERACT, HIT, DEAD }

var state := PlayerState.IDLE
var last_direction := Vector2.RIGHT
var attack_timer := 0.0
var ranged_timer := 0.0
var action_state_timer := 0.0
var pending_slash := false
var current_animation := ""
var has_world_bounds := false
var world_bounds := Rect2()
var camera_base_offset := Vector2.ZERO
var shake_timer := 0.0
var shake_strength := 0.0
var weapon_sprite: Sprite2D
var current_weapon_asset_id := ""
var ep_change_carry: float = 0.0
var ep_regen_delay: float = 0.0
var is_sprinting: bool = false
var sprint_exhausted: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	add_to_group("player")
	add_to_group("map_player")
	set_meta("map_label", "R-17")
	set_meta("map_marker", "player")

	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	weapon_sprite = Sprite2D.new()
	weapon_sprite.name = "WeaponOverlay"
	weapon_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	weapon_sprite.z_index = 5
	weapon_sprite.centered = true
	weapon_sprite.visible = false
	add_child(weapon_sprite)

	camera_base_offset = camera.offset

	if not GameState.feedback_requested.is_connected(_on_feedback_requested):
		GameState.feedback_requested.connect(_on_feedback_requested)

	if not GameState.equipment_changed.is_connected(_update_weapon_overlay):
		GameState.equipment_changed.connect(_update_weapon_overlay)

	_build_sprite_frames()
	_update_weapon_overlay()
	_update_animation()


func _physics_process(delta: float) -> void:
	attack_timer = max(0.0, attack_timer - delta)
	ranged_timer = max(0.0, ranged_timer - delta)
	action_state_timer = max(0.0, action_state_timer - delta)

	if pending_slash and action_state_timer <= 0.0:
		pending_slash = false
		_set_timed_state(PlayerState.SLASH, SLASH_STATE_DURATION)

	var input_direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var wants_sprint: bool = Input.is_action_pressed("dash") and input_direction.length() > 0.05 and not _is_action_state_locked()
	is_sprinting = wants_sprint and _can_sprint()

	if state == PlayerState.DEAD:
		velocity = Vector2.ZERO
		move_and_slide()
		_update_camera_shake(delta)
		_update_animation()
		return

	if not _is_action_state_locked():
		_update_locomotion_state(input_direction)
	elif input_direction.length() > 0.05 and state != PlayerState.SHOOT:
		last_direction = input_direction.normalized()

	var speed_bonus: int = GameState.get_stat_bonus("speed")
	var base_speed: float = max(80.0, move_speed + speed_bonus)
	var speed_multiplier: float = SPRINT_MULTIPLIER if is_sprinting else 1.0
	velocity = input_direction * base_speed * speed_multiplier
	move_and_slide()

	if has_world_bounds:
		global_position = global_position.clamp(world_bounds.position, world_bounds.position + world_bounds.size)

	GameState.player_position = global_position

	if Input.is_action_just_pressed("primary_attack"):
		_primary_attack_pressed()

	if Input.is_action_pressed("primary_attack") and GameState.active_attack_mode() == "ranged":
		_ranged_attack()

	if Input.is_action_just_pressed("attack_melee"):
		_melee_attack()

	if Input.is_action_just_pressed("attack_ranged") or Input.is_action_pressed("attack_ranged"):
		_ranged_attack()

	if Input.is_action_just_pressed("swap_weapon"):
		_set_timed_state(PlayerState.SWAP_TOOL, 0.22)
		AudioManager.play_sfx("ui")
		GameState.use_next_quick_slot()

	for slot_index in range(4):
		if Input.is_action_just_pressed("quick_slot_%d" % [slot_index + 1]):
			_set_timed_state(PlayerState.SWAP_TOOL, 0.22)
			GameState.use_quick_slot(slot_index)

	if Input.is_action_just_pressed("interact"):
		_set_timed_state(PlayerState.INTERACT, 0.18)

	if Input.is_action_just_pressed("save_game"):
		SaveManager.save_game()

	if Input.is_action_just_pressed("load_game"):
		SaveManager.load_game()

	_update_ep(delta)
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


func _primary_attack_pressed() -> void:
	match GameState.active_attack_mode():
		"ranged":
			_ranged_attack()
		"tool":
			_use_tool_action()
		_:
			_melee_attack(true)


func _melee_attack(use_mouse_aim := false) -> void:
	if attack_timer > 0.0:
		return
	_mark_combat_activity()

	if use_mouse_aim:
		last_direction = _aim_direction()

	var weapon_id := GameState.active_attack_item_id()
	var weapon := DataRegistry.get_equipment(weapon_id)

	if String(weapon.get("attack_mode", "melee")) != "melee":
		weapon_id = String(GameState.equipment.get("weapon", "rust_blade"))
		weapon = DataRegistry.get_equipment(weapon_id)

	_set_timed_state(PlayerState.DRAW_SWORD, 0.10)
	pending_slash = true
	attack_timer = float(weapon.get("cooldown", 0.32))

	var sfx_id := String(weapon.get("sfx_id", "melee"))
	var vfx_id := String(weapon.get("attack_vfx_id", "slash_rust"))
	var shake := float(weapon.get("shake_strength", 0.08))

	AudioManager.play_sfx(sfx_id)
	_spawn_attack_flash(vfx_id, max(0.7, shake * 9.0))
	GameState.request_feedback("attack", shake)

	var damage := 12 + GameState.get_stat_bonus("attack")
	var reach: float = 112.0 if weapon_id == "breaker_hammer" else 104.0
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
		if attack_direction.dot(facing) > -0.35 and enemy.has_method("take_damage"):
			enemy.take_damage(damage, true)


func _ranged_attack() -> void:
	if ranged_timer > 0.0:
		return
	_mark_combat_activity()

	var ranged_id := GameState.active_attack_item_id()
	var ranged := DataRegistry.get_equipment(ranged_id)

	if String(ranged.get("attack_mode", "ranged")) != "ranged":
		ranged_id = String(GameState.equipment.get("ranged", "pipe_rifle"))
		ranged = DataRegistry.get_equipment(ranged_id)

	if not GameState.spend_ammo(1):
		GameState.notify("彈藥不足：先用近戰清出空間，或回村補給。")
		return

	last_direction = _aim_direction()
	_set_timed_state(PlayerState.SHOOT, 0.22)

	var sfx_id := String(ranged.get("sfx_id", "shoot"))
	var vfx_id := String(ranged.get("attack_vfx_id", "muzzle_pipe"))
	var shake := float(ranged.get("shake_strength", 0.06))

	AudioManager.play_sfx(sfx_id)
	_spawn_attack_flash(vfx_id, max(0.55, shake * 8.0))
	GameState.request_feedback("attack", shake)

	ranged_timer = float(ranged.get("cooldown", 0.25))

	var projectile_damage := 10 + GameState.get_stat_bonus("attack")
	var projectile_start := _projectile_spawn_global()
	var pools := get_tree().get_nodes_in_group("projectile_pool")

	if not pools.is_empty() and pools[0].has_method("fire_projectile"):
		if not pools[0].fire_projectile(projectile_start, last_direction, projectile_damage):
			GameState.add_item("ammo", 1)
	else:
		var projectile: Area2D = PROJECTILE_SCRIPT.new()
		projectile.setup(projectile_start, last_direction, projectile_damage)
		get_tree().current_scene.add_child(projectile)


func _use_tool_action() -> void:
	_set_timed_state(PlayerState.INTERACT, 0.20)
	_mark_combat_activity()

	var tool := DataRegistry.get_equipment(GameState.active_attack_item_id())

	AudioManager.play_sfx(String(tool.get("sfx_id", "interact")))
	_spawn_attack_flash(String(tool.get("attack_vfx_id", "scan_pulse")), 0.8)
	GameState.notify("R-17 啟動掃描：附近可回收材料已標記。")


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


func _update_ep(delta: float) -> void:
	_update_sprint_exhaustion_lock()

	if is_sprinting:
		_apply_ep_delta(-SPRINT_EP_DRAIN_PER_SECOND * delta)
		return

	if ep_regen_delay > 0.0:
		ep_regen_delay = max(0.0, ep_regen_delay - delta)
		return

	if GameState.ep < GameState.get_max_ep():
		_apply_ep_delta(EP_REGEN_PER_SECOND * delta)
		_update_sprint_exhaustion_lock()


func _mark_combat_activity() -> void:
	ep_regen_delay = EP_REGEN_DELAY_AFTER_COMBAT


func _can_sprint() -> bool:
	_update_sprint_exhaustion_lock()
	return not sprint_exhausted and GameState.ep > 0


func _update_sprint_exhaustion_lock() -> void:
	if sprint_exhausted and GameState.ep >= _sprint_reenable_ep():
		sprint_exhausted = false


func _sprint_reenable_ep() -> int:
	return int(ceil(float(GameState.get_max_ep()) * SPRINT_REENABLE_EP_RATIO))


func _apply_ep_delta(amount: float) -> void:
	ep_change_carry += amount
	var whole_amount: int = int(ep_change_carry)
	if whole_amount == 0:
		return

	var previous_ep: int = GameState.ep
	GameState.ep = clampi(GameState.ep + whole_amount, 0, GameState.get_max_ep())
	ep_change_carry -= float(whole_amount)

	if GameState.ep == 0 and amount < 0.0:
		ep_change_carry = 0.0
		sprint_exhausted = true
	if GameState.ep == GameState.get_max_ep() and amount > 0.0:
		ep_change_carry = 0.0
	_update_sprint_exhaustion_lock()

	if GameState.ep != previous_ep:
		GameState.stats_changed.emit()


func _build_sprite_frames() -> void:
	var frames := SpriteFrames.new()
	var atlas: Texture2D = ASSET_LOADER.load_png(PLAYER_ATLAS_PATH)
	var player_actions: Array[String] = _player_action_names()

	for action_name: String in player_actions:
		var action_index: int = _fallback_action_index(action_name)

		for direction_index in range(8):
			var animation_name: String = "%s_%d" % [action_name, direction_index]
			var source_direction_index: int = _source_direction_index(action_name, direction_index)
			var frame_count: int = _frame_count_for_animation(action_name, direction_index)

			frames.add_animation(animation_name)
			frames.set_animation_speed(
				animation_name,
				_animation_speed_for_action(action_name)
			)
			frames.set_animation_loop(animation_name, action_name in ["idle", "walk", "run"])

			for frame_index in range(frame_count):
				var tex: Texture2D = null

				if PREFER_SPLIT_FRAME_FILES:
					tex = _split_frame_texture(action_name, direction_index, frame_index)

				if tex != null:
					frames.add_frame(animation_name, tex)
				elif atlas != null:
					frames.add_frame(animation_name, _atlas_frame(atlas, action_index, source_direction_index, frame_index % PixelArtFactory.PLAYER_FRAMES_PER_ACTION))
				else:
					frames.add_frame(
						animation_name,
						PIXEL.new().player_texture(source_direction_index, action_index, frame_index % PixelArtFactory.PLAYER_FRAMES_PER_ACTION)
					)

	sprite.sprite_frames = frames


func _player_action_names() -> Array[String]:
	var actions: Array[String] = []
	for action in PixelArtFactory.PLAYER_ACTIONS:
		actions.append(String(action))
	if not actions.has("run"):
		actions.insert(actions.find("walk") + 1, "run")
	return actions


func _fallback_action_index(action_name: String) -> int:
	var action_index: int = PixelArtFactory.PLAYER_ACTIONS.find(action_name)
	if action_index >= 0:
		return action_index
	return PixelArtFactory.PLAYER_ACTIONS.find("walk")


func _animation_speed_for_action(action_name: String) -> float:
	match action_name:
		"run":
			return 12.0
		"walk":
			return 10.0
		"idle":
			return 8.0
		"slash":
			return SLASH_ANIMATION_SPEED
		_:
			return 18.0


func _source_direction_index(action_name: String, direction_index: int) -> int:
	if PREFER_SPLIT_FRAME_FILES:
		return direction_index

	if action_name == "walk":
		match direction_index:
			5:
				return 4
			7:
				return 0
	return direction_index


func _split_frame_texture(action_name: String, direction_index: int, frame_index: int) -> Texture2D:
	var path := "%s/%s/dir_%d/frame_%d.png" % [PLAYER_FRAME_DIR, action_name, direction_index, frame_index]
	return ASSET_LOADER.load_png(path)


func _frame_count_for_animation(action_name: String, direction_index: int) -> int:
	if PREFER_SPLIT_FRAME_FILES:
		var count: int = 0
		while FileAccess.file_exists("%s/%s/dir_%d/frame_%d.png" % [PLAYER_FRAME_DIR, action_name, direction_index, count]):
			count += 1
		if count > 0:
			return count

	return PixelArtFactory.PLAYER_FRAMES_PER_ACTION


func _atlas_frame(atlas: Texture2D, action_index: int, direction_index: int, frame_index: int) -> AtlasTexture:
	var frame_size := PixelArtFactory.PLAYER_FRAME_SIZE
	var texture := AtlasTexture.new()
	texture.atlas = atlas
	texture.region = Rect2((action_index * PixelArtFactory.PLAYER_FRAMES_PER_ACTION + frame_index) * frame_size.x, direction_index * frame_size.y, frame_size.x, frame_size.y)
	return texture


func _update_animation() -> void:
	var direction_index := _direction_index()
	var action_name := "idle"

	match state:
		PlayerState.RUN:
			action_name = "run"
		PlayerState.WALK:
			action_name = "walk"
		PlayerState.SHOOT:
			action_name = "shoot"
		PlayerState.DRAW_SWORD:
			action_name = "draw_sword"
		PlayerState.SLASH:
			action_name = "slash"
		PlayerState.SWAP_TOOL:
			action_name = "swap_tool"
		PlayerState.INTERACT:
			action_name = "interact"
		PlayerState.HIT:
			action_name = "hit"
		PlayerState.DEAD:
			action_name = "dead"

	var next_animation := "%s_%d" % [action_name, direction_index]

	if current_animation != next_animation:
		current_animation = next_animation
		sprite.play(current_animation)


func _update_locomotion_state(input_direction: Vector2) -> void:
	if input_direction.length() > 0.05:
		last_direction = input_direction.normalized()
		state = PlayerState.RUN if is_sprinting else PlayerState.WALK
	else:
		state = PlayerState.IDLE


func _set_timed_state(next_state: int, duration: float) -> void:
	state = next_state
	action_state_timer = max(action_state_timer, duration)
	current_animation = ""


func _is_action_state_locked() -> bool:
	return action_state_timer > 0.0 and state in [PlayerState.SHOOT, PlayerState.DRAW_SWORD, PlayerState.SLASH, PlayerState.SWAP_TOOL, PlayerState.INTERACT, PlayerState.HIT, PlayerState.DEAD]


func _spawn_attack_flash(effect_id: String, strength: float) -> void:
	if effect_id.begins_with("slash") or effect_id.begins_with("slam"):
		return
	var flash: Node2D = ATTACK_FLASH_SCRIPT.new()
	flash.setup(effect_id, last_direction, strength)
	flash.global_position = _attack_anchor_global() + last_direction * 8.0
	get_tree().current_scene.add_child(flash)


func _attack_anchor_global() -> Vector2:
	return global_position + Vector2(0, -62)


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


func _projectile_spawn_global() -> Vector2:
	var direction := last_direction.normalized()
	if direction.length() < 0.1:
		direction = Vector2.RIGHT
	return _attack_anchor_global() + direction * 46.0


func _update_weapon_overlay() -> void:
	if weapon_sprite == null:
		return

	var direction_index := _direction_index()
	var needs_overlay := state in [PlayerState.SHOOT, PlayerState.DRAW_SWORD, PlayerState.SLASH] and direction_index not in [0, 4]
	if not needs_overlay:
		weapon_sprite.visible = false
		return

	var item_id := _weapon_overlay_item_id()
	var equipment := DataRegistry.get_equipment(item_id)
	var asset_id := String(equipment.get("weapon_sprite_asset_id", ""))
	if asset_id.is_empty():
		weapon_sprite.visible = false
		return

	if current_weapon_asset_id != asset_id:
		current_weapon_asset_id = asset_id
		var path := DataRegistry.asset_path(asset_id)
		weapon_sprite.texture = ASSET_LOADER.load_png(path) if not path.is_empty() else null

	if weapon_sprite.texture == null:
		weapon_sprite.visible = false
		return

	var direction := last_direction.normalized()
	if direction.length() < 0.1:
		direction = Vector2.RIGHT

	weapon_sprite.visible = true
	weapon_sprite.position = Vector2(0, -62) + direction * 34.0
	weapon_sprite.rotation = direction.angle()
	weapon_sprite.flip_v = abs(direction.angle()) > PI * 0.5


func _weapon_overlay_item_id() -> String:
	match state:
		PlayerState.SHOOT:
			return String(GameState.equipment.get("ranged", "pipe_rifle"))
		PlayerState.DRAW_SWORD, PlayerState.SLASH:
			return String(GameState.equipment.get("weapon", "rust_blade"))
		_:
			return String(GameState.active_attack_item_id())


func _on_feedback_requested(kind: String, strength: float) -> void:
	match kind:
		"player_hit":
			_mark_combat_activity()
			_set_timed_state(PlayerState.HIT, 0.28)
		"player_dead":
			_mark_combat_activity()
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
	var offset: Vector2 = Vector2(
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0)
	) * shake_strength * clampf(falloff, 0.0, 1.0)

	camera.offset = camera_base_offset + offset
