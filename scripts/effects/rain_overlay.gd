extends Node2D
class_name RainOverlay
## RainOverlay - Animated rain effect that covers the visible screen

var _weather_system: WeatherSystem = null
var _time: float = 0.0
var _rain_drops: Array = []  # Array of rain drop positions
var _is_active: bool = false
var _wind_direction: float = 0.0
var _wind_speed: float = 0.0

const MAX_DROPS: int = 500
const MAX_DROPS_WEB: int = 150  # Reduced for web performance
const DROP_SPEED: float = 900.0  # Pixels per second
const DROP_LENGTH: float = 24.0

var _is_web: bool = false
var _web_redraw_timer: float = 0.0
const WEB_REDRAW_INTERVAL: float = 0.05  # 20 FPS for rain on web (vs 60 on desktop)

func _ready() -> void:
	z_index = 100  # Render above everything
	_is_web = OS.get_name() == "Web"
	EventBus.weather_changed.connect(_on_weather_changed)
	EventBus.wind_changed.connect(_on_wind_changed)
	EventBus.game_mode_changed.connect(_on_game_mode_changed)

func _exit_tree() -> void:
	if EventBus.weather_changed.is_connected(_on_weather_changed):
		EventBus.weather_changed.disconnect(_on_weather_changed)
	if EventBus.wind_changed.is_connected(_on_wind_changed):
		EventBus.wind_changed.disconnect(_on_wind_changed)
	if EventBus.game_mode_changed.is_connected(_on_game_mode_changed):
		EventBus.game_mode_changed.disconnect(_on_game_mode_changed)

func _on_wind_changed(direction: float, speed: float) -> void:
	_wind_direction = direction
	_wind_speed = speed

func setup(weather_system: WeatherSystem) -> void:
	_weather_system = weather_system
	_update_rain_state()

func _on_weather_changed(_weather_type: int, _intensity: float) -> void:
	_update_rain_state()

func _on_game_mode_changed(_old_mode: int, _new_mode: int) -> void:
	_update_rain_state()

func _update_rain_state() -> void:
	var was_active := _is_active

	if not _weather_system or GameManager.current_mode == GameManager.GameMode.MAIN_MENU:
		_is_active = false
	else:
		_is_active = _weather_system.is_raining()

	if _is_active:
		_initialize_drops()
	elif was_active:
		_rain_drops.clear()
		queue_redraw()  # Clear the last frame of rain from screen

func _initialize_drops() -> void:
	if not _weather_system:
		return

	_rain_drops.clear()
	var viewport_size = get_viewport_rect().size

	# Number of drops based on intensity (fewer on web)
	var max_drops = MAX_DROPS_WEB if _is_web else MAX_DROPS
	var drop_count = int(max_drops * _weather_system.intensity)

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

	# Update drop positions — wind pushes drops horizontally
	var viewport_size = get_viewport_rect().size
	var wind_x_offset := -sin(_wind_direction) * _wind_speed * 8.0  # Horizontal wind push

	for drop in _rain_drops:
		drop.y += DROP_SPEED * drop.speed * delta
		drop.x += wind_x_offset * delta

		# Reset drops that go off screen (vertically or horizontally)
		if drop.y > viewport_size.y + DROP_LENGTH or drop.x < -50 or drop.x > viewport_size.x + 50:
			drop.y = -DROP_LENGTH
			drop.x = randf() * viewport_size.x

	# Throttle redraws on web to ~20 FPS
	if _is_web:
		_web_redraw_timer += delta
		if _web_redraw_timer >= WEB_REDRAW_INTERVAL:
			_web_redraw_timer = 0.0
			queue_redraw()
	else:
		queue_redraw()

func _draw() -> void:
	if not _is_active or not _weather_system:
		return

	var intensity = _weather_system.intensity
	var base_alpha = 0.3 + intensity * 0.4  # 0.3 - 0.70 alpha

	# Rain color - slightly blue tinted
	var rain_color = Color(0.75, 0.85, 1.0, base_alpha)

	# Draw each raindrop as a line, angled by wind
	var wind_angle_x := -sin(_wind_direction) * _wind_speed * 0.3
	for drop in _rain_drops:
		var start_pos = Vector2(drop.x, drop.y)
		var end_pos = Vector2(drop.x + wind_angle_x + 3, drop.y + DROP_LENGTH * drop.speed)

		# Vary alpha slightly per drop
		var drop_alpha = base_alpha * randf_range(0.7, 1.0)
		var drop_color = Color(rain_color.r, rain_color.g, rain_color.b, drop_alpha)

		draw_line(start_pos, end_pos, drop_color, 2.0)

	# Draw ground splash effects for heavy rain (skip on web to reduce draw calls)
	if intensity > 0.5 and not _is_web:
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

	# Draw puddle spots during heavy rain
	if _weather_system.intensity > 0.6:
		_draw_puddles(viewport_size)

func _draw_puddles(viewport_size: Vector2) -> void:
	var puddle_count := int(12 * _weather_system.intensity)
	var puddle_color := Color(0.5, 0.6, 0.8, 0.12)

	for i in range(puddle_count):
		# Deterministic positions (seeded by index, stable between frames)
		var seed_x := fmod(float(i) * 137.5 + 23.7, viewport_size.x)
		var seed_y := fmod(float(i) * 89.3 + 41.2, viewport_size.y)
		var radius := 4.0 + fmod(float(i) * 7.3, 6.0)
		# Slight shimmer
		var shimmer := sin(_time * 2.0 + i * 1.3) * 0.03
		var c := Color(puddle_color.r, puddle_color.g, puddle_color.b, puddle_color.a + shimmer)
		draw_circle(Vector2(seed_x, seed_y), radius, c)
