extends PanelContainer
class_name TopHUDBar
## TopHUDBar - Redesigned top status bar with icons and improved typography

signal money_clicked()
signal reputation_clicked()
signal rating_clicked()

# UI References
var _game_mode_icon: Label
var _game_mode_label: Label
var _money_button: Button
var _money_trend: Label
var _day_time_label: Label
var _reputation_button: Button
var _weather_icon: Label
var _weather_label: Label
var _wind_label: Label
var _rating_button: Button

# State
var _last_money: int = 0
var _money_trend_value: int = 0

func _ready() -> void:
	_build_ui()
	_connect_signals()
	_update_all()

func _build_ui() -> void:
	custom_minimum_size = Vector2(0, UIConstants.TOP_HUD_HEIGHT)

	# Apply top bar style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.08, 0.92)
	style.border_width_bottom = 1
	style.border_color = Color(0.2, 0.2, 0.2, 1)
	style.content_margin_left = 16
	style.content_margin_top = 8
	style.content_margin_right = 16
	style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	add_child(hbox)

	# Game Mode Indicator
	var mode_container = HBoxContainer.new()
	mode_container.add_theme_constant_override("separation", 6)
	hbox.add_child(mode_container)

	_game_mode_icon = Label.new()
	_game_mode_icon.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_LG)
	mode_container.add_child(_game_mode_icon)

	_game_mode_label = Label.new()
	_game_mode_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BASE)
	mode_container.add_child(_game_mode_label)

	# Left spacer
	var spacer_left = Control.new()
	spacer_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer_left)

	# Stats Container
	var stats_container = HBoxContainer.new()
	stats_container.add_theme_constant_override("separation", 16)
	hbox.add_child(stats_container)

	# Money Display (clickable)
	var money_container = HBoxContainer.new()
	money_container.add_theme_constant_override("separation", 4)
	stats_container.add_child(money_container)

	_money_button = Button.new()
	_money_button.flat = true
	_money_button.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_MD)
	_money_button.pressed.connect(_on_money_pressed)
	_money_button.tooltip_text = "Click to view financial details"
	money_container.add_child(_money_button)

	_money_trend = Label.new()
	_money_trend.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
	money_container.add_child(_money_trend)

	# Vertical separator
	stats_container.add_child(_create_vseparator())

	# Day/Time Display
	var day_container = HBoxContainer.new()
	day_container.add_theme_constant_override("separation", 6)
	stats_container.add_child(day_container)

	var day_icon = Label.new()
	day_icon.text = "D"
	day_icon.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BASE)
	day_icon.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_DIM)
	day_container.add_child(day_icon)

	_day_time_label = Label.new()
	_day_time_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BASE)
	day_container.add_child(_day_time_label)

	# Vertical separator
	stats_container.add_child(_create_vseparator())

	# Reputation Display
	var rep_container = HBoxContainer.new()
	rep_container.add_theme_constant_override("separation", 6)
	stats_container.add_child(rep_container)

	var rep_label = Label.new()
	rep_label.text = "Rep:"
	rep_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BASE)
	rep_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	rep_container.add_child(rep_label)

	_reputation_button = Button.new()
	_reputation_button.flat = true
	_reputation_button.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BASE)
	_reputation_button.pressed.connect(_on_reputation_pressed)
	_reputation_button.tooltip_text = "Course reputation (click for rating details)"
	rep_container.add_child(_reputation_button)

	# Vertical separator
	stats_container.add_child(_create_vseparator())

	# Course Rating Display (clickable)
	var rating_container = HBoxContainer.new()
	rating_container.add_theme_constant_override("separation", 4)
	stats_container.add_child(rating_container)

	_rating_button = Button.new()
	_rating_button.flat = true
	_rating_button.text = "-- (-.--)"
	_rating_button.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BASE)
	_rating_button.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_DIM)
	_rating_button.pressed.connect(_on_rating_pressed)
	_rating_button.tooltip_text = "Course rating (click for details)"
	rating_container.add_child(_rating_button)

	# Vertical separator
	stats_container.add_child(_create_vseparator())

	# Weather Display
	var weather_container = HBoxContainer.new()
	weather_container.add_theme_constant_override("separation", 6)
	stats_container.add_child(weather_container)

	_weather_icon = Label.new()
	_weather_icon.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BASE)
	weather_container.add_child(_weather_icon)

	_weather_label = Label.new()
	_weather_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BASE)
	weather_container.add_child(_weather_label)

	# Vertical separator
	stats_container.add_child(_create_vseparator())

	# Wind Display
	var wind_container = HBoxContainer.new()
	wind_container.add_theme_constant_override("separation", 6)
	stats_container.add_child(wind_container)

	var wind_icon = Label.new()
	wind_icon.text = "~"
	wind_icon.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BASE)
	wind_icon.add_theme_color_override("font_color", UIConstants.COLOR_INFO)
	wind_container.add_child(wind_icon)

	_wind_label = Label.new()
	_wind_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BASE)
	wind_container.add_child(_wind_label)

	# Right spacer
	var spacer_right = Control.new()
	spacer_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer_right)

func _create_vseparator() -> VSeparator:
	var sep = VSeparator.new()
	sep.custom_minimum_size = Vector2(1, 20)
	return sep

func _connect_signals() -> void:
	# Connect to EventBus signals
	if has_node("/root/EventBus"):
		var eb = get_node("/root/EventBus")
		eb.money_changed.connect(_on_money_changed)
		eb.day_changed.connect(_on_day_changed)
		eb.hour_changed.connect(_on_hour_changed)
		eb.reputation_changed.connect(_on_reputation_changed)
		eb.weather_changed.connect(_on_weather_changed)
		eb.wind_changed.connect(_on_wind_changed)
		eb.game_mode_changed.connect(_on_game_mode_changed)

func _update_all() -> void:
	_update_game_mode()
	_update_money()
	_update_day_time()
	_update_reputation()
	_update_weather()
	_update_wind()

func _update_game_mode() -> void:
	if not has_node("/root/GameManager"):
		return
	var gm = get_node("/root/GameManager")
	var mode = gm.get("current_mode")
	if mode == null:
		mode = 0

	# GameManager.GameMode enum: MAIN_MENU=0, BUILDING=1, SIMULATING=2, PLAYING=3, PAUSED=4
	match mode:
		1:  # BUILDING
			_game_mode_icon.text = "#"
			_game_mode_label.text = "BUILD MODE"
			_game_mode_icon.add_theme_color_override("font_color", UIConstants.COLOR_WARNING)
			_game_mode_label.add_theme_color_override("font_color", UIConstants.COLOR_WARNING)
		2, 3:  # SIMULATING, PLAYING
			_game_mode_icon.text = ">"
			_game_mode_label.text = "PLAYING"
			_game_mode_icon.add_theme_color_override("font_color", UIConstants.COLOR_SUCCESS)
			_game_mode_label.add_theme_color_override("font_color", UIConstants.COLOR_SUCCESS)
		4:  # PAUSED
			_game_mode_icon.text = "||"
			_game_mode_label.text = "PAUSED"
			_game_mode_icon.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_DIM)
			_game_mode_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_DIM)
		_:
			_game_mode_icon.text = "?"
			_game_mode_label.text = "MENU"
			_game_mode_icon.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_DIM)
			_game_mode_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_DIM)

func _update_money() -> void:
	if not has_node("/root/GameManager"):
		return
	var gm = get_node("/root/GameManager")
	var money = gm.get("money")
	if money == null:
		money = 50000

	_money_button.text = "$ %s" % _format_number(money)

	# Color based on balance
	if money < 0:
		_money_button.add_theme_color_override("font_color", UIConstants.COLOR_DANGER)
	elif money < 5000:
		_money_button.add_theme_color_override("font_color", UIConstants.COLOR_WARNING)
	else:
		_money_button.add_theme_color_override("font_color", UIConstants.COLOR_SUCCESS)

	# Trend indicator
	if _money_trend_value > 0:
		_money_trend.text = "^"
		_money_trend.add_theme_color_override("font_color", UIConstants.COLOR_SUCCESS)
	elif _money_trend_value < 0:
		_money_trend.text = "v"
		_money_trend.add_theme_color_override("font_color", UIConstants.COLOR_DANGER)
	else:
		_money_trend.text = ""

	_last_money = money

func _update_day_time() -> void:
	if not has_node("/root/GameManager"):
		return
	var gm = get_node("/root/GameManager")
	var day = gm.get("current_day")
	var hour = gm.get("current_hour")
	if day == null:
		day = 1
	if hour == null:
		hour = 6.0

	var hour_int = int(hour)
	var minute = int((hour - hour_int) * 60)
	var am_pm = "AM" if hour_int < 12 else "PM"
	var display_hour = hour_int if hour_int <= 12 else hour_int - 12
	if display_hour == 0:
		display_hour = 12

	var season = SeasonSystem.get_season(day)
	var season_name = SeasonSystem.get_season_name(season)
	var day_in_season = SeasonSystem.get_day_in_season(day)
	var year = SeasonSystem.get_year(day)
	_day_time_label.text = "%s D%d Y%d - %d:%02d %s" % [season_name, day_in_season, year, display_hour, minute, am_pm]

func _update_reputation() -> void:
	if not has_node("/root/GameManager"):
		return
	var gm = get_node("/root/GameManager")
	var rep = gm.get("reputation")
	if rep == null:
		rep = 50.0

	_reputation_button.text = "%d%%" % int(rep)

	# Color based on reputation
	if rep >= 75:
		_reputation_button.add_theme_color_override("font_color", UIConstants.COLOR_SUCCESS)
	elif rep >= 40:
		_reputation_button.add_theme_color_override("font_color", UIConstants.COLOR_WARNING)
	else:
		_reputation_button.add_theme_color_override("font_color", UIConstants.COLOR_DANGER)

func _update_weather() -> void:
	if not has_node("/root/GameManager"):
		_weather_icon.text = "* *"
		_weather_label.text = "Sunny"
		return

	var gm = get_node("/root/GameManager")
	var weather_system = gm.get("weather_system")
	if weather_system == null:
		_weather_icon.text = "* *"
		_weather_label.text = "Sunny"
		return

	var weather_type = weather_system.get("weather_type")
	if weather_type == null:
		weather_type = 0

	_weather_icon.text = UIConstants.get_weather_icon(weather_type)
	_weather_label.text = UIConstants.get_weather_name(weather_type)

	# Color based on weather
	match weather_type:
		0:  # SUNNY
			_weather_icon.add_theme_color_override("font_color", UIConstants.COLOR_WARNING)
		1, 2:  # PARTLY_CLOUDY, OVERCAST
			_weather_icon.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_DIM)
		_:  # RAIN
			_weather_icon.add_theme_color_override("font_color", UIConstants.COLOR_INFO)

func _update_wind() -> void:
	if not has_node("/root/GameManager"):
		_wind_label.text = "0 mph"
		return

	var gm = get_node("/root/GameManager")
	var wind_system = gm.get("wind_system")
	if wind_system == null:
		_wind_label.text = "0 mph"
		return

	var speed = wind_system.get("wind_speed")
	var direction = wind_system.get("wind_direction")
	if speed == null:
		speed = 0.0
	if direction == null:
		direction = 0.0

	# Convert radians to degrees for direction name
	var degrees = fmod(rad_to_deg(direction) + 360.0, 360.0)
	var dir_name = _get_direction_name(degrees)
	_wind_label.text = "%s %d mph" % [dir_name, int(speed)]

	# Color based on wind speed
	if speed < 5:
		_wind_label.add_theme_color_override("font_color", UIConstants.COLOR_SUCCESS)
	elif speed < 15:
		_wind_label.add_theme_color_override("font_color", UIConstants.COLOR_WARNING)
	else:
		_wind_label.add_theme_color_override("font_color", UIConstants.COLOR_DANGER)

func _get_direction_name(degrees: float) -> String:
	var dirs = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
	var index = int(round(degrees / 45.0)) % 8
	return dirs[index]

func _format_number(num: int) -> String:
	var str_num = str(abs(num))
	var result = ""
	var count = 0
	for i in range(str_num.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = str_num[i] + result
		count += 1
	if num < 0:
		result = "-" + result
	return result

# Signal handlers
func _on_money_pressed() -> void:
	money_clicked.emit()

func _on_reputation_pressed() -> void:
	reputation_clicked.emit()

func _on_rating_pressed() -> void:
	rating_clicked.emit()

func update_rating(stars: float) -> void:
	var display := CourseRatingSystem.get_star_display(stars)
	_rating_button.text = "%s (%.1f)" % [display, stars]
	if stars >= 4.0:
		_rating_button.add_theme_color_override("font_color", UIConstants.COLOR_GOLD)
	elif stars >= 3.0:
		_rating_button.add_theme_color_override("font_color", UIConstants.COLOR_SUCCESS)
	elif stars >= 2.0:
		_rating_button.add_theme_color_override("font_color", UIConstants.COLOR_WARNING)
	else:
		_rating_button.add_theme_color_override("font_color", UIConstants.COLOR_DANGER)

func _on_money_changed(old_amount: int, new_amount: int) -> void:
	_money_trend_value = new_amount - old_amount
	_update_money()

func _on_day_changed(_new_day: int) -> void:
	_update_day_time()

func _on_hour_changed(_new_hour: float) -> void:
	_update_day_time()

func _on_reputation_changed(_old_rep: float, _new_rep: float) -> void:
	_update_reputation()

func _on_weather_changed(_weather_type: int, _intensity: float) -> void:
	_update_weather()

func _on_wind_changed(_direction: float, _speed: float) -> void:
	_update_wind()

func _on_game_mode_changed(_old_mode: int, _new_mode: int) -> void:
	_update_game_mode()
