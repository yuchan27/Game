extends Area2D
class_name DialogueNpc

const PIXEL := preload("res://scripts/utils/PixelArtFactory.gd")
const ASSET_LOADER := preload("res://scripts/utils/RuntimeAssetLoader.gd")

var npc_id := ""
var npc_name := "NPC"
var role := "倖存者"
var color := Color8(110, 126, 116)
var sprite_asset_id := ""
var portrait_asset_id := ""
var _player_near := false
var _name_label: Label
var _prompt: Label
var _sprite: Sprite2D
var _base_sprite_y := 0.0
var _phase := 0.0
var _talk_timer := 0.0
var _interact_radius := 96.0

func setup(data: Dictionary) -> void:
	npc_id = String(data.get("id", ""))
	npc_name = String(data.get("name", npc_id))
	role = String(data.get("role", "倖存者"))
	color = Color.from_string(String(data.get("color", "#6f7e74")), Color8(110, 126, 116))
	sprite_asset_id = String(data.get("sprite_asset_id", "npc_%s" % npc_id))
	portrait_asset_id = String(data.get("portrait_asset_id", sprite_asset_id))
	var position_data: Dictionary = data.get("position", {})
	position = Vector2(float(position_data.get("x", 0.0)), float(position_data.get("y", 0.0)))

func _ready() -> void:
	add_to_group("npc")
	add_to_group("interactable")
	add_to_group("map_npc")
	set_meta("map_label", npc_name)
	set_meta("map_marker", "npc")
	set_meta("portrait_asset_id", portrait_asset_id)
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_add_collision()
	_add_sprite()
	_add_labels()

func _process(delta: float) -> void:
	_update_player_near_from_distance()
	_phase += delta * (5.2 if _player_near else 2.4)
	_talk_timer = max(0.0, _talk_timer - delta)
	if _sprite != null:
		_sprite.position.y = _base_sprite_y + sin(_phase) * (2.0 if _player_near else 1.0)
		_sprite.rotation = sin(_phase * 0.55) * (0.025 if _talk_timer <= 0.0 else 0.055)
		_sprite.modulate = Color(1.08, 1.08, 1.08) if _talk_timer > 0.0 else Color.WHITE
	if _player_near and Input.is_action_just_pressed("interact"):
		_talk()

func _talk() -> void:
	AudioManager.play_sfx("interact")
	_talk_timer = 0.45
	GameState.talk_to_npc(npc_id)

func _update_player_near_from_distance() -> void:
	var player: Node2D = _nearest_player()
	var near: bool = false
	if player != null:
		near = global_position.distance_to(player.global_position) <= _interact_radius
	if near == _player_near:
		return
	_player_near = near
	if _name_label != null:
		_name_label.visible = _player_near
	if _prompt != null:
		_prompt.visible = _player_near
	if not _player_near:
		GameState.close_dialogue()

func _nearest_player() -> Node2D:
	var best: Node2D = null
	var best_distance: float = INF
	for node: Node in get_tree().get_nodes_in_group("player"):
		if node is Node2D:
			var candidate: Node2D = node as Node2D
			var distance: float = global_position.distance_to(candidate.global_position)
			if distance < best_distance:
				best_distance = distance
				best = candidate
	return best

func _add_collision() -> void:
	var collision: CollisionShape2D = CollisionShape2D.new()
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = _interact_radius
	collision.shape = shape
	add_child(collision)

func _add_sprite() -> void:
	_sprite = Sprite2D.new()
	var npc_texture: Texture2D = _npc_texture()
	_sprite.texture = npc_texture if npc_texture != null else PIXEL.new().make_texture(Vector2i(56, 72), [color.darkened(0.35), color, color.lightened(0.25)], npc_id.length())
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.centered = false
	var texture_size: Vector2 = _sprite.texture.get_size()
	_sprite.position = Vector2(-texture_size.x * 0.5, -texture_size.y)
	_base_sprite_y = _sprite.position.y
	add_child(_sprite)

func _add_labels() -> void:
	_name_label = Label.new()
	_name_label.text = "%s｜%s" % [npc_name, role]
	_name_label.position = Vector2(-72, -104)
	_name_label.visible = false
	_name_label.add_theme_font_size_override("font_size", 14)
	add_child(_name_label)

	_prompt = Label.new()
	_prompt.text = "E：交談"
	_prompt.position = Vector2(-36, -128)
	_prompt.visible = false
	_prompt.add_theme_font_size_override("font_size", 14)
	add_child(_prompt)

func _npc_texture() -> Texture2D:
	var asset: Dictionary = DataRegistry.get_visual_asset(sprite_asset_id)
	var path: String = String(asset.get("path", "res://assets/sprites/npcs/%s.png" % npc_id))
	if not path.is_empty() and ResourceLoader.exists(path):
		return ASSET_LOADER.load_png(path)
	return null

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_near = true
		if _name_label != null:
			_name_label.visible = true
		if _prompt != null:
			_prompt.visible = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_update_player_near_from_distance()
