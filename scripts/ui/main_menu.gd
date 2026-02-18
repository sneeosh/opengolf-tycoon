extends Control
class_name MainMenu
## MainMenu - Title screen with New Game (theme selection), Load, and Quit

signal new_game_requested(course_name: String, theme_type: int)
signal load_game_requested()
signal settings_requested()

var _theme_cards: Array = []
var _selected_theme: int = CourseTheme.Type.PARKLAND
var _course_name_input: LineEdit = null

func _ready() -> void:
	# Full-screen dark background
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.12, 0.08, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Center everything in a VBoxContainer
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 20)
	main_vbox.custom_minimum_size = Vector2(900, 600)
	center.add_child(main_vbox)

	# Title
	var title = Label.new()
	title.text = "OpenGolf Tycoon"
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.85, 0.95, 0.75))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(title)

	# Subtitle
	var subtitle = Label.new()
	subtitle.text = "Design. Build. Manage."
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.6, 0.7, 0.5))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(subtitle)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	main_vbox.add_child(spacer)

	# Course name input
	var name_row = HBoxContainer.new()
	name_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var name_label = Label.new()
	name_label.text = "Course Name: "
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.7))
	name_row.add_child(name_label)

	_course_name_input = LineEdit.new()
	_course_name_input.text = "My Golf Course"
	_course_name_input.custom_minimum_size = Vector2(300, 35)
	_course_name_input.add_theme_font_size_override("font_size", 16)
	name_row.add_child(_course_name_input)
	main_vbox.add_child(name_row)

	# Theme selection label
	var theme_label = Label.new()
	theme_label.text = "Select Course Theme"
	theme_label.add_theme_font_size_override("font_size", 20)
	theme_label.add_theme_color_override("font_color", Color(0.8, 0.9, 0.7))
	theme_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(theme_label)

	# Theme cards grid (3x2)
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	main_vbox.add_child(grid)

	for theme_type in CourseTheme.get_all_types():
		var card = _create_theme_card(theme_type)
		grid.add_child(card)
		_theme_cards.append(card)

	# Update initial selection visual
	_update_card_selection()

	# Buttons row
	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 20)
	main_vbox.add_child(btn_row)

	# Continue button - only visible if saves exist
	var saves = SaveManager.get_save_list()
	if not saves.is_empty():
		var continue_btn = Button.new()
		var latest = saves[0]
		continue_btn.text = "Continue"
		continue_btn.tooltip_text = "%s - Day %d" % [latest.get("course_name", ""), latest.get("day", 0)]
		continue_btn.custom_minimum_size = Vector2(160, 45)
		continue_btn.add_theme_font_size_override("font_size", 18)
		continue_btn.pressed.connect(_on_continue_pressed.bind(latest.get("name", "")))
		btn_row.add_child(continue_btn)

	var start_btn = Button.new()
	start_btn.text = "Start New Game"
	start_btn.custom_minimum_size = Vector2(200, 45)
	start_btn.add_theme_font_size_override("font_size", 18)
	start_btn.pressed.connect(_on_start_pressed)
	btn_row.add_child(start_btn)

	var load_btn = Button.new()
	load_btn.text = "Load Game"
	load_btn.custom_minimum_size = Vector2(150, 45)
	load_btn.add_theme_font_size_override("font_size", 16)
	load_btn.pressed.connect(_on_load_pressed)
	btn_row.add_child(load_btn)

	var settings_btn = Button.new()
	settings_btn.text = "Settings"
	settings_btn.custom_minimum_size = Vector2(120, 45)
	settings_btn.add_theme_font_size_override("font_size", 16)
	settings_btn.pressed.connect(_on_settings_pressed)
	btn_row.add_child(settings_btn)

	var quit_btn = Button.new()
	quit_btn.text = "Quit"
	quit_btn.custom_minimum_size = Vector2(100, 45)
	quit_btn.add_theme_font_size_override("font_size", 16)
	quit_btn.pressed.connect(_on_quit_pressed)
	btn_row.add_child(quit_btn)

	# Version label
	var version = Label.new()
	version.text = "v0.1.0 Alpha"
	version.add_theme_font_size_override("font_size", 12)
	version.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(version)

func _create_theme_card(theme_type: int) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(280, 100)
	card.set_meta("theme_type", theme_type)

	# Make clickable
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(_on_card_input.bind(theme_type))

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	# Theme name with accent color
	var accent = CourseTheme.get_accent_color(theme_type)
	var name_label = Label.new()
	name_label.text = CourseTheme.get_theme_name(theme_type)
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", accent)
	vbox.add_child(name_label)

	# Description
	var desc = Label.new()
	desc.text = CourseTheme.get_description(theme_type)
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.65))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.custom_minimum_size = Vector2(250, 0)
	vbox.add_child(desc)

	# Modifier hints
	var modifiers = CourseTheme.get_gameplay_modifiers(theme_type)
	var hints = []
	if modifiers.wind_base_strength > 1.2:
		hints.append("Strong wind")
	elif modifiers.wind_base_strength < 0.8:
		hints.append("Calm wind")
	if modifiers.distance_modifier > 1.02:
		hints.append("+Distance")
	if modifiers.maintenance_cost_multiplier < 0.8:
		hints.append("Low upkeep")
	elif modifiers.maintenance_cost_multiplier > 1.2:
		hints.append("High upkeep")
	if modifiers.green_fee_baseline >= 50:
		hints.append("Premium fees")
	elif modifiers.green_fee_baseline <= 20:
		hints.append("Budget fees")

	if not hints.is_empty():
		var hint_label = Label.new()
		hint_label.text = " | ".join(hints)
		hint_label.add_theme_font_size_override("font_size", 10)
		hint_label.add_theme_color_override("font_color", Color(0.5, 0.6, 0.5))
		vbox.add_child(hint_label)

	return card

func _on_card_input(event: InputEvent, theme_type: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_selected_theme = theme_type
		_update_card_selection()

func _update_card_selection() -> void:
	for card in _theme_cards:
		var theme_type = card.get_meta("theme_type")
		var style = StyleBoxFlat.new()

		if theme_type == _selected_theme:
			var accent = CourseTheme.get_accent_color(theme_type)
			style.bg_color = Color(0.15, 0.22, 0.15, 1.0)
			style.border_color = accent
			style.set_border_width_all(2)
		else:
			style.bg_color = Color(0.12, 0.15, 0.12, 1.0)
			style.border_color = Color(0.3, 0.3, 0.3)
			style.set_border_width_all(1)

		style.set_corner_radius_all(6)
		card.add_theme_stylebox_override("panel", style)

func _on_continue_pressed(save_name: String) -> void:
	SaveManager.load_game(save_name)

func _on_start_pressed() -> void:
	var course_name = _course_name_input.text.strip_edges()
	if course_name.is_empty():
		course_name = "My Golf Course"
	new_game_requested.emit(course_name, _selected_theme)

func _on_load_pressed() -> void:
	load_game_requested.emit()

func _on_settings_pressed() -> void:
	settings_requested.emit()

func _on_quit_pressed() -> void:
	get_tree().quit()
