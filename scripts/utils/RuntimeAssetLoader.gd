extends RefCounted
class_name RuntimeAssetLoader

const PLAYER_FRAME_SIZE := Vector2i(112, 128)
const LEGACY_PLAYER_ATLAS_PATH := "res://assets/sprites/player/recycler_player_multiaction_8dir.png"
const PLAYER_PREVIEW_FRAME_PATHS := [
	"res://assets/sprites/player/frames/idle/dir_2/frame_0.png",
	"res://assets/sprites/player/frames/idle/dir_2/frame_1.png",
	"res://assets/sprites/player/frames/idle/dir_0/frame_0.png",
	"res://assets/sprites/player/frames/walk/dir_2/frame_0.png"
]


static func load_png(path: String) -> Texture2D:
	if path == LEGACY_PLAYER_ATLAS_PATH:
		var preview_atlas: Texture2D = _build_player_preview_atlas()
		if preview_atlas != null:
			return preview_atlas

	return _load_texture_from_file(path)


static func load_wav(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		return load(path) as AudioStream
	var absolute_path: String = ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(absolute_path):
		return null
	var stream: AudioStreamWAV = AudioStreamWAV.load_from_file(absolute_path)
	return stream


static func _load_texture_from_file(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D

	var image: Image = _load_image_from_path(path)
	if image == null:
		return null

	return ImageTexture.create_from_image(image)


static func _load_image_from_path(path: String) -> Image:
	var absolute_path: String = ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(absolute_path):
		return null

	var image: Image = Image.new()
	var result: Error = image.load(absolute_path)
	if result != OK:
		return null

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
