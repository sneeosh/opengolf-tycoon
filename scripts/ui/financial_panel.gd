extends CenteredPanel
class_name FinancialPanel
## FinancialPanel - Detailed financial breakdown toggled by clicking money display

signal close_requested

var _content_vbox: VBoxContainer = null
var _scroll: ScrollContainer = null

func _build_ui() -> void:
	custom_minimum_size = Vector2(360, 620)

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
	title.text = "Financial Overview"
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
	main_vbox.add_child(_scroll)

	_content_vbox = VBoxContainer.new()
	_content_vbox.add_theme_constant_override("separation", 3)
	_content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content_vbox)

func update_display() -> void:
	# Clear existing content
	for child in _content_vbox.get_children():
		child.queue_free()

	var stats = GameManager.daily_stats
	var yesterday = GameManager.yesterday_stats

	# Current Balance
	var balance_label = Label.new()
	balance_label.text = "Current Balance"
	balance_label.add_theme_font_size_override("font_size", 13)
	_content_vbox.add_child(balance_label)

	var balance_row = _create_stat_row("Cash:", "$%d" % GameManager.money, UIConstants.COLOR_TEXT)
	_content_vbox.add_child(balance_row)

	# Green Fee control
	var fee_row = HBoxContainer.new()
	var fee_label = Label.new()
	fee_label.text = "Fee/hole:"
	fee_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fee_row.add_child(fee_label)

	var fee_decrease = Button.new()
	fee_decrease.text = "-"
	fee_decrease.custom_minimum_size = Vector2(28, 28)
	fee_decrease.pressed.connect(func(): GameManager.set_green_fee(GameManager.green_fee - 5))
	fee_row.add_child(fee_decrease)

	var fee_value = Label.new()
	fee_value.text = "$%d/hole" % GameManager.green_fee
	fee_value.custom_minimum_size = Vector2(70, 0)
	fee_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fee_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fee_value.add_theme_color_override("font_color", UIConstants.COLOR_GOLD)
	fee_row.add_child(fee_value)

	var fee_increase = Button.new()
	fee_increase.text = "+"
	fee_increase.custom_minimum_size = Vector2(28, 28)
	fee_increase.pressed.connect(func(): GameManager.set_green_fee(GameManager.green_fee + 5))
	fee_row.add_child(fee_increase)

	_content_vbox.add_child(fee_row)

	# Show round cost and fee cap
	var holes = GameManager.get_open_hole_count()
	var total_cost = GameManager.green_fee * max(holes, 1)
	var max_fee = GameManager.get_effective_max_green_fee()
	var fee_info = Label.new()
	fee_info.text = "  Round: $%d (%d holes) | Max: $%d/hole" % [total_cost, max(holes, 1), max_fee]
	fee_info.add_theme_font_size_override("font_size", 11)
	fee_info.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_DIM)
	_content_vbox.add_child(fee_info)

	_content_vbox.add_child(HSeparator.new())

	# Today's Revenue
	var revenue_label = Label.new()
	revenue_label.text = "Today's Revenue"
	revenue_label.add_theme_font_size_override("font_size", 13)
	_content_vbox.add_child(revenue_label)

	var dim_green = UIConstants.COLOR_SUCCESS_DIM
	var greenfee_row = _create_stat_row("  Green Fees:", "$%d" % stats.revenue, dim_green)
	_content_vbox.add_child(greenfee_row)

	var building_row = _create_stat_row("  Amenities:", "$%d" % stats.building_revenue, dim_green)
	_content_vbox.add_child(building_row)

	var total_rev = stats.get_total_revenue()
	var total_rev_row = _create_stat_row("Total Revenue:", "$%d" % total_rev, UIConstants.COLOR_SUCCESS)
	_content_vbox.add_child(total_rev_row)

	_content_vbox.add_child(HSeparator.new())

	# Today's Costs
	var costs_label = Label.new()
	costs_label.text = "Today's Costs"
	costs_label.add_theme_font_size_override("font_size", 13)
	_content_vbox.add_child(costs_label)

	var dim_color = UIConstants.COLOR_TEXT_DIM
	if stats.terrain_maintenance > 0:
		var terrain_row = _create_stat_row("  Terrain:", "-$%d" % stats.terrain_maintenance, dim_color)
		_content_vbox.add_child(terrain_row)
	if stats.base_operating_cost > 0:
		var base_row = _create_stat_row("  Base:", "-$%d" % stats.base_operating_cost, dim_color)
		_content_vbox.add_child(base_row)
	if stats.staff_wages > 0:
		var staff_row = _create_stat_row("  Staff:", "-$%d" % stats.staff_wages, dim_color)
		_content_vbox.add_child(staff_row)
	if stats.building_operating_costs > 0:
		var building_costs_row = _create_stat_row("  Buildings:", "-$%d" % stats.building_operating_costs, dim_color)
		_content_vbox.add_child(building_costs_row)

	var total_costs_row = _create_stat_row("Total Costs:", "-$%d" % stats.operating_costs, UIConstants.COLOR_DANGER_DIM)
	_content_vbox.add_child(total_costs_row)

	_content_vbox.add_child(HSeparator.new())

	# Today's Profit/Loss
	var profit = stats.get_profit()
	var profit_color = UIConstants.COLOR_SUCCESS if profit >= 0 else UIConstants.COLOR_DANGER
	var profit_text = "+$%d" % profit if profit >= 0 else "-$%d" % abs(profit)
	var profit_row = _create_stat_row("Today's Profit:", profit_text, profit_color)
	_content_vbox.add_child(profit_row)

	# Yesterday's Comparison (if available)
	if yesterday != null:
		_content_vbox.add_child(HSeparator.new())

		var compare_label = Label.new()
		compare_label.text = "Yesterday's Results"
		compare_label.add_theme_font_size_override("font_size", 13)
		_content_vbox.add_child(compare_label)

		var yest_rev = yesterday.get_total_revenue()
		var yest_profit = yesterday.get_profit()

		var yest_rev_row = _create_stat_row("  Revenue:", "$%d" % yest_rev, dim_color)
		_content_vbox.add_child(yest_rev_row)

		var yest_profit_color = UIConstants.COLOR_SUCCESS_MUTED if yest_profit >= 0 else UIConstants.COLOR_DANGER_MUTED
		var yest_profit_text = "+$%d" % yest_profit if yest_profit >= 0 else "-$%d" % abs(yest_profit)
		var yest_profit_row = _create_stat_row("  Profit:", yest_profit_text, yest_profit_color)
		_content_vbox.add_child(yest_profit_row)

		# Show trend
		var trend_diff = profit - yest_profit
		var trend_text = ""
		var trend_color = UIConstants.COLOR_TEXT_DIM
		if trend_diff > 0:
			trend_text = "+$%d vs yesterday" % trend_diff
			trend_color = UIConstants.COLOR_SUCCESS
		elif trend_diff < 0:
			trend_text = "-$%d vs yesterday" % abs(trend_diff)
			trend_color = UIConstants.COLOR_DANGER
		else:
			trend_text = "Same as yesterday"

		var trend_row = _create_stat_row("Trend:", trend_text, trend_color)
		_content_vbox.add_child(trend_row)

	_content_vbox.add_child(HSeparator.new())

	# Reputation
	var rep_label = Label.new()
	rep_label.text = "Course Status"
	rep_label.add_theme_font_size_override("font_size", 13)
	_content_vbox.add_child(rep_label)

	var reputation = GameManager.reputation
	var rep_color = UIConstants.COLOR_SUCCESS if reputation >= 70 else (UIConstants.COLOR_WARNING if reputation >= 40 else UIConstants.COLOR_DANGER)
	var rep_row = _create_stat_row("Reputation:", "%.0f%%" % reputation, rep_color)
	_content_vbox.add_child(rep_row)

	var golfers_row = _create_stat_row("Golfers Today:", "%d" % stats.golfers_served, Color.WHITE)
	_content_vbox.add_child(golfers_row)

	# Loan Section
	_content_vbox.add_child(HSeparator.new())

	var loan_label = Label.new()
	loan_label.text = "Loans"
	loan_label.add_theme_font_size_override("font_size", 13)
	_content_vbox.add_child(loan_label)

	var loan_color = UIConstants.COLOR_DANGER_DIM if GameManager.loan_balance > 0 else UIConstants.COLOR_TEXT_DIM
	var loan_row = _create_stat_row("Outstanding:", "$%d" % GameManager.loan_balance, loan_color)
	_content_vbox.add_child(loan_row)

	if GameManager.loan_balance > 0:
		var interest_row = _create_stat_row("Interest:", "5%% / 7 days", UIConstants.COLOR_TEXT_DIM)
		_content_vbox.add_child(interest_row)

	var loan_btn_row = HBoxContainer.new()
	loan_btn_row.add_theme_constant_override("separation", 8)
	_content_vbox.add_child(loan_btn_row)

	var borrow_btn = Button.new()
	borrow_btn.text = "Borrow $10k"
	borrow_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	borrow_btn.disabled = GameManager.loan_balance >= GameManager.MAX_LOAN
	borrow_btn.pressed.connect(func():
		GameManager.take_loan(10000)
		update_display()
	)
	loan_btn_row.add_child(borrow_btn)

	var repay_btn = Button.new()
	repay_btn.text = "Repay $10k"
	repay_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	repay_btn.disabled = GameManager.loan_balance <= 0
	repay_btn.pressed.connect(func():
		GameManager.repay_loan(10000)
		update_display()
	)
	loan_btn_row.add_child(repay_btn)

	# Seasonal Forecast
	_content_vbox.add_child(HSeparator.new())

	var season_label = Label.new()
	season_label.text = "Seasonal Forecast"
	season_label.add_theme_font_size_override("font_size", 13)
	_content_vbox.add_child(season_label)

	var season = SeasonSystem.get_season(GameManager.current_day)
	var season_name = SeasonSystem.get_season_name(season)
	var season_color = SeasonSystem.get_season_color(season)
	var season_row = _create_stat_row("Season:", season_name, season_color)
	_content_vbox.add_child(season_row)

	var spawn_mod = SeasonSystem.get_spawn_modifier(season)
	var spawn_pct = int(spawn_mod * 100)
	var spawn_color = UIConstants.COLOR_SUCCESS if spawn_mod >= 1.0 else (UIConstants.COLOR_WARNING if spawn_mod >= 0.7 else UIConstants.COLOR_DANGER_DIM)
	var demand_row = _create_stat_row("Demand:", "%d%%" % spawn_pct, spawn_color)
	_content_vbox.add_child(demand_row)

	var maint_mod = SeasonSystem.get_maintenance_modifier(season)
	var maint_pct = int(maint_mod * 100)
	var maint_color = UIConstants.COLOR_SUCCESS if maint_mod <= 1.0 else (UIConstants.COLOR_WARNING if maint_mod <= 1.2 else UIConstants.COLOR_DANGER_DIM)
	var maint_row = _create_stat_row("Maintenance:", "%d%%" % maint_pct, maint_color)
	_content_vbox.add_child(maint_row)

	# Course Ratings (Official Handicap/Slope)
	var rating = GameManager.course_rating
	if rating and rating.has("slope"):
		_content_vbox.add_child(HSeparator.new())

		var rating_label = Label.new()
		rating_label.text = "Official Ratings"
		rating_label.add_theme_font_size_override("font_size", 13)
		_content_vbox.add_child(rating_label)

		# Hole count for context
		var hole_count = 0
		if GameManager.current_course:
			for hole in GameManager.current_course.holes:
				if hole.is_open:
					hole_count += 1
		var holes_row = _create_stat_row("Holes:", "%d" % hole_count, Color.WHITE)
		_content_vbox.add_child(holes_row)

		# Slope Rating (55-155)
		var slope = rating.get("slope", 113)
		var slope_color = UIConstants.COLOR_INFO_DIM
		if slope >= 130:
			slope_color = UIConstants.COLOR_ORANGE
		elif slope <= 90:
			slope_color = UIConstants.COLOR_SUCCESS_DIM
		var slope_text = "%d (%s)" % [slope, CourseRatingSystem.get_slope_text(slope)]
		var slope_row = _create_stat_row("Slope:", slope_text, slope_color)
		_content_vbox.add_child(slope_row)

		# Course Rating (expected scratch golfer score, scales by holes)
		var course_rtg = rating.get("course_rating", 72.0)
		var cr_row = _create_stat_row("Course Rating:", "%.1f" % course_rtg, Color.WHITE)
		_content_vbox.add_child(cr_row)

		# Difficulty
		var difficulty = rating.get("difficulty", 5.0)
		var diff_color = UIConstants.COLOR_SUCCESS_DIM
		if difficulty >= 7.0:
			diff_color = UIConstants.COLOR_DANGER_DIM
		elif difficulty >= 5.0:
			diff_color = UIConstants.COLOR_WARNING
		var diff_text = "%.1f (%s)" % [difficulty, CourseRatingSystem.get_difficulty_text(difficulty)]
		var diff_row = _create_stat_row("Difficulty:", diff_text, diff_color)
		_content_vbox.add_child(diff_row)

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
		show_centered()
