extends Area2D
class_name RecyclerPickup

const PIXEL := preload("res://scripts/utils/PixelArtFactory.gd")
const ASSET_LOADER := preload("res://scripts/utils/RuntimeAssetLoader.gd")
const PICKUP_COLLISION_RADIUS := 30.0
const WORLD_ICON_SIZE := 28.0

@export var item_id := "scrap"
@export var amount := 1

var sprite: Sprite2D
var float_phase := 0.0
var collected := false
var source_key := ""

func setup(id: String, count: int, field_source_key := "") -> void:
	item_id = id
	amount = count
	source_key = field_source_key

func _ready() -> void:
	add_to_group("pickup")
	add_to_group("map_pickup")
	set_meta("map_label", GameState.item_display_name(item_id))
	set_meta("map_marker", "pickup")
	monitoring = true
	body_entered.connect(_on_body_entered)
	float_phase = randf_range(0.0, TAU)
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	# 60x60 左右的拾取範圍：玩家碰到掉落物邊緣就能撿起。
	shape.radius = PICKUP_COLLISION_RADIUS
	collision.shape = shape
	add_child(collision)
	sprite = Sprite2D.new()
	sprite.texture = _item_texture(item_id)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Inventory art keeps its original resolution; loose loot uses a small world
	# glyph, distinct from a full-size terrain object. Pickup reach is unchanged.
	var longest_edge := maxf(sprite.texture.get_width(), sprite.texture.get_height())
	sprite.scale = Vector2.ONE * minf(1.0, WORLD_ICON_SIZE / maxf(1.0, longest_edge))
	add_child(sprite)
	set_process(true)

func _process(delta: float) -> void:
	float_phase += delta * 4.2
	if sprite != null:
		sprite.position.y = sin(float_phase)
		sprite.modulate = Color(1.0, 1.0, 1.0, 0.86 + sin(float_phase) * 0.14)

func _item_texture(id: String) -> Texture2D:
	var resource := DataRegistry.get_resource(id)
	var equipment := DataRegistry.get_equipment(id)
	var asset_id := String(resource.get("icon_asset_id", equipment.get("icon_asset_id", "")))
	if not asset_id.is_empty():
		var path := DataRegistry.asset_path(asset_id)
		var texture := ASSET_LOADER.load_png(path)
		if texture != null:
			return texture
	return PIXEL.new().item_texture(id)

func _on_body_entered(body: Node) -> void:
	if collected or GameState.death_pending or GameState.hp <= 0 or not body.is_in_group("player"):
		return
	collected = true
	set_deferred("monitoring", false)
	var final_amount := amount
	if item_id == "scrap" and GameState.has_effective_perk("scavenger_savant"):
		final_amount = int(round(float(amount) * (1.0 + float(GameState.get_effective_perk_level("scavenger_savant")) * 0.40)))
		final_amount = maxi(amount, final_amount)
	GameState.add_field_item(item_id, final_amount)
	if not source_key.is_empty():
		GameState.record_run_source(source_key)
	AudioManager.play_sfx("pickup")
	GameState.notify("拾取：%s x%d" % [GameState.item_display_name(item_id), final_amount])

	if GameState.has_effective_perk("nano_salvage"):
		var heal_amt := 4 + GameState.get_effective_perk_level("nano_salvage") * 3
		GameState.hp = mini(GameState.get_max_hp(), GameState.hp + heal_amt)
		GameState.ep = mini(GameState.get_max_ep(), GameState.ep + heal_amt)
		GameState.stats_changed.emit()
		_trigger_salvage_blast(body.global_position)

	visible = false
	call_deferred("queue_free")

func _trigger_salvage_blast(center: Vector2) -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy is Node2D:
			var enemy_node := enemy as Node2D
			var dist := center.distance_to(enemy_node.global_position)
			if dist <= 120.0 and dist > 1.0:
				var push: Vector2 = (enemy_node.global_position - center).normalized() * 140.0
				if enemy.has_method("apply_knockback"):
					enemy.apply_knockback(push)
