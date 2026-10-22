extends Node2D
class_name WastelandAtmosphere

const NUM_PARTICLES := 48
const VIEW_W := 1440.0
const VIEW_H := 880.0

var route_id := "scrap_highway"
var particles: Array[Dictionary] = []
var target_player: Node2D
var clock := 0.0
var modulate_node: CanvasModulate

func setup(new_route_id: String, player_node: Node2D) -> void:
	route_id = new_route_id
	target_player = player_node
	z_index = 8
	
	_setup_canvas_modulate()
	_setup_particles()
	set_process(true)


func _setup_canvas_modulate() -> void:
	if modulate_node == null:
		modulate_node = CanvasModulate.new()
		modulate_node.name = "BiomeCanvasModulate"
		add_child(modulate_node)
	modulate_node.color = _biome_modulate_color()


func _setup_particles() -> void:
	particles.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 771923
	for i in range(NUM_PARTICLES):
		particles.append({
			"rel_pos": Vector2(rng.randf_range(-VIEW_W * 0.5, VIEW_W * 0.5), rng.randf_range(-VIEW_H * 0.5, VIEW_H * 0.5)),
			"speed": Vector2(rng.randf_range(-18.0, 32.0), rng.randf_range(-14.0, 16.0)),
			"size": rng.randf_range(1.6, 3.6),
			"alpha_base": rng.randf_range(0.30, 0.75),
			"phase": rng.randf_range(0.0, TAU),
			"freq": rng.randf_range(1.2, 3.2),
			"extra_type": rng.randi() % 3
		})


func _biome_modulate_color() -> Color:
	match route_id:
		"scrap_highway":
			return Color(1.04, 0.96, 0.88) # Warm dusty wasteland sun
		"toxic_marsh":
			return Color(0.82, 0.98, 0.84) # Sickly luminescent emerald swamp
		"crystal_scar":
			return Color(0.84, 0.78, 1.02) # Arcane deep twilight amethyst violet
		"old_factory":
			return Color(1.02, 0.88, 0.78) # Smoldering foundry furnace ember glow
		"ruined_metropolis":
			return Color(0.88, 0.92, 0.98) # Cold concrete slate blue
		"underground_facility":
			return Color(0.82, 0.94, 0.98) # Sterile laboratory cyan
		_:
			return Color(1.0, 1.0, 1.0)


func _process(delta: float) -> void:
	clock += delta
	if target_player != null and is_instance_valid(target_player):
		global_position = target_player.global_position
	var wind := _biome_wind()
	for p in particles:
		var spd: Vector2 = p["speed"] + wind
		var pos: Vector2 = p["rel_pos"] + spd * delta
		var half_w := VIEW_W * 0.5
		var half_h := VIEW_H * 0.5
		if pos.x < -half_w:
			pos.x += VIEW_W
		elif pos.x > half_w:
			pos.x -= VIEW_W
		if pos.y < -half_h:
			pos.y += VIEW_H
		elif pos.y > half_h:
			pos.y -= VIEW_H
		p["rel_pos"] = pos
	queue_redraw()


func _biome_wind() -> Vector2:
	match route_id:
		"scrap_highway":
			return Vector2(40.0, 6.0)
		"toxic_marsh":
			return Vector2(-8.0, -20.0)
		"crystal_scar":
			return Vector2(12.0, -10.0)
		"old_factory":
			return Vector2(6.0, -28.0)
		_:
			return Vector2(14.0, 0.0)


func _biome_particle_color() -> Color:
	match route_id:
		"scrap_highway":
			return Color(0.96, 0.82, 0.44) # Golden dust
		"toxic_marsh":
			return Color(0.42, 0.96, 0.30) # Acid glowing spores
		"crystal_scar":
			return Color(0.82, 0.48, 1.0) # Violet resonance dust
		"old_factory":
			return Color(1.0, 0.58, 0.20) # Furnace embers
		_:
			return Color(0.85, 0.82, 0.75)


func _draw() -> void:
	var base_col := _biome_particle_color()
	for p in particles:
		var pos: Vector2 = p["rel_pos"]
		var sine_mod: float = sin(clock * float(p["freq"]) + float(p["phase"]))
		var cur_alpha: float = clampf(float(p["alpha_base"]) + sine_mod * 0.25, 0.10, 0.92)
		var sz: float = float(p["size"])
		var col := Color(base_col.r, base_col.g, base_col.b, cur_alpha)
		match route_id:
			"scrap_highway":
				# Wind-streaked golden dust dash
				draw_line(pos, pos + Vector2(sz * 2.5, 0.8), col, 1.4)
			"crystal_scar":
				# Shimmering crystal diamond
				var pts := PackedVector2Array([
					pos + Vector2(0, -sz),
					pos + Vector2(sz * 0.7, 0),
					pos + Vector2(0, sz),
					pos + Vector2(-sz * 0.7, 0)
				])
				draw_colored_polygon(pts, col)
				if sz > 2.4:
					draw_circle(pos, sz * 0.35, Color(0.6, 0.95, 1.0, cur_alpha * 0.9))
			"toxic_marsh":
				# Glowing spore bubble
				draw_circle(pos, sz, col)
				draw_circle(pos, sz * 0.4, Color(0.85, 1.0, 0.6, cur_alpha * 0.9))
			"old_factory":
				# Rising flame ember
				draw_circle(pos, sz, col)
				if sz > 2.2:
					draw_circle(pos + Vector2(0, -sz * 0.3), sz * 0.45, Color(1.0, 0.92, 0.4, cur_alpha * 0.9))
			_:
				draw_circle(pos, sz, col)
				if sz > 2.2:
					draw_circle(pos, sz * 0.45, Color(1.0, 1.0, 1.0, cur_alpha * 0.85))
