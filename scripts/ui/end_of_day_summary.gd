extends PanelContainer
class_name EndOfDaySummaryPanel
## EndOfDaySummaryPanel - Shows daily statistics at end of each day

signal continue_pressed

var _day_number: int = 1

func _init(day_number: int = 1) -> void:
	_day_number = day_number

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	custom_minimum_size = Vector2(380, 720)  # Extra height for tier breakdown and feedback

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "Day %d Complete" % _day_number
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	# Stats container
	var stats = GameManager.daily_stats

	# Revenue section
	var revenue_row = _create_stat_row("Revenue:", "$%d" % stats.revenue, Color(0.4, 0.9, 0.4))
	vbox.add_child(revenue_row)

	# Operating costs breakdown
	var costs_label = Label.new()
	costs_label.text = "Operating Costs:"
	costs_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(costs_label)

	# Show breakdown with indentation
	var dim_color = Color(0.7, 0.7, 0.7)
	if stats.terrain_maintenance > 0:
		var terrain_row = _create_stat_row("  Terrain:", "-$%d" % stats.terrain_maintenance, dim_color)
		vbox.add_child(terrain_row)
	if stats.base_operating_cost > 0:
		var base_row = _create_stat_row("  Base:", "-$%d" % stats.base_operating_cost, dim_color)
		vbox.add_child(base_row)
	if stats.staff_wages > 0:
		var staff_row = _create_stat_row("  Staff:", "-$%d" % stats.staff_wages, dim_color)
		vbox.add_child(staff_row)

	var total_costs_row = _create_stat_row("Total Costs:", "-$%d" % stats.operating_costs, Color(0.9, 0.5, 0.5))
	vbox.add_child(total_costs_row)

	# Profit/Loss
	var profit = stats.get_profit()
	var profit_color = Color(0.4, 0.9, 0.4) if profit >= 0 else Color(0.9, 0.4, 0.4)
	var profit_text = "+$%d" % profit if profit >= 0 else "-$%d" % abs(profit)
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

	var star_color = Color(0.9, 0.9, 0.4)  # Yellow/gold for stars
	if stars >= 4:
		star_color = Color(0.4, 0.9, 0.4)  # Green for good rating
	elif stars <= 2:
		star_color = Color(0.9, 0.4, 0.4)  # Red for poor rating

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

	vbox.add_child(HSeparator.new())

	# Golfers served
	var golfers_row = _create_stat_row("Golfers Served:", "%d" % stats.golfers_served)
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
			var row = _create_stat_row("  Serious:", "%d" % serious, Color(0.4, 0.7, 1.0))
			vbox.add_child(row)
		if pros > 0:
			var row = _create_stat_row("  Pro:", "%d" % pros, Color(1.0, 0.85, 0.0))
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
		var hio = _create_notable_badge("Hole-in-One", stats.holes_in_one, Color(1.0, 0.85, 0.0))
		notable_container.add_child(hio)

	# Eagles (gold-ish)
	if stats.eagles > 0:
		var eagle = _create_notable_badge("Eagle", stats.eagles, Color(0.9, 0.75, 0.2))
		notable_container.add_child(eagle)

	# Birdies (blue)
	if stats.birdies > 0:
		var birdie = _create_notable_badge("Birdie", stats.birdies, Color(0.4, 0.7, 1.0))
		notable_container.add_child(birdie)

	# If no notable scores
	if stats.holes_in_one == 0 and stats.eagles == 0 and stats.birdies == 0:
		var none_label = Label.new()
		none_label.text = "None today"
		none_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
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
		sat_color = Color(0.4, 0.9, 0.4)  # Green
	elif satisfaction_pct >= 40:
		sat_color = Color(0.9, 0.9, 0.4)  # Yellow
	else:
		sat_color = Color(0.9, 0.4, 0.4)  # Red

	var sat_row = _create_stat_row("Satisfaction:", "%d%%" % satisfaction_pct, sat_color)
	vbox.add_child(sat_row)

	# Show top feedback if available
	var top_compliment = feedback_summary["top_compliment"]
	var top_complaint = feedback_summary["top_complaint"]

	if top_compliment != "":
		var compliment_row = _create_stat_row("Top praise:", "\"%s\"" % top_compliment, Color(0.6, 0.8, 0.6))
		vbox.add_child(compliment_row)

	if top_complaint != "":
		var complaint_row = _create_stat_row("Top concern:", "\"%s\"" % top_complaint, Color(0.8, 0.6, 0.6))
		vbox.add_child(complaint_row)

	if top_compliment == "" and top_complaint == "" and feedback_summary["total_count"] == 0:
		var no_feedback = Label.new()
		no_feedback.text = "No feedback recorded"
		no_feedback.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		no_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(no_feedback)

	# Spacer
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# Continue button
	var continue_btn = Button.new()
	continue_btn.text = "Continue to Day %d" % (_day_number + 1)
	continue_btn.custom_minimum_size = Vector2(200, 40)
	continue_btn.pressed.connect(_on_continue_pressed)
	vbox.add_child(continue_btn)

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
