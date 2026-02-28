extends Node
class_name EventFeedManager
## EventFeedManager - Persistent event feed for game events
##
## Captures events from EventBus signals and stores them in a scrollable,
## filterable feed. Events persist across the session (up to MAX_EVENTS).
## Replaces nothing — works alongside NotificationToast which handles
## ephemeral pop-up notifications.

const MAX_EVENTS: int = 200

# Event categories
const CAT_RECORD := "record"
const CAT_ECONOMY := "economy"
const CAT_GOLFER := "golfer"
const CAT_WEATHER := "weather"
const CAT_TOURNAMENT := "tournament"
const CAT_MILESTONE := "milestone"
const CAT_COURSE := "course"
const CAT_DAILY := "daily"

# Priority levels
const PRIORITY_INFO := 0      # Feed only, no toast
const PRIORITY_NORMAL := 1    # Standard toast
const PRIORITY_HIGH := 2      # Extended toast, badge pulse
const PRIORITY_CRITICAL := 3  # Persistent toast, auto-open feed

# Category display data: icon, color
const CATEGORY_DATA := {
	CAT_RECORD: { "icon": "[*]", "color": Color(1.0, 0.85, 0.0) },      # Gold
	CAT_ECONOMY: { "icon": "[$]", "color": Color(0.4, 0.9, 0.4) },      # Green
	CAT_GOLFER: { "icon": "[G]", "color": Color(0.4, 0.7, 1.0) },       # Blue
	CAT_WEATHER: { "icon": "[~]", "color": Color(0.5, 0.85, 0.9) },     # Cyan
	CAT_TOURNAMENT: { "icon": "[T]", "color": Color(0.7, 0.4, 0.9) },   # Purple
	CAT_MILESTONE: { "icon": "[!]", "color": Color(0.9, 0.6, 0.3) },    # Orange
	CAT_COURSE: { "icon": "[#]", "color": Color(0.7, 0.55, 0.35) },     # Brown
	CAT_DAILY: { "icon": "[=]", "color": Color(0.6, 0.6, 0.6) },        # Gray
}

var events: Array = []  # Array of EventEntry instances
var category_filters: Dictionary = {}  # category string -> bool (true = visible)
var unread_count: int = 0

signal event_added(entry: RefCounted)
signal unread_count_changed(count: int)
signal feed_cleared()

func _ready() -> void:
	# Initialize all filters to visible
	for cat in CATEGORY_DATA:
		category_filters[cat] = true
	_connect_event_bus()
	print("EventFeedManager initialized")

func _connect_event_bus() -> void:
	# Records
	EventBus.record_broken.connect(_on_record_broken)

	# Economy
	EventBus.money_changed.connect(_on_money_changed)
	EventBus.green_fee_changed.connect(_on_green_fee_changed)
	EventBus.course_rating_changed.connect(_on_course_rating_changed)

	# Golfers
	EventBus.golfer_finished_round.connect(_on_golfer_finished_round)

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

	# New game — clear feed
	EventBus.new_game_started.connect(_on_new_game)

## Add an event to the feed
func add_event(category: String, priority: int, message: String,
			   navigate_target: Variant = null, detail_action: String = "") -> void:
	var entry = EventEntry.new()
	entry.timestamp_day = GameManager.current_day
	entry.timestamp_hour = GameManager.current_hour
	entry.category = category
	entry.priority = priority
	entry.message = message
	entry.navigate_target = navigate_target
	entry.detail_action = detail_action

	var cat_data = CATEGORY_DATA.get(category, {})
	entry.icon = cat_data.get("icon", "[?]")
	entry.color = cat_data.get("color", Color.WHITE)

	events.append(entry)
	if events.size() > MAX_EVENTS:
		events.pop_front()

	unread_count += 1
	event_added.emit(entry)
	unread_count_changed.emit(unread_count)

## Mark all events as read (called when feed panel is opened)
func mark_all_read() -> void:
	unread_count = 0
	unread_count_changed.emit(0)

## Get filtered events based on current category_filters
func get_filtered_events() -> Array:
	var result: Array = []
	for entry in events:
		if category_filters.get(entry.category, true):
			result.append(entry)
	return result

## Set filter for a category
func set_category_filter(category: String, visible: bool) -> void:
	category_filters[category] = visible

## Clear all events (e.g. on new game)
func clear() -> void:
	events.clear()
	unread_count = 0
	unread_count_changed.emit(0)
	feed_cleared.emit()

## Get category display info
static func get_category_icon(category: String) -> String:
	return CATEGORY_DATA.get(category, {}).get("icon", "[?]")

static func get_category_color(category: String) -> Color:
	return CATEGORY_DATA.get(category, {}).get("color", Color.WHITE)

static func get_category_name(category: String) -> String:
	match category:
		CAT_RECORD: return "Records"
		CAT_ECONOMY: return "Economy"
		CAT_GOLFER: return "Golfers"
		CAT_WEATHER: return "Weather"
		CAT_TOURNAMENT: return "Tournament"
		CAT_MILESTONE: return "Milestone"
		CAT_COURSE: return "Course"
		CAT_DAILY: return "Daily"
		_: return category.capitalize()

# ─── Signal handlers ──────────────────────────────────────────────

func _on_record_broken(record_type: String, golfer_name: String, value: int, hole_number: int) -> void:
	match record_type:
		"hole_in_one":
			add_event(CAT_RECORD, PRIORITY_HIGH,
				"Hole-in-one! %s on Hole #%d" % [golfer_name, hole_number],
				hole_number, "view_hole")
		"hole_record":
			add_event(CAT_RECORD, PRIORITY_HIGH,
				"Hole record! %s shot %d on Hole #%d" % [golfer_name, value, hole_number],
				hole_number, "view_hole")
		"course_record":
			add_event(CAT_RECORD, PRIORITY_HIGH,
				"Course record! %s shot %d strokes" % [golfer_name, value])

var _last_bankruptcy_warning_day: int = -1

func _on_money_changed(_old_amount: int, new_amount: int) -> void:
	# Bankruptcy warning
	if new_amount < 0 and new_amount > GameManager.bankruptcy_threshold:
		if _last_bankruptcy_warning_day != GameManager.current_day:
			_last_bankruptcy_warning_day = GameManager.current_day
			add_event(CAT_ECONOMY, PRIORITY_CRITICAL,
				"Warning: Funds at $%d — bankruptcy at $%d!" % [new_amount, GameManager.bankruptcy_threshold])
	elif new_amount <= GameManager.bankruptcy_threshold:
		add_event(CAT_ECONOMY, PRIORITY_CRITICAL,
			"BANKRUPT! Funds fell to $%d" % new_amount)

func _on_green_fee_changed(old_fee: int, new_fee: int) -> void:
	add_event(CAT_ECONOMY, PRIORITY_NORMAL,
		"Green fee changed: $%d -> $%d" % [old_fee, new_fee])

func _on_course_rating_changed(rating: Dictionary) -> void:
	var stars = rating.get("stars", 0)
	var overall = rating.get("overall", 0.0)
	add_event(CAT_COURSE, PRIORITY_INFO,
		"Course rating updated: %.1f (%d stars)" % [overall, stars])

func _on_golfer_finished_round(golfer_id: int, total_score: int, total_par: int) -> void:
	var diff = total_score - total_par
	var diff_str = "%+d" % diff if diff != 0 else "E"
	add_event(CAT_GOLFER, PRIORITY_INFO,
		"Round complete: %d strokes (%s)" % [total_score, diff_str],
		golfer_id, "view_golfer")

func _on_weather_changed(weather_type: int, _intensity: float) -> void:
	var name = UIConstants.get_weather_name(weather_type)
	add_event(CAT_WEATHER, PRIORITY_INFO,
		"Weather: %s" % name)

func _on_season_changed(_old_season: int, new_season: int) -> void:
	var season_names = ["Spring", "Summer", "Fall", "Winter"]
	var season_name = season_names[new_season] if new_season < season_names.size() else "Unknown"
	add_event(CAT_WEATHER, PRIORITY_NORMAL,
		"Season changed to %s" % season_name)

func _on_tournament_scheduled(tier: int, start_day: int) -> void:
	var tier_names = ["Local", "Regional", "National", "Championship"]
	var tier_name = tier_names[tier] if tier < tier_names.size() else "Unknown"
	add_event(CAT_TOURNAMENT, PRIORITY_NORMAL,
		"%s Tournament scheduled for Day %d" % [tier_name, start_day])

func _on_tournament_started(tier: int) -> void:
	var tier_names = ["Local", "Regional", "National", "Championship"]
	var tier_name = tier_names[tier] if tier < tier_names.size() else "Unknown"
	add_event(CAT_TOURNAMENT, PRIORITY_HIGH,
		"%s Tournament has begun!" % tier_name)

func _on_tournament_completed(tier: int, results: Dictionary) -> void:
	var tier_names = ["Local", "Regional", "National", "Championship"]
	var tier_name = tier_names[tier] if tier < tier_names.size() else "Unknown"
	var winner = results.get("winner", "Unknown")
	add_event(CAT_TOURNAMENT, PRIORITY_HIGH,
		"%s Tournament complete — Winner: %s" % [tier_name, winner])

func _on_hole_created(hole_number: int, par: int, distance_yards: int) -> void:
	add_event(CAT_COURSE, PRIORITY_NORMAL,
		"Hole #%d created (Par %d, %d yards)" % [hole_number, par, distance_yards],
		hole_number, "view_hole")

func _on_hole_deleted(hole_number: int) -> void:
	add_event(CAT_COURSE, PRIORITY_NORMAL,
		"Hole #%d removed" % hole_number)

func _on_building_placed(building_type: String, position: Vector2i) -> void:
	var display_name = building_type.capitalize().replace("_", " ")
	add_event(CAT_COURSE, PRIORITY_INFO,
		"%s placed" % display_name, position)

func _on_end_of_day(day_number: int) -> void:
	_generate_daily_summary(day_number)

func _on_new_game() -> void:
	clear()
	_last_bankruptcy_warning_day = -1

## Generate end-of-day summary event
func _generate_daily_summary(day_number: int) -> void:
	var stats = GameManager.daily_stats
	var satisfaction := 0.5
	if FeedbackManager:
		satisfaction = FeedbackManager.get_satisfaction_rating()

	var revenue = stats.get_total_revenue()
	var costs = stats.operating_costs
	var profit = stats.get_profit()
	var golfers = stats.golfers_served
	var stars = GameManager.course_rating.get("stars", 0)
	var overall = GameManager.course_rating.get("overall", 0.0)

	var star_str = ""
	for i in range(stars):
		star_str += "*"

	var lines: PackedStringArray = []
	lines.append("Day %d Summary" % day_number)
	lines.append("  Golfers served: %d" % golfers)
	lines.append("  Revenue: $%d | Costs: $%d | Profit: $%d" % [revenue, costs, profit])
	lines.append("  Satisfaction: %d%%" % int(satisfaction * 100))
	lines.append("  Rating: %s (%.1f)" % [star_str, overall])

	# Notable events
	if stats.holes_in_one > 0:
		lines.append("  Notable: %d hole-in-one(s)!" % stats.holes_in_one)
	if stats.eagles > 0:
		lines.append("  Notable: %d eagle(s)" % stats.eagles)

	add_event(CAT_DAILY, PRIORITY_NORMAL, "\n".join(lines))

# ─── Disconnect on exit ──────────────────────────────────────────

func _exit_tree() -> void:
	if EventBus.record_broken.is_connected(_on_record_broken):
		EventBus.record_broken.disconnect(_on_record_broken)
	if EventBus.money_changed.is_connected(_on_money_changed):
		EventBus.money_changed.disconnect(_on_money_changed)
	if EventBus.green_fee_changed.is_connected(_on_green_fee_changed):
		EventBus.green_fee_changed.disconnect(_on_green_fee_changed)
	if EventBus.course_rating_changed.is_connected(_on_course_rating_changed):
		EventBus.course_rating_changed.disconnect(_on_course_rating_changed)
	if EventBus.golfer_finished_round.is_connected(_on_golfer_finished_round):
		EventBus.golfer_finished_round.disconnect(_on_golfer_finished_round)
	if EventBus.weather_changed.is_connected(_on_weather_changed):
		EventBus.weather_changed.disconnect(_on_weather_changed)
	if EventBus.season_changed.is_connected(_on_season_changed):
		EventBus.season_changed.disconnect(_on_season_changed)
	if EventBus.tournament_scheduled.is_connected(_on_tournament_scheduled):
		EventBus.tournament_scheduled.disconnect(_on_tournament_scheduled)
	if EventBus.tournament_started.is_connected(_on_tournament_started):
		EventBus.tournament_started.disconnect(_on_tournament_started)
	if EventBus.tournament_completed.is_connected(_on_tournament_completed):
		EventBus.tournament_completed.disconnect(_on_tournament_completed)
	if EventBus.hole_created.is_connected(_on_hole_created):
		EventBus.hole_created.disconnect(_on_hole_created)
	if EventBus.hole_deleted.is_connected(_on_hole_deleted):
		EventBus.hole_deleted.disconnect(_on_hole_deleted)
	if EventBus.building_placed.is_connected(_on_building_placed):
		EventBus.building_placed.disconnect(_on_building_placed)
	if EventBus.end_of_day.is_connected(_on_end_of_day):
		EventBus.end_of_day.disconnect(_on_end_of_day)
	if EventBus.new_game_started.is_connected(_on_new_game):
		EventBus.new_game_started.disconnect(_on_new_game)


## EventEntry - A single event in the feed
class EventEntry extends RefCounted:
	var timestamp_day: int = 0
	var timestamp_hour: float = 0.0
	var category: String = ""
	var priority: int = 0
	var message: String = ""
	var icon: String = "[?]"
	var color: Color = Color.WHITE
	var navigate_target: Variant = null  # null, int (golfer_id/hole_number), Vector2i (position)
	var detail_action: String = ""       # "view_hole", "view_golfer", etc.

	func get_time_string() -> String:
		var hour_int = int(timestamp_hour)
		var minute_int = int((timestamp_hour - hour_int) * 60)
		var am_pm = "AM" if hour_int < 12 else "PM"
		var display_hour = hour_int % 12
		if display_hour == 0:
			display_hour = 12
		return "Day %d, %d:%02d %s" % [timestamp_day, display_hour, minute_int, am_pm]
