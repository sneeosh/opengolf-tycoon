extends Node
class_name WindSystem
## WindSystem - Manages wind direction, speed, and effects on ball flight

## Wind state
var wind_direction: float = 0.0  # Radians (0 = North/up, PI/2 = East)
var wind_speed: float = 5.0      # MPH (0-30)

## Wind drift per hour
var _base_direction: float = 0.0
var _drift_rate: float = 0.0

## Club sensitivity to wind (higher = more affected)
const CLUB_WIND_SENSITIVITY = {
	0: 1.0,   # DRIVER - full wind effect
	1: 0.7,   # IRON
	2: 0.4,   # WEDGE
	3: 0.0,   # PUTTER - no wind effect
}

func _ready() -> void:
	_generate_new_wind()
	EventBus.day_changed.connect(_on_day_changed)

func _exit_tree() -> void:
	if EventBus.day_changed.is_connected(_on_day_changed):
		EventBus.day_changed.disconnect(_on_day_changed)

## Public method to generate new daily wind (called by GameManager on day advance)
func generate_daily_wind() -> void:
	_generate_new_wind()

## Generate new wind conditions (called at start and each new day)
func _generate_new_wind() -> void:
	_base_direction = randf() * TAU
	wind_direction = _base_direction
	wind_speed = randf_range(2.0, 20.0)
	_drift_rate = randf_range(-0.3, 0.3)  # How much direction drifts per hour
	_emit_wind_changed()

## Update wind with hourly drift
func update_wind_drift(hours_elapsed: float) -> void:
	wind_direction = _base_direction + _drift_rate * hours_elapsed
	# Slight speed variation
	wind_speed = clampf(wind_speed + randf_range(-0.5, 0.5), 0.0, 30.0)
	_emit_wind_changed()

## Get wind displacement for a shot (in tiles)
## Returns how far the ball will be pushed by wind
func get_wind_displacement(shot_direction: Vector2, distance_tiles: float, club: int) -> Vector2:
	var sensitivity = CLUB_WIND_SENSITIVITY.get(club, 0.5)
	if sensitivity == 0.0:
		return Vector2.ZERO

	var wind_vector = Vector2(cos(wind_direction), sin(wind_direction)) * wind_speed

	# Decompose wind into headwind/tailwind and crosswind components
	var shot_dir_normalized = shot_direction.normalized()
	var headwind = wind_vector.dot(shot_dir_normalized)  # Positive = tailwind
	var crosswind_vec = wind_vector - shot_dir_normalized * headwind

	# Scale effect by distance and sensitivity
	# Longer shots are more affected by wind
	var distance_factor = distance_tiles / 20.0  # Normalize to ~driver distance
	var wind_factor = sensitivity * distance_factor

	# Crosswind pushes ball laterally (main visible effect)
	var displacement = crosswind_vec * wind_factor * 0.15

	# Headwind/tailwind handled separately in get_distance_modifier
	return displacement

## Get distance modifier from headwind/tailwind
## Returns multiplier: <1.0 for headwind, >1.0 for tailwind
func get_distance_modifier(shot_direction: Vector2, club: int) -> float:
	var sensitivity = CLUB_WIND_SENSITIVITY.get(club, 0.5)
	if sensitivity == 0.0:
		return 1.0

	var wind_vector = Vector2(cos(wind_direction), sin(wind_direction)) * wind_speed
	var shot_dir_normalized = shot_direction.normalized()

	# Dot product: positive = tailwind (wind going same direction as shot)
	var headwind_component = wind_vector.dot(shot_dir_normalized)

	# Normalize to a reasonable modifier range
	# At 30mph headwind, up to 15% distance reduction
	# At 30mph tailwind, up to 10% distance increase
	var modifier = 1.0
	if headwind_component < 0:
		# Headwind - reduces distance
		modifier -= abs(headwind_component) / 30.0 * 0.15 * sensitivity
	else:
		# Tailwind - increases distance
		modifier += headwind_component / 30.0 * 0.10 * sensitivity

	return clampf(modifier, 0.75, 1.15)

## Get wind direction as compass text
func get_direction_text() -> String:
	# Convert radians to 8-point compass
	var degrees = fmod(rad_to_deg(wind_direction) + 360.0, 360.0)
	var directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
	var index = int(round(degrees / 45.0)) % 8
	return directions[index]

## Get wind strength description
func get_strength_text() -> String:
	if wind_speed < 5.0:
		return "Calm"
	elif wind_speed < 10.0:
		return "Light"
	elif wind_speed < 15.0:
		return "Moderate"
	elif wind_speed < 20.0:
		return "Strong"
	else:
		return "Very Strong"

func _on_day_changed(_new_day: int) -> void:
	_generate_new_wind()

func _emit_wind_changed() -> void:
	EventBus.wind_changed.emit(wind_direction, wind_speed)
