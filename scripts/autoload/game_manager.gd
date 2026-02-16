extends Node
## GameManager - Central game state manager

enum GameMode { MAIN_MENU, BUILDING, SIMULATING, PLAYING, PAUSED }
enum GameSpeed { PAUSED = 0, NORMAL = 1, FAST = 2, ULTRA = 4 }

var current_mode: GameMode = GameMode.MAIN_MENU
var current_speed: GameSpeed = GameSpeed.NORMAL
var is_paused: bool = false

var current_course: CourseData = null
var course_name: String = "New Course"
var current_theme: int = CourseTheme.Type.PARKLAND
var money: int = 50000
var reputation: float = 50.0
var current_day: int = 1
var current_hour: float = 6.0

# Reputation decay: courses must maintain quality to keep reputation
const REPUTATION_DAILY_DECAY: float = 0.5  # -0.5 rep/day (need steady golfer flow to maintain)

# Green fee pricing
var green_fee: int = 10  # Default $10/hole (auto-clamped by hole count)
const MIN_GREEN_FEE: int = 10
const MAX_GREEN_FEE: int = 200

# Bankruptcy threshold - spending blocked below this amount
const BANKRUPTCY_THRESHOLD: int = -1000

# Staff tier system
enum StaffTier { PART_TIME, FULL_TIME, PREMIUM }

const STAFF_TIER_DATA = {
	StaffTier.PART_TIME: {
		"name": "Part-Time Staff",
		"cost_per_hole": 5,
		"condition_modifier": 0.85,
		"satisfaction_modifier": 0.90,
		"description": "Basic maintenance, limited availability"
	},
	StaffTier.FULL_TIME: {
		"name": "Full-Time Staff",
		"cost_per_hole": 10,
		"condition_modifier": 1.0,
		"satisfaction_modifier": 1.0,
		"description": "Standard professional maintenance"
	},
	StaffTier.PREMIUM: {
		"name": "Premium Staff",
		"cost_per_hole": 20,
		"condition_modifier": 1.15,
		"satisfaction_modifier": 1.10,
		"description": "Expert greenskeepers, exceptional service"
	}
}

var current_staff_tier: int = StaffTier.FULL_TIME

# Reference to terrain grid (set by main scene)
var terrain_grid: TerrainGrid = null

# Reference to wind system (set by main scene)
var wind_system: WindSystem = null

# Reference to weather system (set by main scene)
var weather_system: WeatherSystem = null

# Reference to tournament manager (set by main scene)
var tournament_manager: TournamentManager = null

# Reference to entity layer for building queries (set by main scene)
var entity_layer = null

# Economy system references (set by main scene)
var land_manager: LandManager = null
var staff_manager: StaffManager = null
var marketing_manager: MarketingManager = null

# Daily statistics tracking
var daily_stats: DailyStatistics = DailyStatistics.new()
var yesterday_stats: DailyStatistics = null  # Previous day's stats for comparison

# Per-hole cumulative statistics (persists across days)
var hole_statistics: Dictionary = {}  # hole_number -> HoleStatistics

# Course rating (1-5 stars)
var course_rating: Dictionary = {
	"condition": 3.0,
	"design": 3.0,
	"value": 3.0,
	"pace": 3.0,
	"overall": 3.0,
	"stars": 3
}

# Course records tracking
var course_records: Dictionary = CourseRecords.create_empty_records()

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
	# Connect signals for daily statistics tracking
	EventBus.green_fee_paid.connect(_on_green_fee_paid_for_stats)
	EventBus.golfer_finished_hole.connect(_on_golfer_finished_hole_for_stats)
	EventBus.golfer_finished_round.connect(_on_golfer_finished_round_for_stats)
	EventBus.hole_created.connect(_on_hole_created_for_fee_clamp)

func _on_hole_created_for_fee_clamp(_hole_number: int, _par: int, _distance: int) -> void:
	clamp_green_fee_to_max()

func _on_green_fee_paid_for_stats(_golfer_id: int, _golfer_name: String, amount: int) -> void:
	daily_stats.record_green_fee(amount)

func _on_golfer_finished_hole_for_stats(_golfer_id: int, hole_index: int, strokes: int, par: int) -> void:
	daily_stats.record_hole_score(strokes, par)

	# Record per-hole cumulative stats
	# Note: hole_index is 0-based from golfer, but HoleData uses 1-based hole_number
	var hole_number = hole_index + 1
	if not hole_statistics.has(hole_number):
		hole_statistics[hole_number] = HoleStatistics.new(hole_number)
	hole_statistics[hole_number].record_score(strokes, par)

func _on_golfer_finished_round_for_stats(_golfer_id: int, total_strokes: int) -> void:
	# Get total par from course
	var total_par = 0
	if current_course:
		for hole in current_course.get_open_holes():
			total_par += hole.par
	daily_stats.record_round_finished(total_strokes, total_par)

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
	EventBus.hour_changed.emit(current_hour)

	# Update wind and weather drift each game hour
	if int(current_hour) != int(old_hour):
		if wind_system:
			wind_system.update_wind_drift(current_hour - COURSE_OPEN_HOUR)
		if weather_system:
			weather_system.update_weather(1.0)  # 1 hour elapsed

	# Announce course closing 1 hour before close
	if not _closing_announced and current_hour >= COURSE_CLOSE_HOUR - 1.0:
		_closing_announced = true
		EventBus.course_closing.emit()
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
	EventBus.game_mode_changed.emit(old_mode, new_mode)

func set_speed(new_speed: GameSpeed) -> void:
	current_speed = new_speed
	EventBus.game_speed_changed.emit(new_speed)

func toggle_pause() -> void:
	is_paused = not is_paused
	EventBus.pause_toggled.emit(is_paused)

func modify_money(amount: int) -> void:
	var old_money = money
	money += amount
	EventBus.money_changed.emit(old_money, money)

func can_afford(cost: int) -> bool:
	"""Check if a purchase is allowed (not blocked by bankruptcy threshold)."""
	if cost <= 0:
		return true  # Not a purchase
	return money - cost >= BANKRUPTCY_THRESHOLD

func is_bankrupt() -> bool:
	"""Check if spending is blocked due to low balance."""
	return money < BANKRUPTCY_THRESHOLD

func modify_reputation(amount: float) -> void:
	var old_rep = reputation
	reputation = clamp(reputation + amount, 0.0, 100.0)
	EventBus.reputation_changed.emit(old_rep, reputation)

func set_green_fee(new_fee: int) -> void:
	var old_fee = green_fee
	var effective_max = get_effective_max_green_fee()
	green_fee = clamp(new_fee, MIN_GREEN_FEE, effective_max)
	EventBus.green_fee_changed.emit(old_fee, green_fee)

func get_hole_statistics(hole_number: int) -> HoleStatistics:
	"""Get cumulative statistics for a specific hole"""
	if hole_statistics.has(hole_number):
		return hole_statistics[hole_number]
	return null

func update_course_rating() -> void:
	"""Recalculate course rating based on current state"""
	if not current_course or not terrain_grid:
		return
	course_rating = CourseRatingSystem.calculate_rating(
		terrain_grid, current_course, daily_stats, green_fee, reputation
	)
	EventBus.course_rating_changed.emit(course_rating)

func get_open_hole_count() -> int:
	"""Get the number of open (playable) holes on the course"""
	if not current_course:
		return 0
	return current_course.get_open_holes().size()

func get_effective_max_green_fee() -> int:
	"""Get the maximum green fee allowed based on hole count.
	More holes = higher max fee. Prevents 1-hole courses charging $200."""
	var holes = get_open_hole_count()
	if holes <= 0:
		return MIN_GREEN_FEE
	# $15 per hole, minimum $10
	return max(MIN_GREEN_FEE, min(holes * 15, MAX_GREEN_FEE))

func clamp_green_fee_to_max() -> void:
	"""Re-clamp green fee after hole count changes."""
	var effective_max = get_effective_max_green_fee()
	if green_fee > effective_max:
		set_green_fee(effective_max)

func process_green_fee_payment(golfer_id: int, golfer_name: String) -> bool:
	"""Process a golfer's green fee payment and return success.
	Revenue = per-hole fee x number of open holes + pro shop bonus."""
	var holes = get_open_hole_count()
	var total = green_fee * max(holes, 1)

	# Pro shop staff add bonus revenue per golfer
	if staff_manager:
		total += int(staff_manager.get_pro_shop_revenue_bonus())

	modify_money(total)
	EventBus.log_transaction("%s paid green fee (%d holes x $%d)" % [golfer_name, holes, green_fee], total)
	EventBus.green_fee_paid.emit(golfer_id, golfer_name, total)
	return true

## Check and update hole records (call when golfer finishes a hole)
## Returns array of record types broken
func check_hole_records(golfer_name: String, hole_number: int, strokes: int) -> Array:
	var records_broken: Array = []

	# Check hole-in-one
	if strokes == 1:
		course_records.total_hole_in_ones += 1
		var entry = CourseRecords.RecordEntry.new(golfer_name, 1, current_day, hole_number)
		course_records.hole_in_ones.append(entry)
		records_broken.append({"type": "hole_in_one", "hole": hole_number})
		EventBus.record_broken.emit("hole_in_one", golfer_name, 1, hole_number)

	# Check best score for this hole
	var current_best = course_records.best_per_hole.get(hole_number)
	if current_best == null or strokes < current_best.value:
		var entry = CourseRecords.RecordEntry.new(golfer_name, strokes, current_day, hole_number)
		course_records.best_per_hole[hole_number] = entry
		if current_best != null:  # Only announce if breaking existing record
			records_broken.append({"type": "hole_record", "hole": hole_number, "strokes": strokes})
			EventBus.record_broken.emit("hole_record", golfer_name, strokes, hole_number)

	return records_broken

## Check if golfer set the course record (call when round finishes)
## Returns true if new course record was set
func check_round_record(golfer_name: String, total_strokes: int) -> bool:
	var current = course_records.lowest_round
	if current == null or total_strokes < current.value:
		course_records.lowest_round = CourseRecords.RecordEntry.new(
			golfer_name, total_strokes, current_day, -1
		)
		EventBus.record_broken.emit("course_record", golfer_name, total_strokes, -1)
		EventBus.notify("%s set a new course record: %d strokes!" % [golfer_name, total_strokes], "success")
		return true
	return false

## Reset course records (for new game)
func reset_course_records() -> void:
	course_records = CourseRecords.create_empty_records()

func new_game(course_name_input: String = "New Course", theme: int = CourseTheme.Type.PARKLAND) -> void:
	course_name = course_name_input
	current_theme = theme
	money = 50000
	reputation = 50.0
	current_day = 1
	current_hour = COURSE_OPEN_HOUR

	# Apply theme gameplay modifiers
	var modifiers = CourseTheme.get_gameplay_modifiers(theme)
	green_fee = modifiers.get("green_fee_baseline", 30)
	clamp_green_fee_to_max()  # Clamp to what current hole count allows

	_closing_announced = false
	_end_of_day_triggered = false
	_end_of_day_emitted = false
	current_course = CourseData.new()
	daily_stats.reset()
	yesterday_stats = null  # No yesterday on day 1
	hole_statistics.clear()  # Clear per-hole stats for new game
	reset_course_records()  # Clear records for new game

	# Apply theme colors to tileset generator
	TilesetGenerator.set_theme_colors(CourseTheme.get_terrain_colors(theme))
	EventBus.theme_changed.emit(theme)

	set_mode(GameMode.BUILDING)
	EventBus.new_game_started.emit()

func is_course_open() -> bool:
	return current_hour >= COURSE_OPEN_HOUR and current_hour < COURSE_CLOSE_HOUR

func force_end_day() -> void:
	"""Force advance to closing time - useful for testing."""
	if current_mode != GameMode.SIMULATING:
		EventBus.notify("Must be in simulation mode to end day", "error")
		return

	if _end_of_day_triggered:
		EventBus.notify("Day already ending", "info")
		return

	# Jump to closing time
	current_hour = COURSE_CLOSE_HOUR

	# Trigger course closing announcement if not already done
	if not _closing_announced:
		_closing_announced = true
		EventBus.course_closing.emit()

	# Trigger end of day
	_end_of_day_triggered = true
	EventBus.notify("Course closed early - golfers finishing up", "info")

func is_end_of_day_pending() -> bool:
	return _end_of_day_triggered

var _end_of_day_emitted: bool = false

func request_end_of_day() -> void:
	"""Called when all golfers have left after closing. Emits end_of_day signal."""
	if not _end_of_day_triggered:
		return
	if _end_of_day_emitted:
		return  # Already emitted, waiting for advance_to_next_day()
	_end_of_day_emitted = true
	EventBus.end_of_day.emit(current_day)

func advance_to_next_day() -> void:
	"""Advance to the next morning. Called after end-of-day processing is complete."""
	# Apply daily reputation decay — courses must maintain quality to keep reputation
	# This prevents permanent reputation lock-in from a single tournament
	if reputation > 0:
		modify_reputation(-REPUTATION_DAILY_DECAY)

	# Save yesterday's stats before resetting
	yesterday_stats = DailyStatistics.new()
	yesterday_stats.revenue = daily_stats.revenue
	yesterday_stats.building_revenue = daily_stats.building_revenue
	yesterday_stats.operating_costs = daily_stats.operating_costs
	yesterday_stats.terrain_maintenance = daily_stats.terrain_maintenance
	yesterday_stats.base_operating_cost = daily_stats.base_operating_cost
	yesterday_stats.staff_wages = daily_stats.staff_wages
	yesterday_stats.golfers_served = daily_stats.golfers_served

	# Reset daily statistics for the new day
	daily_stats.reset()

	current_day += 1
	current_hour = COURSE_OPEN_HOUR
	_closing_announced = false
	_end_of_day_triggered = false
	_end_of_day_emitted = false
	EventBus.day_changed.emit(current_day)
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

func _exit_tree() -> void:
	# Disconnect signals to prevent memory leaks and double-callbacks on reload
	if EventBus.green_fee_paid.is_connected(_on_green_fee_paid_for_stats):
		EventBus.green_fee_paid.disconnect(_on_green_fee_paid_for_stats)
	if EventBus.golfer_finished_hole.is_connected(_on_golfer_finished_hole_for_stats):
		EventBus.golfer_finished_hole.disconnect(_on_golfer_finished_hole_for_stats)
	if EventBus.golfer_finished_round.is_connected(_on_golfer_finished_round_for_stats):
		EventBus.golfer_finished_round.disconnect(_on_golfer_finished_round_for_stats)
	if EventBus.hole_created.is_connected(_on_hole_created_for_fee_clamp):
		EventBus.hole_created.disconnect(_on_hole_created_for_fee_clamp)

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
				EventBus.hole_toggled.emit(hole_number, hole.is_open)
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

## DailyStatistics - Tracks statistics for the current day
class DailyStatistics:
	var revenue: int = 0  # Green fees collected today
	var golfers_served: int = 0  # Number of golfers who finished their round
	var holes_in_one: int = 0
	var eagles: int = 0  # Par - 2 (or better on par 5s)
	var birdies: int = 0  # Par - 1
	var bogeys_or_worse: int = 0  # Par + 1 or worse (for pace indicator)
	var total_strokes_today: int = 0  # For calculating average score
	var total_par_today: int = 0  # For calculating average score
	var operating_costs: int = 0  # Total operating costs (sum of below)

	# Operating cost breakdown
	var terrain_maintenance: int = 0  # Cost from terrain upkeep
	var base_operating_cost: int = 0  # Fixed daily cost based on course size
	var staff_wages: int = 0  # Staff costs based on number of holes
	var building_operating_costs: int = 0  # Daily costs from buildings

	# Building revenue from amenities
	var building_revenue: int = 0

	# Golfer tier counts
	var tier_counts: Dictionary = {
		GolferTier.Tier.BEGINNER: 0,
		GolferTier.Tier.CASUAL: 0,
		GolferTier.Tier.SERIOUS: 0,
		GolferTier.Tier.PRO: 0,
	}

	func reset() -> void:
		revenue = 0
		golfers_served = 0
		holes_in_one = 0
		eagles = 0
		birdies = 0
		bogeys_or_worse = 0
		building_revenue = 0
		total_strokes_today = 0
		total_par_today = 0
		operating_costs = 0
		terrain_maintenance = 0
		base_operating_cost = 0
		staff_wages = 0
		building_operating_costs = 0
		tier_counts = {
			GolferTier.Tier.BEGINNER: 0,
			GolferTier.Tier.CASUAL: 0,
			GolferTier.Tier.SERIOUS: 0,
			GolferTier.Tier.PRO: 0,
		}

	## Calculate operating costs based on terrain and course size
	## terrain_cost: total maintenance cost from terrain grid
	## hole_count: number of holes on the course
	## building_costs: total operating costs from all buildings
	func calculate_operating_costs(terrain_cost: int, hole_count: int, building_costs: int = 0) -> void:
		# Terrain maintenance from actual tiles
		terrain_maintenance = terrain_cost

		# Base operating cost: $50 + $25 per hole
		base_operating_cost = 50 + (hole_count * 25)

		# Staff wages based on tier
		var tier_data = GameManager.STAFF_TIER_DATA.get(GameManager.current_staff_tier, {})
		var cost_per_hole = tier_data.get("cost_per_hole", 10)
		staff_wages = hole_count * cost_per_hole

		# Building operating costs (daily upkeep for amenities)
		building_operating_costs = building_costs

		# Total
		operating_costs = terrain_maintenance + base_operating_cost + staff_wages + building_operating_costs

	func get_profit() -> int:
		return revenue + building_revenue - operating_costs

	func get_total_revenue() -> int:
		return revenue + building_revenue

	func get_average_score_to_par() -> float:
		if total_par_today == 0:
			return 0.0
		return float(total_strokes_today - total_par_today) / float(golfers_served) if golfers_served > 0 else 0.0

	func record_hole_score(strokes: int, par: int) -> void:
		var classification = GolfRules.classify_score(strokes, par)
		match classification:
			"hole_in_one": holes_in_one += 1
			"eagle": eagles += 1
			"birdie": birdies += 1
			"bogey", "double_bogey_plus": bogeys_or_worse += 1

	func record_round_finished(total_strokes: int, total_par: int) -> void:
		golfers_served += 1
		total_strokes_today += total_strokes
		total_par_today += total_par

	func record_green_fee(amount: int) -> void:
		revenue += amount

	func record_golfer_tier(tier: int) -> void:
		if tier in tier_counts:
			tier_counts[tier] += 1

## HoleStatistics - Tracks cumulative statistics for a single hole
class HoleStatistics:
	var hole_number: int = 0
	var total_rounds: int = 0
	var total_strokes: int = 0
	var eagles: int = 0
	var birdies: int = 0
	var pars: int = 0
	var bogeys: int = 0
	var double_bogeys_plus: int = 0
	var holes_in_one: int = 0
	var best_score: int = -1
	var best_scorer_name: String = ""

	func _init(hole_num: int = 0) -> void:
		hole_number = hole_num

	func record_score(strokes: int, par: int, golfer_name: String = "") -> void:
		total_rounds += 1
		total_strokes += strokes
		var classification = GolfRules.classify_score(strokes, par)
		match classification:
			"hole_in_one":
				holes_in_one += 1
				eagles += 1  # Hole-in-one counts as eagle or better
			"eagle": eagles += 1
			"birdie": birdies += 1
			"par": pars += 1
			"bogey": bogeys += 1
			"double_bogey_plus": double_bogeys_plus += 1

		# Track best score
		if best_score < 0 or strokes < best_score:
			best_score = strokes
			best_scorer_name = golfer_name

	func get_average_score() -> float:
		if total_rounds == 0:
			return 0.0
		return float(total_strokes) / float(total_rounds)

	func get_average_to_par(par: int) -> float:
		if total_rounds == 0:
			return 0.0
		return get_average_score() - float(par)
