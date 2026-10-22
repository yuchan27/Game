extends CanvasLayer

const MAP_VIEW := preload("res://scripts/ui/WorldMapView.gd")
const PIXEL := preload("res://scripts/utils/PixelArtFactory.gd")
const ASSET_LOADER := preload("res://scripts/utils/RuntimeAssetLoader.gd")
const INVENTORY_SYSTEM := preload("res://scripts/systems/InventorySystem.gd")

var root: Control
var status_panel: PanelContainer
var stats_label: Label
var hp_bar: ProgressBar
var ep_bar: ProgressBar
var hp_value_label: Label
var ep_value_label: Label
var quest_panel: PanelContainer
var quest_header_label: Label
var quest_label: Label
var nav_bar_panel: PanelContainer
var nav_bar: HBoxContainer
var quick_bar_panel: PanelContainer
var quick_bar: HBoxContainer
var inventory_panel: PanelContainer
var inventory_list: VBoxContainer
var workshop_panel: PanelContainer
var workshop_list: VBoxContainer
var contract_panel: PanelContainer
var contract_list: VBoxContainer
var terminal_panel: PanelContainer
var terminal_list: VBoxContainer
var codex_panel: PanelContainer
var codex_list: VBoxContainer
var notice_label: Label
var notice_timer: Timer
var minimap_panel: PanelContainer
var minimap_title: Label
var map_view
var tutorial_panel: PanelContainer
var controls_hint: Label
var dialogue_panel: PanelContainer
var dialogue_portrait: TextureRect
var dialogue_speaker: Label
var dialogue_role: Label
var dialogue_body: Label
var dialogue_timer: Timer
var pause_panel: PanelContainer
var map_open := true
var map_fullscreen := false
var workshop_active_tab := "craft"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("hud")
	_build_hud()
	GameState.stats_changed.connect(_refresh)
	GameState.inventory_changed.connect(_refresh_inventory)
	GameState.inventory_changed.connect(_refresh_workshop)
	GameState.equipment_changed.connect(_refresh_inventory)
	GameState.equipment_changed.connect(_refresh_workshop)
	GameState.equipment_changed.connect(_refresh_terminal)
	GameState.equipment_changed.connect(_refresh_hotbar)
	GameState.inventory_changed.connect(_refresh_terminal)
	GameState.notification_requested.connect(_show_notice)
	GameState.dialogue_requested.connect(_show_dialogue)
	GameState.dialogue_closed.connect(_hide_dialogue)
	get_viewport().size_changed.connect(_layout)
	_refresh()
	_refresh_hotbar()
	_refresh_inventory()
	_refresh_overlay_visibility()
	_layout()

func _process(_delta: float) -> void:
	if pause_panel.visible:
		return
	if Input.is_action_just_pressed("open_inventory"):
		_set_inventory_visible(not inventory_panel.visible)
	if Input.is_action_just_pressed("toggle_minimap"):
		_toggle_map()
	if Input.is_action_just_pressed("toggle_help"):
		_set_tutorial_visible(not tutorial_panel.visible)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if inventory_panel.visible:
				_set_inventory_visible(false)
			elif workshop_panel != null and workshop_panel.visible:
				_set_workshop_visible(false)
			elif contract_panel != null and contract_panel.visible:
				_set_contract_visible(false)
			elif terminal_panel != null and terminal_panel.visible:
				_set_terminal_visible(false)
			elif codex_panel != null and codex_panel.visible:
				_set_codex_visible(false)
			elif tutorial_panel.visible:
				_set_tutorial_visible(false)
			elif map_fullscreen:
				map_fullscreen = false
				_refresh_overlay_visibility()
			elif dialogue_panel.visible:
				_hide_dialogue()
			elif pause_panel.visible:
				_set_pause_visible(false)
			else:
				_set_pause_visible(true)
		elif not pause_panel.visible:
			if event.keycode == KEY_C:
				_set_workshop_visible(not workshop_panel.visible)
			elif event.keycode == KEY_J:
				_set_contract_visible(not contract_panel.visible)
			elif event.keycode == KEY_T:
				_set_terminal_visible(not (terminal_panel != null and terminal_panel.visible))
			elif event.keycode == KEY_K:
				_set_codex_visible(not codex_panel.visible)

func _layout() -> void:
	var size: Vector2 = get_viewport().get_visible_rect().size
	if status_panel != null:
		var st_w := minf(290.0, size.x - 32.0)
		status_panel.position = Vector2(16.0, 14.0)
		status_panel.custom_minimum_size = Vector2(st_w, 68)
		status_panel.size = Vector2(st_w, 68)
	if quest_panel != null:
		var q_w := minf(290.0, size.x - 32.0)
		var q_top: float = (status_panel.position.y + status_panel.size.y + 6.0) if status_panel != null else 88.0
		quest_panel.position = Vector2(16.0, q_top)
		quest_panel.custom_minimum_size = Vector2(q_w, 42)
		quest_panel.size = Vector2(q_w, 42)
	if nav_bar_panel != null:
		var nav_w := minf(540.0, size.x - 32.0)
		nav_bar_panel.position = Vector2(max(16.0, (size.x - nav_w) * 0.5), size.y - 94.0)
		nav_bar_panel.custom_minimum_size = Vector2(nav_w, 28)
		nav_bar_panel.size = Vector2(nav_w, 28)
	if quick_bar_panel != null:
		var quick_w := minf(520.0, size.x - 32.0)
		quick_bar_panel.position = Vector2(max(16.0, (size.x - quick_w) * 0.5), size.y - 64.0)
		quick_bar_panel.custom_minimum_size = Vector2(quick_w, 56)
		quick_bar_panel.size = Vector2(quick_w, 56)
	if controls_hint != null:
		controls_hint.position = Vector2(max(16.0, (size.x - controls_hint.size.x) * 0.5), size.y - 114.0)
		controls_hint.visible = false
	if dialogue_panel != null:
		var dialogue_size := Vector2(min(920.0, size.x - 48.0), min(248.0, size.y - 96.0))
		dialogue_panel.position = Vector2(max(24.0, (size.x - dialogue_size.x) * 0.5), size.y - dialogue_size.y - 12.0)
		dialogue_panel.custom_minimum_size = dialogue_size
		dialogue_panel.size = dialogue_size
		if dialogue_portrait != null:
			dialogue_portrait.custom_minimum_size.x = 96.0 if size.x < 1120.0 else 122.0
		if dialogue_body != null:
			dialogue_body.custom_minimum_size = Vector2(max(300.0, dialogue_size.x - 206.0), max(88.0, dialogue_size.y - 104.0))
	if minimap_panel != null:
		if map_fullscreen:
			minimap_panel.position = Vector2(24, 24)
			minimap_panel.custom_minimum_size = size - Vector2(48, 48)
			minimap_panel.size = size - Vector2(48, 48)
		else:
			minimap_panel.position = Vector2(max(16.0, size.x - 152.0), 14.0)
			minimap_panel.custom_minimum_size = Vector2(138, 142)
			minimap_panel.size = Vector2(138, 142)

	var modal_size: Vector2 = Vector2(min(1100.0, size.x - 44.0), min(610.0, size.y - 64.0))
	var modal_pos := Vector2(max(22.0, (size.x - modal_size.x) * 0.5), max(24.0, (size.y - modal_size.y) * 0.5))
	for panel: PanelContainer in [inventory_panel, workshop_panel, contract_panel, terminal_panel, codex_panel]:
		if panel != null:
			panel.position = modal_pos
			panel.custom_minimum_size = modal_size
			panel.size = modal_size
	if tutorial_panel != null:
		var tutorial_size: Vector2 = Vector2(min(760.0, size.x - 44.0), min(560.0, size.y - 110.0))
		tutorial_panel.position = Vector2(max(22.0, (size.x - tutorial_size.x) * 0.5), max(52.0, (size.y - tutorial_size.y) * 0.5))
		tutorial_panel.custom_minimum_size = tutorial_size
		tutorial_panel.size = tutorial_size
	if pause_panel != null:
		pause_panel.position = Vector2((size.x - 340.0) * 0.5, (size.y - 330.0) * 0.5)
		pause_panel.custom_minimum_size = Vector2(340, 330)
		pause_panel.size = Vector2(340, 330)
	if notice_label != null:
		var notice_y: float = 136.0 if pause_panel != null and pause_panel.visible else 126.0
		notice_label.position = Vector2(max(18.0, (size.x - notice_label.size.x) * 0.5), notice_y)

func _build_hud() -> void:
	root = Control.new()
	root.name = "HudRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_status_panel()
	_build_quest_panel()
	_build_inventory_panel()
	_build_workshop_panel()
	_build_contract_panel()
	_build_terminal_panel()
	_build_codex_panel()
	_add_nav_bar()
	_add_quick_bar()
	_add_minimap()
	_add_tutorial()
	_add_controls_hint()
	_add_dialogue_box()
	_add_pause_menu()
	_add_notice_label()

func _build_status_panel() -> void:
	status_panel = PanelContainer.new()
	status_panel.name = "StatusPanel"
	status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st_style := _panel_style(Color(0.045, 0.055, 0.07, 0.78), Color(0.72, 0.54, 0.22, 0.75), 1)
	st_style.corner_radius_top_left = 6
	st_style.corner_radius_top_right = 6
	st_style.corner_radius_bottom_left = 6
	st_style.corner_radius_bottom_right = 6
	status_panel.add_theme_stylebox_override("panel", st_style)
	root.add_child(status_panel)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 2)
	status_panel.add_child(stack)
	stats_label = Label.new()
	stats_label.add_theme_font_size_override("font_size", 12)
	stats_label.add_theme_color_override("font_color", Color(0.98, 0.92, 0.74))
	stats_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	stats_label.add_theme_constant_override("shadow_offset_x", 1)
	stats_label.add_theme_constant_override("shadow_offset_y", 1)
	stack.add_child(stats_label)
	hp_bar = _make_bar(Color(0.88, 0.24, 0.22), Color(0.18, 0.05, 0.06, 0.95))
	ep_bar = _make_bar(Color(0.20, 0.84, 0.72), Color(0.04, 0.16, 0.18, 0.95))
	hp_value_label = _attach_bar_overlay_label(hp_bar)
	ep_value_label = _attach_bar_overlay_label(ep_bar)
	stack.add_child(_bar_row("裝甲", hp_bar, Color(1.0, 0.56, 0.52)))
	stack.add_child(_bar_row("能量", ep_bar, Color(0.48, 0.96, 0.86)))

func _build_quest_panel() -> void:
	quest_panel = PanelContainer.new()
	quest_panel.name = "QuestPanel"
	quest_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var q_style := _panel_style(Color(0.045, 0.055, 0.07, 0.70), Color(0.25, 0.45, 0.52, 0.60), 1)
	q_style.corner_radius_top_left = 6
	q_style.corner_radius_top_right = 6
	q_style.corner_radius_bottom_left = 6
	q_style.corner_radius_bottom_right = 6
	quest_panel.add_theme_stylebox_override("panel", q_style)
	root.add_child(quest_panel)
	var q_stack := VBoxContainer.new()
	q_stack.add_theme_constant_override("separation", 1)
	quest_panel.add_child(q_stack)
	quest_header_label = Label.new()
	quest_header_label.text = "◈ 村莊"
	quest_header_label.add_theme_font_size_override("font_size", 12)
	quest_header_label.add_theme_color_override("font_color", Color(0.42, 0.88, 0.96))
	q_stack.add_child(quest_header_label)
	quest_label = Label.new()
	quest_label.add_theme_font_size_override("font_size", 11)
	quest_label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.88))
	quest_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	quest_label.add_theme_constant_override("shadow_offset_x", 1)
	quest_label.add_theme_constant_override("shadow_offset_y", 1)
	quest_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q_stack.add_child(quest_label)

func _add_nav_bar() -> void:
	nav_bar_panel = PanelContainer.new()
	nav_bar_panel.name = "NavBarPanel"
	nav_bar_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var nb_style := _panel_style(Color(0.045, 0.052, 0.066, 0.75), Color(0.35, 0.45, 0.52, 0.65), 1)
	nb_style.corner_radius_top_left = 5
	nb_style.corner_radius_top_right = 5
	nb_style.corner_radius_bottom_left = 5
	nb_style.corner_radius_bottom_right = 5
	nb_style.content_margin_top = 2
	nb_style.content_margin_bottom = 2
	nav_bar_panel.add_theme_stylebox_override("panel", nb_style)
	root.add_child(nav_bar_panel)
	nav_bar = HBoxContainer.new()
	nav_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	nav_bar.add_theme_constant_override("separation", 6)
	nav_bar_panel.add_child(nav_bar)
	var entries := [
		["[Tab] 裝備", func() -> void: _set_inventory_visible(true)],
		["[C] 工坊", func() -> void: _set_workshop_visible(true)],
		["[J] 委託", func() -> void: _set_contract_visible(true)],
		["[T] 終端", func() -> void: _set_terminal_visible(true)],
		["[K] 圖鑑", func() -> void: _set_codex_visible(true)],
		["[M] 地圖", func() -> void: set_fullscreen_map(true)],
		["[H] 說明", func() -> void: _set_tutorial_visible(true)],
	]
	for entry in entries:
		var btn := Button.new()
		btn.text = String(entry[0])
		btn.custom_minimum_size = Vector2(80, 24)
		btn.add_theme_font_size_override("font_size", 11)
		btn.add_theme_color_override("font_color", Color(0.95, 0.90, 0.74))
		btn.add_theme_stylebox_override("normal", _button_style(false))
		btn.add_theme_stylebox_override("hover", _button_style(true))
		btn.pressed.connect(entry[1])
		nav_bar.add_child(btn)


func _build_modal_switcher(active_tab: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var tabs := [
		["inventory", "⚙ [Tab] 人物裝備", func() -> void: _set_inventory_visible(true)],
		["workshop", "🔨 [C] 工坊與補給", func() -> void: _set_workshop_visible(true)],
		["contract", "📜 [J] 委託與路線", func() -> void: _set_contract_visible(true)],
		["terminal", "💻 [T] 終端操作", func() -> void: _set_terminal_visible(true)],
		["codex", "📖 [K] 廢土圖鑑", func() -> void: _set_codex_visible(true)],
		["tutorial", "❓ [H] 遊戲說明", func() -> void: _set_tutorial_visible(true)],
	]
	for t in tabs:
		var is_cur := String(t[0]) == active_tab
		var btn := Button.new()
		btn.text = String(t[1])
		btn.custom_minimum_size = Vector2(146, 36)
		btn.add_theme_font_size_override("font_size", 13)
		btn.add_theme_color_override("font_color", Color(1.0, 0.92, 0.52) if is_cur else Color(0.84, 0.86, 0.82))
		btn.add_theme_stylebox_override("normal", _button_style(is_cur))
		btn.add_theme_stylebox_override("hover", _button_style(true))
		btn.pressed.connect(t[2])
		row.add_child(btn)
	var close_btn := Button.new()
	close_btn.text = "✕ 關閉 [Esc]"
	close_btn.custom_minimum_size = Vector2(108, 36)
	close_btn.add_theme_font_size_override("font_size", 13)
	close_btn.add_theme_color_override("font_color", Color(1.0, 0.68, 0.62))
	close_btn.add_theme_stylebox_override("normal", _button_style(false))
	close_btn.add_theme_stylebox_override("hover", _button_style(true))
	close_btn.pressed.connect(_close_all_modals)
	row.add_child(close_btn)
	return row

func _close_all_modals() -> void:
	inventory_panel.visible = false
	if workshop_panel != null:
		workshop_panel.visible = false
	if contract_panel != null:
		contract_panel.visible = false
	if terminal_panel != null:
		terminal_panel.visible = false
	if codex_panel != null:
		codex_panel.visible = false
	tutorial_panel.visible = false
	_refresh_overlay_visibility()

func _build_inventory_panel() -> void:
	inventory_panel = PanelContainer.new()
	inventory_panel.name = "InventoryPanel"
	inventory_panel.add_to_group("equipment_panel")
	inventory_panel.add_to_group("gameplay_input_blocker")
	inventory_panel.set_meta("gameplay_input_blocked", false)
	inventory_panel.z_index = 60
	inventory_panel.visible = false
	inventory_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	inventory_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.055, 0.068, 0.082, 0.995), Color(0.91, 0.66, 0.22, 0.98), 2))
	root.add_child(inventory_panel)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.clip_contents = true
	inventory_panel.add_child(scroll)
	inventory_list = VBoxContainer.new()
	inventory_list.add_theme_constant_override("separation", 10)
	scroll.add_child(inventory_list)

func _build_workshop_panel() -> void:
	workshop_panel = PanelContainer.new()
	workshop_panel.name = "WorkshopPanel"
	workshop_panel.add_to_group("workshop_panel")
	workshop_panel.add_to_group("gameplay_input_blocker")
	workshop_panel.set_meta("gameplay_input_blocked", false)
	workshop_panel.z_index = 60
	workshop_panel.visible = false
	workshop_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	workshop_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.052, 0.064, 0.078, 0.995), Color(0.92, 0.64, 0.24, 0.98), 2))
	root.add_child(workshop_panel)
	var scroll := ScrollContainer.new()
	scroll.clip_contents = true
	workshop_panel.add_child(scroll)
	workshop_list = VBoxContainer.new()
	workshop_list.add_theme_constant_override("separation", 10)
	scroll.add_child(workshop_list)

func _build_contract_panel() -> void:
	contract_panel = PanelContainer.new()
	contract_panel.name = "ContractPanel"
	contract_panel.add_to_group("contract_panel")
	contract_panel.add_to_group("gameplay_input_blocker")
	contract_panel.set_meta("gameplay_input_blocked", false)
	contract_panel.z_index = 60
	contract_panel.visible = false
	contract_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	contract_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.050, 0.062, 0.080, 0.995), Color(0.36, 0.82, 0.92, 0.98), 2))
	root.add_child(contract_panel)
	var scroll := ScrollContainer.new()
	scroll.clip_contents = true
	contract_panel.add_child(scroll)
	contract_list = VBoxContainer.new()
	contract_list.add_theme_constant_override("separation", 10)
	scroll.add_child(contract_list)

func _build_terminal_panel() -> void:
	terminal_panel = PanelContainer.new()
	terminal_panel.name = "TerminalPanel"
	terminal_panel.add_to_group("terminal_panel")
	terminal_panel.add_to_group("gameplay_input_blocker")
	terminal_panel.set_meta("gameplay_input_blocked", false)
	terminal_panel.z_index = 60
	terminal_panel.visible = false
	terminal_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	terminal_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.040, 0.055, 0.075, 0.995), Color(0.24, 0.88, 0.82, 0.98), 2))
	root.add_child(terminal_panel)
	var scroll := ScrollContainer.new()
	scroll.clip_contents = true
	terminal_panel.add_child(scroll)
	terminal_list = VBoxContainer.new()
	terminal_list.add_theme_constant_override("separation", 10)
	scroll.add_child(terminal_list)

func _build_codex_panel() -> void:
	codex_panel = PanelContainer.new()
	codex_panel.name = "CodexPanel"
	codex_panel.add_to_group("codex_panel")
	codex_panel.add_to_group("gameplay_input_blocker")
	codex_panel.set_meta("gameplay_input_blocked", false)
	codex_panel.z_index = 60
	codex_panel.visible = false
	codex_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	codex_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.048, 0.058, 0.074, 0.995), Color(0.86, 0.68, 0.28, 0.98), 2))
	root.add_child(codex_panel)
	var scroll := ScrollContainer.new()
	scroll.clip_contents = true
	codex_panel.add_child(scroll)
	codex_list = VBoxContainer.new()
	codex_list.add_theme_constant_override("separation", 10)
	scroll.add_child(codex_list)

func _add_quick_bar() -> void:
	quick_bar_panel = PanelContainer.new()
	quick_bar_panel.name = "QuickBar"
	quick_bar_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var qb_style := _panel_style(Color(0.048, 0.058, 0.074, 0.94), Color(0.88, 0.64, 0.22, 0.92), 2)
	qb_style.border_width_top = 3
	quick_bar_panel.add_theme_stylebox_override("panel", qb_style)
	root.add_child(quick_bar_panel)
	quick_bar = HBoxContainer.new()
	quick_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	quick_bar.add_theme_constant_override("separation", 8)
	quick_bar_panel.add_child(quick_bar)

func _add_minimap() -> void:
	minimap_panel = PanelContainer.new()
	minimap_panel.name = "MinimapPanel"
	minimap_panel.add_to_group("minimap_panel")
	minimap_panel.add_to_group("gameplay_input_blocker")
	minimap_panel.set_meta("gameplay_input_blocked", false)
	minimap_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mm_style := _panel_style(Color(0.038, 0.050, 0.065, 0.70), Color(0.24, 0.45, 0.52, 0.55), 1)
	mm_style.corner_radius_top_left = 8
	mm_style.corner_radius_top_right = 8
	mm_style.corner_radius_bottom_left = 8
	mm_style.corner_radius_bottom_right = 8
	minimap_panel.add_theme_stylebox_override("panel", mm_style)
	root.add_child(minimap_panel)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 2)
	minimap_panel.add_child(stack)
	minimap_title = Label.new()
	minimap_title.text = "◈ 雷達 [M]"
	minimap_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	minimap_title.add_theme_font_size_override("font_size", 11)
	minimap_title.add_theme_color_override("font_color", Color(0.55, 0.85, 0.90, 0.8))
	stack.add_child(minimap_title)
	map_view = MAP_VIEW.new()
	map_view.custom_minimum_size = Vector2(136, 118)
	stack.add_child(map_view)


func _add_tutorial() -> void:
	tutorial_panel = PanelContainer.new()
	tutorial_panel.name = "TutorialPanel"
	tutorial_panel.add_to_group("tutorial_panel")
	tutorial_panel.add_to_group("gameplay_input_blocker")
	tutorial_panel.set_meta("gameplay_input_blocked", false)
	tutorial_panel.z_index = 65
	tutorial_panel.visible = false
	tutorial_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var tut_style := _panel_style(Color(0.08, 0.075, 0.07, 0.992), Color(0.86, 0.64, 0.26, 0.98), 3)
	tut_style.border_width_top = 5
	tutorial_panel.add_theme_stylebox_override("panel", tut_style)
	root.add_child(tutorial_panel)

	var scroll := ScrollContainer.new()
	scroll.clip_contents = true
	tutorial_panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)

	var header := Label.new()
	header.text = "◈ 廢土回收商 — 遊戲說明與戰術指南 [H]"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 22)
	header.add_theme_color_override("font_color", Color(0.98, 0.84, 0.42))
	vbox.add_child(header)

	# Section 1: 基本操作 (Keycap badge rows matching 參考圖片.png)
	var sec_ops := _make_section_box(vbox, "• 基本操作 (Controls)")
	var ops_grid := GridContainer.new()
	ops_grid.columns = 2
	ops_grid.add_theme_constant_override("h_separation", 18)
	ops_grid.add_theme_constant_override("v_separation", 6)
	sec_ops.add_child(ops_grid)
	for pair in [
		["[W][A][S][D] / 方向鍵", "八向戰術移動"],
		["[滑鼠左鍵 / 右鍵]", "主武裝攻擊 / 雙段連斬揮砍"],
		["[Shift]", "戰術衝刺閃避（消耗 EP，停步自動回復）"],
		["[E]", "與工作台 / NPC / 路線閘門互動"],
		["[1] [2] [3] [4] / [Q]", "切換快捷武裝（近戰 / 遠程 / 工具）"],
		["[Tab] / [C] / [J] / [K]", "裝備面板 / 工坊合成 / 公會委託 / 武裝圖鑑"],
	]:
		var k_lbl := Label.new()
		k_lbl.text = String(pair[0])
		k_lbl.add_theme_font_size_override("font_size", 14)
		k_lbl.add_theme_color_override("font_color", Color(0.98, 0.86, 0.44))
		ops_grid.add_child(k_lbl)
		var v_lbl := Label.new()
		v_lbl.text = String(pair[1])
		v_lbl.add_theme_font_size_override("font_size", 14)
		v_lbl.add_theme_color_override("font_color", Color(0.92, 0.92, 0.88))
		ops_grid.add_child(v_lbl)

	# Section 2: 遊戲流程 (Flowchart cards matching 參考圖片.png)
	var sec_flow := _make_section_box(vbox, "• 遊戲流程 (Core Loop)")
	var flow_row := HBoxContainer.new()
	flow_row.alignment = BoxContainer.ALIGNMENT_CENTER
	flow_row.add_theme_constant_override("separation", 8)
	sec_flow.add_child(flow_row)
	for step_txt in ["1. 探索廢土路線", "➔", "2. 擊敗污染變異體", "➔", "3. 回收廢鐵與核心", "➔", "4. 工坊鍛造與公會委託"]:
		if step_txt == "➔":
			var arr := Label.new()
			arr.text = "➔"
			arr.add_theme_font_size_override("font_size", 18)
			arr.add_theme_color_override("font_color", Color(0.96, 0.76, 0.28))
			flow_row.add_child(arr)
		else:
			var card := PanelContainer.new()
			card.add_theme_stylebox_override("panel", _panel_style(Color(0.14, 0.12, 0.09, 0.95), Color(0.76, 0.58, 0.26, 0.92), 1))
			var clbl := Label.new()
			clbl.text = step_txt
			clbl.add_theme_font_size_override("font_size", 13)
			clbl.add_theme_color_override("font_color", Color(0.98, 0.94, 0.82))
			card.add_child(clbl)
			flow_row.add_child(card)

	# Section 3: 狀態說明 & 成長規則
	var sec_status := _make_section_box(vbox, "• 狀態說明與武裝成長")
	var status_txt := Label.new()
	status_txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_txt.add_theme_font_size_override("font_size", 14)
	status_txt.add_theme_color_override("font_color", Color(0.90, 0.92, 0.88))
	status_txt.text = "▪ HP 裝甲生命值：歸零時緊急撤離回村莊維修艙。\n▪ EP 能量值：用於衝刺與戰術閃避，停止衝刺時自動充能。\n▪ 村莊工坊 [C]：可鍛造彈藥、合成二階近戰/遠程武器與前三階護甲、拆解變異核心。\n▪ 冒險公會 [J]：承接六大廢土路線委託，完成後解鎖三階神兵與高階動力裝甲。"
	sec_status.add_child(status_txt)

	# Section 4: 小提示
	var sec_tips := _make_section_box(vbox, "• 廢土生存小提示")
	var tips_txt := Label.new()
	tips_txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tips_txt.add_theme_font_size_override("font_size", 13)
	tips_txt.add_theme_color_override("font_color", Color(0.82, 0.94, 0.78))
	tips_txt.text = "• 近戰揮砍具備雙段連擊弧光且不消耗彈藥，適合清理小型污染體並節省彈藥。\n• 面對 Boss「廢土巨像」時，善用 [Shift] 閃避衝擊波並切換高穿甲遠程武器輸出。"
	sec_tips.add_child(tips_txt)

	var close_btn := Button.new()
	close_btn.text = "【 關閉視窗 [H / Esc] 】"
	close_btn.custom_minimum_size = Vector2(220, 38)
	close_btn.add_theme_font_size_override("font_size", 15)
	close_btn.add_theme_stylebox_override("normal", _button_style(true))
	close_btn.add_theme_stylebox_override("hover", _button_style(true))
	close_btn.pressed.connect(func() -> void: _set_tutorial_visible(false))
	vbox.add_child(close_btn)

func _make_section_box(parent_vbox: VBoxContainer, title_text: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.05, 0.055, 0.065, 0.92), Color(0.46, 0.38, 0.24, 0.88), 1))
	parent_vbox.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var lbl := Label.new()
	lbl.text = title_text
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(0.98, 0.78, 0.34))
	box.add_child(lbl)
	return box

func _add_controls_hint() -> void:
	controls_hint = Label.new()
	controls_hint.text = "[WASD] 移動 ｜ [左/右鍵] 連斬與射擊 ｜ [Shift] 閃避 ｜ [Tab] 裝備 ｜ [C] 工坊 ｜ [J] 委託 ｜ [K] 圖鑑 ｜ [M] 地圖 ｜ [H] 說明"
	controls_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	controls_hint.add_theme_font_size_override("font_size", 13)
	controls_hint.add_theme_color_override("font_color", Color(0.98, 0.92, 0.72))
	controls_hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.92))
	controls_hint.add_theme_constant_override("shadow_offset_x", 1)
	controls_hint.add_theme_constant_override("shadow_offset_y", 1)
	root.add_child(controls_hint)

func _add_dialogue_box() -> void:
	dialogue_panel = PanelContainer.new()
	dialogue_panel.name = "DialoguePanel"
	dialogue_panel.add_to_group("dialogue_panel")
	dialogue_panel.add_to_group("gameplay_input_blocker")
	dialogue_panel.set_meta("gameplay_input_blocked", false)
	dialogue_panel.custom_minimum_size = Vector2(920, 248)
	dialogue_panel.z_index = 90
	dialogue_panel.visible = false
	dialogue_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var dlg_style := _panel_style(Color(0.042, 0.048, 0.058, 0.96), Color(0.96, 0.72, 0.28, 0.98), 2)
	dlg_style.border_width_top = 4
	dlg_style.corner_radius_top_left = 8
	dlg_style.corner_radius_top_right = 8
	dlg_style.corner_radius_bottom_left = 8
	dlg_style.corner_radius_bottom_right = 8
	dialogue_panel.add_theme_stylebox_override("panel", dlg_style)
	root.add_child(dialogue_panel)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	dialogue_panel.add_child(row)
	var portrait_frame := PanelContainer.new()
	portrait_frame.custom_minimum_size = Vector2(136, 206)
	var pf_style := _panel_style(Color(0.02, 0.025, 0.032, 0.88), Color(0.42, 0.55, 0.62, 0.75), 1)
	pf_style.corner_radius_top_left = 6
	pf_style.corner_radius_top_right = 6
	pf_style.corner_radius_bottom_left = 6
	pf_style.corner_radius_bottom_right = 6
	portrait_frame.add_theme_stylebox_override("panel", pf_style)
	row.add_child(portrait_frame)
	dialogue_portrait = TextureRect.new()
	dialogue_portrait.custom_minimum_size = Vector2(124, 196)
	dialogue_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	dialogue_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dialogue_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_frame.add_child(dialogue_portrait)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	row.add_child(stack)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 10)
	stack.add_child(name_row)
	dialogue_speaker = Label.new()
	dialogue_speaker.add_theme_font_size_override("font_size", 21)
	dialogue_speaker.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	dialogue_speaker.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	dialogue_speaker.add_theme_constant_override("shadow_offset_x", 1)
	dialogue_speaker.add_theme_constant_override("shadow_offset_y", 1)
	name_row.add_child(dialogue_speaker)
	dialogue_role = Label.new()
	dialogue_role.add_theme_font_size_override("font_size", 14)
	dialogue_role.add_theme_color_override("font_color", Color(0.46, 0.86, 0.94))
	name_row.add_child(dialogue_role)
	var sep := HSeparator.new()
	stack.add_child(sep)
	dialogue_body = Label.new()
	dialogue_body.add_theme_font_size_override("font_size", 16)
	dialogue_body.custom_minimum_size = Vector2(720, 110)
	dialogue_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_body.add_theme_color_override("font_color", Color(0.94, 0.95, 0.92))
	stack.add_child(dialogue_body)
	var hint: Label = Label.new()
	hint.text = "◈ [E] 再次對話 ｜ [Esc] 關閉視窗 ｜ 離開 NPC 自動結算"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.68, 0.74, 0.72))
	stack.add_child(hint)
	dialogue_timer = Timer.new()
	dialogue_timer.one_shot = true
	dialogue_timer.timeout.connect(_hide_dialogue)
	add_child(dialogue_timer)

func _add_pause_menu() -> void:
	pause_panel = PanelContainer.new()
	pause_panel.name = "PausePanel"
	pause_panel.add_to_group("gameplay_input_blocker")
	pause_panel.set_meta("gameplay_input_blocked", false)
	pause_panel.z_index = 100
	pause_panel.visible = false
	pause_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.015, 0.018, 0.018, 0.94), Color(0.82, 0.58, 0.24, 0.98), 2))
	root.add_child(pause_panel)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	pause_panel.add_child(stack)
	var title: Label = Label.new()
	title.text = "暫停"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	stack.add_child(title)
	_add_pause_button(stack, "繼續遊戲", func() -> void: _set_pause_visible(false))
	_add_pause_button(stack, "儲存進度", func() -> void: SaveManager.save_game(true))
	_add_pause_button(stack, "讀取存檔", _load_from_pause)
	_add_pause_button(stack, "返回標題", _return_to_title)
	_add_pause_button(stack, "退出遊戲", func() -> void: get_tree().quit(0))

func _add_notice_label() -> void:
	notice_label = Label.new()
	notice_label.name = "NoticeLabel"
	notice_label.z_index = 120
	notice_label.visible = false
	notice_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_label.add_theme_font_size_override("font_size", 18)
	notice_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.68))
	notice_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	notice_label.add_theme_constant_override("shadow_offset_x", 2)
	notice_label.add_theme_constant_override("shadow_offset_y", 2)
	notice_label.custom_minimum_size = Vector2(760, 34)
	root.add_child(notice_label)
	notice_timer = Timer.new()
	notice_timer.one_shot = true
	notice_timer.timeout.connect(_on_notice_timeout)
	add_child(notice_timer)

func _add_pause_button(container: VBoxContainer, text: String, callback: Callable) -> void:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(290, 42)
	button.pressed.connect(callback)
	container.add_child(button)

func _load_from_pause() -> void:
	if SaveManager.load_game(true, true):
		_set_pause_visible(false)

func _return_to_title() -> void:
	_set_pause_visible(false)
	SceneRouter.change_to("main", "default")

func _toggle_map() -> void:
	if not map_open:
		map_open = true
		map_fullscreen = false
	elif not map_fullscreen:
		map_fullscreen = true
	else:
		map_open = false
		map_fullscreen = false
	_refresh_overlay_visibility()

func set_fullscreen_map(enabled: bool) -> void:
	map_open = enabled
	map_fullscreen = enabled
	_refresh_overlay_visibility()

func _set_inventory_visible(is_visible: bool) -> void:
	if is_visible and pause_panel.visible:
		_set_pause_visible(false)
	inventory_panel.visible = is_visible
	if is_visible:
		map_fullscreen = false
		tutorial_panel.visible = false
		if workshop_panel != null:
			workshop_panel.visible = false
		if contract_panel != null:
			contract_panel.visible = false
		if terminal_panel != null:
			terminal_panel.visible = false
		if codex_panel != null:
			codex_panel.visible = false
		pause_panel.visible = false
		_hide_dialogue()
		_refresh_inventory()
	_refresh_overlay_visibility()

func open_workshop(tab := "craft") -> void:
	workshop_active_tab = tab
	_set_workshop_visible(true)

func _set_workshop_visible(is_visible: bool) -> void:
	if workshop_panel == null:
		return
	if is_visible and pause_panel.visible:
		_set_pause_visible(false)
	workshop_panel.visible = is_visible
	if is_visible:
		map_fullscreen = false
		inventory_panel.visible = false
		if contract_panel != null:
			contract_panel.visible = false
		if terminal_panel != null:
			terminal_panel.visible = false
		if codex_panel != null:
			codex_panel.visible = false
		tutorial_panel.visible = false
		pause_panel.visible = false
		_hide_dialogue()
		_refresh_workshop()
	_refresh_overlay_visibility()

func _set_contract_visible(is_visible: bool) -> void:
	if contract_panel == null:
		return
	if is_visible and pause_panel.visible:
		_set_pause_visible(false)
	contract_panel.visible = is_visible
	if is_visible:
		map_fullscreen = false
		inventory_panel.visible = false
		if workshop_panel != null:
			workshop_panel.visible = false
		if terminal_panel != null:
			terminal_panel.visible = false
		if codex_panel != null:
			codex_panel.visible = false
		tutorial_panel.visible = false
		pause_panel.visible = false
		_hide_dialogue()
		_refresh_contracts()
	_refresh_overlay_visibility()

func _set_terminal_visible(is_visible: bool) -> void:
	if terminal_panel == null:
		return
	if is_visible and pause_panel.visible:
		_set_pause_visible(false)
	terminal_panel.visible = is_visible
	if is_visible:
		map_fullscreen = false
		inventory_panel.visible = false
		if workshop_panel != null:
			workshop_panel.visible = false
		if contract_panel != null:
			contract_panel.visible = false
		if codex_panel != null:
			codex_panel.visible = false
		tutorial_panel.visible = false
		pause_panel.visible = false
		_hide_dialogue()
		_refresh_terminal()
	_refresh_overlay_visibility()

func _set_codex_visible(is_visible: bool) -> void:
	if codex_panel == null:
		return
	if is_visible and pause_panel.visible:
		_set_pause_visible(false)
	codex_panel.visible = is_visible
	if is_visible:
		map_fullscreen = false
		inventory_panel.visible = false
		if workshop_panel != null:
			workshop_panel.visible = false
		if contract_panel != null:
			contract_panel.visible = false
		if terminal_panel != null:
			terminal_panel.visible = false
		tutorial_panel.visible = false
		pause_panel.visible = false
		_hide_dialogue()
		_refresh_codex()
	_refresh_overlay_visibility()

func _set_tutorial_visible(is_visible: bool) -> void:
	if is_visible and pause_panel.visible:
		_set_pause_visible(false)
	tutorial_panel.visible = is_visible
	if is_visible:
		map_fullscreen = false
		inventory_panel.visible = false
		if workshop_panel != null:
			workshop_panel.visible = false
		if contract_panel != null:
			contract_panel.visible = false
		if terminal_panel != null:
			terminal_panel.visible = false
		if codex_panel != null:
			codex_panel.visible = false
		pause_panel.visible = false
		_hide_dialogue()
	_refresh_overlay_visibility()

func _set_pause_visible(is_visible: bool) -> void:
	pause_panel.visible = is_visible
	if is_visible:
		map_fullscreen = false
		inventory_panel.visible = false
		if workshop_panel != null:
			workshop_panel.visible = false
		if contract_panel != null:
			contract_panel.visible = false
		if terminal_panel != null:
			terminal_panel.visible = false
		if codex_panel != null:
			codex_panel.visible = false
		tutorial_panel.visible = false
		_hide_dialogue()
	get_tree().paused = is_visible
	_refresh_overlay_visibility()

func _refresh_overlay_visibility() -> void:
	var extra_modal := (workshop_panel != null and workshop_panel.visible) or (contract_panel != null and contract_panel.visible) or (terminal_panel != null and terminal_panel.visible) or (codex_panel != null and codex_panel.visible)
	var modal_open: bool = inventory_panel.visible or extra_modal or tutorial_panel.visible or map_fullscreen or dialogue_panel.visible or pause_panel.visible
	inventory_panel.set_meta("gameplay_input_blocked", inventory_panel.visible)
	if workshop_panel != null:
		workshop_panel.set_meta("gameplay_input_blocked", workshop_panel.visible)
	if contract_panel != null:
		contract_panel.set_meta("gameplay_input_blocked", contract_panel.visible)
	if terminal_panel != null:
		terminal_panel.set_meta("gameplay_input_blocked", terminal_panel.visible)
	if codex_panel != null:
		codex_panel.set_meta("gameplay_input_blocked", codex_panel.visible)
	tutorial_panel.set_meta("gameplay_input_blocked", tutorial_panel.visible)
	dialogue_panel.set_meta("gameplay_input_blocked", dialogue_panel.visible)
	pause_panel.set_meta("gameplay_input_blocked", pause_panel.visible)
	minimap_panel.set_meta("gameplay_input_blocked", map_fullscreen)
	if nav_bar_panel != null:
		nav_bar_panel.visible = not modal_open
	quick_bar_panel.visible = not modal_open
	controls_hint.visible = not modal_open
	minimap_panel.visible = map_open and not inventory_panel.visible and not extra_modal and not tutorial_panel.visible and not dialogue_panel.visible and not pause_panel.visible
	if map_fullscreen:
		var mm_style := _panel_style(Color(0.025, 0.035, 0.045, 0.98), Color(0.28, 0.65, 0.75, 0.85), 2)
		minimap_panel.add_theme_stylebox_override("panel", mm_style)
		if minimap_title != null:
			minimap_title.text = "◈ 全域戰術地圖 [M / Esc 關閉] ｜ Seed %d" % GameState.seed
	else:
		var mm_style := _panel_style(Color(0.038, 0.050, 0.065, 0.70), Color(0.24, 0.45, 0.52, 0.55), 1)
		mm_style.corner_radius_top_left = 8
		mm_style.corner_radius_top_right = 8
		mm_style.corner_radius_bottom_left = 8
		mm_style.corner_radius_bottom_right = 8
		minimap_panel.add_theme_stylebox_override("panel", mm_style)
		if minimap_title != null:
			minimap_title.text = "◈ 雷達 [M]"
	if map_view != null:
		map_view.set_full_screen(map_fullscreen)
	_update_notice_visibility()
	_layout()

func _refresh() -> void:
	var route: Dictionary = DataRegistry.get_wasteland_route(GameState.current_route_id)
	var route_name: String = String(route.get("name", "村莊"))
	var max_hp: int = GameState.get_max_hp()
	var max_ep: int = GameState.get_max_ep()
	hp_bar.max_value = max_hp
	hp_bar.value = GameState.hp
	ep_bar.max_value = max_ep
	ep_bar.value = GameState.ep
	if hp_value_label != null:
		hp_value_label.text = "%d / %d" % [GameState.hp, max_hp]
	if ep_value_label != null:
		ep_value_label.text = "%d / %d" % [GameState.ep, max_ep]
	var active_wpn := GameState.active_attack_item_id()
	stats_label.text = "⚡ Lv.%d (XP %d/%d) ｜ 彈 %d · 鐵 %d · 核 %d" % [GameState.level, GameState.xp, GameState.xp_to_next_level(), GameState.ammo, GameState.scrap, GameState.cores]
	if quest_header_label != null:
		quest_header_label.text = "◈ %s ▸ %s" % [_scene_name(GameState.current_scene_id), route_name]
	if quest_label != null:
		quest_label.text = "委託：%s" % [GameState.active_quest_summary()]


func _scene_name(scene_id: String) -> String:
	match scene_id:
		"village":
			return "村莊"
		"guild":
			return "冒險公會"
		"wasteland":
			return "廢土"
		"main":
			return "主選單"
		_:
			return "未知區域"

func _refresh_hotbar() -> void:
	for child: Node in quick_bar.get_children():
		child.queue_free()
	for i: int in range(GameState.quick_slots.size()):
		var item_id: String = String(GameState.quick_slots[i])
		var is_active: bool = (i == GameState.active_quick_slot)
		var button: Button = Button.new()
		button.add_to_group("hotbar_slot")
		button.set_meta("quick_slot_index", i)
		button.custom_minimum_size = Vector2(130, 52)
		var equip_data := DataRegistry.get_equipment(item_id)
		var slot_type := String(equip_data.get("slot", ""))
		var lvl_tag := (" Lv.%d" % GameState.get_weapon_level(item_id)) if slot_type in ["weapon", "ranged"] else ""
		button.text = "%s[%d]%s" % ["▸" if is_active else "", i + 1, lvl_tag]
		button.add_theme_font_size_override("font_size", 13)
		button.add_theme_color_override("font_color", Color(1.0, 0.90, 0.48) if is_active else Color(0.86, 0.88, 0.84))
		if not item_id.is_empty():
			button.icon = _item_icon(item_id)
			button.tooltip_text = GameState.item_display_name(item_id)
		button.expand_icon = true
		button.add_theme_stylebox_override("normal", _button_style(is_active))
		button.add_theme_stylebox_override("hover", _button_style(true))
		button.pressed.connect(func() -> void: GameState.use_quick_slot(i))
		quick_bar.add_child(button)

func _refresh_inventory() -> void:
	if inventory_list == null or not inventory_panel.visible:
		return
	for child: Node in inventory_list.get_children():
		child.queue_free()
	inventory_list.add_child(_build_modal_switcher("inventory"))
	var title: Label = Label.new()
	title.text = "人物裝備與戰術改裝：R-17 回收機器人"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.98, 0.88, 0.48))
	inventory_list.add_child(title)
	var current_item: String = GameState.active_attack_item_id()
	var current_equipment: Dictionary = DataRegistry.get_equipment(current_item)
	var current_name: String = String(current_equipment.get("name", GameState.item_display_name(current_item)))
	var mode_label: String = _attack_mode_label(String(current_equipment.get("attack_mode", "melee")))
	var active_label: Label = Label.new()
	active_label.text = "目前左鍵：%s（%s）｜升級點：%d｜彈藥 x%d｜廢鐵 x%d｜核心 x%d｜晶核 x%d" % [current_name, mode_label, GameState.upgrade_points, GameState.ammo, GameState.scrap, GameState.cores, GameState.crystals]
	active_label.add_theme_font_size_override("font_size", 16)
	inventory_list.add_child(active_label)

	var top: BoxContainer
	if get_viewport().get_visible_rect().size.x < 1180.0:
		top = VBoxContainer.new()
	else:
		top = HBoxContainer.new()
	top.add_theme_constant_override("separation", 18)
	inventory_list.add_child(top)
	top.add_child(_build_profile_card())

	var equip_list: VBoxContainer = VBoxContainer.new()
	equip_list.custom_minimum_size = Vector2(660, 400)
	equip_list.add_theme_constant_override("separation", 8)
	top.add_child(equip_list)
	_add_equipment_card(equip_list, "weapon", "近戰武器")
	_add_equipment_card(equip_list, "ranged", "遠程武器")
	_add_equipment_card(equip_list, "armor", "護甲")
	_add_equipment_card(equip_list, "tool", "工具")

	var upgrade_row: HBoxContainer = HBoxContainer.new()
	upgrade_row.add_theme_constant_override("separation", 8)
	inventory_list.add_child(upgrade_row)
	_add_upgrade_button(upgrade_row, "HP", "hp")
	_add_upgrade_button(upgrade_row, "EP", "ep")
	_add_upgrade_button(upgrade_row, "攻擊", "attack")
	_add_upgrade_button(upgrade_row, "防禦", "defense")
	_add_weapon_forge_button(upgrade_row, "weapon", "鍛造近戰")
	_add_weapon_forge_button(upgrade_row, "ranged", "鍛造遠程")

	var btn_perk := Button.new()
	btn_perk.text = "⚡ 戰術晶片 [C]"
	btn_perk.custom_minimum_size = Vector2(136, 36)
	btn_perk.add_theme_stylebox_override("normal", _button_style(true))
	btn_perk.add_theme_stylebox_override("hover", _button_style(true))
	btn_perk.pressed.connect(func() -> void:
		open_workshop("perks")
	)
	upgrade_row.add_child(btn_perk)

	var btn_recycle := Button.new()
	btn_recycle.text = "♻ 拆解回收 [C]"
	btn_recycle.custom_minimum_size = Vector2(136, 36)
	btn_recycle.add_theme_stylebox_override("normal", _button_style(false))
	btn_recycle.add_theme_stylebox_override("hover", _button_style(true))
	btn_recycle.pressed.connect(func() -> void:
		open_workshop("recycle")
	)
	upgrade_row.add_child(btn_recycle)

	var separator: HSeparator = HSeparator.new()
	inventory_list.add_child(separator)
	var bag_label: Label = Label.new()
	bag_label.text = "背包物品（點擊裝備可穿戴）"
	bag_label.add_theme_font_size_override("font_size", 19)
	inventory_list.add_child(bag_label)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	inventory_list.add_child(grid)
	for item_id in GameState.inventory.keys():
		_add_bag_button(grid, String(item_id), int(GameState.inventory[item_id]))

func _refresh_workshop() -> void:
	if workshop_list == null or workshop_panel == null or not workshop_panel.visible:
		return
	for child: Node in workshop_list.get_children():
		child.queue_free()
	workshop_list.add_child(_build_modal_switcher("workshop"))
	_build_workshop_content_inner()


func _on_workshop_forge() -> void:
	INVENTORY_SYSTEM.forge_ammo_pack()
	_refresh_workshop()


func _on_workshop_shop() -> void:
	INVENTORY_SYSTEM.shop_buy_ammo()
	_refresh_workshop()


func _on_workshop_craft() -> void:
	if INVENTORY_SYSTEM.craft_basic_upgrade():
		for item_id in ["breaker_hammer", "melee_axe", "melee_sword", "crystal_guard", "light_reinforced_armor", "patched_armor", "spark_cutter"]:
			if GameState.can_equip(item_id):
				GameState.equip_item(item_id)
				break
	_refresh_workshop()


func _on_workshop_mod() -> void:
	if INVENTORY_SYSTEM.craft_mod_upgrade():
		for item_id in ["ranged_explosive", "ranged_crossbow", "ranged_revolver", "ranged_shotgun", "ranged_smg", "ranged_pistol", "coil_launcher"]:
			if GameState.can_equip(item_id):
				GameState.equip_item(item_id)
				break
	_refresh_workshop()


func _on_workshop_recycle() -> void:
	INVENTORY_SYSTEM.recycle_core()
	_refresh_workshop()


func _on_workshop_save() -> void:
	GameState.heal_full()
	SaveManager.save_game(true)
	_refresh_workshop()


func _build_workshop_content_inner() -> void:
	var title := Label.new()
	title.text = "🔨 廢土工坊終端 [C] — 拆解・合成・改裝・戰術晶片"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.98, 0.84, 0.42))
	workshop_list.add_child(title)

	var res_lbl := Label.new()
	res_lbl.text = "當前資源：廢鐵 %d ｜ 異變核心 %d ｜ 污染晶核 %d ｜ 彈藥 %d ｜ 升級點 %d" % [GameState.scrap, GameState.cores, GameState.crystals, GameState.ammo, GameState.upgrade_points]
	res_lbl.add_theme_font_size_override("font_size", 15)
	res_lbl.add_theme_color_override("font_color", Color(0.76, 0.94, 0.92))
	workshop_list.add_child(res_lbl)

	# Sub-tabs bar
	var subtab_row := HBoxContainer.new()
	subtab_row.add_theme_constant_override("separation", 8)
	workshop_list.add_child(subtab_row)

	var subtabs := [
		["recycle", "♻ 分解回收"],
		["craft", "⚒ 裝備合成"],
		["mod", "🔧 武器強化"],
		["forge", "🔥 彈藥補給"],
		["perks", "⚡ 戰術晶片"]
	]
	for tab_info in subtabs:
		var tab_id: String = tab_info[0]
		var tab_name: String = tab_info[1]
		var is_active := (tab_id == workshop_active_tab)
		var btn := Button.new()
		btn.text = tab_name
		btn.custom_minimum_size = Vector2(170, 36)
		btn.add_theme_font_size_override("font_size", 15)
		btn.add_theme_color_override("font_color", Color(1.0, 0.92, 0.52) if is_active else Color(0.82, 0.85, 0.88))
		btn.add_theme_stylebox_override("normal", _button_style(is_active))
		btn.add_theme_stylebox_override("hover", _button_style(true))
		btn.pressed.connect(func() -> void:
			workshop_active_tab = tab_id
			_refresh_workshop()
		)
		subtab_row.add_child(btn)

	match workshop_active_tab:
		"recycle":
			_build_workshop_tab_recycle()
		"craft":
			_build_workshop_tab_craft()
		"mod":
			_build_workshop_tab_mod()
		"forge":
			_build_workshop_tab_forge()
		"perks":
			_build_workshop_tab_perks()
		_:
			_build_workshop_tab_craft()

func _build_workshop_tab_recycle() -> void:
	var desc := Label.new()
	desc.text = "♻ 工業拆解機：分解多餘裝備、怪物遺骸與核心，回收高純度廢鐵與稀有結晶。"
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Color(0.72, 0.88, 0.78))
	workshop_list.add_child(desc)

	var batch_row := HBoxContainer.new()
	batch_row.add_theme_constant_override("separation", 10)
	workshop_list.add_child(batch_row)

	var btn_batch := Button.new()
	btn_batch.text = "📦 一鍵拆解多餘重複裝備"
	btn_batch.custom_minimum_size = Vector2(230, 36)
	btn_batch.add_theme_stylebox_override("normal", _button_style(true))
	btn_batch.add_theme_stylebox_override("hover", _button_style(true))
	btn_batch.pressed.connect(func() -> void:
		GameState.batch_recycle_duplicates()
		_refresh_workshop()
	)
	batch_row.add_child(btn_batch)

	var hint := Label.new()
	hint.text = "（將保留身上已裝備的武器防具，自動分解背包中所有多餘重複裝備）"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.65, 0.72, 0.68))
	batch_row.add_child(hint)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	workshop_list.add_child(grid)

	var has_any := false
	for item_id in GameState.inventory.keys():
		var count: int = int(GameState.inventory[item_id])
		if count <= 0:
			continue
		var yields: Dictionary = GameState.get_disassemble_yield(String(item_id))
		if yields.is_empty():
			continue
		has_any = true

		var is_equipped := false
		for slot_item in GameState.equipment.values():
			if String(slot_item) == String(item_id):
				is_equipped = true
				break

		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(510, 88)
		card.add_theme_stylebox_override("panel", _panel_style(Color(0.055, 0.065, 0.078, 0.94), Color(0.38, 0.62, 0.48, 0.90), 1))

		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 12)
		card.add_child(hb)

		var icon := _fit_texture_rect(_item_icon(String(item_id)), Vector2(64, 64))
		hb.add_child(icon)

		var vb := VBoxContainer.new()
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb.add_theme_constant_override("separation", 3)
		hb.add_child(vb)

		var title_row := HBoxContainer.new()
		title_row.add_theme_constant_override("separation", 8)
		vb.add_child(title_row)

		var name_lbl := Label.new()
		name_lbl.text = "%s x%d" % [GameState.item_display_name(String(item_id)), count]
		name_lbl.add_theme_font_size_override("font_size", 16)
		name_lbl.add_theme_color_override("font_color", Color(0.96, 0.88, 0.52))
		title_row.add_child(name_lbl)

		if is_equipped:
			var eq_tag := Label.new()
			eq_tag.text = "【已裝備】"
			eq_tag.add_theme_font_size_override("font_size", 12)
			eq_tag.add_theme_color_override("font_color", Color(0.42, 0.88, 0.98))
			title_row.add_child(eq_tag)

		var yield_parts: Array[String] = []
		for yk in yields.keys():
			yield_parts.append("%s +%d" % [GameState.item_display_name(String(yk)), int(yields[yk])])
		var yield_lbl := Label.new()
		yield_lbl.text = "拆解回收產出：%s" % " ｜ ".join(yield_parts)
		yield_lbl.add_theme_font_size_override("font_size", 13)
		yield_lbl.add_theme_color_override("font_color", Color(0.72, 0.92, 0.82))
		vb.add_child(yield_lbl)

		var btn_dis := Button.new()
		var can_dis := not (is_equipped and count <= 1)
		btn_dis.text = "拆解 1 件" if can_dis else "已裝備保護"
		btn_dis.disabled = not can_dis
		btn_dis.custom_minimum_size = Vector2(110, 36)
		btn_dis.add_theme_stylebox_override("normal", _button_style(can_dis))
		btn_dis.add_theme_stylebox_override("hover", _button_style(true))
		var current_item_id: String = String(item_id)
		btn_dis.pressed.connect(func() -> void:
			GameState.disassemble_item(current_item_id, 1)
			_refresh_workshop()
		)
		hb.add_child(btn_dis)

		grid.add_child(card)

	if not has_any:
		var empty_lbl := Label.new()
		empty_lbl.text = "背包中目前沒有可拆解的裝備或素材。"
		empty_lbl.add_theme_font_size_override("font_size", 15)
		empty_lbl.add_theme_color_override("font_color", Color(0.65, 0.70, 0.75))
		workshop_list.add_child(empty_lbl)

func _build_workshop_tab_craft() -> void:
	var desc := Label.new()
	desc.text = "⚒ 機械合成台：研製高階近戰利刃、重裝防具與先進十字弩/槍械藍圖。"
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Color(0.88, 0.82, 0.62))
	workshop_list.add_child(desc)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	workshop_list.add_child(grid)

	for r in DataRegistry.recipes:
		var st := String(r.get("station", ""))
		var r_id := String(r.get("id", ""))
		if st == "shop" or r_id == "ammo_pack" or r_id == "recycle_core":
			continue

		var result_dict: Dictionary = r.get("result", {})
		if result_dict.is_empty():
			continue
		var result_item_id: String = String(result_dict.keys()[0])
		var eq := DataRegistry.get_equipment(result_item_id)
		var item_name: String = String(r.get("name", GameState.item_display_name(result_item_id)))

		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(510, 110)
		card.add_theme_stylebox_override("panel", _panel_style(Color(0.055, 0.065, 0.078, 0.94), Color(0.62, 0.52, 0.32, 0.90), 1))

		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 12)
		card.add_child(hb)

		var icon := _fit_texture_rect(_item_icon(result_item_id), Vector2(68, 68))
		hb.add_child(icon)

		var vb := VBoxContainer.new()
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb.add_theme_constant_override("separation", 3)
		hb.add_child(vb)

		var header_row := HBoxContainer.new()
		header_row.add_theme_constant_override("separation", 8)
		vb.add_child(header_row)

		var n_lbl := Label.new()
		n_lbl.text = item_name
		n_lbl.add_theme_font_size_override("font_size", 16)
		n_lbl.add_theme_color_override("font_color", Color(0.98, 0.88, 0.48))
		header_row.add_child(n_lbl)

		var owned_count := int(GameState.inventory.get(result_item_id, 0))
		if owned_count > 0:
			var tag := Label.new()
			tag.text = "【已擁有 x%d】" % owned_count
			tag.add_theme_font_size_override("font_size", 12)
			tag.add_theme_color_override("font_color", Color(0.45, 0.95, 0.85))
			header_row.add_child(tag)

		var stats_desc := ""
		if not eq.is_empty():
			var stats: Dictionary = eq.get("stats", {})
			var atk := int(stats.get("attack", 0))
			var def := int(stats.get("defense", 0))
			var parts: Array[String] = []
			if atk > 0:
				parts.append("攻擊 +%d" % atk)
			if def > 0:
				parts.append("防禦 +%d" % def)
			var arch := String(eq.get("archetype", ""))
			if not arch.is_empty():
				parts.append("類型: %s" % arch)
			stats_desc = " ｜ ".join(parts)
		var stat_lbl := Label.new()
		stat_lbl.text = stats_desc if not stats_desc.is_empty() else "戰術規格裝備"
		stat_lbl.add_theme_font_size_override("font_size", 12)
		stat_lbl.add_theme_color_override("font_color", Color(0.78, 0.82, 0.86))
		vb.add_child(stat_lbl)

		var cost: Dictionary = r.get("cost", {})
		var cost_parts: Array[String] = []
		var can_craft := true
		for c_item in cost.keys():
			var req := int(cost[c_item])
			var have := int(GameState.inventory.get(String(c_item), 0))
			if have < req:
				can_craft = false
			cost_parts.append("%s: %d/%d" % [GameState.item_display_name(String(c_item)), have, req])

		var cost_lbl := Label.new()
		cost_lbl.text = "材料需求：%s" % " ｜ ".join(cost_parts)
		cost_lbl.add_theme_font_size_override("font_size", 12)
		cost_lbl.add_theme_color_override("font_color", Color(0.55, 0.95, 0.65) if can_craft else Color(0.95, 0.55, 0.55))
		vb.add_child(cost_lbl)

		var btn_craft := Button.new()
		btn_craft.text = "立即合成" if can_craft else "材料不足"
		btn_craft.disabled = not can_craft
		btn_craft.custom_minimum_size = Vector2(104, 38)
		btn_craft.add_theme_stylebox_override("normal", _button_style(can_craft))
		btn_craft.add_theme_stylebox_override("hover", _button_style(true))
		var current_recipe_id: String = r_id
		btn_craft.pressed.connect(func() -> void:
			if INVENTORY_SYSTEM.craft_recipe(current_recipe_id):
				if GameState.can_equip(result_item_id):
					GameState.equip_item(result_item_id)
			_refresh_workshop()
		)
		hb.add_child(btn_craft)

		grid.add_child(card)

func _build_workshop_tab_mod() -> void:
	var desc := Label.new()
	desc.text = "🔧 精密改裝站：強化武器星級（最高 Lv.5），大幅提升攻擊力並降低揮砍與射擊冷卻時間。"
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Color(0.68, 0.88, 0.98))
	workshop_list.add_child(desc)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	workshop_list.add_child(grid)

	for item_id in GameState.inventory.keys():
		var count := int(GameState.inventory[item_id])
		if count <= 0:
			continue
		var eq := DataRegistry.get_equipment(String(item_id))
		if eq.is_empty():
			continue
		var slot := String(eq.get("slot", ""))
		if slot != "weapon" and slot != "ranged":
			continue

		var lvl := GameState.get_weapon_level(String(item_id))
		var cost := GameState.get_weapon_upgrade_cost(String(item_id))
		var max_lvl := 5
		var is_max := (lvl >= max_lvl)
		var can_afford := (not is_max and GameState.scrap >= cost)

		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(510, 96)
		card.add_theme_stylebox_override("panel", _panel_style(Color(0.055, 0.065, 0.078, 0.94), Color(0.28, 0.54, 0.72, 0.90), 1))

		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 12)
		card.add_child(hb)

		var icon := _fit_texture_rect(_item_icon(String(item_id)), Vector2(64, 64))
		hb.add_child(icon)

		var vb := VBoxContainer.new()
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb.add_theme_constant_override("separation", 3)
		hb.add_child(vb)

		var title_row := HBoxContainer.new()
		title_row.add_theme_constant_override("separation", 8)
		vb.add_child(title_row)

		var n_lbl := Label.new()
		n_lbl.text = GameState.item_display_name(String(item_id))
		n_lbl.add_theme_font_size_override("font_size", 16)
		n_lbl.add_theme_color_override("font_color", Color(0.96, 0.88, 0.48))
		title_row.add_child(n_lbl)

		var star_str := ""
		for s in range(lvl):
			star_str += "★"
		for s in range(max_lvl - lvl):
			star_str += "☆"
		var star_lbl := Label.new()
		star_lbl.text = "%s Lv.%d / %d" % [star_str, lvl, max_lvl]
		star_lbl.add_theme_font_size_override("font_size", 14)
		star_lbl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.32))
		title_row.add_child(star_lbl)

		var stats_lbl := Label.new()
		stats_lbl.text = "鍛造增益：攻擊加成 +%d ｜ 攻擊間隔縮短 %d%%" % [(lvl - 1) * 3, int((1.0 - GameState.get_weapon_cooldown_multiplier(String(item_id))) * 100.0)]
		stats_lbl.add_theme_font_size_override("font_size", 12)
		stats_lbl.add_theme_color_override("font_color", Color(0.72, 0.92, 0.98))
		vb.add_child(stats_lbl)

		var cost_lbl := Label.new()
		if is_max:
			cost_lbl.text = "已達最高鍛造等級"
			cost_lbl.add_theme_color_override("font_color", Color(0.65, 0.85, 0.75))
		else:
			cost_lbl.text = "升級消耗：廢鐵 %d/%d" % [GameState.scrap, cost]
			cost_lbl.add_theme_color_override("font_color", Color(0.55, 0.95, 0.65) if can_afford else Color(0.95, 0.55, 0.55))
		cost_lbl.add_theme_font_size_override("font_size", 12)
		vb.add_child(cost_lbl)

		var btn_up := Button.new()
		btn_up.text = "已滿級" if is_max else ("強化升星" if can_afford else "廢鐵不足")
		btn_up.disabled = not can_afford
		btn_up.custom_minimum_size = Vector2(104, 36)
		btn_up.add_theme_stylebox_override("normal", _button_style(can_afford))
		btn_up.add_theme_stylebox_override("hover", _button_style(true))
		var current_item_id: String = String(item_id)
		btn_up.pressed.connect(func() -> void:
			GameState.upgrade_weapon_level(current_item_id)
			_refresh_workshop()
		)
		hb.add_child(btn_up)

		grid.add_child(card)

func _build_workshop_tab_forge() -> void:
	var desc := Label.new()
	desc.text = "🔥 鍛造爐與黑市補給：批量鍛造穿甲彈藥、拆解異變核心，或進行全機維修保養。"
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Color(0.98, 0.82, 0.52))
	workshop_list.add_child(desc)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 12)
	workshop_list.add_child(grid)

	var actions := [
		["🔥 鍛造穿甲弩箭/彈藥包", "消耗：廢鐵 x8 ➔ 產出：彈藥 x12", "立即鍛造彈藥", Callable(self, "_on_workshop_forge")],
		["🛒 黑市緊急補給彈藥", "消耗：廢鐵 x4 ➔ 產出：彈藥 x8", "黑市採購彈藥", Callable(self, "_on_workshop_shop")],
		["♻ 工業拆解異變核心", "消耗：異變核心 x1 ➔ 產出：高純廢鐵 x14 + 污染晶核 x1", "啟動核心拆解", Callable(self, "_on_workshop_recycle")],
		["🛠 全機整備維修與存檔", "完全恢復 R-17 機體 HP 與能量 EP，並寫入最新進度存檔", "全機修復並存檔", Callable(self, "_on_workshop_save")],
	]
	for act in actions:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(510, 118)
		card.add_theme_stylebox_override("panel", _panel_style(Color(0.06, 0.07, 0.085, 0.94), Color(0.56, 0.44, 0.24, 0.92), 1))
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 6)
		card.add_child(vb)
		var h_lbl := Label.new()
		h_lbl.text = String(act[0])
		h_lbl.add_theme_font_size_override("font_size", 17)
		h_lbl.add_theme_color_override("font_color", Color(0.98, 0.88, 0.48))
		vb.add_child(h_lbl)
		var d_lbl := Label.new()
		d_lbl.text = String(act[1])
		d_lbl.add_theme_font_size_override("font_size", 13)
		d_lbl.add_theme_color_override("font_color", Color(0.84, 0.86, 0.82))
		vb.add_child(d_lbl)
		var btn := Button.new()
		btn.text = String(act[2])
		btn.custom_minimum_size = Vector2(180, 36)
		btn.add_theme_stylebox_override("normal", _button_style(false))
		btn.add_theme_stylebox_override("hover", _button_style(true))
		btn.pressed.connect(act[3])
		vb.add_child(btn)
		grid.add_child(card)

func _build_workshop_tab_perks() -> void:
	var desc := Label.new()
	desc.text = "⚡ 戰術神經晶片改造：消耗維修升級點裝載或強化強大被動特質，打造專屬廢土戰鬥流派！"
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Color(0.52, 0.94, 0.98))
	workshop_list.add_child(desc)

	var pt_lbl := Label.new()
	pt_lbl.text = "★ 當前可用維修升級點：%d 點（擊殺污染體或提升等級可獲得升級點）" % GameState.upgrade_points
	pt_lbl.add_theme_font_size_override("font_size", 16)
	pt_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.42))
	workshop_list.add_child(pt_lbl)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 12)
	workshop_list.add_child(grid)

	for perk_id in GameState.PERKS_CATALOG.keys():
		var p_def: Dictionary = GameState.PERKS_CATALOG[perk_id]
		var cur_lvl: int = GameState.get_perk_level(perk_id)
		var max_lvl: int = int(p_def.get("max_level", 3))
		var is_max: bool = (cur_lvl >= max_lvl)
		var can_upgrade: bool = (not is_max and GameState.upgrade_points > 0)

		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(510, 118)
		card.add_theme_stylebox_override("panel", _panel_style(Color(0.055, 0.065, 0.08, 0.94), Color(0.24, 0.72, 0.88, 0.92) if cur_lvl > 0 else Color(0.35, 0.45, 0.52, 0.85), 1))

		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 6)
		card.add_child(vb)

		var top_row := HBoxContainer.new()
		top_row.add_theme_constant_override("separation", 10)
		vb.add_child(top_row)

		var icon_lbl := Label.new()
		icon_lbl.text = String(p_def.get("icon", "⚡"))
		icon_lbl.add_theme_font_size_override("font_size", 20)
		top_row.add_child(icon_lbl)

		var name_lbl := Label.new()
		name_lbl.text = String(p_def.get("name", perk_id))
		name_lbl.add_theme_font_size_override("font_size", 16)
		name_lbl.add_theme_color_override("font_color", Color(0.98, 0.92, 0.52) if cur_lvl > 0 else Color(0.85, 0.88, 0.90))
		top_row.add_child(name_lbl)

		var lvl_lbl := Label.new()
		lvl_lbl.text = "【Lv.%d / %d】" % [cur_lvl, max_lvl]
		lvl_lbl.add_theme_font_size_override("font_size", 14)
		lvl_lbl.add_theme_color_override("font_color", Color(0.38, 0.95, 0.82) if cur_lvl > 0 else Color(0.60, 0.65, 0.70))
		top_row.add_child(lvl_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = String(p_def.get("desc", ""))
		desc_lbl.add_theme_font_size_override("font_size", 12)
		desc_lbl.add_theme_color_override("font_color", Color(0.82, 0.86, 0.90))
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(desc_lbl)

		var btn_perk := Button.new()
		btn_perk.text = "已達最高星級" if is_max else ("裝載晶片 (+1 點)" if cur_lvl == 0 else "升級晶片 (+1 點)")
		btn_perk.disabled = not can_upgrade
		btn_perk.custom_minimum_size = Vector2(170, 34)
		btn_perk.add_theme_stylebox_override("normal", _button_style(can_upgrade))
		btn_perk.add_theme_stylebox_override("hover", _button_style(true))
		var current_perk_id: String = String(perk_id)
		btn_perk.pressed.connect(func() -> void:
			GameState.unlock_perk(current_perk_id)
			_refresh_workshop()
		)
		vb.add_child(btn_perk)

		grid.add_child(card)

func _refresh_contracts() -> void:
	if contract_list == null or contract_panel == null or not contract_panel.visible:
		return
	for child: Node in contract_list.get_children():
		child.queue_free()
	contract_list.add_child(_build_modal_switcher("contract"))
	var title := Label.new()
	title.text = "📜 冒險公會委託與廢土路線總覽 [J]"
	title.add_theme_font_size_override("font_size", 23)
	title.add_theme_color_override("font_color", Color(0.52, 0.94, 0.98))
	contract_list.add_child(title)

	var cur_q := Label.new()
	cur_q.text = "目前進行中委託：%s" % GameState.active_quest_summary()
	cur_q.add_theme_font_size_override("font_size", 16)
	cur_q.add_theme_color_override("font_color", Color(0.98, 0.90, 0.54))
	contract_list.add_child(cur_q)

	var q_row := HBoxContainer.new()
	q_row.add_theme_constant_override("separation", 10)
	contract_list.add_child(q_row)
	var btn_claim := Button.new()
	btn_claim.text = "✔ 交付並完成目前委託"
	btn_claim.custom_minimum_size = Vector2(210, 38)
	btn_claim.add_theme_stylebox_override("normal", _button_style(true))
	btn_claim.add_theme_stylebox_override("hover", _button_style(true))
	btn_claim.pressed.connect(func() -> void:
		GameState.complete_active_quest()
		_refresh_contracts()
	)
	q_row.add_child(btn_claim)

	var q_grid := GridContainer.new()
	q_grid.columns = 2
	q_grid.add_theme_constant_override("h_separation", 14)
	q_grid.add_theme_constant_override("v_separation", 10)
	contract_list.add_child(q_grid)
	for qid in DataRegistry.quest_ids():
		var qdata := DataRegistry.get_quest(qid)
		var is_done := GameState.completed_quests.has(qid)
		var is_act := (GameState.active_quest_id == qid)
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(510, 112)
		card.add_theme_stylebox_override("panel", _panel_style(Color(0.055, 0.068, 0.086, 0.94), Color(0.36, 0.82, 0.92, 0.95) if is_act else Color(0.32, 0.44, 0.52, 0.85), 2 if is_act else 1))
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 4)
		card.add_child(vb)
		var status_tag := "【已完成】" if is_done else ("【進行中】" if is_act else "【可承接】")
		var qlbl := Label.new()
		qlbl.text = "%s %s" % [status_tag, String(qdata.get("name", qid))]
		qlbl.add_theme_font_size_override("font_size", 16)
		qlbl.add_theme_color_override("font_color", Color(0.62, 0.96, 0.68) if is_done else Color(0.98, 0.88, 0.48))
		vb.add_child(qlbl)
		var desc := Label.new()
		desc.text = String(qdata.get("description", ""))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_font_size_override("font_size", 13)
		vb.add_child(desc)
		var accept_btn := Button.new()
		accept_btn.text = "已結案" if is_done else ("目前執行中" if is_act else "承接此委託")
		accept_btn.disabled = is_done or is_act
		accept_btn.custom_minimum_size = Vector2(150, 32)
		accept_btn.add_theme_stylebox_override("normal", _button_style(is_act))
		accept_btn.pressed.connect(func() -> void:
			GameState.start_quest(qid)
			_refresh_contracts()
		)
		vb.add_child(accept_btn)
		q_grid.add_child(card)

func _refresh_codex() -> void:
	if codex_list == null or codex_panel == null or not codex_panel.visible:
		return
	for child: Node in codex_list.get_children():
		child.queue_free()
	codex_list.add_child(_build_modal_switcher("codex"))
	var title := Label.new()
	title.text = "📖 廢土武裝與變異生物圖鑑 [K]"
	title.add_theme_font_size_override("font_size", 23)
	title.add_theme_color_override("font_color", Color(0.98, 0.86, 0.44))
	codex_list.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	codex_list.add_child(grid)
	for item_id in DataRegistry.equipment.keys():
		var eq := DataRegistry.get_equipment(String(item_id))
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(335, 96)
		card.add_theme_stylebox_override("panel", _panel_style(Color(0.055, 0.065, 0.078, 0.94), Color(0.52, 0.44, 0.28, 0.90), 1))
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		card.add_child(hb)
		var icon := _fit_texture_rect(_item_icon(String(item_id)), Vector2(72, 64))
		hb.add_child(icon)
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 2)
		hb.add_child(vb)
		var n_lbl := Label.new()
		n_lbl.text = String(eq.get("name", item_id))
		n_lbl.add_theme_font_size_override("font_size", 15)
		n_lbl.add_theme_color_override("font_color", Color(0.98, 0.92, 0.68))
		vb.add_child(n_lbl)
		var s_lbl := Label.new()
		s_lbl.text = "%s｜%s" % [_equipment_stats_text(eq), _source_short_text(eq)]
		s_lbl.add_theme_font_size_override("font_size", 12)
		s_lbl.add_theme_color_override("font_color", Color(0.76, 0.90, 0.88))
		vb.add_child(s_lbl)
		var h_lbl := Label.new()
		h_lbl.text = String(eq.get("obtain_hint", ""))
		h_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		h_lbl.custom_minimum_size = Vector2(220, 32)
		h_lbl.add_theme_font_size_override("font_size", 11)
		h_lbl.add_theme_color_override("font_color", Color(0.78, 0.78, 0.72))
		vb.add_child(h_lbl)
		grid.add_child(card)

func _refresh_terminal() -> void:
	if terminal_list == null or terminal_panel == null or not terminal_panel.visible:
		return
	for child: Node in terminal_list.get_children():
		child.queue_free()

	terminal_list.add_child(_build_modal_switcher("terminal"))

	var has_controller: bool = GameState.has_terminal_controller()

	if not has_controller:
		var warn_box := PanelContainer.new()
		warn_box.add_theme_stylebox_override("panel", _panel_style(Color(0.12, 0.04, 0.04, 0.95), Color(0.95, 0.32, 0.28, 0.95), 2))
		var wvb := VBoxContainer.new()
		wvb.add_theme_constant_override("separation", 8)
		warn_box.add_child(wvb)

		var warn_title := Label.new()
		warn_title.text = "⚠ 終端操作權限未解鎖 ｜ 錯誤代碼：ERR_NO_TERMINAL_CONTROLLER"
		warn_title.add_theme_font_size_override("font_size", 20)
		warn_title.add_theme_color_override("font_color", Color(1.0, 0.42, 0.38))
		wvb.add_child(warn_title)

		var warn_diag := Label.new()
		warn_diag.text = "【系統診斷】：檢測到村莊中央「方舟四號古代終端」的物理連接埠，但 R-17 的神經通訊陣列已在第三次大崩塌迫降中嚴重燒毀。終端安全系統已啟動主動防禦協議，拒絕未經驗證的直接物理接觸操作。"
		warn_diag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		warn_diag.add_theme_font_size_override("font_size", 14)
		warn_diag.add_theme_color_override("font_color", Color(0.95, 0.85, 0.82))
		wvb.add_child(warn_diag)

		terminal_list.add_child(warn_box)

		var story_box := PanelContainer.new()
		story_box.add_theme_stylebox_override("panel", _panel_style(Color(0.048, 0.058, 0.072, 0.94), Color(0.88, 0.64, 0.22, 0.85), 1))
		var svb := VBoxContainer.new()
		svb.add_theme_constant_override("separation", 10)
		story_box.add_child(svb)

		var story_h := Label.new()
		story_h.text = "📜 解密歷史：方舟加密通訊矩陣與終端操作器"
		story_h.add_theme_font_size_override("font_size", 17)
		story_h.add_theme_color_override("font_color", Color(0.98, 0.88, 0.45))
		svb.add_child(story_h)

		var story_p1 := Label.new()
		story_p1.text = "在舊文明時代，方舟終端是維繫各大避難所、天軌偵測衛星與自律防衛機甲的最高神經中樞。大崩塌後，荒原上的電磁風暴與變異孢子徹底切斷了遠程通訊。\n\n村莊工坊的大師指出：只要利用高強度合金板加固外殼，結合超導線圈重建加密握手協議，即可在工坊合成【終端操作器】。攜帶操作器後，即可隔空與古代終端機台建立安全同頻，全面解鎖四大生態域遙測日誌、方舟機密解密數據與遠程物資調度！"
		story_p1.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		story_p1.add_theme_font_size_override("font_size", 14)
		story_p1.add_theme_color_override("font_color", Color(0.88, 0.90, 0.92))
		svb.add_child(story_p1)

		terminal_list.add_child(story_box)

		var craft_req_box := PanelContainer.new()
		craft_req_box.add_theme_stylebox_override("panel", _panel_style(Color(0.045, 0.052, 0.065, 0.92), Color(0.35, 0.52, 0.65, 0.85), 1))
		var cvb := VBoxContainer.new()
		cvb.add_theme_constant_override("separation", 8)
		craft_req_box.add_child(cvb)

		var req_title := Label.new()
		req_title.text = "⚒ 終端操作器合成需求（村莊工坊 [C]）："
		req_title.add_theme_font_size_override("font_size", 15)
		req_title.add_theme_color_override("font_color", Color(0.42, 0.88, 0.96))
		cvb.add_child(req_title)

		var req_hb := HBoxContainer.new()
		req_hb.add_theme_constant_override("separation", 16)
		cvb.add_child(req_hb)

		var icon := _fit_texture_rect(_item_icon("terminal_controller"), Vector2(64, 64))
		req_hb.add_child(icon)

		var req_info := VBoxContainer.new()
		req_hb.add_child(req_info)

		var have_plate := int(GameState.inventory.get("alloy_plate", 0))
		var have_coil := int(GameState.inventory.get("broken_coil", 0))
		var have_scrap := GameState.scrap
		var can_craft := have_plate >= 2 and have_coil >= 2 and have_scrap >= 15

		var mat_lbl := Label.new()
		mat_lbl.text = "• 合金板: %d/2 ｜ • 超導線圈: %d/2 ｜ • 廢鐵: %d/15" % [have_plate, have_coil, have_scrap]
		mat_lbl.add_theme_font_size_override("font_size", 14)
		mat_lbl.add_theme_color_override("font_color", Color(0.55, 0.95, 0.65) if can_craft else Color(0.95, 0.65, 0.55))
		req_info.add_child(mat_lbl)

		var goto_btn := Button.new()
		goto_btn.text = "⚒ 前往村莊工坊合成【終端操作器】" if can_craft else "⚒ 材料不足：前往廢鐵公路收集材料"
		goto_btn.custom_minimum_size = Vector2(300, 38)
		goto_btn.add_theme_stylebox_override("normal", _button_style(can_craft))
		goto_btn.add_theme_stylebox_override("hover", _button_style(true))
		goto_btn.pressed.connect(func() -> void:
			open_workshop("craft")
		)
		req_info.add_child(goto_btn)

		terminal_list.add_child(craft_req_box)
	else:
		var status_box := PanelContainer.new()
		status_box.add_theme_stylebox_override("panel", _panel_style(Color(0.040, 0.065, 0.080, 0.95), Color(0.24, 0.88, 0.82, 0.95), 2))
		var svb := VBoxContainer.new()
		svb.add_theme_constant_override("separation", 6)
		status_box.add_child(svb)

		var s_row := HBoxContainer.new()
		s_row.add_theme_constant_override("separation", 12)
		svb.add_child(s_row)

		var s_icon := _fit_texture_rect(_item_icon("terminal_controller"), Vector2(48, 48))
		s_row.add_child(s_icon)

		var s_text := VBoxContainer.new()
		s_row.add_child(s_text)

		var s_title := Label.new()
		s_title.text = "📡 方舟古代終端操作矩陣 ｜ 狀態：已連線 (ONLINE) ｜ 協議：ARK-OS v9.4"
		s_title.add_theme_font_size_override("font_size", 18)
		s_title.add_theme_color_override("font_color", Color(0.38, 0.95, 0.85))
		s_text.add_child(s_title)

		var s_sub := Label.new()
		s_sub.text = "終端操作器認證通過。天軌衛星遙測陣列同頻中，已同步四大廢土生態域實時數據與方舟機密解密檔案。"
		s_sub.add_theme_font_size_override("font_size", 12)
		s_sub.add_theme_color_override("font_color", Color(0.78, 0.86, 0.92))
		s_text.add_child(s_sub)

		terminal_list.add_child(status_box)

		var bio_title := Label.new()
		bio_title.text = "🌍 四大野外地圖生態域實時遙測 (Biome Realtime Telemetry)"
		bio_title.add_theme_font_size_override("font_size", 16)
		bio_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
		terminal_list.add_child(bio_title)

		var bio_grid := GridContainer.new()
		bio_grid.columns = 2
		bio_grid.add_theme_constant_override("h_separation", 12)
		bio_grid.add_theme_constant_override("v_separation", 8)
		terminal_list.add_child(bio_grid)

		var biomes_info := [
			{
				"name": "1. 荒漠廢鐵大道 (Scrap Highway)",
				"risk": "危險度：★☆☆ ｜ 輻射度：14%",
				"desc": "昔日城際運輸樞紐，地表堆滿鏽蝕裝甲車與工程殘骸。\n【資源富集】：廢鐵塊、高密合金板、超導線圈。\n【主要威脅】：廢鐵獵犬、鏽甲蠻獸。"
			},
			{
				"name": "2. 毒沼腐化林 (Toxic Marsh)",
				"risk": "危險度：★★☆ ｜ 毒性孢子：52%",
				"desc": "化學廢料洩漏與地脈交融形成的致命沼澤，積水具酸蝕性。\n【資源富集】：腐蝕毒囊、突變真菌、毒液苔蘚。\n【主要威脅】：劇毒遁行者、孢子射手、酸蝕飛行體。"
			},
			{
				"name": "3. 晶痕裂谷 (Crystal Scar)",
				"risk": "危險度：★★★ ｜ 共振磁場：78%",
				"desc": "高能紫晶脈自地底破土而出，空氣中瀰漫高頻共振電流。\n【資源富集】：高能晶核、變異核心、精密晶片、能量碎晶。\n【主要威脅】：晶化浮游怪、共振機械巨獸。"
			},
			{
				"name": "4. 舊工廠樞紐 (Old Factory)",
				"risk": "危險度：★★★★ ｜ 警戒等級：95%",
				"desc": "戰前最高機密自動化兵工廠，核心超載防衛程序至今仍在運轉。\n【資源富集】：古代反應堆、工業外骨架、動力核心、高純合金。\n【主要威脅】：失控戰鬥機甲殘骸、Boss「廢土巨像」。"
			}
		]

		for b in biomes_info:
			var card := PanelContainer.new()
			card.custom_minimum_size = Vector2(510, 105)
			card.add_theme_stylebox_override("panel", _panel_style(Color(0.048, 0.058, 0.072, 0.94), Color(0.28, 0.65, 0.78, 0.85), 1))
			var cv := VBoxContainer.new()
			cv.add_theme_constant_override("separation", 3)
			card.add_child(cv)

			var n_row := HBoxContainer.new()
			cv.add_child(n_row)
			var nlbl := Label.new()
			nlbl.text = String(b["name"])
			nlbl.add_theme_font_size_override("font_size", 15)
			nlbl.add_theme_color_override("font_color", Color(0.98, 0.90, 0.52))
			n_row.add_child(nlbl)

			var rlbl := Label.new()
			rlbl.text = "   " + String(b["risk"])
			rlbl.add_theme_font_size_override("font_size", 12)
			rlbl.add_theme_color_override("font_color", Color(0.45, 0.92, 0.85))
			n_row.add_child(rlbl)

			var dlbl := Label.new()
			dlbl.text = String(b["desc"])
			dlbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			dlbl.add_theme_font_size_override("font_size", 12)
			dlbl.add_theme_color_override("font_color", Color(0.85, 0.88, 0.90))
			cv.add_child(dlbl)

			bio_grid.add_child(card)

		var log_title := Label.new()
		log_title.text = "📁 方舟機密解密檔案 (Ark Declassified Archives)"
		log_title.add_theme_font_size_override("font_size", 16)
		log_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
		terminal_list.add_child(log_title)

		var logs_box := PanelContainer.new()
		logs_box.add_theme_stylebox_override("panel", _panel_style(Color(0.042, 0.050, 0.062, 0.92), Color(0.32, 0.48, 0.58, 0.85), 1))
		var lvb := VBoxContainer.new()
		lvb.add_theme_constant_override("separation", 8)
		logs_box.add_child(lvb)

		var logs := [
			"【檔案 01 ｜ 大崩塌日誌】：2184 年天軌主站墜毀，地脈晶核洩漏引發全域基因變異。17 艘方舟殘骸散落荒原，唯有回收古代核心方能重建淨化力場。",
			"【檔案 02 ｜ R-17 機兵協議】：作為 R 系列最後的生化機械十字軍獵兵，R-17 具備雙段光刃近戰格鬥與遠程射擊模組，是廢土倖存者重建秩序的唯一希望。",
			"【檔案 03 ｜ 工廠巨像之謎】：舊工廠的廢土巨像是戰前失控的泰坦重工原型機。其胸腔的「超聚變動力核心」是徹底驅動方舟終端深層網絡的關鍵要素。"
		]
		for lg in logs:
			var l_lbl := Label.new()
			l_lbl.text = lg
			l_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l_lbl.add_theme_font_size_override("font_size", 13)
			l_lbl.add_theme_color_override("font_color", Color(0.82, 0.88, 0.92))
			lvb.add_child(l_lbl)

		terminal_list.add_child(logs_box)

		var act_row := HBoxContainer.new()
		act_row.add_theme_constant_override("separation", 16)
		terminal_list.add_child(act_row)

		var scan_btn := Button.new()
		scan_btn.text = "📡 釋放終端生態掃描脈衝"
		scan_btn.custom_minimum_size = Vector2(230, 40)
		scan_btn.add_theme_stylebox_override("normal", _button_style(true))
		scan_btn.add_theme_stylebox_override("hover", _button_style(true))
		scan_btn.pressed.connect(func() -> void:
			AudioManager.play_sfx("shoot_coil")
			GameState.notify("📡 終端天軌掃描脈衝已發射：周圍生態威脅與資源富集點已即時標記！")
		)
		act_row.add_child(scan_btn)

		var airdrop_btn := Button.new()
		var can_airdrop: bool = GameState.scrap >= 20
		airdrop_btn.text = "📦 調度終端空投補給 (消耗 20 廢鐵)" if can_airdrop else "📦 廢鐵不足 20：無法調度空投"
		airdrop_btn.disabled = not can_airdrop
		airdrop_btn.custom_minimum_size = Vector2(270, 40)
		airdrop_btn.add_theme_stylebox_override("normal", _button_style(can_airdrop))
		airdrop_btn.add_theme_stylebox_override("hover", _button_style(true))
		airdrop_btn.pressed.connect(func() -> void:
			if GameState.scrap >= 20:
				GameState.consume_item("scrap", 20)
				GameState.add_item("ammo", 16)
				GameState.add_item("alloy_plate", 1)
				AudioManager.play_sfx("pickup")
				GameState.notify("📦 終端緊急空投已送達：獲得彈藥 +16、合金板 +1！")
				_refresh_terminal()
		)
		act_row.add_child(airdrop_btn)

func _build_profile_card() -> PanelContainer:
	var profile_panel: PanelContainer = PanelContainer.new()
	profile_panel.custom_minimum_size = Vector2(330, 360)
	profile_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.025, 0.025, 0.82), Color(0.35, 0.55, 0.57, 0.95), 1))
	var profile_stack: VBoxContainer = VBoxContainer.new()
	profile_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	profile_stack.add_theme_constant_override("separation", 10)
	profile_panel.add_child(profile_stack)
	var name_label: Label = Label.new()
	name_label.text = "R-17 維修艙"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 20)
	profile_stack.add_child(name_label)
	var portrait: TextureRect = _fit_texture_rect(_player_preview_texture(), Vector2(188, 188))
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	profile_stack.add_child(portrait)
	var stat: Label = Label.new()
	stat.text = "HP %d/%d\nEP %d/%d\n攻擊 %+d  防禦 %+d  速度 %+d" % [GameState.hp, GameState.get_max_hp(), GameState.ep, GameState.get_max_ep(), GameState.get_stat_bonus("attack"), GameState.get_stat_bonus("defense"), GameState.get_stat_bonus("speed")]
	stat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stat.add_theme_font_size_override("font_size", 19)
	profile_stack.add_child(stat)

	var active_perks: Array[String] = []
	for p_id in GameState.perks.keys():
		var lvl: int = int(GameState.perks[p_id])
		if lvl > 0 and GameState.PERKS_CATALOG.has(p_id):
			var icon_char: String = String(GameState.PERKS_CATALOG[p_id].get("icon", "⚡"))
			var name_str: String = String(GameState.PERKS_CATALOG[p_id].get("name", p_id)).split(" ")[0]
			active_perks.append("%s %s Lv.%d" % [icon_char, name_str, lvl])
	if not active_perks.is_empty():
		var perk_lbl := Label.new()
		perk_lbl.text = "【戰術晶片】\n%s" % "\n".join(active_perks)
		perk_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		perk_lbl.add_theme_font_size_override("font_size", 13)
		perk_lbl.add_theme_color_override("font_color", Color(0.42, 0.95, 0.88))
		profile_stack.add_child(perk_lbl)

	return profile_panel

func _add_equipment_card(container: VBoxContainer, slot: String, label: String) -> void:
	var item_id: String = String(GameState.equipment.get(slot, ""))
	var equipment: Dictionary = DataRegistry.get_equipment(item_id)
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(660, 92)
	button.text = ""
	button.clip_contents = true
	button.add_theme_stylebox_override("normal", _panel_style(Color(0.045, 0.045, 0.040, 0.76), Color(0.20, 0.32, 0.34, 0.96), 1))
	button.add_theme_stylebox_override("hover", _panel_style(Color(0.070, 0.070, 0.058, 0.86), Color(0.86, 0.64, 0.26, 0.98), 1))
	button.pressed.connect(func() -> void:
		var slot_index: int = GameState.quick_slots.find(item_id)
		if slot_index >= 0:
			GameState.use_quick_slot(slot_index)
	)

	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.position = Vector2(14, 6)
	row.size = Vector2(632, 80)
	row.add_theme_constant_override("separation", 16)
	button.add_child(row)

	var icon_box: PanelContainer = PanelContainer.new()
	icon_box.custom_minimum_size = Vector2(150, 78)
	icon_box.size = Vector2(150, 78)
	icon_box.clip_contents = true
	icon_box.add_theme_stylebox_override("panel", _panel_style(Color(0.02, 0.02, 0.018, 0.22), Color(0.12, 0.18, 0.18, 0.35), 0))
	row.add_child(icon_box)
	var icon: TextureRect = _fit_texture_rect(_item_icon(item_id), Vector2(132, 72))
	icon.position = Vector2(9, 3)
	icon_box.add_child(icon)

	var divider: VSeparator = VSeparator.new()
	divider.custom_minimum_size = Vector2(8, 70)
	row.add_child(divider)

	var text_stack: VBoxContainer = VBoxContainer.new()
	text_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	text_stack.custom_minimum_size = Vector2(430, 78)
	text_stack.add_theme_constant_override("separation", 2)
	row.add_child(text_stack)

	var slot_label: Label = Label.new()
	slot_label.text = label
	slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_label.add_theme_font_size_override("font_size", 14)
	slot_label.add_theme_color_override("font_color", Color(0.72, 0.92, 0.92))
	text_stack.add_child(slot_label)

	var name_label: Label = Label.new()
	var wpn_suffix := ("  [Lv.%d]" % GameState.get_weapon_level(item_id)) if slot in ["weapon", "ranged"] else ""
	name_label.text = String(equipment.get("name", item_id)) + wpn_suffix
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color(0.96, 0.95, 0.90))
	text_stack.add_child(name_label)

	var info_label: Label = Label.new()
	info_label.text = "%s｜%s" % [_equipment_stats_text(equipment), _source_short_text(equipment)]
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.add_theme_font_size_override("font_size", 12)
	info_label.add_theme_color_override("font_color", Color(0.78, 0.78, 0.70))
	text_stack.add_child(info_label)

	button.tooltip_text = String(equipment.get("obtain_hint", ""))
	container.add_child(button)

func _fit_texture_rect(texture: Texture2D, box_size: Vector2) -> TextureRect:
	var rect: TextureRect = TextureRect.new()
	rect.custom_minimum_size = box_size
	rect.size = box_size
	rect.texture = texture
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

func _equipment_stats_text(equipment: Dictionary) -> String:
	var stats: Dictionary = equipment.get("stats", {})
	return "攻%+d 防%+d 速%+d" % [int(stats.get("attack", 0)), int(stats.get("defense", 0)), int(stats.get("speed", 0))]

func _source_short_text(equipment: Dictionary) -> String:
	match String(equipment.get("progression", "")):
		"base":
			return "初始"
		"craftable":
			return "村莊合成"
		"guild_reward":
			return "公會任務"
		_:
			return "裝備"

func _add_upgrade_button(container: HBoxContainer, label: String, kind: String) -> void:
	var button: Button = Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(90, 40)
	button.disabled = GameState.upgrade_points <= 0
	button.add_theme_stylebox_override("normal", _button_style(false))
	button.add_theme_stylebox_override("hover", _button_style(true))
	button.pressed.connect(func() -> void:
		if GameState.spend_upgrade_point(kind):
			_refresh_inventory()
	)
	container.add_child(button)

func _add_weapon_forge_button(container: HBoxContainer, slot: String, prefix: String) -> void:
	var item_id := String(GameState.equipment.get(slot, ""))
	var lvl := GameState.get_weapon_level(item_id)
	var cost := GameState.get_weapon_upgrade_cost(item_id)
	var button: Button = Button.new()
	button.text = ("%s Lv.MAX" % prefix) if lvl >= 5 else ("%s Lv.%d→%d (鐵%d)" % [prefix, lvl, lvl + 1, cost])
	button.custom_minimum_size = Vector2(160, 40)
	button.disabled = lvl >= 5 or GameState.scrap < cost
	button.add_theme_stylebox_override("normal", _button_style(false))
	button.add_theme_stylebox_override("hover", _button_style(true))
	button.pressed.connect(func() -> void:
		if GameState.upgrade_weapon_level(item_id):
			_refresh_inventory()
	)
	container.add_child(button)

func _add_bag_button(container: GridContainer, item_id: String, amount: int) -> void:
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(285, 60)
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.text = "%s x%d" % [GameState.item_display_name(item_id), amount]
	button.icon = _item_icon(item_id)
	button.expand_icon = true
	button.pressed.connect(_equip_from_inventory.bind(item_id))
	container.add_child(button)

func _item_icon(item_id: String) -> Texture2D:
	var resource: Dictionary = DataRegistry.get_resource(item_id)
	var equipment: Dictionary = DataRegistry.get_equipment(item_id)
	var asset_id: String = String(resource.get("icon_asset_id", equipment.get("icon_asset_id", "")))
	if not asset_id.is_empty():
		var path: String = DataRegistry.asset_path(asset_id)
		if not path.is_empty():
			var texture: Texture2D = ASSET_LOADER.load_png(path)
			if texture != null:
				return texture
	return PIXEL.new().item_texture(item_id)

func _player_preview_texture() -> Texture2D:
	var frame_path: String = "res://assets/sprites/player/frames/idle/dir_2/frame_0.png"
	var frame_texture: Texture2D = ASSET_LOADER.load_png(frame_path)
	if frame_texture != null:
		return frame_texture
	return PIXEL.new().player_texture(2, 0, 0)

func _equip_from_inventory(item_id: String) -> void:
	if DataRegistry.get_equipment(item_id).is_empty():
		GameState.notify("%s 是材料，無法直接裝備。" % GameState.item_display_name(item_id))
		return
	GameState.equip_item(item_id)
	_refresh_inventory()
	_refresh_hotbar()

func _show_dialogue(speaker: String, role: String, message: String) -> void:
	dialogue_speaker.text = speaker
	dialogue_role.text = role
	dialogue_body.text = message
	dialogue_portrait.texture = _npc_portrait_texture(speaker)
	dialogue_panel.visible = true
	if dialogue_timer != null:
		dialogue_timer.start(14.0)
	_refresh_overlay_visibility()

func _hide_dialogue() -> void:
	if dialogue_panel == null:
		return
	dialogue_panel.visible = false
	if dialogue_timer != null:
		dialogue_timer.stop()
	_refresh_overlay_visibility()

func _npc_portrait_texture(speaker: String) -> Texture2D:
	for npc: Dictionary in DataRegistry.npcs_for_scene(GameState.current_scene_id):
		if String(npc.get("name", "")) == speaker:
			var portrait_id: String = String(npc.get("portrait_asset_id", npc.get("sprite_asset_id", "")))
			var path: String = DataRegistry.asset_path(portrait_id)
			if not path.is_empty():
				var texture: Texture2D = ASSET_LOADER.load_png(path)
				if texture != null:
					return texture
	return PIXEL.new().make_texture(Vector2i(72, 96), [Color8(49, 58, 56), Color8(104, 132, 126), Color8(178, 216, 204)], speaker.length())

func _show_notice(message: String) -> void:
	if notice_label == null:
		return
	notice_label.text = message
	if notice_timer != null:
		notice_timer.start(3.0)
	_update_notice_visibility()
	call_deferred("_layout_after_notice")

func _update_notice_visibility() -> void:
	if notice_label == null:
		return
	var modal_covers_notice: bool = inventory_panel != null and inventory_panel.visible
	modal_covers_notice = modal_covers_notice or (workshop_panel != null and workshop_panel.visible)
	modal_covers_notice = modal_covers_notice or (contract_panel != null and contract_panel.visible)
	modal_covers_notice = modal_covers_notice or (terminal_panel != null and terminal_panel.visible)
	modal_covers_notice = modal_covers_notice or (codex_panel != null and codex_panel.visible)
	modal_covers_notice = modal_covers_notice or (tutorial_panel != null and tutorial_panel.visible)
	modal_covers_notice = modal_covers_notice or map_fullscreen
	modal_covers_notice = modal_covers_notice or (dialogue_panel != null and dialogue_panel.visible)
	var notice_active: bool = notice_timer != null and not notice_timer.is_stopped()
	notice_label.visible = notice_active and not modal_covers_notice

func _on_notice_timeout() -> void:
	if notice_label != null:
		notice_label.visible = false

func _layout_after_notice() -> void:
	await get_tree().process_frame
	_layout()

func _attack_mode_label(mode: String) -> String:
	match mode:
		"ranged":
			return "遠程"
		"tool":
			return "工具"
		_:
			return "近戰"

func _make_bar(fill: Color, background: Color) -> ProgressBar:
	var bar: ProgressBar = ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(216, 13)
	var fill_style: StyleBoxFlat = StyleBoxFlat.new()
	fill_style.bg_color = fill
	fill_style.border_color = fill.lightened(0.28)
	fill_style.border_width_top = 1
	fill_style.corner_radius_top_left = 3
	fill_style.corner_radius_top_right = 3
	fill_style.corner_radius_bottom_left = 3
	fill_style.corner_radius_bottom_right = 3
	var bg_style: StyleBoxFlat = StyleBoxFlat.new()
	bg_style.bg_color = background
	bg_style.border_color = Color(0.28, 0.34, 0.38, 0.85)
	bg_style.border_width_left = 1
	bg_style.border_width_right = 1
	bg_style.border_width_top = 1
	bg_style.border_width_bottom = 1
	bg_style.corner_radius_top_left = 3
	bg_style.corner_radius_top_right = 3
	bg_style.corner_radius_bottom_left = 3
	bg_style.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("fill", fill_style)
	bar.add_theme_stylebox_override("background", bg_style)
	return bar

func _attach_bar_overlay_label(bar: ProgressBar) -> Label:
	var lbl := Label.new()
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(0.98, 0.98, 0.96))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	bar.add_child(lbl)
	return lbl

func _bar_row(label: String, bar: ProgressBar, label_color := Color(0.92, 0.94, 0.90)) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var name: Label = Label.new()
	name.text = label
	name.custom_minimum_size = Vector2(38, 16)
	name.add_theme_font_size_override("font_size", 11)
	name.add_theme_color_override("font_color", label_color)
	row.add_child(name)
	row.add_child(bar)
	return row


func _panel_style(bg: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_right = border_width
	style.border_width_top = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style

func _button_style(active: bool) -> StyleBoxFlat:
	var bg: Color = Color(0.14, 0.11, 0.06, 0.96) if active else Color(0.055, 0.066, 0.082, 0.92)
	var border: Color = Color(0.98, 0.74, 0.22, 1.0) if active else Color(0.32, 0.44, 0.50, 0.92)
	var st := _panel_style(bg, border, 2 if active else 1)
	if active:
		st.border_width_top = 4
	return st
