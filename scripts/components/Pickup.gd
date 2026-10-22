extends Area2D
class_name RecyclerPickup

const PIXEL := preload("res://scripts/utils/PixelArtFactory.gd")
const ASSET_LOADER := preload("res://scripts/utils/RuntimeAssetLoader.gd")
const PICKUP_COLLISION_RADIUS := 30.0

@export var item_id := "scrap"
@export var amount := 1

var sprite: Sprite2D
var float_phase := 0.0
var collected := false

func setup(id: String, count: int) -> void:
	item_id = id
	amount = count

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
	# 掉落物圖示本體已預先處理成 64x64，不再額外放大。
	sprite.scale = Vector2.ONE
	add_child(sprite)
	set_process(true)

func _process(delta: float) -> void:
	float_phase += delta * 4.2
	if sprite != null:
		sprite.position.y = sin(float_phase) * 2.0
		sprite.rotation = sin(float_phase * 0.4) * 0.04
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
	if collected or not body.is_in_group("player"):
		return
	collected = true
	set_deferred("monitoring", false)
	var final_amount := amount
	if item_id == "scrap" and GameState.has_perk("scavenger_savant"):
		final_amount = int(round(float(amount) * (1.0 + float(GameState.get_perk_level("scavenger_savant")) * 0.40)))
		final_amount = maxi(amount, final_amount)
	GameState.add_item(item_id, final_amount)
	AudioManager.play_sfx("pickup")
	GameState.notify("拾取：%s x%d" % [GameState.item_display_name(item_id), final_amount])

	if GameState.has_perk("nano_salvage"):
		var heal_amt := 4 + GameState.get_perk_level("nano_salvage") * 3
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
