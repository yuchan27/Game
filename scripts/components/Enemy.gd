extends CharacterBody2D
class_name WastelandEnemy

const PIXEL := preload("res://scripts/utils/PixelArtFactory.gd")
const PICKUP_SCRIPT := preload("res://scripts/components/Pickup.gd")
const DAMAGE_POPUP_SCRIPT := preload("res://scripts/components/DamagePopup.gd")
const HEALTH_BAR_SCRIPT := preload("res://scripts/components/EnemyHealthBar.gd")
const HIT_EFFECT_SCRIPT := preload("res://scripts/components/HitEffect.gd")
const ENEMY_ATLAS_PATH := "res://assets/sprites/enemies/polluted_enemy_six_types.png"
const TARGET_ACQUIRE_RANGE := 720.0
const TARGET_RELEASE_RANGE := 900.0
const HOME_ARRIVAL_RADIUS := 24.0
static var _directional_art_cache: Dictionary = {}

var enemy_id := "scrap_biter"
var enemy_name := "污染體"
var enemy_type := "melee"
var hp := 24
var max_hp := 24
var speed := 70.0
var damage := 8
var drop_table: Dictionary = {}
var rare_drop_table: Dictionary = {}
var target: Node2D
var attack_cooldown := 0.0
var ranged_cooldown := 0.0
var dash_cooldown := 0.0
var dash_time := 0.0
var contact_range := 42.0
var preferred_distance := 0.0
var ranged_range := 0.0
var ranged_attack_cooldown := 1.4
var can_fire_projectiles := false
var is_dead := false
var _phase := 0.0
var _sprite: Sprite2D
var _health_bar: Node2D
var _base_sprite_pos := Vector2.ZERO
var _base_scale := Vector2.ONE
var knockback_velocity := Vector2.ZERO
var stagger_timer := 0.0
var facing_direction := Vector2.RIGHT
var facing_index := 0
var pending_attack := ""
var windup_timer := 0.0
var windup_duration := 0.0
var recovery_timer := 0.0
var _attack_direction := Vector2.RIGHT
var _hit_flash_timer := 0.0
var _directional_frames: Array = []
var _directional_offsets: Array = []
var _directional_scale := 1.0
var _directional_source := ""
var _spawn_anchor_position := Vector2.ZERO
var _is_alerted := false

func setup(id: String, data: Dictionary, player_ref: Node2D) -> void:
	enemy_id = id
	enemy_name = String(data.get("name", id))
	enemy_type = String(data.get("type", "melee"))
	hp = int(data.get("hp", 24))
	max_hp = hp
	speed = float(data.get("speed", 70.0))
	damage = int(data.get("damage", 8))
	drop_table = data.get("drop_table", {})
	rare_drop_table = data.get("rare_drop_table", {})
	target = player_ref
	_configure_behavior()

func _ready() -> void:
	_spawn_anchor_position = global_position
	_is_alerted = enemy_type == "boss"
	add_to_group("enemy")
	add_to_group("map_enemy")
	set_meta("map_label", enemy_name)
	set_meta("map_marker", "enemy")
	if enemy_type == "boss":
		add_to_group("boss")
		add_to_group("map_boss")
		set_meta("map_marker", "boss")
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 32 if enemy_type == "boss" else 18
	collision.shape = shape
	add_child(collision)
	var shadow := Polygon2D.new()
	shadow.name = "GroundShadow"
	shadow.z_index = -1
	var rx := 42.0 if enemy_type == "boss" else 22.0
	var ry := 14.0 if enemy_type == "boss" else 7.5
	var sy := 24.0 if enemy_type == "boss" else 18.0
	var s_pts := PackedVector2Array()
	for i in range(18):
		var a := float(i) / 18.0 * TAU
		s_pts.append(Vector2(cos(a) * rx, sin(a) * ry + sy))
	shadow.polygon = s_pts
	shadow.color = Color(0.03, 0.02, 0.04, 0.44)
	add_child(shadow)
	_sprite = Sprite2D.new()
	_sprite.texture = _enemy_texture(enemy_type)
	_load_directional_art()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if enemy_type == "boss":
		_sprite.scale = Vector2(1.9, 1.9)
		_sprite.position.y = -14
	_base_sprite_pos = _sprite.position
	_base_scale = _sprite.scale
	add_child(_sprite)
	_update_facing(Vector2.RIGHT)
	_update_presentation()
	_health_bar = HEALTH_BAR_SCRIPT.new()
	_health_bar.setup(116.0 if enemy_type == "boss" else 54.0)
	_health_bar.position = Vector2(0, -90 if enemy_type == "boss" else -54)
	_health_bar.visible = false
	add_child(_health_bar)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_phase += delta * _animation_speed()
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	ranged_cooldown = maxf(0.0, ranged_cooldown - delta)
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	dash_time = maxf(0.0, dash_time - delta)
	recovery_timer = maxf(0.0, recovery_timer - delta)
	_hit_flash_timer = maxf(0.0, _hit_flash_timer - delta)
	if target == null or not is_instance_valid(target):
		pending_attack = ""
		_update_presentation()
		queue_redraw()
		return
	var offset := target.global_position - global_position
	var distance := offset.length()
	stagger_timer = max(0.0, stagger_timer - delta)
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 880.0 * delta)
	if not _should_chase_target(distance):
		pending_attack = ""
		windup_timer = 0.0
		var home_offset := _spawn_anchor_position - global_position
		if home_offset.length() > HOME_ARRIVAL_RADIUS:
			_update_facing(home_offset)
			velocity = home_offset.normalized() * _current_speed() * 0.65 + knockback_velocity
		else:
			velocity = knockback_velocity
		move_and_slide()
		_update_presentation()
		queue_redraw()
		return
	var desired := _desired_direction(offset, distance)
	if pending_attack.is_empty() and dash_time <= 0.0:
		_update_facing(offset)
	if not pending_attack.is_empty():
		windup_timer = maxf(0.0, windup_timer - delta)
		if windup_timer <= 0.0:
			_resolve_attack()
	var move_mult := 0.25 if stagger_timer > 0.0 else 1.0
	if not pending_attack.is_empty():
		move_mult *= 0.18
	if dash_time > 0.0:
		desired = _attack_direction
	velocity = desired * _current_speed() * move_mult + knockback_velocity
	move_and_slide()
	if pending_attack.is_empty() and recovery_timer <= 0.0 and stagger_timer <= 0.0:
		if distance < contact_range and attack_cooldown <= 0.0:
			_begin_attack("contact", offset)
		elif can_fire_projectiles and distance <= ranged_range and ranged_cooldown <= 0.0:
			_begin_attack("ranged", offset)
	_update_presentation()
	queue_redraw()

func _begin_attack(kind: String, direction: Vector2) -> void:
	pending_attack = kind
	_attack_direction = direction.normalized() if direction.length() > 0.1 else facing_direction
	_update_facing(_attack_direction)
	windup_duration = 0.42 if enemy_type == "boss" else (0.34 if enemy_type == "heavy" else 0.2)
	if kind == "ranged":
		windup_duration = 0.32
	windup_timer = windup_duration
	if kind == "contact":
		attack_cooldown = _contact_cooldown()
	elif kind == "dash":
		dash_cooldown = 1.2
	queue_redraw()

func _resolve_attack() -> void:
	var kind := pending_attack
	pending_attack = ""
	recovery_timer = 0.18 if enemy_type not in ["heavy", "boss"] else 0.3
	if kind == "dash":
		dash_time = 0.18
	elif kind == "ranged":
		_fire_pollution_shot(_attack_direction)
	elif kind == "contact" and is_instance_valid(target):
		# Leaving the marked reach during anticipation cleanly avoids the hit.
		if global_position.distance_to(target.global_position) < contact_range:
			GameState.take_damage(damage)

func _load_directional_art() -> void:
	var asset := DataRegistry.get_visual_asset("enemy_" + enemy_id)
	var path := String(asset.get("directional_path", "res://assets/sprites/enemies/%s_8dir.png" % enemy_id))
	if not _directional_art_cache.has(path):
		var atlas := _load_atlas_texture(path)
		var art := {"frames": [], "offsets": [], "scale": 1.0}
		var rects: Array = asset.get("directional_rects", [])
		var feet: Array = asset.get("directional_feet", [])
		if atlas != null and (rects.size() == 8 or (atlas.get_width() % 4 == 0 and atlas.get_height() % 2 == 0)):
			var cell := Vector2i(atlas.get_width() / 4, atlas.get_height() / 2)
			var source_image := atlas.get_image()
			var largest := Vector2.ONE
			if source_image != null:
				for index in range(8):
					var origin := Vector2i(index % 4, index / 4) * cell
					var source_rect := Rect2i(origin, cell)
					if rects.size() == 8:
						var coordinates: Array = rects[index]
						if coordinates.size() != 4:
							art["frames"].clear()
							break
						source_rect = Rect2i(int(coordinates[0]), int(coordinates[1]), int(coordinates[2]), int(coordinates[3]))
					if not Rect2i(Vector2i.ZERO, source_image.get_size()).encloses(source_rect) or not source_rect.has_area():
						art["frames"].clear()
						break
					var used := source_image.get_region(source_rect).get_used_rect()
					if not used.has_area():
						art["frames"].clear()
						break
					var texture := AtlasTexture.new()
					texture.atlas = atlas
					texture.region = Rect2(source_rect.position + used.position, used.size)
					art["frames"].append(texture)
					var anchor := Vector2(texture.region.get_center().x, texture.region.end.y)
					if feet.size() == 8 and (feet[index] as Array).size() == 2:
						anchor = Vector2(float(feet[index][0]), float(feet[index][1]))
					art["offsets"].append(texture.region.get_center() - anchor)
					largest = largest.max(Vector2(used.size))
				art["scale"] = minf(88.0 / largest.x, 68.0 / largest.y)
		_directional_art_cache[path] = art
	var cached: Dictionary = _directional_art_cache[path]
	_directional_frames = cached["frames"]
	_directional_offsets = cached["offsets"]
	_directional_scale = float(cached["scale"])
	_directional_source = path if _directional_frames.size() == 8 else ENEMY_ATLAS_PATH
	set_meta("directional_art_source", _directional_source)
	set_meta("directional_art_views", 8 if _directional_frames.size() == 8 else 1)
	set_meta("directional_art_mode", "authored_8view" if _directional_frames.size() == 8 else "single_view_mirrored_fallback")

func _update_facing(direction: Vector2) -> void:
	if direction.length() < 0.1:
		return
	facing_direction = direction.normalized()
	facing_index = int(round(facing_direction.angle() / (PI / 4.0))) & 7
	if _sprite == null:
		return
	if _directional_frames.size() == 8:
		_sprite.texture = _directional_frames[facing_index]
		_sprite.flip_h = false
	else:
		_sprite.flip_h = facing_direction.x < -0.1
	set_meta("facing_index", facing_index)

func _update_presentation() -> void:
	if _sprite == null:
		return
	var bob := sin(_phase) * (3.5 if enemy_type == "flying" else 1.2)
	var lean := Vector2.ZERO
	var squash := Vector2.ONE
	if not pending_attack.is_empty():
		var charge := 1.0 - windup_timer / maxf(0.01, windup_duration)
		lean = -_attack_direction * charge * 4.0
		squash = Vector2(1.0 + charge * 0.04, 1.0 - charge * 0.04)
	elif recovery_timer > 0.0:
		lean = _attack_direction * sin(recovery_timer * 9.0) * 4.0
	var art_scale := _directional_scale if _directional_frames.size() == 8 else 1.0
	var feet_offset := Vector2.ZERO
	if _directional_frames.size() == 8:
		var ground_y := 24.0 if enemy_type == "boss" else 18.0
		feet_offset = (_directional_offsets[facing_index] as Vector2) * art_scale * _base_scale + Vector2(0, ground_y - _base_sprite_pos.y)
	_sprite.position = _base_sprite_pos + feet_offset + Vector2(0, bob) + lean
	_sprite.scale = _base_scale * art_scale * squash
	_sprite.rotation = -facing_direction.x * 0.025 if dash_time > 0.0 else 0.0
	_sprite.modulate = Color.WHITE.lerp(Color(1.0, 0.5, 0.35), clampf(_hit_flash_timer / 0.12, 0.0, 1.0))

func _draw() -> void:
	if is_dead or pending_attack.is_empty():
		return
	var charge := 1.0 - windup_timer / maxf(0.01, windup_duration)
	var radius := contact_range if pending_attack == "contact" else (64.0 if pending_attack == "dash" else 46.0)
	var origin := Vector2.ZERO
	var points := PackedVector2Array([origin])
	for index in range(11):
		var angle := _attack_direction.angle() + lerpf(-0.5, 0.5, float(index) / 10.0)
		points.append((origin + Vector2(cos(angle), sin(angle)) * radius).round())
	draw_colored_polygon(points, Color(0.56, 0.14, 0.08, 0.08 + charge * 0.16))
	draw_polyline(points.slice(1), Color(0.96, 0.48, 0.2, 0.35 + charge * 0.55), 2.0)
	var tip := origin + _attack_direction * (radius * charge)
	draw_rect(Rect2(tip.round() - Vector2(2, 2), Vector2(4, 4)), Color(1.0, 0.74, 0.4, 0.85))

func apply_knockback(impulse: Vector2) -> void:
	if is_dead:
		return
	var resist := 0.30 if enemy_type == "boss" else (0.58 if enemy_type == "heavy" else 1.0)
	knockback_velocity = impulse * resist
	stagger_timer = max(stagger_timer, 0.12 * resist)

func take_damage(amount: int, melee := false) -> void:
	if is_dead:
		return
	_is_alerted = true
	hp -= amount
	AudioManager.play_sfx("hit")
	GameState.request_feedback("enemy_hit", 0.08 if melee else 0.04)
	_show_damage_feedback(amount, melee)
	if _health_bar != null:
		_health_bar.show_value(hp, max_hp)
	if hp <= 0:
		_die(melee)

func _show_damage_feedback(amount: int, melee: bool) -> void:
	var popup: Label = DAMAGE_POPUP_SCRIPT.new()
	popup.setup(amount, melee)
	popup.global_position = global_position + Vector2(randf_range(-12, 12), -44)
	get_tree().current_scene.add_child(popup)
	var effect: Node2D = HIT_EFFECT_SCRIPT.new()
	var effect_kind := "spark" if enemy_type in ["hybrid", "boss"] else "pollution"
	effect.setup(effect_kind)
	effect.global_position = global_position + Vector2(0, -16)
	get_tree().current_scene.add_child(effect)
	if _sprite != null:
		_hit_flash_timer = 0.12
		_update_presentation()

func _die(_melee: bool) -> void:
	if is_dead:
		return
	is_dead = true
	pending_attack = ""
	queue_redraw()
	AudioManager.play_sfx("death")
	GameState.record_enemy_defeated(enemy_type == "boss", String(get_meta("expedition_source_key", "")))
	if enemy_type == "boss":
		GameState.notify("Boss 已被擊破，污染核心掉落。")
	for child in get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", true)
	set_physics_process(false)
	call_deferred("_spawn_drops", global_position)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", scale * 1.12, 0.22)
	tween.tween_property(self, "modulate:a", 0.0, 0.22)
	tween.finished.connect(queue_free)

func _spawn_drops(drop_position: Vector2) -> void:
	for item_id in drop_table.keys():
		var chance := 100 if enemy_type == "boss" else 55
		_try_spawn_drop(String(item_id), drop_table[item_id], chance, drop_position)
	for item_id in rare_drop_table.keys():
		var spec = rare_drop_table[item_id]
		var amount := 1
		var chance := 100 if enemy_type == "boss" else 8
		if typeof(spec) == TYPE_DICTIONARY:
			amount = int(spec.get("amount", 1))
			chance = int(spec.get("chance", chance))
		else:
			amount = int(spec)
		_try_spawn_drop(String(item_id), amount, chance, drop_position)

func _try_spawn_drop(item_id: String, amount_value, chance: int, drop_position: Vector2) -> void:
	var amount := int(amount_value)
	if amount <= 0:
		return
	var bounded_chance := clampi(chance, 0, 100)
	if randi() % 100 >= bounded_chance:
		return
	_spawn_pickup(item_id, amount, drop_position)

func _spawn_pickup(item_id: String, amount: int, drop_position: Vector2) -> void:
	var pickup: Area2D = PICKUP_SCRIPT.new()
	pickup.setup(item_id, amount)
	pickup.global_position = drop_position + Vector2(randf_range(-28, 28), randf_range(-22, 22))
	get_tree().current_scene.add_child(pickup)

func _enemy_texture(type_id: String) -> Texture2D:
	var atlas := _load_atlas_texture(ENEMY_ATLAS_PATH)
	if atlas == null:
		return PIXEL.new().enemy_texture(type_id)
	var index := PixelArtFactory.ENEMY_TYPES.find(type_id)
	if index < 0:
		index = 0
	var frame_size := PixelArtFactory.ENEMY_FRAME_SIZE
	var texture := AtlasTexture.new()
	texture.atlas = atlas
	texture.region = Rect2(index * frame_size.x, 0, frame_size.x, frame_size.y)
	return texture

func _load_atlas_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var loaded: Texture2D = load(path) as Texture2D
		if loaded != null:
			return loaded
	if FileAccess.file_exists(path):
		var image := Image.load_from_file(path)
		if image != null:
			return ImageTexture.create_from_image(image)
	return null

func _configure_behavior() -> void:
	contact_range = 42.0
	preferred_distance = 0.0
	ranged_range = 0.0
	ranged_attack_cooldown = 1.4
	can_fire_projectiles = false
	match enemy_type:
		"fast":
			contact_range = 36.0
			dash_cooldown = 0.35
		"ranged":
			contact_range = 34.0
			preferred_distance = 230.0
			ranged_range = 360.0
			ranged_attack_cooldown = 1.35
			can_fire_projectiles = true
		"heavy":
			contact_range = 58.0
		"flying":
			contact_range = 38.0
		"hybrid":
			contact_range = 46.0
			preferred_distance = 155.0
			ranged_range = 285.0
			ranged_attack_cooldown = 1.05
			can_fire_projectiles = true
		"boss":
			contact_range = 74.0
			preferred_distance = 150.0
			ranged_range = 360.0
			ranged_attack_cooldown = 1.15
			can_fire_projectiles = true

func _desired_direction(offset: Vector2, distance: float) -> Vector2:
	var desired := offset.normalized() if distance > 1.0 else Vector2.ZERO
	if enemy_type == "ranged":
		if distance < preferred_distance:
			desired = -desired * 0.7
		elif distance < ranged_range:
			desired = desired * 0.25
	elif enemy_type == "hybrid":
		if distance < preferred_distance:
			desired = -desired * 0.35
	elif enemy_type == "fast":
		if distance < 190.0 and dash_cooldown <= 0.0 and pending_attack.is_empty() and recovery_timer <= 0.0 and stagger_timer <= 0.0:
			_begin_attack("dash", offset)
	elif enemy_type == "flying":
		var orbit := desired.rotated(PI * 0.5) * 0.45
		desired = (desired + orbit).normalized()
	elif enemy_type == "heavy" and distance > contact_range:
		desired *= 0.8
	elif enemy_type == "boss":
		if distance < preferred_distance:
			desired = -desired * 0.22
		else:
			desired *= 0.58
	return desired

func _should_chase_target(distance: float) -> bool:
	if enemy_type == "boss":
		return true
	if _is_alerted:
		_is_alerted = distance <= TARGET_RELEASE_RANGE
	else:
		_is_alerted = distance <= TARGET_ACQUIRE_RANGE
	return _is_alerted

func _current_speed() -> float:
	if enemy_type == "fast" and dash_time > 0.0:
		return speed * 1.85
	if enemy_type == "flying":
		return speed * 1.08
	if enemy_type == "boss":
		return speed * 0.72
	return speed

func _animation_speed() -> float:
	match enemy_type:
		"fast":
			return 8.0
		"flying":
			return 9.0
		"boss":
			return 3.4
		_:
			return 4.8

func _contact_cooldown() -> float:
	match enemy_type:
		"fast":
			return 0.48
		"heavy":
			return 1.15
		"hybrid":
			return 0.85
		"boss":
			return 1.25
		_:
			return 0.75

func _fire_pollution_shot(direction: Vector2) -> void:
	if direction.length() < 0.1:
		return
	var pools := get_tree().get_nodes_in_group("projectile_pool")
	if pools.is_empty() or not pools[0].has_method("fire_projectile"):
		return
	var projectile_start := global_position + direction * 24.0
	if pools[0].fire_projectile(projectile_start, direction, max(1, int(damage * 0.75)), "player"):
		ranged_cooldown = ranged_attack_cooldown

func behavior_summary() -> Dictionary:
	return {
		"type": enemy_type,
		"contact_range": contact_range,
		"preferred_distance": preferred_distance,
		"ranged_range": ranged_range,
		"can_fire_projectiles": can_fire_projectiles,
		"ranged_cooldown": ranged_attack_cooldown,
		"dash_speed": _current_speed() if enemy_type == "fast" and dash_time > 0.0 else speed
	}
