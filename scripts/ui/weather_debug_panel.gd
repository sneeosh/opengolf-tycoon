extends CenteredPanel
class_name WeatherDebugPanel
## Debug panel for toggling weather conditions and wind settings

signal close_requested

var _weather_buttons: Array[Button] = []
var _wind_speed_slider: HSlider = null
var _wind_dir_slider: HSlider = null
var _wind_speed_label: Label = null
var _wind_dir_label: Label = null
var _current_label: Label = null

const WEATHER_NAMES := ["Sunny", "Partly Cloudy", "Cloudy", "Light Rain", "Rain", "Heavy Rain"]

func _build_ui() -> void:
	custom_minimum_size = Vector2(380, 300)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Title row with close button
	var title_row := HBoxContainer.new()
	vbox.add_child(title_row)

	var title := Label.new()
	title.text = "Weather Debug (F2)"
	title.add_theme_font_size_override("font_size", 16)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.pressed.connect(func(): close_requested.emit())
	title_row.add_child(close_btn)

	# Current status
	_current_label = Label.new()
	_current_label.add_theme_font_size_override("font_size", 12)
	_current_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_current_label)

	# Separator
	vbox.add_child(HSeparator.new())

	# Weather type buttons
	var weather_label := Label.new()
	weather_label.text = "Weather Type"
	weather_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(weather_label)

	var button_grid := GridContainer.new()
	button_grid.columns = 3
	button_grid.add_theme_constant_override("h_separation", 4)
	button_grid.add_theme_constant_override("v_separation", 4)
	vbox.add_child(button_grid)

	for i in range(WEATHER_NAMES.size()):
		var btn := Button.new()
		btn.text = WEATHER_NAMES[i]
		btn.custom_minimum_size = Vector2(110, 30)
		btn.pressed.connect(_on_weather_button.bind(i))
		button_grid.add_child(btn)
		_weather_buttons.append(btn)

	# Separator
	vbox.add_child(HSeparator.new())

	# Wind speed slider
	var wind_speed_row := HBoxContainer.new()
	wind_speed_row.add_theme_constant_override("separation", 8)
	vbox.add_child(wind_speed_row)

	var ws_label := Label.new()
	ws_label.text = "Wind Speed:"
	ws_label.custom_minimum_size = Vector2(90, 0)
	wind_speed_row.add_child(ws_label)

	_wind_speed_slider = HSlider.new()
	_wind_speed_slider.min_value = 0.0
	_wind_speed_slider.max_value = 30.0
	_wind_speed_slider.step = 1.0
	_wind_speed_slider.custom_minimum_size = Vector2(150, 0)
	_wind_speed_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wind_speed_slider.value_changed.connect(_on_wind_speed_changed)
	wind_speed_row.add_child(_wind_speed_slider)

	_wind_speed_label = Label.new()
	_wind_speed_label.text = "5 mph"
	_wind_speed_label.custom_minimum_size = Vector2(60, 0)
	wind_speed_row.add_child(_wind_speed_label)

	# Wind direction slider
	var wind_dir_row := HBoxContainer.new()
	wind_dir_row.add_theme_constant_override("separation", 8)
	vbox.add_child(wind_dir_row)

	var wd_label := Label.new()
	wd_label.text = "Wind Dir:"
	wd_label.custom_minimum_size = Vector2(90, 0)
	wind_dir_row.add_child(wd_label)

	_wind_dir_slider = HSlider.new()
	_wind_dir_slider.min_value = 0.0
	_wind_dir_slider.max_value = 360.0
	_wind_dir_slider.step = 5.0
	_wind_dir_slider.custom_minimum_size = Vector2(150, 0)
	_wind_dir_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wind_dir_slider.value_changed.connect(_on_wind_dir_changed)
	wind_dir_row.add_child(_wind_dir_slider)

	_wind_dir_label = Label.new()
	_wind_dir_label.text = "N 0"
	_wind_dir_label.custom_minimum_size = Vector2(60, 0)
	wind_dir_row.add_child(_wind_dir_label)

	# Listen for external changes
	EventBus.weather_changed.connect(_on_weather_changed_external)
	EventBus.wind_changed.connect(_on_wind_changed_external)

func _exit_tree() -> void:
	if EventBus.weather_changed.is_connected(_on_weather_changed_external):
		EventBus.weather_changed.disconnect(_on_weather_changed_external)
	if EventBus.wind_changed.is_connected(_on_wind_changed_external):
		EventBus.wind_changed.disconnect(_on_wind_changed_external)

func show_centered() -> void:
	_sync_from_systems()
	super.show_centered()

func _sync_from_systems() -> void:
	if GameManager.weather_system:
		_highlight_active_button(GameManager.weather_system.weather_type)
		_update_current_label()

	if GameManager.wind_system:
		_wind_speed_slider.set_value_no_signal(GameManager.wind_system.wind_speed)
		_wind_speed_label.text = "%d mph" % int(GameManager.wind_system.wind_speed)
		var deg = rad_to_deg(GameManager.wind_system.wind_direction)
		_wind_dir_slider.set_value_no_signal(fmod(deg + 360.0, 360.0))
		_wind_dir_label.text = "%s %d" % [GameManager.wind_system.get_direction_text(), int(fmod(deg + 360.0, 360.0))]

func _on_weather_button(weather_type: int) -> void:
	if not GameManager.weather_system:
		return
	var ws: WeatherSystem = GameManager.weather_system
	var wt: WeatherSystem.WeatherType = weather_type as WeatherSystem.WeatherType
	ws.weather_type = wt
	ws.intensity = ws._get_base_intensity(wt)
	ws._target_weather = wt
	ws._transition_progress = 1.0
	EventBus.weather_changed.emit(wt, ws.intensity)
	_highlight_active_button(weather_type)
	_update_current_label()

func _on_wind_speed_changed(value: float) -> void:
	if not GameManager.wind_system:
		return
	GameManager.wind_system.wind_speed = value
	_wind_speed_label.text = "%d mph" % int(value)
	EventBus.wind_changed.emit(GameManager.wind_system.wind_direction, value)
	_update_current_label()

func _on_wind_dir_changed(value: float) -> void:
	if not GameManager.wind_system:
		return
	var rad = deg_to_rad(value)
	GameManager.wind_system.wind_direction = rad
	GameManager.wind_system._base_direction = rad
	_wind_dir_label.text = "%s %d" % [GameManager.wind_system.get_direction_text(), int(value)]
	EventBus.wind_changed.emit(rad, GameManager.wind_system.wind_speed)
	_update_current_label()

func _highlight_active_button(weather_type: int) -> void:
	for i in range(_weather_buttons.size()):
		var btn := _weather_buttons[i]
		if i == weather_type:
			btn.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3))
		else:
			btn.remove_theme_color_override("font_color")

func _update_current_label() -> void:
	if not _current_label:
		return
	var weather_text := "?"
	var wind_text := "?"
	if GameManager.weather_system:
		weather_text = GameManager.weather_system.get_weather_text()
	if GameManager.wind_system:
		wind_text = "%s %d mph" % [GameManager.wind_system.get_direction_text(), int(GameManager.wind_system.wind_speed)]
	_current_label.text = "Current: %s | Wind: %s" % [weather_text, wind_text]

func _on_weather_changed_external(_weather_type: int, _intensity: float) -> void:
	if visible:
		_sync_from_systems()

func _on_wind_changed_external(_direction: float, _speed: float) -> void:
	if visible:
		_sync_from_systems()
