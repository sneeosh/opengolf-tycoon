extends Node
## SaveManager - Handles saving and loading game data

const SAVE_DIR: String = "user://saves/"
const SETTINGS_PATH: String = "user://settings.cfg"
const SAVE_VERSION: int = 1

func _ready() -> void:
	_ensure_save_directory()
	print("SaveManager initialized")

func _ensure_save_directory() -> void:
	var dir = DirAccess.open("user://")
	if dir and not dir.dir_exists("saves"):
		dir.make_dir("saves")

func save_game(save_name: String = "") -> bool:
	if save_name.is_empty():
		save_name = "autosave"
	
	var save_path = SAVE_DIR + save_name + ".save"
	var save_data: Dictionary = {
		"version": SAVE_VERSION,
		"timestamp": Time.get_datetime_string_from_system(),
		"course_name": GameManager.course_name,
		"money": GameManager.money,
		"reputation": GameManager.reputation,
		"current_day": GameManager.current_day,
		"current_hour": GameManager.current_hour,
	}
	
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_var(save_data)
		file.close()
		EventBus.emit_signal("save_completed", true)
		EventBus.notify("Game saved: " + save_name, "success")
		return true
	
	EventBus.emit_signal("save_completed", false)
	EventBus.notify("Failed to save game!", "error")
	return false

func load_game(save_name: String) -> bool:
	var save_path = SAVE_DIR + save_name + ".save"
	
	if not FileAccess.file_exists(save_path):
		EventBus.emit_signal("load_completed", false)
		EventBus.notify("Save file not found!", "error")
		return false
	
	var file = FileAccess.open(save_path, FileAccess.READ)
	if file:
		var save_data = file.get_var()
		file.close()
		_apply_save_data(save_data)
		EventBus.emit_signal("load_completed", true)
		EventBus.notify("Game loaded: " + save_name, "success")
		return true
	
	EventBus.emit_signal("load_completed", false)
	return false

func get_save_list() -> Array:
	var saves: Array = []
	var dir = DirAccess.open(SAVE_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".save"):
				saves.append(file_name.replace(".save", ""))
			file_name = dir.get_next()
		dir.list_dir_end()
	return saves

func _apply_save_data(data: Dictionary) -> void:
	GameManager.course_name = data.get("course_name", "Loaded Course")
	GameManager.money = data.get("money", 50000)
	GameManager.reputation = data.get("reputation", 50.0)
	GameManager.current_day = data.get("current_day", 1)
	GameManager.current_hour = data.get("current_hour", 6.0)
	GameManager.set_mode(GameManager.GameMode.BUILDING)
