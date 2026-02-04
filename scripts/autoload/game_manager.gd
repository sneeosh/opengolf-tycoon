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

# Green fee pricing
var green_fee: int = 30  # Default $30 per golfer
const MIN_GREEN_FEE: int = 10
const MAX_GREEN_FEE: int = 200

# Reference to terrain grid (set by main scene)
var terrain_grid: TerrainGrid = null

# Reference to wind system (set by main scene)
var wind_system: WindSystem = null

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

var _closing_announced: bool = false
var _end_of_day_triggered: bool = false

func _advance_time(delta: float) -> void:
	# 1 real minute = 1 game hour at NORMAL speed
	var time_multiplier: float = float(current_speed)
	var old_hour = current_hour
	current_hour += (delta * time_multiplier) / 60.0

	# Emit hour_changed for smooth time-dependent effects (day/night visual, etc.)
	EventBus.emit_signal("hour_changed", current_hour)

	# Update wind drift each game hour
	if wind_system and int(current_hour) != int(old_hour):
		wind_system.update_wind_drift(current_hour - COURSE_OPEN_HOUR)

	# Announce course closing 1 hour before close
	if not _closing_announced and current_hour >= COURSE_CLOSE_HOUR - 1.0:
		_closing_announced = true
		EventBus.emit_signal("course_closing")
		EventBus.notify("Course closing soon!", "info")

	# Trigger end of day when past closing time (golfer cleanup handled by GolferManager)
	if not _end_of_day_triggered and current_hour >= COURSE_CLOSE_HOUR:
		_end_of_day_triggered = true

	# Don't wrap day automatically — wait for advance_to_next_day() call
	# This allows the end-of-day summary to display before the new day starts
	if current_hour >= HOURS_PER_DAY:
		current_hour = HOURS_PER_DAY  # Clamp to prevent runaway

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

func set_green_fee(new_fee: int) -> void:
	var old_fee = green_fee
	green_fee = clamp(new_fee, MIN_GREEN_FEE, MAX_GREEN_FEE)
	EventBus.emit_signal("green_fee_changed", old_fee, green_fee)

func process_green_fee_payment(golfer_id: int, golfer_name: String) -> bool:
	"""Process a golfer's green fee payment and return success"""
	modify_money(green_fee)
	EventBus.log_transaction("%s paid green fee" % golfer_name, green_fee)
	EventBus.emit_signal("green_fee_paid", golfer_id, golfer_name, green_fee)
	return true

func new_game(course_name_input: String = "New Course") -> void:
	course_name = course_name_input
	money = 50000
	reputation = 50.0
	current_day = 1
	current_hour = COURSE_OPEN_HOUR
	green_fee = 30  # Reset to default
	_closing_announced = false
	_end_of_day_triggered = false
	current_course = CourseData.new()
	set_mode(GameMode.BUILDING)
	EventBus.emit_signal("new_game_started")

func is_course_open() -> bool:
	return current_hour >= COURSE_OPEN_HOUR and current_hour < COURSE_CLOSE_HOUR

func is_end_of_day_pending() -> bool:
	return _end_of_day_triggered

func request_end_of_day() -> void:
	"""Called when all golfers have left after closing. Emits end_of_day signal."""
	if not _end_of_day_triggered:
		return
	EventBus.emit_signal("end_of_day", current_day)

func advance_to_next_day() -> void:
	"""Advance to the next morning. Called after end-of-day processing is complete."""
	current_day += 1
	current_hour = COURSE_OPEN_HOUR
	_closing_announced = false
	_end_of_day_triggered = false
	EventBus.emit_signal("day_changed", current_day)
	if wind_system:
		wind_system.generate_daily_wind()
	EventBus.notify("Day %d — Course is open!" % current_day, "info")

func can_start_playing() -> bool:
	"""Check if the course is ready to start playing (has at least one open hole)"""
	if not current_course:
		return false
	return current_course.get_open_holes().size() > 0

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

	func get_open_holes() -> Array:
		var open: Array = []
		for hole in holes:
			if hole.is_open:
				open.append(hole)
		return open

	func toggle_hole_open(hole_number: int) -> bool:
		for hole in holes:
			if hole.hole_number == hole_number:
				hole.is_open = not hole.is_open
				EventBus.emit_signal("hole_toggled", hole_number, hole.is_open)
				return hole.is_open
		return false

class HoleData:
	var hole_number: int = 1
	var par: int = 4
	var tee_position: Vector2i = Vector2i.ZERO
	var green_position: Vector2i = Vector2i.ZERO
	var hole_position: Vector2i = Vector2i.ZERO  # Actual cup position on green
	var fairway_tiles: Array = []
	var hazard_tiles: Array = []
	var distance_yards: int = 0
	var is_open: bool = true  # Whether the hole is open for play
	var difficulty_rating: float = 1.0  # Hole difficulty (1.0-10.0)
