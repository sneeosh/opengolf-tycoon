extends Control
class_name LiveScorecard
## LiveScorecard - Compact scorecard overlay shown during follow mode.
## Displays the followed golfer's hole-by-hole scores in real time,
## with group members when applicable.

const CELL_W := 28
const LABEL_W := 60
const TOTAL_W := 38
const ROW_H := 18
const FONT_SIZE := 10
const HEADER_FONT := 12
const PANEL_ALPHA := 0.88

const BG_PANEL := Color(0.08, 0.08, 0.08, PANEL_ALPHA)
const BG_HEADER := Color(0.18, 0.35, 0.24, 0.85)
const BG_ROW_A := Color(0.1, 0.1, 0.1, PANEL_ALPHA)
const BG_ROW_B := Color(0.12, 0.12, 0.12, PANEL_ALPHA)
const BG_CURRENT_HOLE := Color(0.25, 0.35, 0.25, 0.6)
const BORDER := Color(0.2, 0.2, 0.2)

var _golfer: Golfer = null
var _group: Array = []  # Array[Golfer]
var _panel: PanelContainer = null
var _grid_container: Control = null
var _header_label: Label = null
var _follow_hint_label: Label = null

## Position: bottom-left, above BottomBar
const MARGIN_LEFT := 10.0
const MARGIN_BOTTOM := 60.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_panel()
	hide()
	EventBus.golfer_finished_hole.connect(_on_golfer_finished_hole)
	EventBus.golfer_started_hole.connect(_on_golfer_started_hole)
	EventBus.follow_mode_exited.connect(_on_follow_mode_exited)

func _exit_tree() -> void:
	if EventBus.golfer_finished_hole.is_connected(_on_golfer_finished_hole):
		EventBus.golfer_finished_hole.disconnect(_on_golfer_finished_hole)
	if EventBus.golfer_started_hole.is_connected(_on_golfer_started_hole):
		EventBus.golfer_started_hole.disconnect(_on_golfer_started_hole)
	if EventBus.follow_mode_exited.is_connected(_on_follow_mode_exited):
		EventBus.follow_mode_exited.disconnect(_on_follow_mode_exited)

func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = BG_PANEL
	style.border_color = BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	_panel.add_child(vbox)

	# Header row: "Following: Name  | Thru X | Score"
	_header_label = Label.new()
	_header_label.add_theme_font_size_override("font_size", HEADER_FONT)
	_header_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT)
	vbox.add_child(_header_label)

	# Grid area for scorecard rows
	_grid_container = VBoxContainer.new()
	_grid_container.add_theme_constant_override("separation", 0)
	vbox.add_child(_grid_container)

	# Escape hint
	_follow_hint_label = Label.new()
	_follow_hint_label.text = "Tab: Next golfer | Esc: Exit follow"
	_follow_hint_label.add_theme_font_size_override("font_size", 9)
	_follow_hint_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_MUTED)
	vbox.add_child(_follow_hint_label)

func show_for_golfer(golfer: Golfer, group: Array) -> void:
	_golfer = golfer
	_group = group
	_rebuild_scorecard()
	show()
	_reposition()

func _reposition() -> void:
	await get_tree().process_frame
	var vp_size = get_viewport().get_visible_rect().size
	_panel.position = Vector2(MARGIN_LEFT, vp_size.y - _panel.size.y - MARGIN_BOTTOM)

func _on_golfer_finished_hole(golfer_id: int, _hole: int, _strokes: int, _par: int) -> void:
	if not visible or not _golfer:
		return
	# Refresh if the finished golfer is in our group
	var in_group = false
	if _golfer.golfer_id == golfer_id:
		in_group = true
	else:
		for g in _group:
			if g.golfer_id == golfer_id:
				in_group = true
				break
	if in_group:
		_rebuild_scorecard()

func _on_golfer_started_hole(golfer_id: int, _hole: int) -> void:
	if not visible or not _golfer:
		return
	if _golfer.golfer_id == golfer_id:
		_rebuild_scorecard()

func _on_follow_mode_exited() -> void:
	_golfer = null
	_group = []
	hide()

func _rebuild_scorecard() -> void:
	if not _golfer or not is_instance_valid(_golfer):
		hide()
		return

	# Update header
	var tier_name = GolferTier.get_tier_name(_golfer.golfer_tier)
	var thru_holes = _golfer.hole_scores.size()
	var score_vs_par = _golfer.total_strokes - _golfer.total_par
	var score_str = _format_score_to_par(score_vs_par, _golfer.total_par > 0)
	var header_text = "%s (%s)  |  Thru %d  |  %s" % [_golfer.golfer_name, tier_name, thru_holes, score_str]

	# Add tournament position if applicable
	if _golfer.is_tournament_golfer and GameManager.tournament_manager:
		var leaderboard = GameManager.tournament_manager.get_leaderboard()
		if leaderboard:
			var pos_data = leaderboard.get_golfer_position(_golfer.golfer_id)
			if pos_data:
				var pos_str = "T%d" % pos_data.position if pos_data.tied else "%d" % pos_data.position
				header_text += "  |  %s/%d" % [pos_str, pos_data.total]
	_header_label.text = header_text

	# Clear grid
	for child in _grid_container.get_children():
		child.queue_free()

	# Get course data
	var course_data = GameManager.course_data
	if not course_data or course_data.holes.is_empty():
		return

	var hole_count = course_data.holes.size()
	var show_two_rows = hole_count > 9

	# Determine if this is a group scorecard
	var show_group = _group.size() > 1

	if show_group:
		_build_group_scorecard(course_data, hole_count, show_two_rows)
	else:
		_build_solo_scorecard(course_data, hole_count, show_two_rows)

	_reposition()

func _build_solo_scorecard(course_data: GameManager.CourseData, hole_count: int, show_two_rows: bool) -> void:
	# Front 9 (or all holes if <=9)
	var front_end = min(hole_count, 9)
	_grid_container.add_child(_build_nine_block(course_data, 0, front_end, "OUT", _golfer))

	# Back 9
	if show_two_rows and hole_count > 9:
		_grid_container.add_child(_build_nine_block(course_data, 9, hole_count, "IN", _golfer))

func _build_group_scorecard(course_data: GameManager.CourseData, hole_count: int, show_two_rows: bool) -> void:
	# Compact group view: Par row + one row per golfer, front 9 only (space constrained)
	var display_end = min(hole_count, 9)

	# Par row
	var par_row = _create_row()
	_add_cell(par_row, "Par", LABEL_W, FONT_SIZE, UIConstants.COLOR_TEXT_DIM, BG_HEADER)
	var par_total = 0
	for i in range(display_end):
		var par = course_data.holes[i].par
		par_total += par
		_add_cell(par_row, str(par), CELL_W, FONT_SIZE, UIConstants.COLOR_TEXT_DIM, BG_HEADER)
	_add_cell(par_row, str(par_total), TOTAL_W, FONT_SIZE, UIConstants.COLOR_TEXT_DIM, BG_HEADER)
	_grid_container.add_child(par_row)

	# One row per group member
	for idx in range(_group.size()):
		var g = _group[idx]
		if not is_instance_valid(g):
			continue
		var is_followed = g.golfer_id == _golfer.golfer_id
		var row = _create_row()
		var name_prefix = "> " if is_followed else "  "
		var name_text = name_prefix + _truncate_name(g.golfer_name, 7)
		var bg = BG_ROW_A if idx % 2 == 0 else BG_ROW_B
		var name_color = UIConstants.COLOR_GOLD if is_followed else UIConstants.COLOR_TEXT
		_add_cell(row, name_text, LABEL_W, FONT_SIZE, name_color, bg)

		var row_total = 0
		for h in range(display_end):
			var score_data = _find_hole_score(g, h)
			if score_data:
				var diff = score_data.strokes - score_data.par
				var color = UIConstants.get_score_color(diff)
				_add_cell(row, str(score_data.strokes), CELL_W, FONT_SIZE, color, bg)
				row_total += score_data.strokes
			elif h == g.current_hole and g.current_strokes > 0:
				# In progress
				_add_cell(row, str(g.current_strokes), CELL_W, FONT_SIZE, UIConstants.COLOR_TEXT_MUTED, BG_CURRENT_HOLE)
			else:
				_add_cell(row, "", CELL_W, FONT_SIZE, UIConstants.COLOR_TEXT_MUTED, bg)

		# Running score-to-par
		var g_score_vs_par = g.total_strokes - g.total_par
		var total_str = _format_score_to_par(g_score_vs_par, g.total_par > 0)
		var total_color = UIConstants.COLOR_SCORE_UNDER if g_score_vs_par < 0 else (UIConstants.COLOR_SCORE_PAR if g_score_vs_par == 0 else UIConstants.COLOR_SCORE_OVER)
		_add_cell(row, total_str, TOTAL_W, FONT_SIZE, total_color, bg)
		_grid_container.add_child(row)

func _build_nine_block(course_data: GameManager.CourseData, from: int, to: int, total_label: String, golfer: Golfer) -> Control:
	var block = VBoxContainer.new()
	block.add_theme_constant_override("separation", 0)

	# Hole number row
	var hole_row = _create_row()
	_add_cell(hole_row, "Hole", LABEL_W, FONT_SIZE, UIConstants.COLOR_TEXT_DIM, BG_HEADER)
	for i in range(from, to):
		var is_current = (i == golfer.current_hole)
		var bg = BG_CURRENT_HOLE if is_current else BG_HEADER
		_add_cell(hole_row, str(i + 1), CELL_W, FONT_SIZE, UIConstants.COLOR_TEXT, bg)
	_add_cell(hole_row, total_label, TOTAL_W, FONT_SIZE, UIConstants.COLOR_TEXT_DIM, BG_HEADER)
	block.add_child(hole_row)

	# Par row
	var par_row = _create_row()
	_add_cell(par_row, "Par", LABEL_W, FONT_SIZE, UIConstants.COLOR_TEXT_DIM, BG_ROW_A)
	var par_total = 0
	for i in range(from, to):
		par_total += course_data.holes[i].par
		_add_cell(par_row, str(course_data.holes[i].par), CELL_W, FONT_SIZE, UIConstants.COLOR_TEXT_DIM, BG_ROW_A)
	_add_cell(par_row, str(par_total), TOTAL_W, FONT_SIZE, UIConstants.COLOR_TEXT_DIM, BG_ROW_A)
	block.add_child(par_row)

	# Score row
	var score_row = _create_row()
	_add_cell(score_row, "Score", LABEL_W, FONT_SIZE, UIConstants.COLOR_TEXT, BG_ROW_B)
	var score_total = 0
	for i in range(from, to):
		var score_data = _find_hole_score(golfer, i)
		if score_data:
			var diff = score_data.strokes - score_data.par
			var color = UIConstants.get_score_color(diff)
			_add_cell(score_row, str(score_data.strokes), CELL_W, FONT_SIZE, color, BG_ROW_B)
			score_total += score_data.strokes
		elif i == golfer.current_hole and golfer.current_strokes > 0:
			_add_cell(score_row, str(golfer.current_strokes), CELL_W, FONT_SIZE, UIConstants.COLOR_TEXT_MUTED, BG_CURRENT_HOLE)
		else:
			_add_cell(score_row, "", CELL_W, FONT_SIZE, UIConstants.COLOR_TEXT_MUTED, BG_ROW_B)
	_add_cell(score_row, str(score_total) if score_total > 0 else "", TOTAL_W, FONT_SIZE, UIConstants.COLOR_TEXT, BG_ROW_B)
	block.add_child(score_row)

	return block

## Helper: find a golfer's score for a specific hole index
func _find_hole_score(golfer: Golfer, hole_index: int) -> Variant:
	for s in golfer.hole_scores:
		if s.hole == hole_index:
			return s
	return null

## Helper: create an HBoxContainer row
func _create_row() -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	return row

## Helper: add a cell (label with background) to a row
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

func _format_score_to_par(diff: int, has_played: bool) -> String:
	if not has_played:
		return "E"
	if diff == 0:
		return "E"
	elif diff > 0:
		return "+%d" % diff
	else:
		return "%d" % diff

func _truncate_name(name: String, max_len: int) -> String:
	if name.length() <= max_len:
		return name
	return name.substr(0, max_len - 1) + "."
