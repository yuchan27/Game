extends Node

# Attach to a Node in an isolated QA project; optional --qa-output saves rendered captures.

const HUD_SCENE := preload("res://scenes/ui/HUD.tscn")
const REPORT_FILENAME := "world_atlas_regression_report.json"
var _checks: Array[Dictionary] = []
var _failures: Array[String] = []
var _captures: Array[String] = []
var _output := ""
var _tree: SceneTree


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_tree = get_tree()
	var args := OS.get_cmdline_user_args()
	var output_index := args.find("--qa-output")
	if output_index >= 0 and output_index + 1 < args.size():
		_output = args[output_index + 1]
	call_deferred("_run")


func _run() -> void:
	await _tree.process_frame
	GameState.reset_new_run(false)
	var hud := HUD_SCENE.instantiate()
	_tree.root.add_child(hud)
	await _tree.process_frame
	var atlas := hud.get("atlas_panel") as PanelContainer
	_expect(atlas != null and atlas.is_in_group("world_atlas_panel"), "atlas has its stable panel contract")
	if atlas == null:
		hud.queue_free()
		await _tree.process_frame
		_finish()
		return
	var buttons: Dictionary = atlas.get("route_buttons")
	_expect(buttons.size() == 6, "six campaign regions are selectable")
	var markers: Dictionary = atlas.get("map_markers")
	_expect(markers.size() == 6, "six illustration markers are selectable")
	var illustration := atlas.get("map_texture") as TextureRect
	var detail_label := atlas.get("detail_label") as RichTextLabel
	_expect(illustration.texture != null, "authored world illustration loads")
	var before := GameState.get_save_data().duplicate(true)
	hud.call("_set_inventory_visible", true)
	hud.call("_show_notice", "圖鑑通知遮蔽檢查")
	var g := InputEventKey.new()
	g.pressed = true
	g.keycode = KEY_G
	hud.call("_unhandled_input", g)
	_expect(atlas.visible and _tree.paused, "G opens the atlas and owns a reading pause")
	for frame in range(4):
		await _tree.process_frame
	_expect(Rect2(Vector2.ZERO, _tree.root.get_visible_rect().size).encloses(atlas.get_global_rect()), "atlas fits its viewport on first open")
	_expect(atlas.is_in_group("gameplay_input_blocker") and bool(atlas.get_meta("gameplay_input_blocked")), "atlas blocks gameplay input")
	_expect(not (hud.get("inventory_panel") as Control).visible and not (hud.get("notice_label") as Control).visible, "atlas hides the competing modal and floating notice")
	atlas.call("select_route", "ruined_metropolis")
	_expect(String((atlas.get("detail_label") as RichTextLabel).text).contains("待完成"), "city details explain its unmet prerequisites")
	for route_id: String in buttons:
		(buttons[route_id] as Button).pressed.emit()
		_expect(String(atlas.get("selected_route_id")) == route_id and (markers[route_id] as Button).button_pressed, "%s route button selects its matching illustration marker" % route_id)
		atlas.call("select_route", "toxic_marsh" if route_id == "scrap_highway" else "scrap_highway")
		(markers[route_id] as Button).pressed.emit()
		_expect(String(atlas.get("selected_route_id")) == route_id and (buttons[route_id] as Button).button_pressed, "%s illustration marker selects its matching route button" % route_id)
	_expect(GameState.get_save_data() == before, "browsing the atlas never changes route, quest or player state")
	GameState.completed_quests.assign(["clear_scrap_route", "toxic_sample", "crystal_scar_recon", "old_factory_core"])
	atlas.call("refresh")
	_expect((buttons["ruined_metropolis"] as Button).text.contains("可承接"), "campaign completion unlocks the displayed city contract")
	hud.call("_set_codex_visible", true)
	_expect(not atlas.visible and (hud.get("codex_panel") as Control).visible and _tree.paused, "switching to the journal transfers the reading pause")
	hud.call("_set_codex_visible", false)
	_expect(not _tree.paused, "closing the journal releases the transferred pause")
	hud.call("_set_atlas_visible", true)
	hud.call("_set_inventory_visible", true)
	_expect(not atlas.visible and not _tree.paused and (hud.get("inventory_panel") as Control).visible, "switching to equipment releases only the atlas pause")
	hud.call("_close_all_modals")
	_tree.paused = true
	hud.call("_set_atlas_visible", true)
	hud.call("_set_atlas_visible", false)
	_expect(_tree.paused, "closing an atlas opened during an external pause preserves that pause")
	_tree.paused = false
	hud.call("_set_atlas_visible", true)
	var escape := InputEventKey.new()
	escape.pressed = true
	escape.keycode = KEY_ESCAPE
	hud.call("_unhandled_input", escape)
	_expect(not atlas.visible and not _tree.paused and not (hud.get("pause_panel") as Control).visible, "Escape closes the atlas without opening the pause menu")
	hud.call("set_fullscreen_map", false)
	hud.call("_set_atlas_visible", true)
	hud.call("_toggle_map")
	_expect(not atlas.visible and not _tree.paused and bool(hud.get("map_fullscreen")), "the local M map replaces the atlas without retaining its pause")
	hud.call("set_fullscreen_map", false)
	var window := _tree.root as Window
	var original_window_size := window.size
	var original_scale_mode := window.content_scale_mode
	var original_scale_size := window.content_scale_size
	var content_scroll := atlas.get_node("AtlasContentScroll") as ScrollContainer
	var content := atlas.get_node("AtlasContentScroll/AtlasContent") as VBoxContainer
	var navigation := atlas.get_node("AtlasContentScroll/AtlasContent/ModalNavigation") as GridContainer
	var body := atlas.get_node("AtlasContentScroll/AtlasContent/AtlasBody") as BoxContainer
	var map_frame := atlas.get_node("AtlasContentScroll/AtlasContent/AtlasBody/AtlasMapAndRegions/AtlasMapFrame") as PanelContainer
	var regions := atlas.get_node("AtlasContentScroll/AtlasContent/AtlasBody/AtlasMapAndRegions/AtlasRegions") as GridContainer
	var detail_frame := atlas.get_node("AtlasContentScroll/AtlasContent/AtlasBody/AtlasDetailsFrame") as PanelContainer
	var detail_scroll := atlas.get_node("AtlasContentScroll/AtlasContent/AtlasBody/AtlasDetailsFrame/AtlasDetailsStack/AtlasDetailsScroll") as ScrollContainer
	var footer := atlas.get_node("AtlasContentScroll/AtlasContent/AtlasFooter") as Label
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(1024, 768), Vector2i(760, 900), Vector2i(560, 900)]:
		var direct_logical_viewport := dimensions.x < 800
		window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED if direct_logical_viewport else original_scale_mode
		window.content_scale_size = original_scale_size
		window.size = dimensions
		for frame in range(4):
			await _tree.process_frame
		_expect(window.size == dimensions, "actual Window size is %s" % str(dimensions))
		var viewport_size := _tree.root.get_visible_rect().size
		if direct_logical_viewport:
			_expect(viewport_size.is_equal_approx(Vector2(dimensions)), "logical viewport is %s" % str(dimensions))
		hud.call("_set_atlas_visible", true)
		hud.call("_layout")
		for frame in range(4):
			await _tree.process_frame
		var viewport_bounds := Rect2(Vector2.ZERO, viewport_size)
		_expect(viewport_bounds.encloses(atlas.get_global_rect()), "atlas fits viewport %s" % str(dimensions))
		var is_stacked := dimensions.x < 800
		_expect(body.vertical == is_stacked, "atlas stacks map above details at %s" % str(dimensions))
		_expect(regions.columns == (1 if dimensions.x < 640 else 2), "region grid adapts to width %s" % str(dimensions))
		var expected_navigation_columns := 8 if content_scroll.size.x >= 800.0 else (4 if content_scroll.size.x >= 640.0 else 2)
		_expect(navigation.columns == expected_navigation_columns, "modal navigation fits narrow width %s" % str(dimensions))
		_expect(viewport_bounds.encloses(content_scroll.get_global_rect()), "content scroll fits viewport %s" % str(dimensions))
		if is_stacked:
			_expect(detail_frame.size.x >= body.size.x - 1.0 and detail_frame.size.x > 320.0, "stacked details use the available width at %s" % str(dimensions))
			_expect(content.size.y > content_scroll.size.y + 1.0, "stacked content can scroll vertically at %s" % str(dimensions))
			_expect(map_frame.get_global_rect().position.y < detail_frame.get_global_rect().position.y, "stacked map precedes details at %s" % str(dimensions))
		else:
			_expect(detail_frame.size.x >= 320.0 and map_frame.get_global_rect().position.x < detail_frame.get_global_rect().position.x, "wide atlas keeps its side-by-side layout at %s" % str(dimensions))
		for button: Button in buttons.values():
			await _ensure_reachable(content_scroll, button, "%s is reachable by scrolling at %s" % [button.name, str(dimensions)])
			_expect(not button.disabled and button.mouse_filter != Control.MOUSE_FILTER_IGNORE, "%s remains operable at %s" % [button.name, str(dimensions)])
			_expect(_button_text_fits(button), "%s text fits its button %s" % [button.name, str(dimensions)])
			button.pressed.emit()
			_expect(String(atlas.get("selected_route_id")) == String(button.get_meta("route_id")), "%s selects its region at %s" % [button.name, str(dimensions)])
		for marker: Button in markers.values():
			var route_id := String(marker.get_meta("route_id"))
			await _ensure_reachable(content_scroll, marker, "%s marker is reachable by scrolling at %s" % [route_id, str(dimensions)])
			_expect(_rect_contains(illustration.get_global_rect(), marker.get_global_rect()), "%s marker fits the illustration %s" % [route_id, str(dimensions)])
			_expect(not marker.disabled and marker.mouse_filter != Control.MOUSE_FILTER_IGNORE, "%s marker remains operable at %s" % [route_id, str(dimensions)])
			_expect(_button_text_fits(marker), "%s marker text fits %s" % [String(marker.get_meta("route_id")), str(dimensions)])
			marker.pressed.emit()
			_expect(String(atlas.get("selected_route_id")) == route_id, "%s marker selects its region at %s" % [route_id, str(dimensions)])
		await _ensure_reachable(content_scroll, detail_frame, "details are reachable by scrolling at %s" % str(dimensions))
		_expect(_rect_contains(detail_frame.get_global_rect(), detail_scroll.get_global_rect()), "detail scroll fits its panel at %s" % str(dimensions))
		_expect(detail_label.get_global_rect().size.x <= detail_scroll.get_global_rect().size.x + 1.0, "detail text fits its available width at %s" % str(dimensions))
		detail_scroll.scroll_vertical = 100000
		for frame in range(2):
			await _tree.process_frame
		_expect(detail_label.get_global_rect().end.y <= detail_scroll.get_global_rect().end.y + 2.0, "the end of region details is scroll reachable at %s" % str(dimensions))
		detail_scroll.scroll_vertical = 0
		await _ensure_reachable(content_scroll, footer, "atlas footer is reachable by scrolling at %s" % str(dimensions))
		content_scroll.scroll_vertical = 0
		for frame in range(2):
			await _tree.process_frame
		await _capture(dimensions)
		hud.call("_set_atlas_visible", false)
	window.content_scale_mode = original_scale_mode
	window.content_scale_size = original_scale_size
	window.size = original_window_size
	GameState.reset_new_run(false)
	hud.queue_free()
	await _tree.process_frame
	_expect(_tree.get_nodes_in_group("world_atlas_panel").is_empty(), "atlas is freed with its HUD")
	_finish()


func _capture(dimensions: Vector2i) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if _output.is_empty():
		return
	var error := DirAccess.make_dir_recursive_absolute(_output)
	if error != OK:
		_expect(false, "capture output can be created")
		return
	await RenderingServer.frame_post_draw
	var path := _output.path_join("world_atlas_%dx%d.png" % [dimensions.x, dimensions.y])
	var rendered_image := _tree.root.get_texture().get_image()
	_expect(rendered_image.get_size() == dimensions, "rendered atlas image matches %s" % str(dimensions))
	var captured := rendered_image.save_png(path) == OK
	_expect(captured, "atlas capture saved: %s" % path)
	if captured:
		_captures.append(path)


func _button_text_fits(button: Button) -> bool:
	var font := button.get_theme_font("font")
	var text_size := font.get_multiline_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, button.get_theme_font_size("font_size"))
	var required := text_size + button.get_theme_stylebox("normal").get_minimum_size()
	return required.x <= button.size.x + 1.0 and required.y <= button.size.y + 1.0


func _ensure_reachable(scroll: ScrollContainer, control: Control, description: String) -> void:
	scroll.ensure_control_visible(control)
	for frame in range(2):
		await _tree.process_frame
	_expect(_rect_contains(scroll.get_global_rect(), control.get_global_rect()), description)


func _rect_contains(container: Rect2, item: Rect2, tolerance := 1.0) -> bool:
	return item.position.x >= container.position.x - tolerance \
		and item.position.y >= container.position.y - tolerance \
		and item.end.x <= container.end.x + tolerance \
		and item.end.y <= container.end.y + tolerance


func _expect(condition: bool, description: String) -> void:
	_checks.append({"name": description, "passed": condition})
	if not condition:
		_failures.append(description)
	print("[PASS] " + description if condition else "[FAIL] " + description)


func _finish() -> void:
	if not _output.is_empty():
		var error := DirAccess.make_dir_recursive_absolute(_output)
		var file := FileAccess.open(_output.path_join(REPORT_FILENAME), FileAccess.WRITE) if error == OK else null
		if file == null:
			push_error("Cannot write world atlas regression report")
			_tree.quit(1)
			return
		var passed := _failures.is_empty()
		file.store_string(JSON.stringify({"status": "passed" if passed else "failed", "passed": passed, "success": passed, "checks": _checks, "failures": _failures, "captures": _captures}, "\t"))
	for channel in AudioManager.sfx_players:
		channel.stop()
		channel.stream = null
	print("[ATLAS] %d checks, %d failures" % [_checks.size(), _failures.size()])
	_tree.quit(0 if _failures.is_empty() else 1)
