extends Node

const SAVE_PATH := "user://save_game.json"

var default_save_path := SAVE_PATH

func has_save(save_path := "") -> bool:
	return FileAccess.file_exists(_resolve_path(save_path))

func save_game(show_notice := true, save_path := "", save_spawn_point := true) -> bool:
	if GameState.death_pending or GameState.hp <= 0:
		if show_notice:
			GameState.notify("死亡回收中，暫時無法儲存進度。")
		return false
	var resolved_path := _resolve_path(save_path)
	var data := GameState.get_save_data()
	if save_spawn_point and String(data.get("scene", "")) != "main":
		data["spawn_point"] = "saved"
	var payload := JSON.stringify(data)
	var wrapped := {
		"checksum": payload.sha256_text(),
		"payload": Marshalls.utf8_to_base64(payload)
	}
	if not _ensure_parent_directory(resolved_path):
		if show_notice:
			GameState.notify("存檔失敗：無法建立本機存檔資料夾。")
		return false
	var temporary_path := resolved_path + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		if show_notice:
			GameState.notify("存檔失敗：無法寫入暫存檔。")
		return false
	file.store_string(JSON.stringify(wrapped, "\t"))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		if show_notice:
			GameState.notify("存檔失敗：寫入暫存檔時發生錯誤。")
		return false
	var absolute_temporary_path := ProjectSettings.globalize_path(temporary_path) if temporary_path.begins_with("user://") or temporary_path.begins_with("res://") else temporary_path
	var absolute_save_path := ProjectSettings.globalize_path(resolved_path) if resolved_path.begins_with("user://") or resolved_path.begins_with("res://") else resolved_path
	if DirAccess.rename_absolute(absolute_temporary_path, absolute_save_path) != OK:
		if show_notice:
			GameState.notify("存檔失敗：無法安全更新本機存檔。")
		return false
	if show_notice:
		GameState.notify("已儲存目前進度。")
	return true

func load_game(change_scene := true, show_notice := true, save_path := "") -> bool:
	var resolved_path := _resolve_path(save_path)
	if not FileAccess.file_exists(resolved_path):
		if show_notice:
			GameState.notify("目前沒有可讀取的存檔。")
		return false
	var file := FileAccess.open(resolved_path, FileAccess.READ)
	if file == null:
		if show_notice:
			GameState.notify("讀檔失敗：無法讀取本機存檔。")
		return false
	var wrapper_parser := JSON.new()
	if wrapper_parser.parse(file.get_as_text()) != OK:
		if show_notice:
			GameState.notify("讀檔失敗：存檔格式不正確。")
		return false
	var wrapped = wrapper_parser.data
	if typeof(wrapped) != TYPE_DICTIONARY or typeof(wrapped.get("payload")) != TYPE_STRING or typeof(wrapped.get("checksum")) != TYPE_STRING:
		if show_notice:
			GameState.notify("讀檔失敗：存檔格式不正確。")
		return false
	var encoded_payload := String(wrapped["payload"])
	var checksum := String(wrapped["checksum"])
	if not _is_base64_text(encoded_payload) or not _is_sha256_text(checksum):
		if show_notice:
			GameState.notify("讀檔失敗：存檔格式不正確。")
		return false
	var payload_text := Marshalls.base64_to_utf8(encoded_payload)
	if payload_text.is_empty() or payload_text.sha256_text() != checksum:
		if show_notice:
			GameState.notify("讀檔失敗：checksum 驗證未通過。")
		return false
	var payload_parser := JSON.new()
	if payload_parser.parse(payload_text) != OK or typeof(payload_parser.data) != TYPE_DICTIONARY or not GameState.load_save_data(payload_parser.data):
		if show_notice:
			GameState.notify("讀檔失敗：資料缺漏或版本不相容。")
		return false
	if show_notice:
		GameState.notify("已讀取存檔。")
	if change_scene:
		SceneRouter.change_to(GameState.current_scene_id, GameState.active_spawn_point, resolved_path)
	return true

func load_or_new(save_path := "") -> bool:
	if has_save(save_path):
		return load_game(true, true, save_path)
	GameState.reset_new_run(true)
	SceneRouter.change_to("village", "default", _resolve_path(save_path))
	return true

func _resolve_path(save_path: String) -> String:
	return default_save_path if save_path.is_empty() else save_path

func _ensure_parent_directory(path: String) -> bool:
	var absolute_path := ProjectSettings.globalize_path(path) if path.begins_with("user://") or path.begins_with("res://") else path
	var parent_directory := absolute_path.get_base_dir()
	if DirAccess.dir_exists_absolute(parent_directory):
		return true
	return DirAccess.make_dir_recursive_absolute(parent_directory) == OK

func _is_base64_text(value: String) -> bool:
	if value.is_empty() or value.length() % 4 != 0:
		return false
	var content_length := value.length()
	while content_length > 0 and value.unicode_at(content_length - 1) == 61:
		content_length -= 1
	if value.length() - content_length > 2:
		return false
	for index in range(content_length):
		var character := value.unicode_at(index)
		var valid_character := (character >= 65 and character <= 90) or (character >= 97 and character <= 122) or (character >= 48 and character <= 57) or character == 43 or character == 47
		if not valid_character:
			return false
	return true

func _is_sha256_text(value: String) -> bool:
	if value.length() != 64:
		return false
	for index in range(value.length()):
		var character := value.unicode_at(index)
		var is_digit := character >= 48 and character <= 57
		var is_lower_hex := character >= 97 and character <= 102
		if not is_digit and not is_lower_hex:
			return false
	return true
