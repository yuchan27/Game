extends TileMap
class_name WorldBackdrop

const TILE_SIZE := 32
const SOURCE_ID := 0

const TILE_BASE := Vector2i(0, 0)
const TILE_DARK := Vector2i(1, 0)
const TILE_ROAD := Vector2i(2, 0)
const TILE_HAZARD := Vector2i(3, 0)
const TILE_CRACK := Vector2i(4, 0)
const TILE_ACCENT := Vector2i(5, 0)

var mode := "wasteland"
var map_size := Vector2i(60, 40)
var world_seed := 9527
var route_id := ""


func setup(new_mode: String, size_tiles: Vector2i, new_seed: int, new_route_id := "") -> void:
	mode = new_mode
	map_size = size_tiles
	world_seed = new_seed
	route_id = new_route_id
	_build_tileset()
	_generate_map()


func _build_tileset() -> void:
	var image := Image.create(TILE_SIZE * 6, TILE_SIZE, false, Image.FORMAT_RGBA8)
	var palette := _palette()
	_fill_tile(image, TILE_BASE, palette[0], palette[1], false, false, false)
	_fill_tile(image, TILE_DARK, palette[1], palette[2], false, false, false)
	_fill_tile(image, TILE_ROAD, palette[3], palette[4], true, false, false)
	_fill_tile(image, TILE_HAZARD, palette[1], palette[5], true, true, false)
	_fill_tile(image, TILE_CRACK, palette[0], palette[2], false, false, true)
	_fill_tile(image, TILE_ACCENT, palette[6], palette[4], true, false, false)

	var texture := ImageTexture.create_from_image(image)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var atlas_source := TileSetAtlasSource.new()
	atlas_source.texture = texture
	atlas_source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for x in range(6):
		atlas_source.create_tile(Vector2i(x, 0))

	var new_tile_set := TileSet.new()
	new_tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	new_tile_set.add_source(atlas_source, SOURCE_ID)
	tile_set = new_tile_set


func _palette() -> Array[Color]:
	if mode == "guild":
		return [
			Color8(82, 80, 72), Color8(58, 58, 54), Color8(37, 38, 36),
			Color8(96, 89, 73), Color8(178, 139, 61), Color8(202, 55, 50), Color8(118, 112, 99)
		]

	match route_id:
		"toxic_marsh":
			return [Color8(57, 72, 49), Color8(35, 48, 36), Color8(25, 35, 30), Color8(92, 86, 57), Color8(179, 142, 63), Color8(78, 174, 79), Color8(76, 92, 58)]
		"crystal_scar":
			return [Color8(63, 60, 72), Color8(43, 42, 55), Color8(30, 30, 42), Color8(83, 76, 88), Color8(184, 139, 76), Color8(147, 87, 216), Color8(92, 85, 112)]
		"old_factory":
			return [Color8(68, 69, 65), Color8(44, 47, 49), Color8(27, 30, 33), Color8(87, 83, 73), Color8(184, 143, 67), Color8(204, 76, 46), Color8(92, 96, 98)]
		_:
			return [Color8(86, 75, 58), Color8(55, 51, 43), Color8(35, 35, 32), Color8(126, 96, 59), Color8(187, 144, 66), Color8(210, 118, 45), Color8(102, 87, 68)]


func _fill_tile(image: Image, tile_coords: Vector2i, base: Color, line: Color, rivets := false, hazard := false, cracked := false) -> void:
	var start_x := tile_coords.x * TILE_SIZE
	for y in range(TILE_SIZE):
		for x in range(TILE_SIZE):
			var shade := 0.0
			if ((x * 19 + y * 23 + tile_coords.x * 17 + int(world_seed)) % 17) == 0:
				shade = 0.07
			image.set_pixel(start_x + x, y, base.lerp(line, 0.08 + shade))

	for i in range(TILE_SIZE):
		image.set_pixel(start_x + i, 0, line.darkened(0.18))
		image.set_pixel(start_x + i, TILE_SIZE - 1, line.darkened(0.30))
		image.set_pixel(start_x, i, line.darkened(0.18))
		image.set_pixel(start_x + TILE_SIZE - 1, i, line.darkened(0.30))

	for i in range(3, TILE_SIZE - 3):
		image.set_pixel(start_x + i, 4, line.lightened(0.08))
		image.set_pixel(start_x + 4, i, line.lightened(0.06))

	if rivets:
		for p in [Vector2i(5, 5), Vector2i(26, 5), Vector2i(5, 26), Vector2i(26, 26)]:
			image.set_pixel(start_x + p.x, p.y, line.lightened(0.30))
			image.set_pixel(start_x + p.x + 1, p.y, line.lightened(0.16))
			image.set_pixel(start_x + p.x, p.y + 1, line.darkened(0.05))

	if hazard:
		for i in range(4, TILE_SIZE - 4):
			if int(i / 4) % 2 == 0:
				image.set_pixel(start_x + i, 4, line)
				image.set_pixel(start_x + i, TILE_SIZE - 5, line)
				image.set_pixel(start_x + 4, i, line)
				image.set_pixel(start_x + TILE_SIZE - 5, i, line)

	if cracked:
		_draw_crack(image, start_x + 9, 8, [Vector2i(5, 5), Vector2i(8, -1), Vector2i(3, 7)], line.darkened(0.25))
		_draw_crack(image, start_x + 21, 17, [Vector2i(-5, 3), Vector2i(7, 5), Vector2i(2, 6)], line.darkened(0.20))


func _draw_crack(image: Image, start_x: int, start_y: int, offsets: Array[Vector2i], color: Color) -> void:
	var current := Vector2i(start_x, start_y)
	for offset in offsets:
		var target := current + offset
		_draw_pixel_line(image, current, target, color)
		current = target


func _draw_pixel_line(image: Image, from_pos: Vector2i, to_pos: Vector2i, color: Color) -> void:
	var delta := to_pos - from_pos
	var steps: int = max(abs(delta.x), abs(delta.y))
	if steps <= 0:
		return
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var p := Vector2i(roundi(lerp(float(from_pos.x), float(to_pos.x), t)), roundi(lerp(float(from_pos.y), float(to_pos.y), t)))
		if p.x >= 0 and p.y >= 0 and p.x < image.get_width() and p.y < image.get_height():
			image.set_pixel(p.x, p.y, color)


func _generate_map() -> void:
	clear()
	for y in range(map_size.y):
		for x in range(map_size.x):
			set_cell(0, Vector2i(x, y), SOURCE_ID, _tile_for_position(x, y))


func _tile_for_position(x: int, y: int) -> Vector2i:
	var h := _hash2i(x, y)
	var road := _road_strength(x, y)
	if mode == "guild":
		if x <= 1 or y <= 1 or x >= map_size.x - 2 or y >= map_size.y - 2:
			return TILE_DARK
		if h % 17 == 0:
			return TILE_CRACK
		if h % 11 == 0:
			return TILE_ACCENT
		return TILE_BASE if h % 5 != 0 else TILE_DARK

	if road >= 0.70:
		return TILE_ROAD if h % 8 != 0 else TILE_ACCENT
	if road > 0.0:
		return TILE_BASE if h % 4 != 0 else TILE_CRACK
	if h % 23 == 0:
		return TILE_HAZARD
	if h % 13 == 0:
		return TILE_CRACK
	if h % 7 == 0:
		return TILE_ACCENT
	return TILE_DARK if h % 3 == 0 else TILE_BASE


func _road_strength(x: int, y: int) -> float:
	if mode == "guild":
		return 0.0
	var cx := float(map_size.x) * 0.5
	var spawn_road: bool = abs(float(x) - cx) <= 3.2 and y >= int(float(map_size.y) * 0.45)
	var mid_road: bool = abs(float(y) - float(map_size.y) * 0.52 - sin(float(x) * 0.08) * 2.0) <= 2.4
	var route_bias := 0.0
	if route_id == "toxic_marsh":
		route_bias = sin(float(x) * 0.05) * 1.8
	elif route_id == "crystal_scar":
		route_bias = sin(float(y) * 0.06) * 1.6
	elif route_id == "old_factory":
		route_bias = sin(float(x + y) * 0.04) * 1.4
	var route_path: bool = abs(float(x) - cx - route_bias) <= 2.0
	var shoulder: bool = abs(float(x) - cx - route_bias) <= 3.4 or abs(float(y) - float(map_size.y) * 0.52) <= 3.8
	return 0.78 if spawn_road or mid_road or route_path else (0.22 if shoulder else 0.0)


func _hash2i(x: int, y: int) -> int:
	var n := int(world_seed) + x * 374761393 + y * 668265263
	n = (n ^ (n >> 13)) * 1274126177
	return abs(n ^ (n >> 16))
