extends Node
## GameManager - Central game state manager

enum GameMode { MAIN_MENU, BUILDING, SIMULATING, PLAYING, PAUSED }
enum GameSpeed { PAUSED = 0, NORMAL = 1, FAST = 2, ULTRA = 4 }

var current_mode: GameMode = GameMode.MAIN_MENU
var current_speed: GameSpeed = GameSpeed.NORMAL
var is_paused: bool = false

var current_course: CourseData = null
var course_name: String = "New Course"
var money: int = 50000
var reputation: float = 50.0
var current_day: int = 1
var current_hour: float = 6.0

# Reference to terrain grid (set by main scene)
var terrain_grid: TerrainGrid = null

# Expose properties for backward compatibility
var course_data: CourseData:
	get:
		return current_course

var game_mode: GameMode:
	get:
		return current_mode

func get_game_speed_multiplier() -> float:
	if is_paused:
		return 0.0
	return float(current_speed)

const HOURS_PER_DAY: float = 24.0
const COURSE_OPEN_HOUR: float = 6.0
const COURSE_CLOSE_HOUR: float = 20.0

func _ready() -> void:
	print("GameManager initialized")

func _process(delta: float) -> void:
	if current_mode == GameMode.SIMULATING and not is_paused:
		_advance_time(delta)

func _advance_time(delta: float) -> void:
	var time_multiplier: float = current_speed * 60.0
	current_hour += (delta * time_multiplier) / 60.0
	if current_hour >= HOURS_PER_DAY:
		current_hour -= HOURS_PER_DAY
		current_day += 1
		EventBus.emit_signal("day_changed", current_day)

func set_mode(new_mode: GameMode) -> void:
	var old_mode = current_mode
	current_mode = new_mode
	EventBus.emit_signal("game_mode_changed", old_mode, new_mode)

func set_speed(new_speed: GameSpeed) -> void:
	current_speed = new_speed
	EventBus.emit_signal("game_speed_changed", new_speed)

func toggle_pause() -> void:
	is_paused = not is_paused
	EventBus.emit_signal("pause_toggled", is_paused)

func modify_money(amount: int) -> void:
	var old_money = money
	money += amount
	EventBus.emit_signal("money_changed", old_money, money)

func modify_reputation(amount: float) -> void:
	var old_rep = reputation
	reputation = clamp(reputation + amount, 0.0, 100.0)
	EventBus.emit_signal("reputation_changed", old_rep, reputation)

func new_game(course_name_input: String = "New Course") -> void:
	course_name = course_name_input
	money = 50000
	reputation = 50.0
	current_day = 1
	current_hour = COURSE_OPEN_HOUR
	current_course = CourseData.new()
	set_mode(GameMode.BUILDING)
	EventBus.emit_signal("new_game_started")

func is_course_open() -> bool:
	return current_hour >= COURSE_OPEN_HOUR and current_hour < COURSE_CLOSE_HOUR

func can_start_playing() -> bool:
	"""Check if the course is ready to start playing (has at least one complete hole)"""
	if not current_course:
		return false
	return current_course.holes.size() > 0

func start_simulation() -> bool:
	"""Attempt to start the simulation mode"""
	if not can_start_playing():
		EventBus.notify("Need at least one hole to start playing!", "error")
		return false

	set_mode(GameMode.SIMULATING)
	set_speed(GameSpeed.NORMAL)
	EventBus.notify("Golf course opened!", "info")
	return true

func stop_simulation() -> void:
	"""Stop the simulation and return to building mode"""
	set_mode(GameMode.BUILDING)
	set_speed(GameSpeed.PAUSED)
	EventBus.notify("Returned to building mode", "info")

func get_time_string() -> String:
	var hour_int = int(current_hour)
	var minute_int = int((current_hour - hour_int) * 60)
	var am_pm = "AM" if hour_int < 12 else "PM"
	var display_hour = hour_int % 12
	if display_hour == 0: display_hour = 12
	return "%d:%02d %s" % [display_hour, minute_int, am_pm]

class CourseData:
	var name: String = "New Course"
	var holes: Array = []
	var buildings: Array = []
	var terrain_data: Dictionary = {}
	var total_par: int = 0
	
	func add_hole(hole: HoleData) -> void:
		holes.append(hole)
		_recalculate_par()
	
	func _recalculate_par() -> void:
		total_par = 0
		for hole in holes:
			total_par += hole.par

class HoleData:
	var hole_number: int = 1
	var par: int = 4
	var tee_position: Vector2i = Vector2i.ZERO
	var green_position: Vector2i = Vector2i.ZERO
	var hole_position: Vector2i = Vector2i.ZERO  # Actual cup position on green
	var fairway_tiles: Array = []
	var hazard_tiles: Array = []
	var distance_yards: int = 0
