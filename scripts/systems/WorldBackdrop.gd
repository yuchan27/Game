extends Node2D
class_name WorldBackdrop

class DrawChunk extends Node2D:
	var backdrop: Node2D
	var tile_start := Vector2i.ZERO
	var tile_end := Vector2i.ZERO

	func _draw() -> void:
		if is_instance_valid(backdrop):
			backdrop.call("_draw_chunk", self, tile_start, tile_end)

const ASSET_LOADER := preload("res://scripts/utils/RuntimeAssetLoader.gd")
const CHUNK_TILE_SIZE := 16

var mode := "village"
var map_size := Vector2i(60, 40)
var tile_size := 32
var world_seed := 9527
var tile_texture: Texture2D
var road_texture: Texture2D
var toxic_texture: Texture2D
var crystal_texture: Texture2D
var factory_texture: Texture2D
var toxic_path_texture: Texture2D
var crystal_path_texture: Texture2D
var factory_path_texture: Texture2D
var route_id := ""
var _chunks: Array[Node2D] = []
var _tile_rng_states := PackedInt64Array()
var _batch_rects: Array = []
var _batch_lines: Array = []
var _batch_circles: Array = []

func setup(new_mode: String, size_tiles: Vector2i, new_seed: int, new_route_id := "") -> void:
	mode = new_mode
	map_size = size_tiles
	world_seed = new_seed
	route_id = new_route_id
	tile_texture = _load_tile_texture()
	road_texture = ASSET_LOADER.load_png("res://assets/sprites/tiles/wasteland_road_variants_2p5d.png")
	toxic_texture = ASSET_LOADER.load_png("res://assets/sprites/tiles/toxic_mud_variants_2p5d.png")
	crystal_texture = ASSET_LOADER.load_png("res://assets/sprites/tiles/crystal_ground_variants_2p5d.png")
	factory_texture = ASSET_LOADER.load_png("res://assets/sprites/tiles/factory_ground_variants_2p5d.png")
	toxic_path_texture = ASSET_LOADER.load_png("res://assets/sprites/tiles/toxic_path_variants_2p5d.png")
	crystal_path_texture = ASSET_LOADER.load_png("res://assets/sprites/tiles/crystal_path_variants_2p5d.png")
	factory_path_texture = ASSET_LOADER.load_png("res://assets/sprites/tiles/factory_path_variants_2p5d.png")
	_rebuild_chunks()


func _rebuild_chunks() -> void:
	for chunk in _chunks:
		if is_instance_valid(chunk):
			remove_child(chunk)
			chunk.queue_free()
	_chunks.clear()
	if map_size.x <= 0 or map_size.y <= 0:
		_tile_rng_states.clear()
		return
	_build_tile_rng_states()
	for y in range(0, map_size.y, CHUNK_TILE_SIZE):
		for x in range(0, map_size.x, CHUNK_TILE_SIZE):
			var chunk := DrawChunk.new()
			chunk.backdrop = self
			chunk.tile_start = Vector2i(x, y)
			chunk.tile_end = Vector2i(mini(x + CHUNK_TILE_SIZE, map_size.x), mini(y + CHUNK_TILE_SIZE, map_size.y))
			chunk.position = Vector2(x * tile_size, y * tile_size)
			chunk.name = "BackdropChunk_%d_%d" % [x, y]
			add_child(chunk)
			_chunks.append(chunk)
			chunk.queue_redraw()


func _build_tile_rng_states() -> void:
	_tile_rng_states.resize(map_size.x * map_size.y)
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed
	for y in range(map_size.y):
		for x in range(map_size.x):
			_tile_rng_states[y * map_size.x + x] = rng.state
			_draw_tile(null, rng, x, y, Vector2i.ZERO)


func _draw_chunk(target: CanvasItem, tile_start: Vector2i, tile_end: Vector2i) -> void:
	if _tile_rng_states.size() != map_size.x * map_size.y:
		return
	_batch_rects.clear()
	_batch_lines.clear()
	_batch_circles.clear()
	var rng := RandomNumberGenerator.new()
	for y in range(tile_start.y, tile_end.y):
		for x in range(tile_start.x, tile_end.x):
			rng.state = _tile_rng_states[y * map_size.x + x]
			_draw_tile(target, rng, x, y, tile_start)
	
	# Batch flush: draw rects, lines, circles in grouped streams to optimize 2D canvas draw calls
	for item in _batch_rects:
		target.draw_rect(item[0], item[1], item[2])
	for item in _batch_lines:
		target.draw_line(item[0], item[1], item[2], item[3])
	for item in _batch_circles:
		target.draw_circle(item[0], item[1], item[2])
	_batch_rects.clear()
	_batch_lines.clear()
	_batch_circles.clear()


func _draw_tile(target: CanvasItem, rng: RandomNumberGenerator, x: int, y: int, tile_origin: Vector2i) -> void:
	var base := _base_color()
	var alt := _alt_color()
	var stain := _stain_color()
	var accent := _accent_color()
	var rect := Rect2(Vector2((x - tile_origin.x) * tile_size, (y - tile_origin.y) * tile_size), Vector2(tile_size, tile_size))
	var c := base.lerp(alt, rng.randf_range(0.0, 0.42))
	if mode == "wasteland":
		c = c.lerp(_wasteland_zone_color(x, y), _wasteland_zone_strength(x, y))
		c = c.lerp(_route_noise_color(x, y), _route_noise_strength(x, y))
	elif mode == "village":
		c = c.lerp(_village_patch_color(x, y), _village_patch_strength(x, y))
	var road_strength := _road_strength(x, y)
	if road_strength > 0.0:
		c = c.lerp(_road_color(), road_strength)
	if mode == "wasteland" and rng.randf() < 0.11:
		c = c.lerp(stain, 0.42)
	var texture := _texture_for_tile(x, y, road_strength)
	if texture != null:
		_draw_texture_variant(target, texture, rect, x, y, road_strength)
		var tint_alpha := 0.08 + road_strength * 0.06
		if mode == "village":
			tint_alpha = 0.09 + road_strength * 0.05
		_draw_rect(target, rect, Color(c.r, c.g, c.b, tint_alpha))
	else:
		_draw_rect(target, rect, c)
	if road_strength > 0.0:
		_draw_road_detail(target, rect, x, y, road_strength, rng)
	if mode == "village":
		_draw_village_organic_detail(target, rect, x, y, road_strength, rng)
	if mode == "wasteland":
		_draw_biome_signature_detail(target, rect, x, y, road_strength, accent, stain, rng)
		if rng.randf() < 0.055:
			var crack_start := rect.position + Vector2(rng.randf_range(4, 12), rng.randf_range(6, 24))
			var crack_end := crack_start + Vector2(rng.randf_range(8, 24), rng.randf_range(-8, 10))
			_draw_line(target, crack_start, crack_end, Color(0.04, 0.035, 0.03, 0.38), 1.0)
		if rng.randf() < 0.025:
			_draw_circle(target, rect.position + Vector2(rng.randf_range(8, 24), rng.randf_range(8, 24)), rng.randf_range(2.0, 5.0), Color(stain.r, stain.g, stain.b, 0.46))
		if rng.randf() < 0.018:
			_draw_rect(target, rect.grow(-rng.randf_range(8.0, 13.0)), Color(accent.r, accent.g, accent.b, 0.18), true)


func _draw_biome_signature_detail(target: CanvasItem, rect: Rect2, x: int, y: int, road_strength: float, accent: Color, stain: Color, rng: RandomNumberGenerator) -> void:
	var roll_a := rng.randf()
	var roll_b := rng.randf()
	if target == null:
		return
	match route_id:
		"scrap_highway":
			# Cracked multi-lane highway median stripes & concrete curb blocks
			if road_strength >= 0.55 and x % 4 < 2:
				_draw_rect(target, Rect2(rect.position.x + 4, rect.position.y + 14, 20, 3), Color(0.96, 0.78, 0.22, 0.65), true)
			elif road_strength > 0.15 and road_strength < 0.55:
				_draw_rect(target, Rect2(rect.position.x + 2, rect.position.y + 2, 28, 4), Color(0.68, 0.62, 0.52, 0.50), true)
			if roll_a < 0.05:
				# Tire skid mark or blast scorch ring
				_draw_line(target, rect.position + Vector2(3, 6), rect.position + Vector2(28, 24), Color(0.08, 0.07, 0.06, 0.55), 2.0)
		"toxic_marsh":
			# Metal grate boardwalk planks on road, bubbling acid pools off-road
			if road_strength > 0.3:
				_draw_rect(target, Rect2(rect.position.x + 2, rect.position.y + 3, 28, 26), Color(0.25, 0.36, 0.28, 0.45), false)
				_draw_line(target, rect.position + Vector2(4, 16), rect.position + Vector2(28, 16), Color(0.38, 0.58, 0.38, 0.48), 1.0)
			elif roll_a < 0.14:
				_draw_circle(target, rect.position + Vector2(16, 16), 5.0 + roll_b * 6.0, Color(0.35, 0.92, 0.25, 0.45))
				_draw_circle(target, rect.position + Vector2(14, 14), 2.0 + roll_b * 2.5, Color(0.78, 1.0, 0.48, 0.60))
		"crystal_scar":
			# Glowing violet/magenta crystal veins & fracture lines
			if roll_a < 0.12:
				var p1 := rect.position + Vector2(4, 26)
				var p2 := rect.position + Vector2(16, 12)
				var p3 := rect.position + Vector2(28, 6)
				_draw_line(target, p1, p2, Color(0.88, 0.42, 1.0, 0.60), 1.5)
				_draw_line(target, p2, p3, Color(0.38, 0.92, 0.98, 0.55), 1.0)
			if (x + y) % 9 == 0 and roll_b < 0.40:
				_draw_rect(target, Rect2(rect.position.x + 12, rect.position.y + 10, 8, 12), Color(0.95, 0.55, 1.0, 0.52), true)
		"old_factory":
			# Industrial steel floor plate seams & yellow-black hazard stripes
			if (x % 4 == 0 or y % 4 == 0) and road_strength > 0.0:
				_draw_rect(target, Rect2(rect.position.x + 1, rect.position.y + 1, 30, 30), Color(0.14, 0.16, 0.18, 0.45), false)
			if road_strength > 0.4 and (x + y) % 5 == 0:
				_draw_rect(target, Rect2(rect.position.x + 2, rect.position.y + 26, 12, 4), Color(0.96, 0.72, 0.18, 0.70), true)
				_draw_rect(target, Rect2(rect.position.x + 16, rect.position.y + 26, 12, 4), Color(0.12, 0.12, 0.14, 0.70), true)
			elif roll_a < 0.07:
				# Glowing heat vent slit
				_draw_rect(target, Rect2(rect.position.x + 6, rect.position.y + 14, 20, 3), Color(1.0, 0.48, 0.18, 0.65), true)
		"ruined_metropolis":
			# Urban intersection crosswalk bars & shattered concrete slabs
			if road_strength > 0.4 and x % 6 == 0:
				_draw_rect(target, Rect2(rect.position.x + 6, rect.position.y + 4, 6, 24), Color(0.82, 0.80, 0.74, 0.36), true)
				_draw_rect(target, Rect2(rect.position.x + 18, rect.position.y + 4, 6, 24), Color(0.82, 0.80, 0.74, 0.36), true)
			elif roll_a < 0.06:
				_draw_rect(target, Rect2(rect.position.x + 5, rect.position.y + 6, 18, 14), Color(0.32, 0.30, 0.34, 0.34), true)
		"underground_facility":
			# High-tech cyan energy conduits & containment floor grid
			if road_strength > 0.35:
				_draw_line(target, rect.position + Vector2(0, 16), rect.position + Vector2(32, 16), Color(0.24, 0.88, 0.96, 0.42), 1.5)
			if (x % 5 == 0 and y % 5 == 0) or roll_a < 0.04:
				_draw_rect(target, Rect2(rect.position.x + 8, rect.position.y + 8, 16, 16), Color(0.18, 0.76, 0.88, 0.26), false)
		_:
			if roll_a < 0.03:
				_draw_circle(target, rect.position + Vector2(16, 16), 3.0, Color(accent.r, accent.g, accent.b, 0.25))


func _draw_road_detail(target: CanvasItem, rect: Rect2, x: int, y: int, road_strength: float, rng: RandomNumberGenerator) -> void:
	var edge := _road_edge_color()
	_draw_rect(target, rect, Color(0.10, 0.09, 0.08, 0.12 + road_strength * 0.16), true)
	if mode == "wasteland":
		if rng.randf() < 0.16:
			_draw_circle(target, rect.position + Vector2(rng.randf_range(4, 28), rng.randf_range(4, 28)), rng.randf_range(1.5, 3.5), Color(edge.r, edge.g, edge.b, 0.12 + road_strength * 0.12))
		if x % 8 == 0 and rng.randf() < 0.65:
			_draw_rect(target, Rect2(rect.position.x + rect.size.x * 0.47, rect.position.y + 9, 2, 9), Color(edge.r, edge.g, edge.b, 0.24), true)
		if rng.randf() < 0.28:
			_draw_line(target, rect.position + Vector2(rng.randf_range(4, 12), rng.randf_range(8, 24)), rect.position + Vector2(rng.randf_range(18, 28), rng.randf_range(10, 28)), Color(0.05, 0.045, 0.04, 0.42), 1.0)
	else:
		if rng.randf() < 0.12:
			_draw_circle(target, rect.position + Vector2(rng.randf_range(5, 27), rng.randf_range(5, 27)), rng.randf_range(1.0, 2.4), Color(edge.r, edge.g, edge.b, 0.08))
		if rng.randf() < 0.22:
			var start := rect.position + Vector2(rng.randf_range(4, 12), rng.randf_range(7, 23))
			var end := start + Vector2(rng.randf_range(9, 24), rng.randf_range(-6, 8))
			_draw_line(target, start, end, Color(0.13, 0.11, 0.08, 0.28), 1.0)

func _draw_village_organic_detail(target: CanvasItem, rect: Rect2, x: int, y: int, road_strength: float, rng: RandomNumberGenerator) -> void:
	if road_strength <= 0.0:
		if rng.randf() < 0.10:
			_draw_circle(target, rect.position + Vector2(rng.randf_range(5, 27), rng.randf_range(5, 27)), rng.randf_range(2.0, 5.0), Color(0.20, 0.37, 0.17, 0.32))
		if rng.randf() < 0.06:
			_draw_line(target, rect.position + Vector2(rng.randf_range(4, 10), rng.randf_range(8, 24)), rect.position + Vector2(rng.randf_range(18, 29), rng.randf_range(6, 26)), Color(0.09, 0.16, 0.08, 0.26), 1.0)
		return
	if rng.randf() < 0.18:
		_draw_circle(target, rect.position + Vector2(rng.randf_range(5, 27), rng.randf_range(5, 27)), rng.randf_range(1.2, 3.0), Color(0.78, 0.61, 0.34, 0.18 + road_strength * 0.10))
	if rng.randf() < 0.24:
		var start := rect.position + Vector2(rng.randf_range(3, 12), rng.randf_range(7, 25))
		var end := start + Vector2(rng.randf_range(9, 24), rng.randf_range(-7, 7))
		_draw_line(target, start, end, Color(0.34, 0.24, 0.13, 0.28), 1.0)

func _road_strength(x: int, y: int) -> float:
	if mode == "village":
		var cx := float(map_size.x) * 0.5
		var cy := float(map_size.y) * 0.5
		var plaza_shape := pow((float(x) - cx) / 10.5, 2.0) + pow((float(y) - cy) / 6.5, 2.0)
		var plaza: bool = plaza_shape <= 1.0
		var vertical_center := cx + sin(float(y) * 0.22) * 1.4
		var horizontal_center := cy + sin(float(x) * 0.18) * 1.2
		var vertical: bool = abs(float(x) - vertical_center) <= 2.2 and y >= 4 and y <= map_size.y - 2
		var horizontal: bool = abs(float(y) - horizontal_center) <= 2.2 and x >= 3 and x <= map_size.x - 2
		var shoulder: bool = plaza_shape <= 1.42 or abs(float(x) - vertical_center) <= 3.4 or abs(float(y) - horizontal_center) <= 3.4
		return 0.78 if plaza or vertical or horizontal else (0.22 if shoulder else 0.0)
	if mode == "guild":
		var hall: bool = x >= 8 and x <= 42 and y >= 6 and y <= 23
		var cross: bool = (x >= 23 and x <= 27) or (y >= 14 and y <= 17)
		return 0.65 if hall and cross else 0.0
	if mode == "wasteland":
		if route_id == "scrap_highway":
			var highway: bool = abs(y - int(map_size.y * 0.55) - int(sin(float(x) * 0.08) * 3.0)) <= 3
			var north_south_spur: bool = abs(x - int(map_size.x * 0.50)) <= 2 and y >= int(map_size.y * 0.52)
			var shoulder: bool = abs(y - int(map_size.y * 0.55)) <= 7 and x % 9 == 0
			return 0.66 if (highway or north_south_spur) else (0.24 if shoulder else 0.0)
		if route_id == "old_factory":
			var grid_x: bool = abs(x - int(map_size.x * 0.52)) <= 2 or abs(x - int(map_size.x * 0.28)) <= 1 or abs(x - int(map_size.x * 0.74)) <= 1
			var grid_y: bool = abs(y - int(map_size.y * 0.50)) <= 2 or abs(y - int(map_size.y * 0.28)) <= 1
			return 0.60 if grid_x or grid_y else 0.0
		if route_id == "toxic_marsh":
			var causeway: bool = abs(x - int(map_size.x * 0.46) - int(sin(float(y) * 0.10) * 5.0)) <= 2
			var cross_bridge: bool = abs(y - int(map_size.y * 0.48)) <= 1 and x >= int(map_size.x * 0.22) and x <= int(map_size.x * 0.78)
			return 0.54 if (causeway or cross_bridge) else 0.0
		if route_id == "ruined_metropolis":
			var ave_x: bool = (x % 28 >= 12 and x % 28 <= 15)
			var ave_y: bool = (y % 24 >= 10 and y % 24 <= 13)
			return 0.62 if (ave_x or ave_y) else 0.0
		if route_id == "underground_facility":
			var ring_dist := Vector2(float(x) - map_size.x * 0.5, float(y) - map_size.y * 0.46).length()
			var ring: bool = abs(ring_dist - 24.0) <= 2.0
			var spine: bool = abs(x - int(map_size.x * 0.5)) <= 2 or abs(y - int(map_size.y * 0.46)) <= 2
			return 0.64 if (ring or spine) else 0.0
		var crystal_path: bool = abs(y - int(map_size.y * 0.68) - int(sin(float(x) * 0.18) * 6.0)) <= 2
		var branch: bool = abs(x - int(map_size.x * 0.5) - int(sin(float(y) * 0.11) * 4.0)) <= 2 and y > map_size.y * 0.22
		return 0.50 if crystal_path or branch else 0.0
	return 0.0

func _village_patch_color(x: int, y: int) -> Color:
	var wave := sin(float(x) * 0.17 + float(y) * 0.09)
	if wave > 0.42:
		return Color8(128, 97, 54)
	if wave < -0.38:
		return Color8(53, 93, 48)
	return Color8(78, 65, 43)

func _village_patch_strength(x: int, y: int) -> float:
	var wave := sin(float(x) * 0.13 - float(y) * 0.19) + sin(float(x) * 0.035 + float(y) * 0.051)
	return clampf(0.08 + wave * 0.08, 0.0, 0.24)

func _wasteland_zone_color(x: int, y: int) -> Color:
	var px: float = float(x) / max(1.0, float(map_size.x))
	var py: float = float(y) / max(1.0, float(map_size.y))
	if route_id == "toxic_marsh":
		return Color8(28, 94, 48)
	if route_id == "old_factory":
		return Color8(62, 54, 46)
	if route_id == "scrap_highway":
		return Color8(88, 72, 52)
	if route_id == "ruined_metropolis":
		return Color8(58, 56, 64)
	if route_id == "underground_facility":
		return Color8(28, 52, 68)
	if py < 0.27 and px > 0.36 and px < 0.68:
		return Color8(78, 38, 102)
	if px < 0.38 and py > 0.22 and py < 0.56:
		return Color8(75, 74, 70)
	if px > 0.60 and py > 0.24 and py < 0.62:
		return Color8(34, 82, 52)
	return Color8(48, 36, 64)

func _wasteland_zone_strength(x: int, y: int) -> float:
	if route_id in ["toxic_marsh", "old_factory", "scrap_highway", "ruined_metropolis", "underground_facility"]:
		return 0.40
	var px: float = float(x) / max(1.0, float(map_size.x))
	var py: float = float(y) / max(1.0, float(map_size.y))
	if py < 0.27 and px > 0.36 and px < 0.68:
		return 0.42
	if px < 0.38 and py > 0.22 and py < 0.56:
		return 0.30
	if px > 0.60 and py > 0.24 and py < 0.62:
		return 0.42
	return 0.28

func _route_noise_color(x: int, y: int) -> Color:
	var px: float = float(x) / max(1.0, float(map_size.x))
	var py: float = float(y) / max(1.0, float(map_size.y))
	match route_id:
		"scrap_highway":
			if py > 0.36 and py < 0.70:
				return Color8(146, 108, 60)
			return Color8(84, 62, 42)
		"toxic_marsh":
			if px < 0.52 or (x + y) % 7 < 3:
				return Color8(34, 118, 56)
			return Color8(86, 82, 48)
		"crystal_scar":
			if py < 0.46 or abs(px - 0.52) < 0.14:
				return Color8(102, 48, 138)
			return Color8(68, 58, 86)
		"old_factory":
			if px > 0.42 and py < 0.70:
				return Color8(58, 76, 88)
			return Color8(116, 74, 44)
		"ruined_metropolis":
			if (x / 14 + y / 12) % 2 == 0:
				return Color8(74, 70, 78)
			return Color8(92, 68, 54)
		"underground_facility":
			if abs(px - 0.5) < 0.25 and abs(py - 0.46) < 0.25:
				return Color8(32, 92, 116)
			return Color8(42, 54, 68)
	return Color8(64, 55, 42)

func _route_noise_strength(x: int, y: int) -> float:
	if mode != "wasteland":
		return 0.0
	var wave := sin(float(x) * 0.11 + float(y) * 0.07)
	var broad := sin(float(x) * 0.025 - float(y) * 0.031)
	return clampf(0.14 + wave * 0.08 + broad * 0.11, 0.0, 0.36)

func _road_color() -> Color:
	match route_id:
		"scrap_highway":
			return Color8(58, 54, 52)
		"toxic_marsh":
			return Color8(48, 60, 50)
		"crystal_scar":
			return Color8(54, 40, 76)
		"old_factory":
			return Color8(56, 60, 68)
		"ruined_metropolis":
			return Color8(66, 66, 72)
		"underground_facility":
			return Color8(46, 68, 82)
	if mode == "village":
		return Color8(178, 128, 67)
	return Color8(94, 82, 62)

func _road_edge_color() -> Color:
	match route_id:
		"scrap_highway":
			return Color8(228, 178, 82)
		"toxic_marsh":
			return Color8(118, 224, 68)
		"crystal_scar":
			return Color8(218, 108, 255)
		"old_factory":
			return Color8(238, 172, 34)
		"ruined_metropolis":
			return Color8(188, 182, 168)
		"underground_facility":
			return Color8(72, 224, 246)
	return Color8(199, 159, 94)

func _stain_color() -> Color:
	match route_id:
		"scrap_highway":
			return Color8(132, 76, 38)
		"toxic_marsh":
			return Color8(36, 142, 58)
		"crystal_scar":
			return Color8(112, 46, 156)
		"old_factory":
			return Color8(44, 92, 102)
		"ruined_metropolis":
			return Color8(96, 64, 52)
		"underground_facility":
			return Color8(36, 124, 148)
	return Color8(42, 97, 67)

func _accent_color() -> Color:
	match route_id:
		"scrap_highway":
			return Color8(228, 148, 58)
		"toxic_marsh":
			return Color8(112, 244, 78)
		"crystal_scar":
			return Color8(206, 96, 255)
		"old_factory":
			return Color8(255, 124, 54)
		"ruined_metropolis":
			return Color8(232, 168, 92)
		"underground_facility":
			return Color8(76, 236, 255)
	return Color8(118, 180, 96)

func _base_color() -> Color:
	if mode == "village":
		return Color8(74, 69, 45)
	if route_id == "toxic_marsh":
		return Color8(28, 48, 26)
	if route_id == "old_factory":
		return Color8(46, 48, 54)
	if route_id == "crystal_scar":
		return Color8(36, 26, 52)
	if route_id == "scrap_highway":
		return Color8(78, 62, 44)
	if route_id == "ruined_metropolis":
		return Color8(38, 36, 40)
	if route_id == "underground_facility":
		return Color8(20, 28, 36)
	return Color8(34, 31, 28)

func _alt_color() -> Color:
	if mode == "village":
		return Color8(139, 104, 58)
	if route_id == "toxic_marsh":
		return Color8(56, 110, 42)
	if route_id == "old_factory":
		return Color8(78, 82, 94)
	if route_id == "crystal_scar":
		return Color8(82, 48, 118)
	if route_id == "scrap_highway":
		return Color8(124, 98, 68)
	if route_id == "ruined_metropolis":
		return Color8(72, 68, 74)
	if route_id == "underground_facility":
		return Color8(42, 64, 78)
	return Color8(50, 44, 38)

func _load_tile_texture() -> Texture2D:
	var path := "res://assets/sprites/tiles/village_ground_variants_2p5d.png"
	if mode == "guild":
		path = "res://assets/sprites/tiles/guild_ground_variants_2p5d.png"
	elif mode == "wasteland":
		path = "res://assets/sprites/tiles/wasteland_ground_variants_2p5d.png"
	return ASSET_LOADER.load_png(path)

func _texture_for_tile(x: int, y: int, road_strength: float) -> Texture2D:
	if mode == "wasteland":
		if road_strength > 0.0:
			match route_id:
				"scrap_highway":
					return road_texture if road_texture != null else tile_texture
				"toxic_marsh":
					return toxic_path_texture if toxic_path_texture != null else road_texture
				"crystal_scar":
					return crystal_path_texture if crystal_path_texture != null else crystal_texture
				"old_factory":
					return factory_path_texture if factory_path_texture != null else factory_texture
				_:
					return road_texture if road_texture != null else tile_texture
		else:
			match route_id:
				"toxic_marsh":
					return toxic_texture if toxic_texture != null else tile_texture
				"crystal_scar":
					return crystal_texture if crystal_texture != null else tile_texture
				"old_factory":
					return factory_texture if factory_texture != null else tile_texture
				"scrap_highway":
					return tile_texture
				_:
					var zone := _wasteland_zone_color(x, y)
					if toxic_texture != null and zone.g > zone.r and zone.g > zone.b and _wasteland_zone_strength(x, y) >= 0.38:
						return toxic_texture
					return tile_texture
	return tile_texture

func _draw_texture_variant(target: CanvasItem, texture: Texture2D, rect: Rect2, x: int, y: int, road_strength := 0.0) -> void:
	if target == null:
		return
	if texture.get_width() >= 512 and texture.get_height() >= 128:
		var macro_idx := _macro_block_index(texture, x, y, road_strength)
		var src_2d := Rect2(macro_idx * 128 + (x % 4) * tile_size, (y % 4) * tile_size, tile_size, tile_size)
		target.draw_texture_rect_region(texture, rect, src_2d)
		return
	var variants: int = max(1, int(texture.get_width() / tile_size))
	var raw := sin(float(x * 928371 + y * 6173 + world_seed * 101))
	var variant := int(abs(raw) * 100000.0) % variants
	var src := Rect2(variant * tile_size, 0, tile_size, tile_size)
	target.draw_texture_rect_region(texture, rect, src)

func _macro_block_index(texture: Texture2D, x: int, y: int, road_strength: float) -> int:
	var block_hash: int = absi(int(world_seed) + int(x / 4) * 374761 + int(y / 4) * 668265)
	if mode == "guild":
		if road_strength > 0.4:
			return 2 if (x / 4 + y / 4) % 3 == 0 else 0
		return 0 if block_hash % 4 != 0 else 1
	if texture == road_texture or texture == toxic_path_texture or texture == crystal_path_texture or texture == factory_path_texture:
		match route_id:
			"scrap_highway":
				return 0 if block_hash % 3 != 0 else 1
			"toxic_marsh":
				return 0 if block_hash % 4 != 0 else 1
			"crystal_scar":
				return 0 if block_hash % 4 != 0 else 1
			"old_factory":
				return 0 if block_hash % 3 != 0 else 2
			"ruined_metropolis":
				return 2
			"underground_facility":
				return 3
			_:
				return block_hash % 4
	if texture == toxic_texture or texture == crystal_texture or texture == factory_texture:
		return block_hash % 4
	match route_id:
		"scrap_highway":
			return block_hash % 4
		"old_factory":
			return block_hash % 4
		"ruined_metropolis":
			return 2 if block_hash % 4 != 0 else 1
		"underground_facility":
			return 3 if block_hash % 3 != 0 else 2
		_:
			return block_hash % 4


func _draw_rect(target: CanvasItem, rect: Rect2, color: Color, filled: bool = true) -> void:
	if target != null:
		_batch_rects.append([rect, color, filled])


func _draw_line(target: CanvasItem, from: Vector2, to: Vector2, color: Color, width: float = 1.0) -> void:
	if target != null:
		_batch_lines.append([from, to, color, width])


func _draw_circle(target: CanvasItem, position: Vector2, radius: float, color: Color) -> void:
	if target != null:
		_batch_circles.append([position, radius, color])
