extends PanelContainer
class_name TournamentLeaderboard
## Live leaderboard panel shown during tournaments.
## Anchored to the right side of the screen, updates in real-time.

const PANEL_WIDTH: float = 280.0
const TOP_MARGIN: float = 45.0
const RIGHT_MARGIN: float = 10.0

var _entries: Array = []  # Array of {golfer_id, name, total_strokes, total_par, holes_completed, is_finished}
var _grid: GridContainer = null
var _title_label: Label = null
var _close_btn: Button = null
var _tournament_name: String = ""
var _is_final: bool = false

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
	_close_btn.visible = false  # Only show after tournament completes
	title_row.add_child(_close_btn)

	vbox.add_child(HSeparator.new())

	# Header row
	var header := _create_row("", "Name", "Score", "Thru", UIConstants.COLOR_TEXT_DIM)
	vbox.add_child(header)

	# Scrollable grid area
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 200)
	vbox.add_child(scroll)

	_grid = GridContainer.new()
	_grid.columns = 1
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid)

func show_for_tournament(tournament_name: String) -> void:
	_tournament_name = tournament_name
	_is_final = false
	_entries.clear()
	_title_label.text = "%s — LIVE" % tournament_name
	_close_btn.visible = false
	_refresh_display()
	_position_panel()
	show()

func register_golfer(golfer_id: int, golfer_name: String) -> void:
	_entries.append({
		"golfer_id": golfer_id,
		"name": golfer_name,
		"total_strokes": 0,
		"total_par": 0,
		"holes_completed": 0,
		"is_finished": false,
	})

func update_score(golfer_id: int, _hole: int, strokes: int, par: int) -> void:
	for entry in _entries:
		if entry.golfer_id == golfer_id:
			entry.total_strokes += strokes
			entry.total_par += par
			entry.holes_completed += 1
			break
	_refresh_display()

func mark_finished(golfer_id: int, total_strokes: int) -> void:
	for entry in _entries:
		if entry.golfer_id == golfer_id:
			entry.is_finished = true
			# Use the authoritative total from the golfer
			entry.total_strokes = total_strokes
			break
	_refresh_display()

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

func show_final_results() -> void:
	_is_final = true
	_title_label.text = "%s — FINAL" % _tournament_name
	_close_btn.visible = true
	_refresh_display()

func _refresh_display() -> void:
	# Clear grid
	for child in _grid.get_children():
		child.queue_free()

	# Sort entries: finished first by score vs par, then unfinished by score vs par
	var sorted = _entries.duplicate()
	sorted.sort_custom(func(a, b):
		var a_diff = a.total_strokes - a.total_par if a.total_par > 0 else 999
		var b_diff = b.total_strokes - b.total_par if b.total_par > 0 else 999
		return a_diff < b_diff
	)

	for i in range(sorted.size()):
		var entry = sorted[i]
		var rank_text = "%d" % (i + 1)
		var score_text = _format_score(entry)
		var thru_text = "%d" % entry.holes_completed
		if entry.is_finished:
			thru_text = "F"
		var score_color = _get_score_color(entry.total_strokes - entry.total_par, entry.total_par)
		var row = _create_row(rank_text, entry.name, score_text, thru_text, score_color)
		_grid.add_child(row)

func _format_score(entry: Dictionary) -> String:
	if entry.total_par == 0:
		return "-"
	var diff = entry.total_strokes - entry.total_par
	if diff == 0:
		return "E"
	elif diff > 0:
		return "+%d" % diff
	else:
		return "%d" % diff

func _get_score_color(diff: int, total_par: int) -> Color:
	if total_par == 0:
		return UIConstants.COLOR_TEXT_DIM
	if diff < 0:
		return UIConstants.COLOR_SCORE_UNDER
	if diff == 0:
		return UIConstants.COLOR_SCORE_PAR
	return UIConstants.COLOR_SCORE_OVER

func _create_row(rank: String, player_name: String, score: String, thru: String, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	var rank_label := Label.new()
	rank_label.text = rank
	rank_label.add_theme_font_size_override("font_size", 11)
	rank_label.custom_minimum_size = Vector2(22, 0)
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rank_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_DIM)
	row.add_child(rank_label)

	var name_label := Label.new()
	name_label.text = player_name
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	row.add_child(name_label)

	var score_label := Label.new()
	score_label.text = score
	score_label.add_theme_font_size_override("font_size", 11)
	score_label.custom_minimum_size = Vector2(35, 0)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_label.add_theme_color_override("font_color", color)
	row.add_child(score_label)

	var thru_label := Label.new()
	thru_label.text = thru
	thru_label.add_theme_font_size_override("font_size", 11)
	thru_label.custom_minimum_size = Vector2(28, 0)
	thru_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	thru_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_DIM)
	row.add_child(thru_label)

	return row

func _position_panel() -> void:
	await get_tree().process_frame
	var vp_size = get_viewport().get_visible_rect().size
	position = Vector2(vp_size.x - size.x - RIGHT_MARGIN, TOP_MARGIN)
