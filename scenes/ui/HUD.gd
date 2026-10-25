extends CanvasLayer

const MAP_VIEW := preload("res://scripts/ui/WorldMapView.gd")
const PIXEL := preload("res://scripts/utils/PixelArtFactory.gd")
const ASSET_LOADER := preload("res://scripts/utils/RuntimeAssetLoader.gd")
const INVENTORY_SYSTEM := preload("res://scripts/systems/InventorySystem.gd")
const WORLD_ATLAS := preload("res://scripts/ui/WorldAtlasPanel.gd")
const UI_CHARCOAL := Color("171518")
const UI_BRONZE := Color("785b37")
const UI_AMBER := Color("e3b66b")
const UI_PAPER := Color("e3dac5")
const WORKSHOP_MIN_CARD_WIDTH := 420.0
const WORKSHOP_CARD_GAP := 14.0
const CONTROLS_HINT := "[WASD] 移動　[E] 互動　[Shift] 閃避　[G] 世界紀行　[M] 區域地圖"

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
var campaign_status_label: Label
var campaign_progress_bar: ProgressBar
var _campaign_status_timer := 0.0
var _campaign_status_blocked := false
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
var atlas_panel: PanelContainer
var expedition_draft_panel: PanelContainer
var expedition_draft_title: Label
var expedition_draft_build_label: Label
var expedition_draft_cards: GridContainer
var campaign_choice_panel: PanelContainer
var campaign_choice_title: Label
var campaign_choice_prompt: Label
var campaign_choice_options: VBoxContainer
var _campaign_choice_action_id := ""
var _campaign_choice_submitting := false
var notice_label: Label
var notice_timer: Timer
var minimap_panel: PanelContainer
var minimap_title: Label
var map_view
var tutorial_panel: PanelContainer
var tutorial_journey_label: Label
var tutorial_status_label: Label
var controls_hint: Label
var dialogue_panel: PanelContainer
var dialogue_portrait: TextureRect
var dialogue_speaker: Label
var dialogue_role: Label
var dialogue_body: Label
var dialogue_hint: Label
var dialogue_timer: Timer
var _dialogue_npc_owner: Node
var pause_panel: PanelContainer
var pause_status_label: Label
var pause_resume_button: Button
var pause_save_button: Button
var pause_load_button: Button
var pause_title_button: Button
var pause_exit_button: Button
var _pause_load_pending := false
var death_recovery_panel: PanelContainer
var death_recovery_status: Label
var death_retry_button: Button
var _viewport_layout_pending := false
var _inventory_stacked_layout := false
var map_open := true
var map_fullscreen := false
var workshop_active_tab := "craft"
var _workshop_scroll_tab := ""
var _workshop_card_width := 510.0
var _workshop_card_columns := 2
var _workshop_layout_source_width := -1.0
var _workshop_resize_refresh_queued := false
var _journal_signature := ""
var _story_paused_tree := false
var _journal_paused_tree := false
var _atlas_paused_tree := false
var _tutorial_paused_tree := false
var _draft_paused_tree := false
var _campaign_choice_paused_tree := false
var _last_world_region := ""

func _exit_tree() -> void:
	if _draft_paused_tree or _campaign_choice_paused_tree:
		get_tree().paused = _story_paused_tree or _journal_paused_tree or _atlas_paused_tree or _tutorial_paused_tree or (pause_panel != null and pause_panel.visible)
	elif _story_paused_tree or _journal_paused_tree or _atlas_paused_tree or _tutorial_paused_tree:
		get_tree().paused = false

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
	GameState.npc_dialogue_requested.connect(_show_npc_dialogue)
	GameState.npc_dialogue_closed.connect(_on_npc_dialogue_closed)
	SceneRouter.transition_finished.connect(_on_transition_finished)
	if not SaveManager.load_finished.is_connected(_on_save_load_finished):
		SaveManager.load_finished.connect(_on_save_load_finished)
	if GameState.has_signal("expedition_draft_changed"):
		GameState.connect("expedition_draft_changed", _on_expedition_draft_changed)
	if GameState.has_signal("campaign_choice_requested"):
		GameState.connect("campaign_choice_requested", _on_campaign_choice_requested)
	if GameState.has_signal("campaign_changed"):
		GameState.connect("campaign_changed", _on_campaign_changed)
	get_viewport().size_changed.connect(_schedule_viewport_layout)
	if get_window() != get_viewport():
		get_window().size_changed.connect(_schedule_viewport_layout)
	get_viewport().size_changed.connect(_refresh_workshop_after_layout)
	get_viewport().size_changed.connect(_fit_expedition_draft)
	get_viewport().size_changed.connect(_fit_campaign_choice)
	_refresh()
	_refresh_hotbar()
	_refresh_inventory()
	_refresh_overlay_visibility()
	_layout()
	call_deferred("_sync_campaign_choice")
	call_deferred("_sync_expedition_draft")

func _on_transition_finished(succeeded: bool) -> void:
	if succeeded:
		_sync_campaign_choice()
		_sync_expedition_draft()
	_update_notice_visibility()

func _process(_delta: float) -> void:
	if SceneRouter.is_transition_pending():
		if campaign_status_label != null and campaign_status_label.visible:
			_refresh_campaign_status()
		else:
			_set_campaign_status({})
		_update_notice_visibility()
		return
	_campaign_status_timer -= _delta
	if _campaign_status_timer <= 0.0:
		_campaign_status_timer = 0.25
		_refresh_campaign_status()
	_refresh_context_hint()
	if pause_panel.visible or (expedition_draft_panel != null and expedition_draft_panel.visible) or (campaign_choice_panel != null and campaign_choice_panel.visible):
		return
	if death_recovery_panel != null and death_recovery_panel.visible:
		return
	var region := String(get_parent().get_meta("current_region", ""))
	if region != _last_world_region:
		_last_world_region = region
		_refresh()
	if Input.is_action_just_pressed("open_inventory"):
		_set_inventory_visible(not inventory_panel.visible)
	if Input.is_action_just_pressed("toggle_minimap"):
		_toggle_map()
	if Input.is_action_just_pressed("toggle_help"):
		_set_tutorial_visible(not tutorial_panel.visible)

func _refresh_context_hint() -> void:
	if controls_hint == null:
		return
	var text := CONTROLS_HINT
	var player := get_tree().get_first_node_in_group("player")
	if is_instance_valid(player) and player.has_method("get_nearest_interaction_target"):
		var target: Node2D = player.call("get_nearest_interaction_target", false)
		if is_instance_valid(target) and target.has_method("get_screen_safe_prompt_text"):
			var context := String(target.call("get_screen_safe_prompt_text"))
			if not context.is_empty():
				text = context
	if controls_hint.text == text:
		return
	controls_hint.text = text
	controls_hint.add_theme_font_size_override("font_size", 14 if text != CONTROLS_HINT else 12)
	controls_hint.reset_size()
	_layout()

func _unhandled_input(event: InputEvent) -> void:
	if SceneRouter.is_transition_pending():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_PAGEUP, KEY_PAGEDOWN] and _scroll_active_modal(event.keycode):
			get_viewport().set_input_as_handled()
			return
		if death_recovery_panel != null and death_recovery_panel.visible and event.keycode == KEY_E:
			_retry_death_recovery()
			get_viewport().set_input_as_handled()
			return
		if campaign_choice_panel != null and campaign_choice_panel.visible:
			if event.keycode == KEY_ESCAPE:
				_dismiss_campaign_choice()
			get_viewport().set_input_as_handled()
			return
		if expedition_draft_panel != null and expedition_draft_panel.visible:
			if event.keycode == KEY_ESCAPE:
				_dismiss_expedition_draft()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_G and not pause_panel.visible:
			_set_atlas_visible(not atlas_panel.visible)
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ESCAPE:
			if atlas_panel != null and atlas_panel.visible:
				_set_atlas_visible(false)
				get_viewport().set_input_as_handled()
			elif inventory_panel.visible:
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

func _window_scale_x() -> float:
	return float(get_window().size.x) / maxf(1.0, get_viewport().get_visible_rect().size.x)

func _contract_font_size(base_size: int) -> int:
	var display_scale := clampf(_window_scale_x(), 0.75, 1.0)
	return ceili(float(base_size) / display_scale)

func _set_contract_font_size(control: Control, base_size: int) -> void:
	control.set_meta("contract_base_font_size", base_size)
	control.add_theme_font_size_override("font_size", _contract_font_size(base_size))

func _apply_contract_font_sizes(node: Node) -> void:
	if node is Control and (node as Control).has_meta("contract_base_font_size"):
		_set_contract_font_size(node as Control, int((node as Control).get_meta("contract_base_font_size")))
	for child: Node in node.get_children():
		_apply_contract_font_sizes(child)

func _inventory_available_display_width() -> float:
	var viewport_width := get_viewport().get_visible_rect().size.x
	return maxf(1.0, viewport_width - 68.0) * _window_scale_x()

func _terminal_grid_columns() -> int:
	if terminal_panel == null:
		return 1
	var available_display_width := maxf(1.0, terminal_panel.size.x - 48.0) * _window_scale_x()
	return 2 if available_display_width >= 760.0 else 1

func _layout() -> void:
	var size: Vector2 = get_viewport().get_visible_rect().size
	var window_width := float(get_window().size.x)
	var physical_scale_x := _window_scale_x()
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
		var q_expected_lines := 3
		if not _last_world_region.is_empty():
			q_expected_lines += 1
		if GameState.has_active_expedition() or GameState.is_legacy_expedition():
			q_expected_lines += 1
			if GameState.has_active_expedition():
				q_expected_lines += 1
		if not _campaign_summary_text().is_empty():
			q_expected_lines += 1
		var q_height := maxf(14.0 + float(q_expected_lines) * 14.0, quest_panel.get_combined_minimum_size().y)
		quest_panel.custom_minimum_size = Vector2(q_w, q_height)
		quest_panel.size = Vector2(q_w, q_height)
	var quick_bar_top: float = size.y - 64.0
	if quick_bar_panel != null:
		var quick_w := minf(520.0, size.x - 32.0)
		quick_bar_panel.custom_minimum_size = Vector2(quick_w, 0.0)
		var quick_height: float = quick_bar_panel.get_combined_minimum_size().y
		quick_bar_panel.custom_minimum_size = Vector2(quick_w, quick_height)
		quick_bar_panel.size = Vector2(quick_w, quick_height)
		quick_bar_top = size.y - quick_height - 8.0
		quick_bar_panel.position = Vector2(maxf(16.0, (size.x - quick_w) * 0.5), quick_bar_top)
	var nav_top: float = quick_bar_top - 40.0
	if nav_bar_panel != null:
		var nav_w := minf(676.0, size.x - 32.0)
		var nav_height: float = maxf(36.0, nav_bar_panel.get_combined_minimum_size().y)
		nav_top = quick_bar_top - nav_height - 4.0
		nav_bar_panel.position = Vector2(maxf(16.0, (size.x - nav_w) * 0.5), nav_top)
		nav_bar_panel.custom_minimum_size = Vector2(nav_w, nav_height)
		nav_bar_panel.size = Vector2(nav_w, nav_height)
	if controls_hint != null:
		var controls_min_size: Vector2 = controls_hint.get_combined_minimum_size()
		controls_hint.position = Vector2(maxf(16.0, (size.x - controls_min_size.x) * 0.5), nav_top - controls_min_size.y - 4.0)
	if dialogue_panel != null:
		var dialogue_size := Vector2(min(920.0, size.x - 48.0), min(248.0, size.y - 96.0))
		dialogue_panel.position = Vector2(max(24.0, (size.x - dialogue_size.x) * 0.5), size.y - dialogue_size.y - 12.0)
		dialogue_panel.custom_minimum_size = dialogue_size
		dialogue_panel.size = dialogue_size
		if dialogue_portrait != null:
			dialogue_portrait.custom_minimum_size.x = 96.0 if size.x < 1120.0 else 122.0
		if dialogue_body != null:
			dialogue_body.custom_minimum_size = Vector2(max(300.0, dialogue_size.x - 218.0), 0)
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
	for panel: PanelContainer in [inventory_panel, workshop_panel, contract_panel, terminal_panel, codex_panel, atlas_panel]:
		if panel != null:
			panel.position = modal_pos
			panel.custom_minimum_size = modal_size
			panel.size = modal_size
			var navigation := panel.get_node_or_null("ModalContentShell/ModalNavigation") as GridContainer
			if navigation != null:
				navigation.columns = 8 if window_width >= 1000.0 else 4
	if contract_panel != null and contract_list != null:
		var catalog_columns := 2 if (contract_panel.size.x - 48.0) * physical_scale_x >= 760.0 else 1
		for child: Node in contract_list.get_children():
			if child is GridContainer and child.name.begins_with("ContractCatalog_"):
				(child as GridContainer).columns = catalog_columns
		_apply_contract_font_sizes(contract_panel)
	if terminal_list != null:
		var terminal_columns := _terminal_grid_columns()
		for child: Node in terminal_list.get_children():
			if child is GridContainer and child.name in ["TerminalRouteGrid", "TerminalLockedGrid"]:
				(child as GridContainer).columns = terminal_columns
	if expedition_draft_panel != null:
		var draft_height := 460.0 if size.x >= 1000.0 else 660.0
		var draft_size := Vector2(maxf(1.0, minf(1040.0, size.x - 40.0)), maxf(1.0, minf(draft_height, size.y - 44.0)))
		expedition_draft_panel.position = Vector2(maxf(20.0, (size.x - draft_size.x) * 0.5), maxf(22.0, (size.y - draft_size.y) * 0.5))
		expedition_draft_panel.custom_minimum_size = draft_size
		expedition_draft_panel.size = draft_size
		if expedition_draft_cards != null:
			expedition_draft_cards.columns = 3 if size.x >= 1000.0 else 1
	if campaign_choice_panel != null:
		var choice_size := Vector2(maxf(1.0, minf(820.0, size.x - 48.0)), maxf(1.0, minf(500.0, size.y - 56.0)))
		campaign_choice_panel.position = Vector2(maxf(24.0, (size.x - choice_size.x) * 0.5), maxf(28.0, (size.y - choice_size.y) * 0.5))
		campaign_choice_panel.custom_minimum_size = choice_size
		campaign_choice_panel.size = choice_size
	if codex_list != null:
		var equipment_grid := codex_list.get_node_or_null("CodexEquipmentGrid") as GridContainer
		if equipment_grid != null:
			equipment_grid.columns = 2 if size.x < 1180.0 else 3
	if tutorial_panel != null:
		var tutorial_size: Vector2 = Vector2(min(760.0, size.x - 44.0), min(560.0, size.y - 110.0))
		tutorial_panel.position = Vector2(max(22.0, (size.x - tutorial_size.x) * 0.5), max(52.0, (size.y - tutorial_size.y) * 0.5))
		tutorial_panel.custom_minimum_size = tutorial_size
		tutorial_panel.size = tutorial_size
	if pause_panel != null:
		var pause_size := Vector2(minf(480.0, maxf(1.0, size.x - 48.0)), minf(440.0, maxf(1.0, size.y - 48.0)))
		pause_panel.position = Vector2(maxf(24.0, (size.x - pause_size.x) * 0.5), maxf(24.0, (size.y - pause_size.y) * 0.5))
		pause_panel.custom_minimum_size = pause_size
		pause_panel.size = pause_size
	if death_recovery_panel != null:
		var death_size := Vector2(minf(560.0, maxf(1.0, size.x - 48.0)), minf(276.0, maxf(1.0, size.y - 48.0)))
		death_recovery_panel.position = Vector2(maxf(24.0, (size.x - death_size.x) * 0.5), maxf(24.0, (size.y - death_size.y) * 0.5))
		death_recovery_panel.custom_minimum_size = death_size
		death_recovery_panel.size = death_size
	if notice_label != null:
		var notice_y: float = 136.0 if pause_panel != null and pause_panel.visible else 126.0
		if pause_panel == null or not pause_panel.visible:
			if quest_panel != null:
				notice_y = maxf(notice_y, quest_panel.position.y + quest_panel.size.y + 10.0)
			if minimap_panel != null and not map_fullscreen:
				notice_y = maxf(notice_y, minimap_panel.position.y + minimap_panel.size.y + 10.0)
		var notice_width := minf(760.0, maxf(1.0, size.x - 36.0))
		notice_label.size = Vector2(notice_width, 34.0)
		notice_label.position = Vector2((size.x - notice_width) * 0.5, notice_y)

func _schedule_viewport_layout() -> void:
	if _viewport_layout_pending:
		return
	_viewport_layout_pending = true
	_apply_viewport_layout.call_deferred()

func _apply_viewport_layout() -> void:
	await get_tree().process_frame
	_viewport_layout_pending = false
	if is_inside_tree():
		_layout()
		if inventory_panel != null and inventory_panel.visible:
			var available_width := _inventory_available_display_width()
			var should_stack := available_width < 940.0
			if should_stack != _inventory_stacked_layout:
				var scroll := inventory_list.get_parent() as ScrollContainer if inventory_list != null else null
				var previous_scroll := scroll.scroll_vertical if scroll != null else 0
				_refresh_inventory()
				if scroll != null:
					await get_tree().process_frame
					scroll.scroll_vertical = previous_scroll

func _build_hud() -> void:
	root = Control.new()
	root.name = "HudRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ui_theme := Theme.new()
	ui_theme.default_font_size = 14
	ui_theme.set_color("font_color", "Label", UI_PAPER)
	ui_theme.set_color("font_color", "Button", UI_PAPER)
	ui_theme.set_color("font_hover_color", "Button", UI_AMBER)
	ui_theme.set_stylebox("normal", "Button", _button_style(false))
	ui_theme.set_stylebox("hover", "Button", _button_style(true))
	ui_theme.set_stylebox("pressed", "Button", _button_style(true))
	ui_theme.set_stylebox("focus", "Button", _panel_style(Color(0, 0, 0, 0), UI_AMBER, 2))
	root.theme = ui_theme
	add_child(root)
	_build_status_panel()
	_build_quest_panel()
	_build_inventory_panel()
	_build_workshop_panel()
	_build_contract_panel()
	_build_terminal_panel()
	_build_codex_panel()
	_build_atlas_panel()
	_build_expedition_draft_panel()
	_build_campaign_choice_panel()
	_add_nav_bar()
	_add_quick_bar()
	_add_minimap()
	_add_tutorial()
	_add_controls_hint()
	_add_dialogue_box()
	_add_pause_menu()
	_add_death_recovery_panel()
	_add_notice_label()

func _build_status_panel() -> void:
	status_panel = PanelContainer.new()
	status_panel.name = "StatusPanel"
	status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st_style := _panel_style(Color(0.075, 0.067, 0.077, 0.94), UI_BRONZE, 1)
	st_style.border_width_top = 2
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
	var q_style := _panel_style(Color(0.075, 0.067, 0.077, 0.90), UI_BRONZE, 1)
	quest_panel.add_theme_stylebox_override("panel", q_style)
	root.add_child(quest_panel)
	var q_stack := VBoxContainer.new()
	q_stack.add_theme_constant_override("separation", 1)
	quest_panel.add_child(q_stack)
	quest_header_label = Label.new()
	quest_header_label.text = "◈ 村莊"
	quest_header_label.add_theme_font_size_override("font_size", 12)
	quest_header_label.add_theme_color_override("font_color", UI_AMBER)
	quest_header_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q_stack.add_child(quest_header_label)
	quest_label = Label.new()
	quest_label.add_theme_font_size_override("font_size", 11)
	quest_label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.88))
	quest_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	quest_label.add_theme_constant_override("shadow_offset_x", 1)
	quest_label.add_theme_constant_override("shadow_offset_y", 1)
	quest_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q_stack.add_child(quest_label)
	campaign_status_label = Label.new()
	campaign_status_label.name = "CampaignLiveStatus"
	campaign_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	campaign_status_label.add_theme_font_size_override("font_size", 14)
	campaign_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	campaign_status_label.hide()
	q_stack.add_child(campaign_status_label)
	campaign_progress_bar = _make_bar(UI_AMBER, Color(0.10, 0.09, 0.08, 0.90))
	campaign_progress_bar.name = "CampaignLiveProgress"
	campaign_progress_bar.step = 0.0
	campaign_progress_bar.custom_minimum_size = Vector2(0, 6)
	campaign_progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	campaign_progress_bar.hide()
	q_stack.add_child(campaign_progress_bar)

func _add_nav_bar() -> void:
	nav_bar_panel = PanelContainer.new()
	nav_bar_panel.name = "NavBarPanel"
	nav_bar_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var nb_style := _panel_style(Color(0.075, 0.067, 0.077, 0.97), UI_BRONZE, 1)
	nb_style.content_margin_top = 2
	nb_style.content_margin_bottom = 2
	nav_bar_panel.add_theme_stylebox_override("panel", nb_style)
	root.add_child(nav_bar_panel)
	nav_bar = HBoxContainer.new()
	nav_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	nav_bar.add_theme_constant_override("separation", 4)
	nav_bar_panel.add_child(nav_bar)
	var entries := [
		["[I] 裝備", func() -> void: _set_inventory_visible(true)],
		["[C] 工坊", func() -> void: _set_workshop_visible(true)],
		["[J] 委託", func() -> void: _set_contract_visible(true)],
		["[T] 終端", func() -> void: _set_terminal_visible(true)],
		["[K] 手記", func() -> void: _set_codex_visible(true)],
		["[G] 紀行", func() -> void: _set_atlas_visible(true)],
		["[M] 區域", func() -> void: set_fullscreen_map(true)],
		["[H] 說明", func() -> void: _set_tutorial_visible(true)],
	]
	for entry in entries:
		var btn := Button.new()
		btn.text = String(entry[0])
		btn.custom_minimum_size = Vector2(72, 28)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 11)
		btn.add_theme_color_override("font_color", Color(0.95, 0.90, 0.74))
		btn.add_theme_stylebox_override("normal", _button_style(false))
		btn.add_theme_stylebox_override("hover", _button_style(true))
		btn.pressed.connect(entry[1])
		nav_bar.add_child(btn)


func _build_modal_switcher(active_tab: String) -> GridContainer:
	var row := GridContainer.new()
	row.columns = 8 if get_window().size.x >= 1000 else 4
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	var tabs := [
		["inventory", "[I] 裝備", func() -> void: _set_inventory_visible(true)],
		["workshop", "[C] 工坊", func() -> void: _set_workshop_visible(true)],
		["contract", "[J] 委託", func() -> void: _set_contract_visible(true)],
		["terminal", "[T] 終端", func() -> void: _set_terminal_visible(true)],
		["codex", "[K] 手記", func() -> void: _set_codex_visible(true)],
		["atlas", "[G] 紀行", func() -> void: _set_atlas_visible(true)],
		["tutorial", "[H] 說明", func() -> void: _set_tutorial_visible(true)],
	]
	for t in tabs:
		var tab_id := String(t[0])
		var is_cur := tab_id == active_tab
		var btn := Button.new()
		btn.name = "ModalTab_%s" % tab_id
		btn.text = String(t[1])
		btn.custom_minimum_size = Vector2(0, 34)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var field_locked_workshop := tab_id == "workshop" and GameState.current_scene_id == "wasteland"
		btn.disabled = field_locked_workshop
		if field_locked_workshop:
			btn.text = "[C] 工坊"
			btn.tooltip_text = "出征期間不能使用工坊；請先經返村門回到村莊或公會。"
		btn.add_theme_font_size_override("font_size", 12)
		btn.add_theme_color_override("font_color", Color(1.0, 0.92, 0.52) if is_cur else Color(0.84, 0.86, 0.82))
		btn.add_theme_stylebox_override("normal", _button_style(is_cur))
		btn.add_theme_stylebox_override("hover", _button_style(true))
		btn.pressed.connect(t[2])
		row.add_child(btn)
	var close_btn := Button.new()
	close_btn.name = "ModalCloseButton"
	close_btn.text = "關閉 [Esc]"
	close_btn.custom_minimum_size = Vector2(0, 34)
	close_btn.add_theme_font_size_override("font_size", 12)
	close_btn.add_theme_color_override("font_color", Color(1.0, 0.68, 0.62))
	close_btn.add_theme_stylebox_override("normal", _button_style(false))
	close_btn.add_theme_stylebox_override("hover", _button_style(true))
	close_btn.pressed.connect(_close_all_modals)
	row.add_child(close_btn)
	return row

func _add_modal_navigation(panel: PanelContainer, scroll: ScrollContainer, active_tab: String) -> void:
	var shell := VBoxContainer.new()
	shell.name = "ModalContentShell"
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_theme_constant_override("separation", 8)
	panel.add_child(shell)
	var navigation := _build_modal_switcher(active_tab)
	navigation.name = "ModalNavigation"
	navigation.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.add_child(navigation)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	shell.add_child(scroll)

func _refresh_modal_navigation(panel: PanelContainer, active_tab: String) -> void:
	var shell := panel.get_node_or_null("ModalContentShell") as VBoxContainer
	if shell == null:
		return
	var old_navigation := shell.get_node_or_null("ModalNavigation")
	if old_navigation != null:
		shell.remove_child(old_navigation)
		old_navigation.queue_free()
	var navigation := _build_modal_switcher(active_tab)
	navigation.name = "ModalNavigation"
	navigation.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.add_child(navigation)
	shell.move_child(navigation, 0)

func _ensure_scroll_control_visible(control: Control) -> void:
	var ancestor: Node = control.get_parent()
	while ancestor != null and not ancestor is ScrollContainer:
		ancestor = ancestor.get_parent()
	if not ancestor is ScrollContainer:
		return
	var scroll := ancestor as ScrollContainer
	var visible_rect := scroll.get_global_rect()
	var control_rect := control.get_global_rect()
	var visible_top := visible_rect.position.y + 2.0
	var visible_bottom := visible_rect.end.y - 2.0
	if control_rect.position.y < visible_top:
		scroll.scroll_vertical = maxi(0, scroll.scroll_vertical - int(ceil(visible_top - control_rect.position.y)))
	elif control_rect.end.y > visible_bottom:
		scroll.scroll_vertical += int(ceil(control_rect.end.y - visible_bottom))

func _find_first_visible_scroll_container(node: Node) -> ScrollContainer:
	for child: Node in node.get_children():
		if child is ScrollContainer and (child as ScrollContainer).is_visible_in_tree():
			return child as ScrollContainer
		var nested := _find_first_visible_scroll_container(child)
		if nested != null:
			return nested
	return null

func _find_first_focusable_button(node: Node) -> Button:
	for child: Node in node.get_children():
		if not child is Control or not (child as Control).is_visible_in_tree():
			continue
		if child is Button:
			var button := child as Button
			if not button.disabled and button.focus_mode != Control.FOCUS_NONE:
				return button
		var nested := _find_first_focusable_button(child)
		if nested != null:
			return nested
	return null

func _focus_initial_modal_action(panel: Control) -> void:
	await get_tree().process_frame
	if not is_instance_valid(panel) or not panel.is_visible_in_tree():
		return
	var scroll := _find_first_visible_scroll_container(panel)
	var target: Button
	if panel == contract_panel:
		target = panel.find_child("ModalTab_contract", true, false) as Button
	if panel == contract_panel and scroll != null:
		scroll.scroll_vertical = 0
	if target == null:
		target = _find_first_focusable_button(scroll) if scroll != null else null
	if target == null:
		var navigation := panel.find_child("ModalNavigation", true, false) as Control
		if navigation != null:
			target = _find_first_focusable_button(navigation)
	if target == null:
		target = _find_first_focusable_button(panel)
	if target == null:
		return
	target.grab_focus()
	_ensure_scroll_control_visible(target)

func _scroll_active_modal(keycode: int) -> bool:
	var active_panels: Array[Control] = [
		dialogue_panel, tutorial_panel, campaign_choice_panel, expedition_draft_panel,
		pause_panel, inventory_panel, workshop_panel, contract_panel, terminal_panel,
		codex_panel, atlas_panel
	]
	for panel: Control in active_panels:
		if panel == null or not panel.is_visible_in_tree():
			continue
		var scroll := _find_first_visible_scroll_container(panel)
		if scroll == null:
			continue
		var scrollbar := scroll.get_v_scroll_bar()
		var maximum := maxi(0, floori(scrollbar.max_value - scrollbar.page))
		if maximum == 0:
			return false
		var page := maxi(48, floori(scroll.get_global_rect().size.y * 0.8))
		var delta := -page if keycode == KEY_PAGEUP else page
		scroll.scroll_vertical = clampi(scroll.scroll_vertical + delta, 0, maximum)
		return true
	return false

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
	if atlas_panel != null:
		atlas_panel.visible = false
	if expedition_draft_panel != null:
		expedition_draft_panel.visible = false
	if campaign_choice_panel != null:
		campaign_choice_panel.visible = false
	tutorial_panel.visible = false
	_refresh_overlay_visibility()

func _build_atlas_panel() -> void:
	atlas_panel = WORLD_ATLAS.new()
	atlas_panel.visible = false
	root.add_child(atlas_panel)
	atlas_panel.minimum_size_changed.connect(_layout)
	atlas_panel.call("set_navigation", _build_modal_switcher("atlas"))

func _build_expedition_draft_panel() -> void:
	expedition_draft_panel = PanelContainer.new()
	expedition_draft_panel.name = "ExpeditionDraftPanel"
	expedition_draft_panel.add_to_group("gameplay_input_blocker")
	expedition_draft_panel.set_meta("gameplay_input_blocked", false)
	expedition_draft_panel.z_index = 110
	expedition_draft_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	expedition_draft_panel.visible = false
	expedition_draft_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	expedition_draft_panel.clip_contents = true
	var draft_style := _panel_style(Color(0.035, 0.044, 0.050, 0.995), Color(0.53, 0.69, 0.58), 2)
	draft_style.border_width_top = 4
	expedition_draft_panel.add_theme_stylebox_override("panel", draft_style)
	root.add_child(expedition_draft_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	expedition_draft_panel.add_child(content)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	content.add_child(header)
	expedition_draft_title = Label.new()
	expedition_draft_title.text = "◈ 戰地調校"
	expedition_draft_title.add_theme_font_size_override("font_size", 23)
	expedition_draft_title.add_theme_color_override("font_color", UI_AMBER)
	expedition_draft_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	expedition_draft_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(expedition_draft_title)
	var close_button := Button.new()
	close_button.text = "稍後選擇 [Esc]"
	close_button.custom_minimum_size = Vector2(164.0, 38.0)
	close_button.focus_mode = Control.FOCUS_ALL
	close_button.add_theme_stylebox_override("normal", _button_style(false))
	close_button.add_theme_stylebox_override("hover", _button_style(true))
	close_button.pressed.connect(_dismiss_expedition_draft)
	header.add_child(close_button)

	var rules := Label.new()
	rules.text = "三選一｜借用據點的調校只在本趟生效；死亡或成功撤離後清除。無需貨幣、不會重抽。已有待選時會先完成先前調校；目前據點的選擇機會仍保留。之後的據點可再選同方案並疊加 +1；永久等級與本趟調校合計最高 Lv.5。"
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rules.add_theme_font_size_override("font_size", 13)
	rules.add_theme_color_override("font_color", UI_PAPER)
	content.add_child(rules)
	expedition_draft_build_label = Label.new()
	expedition_draft_build_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	expedition_draft_build_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	expedition_draft_build_label.add_theme_font_size_override("font_size", 13)
	expedition_draft_build_label.add_theme_color_override("font_color", Color(0.67, 0.88, 0.74))
	content.add_child(expedition_draft_build_label)

	var cards_viewport := Control.new()
	cards_viewport.name = "DraftOptionsViewport"
	cards_viewport.clip_contents = true
	cards_viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(cards_viewport)
	var cards_scroll := ScrollContainer.new()
	cards_scroll.name = "DraftOptionsScroll"
	cards_scroll.clip_contents = true
	cards_scroll.follow_focus = true
	cards_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cards_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	cards_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cards_viewport.add_child(cards_scroll)
	expedition_draft_cards = GridContainer.new()
	expedition_draft_cards.name = "DraftOptions"
	expedition_draft_cards.columns = 3
	expedition_draft_cards.add_theme_constant_override("h_separation", 8)
	expedition_draft_cards.add_theme_constant_override("v_separation", 8)
	expedition_draft_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	expedition_draft_cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards_scroll.add_child(expedition_draft_cards)

func _build_campaign_choice_panel() -> void:
	campaign_choice_panel = PanelContainer.new()
	campaign_choice_panel.name = "CampaignChoicePanel"
	campaign_choice_panel.add_to_group("gameplay_input_blocker")
	campaign_choice_panel.set_meta("gameplay_input_blocked", false)
	campaign_choice_panel.z_index = 120
	campaign_choice_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	campaign_choice_panel.visible = false
	campaign_choice_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	campaign_choice_panel.clip_contents = true
	campaign_choice_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.032, 0.039, 0.99), UI_AMBER, 2))
	root.add_child(campaign_choice_panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	campaign_choice_panel.add_child(content)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	content.add_child(header)
	campaign_choice_title = Label.new()
	campaign_choice_title.text = "章節行動選擇"
	campaign_choice_title.add_theme_font_size_override("font_size", 22)
	campaign_choice_title.add_theme_color_override("font_color", UI_AMBER)
	campaign_choice_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	campaign_choice_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(campaign_choice_title)
	var defer_button := Button.new()
	defer_button.text = "稍後決定 [Esc]"
	defer_button.custom_minimum_size = Vector2(156.0, 36.0)
	defer_button.focus_mode = Control.FOCUS_ALL
	defer_button.add_theme_stylebox_override("normal", _button_style(false))
	defer_button.add_theme_stylebox_override("hover", _button_style(true))
	defer_button.pressed.connect(_dismiss_campaign_choice)
	header.add_child(defer_button)
	campaign_choice_prompt = Label.new()
	campaign_choice_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	campaign_choice_prompt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	campaign_choice_prompt.add_theme_font_size_override("font_size", 16)
	campaign_choice_prompt.add_theme_color_override("font_color", UI_PAPER)
	content.add_child(campaign_choice_prompt)
	var options_scroll := ScrollContainer.new()
	options_scroll.name = "CampaignChoiceOptionsScroll"
	options_scroll.clip_contents = true
	options_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	options_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	options_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(options_scroll)
	campaign_choice_options = VBoxContainer.new()
	campaign_choice_options.name = "CampaignChoiceOptions"
	campaign_choice_options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	campaign_choice_options.add_theme_constant_override("separation", 8)
	options_scroll.add_child(campaign_choice_options)
	var footer := Label.new()
	footer.text = "選擇會記入本章行動；按稍後決定會保留選項，不會替你作答。"
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.add_theme_font_size_override("font_size", 12)
	footer.add_theme_color_override("font_color", Color(0.70, 0.83, 0.78))
	content.add_child(footer)

func _sync_campaign_choice() -> void:
	if SceneRouter.is_transition_pending():
		return
	if campaign_choice_panel == null or not GameState.has_method("campaign_choice_state"):
		return
	if pause_panel != null and pause_panel.visible and not campaign_choice_panel.visible:
		return
	var value: Variant = GameState.call("campaign_choice_state")
	var state: Dictionary = value if value is Dictionary else {}
	var action_id := String(state.get("action_id", ""))
	if action_id.is_empty():
		if campaign_choice_panel.visible:
			campaign_choice_panel.visible = false
			_campaign_choice_action_id = ""
			_campaign_choice_submitting = false
			_refresh_overlay_visibility()
			call_deferred("_sync_expedition_draft")
		return
	_campaign_choice_action_id = action_id
	if not campaign_choice_panel.visible:
		_close_overlays_for_campaign_choice()
		campaign_choice_panel.visible = true
		if dialogue_panel != null and dialogue_panel.visible:
			_hide_dialogue()
	_refresh_campaign_choice(state)
	_refresh_overlay_visibility()
	call_deferred("_focus_first_campaign_choice")
	call_deferred("_fit_campaign_choice")

func _close_overlays_for_campaign_choice() -> void:
	for panel: Control in [inventory_panel, workshop_panel, contract_panel, terminal_panel, codex_panel, atlas_panel, expedition_draft_panel, tutorial_panel]:
		if panel != null:
			panel.visible = false
	map_fullscreen = false

func _refresh_campaign_choice(state: Dictionary) -> void:
	if campaign_choice_title == null or campaign_choice_prompt == null or campaign_choice_options == null:
		return
	campaign_choice_title.text = String(state.get("name", "本章行動選擇"))
	campaign_choice_prompt.text = String(state.get("prompt", "選擇接下來的處置方式。稍後決定會保留本次選項。"))
	for child: Node in campaign_choice_options.get_children():
		campaign_choice_options.remove_child(child)
		child.queue_free()
	var action_id := String(state.get("action_id", ""))
	var first_button: Button
	for option_value in state.get("options", []):
		if not option_value is Dictionary:
			continue
		var option: Dictionary = option_value
		var option_id := String(option.get("id", ""))
		if option_id.is_empty():
			continue
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", _panel_style(Color(0.065, 0.075, 0.079, 0.98), Color(0.38, 0.51, 0.47, 0.96), 1))
		campaign_choice_options.add_child(card)
		var stack := VBoxContainer.new()
		stack.add_theme_constant_override("separation", 4)
		stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_child(stack)
		var option_name := Label.new()
		option_name.text = String(option.get("name", option_id))
		option_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		option_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option_name.add_theme_font_size_override("font_size", 17)
		option_name.add_theme_color_override("font_color", Color(0.98, 0.86, 0.55))
		stack.add_child(option_name)
		var description := Label.new()
		description.text = String(option.get("description", ""))
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		description.add_theme_color_override("font_color", UI_PAPER)
		stack.add_child(description)
		var choose_button := Button.new()
		choose_button.name = "ChooseCampaignOptionButton"
		choose_button.text = "選擇：%s" % option_name.text
		choose_button.custom_minimum_size = Vector2(170.0, 36.0)
		choose_button.size_flags_horizontal = Control.SIZE_SHRINK_END
		choose_button.focus_mode = Control.FOCUS_ALL
		choose_button.add_theme_stylebox_override("normal", _button_style(false))
		choose_button.add_theme_stylebox_override("hover", _button_style(true))
		choose_button.pressed.connect(_complete_campaign_choice.bind(action_id, option_id))
		stack.add_child(choose_button)
		if first_button == null:
			first_button = choose_button
	if campaign_choice_options.get_child_count() == 0:
		var empty_label := Label.new()
		empty_label.text = "目前沒有可顯示的處置選項；本次行動仍保留，請稍後再開啟。"
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		campaign_choice_options.add_child(empty_label)
	if first_button != null:
		first_button.call_deferred("grab_focus")

func _fit_campaign_choice() -> void:
	for layout_pass in range(2):
		await get_tree().process_frame
		if campaign_choice_panel == null or not campaign_choice_panel.visible:
			return
		_layout()

func _focus_first_campaign_choice() -> void:
	if campaign_choice_panel == null or not campaign_choice_panel.visible or campaign_choice_options == null:
		return
	for card: Node in campaign_choice_options.get_children():
		var button := card.find_child("ChooseCampaignOptionButton", true, false) as Button
		if button != null:
			button.grab_focus()
			return

func _has_pending_campaign_choice() -> bool:
	if not GameState.has_method("campaign_choice_state"):
		return false
	var value: Variant = GameState.call("campaign_choice_state")
	return value is Dictionary and not String(value.get("action_id", "")).is_empty()

func _on_campaign_choice_requested(_action_id: String) -> void:
	_sync_campaign_choice()

func _on_campaign_changed() -> void:
	_refresh()
	if campaign_choice_panel != null and campaign_choice_panel.visible:
		_sync_campaign_choice()
	if contract_panel != null and contract_panel.visible:
		_refresh_contracts()
	if codex_panel != null and codex_panel.visible:
		_refresh_codex()

func _complete_campaign_choice(action_id: String, option_id: String) -> void:
	if campaign_choice_panel == null or not campaign_choice_panel.visible or _campaign_choice_action_id != action_id or _campaign_choice_submitting or action_id.is_empty() or option_id.is_empty() or not GameState.has_method("campaign_choice_state") or not GameState.has_method("complete_campaign_action"):
		return
	var value: Variant = GameState.call("campaign_choice_state")
	if not value is Dictionary or String(value.get("action_id", "")) != action_id:
		_sync_campaign_choice()
		return
	var found := false
	for option_value in value.get("options", []):
		if option_value is Dictionary and String(option_value.get("id", "")) == option_id:
			found = true
			break
	if not found:
		_sync_campaign_choice()
		return
	_campaign_choice_submitting = true
	var completed := bool(GameState.call("complete_campaign_action", action_id, option_id))
	_campaign_choice_submitting = false
	if completed:
		campaign_choice_panel.visible = false
		_campaign_choice_action_id = ""
		_refresh_overlay_visibility()
		_refresh()
		call_deferred("_sync_expedition_draft")
	else:
		_sync_campaign_choice()

func _dismiss_campaign_choice() -> void:
	if campaign_choice_panel == null or not campaign_choice_panel.visible:
		return
	campaign_choice_panel.visible = false
	_campaign_choice_action_id = ""
	_campaign_choice_submitting = false
	_refresh_overlay_visibility()
	call_deferred("_sync_expedition_draft")

func _sync_expedition_draft() -> void:
	if SceneRouter.is_transition_pending():
		return
	if expedition_draft_panel == null or not GameState.has_method("expedition_draft_state"):
		return
	if _has_pending_campaign_choice():
		if expedition_draft_panel.visible:
			expedition_draft_panel.visible = false
			_refresh_overlay_visibility()
		return
	var state: Dictionary = GameState.call("expedition_draft_state")
	var pending := String(state.get("pending", ""))
	if pending.is_empty():
		if expedition_draft_panel.visible:
			expedition_draft_panel.visible = false
			_refresh_overlay_visibility()
		return
	if not expedition_draft_panel.visible:
		_close_all_modals()
		if dialogue_panel != null and dialogue_panel.visible:
			_hide_dialogue()
		map_fullscreen = false
		expedition_draft_panel.visible = true
	_refresh_expedition_draft(state)
	_refresh_overlay_visibility()
	call_deferred("_focus_first_expedition_draft_option")
	call_deferred("_fit_expedition_draft")

func _fit_expedition_draft() -> void:
	# Wrapped labels briefly report a tall minimum before their first width pass.
	for layout_pass in range(2):
		await get_tree().process_frame
		if expedition_draft_panel == null or not expedition_draft_panel.visible:
			return
		_layout()

func _refresh_expedition_draft(state: Dictionary) -> void:
	if expedition_draft_title == null or expedition_draft_cards == null:
		return
	var site_name := String(state.get("site_name", "戰地據點"))
	expedition_draft_title.text = "◈ %s｜選擇本趟調校" % site_name
	if GameState.has_method("expedition_build_summary"):
		var build_summary := String(GameState.call("expedition_build_summary"))
		expedition_draft_build_label.text = build_summary.replace("｜尚有待選，回調校據點按 E", "")
	else:
		expedition_draft_build_label.text = "本趟調校：尚未選擇"
	for child: Node in expedition_draft_cards.get_children():
		child.queue_free()
	var choices: Dictionary = state.get("choices", {})
	var options: Array = state.get("options", [])
	var first_choice_button: Button
	for option_value in options:
		if not option_value is Dictionary:
			continue
		var option: Dictionary = option_value
		var package_id := String(option.get("id", ""))
		if package_id.is_empty():
			continue
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", _panel_style(Color(0.075, 0.083, 0.084, 0.98), Color(0.32, 0.43, 0.39, 0.92), 1))
		expedition_draft_cards.add_child(card)
		var card_content := VBoxContainer.new()
		card_content.add_theme_constant_override("separation", 4)
		card_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_child(card_content)
		var name_label := Label.new()
		name_label.text = String(option.get("name", package_id))
		name_label.add_theme_font_size_override("font_size", 18)
		name_label.add_theme_color_override("font_color", Color(0.98, 0.86, 0.55))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card_content.add_child(name_label)
		var prior_stacks := 0
		for chosen_value in choices.values():
			if String(chosen_value) == package_id:
				prior_stacks += 1
		if prior_stacks > 0:
			var stack_label := Label.new()
			stack_label.text = "本趟已選 %d 次｜再選 +1" % prior_stacks
			stack_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			stack_label.add_theme_font_size_override("font_size", 12)
			stack_label.add_theme_color_override("font_color", Color(0.68, 0.86, 0.73))
			stack_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			card_content.add_child(stack_label)
		var description := Label.new()
		description.text = String(option.get("description", ""))
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		description.add_theme_color_override("font_color", UI_PAPER)
		card_content.add_child(description)
		var effects: Array[String] = []
		for effect_value in option.get("effects", []):
			var effect := String(effect_value)
			if not effect.is_empty():
				effects.append("• " + effect)
		var effect_label := Label.new()
		effect_label.text = "本次效果：\n%s" % "\n".join(effects)
		effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		effect_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		effect_label.add_theme_font_size_override("font_size", 13)
		effect_label.add_theme_color_override("font_color", Color(0.72, 0.91, 0.80))
		card_content.add_child(effect_label)
		var tradeoff := Label.new()
		tradeoff.text = "代價：%s" % String(option.get("tradeoff", ""))
		tradeoff.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tradeoff.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tradeoff.add_theme_font_size_override("font_size", 13)
		tradeoff.add_theme_color_override("font_color", Color(0.90, 0.72, 0.66))
		card_content.add_child(tradeoff)
		var choose_button := Button.new()
		choose_button.name = "ChooseDraftButton"
		choose_button.text = "選擇此方案"
		choose_button.custom_minimum_size = Vector2(142.0, 34.0)
		choose_button.size_flags_horizontal = Control.SIZE_SHRINK_END
		choose_button.focus_mode = Control.FOCUS_ALL
		choose_button.add_theme_stylebox_override("normal", _button_style(false))
		choose_button.add_theme_stylebox_override("hover", _button_style(true))
		choose_button.pressed.connect(_choose_expedition_draft.bind(package_id))
		card_content.add_child(choose_button)
		if first_choice_button == null:
			first_choice_button = choose_button
	if options.is_empty():
		var empty_label := Label.new()
		empty_label.text = "目前沒有可顯示的調校方案；待選內容仍保留，請稍後回到據點。"
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		expedition_draft_cards.add_child(empty_label)
	var scroll := expedition_draft_cards.get_parent() as ScrollContainer
	if scroll != null:
		scroll.scroll_vertical = 0
	if first_choice_button != null:
		first_choice_button.call_deferred("grab_focus")

func _focus_first_expedition_draft_option() -> void:
	if expedition_draft_panel == null or not expedition_draft_panel.visible or expedition_draft_cards == null:
		return
	for card: Node in expedition_draft_cards.get_children():
		var button := card.find_child("ChooseDraftButton", true, false) as Button
		if button != null:
			button.grab_focus()
			return

func _on_expedition_draft_changed() -> void:
	_sync_expedition_draft()
	_refresh()
	if inventory_panel != null and inventory_panel.visible:
		_refresh_inventory()

func _choose_expedition_draft(package_id: String) -> void:
	if not GameState.has_method("choose_expedition_draft"):
		return
	if not bool(GameState.call("choose_expedition_draft", package_id)):
		_sync_expedition_draft()

func _dismiss_expedition_draft() -> void:
	if expedition_draft_panel == null or not expedition_draft_panel.visible:
		return
	expedition_draft_panel.visible = false
	_refresh_overlay_visibility()

func _set_atlas_visible(is_visible: bool) -> void:
	if atlas_panel == null:
		return
	var was_visible := atlas_panel.visible
	if is_visible:
		if pause_panel.visible:
			_set_pause_visible(false)
		_close_all_modals()
		_hide_dialogue()
		map_fullscreen = false
	atlas_panel.visible = is_visible
	if is_visible:
		atlas_panel.call("refresh")
	_refresh_overlay_visibility()
	if is_visible and not was_visible:
		call_deferred("_focus_initial_modal_action", atlas_panel)

func _build_inventory_panel() -> void:
	inventory_panel = PanelContainer.new()
	inventory_panel.name = "InventoryPanel"
	inventory_panel.add_to_group("equipment_panel")
	inventory_panel.add_to_group("gameplay_input_blocker")
	inventory_panel.set_meta("gameplay_input_blocked", false)
	inventory_panel.z_index = 60
	inventory_panel.visible = false
	inventory_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	inventory_panel.add_theme_stylebox_override("panel", _panel_style(UI_CHARCOAL, UI_BRONZE, 2))
	root.add_child(inventory_panel)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "InventoryScroll"
	scroll.clip_contents = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inventory_list = VBoxContainer.new()
	inventory_list.add_theme_constant_override("separation", 10)
	inventory_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(inventory_list)
	_add_modal_navigation(inventory_panel, scroll, "inventory")

func _build_workshop_panel() -> void:
	workshop_panel = PanelContainer.new()
	workshop_panel.name = "WorkshopPanel"
	workshop_panel.add_to_group("workshop_panel")
	workshop_panel.add_to_group("gameplay_input_blocker")
	workshop_panel.set_meta("gameplay_input_blocked", false)
	workshop_panel.z_index = 60
	workshop_panel.visible = false
	workshop_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	workshop_panel.add_theme_stylebox_override("panel", _panel_style(UI_CHARCOAL, UI_BRONZE, 2))
	root.add_child(workshop_panel)
	var scroll := ScrollContainer.new()
	scroll.name = "WorkshopScroll"
	scroll.clip_contents = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workshop_list = VBoxContainer.new()
	workshop_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workshop_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workshop_list.add_theme_constant_override("separation", 10)
	scroll.add_child(workshop_list)
	_add_modal_navigation(workshop_panel, scroll, "workshop")

func _build_contract_panel() -> void:
	contract_panel = PanelContainer.new()
	contract_panel.name = "ContractPanel"
	contract_panel.add_to_group("contract_panel")
	contract_panel.add_to_group("gameplay_input_blocker")
	contract_panel.set_meta("gameplay_input_blocked", false)
	contract_panel.z_index = 60
	contract_panel.visible = false
	contract_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	contract_panel.add_theme_stylebox_override("panel", _panel_style(UI_CHARCOAL, UI_BRONZE, 2))
	root.add_child(contract_panel)
	var scroll := ScrollContainer.new()
	scroll.name = "ContractScroll"
	scroll.clip_contents = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contract_list = VBoxContainer.new()
	contract_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contract_list.add_theme_constant_override("separation", 10)
	scroll.add_child(contract_list)
	_add_modal_navigation(contract_panel, scroll, "contract")

func _build_terminal_panel() -> void:
	terminal_panel = PanelContainer.new()
	terminal_panel.name = "TerminalPanel"
	terminal_panel.add_to_group("terminal_panel")
	terminal_panel.add_to_group("gameplay_input_blocker")
	terminal_panel.set_meta("gameplay_input_blocked", false)
	terminal_panel.z_index = 60
	terminal_panel.visible = false
	terminal_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	terminal_panel.add_theme_stylebox_override("panel", _panel_style(UI_CHARCOAL, UI_BRONZE, 2))
	root.add_child(terminal_panel)
	var scroll := ScrollContainer.new()
	scroll.clip_contents = true
	terminal_list = VBoxContainer.new()
	terminal_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	terminal_list.add_theme_constant_override("separation", 10)
	scroll.add_child(terminal_list)
	_add_modal_navigation(terminal_panel, scroll, "terminal")

func _build_codex_panel() -> void:
	codex_panel = PanelContainer.new()
	codex_panel.name = "CodexPanel"
	codex_panel.add_to_group("codex_panel")
	codex_panel.add_to_group("gameplay_input_blocker")
	codex_panel.set_meta("gameplay_input_blocked", false)
	codex_panel.z_index = 60
	codex_panel.visible = false
	codex_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	codex_panel.add_theme_stylebox_override("panel", _panel_style(UI_CHARCOAL, UI_BRONZE, 2))
	root.add_child(codex_panel)
	var scroll := ScrollContainer.new()
	scroll.clip_contents = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	codex_list = VBoxContainer.new()
	codex_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	codex_list.add_theme_constant_override("separation", 10)
	scroll.add_child(codex_list)
	_add_modal_navigation(codex_panel, scroll, "codex")

func _add_quick_bar() -> void:
	quick_bar_panel = PanelContainer.new()
	quick_bar_panel.name = "QuickBar"
	quick_bar_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var qb_style := _panel_style(UI_CHARCOAL, UI_BRONZE, 2)
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
	var mm_style := _panel_style(Color(0.075, 0.067, 0.077, 0.90), UI_BRONZE, 1)
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
	map_view.custom_minimum_size = Vector2(110, 100)
	map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
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

	var panel_stack := VBoxContainer.new()
	panel_stack.add_theme_constant_override("separation", 8)
	tutorial_panel.add_child(panel_stack)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 10)
	panel_stack.add_child(header_row)
	var header := Label.new()
	header.text = "◈ 遊戲說明與戰術指南 [H]｜暫停"
	header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_font_size_override("font_size", 20)
	header.add_theme_color_override("font_color", Color(0.98, 0.84, 0.42))
	header_row.add_child(header)
	var close_btn := Button.new()
	close_btn.name = "TutorialCloseButton"
	close_btn.text = "關閉 [H / Esc]"
	close_btn.custom_minimum_size = Vector2(136, 36)
	close_btn.pressed.connect(func() -> void: _set_tutorial_visible(false))
	header_row.add_child(close_btn)

	var scroll := ScrollContainer.new()
	scroll.name = "TutorialScroll"
	scroll.clip_contents = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel_stack.add_child(scroll)
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)

	var sec_ops := _make_section_box(vbox, "• 基本操作")
	var ops_grid := GridContainer.new()
	ops_grid.name = "TutorialControlsGrid"
	ops_grid.columns = 2
	ops_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ops_grid.add_theme_constant_override("h_separation", 18)
	ops_grid.add_theme_constant_override("v_separation", 6)
	sec_ops.add_child(ops_grid)
	for pair in [
		["[W] [A] [S] [D]", "移動（八個方向）"],
		["滑鼠左鍵", "使用目前快捷欄武裝；依武裝執行近戰、遠程或工具動作。"],
		["滑鼠右鍵", "遠程攻擊快捷輸入。"],
		["[Space]", "近戰攻擊。"],
		["[Shift]", "移動時按下可閃避（消耗 6 EP）；持續按住並移動可衝刺（每秒消耗 10 EP）。"],
		["[E]", "與 NPC、工作站和路線閘門互動。"],
		["[1]–[4] / [Q]", "選擇快捷欄，或切換至下一格。"],
		["[I]；[C]", "人物裝備；工坊。Tab 瀏覽目前畫面，Esc 關閉面板。"],
		["[J] / [K]", "公會委託 / 回收者手記。"],
		["[G] / [M] / [T] / [H]", "世界紀行 / 區域地圖 / 戰術終端 / 本說明。地圖只供查看，不會傳送。"],
		["[PageUp / PageDown]", "在目前面板逐頁捲動；也可使用滑鼠滾輪。"],
		["[F5] / [F9]", "快速儲存 / 讀取存檔。"],
		["[Esc]", "關閉目前面板；沒有面板時開啟暫停選單。"],
	]:
		var k_lbl := Label.new()
		k_lbl.text = String(pair[0])
		k_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		k_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		k_lbl.add_theme_font_size_override("font_size", 14)
		k_lbl.add_theme_color_override("font_color", Color(0.98, 0.86, 0.44))
		ops_grid.add_child(k_lbl)
		var v_lbl := Label.new()
		v_lbl.text = String(pair[1])
		v_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v_lbl.add_theme_font_size_override("font_size", 14)
		v_lbl.add_theme_color_override("font_color", Color(0.92, 0.92, 0.88))
		ops_grid.add_child(v_lbl)

	var sec_journey := _make_section_box(vbox, "• 目前旅程")
	tutorial_journey_label = Label.new()
	tutorial_journey_label.name = "TutorialJourneyLabel"
	tutorial_journey_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tutorial_journey_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tutorial_journey_label.add_theme_font_size_override("font_size", 14)
	sec_journey.add_child(tutorial_journey_label)

	var sec_flow := _make_section_box(vbox, "• 遠征流程")
	var flow_list := VBoxContainer.new()
	flow_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow_list.add_theme_constant_override("separation", 5)
	sec_flow.add_child(flow_list)
	for step_text in [
		"1. 在村莊或公會按 [J] 承接一項委託；同一時間只有一項有效委託。",
		"2. 用 [M] 查看路線，走到地圖標示的出擊閘門按 [E] 出發。",
		"3. 在廢土完成目前行動與委託目標；路線上標記的戰地調校點可選擇，最多每趟兩處。",
		"4. 用 [M] 找返村閘門並按 [E] 撤離；只有成功進入村莊才會入庫本趟收穫和已完成步驟。",
		"5. 每章主線有兩趟指定行動，也保留原委託目標。可分趟帶回已完成步驟；全部目標完成後，仍須在村莊或公會按 [J] 交付一次並領取報酬。"
	]:
		var step_label := Label.new()
		step_label.text = String(step_text)
		step_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		step_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		step_label.add_theme_font_size_override("font_size", 14)
		flow_list.add_child(step_label)

	var sec_status := _make_section_box(vbox, "• 本趟收穫與進度")
	tutorial_status_label = Label.new()
	tutorial_status_label.name = "TutorialStatusLabel"
	tutorial_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tutorial_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tutorial_status_label.add_theme_font_size_override("font_size", 14)
	tutorial_status_label.add_theme_color_override("font_color", Color(0.90, 0.92, 0.88))
	sec_status.add_child(tutorial_status_label)

	var sec_tips := _make_section_box(vbox, "• 章節與永久進度")
	var tips_txt := Label.new()
	tips_txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tips_txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tips_txt.add_theme_font_size_override("font_size", 14)
	tips_txt.add_theme_color_override("font_color", Color(0.82, 0.94, 0.78))
	tips_txt.text = "• 前四章主線可自由選擇順序，前四章線索為選讀；都心章需完成前四章，設施章需先完成都心章，這兩章的指定線索屬必要目標。\n• [K] 會保留已發現線索；新制出征尚未帶回的線索仍須從原路線安全撤離，才計入委託。\n• 每趟最多兩個戰地調校選擇，其臨時加成於安全撤離或死亡後清除。\n• 第一條主線交付後，供水只會有限恢復；沒有缺水倒數，後續供水依後續交付推進。\n• 非衝刺或閃避時每秒回復 4 EP，普通行走也會回復；合成、鍛造與永久強化服務在村莊或公會進行。"
	sec_tips.add_child(tips_txt)
	_refresh_tutorial_rules()

func _refresh_tutorial_rules() -> void:
	if tutorial_journey_label != null:
		tutorial_journey_label.text = GameState.get_journey_hint()
	if tutorial_status_label == null:
		return
	if GameState.is_legacy_expedition():
		tutorial_status_label.text = "舊版在途存檔：首次返村前仍沿用即時保留規則，已發現線索也會立即計入目標；死亡不會套用新制的本趟收穫與進度損失。首次返村後的新出征才採新制。"
	else:
		tutorial_status_label.text = "新制出征的本趟收穫與尚未帶回的委託步驟暫存；只有返村閘門成功進入村莊才會入庫。安全撤離帶回已完成步驟，未完成的計時、護送與搬運下次重來；死亡會失去本趟未入庫收穫與暫存步驟。已入庫物資、裝備、經驗與已發現線索保留；線索任務成果仍須從原路線安全撤離。"

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
	controls_hint.text = CONTROLS_HINT
	controls_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	controls_hint.add_theme_font_size_override("font_size", 12)
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
	dialogue_panel.set_meta("dialogue_npc_owner_id", 0)
	dialogue_panel.custom_minimum_size = Vector2(920, 248)
	dialogue_panel.z_index = 90
	dialogue_panel.visible = false
	dialogue_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var dlg_style := _panel_style(Color(0.042, 0.048, 0.058, 0.995), Color(0.96, 0.72, 0.28, 0.98), 2)
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
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	var dialogue_scroll := ScrollContainer.new()
	dialogue_scroll.name = "DialogueScroll"
	dialogue_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dialogue_scroll.custom_minimum_size.y = 110
	dialogue_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(dialogue_scroll)
	dialogue_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialogue_scroll.add_child(dialogue_body)
	dialogue_hint = Label.new()
	dialogue_hint.text = "[E] NPC 下一段 ｜ [Esc] 關閉 ｜ 滾輪閱讀 ｜ [K] 回收者手記"
	dialogue_hint.add_theme_font_size_override("font_size", 12)
	dialogue_hint.add_theme_color_override("font_color", Color(0.68, 0.74, 0.72))
	stack.add_child(dialogue_hint)
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
	var scroll := ScrollContainer.new()
	scroll.name = "PauseScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = true
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(scroll)
	var buttons := VBoxContainer.new()
	buttons.name = "PauseButtons"
	buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.size_flags_vertical = Control.SIZE_EXPAND_FILL
	buttons.add_theme_constant_override("separation", 8)
	scroll.add_child(buttons)
	pause_status_label = Label.new()
	pause_status_label.name = "PauseStatusLabel"
	pause_status_label.text = "Esc 可關閉暫停。返回標題或退出不會自動儲存；手動儲存只記錄目前狀態，不會提前結算本趟收穫。"
	pause_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pause_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pause_status_label.add_theme_font_size_override("font_size", 14)
	pause_status_label.add_theme_color_override("font_color", Color(0.82, 0.82, 0.76))
	buttons.add_child(pause_status_label)
	pause_resume_button = _add_pause_button(buttons, "繼續遊戲", _resume_or_retry_recovery)
	pause_save_button = _add_pause_button(buttons, "儲存進度", _save_from_pause)
	pause_load_button = _add_pause_button(buttons, "讀取存檔", _load_from_pause)
	pause_title_button = _add_pause_button(buttons, "返回標題", _return_to_title)
	pause_exit_button = _add_pause_button(buttons, "退出遊戲", _quit_from_pause)

func _add_death_recovery_panel() -> void:
	death_recovery_panel = PanelContainer.new()
	death_recovery_panel.name = "DeathRecoveryPanel"
	death_recovery_panel.add_to_group("gameplay_input_blocker")
	death_recovery_panel.set_meta("gameplay_input_blocked", false)
	death_recovery_panel.z_index = 95
	death_recovery_panel.visible = false
	death_recovery_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	death_recovery_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.015, 0.018, 0.018, 0.97), Color(0.82, 0.58, 0.24, 0.98), 2))
	root.add_child(death_recovery_panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	death_recovery_panel.add_child(stack)
	var title := Label.new()
	title.text = "R-17 機體停機"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", UI_AMBER)
	stack.add_child(title)
	death_recovery_status = Label.new()
	death_recovery_status.name = "DeathRecoveryStatus"
	death_recovery_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	death_recovery_status.custom_minimum_size = Vector2(0, 72)
	death_recovery_status.add_theme_font_size_override("font_size", 15)
	death_recovery_status.add_theme_color_override("font_color", UI_PAPER)
	stack.add_child(death_recovery_status)
	death_retry_button = Button.new()
	death_retry_button.name = "DeathRetryButton"
	death_retry_button.text = "立即返回維修艙"
	death_retry_button.custom_minimum_size = Vector2(0, 46)
	death_retry_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	death_retry_button.add_theme_stylebox_override("normal", _button_style(true))
	death_retry_button.add_theme_stylebox_override("hover", _button_style(true))
	death_retry_button.pressed.connect(_retry_death_recovery)
	stack.add_child(death_retry_button)
	var hint := Label.new()
	hint.text = "按 [E] 立即回收　｜　按 [Esc] 開啟暫停選單"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.72, 0.74, 0.70))
	stack.add_child(hint)

func _retry_death_recovery() -> void:
	if GameState.retry_death_recovery():
		death_recovery_status.text = "回收程序已啟動，正送往村莊維修艙。"
		death_retry_button.disabled = true
		return
	death_recovery_status.text = "回收程序目前無法啟動。按 [Esc] 開啟暫停選單重試或返回標題。"

func _update_death_recovery_panel() -> void:
	if death_recovery_panel == null:
		return
	var death_pending := GameState.current_scene_id == "wasteland" and (GameState.death_pending or GameState.hp <= 0)
	var show_panel := death_pending and not SceneRouter.is_transition_pending() and (pause_panel == null or not pause_panel.visible)
	var was_visible := death_recovery_panel.visible
	death_recovery_panel.visible = show_panel
	death_recovery_panel.set_meta("gameplay_input_blocked", show_panel)
	if show_panel and not was_visible:
		_schedule_viewport_layout()
		call_deferred("_focus_initial_modal_action", death_recovery_panel)
	if death_retry_button != null:
		death_retry_button.disabled = not death_pending or SceneRouter.is_transition_pending()
	if death_recovery_status != null:
		if GameState.is_legacy_expedition():
			death_recovery_status.text = "舊制出征的物資與進度已即時入庫；回收系統正將你送回維修艙。"
		else:
			death_recovery_status.text = "尚未安全撤離的本趟材料、行動與線索不會帶回；先前已入庫的物資與成長保留。回收系統正前往最近維修艙。"

func _add_notice_label() -> void:
	notice_label = Label.new()
	notice_label.name = "NoticeLabel"
	notice_label.z_index = 120
	notice_label.visible = false
	notice_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice_label.add_theme_font_size_override("font_size", 18)
	notice_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.68))
	notice_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	notice_label.add_theme_constant_override("shadow_offset_x", 2)
	notice_label.add_theme_constant_override("shadow_offset_y", 2)
	notice_label.custom_minimum_size = Vector2(0, 34)
	root.add_child(notice_label)
	notice_timer = Timer.new()
	notice_timer.one_shot = true
	notice_timer.timeout.connect(_on_notice_timeout)
	add_child(notice_timer)

func _add_pause_button(container: VBoxContainer, text: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(290, 42)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	container.add_child(button)
	return button

func _resume_or_retry_recovery() -> void:
	if _pause_load_pending:
		return
	if GameState.death_pending and not GameState.retry_death_recovery():
		_set_pause_feedback("暫時無法重試回收；請稍後再試，或返回標題。", false)
		return
	_set_pause_visible(false)

func _set_pause_feedback(message: String, success: bool) -> void:
	if pause_status_label == null:
		return
	pause_status_label.text = message
	pause_status_label.add_theme_color_override("font_color", Color(0.58, 0.88, 0.68) if success else Color(1.0, 0.52, 0.42))
	var scroll := pause_panel.find_child("PauseScroll", true, false) as ScrollContainer
	if scroll != null:
		scroll.call_deferred("ensure_control_visible", pause_status_label)

func _save_from_pause() -> void:
	if _pause_load_pending:
		return
	var saved := SaveManager.save_game(true)
	if saved:
		_set_pause_feedback("已儲存目前狀態；存檔不會提前結算本趟收穫。", true)
	else:
		_set_pause_feedback("存檔失敗；本趟收穫未因此入庫。按 Esc 關閉暫停可查看詳細訊息。", false)

func _load_from_pause() -> void:
	if _pause_load_pending:
		return
	_set_pause_load_state(true, "讀取中…正在進入存檔場景。", true)
	var loaded := SaveManager.load_game(true, true)
	if not loaded:
		_set_pause_load_state(false, "讀取失敗；目前仍留在暫停選單。按 Esc 關閉暫停可查看詳細訊息。", false)

func _set_pause_load_state(pending: bool, message: String, success: bool) -> void:
	_pause_load_pending = pending
	for button: Button in [pause_resume_button, pause_save_button, pause_load_button, pause_title_button, pause_exit_button]:
		if button != null and is_instance_valid(button):
			button.disabled = pending
	if not message.is_empty():
		_set_pause_feedback(message, success)

func _on_save_load_finished(succeeded: bool) -> void:
	if not _pause_load_pending:
		return
	if succeeded:
		_pause_load_pending = false
		return
	_set_pause_load_state(false, "讀取失敗；目前仍留在暫停選單。按 Esc 關閉暫停可查看詳細訊息。", false)

func _return_to_title() -> void:
	if _pause_load_pending:
		return
	_set_pause_visible(false)
	SceneRouter.change_to("main", "default")

func _quit_from_pause() -> void:
	if _pause_load_pending:
		return
	get_tree().quit(0)

func _toggle_map() -> void:
	if atlas_panel != null and atlas_panel.visible:
		set_fullscreen_map(true)
		return
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
	var was_visible := inventory_panel.visible
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
	if is_visible and not was_visible:
		call_deferred("_focus_initial_modal_action", inventory_panel)

func open_workshop(tab := "craft") -> void:
	workshop_active_tab = tab
	_set_workshop_visible(true)

func open_contracts() -> void:
	_set_contract_visible(true)

func _set_workshop_visible(is_visible: bool) -> void:
	if workshop_panel == null:
		return
	if is_visible and GameState.current_scene_id == "wasteland":
		GameState.notify("回村莊或公會再整備：出征期間不能合成、鍛造、強化、拆解或購買晶片。")
		return
	var was_visible := workshop_panel.visible
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
	if is_visible and not was_visible:
		call_deferred("_focus_initial_modal_action", workshop_panel)

func _set_contract_visible(is_visible: bool) -> void:
	if contract_panel == null:
		return
	var was_visible := contract_panel.visible
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
		_layout()
		_refresh_contracts()
	_refresh_overlay_visibility()
	if is_visible and not was_visible:
		call_deferred("_focus_initial_modal_action", contract_panel)

func _set_terminal_visible(is_visible: bool) -> void:
	if terminal_panel == null:
		return
	var was_visible := terminal_panel.visible
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
	if is_visible and not was_visible:
		call_deferred("_focus_initial_modal_action", terminal_panel)

func _set_codex_visible(is_visible: bool) -> void:
	if codex_panel == null:
		return
	var was_visible := codex_panel.visible
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
	if is_visible and not was_visible:
		call_deferred("_focus_initial_modal_action", codex_panel)

func _set_tutorial_visible(is_visible: bool) -> void:
	var was_visible := tutorial_panel.visible
	if is_visible and pause_panel.visible:
		_set_pause_visible(false)
	tutorial_panel.visible = is_visible
	if is_visible:
		_refresh_tutorial_rules()
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
	if is_visible and not was_visible:
		call_deferred("_focus_initial_modal_action", tutorial_panel)

func _set_pause_visible(is_visible: bool) -> void:
	var was_visible := pause_panel.visible
	pause_panel.visible = is_visible
	if is_visible:
		if pause_status_label != null:
			if _pause_load_pending:
				pause_status_label.text = "讀取中…正在進入存檔場景。"
				pause_status_label.add_theme_color_override("font_color", Color(0.58, 0.88, 0.68))
			else:
				pause_status_label.text = "Esc 可關閉暫停。返回標題或退出不會自動儲存；手動儲存只記錄目前狀態，不會提前結算本趟收穫。"
				if GameState.death_pending:
					pause_status_label.text = "機體已停機。若回收中斷，可重試送回維修艙，或返回標題。成功抵達後才結算新制本趟未入庫成果；已入庫物資與成長保留。"
					if GameState.is_legacy_expedition():
						pause_status_label.text = "機體已停機。若回收中斷，可重試送回維修艙，或返回標題。本趟沿用舊制，物資與進度保留。"
				pause_status_label.add_theme_color_override("font_color", Color(0.82, 0.82, 0.76))
		if pause_resume_button != null:
			pause_resume_button.text = "重試回收機體" if GameState.death_pending else "繼續遊戲"
		for button: Button in [pause_resume_button, pause_save_button, pause_load_button, pause_title_button, pause_exit_button]:
			if button != null:
				button.disabled = _pause_load_pending
		var scroll := pause_panel.find_child("PauseScroll", true, false) as ScrollContainer
		if scroll != null:
			scroll.scroll_vertical = 0
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
	if not is_visible:
		call_deferred("_sync_campaign_choice")
	elif not was_visible:
		call_deferred("_focus_initial_modal_action", pause_panel)

func _refresh_overlay_visibility() -> void:
	_update_death_recovery_panel()
	var draft_open := expedition_draft_panel != null and expedition_draft_panel.visible
	var campaign_choice_open := campaign_choice_panel != null and campaign_choice_panel.visible
	var death_recovery_open := death_recovery_panel != null and death_recovery_panel.visible
	var competing_modal := inventory_panel.visible or tutorial_panel.visible or dialogue_panel.visible or pause_panel.visible or death_recovery_open or map_fullscreen or draft_open or campaign_choice_open
	for panel: Control in [workshop_panel, contract_panel, terminal_panel, codex_panel]:
		competing_modal = competing_modal or (panel != null and panel.visible)
	if competing_modal and atlas_panel != null:
		atlas_panel.visible = false
	var atlas_open := atlas_panel != null and atlas_panel.visible
	var journal_open := codex_panel != null and codex_panel.visible
	var owned_reading_pause := _journal_paused_tree or _atlas_paused_tree or _tutorial_paused_tree or _draft_paused_tree or _campaign_choice_paused_tree
	var reading_modal_open := journal_open or atlas_open or tutorial_panel.visible or draft_open or campaign_choice_open
	if reading_modal_open and (owned_reading_pause or not get_tree().paused):
		_journal_paused_tree = journal_open
		_atlas_paused_tree = atlas_open
		_tutorial_paused_tree = tutorial_panel.visible
		_draft_paused_tree = draft_open
		_campaign_choice_paused_tree = campaign_choice_open
		get_tree().paused = true
	elif owned_reading_pause and not reading_modal_open:
		_journal_paused_tree = false
		_atlas_paused_tree = false
		_tutorial_paused_tree = false
		_draft_paused_tree = false
		_campaign_choice_paused_tree = false
		get_tree().paused = _story_paused_tree or (pause_panel != null and pause_panel.visible)
	var extra_modal := (workshop_panel != null and workshop_panel.visible) or (contract_panel != null and contract_panel.visible) or (terminal_panel != null and terminal_panel.visible) or (codex_panel != null and codex_panel.visible)
	extra_modal = extra_modal or atlas_open or draft_open or campaign_choice_open
	var modal_open: bool = inventory_panel.visible or extra_modal or tutorial_panel.visible or map_fullscreen or dialogue_panel.visible or pause_panel.visible or death_recovery_open
	_campaign_status_blocked = modal_open
	inventory_panel.set_meta("gameplay_input_blocked", inventory_panel.visible)
	if workshop_panel != null:
		workshop_panel.set_meta("gameplay_input_blocked", workshop_panel.visible)
	if contract_panel != null:
		contract_panel.set_meta("gameplay_input_blocked", contract_panel.visible)
	if terminal_panel != null:
		terminal_panel.set_meta("gameplay_input_blocked", terminal_panel.visible)
	if codex_panel != null:
		codex_panel.set_meta("gameplay_input_blocked", codex_panel.visible)
	if atlas_panel != null:
		atlas_panel.set_meta("gameplay_input_blocked", atlas_open)
	if expedition_draft_panel != null:
		expedition_draft_panel.set_meta("gameplay_input_blocked", draft_open)
	if campaign_choice_panel != null:
		campaign_choice_panel.set_meta("gameplay_input_blocked", campaign_choice_open)
	status_panel.visible = not atlas_open
	quest_panel.visible = not atlas_open
	tutorial_panel.set_meta("gameplay_input_blocked", tutorial_panel.visible)
	dialogue_panel.set_meta("gameplay_input_blocked", dialogue_panel.visible)
	pause_panel.set_meta("gameplay_input_blocked", pause_panel.visible)
	minimap_panel.set_meta("gameplay_input_blocked", map_fullscreen)
	if nav_bar_panel != null:
		nav_bar_panel.visible = not modal_open
	quick_bar_panel.visible = not modal_open
	controls_hint.visible = not modal_open
	minimap_panel.visible = map_open and not inventory_panel.visible and not extra_modal and not tutorial_panel.visible and not dialogue_panel.visible and not pause_panel.visible and not death_recovery_open
	if map_fullscreen:
		var mm_style := _panel_style(UI_CHARCOAL, UI_BRONZE, 2)
		minimap_panel.add_theme_stylebox_override("panel", mm_style)
		if minimap_title != null:
			minimap_title.text = "◈ 區域戰術地圖 [M / Esc 關閉] ｜ Seed %d" % GameState.seed
	else:
		var mm_style := _panel_style(Color(0.075, 0.067, 0.077, 0.90), UI_BRONZE, 1)
		minimap_panel.add_theme_stylebox_override("panel", mm_style)
		if minimap_title != null:
			minimap_title.text = "◈ 雷達 [M]"
	if map_view != null:
		map_view.set_full_screen(map_fullscreen)
	_update_notice_visibility()
	_refresh_campaign_status()
	_layout()

func _refresh_campaign_status() -> void:
	if campaign_status_label == null:
		return
	var providers := get_tree().get_nodes_in_group("campaign_action")
	var blocked: bool = _campaign_status_blocked or SceneRouter.is_transition_pending() or GameState.current_scene_id != "wasteland" or GameState.death_pending or GameState.hp <= 0 or not GameState.has_authored_campaign()
	var occluders: Array[Control] = [status_panel, quest_panel, minimap_panel, nav_bar_panel, quick_bar_panel, notice_label, controls_hint]
	for provider: Node in providers:
		if is_instance_valid(provider) and get_parent().is_ancestor_of(provider) and provider.has_method("set_hud_presentation"):
			provider.call("set_hud_presentation", blocked, occluders)
	if blocked:
		_set_campaign_status({})
		return
	for definition: Dictionary in GameState.campaign_outing().get("actions", []):
		var action_id := String(definition.get("id", ""))
		if GameState.campaign_action_status(action_id) not in ["ready", "active"]:
			continue
		for provider: Node in providers:
			if not is_instance_valid(provider) or not get_parent().is_ancestor_of(provider) or String(provider.get_meta("campaign_action_id", "")) != action_id or not provider.has_method("presentation_state"):
				continue
			_set_campaign_status(provider.call("presentation_state"))
			return
	_set_campaign_status({})

func _set_campaign_status(state: Dictionary) -> void:
	if campaign_status_label == null or campaign_progress_bar == null:
		return
	var show_status := not state.is_empty()
	var text := ""
	var waiting := bool(state.get("waiting", false))
	if show_status:
		text = "現場｜%s\n%s" % [String(state.get("name", "本趟行動")), String(state.get("text", ""))]
		var progress := String(state.get("progress_text", ""))
		if waiting and not progress.is_empty():
			text += "\n" + progress
	var show_progress := show_status and float(state.get("maximum", 0.0)) > 0.0
	var needs_layout := campaign_status_label.visible != show_status or campaign_status_label.text != text or campaign_progress_bar.visible != show_progress
	campaign_status_label.visible = show_status
	campaign_status_label.text = text
	campaign_status_label.add_theme_color_override("font_color", UI_AMBER if waiting else Color(0.65, 0.91, 0.82))
	campaign_progress_bar.visible = show_progress
	if show_progress:
		campaign_progress_bar.max_value = float(state["maximum"])
		campaign_progress_bar.value = clampf(float(state.get("value", 0.0)), 0.0, campaign_progress_bar.max_value)
	if needs_layout:
		call_deferred("_layout")

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
		if not _last_world_region.is_empty():
			quest_header_label.text += "\n%s" % _last_world_region
	if quest_label != null:
		var quest := DataRegistry.get_quest(GameState.active_quest_id)
		var quest_lines: Array[String] = []
		if GameState.has_active_expedition() or GameState.is_legacy_expedition():
			var expedition_status := GameState.expedition_summary()
			if not expedition_status.is_empty():
				quest_lines.append(expedition_status)
			if GameState.has_active_expedition() and GameState.has_method("expedition_build_summary"):
				quest_lines.append(String(GameState.call("expedition_build_summary")))
		quest_lines.append(String(quest.get("name", "灰燼之後的名字")))
		quest_lines.append("下一步：%s" % GameState.get_journey_hint())
		var campaign_summary := _campaign_summary_text()
		if not campaign_summary.is_empty():
			quest_lines.append(campaign_summary)
		quest_label.text = "\n".join(quest_lines)
	_update_death_recovery_panel()
	_layout()
	if codex_panel != null and codex_panel.visible and _journal_signature != str(GameState.discovered_events) + str(GameState.completed_quests) + GameState.active_quest_id:
		_refresh_codex()
	if atlas_panel != null and atlas_panel.visible:
		atlas_panel.call("refresh")


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
			if item_id == "ammo":
				var banked_ammo := int(GameState.inventory.get("ammo", 0))
				var available_ammo := GameState.quest_item_count("ammo")
				var outing_ammo := maxi(0, available_ammo - banked_ammo)
				if GameState.has_active_expedition():
					button.tooltip_text = "彈藥可用 %d（已入庫 %d；本趟 %d）｜遠程武器攻擊時自動消耗；此快捷欄不能直接使用。" % [available_ammo, banked_ammo, outing_ammo]
				else:
					button.tooltip_text = "彈藥可用 %d（已入庫）｜遠程武器攻擊時自動消耗；此快捷欄不能直接使用。" % available_ammo
			elif not DataRegistry.get_resource(item_id).is_empty():
				var resource := DataRegistry.get_resource(item_id)
				button.tooltip_text = "%s x%d｜選取快捷欄不會直接消耗。" % [String(resource.get("name", GameState.item_display_name(item_id))), GameState.quest_item_count(item_id)]
			else:
				button.tooltip_text = GameState.item_display_name(item_id)
		button.expand_icon = true
		button.add_theme_stylebox_override("normal", _button_style(is_active))
		button.add_theme_stylebox_override("hover", _button_style(true))
		button.pressed.connect(func() -> void: GameState.use_quick_slot(i))
		quick_bar.add_child(button)

func _refresh_inventory() -> void:
	if inventory_list == null or not inventory_panel.visible:
		return
	_refresh_modal_navigation(inventory_panel, "inventory")
	for child: Node in inventory_list.get_children():
		child.queue_free()
	var title: Label = Label.new()
	title.text = "人物裝備與戰術改裝：R-17 回收機器人"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.98, 0.88, 0.48))
	inventory_list.add_child(title)
	var current_item: String = GameState.active_attack_item_id()
	var current_equipment: Dictionary = DataRegistry.get_equipment(current_item)
	var current_name: String = String(current_equipment.get("name", GameState.item_display_name(current_item)))
	var mode_label: String = _attack_mode_label(String(current_equipment.get("attack_mode", "melee")))
	var banked_ammo := int(GameState.inventory.get("ammo", 0))
	var available_ammo := GameState.quest_item_count("ammo")
	var outing_ammo := maxi(0, available_ammo - banked_ammo)
	var ammo_summary: String
	if GameState.has_active_expedition():
		ammo_summary = "彈藥可用 %d（庫存 %d＋本趟 %d）" % [available_ammo, banked_ammo, outing_ammo]
	else:
		ammo_summary = "彈藥可用 %d（已入庫）" % available_ammo
	var active_label: Label = Label.new()
	active_label.text = "目前左鍵：%s（%s）｜升級點：%d｜%s｜廢鐵 x%d｜核心 x%d｜晶核 x%d" % [current_name, mode_label, GameState.upgrade_points, ammo_summary, GameState.scrap, GameState.cores, GameState.crystals]
	active_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	active_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_label.add_theme_font_size_override("font_size", 16)
	inventory_list.add_child(active_label)
	var legacy_trip := GameState.is_legacy_expedition()
	var haul_label: Label = Label.new()
	if legacy_trip:
		haul_label.text = "舊存檔｜本趟拾取物已全部入庫；首次返村前仍沿用舊制。"
	elif GameState.has_active_expedition():
		haul_label.text = "本趟未入庫收穫：%s" % GameState.expedition_haul_summary()
	else:
		haul_label.text = "本趟未入庫收穫：無（目前未出征）"
	haul_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	haul_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	haul_label.add_theme_font_size_override("font_size", 15)
	haul_label.add_theme_color_override("font_color", Color(0.98, 0.84, 0.42))
	inventory_list.add_child(haul_label)
	var expedition_rules: Label = Label.new()
	if legacy_trip:
		expedition_rules.text = "本趟仍沿用舊制；首次返村後的新制出征，收穫須經路線出口成功返村才入庫。之後拾取彈藥可立即使用，先消耗本趟收穫、再用已入庫彈藥，已消耗不退還；出征找到的裝備帶回入庫後才能裝備。"
	else:
		expedition_rules.text = "庫存已入庫；新制出征收穫須經路線出口成功返村才入庫。拾取彈藥可立即使用，先消耗本趟收穫、再用已入庫彈藥，已消耗不退還；出征找到的裝備成功帶回入庫後才能裝備。"
	if GameState.current_scene_id == "wasteland":
		expedition_rules.text = "野外 [C] 工坊停用，永久整備須回村莊或公會。\n" + expedition_rules.text
	expedition_rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	expedition_rules.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	expedition_rules.add_theme_font_size_override("font_size", 13)
	expedition_rules.add_theme_color_override("font_color", UI_PAPER)
	inventory_list.add_child(expedition_rules)
	if GameState.has_active_expedition() and GameState.has_method("expedition_build_summary"):
		var build_label := Label.new()
		build_label.text = String(GameState.call("expedition_build_summary"))
		build_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		build_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		build_label.add_theme_font_size_override("font_size", 14)
		build_label.add_theme_color_override("font_color", Color(0.67, 0.88, 0.74))
		inventory_list.add_child(build_label)

	var top: BoxContainer
	var viewport_width := get_viewport().get_visible_rect().size.x
	var available_inventory_width := maxf(1.0, viewport_width - 68.0)
	var narrow_inventory := viewport_width < 1180.0
	var side_by_side := _inventory_available_display_width() >= 940.0
	_inventory_stacked_layout = not side_by_side
	if side_by_side:
		top = HBoxContainer.new()
	else:
		top = VBoxContainer.new()
	top.add_theme_constant_override("separation", 18)
	top.name = "InventoryEquipmentRow"
	inventory_list.add_child(top)
	var profile_card := _build_profile_card()
	profile_card.name = "InventoryProfileCard"
	if not side_by_side:
		profile_card.custom_minimum_size.x = minf(330.0, available_inventory_width)
	top.add_child(profile_card)

	var equipment_card_width := minf(660.0, maxf(1.0, available_inventory_width - (348.0 if side_by_side else 0.0)))
	var equip_list: VBoxContainer = VBoxContainer.new()
	equip_list.name = "InventoryEquipmentList"
	equip_list.custom_minimum_size = Vector2(equipment_card_width, 400)
	equip_list.add_theme_constant_override("separation", 8)
	top.add_child(equip_list)
	_add_equipment_card(equip_list, "weapon", "近戰武器", equipment_card_width)
	_add_equipment_card(equip_list, "ranged", "遠程武器", equipment_card_width)
	_add_equipment_card(equip_list, "armor", "護甲", equipment_card_width)
	_add_equipment_card(equip_list, "tool", "工具", equipment_card_width)

	var upgrade_row: Container
	if narrow_inventory:
		var upgrade_grid := GridContainer.new()
		upgrade_grid.columns = 4 if available_inventory_width >= 620.0 else (3 if available_inventory_width >= 480.0 else (2 if available_inventory_width >= 336.0 else 1))
		upgrade_grid.add_theme_constant_override("h_separation", 8)
		upgrade_grid.add_theme_constant_override("v_separation", 8)
		upgrade_row = upgrade_grid
	else:
		var upgrade_hbox := HBoxContainer.new()
		upgrade_hbox.add_theme_constant_override("separation", 8)
		upgrade_row = upgrade_hbox
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
	btn_perk.disabled = GameState.current_scene_id == "wasteland"
	if btn_perk.disabled:
		btn_perk.tooltip_text = "回村莊或公會後才能購買戰術晶片。"
	btn_perk.add_theme_stylebox_override("normal", _button_style(true))
	btn_perk.add_theme_stylebox_override("hover", _button_style(true))
	btn_perk.pressed.connect(func() -> void:
		open_workshop("perks")
	)
	upgrade_row.add_child(btn_perk)

	var btn_recycle := Button.new()
	btn_recycle.text = "♻ 拆解回收 [C]"
	btn_recycle.custom_minimum_size = Vector2(136, 36)
	btn_recycle.disabled = GameState.current_scene_id == "wasteland"
	if btn_recycle.disabled:
		btn_recycle.tooltip_text = "回村莊或公會後才能拆解回收。"
	btn_recycle.add_theme_stylebox_override("normal", _button_style(false))
	btn_recycle.add_theme_stylebox_override("hover", _button_style(true))
	btn_recycle.pressed.connect(func() -> void:
		open_workshop("recycle")
	)
	upgrade_row.add_child(btn_recycle)

	var separator: HSeparator = HSeparator.new()
	inventory_list.add_child(separator)
	var bag_label: Label = Label.new()
	bag_label.text = "已入庫背包物品｜裝備可點擊穿戴；材料與資源僅顯示數量"
	bag_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bag_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bag_label.add_theme_font_size_override("font_size", 19)
	inventory_list.add_child(bag_label)
	var grid: GridContainer = GridContainer.new()
	grid.columns = clampi(int(floor(available_inventory_width / 297.0)), 1, 3)
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	inventory_list.add_child(grid)
	var bag_button_width := minf(285.0, available_inventory_width)
	for item_id in GameState.inventory.keys():
		_add_bag_button(grid, String(item_id), int(GameState.inventory[item_id]), bag_button_width)

func _refresh_workshop_after_layout() -> void:
	if workshop_panel == null or not workshop_panel.visible:
		return
	if is_equal_approx(workshop_panel.custom_minimum_size.x, _workshop_layout_source_width) or _workshop_resize_refresh_queued:
		return
	_workshop_resize_refresh_queued = true
	call_deferred("_reflow_workshop_after_layout")

func _reflow_workshop_after_layout() -> void:
	_workshop_resize_refresh_queued = false
	if workshop_panel == null or not workshop_panel.visible:
		return
	_refresh_workshop()
	call_deferred("_layout")

func _update_workshop_card_layout() -> void:
	var content_width := maxf(1.0, workshop_panel.custom_minimum_size.x)
	var panel_style := workshop_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if panel_style != null:
		content_width -= panel_style.content_margin_left + panel_style.content_margin_right
		content_width -= float(panel_style.border_width_left + panel_style.border_width_right)
	var scroll := workshop_list.get_parent() as ScrollContainer
	if scroll != null:
		content_width -= maxf(12.0, scroll.get_v_scroll_bar().get_combined_minimum_size().x)
	content_width = maxf(1.0, content_width)
	_workshop_layout_source_width = workshop_panel.custom_minimum_size.x
	_workshop_card_columns = 2 if content_width >= WORKSHOP_MIN_CARD_WIDTH * 2.0 + WORKSHOP_CARD_GAP else 1
	_workshop_card_width = floorf((content_width - WORKSHOP_CARD_GAP * float(_workshop_card_columns - 1)) / float(_workshop_card_columns))

func _make_workshop_grid(h_separation: int = 12, v_separation: int = 10) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = _workshop_card_columns
	grid.add_theme_constant_override("h_separation", h_separation)
	grid.add_theme_constant_override("v_separation", v_separation)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return grid

func _size_workshop_card(card: PanelContainer, height: float) -> void:
	card.custom_minimum_size = Vector2(_workshop_card_width, height)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _wrap_workshop_label(label: Label) -> void:
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _refresh_workshop() -> void:
	if workshop_list == null or workshop_panel == null or not workshop_panel.visible:
		return
	_refresh_modal_navigation(workshop_panel, "workshop")
	if _workshop_scroll_tab != workshop_active_tab:
		var scroll := workshop_list.get_parent() as ScrollContainer
		if scroll != null:
			scroll.scroll_vertical = 0
		_workshop_scroll_tab = workshop_active_tab
	_update_workshop_card_layout()
	for child: Node in workshop_list.get_children():
		workshop_list.remove_child(child)
		child.queue_free()
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
	if not GameState.can_deliver_quest_here():
		GameState.notify("請先經路線出口返村，再進行維修與存檔。")
		return
	GameState.heal_full()
	SaveManager.save_game(true)
	_refresh_workshop()


func _build_workshop_content_inner() -> void:
	var title := Label.new()
	title.text = "🔨 廢土工坊終端 [C] — 拆解・合成・改裝・戰術晶片"
	_wrap_workshop_label(title)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.98, 0.84, 0.42))
	workshop_list.add_child(title)

	var res_lbl := Label.new()
	res_lbl.text = "當前資源：廢鐵 %d ｜ 異變核心 %d ｜ 污染晶核 %d ｜ 彈藥 %d ｜ 升級點 %d" % [GameState.scrap, GameState.cores, GameState.crystals, GameState.ammo, GameState.upgrade_points]
	_wrap_workshop_label(res_lbl)
	res_lbl.add_theme_font_size_override("font_size", 15)
	res_lbl.add_theme_color_override("font_color", Color(0.76, 0.94, 0.92))
	workshop_list.add_child(res_lbl)

	# Sub-tabs bar
	var subtab_row := HBoxContainer.new()
	subtab_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	_wrap_workshop_label(desc)
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
	hint.text = "（每種裝備至少保留一件，只拆多出的副本；素材需手動選擇）"
	_wrap_workshop_label(hint)
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.65, 0.72, 0.68))
	batch_row.add_child(hint)

	var grid := _make_workshop_grid()
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
		_size_workshop_card(card, 88)
		card.add_theme_stylebox_override("panel", _panel_style(Color(0.055, 0.065, 0.078, 0.94), Color(0.38, 0.62, 0.48, 0.90), 1))

		var hb := HBoxContainer.new()
		hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_theme_constant_override("separation", 12)
		card.add_child(hb)

		var icon := _fit_texture_rect(_item_icon(String(item_id)), Vector2(64, 64))
		hb.add_child(icon)

		var vb := VBoxContainer.new()
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb.add_theme_constant_override("separation", 3)
		hb.add_child(vb)

		var title_row := HBoxContainer.new()
		title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_row.add_theme_constant_override("separation", 8)
		vb.add_child(title_row)

		var name_lbl := Label.new()
		name_lbl.text = "%s x%d" % [GameState.item_display_name(String(item_id)), count]
		_wrap_workshop_label(name_lbl)
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
		_wrap_workshop_label(yield_lbl)
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
		_wrap_workshop_label(empty_lbl)
		empty_lbl.add_theme_font_size_override("font_size", 15)
		empty_lbl.add_theme_color_override("font_color", Color(0.65, 0.70, 0.75))
		workshop_list.add_child(empty_lbl)

func _build_workshop_tab_craft() -> void:
	var desc := Label.new()
	desc.text = "⚒ 機械合成台：研製高階近戰利刃、重裝防具與先進十字弩/槍械藍圖。"
	_wrap_workshop_label(desc)
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Color(0.88, 0.82, 0.62))
	workshop_list.add_child(desc)

	var grid := _make_workshop_grid()
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
		_size_workshop_card(card, 110)
		card.add_theme_stylebox_override("panel", _panel_style(Color(0.055, 0.065, 0.078, 0.94), Color(0.62, 0.52, 0.32, 0.90), 1))

		var hb := HBoxContainer.new()
		hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_theme_constant_override("separation", 12)
		card.add_child(hb)

		var icon := _fit_texture_rect(_item_icon(result_item_id), Vector2(68, 68))
		hb.add_child(icon)

		var vb := VBoxContainer.new()
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb.add_theme_constant_override("separation", 3)
		hb.add_child(vb)

		var header_row := HBoxContainer.new()
		header_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header_row.add_theme_constant_override("separation", 8)
		vb.add_child(header_row)

		var n_lbl := Label.new()
		n_lbl.text = item_name
		_wrap_workshop_label(n_lbl)
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
		_wrap_workshop_label(stat_lbl)
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
		_wrap_workshop_label(cost_lbl)
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
	_wrap_workshop_label(desc)
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Color(0.68, 0.88, 0.98))
	workshop_list.add_child(desc)

	var grid := _make_workshop_grid()
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
		_size_workshop_card(card, 96)
		card.add_theme_stylebox_override("panel", _panel_style(Color(0.055, 0.065, 0.078, 0.94), Color(0.28, 0.54, 0.72, 0.90), 1))

		var hb := HBoxContainer.new()
		hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_theme_constant_override("separation", 12)
		card.add_child(hb)

		var icon := _fit_texture_rect(_item_icon(String(item_id)), Vector2(64, 64))
		hb.add_child(icon)

		var vb := VBoxContainer.new()
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb.add_theme_constant_override("separation", 3)
		hb.add_child(vb)

		var title_row := VBoxContainer.new()
		title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_row.add_theme_constant_override("separation", 2)
		vb.add_child(title_row)

		var n_lbl := Label.new()
		n_lbl.text = GameState.item_display_name(String(item_id))
		_wrap_workshop_label(n_lbl)
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
		_wrap_workshop_label(stats_lbl)
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
		_wrap_workshop_label(cost_lbl)
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
	_wrap_workshop_label(desc)
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Color(0.98, 0.82, 0.52))
	workshop_list.add_child(desc)

	var grid := _make_workshop_grid(14, 12)
	workshop_list.add_child(grid)

	var actions := [
		["🔥 鍛造穿甲弩箭/彈藥包", "消耗：廢鐵 x8 ➔ 產出：彈藥 x12", "立即鍛造彈藥", Callable(self, "_on_workshop_forge")],
		["🛒 黑市緊急補給彈藥", "消耗：廢鐵 x4 ➔ 產出：彈藥 x8", "黑市採購彈藥", Callable(self, "_on_workshop_shop")],
		["♻ 工業拆解異變核心", "消耗：異變核心 x1 ➔ 產出：高純廢鐵 x14 + 污染晶核 x1", "啟動核心拆解", Callable(self, "_on_workshop_recycle")],
		["🛠 全機整備維修與存檔", "完全恢復 R-17 機體 HP 與能量 EP，並寫入最新進度存檔", "全機修復並存檔", Callable(self, "_on_workshop_save")],
	]
	for act in actions:
		var card := PanelContainer.new()
		_size_workshop_card(card, 118)
		card.add_theme_stylebox_override("panel", _panel_style(Color(0.06, 0.07, 0.085, 0.94), Color(0.56, 0.44, 0.24, 0.92), 1))
		var vb := VBoxContainer.new()
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb.add_theme_constant_override("separation", 6)
		card.add_child(vb)
		var h_lbl := Label.new()
		h_lbl.text = String(act[0])
		_wrap_workshop_label(h_lbl)
		h_lbl.add_theme_font_size_override("font_size", 17)
		h_lbl.add_theme_color_override("font_color", Color(0.98, 0.88, 0.48))
		vb.add_child(h_lbl)
		var d_lbl := Label.new()
		d_lbl.text = String(act[1])
		_wrap_workshop_label(d_lbl)
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
	_wrap_workshop_label(desc)
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Color(0.52, 0.94, 0.98))
	workshop_list.add_child(desc)

	var pt_lbl := Label.new()
	pt_lbl.text = "★ 可用維修升級點：%d 點（擊敗敵人累積經驗，提升等級時取得）" % GameState.upgrade_points
	_wrap_workshop_label(pt_lbl)
	pt_lbl.add_theme_font_size_override("font_size", 16)
	pt_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.42))
	workshop_list.add_child(pt_lbl)

	var grid := _make_workshop_grid(14, 12)
	workshop_list.add_child(grid)

	for perk_id in GameState.PERKS_CATALOG.keys():
		var p_def: Dictionary = GameState.PERKS_CATALOG[perk_id]
		var cur_lvl: int = GameState.get_perk_level(perk_id)
		var max_lvl: int = int(p_def.get("max_level", 3))
		var is_max: bool = (cur_lvl >= max_lvl)
		var can_upgrade: bool = (not is_max and GameState.upgrade_points > 0)

		var card := PanelContainer.new()
		_size_workshop_card(card, 118)
		card.add_theme_stylebox_override("panel", _panel_style(Color(0.055, 0.065, 0.08, 0.94), Color(0.24, 0.72, 0.88, 0.92) if cur_lvl > 0 else Color(0.35, 0.45, 0.52, 0.85), 1))

		var vb := VBoxContainer.new()
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb.add_theme_constant_override("separation", 6)
		card.add_child(vb)

		var top_row := HBoxContainer.new()
		top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_row.add_theme_constant_override("separation", 10)
		vb.add_child(top_row)

		var icon_lbl := Label.new()
		icon_lbl.text = String(p_def.get("icon", "⚡"))
		icon_lbl.add_theme_font_size_override("font_size", 20)
		top_row.add_child(icon_lbl)

		var name_lbl := Label.new()
		name_lbl.text = String(p_def.get("name", perk_id))
		_wrap_workshop_label(name_lbl)
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
		_wrap_workshop_label(desc_lbl)
		desc_lbl.add_theme_font_size_override("font_size", 12)
		desc_lbl.add_theme_color_override("font_color", Color(0.82, 0.86, 0.90))
		vb.add_child(desc_lbl)

		var btn_perk := Button.new()
		btn_perk.text = "已達最高星級" if is_max else ("裝載晶片（消耗 1 點）" if cur_lvl == 0 else "升級晶片（消耗 1 點）")
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
	_refresh_modal_navigation(contract_panel, "contract")
	for child: Node in contract_list.get_children():
		contract_list.remove_child(child)
		child.queue_free()
	var title := Label.new()
	title.text = "📜 公會委託與廢土路線 [J]"
	_set_contract_font_size(title, 22)
	title.add_theme_color_override("font_color", UI_AMBER)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contract_list.add_child(title)

	var active_quest := DataRegistry.get_quest(GameState.active_quest_id)
	_add_current_contract_card(contract_list, active_quest)

	var available_quests: Array[String] = []
	var waiting_quests: Array[String] = []
	var completed_quests: Array[String] = []
	var locked_quests: Array[String] = []
	for raw_quest_id in DataRegistry.quest_ids():
		var quest_id := String(raw_quest_id)
		if quest_id == GameState.active_quest_id:
			continue
		if GameState.completed_quests.has(quest_id):
			completed_quests.append(quest_id)
		elif GameState.is_quest_available(quest_id):
			available_quests.append(quest_id)
		elif not GameState.active_quest_id.is_empty() and GameState.quest_prerequisites_met(quest_id):
			waiting_quests.append(quest_id)
		else:
			locked_quests.append(quest_id)

	var catalog_title := Label.new()
	catalog_title.text = "委託清單｜可承接、待處理與已完成"
	_set_contract_font_size(catalog_title, 17)
	catalog_title.add_theme_color_override("font_color", Color(0.78, 0.88, 0.80))
	contract_list.add_child(catalog_title)
	var expand_available := GameState.active_quest_id.is_empty() and GameState.can_deliver_quest_here()
	_add_contract_catalog_group(contract_list, "Available", "可承接委託", available_quests, expand_available)
	_add_contract_catalog_group(contract_list, "Waiting", "需先交付目前委託", waiting_quests)
	_add_contract_catalog_group(contract_list, "Completed", "已完成委託", completed_quests)
	_add_contract_catalog_group(contract_list, "Locked", "尚未解鎖", locked_quests)

	if not GameState.get_story_summary().is_empty():
		_add_journal_record(contract_list, "MainStorySummary", "主線摘要｜灰燼之後的名字", GameState.get_story_summary(), "Contract")
	if not active_quest.is_empty():
		var story_details := String(active_quest.get("story_step", "")).strip_edges()
		var description := String(active_quest.get("description", "")).strip_edges()
		if not description.is_empty():
			if not story_details.is_empty():
				story_details += "\n\n"
			story_details += description
		if not story_details.is_empty():
			_add_journal_record(contract_list, "ActiveQuestBriefing", "委託背景與完整說明", story_details, "Contract")
		_add_campaign_field_notes(contract_list, GameState.active_quest_id)
	var outing_details := _campaign_outing_details_text()
	if not outing_details.is_empty():
		_add_journal_record(contract_list, "ActiveCampaignOuting", "本趟章節行動與現場指引", outing_details, "Contract")
	var rules := _contract_rules_text()
	_add_journal_record(contract_list, "DeliveryRules", "交付、撤離與工坊規則", rules, "Contract")


func _add_current_contract_card(container: VBoxContainer, active_quest: Dictionary) -> void:
	var card := PanelContainer.new()
	card.name = "CurrentContractCard"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _panel_style(Color(0.055, 0.062, 0.067, 0.98), UI_AMBER, 2))
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 6)
	card.add_child(content)
	var active := not active_quest.is_empty()
	var quest_id := GameState.active_quest_id
	var quest_name := String(active_quest.get("name", "尚未承接委託"))
	var title_text := "目前委託｜尚未承接"
	if active:
		title_text = "目前委託｜%s" % quest_name
	var title := _make_contract_label(title_text, 20, UI_AMBER)
	title.name = "CurrentContractTitle"
	content.add_child(title)
	if active:
		var route_id := String(active_quest.get("route", ""))
		var route_name := String(DataRegistry.get_wasteland_route(route_id).get("name", route_id))
		var route_line := "路線：%s｜建議等級 %d" % [route_name, int(active_quest.get("recommended_level", 1))]
		content.add_child(_make_contract_label(route_line, 14, Color(0.72, 0.87, 0.81)))
	var journey_hint := GameState.get_journey_hint()
	if GameState.can_deliver_quest_here() and GameState.is_active_quest_ready():
		journey_hint = "目標已全部完成；使用下方「交付並領取報酬」按鈕。"
	var next_step := _make_contract_label("下一步：%s" % journey_hint, 16, UI_PAPER)
	next_step.name = "ContractNextStep"
	content.add_child(next_step)

	var requirement_lines: Array[String] = []
	var optional_lines: Array[String] = []
	var required_ready := 0
	var required_count := 0
	if active:
		for requirement: Dictionary in GameState.active_quest_requirements():
			var requirement_text := String(requirement.get("text", ""))
			if bool(requirement.get("optional", false)):
				optional_lines.append("• " + requirement_text)
				continue
			required_count += 1
			var ready := bool(requirement.get("ready", false))
			if ready:
				required_ready += 1
			requirement_lines.append("%s %s" % ["✓" if ready else "○", requirement_text])
	if active:
		var progress_label := _make_contract_label("必要目標進度　%d / %d" % [required_ready, required_count], 16, UI_AMBER)
		progress_label.name = "ContractProgress"
		content.add_child(progress_label)
	var requirements := Label.new()
	requirements.name = "ContractRequirements"
	if active:
		requirements.text = "\n".join(requirement_lines) if not requirement_lines.is_empty() else "目前沒有必要目標。"
		if GameState.has_active_expedition():
			requirements.text += "\n本趟成果須成功返村才保留；交付材料會扣除。"
	else:
		requirements.text = "從下方展開「可承接委託」查看路線、必要目標與報酬。"
	requirements.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	requirements.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_set_contract_font_size(requirements, 14)
	requirements.add_theme_color_override("font_color", UI_PAPER)
	content.add_child(requirements)
	if not optional_lines.is_empty():
		var optional := _make_contract_label("選讀目標（不影響交付）\n%s" % "\n".join(optional_lines), 13, Color(0.70, 0.87, 0.82))
		optional.name = "ContractOptionalObjectives"
		content.add_child(optional)

	var at_delivery_location := GameState.can_deliver_quest_here()
	var delivery_text := "承接地點：村莊或公會 [J]。" if not active else "交付地點：村莊或公會。"
	if active:
		if not at_delivery_location:
			delivery_text = "交付地點：村莊或公會；[M] 查看返村出口，走到閘門按 [E] 撤離，返村後開啟 [J] 使用交付按鈕。"
		elif GameState.is_active_quest_ready():
			delivery_text = "交付地點：目前所在的村莊／公會；使用下方「交付並領取報酬」。"
		else:
			delivery_text = "交付地點：村莊或公會；完成必要條件後回到此處，使用下方交付按鈕。"
	content.add_child(_make_contract_label(delivery_text, 14, Color(0.78, 0.88, 0.80)))
	if active:
		content.add_child(_make_contract_label("報酬：%s" % GameState.quest_reward_summary(quest_id), 14, UI_AMBER))

	var claim_row := HBoxContainer.new()
	claim_row.add_theme_constant_override("separation", 8)
	content.add_child(claim_row)
	var claim_button := Button.new()
	claim_button.name = "ContractClaim"
	claim_button.text = "✔ 交付並領取報酬" if GameState.is_active_quest_ready() else "仍有必需條件未完成"
	if not at_delivery_location:
		claim_button.text = "返回村莊／公會交付"
	elif not active:
		claim_button.text = "先承接一份委託"
	claim_button.disabled = not at_delivery_location or not GameState.is_active_quest_ready()
	claim_button.custom_minimum_size = Vector2(230, 38)
	_set_contract_font_size(claim_button, 15)
	claim_button.focus_entered.connect(func() -> void: _ensure_scroll_control_visible(claim_button))
	claim_button.add_theme_stylebox_override("normal", _button_style(true))
	claim_button.add_theme_stylebox_override("hover", _button_style(true))
	claim_button.pressed.connect(func() -> void:
		if GameState.complete_active_quest():
			_set_contract_visible(false)
		else:
			_refresh_contracts()
	)
	claim_row.add_child(claim_button)
	container.add_child(card)


func _contract_rules_text() -> String:
	var expedition_rules := "庫存是已入庫物資；本趟收穫須經路線出口成功返村才入庫。拾取彈藥可立即使用，先消耗本趟彈藥、再消耗已入庫彈藥；已消耗的不退還。出征找到的裝備須成功帶回入庫後才能裝備。"
	if GameState.is_legacy_expedition():
		expedition_rules = "舊存檔本趟拾取物已入庫，返村前沿用舊制；新制出征收穫才須經路線出口帶回入庫。之後拾取彈藥可立即使用，先消耗本趟彈藥、再消耗已入庫彈藥；已消耗的不退還。裝備也須成功帶回入庫後才能裝備。"
	return "一次承接一份；[J] 可隨時查閱，承接與交付需在村莊／公會。擊敗數從承接後計算，只計委託路線；交付材料會從已入庫庫存扣除，報酬只領一次。\n%s 工坊合成、鍛造、拆解、晶片與永久升級只能在村莊／公會進行。" % expedition_rules


func _make_contract_label(text: String, font_size: int, font_color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_set_contract_font_size(label, font_size)
	label.add_theme_color_override("font_color", font_color)
	return label


func _add_contract_catalog_group(container: VBoxContainer, group_id: String, title: String, quest_ids: Array[String], expanded := false) -> void:
	if quest_ids.is_empty():
		return
	var toggle := Button.new()
	toggle.name = "ContractCatalogGroup_%s" % group_id
	toggle.text = "%s %s（%d）" % ["▾" if expanded else "▸", title, quest_ids.size()]
	_set_contract_font_size(toggle, 15)
	toggle.toggle_mode = true
	toggle.button_pressed = expanded
	toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toggle.add_theme_stylebox_override("normal", _button_style(false))
	toggle.focus_entered.connect(func() -> void: _ensure_scroll_control_visible(toggle))
	container.add_child(toggle)
	var grid := GridContainer.new()
	grid.name = "ContractCatalog_%s" % group_id
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	var available_width := (contract_panel.size.x - 48.0) * _window_scale_x()
	grid.columns = 2 if available_width >= 760.0 else 1
	grid.visible = expanded
	container.add_child(grid)
	toggle.toggled.connect(func(is_expanded: bool) -> void:
		grid.visible = is_expanded
		toggle.text = "%s %s（%d）" % ["▾" if is_expanded else "▸", title, quest_ids.size()]
	)
	for quest_id: String in quest_ids:
		_add_contract_catalog_entry(grid, quest_id)


func _add_contract_catalog_entry(grid: GridContainer, quest_id: String) -> void:
	var quest := DataRegistry.get_quest(quest_id)
	if quest.is_empty():
		return
	var is_done := GameState.completed_quests.has(quest_id)
	var available := GameState.is_quest_available(quest_id)
	var status_tag := "已完成" if is_done else ("可承接" if available else ("先交付目前委託" if GameState.quest_prerequisites_met(quest_id) else "待解鎖"))
	if available and quest_id == GameState.next_story_quest_id():
		status_tag = "建議下一站"
	var card := PanelContainer.new()
	card.name = "ContractEntry_%s" % quest_id
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _panel_style(UI_CHARCOAL, UI_BRONZE, 1))
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	card.add_child(content)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	content.add_child(row)
	var details_button := Button.new()
	details_button.name = "ContractDetails_%s" % quest_id
	details_button.text = "▸ 【%s】 %s" % [status_tag, String(quest.get("name", quest_id))]
	details_button.toggle_mode = true
	details_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_set_contract_font_size(details_button, 15)
	details_button.focus_entered.connect(func() -> void: _ensure_scroll_control_visible(details_button))
	details_button.add_theme_stylebox_override("normal", _button_style(false))
	details_button.add_theme_color_override("font_color", Color(0.62, 0.96, 0.68) if is_done else UI_PAPER)
	row.add_child(details_button)
	if not is_done:
		var accept_button := Button.new()
		accept_button.name = "ContractAccept_%s" % quest_id
		accept_button.text = "承接" if GameState.can_deliver_quest_here() else "回村承接"
		accept_button.disabled = is_done or not available or not GameState.active_quest_id.is_empty() or not GameState.can_deliver_quest_here()
		accept_button.custom_minimum_size = Vector2(104, 32)
		_set_contract_font_size(accept_button, 15)
		accept_button.focus_entered.connect(func() -> void: _ensure_scroll_control_visible(accept_button))
		accept_button.add_theme_stylebox_override("normal", _button_style(available))
		accept_button.add_theme_stylebox_override("hover", _button_style(true))
		var current_quest_id := quest_id
		accept_button.pressed.connect(func() -> void:
			if GameState.start_quest(current_quest_id):
				_set_contract_visible(false)
			else:
				_refresh_contracts()
		)
		row.add_child(accept_button)
	var route_id := String(quest.get("route", ""))
	var route_name := String(DataRegistry.get_wasteland_route(route_id).get("name", "廢土"))
	var detail_text := "%s｜建議等級 %d\n背景：%s\n目標：%s\n報酬：%s" % [route_name, int(quest.get("recommended_level", 1)), String(quest.get("story_step", "")), GameState.quest_objectives_summary(quest_id), GameState.quest_reward_summary(quest_id)]
	var description := String(quest.get("description", "")).strip_edges()
	if not description.is_empty():
		detail_text += "\n\n" + description
	var field: Variant = quest.get("field_objective", {})
	if field is Dictionary and not field.is_empty():
		detail_text += "\n現場：%s" % String(field.get("purpose", field.get("pending_dialogue", "")))
	if is_done and bool(quest.get("main_campaign", false)):
		var consequence := _campaign_consequence_summary(quest_id)
		if not consequence.is_empty():
			detail_text += "\n本章後續：%s" % consequence
	if not available and not is_done:
		var prerequisite_names: Array[String] = []
		for prerequisite in quest.get("prerequisites", []):
			prerequisite_names.append(String(DataRegistry.get_quest(String(prerequisite)).get("name", prerequisite)))
		if not prerequisite_names.is_empty():
			detail_text += "\n先完成：%s" % "、".join(prerequisite_names)
		elif not GameState.active_quest_id.is_empty():
			detail_text += "\n請先交付目前委託。"
	if is_done and GameState.has_method("campaign_field_notes"):
		var field_notes := String(GameState.call("campaign_field_notes", quest_id))
		if not field_notes.is_empty():
			detail_text += "\n\n現場紀錄：\n" + field_notes
	var details := _make_contract_label(detail_text, 13, UI_PAPER)
	details.name = "ContractDetailsText_%s" % quest_id
	details.visible = false
	content.add_child(details)
	details_button.toggled.connect(func(open: bool) -> void:
		details.visible = open
		details_button.text = "%s 【%s】 %s" % ["▾" if open else "▸", status_tag, String(quest.get("name", quest_id))]
	)
	grid.add_child(card)

func _refresh_codex() -> void:
	if codex_list == null or codex_panel == null or not codex_panel.visible:
		return
	_refresh_modal_navigation(codex_panel, "codex")
	_journal_signature = str(GameState.discovered_events) + str(GameState.completed_quests) + GameState.active_quest_id
	for child: Node in codex_list.get_children():
		codex_list.remove_child(child)
		child.queue_free()
	var title := Label.new()
	title.text = "回收者手記｜灰燼之後的名字 [K]"
	title.add_theme_font_size_override("font_size", 23)
	title.add_theme_color_override("font_color", Color(0.98, 0.86, 0.44))
	codex_list.add_child(title)
	_build_story_journal()
	var equipment_title := Label.new()
	equipment_title.text = "武裝資料庫"
	equipment_title.add_theme_font_size_override("font_size", 20)
	codex_list.add_child(equipment_title)

	var grid := GridContainer.new()
	grid.name = "CodexEquipmentGrid"
	grid.columns = 2 if get_viewport().get_visible_rect().size.x < 1180.0 else 3
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
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(vb)
		var n_lbl := Label.new()
		n_lbl.text = String(eq.get("name", item_id))
		n_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		n_lbl.add_theme_font_size_override("font_size", 15)
		n_lbl.add_theme_color_override("font_color", Color(0.98, 0.92, 0.68))
		vb.add_child(n_lbl)
		var s_lbl := Label.new()
		s_lbl.text = "%s｜%s" % [_equipment_stats_text(eq), _source_short_text(eq)]
		s_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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

func _build_story_journal() -> void:
	var summary := Label.new()
	summary.name = "StorySummary"
	summary.text = GameState.get_story_summary()
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.add_theme_font_size_override("font_size", 16)
	summary.add_theme_color_override("font_color", Color(0.62, 0.91, 0.84))
	codex_list.add_child(summary)
	var premise := Label.new()
	premise.name = "StoryPremise"
	premise.text = "艾倫認得撐住撤離門的你；他和母親柳青活了下來，門外的住戶卻失去了水源。調查從重接今天的水路開始，沿現場紀錄追查當年的封鎖，以及它留給居民的代價。"
	if GameState.completed_quests.has("facility_memory"):
		premise.text = GameState.quest_completion_story("facility_memory")
	premise.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	premise.add_theme_font_size_override("font_size", 15)
	premise.add_theme_color_override("font_color", UI_PAPER)
	codex_list.add_child(premise)
	var last_report := GameState.last_expedition_report()
	if not last_report.is_empty():
		_add_journal_record(codex_list, "Latest", "上次出征回報", last_report, "Expedition")
	var consequences := _campaign_completed_consequences_text()
	if not consequences.is_empty():
		var consequence_label := Label.new()
		consequence_label.name = "CampaignConsequences"
		consequence_label.text = "已完成章節的處置紀錄\n%s" % consequences
		consequence_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		consequence_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		consequence_label.add_theme_font_size_override("font_size", 14)
		consequence_label.add_theme_color_override("font_color", Color(0.74, 0.90, 0.80))
		codex_list.add_child(consequence_label)
	for quest: Dictionary in DataRegistry.quests:
		if bool(quest.get("main_campaign", false)):
			var quest_id := String(quest["id"])
			if GameState.has_completed_campaign(quest_id):
				_add_journal_record(codex_list, quest_id, "章節回顧｜%s" % String(quest.get("name", quest_id)), GameState.quest_completion_story(quest_id), "Chapter")
			_add_campaign_field_notes(codex_list, String(quest["id"]))
	for event in DataRegistry.events:
		if not bool(event.get("story", false)):
			continue
		var route_id := String(event.get("route", ""))
		var event_id := String(event.get("id", ""))
		var discovered := GameState.has_story_discovery(route_id, event_id)
		var unlocked := GameState.is_story_event_unlocked(event_id)
		var card := PanelContainer.new()
		card.name = "StoryEntry_%s" % event_id
		card.set_meta("discovered", discovered)
		card.add_theme_stylebox_override("panel", _panel_style(Color(0.045, 0.060, 0.070, 0.995), Color(0.35, 0.66, 0.62) if discovered else Color(0.29, 0.32, 0.36), 1))
		var text := Label.new()
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.custom_minimum_size = Vector2(0, 76)
		text.add_theme_font_size_override("font_size", 15)
		var route_name := String(DataRegistry.get_wasteland_route(route_id).get("name", route_id))
		var heading := "%02d｜%s｜%s" % [int(event.get("chapter", 0)), route_name, String(event.get("name", event_id))]
		var entry := "%s\n%s" % [String(event.get("description", "")), String(event.get("revelation", ""))] if discovered else "尚未調查。%s\n現場：%s" % [String(event.get("objective", "循線探索該區地標。")), String(event.get("location_hint", "地圖 [M] 的橘色事件標記，靠近按 E。"))]
		if not discovered and not unlocked:
			heading = "%02d｜%s｜後續調查尚未開放" % [int(event.get("chapter", 0)), route_name]
			entry = "先完成 [J] 列出的前置主線；解鎖後再顯示現場目標與位置。"
		if discovered and not String(event.get("follow_up", "")).is_empty():
			entry += "\n紀錄指向：%s" % String(event["follow_up"])
		if discovered and GameState.story_discovery_needs_extraction(route_id, event_id):
			entry += "\n手記已保留；任務成果待從這條路線安全撤離後保留。"
		text.text = "%s\n%s" % [heading, entry]
		card.add_child(text)
		codex_list.add_child(card)
	var lead := Label.new()
	lead.name = "StoryNextAction"
	lead.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lead.add_theme_font_size_override("font_size", 16)
	lead.text = "下一步：%s\n整備：背包 [I] 裝備報酬與分配升級點；工坊 [C] 強化武器、製作與補給。紀錄會永久保留，選讀線索可回原路補查。" % GameState.get_journey_hint()
	codex_list.add_child(lead)

func _campaign_summary_text() -> String:
	if not GameState.has_method("has_authored_campaign") or not bool(GameState.call("has_authored_campaign")) or not GameState.has_method("campaign_summary"):
		return ""
	var summary := String(GameState.call("campaign_summary")).strip_edges()
	if summary.is_empty():
		return ""
	var lines := summary.split("\n", false)
	var heading := String(lines[0]) if not lines.is_empty() else summary
	if not GameState.has_method("campaign_outing") or not GameState.has_method("campaign_action_status"):
		return heading
	var outing_value: Variant = GameState.call("campaign_outing")
	if not outing_value is Dictionary or outing_value.is_empty():
		return heading
	var actions: Variant = outing_value.get("actions", [])
	if not actions is Array:
		return heading
	var total := 0
	var completed := 0
	for action_value in actions:
		if not action_value is Dictionary:
			continue
		var action_id := String(action_value.get("id", ""))
		if action_id.is_empty():
			continue
		total += 1
		if String(GameState.call("campaign_action_status", action_id)) == "done":
			completed += 1
	return "%s｜本趟行動 %d/%d" % [heading, completed, total] if total > 0 else heading

func _campaign_outing_details_text() -> String:
	if not GameState.has_method("has_authored_campaign") or not bool(GameState.call("has_authored_campaign")) or not GameState.has_method("campaign_outing"):
		return ""
	var value: Variant = GameState.call("campaign_outing")
	if not value is Dictionary or value.is_empty():
		return ""
	var outing: Dictionary = value
	var outing_name := String(outing.get("name", ""))
	if outing_name.is_empty():
		return ""
	var lines: Array[String] = ["本章行動｜%s" % outing_name]
	lines.append("成功撤離只結算已完成行動並更新章節進度；委託條件與報酬仍獨立，達標後須另行交付。")
	var briefing := String(outing.get("briefing", "")).strip_edges()
	if not briefing.is_empty():
		lines.append(briefing)
	var actions: Variant = outing.get("actions", [])
	var all_done: bool = actions is Array and not actions.is_empty()
	var action_count := 0
	if actions is Array:
		for action_value in actions:
			if not action_value is Dictionary:
				continue
			var action_id := String(action_value.get("id", ""))
			if action_id.is_empty():
				continue
			action_count += 1
			var status := String(GameState.call("campaign_action_status", action_id)) if GameState.has_method("campaign_action_status") else "ready"
			var status_text := "待確認"
			match status:
				"locked":
					status_text = "尚未開放"
				"ready":
					status_text = "待執行"
				"active":
					status_text = "進行中"
				"done":
					status_text = "已完成"
			lines.append("現場行動：%s｜%s" % [String(action_value.get("name", action_id)), status_text])
			if GameState.has_method("campaign_action_hint"):
				var action_hint := String(GameState.call("campaign_action_hint", action_id))
				if not action_hint.is_empty():
					lines.append("　" + action_hint)
			if status != "done":
				all_done = false
	if action_count == 0:
		all_done = false
	var return_text := String(outing.get("return_text", "")).strip_edges()
	if all_done and not return_text.is_empty():
		lines.append("完成後：%s" % return_text)
	return "\n".join(lines)

func _add_campaign_field_notes(container: VBoxContainer, quest_id: String) -> void:
	if not GameState.has_method("campaign_field_notes"):
		return
	var text := String(GameState.call("campaign_field_notes", quest_id))
	if text.is_empty():
		return
	var quest_name := String(DataRegistry.get_quest(quest_id).get("name", quest_id))
	_add_journal_record(container, quest_id, "現場紀錄｜%s" % quest_name, text)

func _add_journal_record(container: VBoxContainer, record_id: String, title: String, text: String, prefix := "Campaign") -> void:
	var toggle := Button.new()
	toggle.name = "%sNotes_%s" % [prefix, record_id]
	toggle.text = "展開" + title
	toggle.toggle_mode = true
	toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toggle.add_theme_stylebox_override("normal", _button_style(false))
	container.add_child(toggle)
	var notes := Label.new()
	notes.name = "%sFieldNotes_%s" % [prefix, record_id]
	notes.text = text
	notes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	notes.add_theme_font_size_override("font_size", 14)
	notes.add_theme_color_override("font_color", Color(0.74, 0.90, 0.80))
	notes.visible = false
	container.add_child(notes)
	toggle.toggled.connect(func(expanded: bool) -> void:
		notes.visible = expanded
		toggle.text = ("收合" if expanded else "展開") + title
	)

func _campaign_consequence_summary(quest_id: String) -> String:
	if not GameState.has_method("campaign_consequence_summary"):
		return ""
	return String(GameState.call("campaign_consequence_summary", quest_id)).strip_edges()

func _campaign_completed_consequences_text() -> String:
	var lines: Array[String] = []
	for quest_id: String in DataRegistry.quest_ids():
		if not GameState.completed_quests.has(quest_id):
			continue
		var quest: Dictionary = DataRegistry.get_quest(quest_id)
		if not bool(quest.get("main_campaign", false)):
			continue
		var consequence := _campaign_consequence_summary(quest_id)
		if not consequence.is_empty():
			lines.append("%s｜%s" % [String(quest.get("name", quest_id)), consequence])
	return "\n".join(lines)

func _refresh_terminal() -> void:
	if terminal_list == null or terminal_panel == null or not terminal_panel.visible:
		return
	_refresh_modal_navigation(terminal_panel, "terminal")
	for child: Node in terminal_list.get_children():
		child.queue_free()
	var has_controller: bool = GameState.has_terminal_controller()

	if not has_controller:
		terminal_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var missing_box := PanelContainer.new()
		missing_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		missing_box.custom_minimum_size.y = 92.0
		missing_box.add_theme_stylebox_override("panel", _panel_style(Color("171518"), UI_BRONZE, 1))
		var missing_stack := VBoxContainer.new()
		missing_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		missing_stack.alignment = BoxContainer.ALIGNMENT_CENTER
		missing_stack.add_theme_constant_override("separation", 8)
		missing_box.add_child(missing_stack)

		var missing_title := Label.new()
		missing_title.text = "終端操作器尚未取得"
		missing_title.add_theme_font_size_override("font_size", 18)
		missing_title.add_theme_color_override("font_color", UI_AMBER)
		missing_stack.add_child(missing_title)

		var missing_text := Label.new()
		missing_text.text = "可在村莊或公會的 [C] 工坊製作。取得後可查看主線路線與補給；此面板只顯示配方，不會消耗材料。"
		missing_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		missing_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		missing_text.add_theme_font_size_override("font_size", 14)
		missing_stack.add_child(missing_text)
		terminal_list.add_child(missing_box)

		var locked_grid := GridContainer.new()
		locked_grid.name = "TerminalLockedGrid"
		locked_grid.columns = _terminal_grid_columns()
		locked_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		locked_grid.size_flags_vertical = Control.SIZE_FILL
		locked_grid.add_theme_constant_override("h_separation", 12)
		locked_grid.add_theme_constant_override("v_separation", 10)
		terminal_list.add_child(locked_grid)

		var recipe_box := PanelContainer.new()
		recipe_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		recipe_box.add_theme_stylebox_override("panel", _panel_style(Color("171518"), UI_BRONZE, 1))
		var recipe_stack := VBoxContainer.new()
		recipe_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		recipe_stack.add_theme_constant_override("separation", 8)
		recipe_box.add_child(recipe_stack)
		var recipe: Dictionary = DataRegistry.get_recipe("craft_terminal_controller")
		var recipe_title := Label.new()
		recipe_title.text = "[C] 工坊配方｜%s" % String(recipe.get("name", "終端操作器"))
		recipe_title.add_theme_font_size_override("font_size", 16)
		recipe_title.add_theme_color_override("font_color", UI_AMBER)
		recipe_stack.add_child(recipe_title)

		var recipe_cost: Dictionary = recipe.get("cost", {})
		var material_lines: Array[String] = []
		var can_craft := not recipe_cost.is_empty()
		for material_value in recipe_cost:
			var material_id := String(material_value)
			var required := int(recipe_cost.get(material_id, 0))
			var owned := int(GameState.inventory.get(material_id, 0))
			if owned < required:
				can_craft = false
			material_lines.append("%s　%d／%d" % [GameState.item_display_name(material_id), owned, required])

		var materials_label := Label.new()
		materials_label.text = "製作材料：\n%s" % ("\n".join(material_lines) if not material_lines.is_empty() else "配方材料尚未設定。")
		materials_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		materials_label.add_theme_font_size_override("font_size", 14)
		recipe_stack.add_child(materials_label)

		var craft_status := Label.new()
		if recipe_cost.is_empty():
			craft_status.text = "配方材料尚未設定。"
		else:
			craft_status.text = "材料已齊，可前往工坊製作。" if can_craft else "材料未齊；可先到工坊查看配方。"
		craft_status.add_theme_font_size_override("font_size", 14)
		craft_status.add_theme_color_override("font_color", Color(0.55, 0.92, 0.68) if can_craft else Color(0.88, 0.78, 0.62))
		recipe_stack.add_child(craft_status)

		var craft_at_hub := GameState.can_deliver_quest_here()
		var craft_button := Button.new()
		craft_button.text = "[C] 前往工坊製作終端操作器" if craft_at_hub else "返回村莊／公會後使用 [C] 工坊"
		craft_button.tooltip_text = "終端操作器只能在村莊或公會的 [C] 工坊製作；T 僅顯示配方。"
		craft_button.disabled = not craft_at_hub
		craft_button.custom_minimum_size = Vector2(0, 40)
		craft_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		craft_button.add_theme_stylebox_override("normal", _button_style(craft_at_hub))
		craft_button.add_theme_stylebox_override("hover", _button_style(true))
		craft_button.pressed.connect(func() -> void:
			if not GameState.can_deliver_quest_here():
				GameState.notify("終端操作器只能在村莊或公會工坊製作。")
				return
			AudioManager.play_sfx("ui")
			open_workshop("craft")
		)
		recipe_stack.add_child(craft_button)
		locked_grid.add_child(recipe_box)

		var journey_box := PanelContainer.new()
		journey_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		journey_box.add_theme_stylebox_override("panel", _panel_style(Color("171518"), UI_BRONZE, 1))
		var journey_stack := VBoxContainer.new()
		journey_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		journey_stack.add_theme_constant_override("separation", 8)
		journey_box.add_child(journey_stack)
		var journey_title := Label.new()
		journey_title.text = "目前旅程"
		journey_title.add_theme_font_size_override("font_size", 18)
		journey_title.add_theme_color_override("font_color", UI_AMBER)
		journey_stack.add_child(journey_title)
		var journey_summary := Label.new()
		journey_summary.text = GameState.get_story_summary()
		journey_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		journey_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		journey_summary.add_theme_font_size_override("font_size", 14)
		journey_stack.add_child(journey_summary)
		var journey_next_step := Label.new()
		journey_next_step.text = "下一步：%s" % GameState.get_journey_hint()
		journey_next_step.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		journey_next_step.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		journey_next_step.add_theme_font_size_override("font_size", 15)
		journey_next_step.add_theme_color_override("font_color", UI_PAPER)
		journey_stack.add_child(journey_next_step)
		var notes_prompt := Label.new()
		notes_prompt.text = "按 [K] 開啟目前手記，查看已記錄的線索。"
		notes_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		notes_prompt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		notes_prompt.add_theme_font_size_override("font_size", 14)
		journey_stack.add_child(notes_prompt)
		locked_grid.add_child(journey_box)
	else:
		terminal_list.size_flags_vertical = Control.SIZE_FILL
		var route_intro_box := PanelContainer.new()
		route_intro_box.add_theme_stylebox_override("panel", _panel_style(Color("171518"), UI_BRONZE, 1))
		var route_intro_stack := VBoxContainer.new()
		route_intro_stack.add_theme_constant_override("separation", 6)
		route_intro_box.add_child(route_intro_stack)
		var route_title := Label.new()
		route_title.text = "野外路線資料"
		route_title.add_theme_font_size_override("font_size", 18)
		route_title.add_theme_color_override("font_color", UI_AMBER)
		route_intro_stack.add_child(route_title)
		var route_intro := Label.new()
		route_intro.text = "終端操作器已取得。此處提供主線路線資訊與補給兌換；永久晶片調校請使用 [C] 工坊。"
		route_intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		route_intro.add_theme_font_size_override("font_size", 14)
		route_intro_stack.add_child(route_intro)
		terminal_list.add_child(route_intro_box)

		var action_row := HBoxContainer.new()
		action_row.add_theme_constant_override("separation", 8)
		terminal_list.add_child(action_row)

		var map_button := Button.new()
		map_button.name = "TerminalMapButton"
		map_button.text = "[M] 區域地圖"
		map_button.tooltip_text = "關閉終端並開啟區域地圖。"
		map_button.custom_minimum_size = Vector2(0, 42)
		map_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		map_button.add_theme_stylebox_override("normal", _button_style(true))
		map_button.add_theme_stylebox_override("hover", _button_style(true))
		map_button.pressed.connect(func() -> void:
			AudioManager.play_sfx("ui")
			_set_terminal_visible(false)
			set_fullscreen_map(true)
		)
		action_row.add_child(map_button)

		var notes_button := Button.new()
		notes_button.text = "[K] 目前手記"
		notes_button.tooltip_text = "關閉終端並開啟目前可讀的手記。"
		notes_button.custom_minimum_size = Vector2(0, 42)
		notes_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		notes_button.add_theme_stylebox_override("normal", _button_style(true))
		notes_button.add_theme_stylebox_override("hover", _button_style(true))
		notes_button.pressed.connect(func() -> void:
			AudioManager.play_sfx("ui")
			_set_codex_visible(true)
		)
		action_row.add_child(notes_button)

		var supply_at_hub := GameState.can_deliver_quest_here()
		var can_supply := supply_at_hub and GameState.scrap >= 20
		var supply_button := Button.new()
		supply_button.text = "補給（20 廢鐵）" if supply_at_hub else "補給需在村莊／公會"
		supply_button.tooltip_text = "消耗 20 廢鐵，兌換 16 彈藥與 1 合金板；僅限村莊／公會。"
		if not supply_at_hub:
			supply_button.tooltip_text = "請先回到村莊或公會。兌換內容：20 廢鐵換 16 彈藥與 1 合金板。"
		elif not can_supply:
			supply_button.tooltip_text = "需要 20 廢鐵，目前有 %d。兌換可獲得 16 彈藥與 1 合金板。" % GameState.scrap
		supply_button.disabled = not can_supply
		supply_button.custom_minimum_size = Vector2(0, 42)
		supply_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		supply_button.add_theme_stylebox_override("normal", _button_style(can_supply))
		supply_button.add_theme_stylebox_override("hover", _button_style(true))
		supply_button.pressed.connect(func() -> void:
			if not GameState.can_deliver_quest_here():
				GameState.notify("補給兌換僅限村莊或公會。")
				_refresh_terminal()
				return
			if not GameState.consume_item("scrap", 20):
				GameState.notify("廢鐵不足 20，無法兌換補給。")
				_refresh_terminal()
				return
			GameState.add_item("ammo", 16)
			GameState.add_item("alloy_plate", 1)
			AudioManager.play_sfx("pickup")
			GameState.notify("補給已兌換：彈藥 +16、合金板 +1。")
			_refresh_terminal()
		)
		action_row.add_child(supply_button)

		var route_grid_title := Label.new()
		route_grid_title.text = "主線委託路線"
		route_grid_title.add_theme_font_size_override("font_size", 16)
		route_grid_title.add_theme_color_override("font_color", UI_AMBER)
		terminal_list.add_child(route_grid_title)

		var route_grid := GridContainer.new()
		route_grid.name = "TerminalRouteGrid"
		route_grid.columns = _terminal_grid_columns()
		route_grid.add_theme_constant_override("h_separation", 12)
		route_grid.add_theme_constant_override("v_separation", 8)
		route_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		terminal_list.add_child(route_grid)

		for quest_value in DataRegistry.quests:
			if not (quest_value is Dictionary):
				continue
			var quest: Dictionary = quest_value
			if not bool(quest.get("main_campaign", false)):
				continue
			var quest_id := String(quest.get("id", ""))
			var route_id := String(quest.get("route", ""))
			var route: Dictionary = DataRegistry.get_wasteland_route(route_id)
			var quest_status := "前置未完成"
			var quest_status_color := Color(0.76, 0.78, 0.80)
			if GameState.completed_quests.has(quest_id):
				quest_status = "已完成"
				quest_status_color = Color(0.55, 0.92, 0.68)
			elif GameState.active_quest_id == quest_id:
				quest_status = "目前承接中"
				quest_status_color = UI_AMBER
			elif GameState.quest_prerequisites_met(quest_id):
				quest_status = "前置已完成"
				quest_status_color = Color(0.60, 0.82, 0.86)

			var route_card := PanelContainer.new()
			route_card.custom_minimum_size = Vector2(280, 0)
			route_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			route_card.add_theme_stylebox_override("panel", _panel_style(Color("171518"), UI_BRONZE, 1))
			var card_stack := VBoxContainer.new()
			card_stack.add_theme_constant_override("separation", 4)
			route_card.add_child(card_stack)

			var quest_name_label := Label.new()
			quest_name_label.text = String(quest.get("name", quest_id))
			quest_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			quest_name_label.add_theme_font_size_override("font_size", 16)
			quest_name_label.add_theme_color_override("font_color", UI_AMBER)
			card_stack.add_child(quest_name_label)

			var quest_status_label := Label.new()
			quest_status_label.text = "狀態：%s" % quest_status
			quest_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			quest_status_label.add_theme_font_size_override("font_size", 14)
			quest_status_label.add_theme_color_override("font_color", quest_status_color)
			card_stack.add_child(quest_status_label)

			var route_details := Label.new()
			route_details.text = "路線：%s ｜ 建議等級 %d" % [String(route.get("name", route_id)), int(quest.get("recommended_level", 1))]
			route_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			route_details.add_theme_font_size_override("font_size", 14)
			card_stack.add_child(route_details)

			var resource_names: Array[String] = []
			var seen_resources: Dictionary = {}
			var resource_mix: Variant = route.get("resource_mix", [])
			if resource_mix is Array:
				for material_value in resource_mix:
					var material_id := String(material_value)
					if material_id.is_empty() or seen_resources.has(material_id):
						continue
					seen_resources[material_id] = true
					resource_names.append(GameState.item_display_name(material_id))
			var resource_label := Label.new()
			resource_label.text = "資源：%s" % ("、".join(resource_names) if not resource_names.is_empty() else "未設定")
			resource_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			resource_label.add_theme_font_size_override("font_size", 14)
			card_stack.add_child(resource_label)

			var enemy_names: Array[String] = []
			var seen_enemies: Dictionary = {}
			var enemy_mix: Variant = route.get("enemy_mix", [])
			if enemy_mix is Array:
				for enemy_value in enemy_mix:
					var enemy_id := String(enemy_value)
					if enemy_id.is_empty() or seen_enemies.has(enemy_id):
						continue
					seen_enemies[enemy_id] = true
					var enemy: Dictionary = DataRegistry.get_enemy(enemy_id)
					enemy_names.append(String(enemy.get("name", enemy_id)))
			var enemy_label := Label.new()
			enemy_label.text = "敵群：%s" % ("、".join(enemy_names) if not enemy_names.is_empty() else "未設定")
			enemy_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			enemy_label.add_theme_font_size_override("font_size", 14)
			card_stack.add_child(enemy_label)
			route_grid.add_child(route_card)

	if has_controller:
		var journey_box := PanelContainer.new()
		journey_box.add_theme_stylebox_override("panel", _panel_style(Color("171518"), UI_BRONZE, 1))
		var journey_stack := VBoxContainer.new()
		journey_stack.add_theme_constant_override("separation", 4)
		journey_box.add_child(journey_stack)
		var journey_title := Label.new()
		journey_title.text = "目前旅程"
		journey_title.add_theme_font_size_override("font_size", 16)
		journey_title.add_theme_color_override("font_color", UI_AMBER)
		journey_stack.add_child(journey_title)
		var journey_summary := Label.new()
		journey_summary.text = GameState.get_story_summary()
		journey_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		journey_summary.add_theme_font_size_override("font_size", 14)
		journey_stack.add_child(journey_summary)
		var notes_prompt := Label.new()
		notes_prompt.text = "按 [K] 開啟目前手記，查看已記錄的線索。"
		notes_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		notes_prompt.add_theme_font_size_override("font_size", 14)
		journey_stack.add_child(notes_prompt)
		terminal_list.add_child(journey_box)

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

func _add_equipment_card(container: VBoxContainer, slot: String, label: String, width: float = 660.0) -> void:
	var item_id: String = String(GameState.equipment.get(slot, ""))
	var equipment: Dictionary = DataRegistry.get_equipment(item_id)
	var card_width := maxf(1.0, width)
	var row_width := maxf(1.0, card_width - 28.0)
	var icon_width := minf(150.0, maxf(72.0, row_width * 0.30))
	var text_width := maxf(80.0, row_width - icon_width - 40.0)
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(card_width, 92)
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
	row.size = Vector2(row_width, 80)
	row.add_theme_constant_override("separation", 16)
	button.add_child(row)

	var icon_box: PanelContainer = PanelContainer.new()
	icon_box.custom_minimum_size = Vector2(icon_width, 78)
	icon_box.size = Vector2(icon_width, 78)
	icon_box.clip_contents = true
	icon_box.add_theme_stylebox_override("panel", _panel_style(Color(0.02, 0.02, 0.018, 0.22), Color(0.12, 0.18, 0.18, 0.35), 0))
	row.add_child(icon_box)
	var icon_size := Vector2(maxf(32.0, icon_width - 18.0), 72.0)
	var icon: TextureRect = _fit_texture_rect(_item_icon(item_id), icon_size)
	icon.position = Vector2((icon_width - icon_size.x) * 0.5, 3.0)
	icon_box.add_child(icon)

	var divider: VSeparator = VSeparator.new()
	divider.custom_minimum_size = Vector2(8, 70)
	row.add_child(divider)

	var text_stack: VBoxContainer = VBoxContainer.new()
	text_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	text_stack.custom_minimum_size = Vector2(text_width, 78)
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
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color(0.96, 0.95, 0.90))
	text_stack.add_child(name_label)

	var info_label: Label = Label.new()
	info_label.text = "%s｜%s" % [_equipment_stats_text(equipment), _source_short_text(equipment)]
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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

func _add_upgrade_button(container: Container, label: String, kind: String) -> void:
	var button: Button = Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(90, 40)
	var field_locked := GameState.current_scene_id == "wasteland"
	button.disabled = GameState.upgrade_points <= 0 or field_locked
	if field_locked:
		button.tooltip_text = "回村莊或公會後才能購買永久升級。"
	button.add_theme_stylebox_override("normal", _button_style(false))
	button.add_theme_stylebox_override("hover", _button_style(true))
	button.pressed.connect(func() -> void:
		if GameState.spend_upgrade_point(kind):
			_refresh_inventory()
	)
	container.add_child(button)

func _add_weapon_forge_button(container: Container, slot: String, prefix: String) -> void:
	var item_id := String(GameState.equipment.get(slot, ""))
	var lvl := GameState.get_weapon_level(item_id)
	var cost := GameState.get_weapon_upgrade_cost(item_id)
	var button: Button = Button.new()
	button.text = ("%s Lv.MAX" % prefix) if lvl >= 5 else ("%s Lv.%d→%d (鐵%d)" % [prefix, lvl, lvl + 1, cost])
	button.custom_minimum_size = Vector2(160, 40)
	var field_locked := GameState.current_scene_id == "wasteland"
	button.disabled = lvl >= 5 or GameState.scrap < cost or field_locked
	if field_locked:
		button.tooltip_text = "回村莊或公會後才能強化裝備。"
	button.add_theme_stylebox_override("normal", _button_style(false))
	button.add_theme_stylebox_override("hover", _button_style(true))
	button.pressed.connect(func() -> void:
		if GameState.upgrade_weapon_level(item_id):
			_refresh_inventory()
	)
	container.add_child(button)

func _add_bag_button(container: GridContainer, item_id: String, amount: int, button_width: float = 285.0) -> void:
	if DataRegistry.get_equipment(item_id).is_empty():
		var status_card := PanelContainer.new()
		status_card.custom_minimum_size = Vector2(button_width, 60)
		status_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		status_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		status_card.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.047, 0.051, 0.94), Color(0.29, 0.43, 0.37, 0.80), 1))
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 8)
		status_card.add_child(row)
		row.add_child(_fit_texture_rect(_item_icon(item_id), Vector2(42, 42)))
		var labels := VBoxContainer.new()
		labels.alignment = BoxContainer.ALIGNMENT_CENTER
		labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		labels.add_theme_constant_override("separation", 2)
		row.add_child(labels)
		var name_label := Label.new()
		name_label.text = "%s x%d" % [GameState.item_display_name(item_id), amount]
		_wrap_workshop_label(name_label)
		name_label.add_theme_font_size_override("font_size", 14)
		name_label.add_theme_color_override("font_color", Color(0.83, 0.90, 0.83))
		labels.add_child(name_label)
		var kind_label := Label.new()
		kind_label.text = "材料／資源｜不可裝備"
		_wrap_workshop_label(kind_label)
		kind_label.add_theme_font_size_override("font_size", 11)
		kind_label.add_theme_color_override("font_color", Color(0.62, 0.74, 0.68))
		labels.add_child(kind_label)
		container.add_child(status_card)
		return
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(button_width, 60)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.text = "%s x%d" % [GameState.item_display_name(item_id), amount]
	button.icon = _item_icon(item_id)
	button.expand_icon = true
	button.tooltip_text = "點擊裝備：%s" % String(DataRegistry.get_equipment(item_id).get("obtain_hint", GameState.item_display_name(item_id)))
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

func _show_npc_dialogue(owner: Node, speaker: String, role: String, message: String) -> void:
	_show_dialogue_with_owner(speaker, role, message, owner)

func _set_dialogue_npc_owner(owner: Node) -> void:
	var next_owner: Node = owner if is_instance_valid(owner) else null
	if is_instance_valid(_dialogue_npc_owner) and _dialogue_npc_owner == next_owner:
		if dialogue_panel != null:
			dialogue_panel.set_meta("dialogue_npc_owner_id", _dialogue_npc_owner.get_instance_id())
		return
	_clear_dialogue_npc_owner()
	_dialogue_npc_owner = next_owner
	if dialogue_panel != null:
		dialogue_panel.set_meta("dialogue_npc_owner_id", _dialogue_npc_owner.get_instance_id() if is_instance_valid(_dialogue_npc_owner) else 0)

func _clear_dialogue_npc_owner() -> void:
	var previous_owner: Node = _dialogue_npc_owner
	_dialogue_npc_owner = null
	if dialogue_panel != null:
		dialogue_panel.set_meta("dialogue_npc_owner_id", 0)
	if is_instance_valid(previous_owner) and previous_owner.has_method("reset_dialogue_state"):
		previous_owner.call("reset_dialogue_state")

func _show_dialogue(speaker: String, role: String, message: String) -> void:
	_show_dialogue_with_owner(speaker, role, message, null)

func _show_dialogue_with_owner(speaker: String, role: String, message: String, npc_owner: Node) -> void:
	_set_dialogue_npc_owner(npc_owner)
	for panel: Control in [inventory_panel, workshop_panel, contract_panel, terminal_panel, codex_panel, tutorial_panel, atlas_panel, expedition_draft_panel, campaign_choice_panel]:
		if panel != null:
			panel.visible = false
	map_fullscreen = false
	if _journal_paused_tree or _atlas_paused_tree or _tutorial_paused_tree or _draft_paused_tree or _campaign_choice_paused_tree:
		_journal_paused_tree = false
		_atlas_paused_tree = false
		_tutorial_paused_tree = false
		_draft_paused_tree = false
		_campaign_choice_paused_tree = false
		get_tree().paused = _story_paused_tree or pause_panel.visible
	if role.contains("劇情線索") and not get_tree().paused:
		_story_paused_tree = true
		get_tree().paused = true
	dialogue_speaker.text = speaker
	dialogue_role.text = role
	if dialogue_hint != null:
		if is_instance_valid(_dialogue_npc_owner):
			var e_hint := "[E] 結束對話"
			if _dialogue_npc_owner.has_method("is_dialogue_final_page") and not bool(_dialogue_npc_owner.call("is_dialogue_final_page")):
				e_hint = "[E] 下一段"
			dialogue_hint.text = "%s ｜ [Esc] 關閉 ｜ PageUp／PageDown 或滾輪閱讀 ｜ [K] 回收者手記" % e_hint
		elif role.contains("劇情線索"):
			dialogue_hint.text = "PageUp／PageDown 或滾輪閱讀線索 ｜ [Esc] 關閉 ｜ [K] 回收者手記"
		elif role in ["撤離回報", "機體回收", "委託回報"]:
			dialogue_hint.text = "PageUp／PageDown 或滾輪閱讀回報 ｜ [Esc] 關閉 ｜ [K] 回收者手記"
		else:
			dialogue_hint.text = "PageUp／PageDown 或滾輪閱讀 ｜ [Esc] 關閉 ｜ [K] 回收者手記"
	dialogue_body.text = message
	var scroll := dialogue_body.get_parent() as ScrollContainer
	if scroll != null:
		scroll.scroll_vertical = 0
	dialogue_portrait.texture = _npc_portrait_texture(speaker)
	dialogue_panel.visible = true
	if dialogue_timer != null:
		dialogue_timer.stop()
	_refresh_overlay_visibility()

func _hide_dialogue() -> void:
	if dialogue_panel == null:
		return
	_clear_dialogue_npc_owner()
	if _story_paused_tree:
		_story_paused_tree = false
		get_tree().paused = _journal_paused_tree or _atlas_paused_tree or _tutorial_paused_tree or _draft_paused_tree or _campaign_choice_paused_tree or pause_panel.visible
	dialogue_panel.visible = false
	if dialogue_timer != null:
		dialogue_timer.stop()
	_refresh_overlay_visibility()
	if not pause_panel.visible:
		call_deferred("_sync_campaign_choice")

func _on_npc_dialogue_closed(owner: Node) -> void:
	if not dialogue_panel.visible or not is_instance_valid(owner) or not is_instance_valid(_dialogue_npc_owner):
		return
	if _dialogue_npc_owner != owner or int(dialogue_panel.get_meta("dialogue_npc_owner_id", 0)) != owner.get_instance_id():
		return
	_hide_dialogue()

func _npc_portrait_texture(speaker: String) -> Texture2D:
	for npc: Dictionary in DataRegistry.npcs:
		var npc_name := String(npc.get("name", ""))
		if npc_name == speaker or npc_name.ends_with(" " + speaker):
			var portrait_id: String = String(npc.get("portrait_asset_id", npc.get("sprite_asset_id", "")))
			var path: String = DataRegistry.asset_path(portrait_id)
			if not path.is_empty():
				var texture: Texture2D = ASSET_LOADER.load_png(path)
				if texture != null:
					return texture
	for event in DataRegistry.events:
		if bool(event.get("story", false)) and String(event.get("name", "")) == speaker:
			var route := DataRegistry.get_wasteland_route(String(event.get("route", "")))
			var path := DataRegistry.asset_path("prop_%s" % String(route.get("landmark_prop", "")))
			if not path.is_empty():
				return ASSET_LOADER.load_png(path)
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
	modal_covers_notice = modal_covers_notice or (atlas_panel != null and atlas_panel.visible)
	modal_covers_notice = modal_covers_notice or (expedition_draft_panel != null and expedition_draft_panel.visible)
	modal_covers_notice = modal_covers_notice or (campaign_choice_panel != null and campaign_choice_panel.visible)
	modal_covers_notice = modal_covers_notice or (tutorial_panel != null and tutorial_panel.visible)
	modal_covers_notice = modal_covers_notice or (pause_panel != null and pause_panel.visible)
	modal_covers_notice = modal_covers_notice or (death_recovery_panel != null and death_recovery_panel.visible)
	modal_covers_notice = modal_covers_notice or map_fullscreen
	modal_covers_notice = modal_covers_notice or (dialogue_panel != null and dialogue_panel.visible)
	modal_covers_notice = modal_covers_notice or SceneRouter.is_transition_pending()
	# Keep the current notice (including save failures) readable after a story panel.
	if notice_timer != null:
		notice_timer.paused = modal_covers_notice
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
	style.set_corner_radius_all(0)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style

func _button_style(active: bool) -> StyleBoxFlat:
	var bg: Color = Color("3b2c1c") if active else UI_CHARCOAL
	var border: Color = UI_AMBER if active else UI_BRONZE
	var st := _panel_style(bg, border, 2 if active else 1)
	if active:
		st.border_width_top = 4
	return st
