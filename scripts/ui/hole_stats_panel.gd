extends PanelContainer
class_name HoleStatsPanel
## HoleStatsPanel - Shows detailed statistics for a selected hole

signal close_requested
signal hole_selected(hole_number: int)

var _hole_data = null  # GameManager.HoleData
var _content_vbox: VBoxContainer = null
var _title_label: Label = null

func _ready() -> void:
	_build_ui()
	hide()

func _build_ui() -> void:
	custom_minimum_size = Vector2(300, 420)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	margin.add_child(main_vbox)

	# Title row with close button
	var title_row = HBoxContainer.new()
	main_vbox.add_child(title_row)

	_title_label = Label.new()
	_title_label.text = "Hole Statistics"
	_title_label.add_theme_font_size_override("font_size", 18)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(_title_label)

	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(30, 30)
	close_btn.pressed.connect(_on_close_pressed)
	title_row.add_child(close_btn)

	main_vbox.add_child(HSeparator.new())

	# Scrollable content area
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 340)
	main_vbox.add_child(scroll)

	_content_vbox = VBoxContainer.new()
	_content_vbox.add_theme_constant_override("separation", 6)
	_content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_content_vbox)

func show_for_hole(hole_data) -> void:
	_hole_data = hole_data
	_update_display()
	show()
	hole_selected.emit(hole_data.hole_number)

func _update_display() -> void:
	# Clear existing content
	for child in _content_vbox.get_children():
		child.queue_free()

	if not _hole_data:
		return

	var hole_num = _hole_data.hole_number
	var par = _hole_data.par
	var yardage = _hole_data.distance_yards
	var difficulty = _hole_data.difficulty_rating

	# Update title
	_title_label.text = "Hole %d Statistics" % hole_num

	# Basic hole info
	var info_label = Label.new()
	info_label.text = "Hole Information"
	info_label.add_theme_font_size_override("font_size", 14)
	_content_vbox.add_child(info_label)

	var par_row = _create_stat_row("Par:", str(par), Color.WHITE)
	_content_vbox.add_child(par_row)

	var yard_row = _create_stat_row("Distance:", "%d yards" % yardage, Color.WHITE)
	_content_vbox.add_child(yard_row)

	# Difficulty with color coding
	var diff_color = Color(0.4, 0.9, 0.4)  # Green for easy
	if difficulty >= 7:
		diff_color = Color(0.9, 0.4, 0.4)  # Red for hard
	elif difficulty >= 4:
		diff_color = Color(0.9, 0.9, 0.4)  # Yellow for medium

	var diff_row = _create_stat_row("Difficulty:", "%.1f / 10" % difficulty, diff_color)
	_content_vbox.add_child(diff_row)

	_content_vbox.add_child(HSeparator.new())

	# Get hole statistics
	var stats = GameManager.get_hole_statistics(hole_num)

	if stats and stats.total_rounds > 0:
		# Scoring section
		var scoring_label = Label.new()
		scoring_label.text = "Scoring Statistics"
		scoring_label.add_theme_font_size_override("font_size", 14)
		_content_vbox.add_child(scoring_label)

		var rounds_row = _create_stat_row("Rounds Played:", str(stats.total_rounds), Color.WHITE)
		_content_vbox.add_child(rounds_row)

		# Average score
		var avg_score = stats.get_average_score()
		var avg_to_par = stats.get_average_to_par(par)
		var avg_color = Color(0.4, 0.9, 0.4) if avg_to_par <= 0 else Color(0.9, 0.9, 0.4)
		if avg_to_par > 0.5:
			avg_color = Color(0.9, 0.4, 0.4)

		var avg_text = "%.2f" % avg_score
		if avg_to_par != 0:
			var sign = "+" if avg_to_par > 0 else ""
			avg_text += " (%s%.2f)" % [sign, avg_to_par]
		var avg_row = _create_stat_row("Average Score:", avg_text, avg_color)
		_content_vbox.add_child(avg_row)

		# Best score
		if stats.best_score > 0:
			var best_color = Color(1.0, 0.85, 0.0) if stats.best_score == 1 else Color(0.4, 0.8, 1.0)
			var best_row = _create_stat_row("Best Score:", str(stats.best_score), best_color)
			_content_vbox.add_child(best_row)

		_content_vbox.add_child(HSeparator.new())

		# Score distribution
		var dist_label = Label.new()
		dist_label.text = "Score Distribution"
		dist_label.add_theme_font_size_override("font_size", 14)
		_content_vbox.add_child(dist_label)

		var dim_color = Color(0.7, 0.7, 0.7)

		if stats.holes_in_one > 0:
			var hio_row = _create_stat_row("  Holes-in-One:", str(stats.holes_in_one), Color(1.0, 0.85, 0.0))
			_content_vbox.add_child(hio_row)

		if stats.eagles > 0:
			var eagle_row = _create_stat_row("  Eagles:", str(stats.eagles), Color(0.9, 0.75, 0.2))
			_content_vbox.add_child(eagle_row)

		if stats.birdies > 0:
			var birdie_row = _create_stat_row("  Birdies:", str(stats.birdies), Color(0.4, 0.7, 1.0))
			_content_vbox.add_child(birdie_row)

		var par_row2 = _create_stat_row("  Pars:", str(stats.pars), dim_color)
		_content_vbox.add_child(par_row2)

		if stats.bogeys > 0:
			var bogey_row = _create_stat_row("  Bogeys:", str(stats.bogeys), Color(0.8, 0.6, 0.4))
			_content_vbox.add_child(bogey_row)

		if stats.double_bogeys_plus > 0:
			var dbl_row = _create_stat_row("  Double+:", str(stats.double_bogeys_plus), Color(0.9, 0.4, 0.4))
			_content_vbox.add_child(dbl_row)
	else:
		# No data yet
		var no_data = Label.new()
		no_data.text = "No rounds played yet"
		no_data.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		no_data.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_content_vbox.add_child(no_data)

func _create_stat_row(label_text: String, value_text: String, value_color: Color) -> HBoxContainer:
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
