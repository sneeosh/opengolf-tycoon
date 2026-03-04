extends CenteredPanel
class_name EnhancedRoundSummary
## EnhancedRoundSummary - Full scorecard popup shown when a followed golfer
## finishes their round. Replaces the brief toast with a detailed breakdown.

signal close_requested

var _golfer: Golfer = null
var _content_vbox: VBoxContainer = null
var _title_label: Label = null

const CELL_W := 32
const LABEL_W := 52
const TOTAL_W := 40
const ROW_H := 20
const FONT_SIZE := 11
const HEADER_FONT := 14

func _build_ui() -> void:
	custom_minimum_size = Vector2(460, 340)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.08, 0.96)
	style.border_color = Color(0.3, 0.5, 0.35)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Title row
	var title_row := HBoxContainer.new()
	vbox.add_child(title_row)

	_title_label = Label.new()
	_title_label.text = "ROUND COMPLETE"
	_title_label.add_theme_font_size_override("font_size", 16)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(_title_label)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(60, 28)
	close_btn.pressed.connect(func(): close_requested.emit())
	title_row.add_child(close_btn)

	vbox.add_child(HSeparator.new())

	# Scrollable content
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	vbox.add_child(scroll)

	_content_vbox = VBoxContainer.new()
	_content_vbox.add_theme_constant_override("separation", 6)
	_content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_content_vbox)

func _ready() -> void:
	super._ready()

func show_for_golfer(golfer: Golfer) -> void:
	_golfer = golfer
	_rebuild()
	show_centered()

func _rebuild() -> void:
	if not _golfer:
		return

	# Clear existing content
	for child in _content_vbox.get_children():
		child.queue_free()

	# Golfer info header
	var tier_name = GolferTier.get_tier_name(_golfer.golfer_tier)
	var info_label := Label.new()
	info_label.text = "%s  (%s)" % [_golfer.golfer_name, tier_name]
	info_label.add_theme_font_size_override("font_size", HEADER_FONT)
	_content_vbox.add_child(info_label)

	# Build scorecard grid
	var course_data = GameManager.course_data
	if course_data and not course_data.holes.is_empty():
		var hole_count = course_data.holes.size()
		var front_end = min(hole_count, 9)

		# Front 9
		_content_vbox.add_child(_build_nine_block(course_data, 0, front_end, "OUT"))

		# Back 9
		if hole_count > 9:
			_content_vbox.add_child(_build_nine_block(course_data, 9, hole_count, "IN"))

	_content_vbox.add_child(HSeparator.new())

	# Summary stats
	var score_vs_par = _golfer.total_strokes - _golfer.total_par
	var score_str: String
	if score_vs_par == 0:
		score_str = "%d (Even par)" % _golfer.total_strokes
	elif score_vs_par > 0:
		score_str = "%d (+%d)" % [_golfer.total_strokes, score_vs_par]
	else:
		score_str = "%d (%d)" % [_golfer.total_strokes, score_vs_par]

	var score_color = UIConstants.get_score_color(score_vs_par)
	_content_vbox.add_child(_stat_row("Total Score", score_str, score_color))

	# Best and worst holes
	var best = _find_best_hole()
	var worst = _find_worst_hole()
	if best:
		var best_diff = best.strokes - best.par
		var best_name = GolfRules.get_score_name(best.strokes, best.par)
		_content_vbox.add_child(_stat_row("Best Hole", "%s on #%d (Par %d)" % [best_name, best.hole + 1, best.par], UIConstants.get_score_color(best_diff)))
	if worst:
		var worst_diff = worst.strokes - worst.par
		var worst_name = GolfRules.get_score_name(worst.strokes, worst.par)
		_content_vbox.add_child(_stat_row("Worst Hole", "%s on #%d (Par %d)" % [worst_name, worst.hole + 1, worst.par], UIConstants.get_score_color(worst_diff)))

	_content_vbox.add_child(HSeparator.new())

	# Mood and payment
	var mood_text = _get_mood_text(_golfer.current_mood)
	var mood_color = _get_mood_color(_golfer.current_mood)
	_content_vbox.add_child(_stat_row("Satisfaction", "%s (%.0f%%)" % [mood_text, _golfer.current_mood * 100], mood_color))

	var holes_played = _golfer.hole_scores.size()
	var fee_paid = GameManager.green_fee * holes_played
	_content_vbox.add_child(_stat_row("Paid", "$%d (%d holes x $%d)" % [fee_paid, holes_played, GameManager.green_fee], UIConstants.COLOR_SUCCESS_DIM))

func _build_nine_block(course_data: GameManager.CourseData, from: int, to: int, total_label: String) -> Control:
	var block = VBoxContainer.new()
	block.add_theme_constant_override("separation", 0)

	# Hole numbers
	var hole_row = _create_row()
	_add_cell(hole_row, "Hole", LABEL_W, FONT_SIZE, UIConstants.COLOR_TEXT_DIM, Color(0.18, 0.35, 0.24, 0.85))
	for i in range(from, to):
		_add_cell(hole_row, str(i + 1), CELL_W, FONT_SIZE, UIConstants.COLOR_TEXT, Color(0.18, 0.35, 0.24, 0.85))
	_add_cell(hole_row, total_label, TOTAL_W, FONT_SIZE, UIConstants.COLOR_TEXT_DIM, Color(0.18, 0.35, 0.24, 0.85))
	block.add_child(hole_row)

	# Par
	var par_row = _create_row()
	_add_cell(par_row, "Par", LABEL_W, FONT_SIZE, UIConstants.COLOR_TEXT_DIM, Color(0.14, 0.14, 0.14))
	var par_total = 0
	for i in range(from, to):
		par_total += course_data.holes[i].par
		_add_cell(par_row, str(course_data.holes[i].par), CELL_W, FONT_SIZE, UIConstants.COLOR_TEXT_DIM, Color(0.14, 0.14, 0.14))
	_add_cell(par_row, str(par_total), TOTAL_W, FONT_SIZE, UIConstants.COLOR_TEXT_DIM, Color(0.14, 0.14, 0.14))
	block.add_child(par_row)

	# Score
	var score_row = _create_row()
	_add_cell(score_row, "Score", LABEL_W, FONT_SIZE, UIConstants.COLOR_TEXT, Color(0.11, 0.11, 0.11))
	var score_total = 0
	for i in range(from, to):
		var score_data = _find_hole_score(i)
		if score_data:
			var diff = score_data.strokes - score_data.par
			_add_cell(score_row, str(score_data.strokes), CELL_W, FONT_SIZE, UIConstants.get_score_color(diff), Color(0.11, 0.11, 0.11))
			score_total += score_data.strokes
		else:
			_add_cell(score_row, "-", CELL_W, FONT_SIZE, UIConstants.COLOR_TEXT_MUTED, Color(0.11, 0.11, 0.11))
	_add_cell(score_row, str(score_total) if score_total > 0 else "-", TOTAL_W, FONT_SIZE, UIConstants.COLOR_TEXT, Color(0.11, 0.11, 0.11))
	block.add_child(score_row)

	return block

func _find_hole_score(hole_index: int) -> Variant:
	if not _golfer:
		return null
	for s in _golfer.hole_scores:
		if s.hole == hole_index:
			return s
	return null

func _find_best_hole() -> Variant:
	if not _golfer or _golfer.hole_scores.is_empty():
		return null
	var best = null
	var best_diff = 999
	for s in _golfer.hole_scores:
		var diff = s.strokes - s.par
		if diff < best_diff:
			best_diff = diff
			best = s
	return best

func _find_worst_hole() -> Variant:
	if not _golfer or _golfer.hole_scores.is_empty():
		return null
	var worst = null
	var worst_diff = -999
	for s in _golfer.hole_scores:
		var diff = s.strokes - s.par
		if diff > worst_diff:
			worst_diff = diff
			worst = s
	return worst

func _stat_row(label_text: String, value_text: String, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 12)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var value := Label.new()
	value.text = value_text
	value.add_theme_font_size_override("font_size", 12)
	value.add_theme_color_override("font_color", color)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	return row

func _create_row() -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	return row

func _add_cell(row: HBoxContainer, text: String, width: int, font_size: int, font_color: Color, bg_color: Color) -> void:
	var cell = PanelContainer.new()
	cell.custom_minimum_size = Vector2(width, ROW_H)
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = Color(0.15, 0.15, 0.15, 0.5)
	style.border_width_right = 1
	style.border_width_bottom = 1
	cell.add_theme_stylebox_override("panel", style)

	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cell.add_child(label)
	row.add_child(cell)

func _get_mood_text(mood: float) -> String:
	if mood >= 0.8: return "Very Happy"
	if mood >= 0.6: return "Satisfied"
	if mood >= 0.4: return "Neutral"
	if mood >= 0.2: return "Dissatisfied"
	return "Frustrated"

func _get_mood_color(mood: float) -> Color:
	if mood >= 0.6: return UIConstants.COLOR_MOOD_HAPPY
	if mood >= 0.4: return UIConstants.COLOR_MOOD_NEUTRAL
	return UIConstants.COLOR_MOOD_UNHAPPY
