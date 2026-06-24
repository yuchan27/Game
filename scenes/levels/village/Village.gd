extends Node2D

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const HUD_SCENE := preload("res://scenes/ui/HUD.tscn")
const PIXEL := preload("res://scripts/utils/PixelArtFactory.gd")
const ASSET_LOADER := preload("res://scripts/utils/RuntimeAssetLoader.gd")
const VILLAGE_TILEMAP_SCRIPT := preload("res://scripts/systems/VillageTileMap.gd")
const INTERACTABLE_SCRIPT := preload("res://scripts/components/Interactable.gd")
const ROUTE_GATE_SCRIPT := preload("res://scripts/components/RouteGate.gd")
const DIALOGUE_NPC_SCRIPT := preload("res://scripts/components/DialogueNpc.gd")
const INVENTORY_SCRIPT := preload("res://scripts/systems/InventorySystem.gd")
const PROJECTILE_POOL_SCRIPT := preload("res://scripts/systems/ProjectilePool.gd")
const WORLD_PROP_SCRIPT := preload("res://scripts/components/WorldProp.gd")

const MAP_TILES := Vector2i(78, 56)
const TILE_SIZE := 32
const WORLD_RECT := Rect2(Vector2(48, 48), Vector2(MAP_TILES.x * TILE_SIZE - 96, MAP_TILES.y * TILE_SIZE - 96))

const STATION_ASSETS := {
	"forge": "structure_forge",
	"craft": "structure_craft",
	"shop": "structure_shop",
	"mod": "structure_mod_station",
	"recycle": "structure_recycle_machine",
	"save": "structure_save_station",
	"to_guild": "structure_guild_gate",
	"route_gate": "structure_wasteland_gate"
}

var player: Node2D

func _ready() -> void:
	y_sort_enabled = true
	GameState.current_scene_id = "village"
	set_meta("map_world_size", Vector2(MAP_TILES.x * TILE_SIZE, MAP_TILES.y * TILE_SIZE))
	set_meta("map_scene_label", "廢土村莊")
	AudioManager.play_music("village")

	var tilemap: TileMap = VILLAGE_TILEMAP_SCRIPT.new()
	tilemap.setup(MAP_TILES, 137)
	add_child(tilemap)
	_add_boundaries(Vector2(MAP_TILES.x * TILE_SIZE, MAP_TILES.y * TILE_SIZE))
	_add_decor()
	_add_stations()
	_add_route_gates()
	_spawn_npcs()
	_add_projectile_pool(200)
	_spawn_player(_spawn_position())
	add_child(HUD_SCENE.instantiate())
	GameState.notify("村莊據點：合成前期裝備，三階武器與後三階護甲需到冒險公會完成委託取得。")

func _spawn_position() -> Vector2:
	match GameState.active_spawn_point:
		"from_wasteland":
			return Vector2(1248, 980)
		"from_guild":
			return Vector2(1580, 820)
		"clinic":
			return Vector2(1040, 1030)
		"saved":
			return GameState.player_position
		_:
			return Vector2(1248, 920)

func _spawn_player(default_position: Vector2) -> void:
	player = PLAYER_SCENE.instantiate()
	player.global_position = default_position
	add_child(player)
	if player.has_method("set_world_bounds"):
		player.set_world_bounds(WORLD_RECT)

func _add_projectile_pool(limit: int) -> void:
	var pool: Node = PROJECTILE_POOL_SCRIPT.new()
	pool.max_projectiles = limit
	add_child(pool)

func _add_stations() -> void:
	_add_station("forge", "鍛造爐：廢鐵 x8 → 彈藥 x12", Vector2(1248, 370), Color8(102, 68, 45), "鍛造")
	_add_station("craft", "合成台：二階近戰 / 前三階護甲", Vector2(680, 650), Color8(72, 92, 96), "合成")
	_add_station("shop", "補給商：廢鐵 x4 → 彈藥 x8", Vector2(1810, 650), Color8(93, 75, 47), "商店")
	_add_station("mod", "改裝站：二階遠程武器", Vector2(720, 1130), Color8(54, 77, 91), "改裝")
	_add_station("recycle", "拆解機：核心 x1 → 材料", Vector2(1248, 1180), Color8(69, 88, 78), "拆解")
	_add_station("save", "維修存檔點：修復與儲存", Vector2(1760, 1130), Color8(42, 92, 108), "存檔")
	_add_station("to_guild", "前往冒險公會：接任務拿高階裝備", Vector2(2060, 900), Color8(90, 82, 120), "公會")

func _add_route_gates() -> void:
	_add_route_gate("crystal_scar", "北門：紫晶裂隙", Vector2(1248, 170))
	_add_route_gate("scrap_highway", "南門：廢鐵公路", Vector2(1248, 1560))
	_add_route_gate("toxic_marsh", "西門：毒沼排水區", Vector2(230, 900))
	_add_route_gate("old_factory", "東門：舊工廠外圍", Vector2(2260, 900))

func _add_station(id: String, label: String, pos: Vector2, color: Color, map_label: String) -> void:
	var node := Node2D.new()
	node.position = pos
	node.y_sort_enabled = true
	node.add_to_group("map_station")
	node.set_meta("map_label", map_label)
	node.set_meta("map_marker", "station")
	add_child(node)
	var sprite := Sprite2D.new()
	var texture := _station_texture(id)
	sprite.texture = texture if texture != null else PIXEL.new().make_texture(Vector2i(180, 110), [color.darkened(0.35), color, color.lightened(0.18)], id.length())
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var texture_size := sprite.texture.get_size()
	sprite.centered = false
	sprite.position = Vector2(-texture_size.x * 0.5, -texture_size.y)
	node.add_child(sprite)
	_add_station_collision(node, texture_size)
	var interactable: Area2D = INTERACTABLE_SCRIPT.new()
	interactable.interaction_id = id
	interactable.prompt = label
	interactable.radius = max(texture_size.x, texture_size.y) * 0.34
	interactable.interacted.connect(_on_station_interacted)
	node.add_child(interactable)

func _add_station_collision(node: Node2D, texture_size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.add_to_group("obstacle")
	var shape := RectangleShape2D.new()
	shape.size = Vector2(max(52.0, texture_size.x * 0.58), max(22.0, texture_size.y * 0.18))
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0, -shape.size.y * 0.5)
	body.add_child(collision)
	node.add_child(body)

func _add_route_gate(route_id: String, label: String, pos: Vector2) -> void:
	var node := Node2D.new()
	node.position = pos
	node.y_sort_enabled = true
	node.add_to_group("map_gate")
	node.set_meta("map_label", label)
	node.set_meta("map_marker", "gate")
	add_child(node)
	var sprite := Sprite2D.new()
	sprite.texture = _station_texture("route_gate")
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if sprite.texture != null:
		var texture_size := sprite.texture.get_size()
		sprite.centered = false
		sprite.position = Vector2(-texture_size.x * 0.5, -texture_size.y)
	node.add_child(sprite)
	var gate := ROUTE_GATE_SCRIPT.new()
	gate.setup_route(route_id, label, Vector2.ZERO, 76.0)
	gate.interacted.connect(_on_route_gate_interacted)
	node.add_child(gate)

func _station_texture(id: String) -> Texture2D:
	var asset_id := String(STATION_ASSETS.get(id, ""))
	var path := DataRegistry.asset_path(asset_id)
	return ASSET_LOADER.load_png(path) if not path.is_empty() else null

func _add_decor() -> void:
	var props := [
		["scrap_wall", Vector2(440, 330), true, Vector2i(110, 72)],
		["scrap_wall", Vector2(2050, 330), true, Vector2i(110, 72)],
		["rust_rock", Vector2(920, 360), true, Vector2i(78, 62)],
		["dead_tree", Vector2(1510, 500), true, Vector2i(72, 110)],
		["road_marker", Vector2(1248, 760), false, Vector2i(44, 58)],
		["road_marker", Vector2(1248, 1060), false, Vector2i(44, 58)],
		["signal_pylon", Vector2(2050, 1240), true, Vector2i(72, 128)],
		["toxic_pool", Vector2(430, 1220), false, Vector2i(86, 50)],
		["wreck", Vector2(1980, 1420), true, Vector2i(116, 80)],
		["scrap_barricade", Vector2(1500, 1460), true, Vector2i(120, 72)]
	]
	for prop_data in props:
		var prop: StaticBody2D = WORLD_PROP_SCRIPT.new()
		prop.setup(String(prop_data[0]), bool(prop_data[2]), prop_data[3])
		prop.global_position = prop_data[1]
		add_child(prop)

func _add_boundaries(world_size: Vector2) -> void:
	_add_boundary(Vector2(world_size.x * 0.5, 12), Vector2(world_size.x, 24))
	_add_boundary(Vector2(world_size.x * 0.5, world_size.y - 12), Vector2(world_size.x, 24))
	_add_boundary(Vector2(12, world_size.y * 0.5), Vector2(24, world_size.y))
	_add_boundary(Vector2(world_size.x - 12, world_size.y * 0.5), Vector2(24, world_size.y))

func _add_boundary(pos: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.add_to_group("obstacle")
	body.position = pos
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

func _spawn_npcs() -> void:
	for npc_data in DataRegistry.npcs_for_scene("village"):
		var npc: Area2D = DIALOGUE_NPC_SCRIPT.new()
		npc.setup(npc_data)
		add_child(npc)

func _on_route_gate_interacted(interaction_id: String) -> void:
	var route_id := interaction_id.replace("route:", "")
	GameState.set_current_route(route_id)
	SceneRouter.change_to("wasteland", "from_village")

func _on_station_interacted(id: String) -> void:
	match id:
		"forge":
			INVENTORY_SCRIPT.forge_ammo_pack()
		"craft":
			var crafted := INVENTORY_SCRIPT.craft_basic_upgrade()
			if crafted:
				_try_equip_best_new_craft()
		"shop":
			INVENTORY_SCRIPT.shop_buy_ammo()
		"mod":
			var crafted := INVENTORY_SCRIPT.craft_mod_upgrade()
			if crafted and GameState.can_equip("coil_launcher"):
				GameState.equip_item("coil_launcher")
		"recycle":
			INVENTORY_SCRIPT.recycle_core()
		"save":
			GameState.heal_full()
			SaveManager.save_game(true)
			GameState.notify("維修完成。Tab 可使用升級點強化 R-17。")
		"to_guild":
			SceneRouter.change_to("guild", "from_village")

func _try_equip_best_new_craft() -> void:
	for item_id in ["crystal_guard", "light_reinforced_armor", "patched_armor", "spark_cutter"]:
		if GameState.can_equip(item_id):
			var item := DataRegistry.get_equipment(item_id)
			var slot := String(item.get("slot", ""))
			if String(GameState.equipment.get(slot, "")) != item_id:
				GameState.equip_item(item_id)
				return
