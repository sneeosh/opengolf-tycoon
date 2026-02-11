extends Control
class_name WeatherIndicator
## WeatherIndicator - HUD widget showing current weather conditions

var _weather_type: int = 0
var _intensity: float = 0.0
var _icon_label: Label = null
var _status_label: Label = null

func _ready() -> void:
	custom_minimum_size = Vector2(90, 50)

	# Create container layout
	var vbox = VBoxContainer.new()
	vbox.name = "WeatherContainer"
	add_child(vbox)

	# Title label
	var title = Label.new()
	title.text = "Weather"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 10)
	title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(title)

	# Icon/condition label
	_icon_label = Label.new()
	_icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_icon_label.add_theme_font_size_override("font_size", 14)
	_icon_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(_icon_label)

	# Status label
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_status_label)

	# Connect to weather signal
	EventBus.weather_changed.connect(_on_weather_changed)

func _exit_tree() -> void:
	if EventBus.weather_changed.is_connected(_on_weather_changed):
		EventBus.weather_changed.disconnect(_on_weather_changed)

func _on_weather_changed(weather_type: int, intensity: float) -> void:
	_weather_type = weather_type
	_intensity = intensity
	_update_display()

func _update_display() -> void:
	if not _icon_label or not _status_label:
		return

	# Get weather text and icon based on type
	var icon = _get_weather_icon()
	var text = _get_weather_text()
	var color = _get_weather_color()

	_icon_label.text = icon
	_icon_label.add_theme_color_override("font_color", color)

	_status_label.text = text
	_status_label.add_theme_color_override("font_color", color)

func _get_weather_icon() -> String:
	# WeatherType enum: SUNNY=0, PARTLY_CLOUDY=1, CLOUDY=2, LIGHT_RAIN=3, RAIN=4, HEAVY_RAIN=5
	match _weather_type:
		0:  # SUNNY
			return "* *"
		1:  # PARTLY_CLOUDY
			return "*~~"
		2:  # CLOUDY
			return "~~~"
		3:  # LIGHT_RAIN
			return "~~."
		4:  # RAIN
			return "~~:"
		5:  # HEAVY_RAIN
			return "~~|"
	return "?"

func _get_weather_text() -> String:
	match _weather_type:
		0:
			return "Sunny"
		1:
			return "Pt. Cloudy"
		2:
			return "Cloudy"
		3:
			return "Lt. Rain"
		4:
			return "Rain"
		5:
			return "Heavy Rain"
	return "Unknown"

func _get_weather_color() -> Color:
	match _weather_type:
		0:  # SUNNY
			return Color(1.0, 0.95, 0.4)  # Bright yellow
		1:  # PARTLY_CLOUDY
			return Color(0.9, 0.9, 0.6)  # Light yellow
		2:  # CLOUDY
			return Color(0.7, 0.7, 0.75)  # Gray
		3:  # LIGHT_RAIN
			return Color(0.6, 0.7, 0.9)  # Light blue
		4:  # RAIN
			return Color(0.4, 0.5, 0.8)  # Blue
		5:  # HEAVY_RAIN
			return Color(0.3, 0.4, 0.7)  # Dark blue
	return Color.WHITE

## Set initial weather values (called by main.gd after creation)
func set_weather(weather_type: int, intensity: float) -> void:
	_weather_type = weather_type
	_intensity = intensity
	_update_display()
