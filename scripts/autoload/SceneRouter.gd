extends Node

signal transition_finished(succeeded: bool)
signal load_finished(succeeded: bool, save_succeeded: bool)

const SCENES := {
	"main": "res://scenes/main/Main.tscn",
	"village": "res://scenes/levels/village/Village.tscn",
	"wasteland": "res://scenes/levels/wasteland/Wasteland.tscn",
	"guild": "res://scenes/levels/guild/Guild.tscn"
}

var _pending_scene_id := ""
var _pending_spawn_point := "default"
var _pending_save_path := ""
var _pending_travel_reason := ""
var _pending_load_data: Dictionary = {}
var transition_active := false
const ENTRANCE := preload("res://scripts/ui/SceneEntrance.gd")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func is_transition_pending() -> bool:
	return transition_active or not _pending_scene_id.is_empty()

func change_to(scene_id: String, spawn_point := "default", save_path := "", travel_reason := "") -> void:
	if transition_active or not _pending_scene_id.is_empty():
		return
	if not SCENES.has(scene_id):
		GameState.notify("找不到場景：%s" % scene_id)
		return
	if travel_reason == "extract" and (GameState.current_scene_id != "wasteland" or scene_id != "village" or spawn_point != "from_wasteland" or GameState.death_pending or GameState.hp <= 0):
		return
	if (GameState.has_active_expedition() or GameState.is_legacy_expedition()) and GameState.current_scene_id == "wasteland" and scene_id in ["village", "guild"] and travel_reason not in ["extract", "death"]:
		GameState.notify("請抵達地圖 [M] 的返村門，才能帶回本趟收穫。")
		return
	if travel_reason == "death" and (not GameState.death_pending or scene_id != "village" or spawn_point != "clinic"):
		return
	if scene_id == "main" and GameState.death_pending:
		GameState.cancel_death_recovery()
	_queue_transition(scene_id, spawn_point, save_path, travel_reason)

func load_saved_game(data: Dictionary, save_path: String) -> bool:
	if is_transition_pending() or not GameState.is_save_data_valid(data):
		return false
	# Loading replaces state; it is neither extraction nor cancellation of the old run.
	_queue_transition(String(data.get("scene", "village")), String(data.get("spawn_point", "default")), save_path, "load", data)
	return true

func _queue_transition(scene_id: String, spawn_point: String, save_path: String, travel_reason: String, load_data: Dictionary = {}) -> void:
	_pending_scene_id = scene_id
	_pending_spawn_point = spawn_point
	_pending_save_path = save_path
	_pending_travel_reason = travel_reason
	_pending_load_data = load_data.duplicate(true)
	AudioManager.play_sfx("transition")
	call_deferred("_change_scene_deferred")

func _change_scene_deferred() -> void:
	if _pending_scene_id.is_empty():
		return
	var scene_id := _pending_scene_id
	var spawn_point := _pending_spawn_point
	var save_path := _pending_save_path
	var travel_reason := _pending_travel_reason
	var load_data := _pending_load_data
	var origin_scene := GameState.current_scene_id
	var origin_spawn := GameState.active_spawn_point
	_pending_scene_id = ""
	_pending_load_data = {}
	transition_active = true
	var was_paused := get_tree().paused
	get_tree().paused = true
	var layer := CanvasLayer.new()
	layer.layer = 100
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var entrance := ENTRANCE.new()
	layer.add_child(entrance)
	await entrance.cover()
	_flush_campaign_progress()
	var load_checkpoint: Dictionary = {}
	var error := OK
	if travel_reason == "load":
		# No await between snapshot, silent apply and the native scene request.
		load_checkpoint = GameState.capture_runtime_state()
		if not GameState.load_save_data(load_data, false):
			error = ERR_INVALID_DATA
		else:
			# HP0/legacy normalization can change the saved destination to the clinic.
			scene_id = GameState.current_scene_id
			spawn_point = GameState.active_spawn_point
	else:
		GameState.set_scene(scene_id, spawn_point)
	if error == OK:
		error = get_tree().change_scene_to_file(SCENES[scene_id])
	var result: Dictionary = {}
	var save_succeeded := true
	if error == OK:
		await get_tree().scene_changed
		# The old HUD may release its own modal pause while exiting.
		get_tree().paused = true
		if travel_reason == "load":
			GameState.publish_loaded_state()
		elif travel_reason == "extract":
			result = GameState.settle_expedition(true)
		elif travel_reason == "death":
			result = GameState.complete_death_recovery()
		if scene_id != "main":
			save_succeeded = SaveManager.save_game(false, save_path, false)
		var presentation := entrance_text(scene_id)
		entrance.arrive(presentation[0], presentation[1])
		await entrance.finished
	else:
		if travel_reason == "load":
			# Restore raw runtime state, not a save-schema round trip with normalization.
			GameState.restore_runtime_state(load_checkpoint)
		else:
			GameState.set_scene(origin_scene, origin_spawn)
			var failure_message := "場景載入失敗，請稍後重試。"
			if travel_reason == "death":
				failure_message = "維修艙載入失敗；按 [Esc] 開啟暫停選單，可重試回收或返回標題。"
			GameState.notify(failure_message)
	layer.queue_free()
	get_tree().paused = false if error == OK else was_paused
	transition_active = false
	GameState.show_expedition_result(result, save_succeeded)
	if not save_succeeded and result.is_empty():
		GameState.notify("自動存檔失敗；目前進度仍在本次遊戲中。離開前請按 [Esc] 重新儲存。")
	# Restored panels must acquire their pause after the curtain releases its own.
	transition_finished.emit(error == OK)
	if travel_reason == "load":
		load_finished.emit(error == OK, save_succeeded)

func _flush_campaign_progress() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	# Flush the source run while scene/route ownership is still valid, before
	# normal travel changes scene identity or a load replaces the active ledger.
	for action: Node in get_tree().get_nodes_in_group("campaign_action"):
		if scene.is_ancestor_of(action) and action.has_method("flush_runtime_progress"):
			action.call("flush_runtime_progress")

func entrance_text(scene_id: String) -> Array[String]:
	if scene_id == "wasteland":
		var route := DataRegistry.get_wasteland_route(GameState.current_route_id)
		var quest := DataRegistry.get_quest(GameState.active_quest_id)
		var context := "自由回收・成果須從返村門帶回"
		if not quest.is_empty():
			context = "目前委託：" + String(quest.get("name", ""))
			if quest.get("route", "") == GameState.current_route_id:
				var outing := GameState.campaign_outing()
				if not outing.is_empty():
					context = "本趟：" + String(outing.get("name", ""))
		return [String(route.get("name", "廢土邊境")), context + "\n" + GameState.get_journey_hint()]
	if scene_id == "guild":
		return ["回收者公會", "每一份委託，都有人在等你回來。\n" + GameState.get_journey_hint()]
	if scene_id == "village":
		return ["最後的燈火", "整理行囊、修復裝備，讓下一次出發更有把握。\n" + GameState.get_journey_hint()]
	return ["廢土回收商", "灰燼之後的名字"]
