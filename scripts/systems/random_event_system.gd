extends Node
class_name RandomEventSystem
## RandomEventSystem - Generates random events that create narrative variety
##
## Triggers events at the start of each day during simulation. Events include
## weather disasters, equipment breakdowns, VIP visits, PR reviews, economic
## shifts, and sponsorship offers. Each event type has prerequisites, effects,
## and durations. Integrates with EventBus for UI notifications.

## Event categories
enum EventCategory {
	WEATHER_DISASTER,
	EQUIPMENT_BREAKDOWN,
	VIP_VISIT,
	PR_REVIEW,
	ECONOMIC,
	SPONSORSHIP,
	WILDLIFE,
}

## Event data structure
class RandomEvent:
	var id: String = ""
	var category: int = EventCategory.WEATHER_DISASTER
	var title: String = ""
	var description: String = ""
	var effects: Dictionary = {}  # {effect_type: value}
	var duration_days: int = 1
	var days_remaining: int = 0
	var day_started: int = 0
	var requires_response: bool = false  # If true, player must accept/decline
	var accepted: bool = false

	func is_active() -> bool:
		return days_remaining > 0

## All possible event definitions
const EVENT_DEFINITIONS: Array = [
	# --- Weather Disasters ---
	{
		"id": "lightning_strike",
		"category": EventCategory.WEATHER_DISASTER,
		"title": "Lightning Strike!",
		"description": "Lightning struck a building on the course! Repair costs incurred.",
		"effects": {"money": -2000, "condition_penalty": 0.1},
		"duration_days": 1,
		"weight": 1.0,
		"min_day": 5,
		"requires_weather": ["RAIN", "HEAVY_RAIN"],
	},
	{
		"id": "flooding",
		"category": EventCategory.WEATHER_DISASTER,
		"title": "Course Flooding",
		"description": "Heavy rain has flooded low-lying holes. Course condition reduced for 2 days.",
		"effects": {"condition_penalty": 0.25, "spawn_modifier": 0.6},
		"duration_days": 2,
		"weight": 0.8,
		"min_day": 3,
		"requires_weather": ["HEAVY_RAIN"],
	},
	{
		"id": "drought",
		"category": EventCategory.WEATHER_DISASTER,
		"title": "Drought Conditions",
		"description": "Extended dry spell is browning the fairways. Maintenance costs increased.",
		"effects": {"maintenance_multiplier": 1.5, "condition_penalty": 0.15},
		"duration_days": 3,
		"weight": 0.6,
		"min_day": 7,
		"requires_weather": ["SUNNY"],
		"requires_season": ["SUMMER"],
	},
	# --- Equipment Breakdowns ---
	{
		"id": "cart_breakdown",
		"category": EventCategory.EQUIPMENT_BREAKDOWN,
		"title": "Cart Shed Breakdown",
		"description": "Golf carts need emergency repairs. Repair bill incoming.",
		"effects": {"money": -1500},
		"duration_days": 1,
		"weight": 1.0,
		"min_day": 5,
		"requires_building": "cart_shed",
	},
	{
		"id": "irrigation_failure",
		"category": EventCategory.EQUIPMENT_BREAKDOWN,
		"title": "Irrigation System Failure",
		"description": "Sprinkler system malfunction! Greens condition deteriorating until fixed.",
		"effects": {"money": -3000, "condition_penalty": 0.2},
		"duration_days": 2,
		"weight": 0.7,
		"min_day": 10,
	},
	{
		"id": "range_nets_torn",
		"category": EventCategory.EQUIPMENT_BREAKDOWN,
		"title": "Driving Range Nets Torn",
		"description": "Driving range nets need replacement. Range closed for repairs.",
		"effects": {"money": -1000},
		"duration_days": 1,
		"weight": 0.8,
		"min_day": 7,
		"requires_building": "driving_range",
	},
	# --- VIP Visits ---
	{
		"id": "celebrity_golfer",
		"category": EventCategory.VIP_VISIT,
		"title": "Celebrity Golfer Visit!",
		"description": "A famous golfer wants to play your course! Great play = huge reputation boost.",
		"effects": {"pro_spawn_boost": 2.0, "reputation_bonus": 5.0},
		"duration_days": 1,
		"weight": 0.5,
		"min_day": 14,
		"min_rating": 3.0,
	},
	{
		"id": "corporate_outing",
		"category": EventCategory.VIP_VISIT,
		"title": "Corporate Outing Booked",
		"description": "A company booked a full-day corporate outing. Big payday!",
		"effects": {"money": 5000, "spawn_modifier": 1.5},
		"duration_days": 1,
		"weight": 0.8,
		"min_day": 7,
		"min_holes": 9,
	},
	# --- PR Events ---
	{
		"id": "magazine_review_good",
		"category": EventCategory.PR_REVIEW,
		"title": "Golf Magazine Review!",
		"description": "A golf magazine is reviewing your course. High rating attracts more pros!",
		"effects": {"pro_spawn_boost": 1.5, "reputation_bonus": 3.0},
		"duration_days": 3,
		"weight": 0.6,
		"min_day": 14,
		"min_rating": 3.5,
	},
	{
		"id": "magazine_review_bad",
		"category": EventCategory.PR_REVIEW,
		"title": "Negative Press Coverage",
		"description": "A local paper published a critical review. Fewer golfers expected this week.",
		"effects": {"spawn_modifier": 0.7, "reputation_penalty": 3.0},
		"duration_days": 3,
		"weight": 0.4,
		"min_day": 10,
		"max_rating": 2.5,
	},
	{
		"id": "social_media_viral",
		"category": EventCategory.PR_REVIEW,
		"title": "Viral Social Media Post!",
		"description": "A golfer's post about your course went viral! Massive interest spike.",
		"effects": {"spawn_modifier": 2.0, "reputation_bonus": 2.0},
		"duration_days": 2,
		"weight": 0.3,
		"min_day": 7,
		"min_rating": 3.0,
	},
	# --- Economic Events ---
	{
		"id": "local_recession",
		"category": EventCategory.ECONOMIC,
		"title": "Local Economic Downturn",
		"description": "The local economy is struggling. Fewer golfers and tighter budgets.",
		"effects": {"spawn_modifier": 0.7, "beginner_bias": 1.5},
		"duration_days": 7,
		"weight": 0.3,
		"min_day": 14,
	},
	{
		"id": "golf_boom",
		"category": EventCategory.ECONOMIC,
		"title": "Golf Popularity Surge!",
		"description": "Golf is trending! More people want to play.",
		"effects": {"spawn_modifier": 1.5, "reputation_bonus": 1.0},
		"duration_days": 5,
		"weight": 0.3,
		"min_day": 14,
	},
	{
		"id": "supply_cost_spike",
		"category": EventCategory.ECONOMIC,
		"title": "Supply Cost Increase",
		"description": "Equipment and supply costs have risen across the industry.",
		"effects": {"maintenance_multiplier": 1.3},
		"duration_days": 5,
		"weight": 0.4,
		"min_day": 10,
	},
	# --- Sponsorship Offers ---
	{
		"id": "hole_sponsorship",
		"category": EventCategory.SPONSORSHIP,
		"title": "Hole Sponsorship Offer",
		"description": "A company wants to sponsor a hole on your course for $3,000!",
		"effects": {"money": 3000},
		"duration_days": 1,
		"weight": 0.5,
		"min_day": 14,
		"min_holes": 9,
	},
	{
		"id": "tournament_sponsor",
		"category": EventCategory.SPONSORSHIP,
		"title": "Tournament Sponsor Found",
		"description": "A sponsor will cover your next tournament's prize pool — $5,000 bonus!",
		"effects": {"money": 5000, "reputation_bonus": 2.0},
		"duration_days": 1,
		"weight": 0.3,
		"min_day": 21,
		"min_rating": 3.5,
	},
	# --- Wildlife/Pest Events ---
	{
		"id": "geese_invasion",
		"category": EventCategory.WILDLIFE,
		"title": "Geese on the Greens!",
		"description": "A flock of geese has taken over the greens. Golfer satisfaction reduced.",
		"effects": {"satisfaction_penalty": 0.15},
		"duration_days": 2,
		"weight": 0.7,
		"min_day": 5,
	},
	{
		"id": "mole_damage",
		"category": EventCategory.WILDLIFE,
		"title": "Mole Damage",
		"description": "Moles are tearing up the fairways! Condition dropping until dealt with.",
		"effects": {"condition_penalty": 0.2, "money": -500},
		"duration_days": 3,
		"weight": 0.5,
		"min_day": 7,
	},
]

## Active events currently affecting the course
var active_events: Array = []  # Array of RandomEvent

## Event history for tracking (prevents repeat events)
var _recent_event_ids: Array = []  # Last N event IDs to avoid repeats
const MAX_RECENT_HISTORY: int = 10

## Daily roll chance (base probability that any event occurs on a given day)
const BASE_EVENT_CHANCE: float = 0.35  # 35% chance per day
const MAX_ACTIVE_EVENTS: int = 3  # Don't overwhelm the player

## Track consecutive no-event days to increase probability
var _days_without_event: int = 0

signal event_started(event: RandomEvent)
signal event_ended(event: RandomEvent)

func _ready() -> void:
	EventBus.day_changed.connect(_on_day_changed)
	EventBus.end_of_day.connect(_on_end_of_day)

func _exit_tree() -> void:
	if EventBus.day_changed.is_connected(_on_day_changed):
		EventBus.day_changed.disconnect(_on_day_changed)
	if EventBus.end_of_day.is_connected(_on_end_of_day):
		EventBus.end_of_day.disconnect(_on_end_of_day)

func _on_day_changed(_new_day: int) -> void:
	_tick_active_events()
	_try_generate_event()

func _on_end_of_day(_day_number: int) -> void:
	# Apply end-of-day effects for active events (reputation changes, etc.)
	for event in active_events:
		_apply_daily_effects(event)

## Tick down active event durations and remove expired ones
func _tick_active_events() -> void:
	var expired: Array = []
	for event in active_events:
		event.days_remaining -= 1
		if event.days_remaining <= 0:
			expired.append(event)

	for event in expired:
		active_events.erase(event)
		_on_event_expired(event)

## Try to generate a random event for today
func _try_generate_event() -> void:
	if active_events.size() >= MAX_ACTIVE_EVENTS:
		return

	# Increase chance if nothing has happened recently (pity timer)
	var effective_chance = BASE_EVENT_CHANCE + (_days_without_event * 0.08)
	effective_chance = minf(effective_chance, 0.8)

	if randf() > effective_chance:
		_days_without_event += 1
		return

	# Collect eligible events
	var eligible = _get_eligible_events()
	if eligible.is_empty():
		_days_without_event += 1
		return

	# Weighted random selection
	var selected = _weighted_random_select(eligible)
	if selected:
		_trigger_event(selected)
		_days_without_event = 0

## Get events that meet all prerequisites
func _get_eligible_events() -> Array:
	var eligible: Array = []
	var current_day = GameManager.current_day
	var rating = GameManager.course_rating.get("overall", 3.0)
	var hole_count = GameManager.get_open_hole_count()

	for definition in EVENT_DEFINITIONS:
		var id = definition.get("id", "")

		# Skip recently occurred events
		if id in _recent_event_ids:
			continue

		# Skip if already an active event of same category
		var category = definition.get("category", -1)
		var category_active = false
		for active in active_events:
			if active.category == category:
				category_active = true
				break
		if category_active:
			continue

		# Check minimum day requirement
		if current_day < definition.get("min_day", 1):
			continue

		# Check minimum rating requirement
		if definition.has("min_rating") and rating < definition.get("min_rating"):
			continue

		# Check maximum rating requirement (for negative events)
		if definition.has("max_rating") and rating > definition.get("max_rating"):
			continue

		# Check minimum holes requirement
		if definition.has("min_holes") and hole_count < definition.get("min_holes"):
			continue

		# Check weather requirement
		if definition.has("requires_weather"):
			var current_weather = _get_current_weather_name()
			if current_weather not in definition.get("requires_weather"):
				continue

		# Check season requirement
		if definition.has("requires_season"):
			var current_season = SeasonSystem.get_season_name(SeasonSystem.get_season(current_day))
			if current_season.to_upper() not in definition.get("requires_season"):
				continue

		# Check building requirement
		if definition.has("requires_building"):
			if not _has_building(definition.get("requires_building")):
				continue

		eligible.append(definition)

	return eligible

## Weighted random selection from eligible events
func _weighted_random_select(eligible: Array) -> Dictionary:
	var total_weight: float = 0.0
	for def in eligible:
		total_weight += def.get("weight", 1.0)

	if total_weight <= 0.0:
		return {}

	var roll = randf() * total_weight
	var cumulative: float = 0.0
	for def in eligible:
		cumulative += def.get("weight", 1.0)
		if roll <= cumulative:
			return def

	return eligible.back() if not eligible.is_empty() else {}

## Create and activate a new event from a definition
func _trigger_event(definition: Dictionary) -> void:
	var event = RandomEvent.new()
	event.id = definition.get("id", "unknown")
	event.category = definition.get("category", EventCategory.WEATHER_DISASTER)
	event.title = definition.get("title", "Unknown Event")
	event.description = definition.get("description", "")
	event.effects = definition.get("effects", {})
	event.duration_days = definition.get("duration_days", 1)
	event.days_remaining = event.duration_days
	event.day_started = GameManager.current_day

	active_events.append(event)

	# Track in recent history to prevent repeats
	_recent_event_ids.append(event.id)
	while _recent_event_ids.size() > MAX_RECENT_HISTORY:
		_recent_event_ids.pop_front()

	# Apply immediate effects
	_apply_immediate_effects(event)

	# Notify via EventBus
	var notification_type = _get_notification_type(event)
	EventBus.notify("%s — %s" % [event.title, event.description], notification_type)
	EventBus.random_event_started.emit(event.id, event.title, event.category)

	event_started.emit(event)

## Apply one-time effects when event triggers
func _apply_immediate_effects(event: RandomEvent) -> void:
	var effects = event.effects

	# Immediate money change
	if effects.has("money"):
		var amount = int(effects["money"])
		GameManager.modify_money(amount)
		var desc = event.title
		EventBus.log_transaction(desc, amount)

	# Immediate reputation bonus
	if effects.has("reputation_bonus"):
		GameManager.modify_reputation(float(effects["reputation_bonus"]))

	# Immediate reputation penalty
	if effects.has("reputation_penalty"):
		GameManager.modify_reputation(-float(effects["reputation_penalty"]))

## Apply recurring daily effects for multi-day events
func _apply_daily_effects(event: RandomEvent) -> void:
	var effects = event.effects

	# Daily satisfaction penalty persists via get_satisfaction_modifier()
	# Daily spawn modifier persists via get_spawn_rate_modifier()
	# Daily maintenance multiplier persists via get_maintenance_multiplier()
	# These are queried by other systems each frame/tick — no daily action needed.

	# Ongoing reputation effects (smaller daily dose for multi-day events)
	if event.duration_days > 1:
		if effects.has("reputation_bonus"):
			var daily_rep = float(effects["reputation_bonus"]) / float(event.duration_days)
			GameManager.modify_reputation(daily_rep)
		if effects.has("reputation_penalty"):
			var daily_rep = float(effects["reputation_penalty"]) / float(event.duration_days)
			GameManager.modify_reputation(-daily_rep)

## Handle event expiration
func _on_event_expired(event: RandomEvent) -> void:
	EventBus.notify("%s has ended." % event.title, "info")
	EventBus.random_event_ended.emit(event.id, event.title)
	event_ended.emit(event)

## --- Modifier queries used by other systems ---

## Get combined spawn rate modifier from all active events
func get_spawn_rate_modifier() -> float:
	var modifier: float = 1.0
	for event in active_events:
		if event.effects.has("spawn_modifier"):
			modifier *= float(event.effects["spawn_modifier"])
		if event.effects.has("pro_spawn_boost"):
			# Pro spawn boost slightly increases overall spawns too
			modifier *= 1.0 + (float(event.effects["pro_spawn_boost"]) - 1.0) * 0.3
	return modifier

## Get combined maintenance cost multiplier from all active events
func get_maintenance_multiplier() -> float:
	var modifier: float = 1.0
	for event in active_events:
		if event.effects.has("maintenance_multiplier"):
			modifier *= float(event.effects["maintenance_multiplier"])
	return modifier

## Get combined satisfaction modifier from all active events
func get_satisfaction_modifier() -> float:
	var penalty: float = 0.0
	for event in active_events:
		if event.effects.has("satisfaction_penalty"):
			penalty += float(event.effects["satisfaction_penalty"])
	return clampf(1.0 - penalty, 0.5, 1.0)

## Get combined condition penalty from all active events
func get_condition_penalty() -> float:
	var penalty: float = 0.0
	for event in active_events:
		if event.effects.has("condition_penalty"):
			penalty += float(event.effects["condition_penalty"])
	return clampf(penalty, 0.0, 0.5)

## Check if any VIP event is active (for special golfer spawning)
func has_vip_event() -> bool:
	for event in active_events:
		if event.category == EventCategory.VIP_VISIT:
			return true
	return false

## Get the pro spawn boost multiplier (for tier distribution)
func get_pro_spawn_boost() -> float:
	var boost: float = 1.0
	for event in active_events:
		if event.effects.has("pro_spawn_boost"):
			boost = maxf(boost, float(event.effects["pro_spawn_boost"]))
	return boost

## --- Helpers ---

func _get_current_weather_name() -> String:
	if not GameManager.weather_system:
		return "SUNNY"
	match GameManager.weather_system.weather_type:
		WeatherSystem.WeatherType.SUNNY: return "SUNNY"
		WeatherSystem.WeatherType.PARTLY_CLOUDY: return "PARTLY_CLOUDY"
		WeatherSystem.WeatherType.CLOUDY: return "CLOUDY"
		WeatherSystem.WeatherType.LIGHT_RAIN: return "LIGHT_RAIN"
		WeatherSystem.WeatherType.RAIN: return "RAIN"
		WeatherSystem.WeatherType.HEAVY_RAIN: return "HEAVY_RAIN"
	return "SUNNY"

func _has_building(building_type: String) -> bool:
	if not GameManager.entity_layer:
		return false
	var buildings = GameManager.entity_layer.get_all_buildings()
	for building in buildings:
		if building.building_type == building_type:
			return true
	return false

func _get_notification_type(event: RandomEvent) -> String:
	match event.category:
		EventCategory.WEATHER_DISASTER, EventCategory.EQUIPMENT_BREAKDOWN:
			return "warning"
		EventCategory.VIP_VISIT, EventCategory.SPONSORSHIP:
			return "success"
		EventCategory.PR_REVIEW:
			if event.effects.has("reputation_bonus"):
				return "success"
			return "warning"
		EventCategory.ECONOMIC:
			if event.effects.has("spawn_modifier") and float(event.effects["spawn_modifier"]) < 1.0:
				return "warning"
			return "info"
		EventCategory.WILDLIFE:
			return "warning"
	return "info"

## --- Serialization ---

func serialize() -> Dictionary:
	var events_data: Array = []
	for event in active_events:
		events_data.append({
			"id": event.id,
			"category": event.category,
			"title": event.title,
			"description": event.description,
			"effects": event.effects,
			"duration_days": event.duration_days,
			"days_remaining": event.days_remaining,
			"day_started": event.day_started,
		})
	return {
		"active_events": events_data,
		"recent_event_ids": _recent_event_ids.duplicate(),
		"days_without_event": _days_without_event,
	}

func deserialize(data: Dictionary) -> void:
	active_events.clear()
	_recent_event_ids.clear()

	var events_data = data.get("active_events", [])
	for event_data in events_data:
		var event = RandomEvent.new()
		event.id = event_data.get("id", "")
		event.category = int(event_data.get("category", 0))
		event.title = event_data.get("title", "")
		event.description = event_data.get("description", "")
		event.effects = event_data.get("effects", {})
		event.duration_days = int(event_data.get("duration_days", 1))
		event.days_remaining = int(event_data.get("days_remaining", 0))
		event.day_started = int(event_data.get("day_started", 0))
		active_events.append(event)

	_recent_event_ids = data.get("recent_event_ids", [])
	_days_without_event = int(data.get("days_without_event", 0))

## Get a summary of active events for UI display
func get_active_event_summaries() -> Array:
	var summaries: Array = []
	for event in active_events:
		summaries.append({
			"title": event.title,
			"description": event.description,
			"days_remaining": event.days_remaining,
			"category": event.category,
		})
	return summaries
