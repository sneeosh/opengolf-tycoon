extends PanelContainer
class_name TournamentLeaderboard
## Live leaderboard panel shown during tournaments.
## Supports multi-round display with per-round score columns, cut line,
## and MC (missed cut) labels.

const PANEL_WIDTH: float = 340.0
const TOP_MARGIN: float = 45.0
const RIGHT_MARGIN: float = 10.0

var _entries: Array = []  # Array of entry dicts
var _grid: GridContainer = null
var _scroll: ScrollContainer = null
var _title_label: Label = null
var _round_label: Label = null
var _close_btn: Button = null
var _tournament_name: String = ""
var _participant_count: int = 0
var _total_rounds: int = 1
var _current_round: int = 1
var _is_final: bool = false
var _cut_advancing: Array = []
var _cut_eliminated: Array = []

func _ready() -> void:
	_build_ui()
	hide()

func _build_ui() -> void:
	custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var style := StyleBoxFlat.new()
	style.bg_color = Color(UIConstants.COLOR_BG_DARK, 0.92)
	style.border_width_bottom = 2
	style.border_width_top = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = UIConstants.COLOR_BORDER
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	# Title row
	var title_row := HBoxContainer.new()
	vbox.add_child(title_row)

	_title_label = Label.new()
	_title_label.text = "Tournament Leaderboard"
	_title_label.add_theme_font_size_override("font_size", 13)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(_title_label)

	_close_btn = Button.new()
	_close_btn.text = "X"
	_close_btn.custom_minimum_size = Vector2(24, 24)
	_close_btn.pressed.connect(func(): hide())
	_close_btn.visible = false
	title_row.add_child(_close_btn)

	# Round info label
	_round_label = Label.new()
	_round_label.text = ""
	_round_label.add_theme_font_size_override("font_size", 11)
	_round_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_DIM)
	_round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_round_label.visible = false
	vbox.add_child(_round_label)

	vbox.add_child(HSeparator.new())

	# Scrollable grid area
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.custom_minimum_size = Vector2(0, 200)
	vbox.add_child(_scroll)

	_grid = GridContainer.new()
	_grid.columns = 1
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_grid)

## Show leaderboard for a tournament (multi-round aware)
func show_for_tournament(tournament_name: String, participant_count: int = 0,
		total_rounds: int = 1, round_text: String = "") -> void:
	_tournament_name = tournament_name
	_participant_count = participant_count
	_total_rounds = total_rounds
	_current_round = 1
	_is_final = false
	_entries.clear()
	_cut_advancing.clear()
	_cut_eliminated.clear()

	if participant_count > 0:
		_title_label.text = "%s (%d) — LIVE" % [tournament_name, participant_count]
	else:
		_title_label.text = "%s — LIVE" % tournament_name

	_round_label.text = round_text
	_round_label.visible = round_text != ""
	_close_btn.visible = false
	_refresh_display()
	_position_panel()
	show()

## Update round info display
func update_round_info(round_num: int, total_rnds: int, round_text: String) -> void:
	_current_round = round_num
	_total_rounds = total_rnds
	_round_label.text = round_text
	_round_label.visible = round_text != ""

	if not _is_final:
		if _participant_count > 0:
			_title_label.text = "%s (%d) — LIVE" % [_tournament_name, _participant_count]
		else:
			_title_label.text = "%s — LIVE" % _tournament_name

	_refresh_display()

## Register a golfer on the leaderboard
func register_golfer(golfer_id: int, golfer_name: String, sim_id: int = -1) -> void:
	_entries.append({
		"golfer_id": golfer_id,
		"sim_id": sim_id if sim_id != -1 else golfer_id,
		"name": golfer_name,
		"round_scores": [],
		"total_strokes": 0,
		"total_par": 0,
		"holes_completed": 0,
		"is_finished": false,
		"missed_cut": false,
	})

## Update score for a live golfer (per-hole update)
func update_score(golfer_id: int, _hole: int, strokes: int, par: int) -> void:
	for entry in _entries:
		if entry.golfer_id == golfer_id:
			entry.total_strokes += strokes
			entry.total_par += par
			entry.holes_completed += 1
			break
	_refresh_display()

## Mark a live golfer as finished
func mark_finished(golfer_id: int, total_strokes: int) -> void:
	for entry in _entries:
		if entry.golfer_id == golfer_id:
			entry.is_finished = true
			entry.total_strokes = total_strokes
			break
	_refresh_display()

## Set simulated results for batch-completed golfers
func set_simulated_results(results: Array) -> void:
	for result in results:
		for entry in _entries:
			if entry.golfer_id == result.golfer_id:
				entry.total_strokes = result.total_strokes
				entry.total_par = result.total_par
				entry.holes_completed = result.holes_completed
				entry.is_finished = true
				break
	_refresh_display()

## Set round score for a simulated golfer (multi-round)
func set_round_score(sim_id: int, round_number: int,
		round_strokes: int, round_par: int,
		cumulative_strokes: int, cumulative_par: int) -> void:
	for entry in _entries:
		if entry.sim_id == sim_id or entry.golfer_id == sim_id:
			while entry.round_scores.size() < round_number:
				entry.round_scores.append(null)
			entry.round_scores[round_number - 1] = {
				"strokes": round_strokes,
				"par": round_par,
			}
			entry.total_strokes = cumulative_strokes
			entry.total_par = cumulative_par
			entry.is_finished = true
			entry.holes_completed = -1
			break
	_refresh_display()

## Apply cut line: mark eliminated golfers
func apply_cut_line(advancing: Array, eliminated: Array) -> void:
	_cut_advancing = advancing
	_cut_eliminated = eliminated
	for entry in _entries:
		if entry.sim_id in eliminated:
			entry.missed_cut = true
	_refresh_display()

func show_final_results() -> void:
	_is_final = true
	if _participant_count > 0:
		_title_label.text = "%s (%d) — FINAL" % [_tournament_name, _participant_count]
	else:
		_title_label.text = "%s — FINAL" % _tournament_name
	_round_label.visible = false
	_close_btn.visible = true
	_refresh_display()

func _refresh_display() -> void:
	for child in _grid.get_children():
		child.queue_free()

	# Header row
	var header = _create_header_row()
	_grid.add_child(header)

	# Sort: advancing by score-to-par, then eliminated
	var sorted = _entries.duplicate()
	sorted.sort_custom(func(a, b):
		if a.missed_cut != b.missed_cut:
			return not a.missed_cut
		var a_diff = a.total_strokes - a.total_par if a.total_par > 0 else 999
		var b_diff = b.total_strokes - b.total_par if b.total_par > 0 else 999
		return a_diff < b_diff
	)

	var cut_line_shown = false
	for i in range(sorted.size()):
		var entry = sorted[i]

		# Show cut line separator
		if entry.missed_cut and not cut_line_shown and not _cut_eliminated.is_empty():
			cut_line_shown = true
			_grid.add_child(_create_cut_line_separator())

		var rank_text = "%d" % (i + 1)
		var score_text = _format_total_score(entry)
		var thru_text = _get_thru_text(entry)
		var score_color = _get_score_color(entry.total_strokes - entry.total_par, entry.total_par)

		if entry.missed_cut:
			score_color = UIConstants.COLOR_TEXT_DIM

		var row = _create_entry_row(rank_text, entry.name, entry.round_scores,
			score_text, thru_text, score_color, entry.missed_cut)
		_grid.add_child(row)

func _create_header_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)

	row.add_child(_make_label("", 20, UIConstants.COLOR_TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT))

	var name_lbl = _make_label("Name", 0, UIConstants.COLOR_TEXT_DIM)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)

	if _total_rounds > 1:
		for r in range(_total_rounds):
			row.add_child(_make_label("R%d" % (r + 1), 28, UIConstants.COLOR_TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT))

	row.add_child(_make_label("Tot", 35, UIConstants.COLOR_TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT))
	row.add_child(_make_label("Thru", 28, UIConstants.COLOR_TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT))

	return row

func _create_entry_row(rank: String, player_name: String, round_scores: Array,
		score: String, thru: String, color: Color, missed_cut: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)

	var name_color = Color.WHITE if not missed_cut else UIConstants.COLOR_TEXT_DIM

	row.add_child(_make_label(rank, 20, UIConstants.COLOR_TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT))

	var name_lbl = _make_label(player_name, 0, name_color)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.clip_text = true
	row.add_child(name_lbl)

	if _total_rounds > 1:
		for r in range(_total_rounds):
			var r_text = "-"
			var r_color = UIConstants.COLOR_TEXT_DIM
			if r < round_scores.size() and round_scores[r] != null:
				var diff = round_scores[r].strokes - round_scores[r].par
				r_text = _format_score_diff(diff)
				r_color = _get_score_color(diff, round_scores[r].par)
				if missed_cut:
					r_color = UIConstants.COLOR_TEXT_DIM
			row.add_child(_make_label(r_text, 28, r_color, HORIZONTAL_ALIGNMENT_RIGHT))

	row.add_child(_make_label(score, 35, color, HORIZONTAL_ALIGNMENT_RIGHT))

	var thru_text = "MC" if missed_cut else thru
	var thru_color = UIConstants.COLOR_SCORE_OVER if missed_cut else UIConstants.COLOR_TEXT_DIM
	row.add_child(_make_label(thru_text, 28, thru_color, HORIZONTAL_ALIGNMENT_RIGHT))

	return row

func _create_cut_line_separator() -> HBoxContainer:
	var row := HBoxContainer.new()
	var sep_label = Label.new()
	sep_label.text = "— CUT LINE —"
	sep_label.add_theme_font_size_override("font_size", 10)
	sep_label.add_theme_color_override("font_color", UIConstants.COLOR_SCORE_OVER)
	sep_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sep_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sep_label)
	return row

func _make_label(text: String, min_width: int, color: Color,
		alignment: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = alignment
	if min_width > 0:
		label.custom_minimum_size = Vector2(min_width, 0)
	return label

func _format_total_score(entry: Dictionary) -> String:
	if entry.total_par == 0:
		return "-"
	return _format_score_diff(entry.total_strokes - entry.total_par)

func _format_score_diff(diff: int) -> String:
	if diff == 0:
		return "E"
	elif diff > 0:
		return "+%d" % diff
	else:
		return "%d" % diff

func _get_thru_text(entry: Dictionary) -> String:
	if entry.is_finished:
		return "F"
	if entry.holes_completed > 0:
		return "%d" % entry.holes_completed
	return "-"

func _get_score_color(diff: int, total_par: int) -> Color:
	if total_par == 0:
		return UIConstants.COLOR_TEXT_DIM
	if diff < 0:
		return UIConstants.COLOR_SCORE_UNDER
	if diff == 0:
		return UIConstants.COLOR_SCORE_PAR
	return UIConstants.COLOR_SCORE_OVER

func _position_panel() -> void:
	await get_tree().process_frame
	var vp_size = get_viewport().get_visible_rect().size
	position = Vector2(vp_size.x - size.x - RIGHT_MARGIN, TOP_MARGIN)
