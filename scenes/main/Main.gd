extends Node2D

const BACKDROP_SCRIPT := preload("res://scripts/systems/WorldBackdrop.gd")
const ASSET_LOADER := preload("res://scripts/utils/RuntimeAssetLoader.gd")

var title_layer: CanvasLayer
var title_voice_active := false
var intro_active := false
var force_fullscreen_on_start := true
var title_panel: Panel
var intro_panel: Panel
var title_status: Label
var _bg_backdrop: Node2D

func _ready() -> void:
	if force_fullscreen_on_start and not OS.has_feature("headless"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	get_viewport().size_changed.connect(_layout_title_screen)
	print("Waste Recycler Main scene loaded")
	DataRegistry.load_all()
	await get_tree().process_frame
	if OS.has_feature("headless"):
		SceneRouter.change_to("village", "default")
	else:
		_ensure_live_background()
		_build_title_screen()

func _ensure_live_background() -> void:
	if _bg_backdrop != null and is_instance_valid(_bg_backdrop):
		return
	_bg_backdrop = BACKDROP_SCRIPT.new()
	_bg_backdrop.setup("wasteland", Vector2i(48, 32), 2049, "scrap_highway")
	add_child(_bg_backdrop)

func _unhandled_input(event: InputEvent) -> void:
	if intro_active and event.is_action_pressed("ui_accept"):
		_finish_intro_to_game()
	elif title_voice_active and event.is_action_pressed("ui_accept"):
		_skip_title_voice()

func _build_title_screen() -> void:
	# 第一個畫面：主選單。這裡只播放世界觀說明，不播放序章內容。
	AudioManager.play_music("intro")
	title_voice_active = AudioManager.play_voice("title_story")
	intro_active = false

	if title_voice_active and AudioManager.voice_player != null and not AudioManager.voice_player.finished.is_connected(_on_title_voice_finished):
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
	backdrop.color = Color(0.035, 0.042, 0.052, 0.68)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(backdrop)

	title_panel = Panel.new()
	title_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	title_panel.custom_minimum_size = Vector2(720, 460)
	title_panel.add_theme_stylebox_override("panel", _panel_style())
	root.add_child(title_panel)
	var content := _add_panel_content(title_panel)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	content.add_child(stack)

	var badge := Label.new()
	badge.text = "◈ WASTELAND RECYCLER // R-17 VANGUARD TACTICAL EDITION"
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 13)
	badge.add_theme_color_override("font_color", Color(0.42, 0.88, 0.96))
	stack.add_child(badge)

	var title := Label.new()
	title.text = "廢土回收商"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.98, 0.82, 0.34))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	stack.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "在無盡的暴雨與輻射金屬塵落盡之後，古老文明在大崩壞中淪為死寂。你是最後一位受命啟動的十字軍先鋒機體，穿行於異變體盤據的廢土，為圍牆後殘存的生命，尋找活過明天的希望……"
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 17)
	subtitle.add_theme_color_override("font_color", Color(0.92, 0.94, 0.90))
	stack.add_child(subtitle)

	var continue_button := _make_styled_button("▶ 繼續遊戲（讀取進度）", true)
	continue_button.disabled = not SaveManager.has_save()
	continue_button.pressed.connect(_continue_game)
	stack.add_child(continue_button)

	var new_button := _make_styled_button("⚡ 開始遊戲（全新探索）", true)
	new_button.pressed.connect(_new_game)
	stack.add_child(new_button)

	var skip_button := _make_styled_button("⏭ 跳過語音說明", false)
	skip_button.disabled = not title_voice_active
	skip_button.pressed.connect(_skip_title_voice)
	stack.add_child(skip_button)

	var help := Label.new()
	var voice_hint := "🔊 主選單中文語音導覽播放中；按 Enter 或點擊跳過說明。" if title_voice_active else "主選單說明文字已顯示；按開始遊戲會進入序章。"
	help.text = "WASD 移動｜左鍵/右鍵 攻擊｜Shift 戰術閃避｜E 互動｜Tab 裝備鍛造｜M 雷達地圖\n%s" % voice_hint
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 13)
	help.add_theme_color_override("font_color", Color(0.84, 0.86, 0.78))
	stack.add_child(help)
	title_status = Label.new()
	title_status.add_theme_font_size_override("font_size", 14)
	title_status.add_theme_color_override("font_color", Color(1.0, 0.58, 0.42))
	title_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_status.visible = false
	stack.add_child(title_status)
	_layout_title_screen()

func _make_styled_button(label_text: String, primary: bool) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(0, 42)
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", Color(0.98, 0.94, 0.82) if primary else Color(0.84, 0.88, 0.88))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.11, 0.13, 0.16, 0.96) if primary else Color(0.07, 0.085, 0.105, 0.92)
	normal.border_color = Color(0.94, 0.68, 0.22, 0.95) if primary else Color(0.36, 0.58, 0.64, 0.88)
	normal.border_width_left = 2
	normal.border_width_right = 2
	normal.border_width_top = 2
	normal.border_width_bottom = 2
	normal.corner_radius_top_left = 5
	normal.corner_radius_top_right = 5
	normal.corner_radius_bottom_left = 5
	normal.corner_radius_bottom_right = 5
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.18, 0.15, 0.08, 0.98)
	hover.border_color = Color(1.0, 0.82, 0.32, 1.0)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	return btn

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
	if not SaveManager.load_game(false, false):
		if title_status != null:
			title_status.text = "讀取存檔失敗，請檢查存檔內容後再試。"
			title_status.visible = true
		return
	_skip_title_voice()
	intro_active = false
	if title_layer != null:
		title_layer.queue_free()
	get_tree().paused = false
	SceneRouter.change_to(GameState.current_scene_id, GameState.active_spawn_point)

func _new_game() -> void:
	_skip_title_voice()
	GameState.reset_new_run(true)
	_show_intro()

func _show_intro() -> void:
	# 第二個畫面：序章。開始遊戲後才進入；這裡才播放序章旁白。
	intro_active = true
	title_voice_active = false
	AudioManager.play_music("intro")
	var intro_voice_started := AudioManager.play_voice("intro_story")

	if intro_voice_started and AudioManager.voice_player != null and not AudioManager.voice_player.finished.is_connected(_finish_intro_to_game):
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
	backdrop.color = Color(0.03, 0.036, 0.046, 0.72)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(backdrop)

	intro_panel = Panel.new()
	intro_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	intro_panel.custom_minimum_size = Vector2(980, 560)
	intro_panel.add_theme_stylebox_override("panel", _panel_style())
	root.add_child(intro_panel)
	var content := _add_panel_content(intro_panel)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 14)
	content.add_child(stack)

	var title := Label.new()
	title.text = "◈ 序章：十字軍機甲 R-17 啟動誓約"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.98, 0.82, 0.34))
	stack.add_child(title)

	var body := Label.new()
	body.text = "大雨已經停了，但天空再也沒有亮過。黑色的金屬酸灰日夜不息地落下，吞噬了南方所有的道路。\n\n在被遺忘的地下深處，機體冷卻液正在沸騰，動力核心在警報聲中破開死寂。醒來吧，R-17……\n\n聽聽外面的聲音，避難所的高牆正在變異巨獸的撞擊下顫抖，老陳的鍛造爐快要熄火，孩子們的水源也即將耗盡。\n\n你的記憶體裡只剩下最後一條誓言：\n「握緊你的劍與弩砲，踏入荒原，把明天的希望……帶回村莊！」"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 20)
	body.add_theme_color_override("font_color", Color(0.94, 0.95, 0.92))
	stack.add_child(body)

	var skip_button := _make_styled_button("▶ 進入廢土村莊據點（跳過序章）", true)
	skip_button.pressed.connect(_finish_intro_to_game)
	stack.add_child(skip_button)

	var skip := Label.new()
	skip.text = "🔊 序章中文語音旁白播放中；按 Enter 或點擊按鈕可直接進入遊戲。" if intro_voice_started else "序章文字已顯示；按 Enter 或點擊按鈕可直接進入遊戲。"
	skip.add_theme_font_size_override("font_size", 13)
	skip.add_theme_color_override("font_color", Color(0.52, 0.90, 0.96))
	stack.add_child(skip)

	if not intro_voice_started:
		_layout_title_screen()
		return
	_layout_title_screen()

func _layout_title_screen() -> void:
	var viewport_size := get_viewport_rect().size
	if is_instance_valid(title_panel):
		var title_size := Vector2(min(720.0, viewport_size.x - 48.0), min(460.0, viewport_size.y - 48.0))
		title_panel.custom_minimum_size = title_size
		title_panel.size = title_size
		title_panel.position = (viewport_size - title_size) * 0.5
	if is_instance_valid(intro_panel):
		var intro_size := Vector2(min(980.0, viewport_size.x - 48.0), min(560.0, viewport_size.y - 48.0))
		intro_panel.custom_minimum_size = intro_size
		intro_panel.size = intro_size
		intro_panel.position = (viewport_size - intro_size) * 0.5

func _add_panel_content(panel: Panel) -> MarginContainer:
	var content := MarginContainer.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.add_theme_constant_override("margin_left", 22)
	content.add_theme_constant_override("margin_right", 22)
	content.add_theme_constant_override("margin_top", 18)
	content.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(content)
	return content

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
	style.bg_color = Color(0.052, 0.064, 0.080, 0.94)
	style.border_color = Color(0.94, 0.68, 0.22, 0.98)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 5
	style.border_width_bottom = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	return style
