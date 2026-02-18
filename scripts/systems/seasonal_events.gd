extends RefCounted
class_name SeasonalEvents
## SeasonalEvents - Defines special events tied to the seasonal calendar
##
## Each season has themed events that affect gameplay, revenue, or golfer
## demand. Events trigger on specific days within each season.

class SeasonEvent:
	var id: String
	var name: String
	var description: String
	var season: int  # SeasonSystem.Season enum
	var day_in_season: int  # Which day of the season (1-7)
	var revenue_modifier: float = 1.0
	var spawn_modifier: float = 1.0
	var reputation_bonus: float = 0.0
	var duration_days: int = 1  # How many days the event lasts

	func _init(p_id: String, p_name: String, p_desc: String, p_season: int,
			p_day: int, p_revenue: float = 1.0, p_spawn: float = 1.0,
			p_rep: float = 0.0, p_duration: int = 1) -> void:
		id = p_id
		name = p_name
		description = p_desc
		season = p_season
		day_in_season = p_day
		revenue_modifier = p_revenue
		spawn_modifier = p_spawn
		reputation_bonus = p_rep
		duration_days = p_duration

static func get_all_events() -> Array:
	return [
		# Spring events
		SeasonEvent.new("spring_open", "Spring Opening Day",
			"Course opens for the season! Extra golfers flock in.",
			SeasonSystem.Season.SPRING, 1, 1.5, 1.5, 2.0),
		SeasonEvent.new("spring_charity", "Charity Scramble",
			"Local charity event boosts reputation.",
			SeasonSystem.Season.SPRING, 4, 1.2, 1.3, 3.0),

		# Summer events
		SeasonEvent.new("summer_peak", "Peak Season",
			"Highest demand of the year. Premium pricing accepted.",
			SeasonSystem.Season.SUMMER, 1, 1.5, 1.0, 0.0, 3),
		SeasonEvent.new("summer_junior", "Junior Golf Day",
			"Young golfers visit. High volume, lower fees.",
			SeasonSystem.Season.SUMMER, 5, 0.8, 1.8, 2.0),

		# Fall events
		SeasonEvent.new("fall_classic", "Fall Classic Invitational",
			"Prestigious amateur event. Serious golfers attend.",
			SeasonSystem.Season.FALL, 2, 1.3, 1.4, 5.0, 2),
		SeasonEvent.new("fall_twilight", "Twilight Golf Week",
			"End-of-season discounts drive high attendance.",
			SeasonSystem.Season.FALL, 6, 0.9, 1.6, 1.0),

		# Winter events
		SeasonEvent.new("winter_open", "Winter Open",
			"Hardy golfers brave the cold. Low demand but loyal visitors.",
			SeasonSystem.Season.WINTER, 3, 1.0, 0.8, 1.0),
		SeasonEvent.new("winter_maint", "Maintenance Week",
			"Course maintenance reduces play. Great time to build.",
			SeasonSystem.Season.WINTER, 6, 0.5, 0.3, 0.0),
	]

## Get the currently active event (if any) for the given game day
static func get_active_event(day: int) -> SeasonEvent:
	var season = SeasonSystem.get_season(day)
	var day_in_season = SeasonSystem.get_day_in_season(day)

	for event in get_all_events():
		if event.season == season:
			if day_in_season >= event.day_in_season and day_in_season < event.day_in_season + event.duration_days:
				return event
	return null

## Get upcoming events within the next N days
static func get_upcoming_events(current_day: int, look_ahead: int = 14) -> Array:
	var upcoming: Array = []
	for d in range(current_day + 1, current_day + look_ahead + 1):
		var event = get_active_event(d)
		if event and not _array_has_event(upcoming, event.id):
			upcoming.append({"event": event, "day": d, "days_until": d - current_day})
	return upcoming

static func _array_has_event(arr: Array, event_id: String) -> bool:
	for entry in arr:
		if entry.event.id == event_id:
			return true
	return false

## Get events for a specific season (for calendar display)
static func get_season_events(season: int) -> Array:
	var events: Array = []
	for event in get_all_events():
		if event.season == season:
			events.append(event)
	return events
