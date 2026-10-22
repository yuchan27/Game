extends CharacterBody2D
class_name WastelandEnemy

const PIXEL := preload("res://scripts/utils/PixelArtFactory.gd")
const PICKUP_SCRIPT := preload("res://scripts/components/Pickup.gd")
const DAMAGE_POPUP_SCRIPT := preload("res://scripts/components/DamagePopup.gd")
const HEALTH_BAR_SCRIPT := preload("res://scripts/components/EnemyHealthBar.gd")
const HIT_EFFECT_SCRIPT := preload("res://scripts/components/HitEffect.gd")
const ENEMY_ATLAS_PATH := "res://assets/sprites/enemies/polluted_enemy_six_types.png"

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
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if enemy_type == "boss":
		_sprite.scale = Vector2(1.9, 1.9)
		_sprite.position.y = -14
	_base_sprite_pos = _sprite.position
	_base_scale = _sprite.scale
	add_child(_sprite)
	_health_bar = HEALTH_BAR_SCRIPT.new()
	_health_bar.setup(116.0 if enemy_type == "boss" else 54.0)
	_health_bar.position = Vector2(0, -90 if enemy_type == "boss" else -54)
	_health_bar.visible = false
	add_child(_health_bar)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_phase += delta * _animation_speed()
	if _sprite != null:
		_sprite.position = _base_sprite_pos + Vector2(0, sin(_phase) * (3.5 if enemy_type == "flying" else 1.6))
		_sprite.scale = _base_scale * (1.0 + sin(_phase * 0.7) * 0.025)
	if target == null or not is_instance_valid(target):
		return
	var offset := target.global_position - global_position
	var distance := offset.length()
	var desired := _desired_direction(offset, distance)
	if _sprite != null and abs(offset.x) > 4.0:
		_sprite.flip_h = offset.x < 0.0
	stagger_timer = max(0.0, stagger_timer - delta)
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 880.0 * delta)
	var move_mult := 0.25 if stagger_timer > 0.0 else 1.0
	velocity = desired * _current_speed() * move_mult + knockback_velocity
	move_and_slide()
	attack_cooldown = max(0.0, attack_cooldown - delta)
	ranged_cooldown = max(0.0, ranged_cooldown - delta)
	dash_cooldown = max(0.0, dash_cooldown - delta)
	dash_time = max(0.0, dash_time - delta)
	if can_fire_projectiles and distance <= ranged_range and ranged_cooldown <= 0.0:
		_fire_pollution_shot(offset.normalized())
	if distance < contact_range and attack_cooldown <= 0.0:
		attack_cooldown = _contact_cooldown()
		GameState.take_damage(damage)

func apply_knockback(impulse: Vector2) -> void:
	if is_dead:
		return
	var resist := 0.30 if enemy_type == "boss" else (0.58 if enemy_type == "heavy" else 1.0)
	knockback_velocity = impulse * resist
	stagger_timer = max(stagger_timer, 0.12 * resist)

func take_damage(amount: int, melee := false) -> void:
	if is_dead:
		return
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
		_sprite.modulate = Color(1.0, 0.55, 0.45)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(_sprite, "position", _base_sprite_pos + Vector2(randf_range(-8, 8), -4), 0.04)
		tween.tween_property(_sprite, "modulate", Color.WHITE, 0.12)

func _die(_melee: bool) -> void:
	if is_dead:
		return
	is_dead = true
	AudioManager.play_sfx("death")
	GameState.record_enemy_defeated(enemy_type == "boss")
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
		if distance < 190.0 and dash_cooldown <= 0.0:
			dash_time = 0.18
			dash_cooldown = 1.2
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
