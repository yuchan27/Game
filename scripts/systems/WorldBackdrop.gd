extends TileMap
class_name WorldBackdrop

const TILE_SIZE := 32
const SOURCE_ID := 0

const TILE_BASE := Vector2i(0, 0)
const TILE_DARK := Vector2i(1, 0)
const TILE_ROAD := Vector2i(2, 0)
const TILE_EDGE := Vector2i(3, 0)
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
	_fill_tile(image, TILE_BASE, palette[0], palette[1], false, false)
	_fill_tile(image, TILE_DARK, palette[1], palette[2], false, false)
	_fill_tile(image, TILE_ROAD, palette[3], palette[4], false, false)
	_fill_tile(image, TILE_EDGE, palette[4], palette[2], false, false)
	_fill_tile(image, TILE_CRACK, palette[0], palette[2], false, true)
	_fill_tile(image, TILE_ACCENT, palette[5], palette[4], true, false)

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
			Color8(82, 80, 72), Color8(60, 59, 54), Color8(42, 42, 39),
			Color8(96, 89, 73), Color8(132, 107, 65), Color8(118, 112, 99)
		]

	match route_id:
		"toxic_marsh":
			return [Color8(88, 86, 61), Color8(58, 70, 48), Color8(36, 48, 36), Color8(116, 94, 55), Color8(81, 88, 55), Color8(78, 144, 70)]
		"crystal_scar":
			return [Color8(92, 82, 72), Color8(68, 60, 72), Color8(45, 42, 56), Color8(126, 98, 62), Color8(84, 74, 88), Color8(129, 86, 184)]
		"old_factory":
			return [Color8(85, 80, 67), Color8(64, 65, 60), Color8(43, 46, 46), Color8(116, 94, 58), Color8(78, 76, 67), Color8(125, 98, 70)]
		_:
			return [Color8(104, 86, 58), Color8(74, 65, 49), Color8(52, 49, 42), Color8(142, 104, 58), Color8(96, 73, 48), Color8(116, 91, 64)]


func _fill_tile(image: Image, tile_coords: Vector2i, base: Color, line: Color, rivets := false, cracked := false) -> void:
	var start_x := tile_coords.x * TILE_SIZE
	for y in range(TILE_SIZE):
		for x in range(TILE_SIZE):
			var shade := 0.0
			if ((x * 19 + y * 23 + tile_coords.x * 17 + int(world_seed)) % 29) == 0:
				shade = 0.04
			image.set_pixel(start_x + x, y, base.lerp(line, 0.045 + shade))

	# Soft seams only; avoid the previous high-contrast checkerboard look.
	for i in range(TILE_SIZE):
		image.set_pixel(start_x + i, TILE_SIZE - 1, line.darkened(0.14))
		image.set_pixel(start_x + TILE_SIZE - 1, i, line.darkened(0.12))

	if rivets:
		for p in [Vector2i(6, 6), Vector2i(25, 6), Vector2i(6, 25), Vector2i(25, 25)]:
			image.set_pixel(start_x + p.x, p.y, line.lightened(0.18))

	if cracked:
		_draw_crack(image, start_x + 10, 9, [Vector2i(5, 4), Vector2i(7, -1), Vector2i(4, 5)], line.darkened(0.22))


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
		if h % 53 == 0:
			return TILE_CRACK
		if h % 31 == 0:
			return TILE_ACCENT
		return TILE_BASE if h % 5 != 0 else TILE_DARK

	if road >= 0.70:
		return TILE_ROAD
	if road > 0.0:
		return TILE_EDGE if h % 8 != 0 else TILE_CRACK
	if h % 47 == 0:
		return TILE_ACCENT
	if h % 41 == 0:
		return TILE_CRACK
	if h % 7 == 0:
		return TILE_DARK
	return TILE_BASE


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
