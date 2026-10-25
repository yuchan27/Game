extends Node

const WASTELAND_SCENE := preload("res://scenes/levels/wasteland/Wasteland.tscn")
const CAMPAIGN_SCRIPT := preload("res://scripts/systems/CampaignProgress.gd")
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
var last_dialogue_speaker := ""
var last_dialogue_role := ""
var last_dialogue_message := ""
var death_timeout: Timer
var result_exit_code := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run_all.call_deferred()

func _run_all() -> void:
	get_tree().current_scene = null
	var start := Node2D.new()
	get_tree().root.add_child(start)
	get_tree().current_scene = start
	_parse_user_arguments()
	SaveManager.default_save_path = test_save_path
	DataRegistry.load_all()
	GameState.dialogue_requested.connect(_capture_dialogue_message)
	await get_tree().process_frame
	_run_quest_regressions()
	_run_free_order_story_regression()
	_run_full_contract_progression_cycle()
	_run_campaign_outing_regressions()
	_run_save_validation_regressions()
	await _run_position_restore_regression()
	_run_route_scoped_event_save_regression()
	_run_death_save_boundary_regressions()
	_run_dead_pickup_regression()
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


func _run_dead_pickup_regression() -> void:
	GameState.reset_new_run(false)
	GameState.perks["nano_salvage"] = 1
	GameState.hp = 0
	GameState.death_pending = true
	var body := Node2D.new()
	body.add_to_group("player")
	add_child(body)
	var pickup := preload("res://scripts/components/Pickup.gd").new()
	pickup.setup("scrap", 2)
	add_child(pickup)
	var inventory_before := GameState.inventory.duplicate(true)
	pickup.call("_on_body_entered", body)
	_expect(not pickup.collected and GameState.hp == 0 and GameState.inventory == inventory_before, "pending death prevents pickup rewards and nano-salvage resurrection")
	GameState.death_pending = false
	pickup.call("_on_body_entered", body)
	_expect(not pickup.collected and GameState.inventory == inventory_before, "zero-health pickup is rejected even before death flag propagation")
	pickup.free()
	body.free()
	GameState.reset_new_run(false)

func _run_quest_regressions() -> void:
	GameState.reset_new_run(false)
	_expect(GameState.next_story_quest_id() == "clear_scrap_route", "the story tracker points to the opening campaign contract")
	_expect(not GameState.is_quest_available("metropolis_archive"), "the city archive stays locked until the four core route contracts are complete")
	_expect(not GameState.is_story_event_unlocked("story_metropolis_archive"), "the city archive discovery stays locked before its campaign prerequisites")
	_expect(GameState.is_story_event_unlocked("story_scrap_manifest"), "the opening route clue is unlocked without an active quest acceptance")
	_expect(not GameState.start_quest("metropolis_archive"), "a campaign prerequisite cannot be bypassed by direct quest acceptance")
	GameState.current_scene_id = "village"
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

	GameState.current_scene_id = "wasteland"
	GameState.current_route_id = "toxic_marsh"
	var count_before_wrong_route := int(GameState.quest_progress.get("defeat_enemy", 0))
	GameState.record_enemy_defeated()
	_expect(int(GameState.quest_progress.get("defeat_enemy", 0)) == count_before_wrong_route, "kill on another route does not progress the quest")
	GameState.current_route_id = "scrap_highway"
	for _index in range(4):
		GameState.record_enemy_defeated()
	_expect(int(GameState.quest_progress.get("defeat_enemy", 0)) == 5, "kill on the quest route advances its counter")
	GameState.add_item("scrap", 12)
	var route_state: Dictionary = GameState.route_states.get("scrap_highway", {}).duplicate(true)
	var fields: Dictionary = route_state.get("field_objectives", {}).duplicate(true)
	fields["highway_bypass_repair"] = true
	route_state["field_objectives"] = fields
	GameState.route_states["scrap_highway"] = route_state
	if GameState.quest_progress.has("campaign"):
		GameState.quest_progress["campaign"]["outing_index"] = 2
	GameState.current_scene_id = "village"
	_expect(GameState.is_active_quest_ready(), "quest objectives become ready after route kills and collection")
	var completed := GameState.complete_active_quest()
	var reward_after_first_completion := GameState.inventory.duplicate(true)
	var xp_after_first_completion := GameState.xp
	var duplicate_completion := GameState.complete_active_quest()
	_expect(completed, "ready quest completes")
	_expect(not duplicate_completion, "duplicate quest completion is rejected")
	_expect(GameState.inventory == reward_after_first_completion and GameState.xp == xp_after_first_completion, "duplicate completion does not grant rewards twice")
	_expect(GameState.quest_progress.is_empty(), "quest completion clears objective counters")

	GameState.current_scene_id = "village"
	GameState.current_route_id = "scrap_highway"
	var second_accepted := GameState.start_quest("toxic_sample")
	_expect(second_accepted and int(GameState.quest_progress.get("defeat_enemy", 0)) == 0, "next quest starts with clean counters")
	GameState.reset_new_run(false)
	GameState.current_scene_id = "village"
	var factory_accepted := GameState.start_quest("old_factory_core")
	GameState.current_scene_id = "wasteland"
	GameState.current_route_id = "old_factory"
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
	_expect(GameState.story_dialogue_for_npc(DataRegistry.get_npc("repair_robot")).is_empty(), "story NPC dialogue remains on its opening line before discoveries")
	var quest_ids := DataRegistry.quest_ids()
	_expect(quest_ids.size() == 8, "the regression data contains six campaign chapters and two retained side contracts")
	var expected_next_story := {
		"clear_scrap_route": "toxic_sample",
		"toxic_sample": "crystal_scar_recon",
		"crystal_scar_recon": "old_factory_core",
		"old_factory_core": "metropolis_archive",
		"drainage_rescue": "metropolis_archive",
		"factory_sabotage": "metropolis_archive",
		"metropolis_archive": "facility_memory",
		"facility_memory": ""
	}
	var event_host: Node = WASTELAND_SCENE.instantiate()
	for quest_id in quest_ids:
		var final_event_route := ""
		var final_event_id := ""
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
			elif String(objective.get("type", "")) == "discover":
				var event_route := String(objective.get("route", ""))
				var event_id := String(objective.get("event", ""))
				if quest_id == "facility_memory":
					final_event_route = event_route
					final_event_id = event_id
					continue
				event_host.set("route_id", event_route)
				event_host.call("_on_event_interacted", "event:%s:%s" % [event_route, event_id])
				if event_id == "story_scrap_manifest":
					_expect(GameState.story_dialogue_for_npc(DataRegistry.get_npc("wasteland_survivor")).contains("巴士名冊"), "NPC story dialogue reflects the first discovered route clue")
		for _index in range(boss_target):
			GameState.record_enemy_defeated(true)
		for _index in range(max(0, enemy_target - boss_target)):
			GameState.record_enemy_defeated(false)
		if quest_id == "facility_memory":
			_expect(int(GameState.quest_progress.get("defeat_boss", 0)) == boss_target and boss_target == 1, "the finale registers its mandatory boss defeat")
			_expect(not GameState.is_active_quest_ready(), "the finale remains incomplete after its boss until the last memory is found")
			event_host.set("route_id", final_event_route)
			event_host.call("_on_event_interacted", "event:%s:%s" % [final_event_route, final_event_id])
		var field_obj: Dictionary = quest.get("field_objective", {})
		if not field_obj.is_empty():
			var f_route := String(field_obj.get("route", quest.get("route", "")))
			var f_id := String(field_obj.get("id", ""))
			var r_state: Dictionary = GameState.route_states.get(f_route, {}).duplicate(true)
			var r_fields: Dictionary = r_state.get("field_objectives", {}).duplicate(true)
			r_fields[f_id] = true
			r_state["field_objectives"] = r_fields
			GameState.route_states[f_route] = r_state
		if GameState.quest_progress.has("campaign"):
			GameState.quest_progress["campaign"]["outing_index"] = 2
		GameState.current_scene_id = "guild"
		_expect(accepted, "contract accepted in sequence: " + quest_id)
		_expect(GameState.is_active_quest_ready(), "contract objectives complete in sequence: " + quest_id)
		var inventory_before_completion := GameState.inventory.duplicate(true)
		var xp_before_completion := GameState.xp
		var level_before_completion := GameState.level
		last_dialogue_speaker = ""
		last_dialogue_role = ""
		last_dialogue_message = ""
		var completed := GameState.complete_active_quest()
		_expect(completed and GameState.completed_quests.has(quest_id), "contract reward delivered in sequence: " + quest_id)
		var completion_text := GameState.quest_completion_story(quest_id)
		if not completion_text.is_empty():
			_expect(last_dialogue_speaker == "米婭" and last_dialogue_role == "委託回報" and last_dialogue_message.contains(completion_text), "quest completion presents its authored story beat: " + quest_id)
		var inventory_after_completion := GameState.inventory.duplicate(true)
		var xp_after_completion := GameState.xp
		var level_after_completion := GameState.level
		var rewards_applied_once := true
		if quest_id == "facility_memory":
			var duplicate_end_completion := GameState.complete_active_quest()
			_expect(not duplicate_end_completion and GameState.inventory == inventory_after_completion and GameState.xp == xp_after_completion, "finale completion cannot grant its reward or XP twice")
			rewards_applied_once = int(inventory_after_completion.get("ammo", 0)) - int(inventory_before_completion.get("ammo", 0)) == 24
			rewards_applied_once = rewards_applied_once and int(inventory_after_completion.get("mutant_core", 0)) - int(inventory_before_completion.get("mutant_core", 0)) == 2
			rewards_applied_once = rewards_applied_once and int(inventory_after_completion.get("scrap", 0)) - int(inventory_before_completion.get("scrap", 0)) == 40
			rewards_applied_once = rewards_applied_once and int(inventory_after_completion.get("dynamo_core", 0)) - int(inventory_before_completion.get("dynamo_core", 0)) == 1
		var progression_increased := level_after_completion > level_before_completion or xp_after_completion > xp_before_completion
		_expect(rewards_applied_once and progression_increased, "finale completion delivers each reward and progression once")
		_expect(GameState.next_story_quest_id() == String(expected_next_story[quest_id]), "story tracker advances after " + quest_id)
		if quest_id == "old_factory_core":
			_expect(GameState.is_quest_available("metropolis_archive"), "the metropolis chapter unlocks after all four original core quests")
			_expect(GameState.is_story_event_unlocked("story_metropolis_archive") and not GameState.is_story_event_unlocked("story_facility_memory"), "city discovery unlocks with the four core quests while the facility clue remains locked")
		if quest_id == "metropolis_archive":
			_expect(GameState.is_story_event_unlocked("story_facility_memory"), "facility discovery unlocks when the city archive contract is complete")
		if quest_id == "facility_memory":
			_expect(GameState.get_story_summary().begins_with("劇情線索：6/6"), "completing the six-route campaign records every chapter discovery")
			var final_water_dialogue := GameState.story_dialogue_for_npc(DataRegistry.get_npc("repair_robot"))
			_expect(final_water_dialogue.contains("按表穩定接水") and final_water_dialogue.contains("水量仍有限"), "NPC dialogue closes the arc after the facility chapter")
	event_host.free()
	GameState.reset_new_run(false)

func _run_free_order_story_regression() -> void:
	GameState.reset_new_run(false)
	GameState.current_scene_id = "guild"
	var accepted := GameState.start_quest("toxic_sample")
	var first_outing_dialogue := GameState.story_dialogue_for_npc(DataRegistry.get_npc("repair_robot"))
	_expect(accepted, "chapter two remains available before chapter one in the free-order opening")
	_expect(
		first_outing_dialogue.contains("泵站") and not first_outing_dialogue.contains("南門只驗過") and not first_outing_dialogue.contains("首股試水"),
		"the first pump-station briefing does not assume the southern-gate sample happened"
	)
	var guild_hint := GameState.get_journey_hint()
	_expect(guild_hint.contains("出擊門按 [E]") and guild_hint.contains("[M] 查看地圖"), "guild route guidance separates map viewing from gate interaction")
	GameState.current_scene_id = "wasteland"
	GameState.current_route_id = "toxic_marsh"
	var field_hint := GameState.get_journey_hint()
	_expect(field_hint.contains("上游取樣口") and field_hint.contains("[M] 查看地圖標記"), "field guidance names the active sample marker and uses M only for the map")
	GameState.reset_new_run(false)

func _run_campaign_outing_regressions() -> void:
	GameState.reset_new_run(false)
	if SaveManager.default_save_path == SaveManager.SAVE_PATH:
		_expect(false, "campaign outing regression refuses the real player save path")
		return
	_run_return_gate_story_continuity_regressions()
	var campaign_quest_ids: Array[String] = [
		"clear_scrap_route", "toxic_sample", "crystal_scar_recon",
		"old_factory_core", "metropolis_archive", "facility_memory"
	]
	var outings_total := 0
	var actions_total := 0
	for quest_id in campaign_quest_ids:
		var quest := DataRegistry.get_quest(quest_id)
		var outings: Array = CAMPAIGN_SCRIPT.outings(quest_id)
		outings_total += outings.size()
		for outing: Dictionary in outings:
			actions_total += outing.get("actions", []).size()
		_expect(bool(quest.get("main_campaign", false)), "authored campaign contract exists: " + quest_id)
	_expect(outings_total == 12, "six authored contracts define twelve outings")
	_expect(actions_total == 25, "twelve outings define twenty-five authored actions")
	if outings_total != 12 or actions_total != 25:
		GameState.reset_new_run(false)
		return

	var event_host: Node = WASTELAND_SCENE.instantiate()
	var completed_action_count := 0
	var flow_succeeded := true
	for quest_id in campaign_quest_ids:
		var quest: Dictionary = DataRegistry.get_quest(quest_id)
		GameState.current_scene_id = "guild"
		if not GameState.start_quest(quest_id):
			_expect(false, "campaign contract starts in order: " + quest_id)
			flow_succeeded = false
			break
		var outings: Array = CAMPAIGN_SCRIPT.outings(quest_id)
		_expect(outings.size() == 2, "campaign contract has two ordered outings: " + quest_id)
		for outing_index in range(outings.size()):
			var outing: Dictionary = outings[outing_index]
			var partial_return := quest_id == "clear_scrap_route" and outing_index == 0
			var finish_contract_goals := outing_index == outings.size() - 1
			var completed_actions := _run_campaign_regression_outing(
				quest, outing, outing_index, partial_return, finish_contract_goals, event_host
			)
			if completed_actions < 0:
				flow_succeeded = false
				break
			completed_action_count += completed_actions
		if not flow_succeeded:
			break
		_expect(GameState.campaign_outing().is_empty(), "both outings safely settle before hand-in: " + quest_id)
		GameState.current_scene_id = "guild"
		_expect(GameState.is_active_quest_ready(), "original objectives and outings are ready to hand in: " + quest_id)
		var inventory_before := GameState.inventory.duplicate(true)
		var xp_before := GameState.xp
		var level_before := GameState.level
		last_dialogue_message = ""
		var handed_in := GameState.complete_active_quest()
		_expect(handed_in, "campaign contract hands in: " + quest_id)
		if not handed_in:
			flow_succeeded = false
			break
		var inventory_after := GameState.inventory.duplicate(true)
		var tracked_items: Dictionary = {}
		var expected_counts: Dictionary = {}
		for objective: Dictionary in quest.get("objectives", []):
			if objective.get("type", "") == "collect":
				var item_id := String(objective.get("item", ""))
				tracked_items[item_id] = true
				expected_counts[item_id] = int(expected_counts.get(item_id, inventory_before.get(item_id, 0))) - int(objective.get("amount", 0))
		var rewards: Dictionary = quest.get("reward", {})
		for item_id: String in rewards:
			tracked_items[item_id] = true
			expected_counts[item_id] = int(expected_counts.get(item_id, inventory_before.get(item_id, 0))) + int(rewards[item_id])
		for item_id: String in tracked_items:
			_expect(int(inventory_after.get(item_id, 0)) == int(expected_counts[item_id]), "hand-in applies exact item delta once: %s / %s" % [quest_id, item_id])
		_expect(GameState.xp > xp_before or GameState.level > level_before, "hand-in grants chapter progression: " + quest_id)
		var completion_text := String(quest.get("campaign_completion_text", ""))
		if not completion_text.is_empty():
			_expect(last_dialogue_message.contains(completion_text), "hand-in presents authored chapter outcome: " + quest_id)
		_expect(GameState.has_completed_campaign(quest_id), "hand-in records completed chapter consequences: " + quest_id)
		var inventory_after_once := GameState.inventory.duplicate(true)
		var xp_after_once := GameState.xp
		var level_after_once := GameState.level
		_expect(not GameState.complete_active_quest(), "duplicate campaign hand-in is rejected: " + quest_id)
		_expect(GameState.inventory == inventory_after_once and GameState.xp == xp_after_once and GameState.level == level_after_once, "duplicate campaign hand-in cannot repeat rewards: " + quest_id)
	if is_instance_valid(event_host):
		event_host.free()
	_expect(flow_succeeded, "campaign outings complete in authored order")
	_expect(completed_action_count == 25, "all twenty-five campaign actions complete through GameState APIs")
	if flow_succeeded and completed_action_count == 25:
		_expect(GameState.get_story_summary().begins_with("劇情線索：6/6"), "six extracted route clues complete the story record")
		var final_water_dialogue := GameState.story_dialogue_for_npc(DataRegistry.get_npc("repair_robot"))
		_expect(final_water_dialogue.contains("按表穩定接水") and final_water_dialogue.contains("水量仍有限"), "final chapter dialogue reflects the restored limited supply")
	if GameState.has_active_expedition():
		GameState.settle_expedition(false)
	GameState.reset_new_run(false)

func _run_return_gate_story_continuity_regressions() -> void:
	var ch1b_choice := CAMPAIGN_SCRIPT.action("clear_scrap_route", "ch1b_return_route", "ch1b_route_coupling")
	var exposed := CAMPAIGN_SCRIPT.option(ch1b_choice, "ch1b_exposed_short")
	var covered := CAMPAIGN_SCRIPT.option(ch1b_choice, "ch1b_covered_long")
	var exposed_waypoints: Array = exposed.get("waypoints", [])
	var covered_waypoints: Array = covered.get("waypoints", [])
	var scrap_gate: Array = DataRegistry.get_wasteland_route("scrap_highway").get("return_gate_position", [])
	var route_paths: Array = DataRegistry.get_wasteland_route("scrap_highway").get("exploration_paths", [])
	var main_road: Array = route_paths[0] if not route_paths.is_empty() else []
	var gate_approach_is_authored := false
	for index in range(1, main_road.size()):
		if main_road[index - 1] == [0.5, 0.3] and main_road[index] == scrap_gate:
			gate_approach_is_authored = true
	var both_choices_reach_gate_staging: bool = (
		not exposed_waypoints.is_empty()
		and not covered_waypoints.is_empty()
		and exposed_waypoints.back() == [0.5, 0.14]
		and covered_waypoints.back() == [0.5, 0.14]
	)
	_expect(
		scrap_gate == [0.5, 0.07]
		and gate_approach_is_authored
		and both_choices_reach_gate_staging
		and float(exposed_waypoints.back()[0]) == float(scrap_gate[0])
		and float(exposed_waypoints.back()[1]) < 0.3
		and float(exposed_waypoints.back()[1]) > float(scrap_gate[1]),
		"chapter 1B routes converge on the northbound gate approach without completing at the gate"
	)
	var exposed_reward: Dictionary = exposed.get("reward", {})
	var covered_reward: Dictionary = covered.get("reward", {})
	_expect(
		exposed_waypoints.size() < covered_waypoints.size()
		and int(exposed.get("waves", 0)) > int(covered.get("waves", 0))
		and int(exposed_reward.get("mutant_herb", 0)) == 2
		and covered_reward.is_empty(),
		"chapter 1B keeps the exposed-short versus covered-long risk and supply tradeoff"
	)
	var ch1b_carry := CAMPAIGN_SCRIPT.action("clear_scrap_route", "ch1b_carry_coupling", "ch1b_route_coupling")
	var ch1b_instruction := String(ch1b_carry.get("instruction", ""))
	var ch1b_result := String(ch1b_carry.get("result_text", ""))
	_expect(
		ch1b_instruction.contains("實際回村門按 E")
		and ch1b_result.contains("尚未撤離")
		and ch1b_result.contains("回村門靠近按 E"),
		"chapter 1B carry text leaves extraction pending until E at the physical gate"
	)

	var ch3b_outing := CAMPAIGN_SCRIPT.outing_by_id("crystal_scar_recon", "ch3b_relay_defense")
	var ch3b_carry := CAMPAIGN_SCRIPT.action("crystal_scar_recon", "ch3b_carry_relay", "ch3b_relay_defense")
	var ch3b_defend := CAMPAIGN_SCRIPT.action("crystal_scar_recon", "ch3b_defend_relay", "ch3b_relay_defense")
	var relay_waypoints: Array = ch3b_carry.get("waypoints", [])
	var relay_position: Array = ch3b_defend.get("position", [])
	var crystal_gate: Array = DataRegistry.get_wasteland_route("crystal_scar").get("return_gate_position", [])
	var ch3b_result := String(ch3b_defend.get("result_text", ""))
	_expect(
		crystal_gate == [0.5, 0.06]
		and not relay_waypoints.is_empty()
		and relay_waypoints.back() == [0.5, 0.83]
		and relay_position == [0.5, 0.83]
		and String(ch3b_defend.get("name", "")).contains("南側入口"),
		"chapter 3B keeps the relay defense at the authored south-entry site"
	)
	_expect(
		String(ch3b_outing.get("briefing", "")).contains("北側遠端回村門按 E")
		and ch3b_result.contains("北側遠端回村門")
		and ch3b_result.contains("靠近按 E"),
		"chapter 3B post-defense text directs the player to the separate far-side return gate"
	)

func _run_campaign_regression_outing(quest: Dictionary, outing: Dictionary, outing_index: int, partial_return: bool, finish_contract_goals: bool, event_host: Node) -> int:
	var quest_id := String(quest.get("id", ""))
	var route_id := String(quest.get("route", ""))
	var expected_outing_id := String(outing.get("id", ""))
	var campaign_state: Dictionary = GameState.quest_progress.get("campaign", {})
	if int(campaign_state.get("outing_index", -1)) != outing_index or String(GameState.campaign_outing().get("id", "")) != expected_outing_id:
		_expect(false, "next authored outing is current without index mutation: " + expected_outing_id)
		return -1
	GameState.current_scene_id = "wasteland"
	GameState.current_route_id = route_id
	if not GameState.begin_expedition():
		_expect(false, "outbound expedition begins: " + expected_outing_id)
		return -1
	_expect(String(GameState.campaign_outing().get("id", "")) == expected_outing_id, "expedition binds current authored outing: " + expected_outing_id)
	if outing_index == 0:
		for objective: Dictionary in quest.get("objectives", []):
			if objective.get("type", "") != "discover":
				continue
			var event_route := String(objective.get("route", ""))
			var event_id := String(objective.get("event", ""))
			event_host.set("route_id", event_route)
			if not GameState.is_story_event_unlocked(event_id):
				_expect(false, "chapter clue is unlocked on its route: " + event_id)
				return -1
			event_host.call("_on_event_interacted", "event:%s:%s" % [event_route, event_id])
			if not GameState.has_story_discovery(event_route, event_id):
				_expect(false, "chapter clue records during its outing: " + event_id)
				return -1

	var actions: Array = outing.get("actions", [])
	for definition: Dictionary in actions:
		var action_id := String(definition.get("id", ""))
		var requirements: Array = definition.get("requires", [])
		var unmet_dependency := false
		for requirement: String in requirements:
			if GameState.campaign_action_status(requirement) != "done":
				unmet_dependency = true
		if unmet_dependency:
			_expect(GameState.campaign_action_status(action_id) == "locked", "authored action dependency blocks early start: " + action_id)
			_expect(not GameState.complete_campaign_action(action_id, _campaign_regression_result(definition)), "locked action cannot skip its prerequisite: " + action_id)

	var action_count := 0
	var action_index := 0
	while action_index < actions.size():
		var definition: Dictionary = actions[action_index]
		var action_id := String(definition.get("id", ""))
		if GameState.campaign_action_status(action_id) == "done":
			action_index += 1
			continue
		if GameState.campaign_action_status(action_id) != "ready":
			_expect(false, "next action becomes ready after its declared prerequisites: " + action_id)
			return -1
		if not _complete_campaign_regression_action(definition, actions):
			_expect(false, "typed campaign action completes through existing APIs: " + action_id)
			return -1
		action_count += 1
		if partial_return and action_index == 0:
			_expect(int(GameState.quest_progress["campaign"]["outing_index"]) == outing_index, "an in-run partial outing does not advance early: " + expected_outing_id)
			if action_index + 1 < actions.size():
				var next_action: Dictionary = actions[action_index + 1]
				_expect(GameState.campaign_action_status(String(next_action.get("id", ""))) == "ready", "dependent action unlocks after its prerequisite: " + String(next_action.get("id", "")))
			GameState.current_scene_id = "guild"
			var partial_result := GameState.settle_expedition(true)
			if partial_result.get("outcome", "") != "extracted":
				_expect(false, "partial outing uses successful extraction settlement: " + expected_outing_id)
				return -1
			_expect(int(GameState.quest_progress["campaign"]["outing_index"]) == outing_index, "partial extraction preserves current outing: " + expected_outing_id)
			_expect(GameState.quest_progress["campaign"]["actions"].has(action_id), "partial extraction banks completed action: " + action_id)
			_expect(GameState.campaign_action_status(action_id) == "done", "banked action remains completed on return: " + action_id)
			if not _campaign_discoveries_are_extracted(quest):
				_expect(false, "story clue remains pending after its first safe extraction: " + quest_id)
				return -1
			GameState.current_scene_id = "wasteland"
			GameState.current_route_id = route_id
			if not GameState.begin_expedition():
				_expect(false, "partial outing can resume on the same route: " + expected_outing_id)
				return -1
			_expect(String(GameState.campaign_outing().get("id", "")) == expected_outing_id, "partial extraction resumes the same outing: " + expected_outing_id)
			_expect(GameState.campaign_action_status(action_id) == "done", "partial extraction does not repeat completed action: " + action_id)
			action_index += 1
			continue
		action_index += 1

	if finish_contract_goals and not _complete_campaign_contract_goals(quest):
		_expect(false, "original chapter objectives are fulfilled with their existing APIs: " + quest_id)
		return -1
	if finish_contract_goals:
		_expect(not GameState.is_active_quest_ready(), "final outing cannot hand in before safe extraction: " + quest_id)
		_expect(_campaign_discoveries_are_extracted(quest), "chapter clue has been safely carried before final hand-in: " + quest_id)
	var index_before_return := int(GameState.quest_progress["campaign"]["outing_index"])
	GameState.current_scene_id = "guild"
	var result := GameState.settle_expedition(true)
	if result.get("outcome", "") != "extracted" or result.get("campaign_outing", "") != expected_outing_id:
		_expect(false, "completed outing settles through safe extraction: " + expected_outing_id)
		return -1
	var state_after_return: Dictionary = GameState.quest_progress.get("campaign", {})
	var expected_index := index_before_return + 1
	_expect(int(state_after_return.get("outing_index", -1)) == expected_index, "safe extraction advances exactly one outing: " + expected_outing_id)
	_expect(CAMPAIGN_SCRIPT.ready(outing, state_after_return.get("actions", {})), "safe extraction banks every action in the outing: " + expected_outing_id)
	_expect(_campaign_discoveries_are_extracted(quest), "safe extraction banks the chapter clue: " + quest_id)
	var field_objective: Variant = quest.get("field_objective", {})
	if field_objective is Dictionary and not field_objective.is_empty():
		var field_id := String(field_objective.get("id", ""))
		for completed_definition: Dictionary in actions:
			if String(completed_definition.get("field_objective", "")) == field_id and GameState.campaign_action_status(String(completed_definition.get("id", ""))) == "done":
				_expect(GameState.field_objective_status(quest_id), "safe extraction preserves completed original field objective: " + quest_id)
				break
	if expected_index < CAMPAIGN_SCRIPT.outings(quest_id).size():
		var next_outing: Dictionary = CAMPAIGN_SCRIPT.outings(quest_id)[expected_index]
		_expect(String(GameState.campaign_outing().get("id", "")) == String(next_outing.get("id", "")), "next outing unlocks in authored order: " + expected_outing_id)
	else:
		_expect(GameState.campaign_outing().is_empty(), "final outing clears the campaign action gate: " + expected_outing_id)
	GameState.current_scene_id = "guild"
	return action_count

func _complete_campaign_regression_action(definition: Dictionary, outing_actions: Array) -> bool:
	var action_id := String(definition.get("id", ""))
	var action_type := String(definition.get("type", ""))
	var result := _campaign_regression_result(definition)
	if result.is_empty():
		return false
	if action_type == "choice":
		return GameState.request_campaign_choice(action_id) and GameState.complete_campaign_action(action_id, result)
	var progress := GameState.campaign_action_progress(action_id)
	progress["started"] = true
	var route_choice_id := String(definition.get("route_choice", ""))
	var selected_choice_id := GameState.campaign_selected_choice(route_choice_id) if not route_choice_id.is_empty() else ""
	match action_type:
		"channel", "defend":
			progress["elapsed"] = CAMPAIGN_SCRIPT.effective_duration(definition, outing_actions, selected_choice_id)
			if action_type == "defend":
				progress["checkpoint"] = int(definition.get("waves", 0))
		"escort", "carry":
			var waypoints: Array = definition.get("waypoints", [])
			if not route_choice_id.is_empty():
				var choice_definition := CAMPAIGN_SCRIPT.action(GameState.active_quest_id, route_choice_id, String(GameState.campaign_outing().get("id", "")))
				var selected_option := CAMPAIGN_SCRIPT.option(choice_definition, selected_choice_id)
				var selected_waypoints: Variant = selected_option.get("waypoints", [])
				if selected_waypoints is Array and not selected_waypoints.is_empty():
					waypoints = selected_waypoints
			if waypoints.is_empty():
				return false
			progress["checkpoint"] = waypoints.size()
		_:
			return false
	return GameState.update_campaign_action(action_id, progress, GameState.campaign_action_owner()) and GameState.complete_campaign_action(action_id, result)

func _campaign_regression_result(definition: Dictionary) -> String:
	if String(definition.get("type", "")) != "choice":
		return "done"
	var options: Array = definition.get("options", [])
	return String(options[0].get("id", "")) if not options.is_empty() else ""

func _complete_campaign_contract_goals(quest: Dictionary) -> bool:
	var quest_id := String(quest.get("id", ""))
	for objective: Dictionary in quest.get("objectives", []):
		var kind := String(objective.get("type", ""))
		if kind == "collect":
			var item_id := String(objective.get("item", ""))
			var missing := int(objective.get("amount", 0)) - GameState.quest_item_count(item_id)
			if missing > 0:
				GameState.add_field_item(item_id, missing)
				if GameState.quest_item_count(item_id) < int(objective.get("amount", 0)):
					return false
		elif kind == "defeat":
			var counter := String(objective.get("counter", "defeat_enemy"))
			var missing := int(objective.get("amount", 0)) - GameState.quest_counter_value(counter)
			for _index in range(maxi(0, missing)):
				GameState.record_enemy_defeated(counter == "defeat_boss")
			if GameState.quest_counter_value(counter) < int(objective.get("amount", 0)):
				return false
		elif kind == "discover":
			if not GameState.has_story_discovery(String(objective.get("route", "")), String(objective.get("event", ""))):
				return false
	var field_objective: Variant = quest.get("field_objective", {})
	if field_objective is Dictionary and not field_objective.is_empty() and not GameState.field_objective_status(quest_id):
		if not GameState.complete_quest_field_objective(quest_id):
			return false
	return true

func _campaign_discoveries_are_extracted(quest: Dictionary) -> bool:
	for objective: Dictionary in quest.get("objectives", []):
		if objective.get("type", "") != "discover":
			continue
		if GameState.story_discovery_needs_extraction(String(objective.get("route", "")), String(objective.get("event", ""))):
			return false
	return true

func _run_save_validation_regressions() -> void:
	GameState.reset_new_run(false)
	var legacy_campaign_payload := GameState.get_save_data().duplicate(true)
	legacy_campaign_payload["version"] = 4
	legacy_campaign_payload["completed_quests"] = ["clear_scrap_route", "toxic_sample", "crystal_scar_recon", "old_factory_core"]
	var legacy_campaign_written := _write_wrapped_data(legacy_campaign_payload, test_save_path)
	GameState.reset_new_run(false)
	var legacy_campaign_loaded := SaveManager.load_game(false, false, test_save_path)
	_expect(legacy_campaign_written and legacy_campaign_loaded and GameState.completed_quests.size() == 4, "an existing version-4 save keeps its completed core quest ids")
	_expect(GameState.is_quest_available("metropolis_archive"), "completed original contracts unlock the new city chapter after loading an old save")
	_expect(not GameState.start_quest("clear_scrap_route"), "an original completed contract stays completed after loading an old save")
	GameState.reset_new_run(false)
	var weapon_upgraded := GameState.upgrade_weapon_level("rust_blade")
	var weapon_level_saved := SaveManager.save_game(false, test_save_path)
	_expect(weapon_upgraded and weapon_level_saved and GameState.get_weapon_level("rust_blade") == 2, "weapon upgrade is saved to the real test save file")
	GameState.reset_new_run(false)
	var upgraded_weapon_loaded := SaveManager.load_game(false, false, test_save_path)
	_expect(upgraded_weapon_loaded and GameState.get_weapon_level("rust_blade") == 2, "weapon level survives reset and reload from disk")
	GameState.reset_new_run(false)
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
	var invalid_weapon_levels_payload: Dictionary = GameState.get_save_data().duplicate(true)
	invalid_weapon_levels_payload["weapon_levels"] = {"patched_armor": 2}
	var invalid_weapon_levels_rejected := not GameState.load_save_data(invalid_weapon_levels_payload)
	_expect(invalid_weapon_levels_rejected and GameState.get_save_data() == state_before_malformed_load, "non-weapon equipment level is rejected without state mutation")
	var unknown_weapon_level_payload: Dictionary = GameState.get_save_data().duplicate(true)
	unknown_weapon_level_payload["weapon_levels"] = {"missing_weapon": 2}
	var unknown_weapon_level_rejected := not GameState.load_save_data(unknown_weapon_level_payload)
	_expect(unknown_weapon_level_rejected and GameState.get_save_data() == state_before_malformed_load, "unknown weapon level id is rejected without state mutation")
	var fractional_weapon_level_payload: Dictionary = GameState.get_save_data().duplicate(true)
	fractional_weapon_level_payload["weapon_levels"] = {"rust_blade": 2.5}
	var fractional_weapon_level_rejected := not GameState.load_save_data(fractional_weapon_level_payload)
	_expect(fractional_weapon_level_rejected and GameState.get_save_data() == state_before_malformed_load, "fractional weapon level is rejected without state mutation")
	var nonfinite_weapon_level_payload: Dictionary = GameState.get_save_data().duplicate(true)
	nonfinite_weapon_level_payload["weapon_levels"] = {"rust_blade": INF}
	var nonfinite_weapon_level_rejected := not GameState.load_save_data(nonfinite_weapon_level_payload)
	_expect(nonfinite_weapon_level_rejected and GameState.get_save_data() == state_before_malformed_load, "non-finite weapon level is rejected without state mutation")
	var zero_weapon_level_payload: Dictionary = GameState.get_save_data().duplicate(true)
	zero_weapon_level_payload["weapon_levels"] = {"rust_blade": 0}
	var zero_weapon_level_rejected := not GameState.load_save_data(zero_weapon_level_payload)
	_expect(zero_weapon_level_rejected and GameState.get_save_data() == state_before_malformed_load, "weapon level below one is rejected without state mutation")
	var out_of_range_weapon_level_payload: Dictionary = GameState.get_save_data().duplicate(true)
	out_of_range_weapon_level_payload["weapon_levels"] = {"rust_blade": 6}
	var out_of_range_weapon_level_rejected := not GameState.load_save_data(out_of_range_weapon_level_payload)
	_expect(out_of_range_weapon_level_rejected and GameState.get_save_data() == state_before_malformed_load, "weapon level above five is rejected without state mutation")
	var invalid_weapon_levels_type_payload: Dictionary = GameState.get_save_data().duplicate(true)
	invalid_weapon_levels_type_payload["weapon_levels"] = "invalid"
	var invalid_weapon_levels_type_rejected := not GameState.load_save_data(invalid_weapon_levels_type_payload)
	_expect(invalid_weapon_levels_type_rejected and GameState.get_save_data() == state_before_malformed_load, "non-dictionary weapon levels are rejected without state mutation")
	var invalid_perks_type_payload: Dictionary = GameState.get_save_data().duplicate(true)
	invalid_perks_type_payload["perks"] = "invalid"
	var invalid_perks_type_rejected := not GameState.load_save_data(invalid_perks_type_payload)
	_expect(invalid_perks_type_rejected and GameState.get_save_data() == state_before_malformed_load, "non-dictionary perks are rejected without state mutation")
	var unknown_perk_payload: Dictionary = GameState.get_save_data().duplicate(true)
	unknown_perk_payload["perks"] = {"missing_perk": 1}
	var unknown_perk_rejected := not GameState.load_save_data(unknown_perk_payload)
	_expect(unknown_perk_rejected and GameState.get_save_data() == state_before_malformed_load, "unknown perk id is rejected without state mutation")
	var invalid_perk_level_payload: Dictionary = GameState.get_save_data().duplicate(true)
	invalid_perk_level_payload["perks"] = {"arc_overload": 4}
	var invalid_perk_level_rejected := not GameState.load_save_data(invalid_perk_level_payload)
	_expect(invalid_perk_level_rejected and GameState.get_save_data() == state_before_malformed_load, "perk level above its catalog maximum is rejected without state mutation")

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
		"discovered_events": [],
		"expedition": {"active": {}, "last_result": {}, "legacy_trip": false, "uncommitted_clues": []}
	}
	var all_legacy_versions_loaded := true
	for legacy_version in range(1, GameState.SAVE_VERSION + 1):
		legacy_payload["version"] = legacy_version
		var legacy_written := _write_wrapped_data(legacy_payload, test_save_path)
		all_legacy_versions_loaded = all_legacy_versions_loaded and legacy_written and SaveManager.load_game(false, false, test_save_path)
	_expect(all_legacy_versions_loaded, "version 1 through current saves load with legacy defaults")
	_expect(GameState.current_route_id == "scrap_highway" and GameState.quest_progress.is_empty(), "legacy save receives defaults for fields added later")
	_expect(GameState.weapon_levels.is_empty() and GameState.perks.is_empty(), "legacy save defaults missing weapon levels and perks to empty dictionaries")
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
	GameState.begin_expedition()
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
	GameState.current_route_id = "scrap_highway"
	GameState.begin_expedition()
	GameState.active_spawn_point = "saved"
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
	GameState.begin_expedition()
	var wasteland: Node = WASTELAND_SCENE.instantiate()
	wasteland.set("route_id", "crystal_scar")
	wasteland.call("_on_event_interacted", "event:crystal_scar:supply_cache")
	var event_id := "crystal_scar:supply_cache"
	var payload := _read_payload(test_save_path)
	var active_claims: Array = payload.get("expedition", {}).get("active", {}).get("claims", [])
	var auto_saved: bool = active_claims.has(event_id) or payload.get("discovered_events", []).has(event_id)
	GameState.discovered_events.clear()
	var loaded := SaveManager.load_game(false, false, test_save_path)
	_expect(auto_saved, "collecting a route event writes its route-scoped id to the save")
	_expect(loaded and GameState.has_field_claim(event_id), "route-scoped discovered event survives the real save/load boundary")
	wasteland.call("_on_event_interacted", "event:crystal_scar:story_crystal_echo")
	var story_event_id := "crystal_scar:story_crystal_echo"
	_expect(GameState.has_story_discovery("crystal_scar", "story_crystal_echo"), "route story event is recognized through the shared discovery state")
	_expect(GameState.get_story_summary().begins_with("劇情線索：1/6"), "the story summary counts the six route chapters from saved discoveries")
	GameState.discovered_events.clear()
	var story_loaded := SaveManager.load_game(false, false, test_save_path)
	_expect(story_loaded and GameState.discovered_events.has(story_event_id), "story discovery persists across the existing save format")
	_expect(DataRegistry.story_events_for_route("crystal_scar").size() == 1, "each route exposes its own narrative event through DataRegistry")
	_expect(not GameState.has_story_discovery("toxic_marsh", "story_crystal_echo"), "a narrative event cannot be credited to another route")

	var legacy_payload: Dictionary = GameState.get_save_data().duplicate(true)
	legacy_payload["discovered_events"] = ["supply_cache"]
	legacy_payload["expedition"]["uncommitted_clues"] = []
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

	var wrong_story_route_payload: Dictionary = state_before_unknown_route.duplicate(true)
	wrong_story_route_payload["discovered_events"] = ["toxic_marsh:story_crystal_echo"]
	var wrong_story_route_written := _write_wrapped_data(wrong_story_route_payload, test_save_path)
	var wrong_story_route_loaded := SaveManager.load_game(false, false, test_save_path)
	_expect(wrong_story_route_written and not wrong_story_route_loaded and GameState.get_save_data() == state_before_unknown_route, "a scoped story event saved under another route is rejected without mutation")
	var generic_other_route_payload: Dictionary = state_before_unknown_route.duplicate(true)
	generic_other_route_payload["discovered_events"] = ["toxic_marsh:supply_cache"]
	generic_other_route_payload["expedition"]["uncommitted_clues"] = []
	var generic_other_route_written := _write_wrapped_data(generic_other_route_payload, test_save_path)
	var generic_other_route_loaded := SaveManager.load_game(false, false, test_save_path)
	_expect(generic_other_route_written and generic_other_route_loaded and GameState.discovered_events.has("toxic_marsh:supply_cache"), "legacy generic route-scoped events remain valid under their existing save contract")
	wasteland.free()

func _run_death_save_boundary_regressions() -> void:
	_seed_sentinel_state()
	var healthy_saved := SaveManager.save_game(false, test_save_path)
	var previous_save_bytes := _read_text(test_save_path)
	GameState.current_scene_id = "wasteland"
	GameState.current_route_id = "scrap_highway"
	GameState.begin_expedition()
	GameState.hp = 1
	GameState.take_damage(10)
	var death_save_succeeded := SaveManager.save_game(false, test_save_path)
	var bytes_after_death_save := _read_text(test_save_path)
	_expect(healthy_saved and not death_save_succeeded and bytes_after_death_save == previous_save_bytes, "death-window save is refused without changing the previous save bytes")
	_expect(GameState.death_pending, "refusing a death-window save leaves recovery pending")
	GameState.reset_new_run(false)

	GameState.current_scene_id = "wasteland"
	GameState.current_route_id = "old_factory"
	GameState.active_spawn_point = "saved"
	GameState.begin_expedition()
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
	GameState.current_route_id = "scrap_highway"
	GameState.begin_expedition()
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
	GameState.current_route_id = "scrap_highway"
	GameState.begin_expedition()
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
	await get_tree().create_timer(2.0, true).timeout
	_expect(paused_death_transition_received and GameState.current_scene_id == "village" and GameState.active_spawn_point == "clinic" and not GameState.death_pending, "unpausing resumes death recovery and routes to the clinic")
	if GameState.scene_changed.is_connected(_on_paused_death_transition_scene_changed):
		GameState.scene_changed.disconnect(_on_paused_death_transition_scene_changed)
	SceneRouter._pending_scene_id = ""
	GameState.reset_new_run(false)

	while SceneRouter.transition_active:
		await get_tree().process_frame
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
	_expect(not GameState.death_pending, "returning to title cancels pending death recovery")
	await get_tree().create_timer(2.0, true).timeout
	_expect(title_return_scene_received and not unexpected_title_return_recovery_received and GameState.current_scene_id == "main", "cancelled death recovery cannot later teleport from the title screen")
	if GameState.scene_changed.is_connected(_on_title_return_scene_changed):
		GameState.scene_changed.disconnect(_on_title_return_scene_changed)
	SceneRouter._pending_scene_id = ""
	while SceneRouter.transition_active:
		await get_tree().process_frame
	GameState.reset_new_run(false)

func _on_paused_death_transition_scene_changed(scene_id: String) -> void:
	if scene_id == "village" and GameState.active_spawn_point == "clinic":
		paused_death_transition_received = true
		call_deferred("_cancel_paused_death_scene_change")


func _capture_dialogue_message(speaker: String, role: String, message: String) -> void:
	last_dialogue_speaker = speaker
	last_dialogue_role = role
	last_dialogue_message = message

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
	GameState.begin_expedition()
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
		await SceneRouter.transition_finished
		_check_death_transition_state()

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
