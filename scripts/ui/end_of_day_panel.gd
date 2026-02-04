extends CenterContainer
class_name EndOfDaySummaryPanel
## EndOfDaySummaryPanel - Shows daily statistics at end of day

signal continue_pressed

var _day_number: int = 0
var _summary: Dictionary = {}

func setup(day_number: int, summary: Dictionary) -> void:
	_day_number = day_number
	_summary = summary

func _ready() -> void:
	# Block input to nodes behind us
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()

func _build_ui() -> void:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 380)
	add_child(panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "Day %d Summary" % _day_number
	title.add_theme_font_size_override("font_size", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	# Revenue
	var revenue = _summary.get("revenue", 0)
	_add_stat_row(vbox, "Revenue:", "+$%d" % revenue, Color(0.3, 0.85, 0.3))

	# Expenses
	var expenses = _summary.get("expenses", 0)
	_add_stat_row(vbox, "Expenses:", "-$%d" % expenses, Color(0.85, 0.3, 0.3))

	# Profit
	var profit = _summary.get("profit", 0)
	var profit_color = Color(0.3, 0.85, 0.3) if profit >= 0 else Color(0.85, 0.3, 0.3)
	var profit_text = "+$%d" % profit if profit >= 0 else "-$%d" % abs(profit)
	_add_stat_row(vbox, "Net Profit:", profit_text, profit_color)

	vbox.add_child(HSeparator.new())

	# Golfers served
	_add_stat_row(vbox, "Golfers Served:", "%d" % _summary.get("golfers_served", 0), Color.WHITE)

	# Average pace
	var pace = _summary.get("average_pace_of_play", 0.0)
	if pace > 0.0:
		_add_stat_row(vbox, "Avg Pace:", "%.1f hrs/round" % pace, Color.WHITE)

	# Average score
	var avg_score = _summary.get("average_score_vs_par", 0.0)
	if _summary.get("golfers_served", 0) > 0:
		var score_text = "%+.1f vs par" % avg_score
		_add_stat_row(vbox, "Avg Score:", score_text, Color.WHITE)

	# Notable scores
	var notables: Array = _summary.get("notable_scores", [])
	if not notables.is_empty():
		vbox.add_child(HSeparator.new())
		var notable_label = Label.new()
		notable_label.text = "Notable Scores:"
		notable_label.add_theme_font_size_override("font_size", 14)
		vbox.add_child(notable_label)

		var shown = mini(notables.size(), 5)
		for i in range(shown):
			var n = notables[i]
			var line = Label.new()
			line.text = "  Hole %d: %s (%d strokes)" % [
				n.get("hole_number", 0),
				n.get("score_name", ""),
				n.get("strokes", 0),
			]
			line.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
			vbox.add_child(line)
	else:
		vbox.add_child(HSeparator.new())
		var none_label = Label.new()
		none_label.text = "No notable scores today."
		none_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		vbox.add_child(none_label)

	# Continue button
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer)

	var continue_btn = Button.new()
	continue_btn.text = "Continue to Day %d" % (_day_number + 1)
	continue_btn.custom_minimum_size = Vector2(0, 36)
	continue_btn.pressed.connect(_on_continue_pressed)
	vbox.add_child(continue_btn)

func _add_stat_row(parent: VBoxContainer, label_text: String, value_text: String, value_color: Color) -> void:
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

	parent.add_child(row)

func _on_continue_pressed() -> void:
	continue_pressed.emit()
	queue_free()
