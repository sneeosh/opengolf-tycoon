extends CenteredPanel
class_name TournamentResultsPopup
## TournamentResultsPopup - Shows full tournament results when a tournament completes.
## Displays leaderboard with per-round scores, dramatic moments,
## financial summary, and reputation earned.

signal closed

var _tier: int = 0
var _results: Dictionary = {}
var _entries: Array = []

func show_results(tier: int, results: Dictionary, entries: Array) -> void:
	_tier = tier
	_results = results
	_entries = entries
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame
	_build_content()
	show_centered()

## No-op: don't build anything on _ready(). Content is built on-demand via show_results().
func _build_ui() -> void:
	pass

func _build_content() -> void:
	var viewport_height = 800
	if get_viewport():
		viewport_height = get_viewport().get_visible_rect().size.y
	var panel_height = min(680, viewport_height - 80)
	var total_rounds = _results.get("total_rounds", 1)
	var panel_width = 380 if total_rounds <= 1 else 480
	custom_minimum_size = Vector2(panel_width, panel_height)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	margin.add_child(main_vbox)

	# Title
	var tier_data = TournamentSystem.get_tier_data(_tier)
	var rounds_played = _results.get("rounds_played", 1)
	var title = Label.new()
	var title_text = tier_data.get("name", "Tournament") + " — Results"
	if total_rounds > 1:
		title_text += " (%d rounds)" % rounds_played
	title.text = title_text
	title.add_theme_font_size_override("font_size", 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(title)

	main_vbox.add_child(HSeparator.new())

	# Scrollable content
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# Winner highlight
	var winner_name = _results.get("winner_name", "Unknown")
	var winning_score = _results.get("winning_score", 0)
	var par = _results.get("par", 72)
	var winner_diff = winning_score - par
	var winner_score_text = _format_score_vs_par(winner_diff)

	var winner_label = Label.new()
	winner_label.text = "Winner: %s (%s)" % [winner_name, winner_score_text]
	winner_label.add_theme_font_size_override("font_size", 16)
	winner_label.add_theme_color_override("font_color", UIConstants.COLOR_GOLD)
	winner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(winner_label)

	# Dramatic moments section
	var moments = _results.get("moments", [])
	var high_moments = moments.filter(func(m): return m.importance >= 2)
	if not high_moments.is_empty():
		vbox.add_child(HSeparator.new())
		var moments_title = Label.new()
		moments_title.text = "Highlights"
		moments_title.add_theme_font_size_override("font_size", 13)
		moments_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		moments_title.add_theme_color_override("font_color", UIConstants.COLOR_GOLD)
		vbox.add_child(moments_title)

		for moment in high_moments.slice(0, 5):  # Show up to 5 highlights
			var m_label = Label.new()
			m_label.text = moment.detail
			m_label.add_theme_font_size_override("font_size", 11)
			m_label.add_theme_color_override("font_color", UIConstants.COLOR_INFO)
			m_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			m_label.autowrap_mode = TextServer.AUTOWRAP_WORD
			vbox.add_child(m_label)

	vbox.add_child(HSeparator.new())

	# Leaderboard section
	var lb_title = Label.new()
	lb_title.text = "Final Leaderboard"
	lb_title.add_theme_font_size_override("font_size", 14)
	lb_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lb_title)

	# Header row
	var header = _create_leaderboard_header(total_rounds)
	vbox.add_child(header)

	# Leaderboard entries
	var cut_line_shown = false
	for i in range(_entries.size()):
		var entry = _entries[i]
		var is_mc = entry.get("missed_cut", false)

		# Show cut line separator
		if is_mc and not cut_line_shown:
			cut_line_shown = true
			var cut_sep = HBoxContainer.new()
			var cut_label = Label.new()
			cut_label.text = "— CUT LINE —"
			cut_label.add_theme_font_size_override("font_size", 10)
			cut_label.add_theme_color_override("font_color", UIConstants.COLOR_SCORE_OVER)
			cut_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cut_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cut_sep.add_child(cut_label)
			vbox.add_child(cut_sep)

		var rank_text = "%d." % (i + 1)
		var diff = entry.get("score_to_par", entry.get("total_strokes", 0) - entry.get("total_par", 0))
		var score_text = _format_score_vs_par(diff)
		var score_color = _get_score_color(diff)
		if i == 0:
			score_color = UIConstants.COLOR_GOLD
		if is_mc:
			score_color = UIConstants.COLOR_TEXT_DIM

		var round_scores = entry.get("round_scores", [])
		var row = _create_leaderboard_entry(rank_text, entry.get("name", ""),
			round_scores, score_text, score_color, total_rounds, is_mc)
		vbox.add_child(row)

	vbox.add_child(HSeparator.new())

	# Financial summary
	var finance_title = Label.new()
	finance_title.text = "Financial Summary"
	finance_title.add_theme_font_size_override("font_size", 14)
	finance_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(finance_title)

	var entry_cost = tier_data.get("entry_cost", 0)
	var spectator_rev = _results.get("spectator_revenue", 0)
	var sponsor_rev = _results.get("sponsorship_revenue", 0)
	var total_rev = _results.get("total_revenue", 0)
	var net = total_rev - entry_cost

	vbox.add_child(_create_stat_row("Entry Fee:", "-$%d" % entry_cost, UIConstants.COLOR_DANGER_DIM))

	if spectator_rev > 0:
		var drama_mult = _results.get("drama_multiplier", 1.0)
		var spec_text = "+$%d" % spectator_rev
		if drama_mult > 1.05:
			spec_text += " (%.0f%% drama bonus)" % ((drama_mult - 1.0) * 100)
		vbox.add_child(_create_stat_row("Spectator Revenue:", spec_text, UIConstants.COLOR_SUCCESS_DIM))

	if sponsor_rev > 0:
		vbox.add_child(_create_stat_row("Sponsorship Revenue:", "+$%d" % sponsor_rev, UIConstants.COLOR_SUCCESS_DIM))

	var net_color = UIConstants.COLOR_SUCCESS if net >= 0 else UIConstants.COLOR_DANGER
	var net_text = "+$%d" % net if net >= 0 else "-$%d" % abs(net)
	vbox.add_child(_create_stat_row("Net Income:", net_text, net_color))

	vbox.add_child(HSeparator.new())

	# Reputation earned
	var rep_reward = tier_data.get("reputation_reward", 0)
	vbox.add_child(_create_stat_row("Reputation Earned:", "+%d" % rep_reward, UIConstants.COLOR_INFO))

	# Close button
	main_vbox.add_child(HSeparator.new())

	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(200, 38)
	close_btn.pressed.connect(_on_close_pressed)
	main_vbox.add_child(close_btn)

func _create_leaderboard_header(total_rounds: int) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	row.add_child(_make_lbl("", 28, UIConstants.COLOR_TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT))

	var name_lbl = _make_lbl("Name", 0, UIConstants.COLOR_TEXT_DIM)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)

	if total_rounds > 1:
		for r in range(total_rounds):
			row.add_child(_make_lbl("R%d" % (r + 1), 28, UIConstants.COLOR_TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT))

	row.add_child(_make_lbl("Tot", 40, UIConstants.COLOR_TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT))

	return row

func _create_leaderboard_entry(rank: String, player_name: String,
		round_scores: Array, score: String, color: Color,
		total_rounds: int, missed_cut: bool) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	row.add_child(_make_lbl(rank, 28, UIConstants.COLOR_TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT))

	var name_color = Color.WHITE if not missed_cut else UIConstants.COLOR_TEXT_DIM
	var name_lbl = _make_lbl(player_name, 0, name_color)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.clip_text = true
	row.add_child(name_lbl)

	if total_rounds > 1:
		for r in range(total_rounds):
			var r_text = "-"
			var r_color = UIConstants.COLOR_TEXT_DIM
			if r < round_scores.size():
				var r_diff = round_scores[r]
				r_text = _format_score_vs_par(r_diff)
				r_color = _get_score_color(r_diff)
				if missed_cut:
					r_color = UIConstants.COLOR_TEXT_DIM
			row.add_child(_make_lbl(r_text, 28, r_color, HORIZONTAL_ALIGNMENT_RIGHT))

	var mc_text = "MC" if missed_cut else ""
	if missed_cut:
		var score_mc = _make_lbl(score + " " + mc_text, 55, color, HORIZONTAL_ALIGNMENT_RIGHT)
		row.add_child(score_mc)
	else:
		row.add_child(_make_lbl(score, 40, color, HORIZONTAL_ALIGNMENT_RIGHT))

	return row

func _make_lbl(text: String, min_width: int, color: Color,
		alignment: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = alignment
	if min_width > 0:
		label.custom_minimum_size = Vector2(min_width, 0)
	return label

func _create_stat_row(label_text: String, value_text: String, value_color: Color = Color.WHITE) -> HBoxContainer:
	var row = HBoxContainer.new()

	var label = Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var value = Label.new()
	value.text = value_text
	value.add_theme_color_override("font_color", value_color)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)

	return row

func _format_score_vs_par(diff: int) -> String:
	if diff == 0:
		return "E"
	elif diff > 0:
		return "+%d" % diff
	else:
		return "%d" % diff

func _get_score_color(diff: int) -> Color:
	if diff < 0:
		return UIConstants.COLOR_SCORE_UNDER
	if diff == 0:
		return UIConstants.COLOR_SCORE_PAR
	return UIConstants.COLOR_SCORE_OVER

func _on_close_pressed() -> void:
	closed.emit()
	hide()
