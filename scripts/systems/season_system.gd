extends RefCounted
class_name SeasonSystem
## SeasonSystem - Static class for seasonal calendar and modifiers.
## Season is derived from GameManager.current_day — no stored state.
## 28-day year: Spring (1-7), Summer (8-14), Fall (15-21), Winter (22-28).

enum Season { SPRING, SUMMER, FALL, WINTER }

const DAYS_PER_SEASON: int = 7
const DAYS_PER_YEAR: int = 28

static func get_season(day: int) -> int:
	var day_in_year = (day - 1) % DAYS_PER_YEAR
	return int(day_in_year / DAYS_PER_SEASON)

static func get_day_in_season(day: int) -> int:
	return ((day - 1) % DAYS_PER_SEASON) + 1

static func get_year(day: int) -> int:
	return ((day - 1) / DAYS_PER_YEAR) + 1

static func get_season_name(season: int) -> String:
	match season:
		Season.SPRING: return "Spring"
		Season.SUMMER: return "Summer"
		Season.FALL: return "Fall"
		Season.WINTER: return "Winter"
	return "Unknown"

## Golfer demand multiplier by season
static func get_spawn_modifier(season: int) -> float:
	match season:
		Season.SPRING: return 0.9
		Season.SUMMER: return 1.4
		Season.FALL: return 0.8
		Season.WINTER: return 0.3
	return 1.0

## Maintenance cost multiplier by season
## Summer is expensive (watering), Fall is cheapest (winterizing)
static func get_maintenance_modifier(season: int) -> float:
	match season:
		Season.SPRING: return 1.1
		Season.SUMMER: return 1.4
		Season.FALL: return 0.7
		Season.WINTER: return 1.1
	return 1.0

## Cumulative weather probability thresholds per season
## Order: [SUNNY, PARTLY_CLOUDY, CLOUDY, LIGHT_RAIN, RAIN, HEAVY_RAIN]
static func get_weather_weights(season: int) -> Array:
	match season:
		Season.SPRING:
			return [0.25, 0.50, 0.65, 0.80, 0.93, 1.0]
		Season.SUMMER:
			return [0.55, 0.80, 0.90, 0.95, 0.98, 1.0]
		Season.FALL:
			return [0.30, 0.55, 0.75, 0.88, 0.96, 1.0]
		Season.WINTER:
			return [0.15, 0.35, 0.60, 0.78, 0.92, 1.0]
	return [0.40, 0.70, 0.85, 0.93, 0.98, 1.0]

static func get_season_color(season: int) -> Color:
	match season:
		Season.SPRING: return Color(0.4, 0.8, 0.4)
		Season.SUMMER: return Color(0.9, 0.85, 0.3)
		Season.FALL: return Color(0.85, 0.55, 0.25)
		Season.WINTER: return Color(0.6, 0.7, 0.85)
	return Color.WHITE
