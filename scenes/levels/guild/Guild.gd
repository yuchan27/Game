extends Node2D

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const HUD_SCENE := preload("res://scenes/ui/HUD.tscn")
const PIXEL := preload("res://scripts/utils/PixelArtFactory.gd")
const ASSET_LOADER := preload("res://scripts/utils/RuntimeAssetLoader.gd")
const BACKDROP_SCRIPT := preload("res://scripts/systems/WorldBackdrop.gd")
const INTERACTABLE_SCRIPT := preload("res://scripts/components/Interactable.gd")
const DIALOGUE_NPC_SCRIPT := preload("res://scripts/components/DialogueNpc.gd")
const PROJECTILE_POOL_SCRIPT := preload("res://scripts/systems/ProjectilePool.gd")
const WORLD_PROP_SCRIPT := preload("res://scripts/components/WorldProp.gd")

const MAP_TILES := Vector2i(52, 34)
const TILE_SIZE := 32
const WORLD_RECT := Rect2(Vector2(48, 48), Vector2(MAP_TILES.x * TILE_SIZE - 96, MAP_TILES.y * TILE_SIZE - 96))

const COUNTER_ASSETS := {
	"contract": "structure_guild_gate",
	"reward": "structure_save_station",
	"to_wasteland": "structure_wasteland_gate",
	"to_village": "structure_village_return_gate"
}

func _ready() -> void:
	y_sort_enabled = true
	GameState.current_scene_id = "guild"
	set_meta("map_world_size", Vector2(MAP_TILES.x * TILE_SIZE, MAP_TILES.y * TILE_SIZE))
	set_meta("map_scene_label", "冒險公會")
	AudioManager.play_music("guild")
	var backdrop: Node2D = BACKDROP_SCRIPT.new()
	backdrop.setup("guild", MAP_TILES, 4096)
	add_child(backdrop)
	_add_boundaries(Vector2(MAP_TILES.x * TILE_SIZE, MAP_TILES.y * TILE_SIZE))
	_add_decor()
	_add_counter("contract", "委託板：選擇下一份委託", Vector2(330, 275), Color8(102, 74, 118), "委託板")
	_add_counter("reward", "回報櫃台：交付完成委託", Vector2(680, 275), Color8(75, 96, 122), "回報櫃台")
	_add_counter("to_wasteland", "前往目前委託路線", Vector2(1080, 540), Color8(92, 88, 56), "出擊門")
	_add_counter("to_village", "返回村莊", Vector2(560, 720), Color8(64, 110, 70), "回村門")
	_spawn_npcs()
	_add_projectile_pool(200)
	var player := PLAYER_SCENE.instantiate()
	player.global_position = Vector2(660, 470) if GameState.active_spawn_point != "saved" else GameState.player_position
	add_child(player)
	if player.has_method("set_world_bounds"):
		player.set_world_bounds(WORLD_RECT)
	add_child(HUD_SCENE.instantiate())
	GameState.notify("冒險公會：接委託、交付獎勵，或直接前往目前路線。")

func _add_projectile_pool(limit: int) -> void:
	var pool: Node = PROJECTILE_POOL_SCRIPT.new()
	pool.max_projectiles = limit
	add_child(pool)

class GuildFoundation extends Node2D:
	var base_size: Vector2

	func _init(sz: Vector2) -> void:
		base_size = sz
		z_index = -1

	func _draw() -> void:
		var hw := base_size.x * 0.50
		var hh := maxf(10.0, base_size.y * 0.15)
		# Ambient occlusion shadow
		for i in range(3):
			var factor: float = 1.0 + float(i) * 0.12
			var alpha: float = 0.22 - float(i) * 0.05
			draw_set_transform(Vector2(4.0, -hh * 0.2), 0.0, Vector2(hw * factor, hh * factor))
			draw_circle(Vector2.ZERO, 1.0, Color(0.02, 0.02, 0.03, alpha))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# Polished bunker brass-trimmed foundation plate
		var plate_rect := Rect2(-hw * 0.92, -hh * 1.4, hw * 1.84, hh * 1.8)
		draw_rect(plate_rect, Color(0.12, 0.14, 0.18, 0.95))
		draw_rect(plate_rect, Color(0.48, 0.42, 0.25, 0.85), false, 1.8)
		# Corner rivets
		for sx in [-hw * 0.82, hw * 0.82]:
			for sy in [-hh * 1.1, hh * 0.2]:
				draw_circle(Vector2(sx, sy), 2.2, Color(0.65, 0.58, 0.35, 1.0))


func _add_counter(id: String, label: String, pos: Vector2, color: Color, map_label: String) -> void:
	var node := Node2D.new()
	node.position = pos
	node.y_sort_enabled = true
	node.add_to_group("map_station")
	node.set_meta("map_label", map_label)
	node.set_meta("map_marker", "station")
	var asset_id: String = String(COUNTER_ASSETS.get(id, ""))
	node.set_meta("structure_asset_id", asset_id)
	add_child(node)

	var sprite := Sprite2D.new()
	var texture := _counter_texture(id)
	sprite.texture = texture if texture != null else PIXEL.new().make_texture(Vector2i(200, 104), [color.darkened(0.3), color, color.lightened(0.22)], id.length())
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var texture_size := sprite.texture.get_size()
	var foundation := GuildFoundation.new(texture_size)
	foundation.name = "GuildFoundation"
	node.add_child(foundation)
	sprite.centered = false
	sprite.position = Vector2(-texture_size.x * 0.5, -texture_size.y)
	node.add_child(sprite)
	var badge := Label.new()
	badge.text = "【%s】" % map_label
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.custom_minimum_size = Vector2(140, 20)
	badge.position = Vector2(-70, -texture_size.y - 14.0)
	badge.add_theme_font_size_override("font_size", 11)
	badge.add_theme_color_override("font_color", Color(0.55, 0.85, 0.90, 0.75))
	badge.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.92))
	badge.add_theme_constant_override("shadow_offset_x", 1)
	badge.add_theme_constant_override("shadow_offset_y", 1)
	node.add_child(badge)

	_add_counter_collision(node, texture_size, asset_id)

	var interactable: Area2D = INTERACTABLE_SCRIPT.new()
	interactable.interaction_id = id
	interactable.prompt = label
	interactable.radius = max(texture_size.x, texture_size.y) * 0.38
	interactable.interacted.connect(_on_interacted)
	node.add_child(interactable)

func _counter_texture(id: String) -> Texture2D:
	var asset_id := String(COUNTER_ASSETS.get(id, ""))
	return ASSET_LOADER.load_png(DataRegistry.asset_path(asset_id)) if not asset_id.is_empty() else null

func _add_counter_collision(node: Node2D, texture_size: Vector2, asset_id: String) -> void:
	var body := StaticBody2D.new()
	body.name = "StructureCollider"
	body.add_to_group("obstacle")
	var shape := RectangleShape2D.new()
	var authored_collision: Variant = DataRegistry.get_visual_asset(asset_id).get("collision", [])
	if authored_collision is Array and authored_collision.size() == 2:
		shape.size = Vector2(max(24.0, float(authored_collision[0])), max(16.0, float(authored_collision[1])))
	else:
		shape.size = Vector2(max(48.0, texture_size.x * 0.54), max(22.0, texture_size.y * 0.18))
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	collision.shape = shape
	collision.position = Vector2(0, -shape.size.y * 0.5)
	body.add_child(collision)
	node.add_child(body)

func _add_decor() -> void:
	var props := [
		["scrap_wall", Vector2(170, 500), true, Vector2i(96, 66)],
		["signal_pylon", Vector2(910, 390), true, Vector2i(72, 128)],
		["rust_rock", Vector2(1250, 330), true, Vector2i(72, 62)],
		["road_marker", Vector2(820, 650), false, Vector2i(42, 58)]
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
	for npc_data in DataRegistry.npcs_for_scene("guild"):
		var npc: Area2D = DIALOGUE_NPC_SCRIPT.new()
		npc.setup(npc_data)
		add_child(npc)

func _on_interacted(id: String) -> void:
	match id:
		"contract":
			_start_next_contract()
		"reward":
			GameState.complete_active_quest()
		"to_wasteland":
			if GameState.active_quest_id.is_empty():
				GameState.notify("尚未接委託，仍可從村莊四門選擇探索路線。")
			GameState.seed = randi_range(1000, 999999)
			SceneRouter.change_to("wasteland", "from_guild")
		"to_village":
			SceneRouter.change_to("village", "from_guild")

func _start_next_contract() -> void:
	if not GameState.active_quest_id.is_empty():
		GameState.notify("目前委託：%s" % GameState.active_quest_summary())
		return
	for quest_id in DataRegistry.quest_ids():
		if not GameState.completed_quests.has(quest_id):
			GameState.start_quest(quest_id)
			return
	GameState.notify("目前沒有新的公會委託。")
