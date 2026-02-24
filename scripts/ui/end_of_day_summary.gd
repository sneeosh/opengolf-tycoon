extends CenteredPanel
class_name EndOfDaySummaryPanel
## EndOfDaySummaryPanel - Shows daily statistics at end of each day

signal continue_pressed
signal build_mode_pressed

var _day_number: int = 1

func _init(day_number: int = 1) -> void:
	_day_number = day_number

func _ready() -> void:
	super._ready()
	# Show centered immediately (this panel auto-shows on creation)
	show_centered()

func _build_ui() -> void:
	# Get viewport height to set appropriate panel size
	var viewport_height = 800  # Default fallback
	if get_viewport():
		viewport_height = get_viewport().get_visible_rect().size.y
	var panel_height = min(680, viewport_height - 100)  # Leave margin from screen edges
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

	# Title (fixed at top)
	var title = Label.new()
	title.text = "Day %d Complete" % _day_number
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(title)

	main_vbox.add_child(HSeparator.new())

	# Scrollable content area
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# Stats container
	var stats = GameManager.daily_stats

	# Revenue section
	var revenue_label = Label.new()
	revenue_label.text = "Revenue:"
	revenue_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(revenue_label)

	# Show green fees
	var dim_green = UIConstants.COLOR_SUCCESS_DIM
	var greenfee_row = _create_stat_row("  Green Fees:", "$%d" % stats.revenue, dim_green)
	vbox.add_child(greenfee_row)

	# Show building revenue if any
	if stats.building_revenue > 0:
		var building_row = _create_stat_row("  Amenities:", "$%d" % stats.building_revenue, dim_green)
		vbox.add_child(building_row)

	# Show tournament revenue if any
	if stats.tournament_revenue > 0:
		var tourn_rev_row = _create_stat_row("  Tournament:", "$%d" % stats.tournament_revenue, dim_green)
		vbox.add_child(tourn_rev_row)

	# Total revenue with trend
	var total_rev = stats.get_total_revenue()
	var rev_text = "$%d" % total_rev
	var yesterday = GameManager.yesterday_stats
	if yesterday:
		var yest_rev = yesterday.get_total_revenue()
		rev_text += " %s" % _trend_arrow(total_rev, yest_rev)
	var total_rev_row = _create_stat_row("Total Revenue:", rev_text, UIConstants.COLOR_SUCCESS)
	vbox.add_child(total_rev_row)

	# Operating costs breakdown
	var costs_label = Label.new()
	costs_label.text = "Operating Costs:"
	costs_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(costs_label)

	# Show breakdown with indentation
	var dim_color = UIConstants.COLOR_TEXT_DIM
	if stats.terrain_maintenance > 0:
		var terrain_row = _create_stat_row("  Terrain:", "-$%d" % stats.terrain_maintenance, dim_color)
		vbox.add_child(terrain_row)
	if stats.base_operating_cost > 0:
		var base_row = _create_stat_row("  Base:", "-$%d" % stats.base_operating_cost, dim_color)
		vbox.add_child(base_row)
	if stats.staff_wages > 0:
		var staff_row = _create_stat_row("  Staff:", "-$%d" % stats.staff_wages, dim_color)
		vbox.add_child(staff_row)
	if stats.building_operating_costs > 0:
		var building_row = _create_stat_row("  Buildings:", "-$%d" % stats.building_operating_costs, dim_color)
		vbox.add_child(building_row)
	if stats.tournament_entry_fee > 0:
		var tourn_fee_row = _create_stat_row("  Tournament Fee:", "-$%d" % stats.tournament_entry_fee, dim_color)
		vbox.add_child(tourn_fee_row)

	var total_costs = stats.operating_costs + stats.tournament_entry_fee
	var total_costs_row = _create_stat_row("Total Costs:", "-$%d" % total_costs, UIConstants.COLOR_DANGER_DIM)
	vbox.add_child(total_costs_row)

	# Profit/Loss with trend
	var profit = stats.get_profit()
	var profit_color = UIConstants.COLOR_SUCCESS if profit >= 0 else UIConstants.COLOR_DANGER
	var profit_text = "+$%d" % profit if profit >= 0 else "-$%d" % abs(profit)
	if yesterday:
		var yest_profit = yesterday.get_profit()
		profit_text += " %s" % _trend_arrow(profit, yest_profit)
	var profit_row = _create_stat_row("Daily Profit:", profit_text, profit_color)
	vbox.add_child(profit_row)

	vbox.add_child(HSeparator.new())

	# Course Rating section
	var rating = GameManager.course_rating
	var rating_label = Label.new()
	rating_label.text = "Course Rating"
	rating_label.add_theme_font_size_override("font_size", 16)
	rating_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(rating_label)

	# Star display
	var stars = rating.get("stars", 3)
	var overall = rating.get("overall", 3.0)
	var star_text = ""
	for i in range(stars):
		star_text += "*"
	for i in range(5 - stars):
		star_text += "-"
	star_text += " (%.1f)" % overall

	var star_color = UIConstants.COLOR_WARNING
	if stars >= 4:
		star_color = UIConstants.COLOR_SUCCESS
	elif stars <= 2:
		star_color = UIConstants.COLOR_DANGER

	var star_row = _create_stat_row("Overall:", star_text, star_color)
	vbox.add_child(star_row)

	# Show individual ratings in smaller text
	var cond_row = _create_stat_row("  Condition:", "%.1f" % rating.get("condition", 3.0), dim_color)
	var design_row = _create_stat_row("  Design:", "%.1f" % rating.get("design", 3.0), dim_color)
	var value_row = _create_stat_row("  Value:", "%.1f" % rating.get("value", 3.0), dim_color)
	var pace_row = _create_stat_row("  Pace:", "%.1f" % rating.get("pace", 3.0), dim_color)
	vbox.add_child(cond_row)
	vbox.add_child(design_row)
	vbox.add_child(value_row)
	vbox.add_child(pace_row)

	# Course Difficulty section
	var difficulty = rating.get("difficulty", 5.0)
	var slope = rating.get("slope", 113)
	var course_rtg = rating.get("course_rating", 72.0)

	# Difficulty with color coding
	var diff_color = UIConstants.COLOR_SUCCESS
	if difficulty >= 7.0:
		diff_color = UIConstants.COLOR_DANGER
	elif difficulty >= 5.0:
		diff_color = UIConstants.COLOR_WARNING

	var diff_text = "%.1f (%s)" % [difficulty, CourseRatingSystem.get_difficulty_text(difficulty)]
	var diff_row = _create_stat_row("Difficulty:", diff_text, diff_color)
	vbox.add_child(diff_row)

	# Slope rating
	var slope_color = UIConstants.COLOR_INFO_DIM
	if slope >= 130:
		slope_color = UIConstants.COLOR_ORANGE
	var slope_row = _create_stat_row("Slope Rating:", "%d" % slope, slope_color)
	vbox.add_child(slope_row)

	# Course rating (expected score)
	var cr_row = _create_stat_row("Course Rating:", "%.1f" % course_rtg, dim_color)
	vbox.add_child(cr_row)

	vbox.add_child(HSeparator.new())

	# Golfers served with trend
	var golfers_text = "%d" % stats.golfers_served
	if yesterday:
		golfers_text += " %s" % _trend_arrow(stats.golfers_served, yesterday.golfers_served)
	var golfers_row = _create_stat_row("Golfers Served:", golfers_text)
	vbox.add_child(golfers_row)

	# Golfer tier breakdown
	if stats.golfers_served > 0:
		var beginners = stats.tier_counts.get(GolferTier.Tier.BEGINNER, 0)
		var casuals = stats.tier_counts.get(GolferTier.Tier.CASUAL, 0)
		var serious = stats.tier_counts.get(GolferTier.Tier.SERIOUS, 0)
		var pros = stats.tier_counts.get(GolferTier.Tier.PRO, 0)

		if beginners > 0:
			var row = _create_stat_row("  Beginners:", "%d" % beginners, dim_color)
			vbox.add_child(row)
		if casuals > 0:
			var row = _create_stat_row("  Casual:", "%d" % casuals, dim_color)
			vbox.add_child(row)
		if serious > 0:
			var row = _create_stat_row("  Serious:", "%d" % serious, UIConstants.COLOR_INFO)
			vbox.add_child(row)
		if pros > 0:
			var row = _create_stat_row("  Pro:", "%d" % pros, UIConstants.COLOR_GOLD)
			vbox.add_child(row)

	# Average score (if any golfers played)
	if stats.golfers_served > 0:
		var avg_score = stats.get_average_score_to_par()
		var avg_text = ""
		if avg_score == 0:
			avg_text = "Even"
		elif avg_score > 0:
			avg_text = "+%.1f" % avg_score
		else:
			avg_text = "%.1f" % avg_score
		var avg_row = _create_stat_row("Avg Score:", avg_text)
		vbox.add_child(avg_row)

	vbox.add_child(HSeparator.new())

	# Notable scores section
	var notable_label = Label.new()
	notable_label.text = "Notable Scores"
	notable_label.add_theme_font_size_override("font_size", 16)
	notable_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(notable_label)

	var notable_container = HBoxContainer.new()
	notable_container.alignment = BoxContainer.ALIGNMENT_CENTER
	notable_container.add_theme_constant_override("separation", 20)
	vbox.add_child(notable_container)

	# Hole in ones (gold)
	if stats.holes_in_one > 0:
		var hio = _create_notable_badge("Hole-in-One", stats.holes_in_one, UIConstants.COLOR_GOLD)
		notable_container.add_child(hio)

	# Eagles (gold-ish)
	if stats.eagles > 0:
		var eagle = _create_notable_badge("Eagle", stats.eagles, UIConstants.COLOR_GOLD_DIM)
		notable_container.add_child(eagle)

	# Birdies (blue)
	if stats.birdies > 0:
		var birdie = _create_notable_badge("Birdie", stats.birdies, UIConstants.COLOR_INFO)
		notable_container.add_child(birdie)

	# If no notable scores
	if stats.holes_in_one == 0 and stats.eagles == 0 and stats.birdies == 0:
		var none_label = Label.new()
		none_label.text = "None today"
		none_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_MUTED)
		notable_container.add_child(none_label)

	vbox.add_child(HSeparator.new())

	# Golfer Satisfaction section
	var satisfaction_label = Label.new()
	satisfaction_label.text = "Golfer Satisfaction"
	satisfaction_label.add_theme_font_size_override("font_size", 16)
	satisfaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(satisfaction_label)

	var feedback_summary = FeedbackManager.get_daily_summary()
	var satisfaction_pct = int(feedback_summary["satisfaction"] * 100)

	# Determine satisfaction color
	var sat_color: Color
	if satisfaction_pct >= 70:
		sat_color = UIConstants.COLOR_SUCCESS
	elif satisfaction_pct >= 40:
		sat_color = UIConstants.COLOR_WARNING
	else:
		sat_color = UIConstants.COLOR_DANGER

	var sat_row = _create_stat_row("Satisfaction:", "%d%%" % satisfaction_pct, sat_color)
	vbox.add_child(sat_row)

	# Show top feedback if available
	var top_compliment = feedback_summary["top_compliment"]
	var top_complaint = feedback_summary["top_complaint"]

	if top_compliment != "":
		var compliment_row = _create_stat_row("Top praise:", "\"%s\"" % top_compliment, UIConstants.COLOR_SUCCESS_MUTED)
		vbox.add_child(compliment_row)

	if top_complaint != "":
		var complaint_row = _create_stat_row("Top concern:", "\"%s\"" % top_complaint, UIConstants.COLOR_DANGER_MUTED)
		vbox.add_child(complaint_row)

	if top_compliment == "" and top_complaint == "" and feedback_summary["total_count"] == 0:
		var no_feedback = Label.new()
		no_feedback.text = "No feedback recorded"
		no_feedback.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_MUTED)
		no_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(no_feedback)

	# Action buttons (fixed at bottom, outside scroll area)
	main_vbox.add_child(HSeparator.new())

	var btn_row = VBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 6)
	main_vbox.add_child(btn_row)

	var continue_btn = Button.new()
	continue_btn.text = "Continue to Day %d" % (_day_number + 1)
	continue_btn.custom_minimum_size = Vector2(200, 38)
	continue_btn.pressed.connect(_on_continue_pressed)
	btn_row.add_child(continue_btn)

	var build_btn = Button.new()
	build_btn.text = "Return to Build Mode"
	build_btn.custom_minimum_size = Vector2(200, 38)
	build_btn.pressed.connect(_on_build_mode_pressed)
	btn_row.add_child(build_btn)

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

func _create_notable_badge(label_text: String, count: int, color: Color) -> VBoxContainer:
	var badge = VBoxContainer.new()
	badge.alignment = BoxContainer.ALIGNMENT_CENTER

	var count_label = Label.new()
	count_label.text = str(count)
	count_label.add_theme_font_size_override("font_size", 20)
	count_label.add_theme_color_override("font_color", color)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_child(count_label)

	var name_label = Label.new()
	name_label.text = label_text
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_child(name_label)

	return badge

func _on_continue_pressed() -> void:
	continue_pressed.emit()
	queue_free()

func _on_build_mode_pressed() -> void:
	build_mode_pressed.emit()
	queue_free()

static func _trend_arrow(current: float, previous: float) -> String:
	if current > previous:
		return "^"
	elif current < previous:
		return "v"
	return "="
