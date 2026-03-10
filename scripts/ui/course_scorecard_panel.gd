extends CenteredPanel
class_name CourseScorecardPanel
## CourseScorecardPanel - Full course scorecard showing all holes with par, yardage,
## stroke index, and average scores. Modeled after a real golf scorecard.

signal close_requested

# Grid cell styling
const CELL_WIDTH := 36
const LABEL_COL_WIDTH := 54
const TOTAL_COL_WIDTH := 44
const ROW_HEIGHT := 22
const HEADER_FONT_SIZE := 16
const CELL_FONT_SIZE := 11
const LABEL_FONT_SIZE := 11

const BG_SCORECARD := Color(0.12, 0.12, 0.12, 0.98)
const BG_HEADER_ROW := Color(0.18, 0.35, 0.24, 0.9)  # Green header
const BG_DATA_ROW_A := Color(0.14, 0.14, 0.14)
const BG_DATA_ROW_B := Color(0.11, 0.11, 0.11)
const BORDER_COLOR := Color(0.25, 0.25, 0.25)

var _content_vbox: VBoxContainer = null
var _title_label: Label = null
var _subtitle_label: Label = null

func _build_ui() -> void:
	custom_minimum_size = Vector2(480, 300)

	var style = StyleBoxFlat.new()
	style.bg_color = BG_SCORECARD
	style.border_color = BORDER_COLOR
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	add_theme_stylebox_override("panel", style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 6)
	margin.add_child(main_vbox)

	# Title row with close button
	var title_row = HBoxContainer.new()
	main_vbox.add_child(title_row)

	var title_vbox = VBoxContainer.new()
	title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_vbox.add_theme_constant_override("separation", 2)
	title_row.add_child(title_vbox)

	_title_label = Label.new()
	_title_label.text = "Course Scorecard"
	_title_label.add_theme_font_size_override("font_size", HEADER_FONT_SIZE)
	title_vbox.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.text = ""
	_subtitle_label.add_theme_font_size_override("font_size", CELL_FONT_SIZE)
	_subtitle_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_DIM)
	title_vbox.add_child(_subtitle_label)

	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(28, 28)
	close_btn.pressed.connect(_on_close_pressed)
	title_row.add_child(close_btn)

	main_vbox.add_child(HSeparator.new())

	# Scrollable content
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.custom_minimum_size = Vector2(0, 200)
	main_vbox.add_child(scroll)

	_content_vbox = VBoxContainer.new()
	_content_vbox.add_theme_constant_override("separation", 8)
	_content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_content_vbox)

func refresh() -> void:
	_update_display()

func _update_display() -> void:
	if not _content_vbox or not _title_label or not _subtitle_label:
		return

	for child in _content_vbox.get_children():
		child.queue_free()

	if not GameManager.current_course or GameManager.current_course.holes.is_empty():
		_title_label.text = "Course Scorecard"
		_subtitle_label.text = ""
		var no_data = Label.new()
		no_data.text = "No holes created yet"
		no_data.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_MUTED)
		no_data.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_content_vbox.add_child(no_data)
		return

	var course = GameManager.current_course
	var holes = course.holes

	# Header info
	_title_label.text = GameManager.course_name.to_upper()
	var theme_name = CourseTheme.get_theme_name(GameManager.current_theme)
	var rating = GameManager.course_rating
	var total_yardage := 0
	for hole in holes:
		total_yardage += hole.distance_yards
	var stars_text = ""
	for i in rating.get("stars", 0):
		stars_text += "*"
	_subtitle_label.text = "%s  |  Rating: %.1f  |  Slope: %d  |  %s  |  Par %d  |  %d yds" % [
		theme_name,
		rating.get("course_rating", 72.0),
		rating.get("slope", 113),
		stars_text,
		course.total_par,
		total_yardage
	]

	# Split into front/back nine
	var front_holes: Array = []
	var back_holes: Array = []
	for hole in holes:
		if hole.hole_number <= 9:
			front_holes.append(hole)
		else:
			back_holes.append(hole)

	# Sort by hole number
	front_holes.sort_custom(func(a, b): return a.hole_number < b.hole_number)
	back_holes.sort_custom(func(a, b): return a.hole_number < b.hole_number)

	# Build scorecard grid(s)
	if back_holes.is_empty():
		# Single nine or fewer
		_content_vbox.add_child(_build_nine_grid(front_holes, "OUT"))
	elif front_holes.is_empty():
		# Only back nine holes (unusual but possible)
		_content_vbox.add_child(_build_nine_grid(back_holes, "IN"))
	else:
		_content_vbox.add_child(_build_nine_grid(front_holes, "OUT"))
		_content_vbox.add_child(_build_nine_grid(back_holes, "IN"))

		# Total row
		_content_vbox.add_child(_build_total_row(front_holes, back_holes))

	# Course records section
	_content_vbox.add_child(HSeparator.new())
	_content_vbox.add_child(_build_records_section())

func _build_nine_grid(holes: Array, label: String) -> VBoxContainer:
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 0)

	var num_holes = holes.size()

	# Row 1: Hole numbers
	container.add_child(_build_row("Hole", holes.map(func(h): return str(h.hole_number)), label, BG_HEADER_ROW, Color.WHITE, true))

	# Row 2: Yardage
	var yard_sum := 0
	for h in holes:
		yard_sum += h.distance_yards
	container.add_child(_build_row("Yards", holes.map(func(h): return str(h.distance_yards)), str(yard_sum), BG_DATA_ROW_A, UIConstants.COLOR_TEXT_DIM))

	# Row 3: Par
	var par_sum := 0
	for h in holes:
		par_sum += h.par
	container.add_child(_build_row("Par", holes.map(func(h): return str(h.par) + ("*" if h.par_override > 0 else "")), str(par_sum), BG_DATA_ROW_B, Color.WHITE))

	# Row 4: Handicap (stroke index)
	container.add_child(_build_row("Hcp", holes.map(func(h): return str(h.stroke_index) if h.stroke_index > 0 else "-"), "", BG_DATA_ROW_A, UIConstants.COLOR_TEXT_DIM))

	# Row 5: Average score (color-coded)
	container.add_child(_build_avg_row(holes, par_sum))

	return container

func _build_row(label_text: String, values: Array, total_text: String, bg_color: Color, text_color: Color, is_header := false) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)

	# Label column
	var label_cell = _make_cell(label_text, LABEL_COL_WIDTH, bg_color, text_color, is_header)
	row.add_child(label_cell)

	# Value cells
	for val in values:
		row.add_child(_make_cell(str(val), CELL_WIDTH, bg_color, text_color, is_header))

	# Total column
	if total_text != "":
		var total_bg = bg_color.lightened(0.05) if not is_header else bg_color
		row.add_child(_make_cell(total_text, TOTAL_COL_WIDTH, total_bg, text_color, is_header))
	else:
		# Empty total cell for rows without totals
		row.add_child(_make_cell("", TOTAL_COL_WIDTH, bg_color, text_color))

	return row

func _build_avg_row(holes: Array, par_sum: int) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)

	# Label
	row.add_child(_make_cell("Avg", LABEL_COL_WIDTH, BG_DATA_ROW_B, UIConstants.COLOR_TEXT_DIM))

	var total_avg := 0.0
	var total_par_with_data := 0
	var has_any_data := false

	for hole in holes:
		var stats = GameManager.get_hole_statistics(hole.hole_number)
		if stats and stats.total_rounds > 0:
			has_any_data = true
			var avg = stats.get_average_score()
			total_avg += avg
			total_par_with_data += hole.par
			var avg_to_par = avg - hole.par
			var color = _get_avg_color(avg_to_par)
			row.add_child(_make_cell("%.1f" % avg, CELL_WIDTH, BG_DATA_ROW_B, color))
		else:
			row.add_child(_make_cell("-", CELL_WIDTH, BG_DATA_ROW_B, UIConstants.COLOR_TEXT_MUTED))

	# Total average (only compare against par of holes that have data)
	if has_any_data:
		var avg_to_par = total_avg - total_par_with_data
		var color = _get_avg_color(avg_to_par)
		row.add_child(_make_cell("%.1f" % total_avg, TOTAL_COL_WIDTH, BG_DATA_ROW_B.lightened(0.05), color))
	else:
		row.add_child(_make_cell("-", TOTAL_COL_WIDTH, BG_DATA_ROW_B, UIConstants.COLOR_TEXT_MUTED))

	return row

func _build_total_row(front_holes: Array, back_holes: Array) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)

	var front_par := 0
	var front_yards := 0
	var back_par := 0
	var back_yards := 0

	for h in front_holes:
		front_par += h.par
		front_yards += h.distance_yards
	for h in back_holes:
		back_par += h.par
		back_yards += h.distance_yards

	var total_label = Label.new()
	total_label.text = "TOTAL:  Par %d  |  %d yards" % [front_par + back_par, front_yards + back_yards]
	total_label.add_theme_font_size_override("font_size", CELL_FONT_SIZE)
	total_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_DIM)
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	total_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(total_label)

	return row

func _build_records_section() -> VBoxContainer:
	var section = VBoxContainer.new()
	section.add_theme_constant_override("separation", 4)

	var header = Label.new()
	header.text = "Course Records"
	header.add_theme_font_size_override("font_size", 13)
	section.add_child(header)

	var records = GameManager.course_records

	# Lowest round
	var lowest = records.get("lowest_round")
	if lowest != null:
		var diff = lowest.value - GameManager.current_course.total_par
		var diff_text = ""
		if diff > 0:
			diff_text = " (+%d)" % diff
		elif diff < 0:
			diff_text = " (%d)" % diff
		else:
			diff_text = " (E)"
		var text = "Lowest Round: %d%s by %s (Day %d)" % [lowest.value, diff_text, lowest.golfer_name, lowest.date_day]
		section.add_child(_make_record_label(text, UIConstants.COLOR_GOLD))
	else:
		section.add_child(_make_record_label("Lowest Round: No rounds completed", UIConstants.COLOR_TEXT_MUTED))

	# Holes-in-one count
	var hio_count = records.get("total_hole_in_ones", 0)
	if hio_count > 0:
		section.add_child(_make_record_label("Holes-in-One: %d" % hio_count, UIConstants.COLOR_GOLD))

	# Best per hole
	var best_per_hole = records.get("best_per_hole", {})
	if not best_per_hole.is_empty():
		var best_label = Label.new()
		best_label.text = "Best Scores:"
		best_label.add_theme_font_size_override("font_size", CELL_FONT_SIZE)
		best_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_DIM)
		section.add_child(best_label)

		var sorted_holes = best_per_hole.keys()
		sorted_holes.sort()
		for hole_num in sorted_holes:
			var record = best_per_hole[hole_num]
			# Find par for this hole
			var par := 4
			for hole in GameManager.current_course.holes:
				if hole.hole_number == hole_num:
					par = hole.par
					break
			var score_name = GolfRules.get_score_name(record.value, par)
			var text = "  #%d: %d (%s) - %s" % [hole_num, record.value, score_name, record.golfer_name]
			var color = UIConstants.get_score_color(record.value - par)
			section.add_child(_make_record_label(text, color))

	return section

func _make_cell(text: String, width: float, bg_color: Color, text_color: Color, bold := false) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(width, ROW_HEIGHT)

	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = BORDER_COLOR
	style.border_width_bottom = 1
	style.border_width_right = 1
	panel.add_theme_stylebox_override("panel", style)

	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", CELL_FONT_SIZE)
	label.add_theme_color_override("font_color", text_color)
	panel.add_child(label)

	return panel

func _make_record_label(text: String, color: Color) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", CELL_FONT_SIZE)
	label.add_theme_color_override("font_color", color)
	return label

func _get_avg_color(avg_to_par: float) -> Color:
	if avg_to_par <= 0:
		return UIConstants.COLOR_SCORE_UNDER
	if avg_to_par <= 0.5:
		return UIConstants.COLOR_WARNING
	return UIConstants.COLOR_SCORE_OVER

func _on_close_pressed() -> void:
	close_requested.emit()
	hide()
