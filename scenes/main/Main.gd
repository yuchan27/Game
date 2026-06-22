extends Node2D

var title_layer: CanvasLayer
var title_voice_active := false
var intro_active := false

func _ready() -> void:
	if not OS.has_feature("headless"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	print("Waste Recycler Main scene loaded")
	DataRegistry.load_all()
	await get_tree().process_frame
	if OS.has_feature("headless"):
		SceneRouter.change_to("village", "default")
	else:
		_build_title_screen()

func _unhandled_input(event: InputEvent) -> void:
	if intro_active and event.is_action_pressed("ui_accept"):
		_finish_intro_to_game()
	elif title_voice_active and event.is_action_pressed("ui_accept"):
		_skip_title_voice()

func _build_title_screen() -> void:
	# 第一個畫面：主選單。這裡可以播放主選單說明，但不會自動進序章。
	AudioManager.play_music("intro")
	AudioManager.play_voice("intro_story")
	title_voice_active = true
	intro_active = false

	if AudioManager.voice_player != null and not AudioManager.voice_player.finished.is_connected(_on_title_voice_finished):
		AudioManager.voice_player.finished.connect(_on_title_voice_finished)

	if title_layer == null or not is_instance_valid(title_layer):
		title_layer = CanvasLayer.new()
		add_child(title_layer)
	else:
		for child in title_layer.get_children():
			child.queue_free()

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_layer.add_child(root)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.018, 0.016, 0.014, 0.98)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(backdrop)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(720, 460)
	panel.position = Vector2(300, 130)
	panel.add_theme_stylebox_override("panel", _panel_style())
	root.add_child(panel)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 14)
	panel.add_child(stack)

	var title := Label.new()
	title.text = "廢土回收商"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	stack.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "人類文明崩壞後，資源被污染區吞沒。R-17 在維修艙甦醒，必須回收廢鐵、核心與晶體，替村莊換取下一天的能源。"
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	stack.add_child(subtitle)

	var continue_button := Button.new()
	continue_button.text = "繼續遊戲"
	continue_button.disabled = not SaveManager.has_save()
	continue_button.pressed.connect(_continue_game)
	stack.add_child(continue_button)

	var new_button := Button.new()
	new_button.text = "開始遊戲"
	new_button.pressed.connect(_new_game)
	stack.add_child(new_button)

	var skip_button := Button.new()
	skip_button.text = "跳過說明"
	skip_button.pressed.connect(_skip_title_voice)
	stack.add_child(skip_button)

	var help := Label.new()
	help.text = "WASD 移動｜滑鼠左鍵依裝備攻擊｜E 互動｜Tab 人物裝備｜M 地圖｜Esc 暫停\n主選單說明播放中；按 Enter 或點擊跳過說明。"
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 14)
	stack.add_child(help)

func _on_title_voice_finished() -> void:
	title_voice_active = false
	if AudioManager.voice_player != null and AudioManager.voice_player.finished.is_connected(_on_title_voice_finished):
		AudioManager.voice_player.finished.disconnect(_on_title_voice_finished)

func _skip_title_voice() -> void:
	if not title_voice_active:
		return
	title_voice_active = false
	if AudioManager.voice_player != null and AudioManager.voice_player.finished.is_connected(_on_title_voice_finished):
		AudioManager.voice_player.finished.disconnect(_on_title_voice_finished)
	AudioManager.stop_voice()

func _continue_game() -> void:
	_skip_title_voice()
	intro_active = false
	if title_layer != null:
		title_layer.queue_free()
	SaveManager.load_game(true, true)

func _new_game() -> void:
	_skip_title_voice()
	GameState.reset_new_run(true)
	_show_intro()

func _show_intro() -> void:
	# 第二個畫面：序章。開始遊戲後才進入；旁白結束或按 Enter/跳過後正式進入村莊。
	intro_active = true
	title_voice_active = false
	AudioManager.play_music("intro")
	AudioManager.play_voice("intro_story")

	if AudioManager.voice_player != null and not AudioManager.voice_player.finished.is_connected(_finish_intro_to_game):
		AudioManager.voice_player.finished.connect(_finish_intro_to_game)

	if title_layer == null or not is_instance_valid(title_layer):
		title_layer = CanvasLayer.new()
		add_child(title_layer)
	else:
		for child in title_layer.get_children():
			child.queue_free()

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_layer.add_child(root)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.012, 0.012, 0.014, 0.98)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(backdrop)

	var panel := PanelContainer.new()
	panel.position = Vector2(180, 96)
	panel.custom_minimum_size = Vector2(980, 560)
	panel.add_theme_stylebox_override("panel", _panel_style())
	root.add_child(panel)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 16)
	panel.add_child(stack)

	var title := Label.new()
	title.text = "序章：R-17 甦醒"
	title.add_theme_font_size_override("font_size", 30)
	stack.add_child(title)

	var body := Label.new()
	body.text = "第一紀元的最後一年，天空不再下雨，只落下帶著金屬味的灰。\n\n人類把城市拆成燃料，把河床挖成電池，最後連記憶也拿去交換乾淨的水。舊工廠失控後，污染帶吞掉南方平原，只剩這座村莊還在廢鐵牆後微弱發光。\n\n你是 R-17，最後一台仍願意走進廢土的回收機器人。你的核心裡存著一段命令：帶回能讓大家活到明天的資源。\n\n四條路通往不同的污染區。每一次出門，都是一次交易：用鋼鐵身軀承受荒野，把廢墟裡的希望帶回來。"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 20)
	stack.add_child(body)

	var skip_button := Button.new()
	skip_button.text = "跳過序章"
	skip_button.pressed.connect(_finish_intro_to_game)
	stack.add_child(skip_button)

	var skip := Label.new()
	skip.text = "旁白播放中；按 Enter 或點擊跳過序章可直接進入遊戲。"
	skip.add_theme_font_size_override("font_size", 13)
	stack.add_child(skip)

	if AudioManager.voice_player == null or not AudioManager.voice_player.playing:
		call_deferred("_finish_intro_to_game")

func _finish_intro_to_game() -> void:
	if not intro_active:
		return
	intro_active = false
	if AudioManager.voice_player != null and AudioManager.voice_player.finished.is_connected(_finish_intro_to_game):
		AudioManager.voice_player.finished.disconnect(_finish_intro_to_game)
	AudioManager.stop_voice()
	GameState.mark_intro_seen()
	SaveManager.save_game(false)
	if title_layer != null:
		title_layer.queue_free()
	SceneRouter.change_to("village", "default")

func _start_new_run_after_intro() -> void:
	_finish_intro_to_game()

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.027, 0.026, 0.92)
	style.border_color = Color(0.80, 0.58, 0.26, 0.96)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	return style
