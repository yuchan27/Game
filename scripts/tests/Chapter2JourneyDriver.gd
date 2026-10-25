extends "res://scripts/tests/FirstChapterJourneyDriver.gd"

const CHAPTER_ONE_QUEST_ID := "clear_scrap_route"
const CHAPTER_TWO_QUEST_ID := "toxic_sample"
const FIRST_OUTING_ID := "ch2a_sample_taps"
const UPPER_SAMPLE_ACTION_ID := "ch2a_sample_upper"
const RETURN_SAMPLE_ACTION_ID := "ch2a_sample_return"
const CHAPTER2_SECOND_OUTING_ID := "ch2b_first_flush"
const FLUSH_CHOICE_ACTION_ID := "ch2b_flush_plan"
const FLUSH_CHOICE_ID := "ch2b_purge_air"
const RETURN_VALVE_ACTION_ID := "ch2b_open_return_valve"

var _chapter2_milestones: Dictionary = {}
var _chapter2_handin_evidence: Dictionary = {}


func _run() -> void:
	await get_tree().process_frame
	if not _validate_isolation():
		await _finish_chapter2()
		return
	_record_check("GUI_input_run", not OS.has_feature("headless"), "Godot GUI runtime", "headless" if OS.has_feature("headless") else "GUI")
	var movement_mapping := _check_action_key("move_right", KEY_D)
	var interact_mapping := _check_action_key("interact", KEY_E)
	_record_check("WASD_and_interact_InputMap", movement_mapping and interact_mapping, "move_right maps to D and interact maps to E", {"move_right_D": movement_mapping, "interact_E": interact_mapping})
	if OS.has_feature("headless") or not movement_mapping or not interact_mapping:
		await _finish_chapter2()
		return

	var tree := get_tree()
	var main_error := tree.change_scene_to_file(MAIN_SCENE_PATH)
	_record_check("load_title", main_error == OK, OK, main_error)
	if main_error != OK:
		await _finish_chapter2()
		return
	if not await _wait_for_title():
		_record_check("title_ready", false, MAIN_SCENE_PATH, _current_scene_evidence())
		await _finish_chapter2()
		return

	var main_scene := tree.current_scene
	var new_game_button := main_scene.get("new_game_button") as Button
	_record_check("new_game_button_focused", is_instance_valid(new_game_button) and get_viewport().gui_get_focus_owner() == new_game_button, "focused new game button", _node_name(get_viewport().gui_get_focus_owner()))
	if not is_instance_valid(new_game_button) or get_viewport().gui_get_focus_owner() != new_game_button:
		await _finish_chapter2()
		return
	await _tap_key(KEY_ENTER, "Enter: start a new game")
	if not await _wait_for_intro(main_scene):
		_record_check("new_game_intro", false, "intro active", bool(main_scene.get("intro_active")))
		await _finish_chapter2()
		return
	await _tap_key(KEY_ENTER, "Enter: enter Village")
	if not await _wait_for_scene(VILLAGE_SCENE_PATH, "village", 1):
		_record_check("enter_village", false, VILLAGE_SCENE_PATH, _current_scene_evidence())
		await _finish_chapter2()
		return

	var village := tree.current_scene
	var village_player := _find_player(village)
	var guild_gate := _find_interactable(village, "to_guild")
	_record_check("Village_to_Guild_gate", village_player != null and guild_gate != null, "player and authored to_guild gate", {"player": _node_name(village_player), "gate": _node_name(guild_gate)})
	if village_player == null or guild_gate == null or not await _walk_until_interactable(village_player, guild_gate, 18000):
		_record_check("reach_Guild_gate_with_WASD", false, "player selects to_guild", _current_scene_evidence())
		await _finish_chapter2()
		return
	await _tap_key(KEY_E, "E: enter Guild")
	if not await _wait_for_scene(GUILD_SCENE_PATH, "guild", 2):
		_record_check("enter_Guild", false, GUILD_SCENE_PATH, _current_scene_evidence())
		await _finish_chapter2()
		return

	var guild := tree.current_scene
	var guild_player := _find_player(guild)
	var contract_board := _find_interactable(guild, "contract")
	var chapter2_available_before_chapter1 := GameState.is_quest_available(CHAPTER_TWO_QUEST_ID) and not GameState.completed_quests.has(CHAPTER_ONE_QUEST_ID)
	_record_check("Chapter2_is_available_before_Chapter1_completion", chapter2_available_before_chapter1, "toxic_sample can be accepted without clear_scrap_route completion", {"available": GameState.is_quest_available(CHAPTER_TWO_QUEST_ID), "completed_quests": GameState.completed_quests.duplicate()})
	_record_check("Guild_contract_board_present", guild_player != null and contract_board != null, "player and real contract board", {"player": _node_name(guild_player), "board": _node_name(contract_board)})
	if guild_player == null or contract_board == null or not chapter2_available_before_chapter1:
		await _finish_chapter2()
		return
	if not await _walk_until_interactable(guild_player, contract_board, 16000):
		_record_check("reach_Guild_contract_board", false, "player selects Guild contract board", _node_name(guild_player.call("get_nearest_interaction_target")))
		await _finish_chapter2()
		return
	await _tap_key(KEY_E, "E: open Guild contract catalog")
	var accept_button := guild.find_child("ContractAccept_" + CHAPTER_TWO_QUEST_ID, true, false) as Button
	var panel := guild.find_child("ContractPanel", true, false) as Control
	var panel_wait_started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - panel_wait_started < 5000 and (not is_instance_valid(panel) or not panel.is_visible_in_tree() or not is_instance_valid(accept_button)):
		await get_tree().process_frame
	var acceptance_ready := is_instance_valid(panel) and panel.is_visible_in_tree() and is_instance_valid(accept_button) and not accept_button.disabled
	_record_check("Guild_catalog_shows_enabled_Chapter2_acceptance", acceptance_ready, "visible ContractPanel and enabled ContractAccept_toxic_sample", {"panel_visible": is_instance_valid(panel) and panel.is_visible_in_tree(), "button": _node_name(accept_button), "disabled": accept_button.disabled if is_instance_valid(accept_button) else true})
	if not acceptance_ready or not await _focus_button_with_tab(accept_button, 72):
		await _finish_chapter2()
		return
	await _tap_key(KEY_ENTER, "Enter: accept toxic_sample from Guild catalog")
	var accept_started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - accept_started < 5000 and GameState.active_quest_id != CHAPTER_TWO_QUEST_ID:
		await get_tree().process_frame
	_milestone("accepted_from_Guild_catalog", GameState.active_quest_id == CHAPTER_TWO_QUEST_ID, CHAPTER_TWO_QUEST_ID, GameState.active_quest_id)
	if GameState.active_quest_id != CHAPTER_TWO_QUEST_ID:
		await _finish_chapter2()
		return

	var wasteland_gate := _find_interactable(guild, "to_wasteland")
	guild_player = _find_player(guild)
	if wasteland_gate == null or guild_player == null or not await _walk_until_interactable(guild_player, wasteland_gate, 20000, true):
		_milestone("reach_first_wasteland_gate", false, "Guild to_wasteland gate selected", _node_name(guild_player.call("get_nearest_interaction_target")) if is_instance_valid(guild_player) else "no player")
		await _finish_chapter2()
		return
	await _tap_key(KEY_E, "E: enter toxic_marsh for outing one")
	if not await _wait_for_scene(WASTELAND_SCENE_PATH, "wasteland", 3):
		_milestone("enter_first_toxic_marsh_outing", false, WASTELAND_SCENE_PATH, _current_scene_evidence())
		await _finish_chapter2()
		return

	var first_scene := tree.current_scene
	var first_player := _find_player(first_scene)
	var first_outing := GameState.campaign_outing()
	_milestone("first_authored_outing_started", first_player != null and String(first_outing.get("id", "")) == FIRST_OUTING_ID and GameState.current_route_id == "toxic_marsh", FIRST_OUTING_ID + " on toxic_marsh", {"outing": first_outing, "route": GameState.current_route_id})
	if first_player == null or String(first_outing.get("id", "")) != FIRST_OUTING_ID:
		await _finish_chapter2()
		return
	if not await _complete_channel_action(first_scene, first_player, UPPER_SAMPLE_ACTION_ID, 4.5):
		await _finish_chapter2()
		return
	first_player = _find_player(first_scene)
	if not await _complete_channel_action(first_scene, first_player, RETURN_SAMPLE_ACTION_ID, 4.5):
		await _finish_chapter2()
		return
	if not await _extract_to_village(first_scene, "first_outing", 4):
		await _finish_chapter2()
		return
	var first_campaign: Dictionary = GameState.quest_progress.get("campaign", {}).duplicate(true)
	var first_save: Dictionary = _isolated_save_evidence()
	var first_saved_result: Dictionary = first_save.get("expedition", {}).get("last_result", {})
	_milestone("first_outing_extracted_and_banked", int(first_campaign.get("outing_index", -1)) == 1 and first_campaign.get("actions", {}).has(UPPER_SAMPLE_ACTION_ID) and first_campaign.get("actions", {}).has(RETURN_SAMPLE_ACTION_ID) and String(first_saved_result.get("outcome", "")) == "extracted", "saved outing_index=1 with both sample actions banked and extracted result", {"campaign": first_campaign, "last_result": first_saved_result})
	await _dismiss_visible_dialogue("Escape: close first-outing extraction report")
	if int(first_campaign.get("outing_index", -1)) != 1:
		await _finish_chapter2()
		return

	var return_village := tree.current_scene
	var route_gate := _find_interactable(return_village, "route:toxic_marsh")
	var return_player := _find_player(return_village)
	if route_gate == null or return_player == null or not await _walk_until_interactable(return_player, route_gate, 18000):
		_milestone("reach_second_outing_route_gate", false, "Village route:toxic_marsh selected", _node_name(return_player.call("get_nearest_interaction_target")) if is_instance_valid(return_player) else "no player")
		await _finish_chapter2()
		return
	await _tap_key(KEY_E, "E: enter toxic_marsh for outing two")
	if not await _wait_for_scene(WASTELAND_SCENE_PATH, "wasteland", 5):
		_milestone("enter_second_toxic_marsh_outing", false, WASTELAND_SCENE_PATH, _current_scene_evidence())
		await _finish_chapter2()
		return

	var second_scene := tree.current_scene
	var second_player := _find_player(second_scene)
	var second_outing := GameState.campaign_outing()
	_milestone("second_authored_outing_started", second_player != null and String(second_outing.get("id", "")) == CHAPTER2_SECOND_OUTING_ID and GameState.current_route_id == "toxic_marsh", CHAPTER2_SECOND_OUTING_ID + " on toxic_marsh", {"outing": second_outing, "route": GameState.current_route_id})
	if second_player == null or String(second_outing.get("id", "")) != CHAPTER2_SECOND_OUTING_ID:
		await _finish_chapter2()
		return
	var choice_action := _find_campaign_action(second_scene, FLUSH_CHOICE_ACTION_ID)
	if choice_action == null or not await _walk_until_interactable(second_player, choice_action, 18000, true):
		_milestone("reach_second_outing_flush_choice", false, FLUSH_CHOICE_ACTION_ID, _node_name(choice_action))
		await _finish_chapter2()
		return
	await _tap_key(KEY_E, "E: open first-flush choice")
	var choice_state: Dictionary = GameState.campaign_choice_state()
	var choice_panel := second_scene.find_child("CampaignChoicePanel", true, false) as Control
	var choice_wait_started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - choice_wait_started < 5000 and (not is_instance_valid(choice_panel) or not choice_panel.is_visible_in_tree()):
		await get_tree().process_frame
	var choice_open := is_instance_valid(choice_panel) and choice_panel.is_visible_in_tree() and String(choice_state.get("action_id", "")) == FLUSH_CHOICE_ACTION_ID
	_record_check("second_outing_choice_panel_opened_by_E", choice_open, FLUSH_CHOICE_ACTION_ID, {"visible": is_instance_valid(choice_panel) and choice_panel.is_visible_in_tree(), "state": choice_state})
	if not choice_open:
		await _finish_chapter2()
		return
	var hud := _current_hud()
	var option_button := _campaign_option_button(hud, choice_state, FLUSH_CHOICE_ID)
	if not is_instance_valid(option_button) or not await _focus_button_with_tab(option_button, 12):
		_record_check("flush_choice_option_has_keyboard_focus", false, FLUSH_CHOICE_ID + " button focused", _node_name(get_viewport().gui_get_focus_owner()))
		await _finish_chapter2()
		return
	await _tap_key(KEY_ENTER, "Enter: select quick air purge")
	var choice_started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - choice_started < 5000 and GameState.campaign_action_status(FLUSH_CHOICE_ACTION_ID) != "done":
		await get_tree().process_frame
	_milestone("physical_keyboard_selected_flush_choice", GameState.campaign_action_status(FLUSH_CHOICE_ACTION_ID) == "done" and GameState.campaign_selected_choice(FLUSH_CHOICE_ACTION_ID) == FLUSH_CHOICE_ID, FLUSH_CHOICE_ID, GameState.campaign_selected_choice(FLUSH_CHOICE_ACTION_ID))
	if GameState.campaign_action_status(FLUSH_CHOICE_ACTION_ID) != "done":
		await _finish_chapter2()
		return
	second_player = _find_player(second_scene)
	if not await _complete_channel_action(second_scene, second_player, RETURN_VALVE_ACTION_ID, 8.5):
		await _finish_chapter2()
		return
	if not await _extract_to_village(second_scene, "second_outing", 6):
		await _finish_chapter2()
		return
	var final_campaign: Dictionary = GameState.quest_progress.get("campaign", {}).duplicate(true)
	var final_save: Dictionary = _isolated_save_evidence()
	var second_result: Dictionary = final_save.get("expedition", {}).get("last_result", {})
	_milestone("second_outing_extracted_and_banked", int(final_campaign.get("outing_index", -1)) == 2 and final_campaign.get("actions", {}).has(RETURN_VALVE_ACTION_ID) and final_campaign.get("actions", {}).get(FLUSH_CHOICE_ACTION_ID, "") == FLUSH_CHOICE_ID and String(second_result.get("outcome", "")) == "extracted", "saved outing_index=2 with choice and valve action banked and extracted result", {"campaign": final_campaign, "last_result": second_result})
	_chapter2_milestones["second_extraction"] = second_result
	await _walk_to_guild_and_handin_chapter2(tree)
	await _finish_chapter2()


func _walk_to_guild_and_handin_chapter2(tree: SceneTree) -> void:
	var debrief_closed := await _dismiss_visible_dialogue("Escape: close second-outing extraction debrief")
	_record_check("second_outing_debrief_closed_before_Guild_travel", debrief_closed, "Village HUD dialogue is closed with injected Escape", _dialogue_evidence())
	if not debrief_closed:
		return
	var village := tree.current_scene
	var village_player := _find_player(village)
	var guild_gate := _find_interactable(village, "to_guild")
	var guild_gate_reached := is_instance_valid(village_player) and is_instance_valid(guild_gate) and await _walk_until_interactable(village_player, guild_gate, 18000)
	_record_check("second_outing_WASD_reaches_authored_Village_Guild_gate", guild_gate_reached, "player selects the authored to_guild interactable through WASD", {
		"player": _node_name(village_player),
		"gate": _node_name(guild_gate),
		"player_position": _vector_data(village_player.global_position) if is_instance_valid(village_player) else [],
		"gate_position": _vector_data(guild_gate.global_position) if is_instance_valid(guild_gate) else [],
		"selected_target": _node_name(village_player.call("get_nearest_interaction_target")) if is_instance_valid(village_player) else "invalid"
	})
	if not guild_gate_reached:
		return
	await _tap_key(KEY_E, "E: return to the Guild after Chapter 2 outing two")
	var expected_transition_count := _transition_events.size() + 1
	var guild_ready := await _wait_for_scene(GUILD_SCENE_PATH, "guild", expected_transition_count)
	_record_check("second_outing_physical_Village_gate_enters_Guild", guild_ready, "SceneRouter loads Guild through the selected Village gate", _current_scene_evidence())
	if not guild_ready:
		return
	_record_persistent_root("after_chapter2_second_outing_village_to_guild")

	var guild := tree.current_scene
	var guild_player := _find_player(guild)
	var reward_counter := _find_interactable(guild, "reward")
	var reached_counter := is_instance_valid(guild_player) and is_instance_valid(reward_counter) and await _walk_until_interactable(guild_player, reward_counter, 18000)
	_record_check("Chapter2_WASD_reaches_real_Guild_reward_counter", reached_counter, "player selects the Guild reward interactable using physical movement", {
		"player": _node_name(guild_player),
		"counter": _node_name(reward_counter),
		"counter_position": _vector_data(reward_counter.global_position) if is_instance_valid(reward_counter) else [],
		"player_position": _vector_data(guild_player.global_position) if is_instance_valid(guild_player) else [],
		"selected_target": _node_name(guild_player.call("get_nearest_interaction_target")) if is_instance_valid(guild_player) else "invalid"
	})
	if not reached_counter:
		return
	var requirements: Array[Dictionary] = GameState.active_quest_requirements()
	var ledger_requirement: Dictionary = {}
	var required_requirements_ready := true
	for requirement: Dictionary in requirements:
		if String(requirement.get("kind", "")) == "discover" and bool(requirement.get("optional", false)):
			ledger_requirement = requirement
		if not bool(requirement.get("optional", false)) and not bool(requirement.get("ready", false)):
			required_requirements_ready = false
	var ledger_discovered := GameState.has_story_discovery("toxic_marsh", "story_marsh_ledger")
	var ready_with_undiscovered_ledger := GameState.active_quest_id == CHAPTER_TWO_QUEST_ID and not ledger_discovered and not ledger_requirement.is_empty() and not bool(ledger_requirement.get("ready", true)) and required_requirements_ready and GameState.is_active_quest_ready() and not GameState.has_active_expedition() and GameState.current_scene_id == "guild"
	_chapter2_milestones["undiscovered_optional_ledger_does_not_block_ready_contract"] = ready_with_undiscovered_ledger
	_record_check("undiscovered_optional_ledger_does_not_block_ready_contract", ready_with_undiscovered_ledger, "toxic_sample is deliverable at Guild with story_marsh_ledger undiscovered while every nonoptional requirement is ready", {
		"active_quest_id": GameState.active_quest_id,
		"requirements": requirements,
		"all_required_requirements_ready": required_requirements_ready,
		"is_active_quest_ready": GameState.is_active_quest_ready(),
		"ledger_requirement": ledger_requirement,
		"ledger_discovered": ledger_discovered,
		"quest_counter_defeats": GameState.quest_counter_value("defeat_enemy"),
		"bio_crystal_inventory": int(GameState.inventory.get("bio_crystal", 0)),
		"campaign": GameState.quest_progress.get("campaign", {}).duplicate(true),
		"active_expedition": GameState.has_active_expedition()
	})
	if GameState.active_quest_id != CHAPTER_TWO_QUEST_ID or not ready_with_undiscovered_ledger:
		return

	var guild_hud := _current_hud()
	var contract_panel := guild_hud.get("contract_panel") as Control if is_instance_valid(guild_hud) else null
	var contract_list := guild_hud.get("contract_list") as VBoxContainer if is_instance_valid(guild_hud) else null
	var panel_closed_before_j := is_instance_valid(contract_panel) and not contract_panel.visible
	_record_check("Chapter2_Guild_J_panel_closed_before_open", panel_closed_before_j, "Guild contract panel is initially closed", {
		"hud_valid": is_instance_valid(guild_hud),
		"panel_valid": is_instance_valid(contract_panel),
		"panel_visible": contract_panel.visible if is_instance_valid(contract_panel) else false,
		"reward_counter_selected": guild_player.call("get_nearest_interaction_target") == reward_counter
	})
	if not panel_closed_before_j:
		return
	await _tap_key(KEY_J, "J: open Guild contract details before Chapter 2 delivery")
	var panel_wait_started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - panel_wait_started < 4000 and (not is_instance_valid(contract_panel) or not contract_panel.visible):
		await get_tree().process_frame
	var panel_open := is_instance_valid(contract_panel) and contract_panel.visible
	await get_tree().process_frame
	var current_contract_card := guild.find_child("CurrentContractCard", true, false) as Control
	var optional_objective_label := guild.find_child("ContractOptionalObjectives", true, false) as Label
	var contract_scroll := guild.find_child("ContractScroll", true, false) as ScrollContainer
	var optional_objective_text := optional_objective_label.text if is_instance_valid(optional_objective_label) else ""
	var optional_objective_in_scroll_view: bool = is_instance_valid(contract_scroll) and is_instance_valid(optional_objective_label) and contract_scroll.get_global_rect().encloses(optional_objective_label.get_global_rect())
	var optional_card_capture := await _capture_viewport_screenshot("chapter2-guild-optional-objective.png") if panel_open else {"saved": false, "reason": "Guild J panel did not open"}
	var briefing_button := contract_list.get_node_or_null("ContractNotes_ActiveQuestBriefing") as Button if is_instance_valid(contract_list) else null
	var briefing_text := contract_list.get_node_or_null("ContractFieldNotes_ActiveQuestBriefing") as Label if is_instance_valid(contract_list) else null
	var briefing_focused := panel_open and is_instance_valid(briefing_button) and await _focus_button_with_tab(briefing_button, 72)
	if briefing_focused:
		await _tap_key(KEY_ENTER, "Enter: expand live toxic_sample Guild J details")
	var briefing_wait_started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - briefing_wait_started < 4000 and is_instance_valid(briefing_text) and not briefing_text.visible:
		await get_tree().process_frame
	var live_contract_text := briefing_text.text if is_instance_valid(briefing_text) else ""
	var live_briefing_visible := panel_open and briefing_focused and is_instance_valid(briefing_text) and briefing_text.visible
	var optional_ledger_copy_visible: bool = panel_open and is_instance_valid(current_contract_card) and is_instance_valid(optional_objective_label) and optional_objective_label.is_visible_in_tree() and optional_objective_in_scroll_view and optional_objective_text.contains("選讀目標（不影響交付）") and optional_objective_text.contains("排水泵站的分流帳本（未調查）") and bool(ledger_requirement.get("optional", false)) and not ledger_discovered
	var optional_discovery_not_revealed: bool = live_briefing_visible and not live_contract_text.contains("地下欄標著污染警報下的手寫簽名") and not live_contract_text.contains("外圍支線則被劃除") and live_contract_text.contains("找不到也不影響委託交付")
	_chapter2_handin_evidence["guild_j"] = {
		"panel_open": panel_open,
		"current_contract_card_found": is_instance_valid(current_contract_card),
		"optional_objective_label_visible": is_instance_valid(optional_objective_label) and optional_objective_label.is_visible_in_tree(),
		"optional_objective_label_in_scroll_view": optional_objective_in_scroll_view,
		"optional_objective_text": optional_objective_text,
		"optional_objective_screenshot": optional_card_capture,
		"briefing_button_found": is_instance_valid(briefing_button),
		"briefing_focused": briefing_focused,
		"briefing_visible": live_briefing_visible,
		"optional_ledger_copy_visible": optional_ledger_copy_visible,
		"optional_discovery_result_remains_hidden": optional_discovery_not_revealed,
		"ledger_requirement": ledger_requirement,
		"ledger_discovered": ledger_discovered,
		"visible_contract_text": live_contract_text
	}
	_record_check("Guild_J_shows_ledger_is_optional_and_does_not_block_delivery", optional_ledger_copy_visible, "live expanded Guild J text shows the undiscovered pump ledger as optional / nonblocking", _chapter2_handin_evidence["guild_j"])
	_record_check("Guild_J_does_not_reveal_undiscovered_ledger_result", optional_discovery_not_revealed, "live expanded briefing communicates that the ledger is nonblocking without exposing undiscovered findings", _chapter2_handin_evidence["guild_j"])
	if panel_open:
		await _tap_key(KEY_ESCAPE, "Escape: close Guild J details before physical Chapter 2 delivery")
	var close_started := Time.get_ticks_msec()
	while is_instance_valid(contract_panel) and contract_panel.visible and Time.get_ticks_msec() - close_started < 4000:
		await get_tree().process_frame
	var panel_closed := panel_open and is_instance_valid(contract_panel) and not contract_panel.visible
	var counter_selected: bool = is_instance_valid(guild_player) and is_instance_valid(reward_counter) and guild_player.call("get_nearest_interaction_target") == reward_counter
	_record_check("Guild_J_closed_with_Escape_and_physical_reward_counter_stays_selected", panel_closed and counter_selected, "J panel closes by Escape and the same physical reward counter remains selected", {
		"panel_closed_by_Escape": panel_closed,
		"reward_counter_selected": counter_selected,
		"player_position": _vector_data(guild_player.global_position) if is_instance_valid(guild_player) else [],
		"counter_position": _vector_data(reward_counter.global_position) if is_instance_valid(reward_counter) else []
	})
	if not panel_closed or not counter_selected:
		return

	var pre_handin_inventory: Dictionary = GameState.inventory.duplicate(true)
	var pre_handin_level := int(GameState.level)
	var pre_handin_xp_field := int(GameState.xp)
	var pre_handin_lifetime_xp := _lifetime_xp(pre_handin_level, pre_handin_xp_field)
	var expected_inventory_delta := _expected_handin_inventory_delta(DataRegistry.get_quest(CHAPTER_TWO_QUEST_ID))
	var pre_handin_save := _isolated_save_evidence()
	await _tap_key(KEY_E, "E: hand in completed toxic_sample at the real Guild reward counter")
	var handin_started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - handin_started < 8000 and GameState.active_quest_id == CHAPTER_TWO_QUEST_ID:
		await get_tree().process_frame
	var post_handin_inventory: Dictionary = GameState.inventory.duplicate(true)
	var post_handin_level := int(GameState.level)
	var post_handin_xp := _lifetime_xp(post_handin_level, int(GameState.xp))
	var observed_inventory_delta := _inventory_delta(pre_handin_inventory, post_handin_inventory)
	var handin_xp_delta := post_handin_xp - pre_handin_lifetime_xp
	var handin_completed := GameState.active_quest_id.is_empty() and GameState.completed_quests.has(CHAPTER_TWO_QUEST_ID)
	var handin_effects_exact := expected_inventory_delta == observed_inventory_delta and handin_xp_delta == 35
	var saved_after_handin := _isolated_save_evidence()
	var saved_completed_quests: Variant = saved_after_handin.get("completed_quests", [])
	var saved_handin: bool = bool(saved_after_handin.get("checksum_valid", false)) and String(saved_after_handin.get("active_quest_id", "")) == "" and saved_completed_quests is Array and saved_completed_quests.has(CHAPTER_TWO_QUEST_ID)
	_chapter2_handin_evidence["first_delivery"] = {
		"interaction_id": String(reward_counter.get("interaction_id")),
		"active_quest_after": GameState.active_quest_id,
		"completed_quests_after": GameState.completed_quests.duplicate(),
		"requirements_before_delivery": requirements,
		"optional_ledger_undiscovered": not ledger_discovered,
		"inventory_before": pre_handin_inventory,
		"inventory_after": post_handin_inventory,
		"expected_inventory_delta": expected_inventory_delta,
		"observed_inventory_delta": observed_inventory_delta,
		"level_before": pre_handin_level,
		"level_after": post_handin_level,
		"xp_field_before": pre_handin_xp_field,
		"xp_field_after": int(GameState.xp),
		"lifetime_xp_before": pre_handin_lifetime_xp,
		"lifetime_xp_after": post_handin_xp,
		"lifetime_xp_delta": handin_xp_delta,
		"isolated_save_before": pre_handin_save,
		"isolated_save_after": saved_after_handin,
		"checksummed_handin_saved": saved_handin,
		"dialogue": _dialogue_evidence()
	}
	var delivery_passed: bool = handin_completed and handin_effects_exact and saved_handin
	_record_check("physical_Guild_E_delivers_toxic_sample_with_exact_material_and_XP_effects", delivery_passed, "one real counter E completes toxic_sample, applies the exact reward delta and +35 lifetime XP, and writes a valid isolated save", _chapter2_handin_evidence["first_delivery"])
	_chapter2_milestones["guild_handin"] = delivery_passed
	if not delivery_passed:
		return

	var before_reload_inventory: Dictionary = GameState.inventory.duplicate(true)
	var before_reload_completed: Array[String] = GameState.completed_quests.duplicate()
	var before_reload_level := int(GameState.level)
	var before_reload_xp_field := int(GameState.xp)
	var before_reload_lifetime_xp := _lifetime_xp(before_reload_level, before_reload_xp_field)
	var before_reload_payload_hash := String(saved_after_handin.get("payload_sha256", ""))
	var load_succeeded := SaveManager.load_game(false, false)
	await get_tree().process_frame
	var after_reload_save := _isolated_save_evidence()
	var after_reload_inventory: Dictionary = GameState.inventory.duplicate(true)
	var after_reload_level := int(GameState.level)
	var after_reload_xp_field := int(GameState.xp)
	var after_reload_lifetime_xp := _lifetime_xp(after_reload_level, after_reload_xp_field)
	var reload_preserved := load_succeeded and GameState.active_quest_id.is_empty() and GameState.completed_quests == before_reload_completed and GameState.completed_quests.has(CHAPTER_TWO_QUEST_ID) and after_reload_inventory == before_reload_inventory and after_reload_level == before_reload_level and after_reload_xp_field == before_reload_xp_field and after_reload_lifetime_xp == before_reload_lifetime_xp and not GameState.has_active_expedition() and GameState.current_scene_id == "guild" and tree.current_scene.scene_file_path == GUILD_SCENE_PATH and bool(after_reload_save.get("checksum_valid", false)) and String(after_reload_save.get("payload_sha256", "")) == before_reload_payload_hash
	_chapter2_handin_evidence["save_manager_reload"] = {
		"method": "SaveManager.load_game(false, false)",
		"load_succeeded": load_succeeded,
		"completed_quests_before": before_reload_completed,
		"completed_quests_after": GameState.completed_quests.duplicate(),
		"inventory_before": before_reload_inventory,
		"inventory_after": after_reload_inventory,
		"inventory_unchanged": before_reload_inventory == after_reload_inventory,
		"level_before": before_reload_level,
		"level_after": after_reload_level,
		"xp_field_before": before_reload_xp_field,
		"xp_field_after": after_reload_xp_field,
		"lifetime_xp_before": before_reload_lifetime_xp,
		"lifetime_xp_after": after_reload_lifetime_xp,
		"active_expedition": GameState.has_active_expedition(),
		"scene": _current_scene_evidence(),
		"save_before": before_reload_payload_hash,
		"save_after": after_reload_save.get("payload_sha256", ""),
		"save_unchanged_by_reload": String(after_reload_save.get("payload_sha256", "")) == before_reload_payload_hash
	}
	_record_check("isolated_SaveManager_reload_preserves_Chapter2_completion_and_rewards", reload_preserved, "loading the isolated hand-in save preserves inventory, level, XP and completion without changing Guild scene or save payload", _chapter2_handin_evidence["save_manager_reload"])
	if not reload_preserved:
		return

	var completion_report_closed := await _dismiss_visible_dialogue("Escape: close toxic_sample completion report before duplicate E")
	_record_check("Chapter2_completion_report_closed_before_duplicate_E", completion_report_closed, "completion dialogue closes with injected Escape", _dialogue_evidence())
	if not completion_report_closed:
		return
	var before_repeat_inventory: Dictionary = GameState.inventory.duplicate(true)
	var before_repeat_completed: Array[String] = GameState.completed_quests.duplicate()
	var before_repeat_level := int(GameState.level)
	var before_repeat_xp := _lifetime_xp(before_repeat_level, int(GameState.xp))
	var before_repeat_save := _isolated_save_evidence()
	var same_counter_selected: bool = guild_player.call("get_nearest_interaction_target") == reward_counter
	_record_check("Chapter2_duplicate_E_starts_at_same_physical_reward_counter", same_counter_selected, "same Guild reward counter remains selected after data-only reload", {
		"selected_target": _node_name(guild_player.call("get_nearest_interaction_target")),
		"player_position": _vector_data(guild_player.global_position),
		"counter_position": _vector_data(reward_counter.global_position)
	})
	if not same_counter_selected:
		return
	await _tap_key(KEY_E, "E: attempt toxic_sample delivery again after isolated SaveManager reload")
	await get_tree().process_frame
	var after_repeat_inventory: Dictionary = GameState.inventory.duplicate(true)
	var after_repeat_completed: Array[String] = GameState.completed_quests.duplicate()
	var after_repeat_level := int(GameState.level)
	var after_repeat_xp := _lifetime_xp(after_repeat_level, int(GameState.xp))
	var after_repeat_save := _isolated_save_evidence()
	var duplicate_blocked := GameState.active_quest_id.is_empty() and after_repeat_inventory == before_repeat_inventory and after_repeat_completed == before_repeat_completed and after_repeat_completed.has(CHAPTER_TWO_QUEST_ID) and after_repeat_level == before_repeat_level and after_repeat_xp == before_repeat_xp and String(after_repeat_save.get("payload_sha256", "")) == String(before_repeat_save.get("payload_sha256", ""))
	_chapter2_handin_evidence["repeat_delivery"] = {
		"active_quest_after": GameState.active_quest_id,
		"inventory_before": before_repeat_inventory,
		"inventory_after": after_repeat_inventory,
		"inventory_unchanged": after_repeat_inventory == before_repeat_inventory,
		"completed_quests_before": before_repeat_completed,
		"completed_quests_after": after_repeat_completed,
		"completion_unchanged": after_repeat_completed == before_repeat_completed,
		"level_before": before_repeat_level,
		"level_after": after_repeat_level,
		"xp_before": before_repeat_xp,
		"xp_after": after_repeat_xp,
		"save_hash_before": before_repeat_save.get("payload_sha256", ""),
		"save_hash_after": after_repeat_save.get("payload_sha256", ""),
		"save_unchanged": String(after_repeat_save.get("payload_sha256", "")) == String(before_repeat_save.get("payload_sha256", "")),
		"dialogue": _dialogue_evidence()
	}
	_chapter2_milestones["duplicate_delivery_guard"] = duplicate_blocked
	_record_check("second_physical_Guild_E_does_not_duplicate_Chapter2_rewards_XP_or_save", duplicate_blocked, "after reload, repeat E leaves inventory, XP, level, completed contract and checksummed save unchanged", _chapter2_handin_evidence["repeat_delivery"])
	_record_check("Chapter2_journey_finishes_alive_in_Guild_after_handin", GameState.current_scene_id == "guild" and tree.current_scene.scene_file_path == GUILD_SCENE_PATH and GameState.hp > 0 and not GameState.death_pending and not GameState.has_active_expedition() and _all_transitions_succeeded(), "living player in Guild with no active outing after every physical SceneRouter transition", {
		"scene": _current_scene_evidence(),
		"hp": GameState.hp,
		"death_pending": GameState.death_pending,
		"active_expedition": GameState.has_active_expedition(),
		"transitions": _transition_events
	})


func _complete_channel_action(scene: Node, player: Node2D, action_id: String, duration: float) -> bool:
	var action := _find_campaign_action(scene, action_id)
	var input_count_before := _input_events.size()
	var movement_started := Time.get_ticks_msec()
	var movement_evidence := _channel_movement_evidence(player, action, movement_started, input_count_before)
	var route_timeout := 60000 if action_id == RETURN_SAMPLE_ACTION_ID else 30000
	var authored_route := await _walk_authored_channel_route(scene, player, action, action_id, route_timeout)
	var reached := bool(authored_route.get("selected_action", false))
	if not bool(authored_route.get("available", false)):
		reached = is_instance_valid(player) and is_instance_valid(action) and await _walk_until_interactable(player, action, 20000, true)
		movement_evidence["direct_approach_retry"] = _channel_movement_evidence(player, action, movement_started, input_count_before)
	elif not reached and action_id == RETURN_SAMPLE_ACTION_ID:
		movement_evidence["direct_approach_after_authored_route"] = {
			"attempted": false,
			"reason": "preserve the authored west/north corridor around TerrainBasin_water_0",
			"player_at_route_failure": _vector_data(player.global_position) if is_instance_valid(player) else []
		}
	elif not reached:
		var retry_started := Time.get_ticks_msec()
		var retry_input_count := _input_events.size()
		reached = is_instance_valid(player) and is_instance_valid(action) and await _walk_until_interactable(player, action, 12000, true)
		movement_evidence["direct_approach_after_authored_route"] = {
			"selected_action": reached,
			"elapsed_ms": Time.get_ticks_msec() - retry_started,
			"input_event_count_delta": _input_events.size() - retry_input_count,
			"final": _channel_movement_evidence(player, action, retry_started, retry_input_count)
		}
	movement_evidence["authored_route"] = authored_route
	_record_check("reach_" + action_id, reached, action_id + " selected by player movement", {"player": _node_name(player), "action": _node_name(action), "status": GameState.campaign_action_status(action_id), "initial_attempt": movement_evidence})
	if not reached:
		return false
	var approach := await _prepare_channel_hold(player, action, action_id)
	_record_check("stabilize_" + action_id + "_inside_channel_range", bool(approach.get("safe_to_hold", false)), "settled player selected on the action at least 20px inside its channel radius", approach)
	if not bool(approach.get("safe_to_hold", false)):
		return false
	var hold_evidence := await _hold_channel_action(player, action, action_id, duration)
	var done := await _wait_for_campaign_action(action_id, "done", 5000)
	var after_hold := _channel_action_snapshot(player, action, action_id)
	var hold_valid := bool(hold_evidence.get("e_key_press_and_release_valid", false)) and bool(hold_evidence.get("held_input_samples_valid", false)) and bool(hold_evidence.get("inside_channel_radius_for_all_samples", false)) and int(hold_evidence.get("elapsed_ms", 0)) >= roundi(duration * 1000.0)
	var completed := done and hold_valid
	var hold_failure_screenshot := {}
	if not completed:
		hold_failure_screenshot = await _capture_viewport_screenshot("chapter2-channel-hold-failure-" + action_id + ".png")
	_milestone(action_id + "_completed_with_E_hold", completed, "done after a timed physical E hold with in-range progress evidence", {"status": GameState.campaign_action_status(action_id), "wait_succeeded": done, "hold_valid": hold_valid, "hold": hold_evidence, "after_hold": after_hold, "failure_viewport_capture": hold_failure_screenshot})
	return completed


func _walk_authored_channel_route(scene: Node, player: Node2D, action: Node2D, action_id: String, timeout_ms: int) -> Dictionary:
	var path_data := _authored_channel_waypoints(scene, action_id)
	var normalized_waypoints: Array = path_data.get("normalized", [])
	var waypoints_world: Array[Vector2] = []
	for raw_waypoint: Variant in path_data.get("world", []):
		if raw_waypoint is Vector2:
			waypoints_world.append(raw_waypoint)
	if normalized_waypoints.is_empty() or waypoints_world.is_empty():
		return {"available": false, "selected_action": false, "reason": "no authored waypoint set for action"}
	if not is_instance_valid(player) or not is_instance_valid(action):
		return {"available": true, "selected_action": false, "reason": "player or action node missing", "waypoints_normalized": normalized_waypoints}
	var started := Time.get_ticks_msec()
	var input_count_before := _input_events.size()
	var reached_count := 0
	var failed_waypoint: Array = []
	var waypoint_navigation: Array[Dictionary] = []
	for waypoint: Vector2 in waypoints_world:
		var remaining := maxi(0, timeout_ms - (Time.get_ticks_msec() - started))
		if remaining <= 0:
			failed_waypoint = _vector_data(waypoint)
			waypoint_navigation.append(_waypoint_navigation_evidence(player, waypoint, false, "route_timeout_before_attempt"))
			break
		var waypoint_reached := true
		if player.global_position.distance_to(waypoint) > 32.0:
			var combat_buffer_ms := 6000 if action_id == RETURN_SAMPLE_ACTION_ID else 0
			var estimated_ms := clampi(roundi(player.global_position.distance_to(waypoint) / 188.0 * 1500.0 + 1000.0 + combat_buffer_ms), 3000, 18000)
			var waypoint_timeout := mini(remaining, estimated_ms)
			waypoint_reached = await _walk_to_position(player, waypoint, waypoint_timeout, true)
			var waypoint_evidence := _waypoint_navigation_evidence(player, waypoint, waypoint_reached, "walk_to_position")
			if not waypoint_reached:
				failed_waypoint = _vector_data(waypoint)
				waypoint_evidence["viewport_capture"] = await _capture_waypoint_failure_screenshot()
				waypoint_navigation.append(waypoint_evidence)
				break
			waypoint_navigation.append(waypoint_evidence)
		else:
			waypoint_navigation.append(_waypoint_navigation_evidence(player, waypoint, true, "already_within_waypoint_tolerance"))
		reached_count += 1
	var selected := reached_count == waypoints_world.size() and not waypoints_world.is_empty()
	if selected:
		var remaining_for_target := maxi(0, timeout_ms - (Time.get_ticks_msec() - started))
		selected = remaining_for_target > 0 and await _walk_until_interactable(player, action, remaining_for_target, true)
	var final_evidence := _channel_movement_evidence(player, action, started, input_count_before)
	return {
		"available": true,
		"selected_action": selected,
		"waypoints_normalized": normalized_waypoints,
		"waypoints_world": path_data.get("world_arrays", []),
		"waypoints_reached": reached_count,
		"failed_waypoint": failed_waypoint,
		"waypoint_navigation": waypoint_navigation,
		"elapsed_ms": Time.get_ticks_msec() - started,
		"input_event_count_delta": _input_events.size() - input_count_before,
		"final": final_evidence
	}


func _waypoint_navigation_evidence(player: Node2D, waypoint: Vector2, reached: bool, phase: String) -> Dictionary:
	var evidence := {
		"phase": phase,
		"reached": reached,
		"waypoint_world_position": _vector_data(waypoint),
		"player_world_position": _vector_data(player.global_position) if is_instance_valid(player) else [],
		"player_velocity": _vector_data((player as CharacterBody2D).velocity) if is_instance_valid(player) and player is CharacterBody2D else [],
		"distance_to_waypoint": player.global_position.distance_to(waypoint) if is_instance_valid(player) else -1.0,
		"nearby_enemies_to_player": _nearby_enemy_evidence(player.global_position, 300.0) if is_instance_valid(player) else [],
		"nearby_enemies_to_waypoint": _nearby_enemy_evidence(waypoint, 300.0)
	}
	if not is_instance_valid(player):
		evidence["segment_collision"] = "no player"
		return evidence
	var player_body := player as CollisionObject2D
	if player_body == null:
		evidence["segment_collision"] = "player is not a CollisionObject2D"
		return evidence
	if player is CharacterBody2D:
		evidence["slide_collisions"] = _slide_collision_evidence(player as CharacterBody2D)
		evidence["player_body_sweep"] = _body_sweep_evidence(player as CharacterBody2D, waypoint)
	var query := PhysicsRayQueryParameters2D.create(player.global_position, waypoint, 0x7fffffff, [player_body.get_rid()])
	query.collide_with_areas = false
	var collision: Dictionary = player.get_world_2d().direct_space_state.intersect_ray(query)
	if collision.is_empty():
		evidence["segment_collision"] = "no body hit on player-to-waypoint center ray"
	else:
		var collider := collision.get("collider") as Node
		evidence["segment_collision"] = {
			"collider": _node_name(collider),
			"collider_class": collider.get_class() if is_instance_valid(collider) else "unknown",
			"position": _vector_data(collision.get("position", Vector2.ZERO)),
			"normal": _vector_data(collision.get("normal", Vector2.ZERO)),
			"collider_details": _collision_node_evidence(collider)
		}
	return evidence


func _slide_collision_evidence(player: CharacterBody2D) -> Array[Dictionary]:
	var collisions: Array[Dictionary] = []
	for index in range(player.get_slide_collision_count()):
		var collision := player.get_slide_collision(index)
		var collider := collision.get_collider() as Node
		collisions.append({
			"collider": _node_name(collider),
			"collider_class": collider.get_class() if is_instance_valid(collider) else "unknown",
			"collider_details": _collision_node_evidence(collider),
			"position": _vector_data(collision.get_position()),
			"normal": _vector_data(collision.get_normal()),
			"collider_velocity": _vector_data(collision.get_collider_velocity()),
			"travel": _vector_data(collision.get_travel()),
			"remainder": _vector_data(collision.get_remainder())
		})
	return collisions


func _body_sweep_evidence(player: CharacterBody2D, destination: Vector2) -> Dictionary:
	var collision_shape := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if not is_instance_valid(collision_shape) or collision_shape.shape == null:
		return {"available": false, "reason": "player CollisionShape2D is missing"}
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = collision_shape.shape
	query.transform = collision_shape.global_transform
	query.collision_mask = player.collision_mask
	query.exclude = [player.get_rid()]
	query.collide_with_areas = false
	query.motion = destination - player.global_position
	var space := player.get_world_2d().direct_space_state
	var fractions := space.cast_motion(query)
	var result := {
		"available": true,
		"shape_class": collision_shape.shape.get_class(),
		"shape_world_transform_origin": _vector_data(collision_shape.global_position),
		"requested_motion": _vector_data(query.motion),
		"safe_fraction": float(fractions[0]) if fractions.size() >= 2 else -1.0,
		"unsafe_fraction": float(fractions[1]) if fractions.size() >= 2 else -1.0,
		"destination_overlaps": []
	}
	var destination_query := PhysicsShapeQueryParameters2D.new()
	destination_query.shape = collision_shape.shape
	destination_query.transform = collision_shape.global_transform
	destination_query.transform.origin += destination - player.global_position
	destination_query.collision_mask = player.collision_mask
	destination_query.exclude = [player.get_rid()]
	destination_query.collide_with_areas = false
	destination_query.motion = Vector2.ZERO
	result["destination_overlaps"] = _shape_overlap_evidence(space, destination_query)
	if fractions.size() < 2 or float(fractions[1]) >= 1.0:
		result["sweep_blocker_overlaps"] = []
		return result
	var blocker_query := PhysicsShapeQueryParameters2D.new()
	blocker_query.shape = collision_shape.shape
	blocker_query.transform = collision_shape.global_transform
	blocker_query.collision_mask = player.collision_mask
	blocker_query.exclude = [player.get_rid()]
	blocker_query.collide_with_areas = false
	blocker_query.motion = Vector2.ZERO
	blocker_query.transform.origin += (destination - player.global_position) * float(fractions[1])
	result["sweep_blocker_overlaps"] = _shape_overlap_evidence(space, blocker_query)
	return result


func _shape_overlap_evidence(space: PhysicsDirectSpaceState2D, query: PhysicsShapeQueryParameters2D) -> Array[Dictionary]:
	var overlaps: Array[Dictionary] = []
	for hit: Dictionary in space.intersect_shape(query, 16):
		var collider := hit.get("collider") as Node
		overlaps.append({
			"collider": _node_name(collider),
			"collider_class": collider.get_class() if is_instance_valid(collider) else "unknown",
			"collider_details": _collision_node_evidence(collider),
			"shape_index": int(hit.get("shape", -1))
		})
	return overlaps


func _collision_node_evidence(collider: Node) -> Dictionary:
	if not is_instance_valid(collider):
		return {"valid": false}
	var evidence: Dictionary = {
		"valid": true,
		"node_name": _node_name(collider),
		"node_path": str(collider.get_path()),
		"class": collider.get_class(),
		"parent_name": _node_name(collider.get_parent()),
		"groups": []
	}
	var groups: Array[String] = []
	for group: StringName in collider.get_groups():
		groups.append(String(group))
	evidence["groups"] = groups
	if collider is Node2D:
		evidence["world_position"] = _vector_data((collider as Node2D).global_position)
	if collider is CollisionObject2D:
		evidence["collision_layer"] = (collider as CollisionObject2D).collision_layer
		evidence["collision_mask"] = (collider as CollisionObject2D).collision_mask
	if collider.has_meta("map_label"):
		evidence["map_label"] = str(collider.get_meta("map_label"))
	var prop_id: Variant = collider.get("prop_id")
	if prop_id != null:
		evidence["prop_id"] = str(prop_id)
	var blocks_movement: Variant = collider.get("blocks_movement")
	if blocks_movement != null:
		evidence["blocks_movement"] = bool(blocks_movement)
	var shapes: Array[Dictionary] = []
	for child: Node in collider.get_children():
		if child is CollisionShape2D:
			var collision_shape := child as CollisionShape2D
			if collision_shape.shape == null:
				continue
			var shape_evidence: Dictionary = {
				"node_name": _node_name(collision_shape),
				"shape_class": collision_shape.shape.get_class(),
				"world_position": _vector_data(collision_shape.global_position)
			}
			if collision_shape.shape is RectangleShape2D:
				shape_evidence["size"] = _vector_data((collision_shape.shape as RectangleShape2D).size)
			elif collision_shape.shape is CapsuleShape2D:
				var capsule := collision_shape.shape as CapsuleShape2D
				shape_evidence["radius"] = capsule.radius
				shape_evidence["height"] = capsule.height
			shapes.append(shape_evidence)
		elif child is CollisionPolygon2D:
			var collision_polygon := child as CollisionPolygon2D
			shapes.append({
				"node_name": _node_name(collision_polygon),
				"shape_class": "CollisionPolygon2D",
				"world_position": _vector_data(collision_polygon.global_position),
				"point_count": collision_polygon.polygon.size()
			})
	evidence["collision_shapes"] = shapes
	return evidence


func _capture_waypoint_failure_screenshot() -> Dictionary:
	return await _capture_viewport_screenshot("chapter2-return-waypoint-failure.png")


func _capture_viewport_screenshot(file_name: String) -> Dictionary:
	if not _isolation_validated or not _is_path_within(_isolated_root, OS.get_environment("TEMP")):
		return {"saved": false, "reason": "isolated Temp output path was not validated"}
	var screenshot_path := _isolated_root.path_join(file_name)
	if FileAccess.file_exists(screenshot_path):
		return {"saved": false, "reason": "screenshot path already exists", "path": screenshot_path}
	await get_tree().process_frame
	var screenshot := get_viewport().get_texture().get_image()
	var save_error := screenshot.save_png(screenshot_path)
	return {
		"saved": save_error == OK,
		"path": screenshot_path,
		"width": screenshot.get_width(),
		"height": screenshot.get_height(),
		"error": save_error
	}


func _authored_channel_waypoints(scene: Node, action_id: String) -> Dictionary:
	var route_data: Dictionary = scene.get("route_data") if is_instance_valid(scene) else {}
	var paths: Array = route_data.get("exploration_paths", [])
	var normalized_waypoints: Array = []
	if action_id == UPPER_SAMPLE_ACTION_ID and paths.size() > 0 and paths[0] is Array and paths[0].size() >= 3:
		var approach_path: Array = paths[0]
		normalized_waypoints = [approach_path[1]]
	elif action_id == RETURN_SAMPLE_ACTION_ID and paths.size() > 4 and paths[1] is Array and paths[1].size() >= 3 and paths[4] is Array and paths[4].size() >= 3:
		var west_path: Array = paths[1]
		var west_exit_path: Array = paths[4]
		normalized_waypoints = [west_path[1], west_path[2], west_exit_path[1], west_exit_path[2]]
	if normalized_waypoints.is_empty():
		return {"normalized": [], "world": [], "world_arrays": []}
	var map_size: Vector2 = scene.get_meta("map_world_size", Vector2(1664.0, 1088.0))
	var waypoints_world: Array[Vector2] = []
	var world_arrays: Array = []
	for raw_point: Variant in normalized_waypoints:
		if raw_point is Array and raw_point.size() == 2:
			var waypoint := Vector2(float(raw_point[0]) * map_size.x, float(raw_point[1]) * map_size.y)
			waypoints_world.append(waypoint)
			world_arrays.append(_vector_data(waypoint))
	return {"normalized": normalized_waypoints, "world": waypoints_world, "world_arrays": world_arrays}


func _prepare_channel_hold(player: Node2D, action: Node2D, action_id: String) -> Dictionary:
	if not is_instance_valid(player) or not is_instance_valid(action):
		return {"safe_to_hold": false, "reason": "player or action node missing"}
	var radius := _channel_radius(action)
	var desired_distance := minf(56.0, radius * 0.5)
	var distance_before := player.global_position.distance_to(action.global_position)
	var direction_away := player.global_position - action.global_position
	if direction_away.length_squared() < 0.01:
		direction_away = Vector2.RIGHT
	var staging_position := action.global_position + direction_away.normalized() * desired_distance
	var stage_move_attempted := distance_before > radius - 28.0
	var stage_move_succeeded := true
	if stage_move_attempted:
		var stage_timeout := clampi(roundi(player.global_position.distance_to(staging_position) / 188.0 * 1500.0 + 1000.0), 3000, 10000)
		stage_move_succeeded = await _walk_to_position(player, staging_position, stage_timeout, true)
	_set_movement_keys([])
	var settle_started := Time.get_ticks_msec()
	var stable_frames := 0
	while Time.get_ticks_msec() - settle_started < 1000:
		await get_tree().physics_frame
		await get_tree().process_frame
		var speed := (player as CharacterBody2D).velocity.length() if player is CharacterBody2D else 0.0
		stable_frames = stable_frames + 1 if speed <= 5.0 else 0
		var distance := player.global_position.distance_to(action.global_position)
		if stable_frames >= 2 and distance <= radius - 20.0 and _target_is_selected(player, action):
			break
	var final_distance := player.global_position.distance_to(action.global_position)
	var final_speed := (player as CharacterBody2D).velocity.length() if player is CharacterBody2D else 0.0
	var selected := _target_is_selected(player, action)
	return {
		"action_id": action_id,
		"radius": radius,
		"distance_before_staging": distance_before,
		"staging_position_world": _vector_data(staging_position),
		"stage_move_attempted": stage_move_attempted,
		"stage_move_succeeded": stage_move_succeeded,
		"player_world_position": _vector_data(player.global_position),
		"distance_after_settle": final_distance,
		"range_margin_after_settle": radius - final_distance,
		"player_speed_after_settle": final_speed,
		"settle_elapsed_ms": Time.get_ticks_msec() - settle_started,
		"stable_frames": stable_frames,
		"nearest_interaction_target": _node_name(player.call("get_nearest_interaction_target")),
		"action_can_interact": bool(action.call("can_interact")),
		"action_status": GameState.campaign_action_status(action_id),
		"safe_to_hold": selected and final_distance <= radius - 20.0 and final_speed <= 5.0
	}


func _channel_radius(action: Node2D) -> float:
	var radius_value: Variant = action.get("_radius")
	if typeof(radius_value) in [TYPE_INT, TYPE_FLOAT]:
		return float(radius_value)
	var action_data: Variant = action.get("action_data")
	if action_data is Dictionary:
		return float(action_data.get("radius", 112.0))
	return 112.0


func _channel_action_snapshot(player: Node2D, action: Node2D, action_id: String) -> Dictionary:
	var player_valid := is_instance_valid(player)
	var action_valid := is_instance_valid(action)
	var radius := _channel_radius(action) if action_valid else 112.0
	var distance := player.global_position.distance_to(action.global_position) if player_valid and action_valid else -1.0
	var runtime: Dictionary = GameState.campaign_action_progress(action_id)
	var snapshot := {
		"ticks_msec": Time.get_ticks_msec(),
		"action_id": action_id,
		"action_status": GameState.campaign_action_status(action_id),
		"campaign_runtime": runtime,
		"interact_action_pressed": Input.is_action_pressed("interact"),
		"player_valid": player_valid,
		"player_world_position": _vector_data(player.global_position) if player_valid else [],
		"player_speed": (player as CharacterBody2D).velocity.length() if player_valid and player is CharacterBody2D else 0.0,
		"action_valid": action_valid,
		"action_world_position": _vector_data(action.global_position) if action_valid else [],
		"channel_radius": radius,
		"distance_to_action": distance,
		"inside_channel_radius": distance >= 0.0 and distance <= radius,
		"nearest_interaction_target": _node_name(player.call("get_nearest_interaction_target")) if player_valid else "no player",
		"action_can_interact": bool(action.call("can_interact")) if action_valid and action.has_method("can_interact") else false
	}
	if player_valid and player is CharacterBody2D:
		var body := player as CharacterBody2D
		snapshot["player_position_delta"] = _vector_data(body.get_position_delta())
		snapshot["player_slide_collisions"] = _slide_collision_evidence(body)
		snapshot["movement_actions_pressed"] = {
			"move_left": Input.is_action_pressed("move_left"),
			"move_right": Input.is_action_pressed("move_right"),
			"move_up": Input.is_action_pressed("move_up"),
			"move_down": Input.is_action_pressed("move_down")
		}
		snapshot["physical_movement_keys_pressed"] = {
			"A": Input.is_key_pressed(KEY_A),
			"W": Input.is_key_pressed(KEY_W),
			"S": Input.is_key_pressed(KEY_S),
			"D": Input.is_key_pressed(KEY_D)
		}
		snapshot["player_state"] = body.get("state")
		snapshot["game_state_hp"] = GameState.hp
		snapshot["nearby_enemy_motion"] = _channel_enemy_motion_evidence(player.global_position, 400.0)
	if action_valid and action.has_method("presentation_state"):
		snapshot["visible_action_progress"] = action.call("presentation_state")
	return snapshot


func _channel_enemy_motion_evidence(center: Vector2, radius: float) -> Array[Dictionary]:
	var enemies: Array[Dictionary] = []
	for raw_enemy: Variant in get_tree().get_nodes_in_group("enemy"):
		var enemy := raw_enemy as Node2D
		if not is_instance_valid(enemy):
			continue
		var distance := center.distance_to(enemy.global_position)
		if distance > radius:
			continue
		var evidence := {
			"enemy_id": String(enemy.get("enemy_id")),
			"hp": int(enemy.get("hp")),
			"distance": distance,
			"position": _vector_data(enemy.global_position),
			"velocity": _vector_data((enemy as CharacterBody2D).velocity) if enemy is CharacterBody2D else [],
			"is_dead": bool(enemy.get("is_dead")),
			"pending_attack": String(enemy.get("pending_attack")),
			"target_is_player": enemy.get("target") == _find_player(get_tree().current_scene)
		}
		enemies.append(evidence)
	enemies.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return float(left["distance"]) < float(right["distance"]))
	return enemies


func _hold_channel_action(player: Node2D, action: Node2D, action_id: String, duration: float) -> Dictionary:
	var hold_ms := roundi(duration * 1000.0) + 500
	var input_event_start := _input_events.size()
	var started := Time.get_ticks_msec()
	var next_sample_msec := started
	var samples: Array[Dictionary] = []
	_send_key(KEY_E, true, "Hold E: " + action_id)
	var press_event: Dictionary = _input_events[input_event_start].duplicate(true) if _input_events.size() > input_event_start else {}
	while Time.get_ticks_msec() - started < hold_ms:
		await get_tree().process_frame
		if Time.get_ticks_msec() >= next_sample_msec:
			samples.append(_channel_action_snapshot(player, action, action_id))
			next_sample_msec = Time.get_ticks_msec() + 250
	_send_key(KEY_E, false, "Hold E: " + action_id)
	await get_tree().physics_frame
	await get_tree().process_frame
	var released := Time.get_ticks_msec()
	var release_event: Dictionary = _input_events[_input_events.size() - 1].duplicate(true) if _input_events.size() > input_event_start else {}
	var after_release := _channel_action_snapshot(player, action, action_id)
	var max_elapsed := 0.0
	var started_samples := 0
	var held_samples := 0
	var in_range_samples := 0
	var movement_events_during_hold: Array[Dictionary] = []
	for event_index in range(input_event_start, _input_events.size()):
		var event: Dictionary = _input_events[event_index]
		if int(event.get("physical_keycode", -1)) in [KEY_A, KEY_W, KEY_S, KEY_D]:
			movement_events_during_hold.append(event.duplicate(true))
	for sample: Dictionary in samples:
		var runtime: Dictionary = sample.get("campaign_runtime", {})
		if bool(runtime.get("started", false)):
			started_samples += 1
			max_elapsed = maxf(max_elapsed, float(runtime.get("elapsed", 0.0)))
		if bool(sample.get("interact_action_pressed", false)):
			held_samples += 1
		if bool(sample.get("inside_channel_radius", false)):
			in_range_samples += 1
	var press_valid := int(press_event.get("physical_keycode", -1)) == KEY_E and bool(press_event.get("pressed", false))
	var release_valid := int(release_event.get("physical_keycode", -1)) == KEY_E and not bool(release_event.get("pressed", true))
	return {
		"requested_minimum_hold_ms": roundi(duration * 1000.0),
		"planned_hold_ms": hold_ms,
		"elapsed_ms": released - started,
		"input_event_count_delta": _input_events.size() - input_event_start,
		"movement_input_events_during_hold": movement_events_during_hold,
		"press_event": press_event,
		"release_event": release_event,
		"e_key_press_and_release_valid": press_valid and release_valid,
		"sample_count": samples.size(),
		"samples": samples,
		"progress_started_sample_count": started_samples,
		"maximum_observed_elapsed_seconds": max_elapsed,
		"held_input_sample_count": held_samples,
		"in_range_sample_count": in_range_samples,
		"held_input_samples_valid": not samples.is_empty() and held_samples == samples.size(),
		"inside_channel_radius_for_all_samples": not samples.is_empty() and in_range_samples == samples.size(),
		"after_release": after_release
	}


func _channel_movement_evidence(player: Node2D, action: Node2D, started_msec: int, input_count_before: int) -> Dictionary:
	var evidence := {
		"elapsed_ms": Time.get_ticks_msec() - started_msec,
		"input_event_count_before": input_count_before,
		"input_event_count_after": _input_events.size(),
		"input_event_count_delta": _input_events.size() - input_count_before,
		"player_world_position": _vector_data(player.global_position) if is_instance_valid(player) else [],
		"action_world_position": _vector_data(action.global_position) if is_instance_valid(action) else [],
		"nearest_interaction_target": _node_name(player.call("get_nearest_interaction_target")) if is_instance_valid(player) else "no player",
		"distance_to_action": player.global_position.distance_to(action.global_position) if is_instance_valid(player) and is_instance_valid(action) else -1.0,
		"action_status": GameState.campaign_action_status(str(action.get("interaction_id"))) if is_instance_valid(action) else "missing action"
	}
	if not is_instance_valid(player) or not is_instance_valid(action):
		return evidence
	evidence["player_screen_position"] = _vector_data(get_viewport().get_canvas_transform() * player.global_position)
	evidence["action_screen_position"] = _vector_data(get_viewport().get_canvas_transform() * action.global_position)
	if player is CharacterBody2D:
		evidence["player_velocity"] = _vector_data((player as CharacterBody2D).velocity)
	var query := PhysicsRayQueryParameters2D.create(player.global_position, action.global_position, 0x7fffffff, [player.get_rid()])
	query.collide_with_areas = false
	var collision: Dictionary = player.get_world_2d().direct_space_state.intersect_ray(query)
	if not collision.is_empty():
		var collider := collision.get("collider") as Node
		evidence["direct_route_collision"] = {
			"collider": _node_name(collider),
			"collider_class": collider.get_class() if is_instance_valid(collider) else "unknown",
			"position": _vector_data(collision.get("position", Vector2.ZERO)),
			"normal": _vector_data(collision.get("normal", Vector2.ZERO)),
			"collider_details": _collision_node_evidence(collider)
		}
	else:
		evidence["direct_route_collision"] = "no body hit on center-to-center ray"
	return evidence


func _extract_to_village(scene: Node, stage: String, transition_count: int) -> bool:
	var player := _find_player(scene)
	var exit := _find_interactable(scene, "to_village")
	var initial_player_position := _vector_data(player.global_position) if is_instance_valid(player) else []
	var second_outing := String(GameState.campaign_outing().get("id", "")) == CHAPTER2_SECOND_OUTING_ID
	var direct_route_geometry: Dictionary = _gate_route_collision_evidence(player, exit) if second_outing and is_instance_valid(player) and is_instance_valid(exit) else {}
	var direct_attempted := is_instance_valid(player) and is_instance_valid(exit) and not second_outing
	var reached := direct_attempted and await _walk_until_interactable(player, exit, 30000, true)
	var observed := {
		"player": _node_name(player),
		"gate": _node_name(exit),
		"initial_player_world_position": initial_player_position,
		"gate_world_position": _vector_data(exit.global_position) if is_instance_valid(exit) else [],
		"direct_route_attempted": direct_attempted,
		"direct_route_geometry_before_traversal": direct_route_geometry
	}
	if second_outing:
		observed["authored_route_start_viewport"] = await _capture_viewport_screenshot("chapter2-second-outing-gate-route-start.png")
	if not reached and is_instance_valid(player) and is_instance_valid(exit) and str(scene.get("route_id")) == "toxic_marsh":
		if direct_route_geometry.is_empty():
			direct_route_geometry = _gate_route_collision_evidence(player, exit)
		var route_data: Dictionary = scene.get("route_data")
		var paths: Array = route_data.get("exploration_paths", [])
		var return_gate_position: Variant = route_data.get("return_gate_position", [])
		var normalized_waypoints: Array = []
		var route_mode := "authored_west_return_corridor"
		if second_outing and paths.size() > 3 and paths[2] is Array and paths[2].size() >= 4 and paths[3] is Array and paths[3].size() >= 4 and return_gate_position is Array and return_gate_position.size() == 2:
			var east_approach_path: Array = paths[2]
			var east_return_path: Array = paths[3]
			normalized_waypoints = [east_approach_path[0], east_approach_path[1], east_approach_path[2], east_approach_path[3], east_return_path[1], east_return_path[2], return_gate_position]
			route_mode = "authored_east_return_corridor"
		elif paths.size() > 4 and paths[0] is Array and paths[0].size() >= 3 and paths[1] is Array and paths[1].size() >= 3 and paths[4] is Array and paths[4].size() >= 3 and return_gate_position is Array and return_gate_position.size() == 2:
			var approach_path: Array = paths[0]
			var west_path: Array = paths[1]
			var exit_path: Array = paths[4]
			normalized_waypoints = [approach_path[approach_path.size() - 1], approach_path[approach_path.size() - 2], west_path[1], west_path[2], exit_path[1], exit_path[2], return_gate_position]
		var map_size: Vector2 = scene.get_meta("map_world_size", Vector2(1664.0, 1088.0))
		var waypoints_world: Array[Vector2] = []
		for raw_point: Variant in normalized_waypoints:
			if raw_point is Array and raw_point.size() == 2:
				waypoints_world.append(Vector2(float(raw_point[0]) * map_size.x, float(raw_point[1]) * map_size.y))
		var waypoints_world_evidence: Array = []
		for waypoint: Vector2 in waypoints_world:
			waypoints_world_evidence.append(_vector_data(waypoint))
		var reached_waypoint_count := 0
		var failed_waypoint: Array = []
		var waypoint_navigation: Array[Dictionary] = []
		var route_started := Time.get_ticks_msec()
		var route_timeout := 75000 if second_outing else 60000
		for waypoint: Vector2 in waypoints_world:
			var remaining := maxi(0, route_timeout - (Time.get_ticks_msec() - route_started))
			if remaining <= 0:
				failed_waypoint = _vector_data(waypoint)
				waypoint_navigation.append(_waypoint_navigation_evidence(player, waypoint, false, "return_route_timeout_before_attempt"))
				break
			var waypoint_reached := true
			if player.global_position.distance_to(waypoint) > 32.0:
				var distance := player.global_position.distance_to(waypoint)
				var waypoint_timeout := mini(remaining, clampi(roundi(distance / 188.0 * 1500.0 + 7000.0), 4000, 18000))
				waypoint_reached = await _walk_to_position(player, waypoint, waypoint_timeout, true)
				var waypoint_evidence := _waypoint_navigation_evidence(player, waypoint, waypoint_reached, "physical_return_corridor")
				if not waypoint_reached:
					failed_waypoint = _vector_data(waypoint)
					waypoint_evidence["viewport_capture"] = await _capture_viewport_screenshot("chapter2-return-gate-waypoint-failure.png")
					waypoint_navigation.append(waypoint_evidence)
					break
				waypoint_navigation.append(waypoint_evidence)
			else:
				waypoint_navigation.append(_waypoint_navigation_evidence(player, waypoint, true, "already_within_waypoint_tolerance"))
			reached_waypoint_count += 1
		var remaining_for_gate := maxi(0, route_timeout - (Time.get_ticks_msec() - route_started))
		reached = reached_waypoint_count == waypoints_world.size() and not waypoints_world.is_empty() and remaining_for_gate > 0 and await _walk_until_interactable(player, exit, mini(12000, remaining_for_gate), true)
		observed["direct_route_geometry"] = direct_route_geometry
		observed["return_corridor_mode"] = route_mode
		observed["return_corridor_normalized_waypoints"] = normalized_waypoints
		observed["return_corridor_world_waypoints"] = waypoints_world_evidence
		observed["return_corridor_waypoints_reached"] = reached_waypoint_count
		observed["return_corridor_failed_waypoint"] = failed_waypoint
		observed["return_corridor_waypoint_navigation"] = waypoint_navigation
		observed["return_corridor_elapsed_ms"] = Time.get_ticks_msec() - route_started
		observed["retry_selected_gate"] = reached
		observed["retry_final_player_world_position"] = _vector_data(player.global_position)
		observed["retry_final_nearest_interaction_target"] = _node_name(player.call("get_nearest_interaction_target"))
	_record_check(stage + "_reach_physical_extraction_gate", reached, "player selects the real to_village gate", observed)
	if not reached:
		return false
	await _tap_key(KEY_E, "E: physically extract " + stage)
	var extracted := await _wait_for_scene(VILLAGE_SCENE_PATH, "village", transition_count)
	_record_check(stage + "_E_triggers_SceneRouter_extraction", extracted, "new Village scene after SceneRouter extraction", _current_scene_evidence())
	return extracted


func _gate_route_collision_evidence(player: Node2D, exit: Node2D) -> Dictionary:
	if not is_instance_valid(player) or not is_instance_valid(exit):
		return {"available": false, "reason": "player or extraction gate is missing"}
	var result: Dictionary = {
		"available": true,
		"player_world_position": _vector_data(player.global_position),
		"gate_world_position": _vector_data(exit.global_position)
	}
	var player_body := player as CollisionObject2D
	if player_body == null:
		result["center_ray"] = "player is not a CollisionObject2D"
		return result
	var query := PhysicsRayQueryParameters2D.create(player.global_position, exit.global_position, 0x7fffffff, [player_body.get_rid()])
	query.collide_with_areas = false
	var hit: Dictionary = player.get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		result["center_ray"] = "no body hit on player-to-gate center ray"
	else:
		var collider := hit.get("collider") as Node
		result["center_ray"] = {
			"hit_position": _vector_data(hit.get("position", Vector2.ZERO)),
			"normal": _vector_data(hit.get("normal", Vector2.ZERO)),
			"collider": _collision_node_evidence(collider)
		}
	if player is CharacterBody2D:
		result["player_capsule_sweep"] = _body_sweep_evidence(player as CharacterBody2D, exit.global_position)
	result["blocking_props_near_direct_route"] = _blocking_props_near_route(player.get_tree().current_scene, player.global_position, exit.global_position, 160.0)
	return result


func _blocking_props_near_route(scene: Node, start: Vector2, finish: Vector2, max_distance: float) -> Array[Dictionary]:
	var props: Array[Dictionary] = []
	var segment := finish - start
	var length_squared := segment.length_squared()
	for raw_prop: Node in get_tree().get_nodes_in_group("world_prop"):
		if not is_instance_valid(raw_prop) or not scene.is_ancestor_of(raw_prop) or not raw_prop is Node2D:
			continue
		var blocking_value: Variant = raw_prop.get("blocks_movement")
		if blocking_value == null or not bool(blocking_value):
			continue
		var prop := raw_prop as Node2D
		var progress := clampf((prop.global_position - start).dot(segment) / length_squared, 0.0, 1.0) if length_squared > 0.0 else 0.0
		var route_point := start + segment * progress
		var distance := prop.global_position.distance_to(route_point)
		if distance > max_distance:
			continue
		var prop_evidence := _collision_node_evidence(prop)
		prop_evidence["distance_to_direct_route"] = distance
		prop_evidence["closest_route_point"] = _vector_data(route_point)
		if prop.has_method("get_collision_bounds"):
			var bounds: Rect2 = prop.call("get_collision_bounds")
			prop_evidence["collision_bounds"] = [_vector_data(bounds.position), _vector_data(bounds.size)]
		props.append(prop_evidence)
	props.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return float(left["distance_to_direct_route"]) < float(right["distance_to_direct_route"]))
	if props.size() > 12:
		props.resize(12)
	return props


func _milestone(name: String, passed: bool, expected: Variant, observed: Variant) -> void:
	_chapter2_milestones[name] = passed
	_record_check(name, passed, expected, observed)


func _finish_chapter2() -> void:
	if _finished:
		return
	_finished = true
	_release_all_keys()
	var unverified_branches: Array[String] = []
	if not bool(_chapter2_milestones.get("undiscovered_optional_ledger_does_not_block_ready_contract", false)):
		unverified_branches.append("required quest objectives and optional ledger readiness")
	if not bool(_chapter2_handin_evidence.get("guild_j", {}).get("optional_ledger_copy_visible", false)) or not bool(_chapter2_milestones.get("guild_handin", false)):
		unverified_branches.append("Guild J details and physical reward-counter hand-in")
	if not bool(_chapter2_handin_evidence.get("save_manager_reload", {}).get("load_succeeded", false)) or not bool(_chapter2_milestones.get("duplicate_delivery_guard", false)):
		unverified_branches.append("SaveManager reload and duplicate reward guard")
	var report := {
		"schema_version": 1,
		"runner": "chapter2_two_outing_authentic_input_journey",
		"result": "PASS" if _failures.is_empty() else "FAIL",
		"engine": Engine.get_version_info(),
		"started_unix": _started_unix,
		"run_id": _run_id,
		"source_project_root": _source_project_root,
		"source_tree_sha256": _source_tree_sha256,
		"chapter2_driver_sha256": FileAccess.get_file_as_string("res://scripts/tests/Chapter2JourneyDriver.gd").sha256_text(),
		"temp_mirror_project_root": ProjectSettings.globalize_path("res://"),
		"report_path": _report_path,
		"isolation_root": _isolated_root,
		"isolated_save_path": ProjectSettings.globalize_path("user://save_game.json"),
		"isolated_save_exists": FileAccess.file_exists("user://save_game.json") if _isolation_validated else false,
		"checks": _checks,
		"failures": _failures,
		"milestones": _chapter2_milestones,
		"input_event_count": _input_events.size(),
		"movement_input_events": _movement_input_evidence(),
		"space_attack_input_events": _space_attack_input_evidence(),
		"combat_attack_count": _combat_attack_count,
		"combat_responses": _combat_responses,
		"transition_events": _transition_events,
		"terminal_state": {
			"scene": _current_scene_evidence(),
			"active_quest_id": GameState.active_quest_id,
			"completed_quests": GameState.completed_quests.duplicate(),
			"inventory": GameState.inventory.duplicate(true),
			"level": GameState.level,
			"xp": GameState.xp,
			"quest_progress": GameState.quest_progress.duplicate(true),
			"defeated_enemies": GameState.defeated_enemies,
			"discovered_events": GameState.discovered_events.duplicate(true),
			"campaign": GameState.quest_progress.get("campaign", {}).duplicate(true)
		},
		"chapter2_handin": _chapter2_handin_evidence,
		"unverified_branches": unverified_branches
	}
	print("[CHAPTER2_JOURNEY][%s] checks=%d failures=%s" % [report.result, _checks.size(), JSON.stringify(_failures)])
	if _isolation_validated and _is_path_within(_report_path, _isolated_root):
		var file := FileAccess.open(_report_path, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report, "\t"))
			file.close()
		else:
			push_error("Could not write isolated Chapter 2 journey report: " + _report_path)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _space_attack_input_evidence() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for event: Dictionary in _input_events:
		if int(event.get("physical_keycode", -1)) == KEY_SPACE:
			events.append(event.duplicate(true))
	return events


func _movement_input_evidence() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for event: Dictionary in _input_events:
		if int(event.get("physical_keycode", -1)) in [KEY_A, KEY_W, KEY_S, KEY_D]:
			events.append(event.duplicate(true))
	return events
