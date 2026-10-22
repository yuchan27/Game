extends Node

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const VILLAGE_SCENE := preload("res://scenes/levels/village/Village.tscn")
const GUILD_SCENE := preload("res://scenes/levels/guild/Guild.tscn")
const WASTELAND_SCENE := preload("res://scenes/levels/wasteland/Wasteland.tscn")

const REVIEW_SIZE := Vector2i(1280, 720)
const RESPONSIVE_SIZE := Vector2i(1024, 768)
const MIN_CAPTURE_SIZE := Vector2i(640, 360)
const MIN_PNG_BYTES := 4096
const MIN_SAMPLE_COLORS := 8
const REVIEW_SEED := 424242
const REQUIRED_CAPTURES := [
	"main_title",
	"continue_load_failure",
	"intro",
	"inventory",
	"tutorial",
	"full_map",
	"dialogue",
	"pause",
	"death",
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
	"guild_hud",
	"player_walk",
	"player_slash",
	"player_shoot",
	"main_title_1024x768",
	"intro_1024x768",
	"inventory_1024x768",
	"dialogue_1024x768",
	"full_map_1024x768"
]

var _output_dir := ""
var _records: Array[Dictionary] = []
var _runtime_checks: Array[Dictionary] = []
var _failures: Array[String] = []
var _active_scene: Node
var _boss_defeat_setup: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	get_window().size = REVIEW_SIZE
	_output_dir = _resolve_output_dir()
	var dir_error := DirAccess.make_dir_recursive_absolute(_output_dir)
	if dir_error != OK:
		_failures.append("Could not create QA output directory: %s (error %d)" % [_output_dir, dir_error])
		await _finish_review()
		return

	var headless := OS.has_feature("headless") or DisplayServer.get_name().to_lower().contains("headless")
	if headless:
		_failures.append("Visual review requires a rendered GUI viewport; this run is headless.")
		for capture_name: String in REQUIRED_CAPTURES:
			_records.append({"name": capture_name, "success": false, "reason": "headless renderer; no screenshot was produced"})
		await _finish_review()
		return

	DataRegistry.load_all()
	print("[VISUAL] Capturing %d review images at %dx%d to %s" % [REQUIRED_CAPTURES.size(), REVIEW_SIZE.x, REVIEW_SIZE.y, _output_dir])
	await _capture_title_and_intro()
	await _capture_village_ui()
	await _capture_guild_ui()
	await _capture_wasteland_routes()
	await _capture_responsive_views()
	await _finish_review()

func _capture_title_and_intro() -> void:
	GameState.reset_new_run(false)
	GameState.current_scene_id = "main"
	var main_scene: Node = MAIN_SCENE.instantiate()
	main_scene.set("force_fullscreen_on_start", false)
	add_child(main_scene)
	await _wait_for_render()
	await _capture_image("main_title")
	_validate_panel_bounds("main_title_1280x720", main_scene, "title_panel")
	var previous_save_path := SaveManager.default_save_path
	SaveManager.default_save_path = _output_dir.path_join("missing_save_%d.json" % Time.get_ticks_msec())
	main_scene.call("_continue_game")
	await _wait_for_render()
	var title_layer := main_scene.get("title_layer") as CanvasLayer
	var failure_notice := main_scene.get("title_status") as Label
	_runtime_check("continue_failure_keeps_title", title_layer != null and is_instance_valid(title_layer) and title_layer.is_inside_tree(), "title_layer_valid=%s" % str(title_layer != null and is_instance_valid(title_layer)))
	_runtime_check("continue_failure_shows_notice", failure_notice != null and failure_notice.visible and failure_notice.text.contains("讀取存檔失敗"), "notice=%s" % (failure_notice.text if failure_notice != null else "missing"))
	await _capture_image("continue_load_failure")
	SaveManager.default_save_path = previous_save_path
	main_scene.call("_skip_title_voice")
	GameState.reset_new_run(false)
	main_scene.call("_show_intro")
	await _wait_for_render()
	await _capture_image("intro")
	_validate_panel_bounds("intro_1280x720", main_scene, "intro_panel")
	AudioManager.stop_voice()
	main_scene.queue_free()
	await get_tree().process_frame

func _capture_village_ui() -> void:
	await _prepare_scene("village", VILLAGE_SCENE)
	var hud := _find_hud()
	if hud == null:
		_failures.append("Village scene did not create the expected HUD.")
		return
	_validate_hud_groups()
	await _run_nearest_interaction_check(hud)
	await _capture_image("village_hud")
	var saved_quest_id := GameState.active_quest_id
	var saved_quest_progress := GameState.quest_progress.duplicate(true)
	var saved_inventory := GameState.inventory.duplicate(true)
	GameState.active_quest_id = "old_factory_core"
	GameState.quest_progress = {"defeat_enemy": 7, "defeat_boss": 0}
	GameState.inventory["mutant_core"] = 1
	hud.call("_refresh")
	await _wait_for_render()
	var quest_label := hud.get("quest_label") as Label
	var quest_text := String(quest_label.text) if quest_label != null else ""
	_runtime_check("quest_progress_is_readable", quest_label != null and quest_label.get_line_count() >= 2 and quest_text.contains("7/8") and quest_text.contains("0/1"), "lines=%d text=%s" % [quest_label.get_line_count() if quest_label != null else 0, quest_text])
	_validate_control_bounds("quest_progress_panel", hud.get("quest_panel") as Control)
	await _capture_image("quest_progress")
	GameState.active_quest_id = saved_quest_id
	GameState.quest_progress = saved_quest_progress
	GameState.inventory = saved_inventory
	hud.call("_refresh")
	await _check_hidden_inventory_refresh(hud)
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
	await _capture_image("inventory")
	await _check_player_input_blocked(hud, "inventory")
	hud.call("_set_inventory_visible", false)
	_clear_test_notice(hud)

	var tutorial_panels := get_tree().get_nodes_in_group("tutorial_panel")
	if tutorial_panels.is_empty():
		_failures.append("Tutorial panel group is missing.")
	else:
		(tutorial_panels[0] as Control).visible = true
		hud.call("_refresh_overlay_visibility")
		await _check_notice_suppressed_by_modal(hud, "tutorial_hides_global_notice")
		await _wait_for_render()
		await _capture_image("tutorial")
		await _check_player_input_blocked(hud, "tutorial")
		(tutorial_panels[0] as Control).visible = false
		hud.call("_refresh_overlay_visibility")
		_clear_test_notice(hud)

	var players := get_tree().get_nodes_in_group("player")
	var npcs := get_tree().get_nodes_in_group("dialogue_npc")
	if players.is_empty() or npcs.is_empty():
		_failures.append("Dialogue capture needs at least one player and dialogue NPC.")
	else:
		var player := players[0] as Node2D
		var npc := npcs[0] as Node2D
		player.global_position = npc.global_position + Vector2(48.0, 0.0)
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
		hud.call("_show_notice", "暫停期間仍會顯示存檔提示")
		var pause_notice := hud.get("notice_label") as Control
		_runtime_check("pause_keeps_global_notice_visible", pause_notice != null and pause_notice.visible, "visible=%s" % str(pause_notice != null and pause_notice.visible))
		await _wait_for_render()
		await _capture_image("pause")
		await _check_player_input_blocked(hud, "pause")
		_runtime_check("pause_HUD_processes_while_paused", int(hud.process_mode) == Node.PROCESS_MODE_ALWAYS, "process_mode=%d" % int(hud.process_mode))
		var escape := InputEventKey.new()
		escape.pressed = true
		escape.keycode = KEY_ESCAPE
		hud.call("_unhandled_input", escape)
		_runtime_check("pause_Escape_unpauses", not get_tree().paused, "tree_paused=%s" % str(get_tree().paused))
		hud.call("_set_pause_visible", false)
		_clear_test_notice(hud)

	if not players.is_empty():
		var dead_player := players[0]
		dead_player.set_physics_process(false)
		dead_player.set("state", 8)
		if dead_player.has_method("_update_animation"):
			dead_player.call("_update_animation")
		GameState.hp = 0
		GameState.death_pending = true
		GameState.stats_changed.emit()
		await _wait_for_render()
		await _capture_image("death")
		GameState.death_pending = false
		GameState.hp = GameState.get_max_hp()

func _capture_guild_ui() -> void:
	await _prepare_scene("guild", GUILD_SCENE)
	await _wait_for_render()
	await _capture_image("guild_hud")

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
		hud.call("set_fullscreen_map", true)
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

func _capture_responsive_views() -> void:
	await _remove_active_scene()
	get_tree().paused = false
	get_window().size = RESPONSIVE_SIZE
	await _wait_for_render()
	var responsive_window_size := get_window().size
	_runtime_check("responsive_window_1024x768", responsive_window_size == RESPONSIVE_SIZE, "window=%s" % str(responsive_window_size))

	GameState.reset_new_run(false)
	GameState.current_scene_id = "main"
	var main_scene: Node = MAIN_SCENE.instantiate()
	main_scene.set("force_fullscreen_on_start", false)
	add_child(main_scene)
	await _wait_for_render()
	main_scene.call("_layout_title_screen")
	await _capture_image("main_title_1024x768")
	_validate_panel_bounds("main_title_1024x768", main_scene, "title_panel")
	main_scene.call("_skip_title_voice")
	main_scene.call("_show_intro")
	await _wait_for_render()
	await _capture_image("intro_1024x768")
	_validate_panel_bounds("intro_1024x768", main_scene, "intro_panel")
	AudioManager.stop_voice()
	main_scene.queue_free()
	await get_tree().process_frame

	await _prepare_scene("village", VILLAGE_SCENE)
	var village_hud := _find_hud()
	var village_players := get_tree().get_nodes_in_group("player")
	var village_npcs := get_tree().get_nodes_in_group("dialogue_npc")
	if village_hud == null or village_players.is_empty():
		_failures.append("Responsive village captures could not find the HUD or player.")
	else:
		village_hud.call("_set_inventory_visible", true)
		await _check_notice_suppressed_by_modal(village_hud, "inventory_1024_hides_global_notice")
		await _wait_for_render()
		await _capture_image("inventory_1024x768")
		_validate_control_bounds("inventory_1024x768", village_hud.get("inventory_panel") as Control)
		village_hud.call("_set_inventory_visible", false)
		_clear_test_notice(village_hud)
		if village_npcs.is_empty():
			_failures.append("Responsive dialogue capture could not find a dialogue NPC.")
		else:
			var player := village_players[0] as Node2D
			var npc := village_npcs[0] as Node2D
			player.global_position = npc.global_position + Vector2(48.0, 0.0)
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

	get_window().size = REVIEW_SIZE
	await _wait_for_render()

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
	GameState.player_position = player.global_position
	if camera != null:
		camera.zoom = Vector2(1.35, 1.35)
		camera.force_update_scroll()
	await _wait_for_render()
	await _capture_image(capture_name)
	player.global_position = original_position
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
		set_meta("map_world_size", REVIEW_SIZE)
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
	var success := _failures.is_empty() and success_count == REQUIRED_CAPTURES.size()
	var report := {
		"success": success,
		"success_count": success_count,
		"failure_count": capture_failure_count,
		"error_count": _failures.size(),
		"expected_capture_count": REQUIRED_CAPTURES.size(),
		"runtime_check_success_count": runtime_check_success_count,
		"runtime_check_failure_count": runtime_check_failure_count,
		"capture_size": {"width": REVIEW_SIZE.x, "height": REVIEW_SIZE.y},
		"responsive_capture_size": {"width": RESPONSIVE_SIZE.x, "height": RESPONSIVE_SIZE.y},
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
	get_tree().quit(0 if success else 1)

func _ensure_required_captures() -> void:
	var recorded: Dictionary = {}
	for result: Dictionary in _records:
		recorded[String(result.get("name", ""))] = true
	for capture_name: String in REQUIRED_CAPTURES:
		if not recorded.has(capture_name):
			_record_failure(capture_name, "required visual state was not captured")
