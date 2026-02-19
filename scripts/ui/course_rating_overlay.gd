extends CenteredPanel
class_name CourseRatingOverlay
## CourseRatingOverlay - Shows detailed course rating breakdown
##
## Displays overall star rating and category breakdown. Opened by clicking
## the star rating in the top bar.

signal close_requested
signal rating_updated(stars: float)

const PANEL_WIDTH := 240.0

var _overall_label: Label = null
var _condition_label: Label = null
var _design_label: Label = null
var _value_label: Label = null
var _difficulty_label: Label = null

func _build_ui() -> void:
	custom_minimum_size = Vector2(PANEL_WIDTH, 0)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.06, 0.95)
	style.border_color = UIConstants.COLOR_PRIMARY
	style.set_border_width_all(1)
	style.border_width_left = 2
	style.set_corner_radius_all(6)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	# Title row with close button
	var title_row := HBoxContainer.new()
	vbox.add_child(title_row)

	var title := Label.new()
	title.text = "Course Rating"
	title.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_MD)
	title.add_theme_color_override("font_color", UIConstants.COLOR_GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(30, 30)
	close_btn.pressed.connect(_on_close_pressed)
	title_row.add_child(close_btn)

	vbox.add_child(HSeparator.new())

	_overall_label = _add_row(vbox, "Overall:", "---")
	_condition_label = _add_row(vbox, "Condition:", "---")
	_design_label = _add_row(vbox, "Design:", "---")
	_value_label = _add_row(vbox, "Value:", "---")
	_difficulty_label = _add_row(vbox, "Difficulty:", "---")

func _add_row(parent: VBoxContainer, label_text: String, initial_value: String) -> Label:
	var row := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
	lbl.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_DIM)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)

	var val := Label.new()
	val.text = initial_value
	val.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
	val.add_theme_color_override("font_color", UIConstants.COLOR_TEXT)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val)

	parent.add_child(row)
	return val

func _update_rating() -> void:
	if not GameManager.current_course or not GameManager.terrain_grid:
		return

	var rating := CourseRatingSystem.calculate_rating(
		GameManager.terrain_grid,
		GameManager.current_course,
		GameManager.daily_stats,
		GameManager.green_fee,
		GameManager.reputation
	)

	var stars: float = rating.get("overall", 3.0)
	_overall_label.text = "%s (%.1f)" % [CourseRatingSystem.get_star_display(stars), stars]
	_overall_label.add_theme_color_override("font_color", _star_color(stars))

	_condition_label.text = "%.1f" % rating.get("condition", 0.0)
	_design_label.text = "%.1f" % rating.get("design", 0.0)
	_value_label.text = "%.1f" % rating.get("value", 0.0)

	var diff: float = rating.get("difficulty", 5.0)
	_difficulty_label.text = "%s (%.1f)" % [CourseRatingSystem.get_difficulty_text(diff), diff]

	rating_updated.emit(stars)

func _star_color(stars: float) -> Color:
	if stars >= 4.0:
		return UIConstants.COLOR_GOLD
	elif stars >= 3.0:
		return UIConstants.COLOR_SUCCESS
	elif stars >= 2.0:
		return UIConstants.COLOR_WARNING
	return UIConstants.COLOR_DANGER

func _on_close_pressed() -> void:
	close_requested.emit()
	hide()

func toggle() -> void:
	if visible:
		hide()
	else:
		_update_rating()
		show_centered()
