extends Node2D

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const HUD_SCENE := preload("res://scenes/ui/HUD.tscn")
const PIXEL := preload("res://scripts/utils/PixelArtFactory.gd")
const ASSET_LOADER := preload("res://scripts/utils/RuntimeAssetLoader.gd")
const BACKDROP_SCRIPT := preload("res://scripts/systems/WorldBackdrop.gd")
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
var _world_backdrop: Node2D
var _ground_contact_bounds: Array[Rect2] = []
var _ground_contacts_registered := false

func _ready() -> void:
	y_sort_enabled = true
	GameState.current_scene_id = "village"
	set_meta("story_ending", false)
	set_meta("map_world_size", Vector2(MAP_TILES.x * TILE_SIZE, MAP_TILES.y * TILE_SIZE))
	set_meta("map_scene_label", "廢土村莊")
	AudioManager.play_music("village")

	var backdrop := BACKDROP_SCRIPT.new() as Node2D
	backdrop.setup("village", MAP_TILES, 137, "village")
	if backdrop.has_method("has_material_ground") and bool(backdrop.call("has_material_ground")):
		_world_backdrop = backdrop
		add_child(backdrop)
	else:
		backdrop.free()
		var tilemap: TileMap = VILLAGE_TILEMAP_SCRIPT.new()
		tilemap.setup(MAP_TILES, 137)
		add_child(tilemap)
	_add_boundaries(Vector2(MAP_TILES.x * TILE_SIZE, MAP_TILES.y * TILE_SIZE))
	_add_decor()
	_add_stations()
	_add_route_gates()
	_spawn_npcs()
	_add_projectile_pool(200)
	GameState.stats_changed.connect(_refresh_story_recovery)
	_refresh_story_recovery()
	_register_ground_contacts()
	_spawn_player(_spawn_position())
	add_child(HUD_SCENE.instantiate())
	GameState.notify("%s。%s" % [GameState.get_village_water_summary(), GameState.get_journey_hint()])

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
	_add_route_gate("old_factory", "東門：舊工廠外圍", Vector2(2260, 540))
	_add_route_gate("underground_facility", "西北門：地底研究設施", Vector2(260, 510))
	_add_route_gate("ruined_metropolis", "東南門：崩塌都心區", Vector2(2240, 1460))

class StationFoundation extends Node2D:
	var station_id: String
	var base_size: Vector2

	func _init(id: String, sz: Vector2) -> void:
		station_id = id
		base_size = sz
		z_index = -1

	func _draw() -> void:
		var hw := base_size.x * 0.52
		var hh := maxf(12.0, base_size.y * 0.16)

		# 1. Broad soft ambient occlusion shadow (cast slightly bottom-right from 45° sun)
		for i in range(4):
			var factor: float = 1.0 + float(i) * 0.14
			var alpha: float = 0.20 - float(i) * 0.04
			draw_set_transform(Vector2(5.0, -hh * 0.2), 0.0, Vector2(hw * factor, hh * factor))
			draw_circle(Vector2.ZERO, 1.0, Color(0.02, 0.02, 0.03, alpha))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		# 2. Structural foundation skid plate (ground-anchored steel plate)
		var plate_hw := hw * 0.92
		var plate_hh := hh * 0.82
		var plate_rect := Rect2(-plate_hw, -plate_hh * 1.5, plate_hw * 2.0, plate_hh * 2.0)
		draw_rect(plate_rect, Color(0.14, 0.16, 0.19, 0.92))
		draw_rect(plate_rect, Color(0.26, 0.29, 0.34, 0.85), false, 2.0)

		# Corner anchor bolts
		var bolt_color := Color(0.55, 0.52, 0.45, 1.0)
		var bolt_head := Color(0.08, 0.08, 0.10, 1.0)
		var bolt_offset := Vector2(plate_hw - 6.0, plate_hh - 4.0)
		for sign_x in [-1.0, 1.0]:
			for sign_y in [-1.0, 1.0]:
				var bp := Vector2(sign_x * bolt_offset.x, sign_y * bolt_offset.y - plate_hh * 0.5)
				draw_circle(bp, 2.8, bolt_head)
				draw_circle(bp, 1.6, bolt_color)

		# 3. Station-specific ground decals & environmental integration
		match station_id:
			"forge":
				draw_circle(Vector2(6.0, 4.0), hw * 0.45, Color(0.95, 0.42, 0.12, 0.38))
				draw_circle(Vector2(4.0, 2.0), hw * 0.25, Color(1.0, 0.72, 0.28, 0.52))
				draw_polyline(PackedVector2Array([Vector2(-plate_hw + 4, 0), Vector2(-plate_hw - 28, 12), Vector2(-plate_hw - 52, 22)]), Color(0.12, 0.11, 0.14, 1.0), 3.0)
				draw_polyline(PackedVector2Array([Vector2(plate_hw - 4, 4), Vector2(plate_hw + 32, 16), Vector2(plate_hw + 60, 24)]), Color(0.12, 0.11, 0.14, 1.0), 3.0)
			"mod":
				draw_circle(Vector2(0.0, 0.0), hw * 0.42, Color(0.18, 0.82, 0.94, 0.28))
				draw_polyline(PackedVector2Array([Vector2(-plate_hw - 36, 14), Vector2(-plate_hw, 2)]), Color(0.12, 0.35, 0.42, 1.0), 3.0)
				draw_polyline(PackedVector2Array([Vector2(plate_hw, 2), Vector2(plate_hw + 36, 14)]), Color(0.12, 0.35, 0.42, 1.0), 3.0)
			"save":
				draw_arc(Vector2.ZERO, hw * 0.65, 0.0, TAU, 32, Color(0.2, 0.88, 0.95, 0.5), 2.0)
				draw_circle(Vector2.ZERO, hw * 0.35, Color(0.15, 0.75, 0.85, 0.22))
			"recycle":
				draw_circle(Vector2(0.0, 2.0), hw * 0.5, Color(0.07, 0.06, 0.05, 0.65))
				draw_polyline(PackedVector2Array([Vector2(-plate_hw, -2), Vector2(-plate_hw - 22, 10)]), Color(0.12, 0.11, 0.14, 1.0), 3.0)
			"craft":
				draw_polyline(PackedVector2Array([Vector2(plate_hw, 0), Vector2(plate_hw + 26, 14)]), Color(0.12, 0.11, 0.14, 1.0), 3.0)
			"shop":
				var rug_rect := Rect2(-plate_hw * 0.85, -plate_hh * 1.2, plate_hw * 1.7, plate_hh * 2.2)
				draw_rect(rug_rect, Color(0.42, 0.32, 0.22, 0.82))
				draw_rect(rug_rect, Color(0.55, 0.44, 0.28, 0.9), false, 1.5)
			"to_guild", "route_gate", "wasteland_gate":
				var sill_w := plate_hw * 0.9
				draw_rect(Rect2(-sill_w, -4, sill_w * 2.0, 8), Color(0.16, 0.18, 0.2, 1.0))
				for sx in range(int(-sill_w + 4), int(sill_w - 4), 14):
					draw_line(Vector2(sx, 4), Vector2(sx + 6, -4), Color(0.9, 0.75, 0.2, 0.85), 2.5)


func _add_station(id: String, label: String, pos: Vector2, color: Color, map_label: String) -> void:
	var node := Node2D.new()
	node.position = pos
	# The parent sorts this station by its registered foot; keep its art and labels together.
	node.y_sort_enabled = false
	node.add_to_group("map_station")
	node.set_meta("map_label", map_label)
	node.set_meta("map_marker", "station")
	var asset_id: String = String(STATION_ASSETS.get(id, ""))
	node.set_meta("structure_asset_id", asset_id)
	var asset: Dictionary = DataRegistry.get_visual_asset(asset_id)
	add_child(node)
	var sprite := Sprite2D.new()
	var texture := _station_texture(id)
	sprite.texture = texture if texture != null else PIXEL.new().make_texture(Vector2i(180, 110), [color.darkened(0.35), color, color.lightened(0.18)], id.length())
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var texture_size := sprite.texture.get_size()
	sprite.centered = false
	sprite.position = Vector2(-texture_size.x * 0.5, -texture_size.y)
	var legacy_bounds := Rect2(sprite.position, texture_size)
	var presentation_bounds: Rect2 = ASSET_LOADER.apply_world_presentation(sprite, asset, "village")
	var has_world_presentation := presentation_bounds.size.x > 0.0 and presentation_bounds.size.y > 0.0
	if has_world_presentation:
		sprite.material = WORLD_PROP_SCRIPT.world_source_material(ASSET_LOADER.world_presentation_source(asset, "village"), "village")
	if not has_world_presentation:
		presentation_bounds = legacy_bounds
		var foundation := StationFoundation.new(id, texture_size)
		foundation.name = "StationFoundation"
		node.add_child(foundation)
	node.add_child(sprite)

	var open_passage := has_world_presentation and asset_id == "structure_guild_gate"
	var collider_bounds := _add_station_collision(node, texture_size, asset_id, open_passage)
	if collider_bounds.size.x >= 30.0:
		_ground_contact_bounds.append(collider_bounds)
	var interactable: Area2D = INTERACTABLE_SCRIPT.new()
	interactable.interaction_id = id
	interactable.prompt = label
	interactable.radius = max(texture_size.x, texture_size.y) * 0.34
	interactable.setup_box(Vector2(0, -texture_size.y * 0.5), Vector2(texture_size.x + 140.0, texture_size.y + 140.0))
	interactable.set_screen_safe_prompt(presentation_bounds.get_center())
	interactable.interacted.connect(_on_station_interacted)
	node.add_child(interactable)

func _add_station_collision(node: Node2D, texture_size: Vector2, asset_id: String, open_passage := false) -> Rect2:
	var body := StaticBody2D.new()
	body.name = "StructureCollider"
	body.add_to_group("obstacle")
	var shape := RectangleShape2D.new()
	var authored_collision: Variant = DataRegistry.get_visual_asset(asset_id).get("collision", [])
	if authored_collision is Array and authored_collision.size() == 2:
		shape.size = Vector2(max(24.0, float(authored_collision[0])), max(16.0, float(authored_collision[1])))
	else:
		shape.size = Vector2(max(52.0, texture_size.x * 0.58), max(22.0, texture_size.y * 0.18))
	if open_passage:
		var pier_width := shape.size.x * 0.18
		for pier_data in [["LeftPassagePier", -1.0], ["RightPassagePier", 1.0]]:
			var pier := CollisionShape2D.new()
			pier.name = String(pier_data[0])
			var pier_shape := RectangleShape2D.new()
			pier_shape.size = Vector2(pier_width, shape.size.y)
			pier.shape = pier_shape
			pier.position = Vector2(float(pier_data[1]) * (shape.size.x * 0.5 - pier_width * 0.5), -shape.size.y * 0.5)
			body.add_child(pier)
	else:
		var collision := CollisionShape2D.new()
		collision.name = "CollisionShape2D"
		collision.shape = shape
		collision.position = Vector2(0, -shape.size.y * 0.5)
		body.add_child(collision)
	node.add_child(body)
	return Rect2(node.global_position + Vector2(-shape.size.x * 0.5, -shape.size.y), shape.size)

func _add_route_gate(route_id: String, label: String, pos: Vector2) -> void:
	var node := Node2D.new()
	node.position = pos
	# Sort the complete gate presentation by its registered foot.
	node.y_sort_enabled = false
	node.add_to_group("map_gate")
	node.set_meta("map_label", label)
	node.set_meta("map_marker", "gate")
	add_child(node)
	var sprite := Sprite2D.new()
	sprite.texture = _station_texture("route_gate")
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var asset_id := String(STATION_ASSETS.get("route_gate", ""))
	var asset: Dictionary = DataRegistry.get_visual_asset(asset_id)
	var gate_size := sprite.texture.get_size() if sprite.texture != null else Vector2(100, 100)
	sprite.centered = false
	sprite.position = Vector2(-gate_size.x * 0.5, -gate_size.y)
	var legacy_bounds := Rect2(sprite.position, gate_size)
	var presentation_bounds: Rect2 = ASSET_LOADER.apply_world_presentation(sprite, asset, "village")
	var has_world_presentation := presentation_bounds.size.x > 0.0 and presentation_bounds.size.y > 0.0
	if has_world_presentation:
		sprite.material = WORLD_PROP_SCRIPT.world_source_material(ASSET_LOADER.world_presentation_source(asset, "village"), "village")
	if not has_world_presentation:
		presentation_bounds = legacy_bounds
	if sprite.texture != null or has_world_presentation:
		if not has_world_presentation:
			var foundation := StationFoundation.new("route_gate", gate_size)
			foundation.name = "GateFoundation"
			node.add_child(foundation)
		_ground_contact_bounds.append(_presentation_foot_band(pos, presentation_bounds))
	node.add_child(sprite)
	var gate := ROUTE_GATE_SCRIPT.new()
	gate.setup_route(route_id, label, Vector2.ZERO, max(gate_size.x, gate_size.y) * 0.5 + 70.0)
	gate.setup_box(Vector2(0, -gate_size.y * 0.5), Vector2(gate_size.x + 140.0, gate_size.y + 140.0))
	gate.set_screen_safe_prompt(presentation_bounds.get_center())
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
		prop.preserve_legacy_collision = true
		prop.setup(String(prop_data[0]), bool(prop_data[2]), prop_data[3], "village")
		prop.global_position = prop_data[1]
		add_child(prop)
	_add_residential_frontage()

func _add_residential_frontage() -> void:
	for entry: Dictionary in WORLD_PROP_SCRIPT.material_kit().get("hubs", {}).get("village", {}).get("scenery", []):
		var prop := WORLD_PROP_SCRIPT.new()
		prop.setup(String(entry.id), true, Vector2i(300, 220), "village")
		prop.position = Vector2(float(entry.position[0]), float(entry.position[1]))
		add_child(prop)
		# Keep an older saved position usable when new scenery occupies its plot.
		if GameState.active_spawn_point == "saved" and prop.get_collision_bounds().grow(48.0).has_point(GameState.player_position):
			remove_child(prop)
			prop.free()

func _refresh_story_recovery() -> void:
	var water_stage := GameState.get_village_water_stage()
	var restored := water_stage == 2
	var cistern_asset := DataRegistry.get_visual_asset("prop_cistern_restored" if restored else "prop_cistern_dry")
	var existing := get_node_or_null("RecoveredWaterFeature")
	if existing != null:
		if int(existing.get_meta("water_stage", -1)) == water_stage:
			return
		remove_child(existing)
		existing.queue_free()
	var sprite := Sprite2D.new()
	var bounds: Rect2 = ASSET_LOADER.apply_world_presentation(sprite, cistern_asset, "village")
	var feature := Node2D.new()
	feature.name = "RecoveredWaterFeature"
	feature.position = Vector2(1510, 940)
	feature.y_sort_enabled = false
	feature.set_meta("water_stage", water_stage)
	feature.set_meta("restored", restored)
	if restored:
		feature.add_to_group("story_ending")
	set_meta("story_ending", restored)
	feature.add_to_group("map_prop")
	feature.set_meta("map_marker", "story")
	var water_label := "淨水回流｜仍需配給" if restored else ("臨時供水｜仍需配給" if water_stage == 1 else "乾涸蓄水槽｜供水停擺")
	feature.set_meta("map_label", water_label)
	add_child(feature)
	if bounds.has_area():
		sprite.material = WORLD_PROP_SCRIPT.world_source_material(ASSET_LOADER.world_presentation_source(cistern_asset, "village"), "village")
		feature.add_child(sprite)
		if water_stage == 1:
			_add_cistern_trickle(feature, bounds.size.x / 150.0)
		if not _ground_contacts_registered:
			# The crop includes debris below the authored foot at local y=0.
			_ground_contact_bounds.append(Rect2(feature.position + Vector2(bounds.position.x, -8), Vector2(bounds.size.x, 16)))
	else:
		sprite.free()
		_add_fallback_cistern(feature, water_stage)
		bounds = Rect2(-70, -70, 140, 90)
		if not _ground_contacts_registered:
			_ground_contact_bounds.append(Rect2(feature.position + Vector2(-56, -12), Vector2(112, 16)))
	var label := Label.new()
	label.name = "WaterStatus"
	label.text = water_label
	label.position = Vector2(-110, bounds.position.y - 22)
	label.size = Vector2(220, 20)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color("a6cecb") if water_stage > 0 else Color("c2af8c"))
	label.add_theme_color_override("font_outline_color", Color("171518"))
	label.add_theme_constant_override("outline_size", 3)
	feature.add_child(label)

func _add_cistern_trickle(feature: Node2D, presentation_scale: float) -> void:
	# Small static water marks sit inside the registered dry cistern's bowl.
	# The original raster stays intact; scale follows its world presentation width.
	var trickle := Line2D.new()
	trickle.name = "TemporaryWaterFlow"
	trickle.points = PackedVector2Array([Vector2(-10, -39), Vector2(-10, -33), Vector2(-8, -23)])
	trickle.width = 1.5
	trickle.default_color = Color("80b4b8")
	trickle.scale = Vector2.ONE * presentation_scale
	feature.add_child(trickle)
	var puddle := Polygon2D.new()
	puddle.polygon = PackedVector2Array([Vector2(-15, -24), Vector2(-5, -26), Vector2(3, -23), Vector2(-5, -20)])
	puddle.color = Color(0.23, 0.47, 0.50, 0.85)
	puddle.scale = Vector2.ONE * presentation_scale
	feature.add_child(puddle)

func _add_fallback_cistern(feature: Node2D, water_stage: int) -> void:
	var pool := Polygon2D.new()
	var points := PackedVector2Array()
	for i in range(20):
		var angle := float(i) / 20.0 * TAU
		points.append(Vector2(cos(angle) * 56.0, sin(angle) * 25.0 + 4.0))
	pool.polygon = points
	pool.color = Color(0.18, 0.68, 0.78, 0.78) if water_stage == 2 else Color("514a3c")
	feature.add_child(pool)
	var pipe := Line2D.new()
	pipe.points = PackedVector2Array([Vector2(-118, -34), Vector2(-88, -34), Vector2(-88, -8), Vector2(-48, -8)])
	pipe.width = 10.0
	pipe.default_color = Color(0.28, 0.34, 0.37, 1.0)
	feature.add_child(pipe)
	if water_stage > 0:
		var water_flow := Line2D.new()
		water_flow.points = PackedVector2Array([Vector2(-84, -27), Vector2(-84, -14), Vector2(-54, -14)])
		water_flow.width = 3.0 if water_stage == 2 else 1.5
		water_flow.default_color = Color(0.55, 0.9, 0.95, 0.95)
		feature.add_child(water_flow)

func _presentation_foot_band(position: Vector2, bounds: Rect2) -> Rect2:
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return Rect2()
	var height := minf(16.0, bounds.size.y)
	return Rect2(position + Vector2(bounds.position.x, bounds.end.y - height), Vector2(bounds.size.x, height))

func _register_ground_contacts() -> void:
	if _world_backdrop == null or not _world_backdrop.has_method("register_ground_contacts"):
		return
	for raw_prop in get_tree().get_nodes_in_group("world_prop"):
		var prop := raw_prop as WorldProp
		if prop == null or not is_ancestor_of(prop):
			continue
		var foot: Rect2 = prop.get_collision_bounds()
		if foot.size == Vector2.ZERO:
			var visual: Rect2 = prop.get_visual_bounds()
			foot = Rect2(prop.global_position - Vector2(visual.size.x * 0.32, 8), Vector2(visual.size.x * 0.64, 12))
		if foot.size.x >= 30.0:
			_ground_contact_bounds.append(foot)
	if not _ground_contact_bounds.is_empty():
		_world_backdrop.call("register_ground_contacts", _ground_contact_bounds)
		_ground_contacts_registered = true

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
	var hud_nodes := get_tree().get_nodes_in_group("hud")
	var hud = hud_nodes[0] if not hud_nodes.is_empty() else null
	match id:
		"forge":
			if hud != null and hud.has_method("open_workshop"):
				hud.open_workshop("forge")
			else:
				INVENTORY_SCRIPT.forge_ammo_pack()
		"craft":
			if hud != null and hud.has_method("open_workshop"):
				hud.open_workshop("craft")
			else:
				var crafted := INVENTORY_SCRIPT.craft_basic_upgrade()
				if crafted:
					_try_equip_best_new_craft()
		"shop":
			if hud != null and hud.has_method("open_workshop"):
				hud.open_workshop("forge")
			else:
				INVENTORY_SCRIPT.shop_buy_ammo()
		"mod":
			if hud != null and hud.has_method("open_workshop"):
				hud.open_workshop("mod")
			else:
				var crafted := INVENTORY_SCRIPT.craft_mod_upgrade()
				if crafted and GameState.can_equip("coil_launcher"):
					GameState.equip_item("coil_launcher")
		"recycle":
			if hud != null and hud.has_method("open_workshop"):
				hud.open_workshop("recycle")
			else:
				INVENTORY_SCRIPT.recycle_core()
		"save":
			GameState.heal_full()
			SaveManager.save_game(true)
			GameState.notify("維修完成。可在工坊 [C] 裝載戰術晶片與強化裝備。")
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
