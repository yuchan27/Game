extends Node2D
## Ordinary art playback of the existing Player, only in the isolated art copy.
## No QA assertions, gameplay simulation or save calls.
const PLAYER := preload("res://scenes/player/player.tscn")
const NAMES := ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
var figures: Array[Node] = []
var clock := 0.0
var family := "blade"
var prefix := "player_v2"
var output_root := ""

func _ready() -> void:
	if not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		push_error("Player art preview requires an isolated project with a dedicated custom user directory.")
		get_tree().quit(2)
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--art-output="):
			output_root = argument.trim_prefix("--art-output=")
	if output_root.is_empty() or not output_root.is_absolute_path():
		push_error("Pass --art-output=<absolute output directory> after --.")
		get_tree().quit(2)
		return
	if DirAccess.make_dir_recursive_absolute(output_root) != OK:
		push_error("Cannot create the requested art output directory.")
		get_tree().quit(2)
		return
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	RenderingServer.set_default_clear_color(Color("#23282d"))
	set_process(false)
	var args := OS.get_cmdline_user_args()
	var family_arg := args.find("--family")
	if family_arg >= 0 and family_arg + 1 < args.size():
		family = args[family_arg + 1]
		prefix += "_" + family
	if family == "rifle":
		GameState.active_quick_slot = 1
	elif family == "heavy":
		GameState.quick_slots[0] = "breaker_hammer"
		GameState.equipment["weapon"] = "breaker_hammer"
	if "--live" in OS.get_cmdline_user_args():
		for facing in 8:
			_make_figure(facing, 0, 0.0, Vector2(150 + (facing % 4) * 310, 300 + (facing / 4) * 320), 2.0)
		set_process(true)
		return
	for facing in 8:
		var at := Vector2(150 + (facing % 4) * 310, 300 + (facing / 4) * 320)
		_make_figure(facing, 0, 0.0, at + Vector2(-85, 0), 1.0)
		_make_figure(facing, 0, 0.0, at + Vector2(80, 0), 2.0)
		_label(NAMES[facing] + "   96px / 2x", at + Vector2(-100, 12))
	await _capture(prefix + "_idle.png")
	await _clear_figures()
	for key in 4:
		for facing in 8:
			var at := Vector2(85 + facing * 160, 140 + key * 170)
			_make_figure(facing, 1, float(key) / 4.0, at, 1.0)
			_label(NAMES[facing] + "  stride " + str(key + 1), at + Vector2(-55, 12))
	await _capture(prefix + "_walk_keys.png")
	await _clear_figures()
	for key in 3:
		for facing in 8:
			var at := Vector2(85 + facing * 160, 175 + key * 230)
			_make_figure(facing, 2 if family == "rifle" else 4, [0.1, 0.5, 0.9][key], at, 1.0)
			_label(NAMES[facing] + ("  fire " if family == "rifle" else "  strike ") + str(key + 1), at + Vector2(-55, 12))
	await _capture(prefix + ("_fire_keys.png" if family == "rifle" else "_strike_keys.png"))
	get_tree().quit()

func _make_figure(facing: int, action: int, phase: float, at: Vector2, zoom: float) -> void:
	var figure := PLAYER.instantiate()
	figure.get_node("Camera2D").enabled = false
	add_child(figure)
	figure.set_physics_process(false)
	figure.position = at
	figure.scale = Vector2.ONE * zoom
	figure.state = action
	figure.last_direction = Vector2.RIGHT.rotated(float(facing) * PI / 4.0)
	figure.walk_phase = phase * TAU
	figure.velocity = Vector2.RIGHT * 180.0 if action == 1 else Vector2.ZERO
	figure.action_state_duration = 0.24 if action == 2 else 0.42
	figure.action_state_timer = (1.0 - phase) * figure.action_state_duration
	figure._update_weapon_overlay()
	figure._update_animation()
	figures.append(figure)

func _label(text: String, at: Vector2) -> void:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", 16)
	add_child(label)
	figures.append(label)

func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var output_path := output_root.path_join(name)
	get_viewport().get_texture().get_image().save_png(output_path)
	print("ACTUAL_PLAYER_ART: " + output_path)

func _clear_figures() -> void:
	for figure in figures:
		figure.queue_free()
	figures.clear()
	await get_tree().process_frame

func _process(delta: float) -> void:
	clock += delta
	var stage := int(clock / 2.0) % 3
	for figure in figures:
		figure.state = [0, 1, 2 if family == "rifle" else 4][stage]
		figure.walk_phase = clock * TAU / 0.72
		figure.velocity = Vector2.RIGHT * 180.0 if stage == 1 else Vector2.ZERO
		figure.action_state_duration = 0.24 if family == "rifle" and stage == 2 else 0.42
		figure.action_state_timer = (1.0 - fposmod(clock, 0.72) / 0.72) * figure.action_state_duration
		figure._update_weapon_overlay()
		figure._update_animation()
	if Input.is_key_pressed(KEY_ESCAPE):
		get_tree().quit()
