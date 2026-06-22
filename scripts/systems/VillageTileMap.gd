extends TileMap
class_name VillageTileMap

const TILE_SIZE := 32

const SOURCE_ID := 0
const TILE_WASTELAND := Vector2i(0, 0)
const TILE_DARK_SOIL := Vector2i(1, 0)
const TILE_ROAD := Vector2i(2, 0)
const TILE_ROAD_EDGE := Vector2i(3, 0)
const TILE_CRACKED := Vector2i(4, 0)
const TILE_SCRAP_PLATE := Vector2i(5, 0)

var map_size := Vector2i(78, 56)
var world_seed := 137


func setup(new_map_size: Vector2i, new_seed: int) -> void:
	map_size = new_map_size
	world_seed = new_seed
	_build_tileset()
	_generate_village_floor()


func _build_tileset() -> void:
	var image := Image.create(TILE_SIZE * 6, TILE_SIZE, false, Image.FORMAT_RGBA8)

	# Unified yuchan branch palette: dry wasteland floor + readable road + rare scrap detail.
	_fill_wasteland_tile(image, TILE_WASTELAND, Color8(105, 88, 61), Color8(76, 63, 44), false, false)
	_fill_wasteland_tile(image, TILE_DARK_SOIL, Color8(79, 72, 58), Color8(55, 52, 45), false, false)
	_fill_wasteland_tile(image, TILE_ROAD, Color8(150, 110, 63), Color8(104, 77, 47), false, false)
	_fill_wasteland_tile(image, TILE_ROAD_EDGE, Color8(121, 93, 58), Color8(82, 66, 47), false, false)
	_fill_wasteland_tile(image, TILE_CRACKED, Color8(94, 84, 66), Color8(54, 48, 40), false, true)
	_fill_wasteland_tile(image, TILE_SCRAP_PLATE, Color8(70, 72, 66), Color8(43, 45, 43), true, false)

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


func _fill_wasteland_tile(image: Image, tile_coords: Vector2i, base: Color, line: Color, metal := false, cracked := false) -> void:
	var start_x := tile_coords.x * TILE_SIZE

	for y in range(TILE_SIZE):
		for x in range(TILE_SIZE):
			var shade := 0.0
			if ((x * 19 + y * 23 + tile_coords.x * 17 + int(world_seed)) % 37) == 0:
				shade = 0.035
			var c := base.lerp(line, 0.035 + shade)
			image.set_pixel(start_x + x, y, c)

	# Soft seams only; keep TileMap readable without the previous noisy checkerboard effect.
	for i in range(TILE_SIZE):
		image.set_pixel(start_x + i, TILE_SIZE - 1, line.darkened(0.11))
		image.set_pixel(start_x + TILE_SIZE - 1, i, line.darkened(0.09))

	if metal:
		for p in [Vector2i(6, 6), Vector2i(25, 6), Vector2i(6, 25), Vector2i(25, 25)]:
			image.set_pixel(start_x + p.x, p.y, line.lightened(0.18))
		for i in range(5, TILE_SIZE - 5):
			if i % 11 == 0:
				image.set_pixel(start_x + i, 5, line.lightened(0.12))
				image.set_pixel(start_x + 5, i, line.lightened(0.10))

	if cracked:
		_draw_crack(image, start_x + 10, 9, [Vector2i(5, 4), Vector2i(6, -1), Vector2i(3, 5)], line.darkened(0.22))


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


func _generate_village_floor() -> void:
	clear()
	for y in range(map_size.y):
		for x in range(map_size.x):
			var atlas_coords := _tile_for_position(x, y)
			set_cell(0, Vector2i(x, y), SOURCE_ID, atlas_coords)


func _tile_for_position(x: int, y: int) -> Vector2i:
	var rng_value := _hash2i(x, y)
	var cx := float(map_size.x) * 0.5
	var cy := float(map_size.y) * 0.5
	var plaza_shape: float = pow((float(x) - cx) / 10.8, 2.0) + pow((float(y) - cy) / 6.8, 2.0)
	var vertical_center: float = cx + sin(float(y) * 0.18) * 1.15
	var horizontal_center: float = cy + sin(float(x) * 0.15) * 1.0
	var vertical: bool = abs(float(x) - vertical_center) <= 2.4 and y >= 4 and y <= map_size.y - 2
	var horizontal: bool = abs(float(y) - horizontal_center) <= 2.4 and x >= 3 and x <= map_size.x - 2
	var shoulder: bool = plaza_shape <= 1.35 or abs(float(x) - vertical_center) <= 3.6 or abs(float(y) - horizontal_center) <= 3.6

	if plaza_shape <= 1.0 or vertical or horizontal:
		return TILE_ROAD
	if shoulder:
		return TILE_ROAD_EDGE if rng_value % 16 != 0 else TILE_CRACKED
	if rng_value % 73 == 0:
		return TILE_SCRAP_PLATE
	if rng_value % 61 == 0:
		return TILE_CRACKED
	if rng_value % 11 == 0:
		return TILE_DARK_SOIL
	return TILE_WASTELAND


func _hash2i(x: int, y: int) -> int:
	var n := int(world_seed) + x * 374761393 + y * 668265263
	n = (n ^ (n >> 13)) * 1274126177
	return abs(n ^ (n >> 16))
