extends PanelContainer
class_name CalendarWidget
## CalendarWidget - Compact date/season display for the top HUD bar
##
## Shows current date, season, and upcoming holidays.

var _date_label: Label = null
var _season_label: Label = null
var _holiday_label: Label = null
var _last_day: int = -1

func _ready() -> void:
	custom_minimum_size = Vector2(180, 50)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.15, 0.9)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 1)
	add_child(vbox)

	_date_label = Label.new()
	_date_label.add_theme_font_size_override("font_size", 12)
	_date_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	vbox.add_child(_date_label)

	_season_label = Label.new()
	_season_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_season_label)

	_holiday_label = Label.new()
	_holiday_label.add_theme_font_size_override("font_size", 10)
	_holiday_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	_holiday_label.visible = false
	vbox.add_child(_holiday_label)

	EventBus.day_changed.connect(_on_day_changed)
	_update_display(GameManager.current_day)

func _exit_tree() -> void:
	if EventBus.day_changed.is_connected(_on_day_changed):
		EventBus.day_changed.disconnect(_on_day_changed)

func _on_day_changed(new_day: int) -> void:
	_update_display(new_day)

func _update_display(day: int) -> void:
	if day == _last_day:
		return
	_last_day = day

	# Date
	_date_label.text = SeasonalCalendar.get_date_string(day)

	# Season with color
	var season = SeasonalCalendar.get_season(day)
	var season_name = SeasonalCalendar.SEASON_NAMES[season]
	var day_in_season = SeasonalCalendar.get_day_in_season(day) + 1
	_season_label.text = "%s (Day %d/90)" % [season_name, day_in_season]
	_season_label.add_theme_color_override("font_color", SeasonalCalendar.get_season_color(season))

	# Holiday
	var holiday = SeasonalCalendar.get_active_holiday(day)
	if not holiday.is_empty():
		_holiday_label.text = holiday.name
		_holiday_label.visible = true
	else:
		var upcoming = SeasonalCalendar.get_upcoming_holidays(day, 7)
		if not upcoming.is_empty():
			_holiday_label.text = "%s in %d days" % [upcoming[0].name, upcoming[0].days_until]
			_holiday_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
			_holiday_label.visible = true
		else:
			_holiday_label.visible = false
