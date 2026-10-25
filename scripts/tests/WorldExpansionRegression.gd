extends RefCounted

const WASTELAND_SCENE := preload("res://scenes/levels/wasteland/Wasteland.tscn")
const SAVE_PATH := "user://qa/world_expansion_save.json"

var checks: Array[Dictionary] = []
var failures: Array[String] = []


func run(parent: Node) -> Dictionary:
	var previous_save_path: String = SaveManager.default_save_path
	var previous_state := GameState.get_save_data().duplicate(true)
	SaveManager.default_save_path = SAVE_PATH
	for route_id in DataRegistry.wasteland_routes:
		await _check_route(parent, String(route_id))
	SaveManager.default_save_path = previous_save_path
	GameState.load_save_data(previous_state)
	return {"checks": checks, "failures": failures}


func _check_route(parent: Node, route_id: String) -> void:
	GameState.reset_new_run(false)
	GameState.current_scene_id = "wasteland"
	GameState.current_route_id = route_id
	GameState.active_spawn_point = "default"
	GameState.begin_expedition()
	var world := WASTELAND_SCENE.instantiate() as Node2D
	parent.add_child(world)
	world.set_process(false)
	_freeze_actors(parent)
	await parent.get_tree().process_frame
	await parent.get_tree().physics_frame
	var player := world.get("player") as CharacterBody2D
	var route: Dictionary = DataRegistry.get_wasteland_route(route_id)
	var world_size: Vector2 = world.get("world_size")
	var configured_size: Array = route.get("size_tiles", [])
	_expect(configured_size.size() == 2 and world_size == Vector2(float(configured_size[0]), float(configured_size[1])) * 32.0 and world_size.x * world_size.y > 5760.0 * 4480.0, route_id + ": authored world is larger than the original shared extent")
	var points: Array = world.get("_exploration_points")
	_expect(points.size() == 3 and parent.get_tree().get_nodes_in_group("exploration_point").size() == 3, route_id + ": three authored exploration sites exist")
	_expect(parent.get_tree().get_nodes_in_group("story_site").size() == 1, route_id + ": campaign site is preserved")
	_expect(_paths_are_clear(world, player), route_id + ": authored road centerlines have no static obstacle collisions")
	for point: Dictionary in points:
		await _check_point(parent, world, player, point, route_id)
	var items_before_reload := _snapshot_items()
	var saved := SaveManager.save_game(false)
	world.queue_free()
	await parent.get_tree().process_frame
	await parent.get_tree().physics_frame
	GameState.reset_new_run(false)
	var loaded := SaveManager.load_game(false, false)
	_expect(saved and loaded and _items_equal(_snapshot_items(), items_before_reload), route_id + ": exploration rewards survive real wrapped save and reload")
	world = WASTELAND_SCENE.instantiate()
	parent.add_child(world)
	world.set_process(false)
	_freeze_actors(parent)
	await parent.get_tree().process_frame
	await parent.get_tree().physics_frame
	points = world.get("_exploration_points")
	for point: Dictionary in points:
		var items_before_repeat := _snapshot_items()
		world.call("_on_exploration_interacted", "exploration:" + String(point["event"]))
		_expect(bool(world.call("_exploration_point_claimed", point)) and point["guard_nodes"].is_empty() and _items_equal(_snapshot_items(), items_before_repeat), route_id + ": loaded site cannot respawn guards or grant rewards twice: " + String(point["event"]))
	world.queue_free()
	await parent.get_tree().process_frame
	await parent.get_tree().physics_frame


func _check_point(parent: Node, world: Node2D, player: CharacterBody2D, point: Dictionary, route_id: String) -> void:
	var label := route_id + ": " + String(point["event"])
	var center: Vector2 = point["world_position"]
	var approach := center + Vector2(0, 48)
	_expect(_position_is_clear(world, player, approach), label + " reward has a clear walk-up position")
	player.global_position = approach
	GameState.player_position = approach
	player.move_and_collide(Vector2.ZERO)
	await parent.get_tree().physics_frame
	await parent.get_tree().physics_frame
	var area := point["interactable_node"] as Area2D
	if not area.can_interact() and player.global_position.distance_to(area.global_position) <= area.radius:
		area._on_body_entered(player)
	var items_before := _snapshot_items()
	_expect(area.can_interact(), label + " is reachable through the real interaction area")
	area.interact()
	var guards: Array = point["guard_nodes"]
	_expect(bool(point["active"]) and guards.size() == 3 and _items_equal(_snapshot_items(), items_before) and not bool(point["cleared"]), label + " starts three guards and denies reward before the fight")
	_expect(parent.get_tree().get_nodes_in_group("enemy").size() <= 50, label + " encounter stays within the shared enemy cap")
	for guard in guards:
		guard.set_physics_process(false)
		guard.drop_table = {}
		guard.rare_drop_table = {}
		guard.take_damage(int(guard.hp))
	var items_after_combat := _snapshot_items()
	world.call("_refresh_exploration_points")
	GameState.death_pending = true
	area.interact()
	_expect(_items_equal(_snapshot_items(), items_after_combat) and not GameState.has_field_claim(String(point["discovery_key"])), label + " cannot claim rewards during death recovery")
	GameState.death_pending = false
	GameState.current_route_id = "not_this_route"
	world.call("_on_exploration_interacted", "exploration:" + String(point["event"]))
	_expect(_items_equal(_snapshot_items(), items_after_combat), label + " stale route callback cannot grant rewards")
	GameState.current_route_id = route_id
	area.interact()
	var expected_items := items_after_combat.duplicate(true)
	var rewards: Dictionary = point.get("reward", {})
	for item_id in rewards:
		expected_items[item_id] = int(expected_items.get(item_id, 0)) + int(rewards[item_id])
	_expect(bool(point["cleared"]) and _items_equal(_snapshot_items(), expected_items) and GameState.has_field_claim(String(point["discovery_key"])), label + " grants its exact authored reward only after all guards die")
	var items_after_first_claim := _snapshot_items()
	area.interact()
	_expect(_items_equal(_snapshot_items(), items_after_first_claim), label + " repeated interaction cannot duplicate its reward")
	GameState.hp = GameState.get_max_hp()
	GameState.death_pending = false


func _freeze_actors(parent: Node) -> void:
	for group in ["enemy", "player"]:
		for actor in parent.get_tree().get_nodes_in_group(group):
			actor.set_physics_process(false)


func _paths_are_clear(world: Node2D, player: CharacterBody2D) -> bool:
	var paths: Array = world.get_meta("map_paths", [])
	for path_index in range(paths.size()):
		var path: PackedVector2Array = paths[path_index]
		for index in range(1, path.size()):
			var a: Vector2 = path[index - 1]
			var b: Vector2 = path[index]
			var steps := maxi(1, ceili(a.distance_to(b) / 72.0))
			for step in range(steps + 1):
				var sample := a.lerp(b, float(step) / float(steps))
				var obstacle := _blocking_obstacle_at(world, player, sample)
				if obstacle != null:
					var obstacle_bounds := (obstacle as WorldProp).get_collision_bounds() if obstacle is WorldProp else Rect2()
					var player_shape := player.get_node("CollisionShape2D") as CollisionShape2D
					print("[WORLD] ROAD BLOCK path=%d segment=%d sample=%s obstacle=%s position=%s bounds=%s player_shape=%s player_shape_position=%s" % [path_index, index - 1, str(sample), String(obstacle.get_meta("map_label", obstacle.name)), str((obstacle as Node2D).global_position), str(obstacle_bounds), str(player_shape.shape), str(player_shape.global_position)])
					return false
	return true


func _position_is_clear(world: Node2D, player: CharacterBody2D, position: Vector2) -> bool:
	return _blocking_obstacle_at(world, player, position) == null


func _blocking_obstacle_at(world: Node2D, player: CharacterBody2D, position: Vector2) -> Node:
	var collision := player.get_node("CollisionShape2D") as CollisionShape2D
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = collision.shape
	query.transform = Transform2D(0.0, position + collision.position)
	query.exclude = [player.get_rid()]
	query.collide_with_areas = false
	for hit: Dictionary in world.get_world_2d().direct_space_state.intersect_shape(query, 32):
		var body := hit.get("collider") as Node
		if body != null and body.is_in_group("obstacle"):
			return body
	return null


func _expect(condition: bool, label: String) -> void:
	checks.append({"name": label, "passed": condition})
	if condition:
		print("[WORLD] PASS: ", label)
	else:
		failures.append(label)
		push_error("[WORLD] FAIL: " + label)


func _snapshot_items() -> Dictionary:
	var snapshot: Dictionary = {}
	for item_id in ["scrap", "ammo", "mutant_core", "bio_crystal", "alloy_plate", "broken_coil", "mutant_herb", "acid_sac", "amethyst_gem", "precision_chip", "dynamo_core", "terminal_controller"]:
		snapshot[item_id] = GameState.quest_item_count(item_id)
	return snapshot


func _items_equal(a: Dictionary, b: Dictionary) -> bool:
	for item_id in a:
		if int(a[item_id]) != int(b.get(item_id, 0)):
			return false
	for item_id in b:
		if int(b[item_id]) != int(a.get(item_id, 0)):
			return false
	return true
