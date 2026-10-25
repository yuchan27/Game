extends StaticBody2D
class_name WorldProp

const PIXEL := preload("res://scripts/utils/PixelArtFactory.gd")
const ASSET_LOADER := preload("res://scripts/utils/RuntimeAssetLoader.gd")
const MATERIAL_KIT_PATH := "res://data/art/world_materials_v3.json"

static var _material_kit: Dictionary = {}
static var _material_kit_loaded := false
static var _atlas_textures: Dictionary = {}
static var _cutout_shader: Shader
static var _cutout_materials: Dictionary = {}
static var _ground_contact_cache: Dictionary = {}

var prop_id := "rust_rock"
var blocks_movement := true
var visual_size := Vector2i(56, 56)
var collision_size := Vector2(42, 24)
var visual_asset: Dictionary = {}
var _render_scale := Vector2.ONE
var _sprite_origin := Vector2.ZERO
var _visual_bounds_local := Rect2()
var _material_asset: Dictionary = {}
var material_route := ""
var preserve_legacy_collision := false

static func material_kit() -> Dictionary:
	if not _material_kit_loaded:
		_material_kit_loaded = true
		var file := FileAccess.open(MATERIAL_KIT_PATH, FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary and int(parsed.get("version", 0)) == 3:
				_material_kit = parsed
	return _material_kit if bool(_material_kit.get("enabled", false)) else {}

func setup(id: String, blocking := true, size := Vector2i(56, 56), route_context := "") -> void:
	prop_id = id
	material_route = route_context
	blocks_movement = blocking
	visual_size = size
	collision_size = Vector2(max(24, size.x * 0.72), max(16, size.y * 0.28))

func _ready() -> void:
	add_to_group("world_prop")
	add_to_group("map_prop")
	set_meta("map_marker", "prop")
	# The scene sorts this body's registered foot. Keep the sprite/contact art
	# together: nested Y sorting would sort by the negative canvas top instead.
	y_sort_enabled = false
	var texture := _prop_texture()
	set_meta("map_label", _prop_label())
	_add_sprite(texture)
	if blocks_movement:
		add_to_group("obstacle")
		if preserve_legacy_collision and not _material_asset.is_empty():
			_add_legacy_collision()
		else:
			_add_collision(texture.get_size())


func _add_legacy_collision() -> void:
	# Hub art can opt into the kit without moving existing saved-world blockers.
	var route := material_route
	var material := _material_asset
	var rendered_scale := _render_scale
	var origin := _sprite_origin
	material_route = ""
	var legacy := _prop_texture()
	var bounds := _opaque_bounds(legacy)
	var content_size := Vector2(bounds.size)
	if content_size.x <= 0.0 or content_size.y <= 0.0:
		bounds = Rect2i(Vector2i.ZERO, Vector2i(legacy.get_size()))
		content_size = legacy.get_size()
	var target := Vector2(visual_size)
	var fit := minf(target.x / maxf(1.0, content_size.x), target.y / maxf(1.0, content_size.y))
	_render_scale = Vector2.ONE * fit * _deterministic_scale().x
	_sprite_origin = _sprite_canvas_origin(legacy.get_size(), bounds)
	_add_collision(legacy.get_size())
	material_route = route
	_material_asset = material
	_render_scale = rendered_scale
	_sprite_origin = origin

func _add_collision(texture_size: Vector2) -> void:
	if not _material_asset.is_empty() and not _material_asset.get("footprints", []).is_empty():
		var bounds := Rect2()
		for values: Array in _material_asset.get("footprints", []):
			if values.size() != 4:
				continue
			var footprint := Rect2(float(values[0]), float(values[1]), float(values[2]), float(values[3]))
			if footprint.size.x <= 0.0 or footprint.size.y <= 0.0:
				continue
			var authored_collision := CollisionShape2D.new()
			var rectangle := RectangleShape2D.new()
			rectangle.size = footprint.size
			authored_collision.shape = rectangle
			authored_collision.position = footprint.get_center()
			add_child(authored_collision)
			bounds = footprint if bounds.size == Vector2.ZERO else bounds.merge(footprint)
		set_meta("collision_footprint_local", bounds)
		return
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape := RectangleShape2D.new()
	var footprint: Variant = visual_asset.get("collision_footprint", [])
	var local_position := Vector2.ZERO
	if not _material_asset.is_empty():
		# A legacy blocking tree keeps a small root, never its old canvas-sized wall.
		shape.size = Vector2(clampf(_visual_bounds_local.size.x * 0.35, 12.0, 28.0), 12.0)
		local_position = Vector2(0, -4)
	elif footprint is Array and footprint.size() == 4 and texture_size.x > 0.0 and texture_size.y > 0.0:
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

static func world_source_material(source: Dictionary, route_context: String) -> ShaderMaterial:
	var kit := material_kit()
	var default_cutoff := _validated_shader_number(kit.get("alpha_cutoff", 0.65), 0.65, 0.01, 0.95)
	var cutoff := _validated_shader_number(source.get("alpha_cutoff", default_cutoff), default_cutoff, 0.01, 0.95)
	var saturation := _validated_shader_number(source.get("saturation", 1.0), 1.0, 0.0, 1.0)
	var exposure := _validated_shader_number(source.get("exposure", 1.0), 1.0, 0.25, 1.5)
	var material := _base_cutout_material(cutoff)
	var contact: Dictionary = _ground_contact_settings(route_context)
	var crop: Variant = source.get("source_rect", [])
	var foot: Variant = source.get("foot", [])
	var contact_anchor_valid: bool = crop is Array and crop.size() == 4 and foot is Array and foot.size() == 2
	if contact_anchor_valid:
		for value: Variant in crop + foot:
			var value_type := typeof(value)
			if (value_type != TYPE_INT and value_type != TYPE_FLOAT) or not is_finite(float(value)):
				contact_anchor_valid = false
				break
	if contact_anchor_valid:
		var source_rect := Rect2(float(crop[0]), float(crop[1]), float(crop[2]), float(crop[3]))
		contact_anchor_valid = source_rect.size.x > 0.0 and source_rect.size.y > 0.0 and source_rect.has_point(Vector2(float(foot[0]), float(foot[1])))
	var has_contact: bool = not contact.is_empty() and contact_anchor_valid
	if has_contact or saturation != 1.0 or exposure != 1.0:
		material = material.duplicate() as ShaderMaterial
		if saturation != 1.0:
			material.set_shader_parameter("color_saturation", saturation)
		if exposure != 1.0:
			material.set_shader_parameter("color_exposure", exposure)
		if has_contact:
			material.set_shader_parameter("ground_contact_enabled", true)
			material.set_shader_parameter("ground_texture", contact["texture"])
			material.set_shader_parameter("ground_region", contact["region"])
			material.set_shader_parameter("region_tint", contact["tint"])
			material.set_shader_parameter("ground_world_size", contact["world_size"])
			material.set_shader_parameter("contact_earth_contrast", contact["earth_contrast"])
			material.set_shader_parameter("contact_band_pixels", contact["band_pixels"])
			material.set_shader_parameter("contact_strength", contact["strength"])
			material.set_shader_parameter("contact_foot_local", Vector2(float(foot[0]) - float(crop[0]), float(foot[1]) - float(crop[1])))
	return material

static func _validated_shader_number(value: Variant, fallback: float, minimum: float, maximum: float) -> float:
	var value_type := typeof(value)
	if value_type != TYPE_INT and value_type != TYPE_FLOAT:
		return fallback
	var number := float(value)
	return clampf(number, minimum, maximum) if is_finite(number) else fallback

static func _base_cutout_material(cutoff: float) -> ShaderMaterial:
	if _cutout_shader == null:
		_cutout_shader = Shader.new()
		_cutout_shader.code = """
		shader_type canvas_item;
		uniform float source_alpha_cutoff = 0.65;
		uniform float color_saturation = 1.0;
		uniform float color_exposure = 1.0;
		uniform bool ground_contact_enabled = false;
		uniform sampler2D ground_texture : source_color, filter_nearest, repeat_enable;
		uniform vec4 ground_region = vec4(0.0, 0.0, 1.0, 1.0);
		uniform vec4 region_tint : source_color = vec4(1.0);
		uniform float ground_world_size = 512.0;
		uniform float contact_earth_contrast = 0.68;
		uniform float contact_band_pixels = 5.0;
		uniform float contact_strength = 0.4;
		uniform vec2 contact_foot_local = vec2(0.0);
		varying vec2 prop_world_position;
		varying vec2 foot_world_position;
		void vertex() {
			prop_world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
			foot_world_position = (MODEL_MATRIX * vec4(contact_foot_local, 0.0, 1.0)).xy;
		}
		float grain(vec2 p) {
			vec2 cell = floor(p / 24.0);
			vec2 f = smoothstep(vec2(0.0), vec2(1.0), fract(p / 24.0));
			float a = fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
			float b = fract(sin(dot(cell + vec2(1.0, 0.0), vec2(127.1, 311.7))) * 43758.5453);
			float c = fract(sin(dot(cell + vec2(0.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
			float d = fract(sin(dot(cell + vec2(1.0), vec2(127.1, 311.7))) * 43758.5453);
			return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
		}
		void fragment() {
			vec4 source = COLOR;
			if (texture(TEXTURE, UV).a < source_alpha_cutoff) { discard; }
			if (color_exposure != 1.0) { source.rgb *= color_exposure; }
			if (color_saturation != 1.0) {
				float luminance = dot(source.rgb, vec3(0.2126, 0.7152, 0.0722));
				source.rgb = mix(vec3(luminance), source.rgb, color_saturation);
			}
			if (ground_contact_enabled && contact_strength > 0.0) {
				vec2 p = floor(prop_world_position) + vec2(0.5);
				float edge = clamp(contact_band_pixels + (grain(p) - 0.5), 3.0, 6.0);
				float distance_to_foot = abs(prop_world_position.y - foot_world_position.y);
				float contact = 1.0 - smoothstep(edge - 0.5, edge, distance_to_foot);
				vec2 ground_uv = ground_region.xy + fract(p / ground_world_size) * ground_region.zw;
				vec3 ground = texture(ground_texture, ground_uv).rgb;
				ground = mix(vec3(0.16, 0.145, 0.125), ground, contact_earth_contrast);
				ground *= region_tint.rgb;
				ground *= 0.97 + grain(p * 0.11) * 0.06;
				source.rgb = mix(source.rgb, ground, contact * contact_strength);
			}
			COLOR = source;
		}
		"""
	var material: ShaderMaterial = _cutout_materials.get(cutoff) as ShaderMaterial
	if material == null:
		material = ShaderMaterial.new()
		material.shader = _cutout_shader
		material.set_shader_parameter("source_alpha_cutoff", cutoff)
		_cutout_materials[cutoff] = material
	return material

func _add_sprite(texture: Texture2D) -> void:
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var has_ground_contact := false
	# Authored landmarks can retain their soil fragments while removing low-alpha glow.
	if _material_asset.is_empty() and visual_asset.has("alpha_cutoff"):
		var landmark_shader := Shader.new()
		landmark_shader.code = "shader_type canvas_item; uniform float alpha_cutoff = 0.15; void fragment() { if (texture(TEXTURE, UV).a < alpha_cutoff) { discard; } }"
		var landmark_material := ShaderMaterial.new()
		landmark_material.shader = landmark_shader
		landmark_material.set_shader_parameter("alpha_cutoff", clampf(float(visual_asset.get("alpha_cutoff", 0.15)), 0.01, 0.95))
		sprite.material = landmark_material
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
	if not _material_asset.is_empty():
		_render_scale = Vector2.ONE * float(_material_asset.get("width", content_size.x)) / maxf(1.0, texture_size.x)
	sprite.scale = _render_scale
	sprite.position = _sprite_canvas_origin(texture_size, content_rect)
	if not _material_asset.is_empty():
		var source: Array = _material_asset.get("source_rect", [])
		var foot: Array = _material_asset.get("foot", [])
		if source.size() == 4 and foot.size() == 2:
			sprite.position = -Vector2(float(foot[0]) - float(source[0]), float(foot[1]) - float(source[1])) * _render_scale
		var source_material := WorldProp.world_source_material(_material_asset, material_route)
		sprite.material = source_material
		has_ground_contact = bool(source_material.get_shader_parameter("ground_contact_enabled"))
	_sprite_origin = sprite.position
	var rendered_size: Vector2 = content_size * _render_scale
	_visual_bounds_local = Rect2(sprite.position + Vector2(content_rect.position) * _render_scale, rendered_size)
	if (prop_id != "toxic_pool" or not _material_asset.is_empty()) and not bool(visual_asset.get("authored_ground_contact", false)):
		_add_ground_contact(rendered_size, has_ground_contact)
	sprite.modulate = Color.WHITE if not _material_asset.is_empty() else _deterministic_tint()
	add_child(sprite)

func _add_ground_contact(rendered_size: Vector2, has_ground_contact := false) -> void:
	if material_route.is_empty():
		var legacy_shadow := Polygon2D.new()
		legacy_shadow.name = "GroundShadow"
		legacy_shadow.z_index = -1
		var points := PackedVector2Array()
		for index in range(16):
			var angle := float(index) / 16.0 * TAU
			points.append(Vector2(cos(angle) * maxf(14.0, rendered_size.x * 0.42), sin(angle) * maxf(5.0, minf(12.0, rendered_size.y * 0.12)) - 3.0))
		legacy_shadow.polygon = points
		legacy_shadow.color = Color(0.03, 0.02, 0.04, 0.38)
		add_child(legacy_shadow)
		return
	if has_ground_contact:
		return
	# Small stepped contact sits at the registered foot; no floating oval below the art.
	var half_width := snappedf(maxf(10.0, rendered_size.x * 0.34), 2.0)
	var depth := snappedf(clampf(rendered_size.y * 0.055, 4.0, 9.0), 2.0)
	var skirt := Polygon2D.new()
	skirt.name = "GroundContact"
	skirt.z_index = -1
	skirt.polygon = PackedVector2Array([
		Vector2(-half_width - 4, -depth), Vector2(-half_width * 0.4, -depth - 4),
		Vector2(half_width - 4, -depth), Vector2(half_width + 6, 0),
		Vector2(half_width * 0.5, depth), Vector2(-half_width + 2, depth - 2),
		Vector2(-half_width - 6, 0)])
	skirt.color = Color8(47, 43, 36, 190)
	add_child(skirt)
	var shadow := Polygon2D.new()
	shadow.name = "GroundShadow"
	shadow.z_index = -1
	shadow.polygon = PackedVector2Array([Vector2(-half_width, -depth), Vector2(half_width - 2, -depth + 2), Vector2(half_width, 2), Vector2(-half_width + 4, 4)])
	shadow.color = Color8(18, 20, 19, 135)
	add_child(shadow)

static func _ground_contact_settings(route_id: String) -> Dictionary:
	if _ground_contact_cache.has(route_id):
		var cached: Variant = _ground_contact_cache[route_id]
		if cached is Dictionary:
			return cached
	var kit := material_kit()
	var config: Variant = kit.get("ground_contact", {})
	if not config is Dictionary or not bool(config.get("enabled", false)):
		return _cache_ground_contact(route_id, {})
	var ground_root: Variant = kit.get("ground", {})
	if not ground_root is Dictionary:
		return _cache_ground_contact(route_id, {})
	var base_earth: Variant = ground_root.get("earth", {})
	if not base_earth is Dictionary:
		return _cache_ground_contact(route_id, {})
	var region_config: Dictionary = {}
	var regions: Variant = kit.get("regions", {})
	if regions is Dictionary:
		var route_region: Variant = regions.get(route_id, {})
		if route_region is Dictionary:
			region_config = route_region
	var earth_entries: Array = []
	var regional_earth: Variant = region_config.get("earth", {})
	if regional_earth is Dictionary:
		earth_entries.append(regional_earth)
	earth_entries.append(base_earth)
	for earth_entry: Variant in earth_entries:
		if not earth_entry is Dictionary:
			continue
		var texture := ASSET_LOADER.load_png(String(earth_entry.get("path", "")))
		if texture == null or texture.get_width() <= 0 or texture.get_height() <= 0:
			continue
		var raw_rect: Variant = earth_entry.get("source_rect", [0, 0, texture.get_width(), texture.get_height()])
		if not raw_rect is Array or raw_rect.size() != 4:
			continue
		var rect := Rect2(float(raw_rect[0]), float(raw_rect[1]), float(raw_rect[2]), float(raw_rect[3]))
		if rect.size.x <= 0.0 or rect.size.y <= 0.0 or not Rect2(Vector2.ZERO, texture.get_size()).encloses(rect):
			continue
		var earth_contrast := 0.68
		var configured_contrast: Variant = region_config.get("earth_contrast", 0.68)
		var contrast_type := typeof(configured_contrast)
		if contrast_type == TYPE_INT or contrast_type == TYPE_FLOAT:
			var contrast_value := float(configured_contrast)
			if is_finite(contrast_value) and contrast_value >= 0.0 and contrast_value <= 1.0:
				earth_contrast = contrast_value
		var contact := {
			"texture": texture,
			"region": Vector4(rect.position.x / texture.get_width(), rect.position.y / texture.get_height(), rect.size.x / texture.get_width(), rect.size.y / texture.get_height()),
			"tint": _ground_region_tint(route_id, region_config),
			"earth_contrast": earth_contrast,
			"world_size": maxf(32.0, float(earth_entry.get("world_size", 512.0))),
			"band_pixels": clampf(float(config.get("band_pixels", 5.0)), 3.0, 6.0),
			"strength": clampf(float(config.get("strength", 0.4)), 0.0, 1.0)
		}
		return _cache_ground_contact(route_id, contact)
	return _cache_ground_contact(route_id, {})

static func _cache_ground_contact(route_id: String, settings: Dictionary) -> Dictionary:
	_ground_contact_cache[route_id] = settings
	return settings

static func _ground_region_tint(route_id: String, region_config: Dictionary) -> Color:
	var tint := Color.WHITE
	match route_id:
		"toxic_marsh": tint = Color(0.90, 0.98, 0.88)
		"crystal_scar": tint = Color(0.95, 0.90, 1.0)
		"old_factory": tint = Color(1.0, 0.93, 0.87)
		"ruined_metropolis": tint = Color(0.94, 0.95, 0.98)
		"underground_facility": tint = Color(0.87, 0.97, 1.0)
	var regional_tint: Variant = region_config.get("tint", [])
	if regional_tint is Array and regional_tint.size() == 3:
		var tint_valid := true
		for value in regional_tint:
			var value_type := typeof(value)
			if value_type != TYPE_INT and value_type != TYPE_FLOAT:
				tint_valid = false
				break
			var channel := float(value)
			if not is_finite(channel) or channel < 0.0 or channel > 1.0:
				tint_valid = false
				break
		if tint_valid:
			tint = Color(float(regional_tint[0]), float(regional_tint[1]), float(regional_tint[2]))
	return tint

func _sprite_canvas_origin(texture_size: Vector2, content_rect := Rect2i()) -> Vector2:
	var origin := Vector2(-texture_size.x * 0.5, -texture_size.y)
	if content_rect.size != Vector2i.ZERO:
		var content_size := Vector2(content_rect.size)
		origin = Vector2(-content_size.x * 0.5 - content_rect.position.x, -content_size.y - content_rect.position.y)
	return origin * _render_scale

func _opaque_bounds(texture: Texture2D) -> Rect2i:
	if texture == null:
		return Rect2i()
	var cutoff := 0.0 if _material_asset.is_empty() else float(_material_asset.get("alpha_cutoff", material_kit().get("alpha_cutoff", 0.65)))
	var cache_key := "world_prop_opaque_bounds_alpha_%d" % int(ceilf(cutoff * 255.0))
	if texture.has_meta(cache_key):
		var cached_bounds: Variant = texture.get_meta(cache_key)
		if cached_bounds is Rect2i:
			return cached_bounds
	var image := texture.get_image()
	if image == null or image.is_empty():
		return Rect2i(Vector2i.ZERO, Vector2i(texture.get_size()))
	var opaque_bounds: Rect2i = image.get_used_rect()
	if cutoff > 0.0:
		var minimum := image.get_size()
		var maximum := Vector2i(-1, -1)
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				if image.get_pixel(x, y).a >= cutoff:
					minimum = minimum.min(Vector2i(x, y))
					maximum = maximum.max(Vector2i(x, y))
		opaque_bounds = Rect2i(minimum, maximum - minimum + Vector2i.ONE) if maximum.x >= minimum.x else Rect2i()
	texture.set_meta(cache_key, opaque_bounds)
	return opaque_bounds

func _prop_texture() -> Texture2D:
	visual_asset = DataRegistry.get_visual_asset("prop_%s" % prop_id)
	_material_asset = _cohesive_asset()
	if not _material_asset.is_empty():
		var source: Array = _material_asset.get("source_rect", [])
		if source.size() == 4:
			var source_path := String(_material_asset.get("path", ""))
			var cache_key := "%s|%s" % [source_path, JSON.stringify(source)]
			if _atlas_textures.has(cache_key):
				return _atlas_textures[cache_key] as AtlasTexture
			var source_texture := ASSET_LOADER.load_png(source_path)
			if source_texture != null:
				var atlas := AtlasTexture.new()
				atlas.atlas = source_texture
				atlas.region = Rect2(float(source[0]), float(source[1]), float(source[2]), float(source[3]))
				atlas.filter_clip = true
				_atlas_textures[cache_key] = atlas
				return atlas
		_material_asset = {}
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
		var fallback_source: Variant = visual_asset.get("source_rect", [])
		if fallback_source is Array and fallback_source.size() == 4:
			var region := Rect2(float(fallback_source[0]), float(fallback_source[1]), float(fallback_source[2]), float(fallback_source[3]))
			if region.size.x > 0.0 and region.size.y > 0.0 and Rect2(Vector2.ZERO, texture.get_size()).encloses(region):
				var atlas := AtlasTexture.new()
				atlas.atlas = texture
				atlas.region = region
				atlas.filter_clip = true
				return atlas
		return texture
	return _make_prop_texture()

func _cohesive_asset() -> Dictionary:
	if material_route.is_empty():
		return {}
	var props: Dictionary = material_kit().get("props", {})
	if props.has(prop_id):
		var direct_asset: Variant = props[prop_id]
		if direct_asset is Dictionary:
			var route_ids: Variant = direct_asset.get("route_ids", [])
			var universal: bool = not direct_asset.has("route_ids") or (route_ids is Array and route_ids.is_empty())
			if universal or (route_ids is Array and material_route in route_ids):
				return direct_asset
	# Preserve all six evidence landmarks and their authored legacy collision feet.
	if bool(visual_asset.get("unique_required", false)):
		return {}
	var key := ""
	match prop_id:
		"rust_rock", "ore_node": key = "rubble_a"
		"scrap_pile": key = "rubble_b"
		"scrap_wall", "scrap_barricade", "ruin_wall": key = "wall_stub"
		"wreck": key = "wagon"
		"dead_tree": key = "thorn"
		"herb_patch": key = "dry_grass"
		"barrel_stack": key = "supply"
		"road_marker", "signal_pylon": key = "waypost"
		"crystal_node": key = "" if material_route == "crystal_scar" else "rubble_b"
		"toxic_pool": key = "" if material_route == "toxic_marsh" else "rubble_b"
	return props.get(key, {})

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
