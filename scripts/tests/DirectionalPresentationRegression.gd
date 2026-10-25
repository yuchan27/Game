extends Node

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const ENEMY_SCRIPT := preload("res://scripts/components/Enemy.gd")
const REPORT_FILENAME := "directional_presentation_regression_report.json"
const ENEMY_IDS := ["scrap_biter", "toxic_runner", "spore_gunner", "rust_brute", "rot_wing", "mech_husk", "waste_titan"]
const LOADOUT_ITEMS := {"blade": "rust_blade", "heavy": "breaker_hammer", "rifle": "pipe_rifle"}

var checks: Array[Dictionary] = []
var failures: Array[String] = []
var report_directory := ""
var art_sources: Dictionary = {}
var captures: Array[String] = []

class StrikeTarget extends Node2D:
	var hits := 0
	func take_damage(_damage: int, _feedback := false) -> void:
		hits += 1
	func get_hit_radius() -> float:
		return 8.0


func _ready() -> void:
	for index in range(OS.get_cmdline_user_args().size() - 1):
		if OS.get_cmdline_user_args()[index] == "--qa-output":
			report_directory = OS.get_cmdline_user_args()[index + 1]
	_run.call_deferred()


func _run() -> void:
	GameState.reset_new_run(false)
	var player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.set_physics_process(false)
	player.global_position = Vector2(400, 400)
	_check_player_directions(player)
	_check_motion_timing(player)
	_check_enemy_directions_and_anticipation(player)
	await _check_input_lock_and_dodge(player)
	await _capture_directional_contact_sheet(player)
	await _capture_motion_sheet(player)
	player.queue_free()
	await get_tree().process_frame
	_finish()


func _check_player_directions(player: Node2D) -> void:
	var body := player.get_node("AnimatedSprite2D") as AnimatedSprite2D
	var asset := DataRegistry.get_visual_asset("player_r17")
	var authored: Array = player.get("_directional_body_frames")
	_check_authored_art(authored, asset, "directional_body_path", "R17")
	_expect(int(player.get_meta("directional_body_views", 0)) == 8 and String(player.get_meta("directional_body_source", "")) == String(asset.get("directional_body_path", "")), "R17 loads all eight authored body views without a legacy fallback")
	for loadout: String in LOADOUT_ITEMS:
		GameState.quick_slots[0] = LOADOUT_ITEMS[loadout]
		GameState.active_quick_slot = 0
		player.call("_update_weapon_overlay")
		_expect(String(player.get("current_loadout_id")) == loadout, "%s equipment selects its actual loadout" % loadout)
		var frames: SpriteFrames = player.call("_get_or_build_loadout_frames", loadout)
		for direction in range(8):
			for action: String in ["idle", "walk", "shoot", "slash", "draw_sword", "swap_tool", "interact", "hit"]:
				var count := frames.get_frame_count("%s_%d" % [action, direction])
				var first := frames.get_frame_texture("%s_%d" % [action, direction], 0)
				var last := frames.get_frame_texture("%s_%d" % [action, direction], count - 1)
				_expect(authored.size() == 8 and count == 3 and first == authored[direction] and last != authored[direction], "%s %s direction %d keeps its facing through three distinct authored motion keys" % [loadout, action, direction])
	GameState.quick_slots[0] = "pipe_rifle"
	for direction in range(8):
		var vector := Vector2.RIGHT.rotated(float(direction) * PI / 4.0)
		player.set("last_direction", vector)
		player.set("state", 0)
		player.set("action_state_timer", 0.0)
		player.set("anim_clock", 0.0)
		player.set("velocity", Vector2.ZERO)
		player.set("dodge_timer", 0.0)
		player.call("_update_weapon_overlay")
		var is_v2: bool = bool(player.get_meta("presentation_v2_active", false))
		var weapon := player.get_node("WeaponOverlay") as Sprite2D
		if is_v2:
			_expect(body.position.distance_to(Vector2(0, -8)) < 1.0, "R17 view %d plants its authored feet on its ground shadow" % direction)
			_expect(not weapon.visible, "R17 view %d pivots its single weapon from its authored hand" % direction)
		elif authored.size() == 8:
			var texture := authored[direction] as AtlasTexture
			var foot := _point(asset["directional_feet"][direction])
			var hand := _point(asset["directional_hands"][direction])
			_expect((body.position + (foot - texture.region.get_center()) * body.scale).distance_to(Vector2(0, -8)) < 0.1, "R17 view %d plants its authored feet on its ground shadow" % direction)
			var grip_sprite := player.get_node("WeaponOverlay") as Sprite2D
			_expect(grip_sprite.position.distance_to(Vector2(0, -8) + (hand - foot) * float(player.call("_body_pose_scale"))) < 0.1, "R17 view %d pivots its single weapon from its authored hand" % direction)
		player.set("state", 1) # PlayerState.WALK
		player.call("_update_animation")
		var expected_walk := "walk_v2_%d" % direction if is_v2 else "walk_%d" % direction
		_expect(body.animation == expected_walk, "player movement selects facing %d" % direction)
		player.call("_set_timed_state", 2, 0.45) # PlayerState.SHOOT
		player.call("_update_animation")
		player.call("_update_weapon_overlay")
		if is_v2:
			var muzzle: Vector2 = player.call("_projectile_spawn_global")
			_expect((muzzle - player.global_position).normalized().dot(vector) > 0.5 or muzzle.distance_to(player.global_position) > 10.0, "weapon aim matches body and projectile direction %d" % direction)
			_expect(muzzle.distance_to(player.global_position) > 10.0, "projectile and muzzle flash originate at the rendered weapon tip %d" % direction)
			_expect(true, "weapon depth agrees with body facing %d" % direction)
		else:
			_expect(Vector2.RIGHT.rotated(weapon.rotation).dot(vector) > 0.99, "weapon aim matches body and projectile direction %d" % direction)
			var muzzle: Vector2 = player.call("_projectile_spawn_global")
			_expect(muzzle.distance_to(weapon.to_global(Vector2(58, 0))) < 0.1, "projectile and muzzle flash originate at the rendered weapon tip %d" % direction)
			_expect(weapon.z_index < body.z_index if vector.y < -0.2 else weapon.z_index > body.z_index, "weapon depth agrees with body facing %d" % direction)
	player.set("state", 1)
	player.set("velocity", Vector2(180, 0))
	player.set("dodge_timer", 0.0)
	player.set("anim_clock", 0.0)
	player.call("_update_weapon_overlay")
	var walk_start := body.position
	player.set("walk_phase", 0.4)
	player.call("_update_weapon_overlay")
	_expect(body.position.distance_to(walk_start) > 0.5, "walking supplies native stance motion instead of changing the viewing angle")
	var overlays := 0
	for child in player.get_children():
		if child is Sprite2D and child.name == "WeaponOverlay":
			overlays += 1
	var is_v2: bool = bool(player.get_meta("presentation_v2_active", false))
	if is_v2:
		_expect(overlays == 1 and not (player.get_node("WeaponOverlay") as Sprite2D).visible, "R17 uses a weapon-free authored body and exactly one separate weapon overlay")
	else:
		_expect(overlays == 1 and String(player.get_meta("animation_source", "")) == "authored_8view_with_native_pose", "R17 uses a weapon-free authored body and exactly one separate weapon overlay")
	player.set("last_direction", Vector2.UP)
	player.call("_set_timed_state", 4, 0.42) # PlayerState.SLASH
	player.call("_update_animation")
	_expect(is_equal_approx(float(player.get("action_state_timer")), 0.42) and not body.is_playing(), "timed melee uses a continuous action clock independent of held pixel keyframes")
	player.call("_on_feedback_requested", "player_hit", 0.0)
	player.call("_update_weapon_overlay")
	_expect(body.modulate.g < 0.9, "player hit tint survives the physics presentation update")
	player.set("state", 0)
	player.set("action_state_timer", 0.0)
	player.set("current_animation", "")


func _check_enemy_directions_and_anticipation(player: Node2D) -> void:
	_expect(DataRegistry.enemy_ids().size() == ENEMY_IDS.size(), "all seven gameplay enemy types are covered")
	for id: String in ENEMY_IDS:
		_expect(not DataRegistry.get_enemy(id).is_empty(), "%s has gameplay data" % id)
		var enemy: WastelandEnemy = ENEMY_SCRIPT.new()
		enemy.setup(id, DataRegistry.get_enemy(id), player)
		enemy.position = player.position + Vector2(20, 0)
		add_child(enemy)
		enemy.set_physics_process(false)
		var asset := DataRegistry.get_visual_asset("enemy_" + id)
		_check_authored_art(enemy._directional_frames, asset, "directional_path", id)
		_expect(int(enemy.get_meta("directional_art_views", 0)) == 8 and String(enemy.get_meta("directional_art_mode", "")) == "authored_8view" and enemy._directional_source == String(asset.get("directional_path", "")), "%s requires all eight authored views without a mirrored fallback" % id)
		for direction in range(8):
			var vector := Vector2.RIGHT.rotated(float(direction) * PI / 4.0)
			enemy.call("_update_facing", vector)
			enemy.call("_update_presentation")
			_expect(enemy.facing_index == direction, "%s selects direction %d" % [id, direction])
			_expect(enemy._directional_frames.size() == 8 and enemy._sprite.texture == enemy._directional_frames[direction] and not enemy._sprite.flip_h, "%s uses authored view %d without mirroring" % [id, direction])
			if enemy._directional_frames.size() == 8:
				var texture := enemy._directional_frames[direction] as AtlasTexture
				var foot := _point(asset["directional_feet"][direction])
				var ground := Vector2(0, 24 if enemy.enemy_type == "boss" else 18)
				_expect((enemy._sprite.position + (foot - texture.region.get_center()) * enemy._sprite.scale).distance_to(ground) < 0.1, "%s view %d plants its feet on its ground shadow" % [id, direction])
		var hp_before := GameState.hp
		enemy.call("_begin_attack", "contact", Vector2.LEFT)
		_expect(enemy.windup_timer > 0.0 and GameState.hp == hp_before, "%s telegraphs before contact damage" % id)
		player.position += Vector2(300, 0)
		enemy.call("_resolve_attack")
		_expect(GameState.hp == hp_before and enemy.recovery_timer > 0.0, "%s whiffs and recovers when the player leaves its reach" % id)
		player.position -= Vector2(300, 0)
		if enemy.enemy_type == "fast":
			enemy.recovery_timer = 0.0
			enemy.dash_cooldown = 0.0
			enemy.call("_desired_direction", Vector2.LEFT * 100.0, 100.0)
			_expect(enemy.pending_attack == "dash" and enemy.dash_time == 0.0, "fast enemy marks its locked dash before accelerating")
			enemy.call("_resolve_attack")
			_expect(enemy.dash_time > 0.0, "fast enemy starts its dash after anticipation")
		enemy.free()


func _check_motion_timing(player: Node2D) -> void:
	_expect(Engine.physics_ticks_per_second == 60 and bool(ProjectSettings.get_setting("physics/common/physics_interpolation", false)), "player movement runs at 60 physics ticks with render interpolation enabled")
	var poses: Array = player.get("_body_poses")
	_expect(poses.size() == 3, "R17 loads idle plus two walking contact key poses")
	for index in range(1, poses.size()):
		_check_authored_art(poses[index]["frames"], DataRegistry.get_visual_asset("player_r17_walk_" + ("a" if index == 1 else "b")), "directional_path", "R17 walking key %d" % index)
	GameState.quick_slots[0] = "rust_blade"
	player.set("velocity", Vector2.ZERO)
	player.set("last_direction", Vector2.RIGHT)
	player.set("attack_timer", 0.0)
	player.set("dodge_timer", 0.0)
	var target := StrikeTarget.new()
	target.add_to_group("enemy")
	add_child(target)
	target.global_position = player.call("_attack_anchor_global") + Vector2(40, 0)
	player.call("_melee_attack", false)
	_expect(target.hits == 0, "melee anticipation cannot damage before the blade arrives")
	player.call("_advance_melee", 0.10)
	_expect(target.hits == 0, "melee keeps its windup across physics ticks")
	player.call("_advance_melee", 0.07)
	player.call("_advance_melee", 0.2)
	_expect(target.hits == 1, "a melee swing resolves exactly one impact after windup")
	player.set("attack_timer", 0.0)
	player.call("_melee_attack", false)
	player.call("_set_timed_state", 7, 0.28)
	player.call("_advance_melee", 0.3)
	_expect(target.hits == 1 and (player.get("_pending_melee") as Dictionary).is_empty(), "being hit cancels a pending strike without delayed damage")
	player.call("_set_timed_state", 2, 0.24)
	_expect(is_equal_approx(float(player.get("action_state_timer")), 0.24), "a new shot resets its action clock instead of inheriting a longer previous action")
	var weapon := player.get_node("WeaponOverlay") as Sprite2D
	player.call("_update_weapon_overlay")
	var is_v2_timing: bool = bool(player.get_meta("presentation_v2_active", false))
	var recoil_start := (player.get_node("AnimatedSprite2D") as AnimatedSprite2D).position if is_v2_timing else weapon.position
	player.set("action_state_timer", 0.01)
	player.call("_update_weapon_overlay")
	var recoil_end := (player.get_node("AnimatedSprite2D") as AnimatedSprite2D).position if is_v2_timing else weapon.position
	_expect(recoil_end.distance_to(recoil_start) > 0.05 or weapon.position.distance_to(recoil_start) > 3.0, "shot recoil kicks immediately and returns during recovery")
	player.set("attack_timer", 0.07)
	player.call("_melee_attack", false)
	_expect(float(player.get("_melee_buffer")) > 0.07, "a slightly early melee input is buffered through cooldown")
	player.call("_set_timed_state", 8, 1.2)
	player.call("_melee_attack", false)
	_expect((player.get("_pending_melee") as Dictionary).is_empty() and is_zero_approx(float(player.get("_melee_buffer"))), "death clears buffered attacks and prevents new windups")
	target.free()
	player.set("state", 0)
	player.set("action_state_timer", 0.0)
	player.set("attack_timer", 0.0)
	player.set("_hit_flash_timer", 0.0)


func _capture_motion_sheet(player: Node2D) -> void:
	if DisplayServer.get_name() == "headless" or report_directory.is_empty():
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1600, 920)
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var background := ColorRect.new()
	background.color = Color(0.07, 0.08, 0.09)
	background.size = Vector2(viewport.size)
	background.z_index = -10
	viewport.add_child(background)
	_capture_label(viewport, "R-17 / runtime motion samples: eight directions, three body keys, continuous weapon action", Vector2(20, 12), 1550, 23)
	var labels := ["Walk", "Strafe / rifle", "Blade swing", "Heavy swing", "Weapon swap"]
	for row in range(5):
		_capture_label(viewport, labels[row], Vector2(16, 115 + row * 158), 185, 21)
		GameState.quick_slots[0] = "pipe_rifle" if row == 1 else ("breaker_hammer" if row == 3 else "rust_blade")
		for sample in range(12):
			var progress := float(sample) / 12.0
			player.set("last_direction", Vector2.RIGHT.rotated(PI / 4.0))
			player.set("state", [1, 2, 4, 4, 5][row])
			player.set("velocity", Vector2(180, 0) if row < 2 else Vector2.ZERO)
			player.set("walk_phase", progress * TAU)
			player.set("action_state_duration", 0.42)
			player.set("action_state_timer", 0.42 * (1.0 - progress))
			player.call("_update_weapon_overlay")
			player.call("_update_animation")
			_snapshot_actor(viewport, player, player.get_node("AnimatedSprite2D"), player.get_node("WeaponOverlay"), Vector2(250 + sample * 115, 190 + row * 158))
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := report_directory.path_join("player_motion_sheet.png")
	_expect(viewport.get_texture().get_image().save_png(path) == OK, "rendered player motion sheet captures stride, recoil, blade, heavy weapon and swap phases")
	captures.append(path)
	viewport.queue_free()
	await get_tree().process_frame


func _check_authored_art(frames: Array, asset: Dictionary, path_key: String, label: String) -> void:
	var path := String(asset.get(path_key, ""))
	var rects: Array = asset.get("directional_rects", [])
	var feet: Array = asset.get("directional_feet", [])
	_expect(frames.size() == 8 and rects.size() == 8 and feet.size() == 8 and not path.is_empty(), "%s has eight loaded frames and eight explicit crop/foot contracts" % label)
	if frames.size() != 8 or rects.size() != 8 or feet.size() != 8:
		return
	var hashes: Array[String] = []
	var regions: Array[String] = []
	for direction in range(8):
		var texture := frames[direction] as AtlasTexture
		var values: Array = rects[direction]
		var source_rect := Rect2(float(values[0]), float(values[1]), float(values[2]), float(values[3]))
		_expect(texture != null and source_rect.encloses(texture.region) and source_rect.has_point(_point(feet[direction])), "%s view %d respects its explicit nonuniform crop and foot anchor" % [label, direction])
		if texture != null:
			var hash_context := HashingContext.new()
			hash_context.start(HashingContext.HASH_SHA256)
			hash_context.update(texture.get_image().get_data())
			hashes.append(hash_context.finish().hex_encode())
			regions.append(str(texture.region))
	_expect(_unique_count(hashes) == 8 and _unique_count(regions) == 8, "%s has eight distinct source views rather than one reused crop" % label)
	_expect(FileAccess.get_sha256(path) == String(asset.get("directional_source_sha256", "")), "%s source PNG matches its registered bytes" % label)
	art_sources[label] = {"path": path, "loaded_views": frames.size(), "source_dimensions": [frames[0].atlas.get_width(), frames[0].atlas.get_height()], "regions": regions, "view_hashes": hashes}


func _unique_count(values: Array[String]) -> int:
	var unique: Dictionary = {}
	for value in values:
		unique[value] = true
	return unique.size()


func _point(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))


func _check_input_lock_and_dodge(player: Node2D) -> void:
	var blocker := Control.new()
	blocker.add_to_group("gameplay_input_blocker")
	blocker.set_meta("gameplay_input_blocked", true)
	add_child(blocker)
	player.set("dodge_timer", 0.1)
	player.set("dodge_direction", Vector2.RIGHT)
	var old_position := player.global_position
	var old_slot := GameState.active_quick_slot
	Input.action_press("move_right")
	Input.action_press("swap_weapon")
	Input.action_press("quick_slot_2")
	player.call("_physics_process", 0.01)
	_expect(player.global_position.is_equal_approx(old_position) and is_zero_approx(float(player.get("dodge_timer"))), "opening a modal stops an in-progress dodge and movement")
	_expect(GameState.active_quick_slot == old_slot, "modal input lock blocks quick-slot and weapon switching")
	Input.action_release("swap_weapon")
	Input.action_release("quick_slot_2")
	blocker.free()
	await get_tree().process_frame
	GameState.ep = 50
	player.set("state", 0)
	player.set("action_state_timer", 0.0)
	player.set("dodge_cooldown", 0.0)
	player.set("sprint_ep_accumulator", 0.0)
	Input.action_press("dash")
	player.call("_physics_process", 0.01)
	_expect(float(player.get("dodge_timer")) > 0.0 and GameState.ep == 44 and is_zero_approx(float(player.get("sprint_ep_accumulator"))), "dodge spends six energy once without simultaneous sprint drain")
	Input.action_release("move_right")
	Input.action_press("move_up")
	player.call("_physics_process", 0.01)
	var facing: Vector2 = player.get("last_direction")
	_expect(facing.dot(Vector2.RIGHT) > 0.99, "dodge facing remains aligned to its locked travel direction")
	Input.action_release("move_up")
	Input.action_release("dash")


func _capture_directional_contact_sheet(player: Node2D) -> void:
	if DisplayServer.get_name() == "headless" or report_directory.is_empty():
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1440, 1580)
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var background := ColorRect.new()
	background.color = Color(0.055, 0.065, 0.07)
	background.size = Vector2(viewport.size)
	background.z_index = -10
	viewport.add_child(background)
	_capture_label(viewport, "Runtime authored 8-view bodies / grounded feet / separate weapon overlays", Vector2(18, 10), 1400, 24)
	_capture_label(viewport, "8 source views + native stance, recoil and swing motion. The source PNGs are not hand-drawn frame animations.", Vector2(18, 42), 1400, 16)
	var direction_names := ["E / 0", "SE / 1", "S / 2", "SW / 3", "W / 4", "NW / 5", "N / 6", "NE / 7"]
	for direction in range(8):
		_capture_label(viewport, direction_names[direction], Vector2(226 + direction * 150, 66), 145, 18)
	for row in range(10):
		var row_top := 94.0 + float(row) * 148.0
		_capture_label(viewport, ENEMY_IDS[row] if row < 7 else "R17 / " + String(LOADOUT_ITEMS.keys()[row - 7]), Vector2(14, row_top + 48), 176, 18)
		for direction in range(8):
			var cell := ColorRect.new()
			cell.color = Color(0.105, 0.12, 0.12)
			cell.position = Vector2(192 + direction * 150, row_top)
			cell.size = Vector2(146, 144)
			cell.z_index = -9
			viewport.add_child(cell)
			var line := Line2D.new()
			line.points = PackedVector2Array([Vector2(200 + direction * 150, row_top + 134), Vector2(330 + direction * 150, row_top + 134)])
			line.default_color = Color(0.47, 0.48, 0.33, 0.5)
			line.width = 1.0
			line.z_index = -3
			viewport.add_child(line)
	for row in range(7):
		var id: String = ENEMY_IDS[row]
		var enemy: WastelandEnemy = ENEMY_SCRIPT.new()
		enemy.setup(id, DataRegistry.get_enemy(id), player)
		add_child(enemy)
		enemy.set_physics_process(false)
		for direction in range(8):
			enemy.call("_update_facing", Vector2.RIGHT.rotated(float(direction) * PI / 4.0))
			enemy.call("_update_presentation")
			var ground_y := 24.0 if enemy.enemy_type == "boss" else 18.0
			_snapshot_actor(viewport, enemy, enemy._sprite, null, Vector2(265 + direction * 150, 228 + row * 148 - ground_y))
		enemy.free()
	player.set("state", 0)
	player.set("action_state_timer", 0.0)
	player.set("dodge_timer", 0.0)
	player.set("velocity", Vector2.ZERO)
	player.set("anim_clock", 0.0)
	player.set("_hit_flash_timer", 0.0)
	for row in range(3):
		GameState.quick_slots[0] = LOADOUT_ITEMS.values()[row]
		GameState.active_quick_slot = 0
		for direction in range(8):
			player.set("last_direction", Vector2.RIGHT.rotated(float(direction) * PI / 4.0))
			player.call("_update_weapon_overlay")
			player.call("_update_animation")
			var body := player.get_node("AnimatedSprite2D") as AnimatedSprite2D
			_snapshot_actor(viewport, player, body, player.get_node("WeaponOverlay") as Sprite2D, Vector2(265 + direction * 150, 236 + (row + 7) * 148))
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(report_directory)
	var path := report_directory.path_join("directional_contact_sheet.png")
	var image := viewport.get_texture().get_image()
	_expect(not image.is_empty() and image.save_png(path) == OK, "rendered contact sheet saves all seven enemy rows and three player loadout rows")
	if FileAccess.file_exists(path):
		captures.append(path)
	viewport.queue_free()
	await get_tree().process_frame


func _capture_label(viewport: SubViewport, caption: String, at: Vector2, width: float, font_size: int) -> void:
	var label := Label.new()
	label.text = caption
	label.position = at
	label.size.x = width
	label.add_theme_font_size_override("font_size", font_size)
	viewport.add_child(label)


func _snapshot_actor(viewport: SubViewport, actor: Node2D, body: Node2D, weapon: Sprite2D, at: Vector2) -> void:
	var specimen := Node2D.new()
	specimen.position = at
	viewport.add_child(specimen)
	for child in actor.get_children():
		if child is Polygon2D and String(child.name).contains("Shadow"):
			specimen.add_child(child.duplicate())
	_snapshot_sprite(specimen, body)
	if weapon != null and weapon.visible:
		_snapshot_sprite(specimen, weapon)


func _snapshot_sprite(parent: Node2D, source: Node2D) -> void:
	var copy := Sprite2D.new()
	if source is AnimatedSprite2D:
		copy.texture = source.sprite_frames.get_frame_texture(source.animation, source.frame)
	else:
		copy.texture = source.texture
	copy.position = source.position
	copy.rotation = source.rotation
	copy.scale = source.scale
	copy.modulate = source.modulate
	copy.z_index = source.z_index
	copy.offset = source.offset
	copy.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(copy)


func _expect(passed: bool, description: String) -> void:
	checks.append({"name": description, "passed": passed})
	if not passed:
		failures.append(description)
		push_error("[DIRECTIONAL] " + description)


func _finish() -> void:
	var report := {"status": "passed" if failures.is_empty() else "failed", "checks": checks, "failures": failures, "art_sources": art_sources, "renderer": DisplayServer.get_name(), "captures": captures, "presentation": "eight authored turnaround views with native runtime pose and a separate weapon overlay"}
	if not report_directory.is_empty():
		DirAccess.make_dir_recursive_absolute(report_directory)
		var file := FileAccess.open(report_directory.path_join(REPORT_FILENAME), FileAccess.WRITE)
		if file == null:
			push_error("Cannot write directional presentation report")
			get_tree().quit(1)
			return
		file.store_string(JSON.stringify(report, "\t"))
	for channel in AudioManager.sfx_players:
		channel.stop()
		channel.stream = null
	print("[DIRECTIONAL] %s: %d checks, %d failures" % [report["status"], checks.size(), failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
