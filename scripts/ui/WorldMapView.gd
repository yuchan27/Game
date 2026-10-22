extends Control
class_name WorldMapView

signal expand_requested

var full_screen := false

const MARKER_COLORS := {
	"player": Color(0.35, 0.95, 0.95, 1.0),
	"npc": Color(0.95, 0.82, 0.38, 1.0),
	"station": Color(0.62, 0.74, 1.0, 1.0),
	"gate": Color(0.45, 0.95, 0.48, 1.0),
	"pickup": Color(0.76, 0.46, 1.0, 1.0),
	"enemy": Color(0.95, 0.35, 0.30, 1.0),
	"boss": Color(1.0, 0.16, 0.12, 1.0),
	"prop": Color(0.50, 0.58, 0.48, 0.85),
	"event": Color(0.95, 0.62, 0.25, 1.0)
}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	custom_minimum_size = Vector2(210, 116)
	gui_input.connect(_on_gui_input)

func set_full_screen(enabled: bool) -> void:
	full_screen = enabled
	custom_minimum_size = Vector2(900, 560) if full_screen else Vector2(210, 116)
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if full_screen:
		_draw_fullscreen_map()
	else:
		_draw_mini_radar()

func _draw_mini_radar() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.46

	# 1. Sleek semi-transparent circular dark glass
	draw_circle(center, radius, Color(0.038, 0.052, 0.068, 0.78))

	# 2. Concentric tactical range rings
	draw_arc(center, radius, 0, TAU, 48, Color(0.28, 0.65, 0.72, 0.50), 1.5)
	draw_arc(center, radius * 0.64, 0, TAU, 36, Color(0.20, 0.50, 0.56, 0.25), 1.0)
	draw_arc(center, radius * 0.30, 0, TAU, 24, Color(0.20, 0.50, 0.56, 0.18), 1.0)

	# 3. Fine crosshair axes
	draw_line(Vector2(center.x - radius * 0.90, center.y), Vector2(center.x + radius * 0.90, center.y), Color(0.22, 0.55, 0.62, 0.20), 1.0)
	draw_line(Vector2(center.x, center.y - radius * 0.90), Vector2(center.x, center.y + radius * 0.90), Color(0.22, 0.55, 0.62, 0.20), 1.0)

	# 4. Rotating sweep beam
	var time_sec: float = float(Time.get_ticks_msec()) * 0.001
	var sweep_angle: float = fmod(time_sec * 1.8, TAU)
	var sweep_end := center + Vector2(cos(sweep_angle), sin(sweep_angle)) * radius
	draw_line(center, sweep_end, Color(0.42, 0.94, 0.88, 0.30), 1.2)

	# 5. North compass mark
	draw_line(Vector2(center.x, center.y - radius), Vector2(center.x, center.y - radius + 3.5), Color(0.96, 0.82, 0.35, 0.85), 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(center.x - 3.0, center.y - radius + 11.0), "N", HORIZONTAL_ALIGNMENT_CENTER, -1, 9, Color(0.96, 0.82, 0.35, 0.75))

	# 6. Player-centered tactical blips
	var player_nodes := get_tree().get_nodes_in_group("map_player")
	if player_nodes.is_empty() or not (player_nodes[0] is Node2D):
		return
	var player_node := player_nodes[0] as Node2D
	var player_pos: Vector2 = player_node.global_position
	var radar_world_range: float = 750.0
	var radar_scale: float = (radius * 0.86) / radar_world_range

	var drawn_nodes: Dictionary = {}
	for group_name: String in _visible_marker_groups():
		if group_name == "map_player":
			continue
		for node in get_tree().get_nodes_in_group(group_name):
			if not is_instance_valid(node) or not (node is Node2D):
				continue
			var instance_id := node.get_instance_id()
			if drawn_nodes.has(instance_id):
				continue
			drawn_nodes[instance_id] = true
			var marker := String(node.get_meta("map_marker", _marker_from_group(group_name)))
			if not _should_draw_marker(marker):
				continue
			var node2d := node as Node2D
			var delta_pos := node2d.global_position - player_pos
			var dist := delta_pos.length()
			var blip_pos: Vector2
			var blip_alpha: float = 1.0
			if dist <= radar_world_range:
				blip_pos = center + delta_pos * radar_scale
			else:
				# Show on perimeter ring
				blip_pos = center + delta_pos.normalized() * (radius * 0.90)
				blip_alpha = 0.55

			var base_color: Color = MARKER_COLORS.get(marker, Color.WHITE)
			base_color.a = blip_alpha
			match marker:
				"gate":
					var d_sz := 3.5
					draw_colored_polygon(PackedVector2Array([
						blip_pos + Vector2(0, -d_sz),
						blip_pos + Vector2(d_sz, 0),
						blip_pos + Vector2(0, d_sz),
						blip_pos + Vector2(-d_sz, 0)
					]), base_color)
				"npc":
					draw_circle(blip_pos, 3.0, base_color)
					draw_circle(blip_pos, 1.2, Color(1.0, 1.0, 1.0, blip_alpha))
				"station":
					draw_rect(Rect2(blip_pos - Vector2(2.5, 2.5), Vector2(5, 5)), base_color, true)
				"boss":
					draw_circle(blip_pos, 4.5, base_color)
					draw_arc(blip_pos, 6.0, 0, TAU, 16, Color(1.0, 0.2, 0.2, blip_alpha * 0.8), 1.0)
				"enemy":
					draw_circle(blip_pos, 2.5, base_color)
				_:
					draw_circle(blip_pos, 2.2, base_color)

	# 7. Player center blip: cyan chevron pointing in facing direction
	var facing_dir := Vector2.RIGHT
	if "last_direction" in player_node:
		var ld = player_node.get("last_direction")
		if ld is Vector2 and ld.length_squared() > 0.01:
			facing_dir = ld.normalized()

	var forward := facing_dir * 5.5
	var right_wing := Vector2(-facing_dir.y, facing_dir.x) * 3.5 - facing_dir * 3.0
	var left_wing := Vector2(facing_dir.y, -facing_dir.x) * 3.5 - facing_dir * 3.0
	draw_colored_polygon(PackedVector2Array([
		center + forward,
		center + right_wing,
		center,
		center + left_wing
	]), Color(0.40, 0.98, 0.96, 1.0))
	draw_circle(center, 1.5, Color(1.0, 1.0, 1.0, 0.95))

func _draw_fullscreen_map() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.035, 0.045, 0.045, 0.95), true)
	draw_rect(rect, Color(0.38, 0.45, 0.40, 0.92), false, 1.0)
	var world: Vector2 = _world_size()
	var padding: float = 24.0
	var map_area := Rect2(Vector2(16.0, 48.0), Vector2(max(1.0, size.x - 32.0), max(1.0, size.y - 100.0)))
	var scale: float = min((map_area.size.x - padding * 2.0) / max(1.0, world.x), (map_area.size.y - padding * 2.0) / max(1.0, world.y))
	var map_size: Vector2 = world * scale
	var origin: Vector2 = map_area.position + (map_area.size - map_size) * 0.5
	draw_rect(Rect2(origin, map_size), Color(0.08, 0.10, 0.09, 0.75), true)
	draw_rect(Rect2(origin, map_size), Color(0.46, 0.42, 0.32, 0.85), false, 1.0)
	_draw_route_frame(origin, map_size)
	_draw_viewport_box(origin, scale, world)
	_draw_group_markers(origin, scale)
	_draw_legend()
	_draw_title()


func _draw_route_frame(origin: Vector2, map_size: Vector2) -> void:
	var center := origin + map_size * 0.5
	for i in range(1, 4):
		var gx := origin.x + map_size.x * (float(i) * 0.25)
		var gy := origin.y + map_size.y * (float(i) * 0.25)
		draw_line(Vector2(gx, origin.y + 4), Vector2(gx, origin.y + map_size.y - 4), Color(0.24, 0.34, 0.36, 0.32), 1.0)
		draw_line(Vector2(origin.x + 4, gy), Vector2(origin.x + map_size.x - 4, gy), Color(0.24, 0.34, 0.36, 0.32), 1.0)
	draw_line(Vector2(center.x, origin.y + 8), Vector2(center.x, origin.y + map_size.y - 8), Color(0.48, 0.43, 0.31, 0.55), 2.0)
	draw_line(Vector2(origin.x + 8, center.y), Vector2(origin.x + map_size.x - 8, center.y), Color(0.48, 0.43, 0.31, 0.55), 2.0)

func _draw_group_markers(origin: Vector2, scale: float) -> void:
	var map_rect := Rect2(origin, _world_size() * scale)
	var drawn_nodes: Dictionary = {}
	for group_name: String in _visible_marker_groups():
		for node in get_tree().get_nodes_in_group(group_name):
			if not is_instance_valid(node) or not (node is Node2D):
				continue
			var instance_id := node.get_instance_id()
			if drawn_nodes.has(instance_id):
				continue
			drawn_nodes[instance_id] = true
			var marker := String(node.get_meta("map_marker", _marker_from_group(group_name)))
			if not _should_draw_marker(marker):
				continue
			var color: Color = MARKER_COLORS.get(marker, Color.WHITE)
			var node2d := node as Node2D
			var pos := origin + node2d.global_position * scale
			if not map_rect.has_point(pos):
				continue
			var radius := _marker_radius(marker)
			draw_circle(pos, radius, color)
			draw_circle(pos, max(1.5, radius * 0.42), Color(1.0, 1.0, 0.78, 0.9))
			if full_screen and marker not in ["prop", "pickup", "enemy"]:
				var label := String(node.get_meta("map_label", ""))
				if not label.is_empty():
					draw_string(ThemeDB.fallback_font, pos + Vector2(8, -6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)

func _visible_marker_groups() -> Array[String]:
	if GameState.current_scene_id == "wasteland":
		if full_screen:
			return ["map_gate", "map_event", "map_boss", "map_enemy", "map_pickup", "map_player"]
		return ["map_gate", "map_boss", "map_player"]
	return ["map_station", "map_gate", "map_npc", "map_player"]

func _should_draw_marker(marker: String) -> bool:
	if GameState.current_scene_id != "wasteland":
		return marker in ["player", "npc", "station", "gate"]
	if full_screen:
		return marker in ["player", "gate", "event", "boss", "enemy", "pickup"]
	return marker in ["player", "gate", "boss"]

func _draw_viewport_box(origin: Vector2, scale: float, world: Vector2) -> void:
	var player_nodes := get_tree().get_nodes_in_group("map_player")
	if player_nodes.is_empty() or not (player_nodes[0] is Node2D):
		return
	var viewport_size := get_viewport_rect().size
	var player_pos: Vector2 = (player_nodes[0] as Node2D).global_position
	var camera_rect := Rect2(player_pos - viewport_size * 0.5, viewport_size).intersection(Rect2(Vector2.ZERO, world))
	draw_rect(Rect2(origin + camera_rect.position * scale, camera_rect.size * scale), Color(0.65, 0.82, 1.0, 0.28), false, 1.0)

func _draw_legend() -> void:
	var labels := []
	if GameState.current_scene_id == "wasteland":
		labels = [
			["player", "玩家"],
			["gate", "出口"],
			["event", "事件"],
			["boss", "Boss"],
			["enemy", "敵人"],
			["pickup", "物資"]
		]
	else:
		labels = [
			["player", "玩家"],
			["npc", "NPC"],
			["station", "設施"],
			["gate", "出口"]
		]
	var x := 28.0
	var y := size.y - 34.0
	draw_rect(Rect2(0.0, size.y - 48.0, size.x, 48.0), Color(0.025, 0.032, 0.030, 0.96), true)
	for item in labels:
		var marker := String(item[0])
		draw_circle(Vector2(x, y), 5.0, MARKER_COLORS.get(marker, Color.WHITE))
		draw_string(ThemeDB.fallback_font, Vector2(x + 10, y + 5), String(item[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
		x += 82.0

func _draw_title() -> void:
	var route := DataRegistry.get_wasteland_route(GameState.current_route_id)
	var route_name := String(route.get("name", "村莊")) if GameState.current_scene_id == "wasteland" else _scene_label()
	var title := "%s｜Seed:%d｜任務：%s" % [route_name, GameState.seed, GameState.active_quest_summary()]
	draw_string(ThemeDB.fallback_font, Vector2(28, 28), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.96, 0.94, 0.88))

func _world_size() -> Vector2:
	var scene := get_tree().current_scene
	if scene != null and scene.has_meta("map_world_size"):
		var meta_size = scene.get_meta("map_world_size")
		if meta_size is Vector2:
			return meta_size
	return get_viewport_rect().size

func _scene_label() -> String:
	var scene := get_tree().current_scene
	if scene != null and scene.has_meta("map_scene_label"):
		return String(scene.get_meta("map_scene_label"))
	match GameState.current_scene_id:
		"village":
			return "村莊"
		"guild":
			return "冒險公會"
		"wasteland":
			return "廢土"
		_:
			return "未知區域"

func _marker_from_group(group_name: String) -> String:
	match group_name:
		"map_player":
			return "player"
		"map_npc":
			return "npc"
		"map_station":
			return "station"
		"map_gate":
			return "gate"
		"map_pickup":
			return "pickup"
		"map_enemy":
			return "enemy"
		"map_boss":
			return "boss"
		"map_event":
			return "event"
		_:
			return "prop"

func _marker_radius(marker: String) -> float:
	if full_screen:
		match marker:
			"player":
				return 7.5
			"boss":
				return 8.5
			"enemy":
				return 5.5
			"prop":
				return 2.3
			_:
				return 5.0
	match marker:
		"player":
			return 5.0
		"boss":
			return 5.5
		"enemy":
			return 3.2
		"prop":
			return 1.4
		_:
			return 3.0

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		expand_requested.emit()
