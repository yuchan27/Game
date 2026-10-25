extends Node

const REGRESSION := preload("res://scripts/tests/WorldExpansionRegression.gd")
const REPORT_FILENAME := "world_expansion_regression_report.json"

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var result: Dictionary = await REGRESSION.new().run(self)
	var checks: Array = result.get("checks", [])
	var failures: Array = result.get("failures", [])
	var passed := not checks.is_empty() and failures.is_empty()
	var report := {"status": "passed" if passed else "failed", "checks": checks, "failures": failures}
	var arguments := OS.get_cmdline_user_args()
	var index := arguments.find("--qa-output")
	if index >= 0 and index + 1 < arguments.size():
		var output := arguments[index + 1]
		var directory_error := DirAccess.make_dir_recursive_absolute(output)
		var file := FileAccess.open(output.path_join(REPORT_FILENAME), FileAccess.WRITE) if directory_error == OK else null
		if file == null:
			push_error("Cannot write world expansion report")
			get_tree().quit(1)
			return
		file.store_string(JSON.stringify(report, "\t"))
	AudioManager.stop_all()
	print("[WORLD] %s: %d checks, %d failures" % [report["status"], checks.size(), failures.size()])
	get_tree().quit(0 if passed else 1)
