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
const ATMOSPHERE_SCRIPT := preload("res://scripts/components/WastelandAtmosphere.gd")

const DEFAULT_PROP_NODES := 58
const DEFAULT_RESOURCE_NODES := 24
const DEFAULT_EVENT_NODES := 6
const DEFAULT_ENEMY_LIMIT := 50
const MAX_ACTIVE_ENEMIES := 50
const POPULATION_CHECK_INTERVAL := 0.2
const BOSS_ID := "waste_titan"

var player: Node2D
var world_size: Vector2 = Vector2(5760, 4480)
var route_id: String = "scrap_highway"
var route_data: Dictionary = {}
var route_seed: int = 9527
var combat_enemy_ids: Array[String] = []
var enemy_spawn_cursor: int = 0
var boss_spawned: bool = false
var _population_check_timer: float = 0.0


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
	var atmo: Node2D = ATMOSPHERE_SCRIPT.new()
	atmo.setup(route_id, player)
	add_child(atmo)
	_spawn_exit()
	_spawn_route_landmarks()
	_spawn_props()
	_spawn_resources()
	_spawn_harvestable_nodes()
	_spawn_events()
	_prepare_combat_enemy_ids()
	_spawn_enemies()
	_maybe_spawn_boss()
	add_child(HUD_SCENE.instantiate())
	GameState.notify(String(route_data.get("notice", "進入廢土。沿道路探索、擊倒污染體、回收資源後返回村莊。")))


func _process(delta: float) -> void:
	_population_check_timer -= delta
	if _population_check_timer > 0.0:
		return
	_population_check_timer = POPULATION_CHECK_INTERVAL
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
		exit.setup_box(Vector2(0, -texture_size.y * 0.5), Vector2(texture_size.x + 140.0, texture_size.y + 140.0))
		add_child(gate)


func _spawn_resources() -> void:
	var count: int = int(DataRegistry.map_params.get("resource_nodes", DEFAULT_RESOURCE_NODES))
	var rect: Rect2 = _route_resource_rect()
	var positions: Array = LEVEL_GENERATOR_SCRIPT.seeded_positions(count, rect, route_seed + 11, 210, _placement_blocked_regions(64.0))
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

class HarvestableNode extends Node2D:
	var node_id: String
	var node_label: String
	var drops: Array = []
	var harvested: bool = false
	var sprite: Sprite2D
	var interactable: Area2D

	func setup(id: String, label: String, texture_path: String, drop_list: Array) -> void:
		node_id = id
		node_label = label
		drops = drop_list
		y_sort_enabled = true
		add_to_group("harvestable_node")
		add_to_group("map_event")
		set_meta("map_label", label)
		set_meta("map_marker", "event")

		sprite = Sprite2D.new()
		var tex: Texture2D = ASSET_LOADER.load_png(texture_path)
		if tex != null:
			sprite.texture = tex
		else:
			sprite.texture = PIXEL.new().make_texture(Vector2i(96, 80), [Color8(35, 45, 55), Color8(65, 80, 95)], id.length())
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var sz: Vector2 = sprite.texture.get_size() if sprite.texture != null else Vector2(96, 80)
		sprite.position = Vector2(-sz.x * 0.5, -sz.y)
		add_child(sprite)

		var shadow := Polygon2D.new()
		shadow.z_index = -1
		var pts := PackedVector2Array()
		for i in range(16):
			var a: float = float(i) / 16.0 * TAU
			pts.append(Vector2(cos(a) * (sz.x * 0.42), sin(a) * (sz.y * 0.16) - 4.0))
		shadow.polygon = pts
		shadow.color = Color(0.04, 0.03, 0.05, 0.38)
		add_child(shadow)

		interactable = INTERACTABLE_SCRIPT.new()
		interactable.interaction_id = "harvest:" + id
		interactable.prompt = "採集 %s" % label
		interactable.radius = maxf(sz.x, sz.y) * 0.45
		interactable.setup_box(Vector2(0, -sz.y * 0.5), sz + Vector2(100, 100))
		interactable.interacted.connect(_on_interacted)
		add_child(interactable)

	func _on_interacted(_interaction_id: String) -> void:
		if harvested:
			return
		harvested = true
		interactable.set_deferred("monitoring", false)
		AudioManager.play_sfx("pickup")
		GameState.request_feedback("attack", 0.16)

		var summary_parts: Array[String] = []
		for raw_drop in drops:
			var drop: Dictionary = raw_drop if raw_drop is Dictionary else {}
			var item_key: String = String(drop.get("item", "scrap"))
			var item_amt: int = int(drop.get("amount", 1))
			GameState.add_item(item_key, item_amt)
			summary_parts.append("%s x%d" % [GameState.item_display_name(item_key), item_amt])

		GameState.notify("已開採 %s ➔ 獲得 %s！" % [node_label, "、".join(summary_parts)])

		var tween := create_tween()
		tween.tween_property(sprite, "modulate", Color(0.45, 0.48, 0.52, 0.65), 0.35)
		remove_from_group("map_event")


func _spawn_harvestable_nodes() -> void:
	var harvest_configs: Array[Dictionary] = []
	match route_id:
		"scrap_highway":
			harvest_configs = [
				{"id": "ore_node", "label": "合金礦石脈", "path": "res://assets/sprites/props/ore_node.png", "drops": [{"item": "alloy_plate", "amount": 2}, {"item": "scrap", "amount": 8}]},
				{"id": "scrap_pile", "label": "精密機械堆", "path": "res://assets/sprites/props/scrap_pile.png", "drops": [{"item": "broken_coil", "amount": 2}, {"item": "scrap", "amount": 10}]},
				{"id": "barrel_stack", "label": "軍規物資箱", "path": "res://assets/sprites/props/barrel_stack.png", "drops": [{"item": "ammo", "amount": 8}, {"item": "scrap", "amount": 6}]}
			]
		"toxic_marsh":
			harvest_configs = [
				{"id": "herb_patch", "label": "變異發光草藥叢", "path": "res://assets/sprites/props/herb_patch.png", "drops": [{"item": "mutant_herb", "amount": 3}, {"item": "acid_sac", "amount": 1}]},
				{"id": "crystal_node", "label": "腐蝕晶核簇", "path": "res://assets/sprites/props/crystal_node.png", "drops": [{"item": "bio_crystal", "amount": 2}, {"item": "acid_sac", "amount": 1}]},
				{"id": "scrap_pile", "label": "沈降機械廢品", "path": "res://assets/sprites/props/scrap_pile.png", "drops": [{"item": "scrap", "amount": 12}, {"item": "mutant_herb", "amount": 2}]}
			]
		"crystal_scar":
			harvest_configs = [
				{"id": "crystal_node", "label": "共鳴紫晶脈石", "path": "res://assets/sprites/props/crystal_node.png", "drops": [{"item": "amethyst_gem", "amount": 2}, {"item": "bio_crystal", "amount": 2}]},
				{"id": "ore_node", "label": "高能晶化礦堆", "path": "res://assets/sprites/props/ore_node.png", "drops": [{"item": "amethyst_gem", "amount": 2}, {"item": "mutant_core", "amount": 1}]}
			]
		"old_factory":
			harvest_configs = [
				{"id": "scrap_pile", "label": "工業控制台殘骸", "path": "res://assets/sprites/props/scrap_pile.png", "drops": [{"item": "precision_chip", "amount": 2}, {"item": "scrap", "amount": 10}]},
				{"id": "barrel_stack", "label": "高壓電漿儲能桶", "path": "res://assets/sprites/props/barrel_stack.png", "drops": [{"item": "dynamo_core", "amount": 1}, {"item": "ammo", "amount": 10}]},
				{"id": "ore_node", "label": "重型合金鑄塊", "path": "res://assets/sprites/props/ore_node.png", "drops": [{"item": "alloy_plate", "amount": 3}, {"item": "precision_chip", "amount": 1}]}
			]
		"ruined_metropolis":
			harvest_configs = [
				{"id": "scrap_pile", "label": "都市通訊站殘骸", "path": "res://assets/sprites/props/scrap_pile.png", "drops": [{"item": "precision_chip", "amount": 2}, {"item": "alloy_plate", "amount": 2}]},
				{"id": "barrel_stack", "label": "防空應急物資箱", "path": "res://assets/sprites/props/barrel_stack.png", "drops": [{"item": "ammo", "amount": 12}, {"item": "scrap", "amount": 12}]}
			]
		"underground_facility":
			harvest_configs = [
				{"id": "crystal_node", "label": "反應堆紫晶沉積", "path": "res://assets/sprites/props/crystal_node.png", "drops": [{"item": "amethyst_gem", "amount": 3}, {"item": "bio_crystal", "amount": 2}]},
				{"id": "barrel_stack", "label": "低溫超導能源箱", "path": "res://assets/sprites/props/barrel_stack.png", "drops": [{"item": "dynamo_core", "amount": 2}, {"item": "acid_sac", "amount": 1}]}
			]

	if harvest_configs.is_empty():
		return

	var count: int = 10
	var rect: Rect2 = _route_resource_rect()
	var positions: Array = LEVEL_GENERATOR_SCRIPT.seeded_positions(count, rect, route_seed + 77, 240, _placement_blocked_regions(80.0))
	for i in range(positions.size()):
		var cfg: Dictionary = harvest_configs[i % harvest_configs.size()]
		var node := HarvestableNode.new()
		node.setup(
			String(cfg.get("id", "harvest")),
			String(cfg.get("label", "採集點")),
			String(cfg.get("path", "")),
			cfg.get("drops", [])
		)
		node.global_position = positions[i]
		add_child(node)


func _spawn_props() -> void:
	var count: int = int(DataRegistry.map_params.get("prop_nodes", DEFAULT_PROP_NODES))
	var positions: Array = LEVEL_GENERATOR_SCRIPT.seeded_positions(count, Rect2(160, 180, world_size.x - 320, world_size.y - 900), route_seed + 301, 250, _placement_blocked_regions(132.0))
	var prop_ids: Array = route_data.get("prop_mix", ["rust_rock", "dead_tree", "scrap_wall", "toxic_pool", "wreck", "signal_pylon", "road_marker"])
	if prop_ids.is_empty():
		prop_ids = ["rust_rock", "dead_tree", "scrap_wall", "toxic_pool", "wreck", "signal_pylon", "road_marker"]
	var landmark_prop: String = String(route_data.get("landmark_prop", ""))
	var scatter_prop_ids: Array[String] = []
	for raw_id in prop_ids:
		var prop_id: String = String(raw_id)
		var asset: Dictionary = DataRegistry.get_visual_asset("prop_%s" % prop_id)
		if prop_id == landmark_prop or bool(asset.get("unique_required", false)):
			continue
		scatter_prop_ids.append(prop_id)
	if scatter_prop_ids.is_empty():
		scatter_prop_ids = ["rust_rock", "dead_tree", "scrap_wall", "toxic_pool", "wreck", "signal_pylon", "road_marker"]
	for i in range(positions.size()):
		var id: String = scatter_prop_ids[i % scatter_prop_ids.size()]
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
				["crystal_node", Vector2(world_size.x * 0.42, world_size.y * 0.36), false, Vector2i(96, 80)],
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
		"ruined_metropolis":
			landmarks = [
				["scrap_wall", Vector2(world_size.x * 0.38, world_size.y * 0.44), true, Vector2i(152, 90)],
				["scrap_barricade", Vector2(world_size.x * 0.62, world_size.y * 0.48), true, Vector2i(144, 84)],
				["wreck", Vector2(world_size.x * 0.48, world_size.y * 0.34), true, Vector2i(136, 86)],
				["road_marker", Vector2(world_size.x * 0.52, world_size.y * 0.56), false, Vector2i(44, 60)],
				["signal_pylon", Vector2(world_size.x * 0.68, world_size.y * 0.36), true, Vector2i(66, 136)]
			]
		"underground_facility":
			landmarks = [
				["scrap_wall", Vector2(world_size.x * 0.40, world_size.y * 0.38), true, Vector2i(148, 88)],
				["toxic_pool", Vector2(world_size.x * 0.58, world_size.y * 0.44), false, Vector2i(132, 72)],
				["scrap_barricade", Vector2(world_size.x * 0.34, world_size.y * 0.56), true, Vector2i(140, 82)],
				["rust_rock", Vector2(world_size.x * 0.66, world_size.y * 0.54), true, Vector2i(104, 78)],
				["signal_pylon", Vector2(world_size.x * 0.50, world_size.y * 0.24), true, Vector2i(68, 140)]
			]
	for raw_item in landmarks:
		var item: Array = raw_item
		var prop_id: String = String(item[0])
		var candidates: Array[Vector2] = [item[1]]
		for offset: Vector2 in [Vector2(180, 0), Vector2(-180, 0), Vector2(0, -180), Vector2(0, 180), Vector2(260, 120), Vector2(-260, 120)]:
			candidates.append(item[1] + offset)
		_spawn_prop_at_safe_position(prop_id, bool(item[2]), item[3], candidates)

	var landmark_id: String = String(route_data.get("landmark_prop", ""))
	if not landmark_id.is_empty():
		var spawn_anchor: Vector2 = Vector2(world_size.x * 0.5, world_size.y - 300.0)
		var offsets: Array[Vector2] = [
			Vector2(-360, -60), Vector2(360, -60), Vector2(-500, -320), Vector2(500, -320),
			Vector2(-530, -120), Vector2(530, -120), Vector2(-420, -340), Vector2(420, -340)
		]
		var candidates: Array[Vector2] = []
		for offset: Vector2 in offsets:
			candidates.append(spawn_anchor + offset)
		_spawn_prop_at_safe_position(landmark_id, true, _prop_size(landmark_id, 0), candidates)


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
	var asset: Dictionary = DataRegistry.get_visual_asset("prop_%s" % id)
	var asset_size: Variant = asset.get("size", [])
	var collision_footprint: Variant = asset.get("collision_footprint", [])
	if asset_size is Array and asset_size.size() == 2 and collision_footprint is Array and collision_footprint.size() == 4:
		return Vector2i(int(asset_size[0]), int(asset_size[1]))
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
	var positions: Array = LEVEL_GENERATOR_SCRIPT.seeded_positions(int(DataRegistry.map_params.get("event_nodes", DEFAULT_EVENT_NODES)), Rect2(300, 320, world_size.x - 600, world_size.y - 1100), route_seed + 25, 520, _placement_blocked_regions(120.0))
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
	var positions: Array = LEVEL_GENERATOR_SCRIPT.seeded_positions(limit, Rect2(260, 240, world_size.x - 520, world_size.y - 1100), route_seed + 91, 360, _placement_blocked_regions(96.0))
	for i in range(min(limit, positions.size())):
		_spawn_enemy_at(_enemy_id_for_spawn(), positions[i])


func _maintain_enemy_population() -> void:
	if combat_enemy_ids.is_empty() or player == null or not is_instance_valid(player):
		return
	var limit: int = _normal_enemy_limit()
	var count: int = _normal_enemy_count()
	while count < limit:
		if not _spawn_enemy_at(_enemy_id_for_spawn(), _spawn_position_near_player(720.0, 1260.0)):
			break
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


func _spawn_enemy_at(id: String, position: Vector2) -> bool:
	var data: Dictionary = DataRegistry.get_enemy(id)
	if data.is_empty() or position.x < 96.0 or position.y < 96.0 or position.x > world_size.x - 96.0 or position.y > world_size.y - 96.0:
		return false
	if not _enemy_spawn_position_is_clear(position, 42.0):
		return false
	var enemy: CharacterBody2D = ENEMY_SCRIPT.new()
	enemy.setup(id, data, player)
	enemy.global_position = position
	add_child(enemy)
	return true


func _spawn_position_near_player(min_radius: float, max_radius: float, safety_radius: float = 42.0) -> Vector2:
	var center: Vector2 = player.global_position if player != null and is_instance_valid(player) else Vector2(world_size.x * 0.5, world_size.y * 0.5)
	for attempt in range(32):
		var seed_value: int = _hash2i(enemy_spawn_cursor + route_seed + attempt * 31, GameState.defeated_enemies + 17)
		var angle: float = float(seed_value % 6283) / 1000.0
		var radius: float = lerpf(min_radius, max_radius, float((seed_value / 17) % 1000) / 1000.0)
		var candidate: Vector2 = (center + Vector2(cos(angle), sin(angle)) * radius).clamp(Vector2(96, 96), world_size - Vector2(96, 96))
		if _enemy_spawn_position_is_clear(candidate, safety_radius):
			return candidate
	return Vector2(-1.0, -1.0)


func _enemy_spawn_position_is_clear(position: Vector2, radius: float) -> bool:
	var candidate_bounds := Rect2(position - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
	var return_lane := _return_lane_bounds()
	if candidate_bounds.intersects(return_lane):
		return false
	if player != null and is_instance_valid(player) and position.distance_to(player.global_position) < 96.0:
		return false
	for raw_prop in get_tree().get_nodes_in_group("world_prop"):
		var prop := raw_prop as WorldProp
		if prop == null or not is_instance_valid(prop) or not prop.blocks_movement:
			continue
		if candidate_bounds.intersects(prop.get_collision_bounds().grow(8.0)):
			return false
	for raw_enemy in get_tree().get_nodes_in_group("enemy"):
		var enemy := raw_enemy as Node2D
		if enemy != null and is_instance_valid(enemy) and position.distance_to(enemy.global_position) < radius + 42.0:
			return false
	return true


func _maybe_spawn_boss() -> void:
	if boss_spawned or not _boss_should_exist():
		return
	if _active_boss_count() > 0:
		boss_spawned = true
		return
	if _normal_enemy_count() >= MAX_ACTIVE_ENEMIES:
		_despawn_farthest_normal_enemy()
	if _spawn_boss(_spawn_position_near_player(880.0, 1320.0, 64.0)):
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


func _spawn_boss(spawn_position: Vector2) -> bool:
	var boss_data: Dictionary = DataRegistry.get_enemy(BOSS_ID)
	if boss_data.is_empty() or spawn_position.x < 96.0:
		return false
	if not _enemy_spawn_position_is_clear(spawn_position, 64.0):
		return false
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
	return true


func _spawn_prop_at_safe_position(id: String, blocking: bool, size: Vector2i, candidates: Array[Vector2]) -> WorldProp:
	var prop := WORLD_PROP_SCRIPT.new() as WorldProp
	prop.setup(id, blocking, size)
	if not candidates.is_empty():
		prop.global_position = candidates[0]
	add_child(prop)
	for candidate: Vector2 in candidates:
		prop.global_position = candidate
		if _prop_position_is_clear(prop):
			return prop
	prop.queue_free()
	return null


func _prop_position_is_clear(prop: WorldProp) -> bool:
	var candidate_bounds: Rect2 = prop.get_visual_bounds().grow(8.0)
	for critical_region: Rect2 in _critical_prop_regions():
		if candidate_bounds.intersects(critical_region):
			return false
	for raw_existing in get_tree().get_nodes_in_group("world_prop"):
		var existing := raw_existing as WorldProp
		if existing == null or not is_instance_valid(existing) or existing == prop:
			continue
		if candidate_bounds.intersects(existing.get_visual_bounds().grow(8.0)):
			return false
	return true


func _placement_blocked_regions(padding: float) -> Array[Rect2]:
	var blocked: Array[Rect2] = []
	for region: Rect2 in _critical_prop_regions():
		blocked.append(region.grow(padding))
	for raw_prop in get_tree().get_nodes_in_group("world_prop"):
		var prop := raw_prop as WorldProp
		if prop == null or not is_instance_valid(prop):
			continue
		var bounds: Rect2 = prop.get_visual_bounds()
		if bounds.size.x > 0.0 and bounds.size.y > 0.0:
			blocked.append(bounds.grow(padding))
	return blocked


func _critical_prop_regions() -> Array[Rect2]:
	var regions: Array[Rect2] = [_return_lane_bounds()]
	if player != null and is_instance_valid(player):
		regions.append(Rect2(player.global_position + Vector2(-88, -102), Vector2(176, 118)))
	return regions


func _return_lane_bounds() -> Rect2:
	return Rect2(Vector2(world_size.x * 0.5 - 140.0, world_size.y - 470.0), Vector2(280.0, 430.0))


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
	var event_id: String = interaction_id.trim_prefix("event:")
	var separator: int = event_id.find(":")
	var bare_event_id: String = event_id.substr(separator + 1) if separator >= 0 else event_id
	if GameState.discovered_events.has(event_id) or GameState.discovered_events.has(bare_event_id):
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
