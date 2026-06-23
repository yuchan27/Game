extends Node

const VILLAGE_SCENE := preload("res://scenes/levels/village/Village.tscn")
const WASTELAND_SCENE := preload("res://scenes/levels/wasteland/Wasteland.tscn")
const GUILD_SCENE := preload("res://scenes/levels/guild/Guild.tscn")
const ENEMY_SCRIPT := preload("res://scripts/components/Enemy.gd")

var failures: Array[String] = []

func _ready() -> void:
	await get_tree().process_frame
	print("[VERIFY] Waste Recycler vertical slice verification started")
	DataRegistry.load_all()
	_check_data_registry()
	_check_enemy_behavior_contract()
	_check_baked_assets()
	_check_export_presets()
	await _check_scene("village", VILLAGE_SCENE, {
		"interactable": 7,
		"npc": 4,
		"player": 1
	})
	await _check_scene("wasteland", WASTELAND_SCENE, {
		"interactable": 5,
		"enemy": 30,
		"pickup": 42,
		"world_prop": 60,
		"obstacle": 40,
		"projectile_pool": 1,
		"player": 1
	})
	await _check_scene("guild", GUILD_SCENE, {
		"interactable": 3,
		"npc": 2,
		"player": 1
	})
	_check_save_roundtrip()
	_check_equipment_loop()
	_check_recipe_and_quest_loop()
	_check_npc_dialogue_loop()
	await _check_playable_core_loop()
	await _check_wasteland_prop_contract()
	await _check_wasteland_route_contract()
	await _check_enemy_projectile_damage()
	await _check_pc_controls()
	await _check_player_animation_contract()
	await _check_projectile_pool_limit()
	_finish()

func _check_data_registry() -> void:
	_expect(DataRegistry.equipment.size() >= 6, "equipment data has at least 6 entries")
	_expect(DataRegistry.resources.size() >= 4, "resource data has at least 4 entries")
	_expect(DataRegistry.enemies.size() >= 7, "enemy data has 6 enemy archetypes plus boss")
	_expect(DataRegistry.events.size() >= 4, "event data has random event pool")
	_expect(DataRegistry.recipes.size() >= 5, "recipe data has forge craft shop and mod loops")
	_expect(DataRegistry.quests.size() >= 2, "quest data has guild contracts")
	_expect(DataRegistry.npcs.size() >= 6, "npc data has village and guild dialogue characters")
	_expect(DataRegistry.wasteland_routes.size() >= 4, "wasteland has four route definitions")
	_expect(DataRegistry.visual_assets.size() >= 35, "visual asset manifest has formal art entries")
	_expect(int(DataRegistry.map_params.get("width_tiles", 0)) >= 100, "wasteland width is at least 100 tiles")
	_expect(int(DataRegistry.map_params.get("height_tiles", 0)) >= 80, "wasteland height is at least 80 tiles")
	_expect(int(DataRegistry.map_params.get("prop_nodes", 0)) >= 60, "wasteland has enough pseudo-3D props configured")

func _check_enemy_behavior_contract() -> void:
	var required_patterns := {
		"scrap_biter": "chase_and_bite",
		"toxic_runner": "dash_strike",
		"spore_gunner": "keep_distance_projectile",
		"rust_brute": "slow_wide_melee",
		"rot_wing": "orbiting_melee",
		"mech_husk": "mixed_melee_projectile",
		"waste_titan": "boss_stomp_and_core_barrage"
	}
	for enemy_id in required_patterns.keys():
		var data := DataRegistry.get_enemy(String(enemy_id))
		_expect(String(data.get("attack_pattern", "")) == String(required_patterns[enemy_id]), "enemy has attack pattern: " + String(enemy_id))
		var enemy: WastelandEnemy = ENEMY_SCRIPT.new()
		enemy.setup(String(enemy_id), data, null)
		var summary := enemy.behavior_summary()
		if String(summary.get("type", "")) in ["ranged", "hybrid"]:
			_expect(bool(summary.get("can_fire_projectiles", false)), "enemy can fire projectiles: " + String(enemy_id))
			_expect(float(summary.get("ranged_range", 0.0)) > 250.0, "enemy has ranged attack distance: " + String(enemy_id))
		if String(summary.get("type", "")) == "fast":
			_expect(float(summary.get("contact_range", 0.0)) <= 38.0, "fast enemy uses close dash contact range")
		if String(summary.get("type", "")) == "heavy":
			_expect(float(summary.get("contact_range", 0.0)) >= 56.0, "heavy enemy has wider melee range")
		if String(summary.get("type", "")) == "boss":
			_expect(bool(summary.get("can_fire_projectiles", false)), "boss can fire projectile pressure")
			_expect(float(summary.get("contact_range", 0.0)) >= 70.0, "boss has wide stomp range")
		enemy.free()

func _check_baked_assets() -> void:
	_expect_png_size("res://assets/sprites/player/recycler_player_multiaction_8dir.png", Vector2i(8064, 1024), "baked full-body R-17 player atlas exists at 9 actions x 8 directions x 8 frames")
	_expect_png_size("res://assets/sprites/player/frames/walk/dir_0/frame_0.png", Vector2i(112, 128), "R-17 split walk frame exists for right direction")
	_expect_png_size("res://assets/sprites/player/frames/shoot/dir_4/frame_7.png", Vector2i(112, 128), "R-17 split shoot frame exists for left direction")
	_expect_png_size("res://assets/sprites/player/actions/walk.png", Vector2i(896, 1024), "R-17 per-action walk sheet exists for review")
	_expect_png_size("res://assets/sprites/enemies/polluted_enemy_six_types.png", Vector2i(672, 72), "baked enemy atlas has 6 enemy types plus boss")
	_expect_png_size("res://assets/sprites/items/recycler_item_icons.png", Vector2i(352, 72), "baked high-detail item icon atlas has 4 resource icons")
	_expect_png_size("res://assets/sprites/tiles/recycler_tileset.png", Vector2i(192, 32), "baked terrain tileset has village and wasteland tiles")

func _check_export_presets() -> void:
	var config := ConfigFile.new()
	var loaded := config.load("res://export_presets.cfg")
	_expect(loaded == OK, "export_presets.cfg loads")
	if loaded != OK:
		return
	_expect(String(config.get_value("preset.0", "name", "")) == "Windows Desktop", "Windows export preset exists")
	_expect(String(config.get_value("preset.0", "platform", "")) == "Windows Desktop", "Windows export preset platform is valid")
	_expect(String(config.get_value("preset.1", "name", "")) == "Android", "Android export preset exists")
	_expect(String(config.get_value("preset.1", "platform", "")) == "Android", "Android export preset platform is valid")

func _check_scene(scene_id: String, packed: PackedScene, group_minimums: Dictionary) -> void:
	GameState.reset_new_run(false)
	GameState.current_scene_id = scene_id
	var instance := packed.instantiate()
	add_child(instance)
	await get_tree().process_frame
	await get_tree().process_frame
	for group_name in group_minimums.keys():
		var count := get_tree().get_nodes_in_group(String(group_name)).size()
		_expect(count >= int(group_minimums[group_name]), "%s has %s >= %d" % [scene_id, group_name, int(group_minimums[group_name])])
	instance.queue_free()
	await get_tree().process_frame

func _check_save_roundtrip() -> void:
	GameState.reset_new_run(false)
	GameState.current_scene_id = "wasteland"
	GameState.start_quest("clear_scrap_route")
	GameState.advance_quest_counter("defeat_enemy", 2)
	GameState.player_position = Vector2(321, 654)
	GameState.add_item("scrap", 12)
	GameState.add_item("spark_cutter", 1)
	GameState.equip_item("spark_cutter")
	GameState.talk_to_npc("repair_robot")
	var before := GameState.get_save_data()
	var saved := SaveManager.save_game()
	GameState.reset_new_run(false)
	var loaded := _load_save_without_scene_change()
	var after := GameState.get_save_data()
	_expect(saved, "save manager writes save_game.json")
	_expect(loaded, "save manager loads save_game.json")
	_expect(String(after.get("scene", "")) == String(before.get("scene", "")), "save roundtrip restores scene")
	_expect(Vector2(float(after.player.position_x), float(after.player.position_y)) == Vector2(321, 654), "save roundtrip restores player position")
	_expect(String(after.equipment.weapon) == "spark_cutter", "save roundtrip restores equipped weapon")
	_expect(String(after.get("active_quest_id", "")) == "clear_scrap_route", "save roundtrip restores active quest")
	_expect(int(after.get("quest_progress", {}).get("defeat_enemy", 0)) == 2, "save roundtrip restores quest progress")
	_expect(String(after.get("quick_slots", [])[0]) == "spark_cutter", "save roundtrip restores quick slot equipment")
	_expect(after.get("talked_npcs", []).has("repair_robot"), "save roundtrip restores talked NPC state")

func _load_save_without_scene_change() -> bool:
	if not FileAccess.file_exists("user://save_game.json"):
		return false
	var file := FileAccess.open("user://save_game.json", FileAccess.READ)
	var wrapped = JSON.parse_string(file.get_as_text())
	if typeof(wrapped) != TYPE_DICTIONARY:
		return false
	var payload_text := Marshalls.base64_to_utf8(String(wrapped.get("payload", "")))
	if payload_text.sha256_text() != String(wrapped.get("checksum", "")):
		return false
	var data = JSON.parse_string(payload_text)
	if typeof(data) != TYPE_DICTIONARY:
		return false
	return GameState.load_save_data(data)

func _check_equipment_loop() -> void:
	GameState.reset_new_run(false)
	_expect(GameState.consume_item("scrap", 8), "scrap can be consumed for forging")
	GameState.add_item("ammo", 12)
	_expect(GameState.spend_ammo(1), "ranged attack consumes ammo")
	GameState.add_item("spark_cutter", 1)
	_expect(GameState.equip_item("spark_cutter"), "crafted melee weapon can be equipped")
	_expect(GameState.get_stat_bonus("attack") >= 15, "equipment stat bonus updates attack")

func _check_recipe_and_quest_loop() -> void:
	GameState.reset_new_run(false)
	_expect(DataRegistry.get_recipe("ammo_pack").size() > 0, "ammo recipe can be read")
	var ammo_before := GameState.ammo
	_expect(InventorySystem.forge_ammo_pack(), "forge station recipe crafts ammo pack")
	_expect(GameState.ammo == ammo_before + 12, "forge recipe increases ammo")
	GameState.add_item("bio_crystal", 1)
	_expect(InventorySystem.craft_basic_upgrade(), "craft station recipe creates spark cutter")
	_expect(GameState.inventory.has("spark_cutter"), "crafted weapon enters inventory")
	_expect(GameState.start_quest("clear_scrap_route"), "guild can start a quest")
	for i in range(5):
		GameState.record_enemy_defeated()
	GameState.add_item("scrap", 12)
	_expect(GameState.is_active_quest_ready(), "quest becomes ready after defeat and collect objectives")
	var cores_before := GameState.cores
	_expect(GameState.complete_active_quest(), "guild reward completes active quest")
	_expect(GameState.active_quest_id.is_empty(), "completed quest clears active quest")
	_expect(GameState.completed_quests.has("clear_scrap_route"), "completed quest is recorded")
	_expect(GameState.cores == cores_before + 1, "quest reward grants mutant core")

func _check_npc_dialogue_loop() -> void:
	GameState.reset_new_run(false)
	var ammo_before := GameState.ammo
	_expect(GameState.talk_to_npc("forge_master"), "npc dialogue can be triggered")
	_expect(GameState.talked_npcs.has("forge_master"), "npc dialogue marks first talk")
	_expect(GameState.ammo == ammo_before + 3, "npc first talk grants reward")
	_expect(GameState.talk_to_npc("forge_master"), "npc repeat dialogue can be triggered")
	_expect(GameState.ammo == ammo_before + 3, "npc repeat dialogue does not duplicate reward")

func _check_playable_core_loop() -> void:
	GameState.reset_new_run(false)
	GameState.current_scene_id = "wasteland"
	var instance := WASTELAND_SCENE.instantiate()
	add_child(instance)
	await get_tree().process_frame
	await get_tree().process_frame
	var players := get_tree().get_nodes_in_group("player")
	var enemies := get_tree().get_nodes_in_group("enemy")
	var pickups_before := get_tree().get_nodes_in_group("pickup").size()
	_expect(not players.is_empty(), "playable loop has player")
	_expect(not enemies.is_empty(), "playable loop has enemy")
	if players.is_empty() or enemies.is_empty():
		instance.queue_free()
		await get_tree().process_frame
		return
	var player := players[0]
	var enemy := enemies[0]
	player.global_position = Vector2(640, 640)
	enemy.global_position = player.global_position + Vector2(32, 0)
	enemy.hp = 1
	player.last_direction = Vector2.RIGHT
	var defeated_before := GameState.defeated_enemies
	player._melee_attack()
	await get_tree().create_timer(0.12).timeout
	_expect(GameState.defeated_enemies == defeated_before + 1, "playable loop melee defeats enemy")
	_expect(get_tree().get_nodes_in_group("pickup").size() >= pickups_before, "playable loop keeps or creates pickup resources")
	var ammo_before := GameState.ammo
	player.ranged_timer = 0.0
	player._ranged_attack()
	await get_tree().process_frame
	_expect(GameState.ammo == ammo_before - 1, "playable loop ranged attack consumes ammo")
	var pools := get_tree().get_nodes_in_group("projectile_pool")
	if not pools.is_empty():
		_expect(int(pools[0].active_count) >= 1, "playable loop ranged attack spawns projectile")
	GameState.player_position = player.global_position
	var saved := SaveManager.save_game()
	GameState.current_scene_id = "village"
	var loaded := _load_save_without_scene_change()
	_expect(saved and loaded, "playable loop can save and reload after combat")
	_expect(GameState.current_scene_id == "wasteland", "playable loop restores wasteland scene after reload")
	GameState.set_scene("village", "from_wasteland")
	_expect(GameState.current_scene_id == "village", "playable loop can return to village state")
	instance.queue_free()
	await get_tree().process_frame

func _check_wasteland_prop_contract() -> void:
	GameState.reset_new_run(false)
	GameState.current_scene_id = "wasteland"
	var instance := WASTELAND_SCENE.instantiate()
	add_child(instance)
	await get_tree().process_frame
	await get_tree().process_frame
	var props := get_tree().get_nodes_in_group("world_prop")
	var obstacles := get_tree().get_nodes_in_group("obstacle")
	_expect(props.size() >= int(DataRegistry.map_params.get("prop_nodes", 72)), "wasteland props spawn from seed")
	_expect(obstacles.size() >= 40, "wasteland blocking obstacles exist")
	if not props.is_empty():
		var prop := props[0]
		_expect(prop is Node2D and prop.y_sort_enabled, "wasteland props participate in Y-Sort")
	if not obstacles.is_empty():
		var obstacle := obstacles[0]
		_expect(_has_collision_shape(obstacle), "blocking obstacle has collision")
	instance.queue_free()
	await get_tree().process_frame

func _check_wasteland_route_contract() -> void:
	for route_id in ["scrap_highway", "toxic_marsh", "crystal_scar", "old_factory"]:
		GameState.reset_new_run(false)
		GameState.current_scene_id = "wasteland"
		GameState.set_current_route(route_id)
		var instance := WASTELAND_SCENE.instantiate()
		add_child(instance)
		await get_tree().process_frame
		await get_tree().process_frame
		var route := DataRegistry.get_wasteland_route(route_id)
		_expect(not route.is_empty(), "route data exists: " + route_id)
		_expect(get_tree().get_nodes_in_group("enemy").size() >= 30, "route has enemy pressure: " + route_id)
		_expect(get_tree().get_nodes_in_group("pickup").size() >= 42, "route has resources: " + route_id)
		if bool(route.get("boss_enabled", false)):
			_expect(get_tree().get_nodes_in_group("boss").size() >= 1, "boss route spawns boss: " + route_id)
		instance.queue_free()
		await get_tree().process_frame

func _check_enemy_projectile_damage() -> void:
	GameState.reset_new_run(false)
	GameState.current_scene_id = "wasteland"
	var instance := WASTELAND_SCENE.instantiate()
	add_child(instance)
	await get_tree().process_frame
	await get_tree().process_frame
	var players := get_tree().get_nodes_in_group("player")
	var pools := get_tree().get_nodes_in_group("projectile_pool")
	_expect(not players.is_empty(), "enemy projectile test has player")
	_expect(not pools.is_empty(), "enemy projectile test has pool")
	if players.is_empty() or pools.is_empty():
		instance.queue_free()
		await get_tree().process_frame
		return
	var player := players[0]
	var hp_before := GameState.hp
	var expected_damage: int = max(1, 9 - GameState.get_stat_bonus("defense"))
	var pool := pools[0]
	_expect(pool.fire_projectile(player.global_position - Vector2(28, 0), Vector2.RIGHT, 9, "player"), "enemy projectile can be fired at player group")
	await get_tree().process_frame
	var projectile = pool.pooled_projectiles[0] if pool.pooled_projectiles.size() > 0 else null
	_expect(projectile != null and String(projectile.target_group) == "player", "enemy projectile targets player group")
	if projectile != null:
		projectile._on_body_entered(player)
	_expect(GameState.hp == hp_before - expected_damage, "enemy projectile damages player after armor reduction")
	instance.queue_free()
	await get_tree().process_frame

func _check_pc_controls() -> void:
	GameState.reset_new_run(false)
	var instance := VILLAGE_SCENE.instantiate()
	add_child(instance)
	await get_tree().process_frame
	var required_actions: Array[String] = [
		"move_up",
		"move_down",
		"move_left",
		"move_right",
		"primary_attack",
		"attack_melee",
		"attack_ranged",
		"interact",
		"open_inventory",
		"save_game",
		"toggle_minimap",
		"toggle_help",
		"swap_weapon",
		"quick_slot_1",
		"quick_slot_2",
		"quick_slot_3",
		"quick_slot_4"
	]
	for action_name in required_actions:
		_expect(InputMap.has_action(action_name), "input action exists: " + action_name)
	var primary_has_left_click := false
	for event in InputMap.action_get_events("primary_attack"):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			primary_has_left_click = true
	var ranged_has_left_click := false
	for event in InputMap.action_get_events("attack_ranged"):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			ranged_has_left_click = true
	var melee_has_left_click := false
	for event in InputMap.action_get_events("attack_melee"):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			melee_has_left_click = true
	_expect(primary_has_left_click, "PC primary attack is bound to left mouse")
	_expect(not ranged_has_left_click, "PC ranged attack does not own left mouse")
	_expect(not melee_has_left_click, "PC melee attack does not share left mouse")
	_expect(GameState.active_attack_mode() == "melee", "left mouse uses melee when blade quick slot is active")
	GameState.use_quick_slot(1)
	_expect(GameState.active_attack_mode() == "ranged", "left mouse uses ranged when gun quick slot is active")
	var hotbar_slots := get_tree().get_nodes_in_group("hotbar_slot")
	var minimap_panels := get_tree().get_nodes_in_group("minimap_panel")
	var tutorial_panels := get_tree().get_nodes_in_group("tutorial_panel")
	var equipment_panels := get_tree().get_nodes_in_group("equipment_panel")
	var dialogue_panels := get_tree().get_nodes_in_group("dialogue_panel")
	var touch_buttons := get_tree().get_nodes_in_group("touch_control")
	_expect(hotbar_slots.size() >= 4, "PC HUD includes 4 quick slots")
	_expect(minimap_panels.size() >= 1, "PC HUD includes minimap panel")
	_expect(tutorial_panels.size() >= 1, "PC HUD includes tutorial panel")
	_expect(equipment_panels.size() >= 1, "PC HUD includes character equipment panel")
	_expect(dialogue_panels.size() >= 1, "PC HUD includes dialogue box")
	_expect(touch_buttons.is_empty(), "PC HUD does not show mobile touch buttons")
	var seen_quick_slots: Dictionary = {}
	for slot in hotbar_slots:
		if slot.has_meta("quick_slot_index"):
			seen_quick_slots[int(slot.get_meta("quick_slot_index"))] = true
	for i in range(4):
		_expect(seen_quick_slots.has(i), "quick slot exists: %d" % [i + 1])
	_expect(GameState.use_quick_slot(1), "quick slot can equip ranged item")
	_expect(GameState.active_quick_slot == 1, "quick slot updates active selection")
	_expect(GameState.use_next_quick_slot(), "swap weapon cycles quick slot")
	_expect(GameState.active_quick_slot == 2, "swap weapon selects next quick slot")
	instance.queue_free()
	await get_tree().process_frame

func _check_player_animation_contract() -> void:
	GameState.reset_new_run(false)
	var instance := VILLAGE_SCENE.instantiate()
	add_child(instance)
	await get_tree().process_frame
	var players := get_tree().get_nodes_in_group("player")
	_expect(not players.is_empty(), "player exists for animation contract")
	if not players.is_empty():
		var player := players[0]
		var animated_sprite := player.get_node_or_null("AnimatedSprite2D")
		_expect(animated_sprite is AnimatedSprite2D, "player uses AnimatedSprite2D")
		if animated_sprite is AnimatedSprite2D:
			var frame_set: SpriteFrames = animated_sprite.sprite_frames
			var actions: Array[String] = ["idle", "walk", "shoot", "draw_sword", "slash", "swap_tool", "interact", "hit", "dead"]
			for action_name in actions:
				for direction_index in range(8):
					var animation_name := "%s_%d" % [action_name, direction_index]
					_expect(frame_set.has_animation(animation_name), "player animation exists: " + animation_name)
					if frame_set.has_animation(animation_name):
						_expect(frame_set.get_frame_count(animation_name) >= 8, "player animation has 8-frame motion: " + animation_name)
			var first_frame := frame_set.get_frame_texture("idle_0", 0)
			_expect(first_frame is Texture2D, "player animation frames load as textures")
			_expect(not (first_frame is AtlasTexture), "player animation uses split PNG frames before atlas fallback")
		if player.has_method("_aim_direction_from_global_target") and player.has_method("_projectile_spawn_global") and player.has_method("_attack_anchor_global"):
			player.global_position = Vector2(400, 400)
			player.last_direction = Vector2.RIGHT
			var anchor: Vector2 = player._attack_anchor_global()
			var aim_right: Vector2 = player._aim_direction_from_global_target(anchor + Vector2(240, 0))
			var aim_down: Vector2 = player._aim_direction_from_global_target(anchor + Vector2(0, 240))
			var sprite_center: Vector2 = animated_sprite.global_position if animated_sprite is AnimatedSprite2D else player.global_position
			var right_hand_muzzle: Vector2 = player._projectile_spawn_global()
			player.last_direction = Vector2.LEFT
			var left_hand_muzzle: Vector2 = player._projectile_spawn_global()
			var aim_from_right_hand: Vector2 = player._aim_direction_from_origin(right_hand_muzzle + Vector2(-240, 0), right_hand_muzzle)
			_expect(aim_right.dot(Vector2.RIGHT) > 0.99, "player ranged aim uses muzzle anchor for right target")
			_expect(aim_down.dot(Vector2.DOWN) > 0.99, "player ranged aim uses muzzle anchor for down target")
			_expect(aim_from_right_hand.dot(Vector2.LEFT) > 0.99, "player ranged projectile aims from hand origin to target")
			_expect(right_hand_muzzle == sprite_center + Vector2(22, 20), "player projectile starts at raised right hand")
			_expect(left_hand_muzzle == sprite_center + Vector2(-22, 20), "player projectile starts at raised left hand")
	instance.queue_free()
	await get_tree().process_frame

func _check_projectile_pool_limit() -> void:
	GameState.reset_new_run(false)
	var instance := WASTELAND_SCENE.instantiate()
	add_child(instance)
	await get_tree().process_frame
	var pools := get_tree().get_nodes_in_group("projectile_pool")
	_expect(not pools.is_empty(), "projectile pool exists in wasteland")
	if not pools.is_empty():
		var pool := pools[0]
		_expect(int(pool.max_projectiles) == int(DataRegistry.map_params.get("projectile_limit", 200)), "projectile pool uses map projectile limit")
		var fired := 0
		for i in range(int(pool.max_projectiles) + 5):
			if pool.fire_projectile(Vector2(100, 100), Vector2.RIGHT, 1):
				fired += 1
		_expect(fired == int(pool.max_projectiles), "projectile pool blocks projectiles above limit")
		_expect(int(pool.active_count) == int(pool.max_projectiles), "projectile pool active count stays at limit")
	instance.queue_free()
	await get_tree().process_frame

func _expect(condition: bool, label: String) -> void:
	if condition:
		print("[PASS] " + label)
	else:
		failures.append(label)
		push_error("[FAIL] " + label)

func _has_collision_shape(node: Node) -> bool:
	for child in node.get_children():
		if child is CollisionShape2D:
			return true
	return false

func _expect_png_size(path: String, expected_size: Vector2i, label: String) -> void:
	_expect(FileAccess.file_exists(path), label + " file exists")
	if not FileAccess.file_exists(path):
		return
	var image := Image.load_from_file(path)
	_expect(image != null, label + " loads as Image")
	if image != null:
		_expect(image.get_size() == expected_size, "%s size is %s" % [label, expected_size])

func _finish() -> void:
	if failures.is_empty():
		print("[VERIFY] All vertical slice checks passed")
		get_tree().quit(0)
	else:
		print("[VERIFY] Failed checks: %s" % JSON.stringify(failures))
		get_tree().quit(1)
