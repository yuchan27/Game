extends Node

var checks: Array[Dictionary] = []
var failures: Array[String] = []
var output_dir := "user://qa"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var arguments := OS.get_cmdline_user_args()
	for index in range(arguments.size() - 1):
		if arguments[index] == "--qa-output":
			output_dir = arguments[index + 1]
	_run.call_deferred()

func _run() -> void:
	# Keep the test harness alive while exercising actual SceneTree replacements.
	get_tree().current_scene = null
	var start := Node2D.new()
	get_tree().root.add_child(start)
	get_tree().current_scene = start
	GameState.reset_new_run(false)
	SaveManager.default_save_path = output_dir.path_join("entrance-save.json")
	SceneRouter.change_to("village", "default", SaveManager.default_save_path)
	await get_tree().process_frame
	_expect(SceneRouter.transition_active and get_tree().paused, "departure pauses gameplay during the curtain")
	var overlay := _entrance()
	_expect(overlay != null and bool(overlay.get_meta("gameplay_input_blocked", false)), "transition overlay owns the gameplay input blocker")
	SceneRouter.change_to("wasteland")
	_expect(GameState.current_scene_id == "village", "repeated transition requests cannot replace the destination")
	await _wait_for_transition()
	_expect(not get_tree().paused, "arrival automatically releases its transition pause")
	_expect(get_tree().current_scene != null and get_tree().current_scene.scene_file_path.ends_with("Village.tscn"), "village actually becomes the current scene")
	_expect(_entrance() == null, "finished transition removes its input overlay")
	_expect(get_tree().get_nodes_in_group("player").size() == 1, "actual scene replacement has exactly one player")
	SceneRouter.change_to("guild", "default", SaveManager.default_save_path)
	for _index in range(100):
		await get_tree().create_timer(0.02, true).timeout
		overlay = _entrance()
		if overlay != null and bool(overlay.get("arriving")):
			break
	_expect(overlay != null and bool(overlay.get("arriving")), "second region reaches its arrival title")
	if overlay != null:
		var label := overlay.get("title_label") as Label
		_expect(label != null and label.text == "回收者公會", "arrival title matches the loaded destination")
		var key := InputEventKey.new()
		key.pressed = true
		key.keycode = KEY_ENTER
		Input.parse_input_event(key)
		await get_tree().process_frame
		key = InputEventKey.new()
		key.keycode = KEY_ENTER
		key.pressed = false
		Input.parse_input_event(key)
	await _wait_for_transition()
	_expect(not get_tree().paused and not SceneRouter.transition_active, "skip input restores interactive gameplay")
	_expect(get_tree().current_scene.scene_file_path.ends_with("Guild.tscn"), "skip never cancels or changes the loaded scene")
	SceneRouter.change_to("main")
	await _wait_for_transition()
	_expect(not get_tree().paused and get_tree().current_scene.scene_file_path.ends_with("Main.tscn"), "returning to title leaves an interactive unpaused scene")
	_finish()

func _entrance() -> Control:
	for node in get_tree().get_nodes_in_group("gameplay_input_blocker"):
		if node.name == "SceneEntrance" and not node.is_queued_for_deletion():
			return node as Control
	return null

func _wait_for_transition() -> void:
	await get_tree().process_frame
	for _index in range(160):
		if not SceneRouter.transition_active and SceneRouter._pending_scene_id.is_empty():
			await get_tree().process_frame
			return
		await get_tree().create_timer(0.05, true).timeout
	_expect(false, "scene transition finishes within 8 seconds")

func _expect(passed: bool, label: String) -> void:
	checks.append({"name": label, "passed": passed})
	if not passed:
		failures.append(label)
	print("[ENTRANCE %s] %s" % ["PASS" if passed else "FAIL", label])

func _finish() -> void:
	get_tree().paused = false
	DirAccess.make_dir_recursive_absolute(output_dir)
	var file := FileAccess.open(output_dir.path_join("scene_entrance_regression_report.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"status": "passed" if failures.is_empty() else "failed", "success": failures.is_empty(), "checks": checks, "failures": failures}, "\t"))
	else:
		failures.append("report could not be written")
	AudioManager.stop_all()
	await get_tree().create_timer(0.1, true).timeout
	get_tree().quit(0 if failures.is_empty() else 1)
