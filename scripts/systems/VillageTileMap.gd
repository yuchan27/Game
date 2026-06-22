extends TileMap
class_name VillageTileMap

const TILE_SIZE := 32

const SOURCE_ID := 0
const TILE_GRASS := Vector2i(0, 0)
const TILE_DIRT := Vector2i(1, 0)
const TILE_ROAD := Vector2i(2, 0)
const TILE_PLAZA := Vector2i(3, 0)
const TILE_SHOULDER := Vector2i(4, 0)
const TILE_DARK_PATCH := Vector2i(5, 0)

var map_size := Vector2i(78, 56)
var world_seed := 137


func setup(new_map_size: Vector2i, new_seed: int) -> void:
	map_size = new_map_size
	world_seed = new_seed
	_build_tileset()
	_generate_village_floor()


func _build_tileset() -> void:
	var image := Image.create(TILE_SIZE * 6, TILE_SIZE, false, Image.FORMAT_RGBA8)

	_fill_tile(image, TILE_GRASS, Color8(52, 88, 48), Color8(37, 62, 35))
	_fill_tile(image, TILE_DIRT, Color8(93, 76, 48), Color8(69, 55, 36))
	_fill_tile(image, TILE_ROAD, Color8(156, 117, 62), Color8(120, 86, 45))
	_fill_tile(image, TILE_PLAZA, Color8(178, 134, 72), Color8(132, 94, 50))
	_fill_tile(image, TILE_SHOULDER, Color8(118, 91, 52), Color8(82, 65, 42))
	_fill_tile(image, TILE_DARK_PATCH, Color8(45, 62, 38), Color8(34, 45, 31))

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


func _fill_tile(image: Image, tile_coords: Vector2i, base: Color, line: Color) -> void:
	var start_x := tile_coords.x * TILE_SIZE
	for y in range(TILE_SIZE):
		for x in range(TILE_SIZE):
			var noise := 0.0
			if ((x * 17 + y * 31 + tile_coords.x * 13) % 11) == 0:
				noise = 0.08
			var c := base.lerp(line, 0.16 + noise)
			image.set_pixel(start_x + x, y, c)

	for i in range(TILE_SIZE):
		image.set_pixel(start_x + i, TILE_SIZE - 1, line.darkened(0.16))
		image.set_pixel(start_x + TILE_SIZE - 1, i, line.darkened(0.12))
	for i in range(8):
		var px := start_x + int((i * 7 + tile_coords.x * 5) % TILE_SIZE)
		var py := int((i * 11 + tile_coords.x * 3) % TILE_SIZE)
		image.set_pixel(px, py, line.lightened(0.18))


func _generate_village_floor() -> void:
	clear()
	for y in range(map_size.y):
		for x in range(map_size.x):
			var road_strength := _road_strength(x, y)
			var atlas_coords := _tile_for_position(x, y, road_strength)
			set_cell(0, Vector2i(x, y), SOURCE_ID, atlas_coords)


func _tile_for_position(x: int, y: int, road_strength: float) -> Vector2i:
	if road_strength >= 0.70:
		var cx := float(map_size.x) * 0.5
		var cy := float(map_size.y) * 0.5
		var plaza_shape := pow((float(x) - cx) / 10.5, 2.0) + pow((float(y) - cy) / 6.5, 2.0)
		return TILE_PLAZA if plaza_shape <= 1.0 else TILE_ROAD
	if road_strength > 0.0:
		return TILE_SHOULDER

	var patch := _village_patch_value(x, y)
	if patch > 0.52:
		return TILE_DIRT
	if patch < -0.48:
		return TILE_DARK_PATCH
	return TILE_GRASS


func _road_strength(x: int, y: int) -> float:
	var cx: float = float(map_size.x) * 0.5
	var cy: float = float(map_size.y) * 0.5
	var plaza_shape: float = pow((float(x) - cx) / 10.5, 2.0) + pow((float(y) - cy) / 6.5, 2.0)
	var plaza: bool = plaza_shape <= 1.0
	var vertical_center: float = cx + sin(float(y) * 0.22) * 1.4
	var horizontal_center: float = cy + sin(float(x) * 0.18) * 1.2
	var vertical: bool = abs(float(x) - vertical_center) <= 2.2 and y >= 4 and y <= map_size.y - 2
	var horizontal: bool = abs(float(y) - horizontal_center) <= 2.2 and x >= 3 and x <= map_size.x - 2
	var shoulder: bool = plaza_shape <= 1.42 or abs(float(x) - vertical_center) <= 3.4 or abs(float(y) - horizontal_center) <= 3.4
	return 0.78 if plaza or vertical or horizontal else (0.22 if shoulder else 0.0)


func _village_patch_value(x: int, y: int) -> float:
	return sin(float(x) * 0.17 + float(y) * 0.09) + sin(float(x) * 0.035 + float(y) * 0.051)
