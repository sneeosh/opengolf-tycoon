extends CenteredPanel
class_name BuildingInfoPanel
## BuildingInfoPanel - Shows building info and upgrade options when clicked

signal upgrade_requested(building: Building)
signal close_requested

var _building: Building = null
var _vbox: VBoxContainer = null
var _upgrade_btn: Button = null

func _build_ui() -> void:
	custom_minimum_size = Vector2(280, 200)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 6)
	margin.add_child(_vbox)

func show_for_building(building: Building) -> void:
	_building = building
	_update_display()
	show_centered()

func _update_display() -> void:
	# Clear existing content
	for child in _vbox.get_children():
		child.queue_free()

	if not _building:
		return

	# Title
	var title = Label.new()
	title.text = _building.get_display_name()
	title.add_theme_font_size_override("font_size", 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vbox.add_child(title)

	_vbox.add_child(HSeparator.new())

	# Current stats
	var income = _building.get_income_per_golfer()
	if income > 0:
		var income_row = _create_stat_row("Income:", "$%d per golfer" % income, Color(0.4, 0.9, 0.4))
		_vbox.add_child(income_row)

	var satisfaction = _building.get_satisfaction_bonus()
	if satisfaction > 0:
		var sat_row = _create_stat_row("Satisfaction:", "+%d%%" % int(satisfaction * 100), Color(0.4, 0.8, 1.0))
		_vbox.add_child(sat_row)

	# Level indicator
	if _building.building_data.get("upgradeable", false):
		var level_row = _create_stat_row("Level:", "%d / 3" % _building.upgrade_level, Color.WHITE)
		_vbox.add_child(level_row)

	_vbox.add_child(HSeparator.new())

	# Upgrade section
	if _building.can_upgrade():
		var next_upgrade = _building.get_next_upgrade_data()
		var upgrade_cost = _building.get_upgrade_cost()

		var upgrade_label = Label.new()
		upgrade_label.text = "Next Upgrade:"
		upgrade_label.add_theme_font_size_override("font_size", 14)
		_vbox.add_child(upgrade_label)

		var next_name = next_upgrade.get("name", "Level %d" % (_building.upgrade_level + 1))
		var name_label = Label.new()
		name_label.text = next_name
		name_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		_vbox.add_child(name_label)

		# Show what the upgrade adds
		var next_income = next_upgrade.get("income_per_golfer", 0)
		if next_income > 0:
			var preview = Label.new()
			preview.text = "  +$%d per golfer" % next_income
			preview.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
			preview.add_theme_font_size_override("font_size", 12)
			_vbox.add_child(preview)

		var next_sat = next_upgrade.get("satisfaction_bonus", 0.0)
		if next_sat > 0:
			var preview = Label.new()
			preview.text = "  +%d%% satisfaction" % int(next_sat * 100)
			preview.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
			preview.add_theme_font_size_override("font_size", 12)
			_vbox.add_child(preview)

		# Upgrade button
		_upgrade_btn = Button.new()
		_upgrade_btn.text = "Upgrade - $%d" % upgrade_cost

		var can_afford = GameManager.money >= upgrade_cost
		if not can_afford:
			_upgrade_btn.disabled = true
			_upgrade_btn.text += " (Need $%d more)" % (upgrade_cost - GameManager.money)

		_upgrade_btn.pressed.connect(_on_upgrade_pressed)
		_vbox.add_child(_upgrade_btn)
	else:
		var max_label = Label.new()
		max_label.text = "Max Level Reached"
		max_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
		max_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_vbox.add_child(max_label)

	# Close button
	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(_on_close_pressed)
	_vbox.add_child(close_btn)

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

func _on_upgrade_pressed() -> void:
	if _building and _building.upgrade():
		upgrade_requested.emit(_building)
		_update_display()

func _on_close_pressed() -> void:
	close_requested.emit()
	hide()
