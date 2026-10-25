extends Node

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const WASTELAND_SCENE := preload("res://scenes/levels/wasteland/Wasteland.tscn")
const VILLAGE_SCENE := preload("res://scenes/levels/village/Village.tscn")
const GUILD_SCENE := preload("res://scenes/levels/guild/Guild.tscn")
const PROJECTILE_POOL_SCRIPT := preload("res://scripts/systems/ProjectilePool.gd")
const ROUTE_IDS: Array[String] = ["scrap_highway", "toxic_marsh", "crystal_scar", "old_factory"]
const REPORT_FILENAME := "collision_regression_report.json"

var checks: Array[Dictionary] = []
var failures: Array[String] = []
var report_directory := ""


func _ready() -> void:
	_parse_user_arguments()
	GameState.reset_new_run(false)
	await _check_player_and_projectile_physics()
	for route_id: String in ROUTE_IDS:
		await _check_route_spawn_clearance(route_id)
	await _check_service_structure(VILLAGE_SCENE, "village", "structure_forge")
	await _check_service_structure(GUILD_SCENE, "guild", "structure_guild_gate")
	await _finish_report()


func _parse_user_arguments() -> void:
	var arguments := OS.get_cmdline_user_args()
	var index := 0
	while index < arguments.size():
		var argument: String = String(arguments[index])
		if argument == "--qa-output" and index + 1 < arguments.size():
			report_directory = String(arguments[index + 1])
			index += 2
		else:
			index += 1


func _check_player_and_projectile_physics() -> void:
	var fixture := Node2D.new()
	fixture.name = "CollisionPhysicsFixture"
	add_child(fixture)
	var player := PLAYER_SCENE.instantiate() as CharacterBody2D
	player.global_position = Vector2(64.0, 100.0)
	fixture.add_child(player)
	var player_collision := player.get_node("CollisionShape2D") as CollisionShape2D
	var capsule := player_collision.shape as CapsuleShape2D
	_expect(is_equal_approx(player_collision.position.y + capsule.height * 0.5, 0.0), "player collider bottom aligns with sprite feet")

	var wall := _make_wall(Vector2(150.0, 73.0), Vector2(20.0, 180.0))
	fixture.add_child(wall)
	Input.action_press("move_right")
	for _frame in range(60):
		await get_tree().physics_frame
	Input.action_release("move_right")
	_expect(player.global_position.x < 132.0, "player is blocked by a real static obstacle")

	wall.global_position = Vector2(90.0, 73.0)
	player.global_position = Vector2(160.0, 100.0)
	player.velocity = Vector2.ZERO
	await get_tree().physics_frame
	var projectile_pool := PROJECTILE_POOL_SCRIPT.new() as ProjectilePool
	fixture.add_child(projectile_pool)
	var hp_before_blocked_shot: int = GameState.hp
	var blocked_shot_started: bool = projectile_pool.fire_projectile(Vector2(32.0, 73.0), Vector2.RIGHT, 12, "player")
	for _frame in range(18):
		await get_tree().physics_frame
	_expect(blocked_shot_started and projectile_pool.active_count == 0, "projectile releases when it hits a static obstacle")
	_expect(GameState.hp == hp_before_blocked_shot, "obstacle blocks projectile damage to a target behind it")

	wall.queue_free()
	await get_tree().process_frame
	await get_tree().physics_frame
	var hp_before_clear_shot: int = GameState.hp
	var clear_shot_started: bool = projectile_pool.fire_projectile(Vector2(32.0, 73.0), Vector2.RIGHT, 12, "player")
	for _frame in range(24):
		await get_tree().physics_frame
	_expect(clear_shot_started and GameState.hp < hp_before_clear_shot, "projectile still damages a target when its path is clear")
	_expect(projectile_pool.active_count == 0, "projectile releases after hitting its intended target")
	fixture.queue_free()
	await get_tree().process_frame
	await get_tree().physics_frame


func _check_route_spawn_clearance(route_id: String) -> void:
	GameState.current_route_id = route_id
	GameState.active_spawn_point = "default"
	var wasteland := WASTELAND_SCENE.instantiate()
	add_child(wasteland)
	await get_tree().process_frame
	await get_tree().physics_frame
	var player: CharacterBody2D = wasteland.get("player") as CharacterBody2D
	var expected_landmark: String = String(DataRegistry.get_wasteland_route(route_id).get("landmark_prop", ""))
	var landmark: WorldProp
	var legacy_prop: WorldProp
	var blocking_nonblocking_mix_valid := true
	for raw_prop in get_tree().get_nodes_in_group("world_prop"):
		var prop := raw_prop as WorldProp
		if prop == null or not is_instance_valid(prop):
			continue
		if prop.prop_id == expected_landmark:
			landmark = prop
		if prop.prop_id == "scrap_wall":
			legacy_prop = prop
		if prop.prop_id in ["toxic_pool", "road_marker"] and (prop.blocks_movement or prop.is_in_group("obstacle")):
			blocking_nonblocking_mix_valid = false
	_expect(landmark != null, "%s creates its unique route landmark" % route_id)
	_expect(blocking_nonblocking_mix_valid, "%s keeps toxic pools and road markers nonblocking" % route_id)
	if landmark != null:
		var asset: Dictionary = DataRegistry.get_visual_asset("prop_%s" % expected_landmark)
		_expect(String(landmark.get_meta("map_label", "")) == String(asset.get("display_name", "")), "%s landmark uses its manifest display name" % route_id)
		_expect(_footprint_matches_sprite_transform(landmark, asset), "%s landmark collider follows the padded sprite artwork" % route_id)
		_expect(_shape_query_hits_prop(landmark), "%s landmark collider blocks movement in Physics2D" % route_id)
	_expect(legacy_prop != null and legacy_prop.blocks_movement and legacy_prop.is_in_group("obstacle"), "%s retains a blocking legacy prop" % route_id)
	if legacy_prop != null:
		_expect(_shape_query_hits_prop(legacy_prop), "%s legacy prop collider blocks movement in Physics2D" % route_id)

	if player != null:
		var collision := player.get_node("CollisionShape2D") as CollisionShape2D
		var player_query_hits: Array[Dictionary] = _intersect_shape(collision.shape, Transform2D(0.0, player.global_position + collision.position), player.get_rid())
		_expect(player_query_hits.is_empty(), "%s player spawn has no static-body overlap" % route_id)

	var lane_bounds: Rect2 = wasteland.call("_extraction_gate_bounds")
	var world_size: Vector2 = wasteland.get("world_size")
	var lane_clear := true
	for raw_prop in get_tree().get_nodes_in_group("world_prop"):
		var prop := raw_prop as WorldProp
		if prop != null and is_instance_valid(prop) and prop.get_visual_bounds().intersects(lane_bounds):
			lane_clear = false
	_expect(lane_clear, "%s keeps generated props out of the return lane" % route_id)
	var lane_physics_clear := true
	for y_offset: float in [-120.0, 0.0, 120.0]:
		var position := Vector2(lane_bounds.get_center().x, lane_bounds.get_center().y + y_offset)
		var hits: Array[Dictionary] = _intersect_shape(_rectangle_shape(Vector2(64.0, 64.0)), Transform2D(0.0, position), player.get_rid() if player != null else RID())
		if not hits.is_empty():
			lane_physics_clear = false
			break
	_expect(lane_physics_clear, "%s return route has no physics obstacle collision" % route_id)

	wasteland.queue_free()
	await get_tree().process_frame
	await get_tree().physics_frame


func _check_service_structure(scene: PackedScene, scene_id: String, expected_asset_id: String) -> void:
	GameState.current_scene_id = scene_id
	GameState.active_spawn_point = "default"
	var service_scene := scene.instantiate()
	add_child(service_scene)
	await get_tree().process_frame
	await get_tree().physics_frame
	var station: Node2D
	for raw_station in get_tree().get_nodes_in_group("map_station"):
		var candidate := raw_station as Node2D
		if candidate != null and is_instance_valid(candidate) and String(candidate.get_meta("structure_asset_id", "")) == expected_asset_id:
			station = candidate
			break
	_expect(station != null, "%s loads the chosen service structure" % scene_id)
	if station != null:
		var raw_collision: Variant = DataRegistry.get_visual_asset(expected_asset_id).get("collision", [])
		var body := station.get_node_or_null("StructureCollider") as StaticBody2D
		var collision := body.get_node_or_null("CollisionShape2D") as CollisionShape2D if body != null else null
		var authored_size: Vector2 = Vector2(float(raw_collision[0]), float(raw_collision[1])) if raw_collision is Array and raw_collision.size() == 2 else Vector2.ZERO
		_expect(collision != null and collision.shape is RectangleShape2D and (collision.shape as RectangleShape2D).size.distance_to(authored_size) < 0.5, "%s collider uses manifest collision dimensions" % scene_id)
		var player := _player_in_tree()
		var interactable: Area2D
		for raw_interactable in get_tree().get_nodes_in_group("interactable"):
			var candidate := raw_interactable as Area2D
			if candidate != null and candidate.get_parent() == station:
				interactable = candidate
				break
		if player != null and interactable != null:
			var player_collision := player.get_node("CollisionShape2D") as CollisionShape2D
			var approach_distance: float = maxf(12.0, interactable.radius - 8.0)
			var approach_position: Vector2 = station.global_position + Vector2(0.0, approach_distance)
			var approach_shape_position: Vector2 = approach_position + player_collision.position
			var approach_hits: Array[Dictionary] = _intersect_shape(player_collision.shape, Transform2D(0.0, approach_shape_position), player.get_rid())
			_expect(station.global_position.distance_to(approach_position) <= interactable.radius and approach_hits.is_empty(), "%s station remains reachable from its interaction zone" % scene_id)
		else:
			_expect(false, "%s station has an interaction zone and player" % scene_id)
	service_scene.queue_free()
	await get_tree().process_frame
	await get_tree().physics_frame


func _player_in_tree() -> CharacterBody2D:
	for raw_player in get_tree().get_nodes_in_group("player"):
		var candidate := raw_player as CharacterBody2D
		if candidate != null and is_instance_valid(candidate):
			return candidate
	return null


func _shape_query_hits_prop(prop: WorldProp) -> bool:
	var bounds: Rect2 = prop.get_collision_bounds()
	var query_size: Vector2 = Vector2(maxf(4.0, minf(12.0, bounds.size.x * 0.25)), maxf(4.0, minf(12.0, bounds.size.y * 0.25)))
	var hits: Array[Dictionary] = _intersect_shape(_rectangle_shape(query_size), Transform2D(0.0, bounds.get_center()))
	for hit: Dictionary in hits:
		if hit.get("collider") == prop:
			return true
	return false


func _footprint_matches_sprite_transform(prop: WorldProp, asset: Dictionary) -> bool:
	var collision: CollisionShape2D = null
	for child in prop.get_children():
		if child is CollisionShape2D:
			collision = child
			break
	if collision == null or collision.shape == null:
		return false
	var material: Dictionary = prop.get("_material_asset") if prop.get("_material_asset") is Dictionary else {}
	if not material.is_empty() and not material.get("footprints", []).is_empty():
		var authored_footprints: Array = material.get("footprints", [])
		if authored_footprints.size() > 0 and authored_footprints[0].size() == 4:
			var authored_rect := Rect2(float(authored_footprints[0][0]), float(authored_footprints[0][1]), float(authored_footprints[0][2]), float(authored_footprints[0][3]))
			var pos_err := collision.position.distance_to(authored_rect.get_center())
			var size_err := (collision.shape as RectangleShape2D).size.distance_to(authored_rect.size)
			return pos_err < 0.5 and size_err < 0.5
	var footprint: Variant = asset.get("collision_footprint", [])
	if not (footprint is Array) or footprint.size() != 4:
		return false
	var sprite := prop.get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null or sprite.texture == null:
		return false
	var texture_size: Vector2 = sprite.texture.get_size()
	var scale: Vector2 = sprite.scale
	var expected_center := sprite.position + Vector2(
		(float(footprint[0]) + float(footprint[2]) * 0.5) * texture_size.x,
		(float(footprint[1]) + float(footprint[3]) * 0.5) * texture_size.y
	) * scale
	var expected_size := Vector2(texture_size.x * float(footprint[2]), texture_size.y * float(footprint[3])) * scale
	var position_error: float = collision.position.distance_to(expected_center)
	var size_error: float = (collision.shape as RectangleShape2D).size.distance_to(expected_size)
	return position_error < 0.5 and size_error < 0.5


func _intersect_shape(shape: Shape2D, transform: Transform2D, excluded_rid: RID = RID()) -> Array[Dictionary]:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = transform
	query.collision_mask = 1
	query.collide_with_bodies = true
	query.collide_with_areas = false
	if excluded_rid.is_valid():
		var excluded: Array[RID] = [excluded_rid]
		query.exclude = excluded
	return get_viewport().world_2d.direct_space_state.intersect_shape(query, 64)


func _rectangle_shape(size: Vector2) -> RectangleShape2D:
	var shape := RectangleShape2D.new()
	shape.size = size
	return shape


func _make_wall(position: Vector2, size: Vector2) -> StaticBody2D:
	var wall := StaticBody2D.new()
	wall.position = position
	wall.add_to_group("obstacle")
	var collision := CollisionShape2D.new()
	collision.shape = _rectangle_shape(size)
	wall.add_child(collision)
	return wall


func _expect(condition: bool, description: String) -> void:
	checks.append({"name": description, "success": condition})
	if not condition:
		failures.append(description)


func _finish_report() -> void:
	AudioManager.stop_all()
	await get_tree().process_frame
	await get_tree().process_frame
	var success_count := 0
	for result: Dictionary in checks:
		if bool(result.get("success", false)):
			success_count += 1
	var report := {
		"success": failures.is_empty(),
		"success_count": success_count,
		"failure_count": failures.size(),
		"checks": checks,
		"failures": failures
	}
	var report_path := "user://qa/%s" % REPORT_FILENAME
	if not report_directory.is_empty():
		DirAccess.make_dir_recursive_absolute(report_directory)
		report_path = report_directory.path_join(REPORT_FILENAME)
	else:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://qa"))
	var output := FileAccess.open(report_path, FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(report, "\t"))
		output.close()
	else:
		failures.append("could not write collision regression report")
	var summary: String = "[COLLISION] success=%s success_count=%d failure_count=%d report=%s" % [str(failures.is_empty()).to_lower(), success_count, failures.size(), report_path]
	print(summary)
	if failures.is_empty():
		get_tree().quit(0)
	else:
		push_error("Collision regression failures: %s" % ", ".join(failures))
		get_tree().quit(1)
