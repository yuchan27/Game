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
	var texture: Texture2D = ImageTexture.create_from_image(_build_wasteland_tileset_image())
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var atlas_source: TileSetAtlasSource = TileSetAtlasSource.new()
	atlas_source.texture = texture
	atlas_source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for x in range(6):
		atlas_source.create_tile(Vector2i(x, 0))

	var new_tile_set: TileSet = TileSet.new()
	new_tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	new_tile_set.add_source(atlas_source, SOURCE_ID)
	tile_set = new_tile_set


func _build_wasteland_tileset_image() -> Image:
	var image: Image = Image.create(TILE_SIZE * 6, TILE_SIZE, false, Image.FORMAT_RGBA8)
	var palette: Array[Color] = _palette()
	_fill_wasteland_tile(image, TILE_BASE, palette[0], palette[1], false, false, false)
	_fill_wasteland_tile(image, TILE_DARK, palette[1], palette[2], false, false, false)
	_fill_wasteland_tile(image, TILE_ROAD, palette[3], palette[4], true, false, false)
	_fill_wasteland_tile(image, TILE_EDGE, palette[4], palette[1], true, false, false)
	_fill_wasteland_tile(image, TILE_CRACK, palette[0], palette[2], false, true, false)
	_fill_wasteland_tile(image, TILE_ACCENT, palette[5], palette[4], false, false, true)
	return image


func _palette() -> Array[Color]:
	if mode == "guild":
		return [
			Color8(65, 63, 56), Color8(48, 47, 43), Color8(31, 31, 30),
			Color8(76, 69, 55), Color8(92, 75, 50), Color8(89, 83, 72)
		]

	match route_id:
		"toxic_marsh":
			return [
				Color8(82, 78, 55), Color8(58, 66, 44), Color8(37, 47, 34),
				Color8(102, 82, 49), Color8(73, 76, 48), Color8(70, 119, 60)
			]
		"crystal_scar":
			return [
				Color8(86, 72, 62), Color8(62, 54, 65), Color8(42, 38, 52),
				Color8(114, 84, 54), Color8(76, 62, 72), Color8(108, 72, 146)
			]
		"old_factory":
			return [
				Color8(78, 72, 61), Color8(56, 55, 50), Color8(38, 38, 36),
				Color8(108, 82, 51), Color8(74, 68, 58), Color8(105, 77, 52)
			]
		_:
			return [
				Color8(98, 80, 53), Color8(70, 60, 45), Color8(50, 45, 37),
				Color8(132, 94, 52), Color8(90, 67, 44), Color8(108, 84, 58)
			]


func _fill_wasteland_tile(image: Image, tile_coords: Vector2i, base: Color, stain: Color, dusty := false, cracked := false, accent := false) -> void:
	var start_x: int = tile_coords.x * TILE_SIZE
	for y in range(TILE_SIZE):
		for x in range(TILE_SIZE):
			var n: int = _pixel_hash(x, y, tile_coords.x)
			var blend: float = 0.06 + float(n % 17) / 360.0
			var c: Color = base.lerp(stain, blend)
			if dusty and (n % 23 == 0):
				c = c.lightened(0.08)
			if accent and (n % 19 == 0):
				c = c.lightened(0.10)
			image.set_pixel(start_x + x, y, c)

	# 只保留很淡的邊緣，避免看起來像卡通棋盤格。
	for i in range(TILE_SIZE):
		image.set_pixel(start_x + i, TILE_SIZE - 1, stain.darkened(0.10))
		image.set_pixel(start_x + TILE_SIZE - 1, i, stain.darkened(0.08))

	if cracked:
		_draw_crack(image, start_x + 8, 10, [Vector2i(4, 3), Vector2i(8, -2), Vector2i(5, 5)], stain.darkened(0.24))
		_draw_crack(image, start_x + 22, 18, [Vector2i(-4, 2), Vector2i(5, 3)], stain.darkened(0.20))
	elif accent:
		for i in range(5):
			var px: int = start_x + 6 + i * 4
			var py: int = 8 + int((_pixel_hash(i, tile_coords.x, world_seed) % 13))
			image.set_pixel(px, py, stain.lightened(0.22))


func _draw_crack(image: Image, start_x: int, start_y: int, offsets: Array[Vector2i], color: Color) -> void:
	var current: Vector2i = Vector2i(start_x, start_y)
	for offset: Vector2i in offsets:
		var target: Vector2i = current + offset
		_draw_pixel_line(image, current, target, color)
		current = target


func _draw_pixel_line(image: Image, from_pos: Vector2i, to_pos: Vector2i, color: Color) -> void:
	var delta: Vector2i = to_pos - from_pos
	var steps: int = max(abs(delta.x), abs(delta.y))
	if steps <= 0:
		return
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var p: Vector2i = Vector2i(roundi(lerp(float(from_pos.x), float(to_pos.x), t)), roundi(lerp(float(from_pos.y), float(to_pos.y), t)))
		if p.x >= 0 and p.y >= 0 and p.x < image.get_width() and p.y < image.get_height():
			image.set_pixel(p.x, p.y, color)


func _generate_map() -> void:
	clear()
	for y in range(map_size.y):
		for x in range(map_size.x):
			set_cell(0, Vector2i(x, y), SOURCE_ID, _tile_for_position(x, y))


func _tile_for_position(x: int, y: int) -> Vector2i:
	var h: int = _hash2i(x, y)
	var road: float = _road_strength(x, y)
	if mode == "guild":
		if x <= 1 or y <= 1 or x >= map_size.x - 2 or y >= map_size.y - 2:
			return TILE_DARK
		if h % 97 == 0:
			return TILE_CRACK
		if h % 79 == 0:
			return TILE_ACCENT
		return TILE_BASE if h % 10 != 0 else TILE_DARK

	if road >= 0.70:
		return TILE_ROAD if h % 11 != 0 else TILE_EDGE
	if road > 0.0:
		return TILE_EDGE if h % 18 != 0 else TILE_CRACK
	if h % 127 == 0:
		return TILE_ACCENT
	if h % 109 == 0:
		return TILE_CRACK
	if h % 17 == 0:
		return TILE_DARK
	return TILE_BASE


func _road_strength(x: int, y: int) -> float:
	if mode == "guild":
		return 0.0
	var cx: float = float(map_size.x) * 0.5
	var route_bias: float = 0.0
	if route_id == "toxic_marsh":
		route_bias = sin(float(x) * 0.045) * 1.6
	elif route_id == "crystal_scar":
		route_bias = sin(float(y) * 0.052) * 1.5
	elif route_id == "old_factory":
		route_bias = sin(float(x + y) * 0.035) * 1.3
	var main_path: bool = abs(float(x) - cx - route_bias) <= 2.4
	var spawn_path: bool = abs(float(x) - cx) <= 3.0 and y >= int(float(map_size.y) * 0.48)
	var cross_path: bool = abs(float(y) - float(map_size.y) * 0.54 - sin(float(x) * 0.07) * 1.6) <= 1.8
	var shoulder: bool = abs(float(x) - cx - route_bias) <= 4.0 or abs(float(y) - float(map_size.y) * 0.54) <= 3.0
	return 0.78 if main_path or spawn_path or cross_path else (0.22 if shoulder else 0.0)


func _hash2i(x: int, y: int) -> int:
	var n: int = int(world_seed) + x * 374761393 + y * 668265263
	n = (n ^ (n >> 13)) * 1274126177
	return abs(n ^ (n >> 16))


func _pixel_hash(x: int, y: int, salt: int) -> int:
	var n: int = int(world_seed) + x * 1103515245 + y * 12345 + salt * 2654435761
	n = n ^ (n >> 16)
	return abs(n)
