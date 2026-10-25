extends Node2D
class_name AttackFlash

var effect_id := "slash_rust"
var direction := Vector2.RIGHT
var color_primary := Color8(255, 178, 58)
var color_secondary := Color8(54, 230, 238)
var lifetime := 0.24
var age := 0.0
var swing_sign := 1.0

func setup(new_effect_id: String, new_direction: Vector2, strength := 1.0, combo_sign := 1.0) -> void:
	effect_id = new_effect_id
	age = 0.0
	direction = new_direction.normalized()
	if direction.length() < 0.1:
		direction = Vector2.RIGHT
	swing_sign = -1.0 if combo_sign < 0.0 else 1.0
	lifetime = 0.25 if (effect_id.begins_with("slash") or effect_id.begins_with("slam")) else 0.16
	if effect_id.contains("acid"):
		color_primary = Color8(110, 240, 82)
		color_secondary = Color8(208, 255, 125)
	elif effect_id.contains("blade"):
		color_primary = Color8(92, 242, 255)
		color_secondary = Color8(235, 252, 255)
	elif effect_id.contains("heavy") or effect_id.contains("slam") or effect_id.contains("explosive"):
		color_primary = Color8(255, 128, 42)
		color_secondary = Color8(255, 224, 112)
	elif effect_id.contains("coil") or effect_id.contains("spark"):
		color_primary = Color8(54, 229, 244)
		color_secondary = Color8(255, 187, 60)
	elif effect_id.contains("shotgun"):
		color_primary = Color8(255, 164, 52)
		color_secondary = Color8(255, 236, 148)
	elif effect_id.contains("pipe"):
		color_primary = Color8(255, 188, 72)
		color_secondary = Color8(91, 226, 238)
	scale = Vector2.ONE * clampf(strength, 0.7, 1.55)
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	age += delta
	if age >= lifetime:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var t := clampf(age / max(lifetime, 0.01), 0.0, 1.0)
	var alpha := 1.0 - t
	if effect_id.begins_with("slam"):
		_draw_slam(t, alpha)
	elif effect_id.begins_with("muzzle"):
		_draw_muzzle(t, alpha)
	elif effect_id.begins_with("scan") or effect_id.begins_with("magnet"):
		_draw_tool_pulse(t, alpha)
	elif effect_id.begins_with("acid"):
		_draw_muzzle(t, alpha)
		_draw_tool_pulse(t, alpha * 0.55)
	else:
		_draw_slash(t, alpha)

func _draw_slash(t: float, alpha: float) -> void:
	var eased := smoothstep(0.20, 0.58, t)
	var base_ang := direction.angle()
	var spread_mult := 1.24 if effect_id.contains("heavy") else (1.12 if effect_id.contains("blade") else 1.04)
	var radius := lerpf(38.0, 62.0, eased) * spread_mult
	var pivot := direction * 10.0 + Vector2(0, -4)
	var sweep_head := lerpf(-1.50, 1.30, eased) * swing_sign
	var sweep_tail := lerpf(-1.50, 1.30, smoothstep(0.20, 0.58, maxf(0.0, t - 0.15))) * swing_sign
	var a0 := minf(sweep_head, sweep_tail)
	var a1 := maxf(sweep_head, sweep_tail)
	if a1 - a0 < 0.35:
		a1 = a0 + 0.35

	var steps := 18
	var pts_outer := PackedVector2Array()
	var pts_mid := PackedVector2Array()
	var pts_inner := PackedVector2Array()
	for i in range(steps + 1):
		var u := float(i) / float(steps)
		var ang := base_ang + lerpf(a0, a1, u)
		var env := sin(u * PI)
		var r_out := radius + env * 8.0
		var r_mid := r_out - (4.5 + env * 3.5)
		var r_in := r_out - (10.0 + env * 8.0)
		var dir_pt := Vector2(cos(ang), sin(ang) * 0.84)
		pts_outer.append((pivot + dir_pt * r_out).round())
		pts_mid.append((pivot + dir_pt * r_mid).round())
		pts_inner.append((pivot + dir_pt * r_in).round())

	var poly_wake := PackedVector2Array()
	poly_wake.append_array(pts_outer)
	for i in range(pts_inner.size() - 1, -1, -1):
		poly_wake.append(pts_inner[i])
	if poly_wake.size() >= 6:
		draw_colored_polygon(poly_wake, Color(color_primary.r, color_primary.g, color_primary.b, alpha * 0.42))

	var poly_core := PackedVector2Array()
	poly_core.append_array(pts_outer)
	for i in range(pts_mid.size() - 1, -1, -1):
		poly_core.append(pts_mid[i])
	if poly_core.size() >= 6:
		draw_colored_polygon(poly_core, Color(color_secondary.r, color_secondary.g, color_secondary.b, alpha * 0.78))

	if pts_outer.size() >= 2:
		draw_polyline(pts_outer, Color(0.96, 0.99, 1.0, alpha * 0.94), 2.0, false)

	for i in range(6):
		var spark_u := float(i) / 5.0
		var spark_ang := base_ang + lerpf(a0, a1, spark_u)
		var spark_dir := Vector2(cos(spark_ang), sin(spark_ang) * 0.84)
		var spark_pos := pivot + spark_dir * (radius + 4.0 + float(i * 3) * eased)
		draw_rect(Rect2(spark_pos.round(), Vector2(3, 2)), Color(color_secondary.r, color_secondary.g, color_secondary.b, alpha * 0.85))

func _draw_slam(t: float, alpha: float) -> void:
	var center := direction * 34.0 + Vector2(0, -4)
	var radius := lerpf(18.0, 68.0, t)
	draw_arc(center, radius, 0.0, TAU, 36, Color(color_primary.r, color_primary.g, color_primary.b, alpha * 0.9), 5.0)
	draw_arc(center, radius * 0.68, 0.0, TAU, 28, Color(color_secondary.r, color_secondary.g, color_secondary.b, alpha * 0.75), 2.5)
	for i in range(6):
		var ang := direction.angle() + float(i - 2.5) * 0.45
		var ray_dir := Vector2(cos(ang), sin(ang))
		draw_line(center + ray_dir * 8.0, center + ray_dir * (radius + 8.0), Color(color_secondary.r, color_secondary.g, color_secondary.b, alpha * 0.7), 2.0)

func _draw_muzzle(t: float, alpha: float) -> void:
	var start := Vector2.ZERO
	var end := direction * (24.0 if effect_id.contains("shotgun") or effect_id.contains("explosive") else 16.0)
	var normal := direction.rotated(PI * 0.5)
	# Clean directional muzzle spark & core burst anchored right at the weapon muzzle tip
	draw_line(start, end, Color(color_secondary.r, color_secondary.g, color_secondary.b, alpha * 0.95), 3.0)
	draw_line(start - normal * 7.0, start + normal * 7.0, Color(color_primary.r, color_primary.g, color_primary.b, alpha * 0.9), 2.0)
	if effect_id.contains("shotgun") or effect_id.contains("explosive"):
		draw_line(start, end + normal * 10.0, Color(color_primary.r, color_primary.g, color_primary.b, alpha * 0.75), 2.0)
		draw_line(start, end - normal * 10.0, Color(color_primary.r, color_primary.g, color_primary.b, alpha * 0.75), 2.0)
	draw_circle(start + direction * 4.0, 5.5 * (1.0 - t * 0.4), Color(color_primary.r, color_primary.g, color_primary.b, alpha))
	draw_circle(start + direction * 2.0, 3.0, Color(1.0, 0.98, 0.85, alpha * 0.95))

func _draw_tool_pulse(t: float, alpha: float) -> void:
	var radius := lerpf(18.0, 54.0, t)
	draw_arc(Vector2(0, -10), radius, 0.0, TAU, 64, Color(color_secondary.r, color_secondary.g, color_secondary.b, alpha), 3.0)
	draw_circle(direction * 32.0 + Vector2(0, -8), 5.0, Color(color_primary.r, color_primary.g, color_primary.b, alpha))
