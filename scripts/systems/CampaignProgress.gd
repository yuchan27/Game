extends RefCounted

# Authored outings supplement existing quest IDs, goals and one-time rewards.
static func new_state() -> Dictionary:
	return {"version": 1, "outing_index": 0, "actions": {}}

static func outings(quest_id: String) -> Array:
	return DataRegistry.get_quest(quest_id).get("campaign_outings", [])

static func current(quest_id: String, state: Dictionary) -> Dictionary:
	var entries := outings(quest_id)
	var index := int(state.get("outing_index", entries.size()))
	return entries[index] if index >= 0 and index < entries.size() else {}

static func outing_by_id(quest_id: String, outing_id: String) -> Dictionary:
	for entry: Dictionary in outings(quest_id):
		if entry.get("id", "") == outing_id:
			return entry
	return {}

static func action(quest_id: String, action_id: String, outing_id := "") -> Dictionary:
	for entry: Dictionary in outings(quest_id):
		if not outing_id.is_empty() and entry.get("id", "") != outing_id:
			continue
		for definition: Dictionary in entry.get("actions", []):
			if definition.get("id", "") == action_id:
				return definition
	return {}

static func option(definition: Dictionary, result: String) -> Dictionary:
	for entry: Dictionary in definition.get("options", []):
		if entry.get("id", "") == result:
			return entry
	return {}

static func effective_duration(definition: Dictionary, outing_actions: Array, selected_option_id: String) -> float:
	var base_duration := float(definition.get("duration", 3.0))
	var route_choice_id := String(definition.get("route_choice", ""))
	if route_choice_id.is_empty() or selected_option_id.is_empty():
		return maxf(0.1, base_duration)
	for candidate in outing_actions:
		if not candidate is Dictionary or String(candidate.get("id", "")) != route_choice_id:
			continue
		var selected := option(candidate, selected_option_id)
		if not selected.is_empty():
			return maxf(0.1, float(selected.get("duration", base_duration)))
		break
	return maxf(0.1, base_duration)

static func ready(entry: Dictionary, actions: Dictionary) -> bool:
	if entry.is_empty() or entry.get("actions", []).is_empty():
		return false
	for definition: Dictionary in entry.get("actions", []):
		if not actions.has(definition["id"]):
			return false
	return true

static func field_notes(quest_id: String, results: Dictionary, provisional: Dictionary) -> String:
	var sections: Array[String] = []
	for entry: Dictionary in outings(quest_id):
		var lines: Array[String] = []
		for definition: Dictionary in entry.get("actions", []):
			var action_id := String(definition["id"])
			if not valid_result(definition, results.get(action_id)):
				continue
			var result := String(definition.get("result_text", definition.get("name", "")))
			if definition.get("type", "") == "choice":
				result = String(option(definition, String(results[action_id])).get("name", "")) + "；" + result
			lines.append("%s｜%s：%s" % ["本趟待帶回" if provisional.has(action_id) else "已帶回", String(definition.get("name", action_id)), result])
		if not lines.is_empty():
			sections.append(String(entry.get("name", "")) + "\n" + "\n".join(lines))
	return "\n\n".join(sections)

static func action_receipt(quest_id: String, outing_id: String, results: Dictionary) -> String:
	var lines: Array[String] = []
	for definition: Dictionary in outing_by_id(quest_id, outing_id).get("actions", []):
		var action_id := String(definition["id"])
		if not valid_result(definition, results.get(action_id)):
			continue
		var line := String(definition.get("name", action_id))
		if definition.get("type", "") == "choice":
			line += "：" + String(option(definition, String(results[action_id])).get("name", ""))
		lines.append("• " + line)
	return "\n".join(lines)

static func return_report(quest_id: String, outing_id: String, committed: Dictionary, new_actions: Dictionary) -> String:
	var entry := outing_by_id(quest_id, outing_id)
	if entry.is_empty():
		return ""
	var report := ""
	if ready(entry, committed):
		var entries := outings(quest_id)
		var next_index := entries.find(entry) + 1
		report = String(entry.get("return_text", "本趟行動成果已帶回。"))
		if next_index < entries.size():
			report += "\n下一趟：%s。回到原路線出發點再出征；章節報酬仍須完成全部目標後按 [J] 交付。" % String(entries[next_index].get("name", ""))
		else:
			report += "\n兩趟章節行動已完成；確認原委託的材料、清剿與調查目標後按 [J] 交付。"
		return report
	report = "本趟未新增完整章節步驟；先前已帶回的成果仍保留。" if new_actions.is_empty() else "本趟完成的步驟已帶回，尚未完成這趟全部行動。"
	report += "\n未完成操作的計時、護送與搬運位置會在下次出發重新開始。"
	for definition: Dictionary in entry.get("actions", []):
		if not committed.has(definition["id"]):
			report += "\n下趟續作：%s。從村莊同一路線出發；已帶回的前段不用重做。" % String(definition.get("name", "現場行動"))
			break
	return report

static func valid_result(definition: Dictionary, value: Variant) -> bool:
	if definition.is_empty() or not value is String:
		return false
	return not option(definition, value).is_empty() if definition.get("type", "") == "choice" else value == "done"

static func valid_state(value: Variant, quest_id: String) -> bool:
	if not value is Dictionary or value.get("version") != 1 or not _whole(value.get("version"), 1):
		return false
	var entries := outings(quest_id)
	if entries.is_empty() or not _whole(value.get("outing_index"), entries.size()) or not value.get("actions") is Dictionary:
		return false
	var index := int(value["outing_index"])
	var results: Dictionary = value["actions"]
	for action_id: Variant in results:
		if not action_id is String:
			return false
		var definition := action(quest_id, action_id)
		if not valid_result(definition, results[action_id]):
			return false
		for requirement: String in definition.get("requires", []):
			if not results.has(requirement):
				return false
	for entry_index in range(entries.size()):
		var entry: Dictionary = entries[entry_index]
		if entry_index < index and not ready(entry, results):
			return false
		if entry_index > index:
			for definition: Dictionary in entry.get("actions", []):
				if results.has(definition["id"]):
					return false
	# A finished current outing must have advanced at its extraction boundary.
	return index >= entries.size() or not ready(entries[index], results)

static func valid_runtime(definition: Dictionary, progress: Variant) -> bool:
	if definition.is_empty() or not progress is Dictionary:
		return false
	for key: Variant in progress:
		if key == "started":
			if typeof(progress[key]) != TYPE_BOOL:
				return false
		elif key == "checkpoint":
			if not _whole(progress[key], 32):
				return false
		elif key in ["elapsed", "actor_x", "actor_y"]:
			if typeof(progress[key]) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(progress[key])) or float(progress[key]) < 0.0:
				return false
			var limit := maxf(1.0, float(definition.get("duration", 120.0))) if key == "elapsed" else 32768.0
			if float(progress[key]) > limit:
				return false
		else:
			return false
	return true

static func valid_run(run: Dictionary) -> bool:
	var outing_id: Variant = run.get("campaign_outing", "")
	var actions: Variant = run.get("campaign_actions", {})
	var runtime: Variant = run.get("campaign_runtime", {})
	if not outing_id is String or not actions is Dictionary or not runtime is Dictionary:
		return false
	if outing_id.is_empty():
		return actions.is_empty() and runtime.is_empty()
	var quest_id := String(run.get("quest_id", ""))
	if outing_by_id(quest_id, outing_id).is_empty() or DataRegistry.get_quest(quest_id).get("route", "") != run.get("route", ""):
		return false
	for action_id: Variant in actions:
		if not action_id is String or not valid_result(action(quest_id, action_id, outing_id), actions[action_id]):
			return false
	for action_id: Variant in runtime:
		if not action_id is String or not valid_runtime(action(quest_id, action_id, outing_id), runtime[action_id]):
			return false
	return true

static func valid_active_run(run: Dictionary, quest_progress: Dictionary) -> bool:
	var state: Dictionary = quest_progress.get("campaign", {})
	var entry := current(String(run.get("quest_id", "")), state) if not state.is_empty() else {}
	if DataRegistry.get_quest(String(run.get("quest_id", ""))).get("route", "") != run.get("route", ""):
		entry = {}
	if String(run.get("campaign_outing", "")) != String(entry.get("id", "")):
		return false
	var results: Dictionary = state.get("actions", {}).duplicate(true)
	var provisional: Dictionary = run.get("campaign_actions", {})
	for action_id: String in provisional:
		if results.has(action_id):
			return false
	results.merge(provisional)
	for action_id: String in provisional:
		for requirement: String in action(String(run["quest_id"]), action_id).get("requires", []):
			if not results.has(requirement):
				return false
	return true

static func _whole(value: Variant, maximum: int) -> bool:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	return is_finite(float(value)) and float(value) >= 0 and float(value) <= maximum and floorf(float(value)) == float(value)
