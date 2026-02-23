extends CenteredPanel
class_name AwardsPanel
## AwardsPanel - Displays end-of-year awards ceremony and hall of fame
##
## Two views: ceremony (current year awards) and hall of fame (all-time awards).

var _content_container: VBoxContainer = null
var _awards_list: VBoxContainer = null
var _awards_system: AwardsSystem = null
var _showing_hall_of_fame: bool = false
var _toggle_btn: Button = null
var _title_label: Label = null
var _summary_label: Label = null

func setup(awards: AwardsSystem) -> void:
	_awards_system = awards
	if _awards_system:
		_awards_system.awards_generated.connect(_on_awards_generated)

func _build_ui() -> void:
	custom_minimum_size = Vector2(500, 350)

	var style = StyleBoxFlat.new()
	style.bg_color = UIConstants.COLOR_BG_PANEL
	style.border_color = UIConstants.COLOR_GOLD
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = UIConstants.MARGIN_LG
	style.content_margin_right = UIConstants.MARGIN_LG
	style.content_margin_top = UIConstants.MARGIN_MD
	style.content_margin_bottom = UIConstants.MARGIN_LG
	add_theme_stylebox_override("panel", style)

	_content_container = VBoxContainer.new()
	_content_container.add_theme_constant_override("separation", UIConstants.SEPARATION_LG)
	add_child(_content_container)

	# Header
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", UIConstants.SEPARATION_LG)
	_content_container.add_child(header)

	_title_label = Label.new()
	_title_label.text = "Awards Ceremony"
	_title_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_LG)
	_title_label.add_theme_color_override("font_color", UIConstants.COLOR_GOLD)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)

	_toggle_btn = Button.new()
	_toggle_btn.text = "Hall of Fame"
	_toggle_btn.custom_minimum_size = Vector2(100, 28)
	_toggle_btn.pressed.connect(_toggle_view)
	header.add_child(_toggle_btn)

	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(28, 28)
	close_btn.pressed.connect(func(): hide())
	header.add_child(close_btn)

	# Summary line
	_summary_label = Label.new()
	_summary_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
	_summary_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_DIM)
	_content_container.add_child(_summary_label)

	# Separator
	var sep = HSeparator.new()
	_content_container.add_child(sep)

	# Scrollable awards list
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(460, 250)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_container.add_child(scroll)

	_awards_list = VBoxContainer.new()
	_awards_list.add_theme_constant_override("separation", UIConstants.SEPARATION_MD)
	_awards_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_awards_list)

func _on_awards_generated(awards: Array, year: int) -> void:
	_showing_hall_of_fame = false
	_show_ceremony(awards, year)
	show_centered()

func _toggle_view() -> void:
	_showing_hall_of_fame = not _showing_hall_of_fame
	if _showing_hall_of_fame:
		_show_hall_of_fame()
	elif _awards_system and not _awards_system.latest_awards.is_empty():
		var year = _awards_system.latest_awards[0].year if not _awards_system.latest_awards.is_empty() else 0
		_show_ceremony(_awards_system.latest_awards, year)
	else:
		_show_hall_of_fame()

func _show_ceremony(awards: Array, year: int) -> void:
	_title_label.text = "Year %d Awards Ceremony" % year
	_toggle_btn.text = "Hall of Fame"

	var counts = {"gold": 0, "silver": 0, "bronze": 0}
	for a in awards:
		match a.tier:
			2: counts.gold += 1
			1: counts.silver += 1
			0: counts.bronze += 1
	_summary_label.text = "Gold: %d | Silver: %d | Bronze: %d" % [counts.gold, counts.silver, counts.bronze]

	_clear_list()
	if awards.is_empty():
		_add_empty_label("No awards earned this year. Keep improving!")
		return

	for award in awards:
		_awards_list.add_child(_create_award_row(award))

func _show_hall_of_fame() -> void:
	_title_label.text = "Hall of Fame"
	_toggle_btn.text = "Latest Awards"

	if not _awards_system or _awards_system.hall_of_fame.is_empty():
		_summary_label.text = "Complete your first year to earn awards."
		_clear_list()
		_add_empty_label("No awards yet. Awards are given at the end of each year (every 28 days).")
		return

	var counts = _awards_system.get_award_counts()
	_summary_label.text = "All-Time: Gold: %d | Silver: %d | Bronze: %d" % [counts.gold, counts.silver, counts.bronze]

	_clear_list()

	# Group by year (newest first)
	var years: Array = []
	for award in _awards_system.hall_of_fame:
		if award.year not in years:
			years.append(award.year)
	years.sort()
	years.reverse()

	for year in years:
		var year_awards = _awards_system.get_awards_for_year(year)
		if year_awards.is_empty():
			continue

		# Year header
		var year_label = Label.new()
		year_label.text = "--- Year %d ---" % year
		year_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
		year_label.add_theme_color_override("font_color", UIConstants.COLOR_GOLD_DIM)
		year_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_awards_list.add_child(year_label)

		for award in year_awards:
			_awards_list.add_child(_create_award_row(award))

func _create_award_row(award: AwardsSystem.Award) -> PanelContainer:
	var panel = PanelContainer.new()

	var tier_color = _get_tier_color(award.tier)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.14, 0.9)
	style.border_color = tier_color
	style.border_width_left = 3
	style.set_corner_radius_all(3)
	style.content_margin_left = UIConstants.MARGIN_MD
	style.content_margin_right = UIConstants.MARGIN_SM
	style.content_margin_top = UIConstants.MARGIN_SM
	style.content_margin_bottom = UIConstants.MARGIN_SM
	panel.add_theme_stylebox_override("panel", style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", UIConstants.SEPARATION_LG)
	panel.add_child(hbox)

	# Tier icon
	var tier_label = Label.new()
	tier_label.text = _get_tier_icon(award.tier)
	tier_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_LG)
	tier_label.add_theme_color_override("font_color", tier_color)
	tier_label.custom_minimum_size = Vector2(30, 0)
	tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hbox.add_child(tier_label)

	# Text column
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 1)
	hbox.add_child(vbox)

	var title = Label.new()
	title.text = award.title
	title.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
	title.add_theme_color_override("font_color", UIConstants.COLOR_TEXT)
	vbox.add_child(title)

	var desc = Label.new()
	desc.text = award.description
	desc.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_XS)
	desc.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_DIM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.custom_minimum_size = Vector2(320, 0)
	vbox.add_child(desc)

	# Value badge
	var value_label = Label.new()
	value_label.text = award.value
	value_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
	value_label.add_theme_color_override("font_color", tier_color)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.custom_minimum_size = Vector2(80, 0)
	hbox.add_child(value_label)

	return panel

func _get_tier_color(tier: int) -> Color:
	match tier:
		2: return UIConstants.COLOR_GOLD
		1: return Color(0.75, 0.75, 0.78)  # Silver
		0: return Color(0.8, 0.5, 0.2)  # Bronze
	return UIConstants.COLOR_TEXT_DIM

func _get_tier_icon(tier: int) -> String:
	match tier:
		2: return "[G]"
		1: return "[S]"
		0: return "[B]"
	return "[?]"

func _clear_list() -> void:
	for child in _awards_list.get_children():
		child.queue_free()

func _add_empty_label(text: String) -> void:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BASE)
	label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_DIM)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_awards_list.add_child(label)

## Show the hall of fame view directly
func show_hall_of_fame() -> void:
	_showing_hall_of_fame = true
	_show_hall_of_fame()
	show_centered()
