extends RefCounted
class_name RuntimeAssetLoader

const GENERATED_ARMOR_ICONS := {
	"patched_armor": true,
	"crystal_guard": true,
	"industrial_exoshell": true
}

static func load_png(path: String) -> Texture2D:
	var generated := _generated_armor_icon(path)
	if generated != null:
		return generated

	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	var absolute_path := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(absolute_path):
		return null
	var image := Image.new()
	if image.load(absolute_path) != OK:
		return null
	return ImageTexture.create_from_image(image)

static func load_wav(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		return load(path) as AudioStream
	var absolute_path := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(absolute_path):
		return null
	var stream := AudioStreamWAV.load_from_file(absolute_path)
	return stream

static func _generated_armor_icon(path: String) -> Texture2D:
	if not path.begins_with("res://assets/sprites/items/"):
		return null

	var item_id := path.get_file().get_basename()
	if not GENERATED_ARMOR_ICONS.has(item_id):
		return null

	var image := Image.create(88, 72, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	_draw_ellipse(image, Rect2i(18, 51, 52, 12), Color(0, 0, 0, 0.32))

	match item_id:
		"patched_armor":
			_draw_armor_shape(image, Color8(104, 116, 105), Color8(53, 58, 54), Color8(36, 196, 207), false, false)
		"crystal_guard":
			_draw_armor_shape(image, Color8(83, 86, 101), Color8(40, 43, 58), Color8(157, 84, 224), true, false)
		"industrial_exoshell":
			_draw_armor_shape(image, Color8(70, 86, 102), Color8(28, 34, 42), Color8(85, 159, 224), false, true)

	return ImageTexture.create_from_image(image)

static func _draw_armor_shape(image: Image, body: Color, outline: Color, core: Color, crystal := false, heavy := false) -> void:
	var chest := Rect2i(30, 18, 29, 35)
	_draw_rect(image, Rect2i(chest.position.x - 4, chest.position.y + 4, 5, 27), outline)
	_draw_rect(image, Rect2i(chest.position.x + chest.size.x - 1, chest.position.y + 4, 5, 27), outline)
	_draw_rect(image, chest.grow(3), outline)
	_draw_rect(image, chest, body)
	_draw_rect(image, Rect2i(35, 24, 19, 18), outline.darkened(0.1))
	_draw_rect(image, Rect2i(38, 27, 13, 12), core)
	_draw_rect(image, Rect2i(38, 27, 13, 2), core.lightened(0.35))
	_draw_rect(image, Rect2i(31, 52, 10, 5), outline)
	_draw_rect(image, Rect2i(49, 52, 10, 5), outline)
	if crystal:
		_draw_line(image, Vector2i(44, 11), Vector2i(55, 18), Color8(171, 111, 255), 3)
		_draw_line(image, Vector2i(44, 11), Vector2i(34, 18), Color8(105, 214, 232), 2)
	if heavy:
		_draw_rect(image, Rect2i(24, 24, 7, 29), Color8(36, 45, 55))
		_draw_rect(image, Rect2i(59, 24, 7, 29), Color8(36, 45, 55))
		_draw_circle(image, Vector2i(29, 18), 5, Color8(70, 137, 214))
		_draw_circle(image, Vector2i(61, 18), 5, Color8(70, 137, 214))

static func _draw_rect(image: Image, rect: Rect2i, color: Color) -> void:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			_set_pixel_safe(image, x, y, color)

static func _draw_circle(image: Image, center: Vector2i, radius: int, color: Color) -> void:
	var r2 := radius * radius
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			var dx := x - center.x
			var dy := y - center.y
			if dx * dx + dy * dy <= r2:
				_set_pixel_safe(image, x, y, color)

static func _draw_ellipse(image: Image, rect: Rect2i, color: Color) -> void:
	var center := Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y + rect.size.y * 0.5)
	var rx := max(1.0, rect.size.x * 0.5)
	var ry := max(1.0, rect.size.y * 0.5)
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			var nx := (float(x) - center.x) / rx
			var ny := (float(y) - center.y) / ry
			if nx * nx + ny * ny <= 1.0:
				_set_pixel_safe(image, x, y, color)

static func _draw_line(image: Image, from_pos: Vector2i, to_pos: Vector2i, color: Color, thickness := 1) -> void:
	var delta := to_pos - from_pos
	var steps: int = max(abs(delta.x), abs(delta.y))
	if steps <= 0:
		_draw_circle(image, from_pos, max(1, thickness), color)
		return
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var p := Vector2i(roundi(lerp(float(from_pos.x), float(to_pos.x), t)), roundi(lerp(float(from_pos.y), float(to_pos.y), t)))
		if thickness <= 1:
			_set_pixel_safe(image, p.x, p.y, color)
		else:
			_draw_circle(image, p, int(ceil(float(thickness) * 0.5)), color)

static func _set_pixel_safe(image: Image, x: int, y: int, color: Color) -> void:
	if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
		return
	image.set_pixel(x, y, color)
