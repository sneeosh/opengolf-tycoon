extends CenteredPanel
class_name TournamentResultsPopup
## TournamentResultsPopup - Shows full tournament results when a tournament completes.
## Displays leaderboard, financial summary, and reputation earned.

signal closed

var _tier: int = 0
var _results: Dictionary = {}
var _entries: Array = []

func show_results(tier: int, results: Dictionary, entries: Array) -> void:
	_tier = tier
	_results = results
	_entries = entries
	# Clear any existing children (from previous showing)
	for child in get_children():
		child.queue_free()
	# Wait a frame for cleanup, then build and show
	await get_tree().process_frame
	_build_ui()
	show_centered()

func _build_ui() -> void:
	var viewport_height = 800
	if get_viewport():
		viewport_height = get_viewport().get_visible_rect().size.y
	var panel_height = min(620, viewport_height - 100)
	custom_minimum_size = Vector2(380, panel_height)

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
	var title = Label.new()
	title.text = tier_data.get("name", "Tournament") + " — Results"
	title.add_theme_font_size_override("font_size", 22)
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

	vbox.add_child(HSeparator.new())

	# Leaderboard section
	var lb_title = Label.new()
	lb_title.text = "Leaderboard"
	lb_title.add_theme_font_size_override("font_size", 14)
	lb_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lb_title)

	# Header row
	var header = _create_leaderboard_row("", "Name", "Score", UIConstants.COLOR_TEXT_DIM)
	vbox.add_child(header)

	# Leaderboard entries (already sorted by caller)
	for i in range(_entries.size()):
		var entry = _entries[i]
		var rank_text = "%d." % (i + 1)
		var diff = entry.get("total_strokes", 0) - entry.get("total_par", 0)
		var score_text = _format_score_vs_par(diff)
		var score_color = _get_score_color(diff)

		# Highlight winner row
		if i == 0:
			score_color = UIConstants.COLOR_GOLD

		var row = _create_leaderboard_row(rank_text, entry.get("name", ""), score_text, score_color)
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

	var fee_row = _create_stat_row("Entry Fee:", "-$%d" % entry_cost, UIConstants.COLOR_DANGER_DIM)
	vbox.add_child(fee_row)

	if spectator_rev > 0:
		var spec_row = _create_stat_row("Spectator Revenue:", "+$%d" % spectator_rev, UIConstants.COLOR_SUCCESS_DIM)
		vbox.add_child(spec_row)

	if sponsor_rev > 0:
		var spon_row = _create_stat_row("Sponsorship Revenue:", "+$%d" % sponsor_rev, UIConstants.COLOR_SUCCESS_DIM)
		vbox.add_child(spon_row)

	var net_color = UIConstants.COLOR_SUCCESS if net >= 0 else UIConstants.COLOR_DANGER
	var net_text = "+$%d" % net if net >= 0 else "-$%d" % abs(net)
	var net_row = _create_stat_row("Net Income:", net_text, net_color)
	vbox.add_child(net_row)

	vbox.add_child(HSeparator.new())

	# Reputation earned
	var rep_reward = tier_data.get("reputation_reward", 0)
	var rep_row = _create_stat_row("Reputation Earned:", "+%d" % rep_reward, UIConstants.COLOR_INFO)
	vbox.add_child(rep_row)

	# Close button (fixed at bottom, outside scroll)
	main_vbox.add_child(HSeparator.new())

	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(200, 38)
	close_btn.pressed.connect(_on_close_pressed)
	main_vbox.add_child(close_btn)

func _create_leaderboard_row(rank: String, player_name: String, score: String, color: Color) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	var rank_label = Label.new()
	rank_label.text = rank
	rank_label.add_theme_font_size_override("font_size", 12)
	rank_label.custom_minimum_size = Vector2(28, 0)
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rank_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_DIM)
	row.add_child(rank_label)

	var name_label = Label.new()
	name_label.text = player_name
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	row.add_child(name_label)

	var score_label = Label.new()
	score_label.text = score
	score_label.add_theme_font_size_override("font_size", 12)
	score_label.custom_minimum_size = Vector2(40, 0)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_label.add_theme_color_override("font_color", color)
	row.add_child(score_label)

	return row

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
