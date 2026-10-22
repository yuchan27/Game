extends Area2D
class_name RecyclerProjectile

const PIXEL := preload("res://scripts/utils/PixelArtFactory.gd")

var direction := Vector2.RIGHT
var speed := 560.0
var damage := 8
var life := 1.2
var max_life := 1.2
var is_active := true
var pool_owner: Node
var target_group := "enemy"
var pierce_remaining := 0
var hit_enemies: Array[Node] = []

func setup(start: Vector2, dir: Vector2, projectile_damage: int, new_target_group := "enemy") -> void:
	global_position = start
	direction = dir.normalized()
	damage = projectile_damage
	target_group = new_target_group
	life = max_life
	is_active = true
	visible = true
	monitoring = true
	set_physics_process(true)
	rotation = direction.angle()
	hit_enemies.clear()
	if target_group == "enemy":
		pierce_remaining = GameState.get_perk_level("armor_piercer")
	else:
		pierce_remaining = 0
	queue_redraw()

func setup_pooled(start: Vector2, dir: Vector2, projectile_damage: int, owner: Node, new_target_group := "enemy") -> void:
	pool_owner = owner
	setup(start, dir, projectile_damage, new_target_group)

func _ready() -> void:
	add_to_group("projectile")
	monitoring = true
	body_entered.connect(_on_body_entered)
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 7.0
	collision.shape = shape
	add_child(collision)

func _draw() -> void:
	if not is_active:
		return
	if target_group == "enemy":
		# High-craft piercing crossbow bolt (穿甲鋼鐵弩箭)
		# 1. Aerodynamic wind tracer trail
		draw_line(Vector2(-26, 0), Vector2(-6, 0), Color(0.96, 0.82, 0.38, 0.45), 2.0)
		# 2. Hardened alloy arrow shaft
		draw_line(Vector2(-16, 0), Vector2(7, 0), Color(0.15, 0.14, 0.16, 1.0), 3.0)
		draw_line(Vector2(-15, 0), Vector2(6, 0), Color(0.76, 0.74, 0.70, 1.0), 1.6)
		# 3. Barbed triangular steel broadhead
		var arrowhead := PackedVector2Array([
			Vector2(14, 0),
			Vector2(5, -4.5),
			Vector2(7, 0),
			Vector2(5, 4.5)
		])
		draw_colored_polygon(arrowhead, Color(0.95, 0.96, 1.0, 1.0))
		draw_polyline(arrowhead, Color(0.12, 0.14, 0.16, 1.0), 1.2, true)
		draw_line(Vector2(7, 0), Vector2(13, 0), Color(0.42, 0.84, 0.98, 0.9), 1.0)
		# 4. Crimson tactical fletching vanes at rear
		var top_vane := PackedVector2Array([Vector2(-15, 0), Vector2(-11, -4.2), Vector2(-7, 0)])
		var bot_vane := PackedVector2Array([Vector2(-15, 0), Vector2(-11, 4.2), Vector2(-7, 0)])
		draw_colored_polygon(top_vane, Color(0.88, 0.22, 0.24, 1.0))
		draw_colored_polygon(bot_vane, Color(0.88, 0.22, 0.24, 1.0))
		draw_circle(Vector2(-15, 0), 1.6, Color(0.98, 0.82, 0.32, 1.0))
	else:
		# Enemy toxic bio-spore projectile
		draw_circle(Vector2(0, 0), 5.5, Color(0.32, 0.88, 0.24, 0.95))
		draw_circle(Vector2(1, 0), 3.2, Color(0.82, 1.0, 0.45, 0.95))
		draw_circle(Vector2(-7, 0), 2.8, Color(0.24, 0.72, 0.18, 0.75))
		draw_circle(Vector2(-13, 0), 1.8, Color(0.18, 0.58, 0.14, 0.50))

func _physics_process(delta: float) -> void:
	if not is_active:
		return
	global_position += direction * speed * delta
	rotation = direction.angle()
	life -= delta
	if life <= 0.0:
		_release()

func _on_body_entered(body: Node) -> void:
	if not is_active:
		return
	if body.is_in_group(target_group):
		if hit_enemies.has(body):
			return
		hit_enemies.append(body)
		if body.has_method("take_damage"):
			body.take_damage(damage, false)
			if target_group == "enemy" and GameState.has_perk("arc_overload"):
				_trigger_arc_discharge(body.global_position, body)
		elif target_group == "player":
			GameState.take_damage(damage)

		if target_group == "enemy" and pierce_remaining > 0:
			pierce_remaining -= 1
			return
		_release()
	elif body is StaticBody2D or body.is_in_group("obstacle"):
		_release()

func _trigger_arc_discharge(origin: Vector2, hit_enemy: Node) -> void:
	var arc_dmg := 8 + GameState.get_perk_level("arc_overload") * 8
	var struck := 0
	for other in get_tree().get_nodes_in_group("enemy"):
		if other == hit_enemy or not (other is Node2D):
			continue
		var other_node := other as Node2D
		if origin.distance_to(other_node.global_position) <= 140.0:
			if other.has_method("take_damage"):
				other.call("take_damage", arc_dmg, false)
				struck += 1
				if struck >= 2:
					break

func deactivate() -> void:
	is_active = false
	visible = false
	set_deferred("monitoring", false)
	set_physics_process(false)
	global_position = Vector2(-100000, -100000)

func _release() -> void:
	if pool_owner != null and pool_owner.has_method("release"):
		pool_owner.release(self)
	else:
		call_deferred("queue_free")
