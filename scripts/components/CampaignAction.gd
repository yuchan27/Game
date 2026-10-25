extends Node2D
class_name CampaignAction

const PIXEL := preload("res://scripts/utils/PixelArtFactory.gd")
const ASSET_LOADER := preload("res://scripts/utils/RuntimeAssetLoader.gd")
const WORLD_PROP_SCRIPT := preload("res://scripts/components/WorldProp.gd")
const CAMPAIGN_SCRIPT := preload("res://scripts/systems/CampaignProgress.gd")

const FOLLOWER_STOP_DISTANCE := 520.0
const FOLLOWER_ENEMY_DISTANCE := 300.0
const FOLLOWER_SPEED := 126.0
const FOLLOWER_WAYPOINT_RADIUS := 34.0
const RANGE_CUE_SEGMENTS := 32

var action_data: Dictionary = {}
var action_id := ""
var action_type := "channel"

var _host: Node2D
var _player: Node2D
var _route_id := ""
var _world_size := Vector2.ZERO
var _outing_actions: Array[Dictionary] = []
var _waypoints: Array[Vector2] = []
var _wave_count := 0
var _progress: Dictionary = {}
var _runtime_owner: Dictionary = {}
var _status := "locked"
var _wait_reason := ""
var _radius := 112.0
var _duration := 3.0
var _status_label: Label
var _navigation_marker: Node2D
var _escort_actor: Node2D
var _payload_sprite: Sprite2D
var _progress_dirty := false
var _progress_write_timer := 0.0
var _status_refresh_timer := 0.0
var _actor_write_timer := 0.0
var _spawned_wave_index := -1


func setup(definition: Dictionary, player_ref: Node2D, host_ref: Node2D, active_route: String, map_size: Vector2, outing_actions: Array) -> void:
	action_data = definition.duplicate(true)
	action_id = String(action_data.get("id", ""))
	action_type = String(action_data.get("type", "channel"))
	_player = player_ref
	_host = host_ref
	_route_id = active_route
	_world_size = map_size
	_runtime_owner = GameState.campaign_action_owner()
	_radius = maxf(48.0, float(action_data.get("radius", 112.0)))
	_duration = maxf(0.1, float(action_data.get("duration", 3.0)))
	for raw_action in outing_actions:
		if raw_action is Dictionary:
			_outing_actions.append(raw_action.duplicate(true))
	position = _normalized_position(action_data.get("position", []))
	_progress = _sanitize_progress(GameState.campaign_action_progress(action_id))
	_refresh_definition_from_choice()
	_status = GameState.campaign_action_status(action_id)


func _ready() -> void:
	y_sort_enabled = true
	add_to_group("interactable")
	add_to_group("map_event")
	add_to_group("campaign_action")
	set_meta("campaign_action_id", action_id)
	# WorldMapView treats these as priority field sites and displays their labels.
	set_meta("field_objective_id", action_id)
	set_meta("map_marker", "event")
	_spawn_action_prop()
	_create_status_label()
	_create_navigation_marker()
	_refresh_status_display()
	if GameState.has_signal("campaign_changed"):
		GameState.campaign_changed.connect(_on_campaign_changed)


func _exit_tree() -> void:
	_flush_progress()
	_cleanup_payload()
	if is_instance_valid(_escort_actor):
		_escort_actor.queue_free()
	_escort_actor = null


func _process(delta: float) -> void:
	_update_status_label_position()
	if action_id.is_empty() or not is_instance_valid(_player) or not is_instance_valid(_host):
		return
	_progress_write_timer = maxf(0.0, _progress_write_timer - delta)
	_actor_write_timer += delta
	_status_refresh_timer -= delta
	if _status_refresh_timer <= 0.0:
		_status_refresh_timer = 0.25
		_refresh_from_campaign()
		_refresh_status_display()
	if _progress_dirty and _progress_write_timer <= 0.0:
		_flush_progress()
	if GameState.death_pending or GameState.hp <= 0 or GameState.current_scene_id != "wasteland" or GameState.current_route_id != _route_id:
		return
	for blocker: Node in get_tree().get_nodes_in_group("gameplay_input_blocker"):
		if blocker is Control and (blocker as Control).is_visible_in_tree() and bool(blocker.get_meta("gameplay_input_blocked", true)):
			return
	if _status not in ["ready", "active"] or not bool(_progress.get("started", false)):
		return
	match action_type:
		"channel":
			_process_channel(delta)
		"escort":
			_process_escort(delta)
		"carry":
			_process_carry()
		"defend":
			_process_defend(delta)
		"choice":
			pass
	_update_status_label_position()


func can_interact() -> bool:
	if not is_instance_valid(_player) or not _route_choice_is_ready():
		return false
	if _status not in ["ready", "active"]:
		return false
	if _status == "active" and bool(_progress.get("started", false)) and action_type in ["escort", "carry", "defend"]:
		return false
	return _player.global_position.distance_to(global_position) <= _radius


func interact() -> void:
	if not can_interact():
		return
	AudioManager.play_sfx("interact")
	if action_type == "choice":
		GameState.request_campaign_choice(action_id)
		return
	if bool(_progress.get("started", false)):
		return
	_progress["started"] = true
	_wait_reason = ""
	if action_type == "escort":
		_progress["actor_x"] = global_position.x
		_progress["actor_y"] = global_position.y
		_ensure_escort_actor()
	elif action_type == "carry":
		_ensure_payload()
	_mark_progress_dirty(true)
	_refresh_status_display()
	GameState.notify(_start_text())


func get_screen_safe_prompt_text() -> String:
	if not can_interact():
		return ""
	var action_name := String(action_data.get("name", "現場行動"))
	if action_type == "channel" and bool(_progress.get("started", false)):
		return "[E] 按住不放：%s" % action_name
	var verb := "繼續" if _status == "active" else _interaction_verb()
	return "[E] %s：%s" % [verb, action_name]


func _definition_text(field_name: String) -> String:
	var value: Variant = action_data.get(field_name, "")
	return String(value).strip_edges() if typeof(value) == TYPE_STRING else ""


func _interaction_verb() -> String:
	var verb := _definition_text("interaction_verb")
	if not verb.is_empty():
		return verb
	match action_type:
		"choice":
			return "選擇調度"
		"channel":
			return "開始操作"
		"escort":
			return "開始護送"
		"carry":
			return "開始搬運"
		"defend":
			return "開始防守"
	return "開始"


func _payload_item_id() -> String:
	var item_id := _definition_text("payload_item")
	return item_id if not item_id.is_empty() else "bio_crystal"


func _on_campaign_changed() -> void:
	_refresh_from_campaign()
	_refresh_status_display()


func _refresh_from_campaign() -> void:
	var previous_status := _status
	var previous_started := bool(_progress.get("started", false))
	var previous_checkpoint := int(_progress.get("checkpoint", 0))
	_status = GameState.campaign_action_status(action_id)
	if not _progress_dirty:
		_progress = _sanitize_progress(GameState.campaign_action_progress(action_id))
	var progress_started := bool(_progress.get("started", false))
	var checkpoint := int(_progress.get("checkpoint", 0))
	if _status != previous_status or progress_started != previous_started or checkpoint != previous_checkpoint or _status != "active" or not progress_started:
		_wait_reason = ""
	_refresh_definition_from_choice()
	if _status == "done":
		_cleanup_payload()
		if is_instance_valid(_escort_actor):
			_escort_actor.queue_free()
		_escort_actor = null


func _refresh_definition_from_choice() -> void:
	var selected_option := _route_choice_option()
	var choice_action_id := String(action_data.get("route_choice", ""))
	var selected_choice_id := GameState.campaign_selected_choice(choice_action_id) if not choice_action_id.is_empty() else ""
	_duration = CAMPAIGN_SCRIPT.effective_duration(action_data, _outing_actions, selected_choice_id)
	var raw_waypoints: Variant = action_data.get("waypoints", [])
	if not selected_option.is_empty():
		var option_waypoints: Variant = selected_option.get("waypoints", [])
		if option_waypoints is Array and not option_waypoints.is_empty():
			raw_waypoints = option_waypoints
	_waypoints.clear()
	if raw_waypoints is Array:
		for raw_position in raw_waypoints:
			_waypoints.append(_normalized_position(raw_position))
	_wave_count = max(0, int(action_data.get("waves", 0)))
	if not selected_option.is_empty() and selected_option.has("waves"):
		_wave_count = max(0, int(selected_option.get("waves", _wave_count)))


func _route_choice_option() -> Dictionary:
	var choice_action_id := String(action_data.get("route_choice", ""))
	if choice_action_id.is_empty():
		return {}
	var selected_id := GameState.campaign_selected_choice(choice_action_id)
	if selected_id.is_empty():
		return {}
	for candidate: Dictionary in _outing_actions:
		if String(candidate.get("id", "")) != choice_action_id:
			continue
		for raw_option in candidate.get("options", []):
			if raw_option is Dictionary and String(raw_option.get("id", "")) == selected_id:
				return raw_option
	return {}


func _route_choice_is_ready() -> bool:
	var choice_action_id := String(action_data.get("route_choice", ""))
	return choice_action_id.is_empty() or not GameState.campaign_selected_choice(choice_action_id).is_empty()


func _spawn_action_prop() -> void:
	var prop_id := String(action_data.get("prop", ""))
	if prop_id.is_empty():
		return
	var prop := WORLD_PROP_SCRIPT.new() as WorldProp
	prop.setup(prop_id, false, Vector2i(124, 110), _route_id)
	prop.name = "CampaignActionProp"
	add_child(prop)


func _create_status_label() -> void:
	_status_label = Label.new()
	_status_label.name = "CampaignActionStatus"
	_status_label.position = Vector2(-148.0, -156.0)
	_status_label.size = Vector2(296.0, 54.0)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 13)
	_status_label.add_theme_color_override("font_color", Color8(232, 220, 184))
	_status_label.add_theme_color_override("font_outline_color", Color8(22, 21, 18))
	_status_label.add_theme_constant_override("outline_size", 4)
	add_child(_status_label)


func _create_navigation_marker() -> void:
	if action_type not in ["escort", "carry"]:
		return
	_navigation_marker = Node2D.new()
	_navigation_marker.name = "CampaignNextWaypoint"
	_navigation_marker.set_meta("campaign_action_id", action_id)
	_navigation_marker.set_meta("campaign_waypoint", true)
	_navigation_marker.set_meta("field_objective_id", action_id)
	_navigation_marker.set_meta("map_marker", "event")
	add_child(_navigation_marker)


func _refresh_navigation_marker() -> void:
	if not is_instance_valid(_navigation_marker):
		return
	var should_show := _status == "active" and bool(_progress.get("started", false)) and not _waypoints.is_empty()
	if not should_show:
		if _navigation_marker.is_in_group("map_event"):
			_navigation_marker.remove_from_group("map_event")
		return
	var checkpoint := clampi(int(_progress.get("checkpoint", 0)), 0, _waypoints.size() - 1)
	_navigation_marker.global_position = _waypoints[checkpoint]
	_navigation_marker.set_meta("map_label", "路點｜%s %d／%d" % [String(action_data.get("name", "行動")), checkpoint + 1, _waypoints.size()])
	if not _navigation_marker.is_in_group("map_event"):
		_navigation_marker.add_to_group("map_event")


func _refresh_status_display() -> void:
	queue_redraw()
	var action_name := String(action_data.get("name", "現場行動"))
	var state_text := _status_description()
	var map_text := "%s｜%s" % [action_name, state_text]
	set_meta("map_label", map_text)
	_refresh_navigation_marker()
	if not is_instance_valid(_status_label):
		return
	_status_label.text = "%s\n%s" % [action_name, state_text]
	_status_label.modulate = Color8(165, 190, 152) if _status == "done" else Color8(232, 220, 184)
	_update_status_label_position()


var _presentation_blocked: bool = false
var _presentation_occluders: Array[Control] = []


func set_hud_presentation(blocked: bool, occluders: Array[Control]) -> void:
	_presentation_blocked = blocked
	_presentation_occluders = occluders
	_update_status_label_position()


func _update_status_label_position() -> void:
	if not is_instance_valid(_status_label):
		return
	var anchor := global_position
	if action_type == "escort" and _status == "active" and bool(_progress.get("started", false)) and is_instance_valid(_escort_actor):
		anchor = _escort_actor.global_position
	_status_label.position = to_local(anchor) + Vector2(-148.0, -156.0)
	var should_be_visible: bool = (
		not _presentation_blocked
		and not SceneRouter.is_transition_pending()
		and not GameState.death_pending
		and GameState.hp > 0
		and GameState.current_scene_id == "wasteland"
		and GameState.current_route_id == _route_id
		and _status in ["ready", "active"]
		and is_instance_valid(_player)
		and _player.global_position.distance_to(anchor) <= 360.0
	)
	if should_be_visible:
		var label_rect: Rect2 = _status_label.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, _status_label.size)
		for occluder: Control in _presentation_occluders:
			if not is_instance_valid(occluder) or not occluder.is_visible_in_tree() or occluder.size.x <= 0.0 or occluder.size.y <= 0.0:
				continue
			var occluder_rect: Rect2 = (occluder.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, occluder.size)).grow(2.0)
			if label_rect.intersects(occluder_rect):
				should_be_visible = false
				break
	_status_label.visible = should_be_visible


func _draw() -> void:
	if action_type not in ["channel", "defend"] or _status not in ["ready", "active"]:
		return
	if not is_instance_valid(_player) or _player.global_position.distance_to(global_position) > 360.0:
		return

	var points := PackedVector2Array()
	for index in range(RANGE_CUE_SEGMENTS):
		var angle := TAU * float(index) / float(RANGE_CUE_SEGMENTS)
		points.append(Vector2(cos(angle), sin(angle)) * _radius)
	draw_colored_polygon(points, Color8(151, 187, 128, 22))
	points.append(points[0])
	draw_polyline(points, Color8(177, 207, 150, 108), 2.0, false)


func _status_description() -> String:
	match _status:
		"locked":
			return "等待前置行動"
		"done":
			var result_text := _definition_text("result_text")
			return result_text if not result_text.is_empty() else "已完成"
		"ready":
			if not _route_choice_is_ready():
				return "等待前段調度"
			return "靠近按 E %s" % _interaction_verb()
		"active":
			if not bool(_progress.get("started", false)):
				return "靠近按 E 繼續"
			if not _wait_reason.is_empty():
				return _wait_reason
			return _active_progress_text()
	return ""


func _active_progress_text() -> String:
	match action_type:
		"channel":
			return "按住 E %.1f／%.1f 秒" % [float(_progress.get("elapsed", 0.0)), _duration]
		"escort":
			return "護送中 %d／%d・下一路點 [M]" % [int(_progress.get("checkpoint", 0)), _waypoints.size()]
		"carry":
			return "攜帶中 %d／%d・下一路點 [M]" % [int(_progress.get("checkpoint", 0)), _waypoints.size()]
		"defend":
			return "守住據點 %.0f／%.0f 秒・波次 %d／%d" % [float(_progress.get("elapsed", 0.0)), _duration, int(_progress.get("checkpoint", 0)), _wave_count]
		"choice":
			return "靠近按 E 選擇調度"
	return ""


func presentation_state() -> Dictionary:
	var started := bool(_progress.get("started", false))
	var is_active := _status == "active" and started
	var progress_text := _active_progress_text() if is_active else ""
	var value := 0.0
	var maximum := 0.0
	if is_active:
		match action_type:
			"channel", "defend":
				value = float(_progress.get("elapsed", 0.0))
				maximum = _duration
			"escort", "carry":
				value = float(_progress.get("checkpoint", 0))
				maximum = float(_waypoints.size())
	return {
		"action_id": action_id,
		"name": String(action_data.get("name", "現場行動")),
		"status": _status,
		"text": _status_description(),
		"waiting": is_active and not _wait_reason.is_empty(),
		"progress_text": progress_text,
		"value": value,
		"maximum": maximum,
	}


func _start_text() -> String:
	var instruction := _definition_text("active_instruction")
	if instruction.is_empty():
		instruction = _definition_text("instruction")
	if not instruction.is_empty():
		return instruction
	match action_type:
		"channel":
			return "按住 E，完成「%s」。離開或放開會中斷本次操作。" % String(action_data.get("name", "現場操作"))
		"escort":
			return "人員已跟上。留在附近，沿 M 上的下一路點護送。"
		"carry":
			return "已帶上%s；沿 M 上的下一路點送抵據點。" % GameState.item_display_name(_payload_item_id())
		"defend":
			return "守在據點範圍內。威脅未清除時，防守進度會暫停。"
	return "現場行動已開始。"


func _process_channel(delta: float) -> void:
	var is_held := Input.is_action_pressed("interact")
	var is_near := _player.global_position.distance_to(global_position) <= _radius
	var elapsed := float(_progress.get("elapsed", 0.0))
	if not is_held or not is_near:
		if elapsed > 0.0:
			_progress["elapsed"] = 0.0
			_mark_progress_dirty(true)
		return
	var previous_bucket := int(floor(elapsed))
	elapsed = minf(_duration, elapsed + delta)
	_progress["elapsed"] = elapsed
	if int(floor(elapsed)) != previous_bucket:
		_mark_progress_dirty(true)
	else:
		_mark_progress_dirty()
	_refresh_status_display()
	if elapsed >= _duration:
		_complete_action()


func _process_escort(delta: float) -> void:
	_wait_reason = ""
	if _waypoints.is_empty():
		return
	_ensure_escort_actor()
	if not is_instance_valid(_escort_actor):
		return
	var checkpoint := clampi(int(_progress.get("checkpoint", 0)), 0, _waypoints.size())
	while checkpoint < _waypoints.size() and _escort_actor.global_position.distance_to(_waypoints[checkpoint]) <= FOLLOWER_WAYPOINT_RADIUS:
		checkpoint += 1
		_progress["checkpoint"] = checkpoint
		_mark_progress_dirty(true)
	if checkpoint >= _waypoints.size():
		if _escort_actor.global_position.distance_to(_player.global_position) <= FOLLOWER_STOP_DISTANCE * 0.5:
			_complete_action()
		else:
			_wait_reason = "靠近護送者完成會合"
		return
	if _escort_actor.global_position.distance_to(_player.global_position) > FOLLOWER_STOP_DISTANCE:
		_wait_reason = "靠近護送者才能繼續"
		return
	if _enemy_near(_escort_actor.global_position, FOLLOWER_ENEMY_DISTANCE):
		_wait_reason = "清除護送者附近敵人"
		return
	var before := _escort_actor.global_position
	_escort_actor.global_position = before.move_toward(_waypoints[checkpoint], FOLLOWER_SPEED * delta)
	_update_status_label_position()
	_progress["actor_x"] = _escort_actor.global_position.x
	_progress["actor_y"] = _escort_actor.global_position.y
	if _actor_write_timer >= 0.5 or before.distance_to(_escort_actor.global_position) >= 36.0:
		_actor_write_timer = 0.0
		_mark_progress_dirty(true)


func _process_carry() -> void:
	_wait_reason = ""
	if _waypoints.is_empty():
		return
	_ensure_payload()
	var checkpoint := clampi(int(_progress.get("checkpoint", 0)), 0, _waypoints.size())
	var route_waves := mini(_wave_count, _waypoints.size())
	if checkpoint < route_waves:
		if _spawned_wave_index == checkpoint:
			if _count_live_wave_enemies(checkpoint) > 0:
				_wait_reason = "清除本波伏擊敵人"
				return
			_spawned_wave_index = -1
			checkpoint += 1
			_progress["checkpoint"] = checkpoint
			_mark_progress_dirty(true)
		elif _count_live_wave_enemies(checkpoint) > 0:
			_wait_reason = "清除本波伏擊敵人"
			return
		elif _player.global_position.distance_to(_waypoints[checkpoint]) <= _radius:
			var spawned := _spawn_wave(checkpoint, _waypoints[checkpoint])
			if spawned <= 0:
				_wait_reason = "路點尚未就緒，保持戒備"
				return
			_spawned_wave_index = checkpoint
			return
		else:
			_wait_reason = "前往標記路點，注意伏擊"
			return
	else:
		while checkpoint < _waypoints.size() and _player.global_position.distance_to(_waypoints[checkpoint]) <= _radius:
			checkpoint += 1
			_progress["checkpoint"] = checkpoint
			_mark_progress_dirty(true)
		if checkpoint < _waypoints.size():
			_wait_reason = "靠近下一路點繼續搬運"
	if checkpoint >= _waypoints.size():
		_complete_action()


func _process_defend(delta: float) -> void:
	_wait_reason = ""
	if _player.global_position.distance_to(global_position) > _radius:
		_wait_reason = "留在據點範圍內防守"
		return
	var checkpoint := maxi(0, int(_progress.get("checkpoint", 0)))
	if _spawned_wave_index == checkpoint:
		if _count_live_wave_enemies(checkpoint) > 0:
			_wait_reason = "清除本波敵人後繼續"
			return
		_spawned_wave_index = -1
		checkpoint += 1
		_progress["checkpoint"] = checkpoint
		_mark_progress_dirty(true)
	elif _count_live_wave_enemies(checkpoint) > 0:
		_wait_reason = "清除本波敵人後繼續"
		return
	if _enemy_near(global_position, _radius + 180.0):
		_wait_reason = "清除據點附近敵人後繼續"
		return
	if checkpoint < _wave_count:
		var spawn_at := checkpoint == 0 or float(_progress.get("elapsed", 0.0)) >= _duration * float(checkpoint) / float(maxi(1, _wave_count))
		if spawn_at:
			var spawned := _spawn_wave(checkpoint, global_position)
			if spawned > 0:
				_spawned_wave_index = checkpoint
				return
			_wait_reason = "等待下一波敵人"
	var elapsed := minf(_duration, float(_progress.get("elapsed", 0.0)) + delta)
	_progress["elapsed"] = elapsed
	_mark_progress_dirty()
	if elapsed >= _duration and checkpoint >= _wave_count:
		_complete_action()


func _spawn_wave(wave_index: int, center: Vector2) -> int:
	if not is_instance_valid(_host) or not _host.has_method("spawn_campaign_wave"):
		return 0
	return int(_host.call("spawn_campaign_wave", action_id, wave_index, 2, center))


func _count_live_wave_enemies(wave_index: int) -> int:
	var count := 0
	for raw_enemy in get_tree().get_nodes_in_group("enemy"):
		var enemy := raw_enemy as Node2D
		if enemy == null or not is_instance_valid(enemy) or bool(enemy.get("is_dead")):
			continue
		if String(enemy.get_meta("campaign_action_id", "")) == action_id and int(enemy.get_meta("campaign_wave_index", -1)) == wave_index:
			count += 1
	return count


func _enemy_near(center: Vector2, distance: float) -> bool:
	for raw_enemy in get_tree().get_nodes_in_group("enemy"):
		var enemy := raw_enemy as Node2D
		if enemy == null or not is_instance_valid(enemy) or bool(enemy.get("is_dead")):
			continue
		if enemy.global_position.distance_to(center) <= distance:
			return true
	return false


func _ensure_escort_actor() -> void:
	if is_instance_valid(_escort_actor) or not is_instance_valid(_host):
		return
	var actor := Node2D.new()
	actor.name = "CampaignEscort_%s" % action_id
	actor.add_to_group("campaign_follower")
	actor.y_sort_enabled = true
	var saved_position := Vector2(float(_progress.get("actor_x", 0.0)), float(_progress.get("actor_y", 0.0)))
	actor.global_position = saved_position if saved_position != Vector2.ZERO else global_position
	var shadow := Polygon2D.new()
	shadow.name = "GroundShadow"
	shadow.z_index = -1
	var shadow_points := PackedVector2Array()
	for index in range(16):
		var angle := float(index) / 16.0 * TAU
		shadow_points.append(Vector2(cos(angle) * 21.0, sin(angle) * 7.0 + 1.0))
	shadow.polygon = shadow_points
	shadow.color = Color(0.03, 0.02, 0.04, 0.42)
	actor.add_child(shadow)
	var sprite := Sprite2D.new()
	var asset := DataRegistry.get_visual_asset("npc_wasteland_survivor")
	var texture := ASSET_LOADER.load_png(String(asset.get("path", "res://assets/sprites/npcs/wasteland_survivor.png")))
	if texture != null:
		sprite.texture = texture
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.centered = false
		sprite.position = Vector2(-texture.get_width() * 0.5, -texture.get_height())
		actor.add_child(sprite)
	_host.add_child(actor)
	_escort_actor = actor


func _ensure_payload() -> void:
	if is_instance_valid(_payload_sprite) or not is_instance_valid(_player):
		return
	var item_id := _payload_item_id()
	var resource: Dictionary = DataRegistry.get_resource(item_id)
	var equipment: Dictionary = DataRegistry.get_equipment(item_id)
	var asset_id := String(resource.get("icon_asset_id", equipment.get("icon_asset_id", "")))
	var visual_asset: Dictionary = DataRegistry.get_visual_asset(asset_id)
	var texture: Texture2D = ASSET_LOADER.load_png(DataRegistry.asset_path(asset_id)) if not asset_id.is_empty() else null
	if texture != null:
		var raw_crop: Variant = visual_asset.get("source_rect", [])
		if raw_crop is Array and raw_crop.size() == 4:
			var region := Rect2(float(raw_crop[0]), float(raw_crop[1]), float(raw_crop[2]), float(raw_crop[3]))
			if region.size.x > 0.0 and region.size.y > 0.0 and Rect2(Vector2.ZERO, texture.get_size()).encloses(region):
				var atlas := AtlasTexture.new()
				atlas.atlas = texture
				atlas.region = region
				atlas.filter_clip = true
				texture = atlas
	if texture == null:
		texture = PIXEL.new().item_texture(item_id)
	var sprite := Sprite2D.new()
	sprite.name = "CampaignCarryPayload"
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var texture_size := texture.get_size()
	var display_scale := minf(24.0 / texture_size.x, 22.0 / texture_size.y) if texture_size.x > 0.0 and texture_size.y > 0.0 else 0.35
	sprite.scale = Vector2.ONE * display_scale
	sprite.position = Vector2(20.0, -46.0)
	sprite.z_index = 8
	_player.add_child(sprite)
	_payload_sprite = sprite


func _cleanup_payload() -> void:
	if is_instance_valid(_payload_sprite):
		_payload_sprite.queue_free()
	_payload_sprite = null


func _complete_action() -> void:
	_flush_progress()
	if not GameState.complete_campaign_action(action_id):
		_refresh_from_campaign()
		_refresh_status_display()
		return
	_progress["started"] = false
	_cleanup_payload()
	if is_instance_valid(_escort_actor):
		_escort_actor.queue_free()
	_escort_actor = null
	AudioManager.play_sfx("quest_complete")
	_refresh_from_campaign()
	_refresh_status_display()


func _mark_progress_dirty(force := false) -> void:
	_progress_dirty = true
	if force:
		_flush_progress()


func flush_runtime_progress() -> void:
	_flush_progress()


func _flush_progress() -> void:
	if not _progress_dirty or action_id.is_empty() or _runtime_owner.is_empty():
		return
	var clean := _sanitize_progress(_progress)
	if GameState.update_campaign_action(action_id, clean, _runtime_owner):
		_progress = clean
		_progress_dirty = false
		_progress_write_timer = 0.5


func _sanitize_progress(raw: Dictionary) -> Dictionary:
	return {
		"elapsed": maxf(0.0, float(raw.get("elapsed", 0.0))),
		"checkpoint": maxi(0, int(raw.get("checkpoint", 0))),
		"actor_x": float(raw.get("actor_x", 0.0)),
		"actor_y": float(raw.get("actor_y", 0.0)),
		"started": bool(raw.get("started", false))
	}


func _normalized_position(raw_position: Variant) -> Vector2:
	if raw_position is Array and raw_position.size() == 2:
		return Vector2(float(raw_position[0]) * _world_size.x, float(raw_position[1]) * _world_size.y)
	return _world_size * 0.5
