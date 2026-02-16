extends CenteredPanel
class_name StaffPanel
## StaffPanel - UI for hiring/firing staff and monitoring course condition
##
## Displays course condition, payroll, hire buttons for 4 staff types,
## and a roster of hired staff with fire buttons.

signal close_requested

var _condition_bar: ProgressBar = null
var _condition_label: Label = null
var _payroll_label: Label = null
var _staff_list_container: VBoxContainer = null
var _modifiers_label: Label = null

func _build_ui() -> void:
	custom_minimum_size = Vector2(320, 450)

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

	var title = Label.new()
	title.text = "Staff Management"
	title.add_theme_font_size_override("font_size", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(30, 30)
	close_btn.pressed.connect(_on_close_pressed)
	title_row.add_child(close_btn)

	main_vbox.add_child(HSeparator.new())

	# Condition section
	var condition_row = HBoxContainer.new()
	main_vbox.add_child(condition_row)

	var condition_text = Label.new()
	condition_text.text = "Condition:"
	condition_row.add_child(condition_text)

	_condition_bar = ProgressBar.new()
	_condition_bar.min_value = 0
	_condition_bar.max_value = 100
	_condition_bar.value = 100
	_condition_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_condition_bar.custom_minimum_size = Vector2(120, 20)
	_condition_bar.show_percentage = false
	condition_row.add_child(_condition_bar)

	_condition_label = Label.new()
	_condition_label.text = "100% (Pristine)"
	_condition_label.custom_minimum_size = Vector2(100, 0)
	_condition_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	condition_row.add_child(_condition_label)

	# Payroll row
	_payroll_label = Label.new()
	_payroll_label.text = "Daily Payroll: $0"
	main_vbox.add_child(_payroll_label)

	main_vbox.add_child(HSeparator.new())

	# Hire section
	var hire_label = Label.new()
	hire_label.text = "HIRE STAFF:"
	hire_label.add_theme_font_size_override("font_size", 14)
	main_vbox.add_child(hire_label)

	# 2x2 grid of hire buttons
	var hire_grid = GridContainer.new()
	hire_grid.columns = 2
	hire_grid.add_theme_constant_override("h_separation", 8)
	hire_grid.add_theme_constant_override("v_separation", 6)
	main_vbox.add_child(hire_grid)

	_add_hire_button(hire_grid, StaffManager.StaffType.GROUNDSKEEPER)
	_add_hire_button(hire_grid, StaffManager.StaffType.MARSHAL)
	_add_hire_button(hire_grid, StaffManager.StaffType.CART_OPERATOR)
	_add_hire_button(hire_grid, StaffManager.StaffType.PRO_SHOP)

	main_vbox.add_child(HSeparator.new())

	# Staff roster section
	var roster_label = Label.new()
	roster_label.text = "CURRENT STAFF:"
	roster_label.add_theme_font_size_override("font_size", 14)
	main_vbox.add_child(roster_label)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 120)
	main_vbox.add_child(scroll)

	_staff_list_container = VBoxContainer.new()
	_staff_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_staff_list_container.add_theme_constant_override("separation", 4)
	scroll.add_child(_staff_list_container)

	main_vbox.add_child(HSeparator.new())

	# Modifiers section
	var mod_label = Label.new()
	mod_label.text = "EFFECTS:"
	mod_label.add_theme_font_size_override("font_size", 14)
	main_vbox.add_child(mod_label)

	_modifiers_label = Label.new()
	_modifiers_label.text = "Pace: 60%  Pro Shop: +$0/golfer"
	_modifiers_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	main_vbox.add_child(_modifiers_label)

func _add_hire_button(parent: GridContainer, staff_type: int) -> void:
	var data = StaffManager.STAFF_DATA.get(staff_type, {})
	var btn = Button.new()
	btn.text = "+ %s $%d" % [data.get("name", "Staff"), data.get("base_salary", 50)]
	btn.tooltip_text = data.get("description", "")
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(_on_hire_pressed.bind(staff_type))
	parent.add_child(btn)

func _ready() -> void:
	super._ready()
	# Connect to staff manager signals for reactive updates
	if GameManager.staff_manager:
		GameManager.staff_manager.staff_changed.connect(_on_staff_changed)
		GameManager.staff_manager.condition_changed.connect(_on_condition_changed)

func _on_staff_changed() -> void:
	_update_display()

func _on_condition_changed(_new_condition: float) -> void:
	_update_display()

func _update_display() -> void:
	if not GameManager.staff_manager:
		return

	var sm = GameManager.staff_manager

	# Update condition bar
	var condition_pct = sm.course_condition * 100
	_condition_bar.value = condition_pct

	# Color the progress bar based on condition
	var bar_style = StyleBoxFlat.new()
	if sm.course_condition >= 0.7:
		bar_style.bg_color = Color(0.3, 0.7, 0.3)  # Green
	elif sm.course_condition >= 0.5:
		bar_style.bg_color = Color(0.8, 0.8, 0.3)  # Yellow
	else:
		bar_style.bg_color = Color(0.8, 0.3, 0.3)  # Red
	_condition_bar.add_theme_stylebox_override("fill", bar_style)

	_condition_label.text = "%d%% (%s)" % [int(condition_pct), sm.get_condition_description()]

	# Update payroll
	_payroll_label.text = "Daily Payroll: $%d" % sm.get_daily_payroll()

	# Update staff roster
	for child in _staff_list_container.get_children():
		child.queue_free()

	if sm.hired_staff.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No staff hired"
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_staff_list_container.add_child(empty_label)
	else:
		for i in range(sm.hired_staff.size()):
			var staff = sm.hired_staff[i]
			_add_staff_row(i, staff)

	# Update modifiers
	var pace_pct = int(sm.get_pace_modifier() * 100)
	var pro_bonus = int(sm.get_pro_shop_revenue_bonus())
	_modifiers_label.text = "Pace: %d%%  Pro Shop: +$%d/golfer" % [pace_pct, pro_bonus]

func _add_staff_row(index: int, staff: Dictionary) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_staff_list_container.add_child(row)

	# Staff info
	var type_data = StaffManager.STAFF_DATA.get(staff.type, {})
	var type_name = type_data.get("name", "Staff")
	var staff_name = staff.get("name", "Unknown")

	var info_label = Label.new()
	info_label.text = "%s (%s) $%d" % [staff_name, type_name, staff.salary]
	info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(info_label)

	# Fire button
	var fire_btn = Button.new()
	fire_btn.text = "X"
	fire_btn.custom_minimum_size = Vector2(24, 24)
	fire_btn.tooltip_text = "Fire %s" % staff_name
	fire_btn.pressed.connect(_on_fire_pressed.bind(index))
	row.add_child(fire_btn)

func _on_hire_pressed(staff_type: int) -> void:
	if GameManager.staff_manager:
		GameManager.staff_manager.hire_staff(staff_type)
		_update_display()

func _on_fire_pressed(index: int) -> void:
	if GameManager.staff_manager:
		GameManager.staff_manager.fire_staff(index)
		_update_display()

func _on_close_pressed() -> void:
	close_requested.emit()
	hide()

func toggle() -> void:
	if visible:
		hide()
	else:
		_update_display()
		show_centered()
