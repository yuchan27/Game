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
	custom_minimum_size = Vector2(210, 116)
	gui_input.connect(_on_gui_input)

func set_full_screen(enabled: bool) -> void:
	full_screen = enabled
	custom_minimum_size = Vector2(900, 560) if full_screen else Vector2(210, 116)
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.035, 0.045, 0.045, 0.95), true)
	draw_rect(rect, Color(0.38, 0.45, 0.40, 0.92), false, 1.0)
	var world: Vector2 = _world_size()
	var padding: float = 24.0 if full_screen else 8.0
	var scale: float = min((size.x - padding * 2.0) / max(1.0, world.x), (size.y - padding * 2.0) / max(1.0, world.y))
	var map_size: Vector2 = world * scale
	var origin: Vector2 = (size - map_size) * 0.5
	draw_rect(Rect2(origin, map_size), Color(0.08, 0.10, 0.09, 0.75), true)
	draw_rect(Rect2(origin, map_size), Color(0.46, 0.42, 0.32, 0.85), false, 1.0)
	_draw_route_frame(origin, map_size)
	_draw_viewport_box(origin, scale, world)
	_draw_group_markers(origin, scale)
	if full_screen:
		_draw_legend()
		_draw_title()

func _draw_route_frame(origin: Vector2, map_size: Vector2) -> void:
	var center := origin + map_size * 0.5
	draw_line(Vector2(center.x, origin.y + 8), Vector2(center.x, origin.y + map_size.y - 8), Color(0.48, 0.43, 0.31, 0.55), 2.0)
	draw_line(Vector2(origin.x + 8, center.y), Vector2(origin.x + map_size.x - 8, center.y), Color(0.48, 0.43, 0.31, 0.55), 2.0)

func _draw_group_markers(origin: Vector2, scale: float) -> void:
	for group_name: String in _visible_marker_groups():
		for node in get_tree().get_nodes_in_group(group_name):
			if not is_instance_valid(node) or not (node is Node2D):
				continue
			var marker := String(node.get_meta("map_marker", _marker_from_group(group_name)))
			if not _should_draw_marker(marker):
				continue
			var color: Color = MARKER_COLORS.get(marker, Color.WHITE)
			var node2d := node as Node2D
			var pos := origin + node2d.global_position * scale
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
			return ["map_gate", "map_event", "map_boss", "map_player"]
		return ["map_gate", "map_boss", "map_player"]
	return ["map_station", "map_gate", "map_npc", "map_player"]

func _should_draw_marker(marker: String) -> bool:
	if GameState.current_scene_id != "wasteland":
		return marker in ["player", "npc", "station", "gate"]
	if full_screen:
		return marker in ["player", "gate", "event", "boss"]
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
			["boss", "Boss"]
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
	for item in labels:
		var marker := String(item[0])
		draw_circle(Vector2(x, y), 5.0, MARKER_COLORS.get(marker, Color.WHITE))
		draw_string(ThemeDB.fallback_font, Vector2(x + 10, y + 5), String(item[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
		x += 82.0

func _draw_title() -> void:
	var route := DataRegistry.get_wasteland_route(GameState.current_route_id)
	var route_name := String(route.get("name", "村莊")) if GameState.current_scene_id == "wasteland" else _scene_label()
	var title := "%s｜任務：%s" % [route_name, GameState.active_quest_summary()]
	draw_string(ThemeDB.fallback_font, Vector2(28, 28), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)

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
	return GameState.current_scene_id

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
