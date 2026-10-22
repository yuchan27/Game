extends Node

signal stats_changed
signal inventory_changed
signal equipment_changed
signal scene_changed(scene_id: String)
signal notification_requested(message: String)
signal dialogue_requested(speaker: String, role: String, message: String)
signal dialogue_closed
signal feedback_requested(kind: String, strength: float)

const MAX_HP := 120
const MAX_EP := 60
const SAVE_VERSION := 4
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
var _death_sequence_generation := 0
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
		"desc": "遠程命中時跳躍電弧連鎖打擊周圍 2 名敵人 (每級傷害 +10)。",
		"max_level": 3,
		"icon": "⚡"
	},
	"vibro_rend": {
		"id": "vibro_rend",
		"name": "高週波撕裂 (Vibro-Rend)",
		"desc": "近戰揮砍造成流血與減速，每秒造成持續真實傷害 (每級 +8 點)。",
		"max_level": 3,
		"icon": "🩸"
	},
	"nano_salvage": {
		"id": "nano_salvage",
		"name": "奈米回收力場 (Nano Salvage Field)",
		"desc": "拾取材料或擊殺敵人時，恢復 6 點生命/護盾並釋放金屬擊退衝擊波。",
		"max_level": 3,
		"icon": "🛡"
	},
	"dodge_blast": {
		"id": "dodge_blast",
		"name": "破片推進 (Dodge Blast)",
		"desc": "翻滾閃避時在起點引爆破片衝擊，擊退並重創追擊的怪物。",
		"max_level": 3,
		"icon": "💥"
	},
	"armor_piercer": {
		"id": "armor_piercer",
		"name": "破甲貫通 (Armor Piercer)",
		"desc": "金屬箭矢可穿透目標 (每級 +1 名敵人)，並提高 20% 飛行速度與暴擊率。",
		"max_level": 3,
		"icon": "🏹"
	},
	"scavenger_savant": {
		"id": "scavenger_savant",
		"name": "拾荒大師 (Scavenger Savant)",
		"desc": "拾取與拆解獲得的廢鐵與材料增加 40%，拆解獲得稀有結晶機率翻倍。",
		"max_level": 3,
		"icon": "♻"
	}
}

func _ready() -> void:
	_ensure_input_actions()
	reset_new_run(false)

func reset_new_run(emit_changes := true) -> void:
	_death_sequence_generation += 1
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
	if DataRegistry.get_wasteland_route(route_id).is_empty():
		notify("未知的廢土路線：%s" % route_id)
		return
	current_route_id = route_id
	var route := DataRegistry.get_wasteland_route(route_id)
	notify("路線已切換：%s" % String(route.get("name", route_id)))
	stats_changed.emit()

func mark_intro_seen() -> void:
	intro_seen = true

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
		notify("快捷欄 %d：%s x%d" % [index + 1, String(resource.get("name", item_id)), int(inventory.get(item_id, 0))])
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

func get_stat_bonus(stat_name: String) -> int:
	var total := 0
	for item_id in equipment.values():
		var item := DataRegistry.get_equipment(String(item_id))
		var stats: Dictionary = item.get("stats", {})
		total += int(stats.get(stat_name, 0))
	match stat_name:
		"attack":
			total += attack_upgrade_level * 3
			var active_weapon := active_attack_item_id()
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
	hp = get_max_hp()
	ep = get_max_ep()
	death_pending = false
	stats_changed.emit()
	SceneRouter.change_to("village", "clinic")

func cancel_death_recovery() -> void:
	_death_sequence_generation += 1
	death_pending = false

func heal_full() -> void:
	hp = get_max_hp()
	ep = get_max_ep()
	stats_changed.emit()

func spend_ammo(amount := 1) -> bool:
	return consume_item("ammo", amount)

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

func has_perk(perk_id: String) -> bool:
	return get_perk_level(perk_id) > 0

func unlock_perk(perk_id: String) -> bool:
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
	count = maxi(1, count)
	var available := int(inventory.get(item_id, 0))
	if available <= 0:
		notify("背包中沒有該物品：%s" % item_display_name(item_id))
		return {}

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

	consume_item(item_id, count)
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
		var is_equipped := false
		for slot_item in equipment.values():
			if String(slot_item) == item_id:
				is_equipped = true
				break
		var surplus: int = (count - 1) if is_equipped else count
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

func record_enemy_defeated(boss := false) -> void:
	defeated_enemies += 1
	add_xp(18)
	if _is_active_quest_route():
		advance_quest_counter("defeat_enemy", 1)
		if boss:
			advance_quest_counter("defeat_boss", 1)
	if defeated_enemies % 3 == 0:
		add_item("ammo", 4)
		notify("污染體掉落可用彈藥 x4。")

func start_quest(quest_id: String) -> bool:
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
	active_quest_id = quest_id
	var route_id := String(quest.get("route", ""))
	if not route_id.is_empty():
		current_route_id = route_id
	quest_progress.clear()
	for objective in quest.get("objectives", []):
		if String(objective.get("type", "")) == "defeat":
			var counter := String(objective.get("counter", "defeat_enemy"))
			quest_progress[counter] = 0
	notify("已接下委託：%s" % String(quest.get("name", quest_id)))
	_emit_all()
	SaveManager.save_game(false)
	return true

func advance_quest_counter(counter_id: String, amount := 1) -> void:
	if active_quest_id.is_empty():
		return
	quest_progress[counter_id] = int(quest_progress.get(counter_id, 0)) + amount
	stats_changed.emit()

func is_active_quest_ready() -> bool:
	if active_quest_id.is_empty():
		return false
	var quest := DataRegistry.get_quest(active_quest_id)
	if quest.is_empty():
		return false
	for objective in quest.get("objectives", []):
		var kind := String(objective.get("type", ""))
		var amount := int(objective.get("amount", 0))
		if kind == "collect":
			var item_id := String(objective.get("item", ""))
			if int(inventory.get(item_id, 0)) < amount:
				return false
		elif kind == "defeat":
			var counter := String(objective.get("counter", "defeat_enemy"))
			if int(quest_progress.get(counter, 0)) < amount:
				return false
	return true

func complete_active_quest() -> bool:
	if active_quest_id.is_empty():
		notify("目前沒有可交付的委託。")
		return false
	if not is_active_quest_ready():
		notify("委託目標尚未完成。")
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
	completed_quests.append(completed_id)
	active_quest_id = ""
	quest_progress.clear()
	add_xp(35)
	notify("委託完成：%s" % String(quest.get("name", completed_id)))
	_emit_all()
	SaveManager.save_game(false)
	return true

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
			parts.append("%s %d/%d" % [item_display_name(item_id), int(inventory.get(item_id, 0)), amount])
		elif kind == "defeat":
			var counter := String(objective.get("counter", "defeat_enemy"))
			var objective_name := "擊敗 Boss" if counter == "defeat_boss" else "擊倒污染體"
			parts.append("%s %d/%d" % [objective_name, int(quest_progress.get(counter, 0)), amount])
	return "%s：%s" % [String(quest.get("name", active_quest_id)), _join_strings(parts, "、")]

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
	var message := String(npc.get("line", "")) if first_time else String(npc.get("repeat_line", npc.get("line", "")))
	if first_time:
		talked_npcs.append(npc_id)
		var reward: Dictionary = npc.get("reward", {})
		for item_id in reward.keys():
			add_item(String(item_id), int(reward[item_id]))
	dialogue_requested.emit(String(npc.get("name", npc_id)), String(npc.get("role", "倖存者")), message)
	inventory_changed.emit()
	stats_changed.emit()
	return true

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
		"perks": perks
	}

func load_save_data(data: Dictionary) -> bool:
	if not _is_save_data_valid(data):
		return false
	_death_sequence_generation += 1
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
	_sync_resource_counters()
	hp = clampi(hp, 0, get_max_hp())
	ep = clampi(ep, 0, get_max_ep())
	if hp == 0:
		# Treat older death-window saves as a completed recovery, preserving earned progress.
		current_scene_id = "village"
		active_spawn_point = "clinic"
		hp = get_max_hp()
		ep = get_max_ep()
	_emit_all()
	return true

func _is_active_quest_route() -> bool:
	if active_quest_id.is_empty():
		return false
	var quest := DataRegistry.get_quest(active_quest_id)
	return not quest.is_empty() and String(quest.get("route", "")) == current_route_id

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
	if not _valid_quest_progress(data.get("quest_progress", {})):
		return false
	if not _valid_route_states(data.get("route_states", {})):
		return false
	if not _valid_quick_slots(data.get("quick_slots", ["rust_blade", "pipe_rifle", "recycler_glove", "ammo"])):
		return false
	var active_slot = data.get("active_quick_slot", 0)
	if not _is_integer_value(active_slot) or int(active_slot) < 0 or int(active_slot) >= 4:
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
			if id.contains(":"):
				var scoped_id := id.split(":")
				if scoped_id.size() != 2 or DataRegistry.get_wasteland_route(String(scoped_id[0])).is_empty():
					return false
				event_id = String(scoped_id[1])
			for event in DataRegistry.events:
				if String(event.get("id", "")) == event_id:
					return true
		"npc":
			return not DataRegistry.get_npc(id).is_empty()
		"quest":
			return not DataRegistry.get_quest(id).is_empty()
	return false

func _valid_quest_progress(value: Variant) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		return false
	var known_counters: Dictionary = {}
	for quest in DataRegistry.quests:
		for objective in quest.get("objectives", []):
			if String(objective.get("type", "")) == "defeat":
				known_counters[String(objective.get("counter", "defeat_enemy"))] = true
	for counter in value.keys():
		if typeof(counter) != TYPE_STRING or not known_counters.has(String(counter)):
			return false
		if not _is_integer_value(value[counter]) or int(value[counter]) < 0:
			return false
	return true

func _valid_route_states(value: Variant) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		return false
	for route_id in value.keys():
		if typeof(route_id) != TYPE_STRING or DataRegistry.get_wasteland_route(String(route_id)).is_empty() or typeof(value[route_id]) != TYPE_DICTIONARY:
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
	ammo = int(inventory.get("ammo", 0))
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
	_register_key("open_inventory", KEY_TAB)
	_register_key("save_game", KEY_F5)
	_register_key("load_game", KEY_F9)
	_register_key("toggle_minimap", KEY_M)
	_register_key("toggle_help", KEY_H)
	_register_key("swap_weapon", KEY_Q)
	_register_key("quick_slot_1", KEY_1)
	_register_key("quick_slot_2", KEY_2)
	_register_key("quick_slot_3", KEY_3)
	_register_key("quick_slot_4", KEY_4)
	_register_key("primary_attack", KEY_J)
	_register_mouse("primary_attack", MOUSE_BUTTON_LEFT)
	_unregister_mouse("attack_melee", MOUSE_BUTTON_LEFT)
	_unregister_mouse("attack_ranged", MOUSE_BUTTON_LEFT)
	_register_key("attack_melee", KEY_SPACE)
	_register_mouse("attack_ranged", MOUSE_BUTTON_RIGHT)
	_register_key("attack_ranged", KEY_K)
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
