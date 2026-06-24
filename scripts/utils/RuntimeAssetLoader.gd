extends RefCounted
class_name RuntimeAssetLoader

const PLAYER_FRAME_SIZE := Vector2i(112, 128)
const LEGACY_PLAYER_ATLAS_PATH := "res://assets/sprites/player/recycler_player_multiaction_8dir.png"
const ARMOR_ICON_DIR := "res://assets/sprites/items/armor/"
const ARMOR_ICON_CANVAS_SIZE := Vector2i(256, 256)
const PLAYER_PREVIEW_FRAME_PATHS := [
	"res://assets/sprites/player/frames/idle/dir_2/frame_0.png",
	"res://assets/sprites/player/frames/idle/dir_2/frame_1.png",
	"res://assets/sprites/player/frames/idle/dir_0/frame_0.png",
	"res://assets/sprites/player/frames/walk/dir_2/frame_0.png"
]

static var _texture_cache: Dictionary = {}


static func load_png(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _texture_cache.has(path):
		return _texture_cache[path] as Texture2D

	var texture: Texture2D = null
	if path == LEGACY_PLAYER_ATLAS_PATH:
		# 舊版 player atlas 在目前分支不存在時，不再嘗試讀取缺檔，避免 Godot 一直輸出 .ctex 錯誤。
		texture = _build_player_preview_atlas()
	elif _is_armor_icon_path(path):
		texture = _load_transparent_armor_icon(path)
	else:
		texture = _load_texture_from_file(path)

	if texture != null:
		_texture_cache[path] = texture
	return texture


static func load_wav(path: String) -> AudioStream:
	if path.is_empty():
		return null

	# 音樂檔在 Git 切換或手動覆蓋後，Godot 可能還會沿用 .godot/imported 裡的舊匯入快取。
	# 這裡優先直接讀取目前工作目錄的原始檔，並依檔頭判斷實際格式。
	# 有些音樂副檔名是 .wav，但內容其實是 MP3；直接丟給 WAV parser 會出現「Not a WAV file」。
	var absolute_path: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute_path):
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(absolute_path)
		var direct_stream: AudioStream = _audio_stream_from_bytes(bytes, path)
		if direct_stream != null:
			return direct_stream

	if ResourceLoader.exists(path):
		return load(path) as AudioStream
	return null


static func _audio_stream_from_bytes(bytes: PackedByteArray, path: String) -> AudioStream:
	if bytes.size() < 4:
		return null
	if _has_ascii_header(bytes, "RIFF"):
		var wav_stream: AudioStreamWAV = AudioStreamWAV.load_from_buffer(bytes)
		return wav_stream
	if _looks_like_mp3(bytes) or path.get_extension().to_lower() == "mp3":
		var mp3_stream: AudioStreamMP3 = AudioStreamMP3.new()
		mp3_stream.data = bytes
		return mp3_stream
	return null


static func _has_ascii_header(bytes: PackedByteArray, header: String) -> bool:
	if bytes.size() < header.length():
		return false
	for index: int in range(header.length()):
		if int(bytes[index]) != header.unicode_at(index):
			return false
	return true


static func _looks_like_mp3(bytes: PackedByteArray) -> bool:
	if bytes.size() >= 3:
		var has_id3_header: bool = int(bytes[0]) == 0x49 and int(bytes[1]) == 0x44 and int(bytes[2]) == 0x33
		if has_id3_header:
			return true
	if bytes.size() >= 2:
		var first_byte: int = int(bytes[0])
		var second_byte: int = int(bytes[1])
		return first_byte == 0xFF and (second_byte & 0xE0) == 0xE0
	return false


static func _load_texture_from_file(path: String) -> Texture2D:
	# PNG 一律優先用 Image 直接讀原檔，避免 .import 存在但 .godot/imported/*.ctex 遺失時報錯。
	# 掉落物圖示已經改成預先處理好的小尺寸透明 PNG，不再在執行期掃像素去背，避免載入變慢。
	if path.get_extension().to_lower() == "png":
		var image: Image = _load_image_from_path(path)
		if image != null:
			return ImageTexture.create_from_image(image)

	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


static func _load_transparent_armor_icon(path: String) -> Texture2D:
	var image: Image = _load_image_from_path(path)
	if image == null:
		return null
	_strip_connected_light_background(image)
	var fitted: Image = _fit_image_to_canvas(image, ARMOR_ICON_CANVAS_SIZE, 14)
	return ImageTexture.create_from_image(fitted)


static func _load_image_from_path(path: String) -> Image:
	var absolute_path: String = ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(absolute_path):
		return null

	var image: Image = Image.new()
	var result: Error = image.load(absolute_path)
	if result != OK:
		return null
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	return image


static func _build_player_preview_atlas() -> Texture2D:
	var frame_image: Image = null
	for frame_path: String in PLAYER_PREVIEW_FRAME_PATHS:
		frame_image = _load_image_from_path(frame_path)
		if frame_image != null:
			break

	if frame_image == null:
		return null

	var atlas_image: Image = Image.create(PLAYER_FRAME_SIZE.x, PLAYER_FRAME_SIZE.y * 3, false, Image.FORMAT_RGBA8)
	atlas_image.fill(Color(0, 0, 0, 0))
	_blit_centered(frame_image, atlas_image, Rect2i(0, PLAYER_FRAME_SIZE.y * 2, PLAYER_FRAME_SIZE.x, PLAYER_FRAME_SIZE.y))
	return ImageTexture.create_from_image(atlas_image)


static func _blit_centered(source: Image, target: Image, target_rect: Rect2i) -> void:
	var copy_size: Vector2i = Vector2i(min(source.get_width(), target_rect.size.x), min(source.get_height(), target_rect.size.y))
	if copy_size.x <= 0 or copy_size.y <= 0:
		return

	var source_pos: Vector2i = Vector2i(max(0, int((source.get_width() - copy_size.x) * 0.5)), max(0, int((source.get_height() - copy_size.y) * 0.5)))
	var target_pos: Vector2i = Vector2i(target_rect.position.x + int((target_rect.size.x - copy_size.x) * 0.5), target_rect.position.y + int((target_rect.size.y - copy_size.y) * 0.5))
	target.blit_rect(source, Rect2i(source_pos, copy_size), target_pos)


static func _is_armor_icon_path(path: String) -> bool:
	return path.begins_with(ARMOR_ICON_DIR) and path.get_extension().to_lower() == "png"


static func _strip_connected_light_background(image: Image) -> void:
	var width: int = image.get_width()
	var height: int = image.get_height()
	if width <= 0 or height <= 0:
		return

	var visited: PackedByteArray = PackedByteArray()
	visited.resize(width * height)
	var stack: Array[Vector2i] = []
	for x in range(width):
		_push_background_candidate(image, visited, stack, Vector2i(x, 0), width, height)
		_push_background_candidate(image, visited, stack, Vector2i(x, height - 1), width, height)
	for y in range(height):
		_push_background_candidate(image, visited, stack, Vector2i(0, y), width, height)
		_push_background_candidate(image, visited, stack, Vector2i(width - 1, y), width, height)

	while not stack.is_empty():
		var point: Vector2i = stack.pop_back()
		image.set_pixel(point.x, point.y, Color(0, 0, 0, 0))
		_push_background_candidate(image, visited, stack, point + Vector2i(1, 0), width, height)
		_push_background_candidate(image, visited, stack, point + Vector2i(-1, 0), width, height)
		_push_background_candidate(image, visited, stack, point + Vector2i(0, 1), width, height)
		_push_background_candidate(image, visited, stack, point + Vector2i(0, -1), width, height)


static func _push_background_candidate(image: Image, visited: PackedByteArray, stack: Array[Vector2i], point: Vector2i, width: int, height: int) -> void:
	if point.x < 0 or point.y < 0 or point.x >= width or point.y >= height:
		return
	var index: int = point.y * width + point.x
	if visited[index] != 0:
		return
	visited[index] = 1
	if _is_light_background_pixel(image.get_pixel(point.x, point.y)):
		stack.append(point)


static func _is_light_background_pixel(color: Color) -> bool:
	if color.a <= 0.05:
		return true
	var max_channel: float = max(color.r, max(color.g, color.b))
	var min_channel: float = min(color.r, min(color.g, color.b))
	var saturation: float = max_channel - min_channel
	if max_channel >= 0.78 and saturation <= 0.18:
		return true
	return color.r >= 0.82 and color.g >= 0.80 and color.b >= 0.76


static func _fit_image_to_canvas(image: Image, canvas_size: Vector2i, padding: int) -> Image:
	var bounds: Rect2i = _opaque_bounds(image)
	var canvas: Image = Image.create(canvas_size.x, canvas_size.y, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0, 0, 0, 0))
	if bounds.size.x <= 0 or bounds.size.y <= 0:
		return canvas

	var cropped: Image = Image.create(bounds.size.x, bounds.size.y, false, Image.FORMAT_RGBA8)
	cropped.fill(Color(0, 0, 0, 0))
	cropped.blit_rect(image, bounds, Vector2i.ZERO)

	var max_draw_size: Vector2i = Vector2i(max(1, canvas_size.x - padding * 2), max(1, canvas_size.y - padding * 2))
	var scale: float = min(float(max_draw_size.x) / float(bounds.size.x), float(max_draw_size.y) / float(bounds.size.y))
	var draw_size: Vector2i = Vector2i(max(1, int(round(float(bounds.size.x) * scale))), max(1, int(round(float(bounds.size.y) * scale))))
	cropped.resize(draw_size.x, draw_size.y, Image.INTERPOLATE_LANCZOS)

	var target_pos: Vector2i = Vector2i(int((canvas_size.x - draw_size.x) * 0.5), int((canvas_size.y - draw_size.y) * 0.5))
	canvas.blit_rect(cropped, Rect2i(Vector2i.ZERO, draw_size), target_pos)
	return canvas


static func _opaque_bounds(image: Image) -> Rect2i:
	var min_x: int = image.get_width()
	var min_y: int = image.get_height()
	var max_x: int = -1
	var max_y: int = -1
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.04:
				min_x = min(min_x, x)
				min_y = min(min_y, y)
				max_x = max(max_x, x)
				max_y = max(max_y, y)
	if max_x < min_x or max_y < min_y:
		return Rect2i(Vector2i.ZERO, Vector2i.ZERO)
	return Rect2i(Vector2i(min_x, min_y), Vector2i(max_x - min_x + 1, max_y - min_y + 1))
