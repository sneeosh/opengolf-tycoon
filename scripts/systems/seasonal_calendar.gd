extends RefCounted
class_name SeasonalCalendar
## SeasonalCalendar - 360-day year with 4 seasons, holidays, and seasonal modifiers
##
## 360-day year: 4 seasons x 90 days each
## 12 months of 30 days (3 months per season)
## Integrates with WeatherSystem, GolferManager, and maintenance costs

enum Season { SPRING, SUMMER, FALL, WINTER }

const DAYS_PER_SEASON: int = 90
const DAYS_PER_MONTH: int = 30
const DAYS_PER_YEAR: int = 360
const MONTHS_PER_SEASON: int = 3

const SEASON_NAMES: Array = ["Spring", "Summer", "Fall", "Winter"]
const MONTH_NAMES: Array = [
	"March", "April", "May",        # Spring
	"June", "July", "August",       # Summer
	"September", "October", "November",  # Fall
	"December", "January", "February"    # Winter
]

## Per-season weather probability tables
## [SUNNY, PARTLY_CLOUDY, CLOUDY, LIGHT_RAIN, RAIN, HEAVY_RAIN]
const WEATHER_PROBABILITIES = {
	Season.SPRING: [0.25, 0.25, 0.20, 0.15, 0.10, 0.05],
	Season.SUMMER: [0.45, 0.25, 0.15, 0.08, 0.05, 0.02],
	Season.FALL:   [0.30, 0.25, 0.25, 0.12, 0.06, 0.02],
	Season.WINTER: [0.20, 0.20, 0.30, 0.15, 0.10, 0.05],
}

## Per-season golfer spawn rate multipliers
const SPAWN_MULTIPLIERS = {
	Season.SPRING: 0.85,   # Warming up, still cool mornings
	Season.SUMMER: 1.2,    # Peak golf season
	Season.FALL:   0.90,   # Cooling down, leaves
	Season.WINTER: 0.50,   # Off-season, much fewer golfers
}

## Per-season maintenance cost multipliers
const MAINTENANCE_MULTIPLIERS = {
	Season.SPRING: 1.2,    # Aeration, overseeding, spring prep
	Season.SUMMER: 1.0,    # Normal maintenance
	Season.FALL:   1.1,    # Leaf cleanup, winterizing
	Season.WINTER: 0.7,    # Reduced maintenance needs
}

## Per-season green fee tolerance (how much players accept above/below base fee)
const GREEN_FEE_TOLERANCE = {
	Season.SPRING: 1.0,    # Normal tolerance
	Season.SUMMER: 1.15,   # Willing to pay more in peak season
	Season.FALL:   0.95,   # Slightly less tolerant
	Season.WINTER: 0.75,   # Much more price-sensitive
}

## Holiday events: {day_of_year, name, duration_days, spawn_bonus, fee_tolerance}
const HOLIDAYS: Array = [
	{"day": 1, "name": "Opening Day", "duration": 3, "spawn_bonus": 1.5, "fee_tolerance": 1.1},
	{"day": 45, "name": "Spring Classic", "duration": 2, "spawn_bonus": 1.8, "fee_tolerance": 1.2},
	{"day": 90, "name": "Summer Kickoff", "duration": 3, "spawn_bonus": 2.0, "fee_tolerance": 1.3},
	{"day": 135, "name": "Midsummer Invitational", "duration": 2, "spawn_bonus": 1.6, "fee_tolerance": 1.2},
	{"day": 180, "name": "Labor Day Weekend", "duration": 3, "spawn_bonus": 2.0, "fee_tolerance": 1.3},
	{"day": 225, "name": "Fall Festival", "duration": 2, "spawn_bonus": 1.4, "fee_tolerance": 1.0},
	{"day": 270, "name": "Winter Open", "duration": 2, "spawn_bonus": 1.3, "fee_tolerance": 0.9},
	{"day": 340, "name": "Season Finale", "duration": 3, "spawn_bonus": 1.7, "fee_tolerance": 1.1},
]

## Calculate the season from a game day number (1-based)
static func get_season(day: int) -> int:
	var day_of_year = (day - 1) % DAYS_PER_YEAR
	@warning_ignore("integer_division")
	return clampi(day_of_year / DAYS_PER_SEASON, 0, 3)

## Get the day within the current season (0-89)
static func get_day_in_season(day: int) -> int:
	var day_of_year = (day - 1) % DAYS_PER_YEAR
	return day_of_year % DAYS_PER_SEASON

## Get the month index (0-11)
static func get_month(day: int) -> int:
	var day_of_year = (day - 1) % DAYS_PER_YEAR
	@warning_ignore("integer_division")
	return clampi(day_of_year / DAYS_PER_MONTH, 0, 11)

## Get the day within the current month (1-30)
static func get_day_in_month(day: int) -> int:
	var day_of_year = (day - 1) % DAYS_PER_YEAR
	return (day_of_year % DAYS_PER_MONTH) + 1

## Get the year number (1-based)
static func get_year(day: int) -> int:
	@warning_ignore("integer_division")
	return ((day - 1) / DAYS_PER_YEAR) + 1

## Get season name
static func get_season_name(day: int) -> String:
	return SEASON_NAMES[get_season(day)]

## Get month name
static func get_month_name(day: int) -> String:
	return MONTH_NAMES[get_month(day)]

## Format a full date string
static func get_date_string(day: int) -> String:
	return "%s %d, Year %d" % [get_month_name(day), get_day_in_month(day), get_year(day)]

## Get short date
static func get_short_date(day: int) -> String:
	return "%s %d" % [get_month_name(day), get_day_in_month(day)]

## Get weather probability table for the current season
static func get_weather_probabilities(day: int) -> Array:
	var season = get_season(day)
	return WEATHER_PROBABILITIES[season]

## Get spawn rate multiplier for the current season
static func get_spawn_multiplier(day: int) -> float:
	return SPAWN_MULTIPLIERS[get_season(day)]

## Get maintenance cost multiplier for the current season
static func get_maintenance_multiplier(day: int) -> float:
	return MAINTENANCE_MULTIPLIERS[get_season(day)]

## Get green fee tolerance for the current season
static func get_fee_tolerance(day: int) -> float:
	return GREEN_FEE_TOLERANCE[get_season(day)]

## Check if a holiday is active on the given day
static func get_active_holiday(day: int) -> Dictionary:
	var day_of_year = (day - 1) % DAYS_PER_YEAR
	for holiday in HOLIDAYS:
		if day_of_year >= holiday.day and day_of_year < holiday.day + holiday.duration:
			return holiday
	return {}

## Get upcoming holidays within the next N days
static func get_upcoming_holidays(day: int, lookahead: int = 30) -> Array:
	var result: Array = []
	var day_of_year = (day - 1) % DAYS_PER_YEAR
	for holiday in HOLIDAYS:
		var days_until = holiday.day - day_of_year
		if days_until < 0:
			days_until += DAYS_PER_YEAR
		if days_until <= lookahead and days_until > 0:
			var entry = holiday.duplicate()
			entry["days_until"] = days_until
			result.append(entry)
	result.sort_custom(func(a, b): return a.days_until < b.days_until)
	return result

## Get the combined spawn modifier (season + holiday)
static func get_total_spawn_modifier(day: int) -> float:
	var seasonal = get_spawn_multiplier(day)
	var holiday = get_active_holiday(day)
	if not holiday.is_empty():
		return seasonal * holiday.spawn_bonus
	return seasonal

## Get the combined fee tolerance (season + holiday)
static func get_total_fee_tolerance(day: int) -> float:
	var seasonal = get_fee_tolerance(day)
	var holiday = get_active_holiday(day)
	if not holiday.is_empty():
		return seasonal * holiday.fee_tolerance
	return seasonal

## Get a season color for UI display
static func get_season_color(season: int) -> Color:
	match season:
		Season.SPRING:
			return Color(0.5, 0.85, 0.4)   # Fresh green
		Season.SUMMER:
			return Color(1.0, 0.85, 0.3)   # Warm gold
		Season.FALL:
			return Color(0.9, 0.55, 0.2)   # Autumn orange
		Season.WINTER:
			return Color(0.6, 0.75, 0.95)  # Cool blue
	return Color.WHITE
