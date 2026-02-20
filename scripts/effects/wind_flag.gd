extends Node2D
class_name WindFlag
## Animated wind pennant rendered on tee boxes and greens.
## Subscribes to wind_changed for direction/speed updates.
## Uses _draw() with sine-wave vertex offset for flutter animation.

var _wind_direction: float = 0.0  # radians, 0 = North
var _wind_speed: float = 5.0
var _time: float = 0.0
var _flag_color: Color = Color(0.9, 0.15, 0.15)  # Red pennant
var _pole_height: float = 24.0
var _flag_length: float = 10.0
var _phase_offset: float = 0.0  # Per-flag variation
var _is_web: bool = false
var _web_redraw_timer: float = 0.0
const WEB_FLAG_REDRAW_INTERVAL: float = 0.1  # 10 FPS for flag flutter on web

func _ready() -> void:
	_is_web = OS.get_name() == "Web"
	EventBus.wind_changed.connect(_on_wind_changed)
	_phase_offset = randf() * TAU  # Random phase so flags don't all flutter in sync
	z_index = 5  # Above terrain, below golfers

func _exit_tree() -> void:
	if EventBus.wind_changed.is_connected(_on_wind_changed):
		EventBus.wind_changed.disconnect(_on_wind_changed)

func _on_wind_changed(direction: float, speed: float) -> void:
	_wind_direction = direction
	_wind_speed = speed

func _process(delta: float) -> void:
	_time += delta
	if _is_web:
		_web_redraw_timer += delta
		if _web_redraw_timer >= WEB_FLAG_REDRAW_INTERVAL:
			_web_redraw_timer = 0.0
			queue_redraw()
	else:
		queue_redraw()

func _draw() -> void:
	# Pole: vertical line from base to top
	var pole_base := Vector2(0, 0)
	var pole_top := Vector2(0, -_pole_height)
	draw_line(pole_base, pole_top, Color(0.5, 0.5, 0.5), 1.5)

	# Flag extends from pole top in wind direction
	# Project wind direction into isometric space
	var wind_dir_2d := Vector2(-sin(_wind_direction), cos(_wind_direction) * 0.5)
	var wind_strength := clampf(_wind_speed / 30.0, 0.05, 1.0)

	# Flag length scales slightly with wind speed
	var flag_len := _flag_length + wind_strength * 4.0

	# Flutter parameters
	var flutter_speed := 3.0 + wind_strength * 5.0
	var flutter_amp := 1.0 + wind_strength * 3.0

	# Draw flag as a filled polygon with sine-wave distortion
	var segments := 6
	var top_points: PackedVector2Array = []
	var bottom_points: PackedVector2Array = []

	for i in range(segments + 1):
		var t := float(i) / segments  # 0..1 along flag length
		var base_pos := pole_top + wind_dir_2d * flag_len * t

		# Sine-wave flutter increases toward the trailing edge
		var flutter := sin(_time * flutter_speed + t * 4.0 + _phase_offset) * flutter_amp * t
		var flutter_offset := Vector2(-wind_dir_2d.y, wind_dir_2d.x) * flutter

		# Flag width tapers from ~6px at pole to ~2px at tip
		var half_width := lerpf(3.0, 1.0, t)
		var perp := Vector2(-wind_dir_2d.y, wind_dir_2d.x).normalized()

		top_points.append(base_pos + perp * half_width + flutter_offset)
		bottom_points.append(base_pos - perp * half_width + flutter_offset)

	# Combine into a single polygon (top edge forward, bottom edge reversed)
	var polygon: PackedVector2Array = []
	for pt in top_points:
		polygon.append(pt)
	for i in range(bottom_points.size() - 1, -1, -1):
		polygon.append(bottom_points[i])

	if polygon.size() >= 3:
		# Main flag fill
		var flag_alpha := 0.7 + wind_strength * 0.3
		var fill_color := Color(_flag_color.r, _flag_color.g, _flag_color.b, flag_alpha)
		draw_colored_polygon(polygon, fill_color)

		# Outline for definition (skip on web — N draw_line calls per flag)
		if not _is_web:
			var outline_color := Color(_flag_color.r * 0.6, _flag_color.g * 0.6, _flag_color.b * 0.6, flag_alpha)
			for i in range(polygon.size()):
				var next := (i + 1) % polygon.size()
				draw_line(polygon[i], polygon[next], outline_color, 0.5)

	# Small ball at pole top
	draw_circle(pole_top, 1.5, Color(0.8, 0.8, 0.8))
