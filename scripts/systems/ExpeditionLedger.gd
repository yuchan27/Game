extends RefCounted

const CAMPAIGN := preload("res://scripts/systems/CampaignProgress.gd")
const DRAFT_PACKAGES := {
	"arc": {"name": "電弧射手", "perks": ["arc_overload", "armor_piercer"],
		"description": "本趟電弧與貫通各加 1 級，支援遠程攻擊敵群。",
		"tradeoff": "只強化遠程效果，不補彈藥，也不提供近戰或拾取回復。"},
	"melee": {"name": "近戰推進", "perks": ["vibro_rend", "dodge_blast"],
		"description": "本趟近戰撕裂與閃避衝擊各加 1 級，近身後製造退路。",
		"tradeoff": "需要靠近敵人並掌握閃避時機，不提供遠程貫通或拾取回復。"},
	"salvage": {"name": "回收維生", "perks": ["nano_salvage", "scavenger_savant"],
		"description": "本趟拾取回復與廢鐵拾取加成各加 1 級。",
		"tradeoff": "依賴拾取物，繞路會增加風險；沒有直接傷害加成，返村拆解不受此調校影響。"}
}

# Banked inventory stays in GameState. Only an explicit gate can settle this ledger.
var active: Dictionary = {}
var last_result: Dictionary = {}
var legacy_trip := false
var uncommitted_clues: Array[String] = []

func clear() -> void:
	active.clear()
	last_result.clear()
	legacy_trip = false
	uncommitted_clues.clear()

func begin(route_id: String, quest_id: String) -> void:
	active = {
		"id": Crypto.new().generate_random_bytes(16).hex_encode(),
		"route": route_id, "quest_id": quest_id,
		"haul": {}, "counters": {}, "fields": {}, "claims": [], "sources": [], "layout": {},
		"draft_choices": {}, "pending_draft": "",
		"campaign_outing": "", "campaign_actions": {}, "campaign_runtime": {}
	}

func finish(outcome: String) -> Dictionary:
	if active.is_empty():
		legacy_trip = false
		return {}
	var result := active.duplicate(true)
	# Clear before publishing any result, so repeated callbacks cannot settle twice.
	active = {}
	legacy_trip = false
	last_result = {
		"id": result["id"], "route": result["route"], "quest_id": result["quest_id"],
		"outcome": outcome, "haul": result["haul"].duplicate(true),
		"counters": result["counters"].duplicate(true), "fields": result["fields"].duplicate(true),
		"draft_choices": result.get("draft_choices", {}).duplicate(true)
	}
	last_result["campaign_outing"] = result.get("campaign_outing", "")
	last_result["campaign_actions"] = result.get("campaign_actions", {}).duplicate(true)
	return result

func save_data() -> Dictionary:
	return {"active": active.duplicate(true), "last_result": last_result.duplicate(true),
		"legacy_trip": legacy_trip, "uncommitted_clues": uncommitted_clues.duplicate()}

func load_data(value: Dictionary) -> void:
	active = value["active"].duplicate(true)
	if not active.is_empty():
		# v5 saves made before drafts have no choice state and remain resumable.
		active["draft_choices"] = active.get("draft_choices", {})
		active["pending_draft"] = active.get("pending_draft", "")
		active["campaign_outing"] = active.get("campaign_outing", "")
		active["campaign_actions"] = active.get("campaign_actions", {})
		active["campaign_runtime"] = active.get("campaign_runtime", {})
	last_result = value["last_result"].duplicate(true)
	legacy_trip = value["legacy_trip"]
	uncommitted_clues.clear()
	for clue: String in value["uncommitted_clues"]:
		uncommitted_clues.append(clue)

func perk_bonus(perk_id: String) -> int:
	var bonus := 0
	for package_id: String in active.get("draft_choices", {}).values():
		if DRAFT_PACKAGES.get(package_id, {}).get("perks", []).has(perk_id):
			bonus += 1
	return bonus

func offer_draft(milestone_id: String) -> bool:
	if active.is_empty() or draft_site(active["route"], milestone_id).is_empty():
		return false
	if active.get("draft_choices", {}).has(milestone_id):
		return false
	if active.get("draft_choices", {}).size() >= 2:
		return false
	if String(active.get("pending_draft", "")).is_empty():
		active["pending_draft"] = milestone_id
	return true

func choose_draft(package_id: String) -> bool:
	var pending := String(active.get("pending_draft", ""))
	if active.is_empty() or pending.is_empty() or not DRAFT_PACKAGES.has(package_id):
		return false
	var choices: Dictionary = active.get("draft_choices", {})
	if choices.has(pending) or choices.size() >= 2:
		return false
	choices[pending] = package_id
	active["draft_choices"] = choices
	active["pending_draft"] = ""
	return true

static func draft_site(route_id: String, milestone_id: String) -> Dictionary:
	if milestone_id.is_empty():
		return {}
	for point: Dictionary in DataRegistry.get_wasteland_route(route_id).get("exploration_points", []):
		if point.get("draft_id", "") == milestone_id:
			return point
	return {}

static func valid_save(value: Variant, context: Dictionary) -> bool:
	if not value is Dictionary:
		return false
	for key in ["active", "last_result"]:
		if not value.get(key) is Dictionary:
			return false
	if typeof(value.get("legacy_trip")) != TYPE_BOOL or not value.get("uncommitted_clues") is Array:
		return false
	var scene := String(context.get("scene", "village"))
	if value["legacy_trip"] and (scene != "wasteland" or not value["active"].is_empty()):
		return false
	var clues: Dictionary = {}
	for key: Variant in value["uncommitted_clues"]:
		if not key is String or clues.has(key) or not _known_claim(key, "", true):
			return false
		if not context.get("discovered_events", []).has(key):
			return false
		clues[key] = true
	var previous: Dictionary = value["last_result"]
	if not previous.is_empty():
		if not _valid_result(previous) or previous.get("outcome", "") not in ["extracted", "lost"]:
			return false
	var run: Dictionary = value["active"]
	if run.is_empty():
		return scene != "wasteland" or bool(value["legacy_trip"])
	if scene != "wasteland" or not _valid_result(run):
		return false
	if run["id"] == previous.get("id", "") or run["route"] != context.get("route", "scrap_highway"):
		return false
	if run["quest_id"] != context.get("active_quest_id", ""):
		return false
	if not CAMPAIGN.valid_active_run(run, context.get("quest_progress", {})):
		return false
	if not run.get("layout", {}) is Dictionary:
		return false
	for pool: Variant in run.get("layout", {}):
		if pool not in ["resources", "harvest"] or not run["layout"][pool] is Array or run["layout"][pool].size() > 512:
			return false
		for position: Variant in run["layout"][pool]:
			if not position is Array or position.size() != 2:
				return false
			for coordinate: Variant in position:
				if typeof(coordinate) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(coordinate)) or float(coordinate) < 0 or float(coordinate) > 32768:
					return false
	for collection in ["claims", "sources"]:
		if not run.get(collection) is Array:
			return false
		var seen: Dictionary = {}
		for key: Variant in run[collection]:
			if not key is String or seen.has(key):
				return false
			if collection == "claims" and not _known_claim(key, run["route"], false):
				return false
			if collection == "sources" and not _known_source(key, run["route"]):
				return false
			seen[key] = true
	return _valid_drafts(run) and CAMPAIGN.valid_run(run)

static func _valid_result(run: Dictionary) -> bool:
	if not run.get("id") is String or String(run["id"]).is_empty() or String(run["id"]).length() > 64:
		return false
	if not run.get("route") is String or DataRegistry.get_wasteland_route(run["route"]).is_empty():
		return false
	if not run.get("quest_id") is String:
		return false
	var quest := DataRegistry.get_quest(run["quest_id"])
	if not String(run["quest_id"]).is_empty() and quest.is_empty():
		return false
	if not run.get("haul") is Dictionary or not run.get("counters") is Dictionary or not run.get("fields") is Dictionary:
		return false
	for item: Variant in run["haul"]:
		if not item is String or (DataRegistry.get_resource(item).is_empty() and DataRegistry.get_equipment(item).is_empty()):
			return false
		if not _count(run["haul"][item]):
			return false
	var known_counters: Dictionary = {}
	if String(quest.get("route", "")) == run["route"]:
		for objective: Dictionary in quest.get("objectives", []):
			if objective.get("type", "") == "defeat":
				known_counters[String(objective.get("counter", "defeat_enemy"))] = true
	for counter: Variant in run["counters"]:
		if not counter is String or not known_counters.has(counter) or not _count(run["counters"][counter]):
			return false
	var field: Dictionary = quest.get("field_objective", {})
	for field_id: Variant in run["fields"]:
		if not field_id is String or field_id != field.get("id", "") or field.get("route", "") != run["route"] or typeof(run["fields"][field_id]) != TYPE_BOOL or run["fields"][field_id] != true:
			return false
	return _valid_drafts(run) and CAMPAIGN.valid_run(run)

static func _valid_drafts(run: Dictionary) -> bool:
	var choices: Variant = run.get("draft_choices", {})
	var pending: Variant = run.get("pending_draft", "")
	if not choices is Dictionary or choices.size() > 2 or not pending is String:
		return false
	for milestone: Variant in choices:
		if not milestone is String or draft_site(run["route"], milestone).is_empty():
			return false
		if not choices[milestone] is String or not DRAFT_PACKAGES.has(choices[milestone]):
			return false
	if not pending.is_empty() and (choices.size() >= 2 or choices.has(pending) or draft_site(run["route"], pending).is_empty()):
		return false
	return true

static func _known_claim(key: String, route: String, story: bool) -> bool:
	var parts := key.split(":", false)
	if parts.size() != 2 or DataRegistry.get_wasteland_route(parts[0]).is_empty():
		return false
	if not route.is_empty() and parts[0] != route:
		return false
	var event := DataRegistry.get_event(parts[1])
	return not event.is_empty() and bool(event.get("story", false)) == story and (not story or event.get("route", "") == parts[0])

static func _known_source(key: String, route: String) -> bool:
	var parts := key.split(":", false)
	if parts.size() < 3 or parts[1] != route:
		return false
	if parts[0] == "resource":
		return parts.size() == 3 and parts[2].is_valid_int() and int(parts[2]) >= 0 and int(parts[2]) < 10000
	if parts[0] == "boss":
		if parts.size() != 3 or route not in ["old_factory", "underground_facility"] or parts[2] != "waste_titan":
			return false
		return String(DataRegistry.get_enemy(parts[2]).get("type", "")) == "boss"
	if parts[0] != "harvest" or parts.size() != 4:
		return false
	return parts[2].is_valid_int() and parts[3].is_valid_int() and int(parts[2]) >= 0 and int(parts[2]) <= 32768 and int(parts[3]) >= 0 and int(parts[3]) <= 32768

static func _count(value: Variant) -> bool:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	var number := float(value)
	return is_finite(number) and number >= 0 and number <= 2147483647 and floorf(number) == number
