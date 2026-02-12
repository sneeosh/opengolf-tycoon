extends Control
class_name WindIndicator
## WindIndicator - HUD widget showing wind direction and speed

var _wind_direction: float = 0.0
var _wind_speed: float = 0.0
var _arrow_node: Node2D = null
var _speed_label: Label = null
var _direction_label: Label = null

func _ready() -> void:
	custom_minimum_size = Vector2(100, 50)

	# Create container layout
	var vbox = VBoxContainer.new()
	vbox.name = "WindContainer"
	add_child(vbox)

	# Title label
	var title = Label.new()
	title.text = "Wind"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 10)
	title.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(title)

	# Arrow container (SubViewportContainer approach is complex; use a simple label with direction)
	_direction_label = Label.new()
	_direction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_direction_label.add_theme_font_size_override("font_size", 14)
	_direction_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(_direction_label)

	# Speed label
	_speed_label = Label.new()
	_speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speed_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_speed_label)

	# Connect to wind signal
	EventBus.wind_changed.connect(_on_wind_changed)

func _exit_tree() -> void:
	if EventBus.wind_changed.is_connected(_on_wind_changed):
		EventBus.wind_changed.disconnect(_on_wind_changed)

func _on_wind_changed(direction: float, speed: float) -> void:
	_wind_direction = direction
	_wind_speed = speed
	_update_display()

func _update_display() -> void:
	if not _speed_label or not _direction_label:
		return

	# Direction arrow using Unicode arrows
	var arrow = _get_direction_arrow()
	var compass = _get_compass_text()
	_direction_label.text = "%s %s" % [arrow, compass]

	# Speed with color coding
	_speed_label.text = "%d mph" % int(_wind_speed)

	if _wind_speed < 5.0:
		_speed_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))  # Green - calm
	elif _wind_speed < 10.0:
		_speed_label.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))  # Light green
	elif _wind_speed < 15.0:
		_speed_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.4))  # Yellow
	elif _wind_speed < 20.0:
		_speed_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))  # Orange
	else:
		_speed_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))  # Red

func _get_direction_arrow() -> String:
	var degrees = fmod(rad_to_deg(_wind_direction) + 360.0, 360.0)
	# Wind direction indicates where wind is coming FROM, arrow shows where it blows TO
	var arrows = ["↓", "↙", "←", "↖", "↑", "↗", "→", "↘"]
	var index = int(round(degrees / 45.0)) % 8
	return arrows[index]

func _get_compass_text() -> String:
	var degrees = fmod(rad_to_deg(_wind_direction) + 360.0, 360.0)
	var directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
	var index = int(round(degrees / 45.0)) % 8
	return directions[index]

## Set initial wind values (called by main.gd after creation)
func set_wind(direction: float, speed: float) -> void:
	_wind_direction = direction
	_wind_speed = speed
	_update_display()
