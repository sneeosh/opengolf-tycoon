extends Control
class_name GameOverPanel
## GameOverPanel - Shown when the player goes bankrupt (money < -$1000)
##
## Displays game statistics celebrating what the player achieved,
## with options to retry (new game) or load a save.

signal retry_requested
signal load_requested
signal quit_to_menu_requested

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()

func _build_ui() -> void:
	# Dark overlay
	var bg = ColorRect.new()
	bg.color = Color(0.05, 0.0, 0.0, 0.75)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.08, 0.08, 0.95)
	style.border_color = UIConstants.COLOR_DANGER
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(450, 0)
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "Course Closed"
	title.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_XL)
	title.add_theme_color_override("font_color", UIConstants.COLOR_DANGER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Subtitle
	var subtitle = Label.new()
	subtitle.text = "Your course has gone bankrupt."
	subtitle.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BASE)
	subtitle.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_DIM)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	vbox.add_child(HSeparator.new())

	# Stats section - celebrate what the player achieved
	var stats_label = Label.new()
	stats_label.text = "Your Legacy"
	stats_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_MD)
	stats_label.add_theme_color_override("font_color", UIConstants.COLOR_GOLD)
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(stats_label)

	# Gather stats
	var days = GameManager.current_day
	var holes = GameManager.current_course.holes.size() if GameManager.current_course else 0
	var rating = GameManager.course_rating.get("stars", 0)
	var total_hio = GameManager.course_records.get("total_hole_in_ones", 0)
	var best_round = GameManager.course_records.get("lowest_round")

	_add_stat_row(vbox, "Days Survived", str(days))
	_add_stat_row(vbox, "Holes Built", str(holes))
	_add_stat_row(vbox, "Best Course Rating", "%d star%s" % [rating, "s" if rating != 1 else ""])

	if total_hio > 0:
		_add_stat_row(vbox, "Holes-in-One Witnessed", str(total_hio))

	if best_round and best_round is CourseRecords.RecordEntry:
		_add_stat_row(vbox, "Course Record", "%d strokes by %s" % [best_round.value, best_round.golfer_name])

	var season_name = SeasonSystem.get_season_name(SeasonSystem.get_season(days))
	var year = SeasonSystem.get_year(days)
	_add_stat_row(vbox, "Final Season", "%s, Year %d" % [season_name, year])

	vbox.add_child(HSeparator.new())

	# Buttons
	var btn_box = VBoxContainer.new()
	btn_box.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_box)

	var retry_btn = Button.new()
	retry_btn.text = "Start New Game"
	retry_btn.custom_minimum_size = Vector2(300, 40)
	retry_btn.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_MD)
	retry_btn.pressed.connect(func(): retry_requested.emit())
	btn_box.add_child(retry_btn)

	var load_btn = Button.new()
	load_btn.text = "Load Saved Game"
	load_btn.custom_minimum_size = Vector2(300, 40)
	load_btn.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_MD)
	load_btn.pressed.connect(func(): load_requested.emit())
	btn_box.add_child(load_btn)

	var quit_btn = Button.new()
	quit_btn.text = "Quit to Menu"
	quit_btn.custom_minimum_size = Vector2(300, 40)
	quit_btn.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BASE)
	quit_btn.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_DIM)
	quit_btn.pressed.connect(func(): quit_to_menu_requested.emit())
	btn_box.add_child(quit_btn)

func _add_stat_row(parent: VBoxContainer, label_text: String, value_text: String) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var label = Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BASE)
	label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_DIM)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var value = Label.new()
	value.text = value_text
	value.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BASE)
	value.add_theme_color_override("font_color", UIConstants.COLOR_TEXT)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)

	parent.add_child(row)
