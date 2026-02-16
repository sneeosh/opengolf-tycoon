extends Node2D
class_name DayNightSystem
## DayNightSystem - Visual time-of-day tinting using CanvasModulate

var _canvas_modulate: CanvasModulate = null
var _current_hour: float = 6.0
var _weather_tint: Color = Color.WHITE
var _target_weather_tint: Color = Color.WHITE  # Lerp target for smooth transitions

func _ready() -> void:
	_canvas_modulate = CanvasModulate.new()
	_canvas_modulate.name = "DayNightModulate"
	_canvas_modulate.color = Color.WHITE
	add_child(_canvas_modulate)
	EventBus.hour_changed.connect(_on_hour_changed)
	EventBus.weather_changed.connect(_on_weather_changed)

func _exit_tree() -> void:
	if EventBus.hour_changed.is_connected(_on_hour_changed):
		EventBus.hour_changed.disconnect(_on_hour_changed)
	if EventBus.weather_changed.is_connected(_on_weather_changed):
		EventBus.weather_changed.disconnect(_on_weather_changed)

func _on_hour_changed(hour: float) -> void:
	_current_hour = hour
	_update_tint()

func _on_weather_changed(_weather_type: int, _intensity: float) -> void:
	# Set target weather tint — actual tint will smoothly lerp toward it in _process
	if GameManager.weather_system:
		_target_weather_tint = GameManager.weather_system.get_sky_tint()
	else:
		_target_weather_tint = Color.WHITE

func _process(delta: float) -> void:
	# Smoothly interpolate weather tint toward target (prevents jarring color jumps)
	_weather_tint = _weather_tint.lerp(_target_weather_tint, clampf(delta * 2.0, 0.0, 1.0))
	_update_tint()

func _update_tint() -> void:
	var time_tint = _get_tint_for_hour(_current_hour)

	# Blend time-of-day tint with weather tint
	# Weather tint has alpha indicating strength of effect
	var weather_strength = _weather_tint.a
	var weather_color = Color(_weather_tint.r, _weather_tint.g, _weather_tint.b, 1.0)

	# Darken/tint based on weather
	var final_tint = time_tint.lerp(time_tint * weather_color, weather_strength)
	_canvas_modulate.color = final_tint

func _get_tint_for_hour(hour: float) -> Color:
	# Sunrise: 5 AM - 7 AM  (warm orange → white)
	# Daytime: 7 AM - 5 PM  (full white)
	# Sunset:  5 PM - 8 PM  (white → warm orange → dusk blue)
	# Night:   8 PM - 5 AM  (dark blue)

	if hour < 5.0:
		# Deep night
		return Color(0.15, 0.15, 0.3)
	elif hour < 7.0:
		# Sunrise transition
		var t = (hour - 5.0) / 2.0  # 0.0 at 5 AM, 1.0 at 7 AM
		var night_color = Color(0.15, 0.15, 0.3)
		var dawn_color = Color(1.0, 0.85, 0.7)  # Warm sunrise
		var day_color = Color.WHITE
		if t < 0.5:
			return night_color.lerp(dawn_color, t * 2.0)
		else:
			return dawn_color.lerp(day_color, (t - 0.5) * 2.0)
	elif hour < 17.0:
		# Full daytime
		return Color.WHITE
	elif hour < 20.0:
		# Sunset transition
		var t = (hour - 17.0) / 3.0  # 0.0 at 5 PM, 1.0 at 8 PM
		var day_color = Color.WHITE
		var sunset_color = Color(1.0, 0.75, 0.5)  # Warm sunset orange
		var dusk_color = Color(0.3, 0.25, 0.45)  # Evening blue
		if t < 0.5:
			return day_color.lerp(sunset_color, t * 2.0)
		else:
			return sunset_color.lerp(dusk_color, (t - 0.5) * 2.0)
	else:
		# Night
		var t = clampf((hour - 20.0) / 4.0, 0.0, 1.0)
		var dusk_color = Color(0.3, 0.25, 0.45)
		var night_color = Color(0.15, 0.15, 0.3)
		return dusk_color.lerp(night_color, t)
