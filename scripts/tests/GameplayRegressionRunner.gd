extends Node

const WASTELAND_SCENE := preload("res://scenes/levels/wasteland/Wasteland.tscn")
const DEFAULT_TEST_SAVE_PATH := "user://qa/gameplay_regression_save.json"
const REPORT_FILENAME := "GameplayRegressionRunner.json"

var checks: Array[Dictionary] = []
var failures: Array[String] = []
var test_save_path := DEFAULT_TEST_SAVE_PATH
var report_directory := ""
var death_transition_received := false
var paused_death_transition_received := false
var title_return_scene_received := false
var unexpected_title_return_recovery_received := false
var runner_finished := false
var death_timeout: Timer
var result_exit_code := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_parse_user_arguments()
	SaveManager.default_save_path = test_save_path
	DataRegistry.load_all()
	await get_tree().process_frame
	_run_quest_regressions()
	_run_full_contract_progression_cycle()
	_run_save_validation_regressions()
	await _run_position_restore_regression()
	_run_route_scoped_event_save_regression()
	_run_death_save_boundary_regressions()
	await _run_pending_death_cancellation_regressions()
	_run_death_recovery_regression()

func _parse_user_arguments() -> void:
	var arguments := OS.get_cmdline_user_args()
	var index := 0
	while index < arguments.size():
		var argument := String(arguments[index])
		if argument in ["--qa-save-path", "--qa-output"] and index + 1 < arguments.size():
			var value := String(arguments[index + 1])
			if argument == "--qa-save-path":
				test_save_path = value
			else:
				report_directory = value
			index += 2
		else:
			index += 1

func _run_quest_regressions() -> void:
	GameState.reset_new_run(false)
	GameState.current_scene_id = "wasteland"
	GameState.current_route_id = "scrap_highway"
	GameState.quest_progress = {"defeat_enemy": 3}
	var accepted := GameState.start_quest("clear_scrap_route")
	_expect(accepted, "quest acceptance succeeds")
	_expect(int(GameState.quest_progress.get("defeat_enemy", -1)) == 0, "acceptance resets existing objective counters")
	GameState.advance_quest_counter("defeat_enemy", 1)
	var progress_before_replacement := int(GameState.quest_progress.get("defeat_enemy", 0))
	var replacement_accepted := GameState.start_quest("toxic_sample")
	_expect(not replacement_accepted and GameState.active_quest_id == "clear_scrap_route", "active quest cannot be replaced")
	_expect(int(GameState.quest_progress.get("defeat_enemy", 0)) == progress_before_replacement, "rejected replacement preserves active quest progress")

	GameState.current_route_id = "toxic_marsh"
	var count_before_wrong_route := int(GameState.quest_progress.get("defeat_enemy", 0))
	GameState.record_enemy_defeated()
	_expect(int(GameState.quest_progress.get("defeat_enemy", 0)) == count_before_wrong_route, "kill on another route does not progress the quest")
	GameState.current_route_id = "scrap_highway"
	for _index in range(4):
		GameState.record_enemy_defeated()
	_expect(int(GameState.quest_progress.get("defeat_enemy", 0)) == 5, "kill on the quest route advances its counter")
	GameState.add_item("scrap", 12)
	_expect(GameState.is_active_quest_ready(), "quest objectives become ready after route kills and collection")
	var completed := GameState.complete_active_quest()
	var reward_after_first_completion := GameState.inventory.duplicate(true)
	var xp_after_first_completion := GameState.xp
	var duplicate_completion := GameState.complete_active_quest()
	_expect(completed, "ready quest completes")
	_expect(not duplicate_completion, "duplicate quest completion is rejected")
	_expect(GameState.inventory == reward_after_first_completion and GameState.xp == xp_after_first_completion, "duplicate completion does not grant rewards twice")
	_expect(GameState.quest_progress.is_empty(), "quest completion clears objective counters")

	GameState.current_scene_id = "wasteland"
	GameState.current_route_id = "scrap_highway"
	var second_accepted := GameState.start_quest("toxic_sample")
	_expect(second_accepted and int(GameState.quest_progress.get("defeat_enemy", 0)) == 0, "next quest starts with clean counters")
	GameState.reset_new_run(false)
	GameState.current_scene_id = "wasteland"
	var factory_accepted := GameState.start_quest("old_factory_core")
	GameState.record_enemy_defeated(false)
	_expect(factory_accepted and int(GameState.quest_progress.get("defeat_boss", 0)) == 0, "ordinary kill does not satisfy the factory boss objective")
	GameState.record_enemy_defeated(true)
	_expect(int(GameState.quest_progress.get("defeat_boss", 0)) == 1, "boss kill advances the factory boss objective")
	var boss_count_before_wrong_route := int(GameState.quest_progress.get("defeat_boss", 0))
	GameState.current_route_id = "scrap_highway"
	GameState.record_enemy_defeated(true)
	_expect(int(GameState.quest_progress.get("defeat_boss", 0)) == boss_count_before_wrong_route, "boss on another route does not progress the factory quest")

func _run_full_contract_progression_cycle() -> void:
	GameState.reset_new_run(false)
	var quest_ids := DataRegistry.quest_ids()
	_expect(quest_ids.size() == 6, "the regression data contains all six guild contracts")
	for quest_id in quest_ids:
		GameState.current_scene_id = "guild"
		var accepted := GameState.start_quest(quest_id)
		var quest := DataRegistry.get_quest(quest_id)
		GameState.current_scene_id = "wasteland"
		var enemy_target := 0
		var boss_target := 0
		for objective in quest.get("objectives", []):
			if String(objective.get("type", "")) == "defeat":
				var counter := String(objective.get("counter", "defeat_enemy"))
				if counter == "defeat_boss":
					boss_target = max(boss_target, int(objective.get("amount", 0)))
				else:
					enemy_target = max(enemy_target, int(objective.get("amount", 0)))
			elif String(objective.get("type", "")) == "collect":
				var item_id := String(objective.get("item", ""))
				var needed := int(objective.get("amount", 0)) - int(GameState.inventory.get(item_id, 0))
				if needed > 0:
					GameState.add_item(item_id, needed)
		for _index in range(boss_target):
			GameState.record_enemy_defeated(true)
		for _index in range(max(0, enemy_target - boss_target)):
			GameState.record_enemy_defeated(false)
		_expect(accepted, "contract accepted in sequence: " + quest_id)
		_expect(GameState.is_active_quest_ready(), "contract objectives complete in sequence: " + quest_id)
		var completed := GameState.complete_active_quest()
		_expect(completed and GameState.completed_quests.has(quest_id), "contract reward delivered in sequence: " + quest_id)
	GameState.reset_new_run(false)

func _run_save_validation_regressions() -> void:
	_seed_sentinel_state()
	var saved := SaveManager.save_game(false, test_save_path)
	_expect(saved, "manual save writes to the isolated test path")
	var valid_wrapper_text := _read_text(test_save_path)
	var valid_wrapper = JSON.parse_string(valid_wrapper_text)
	var valid_payload := _decode_wrapper(valid_wrapper)
	_expect(String(valid_payload.get("spawn_point", "")) == "saved", "manual save stores the saved-position spawn mode")

	if typeof(valid_wrapper) == TYPE_DICTIONARY:
		var tampered_wrapper: Dictionary = valid_wrapper.duplicate(true)
		var original_checksum := String(tampered_wrapper.get("checksum", ""))
		var replacement_character := "0" if original_checksum.substr(0, 1) != "0" else "1"
		tampered_wrapper["checksum"] = replacement_character + original_checksum.substr(1)
		_write_text(test_save_path, JSON.stringify(tampered_wrapper, "\t"))
		_seed_sentinel_state()
		var state_before_tampered_load := GameState.get_save_data().duplicate(true)
		var tampered_loaded := SaveManager.load_game(false, false, test_save_path)
		_expect(not tampered_loaded, "tampered checksum is rejected")
		_expect(GameState.get_save_data() == state_before_tampered_load, "tampered save leaves game state unchanged")
		_write_text(test_save_path, valid_wrapper_text)

	_write_text(test_save_path, "{ malformed json")
	_seed_sentinel_state()
	var state_before_bad_wrapper := GameState.get_save_data().duplicate(true)
	var malformed_wrapper_loaded := SaveManager.load_game(false, false, test_save_path)
	_expect(not malformed_wrapper_loaded, "malformed outer JSON wrapper is rejected")
	_expect(GameState.get_save_data() == state_before_bad_wrapper, "malformed wrapper leaves game state unchanged")
	var bad_base64_wrapper := {"checksum": "0".repeat(64), "payload": "not base64!"}
	_write_text(test_save_path, JSON.stringify(bad_base64_wrapper))
	var bad_base64_loaded := SaveManager.load_game(false, false, test_save_path)
	_expect(not bad_base64_loaded and GameState.get_save_data() == state_before_bad_wrapper, "malformed base64 is rejected without mutation")
	var bad_json_payload := "not JSON"
	var checksummed_bad_json := {
		"checksum": bad_json_payload.sha256_text(),
		"payload": Marshalls.utf8_to_base64(bad_json_payload)
	}
	_write_text(test_save_path, JSON.stringify(checksummed_bad_json))
	var bad_json_loaded := SaveManager.load_game(false, false, test_save_path)
	_expect(not bad_json_loaded and GameState.get_save_data() == state_before_bad_wrapper, "valid checksum cannot bypass payload JSON validation")
	_write_text(test_save_path, valid_wrapper_text)

	var malformed_payload: Dictionary = GameState.get_save_data()
	malformed_payload["scene"] = "unknown_scene"
	var malformed_written := _write_wrapped_data(malformed_payload, test_save_path)
	_seed_sentinel_state()
	var state_before_malformed_load := GameState.get_save_data().duplicate(true)
	var malformed_loaded := SaveManager.load_game(false, false, test_save_path)
	_expect(malformed_written and not malformed_loaded, "valid checksum cannot bypass scene enum validation")
	_expect(GameState.get_save_data() == state_before_malformed_load, "invalid schema causes no partial state mutation")

	var unknown_id_payload: Dictionary = GameState.get_save_data().duplicate(true)
	unknown_id_payload["inventory"]["missing_item"] = 1
	var unknown_id_written := _write_wrapped_data(unknown_id_payload, test_save_path)
	var unknown_id_loaded := SaveManager.load_game(false, false, test_save_path)
	_expect(unknown_id_written and not unknown_id_loaded, "unknown inventory item id is rejected")
	_expect(GameState.get_save_data() == state_before_malformed_load, "unknown item id cannot partially mutate game state")

	var invalid_type_payload: Dictionary = GameState.get_save_data().duplicate(true)
	invalid_type_payload["inventory"]["scrap"] = "many"
	var invalid_type_written := _write_wrapped_data(invalid_type_payload, test_save_path)
	var invalid_type_loaded := SaveManager.load_game(false, false, test_save_path)
	_expect(invalid_type_written and not invalid_type_loaded, "invalid inventory quantity type is rejected")
	_expect(GameState.get_save_data() == state_before_malformed_load, "invalid inventory quantity cannot partially mutate game state")

	var invalid_equipment_payload: Dictionary = GameState.get_save_data().duplicate(true)
	invalid_equipment_payload["equipment"]["weapon"] = "missing_weapon"
	var invalid_equipment_written := _write_wrapped_data(invalid_equipment_payload, test_save_path)
	var invalid_equipment_loaded := SaveManager.load_game(false, false, test_save_path)
	_expect(invalid_equipment_written and not invalid_equipment_loaded, "unknown equipped item id is rejected")
	_expect(GameState.get_save_data() == state_before_malformed_load, "unknown equipped item cannot partially mutate game state")

	var unowned_equipment_payload: Dictionary = GameState.get_save_data().duplicate(true)
	unowned_equipment_payload["inventory"].erase("rust_blade")
	var unowned_equipment_written := _write_wrapped_data(unowned_equipment_payload, test_save_path)
	var unowned_equipment_loaded := SaveManager.load_game(false, false, test_save_path)
	_expect(unowned_equipment_written and not unowned_equipment_loaded, "equipped item must be owned in the saved inventory")
	_expect(GameState.get_save_data() == state_before_malformed_load, "unowned equipment cannot partially mutate game state")

	var invalid_version_payload: Dictionary = GameState.get_save_data().duplicate(true)
	invalid_version_payload["version"] = "4"
	var invalid_version_rejected := not GameState.load_save_data(invalid_version_payload)
	_expect(invalid_version_rejected and GameState.get_save_data() == state_before_malformed_load, "save version with the wrong type is rejected without mutation")
	var float_version_payload: Dictionary = GameState.get_save_data().duplicate(true)
	float_version_payload["version"] = 4.5
	var float_version_rejected := not GameState.load_save_data(float_version_payload)
	_expect(float_version_rejected and GameState.get_save_data() == state_before_malformed_load, "fractional save version is rejected without mutation")

	var future_payload: Dictionary = GameState.get_save_data()
	future_payload["version"] = GameState.SAVE_VERSION + 1
	var future_rejected := not GameState.load_save_data(future_payload)
	_expect(future_rejected and GameState.get_save_data() == state_before_malformed_load, "unsupported future save version is rejected without mutation")

	var legacy_payload := {
		"version": 1,
		"player": {"health": 70, "energy": 22, "position_x": 321.5, "position_y": 654.25},
		"inventory": {"scrap": 10, "ammo": 2, "rust_blade": 1, "pipe_rifle": 1, "patched_armor": 1, "recycler_glove": 1},
		"equipment": {"weapon": "rust_blade", "ranged": "pipe_rifle", "armor": "patched_armor", "tool": "recycler_glove"},
		"scene": "village",
		"spawn_point": "default",
		"seed": 1234,
		"level": 2,
		"defeated_enemies": 4,
		"discovered_events": []
	}
	var all_legacy_versions_loaded := true
	for legacy_version in range(1, GameState.SAVE_VERSION + 1):
		legacy_payload["version"] = legacy_version
		var legacy_written := _write_wrapped_data(legacy_payload, test_save_path)
		all_legacy_versions_loaded = all_legacy_versions_loaded and legacy_written and SaveManager.load_game(false, false, test_save_path)
	_expect(all_legacy_versions_loaded, "version 1 through current saves load with legacy defaults")
	_expect(GameState.current_route_id == "scrap_highway" and GameState.quest_progress.is_empty(), "legacy save receives defaults for fields added later")
	_expect(GameState.player_position == Vector2(321.5, 654.25), "legacy save restores its player position")
	GameState.reset_new_run(false)
	GameState.current_scene_id = "wasteland"
	GameState.current_route_id = "scrap_highway"
	GameState.player_position = Vector2(1234, 2345)
	GameState.hp = 71
	GameState.ep = 35
	var path_restored := SaveManager.load_game(false, false, test_save_path)
	_expect(path_restored and GameState.hp == 70, "save loader reads the selected test path")
	GameState.player_position = Vector2(1234, 2345)
	GameState.current_scene_id = "wasteland"
	GameState.active_spawn_point = "saved"
	GameState.current_route_id = "scrap_highway"
	var position_save := SaveManager.save_game(false, test_save_path)
	_expect(position_save, "position fixture saves to the test path")
	var position_payload := _read_payload(test_save_path)
	_expect(position_payload.get("spawn_point", "") == "saved", "position fixture retains saved-position semantics")

	var repeat_save := SaveManager.save_game(false, test_save_path)
	var repeat_load := SaveManager.load_game(false, false, test_save_path)
	_expect(repeat_save and repeat_load and GameState.player_position == Vector2(1234, 2345), "repeated atomic save replaces and reloads the prior save")

	GameState.reset_new_run(false)
	GameState.consume_item("ammo", int(GameState.inventory.get("ammo", 0)))
	var empty_ammo_saved := SaveManager.save_game(false, test_save_path)
	GameState.add_item("ammo", 5)
	var empty_ammo_loaded := SaveManager.load_game(false, false, test_save_path)
	_expect(empty_ammo_saved and empty_ammo_loaded and int(GameState.inventory.get("ammo", 0)) == 0, "save roundtrip preserves a legitimately depleted resource")
	_expect(GameState.quick_slots.has("ammo"), "depleted resource may remain bound to its quick slot")
	GameState.current_scene_id = "wasteland"
	GameState.active_spawn_point = "saved"
	GameState.current_route_id = "scrap_highway"
	GameState.player_position = Vector2(1234, 2345)
	_expect(SaveManager.save_game(false, test_save_path), "position restore fixture is reinstated after the inventory check")

func _run_position_restore_regression() -> void:
	var loaded := SaveManager.load_game(false, false, test_save_path)
	_expect(loaded and GameState.active_spawn_point == "saved", "manual load restores saved spawn semantics")
	var expected_position := GameState.player_position
	var wasteland: Node2D = WASTELAND_SCENE.instantiate()
	wasteland.call("_spawn_player", Vector2(2800, 4000))
	var spawned_player: Node2D = wasteland.get("player") as Node2D
	_expect(spawned_player != null and spawned_player.global_position.distance_to(expected_position) < 0.1, "wasteland instantiation restores the saved player position")
	wasteland.free()

func _run_route_scoped_event_save_regression() -> void:
	GameState.reset_new_run(false)
	GameState.current_scene_id = "wasteland"
	GameState.current_route_id = "crystal_scar"
	var wasteland: Node = WASTELAND_SCENE.instantiate()
	wasteland.call("_on_event_interacted", "event:crystal_scar:supply_cache")
	var event_id := "crystal_scar:supply_cache"
	var payload := _read_payload(test_save_path)
	var discovered_events: Array = payload.get("discovered_events", [])
	var auto_saved: bool = discovered_events.has(event_id)
	GameState.discovered_events.clear()
	var loaded := SaveManager.load_game(false, false, test_save_path)
	_expect(auto_saved, "collecting a route event writes its route-scoped id to the save")
	_expect(loaded and GameState.discovered_events.has(event_id), "route-scoped discovered event survives the real save/load boundary")

	var legacy_payload: Dictionary = GameState.get_save_data().duplicate(true)
	legacy_payload["discovered_events"] = ["supply_cache"]
	var legacy_written := _write_wrapped_data(legacy_payload, test_save_path)
	GameState.discovered_events.clear()
	var legacy_loaded := SaveManager.load_game(false, false, test_save_path)
	_expect(legacy_written and legacy_loaded and GameState.discovered_events.has("supply_cache"), "legacy unscoped discovered-event ids remain loadable")
	var legacy_event_ammo_before := GameState.ammo
	wasteland.call("_on_event_interacted", "event:crystal_scar:supply_cache")
	_expect(GameState.ammo == legacy_event_ammo_before, "legacy bare event id prevents a duplicate route-scoped reward")

	var state_before_unknown_route := GameState.get_save_data().duplicate(true)
	var unknown_route_payload: Dictionary = state_before_unknown_route.duplicate(true)
	unknown_route_payload["discovered_events"] = ["unknown_route:supply_cache"]
	var unknown_route_written := _write_wrapped_data(unknown_route_payload, test_save_path)
	var unknown_route_loaded := SaveManager.load_game(false, false, test_save_path)
	_expect(unknown_route_written and not unknown_route_loaded and GameState.get_save_data() == state_before_unknown_route, "event id with an unknown route is rejected without mutation")

	var unknown_event_payload: Dictionary = state_before_unknown_route.duplicate(true)
	unknown_event_payload["discovered_events"] = ["crystal_scar:missing_event"]
	var unknown_event_written := _write_wrapped_data(unknown_event_payload, test_save_path)
	var unknown_event_loaded := SaveManager.load_game(false, false, test_save_path)
	_expect(unknown_event_written and not unknown_event_loaded and GameState.get_save_data() == state_before_unknown_route, "route-scoped id with an unknown event is rejected without mutation")
	wasteland.free()

func _run_death_save_boundary_regressions() -> void:
	_seed_sentinel_state()
	var healthy_saved := SaveManager.save_game(false, test_save_path)
	var previous_save_bytes := _read_text(test_save_path)
	GameState.current_scene_id = "wasteland"
	GameState.hp = 1
	GameState.take_damage(10)
	var death_save_succeeded := SaveManager.save_game(false, test_save_path)
	var bytes_after_death_save := _read_text(test_save_path)
	_expect(healthy_saved and not death_save_succeeded and bytes_after_death_save == previous_save_bytes, "death-window save is refused without changing the previous save bytes")
	_expect(GameState.death_pending, "refusing a death-window save leaves recovery pending")
	GameState.reset_new_run(false)

	var zero_hp_payload: Dictionary = GameState.get_save_data().duplicate(true)
	zero_hp_payload["player"]["health"] = 0
	zero_hp_payload["player"]["energy"] = 4
	zero_hp_payload["player"]["position_x"] = 720.0
	zero_hp_payload["player"]["position_y"] = 860.0
	zero_hp_payload["scene"] = "wasteland"
	zero_hp_payload["spawn_point"] = "saved"
	zero_hp_payload["route"] = "old_factory"
	zero_hp_payload["xp"] = 37
	zero_hp_payload["inventory"]["scrap"] = 17
	var expected_inventory: Dictionary = zero_hp_payload["inventory"].duplicate(true)
	var zero_hp_written := _write_wrapped_data(zero_hp_payload, test_save_path)
	var zero_hp_loaded := SaveManager.load_game(false, false, test_save_path)
	_expect(zero_hp_written and zero_hp_loaded and GameState.current_scene_id == "village" and GameState.active_spawn_point == "clinic", "loading a valid zero-HP save recovers at the clinic")
	_expect(GameState.hp == GameState.get_max_hp() and GameState.ep == GameState.get_max_ep() and not GameState.death_pending, "zero-HP recovery restores control and full resources")
	_expect(GameState.inventory == expected_inventory and GameState.xp == 37 and GameState.current_route_id == "old_factory", "zero-HP recovery preserves inventory and progression")

func _run_pending_death_cancellation_regressions() -> void:
	GameState.reset_new_run(false)
	GameState.current_scene_id = "wasteland"
	GameState.hp = 1
	GameState.take_damage(10)
	GameState.reset_new_run(false)
	GameState.current_scene_id = "guild"
	await get_tree().create_timer(1.4).timeout
	_expect(GameState.current_scene_id == "guild" and GameState.hp == GameState.get_max_hp() and not GameState.death_pending, "new-run reset cancels the pending death transition")

	GameState.reset_new_run(false)
	GameState.current_scene_id = "guild"
	GameState.hp = 83
	GameState.ep = 29
	GameState.player_position = Vector2(320, 240)
	var saved := SaveManager.save_game(false, test_save_path, false)
	GameState.current_scene_id = "wasteland"
	GameState.hp = 1
	GameState.take_damage(10)
	var loaded := SaveManager.load_game(false, false, test_save_path)
	_expect(saved and loaded and GameState.current_scene_id == "guild" and GameState.hp == 83 and not GameState.death_pending, "valid load restores state and cancels the pending death")
	await get_tree().create_timer(1.4).timeout
	_expect(GameState.current_scene_id == "guild" and GameState.hp == 83 and GameState.player_position == Vector2(320, 240), "stale death timer cannot overwrite a loaded game")

	GameState.reset_new_run(false)
	GameState.current_scene_id = "guild"
	GameState.hp = 1
	paused_death_transition_received = false
	if GameState.scene_changed.is_connected(_on_paused_death_transition_scene_changed):
		GameState.scene_changed.disconnect(_on_paused_death_transition_scene_changed)
	GameState.scene_changed.connect(_on_paused_death_transition_scene_changed)
	GameState.take_damage(10)
	await get_tree().process_frame
	get_tree().paused = true
	await get_tree().create_timer(1.4, true).timeout
	_expect(GameState.current_scene_id == "guild" and GameState.death_pending and not paused_death_transition_received, "pausing freezes death recovery without routing behind the pause menu")
	get_tree().paused = false
	await get_tree().create_timer(1.4, true).timeout
	_expect(paused_death_transition_received and GameState.current_scene_id == "village" and GameState.active_spawn_point == "clinic" and not GameState.death_pending, "unpausing resumes death recovery and routes to the clinic")
	if GameState.scene_changed.is_connected(_on_paused_death_transition_scene_changed):
		GameState.scene_changed.disconnect(_on_paused_death_transition_scene_changed)
	SceneRouter._pending_scene_id = ""
	GameState.reset_new_run(false)

	GameState.current_scene_id = "guild"
	GameState.hp = 1
	title_return_scene_received = false
	unexpected_title_return_recovery_received = false
	if GameState.scene_changed.is_connected(_on_title_return_scene_changed):
		GameState.scene_changed.disconnect(_on_title_return_scene_changed)
	GameState.scene_changed.connect(_on_title_return_scene_changed)
	GameState.take_damage(10)
	await get_tree().process_frame
	SceneRouter.change_to("main")
	_expect(GameState.current_scene_id == "main" and not GameState.death_pending, "returning to title cancels pending death recovery")
	await get_tree().create_timer(1.4, true).timeout
	_expect(title_return_scene_received and not unexpected_title_return_recovery_received and GameState.current_scene_id == "main", "cancelled death recovery cannot later teleport from the title screen")
	if GameState.scene_changed.is_connected(_on_title_return_scene_changed):
		GameState.scene_changed.disconnect(_on_title_return_scene_changed)
	SceneRouter._pending_scene_id = ""
	GameState.reset_new_run(false)

func _on_paused_death_transition_scene_changed(scene_id: String) -> void:
	if scene_id == "village" and GameState.active_spawn_point == "clinic":
		paused_death_transition_received = true
		call_deferred("_cancel_paused_death_scene_change")

func _cancel_paused_death_scene_change() -> void:
	SceneRouter._pending_scene_id = ""

func _on_title_return_scene_changed(scene_id: String) -> void:
	if scene_id == "main":
		title_return_scene_received = true
		SceneRouter._pending_scene_id = ""
	elif scene_id == "village" and GameState.active_spawn_point == "clinic":
		unexpected_title_return_recovery_received = true
		SceneRouter._pending_scene_id = ""

func _run_death_recovery_regression() -> void:
	GameState.reset_new_run(false)
	GameState.current_scene_id = "wasteland"
	GameState.current_route_id = "scrap_highway"
	GameState.player_position = Vector2(720, 860)
	GameState.hp = 1
	GameState.ep = 4
	death_transition_received = false
	death_timeout = Timer.new()
	death_timeout.one_shot = true
	death_timeout.wait_time = 3.0
	death_timeout.timeout.connect(_on_death_transition_timeout)
	add_child(death_timeout)
	death_timeout.start()
	if not GameState.scene_changed.is_connected(_on_death_transition_scene_changed):
		GameState.scene_changed.connect(_on_death_transition_scene_changed)
	GameState.take_damage(10)

func _on_death_transition_timeout() -> void:
	if not death_transition_received:
		_expect(false, "death recovery routes the player back to the clinic")
		_finish()

func _on_death_transition_scene_changed(scene_id: String) -> void:
	if scene_id == "village" and GameState.active_spawn_point == "clinic":
		death_transition_received = true
		if death_timeout != null:
			death_timeout.stop()
			death_timeout.queue_free()
			death_timeout = null
		call_deferred("_check_death_transition_state")

func _check_death_transition_state() -> void:
	_expect(GameState.hp == GameState.get_max_hp() and GameState.ep == GameState.get_max_ep() and not GameState.death_pending, "death recovery restores HP, EP, and active control")
	var transition_payload := _read_payload(test_save_path)
	_expect(String(transition_payload.get("scene", "")) == "village" and String(transition_payload.get("spawn_point", "")) == "clinic", "scene transition saves its intended clinic entry point")
	_expect(Vector2(float(transition_payload.get("player", {}).get("position_x", 0.0)), float(transition_payload.get("player", {}).get("position_y", 0.0))) == Vector2(720, 860), "transition save keeps the prior scene coordinates separate from its spawn point")
	SceneRouter._pending_scene_id = ""
	_finish()

func _seed_sentinel_state() -> void:
	GameState.reset_new_run(false)
	GameState.current_scene_id = "village"
	GameState.current_route_id = "scrap_highway"
	GameState.active_spawn_point = "from_wasteland"
	GameState.hp = 71
	GameState.ep = 35
	GameState.player_position = Vector2(111, 222)
	GameState.inventory["scrap"] = 17
	GameState.scrap = 17

func _decode_wrapper(wrapper: Variant) -> Dictionary:
	if typeof(wrapper) != TYPE_DICTIONARY:
		return {}
	var payload_text := Marshalls.base64_to_utf8(String(wrapper.get("payload", "")))
	if payload_text.sha256_text() != String(wrapper.get("checksum", "")):
		return {}
	var parsed = JSON.parse_string(payload_text)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func _read_payload(path: String) -> Dictionary:
	return _decode_wrapper(JSON.parse_string(_read_text(path)))

func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_as_text() if file != null else ""

func _write_wrapped_data(data: Dictionary, path: String) -> bool:
	var payload := JSON.stringify(data)
	var wrapped := {
		"checksum": payload.sha256_text(),
		"payload": Marshalls.utf8_to_base64(payload)
	}
	return _write_text(path, JSON.stringify(wrapped, "\t"))

func _write_text(path: String, value: String) -> bool:
	var absolute_path := ProjectSettings.globalize_path(path) if path.begins_with("user://") or path.begins_with("res://") else path
	var parent_directory := absolute_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(parent_directory) and DirAccess.make_dir_recursive_absolute(parent_directory) != OK:
		return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(value)
	return file.get_error() == OK

func _expect(passed: bool, name: String) -> void:
	checks.append({"name": name, "passed": passed, "details": ""})
	if passed:
		print("[PASS] " + name)
	else:
		failures.append(name)
		push_error("[FAIL] " + name)

func _finish() -> void:
	if runner_finished:
		return
	runner_finished = true
	var status := "passed" if failures.is_empty() else "failed"
	var report := {"status": status, "checks": checks.duplicate(true)}
	var report_written := true
	if not report_directory.is_empty():
		var report_path := report_directory.path_join(REPORT_FILENAME)
		report_written = _write_text(report_path, JSON.stringify(report, "\t"))
		if not report_written:
			push_error("Could not write gameplay regression report: " + report_path)
	_stop_test_audio()
	if not failures.is_empty() or not report_written:
		print("[GAMEPLAY_REGRESSION] failed (%d checks, report_written=%s)" % [failures.size(), str(report_written)])
		result_exit_code = 1
	else:
		print("[GAMEPLAY_REGRESSION] passed (%d checks)" % checks.size())
		result_exit_code = 0
	get_tree().create_timer(0.1).timeout.connect(_quit_after_audio_flush)

func _quit_after_audio_flush() -> void:
	get_tree().quit(result_exit_code)

func _stop_test_audio() -> void:
	if AudioManager.music_player != null:
		AudioManager.music_player.stop()
		AudioManager.music_player.stream = null
	if AudioManager.voice_player != null:
		AudioManager.voice_player.stop()
		AudioManager.voice_player.stream = null
	for player in AudioManager.sfx_players:
		player.stop()
		player.stream = null
