extends Node2D

const PREVIEW_USER_DIR_NAME := "R17-Facing-Intake-v019-20261024"
const ROOT_ARGUMENT_PREFIX := "--r17-root="
const OUTPUT_ARGUMENT_PREFIX := "--art-output="
const MANIFEST_RELATIVE_PATH := "data/art/r17_presentation_v2.json"
const CANDIDATE_RELATIVE_PATH := "assets/sprites/player/redesign_v2/source/angular_candidates/r17_blade_idle_e11_25_v019.png"
const REFERENCE_RELATIVE_PATH := "assets/sprites/player/redesign_v2/source/angular_candidates/r17_blade_idle_e22_5_v017.png"

const COLUMN_CENTERS := [160.0, 480.0, 800.0, 1120.0]
const LARGE_BASELINE := 427.0
const SMALL_BASELINE := 664.0
const LARGE_BODY_HEIGHT := 288.0
const SMALL_BODY_HEIGHT := 96.0

var _clip_material: ShaderMaterial


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	call_deferred("_prepare_comparison")


func _prepare_comparison() -> void:
	var custom_user_dir_enabled := bool(ProjectSettings.get_setting("application/config/use_custom_user_dir", false))
	var custom_user_dir_name := String(ProjectSettings.get_setting("application/config/custom_user_dir_name", ""))
	if not custom_user_dir_enabled or custom_user_dir_name != PREVIEW_USER_DIR_NAME:
		push_error("Run this source-only viewer with its dedicated custom user directory.")
		get_tree().quit(2)
		return

	var project_root := _read_user_argument(ROOT_ARGUMENT_PREFIX)
	if project_root.is_empty() or not project_root.is_absolute_path():
		push_error("Pass an absolute --r17-root= path to the project copy.")
		get_tree().quit(2)
		return
	project_root = project_root.trim_suffix("/")

	var output_argument := _read_user_argument(OUTPUT_ARGUMENT_PREFIX)
	if output_argument.is_empty() or not output_argument.is_absolute_path():
		push_error("Pass an absolute --art-output= PNG path or output directory.")
		get_tree().quit(2)
		return
	var output_info := _resolve_output_path(output_argument)
	var output_directory := String(output_info.get("directory", ""))
	var output_path := String(output_info.get("path", ""))
	if output_directory.is_empty() or output_path.is_empty():
		push_error("Could not resolve the requested --art-output= location.")
		get_tree().quit(2)
		return
	var mkdir_error := DirAccess.make_dir_recursive_absolute(output_directory)
	if mkdir_error != OK and mkdir_error != ERR_ALREADY_EXISTS:
		push_error("Could not create the requested art preview output directory: %s" % mkdir_error)
		get_tree().quit(2)
		return

	var manifest_path := project_root.path_join(MANIFEST_RELATIVE_PATH)
	var manifest_file := FileAccess.open(manifest_path, FileAccess.READ)
	if manifest_file == null:
		push_error("Could not read the blade facing manifest under --r17-root=.")
		get_tree().quit(3)
		return
	var manifest_variant: Variant = JSON.parse_string(manifest_file.get_as_text())
	manifest_file.close()
	if not manifest_variant is Dictionary:
		push_error("The blade facing manifest is not a JSON object.")
		get_tree().quit(3)
		return

	var manifest: Dictionary = manifest_variant
	var blade: Dictionary = manifest.get("families", {}).get("blade", {})
	var ready_key: Dictionary = blade.get("keys", {}).get("ready", {})
	var facings: Array = blade.get("facing_angles", [])
	var ready_cells: Array = ready_key.get("cells", [])
	var east_index := _facing_index(facings, 0.0)
	var southeast_index := _facing_index(facings, 45.0)
	if ready_key.is_empty() or east_index < 0 or southeast_index < 0 or east_index >= ready_cells.size() or southeast_index >= ready_cells.size():
		push_error("The manifest does not provide the ready cells for E0 and SE45.")
		get_tree().quit(3)
		return
	if not ready_cells[east_index] is Array or not ready_cells[southeast_index] is Array:
		push_error("The manifest ready cells are malformed.")
		get_tree().quit(3)
		return
	var east_cell: Array = ready_cells[east_index]
	var southeast_cell: Array = ready_cells[southeast_index]
	if east_cell.size() < 9 or southeast_cell.size() < 9:
		push_error("The manifest ready cells do not contain body and anchor metadata.")
		get_tree().quit(3)
		return

	var ready_source_path := _resolve_res_path(project_root, String(ready_key.get("path", "")))
	var east_image := _load_image(ready_source_path, "manifest blade ready source")
	var candidate_image := _load_image(project_root.path_join(CANDIDATE_RELATIVE_PATH), "E11.25 v019 candidate")
	var reference_image := _load_image(project_root.path_join(REFERENCE_RELATIVE_PATH), "E22.5 v017 reference")
	if east_image == null or candidate_image == null or reference_image == null:
		get_tree().quit(3)
		return

	var entries: Array[Dictionary] = [
		_make_manifest_entry("E0 · approved", "ready key · manifest", east_image, east_cell, "Runtime registered"),
		_make_entry("E11.25 · v019", "candidate · registration pending", candidate_image, Rect2(Vector2.ZERO, Vector2(candidate_image.get_size())), Vector2(616.0, 1337.0), Vector2(545.0, 839.0), 1123.0, true, "Manual preview anchor; not registered"),
		_make_entry("E22.5 · v017", "reference only · grip unregistered", reference_image, Rect2(Vector2.ZERO, Vector2(reference_image.get_size())), Vector2(590.0, 1338.0), Vector2.ZERO, 1154.0, false, "Reference only; no grip anchor"),
		_make_manifest_entry("SE45 · approved", "ready key · manifest", east_image, southeast_cell, "Runtime registered")
	]
	_clip_material = _create_alpha_clip_material()
	_build_layout(entries)

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var viewport := get_viewport()
	var image := viewport.get_texture().get_image()
	var save_error := image.save_png(output_path)
	print("ART_FACING_PREVIEW_LAYOUT: viewport=", viewport.get_visible_rect().size, " columns=4 centers=", COLUMN_CENTERS, " body_targets=288px,96px baselines=", LARGE_BASELINE, ",", SMALL_BASELINE, " top_row_markers=sole+hand_when_available bottom_row_markers=none")
	print("ART_FACING_PREVIEW_PNG: mode=", output_info.get("mode", ""), " argument=", output_argument, " path=", output_path, " result=", save_error)
	if save_error != OK:
		push_error("Could not save the art-facing preview PNG: %s" % save_error)
		get_tree().quit(4)
		return
	get_tree().quit(0)


func _read_user_argument(prefix: String) -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""


func _resolve_output_path(output_argument: String) -> Dictionary:
	if output_argument.to_lower().ends_with(".png"):
		return {"mode": "file", "path": output_argument, "directory": output_argument.get_base_dir()}
	return {"mode": "directory", "path": output_argument.path_join("r17_facing_intake_v019.png"), "directory": output_argument}


func _resolve_res_path(project_root: String, resource_path: String) -> String:
	if not resource_path.begins_with("res://"):
		return ""
	return project_root.path_join(resource_path.trim_prefix("res://"))


func _load_image(path: String, label: String) -> Image:
	if path.is_empty():
		push_error("Missing source path for %s." % label)
		return null
	var image := Image.load_from_file(path)
	if image == null or image.is_empty():
		push_error("Could not load %s: %s" % [label, path])
		return null
	return image


func _facing_index(facings: Array, target: float) -> int:
	for index in range(facings.size()):
		if is_equal_approx(float(facings[index]), target):
			return index
	return -1


func _make_manifest_entry(label: String, status: String, image: Image, cell: Array, registration: String) -> Dictionary:
	var region := Rect2(Vector2(float(cell[0]), float(cell[1])), Vector2(float(cell[2]), float(cell[3])))
	var sole := Vector2(float(cell[4]), float(cell[5]))
	var hand := Vector2(float(cell[6]), float(cell[7]))
	return _make_entry(label, status, image, region, sole, hand, float(cell[8]), true, registration)


func _make_entry(label: String, status: String, image: Image, region: Rect2, sole: Vector2, hand: Vector2, body_height: float, has_hand: bool, registration: String) -> Dictionary:
	return {
		"label": label,
		"status": status,
		"image": image,
		"region": region,
		"sole": sole,
		"hand": hand,
		"body_height": body_height,
		"has_hand": has_hand,
		"registration": registration
	}


func _create_alpha_clip_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment(){vec4 pixel=texture(TEXTURE,UV);if(pixel.a<0.96){discard;}COLOR=vec4(pixel.rgb,1.0);}"
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


func _build_layout(entries: Array[Dictionary]) -> void:
	RenderingServer.set_default_clear_color(Color("#171c22"))
	for index in range(entries.size()):
		var center_x := float(COLUMN_CENTERS[index])
		var panel := ColorRect.new()
		panel.position = Vector2(center_x - 150.0, 67.0)
		panel.size = Vector2(300.0, 614.0)
		panel.color = Color8(29, 35, 42, 255) if index % 2 == 0 else Color8(32, 38, 45, 255)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.z_index = -10
		add_child(panel)

	_add_label("R-17 BLADE IDLE · E11.25 INTAKE", Vector2(24, 10), Vector2(740, 28), 22, Color8(239, 231, 211))
	_add_label("Source comparison only · nearest sampling · alpha cutoff 0.96 · registration pending", Vector2(25, 39), Vector2(830, 20), 13, Color8(169, 184, 196))
	_add_label("288px normalized inspection row", Vector2(25, 63), Vector2(330, 20), 13, Color8(209, 198, 162))
	_add_label("Top markers: amber sole · cyan manifest hand · magenta candidate preview hand", Vector2(515, 63), Vector2(720, 20), 12, Color8(170, 185, 195))

	var column_headers: Array[String] = [
		"E0 · approved\nmanifest ready",
		"E11.25 · v019\ncandidate · pending",
		"E22.5 · v017\nreference · grip unregistered",
		"SE45 · approved\nmanifest ready"
	]
	for index in range(entries.size()):
		var center_x := float(COLUMN_CENTERS[index])
		_add_label(column_headers[index], Vector2(center_x - 145.0, 84.0), Vector2(290.0, 42.0), 15, Color8(233, 227, 212), true)
		_add_entry_sprites(entries[index], center_x)
		var entry: Dictionary = entries[index]
		print("ART_FACING_PREVIEW_REGISTRATION: ", entry["label"], " status=", entry["status"], " registration=", entry["registration"], " region=", entry["region"], " sole=", entry["sole"], " hand=", entry["hand"] if bool(entry["has_hand"]) else "unregistered", " body_height=", entry["body_height"])

	var divider := ColorRect.new()
	divider.position = Vector2(24.0, 438.0)
	divider.size = Vector2(1232.0, 1.0)
	divider.color = Color8(75, 89, 101, 255)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(divider)
	_add_label("96px runtime scale · same body-height normalization · no markers", Vector2(25, 445), Vector2(660, 20), 13, Color8(209, 198, 162))
	for index in range(entries.size()):
		_add_label(column_headers[index].replace("\n", " · "), Vector2(float(COLUMN_CENTERS[index]) - 145.0, 469.0), Vector2(290.0, 24.0), 13, Color8(197, 207, 211), true)
	_add_label("v019 hand point is a manual review marker only. E22.5 v017 has no registered grip; active angles and manifests are untouched.", Vector2(24, 692), Vector2(1230, 18), 11, Color8(157, 172, 184))


func _add_entry_sprites(entry: Dictionary, center_x: float) -> void:
	var source_image := entry.get("image") as Image
	var image_texture := ImageTexture.create_from_image(source_image)
	var region: Rect2 = entry["region"]
	var atlas := AtlasTexture.new()
	atlas.atlas = image_texture
	atlas.region = region
	atlas.filter_clip = true
	var sole: Vector2 = entry["sole"]
	var hand: Vector2 = entry["hand"]
	for row in 2:
		var body_height := LARGE_BODY_HEIGHT if row == 0 else SMALL_BODY_HEIGHT
		var baseline_y := LARGE_BASELINE if row == 0 else SMALL_BASELINE
		var sprite := Sprite2D.new()
		sprite.texture = atlas
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.material = _clip_material
		sprite.centered = true
		sprite.scale = Vector2.ONE * body_height / float(entry["body_height"])
		sprite.offset = region.get_center() - sole
		sprite.position = Vector2(center_x, baseline_y)
		sprite.z_index = 1
		add_child(sprite)
		if row == 0:
			_add_marker(sprite.position, Color8(255, 199, 75), 9.0)
			if bool(entry["has_hand"]):
				var hand_color := Color8(75, 224, 228) if String(entry["status"]).contains("approved") else Color8(235, 96, 205)
				var scale_factor := body_height / float(entry["body_height"])
				_add_marker(sprite.position + (hand - sole) * scale_factor, hand_color, 8.0)


func _add_marker(position: Vector2, color: Color, size: float) -> void:
	var border := Polygon2D.new()
	border.position = position
	border.color = Color8(12, 15, 19)
	border.z_index = 20
	border.polygon = _square_polygon(size + 3.0)
	add_child(border)
	var marker := Polygon2D.new()
	marker.position = position
	marker.color = color
	marker.z_index = 21
	marker.polygon = _square_polygon(size)
	add_child(marker)


func _square_polygon(size: float) -> PackedVector2Array:
	var half := size * 0.5
	return PackedVector2Array([
		Vector2(-half, -half),
		Vector2(half, -half),
		Vector2(half, half),
		Vector2(-half, half)
	])


func _add_label(text_value: String, position: Vector2, size: Vector2, font_size: int, color: Color, centered := false) -> void:
	var label := Label.new()
	label.text = text_value
	label.position = position
	label.size = size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if centered:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 5
	add_child(label)
