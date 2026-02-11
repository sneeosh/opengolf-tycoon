extends Node2D
class_name RainOverlay
## RainOverlay - Animated rain effect that covers the visible screen

var _weather_system: WeatherSystem = null
var _time: float = 0.0
var _rain_drops: Array = []  # Array of rain drop positions
var _is_active: bool = false

const MAX_DROPS: int = 200
const DROP_SPEED: float = 800.0  # Pixels per second
const DROP_LENGTH: float = 20.0

func _ready() -> void:
	z_index = 100  # Render above everything
	EventBus.weather_changed.connect(_on_weather_changed)

func _exit_tree() -> void:
	if EventBus.weather_changed.is_connected(_on_weather_changed):
		EventBus.weather_changed.disconnect(_on_weather_changed)

func setup(weather_system: WeatherSystem) -> void:
	_weather_system = weather_system
	_update_rain_state()

func _on_weather_changed(_weather_type: int, _intensity: float) -> void:
	_update_rain_state()

func _update_rain_state() -> void:
	if not _weather_system:
		_is_active = false
		return

	_is_active = _weather_system.is_raining()

	if _is_active:
		_initialize_drops()
	else:
		_rain_drops.clear()

func _initialize_drops() -> void:
	if not _weather_system:
		return

	_rain_drops.clear()
	var viewport_size = get_viewport_rect().size

	# Number of drops based on intensity
	var drop_count = int(MAX_DROPS * _weather_system.intensity)

	for i in range(drop_count):
		_rain_drops.append({
			"x": randf() * viewport_size.x,
			"y": randf() * viewport_size.y,
			"speed": randf_range(0.8, 1.2),
			"offset": randf() * TAU
		})

func _process(delta: float) -> void:
	if not _is_active:
		return

	_time += delta

	# Update drop positions
	var viewport_size = get_viewport_rect().size

	for drop in _rain_drops:
		drop.y += DROP_SPEED * drop.speed * delta

		# Reset drops that go off screen
		if drop.y > viewport_size.y + DROP_LENGTH:
			drop.y = -DROP_LENGTH
			drop.x = randf() * viewport_size.x

	queue_redraw()

func _draw() -> void:
	if not _is_active or not _weather_system:
		return

	var intensity = _weather_system.intensity
	var base_alpha = 0.15 + intensity * 0.25  # 0.15 - 0.40 alpha

	# Rain color - slightly blue tinted
	var rain_color = Color(0.7, 0.8, 0.95, base_alpha)

	# Draw each raindrop as a line
	for drop in _rain_drops:
		var start_pos = Vector2(drop.x, drop.y)
		var end_pos = Vector2(drop.x + 3, drop.y + DROP_LENGTH * drop.speed)

		# Vary alpha slightly per drop
		var drop_alpha = base_alpha * randf_range(0.7, 1.0)
		var drop_color = Color(rain_color.r, rain_color.g, rain_color.b, drop_alpha)

		draw_line(start_pos, end_pos, drop_color, 1.5)

	# Draw ground splash effects for heavy rain
	if intensity > 0.5:
		_draw_splashes()

func _draw_splashes() -> void:
	var viewport_size = get_viewport_rect().size
	var splash_count = int(20 * _weather_system.intensity)

	for i in range(splash_count):
		# Use deterministic positions based on time for consistent animation
		var seed_val = i * 17 + int(_time * 3) % 100
		var x = fmod(seed_val * 73.0, viewport_size.x)
		var y = viewport_size.y - 50 + fmod(seed_val * 31.0, 50)

		var splash_phase = fmod(_time * 5.0 + i * 0.5, 1.0)

		if splash_phase < 0.3:
			var radius = splash_phase * 8.0
			var alpha = (0.3 - splash_phase) * 0.5
			draw_arc(Vector2(x, y), radius, 0, PI, 8, Color(0.8, 0.85, 0.95, alpha), 1.0)
