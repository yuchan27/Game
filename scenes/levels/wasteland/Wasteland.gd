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
const CAMPAIGN_ACTION_SCRIPT := preload("res://scripts/components/CampaignAction.gd")
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
var _story_site_regions: Array[Rect2] = []
var _campaign_regions: Array[Rect2] = []
var _campaign_action_definitions: Array[Dictionary] = []
var _exploration_site_regions: Array[Rect2] = []
var _exploration_path_regions: Array[Rect2] = []
var _exploration_points: Array[Dictionary] = []
var _architecture_regions: Array[Rect2] = []
var _architecture_visual_regions: Array[Rect2] = []
var _architecture_sprites: Array[Sprite2D] = []
static var _architecture_occlusion_masks: Dictionary = {}
var _current_region := ""
var _contract_field_sites: Dictionary = {}
var _contract_field_regions: Array[Rect2] = []
var _authored_cover_count := 0
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
	GameState.begin_expedition()
	AudioManager.play_music(String(route_data.get("music", "wasteland")))
	var params: Dictionary = DataRegistry.map_params
	var tile_size: int = int(params.get("tile_size", 32))
	var size_tiles: Vector2i = Vector2i(int(params.get("width_tiles", 180)), int(params.get("height_tiles", 140)))
	var route_size: Variant = route_data.get("size_tiles", [])
	if route_size is Array and route_size.size() == 2:
		size_tiles = Vector2i(clampi(int(route_size[0]), 180, 240), clampi(int(route_size[1]), 140, 200))
	world_size = Vector2(size_tiles.x * tile_size, size_tiles.y * tile_size)
	set_meta("map_world_size", world_size)
	set_meta("map_scene_label", String(route_data.get("name", "廢土")))
	_configure_exploration_layout()
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
	_spawn_campaign_actions()
	_spawn_exploration_points()
	_spawn_contract_field_sites()
	_spawn_authored_architecture()
	_spawn_pathside_landmarks()
	_spawn_props()
	_spawn_resources()
	_spawn_harvestable_nodes()
	_spawn_events()
	var ground_contacts: Array[Rect2] = []
	for prop: Node in get_tree().get_nodes_in_group("world_prop"):
		if not is_ancestor_of(prop) or not prop.has_method("get_collision_bounds"):
			continue
		var foot: Rect2 = prop.get_collision_bounds()
		if foot.size == Vector2.ZERO:
			var visual: Rect2 = prop.get_visual_bounds()
			foot = Rect2(prop.global_position - Vector2(visual.size.x * 0.32, 8), Vector2(visual.size.x * 0.64, 12))
		if foot.size.x >= 30.0:
			ground_contacts.append(foot)
	backdrop.call("register_ground_contacts", ground_contacts)
	_prepare_combat_enemy_ids()
	_spawn_enemies()
	_maybe_spawn_boss()
	add_child(HUD_SCENE.instantiate())
	GameState.stats_changed.connect(_refresh_contract_field_sites)
	_update_region_notice()
	GameState.notify(String(route_data.get("notice", "進入廢土。沿道路探索、擊倒污染體、回收資源後返回村莊。")))


func _process(delta: float) -> void:
	_population_check_timer -= delta
	if _population_check_timer > 0.0:
		return
	_population_check_timer = POPULATION_CHECK_INTERVAL
	_refresh_exploration_points()
	_refresh_architecture_occlusion()
	_refresh_contract_field_labels()
	_update_region_notice()
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
	exit.prompt = "撤離返村（帶回本趟收穫）"
	exit.position = _return_gate_world_position()
	exit.add_to_group("map_gate")
	exit.set_meta("map_label", "回村門")
	exit.set_meta("map_marker", "gate")
	exit.interacted.connect(func(_id: String) -> void: SceneRouter.change_to("village", "from_wasteland", "", "extract"))
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
	positions = GameState.expedition_positions("resources", positions)
	var ids: Array = route_data.get("resource_mix", ["scrap", "ammo", "bio_crystal", "mutant_core"])
	if ids.is_empty():
		ids = ["scrap", "ammo", "bio_crystal", "mutant_core"]
	for i in range(positions.size()):
		var source_key := "resource:%s:%d" % [route_id, i]
		if GameState.has_run_source(source_key):
			continue
		var id: String = String(ids[i % ids.size()])
		var amount: int = 1 + (i % 2)
		if id == "mutant_core":
			amount = 1
		var pickup: Area2D = PICKUP_SCRIPT.new()
		pickup.setup(id, amount, source_key)
		pickup.global_position = positions[i]
		add_child(pickup)

class HarvestableNode extends Node2D:
	var node_id: String
	var node_label: String
	var drops: Array = []
	var harvested: bool = false
	var source_key := ""
	var sprite: Node2D
	var interactable: Area2D

	func setup(id: String, label: String, texture_path: String, drop_list: Array, route_context := "", run_source_key := "") -> void:
		node_id = id
		node_label = label
		drops = drop_list
		source_key = run_source_key
		y_sort_enabled = true
		add_to_group("harvestable_node")
		add_to_group("map_event")
		set_meta("map_label", label)
		set_meta("map_marker", "event")

		var sz := Vector2(96, 80)
		if not WORLD_PROP_SCRIPT.material_kit().is_empty():
			var prop := WORLD_PROP_SCRIPT.new() as WorldProp
			prop.setup(id, false, Vector2i(sz), route_context)
			sprite = prop
		else:
			var legacy_sprite := Sprite2D.new()
			legacy_sprite.texture = ASSET_LOADER.load_png(texture_path)
			if legacy_sprite.texture == null:
				legacy_sprite.texture = PIXEL.new().make_texture(Vector2i(96, 80), [Color8(35, 45, 55), Color8(65, 80, 95)], id.length())
			legacy_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sz = legacy_sprite.texture.get_size()
			legacy_sprite.position = Vector2(-sz.x * 0.5, -sz.y)
			sprite = legacy_sprite
		add_child(sprite)

		interactable = INTERACTABLE_SCRIPT.new()
		interactable.interaction_id = "harvest:" + id
		interactable.prompt = "採集 %s" % label
		interactable.radius = maxf(sz.x, sz.y) * 0.45
		interactable.setup_box(Vector2(0, -sz.y * 0.5), sz + Vector2(100, 100))
		interactable.interacted.connect(_on_interacted)
		add_child(interactable)

	func _on_interacted(_interaction_id: String) -> void:
		if harvested or (not source_key.is_empty() and GameState.has_run_source(source_key)):
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
			GameState.add_field_item(item_key, item_amt)
			summary_parts.append("%s x%d" % [GameState.item_display_name(item_key), item_amt])
		if not source_key.is_empty():
			GameState.record_run_source(source_key)

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
	positions = GameState.expedition_positions("harvest", positions)
	for i in range(positions.size()):
		var position: Vector2 = positions[i]
		var source_key := "harvest:%s:%d:%d" % [route_id, roundi(position.x), roundi(position.y)]
		if GameState.has_run_source(source_key):
			continue
		var cfg: Dictionary = harvest_configs[i % harvest_configs.size()]
		var node := HarvestableNode.new()
		node.setup(
			String(cfg.get("id", "harvest")),
			String(cfg.get("label", "採集點")),
			String(cfg.get("path", "")),
			cfg.get("drops", []),
			route_id,
			source_key
		)
		node.global_position = position
		add_child(node)


func _spawn_props() -> void:
	if not WORLD_PROP_SCRIPT.material_kit().is_empty():
		_spawn_material_clusters()
		return
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
		prop.setup(id, blocking, size, route_id)
		prop.global_position = positions[i]
		add_child(prop)


func _spawn_material_clusters() -> void:
	# Authored yards replace part of the filler budget rather than piling on top.
	var budget := maxi(0, int(DataRegistry.map_params.get("prop_nodes", DEFAULT_PROP_NODES)) - _authored_cover_count)
	var architecture_budget := budget / 2
	var cluster_index := 0
	# Erosion collects masonry and weeds beside real facade feet, never across doors.
	for footprint: Rect2 in _architecture_regions:
		if footprint.size.x > 600.0 or footprint.size.y > 200.0:
			continue
		for side in [-1.0, 1.0]:
			var edge_x := footprint.position.x - 88.0 if side < 0.0 else footprint.end.x + 88.0
			var placed := _spawn_material_cluster(Vector2(edge_x, footprint.end.y + 28.0), cluster_index, mini(budget, architecture_budget))
			budget -= placed
			architecture_budget -= placed
			cluster_index += 1
			if architecture_budget <= 0:
				break
		if architecture_budget <= 0:
			break
	# Roadside caches occur in uneven pairs, leaving the route centre and return open.
	for path: PackedVector2Array in get_meta("map_paths", []):
		for segment in range(1, path.size()):
			var a: Vector2 = path[segment - 1]
			var b: Vector2 = path[segment]
			var normal := Vector2(-(b - a).y, (b - a).x).normalized()
			var steps := maxi(1, int(a.distance_to(b) / 680.0))
			for step in range(steps):
				var side := -1.0 if cluster_index % 2 == 0 else 1.0
				var center := a.lerp(b, (float(step) + 0.35) / float(steps)) + normal * side * 244.0
				budget -= _spawn_material_cluster(center, cluster_index, budget)
				cluster_index += 1
				if budget <= 0:
					return


func _spawn_material_cluster(center: Vector2, index: int, budget: int) -> int:
	var ids: Array[String] = ["rubble_a" if index % 2 == 0 else "rubble_b", "dry_grass", "thorn" if index % 3 else "supply"]
	var offsets: Array[Vector2] = [Vector2.ZERO, Vector2(58, 12), Vector2(-64, 22)]
	var placed := 0
	for part in range(mini(budget, ids.size())):
		var prop := WORLD_PROP_SCRIPT.new() as WorldProp
		prop.setup(ids[part], false, Vector2i(56, 56), route_id)
		prop.position = center + offsets[part] * (-1.0 if index % 2 else 1.0)
		prop.name = "MaterialCluster_%d_%d" % [index, part]
		add_child(prop)
		var bounds := prop.get_visual_bounds()
		var blocked := not Rect2(Vector2(80, 80), world_size - Vector2(160, 160)).encloses(bounds)
		var reserves: Array[Rect2] = [_entry_lane_bounds(), _extraction_gate_bounds()]
		reserves.append_array(_story_site_regions)
		reserves.append_array(_campaign_regions)
		reserves.append_array(_exploration_site_regions)
		reserves.append_array(_exploration_path_regions)
		for region: Rect2 in reserves:
			blocked = blocked or bounds.intersects(region)
		for region: Rect2 in _architecture_regions:
			blocked = blocked or bounds.intersects(region.grow(4.0))
		if player != null:
			blocked = blocked or bounds.grow(48.0).has_point(player.position)
		for raw_existing in get_tree().get_nodes_in_group("world_prop"):
			var existing := raw_existing as WorldProp
			if existing != null and existing != prop:
				blocked = blocked or bounds.intersects(existing.get_visual_bounds().grow(3.0))
		if blocked:
			remove_child(prop)
			prop.queue_free()
		else:
			placed += 1
	return placed


func _spawn_route_landmarks() -> void:
	_spawn_story_site()
	_prepare_campaign_action_layout()
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


func _prepare_campaign_action_layout() -> void:
	_campaign_action_definitions.clear()
	_campaign_regions.clear()
	if not GameState.has_authored_campaign() or GameState.is_legacy_expedition():
		return
	var quest := DataRegistry.get_quest(GameState.active_quest_id)
	if quest.is_empty() or String(quest.get("route", "")) != route_id:
		return
	var outing := GameState.campaign_outing()
	var raw_actions: Variant = outing.get("actions", [])
	if not raw_actions is Array:
		return
	for raw_action in raw_actions:
		if not raw_action is Dictionary or String(raw_action.get("id", "")).is_empty():
			continue
		_campaign_action_definitions.append(raw_action.duplicate(true))
	for action: Dictionary in _campaign_action_definitions:
		var action_position := _normalized_world_position(action.get("position", []))
		var radius := maxf(112.0, float(action.get("radius", 112.0))) + 96.0
		_campaign_regions.append(Rect2(action_position - Vector2(radius, radius), Vector2(radius * 2.0, radius * 2.0)))
		_append_campaign_path(action_position, action.get("waypoints", []), true)
		var route_choice_id := String(action.get("route_choice", ""))
		if not route_choice_id.is_empty():
			var choice := _campaign_action_by_id(route_choice_id)
			for raw_option in choice.get("options", []):
				if raw_option is Dictionary:
					_append_campaign_path(action_position, raw_option.get("waypoints", []), true)


func _append_campaign_path(origin: Vector2, raw_waypoints: Variant, include_origin: bool) -> void:
	if not raw_waypoints is Array:
		return
	var waypoints: Array = raw_waypoints
	if waypoints.is_empty():
		return
	var points: Array[Vector2] = []
	if include_origin:
		points.append(origin)
	for raw_position in waypoints:
		points.append(_normalized_world_position(raw_position))
	for point: Vector2 in points:
		_campaign_regions.append(Rect2(point - Vector2(152.0, 152.0), Vector2(304.0, 304.0)))
	for index in range(1, points.size()):
		var a: Vector2 = points[index - 1]
		var b: Vector2 = points[index]
		var bounds := Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), Vector2(absf(a.x - b.x), absf(a.y - b.y))).grow(136.0)
		_campaign_regions.append(bounds)


func _campaign_action_by_id(action_id: String) -> Dictionary:
	for action: Dictionary in _campaign_action_definitions:
		if String(action.get("id", "")) == action_id:
			return action
	return {}


func _campaign_uses_field_objective(objective: Dictionary) -> bool:
	var objective_id := String(objective.get("id", ""))
	if objective_id.is_empty():
		return false
	var raw_objective_position: Variant = objective.get("position", [])
	var objective_position_is_valid: bool = raw_objective_position is Array and raw_objective_position.size() == 2
	var objective_position := _normalized_world_position(raw_objective_position) if objective_position_is_valid else Vector2.ZERO
	var visual_prop := String(objective.get("visual_prop", "signal_pylon"))
	for action: Dictionary in _campaign_action_definitions:
		if String(action.get("field_objective", "")) == objective_id:
			return true
		if not objective_position_is_valid or visual_prop.is_empty() or String(action.get("prop", "")) != visual_prop:
			continue
		var raw_action_position: Variant = action.get("position", [])
		if not raw_action_position is Array or raw_action_position.size() != 2:
			continue
		if _normalized_world_position(raw_action_position).is_equal_approx(objective_position):
			return true
	return false


func _spawn_campaign_actions() -> void:
	if _campaign_action_definitions.is_empty():
		return
	for action_data: Dictionary in _campaign_action_definitions:
		var action := CAMPAIGN_ACTION_SCRIPT.new() as Node2D
		if action == null:
			continue
		action.name = "CampaignAction_%s" % String(action_data.get("id", "Action"))
		action.call("setup", action_data, player, self, route_id, world_size, _campaign_action_definitions)
		add_child(action)


func _spawn_authored_architecture() -> void:
	var file := FileAccess.open("res://data/art/world_v2.json", FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return
	var modules: Dictionary = parsed.get("modules", {})
	var composition: Dictionary = parsed.get("routes", {}).get(route_id, {})
	_spawn_architecture_ground(composition)
	var cutout_shader := Shader.new()
	cutout_shader.code = "shader_type canvas_item; uniform float alpha_cutoff = 0.65; void fragment() { if (texture(TEXTURE, UV).a < alpha_cutoff) { discard; } }"
	var cutout_materials: Dictionary = {}
	for placement: Dictionary in composition.get("placements", []):
		var module_id := String(placement.get("module", ""))
		var module: Dictionary = modules.get(module_id, {})
		var texture := ASSET_LOADER.load_png(String(module.get("path", "")))
		var source: Array = module.get("source_rect", [])
		if texture == null or source.size() != 4:
			continue
		var cutoff := clampf(float(module.get("alpha_cutoff", 0.65)), 0.01, 0.95)
		if not cutout_materials.has(cutoff):
			var material := ShaderMaterial.new()
			material.shader = cutout_shader
			material.set_shader_parameter("alpha_cutoff", cutoff)
			cutout_materials[cutoff] = material
		var cutout: ShaderMaterial = cutout_materials[cutoff]
		var anchor := _normalized_world_position(placement.get("position", [0.5, 0.5]))
		var footprints: Array[Rect2] = []
		var overlaps_saved_player := false
		for raw_footprint: Array in module.get("footprints", []):
			var footprint := Rect2(float(raw_footprint[0]), float(raw_footprint[1]), float(raw_footprint[2]), float(raw_footprint[3]))
			footprints.append(footprint)
			if footprint.grow(48.0).has_point(player.position - anchor):
				overlaps_saved_player = true
		if overlaps_saved_player:
			continue
		var body := StaticBody2D.new()
		body.name = "Architecture_%s_%d" % [module_id, _architecture_visual_regions.size()]
		body.position = anchor
		body.add_to_group("obstacle")
		body.add_to_group("world_architecture")
		body.set_meta("map_label", String(module.get("label", "建築遺構")))
		if not bool(module.get("authored_ground_contact", false)) and not WORLD_PROP_SCRIPT.material_kit().is_empty():
			for footprint: Rect2 in footprints:
				_add_architecture_contact(body, footprint, cutout)
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(float(source[0]), float(source[1]), float(source[2]), float(source[3]))
		atlas.filter_clip = true
		var sprite := Sprite2D.new()
		sprite.texture = atlas
		var mask_key := "%s:%s:%d" % [String(module.get("path", "")), source, int(cutoff * 255.0)]
		if not _architecture_occlusion_masks.has(mask_key):
			var opacity_mask := BitMap.new()
			opacity_mask.create_from_image_alpha(atlas.get_image(), maxf(0.5, cutoff))
			_architecture_occlusion_masks[mask_key] = opacity_mask
		sprite.set_meta("occlusion_mask", _architecture_occlusion_masks[mask_key])
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.material = cutout
		sprite.centered = false
		var ratio := float(module.get("width", source[2])) / float(source[2])
		var visible_size := Vector2(float(source[2]), float(source[3])) * ratio
		sprite.scale = Vector2.ONE * ratio
		sprite.position = Vector2(-visible_size.x * 0.5, -visible_size.y)
		var source_foot: Array = module.get("foot", [])
		if source_foot.size() == 2:
			sprite.position = -Vector2(float(source_foot[0]) - float(source[0]), float(source_foot[1]) - float(source[1])) * ratio
		body.add_child(sprite)
		for footprint: Rect2 in footprints:
			var collision := CollisionShape2D.new()
			var rectangle := RectangleShape2D.new()
			rectangle.size = footprint.size
			collision.shape = rectangle
			collision.position = footprint.get_center()
			body.add_child(collision)
			_architecture_regions.append(Rect2(anchor + footprint.position, footprint.size))
		_architecture_visual_regions.append(Rect2(anchor + sprite.position, visible_size))
		_architecture_sprites.append(sprite)
		add_child(body)
	_spawn_authored_cover(composition)


func _add_architecture_contact(body: Node2D, footprint: Rect2, cutout: ShaderMaterial) -> void:
	# A collision foot may extend below the sprite. Soil contact stays at the art base.
	var base := snappedf(minf(0.0, footprint.end.y), 2.0)
	var half_patch := minf(24.0, footprint.size.x * 0.16)
	var rubble: Dictionary = WORLD_PROP_SCRIPT.material_kit().get("props", {}).get("rubble_b", {})
	var source: Array = rubble.get("source_rect", [])
	var foot: Array = rubble.get("foot", [])
	var texture := ASSET_LOADER.load_png(String(rubble.get("path", "")))
	for side in [-1.0, 1.0]:
		var x := snappedf(footprint.position.x + 10.0 if side < 0.0 else footprint.end.x - 10.0, 2.0)
		var soil := Polygon2D.new()
		soil.name = "MasonryCornerSoil"
		soil.position = Vector2(x, base)
		soil.polygon = PackedVector2Array([Vector2(-half_patch, -4), Vector2(half_patch - 6, -2), Vector2(half_patch + 4, 0), Vector2(half_patch - 2, 2), Vector2(2, 4), Vector2(-half_patch + 4, 2)])
		soil.color = Color8(66, 57, 45, 75)
		body.add_child(soil)
		var contact := Polygon2D.new()
		contact.name = "MasonryCornerContact"
		contact.position = Vector2(x, base)
		contact.polygon = PackedVector2Array([Vector2(-half_patch * 0.65, -2), Vector2(half_patch * 0.7, -2), Vector2(half_patch * 0.6, 0), Vector2(-half_patch * 0.5, 2)])
		contact.color = Color8(24, 27, 23, 68)
		body.add_child(contact)
		if texture == null or source.size() != 4 or foot.size() != 2:
			continue
		# Small original kit fragments break the facade edge; no new collision body.
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(float(source[0]), float(source[1]), float(source[2]), float(source[3]))
		atlas.filter_clip = true
		var debris := Sprite2D.new()
		debris.name = "MasonryCornerRubble"
		debris.texture = atlas
		debris.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		debris.material = cutout
		debris.centered = false
		var ratio := minf(36.0, footprint.size.x * 0.3) / float(source[2])
		debris.scale = Vector2.ONE * ratio
		debris.position = Vector2(x + side * 12.0, base + 4.0) - Vector2(float(foot[0]) - float(source[0]), float(foot[1]) - float(source[1])) * ratio
		body.add_child(debris)


func _spawn_authored_cover(composition: Dictionary) -> void:
	for cover: Dictionary in composition.get("decorations", []):
		var prop := WORLD_PROP_SCRIPT.new() as WorldProp
		var size: Array = cover.get("size", [104, 90])
		prop.setup(String(cover.get("prop", "wreck")), bool(cover.get("blocking", true)), Vector2i(int(size[0]), int(size[1])), route_id)
		prop.position = _normalized_world_position(cover.get("position", [0.5, 0.5]))
		prop.name = "AuthoredCover_%s_%d" % [prop.prop_id, get_child_count()]
		add_child(prop)
		var overlaps_contract_approach := false
		for region: Rect2 in _contract_field_regions:
			overlaps_contract_approach = overlaps_contract_approach or prop.get_visual_bounds().intersects(region)
		for region: Rect2 in _campaign_regions:
			overlaps_contract_approach = overlaps_contract_approach or prop.get_visual_bounds().intersects(region)
		if overlaps_contract_approach:
			remove_child(prop)
			prop.queue_free()
			continue
		if prop.get_collision_bounds().grow(48.0).has_point(player.position):
			remove_child(prop)
			prop.queue_free()
		else:
			_authored_cover_count += 1




func _spawn_architecture_ground(composition: Dictionary) -> void:
	for area: Dictionary in composition.get("ground_areas", []):
		var values: Array = area.get("rect", [])
		if values.size() != 4 or not bool(area.get("blocking", false)):
			continue
		var rect := Rect2(float(values[0]) * world_size.x, float(values[1]) * world_size.y, float(values[2]) * world_size.x, float(values[3]) * world_size.y)
		var outline := BACKDROP_SCRIPT.parse_ground_outline(area.get("outline", null), world_size, rect)
		if outline.is_empty():
			var far_edge := (rect.end / 32.0).ceil() * 32.0
			rect.position = (rect.position / 32.0).floor() * 32.0
			rect.end = far_edge
			# Preserve the legacy rectangle and saved-player escape path when no valid outline exists.
			if rect.grow(48.0).has_point(player.position):
				continue
		elif rect.grow(48.0).has_point(player.position) and BACKDROP_SCRIPT.ground_outline_contains_or_near(outline, player.position, 48.0):
			continue
		var body := StaticBody2D.new()
		body.name = "TerrainBasin_%s_%d" % [String(area.get("kind", "water")), _architecture_regions.size()]
		body.position = rect.get_center()
		body.add_to_group("obstacle")
		if outline.is_empty():
			var collision_shape := CollisionShape2D.new()
			var rectangle := RectangleShape2D.new()
			rectangle.size = rect.size
			collision_shape.shape = rectangle
			body.add_child(collision_shape)
		else:
			var collision_polygon := CollisionPolygon2D.new()
			var local_outline := PackedVector2Array()
			for point: Vector2 in outline:
				local_outline.append(point - body.position)
			collision_polygon.polygon = local_outline
			body.add_child(collision_polygon)
		add_child(body)
		_architecture_regions.append(rect)


func _refresh_architecture_occlusion() -> void:
	if player == null:
		return
	var subjects: Array[Node2D] = [player]
	for candidate: Node in get_tree().get_nodes_in_group("campaign_follower"):
		var follower := candidate as Node2D
		if follower != null and is_ancestor_of(follower) and not follower.is_queued_for_deletion() and follower.is_visible_in_tree():
			subjects.append(follower)
	for index in range(_architecture_sprites.size()):
		var sprite := _architecture_sprites[index]
		var obscures_subject := false
		for subject: Node2D in subjects:
			var subject_position := to_local(subject.global_position)
			var silhouette := Rect2(subject_position + Vector2(-30, -102), Vector2(60, 112))
			if subject_position.y >= sprite.get_parent().position.y or not _architecture_visual_regions[index].intersects(silhouette):
				continue
			var mask: BitMap = sprite.get_meta("occlusion_mask", null)
			for offset: Vector2 in [Vector2(0, -92), Vector2(-16, -70), Vector2(16, -70), Vector2(0, -44), Vector2(0, -16)]:
				var local_point := Vector2i(sprite.to_local(subject.global_position + offset).floor())
				if mask != null and Rect2i(Vector2i.ZERO, mask.get_size()).has_point(local_point) and mask.get_bitv(local_point):
					obscures_subject = true
					break
			if obscures_subject:
				break
		sprite.self_modulate.a = 0.32 if obscures_subject else 1.0


func _spawn_story_site() -> void:
	var story_events: Array[Dictionary] = DataRegistry.story_events_for_route(route_id)
	var site_data: Dictionary = route_data.get("story_site", {})
	var walkup_data: Variant = site_data.get("walkup", [])
	if story_events.is_empty() or not walkup_data is Array or walkup_data.size() != 2:
		return

	var event_data: Dictionary = story_events[0]
	var event_id: String = String(event_data.get("id", ""))
	var chapter: int = int(event_data.get("chapter", 0))
	var event_name: String = String(event_data.get("name", "劇情線索"))
	var walkup_position := Vector2(float(walkup_data[0]) * world_size.x, float(walkup_data[1]) * world_size.y)
	var site := Node2D.new()
	site.name = "StorySite_%s" % route_id
	site.global_position = walkup_position
	site.add_to_group("story_site")
	site.add_to_group("map_event")
	site.set_meta("story_event_id", event_id)
	site.set_meta("story_route_id", route_id)
	site.set_meta("story_chapter", chapter)
	site.set_meta("map_label", "第 %d 章｜%s" % [chapter, event_name])
	site.set_meta("map_marker", "event")
	add_child(site)

	var protected_data: Variant = site_data.get("protected_area", [700, 680])
	var protected_size := Vector2(700.0, 680.0)
	if protected_data is Array and protected_data.size() == 2:
		protected_size = Vector2(maxf(480.0, float(protected_data[0])), maxf(520.0, float(protected_data[1])))
	_story_site_regions.append(Rect2(walkup_position + Vector2(-protected_size.x * 0.5, -protected_size.y * 0.82), protected_size))

	var landmark_id: String = String(route_data.get("landmark_prop", ""))
	var landmark_offset: Vector2 = _story_site_offset(site_data.get("landmark_offset", [0, -170]), Vector2(0, -170))
	var landmark_prop: WorldProp
	if not landmark_id.is_empty():
		landmark_prop = _add_story_site_prop(landmark_id, walkup_position + landmark_offset, true, 0)
	var site_props: Variant = site_data.get("props", [])
	if site_props is Array:
		for index in range(site_props.size()):
			var prop_data: Dictionary = site_props[index]
			var prop_id := String(prop_data.get("id", ""))
			if prop_id.is_empty():
				continue
			var offset := _story_site_offset(prop_data.get("offset", [0, 0]), Vector2.ZERO)
			_add_story_site_prop(prop_id, walkup_position + offset, bool(prop_data.get("blocking", true)), index + 1)

	var interactable: Area2D = INTERACTABLE_SCRIPT.new()
	interactable.interaction_id = "event:%s:%s" % [route_id, event_id]
	interactable.prompt = "調查線索"
	interactable.radius = 112.0
	interactable.interacted.connect(_on_event_interacted)
	site.add_child(interactable)
	if is_instance_valid(landmark_prop):
		var visual_bounds := landmark_prop.get_visual_bounds()
		var prompt_anchor := Vector2(visual_bounds.get_center().x, visual_bounds.position.y - 24.0) - walkup_position
		if bool(site_data.get("hud_prompt", false)):
			interactable.prompt = "調查 %s" % event_name
			interactable.set_screen_safe_prompt(prompt_anchor)
		else:
			interactable.set_prompt_anchor(prompt_anchor)


func _story_site_offset(raw_offset: Variant, fallback: Vector2) -> Vector2:
	if raw_offset is Array and raw_offset.size() == 2:
		return Vector2(float(raw_offset[0]), float(raw_offset[1]))
	return fallback


func _spawn_contract_field_sites() -> void:
	for quest: Dictionary in DataRegistry.quests:
		var objective: Variant = quest.get("field_objective", {})
		if not objective is Dictionary or String(objective.get("route", "")) != route_id:
			continue
		if GameState.has_authored_campaign() and _campaign_uses_field_objective(objective):
			continue
		var raw_position: Variant = objective.get("position", [])
		if not raw_position is Array or raw_position.size() != 2:
			continue
		var quest_id := String(quest.get("id", ""))
		var site := Node2D.new()
		site.name = "ContractSite_%s" % quest_id
		site.position = _normalized_world_position(raw_position)
		site.add_to_group("map_event")
		site.set_meta("map_marker", "event")
		site.set_meta("field_objective_id", String(objective.get("id", "")))
		add_child(site)
		# Keep generated encounters/debris out of the device's approach.
		var approach := Rect2(site.position - Vector2(170, 180), Vector2(340, 340))
		_story_site_regions.append(approach)
		_contract_field_regions.append(approach)
		var prop := WORLD_PROP_SCRIPT.new() as WorldProp
		prop.setup(String(objective.get("visual_prop", "signal_pylon")), false, Vector2i(124, 110), route_id)
		prop.name = "ContractMechanism"
		site.add_child(prop)
		var label := Label.new()
		label.name = "ContractStatus"
		label.position = Vector2(-110, 20)
		label.size = Vector2(220, 44)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_outline_color", Color("171518"))
		label.add_theme_constant_override("outline_size", 3)
		site.add_child(label)
		_contract_field_sites[quest_id] = {"site": site, "prop": prop, "label": label, "objective": objective, "interaction": null}
	_refresh_contract_field_sites()


func _refresh_contract_field_sites() -> void:
	for quest_id: String in _contract_field_sites:
		var entry: Dictionary = _contract_field_sites[quest_id]
		var site: Node2D = entry["site"]
		var objective: Dictionary = entry["objective"]
		var label: Label = entry["label"]
		var done := GameState.field_objective_status(quest_id)
		var active := GameState.active_quest_id == quest_id
		var state_text := "已完成" if done else ("待處理" if active else "承接對應公會委託後可操作")
		if not done and GameState.completed_quests.has(quest_id):
			state_text = "既有委託已結案"
		label.text = "%s\n%s" % [String(objective.get("name", "現場設施")), state_text]
		label.modulate = Color("a7b99b") if done else Color("e3dac5")
		site.set_meta("map_label", label.text.replace("\n", "｜"))
		var interaction: Area2D = entry.get("interaction")
		if (done or not active) and is_instance_valid(interaction):
			interaction.queue_free()
			entry["interaction"] = null
		elif active and not done and not is_instance_valid(interaction):
			interaction = INTERACTABLE_SCRIPT.new()
			interaction.interaction_id = "field:%s" % quest_id
			interaction.prompt = String(objective.get("action_name", "操作設施"))
			interaction.radius = 104.0
			interaction.interacted.connect(_on_contract_field_interacted.bind(quest_id))
			site.add_child(interaction)
			var prop: WorldProp = entry["prop"]
			var bounds := prop.get_visual_bounds()
			interaction.set_prompt_anchor(Vector2(bounds.get_center().x, bounds.position.y - 24.0) - site.global_position)
			entry["interaction"] = interaction
	_refresh_contract_field_labels()


func _refresh_contract_field_labels() -> void:
	if not is_instance_valid(player):
		return
	for entry: Dictionary in _contract_field_sites.values():
		var site: Node2D = entry["site"]
		var label: Label = entry["label"]
		# Distant sites retain map markers; only nearby devices need world text.
		label.visible = player.global_position.distance_squared_to(site.global_position) <= 280.0 * 280.0


func _on_contract_field_interacted(_interaction_id: String, quest_id: String) -> void:
	if not GameState.complete_quest_field_objective(quest_id):
		return
	var objective: Dictionary = DataRegistry.get_quest(quest_id).get("field_objective", {})
	var result := String(objective.get("completed_dialogue", "現場操作已完成。"))
	if quest_id == "factory_sabotage":
		result += "\n外圍增援已受干擾：此路線一般敵人的後續補充上限降低 6；現有守衛不會消失。"
	result += "\n\n其餘擊殺、物資與返村交付條件仍需完成；此操作不另外發放報酬。"
	if GameState.has_active_expedition():
		result += "\n本趟行動待安全撤離後保留。"
	GameState.dialogue_requested.emit("R-17", String(objective.get("name", "現場行動")), result)


func _add_story_site_prop(id: String, position: Vector2, blocking: bool, index: int) -> WorldProp:
	var prop := WORLD_PROP_SCRIPT.new() as WorldProp
	prop.setup(id, blocking, _prop_size(id, index), route_id)
	prop.global_position = position
	prop.name = "StoryProp_%s_%d" % [id, index]
	add_child(prop)
	var fallback: Variant = DataRegistry.get_visual_asset("prop_%s" % id).get("saved_position_fallback_size", [])
	if GameState.active_spawn_point == "saved" and fallback is Array and fallback.size() == 2 and prop.get_collision_bounds().grow(48.0).has_point(player.position):
		# A resized landmark must not enclose a position from an older save.
		# Keep that entry's original presentation/body instead of hiding its story art.
		remove_child(prop)
		prop.free()
		prop = WORLD_PROP_SCRIPT.new() as WorldProp
		prop.setup(id, blocking, Vector2i(maxi(1, int(fallback[0])), maxi(1, int(fallback[1]))), route_id)
		prop.global_position = position
		prop.name = "StoryProp_%s_%d" % [id, index]
		prop.set_meta("saved_position_presentation_fallback", true)
		add_child(prop)
	var asset: Dictionary = DataRegistry.get_visual_asset("prop_%s" % id)
	if bool(asset.get("fade_when_occluding", false)):
		for child in prop.get_children():
			if not child is Sprite2D:
				continue
			var mask_key := "landmark:%s" % String(asset.get("path", ""))
			if not _architecture_occlusion_masks.has(mask_key):
				var opacity_mask := BitMap.new()
				opacity_mask.create_from_image_alpha(child.texture.get_image(), 0.5)
				_architecture_occlusion_masks[mask_key] = opacity_mask
			child.set_meta("occlusion_mask", _architecture_occlusion_masks[mask_key])
			_architecture_sprites.append(child)
			_architecture_visual_regions.append(prop.get_visual_bounds())
	return prop


func _configure_exploration_layout() -> void:
	var map_paths: Array[PackedVector2Array] = []
	for raw_path in route_data.get("exploration_paths", []):
		var path := PackedVector2Array()
		for raw_position in raw_path:
			path.append(_normalized_world_position(raw_position))
		for index in range(1, path.size()):
			var a: Vector2 = path[index - 1]
			var b: Vector2 = path[index]
			_exploration_path_regions.append(Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), Vector2(absf(b.x - a.x), absf(b.y - a.y))).grow(112.0))
		map_paths.append(path)
	set_meta("map_paths", map_paths)
	set_meta("map_regions", route_data.get("regions", []).duplicate(true))
	for raw_point in route_data.get("exploration_points", []):
		var point: Dictionary = raw_point.duplicate(true)
		var event_id := String(point.get("event", ""))
		var event_data := DataRegistry.get_event(event_id)
		if event_data.is_empty() or bool(event_data.get("story", false)):
			continue
		point["world_position"] = _normalized_world_position(point.get("position", [0.5, 0.5]))
		point["discovery_key"] = "%s:%s" % [route_id, event_id]
		point["active"] = false
		point["cleared"] = false
		point["guard_nodes"] = []
		_exploration_points.append(point)
		_exploration_site_regions.append(Rect2(point["world_position"] + Vector2(-340, -400), Vector2(680, 620)))


func _normalized_world_position(raw_position: Variant) -> Vector2:
	if raw_position is Array and raw_position.size() == 2:
		return Vector2(float(raw_position[0]) * world_size.x, float(raw_position[1]) * world_size.y)
	return world_size * 0.5


func _spawn_exploration_points() -> void:
	for point: Dictionary in _exploration_points:
		var center: Vector2 = point["world_position"]
		var marker := Node2D.new()
		marker.name = "Exploration_%s" % String(point["event"])
		marker.position = center
		marker.add_to_group("exploration_point")
		marker.set_meta("map_marker", "event")
		marker.set_meta("exploration_event", point["event"])
		add_child(marker)
		point["marker_node"] = marker

		var reward_prop := WORLD_PROP_SCRIPT.new() as WorldProp
		var prop_id := String(point.get("prop", "barrel_stack"))
		reward_prop.setup(prop_id, false, Vector2i(100, 90), route_id)
		reward_prop.position = center + Vector2(0, -42)
		reward_prop.name = "ExplorationReward_%s" % String(point["event"])
		add_child(reward_prop)
		point["reward_node"] = reward_prop
		var edge_prop := "scrap_wall"
		if route_id in ["toxic_marsh", "crystal_scar"]:
			edge_prop = "dead_tree" if route_id == "toxic_marsh" else "rust_rock"
		elif route_id == "ruined_metropolis":
			edge_prop = "ruin_wall"
		for offset: Vector2 in [Vector2(-255, -135), Vector2(255, -135), Vector2(205, -335)]:
			_add_exploration_edge_prop(edge_prop, center + offset)

		var area: Area2D = INTERACTABLE_SCRIPT.new()
		area.interaction_id = "exploration:%s" % String(point["event"])
		area.prompt = "調查／回收 %s" % String(point.get("name", "遺留物資"))
		area.radius = 112.0
		area.interacted.connect(_on_exploration_interacted)
		marker.add_child(area)
		point["interactable_node"] = area
		var label := Label.new()
		label.position = Vector2(-180, -222)
		label.size = Vector2(360, 66)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 15)
		label.add_theme_color_override("font_color", Color8(218, 198, 153))
		label.add_theme_color_override("font_outline_color", Color8(18, 20, 19))
		label.add_theme_constant_override("outline_size", 5)
		marker.add_child(label)
		point["status_label"] = label
		point["status_text"] = ""
		if _exploration_point_claimed(point):
			_set_exploration_status(point, "已回收")
			reward_prop.modulate = Color(0.52, 0.52, 0.48, 0.72)
		else:
			_set_exploration_status(point, "守衛盤踞・接近後交戰")


func _add_exploration_edge_prop(id: String, position: Vector2) -> void:
	var prop := WORLD_PROP_SCRIPT.new() as WorldProp
	prop.setup(id, true, Vector2i(138, 112), route_id)
	prop.position = position
	add_child(prop)
	var bounds := prop.get_visual_bounds().grow(12.0)
	var blocked := bounds.intersects(_entry_lane_bounds()) or bounds.intersects(_extraction_gate_bounds())
	for region: Rect2 in _story_site_regions:
		blocked = blocked or bounds.intersects(region)
	for region: Rect2 in _campaign_regions:
		blocked = blocked or bounds.intersects(region)
	for raw_existing in get_tree().get_nodes_in_group("world_prop"):
		var existing := raw_existing as WorldProp
		if existing != null and existing != prop and bounds.intersects(existing.get_visual_bounds().grow(8.0)):
			blocked = true
	if blocked:
		remove_child(prop)
		prop.queue_free()


func _spawn_pathside_landmarks() -> void:
	var prop_ids: Array = route_data.get("path_props", ["rust_rock", "scrap_wall"])
	var cohesive := not WORLD_PROP_SCRIPT.material_kit().is_empty()
	if cohesive:
		# Larger wrecks belong to authored sites; roadside cues stay sparse and low.
		prop_ids = ["waypost", "rubble_a", "rubble_b"]
	if prop_ids.is_empty():
		return
	var count := 0
	for path: PackedVector2Array in get_meta("map_paths", []):
		for index in range(1, path.size()):
			var a: Vector2 = path[index - 1]
			var b: Vector2 = path[index]
			var direction := (b - a).normalized()
			var normal := Vector2(-direction.y, direction.x)
			var steps := int(a.distance_to(b) / (960.0 if cohesive else 440.0))
			for step in range(1, steps + 1):
				if count >= (12 if cohesive else 30):
					return
				var center := a.lerp(b, float(step) / float(steps + 1))
				var id := String(prop_ids[count % prop_ids.size()])
				var side := -1.0 if count % 2 == 0 else 1.0
				_spawn_prop_at_safe_position(id, not cohesive, Vector2i(122, 106), [center + normal * 260.0 * side, center - normal * 260.0 * side])
				count += 1


func _exploration_point_claimed(point: Dictionary) -> bool:
	return GameState.has_field_claim(String(point["discovery_key"])) or GameState.has_field_claim(String(point["event"]))


func _exploration_draft_available(point: Dictionary) -> bool:
	var draft_id := String(point.get("draft_id", ""))
	return not draft_id.is_empty() and GameState.can_offer_expedition_draft(draft_id)


func _offer_exploration_draft(point: Dictionary) -> bool:
	if not _exploration_draft_available(point):
		return false
	GameState.offer_expedition_draft(String(point["draft_id"]))
	return true


func _set_exploration_status(point: Dictionary, status: String) -> void:
	point["status_text"] = status
	_refresh_exploration_marker(point)


func _refresh_exploration_marker(point: Dictionary) -> void:
	var draft_available := _exploration_draft_available(point)
	var status := String(point.get("status_text", ""))
	if draft_available:
		status = "%s・戰地調校可用" % status if not status.is_empty() else "戰地調校可用"
	var label: Label = point.get("status_label") as Label
	if label != null:
		label.text = "%s\n%s" % [String(point.get("name", "探索據點")), status]
	var marker: Node2D = point.get("marker_node") as Node2D
	if marker != null:
		if not _exploration_point_claimed(point) or draft_available:
			marker.add_to_group("map_event")
		else:
			marker.remove_from_group("map_event")
		var map_name := String(point.get("name", "探索據點"))
		if draft_available:
			map_name += "・戰地調校"
		marker.set_meta("map_label", "%s｜%s" % [map_name, status])
	var interactable: Area2D = point.get("interactable_node") as Area2D
	if interactable != null:
		var name := String(point.get("name", "遺留物資"))
		if draft_available and _exploration_point_claimed(point):
			interactable.set("prompt", "戰地調校・%s" % name)
		elif draft_available:
			interactable.set("prompt", "調查／回收 %s・戰地調校" % name)
		elif _exploration_point_claimed(point):
			interactable.set("prompt", "已回收・%s" % name)
		else:
			interactable.set("prompt", "調查／回收 %s" % name)


func _refresh_exploration_points() -> void:
	if player == null or not is_instance_valid(player):
		return
	for point: Dictionary in _exploration_points:
		_refresh_exploration_marker(point)
		if _exploration_point_claimed(point):
			continue
		if not bool(point["active"]) and player.global_position.distance_to(point["world_position"]) <= 520.0:
			_activate_exploration_point(point)
		if not bool(point["active"]) or bool(point["cleared"]):
			continue
		var living := 0
		for guard in point["guard_nodes"]:
			if is_instance_valid(guard) and not bool(guard.get("is_dead")):
				living += 1
		if living == 0:
			point["cleared"] = true
			_set_exploration_status(point, "守衛已清除・按 E 回收")
			GameState.notify("%s 已肅清。返回據點按 E 回收遺留物資。" % String(point["name"]))
			AudioManager.play_sfx("quest_complete")
		else:
			_set_exploration_status(point, "剩餘守衛 %d・清除後回收" % living)


func _activate_exploration_point(point: Dictionary) -> void:
	if bool(point["active"]) or _exploration_point_claimed(point):
		return
	var guard_ids: Array = point.get("guards", [])
	var guards: Array = []
	var center: Vector2 = point["world_position"]
	for index in range(guard_ids.size()):
		var id := String(guard_ids[index])
		var data := DataRegistry.get_enemy(id)
		if data.is_empty() or String(data.get("type", "")) == "boss":
			continue
		for attempt in range(16):
			var angle := -PI * 0.5 + TAU * float(index) / float(maxi(1, guard_ids.size())) + float(attempt) * 0.38
			var position := center + Vector2(cos(angle), sin(angle)) * (218.0 + float(attempt % 3) * 30.0)
			if not _enemy_spawn_position_is_clear(position, 42.0):
				continue
			if _normal_enemy_count() >= _normal_enemy_limit() and not _despawn_farthest_normal_enemy():
				break
			var guard: CharacterBody2D = ENEMY_SCRIPT.new()
			guard.setup(id, data, player)
			guard.position = position
			guard.set_meta("exploration_guard", String(point["discovery_key"]))
			add_child(guard)
			guards.append(guard)
			break
	if guards.size() != guard_ids.size():
		for guard in guards:
			remove_child(guard)
			guard.queue_free()
		return
	point["guard_nodes"] = guards
	point["active"] = true
	_set_exploration_status(point, "剩餘守衛 %d・清除後回收" % guards.size())
	GameState.notify("發現 %s：擊倒 %d 名守衛，再按 E 回收物資。" % [String(point["name"]), guards.size()])


func _on_exploration_interacted(interaction_id: String) -> void:
	if GameState.death_pending or GameState.hp <= 0 or GameState.current_scene_id != "wasteland" or GameState.current_route_id != route_id:
		return
	var event_id := interaction_id.trim_prefix("exploration:")
	for point: Dictionary in _exploration_points:
		if String(point["event"]) != event_id:
			continue
		if _exploration_point_claimed(point):
			if not _offer_exploration_draft(point):
				GameState.notify("%s 的物資已經回收過。" % String(point["name"]))
			_refresh_exploration_marker(point)
			return
		_activate_exploration_point(point)
		_refresh_exploration_points()
		if not bool(point["cleared"]):
			GameState.notify("%s 仍有守衛，先肅清附近的威脅。" % String(point["name"]))
			return
		GameState.record_field_claim(String(point["discovery_key"]))
		var rewards: Dictionary = point.get("reward", {})
		var summary: Array[String] = []
		for item_id in rewards:
			var amount := int(rewards[item_id])
			GameState.add_field_item(String(item_id), amount)
			summary.append("%s ×%d" % [GameState.item_display_name(String(item_id)), amount])
		_set_exploration_status(point, "已回收")
		var reward_prop: WorldProp = point["reward_node"]
		reward_prop.modulate = Color(0.52, 0.52, 0.48, 0.72)
		GameState.notify("%s：%s\n獲得 %s" % [String(point["name"]), String(point.get("description", "回收完成。")), "、".join(summary)])
		GameState.stats_changed.emit()
		AudioManager.play_sfx("pickup")
		_offer_exploration_draft(point)
		_refresh_exploration_marker(point)
		SaveManager.save_game(false)
		return


func _update_region_notice() -> void:
	if player == null or not is_instance_valid(player):
		return
	var nearest := ""
	var distance := 900.0
	for region: Dictionary in route_data.get("regions", []):
		var region_distance := player.global_position.distance_to(_normalized_world_position(region.get("center", [])))
		if region_distance < distance:
			distance = region_distance
			nearest = String(region.get("name", ""))
	if not nearest.is_empty() and nearest != _current_region:
		_current_region = nearest
		set_meta("current_region", nearest)
		GameState.notify("抵達 %s。沿道路尋找守衛據點與遺留物資。" % nearest)


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
	var global_events: Array[Dictionary] = []
	for event_data: Dictionary in DataRegistry.events:
		var authored := false
		for point: Dictionary in _exploration_points:
			if String(point["event"]) == String(event_data.get("id", "")):
				authored = true
		if not bool(event_data.get("story", false)) and not authored:
			global_events.append(event_data)
	var event_count: int = mini(int(DataRegistry.map_params.get("event_nodes", DEFAULT_EVENT_NODES)), global_events.size())
	var positions: Array = LEVEL_GENERATOR_SCRIPT.seeded_positions(event_count, Rect2(300, 320, world_size.x - 600, world_size.y - 1100), route_seed + 25, 520, _placement_blocked_regions(120.0))
	for i in range(positions.size()):
		var event_data: Dictionary = global_events[i]
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
		if not WORLD_PROP_SCRIPT.material_kit().is_empty():
			var prop := WORLD_PROP_SCRIPT.new() as WorldProp
			prop.setup(String(event_data.get("visual_prop", "barrel_stack")), false, Vector2i(96, 84), route_id)
			prop.name = "EventRemnant_%s" % String(event_data.get("id", "event"))
			node.add_child(prop)
		else:
			var marker := Sprite2D.new()
			var marker_item := "bio_crystal" if i % 2 == 0 else "mutant_core"
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
	if _campaign_outing_actions_complete():
		return
	var limit: int = _normal_enemy_limit()
	var count: int = _normal_enemy_count()
	while count < limit:
		if not _spawn_enemy_at(_enemy_id_for_spawn(), _spawn_position_near_player(720.0, 1260.0)):
			break
		count += 1


func _campaign_outing_actions_complete() -> bool:
	if not GameState.has_authored_campaign():
		return false
	var outing := GameState.campaign_outing()
	var actions: Array = outing.get("actions", [])
	if actions.is_empty():
		return false
	for definition: Dictionary in actions:
		if GameState.campaign_action_status(String(definition.get("id", ""))) != "done":
			return false
	return true


func _normal_enemy_limit() -> int:
	var total_limit := _normal_enemy_cap()
	if _campaign_wave_slots_needed():
		total_limit = maxi(0, total_limit - 2)
	return total_limit


func _normal_enemy_cap() -> int:
	var total_limit: int = clampi(int(DataRegistry.map_params.get("enemy_limit", DEFAULT_ENEMY_LIMIT)), 0, MAX_ACTIVE_ENEMIES)
	if route_id == "old_factory" and GameState.field_objective_status("factory_sabotage"):
		total_limit = maxi(0, total_limit - 6)
	if _boss_should_exist() or boss_spawned or _active_boss_count() > 0:
		return max(0, total_limit - 1)
	return total_limit


func _campaign_wave_slots_needed() -> bool:
	for action: Dictionary in _campaign_action_definitions:
		if int(action.get("waves", 0)) > 0:
			return true
		for raw_option in action.get("options", []):
			if raw_option is Dictionary and int(raw_option.get("waves", 0)) > 0:
				return true
		var route_choice_id := String(action.get("route_choice", ""))
		if route_choice_id.is_empty():
			continue
		var choice := _campaign_action_by_id(route_choice_id)
		for raw_option in choice.get("options", []):
			if raw_option is Dictionary and int(raw_option.get("waves", 0)) > 0:
				return true
	return false


func _boss_should_exist() -> bool:
	var trigger_count: int = int(DataRegistry.map_params.get("boss_spawn_after_defeats", 40))
	var story_boss_source := _story_boss_source_key()
	var boss_is_story_objective: bool = not story_boss_source.is_empty()
	if boss_is_story_objective:
		if GameState.has_active_expedition() and GameState.has_run_source(story_boss_source):
			return false
		return not DataRegistry.get_enemy(BOSS_ID).is_empty()
	return bool(route_data.get("boss_enabled", false)) and GameState.defeated_enemies >= trigger_count and not DataRegistry.get_enemy(BOSS_ID).is_empty()


func _story_boss_source_key() -> String:
	if (route_id == "old_factory" and GameState.active_quest_id == "old_factory_core") or (route_id == "underground_facility" and GameState.active_quest_id == "facility_memory"):
		return "boss:%s:%s" % [route_id, BOSS_ID]
	return ""


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
	return _spawn_enemy_at_for_campaign(id, position, "", -1)


func _spawn_enemy_at_for_campaign(id: String, position: Vector2, campaign_action_id: String, campaign_wave_index: int) -> bool:
	var data: Dictionary = DataRegistry.get_enemy(id)
	if data.is_empty() or position.x < 96.0 or position.y < 96.0 or position.x > world_size.x - 96.0 or position.y > world_size.y - 96.0:
		return false
	if not _enemy_spawn_position_is_clear(position, 42.0, not campaign_action_id.is_empty()):
		return false
	var enemy: CharacterBody2D = ENEMY_SCRIPT.new()
	enemy.setup(id, data, player)
	if not campaign_action_id.is_empty():
		enemy.set_meta("campaign_action_id", campaign_action_id)
		enemy.set_meta("campaign_wave_index", campaign_wave_index)
	enemy.global_position = position
	add_child(enemy)
	return true


func spawn_campaign_wave(campaign_action_id: String, wave_index: int, wave_size: int, center: Vector2) -> int:
	if campaign_action_id.is_empty() or combat_enemy_ids.is_empty() or GameState.campaign_action_status(campaign_action_id) != "active":
		return 0
	var target_count := clampi(wave_size, 0, 3)
	var spawned := 0
	for index in range(target_count):
		if _normal_enemy_count() >= _normal_enemy_cap():
			break
		var placed := false
		for attempt in range(12):
			var angle := TAU * float(index * 3 + wave_index * 2 + attempt) / float(maxi(6, target_count * 3))
			var radius := 236.0 + float((attempt + index) % 3) * 44.0
			var candidate := (center + Vector2(cos(angle), sin(angle)) * radius).clamp(Vector2(96, 96), world_size - Vector2(96, 96))
			if _spawn_enemy_at_for_campaign(_enemy_id_for_spawn(), candidate, campaign_action_id, wave_index):
				spawned += 1
				placed = true
				break
		if not placed:
			break
	return spawned


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


func _enemy_spawn_position_is_clear(position: Vector2, radius: float, allow_story_site := false) -> bool:
	var candidate_bounds := Rect2(position - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
	if candidate_bounds.intersects(_entry_lane_bounds()) or candidate_bounds.intersects(_extraction_gate_bounds()):
		return false
	if not allow_story_site:
		for site_region: Rect2 in _story_site_regions:
			if candidate_bounds.intersects(site_region):
				return false
	for architecture_region: Rect2 in _architecture_regions:
		if candidate_bounds.intersects(architecture_region.grow(8.0)):
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


func _despawn_farthest_normal_enemy() -> bool:
	var farthest: Node2D = null
	var farthest_distance: float = -1.0
	var center: Vector2 = player.global_position if player != null and is_instance_valid(player) else Vector2.ZERO
	for raw_node in get_tree().get_nodes_in_group("enemy"):
		var node: Node2D = raw_node as Node2D
		if node == null or not is_instance_valid(node) or node.is_in_group("boss") or node.has_meta("exploration_guard") or node.has_meta("campaign_action_id"):
			continue
		var distance: float = center.distance_to(node.global_position)
		if distance > farthest_distance:
			farthest_distance = distance
			farthest = node
	if farthest != null:
		remove_child(farthest)
		farthest.queue_free()
		return true
	return false


func _spawn_boss(spawn_position: Vector2) -> bool:
	var boss_data: Dictionary = DataRegistry.get_enemy(BOSS_ID)
	if boss_data.is_empty() or spawn_position.x < 96.0:
		return false
	if not _enemy_spawn_position_is_clear(spawn_position, 64.0):
		return false
	var boss: CharacterBody2D = ENEMY_SCRIPT.new()
	boss.setup(BOSS_ID, boss_data, player)
	var source_key := _story_boss_source_key()
	if not source_key.is_empty():
		boss.set_meta("expedition_source_key", source_key)
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
	prop.setup(id, blocking, size, route_id)
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
	for region: Rect2 in _architecture_visual_regions:
		blocked.append(region.grow(padding))
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
	var regions: Array[Rect2] = [_entry_lane_bounds(), _extraction_gate_bounds()]
	regions.append_array(_architecture_regions)
	regions.append_array(_architecture_visual_regions)
	regions.append_array(_story_site_regions)
	regions.append_array(_campaign_regions)
	regions.append_array(_exploration_site_regions)
	regions.append_array(_exploration_path_regions)
	if player != null and is_instance_valid(player):
		regions.append(Rect2(player.global_position + Vector2(-88, -102), Vector2(176, 118)))
	return regions


func _return_gate_world_position() -> Vector2:
	var raw_position: Variant = route_data.get("return_gate_position", [])
	if raw_position is Array and raw_position.size() == 2:
		return _normalized_world_position(raw_position).clamp(Vector2(128.0, 128.0), world_size - Vector2(128.0, 128.0))
	return Vector2(world_size.x * 0.5, world_size.y - 90.0)


func _extraction_gate_bounds() -> Rect2:
	var position := _return_gate_world_position()
	return Rect2(position + Vector2(-250.0, -220.0), Vector2(500.0, 560.0))


func _entry_lane_bounds() -> Rect2:
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
	var event_route: String = event_id.substr(0, separator) if separator >= 0 else route_id
	var bare_event_id: String = event_id.substr(separator + 1) if separator >= 0 else event_id
	var event_data: Dictionary = DataRegistry.get_event(bare_event_id)
	if event_data.is_empty():
		GameState.notify("找不到這份事件紀錄。")
		return
	if bool(event_data.get("story", false)):
		if event_route != route_id or String(event_data.get("route", "")) != event_route:
			GameState.notify("這份劇情紀錄不屬於目前路線。")
			return
		if GameState.has_story_discovery(event_route, bare_event_id):
			GameState.notify("這份劇情紀錄已經整理過。")
			return
		if not GameState.is_story_event_unlocked(bare_event_id):
			match event_route:
				"ruined_metropolis":
					GameState.notify("完成前四條主線委託後，檔案庫才會回應。")
				"underground_facility":
					GameState.notify("先完成都心檔案委託，才能讀取研究設施的記憶。")
				_:
					GameState.notify("這段劇情紀錄目前尚未可讀。")
			return
		GameState.record_story_discovery(event_route, bare_event_id)
		GameState.stats_changed.emit()
		var chapter: int = int(event_data.get("chapter", 0))
		var body := "%s\n\n%s" % [String(event_data.get("description", "")), String(event_data.get("revelation", ""))]
		GameState.dialogue_requested.emit(String(event_data.get("name", "劇情紀錄")), "第 %d 章・劇情線索" % chapter, body)
		SaveManager.save_game(false)
		return
	if GameState.has_field_claim(event_id) or GameState.has_field_claim(bare_event_id):
		GameState.notify("這個事件已經回收過。")
		return
	GameState.record_field_claim(event_id)
	var reward: Dictionary = event_data.get("reward", {})
	for item_id in reward.keys():
		GameState.add_field_item(String(item_id), int(reward[item_id]))
	var event_name: String = String(event_data.get("name", event_id))
	var description: String = String(event_data.get("description", ""))
	GameState.notify("%s 完成：%s" % [event_name, description])
	SaveManager.save_game(false)


func _hash2i(x: int, y: int) -> int:
	var n: int = int(route_seed) + x * 374761393 + y * 668265263
	n = (n ^ (n >> 13)) * 1274126177
	return abs(n ^ (n >> 16))
