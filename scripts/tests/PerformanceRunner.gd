extends Node

const WASTELAND_SCENE := preload("res://scenes/levels/wasteland/Wasteland.tscn")
const ASSET_LOADER := preload("res://scripts/utils/RuntimeAssetLoader.gd")

const WARMUP_FRAMES := 90
const SAMPLE_FRAMES := 240
const PROJECTILE_INTERVAL := 6

var qa_output_dir := ""
var checks: Array[Dictionary] = []
var peak_active_projectiles := 0

func _ready() -> void:
	qa_output_dir = _read_user_arg("--qa-output", "")
	DataRegistry.load_all()
	GameState.reset_new_run(false)
	GameState.seed = 424242
	GameState.current_scene_id = "wasteland"
	GameState.set_current_route("crystal_scar")
	GameState.defeated_enemies = int(DataRegistry.map_params.get("boss_spawn_after_defeats", 40))
	await _run_representative_scene_sample()
	_release_test_resources()
	var passed := true
	for check in checks:
		passed = passed and bool(check.get("passed", false))
	var report := _build_report(passed)
	var report_written := _write_report(report)
	if not report_written:
		passed = false
		print("[PERF] Failed to write performance_report.json")
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(0 if passed else 1)


func _release_test_resources() -> void:
	AudioManager.stop_all()
	ASSET_LOADER._texture_cache.clear()

func _run_representative_scene_sample() -> void:
	var setup_start := Time.get_ticks_usec()
	var world := WASTELAND_SCENE.instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var scene_setup_usec := Time.get_ticks_usec() - setup_start
	var enemies := get_tree().get_nodes_in_group("enemy")
	var bosses := get_tree().get_nodes_in_group("boss")
	var props := get_tree().get_nodes_in_group("world_prop")
	var pickups := get_tree().get_nodes_in_group("pickup")
	var pools := get_tree().get_nodes_in_group("projectile_pool")
	_check(enemies.size() >= int(DataRegistry.map_params.get("enemy_limit", 50)), "wasteland enemy load meets configured limit", str(enemies.size()))
	_check(not bosses.is_empty(), "boss AI is active in representative stress route", str(bosses.size()))
	_check(props.size() >= int(DataRegistry.map_params.get("prop_nodes", 58)), "wasteland prop load meets configured count", str(props.size()))
	_check(pickups.size() >= int(DataRegistry.map_params.get("resource_nodes", 24)), "wasteland pickup load meets configured count", str(pickups.size()))
	_check(pools.size() == 1, "wasteland creates one projectile pool", str(pools.size()))
	if pools.is_empty():
		world.queue_free()
		await get_tree().process_frame
		return
	var pool = pools[0]
	var player := get_tree().get_first_node_in_group("player") as Node2D
	_check(player != null, "wasteland creates player for AI target", "player group lookup")
	var warmup_usec: int = await _measure_frame_waits(WARMUP_FRAMES)
	var process_samples: Array[float] = []
	var physics_samples: Array[float] = []
	var process_monitor_samples: Array[float] = []
	var physics_monitor_samples: Array[float] = []
	var draw_call_samples: Array[float] = []
	var rendered_object_samples: Array[float] = []
	var primitive_samples: Array[float] = []
	var memory_before := _memory_static_bytes()
	var node_count_before := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	for frame_index in range(SAMPLE_FRAMES):
		var process_start := Time.get_ticks_usec()
		await get_tree().process_frame
		process_samples.append(float(Time.get_ticks_usec() - process_start) / 1000.0)
		process_monitor_samples.append(float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0)
		draw_call_samples.append(float(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		rendered_object_samples.append(float(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)))
		primitive_samples.append(float(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
		var physics_start := Time.get_ticks_usec()
		await get_tree().physics_frame
		physics_samples.append(float(Time.get_ticks_usec() - physics_start) / 1000.0)
		physics_monitor_samples.append(float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0)
		if player != null and frame_index % PROJECTILE_INTERVAL == 0:
			var direction := Vector2.RIGHT.rotated(float(frame_index % 8) * TAU / 8.0)
			pool.fire_projectile(player.global_position + direction * 64.0, direction, 1, "qa_no_collision_target")
		peak_active_projectiles = max(peak_active_projectiles, int(pool.active_count))
	var memory_after := _memory_static_bytes()
	var node_count_after := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	_check(process_samples.size() == SAMPLE_FRAMES and physics_samples.size() == SAMPLE_FRAMES, "performance sample contains all requested frame waits", "%d process / %d physics" % [process_samples.size(), physics_samples.size()])
	_check(_all_finite_positive(process_samples) and _all_finite_positive(physics_samples), "frame wait samples are finite and positive", "process and physics cadence")
	_check(process_monitor_samples.size() == SAMPLE_FRAMES and physics_monitor_samples.size() == SAMPLE_FRAMES and _all_finite_nonnegative(process_monitor_samples) and _all_finite_nonnegative(physics_monitor_samples), "Godot processing-time monitor samples are finite", "TIME_PROCESS and TIME_PHYSICS_PROCESS")
	_check(draw_call_samples.size() == SAMPLE_FRAMES and rendered_object_samples.size() == SAMPLE_FRAMES and primitive_samples.size() == SAMPLE_FRAMES, "renderer monitor sample contains every frame", "draw calls, rendered objects, and primitives")
	_check(_all_finite_nonnegative(draw_call_samples) and _all_finite_nonnegative(rendered_object_samples) and _all_finite_nonnegative(primitive_samples), "renderer monitor samples are finite", "RENDER_TOTAL_DRAW_CALLS_IN_FRAME and RENDER_TOTAL_PRIMITIVES_IN_FRAME")
	var rendered := not DisplayServer.get_name().to_lower().contains("headless")
	_check(rendered, "performance sample uses a rendered display server", DisplayServer.get_name())
	_check(draw_call_samples.max() > 0.0 and primitive_samples.max() > 0.0, "rendered frame reports nonzero draw work", "peak draw calls %.0f / primitives %.0f" % [draw_call_samples.max(), primitive_samples.max()])
	_check(peak_active_projectiles > 0, "performance sample exercises active projectiles", str(peak_active_projectiles))
	_check(int(pool.active_count) >= 0 and int(pool.active_count) <= int(pool.max_projectiles), "active projectiles stay within configured pool bounds", "%d / %d" % [int(pool.active_count), int(pool.max_projectiles)])
	var pool_total_before_smoke := int(pool.total_projectiles())
	var cap := int(pool.max_projectiles)
	for projectile in pool.pooled_projectiles:
		if projectile != null and is_instance_valid(projectile) and projectile.is_active:
			pool.release(projectile)
	var fired := 0
	for index in range(cap + 1):
		var angle := float(index) / float(max(1, cap)) * TAU
		if pool.fire_projectile(Vector2(100, 100), Vector2.RIGHT.rotated(angle), 1, "qa_no_collision_target"):
			fired += 1
	_check(fired == cap, "projectile pool rejects allocation beyond its configured limit", "%d accepted / %d maximum" % [fired, cap])
	_check(int(pool.active_count) == cap and int(pool.total_projectiles()) <= cap, "projectile pool active and allocated counts remain bounded", "%d active / %d allocated / %d maximum" % [int(pool.active_count), int(pool.total_projectiles()), cap])
	var active_after_capacity_smoke := int(pool.active_count)
	var allocated_after_capacity_smoke := int(pool.total_projectiles())
	for projectile in pool.pooled_projectiles:
		if projectile != null and is_instance_valid(projectile) and projectile.is_active:
			pool.release(projectile)
	var reuse_target := mini(24, cap)
	var reused := 0
	for index in range(reuse_target):
		if pool.fire_projectile(Vector2(120, 120), Vector2.RIGHT.rotated(float(index) * TAU / float(max(1, reuse_target))), 1, "qa_no_collision_target"):
			reused += 1
	var allocated_after_reuse := int(pool.total_projectiles())
	_check(reused == reuse_target and allocated_after_reuse == allocated_after_capacity_smoke, "projectile pool reuses allocated instances without growing", "%d reused; allocation %d -> %d" % [reused, allocated_after_capacity_smoke, allocated_after_reuse])
	var result := {
		"scene": "res://scenes/levels/wasteland/Wasteland.tscn",
		"route": "crystal_scar",
		"boss_active": not bosses.is_empty(),
		"scene_setup_elapsed_usec": scene_setup_usec,
		"warmup_frames": WARMUP_FRAMES,
		"warmup_elapsed_ms": float(warmup_usec) / 1000.0,
		"sample_frames": SAMPLE_FRAMES,
		"sample_frame_waits": {
			"process": _distribution(process_samples),
			"physics": _distribution(physics_samples)
		},
		"godot_processing_time_ms": {
			"process": _distribution(process_monitor_samples),
			"physics": _distribution(physics_monitor_samples)
		},
		"render_work_per_frame": {
			"draw_calls": _distribution(draw_call_samples),
			"rendered_objects": _distribution(rendered_object_samples),
			"primitives": _distribution(primitive_samples)
		},
		"interpretation": "Frame-wait distributions measure wall-clock cadence between signals. Godot processing-time monitors report engine-reported process and physics work. Renderer monitors report per-frame draw work. These values are not CPU utilization.",
		"environment": {
			"display_server": DisplayServer.get_name(),
			"rendered": rendered,
			"renderer": str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "unknown")),
			"processor": OS.get_processor_name(),
			"engine_version": Engine.get_version_info().get("string", "unknown")
		},
		"counts": {
			"enemy_nodes": enemies.size(),
			"boss_nodes": bosses.size(),
			"world_prop_nodes": props.size(),
			"pickup_nodes": pickups.size(),
			"node_count_before_sample": node_count_before,
			"node_count_after_sample": node_count_after,
			"static_memory_before_bytes": memory_before,
			"static_memory_after_bytes": memory_after,
			"static_memory_delta_bytes": memory_after - memory_before,
			"static_memory_peak_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC_MAX)),
			"active_projectiles_peak_during_sample": peak_active_projectiles,
			"projectiles_allocated_before_capacity_smoke": pool_total_before_smoke,
			"projectiles_active_after_capacity_smoke": active_after_capacity_smoke,
			"projectiles_allocated_after_capacity_smoke": int(pool.total_projectiles()),
			"projectile_reuse_count": reused,
			"projectiles_allocated_after_reuse": allocated_after_reuse,
			"projectile_limit": cap
		}
	}
	set_meta("performance_sample", result)
	world.queue_free()
	await get_tree().process_frame
	return

func _measure_frame_waits(frame_count: int) -> int:
	var start := Time.get_ticks_usec()
	for _index in range(frame_count):
		await get_tree().process_frame
	return Time.get_ticks_usec() - start

func _distribution(samples: Array[float]) -> Dictionary:
	if samples.is_empty():
		return {"count": 0, "mean_ms": 0.0, "p50_ms": 0.0, "p95_ms": 0.0, "max_ms": 0.0}
	var sorted: Array[float] = samples.duplicate()
	sorted.sort()
	var total := 0.0
	for value in sorted:
		total += value
	return {
		"count": sorted.size(),
		"mean_ms": total / float(sorted.size()),
		"p50_ms": sorted[_percentile_index(sorted.size(), 0.50)],
		"p95_ms": sorted[_percentile_index(sorted.size(), 0.95)],
		"max_ms": sorted[sorted.size() - 1]
	}

func _percentile_index(count: int, percentile: float) -> int:
	return clampi(roundi(float(count - 1) * percentile), 0, count - 1)

func _all_finite_positive(values: Array[float]) -> bool:
	for value in values:
		if value <= 0.0 or is_nan(value) or is_inf(value):
			return false
	return true

func _all_finite_nonnegative(values: Array[float]) -> bool:
	for value in values:
		if value < 0.0 or is_nan(value) or is_inf(value):
			return false
	return true

func _memory_static_bytes() -> int:
	return int(Performance.get_monitor(Performance.MEMORY_STATIC))

func _check(condition: bool, name: String, details: String) -> void:
	checks.append({"name": name, "passed": condition, "details": details})
	if condition:
		print("[PERF PASS] %s: %s" % [name, details])
	else:
		push_error("[PERF FAIL] %s: %s" % [name, details])

func _build_report(passed: bool) -> Dictionary:
	return {
		"schema_version": 1,
		"runner": "PerformanceRunner",
		"status": "passed" if passed else "failed",
		"checks": checks.duplicate(true),
		"methodology": "Record scene setup elapsed time, warm up a real seeded crystal_scar wasteland with 50 configured enemies and the boss active, sample 240 wall-clock frame-signal waits and Godot process/physics time monitors while projectiles are exercised, then smoke-test pool capacity and instance reuse. Timing is descriptive and has no machine-specific pass threshold.",
		"sample": get_meta("performance_sample", {})
	}

func _write_report(report: Dictionary) -> bool:
	var report_path := "user://qa_reports/performance_report.json"
	if not qa_output_dir.is_empty():
		if not DirAccess.dir_exists_absolute(qa_output_dir):
			var make_dir_error := DirAccess.make_dir_recursive_absolute(qa_output_dir)
			if make_dir_error != OK:
				return false
		report_path = qa_output_dir.path_join("performance_report.json")
	else:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://qa_reports"))
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return false
	print("[PERF] Report written: " + report_path)
	return true

func _read_user_arg(option: String, fallback: String) -> String:
	var args := OS.get_cmdline_user_args()
	for index in range(args.size() - 1):
		if args[index] == option:
			return String(args[index + 1])
	return fallback
