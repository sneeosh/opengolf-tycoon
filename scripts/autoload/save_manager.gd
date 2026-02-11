extends Node
## SaveManager - Handles saving and loading game data
##
## SAVE STATE CHECKLIST - Update when adding new saveable content:
## - [x] Game state (money, reputation, day, hour, green_fee)
## - [x] Terrain tiles and elevation
## - [x] Entities (trees, buildings, rocks) via EntityLayer
## - [x] Holes (positions, par, open/closed state)
## - [x] Wind (direction, speed)
## - [ ] Golfers - NOT persisted; cleared on load, respawn naturally when simulation resumes
##       (See DEVELOPMENT_MILESTONES.md for future full mid-action state persistence)
## - [ ] TODO: Add new entity types here as they're implemented
##
## When adding a new saveable entity:
## 1. Add serialize/deserialize methods to the entity class
## 2. Add serialization call in _build_save_data()
## 3. Add deserialization call in _apply_save_data()
## 4. Update this checklist

const SAVE_DIR: String = "user://saves/"
const SETTINGS_PATH: String = "user://settings.cfg"
const SAVE_VERSION: int = 2

## Scene-tree references (set by Main in _ready())
var terrain_grid: TerrainGrid = null
var entity_layer: EntityLayer = null
var golfer_manager: Node = null
var ball_manager: Node = null

func _ready() -> void:
	_ensure_save_directory()
	EventBus.day_changed.connect(_on_day_changed)
	print("SaveManager initialized")

func _ensure_save_directory() -> void:
	var dir = DirAccess.open("user://")
	if dir and not dir.dir_exists("saves"):
		dir.make_dir("saves")

func set_references(grid: TerrainGrid, entities: EntityLayer, golfers: Node = null, balls: Node = null) -> void:
	terrain_grid = grid
	entity_layer = entities
	golfer_manager = golfers
	ball_manager = balls

func save_game(save_name: String = "") -> bool:
	if save_name.is_empty():
		save_name = "autosave"

	var save_path = SAVE_DIR + save_name + ".save"
	var save_data: Dictionary = _build_save_data()

	var json_string = JSON.stringify(save_data, "\t")
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
		EventBus.save_completed.emit(true)
		EventBus.notify("Game saved: " + save_name, "success")
		return true

	EventBus.save_completed.emit(false)
	EventBus.notify("Failed to save game!", "error")
	return false

func load_game(save_name: String) -> bool:
	var save_path = SAVE_DIR + save_name + ".save"

	if not FileAccess.file_exists(save_path):
		EventBus.load_completed.emit(false)
		EventBus.notify("Save file not found!", "error")
		return false

	var file = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		EventBus.load_completed.emit(false)
		return false

	var json_string = file.get_as_text()
	file.close()

	var save_data = JSON.parse_string(json_string)
	if save_data == null or not save_data is Dictionary:
		EventBus.load_completed.emit(false)
		EventBus.notify("Corrupt save file!", "error")
		return false

	_apply_save_data(save_data)
	EventBus.load_completed.emit(true)
	EventBus.notify("Game loaded: " + save_name, "success")
	return true

func delete_save(save_name: String) -> bool:
	var save_path = SAVE_DIR + save_name + ".save"
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
		return true
	return false

func get_save_list() -> Array[Dictionary]:
	"""Returns array of {name, timestamp, course_name, day} for each save."""
	var saves: Array[Dictionary] = []
	var dir = DirAccess.open(SAVE_DIR)
	if not dir:
		return saves

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".save"):
			var name = file_name.replace(".save", "")
			var metadata = _read_save_metadata(SAVE_DIR + file_name)
			metadata["name"] = name
			saves.append(metadata)
		file_name = dir.get_next()
	dir.list_dir_end()

	# Sort by timestamp descending (newest first)
	saves.sort_custom(func(a, b): return a.get("timestamp", "") > b.get("timestamp", ""))
	return saves

## Build the full save data dictionary
func _build_save_data() -> Dictionary:
	var data: Dictionary = {
		"version": SAVE_VERSION,
		"timestamp": Time.get_datetime_string_from_system(),
		"game_state": {
			"course_name": GameManager.course_name,
			"money": GameManager.money,
			"reputation": GameManager.reputation,
			"current_day": GameManager.current_day,
			"current_hour": GameManager.current_hour,
			"green_fee": GameManager.green_fee,
		},
	}

	# Terrain
	if terrain_grid:
		data["terrain"] = terrain_grid.serialize()
		data["elevation"] = terrain_grid.serialize_elevation()

	# Entities
	if entity_layer:
		data["entities"] = entity_layer.serialize()

	# Holes
	if GameManager.current_course:
		data["holes"] = _serialize_holes(GameManager.current_course.holes)

	# Wind
	if GameManager.wind_system:
		data["wind"] = {
			"direction": GameManager.wind_system.wind_direction,
			"speed": GameManager.wind_system.wind_speed,
		}

	# Weather
	if GameManager.weather_system:
		data["weather"] = {
			"type": GameManager.weather_system.weather_type,
			"intensity": GameManager.weather_system.intensity,
		}

	# Tournament
	if GameManager.tournament_manager:
		data["tournament"] = GameManager.tournament_manager.get_save_data()

	# Golfers: NOT saved - they are cleared on load and respawn naturally when
	# simulation resumes. Full mid-action state persistence is a future milestone.

	# Course Records
	data["course_records"] = CourseRecords.serialize_records(GameManager.course_records)

	return data

## Serialize hole data to plain dictionaries
func _serialize_holes(holes: Array) -> Array:
	var result: Array = []
	for hole in holes:
		result.append({
			"hole_number": hole.hole_number,
			"par": hole.par,
			"tee_position": {"x": hole.tee_position.x, "y": hole.tee_position.y},
			"green_position": {"x": hole.green_position.x, "y": hole.green_position.y},
			"hole_position": {"x": hole.hole_position.x, "y": hole.hole_position.y},
			"distance_yards": hole.distance_yards,
			"is_open": hole.is_open,
			"difficulty_rating": hole.difficulty_rating,
		})
	return result

## Apply loaded save data
func _apply_save_data(data: Dictionary) -> void:
	# IMPORTANT: Set to BUILDING mode FIRST to prevent golfer_manager from
	# processing golfers while we're still loading
	GameManager.set_mode(GameManager.GameMode.BUILDING)

	var version = data.get("version", 1)

	# Game state (with fallbacks for older save versions)
	var game = data.get("game_state", data)  # v1 had flat structure
	GameManager.course_name = game.get("course_name", "Loaded Course")
	GameManager.money = int(game.get("money", 50000))
	GameManager.reputation = float(game.get("reputation", 50.0))
	GameManager.current_day = int(game.get("current_day", 1))
	GameManager.current_hour = float(game.get("current_hour", 6.0))
	GameManager.green_fee = int(game.get("green_fee", 30))

	# Terrain
	if terrain_grid and data.has("terrain"):
		terrain_grid.deserialize(data["terrain"])
	if terrain_grid and data.has("elevation"):
		terrain_grid.deserialize_elevation(data["elevation"])
	if terrain_grid:
		terrain_grid.queue_redraw()

	# Entities
	if entity_layer and data.has("entities"):
		entity_layer.deserialize(data["entities"])

	# Holes
	if data.has("holes"):
		_deserialize_holes(data["holes"])

	# Wind
	if GameManager.wind_system and data.has("wind"):
		var wind_data = data["wind"]
		GameManager.wind_system.wind_direction = float(wind_data.get("direction", 0.0))
		GameManager.wind_system.wind_speed = float(wind_data.get("speed", 5.0))

	# Weather
	if GameManager.weather_system and data.has("weather"):
		var weather_data = data["weather"]
		GameManager.weather_system.weather_type = int(weather_data.get("type", 0))
		GameManager.weather_system.intensity = float(weather_data.get("intensity", 0.0))
		# Emit signal to update UI and visuals
		EventBus.weather_changed.emit(GameManager.weather_system.weather_type, GameManager.weather_system.intensity)

	# Tournament
	if GameManager.tournament_manager and data.has("tournament"):
		GameManager.tournament_manager.load_save_data(data["tournament"])

	# Course Records
	if data.has("course_records"):
		GameManager.course_records = CourseRecords.deserialize_records(data["course_records"])
	else:
		GameManager.course_records = CourseRecords.create_empty_records()

	# Golfers: Always clear on load - they will respawn naturally when the user
	# switches to simulation mode. This avoids complex mid-action state restoration.
	if golfer_manager and golfer_manager.has_method("clear_all_golfers"):
		golfer_manager.clear_all_golfers()

	# Clear all balls as well - they'll be created fresh when golfers spawn
	if ball_manager and ball_manager.has_method("clear_all_balls"):
		ball_manager.clear_all_balls()

	EventBus.load_completed.emit(true)

## Deserialize holes into GameManager.current_course
func _deserialize_holes(holes_data: Array) -> void:
	if not GameManager.current_course:
		GameManager.current_course = GameManager.CourseData.new()
	GameManager.current_course.holes.clear()

	for h in holes_data:
		var hole = GameManager.HoleData.new()
		hole.hole_number = int(h.get("hole_number", 1))
		hole.par = int(h.get("par", 4))
		var tee = h.get("tee_position", {"x": 0, "y": 0})
		hole.tee_position = Vector2i(int(tee.get("x", 0)), int(tee.get("y", 0)))
		var green = h.get("green_position", {"x": 0, "y": 0})
		hole.green_position = Vector2i(int(green.get("x", 0)), int(green.get("y", 0)))
		var hp = h.get("hole_position", {"x": 0, "y": 0})
		hole.hole_position = Vector2i(int(hp.get("x", 0)), int(hp.get("y", 0)))
		hole.distance_yards = int(h.get("distance_yards", 0))
		hole.is_open = h.get("is_open", true)
		hole.difficulty_rating = float(h.get("difficulty_rating", 1.0))
		GameManager.current_course.holes.append(hole)

	GameManager.current_course._recalculate_par()

	# Emit hole_created signals so HoleManager rebuilds visualizations
	for hole in GameManager.current_course.holes:
		EventBus.hole_created.emit(hole.hole_number, hole.par, hole.distance_yards)

## Read only the metadata from a save file (for listing)
func _read_save_metadata(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return {"timestamp": "", "course_name": "Unknown", "day": 0}

	var json_string = file.get_as_text()
	file.close()

	var data = JSON.parse_string(json_string)
	if data == null or not data is Dictionary:
		return {"timestamp": "", "course_name": "Unknown", "day": 0}

	var game = data.get("game_state", data)
	return {
		"timestamp": data.get("timestamp", ""),
		"course_name": game.get("course_name", "Unknown"),
		"day": int(game.get("current_day", 0)),
	}

## Auto-save at end of each day
func _on_day_changed(_new_day: int) -> void:
	save_game("autosave")
