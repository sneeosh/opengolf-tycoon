extends RefCounted
class_name SeasonSystem
## SeasonSystem - Static class for seasonal calendar and modifiers.
## Season is derived from GameManager.current_day — no stored state.
## 28-day year: Spring (1-7), Summer (8-14), Fall (15-21), Winter (22-28).
##
## Theme-aware: Modifier tables vary per CourseTheme.Type so Desert courses
## peak in winter while Mountain courses peak in summer.

enum Season { SPRING, SUMMER, FALL, WINTER }

const DAYS_PER_SEASON: int = 7
const DAYS_PER_YEAR: int = 28

## Theme-aware spawn rate modifier tables (theme -> {season -> modifier}).
## Fallback row (PARKLAND) matches the original global values.
const THEME_SPAWN_MODIFIERS: Dictionary = {
	0:  {0: 0.9, 1: 1.4, 2: 0.8, 3: 0.3},  # PARKLAND
	1:  {0: 0.6, 1: 0.3, 2: 0.9, 3: 1.4},  # DESERT  (inverted peak)
	2:  {0: 0.8, 1: 1.3, 2: 0.9, 3: 0.4},  # LINKS
	3:  {0: 1.0, 1: 1.5, 2: 0.7, 3: 0.1},  # MOUNTAIN
	4:  {0: 0.9, 1: 1.2, 2: 1.0, 3: 0.6},  # CITY    (stable year-round)
	5:  {0: 1.0, 1: 1.3, 2: 0.8, 3: 1.2},  # RESORT  (dual peak)
	6:  {0: 0.8, 1: 1.3, 2: 0.9, 3: 0.3},  # HEATHLAND
	7:  {0: 1.0, 1: 1.4, 2: 1.1, 3: 0.2},  # WOODLAND (fall foliage boost)
	8:  {0: 1.1, 1: 0.8, 2: 1.2, 3: 1.3},  # TROPICAL (inverted peak)
	9:  {0: 0.7, 1: 0.9, 2: 0.8, 3: 0.4},  # MARSHLAND
}

## Theme-aware maintenance cost modifier tables.
const THEME_MAINTENANCE_MODIFIERS: Dictionary = {
	0:  {0: 1.1, 1: 1.4, 2: 0.7, 3: 1.1},  # PARKLAND
	1:  {0: 0.8, 1: 0.6, 2: 0.8, 3: 1.0},  # DESERT  (low year-round)
	2:  {0: 1.0, 1: 1.1, 2: 0.8, 3: 1.3},  # LINKS   (winter wind damage)
	3:  {0: 1.2, 1: 1.3, 2: 0.8, 3: 1.5},  # MOUNTAIN (costly winters)
	4:  {0: 1.0, 1: 1.2, 2: 0.9, 3: 1.0},  # CITY
	5:  {0: 1.1, 1: 1.3, 2: 0.9, 3: 1.2},  # RESORT
	6:  {0: 0.9, 1: 1.1, 2: 0.8, 3: 1.0},  # HEATHLAND
	7:  {0: 1.0, 1: 1.2, 2: 1.0, 3: 0.9},  # WOODLAND
	8:  {0: 1.3, 1: 1.5, 2: 1.1, 3: 0.9},  # TROPICAL (summer growth)
	9:  {0: 1.2, 1: 1.4, 2: 0.9, 3: 1.0},  # MARSHLAND
}

## Tournament prestige multipliers per theme × season.
## Higher prestige seasons reward more reputation for hosting tournaments.
const THEME_TOURNAMENT_PRESTIGE: Dictionary = {
	0:  {0: 1.0, 1: 1.0, 2: 1.2, 3: 0.5},  # PARKLAND  (fall classic)
	1:  {0: 0.8, 1: 0.5, 2: 1.2, 3: 1.0},  # DESERT    (fall/winter)
	2:  {0: 0.8, 1: 1.2, 2: 1.0, 3: 0.5},  # LINKS     (summer Open)
	3:  {0: 1.0, 1: 1.2, 2: 0.8, 3: 0.5},  # MOUNTAIN
	4:  {0: 1.0, 1: 1.0, 2: 1.2, 3: 0.8},  # CITY      (no deep off-season)
	5:  {0: 0.8, 1: 1.0, 2: 1.0, 3: 1.2},  # RESORT    (winter prestige)
	6:  {0: 0.8, 1: 1.2, 2: 1.0, 3: 0.5},  # HEATHLAND
	7:  {0: 1.0, 1: 1.0, 2: 1.2, 3: 0.5},  # WOODLAND  (fall classic)
	8:  {0: 0.8, 1: 0.5, 2: 1.0, 3: 1.2},  # TROPICAL  (winter prestige)
	9:  {0: 0.8, 1: 0.8, 2: 1.2, 3: 0.5},  # MARSHLAND (fall classic)
}

## Theme weather modifiers: {theme -> {wind_modifier, rain_modifier}}
## Applied on top of base seasonal weather tables.
const THEME_WEATHER_MODIFIERS: Dictionary = {
	0:  {"wind": 1.0, "rain": 1.0},  # PARKLAND  (standard)
	1:  {"wind": 0.8, "rain": 0.3},  # DESERT    (dry, moderate wind)
	2:  {"wind": 1.5, "rain": 1.2},  # LINKS     (windy, frequent rain)
	3:  {"wind": 1.2, "rain": 1.3},  # MOUNTAIN  (variable, more precip)
	4:  {"wind": 1.0, "rain": 1.0},  # CITY      (standard)
	5:  {"wind": 1.0, "rain": 1.0},  # RESORT    (standard)
	6:  {"wind": 1.0, "rain": 1.0},  # HEATHLAND (standard)
	7:  {"wind": 1.0, "rain": 1.0},  # WOODLAND  (standard)
	8:  {"wind": 0.7, "rain": 1.8},  # TROPICAL  (calm but very rainy)
	9:  {"wind": 0.9, "rain": 1.4},  # MARSHLAND (damp, frequent rain)
}

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

## Golfer demand multiplier by season, optionally theme-aware.
## When theme is provided, returns theme-specific modifier. Otherwise falls back
## to PARKLAND (the original global values).
static func get_spawn_modifier(season: int, theme: int = -1) -> float:
	var t = theme if theme >= 0 else 0  # Default to PARKLAND
	if THEME_SPAWN_MODIFIERS.has(t):
		return THEME_SPAWN_MODIFIERS[t].get(season, 1.0)
	return THEME_SPAWN_MODIFIERS[0].get(season, 1.0)

## Maintenance cost multiplier by season, optionally theme-aware.
static func get_maintenance_modifier(season: int, theme: int = -1) -> float:
	var t = theme if theme >= 0 else 0
	if THEME_MAINTENANCE_MODIFIERS.has(t):
		return THEME_MAINTENANCE_MODIFIERS[t].get(season, 1.0)
	return THEME_MAINTENANCE_MODIFIERS[0].get(season, 1.0)

## Blended spawn modifier with 2-day gradual transition at season boundaries.
## Day 7 of current season: 66% current + 34% next.
## Day 1 of next season: 34% previous + 66% current.
static func get_blended_spawn_modifier(day: int, theme: int = -1) -> float:
	var season = get_season(day)
	var day_in_season = get_day_in_season(day)
	var current_mod = get_spawn_modifier(season, theme)

	if day_in_season == DAYS_PER_SEASON:
		var next_season = (season + 1) % 4
		var next_mod = get_spawn_modifier(next_season, theme)
		return lerpf(current_mod, next_mod, 0.34)

	if day_in_season == 1:
		var prev_season = (season + 3) % 4
		var prev_mod = get_spawn_modifier(prev_season, theme)
		return lerpf(current_mod, prev_mod, 0.34)

	return current_mod

## Blended maintenance modifier with 2-day gradual transition.
static func get_blended_maintenance_modifier(day: int, theme: int = -1) -> float:
	var season = get_season(day)
	var day_in_season = get_day_in_season(day)
	var current_mod = get_maintenance_modifier(season, theme)

	if day_in_season == DAYS_PER_SEASON:
		var next_season = (season + 1) % 4
		var next_mod = get_maintenance_modifier(next_season, theme)
		return lerpf(current_mod, next_mod, 0.34)

	if day_in_season == 1:
		var prev_season = (season + 3) % 4
		var prev_mod = get_maintenance_modifier(prev_season, theme)
		return lerpf(current_mod, prev_mod, 0.34)

	return current_mod

## Green fee tolerance — how willing golfers are to pay premium pricing.
## Peak-season golfers accept 30% higher fees; off-season golfers expect discounts.
## Maps spawn modifier (demand proxy) to a 0.7–1.3 tolerance range.
static func get_fee_tolerance(day: int, theme: int = -1) -> float:
	var spawn_mod = get_blended_spawn_modifier(day, theme)
	return clampf(0.5 + spawn_mod * 0.55, 0.7, 1.3)

## Tournament prestige modifier — reputation reward scales by season.
static func get_tournament_prestige(day: int, theme: int = -1) -> float:
	var season = get_season(day)
	var t = theme if theme >= 0 else 0
	if THEME_TOURNAMENT_PRESTIGE.has(t):
		return THEME_TOURNAMENT_PRESTIGE[t].get(season, 1.0)
	return 1.0

## Theme weather modifiers for wind and rain probability adjustments.
static func get_theme_weather_modifiers(theme: int = -1) -> Dictionary:
	var t = theme if theme >= 0 else 0
	if THEME_WEATHER_MODIFIERS.has(t):
		return THEME_WEATHER_MODIFIERS[t]
	return {"wind": 1.0, "rain": 1.0}

## Blended weather weights with 2-day transition and theme rain modifier.
static func get_blended_weather_weights(day: int, theme: int = -1) -> Array:
	var season = get_season(day)
	var day_in_season = get_day_in_season(day)
	var base = get_weather_weights(season)

	# Apply blending at season boundaries
	if day_in_season == DAYS_PER_SEASON:
		var next_season = (season + 1) % 4
		var next = get_weather_weights(next_season)
		base = _lerp_array(base, next, 0.34)
	elif day_in_season == 1:
		var prev_season = (season + 3) % 4
		var prev = get_weather_weights(prev_season)
		base = _lerp_array(base, prev, 0.34)

	# Apply theme rain modifier — shifts probability toward/away from rain
	var weather_mods = get_theme_weather_modifiers(theme)
	var rain_mod = weather_mods.get("rain", 1.0)
	if rain_mod != 1.0:
		base = _apply_rain_modifier(base, rain_mod)

	return base

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

## Lerp two arrays element-wise.
static func _lerp_array(a: Array, b: Array, t: float) -> Array:
	var result: Array = []
	for i in range(mini(a.size(), b.size())):
		result.append(lerpf(a[i], b[i], t))
	return result

## Apply rain modifier to cumulative weather thresholds.
## rain_mod > 1.0 compresses the sunny portion (more rain).
## rain_mod < 1.0 expands the sunny portion (less rain).
static func _apply_rain_modifier(thresholds: Array, rain_mod: float) -> Array:
	if thresholds.size() < 6:
		return thresholds
	# Convert cumulative to individual probabilities
	var probs: Array = [thresholds[0]]
	for i in range(1, thresholds.size()):
		probs.append(thresholds[i] - thresholds[i - 1])
	# Scale rain probabilities (indices 3-5: LIGHT_RAIN, RAIN, HEAVY_RAIN)
	for i in range(3, probs.size()):
		probs[i] *= rain_mod
	# Normalize back to 1.0
	var total = 0.0
	for p in probs:
		total += p
	if total <= 0:
		return thresholds
	for i in range(probs.size()):
		probs[i] /= total
	# Convert back to cumulative
	var result: Array = [probs[0]]
	for i in range(1, probs.size()):
		result.append(result[i - 1] + probs[i])
	result[result.size() - 1] = 1.0  # Ensure last is exactly 1.0
	return result
