extends StaticBody2D
class_name WorldProp

const PIXEL := preload("res://scripts/utils/PixelArtFactory.gd")
const ASSET_LOADER := preload("res://scripts/utils/RuntimeAssetLoader.gd")

var prop_id := "rust_rock"
var blocks_movement := true
var visual_size := Vector2i(56, 56)
var collision_size := Vector2(42, 24)
var visual_asset: Dictionary = {}
var _render_scale := Vector2.ONE
var _sprite_origin := Vector2.ZERO
var _visual_bounds_local := Rect2()

func setup(id: String, blocking := true, size := Vector2i(56, 56)) -> void:
	prop_id = id
	blocks_movement = blocking
	visual_size = size
	collision_size = Vector2(max(24, size.x * 0.72), max(16, size.y * 0.28))

func _ready() -> void:
	add_to_group("world_prop")
	add_to_group("map_prop")
	set_meta("map_marker", "prop")
	y_sort_enabled = true
	var texture := _prop_texture()
	set_meta("map_label", _prop_label())
	_add_sprite(texture)
	if blocks_movement:
		add_to_group("obstacle")
		_add_collision(texture.get_size())

func _add_collision(texture_size: Vector2) -> void:
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape := RectangleShape2D.new()
	var footprint: Variant = visual_asset.get("collision_footprint", [])
	var local_position := Vector2.ZERO
	if footprint is Array and footprint.size() == 4 and texture_size.x > 0.0 and texture_size.y > 0.0:
		var left := clampf(float(footprint[0]), 0.0, 1.0)
		var top := clampf(float(footprint[1]), 0.0, 1.0)
		var width := clampf(float(footprint[2]), 0.0, 1.0 - left)
		var height := clampf(float(footprint[3]), 0.0, 1.0 - top)
		if width > 0.0 and height > 0.0:
			shape.size = Vector2(texture_size.x * width, texture_size.y * height) * _render_scale
			local_position = Vector2((left + width * 0.5) * texture_size.x, (top + height * 0.5) * texture_size.y) * _render_scale
			local_position += _sprite_origin
		else:
			shape.size = collision_size
			local_position = Vector2(0.0, -shape.size.y * 0.5)
	else:
		shape.size = collision_size
		local_position = Vector2(0.0, -shape.size.y * 0.5)
	collision.shape = shape
	collision.position = local_position
	add_child(collision)
	set_meta("collision_footprint_local", Rect2(local_position - shape.size * 0.5, shape.size))

func get_collision_bounds() -> Rect2:
	var local_rect: Rect2 = get_meta("collision_footprint_local", Rect2())
	return Rect2(global_position + local_rect.position, local_rect.size)

func get_visual_bounds() -> Rect2:
	return Rect2(global_position + _visual_bounds_local.position, _visual_bounds_local.size)

func _add_sprite(texture: Texture2D) -> void:
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = false
	var texture_size := sprite.texture.get_size() if sprite.texture != null else Vector2(visual_size)
	var content_rect := _opaque_bounds(sprite.texture)
	var content_size := Vector2(content_rect.size)
	if content_size.x <= 0.0 or content_size.y <= 0.0:
		content_rect = Rect2i(Vector2i.ZERO, Vector2i(texture_size))
		content_size = texture_size
	var target_size: Vector2 = Vector2(visual_size)
	var fit_scale: float = minf(target_size.x / maxf(1.0, content_size.x), target_size.y / maxf(1.0, content_size.y))
	_render_scale = Vector2.ONE * fit_scale * _deterministic_scale().x
	sprite.scale = _render_scale
	sprite.position = _sprite_canvas_origin(texture_size, content_rect)
	_sprite_origin = sprite.position
	var rendered_size: Vector2 = content_size * _render_scale
	_visual_bounds_local = Rect2(Vector2(-rendered_size.x * 0.5, -rendered_size.y), rendered_size)
	if prop_id != "toxic_pool":
		var shadow := Polygon2D.new()
		shadow.name = "GroundShadow"
		shadow.z_index = -1
		var rx := maxf(14.0, rendered_size.x * 0.42)
		var ry := maxf(5.0, minf(12.0, rendered_size.y * 0.12))
		var s_pts := PackedVector2Array()
		for i in range(16):
			var a := float(i) / 16.0 * TAU
			s_pts.append(Vector2(cos(a) * rx, sin(a) * ry - 3.0))
		shadow.polygon = s_pts
		shadow.color = Color(0.03, 0.02, 0.04, 0.38)
		add_child(shadow)
	sprite.modulate = _deterministic_tint()
	add_child(sprite)

func _sprite_canvas_origin(texture_size: Vector2, content_rect := Rect2i()) -> Vector2:
	var origin := Vector2(-texture_size.x * 0.5, -texture_size.y)
	if content_rect.size != Vector2i.ZERO:
		var content_size := Vector2(content_rect.size)
		origin = Vector2(-content_size.x * 0.5 - content_rect.position.x, -content_size.y - content_rect.position.y)
	return origin * _render_scale

func _opaque_bounds(texture: Texture2D) -> Rect2i:
	if texture == null:
		return Rect2i()
	if texture.has_meta("world_prop_opaque_bounds"):
		var cached_bounds: Variant = texture.get_meta("world_prop_opaque_bounds")
		if cached_bounds is Rect2i:
			return cached_bounds
	var image := texture.get_image()
	if image == null or image.is_empty():
		return Rect2i(Vector2i.ZERO, Vector2i(texture.get_size()))
	var opaque_bounds: Rect2i = image.get_used_rect()
	texture.set_meta("world_prop_opaque_bounds", opaque_bounds)
	return opaque_bounds

func _prop_texture() -> Texture2D:
	visual_asset = DataRegistry.get_visual_asset("prop_%s" % prop_id)
	var variant_prefix := String(visual_asset.get("variant_prefix", ""))
	var variants := int(visual_asset.get("variants", 0))
	if not variant_prefix.is_empty() and variants > 0:
		var index := int(abs(round(global_position.x * 0.17 + global_position.y * 0.31 + prop_id.length() * 13.0))) % variants
		var variant_path := "%s%d.png" % [variant_prefix, index]
		var variant_texture := ASSET_LOADER.load_png(variant_path)
		if variant_texture != null:
			return variant_texture
	var path := String(visual_asset.get("path", "res://assets/sprites/props/%s.png" % prop_id))
	var texture := ASSET_LOADER.load_png(path)
	if texture != null:
		return texture
	return _make_prop_texture()

func _deterministic_scale() -> Vector2:
	var seed_value := int(abs(round(global_position.x * 3.0 + global_position.y * 5.0))) + prop_id.length()
	var factor := 0.92 + float(seed_value % 17) / 100.0
	return Vector2(factor, factor)

func _deterministic_tint() -> Color:
	var seed_value := int(abs(round(global_position.x + global_position.y))) + prop_id.length() * 19
	var light := 0.92 + float(seed_value % 13) / 100.0
	return Color(light, light, light, 1.0)

func _prop_label() -> String:
	var display_name := String(visual_asset.get("display_name", ""))
	if not display_name.is_empty():
		return display_name
	match prop_id:
		"dead_tree":
			return "枯樹"
		"scrap_wall":
			return "廢鐵牆"
		"toxic_pool":
			return "毒泥池"
		"wreck":
			return "車骸"
		"signal_pylon":
			return "訊號塔"
		"road_marker":
			return "路標"
		"scrap_barricade":
			return "廢鐵路障"
		_:
			return "荒地障礙"

func _make_prop_texture() -> Texture2D:
	var palette: Array[Color] = [Color8(62, 55, 48), Color8(101, 83, 63), Color8(158, 103, 57)]
	match prop_id:
		"dead_tree":
			palette = [Color8(48, 39, 32), Color8(96, 70, 48), Color8(135, 95, 55)]
		"scrap_wall":
			palette = [Color8(39, 44, 49), Color8(92, 102, 103), Color8(190, 122, 55)]
		"toxic_pool":
			palette = [Color8(31, 47, 38), Color8(63, 149, 76), Color8(162, 221, 82)]
		"wreck":
			palette = [Color8(43, 42, 46), Color8(87, 93, 99), Color8(179, 75, 54)]
		"signal_pylon":
			palette = [Color8(35, 34, 42), Color8(84, 102, 122), Color8(68, 210, 226)]
		"road_marker":
			palette = [Color8(60, 52, 42), Color8(180, 139, 66), Color8(229, 207, 88)]
	var image := PIXEL.new().make_image(visual_size, palette, prop_id.length())
	_carve_shape(image)
	return ImageTexture.create_from_image(image)

func _carve_shape(image: Image) -> void:
	match prop_id:
		"dead_tree":
			_clear_outside_trunk(image)
		"toxic_pool":
			_clear_corners(image, 0.34)
		"signal_pylon":
			_clear_outside_pylon(image)
		"road_marker":
			_clear_corners(image, 0.2)
		_:
			_clear_corners(image, 0.18)

func _clear_corners(image: Image, edge_ratio: float) -> void:
	var size: Vector2i = image.get_size()
	var center := Vector2(size.x * 0.5, size.y * 0.55)
	var radius: float = float(min(size.x, size.y)) * (0.5 + edge_ratio)
	for y in size.y:
		for x in size.x:
			var point := Vector2(float(x), float(y))
			if point.distance_to(center) > radius and y < size.y * 0.82:
				image.set_pixel(x, y, Color(0, 0, 0, 0))

func _clear_outside_trunk(image: Image) -> void:
	var size: Vector2i = image.get_size()
	for y in size.y:
		for x in size.x:
			var trunk_width: int = 7 + int((float(y) / max(1.0, float(size.y))) * 12.0)
			var trunk_center: int = int(size.x / 2) + int(sin(float(y) * 0.14) * 4.0)
			var crown: bool = y < size.y * 0.32 and abs(x - trunk_center) < 20
			var trunk: bool = abs(x - trunk_center) < trunk_width
			if not crown and not trunk:
				image.set_pixel(x, y, Color(0, 0, 0, 0))

func _clear_outside_pylon(image: Image) -> void:
	var size: Vector2i = image.get_size()
	for y in size.y:
		for x in size.x:
			var center_x: int = int(size.x / 2)
			var arm: bool = y > size.y * 0.18 and y < size.y * 0.28 and abs(x - center_x) < 22
			var mast: bool = abs(x - center_x) < 5
			var legs: bool = y > size.y * 0.56 and (abs(x - (center_x - 10)) < 4 or abs(x - (center_x + 10)) < 4)
			if not arm and not mast and not legs:
				image.set_pixel(x, y, Color(0, 0, 0, 0))
