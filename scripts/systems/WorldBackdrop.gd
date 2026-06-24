extends Node2D
class_name WorldBackdrop

const ASSET_LOADER := preload("res://scripts/utils/RuntimeAssetLoader.gd")

var mode := "village"
var map_size := Vector2i(60, 40)
var tile_size := 32
var world_seed := 9527
var tile_texture: Texture2D
var road_texture: Texture2D
var toxic_texture: Texture2D
var route_id := ""

func setup(new_mode: String, size_tiles: Vector2i, new_seed: int, new_route_id := "") -> void:
	mode = new_mode
	map_size = size_tiles
	world_seed = new_seed
	route_id = new_route_id
	tile_texture = _load_tile_texture()
	road_texture = ASSET_LOADER.load_png("res://assets/sprites/tiles/wasteland_road_variants_2p5d.png")
	toxic_texture = ASSET_LOADER.load_png("res://assets/sprites/tiles/toxic_mud_variants_2p5d.png")
	queue_redraw()

func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed
	var base := _base_color()
	var alt := _alt_color()
	var stain := _stain_color()
	var accent := _accent_color()
	for y in map_size.y:
		for x in map_size.x:
			var rect := Rect2(x * tile_size, y * tile_size, tile_size, tile_size)
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
				_draw_texture_variant(texture, rect, x, y)
				var tint_alpha := 0.34 + road_strength * 0.24
				if mode == "village":
					tint_alpha = 0.44 + road_strength * 0.24
				draw_rect(rect, Color(c.r, c.g, c.b, tint_alpha))
			else:
				draw_rect(rect, c)
			if road_strength > 0.0:
				_draw_road_detail(rect, x, y, road_strength, rng)
			if mode == "village":
				_draw_village_organic_detail(rect, x, y, road_strength, rng)
			if mode == "wasteland" and rng.randf() < 0.055:
				var crack_start := rect.position + Vector2(rng.randf_range(4, 12), rng.randf_range(6, 24))
				var crack_end := crack_start + Vector2(rng.randf_range(8, 24), rng.randf_range(-8, 10))
				draw_line(crack_start, crack_end, Color(0.04, 0.035, 0.03, 0.34), 1.0)
			if mode == "wasteland" and rng.randf() < 0.025:
				draw_circle(rect.position + Vector2(rng.randf_range(8, 24), rng.randf_range(8, 24)), rng.randf_range(2.0, 5.0), Color(0.22, 0.45, 0.25, 0.45))
			if mode == "wasteland" and rng.randf() < 0.018:
				draw_rect(rect.grow(-rng.randf_range(8.0, 13.0)), Color(accent.r, accent.g, accent.b, 0.16), true)

func _draw_road_detail(rect: Rect2, x: int, y: int, road_strength: float, rng: RandomNumberGenerator) -> void:
	var edge := _road_edge_color()
	draw_rect(rect, Color(0.10, 0.09, 0.08, 0.12 + road_strength * 0.16), true)
	if mode == "wasteland":
		if rng.randf() < 0.16:
			draw_circle(rect.position + Vector2(rng.randf_range(4, 28), rng.randf_range(4, 28)), rng.randf_range(1.5, 3.5), Color(edge.r, edge.g, edge.b, 0.12 + road_strength * 0.12))
		if x % 8 == 0 and rng.randf() < 0.65:
			draw_rect(Rect2(rect.position.x + rect.size.x * 0.47, rect.position.y + 9, 2, 9), Color(edge.r, edge.g, edge.b, 0.20), true)
		if rng.randf() < 0.28:
			draw_line(rect.position + Vector2(rng.randf_range(4, 12), rng.randf_range(8, 24)), rect.position + Vector2(rng.randf_range(18, 28), rng.randf_range(10, 28)), Color(0.05, 0.045, 0.04, 0.42), 1.0)
	else:
		if rng.randf() < 0.12:
			draw_circle(rect.position + Vector2(rng.randf_range(5, 27), rng.randf_range(5, 27)), rng.randf_range(1.0, 2.4), Color(edge.r, edge.g, edge.b, 0.08))
		if rng.randf() < 0.22:
			var start := rect.position + Vector2(rng.randf_range(4, 12), rng.randf_range(7, 23))
			var end := start + Vector2(rng.randf_range(9, 24), rng.randf_range(-6, 8))
			draw_line(start, end, Color(0.13, 0.11, 0.08, 0.28), 1.0)

func _draw_village_organic_detail(rect: Rect2, x: int, y: int, road_strength: float, rng: RandomNumberGenerator) -> void:
	if road_strength <= 0.0:
		if rng.randf() < 0.10:
			draw_circle(rect.position + Vector2(rng.randf_range(5, 27), rng.randf_range(5, 27)), rng.randf_range(2.0, 5.0), Color(0.20, 0.37, 0.17, 0.32))
		if rng.randf() < 0.06:
			draw_line(rect.position + Vector2(rng.randf_range(4, 10), rng.randf_range(8, 24)), rect.position + Vector2(rng.randf_range(18, 29), rng.randf_range(6, 26)), Color(0.09, 0.16, 0.08, 0.26), 1.0)
		return
	if rng.randf() < 0.18:
		draw_circle(rect.position + Vector2(rng.randf_range(5, 27), rng.randf_range(5, 27)), rng.randf_range(1.2, 3.0), Color(0.78, 0.61, 0.34, 0.18 + road_strength * 0.10))
	if rng.randf() < 0.24:
		var start := rect.position + Vector2(rng.randf_range(3, 12), rng.randf_range(7, 25))
		var end := start + Vector2(rng.randf_range(9, 24), rng.randf_range(-7, 7))
		draw_line(start, end, Color(0.34, 0.24, 0.13, 0.28), 1.0)

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
			var shoulder: bool = abs(y - int(map_size.y * 0.55)) <= 7 and x % 9 == 0
			return 0.62 if highway else (0.24 if shoulder else 0.0)
		if route_id == "old_factory":
			var grid_x: bool = abs(x - int(map_size.x * 0.52)) <= 2
			var grid_y: bool = abs(y - int(map_size.y * 0.50)) <= 2
			return 0.56 if grid_x or grid_y else 0.0
		if route_id == "toxic_marsh":
			var causeway: bool = abs(x - int(map_size.x * 0.43) - int(sin(float(y) * 0.10) * 5.0)) <= 2
			return 0.48 if causeway else 0.0
		var crystal_path: bool = abs(y - int(map_size.y * 0.68) - int(sin(float(x) * 0.18) * 6.0)) <= 2
		var branch: bool = abs(x - int(map_size.x * 0.5) - int(sin(float(y) * 0.11) * 4.0)) <= 1 and y > map_size.y * 0.30
		return 0.45 if crystal_path or branch else 0.0
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
		return Color8(34, 82, 52)
	if route_id == "old_factory":
		return Color8(56, 52, 47)
	if route_id == "scrap_highway":
		return Color8(75, 69, 57)
	if py < 0.27 and px > 0.36 and px < 0.68:
		return Color8(72, 39, 90)
	if px < 0.38 and py > 0.22 and py < 0.56:
		return Color8(75, 74, 70)
	if px > 0.60 and py > 0.24 and py < 0.62:
		return Color8(34, 82, 52)
	return Color8(39, 45, 38)

func _wasteland_zone_strength(x: int, y: int) -> float:
	if route_id in ["toxic_marsh", "old_factory", "scrap_highway"]:
		return 0.36
	var px: float = float(x) / max(1.0, float(map_size.x))
	var py: float = float(y) / max(1.0, float(map_size.y))
	if py < 0.27 and px > 0.36 and px < 0.68:
		return 0.36
	if px < 0.38 and py > 0.22 and py < 0.56:
		return 0.30
	if px > 0.60 and py > 0.24 and py < 0.62:
		return 0.42
	return 0.0

func _route_noise_color(x: int, y: int) -> Color:
	var px: float = float(x) / max(1.0, float(map_size.x))
	var py: float = float(y) / max(1.0, float(map_size.y))
	match route_id:
		"scrap_highway":
			if py > 0.36 and py < 0.70:
				return Color8(137, 104, 62)
			return Color8(78, 58, 42)
		"toxic_marsh":
			if px < 0.46:
				return Color8(30, 98, 58)
			return Color8(91, 83, 54)
		"crystal_scar":
			if py < 0.42 or abs(px - 0.52) < 0.10:
				return Color8(86, 48, 112)
			return Color8(70, 72, 78)
		"old_factory":
			if px > 0.45 and py < 0.68:
				return Color8(62, 78, 86)
			return Color8(108, 73, 48)
	return Color8(64, 55, 42)

func _route_noise_strength(x: int, y: int) -> float:
	if mode != "wasteland":
		return 0.0
	var wave := sin(float(x) * 0.11 + float(y) * 0.07)
	var broad := sin(float(x) * 0.025 - float(y) * 0.031)
	return clampf(0.12 + wave * 0.08 + broad * 0.11, 0.0, 0.34)

func _road_color() -> Color:
	match route_id:
		"scrap_highway":
			return Color8(78, 75, 68)
		"toxic_marsh":
			return Color8(76, 82, 57)
		"crystal_scar":
			return Color8(69, 63, 82)
		"old_factory":
			return Color8(64, 71, 74)
	if mode == "village":
		return Color8(178, 128, 67)
	return Color8(94, 82, 62)

func _road_edge_color() -> Color:
	match route_id:
		"scrap_highway":
			return Color8(204, 164, 86)
		"toxic_marsh":
			return Color8(132, 190, 72)
		"crystal_scar":
			return Color8(190, 110, 230)
		"old_factory":
			return Color8(216, 132, 54)
	return Color8(199, 159, 94)

func _stain_color() -> Color:
	match route_id:
		"scrap_highway":
			return Color8(124, 72, 38)
		"toxic_marsh":
			return Color8(33, 126, 55)
		"crystal_scar":
			return Color8(99, 45, 136)
		"old_factory":
			return Color8(43, 88, 95)
	return Color8(42, 97, 67)

func _accent_color() -> Color:
	match route_id:
		"scrap_highway":
			return Color8(220, 142, 58)
		"toxic_marsh":
			return Color8(108, 238, 78)
		"crystal_scar":
			return Color8(196, 92, 255)
		"old_factory":
			return Color8(255, 118, 54)
	return Color8(118, 180, 96)

func _base_color() -> Color:
	if mode == "village":
		return Color8(74, 69, 45)
	if route_id == "toxic_marsh":
		return Color8(26, 34, 27)
	if route_id == "old_factory":
		return Color8(31, 32, 33)
	if route_id == "crystal_scar":
		return Color8(31, 27, 38)
	if route_id == "scrap_highway":
		return Color8(44, 34, 25)
	return Color8(34, 31, 28)

func _alt_color() -> Color:
	if mode == "village":
		return Color8(139, 104, 58)
	if route_id == "toxic_marsh":
		return Color8(47, 78, 46)
	if route_id == "old_factory":
		return Color8(71, 66, 58)
	if route_id == "crystal_scar":
		return Color8(63, 45, 81)
	if route_id == "scrap_highway":
		return Color8(87, 66, 44)
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
		if road_strength > 0.0 and road_texture != null:
			return road_texture
		var zone := _wasteland_zone_color(x, y)
		if toxic_texture != null and zone.g > zone.r and zone.g > zone.b and _wasteland_zone_strength(x, y) >= 0.4:
			return toxic_texture
	return tile_texture

func _draw_texture_variant(texture: Texture2D, rect: Rect2, x: int, y: int) -> void:
	var variants: int = max(1, int(texture.get_width() / tile_size))
	var raw := sin(float(x * 928371 + y * 6173 + world_seed * 101))
	var variant := int(abs(raw) * 100000.0) % variants
	var src := Rect2(variant * tile_size, 0, tile_size, tile_size)
	draw_texture_rect_region(texture, rect, src)