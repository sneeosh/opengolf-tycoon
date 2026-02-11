extends Node
class_name WeatherSystem
## WeatherSystem - Manages weather conditions and their effects on gameplay

## Weather types
enum WeatherType {
	SUNNY,
	PARTLY_CLOUDY,
	CLOUDY,
	LIGHT_RAIN,
	RAIN,
	HEAVY_RAIN
}

## Current weather state
var weather_type: WeatherType = WeatherType.SUNNY
var intensity: float = 0.0  # 0.0 = clear, 1.0 = severe

## Weather transition
var _target_weather: WeatherType = WeatherType.SUNNY
var _transition_progress: float = 1.0
const TRANSITION_SPEED: float = 0.5  # How fast weather changes (per hour)

## Weather persistence (how long current weather tends to last)
var _hours_in_current_weather: float = 0.0
var _weather_duration: float = 4.0  # Target hours before potential change

func _ready() -> void:
	_generate_daily_weather()
	EventBus.day_changed.connect(_on_day_changed)

func _exit_tree() -> void:
	if EventBus.day_changed.is_connected(_on_day_changed):
		EventBus.day_changed.disconnect(_on_day_changed)

## Generate weather for a new day
func generate_daily_weather() -> void:
	_generate_daily_weather()

func _generate_daily_weather() -> void:
	# Weight towards good weather (70% chance of sunny/partly cloudy)
	var roll = randf()
	if roll < 0.40:
		weather_type = WeatherType.SUNNY
		intensity = 0.0
	elif roll < 0.70:
		weather_type = WeatherType.PARTLY_CLOUDY
		intensity = 0.1
	elif roll < 0.85:
		weather_type = WeatherType.CLOUDY
		intensity = 0.25
	elif roll < 0.93:
		weather_type = WeatherType.LIGHT_RAIN
		intensity = 0.4
	elif roll < 0.98:
		weather_type = WeatherType.RAIN
		intensity = 0.6
	else:
		weather_type = WeatherType.HEAVY_RAIN
		intensity = 0.85

	_target_weather = weather_type
	_transition_progress = 1.0
	_hours_in_current_weather = 0.0
	_weather_duration = randf_range(3.0, 8.0)

	_emit_weather_changed()
	print("Weather for today: %s (intensity: %.1f)" % [get_weather_text(), intensity])

## Update weather with hourly changes
func update_weather(hours_elapsed: float) -> void:
	_hours_in_current_weather += hours_elapsed

	# Check if weather should change
	if _hours_in_current_weather >= _weather_duration:
		_maybe_change_weather()

	# Handle weather transitions
	if _transition_progress < 1.0:
		_transition_progress = minf(_transition_progress + TRANSITION_SPEED * hours_elapsed, 1.0)
		_update_intensity_for_transition()
		_emit_weather_changed()

func _maybe_change_weather() -> void:
	# Weather tends to move in patterns (sunny -> cloudy -> rain -> clearing)
	var change_chance = 0.3  # 30% chance per check
	if randf() > change_chance:
		# Reset duration but keep current weather
		_weather_duration = randf_range(2.0, 6.0)
		_hours_in_current_weather = 0.0
		return

	# Determine new weather based on current
	var new_weather = _get_next_weather()
	if new_weather != weather_type:
		_target_weather = new_weather
		_transition_progress = 0.0
		_hours_in_current_weather = 0.0
		_weather_duration = randf_range(2.0, 6.0)

func _get_next_weather() -> WeatherType:
	# Weather tends to follow patterns
	match weather_type:
		WeatherType.SUNNY:
			# Sunny can become partly cloudy
			return WeatherType.PARTLY_CLOUDY if randf() < 0.7 else WeatherType.SUNNY
		WeatherType.PARTLY_CLOUDY:
			# Can go either way
			var roll = randf()
			if roll < 0.4:
				return WeatherType.SUNNY
			elif roll < 0.8:
				return WeatherType.CLOUDY
			else:
				return WeatherType.PARTLY_CLOUDY
		WeatherType.CLOUDY:
			var roll = randf()
			if roll < 0.3:
				return WeatherType.PARTLY_CLOUDY
			elif roll < 0.7:
				return WeatherType.LIGHT_RAIN
			else:
				return WeatherType.CLOUDY
		WeatherType.LIGHT_RAIN:
			var roll = randf()
			if roll < 0.4:
				return WeatherType.CLOUDY
			elif roll < 0.7:
				return WeatherType.RAIN
			else:
				return WeatherType.LIGHT_RAIN
		WeatherType.RAIN:
			var roll = randf()
			if roll < 0.4:
				return WeatherType.LIGHT_RAIN
			elif roll < 0.6:
				return WeatherType.HEAVY_RAIN
			else:
				return WeatherType.RAIN
		WeatherType.HEAVY_RAIN:
			# Heavy rain tends to let up
			return WeatherType.RAIN if randf() < 0.7 else WeatherType.HEAVY_RAIN

	return weather_type

func _update_intensity_for_transition() -> void:
	# Lerp intensity based on transition progress
	var target_intensity = _get_base_intensity(_target_weather)
	var current_base = _get_base_intensity(weather_type)
	intensity = lerpf(current_base, target_intensity, _transition_progress)

	# Update weather type when transition is mostly complete
	if _transition_progress >= 0.8:
		weather_type = _target_weather

func _get_base_intensity(wtype: WeatherType) -> float:
	match wtype:
		WeatherType.SUNNY:
			return 0.0
		WeatherType.PARTLY_CLOUDY:
			return 0.1
		WeatherType.CLOUDY:
			return 0.25
		WeatherType.LIGHT_RAIN:
			return 0.4
		WeatherType.RAIN:
			return 0.6
		WeatherType.HEAVY_RAIN:
			return 0.85
	return 0.0

## Get spawn rate modifier based on weather (0.5 - 1.0)
## Bad weather reduces golfer spawning
func get_spawn_rate_modifier() -> float:
	match weather_type:
		WeatherType.SUNNY:
			return 1.0
		WeatherType.PARTLY_CLOUDY:
			return 1.0
		WeatherType.CLOUDY:
			return 0.9
		WeatherType.LIGHT_RAIN:
			return 0.7
		WeatherType.RAIN:
			return 0.5
		WeatherType.HEAVY_RAIN:
			return 0.3
	return 1.0

## Get accuracy modifier for shots (rain makes aiming harder)
func get_accuracy_modifier() -> float:
	match weather_type:
		WeatherType.SUNNY, WeatherType.PARTLY_CLOUDY, WeatherType.CLOUDY:
			return 1.0
		WeatherType.LIGHT_RAIN:
			return 0.95
		WeatherType.RAIN:
			return 0.90
		WeatherType.HEAVY_RAIN:
			return 0.85
	return 1.0

## Get sky tint color for DayNightSystem integration
func get_sky_tint() -> Color:
	match weather_type:
		WeatherType.SUNNY:
			return Color(1.0, 1.0, 1.0, 0.0)  # No tint
		WeatherType.PARTLY_CLOUDY:
			return Color(0.95, 0.95, 0.95, 0.1)
		WeatherType.CLOUDY:
			return Color(0.85, 0.85, 0.9, 0.2)
		WeatherType.LIGHT_RAIN:
			return Color(0.75, 0.78, 0.85, 0.3)
		WeatherType.RAIN:
			return Color(0.65, 0.68, 0.75, 0.35)
		WeatherType.HEAVY_RAIN:
			return Color(0.55, 0.58, 0.65, 0.4)
	return Color(1.0, 1.0, 1.0, 0.0)

## Check if it's currently raining
func is_raining() -> bool:
	return weather_type >= WeatherType.LIGHT_RAIN

## Get weather description text
func get_weather_text() -> String:
	match weather_type:
		WeatherType.SUNNY:
			return "Sunny"
		WeatherType.PARTLY_CLOUDY:
			return "Partly Cloudy"
		WeatherType.CLOUDY:
			return "Cloudy"
		WeatherType.LIGHT_RAIN:
			return "Light Rain"
		WeatherType.RAIN:
			return "Rain"
		WeatherType.HEAVY_RAIN:
			return "Heavy Rain"
	return "Unknown"

## Get weather icon character
func get_weather_icon() -> String:
	match weather_type:
		WeatherType.SUNNY:
			return "O"  # Sun
		WeatherType.PARTLY_CLOUDY:
			return "o~"  # Partial cloud
		WeatherType.CLOUDY:
			return "~~"  # Cloud
		WeatherType.LIGHT_RAIN:
			return "~."  # Light rain
		WeatherType.RAIN:
			return "~:"  # Rain
		WeatherType.HEAVY_RAIN:
			return "~|"  # Heavy rain
	return "?"

func _on_day_changed(_new_day: int) -> void:
	_generate_daily_weather()

func _emit_weather_changed() -> void:
	EventBus.weather_changed.emit(weather_type, intensity)
