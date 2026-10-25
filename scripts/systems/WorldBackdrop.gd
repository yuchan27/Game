extends Node2D
class_name WorldBackdrop

class DrawChunk extends Node2D:
	var backdrop: Node2D
	var tile_start := Vector2i.ZERO
	var tile_end := Vector2i.ZERO

	func _draw() -> void:
		if is_instance_valid(backdrop):
			backdrop.call("_draw_chunk", self, tile_start, tile_end)

const ASSET_LOADER := preload("res://scripts/utils/RuntimeAssetLoader.gd")
const CHUNK_TILE_SIZE := 16
const WASTELAND_SURFACE_SIZE := 64
const MATERIAL_MASK_STEP := 8.0

static var _wasteland_surface_cache: Dictionary = {}
static var _ground_shader: Shader
static var _ground_mask_cache: Dictionary = {}

var mode := "village"
var map_size := Vector2i(60, 40)
var tile_size := 32
var world_seed := 9527
var tile_texture: Texture2D
var road_texture: Texture2D
var toxic_texture: Texture2D
var crystal_texture: Texture2D
var factory_texture: Texture2D
var toxic_path_texture: Texture2D
var crystal_path_texture: Texture2D
var factory_path_texture: Texture2D
var wasteland_surface_texture: Texture2D
var route_id := ""
var _chunks: Array[Node2D] = []
var _tile_rng_states := PackedInt64Array()
var _authored_road_tiles := PackedByteArray()
var _authored_road_directions := PackedByteArray()
var _authored_road_offsets := PackedFloat32Array()
var _authored_ground_tiles := PackedByteArray()
var _has_authored_paths := false
var _batch_rects: Array = []
var _batch_lines: Array = []
var _batch_circles: Array = []
var _ground_material: ShaderMaterial
var _material_roads: Array[Dictionary] = []
var _material_areas: Array[Dictionary] = []
# Separate registered feet preserve authored openings between structure supports.
var _material_architecture_feet: Array[Rect2] = []
var _material_mask_key := ""

func setup(new_mode: String, size_tiles: Vector2i, new_seed: int, new_route_id := "") -> void:
	mode = new_mode
	map_size = size_tiles
	world_seed = new_seed
	route_id = new_route_id
	tile_texture = _load_tile_texture()
	road_texture = ASSET_LOADER.load_png("res://assets/sprites/tiles/wasteland_road_variants_2p5d.png")
	toxic_texture = ASSET_LOADER.load_png("res://assets/sprites/tiles/toxic_mud_variants_2p5d.png")
	crystal_texture = ASSET_LOADER.load_png("res://assets/sprites/tiles/crystal_ground_variants_2p5d.png")
	factory_texture = ASSET_LOADER.load_png("res://assets/sprites/tiles/factory_ground_variants_2p5d.png")
	toxic_path_texture = ASSET_LOADER.load_png("res://assets/sprites/tiles/toxic_path_variants_2p5d.png")
	crystal_path_texture = ASSET_LOADER.load_png("res://assets/sprites/tiles/crystal_path_variants_2p5d.png")
	factory_path_texture = ASSET_LOADER.load_png("res://assets/sprites/tiles/factory_path_variants_2p5d.png")
	_build_authored_road_tiles()
	_build_authored_ground_tiles()
	_load_ground_material()
	wasteland_surface_texture = null
	if mode == "wasteland" and _ground_material == null:
		wasteland_surface_texture = _get_wasteland_surface_texture(route_id)
	_rebuild_chunks()


func _build_authored_road_tiles() -> void:
	_authored_road_tiles.clear()
	_authored_road_directions.clear()
	_authored_road_offsets.clear()
	if mode != "wasteland" or map_size.x <= 0 or map_size.y <= 0:
		return
	_authored_road_tiles.resize(map_size.x * map_size.y)
	_authored_road_tiles.fill(0)
	_authored_road_directions.resize(map_size.x * map_size.y)
	_authored_road_directions.fill(0)
	_authored_road_offsets.resize(map_size.x * map_size.y)
	_authored_road_offsets.fill(0.0)
	var route: Dictionary = DataRegistry.get_wasteland_route(route_id)
	var paths: Array = route.get("exploration_paths", [])
	_has_authored_paths = not paths.is_empty()
	var widths: Array = route.get("path_widths", [])
	for path_index in range(paths.size()):
		var raw_path: Array = paths[path_index]
		var half_width := float(widths[path_index]) * 0.5 if path_index < widths.size() else 3.5
		for index in range(1, raw_path.size()):
			var a := Vector2(float(raw_path[index - 1][0]) * map_size.x, float(raw_path[index - 1][1]) * map_size.y)
			var b := Vector2(float(raw_path[index][0]) * map_size.x, float(raw_path[index][1]) * map_size.y)
			var minimum := Vector2i(floori(minf(a.x, b.x) - half_width - 1.5), floori(minf(a.y, b.y) - half_width - 1.5))
			var maximum := Vector2i(ceili(maxf(a.x, b.x) + half_width + 1.5), ceili(maxf(a.y, b.y) + half_width + 1.5))
			for y in range(maxi(0, minimum.y), mini(map_size.y, maximum.y + 1)):
				for x in range(maxi(0, minimum.x), mini(map_size.x, maximum.x + 1)):
					var center := Vector2(x + 0.5, y + 0.5)
					var nearest := Geometry2D.get_closest_point_to_segment(center, a, b)
					var distance := center.distance_to(nearest)
					if distance > half_width + 1.3:
						continue
					var value := 1 if distance > half_width else (3 if distance < 0.48 else 2)
					var tile_index := y * map_size.x + x
					if value >= _authored_road_tiles[tile_index]:
						_authored_road_tiles[tile_index] = value
						_authored_road_directions[tile_index] = 1 if absf(b.x - a.x) >= absf(b.y - a.y) else 2
						_authored_road_offsets[tile_index] = distance
	for point: Dictionary in route.get("exploration_points", []):
		var raw_position: Array = point.get("position", [0.5, 0.5])
		var center := Vector2(float(raw_position[0]) * map_size.x, float(raw_position[1]) * map_size.y)
		for y in range(maxi(0, floori(center.y - 5.0)), mini(map_size.y, ceili(center.y + 5.0))):
			for x in range(maxi(0, floori(center.x - 7.0)), mini(map_size.x, ceili(center.x + 7.0))):
				if Vector2((x - center.x) / 7.0, (y - center.y) / 5.0).length_squared() <= 1.0:
					_authored_road_tiles[y * map_size.x + x] = maxi(2, _authored_road_tiles[y * map_size.x + x])


func _build_authored_ground_tiles() -> void:
	_authored_ground_tiles.resize(map_size.x * map_size.y)
	_authored_ground_tiles.fill(0)
	if mode != "wasteland":
		return
	var file := FileAccess.open("res://data/art/world_v2.json", FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return
	var composition: Dictionary = parsed.get("routes", {}).get(route_id, {})
	var kinds := {"water": 1, "chasm": 2, "furnace": 3, "rubble": 4, "coolant": 5}
	var world_extent := Vector2(map_size) * tile_size
	for area: Dictionary in composition.get("ground_areas", []):
		var values: Array = area.get("rect", [])
		if values.size() != 4:
			continue
		var rect := Rect2(float(values[0]) * map_size.x, float(values[1]) * map_size.y, float(values[2]) * map_size.x, float(values[3]) * map_size.y)
		var world_bounds := Rect2(Vector2(float(values[0]), float(values[1])) * world_extent, Vector2(float(values[2]), float(values[3])) * world_extent)
		var outline := parse_ground_outline(area.get("outline", null), world_extent, world_bounds)
		for y in range(maxi(0, floori(rect.position.y)), mini(map_size.y, ceili(rect.end.y))):
			for x in range(maxi(0, floori(rect.position.x)), mini(map_size.x, ceili(rect.end.x))):
				if not outline.is_empty() and not Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5) * tile_size, outline):
					continue
				_authored_ground_tiles[y * map_size.x + x] = int(kinds.get(String(area.get("kind", "water")), 1))


static func parse_ground_outline(raw: Variant, world_extent: Vector2, world_bounds: Rect2) -> PackedVector2Array:
	var invalid := PackedVector2Array()
	if not raw is Array or raw.size() < 3 or world_extent.x <= 0.0 or world_extent.y <= 0.0 or world_bounds.size.x <= 0.0 or world_bounds.size.y <= 0.0:
		return invalid
	var points := PackedVector2Array()
	var allowed_bounds := world_bounds.grow(0.01)
	for raw_point in raw:
		if not raw_point is Array or raw_point.size() != 2:
			return invalid
		if (typeof(raw_point[0]) != TYPE_INT and typeof(raw_point[0]) != TYPE_FLOAT) or (typeof(raw_point[1]) != TYPE_INT and typeof(raw_point[1]) != TYPE_FLOAT):
			return invalid
		var normalized := Vector2(float(raw_point[0]), float(raw_point[1]))
		if not is_finite(normalized.x) or not is_finite(normalized.y) or normalized.x < 0.0 or normalized.x > 1.0 or normalized.y < 0.0 or normalized.y > 1.0:
			return invalid
		var point := normalized * world_extent
		if not allowed_bounds.has_point(point):
			return invalid
		for existing: Vector2 in points:
			if existing.distance_squared_to(point) <= 0.0001:
				return invalid
		points.append(point)
	var double_area := 0.0
	for index in range(points.size()):
		double_area += points[index].cross(points[(index + 1) % points.size()])
	if absf(double_area) <= 0.01:
		return invalid
	for index in range(points.size()):
		var previous: Vector2 = points[(index + points.size() - 1) % points.size()]
		var current: Vector2 = points[index]
		var next: Vector2 = points[(index + 1) % points.size()]
		if absf((current - previous).cross(next - current)) <= 0.001 and (current - previous).dot(next - current) < 0.0:
			return invalid
	for first in range(points.size()):
		var first_next := (first + 1) % points.size()
		for second in range(first + 1, points.size()):
			var second_next := (second + 1) % points.size()
			if first_next == second or second_next == first:
				continue
			if _ground_segments_intersect(points[first], points[first_next], points[second], points[second_next]):
				return invalid
	return points


static func _ground_segments_intersect(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	var ab_c := (b - a).cross(c - a)
	var ab_d := (b - a).cross(d - a)
	var cd_a := (d - c).cross(a - c)
	var cd_b := (d - c).cross(b - c)
	const EPSILON := 0.001
	if ((ab_c > EPSILON and ab_d < -EPSILON) or (ab_c < -EPSILON and ab_d > EPSILON)) and ((cd_a > EPSILON and cd_b < -EPSILON) or (cd_a < -EPSILON and cd_b > EPSILON)):
		return true
	return (absf(ab_c) <= EPSILON and _ground_point_on_segment(c, a, b)) or (absf(ab_d) <= EPSILON and _ground_point_on_segment(d, a, b)) or (absf(cd_a) <= EPSILON and _ground_point_on_segment(a, c, d)) or (absf(cd_b) <= EPSILON and _ground_point_on_segment(b, c, d))


static func _ground_point_on_segment(point: Vector2, a: Vector2, b: Vector2) -> bool:
	const EPSILON := 0.001
	return point.x >= minf(a.x, b.x) - EPSILON and point.x <= maxf(a.x, b.x) + EPSILON and point.y >= minf(a.y, b.y) - EPSILON and point.y <= maxf(a.y, b.y) + EPSILON


static func ground_outline_contains_or_near(outline: PackedVector2Array, point: Vector2, distance: float) -> bool:
	if outline.size() < 3:
		return false
	if Geometry2D.is_point_in_polygon(point, outline):
		return true
	var limit_squared := distance * distance
	for index in range(outline.size()):
		var closest := Geometry2D.get_closest_point_to_segment(point, outline[index], outline[(index + 1) % outline.size()])
		if point.distance_squared_to(closest) <= limit_squared:
			return true
	return false


func _load_ground_material() -> void:
	_ground_material = null
	_material_roads.clear()
	_material_areas.clear()
	_material_architecture_feet.clear()
	if mode not in ["wasteland", "village", "guild"]:
		return
	var file := FileAccess.open("res://data/art/world_materials_v3.json", FileAccess.READ)
	if file == null:
		return
	var manifest: Variant = JSON.parse_string(file.get_as_text())
	if not manifest is Dictionary or manifest.get("version", 0) != 3 or manifest.get("enabled", false) != true:
		return
	var ground: Variant = manifest.get("ground", {})
	if not ground is Dictionary:
		return
	var region_config: Dictionary = {}
	var region_entries: Variant = manifest.get("regions", {})
	if region_entries is Dictionary:
		var route_region: Variant = region_entries.get(route_id, {})
		if route_region is Dictionary:
			region_config = route_region
	var textures: Array[Texture2D] = []
	var regions: Array[Vector4] = []
	var scales: Array[float] = []
	for key in ["earth", "road"]:
		var entry: Variant = region_config.get(key, ground.get(key, {}))
		if not entry is Dictionary:
			return
		var texture := ASSET_LOADER.load_png(String(entry.get("path", "")))
		if texture == null:
			return
		var raw: Variant = entry.get("source_rect", [0, 0, texture.get_width(), texture.get_height()])
		if not raw is Array or raw.size() != 4:
			return
		var region := Rect2(float(raw[0]), float(raw[1]), float(raw[2]), float(raw[3]))
		if region.size.x <= 0 or region.size.y <= 0 or not Rect2(Vector2.ZERO, texture.get_size()).encloses(region):
			return
		textures.append(texture)
		regions.append(Vector4(region.position.x / texture.get_width(), region.position.y / texture.get_height(), region.size.x / texture.get_width(), region.size.y / texture.get_height()))
		scales.append(maxf(32.0, float(entry.get("world_size", 512.0))))
	var water_texture: Texture2D = textures[0]
	var water_region: Vector4 = regions[0]
	var water_size: float = scales[0]
	var water_enabled := false
	var water_entry: Variant = region_config.get("water")
	if water_entry is Dictionary:
		var candidate: Texture2D = ASSET_LOADER.load_png(String(water_entry.get("path", "")))
		var raw_size: Variant = water_entry.get("world_size", 512.0)
		var size_type := typeof(raw_size)
		var size_valid := (size_type == TYPE_INT or size_type == TYPE_FLOAT) and is_finite(float(raw_size))
		if candidate != null:
			var raw: Variant = water_entry.get("source_rect", [0, 0, candidate.get_width(), candidate.get_height()])
			var valid: bool = raw is Array and raw.size() == 4
			if valid:
				for value in raw:
					var value_type := typeof(value)
					if (value_type != TYPE_INT and value_type != TYPE_FLOAT) or not is_finite(float(value)):
						valid = false
						break
			if valid and size_valid:
				var rect := Rect2(float(raw[0]), float(raw[1]), float(raw[2]), float(raw[3]))
				if rect.size.x > 0.0 and rect.size.y > 0.0 and Rect2(Vector2.ZERO, candidate.get_size()).encloses(rect):
					water_texture = candidate
					water_region = Vector4(rect.position.x / candidate.get_width(), rect.position.y / candidate.get_height(), rect.size.x / candidate.get_width(), rect.size.y / candidate.get_height())
					water_size = maxf(32.0, float(raw_size))
					water_enabled = true
	if _ground_shader == null:
		_ground_shader = Shader.new()
		_ground_shader.code = """
shader_type canvas_item;
render_mode unshaded;
uniform sampler2D earth_texture : source_color, filter_nearest, repeat_enable;
uniform sampler2D road_texture : source_color, filter_nearest, repeat_enable;
uniform sampler2D water_texture : source_color, filter_nearest, repeat_enable;
uniform sampler2D ground_mask : filter_linear, repeat_disable;
uniform vec4 earth_region;
uniform vec4 road_region;
uniform vec4 water_region;
uniform float earth_size = 512.0;
uniform float road_size = 512.0;
uniform float water_size = 512.0;
uniform float water_enabled = 0.0;
uniform float earth_contrast = 0.68;
uniform float road_contrast = 0.72;
uniform float paving_continuity = 0.0;
uniform vec2 chunk_origin;
uniform vec2 mask_size;
uniform vec4 region_tint : source_color = vec4(1.0);
varying vec2 ground_position;
void vertex() { ground_position = VERTEX + chunk_origin; }
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
	vec2 p = floor(ground_position) + vec2(0.5);
	vec4 earth = texture(earth_texture, earth_region.xy + fract(p / earth_size) * earth_region.zw);
	vec4 road = texture(road_texture, road_region.xy + fract(p / road_size) * road_region.zw);
	earth.rgb = mix(vec3(0.16, 0.145, 0.125), earth.rgb, earth_contrast);
	road.rgb = mix(vec3(0.16, 0.145, 0.125), road.rgb, road_contrast);
	vec4 mask = texture(ground_mask, ((p - chunk_origin) / 8.0 + vec2(1.0)) / mask_size);
	float wear = grain(p) - 0.5;
	// Break a corridor shoulder into worn bays instead of a straight decal edge.
	float shoulder_wear = grain(p * 0.21) - 0.5;
	float road_mix = smoothstep(0.08, 0.92, mask.r + wear * 0.30 + shoulder_wear * 0.55);
	// Worn paving is exposed in patches, not an uninterrupted carpet beneath props.
	float paving_patches = 0.35 + smoothstep(0.24, 0.72, grain(p * 0.18)) * 0.65;
	// Settled streets keep a readable spine; their shoulders still break into earth.
	road_mix *= mix(paving_patches, max(paving_patches, paving_continuity), smoothstep(0.64, 0.96, mask.r));
	road_mix *= 1.0 - mask.a * 0.66;
	vec3 surface = mix(earth.rgb, road.rgb, road_mix) * region_tint.rgb;
	surface *= 0.97 + grain(p * 0.11) * 0.06;
	float basin = smoothstep(0.48, 0.73, mask.g + wear * 0.10);
	float rim = smoothstep(0.22, 0.49, mask.g) * (1.0 - basin);
	float kind = floor(mask.b * 5.0 + 0.5);
	vec3 pool = vec3(0.085, 0.16, 0.13);
	if (kind > 1.5 && kind < 2.5) { pool = vec3(0.055, 0.05, 0.075); }
	if (kind > 2.5 && kind < 3.5) { pool = vec3(0.22, 0.115, 0.055); }
	if (kind > 3.5 && kind < 4.5) {
		// Dry yards expose scattered stone through the same earth. A solid basin
		// fill/rim makes their authored bounds look like a detached paving mat.
		float broken_edge = wear * 0.60 + (grain(p * 0.31) - 0.5) * 0.80;
		basin = smoothstep(0.40, 0.92, mask.g + broken_edge);
		basin *= smoothstep(0.38, 0.76, grain(p * 0.15)) * 0.42;
		rim = 0.0;
		pool = mix(earth.rgb, road.rgb, 0.24) * region_tint.rgb * 0.96;
	}
	if (kind > 4.5) { pool = vec3(0.055, 0.17, 0.19); }
	vec3 worn_stone = mix(earth.rgb, road.rgb, 0.55) * vec3(0.76, 0.75, 0.69);
	vec3 rim_color = worn_stone;
	float rim_strength = rim * 0.85;
	if (kind > 0.5 && kind < 1.5 && water_enabled > 0.5) {
		float silt_break = mix(0.62, 1.0, grain(p * 0.31));
		vec3 wet_silt = mix(earth.rgb, vec3(0.245, 0.235, 0.15), 0.38) * region_tint.rgb;
		rim_color = mix(worn_stone, wet_silt, 0.76);
		rim_strength *= silt_break;
		vec3 marsh_water = texture(water_texture, water_region.xy + fract(p / water_size) * water_region.zw).rgb;
		pool = mix(pool, marsh_water * region_tint.rgb, 0.72);
	}
	surface = mix(surface, rim_color, rim_strength);
	pool *= 0.85 + grain(p + vec2(173.0, 89.0)) * 0.30 + earth.r * 0.14;
	COLOR = vec4(mix(surface, pool, basin), 1.0);
}
"""
	_ground_material = ShaderMaterial.new()
	_ground_material.shader = _ground_shader
	_ground_material.set_shader_parameter("earth_texture", textures[0])
	_ground_material.set_shader_parameter("road_texture", textures[1])
	_ground_material.set_shader_parameter("water_texture", water_texture)
	_ground_material.set_shader_parameter("earth_region", regions[0])
	_ground_material.set_shader_parameter("road_region", regions[1])
	_ground_material.set_shader_parameter("water_region", water_region)
	_ground_material.set_shader_parameter("earth_size", scales[0])
	_ground_material.set_shader_parameter("road_size", scales[1])
	_ground_material.set_shader_parameter("water_size", water_size)
	_ground_material.set_shader_parameter("water_enabled", 1.0 if water_enabled else 0.0)
	var earth_contrast := 0.68
	var raw_contrast: Variant = region_config.get("earth_contrast", 0.68)
	if typeof(raw_contrast) == TYPE_INT or typeof(raw_contrast) == TYPE_FLOAT:
		if is_finite(float(raw_contrast)) and float(raw_contrast) >= 0.0 and float(raw_contrast) <= 1.0:
			earth_contrast = float(raw_contrast)
	_ground_material.set_shader_parameter("earth_contrast", earth_contrast)
	_ground_material.set_shader_parameter("road_contrast", minf(1.0, earth_contrast + 0.04))
	var continuity: Variant = region_config.get("paving_continuity", 0.0)
	if (typeof(continuity) == TYPE_INT or typeof(continuity) == TYPE_FLOAT) and is_finite(float(continuity)):
		_ground_material.set_shader_parameter("paving_continuity", clampf(float(continuity), 0.0, 1.0))
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
	_ground_material.set_shader_parameter("region_tint", tint)
	if mode in ["village", "guild"]:
		_load_hub_material_layout(manifest)
		return
	var route: Dictionary = DataRegistry.get_wasteland_route(route_id)
	var paths: Array = route.get("exploration_paths", [])
	var widths: Array = route.get("path_widths", [])
	var world_extent := Vector2(map_size) * tile_size
	for path_index in range(paths.size()):
		var path: Array = paths[path_index]
		var radius := (float(widths[path_index]) if path_index < widths.size() else 7.0) * tile_size * 0.5
		for index in range(1, path.size()):
			_material_roads.append({"a": Vector2(float(path[index - 1][0]), float(path[index - 1][1])) * world_extent, "b": Vector2(float(path[index][0]), float(path[index][1])) * world_extent, "radius": radius})
	for point: Dictionary in route.get("exploration_points", []):
		var position_array: Array = point.get("position", [0.5, 0.5])
		_material_roads.append({"center": Vector2(float(position_array[0]), float(position_array[1])) * world_extent, "radii": Vector2(7, 5) * tile_size})
	_material_mask_key = "%s:%s:%d:%d:0" % [route_id, map_size, tile_size, hash(_material_roads)]
	var area_file := FileAccess.open("res://data/art/world_v2.json", FileAccess.READ)
	if area_file == null:
		return
	var area_manifest: Variant = JSON.parse_string(area_file.get_as_text())
	if not area_manifest is Dictionary:
		return
	var kinds := {"water": 1, "chasm": 2, "furnace": 3, "rubble": 4, "coolant": 5}
	for area: Dictionary in area_manifest.get("routes", {}).get(route_id, {}).get("ground_areas", []):
		var values: Array = area.get("rect", [])
		if values.size() == 4:
			var bounds := Rect2(Vector2(float(values[0]), float(values[1])) * world_extent, Vector2(float(values[2]), float(values[3])) * world_extent)
			var area_data: Dictionary = {"rect": bounds, "kind": int(kinds.get(String(area.get("kind", "water")), 1))}
			var outline := parse_ground_outline(area.get("outline", null), world_extent, bounds)
			if not outline.is_empty():
				area_data["outline"] = outline
			_material_areas.append(area_data)
	var modules: Dictionary = area_manifest.get("modules", {})
	var composition: Dictionary = area_manifest.get("routes", {}).get(route_id, {})
	for placement: Dictionary in composition.get("placements", []):
		var raw_position: Array = placement.get("position", [0.5, 0.5])
		if raw_position.size() != 2:
			continue
		var anchor := Vector2(float(raw_position[0]), float(raw_position[1])) * world_extent
		var module: Dictionary = modules.get(String(placement.get("module", "")), {})
		for raw_footprint: Array in module.get("footprints", []):
			if raw_footprint.size() != 4:
				continue
			var footprint := Rect2(Vector2(float(raw_footprint[0]), float(raw_footprint[1])), Vector2(float(raw_footprint[2]), float(raw_footprint[3])))
			if footprint.size.x > 0.0 and footprint.size.y > 0.0:
				_material_architecture_feet.append(Rect2(anchor + footprint.position, footprint.size))
	_material_mask_key = "%s:%s:%d:%d:%d:%d" % [route_id, map_size, tile_size, hash(_material_roads), hash(_material_areas), hash(_material_architecture_feet)]


func has_material_ground() -> bool:
	return _ground_material != null


func get_map_road_segments() -> Array[Dictionary]:
	# The hub map reads the same placed roads as the ground, never a second layout.
	var segments: Array[Dictionary] = []
	for road: Dictionary in _material_roads:
		if road.has("a") and road.has("b"):
			segments.append({"a": road.a, "b": road.b, "width": float(road.radius) * 2.0})
	return segments


func _load_hub_material_layout(manifest: Dictionary) -> void:
	# Reuse the same world-space sampler/masks; hub lanes are presentation data.
	var layout: Dictionary = manifest.get("hubs", {}).get(mode, {})
	var continuity: Variant = layout.get("paving_continuity", 0.0)
	if (typeof(continuity) == TYPE_INT or typeof(continuity) == TYPE_FLOAT) and is_finite(float(continuity)):
		_ground_material.set_shader_parameter("paving_continuity", clampf(float(continuity), 0.0, 1.0))
	for lane: Dictionary in layout.get("lanes", []):
		var points: Array = lane.get("points", [])
		var radius := maxf(8.0, float(lane.get("width", 96.0)) * 0.5)
		for index in range(1, points.size()):
			var a: Array = points[index - 1]
			var b: Array = points[index]
			if a.size() == 2 and b.size() == 2:
				_material_roads.append({"a": Vector2(float(a[0]), float(a[1])), "b": Vector2(float(b[0]), float(b[1])), "radius": radius})
	for plaza: Dictionary in layout.get("plazas", []):
		var center: Array = plaza.get("center", [])
		var radii: Array = plaza.get("radii", [])
		if center.size() == 2 and radii.size() == 2:
			_material_roads.append({"center": Vector2(float(center[0]), float(center[1])), "radii": Vector2(maxf(8.0, float(radii[0])), maxf(8.0, float(radii[1])))})
	_material_mask_key = "%s:%s:%d:%d" % [mode, map_size, tile_size, hash(_material_roads)]


func _make_ground_mask(origin: Vector2, extent: Vector2) -> ImageTexture:
	# One eight-world-pixel mask per chunk, with shared-coordinate padding on all edges.
	var cache_key := "%s:%s:%s" % [_material_mask_key, origin, extent]
	if _ground_mask_cache.has(cache_key):
		return _ground_mask_cache[cache_key] as ImageTexture
	var size := Vector2i(ceili(extent.x / MATERIAL_MASK_STEP) + 2, ceili(extent.y / MATERIAL_MASK_STEP) + 2)
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var chunk_bounds := Rect2(origin, extent).grow(MATERIAL_MASK_STEP)
	var roads: Array[Dictionary] = []
	var areas: Array[Dictionary] = []
	var architecture_feet: Array[Rect2] = []
	for path: Dictionary in _material_roads:
		var bounds: Rect2
		if path.has("center"):
			bounds = Rect2(path.center - path.radii, path.radii * 2.0)
		else:
			bounds = Rect2(path.a, Vector2.ZERO).expand(path.b).grow(float(path.radius))
		if bounds.grow(32.0).intersects(chunk_bounds):
			roads.append(path)
	for area: Dictionary in _material_areas:
		var area_rect: Rect2 = area.rect
		if area_rect.grow(16.0).intersects(chunk_bounds):
			areas.append(area)
	for foot: Rect2 in _material_architecture_feet:
		if foot.grow(24.0).intersects(chunk_bounds):
			architecture_feet.append(foot)
	for y in range(size.y):
		for x in range(size.x):
			var p := origin + (Vector2(x, y) - Vector2(0.5, 0.5)) * MATERIAL_MASK_STEP
			var road := 0.0
			for path: Dictionary in roads:
				var depth: float
				if path.has("center"):
					depth = (1.0 - ((p - path.center) / path.radii).length()) * minf(path.radii.x, path.radii.y)
				else:
					depth = float(path.radius) - p.distance_to(Geometry2D.get_closest_point_to_segment(p, path.a, path.b))
				road = maxf(road, clampf(0.5 + depth / 48.0, 0.0, 1.0))
			var basin := 0.0
			var kind := 0.0
			for area: Dictionary in areas:
				var rect: Rect2 = area.rect
				if not rect.grow(16.0).has_point(p):
					continue
				var depth: float
				if area.has("outline"):
					depth = _ground_outline_depth(area.outline, p)
				else:
					# Keep the legacy rounded-rectangle field for entries without a valid outline.
					var q := (p - rect.get_center()).abs() - rect.size * 0.5 + Vector2(12, 12)
					depth = 12.0 - q.max(Vector2.ZERO).length() - minf(maxf(q.x, q.y), 0.0)
				var value := clampf(0.45 + depth / 48.0, 0.0, 1.0)
				if value > basin:
					basin = value
					kind = float(area.kind) / 5.0
			var apron := 0.0
			for foot: Rect2 in architecture_feet:
				if not foot.grow(24.0).has_point(p):
					continue
				# Fade road coverage into the earth material at the foot perimeter.
				var outside := ((p - foot.get_center()).abs() - foot.size * 0.5).max(Vector2.ZERO).length()
				var edge_variation := sin((p.x + p.y * 0.37) * 0.075) * 2.0 + sin((p.y - p.x * 0.41) * 0.11) * 2.0
				var shoulder_width := clampf(20.0 + edge_variation, 16.0, 24.0)
				apron = maxf(apron, 1.0 - smoothstep(0.0, shoulder_width, outside))
			image.set_pixel(x, y, Color(road, basin, kind, apron))
	var texture := ImageTexture.create_from_image(image)
	_ground_mask_cache[cache_key] = texture
	return texture


func _ground_outline_depth(outline: PackedVector2Array, point: Vector2) -> float:
	var edge_distance := INF
	for index in range(outline.size()):
		var closest := Geometry2D.get_closest_point_to_segment(point, outline[index], outline[(index + 1) % outline.size()])
		edge_distance = minf(edge_distance, point.distance_to(closest))
	return edge_distance if Geometry2D.is_point_in_polygon(point, outline) else -edge_distance


func register_ground_contacts(contacts: Array[Rect2]) -> void:
	if _ground_material == null or contacts.is_empty():
		return
	# Once after scene population: actual placed feet wear into the same ground.
	_material_architecture_feet.append_array(contacts)
	_material_mask_key += ":props:%d" % hash(contacts)
	for chunk: Node2D in _chunks:
		var extent := Vector2(chunk.tile_end - chunk.tile_start) * tile_size
		var bounds := Rect2(chunk.position, extent)
		var affected := false
		for foot: Rect2 in contacts:
			if foot.grow(24.0).intersects(bounds):
				affected = true
				break
		if not affected:
			continue
		var mask := _make_ground_mask(chunk.position, extent)
		chunk.material.set_shader_parameter("ground_mask", mask)
		chunk.material.set_shader_parameter("mask_size", Vector2(mask.get_width(), mask.get_height()))


func _get_wasteland_surface_texture(biome: String) -> Texture2D:
	if _wasteland_surface_cache.has(biome):
		return _wasteland_surface_cache[biome] as Texture2D
	var image := Image.create(WASTELAND_SURFACE_SIZE, WASTELAND_SURFACE_SIZE, false, Image.FORMAT_RGBA8)
	var broad_noise := FastNoiseLite.new()
	broad_noise.seed = absi(biome.hash()) + 1201
	broad_noise.frequency = 0.075
	var grain_noise := FastNoiseLite.new()
	grain_noise.seed = absi(biome.hash()) + 9413
	grain_noise.frequency = 0.42
	for y in range(WASTELAND_SURFACE_SIZE):
		for x in range(WASTELAND_SURFACE_SIZE):
			var value := clampf(0.94 + broad_noise.get_noise_2d(x, y) * 0.10 + grain_noise.get_noise_2d(x, y) * 0.035, 0.78, 1.12)
			image.set_pixel(x, y, Color(value, value, value, 1.0))
	var texture := ImageTexture.create_from_image(image)
	_wasteland_surface_cache[biome] = texture
	return texture


func _rebuild_chunks() -> void:
	for chunk in _chunks:
		if is_instance_valid(chunk):
			remove_child(chunk)
			chunk.queue_free()
	_chunks.clear()
	if map_size.x <= 0 or map_size.y <= 0:
		_tile_rng_states.clear()
		return
	if _ground_material == null:
		_build_tile_rng_states()
	for y in range(0, map_size.y, CHUNK_TILE_SIZE):
		for x in range(0, map_size.x, CHUNK_TILE_SIZE):
			var chunk := DrawChunk.new()
			chunk.backdrop = self
			chunk.tile_start = Vector2i(x, y)
			chunk.tile_end = Vector2i(mini(x + CHUNK_TILE_SIZE, map_size.x), mini(y + CHUNK_TILE_SIZE, map_size.y))
			chunk.position = Vector2(x * tile_size, y * tile_size)
			if _ground_material != null:
				var extent := Vector2(chunk.tile_end - chunk.tile_start) * tile_size
				var mask := _make_ground_mask(chunk.position, extent)
				var chunk_material := _ground_material.duplicate() as ShaderMaterial
				chunk_material.set_shader_parameter("chunk_origin", chunk.position)
				chunk_material.set_shader_parameter("ground_mask", mask)
				chunk_material.set_shader_parameter("mask_size", Vector2(mask.get_width(), mask.get_height()))
				chunk.material = chunk_material
			chunk.name = "BackdropChunk_%d_%d" % [x, y]
			add_child(chunk)
			_chunks.append(chunk)
			chunk.queue_redraw()


func _build_tile_rng_states() -> void:
	_tile_rng_states.resize(map_size.x * map_size.y)
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed
	for y in range(map_size.y):
		for x in range(map_size.x):
			_tile_rng_states[y * map_size.x + x] = rng.state
			_draw_tile(null, rng, x, y, Vector2i.ZERO)


func _draw_chunk(target: CanvasItem, tile_start: Vector2i, tile_end: Vector2i) -> void:
	if _ground_material != null:
		# One ordered opaque surface: legacy queued kerbs and basin rectangles cannot cover it.
		target.draw_rect(Rect2(Vector2.ZERO, Vector2(tile_end - tile_start) * tile_size), Color.WHITE)
		return
	if _tile_rng_states.size() != map_size.x * map_size.y:
		return
	_batch_rects.clear()
	_batch_lines.clear()
	_batch_circles.clear()
	var rng := RandomNumberGenerator.new()
	for y in range(tile_start.y, tile_end.y):
		for x in range(tile_start.x, tile_end.x):
			rng.state = _tile_rng_states[y * map_size.x + x]
			_draw_tile(target, rng, x, y, tile_start)
	
	# Batch flush: draw rects, lines, circles in grouped streams to optimize 2D canvas draw calls
	for item in _batch_rects:
		target.draw_rect(item[0], item[1], item[2])
	for item in _batch_lines:
		target.draw_line(item[0], item[1], item[2], item[3])
	for item in _batch_circles:
		target.draw_circle(item[0], item[1], item[2])
	_batch_rects.clear()
	_batch_lines.clear()
	_batch_circles.clear()


func _draw_tile(target: CanvasItem, rng: RandomNumberGenerator, x: int, y: int, tile_origin: Vector2i) -> void:
	var road_strength := _road_strength(x, y)
	var base := _base_color()
	var alt := _alt_color()
	var stain := _stain_color()
	var accent := _accent_color()
	var rect := Rect2(Vector2((x - tile_origin.x) * tile_size, (y - tile_origin.y) * tile_size), Vector2(tile_size, tile_size))
	var c := _wasteland_surface_color(road_strength, x, y) if mode == "wasteland" else base.lerp(alt, rng.randf_range(0.0, 0.42))
	if mode == "village":
		c = c.lerp(_village_patch_color(x, y), _village_patch_strength(x, y))
	if mode != "wasteland" and road_strength > 0.0:
		c = c.lerp(_road_color(), road_strength)
	var texture := _texture_for_tile(x, y, road_strength)
	if texture != null:
		_draw_texture_variant(target, texture, rect, x, y, road_strength, c if mode == "wasteland" else Color.WHITE)
		if mode != "wasteland":
			var tint_alpha := 0.08 + road_strength * 0.06
			if mode == "village":
				tint_alpha = 0.09 + road_strength * 0.05
			_draw_rect(target, rect, Color(c.r, c.g, c.b, tint_alpha))
	else:
		_draw_rect(target, rect, c)
	if road_strength > 0.0:
		_draw_road_detail(target, rect, x, y, road_strength, rng)
	if mode == "village":
		_draw_village_organic_detail(target, rect, x, y, road_strength, rng)
	if mode == "wasteland":
		_draw_biome_signature_detail(target, rect, x, y, road_strength, accent, stain, rng)
		_draw_authored_road_edges(target, rect, x, y)
		_draw_authored_ground_detail(target, rect, x, y)


func _draw_authored_road_edges(target: CanvasItem, rect: Rect2, x: int, y: int) -> void:
	if target == null or _authored_road_tiles.size() != map_size.x * map_size.y:
		return
	var tile_index := y * map_size.x + x
	var road := _authored_road_tiles[tile_index]
	var hash_value := absi(x * 374761 + y * 668265 + world_seed)
	hash_value = absi(hash_value ^ (hash_value >> 13) ^ (x * y * 224682251))
	if road == 1:
		for index in range(3):
			var chip := Vector2(3 + (hash_value / (index + 1)) % 25, 4 + (hash_value / (index + 3)) % 23)
			_draw_rect(target, Rect2(rect.position + chip, Vector2(3 + index, 2)), Color8(118, 108, 83, 165))
		return
	if road < 2:
		return
	var horizontal := _authored_road_directions[tile_index] == 1
	if route_id == "toxic_marsh":
		for plank in [7, 17, 27]:
			var plank_rect := Rect2(rect.position + Vector2(plank, 1), Vector2(5, 30)) if horizontal else Rect2(rect.position + Vector2(1, plank), Vector2(30, 5))
			_draw_rect(target, plank_rect, Color8(112, 106, 76, 220))
		if (x + y) % 3 == 0:
			_draw_rect(target, Rect2(rect.position + Vector2(3, 3), Vector2(3, 3)), Color8(152, 150, 115))
	elif route_id == "scrap_highway":
		if absf(_authored_road_offsets[tile_index] - 2.5) < 0.6:
			var track := Rect2(rect.position + Vector2(0, 9), Vector2(32, 7)) if horizontal else Rect2(rect.position + Vector2(9, 0), Vector2(7, 32))
			_draw_rect(target, track, Color8(22, 23, 23, 74))
		if hash_value % 19 == 0:
			var sign_y := -1.0 if hash_value % 2 == 0 else 1.0
			var start := Vector2(3 + hash_value % 6, 9 + (hash_value >> 4) % 14)
			var bend := start + Vector2(8 + (hash_value >> 6) % 8, sign_y * float(2 + (hash_value >> 8) % 5))
			var end := bend + Vector2(5 + (hash_value >> 10) % 8, sign_y * (-3.0 if hash_value % 3 == 0 else 2.0))
			if hash_value % 4 == 0:
				start = Vector2(start.y, start.x)
				bend = Vector2(bend.y, bend.x)
				end = Vector2(end.y, end.x)
			_draw_line(target, rect.position + start, rect.position + bend, Color8(19, 20, 20, 175), 1.5)
			_draw_line(target, rect.position + bend, rect.position + end, Color8(19, 20, 20, 175), 1.5)
			if hash_value % 3 == 0:
				_draw_line(target, rect.position + bend, rect.position + bend + Vector2(-4, 7), Color8(19, 20, 20, 145), 1.0)
	var edge_color := Color8(120, 114, 97)
	if route_id == "toxic_marsh":
		edge_color = Color8(160, 145, 98)
	elif route_id == "crystal_scar":
		edge_color = Color8(129, 112, 143)
	elif route_id == "underground_facility":
		edge_color = Color8(95, 142, 147)
	for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var neighbor := Vector2i(x, y) + offset
		if neighbor.x < 0 or neighbor.y < 0 or neighbor.x >= map_size.x or neighbor.y >= map_size.y:
			continue
		if _authored_road_tiles[neighbor.y * map_size.x + neighbor.x] >= 2:
			continue
		var edge := Rect2(rect.position + Vector2(0 if offset.x <= 0 else 27, 0 if offset.y <= 0 else 27), Vector2(32 if offset.y != 0 else 5, 32 if offset.x != 0 else 5))
		_draw_rect(target, edge.grow(2.0), Color8(25, 26, 24, 200))
		_draw_rect(target, edge, edge_color.darkened(0.16 if hash_value % 4 == 0 else 0.0))


func _draw_authored_ground_detail(target: CanvasItem, rect: Rect2, x: int, y: int) -> void:
	if target == null or _authored_ground_tiles.size() != map_size.x * map_size.y:
		return
	var kind := _authored_ground_tiles[y * map_size.x + x]
	if kind == 0:
		return
	var rim := Color8(88, 102, 91)
	if kind == 2:
		rim = Color8(91, 78, 107)
	elif kind == 3:
		rim = Color8(190, 103, 39)
	elif kind == 5:
		rim = Color8(49, 141, 158)
	for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var neighbor := Vector2i(x, y) + offset
		if neighbor.x < 0 or neighbor.y < 0 or neighbor.x >= map_size.x or neighbor.y >= map_size.y:
			continue
		if _authored_ground_tiles[neighbor.y * map_size.x + neighbor.x] == kind:
			continue
		var edge := Rect2(rect.position + Vector2(0 if offset.x <= 0 else 27, 0 if offset.y <= 0 else 27), Vector2(32 if offset.y != 0 else 5, 32 if offset.x != 0 else 5))
		_draw_rect(target, edge, rim)
	if kind in [1, 5] and (x * 3 + y) % 6 == 0:
		_draw_line(target, rect.position + Vector2(6, 16), rect.position + Vector2(23, 16), Color(rim, 0.32), 2.0)
	elif kind == 2 and x % 3 == 0:
		_draw_line(target, rect.position + Vector2(16, 0), rect.position + Vector2(16, 32), Color8(35, 30, 42), 3.0)
	elif kind == 3 and (x + y) % 4 == 0:
		_draw_rect(target, Rect2(rect.position + Vector2(8, 8), Vector2(18, 3)), Color8(225, 127, 42, 140))


func _draw_biome_signature_detail(target: CanvasItem, rect: Rect2, x: int, y: int, road_strength: float, accent: Color, stain: Color, rng: RandomNumberGenerator) -> void:
	if target == null:
		return
	var roll_a := rng.randf()
	var roll_b := rng.randf()
	match route_id:
		"scrap_highway":
			var tile_index := y * map_size.x + x
			var road_mark := _authored_road_tiles[tile_index]
			var horizontal := _authored_road_directions[tile_index] == 1
			if road_mark == 3 and (x if horizontal else y) % 7 < 3:
				var marking := Rect2(rect.position + Vector2(0, 14), Vector2(32, 3)) if horizontal else Rect2(rect.position + Vector2(14, 0), Vector2(3, 32))
				_draw_rect(target, marking, Color8(175, 147, 86, 170), true)
			if roll_b < 0.025:
				_draw_line(target, rect.position + Vector2(7, 20), rect.position + Vector2(19, 16), Color(0.14, 0.13, 0.12, 0.28), 1.0)
		"toxic_marsh":
			if road_strength > 0.3:
				var causeway: bool = abs(x - int(map_size.x * 0.46) - int(sin(float(y) * 0.10) * 5.0)) <= 2
				if (causeway and x % 4 == 0) or (not causeway and y % 4 == 0):
					_draw_line(target, rect.position + Vector2(3, 29), rect.position + Vector2(29, 29), Color(0.42, 0.45, 0.39, 0.34), 1.0)
			elif roll_a < 0.035:
				var puddle := rect.position + Vector2(rng.randf_range(7, 25), rng.randf_range(7, 25))
				_draw_circle(target, puddle, 3.0 + roll_b * 4.0, Color(0.12, 0.23, 0.15, 0.42))
				if roll_b < 0.42:
					_draw_circle(target, puddle + Vector2(1, -1), 1.2, Color(0.43, 0.55, 0.31, 0.40))
		"crystal_scar":
			if roll_a < 0.045:
				var p1 := rect.position + Vector2(rng.randf_range(4, 11), rng.randf_range(10, 27))
				var p2 := p1 + Vector2(rng.randf_range(5, 11), rng.randf_range(-7, -1))
				var p3 := p2 + Vector2(rng.randf_range(5, 10), rng.randf_range(-4, 4))
				_draw_line(target, p1, p2, Color(0.48, 0.35, 0.57, 0.50), 1.0)
				_draw_line(target, p2, p3, Color(0.46, 0.55, 0.58, 0.38), 1.0)
			elif roll_b < 0.018:
				_draw_circle(target, rect.position + Vector2(rng.randf_range(8, 24), rng.randf_range(8, 24)), 1.5, Color(0.62, 0.51, 0.68, 0.42))
		"old_factory":
			if road_strength > 0.4 and (x % 8 == 0 or y % 8 == 0):
				_draw_line(target, rect.position + Vector2(5, 29), rect.position + Vector2(27, 29), Color(0.31, 0.33, 0.34, 0.40), 1.0)
			if road_strength > 0.4 and (x + y) % 13 == 0:
				_draw_rect(target, Rect2(rect.position.x + 8, rect.position.y + 26, 8, 2), Color(0.67, 0.51, 0.29, 0.48), true)
			elif roll_a < 0.018:
				_draw_rect(target, Rect2(rect.position.x + 8, rect.position.y + 15, 16, 1.5), Color(0.63, 0.35, 0.22, 0.42), true)
		"ruined_metropolis":
			if road_strength > 0.4 and (x % 28 == 12 or y % 24 == 10) and (x + y) % 4 < 2:
				_draw_rect(target, Rect2(rect.position.x + 6, rect.position.y + 15, 12, 1.3), Color(0.58, 0.57, 0.54, 0.40), true)
			elif roll_a < 0.035:
				var start := rect.position + Vector2(rng.randf_range(5, 12), rng.randf_range(8, 22))
				_draw_line(target, start, start + Vector2(rng.randf_range(7, 14), rng.randf_range(-4, 4)), Color(0.24, 0.24, 0.25, 0.46), 1.0)
		"underground_facility":
			if road_strength > 0.35 and (x % 5 == 0 or y % 5 == 0):
				var conduit := Color(0.25, 0.47, 0.50, 0.42)
				if y % 5 == 0:
					_draw_line(target, rect.position + Vector2(3, 16), rect.position + Vector2(29, 16), conduit, 1.2)
				else:
					_draw_line(target, rect.position + Vector2(16, 3), rect.position + Vector2(16, 29), conduit, 1.2)
			if roll_a < 0.018:
				_draw_circle(target, rect.position + Vector2(16, 16), 2.0, Color(0.38, 0.61, 0.61, 0.42))
		_:
			if roll_a < 0.03:
				_draw_circle(target, rect.position + Vector2(16, 16), 2.0, Color(accent.r, accent.g, accent.b, 0.25))


func _draw_road_detail(target: CanvasItem, rect: Rect2, x: int, y: int, road_strength: float, rng: RandomNumberGenerator) -> void:
	if mode == "wasteland":
		if rng.randf() < 0.07:
			var scuff := rect.position + Vector2(rng.randf_range(5, 27), rng.randf_range(5, 27))
			_draw_circle(target, scuff, rng.randf_range(1.0, 2.2), Color(0.27, 0.27, 0.26, 0.22))
		if rng.randf() < 0.05:
			var start := rect.position + Vector2(rng.randf_range(4, 12), rng.randf_range(8, 24))
			_draw_line(target, start, start + Vector2(rng.randf_range(8, 15), rng.randf_range(-3, 3)), Color(0.18, 0.18, 0.17, 0.22), 1.0)
		return
	var edge := _road_edge_color()
	_draw_rect(target, rect, Color(0.10, 0.09, 0.08, 0.12 + road_strength * 0.16), true)
	if rng.randf() < 0.12:
		_draw_circle(target, rect.position + Vector2(rng.randf_range(5, 27), rng.randf_range(5, 27)), rng.randf_range(1.0, 2.4), Color(edge.r, edge.g, edge.b, 0.08))
	if rng.randf() < 0.22:
		var start := rect.position + Vector2(rng.randf_range(4, 12), rng.randf_range(7, 23))
		var end := start + Vector2(rng.randf_range(9, 24), rng.randf_range(-6, 8))
		_draw_line(target, start, end, Color(0.13, 0.11, 0.08, 0.28), 1.0)


func _draw_village_organic_detail(target: CanvasItem, rect: Rect2, x: int, y: int, road_strength: float, rng: RandomNumberGenerator) -> void:
	if road_strength <= 0.0:
		if rng.randf() < 0.10:
			_draw_circle(target, rect.position + Vector2(rng.randf_range(5, 27), rng.randf_range(5, 27)), rng.randf_range(2.0, 5.0), Color(0.20, 0.37, 0.17, 0.32))
		if rng.randf() < 0.06:
			_draw_line(target, rect.position + Vector2(rng.randf_range(4, 10), rng.randf_range(8, 24)), rect.position + Vector2(rng.randf_range(18, 29), rng.randf_range(6, 26)), Color(0.09, 0.16, 0.08, 0.26), 1.0)
		return
	if rng.randf() < 0.18:
		_draw_circle(target, rect.position + Vector2(rng.randf_range(5, 27), rng.randf_range(5, 27)), rng.randf_range(1.2, 3.0), Color(0.78, 0.61, 0.34, 0.18 + road_strength * 0.10))
	if rng.randf() < 0.24:
		var start := rect.position + Vector2(rng.randf_range(3, 12), rng.randf_range(7, 25))
		var end := start + Vector2(rng.randf_range(9, 24), rng.randf_range(-7, 7))
		_draw_line(target, start, end, Color(0.34, 0.24, 0.13, 0.28), 1.0)

func _road_strength(x: int, y: int) -> float:
	if mode == "wasteland" and _authored_road_tiles.size() == map_size.x * map_size.y and _authored_road_tiles[y * map_size.x + x] > 0:
		return 0.28 if _authored_road_tiles[y * map_size.x + x] == 1 else 0.94
	if mode == "village":
		var cx := float(map_size.x) * 0.5
		var cy := float(map_size.y) * 0.5
		var plaza_shape := pow((float(x) - cx) / 10.5, 2.0) + pow((float(y) - cy) / 6.5, 2.0)
		var plaza: bool = plaza_shape <= 1.0
		var vertical_center := cx + sin(float(y) * 0.22) * 1.4
		var horizontal_center := cy + sin(float(x) * 0.18) * 1.2
		var vertical: bool = abs(float(x) - vertical_center) <= 2.2 and y >= 4 and y <= map_size.y - 2
		var horizontal: bool = abs(float(y) - horizontal_center) <= 2.2 and x >= 3 and x <= map_size.x - 2
		var shoulder: bool = plaza_shape <= 1.42 or abs(float(x) - vertical_center) <= 3.4 or abs(float(y) - horizontal_center) <= 3.4
		return 0.78 if plaza or vertical or horizontal else (0.22 if shoulder else 0.0)
	if mode == "guild":
		var hall: bool = x >= 8 and x <= 42 and y >= 6 and y <= 23
		var cross: bool = (x >= 23 and x <= 27) or (y >= 14 and y <= 17)
		return 0.65 if hall and cross else 0.0
	if mode == "wasteland":
		if _has_authored_paths:
			return 0.0
		if route_id == "scrap_highway":
			var highway: bool = abs(y - int(map_size.y * 0.55) - int(sin(float(x) * 0.08) * 3.0)) <= 3
			var north_south_spur: bool = abs(x - int(map_size.x * 0.50)) <= 2 and y >= int(map_size.y * 0.52)
			var shoulder: bool = abs(y - int(map_size.y * 0.55)) <= 7 and x % 9 == 0
			return 0.66 if (highway or north_south_spur) else (0.24 if shoulder else 0.0)
		if route_id == "old_factory":
			var grid_x: bool = abs(x - int(map_size.x * 0.52)) <= 2 or abs(x - int(map_size.x * 0.28)) <= 1 or abs(x - int(map_size.x * 0.74)) <= 1
			var grid_y: bool = abs(y - int(map_size.y * 0.50)) <= 2 or abs(y - int(map_size.y * 0.28)) <= 1
			return 0.60 if grid_x or grid_y else 0.0
		if route_id == "toxic_marsh":
			var causeway: bool = abs(x - int(map_size.x * 0.46) - int(sin(float(y) * 0.10) * 5.0)) <= 2
			var cross_bridge: bool = abs(y - int(map_size.y * 0.48)) <= 1 and x >= int(map_size.x * 0.22) and x <= int(map_size.x * 0.78)
			return 0.54 if (causeway or cross_bridge) else 0.0
		if route_id == "ruined_metropolis":
			var ave_x: bool = (x % 28 >= 12 and x % 28 <= 15)
			var ave_y: bool = (y % 24 >= 10 and y % 24 <= 13)
			var arrival_spine: bool = abs(float(x) - map_size.x * 0.5) <= 2.2 and y >= int(map_size.y * 0.46)
			var archive_approach: bool = abs(float(y) - map_size.y * 0.50) <= 2.2 and x >= map_size.x * 0.30 and x <= map_size.x * 0.70
			return 0.62 if (ave_x or ave_y or arrival_spine or archive_approach) else 0.0
		if route_id == "underground_facility":
			var ring_dist := Vector2(float(x) - map_size.x * 0.5, float(y) - map_size.y * 0.46).length()
			var ring: bool = abs(ring_dist - 24.0) <= 2.0
			var spine: bool = abs(x - int(map_size.x * 0.5)) <= 2 or abs(y - int(map_size.y * 0.46)) <= 2
			return 0.64 if (ring or spine) else 0.0
		var crystal_path: bool = abs(y - int(map_size.y * 0.68) - int(sin(float(x) * 0.18) * 6.0)) <= 2
		var branch: bool = abs(x - int(map_size.x * 0.5) - int(sin(float(y) * 0.11) * 4.0)) <= 2 and y > map_size.y * 0.22
		return 0.50 if crystal_path or branch else 0.0
	return 0.0

func _village_patch_color(x: int, y: int) -> Color:
	var wave := sin(float(x) * 0.17 + float(y) * 0.09)
	if wave > 0.42:
		return Color8(128, 97, 54)
	if wave < -0.38:
		return Color8(53, 93, 48)
	return Color8(78, 65, 43)

func _village_patch_strength(x: int, y: int) -> float:
	var wave := sin(float(x) * 0.13 - float(y) * 0.19) + sin(float(x) * 0.035 + float(y) * 0.051)
	return clampf(0.08 + wave * 0.08, 0.0, 0.24)

func _wasteland_zone_color(x: int, y: int) -> Color:
	var px: float = float(x) / max(1.0, float(map_size.x))
	var py: float = float(y) / max(1.0, float(map_size.y))
	if route_id == "toxic_marsh":
		return Color8(28, 94, 48)
	if route_id == "old_factory":
		return Color8(62, 54, 46)
	if route_id == "scrap_highway":
		return Color8(88, 72, 52)
	if route_id == "ruined_metropolis":
		return Color8(58, 56, 64)
	if route_id == "underground_facility":
		return Color8(28, 52, 68)
	if py < 0.27 and px > 0.36 and px < 0.68:
		return Color8(78, 38, 102)
	if px < 0.38 and py > 0.22 and py < 0.56:
		return Color8(75, 74, 70)
	if px > 0.60 and py > 0.24 and py < 0.62:
		return Color8(34, 82, 52)
	return Color8(48, 36, 64)

func _wasteland_zone_strength(x: int, y: int) -> float:
	if route_id in ["toxic_marsh", "old_factory", "scrap_highway", "ruined_metropolis", "underground_facility"]:
		return 0.40
	var px: float = float(x) / max(1.0, float(map_size.x))
	var py: float = float(y) / max(1.0, float(map_size.y))
	if py < 0.27 and px > 0.36 and px < 0.68:
		return 0.42
	if px < 0.38 and py > 0.22 and py < 0.56:
		return 0.30
	if px > 0.60 and py > 0.24 and py < 0.62:
		return 0.42
	return 0.28

func _route_noise_color(x: int, y: int) -> Color:
	var px: float = float(x) / max(1.0, float(map_size.x))
	var py: float = float(y) / max(1.0, float(map_size.y))
	match route_id:
		"scrap_highway":
			if py > 0.36 and py < 0.70:
				return Color8(146, 108, 60)
			return Color8(84, 62, 42)
		"toxic_marsh":
			if px < 0.52 or (x + y) % 7 < 3:
				return Color8(34, 118, 56)
			return Color8(86, 82, 48)
		"crystal_scar":
			if py < 0.46 or abs(px - 0.52) < 0.14:
				return Color8(102, 48, 138)
			return Color8(68, 58, 86)
		"old_factory":
			if px > 0.42 and py < 0.70:
				return Color8(58, 76, 88)
			return Color8(116, 74, 44)
		"ruined_metropolis":
			if (x / 14 + y / 12) % 2 == 0:
				return Color8(74, 70, 78)
			return Color8(92, 68, 54)
		"underground_facility":
			if abs(px - 0.5) < 0.25 and abs(py - 0.46) < 0.25:
				return Color8(32, 92, 116)
			return Color8(42, 54, 68)
	return Color8(64, 55, 42)

func _route_noise_strength(x: int, y: int) -> float:
	if mode != "wasteland":
		return 0.0
	var wave := sin(float(x) * 0.11 + float(y) * 0.07)
	var broad := sin(float(x) * 0.025 - float(y) * 0.031)
	return clampf(0.14 + wave * 0.08 + broad * 0.11, 0.0, 0.36)

func _wasteland_surface_color(road_strength: float, x := 0, y := 0) -> Color:
	if _authored_ground_tiles.size() == map_size.x * map_size.y:
		match _authored_ground_tiles[y * map_size.x + x]:
			1: return Color8(24, 43, 39)
			2: return Color8(15, 17, 25)
			3: return Color8(49, 26, 19)
			4: return Color8(78, 73, 70)
			5: return Color8(13, 40, 52)
	var ground := Color8(74, 68, 59)
	var path := Color8(60, 61, 61)
	match route_id:
		"scrap_highway":
			ground = Color8(76, 69, 57)
			path = Color8(43, 44, 43)
		"toxic_marsh":
			ground = Color8(43, 51, 39)
			path = Color8(91, 85, 66)
		"crystal_scar":
			ground = Color8(46, 42, 51)
			path = Color8(79, 68, 84)
		"old_factory":
			ground = Color8(50, 53, 52)
			path = Color8(87, 79, 61)
		"ruined_metropolis":
			ground = Color8(66, 64, 60)
			path = Color8(40, 43, 45)
		"underground_facility":
			ground = Color8(39, 47, 50)
			path = Color8(64, 75, 72)
	return ground.lerp(path, clampf(road_strength, 0.0, 0.88))


func _road_color() -> Color:
	match route_id:
		"scrap_highway":
			return Color8(58, 54, 52)
		"toxic_marsh":
			return Color8(48, 60, 50)
		"crystal_scar":
			return Color8(54, 40, 76)
		"old_factory":
			return Color8(56, 60, 68)
		"ruined_metropolis":
			return Color8(66, 66, 72)
		"underground_facility":
			return Color8(46, 68, 82)
	if mode == "village":
		return Color8(178, 128, 67)
	return Color8(94, 82, 62)

func _road_edge_color() -> Color:
	match route_id:
		"scrap_highway":
			return Color8(228, 178, 82)
		"toxic_marsh":
			return Color8(118, 224, 68)
		"crystal_scar":
			return Color8(218, 108, 255)
		"old_factory":
			return Color8(238, 172, 34)
		"ruined_metropolis":
			return Color8(188, 182, 168)
		"underground_facility":
			return Color8(72, 224, 246)
	return Color8(199, 159, 94)

func _stain_color() -> Color:
	match route_id:
		"scrap_highway":
			return Color8(132, 76, 38)
		"toxic_marsh":
			return Color8(36, 142, 58)
		"crystal_scar":
			return Color8(112, 46, 156)
		"old_factory":
			return Color8(44, 92, 102)
		"ruined_metropolis":
			return Color8(96, 64, 52)
		"underground_facility":
			return Color8(36, 124, 148)
	return Color8(42, 97, 67)

func _accent_color() -> Color:
	match route_id:
		"scrap_highway":
			return Color8(228, 148, 58)
		"toxic_marsh":
			return Color8(112, 244, 78)
		"crystal_scar":
			return Color8(206, 96, 255)
		"old_factory":
			return Color8(255, 124, 54)
		"ruined_metropolis":
			return Color8(232, 168, 92)
		"underground_facility":
			return Color8(76, 236, 255)
	return Color8(118, 180, 96)

func _base_color() -> Color:
	if mode == "village":
		return Color8(74, 69, 45)
	if route_id == "toxic_marsh":
		return Color8(28, 48, 26)
	if route_id == "old_factory":
		return Color8(46, 48, 54)
	if route_id == "crystal_scar":
		return Color8(36, 26, 52)
	if route_id == "scrap_highway":
		return Color8(78, 62, 44)
	if route_id == "ruined_metropolis":
		return Color8(38, 36, 40)
	if route_id == "underground_facility":
		return Color8(20, 28, 36)
	return Color8(34, 31, 28)

func _alt_color() -> Color:
	if mode == "village":
		return Color8(139, 104, 58)
	if route_id == "toxic_marsh":
		return Color8(56, 110, 42)
	if route_id == "old_factory":
		return Color8(78, 82, 94)
	if route_id == "crystal_scar":
		return Color8(82, 48, 118)
	if route_id == "scrap_highway":
		return Color8(124, 98, 68)
	if route_id == "ruined_metropolis":
		return Color8(72, 68, 74)
	if route_id == "underground_facility":
		return Color8(42, 64, 78)
	return Color8(50, 44, 38)

func _load_tile_texture() -> Texture2D:
	var path := "res://assets/sprites/tiles/village_ground_variants_2p5d.png"
	if mode == "guild":
		path = "res://assets/sprites/tiles/guild_ground_variants_2p5d.png"
	elif mode == "wasteland":
		path = "res://assets/sprites/tiles/wasteland_ground_variants_2p5d.png"
	return ASSET_LOADER.load_png(path)

func _texture_for_tile(x: int, y: int, road_strength: float) -> Texture2D:
	if mode == "wasteland":
		return wasteland_surface_texture
	return tile_texture


func _draw_texture_variant(target: CanvasItem, texture: Texture2D, rect: Rect2, x: int, y: int, road_strength := 0.0, modulate := Color.WHITE) -> void:
	if target == null:
		return
	if texture == wasteland_surface_texture:
		var sample_hash: int = absi(int(world_seed) + x * 374761 + y * 668265)
		var source := Rect2(sample_hash % (WASTELAND_SURFACE_SIZE - tile_size + 1), int(sample_hash / 37) % (WASTELAND_SURFACE_SIZE - tile_size + 1), tile_size, tile_size)
		target.draw_texture_rect_region(texture, rect, source, modulate)
		return
	if texture.get_width() >= 512 and texture.get_height() >= 128:
		var macro_idx := _macro_block_index(texture, x, y, road_strength)
		var src_2d := Rect2(macro_idx * 128 + (x % 4) * tile_size, (y % 4) * tile_size, tile_size, tile_size)
		target.draw_texture_rect_region(texture, rect, src_2d, modulate)
		return
	var variants: int = max(1, int(texture.get_width() / tile_size))
	var raw := sin(float(x * 928371 + y * 6173 + world_seed * 101))
	var variant := int(abs(raw) * 100000.0) % variants
	var src := Rect2(variant * tile_size, 0, tile_size, tile_size)
	target.draw_texture_rect_region(texture, rect, src, modulate)

func _macro_block_index(texture: Texture2D, x: int, y: int, road_strength: float) -> int:
	var block_hash: int = absi(int(world_seed) + int(x / 4) * 374761 + int(y / 4) * 668265)
	if mode == "guild":
		if road_strength > 0.4:
			return 2 if (x / 4 + y / 4) % 3 == 0 else 0
		return 0 if block_hash % 4 != 0 else 1
	if texture == road_texture or texture == toxic_path_texture or texture == crystal_path_texture or texture == factory_path_texture:
		match route_id:
			"scrap_highway":
				# Atlas block 1 is factory grating, so it breaks the asphalt route theme.
				return 0
			"toxic_marsh":
				return 0 if block_hash % 4 != 0 else 1
			"crystal_scar":
				return 0 if block_hash % 4 != 0 else 1
			"old_factory":
				return 0 if block_hash % 3 != 0 else 2
			"ruined_metropolis":
				return 2
			"underground_facility":
				return 3
			_:
				return block_hash % 4
	if texture == toxic_texture or texture == crystal_texture or texture == factory_texture:
		return block_hash % 4
	match route_id:
		"scrap_highway":
			return block_hash % 4
		"old_factory":
			return block_hash % 4
		"ruined_metropolis":
			return 2 if block_hash % 4 != 0 else 1
		"underground_facility":
			return 3 if block_hash % 3 != 0 else 2
		_:
			return block_hash % 4


func _draw_rect(target: CanvasItem, rect: Rect2, color: Color, filled: bool = true) -> void:
	if target != null:
		_batch_rects.append([rect, color, filled])


func _draw_line(target: CanvasItem, from: Vector2, to: Vector2, color: Color, width: float = 1.0) -> void:
	if target != null:
		_batch_lines.append([from, to, color, width])


func _draw_circle(target: CanvasItem, position: Vector2, radius: float, color: Color) -> void:
	if target != null:
		_batch_circles.append([position, radius, color])
