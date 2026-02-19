extends CenteredPanel
class_name SeasonalCalendarPanel
## SeasonalCalendarPanel - Shows seasonal calendar with events and modifiers

signal close_requested

var _content: VBoxContainer = null

func _build_ui() -> void:
	custom_minimum_size = Vector2(480, 420)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Title row
	var title_row = HBoxContainer.new()
	vbox.add_child(title_row)

	var title = Label.new()
	title.text = "Seasonal Calendar"
	title.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_LG)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.pressed.connect(func(): close_requested.emit())
	title_row.add_child(close_btn)

	vbox.add_child(HSeparator.new())

	# Scrollable content
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 6)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_content)

func show_centered() -> void:
	_refresh_display()
	await super.show_centered()

func _refresh_display() -> void:
	for child in _content.get_children():
		child.queue_free()

	var day = GameManager.current_day
	var season = SeasonSystem.get_season(day)
	var day_in_season = SeasonSystem.get_day_in_season(day)
	var year = SeasonSystem.get_year(day)

	# Current status
	var status_box = VBoxContainer.new()
	status_box.add_theme_constant_override("separation", 4)

	var date_label = Label.new()
	date_label.text = "%s, Year %d (Day %d of %d)" % [
		SeasonSystem.get_season_name(season), year,
		day_in_season, SeasonSystem.DAYS_PER_SEASON
	]
	date_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_MD)
	date_label.add_theme_color_override("font_color", SeasonSystem.get_season_color(season))
	status_box.add_child(date_label)

	# Active event
	var active_event = SeasonalEvents.get_active_event(day)
	if active_event:
		var event_label = Label.new()
		event_label.text = "Active: %s" % active_event.name
		event_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BASE)
		event_label.add_theme_color_override("font_color", UIConstants.COLOR_GOLD)
		status_box.add_child(event_label)

		var desc_label = Label.new()
		desc_label.text = active_event.description
		desc_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
		desc_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_DIM)
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		status_box.add_child(desc_label)

		_add_modifier_row(status_box, active_event)

	_content.add_child(status_box)

	# Current season modifiers
	_content.add_child(HSeparator.new())
	var mod_header = Label.new()
	mod_header.text = "Season Modifiers"
	mod_header.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BASE)
	mod_header.add_theme_color_override("font_color", UIConstants.COLOR_INFO)
	_content.add_child(mod_header)

	var spawn_mod = SeasonSystem.get_spawn_modifier(season)
	var maint_mod = SeasonSystem.get_maintenance_modifier(season)
	_add_stat_row(_content, "Golfer Demand", _format_modifier(spawn_mod), _get_modifier_color(spawn_mod))
	_add_stat_row(_content, "Maintenance Cost", _format_modifier(maint_mod), _get_modifier_color(maint_mod, true))

	# Upcoming events
	_content.add_child(HSeparator.new())
	var upcoming_header = Label.new()
	upcoming_header.text = "Upcoming Events"
	upcoming_header.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BASE)
	upcoming_header.add_theme_color_override("font_color", UIConstants.COLOR_INFO)
	_content.add_child(upcoming_header)

	var upcoming = SeasonalEvents.get_upcoming_events(day, 21)
	if upcoming.is_empty():
		var none_label = Label.new()
		none_label.text = "No events in the next 3 weeks."
		none_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
		none_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_MUTED)
		_content.add_child(none_label)
	else:
		for entry in upcoming:
			var event: SeasonalEvents.SeasonEvent = entry.event
			var event_row = VBoxContainer.new()
			event_row.add_theme_constant_override("separation", 2)

			var name_row = HBoxContainer.new()
			var event_name = Label.new()
			event_name.text = event.name
			event_name.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
			event_name.add_theme_color_override("font_color", SeasonSystem.get_season_color(event.season))
			event_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_row.add_child(event_name)

			var days_label = Label.new()
			days_label.text = "in %d day%s" % [entry.days_until, "s" if entry.days_until != 1 else ""]
			days_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
			days_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_DIM)
			name_row.add_child(days_label)
			event_row.add_child(name_row)

			var event_desc = Label.new()
			event_desc.text = event.description
			event_desc.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_XS)
			event_desc.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_MUTED)
			event_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
			event_row.add_child(event_desc)

			_content.add_child(event_row)

	# Full year calendar
	_content.add_child(HSeparator.new())
	var cal_header = Label.new()
	cal_header.text = "Year Overview (28-day year)"
	cal_header.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BASE)
	cal_header.add_theme_color_override("font_color", UIConstants.COLOR_INFO)
	_content.add_child(cal_header)

	for s in range(4):
		_add_season_row(_content, s, season, day_in_season)

func _add_season_row(parent: VBoxContainer, s: int, current_season: int, current_day_in_season: int) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	var name_label = Label.new()
	name_label.text = SeasonSystem.get_season_name(s)
	name_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
	name_label.add_theme_color_override("font_color", SeasonSystem.get_season_color(s))
	name_label.custom_minimum_size = Vector2(60, 0)
	row.add_child(name_label)

	# Day indicators
	for d in range(1, SeasonSystem.DAYS_PER_SEASON + 1):
		var day_box = ColorRect.new()
		day_box.custom_minimum_size = Vector2(14, 14)

		if s == current_season and d == current_day_in_season:
			day_box.color = Color.WHITE
		elif s < current_season or (s == current_season and d < current_day_in_season):
			day_box.color = SeasonSystem.get_season_color(s).darkened(0.6)
		else:
			day_box.color = SeasonSystem.get_season_color(s).darkened(0.3)

		# Check for event on this day
		var has_event = false
		for event in SeasonalEvents.get_season_events(s):
			if d >= event.day_in_season and d < event.day_in_season + event.duration_days:
				has_event = true
				break
		if has_event:
			day_box.color = day_box.color.lightened(0.3)

		row.add_child(day_box)

	# Spawn modifier
	var mod = Label.new()
	mod.text = _format_modifier(SeasonSystem.get_spawn_modifier(s))
	mod.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_XS)
	mod.add_theme_color_override("font_color", _get_modifier_color(SeasonSystem.get_spawn_modifier(s)))
	mod.custom_minimum_size = Vector2(50, 0)
	mod.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(mod)

	parent.add_child(row)

func _add_modifier_row(parent: VBoxContainer, event: SeasonalEvents.SeasonEvent) -> void:
	var mods: Array = []
	if event.revenue_modifier != 1.0:
		mods.append("Revenue %s" % _format_modifier(event.revenue_modifier))
	if event.spawn_modifier != 1.0:
		mods.append("Demand %s" % _format_modifier(event.spawn_modifier))
	if event.reputation_bonus > 0:
		mods.append("+%.0f rep" % event.reputation_bonus)
	if mods.is_empty():
		return
	var mod_label = Label.new()
	mod_label.text = " | ".join(mods)
	mod_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_XS)
	mod_label.add_theme_color_override("font_color", UIConstants.COLOR_SUCCESS_DIM)
	parent.add_child(mod_label)

func _add_stat_row(parent: VBoxContainer, label_text: String, value_text: String, color: Color) -> void:
	var row = HBoxContainer.new()
	var label = Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
	label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_DIM)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var value = Label.new()
	value.text = value_text
	value.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
	value.add_theme_color_override("font_color", color)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	parent.add_child(row)

func _format_modifier(mod: float) -> String:
	if mod > 1.0:
		return "+%d%%" % int((mod - 1.0) * 100)
	elif mod < 1.0:
		return "-%d%%" % int((1.0 - mod) * 100)
	return "Normal"

func _get_modifier_color(mod: float, invert: bool = false) -> Color:
	if invert:
		return UIConstants.COLOR_SUCCESS if mod < 1.0 else (UIConstants.COLOR_DANGER if mod > 1.0 else UIConstants.COLOR_TEXT)
	return UIConstants.COLOR_SUCCESS if mod > 1.0 else (UIConstants.COLOR_DANGER if mod < 1.0 else UIConstants.COLOR_TEXT)
