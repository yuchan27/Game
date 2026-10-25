extends Node

signal stats_changed
signal inventory_changed
signal equipment_changed
signal scene_changed(scene_id: String)
signal notification_requested(message: String)
signal dialogue_requested(speaker: String, role: String, message: String)
signal dialogue_closed
signal npc_dialogue_requested(owner: Node, speaker: String, role: String, message: String)
signal npc_dialogue_closed(owner: Node)
signal expedition_draft_changed
signal campaign_changed
signal campaign_choice_requested(action_id: String)
signal feedback_requested(kind: String, strength: float)

const MAX_HP := 120
const MAX_EP := 60
const SAVE_VERSION := 5
# Exact mutable fields for in-memory rollback; this is separate from the save payload schema.
const RUNTIME_STATE_FIELDS := [
	"current_scene_id", "active_spawn_point", "current_route_id", "seed", "level", "xp",
	"upgrade_points", "hp_upgrade_level", "ep_upgrade_level", "attack_upgrade_level", "defense_upgrade_level",
	"hp", "ep", "ammo", "scrap", "cores", "crystals", "player_position", "defeated_enemies",
	"discovered_events", "talked_npcs", "active_quest_id", "completed_quests", "quest_progress", "route_states",
	"intro_seen", "death_pending", "_last_ammo_spend", "inventory", "quick_slots", "active_quick_slot",
	"equipment", "weapon_levels", "perks", "_death_sequence_generation", "_campaign_runtime_generation"
]
const EXPEDITION_SCRIPT := preload("res://scripts/systems/ExpeditionLedger.gd")
const CAMPAIGN_SCRIPT := preload("res://scripts/systems/CampaignProgress.gd")
const FIELD_OBJECTIVE_VERSION_KEY := "field_objective_version"
const FIELD_OBJECTIVE_VERSION := 1
const UNSAVED_RESULT_WARNING := "【自動存檔失敗】以下結果目前只保留在本次遊戲中，尚未寫入本機存檔。離開前請按 [Esc] 關閉此回報，再按 [Esc] 開啟暫停選單重新儲存；讀取舊檔會回到先前進度。\n"
const DEFAULT_EQUIPMENT := {
	"weapon": "rust_blade",
	"ranged": "pipe_rifle",
	"armor": "patched_armor",
	"tool": "recycler_glove"
}

var current_scene_id := "village"
var active_spawn_point := "default"
var current_route_id := "scrap_highway"
var seed := 9527
var level := 1
var xp := 0
var upgrade_points := 0
var hp_upgrade_level := 0
var ep_upgrade_level := 0
var attack_upgrade_level := 0
var defense_upgrade_level := 0
var hp := MAX_HP
var ep := MAX_EP
var ammo := 18
var scrap := 40
var cores := 2
var crystals := 0
var player_position := Vector2.ZERO
var defeated_enemies := 0
var discovered_events: Array[String] = []
var talked_npcs: Array[String] = []
var active_quest_id := ""
var completed_quests: Array[String] = []
var quest_progress: Dictionary = {}
var route_states: Dictionary = {}
var intro_seen := false
var death_pending := false
var _expedition := EXPEDITION_SCRIPT.new()
var _last_ammo_spend: Dictionary = {}
var _death_sequence_generation := 0
# Invalidates action nodes that captured ownership before a run replacement or save load.
var _campaign_runtime_generation := 0
var inventory: Dictionary = {}
var quick_slots: Array[String] = ["rust_blade", "pipe_rifle", "recycler_glove", "ammo"]
var active_quick_slot := 0
var equipment: Dictionary = {
	"weapon": "rust_blade",
	"ranged": "pipe_rifle",
	"armor": "patched_armor",
	"tool": "recycler_glove"
}
var weapon_levels: Dictionary = {}
var perks: Dictionary = {}

const PERKS_CATALOG := {
	"arc_overload": {
		"id": "arc_overload",
		"name": "高壓電弧 (Arc Overload)",
		"desc": "遠程命中時，連鎖打擊 140 範圍內最多 2 名其他敵人；依等級造成 16／24／32 傷害。",
		"max_level": 3,
		"icon": "⚡"
	},
	"vibro_rend": {
		"id": "vibro_rend",
		"name": "高週波撕裂 (Vibro-Rend)",
		"desc": "近戰每次命中追加 12／18／24 傷害（依等級），並額外擊退目標。",
		"max_level": 3,
		"icon": "🩸"
	},
	"nano_salvage": {
		"id": "nano_salvage",
		"name": "奈米回收力場 (Nano Salvage Field)",
		"desc": "拾取任意掉落物時，恢復生命與能量各 7／10／13 點（依等級），並擊退 120 範圍內敵人。",
		"max_level": 3,
		"icon": "🛡"
	},
	"dodge_blast": {
		"id": "dodge_blast",
		"name": "破片推進 (Dodge Blast)",
		"desc": "閃避時在起點釋放衝擊，對 100 範圍內敵人造成 24／34／44 傷害（依等級）並擊退。",
		"max_level": 3,
		"icon": "💥"
	},
	"armor_piercer": {
		"id": "armor_piercer",
		"name": "破甲貫通 (Armor Piercer)",
		"desc": "遠程投射物每級可再穿透 1 名敵人，命中後仍可繼續攻擊後方目標。",
		"max_level": 3,
		"icon": "🏹"
	},
	"scavenger_savant": {
		"id": "scavenger_savant",
		"name": "拾荒大師 (Scavenger Savant)",
		"desc": "拾取廢鐵與裝備拆解的產量每級增加 40%；拆解加成適用於配方列出的各項材料。",
		"max_level": 3,
		"icon": "♻"
	}
}

func _ready() -> void:
	_ensure_input_actions()
	reset_new_run(false)

func reset_new_run(emit_changes := true) -> void:
	_death_sequence_generation += 1
	_campaign_runtime_generation += 1
	_expedition.clear()
	_last_ammo_spend.clear()
	current_scene_id = "village"
	active_spawn_point = "default"
	current_route_id = "scrap_highway"
	seed = 9527
	level = 1
	xp = 0
	upgrade_points = 0
	hp_upgrade_level = 0
	ep_upgrade_level = 0
	attack_upgrade_level = 0
	defense_upgrade_level = 0
	hp = MAX_HP
	ep = MAX_EP
	ammo = 18
	scrap = 40
	cores = 2
	crystals = 0
	player_position = Vector2.ZERO
	defeated_enemies = 0
	discovered_events.clear()
	talked_npcs.clear()
	active_quest_id = ""
	completed_quests.clear()
	quest_progress.clear()
	route_states.clear()
	intro_seen = false
	death_pending = false
	active_quick_slot = 0
	inventory = {
		"scrap": scrap,
		"ammo": ammo,
		"mutant_core": cores,
		"rust_blade": 1,
		"spark_cutter": 1,
		"pipe_rifle": 1,
		"coil_launcher": 1,
		"patched_armor": 1,
		"recycler_glove": 1
	}
	quick_slots = ["rust_blade", "pipe_rifle", "recycler_glove", "ammo"]
	equipment = {
		"weapon": "rust_blade",
		"ranged": "pipe_rifle",
		"armor": "patched_armor",
		"tool": "recycler_glove"
	}
	weapon_levels.clear()
	perks.clear()
	if emit_changes:
		_emit_all()

func get_max_hp() -> int:
	return MAX_HP + hp_upgrade_level * 20

func get_max_ep() -> int:
	return MAX_EP + ep_upgrade_level * 10

func set_scene(scene_id: String, spawn_point := "default") -> void:
	current_scene_id = scene_id
	active_spawn_point = spawn_point
	scene_changed.emit(scene_id)

func set_current_route(route_id: String) -> void:
	if has_active_expedition() and String(_expedition.active["route"]) != route_id:
		notify("請先從返村門撤離，再選擇另一條路線。")
		return
	if DataRegistry.get_wasteland_route(route_id).is_empty():
		notify("未知的廢土路線：%s" % route_id)
		return
	current_route_id = route_id
	var route := DataRegistry.get_wasteland_route(route_id)
	notify("路線已切換：%s" % String(route.get("name", route_id)))
	stats_changed.emit()

func mark_intro_seen() -> void:
	intro_seen = true

func has_active_expedition() -> bool:
	return not _expedition.active.is_empty()

func is_legacy_expedition() -> bool:
	return _expedition.legacy_trip

func begin_expedition() -> bool:
	if current_scene_id != "wasteland" or death_pending or _expedition.legacy_trip:
		return false
	if has_active_expedition():
		return String(_expedition.active["route"]) == current_route_id
	_expedition.begin(current_route_id, active_quest_id)
	_campaign_runtime_generation += 1
	if has_authored_campaign() and DataRegistry.get_quest(active_quest_id).get("route", "") == current_route_id:
		_expedition.active["campaign_outing"] = campaign_outing().get("id", "")
	_sync_resource_counters()
	stats_changed.emit()
	return true

func add_field_item(item_id: String, amount := 1) -> void:
	if amount <= 0 or death_pending or hp <= 0:
		return
	if not has_active_expedition():
		add_item(item_id, amount)
		return
	var haul: Dictionary = _expedition.active["haul"]
	haul[item_id] = int(haul.get(item_id, 0)) + amount
	_sync_resource_counters()
	inventory_changed.emit()
	stats_changed.emit()

func quest_item_count(item_id: String) -> int:
	var haul: Dictionary = _expedition.active.get("haul", {})
	return int(inventory.get(item_id, 0)) + int(haul.get(item_id, 0))

func quest_counter_value(counter: String) -> int:
	var counters: Dictionary = _expedition.active.get("counters", {})
	return int(quest_progress.get(counter, 0)) + int(counters.get(counter, 0))

func has_field_claim(key: String) -> bool:
	return discovered_events.has(key) or _expedition.active.get("claims", []).has(key)

func record_field_claim(key: String) -> void:
	if has_field_claim(key):
		return
	if has_active_expedition():
		_expedition.active["claims"].append(key)
	else:
		discovered_events.append(key)

func has_run_source(key: String) -> bool:
	return _expedition.active.get("sources", []).has(key)

func record_run_source(key: String) -> void:
	if has_active_expedition() and not has_run_source(key):
		_expedition.active["sources"].append(key)

func expedition_positions(pool: String, generated: Array) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	if not has_active_expedition():
		for position: Vector2 in generated:
			positions.append(position)
		return positions
	# Saved-position safety can change generated exclusions. Preserve source identities.
	var layout: Dictionary = _expedition.active.get("layout", {})
	if not layout.has(pool):
		var saved: Array = []
		for position: Vector2 in generated:
			saved.append([position.x, position.y])
		layout[pool] = saved
		_expedition.active["layout"] = layout
	for position: Array in layout[pool]:
		positions.append(Vector2(float(position[0]), float(position[1])))
	return positions

func record_story_discovery(route_id: String, event_id: String) -> void:
	if has_story_discovery(route_id, event_id):
		return
	var key := "%s:%s" % [route_id, event_id]
	discovered_events.append(key)
	if has_active_expedition() and not _expedition.uncommitted_clues.has(key):
		_expedition.uncommitted_clues.append(key)

func _quest_discovery_ready(route_id: String, event_id: String) -> bool:
	if not has_story_discovery(route_id, event_id):
		return false
	return not _expedition.uncommitted_clues.has("%s:%s" % [route_id, event_id]) or (has_active_expedition() and current_route_id == route_id)

func story_discovery_needs_extraction(route_id: String, event_id: String) -> bool:
	return _expedition.uncommitted_clues.has("%s:%s" % [route_id, event_id])

func settle_expedition(extracted: bool, emit_changes := true) -> Dictionary:
	var result: Dictionary = _expedition.finish("extracted" if extracted else "lost")
	if result.is_empty():
		return {}
	_campaign_runtime_generation += 1
	if extracted:
		for item_id: String in result["haul"]:
			inventory[item_id] = int(inventory.get(item_id, 0)) + int(result["haul"][item_id])
		if result["quest_id"] == active_quest_id:
			for counter: String in result["counters"]:
				quest_progress[counter] = int(quest_progress.get(counter, 0)) + int(result["counters"][counter])
			var state: Dictionary = route_states.get(result["route"], {}).duplicate(true)
			var fields: Dictionary = state.get("field_objectives", {}).duplicate(true)
			fields.merge(result["fields"], true)
			if not fields.is_empty():
				state["field_objectives"] = fields
				route_states[result["route"]] = state
			_settle_campaign_outing(result)
		for key: String in result["claims"]:
			if not discovered_events.has(key):
				discovered_events.append(key)
		for index in range(_expedition.uncommitted_clues.size() - 1, -1, -1):
			if _expedition.uncommitted_clues[index].begins_with(String(result["route"]) + ":"):
				_expedition.uncommitted_clues.remove_at(index)
	_last_ammo_spend.clear()
	_sync_resource_counters()
	if emit_changes:
		_emit_all()
		campaign_changed.emit()
	return _expedition.last_result.duplicate(true)

func show_expedition_result(result: Dictionary, saved := true) -> void:
	var body := expedition_result_text(result, saved)
	if not body.is_empty():
		var extracted: bool = result.get("outcome", "") == "extracted"
		dialogue_requested.emit("米婭" if extracted else "艾達", "撤離回報" if extracted else "機體回收", body)

func last_expedition_report() -> String:
	if _expedition.last_result.is_empty():
		return ""
	return "上次出征回報（當時狀態）；目前目標以 [J] 為準。\n" + expedition_result_text(_expedition.last_result)

func expedition_result_text(result: Dictionary, saved := true) -> String:
	if result.is_empty():
		return ""
	var extracted: bool = result.get("outcome", "") == "extracted"
	var route := DataRegistry.get_wasteland_route(String(result.get("route", "")))
	var body := "路線：%s｜%s\n" % [String(route.get("name", "廢土")), "安全撤離" if extracted else "機體回收"]
	body += ("已入庫：%s" if extracted else "本趟遺失：%s") % _haul_summary(result.get("haul", {}))
	var quest_id := String(result.get("quest_id", ""))
	var quest := DataRegistry.get_quest(quest_id)
	var outing_id := String(result.get("campaign_outing", ""))
	var outing := CAMPAIGN_SCRIPT.outing_by_id(quest_id, outing_id)
	if not outing.is_empty():
		var receipt := CAMPAIGN_SCRIPT.action_receipt(quest_id, outing_id, result.get("campaign_actions", {}))
		body += "\n章節行動：%s" % String(outing.get("name", ""))
		if receipt.is_empty():
			if String(result.get("campaign_report", "")).is_empty():
				body += "\n本趟沒有新的完整章節步驟；先前已帶回的步驟仍保留。"
		else:
			body += "\n%s\n%s" % ["本趟已帶回：" if extracted else "本趟未帶回，下次仍需重做：", receipt]
	else:
		if not quest.is_empty():
			body += "\n委託：%s" % String(quest.get("name", quest_id))
		var field: Dictionary = quest.get("field_objective", {})
		if not field.is_empty() and result.get("fields", {}).has(String(field.get("id", ""))):
			body += "\n現場目標：%s（%s）。" % [String(field.get("name", "現場行動")), "已帶回" if extracted else "未帶回，下趟需重新完成"]
	var campaign_report := String(result.get("campaign_report", ""))
	if not campaign_report.is_empty():
		body += "\n\n" + campaign_report
	if not extracted and not outing.is_empty():
		body += "\n未完成的計時、護送與搬運位置下次重新開始；可在 [J] 核對已帶回的步驟。"
	body += "\n\n本趟已完成的清剿與現場行動已保留；未達成的目標仍需繼續。委託報酬另按 [J] 交付。" if extracted else "\n\n已入庫裝備、未使用的既有物資、等級與線索手記保留。本趟清剿及現場行動未保留；新線索的任務成果仍需到原路線安全撤離。"
	body += "\n已使用的彈藥不退還。"
	if not result.get("draft_choices", {}).is_empty():
		body += "\n本趟戰地調校已卸載；永久晶片不受影響。"
	return body if saved else UNSAVED_RESULT_WARNING + body

func expedition_summary() -> String:
	if _expedition.legacy_trip:
		return "舊旅程｜首次返村前沿用原有保留規則"
	if not has_active_expedition():
		return "據點整備｜物資已入庫"
	var haul: Dictionary = _expedition.active["haul"]
	var count := 0
	for amount: Variant in haul.values():
		count += int(amount)
	return "出征中｜待帶回 %d 件物資 [I]" % count

func expedition_haul_summary() -> String:
	return _haul_summary(_expedition.active.get("haul", {}))

func _haul_summary(haul: Dictionary) -> String:
	var parts: Array[String] = []
	for item_id: String in haul:
		if int(haul[item_id]) > 0:
			parts.append("%s x%d" % [item_display_name(item_id), int(haul[item_id])])
	return "、".join(parts) if not parts.is_empty() else "無"

func has_authored_campaign() -> bool:
	return not active_quest_id.is_empty() and quest_progress.get("campaign", {}) is Dictionary and not quest_progress.get("campaign", {}).is_empty()

func campaign_outing() -> Dictionary:
	return CAMPAIGN_SCRIPT.current(active_quest_id, quest_progress["campaign"]) if has_authored_campaign() else {}

func _campaign_run_matches() -> bool:
	return has_active_expedition() and not death_pending and hp > 0 and current_scene_id == "wasteland" and _expedition.active.get("quest_id", "") == active_quest_id and _expedition.active.get("route", "") == current_route_id and not campaign_outing().is_empty() and _expedition.active.get("campaign_outing", "") == campaign_outing().get("id", "")

func _campaign_results() -> Dictionary:
	var results: Dictionary = quest_progress.get("campaign", {}).get("actions", {}).duplicate(true)
	if _campaign_run_matches():
		results.merge(_expedition.active.get("campaign_actions", {}), true)
	return results

func campaign_action_status(action_id: String) -> String:
	var entry := campaign_outing()
	var definition := CAMPAIGN_SCRIPT.action(active_quest_id, action_id, String(entry.get("id", "")))
	if entry.is_empty() or definition.is_empty():
		return "locked"
	var results := _campaign_results()
	if results.has(action_id):
		return "done"
	if not _campaign_run_matches():
		return "locked"
	for requirement: String in definition.get("requires", []):
		if not results.has(requirement):
			return "locked"
	return "active" if bool(campaign_action_progress(action_id).get("started", false)) else "ready"

func campaign_action_progress(action_id: String) -> Dictionary:
	return _expedition.active.get("campaign_runtime", {}).get(action_id, {}).duplicate(true) if _campaign_run_matches() else {}

func campaign_action_owner() -> Dictionary:
	if not _campaign_run_matches():
		return {}
	return {
		"generation": _campaign_runtime_generation,
		"run_id": String(_expedition.active.get("id", "")),
		"quest_id": active_quest_id,
		"route_id": current_route_id,
		"outing_id": String(_expedition.active.get("campaign_outing", ""))
	}

func update_campaign_action(action_id: String, progress: Dictionary, expected_owner: Dictionary = {}) -> bool:
	var current_owner := campaign_action_owner()
	var owner := expected_owner if not expected_owner.is_empty() else current_owner
	if current_owner.is_empty() or owner != current_owner:
		return false
	if campaign_action_status(action_id) not in ["ready", "active"]:
		return false
	var definition := CAMPAIGN_SCRIPT.action(active_quest_id, action_id, String(campaign_outing()["id"]))
	if not CAMPAIGN_SCRIPT.valid_runtime(definition, progress):
		return false
	var previous: Dictionary = _expedition.active["campaign_runtime"].get(action_id, {})
	var step_changed := bool(previous.get("started", false)) != bool(progress.get("started", false)) or int(previous.get("checkpoint", 0)) != int(progress.get("checkpoint", 0))
	# Timers and actor coordinates enter the normal save snapshot, never per-frame IO.
	_expedition.active["campaign_runtime"][action_id] = progress.duplicate(true)
	if step_changed:
		campaign_changed.emit()
	return true

func complete_campaign_action(action_id: String, result := "done") -> bool:
	if campaign_action_status(action_id) != "active":
		return false
	var definition := CAMPAIGN_SCRIPT.action(active_quest_id, action_id, String(campaign_outing()["id"]))
	if not CAMPAIGN_SCRIPT.valid_result(definition, result) or not _campaign_action_finished(definition):
		return false
	# Record first; signals/repeated button callbacks cannot award twice.
	_expedition.active["campaign_actions"][action_id] = result
	_expedition.active["campaign_runtime"].erase(action_id)
	var field_id := String(definition.get("field_objective", ""))
	if not field_id.is_empty():
		_expedition.active["fields"][field_id] = true
	var selected := CAMPAIGN_SCRIPT.option(definition, result)
	for item_id: String in selected.get("reward", {}):
		add_field_item(item_id, int(selected["reward"][item_id]))
	notify("現場完成：%s。成果待安全帶回；現場紀錄 [K]。" % String(definition.get("name", action_id)))
	campaign_changed.emit()
	stats_changed.emit()
	if not SaveManager.save_game(false):
		notify("現場成果目前只在記憶中，自動存檔未成功；請在暫停選單重試儲存。成果仍須安全返村。")
	return true

func _campaign_action_finished(definition: Dictionary) -> bool:
	var progress := campaign_action_progress(String(definition["id"]))
	if not bool(progress.get("started", false)):
		return false
	var kind := String(definition.get("type", ""))
	if kind == "choice":
		return true
	if kind in ["channel", "defend"]:
		var choice_action_id := String(definition.get("route_choice", ""))
		var selected_choice_id := campaign_selected_choice(choice_action_id) if not choice_action_id.is_empty() else ""
		var duration := CAMPAIGN_SCRIPT.effective_duration(definition, campaign_outing().get("actions", []), selected_choice_id)
		if float(progress.get("elapsed", 0.0)) < duration:
			return false
	var selected := CAMPAIGN_SCRIPT.option(CAMPAIGN_SCRIPT.action(active_quest_id, String(definition.get("route_choice", ""))), campaign_selected_choice(String(definition.get("route_choice", ""))))
	if kind in ["escort", "carry"]:
		var waypoints: Array = selected.get("waypoints", definition.get("waypoints", []))
		return not waypoints.is_empty() and int(progress.get("checkpoint", 0)) >= waypoints.size()
	if kind == "defend":
		return int(progress.get("checkpoint", 0)) >= int(definition.get("waves", 0))
	return kind == "channel"

func request_campaign_choice(action_id: String) -> bool:
	if campaign_action_status(action_id) not in ["ready", "active"]:
		return false
	var definition := CAMPAIGN_SCRIPT.action(active_quest_id, action_id, String(campaign_outing()["id"]))
	if definition.get("type", "") != "choice":
		return false
	var progress := campaign_action_progress(action_id)
	progress["started"] = true
	if not update_campaign_action(action_id, progress, campaign_action_owner()):
		return false
	if not SaveManager.save_game(false):
		notify("現場選項目前只在記憶中，自動存檔未成功；請在暫停選單重試儲存。")
	campaign_choice_requested.emit(action_id)
	return true

func campaign_selected_choice(action_id: String) -> String:
	var definition := CAMPAIGN_SCRIPT.action(active_quest_id, action_id)
	return String(_campaign_results().get(action_id, "")) if definition.get("type", "") == "choice" else ""

func campaign_choice_state() -> Dictionary:
	if not _campaign_run_matches():
		return {}
	for definition: Dictionary in campaign_outing().get("actions", []):
		var action_id := String(definition["id"])
		if definition.get("type", "") == "choice" and campaign_action_status(action_id) == "active":
			return {"action_id": action_id, "name": definition.get("name", "現場決策"), "prompt": definition.get("prompt", "此決策會先記在本趟帳本；安全返村後才保留。"), "options": definition.get("options", []).duplicate(true), "selected": ""}
	return {}

func campaign_summary() -> String:
	if not has_authored_campaign():
		return ""
	var entries := CAMPAIGN_SCRIPT.outings(active_quest_id)
	var state: Dictionary = quest_progress["campaign"]
	var entry := campaign_outing()
	if entry.is_empty():
		return "章節行動 %d/%d 已帶回；達成原委託目標後按 [J] 交付。" % [entries.size(), entries.size()]
	var lines: Array[String] = ["行動 %d/%d：%s" % [int(state["outing_index"]) + 1, entries.size(), String(entry.get("name", ""))], String(entry.get("briefing", ""))]
	var results := _campaign_results()
	var committed: Dictionary = state.get("actions", {})
	for definition: Dictionary in entry.get("actions", []):
		var action_id := String(definition["id"])
		var status := "已帶回" if committed.has(action_id) else ("待安全帶回" if results.has(action_id) else ("進行中" if campaign_action_status(action_id) == "active" else "待行動"))
		lines.append("• %s（%s）" % [String(definition.get("name", action_id)), status])
	return "\n".join(lines)

func campaign_journey_hint() -> String:
	var entry := campaign_outing()
	if entry.is_empty():
		return "章節行動已全數帶回；按 [J] 核對剩餘條件，達標後在公會回報櫃台按 [E] 或開委託頁交付。"
	if can_deliver_quest_here():
		var quest := DataRegistry.get_quest(active_quest_id)
		var route_id := String(quest.get("route", ""))
		var route_name := String(DataRegistry.get_wasteland_route(route_id).get("name", route_id))
		var departure := "公會出擊門" if current_scene_id == "guild" else "村莊路線門"
		return "到%s按 [E] 前往「%s」；[M] 只顯示地圖。本趟：%s。" % [departure, route_name, String(entry.get("name", ""))]
	var results := _campaign_results()
	if CAMPAIGN_SCRIPT.ready(entry, results):
		var final_outing := int(quest_progress["campaign"]["outing_index"]) == CAMPAIGN_SCRIPT.outings(active_quest_id).size() - 1
		if final_outing:
			for requirement: Dictionary in active_quest_requirements():
				if requirement["kind"] != "campaign" and not requirement["optional"] and not requirement["ready"]:
					return "章節行動已完成；%s；[M] 查看地圖，達標後走到返村閘門按 [E] 撤離。" % String(requirement["hint"])
			return "本趟與委託目標已完成；[M] 查看返村出口，走到閘門按 [E] 撤離；返村後按 [J] 交付。"
		return "本趟行動已完成；[M] 查看返村出口，走到閘門按 [E] 帶回成果，再回村出發下一趟。"
	for definition: Dictionary in entry.get("actions", []):
		if results.has(definition["id"]):
			continue
		return "%s：%s；[M] 查看地圖標記。" % [String(definition.get("name", "行動")), campaign_action_hint(String(definition["id"]))]
	return "查看本趟行動 [J]。"

func campaign_action_hint(action_id: String) -> String:
	var entry := campaign_outing()
	if entry.is_empty():
		return ""
	var definition := CAMPAIGN_SCRIPT.action(active_quest_id, action_id, String(entry["id"]))
	if definition.is_empty():
		return ""
	var results := _campaign_results()
	if results.has(action_id):
		var banked: bool = quest_progress["campaign"].get("actions", {}).has(action_id)
		var prefix := "已帶回：" if banked else "現場完成，待安全帶回："
		return prefix + String(definition.get("result_text", definition.get("name", "")))
	for requirement: String in definition.get("requires", []):
		if not results.has(requirement):
			return "先完成「%s」。" % String(CAMPAIGN_SCRIPT.action(active_quest_id, requirement).get("name", requirement))
	var started := bool(campaign_action_progress(action_id).get("started", false))
	var fallback := "靠近按 E 開始；現場成果須安全帶回。"
	if started:
		match String(definition.get("type", "")):
			"channel": fallback = "按住 E 完成操作；離開範圍或放開會中斷。"
			"escort": fallback = "隊伍已出發；跟隨下一路點，清除隊伍附近威脅。"
			"carry": fallback = "已取件；依序通過搬運路點，清除路途伏擊。"
			"defend": fallback = "守在地面範圍內，清除附近威脅後才繼續計時。"
			"choice": fallback = "靠近按 E 開啟處置選項；可暫緩，不會自動作答。"
	var instruction := String(definition.get("active_instruction" if started else "instruction", fallback))
	return "出征後：" + instruction if can_deliver_quest_here() else instruction

func _settle_campaign_outing(result: Dictionary) -> void:
	var entry := campaign_outing()
	if not has_authored_campaign() or entry.is_empty() or result.get("campaign_outing", "") != entry.get("id", ""):
		return
	var state: Dictionary = quest_progress["campaign"]
	state["actions"].merge(result.get("campaign_actions", {}), false)
	if CAMPAIGN_SCRIPT.ready(entry, state["actions"]):
		state["outing_index"] = int(state["outing_index"]) + 1
	_expedition.last_result["campaign_report"] = CAMPAIGN_SCRIPT.return_report(active_quest_id, String(entry["id"]), state["actions"], result.get("campaign_actions", {}))

func _store_campaign_consequences(quest_id: String) -> void:
	if not has_authored_campaign() or not campaign_outing().is_empty():
		return
	var quest := DataRegistry.get_quest(quest_id)
	var route_id := String(quest.get("route", ""))
	var state: Dictionary = route_states.get(route_id, {}).duplicate(true)
	var choices: Dictionary = state.get("campaign_choices", {}).duplicate(true)
	for action_id: String in quest_progress["campaign"].get("actions", {}):
		if CAMPAIGN_SCRIPT.action(quest_id, action_id).get("type", "") == "choice":
			choices[action_id] = quest_progress["campaign"]["actions"][action_id]
	if not choices.is_empty():
		state["campaign_choices"] = choices
	# Only a newly authored, fully extracted chapter earns field-note history.
	state["campaign_completed"] = quest_id
	route_states[route_id] = state

func has_completed_campaign(quest_id: String) -> bool:
	var route_id := String(DataRegistry.get_quest(quest_id).get("route", ""))
	return completed_quests.has(quest_id) and route_states.get(route_id, {}).get("campaign_completed", "") == quest_id

func campaign_field_notes(quest_id: String) -> String:
	if quest_id.is_empty():
		return ""
	var results: Dictionary = {}
	var provisional: Dictionary = {}
	if quest_id == active_quest_id and has_authored_campaign():
		results = _campaign_results()
		if _campaign_run_matches():
			provisional = _expedition.active.get("campaign_actions", {})
	else:
		var route_id := String(DataRegistry.get_quest(quest_id).get("route", ""))
		var state: Dictionary = route_states.get(route_id, {})
		if not has_completed_campaign(quest_id):
			return ""
		for entry: Dictionary in CAMPAIGN_SCRIPT.outings(quest_id):
			for definition: Dictionary in entry.get("actions", []):
				results[definition["id"]] = state.get("campaign_choices", {}).get(definition["id"], "") if definition.get("type", "") == "choice" else "done"
	return CAMPAIGN_SCRIPT.field_notes(quest_id, results, provisional)

func campaign_consequence_summary(quest_id: String) -> String:
	var quest := DataRegistry.get_quest(quest_id)
	var results: Dictionary = route_states.get(String(quest.get("route", "")), {}).get("campaign_choices", {})
	if quest_id == active_quest_id and has_authored_campaign():
		results = _campaign_results()
	var parts: Array[String] = []
	for entry: Dictionary in CAMPAIGN_SCRIPT.outings(quest_id):
		for definition: Dictionary in entry.get("actions", []):
			if definition.get("type", "") != "choice":
				continue
			var selected := CAMPAIGN_SCRIPT.option(definition, String(results.get(definition["id"], "")))
			if not selected.is_empty():
				parts.append("%s：%s" % [String(definition["name"]), String(selected.get("description", selected.get("name", "")))])
	return "\n".join(parts)

func _valid_campaign_consequences(value: Variant, route_id: String) -> bool:
	if not value is Dictionary:
		return false
	for action_id: Variant in value:
		if not action_id is String:
			return false
		var valid := false
		for quest: Dictionary in DataRegistry.quests:
			if quest.get("route", "") != route_id:
				continue
			var definition := CAMPAIGN_SCRIPT.action(String(quest["id"]), action_id)
			if definition.get("type", "") == "choice" and CAMPAIGN_SCRIPT.valid_result(definition, value[action_id]):
				valid = true
				break
		if not valid:
			return false
	return true

func can_use_hub_services() -> bool:
	if not can_deliver_quest_here():
		notify("請回村莊或公會整備；本趟收穫須從返村門安全帶回。")
		return false
	return true

func can_offer_expedition_draft(milestone_id: String) -> bool:
	if current_scene_id != "wasteland" or death_pending or hp <= 0 or not has_active_expedition():
		return false
	var choices: Dictionary = _expedition.active.get("draft_choices", {})
	return choices.size() < 2 and not choices.has(milestone_id) and not EXPEDITION_SCRIPT.draft_site(current_route_id, milestone_id).is_empty()

func offer_expedition_draft(milestone_id: String) -> bool:
	if not can_offer_expedition_draft(milestone_id):
		return false
	var had_pending := not String(_expedition.active.get("pending_draft", "")).is_empty()
	if not _expedition.offer_draft(milestone_id):
		return false
	if not had_pending:
		SaveManager.save_game(false)
	expedition_draft_changed.emit()
	return true

func choose_expedition_draft(package_id: String) -> bool:
	if current_scene_id != "wasteland" or death_pending or hp <= 0 or not has_active_expedition():
		return false
	if not _expedition.choose_draft(package_id):
		return false
	var saved: bool = SaveManager.save_game(false)
	stats_changed.emit()
	expedition_draft_changed.emit()
	AudioManager.play_sfx("level_up")
	if not saved:
		notify("調校已在本趟生效，但自動存檔失敗；離開前請按 [F5] 重新儲存。")
	return true

func expedition_draft_state() -> Dictionary:
	var state := {"pending": "", "site_name": "", "choices": {}, "options": []}
	if current_scene_id != "wasteland" or death_pending or hp <= 0 or not has_active_expedition():
		return state
	var pending := String(_expedition.active.get("pending_draft", ""))
	state["pending"] = pending
	state["site_name"] = String(EXPEDITION_SCRIPT.draft_site(current_route_id, pending).get("name", "戰地據點"))
	state["choices"] = _expedition.active.get("draft_choices", {}).duplicate(true)
	for package_id: String in EXPEDITION_SCRIPT.DRAFT_PACKAGES:
		var package: Dictionary = EXPEDITION_SCRIPT.DRAFT_PACKAGES[package_id]
		var effects: Array[String] = []
		for perk_id: String in package["perks"]:
			var before := get_effective_perk_level(perk_id)
			effects.append(_draft_effect_text(perk_id, before, before + 1))
		state["options"].append({"id": package_id, "name": package["name"], "description": package["description"], "tradeoff": package["tradeoff"], "effects": effects})
	return state

func expedition_build_summary() -> String:
	if not has_active_expedition() or current_scene_id != "wasteland":
		return "戰地調校：無（僅本趟有效）"
	var names: Array[String] = []
	for package_id: String in _expedition.active.get("draft_choices", {}).values():
		names.append(String(EXPEDITION_SCRIPT.DRAFT_PACKAGES.get(package_id, {}).get("name", package_id)))
	var result := "戰地調校 %d/2：%s" % [names.size(), "、".join(names) if not names.is_empty() else "未選擇"]
	if not String(_expedition.active.get("pending_draft", "")).is_empty():
		result += "｜尚有待選，回調校據點按 E"
	return result

func _draft_effect_text(perk_id: String, before: int, after: int) -> String:
	match perk_id:
		"arc_overload":
			return "連鎖傷害 %d → %d（140 範圍內最多 2 名其他敵人）" % [0 if before == 0 else 8 + before * 8, 8 + after * 8]
		"armor_piercer":
			return "每發額外貫通 %d → %d 名敵人" % [before, after]
		"vibro_rend":
			return "近戰追加傷害 %d → %d，並額外擊退" % [0 if before == 0 else 6 + before * 6, 6 + after * 6]
		"dodge_blast":
			return "閃避起點衝擊傷害 %d → %d（100 範圍）" % [0 if before == 0 else 14 + before * 10, 14 + after * 10]
		"nano_salvage":
			return "每次拾取恢復 HP／EP 各 %d → %d，並擊退周圍敵人" % [0 if before == 0 else 4 + before * 3, 4 + after * 3]
		"scavenger_savant":
			return "廢鐵掉落物拾取加成 +%d%% → +%d%%（不影響返村拆解）" % [before * 40, after * 40]
	return ""

func add_item(item_id: String, amount := 1) -> void:
	if amount <= 0:
		return
	inventory[item_id] = int(inventory.get(item_id, 0)) + amount
	_sync_resource_counters()
	inventory_changed.emit()
	stats_changed.emit()

func consume_item(item_id: String, amount := 1) -> bool:
	if amount <= 0:
		return true
	if item_id == "ammo":
		return spend_ammo(amount)
	if int(inventory.get(item_id, 0)) < amount:
		return false
	inventory[item_id] = int(inventory[item_id]) - amount
	if int(inventory[item_id]) <= 0:
		inventory.erase(item_id)
	_sync_resource_counters()
	inventory_changed.emit()
	stats_changed.emit()
	return true

func can_equip(item_id: String) -> bool:
	return inventory.has(item_id) and not DataRegistry.get_equipment(item_id).is_empty()

func has_terminal_controller() -> bool:
	return int(inventory.get("terminal_controller", 0)) > 0 or equipment.get("tool", "") == "terminal_controller"

func equip_item(item_id: String) -> bool:
	if not can_equip(item_id):
		notify("背包中沒有可裝備的物品：%s" % item_display_name(item_id))
		return false
	var item := DataRegistry.get_equipment(item_id)
	var slot := String(item.get("slot", "tool"))
	equipment[slot] = item_id
	_sync_quick_slot_for_equipment(slot, item_id)
	equipment_changed.emit()
	stats_changed.emit()
	AudioManager.play_sfx("ui")
	notify("已裝備：%s" % String(item.get("name", item_id)))
	return true

func use_quick_slot(index: int) -> bool:
	if index < 0 or index >= quick_slots.size():
		return false
	active_quick_slot = index
	var item_id := String(quick_slots[index])
	if item_id.is_empty():
		notify("快捷欄 %d 是空的" % [index + 1])
		equipment_changed.emit()
		return false
	if not DataRegistry.get_equipment(item_id).is_empty():
		return equip_item(item_id)
	var resource := DataRegistry.get_resource(item_id)
	if not resource.is_empty():
		var banked := int(inventory.get(item_id, 0))
		var in_haul := int(_expedition.active.get("haul", {}).get(item_id, 0))
		if item_id == "ammo":
			notify("彈藥資訊：可用 %d（庫存 %d／本趟 %d）。射擊自動消耗；選此格時左鍵使用近戰。" % [banked + in_haul, banked, in_haul])
		else:
			notify("快捷欄 %d：%s（庫存 %d／本趟 %d）。此格只供查看材料；左鍵使用近戰。" % [index + 1, String(resource.get("name", item_id)), banked, in_haul])
		equipment_changed.emit()
		return true
	notify("快捷欄 %d 無法使用：%s" % [index + 1, item_id])
	equipment_changed.emit()
	return false

func use_next_quick_slot() -> bool:
	if quick_slots.is_empty():
		return false
	return use_quick_slot((active_quick_slot + 1) % quick_slots.size())

func set_quick_slot(index: int, item_id: String) -> bool:
	if index < 0 or index >= quick_slots.size():
		return false
	if not inventory.has(item_id):
		notify("背包中沒有 %s，無法放入快捷欄" % item_display_name(item_id))
		return false
	quick_slots[index] = item_id
	equipment_changed.emit()
	notify("快捷欄 %d 設為 %s" % [index + 1, item_display_name(item_id)])
	return true

func active_quick_item_id() -> String:
	if active_quick_slot < 0 or active_quick_slot >= quick_slots.size():
		return String(equipment.get("weapon", "rust_blade"))
	return String(quick_slots[active_quick_slot])

func active_attack_mode() -> String:
	var item_id := active_quick_item_id()
	var item := DataRegistry.get_equipment(item_id)
	if item.is_empty():
		item = DataRegistry.get_equipment(String(equipment.get("weapon", "rust_blade")))
	return String(item.get("attack_mode", "melee"))

func active_attack_item_id() -> String:
	var item_id := active_quick_item_id()
	if not DataRegistry.get_equipment(item_id).is_empty():
		return item_id
	var mode := active_attack_mode()
	if mode == "ranged":
		return String(equipment.get("ranged", "pipe_rifle"))
	if mode == "tool":
		return String(equipment.get("tool", "recycler_glove"))
	return String(equipment.get("weapon", "rust_blade"))

func equipped_slot_name(slot: String) -> String:
	return item_display_name(String(equipment.get(slot, "")))

func item_display_name(item_id: String) -> String:
	var equipment_data := DataRegistry.get_equipment(item_id)
	if not equipment_data.is_empty():
		return String(equipment_data.get("name", item_id))
	var resource := DataRegistry.get_resource(item_id)
	if not resource.is_empty():
		return String(resource.get("name", item_id))
	return item_id

func get_stat_bonus(stat_name: String, attack_item_id := "") -> int:
	var total := 0
	for item_id in equipment.values():
		var item := DataRegistry.get_equipment(String(item_id))
		var stats: Dictionary = item.get("stats", {})
		total += int(stats.get(stat_name, 0))
	match stat_name:
		"attack":
			total += attack_upgrade_level * 3
			var active_weapon := active_attack_item_id() if attack_item_id.is_empty() else attack_item_id
			total += (get_weapon_level(active_weapon) - 1) * 3
		"defense":
			total += defense_upgrade_level * 2
	return total

func get_weapon_level(item_id: String) -> int:
	return clampi(int(weapon_levels.get(item_id, 1)), 1, 5)

func get_weapon_upgrade_cost(item_id: String) -> int:
	return 8 + get_weapon_level(item_id) * 6

func get_weapon_cooldown_multiplier(item_id: String) -> float:
	return maxf(0.68, 1.0 - float(get_weapon_level(item_id) - 1) * 0.06)

func upgrade_weapon_level(item_id: String) -> bool:
	if not can_use_hub_services():
		return false
	var item := DataRegistry.get_equipment(item_id)
	if item.is_empty() or not ["weapon", "ranged"].has(String(item.get("slot", ""))):
		notify("該裝備無法進行武器鍛造強化。")
		return false
	var current_lvl := get_weapon_level(item_id)
	if current_lvl >= 5:
		notify("%s 已達最高鍛造等級 Lv.5。" % item_display_name(item_id))
		return false
	var cost := get_weapon_upgrade_cost(item_id)
	if not consume_item("scrap", cost):
		notify("強化 %s 需要廢鐵 x%d。" % [item_display_name(item_id), cost])
		return false
	weapon_levels[item_id] = current_lvl + 1
	AudioManager.play_sfx("sfx_ui_upgrade")
	request_feedback("level_up", 0.16)
	notify("%s 強化至 Lv.%d（攻擊 +%d、冷卻縮短）" % [item_display_name(item_id), current_lvl + 1, current_lvl * 3])
	equipment_changed.emit()
	stats_changed.emit()
	SaveManager.save_game(false)
	return true

func take_damage(amount: int) -> void:
	if death_pending:
		return
	var reduced: int = max(1, amount - get_stat_bonus("defense"))
	hp = max(0, hp - reduced)
	request_feedback("player_hit", 0.28)
	AudioManager.play_sfx("hurt")
	stats_changed.emit()
	if hp <= 0:
		death_pending = true
		_death_sequence_generation += 1
		request_feedback("player_dead", 0.58)
		AudioManager.play_sfx("death")
		notify("R-17 核心停機，維修艙正在回收機體。")
		call_deferred("_finish_death_sequence", _death_sequence_generation)

func _finish_death_sequence(sequence_generation: int) -> void:
	await get_tree().create_timer(1.25, false).timeout
	if sequence_generation != _death_sequence_generation or not death_pending:
		return
	retry_death_recovery()

func retry_death_recovery() -> bool:
	if not death_pending or hp > 0 or SceneRouter.is_transition_pending():
		return false
	SceneRouter.change_to("village", "clinic", "", "death")
	return SceneRouter.is_transition_pending()

func complete_death_recovery() -> Dictionary:
	var result := settle_expedition(false)
	_expedition.legacy_trip = false
	hp = get_max_hp()
	ep = get_max_ep()
	death_pending = false
	stats_changed.emit()
	return result

func cancel_death_recovery() -> void:
	_death_sequence_generation += 1
	death_pending = false

func heal_full() -> void:
	if not can_use_hub_services():
		return
	hp = get_max_hp()
	ep = get_max_ep()
	stats_changed.emit()

func spend_ammo(amount := 1) -> bool:
	if amount <= 0:
		return true
	if quest_item_count("ammo") < amount:
		return false
	var haul: Dictionary = _expedition.active.get("haul", {})
	var from_haul := mini(amount, int(haul.get("ammo", 0)))
	if from_haul > 0:
		haul["ammo"] = int(haul["ammo"]) - from_haul
	var from_bank := amount - from_haul
	if from_bank > 0:
		inventory["ammo"] = int(inventory.get("ammo", 0)) - from_bank
	_last_ammo_spend = {"haul": from_haul, "bank": from_bank}
	_sync_resource_counters()
	inventory_changed.emit()
	stats_changed.emit()
	return true

func refund_ammo(amount := 1) -> void:
	# Player fires synchronously; a full projectile pool refunds the same balance.
	var bank := mini(maxi(0, amount), int(_last_ammo_spend.get("bank", 0)))
	var haul := mini(maxi(0, amount - bank), int(_last_ammo_spend.get("haul", 0)))
	_last_ammo_spend.clear()
	if bank > 0:
		inventory["ammo"] = int(inventory.get("ammo", 0)) + bank
	if haul > 0 and has_active_expedition():
		var items: Dictionary = _expedition.active["haul"]
		items["ammo"] = int(items.get("ammo", 0)) + haul
	_sync_resource_counters()
	inventory_changed.emit()
	stats_changed.emit()

func xp_to_next_level() -> int:
	return 80 + (level - 1) * 45

func add_xp(amount: int) -> void:
	xp += max(0, amount)
	while xp >= xp_to_next_level():
		xp -= xp_to_next_level()
		level += 1
		upgrade_points += 1
		AudioManager.play_sfx("level_up")
		request_feedback("level_up", 0.22)
		notify("R-17 等級提升，獲得 1 點維修升級點。")
	stats_changed.emit()

func spend_upgrade_point(kind: String) -> bool:
	if not can_use_hub_services():
		return false
	if upgrade_points <= 0:
		notify("沒有可用升級點。")
		return false
	upgrade_points -= 1
	match kind:
		"hp":
			hp_upgrade_level += 1
			hp = get_max_hp()
			notify("維修艙強化完成：HP 上限提升。")
		"ep":
			ep_upgrade_level += 1
			ep = get_max_ep()
			notify("能量核心調校完成：EP 上限提升。")
		"attack":
			attack_upgrade_level += 1
			notify("武器校準完成：攻擊力提升。")
		"defense":
			defense_upgrade_level += 1
			notify("外殼補強完成：防禦提升。")
		_:
			upgrade_points += 1
			notify("未知的升級項目。")
			return false
	stats_changed.emit()
	SaveManager.save_game(false)
	return true

func get_perk_level(perk_id: String) -> int:
	return int(perks.get(perk_id, 0))

func get_effective_perk_level(perk_id: String) -> int:
	var bonus: int = _expedition.perk_bonus(perk_id) if current_scene_id == "wasteland" and has_active_expedition() and not death_pending else 0
	return get_perk_level(perk_id) + bonus

func has_effective_perk(perk_id: String) -> bool:
	return get_effective_perk_level(perk_id) > 0

func has_perk(perk_id: String) -> bool:
	return get_perk_level(perk_id) > 0

func unlock_perk(perk_id: String) -> bool:
	if not can_use_hub_services():
		return false
	if not PERKS_CATALOG.has(perk_id):
		notify("未知的戰術晶片：%s" % perk_id)
		return false
	var perk_def: Dictionary = PERKS_CATALOG[perk_id]
	var current_lvl: int = get_perk_level(perk_id)
	var max_lvl: int = int(perk_def.get("max_level", 3))
	if current_lvl >= max_lvl:
		notify("%s 已達到最高等級 Lv.%d。" % [String(perk_def.get("name", perk_id)), max_lvl])
		return false
	if upgrade_points <= 0:
		notify("升級點數不足，擊殺敵人或提升等級可獲得升級點。")
		return false
	upgrade_points -= 1
	perks[perk_id] = current_lvl + 1
	AudioManager.play_sfx("level_up")
	request_feedback("level_up", 0.22)
	notify("戰術晶片裝載成功：%s 提升至 Lv.%d！" % [String(perk_def.get("name", perk_id)), current_lvl + 1])
	stats_changed.emit()
	SaveManager.save_game(false)
	return true

func disassemble_item(item_id: String, count: int = 1) -> Dictionary:
	if not can_use_hub_services():
		return {}
	count = maxi(1, count)
	var available := int(inventory.get(item_id, 0))
	if available <= 0:
		notify("背包中沒有該物品：%s" % item_display_name(item_id))
		return {}
	count = mini(count, available)

	# If currently equipped, preserve at least 1 copy
	for slot_item in equipment.values():
		if String(slot_item) == item_id:
			if available <= count:
				count = available - 1
			break
	if count <= 0:
		notify("無法拆解已裝備的武器或防具，請先卸下或更換裝備。")
		return {}

	var yield_mats := get_disassemble_yield(item_id)
	if yield_mats.is_empty():
		notify("該物品無法被拆解：%s" % item_display_name(item_id))
		return {}

	if not consume_item(item_id, count):
		return {}
	if not inventory.has(item_id):
		var quick_slots_changed := false
		for index in range(quick_slots.size()):
			if quick_slots[index] == item_id:
				quick_slots[index] = ""
				quick_slots_changed = true
		if quick_slots_changed:
			equipment_changed.emit()
	var total_gained: Dictionary = {}
	var savant_bonus: float = 1.0 + float(get_perk_level("scavenger_savant")) * 0.40
	for mat_id in yield_mats.keys():
		var single_amt := int(yield_mats[mat_id])
		var amt := int(round(float(single_amt * count) * savant_bonus))
		amt = maxi(1, amt)
		add_item(String(mat_id), amt)
		total_gained[String(mat_id)] = amt

	AudioManager.play_sfx("interact")
	request_feedback("attack", 0.12)
	var summary_parts: Array[String] = []
	for mat_id in total_gained.keys():
		summary_parts.append("%s x%d" % [item_display_name(String(mat_id)), int(total_gained[mat_id])])
	notify("拆解完成：%s x%d ➔ 獲得 %s" % [item_display_name(item_id), count, "、".join(summary_parts)])
	SaveManager.save_game(false)
	return total_gained

func get_disassemble_yield(item_id: String) -> Dictionary:
	match item_id:
		"mutant_core":
			return {"scrap": 14, "bio_crystal": 1}
		"bio_crystal":
			return {"scrap": 8}
		"alloy_plate":
			return {"scrap": 10}
		"broken_coil":
			return {"scrap": 8}
		"mutant_herb":
			return {"scrap": 6}
		"acid_sac":
			return {"scrap": 12, "bio_crystal": 1}
		"amethyst_gem":
			return {"scrap": 16, "bio_crystal": 2}
		"precision_chip":
			return {"scrap": 18, "mutant_core": 1}
		"dynamo_core":
			return {"scrap": 22, "mutant_core": 1}
		_:
			var eq := DataRegistry.get_equipment(item_id)
			if eq.is_empty():
				return {}
			var recipe_cost := _find_recipe_cost(item_id)
			var yields: Dictionary = {}
			if not recipe_cost.is_empty():
				var scrap_cost := int(recipe_cost.get("scrap", 10))
				yields["scrap"] = maxi(4, int(round(float(scrap_cost) * 0.65)))
				if recipe_cost.has("mutant_core"):
					yields["mutant_core"] = maxi(1, int(recipe_cost["mutant_core"]) - 1)
				if recipe_cost.has("bio_crystal"):
					yields["bio_crystal"] = maxi(1, int(recipe_cost["bio_crystal"]) - 1)
			else:
				yields["scrap"] = 8
			return yields

func _find_recipe_cost(item_id: String) -> Dictionary:
	for r in DataRegistry.recipes:
		var res: Dictionary = r.get("result", {})
		if res.has(item_id):
			return r.get("cost", {})
	return {}

func batch_recycle_duplicates() -> Dictionary:
	var total_yields: Dictionary = {}
	var items_to_dismantle: Dictionary = {}
	for item_id in inventory.keys():
		var count := int(inventory[item_id])
		if count <= 0:
			continue
		var eq := DataRegistry.get_equipment(item_id)
		if eq.is_empty():
			continue
		var surplus := maxi(0, count - 1)
		if surplus > 0:
			items_to_dismantle[item_id] = surplus

	if items_to_dismantle.is_empty():
		notify("沒有可拆解的多餘重複裝備。")
		return {}

	for item_id in items_to_dismantle.keys():
		var count: int = items_to_dismantle[item_id]
		var gained := disassemble_item(item_id, count)
		for mat in gained.keys():
			total_yields[mat] = int(total_yields.get(mat, 0)) + int(gained[mat])

	return total_yields

func record_enemy_defeated(boss := false, source_key := "") -> void:
	if boss and not source_key.is_empty():
		record_run_source(source_key)
	defeated_enemies += 1
	add_xp(18)
	if _is_active_quest_route():
		advance_quest_counter("defeat_enemy", 1)
		if boss:
			advance_quest_counter("defeat_boss", 1)
	if defeated_enemies % 3 == 0:
		add_field_item("ammo", 4)
		notify("污染體掉落可用彈藥 x4。")

func start_quest(quest_id: String) -> bool:
	if not can_deliver_quest_here():
		notify("請先回到村莊或公會，再按 [J] 承接委託；出發前會替你標好路線。")
		return false
	if not active_quest_id.is_empty():
		notify("目前已有進行中的委託：%s" % active_quest_summary())
		return false
	if completed_quests.has(quest_id):
		notify("這份委託已完成。")
		return false
	var quest := DataRegistry.get_quest(quest_id)
	if quest.is_empty():
		notify("未知的委託：%s" % quest_id)
		return false
	if not is_quest_available(quest_id):
		notify("此主線委託尚未解鎖，請先完成前置委託。")
		return false
	active_quest_id = quest_id
	var route_id := String(quest.get("route", ""))
	if not route_id.is_empty():
		current_route_id = route_id
	quest_progress.clear()
	for objective in quest.get("objectives", []):
		if String(objective.get("type", "")) == "defeat":
			var counter := String(objective.get("counter", "defeat_enemy"))
			quest_progress[counter] = 0
	var field_objective: Variant = quest.get("field_objective", {})
	if field_objective is Dictionary and not field_objective.is_empty():
		quest_progress[FIELD_OBJECTIVE_VERSION_KEY] = FIELD_OBJECTIVE_VERSION
	if bool(quest.get("main_campaign", false)) and not CAMPAIGN_SCRIPT.outings(quest_id).is_empty():
		quest_progress["campaign"] = CAMPAIGN_SCRIPT.new_state()
	notify("已接下委託：%s" % String(quest.get("name", quest_id)))
	_emit_all()
	SaveManager.save_game(false)
	return true

func advance_quest_counter(counter_id: String, amount := 1) -> void:
	if active_quest_id.is_empty() or amount <= 0:
		return
	var declared := false
	for objective: Dictionary in DataRegistry.get_quest(active_quest_id).get("objectives", []):
		if objective.get("type", "") == "defeat" and String(objective.get("counter", "defeat_enemy")) == counter_id:
			declared = true
			break
	if not declared:
		return
	if has_active_expedition() and _expedition.active["quest_id"] == active_quest_id:
		var counters: Dictionary = _expedition.active["counters"]
		counters[counter_id] = int(counters.get(counter_id, 0)) + amount
	else:
		quest_progress[counter_id] = int(quest_progress.get(counter_id, 0)) + amount
	stats_changed.emit()

func is_active_quest_ready() -> bool:
	if active_quest_id.is_empty() or DataRegistry.get_quest(active_quest_id).is_empty():
		return false
	for requirement: Dictionary in active_quest_requirements():
		if not requirement["optional"] and not requirement["ready"]:
			return false
	return true

func active_quest_requirements() -> Array[Dictionary]:
	var requirements: Array[Dictionary] = []
	var quest := DataRegistry.get_quest(active_quest_id)
	if quest.is_empty():
		return requirements
	if has_authored_campaign():
		var entry := campaign_outing()
		var count := CAMPAIGN_SCRIPT.outings(active_quest_id).size()
		var banked := int(quest_progress["campaign"]["outing_index"])
		var text := "章節行動已帶回 %d/%d 趟" % [banked, count]
		if not entry.is_empty() and CAMPAIGN_SCRIPT.ready(entry, _campaign_results()):
			text += "；本趟完成，須先從返村門帶回"
		requirements.append({"kind": "campaign", "ready": entry.is_empty(), "optional": false, "text": text, "hint": "完成本趟章節行動；[M] 查看返村出口，走到閘門按 [E] 撤離。"})
	if _active_field_objective_is_required(active_quest_id):
		var field: Dictionary = quest.get("field_objective", {})
		var ready := field_objective_status(active_quest_id)
		var text := "現場行動：" + String(field.get("name", "現場目標"))
		if ready and has_active_expedition() and _expedition.active["fields"].get(String(field.get("id", "")), false):
			text += "（本趟完成，待返村）"
		requirements.append({"kind": "field", "ready": ready, "optional": false, "text": text, "hint": "沿 [M] 找「%s」，靠近按 [E]。" % String(field.get("name", "現場目標"))})
	for objective: Dictionary in quest.get("objectives", []):
		var kind := String(objective.get("type", ""))
		var amount := int(objective.get("amount", 0))
		var ready := false
		var text := ""
		var hint := ""
		if kind == "collect":
			var item_id := String(objective.get("item", ""))
			var total := quest_item_count(item_id)
			var banked := int(inventory.get(item_id, 0))
			ready = total >= amount
			text = "交付%s %d/%d" % [item_display_name(item_id), total, amount]
			if total > banked:
				text += "（庫存 %d＋本趟 %d）" % [banked, total - banked]
			hint = "還需%s x%d；交付前請保留材料。" % [item_display_name(item_id), maxi(0, amount - total)]
		elif kind == "defeat":
			var counter := String(objective.get("counter", "defeat_enemy"))
			var total := quest_counter_value(counter)
			var provisional := total - int(quest_progress.get(counter, 0))
			ready = total >= amount
			text = "%s %d/%d" % ["擊敗本區 Boss" if counter == "defeat_boss" else "擊倒本區污染體", total, amount]
			if provisional > 0:
				text += "（含本趟 %d）" % provisional
			hint = text + "；其餘條件按 [J]。"
		elif kind == "discover":
			var route_id := String(objective.get("route", ""))
			var event_id := String(objective.get("event", ""))
			var event := DataRegistry.get_event(event_id)
			var found := has_story_discovery(route_id, event_id)
			var pending := story_discovery_needs_extraction(route_id, event_id)
			ready = _quest_discovery_ready(route_id, event_id)
			text = "%s（%s）" % [String(event.get("name", "現場紀錄")), "已讀，待該路線撤離" if pending else ("已帶回" if found else "未調查")]
			hint = "紀錄已讀，仍須從「%s」成功返村。" % String(DataRegistry.get_wasteland_route(route_id).get("name", route_id)) if pending else "調查「%s」，靠近按 E [M]。" % String(event.get("name", "現場紀錄"))
		else:
			continue
		if not ready and kind == "collect":
			text += "；尚缺 %d" % maxi(0, amount - quest_item_count(String(objective.get("item", ""))))
		requirements.append({"kind": kind, "ready": ready, "optional": kind == "discover" and bool(objective.get("optional", false)), "text": text, "hint": hint})
	return requirements

func active_quest_requirements_text() -> String:
	var required: Array[String] = []
	var optional: Array[String] = []
	for requirement: Dictionary in active_quest_requirements():
		if requirement["optional"]:
			optional.append("選讀，不影響交付｜" + String(requirement["text"]))
		else:
			required.append("%s｜%s" % ["已達成" if requirement["ready"] else "待完成", String(requirement["text"])])
	required.append_array(optional)
	return "\n".join(required)

func field_objective_status(quest_id: String) -> bool:
	var quest := DataRegistry.get_quest(quest_id)
	var field_objective: Variant = quest.get("field_objective", {})
	if quest.is_empty() or not field_objective is Dictionary:
		return false
	var objective_id := String(field_objective.get("id", ""))
	var route_id := String(field_objective.get("route", quest.get("route", "")))
	if objective_id.is_empty() or route_id.is_empty():
		return false
	if has_active_expedition() and _expedition.active["quest_id"] == quest_id and _expedition.active["route"] == route_id and _expedition.active["fields"].get(objective_id, false):
		return true
	var route_state: Variant = route_states.get(route_id, {})
	if not route_state is Dictionary:
		return false
	var completed_objectives: Variant = route_state.get("field_objectives", {})
	if not completed_objectives is Dictionary:
		return false
	return completed_objectives.get(objective_id, false) == true

func complete_quest_field_objective(quest_id: String) -> bool:
	if hp <= 0 or death_pending:
		return false
	if active_quest_id != quest_id or completed_quests.has(quest_id):
		return false
	var quest := DataRegistry.get_quest(quest_id)
	var field_objective: Variant = quest.get("field_objective", {})
	if quest.is_empty() or not field_objective is Dictionary:
		return false
	var objective_id := String(field_objective.get("id", ""))
	var route_id := String(field_objective.get("route", quest.get("route", "")))
	if objective_id.is_empty() or route_id != String(quest.get("route", "")):
		return false
	if current_scene_id != "wasteland" or current_route_id != route_id or field_objective_status(quest_id):
		return false
	if has_active_expedition():
		_expedition.active["fields"][objective_id] = true
		_emit_all()
		SaveManager.save_game(false)
		return true
	var route_state: Variant = route_states.get(route_id, {})
	var completed_objectives: Variant = {}
	if route_state is Dictionary:
		completed_objectives = route_state.get("field_objectives", {})
	if not route_state is Dictionary or not completed_objectives is Dictionary:
		return false
	completed_objectives[objective_id] = true
	route_state["field_objectives"] = completed_objectives
	route_states[route_id] = route_state
	_emit_all()
	SaveManager.save_game(false)
	return true

func _active_field_objective_is_required(quest_id: String) -> bool:
	return quest_id == active_quest_id and int(quest_progress.get(FIELD_OBJECTIVE_VERSION_KEY, 0)) == FIELD_OBJECTIVE_VERSION

func complete_active_quest() -> bool:
	if active_quest_id.is_empty():
		notify("目前沒有可交付的委託。")
		return false
	if not can_deliver_quest_here():
		notify("按 [M] 查看返村出口，走到閘門按 [E] 撤離；返村後按 [J] 交付物資。")
		return false
	if not is_active_quest_ready():
		notify("委託尚未達標。" + get_journey_hint())
		return false
	var quest := DataRegistry.get_quest(active_quest_id)
	if quest.is_empty() or completed_quests.has(active_quest_id):
		return false
	for objective in quest.get("objectives", []):
		if String(objective.get("type", "")) == "collect":
			consume_item(String(objective.get("item", "")), int(objective.get("amount", 0)))
	var reward: Dictionary = quest.get("reward", {})
	for item_id in reward.keys():
		add_item(String(item_id), int(reward[item_id]))
	var completed_id := active_quest_id
	_store_campaign_consequences(completed_id)
	completed_quests.append(completed_id)
	active_quest_id = ""
	quest_progress.clear()
	add_xp(35)
	notify("委託完成：%s" % String(quest.get("name", completed_id)))
	_emit_all()
	var saved: bool = SaveManager.save_game(false)
	dialogue_requested.emit("米婭", "委託回報", quest_completion_report(completed_id, saved))
	return true

func quest_completion_report(quest_id: String, saved := true) -> String:
	var quest := DataRegistry.get_quest(quest_id)
	var completion_text := quest_completion_story(quest_id)
	completion_text += "\n\n報酬：%s" % quest_reward_summary(quest_id)
	var consequence := campaign_consequence_summary(quest_id)
	if not consequence.is_empty():
		completion_text += "\n現場決策：" + consequence
	var preparation := String(quest.get("preparation_hint", ""))
	if not preparation.is_empty():
		completion_text += "\n整備：%s" % preparation
	completion_text += "\n下一步：%s" % get_journey_hint()
	return completion_text if saved else UNSAVED_RESULT_WARNING + completion_text

func quest_completion_story(quest_id: String) -> String:
	var quest := DataRegistry.get_quest(quest_id)
	var completion_text := String(quest.get("completion_text", ""))
	var discovered_optional_revelations: Array[String] = []
	for objective in quest.get("objectives", []):
		if String(objective.get("type", "")) == "discover" and has_story_discovery(String(objective.get("route", "")), String(objective.get("event", ""))):
			completion_text = String(quest.get("completion_discovery_text", completion_text))
			if bool(objective.get("optional", false)):
				var event := DataRegistry.get_event(String(objective.get("event", "")))
				var revelation := String(event.get("revelation", ""))
				if bool(event.get("story", false)) and not revelation.is_empty():
					discovered_optional_revelations.append(revelation)
			break
	# Only banked, delivered authored outings may speak for their new story beats.
	var campaign_completed := has_completed_campaign(quest_id)
	if campaign_completed:
		completion_text = String(quest.get("campaign_completion_text", completion_text))
	var field_objective: Variant = quest.get("field_objective", {})
	if field_objective is Dictionary and not field_objective.is_empty():
		if not field_objective_status(quest_id):
			completion_text = String(quest.get("legacy_completion_text", completion_text))
		var field_result := "已完成" if field_objective_status(quest_id) else "未要求（此委託在更新前已承接）"
		completion_text += "\n現場行動：%s（%s）。" % [String(field_objective.get("name", "現場行動")), field_result]
	if quest_id == "facility_memory" and completed_quests.has("metropolis_archive"):
		var city_record := campaign_consequence_summary("metropolis_archive")
		if not city_record.is_empty():
			completion_text += "\n姓名公開範圍沿用都心紀錄：\n" + city_record
	if campaign_completed:
		for revelation in discovered_optional_revelations:
			completion_text += "\n\n米婭把你發現的線索記進公會紀錄：" + revelation
	return completion_text

func can_deliver_quest_here() -> bool:
	return current_scene_id == "village" or current_scene_id == "guild"

func quest_reward_summary(quest_id: String) -> String:
	var reward: Dictionary = DataRegistry.get_quest(quest_id).get("reward", {})
	var parts: Array[String] = []
	for item_id in reward.keys():
		parts.append("%s x%d" % [item_display_name(String(item_id)), int(reward[item_id])])
	parts.append("經驗 +35")
	return "、".join(parts)

func quest_objectives_summary(quest_id: String) -> String:
	var parts: Array[String] = []
	var quest := DataRegistry.get_quest(quest_id)
	for objective in quest.get("objectives", []):
		var kind := String(objective.get("type", ""))
		var amount := int(objective.get("amount", 0))
		if kind == "collect":
			parts.append("交付%s x%d" % [item_display_name(String(objective.get("item", ""))), amount])
		elif kind == "defeat":
			parts.append("%s x%d" % ["擊敗 Boss" if String(objective.get("counter", "")) == "defeat_boss" else "擊倒當地污染體", amount])
		elif kind == "discover":
			var event := DataRegistry.get_event(String(objective.get("event", "")))
			parts.append("%s%s" % ["選讀：" if bool(objective.get("optional", false)) else "調查：", String(event.get("name", "現場紀錄"))])
	var field_objective: Variant = quest.get("field_objective", {})
	if field_objective is Dictionary and not field_objective.is_empty():
		var field_status := "新承接時須完成"
		if field_objective_status(quest_id):
			field_status = "已完成"
		elif quest_id == active_quest_id and not _active_field_objective_is_required(quest_id):
			field_status = "既有進度不要求"
		elif quest_id == active_quest_id:
			field_status = "待完成"
		parts.append("現場行動：%s（%s）" % [String(field_objective.get("name", "現場行動")), field_status])
	return "、".join(parts)

func get_journey_hint() -> String:
	if active_quest_id.is_empty():
		var next_id := next_story_quest_id()
		if not next_id.is_empty():
			var next_name := String(DataRegistry.get_quest(next_id).get("name", next_id))
			return "按 [J] 開啟委託頁，承接「%s」。" % next_name if can_deliver_quest_here() else "[M] 查看地圖，走到返村閘門按 [E] 撤離，再回村按 [J] 承接「%s」。" % next_name
		for quest in DataRegistry.quests:
			if not completed_quests.has(String(quest.get("id", ""))):
				return "供水已恢復；回村後按 [J] 承接剩餘支線，或按 [K] 補查紀錄。"
		return "本篇完成。回村與艾達、艾倫交談；可繼續探索支路、回收與鍛造。"
	if is_active_quest_ready():
		return "按 [J] 開啟委託頁交付並領取報酬；公會回報櫃台也可按 [E]。" if can_deliver_quest_here() else "目標齊備；[M] 查看返村出口，走到閘門按 [E] 撤離，返村後按 [J] 交付。"
	var quest := DataRegistry.get_quest(active_quest_id)
	var route_id := String(quest.get("route", ""))
	var route_name := String(DataRegistry.get_wasteland_route(route_id).get("name", route_id))
	if can_deliver_quest_here() and has_authored_campaign() and campaign_outing().is_empty():
		for requirement: Dictionary in active_quest_requirements():
			if not requirement["optional"] and not requirement["ready"]:
				var departure := "公會出擊門" if current_scene_id == "guild" else "村莊路線門"
				return "兩趟行動已帶回；%s 前往「%s」的%s按 [E] 出發；[M] 查看地圖。" % [String(requirement["hint"]), route_name, departure]
	if current_scene_id == "guild":
		return "到公會出擊門按 [E] 前往「%s」；[M] 查看地圖。%s" % [route_name, campaign_journey_hint() if has_authored_campaign() and not campaign_outing().is_empty() else "完整目標按 [J]。"]
	if current_scene_id != "wasteland":
		return "到村莊「%s」路線門按 [E] 出發；[M] 查看地圖。%s" % [route_name, campaign_journey_hint() if has_authored_campaign() and not campaign_outing().is_empty() else "完整目標按 [J]。"]
	if current_route_id != route_id:
		return "本區擊殺不計入目前委託，但回收材料仍可帶回村。[M] 查看返村出口，走到閘門按 [E] 撤離，再到「%s」路線門按 [E] 出發。" % route_name
	if has_authored_campaign() and not campaign_outing().is_empty():
		return campaign_journey_hint()
	for requirement: Dictionary in active_quest_requirements():
		if not requirement["optional"] and not requirement["ready"]:
			return String(requirement["hint"])
	return "按 [J] 確認目前委託的剩餘目標。"

func active_quest_summary() -> String:
	if active_quest_id.is_empty():
		return "無"
	var quest := DataRegistry.get_quest(active_quest_id)
	if quest.is_empty():
		return active_quest_id
	var parts: Array[String] = []
	for objective in quest.get("objectives", []):
		var kind := String(objective.get("type", ""))
		var amount := int(objective.get("amount", 0))
		if kind == "collect":
			var item_id := String(objective.get("item", ""))
			parts.append("%s %d/%d" % [item_display_name(item_id), quest_item_count(item_id), amount])
		elif kind == "defeat":
			var counter := String(objective.get("counter", "defeat_enemy"))
			var objective_name := "擊敗 Boss" if counter == "defeat_boss" else "擊倒污染體"
			parts.append("%s %d/%d" % [objective_name, quest_counter_value(counter), amount])
		elif kind == "discover":
			var route_id := String(objective.get("route", ""))
			var event_id := String(objective.get("event", ""))
			var event: Dictionary = DataRegistry.get_event(event_id)
			var prefix := "選讀線索" if bool(objective.get("optional", false)) else "調查線索"
			var state := "已發現" if has_story_discovery(route_id, event_id) else "未發現"
			if story_discovery_needs_extraction(route_id, event_id):
				state = "已記錄，待該路線撤離"
			parts.append("%s：%s" % [prefix, "%s（%s）" % [String(event.get("name", event_id)), state]])
	var field_objective: Variant = quest.get("field_objective", {})
	if field_objective is Dictionary and not field_objective.is_empty():
		var field_state := "已完成" if field_objective_status(active_quest_id) else "待完成"
		if not _active_field_objective_is_required(active_quest_id) and not field_objective_status(active_quest_id):
			field_state = "既有進度不要求"
		parts.append("現場行動：%s（%s）" % [String(field_objective.get("name", "現場行動")), field_state])
	return "%s：%s" % [String(quest.get("name", active_quest_id)), _join_strings(parts, "、")]

func has_story_discovery(route_id: String, event_id: String) -> bool:
	var event := DataRegistry.get_event(event_id)
	if event.is_empty() or not bool(event.get("story", false)) or String(event.get("route", "")) != route_id:
		return false
	return discovered_events.has("%s:%s" % [route_id, event_id]) or discovered_events.has(event_id)

func get_story_summary() -> String:
	var found := 0
	var total := 0
	for event in DataRegistry.events:
		if not bool(event.get("story", false)):
			continue
		total += 1
		if has_story_discovery(String(event.get("route", "")), String(event.get("id", ""))):
			found += 1
	return "劇情線索：%d/%d｜%s" % [found, total, get_village_water_summary()]

func get_village_water_stage() -> int:
	# Derived from existing completions; no new persistent field or save version.
	if completed_quests.has("facility_memory"):
		return 2
	return 1 if completed_quests.has("clear_scrap_route") else 0

func get_village_water_summary() -> String:
	match get_village_water_stage():
		2:
			return "村莊供水：穩定回流，仍需配給"
		1:
			return "村莊供水：臨時細流，主水路待修"
	return "村莊供水：停擺，先接南門旁路"

func next_story_quest_id() -> String:
	if not active_quest_id.is_empty() and bool(DataRegistry.get_quest(active_quest_id).get("main_campaign", false)):
		return active_quest_id
	for quest in DataRegistry.quests:
		if bool(quest.get("main_campaign", false)) and not completed_quests.has(String(quest.get("id", ""))):
			return String(quest.get("id", ""))
	return ""

func is_quest_available(quest_id: String) -> bool:
	var quest := DataRegistry.get_quest(quest_id)
	if quest.is_empty() or completed_quests.has(quest_id) or not active_quest_id.is_empty():
		return false
	return quest_prerequisites_met(quest_id)

func quest_prerequisites_met(quest_id: String) -> bool:
	var quest := DataRegistry.get_quest(quest_id)
	if quest.is_empty():
		return false
	for prerequisite in quest.get("prerequisites", []):
		if not completed_quests.has(String(prerequisite)):
			return false
	return true

func is_story_event_unlocked(event_id: String) -> bool:
	var event := DataRegistry.get_event(event_id)
	if event.is_empty():
		return false
	if not bool(event.get("story", false)):
		return true
	for quest in DataRegistry.quests:
		if String(quest.get("route", "")) != String(event.get("route", "")):
			continue
		for objective in quest.get("objectives", []):
			if String(objective.get("type", "")) == "discover" and String(objective.get("event", "")) == event_id:
				return quest_prerequisites_met(String(quest.get("id", "")))
	return true

func story_dialogue_for_npc(npc: Dictionary) -> String:
	var authored := has_authored_campaign()
	var active_route := String(DataRegistry.get_quest(active_quest_id).get("route", ""))
	for story_line in npc.get("story_lines", []):
		if authored:
			var discovery: Dictionary = story_line.get("requires_discovered", {})
			var current_context: bool = story_line.has("requires_campaign_outing") or story_line.has("requires_campaign_finished") or bool(story_line.get("requires_ready", false)) or (not discovery.is_empty() and discovery.get("route", "") == active_route)
			if not current_context:
				continue
		var conditions_met := true
		if story_line.has("requires_active"):
			conditions_met = active_quest_id == String(story_line["requires_active"])
		if story_line.has("requires_ready"):
			conditions_met = conditions_met and not active_quest_id.is_empty() and is_active_quest_ready() == bool(story_line["requires_ready"])
		if story_line.has("requires_campaign_outing"):
			conditions_met = conditions_met and has_authored_campaign() and campaign_outing().get("id", "") == String(story_line["requires_campaign_outing"])
		if story_line.has("requires_campaign_finished"):
			conditions_met = conditions_met and has_authored_campaign() and campaign_outing().is_empty() == bool(story_line["requires_campaign_finished"])
		if story_line.has("requires_campaign_completed"):
			conditions_met = conditions_met and has_completed_campaign(String(story_line["requires_campaign_completed"]))
		for required_quest in story_line.get("requires_completed", []):
			if not completed_quests.has(String(required_quest)):
				conditions_met = false
				break
		var required_discovery: Dictionary = story_line.get("requires_discovered", {})
		if conditions_met and not required_discovery.is_empty():
			conditions_met = has_story_discovery(String(required_discovery.get("route", "")), String(required_discovery.get("event", "")))
		if conditions_met:
			var text := String(story_line.get("text", ""))
			if not text.is_empty():
				if story_line.has("requires_campaign_completed"):
					text += "\n\n下一步：" + get_journey_hint()
				return text
	if authored:
		return String(npc.get("repeat_line", npc.get("line", ""))) + "\n目前行動：" + get_journey_hint()
	return ""

func notify(message: String) -> void:
	notification_requested.emit(message)

func request_feedback(kind: String, strength: float) -> void:
	feedback_requested.emit(kind, strength)

func close_dialogue() -> void:
	dialogue_closed.emit()

func talk_to_npc(npc_id: String) -> bool:
	var npc := DataRegistry.get_npc(npc_id)
	if npc.is_empty():
		notify("未知的 NPC：%s" % npc_id)
		return false
	var first_time := not talked_npcs.has(npc_id)
	var story_line := story_dialogue_for_npc(npc)
	var base_line := String(npc.get("line", "")) if first_time else String(npc.get("repeat_line", npc.get("line", "")))
	var message := story_line if not story_line.is_empty() else base_line
	message += campaign_npc_record(npc_id)
	if first_time:
		talked_npcs.append(npc_id)
		var reward: Dictionary = npc.get("reward", {})
		for item_id in reward.keys():
			add_item(String(item_id), int(reward[item_id]))
	dialogue_requested.emit(String(npc.get("name", npc_id)), String(npc.get("role", "倖存者")), message)
	inventory_changed.emit()
	stats_changed.emit()
	return true

func campaign_npc_record(npc_id: String) -> String:
	var consequence_quest := ""
	if npc_id == "wasteland_survivor" and completed_quests.has("metropolis_archive"):
		consequence_quest = "metropolis_archive"
	elif npc_id in ["repair_robot", "forge_master"] and completed_quests.has("facility_memory"):
		consequence_quest = "facility_memory"
	elif npc_id == "guild_clerk":
		for index in range(completed_quests.size() - 1, -1, -1):
			if not campaign_consequence_summary(completed_quests[index]).is_empty():
				consequence_quest = completed_quests[index]
				break
	if not consequence_quest.is_empty():
		var consequence := campaign_consequence_summary(consequence_quest)
		if not consequence.is_empty():
			return "\n\n已帶回的處置紀錄：\n" + consequence
	return ""

func capture_runtime_state() -> Dictionary:
	var snapshot: Dictionary = {}
	for field_name: String in RUNTIME_STATE_FIELDS:
		var value: Variant = get(field_name)
		if value is Dictionary or value is Array:
			value = value.duplicate(true)
		snapshot[field_name] = value
	snapshot["_expedition"] = {
		"active": _expedition.active.duplicate(true),
		"last_result": _expedition.last_result.duplicate(true),
		"legacy_trip": _expedition.legacy_trip,
		"uncommitted_clues": _expedition.uncommitted_clues.duplicate(true)
	}
	return snapshot

func restore_runtime_state(snapshot: Dictionary) -> void:
	for field_name: String in RUNTIME_STATE_FIELDS:
		if not snapshot.has(field_name):
			return
	var expedition_snapshot: Variant = snapshot.get("_expedition")
	if not expedition_snapshot is Dictionary:
		return
	for field_name in ["active", "last_result", "legacy_trip", "uncommitted_clues"]:
		if not expedition_snapshot.has(field_name):
			return
	if typeof(expedition_snapshot["active"]) != TYPE_DICTIONARY or typeof(expedition_snapshot["last_result"]) != TYPE_DICTIONARY or typeof(expedition_snapshot["legacy_trip"]) != TYPE_BOOL or typeof(expedition_snapshot["uncommitted_clues"]) != TYPE_ARRAY:
		return

	for field_name: String in RUNTIME_STATE_FIELDS:
		var value: Variant = snapshot[field_name]
		if value is Dictionary or value is Array:
			value = value.duplicate(true)
		set(field_name, value)
	var active_snapshot: Dictionary = expedition_snapshot["active"]
	var last_result_snapshot: Dictionary = expedition_snapshot["last_result"]
	var clues_snapshot: Array = expedition_snapshot["uncommitted_clues"]
	_expedition.active = active_snapshot.duplicate(true)
	_expedition.last_result = last_result_snapshot.duplicate(true)
	_expedition.legacy_trip = expedition_snapshot["legacy_trip"]
	_expedition.uncommitted_clues.clear()
	for clue: Variant in clues_snapshot:
		_expedition.uncommitted_clues.append(String(clue))

func publish_loaded_state() -> void:
	# Publish only after the destination scene has entered the tree with these values applied.
	scene_changed.emit(current_scene_id)
	_emit_all()
	campaign_changed.emit()
	expedition_draft_changed.emit()

func get_save_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"player": {
			"health": hp,
			"energy": ep,
			"position_x": player_position.x,
			"position_y": player_position.y
		},
		"inventory": inventory,
		"equipment": equipment,
		"scene": current_scene_id,
		"spawn_point": active_spawn_point,
		"route": current_route_id,
		"seed": seed,
		"level": level,
		"xp": xp,
		"upgrade_points": upgrade_points,
		"hp_upgrade_level": hp_upgrade_level,
		"ep_upgrade_level": ep_upgrade_level,
		"attack_upgrade_level": attack_upgrade_level,
		"defense_upgrade_level": defense_upgrade_level,
		"intro_seen": intro_seen,
		"defeated_enemies": defeated_enemies,
		"discovered_events": discovered_events,
		"talked_npcs": talked_npcs,
		"active_quest_id": active_quest_id,
		"completed_quests": completed_quests,
		"quest_progress": quest_progress,
		"route_states": route_states,
		"quick_slots": quick_slots,
		"active_quick_slot": active_quick_slot,
		"weapon_levels": weapon_levels,
		"perks": perks,
		"expedition": _expedition.save_data()
	}

func load_save_data(data: Dictionary, emit_changes := true) -> bool:
	if not is_save_data_valid(data):
		return false
	_death_sequence_generation += 1
	_campaign_runtime_generation += 1
	var player: Dictionary = data["player"]
	hp = int(player.get("health", MAX_HP))
	ep = int(player.get("energy", MAX_EP))
	player_position = Vector2(float(player.get("position_x", 0.0)), float(player.get("position_y", 0.0)))
	inventory = {}
	for item_key in data["inventory"].keys():
		inventory[String(item_key)] = int(data["inventory"][item_key])
	equipment = _equipment_with_defaults(data["equipment"])
	current_scene_id = String(data.get("scene", "village"))
	active_spawn_point = String(data.get("spawn_point", "default"))
	current_route_id = String(data.get("route", "scrap_highway"))
	seed = int(data.get("seed", 9527))
	level = int(data.get("level", 1))
	xp = int(data.get("xp", 0))
	upgrade_points = int(data.get("upgrade_points", 0))
	hp_upgrade_level = int(data.get("hp_upgrade_level", 0))
	ep_upgrade_level = int(data.get("ep_upgrade_level", 0))
	attack_upgrade_level = int(data.get("attack_upgrade_level", 0))
	defense_upgrade_level = int(data.get("defense_upgrade_level", 0))
	perks = data.get("perks", {}).duplicate(true)
	intro_seen = bool(data.get("intro_seen", false))
	death_pending = false
	defeated_enemies = int(data.get("defeated_enemies", 0))
	discovered_events = _string_array(data.get("discovered_events", []))
	talked_npcs = _string_array(data.get("talked_npcs", []))
	active_quest_id = String(data.get("active_quest_id", ""))
	completed_quests = _string_array(data.get("completed_quests", []))
	quest_progress = data.get("quest_progress", {}).duplicate(true)
	route_states = data.get("route_states", {}).duplicate(true)
	quick_slots = _string_array(data.get("quick_slots", ["rust_blade", "pipe_rifle", "recycler_glove", "ammo"]))
	while quick_slots.size() < 4:
		quick_slots.append("")
	active_quick_slot = int(data.get("active_quick_slot", 0))
	weapon_levels = data.get("weapon_levels", {}).duplicate(true)
	_expedition.clear()
	_last_ammo_spend.clear()
	if int(data.get("version", 1)) >= 5:
		_expedition.load_data(data["expedition"])
	else:
		# Preserve an old in-flight trip through further v5 saves until its first return.
		_expedition.legacy_trip = current_scene_id == "wasteland"
	_sync_resource_counters()
	hp = clampi(hp, 0, get_max_hp())
	ep = clampi(ep, 0, get_max_ep())
	if hp == 0:
		# Old trips preserve their old earned state; new runs lose only their ledger.
		settle_expedition(false, emit_changes)
		current_scene_id = "village"
		active_spawn_point = "clinic"
		hp = get_max_hp()
		ep = get_max_ep()
	if emit_changes:
		_emit_all()
	return true

func _is_active_quest_route() -> bool:
	if active_quest_id.is_empty():
		return false
	var quest := DataRegistry.get_quest(active_quest_id)
	return not quest.is_empty() and String(quest.get("route", "")) == current_route_id

func is_save_data_valid(data: Dictionary) -> bool:
	return _is_save_data_valid(data)

func _is_save_data_valid(data: Dictionary) -> bool:
	var version = data.get("version", 1)
	if not _is_integer_value(version) or int(version) < 1 or int(version) > SAVE_VERSION:
		return false
	if typeof(data.get("player")) != TYPE_DICTIONARY or typeof(data.get("inventory")) != TYPE_DICTIONARY or typeof(data.get("equipment")) != TYPE_DICTIONARY:
		return false
	var player: Dictionary = data["player"]
	for key in ["health", "energy", "position_x", "position_y"]:
		if player.has(key) and not _is_number_value(player[key]):
			return false
	for key in ["health", "energy"]:
		if player.has(key) and not _is_integer_value(player[key]):
			return false
	if not _is_integer_field_in_range(data, "seed", 0, 2147483647):
		return false
	if not _is_integer_field_in_range(data, "level", 1, 1000000):
		return false
	for key in ["xp", "upgrade_points", "defeated_enemies"]:
		if not _is_integer_field_in_range(data, key, 0, 2147483647):
			return false
	for key in ["hp_upgrade_level", "ep_upgrade_level", "attack_upgrade_level", "defense_upgrade_level"]:
		if not _is_integer_field_in_range(data, key, 0, 1000000):
			return false
	if data.has("intro_seen") and typeof(data["intro_seen"]) != TYPE_BOOL:
		return false
	var loaded_hp := float(player.get("health", MAX_HP))
	var loaded_ep := float(player.get("energy", MAX_EP))
	var max_hp := MAX_HP + int(data.get("hp_upgrade_level", 0)) * 20
	var max_ep := MAX_EP + int(data.get("ep_upgrade_level", 0)) * 10
	if loaded_hp < 0.0 or loaded_hp > float(max_hp) or loaded_ep < 0.0 or loaded_ep > float(max_ep):
		return false
	if not _is_optional_string(data, "scene") or not SceneRouter.SCENES.has(String(data.get("scene", "village"))):
		return false
	if not _is_optional_string(data, "spawn_point") or not ["default", "from_village", "from_guild", "from_wasteland", "clinic", "saved"].has(String(data.get("spawn_point", "default"))):
		return false
	if not _is_optional_string(data, "route") or DataRegistry.get_wasteland_route(String(data.get("route", "scrap_highway"))).is_empty():
		return false
	if not _valid_item_counts(data["inventory"]):
		return false
	if not _valid_equipment(data["equipment"], data["inventory"]):
		return false
	if not _valid_known_id_array(data.get("discovered_events", []), "event"):
		return false
	if not _valid_known_id_array(data.get("talked_npcs", []), "npc"):
		return false
	if not _valid_known_id_array(data.get("completed_quests", []), "quest"):
		return false
	var active_quest = data.get("active_quest_id", "")
	if typeof(active_quest) != TYPE_STRING or (not String(active_quest).is_empty() and DataRegistry.get_quest(String(active_quest)).is_empty()):
		return false
	var completed: Array = data.get("completed_quests", [])
	if completed.has(active_quest):
		return false
	if not _valid_quest_progress(data.get("quest_progress", {}), String(active_quest)):
		return false
	if not _valid_route_states(data.get("route_states", {}), completed):
		return false
	if not _valid_weapon_levels(data.get("weapon_levels", {})):
		return false
	if not _valid_perks(data.get("perks", {})):
		return false
	if not _valid_quick_slots(data.get("quick_slots", ["rust_blade", "pipe_rifle", "recycler_glove", "ammo"])):
		return false
	var active_slot = data.get("active_quick_slot", 0)
	if not _is_integer_value(active_slot) or int(active_slot) < 0 or int(active_slot) >= 4:
		return false
	if int(version) >= 5 and not EXPEDITION_SCRIPT.valid_save(data.get("expedition"), data):
		return false
	return true

func _valid_weapon_levels(value: Variant) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		return false
	for item_id in value.keys():
		if typeof(item_id) != TYPE_STRING:
			return false
		var item := DataRegistry.get_equipment(String(item_id))
		if item.is_empty() or not ["weapon", "ranged"].has(String(item.get("slot", ""))):
			return false
		var item_level = value[item_id]
		if not _is_integer_value(item_level) or int(item_level) < 1 or int(item_level) > 5:
			return false
	return true

func _valid_perks(value: Variant) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		return false
	for perk_id in value.keys():
		if typeof(perk_id) != TYPE_STRING or not PERKS_CATALOG.has(String(perk_id)):
			return false
		var perk_level = value[perk_id]
		var max_level := int(PERKS_CATALOG[String(perk_id)].get("max_level", 3))
		if not _is_integer_value(perk_level) or int(perk_level) < 0 or int(perk_level) > max_level:
			return false
	return true

func _valid_item_counts(items: Dictionary) -> bool:
	for item_id in items.keys():
		var id := String(item_id)
		if DataRegistry.get_equipment(id).is_empty() and DataRegistry.get_resource(id).is_empty():
			return false
		if not _is_integer_value(items[item_id]) or int(items[item_id]) < 0:
			return false
	return true

func _valid_equipment(items: Dictionary, owned_items: Dictionary) -> bool:
	for slot in items.keys():
		var slot_id := String(slot)
		if not ["weapon", "ranged", "armor", "tool"].has(slot_id):
			return false
		var item_id = items[slot]
		if typeof(item_id) != TYPE_STRING:
			return false
		var equipment_data := DataRegistry.get_equipment(String(item_id))
		if equipment_data.is_empty() or String(equipment_data.get("slot", "")) != slot_id:
			return false
	for slot in DEFAULT_EQUIPMENT.keys():
		var item_id := String(items.get(slot, DEFAULT_EQUIPMENT[slot]))
		if int(owned_items.get(item_id, 0)) <= 0:
			return false
	return true

func _valid_known_id_array(value: Variant, kind: String) -> bool:
	if typeof(value) != TYPE_ARRAY:
		return false
	var seen: Dictionary = {}
	for item in value:
		if typeof(item) != TYPE_STRING:
			return false
		var id := String(item)
		if seen.has(id) or not _is_known_id(id, kind):
			return false
		seen[id] = true
	return true

func _is_known_id(id: String, kind: String) -> bool:
	match kind:
		"event":
			var event_id := id
			var scoped_route := ""
			if id.contains(":"):
				var scoped_id := id.split(":")
				if scoped_id.size() != 2 or DataRegistry.get_wasteland_route(String(scoped_id[0])).is_empty():
					return false
				scoped_route = String(scoped_id[0])
				event_id = String(scoped_id[1])
			for event in DataRegistry.events:
				if String(event.get("id", "")) == event_id:
					if not scoped_route.is_empty() and bool(event.get("story", false)) and String(event.get("route", "")) != scoped_route:
						return false
					return true
		"npc":
			return not DataRegistry.get_npc(id).is_empty()
		"quest":
			return not DataRegistry.get_quest(id).is_empty()
	return false

func _valid_quest_progress(value: Variant, quest_id: String) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		return false
	var known_counters: Dictionary = {}
	for quest in DataRegistry.quests:
		for objective in quest.get("objectives", []):
			if String(objective.get("type", "")) == "defeat":
				known_counters[String(objective.get("counter", "defeat_enemy"))] = true
	var active_quest := DataRegistry.get_quest(quest_id)
	var active_field_objective: Variant = active_quest.get("field_objective", {})
	for counter in value.keys():
		if typeof(counter) != TYPE_STRING:
			return false
		if counter == "campaign":
			if not CAMPAIGN_SCRIPT.valid_state(value[counter], quest_id):
				return false
			continue
		if String(counter) == FIELD_OBJECTIVE_VERSION_KEY:
			if not active_field_objective is Dictionary or active_field_objective.is_empty():
				return false
			if not _is_integer_value(value[counter]) or int(value[counter]) != FIELD_OBJECTIVE_VERSION:
				return false
			continue
		if not known_counters.has(String(counter)):
			return false
		if not _is_integer_value(value[counter]) or int(value[counter]) < 0:
			return false
	return true

func _valid_route_states(value: Variant, completed_ids: Array) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		return false
	for route_id in value.keys():
		if typeof(route_id) != TYPE_STRING or DataRegistry.get_wasteland_route(String(route_id)).is_empty() or typeof(value[route_id]) != TYPE_DICTIONARY:
			return false
		var state: Dictionary = value[route_id]
		if state.has("campaign_choices") and not _valid_campaign_consequences(state["campaign_choices"], String(route_id)):
			return false
		if state.has("campaign_completed"):
			var recorded: Variant = state["campaign_completed"]
			if not recorded is String or not completed_ids.has(recorded):
				return false
			if DataRegistry.get_quest(recorded).get("route", "") != route_id or CAMPAIGN_SCRIPT.outings(recorded).is_empty():
				return false
			for entry: Dictionary in CAMPAIGN_SCRIPT.outings(recorded):
				for definition: Dictionary in entry.get("actions", []):
					if definition.get("type", "") == "choice" and not CAMPAIGN_SCRIPT.valid_result(definition, state.get("campaign_choices", {}).get(definition["id"])):
						return false
		if state.has("field_objectives"):
			var fields: Variant = state["field_objectives"]
			if not fields is Dictionary:
				return false
			for objective_id: Variant in fields:
				if typeof(objective_id) != TYPE_STRING or String(objective_id).is_empty() or typeof(fields[objective_id]) != TYPE_BOOL:
					return false
	return true

func _valid_quick_slots(value: Variant) -> bool:
	if typeof(value) != TYPE_ARRAY or value.size() > 4:
		return false
	for item in value:
		if typeof(item) != TYPE_STRING:
			return false
		var id := String(item)
		if not id.is_empty() and DataRegistry.get_equipment(id).is_empty() and DataRegistry.get_resource(id).is_empty():
			return false
	return true

func _is_optional_string(data: Dictionary, key: String) -> bool:
	return not data.has(key) or typeof(data[key]) == TYPE_STRING

func _is_integer_field_in_range(data: Dictionary, key: String, minimum: int, maximum: int) -> bool:
	if not data.has(key):
		return true
	return _is_integer_value(data[key]) and int(data[key]) >= minimum and int(data[key]) <= maximum

func _is_integer_value(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	if typeof(value) != TYPE_FLOAT:
		return false
	var numeric_value := float(value)
	return is_finite(numeric_value) and abs(numeric_value) <= 9007199254740991.0 and floor(numeric_value) == numeric_value

func _is_number_value(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	return typeof(value) == TYPE_FLOAT and is_finite(float(value))

func _equipment_with_defaults(loaded_equipment: Dictionary) -> Dictionary:
	var merged: Dictionary = DEFAULT_EQUIPMENT.duplicate(true)
	for slot in loaded_equipment.keys():
		merged[String(slot)] = String(loaded_equipment[slot])
	return merged

func _string_array(source) -> Array[String]:
	var result: Array[String] = []
	if typeof(source) != TYPE_ARRAY:
		return result
	for value in source:
		result.append(String(value))
	return result

func _emit_all() -> void:
	stats_changed.emit()
	inventory_changed.emit()
	equipment_changed.emit()

func _sync_resource_counters() -> void:
	ammo = quest_item_count("ammo")
	scrap = int(inventory.get("scrap", 0))
	cores = int(inventory.get("mutant_core", 0))
	crystals = int(inventory.get("bio_crystal", 0))

func _sync_quick_slot_for_equipment(slot: String, item_id: String) -> void:
	var index := -1
	match slot:
		"weapon":
			index = 0
		"ranged":
			index = 1
		"tool":
			index = 2
	if index >= 0 and index < quick_slots.size():
		quick_slots[index] = item_id

func _join_strings(parts: Array[String], delimiter: String) -> String:
	var result := ""
	for i in range(parts.size()):
		if i > 0:
			result += delimiter
		result += parts[i]
	return result

func _ensure_input_actions() -> void:
	_register_key("move_up", KEY_W)
	_register_key("move_down", KEY_S)
	_register_key("move_left", KEY_A)
	_register_key("move_right", KEY_D)
	_register_key("interact", KEY_E)
	_register_key("open_inventory", KEY_I)
	_register_key("save_game", KEY_F5)
	_register_key("load_game", KEY_F9)
	_register_key("toggle_minimap", KEY_M)
	_register_key("toggle_help", KEY_H)
	_register_key("swap_weapon", KEY_Q)
	_register_key("quick_slot_1", KEY_1)
	_register_key("quick_slot_2", KEY_2)
	_register_key("quick_slot_3", KEY_3)
	_register_key("quick_slot_4", KEY_4)
	_register_mouse("primary_attack", MOUSE_BUTTON_LEFT)
	_unregister_mouse("attack_melee", MOUSE_BUTTON_LEFT)
	_unregister_mouse("attack_ranged", MOUSE_BUTTON_LEFT)
	_register_key("attack_melee", KEY_SPACE)
	_register_mouse("attack_ranged", MOUSE_BUTTON_RIGHT)
	_register_key("dash", KEY_SHIFT)

func _register_key(action_name: String, physical_key: Key) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey and event.physical_keycode == physical_key:
			return
	var event := InputEventKey.new()
	event.physical_keycode = physical_key
	event.keycode = physical_key
	InputMap.action_add_event(action_name, event)

func _register_mouse(action_name: String, button_index: MouseButton) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	for event in InputMap.action_get_events(action_name):
		if event is InputEventMouseButton and event.button_index == button_index:
			return
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	InputMap.action_add_event(action_name, event)

func _unregister_mouse(action_name: String, button_index: MouseButton) -> void:
	if not InputMap.has_action(action_name):
		return
	for event in InputMap.action_get_events(action_name):
		if event is InputEventMouseButton and event.button_index == button_index:
			InputMap.action_erase_event(action_name, event)
			return
