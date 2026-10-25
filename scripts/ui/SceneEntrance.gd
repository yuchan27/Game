extends Control
## Short native pixel curtain and region title; no shaders or per-frame allocations.

signal finished

var veil := 0.0
var reveal := 0.0
var arriving := false
var title_label: Label
var subtitle_label: Label
var skip_label: Label
var _animation: Tween
var _completed := false

func _ready() -> void:
	name = "SceneEntrance"
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_to_group("gameplay_input_blocker")
	set_meta("gameplay_input_blocked", true)
	for text_node in [Label.new(), Label.new(), Label.new()]:
		text_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(text_node)
	title_label = get_child(0) as Label
	subtitle_label = get_child(1) as Label
	skip_label = get_child(2) as Label
	title_label.add_theme_font_size_override("font_size", 32)
	title_label.add_theme_color_override("font_color", Color("e6cd96"))
	subtitle_label.add_theme_font_size_override("font_size", 18)
	subtitle_label.add_theme_color_override("font_color", Color("b9b3a6"))
	skip_label.add_theme_font_size_override("font_size", 13)
	skip_label.add_theme_color_override("font_color", Color("9c9586"))
	skip_label.text = "Enter／空白鍵／Esc　略過轉場"
	resized.connect(_layout)
	_layout()

func _layout() -> void:
	if title_label == null:
		return
	var center_y := size.y * 0.40
	title_label.position = Vector2(24, center_y)
	title_label.size = Vector2(size.x - 48, 48)
	subtitle_label.position = Vector2(48, center_y + 60)
	subtitle_label.size = Vector2(size.x - 96, 112)
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	skip_label.position = Vector2(24, size.y - 64)
	skip_label.size = Vector2(size.x - 48, 24)

func cover() -> void:
	title_label.hide()
	subtitle_label.hide()
	skip_label.hide()
	_animation = create_tween()
	_animation.tween_property(self, "veil", 1.0, 0.16)
	await _animation.finished

func arrive(title: String, subtitle: String) -> void:
	arriving = true
	title_label.text = title
	subtitle_label.text = subtitle
	title_label.show()
	subtitle_label.show()
	skip_label.show()
	veil = 0.82
	_animation = create_tween()
	_animation.tween_property(self, "reveal", 1.0, 0.25)
	# Brief context remains in HUD/J after this skippable title; no new modal.
	_animation.tween_interval(clampf(float(subtitle.length()) * 0.04, 0.65, 3.0))
	_animation.tween_property(self, "modulate:a", 0.0, 0.25)
	_animation.tween_callback(finish)

func finish() -> void:
	if _completed:
		return
	_completed = true
	set_meta("gameplay_input_blocked", false)
	finished.emit()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if arriving and not event.echo and event.keycode in [KEY_ENTER, KEY_SPACE, KEY_ESCAPE]:
			if _animation != null:
				_animation.kill()
			finish()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	queue_redraw()
	if title_label != null:
		title_label.modulate.a = reveal
		subtitle_label.modulate.a = reveal
		skip_label.modulate.a = reveal

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.018, 0.020, 0.026, veil))
	if not arriving:
		return
	var y := floorf(size.y * 0.40 - 20)
	var half_width := floorf(minf(280.0, size.x * 0.3) * reveal)
	var center_x := floorf(size.x * 0.5)
	var gold := Color(0.58, 0.43, 0.23, reveal)
	draw_rect(Rect2(center_x - half_width, y, half_width * 2.0, 2), gold)
	draw_rect(Rect2(center_x - half_width, y + 212, half_width * 2.0, 2), gold)
	for index in range(12):
		var x := center_x + (float(index) - 5.5) * 32.0
		var drift := floorf(reveal * float(12 + index % 4 * 9))
		draw_rect(Rect2(x, y - drift, 2, 2), Color(0.80, 0.53, 0.23, (1.0 - reveal) * 0.7))
