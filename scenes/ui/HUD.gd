extends CanvasLayer

const MAP_VIEW := preload("res://scripts/ui/WorldMapView.gd")
const PIXEL := preload("res://scripts/utils/PixelArtFactory.gd")
const ASSET_LOADER := preload("res://scripts/utils/RuntimeAssetLoader.gd")

var root: Control
var status_panel: PanelContainer
var stats_label: Label
var hp_bar: ProgressBar
var ep_bar: ProgressBar
var quest_panel: PanelContainer
var quest_label: Label
var quick_bar_panel: PanelContainer
var quick_bar: HBoxContainer
var inventory_panel: PanelContainer
var inventory_list: VBoxContainer
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

func _ready() -> void:
	_build_hud()
	GameState.stats_changed.connect(_refresh)
	GameState.inventory_changed.connect(_refresh_inventory)
	GameState.equipment_changed.connect(_refresh_inventory)
	GameState.equipment_changed.connect(_refresh_hotbar)
	GameState.notification_requested.connect(_show_notice)
	GameState.dialogue_requested.connect(_show_dialogue)
	GameState.dialogue_closed.connect(_hide_dialogue)
	_refresh()
	_refresh_inventory()
	_refresh_overlay_visibility()
	_layout()

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("open_inventory"):
		_set_inventory_visible(not inventory_panel.visible)
	if Input.is_action_just_pressed("toggle_minimap"):
		_toggle_map()
	if Input.is_action_just_pressed("toggle_help"):
		tutorial_panel.visible = not tutorial_panel.visible
		_refresh_overlay_visibility()
	_layout()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if inventory_panel.visible:
			_set_inventory_visible(false)
		elif tutorial_panel.visible:
			tutorial_panel.visible = false
			_refresh_overlay_visibility()
		elif map_fullscreen:
			map_fullscreen = false
			_refresh_overlay_visibility()
		elif dialogue_panel.visible:
			_hide_dialogue()
		elif pause_panel.visible:
			_set_pause_visible(false)
		else:
			_set_pause_visible(true)

func _layout() -> void:
	var size: Vector2 = get_viewport().get_visible_rect().size
	if status_panel != null:
		status_panel.position = Vector2(size.x - 442.0, 18.0)
		status_panel.custom_minimum_size = Vector2(420, 96)
		status_panel.size = Vector2(420, 96)
	if quest_panel != null:
		var quest_size: Vector2 = Vector2(min(620.0, max(260.0, size.x - 500.0)), 78)
		quest_panel.position = Vector2(18, 18)
		quest_panel.custom_minimum_size = quest_size
		quest_panel.size = quest_size
	if quick_bar_panel != null:
		quick_bar_panel.position = Vector2(max(16.0, (size.x - 520.0) * 0.5), size.y - 82.0)
		quick_bar_panel.size = Vector2(520, 64)
	if controls_hint != null:
		controls_hint.position = Vector2(max(16.0, (size.x - controls_hint.size.x) * 0.5), size.y - 116.0)
	if dialogue_panel != null:
		dialogue_panel.position = Vector2(max(24.0, (size.x - 920.0) * 0.5), size.y - 308.0)
		dialogue_panel.size = Vector2(min(920.0, size.x - 48.0), 248)
	if minimap_panel != null:
		if map_fullscreen:
			minimap_panel.position = Vector2(48, 48)
			minimap_panel.custom_minimum_size = size - Vector2(96, 96)
			minimap_panel.size = size - Vector2(96, 96)
		else:
			minimap_panel.position = Vector2(size.x - 330.0, 126.0)
			minimap_panel.custom_minimum_size = Vector2(308, 210)
			minimap_panel.size = Vector2(308, 210)
	if inventory_panel != null:
		var inventory_size: Vector2 = Vector2(min(980.0, size.x - 44.0), min(660.0, size.y - 118.0))
		inventory_panel.position = Vector2(max(22.0, (size.x - 980.0) * 0.5), 76)
		inventory_panel.custom_minimum_size = inventory_size
		inventory_panel.size = inventory_size
	if tutorial_panel != null:
		var tutorial_size: Vector2 = Vector2(min(500.0, size.x - 44.0), 246)
		tutorial_panel.position = Vector2(22, max(118.0, size.y - 392.0))
		tutorial_panel.custom_minimum_size = tutorial_size
		tutorial_panel.size = tutorial_size
	if pause_panel != null:
		pause_panel.position = Vector2((size.x - 340.0) * 0.5, (size.y - 330.0) * 0.5)
		pause_panel.custom_minimum_size = Vector2(340, 330)
		pause_panel.size = Vector2(340, 330)
	if notice_label != null:
		notice_label.position = Vector2(max(18.0, (size.x - notice_label.size.x) * 0.5), 106.0)

func _build_hud() -> void:
	root = Control.new()
	root.name = "HudRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	_build_status_panel()
	_build_quest_panel()
	_build_inventory_panel()
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
	status_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.04, 0.035, 0.025, 0.88), Color(0.90, 0.48, 0.26, 1.0), 2))
	root.add_child(status_panel)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	status_panel.add_child(stack)
	stats_label = Label.new()
	stats_label.add_theme_font_size_override("font_size", 15)
	stack.add_child(stats_label)
	hp_bar = _make_bar(Color(0.95, 0.06, 0.05), Color(0.25, 0.02, 0.02, 0.95))
	ep_bar = _make_bar(Color(0.0, 0.85, 0.95), Color(0.02, 0.14, 0.17, 0.95))
	stack.add_child(_bar_row("HP", hp_bar))
	stack.add_child(_bar_row("EP", ep_bar))

func _build_quest_panel() -> void:
	quest_panel = PanelContainer.new()
	quest_panel.name = "QuestPanel"
	quest_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.04, 0.035, 0.025, 0.82), Color(0.30, 0.32, 0.30, 0.88), 1))
	root.add_child(quest_panel)
	quest_label = Label.new()
	quest_label.add_theme_font_size_override("font_size", 15)
	quest_label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.86))
	quest_panel.add_child(quest_label)

func _build_inventory_panel() -> void:
	inventory_panel = PanelContainer.new()
	inventory_panel.name = "InventoryPanel"
	inventory_panel.z_index = 60
	inventory_panel.visible = false
	inventory_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.02, 0.025, 0.025, 0.91), Color(0.86, 0.64, 0.26, 0.98), 2))
	root.add_child(inventory_panel)
	var scroll: ScrollContainer = ScrollContainer.new()
	inventory_panel.add_child(scroll)
	inventory_list = VBoxContainer.new()
	inventory_list.add_theme_constant_override("separation", 10)
	scroll.add_child(inventory_list)

func _add_quick_bar() -> void:
	quick_bar_panel = PanelContainer.new()
	quick_bar_panel.name = "QuickBar"
	quick_bar_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.03, 0.026, 0.018, 0.90), Color(0.45, 0.38, 0.22, 0.82), 1))
	root.add_child(quick_bar_panel)
	quick_bar = HBoxContainer.new()
	quick_bar.add_theme_constant_override("separation", 8)
	quick_bar_panel.add_child(quick_bar)

func _add_minimap() -> void:
	minimap_panel = PanelContainer.new()
	minimap_panel.name = "MinimapPanel"
	minimap_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.02, 0.024, 0.022, 0.90), Color(0.30, 0.42, 0.42, 0.9), 1))
	root.add_child(minimap_panel)
	var stack: VBoxContainer = VBoxContainer.new()
	minimap_panel.add_child(stack)
	minimap_title = Label.new()
	minimap_title.text = "地圖 M"
	minimap_title.add_theme_font_size_override("font_size", 15)
	stack.add_child(minimap_title)
	map_view = MAP_VIEW.new()
	map_view.custom_minimum_size = Vector2(280, 160)
	stack.add_child(map_view)

func _add_tutorial() -> void:
	tutorial_panel = PanelContainer.new()
	tutorial_panel.name = "TutorialPanel"
	tutorial_panel.visible = false
	tutorial_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.025, 0.022, 0.92), Color(0.86, 0.64, 0.26, 0.95), 2))
	root.add_child(tutorial_panel)
	var text: Label = Label.new()
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_font_size_override("font_size", 14)
	text.text = "操作說明\nWASD / 方向鍵：移動\nShift：奔跑（消耗 EP，停止後回復）\n滑鼠左鍵：使用目前快捷欄裝備攻擊\nE：互動、拾取、對話\nTab：人物裝備與背包\n1~4：切換快捷欄\nM：地圖 / 全屏地圖 / 關閉地圖\nESC：暫停、關閉面板"
	tutorial_panel.add_child(text)

func _add_controls_hint() -> void:
	controls_hint = Label.new()
	controls_hint.text = "Tab 人物裝備｜H 教學｜M 地圖｜E 互動"
	controls_hint.add_theme_font_size_override("font_size", 14)
	controls_hint.add_theme_color_override("font_color", Color(0.95, 0.95, 0.88))
	root.add_child(controls_hint)

func _add_dialogue_box() -> void:
	dialogue_panel = PanelContainer.new()
	dialogue_panel.name = "DialoguePanel"
	dialogue_panel.add_to_group("dialogue_panel")
	dialogue_panel.custom_minimum_size = Vector2(920, 248)
	dialogue_panel.z_index = 90
	dialogue_panel.visible = false
	dialogue_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.018, 0.020, 0.020, 0.92), Color(0.86, 0.64, 0.26, 0.98), 2))
	root.add_child(dialogue_panel)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	dialogue_panel.add_child(row)
	dialogue_portrait = TextureRect.new()
	dialogue_portrait.custom_minimum_size = Vector2(122, 202)
	dialogue_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	dialogue_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(dialogue_portrait)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)
	row.add_child(stack)
	dialogue_speaker = Label.new()
	dialogue_speaker.add_theme_font_size_override("font_size", 19)
	dialogue_speaker.add_theme_color_override("font_color", Color(1.0, 0.86, 0.42))
	stack.add_child(dialogue_speaker)
	dialogue_role = Label.new()
	dialogue_role.add_theme_font_size_override("font_size", 13)
	dialogue_role.add_theme_color_override("font_color", Color(0.72, 0.92, 0.92))
	stack.add_child(dialogue_role)
	dialogue_body = Label.new()
	dialogue_body.add_theme_font_size_override("font_size", 16)
	dialogue_body.custom_minimum_size = Vector2(740, 132)
	dialogue_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(dialogue_body)
	var hint: Label = Label.new()
	hint.text = "E 繼續互動｜Esc 關閉｜離開 NPC 範圍會自動關閉"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.72, 0.72, 0.68))
	stack.add_child(hint)
	dialogue_timer = Timer.new()
	dialogue_timer.one_shot = true
	dialogue_timer.timeout.connect(_hide_dialogue)
	add_child(dialogue_timer)

func _add_pause_menu() -> void:
	pause_panel = PanelContainer.new()
	pause_panel.name = "PausePanel"
	pause_panel.z_index = 100
	pause_panel.visible = false
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
	_add_pause_button(stack, "讀取存檔", func() -> void: SaveManager.load_game(true, true))
	_add_pause_button(stack, "返回標題", func() -> void: SceneRouter.change_to("main", "default"))
	_add_pause_button(stack, "退出遊戲", func() -> void: get_tree().quit(0))

func _add_notice_label() -> void:
	notice_label = Label.new()
	notice_label.name = "NoticeLabel"
	notice_label.z_index = 120
	notice_label.visible = false
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
	notice_timer.timeout.connect(func() -> void:
		if notice_label != null:
			notice_label.visible = false
	)
	add_child(notice_timer)

func _add_pause_button(container: VBoxContainer, text: String, callback: Callable) -> void:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(290, 42)
	button.pressed.connect(callback)
	container.add_child(button)

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

func _open_full_map() -> void:
	if map_open and not inventory_panel.visible and not tutorial_panel.visible and not pause_panel.visible:
		map_fullscreen = true
		_refresh_overlay_visibility()

func _set_inventory_visible(is_visible: bool) -> void:
	inventory_panel.visible = is_visible
	if is_visible:
		map_fullscreen = false
		tutorial_panel.visible = false
		pause_panel.visible = false
		_refresh_inventory()
	_refresh_overlay_visibility()

func _set_pause_visible(is_visible: bool) -> void:
	pause_panel.visible = is_visible
	if is_visible:
		map_fullscreen = false
		inventory_panel.visible = false
		tutorial_panel.visible = false
		_hide_dialogue()
	_refresh_overlay_visibility()

func _refresh_overlay_visibility() -> void:
	var modal_open: bool = inventory_panel.visible or tutorial_panel.visible or map_fullscreen or dialogue_panel.visible or pause_panel.visible
	quick_bar_panel.visible = not modal_open
	controls_hint.visible = not modal_open
	minimap_panel.visible = map_open and not inventory_panel.visible and not tutorial_panel.visible and not dialogue_panel.visible and not pause_panel.visible
	if map_view != null:
		map_view.set_full_screen(map_fullscreen)
	if minimap_title != null:
		minimap_title.text = "全屏地圖 Esc" if map_fullscreen else "地圖 M"
	_layout()

func _refresh() -> void:
	var route: Dictionary = DataRegistry.get_wasteland_route(GameState.current_route_id)
	var route_name: String = String(route.get("name", "村莊"))
	var max_hp: int = GameState.get_max_hp() if GameState.has_method("get_max_hp") else GameState.MAX_HP
	var max_ep: int = GameState.get_max_ep() if GameState.has_method("get_max_ep") else GameState.MAX_EP
	hp_bar.max_value = max_hp
	hp_bar.value = GameState.hp
	ep_bar.max_value = max_ep
	ep_bar.value = GameState.ep
	stats_label.text = "R-17 Lv.%d  XP %d/%d  彈藥 %d  廢鐵 %d  核心 %d" % [
		GameState.level,
		GameState.xp,
		GameState.xp_to_next_level(),
		GameState.ammo,
		GameState.scrap,
		GameState.cores
	]
	quest_label.text = "場景：%s｜路線：%s\n委託：%s" % [GameState.current_scene_id, route_name, GameState.active_quest_summary()]

func _refresh_hotbar() -> void:
	for child in quick_bar.get_children():
		child.queue_free()
	for i in range(GameState.quick_slots.size()):
		var item_id: String = String(GameState.quick_slots[i])
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(120, 48)
		button.text = "%s %d" % [">" if i == GameState.active_quick_slot else "", i + 1]
		if not item_id.is_empty():
			button.icon = _item_icon(item_id)
			button.tooltip_text = GameState.item_display_name(item_id)
		button.expand_icon = true
		button.add_theme_stylebox_override("normal", _button_style(i == GameState.active_quick_slot))
		button.add_theme_stylebox_override("hover", _button_style(true))
		button.pressed.connect(func() -> void: GameState.use_quick_slot(i))
		quick_bar.add_child(button)

func _refresh_inventory() -> void:
	if inventory_list == null:
		return
	for child in inventory_list.get_children():
		child.queue_free()
	var title: Label = Label.new()
	title.text = "人物裝備：R-17 回收機器人"
	title.add_theme_font_size_override("font_size", 26)
	inventory_list.add_child(title)
	var current_item: String = GameState.active_attack_item_id()
	var current_equipment: Dictionary = DataRegistry.get_equipment(current_item)
	var current_name: String = String(current_equipment.get("name", GameState.item_display_name(current_item)))
	var mode_label: String = _attack_mode_label(String(current_equipment.get("attack_mode", "melee")))
	var active_label: Label = Label.new()
	active_label.text = "目前左鍵：%s（%s）｜升級點：%d" % [current_name, mode_label, GameState.upgrade_points]
	active_label.add_theme_font_size_override("font_size", 18)
	inventory_list.add_child(active_label)

	var top: HBoxContainer = HBoxContainer.new()
	top.add_theme_constant_override("separation", 18)
	inventory_list.add_child(top)

	var profile: VBoxContainer = VBoxContainer.new()
	profile.add_theme_constant_override("separation", 10)
	var profile_panel: PanelContainer = PanelContainer.new()
	profile_panel.custom_minimum_size = Vector2(300, 330)
	profile_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.025, 0.025, 0.82), Color(0.35, 0.55, 0.57, 0.95), 1))
	var profile_stack: VBoxContainer = VBoxContainer.new()
	profile_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	profile_panel.add_child(profile_stack)
	var name_label: Label = Label.new()
	name_label.text = "R-17 維修艙"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 20)
	profile_stack.add_child(name_label)
	var portrait: TextureRect = TextureRect.new()
	portrait.custom_minimum_size = Vector2(170, 170)
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.texture = _player_preview_texture()
	profile_stack.add_child(portrait)
	var stat: Label = Label.new()
	stat.text = "HP %d/%d\nEP %d/%d\n攻擊 %+d  防禦 %+d  速度 %+d" % [
		GameState.hp,
		GameState.get_max_hp(),
		GameState.ep,
		GameState.get_max_ep(),
		GameState.get_stat_bonus("attack"),
		GameState.get_stat_bonus("defense"),
		GameState.get_stat_bonus("speed")
	]
	stat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stat.add_theme_font_size_override("font_size", 19)
	profile_stack.add_child(stat)
	profile.add_child(profile_panel)
	top.add_child(profile)

	var equip_list: VBoxContainer = VBoxContainer.new()
	equip_list.add_theme_constant_override("separation", 10)
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

	var separator: HSeparator = HSeparator.new()
	inventory_list.add_child(separator)
	var bag_label: Label = Label.new()
	bag_label.text = "背包物品（點擊裝備可穿戴）"
	bag_label.add_theme_font_size_override("font_size", 20)
	inventory_list.add_child(bag_label)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	inventory_list.add_child(grid)
	for item_id in GameState.inventory.keys():
		_add_bag_button(grid, String(item_id), int(GameState.inventory[item_id]))

func _add_equipment_card(container: VBoxContainer, slot: String, label: String) -> void:
	var item_id: String = String(GameState.equipment.get(slot, ""))
	var equipment: Dictionary = DataRegistry.get_equipment(item_id)
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(560, 94)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text = "%s\n%s" % [label, String(equipment.get("name", item_id))]
	button.icon = _item_icon(item_id)
	button.expand_icon = true
	button.pressed.connect(func() -> void:
		var slot_index: int = GameState.quick_slots.find(item_id)
		if slot_index >= 0:
			GameState.use_quick_slot(slot_index)
	)
	container.add_child(button)

func _add_upgrade_button(container: HBoxContainer, label: String, kind: String) -> void:
	var button: Button = Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(90, 42)
	button.disabled = GameState.upgrade_points <= 0
	button.pressed.connect(func() -> void:
		if GameState.spend_upgrade_point(kind):
			_refresh_inventory()
	)
	container.add_child(button)

func _add_bag_button(container: GridContainer, item_id: String, amount: int) -> void:
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(250, 62)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
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
		var texture: Texture2D = ASSET_LOADER.load_png(DataRegistry.asset_path(asset_id))
		if texture != null:
			return texture
	return PIXEL.new().item_texture(item_id)

func _player_preview_texture() -> Texture2D:
	var atlas: Texture2D = ASSET_LOADER.load_png("res://assets/sprites/player/recycler_player_multiaction_8dir.png")
	if atlas == null:
		return PIXEL.new().player_texture(2, 0, 1)
	var texture: AtlasTexture = AtlasTexture.new()
	texture.atlas = atlas
	texture.region = Rect2(0, 2 * PixelArtFactory.PLAYER_FRAME_SIZE.y, PixelArtFactory.PLAYER_FRAME_SIZE.x, PixelArtFactory.PLAYER_FRAME_SIZE.y)
	return texture

func _equip_from_inventory(item_id: String) -> void:
	if not DataRegistry.get_equipment(item_id).is_empty():
		GameState.equip_item(item_id)
		_refresh_inventory()

func _attack_mode_label(mode: String) -> String:
	match mode:
		"ranged":
			return "遠程"
		"melee":
			return "近戰"
		"tool":
			return "工具"
		_:
			return "資源"

func _show_notice(message: String) -> void:
	if notice_label == null or notice_timer == null:
		return
	notice_label.text = message
	notice_label.visible = true
	notice_timer.start(2.4)
	_layout()

func _show_dialogue(speaker: String, role: String, message: String) -> void:
	dialogue_speaker.text = speaker
	dialogue_role.text = role
	dialogue_body.text = message
	dialogue_portrait.texture = _portrait_for_speaker(speaker)
	dialogue_panel.visible = true
	dialogue_timer.start(14.0)
	_refresh_overlay_visibility()
	_layout()

func _portrait_for_speaker(speaker: String) -> Texture2D:
	for npc: Dictionary in DataRegistry.npcs:
		if String(npc.get("name", "")) == speaker:
			var asset_id: String = String(npc.get("portrait_asset_id", npc.get("sprite_asset_id", "")))
			var texture: Texture2D = ASSET_LOADER.load_png(DataRegistry.asset_portrait_path(asset_id, DataRegistry.asset_path(asset_id)))
			if texture != null:
				return texture
	return _player_preview_texture()

func _hide_dialogue() -> void:
	if dialogue_panel == null:
		return
	dialogue_panel.visible = false
	if dialogue_timer != null:
		dialogue_timer.stop()
	_refresh_overlay_visibility()

func _make_bar(fill_color: Color, bg_color: Color) -> ProgressBar:
	var bar: ProgressBar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(330, 16)
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", _panel_style(bg_color, Color(0.10, 0.10, 0.10, 0.85), 1))
	bar.add_theme_stylebox_override("fill", _panel_style(fill_color, fill_color.lightened(0.25), 1))
	return bar

func _bar_row(label_text: String, bar: ProgressBar) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var label: Label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(34, 18)
	label.add_theme_font_size_override("font_size", 13)
	row.add_child(label)
	row.add_child(bar)
	return row

func _panel_style(bg: Color, border: Color, border_width := 1) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_right = border_width
	style.border_width_top = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _button_style(selected: bool) -> StyleBoxFlat:
	if selected:
		return _panel_style(Color(0.18, 0.18, 0.14, 0.92), Color(1.0, 0.72, 0.28, 1.0), 2)
	return _panel_style(Color(0.05, 0.05, 0.048, 0.82), Color(0.30, 0.28, 0.24, 0.88), 1)
