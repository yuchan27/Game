extends TileMap
class_name VillageTileMap

const ASSET_LOADER := preload("res://scripts/utils/RuntimeAssetLoader.gd")
const TILE_SIZE := 32
const TILESET_PATH := "res://assets/sprites/tiles/yuchan_wasteland_tiles.png"

const SOURCE_ID := 0
const BLOCK_WASTELAND := 0
const BLOCK_DARK_SOIL := 1
const BLOCK_ROAD := 2
const BLOCK_ROAD_EDGE := 3
const BLOCK_CRACKED := 4
const BLOCK_SCRAP_PLATE := 5

const STATION_PADS := [
	Vector2(1248, 370),
	Vector2(680, 650),
	Vector2(1810, 650),
	Vector2(720, 1130),
	Vector2(1248, 1180),
	Vector2(1760, 1130),
	Vector2(2060, 900),
]

var map_size := Vector2i(78, 56)
var world_seed := 137
var _has_macro_blocks := false


func setup(new_map_size: Vector2i, new_seed: int) -> void:
	map_size = new_map_size
	world_seed = new_seed
	_build_tileset()
	_generate_village_floor()


func _build_tileset() -> void:
	var texture: Texture2D = ASSET_LOADER.load_png(TILESET_PATH)
	if texture == null:
		texture = ImageTexture.create_from_image(_fallback_tileset_image())
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var cols: int = max(1, int(texture.get_width() / TILE_SIZE))
	var rows: int = max(1, int(texture.get_height() / TILE_SIZE))
	_has_macro_blocks = (cols >= 24 and rows >= 4)

	var atlas_source: TileSetAtlasSource = TileSetAtlasSource.new()
	atlas_source.texture = texture
	atlas_source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for ty in range(rows):
		for tx in range(cols):
			atlas_source.create_tile(Vector2i(tx, ty))

	var new_tile_set: TileSet = TileSet.new()
	new_tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	new_tile_set.add_source(atlas_source, SOURCE_ID)
	tile_set = new_tile_set


func _fallback_tileset_image() -> Image:
	var image: Image = Image.create(TILE_SIZE * 6, TILE_SIZE, false, Image.FORMAT_RGBA8)
	_fill_fallback_tile(image, Vector2i(0, 0), Color8(58, 50, 42), Color8(42, 36, 30), false, false)
	_fill_fallback_tile(image, Vector2i(1, 0), Color8(46, 40, 34), Color8(34, 29, 24), false, false)
	_fill_fallback_tile(image, Vector2i(2, 0), Color8(54, 53, 56), Color8(38, 37, 40), false, false)
	_fill_fallback_tile(image, Vector2i(3, 0), Color8(56, 51, 45), Color8(40, 36, 32), false, false)
	_fill_fallback_tile(image, Vector2i(4, 0), Color8(56, 52, 48), Color8(38, 35, 32), false, true)
	_fill_fallback_tile(image, Vector2i(5, 0), Color8(52, 56, 62), Color8(34, 37, 42), true, false)
	return image


func _fill_fallback_tile(image: Image, tile_coords: Vector2i, base: Color, line: Color, metal := false, cracked := false) -> void:
	var start_x: int = tile_coords.x * TILE_SIZE
	for y in range(TILE_SIZE):
		for x in range(TILE_SIZE):
			var shade: float = 0.0
			if ((x * 19 + y * 23 + tile_coords.x * 17 + int(world_seed)) % 37) == 0:
				shade = 0.035
			image.set_pixel(start_x + x, y, base.lerp(line, 0.035 + shade))
	if metal:
		for p: Vector2i in [Vector2i(6, 6), Vector2i(25, 6), Vector2i(6, 25), Vector2i(25, 25)]:
			image.set_pixel(start_x + p.x, p.y, line.lightened(0.18))
	if cracked:
		image.set_pixel(start_x + 12, 12, line.darkened(0.22))


func _generate_village_floor() -> void:
	clear()
	for y in range(map_size.y):
		for x in range(map_size.x):
			var block_idx: int = _block_for_position(x, y)
			var atlas_coords := Vector2i(block_idx, 0)
			if _has_macro_blocks:
				atlas_coords = Vector2i(block_idx * 4 + (x % 4), y % 4)
			set_cell(0, Vector2i(x, y), SOURCE_ID, atlas_coords)


func _block_for_position(x: int, y: int) -> int:
	# Use 4x4 macro-grid aligned hash so soil patches align seamlessly with 128x128 blocks
	var macro_rng: int = _hash2i(x / 4, y / 4)
	var cx: float = float(map_size.x) * 0.5
	var cy: float = float(map_size.y) * 0.5
	var plaza_shape: float = pow((float(x) - cx) / 11.0, 2.0) + pow((float(y) - cy) / 7.0, 2.0)
	var vertical_center: float = cx
	var horizontal_center: float = cy
	var vertical: bool = abs(float(x) - vertical_center) <= 2.2 and y >= 4 and y <= map_size.y - 2
	var horizontal: bool = abs(float(y) - horizontal_center) <= 2.2 and x >= 3 and x <= map_size.x - 2
	var shoulder: bool = plaza_shape <= 1.32 or (abs(float(x) - vertical_center) <= 3.3 and y >= 4 and y <= map_size.y - 2) or (abs(float(y) - horizontal_center) <= 3.3 and x >= 3 and x <= map_size.x - 2)

	# Station pads (environmental integrated industrial metal pads with dithered perimeters)
	var wx: float = float(x * TILE_SIZE + TILE_SIZE * 0.5)
	var wy: float = float(y * TILE_SIZE + TILE_SIZE * 0.5)
	var jitter: float = float((_hash2i(x, y) % 23) - 11) * 0.04
	for pad_center: Vector2 in STATION_PADS:
		var dx: float = abs(wx - pad_center.x)
		var dy: float = abs(wy - (pad_center.y - 24.0))
		var norm_dist := (dx / 120.0) * (dx / 120.0) + (dy / 76.0) * (dy / 76.0) + jitter
		if norm_dist <= 0.68:
			return BLOCK_SCRAP_PLATE
		elif norm_dist <= 1.05:
			return BLOCK_ROAD_EDGE
		elif norm_dist <= 1.45:
			return BLOCK_CRACKED if ((_hash2i(x, y) % 3) == 0) else BLOCK_DARK_SOIL

	# Power conduit and pipeline trenches connecting stations to the main roads
	if (abs(wx - 1248.0) <= 16.0 and wy >= 370.0 and wy <= cy * float(TILE_SIZE)) or \
	   (abs(wy - 650.0) <= 16.0 and ((wx >= 680.0 and wx <= cx * float(TILE_SIZE)) or (wx >= cx * float(TILE_SIZE) and wx <= 1810.0))) or \
	   (abs(wy - 1130.0) <= 16.0 and ((wx >= 720.0 and wx <= 1248.0) or (wx >= 1248.0 and wx <= 1760.0))) or \
	   (abs(wx - 1248.0) <= 16.0 and wy >= cy * float(TILE_SIZE) and wy <= 1180.0):
		if (_hash2i(x, y) % 5) != 0:
			return BLOCK_SCRAP_PLATE

	var edge_dither: float = float((_hash2i(x, y) % 19) - 9) * 0.03
	if plaza_shape + edge_dither <= 1.0 or vertical or horizontal:
		return BLOCK_ROAD
	if shoulder:
		return BLOCK_ROAD_EDGE
	if macro_rng % 7 == 0:
		return BLOCK_CRACKED
	if macro_rng % 3 == 0:
		return BLOCK_DARK_SOIL
	return BLOCK_WASTELAND


func _hash2i(x: int, y: int) -> int:
	var n: int = int(world_seed) + x * 374761393 + y * 668265263
	n = (n ^ (n >> 13)) * 1274126177
	return abs(n ^ (n >> 16))
