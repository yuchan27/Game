extends PanelContainer

const ASSET_LOADER := preload("res://scripts/utils/RuntimeAssetLoader.gd")
const ROUTES := ["scrap_highway", "toxic_marsh", "crystal_scar", "old_factory", "ruined_metropolis", "underground_facility"]
const MARKERS := [Vector2(0.19, 0.28), Vector2(0.48, 0.69), Vector2(0.42, 0.16), Vector2(0.62, 0.36), Vector2(0.84, 0.21), Vector2(0.86, 0.59)]
const STACKED_LAYOUT_BREAKPOINT := 800.0
const SINGLE_COLUMN_BREAKPOINT := 640.0
const STACKED_DETAILS_MIN_HEIGHT := 280.0
const INK := Color("171518")
const BRONZE := Color("785b37")
const AMBER := Color("e3b66b")
const PAPER := Color("e3dac5")

var selected_route_id := "scrap_highway"
var route_buttons: Dictionary = {}
var map_markers: Dictionary = {}
var map_texture: TextureRect
var detail_label: RichTextLabel
var summary_label: Label
var _content_scroll: ScrollContainer
var _content: VBoxContainer
var _body: BoxContainer
var _map_canvas: Control
var _regions: GridContainer
var _detail_frame: PanelContainer
var _detail_scroll: ScrollContainer
var _detail_title: Label


func _ready() -> void:
	name = "WorldAtlasPanel"
	add_to_group("world_atlas_panel")
	add_to_group("gameplay_input_blocker")
	set_meta("gameplay_input_blocked", false)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 66
	add_theme_stylebox_override("panel", _style(INK, BRONZE, 2))
	_content_scroll = ScrollContainer.new()
	_content_scroll.name = "AtlasContentScroll"
	_content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_content_scroll.follow_focus = true
	_content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_content_scroll)
	_content = VBoxContainer.new()
	_content.name = "AtlasContent"
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	_content_scroll.add_child(_content)
	var heading := Label.new()
	heading.text = "世 界 紀 行  /  灰燼之後的名字"
	heading.add_theme_font_size_override("font_size", 23)
	heading.add_theme_color_override("font_color", AMBER)
	_content.add_child(heading)
	summary_label = Label.new()
	summary_label.name = "AtlasSummary"
	summary_label.add_theme_font_size_override("font_size", 13)
	summary_label.add_theme_color_override("font_color", PAPER)
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(summary_label)
	_body = BoxContainer.new()
	_body.name = "AtlasBody"
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 14)
	_content.add_child(_body)
	var left := VBoxContainer.new()
	left.name = "AtlasMapAndRegions"
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 6)
	_body.add_child(left)
	var map_frame := PanelContainer.new()
	map_frame.name = "AtlasMapFrame"
	map_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_frame.add_theme_stylebox_override("panel", _style(Color("0d0e10"), BRONZE))
	left.add_child(map_frame)
	_map_canvas = Control.new()
	_map_canvas.custom_minimum_size = Vector2(0, 240)
	map_frame.add_child(_map_canvas)
	map_texture = TextureRect.new()
	map_texture.name = "WorldAtlasIllustration"
	map_texture.texture = ASSET_LOADER.load_png("res://assets/ui/world_atlas.png")
	map_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	map_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_canvas.add_child(map_texture)
	var caption := Label.new()
	caption.text = "行旅繪圖描繪六區地標；編號可選取地區。實際道路與敵人位置請按 M 查看區域地圖。"
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.add_theme_font_size_override("font_size", 11)
	caption.add_theme_color_override("font_color", Color("b6aa93"))
	left.add_child(caption)
	_regions = GridContainer.new()
	_regions.name = "AtlasRegions"
	_regions.columns = 2
	_regions.add_theme_constant_override("h_separation", 6)
	_regions.add_theme_constant_override("v_separation", 5)
	_regions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(_regions)
	for index in range(ROUTES.size()):
		var route_id: String = ROUTES[index]
		var button := _region_button(route_id)
		button.name = "AtlasRoute_%s" % route_id
		button.custom_minimum_size = Vector2(0, 42)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_regions.add_child(button)
		route_buttons[route_id] = button
		var marker := _region_button(route_id)
		marker.remove_from_group("world_atlas_route")
		marker.add_to_group("world_atlas_marker")
		marker.text = "%02d" % (index + 1)
		marker.size = Vector2(32, 28)
		_map_canvas.add_child(marker)
		map_markers[route_id] = marker
	_detail_frame = PanelContainer.new()
	_detail_frame.name = "AtlasDetailsFrame"
	_detail_frame.custom_minimum_size.x = 320
	_detail_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_frame.add_theme_stylebox_override("panel", _style(Color("1d1a1b"), BRONZE))
	_body.add_child(_detail_frame)
	var detail_stack := VBoxContainer.new()
	detail_stack.name = "AtlasDetailsStack"
	detail_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_stack.add_theme_constant_override("separation", 10)
	_detail_frame.add_child(detail_stack)
	_detail_title = Label.new()
	_detail_title.add_theme_font_size_override("font_size", 20)
	_detail_title.add_theme_color_override("font_color", AMBER)
	detail_stack.add_child(_detail_title)
	_detail_scroll = ScrollContainer.new()
	_detail_scroll.name = "AtlasDetailsScroll"
	_detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_stack.add_child(_detail_scroll)
	detail_label = RichTextLabel.new()
	detail_label.name = "AtlasRegionDetails"
	detail_label.bbcode_enabled = true
	detail_label.fit_content = true
	detail_label.scroll_active = false
	detail_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_label.add_theme_font_size_override("normal_font_size", 14)
	detail_label.add_theme_color_override("default_color", PAPER)
	_detail_scroll.add_child(detail_label)
	var footer := Label.new()
	footer.name = "AtlasFooter"
	footer.text = "G / Esc 關閉　·　Tab / 方向鍵選擇、Enter 確認　·　PageUp／PageDown 閱讀　·　J 委託　·　K 手記　·　閱讀時暫停"
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_theme_font_size_override("font_size", 12)
	footer.add_theme_color_override("font_color", Color("c6b38e"))
	_content.add_child(footer)
	resized.connect(_update_layout)
	_content_scroll.resized.connect(_update_layout)
	_content.resized.connect(_update_layout)
	_map_canvas.resized.connect(_layout_markers)
	var next_quest := DataRegistry.get_quest(GameState.next_story_quest_id())
	selected_route_id = String(next_quest.get("route", GameState.current_route_id))
	if not ROUTES.has(selected_route_id):
		selected_route_id = String(ROUTES[0])
	refresh()
	call_deferred("_update_layout")


func set_navigation(navigation: Control) -> void:
	navigation.name = "ModalNavigation"
	navigation.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(navigation)
	_content.move_child(navigation, 0)


func _update_layout() -> void:
	if _content == null or _body == null or _regions == null or _detail_frame == null:
		return
	var available_width := _content_scroll.size.x
	if available_width <= 0.0:
		return
	var stacked := available_width < STACKED_LAYOUT_BREAKPOINT
	if _body.vertical != stacked:
		_body.vertical = stacked
	var region_columns := 1 if available_width < SINGLE_COLUMN_BREAKPOINT else 2
	if _regions.columns != region_columns:
		_regions.columns = region_columns
	var navigation := _content.get_node_or_null("ModalNavigation") as GridContainer
	if navigation != null:
		var navigation_columns := 8 if available_width >= STACKED_LAYOUT_BREAKPOINT else (4 if available_width >= SINGLE_COLUMN_BREAKPOINT else 2)
		if navigation.columns != navigation_columns:
			navigation.columns = navigation_columns
	var detail_minimum := Vector2(0.0 if stacked else 320.0, STACKED_DETAILS_MIN_HEIGHT if stacked else 0.0)
	if _detail_frame.custom_minimum_size != detail_minimum:
		_detail_frame.custom_minimum_size = detail_minimum
	call_deferred("_layout_markers")


func select_route(route_id: String) -> void:
	if not ROUTES.has(route_id):
		return
	selected_route_id = route_id
	refresh()
	_detail_scroll.scroll_vertical = 0


func refresh() -> void:
	var completed := 0
	for route_id: String in ROUTES:
		var quest := _route_quest(route_id)
		if GameState.completed_quests.has(String(quest.get("id", ""))):
			completed += 1
		var index := ROUTES.find(route_id)
		var button: Button = route_buttons[route_id]
		button.text = "%02d  %s\n%s" % [index + 1, _route_name(route_id), _quest_status(quest)]
		button.button_pressed = route_id == selected_route_id
		(map_markers[route_id] as Button).button_pressed = route_id == selected_route_id
	var location := _route_name(GameState.current_route_id) if GameState.current_scene_id == "wasteland" else "避難村與公會"
	summary_label.text = "旅程 %d / 6 章　·　%s　·　目前：%s" % [completed, GameState.get_story_summary(), location]
	var quest := _route_quest(selected_route_id)
	_detail_title.text = "%02d  %s" % [ROUTES.find(selected_route_id) + 1, _route_name(selected_route_id)]
	var text := "[color=#e3b66b]%s  ·  建議 Lv.%d[/color]\n%s\n\n" % [_quest_status(quest), int(quest.get("recommended_level", 1)), String(quest.get("story_step", ""))]
	text += "[color=#e3b66b]委託目標[/color]\n" + _objectives(quest) + "\n"
	text += "[color=#e3b66b]前置委託[/color]\n"
	var prerequisites: Array = quest.get("prerequisites", [])
	if prerequisites.is_empty():
		text += "無；回公會按 J 選擇這份委託。\n"
	for prerequisite in prerequisites:
		text += "%s %s\n" % ["已完成" if GameState.completed_quests.has(String(prerequisite)) else "待完成", String(DataRegistry.get_quest(String(prerequisite)).get("name", prerequisite))]
	text += "\n[color=#e3b66b]地區紀錄[/color]\n"
	for event: Dictionary in DataRegistry.story_events_for_route(selected_route_id):
		var found := GameState.has_story_discovery(selected_route_id, String(event.get("id", "")))
		text += "%s · %s\n%s\n" % [String(event.get("name", "調查點")), "已發現" if found else "未發現", String(event.get("revelation", "")) if found else String(event.get("objective", "尋找橘色事件標記，靠近調查點按 E。"))]
	text += "\n[color=#b6aa93]從村莊的%s出發。這張圖記錄旅程，地區仍須親自抵達探索。[/color]" % String(DataRegistry.get_wasteland_route(selected_route_id).get("name", "路線入口"))
	detail_label.text = text


func _route_quest(route_id: String) -> Dictionary:
	for quest: Dictionary in DataRegistry.quests:
		if bool(quest.get("main_campaign", false)) and String(quest.get("route", "")) == route_id:
			return quest
	return {}


func _route_name(route_id: String) -> String:
	var name_parts := String(DataRegistry.get_wasteland_route(route_id).get("name", route_id)).split("：")
	return name_parts[name_parts.size() - 1]


func _quest_status(quest: Dictionary) -> String:
	var quest_id := String(quest.get("id", ""))
	if GameState.completed_quests.has(quest_id):
		return "已完成"
	if GameState.active_quest_id == quest_id:
		if GameState.is_active_quest_ready():
			return "可交付" if GameState.can_deliver_quest_here() else "待返村交付"
		return "進行中"
	return "可承接" if GameState.quest_prerequisites_met(quest_id) else "前置未滿"


func _objectives(quest: Dictionary) -> String:
	var result := ""
	var quest_id := String(quest.get("id", ""))
	if not quest_id.is_empty() and GameState.active_quest_id == quest_id:
		return GameState.active_quest_requirements_text() + ("\n野外數字含本趟成果；成功返村才保留。" if GameState.has_active_expedition() else "")
	var completed := GameState.completed_quests.has(quest_id)
	for objective: Dictionary in quest.get("objectives", []):
		var amount := int(objective.get("amount", 1))
		match String(objective.get("type", "")):
			"defeat":
				var counter := String(objective.get("counter", "defeat_enemy"))
				var progress := amount if completed else int(GameState.quest_progress.get(counter, 0)) if GameState.active_quest_id == quest_id else 0
				result += "• %s %d / %d\n" % ["擊敗首領" if counter == "defeat_boss" else "擊退污染體", mini(progress, amount), amount]
			"collect":
				var item_id := String(objective.get("item", ""))
				var progress := amount if completed else int(GameState.inventory.get(item_id, 0))
				result += "• %s %d / %d\n" % [GameState.item_display_name(item_id), mini(progress, amount), amount]
			"discover":
				var found := GameState.has_story_discovery(String(objective.get("route", "")), String(objective.get("event", "")))
				result += "• %s：%s\n" % ["選讀現場線索" if bool(objective.get("optional", false)) else "調查現場線索", "已發現" if found else "未發現"]
	return result


func _region_button(route_id: String) -> Button:
	var button := Button.new()
	button.toggle_mode = true
	button.set_meta("route_id", route_id)
	button.add_to_group("world_atlas_route")
	button.tooltip_text = "%s：查看委託、前置條件與已知紀錄" % _route_name(route_id)
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", PAPER)
	button.add_theme_color_override("font_pressed_color", AMBER)
	button.add_theme_stylebox_override("normal", _style(Color("211e1d"), BRONZE))
	button.add_theme_stylebox_override("hover", _style(Color("342a20"), AMBER))
	button.add_theme_stylebox_override("pressed", _style(Color("3b2c1c"), AMBER, 2))
	button.add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0), AMBER, 2))
	button.pressed.connect(select_route.bind(route_id))
	return button


func _layout_markers() -> void:
	var illustration := Rect2(Vector2.ZERO, _map_canvas.size)
	if map_texture.texture != null:
		var texture_size := map_texture.texture.get_size()
		var ratio := minf(illustration.size.x / texture_size.x, illustration.size.y / texture_size.y)
		illustration.size = texture_size * ratio
		illustration.position = (_map_canvas.size - illustration.size) * 0.5
	for index in range(ROUTES.size()):
		var marker: Button = map_markers[ROUTES[index]]
		marker.position = illustration.position + illustration.size * MARKERS[index] - marker.size * 0.5


func _style(background: Color, border: Color, width := 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style
