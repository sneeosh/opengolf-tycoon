extends Node
## Global shadow system managing sun direction and shadow parameters.
## Registered as autoload "ShadowSystem" - do not add class_name to avoid conflict.
## Separate from wind direction - sun moves independently.

## Sun direction in degrees (0 = East, 90 = South, 180 = West, 270 = North)
## Default is 135 (Southeast) for classic isometric look
var sun_direction: float = 135.0:
	set(value):
		sun_direction = fmod(value, 360.0)
		if sun_direction < 0:
			sun_direction += 360.0
		sun_direction_changed.emit(sun_direction)

## Sun elevation angle (0 = horizon, 90 = directly overhead)
## Lower values = longer shadows
var sun_elevation: float = 45.0:
	set(value):
		sun_elevation = clamp(value, 10.0, 80.0)
		sun_direction_changed.emit(sun_direction)

## Global shadow intensity (0.0 = invisible, 1.0 = fully opaque)
var shadow_intensity: float = 0.3

## Contact shadow (AO) intensity
var contact_shadow_intensity: float = 0.25

signal sun_direction_changed(new_direction: float)

func _ready() -> void:
	# Could sync with day/night cycle in future
	pass

## Get normalized sun direction vector (2D projection)
func get_sun_direction_vector() -> Vector2:
	var rad = deg_to_rad(sun_direction)
	return Vector2(cos(rad), sin(rad))

## Calculate shadow offset for an object of given height
## Returns the 2D offset where the shadow should be rendered
func calculate_shadow_offset(object_height: float) -> Vector2:
	var direction = get_sun_direction_vector()
	# Shadow length based on elevation angle (lower sun = longer shadow)
	var shadow_length = object_height / tan(deg_to_rad(sun_elevation))
	# Clamp to reasonable range
	shadow_length = clamp(shadow_length, object_height * 0.3, object_height * 1.5)
	return direction * shadow_length

## Calculate shadow scale factor based on height
## Taller objects cast larger shadows
func calculate_shadow_scale(object_height: float, base_width: float) -> Vector2:
	var length_factor = 1.0 / tan(deg_to_rad(sun_elevation))
	length_factor = clamp(length_factor, 0.5, 1.5)
	# Shadow stretches in sun direction
	return Vector2(base_width * 0.8, base_width * 0.4 * length_factor)

## Get shadow color with current intensity
func get_shadow_color() -> Color:
	return Color(0, 0, 0, shadow_intensity)

## Get contact shadow color (slightly darker for AO effect)
func get_contact_shadow_color() -> Color:
	return Color(0, 0, 0, contact_shadow_intensity)

## Update sun position based on time of day (0-24 hours)
## Can be called by DayNightSystem
func set_time_of_day(hour: float) -> void:
	# Sun rises in east (0°), peaks at south (90°), sets in west (180°)
	# Map 6AM-6PM (12 hours) to 45°-135° arc
	var day_progress = clamp((hour - 6.0) / 12.0, 0.0, 1.0)
	sun_direction = lerp(45.0, 135.0, day_progress)

	# Elevation: low at dawn/dusk, high at noon
	var noon_distance = abs(hour - 12.0) / 6.0  # 0 at noon, 1 at 6AM/6PM
	sun_elevation = lerp(65.0, 25.0, noon_distance)
