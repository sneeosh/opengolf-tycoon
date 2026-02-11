extends PanelContainer
class_name FinancialPanel
## FinancialPanel - Detailed financial breakdown toggled by clicking money display

signal close_requested

var _vbox: VBoxContainer = null

func _ready() -> void:
	_build_ui()
	hide()

func _build_ui() -> void:
	custom_minimum_size = Vector2(320, 400)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 6)
	margin.add_child(_vbox)

func update_display() -> void:
	# Clear existing content
	for child in _vbox.get_children():
		child.queue_free()

	# Title
	var title = Label.new()
	title.text = "Financial Overview"
	title.add_theme_font_size_override("font_size", 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vbox.add_child(title)

	_vbox.add_child(HSeparator.new())

	var stats = GameManager.daily_stats
	var yesterday = GameManager.yesterday_stats

	# Current Balance
	var balance_label = Label.new()
	balance_label.text = "Current Balance"
	balance_label.add_theme_font_size_override("font_size", 14)
	_vbox.add_child(balance_label)

	var balance_row = _create_stat_row("Cash:", "$%d" % GameManager.money, Color(1.0, 1.0, 1.0))
	_vbox.add_child(balance_row)

	_vbox.add_child(HSeparator.new())

	# Today's Revenue
	var revenue_label = Label.new()
	revenue_label.text = "Today's Revenue"
	revenue_label.add_theme_font_size_override("font_size", 14)
	_vbox.add_child(revenue_label)

	var dim_green = Color(0.5, 0.8, 0.5)
	var greenfee_row = _create_stat_row("  Green Fees:", "$%d" % stats.revenue, dim_green)
	_vbox.add_child(greenfee_row)

	var building_row = _create_stat_row("  Amenities:", "$%d" % stats.building_revenue, dim_green)
	_vbox.add_child(building_row)

	var total_rev = stats.get_total_revenue()
	var total_rev_row = _create_stat_row("Total Revenue:", "$%d" % total_rev, Color(0.4, 0.9, 0.4))
	_vbox.add_child(total_rev_row)

	_vbox.add_child(HSeparator.new())

	# Today's Costs
	var costs_label = Label.new()
	costs_label.text = "Today's Costs"
	costs_label.add_theme_font_size_override("font_size", 14)
	_vbox.add_child(costs_label)

	var dim_color = Color(0.7, 0.7, 0.7)
	if stats.terrain_maintenance > 0:
		var terrain_row = _create_stat_row("  Terrain:", "-$%d" % stats.terrain_maintenance, dim_color)
		_vbox.add_child(terrain_row)
	if stats.base_operating_cost > 0:
		var base_row = _create_stat_row("  Base:", "-$%d" % stats.base_operating_cost, dim_color)
		_vbox.add_child(base_row)
	if stats.staff_wages > 0:
		var staff_row = _create_stat_row("  Staff:", "-$%d" % stats.staff_wages, dim_color)
		_vbox.add_child(staff_row)

	var total_costs_row = _create_stat_row("Total Costs:", "-$%d" % stats.operating_costs, Color(0.9, 0.5, 0.5))
	_vbox.add_child(total_costs_row)

	_vbox.add_child(HSeparator.new())

	# Today's Profit/Loss
	var profit = stats.get_profit()
	var profit_color = Color(0.4, 0.9, 0.4) if profit >= 0 else Color(0.9, 0.4, 0.4)
	var profit_text = "+$%d" % profit if profit >= 0 else "-$%d" % abs(profit)
	var profit_row = _create_stat_row("Today's Profit:", profit_text, profit_color)
	_vbox.add_child(profit_row)

	# Yesterday's Comparison (if available)
	if yesterday != null:
		_vbox.add_child(HSeparator.new())

		var compare_label = Label.new()
		compare_label.text = "Yesterday's Results"
		compare_label.add_theme_font_size_override("font_size", 14)
		_vbox.add_child(compare_label)

		var yest_rev = yesterday.get_total_revenue()
		var yest_profit = yesterday.get_profit()

		var yest_rev_row = _create_stat_row("  Revenue:", "$%d" % yest_rev, dim_color)
		_vbox.add_child(yest_rev_row)

		var yest_profit_color = Color(0.6, 0.8, 0.6) if yest_profit >= 0 else Color(0.8, 0.6, 0.6)
		var yest_profit_text = "+$%d" % yest_profit if yest_profit >= 0 else "-$%d" % abs(yest_profit)
		var yest_profit_row = _create_stat_row("  Profit:", yest_profit_text, yest_profit_color)
		_vbox.add_child(yest_profit_row)

		# Show trend
		var trend_diff = profit - yest_profit
		var trend_text = ""
		var trend_color = Color(0.7, 0.7, 0.7)
		if trend_diff > 0:
			trend_text = "+$%d vs yesterday" % trend_diff
			trend_color = Color(0.4, 0.9, 0.4)
		elif trend_diff < 0:
			trend_text = "-$%d vs yesterday" % abs(trend_diff)
			trend_color = Color(0.9, 0.4, 0.4)
		else:
			trend_text = "Same as yesterday"

		var trend_row = _create_stat_row("Trend:", trend_text, trend_color)
		_vbox.add_child(trend_row)

	_vbox.add_child(HSeparator.new())

	# Reputation
	var rep_label = Label.new()
	rep_label.text = "Course Status"
	rep_label.add_theme_font_size_override("font_size", 14)
	_vbox.add_child(rep_label)

	var reputation = GameManager.reputation
	var rep_color = Color(0.4, 0.9, 0.4) if reputation >= 70 else (Color(0.9, 0.9, 0.4) if reputation >= 40 else Color(0.9, 0.4, 0.4))
	var rep_row = _create_stat_row("Reputation:", "%.0f%%" % reputation, rep_color)
	_vbox.add_child(rep_row)

	var golfers_row = _create_stat_row("Golfers Today:", "%d" % stats.golfers_served, Color.WHITE)
	_vbox.add_child(golfers_row)

	# Spacer
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_vbox.add_child(spacer)

	# Close button
	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(_on_close_pressed)
	_vbox.add_child(close_btn)

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

func toggle() -> void:
	if visible:
		hide()
	else:
		update_display()
		show()
