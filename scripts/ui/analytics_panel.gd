extends CenteredPanel
class_name AnalyticsPanel
## AnalyticsPanel - Course analytics dashboard with 7-day trends

signal close_requested

var _content_vbox: VBoxContainer = null
var _scroll: ScrollContainer = null
var _chart: Control = null
var _update_queued: bool = false

func _build_ui() -> void:
	EventBus.golfer_finished_hole.connect(_on_data_changed)
	EventBus.golfer_finished_round.connect(_on_data_changed)
	EventBus.end_of_day.connect(_on_data_changed)
	EventBus.day_changed.connect(_on_data_changed)

	custom_minimum_size = Vector2(420, 600)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 4)
	margin.add_child(main_vbox)

	# Title row with close button
	var title_row = HBoxContainer.new()
	main_vbox.add_child(title_row)

	var title = Label.new()
	title.text = "Course Analytics (Z)"
	title.add_theme_font_size_override("font_size", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(30, 30)
	close_btn.pressed.connect(_on_close_pressed)
	title_row.add_child(close_btn)

	main_vbox.add_child(HSeparator.new())

	# Scrollable content area
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.custom_minimum_size = Vector2(0, 530)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(_scroll)

	_content_vbox = VBoxContainer.new()
	_content_vbox.add_theme_constant_override("separation", 3)
	_content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content_vbox)

func update_display() -> void:
	for child in _content_vbox.get_children():
		child.queue_free()

	var history = GameManager.daily_history

	# Section 1: Revenue Overview
	_add_section_header("Profit Overview (7-Day)")

	if history.size() < 1:
		_add_dim_label("  No data yet - play at least 1 day")
	else:
		# Mini bar chart in horizontal scroll container
		var chart_scroll = ScrollContainer.new()
		chart_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		chart_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		chart_scroll.custom_minimum_size = Vector2(0, 100)
		_content_vbox.add_child(chart_scroll)

		_chart = MiniBarChart.new()
		_chart.custom_minimum_size = Vector2(380, 100)
		_chart.set_data(history)
		chart_scroll.add_child(_chart)

		# Summary stats from last 7 days
		var recent = _get_recent(history, 7)
		var total_profit = 0
		var total_revenue = 0
		var total_costs = 0
		var total_golfers = 0
		for entry in recent:
			total_profit += entry.get("profit", 0)
			total_revenue += entry.get("revenue", 0)
			total_costs += entry.get("costs", 0)
			total_golfers += entry.get("golfers_served", 0)

		var avg_profit = total_profit / max(recent.size(), 1)
		var profit_color = Color(0.4, 0.9, 0.4) if avg_profit >= 0 else Color(0.9, 0.4, 0.4)
		_content_vbox.add_child(_create_stat_row("Avg Daily Profit:", "$%d" % avg_profit, profit_color))
		_content_vbox.add_child(_create_stat_row("7-Day Revenue:", "$%d" % total_revenue, Color(0.5, 0.8, 0.5)))
		_content_vbox.add_child(_create_stat_row("7-Day Costs:", "$%d" % total_costs, Color(0.9, 0.5, 0.5)))
		_content_vbox.add_child(_create_stat_row("Total Golfers:", "%d" % total_golfers, Color.WHITE))

	_content_vbox.add_child(HSeparator.new())

	# Section 2: Hole Analysis
	_add_section_header("Hole Analysis")

	if GameManager.hole_statistics.is_empty():
		_add_dim_label("  No hole data yet")
	else:
		var hardest_hole = -1
		var hardest_avg = -99.0
		var easiest_hole = -1
		var easiest_avg = 99.0
		var most_played_hole = -1
		var most_rounds = 0

		for hole_num in GameManager.hole_statistics:
			var stats: GameManager.HoleStatistics = GameManager.hole_statistics[hole_num]
			if stats.total_rounds == 0:
				continue

			# Get par for this hole
			var par = 4
			if GameManager.current_course:
				for hole in GameManager.current_course.holes:
					if hole.hole_number == hole_num:
						par = hole.par
						break

			var avg_to_par = stats.get_average_to_par(par)

			if avg_to_par > hardest_avg:
				hardest_avg = avg_to_par
				hardest_hole = hole_num
			if avg_to_par < easiest_avg:
				easiest_avg = avg_to_par
				easiest_hole = hole_num
			if stats.total_rounds > most_rounds:
				most_rounds = stats.total_rounds
				most_played_hole = hole_num

		if hardest_hole > 0:
			var h_text = "Hole %d (+%.1f avg)" % [hardest_hole, hardest_avg]
			_content_vbox.add_child(_create_stat_row("Hardest:", h_text, Color(0.9, 0.5, 0.5)))
		if easiest_hole > 0:
			var e_text = "Hole %d (%.1f avg)" % [easiest_hole, easiest_avg]
			_content_vbox.add_child(_create_stat_row("Easiest:", e_text, Color(0.5, 0.9, 0.5)))
		if most_played_hole > 0:
			_content_vbox.add_child(_create_stat_row("Most Played:", "Hole %d (%d rounds)" % [most_played_hole, most_rounds], Color.WHITE))

	_content_vbox.add_child(HSeparator.new())

	# Section 3: Golfer Demographics
	_add_section_header("Golfer Demographics (7-Day)")

	if history.size() < 1:
		_add_dim_label("  No data yet")
	else:
		var recent = _get_recent(history, 7)
		var totals = {
			GolferTier.Tier.BEGINNER: 0,
			GolferTier.Tier.CASUAL: 0,
			GolferTier.Tier.SERIOUS: 0,
			GolferTier.Tier.PRO: 0,
		}
		for entry in recent:
			var tc = entry.get("tier_counts", {})
			for tier_key in tc:
				# JSON keys may be strings; convert to int
				var tier_int = int(tier_key)
				if tier_int in totals:
					totals[tier_int] += int(tc[tier_key])

		var grand_total = 0
		for v in totals.values():
			grand_total += v

		if grand_total > 0:
			var tier_colors = {
				GolferTier.Tier.BEGINNER: Color(0.5, 0.8, 0.5),
				GolferTier.Tier.CASUAL: Color(0.5, 0.7, 0.9),
				GolferTier.Tier.SERIOUS: Color(0.9, 0.7, 0.3),
				GolferTier.Tier.PRO: Color(0.9, 0.4, 0.4),
			}
			for tier in [GolferTier.Tier.BEGINNER, GolferTier.Tier.CASUAL, GolferTier.Tier.SERIOUS, GolferTier.Tier.PRO]:
				var pct = int(float(totals[tier]) / grand_total * 100)
				var name = GolferTier.get_tier_name(tier)
				_content_vbox.add_child(_create_stat_row("  %s:" % name, "%d%% (%d)" % [pct, totals[tier]], tier_colors[tier]))
		else:
			_add_dim_label("  No golfer data yet")

	_content_vbox.add_child(HSeparator.new())

	# Section 4: Course Health
	_add_section_header("Course Health")

	if history.size() < 2:
		_add_dim_label("  Need 2+ days of data")
	else:
		var recent = _get_recent(history, 7)

		# Satisfaction trend
		if recent.size() >= 2:
			var first_sat = recent[0].get("satisfaction", 0.5)
			var last_sat = recent[-1].get("satisfaction", 0.5)
			var sat_diff = last_sat - first_sat
			var trend_text: String
			var trend_color: Color
			if sat_diff > 0.05:
				trend_text = "Improving (%.0f%%)" % (last_sat * 100)
				trend_color = Color(0.4, 0.9, 0.4)
			elif sat_diff < -0.05:
				trend_text = "Declining (%.0f%%)" % (last_sat * 100)
				trend_color = Color(0.9, 0.4, 0.4)
			else:
				trend_text = "Stable (%.0f%%)" % (last_sat * 100)
				trend_color = Color(0.9, 0.9, 0.4)
			_content_vbox.add_child(_create_stat_row("Satisfaction:", trend_text, trend_color))

		# Reputation trend
		if recent.size() >= 2:
			var first_rep = recent[0].get("reputation", 50.0)
			var last_rep = recent[-1].get("reputation", 50.0)
			var rep_diff = last_rep - first_rep
			var rep_text: String
			var rep_color: Color
			if rep_diff > 1.0:
				rep_text = "%.0f%% (+%.1f)" % [last_rep, rep_diff]
				rep_color = Color(0.4, 0.9, 0.4)
			elif rep_diff < -1.0:
				rep_text = "%.0f%% (%.1f)" % [last_rep, rep_diff]
				rep_color = Color(0.9, 0.4, 0.4)
			else:
				rep_text = "%.0f%% (stable)" % last_rep
				rep_color = Color(0.9, 0.9, 0.4)
			_content_vbox.add_child(_create_stat_row("Reputation:", rep_text, rep_color))

	# Top complaint from FeedbackManager
	if FeedbackManager:
		var top_complaint = FeedbackManager.get_top_complaint()
		if top_complaint != "":
			_content_vbox.add_child(_create_stat_row("Top Issue:", top_complaint, Color(0.9, 0.6, 0.3)))

func _get_recent(history: Array, count: int) -> Array:
	var start = max(0, history.size() - count)
	return history.slice(start)

func _add_section_header(text: String) -> void:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	_content_vbox.add_child(label)

func _add_dim_label(text: String) -> void:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_content_vbox.add_child(label)

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

func _on_close_pressed() -> void:
	close_requested.emit()
	hide()

func _on_data_changed(_arg1 = null, _arg2 = null, _arg3 = null, _arg4 = null) -> void:
	if not visible or _update_queued:
		return
	_update_queued = true
	# Defer to avoid multiple rebuilds in a single frame
	call_deferred("_deferred_update")

func _deferred_update() -> void:
	_update_queued = false
	if visible:
		update_display()

func toggle() -> void:
	if visible:
		hide()
	else:
		update_display()
		show_centered()

## MiniBarChart - Draws a 7-day profit bar chart using _draw()
class MiniBarChart extends Control:
	var _data: Array = []
	var _hovered_bar: int = -1
	var _bar_rects: Array[Rect2] = []

	func _ready() -> void:
		mouse_exited.connect(_on_mouse_exited)

	func set_data(history: Array) -> void:
		# Get last 7 days
		var start = max(0, history.size() - 7)
		_data = history.slice(start)
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			var old_hovered = _hovered_bar
			_hovered_bar = -1
			for i in range(_bar_rects.size()):
				if _bar_rects[i].has_point(event.position):
					_hovered_bar = i
					break
			if _hovered_bar != old_hovered:
				queue_redraw()

	func _on_mouse_exited() -> void:
		if _hovered_bar != -1:
			_hovered_bar = -1
			queue_redraw()

	func _draw() -> void:
		if _data.is_empty():
			return

		var w = size.x
		var h = size.y
		var bar_count = _data.size()
		var bar_width = (w - 20) / max(bar_count, 1)
		var padding = 2.0

		# Find max absolute value for scaling
		var max_val = 1
		for entry in _data:
			var profit = abs(entry.get("profit", 0))
			if profit > max_val:
				max_val = profit

		# Draw zero line
		var zero_y = h / 2.0
		draw_line(Vector2(10, zero_y), Vector2(w - 10, zero_y), Color(0.4, 0.4, 0.4), 1.0)

		# Draw "0" label
		var font = ThemeDB.fallback_font
		draw_string(font, Vector2(0, zero_y + 4), "0", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.5, 0.5, 0.5))

		# Build bar rects and draw bars
		_bar_rects.clear()
		for i in range(bar_count):
			var profit = _data[i].get("profit", 0)
			var bar_height = (float(abs(profit)) / max_val) * (h / 2.0 - 10)
			var x = 10 + i * bar_width + padding
			var bw = bar_width - padding * 2

			var is_hovered = (i == _hovered_bar)
			# Hit area spans full column height for easier hovering
			_bar_rects.append(Rect2(x, 5, bw, h - 15))

			if profit >= 0:
				var color = Color(0.4, 0.85, 0.4, 0.95) if is_hovered else Color(0.3, 0.7, 0.3, 0.8)
				var bar_rect = Rect2(x, zero_y - bar_height, bw, bar_height)
				draw_rect(bar_rect, color)
			else:
				var color = Color(0.85, 0.4, 0.4, 0.95) if is_hovered else Color(0.7, 0.3, 0.3, 0.8)
				var bar_rect = Rect2(x, zero_y, bw, bar_height)
				draw_rect(bar_rect, color)

			# Day label below
			var day_num = _data[i].get("day", 0)
			draw_string(font, Vector2(x + bw / 2 - 4, h - 2), str(day_num), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.5, 0.5, 0.5))

		# Draw hover tooltip
		if _hovered_bar >= 0 and _hovered_bar < _data.size():
			_draw_tooltip(font)

	func _draw_tooltip(font: Font) -> void:
		var entry = _data[_hovered_bar]
		var day = int(entry.get("day", 0))
		var profit = int(entry.get("profit", 0))
		var season = int(entry.get("season", 0))
		var season_name = SeasonSystem.get_season_name(season)
		var year = SeasonSystem.get_year(day)
		var day_in_season = SeasonSystem.get_day_in_season(day)

		var line1 = "%s D%d, Y%d" % [season_name, day_in_season, year]
		var line2 = "Profit: $%d" % profit

		var font_size = 11
		var line_height = 14
		var tooltip_w = 110.0
		var tooltip_h = line_height * 2.0 + 8.0
		var pad = 6.0

		# Position tooltip near the hovered bar, above the day labels
		var bar_rect = _bar_rects[_hovered_bar]
		var tx = bar_rect.position.x + bar_rect.size.x / 2.0 - tooltip_w / 2.0
		# Clamp to chart bounds
		tx = clampf(tx, 2.0, size.x - tooltip_w - 2.0)
		var ty = size.y - tooltip_h - 12.0

		# Background
		var bg_rect = Rect2(tx, ty, tooltip_w, tooltip_h)
		draw_rect(bg_rect, Color(0.12, 0.12, 0.12, 0.92))
		draw_rect(bg_rect, Color(0.5, 0.5, 0.5, 0.5), false, 1.0)

		# Text
		draw_string(font, Vector2(tx + pad, ty + line_height), line1, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.85, 0.85, 0.85))
		var profit_color = Color(0.4, 0.9, 0.4) if profit >= 0 else Color(0.9, 0.4, 0.4)
		draw_string(font, Vector2(tx + pad, ty + line_height * 2), line2, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, profit_color)
