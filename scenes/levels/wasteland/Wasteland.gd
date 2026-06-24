extends Node2D

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const HUD_SCENE := preload("res://scenes/ui/HUD.tscn")
const PIXEL := preload("res://scripts/utils/PixelArtFactory.gd")
const ASSET_LOADER := preload("res://scripts/utils/RuntimeAssetLoader.gd")
const BACKDROP_SCRIPT := preload("res://scripts/systems/WorldBackdrop.gd")
const INTERACTABLE_SCRIPT := preload("res://scripts/components/Interactable.gd")
const PICKUP_SCRIPT := preload("res://scripts/components/Pickup.gd")
const ENEMY_SCRIPT := preload("res://scripts/components/Enemy.gd")
const WORLD_PROP_SCRIPT := preload("res://scripts/components/WorldProp.gd")
const LEVEL_GENERATOR_SCRIPT := preload("res://scripts/systems/LevelGenerator.gd")
const PROJECTILE_POOL_SCRIPT := preload("res://scripts/systems/ProjectilePool.gd")

const DEFAULT_PROP_NODES := 58
const DEFAULT_RESOURCE_NODES := 24
const DEFAULT_EVENT_NODES := 6
const DEFAULT_ENEMY_LIMIT := 50
const MAX_ACTIVE_ENEMIES := 50
const BOSS_ID := "waste_titan"

var player: Node2D
var world_size: Vector2 = Vector2(5760, 4480)
var route_id: String = "scrap_highway"
var route_data: Dictionary = {}
var route_seed: int = 9527
var combat_enemy_ids: Array[String] = []
var enemy_spawn_cursor: int = 0
var boss_spawned: bool = false


func _ready() -> void:
	y_sort_enabled = true
	GameState.current_scene_id = "wasteland"
	route_id = GameState.current_route_id
	route_data = DataRegistry.get_wasteland_route(route_id)
	if route_data.is_empty():
		route_id = "scrap_highway"
		route_data = DataRegistry.get_wasteland_route(route_id)
		GameState.current_route_id = route_id
	AudioManager.play_music(String(route_data.get("music", "wasteland")))
	var params: Dictionary = DataRegistry.map_params
	var tile_size: int = int(params.get("tile_size", 32))
	var size_tiles: Vector2i = Vector2i(int(params.get("width_tiles", 180)), int(params.get("height_tiles", 140)))
	world_size = Vector2(size_tiles.x * tile_size, size_tiles.y * tile_size)
	set_meta("map_world_size", world_size)
	set_meta("map_scene_label", String(route_data.get("name", "廢土")))
	route_seed = GameState.seed + int(route_data.get("seed_offset", 0))
	var backdrop: Node2D = BACKDROP_SCRIPT.new()
	backdrop.setup("wasteland", size_tiles, route_seed, route_id)
	add_child(backdrop)
	_add_boundaries(world_size)
	_add_projectile_pool(int(params.get("projectile_limit", 200)))
	_spawn_player(Vector2(world_size.x * 0.5, world_size.y - 300))
	_spawn_exit()
	_spawn_route_landmarks()
	_spawn_props()
	_spawn_resources()
	_spawn_events()
	_prepare_combat_enemy_ids()
	_spawn_enemies()
	_maybe_spawn_boss()
	add_child(HUD_SCENE.instantiate())
	GameState.notify(String(route_data.get("notice", "進入廢土。沿道路探索、擊倒污染體、回收資源後返回村莊。")))


func _process(_delta: float) -> void:
	_maybe_spawn_boss()
	_maintain_enemy_population()


func _spawn_player(default_position: Vector2) -> void:
	player = PLAYER_SCENE.instantiate()
	if GameState.active_spawn_point == "saved" and GameState.player_position != Vector2.ZERO:
		player.global_position = GameState.player_position
	else:
		player.global_position = default_position
	add_child(player)
	if player.has_method("set_world_bounds"):
		player.set_world_bounds(Rect2(Vector2(48, 48), world_size - Vector2(96, 96)))


func _add_projectile_pool(limit: int) -> void:
	var pool: Node = PROJECTILE_POOL_SCRIPT.new()
	pool.max_projectiles = limit
	add_child(pool)


func _spawn_exit() -> void:
	var exit: Area2D = INTERACTABLE_SCRIPT.new()
	exit.interaction_id = "to_village"
	exit.prompt = "返回村莊"
	exit.position = Vector2(world_size.x * 0.5, world_size.y - 90)
	exit.add_to_group("map_gate")
	exit.set_meta("map_label", "回村門")
	exit.set_meta("map_marker", "gate")
	exit.interacted.connect(func(_id: String) -> void: SceneRouter.change_to("village", "from_wasteland"))
	add_child(exit)
	var gate: Sprite2D = Sprite2D.new()
	var gate_texture: Texture2D = ASSET_LOADER.load_png(DataRegistry.asset_path("structure_village_return_gate"))
	if gate_texture != null:
		gate.texture = gate_texture
		gate.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		gate.centered = false
		var texture_size: Vector2 = gate.texture.get_size()
		gate.position = exit.position + Vector2(-texture_size.x * 0.5, -texture_size.y)
		add_child(gate)


func _spawn_resources() -> void:
	var count: int = int(DataRegistry.map_params.get("resource_nodes", DEFAULT_RESOURCE_NODES))
	var rect: Rect2 = _route_resource_rect()
	var positions: Array = LEVEL_GENERATOR_SCRIPT.seeded_positions(count, rect, route_seed + 11, 210)
	var ids: Array = route_data.get("resource_mix", ["scrap", "ammo", "bio_crystal", "mutant_core"])
	if ids.is_empty():
		ids = ["scrap", "ammo", "bio_crystal", "mutant_core"]
	for i in range(positions.size()):
		var id: String = String(ids[i % ids.size()])
		var amount: int = 1 + (i % 2)
		if id == "mutant_core":
			amount = 1
		var pickup: Area2D = PICKUP_SCRIPT.new()
		pickup.setup(id, amount)
		pickup.global_position = positions[i]
		add_child(pickup)


func _spawn_props() -> void:
	var count: int = int(DataRegistry.map_params.get("prop_nodes", DEFAULT_PROP_NODES))
	var positions: Array = LEVEL_GENERATOR_SCRIPT.seeded_positions(count, Rect2(160, 180, world_size.x - 320, world_size.y - 900), route_seed + 301, 190)
	var prop_ids: Array = route_data.get("prop_mix", ["rust_rock", "dead_tree", "scrap_wall", "toxic_pool", "wreck", "signal_pylon", "road_marker"])
	if prop_ids.is_empty():
		prop_ids = ["rust_rock", "dead_tree", "scrap_wall", "toxic_pool", "wreck", "signal_pylon", "road_marker"]
	for i in range(positions.size()):
		var id: String = String(prop_ids[i % prop_ids.size()])
		var blocking: bool = id != "toxic_pool" and id != "road_marker"
		var size: Vector2i = _prop_size(id, i)
		var prop: StaticBody2D = WORLD_PROP_SCRIPT.new()
		prop.setup(id, blocking, size)
		prop.global_position = positions[i]
		add_child(prop)


func _spawn_route_landmarks() -> void:
	var landmarks: Array = []
	match route_id:
		"scrap_highway":
			landmarks = [
				["wreck", Vector2(world_size.x * 0.28, world_size.y * 0.52), true, Vector2i(150, 96)],
				["road_marker", Vector2(world_size.x * 0.45, world_size.y * 0.48), false, Vector2i(48, 64)],
				["scrap_barricade", Vector2(world_size.x * 0.66, world_size.y * 0.57), true, Vector2i(138, 82)],
				["scrap_wall", Vector2(world_size.x * 0.76, world_size.y * 0.42), true, Vector2i(128, 76)],
				["rust_rock", Vector2(world_size.x * 0.56, world_size.y * 0.68), true, Vector2i(94, 70)]
			]
		"toxic_marsh":
			landmarks = [
				["toxic_pool", Vector2(world_size.x * 0.35, world_size.y * 0.40), false, Vector2i(160, 88)],
				["toxic_pool", Vector2(world_size.x * 0.58, world_size.y * 0.55), false, Vector2i(136, 74)],
				["signal_pylon", Vector2(world_size.x * 0.47, world_size.y * 0.32), true, Vector2i(62, 134)],
				["dead_tree", Vector2(world_size.x * 0.70, world_size.y * 0.62), true, Vector2i(82, 132)],
				["scrap_wall", Vector2(world_size.x * 0.28, world_size.y * 0.62), true, Vector2i(120, 70)]
			]
		"crystal_scar":
			landmarks = [
				["signal_pylon", Vector2(world_size.x * 0.50, world_size.y * 0.18), true, Vector2i(64, 138)],
				["toxic_pool", Vector2(world_size.x * 0.42, world_size.y * 0.36), false, Vector2i(112, 62)],
				["rust_rock", Vector2(world_size.x * 0.62, world_size.y * 0.30), true, Vector2i(108, 80)],
				["dead_tree", Vector2(world_size.x * 0.35, world_size.y * 0.58), true, Vector2i(78, 126)],
				["scrap_wall", Vector2(world_size.x * 0.68, world_size.y * 0.50), true, Vector2i(132, 80)]
			]
		"old_factory":
			landmarks = [
				["scrap_wall", Vector2(world_size.x * 0.42, world_size.y * 0.42), true, Vector2i(150, 92)],
				["signal_pylon", Vector2(world_size.x * 0.63, world_size.y * 0.30), true, Vector2i(70, 142)],
				["scrap_barricade", Vector2(world_size.x * 0.70, world_size.y * 0.56), true, Vector2i(146, 86)],
				["wreck", Vector2(world_size.x * 0.36, world_size.y * 0.63), true, Vector2i(126, 82)],
				["road_marker", Vector2(world_size.x * 0.56, world_size.y * 0.50), false, Vector2i(42, 58)]
			]
	for raw_item in landmarks:
		var item: Array = raw_item
		var prop: StaticBody2D = WORLD_PROP_SCRIPT.new()
		prop.setup(String(item[0]), bool(item[2]), item[3])
		prop.global_position = item[1]
		add_child(prop)


func _route_resource_rect() -> Rect2:
	match route_id:
		"scrap_highway":
			return Rect2(260, world_size.y * 0.34, world_size.x - 520, world_size.y * 0.34)
		"toxic_marsh":
			return Rect2(world_size.x * 0.22, 260, world_size.x * 0.50, world_size.y - 1100)
		"crystal_scar":
			return Rect2(320, 240, world_size.x - 640, world_size.y * 0.52)
		"old_factory":
			return Rect2(world_size.x * 0.30, 260, world_size.x * 0.56, world_size.y - 1120)
		_:
			return Rect2(240, 240, world_size.x - 480, world_size.y - 900)


func _prop_size(id: String, index: int) -> Vector2i:
	match id:
		"dead_tree":
			return Vector2i(46 + (index % 3) * 8, 88 + (index % 4) * 10)
		"scrap_wall":
			return Vector2i(82, 58)
		"scrap_barricade":
			return Vector2i(92, 64)
		"toxic_pool":
			return Vector2i(88, 52)
		"wreck":
			return Vector2i(104, 74)
		"signal_pylon":
			return Vector2i(54, 112)
		"road_marker":
			return Vector2i(34, 48)
		_:
			return Vector2i(56 + (index % 2) * 14, 48 + (index % 3) * 8)


func _spawn_events() -> void:
	if DataRegistry.events.is_empty():
		return
	var positions: Array = LEVEL_GENERATOR_SCRIPT.seeded_positions(int(DataRegistry.map_params.get("event_nodes", DEFAULT_EVENT_NODES)), Rect2(300, 320, world_size.x - 600, world_size.y - 1100), route_seed + 25, 520)
	for i in range(positions.size()):
		var event_data: Dictionary = DataRegistry.events[i % DataRegistry.events.size()]
		var event_id: String = "%s:%s" % [route_id, String(event_data.get("id", "event_%d" % i))]
		var event_name: String = String(event_data.get("name", "廢土事件"))
		var node: Area2D = INTERACTABLE_SCRIPT.new()
		node.interaction_id = "event:" + event_id
		node.prompt = event_name
		node.position = positions[i]
		node.add_to_group("map_event")
		node.set_meta("map_label", event_name)
		node.set_meta("map_marker", "event")
		node.interacted.connect(_on_event_interacted)
		add_child(node)
		var marker: Sprite2D = Sprite2D.new()
		var marker_item: String = "bio_crystal" if i % 2 == 0 else "mutant_core"
		marker.texture = PIXEL.new().item_texture(marker_item)
		marker.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		marker.scale = Vector2(0.92, 0.92)
		marker.position = positions[i]
		add_child(marker)


func _prepare_combat_enemy_ids() -> void:
	combat_enemy_ids.clear()
	var route_mix: Array = route_data.get("enemy_mix", [])
	for raw_id in route_mix:
		var id: String = String(raw_id)
		var data: Dictionary = DataRegistry.get_enemy(id)
		if not data.is_empty() and String(data.get("type", "")) != "boss":
			combat_enemy_ids.append(id)
	if combat_enemy_ids.is_empty():
		for raw_id in DataRegistry.enemy_ids():
			var id: String = String(raw_id)
			if String(DataRegistry.get_enemy(id).get("type", "")) != "boss":
				combat_enemy_ids.append(id)


func _spawn_enemies() -> void:
	if combat_enemy_ids.is_empty():
		return
	var limit: int = _normal_enemy_limit()
	var positions: Array = LEVEL_GENERATOR_SCRIPT.seeded_positions(limit, Rect2(260, 240, world_size.x - 520, world_size.y - 1100), route_seed + 91, 360)
	for i in range(min(limit, positions.size())):
		_spawn_enemy_at(_enemy_id_for_spawn(), positions[i])


func _maintain_enemy_population() -> void:
	if combat_enemy_ids.is_empty() or player == null or not is_instance_valid(player):
		return
	var limit: int = _normal_enemy_limit()
	var count: int = _normal_enemy_count()
	while count < limit:
		_spawn_enemy_at(_enemy_id_for_spawn(), _spawn_position_near_player(720.0, 1260.0))
		count += 1


func _normal_enemy_limit() -> int:
	var total_limit: int = clampi(int(DataRegistry.map_params.get("enemy_limit", DEFAULT_ENEMY_LIMIT)), 0, MAX_ACTIVE_ENEMIES)
	if _boss_should_exist() or boss_spawned or _active_boss_count() > 0:
		return max(0, total_limit - 1)
	return total_limit


func _boss_should_exist() -> bool:
	var trigger_count: int = int(DataRegistry.map_params.get("boss_spawn_after_defeats", 40))
	return bool(route_data.get("boss_enabled", false)) and GameState.defeated_enemies >= trigger_count and not DataRegistry.get_enemy(BOSS_ID).is_empty()


func _normal_enemy_count() -> int:
	var count: int = 0
	for raw_node in get_tree().get_nodes_in_group("enemy"):
		var node: Node = raw_node as Node
		if node != null and is_instance_valid(node) and not node.is_in_group("boss"):
			count += 1
	return count


func _active_boss_count() -> int:
	var count: int = 0
	for raw_node in get_tree().get_nodes_in_group("boss"):
		var node: Node = raw_node as Node
		if node != null and is_instance_valid(node):
			count += 1
	return count


func _enemy_id_for_spawn() -> String:
	var id: String = combat_enemy_ids[enemy_spawn_cursor % combat_enemy_ids.size()]
	enemy_spawn_cursor += 1
	return id


func _spawn_enemy_at(id: String, position: Vector2) -> void:
	var data: Dictionary = DataRegistry.get_enemy(id)
	if data.is_empty():
		return
	var enemy: CharacterBody2D = ENEMY_SCRIPT.new()
	enemy.setup(id, data, player)
	enemy.global_position = position
	add_child(enemy)


func _spawn_position_near_player(min_radius: float, max_radius: float) -> Vector2:
	var center: Vector2 = player.global_position if player != null and is_instance_valid(player) else Vector2(world_size.x * 0.5, world_size.y * 0.5)
	var seed_value: int = _hash2i(enemy_spawn_cursor + route_seed, GameState.defeated_enemies + 17)
	var angle: float = float(seed_value % 6283) / 1000.0
	var radius: float = lerp(min_radius, max_radius, float((seed_value / 17) % 1000) / 1000.0)
	var position: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius
	return position.clamp(Vector2(96, 96), world_size - Vector2(96, 96))


func _maybe_spawn_boss() -> void:
	if boss_spawned or not _boss_should_exist():
		return
	if _active_boss_count() > 0:
		boss_spawned = true
		return
	if _normal_enemy_count() >= MAX_ACTIVE_ENEMIES:
		_despawn_farthest_normal_enemy()
	_spawn_boss(_spawn_position_near_player(880.0, 1320.0))
	boss_spawned = true
	GameState.notify("廢土吞噬核心已鎖定 R-17，Boss 正在追殺你。")


func _despawn_farthest_normal_enemy() -> void:
	var farthest: Node2D = null
	var farthest_distance: float = -1.0
	var center: Vector2 = player.global_position if player != null and is_instance_valid(player) else Vector2.ZERO
	for raw_node in get_tree().get_nodes_in_group("enemy"):
		var node: Node2D = raw_node as Node2D
		if node == null or not is_instance_valid(node) or node.is_in_group("boss"):
			continue
		var distance: float = center.distance_to(node.global_position)
		if distance > farthest_distance:
			farthest_distance = distance
			farthest = node
	if farthest != null:
		farthest.queue_free()


func _spawn_boss(spawn_position: Vector2) -> void:
	var boss_data: Dictionary = DataRegistry.get_enemy(BOSS_ID)
	if boss_data.is_empty():
		return
	var boss: CharacterBody2D = ENEMY_SCRIPT.new()
	boss.setup(BOSS_ID, boss_data, player)
	boss.global_position = spawn_position
	add_child(boss)
	var beacon: Sprite2D = Sprite2D.new()
	beacon.texture = PIXEL.new().item_texture("mutant_core")
	beacon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	beacon.scale = Vector2(1.05, 1.05)
	beacon.position = boss.global_position + Vector2(0, 54)
	add_child(beacon)


func _add_boundaries(size: Vector2) -> void:
	_add_boundary(Vector2(size.x * 0.5, 12), Vector2(size.x, 24))
	_add_boundary(Vector2(size.x * 0.5, size.y - 12), Vector2(size.x, 24))
	_add_boundary(Vector2(12, size.y * 0.5), Vector2(24, size.y))
	_add_boundary(Vector2(size.x - 12, size.y * 0.5), Vector2(24, size.y))


func _add_boundary(pos: Vector2, size: Vector2) -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.add_to_group("obstacle")
	body.position = pos
	var collision: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)


func _on_event_interacted(interaction_id: String) -> void:
	var event_id: String = interaction_id.replace("event:", "")
	if GameState.discovered_events.has(event_id):
		GameState.notify("這個事件已經回收過。")
		return
	GameState.discovered_events.append(event_id)
	for event_data in DataRegistry.events:
		if event_id.ends_with(String(event_data.get("id", ""))):
			var reward: Dictionary = event_data.get("reward", {})
			for item_id in reward.keys():
				GameState.add_item(String(item_id), int(reward[item_id]))
			var event_name: String = String(event_data.get("name", event_id))
			var description: String = String(event_data.get("description", ""))
			GameState.notify("%s 完成：%s" % [event_name, description])
			SaveManager.save_game(false)
			return


func _hash2i(x: int, y: int) -> int:
	var n: int = int(route_seed) + x * 374761393 + y * 668265263
	n = (n ^ (n >> 13)) * 1274126177
	return abs(n ^ (n >> 16))
