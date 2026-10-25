extends Node

const VILLAGE_SCENE := preload("res://scenes/levels/village/Village.tscn")
const WASTELAND_SCENE := preload("res://scenes/levels/wasteland/Wasteland.tscn")
const GUILD_SCENE := preload("res://scenes/levels/guild/Guild.tscn")

var failures: Array[String] = []
var qa_save_path := "user://qa_playtest_save.json"
var qa_output_dir := ""
var _last_walk_blockers: Array[String] = []
var report: Dictionary = {
	"version": 1,
	"runner": "AutomatedPlaytestRunner",
	"checks": [],
	"snapshots": {}
}

func _ready() -> void:
	qa_save_path = _read_user_arg("--qa-save-path", qa_save_path)
	qa_output_dir = _read_user_arg("--qa-output", "")
	SaveManager.default_save_path = qa_save_path
	await get_tree().process_frame
	print("[PLAYTEST] Automated playtest started")
	DataRegistry.load_all()
	await _play_village_input_flow()
	await _play_guild_contract_flow()
	await _play_wasteland_combat_flow()
	await _play_story_site_interaction_flow()
	await _play_story_campaign_target_separation_flow()
	await _play_story_boss_spawn_flow()
	_write_report()
	_finish()

func _play_village_input_flow() -> void:
	GameState.reset_new_run(false)
	GameState.current_scene_id = "village"
	var village := VILLAGE_SCENE.instantiate()
	add_child(village)
	await _settle_frames(3)
	var player := _first_group_node("player") as Node2D
	var hud := _first_node_by_name(village, "HudRoot") as Control
	_expect(player != null, "village: player exists")
	_expect(hud != null, "village: HUD root exists")
	if player != null:
		var camera := player.get_node_or_null("Camera2D")
		_expect(camera is Camera2D and camera.enabled, "village: player camera is enabled")
		var start_position := player.global_position
		Input.action_press("move_right")
		await _settle_seconds(0.35)
		Input.action_release("move_right")
		_expect(player.global_position.x > start_position.x + 20.0, "village: WASD input moves player")
	await _tap_action("open_inventory")
	var inventory_panel := _first_node_by_name(village, "InventoryPanel") as PanelContainer
	_expect(inventory_panel != null and inventory_panel.visible, "village: inventory opens through input")
	var focus_before_tab := get_viewport().gui_get_focus_owner()
	await _tap_key(KEY_TAB)
	var focus_after_tab := get_viewport().gui_get_focus_owner()
	_expect(inventory_panel != null and inventory_panel.visible and focus_after_tab != null and inventory_panel.is_ancestor_of(focus_after_tab) and focus_after_tab != focus_before_tab, "village: Tab advances GUI focus without toggling the inventory")
	var hotbar_slots := get_tree().get_nodes_in_group("hotbar_slot")
	_expect(hotbar_slots.size() >= 4, "village: HUD shows 4 quick slots")
	var active_before := GameState.active_quick_slot
	await _tap_action("swap_weapon")
	_expect(GameState.active_quick_slot == active_before, "village: inventory modal blocks gameplay weapon switching")
	await _tap_action("open_inventory")
	await _tap_action("swap_weapon")
	_expect(GameState.active_quick_slot != active_before, "village: swap input cycles quick slot")
	var ammo_before := GameState.ammo
	_expect(GameState.talk_to_npc("forge_master"), "village: NPC dialogue can be triggered")
	_expect(GameState.ammo == ammo_before + 3, "village: NPC first talk grants reward once")
	GameState.add_item("bio_crystal", 1)
	var crafted := InventorySystem.craft_basic_upgrade()
	_expect(crafted and GameState.inventory.has("spark_cutter"), "village: craft station loop can create weapon")
	_record_snapshot("village", {
		"position": _vector_to_data(player.global_position if player != null else Vector2.ZERO),
		"inventory_open": inventory_panel.visible if inventory_panel != null else false,
		"has_spark_cutter": GameState.inventory.has("spark_cutter"),
		"active_quick_slot": GameState.active_quick_slot,
		"talked_npcs": GameState.talked_npcs.duplicate()
	})
	village.queue_free()
	await _settle_frames(2)

func _play_guild_contract_flow() -> void:
	GameState.reset_new_run(false)
	GameState.current_scene_id = "guild"
	var guild := GUILD_SCENE.instantiate()
	add_child(guild)
	await _settle_frames(3)
	var interactables := get_tree().get_nodes_in_group("interactable")
	_expect(interactables.size() >= 3, "guild: interactable counters exist")
	var player := _first_group_node("player") as Node2D
	var contract_counter: Node2D
	for candidate: Node in interactables:
		if String(candidate.get("interaction_id")) == "contract":
			contract_counter = candidate as Node2D
			break
	_expect(player != null and contract_counter != null, "guild: player and contract board exist")
	if player != null and contract_counter != null:
		player.global_position = contract_counter.global_position
		for _frame in range(8):
			await get_tree().physics_frame
			await get_tree().process_frame
			if bool(contract_counter.call("can_interact")):
				break
		_expect(bool(contract_counter.call("can_interact")), "guild: E interaction is enabled within contract board range")
		await _tap_action("interact")
		await _settle_frames(2)
	var contract_panel := _first_node_by_name(guild, "ContractPanel") as Control
	_expect(contract_panel != null and contract_panel.visible, "guild: E opens the contract catalog")
	var accept_button := _first_node_by_name(guild, "ContractAccept_clear_scrap_route") as Button
	_expect(accept_button != null and not accept_button.disabled, "guild: opening the board presents an enabled quest choice")
	if accept_button != null and contract_panel != null:
		var contract_scroll := _first_node_by_name(guild, "ContractScroll") as ScrollContainer
		if contract_scroll != null:
			contract_scroll.scroll_vertical = 0
		accept_button.grab_focus()
		await _settle_frames(2)
		_expect(contract_scroll != null and _control_fits_scroll(contract_scroll, accept_button), "guild: keyboard focus keeps the selected quest visible in the catalog")
		await _tap_key(KEY_ENTER)
		await _settle_frames(2)
	var started := GameState.active_quest_id == "clear_scrap_route"
	_expect(started, "guild: keyboard activation accepts the selected quest")
	_expect(contract_panel == null or not contract_panel.visible, "guild: successful quest acceptance closes the catalog")
	await _play_contract_field_action_flow(guild)
	for i in range(5):
		GameState.record_enemy_defeated()
	GameState.add_item("scrap", 12)
	if GameState.quest_progress.has("campaign"):
		GameState.quest_progress["campaign"]["outing_index"] = 2
	_expect(GameState.field_objective_status("clear_scrap_route"), "guild: extracted field action remains completed for the active contract")
	_expect(GameState.is_active_quest_ready(), "guild: quest objectives can be completed")
	var reward_before := GameState.cores
	await _tap_key(KEY_J)
	await _settle_frames(2)
	_expect(contract_panel != null and contract_panel.visible, "guild: J reopens the contract page for delivery")
	var claim_button := _first_node_by_name(guild, "ContractClaim") as Button
	_expect(claim_button != null and not claim_button.disabled, "guild: completed objectives enable the delivery button")
	if claim_button != null:
		claim_button.grab_focus()
		await _settle_frames(2)
		await _tap_key(KEY_ENTER)
		await _settle_frames(2)
	var completed := GameState.completed_quests.has("clear_scrap_route")
	_expect(completed, "guild: keyboard activation delivers the completed quest")
	_expect(contract_panel == null or not contract_panel.visible, "guild: successful delivery closes the catalog")
	_expect(GameState.cores == reward_before + 1, "guild: quest delivery grants reward")
	_record_snapshot("guild", {
		"completed_quests": GameState.completed_quests.duplicate(),
		"cores": GameState.cores
	})
	await _play_contract_keyboard_scroll_flow(guild)
	guild.queue_free()
	await _settle_frames(2)

func _play_contract_field_action_flow(guild: Node) -> void:
	var hub_player: Node2D
	for candidate: Node in get_tree().get_nodes_in_group("player"):
		if candidate is Node2D and guild.is_ancestor_of(candidate):
			hub_player = candidate as Node2D
			break
	_expect(hub_player != null, "field action: hub player remains available after contract acceptance")
	if hub_player != null:
		hub_player.set_physics_process(false)
		hub_player.set_process_unhandled_input(false)
	GameState.current_scene_id = "wasteland"
	GameState.set_current_route("scrap_highway")
	var wasteland := WASTELAND_SCENE.instantiate()
	add_child(wasteland)
	await _settle_frames(4)
	var field_player := wasteland.get("player") as Node2D
	var escort_action: Node2D
	var relay_action: Node2D
	for candidate: Node in get_tree().get_nodes_in_group("campaign_action"):
		if not wasteland.is_ancestor_of(candidate):
			continue
		match String(candidate.get("action_id")):
			"ch1a_escort_crew": escort_action = candidate as Node2D
			"ch1a_repair_bypass": relay_action = candidate as Node2D
	_expect(field_player != null, "field action: wasteland spawns its player at the authored entry")
	_expect(escort_action != null and relay_action != null, "field action: accepted contract exposes the first authored outing")
	if field_player != null and escort_action != null and relay_action != null:
		for enemy: Node in get_tree().get_nodes_in_group("enemy"):
			if wasteland.is_ancestor_of(enemy):
				enemy.set("is_dead", true)
				enemy.set_process(false)
				enemy.set_physics_process(false)
				(enemy as CollisionObject2D).collision_layer = 0
				(enemy as CollisionObject2D).collision_mask = 0
		# Prevent the world population timer from replacing the isolated enemies during this walk.
		wasteland.set_process(false)
		var entry_position := field_player.global_position
		_expect(await _walk_player_to(field_player, escort_action.global_position, 4.0), "field action: movement input reaches the fresh-outing escort")
		_expect(entry_position.distance_to(field_player.global_position) > 80.0, "field action: player travels from the real wasteland spawn")
		_expect(field_player.get_nearest_interaction_target() == escort_action, "field action: E selects the first authored escort")
		await _tap_action("interact")
		_expect(GameState.campaign_action_progress("ch1a_escort_crew").get("started", false), "field action: E starts the crew escort")
		var escort_waypoints: Array = escort_action.get("_waypoints")
		var escort_walk: Dictionary = await _walk_player_path(field_player, escort_waypoints, 6.0)
		var relay_walked := bool(escort_walk.get("reached", false))
		var escort_completed := await _wait_for_campaign_action("ch1a_escort_crew", "done", 8.0)
		var escort_state: Dictionary = escort_action.call("presentation_state")
		_expect(relay_walked, "field action: movement follows the authored escort road to the relay (player=%s relay=%s failed_target=%s distance=%.1f)" % [str(field_player.global_position), str(relay_action.global_position), str(escort_walk.get("failed_target", Vector2.ZERO)), float(escort_walk.get("distance", INF))])
		_expect(escort_completed, "field action: escort completes after its actor reaches the relay and rejoins R-17 (%s)" % String(escort_state.get("text", "")))
		_expect(relay_action.call("can_interact"), "field action: relay unlocks after the escort")
		_expect(field_player.get_nearest_interaction_target() == relay_action, "field action: E selects the unlocked relay")
		await _tap_action("interact")
		_expect(GameState.campaign_action_progress("ch1a_repair_bypass").get("started", false), "field action: E starts the bypass repair")
		Input.action_press("interact")
		var channel_elapsed := 0.0
		while channel_elapsed < 4.4:
			await get_tree().physics_frame
			await get_tree().process_frame
			channel_elapsed += 1.0 / float(Engine.physics_ticks_per_second)
		Input.action_release("interact")
		await _settle_frames(2)
		_expect(GameState.field_objective_status("clear_scrap_route"), "field action: holding E completes the actual first-outing objective")
		var return_gate := _wasteland_return_gate(wasteland)
		var return_walk: Dictionary = {"reached": false, "failed_target": Vector2.ZERO, "distance": INF, "blockers": []}
		_expect(return_gate != null, "field action: authored wasteland has a physical return gate")
		if return_gate != null:
			var map_size: Vector2 = wasteland.get("world_size")
			var route_data: Dictionary = wasteland.get("route_data")
			var exploration_paths: Array = route_data.get("exploration_paths", [])
			var northbound_points: Array[Vector2] = [Vector2(map_size.x * 0.5, relay_action.global_position.y)]
			if not exploration_paths.is_empty() and exploration_paths[0] is Array:
				for raw_position: Variant in exploration_paths[0]:
					if not raw_position is Array or raw_position.size() != 2:
						continue
					var route_point := Vector2(float(raw_position[0]) * map_size.x, float(raw_position[1]) * map_size.y)
					if route_point.y < relay_action.global_position.y - 48.0 and route_point.y >= return_gate.global_position.y - 24.0:
						northbound_points.append(route_point)
			if northbound_points.back().distance_to(return_gate.global_position) > 4.0:
				northbound_points.append(return_gate.global_position)
			return_walk = await _walk_player_path(field_player, northbound_points, 10.0)
		_expect(bool(return_walk.get("reached", false)), "field action: player follows the authored northbound road to the far-side return gate (player=%s failed_target=%s distance=%.1f blockers=%s)" % [str(field_player.global_position), str(return_walk.get("failed_target", Vector2.ZERO)), float(return_walk.get("distance", INF)), str(return_walk.get("blockers", []))])
		var gate_interactions: Array[String] = []
		if return_gate != null:
			(return_gate as Interactable).interacted.connect(func(interaction_id: String) -> void: gate_interactions.append(interaction_id))
		for _frame in range(8):
			await get_tree().physics_frame
			await get_tree().process_frame
			if return_gate != null and return_gate.call("can_interact"):
				break
		_expect(return_gate != null and bool(return_gate.call("can_interact")), "field action: physical return gate becomes E-reachable after the walk")
		_expect(field_player.get_nearest_interaction_target() == return_gate, "field action: return gate is the player's selected E target")
		# The QA runner is not the game's current scene, so allow the gate's real signal
		# while preventing SceneRouter from replacing the test process.
		SceneRouter.transition_active = true
		await _tap_action("interact")
		SceneRouter.transition_active = false
		_expect(gate_interactions == ["to_village"], "field action: pressing E activates the physical extraction gate")
	var extracted := GameState.settle_expedition(true)
	_expect(extracted.get("outcome", "") == "extracted", "field action: gate activation settles the active run")
	_expect(int(GameState.quest_progress.get("campaign", {}).get("outing_index", -1)) == 1, "field action: safe extraction advances the first authored outing once")
	GameState.current_scene_id = "guild"
	var campaign: Dictionary = GameState.quest_progress.get("campaign", {}).duplicate(true)
	# The later hand-in assertions retain their previous fixture for chapter completion.
	campaign["outing_index"] = 2
	GameState.quest_progress["campaign"] = campaign
	if hub_player != null:
		hub_player.set_physics_process(true)
		hub_player.set_process_unhandled_input(true)
	wasteland.queue_free()
	await _settle_frames(2)
	_expect(GameState.field_objective_status("clear_scrap_route"), "field action: extracted objective is retained on the route")
	_record_snapshot("field_action", {
		"outing_id": "ch1a_escort_repair",
		"extraction_interaction_id": "to_village",
		"objective_complete": GameState.field_objective_status("clear_scrap_route"),
		"outcome": String(extracted.get("outcome", "")),
		"current_scene": GameState.current_scene_id
	})


func _walk_player_to(player: Node2D, target: Vector2, timeout_seconds: float) -> bool:
	if player == null:
		return false
	var movement_actions := ["move_left", "move_right", "move_up", "move_down"]
	_last_walk_blockers.clear()
	var elapsed := 0.0
	while player.global_position.distance_to(target) > 100.0 and elapsed < timeout_seconds:
		var direction := target - player.global_position
		if direction.x < -1.0:
			Input.action_press("move_left")
		else:
			Input.action_release("move_left")
		if direction.x > 1.0:
			Input.action_press("move_right")
		else:
			Input.action_release("move_right")
		if direction.y < -1.0:
			Input.action_press("move_up")
		else:
			Input.action_release("move_up")
		if direction.y > 1.0:
			Input.action_press("move_down")
		else:
			Input.action_release("move_down")
		await get_tree().physics_frame
		await get_tree().process_frame
		if player is CharacterBody2D:
			var body := player as CharacterBody2D
			for collision_index in range(body.get_slide_collision_count()):
				var collider := body.get_slide_collision(collision_index).get_collider() as Node
				if collider != null:
					var collider_path := String(collider.get_path())
					if not _last_walk_blockers.has(collider_path):
						_last_walk_blockers.append(collider_path)
		elapsed += 1.0 / float(Engine.physics_ticks_per_second)
	for action_name: String in movement_actions:
		Input.action_release(action_name)
	await _settle_frames(2)
	return player.global_position.distance_to(target) <= 116.0


func _walk_player_path(player: Node2D, waypoints: Array, timeout_per_leg: float) -> Dictionary:
	for raw_waypoint: Variant in waypoints:
		if not raw_waypoint is Vector2:
			continue
		var reached := await _walk_player_to(player, raw_waypoint, timeout_per_leg)
		if not reached:
			return {
				"reached": false,
				"failed_target": raw_waypoint,
				"position": player.global_position,
				"distance": player.global_position.distance_to(raw_waypoint),
				"blockers": _last_walk_blockers.duplicate()
			}
	return {"reached": true, "failed_target": Vector2.ZERO, "position": player.global_position, "distance": 0.0, "blockers": []}


func _wait_for_campaign_action(action_id: String, expected_status: String, timeout_seconds: float) -> bool:
	var elapsed := 0.0
	while elapsed < timeout_seconds:
		if GameState.campaign_action_status(action_id) == expected_status:
			return true
		await get_tree().physics_frame
		await get_tree().process_frame
		elapsed += 1.0 / float(Engine.physics_ticks_per_second)
	return GameState.campaign_action_status(action_id) == expected_status


func _wasteland_return_gate(wasteland: Node) -> Node2D:
	for candidate: Node in get_tree().get_nodes_in_group("interactable"):
		if wasteland.is_ancestor_of(candidate) and String(candidate.get("interaction_id")) == "to_village":
			return candidate as Node2D
	return null

func _play_contract_keyboard_scroll_flow(guild: Node) -> void:
	var return_window_size := get_window().size
	get_window().size = Vector2i(800, 600)
	await _settle_frames(3)
	GameState.completed_quests.clear()
	for raw_quest_id in DataRegistry.quest_ids():
		GameState.completed_quests.append(String(raw_quest_id))
	await _tap_key(KEY_J)
	await _settle_frames(3)
	var panel := _first_node_by_name(guild, "ContractPanel") as Control
	var scroll := _first_node_by_name(guild, "ContractScroll") as ScrollContainer
	var completed_toggle := _first_node_by_name(guild, "ContractCatalogGroup_Completed") as Button
	_expect(panel != null and panel.visible and scroll != null and completed_toggle != null, "guild: completed-contract disclosure can be opened with the keyboard")
	if panel != null and scroll != null and completed_toggle != null:
		completed_toggle.grab_focus()
		await _settle_frames(2)
		await _tap_key(KEY_ENTER)
		await _settle_frames(3)
		var last_quest_id := String(DataRegistry.quest_ids().back())
		var last_entry := _first_node_by_name(guild, "ContractDetails_%s" % last_quest_id) as Button
		_expect(last_entry != null, "guild: completed catalog exposes its final disclosure control")
		if last_entry != null:
			scroll.scroll_vertical = 0
			await _settle_frames(2)
			_expect(not _control_fits_scroll(scroll, last_entry), "guild: final quest row begins below the scroll viewport")
			last_entry.grab_focus()
			await _settle_frames(2)
			var focus_reached_row := _control_fits_scroll(scroll, last_entry)
			var focus_scroll_details := "scroll=%.1f max=%.1f viewport=%s row=%s" % [float(scroll.scroll_vertical), scroll.get_v_scroll_bar().max_value, str(scroll.get_global_rect()), str(last_entry.get_global_rect())]
			_expect(focus_reached_row, "guild: keyboard focus follows the final quest row through the scroll region (%s)" % focus_scroll_details)
			await _tap_key(KEY_ENTER)
			await _settle_frames(2)
			var last_details := _first_node_by_name(guild, "ContractDetailsText_%s" % last_quest_id) as Control
			_expect(last_details != null and last_details.visible, "guild: the final quest details expand from keyboard focus")
		var navigation := _first_node_by_name(guild, "ModalNavigation") as Control
		var close_button := _first_node_by_name(guild, "ModalCloseButton") as Control
		_expect(navigation != null and close_button != null and not close_button.get_global_rect().intersects(scroll.get_global_rect()), "guild: close control stays outside the scroll region")
		await _tap_key(KEY_ESCAPE)
		await _settle_frames(2)
		_expect(not panel.visible, "guild: Escape closes the contract page after scrolling")
	get_window().size = return_window_size
	await _settle_frames(3)

func _play_wasteland_combat_flow() -> void:
	GameState.reset_new_run(false)
	GameState.current_scene_id = "wasteland"
	var wasteland := WASTELAND_SCENE.instantiate()
	add_child(wasteland)
	await _settle_frames(4)
	var player := _first_group_node("player") as Node2D
	var enemies := get_tree().get_nodes_in_group("enemy")
	var pools := get_tree().get_nodes_in_group("projectile_pool")
	_expect(player != null, "wasteland: player exists")
	_expect(enemies.size() >= int(DataRegistry.map_params.get("enemy_limit", 50)), "wasteland: configured enemy pressure spawn exists")
	_expect(pools.size() == 1, "wasteland: projectile pool exists")
	if player == null or enemies.is_empty():
		wasteland.queue_free()
		await _settle_frames(2)
		return
	var enemy := enemies[0]
	player.global_position = Vector2(720, 720)
	enemy.global_position = player.global_position + Vector2(34, 0)
	enemy.hp = 1
	player.last_direction = Vector2.RIGHT
	var defeated_before := GameState.defeated_enemies
	await _tap_action("attack_melee")
	await _settle_seconds(0.24)
	_expect(GameState.defeated_enemies == defeated_before + 1, "wasteland: melee input defeats nearby enemy")
	var ammo_before := GameState.ammo
	await _tap_action("attack_ranged")
	await _settle_frames(2)
	_expect(GameState.ammo == ammo_before - 1, "wasteland: ranged input consumes ammo")
	if not pools.is_empty():
		_expect(int(pools[0].active_count) >= 1, "wasteland: ranged input spawns projectile")
	var saved := SaveManager.save_game(false, qa_save_path)
	var loaded := _load_save_without_scene_change()
	_expect(saved and loaded, "wasteland: save/load works after combat input")
	_record_snapshot("wasteland", {
		"enemy_count": enemies.size(),
		"ammo_after_ranged": GameState.ammo,
		"projectiles": int(pools[0].active_count) if not pools.is_empty() else 0,
		"position": _vector_to_data(player.global_position)
	})
	wasteland.queue_free()
	await _settle_frames(2)

func _play_story_site_interaction_flow() -> void:
	for route_id in ["ruined_metropolis", "underground_facility"]:
		GameState.reset_new_run(false)
		var quest_id := "metropolis_archive" if route_id == "ruined_metropolis" else "facility_memory"
		GameState.current_scene_id = "wasteland"
		GameState.set_current_route(route_id)
		var wasteland := WASTELAND_SCENE.instantiate()
		add_child(wasteland)
		await _settle_frames(4)
		var player := _first_group_node("player") as Node2D
		var story_events: Array[Dictionary] = DataRegistry.story_events_for_route(route_id)
		var site: Area2D
		var event_id := ""
		if story_events.size() == 1:
			event_id = String(story_events[0].get("id", ""))
			var expected_id := "event:%s:%s" % [route_id, event_id]
			for story_site in get_tree().get_nodes_in_group("story_site"):
				if String(story_site.get_meta("story_event_id", "")) != event_id:
					continue
				for child in story_site.get_children():
					if child is Area2D and String(child.get("interaction_id")) == expected_id:
						site = child as Area2D
						break
				if site != null:
					break
		_expect(player != null, "story site: player exists on " + route_id)
		_expect(story_events.size() == 1, "story site: campaign event resolves on " + route_id)
		_expect(site != null, "story site: event is an interactable POI on " + route_id)
		if player != null and site != null:
			player.global_position = site.global_position
			for _frame in range(8):
				await get_tree().physics_frame
				await get_tree().process_frame
				if site.can_interact():
					break
			var overlapping_bodies := site.get_overlapping_bodies()
			var player_body := player as PhysicsBody2D
			var player_collision := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
			var physics_details := "distance=%.1f area_mask=%d player_layer=%d shape=%s" % [
				site.global_position.distance_to(player.global_position),
				site.collision_mask,
				player_body.collision_layer if player_body != null else 0,
				str(player_collision.shape) if player_collision != null else "missing"
			]
			_expect(overlapping_bodies.has(player), "story site: Area2D physically detects the player on %s (%s)" % [route_id, physics_details])
			_expect(site.can_interact(), "story site: proximity activates interaction on %s (%s)" % [route_id, physics_details])
			_expect(not GameState.is_quest_available(quest_id), "story site: campaign chapter is locked before its prerequisites on " + route_id)
			var locked_story_target: Node2D = player.get_nearest_interaction_target() if player.has_method("get_nearest_interaction_target") else null
			_expect(locked_story_target == site, "story site: locked clue remains the normal E target on " + route_id)
			await _tap_action("interact")
			_expect(not GameState.has_story_discovery(route_id, event_id), "story site: locked discovery is not recorded on " + route_id)
			if route_id == "ruined_metropolis":
				GameState.completed_quests.append_array([
					"clear_scrap_route",
					"toxic_sample",
					"crystal_scar_recon",
					"old_factory_core"
				])
			else:
				GameState.completed_quests.append_array([
					"clear_scrap_route",
					"toxic_sample",
					"crystal_scar_recon",
					"old_factory_core",
					"metropolis_archive"
				])
			_expect(GameState.is_quest_available(quest_id), "story site: chapter unlocks after its prerequisites on " + route_id)
			var unlocked_story_target: Node2D = player.get_nearest_interaction_target() if player.has_method("get_nearest_interaction_target") else null
			_expect(site.can_interact() and unlocked_story_target == site, "story site: unread clue remains the normal E target after unlock on " + route_id)
			await _tap_action("interact")
			_expect(GameState.has_story_discovery(route_id, event_id), "story site: unlocked E interaction records discovery on " + route_id)
			var saved := SaveManager.save_game(false, qa_save_path)
			GameState.reset_new_run(false)
			var loaded := SaveManager.load_game(false, false, qa_save_path)
			_expect(saved and loaded and GameState.has_story_discovery(route_id, event_id), "story site: discovery survives save/load on " + route_id)
			_record_snapshot("story_site_" + route_id, {
				"event_id": event_id,
				"discovered": GameState.has_story_discovery(route_id, event_id),
				"summary": GameState.get_story_summary()
			})
		wasteland.queue_free()
		await _settle_frames(2)

func _play_story_campaign_target_separation_flow() -> void:
	var route_cases: Array[Dictionary] = [
		{
			"route": "toxic_marsh",
			"quest": "toxic_sample",
			"outing_index": 1,
			"completed": ["clear_scrap_route"],
			"story_unlocked": true,
			"actions": {"ch2a_sample_upper": "done", "ch2a_sample_return": "done"}
		},
		{
			"route": "crystal_scar",
			"quest": "crystal_scar_recon",
			"outing_index": 0,
			"completed": ["clear_scrap_route", "toxic_sample"],
			"story_unlocked": true,
			"actions": {}
		},
		{
			"route": "old_factory",
			"quest": "old_factory_core",
			"outing_index": 0,
			"completed": ["clear_scrap_route", "toxic_sample", "crystal_scar_recon"],
			"story_unlocked": true,
			"actions": {}
		},
		{
			"route": "ruined_metropolis",
			"quest": "metropolis_archive",
			"outing_index": 0,
			"completed": ["clear_scrap_route", "toxic_sample", "crystal_scar_recon"],
			"story_unlocked": false,
			"actions": {}
		},
		{
			"route": "underground_facility",
			"quest": "facility_memory",
			"outing_index": 0,
			"completed": ["clear_scrap_route", "toxic_sample", "crystal_scar_recon", "old_factory_core"],
			"story_unlocked": false,
			"actions": {}
		}
	]
	for test_case: Dictionary in route_cases:
		var route_id := String(test_case["route"])
		var quest_id := String(test_case["quest"])
		GameState.reset_new_run(false)
		GameState.completed_quests.append_array(test_case["completed"])
		GameState.active_quest_id = quest_id
		GameState.quest_progress["campaign"] = {
			"version": 1,
			"outing_index": int(test_case["outing_index"]),
			"actions": test_case["actions"].duplicate(true)
		}
		GameState.current_scene_id = "wasteland"
		GameState.set_current_route(route_id)
		var wasteland := WASTELAND_SCENE.instantiate()
		add_child(wasteland)
		await _settle_frames(4)

		var player := wasteland.get("player") as Node2D
		var story_events: Array[Dictionary] = DataRegistry.story_events_for_route(route_id)
		var story_event_id := String(story_events[0].get("id", "")) if story_events.size() == 1 else ""
		var expected_story_unlocked := bool(test_case["story_unlocked"])
		var story_target: Area2D
		var campaign_action: Node2D
		var outing: Dictionary = GameState.campaign_outing()
		var actions: Array = outing.get("actions", [])
		var first_action_id := String(actions[0].get("id", "")) if not actions.is_empty() and actions[0] is Dictionary else ""
		for site_node: Node in get_tree().get_nodes_in_group("story_site"):
			if not wasteland.is_ancestor_of(site_node) or String(site_node.get_meta("story_event_id", "")) != story_event_id:
				continue
			for child: Node in site_node.get_children():
				if child is Area2D and String(child.get("interaction_id")) == "event:%s:%s" % [route_id, story_event_id]:
					story_target = child as Area2D
					break
			if story_target != null:
				break
		for action_node: Node in get_tree().get_nodes_in_group("campaign_action"):
			if wasteland.is_ancestor_of(action_node) and String(action_node.get("action_id")) == first_action_id:
				campaign_action = action_node as Node2D
				break

		_expect(player != null, "story/campaign E targets: active player exists on " + route_id)
		_expect(story_events.size() == 1 and story_target != null, "story/campaign E targets: clue remains an interactable target on " + route_id)
		_expect(not first_action_id.is_empty() and campaign_action != null, "story/campaign E targets: first campaign action exists on " + route_id)
		if player != null and story_target != null and campaign_action != null:
			var story_radius := float(story_target.get("radius"))
			var action_radius := float(campaign_action.get("_radius"))
			var separation := story_target.global_position.distance_to(campaign_action.global_position)
			_expect(separation > story_radius + action_radius, "story/campaign E targets: approach ranges do not overlap on %s (distance=%.1f story=%.1f action=%.1f)" % [route_id, separation, story_radius, action_radius])
			_expect(GameState.is_story_event_unlocked(story_event_id) == expected_story_unlocked, "story/campaign E targets: authored clue lock state is preserved on " + route_id)
			_expect(not GameState.has_story_discovery(route_id, story_event_id), "story/campaign E targets: story clue is still unread before campaign E on " + route_id)

			player.global_position = campaign_action.global_position
			for _frame in range(8):
				await get_tree().physics_frame
				await get_tree().process_frame
				if campaign_action.can_interact():
					break
			var action_target: Node2D = player.get_nearest_interaction_target() if player.has_method("get_nearest_interaction_target") else null
			_expect(campaign_action.can_interact(), "story/campaign E targets: campaign action enters E range on " + route_id)
			_expect(not story_target.can_interact(), "story/campaign E targets: clue is outside the campaign approach range on " + route_id)
			_expect(action_target == campaign_action, "story/campaign E targets: campaign action is selected at its approach on " + route_id)
			await _tap_action("interact")
			var action_progress: Dictionary = GameState.campaign_action_progress(first_action_id)
			var choice_state := GameState.campaign_choice_state()
			var action_started := bool(action_progress.get("started", false))
			if String(campaign_action.get("action_type")) == "choice":
				action_started = action_started and String(choice_state.get("action_id", "")) == first_action_id
			_expect(action_started, "story/campaign E targets: normal E starts the first campaign action while the clue is unread on " + route_id)
			if String(campaign_action.get("action_type")) == "choice":
				await _tap_key(KEY_ESCAPE)
				await _settle_frames(2)

			player.global_position = story_target.global_position
			for _frame in range(8):
				await get_tree().physics_frame
				await get_tree().process_frame
				if story_target.can_interact():
					break
			var story_selection: Node2D = player.get_nearest_interaction_target() if player.has_method("get_nearest_interaction_target") else null
			_expect(story_target.can_interact(), "story/campaign E targets: story clue remains E reachable after action starts on " + route_id)
			_expect(not campaign_action.can_interact(), "story/campaign E targets: campaign action is outside the clue approach range on " + route_id)
			_expect(story_selection == story_target, "story/campaign E targets: clue is selected at its separate approach on " + route_id)
			await _tap_action("interact")
			_expect(GameState.has_story_discovery(route_id, story_event_id) == expected_story_unlocked, "story/campaign E targets: normal E reads an unlocked clue or preserves the lock on " + route_id)
		wasteland.queue_free()
		await _settle_frames(2)

func _play_story_boss_spawn_flow() -> void:
	var threshold := int(DataRegistry.map_params.get("boss_spawn_after_defeats", 40))
	GameState.reset_new_run(false)
	GameState.current_scene_id = "wasteland"
	GameState.set_current_route("old_factory")
	var free_roam := WASTELAND_SCENE.instantiate()
	add_child(free_roam)
	await _settle_frames(4)
	_expect(get_tree().get_nodes_in_group("boss").is_empty(), "boss route: free exploration does not spawn before its defeat threshold")
	GameState.defeated_enemies = maxi(0, threshold - 1)
	await _settle_seconds(0.25)
	_expect(get_tree().get_nodes_in_group("boss").is_empty(), "boss route: free exploration stays locked one defeat below threshold")
	GameState.defeated_enemies = threshold
	await _settle_seconds(0.25)
	_expect(not get_tree().get_nodes_in_group("boss").is_empty(), "boss route: free exploration spawns at the existing defeat threshold")
	free_roam.queue_free()
	await _settle_frames(2)

	var quest_cases := [
		{
			"route": "old_factory",
			"quest": "old_factory_core",
			"prerequisites": ["clear_scrap_route", "toxic_sample", "crystal_scar_recon"]
		},
		{
			"route": "underground_facility",
			"quest": "facility_memory",
			"prerequisites": ["clear_scrap_route", "toxic_sample", "crystal_scar_recon", "old_factory_core", "metropolis_archive"]
		}
	]
	for test_case: Dictionary in quest_cases:
		var route_id: String = test_case["route"]
		var quest_id: String = test_case["quest"]
		GameState.reset_new_run(false)
		GameState.current_scene_id = "guild"
		GameState.completed_quests.append_array(test_case["prerequisites"])
		var started := GameState.start_quest(quest_id)
		_expect(started, "story boss: campaign quest starts on " + route_id)
		GameState.current_scene_id = "wasteland"
		GameState.set_current_route(route_id)
		var wasteland := WASTELAND_SCENE.instantiate()
		add_child(wasteland)
		await _settle_frames(4)
		_expect(GameState.defeated_enemies < threshold, "story boss: quest fixture remains below the free-roam threshold on " + route_id)
		_expect(not get_tree().get_nodes_in_group("boss").is_empty(), "story boss: active " + quest_id + " spawns its boss on " + route_id)
		wasteland.queue_free()
		await _settle_frames(2)

func _load_save_without_scene_change() -> bool:
	return SaveManager.load_game(false, false, qa_save_path)

func _record_snapshot(id: String, data: Dictionary) -> void:
	report.snapshots[id] = data

func _write_report() -> void:
	report["passed"] = failures.is_empty()
	report["failure_count"] = failures.size()
	report["failures"] = failures.duplicate()
	var report_path := "user://qa_reports/automated_playtest_report.json"
	if not qa_output_dir.is_empty():
		if not DirAccess.dir_exists_absolute(qa_output_dir):
			var make_dir_error := DirAccess.make_dir_recursive_absolute(qa_output_dir)
			if make_dir_error != OK:
				_record_report_failure("playtest report output directory can be created: " + str(make_dir_error))
				return
		report_path = qa_output_dir.path_join("automated_playtest_report.json")
	else:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://qa_reports"))
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
		file.flush()
		if file.get_error() != OK:
			_record_report_failure("playtest report can be written: " + str(file.get_error()))
			return
		print("[PLAYTEST] Report written: " + report_path)
	else:
		_record_report_failure("playtest report can be opened: " + report_path)

func _record_report_failure(label: String) -> void:
	failures.append(label)
	report["passed"] = false
	report["failure_count"] = failures.size()
	report["failures"] = failures.duplicate()
	push_error("[FAIL] " + label)

func _expect(condition: bool, label: String) -> void:
	report.checks.append({
		"label": label,
		"passed": condition
	})
	if condition:
		print("[PASS] " + label)
	else:
		failures.append(label)
		push_error("[FAIL] " + label)

func _first_group_node(group_name: String) -> Node:
	var nodes := get_tree().get_nodes_in_group(group_name)
	return nodes[0] if not nodes.is_empty() else null

func _first_node_by_name(root: Node, node_name: String) -> Node:
	if root.name == node_name:
		return root
	for child in root.get_children():
		var found := _first_node_by_name(child, node_name)
		if found != null:
			return found
	return null

func _vector_to_data(value: Vector2) -> Dictionary:
	return {
		"x": value.x,
		"y": value.y
	}

func _settle_frames(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame

func _settle_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _tap_action(action_name: String) -> void:
	Input.action_release(action_name)
	await get_tree().process_frame
	Input.action_press(action_name)
	await get_tree().process_frame
	await get_tree().physics_frame
	Input.action_release(action_name)
	await get_tree().process_frame

func _tap_key(keycode: int) -> void:
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

func _activate_button(button: Button) -> void:
	if button == null or button.disabled or not button.is_visible_in_tree():
		return
	button.grab_focus()
	await get_tree().process_frame
	await _tap_key(KEY_ENTER)
	await get_tree().process_frame

func _control_fits_scroll(scroll: ScrollContainer, control: Control) -> bool:
	if scroll == null or control == null:
		return false
	return scroll.get_global_rect().grow(-1.0).encloses(control.get_global_rect())

func _finish() -> void:
	if failures.is_empty():
		print("[PLAYTEST] Automated playtest passed")
		get_tree().quit(0)
	else:
		print("[PLAYTEST] Automated playtest failed: %s" % JSON.stringify(failures))
		get_tree().quit(1)

func _read_user_arg(option: String, fallback: String) -> String:
	var args := OS.get_cmdline_user_args()
	for index in range(args.size() - 1):
		if args[index] == option:
			return String(args[index + 1])
	return fallback
