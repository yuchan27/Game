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
var _dialogue_page := 0
var _dialogue_active := false
var _dialogue_signature := ""

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
	add_to_group("dialogue_npc")
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
	_phase += delta * (5.2 if _player_near else 2.2)
	_talk_timer = max(0.0, _talk_timer - delta)
	if _sprite != null:
		_sprite.position.y = _base_sprite_y
		_sprite.rotation = sin(_phase * 0.55) * (0.012 if _talk_timer <= 0.0 else 0.032)
		_sprite.modulate = Color(1.08, 1.08, 1.08) if _talk_timer > 0.0 else Color.WHITE

func can_interact() -> bool:
	return _player_near

func interact() -> void:
	if can_interact():
		_talk()

func is_dialogue_active() -> bool:
	return _dialogue_active

func is_dialogue_final_page() -> bool:
	return _dialogue_active and _dialogue_page >= 2

func reset_dialogue_state() -> void:
	var was_active := _dialogue_active
	_dialogue_active = false
	_dialogue_page = 0
	_dialogue_signature = ""
	if was_active:
		AudioManager.stop_voice()
	_update_prompt_text()

func _talk() -> void:
	var npc: Dictionary = DataRegistry.get_npc(npc_id)
	if npc.is_empty():
		GameState.notify("未知的 NPC：%s" % npc_id)
		return

	AudioManager.play_sfx("interact")
	_dialogue_active = true
	_talk_timer = 0.45

	var first_time: bool = not GameState.talked_npcs.has(npc_id)
	if first_time:
		GameState.talked_npcs.append(npc_id)
		var reward: Dictionary = npc.get("reward", {})
		for item_id in reward.keys():
			GameState.add_item(String(item_id), int(reward[item_id]))

	var first_line: String = String(npc.get("line", ""))
	var story_line := GameState.story_dialogue_for_npc(npc)
	if not story_line.is_empty():
		first_line = story_line
	first_line += GameState.campaign_npc_record(npc_id)
	if _dialogue_signature != first_line:
		_dialogue_signature = first_line
		_dialogue_page = 0
	var second_line: String = String(npc.get("repeat_line", first_line))
	if not story_line.is_empty():
		second_line = "%s\n詳細紀錄可按 [K] 回看；委託與交付目標在 [J]。" % GameState.get_journey_hint()
	if _dialogue_active and _dialogue_page >= 2:
		_finish_dialogue()
		return

	var message: String
	if _dialogue_page <= 0:
		message = first_line
		_dialogue_page = 1 if not second_line.is_empty() and second_line != first_line else 2
	else:
		message = second_line
		_dialogue_page = 2
	var should_play_voice: bool = bool(npc.get("voice_enabled", true)) and message == String(npc.get("line", ""))
	GameState.npc_dialogue_requested.emit(self, String(npc.get("name", npc_id)), String(npc.get("role", "倖存者")), message)
	if should_play_voice:
		AudioManager.play_voice("npc_" + npc_id)
	else:
		AudioManager.stop_voice()
	GameState.inventory_changed.emit()
	GameState.stats_changed.emit()
	_update_prompt_text()

func _finish_dialogue() -> void:
	reset_dialogue_state()
	GameState.npc_dialogue_closed.emit(self)

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
		_name_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.36) if _player_near else Color(0.96, 0.94, 0.82))
	if _prompt != null:
		_prompt.visible = _player_near
	if not _player_near:
		var should_close_dialogue := _dialogue_active
		reset_dialogue_state()
		if should_close_dialogue:
			GameState.npc_dialogue_closed.emit(self)
	_update_prompt_text()

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
	var shadow := Polygon2D.new()
	shadow.name = "GroundShadow"
	shadow.z_index = -1
	var s_pts := PackedVector2Array()
	for i in range(18):
		var a := float(i) / 18.0 * TAU
		s_pts.append(Vector2(cos(a) * 24.0, sin(a) * 8.0 - 4.0))
	shadow.polygon = s_pts
	shadow.color = Color(0.03, 0.02, 0.04, 0.44)
	add_child(shadow)

	_sprite = Sprite2D.new()
	var npc_texture: Texture2D = _npc_texture()
	_sprite.texture = npc_texture if npc_texture != null else PIXEL.new().make_texture(Vector2i(84, 98), [color.darkened(0.35), color, color.lightened(0.25)], npc_id.length())
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.centered = false
	var texture_size: Vector2 = _sprite.texture.get_size()
	_sprite.position = Vector2(-texture_size.x * 0.5, -texture_size.y)
	_base_sprite_y = _sprite.position.y
	add_child(_sprite)

func _add_labels() -> void:
	_name_label = Label.new()
	_name_label.text = "%s｜%s" % [npc_name, role]
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.custom_minimum_size = Vector2(152, 20)
	_name_label.position = Vector2(-76, -114)
	_name_label.visible = false
	_name_label.add_theme_font_size_override("font_size", 13)
	_name_label.add_theme_color_override("font_color", Color(0.98, 0.94, 0.76))
	_name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.92))
	_name_label.add_theme_constant_override("shadow_offset_x", 1)
	_name_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_name_label)

	_prompt = Label.new()
	_prompt.position = Vector2(-36, -134)
	_prompt.visible = false
	_prompt.add_theme_font_size_override("font_size", 14)
	add_child(_prompt)
	_update_prompt_text()

func _update_prompt_text() -> void:
	if _prompt == null:
		return
	if _dialogue_page == 1:
		_prompt.text = "E：下一段"
	elif _dialogue_active and _dialogue_page >= 2:
		_prompt.text = "E：結束對話"
	else:
		_prompt.text = "E：交談"

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
		_update_prompt_text()

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_update_player_near_from_distance()
