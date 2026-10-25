extends Node

const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"
const VILLAGE_SCENE_PATH := "res://scenes/levels/village/Village.tscn"
const GUILD_SCENE_PATH := "res://scenes/levels/guild/Guild.tscn"
const WASTELAND_SCENE_PATH := "res://scenes/levels/wasteland/Wasteland.tscn"
const FIRST_CONTRACT_ID := "clear_scrap_route"
const ESCORT_ACTION_ID := "ch1a_escort_crew"
const RELAY_ACTION_ID := "ch1a_repair_bypass"
const SECOND_OUTING_ID := "ch1b_route_coupling"
const SECOND_CHOICE_ACTION_ID := "ch1b_return_route"
const SECOND_CARRY_ACTION_ID := "ch1b_carry_coupling"
const SECOND_ROUTE_CHOICE_ID := "ch1b_covered_long"
const KILL_REQUIREMENT := 5
const SCRAP_REQUIREMENT := 12
const JOURNEY_TIMEOUT_MS := 30000
const MIN_SUCCESSFUL_CHECKS_TO_PASS := 35
const MAX_RUN_MELEE_ATTACKS := 64

var _report_path := ""
var _isolated_root := ""
var _run_id := ""
var _temp_mirror_origin_run_id := ""
var _source_project_root := ""
var _source_tree_sha256 := ""
var _driver_sha256 := ""
var _checks: Array[Dictionary] = []
var _failures: Array[String] = []
var _input_events: Array[Dictionary] = []
var _transition_events: Array[Dictionary] = []
var _combat_responses: Array[Dictionary] = []
var _combat_attack_count := 0
var _held_keys: Dictionary = {}
var _initial_tree_id := 0
var _initial_viewport_id := 0
var _initial_driver_id := 0
var _finished := false
var _started_unix := 0.0
var _isolation_validated := false
var _isolated_save_exists_at_finish := false
var _isolated_save_path := ""
var _contract_accepted := false
var _wasteland_entered := false
var _field_actions_completed := false
var _extracted := false
var _second_outing_started := false
var _second_outing_completed := false
var _second_outing_extracted := false
var _kill_objective_ready := false
var _scrap_objective_ready := false
var _guild_handin_completed := false
var _repeat_handin_unchanged := false
var _first_debrief_copy_valid := false
var _second_debrief_copy_valid := false
var _j_contract_copy_valid := false
var _post_handin_reload_valid := false
var _first_outing_saved_evidence: Dictionary = {}
var _second_outing_saved_evidence: Dictionary = {}
var _handin_evidence: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_initial_tree_id = get_tree().get_instance_id()
	_initial_viewport_id = get_tree().root.get_instance_id()
	_initial_driver_id = get_instance_id()
	_started_unix = Time.get_unix_time_from_system()
	_report_path = _argument_value("--report")
	_isolated_root = _argument_value("--isolated-root")
	_run_id = _argument_value("--run-id")
	_temp_mirror_origin_run_id = _argument_value("--temp-mirror-origin-run-id")
	_source_project_root = _argument_value("--source-project-root")
	_source_tree_sha256 = _argument_value("--source-tree-sha256")
	_driver_sha256 = FileAccess.get_file_as_string("res://scripts/tests/FirstChapterJourneyDriver.gd").sha256_text()
	if SceneRouter != null and not SceneRouter.transition_finished.is_connected(_on_transition_finished):
		SceneRouter.transition_finished.connect(_on_transition_finished)
	call_deferred("_run")


func _run() -> void:
	await get_tree().process_frame
	if not _validate_isolation():
		await _finish()
		return
	_record_check("actual_Temp_mirror_driver_SHA256_captured", _driver_sha256.length() == 64, "SHA-256 of the running Temp mirror FirstChapterJourneyDriver.gd", _driver_sha256)
	if OS.has_feature("headless"):
		_record_check("non_headless_title_flow", false, "GUI feature enabled", "headless")
		await _finish()
		return
	if not _check_action_key("move_right", KEY_D):
		_record_check("WASD_input_map", false, "move_right maps to D; the harness injects InputEventKey", "missing mapping")
		await _finish()
		return
	if not _check_action_key("interact", KEY_E):
		_record_check("interact_input_map", false, "interact maps to E; the harness injects InputEventKey", "missing mapping")
		await _finish()
		return

	var tree := get_tree()
	var main_error := tree.change_scene_to_file(MAIN_SCENE_PATH)
	_record_check("load_Main_title_scene", main_error == OK, OK, main_error)
	if main_error != OK:
		await _finish()
		return
	var title_ready := await _wait_for_title()
	_record_check("Main_title_is_visible", title_ready, MAIN_SCENE_PATH + " with enabled new-game button", _current_scene_evidence())
	if not title_ready:
		await _finish()
		return

	var main_scene := tree.current_scene
	var main_instance_id := main_scene.get_instance_id()
	var new_game_button := main_scene.get("new_game_button") as Button
	var focus_owner := get_viewport().gui_get_focus_owner()
	_record_check("new_game_button_has_normal_ui_focus", is_instance_valid(new_game_button) and focus_owner == new_game_button, "focused enabled 開始新旅程 button", _node_name(focus_owner))
	if not is_instance_valid(new_game_button) or focus_owner != new_game_button:
		await _finish()
		return
	await _tap_key(KEY_ENTER, "Enter: start new journey")
	var intro_ready := await _wait_for_intro(main_scene)
	_record_check("title_Enter_opens_intro", intro_ready, "Main.intro_active = true", bool(main_scene.get("intro_active")))
	if not intro_ready:
		await _finish()
		return

	await _tap_key(KEY_ENTER, "Enter: enter village from intro")
	var village_ready := await _wait_for_scene(VILLAGE_SCENE_PATH, "village", 1)
	_record_check("intro_Enter_enters_village_through_SceneRouter", village_ready, VILLAGE_SCENE_PATH, _current_scene_evidence())
	_record_check("Main_was_replaced_by_Village", village_ready and tree.current_scene.get_instance_id() != main_instance_id, "new current_scene instance", _current_scene_evidence())
	_record_persistent_root("after_title_to_village")
	if not village_ready:
		await _finish()
		return

	var village := tree.current_scene
	var village_instance_id := village.get_instance_id()
	var village_player := _find_player(village)
	var guild_gate := _find_interactable(village, "to_guild")
	_record_check("Village_has_player_and_authored_guild_gate", village_player != null and guild_gate != null, "player group member and to_guild interactable under Village", {"player": _node_name(village_player), "gate": _node_name(guild_gate)})
	if village_player == null or guild_gate == null:
		await _finish()
		return

	var village_start := village_player.global_position
	var gate_reached := await _walk_until_interactable(village_player, guild_gate, 18000)
	var village_end := village_player.global_position if is_instance_valid(village_player) else Vector2.ZERO
	var village_delta := village_end.distance_to(village_start)
	_record_check("WASD_moves_player_to_guild_gate", gate_reached and village_delta >= 100.0, "injected D/W/A/S InputEventKey events move the player into the authored gate range", {
		"start": _vector_data(village_start),
		"end": _vector_data(village_end),
		"distance_moved": village_delta,
		"gate_position": _vector_data(guild_gate.global_position),
		"gate_can_interact": bool(guild_gate.call("can_interact")) if is_instance_valid(guild_gate) else false,
		"selected_target": _node_name(village_player.call("get_nearest_interaction_target")) if is_instance_valid(village_player) else "invalid"
	})
	if not gate_reached or village_delta < 100.0:
		await _finish()
		return

	await _tap_key(KEY_E, "E: enter guild through Village gate")
	var guild_ready := await _wait_for_scene(GUILD_SCENE_PATH, "guild", 2)
	_record_check("E_on_Village_to_guild_gate_enters_Guild", guild_ready, GUILD_SCENE_PATH, _current_scene_evidence())
	_record_check("Village_was_replaced_by_Guild", guild_ready and tree.current_scene.get_instance_id() != village_instance_id, "new current_scene instance", _current_scene_evidence())
	_record_persistent_root("after_village_to_guild")
	if not guild_ready:
		await _finish()
		return

	var guild := tree.current_scene
	var guild_instance_id := guild.get_instance_id()
	var guild_player := _find_player(guild)
	var return_gate := _find_interactable(guild, "to_village")
	_record_check("Guild_has_player_and_authored_village_gate", guild_player != null and return_gate != null, "player group member and to_village interactable under Guild", {"player": _node_name(guild_player), "gate": _node_name(return_gate)})
	if guild_player == null or return_gate == null:
		await _finish()
		return

	var guild_start := guild_player.global_position
	var return_gate_reached := await _walk_until_interactable(guild_player, return_gate, 10000)
	var guild_end := guild_player.global_position if is_instance_valid(guild_player) else Vector2.ZERO
	var guild_return_distance := guild_end.distance_to(guild_start)
	_record_check("WASD_moves_player_to_Guild_return_gate", return_gate_reached and guild_return_distance >= 100.0, "injected D/W/A/S InputEventKey events travel at least 100 px and reach the authored return gate", {
		"start": _vector_data(guild_start),
		"end": _vector_data(guild_end),
		"distance_moved": guild_return_distance,
		"minimum_distance_moved": 100.0,
		"gate_position": _vector_data(return_gate.global_position),
		"gate_can_interact": bool(return_gate.call("can_interact")) if is_instance_valid(return_gate) else false,
		"selected_target": _node_name(guild_player.call("get_nearest_interaction_target")) if is_instance_valid(guild_player) else "invalid"
	})
	if not return_gate_reached or guild_return_distance < 100.0:
		await _finish()
		return

	await _tap_key(KEY_E, "E: return from Guild to Village")
	var returned_to_village := await _wait_for_scene(VILLAGE_SCENE_PATH, "village", 3)
	_record_check("E_on_Guild_return_gate_returns_to_Village", returned_to_village, VILLAGE_SCENE_PATH, _current_scene_evidence())
	_record_check("Guild_was_replaced_by_new_Village", returned_to_village and tree.current_scene.get_instance_id() != guild_instance_id, "new current_scene instance", _current_scene_evidence())
	_record_persistent_root("after_guild_to_village")
	_record_check("three_normal_SceneRouter_transitions_succeeded", _transition_events.size() == 3 and _all_transitions_succeeded(), "Main→Village, Village→Guild, Guild→Village", _transition_events)

	var initial_save_path := ProjectSettings.globalize_path("user://save_game.json")
	_record_check("isolated_save_is_under_Temp_after_new_game", _is_path_within(initial_save_path, _isolated_root), "user://save_game.json under explicit Temp run root", {
		"save_path": initial_save_path,
		"isolated_root": _isolated_root
	})
	_record_check("initial_roundtrip_ends_in_Village", returned_to_village and String(GameState.current_scene_id) == "village", "GameState.current_scene_id = village", _current_scene_evidence())
	if not returned_to_village:
		await _finish()
		return

	# The first Guild visit above proves return travel. Re-enter through the Village's
	# authored gate before accepting a contract so every route remains player-driven.
	var post_return_village := tree.current_scene
	var post_return_player := _find_player(post_return_village)
	var reentry_gate := _find_interactable(post_return_village, "to_guild")
	_record_check("returned_Village_has_player_and_Guild_gate", post_return_player != null and reentry_gate != null, "player and authored to_guild gate", {
		"player": _node_name(post_return_player),
		"gate": _node_name(reentry_gate)
	})
	if post_return_player == null or reentry_gate == null:
		await _finish()
		return
	var reentry_start := post_return_player.global_position
	var reentry_reached := await _walk_until_interactable(post_return_player, reentry_gate, 18000)
	var reentry_end := post_return_player.global_position if is_instance_valid(post_return_player) else Vector2.ZERO
	var reentry_distance := reentry_end.distance_to(reentry_start)
	_record_check("injected_WASD_reaches_Guild_again", reentry_reached and reentry_distance >= 100.0, "injected InputEventKey movement covers at least 100 px to to_guild", {
		"start": _vector_data(reentry_start),
		"end": _vector_data(reentry_end),
		"distance_moved": reentry_distance,
		"minimum_distance_moved": 100.0,
		"gate_can_interact": bool(reentry_gate.call("can_interact")) if is_instance_valid(reentry_gate) else false
	})
	if not reentry_reached or reentry_distance < 100.0:
		await _finish()
		return
	var post_return_village_id := post_return_village.get_instance_id()
	await _tap_key(KEY_E, "E: re-enter Guild through Village to_guild gate")
	var contract_guild_ready := await _wait_for_scene(GUILD_SCENE_PATH, "guild", 4)
	_record_check("E_on_second_Village_to_guild_gate_enters_Guild", contract_guild_ready, GUILD_SCENE_PATH, _current_scene_evidence())
	_record_check("returned_Village_was_replaced_by_new_Guild", contract_guild_ready and tree.current_scene.get_instance_id() != post_return_village_id, "new Guild current_scene instance", _current_scene_evidence())
	_record_persistent_root("after_second_village_to_guild")
	if not contract_guild_ready:
		await _finish()
		return

	var contract_guild := tree.current_scene
	var contract_player := _find_player(contract_guild)
	var contract_board := _find_interactable(contract_guild, "contract")
	_record_check("Guild_contract_board_is_player_reachable", contract_player != null and contract_board != null, "Guild player and authored contract interactable", {
		"player": _node_name(contract_player),
		"contract_board": _node_name(contract_board)
	})
	if contract_player == null or contract_board == null:
		await _finish()
		return
	var board_start := contract_player.global_position
	var board_reached := await _walk_until_interactable(contract_player, contract_board, 15000)
	var board_end := contract_player.global_position if is_instance_valid(contract_player) else Vector2.ZERO
	_record_check("injected_WASD_and_E_reach_Guild_contract_board", board_reached and contract_player.call("get_nearest_interaction_target") == contract_board, "player movement reaches and selects the real contract board", {
		"start": _vector_data(board_start),
		"end": _vector_data(board_end),
		"distance_moved": board_end.distance_to(board_start),
		"can_interact": bool(contract_board.call("can_interact")) if is_instance_valid(contract_board) else false
	})
	if not board_reached:
		await _finish()
		return

	await _tap_key(KEY_E, "E: open authored Guild contract board")
	var contract_panel := contract_guild.find_child("ContractPanel", true, false) as Control
	var accept_button := contract_guild.find_child("ContractAccept_" + FIRST_CONTRACT_ID, true, false) as Button
	var panel_wait_started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - panel_wait_started < 5000:
		if is_instance_valid(contract_panel) and contract_panel.is_visible_in_tree() and is_instance_valid(accept_button):
			break
		await get_tree().process_frame
	var contract_panel_open := is_instance_valid(contract_panel) and contract_panel.is_visible_in_tree()
	var accept_enabled := is_instance_valid(accept_button) and not accept_button.disabled and accept_button.is_visible_in_tree()
	_record_check("E_opens_enabled_first_contract_choice", contract_panel_open and accept_enabled, "visible contract panel and enabled clear_scrap_route choice", {
		"panel_visible": contract_panel_open,
		"accept_button": _node_name(accept_button),
		"accept_visible": is_instance_valid(accept_button) and accept_button.is_visible_in_tree(),
		"accept_disabled": accept_button.disabled if is_instance_valid(accept_button) else true
	})
	if not contract_panel_open or not accept_enabled:
		await _finish()
		return
	var accept_focused := await _focus_button_with_tab(accept_button, 18)
	_record_check("Tab_navigation_focuses_first_contract_choice", accept_focused, "GUI focus is on ContractAccept_clear_scrap_route after injected Tab key events", _node_name(get_viewport().gui_get_focus_owner()))
	if not accept_focused:
		await _finish()
		return
	await _tap_key(KEY_ENTER, "Enter: accept clear_scrap_route in Guild catalog")
	var accept_wait_started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - accept_wait_started < 5000 and GameState.active_quest_id != FIRST_CONTRACT_ID:
		await get_tree().process_frame
	_contract_accepted = GameState.active_quest_id == FIRST_CONTRACT_ID
	_record_check("Guild_keyboard_activation_accepts_first_contract", _contract_accepted, FIRST_CONTRACT_ID, {
		"active_quest_id": GameState.active_quest_id,
		"current_route_id": GameState.current_route_id,
		"contract_panel_visible": contract_panel.is_visible_in_tree() if is_instance_valid(contract_panel) else false
	})
	_record_check("accepted_contract_selects_authored_scrap_highway_route", _contract_accepted and GameState.current_route_id == "scrap_highway", "current_route_id=scrap_highway", GameState.current_route_id)
	if not _contract_accepted:
		await _finish()
		return

	var wasteland_gate := _find_interactable(contract_guild, "to_wasteland")
	var guild_player_before_departure := _find_player(contract_guild)
	_record_check("Guild_has_authored_wasteland_exit", wasteland_gate != null and guild_player_before_departure != null, "to_wasteland interactable and Guild player", {
		"player": _node_name(guild_player_before_departure),
		"gate": _node_name(wasteland_gate)
	})
	if wasteland_gate == null or guild_player_before_departure == null:
		await _finish()
		return
	var departure_start := guild_player_before_departure.global_position
	var wasteland_gate_reached := await _walk_until_interactable(guild_player_before_departure, wasteland_gate, 18000)
	var departure_end := guild_player_before_departure.global_position if is_instance_valid(guild_player_before_departure) else Vector2.ZERO
	var departure_distance := departure_end.distance_to(departure_start)
	_record_check("injected_WASD_reaches_Guild_wasteland_gate", wasteland_gate_reached and departure_distance >= 100.0, "injected InputEventKey movement reaches Guild's real expedition gate", {
		"start": _vector_data(departure_start),
		"end": _vector_data(departure_end),
		"distance_moved": departure_distance,
		"gate_can_interact": bool(wasteland_gate.call("can_interact")) if is_instance_valid(wasteland_gate) else false
	})
	if not wasteland_gate_reached or departure_distance < 100.0:
		await _finish()
		return
	var contract_guild_id := contract_guild.get_instance_id()
	await _tap_key(KEY_E, "E: enter accepted contract route through Guild expedition gate")
	var wasteland_ready := await _wait_for_scene(WASTELAND_SCENE_PATH, "wasteland", 5)
	_record_check("Guild_E_enters_Wasteland_through_SceneRouter", wasteland_ready, WASTELAND_SCENE_PATH, _current_scene_evidence())
	_record_check("Guild_was_replaced_by_Wasteland", wasteland_ready and tree.current_scene.get_instance_id() != contract_guild_id, "new Wasteland current_scene instance", _current_scene_evidence())
	_record_persistent_root("after_guild_to_wasteland")
	_wasteland_entered = wasteland_ready
	if not wasteland_ready:
		await _finish()
		return

	var wasteland := tree.current_scene
	var field_player := _find_player(wasteland)
	var escort_action := _find_campaign_action(wasteland, ESCORT_ACTION_ID)
	var relay_action := _find_campaign_action(wasteland, RELAY_ACTION_ID)
	var expedition_started := GameState.has_active_expedition()
	var outing_id := String(GameState.campaign_outing().get("id", ""))
	_record_check("accepted_contract_spawns_authored_wasteland_actions", field_player != null and escort_action != null and relay_action != null and expedition_started and GameState.current_route_id == "scrap_highway" and outing_id == "ch1a_escort_repair", "scrap_highway first outing, live expedition, escort and relay", {
		"player": _node_name(field_player),
		"escort_action": _node_name(escort_action),
		"relay_action": _node_name(relay_action),
		"route_id": GameState.current_route_id,
		"expedition_active": expedition_started,
		"outing_id": outing_id,
		"escort_status": GameState.campaign_action_status(ESCORT_ACTION_ID),
		"relay_status": GameState.campaign_action_status(RELAY_ACTION_ID)
	})
	if field_player == null or escort_action == null or relay_action == null or not expedition_started or outing_id != "ch1a_escort_repair":
		await _finish()
		return

	var wasteland_entry := field_player.global_position
	var escort_reached := await _walk_until_interactable(field_player, escort_action, 12000)
	var escort_approach_position := field_player.global_position if is_instance_valid(field_player) else Vector2.ZERO
	_record_check("injected_WASD_reaches_first_escort_action", escort_reached and field_player.call("get_nearest_interaction_target") == escort_action and escort_approach_position.distance_to(wasteland_entry) >= 80.0, "player travels from authored Wasteland entry and selects escort", {
		"entry_position": _vector_data(wasteland_entry),
		"action_position": _vector_data(escort_action.global_position),
		"player_position": _vector_data(escort_approach_position),
		"distance_moved": escort_approach_position.distance_to(wasteland_entry),
		"can_interact": bool(escort_action.call("can_interact"))
	})
	if not escort_reached:
		await _finish()
		return
	await _tap_key(KEY_E, "E: start authored recovery-crew escort")
	var escort_started := bool(GameState.campaign_action_progress(ESCORT_ACTION_ID).get("started", false))
	_record_check("E_starts_first_escort_action", escort_started, "campaign runtime started=true after player E event", GameState.campaign_action_progress(ESCORT_ACTION_ID))
	if not escort_started:
		await _finish()
		return

	var escort_action_valid_before_walk := is_instance_valid(escort_action)
	var escort_waypoints := _path_points(escort_action.get("_waypoints") if escort_action_valid_before_walk else [])
	var escort_walk := await _follow_escort_action(field_player, escort_action, 45000)
	var escort_checkpoint := int(escort_walk.get("last_checkpoint", -1))
	var escort_status := GameState.campaign_action_status(ESCORT_ACTION_ID)
	var escort_action_valid := is_instance_valid(escort_action)
	var escort_actor: Node2D = escort_action.get("_escort_actor") as Node2D if escort_action_valid else null
	var escort_done := bool(escort_walk.get("reached", false)) and escort_waypoints.size() == 4 and escort_status == "done" and escort_checkpoint >= escort_waypoints.size() - 1 and escort_checkpoint <= escort_waypoints.size() and float(escort_walk.get("max_player_actor_distance", INF)) <= 520.0
	var escort_observed := {
		"walk": escort_walk,
		"waypoint_count": escort_waypoints.size(),
		"player_valid": is_instance_valid(field_player),
		"player_inside_tree": field_player.is_inside_tree() if is_instance_valid(field_player) else false,
		"player_hp": int(GameState.hp),
		"death_pending": bool(GameState.death_pending),
		"current_scene": _current_scene_evidence(),
		"current_route_id": String(GameState.current_route_id),
		"active_quest_id": String(GameState.active_quest_id),
		"has_active_expedition": bool(GameState.has_active_expedition()),
		"campaign_action_owner": GameState.campaign_action_owner(),
		"scene_router_transition_count": _transition_events.size(),
		"nearby_enemies_to_player": _nearby_enemy_evidence(field_player.global_position, 520.0) if is_instance_valid(field_player) else [],
		"nearby_enemies_to_escort_actor": _nearby_enemy_evidence(escort_actor.global_position, 520.0) if is_instance_valid(escort_actor) else [],
		"player_position": _vector_data(field_player.global_position) if is_instance_valid(field_player) else [],
		"escort_actor_position": _vector_data(escort_actor.global_position) if is_instance_valid(escort_actor) else [],
		"campaign_action_status": GameState.campaign_action_status(ESCORT_ACTION_ID),
		"runtime": GameState.campaign_action_progress(ESCORT_ACTION_ID),
		"presentation": escort_action.call("presentation_state") if escort_action_valid else {}
	}
	_record_check("first_escort_reaches_native_done_after_final_route_observation", escort_done, "native done status for the authored four-waypoint escort, final route progress observed, and player remained in authored follow range", escort_observed)
	if not escort_done:
		await _finish()
		return
	var relay_approach_start := field_player.global_position
	var relay_reached := await _walk_until_interactable(field_player, relay_action, 10000)
	var relay_unlocked: bool = GameState.campaign_action_status(RELAY_ACTION_ID) == "ready" and bool(relay_action.call("can_interact")) and field_player.call("get_nearest_interaction_target") == relay_action
	_record_check("completed_escort_unlocks_and_player_reaches_relay", relay_reached and relay_unlocked, "relay status=ready; injected WASD reaches its authored interaction range", {
		"relay_status": GameState.campaign_action_status(RELAY_ACTION_ID),
		"relay_can_interact": bool(relay_action.call("can_interact")),
		"selected_target": _node_name(field_player.call("get_nearest_interaction_target")),
		"player_position": _vector_data(field_player.global_position),
		"movement_start": _vector_data(relay_approach_start),
		"distance_moved": relay_approach_start.distance_to(field_player.global_position),
		"relay_position": _vector_data(relay_action.global_position)
	})
	if not relay_reached or not relay_unlocked:
		await _finish()
		return
	await _tap_key(KEY_E, "E: start authored relay repair channel")
	var relay_started := bool(GameState.campaign_action_progress(RELAY_ACTION_ID).get("started", false))
	_record_check("E_starts_relay_repair_channel", relay_started, "campaign runtime started=true after player E event", GameState.campaign_action_progress(RELAY_ACTION_ID))
	if not relay_started:
		await _finish()
		return
	var relay_before_hold := _campaign_runtime_evidence(field_player, relay_action)
	var relay_owner_valid_before_hold := bool(relay_before_hold.get("player_valid", false)) and int(relay_before_hold.get("player_hp", 0)) > 0 and not bool(relay_before_hold.get("death_pending", true)) and String(relay_before_hold.get("game_state_scene_id", "")) == "wasteland" and bool(relay_before_hold.get("has_active_expedition", false)) and bool(relay_before_hold.get("campaign_action_owner_valid", false)) and bool(relay_before_hold.get("campaign_runtime_started", false))
	_record_check("player_and_run_owner_valid_before_relay_hold", relay_owner_valid_before_hold, "valid live player, positive HP, active Wasteland expedition, campaign owner and started runtime", relay_before_hold)
	if not relay_owner_valid_before_hold:
		await _finish()
		return
	await _hold_key_for_seconds(KEY_E, 4.5, "hold E: repair authored south-gate bypass relay")
	var relay_after_hold := _campaign_runtime_evidence(field_player, relay_action)
	var relay_owner_valid_after_hold := bool(relay_after_hold.get("player_valid", false)) and int(relay_after_hold.get("player_hp", 0)) > 0 and not bool(relay_after_hold.get("death_pending", true)) and String(relay_after_hold.get("game_state_scene_id", "")) == "wasteland" and bool(relay_after_hold.get("has_active_expedition", false)) and bool(relay_after_hold.get("campaign_action_owner_valid", false))
	_record_check("player_and_run_owner_valid_immediately_after_relay_hold", relay_owner_valid_after_hold, "same live campaign run remains in Wasteland with positive HP and valid owner after injected hold", relay_after_hold)
	var relay_completed := false
	if relay_owner_valid_after_hold:
		relay_completed = await _wait_for_campaign_action(RELAY_ACTION_ID, "done", 5000)
	var relay_after_wait := _campaign_runtime_evidence(field_player, relay_action)
	var field_objective_active := GameState.field_objective_status(FIRST_CONTRACT_ID)
	_record_check("held_E_completes_relay_and_first_field_objective", relay_completed and field_objective_active, "relay action done and real field objective active in expedition", {
		"immediate_state_after_hold": relay_after_hold,
		"state_after_completion_wait": relay_after_wait,
		"relay_status": GameState.campaign_action_status(RELAY_ACTION_ID),
		"field_objective_active": field_objective_active,
		"campaign_runtime": GameState.campaign_action_progress(RELAY_ACTION_ID),
		"player_position": _vector_data(field_player.global_position) if is_instance_valid(field_player) else [],
		"action_position": _vector_data(relay_action.global_position) if is_instance_valid(relay_action) else []
	})
	if not relay_completed or not field_objective_active:
		await _finish()
		return
	_field_actions_completed = true

	var extraction_gate := _find_interactable(wasteland, "to_village")
	var route_data: Dictionary = wasteland.get("route_data")
	var route_paths: Array = route_data.get("exploration_paths", [])
	var extraction_points: Array[Vector2] = []
	if not route_paths.is_empty() and route_paths[0] is Array:
		for raw_point: Variant in route_paths[0]:
			if not raw_point is Array or raw_point.size() != 2:
				continue
			var map_size: Vector2 = wasteland.get("world_size")
			var point := Vector2(float(raw_point[0]) * map_size.x, float(raw_point[1]) * map_size.y)
			if point.y < relay_action.global_position.y - 24.0:
				extraction_points.append(point)
	if extraction_gate != null and (extraction_points.is_empty() or extraction_points.back().distance_to(extraction_gate.global_position) > 24.0):
		extraction_points.append(extraction_gate.global_position)
	_record_check("authored_extraction_gate_and_northbound_path_exist", extraction_gate != null and not extraction_points.is_empty(), "to_village gate plus authored scrap_highway northbound road points", {
		"gate": _node_name(extraction_gate),
		"gate_position": _vector_data(extraction_gate.global_position) if is_instance_valid(extraction_gate) else [],
		"path_point_count": extraction_points.size(),
		"first_path_point": _vector_data(extraction_points[0]) if not extraction_points.is_empty() else [],
		"last_path_point": _vector_data(extraction_points.back()) if not extraction_points.is_empty() else []
	})
	if extraction_gate == null or extraction_points.is_empty():
		await _finish()
		return
	var extraction_walk := await _walk_player_path(field_player, extraction_points, 45000)
	var extraction_path_state := {
		"player_valid": is_instance_valid(field_player),
		"player_inside_tree": field_player.is_inside_tree() if is_instance_valid(field_player) else false,
		"player_hp": int(GameState.hp),
		"death_pending": bool(GameState.death_pending),
		"current_scene": _current_scene_evidence(),
		"transition_event_count": _transition_events.size()
	}
	var extraction_reached := false
	if bool(extraction_walk.get("reached", false)) and is_instance_valid(field_player) and is_instance_valid(extraction_gate) and GameState.hp > 0 and not GameState.death_pending:
		extraction_reached = await _walk_until_interactable(field_player, extraction_gate, 10000, true)
	var combat_recovery: Dictionary = {"attempted": false}
	if not extraction_reached and is_instance_valid(field_player) and is_instance_valid(extraction_gate) and GameState.hp > 0 and not GameState.death_pending and _combat_attack_count < MAX_RUN_MELEE_ATTACKS:
		var close_enemies := _nearby_enemy_evidence(field_player.global_position, 120.0)
		if not close_enemies.is_empty():
			var attack_budget := mini(4, MAX_RUN_MELEE_ATTACKS - _combat_attack_count)
			combat_recovery = await _clear_close_enemies_with_space(field_player, 10000, attack_budget)
			combat_recovery["stage"] = "extraction_stalled_nearby_enemies"
			_combat_responses.append(combat_recovery)
			_combat_attack_count += int(combat_recovery.get("attack_count", 0))
			combat_recovery["post_attack_state"] = {
				"player_valid": is_instance_valid(field_player),
				"player_hp": GameState.hp,
				"death_pending": GameState.death_pending,
				"current_scene": _current_scene_evidence()
			}
			if is_instance_valid(field_player) and is_instance_valid(extraction_gate) and GameState.hp > 0 and not GameState.death_pending:
				var gate_x := extraction_gate.global_position.x
				var continue_points: Array[Vector2] = [Vector2(gate_x, field_player.global_position.y), extraction_gate.global_position]
				var resumed_walk := await _walk_player_path(field_player, continue_points, 30000)
				combat_recovery["resumed_road_walk"] = resumed_walk
				if is_instance_valid(field_player) and bool(resumed_walk.get("reached", false)):
					extraction_reached = await _walk_until_interactable(field_player, extraction_gate, 10000, true)
	var extraction_target_selected := false
	if extraction_reached and is_instance_valid(field_player) and is_instance_valid(extraction_gate):
		extraction_target_selected = field_player.call("get_nearest_interaction_target") == extraction_gate
	_record_check("injected_WASD_follows_authored_road_to_extraction", extraction_reached and extraction_target_selected, "player follows the authored scrap_highway road, uses Space against immediate hostiles if blocked, then reaches the actual return gate", {
		"path_walk": extraction_walk,
		"path_terminal_state": extraction_path_state,
		"combat_recovery": combat_recovery,
		"player_position": _vector_data(field_player.global_position) if is_instance_valid(field_player) else [],
		"player_hp": GameState.hp,
		"death_pending": GameState.death_pending,
		"nearby_enemies": _nearby_enemy_evidence(field_player.global_position, 520.0) if is_instance_valid(field_player) else [],
		"gate_position": _vector_data(extraction_gate.global_position) if is_instance_valid(extraction_gate) else [],
		"gate_valid": is_instance_valid(extraction_gate),
		"gate_can_interact": bool(extraction_gate.call("can_interact")) if is_instance_valid(extraction_gate) else false,
		"selected_target": _node_name(field_player.call("get_nearest_interaction_target")) if is_instance_valid(field_player) else "invalid"
	})
	if not extraction_reached:
		await _finish()
		return
	var extraction_signals: Array[String] = []
	extraction_gate.connect("interacted", func(interaction_id: String) -> void: extraction_signals.append(interaction_id))
	var wasteland_instance_id := wasteland.get_instance_id()
	await _tap_key(KEY_E, "E: use the actual Wasteland extraction gate")
	var village_after_extraction := await _wait_for_scene(VILLAGE_SCENE_PATH, "village", 6)
	_extracted = village_after_extraction and extraction_signals == ["to_village"]
	_record_check("E_on_actual_extraction_gate_routes_to_Village", _extracted, "gate emits to_village and SceneRouter replaces Wasteland with Village", {
		"gate_interactions": extraction_signals,
		"scene_ready": village_after_extraction,
		"wasteland_instance_id": wasteland_instance_id,
		"current_scene": _current_scene_evidence()
	})
	_record_check("Wasteland_was_replaced_and_root_driver_survived_extraction", village_after_extraction and tree.current_scene.get_instance_id() != wasteland_instance_id and get_parent() == tree.root, "new Village scene with same root-child driver", {
		"village_instance_id": tree.current_scene.get_instance_id() if tree.current_scene != null else 0,
		"driver_instance_id": get_instance_id(),
		"driver_is_root_child": get_parent() == tree.root
	})
	_record_persistent_root("after_wasteland_extraction")
	if not _extracted:
		await _finish()
		return

	var campaign_state: Dictionary = GameState.quest_progress.get("campaign", {}).duplicate(true)
	var persisted_actions: Dictionary = campaign_state.get("actions", {}).duplicate(true)
	var debrief := GameState.last_expedition_report()
	var field_objective_after_extraction := GameState.field_objective_status(FIRST_CONTRACT_ID)
	var quest_ready_after_first_outing := GameState.is_active_quest_ready()
	_record_check("extraction_persists_first_outing_and_objective_to_contract", GameState.active_quest_id == FIRST_CONTRACT_ID and int(campaign_state.get("outing_index", -1)) == 1 and persisted_actions.get(ESCORT_ACTION_ID, "") == "done" and persisted_actions.get(RELAY_ACTION_ID, "") == "done" and field_objective_after_extraction, "active contract, outing_index=1, both authored actions done, relay objective persisted", {
		"active_quest_id": GameState.active_quest_id,
		"outing_index": campaign_state.get("outing_index", -1),
		"actions": persisted_actions,
		"field_objective_persisted": field_objective_after_extraction,
		"quest_ready_for_hand_in": quest_ready_after_first_outing,
		"requirements": GameState.active_quest_requirements()
	})
	_record_check("extraction_produces_first_outing_debrief", not debrief.is_empty(), "non-empty authored expedition debrief after extraction", debrief)
	_record_check("six_normal_SceneRouter_transitions_succeeded", _transition_events.size() == 6 and _all_transitions_succeeded(), "Main→Village→Guild→Village→Guild→Wasteland→Village", _transition_events)
	var final_scene_is_village := String(GameState.current_scene_id) == "village" and tree.current_scene.scene_file_path == VILLAGE_SCENE_PATH
	_record_check("final_scene_is_Village_after_first_contract_extraction", final_scene_is_village, "current scene Village after actual extraction", _current_scene_evidence())
	var first_hud := _current_hud()
	var first_debrief_role_label := first_hud.get("dialogue_role") as Label if is_instance_valid(first_hud) else null
	var first_debrief_role := first_debrief_role_label.text if is_instance_valid(first_debrief_role_label) else ""
	_record_check("first_extraction_opens_real_debrief", first_debrief_role == "撤離回報" and not debrief.is_empty(), "HUD debrief opened by SceneRouter after first extracted outing", {
		"dialogue_role": first_debrief_role,
		"debrief": debrief
	})
	var first_debrief_ui := _dialogue_evidence()
	var first_debrief_body := String(first_debrief_ui.get("body", ""))
	_first_debrief_copy_valid = first_debrief_role == "撤離回報" and bool(first_debrief_ui.get("dialogue_visible", false)) and first_debrief_body.contains("不能長期供水") and first_debrief_body.contains("正式替換接頭仍留在外線") and first_debrief_body.contains("村井仍照配水表輪供")
	_record_check("first_actual_debrief_distinguishes_temporary_test_connector_location_and_unchanged_rationing", _first_debrief_copy_valid, "live first-outing HUD debrief says the test circuit is not long-term supply, the formal connector remains outside, and rationing continues", {
		"dialogue_role": first_debrief_role,
		"dialogue_visible": first_debrief_ui.get("dialogue_visible", false),
		"requires_non_long_term_supply": "不能長期供水",
		"requires_formal_connector_still_outside": "正式替換接頭仍留在外線",
		"requires_rationing_unchanged": "村井仍照配水表輪供",
		"body": first_debrief_body
	})
	_first_outing_saved_evidence = _isolated_save_evidence()
	var first_saved_ledger: Dictionary = _first_outing_saved_evidence.get("expedition", {})
	var first_saved_result: Dictionary = first_saved_ledger.get("last_result", {})
	var first_saved_campaign: Dictionary = _first_outing_saved_evidence.get("campaign", {})
	_record_check("first_extraction_commits_run_ledger_and_campaign_to_isolated_save", bool(_first_outing_saved_evidence.get("checksum_valid", false)) and first_saved_ledger.get("active", {}) is Dictionary and first_saved_ledger.get("active", {}).is_empty() and String(first_saved_result.get("outcome", "")) == "extracted" and String(first_saved_result.get("campaign_outing", "")) == "ch1a_escort_repair" and int(first_saved_campaign.get("outing_index", -1)) == 1, "saved active ledger cleared, extracted first-outing result retained, outing_index=1", _first_outing_saved_evidence)
	if not final_scene_is_village:
		await _finish()
		return
	await _continue_second_outing_and_handin(tree)
	await _finish()


func _continue_second_outing_and_handin(tree: SceneTree) -> void:
	var first_debrief_closed := await _dismiss_visible_dialogue("Escape: close first-outing extraction debrief")
	_record_check("first_outing_debrief_closed_with_player_input", first_debrief_closed, "HUD extraction report dismissed by injected Escape", _dialogue_evidence())
	if not first_debrief_closed:
		return

	var first_return_village := tree.current_scene
	var village_player := _find_player(first_return_village)
	var repair_station := _find_interactable(first_return_village, "save")
	_record_check("returned_Village_has_real_repair_save_station", village_player != null and repair_station != null, "current Village player and authored save station interactable", {
		"player": _node_name(village_player),
		"station": _node_name(repair_station)
	})
	if village_player == null or repair_station == null:
		return
	var repair_reached := await _walk_until_interactable(village_player, repair_station, 18000)
	if not repair_reached:
		_record_check("injected_WASD_reaches_Village_repair_station", false, "save station selected by current Village player", {
			"player_position": _vector_data(village_player.global_position),
			"station_position": _vector_data(repair_station.global_position)
		})
		return
	var hp_before_repair := int(GameState.hp)
	await _tap_key(KEY_E, "E: use Village repair station before second outing")
	var repair_saved := SaveManager.has_save() and _is_path_within(ProjectSettings.globalize_path("user://save_game.json"), _isolated_root)
	_record_check("physical_Village_repair_station_restores_health_and_saves_isolated_profile", int(GameState.hp) == GameState.get_max_hp() and repair_saved, "full HP and isolated Temp save after real E interaction", {
		"hp_before": hp_before_repair,
		"hp_after": GameState.hp,
		"max_hp": GameState.get_max_hp(),
		"save_exists": SaveManager.has_save(),
		"save_path": ProjectSettings.globalize_path("user://save_game.json")
	})
	if int(GameState.hp) != GameState.get_max_hp() or not repair_saved:
		return

	var first_trip_kills := GameState.quest_counter_value("defeat_enemy")
	var first_trip_scrap := GameState.quest_item_count("scrap")
	var first_trip_campaign: Dictionary = GameState.quest_progress.get("campaign", {}).duplicate(true)
	_record_check("first_outing_preserves_original_contract_requirements_for_second_trip", GameState.active_quest_id == FIRST_CONTRACT_ID and int(first_trip_campaign.get("outing_index", -1)) == 1 and GameState.field_objective_status(FIRST_CONTRACT_ID) and first_trip_scrap >= SCRAP_REQUIREMENT, "active first contract, outing 1/2 banked, field objective retained, 12 scrap already available or carried", {
		"active_quest_id": GameState.active_quest_id,
		"campaign": first_trip_campaign,
		"kills_after_first_outing": first_trip_kills,
		"required_kills": KILL_REQUIREMENT,
		"scrap_total": first_trip_scrap,
		"required_scrap": SCRAP_REQUIREMENT,
		"field_objective": GameState.field_objective_status(FIRST_CONTRACT_ID)
	})
	if GameState.active_quest_id != FIRST_CONTRACT_ID or int(first_trip_campaign.get("outing_index", -1)) != 1 or not GameState.field_objective_status(FIRST_CONTRACT_ID) or first_trip_scrap < SCRAP_REQUIREMENT:
		return

	var route_gate := _find_interactable(first_return_village, "route:scrap_highway")
	_record_check("returned_Village_has_authored_scrap_highway_route_gate", route_gate != null, "actual route:scrap_highway interactable in Village", _node_name(route_gate))
	if route_gate == null:
		return
	var route_gate_reached := await _walk_until_interactable(village_player, route_gate, 18000)
	_record_check("injected_WASD_reaches_second_outing_route_gate", route_gate_reached and village_player.call("get_nearest_interaction_target") == route_gate, "player reaches and selects the actual south scrap_highway route gate", {
		"player_position": _vector_data(village_player.global_position),
		"gate_position": _vector_data(route_gate.global_position),
		"selected_target": _node_name(village_player.call("get_nearest_interaction_target"))
	})
	if not route_gate_reached:
		return
	var village_instance_id := first_return_village.get_instance_id()
	await _tap_key(KEY_E, "E: enter second scrap_highway outing through Village route gate")
	var second_wasteland_ready := await _wait_for_scene(WASTELAND_SCENE_PATH, "wasteland", 7)
	_record_check("actual_Village_route_gate_enters_second_Wasteland_through_SceneRouter", second_wasteland_ready and GameState.current_route_id == "scrap_highway", "new Wasteland scene, scrap_highway route, SceneRouter transition 7", {
		"scene_ready": second_wasteland_ready,
		"route_id": GameState.current_route_id,
		"village_instance_id": village_instance_id,
		"current_scene": _current_scene_evidence()
	})
	_record_persistent_root("after_village_to_second_wasteland")
	if not second_wasteland_ready:
		return

	var wasteland := tree.current_scene
	var field_player := _find_player(wasteland)
	var route_choice := _find_campaign_action(wasteland, SECOND_CHOICE_ACTION_ID)
	var expedition_active := GameState.has_active_expedition()
	var second_outing := GameState.campaign_outing()
	_second_outing_started = field_player != null and expedition_active and GameState.active_quest_id == FIRST_CONTRACT_ID and String(second_outing.get("id", "")) == SECOND_OUTING_ID and int(GameState.quest_progress.get("campaign", {}).get("outing_index", -1)) == 1
	_record_check("second_Wasteland_run_owns_second_authored_outing", _second_outing_started and route_choice != null and GameState.campaign_action_status(SECOND_CHOICE_ACTION_ID) == "ready", "live campaign run with outing_index=1 and ready ch1b_route_coupling choice action", {
		"player": _node_name(field_player),
		"expedition_active": expedition_active,
		"active_quest_id": GameState.active_quest_id,
		"outing": second_outing,
		"outing_index": GameState.quest_progress.get("campaign", {}).get("outing_index", -1),
		"choice_action": _node_name(route_choice),
		"choice_status": GameState.campaign_action_status(SECOND_CHOICE_ACTION_ID),
		"campaign_owner": GameState.campaign_action_owner(),
		"death_pending": GameState.death_pending,
		"player_hp": GameState.hp
	})
	if not _second_outing_started or route_choice == null:
		return

	var choice_reached := await _walk_until_interactable(field_player, route_choice, 18000, true)
	_record_check("injected_WASD_reaches_second_outing_route_choice", choice_reached and field_player.call("get_nearest_interaction_target") == route_choice, "second-outing route action selected by player movement", {
		"player_position": _vector_data(field_player.global_position),
		"choice_position": _vector_data(route_choice.global_position),
		"selected_target": _node_name(field_player.call("get_nearest_interaction_target")),
		"player_hp": GameState.hp
	})
	if not choice_reached:
		return
	await _tap_key(KEY_E, "E: open second-outing route choice")
	var hud := _current_hud()
	var choice_panel := wasteland.find_child("CampaignChoicePanel", true, false) as Control
	var choice_wait_started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - choice_wait_started < 8000:
		if is_instance_valid(choice_panel) and choice_panel.is_visible_in_tree():
			break
		await get_tree().process_frame
	var choice_state: Dictionary = GameState.campaign_choice_state()
	_record_check("E_opens_authored_second_outing_choice_panel", is_instance_valid(choice_panel) and choice_panel.is_visible_in_tree() and String(choice_state.get("action_id", "")) == SECOND_CHOICE_ACTION_ID, "CampaignChoicePanel visible for ch1b_return_route", {
		"panel_visible": is_instance_valid(choice_panel) and choice_panel.is_visible_in_tree(),
		"choice_state": choice_state,
		"focus_owner": _node_name(get_viewport().gui_get_focus_owner())
	})
	if not is_instance_valid(choice_panel) or not choice_panel.is_visible_in_tree() or String(choice_state.get("action_id", "")) != SECOND_CHOICE_ACTION_ID:
		return

	var covered_button := _campaign_option_button(hud, choice_state, SECOND_ROUTE_CHOICE_ID)
	var choice_focused := false
	for _press in range(8):
		if is_instance_valid(covered_button) and get_viewport().gui_get_focus_owner() == covered_button:
			choice_focused = true
			break
		await _tap_key(KEY_TAB, "Tab: navigate second-outing route choices")
	if is_instance_valid(covered_button) and get_viewport().gui_get_focus_owner() == covered_button:
		choice_focused = true
	_record_check("Tab_navigation_focuses_covered_long_route_choice", choice_focused, "normal GUI focus reaches the covered-long option button through injected Tab", {
		"target_button": _node_name(covered_button),
		"focus_owner": _node_name(get_viewport().gui_get_focus_owner()),
		"choice_id": SECOND_ROUTE_CHOICE_ID
	})
	if not choice_focused:
		return
	await _tap_key(KEY_ENTER, "Enter: choose covered-long route in campaign panel")
	var choice_completed := await _wait_for_campaign_action(SECOND_CHOICE_ACTION_ID, "done", 8000)
	var selected_route_id := GameState.campaign_selected_choice(SECOND_CHOICE_ACTION_ID)
	_record_check("Enter_selects_covered_long_route_through_real_GUI", choice_completed and selected_route_id == SECOND_ROUTE_CHOICE_ID, "campaign action done with ch1b_covered_long selected by Tab and Enter", {
		"choice_completed": choice_completed,
		"selected_choice": selected_route_id,
		"choice_status": GameState.campaign_action_status(SECOND_CHOICE_ACTION_ID),
		"campaign_runtime": GameState.campaign_action_progress(SECOND_CHOICE_ACTION_ID),
		"choice_panel_visible_after_selection": choice_panel.is_visible_in_tree()
	})
	if not choice_completed or selected_route_id != SECOND_ROUTE_CHOICE_ID:
		return

	var carry_action := _find_campaign_action(wasteland, SECOND_CARRY_ACTION_ID)
	_record_check("covered_route_unlocks_second_outing_carry_action", carry_action != null and GameState.campaign_action_status(SECOND_CARRY_ACTION_ID) == "ready", "ch1b_carry_coupling unlocked by selected route", {
		"carry_action": _node_name(carry_action),
		"carry_status": GameState.campaign_action_status(SECOND_CARRY_ACTION_ID),
		"selected_route": selected_route_id
	})
	if carry_action == null:
		return
	var carry_reached := await _walk_until_interactable(field_player, carry_action, 15000, true)
	_record_check("injected_WASD_reaches_second_outing_carry_action", carry_reached and field_player.call("get_nearest_interaction_target") == carry_action, "player reaches and selects actual coupling carry action", {
		"player_position": _vector_data(field_player.global_position),
		"carry_position": _vector_data(carry_action.global_position),
		"selected_target": _node_name(field_player.call("get_nearest_interaction_target")),
		"player_hp": GameState.hp
	})
	if not carry_reached:
		return
	await _tap_key(KEY_E, "E: pick up and start carrying the replacement coupling")
	var carry_runtime: Dictionary = GameState.campaign_action_progress(SECOND_CARRY_ACTION_ID)
	var carry_waypoints := _path_points(carry_action.get("_waypoints"))
	var carry_wave_count := int(carry_action.get("_wave_count"))
	_record_check("E_starts_real_coupling_carry_with_authored_route", bool(carry_runtime.get("started", false)) and carry_waypoints.size() >= 2 and carry_wave_count >= 0, "started carry runtime with selected route waypoints and authored wave count", {
		"runtime": carry_runtime,
		"waypoint_count": carry_waypoints.size(),
		"waypoints": carry_waypoints.map(func(point: Vector2) -> Array[float]: return _vector_data(point)),
		"wave_count": carry_wave_count,
		"selected_route": selected_route_id
	})
	if not bool(carry_runtime.get("started", false)) or carry_waypoints.size() < 2:
		return

	var carry_walk := await _follow_carry_action(field_player, carry_action, 150000)
	var carry_done := bool(carry_walk.get("reached", false)) and GameState.campaign_action_status(SECOND_CARRY_ACTION_ID) == "done"
	_record_check("player_follows_selected_carry_route_and_clears_real_ambush_wave", carry_done, "all authored route checkpoints reached; real wave combat completed; carry action done", {
		"carry_walk": carry_walk,
		"carry_status": GameState.campaign_action_status(SECOND_CARRY_ACTION_ID),
		"carry_result": GameState.quest_progress.get("campaign", {}).get("actions", {}).get(SECOND_CARRY_ACTION_ID, ""),
		"selected_route": selected_route_id,
		"active_quest_kills": GameState.quest_counter_value("defeat_enemy"),
		"player_hp": GameState.hp,
		"death_pending": GameState.death_pending
	})
	if not carry_done:
		return

	var kill_top_up := await _defeat_remaining_contract_kills(field_player, 60000)
	var current_kills := GameState.quest_counter_value("defeat_enemy")
	_record_check("real_second_outing_combat_meets_original_five_kill_requirement", current_kills >= KILL_REQUIREMENT, "at least the original 5 actual enemy defeats after second-outing combat", {
		"first_outing_kills": first_trip_kills,
		"current_total": current_kills,
		"required": KILL_REQUIREMENT,
		"second_outing_top_up": kill_top_up,
		"defeated_enemies_lifetime": GameState.defeated_enemies
	})
	if current_kills < KILL_REQUIREMENT or GameState.hp <= 0 or GameState.death_pending:
		return

	var extraction_gate := _find_interactable(wasteland, "to_village")
	var extraction_reached := false
	if extraction_gate != null:
		extraction_reached = await _walk_until_interactable(field_player, extraction_gate, 20000, true)
	_record_check("player_walks_from_carry_finish_to_actual_second_extraction_gate", extraction_reached and field_player.call("get_nearest_interaction_target") == extraction_gate, "real Wasteland return gate selected after carry delivery", {
		"gate": _node_name(extraction_gate),
		"player_position": _vector_data(field_player.global_position) if is_instance_valid(field_player) else [],
		"gate_position": _vector_data(extraction_gate.global_position) if is_instance_valid(extraction_gate) else [],
		"carry_finish_position": _vector_data(carry_action.global_position),
		"player_hp": GameState.hp
	})
	if not extraction_reached:
		return
	var second_extraction_signals: Array[String] = []
	extraction_gate.connect("interacted", func(interaction_id: String) -> void: second_extraction_signals.append(interaction_id))
	var second_wasteland_instance_id := wasteland.get_instance_id()
	await _tap_key(KEY_E, "E: extract through actual second-outing return gate")
	var village_after_second_extraction := await _wait_for_scene(VILLAGE_SCENE_PATH, "village", 8)
	_second_outing_extracted = village_after_second_extraction and second_extraction_signals == ["to_village"] and GameState.hp > 0 and not GameState.death_pending
	_record_check("second_actual_return_gate_routes_through_SceneRouter_without_death", _second_outing_extracted, "gate emits to_village; transition 8 returns to Village with positive HP and no death recovery", {
		"interactions": second_extraction_signals,
		"scene_ready": village_after_second_extraction,
		"hp": GameState.hp,
		"death_pending": GameState.death_pending,
		"wasteland_instance_id": second_wasteland_instance_id,
		"current_scene": _current_scene_evidence()
	})
	_record_persistent_root("after_second_wasteland_extraction")
	if not _second_outing_extracted:
		return

	var campaign_after_second: Dictionary = GameState.quest_progress.get("campaign", {}).duplicate(true)
	var actions_after_second: Dictionary = campaign_after_second.get("actions", {}).duplicate(true)
	var second_debrief := GameState.last_expedition_report()
	var second_hud := _current_hud()
	var second_debrief_role_label := second_hud.get("dialogue_role") as Label if is_instance_valid(second_hud) else null
	var second_debrief_role := second_debrief_role_label.text if is_instance_valid(second_debrief_role_label) else ""
	var second_debrief_ui := _dialogue_evidence()
	var second_debrief_body := String(second_debrief_ui.get("body", ""))
	_second_debrief_copy_valid = second_debrief_role == "撤離回報" and bool(second_debrief_ui.get("dialogue_visible", false)) and second_debrief_body.contains("帶回替換接頭") and second_debrief_body.contains("井水仍按表輪供") and second_debrief_body.contains("按 [J] 交付") and GameState.active_quest_id == FIRST_CONTRACT_ID and not GameState.completed_quests.has(FIRST_CONTRACT_ID)
	_record_check("second_actual_debrief_says_connector_returned_but_rationing_and_handin_remain", _second_debrief_copy_valid, "live second-outing HUD debrief says the connector was returned, rationing remains, and the first contract is still awaiting Guild delivery", {
		"dialogue_role": second_debrief_role,
		"dialogue_visible": second_debrief_ui.get("dialogue_visible", false),
		"requires_connector_returned": "帶回替換接頭",
		"requires_rationing_unchanged": "井水仍按表輪供",
		"requires_delivery_still_pending": "按 [J] 交付",
		"active_quest_id": GameState.active_quest_id,
		"contract_already_completed": GameState.completed_quests.has(FIRST_CONTRACT_ID),
		"body": second_debrief_body
	})
	var second_kills := GameState.quest_counter_value("defeat_enemy")
	var second_scrap := GameState.quest_item_count("scrap")
	_kill_objective_ready = second_kills >= KILL_REQUIREMENT
	_scrap_objective_ready = second_scrap >= SCRAP_REQUIREMENT
	var second_result: Dictionary = GameState._expedition.last_result.duplicate(true)
	var second_campaign_complete: bool = int(campaign_after_second.get("outing_index", -1)) == 2 and actions_after_second.get(SECOND_CHOICE_ACTION_ID, "") == SECOND_ROUTE_CHOICE_ID and actions_after_second.get(SECOND_CARRY_ACTION_ID, "") == "done"
	_second_outing_completed = second_campaign_complete and _kill_objective_ready and _scrap_objective_ready and GameState.field_objective_status(FIRST_CONTRACT_ID)
	_record_check("second_extraction_persists_outing_2_of_2_and_original_objectives", _second_outing_completed, "outings 2/2; 5+ kills; 12+ scrap available; original field objective retained; selected choice and carry action banked", {
		"active_quest_id": GameState.active_quest_id,
		"campaign": campaign_after_second,
		"actions": actions_after_second,
		"kills": second_kills,
		"required_kills": KILL_REQUIREMENT,
		"scrap_available": second_scrap,
		"required_scrap": SCRAP_REQUIREMENT,
		"field_objective_persisted": GameState.field_objective_status(FIRST_CONTRACT_ID),
		"quest_ready_for_handin": GameState.is_active_quest_ready(),
		"debrief_role": second_debrief_role,
		"debrief": second_debrief,
		"last_result": second_result,
		"active_expedition_after_extraction": GameState.has_active_expedition(),
		"hp": GameState.hp,
		"death_pending": GameState.death_pending
	})
	if not _second_outing_completed or not _second_debrief_copy_valid or not GameState.is_active_quest_ready() or second_debrief.is_empty() or second_debrief_role != "撤離回報":
		return
	_second_outing_saved_evidence = _isolated_save_evidence()
	var saved_second_ledger: Dictionary = _second_outing_saved_evidence.get("expedition", {})
	var saved_second_result: Dictionary = saved_second_ledger.get("last_result", {})
	var saved_second_campaign: Dictionary = _second_outing_saved_evidence.get("campaign", {})
	_record_check("second_extraction_commits_completed_outing_and_debrief_to_isolated_save", bool(_second_outing_saved_evidence.get("checksum_valid", false)) and saved_second_ledger.get("active", {}) is Dictionary and saved_second_ledger.get("active", {}).is_empty() and String(saved_second_result.get("outcome", "")) == "extracted" and String(saved_second_result.get("campaign_outing", "")) == SECOND_OUTING_ID and int(saved_second_campaign.get("outing_index", -1)) == 2, "saved run ledger settled as extracted, second-outing report retained, campaign outing_index=2", _second_outing_saved_evidence)
	await _walk_to_guild_and_handin(tree)


func _walk_to_guild_and_handin(tree: SceneTree) -> void:
	var second_debrief_closed := await _dismiss_visible_dialogue("Escape: close second-outing extraction debrief")
	if not second_debrief_closed:
		_record_check("second_outing_debrief_closed_with_player_input", false, "HUD extraction report dismissed by injected Escape", _dialogue_evidence())
		return
	_record_check("second_outing_debrief_closed_with_player_input", true, "HUD extraction report dismissed by injected Escape", _dialogue_evidence())
	var village := tree.current_scene
	var village_player := _find_player(village)
	var guild_gate := _find_interactable(village, "to_guild")
	_record_check("second_return_Village_has_real_Guild_gate", village_player != null and guild_gate != null, "current Village player and authored to_guild interactable", {
		"player": _node_name(village_player),
		"gate": _node_name(guild_gate)
	})
	if village_player == null or guild_gate == null:
		return
	var reached_guild_gate := await _walk_until_interactable(village_player, guild_gate, 18000)
	_record_check("injected_WASD_reaches_Guild_after_second_extraction", reached_guild_gate and village_player.call("get_nearest_interaction_target") == guild_gate, "player selects physical Village-to-Guild gate after outing two", {
		"player_position": _vector_data(village_player.global_position),
		"gate_position": _vector_data(guild_gate.global_position)
	})
	if not reached_guild_gate:
		return
	var village_instance_id := village.get_instance_id()
	await _tap_key(KEY_E, "E: enter Guild through the real Village gate for hand-in")
	var guild_ready := await _wait_for_scene(GUILD_SCENE_PATH, "guild", 9)
	_record_check("second_return_Village_E_enters_Guild_through_SceneRouter", guild_ready, "Guild scene on normal transition 9", {
		"scene_ready": guild_ready,
		"village_instance_id": village_instance_id,
		"current_scene": _current_scene_evidence()
	})
	_record_persistent_root("after_second_village_to_guild")
	if not guild_ready:
		return

	var guild := tree.current_scene
	var guild_player := _find_player(guild)
	var reward_counter := _find_interactable(guild, "reward")
	_record_check("Guild_has_physical_reward_counter_and_player", guild_player != null and reward_counter != null, "Guild player and reward interactable counter", {
		"player": _node_name(guild_player),
		"counter": _node_name(reward_counter),
		"counter_position": _vector_data(reward_counter.global_position) if is_instance_valid(reward_counter) else []
	})
	if guild_player == null or reward_counter == null:
		return
	var reached_counter := await _walk_until_interactable(guild_player, reward_counter, 16000)
	var handin_requirements: Array[Dictionary] = GameState.active_quest_requirements()
	var handin_kills := GameState.quest_counter_value("defeat_enemy")
	var handin_scrap := GameState.quest_item_count("scrap")
	var pre_handin_inventory := GameState.inventory.duplicate(true)
	var pre_handin_xp := _lifetime_xp(int(GameState.level), int(GameState.xp))
	var pre_handin_state_ready: bool = reached_counter and guild_player.call("get_nearest_interaction_target") == reward_counter and GameState.active_quest_id == FIRST_CONTRACT_ID and GameState.is_active_quest_ready() and handin_kills >= KILL_REQUIREMENT and handin_scrap >= SCRAP_REQUIREMENT and int(pre_handin_inventory.get("scrap", 0)) >= SCRAP_REQUIREMENT and GameState.field_objective_status(FIRST_CONTRACT_ID) and int(GameState.quest_progress.get("campaign", {}).get("outing_index", -1)) == 2
	_record_check("ready_contract_and_original_5_kill_12_scrap_requirements_reach_Guild_counter", pre_handin_state_ready, "active contract ready at physical counter with outing 2/2, >=5 kills, >=12 banked scrap and field objective", {
		"player_at_counter": reached_counter,
		"selected_target": _node_name(guild_player.call("get_nearest_interaction_target")),
		"active_quest_id": GameState.active_quest_id,
		"requirements": handin_requirements,
		"kills": handin_kills,
		"scrap_count_for_objective": handin_scrap,
		"banked_scrap_inventory": pre_handin_inventory.get("scrap", 0),
		"campaign": GameState.quest_progress.get("campaign", {}),
		"field_objective": GameState.field_objective_status(FIRST_CONTRACT_ID),
		"counter_position": _vector_data(reward_counter.global_position),
		"player_position": _vector_data(guild_player.global_position)
	})
	if not pre_handin_state_ready:
		return

	var guild_hud := _current_hud()
	var guild_contract_panel := guild_hud.get("contract_panel") as Control if is_instance_valid(guild_hud) else null
	var guild_contract_list := guild_hud.get("contract_list") as VBoxContainer if is_instance_valid(guild_hud) else null
	var contract_panel_initially_hidden := is_instance_valid(guild_contract_panel) and not guild_contract_panel.visible
	_record_check("Guild_counter_can_open_live_contract_details_with_J_before_delivery", contract_panel_initially_hidden, "contract panel is closed before the real J key opens it at the Guild counter", {
		"hud_valid": is_instance_valid(guild_hud),
		"panel_valid": is_instance_valid(guild_contract_panel),
		"panel_visible_before_J": guild_contract_panel.visible if is_instance_valid(guild_contract_panel) else false,
		"player_selected_reward_counter": guild_player.call("get_nearest_interaction_target") == reward_counter
	})
	if is_instance_valid(guild_contract_panel):
		await _tap_key(KEY_J, "J: open the active Guild contract before physical delivery")
	var contract_panel_wait_started := Time.get_ticks_msec()
	while is_instance_valid(guild_contract_panel) and not guild_contract_panel.visible and Time.get_ticks_msec() - contract_panel_wait_started < 4000:
		await get_tree().process_frame
	var live_contract_panel_open := is_instance_valid(guild_contract_panel) and guild_contract_panel.visible
	var active_briefing_toggle := guild_contract_list.get_node_or_null("ContractNotes_ActiveQuestBriefing") as Button if is_instance_valid(guild_contract_list) else null
	var active_briefing_text := guild_contract_list.get_node_or_null("ContractFieldNotes_ActiveQuestBriefing") as Label if is_instance_valid(guild_contract_list) else null
	var briefing_focus_reached := false
	if live_contract_panel_open and is_instance_valid(active_briefing_toggle):
		briefing_focus_reached = await _focus_button_with_tab(active_briefing_toggle, 72)
	if briefing_focus_reached:
		await _tap_key(KEY_ENTER, "Enter: expand the visible active quest background and full contract terms")
	var briefing_wait_started := Time.get_ticks_msec()
	while is_instance_valid(active_briefing_text) and not active_briefing_text.visible and Time.get_ticks_msec() - briefing_wait_started < 4000:
		await get_tree().process_frame
	var live_contract_description := active_briefing_text.text if is_instance_valid(active_briefing_text) else ""
	var live_contract_description_visible := live_contract_panel_open and briefing_focus_reached and is_instance_valid(active_briefing_text) and active_briefing_text.visible
	_j_contract_copy_valid = live_contract_description_visible and live_contract_description.contains("擊退污染體 5 名與收集廢鐵 12 份是整章合計") and live_contract_description.contains("可跨兩趟累積")
	_record_check("live_J_contract_terms_explicitly_define_5_kills_and_12_scrap_across_both_outings", _j_contract_copy_valid, "opened Guild J panel and expanded its real active-contract text stating both thresholds are chapter totals that can accumulate across two trips", {
		"panel_open": live_contract_panel_open,
		"briefing_toggle_found": is_instance_valid(active_briefing_toggle),
		"briefing_toggle_focus_reached": briefing_focus_reached,
		"briefing_text_visible": live_contract_description_visible,
		"requires_chapter_total_text": "擊退污染體 5 名與收集廢鐵 12 份是整章合計",
		"requires_two_outings_text": "可跨兩趟累積",
		"visible_live_J_contract_text": live_contract_description
	})
	if live_contract_panel_open:
		await _tap_key(KEY_ESCAPE, "Escape: close live Guild J details before pressing the physical counter")
	var contract_panel_close_started := Time.get_ticks_msec()
	while is_instance_valid(guild_contract_panel) and guild_contract_panel.visible and Time.get_ticks_msec() - contract_panel_close_started < 4000:
		await get_tree().process_frame
	var contract_panel_closed_with_player_input := live_contract_panel_open and is_instance_valid(guild_contract_panel) and not guild_contract_panel.visible
	var reward_counter_still_selected_before_handin: bool = is_instance_valid(guild_player) and is_instance_valid(reward_counter) and guild_player.call("get_nearest_interaction_target") == reward_counter
	_record_check("live_J_contract_closed_and_physical_reward_counter_remains_selected", contract_panel_closed_with_player_input and reward_counter_still_selected_before_handin, "J panel closed by Escape while the player remains at the same physical reward counter", {
		"panel_closed_by_Escape": contract_panel_closed_with_player_input,
		"player_selected_reward_counter": reward_counter_still_selected_before_handin,
		"player_position": _vector_data(guild_player.global_position) if is_instance_valid(guild_player) else [],
		"counter_position": _vector_data(reward_counter.global_position) if is_instance_valid(reward_counter) else []
	})
	if not reward_counter_still_selected_before_handin:
		return

	await _tap_key(KEY_E, "E: deliver completed clear_scrap_route at the physical Guild counter")
	var handin_wait_started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - handin_wait_started < 8000 and GameState.active_quest_id == FIRST_CONTRACT_ID:
		await get_tree().process_frame
	var post_handin_inventory := GameState.inventory.duplicate(true)
	var post_handin_xp := _lifetime_xp(int(GameState.level), int(GameState.xp))
	var reward_definition := DataRegistry.get_quest(FIRST_CONTRACT_ID)
	var expected_inventory_delta := _expected_handin_inventory_delta(reward_definition)
	var observed_inventory_delta := _inventory_delta(pre_handin_inventory, post_handin_inventory)
	var handin_xp_delta := post_handin_xp - pre_handin_xp
	var handin_completed_state := GameState.active_quest_id.is_empty() and GameState.completed_quests.has(FIRST_CONTRACT_ID)
	var exact_handin_effects := expected_inventory_delta == observed_inventory_delta and handin_xp_delta == 35
	_guild_handin_completed = handin_completed_state and exact_handin_effects
	_handin_evidence = {
		"physical_interaction_id": String(reward_counter.get("interaction_id")),
		"active_quest_after": GameState.active_quest_id,
		"completed_quests_after": GameState.completed_quests.duplicate(),
		"expected_inventory_delta": expected_inventory_delta,
		"observed_inventory_delta": observed_inventory_delta,
		"scrap_before": pre_handin_inventory.get("scrap", 0),
		"scrap_after": post_handin_inventory.get("scrap", 0),
		"scrap_objective_consumed": SCRAP_REQUIREMENT,
		"scrap_net_delta_after_reward": int(observed_inventory_delta.get("scrap", 0)),
		"xp_total_before": pre_handin_xp,
		"xp_total_after": post_handin_xp,
		"xp_delta": handin_xp_delta,
		"level_after": GameState.level,
		"inventory_after": post_handin_inventory,
		"dialogue": _dialogue_evidence()
	}
	_record_check("physical_Guild_E_completes_handin_with_exact_12_scrap_and_single_reward_XP", _guild_handin_completed, "contract completed once; exactly 12 scrap consumed before +20 scrap reward; all reward items and +35 lifetime XP added once", _handin_evidence)
	if not _guild_handin_completed:
		return
	var saved_after_handin := _isolated_save_evidence()
	var saved_completed: Array = saved_after_handin.get("completed_quests", [])
	_record_check("successful_handin_is_written_to_isolated_save", bool(saved_after_handin.get("checksum_valid", false)) and String(saved_after_handin.get("active_quest_id", "")) == "" and saved_completed.has(FIRST_CONTRACT_ID), "checksummed Temp save contains completed contract and no active contract", saved_after_handin)

	var pre_reload_inventory := GameState.inventory.duplicate(true)
	var pre_reload_level := int(GameState.level)
	var pre_reload_xp_field := int(GameState.xp)
	var pre_reload_lifetime_xp := _lifetime_xp(pre_reload_level, pre_reload_xp_field)
	var pre_reload_scrap := int(pre_reload_inventory.get("scrap", 0))
	var pre_reload_completed := GameState.completed_quests.duplicate()
	var pre_reload_save_hash := String(saved_after_handin.get("payload_sha256", ""))
	var save_manager_reload_succeeded := SaveManager.load_game(false, false)
	await get_tree().process_frame
	var post_reload_inventory := GameState.inventory.duplicate(true)
	var post_reload_level := int(GameState.level)
	var post_reload_xp_field := int(GameState.xp)
	var post_reload_lifetime_xp := _lifetime_xp(post_reload_level, post_reload_xp_field)
	var post_reload_save_evidence := _isolated_save_evidence()
	var post_reload_inventory_delta := _inventory_delta(pre_handin_inventory, post_reload_inventory)
	var post_reload_state_matches := save_manager_reload_succeeded and GameState.active_quest_id.is_empty() and GameState.completed_quests == pre_reload_completed and GameState.completed_quests.has(FIRST_CONTRACT_ID) and post_reload_inventory == pre_reload_inventory and int(post_reload_inventory.get("scrap", 0)) == pre_reload_scrap and post_reload_inventory_delta == expected_inventory_delta and post_reload_level == pre_reload_level and post_reload_xp_field == pre_reload_xp_field and post_reload_lifetime_xp == pre_reload_lifetime_xp and not GameState.has_active_expedition() and GameState.current_scene_id == "guild" and String(tree.current_scene.scene_file_path) == GUILD_SCENE_PATH and bool(post_reload_save_evidence.get("checksum_valid", false)) and String(post_reload_save_evidence.get("payload_sha256", "")) == pre_reload_save_hash
	_post_handin_reload_valid = post_reload_state_matches
	_handin_evidence["save_manager_reload"] = {
		"method": "SaveManager.load_game(false, false)",
		"load_succeeded": save_manager_reload_succeeded,
		"active_quest_after": GameState.active_quest_id,
		"completed_quests_before": pre_reload_completed,
		"completed_quests_after": GameState.completed_quests.duplicate(),
		"scrap_before_reload": pre_reload_scrap,
		"scrap_after_reload": post_reload_inventory.get("scrap", 0),
		"inventory_before_reload": pre_reload_inventory,
		"inventory_after_reload": post_reload_inventory,
		"expected_reward_delta_after_reload": expected_inventory_delta,
		"observed_reward_delta_after_reload": post_reload_inventory_delta,
		"level_before_reload": pre_reload_level,
		"level_after_reload": post_reload_level,
		"xp_field_before_reload": pre_reload_xp_field,
		"xp_field_after_reload": post_reload_xp_field,
		"lifetime_xp_before_reload": pre_reload_lifetime_xp,
		"lifetime_xp_after_reload": post_reload_lifetime_xp,
		"scene_after_reload": _current_scene_evidence(),
		"active_expedition_after_reload": GameState.has_active_expedition(),
		"save_checksum_valid_after_reload": post_reload_save_evidence.get("checksum_valid", false),
		"save_payload_hash_before_reload": pre_reload_save_hash,
		"save_payload_hash_after_reload": post_reload_save_evidence.get("payload_sha256", ""),
		"save_unchanged_by_reload": String(post_reload_save_evidence.get("payload_sha256", "")) == pre_reload_save_hash
	}
	_record_check("SaveManager_data_only_reload_preserves_completed_contract_scrap_rewards_and_XP", _post_handin_reload_valid, "after the actual checksummed hand-in save is loaded, active quest stays empty, completion remains recorded, 12 scrap remains consumed, all reward inventory and XP match, and no scene change occurs", _handin_evidence.get("save_manager_reload", {}))
	if not _post_handin_reload_valid:
		return

	var contract_report_closed := await _dismiss_visible_dialogue("Escape: close first Guild contract-completion report")
	if not contract_report_closed:
		_record_check("Guild_completion_report_closed_with_player_input_before_repeat", false, "HUD hand-in report dismissed by injected Escape", _dialogue_evidence())
		return
	_record_check("Guild_completion_report_closed_with_player_input_before_repeat", true, "HUD hand-in report dismissed by injected Escape", _dialogue_evidence())
	var before_repeat_inventory := GameState.inventory.duplicate(true)
	var before_repeat_xp := _lifetime_xp(int(GameState.level), int(GameState.xp))
	var before_repeat_level := int(GameState.level)
	var before_repeat_completed: Array[String] = GameState.completed_quests.duplicate()
	var saved_before_repeat := _isolated_save_evidence()
	var guild_player_still_at_counter: bool = is_instance_valid(guild_player) and guild_player.call("get_nearest_interaction_target") == reward_counter
	_record_check("player_remains_at_same_Guild_counter_for_duplicate_delivery_input", guild_player_still_at_counter, "same physical reward interactable selected after closing report", {
		"player_position": _vector_data(guild_player.global_position) if is_instance_valid(guild_player) else [],
		"counter_position": _vector_data(reward_counter.global_position),
		"selected_target": _node_name(guild_player.call("get_nearest_interaction_target")) if is_instance_valid(guild_player) else "invalid"
	})
	if not guild_player_still_at_counter:
		return
	await _tap_key(KEY_E, "E: repeat delivery at the same physical Guild counter")
	await get_tree().process_frame
	var after_repeat_inventory := GameState.inventory.duplicate(true)
	var after_repeat_xp := _lifetime_xp(int(GameState.level), int(GameState.xp))
	var saved_after_repeat := _isolated_save_evidence()
	_repeat_handin_unchanged = GameState.active_quest_id.is_empty() and GameState.level == before_repeat_level and after_repeat_xp == before_repeat_xp and after_repeat_inventory == before_repeat_inventory and GameState.completed_quests == before_repeat_completed and String(saved_after_repeat.get("payload_sha256", "")) == String(saved_before_repeat.get("payload_sha256", ""))
	_handin_evidence["repeat"] = {
		"active_quest_after": GameState.active_quest_id,
		"inventory_unchanged": after_repeat_inventory == before_repeat_inventory,
		"xp_unchanged": after_repeat_xp == before_repeat_xp,
		"level_unchanged": GameState.level == before_repeat_level,
		"completed_quests_unchanged": GameState.completed_quests == before_repeat_completed,
		"save_payload_hash_before": saved_before_repeat.get("payload_sha256", ""),
		"save_payload_hash_after": saved_after_repeat.get("payload_sha256", ""),
		"save_unchanged": String(saved_after_repeat.get("payload_sha256", "")) == String(saved_before_repeat.get("payload_sha256", ""))
	}
	_record_check("repeat_Guild_counter_E_does_not_duplicate_rewards_XP_or_save_changes", _repeat_handin_unchanged, "second player E leaves inventory, XP, level, completed contract and saved payload unchanged", _handin_evidence.get("repeat", {}))
	_record_check("full_first_contract_journey_finishes_alive_in_Guild", GameState.current_scene_id == "guild" and tree.current_scene.scene_file_path == GUILD_SCENE_PATH and GameState.hp > 0 and not GameState.death_pending and not GameState.has_active_expedition() and _transition_events.size() == 9 and _all_transitions_succeeded(), "Guild after 9 successful scene transitions, living player, no active expedition", {
		"scene": _current_scene_evidence(),
		"hp": GameState.hp,
		"death_pending": GameState.death_pending,
		"active_expedition": GameState.has_active_expedition(),
		"transitions": _transition_events
	})


func _current_hud() -> Node:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	for candidate: Node in get_tree().get_nodes_in_group("hud"):
		if is_instance_valid(candidate) and scene.is_ancestor_of(candidate):
			return candidate
	return null


func _dialogue_evidence() -> Dictionary:
	var hud := _current_hud()
	if not is_instance_valid(hud):
		return {"hud_valid": false}
	var panel := hud.get("dialogue_panel") as Control
	var role := hud.get("dialogue_role") as Label
	var body := hud.get("dialogue_body") as Label
	return {
		"hud_valid": true,
		"dialogue_visible": is_instance_valid(panel) and panel.is_visible_in_tree(),
		"role": role.text if is_instance_valid(role) else "",
		"body": body.text if is_instance_valid(body) else ""
	}


func _dismiss_visible_dialogue(description: String) -> bool:
	var hud := _current_hud()
	if not is_instance_valid(hud):
		return false
	var panel := hud.get("dialogue_panel") as Control
	if not is_instance_valid(panel) or not panel.is_visible_in_tree():
		return true
	await _tap_key(KEY_ESCAPE, description)
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 3000:
		if not is_instance_valid(panel) or not panel.is_visible_in_tree():
			return true
		await get_tree().process_frame
	return not is_instance_valid(panel) or not panel.is_visible_in_tree()


func _campaign_option_button(hud: Node, state: Dictionary, option_id: String) -> Button:
	if not is_instance_valid(hud):
		return null
	var options_container := hud.get("campaign_choice_options") as VBoxContainer
	if not is_instance_valid(options_container):
		return null
	var options: Array = state.get("options", [])
	for index in range(options.size()):
		var option_value: Variant = options[index]
		if not option_value is Dictionary or String(option_value.get("id", "")) != option_id or index >= options_container.get_child_count():
			continue
		var card := options_container.get_child(index)
		return card.find_child("ChooseCampaignOptionButton", true, false) as Button
	return null


func _follow_carry_action(player: Node2D, action: Node2D, timeout_ms: int) -> Dictionary:
	var started := Time.get_ticks_msec()
	var steps: Array[Dictionary] = []
	var action_id := String(action.get("action_id")) if is_instance_valid(action) else ""
	var waypoints := _path_points(action.get("_waypoints")) if is_instance_valid(action) else []
	var wave_count := int(action.get("_wave_count")) if is_instance_valid(action) else 0
	var failure_phase := ""
	if not is_instance_valid(player) or not is_instance_valid(action) or action_id != SECOND_CARRY_ACTION_ID or waypoints.is_empty():
		return {"reached": false, "failure_phase": "invalid_player_action_or_waypoints", "waypoint_count": waypoints.size()}
	for index in range(waypoints.size()):
		if GameState.campaign_action_status(action_id) == "done":
			break
		if not is_instance_valid(player) or not is_instance_valid(action) or GameState.hp <= 0 or GameState.death_pending:
			failure_phase = "player_or_action_invalid_or_dead"
			break
		var remaining := maxi(0, timeout_ms - (Time.get_ticks_msec() - started))
		if remaining <= 0:
			failure_phase = "carry_route_timeout_before_waypoint_%d" % index
			break
		var waypoint: Vector2 = waypoints[index]
		var walk_started := Time.get_ticks_msec()
		var walk_reached := await _walk_to_position(player, waypoint, remaining, true)
		var step := {
			"index": index,
			"waypoint": _vector_data(waypoint),
			"walk_reached": walk_reached,
			"walk_elapsed_ms": Time.get_ticks_msec() - walk_started,
			"checkpoint_before": int(GameState.campaign_action_progress(action_id).get("checkpoint", 0)),
			"wave_index": index if index < wave_count else -1
		}
		if not walk_reached:
			failure_phase = "carry_route_waypoint_%d_not_reached" % index
			steps.append(step)
			break
		if index < wave_count:
			var spawn_started := Time.get_ticks_msec()
			var wave_spawned := false
			while Time.get_ticks_msec() - spawn_started < 8000:
				if int(action.get("_spawned_wave_index")) == index or not _campaign_wave_evidence(action_id, index).is_empty():
					wave_spawned = true
					break
				if int(GameState.campaign_action_progress(action_id).get("checkpoint", 0)) > index or GameState.campaign_action_status(action_id) == "done":
					break
				if GameState.hp <= 0 or GameState.death_pending:
					break
				await get_tree().process_frame
			step["wave_spawn_observed"] = wave_spawned
			step["wave_enemies_before_clear"] = _campaign_wave_evidence(action_id, index)
			if not wave_spawned:
				failure_phase = "authored_carry_wave_%d_not_spawned" % index
				steps.append(step)
				break
			var combat := await _clear_campaign_wave(player, action_id, index, maxi(1, timeout_ms - (Time.get_ticks_msec() - started)))
			step["wave_combat"] = combat
			var checkpoint_wait_started := Time.get_ticks_msec()
			while Time.get_ticks_msec() - checkpoint_wait_started < 8000:
				if int(GameState.campaign_action_progress(action_id).get("checkpoint", 0)) > index or GameState.campaign_action_status(action_id) == "done":
					break
				if GameState.hp <= 0 or GameState.death_pending:
					break
				await get_tree().process_frame
			step["checkpoint_after_wave"] = int(GameState.campaign_action_progress(action_id).get("checkpoint", 0))
			if not bool(combat.get("cleared", false)) or int(step["checkpoint_after_wave"]) <= index:
				failure_phase = "authored_carry_wave_%d_not_cleared" % index
				steps.append(step)
				break
		else:
			var checkpoint_started := Time.get_ticks_msec()
			while Time.get_ticks_msec() - checkpoint_started < 8000:
				if int(GameState.campaign_action_progress(action_id).get("checkpoint", 0)) > index or GameState.campaign_action_status(action_id) == "done":
					break
				if GameState.hp <= 0 or GameState.death_pending:
					break
				await get_tree().process_frame
			step["checkpoint_after_walk"] = int(GameState.campaign_action_progress(action_id).get("checkpoint", 0))
			if int(step["checkpoint_after_walk"]) <= index and GameState.campaign_action_status(action_id) != "done":
				failure_phase = "carry_checkpoint_%d_not_advanced" % index
				steps.append(step)
				break
		steps.append(step)
	var reached := GameState.campaign_action_status(action_id) == "done" and failure_phase.is_empty()
	_set_movement_keys([])
	return {
		"reached": reached,
		"failure_phase": failure_phase,
		"action_id": action_id,
		"selected_route": GameState.campaign_selected_choice(SECOND_CHOICE_ACTION_ID),
		"waypoint_count": waypoints.size(),
		"wave_count": wave_count,
		"steps": steps,
		"campaign_action_status": GameState.campaign_action_status(action_id),
		"runtime": GameState.campaign_action_progress(action_id),
		"player_position": _vector_data(player.global_position) if is_instance_valid(player) else [],
		"player_hp": GameState.hp,
		"death_pending": GameState.death_pending,
		"elapsed_ms": Time.get_ticks_msec() - started
	}


func _clear_campaign_wave(player: Node2D, action_id: String, wave_index: int, timeout_ms: int) -> Dictionary:
	var started := Time.get_ticks_msec()
	var combat_events: Array[Dictionary] = []
	var saw_wave_enemy: bool = not _campaign_wave_evidence(action_id, wave_index).is_empty()
	var failure_reason := ""
	while Time.get_ticks_msec() - started < timeout_ms:
		if not is_instance_valid(player) or GameState.hp <= 0 or GameState.death_pending:
			failure_reason = "player_dead_or_invalid"
			break
		var target := _nearest_campaign_wave_enemy(player.global_position, action_id, wave_index)
		if target == null:
			break
		saw_wave_enemy = true
		if _combat_attack_count >= MAX_RUN_MELEE_ATTACKS:
			failure_reason = "journey_melee_attack_cap_reached"
			break
		var distance := player.global_position.distance_to(target.global_position)
		if distance > 104.0:
			var remaining_for_approach := maxi(1, timeout_ms - (Time.get_ticks_msec() - started))
			var approach_position := target.global_position
			var approach_reached := await _walk_to_position(player, approach_position, mini(9000, remaining_for_approach), true)
			combat_events.append({
				"event": "approach_tagged_wave_enemy",
				"enemy_id": str(target.get("enemy_id")) if is_instance_valid(target) else "removed",
				"distance_before": distance,
				"walk_reached": approach_reached,
				"player_position": _vector_data(player.global_position) if is_instance_valid(player) else [],
				"enemy_position": _vector_data(target.global_position) if is_instance_valid(target) else []
			})
			continue
		var remaining_for_attack := maxi(1, timeout_ms - (Time.get_ticks_msec() - started))
		var attack_limit := mini(8, MAX_RUN_MELEE_ATTACKS - _combat_attack_count)
		var combat_response := await _clear_close_enemies_with_space(player, mini(12000, remaining_for_attack), attack_limit)
		combat_response["stage"] = "campaign_carry_%s_wave_%d" % [action_id, wave_index]
		combat_events.append(combat_response)
		_combat_responses.append(combat_response)
		_combat_attack_count += int(combat_response.get("attack_count", 0))
		if int(combat_response.get("attack_count", 0)) <= 0:
			await get_tree().process_frame
	var enemies_after := _campaign_wave_evidence(action_id, wave_index)
	var checkpoint := int(GameState.campaign_action_progress(action_id).get("checkpoint", 0))
	var cleared := saw_wave_enemy and enemies_after.is_empty()
	return {
		"cleared": cleared,
		"wave_index": wave_index,
		"saw_wave_enemy": saw_wave_enemy,
		"combat_events": combat_events,
		"remaining_tagged_enemies": enemies_after,
		"checkpoint": checkpoint,
		"failure_reason": failure_reason,
		"player_hp": GameState.hp,
		"death_pending": GameState.death_pending,
		"elapsed_ms": Time.get_ticks_msec() - started
	}


func _campaign_wave_evidence(action_id: String, wave_index: int) -> Array[Dictionary]:
	var enemies: Array[Dictionary] = []
	for raw_enemy: Variant in get_tree().get_nodes_in_group("enemy"):
		var enemy := raw_enemy as Node2D
		if enemy == null or not is_instance_valid(enemy) or bool(enemy.get("is_dead")) or int(enemy.get("hp")) <= 0:
			continue
		if String(enemy.get_meta("campaign_action_id", "")) != action_id or int(enemy.get_meta("campaign_wave_index", -1)) != wave_index:
			continue
		enemies.append({
			"enemy_id": str(enemy.get("enemy_id")),
			"hp": int(enemy.get("hp")),
			"position": _vector_data(enemy.global_position)
		})
	enemies.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return int(left["hp"]) < int(right["hp"]))
	return enemies


func _nearest_campaign_wave_enemy(center: Vector2, action_id: String, wave_index: int) -> Node2D:
	var nearest: Node2D = null
	var nearest_distance := INF
	for raw_enemy: Variant in get_tree().get_nodes_in_group("enemy"):
		var enemy := raw_enemy as Node2D
		if enemy == null or not is_instance_valid(enemy) or bool(enemy.get("is_dead")) or int(enemy.get("hp")) <= 0:
			continue
		if String(enemy.get_meta("campaign_action_id", "")) != action_id or int(enemy.get_meta("campaign_wave_index", -1)) != wave_index:
			continue
		var distance := center.distance_to(enemy.global_position)
		if distance < nearest_distance:
			nearest = enemy
			nearest_distance = distance
	return nearest


func _defeat_remaining_contract_kills(player: Node2D, timeout_ms: int) -> Dictionary:
	var started := Time.get_ticks_msec()
	var before := GameState.quest_counter_value("defeat_enemy")
	var responses: Array[Dictionary] = []
	var failure_reason := ""
	while GameState.quest_counter_value("defeat_enemy") < KILL_REQUIREMENT and Time.get_ticks_msec() - started < timeout_ms:
		if not is_instance_valid(player) or GameState.hp <= 0 or GameState.death_pending:
			failure_reason = "player_dead_or_invalid"
			break
		var target := _nearest_non_campaign_enemy(player.global_position)
		if target == null:
			await get_tree().create_timer(0.5).timeout
			continue
		var distance := player.global_position.distance_to(target.global_position)
		if distance > 104.0:
			var toward_player := (player.global_position - target.global_position).normalized()
			if toward_player == Vector2.ZERO:
				toward_player = Vector2.DOWN
			var approach := target.global_position + toward_player * 76.0
			var approach_timeout := mini(7000, maxi(1, timeout_ms - (Time.get_ticks_msec() - started)))
			var reached := await _walk_to_position(player, approach, approach_timeout, false)
			responses.append({
				"event": "approach_regular_enemy",
				"enemy_id": str(target.get("enemy_id")) if is_instance_valid(target) else "removed",
				"distance_before": distance,
				"approach_reached": reached,
				"player_position": _vector_data(player.global_position) if is_instance_valid(player) else []
			})
			continue
		if _combat_attack_count >= MAX_RUN_MELEE_ATTACKS:
			failure_reason = "journey_melee_attack_cap_reached"
			break
		var attack_limit := mini(8, MAX_RUN_MELEE_ATTACKS - _combat_attack_count)
		var response := await _clear_close_enemies_with_space(player, mini(10000, maxi(1, timeout_ms - (Time.get_ticks_msec() - started))), attack_limit)
		response["stage"] = "contract_kill_requirement_top_up"
		responses.append(response)
		_combat_responses.append(response)
		_combat_attack_count += int(response.get("attack_count", 0))
		if int(response.get("attack_count", 0)) <= 0:
			await get_tree().process_frame
	var after := GameState.quest_counter_value("defeat_enemy")
	return {
		"reached_requirement": after >= KILL_REQUIREMENT,
		"kills_before": before,
		"kills_after": after,
		"required": KILL_REQUIREMENT,
		"events": responses,
		"failure_reason": failure_reason,
		"player_hp": GameState.hp,
		"death_pending": GameState.death_pending,
		"elapsed_ms": Time.get_ticks_msec() - started
	}


func _nearest_non_campaign_enemy(center: Vector2) -> Node2D:
	var nearest: Node2D = null
	var nearest_distance := INF
	for raw_enemy: Variant in get_tree().get_nodes_in_group("enemy"):
		var enemy := raw_enemy as Node2D
		if enemy == null or not is_instance_valid(enemy) or bool(enemy.get("is_dead")) or int(enemy.get("hp")) <= 0 or enemy.has_meta("campaign_action_id") or enemy.has_meta("exploration_guard"):
			continue
		var distance := center.distance_to(enemy.global_position)
		if distance < nearest_distance:
			nearest = enemy
			nearest_distance = distance
	return nearest


func _isolated_save_evidence() -> Dictionary:
	var path := ProjectSettings.globalize_path("user://save_game.json")
	var evidence: Dictionary = {
		"path": path,
		"inside_isolated_root": _is_path_within(path, _isolated_root),
		"isolation_validated": _isolation_validated,
		"file_exists": FileAccess.file_exists("user://save_game.json"),
		"checksum_valid": false
	}
	if not _isolation_validated or not bool(evidence["inside_isolated_root"]) or not bool(evidence["file_exists"]):
		return evidence
	var file := FileAccess.open("user://save_game.json", FileAccess.READ)
	if file == null:
		evidence["read_error"] = FileAccess.get_open_error()
		return evidence
	var wrapper_value: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not wrapper_value is Dictionary:
		evidence["wrapper_valid"] = false
		return evidence
	var wrapper: Dictionary = wrapper_value
	var payload_text := Marshalls.base64_to_utf8(String(wrapper.get("payload", "")))
	var checksum := String(wrapper.get("checksum", ""))
	var checksum_valid := not payload_text.is_empty() and payload_text.sha256_text() == checksum
	evidence["wrapper_valid"] = true
	evidence["checksum_valid"] = checksum_valid
	evidence["payload_sha256"] = payload_text.sha256_text() if not payload_text.is_empty() else ""
	if not checksum_valid:
		return evidence
	var save_value: Variant = JSON.parse_string(payload_text)
	if not save_value is Dictionary:
		evidence["payload_valid"] = false
		return evidence
	var saved: Dictionary = save_value
	var expedition: Dictionary = saved.get("expedition", {}) if saved.get("expedition", {}) is Dictionary else {}
	var campaign: Dictionary = saved.get("quest_progress", {}).get("campaign", {}) if saved.get("quest_progress", {}) is Dictionary and saved.get("quest_progress", {}).get("campaign", {}) is Dictionary else {}
	evidence.merge({
		"payload_valid": true,
		"scene": String(saved.get("scene", "")),
		"active_quest_id": String(saved.get("active_quest_id", "")),
		"completed_quests": saved.get("completed_quests", []).duplicate() if saved.get("completed_quests", []) is Array else [],
		"campaign": campaign.duplicate(true),
		"expedition": expedition.duplicate(true)
	}, true)
	return evidence


func _lifetime_xp(level_value: int, xp_value: int) -> int:
	var total := xp_value
	for prior_level in range(1, level_value):
		total += 80 + (prior_level - 1) * 45
	return total


func _expected_handin_inventory_delta(quest: Dictionary) -> Dictionary:
	var delta: Dictionary = {}
	for objective_value in quest.get("objectives", []):
		if not objective_value is Dictionary or String(objective_value.get("type", "")) != "collect":
			continue
		var item_id := String(objective_value.get("item", ""))
		delta[item_id] = int(delta.get(item_id, 0)) - int(objective_value.get("amount", 0))
	for item_id: String in quest.get("reward", {}):
		delta[item_id] = int(delta.get(item_id, 0)) + int(quest["reward"][item_id])
	for item_id: String in delta.keys():
		if int(delta[item_id]) == 0:
			delta.erase(item_id)
	return delta


func _inventory_delta(before: Dictionary, after: Dictionary) -> Dictionary:
	var keys: Array[String] = []
	for item_id: Variant in before.keys():
		keys.append(String(item_id))
	for item_id: Variant in after.keys():
		if not keys.has(String(item_id)):
			keys.append(String(item_id))
	var delta: Dictionary = {}
	for item_id: String in keys:
		var difference := int(after.get(item_id, 0)) - int(before.get(item_id, 0))
		if difference != 0:
			delta[item_id] = difference
	return delta


func _validate_isolation() -> bool:
	var temp_root := OS.get_environment("TEMP")
	var actual_user_dir := OS.get_user_data_dir()
	var custom_user_dir_enabled := bool(ProjectSettings.get_setting("application/config/use_custom_user_dir", false))
	var custom_user_dir_name := String(ProjectSettings.get_setting("application/config/custom_user_dir_name", ""))
	var report_under_temp := _is_path_within(_report_path, temp_root)
	var isolated_root_under_temp := _is_path_within(_isolated_root, temp_root)
	var user_dir_under_isolated_root := _is_path_within(actual_user_dir, _isolated_root)
	var report_under_isolated_root := _is_path_within(_report_path, _isolated_root)
	var expected_custom_user_dir_name := "FirstGame-QA-" + _run_id
	var custom_name_matches_run_id := not _run_id.is_empty() and custom_user_dir_name == expected_custom_user_dir_name
	_record_check("report_path_is_under_Temp", report_under_temp, temp_root, _report_path)
	_record_check("isolated_root_is_under_Temp", isolated_root_under_temp, temp_root, _isolated_root)
	_record_check("report_path_is_under_explicit_run_root", report_under_isolated_root, _isolated_root, _report_path)
	_record_check("user_data_dir_resolves_inside_explicit_Temp_root", user_dir_under_isolated_root, _isolated_root, actual_user_dir)
	_record_check("project_uses_custom_user_dir_exactly_matching_run_id", custom_user_dir_enabled and custom_name_matches_run_id, expected_custom_user_dir_name, {
		"enabled": custom_user_dir_enabled,
		"configured_name": custom_user_dir_name,
		"run_id": _run_id
	})
	var storage_is_safe := report_under_temp and isolated_root_under_temp and report_under_isolated_root and user_dir_under_isolated_root and custom_user_dir_enabled and custom_name_matches_run_id
	if not storage_is_safe:
		_record_check("isolated_save_absent_before_start", false, "save check only after isolation is verified", "not checked because path isolation failed")
		return false
	_isolation_validated = true
	_isolated_save_path = ProjectSettings.globalize_path("user://save_game.json")
	var save_existed_before := FileAccess.file_exists("user://save_game.json")
	_record_check("isolated_save_absent_before_start", not save_existed_before, "no save_game.json in fresh isolated profile", save_existed_before)
	return not save_existed_before


func _wait_for_title() -> bool:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < JOURNEY_TIMEOUT_MS:
		var scene := get_tree().current_scene
		if scene != null and scene.scene_file_path == MAIN_SCENE_PATH:
			var button := scene.get("new_game_button") as Button
			if is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled:
				return true
		await get_tree().process_frame
	return false


func _wait_for_intro(main_scene: Node) -> bool:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 10000:
		if not is_instance_valid(main_scene):
			return false
		if bool(main_scene.get("intro_active")):
			return true
		await get_tree().process_frame
	return false


func _wait_for_scene(expected_path: String, expected_scene_id: String, expected_transition_count: int) -> bool:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < JOURNEY_TIMEOUT_MS:
		var scene := get_tree().current_scene
		var path_matches := scene != null and scene.scene_file_path == expected_path
		var id_matches := String(GameState.current_scene_id) == expected_scene_id
		var transition_complete := not SceneRouter.is_transition_pending() and _transition_events.size() >= expected_transition_count
		if path_matches and id_matches and transition_complete:
			return true
		await get_tree().process_frame
	return false


func _walk_until_interactable(player: Node2D, target: Node2D, timeout_ms: int, monitor_nearby_combat: bool = false) -> bool:
	if not is_instance_valid(player) or not is_instance_valid(target):
		_set_movement_keys([])
		return false
	var route_started := Time.get_ticks_msec()
	var remaining := timeout_ms
	var route_id := str(target.get("interaction_id"))
	if route_id == "to_guild":
		var gate_position := target.global_position
		var approach_y := maxf(96.0, gate_position.y - 150.0)
		var waypoints := [
			Vector2(player.global_position.x, approach_y),
			Vector2(gate_position.x - 180.0, approach_y)
		]
		for waypoint: Vector2 in waypoints:
			remaining = maxi(0, timeout_ms - (Time.get_ticks_msec() - route_started))
			if remaining <= 0 or not await _walk_to_position(player, waypoint, remaining, monitor_nearby_combat):
				return false
			if not is_instance_valid(player) or not is_instance_valid(target):
				return false
			if _target_is_selected(player, target):
				_set_movement_keys([])
				return true
	elif route_id == "to_wasteland":
		# The reward counter and signal pylon sit across the direct path from the
		# contract board. Follow the open south aisle before approaching the gate.
		var gate_position := target.global_position
		var map_size: Vector2 = get_tree().current_scene.get_meta("map_world_size", Vector2(1664.0, 1088.0))
		var world_bottom := map_size.y - 96.0
		var approach_y := minf(gate_position.y + 80.0, world_bottom)
		var waypoints := [
			Vector2(player.global_position.x, approach_y),
			Vector2(maxf(96.0, gate_position.x - 240.0), approach_y)
		]
		for waypoint: Vector2 in waypoints:
			remaining = maxi(0, timeout_ms - (Time.get_ticks_msec() - route_started))
			if remaining <= 0 or not await _walk_to_position(player, waypoint, remaining, monitor_nearby_combat):
				return false
			if not is_instance_valid(player) or not is_instance_valid(target):
				return false
			if _target_is_selected(player, target):
				_set_movement_keys([])
				return true
	remaining = maxi(0, timeout_ms - (Time.get_ticks_msec() - route_started))
	if remaining <= 0:
		return false
	return await _walk_into_interaction_range(player, target, remaining, monitor_nearby_combat)


func _walk_into_interaction_range(player: Node2D, target: Node2D, timeout_ms: int, monitor_nearby_combat: bool = false) -> bool:
	if not is_instance_valid(player) or not is_instance_valid(target):
		_set_movement_keys([])
		return false
	var started := Time.get_ticks_msec()
	var best_distance := player.global_position.distance_to(target.global_position)
	var stalled_frames := 0
	while Time.get_ticks_msec() - started < timeout_ms:
		if not is_instance_valid(player) or not is_instance_valid(target):
			_set_movement_keys([])
			return false
		if _target_is_selected(player, target):
			_set_movement_keys([])
			await get_tree().process_frame
			return is_instance_valid(player) and is_instance_valid(target) and _target_is_selected(player, target)

		var delta := target.global_position - player.global_position
		var movement_keys: Array[int] = []
		if absf(delta.x) >= absf(delta.y):
			if absf(delta.x) > 28.0:
				movement_keys.append(KEY_D if delta.x > 0.0 else KEY_A)
			elif absf(delta.y) > 28.0:
				movement_keys.append(KEY_S if delta.y > 0.0 else KEY_W)
		else:
			if absf(delta.y) > 28.0:
				movement_keys.append(KEY_S if delta.y > 0.0 else KEY_W)
			elif absf(delta.x) > 28.0:
				movement_keys.append(KEY_D if delta.x > 0.0 else KEY_A)
		_set_movement_keys(movement_keys)
		await get_tree().physics_frame
		await get_tree().process_frame
		if not is_instance_valid(player) or not is_instance_valid(target):
			_set_movement_keys([])
			return false
		if monitor_nearby_combat and GameState.hp > 0 and not GameState.death_pending and _combat_attack_count < MAX_RUN_MELEE_ATTACKS:
			var close_enemy := _nearest_living_enemy(player.global_position, 120.0)
			if close_enemy != null:
				_set_movement_keys([])
				var remaining_for_attack := maxi(1, timeout_ms - (Time.get_ticks_msec() - started))
				var attack_budget := mini(2, MAX_RUN_MELEE_ATTACKS - _combat_attack_count)
				var combat_response := await _clear_close_enemies_with_space(player, mini(6000, remaining_for_attack), attack_budget)
				combat_response["stage"] = "extraction_gate_approach"
				_combat_responses.append(combat_response)
				_combat_attack_count += int(combat_response.get("attack_count", 0))
				if not is_instance_valid(player) or not is_instance_valid(target) or GameState.hp <= 0 or GameState.death_pending:
					_set_movement_keys([])
					return false
				best_distance = player.global_position.distance_to(target.global_position)
				stalled_frames = 0
				continue

		var distance := player.global_position.distance_to(target.global_position)
		if distance + 0.5 < best_distance:
			best_distance = distance
			stalled_frames = 0
		else:
			stalled_frames += 1
		if stalled_frames >= 180:
			break
	_set_movement_keys([])
	return false


func _walk_player_path(player: Node2D, waypoints: Array[Vector2], timeout_ms: int) -> Dictionary:
	var started := Time.get_ticks_msec()
	var completed_waypoints := 0
	var recentered_waypoints := 0
	var failed_target := Vector2.ZERO
	if not is_instance_valid(player):
		return {
			"reached": false,
			"completed_waypoints": completed_waypoints,
			"recentered_waypoints": recentered_waypoints,
			"failed_target": [],
			"failure_phase": "player_invalid_before_path",
			"player_position": [],
			"elapsed_ms": Time.get_ticks_msec() - started
		}
	for waypoint: Vector2 in waypoints:
		if not is_instance_valid(player):
			_set_movement_keys([])
			return {
				"reached": false,
				"completed_waypoints": completed_waypoints,
				"recentered_waypoints": recentered_waypoints,
				"failed_target": _vector_data(waypoint),
				"failure_phase": "player_freed_during_path",
				"player_position": [],
				"elapsed_ms": Time.get_ticks_msec() - started
			}
		var remaining := maxi(0, timeout_ms - (Time.get_ticks_msec() - started))
		if remaining <= 0:
			_set_movement_keys([])
			return {
				"reached": false,
				"completed_waypoints": completed_waypoints,
				"recentered_waypoints": recentered_waypoints,
				"failed_target": _vector_data(waypoint),
				"failure_phase": "route_waypoint_timeout",
				"player_position": _vector_data(player.global_position) if is_instance_valid(player) else [],
				"elapsed_ms": Time.get_ticks_msec() - started
			}
		if absf(player.global_position.x - waypoint.x) > 64.0:
			var centerline_target := Vector2(waypoint.x, player.global_position.y)
			if not await _walk_to_position(player, centerline_target, remaining, true):
				_set_movement_keys([])
				return {
					"reached": false,
					"completed_waypoints": completed_waypoints,
					"recentered_waypoints": recentered_waypoints,
					"failed_target": _vector_data(centerline_target),
					"failure_phase": "authored_road_centerline_recovery",
					"player_position": _vector_data(player.global_position) if is_instance_valid(player) else [],
					"elapsed_ms": Time.get_ticks_msec() - started
				}
			recentered_waypoints += 1
			remaining = maxi(0, timeout_ms - (Time.get_ticks_msec() - started))
		if remaining <= 0 or not await _walk_to_position(player, waypoint, remaining, true):
			_set_movement_keys([])
			failed_target = waypoint
			return {
				"reached": false,
				"completed_waypoints": completed_waypoints,
				"recentered_waypoints": recentered_waypoints,
				"failed_target": _vector_data(failed_target),
				"failure_phase": "authored_road_waypoint",
				"player_position": _vector_data(player.global_position) if is_instance_valid(player) else [],
				"elapsed_ms": Time.get_ticks_msec() - started
			}
		completed_waypoints += 1
	_set_movement_keys([])
	return {
		"reached": completed_waypoints == waypoints.size(),
		"completed_waypoints": completed_waypoints,
		"recentered_waypoints": recentered_waypoints,
		"failed_target": _vector_data(failed_target),
		"player_position": _vector_data(player.global_position) if is_instance_valid(player) else [],
		"elapsed_ms": Time.get_ticks_msec() - started
	}


func _nearby_enemy_evidence(center: Vector2, radius: float) -> Array[Dictionary]:
	var nearby: Array[Dictionary] = []
	for raw_enemy: Variant in get_tree().get_nodes_in_group("enemy"):
		var enemy := raw_enemy as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		var distance := center.distance_to(enemy.global_position)
		if distance > radius:
			continue
		nearby.append({
			"enemy_id": str(enemy.get("enemy_id")),
			"hp": int(enemy.get("hp")),
			"distance": distance,
			"position": _vector_data(enemy.global_position)
		})
	nearby.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return float(left["distance"]) < float(right["distance"]))
	if nearby.size() > 8:
		nearby.resize(8)
	return nearby


func _clear_close_enemies_with_space(player: Node2D, timeout_ms: int, max_attacks: int = 8) -> Dictionary:
	var started := Time.get_ticks_msec()
	var player_hp_before := GameState.hp
	var player_position_before := _vector_data(player.global_position) if is_instance_valid(player) else []
	var attacks: Array[Dictionary] = []
	var initial_enemies := _nearby_enemy_evidence(player.global_position, 120.0) if is_instance_valid(player) else []
	var stop_reason := "timeout_or_attack_limit"
	while Time.get_ticks_msec() - started < timeout_ms and attacks.size() < max_attacks and is_instance_valid(player) and GameState.hp > 0 and not GameState.death_pending:
		var target := _nearest_living_enemy(player.global_position, 120.0)
		if target == null:
			stop_reason = "no_living_enemy_within_melee_radius"
			break
		var target_position := target.global_position
		var hp_before := int(target.get("hp"))
		var player_hp_before_attack := GameState.hp
		var player_position_before_attack := _vector_data(player.global_position)
		var direction := target_position - player.global_position
		var face_key := KEY_S
		if absf(direction.x) > absf(direction.y):
			face_key = KEY_D if direction.x > 0.0 else KEY_A
		else:
			face_key = KEY_S if direction.y > 0.0 else KEY_W
		_set_movement_keys([face_key])
		await get_tree().physics_frame
		await get_tree().physics_frame
		_set_movement_keys([])
		await get_tree().process_frame
		if not is_instance_valid(player) or not is_instance_valid(target):
			stop_reason = "player_or_target_freed_while_facing"
			break
		await _tap_key(KEY_SPACE, "Space: melee attack nearby %s" % str(target.get("enemy_id")))
		var attack_started := Time.get_ticks_msec()
		while Time.get_ticks_msec() - attack_started < 500:
			await get_tree().process_frame
		var hp_after := int(target.get("hp")) if is_instance_valid(target) else 0
		attacks.append({
			"enemy_id": str(target.get("enemy_id")) if is_instance_valid(target) else "removed",
			"hp_before": hp_before,
			"hp_after": hp_after,
			"target_position_before": _vector_data(target_position),
			"target_position_after": _vector_data(target.global_position) if is_instance_valid(target) else [],
			"player_position_before": player_position_before_attack,
			"player_position_after": _vector_data(player.global_position) if is_instance_valid(player) else [],
			"player_hp_before": player_hp_before_attack,
			"player_hp_after": GameState.hp,
			"elapsed_ms": Time.get_ticks_msec() - started
		})
		if not is_instance_valid(player) or GameState.hp <= 0 or GameState.death_pending:
			stop_reason = "player_dead_or_freed_after_space_attack"
			break
	if not is_instance_valid(player) or GameState.hp <= 0 or GameState.death_pending:
		stop_reason = "player_dead_or_freed"
	elif attacks.size() >= max_attacks:
		stop_reason = "bounded_attack_limit_reached"
	return {
		"attempted": true,
		"attack_count": attacks.size(),
		"attack_input": "InputEventKey Space / attack_melee",
		"active_attack_mode": GameState.active_attack_mode(),
		"weapon_id": GameState.active_attack_item_id(),
		"player_hp_before": player_hp_before,
		"player_position_before": player_position_before,
		"initial_nearby_enemies": initial_enemies,
		"attacks": attacks,
		"player_hp_after": GameState.hp,
		"player_valid_after": is_instance_valid(player),
		"player_position_after": _vector_data(player.global_position) if is_instance_valid(player) else [],
		"death_pending_after": GameState.death_pending,
		"remaining_nearby_enemies": _nearby_enemy_evidence(player.global_position, 120.0) if is_instance_valid(player) else [],
		"current_scene_after": _current_scene_evidence(),
		"stop_reason": stop_reason,
		"elapsed_ms": Time.get_ticks_msec() - started
	}


func _nearest_living_enemy(center: Vector2, radius: float) -> Node2D:
	var nearest: Node2D = null
	var nearest_distance := radius
	for raw_enemy: Variant in get_tree().get_nodes_in_group("enemy"):
		var enemy := raw_enemy as Node2D
		if enemy == null or not is_instance_valid(enemy) or bool(enemy.get("is_dead")):
			continue
		var distance := center.distance_to(enemy.global_position)
		if distance < nearest_distance:
			nearest = enemy
			nearest_distance = distance
	return nearest


func _engage_escort_blocker_with_space(player: Node2D, actor: Node2D, timeout_ms: int, max_attacks: int) -> Dictionary:
	var started := Time.get_ticks_msec()
	var player_hp_before := int(GameState.hp)
	var player_position_before := _vector_data(player.global_position) if is_instance_valid(player) else []
	var actor_position_before := _vector_data(actor.global_position) if is_instance_valid(actor) else []
	var initial_blockers := _nearby_enemy_evidence(actor.global_position, 300.0) if is_instance_valid(actor) else []
	var approaches: Array[Dictionary] = []
	var attacks: Array[Dictionary] = []
	var stop_reason := "no_living_enemy_within_escort_block_radius"
	while Time.get_ticks_msec() - started < timeout_ms and attacks.size() < max_attacks and is_instance_valid(player) and is_instance_valid(actor) and GameState.hp > 0 and not GameState.death_pending:
		if player.global_position.distance_to(actor.global_position) > 520.0:
			stop_reason = "player_outside_authored_escort_follow_range"
			break
		var target := _nearest_living_enemy(actor.global_position, 300.0)
		if target == null:
			stop_reason = "no_living_enemy_within_escort_block_radius"
			break
		var target_position := target.global_position
		var target_hp_before := int(target.get("hp"))
		var player_position_before_approach := player.global_position
		var distance_before_approach := player_position_before_approach.distance_to(target_position)
		var approach_reached := true
		if distance_before_approach > 120.0:
			var approach_direction := (player.global_position - target_position).normalized()
			if approach_direction == Vector2.ZERO:
				approach_direction = Vector2.DOWN
			var approach_target := target_position + approach_direction * 72.0
			var remaining_before_approach := maxi(1, timeout_ms - (Time.get_ticks_msec() - started))
			approach_reached = await _walk_to_position(player, approach_target, mini(1800, remaining_before_approach))
			if not is_instance_valid(player) or not is_instance_valid(target) or not is_instance_valid(actor):
				stop_reason = "player_target_or_escort_freed_during_approach"
				break
		var distance_after_approach := player.global_position.distance_to(target.global_position)
		approaches.append({
			"enemy_id": str(target.get("enemy_id")),
			"enemy_position": _vector_data(target_position),
			"walk_reached_approach_point": approach_reached,
			"player_position_before": _vector_data(player_position_before_approach),
			"player_position_after": _vector_data(player.global_position),
			"enemy_distance_before": distance_before_approach,
			"enemy_distance_after": distance_after_approach,
			"escort_distance_after": player.global_position.distance_to(actor.global_position)
		})
		if distance_after_approach > 120.0:
			stop_reason = "enemy_not_reached_melee_range_by_player_movement"
			break
		var face_direction := target.global_position - player.global_position
		var face_key := KEY_S
		if absf(face_direction.x) > absf(face_direction.y):
			face_key = KEY_D if face_direction.x > 0.0 else KEY_A
		else:
			face_key = KEY_S if face_direction.y > 0.0 else KEY_W
		var target_position_before_attack := target.global_position
		var player_position_before_attack := player.global_position
		var player_hp_before_attack := int(GameState.hp)
		_set_movement_keys([face_key])
		await get_tree().physics_frame
		await get_tree().physics_frame
		_set_movement_keys([])
		await get_tree().process_frame
		if not is_instance_valid(player) or not is_instance_valid(target):
			stop_reason = "player_or_target_freed_while_facing"
			break
		await _tap_key(KEY_SPACE, "Space: melee attack escort blocker %s" % str(target.get("enemy_id")))
		var attack_started := Time.get_ticks_msec()
		while Time.get_ticks_msec() - attack_started < 500:
			await get_tree().process_frame
		var target_hp_after := int(target.get("hp")) if is_instance_valid(target) else 0
		attacks.append({
			"enemy_id": str(target.get("enemy_id")) if is_instance_valid(target) else "removed",
			"enemy_hp_before": target_hp_before,
			"enemy_hp_after": target_hp_after,
			"enemy_position_before": _vector_data(target_position_before_attack),
			"enemy_position_after": _vector_data(target.global_position) if is_instance_valid(target) else [],
			"enemy_still_valid": is_instance_valid(target),
			"player_position_before": _vector_data(player_position_before_attack),
			"player_position_after": _vector_data(player.global_position) if is_instance_valid(player) else [],
			"player_hp_before": player_hp_before_attack,
			"player_hp_after": int(GameState.hp),
			"escort_position": _vector_data(actor.global_position) if is_instance_valid(actor) else [],
			"elapsed_ms": Time.get_ticks_msec() - started
		})
		stop_reason = "bounded_space_attack_limit_reached"
		if not is_instance_valid(player) or GameState.hp <= 0 or GameState.death_pending:
			stop_reason = "player_dead_or_freed_after_space_attack"
			break
		if not is_instance_valid(target) or bool(target.get("is_dead")) or int(target.get("hp")) <= 0:
			stop_reason = "target_cleared_continue_escort_simulation"
			continue
	if attacks.size() >= max_attacks:
		stop_reason = "bounded_space_attack_limit_reached"
	if attacks.is_empty():
		await get_tree().process_frame
	return {
		"attempted": true,
		"response": "player movement and injected InputEventKey Space only",
		"attack_count": attacks.size(),
		"player_hp_before": player_hp_before,
		"player_hp_after": int(GameState.hp),
		"player_valid_after": is_instance_valid(player),
		"death_pending_after": bool(GameState.death_pending),
		"player_position_before": player_position_before,
		"player_position_after": _vector_data(player.global_position) if is_instance_valid(player) else [],
		"escort_position_before": actor_position_before,
		"escort_position_after": _vector_data(actor.global_position) if is_instance_valid(actor) else [],
		"initial_blockers_within_300px_of_escort": initial_blockers,
		"approaches": approaches,
		"attacks": attacks,
		"remaining_blockers_within_300px_of_escort": _nearby_enemy_evidence(actor.global_position, 300.0) if is_instance_valid(actor) else [],
		"current_scene_after": _current_scene_evidence(),
		"scene_router_transition_count": _transition_events.size(),
		"stop_reason": stop_reason,
		"elapsed_ms": Time.get_ticks_msec() - started
	}


func _follow_escort_action(player: Node2D, action: Node2D, timeout_ms: int) -> Dictionary:
	var started := Time.get_ticks_msec()
	var max_player_actor_distance := 0.0
	var last_checkpoint := 0
	var last_sample_time := -1000
	var last_combat_response_time := -1000
	var escort_attack_count := 0
	var escort_combat_response_count := 0
	var samples: Array[Dictionary] = []
	var combat_responses: Array[Dictionary] = []
	if not is_instance_valid(player) or not is_instance_valid(action):
		return {"reached": false, "final_status": GameState.campaign_action_status(ESCORT_ACTION_ID), "stop_reason": "player_or_action_invalid_before_follow"}
	var waypoint_count := _path_points(action.get("_waypoints")).size()
	while Time.get_ticks_msec() - started < timeout_ms:
		var status := GameState.campaign_action_status(ESCORT_ACTION_ID)
		if status == "done":
			_set_movement_keys([])
			return {
				"reached": true,
				"elapsed_ms": Time.get_ticks_msec() - started,
				"max_player_actor_distance": max_player_actor_distance,
				"last_checkpoint": last_checkpoint,
				"samples": samples,
				"combat_responses": combat_responses,
				"final_status": status
			}
		if GameState.death_pending or GameState.hp <= 0 or not is_instance_valid(player) or not is_instance_valid(action):
			break
		var actor := action.get("_escort_actor") as Node2D
		if not is_instance_valid(actor):
			break
		var distance := player.global_position.distance_to(actor.global_position)
		max_player_actor_distance = maxf(max_player_actor_distance, distance)
		var progress := GameState.campaign_action_progress(ESCORT_ACTION_ID)
		last_checkpoint = maxi(last_checkpoint, int(progress.get("checkpoint", 0)))
		var now := Time.get_ticks_msec()
		if now - last_sample_time >= 750:
			samples.append({
				"checkpoint": int(progress.get("checkpoint", 0)),
				"distance": distance,
				"player_position": _vector_data(player.global_position),
				"actor_position": _vector_data(actor.global_position),
				"wait_reason": str(action.get("_wait_reason"))
			})
			last_sample_time = now
		var wait_reason := String(action.get("_wait_reason"))
		if wait_reason == "清除護送者附近敵人" and now - last_combat_response_time >= 800 and escort_attack_count < 8 and escort_combat_response_count < 4:
			var remaining_for_combat := maxi(1, timeout_ms - (now - started))
			var attack_limit := mini(3, 8 - escort_attack_count)
			var combat_response := await _engage_escort_blocker_with_space(player, actor, mini(8500, remaining_for_combat), attack_limit)
			combat_responses.append(combat_response)
			escort_attack_count += int(combat_response.get("attack_count", 0))
			escort_combat_response_count += 1
			_combat_attack_count += int(combat_response.get("attack_count", 0))
			combat_response["stage"] = "escort_authored_enemy_wait"
			_combat_responses.append(combat_response)
			last_combat_response_time = Time.get_ticks_msec()
			if not is_instance_valid(player) or GameState.hp <= 0 or GameState.death_pending:
				break
			continue
		if last_checkpoint >= waypoint_count and distance > 250.0:
			# The crew has reached the final waypoint; walk to them to complete reunion.
			var remaining := maxi(1, timeout_ms - (now - started))
			await _walk_to_position(player, actor.global_position, mini(1400, remaining))
		elif distance > 300.0:
			# Keep the player about 180 px behind the moving crew so the authored
			# escort simulation never pauses because the driver rushed ahead.
			var world_size: Vector2 = action.get("_world_size")
			var follow_point := actor.global_position + Vector2(0.0, 180.0)
			if world_size != Vector2.ZERO:
				follow_point = follow_point.clamp(Vector2(96.0, 96.0), world_size - Vector2(96.0, 96.0))
			var remaining := maxi(1, timeout_ms - (now - started))
			await _walk_to_position(player, follow_point, mini(1400, remaining))
		else:
			await get_tree().process_frame
		if GameState.campaign_action_status(ESCORT_ACTION_ID) == "done":
			continue
	var actor_at_end := action.get("_escort_actor") as Node2D if is_instance_valid(action) else null
	return {
		"reached": GameState.campaign_action_status(ESCORT_ACTION_ID) == "done",
		"elapsed_ms": Time.get_ticks_msec() - started,
		"max_player_actor_distance": max_player_actor_distance,
		"last_checkpoint": last_checkpoint,
		"samples": samples,
		"combat_responses": combat_responses,
		"player_position": _vector_data(player.global_position) if is_instance_valid(player) else [],
		"actor_position": _vector_data(actor_at_end.global_position) if is_instance_valid(actor_at_end) else [],
		"final_status": GameState.campaign_action_status(ESCORT_ACTION_ID)
	}


func _path_points(value: Variant) -> Array[Vector2]:
	var points: Array[Vector2] = []
	if not value is Array:
		return points
	for raw_point: Variant in value:
		if raw_point is Vector2:
			points.append(raw_point)
	return points


func _wait_for_campaign_action(action_id: String, expected_status: String, timeout_ms: int) -> bool:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < timeout_ms:
		if GameState.campaign_action_status(action_id) == expected_status:
			return true
		if GameState.death_pending or GameState.hp <= 0:
			return false
		await get_tree().process_frame
	return GameState.campaign_action_status(action_id) == expected_status


func _focus_button_with_tab(target: Button, max_tab_presses: int) -> bool:
	for _press in range(max_tab_presses + 1):
		if get_viewport().gui_get_focus_owner() == target:
			return true
		await _tap_key(KEY_TAB, "Tab: navigate Guild contract catalog")
	return get_viewport().gui_get_focus_owner() == target


func _walk_to_position(player: Node2D, destination: Vector2, timeout_ms: int, monitor_nearby_combat: bool = false) -> bool:
	if not is_instance_valid(player):
		_set_movement_keys([])
		return false
	var started := Time.get_ticks_msec()
	var best_distance := player.global_position.distance_to(destination)
	var stalled_frames := 0
	while Time.get_ticks_msec() - started < timeout_ms:
		if not is_instance_valid(player):
			_set_movement_keys([])
			return false
		var delta := destination - player.global_position
		if delta.length() <= 24.0:
			_set_movement_keys([])
			return true
		var movement_keys: Array[int] = []
		if absf(delta.x) > 12.0:
			movement_keys.append(KEY_D if delta.x > 0.0 else KEY_A)
		if absf(delta.y) > 12.0:
			movement_keys.append(KEY_S if delta.y > 0.0 else KEY_W)
		_set_movement_keys(movement_keys)
		await get_tree().physics_frame
		await get_tree().process_frame
		if not is_instance_valid(player):
			_set_movement_keys([])
			return false
		if monitor_nearby_combat and GameState.hp > 0 and not GameState.death_pending and _combat_attack_count < MAX_RUN_MELEE_ATTACKS:
			var close_enemy := _nearest_living_enemy(player.global_position, 120.0)
			if close_enemy != null:
				_set_movement_keys([])
				var remaining_for_attack := maxi(1, timeout_ms - (Time.get_ticks_msec() - started))
				var attack_budget := mini(2, MAX_RUN_MELEE_ATTACKS - _combat_attack_count)
				var combat_response := await _clear_close_enemies_with_space(player, mini(6000, remaining_for_attack), attack_budget)
				combat_response["stage"] = "authored_extraction_road"
				_combat_responses.append(combat_response)
				_combat_attack_count += int(combat_response.get("attack_count", 0))
				if not is_instance_valid(player) or GameState.hp <= 0 or GameState.death_pending:
					_set_movement_keys([])
					return false
				best_distance = player.global_position.distance_to(destination)
				stalled_frames = 0
				continue
		var distance := player.global_position.distance_to(destination)
		if distance + 0.5 < best_distance:
			best_distance = distance
			stalled_frames = 0
		else:
			stalled_frames += 1
		if stalled_frames >= 180:
			break
	_set_movement_keys([])
	return is_instance_valid(player) and player.global_position.distance_to(destination) <= 24.0


func _target_is_selected(player: Node2D, target: Node2D) -> bool:
	return bool(target.call("can_interact")) and player.call("get_nearest_interaction_target") == target


func _tap_key(key_code: int, description: String) -> void:
	_send_key(key_code, true, description)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_send_key(key_code, false, description)
	await get_tree().process_frame


func _hold_key_for_seconds(key_code: int, duration: float, description: String) -> void:
	_send_key(key_code, true, description)
	var started := Time.get_ticks_msec()
	var target_ms := maxi(1, roundi(duration * 1000.0))
	while Time.get_ticks_msec() - started < target_ms:
		await get_tree().process_frame
	_send_key(key_code, false, description)
	await get_tree().process_frame


func _set_movement_keys(keys: Array[int]) -> void:
	var next_keys: Dictionary = {}
	for key_code in keys:
		next_keys[key_code] = true
	for old_key: Variant in _held_keys.keys():
		if not next_keys.has(old_key):
			_send_key(int(old_key), false, "WASD movement")
	for next_key: Variant in next_keys.keys():
		if not _held_keys.has(next_key):
			_send_key(int(next_key), true, "WASD movement")
	_held_keys = next_keys


func _release_all_keys() -> void:
	for key_code: Variant in _held_keys.keys():
		_send_key(int(key_code), false, "cleanup")
	_held_keys.clear()


func _send_key(key_code: int, pressed: bool, purpose: String) -> void:
	var event := InputEventKey.new()
	event.keycode = key_code
	event.physical_keycode = key_code
	event.pressed = pressed
	event.echo = false
	Input.parse_input_event(event)
	_input_events.append({
		"event_type": "InputEventKey",
		"injected": true,
		"dispatch": "Input.parse_input_event",
		"key": _key_name(key_code),
		"physical_keycode": key_code,
		"pressed": pressed,
		"purpose": purpose
	})


func _check_action_key(action_name: String, key_code: int) -> bool:
	if not InputMap.has_action(action_name):
		return false
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey and int(event.physical_keycode) == key_code:
			return true
	return false


func _find_player(scene: Node) -> Node2D:
	for candidate: Node in get_tree().get_nodes_in_group("player"):
		if scene.is_ancestor_of(candidate) and candidate is Node2D:
			return candidate as Node2D
	return null


func _find_interactable(scene: Node, interaction_id: String) -> Node2D:
	for candidate: Node in get_tree().get_nodes_in_group("interactable"):
		if scene.is_ancestor_of(candidate) and candidate is Node2D and str(candidate.get("interaction_id")) == interaction_id:
			return candidate as Node2D
	return null


func _find_campaign_action(scene: Node, action_id: String) -> Node2D:
	for candidate: Node in get_tree().get_nodes_in_group("campaign_action"):
		if scene.is_ancestor_of(candidate) and candidate is Node2D and str(candidate.get("action_id")) == action_id:
			return candidate as Node2D
	return null


func _record_persistent_root(stage: String) -> void:
	var tree := get_tree()
	var evidence := {
		"stage": stage,
		"driver_instance_id": get_instance_id(),
		"tree_instance_id": tree.get_instance_id(),
		"root_viewport_instance_id": tree.root.get_instance_id(),
		"driver_is_root_child": get_parent() == tree.root,
		"current_scene": _current_scene_evidence()
	}
	var passed := is_instance_valid(self) and get_instance_id() == _initial_driver_id and tree.get_instance_id() == _initial_tree_id and tree.root.get_instance_id() == _initial_viewport_id and get_parent() == tree.root
	_record_check("persistent_root_driver_survives_" + stage, passed, {
		"driver_instance_id": _initial_driver_id,
		"tree_instance_id": _initial_tree_id,
		"root_viewport_instance_id": _initial_viewport_id,
		"driver_is_root_child": true
	}, evidence)


func _record_check(name: String, passed: bool, expected: Variant, observed: Variant) -> void:
	var record := {
		"name": name,
		"status": "PASS" if passed else "FAIL",
		"expected": expected,
		"observed": observed
	}
	_checks.append(record)
	if not passed:
		_failures.append(name)
	print("[JOURNEY][%s] %s expected=%s observed=%s" % [record.status, name, JSON.stringify(expected), JSON.stringify(observed)])


func _passed_check_count() -> int:
	var count := 0
	for check: Dictionary in _checks:
		if String(check.get("status", "")) == "PASS":
			count += 1
	return count


func _current_scene_evidence() -> Dictionary:
	var scene := get_tree().current_scene
	return {
		"scene_path": scene.scene_file_path if scene != null else "",
		"scene_instance_id": scene.get_instance_id() if scene != null else 0,
		"game_state_scene_id": String(GameState.current_scene_id),
		"transition_pending": SceneRouter.is_transition_pending()
	}


func _campaign_runtime_evidence(player: Node2D, action: Node2D) -> Dictionary:
	var player_valid := is_instance_valid(player)
	var action_valid := is_instance_valid(action)
	var outing: Dictionary = GameState.campaign_outing()
	var campaign_owner: Dictionary = GameState.campaign_action_owner()
	var runtime: Dictionary = GameState.campaign_action_progress(RELAY_ACTION_ID)
	var scene_evidence := _current_scene_evidence()
	var evidence := {
		"player_valid": player_valid,
		"player_queued_for_deletion": player.is_queued_for_deletion() if player_valid else false,
		"player_instance_id": player.get_instance_id() if player_valid else 0,
		"player_position": _vector_data(player.global_position) if player_valid else [],
		"player_hp": int(GameState.hp),
		"death_pending": bool(GameState.death_pending),
		"game_state_scene_id": String(GameState.current_scene_id),
		"game_state_route_id": String(GameState.current_route_id),
		"active_quest_id": String(GameState.active_quest_id),
		"has_active_expedition": bool(GameState.has_active_expedition()),
		"has_authored_campaign": bool(GameState.has_authored_campaign()),
		"campaign_outing": outing,
		"campaign_outing_id": String(outing.get("id", "")),
		"campaign_outing_route_id": String(outing.get("route", "")),
		"campaign_action_owner": campaign_owner,
		"campaign_action_owner_valid": not campaign_owner.is_empty(),
		"campaign_action_status": GameState.campaign_action_status(RELAY_ACTION_ID),
		"campaign_runtime": runtime,
		"campaign_runtime_started": bool(runtime.get("started", false)),
		"field_objective_active": bool(GameState.field_objective_status(FIRST_CONTRACT_ID)),
		"current_scene": scene_evidence,
		"scene_router_transition_pending": bool(SceneRouter.is_transition_pending()),
		"transition_event_count": _transition_events.size(),
		"action_valid": action_valid,
		"action_queued_for_deletion": action.is_queued_for_deletion() if action_valid else false,
		"action_position": _vector_data(action.global_position) if action_valid else []
	}
	if player_valid:
		evidence["nearby_enemies"] = _nearby_enemy_evidence(player.global_position, 180.0)
	else:
		evidence["nearby_enemies"] = []
	return evidence


func _terminal_gameplay_evidence() -> Dictionary:
	var scene := get_tree().current_scene
	var player_records: Array[Dictionary] = []
	var active_player: Node2D = null
	for candidate: Node in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(candidate) or not candidate is Node2D:
			continue
		var player := candidate as Node2D
		var belongs_to_current_scene := scene != null and scene.is_ancestor_of(player)
		if not belongs_to_current_scene:
			continue
		player_records.append({
			"instance_id": player.get_instance_id(),
			"valid": is_instance_valid(player),
			"inside_tree": player.is_inside_tree(),
			"queued_for_deletion": player.is_queued_for_deletion(),
			"position": _vector_data(player.global_position)
		})
		if active_player == null and not player.is_queued_for_deletion():
			active_player = player
	var outing: Dictionary = GameState.campaign_outing()
	var campaign_owner: Dictionary = GameState.campaign_action_owner()
	return {
		"current_scene": _current_scene_evidence(),
		"game_state_hp": int(GameState.hp),
		"death_pending": bool(GameState.death_pending),
		"current_scene_id": String(GameState.current_scene_id),
		"current_route_id": String(GameState.current_route_id),
		"active_quest_id": String(GameState.active_quest_id),
		"has_active_expedition": bool(GameState.has_active_expedition()),
		"has_authored_campaign": bool(GameState.has_authored_campaign()),
		"campaign_outing_id": String(outing.get("id", "")),
		"campaign_outing_route_id": String(outing.get("route", "")),
		"campaign_action_owner": campaign_owner,
		"campaign_action_owner_valid": not campaign_owner.is_empty(),
		"escort_action_status": GameState.campaign_action_status(ESCORT_ACTION_ID),
		"escort_action_runtime": GameState.campaign_action_progress(ESCORT_ACTION_ID),
		"relay_action_status": GameState.campaign_action_status(RELAY_ACTION_ID),
		"relay_action_runtime": GameState.campaign_action_progress(RELAY_ACTION_ID),
		"field_objective_active": bool(GameState.field_objective_status(FIRST_CONTRACT_ID)),
		"player_valid": active_player != null and is_instance_valid(active_player),
		"player_records": player_records,
		"nearby_enemies_to_player": _nearby_enemy_evidence(active_player.global_position, 300.0) if active_player != null and is_instance_valid(active_player) else [],
		"scene_router_transition_pending": bool(SceneRouter.is_transition_pending()),
		"scene_router_transition_count": _transition_events.size(),
		"all_recorded_transitions_succeeded": _all_transitions_succeeded(),
		"isolated_save_path": _isolated_save_path,
		"isolated_save_exists": FileAccess.file_exists("user://save_game.json") if _isolation_validated else false
	}


func _on_transition_finished(succeeded: bool) -> void:
	_transition_events.append({
		"sequence": _transition_events.size() + 1,
		"succeeded": succeeded,
		"scene": _current_scene_evidence()
	})


func _all_transitions_succeeded() -> bool:
	for transition: Dictionary in _transition_events:
		if not bool(transition.get("succeeded", false)):
			return false
	return true


func _is_path_within(path: String, parent: String) -> bool:
	var child := _normalized_path(path)
	var base := _normalized_path(parent)
	return not child.is_empty() and not base.is_empty() and (child == base or child.begins_with(base + "/"))


func _normalized_path(path: String) -> String:
	return path.replace("\\", "/").trim_suffix("/").to_lower()


func _node_name(node: Node) -> String:
	return String(node.name) if is_instance_valid(node) else ""


func _vector_data(value: Vector2) -> Array[float]:
	return [value.x, value.y]


func _key_name(key_code: int) -> String:
	match key_code:
		KEY_ENTER:
			return "Enter"
		KEY_TAB:
			return "Tab"
		KEY_ESCAPE:
			return "Escape"
		KEY_SPACE:
			return "Space"
		KEY_E:
			return "E"
		KEY_D:
			return "D"
		KEY_A:
			return "A"
		KEY_W:
			return "W"
		KEY_S:
			return "S"
		_:
			return str(key_code)


func _argument_value(name: String) -> String:
	var args := OS.get_cmdline_user_args()
	for index in range(args.size()):
		if args[index] == name and index + 1 < args.size():
			return args[index + 1]
		if args[index].begins_with(name + "="):
			return args[index].substr(name.length() + 1)
	return ""


func _finish() -> void:
	if _finished:
		return
	_finished = true
	_release_all_keys()
	var terminal_death_wait_ms := 0
	if GameState.death_pending or GameState.hp <= 0:
		var death_wait_started := Time.get_ticks_msec()
		while Time.get_ticks_msec() - death_wait_started < 5000:
			if not SceneRouter.is_transition_pending() and GameState.current_scene_id != "wasteland":
				break
			await get_tree().process_frame
		terminal_death_wait_ms = Time.get_ticks_msec() - death_wait_started
	var terminal_evidence := _terminal_gameplay_evidence()
	terminal_evidence["death_transition_observation_wait_ms"] = terminal_death_wait_ms
	var terminal_evidence_complete := terminal_evidence.has("game_state_hp") and terminal_evidence.has("death_pending") and terminal_evidence.has("current_scene") and terminal_evidence.has("player_valid") and terminal_evidence.has("scene_router_transition_count") and terminal_evidence.has("campaign_action_owner")
	_record_check("terminal_gameplay_state_evidence_captured", terminal_evidence_complete, "terminal player validity, HP/death state, current scene, campaign owner, and SceneRouter transition evidence", terminal_evidence)
	var milestones_complete := _contract_accepted and _wasteland_entered and _field_actions_completed and _extracted and _first_debrief_copy_valid and _second_outing_started and _second_outing_completed and _second_outing_extracted and _second_debrief_copy_valid and _kill_objective_ready and _scrap_objective_ready and _j_contract_copy_valid and _guild_handin_completed and _post_handin_reload_valid and _repeat_handin_unchanged
	_record_check("minimum_successful_check_count_for_journey_pass", _passed_check_count() >= MIN_SUCCESSFUL_CHECKS_TO_PASS, MIN_SUCCESSFUL_CHECKS_TO_PASS, _passed_check_count())
	_record_check("required_full_first_contract_journey_milestones_complete", milestones_complete, {
		"contract_accepted": true,
		"first_outing_extracted": true,
		"first_debrief_current_copy_valid": true,
		"second_outing_started_and_completed": true,
		"second_debrief_current_copy_valid": true,
		"second_outing_extracted_with_original_objectives_ready": true,
		"live_J_contract_aggregation_copy_valid": true,
		"guild_handin_awarded_once": true,
		"post_handin_SaveManager_reload_valid": true,
		"repeat_handin_unchanged": true
	}, {
		"contract_accepted": _contract_accepted,
		"first_outing_extracted": _extracted,
		"first_debrief_current_copy_valid": _first_debrief_copy_valid,
		"second_outing_started": _second_outing_started,
		"second_outing_completed": _second_outing_completed,
		"second_outing_extracted": _second_outing_extracted,
		"second_debrief_current_copy_valid": _second_debrief_copy_valid,
		"kill_objective_ready": _kill_objective_ready,
		"scrap_objective_ready": _scrap_objective_ready,
		"live_J_contract_aggregation_copy_valid": _j_contract_copy_valid,
		"guild_handin_completed": _guild_handin_completed,
		"post_handin_SaveManager_reload_valid": _post_handin_reload_valid,
		"repeat_handin_unchanged": _repeat_handin_unchanged
	})
	if _isolation_validated:
		_isolated_save_exists_at_finish = FileAccess.file_exists("user://save_game.json")
		var isolated_save_under_temp := _is_path_within(_isolated_save_path, _isolated_root)
		_record_check("isolated_profile_save_was_written_under_Temp", isolated_save_under_temp and _isolated_save_exists_at_finish, "isolated user://save_game.json exists under this Temp run root", {
			"isolated_save_path": _isolated_save_path,
			"exists": _isolated_save_exists_at_finish,
			"isolated_root": _isolated_root
		})
	var result := "PASS" if _failures.is_empty() else "FAIL"
	var report := {
		"schema_version": 3,
		"runner": "first_chapter_persistent_root_full_first_contract_journey",
		"result": result,
		"engine": Engine.get_version_info(),
		"started_unix": _started_unix,
		"duration_seconds": (Time.get_unix_time_from_system() - _started_unix),
		"source_project_root": _source_project_root,
		"temp_mirror_project_root": ProjectSettings.globalize_path("res://"),
		"temp_mirror_origin_run_id": _temp_mirror_origin_run_id,
		"temp_mirror_identity": {
			"project_root": ProjectSettings.globalize_path("res://"),
			"origin_run_id": _temp_mirror_origin_run_id,
			"profile_report_run_id": _run_id
		},
		"source_tree_sha256": _source_tree_sha256,
		"driver_sha256": _driver_sha256,
		"report_path": _report_path,
		"reproducible_launch": {
			"godot_executable": OS.get_executable_path(),
			"project_path": ProjectSettings.globalize_path("res://"),
			"boot_scene": "res://scripts/tests/FirstChapterJourneyBoot.tscn",
			"command_line_args": OS.get_cmdline_args(),
			"command_line_user_args": OS.get_cmdline_user_args(),
			"appdata_override": OS.get_environment("APPDATA"),
			"local_appdata_override": OS.get_environment("LOCALAPPDATA")
		},
		"isolation": {
			"explicit_temp_root": _isolated_root,
			"windows_temp": OS.get_environment("TEMP"),
			"appdata": OS.get_environment("APPDATA"),
			"local_appdata": OS.get_environment("LOCALAPPDATA"),
			"user_data_dir": OS.get_user_data_dir(),
			"isolation_validated_before_save_access": _isolation_validated,
			"custom_user_dir_name": String(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")),
			"run_id_exact_match_required": _run_id,
			"isolated_save_path": _isolated_save_path,
			"isolated_save_written": _isolated_save_exists_at_finish if _isolation_validated else "not_checked_due_to_isolation_failure",
			"real_player_save_read_or_written": false,
			"path_guard": "case-insensitive normalized lexical containment; symlink and junction resolution is not performed"
		},
		"persistent_root": {
			"driver_instance_id": _initial_driver_id,
			"tree_instance_id": _initial_tree_id,
			"root_viewport_instance_id": _initial_viewport_id,
			"final_driver_instance_id": get_instance_id(),
			"final_tree_instance_id": get_tree().get_instance_id(),
			"final_root_viewport_instance_id": get_tree().root.get_instance_id(),
			"driver_is_root_child": get_parent() == get_tree().root
		},
		"checks": _checks,
		"check_count": _checks.size(),
		"passed_check_count": _passed_check_count(),
		"failed_checks": _failures,
		"input_events": _input_events,
		"input_event_count": _input_events.size(),
		"input_events_are_injected": true,
		"input_dispatch": "InputEventKey via Input.parse_input_event",
		"combat_responses": _combat_responses,
		"combat_response_count": _combat_responses.size(),
		"combat_attack_count": _combat_attack_count,
		"max_run_melee_attacks": MAX_RUN_MELEE_ATTACKS,
		"scene_router_transitions": _transition_events,
		"scene_router_transition_count": _transition_events.size(),
		"terminal_evidence": terminal_evidence,
		"milestones": {
			"contract_accepted_through_guild_board": _contract_accepted,
			"first_authored_wasteland_route_entered": _wasteland_entered,
			"first_outing_actions_completed": _field_actions_completed,
			"first_outing_extracted_through_actual_gate": _extracted,
			"first_outing_live_debrief_copy_valid": _first_debrief_copy_valid,
			"second_authored_outing_started": _second_outing_started,
			"second_outing_extraction_completed": _second_outing_extracted,
			"second_outing_live_debrief_copy_valid": _second_debrief_copy_valid,
			"outing_index_2_of_2_and_contract_objectives_ready": _second_outing_completed and _kill_objective_ready and _scrap_objective_ready,
			"live_J_contract_copy_valid": _j_contract_copy_valid,
			"Guild_handin_awarded_once": _guild_handin_completed,
			"post_handin_SaveManager_reload_valid": _post_handin_reload_valid,
			"repeat_handin_left_state_unchanged": _repeat_handin_unchanged
		},
		"first_outing_saved_run_ledger": _first_outing_saved_evidence,
		"second_outing_saved_run_ledger": _second_outing_saved_evidence,
		"handin_and_repeat_evidence": _handin_evidence,
		"scope": "Fresh title journey; actual Village/Guild travel and first authored outing; first actual extraction with current temporary-circuit/connector/rationing debrief assertions; second ch1b_route_coupling outing selected through the GUI, carried along its covered-long authored route with real melee inputs, then extracted through the physical Wasteland gate and current connector/rationing debrief assertions; open the actual Guild J contract details to assert the 5-kill/12-scrap chapter-total wording; complete clear_scrap_route at the physical Guild reward counter; verify the checksummed hand-in save through SaveManager.load_game(false, false); repeat E once and compare state and saved payload. Every game control is an injected InputEventKey through Input.parse_input_event.",
		"limits": [
			"The original defeat objective is a minimum of 5 kills. The selected second-outing carry route requires killing its authored wave, so the saved total may exceed five; the runner asserts readiness against the authored amount.",
			"No enemies are disabled, no quest/progress fixtures are created, and no direct interaction, campaign completion, or quest delivery methods are called. Combat uses at most 64 injected Space key presses across both outings. SaveManager performs only the requested data-only load after the physical hand-in has saved. Death recovery behavior is not deliberately triggered; the run asserts successful extraction with positive HP and no pending death.",
			"The path containment guard is lexical and does not resolve symlinks or junctions; the run uses a fresh run-id path under Temp and an exact matching custom user directory.",
			"The run makes no visual quality claim and does not assert later chapters or the chapter handoff/water-stage outcome."
		]
	}
	if not _is_path_within(_report_path, OS.get_environment("TEMP")):
		push_error("Refusing to write journey report outside Temp: %s" % _report_path)
		print(JSON.stringify(report, "\t"))
		get_tree().quit(2)
		return
	var file := FileAccess.open(_report_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write journey report at %s" % _report_path)
		print(JSON.stringify(report, "\t"))
		get_tree().quit(2)
		return
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.flush()
	file.close()
	print("[JOURNEY] result=%s" % report.result)
	print("[JOURNEY] report=%s" % _report_path)
	get_tree().quit(0 if _failures.is_empty() else 1)
