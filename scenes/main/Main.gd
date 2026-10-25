extends Node2D

const BACKDROP_SCRIPT := preload("res://scripts/systems/WorldBackdrop.gd")
const ASSET_LOADER := preload("res://scripts/utils/RuntimeAssetLoader.gd")

var title_layer: CanvasLayer
var intro_active := false
var force_fullscreen_on_start := false
var title_panel: Panel
var intro_panel: Panel
var title_status: Label
var continue_button: Button
var new_game_button: Button
var new_game_confirmation: ConfirmationDialog
var _bg_backdrop: Node2D
var _title_has_save := false
var _load_pending := false

func _ready() -> void:
	if not SaveManager.load_finished.is_connected(_on_save_load_finished):
		SaveManager.load_finished.connect(_on_save_load_finished)
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
	var main_content_visible := intro_active or (is_instance_valid(title_panel) and title_panel.is_visible_in_tree())
	if main_content_visible and event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_PAGEUP, KEY_PAGEDOWN]:
		if _scroll_main_panel_content(event.keycode):
			get_viewport().set_input_as_handled()
		return
	if intro_active and event.is_action_pressed("ui_accept"):
		_finish_intro_to_game()

func _scroll_main_panel_content(keycode: int) -> bool:
	var panel := intro_panel if intro_active else title_panel
	if not is_instance_valid(panel) or not panel.is_visible_in_tree():
		return false
	var scroll := panel.find_child("PanelContentScroll", true, false) as ScrollContainer
	if scroll == null or not scroll.is_visible_in_tree():
		return false
	var scrollbar := scroll.get_v_scroll_bar()
	var maximum := maxi(0, floori(scrollbar.max_value - scrollbar.page))
	if maximum == 0:
		return false
	var page := maxi(48, floori(scroll.get_global_rect().size.y * 0.8))
	var delta := -page if keycode == KEY_PAGEUP else page
	scroll.scroll_vertical = clampi(scroll.scroll_vertical + delta, 0, maximum)
	return true

func _build_title_screen() -> void:
	# 第一個畫面：主選單。序章只會在玩家開始新旅程後顯示。
	AudioManager.play_music("intro")
	intro_active = false

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
	title_panel.custom_minimum_size = Vector2(720, 440)
	title_panel.add_theme_stylebox_override("panel", _panel_style())
	root.add_child(title_panel)
	var content := _add_panel_content(title_panel)

	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 9)
	content.add_child(stack)

	var badge := Label.new()
	badge.text = "故事篇章・灰燼之後的名字"
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 13)
	badge.add_theme_color_override("font_color", Color(0.76, 0.59, 0.35))
	stack.add_child(badge)

	var title := Label.new()
	title.text = "廢土回收商"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.91, 0.83, 0.66))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	stack.add_child(title)

	_add_story_card(
		stack,
		"村莊的水泵停了。艾倫認出你是當年撐住撤離門的騎士 R-17；你救了他和母親，門外的住戶卻失去了水源。從重接南門旁路開始，沿六區查清那道封鎖命令，為今天還在等水的人找回一條生路。",
		15
	)

	_title_has_save = SaveManager.has_save()
	continue_button = _make_styled_button("繼續旅程（讀取進度）")
	continue_button.disabled = _load_pending or not _title_has_save
	continue_button.pressed.connect(_continue_game)
	stack.add_child(continue_button)

	new_game_button = _make_styled_button("開始新旅程")
	new_game_button.disabled = _load_pending
	new_game_button.pressed.connect(_new_game)
	stack.add_child(new_game_button)

	var exit_button := _make_styled_button("離開遊戲")
	exit_button.pressed.connect(_quit_game)
	stack.add_child(exit_button)

	var help := Label.new()
	help.name = "TitleControlGuide"
	help.text = "Tab 瀏覽選單・Enter 確認・PageUp／PageDown 閱讀｜WASD 移動・移動中按下 Shift 閃避／按住 Shift 疾跑\n滑鼠左鍵主攻・右鍵遠程・Space 近戰｜入村後：E 互動・I 整備・C 工坊・J 委託・T 終端・K 手記・G 紀行・M 區域圖・H 說明"
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 13)
	help.add_theme_color_override("font_color", Color(0.73, 0.69, 0.60))
	stack.add_child(help)
	title_status = Label.new()
	title_status.add_theme_font_size_override("font_size", 14)
	title_status.add_theme_color_override("font_color", Color(1.0, 0.58, 0.42))
	title_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_status.visible = false
	stack.add_child(title_status)
	if continue_button.disabled:
		new_game_button.grab_focus()
	else:
		continue_button.grab_focus()
	_layout_title_screen()

func _make_styled_button(label_text: String) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(0, 42)
	_apply_styled_button_appearance(btn, 16)
	return btn

func _apply_styled_button_appearance(btn: Button, font_size: int) -> void:
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", Color(0.94, 0.87, 0.72))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.20, 0.15, 0.09, 0.98)
	normal.border_color = Color(0.66, 0.50, 0.29, 0.96)
	normal.border_width_left = 2
	normal.border_width_right = 2
	normal.border_width_top = 2
	normal.border_width_bottom = 2
	normal.corner_radius_top_left = 5
	normal.corner_radius_top_right = 5
	normal.corner_radius_bottom_left = 5
	normal.corner_radius_bottom_right = 5
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.27, 0.20, 0.11, 0.99)
	hover.border_color = Color(0.82, 0.66, 0.39, 1.0)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("focus", hover)

func _continue_game() -> void:
	if _load_pending:
		return
	_set_load_pending(true, "讀取中…正在進入存檔場景。")
	if not SaveManager.load_game(true, false):
		_set_load_pending(false, "讀取失敗，仍留在標題畫面；請確認存檔後重試。")

func _set_load_pending(pending: bool, message: String) -> void:
	_load_pending = pending
	if continue_button != null and is_instance_valid(continue_button):
		continue_button.disabled = pending or not _title_has_save
	if new_game_button != null and is_instance_valid(new_game_button):
		new_game_button.disabled = pending
	if title_status != null and is_instance_valid(title_status):
		title_status.text = message
		title_status.visible = not message.is_empty()

func _on_save_load_finished(succeeded: bool) -> void:
	if not _load_pending or succeeded:
		return
	_set_load_pending(false, "讀取失敗，仍留在標題畫面；請確認存檔後重試。")

func _new_game() -> void:
	if _load_pending:
		return
	if SaveManager.has_save():
		_show_new_game_confirmation()
		return
	_begin_new_game()

func _show_new_game_confirmation() -> void:
	if _load_pending:
		return
	if title_status != null and is_instance_valid(title_status):
		title_status.text = ""
		title_status.visible = false
	# Presentation-only so an isolated preview can render this dialog safely.
	if new_game_confirmation == null or not is_instance_valid(new_game_confirmation):
		new_game_confirmation = ConfirmationDialog.new()
		new_game_confirmation.name = "NewGameConfirmation"
		new_game_confirmation.title = "開始新旅程"
		new_game_confirmation.dialog_text = "此裝置只有一個存檔槽。開始新旅程會重設目前旅程；原進度會在你按下「進入村莊」完成序章時被覆寫。要開始嗎？"
		new_game_confirmation.dialog_autowrap = true
		new_game_confirmation.wrap_controls = true
		new_game_confirmation.add_theme_stylebox_override("panel", _panel_style())
		new_game_confirmation.add_theme_font_size_override("font_size", 14)
		new_game_confirmation.confirmed.connect(_begin_new_game)
		add_child(new_game_confirmation)
		var message := new_game_confirmation.get_label()
		message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var confirm_button := new_game_confirmation.get_ok_button()
		confirm_button.text = "開始新旅程"
		_apply_styled_button_appearance(confirm_button, 14)
		var cancel_button := new_game_confirmation.get_cancel_button()
		cancel_button.text = "保留原進度"
		_apply_styled_button_appearance(cancel_button, 14)
	var dialog_width := minf(480.0, maxf(1.0, float(get_window().size.x) - 48.0))
	var dialog_size := Vector2i(roundi(dialog_width), 0)
	new_game_confirmation.min_size = dialog_size
	new_game_confirmation.popup_centered(dialog_size)
	new_game_confirmation.get_cancel_button().grab_focus()
	call_deferred("_layout_new_game_confirmation")

func _begin_new_game() -> void:
	if _load_pending:
		return
	GameState.reset_new_run(true)
	_show_intro()

func _quit_game() -> void:
	get_tree().quit(0)

func _show_intro() -> void:
	# This presentation-only entry is also safe for isolated visual previews.
	intro_active = true
	AudioManager.play_music("intro")

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
	intro_panel.custom_minimum_size = Vector2(980, 620)
	intro_panel.add_theme_stylebox_override("panel", _panel_style())
	root.add_child(intro_panel)
	var content := _add_panel_content(intro_panel)

	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 14)
	content.add_child(stack)

	var title := Label.new()
	title.text = "序章｜先讓水回來"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.91, 0.83, 0.66))
	stack.add_child(title)

	_add_story_card(
		stack,
		"水泵的手輪空轉了一圈。維修艙響起艾達的聲音：「壓力又掉了。南門旁路還能接，主水源得另查。」\n\n艾倫把一截褪色的紅圍巾放到你面前。「我認得你，R-17。你撐住那道門，讓我和我媽柳青過去。但門外的水為什麼斷了，我不知道。」\n\n你的記憶停在撤離警報。艾倫收起圍巾：「先讓水回來。舊事，我們一起查。」",
		16
	)

	var directions := Label.new()
	directions.text = "先在村莊或公會按 [J] 接「南門旁路修復」。[M] 只查看地圖；走到村莊南門按 [E] 出發。\n\n第一趟：靠近回收隊按 [E] 起行，護送到繼電器，再依提示按住 [E] 接通臨時試運線、帶回讀數與水樣。第二趟：選暴露的中央公路或較長的掩蔽繞道，把正式替換接頭搬回。每趟都須走到返村門按 [E]，安全返村後才保留當趟成果。\n\n污染體 5 名與廢鐵 12 份是整章合計，可跨兩趟累積；兩趟行動及必需現場目標完成後，回村或公會按 [J] 查看進度並交付，老陳才會安裝接頭，艾達驗水後恢復有限細流。巴士名冊可選讀；[K] 查手記、[I] 整備、[C] 工坊。"
	directions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	directions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	directions.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	directions.add_theme_font_size_override("font_size", 15)
	directions.add_theme_color_override("font_color", Color(0.78, 0.72, 0.61))
	stack.add_child(directions)
	var controls := Label.new()
	controls.text = "WASD 移動・移動中按下 Shift 閃避／按住 Shift 疾跑｜滑鼠左鍵主攻・右鍵遠程・Space 近戰"
	controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_theme_font_size_override("font_size", 14)
	controls.add_theme_color_override("font_color", Color(0.73, 0.69, 0.60))
	stack.add_child(controls)

	var enter_button := _make_styled_button("進入村莊，重接第一條水路")
	enter_button.pressed.connect(_finish_intro_to_game)
	stack.add_child(enter_button)
	enter_button.grab_focus()

	var hint := Label.new()
	hint.text = "PageUp／PageDown 或滑鼠滾輪閱讀｜按 Enter 或點擊按鈕進入村莊；供水危機沒有倒數期限。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.70, 0.65, 0.55))
	stack.add_child(hint)
	_layout_title_screen()

func _layout_title_screen() -> void:
	var viewport_size := get_viewport_rect().size
	if is_instance_valid(title_panel):
		var title_size := Vector2(maxf(0.0, minf(720.0, viewport_size.x - 48.0)), maxf(0.0, minf(440.0, viewport_size.y - 48.0)))
		title_panel.custom_minimum_size = title_size
		title_panel.size = title_size
		title_panel.position = (viewport_size - title_size) * 0.5
	if is_instance_valid(intro_panel):
		var intro_size := Vector2(maxf(0.0, minf(980.0, viewport_size.x - 48.0)), maxf(0.0, minf(620.0, viewport_size.y - 48.0)))
		intro_panel.custom_minimum_size = intro_size
		intro_panel.size = intro_size
		intro_panel.position = (viewport_size - intro_size) * 0.5
	_layout_new_game_confirmation()

func _layout_new_game_confirmation() -> void:
	if not is_instance_valid(new_game_confirmation) or not new_game_confirmation.visible:
		return
	var focus_owner := new_game_confirmation.get_viewport().gui_get_focus_owner()
	var dialog_width := minf(480.0, maxf(1.0, float(get_window().size.x) - 48.0))
	var dialog_size := Vector2i(roundi(dialog_width), 0)
	new_game_confirmation.min_size = dialog_size
	new_game_confirmation.popup_centered(dialog_size)
	if focus_owner != null and is_instance_valid(focus_owner) and new_game_confirmation.is_ancestor_of(focus_owner):
		focus_owner.grab_focus()

func _add_panel_content(panel: Panel) -> ScrollContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.name = "PanelContentScroll"
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = true
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)
	return scroll

func _add_story_card(parent: Control, text: String, font_size: int) -> Label:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _parchment_style())
	parent.add_child(card)
	var story := Label.new()
	story.text = text
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	story.add_theme_font_size_override("font_size", font_size)
	story.add_theme_color_override("font_color", Color(0.19, 0.16, 0.12))
	card.add_child(story)
	return story

func _finish_intro_to_game() -> void:
	if not intro_active:
		return
	intro_active = false
	GameState.mark_intro_seen()
	SaveManager.save_game(false)
	if title_layer != null:
		title_layer.queue_free()
	SceneRouter.change_to("village", "default")

func _start_new_run_after_intro() -> void:
	_finish_intro_to_game()

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.052, 0.058, 0.068, 0.96)
	style.border_color = Color(0.53, 0.40, 0.25, 0.98)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 5
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

func _parchment_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.72, 0.64, 0.49, 0.98)
	style.border_color = Color(0.43, 0.32, 0.20, 1.0)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style
