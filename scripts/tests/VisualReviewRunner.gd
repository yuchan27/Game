extends Node

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const VILLAGE_SCENE := preload("res://scenes/levels/village/Village.tscn")
const GUILD_SCENE := preload("res://scenes/levels/guild/Guild.tscn")
const WASTELAND_SCENE := preload("res://scenes/levels/wasteland/Wasteland.tscn")
const SCENE_ENTRANCE := preload("res://scripts/ui/SceneEntrance.gd")

const REVIEW_SIZE := Vector2i(1280, 720)
const RESPONSIVE_SIZE := Vector2i(1024, 768)
const NARROW_DESKTOP_SIZE := Vector2i(800, 600)
const COLD_NARROW_REQUIRED_CAPTURES: Array[String] = [
	"main_title_cold_800x600", "intro_cold_800x600", "inventory_cold_800x600",
	"workshop_cold_800x600", "contract_cold_800x600", "terminal_cold_800x600",
	"journal_cold_800x600", "atlas_cold_800x600", "tutorial_cold_800x600",
	"map_cold_800x600", "pause_cold_800x600"
]
const MIN_CAPTURE_SIZE := Vector2i(640, 360)
const MIN_PNG_BYTES := 4096
const MIN_SAMPLE_COLORS := 8
const REVIEW_SEED := 424242
const REQUIRED_CAPTURES := [
	"main_title",
	"new_game_existing_save_confirmation",
	"new_game_existing_save_confirmation_resize_800x600",
	"continue_load_failure",
	"intro",
	"inventory",
	"tutorial",
	"full_map",
	"full_map_resize_800x600",
	"field_minimap_resize_800x600",
	"dialogue",
	"pause",
	"pause_resize_800x600",
	"death",
	"death_1024x768",
	"death_resize_800x600",
	"route_crystal_scar",
	"route_scrap_highway",
	"route_toxic_marsh",
	"route_old_factory",
	"boss",
	"landmark_crystal_spire",
	"landmark_highway_bus",
	"landmark_marsh_pump",
	"landmark_factory_turbine",
	"village_hud",
	"quest_progress",
	"contract",
	"workshop",
	"terminal",
	"pause_save_success",
	"pause_save_failure",
	"pause_load_pending_presentation",
	"pause_load_failure",
	"guild_hud",
	"player_walk",
	"player_slash",
	"player_shoot",
	"main_title_1024x768",
	"intro_1024x768",
	"inventory_1024x768",
	"inventory_resize_960x768",
	"dialogue_1024x768",
	"full_map_1024x768",
	"quest_progress_1024x768",
	"contract_1024x768",
	"contract_resize_800x600",
	"contract_open_800x600",
	"contract_resize_960x600",
	"workshop_1024x768",
	"terminal_1024x768",
	"terminal_locked_resize_800x600",
	"pause_save_success_1024x768",
	"pause_save_failure_1024x768",
	"pause_load_pending_presentation_1024x768",
	"pause_load_failure_1024x768",
	"expedition_draft", "expedition_draft_960x768",
	"campaign_choice", "campaign_choice_960x768",
	"story_journal", "story_journal_1024x768", "story_discovery", "story_ending",
	"route_ruined_metropolis", "route_underground_facility",
	"story_site_scrap_highway", "story_site_toxic_marsh", "story_site_crystal_scar",
	"story_site_old_factory", "story_site_ruined_metropolis", "story_site_underground_facility",
	"world_atlas", "world_atlas_1024x768", "exploration_scrap", "exploration_crystal",
	"scene_entrance"
]

var _output_dir := ""
var _records: Array[Dictionary] = []
var _runtime_checks: Array[Dictionary] = []
var _failures: Array[String] = []
var _active_scene: Node
var _boss_defeat_setup: Dictionary = {}
var _required_capture_names: Array[String] = []
var _cold_narrow_launch := false
var _review_size := REVIEW_SIZE
var _review_size_from_args := false
var _launch_window_size := Vector2i.ZERO
var _original_save_path := ""
var _window_profiles: Array[Dictionary] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var user_args := OS.get_cmdline_user_args()
	_cold_narrow_launch = user_args.has("--qa-cold-narrow")
	_review_size = _review_size_from_user_args(user_args)
	_review_size_from_args = user_args.has("--qa-review-size")
	_launch_window_size = get_window().size
	if _cold_narrow_launch:
		_required_capture_names.assign(COLD_NARROW_REQUIRED_CAPTURES)
	else:
		_required_capture_names.assign(REQUIRED_CAPTURES)
	if not _cold_narrow_launch:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		get_window().size = _review_size
	_output_dir = _resolve_output_dir()
	var dir_error := DirAccess.make_dir_recursive_absolute(_output_dir)
	if dir_error != OK:
		_failures.append("Could not create QA output directory: %s (error %d)" % [_output_dir, dir_error])
		await _finish_review()
		return
	_original_save_path = SaveManager.default_save_path
	SaveManager.default_save_path = _qa_save_path("default")
	_runtime_check("visual_review_save_path_is_isolated", SaveManager.default_save_path.begins_with(_output_dir), "default_save_path=%s" % SaveManager.default_save_path)

	var headless := OS.has_feature("headless") or DisplayServer.get_name().to_lower().contains("headless")
	if headless:
		_failures.append("Visual review requires a rendered GUI viewport; this run is headless.")
		for capture_name: String in _required_capture_names:
			_records.append({"name": capture_name, "success": false, "reason": "headless renderer; no screenshot was produced"})
		await _finish_review()
		return

	DataRegistry.load_all()
	if _cold_narrow_launch:
		_runtime_check("cold_narrow_launch_window_800x600", _launch_window_size == NARROW_DESKTOP_SIZE, "initial_window=%s first_capture_resized=false" % str(_launch_window_size))
		if _launch_window_size == NARROW_DESKTOP_SIZE:
			print("[VISUAL] Capturing cold-narrow launch at %dx%d to %s" % [NARROW_DESKTOP_SIZE.x, NARROW_DESKTOP_SIZE.y, _output_dir])
			await _capture_cold_narrow_title()
		await _finish_review()
		return
	print("[VISUAL] Capturing %d review images at %dx%d to %s" % [_required_capture_names.size(), _review_size.x, _review_size.y, _output_dir])
	await _capture_title_and_intro()
	await _capture_village_ui()
	await _capture_guild_ui()
	await _capture_wasteland_routes()
	await _capture_exploration_sites()
	await _capture_scene_entrance()
	await _capture_story_arc()
	await _capture_expedition_draft()
	await _capture_campaign_choice()
	await _capture_responsive_views()
	await _finish_review()

func _capture_cold_narrow_title() -> void:
	var previous_save_path := SaveManager.default_save_path
	SaveManager.default_save_path = _qa_save_path("cold_narrow_no_save")
	GameState.reset_new_run(false)
	GameState.current_scene_id = "main"
	var main_scene: Node = MAIN_SCENE.instantiate()
	add_child(main_scene)
	await _wait_for_render()
	_record_title_window_profile("cold_title", NARROW_DESKTOP_SIZE)
	_runtime_check("cold_narrow_first_title_capture_keeps_launch_window", get_window().size == NARROW_DESKTOP_SIZE and _launch_window_size == NARROW_DESKTOP_SIZE, "initial_window=%s capture_window=%s" % [str(_launch_window_size), str(get_window().size)])
	await _capture_image("main_title_cold_800x600")
	_validate_panel_bounds("main_title_cold_800x600", main_scene, "title_panel")
	_validate_title_screen_height(main_scene, "main_title_cold_800x600")
	var new_game_button := main_scene.get("new_game_button") as Button
	_runtime_check("cold_narrow_new_game_action_reachable", new_game_button != null and new_game_button.is_visible_in_tree() and not new_game_button.disabled and get_viewport().gui_get_focus_owner() == new_game_button, "new_game_button=%s focus=%s" % [str(new_game_button != null and new_game_button.is_visible_in_tree() and not new_game_button.disabled), str(get_viewport().gui_get_focus_owner().get_path()) if get_viewport().gui_get_focus_owner() != null else "none"])
	await _activate_visual_button(new_game_button)
	await _wait_for_render()
	var intro_panel := main_scene.get("intro_panel") as Control
	_runtime_check("cold_narrow_new_game_opens_intro", bool(main_scene.get("intro_active")) and intro_panel != null and intro_panel.is_visible_in_tree(), "intro_active=%s panel_visible=%s" % [str(main_scene.get("intro_active")), str(intro_panel != null and intro_panel.is_visible_in_tree())])
	await _capture_image("intro_cold_800x600")
	_validate_panel_bounds("intro_cold_800x600", main_scene, "intro_panel")
	var intro_scroll := intro_panel.find_child("PanelContentScroll", true, false) as ScrollContainer if intro_panel != null else null
	var intro_focus := get_viewport().gui_get_focus_owner()
	_runtime_check("cold_narrow_intro_focus_follows_visible_entry", intro_scroll != null and intro_scroll.follow_focus and intro_focus != null and intro_panel.is_ancestor_of(intro_focus) and intro_focus.is_visible_in_tree(), "scroll=%s follow_focus=%s focus=%s" % [str(intro_scroll != null), str(intro_scroll.follow_focus if intro_scroll != null else false), str(intro_focus.get_path()) if intro_focus != null else "none"])
	var hud := await _complete_intro_to_village(main_scene, "cold_narrow")
	SaveManager.default_save_path = previous_save_path
	if hud == null:
		_runtime_check("cold_narrow_village_hud_exists", false, "the title input path did not reach a Village HUD")
		return
	await _capture_cold_narrow_hud_screen(hud, KEY_I, "inventory_panel", "inventory_cold_800x600", KEY_ESCAPE)
	await _capture_cold_narrow_hud_screen(hud, KEY_C, "workshop_panel", "workshop_cold_800x600", KEY_ESCAPE)
	await _capture_cold_narrow_hud_screen(hud, KEY_J, "contract_panel", "contract_cold_800x600", KEY_ESCAPE)
	await _capture_cold_narrow_hud_screen(hud, KEY_T, "terminal_panel", "terminal_cold_800x600", KEY_ESCAPE)
	await _capture_cold_narrow_hud_screen(hud, KEY_K, "codex_panel", "journal_cold_800x600", KEY_ESCAPE)
	await _capture_cold_narrow_hud_screen(hud, KEY_G, "atlas_panel", "atlas_cold_800x600", KEY_ESCAPE)
	await _capture_cold_narrow_hud_screen(hud, KEY_H, "tutorial_panel", "tutorial_cold_800x600", KEY_ESCAPE)
	await _capture_cold_narrow_hud_screen(hud, KEY_M, "minimap_panel", "map_cold_800x600", KEY_ESCAPE)
	await _capture_cold_narrow_hud_screen(hud, KEY_ESCAPE, "pause_panel", "pause_cold_800x600", KEY_ESCAPE)

func _capture_cold_narrow_hud_screen(hud: Node, open_key: int, panel_property: String, capture_name: String, close_key: int) -> void:
	await _tap_visual_key(open_key)
	await _wait_for_render()
	var panel := hud.get(panel_property) as Control
	var visible := panel != null and panel.is_visible_in_tree()
	_runtime_check("%s_opens_from_keyboard" % capture_name, visible, "key=%d panel=%s visible=%s" % [open_key, panel_property, str(visible)])
	if visible:
		if capture_name.begins_with("contract"):
			_validate_contract_task_readability(panel, capture_name)
			_validate_contract_initial_view(panel, "%s_initial_view" % capture_name)
		_validate_control_bounds(capture_name, panel)
		if panel_property != "minimap_panel":
			_assert_initial_modal_focus(hud, panel_property, capture_name + "_first_open")
		await _capture_image(capture_name)
		if capture_name == "tutorial_cold_800x600":
			await _validate_cold_narrow_tutorial_interactions(hud, panel, capture_name)
	if panel != null and panel.is_visible_in_tree():
		await _tap_visual_key(close_key)
		await _wait_for_render()

func _validate_cold_narrow_tutorial_interactions(hud: Node, panel: Control, capture_name: String) -> void:
	var close_button := panel.find_child("TutorialCloseButton", true, false) as Button
	var initial_focus := get_viewport().gui_get_focus_owner()
	_runtime_check("%s_focus_starts_on_close_button" % capture_name, close_button != null and initial_focus == close_button, "close_button=%s focus=%s" % [str(close_button != null), str(initial_focus.get_path()) if initial_focus != null else "none"])

	await _tap_visual_key(KEY_TAB)
	var tab_focus := get_viewport().gui_get_focus_owner()
	var tab_focus_inside := tab_focus != null and panel.is_ancestor_of(tab_focus) and tab_focus.is_visible_in_tree()
	_runtime_check("%s_tab_focus_stays_inside_panel" % capture_name, tab_focus_inside, "focus=%s panel=%s" % [str(tab_focus.get_path()) if tab_focus != null else "none", str(panel.get_path())])

	var scroll := panel.find_child("TutorialScroll", true, false) as ScrollContainer
	var scrollbar := scroll.get_v_scroll_bar() if scroll != null else null
	var maximum := int(maxf(0.0, scrollbar.max_value - scrollbar.page)) if scrollbar != null else 0
	if scroll != null:
		scroll.scroll_vertical = 0
	await _wait_for_render()
	var scroll_start := scroll.scroll_vertical if scroll != null else -1
	var wheel_event := InputEventMouseButton.new()
	wheel_event.position = scroll.get_global_rect().get_center() if scroll != null else Vector2.ZERO
	wheel_event.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel_event.factor = 1.0
	wheel_event.pressed = true
	if scroll != null:
		Input.parse_input_event(wheel_event)
		await _wait_for_render()
	var scroll_end := scroll.scroll_vertical if scroll != null else -1
	_runtime_check("%s_scroll_has_overflow" % capture_name, scroll != null and maximum > 0, "scroll=%s maximum=%d" % [str(scroll != null), maximum])
	_runtime_check("%s_mouse_wheel_scrolls_content" % capture_name, scroll != null and scroll_end > scroll_start, "before=%d after=%d maximum=%d" % [scroll_start, scroll_end, maximum])
	if scroll != null:
		scroll.scroll_vertical = 0
		await _wait_for_render()

	var activation_observed := {"pressed": false}
	if close_button != null:
		close_button.pressed.connect(func() -> void: activation_observed["pressed"] = true, CONNECT_ONE_SHOT)
		await _tap_visual_key(KEY_ENTER)
		await _wait_for_render()
	var closed_by_activation := not panel.is_visible_in_tree()
	_runtime_check("%s_keyboard_activates_close_button" % capture_name, close_button != null and bool(activation_observed["pressed"]) and closed_by_activation, "close_button=%s pressed_signal=%s visible_after_activation=%s" % [str(close_button != null), str(activation_observed["pressed"]), str(panel.is_visible_in_tree())])
	_runtime_check("%s_close_action_releases_reading_pause" % capture_name, closed_by_activation and not get_tree().paused, "visible=%s tree_paused=%s" % [str(panel.is_visible_in_tree()), str(get_tree().paused)])

	await _tap_visual_key(KEY_H)
	await _wait_for_render()
	var reopened_by_h := panel.is_visible_in_tree()
	_runtime_check("%s_reopens_with_H_after_button_activation" % capture_name, reopened_by_h, "visible=%s" % str(reopened_by_h))
	await _tap_visual_key(KEY_ESCAPE)
	await _wait_for_render()
	var closed_by_escape := not panel.is_visible_in_tree()
	_runtime_check("%s_escape_closes_after_reopen" % capture_name, reopened_by_h and closed_by_escape, "visible_after_escape=%s" % str(panel.is_visible_in_tree()))

func _capture_title_and_intro() -> void:
	var previous_save_path := SaveManager.default_save_path
	var existing_save_path := _qa_save_path("new_game_existing_save")
	SaveManager.default_save_path = existing_save_path
	GameState.reset_new_run(false)
	GameState.current_scene_id = "main"
	var fixture_saved := SaveManager.save_game(false)
	var fixture_hash_before := FileAccess.get_file_as_string(existing_save_path).sha256_text() if fixture_saved else ""
	_runtime_check("new_game_existing_save_fixture_created", fixture_saved and SaveManager.has_save(), "fixture=%s" % existing_save_path)
	var main_scene: Node = MAIN_SCENE.instantiate()
	add_child(main_scene)
	await _wait_for_render()
	_record_title_window_profile("standard_title", _review_size)
	await _capture_image("main_title")
	_validate_panel_bounds(_review_check_name("main_title"), main_scene, "title_panel")
	_validate_title_screen_height(main_scene, _review_check_name("main_title"))
	var guide_panel := main_scene.get("title_panel") as Control
	var control_guide := main_scene.find_child("TitleControlGuide", true, false) as Label
	var control_guide_text := control_guide.text if control_guide != null else ""
	var title_controls_complete := control_guide != null and guide_panel != null \
		and guide_panel.get_global_rect().encloses(control_guide.get_global_rect()) \
		and control_guide_text.contains("C 工坊") and control_guide_text.contains("T 終端") \
		and control_guide_text.contains("G 紀行") and control_guide_text.contains("H 說明")
	_runtime_check("title_control_guide_covers_gameplay_panels_inside_title", title_controls_complete, "guide=%s title_panel=%s" % [control_guide_text if control_guide != null else "missing", str(guide_panel != null)])
	SaveManager.default_save_path = _qa_save_path("missing_save")
	main_scene.call("_continue_game")
	await _wait_for_render()
	var title_layer := main_scene.get("title_layer") as CanvasLayer
	var failure_notice := main_scene.get("title_status") as Label
	_runtime_check("continue_failure_keeps_title", title_layer != null and is_instance_valid(title_layer) and title_layer.is_inside_tree(), "title_layer_valid=%s" % str(title_layer != null and is_instance_valid(title_layer)))
	_runtime_check("continue_failure_shows_notice", failure_notice != null and failure_notice.visible and failure_notice.text.contains("讀取失敗"), "notice=%s" % (failure_notice.text if failure_notice != null else "missing"))
	await _capture_image("continue_load_failure")
	SaveManager.default_save_path = existing_save_path
	var new_game_button := main_scene.get("new_game_button") as Button
	_runtime_check("new_game_existing_save_action_available", new_game_button != null and new_game_button.is_visible_in_tree() and not new_game_button.disabled, "button=%s" % str(new_game_button != null and new_game_button.is_visible_in_tree() and not new_game_button.disabled))
	if new_game_button != null:
		await _activate_visual_button(new_game_button)
	await _wait_for_render()
	var confirmation := main_scene.get("new_game_confirmation") as ConfirmationDialog
	var confirmation_visible: bool = confirmation != null and confirmation.visible
	_runtime_check("new_game_confirmation_clears_stale_load_error", failure_notice != null and not failure_notice.visible and failure_notice.text.is_empty(), "notice_visible=%s text=%s" % [str(failure_notice != null and failure_notice.visible), failure_notice.text if failure_notice != null else "missing"])
	var confirm_button := confirmation.get_ok_button() as Button if confirmation != null else null
	var cancel_button := confirmation.get_cancel_button() as Button if confirmation != null else null
	var confirmation_focus := confirmation.get_viewport().gui_get_focus_owner() if confirmation != null else null
	_runtime_check("new_game_existing_save_confirmation_visible", confirmation_visible and confirmation.dialog_text.contains("覆寫"), "visible=%s text=%s" % [str(confirmation_visible), confirmation.dialog_text if confirmation != null else "missing"])
	_runtime_check("new_game_confirmation_uses_content_height", confirmation_visible and confirmation.size.y <= 160, "size=%s max_content_height=160" % str(confirmation.size) if confirmation != null else "missing")
	_runtime_check("new_game_existing_save_confirmation_focuses_cancel", confirmation_visible and cancel_button != null and confirmation_focus == cancel_button, "focus=%s cancel=%s" % [str(confirmation_focus.get_path()) if confirmation_focus != null else "none", str(cancel_button != null)])
	if confirmation_visible:
		await _capture_image("new_game_existing_save_confirmation")
		var original_window_size := get_window().size
		get_window().size = NARROW_DESKTOP_SIZE
		await _wait_for_render()
		var resized_confirmation_focus := confirmation.get_viewport().gui_get_focus_owner()
		var expected_confirmation_width := mini(480, maxi(1, get_window().size.x - 48))
		_runtime_check("new_game_confirmation_resize_keeps_cancel_focus", confirmation.visible and resized_confirmation_focus == cancel_button and cancel_button != null and cancel_button.is_visible_in_tree(), "window=%s size=%s focus=%s" % [str(get_window().size), str(confirmation.size), str(resized_confirmation_focus.get_path()) if resized_confirmation_focus != null else "none"])
		_runtime_check("new_game_confirmation_resize_respects_window_width", confirmation.size.x <= expected_confirmation_width, "window_width=%d dialog_width=%d allowed=%d" % [get_window().size.x, confirmation.size.x, expected_confirmation_width])
		await _capture_image("new_game_existing_save_confirmation_resize_800x600")
		get_window().size = original_window_size
		await _wait_for_render()
		if cancel_button != null:
			cancel_button.grab_focus()
			await _tap_visual_key(KEY_ESCAPE)
		await _wait_for_render()
	var title_panel := main_scene.get("title_panel") as Control
	var confirmation_closed_by_cancel: bool = confirmation != null and not confirmation.visible
	var title_focus := get_viewport().gui_get_focus_owner()
	var focus_returned_to_title := title_panel != null and title_focus != null and title_panel.is_ancestor_of(title_focus) and title_focus.is_visible_in_tree()
	var fixture_unchanged_after_cancel := fixture_saved and FileAccess.get_file_as_string(existing_save_path).sha256_text() == fixture_hash_before
	_runtime_check("new_game_cancel_closes_confirmation", confirmation_visible and confirmation_closed_by_cancel, "closed=%s" % str(confirmation_closed_by_cancel))
	_runtime_check("new_game_cancel_returns_focus_to_title", confirmation_closed_by_cancel and focus_returned_to_title, "focus=%s title_panel=%s" % [str(title_focus.get_path()) if title_focus != null else "none", str(title_panel != null)])
	_runtime_check("new_game_cancel_preserves_existing_save", confirmation_closed_by_cancel and fixture_unchanged_after_cancel, "fixture=%s unchanged=%s" % [existing_save_path, str(fixture_unchanged_after_cancel)])
	if not confirmation_closed_by_cancel and confirmation != null:
		await _tap_visual_key(KEY_ESCAPE)
		await _wait_for_render()
	if confirmation != null and not confirmation.visible and new_game_button != null:
		await _activate_visual_button(new_game_button)
		await _wait_for_render()
	var confirmation_reopened: bool = confirmation != null and confirmation.visible
	var reopened_focus := confirmation.get_viewport().gui_get_focus_owner() if confirmation_reopened else null
	_runtime_check("new_game_existing_save_confirmation_reopens", confirmation_reopened and confirmation.dialog_text.contains("覆寫") and reopened_focus == cancel_button, "visible=%s focus=%s" % [str(confirmation_reopened), str(reopened_focus.get_path()) if reopened_focus != null else "none"])
	if confirmation_reopened and confirm_button != null:
		await _activate_visual_button(confirm_button)
	await _wait_for_render()
	var intro_panel := main_scene.get("intro_panel") as Control
	var intro_visible := bool(main_scene.get("intro_active")) and intro_panel != null and intro_panel.is_visible_in_tree()
	_runtime_check("new_game_confirmation_opens_intro", intro_visible, "intro_active=%s panel_visible=%s" % [str(main_scene.get("intro_active")), str(intro_panel != null and intro_panel.is_visible_in_tree())])
	var fixture_preserved_during_intro := fixture_saved and FileAccess.get_file_as_string(existing_save_path).sha256_text() == fixture_hash_before
	_runtime_check("existing_save_is_preserved_until_entering_village", fixture_preserved_during_intro, "fixture=%s unchanged=%s" % [existing_save_path, str(fixture_preserved_during_intro)])
	await _capture_image("intro")
	_validate_panel_bounds(_review_check_name("intro"), main_scene, "intro_panel")
	AudioManager.stop_voice()
	var village_hud := await _complete_intro_to_village(main_scene, "title_flow")
	var fixture_hash_after_entry := FileAccess.get_file_as_string(existing_save_path).sha256_text() if SaveManager.has_save(existing_save_path) else ""
	_runtime_check("existing_save_is_replaced_after_entering_village", village_hud != null and fixture_saved and not fixture_hash_after_entry.is_empty() and fixture_hash_after_entry != fixture_hash_before, "reached_village=%s fixture=%s changed_after_entry=%s" % [str(village_hud != null), existing_save_path, str(fixture_hash_after_entry != fixture_hash_before)])
	SaveManager.default_save_path = previous_save_path

func _capture_village_ui() -> void:
	await _prepare_scene("village", VILLAGE_SCENE)
	var hud := _find_hud()
	if hud == null:
		_failures.append("Village scene did not create the expected HUD.")
		return
	_validate_hud_groups()
	await _run_nearest_interaction_check(hud)
	await _capture_image("village_hud")
	await _capture_world_atlas(hud, "world_atlas")
	var saved_quest_id := GameState.active_quest_id
	var saved_route_id := GameState.current_route_id
	var saved_quest_progress := GameState.quest_progress.duplicate(true)
	var saved_inventory := GameState.inventory.duplicate(true)
	GameState.active_quest_id = "old_factory_core"
	GameState.current_route_id = String(DataRegistry.get_quest("old_factory_core").get("route", "old_factory"))
	GameState.quest_progress = {"defeat_enemy": 7, "defeat_boss": 0}
	GameState.inventory["mutant_core"] = 1
	hud.call("_refresh")
	await _wait_for_render()
	var quest_label := hud.get("quest_label") as Label
	var quest_text := String(quest_label.text) if quest_label != null else ""
	var quest_name := String(DataRegistry.get_quest("old_factory_core").get("name", ""))
	_runtime_check("quest_guidance_is_readable", quest_label != null and quest_label.get_line_count() >= 2 and quest_text.contains(quest_name) and quest_text.contains("下一步：") and quest_text.contains("[J]"), "lines=%d text=%s" % [quest_label.get_line_count() if quest_label != null else 0, quest_text])
	_validate_quest_panel_layout(hud, "quest_progress_panel")
	await _capture_image("quest_progress")
	await _capture_hub_panel(hud, "_set_contract_visible", "_set_contract_visible", "contract_panel", "contract_list", "contract", true)
	GameState.active_quest_id = saved_quest_id
	GameState.current_route_id = saved_route_id
	GameState.quest_progress = saved_quest_progress
	GameState.inventory = saved_inventory
	hud.call("_refresh")
	await _check_hidden_inventory_refresh(hud)
	await _capture_hub_panel(hud, "open_workshop", "_set_workshop_visible", "workshop_panel", "workshop_list", "workshop", "craft")
	await _capture_hub_panel(hud, "_set_terminal_visible", "_set_terminal_visible", "terminal_panel", "terminal_list", "terminal", true)
	var pose_players := get_tree().get_nodes_in_group("player")
	if not pose_players.is_empty():
		var pose_player := pose_players[0] as CharacterBody2D
		await _capture_player_pose("player_walk", pose_player, 1)
		await _capture_player_pose("player_slash", pose_player, 4)
		await _capture_player_pose("player_shoot", pose_player, 2)

	hud.call("_set_inventory_visible", true)
	await _check_notice_suppressed_by_modal(hud, "inventory_hides_global_notice")
	var inventory_panel := hud.get("inventory_panel") as PanelContainer
	var inventory_style: StyleBoxFlat = inventory_panel.get_theme_stylebox("panel") as StyleBoxFlat if inventory_panel != null else null
	_runtime_check("inventory_backdrop_is_nearly_opaque", inventory_style != null and inventory_style.bg_color.a >= 0.99, "alpha=%.2f" % (inventory_style.bg_color.a if inventory_style != null else 0.0))
	await _wait_for_render()
	_assert_initial_modal_focus(hud, "inventory_panel", "inventory_first_open")
	await _capture_image("inventory")
	var initial_inventory_width := float(hud.call("_inventory_available_display_width"))
	_validate_inventory_layout(hud, initial_inventory_width >= 940.0, _review_check_name("inventory"))
	await _check_player_input_blocked(hud, "inventory")
	hud.call("_set_inventory_visible", false)
	_clear_test_notice(hud)

	var tutorial_panels := get_tree().get_nodes_in_group("tutorial_panel")
	if tutorial_panels.is_empty():
		_failures.append("Tutorial panel group is missing.")
	else:
		hud.call("_set_tutorial_visible", true)
		await _wait_for_render()
		_assert_initial_modal_focus(hud, "tutorial_panel", "tutorial_first_open")
		await _check_notice_suppressed_by_modal(hud, "tutorial_hides_global_notice")
		await _wait_for_render()
		await _capture_image("tutorial")
		await _check_player_input_blocked(hud, "tutorial")
		hud.call("_set_tutorial_visible", false)
		_clear_test_notice(hud)

	var players := get_tree().get_nodes_in_group("player")
	var npcs := get_tree().get_nodes_in_group("dialogue_npc")
	if players.is_empty() or npcs.is_empty():
		_failures.append("Dialogue capture needs at least one player and dialogue NPC.")
	else:
		var player := players[0] as Node2D
		var npc := npcs[0] as Node2D
		player.global_position = npc.global_position + Vector2(48.0, 0.0)
		player.reset_physics_interpolation()
		GameState.player_position = player.global_position
		await _wait_for_render()
		if npc.has_method("interact"):
			npc.call("interact")
		else:
			_failures.append("Dialogue NPC has no interact method.")
		await _wait_for_render()
		await _check_notice_suppressed_by_modal(hud, "dialogue_hides_global_notice")
		await _capture_image("dialogue")
		await _check_player_input_blocked(hud, "dialogue")
		var dialogue_before := String((hud.get("dialogue_body") as Label).text)
		player.call("_interact_with_nearest_target", true)
		await _wait_for_render()
		var dialogue_after := String((hud.get("dialogue_body") as Label).text)
		_runtime_check("dialogue_E_advances_active_npc_only", dialogue_after != dialogue_before, "before=%s after=%s" % [dialogue_before, dialogue_after])
		_clear_test_notice(hud)

	var pause_panels := get_tree().get_nodes_in_group("gameplay_input_blocker")
	var pause_panel: Control
	for candidate: Node in pause_panels:
		if candidate is Control and (candidate as Control).name == "PausePanel":
			pause_panel = candidate as Control
			break
	if pause_panel == null:
		_failures.append("Pause panel is missing.")
	else:
		hud.call("_set_pause_visible", true)
		await _wait_for_render()
		_assert_initial_modal_focus(hud, "pause_panel", "pause_first_open")
		hud.call("_show_notice", "暫停期間仍會顯示存檔提示")
		var pause_notice := hud.get("notice_label") as Control
		_runtime_check("pause_suppresses_global_notice", pause_notice != null and not pause_notice.visible, "visible=%s" % str(pause_notice != null and pause_notice.visible))
		await _wait_for_render()
		await _capture_image("pause")
		_validate_pause_panel_height(pause_panel, "pause_1280x720")
		await _check_player_input_blocked(hud, "pause")
		await _capture_recovery_modal_after_wide_to_narrow(
			"pause_resize_800x600",
			pause_panel,
			hud.get("pause_resume_button") as Button,
			get_window().size
		)
		_runtime_check("pause_HUD_processes_while_paused", int(hud.process_mode) == Node.PROCESS_MODE_ALWAYS, "process_mode=%d" % int(hud.process_mode))
		var escape := InputEventKey.new()
		escape.pressed = true
		escape.keycode = KEY_ESCAPE
		hud.call("_unhandled_input", escape)
		_runtime_check("pause_Escape_unpauses", not get_tree().paused, "tree_paused=%s" % str(get_tree().paused))
		hud.call("_set_pause_visible", false)
		await _capture_pause_feedback(hud, "pause_save_success", "已儲存目前狀態；存檔不會提前結算本趟收穫。", true)
		await _capture_pause_feedback(hud, "pause_save_failure", "存檔失敗；本趟收穫未因此入庫。按 Esc 關閉暫停可查看詳細訊息。", false)
		await _capture_pause_feedback(hud, "pause_load_pending_presentation", "讀取中…正在進入存檔場景。", true, true)
		await _capture_pause_feedback(hud, "pause_load_failure", "讀取失敗；目前仍留在暫停選單。按 Esc 關閉暫停可查看詳細訊息。", false)
		_clear_test_notice(hud)

func _capture_guild_ui() -> void:
	await _prepare_scene("guild", GUILD_SCENE)
	await _wait_for_render()
	await _capture_image("guild_hud")

func _capture_world_atlas(hud: Node, capture_name: String) -> void:
	hud.call("_set_atlas_visible", true)
	await _wait_for_render()
	var atlas := hud.get("atlas_panel") as Control
	if atlas == null:
		_runtime_check(capture_name + "_exists", false, "world atlas panel is missing")
		return
	_assert_initial_modal_focus(hud, "atlas_panel", capture_name + "_first_open")
	atlas.call("select_route", "ruined_metropolis")
	await _wait_for_render()
	var buttons: Dictionary = atlas.get("route_buttons")
	var illustration := atlas.get("map_texture") as TextureRect
	var details := atlas.get("detail_label") as RichTextLabel
	_runtime_check(capture_name + "_six_regions", buttons.size() == 6 and get_tree().get_nodes_in_group("world_atlas_route").size() == 6 and get_tree().get_nodes_in_group("world_atlas_marker").size() == 6, "route buttons=%d, illustration markers=%d" % [buttons.size(), get_tree().get_nodes_in_group("world_atlas_marker").size()])
	_runtime_check(capture_name + "_authored_illustration", illustration != null and illustration.texture != null and illustration.texture.get_width() > 1000, "world illustration texture is loaded from the asset")
	_runtime_check(capture_name + "_prerequisites_readable", details != null and details.text.contains("待完成") and details.text.contains("前置委託"), "city region describes the four unmet campaign prerequisites")
	_runtime_check(capture_name + "_hides_unknown_revelations", not _atlas_contains_revelation(details), "unexplored sites display location hints")
	_runtime_check(capture_name + "_reading_pause", get_tree().paused, "atlas owns a reading pause")
	_validate_control_bounds(capture_name, atlas)
	for route_id in buttons:
		var button := buttons[route_id] as Control
		_runtime_check("%s_%s_button_in_panel" % [capture_name, route_id], button != null and atlas.get_global_rect().encloses(button.get_global_rect()), "route selection is inside the visible atlas")
	if details != null:
		_validate_control_bounds(capture_name + "_detail_scroll", details.get_parent() as Control)
	await _check_notice_suppressed_by_modal(hud, capture_name + "_hides_notice")
	await _capture_image(capture_name)
	await _check_player_input_blocked(hud, capture_name)
	hud.call("_set_atlas_visible", false)
	_runtime_check(capture_name + "_releases_reading_pause", not get_tree().paused, "closing the atlas resumes the world")
	_clear_test_notice(hud)

func _atlas_contains_revelation(details: RichTextLabel) -> bool:
	if details == null:
		return false
	for event: Dictionary in DataRegistry.events:
		var revelation := String(event.get("revelation", ""))
		if bool(event.get("story", false)) and not revelation.is_empty() and details.text.contains(revelation):
			return true
	return false

func _capture_exploration_sites() -> void:
	for setup: Array in [["scrap_highway", "exploration_scrap"], ["crystal_scar", "exploration_crystal"]]:
		await _prepare_wasteland(String(setup[0]), false)
		var world := _active_scene as Node2D
		var points: Array = world.get("_exploration_points")
		var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
		if points.is_empty() or player == null:
			_runtime_check(String(setup[1]) + "_site_exists", false, "exploration site or player is missing")
			continue
		world.set_process(false)
		player.set_physics_process(false)
		var point: Dictionary = points[0]
		player.global_position = Vector2(point["world_position"]) + Vector2(0, 48)
		player.reset_physics_interpolation()
		GameState.player_position = player.global_position
		var camera := player.get_node_or_null("Camera2D") as Camera2D
		if camera != null:
			camera.reset_smoothing()
			camera.force_update_scroll()
		var inventory_before := GameState.inventory.duplicate(true)
		world.call("_refresh_exploration_points")
		for enemy: Node in get_tree().get_nodes_in_group("enemy"):
			enemy.set_process(false)
			enemy.set_physics_process(false)
		var area := point.get("interactable_node") as Area2D
		# A teleport's body transform and monitored overlaps settle on separate physics ticks.
		for _tick in range(8):
			await get_tree().physics_frame
			if area != null and area.overlaps_body(player) and bool(area.call("can_interact")):
				break
		await _wait_for_render()
		var guards: Array = point.get("guard_nodes", [])
		var status := point.get("status_label") as Label
		var capture_name := String(setup[1])
		_runtime_check(capture_name + "_walkup_is_reachable", area != null and bool(area.call("can_interact")), "player stands at the authored site's real interaction area")
		_runtime_check(capture_name + "_three_live_guards", bool(point.get("active", false)) and guards.size() == 3 and not bool(point.get("cleared", true)), "three guards contest the reward before combat")
		_runtime_check(capture_name + "_reward_requires_combat", GameState.inventory == inventory_before and not GameState.discovered_events.has(String(point["discovery_key"])), "approaching the reward has not granted it")
		_runtime_check(capture_name + "_guard_cap", get_tree().get_nodes_in_group("enemy").size() <= 50, "exploration guards share the normal enemy budget")
		_runtime_check(capture_name + "_status_is_readable", status != null and status.text.contains(String(point.get("name", ""))) and status.text.contains("剩餘守衛 3"), "site label explains the remaining encounter")
		var hud := _find_hud()
		if hud != null:
			_clear_test_notice(hud)
		await _capture_image(capture_name)

func _capture_expedition_draft() -> void:
	await _prepare_wasteland("scrap_highway", false)
	var hud := _find_hud()
	if hud == null:
		_failures.append("Expedition draft capture could not find the HUD.")
		return
	var previous_save_path := SaveManager.default_save_path
	SaveManager.default_save_path = _output_dir.path_join("expedition_draft_fixture_save.json")
	var offered := GameState.offer_expedition_draft("scrap_highway_early")
	SaveManager.default_save_path = previous_save_path
	await _wait_for_render()
	var state: Dictionary = GameState.expedition_draft_state()
	var panel := hud.get("expedition_draft_panel") as Control
	var cards := hud.get("expedition_draft_cards") as GridContainer
	var options: Array = state.get("options", [])
	var first_button := cards.find_child("ChooseDraftButton", true, false) as Button if cards != null else null
	_runtime_check("expedition_draft_authored_site_is_pending", offered and String(state.get("pending", "")) == "scrap_highway_early" and panel != null and panel.visible, "offered=%s site=%s visible=%s" % [str(offered), String(state.get("site_name", "")), str(panel != null and panel.visible)])
	_runtime_check("expedition_draft_all_options_are_rendered", cards != null and cards.get_child_count() == options.size() and options.size() >= 3 and first_button != null, "options=%d cards=%d" % [options.size(), cards.get_child_count() if cards != null else 0])
	_runtime_check("expedition_draft_first_option_receives_focus", first_button != null and first_button.has_focus(), "focus_owner=%s" % (str(get_viewport().gui_get_focus_owner().get_path()) if get_viewport().gui_get_focus_owner() != null else "none"))
	_runtime_check("expedition_draft_pauses_world", get_tree().paused, "tree_paused=%s" % str(get_tree().paused))
	_validate_control_bounds("expedition_draft", panel)
	await _check_player_input_blocked(hud, "expedition_draft")
	_clear_test_notice(hud)
	await _capture_image("expedition_draft")
	await _capture_resized_modal("expedition_draft_960x768", panel, Vector2i(960, 768))

func _capture_campaign_choice() -> void:
	await _prepare_scene("village", VILLAGE_SCENE)
	var previous_save_path := SaveManager.default_save_path
	SaveManager.default_save_path = _output_dir.path_join("campaign_choice_fixture_save.json")
	var quest_id := "clear_scrap_route"
	if not GameState.start_quest(quest_id):
		SaveManager.default_save_path = previous_save_path
		_failures.append("Campaign-choice capture could not start the authored fixture quest.")
		return
	var quest := DataRegistry.get_quest(quest_id)
	var outings: Array = quest.get("campaign_outings", [])
	if outings.size() < 2:
		SaveManager.default_save_path = previous_save_path
		_failures.append("Campaign-choice fixture quest no longer has the expected second outing.")
		return
	var campaign_state: Dictionary = GameState.quest_progress.get("campaign", {}).duplicate(true)
	var action_results: Dictionary = campaign_state.get("actions", {}).duplicate(true)
	var first_outing: Dictionary = outings[0]
	for definition: Dictionary in first_outing.get("actions", []):
		var action_id := String(definition.get("id", ""))
		if action_id.is_empty():
			continue
		var result := "done"
		if String(definition.get("type", "")) == "choice":
			var options: Array = definition.get("options", [])
			if not options.is_empty():
				result = String(options[0].get("id", ""))
		action_results[action_id] = result
	campaign_state["actions"] = action_results
	campaign_state["outing_index"] = 1
	GameState.quest_progress["campaign"] = campaign_state
	_runtime_check("campaign_choice_fixture_banks_prior_outing", first_outing.get("actions", []).size() > 0 and action_results.size() >= first_outing.get("actions", []).size() and int(campaign_state.get("outing_index", -1)) == 1, "quest=%s prior_outing=%s actions=%d" % [quest_id, String(first_outing.get("id", "")), action_results.size()])
	await _remove_active_scene()
	GameState.current_scene_id = "wasteland"
	GameState.current_route_id = String(quest.get("route", "scrap_highway"))
	GameState.seed = REVIEW_SEED
	_active_scene = WASTELAND_SCENE.instantiate()
	add_child(_active_scene)
	await _wait_for_render()
	_sync_map_context("wasteland")
	var hud := _find_hud()
	var action_id := "ch1b_return_route"
	var action_status := GameState.campaign_action_status(action_id)
	_runtime_check("campaign_choice_fixture_action_is_ready", GameState.campaign_outing().get("id", "") == "ch1b_route_coupling" and action_status == "ready", "outing=%s action_status=%s" % [String(GameState.campaign_outing().get("id", "")), action_status])
	var requested := action_status == "ready" and GameState.request_campaign_choice(action_id)
	await _wait_for_render()
	var state := GameState.campaign_choice_state()
	var panel := hud.get("campaign_choice_panel") as Control if hud != null else null
	var options := hud.get("campaign_choice_options") as Control if hud != null else null
	var first_button := options.find_child("ChooseCampaignOptionButton", true, false) as Button if options != null else null
	_runtime_check("campaign_choice_requested_from_authored_action", requested and String(state.get("action_id", "")) == action_id and panel != null and panel.visible, "requested=%s action=%s visible=%s" % [str(requested), String(state.get("action_id", "")), str(panel != null and panel.visible)])
	_runtime_check("campaign_choice_all_authored_options_are_rendered", options != null and options.get_child_count() == state.get("options", []).size() and options.get_child_count() >= 2 and first_button != null, "options=%d cards=%d" % [state.get("options", []).size(), options.get_child_count() if options != null else 0])
	_runtime_check("campaign_choice_first_option_receives_focus", first_button != null and first_button.has_focus(), "focus_owner=%s" % (str(get_viewport().gui_get_focus_owner().get_path()) if get_viewport().gui_get_focus_owner() != null else "none"))
	_runtime_check("campaign_choice_pauses_world", get_tree().paused, "tree_paused=%s" % str(get_tree().paused))
	_validate_control_bounds("campaign_choice", panel)
	if hud != null:
		await _check_player_input_blocked(hud, "campaign_choice")
		_clear_test_notice(hud)
	await _capture_image("campaign_choice")
	await _capture_resized_modal("campaign_choice_960x768", panel, Vector2i(960, 768))
	SaveManager.default_save_path = previous_save_path

func _capture_resized_modal(capture_name: String, panel: Control, window_size: Vector2i) -> void:
	var return_size := get_window().size
	get_window().size = window_size
	await _wait_for_render()
	_runtime_check("%s_window" % capture_name, get_window().size == window_size, "window=%s expected=%s" % [str(get_window().size), str(window_size)])
	_validate_control_bounds(capture_name, panel)
	await _capture_image(capture_name)
	get_window().size = return_size
	await _wait_for_render()

func _capture_scene_entrance() -> void:
	await _prepare_scene("village", VILLAGE_SCENE)
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	var entrance: Control = SCENE_ENTRANCE.new()
	layer.add_child(entrance)
	var completion_count := [0]
	entrance.connect("finished", func() -> void: completion_count[0] += 1)
	await entrance.call("cover")
	entrance.call("arrive", "南門：廢鐵公路", "灰燼未冷，循折旗車隊尋找遺留物資。")
	await get_tree().create_timer(0.3).timeout
	var title := entrance.get("title_label") as Label
	_runtime_check("scene_entrance_has_authored_title", title != null and title.visible and title.text == "南門：廢鐵公路" and float(entrance.get("reveal")) >= 0.99, "arrival title is visible after the native reveal")
	_validate_control_bounds("scene_entrance", entrance)
	_validate_control_bounds("scene_entrance_title", title)
	var hud := _find_hud()
	if hud != null:
		await _check_player_input_blocked(hud, "scene_entrance")
	await _capture_image("scene_entrance")
	entrance.call("finish")
	entrance.call("finish")
	_runtime_check("scene_entrance_finishes_once", completion_count[0] == 1 and not bool(entrance.get_meta("gameplay_input_blocked")), "completion is idempotent and releases gameplay input")
	layer.queue_free()
	await get_tree().process_frame

func _capture_player_pose(capture_name: String, player: CharacterBody2D, state_value: int) -> void:
	var was_processing := player.is_physics_processing()
	var original_state := int(player.get("state"))
	var original_direction: Vector2 = player.get("last_direction")
	player.set_physics_process(false)
	player.set("last_direction", Vector2.RIGHT)
	player.set("state", state_value)
	player.set("current_animation", "")
	player.call("_update_animation")
	await _wait_for_render()
	await _capture_image(capture_name)
	player.set("state", original_state)
	player.set("last_direction", original_direction)
	player.set("current_animation", "")
	player.call("_update_animation")
	player.set_physics_process(was_processing)

func _capture_wasteland_routes() -> void:
	var first_route := "crystal_scar"
	await _prepare_wasteland(first_route, true)
	var hud := _find_hud()
	if hud == null:
		_failures.append("Wasteland route did not create the expected HUD.")
		return
	var map_panels := get_tree().get_nodes_in_group("minimap_panel")
	if map_panels.is_empty():
		_failures.append("Minimap panel group is missing; full map cannot be captured.")
	else:
		# Keep the in-field radar visible while resizing. The full-map capture below
		# is a separate modal state and must not stand in for this HUD state.
		var previous_window_size := get_window().size
		var minimap := hud.get("minimap_panel") as Control
		get_window().size = REVIEW_SIZE
		await _wait_for_render()
		var minimap_visible_wide := minimap != null and minimap.is_visible_in_tree()
		_runtime_check("field_minimap_visible_at_1280x720", minimap_visible_wide, "visible=%s" % str(minimap_visible_wide))
		_validate_control_bounds("field_minimap_1280x720", minimap)
		get_window().size = NARROW_DESKTOP_SIZE
		await _wait_for_render()
		var minimap_visible_narrow := minimap != null and minimap.is_visible_in_tree()
		_runtime_check("field_minimap_visible_at_800x600", minimap_visible_narrow, "visible=%s" % str(minimap_visible_narrow))
		_validate_control_bounds("field_minimap_800x600", minimap)
		var status_panel := hud.get("status_panel") as Control
		var quest_panel := hud.get("quest_panel") as Control
		var overlaps_corner_hud := minimap != null and status_panel != null and quest_panel != null and (minimap.get_global_rect().intersects(status_panel.get_global_rect()) or minimap.get_global_rect().intersects(quest_panel.get_global_rect()))
		_runtime_check("field_minimap_avoids_corner_hud_at_800x600", not overlaps_corner_hud, "minimap=%s status=%s quest=%s" % [str(minimap.get_global_rect()) if minimap != null else "missing", str(status_panel.get_global_rect()) if status_panel != null else "missing", str(quest_panel.get_global_rect()) if quest_panel != null else "missing"])
		await _capture_image("field_minimap_resize_800x600")
		get_window().size = previous_window_size
		await _wait_for_render()
		hud.call("set_fullscreen_map", true)
		var full_map_panel := hud.get("minimap_panel") as Control
		var full_map_view := hud.get("map_view") as Control
		get_window().size = REVIEW_SIZE
		await _wait_for_render()
		var full_map_visible_wide := full_map_panel != null and full_map_panel.is_visible_in_tree() and full_map_view != null and bool(full_map_view.get("full_screen"))
		_runtime_check("full_map_visible_at_1280x720", full_map_visible_wide, "visible=%s" % str(full_map_visible_wide))
		_validate_control_bounds("full_map_1280x720", full_map_panel)
		_validate_control_bounds("full_map_view_1280x720", full_map_view)
		get_window().size = NARROW_DESKTOP_SIZE
		await _wait_for_render()
		var full_map_visible_narrow := full_map_panel != null and full_map_panel.is_visible_in_tree() and full_map_view != null and bool(full_map_view.get("full_screen"))
		_runtime_check("full_map_visible_at_800x600", full_map_visible_narrow, "visible=%s" % str(full_map_visible_narrow))
		_validate_control_bounds("full_map_800x600", full_map_panel)
		_validate_control_bounds("full_map_view_800x600", full_map_view)
		await _capture_image("full_map_resize_800x600")
		get_window().size = previous_window_size
		await _wait_for_render()
		await _check_notice_suppressed_by_modal(hud, "full_map_hides_global_notice")
		await _wait_for_render()
		await _capture_image("full_map")
		await _check_player_input_blocked(hud, "full_map")
		hud.call("set_fullscreen_map", false)
		_clear_test_notice(hud)
	_validate_full_map_content()
	await _wait_for_render()
	await _capture_image("route_crystal_scar")
	await _capture_boss()
	await _capture_landmark("crystal_spire", "landmark_crystal_spire")

	for route_id: String in ["scrap_highway", "toxic_marsh", "old_factory"]:
		await _prepare_wasteland(route_id, route_id == "old_factory")
		await _wait_for_render()
		await _capture_image("route_%s" % route_id)
		var landmark_id: String = String(DataRegistry.get_wasteland_route(route_id).get("landmark_prop", ""))
		var capture_name: String = "landmark_%s" % landmark_id
		await _capture_landmark(landmark_id, capture_name)
		if route_id == "scrap_highway":
			await _capture_death_recovery(_find_hud(), "death", true)

func _capture_death_recovery(hud: Node, capture_name: String, capture_narrow_resize := false) -> void:
	if hud == null:
		_runtime_check(capture_name + "_panel_visible", false, "wasteland HUD is missing")
		return
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		_runtime_check(capture_name + "_panel_visible", false, "player is missing")
		return
	var player := players[0] as CharacterBody2D
	var saved_hp := GameState.hp
	var saved_death_pending := GameState.death_pending
	var saved_state := int(player.get("state"))
	var saved_velocity := player.velocity
	var saved_physics_processing := player.is_physics_processing()
	GameState.current_scene_id = "wasteland"
	GameState.hp = 0
	GameState.death_pending = true
	player.set_physics_process(false)
	player.velocity = Vector2.ZERO
	player.set("state", 8)
	player.set("current_animation", "")
	player.call("_update_animation")
	hud.call("_refresh")
	hud.call("_refresh_overlay_visibility")
	hud.call("_layout")
	await _wait_for_render()
	var panel := hud.get("death_recovery_panel") as Control
	var status := hud.get("death_recovery_status") as Label
	var retry_button := hud.get("death_retry_button") as Button
	var panel_layout := "missing"
	if panel != null:
		var panel_parent := panel.get_parent() as Control
		var first_child := panel.get_child(0) as Control if panel.get_child_count() > 0 else null
		panel_layout = "visible=%s size=%s minimum=%s combined_min=%s parent_size=%s anchors=(%.2f,%.2f,%.2f,%.2f) offsets=(%s,%s,%s,%s) child_size=%s child_min=%s" % [str(panel.visible), str(panel.size), str(panel.custom_minimum_size), str(panel.get_combined_minimum_size()), str(panel_parent.size if panel_parent != null else Vector2.ZERO), panel.anchor_left, panel.anchor_top, panel.anchor_right, panel.anchor_bottom, str(panel.offset_left), str(panel.offset_top), str(panel.offset_right), str(panel.offset_bottom), str(first_child.size if first_child != null else Vector2.ZERO), str(first_child.get_combined_minimum_size() if first_child != null else Vector2.ZERO)]
	_runtime_check(capture_name + "_panel_visible", panel != null and panel.visible, panel_layout)
	_runtime_check(capture_name + "_explains_recovery", status != null and status.text.contains("本趟材料") and status.text.contains("已入庫"), "status=%s" % (status.text if status != null else "missing"))
	_runtime_check(capture_name + "_retry_action_available", retry_button != null and retry_button.visible and not retry_button.disabled and retry_button.pressed.is_connected(Callable(hud, "_retry_death_recovery")), "button visible=%s enabled=%s" % [str(retry_button != null and retry_button.visible), str(retry_button != null and not retry_button.disabled)])
	if panel != null:
		_validate_control_bounds(capture_name, panel)
	await _check_player_input_blocked(hud, capture_name)
	await _capture_image(capture_name)
	if capture_narrow_resize:
		await _capture_recovery_modal_after_wide_to_narrow(
			"death_resize_800x600",
			panel,
			retry_button,
			get_window().size
		)
	GameState.hp = saved_hp
	GameState.death_pending = saved_death_pending
	player.set("state", saved_state)
	player.velocity = saved_velocity
	player.set("current_animation", "")
	player.call("_update_animation")
	player.set_physics_process(saved_physics_processing)
	hud.call("_refresh")
	hud.call("_refresh_overlay_visibility")
	await get_tree().process_frame

func _capture_recovery_modal_after_wide_to_narrow(capture_name: String, panel: Control, primary_action: Button, return_window_size: Vector2i) -> void:
	var starting_window_size := get_window().size
	get_window().size = REVIEW_SIZE
	await _wait_for_render()
	var wide_window_matches := get_window().size == REVIEW_SIZE
	var wide_focus_owner := get_viewport().gui_get_focus_owner()
	var wide_action_reachable := panel != null and panel.is_visible_in_tree() and primary_action != null and primary_action.is_visible_in_tree() and not primary_action.disabled and panel.get_global_rect().encloses(primary_action.get_global_rect())
	_runtime_check(capture_name + "_wide_state_primary_action_focused", wide_window_matches and wide_action_reachable and wide_focus_owner == primary_action, "starting_window=%s wide_window=%s panel=%s action=%s focus=%s" % [str(starting_window_size), str(get_window().size), str(panel != null and panel.is_visible_in_tree()), str(primary_action != null and primary_action.is_visible_in_tree() and not primary_action.disabled), str(wide_focus_owner.get_path()) if wide_focus_owner != null else "none"])
	get_window().size = NARROW_DESKTOP_SIZE
	await _wait_for_render()
	var narrow_focus_owner := get_viewport().gui_get_focus_owner()
	var narrow_window_matches := get_window().size == NARROW_DESKTOP_SIZE
	var narrow_action_visible := panel != null and primary_action != null and panel.is_visible_in_tree() and primary_action.is_visible_in_tree() and not primary_action.disabled
	var narrow_action_inside_panel := narrow_action_visible and panel.get_global_rect().encloses(primary_action.get_global_rect())
	_runtime_check(capture_name + "_window_is_800x600", narrow_window_matches, "window=%s expected=%s" % [str(get_window().size), str(NARROW_DESKTOP_SIZE)])
	_runtime_check(capture_name + "_primary_action_reachable", narrow_action_inside_panel, "panel=%s action=%s enabled=%s" % [str(panel.get_global_rect()) if panel != null else "missing", str(primary_action.get_global_rect()) if primary_action != null else "missing", str(primary_action != null and not primary_action.disabled)])
	_runtime_check(capture_name + "_primary_action_keeps_focus", narrow_action_visible and narrow_focus_owner == primary_action, "focus=%s action=%s" % [str(narrow_focus_owner.get_path()) if narrow_focus_owner != null else "none", str(primary_action.get_path()) if primary_action != null else "missing"])
	_validate_control_bounds(capture_name, panel)
	await _capture_image(capture_name)
	get_window().size = return_window_size
	await _wait_for_render()
	var restored_focus_owner := get_viewport().gui_get_focus_owner()
	var restored_action_available := panel != null and panel.is_visible_in_tree() and primary_action != null and primary_action.is_visible_in_tree() and not primary_action.disabled
	_runtime_check(capture_name + "_restore_keeps_primary_action_focused", restored_action_available and restored_focus_owner == primary_action, "window=%s focus=%s action=%s" % [str(get_window().size), str(restored_focus_owner.get_path()) if restored_focus_owner != null else "none", str(primary_action.get_path()) if primary_action != null else "missing"])

func _capture_responsive_views() -> void:
	await _remove_active_scene()
	get_tree().paused = false
	get_window().size = RESPONSIVE_SIZE
	await _wait_for_render()
	var responsive_window_size := get_window().size
	_runtime_check("responsive_window_1024x768", responsive_window_size == RESPONSIVE_SIZE, "window=%s" % str(responsive_window_size))

	var previous_save_path := SaveManager.default_save_path
	SaveManager.default_save_path = _qa_save_path("responsive_no_save")
	GameState.reset_new_run(false)
	GameState.current_scene_id = "main"
	var main_scene: Node = MAIN_SCENE.instantiate()
	add_child(main_scene)
	await _wait_for_render()
	_record_title_window_profile("responsive_title", RESPONSIVE_SIZE)
	main_scene.call("_layout_title_screen")
	await _capture_image("main_title_1024x768")
	_validate_panel_bounds("main_title_1024x768", main_scene, "title_panel")
	_validate_title_screen_height(main_scene, "main_title_1024x768")
	var new_game_button := main_scene.get("new_game_button") as Button
	_runtime_check("new_game_1024x768_action_reachable", new_game_button != null and new_game_button.is_visible_in_tree() and not new_game_button.disabled and get_viewport().gui_get_focus_owner() == new_game_button, "new_game_button=%s focus=%s" % [str(new_game_button != null and new_game_button.is_visible_in_tree() and not new_game_button.disabled), str(get_viewport().gui_get_focus_owner().get_path()) if get_viewport().gui_get_focus_owner() != null else "none"])
	await _activate_visual_button(new_game_button)
	await _wait_for_render()
	var intro_panel := main_scene.get("intro_panel") as Control
	_runtime_check("new_game_1024x768_opens_intro", bool(main_scene.get("intro_active")) and intro_panel != null and intro_panel.is_visible_in_tree(), "intro_active=%s panel_visible=%s" % [str(main_scene.get("intro_active")), str(intro_panel != null and intro_panel.is_visible_in_tree())])
	await _capture_image("intro_1024x768")
	_validate_panel_bounds("intro_1024x768", main_scene, "intro_panel")
	AudioManager.stop_voice()
	main_scene.queue_free()
	await get_tree().process_frame
	SaveManager.default_save_path = previous_save_path

	await _prepare_scene("village", VILLAGE_SCENE)
	var village_hud := _find_hud()
	var village_players := get_tree().get_nodes_in_group("player")
	var village_npcs := get_tree().get_nodes_in_group("dialogue_npc")
	if village_hud == null or village_players.is_empty():
		_failures.append("Responsive village captures could not find the HUD or player.")
	else:
		var saved_quest_id := GameState.active_quest_id
		var saved_route_id := GameState.current_route_id
		var saved_quest_progress := GameState.quest_progress.duplicate(true)
		var saved_inventory := GameState.inventory.duplicate(true)
		GameState.active_quest_id = "old_factory_core"
		GameState.current_route_id = String(DataRegistry.get_quest("old_factory_core").get("route", "old_factory"))
		GameState.quest_progress = {"defeat_enemy": 7, "defeat_boss": 0}
		GameState.inventory["mutant_core"] = 1
		village_hud.call("_refresh")
		await _wait_for_render()
		var responsive_quest_label := village_hud.get("quest_label") as Label
		var responsive_quest_text := String(responsive_quest_label.text) if responsive_quest_label != null else ""
		var responsive_quest_name := String(DataRegistry.get_quest("old_factory_core").get("name", ""))
		_runtime_check("quest_guidance_1024x768_is_readable", responsive_quest_label != null and responsive_quest_text.contains(responsive_quest_name) and responsive_quest_text.contains("下一步：") and responsive_quest_text.contains("[J]"), "text=%s" % responsive_quest_text)
		_validate_quest_panel_layout(village_hud, "quest_progress_1024x768")
		await _capture_image("quest_progress_1024x768")
		var responsive_contract_state_matches_wide := GameState.active_quest_id == "old_factory_core" and GameState.current_route_id == String(DataRegistry.get_quest("old_factory_core").get("route", "old_factory")) and int(GameState.quest_progress.get("defeat_enemy", 0)) == 7 and int(GameState.inventory.get("mutant_core", 0)) == 1
		_runtime_check("contract_1024x768_stages_same_active_quest_as_wide", responsive_contract_state_matches_wide, "quest=old_factory_core route=%s progress=%s mutant_core=%s" % [GameState.current_route_id, str(GameState.quest_progress), str(GameState.inventory.get("mutant_core", 0))])
		await _capture_hub_panel(village_hud, "_set_contract_visible", "_set_contract_visible", "contract_panel", "contract_list", "contract_1024x768", true)
		await _capture_contract_resized_narrow(village_hud)
		GameState.active_quest_id = saved_quest_id
		GameState.current_route_id = saved_route_id
		GameState.quest_progress = saved_quest_progress
		GameState.inventory = saved_inventory
		village_hud.call("_refresh")
		await _wait_for_render()
		await _capture_hub_panel(village_hud, "open_workshop", "_set_workshop_visible", "workshop_panel", "workshop_list", "workshop_1024x768", "craft")
		await _capture_hub_panel(village_hud, "_set_terminal_visible", "_set_terminal_visible", "terminal_panel", "terminal_list", "terminal_1024x768", true)
		await _capture_pause_feedback(village_hud, "pause_save_success_1024x768", "已儲存目前狀態；存檔不會提前結算本趟收穫。", true)
		await _capture_pause_feedback(village_hud, "pause_save_failure_1024x768", "存檔失敗；本趟收穫未因此入庫。按 Esc 關閉暫停可查看詳細訊息。", false)
		await _capture_pause_feedback(village_hud, "pause_load_pending_presentation_1024x768", "讀取中…正在進入存檔場景。", true, true)
		await _capture_pause_feedback(village_hud, "pause_load_failure_1024x768", "讀取失敗；目前仍留在暫停選單。按 Esc 關閉暫停可查看詳細訊息。", false)
		village_hud.call("_set_inventory_visible", true)
		await _check_notice_suppressed_by_modal(village_hud, "inventory_1024_hides_global_notice")
		await _wait_for_render()
		await _capture_image("inventory_1024x768")
		_validate_control_bounds("inventory_1024x768", village_hud.get("inventory_panel") as Control)
		_validate_inventory_layout(village_hud, true, "inventory_1024x768")
		get_window().size = Vector2i(960, 768)
		await _wait_for_render()
		_runtime_check("responsive_window_960x768", get_window().size == Vector2i(960, 768), "window=%s" % str(get_window().size))
		_validate_control_bounds("inventory_resize_960x768", village_hud.get("inventory_panel") as Control)
		var inventory_viewport_width := get_viewport().get_visible_rect().size.x
		var inventory_effective_width := (inventory_viewport_width - 68.0) * float(village_hud.call("_window_scale_x"))
		_runtime_check("inventory_resize_960x768_crosses_stacked_breakpoint", inventory_effective_width < 940.0, "effective_width=%.1f viewport_width=%.1f window=%s" % [inventory_effective_width, inventory_viewport_width, str(get_window().size)])
		await _wait_for_inventory_layout(village_hud, inventory_effective_width >= 940.0)
		_validate_inventory_layout(village_hud, inventory_effective_width >= 940.0, "inventory_resize_960x768")
		await _capture_image("inventory_resize_960x768")
		get_window().size = RESPONSIVE_SIZE
		await _wait_for_render()
		var wide_inventory_viewport_width := get_viewport().get_visible_rect().size.x
		var wide_inventory_effective_width := (wide_inventory_viewport_width - 68.0) * float(village_hud.call("_window_scale_x"))
		await _wait_for_inventory_layout(village_hud, wide_inventory_effective_width >= 940.0)
		_validate_inventory_layout(village_hud, wide_inventory_effective_width >= 940.0, "inventory_resize_back_1024x768")
		village_hud.call("_set_inventory_visible", false)
		_clear_test_notice(village_hud)
		await _capture_world_atlas(village_hud, "world_atlas_1024x768")
		village_hud.call("_set_codex_visible", true)
		await _wait_for_render()
		await _capture_image("story_journal_1024x768")
		_validate_control_bounds("story_journal_1024x768", village_hud.get("codex_panel") as Control)
		_runtime_check("journal_unknown_entries_hide_revelations", not _journal_contains_revelation(village_hud), "fresh game has only location hints")
		village_hud.call("_set_codex_visible", false)
		_runtime_check("closing_journal_resumes_world", not get_tree().paused, "journal releases its own pause")
		if village_npcs.is_empty():
			_failures.append("Responsive dialogue capture could not find a dialogue NPC.")
		else:
			var player := village_players[0] as Node2D
			var npc := village_npcs[0] as Node2D
			player.global_position = npc.global_position + Vector2(48.0, 0.0)
			player.reset_physics_interpolation()
			GameState.player_position = player.global_position
			await _wait_for_render()
			npc.call("interact")
			await _wait_for_render()
			await _check_notice_suppressed_by_modal(village_hud, "dialogue_1024_hides_global_notice")
			await _capture_image("dialogue_1024x768")
			_validate_control_bounds("dialogue_1024x768", village_hud.get("dialogue_panel") as Control)
			_clear_test_notice(village_hud)

	await _prepare_wasteland("crystal_scar", false)
	var map_hud := _find_hud()
	if map_hud == null:
		_failures.append("Responsive full map capture could not find the HUD.")
	else:
		map_hud.call("set_fullscreen_map", true)
		await _wait_for_render()
		await _capture_image("full_map_1024x768")
		_validate_control_bounds("full_map_1024x768", map_hud.get("minimap_panel") as Control)

	await _prepare_wasteland("scrap_highway", false)
	await _capture_death_recovery(_find_hud(), "death_1024x768")

	get_window().size = _review_size
	await _wait_for_render()

func _capture_story_arc() -> void:
	var discoveries: Array[String] = []
	for route_id in DataRegistry.wasteland_route_ids():
		await _prepare_wasteland(String(route_id), false)
		if String(route_id) in ["ruined_metropolis", "underground_facility"]:
			GameState.completed_quests.assign(["clear_scrap_route", "toxic_sample", "crystal_scar_recon", "old_factory_core"])
		if String(route_id) == "underground_facility":
			GameState.completed_quests.append("metropolis_archive")
		GameState.discovered_events = discoveries.duplicate()
		var site := get_tree().get_first_node_in_group("story_site") as Node2D
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if site == null or player == null:
			_failures.append("Story site/player missing for %s" % route_id)
			continue
		for enemy: Node in get_tree().get_nodes_in_group("enemy"):
			enemy.set_process(false)
			enemy.set_physics_process(false)
		player.set_physics_process(false)
		player.global_position = site.global_position + Vector2(0, 74)
		player.reset_physics_interpolation()
		GameState.player_position = player.global_position
		var camera := player.get_node_or_null("Camera2D") as Camera2D
		if camera != null:
			camera.reset_smoothing()
			camera.force_update_scroll()
		await get_tree().physics_frame
		await get_tree().physics_frame
		var site_hud := _find_hud()
		if site_hud != null:
			_clear_test_notice(site_hud)
		await _wait_for_render()
		var landmark_id := String(DataRegistry.get_wasteland_route(String(route_id)).get("landmark_prop", ""))
		var landmark_visible := false
		var landmark_details := "landmark node missing"
		for prop in get_tree().get_nodes_in_group("world_prop"):
			if str(prop.get("prop_id")) == landmark_id and prop.has_method("get_visual_bounds"):
				var bounds: Rect2 = prop.call("get_visual_bounds")
				var screen_bounds: Rect2 = get_viewport().get_canvas_transform() * bounds
				landmark_visible = Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size).encloses(screen_bounds)
				landmark_details = "visual_bounds=%s" % str(screen_bounds)
				break
		_runtime_check("story_landmark_%s_fully_in_view" % route_id, landmark_visible, landmark_details)
		await _capture_image("story_site_%s" % route_id)
		if String(route_id) in ["ruined_metropolis", "underground_facility"]:
			await _capture_image("route_%s" % route_id)
		var interaction: Node
		for child in site.get_children():
			if child is Area2D and child.has_method("interact"):
				interaction = child
				break
		var story_events := DataRegistry.story_events_for_route(String(route_id))
		if interaction == null or story_events.size() != 1:
			_failures.append("Story site has no unique interaction for %s" % route_id)
			continue
		interaction.call("interact")
		await _wait_for_render()
		var event_id := String(story_events[0].get("id", ""))
		_runtime_check("story_site_%s_discovery" % route_id, GameState.has_story_discovery(String(route_id), event_id), "reachable site interaction records exact route event")
		discoveries = GameState.discovered_events.duplicate()
		var hud := _find_hud()
		if String(route_id) == "scrap_highway" and hud != null:
			await _capture_image("story_discovery")
			_runtime_check("story_dialogue_pauses_combat", get_tree().paused, "reading evidence owns a temporary tree pause")
			await _check_player_input_blocked(hud, "story_dialogue")
		if hud != null:
			hud.call("_hide_dialogue")
	var hud := _find_hud()
	if hud == null:
		return
	hud.call("_set_codex_visible", true)
	await _wait_for_render()
	await _capture_image("story_journal")
	_runtime_check("journal_pauses_combat", get_tree().paused, "journal reading pauses the world until closed")
	_validate_control_bounds("story_journal", hud.get("codex_panel") as Control)
	_runtime_check("journal_has_six_discovered_entries", discoveries.size() == 6 and _journal_revelation_count(hud) == 6, GameState.get_story_summary())
	await _check_player_input_blocked(hud, "story_journal")
	await _prepare_scene("village", VILLAGE_SCENE)
	GameState.discovered_events = discoveries.duplicate()
	GameState.completed_quests.assign(["clear_scrap_route", "toxic_sample", "crystal_scar_recon", "old_factory_core", "metropolis_archive"])
	GameState.active_quest_id = "facility_memory"
	GameState.quest_progress = {"defeat_boss": 1}
	for objective in DataRegistry.get_quest("facility_memory").get("objectives", []):
		if String(objective.get("type", "")) == "collect":
			GameState.add_item(String(objective.get("item", "")), int(objective.get("amount", 1)))
	var completed := GameState.complete_active_quest()
	await _wait_for_render()
	hud = _find_hud()
	_runtime_check("ending_completion_shows_authored_payoff", completed and hud != null and (hud.get("dialogue_panel") as Control).visible, "final quest completion emits authored dialogue")
	await _capture_image("story_ending")
	if hud != null:
		hud.call("_hide_dialogue")

func _journal_contains_revelation(hud: Node) -> bool:
	return _journal_revelation_count(hud) > 0

func _journal_revelation_count(hud: Node) -> int:
	var list := hud.get("codex_list") as Control
	if list == null:
		return 0
	var found := 0
	for event in DataRegistry.events:
		if not bool(event.get("story", false)):
			continue
		var card := list.get_node_or_null("StoryEntry_%s" % String(event.get("id", "")))
		if card != null:
			for child in card.get_children():
				if child is Label and not String(event.get("revelation", "")).is_empty() and child.text.contains(String(event.get("revelation", ""))):
					found += 1
	return found

func _prepare_scene(scene_id: String, packed_scene: PackedScene) -> void:
	await _remove_active_scene()
	get_tree().paused = false
	GameState.reset_new_run(false)
	GameState.current_scene_id = scene_id
	GameState.seed = REVIEW_SEED
	_active_scene = packed_scene.instantiate()
	add_child(_active_scene)
	await _wait_for_render()
	_sync_map_context(scene_id)

func _prepare_wasteland(route_id: String, enable_boss: bool) -> void:
	await _remove_active_scene()
	get_tree().paused = false
	GameState.reset_new_run(false)
	GameState.current_scene_id = "wasteland"
	GameState.current_route_id = route_id
	GameState.seed = REVIEW_SEED
	var boss_threshold := int(DataRegistry.map_params.get("boss_spawn_after_defeats", 40))
	GameState.defeated_enemies = boss_threshold + 1 if enable_boss else 0
	if enable_boss:
		_boss_defeat_setup = {"route_id": route_id, "required_threshold": boss_threshold, "defeated_enemies": GameState.defeated_enemies}
	_active_scene = WASTELAND_SCENE.instantiate()
	add_child(_active_scene)
	await _wait_for_render()
	_sync_map_context("wasteland")
	if enable_boss and get_tree().get_nodes_in_group("boss").is_empty():
		_failures.append("Deterministic boss setup failed for route %s at defeated_enemies=%d above threshold %d." % [route_id, GameState.defeated_enemies, boss_threshold])

func _capture_boss() -> void:
	var bosses := get_tree().get_nodes_in_group("boss")
	var players := get_tree().get_nodes_in_group("player")
	if bosses.is_empty() or players.is_empty():
		_failures.append("Boss capture needs a spawned boss and player.")
		return
	var boss := bosses[0] as Node2D
	var player := players[0] as Node2D
	player.global_position = boss.global_position + Vector2(180.0, 100.0)
	player.reset_physics_interpolation()
	GameState.player_position = player.global_position
	player.set_physics_process(false)
	for node: Node in get_tree().get_nodes_in_group("enemy"):
		node.set_process(false)
		node.set_physics_process(false)
	await _wait_for_render()
	await _capture_image("boss")

func _capture_landmark(prop_id: String, capture_name: String) -> void:
	var props := get_tree().get_nodes_in_group("world_prop")
	var landmark: Node2D
	for candidate: Node in props:
		if candidate is Node2D and String(candidate.get("prop_id")) == prop_id:
			landmark = candidate as Node2D
			break
	var players := get_tree().get_nodes_in_group("player")
	if landmark == null or players.is_empty():
		_failures.append("Landmark close-up %s could not find prop '%s' or the player." % [capture_name, prop_id])
		return
	var player := players[0] as Node2D
	var original_position: Vector2 = player.global_position
	var was_processing: bool = player.is_processing()
	var was_physics_processing: bool = player.is_physics_processing()
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	var original_zoom: Vector2 = camera.zoom if camera != null else Vector2.ONE
	var enemy_processing: Array[Dictionary] = []
	for enemy: Node in get_tree().get_nodes_in_group("enemy"):
		enemy_processing.append({"node": enemy, "process": enemy.is_processing(), "physics": enemy.is_physics_processing()})
		enemy.set_process(false)
		enemy.set_physics_process(false)
	player.set_process(false)
	player.set_physics_process(false)
	var collision_bounds: Rect2 = landmark.call("get_collision_bounds") if landmark.has_method("get_collision_bounds") else Rect2(landmark.global_position - Vector2(48.0, 24.0), Vector2(96.0, 48.0))
	player.global_position = Vector2(collision_bounds.end.x + 56.0, landmark.global_position.y + 12.0)
	player.reset_physics_interpolation()
	GameState.player_position = player.global_position
	if camera != null:
		camera.zoom = Vector2(1.35, 1.35)
		camera.force_update_scroll()
	await _wait_for_render()
	await _capture_image(capture_name)
	player.global_position = original_position
	player.reset_physics_interpolation()
	GameState.player_position = original_position
	player.set_process(was_processing)
	player.set_physics_process(was_physics_processing)
	if camera != null:
		camera.zoom = original_zoom
		camera.force_update_scroll()
	for state: Dictionary in enemy_processing:
		var enemy := state.get("node") as Node
		if enemy != null and is_instance_valid(enemy):
			enemy.set_process(bool(state.get("process", true)))
			enemy.set_physics_process(bool(state.get("physics", true)))

func _sync_map_context(scene_id: String) -> void:
	if _active_scene != null and _active_scene.has_meta("map_world_size"):
		set_meta("map_world_size", _active_scene.get_meta("map_world_size"))
	else:
		set_meta("map_world_size", _review_size)
	if _active_scene != null and _active_scene.has_meta("map_scene_label"):
		set_meta("map_scene_label", _active_scene.get_meta("map_scene_label"))
	else:
		var label := "村莊" if scene_id == "village" else "冒險公會" if scene_id == "guild" else "廢土" if scene_id == "wasteland" else "主選單"
		set_meta("map_scene_label", label)

func _find_hud() -> Node:
	var panels := get_tree().get_nodes_in_group("equipment_panel")
	if panels.is_empty():
		return null
	var hud_root := panels[0].get_parent()
	if hud_root == null:
		return null
	return hud_root.get_parent()

func _validate_hud_groups() -> void:
	var expectations := {
		"hotbar_slot": 4,
		"minimap_panel": 1,
		"tutorial_panel": 1,
		"equipment_panel": 1,
		"dialogue_panel": 1
	}
	for group_name: String in expectations:
		var actual := get_tree().get_nodes_in_group(group_name).size()
		var expected := int(expectations[group_name])
		if actual < expected:
			_failures.append("HUD group %s has %d nodes; expected at least %d." % [group_name, actual, expected])
	var touch_controls := get_tree().get_nodes_in_group("touch_control")
	if not touch_controls.is_empty():
		_failures.append("PC HUD unexpectedly contains %d touch controls." % touch_controls.size())
	var slots := get_tree().get_nodes_in_group("hotbar_slot")
	var seen_slots: Dictionary = {}
	for slot: Node in slots:
		if slot.has_meta("quick_slot_index"):
			seen_slots[int(slot.get_meta("quick_slot_index"))] = true
	if seen_slots.size() < 4:
		_failures.append("HUD hotbar slots do not expose all four quick_slot_index values.")

func _validate_full_map_content() -> void:
	if get_tree().get_nodes_in_group("map_pickup").is_empty():
		_failures.append("Full map has no map_pickup markers.")
	if get_tree().get_nodes_in_group("map_enemy").is_empty():
		_failures.append("Full map has no map_enemy markers.")

func _run_nearest_interaction_check(_hud: Node) -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty() or _active_scene == null:
		_runtime_check("E_uses_nearest_eligible_interactable", false, "player or village scene missing")
		return
	var player := players[0] as Node2D
	var original_position := player.global_position
	var existing_interactables := get_tree().get_nodes_in_group("interactable")
	for candidate: Node in existing_interactables:
		candidate.remove_from_group("interactable")

	var interactable_script: Script = load("res://scripts/components/Interactable.gd")
	var near: Node = interactable_script.new()
	near.set("interaction_id", "visual_nearest")
	_active_scene.add_child(near)
	near.global_position = original_position + Vector2(24.0, 0.0)
	var far: Node = interactable_script.new()
	far.set("interaction_id", "visual_farther")
	_active_scene.add_child(far)
	far.global_position = original_position + Vector2(62.0, 0.0)
	await get_tree().process_frame
	near.set("_player_near", true)
	far.set("_player_near", true)
	var fired: Array[String] = []
	near.connect("interacted", func(interaction_id: String) -> void: fired.append(interaction_id))
	far.connect("interacted", func(interaction_id: String) -> void: fired.append(interaction_id))
	player.call("_interact_with_nearest_target", false)
	_runtime_check("E_uses_nearest_eligible_interactable", fired.size() == 1 and fired[0] == "visual_nearest", "interacted=%s" % str(fired))
	player.global_position = original_position
	player.reset_physics_interpolation()
	near.queue_free()
	far.queue_free()
	for candidate: Node in existing_interactables:
		if is_instance_valid(candidate):
			candidate.add_to_group("interactable")
	await get_tree().process_frame

func _check_hidden_inventory_refresh(hud: Node) -> void:
	hud.call("_set_inventory_visible", true)
	await _wait_for_render()
	hud.call("_set_inventory_visible", false)
	await get_tree().process_frame
	var inventory_list := hud.get("inventory_list") as VBoxContainer
	if inventory_list == null:
		_runtime_check("hidden_inventory_does_not_rebuild", false, "inventory list missing")
		return
	var children_before: Array[int] = []
	for child: Node in inventory_list.get_children():
		children_before.append(child.get_instance_id())
	var ammo_before := GameState.ammo
	var consumed := GameState.spend_ammo(1)
	if consumed:
		GameState.add_item("ammo", 1)
	var children_after: Array[int] = []
	for child: Node in inventory_list.get_children():
		children_after.append(child.get_instance_id())
	_runtime_check("hidden_inventory_does_not_rebuild", consumed and children_after == children_before, "ammo_before=%d child_ids_unchanged=%s" % [ammo_before, str(children_after == children_before)])
	hud.call("_set_inventory_visible", true)
	await _wait_for_render()
	_runtime_check("inventory_open_refreshes_latest_ammo", _node_contains_text(inventory_list, "彈藥 x%d" % GameState.ammo), "ammo=%d" % GameState.ammo)
	hud.call("_set_inventory_visible", false)

func _node_contains_text(node: Node, expected: String) -> bool:
	if node is Label and (node as Label).text.contains(expected):
		return true
	if node is Button and (node as Button).text.contains(expected):
		return true
	for child: Node in node.get_children():
		if _node_contains_text(child, expected):
			return true
	return false

func _check_player_input_blocked(hud: Node, blocker_name: String) -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		_runtime_check("%s_blocks_gameplay_input" % blocker_name, false, "player missing")
		return
	var player := players[0] as CharacterBody2D
	var blocked := bool(player.call("_is_gameplay_input_blocked"))
	_runtime_check("%s_is_registered_as_input_blocker" % blocker_name, blocked, "gameplay_input_blocked=%s" % str(blocked))

	var original_position := player.global_position
	var original_velocity := player.velocity
	var original_state := int(player.get("state"))
	var original_attack_timer := float(player.get("attack_timer"))
	var original_ranged_timer := float(player.get("ranged_timer"))
	var original_action_timer := float(player.get("action_state_timer"))
	var original_ammo := GameState.ammo
	player.velocity = Vector2.ZERO
	player.set("attack_timer", 0.0)
	player.set("ranged_timer", 0.0)
	player.set("action_state_timer", 0.0)
	Input.action_press("move_right")
	Input.action_press("primary_attack")
	player.call("_physics_process", 0.1)
	Input.action_release("move_right")
	Input.action_release("primary_attack")
	var movement_blocked := player.global_position.is_equal_approx(original_position) and player.velocity.is_zero_approx()
	var combat_blocked := is_zero_approx(float(player.get("attack_timer"))) and is_zero_approx(float(player.get("ranged_timer"))) and GameState.ammo == original_ammo
	_runtime_check("%s_blocks_movement" % blocker_name, movement_blocked, "position=%s velocity=%s" % [str(player.global_position), str(player.velocity)])
	_runtime_check("%s_blocks_attacks" % blocker_name, combat_blocked, "attack_timer=%s ranged_timer=%s ammo=%d" % [str(player.get("attack_timer")), str(player.get("ranged_timer")), GameState.ammo])
	player.global_position = original_position
	player.reset_physics_interpolation()
	player.velocity = original_velocity
	player.set("state", original_state)
	player.set("attack_timer", original_attack_timer)
	player.set("ranged_timer", original_ranged_timer)
	player.set("action_state_timer", original_action_timer)
	GameState.ammo = original_ammo
	await get_tree().process_frame

func _validate_panel_bounds(check_name: String, scene: Node, property_name: String) -> void:
	var panel := scene.get(property_name) as Control
	if panel == null:
		_runtime_check("%s_panel_in_viewport" % check_name, false, "%s is missing" % property_name)
		return
	_validate_control_bounds(check_name, panel)

func _check_notice_suppressed_by_modal(hud: Node, check_name: String) -> void:
	var notice_label := hud.get("notice_label") as Control
	hud.call("_show_notice", "測試提示不可覆蓋面板")
	await _wait_for_render()
	_runtime_check(check_name, notice_label != null and not notice_label.visible, "visible=%s" % str(notice_label != null and notice_label.visible))

func _clear_test_notice(hud: Node) -> void:
	var notice_timer := hud.get("notice_timer") as Timer
	if notice_timer != null:
		notice_timer.stop()
	var notice_label := hud.get("notice_label") as Control
	if notice_label != null:
		notice_label.visible = false

func _validate_control_bounds(check_name: String, panel: Control) -> void:
	if panel == null:
		_runtime_check("%s_panel_in_viewport" % check_name, false, "control is missing")
		return
	var panel_rect := panel.get_global_rect()
	var viewport_size := get_viewport().get_visible_rect().size
	var output_image := get_viewport().get_texture().get_image()
	var output_size := Vector2(output_image.get_width(), output_image.get_height())
	var render_scale := output_size / viewport_size
	var output_rect := Rect2(panel_rect.position * render_scale, panel_rect.size * render_scale)
	var image_bounds := Rect2(Vector2.ZERO, output_size)
	_runtime_check("%s_panel_in_viewport" % check_name, image_bounds.encloses(output_rect), "panel=%s output_panel=%s image=%s content_viewport=%s" % [str(panel_rect), str(output_rect), str(image_bounds), str(viewport_size)])

func _validate_quest_panel_layout(hud: Node, check_name: String) -> void:
	var quest_panel := hud.get("quest_panel") as Control
	var status_panel := hud.get("status_panel") as Control
	_validate_control_bounds(check_name, quest_panel)
	var overlaps_status := quest_panel != null and status_panel != null and quest_panel.get_global_rect().intersects(status_panel.get_global_rect())
	_runtime_check("%s_quest_panel_avoids_status" % check_name, quest_panel != null and status_panel != null and not overlaps_status, "quest=%s status=%s" % [str(quest_panel.get_global_rect()) if quest_panel != null else "missing", str(status_panel.get_global_rect()) if status_panel != null else "missing"])

func _validate_title_screen_height(scene: Node, check_name: String) -> void:
	var panel := scene.get("title_panel") as Control
	var expected_max := minf(440.0, get_viewport().get_visible_rect().size.y - 48.0)
	_runtime_check("%s_compact_panel_height" % check_name, panel != null and panel.size.y <= expected_max + 1.0, "height=%.1f max=%.1f" % [panel.size.y if panel != null else 0.0, expected_max])

func _record_title_window_profile(profile_name: String, expected_physical_size: Vector2i) -> void:
	var physical_size := get_window().size
	var logical_size := get_viewport().get_visible_rect().size
	_window_profiles.append({
		"name": profile_name,
		"physical_window": {"width": physical_size.x, "height": physical_size.y},
		"logical_viewport": {"width": logical_size.x, "height": logical_size.y}
	})
	_runtime_check("%s_physical_window_matches" % profile_name, physical_size == expected_physical_size, "physical_window=%s expected=%s logical_viewport=%s" % [str(physical_size), str(expected_physical_size), str(logical_size)])
	_runtime_check("%s_logical_viewport_measured" % profile_name, logical_size.x > 0.0 and logical_size.y > 0.0, "logical_viewport=%s physical_window=%s" % [str(logical_size), str(physical_size)])

func _validate_pause_panel_height(panel: Control, check_name: String) -> void:
	var expected_max := minf(440.0, get_viewport().get_visible_rect().size.y - 48.0)
	_runtime_check("%s_compact_panel_height" % check_name, panel != null and panel.size.y <= expected_max + 1.0, "height=%.1f max=%.1f" % [panel.size.y if panel != null else 0.0, expected_max])

func _review_check_name(prefix: String) -> String:
	return "%s_%dx%d" % [prefix, _review_size.x, _review_size.y]

func _validate_inventory_layout(hud: Node, expected_horizontal: bool, check_name: String) -> void:
	var panel := hud.get("inventory_panel") as Control
	var profile := panel.find_child("InventoryProfileCard", true, false) as Control if panel != null else null
	var equipment := panel.find_child("InventoryEquipmentList", true, false) as Control if panel != null else null
	var row := _inventory_equipment_row(panel)
	var navigation := panel.find_child("ModalNavigation", true, false) as Control if panel != null else null
	var scroll := panel.find_child("InventoryScroll", true, false) as ScrollContainer if panel != null else null
	var inventory_list := hud.get("inventory_list") as Control
	var is_horizontal := row is HBoxContainer
	var viewport_width := get_viewport().get_visible_rect().size.x
	var effective_width := (viewport_width - 68.0) * float(hud.call("_window_scale_x"))
	var layout_matches := row != null and (is_horizontal == expected_horizontal)
	var inventory_child_names := PackedStringArray()
	if inventory_list != null:
		for child: Node in inventory_list.get_children():
			inventory_child_names.append("%s:%s" % [child.name, child.get_class()])
	_runtime_check("%s_layout_matches_available_width" % check_name, layout_matches, "row_exists=%s expected_horizontal=%s actual_horizontal=%s inventory_children=%s viewport_width=%.1f effective_width=%.1f window=%s" % [str(row != null), str(expected_horizontal), str(is_horizontal), str(inventory_child_names), viewport_width, effective_width, str(get_window().size)])
	var overlaps := profile != null and equipment != null and profile.get_global_rect().intersects(equipment.get_global_rect())
	_runtime_check("%s_profile_and_equipment_do_not_overlap" % check_name, profile != null and equipment != null and not overlaps, "profile=%s equipment=%s" % [str(profile.get_global_rect()) if profile != null else "missing", str(equipment.get_global_rect()) if equipment != null else "missing"])
	var navigation_fits := false
	if panel != null and navigation != null and navigation.get_child_count() > 0:
		var close_button := navigation.get_child(navigation.get_child_count() - 1) as Control
		navigation_fits = panel.get_global_rect().grow(-4.0).encloses(navigation.get_global_rect()) and close_button != null and panel.get_global_rect().grow(-4.0).encloses(close_button.get_global_rect())
	_runtime_check("%s_navigation_and_close_fit_modal" % check_name, navigation_fits, "panel=%s navigation=%s" % [str(panel.get_global_rect()) if panel != null else "missing", str(navigation.get_global_rect()) if navigation != null else "missing"])
	var content_fits := scroll != null and inventory_list != null
	if content_fits:
		var visible_rect := scroll.get_global_rect()
		for child: Node in inventory_list.get_children():
			if child is Control and (child as Control).visible:
				var child_rect := (child as Control).get_global_rect()
				if child_rect.position.x < visible_rect.position.x - 1.0 or child_rect.end.x > visible_rect.end.x + 1.0:
					content_fits = false
					break
	_runtime_check("%s_inventory_rows_fit_scroll_width" % check_name, content_fits, "scroll=%s list=%s" % [str(scroll.get_global_rect()) if scroll != null else "missing", str(inventory_list.get_global_rect()) if inventory_list != null else "missing"])

func _inventory_equipment_row(panel: Control) -> BoxContainer:
	if panel == null:
		return null
	var profile := panel.find_child("InventoryProfileCard", true, false) as Control
	var equipment := panel.find_child("InventoryEquipmentList", true, false) as Control
	if profile == null or equipment == null:
		return null
	var row := profile.get_parent() as BoxContainer
	if row == null or equipment.get_parent() != row:
		return null
	return row

func _wait_for_inventory_layout(hud: Node, expected_horizontal: bool) -> void:
	for _attempt in range(8):
		await get_tree().process_frame
		var panel := hud.get("inventory_panel") as Control
		var row := _inventory_equipment_row(panel)
		if row != null and (row is HBoxContainer) == expected_horizontal:
			await RenderingServer.frame_post_draw
			return
	await RenderingServer.frame_post_draw

func _capture_hub_panel(hud: Node, open_method: String, close_method: String, panel_property: String, list_property: String, capture_name: String, open_argument: Variant) -> void:
	hud.call(open_method, open_argument)
	await _wait_for_render()
	var panel := hud.get(panel_property) as Control
	var content := hud.get(list_property) as Control
	_runtime_check("%s_screen_visible" % capture_name, panel != null and panel.visible, "visible=%s" % str(panel != null and panel.visible))
	_runtime_check("%s_screen_populated" % capture_name, content != null and content.get_child_count() > 0, "rows=%d" % (content.get_child_count() if content != null else 0))
	if panel != null and capture_name.begins_with("contract"):
		_validate_contract_task_readability(panel, capture_name)
		_validate_contract_initial_view(panel, "%s_initial_view" % capture_name)
	_assert_initial_modal_focus(hud, panel_property, capture_name + "_first_open")
	_validate_control_bounds(capture_name, panel)
	if capture_name.begins_with("terminal") and content != null:
		var locked_grid := content.get_node_or_null("TerminalLockedGrid") as GridContainer
		if locked_grid != null:
			var grid_width := locked_grid.get_global_rect().size.x
			var recipe_box := locked_grid.get_child(0) as Control if locked_grid.get_child_count() > 0 else null
			var journey_box := locked_grid.get_child(1) as Control if locked_grid.get_child_count() > 1 else null
			var recipe_width := recipe_box.get_global_rect().size.x if recipe_box != null else 0.0
			var journey_width := journey_box.get_global_rect().size.x if journey_box != null else 0.0
			var cards_fill_grid := recipe_width >= grid_width * 0.40 and journey_width >= grid_width * 0.40 and absf(recipe_width - journey_width) <= maxf(18.0, grid_width * 0.08)
			_runtime_check("%s_locked_cards_fill_modal" % capture_name, grid_width >= panel.get_global_rect().size.x * 0.80 and cards_fill_grid, "grid=%.1f recipe=%.1f journey=%.1f panel=%.1f" % [grid_width, recipe_width, journey_width, panel.get_global_rect().size.x])
			if capture_name == "terminal":
				var original_window_size := get_window().size
				var original_columns := locked_grid.columns
				get_window().size = NARROW_DESKTOP_SIZE
				await _wait_for_render()
				locked_grid = content.get_node_or_null("TerminalLockedGrid") as GridContainer
				_runtime_check("terminal_locked_grid_reflows_at_800x600", locked_grid != null and locked_grid.columns == 1, "window=%s columns=%d" % [str(get_window().size), locked_grid.columns if locked_grid != null else 0])
				_validate_control_bounds("terminal_locked_resize_800x600", panel)
				await _capture_image("terminal_locked_resize_800x600")
				get_window().size = original_window_size
				await _wait_for_render()
				locked_grid = content.get_node_or_null("TerminalLockedGrid") as GridContainer
				_runtime_check("terminal_locked_grid_restores_initial_columns", locked_grid != null and locked_grid.columns == original_columns, "window=%s columns=%d initial=%d" % [str(get_window().size), locked_grid.columns if locked_grid != null else 0, original_columns])
			var duplicate_journey := false
			for child: Node in content.get_children():
				if child != locked_grid and _node_contains_text(child, "目前旅程"):
					duplicate_journey = true
			_runtime_check("%s_has_single_journey_summary" % capture_name, not duplicate_journey, "locked terminal keeps its journey summary in the two-column card only")
	if capture_name.begins_with("contract") and panel != null:
		var scroll := panel.find_child("ContractScroll", true, false) as ScrollContainer
		var maximum := int(scroll.get_v_scroll_bar().max_value - scroll.get_v_scroll_bar().page) if scroll != null else 0
		if maximum > 0:
			var starting_scroll := scroll.scroll_vertical
			if capture_name == "contract":
				scroll.scroll_vertical = 0
				await _wait_for_render()
				var wheel_start := scroll.scroll_vertical
				var wheel_event := InputEventMouseButton.new()
				wheel_event.position = scroll.get_global_rect().get_center()
				wheel_event.button_index = MOUSE_BUTTON_WHEEL_DOWN
				wheel_event.factor = 1.0
				wheel_event.pressed = true
				Input.parse_input_event(wheel_event)
				await get_tree().process_frame
				var wheel_end := scroll.scroll_vertical
				_runtime_check("contract_mouse_wheel_scrolls_catalog", wheel_end > wheel_start, "before=%d after=%d maximum=%d" % [wheel_start, wheel_end, maximum])
				scroll.scroll_vertical = starting_scroll
				await _wait_for_render()
			await _tap_visual_key(KEY_PAGEDOWN)
			_runtime_check("%s_page_down_scrolls_catalog" % capture_name, scroll.scroll_vertical > starting_scroll, "before=%d after=%d maximum=%d" % [starting_scroll, scroll.scroll_vertical, maximum])
			scroll.scroll_vertical = starting_scroll
			await _wait_for_render()
		elif capture_name == "contract":
			_runtime_check("contract_mouse_wheel_scrolls_catalog", false, "ContractScroll is missing or has no overflowing catalog content; scroll=%s maximum=%d" % [str(scroll != null), maximum])
	await _capture_image(capture_name)
	hud.call(close_method, false)

func _assert_initial_modal_focus(hud: Node, panel_property: String, check_name: String) -> void:
	var panel := hud.get(panel_property) as Control
	var focus_owner := get_viewport().gui_get_focus_owner()
	var focus_is_inside := panel != null and focus_owner != null and panel.is_ancestor_of(focus_owner) and focus_owner.is_visible_in_tree()
	_runtime_check("%s_focus_is_inside_visible_panel" % check_name, focus_is_inside, "panel=%s focus=%s" % [panel_property, str(focus_owner.get_path()) if focus_owner != null else "none"])

func _validate_contract_task_readability(panel: Control, check_name: String) -> void:
	var task_text := panel.find_child("ContractRequirements", true, false) as Control
	var catalogue_group: Control
	for group_name: String in ["Available", "Waiting", "Completed", "Locked"]:
		catalogue_group = panel.find_child("ContractCatalogGroup_%s" % group_name, true, false) as Control
		if catalogue_group != null:
			break
	var physical_scale := float(get_window().size.x) / maxf(1.0, get_viewport().get_visible_rect().size.x)
	var task_font_px := float(task_text.get_theme_font_size("font_size")) * physical_scale if task_text != null else 0.0
	var catalogue_font_px := float(catalogue_group.get_theme_font_size("font_size")) * physical_scale if catalogue_group != null else 0.0
	_runtime_check("%s_task_summary_font_min_12_physical_px" % check_name, task_font_px >= 12.0, "font=%.1f physical px logical_scale=%.3f" % [task_font_px, physical_scale])
	_runtime_check("%s_available_quest_font_min_12_physical_px" % check_name, catalogue_group != null and catalogue_font_px >= 12.0, "font=%.1f physical px group=%s scale=%.3f" % [catalogue_font_px, str(catalogue_group != null), physical_scale])

func _validate_contract_initial_view(panel: Control, check_name: String) -> void:
	var scroll := panel.find_child("ContractScroll", true, false) as ScrollContainer if panel != null else null
	var contract_tab := panel.find_child("ModalTab_contract", true, false) as Button if panel != null else null
	var focus_owner := get_viewport().gui_get_focus_owner()
	var starts_at_top := scroll != null and scroll.scroll_vertical == 0
	var focus_stays_on_fixed_navigation := contract_tab != null and focus_owner == contract_tab
	_runtime_check("%s_scroll_starts_at_top" % check_name, starts_at_top, "scroll=%d" % (scroll.scroll_vertical if scroll != null else -1))
	_runtime_check("%s_focus_stays_on_contract_tab" % check_name, focus_stays_on_fixed_navigation, "focus=%s tab=%s" % [str(focus_owner.get_path()) if focus_owner != null else "none", str(contract_tab.get_path()) if contract_tab != null else "missing"])

func _tap_visual_key(keycode: int) -> void:
	var press := InputEventKey.new()
	press.keycode = keycode
	press.physical_keycode = keycode
	press.pressed = true
	Input.parse_input_event(press)
	await get_tree().process_frame
	var release := InputEventKey.new()
	release.keycode = keycode
	release.physical_keycode = keycode
	release.pressed = false
	Input.parse_input_event(release)
	await get_tree().process_frame

func _activate_visual_button(button: Button) -> void:
	if button == null or not is_instance_valid(button) or not button.is_visible_in_tree() or button.disabled:
		return
	button.grab_focus()
	await get_tree().process_frame
	await _tap_visual_key(KEY_ENTER)

func _complete_intro_to_village(main_scene: Node, check_prefix: String) -> Node:
	var intro_panel := main_scene.get("intro_panel") as Control if is_instance_valid(main_scene) else null
	var focused_control := get_viewport().gui_get_focus_owner()
	var enter_button_focused := intro_panel != null and focused_control is Button and intro_panel.is_ancestor_of(focused_control) and (focused_control as Button).text.begins_with("進入村莊")
	_runtime_check("%s_intro_enter_action_focused" % check_prefix, enter_button_focused, "intro_panel=%s focus=%s" % [str(intro_panel != null), str(focused_control.get_path()) if focused_control != null else "none"])
	if not enter_button_focused:
		return null
	# Keep this runner alive while SceneRouter replaces the actual title scene.
	get_tree().current_scene = null
	main_scene.reparent(get_tree().root)
	get_tree().current_scene = main_scene
	await _tap_visual_key(KEY_ENTER)
	var village_transition_finished := false
	for _frame in range(240):
		await get_tree().process_frame
		var current_scene := get_tree().current_scene
		if GameState.current_scene_id == "village" and current_scene != null and current_scene.scene_file_path == VILLAGE_SCENE.resource_path and not SceneRouter.is_transition_pending() and not SceneRouter.transition_active:
			village_transition_finished = true
			break
	await _wait_for_render()
	var village_scene := get_tree().current_scene
	if village_transition_finished and village_scene != null:
		_active_scene = village_scene
		get_tree().current_scene = self
	var village_hud := _find_hud()
	_runtime_check("%s_reaches_village" % check_prefix, village_transition_finished and village_hud != null, "transition_finished=%s hud=%s" % [str(village_transition_finished), str(village_hud != null)])
	if not village_transition_finished or village_hud == null:
		return null
	await _tap_visual_key(KEY_I)
	await _wait_for_render()
	var inventory_panel := village_hud.get("inventory_panel") as Control
	var inventory_opened := inventory_panel != null and inventory_panel.is_visible_in_tree()
	_runtime_check("%s_village_I_opens_inventory" % check_prefix, inventory_opened, "inventory_panel_visible=%s" % str(inventory_opened))
	if inventory_opened:
		await _tap_visual_key(KEY_ESCAPE)
		await _wait_for_render()
	var inventory_closed := inventory_panel != null and not inventory_panel.is_visible_in_tree()
	_runtime_check("%s_village_Escape_closes_inventory" % check_prefix, inventory_closed, "inventory_panel_visible=%s" % str(inventory_panel != null and inventory_panel.is_visible_in_tree()))
	return village_hud

func _qa_save_path(purpose: String) -> String:
	return _output_dir.path_join("visual_review_%s_%d.json" % [purpose, Time.get_ticks_usec()])

func _capture_contract_resized_narrow(hud: Node) -> void:
	var return_size := get_window().size
	var return_quest_id := GameState.active_quest_id
	GameState.active_quest_id = ""
	hud.call("_refresh")
	hud.call("_set_contract_visible", true)
	await _wait_for_render()
	get_window().size = NARROW_DESKTOP_SIZE
	await _wait_for_render()
	var panel := hud.get("contract_panel") as Control
	var list := hud.get("contract_list") as Control
	var navigation := panel.find_child("ModalNavigation", true, false) as GridContainer if panel != null else null
	var scroll := panel.find_child("ContractScroll", true, false) as ScrollContainer if panel != null else null
	if panel != null:
		_validate_contract_task_readability(panel, "contract_resize_800x600")
	var close_button := panel.find_child("ModalCloseButton", true, false) as Control if panel != null else null
	var expected_columns := 8 if NARROW_DESKTOP_SIZE.x >= 1000 else 4
	var nav_rect := navigation.get_global_rect() if navigation != null else Rect2()
	var panel_rect := panel.get_global_rect() if panel != null else Rect2()
	var close_is_reachable := close_button != null and panel != null and panel_rect.grow(-3.0).encloses(close_button.get_global_rect())
	var close_stays_outside_scroll := close_button != null and scroll != null and not close_button.get_global_rect().intersects(scroll.get_global_rect())
	var physical_scale_x := float(get_window().size.x) / maxf(1.0, get_viewport().get_visible_rect().size.x)
	var nav_buttons_fit := navigation != null and panel != null
	if nav_buttons_fit:
		for child: Node in navigation.get_children():
			if child is Control and not panel_rect.grow(-3.0).encloses((child as Control).get_global_rect()):
				nav_buttons_fit = false
	_runtime_check("contract_resize_800x600_window", get_window().size == NARROW_DESKTOP_SIZE, "window=%s" % str(get_window().size))
	_runtime_check("contract_resize_800x600_navigation_reflows", navigation != null and navigation.columns == expected_columns and panel_rect.grow(-3.0).encloses(nav_rect), "columns=%d expected=%d panel=%s navigation=%s" % [navigation.columns if navigation != null else -1, expected_columns, str(panel_rect), str(nav_rect)])
	_runtime_check("contract_resize_800x600_navigation_buttons_fit", nav_buttons_fit, "panel=%s navigation=%s" % [str(panel_rect), str(nav_rect)])
	_runtime_check("contract_resize_800x600_close_remains_reachable", close_is_reachable and close_stays_outside_scroll, "close=%s scroll=%s" % [str(close_button.get_global_rect()) if close_button != null else "missing", str(scroll.get_global_rect()) if scroll != null else "missing"])
	var catalog_columns_match := list != null
	var expected_catalog_columns := 2 if panel != null and (panel.size.x - 48.0) * physical_scale_x >= 760.0 else 1
	var catalog_grids_checked := 0
	if list != null:
		for child: Node in list.get_children():
			if child is GridContainer and child.name.begins_with("ContractCatalog_"):
				catalog_grids_checked += 1
				if (child as GridContainer).columns != expected_catalog_columns:
					catalog_columns_match = false
	_runtime_check("contract_resize_800x600_catalog_reflows", catalog_columns_match and catalog_grids_checked > 0, "checked_grids=%d expected_columns=%d" % [catalog_grids_checked, expected_catalog_columns])
	_validate_control_bounds("contract_resize_800x600", panel)
	await _capture_image("contract_resize_800x600")
	hud.call("_set_contract_visible", false)
	await _wait_for_render()
	hud.call("_set_contract_visible", true)
	await _wait_for_render()
	_validate_contract_initial_view(panel, "contract_resize_800x600_reopen_initial_view")
	var narrow_open_navigation := panel.find_child("ModalNavigation", true, false) as GridContainer if panel != null else null
	var narrow_open_columns := 2 if panel != null and (panel.size.x - 48.0) * physical_scale_x >= 760.0 else 1
	var narrow_open_grids_checked := 0
	var narrow_open_catalog_matches := list != null
	if list != null:
		for child: Node in list.get_children():
			if child is GridContainer and child.name.begins_with("ContractCatalog_"):
				narrow_open_grids_checked += 1
				if (child as GridContainer).columns != narrow_open_columns:
					narrow_open_catalog_matches = false
	_runtime_check("contract_open_800x600_initial_columns", narrow_open_navigation != null and narrow_open_navigation.columns == 4 and narrow_open_catalog_matches and narrow_open_grids_checked > 0, "navigation=%d catalog_grids=%d expected_catalog=%d" % [narrow_open_navigation.columns if narrow_open_navigation != null else -1, narrow_open_grids_checked, narrow_open_columns])
	_validate_control_bounds("contract_open_800x600", panel)
	await _capture_image("contract_open_800x600")
	var breakpoint_size := Vector2i(960, 600)
	get_window().size = breakpoint_size
	await _wait_for_render()
	var breakpoint_navigation := panel.find_child("ModalNavigation", true, false) as GridContainer if panel != null else null
	var breakpoint_panel_rect := panel.get_global_rect() if panel != null else Rect2()
	var breakpoint_nav_rect := breakpoint_navigation.get_global_rect() if breakpoint_navigation != null else Rect2()
	var breakpoint_buttons_fit := breakpoint_navigation != null and panel != null
	if breakpoint_buttons_fit:
		for child: Node in breakpoint_navigation.get_children():
			if child is Control and not breakpoint_panel_rect.grow(-3.0).encloses((child as Control).get_global_rect()):
				breakpoint_buttons_fit = false
	_runtime_check("contract_resize_960x600_navigation_reflows", breakpoint_navigation != null and breakpoint_navigation.columns == 4 and breakpoint_buttons_fit, "columns=%d panel=%s navigation=%s" % [breakpoint_navigation.columns if breakpoint_navigation != null else -1, str(breakpoint_panel_rect), str(breakpoint_nav_rect)])
	var breakpoint_scale_x := float(get_window().size.x) / maxf(1.0, get_viewport().get_visible_rect().size.x)
	var breakpoint_catalog_columns := 2 if panel != null and (panel.size.x - 48.0) * breakpoint_scale_x >= 760.0 else 1
	var breakpoint_catalog_match := list != null
	var breakpoint_grids_checked := 0
	if list != null:
		for child: Node in list.get_children():
			if child is GridContainer and child.name.begins_with("ContractCatalog_"):
				breakpoint_grids_checked += 1
				if (child as GridContainer).columns != breakpoint_catalog_columns:
					breakpoint_catalog_match = false
	_runtime_check("contract_resize_960x600_catalog_reflows", breakpoint_catalog_match and breakpoint_grids_checked > 0 and breakpoint_catalog_columns == 2, "checked_grids=%d expected_columns=%d" % [breakpoint_grids_checked, breakpoint_catalog_columns])
	_validate_control_bounds("contract_resize_960x600", panel)
	await _capture_image("contract_resize_960x600")
	get_window().size = return_size
	await _wait_for_render()
	var wide_navigation := panel.find_child("ModalNavigation", true, false) as GridContainer if panel != null else null
	_runtime_check("contract_resize_back_1024x768_navigation_reflows", wide_navigation != null and wide_navigation.columns == 8, "columns=%d" % (wide_navigation.columns if wide_navigation != null else -1))
	GameState.active_quest_id = return_quest_id
	hud.call("_refresh")
	hud.call("_set_contract_visible", false)

func _capture_pause_feedback(hud: Node, capture_name: String, message: String, success: bool, pending := false) -> void:
	hud.call("_set_pause_visible", true)
	hud.call("_set_pause_load_state", pending, "", success)
	hud.call("_set_pause_feedback", message, success)
	await _wait_for_render()
	var panel := hud.get("pause_panel") as Control
	var status := hud.get("pause_status_label") as Label
	_runtime_check("%s_feedback_visible" % capture_name, panel != null and panel.visible and status != null and status.visible and status.text == message, "presentation-only message=%s" % (status.text if status != null else "missing"))
	_validate_control_bounds(capture_name, panel)
	_validate_pause_panel_height(panel, capture_name)
	await _capture_image(capture_name)
	hud.call("_set_pause_load_state", false, "", false)
	hud.call("_set_pause_visible", false)

func _runtime_check(check_name: String, passed: bool, detail: String) -> void:
	var result := {"name": check_name, "success": passed, "detail": detail}
	_runtime_checks.append(result)
	if passed:
		print("[VISUAL][CHECK] PASS %s (%s)" % [check_name, detail])
		return
	var message := "%s failed: %s" % [check_name, detail]
	_failures.append(message)
	push_error("[VISUAL][CHECK] " + message)

func _capture_image(capture_name: String) -> void:
	await _wait_for_render()
	var texture: Texture2D = get_viewport().get_texture()
	if texture == null:
		_record_failure(capture_name, "viewport texture is unavailable")
		return
	var image := texture.get_image()
	if image == null or image.is_empty():
		_record_failure(capture_name, "rendered image is empty")
		return
	var image_size := Vector2i(image.get_width(), image.get_height())
	if image_size.x < MIN_CAPTURE_SIZE.x or image_size.y < MIN_CAPTURE_SIZE.y:
		_record_failure(capture_name, "image size %dx%d is below %dx%d" % [image_size.x, image_size.y, MIN_CAPTURE_SIZE.x, MIN_CAPTURE_SIZE.y])
		return
	var sample_colors := _count_sample_colors(image)
	if sample_colors < MIN_SAMPLE_COLORS:
		_record_failure(capture_name, "image has only %d sampled colors; expected at least %d" % [sample_colors, MIN_SAMPLE_COLORS])
		return
	var path := _output_dir.path_join("%s.png" % capture_name)
	var save_error := image.save_png(path)
	if save_error != OK:
		_record_failure(capture_name, "PNG save failed with error %d" % save_error)
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_record_failure(capture_name, "saved PNG could not be reopened")
		return
	var png_bytes := file.get_length()
	file.close()
	if png_bytes < MIN_PNG_BYTES:
		_record_failure(capture_name, "PNG is %d bytes; expected at least %d" % [png_bytes, MIN_PNG_BYTES])
		return
	_records.append({
		"name": capture_name,
		"success": true,
		"path": path,
		"width": image_size.x,
		"height": image_size.y,
		"window_width": get_window().size.x,
		"window_height": get_window().size.y,
		"content_viewport_width": get_viewport().get_visible_rect().size.x,
		"content_viewport_height": get_viewport().get_visible_rect().size.y,
		"png_bytes": png_bytes,
		"sample_colors": sample_colors
	})
	print("[VISUAL] Saved %s (%dx%d, %d bytes, %d sampled colors)" % [path, image_size.x, image_size.y, png_bytes, sample_colors])

func _count_sample_colors(image: Image) -> int:
	var colors: Dictionary = {}
	for y in range(18):
		for x in range(32):
			var point := Vector2i(int((float(x) + 0.5) * image.get_width() / 32.0), int((float(y) + 0.5) * image.get_height() / 18.0))
			colors[image.get_pixel(point.x, point.y).to_rgba32()] = true
	return colors.size()

func _record_failure(capture_name: String, reason: String) -> void:
	var message := "%s: %s" % [capture_name, reason]
	_failures.append(message)
	_records.append({"name": capture_name, "success": false, "reason": reason})
	push_error("[VISUAL] " + message)

func _wait_for_render() -> void:
	for _i in range(2):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

func _remove_active_scene() -> void:
	if _active_scene == null or not is_instance_valid(_active_scene):
		return
	_active_scene.queue_free()
	_active_scene = null
	await get_tree().process_frame
	get_tree().paused = false

func _resolve_output_dir() -> String:
	var requested := "user://visual-review"
	var arguments := OS.get_cmdline_user_args()
	for index in range(arguments.size() - 1):
		if arguments[index] == "--qa-output":
			requested = arguments[index + 1]
			break
	if requested.begins_with("res://") or requested.begins_with("user://"):
		return ProjectSettings.globalize_path(requested)
	if requested.is_absolute_path():
		return requested
	return ProjectSettings.globalize_path("user://" + requested)

func _finish_review() -> void:
	get_tree().paused = false
	AudioManager.stop_all()
	await get_tree().process_frame
	await get_tree().process_frame
	_ensure_required_captures()
	var success_count := 0
	var capture_failure_count := 0
	var runtime_check_success_count := 0
	var runtime_check_failure_count := 0
	for result: Dictionary in _records:
		if bool(result.get("success", false)):
			success_count += 1
		else:
			capture_failure_count += 1
	for check: Dictionary in _runtime_checks:
		if bool(check.get("success", false)):
			runtime_check_success_count += 1
		else:
			runtime_check_failure_count += 1
	var success := _failures.is_empty() and success_count == _required_capture_names.size()
	var first_capture_name := String(_records[0].get("name", "")) if not _records.is_empty() else ""
	var report := {
		"success": success,
		"success_count": success_count,
		"failure_count": capture_failure_count,
		"error_count": _failures.size(),
		"expected_capture_count": _required_capture_names.size(),
		"runtime_check_success_count": runtime_check_success_count,
		"runtime_check_failure_count": runtime_check_failure_count,
		"capture_size": {"width": NARROW_DESKTOP_SIZE.x, "height": NARROW_DESKTOP_SIZE.y} if _cold_narrow_launch else {"width": _review_size.x, "height": _review_size.y},
		"responsive_capture_size": {"width": RESPONSIVE_SIZE.x, "height": RESPONSIVE_SIZE.y},
		"title_window_profiles": _window_profiles,
		"launch_profile": {
			"name": "cold_narrow" if _cold_narrow_launch else ("sized_review" if _review_size_from_args else "standard_review"),
			"cold_start": _cold_narrow_launch or _review_size_from_args,
			"initial_window_width": _launch_window_size.x,
			"initial_window_height": _launch_window_size.y,
			"first_capture": first_capture_name,
			"first_capture_uses_launch_window": _cold_narrow_launch or _review_size_from_args,
			"first_capture_window_override_applied": not _cold_narrow_launch and not _review_size_from_args
		},
		"boss_setup": _boss_defeat_setup,
		"thresholds": {
			"minimum_width": MIN_CAPTURE_SIZE.x,
			"minimum_height": MIN_CAPTURE_SIZE.y,
			"minimum_png_bytes": MIN_PNG_BYTES,
			"minimum_sample_colors": MIN_SAMPLE_COLORS
		},
		"captures": _records,
		"runtime_checks": _runtime_checks,
		"failures": _failures
	}
	var report_path := _output_dir.path_join("visual_review_report.json")
	var report_file := FileAccess.open(report_path, FileAccess.WRITE)
	if report_file == null:
		push_error("[VISUAL] Could not write report: %s" % report_path)
		get_tree().quit(1)
		return
	report_file.store_string(JSON.stringify(report, "\t") + "\n")
	report_file.close()
	print("[VISUAL] success=%s success_count=%d failure_count=%d runtime_checks=%d/%d error_count=%d report=%s" % [success, success_count, capture_failure_count, runtime_check_success_count, _runtime_checks.size(), _failures.size(), report_path])
	if not _original_save_path.is_empty():
		SaveManager.default_save_path = _original_save_path
	get_tree().quit(0 if success else 1)

func _review_size_from_user_args(user_args: PackedStringArray) -> Vector2i:
	for index in range(user_args.size() - 1):
		if user_args[index] != "--qa-review-size":
			continue
		var parts := String(user_args[index + 1]).split("x")
		if parts.size() != 2:
			_failures.append("Invalid --qa-review-size; expected WIDTHxHEIGHT.")
			return REVIEW_SIZE
		var requested := Vector2i(int(parts[0]), int(parts[1]))
		if requested.x < MIN_CAPTURE_SIZE.x or requested.y < MIN_CAPTURE_SIZE.y:
			_failures.append("--qa-review-size is below the minimum screenshot dimensions: %s" % str(requested))
			return REVIEW_SIZE
		return requested
	return REVIEW_SIZE

func _ensure_required_captures() -> void:
	var recorded: Dictionary = {}
	for result: Dictionary in _records:
		recorded[String(result.get("name", ""))] = true
	for capture_name: String in _required_capture_names:
		if not recorded.has(capture_name):
			_record_failure(capture_name, "required visual state was not captured")
