extends Node
class_name EventFeedManager
## EventFeedManager - Persistent event feed for game history
##
## Captures important game events from EventBus signals and stores them
## in a scrollable, filterable feed. Events persist for the session and
## support click-to-navigate and category filtering.

const MAX_EVENTS: int = 200

## Event categories
enum Category {
	RECORDS,
	ECONOMY,
	GOLFERS,
	WEATHER,
	TOURNAMENT,
	MILESTONE,
	COURSE,
	DAILY,
}

## Priority levels
enum Priority {
	INFO,      # Feed only, no toast
	NORMAL,    # Standard 3.5s toast
	HIGH,      # Extended 5s toast, badge pulse
	CRITICAL,  # Persists until clicked, pauses ULTRA speed
}

## Navigate target types
enum NavigateType {
	NONE,
	GOLFER,
	HOLE,
	POSITION,
	PANEL,
}

## Single event entry in the feed
class EventEntry:
	var timestamp_day: int = 0
	var timestamp_hour: float = 0.0
	var category: int = Category.GOLFERS
	var priority: int = Priority.NORMAL
	var message: String = ""
	var icon: String = ""
	var icon_color: Color = Color.WHITE
	var navigate_type: int = NavigateType.NONE
	var navigate_value: Variant = null  # golfer_id, hole_number, Vector2i, or panel name
	var id: int = 0  # Unique ID for tracking

## Category metadata
const CATEGORY_DATA: Dictionary = {
	Category.RECORDS: {"name": "Records", "icon": "*", "color_key": "gold"},
	Category.ECONOMY: {"name": "Economy", "icon": "$", "color_key": "success"},
	Category.GOLFERS: {"name": "Golfers", "icon": "#", "color_key": "info"},
	Category.WEATHER: {"name": "Weather", "icon": "~", "color_key": "info"},
	Category.TOURNAMENT: {"name": "Tournament", "icon": "!", "color_key": "purple"},
	Category.MILESTONE: {"name": "Milestone", "icon": "+", "color_key": "orange"},
	Category.COURSE: {"name": "Course", "icon": "=", "color_key": "warning"},
	Category.DAILY: {"name": "Daily", "icon": ">", "color_key": "text_dim"},
}

signal event_added(entry: EventEntry)
signal unread_count_changed(count: int)

var events: Array = []  # Array of EventEntry
var unread_count: int = 0
var category_filters: Dictionary = {}  # Category enum -> bool (true = visible)
var _next_id: int = 0
var _is_feed_open: bool = false

func _ready() -> void:
	# Initialize all category filters to visible
	for cat in Category.values():
		category_filters[cat] = true

	# Connect to EventBus signals
	_connect_signals()

func _connect_signals() -> void:
	# Records
	EventBus.record_broken.connect(_on_record_broken)

	# Economy
	EventBus.money_changed.connect(_on_money_changed)
	EventBus.reputation_changed.connect(_on_reputation_changed)
	EventBus.green_fee_changed.connect(_on_green_fee_changed)
	EventBus.course_rating_changed.connect(_on_course_rating_changed)

	# Golfers
	EventBus.golfer_finished_round.connect(_on_golfer_finished_round)
	EventBus.golfer_finished_hole.connect(_on_golfer_finished_hole)

	# Weather
	EventBus.weather_changed.connect(_on_weather_changed)
	EventBus.season_changed.connect(_on_season_changed)

	# Tournaments
	EventBus.tournament_scheduled.connect(_on_tournament_scheduled)
	EventBus.tournament_started.connect(_on_tournament_started)
	EventBus.tournament_completed.connect(_on_tournament_completed)

	# Course
	EventBus.hole_created.connect(_on_hole_created)
	EventBus.hole_deleted.connect(_on_hole_deleted)
	EventBus.building_placed.connect(_on_building_placed)

	# Day cycle
	EventBus.end_of_day.connect(_on_end_of_day)

	# Game state
	EventBus.new_game_started.connect(_on_new_game_started)

## Add an event to the feed
func add_event(category: int, priority: int, message: String,
		navigate_type: int = NavigateType.NONE, navigate_value: Variant = null) -> EventEntry:
	# Don't log events during main menu
	if GameManager.current_mode == GameManager.GameMode.MAIN_MENU:
		return null

	var entry = EventEntry.new()
	entry.timestamp_day = GameManager.current_day
	entry.timestamp_hour = GameManager.current_hour
	entry.category = category
	entry.priority = priority
	entry.message = message
	entry.navigate_type = navigate_type
	entry.navigate_value = navigate_value
	entry.id = _next_id
	_next_id += 1

	# Set icon and color from category data
	var cat_data = CATEGORY_DATA.get(category, {})
	entry.icon = cat_data.get("icon", "?")
	entry.icon_color = _get_category_color(category)

	events.append(entry)

	# Trim oldest events if over limit
	while events.size() > MAX_EVENTS:
		events.pop_front()

	# Track unread
	if not _is_feed_open:
		unread_count += 1
		unread_count_changed.emit(unread_count)

	event_added.emit(entry)
	return entry

## Mark all events as read (called when feed panel opens)
func mark_all_read() -> void:
	_is_feed_open = true
	if unread_count > 0:
		unread_count = 0
		unread_count_changed.emit(0)

## Called when feed panel closes
func on_feed_closed() -> void:
	_is_feed_open = false

## Get events filtered by current category settings
func get_filtered_events() -> Array:
	return events.filter(func(e: EventEntry): return category_filters.get(e.category, true))

## Toggle a category filter
func set_category_visible(category: int, visible: bool) -> void:
	category_filters[category] = visible

## Get color for a category
func _get_category_color(category: int) -> Color:
	var cat_data = CATEGORY_DATA.get(category, {})
	var color_key = cat_data.get("color_key", "info")
	match color_key:
		"gold": return UIConstants.COLOR_GOLD
		"success": return UIConstants.COLOR_SUCCESS
		"info": return UIConstants.COLOR_INFO
		"purple": return UIConstants.COLOR_PURPLE
		"orange": return UIConstants.COLOR_ORANGE
		"warning": return UIConstants.COLOR_WARNING
		"text_dim": return UIConstants.COLOR_TEXT_DIM
		_: return UIConstants.COLOR_TEXT

## Clear all events (e.g. on new game)
func clear_events() -> void:
	events.clear()
	unread_count = 0
	_next_id = 0
	unread_count_changed.emit(0)

# --- Signal handlers ---

func _on_record_broken(record_type: String, golfer_name: String, value: int, hole_number: int) -> void:
	var msg := ""
	match record_type:
		"hole_in_one":
			msg = "Hole-in-one! %s on Hole #%d" % [golfer_name, hole_number]
		"lowest_round":
			msg = "Course record! %s shot %d" % [golfer_name, value]
		"best_hole":
			msg = "Hole record! %s scored %d on Hole #%d" % [golfer_name, value, hole_number]
		_:
			msg = "New record by %s: %s" % [golfer_name, record_type]
	add_event(Category.RECORDS, Priority.HIGH, msg, NavigateType.HOLE, hole_number)

func _on_money_changed(old_amount: int, new_amount: int) -> void:
	# Only log significant money milestones
	var milestones := [100000, 250000, 500000, 1000000]
	for milestone in milestones:
		if old_amount < milestone and new_amount >= milestone:
			add_event(Category.ECONOMY, Priority.NORMAL,
				"Reached $%s!" % _format_money(milestone))
			return

	# Bankruptcy warning
	if new_amount < 0 and old_amount >= 0:
		add_event(Category.ECONOMY, Priority.CRITICAL,
			"Warning: Funds depleted! Balance: $%s" % _format_money(new_amount))
	elif new_amount <= -500 and old_amount > -500:
		add_event(Category.ECONOMY, Priority.CRITICAL,
			"Bankruptcy imminent! Balance: $%s" % _format_money(new_amount))

func _on_reputation_changed(old_rep: float, new_rep: float) -> void:
	# Log reputation milestones (every 25 points)
	var old_bracket := int(old_rep / 25.0)
	var new_bracket := int(new_rep / 25.0)
	if new_bracket > old_bracket and new_rep >= 25.0:
		add_event(Category.ECONOMY, Priority.NORMAL,
			"Reputation reached %.0f!" % new_rep)
	elif new_bracket < old_bracket and old_rep >= 25.0:
		add_event(Category.ECONOMY, Priority.NORMAL,
			"Reputation dropped to %.0f" % new_rep, NavigateType.PANEL, "financial")

func _on_green_fee_changed(old_fee: int, new_fee: int) -> void:
	add_event(Category.ECONOMY, Priority.INFO,
		"Green fee changed: $%d -> $%d" % [old_fee, new_fee])

func _on_course_rating_changed(rating: Dictionary) -> void:
	var stars = rating.get("stars", 0)
	var overall = rating.get("overall", 0.0)
	add_event(Category.COURSE, Priority.NORMAL,
		"Course rating updated: %.1f (%d stars)" % [overall, stars])

func _on_golfer_finished_round(golfer_id: int, total_score: int, total_par: int) -> void:
	var diff = total_score - total_par
	# Only log notable rounds (3 under par or worse)
	if diff <= -3:
		var diff_str = "%d" % diff
		add_event(Category.GOLFERS, Priority.NORMAL,
			"Outstanding round: %d (%s) completed" % [total_score, diff_str],
			NavigateType.GOLFER, golfer_id)

func _on_golfer_finished_hole(golfer_id: int, hole_number: int, strokes: int, par: int) -> void:
	var diff = strokes - par
	if diff <= -2:
		var score_name = "Eagle" if diff == -2 else "Albatross"
		add_event(Category.RECORDS, Priority.HIGH,
			"%s on Hole #%d! (%d strokes, par %d)" % [score_name, hole_number, strokes, par],
			NavigateType.HOLE, hole_number)

func _on_weather_changed(weather_type: int, _intensity: float) -> void:
	var weather_names := {
		0: "Sunny", 1: "Partly Cloudy", 2: "Overcast",
		3: "Light Rain", 4: "Rain", 5: "Heavy Rain"
	}
	var name = weather_names.get(weather_type, "Unknown")
	add_event(Category.WEATHER, Priority.INFO, "Weather: %s" % name)

func _on_season_changed(old_season: int, new_season: int) -> void:
	var season_names := {0: "Spring", 1: "Summer", 2: "Fall", 3: "Winter"}
	var name = season_names.get(new_season, "Unknown")
	add_event(Category.WEATHER, Priority.NORMAL, "Season changed to %s" % name)

func _on_tournament_scheduled(tier: int, start_day: int) -> void:
	var tier_names := {0: "Local", 1: "Regional", 2: "National", 3: "Championship"}
	var name = tier_names.get(tier, "Tournament")
	add_event(Category.TOURNAMENT, Priority.NORMAL,
		"%s tournament scheduled for Day %d" % [name, start_day])

func _on_tournament_started(tier: int) -> void:
	var tier_names := {0: "Local", 1: "Regional", 2: "National", 3: "Championship"}
	var name = tier_names.get(tier, "Tournament")
	add_event(Category.TOURNAMENT, Priority.HIGH, "%s tournament has begun!" % name)

func _on_tournament_completed(tier: int, results: Dictionary) -> void:
	var tier_names := {0: "Local", 1: "Regional", 2: "National", 3: "Championship"}
	var name = tier_names.get(tier, "Tournament")
	var winner = results.get("winner_name", "Unknown")
	var score = results.get("winning_score", 0)
	add_event(Category.TOURNAMENT, Priority.HIGH,
		"%s tournament complete! Winner: %s (%d)" % [name, winner, score])

func _on_hole_created(hole_number: int, par: int, distance_yards: int) -> void:
	add_event(Category.COURSE, Priority.NORMAL,
		"Hole #%d created (Par %d, %d yards)" % [hole_number, par, distance_yards])

func _on_hole_deleted(hole_number: int) -> void:
	add_event(Category.COURSE, Priority.NORMAL,
		"Hole #%d removed" % hole_number)

func _on_building_placed(building_type: String, position: Vector2i) -> void:
	add_event(Category.COURSE, Priority.INFO,
		"%s built" % building_type.capitalize(),
		NavigateType.POSITION, position)

func _on_end_of_day(day_number: int) -> void:
	# Generate daily summary
	var stats = GameManager.daily_stats
	var revenue = stats.get_total_revenue()
	var profit = stats.get_profit()
	var golfers = stats.golfers_served
	var satisfaction = FeedbackManager.get_satisfaction_rating() * 100.0

	var notable_parts: Array = []
	if stats.holes_in_one > 0:
		notable_parts.append("%d HIO" % stats.holes_in_one)
	if stats.eagles > 0:
		notable_parts.append("%d eagle%s" % [stats.eagles, "s" if stats.eagles > 1 else ""])

	var msg = "Day %d: %d golfers, $%s revenue, $%s profit, %.0f%% satisfaction" % [
		day_number, golfers, _format_money(revenue), _format_money(profit), satisfaction
	]
	if not notable_parts.is_empty():
		msg += " | " + ", ".join(notable_parts)

	add_event(Category.DAILY, Priority.NORMAL, msg)

func _on_new_game_started() -> void:
	clear_events()
	add_event(Category.COURSE, Priority.NORMAL, "Welcome to %s!" % GameManager.course_name)

func _format_money(amount: int) -> String:
	if amount < 0:
		return "-%s" % _format_money(-amount)
	if amount >= 1000000:
		return "%.1fM" % (amount / 1000000.0)
	if amount >= 1000:
		return "%d,%03d" % [amount / 1000, amount % 1000]
	return str(amount)
