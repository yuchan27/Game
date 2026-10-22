extends RefCounted
class_name PixelArtFactory

const PLAYER_FRAME_SIZE := Vector2i(112, 128)
const PLAYER_FRAMES_PER_ACTION := 8
const ENEMY_FRAME_SIZE := Vector2i(96, 72)
const ITEM_FRAME_SIZE := Vector2i(88, 72)
const PLAYER_ACTIONS := ["idle", "walk", "shoot", "draw_sword", "slash", "swap_tool", "interact", "hit", "dead"]
const ENEMY_TYPES := ["melee", "fast", "ranged", "heavy", "flying", "hybrid", "boss"]
const ITEM_TYPES := ["scrap", "ammo", "mutant_core", "bio_crystal"]
const PLAYER_ATLAS_PATH := "res://assets/sprites/player/recycler_player_multiaction_8dir_preview.png"
const ENEMY_ATLAS_PATH := "res://assets/sprites/enemies/polluted_enemy_six_types.png"
const ITEM_ATLAS_PATH := "res://assets/sprites/items/recycler_item_icons.png"

func make_texture(size: Vector2i, palette: Array[Color], pattern := 0) -> ImageTexture:
	return ImageTexture.create_from_image(make_image(size, palette, pattern))

func make_image(size: Vector2i, palette: Array[Color], pattern := 0) -> Image:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in size.y:
		for x in size.x:
			var color_index: int = abs((x / 4) + (y / 4) + pattern) % max(1, palette.size())
			var c := palette[color_index]
			if pattern % 3 == 0 and (x + y) % 11 == 0:
				c = c.lightened(0.18)
			if x < 2 or y < 2 or x >= size.x - 2 or y >= size.y - 2:
				c = c.darkened(0.35)
			image.set_pixel(x, y, c)
	return image

func player_texture(direction_index := 0, action_index := 0, frame_index := 0) -> Texture2D:
	var atlas := _load_texture(PLAYER_ATLAS_PATH)
	if atlas != null:
		return _atlas_frame(atlas, Rect2(
			(action_index * PLAYER_FRAMES_PER_ACTION + frame_index) * PLAYER_FRAME_SIZE.x,
			direction_index * PLAYER_FRAME_SIZE.y,
			PLAYER_FRAME_SIZE.x,
			PLAYER_FRAME_SIZE.y
		))
	return ImageTexture.create_from_image(player_image(direction_index, action_index, frame_index))

func player_image(direction_index := 0, action_index := 0, frame_index := 0) -> Image:
	var palette: Array[Color] = [
		Color8(16, 20, 24),
		Color8(48, 57, 62),
		Color8(95, 111, 116),
		Color8(32, 219, 236),
		Color8(192, 112, 57),
		Color8(228, 229, 198),
		Color8(72, 221, 147)
	]
	var image := Image.create(PLAYER_FRAME_SIZE.x, PLAYER_FRAME_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var sway: int = 0
	var bob: int = 0
	if action_index == 0:
		sway = 1 if frame_index == 1 else 0
	elif action_index == 1:
		var walk_offsets: Array[int] = [-1, 0, 1]
		sway = walk_offsets[frame_index % walk_offsets.size()]
		bob = abs(sway)
	var direction := _direction_vector(direction_index)
	var origin := Vector2i(24 + sway, 29 + bob)
	_fill_ellipse(image, Vector2i(24, 50), 15, 4, Color(0, 0, 0, 0.26))
	_draw_player_legs(image, origin, direction_index, action_index, frame_index, palette)
	_draw_player_body(image, origin, direction_index, palette)
	_draw_player_head(image, direction_index, direction, origin, palette)
	_draw_player_arms(image, direction_index, action_index, frame_index, origin, direction, palette)
	return image

func enemy_texture(enemy_type: String) -> Texture2D:
	var atlas := _load_texture(ENEMY_ATLAS_PATH)
	if atlas != null:
		var index := ENEMY_TYPES.find(enemy_type)
		if index < 0:
			index = 0
		return _atlas_frame(atlas, Rect2(index * ENEMY_FRAME_SIZE.x, 0, ENEMY_FRAME_SIZE.x, ENEMY_FRAME_SIZE.y))
	return ImageTexture.create_from_image(enemy_image(enemy_type))

func enemy_image(enemy_type: String) -> Image:
	var image := Image.create(ENEMY_FRAME_SIZE.x, ENEMY_FRAME_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	_enemy_ellipse(image, Vector2i(28, 40), 20, 5, Color(0, 0, 0, 0.38))
	match enemy_type:
		"boss":
			_enemy_ellipse(image, Vector2i(29, 27), 25, 17, Color8(15, 12, 10))
			_enemy_ellipse(image, Vector2i(29, 26), 22, 15, Color8(77, 45, 31))
			_enemy_ellipse(image, Vector2i(18, 25), 8, 8, Color8(142, 62, 43))
			_enemy_ellipse(image, Vector2i(35, 23), 13, 11, Color8(116, 77, 44))
			_enemy_ellipse(image, Vector2i(20, 22), 5, 5, Color8(235, 42, 45))
			_enemy_ellipse(image, Vector2i(36, 20), 5, 5, Color8(132, 230, 52))
			_enemy_ellipse(image, Vector2i(42, 28), 4, 4, Color8(204, 42, 44))
			_enemy_rect(image, 12, 31, 42, 38, Color8(27, 15, 11))
			for x in [9, 16, 40, 47]:
				_enemy_line(image, Vector2(x, 29), Vector2(x - 5 if x < 28 else x + 5, 44), Color8(37, 28, 22), 3)
			for x in [15, 23, 32, 42]:
				_enemy_rect(image, x, 5, x + 4, 16, Color8(55, 45, 35))
				_enemy_rect(image, x - 1, 4, x + 5, 7, Color8(213, 126, 54))
			_enemy_line(image, Vector2(14, 37), Vector2(10, 46), Color8(132, 220, 51), 2)
			_enemy_line(image, Vector2(39, 37), Vector2(43, 46), Color8(132, 220, 51), 2)
			_enemy_rect(image, 24, 32, 36, 36, Color8(9, 7, 5))
		"fast":
			_enemy_ellipse(image, Vector2i(29, 27), 18, 12, Color8(17, 22, 14))
			_enemy_ellipse(image, Vector2i(30, 24), 14, 9, Color8(86, 137, 41))
			_enemy_ellipse(image, Vector2i(20, 24), 7, 7, Color8(92, 54, 37))
			for leg in [-16, -10, -5, 6, 11, 17]:
				_enemy_line(image, Vector2(29 + leg * 0.45, 29), Vector2(29 + leg, 43), Color8(152, 209, 61), 2)
				_enemy_line(image, Vector2(29 + leg * 0.45, 22), Vector2(29 + leg, 9), Color8(130, 166, 58), 2)
			for x in [22, 29, 36]:
				_enemy_ellipse(image, Vector2i(x, 21), 2, 2, Color8(223, 48, 46))
			_enemy_rect(image, 29, 14, 34, 17, Color8(224, 245, 85))
		"ranged":
			_enemy_ellipse(image, Vector2i(22, 27), 16, 13, Color8(20, 15, 20))
			_enemy_ellipse(image, Vector2i(22, 24), 12, 10, Color8(108, 55, 70))
			_enemy_ellipse(image, Vector2i(20, 20), 5, 4, Color8(232, 64, 57))
			_enemy_rect(image, 31, 19, 52, 28, Color8(50, 42, 37))
			_enemy_rect(image, 38, 21, 55, 25, Color8(93, 73, 48))
			_enemy_rect(image, 47, 22, 55, 24, Color8(239, 197, 73))
			_enemy_line(image, Vector2(13, 34), Vector2(5, 44), Color8(93, 185, 70), 2)
			_enemy_line(image, Vector2(28, 35), Vector2(31, 45), Color8(93, 185, 70), 2)
			for y in [15, 31]:
				_enemy_rect(image, 35, y, 42, y + 2, Color8(131, 88, 45))
		"heavy":
			_enemy_ellipse(image, Vector2i(29, 27), 21, 16, Color8(18, 16, 14))
			_enemy_rect(image, 16, 14, 40, 34, Color8(91, 73, 55))
			_enemy_rect(image, 19, 17, 37, 22, Color8(201, 136, 70))
			_enemy_rect(image, 7, 18, 17, 40, Color8(44, 38, 32))
			_enemy_rect(image, 40, 18, 51, 40, Color8(44, 38, 32))
			_enemy_rect(image, 20, 31, 38, 37, Color8(31, 16, 13))
			_enemy_ellipse(image, Vector2i(28, 18), 3, 3, Color8(228, 55, 49))
			_enemy_line(image, Vector2(43, 33), Vector2(54, 43), Color8(130, 210, 52), 3)
			_enemy_line(image, Vector2(12, 12), Vector2(6, 6), Color8(217, 138, 65), 2)
			_enemy_line(image, Vector2(44, 12), Vector2(51, 6), Color8(217, 138, 65), 2)
		"flying":
			_enemy_ellipse(image, Vector2i(28, 26), 10, 11, Color8(18, 22, 23))
			_enemy_ellipse(image, Vector2i(28, 23), 8, 8, Color8(76, 85, 76))
			for wing in [-1, 1]:
				_enemy_line(image, Vector2(23 if wing < 0 else 33, 20), Vector2(4 if wing < 0 else 52, 8), Color8(181, 190, 142, 205), 4)
				_enemy_line(image, Vector2(23 if wing < 0 else 33, 27), Vector2(6 if wing < 0 else 50, 39), Color8(102, 132, 101, 205), 4)
				_enemy_line(image, Vector2(26, 24), Vector2(9 if wing < 0 else 47, 14), Color8(48, 43, 33), 1)
			_enemy_ellipse(image, Vector2i(28, 20), 3, 3, Color8(230, 52, 48))
			_enemy_line(image, Vector2(27, 33), Vector2(26, 45), Color8(124, 214, 57), 2)
		"hybrid":
			_enemy_ellipse(image, Vector2i(25, 29), 18, 13, Color8(20, 18, 24))
			_enemy_rect(image, 31, 17, 45, 35, Color8(62, 69, 69))
			_enemy_rect(image, 34, 20, 42, 27, Color8(94, 104, 101))
			_enemy_ellipse(image, Vector2i(23, 23), 4, 4, Color8(229, 45, 61))
			for leg in [-15, -9, 11, 17]:
				_enemy_line(image, Vector2(28, 32), Vector2(28 + leg, 45), Color8(127, 70, 150), 2)
			_enemy_line(image, Vector2(42, 26), Vector2(55, 22), Color8(69, 213, 119), 3)
			_enemy_rect(image, 44, 22, 54, 25, Color8(38, 33, 29))
		"alloy_plate":
			_item_rect(image, 14, 16, 42, 38, Color8(70, 80, 92))
			_item_rect(image, 16, 18, 40, 36, Color8(115, 130, 145))
			_item_set(image, 18, 20, Color8(220, 235, 250))
			_item_set(image, 38, 20, Color8(220, 235, 250))
			_item_set(image, 18, 34, Color8(220, 235, 250))
			_item_set(image, 38, 34, Color8(220, 235, 250))
		"broken_coil":
			_item_rect(image, 18, 16, 38, 38, Color8(42, 48, 55))
			_item_line(image, Vector2(16, 22), Vector2(40, 22), Color8(215, 120, 45), 3)
			_item_line(image, Vector2(16, 28), Vector2(40, 28), Color8(215, 120, 45), 3)
			_item_line(image, Vector2(16, 34), Vector2(40, 34), Color8(215, 120, 45), 3)
			_item_set(image, 14, 16, Color8(75, 225, 240))
			_item_set(image, 42, 38, Color8(75, 225, 240))
		"mutant_herb":
			_item_line(image, Vector2(28, 42), Vector2(28, 18), Color8(34, 110, 45), 3)
			_item_ellipse(image, Vector2i(20, 24), 7, 5, Color8(75, 205, 85))
			_item_ellipse(image, Vector2i(36, 28), 7, 5, Color8(65, 185, 75))
			_item_set(image, 20, 22, Color8(200, 255, 160))
			_item_set(image, 36, 26, Color8(200, 255, 160))
		"acid_sac":
			_item_ellipse(image, Vector2i(28, 26), 13, 14, Color8(45, 120, 25))
			_item_ellipse(image, Vector2i(28, 27), 10, 11, Color8(95, 195, 45))
			_item_ellipse(image, Vector2i(25, 24), 5, 5, Color8(175, 245, 75))
		"amethyst_gem":
			_item_line(image, Vector2(28, 8), Vector2(18, 30), Color8(195, 85, 245), 4)
			_item_line(image, Vector2(28, 8), Vector2(38, 30), Color8(155, 55, 215), 4)
			_item_line(image, Vector2(18, 30), Vector2(28, 44), Color8(75, 20, 105), 4)
			_item_line(image, Vector2(38, 30), Vector2(28, 44), Color8(75, 20, 105), 4)
			_item_set(image, 28, 12, Color8(255, 225, 255))
		"precision_chip":
			_item_rect(image, 16, 16, 40, 40, Color8(20, 60, 40))
			_item_rect(image, 22, 22, 34, 34, Color8(215, 175, 55))
			_item_rect(image, 25, 25, 31, 31, Color8(30, 35, 40))
		"dynamo_core":
			_item_rect(image, 18, 14, 38, 42, Color8(42, 48, 56))
			_item_rect(image, 22, 22, 34, 36, Color8(255, 165, 40))
			_item_line(image, Vector2(24, 26), Vector2(32, 34), Color8(255, 240, 160), 2)
		_:
			_enemy_ellipse(image, Vector2i(30, 29), 21, 13, Color8(20, 15, 12))
			_enemy_ellipse(image, Vector2i(24, 26), 14, 10, Color8(130, 67, 43))
			_enemy_ellipse(image, Vector2i(40, 30), 9, 8, Color8(70, 92, 45))
			_enemy_rect(image, 13, 25, 25, 31, Color8(35, 18, 13))
			_enemy_rect(image, 17, 22, 22, 25, Color8(229, 53, 48))
			for leg in [-16, -8, 8, 16]:
				_enemy_line(image, Vector2(30 + leg * 0.35, 34), Vector2(30 + leg, 45), Color8(92, 174, 63), 2)
			for spike in [12, 19, 35, 44]:
				_enemy_line(image, Vector2(spike, 19), Vector2(spike - 4 if spike < 28 else spike + 4, 9), Color8(191, 111, 66), 2)
	_enemy_highlight_noise(image, enemy_type.length() * 31)
	return image

func _enemy_set(image: Image, x: int, y: int, color: Color) -> void:
	if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height():
		image.set_pixel(x, y, color)

func _enemy_rect(image: Image, x0: int, y0: int, x1: int, y1: int, color: Color) -> void:
	for y in range(min(y0, y1), max(y0, y1) + 1):
		for x in range(min(x0, x1), max(x0, x1) + 1):
			_enemy_set(image, x, y, color)

func _enemy_ellipse(image: Image, center: Vector2i, radius_x: int, radius_y: int, color: Color) -> void:
	for y in range(center.y - radius_y, center.y + radius_y + 1):
		for x in range(center.x - radius_x, center.x + radius_x + 1):
			var dx: float = float(x - center.x) / max(1.0, float(radius_x))
			var dy: float = float(y - center.y) / max(1.0, float(radius_y))
			if dx * dx + dy * dy <= 1.0:
				_enemy_set(image, x, y, color)

func _enemy_line(image: Image, from_point: Vector2, to_point: Vector2, color: Color, width := 1) -> void:
	var steps := int(max(abs(to_point.x - from_point.x), abs(to_point.y - from_point.y)))
	if steps <= 0:
		_enemy_ellipse(image, Vector2i(int(from_point.x), int(from_point.y)), width, width, color)
		return
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var p := from_point.lerp(to_point, t)
		_enemy_ellipse(image, Vector2i(int(round(p.x)), int(round(p.y))), width, width, color)

func _enemy_highlight_noise(image: Image, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in range(42):
		var x := rng.randi_range(4, image.get_width() - 5)
		var y := rng.randi_range(5, image.get_height() - 8)
		var c := image.get_pixel(x, y)
		if c.a > 0.2:
			image.set_pixel(x, y, c.lightened(rng.randf_range(0.18, 0.38)))

func item_texture(item_id: String) -> Texture2D:
	var atlas := _load_texture(ITEM_ATLAS_PATH)
	if atlas != null:
		var index := ITEM_TYPES.find(item_id)
		if index < 0:
			index = 0
		return _atlas_frame(atlas, Rect2(index * ITEM_FRAME_SIZE.x, 0, ITEM_FRAME_SIZE.x, ITEM_FRAME_SIZE.y))
	return ImageTexture.create_from_image(item_image(item_id))

func item_image(item_id: String) -> Image:
	var image := Image.create(ITEM_FRAME_SIZE.x, ITEM_FRAME_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	_item_ellipse(image, Vector2i(28, 37), 20, 4, Color(0, 0, 0, 0.36))
	match item_id:
		"ammo":
			_item_rect(image, 11, 14, 38, 31, Color8(24, 28, 30))
			_item_rect(image, 13, 11, 36, 16, Color8(83, 101, 62))
			_item_rect(image, 15, 17, 35, 28, Color8(78, 91, 54))
			_item_rect(image, 39, 16, 45, 30, Color8(225, 181, 72))
			_item_rect(image, 42, 12, 45, 17, Color8(242, 206, 105))
			_item_rect(image, 11, 31, 38, 34, Color8(12, 15, 17))
			_item_rect(image, 20, 13, 28, 15, Color8(231, 139, 47))
		"mutant_core":
			_item_ellipse(image, Vector2i(28, 23), 15, 14, Color8(46, 13, 18))
			_item_ellipse(image, Vector2i(28, 22), 11, 11, Color8(194, 42, 52))
			_item_ellipse(image, Vector2i(24, 18), 4, 4, Color8(255, 136, 94))
			_item_line(image, Vector2(28, 8), Vector2(34, 2), Color8(86, 172, 76), 2)
			_item_line(image, Vector2(40, 23), Vector2(53, 26), Color8(86, 172, 76), 2)
			_item_line(image, Vector2(16, 25), Vector2(4, 31), Color8(113, 50, 58), 2)
		"bio_crystal":
			_item_line(image, Vector2(28, 5), Vector2(16, 27), Color8(90, 232, 165), 4)
			_item_line(image, Vector2(28, 5), Vector2(41, 27), Color8(202, 102, 243), 4)
			_item_line(image, Vector2(16, 27), Vector2(28, 39), Color8(55, 30, 84), 4)
			_item_line(image, Vector2(41, 27), Vector2(28, 39), Color8(55, 30, 84), 4)
			_item_line(image, Vector2(18, 20), Vector2(9, 33), Color8(170, 78, 230), 3)
			_item_line(image, Vector2(38, 20), Vector2(48, 33), Color8(122, 244, 194), 3)
			_item_rect(image, 25, 14, 31, 31, Color8(161, 248, 214))
			_item_set(image, 31, 9, Color.WHITE)
		_:
			_item_rect(image, 10, 21, 42, 29, Color8(48, 37, 27))
			_item_rect(image, 14, 14, 25, 25, Color8(138, 82, 43))
			_item_rect(image, 25, 12, 38, 23, Color8(111, 114, 104))
			_item_rect(image, 8, 27, 22, 34, Color8(168, 102, 48))
			_item_line(image, Vector2(13, 15), Vector2(41, 29), Color8(225, 164, 83), 2)
			_item_line(image, Vector2(17, 10), Vector2(22, 3), Color8(222, 222, 194), 2)
			_item_line(image, Vector2(25, 11), Vector2(33, 4), Color8(222, 222, 194), 2)
			_item_set(image, 35, 14, Color8(86, 214, 224))
	_item_highlight_noise(image, item_id.length() * 13)
	return image

func _item_set(image: Image, x: int, y: int, color: Color) -> void:
	if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height():
		image.set_pixel(x, y, color)

func _item_rect(image: Image, x0: int, y0: int, x1: int, y1: int, color: Color) -> void:
	for y in range(min(y0, y1), max(y0, y1) + 1):
		for x in range(min(x0, x1), max(x0, x1) + 1):
			_item_set(image, x, y, color)

func _item_ellipse(image: Image, center: Vector2i, radius_x: int, radius_y: int, color: Color) -> void:
	for y in range(center.y - radius_y, center.y + radius_y + 1):
		for x in range(center.x - radius_x, center.x + radius_x + 1):
			var dx: float = float(x - center.x) / max(1.0, float(radius_x))
			var dy: float = float(y - center.y) / max(1.0, float(radius_y))
			if dx * dx + dy * dy <= 1.0:
				_item_set(image, x, y, color)

func _item_line(image: Image, from_point: Vector2, to_point: Vector2, color: Color, width := 1) -> void:
	var steps := int(max(abs(to_point.x - from_point.x), abs(to_point.y - from_point.y)))
	if steps <= 0:
		_item_ellipse(image, Vector2i(int(from_point.x), int(from_point.y)), width, width, color)
		return
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var p := from_point.lerp(to_point, t)
		_item_ellipse(image, Vector2i(int(round(p.x)), int(round(p.y))), width, width, color)

func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var loaded: Texture2D = load(path) as Texture2D
		if loaded != null:
			return loaded
	var absolute_path := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(absolute_path):
		return null
	var image := Image.load_from_file(absolute_path)
	if image == null:
		return null
	return ImageTexture.create_from_image(image)

func _atlas_frame(atlas: Texture2D, region: Rect2) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = atlas
	texture.region = region
	return texture

func _item_highlight_noise(image: Image, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in range(30):
		var x := rng.randi_range(5, image.get_width() - 6)
		var y := rng.randi_range(5, image.get_height() - 8)
		var c := image.get_pixel(x, y)
		if c.a > 0.2:
			image.set_pixel(x, y, c.lightened(rng.randf_range(0.12, 0.34)))

func _draw_player_legs(image: Image, origin: Vector2i, direction_index: int, action_index: int, frame_index: int, palette: Array[Color]) -> void:
	var stride := 0
	if action_index == 1:
		stride = [-2, 0, 2][frame_index % 3]
	var left_x := origin.x - 7
	var right_x := origin.x + 5
	var front_y := 37 if direction_index in [1, 2, 3] else 36
	_fill_rect(image, left_x - 2, front_y, left_x + 3, 48 + max(0, stride), palette[0])
	_fill_rect(image, right_x - 2, front_y, right_x + 3, 48 - min(0, stride), palette[0])
	_fill_rect(image, left_x - 1, front_y + 2, left_x + 2, 46 + max(0, stride), palette[2].darkened(0.18))
	_fill_rect(image, right_x - 1, front_y + 2, right_x + 2, 46 - min(0, stride), palette[2].darkened(0.05))
	_fill_rect(image, left_x - 4, 48 + max(0, stride), left_x + 5, 51 + max(0, stride), palette[0])
	_fill_rect(image, right_x - 4, 48 - min(0, stride), right_x + 5, 51 - min(0, stride), palette[0])

func _draw_player_body(image: Image, origin: Vector2i, direction_index: int, palette: Array[Color]) -> void:
	var shoulder_y := origin.y - 9
	var waist_y := origin.y + 11
	_fill_ellipse(image, Vector2i(origin.x, origin.y + 1), 12, 15, palette[0])
	_fill_rect(image, origin.x - 10, shoulder_y, origin.x + 10, waist_y, palette[1])
	_fill_rect(image, origin.x - 7, shoulder_y + 3, origin.x + 7, waist_y - 2, palette[2])
	_fill_rect(image, origin.x - 2, shoulder_y + 1, origin.x + 2, waist_y + 1, palette[3].darkened(0.18))
	if direction_index in [5, 6, 7]:
		_fill_rect(image, origin.x - 8, shoulder_y + 3, origin.x + 8, waist_y, palette[0].lightened(0.1))
		_fill_rect(image, origin.x - 4, shoulder_y + 6, origin.x + 4, waist_y - 3, palette[3].darkened(0.35))
	else:
		_fill_rect(image, origin.x - 5, shoulder_y + 6, origin.x + 5, shoulder_y + 9, palette[3])
		_set_pixel_safe(image, origin.x + 7, shoulder_y + 7, palette[5])

func _draw_player_head(image: Image, direction_index: int, direction: Vector2, origin: Vector2i, palette: Array[Color]) -> void:
	var head_center := Vector2i(origin.x, origin.y - 17)
	_fill_ellipse(image, head_center, 10, 9, palette[0])
	_fill_ellipse(image, Vector2i(head_center.x, head_center.y + 1), 8, 7, palette[1])
	var visor_center := Vector2i(
		head_center.x + int(round(direction.x * 4.0)),
		head_center.y + int(round(direction.y * 3.0))
	)
	if direction_index in [5, 6, 7]:
		_fill_rect(image, head_center.x - 5, head_center.y - 1, head_center.x + 5, head_center.y + 4, palette[0].lightened(0.16))
		_fill_rect(image, head_center.x - 2, head_center.y + 2, head_center.x + 2, head_center.y + 5, palette[3].darkened(0.45))
	else:
		_fill_rect(image, visor_center.x - 5, visor_center.y - 2, visor_center.x + 5, visor_center.y + 2, palette[3])
		_fill_rect(image, visor_center.x + 2, visor_center.y - 1, visor_center.x + 5, visor_center.y + 1, palette[5])

func _draw_player_arms(image: Image, direction_index: int, action_index: int, frame_index: int, origin: Vector2i, direction: Vector2, palette: Array[Color]) -> void:
	var side := 1 if direction.x >= 0.0 else -1
	var shoulder_left := Vector2(origin.x - 11, origin.y - 7)
	var shoulder_right := Vector2(origin.x + 11, origin.y - 7)
	var idle_left := Vector2(origin.x - 14, origin.y + 9)
	var idle_right := Vector2(origin.x + 14, origin.y + 9)
	_draw_line(image, shoulder_left, idle_left, palette[4], 2)
	_draw_line(image, shoulder_right, idle_right, palette[4], 2)
	if action_index == 2:
		var recoil: Array[float] = [4.0, 0.0, -3.0]
		var muzzle_flash: Array[int] = [1, 5, 2]
		var recoil_value: float = recoil[frame_index % recoil.size()]
		var hand := Vector2(origin.x, origin.y - 1) + direction * (8.0 + recoil_value)
		var muzzle := Vector2(origin.x, origin.y - 1) + direction * (19.0 + recoil_value * 0.5)
		var back_hand := Vector2(origin.x, origin.y + 3) - direction * (5.0 + float(frame_index))
		_draw_line(image, Vector2(origin.x, origin.y - 3), hand, palette[4].lightened(0.12), 2)
		_draw_line(image, Vector2(origin.x, origin.y + 2), back_hand, palette[4].darkened(0.1), 2)
		_draw_line(image, hand, muzzle, palette[0], 3)
		_draw_line(image, hand, muzzle, palette[2].lightened(0.22), 1)
		if frame_index == 1:
			_fill_ellipse(image, Vector2i(int(muzzle.x + direction.x * 4.0), int(muzzle.y + direction.y * 4.0)), muzzle_flash[frame_index % muzzle_flash.size()], muzzle_flash[frame_index % muzzle_flash.size()], Color8(255, 220, 88))
			_fill_ellipse(image, Vector2i(int(muzzle.x + direction.x * 7.0), int(muzzle.y + direction.y * 7.0)), 2, 2, Color8(77, 224, 244))
	elif action_index == 3:
		var hip: Vector2 = Vector2(origin.x - side * 8, origin.y + 10)
		var draw_hand: Vector2 = Vector2(origin.x + side * (2 + frame_index * 3), origin.y - 2 - frame_index)
		_draw_line(image, hip, draw_hand, palette[4], 2)
		_draw_line(image, hip + Vector2(0, 5), draw_hand + Vector2(side * 4, -4), palette[5].darkened(0.12), 1)
	elif action_index == 4:
		var arc_scale: Array[float] = [0.45, 1.15, 0.72]
		var slash_center: Vector2 = Vector2(origin.x, origin.y - 4) + direction * (9.0 + frame_index * 4.0)
		for i in range(-9, 10):
			var tangent: Vector2 = direction.rotated(PI * 0.5) * float(i)
			var forward: Vector2 = direction * (abs(i) * -0.32 * arc_scale[frame_index] + frame_index * 2.5)
			var slash_point: Vector2 = slash_center + tangent + forward
			var radius := 1 if frame_index == 0 else 2
			_fill_ellipse(image, Vector2i(int(slash_point.x), int(slash_point.y)), radius, radius, palette[5])
			_set_pixel_safe(image, int(slash_point.x - direction.x * 2.0), int(slash_point.y - direction.y * 2.0), palette[3].lightened(0.12))
		var sword_tip := slash_center + direction * (7.0 + frame_index * 2.0)
		_draw_line(image, Vector2(origin.x, origin.y - 1), sword_tip, palette[4], 2)
		_draw_line(image, sword_tip - direction.rotated(PI * 0.5) * 3.0, sword_tip + direction.rotated(PI * 0.5) * 3.0, palette[5], 1)
	elif action_index == 5:
		var tool_center := Vector2i(origin.x + side * (9 + frame_index), origin.y + 1)
		_fill_rect(image, tool_center.x - 4, tool_center.y - 4, tool_center.x + 5, tool_center.y + 5, palette[4].lightened(0.2))
		_fill_rect(image, tool_center.x - 2, tool_center.y - 2, tool_center.x + 3, tool_center.y + 3, palette[3].darkened(0.2))
		_draw_line(image, Vector2(origin.x + side * 10, origin.y - 5), Vector2(tool_center), palette[4], 2)
	elif action_index == 6:
		var interact_hand: Vector2 = Vector2(origin.x, origin.y - 1) + direction * (10.0 + frame_index)
		_draw_line(image, Vector2(origin.x, origin.y - 4), interact_hand, palette[4], 2)
		for i in range(1, 4):
			var scan_point: Vector2 = interact_hand + direction * float(i * 4)
			_fill_ellipse(image, Vector2i(int(scan_point.x), int(scan_point.y)), 2, 2, palette[6].lightened(0.1))

func _direction_vector(direction_index: int) -> Vector2:
	return Vector2(cos(float(direction_index) * PI / 4.0), sin(float(direction_index) * PI / 4.0)).normalized()

func _set_pixel_safe(image: Image, x: int, y: int, color: Color) -> void:
	if x >= 0 and y >= 0 and x < PLAYER_FRAME_SIZE.x and y < PLAYER_FRAME_SIZE.y:
		image.set_pixel(x, y, color)

func _fill_rect(image: Image, x0: int, y0: int, x1: int, y1: int, color: Color) -> void:
	var min_x: int = clamp(min(x0, x1), 0, PLAYER_FRAME_SIZE.x - 1)
	var max_x: int = clamp(max(x0, x1), 0, PLAYER_FRAME_SIZE.x - 1)
	var min_y: int = clamp(min(y0, y1), 0, PLAYER_FRAME_SIZE.y - 1)
	var max_y: int = clamp(max(y0, y1), 0, PLAYER_FRAME_SIZE.y - 1)
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			image.set_pixel(x, y, color)

func _fill_ellipse(image: Image, center: Vector2i, radius_x: int, radius_y: int, color: Color) -> void:
	for y in range(center.y - radius_y, center.y + radius_y + 1):
		for x in range(center.x - radius_x, center.x + radius_x + 1):
			var dx: float = float(x - center.x) / max(1.0, float(radius_x))
			var dy: float = float(y - center.y) / max(1.0, float(radius_y))
			if dx * dx + dy * dy <= 1.0:
				_set_pixel_safe(image, x, y, color)

func _draw_line(image: Image, from_point: Vector2, to_point: Vector2, color: Color, width := 1) -> void:
	var steps := int(max(abs(to_point.x - from_point.x), abs(to_point.y - from_point.y)))
	if steps <= 0:
		_fill_ellipse(image, Vector2i(int(from_point.x), int(from_point.y)), width, width, color)
		return
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var p := from_point.lerp(to_point, t)
		_fill_ellipse(image, Vector2i(int(round(p.x)), int(round(p.y))), width, width, color)
