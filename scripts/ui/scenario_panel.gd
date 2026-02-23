extends CenteredPanel
class_name ScenarioPanel
## ScenarioPanel - Scenario selection and in-game objectives display

signal scenario_selected(scenario_id: String, theme_type: int)

var _content_container: VBoxContainer = null
var _scenario_system: ScenarioSystem = null
var _scenario_list: VBoxContainer = null
var _detail_container: VBoxContainer = null
var _selected_scenario_id: String = ""

func setup(system: ScenarioSystem) -> void:
	_scenario_system = system

func _build_ui() -> void:
	custom_minimum_size = Vector2(520, 480)

	var style = StyleBoxFlat.new()
	style.bg_color = UIConstants.COLOR_BG_PANEL
	style.border_color = UIConstants.COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = UIConstants.MARGIN_LG
	style.content_margin_right = UIConstants.MARGIN_LG
	style.content_margin_top = UIConstants.MARGIN_MD
	style.content_margin_bottom = UIConstants.MARGIN_LG
	add_theme_stylebox_override("panel", style)

	_content_container = VBoxContainer.new()
	_content_container.add_theme_constant_override("separation", UIConstants.SEPARATION_MD)
	add_child(_content_container)

	# Header
	var header = HBoxContainer.new()
	_content_container.add_child(header)

	var title = Label.new()
	title.text = "Scenarios"
	title.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_LG)
	title.add_theme_color_override("font_color", UIConstants.COLOR_GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(28, 28)
	close_btn.pressed.connect(func(): hide())
	header.add_child(close_btn)

	# Main layout: list on left, details on right
	var main_split = HSplitContainer.new()
	main_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_container.add_child(main_split)

	# Scenario list (scrollable)
	var list_scroll = ScrollContainer.new()
	list_scroll.custom_minimum_size = Vector2(200, 350)
	main_split.add_child(list_scroll)

	_scenario_list = VBoxContainer.new()
	_scenario_list.add_theme_constant_override("separation", 4)
	_scenario_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.add_child(_scenario_list)

	# Detail panel
	var detail_scroll = ScrollContainer.new()
	detail_scroll.custom_minimum_size = Vector2(280, 350)
	main_split.add_child(detail_scroll)

	_detail_container = VBoxContainer.new()
	_detail_container.add_theme_constant_override("separation", UIConstants.SEPARATION_SM)
	_detail_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.add_child(_detail_container)

func show_centered() -> void:
	_refresh_list()
	super.show_centered()

func _refresh_list() -> void:
	if not _scenario_system or not _scenario_list:
		return

	for child in _scenario_list.get_children():
		child.queue_free()

	for scenario in ScenarioSystem.SCENARIOS:
		var sid = scenario["id"]
		var unlocked = _scenario_system.is_scenario_unlocked(sid)
		var stars = _scenario_system.get_scenario_stars(sid)

		var btn = Button.new()
		btn.custom_minimum_size = Vector2(180, 32)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

		var star_str = ""
		if stars > 0:
			for i in range(stars):
				star_str += "*"
			star_str = " [%s]" % star_str

		if unlocked:
			btn.text = "%s%s" % [scenario["name"], star_str]
			btn.pressed.connect(_on_scenario_clicked.bind(sid))
		else:
			btn.text = "[Locked] %s" % scenario["name"]
			btn.disabled = true
			btn.add_theme_color_override("font_disabled_color", Color(0.4, 0.4, 0.4))

		# Highlight active scenario
		if _scenario_system.is_scenario_active and _scenario_system.current_scenario_id == sid:
			btn.add_theme_color_override("font_color", UIConstants.COLOR_GOLD)

		_scenario_list.add_child(btn)

func _on_scenario_clicked(scenario_id: String) -> void:
	_selected_scenario_id = scenario_id
	_show_scenario_detail(scenario_id)

func _show_scenario_detail(scenario_id: String) -> void:
	if not _detail_container:
		return

	for child in _detail_container.get_children():
		child.queue_free()

	var scenario = _scenario_system.get_scenario(scenario_id)
	if scenario.is_empty():
		return

	# Title
	var name_label = Label.new()
	name_label.text = scenario["name"]
	name_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_LG)
	name_label.add_theme_color_override("font_color", UIConstants.COLOR_GOLD)
	_detail_container.add_child(name_label)

	# Description
	var desc_label = Label.new()
	desc_label.text = scenario["description"]
	desc_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
	desc_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_detail_container.add_child(desc_label)

	_detail_container.add_child(HSeparator.new())

	# Info
	var theme_type = scenario.get("theme", -1)
	var theme_text = "Your choice" if theme_type < 0 else CourseTheme.get_theme_name(theme_type)
	_add_detail_row("Theme:", theme_text)
	_add_detail_row("Starting Money:", "$%d" % scenario.get("starting_money", 50000))

	var time_limit = scenario.get("time_limit_days", 0)
	if time_limit > 0:
		_add_detail_row("Time Limit:", "%d days" % time_limit)
	else:
		_add_detail_row("Time Limit:", "None")

	_detail_container.add_child(HSeparator.new())

	# Objectives
	var obj_title = Label.new()
	obj_title.text = "Objectives:"
	obj_title.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
	obj_title.add_theme_color_override("font_color", UIConstants.COLOR_TEXT)
	_detail_container.add_child(obj_title)

	var objectives = scenario.get("objectives", [])
	for obj in objectives:
		var obj_label = Label.new()
		obj_label.text = "  - %s" % obj.get("label", "")
		obj_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
		obj_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_DIM)
		_detail_container.add_child(obj_label)

	# Star conditions
	_detail_container.add_child(HSeparator.new())
	var stars_title = Label.new()
	stars_title.text = "Star Rating:"
	stars_title.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
	stars_title.add_theme_color_override("font_color", UIConstants.COLOR_TEXT)
	_detail_container.add_child(stars_title)

	var star1 = Label.new()
	star1.text = "  * Complete all objectives"
	star1.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
	star1.add_theme_color_override("font_color", Color(0.8, 0.6, 0.3))
	_detail_container.add_child(star1)

	var star_2 = scenario.get("star_2", {})
	if not star_2.is_empty():
		var star2 = Label.new()
		star2.text = "  ** %s" % _format_star_conditions(star_2)
		star2.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
		star2.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		_detail_container.add_child(star2)

	var star_3 = scenario.get("star_3", {})
	if not star_3.is_empty():
		var star3 = Label.new()
		star3.text = "  *** %s" % _format_star_conditions(star_3)
		star3.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
		star3.add_theme_color_override("font_color", UIConstants.COLOR_GOLD)
		_detail_container.add_child(star3)

	# Current stars
	var earned = _scenario_system.get_scenario_stars(scenario_id)
	if earned > 0:
		var earned_label = Label.new()
		var earned_str = ""
		for i in range(earned):
			earned_str += "*"
		earned_label.text = "Your rating: %s" % earned_str
		earned_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
		earned_label.add_theme_color_override("font_color", UIConstants.COLOR_SUCCESS)
		_detail_container.add_child(earned_label)

	_detail_container.add_child(HSeparator.new())

	# Play button
	var play_btn = Button.new()
	play_btn.text = "Play Scenario"
	play_btn.custom_minimum_size = Vector2(200, 36)
	play_btn.pressed.connect(_on_play_pressed.bind(scenario_id, theme_type))
	_detail_container.add_child(play_btn)

func _add_detail_row(label_text: String, value_text: String) -> void:
	var row = HBoxContainer.new()
	_detail_container.add_child(row)

	var label = Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
	label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_DIM)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var value = Label.new()
	value.text = value_text
	value.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
	value.add_theme_color_override("font_color", UIConstants.COLOR_TEXT)
	row.add_child(value)

func _format_star_conditions(conditions: Dictionary) -> String:
	var parts: Array = []
	for key in conditions.keys():
		var val = conditions[key]
		match key:
			"total_profit":
				parts.append("$%d profit" % val)
			"reputation":
				parts.append("%d+ reputation" % val)
			"rating_stars":
				parts.append("%d-star rating" % val)
			"money":
				parts.append("$%d balance" % val)
	return " + ".join(parts)

func _on_play_pressed(scenario_id: String, theme_type: int) -> void:
	hide()
	scenario_selected.emit(scenario_id, theme_type)
