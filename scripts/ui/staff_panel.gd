extends PanelContainer
class_name StaffPanel
## StaffPanel - UI for managing staff tier selection

signal tier_changed(new_tier: int)
signal close_requested

var _tier_buttons: Array = []
var _effects_label: Label = null
var _content_vbox: VBoxContainer = null

func _ready() -> void:
	_build_ui()
	hide()

func _build_ui() -> void:
	custom_minimum_size = Vector2(280, 0)
	clip_contents = true

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 4)
	margin.add_child(main_vbox)

	# Title row with close button
	var title_row = HBoxContainer.new()
	main_vbox.add_child(title_row)

	var title = Label.new()
	title.text = "Staff Management"
	title.add_theme_font_size_override("font_size", 16)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(24, 24)
	close_btn.pressed.connect(_on_close_pressed)
	title_row.add_child(close_btn)

	main_vbox.add_child(HSeparator.new())

	# Content area
	_content_vbox = VBoxContainer.new()
	_content_vbox.add_theme_constant_override("separation", 4)
	_content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(_content_vbox)

	# Tier selection buttons
	for tier in GameManager.STAFF_TIER_DATA.keys():
		var tier_data = GameManager.STAFF_TIER_DATA[tier]
		var btn = Button.new()
		btn.text = "%s ($%d/hole/day)" % [tier_data["name"], tier_data["cost_per_hole"]]
		btn.tooltip_text = tier_data["description"]
		btn.toggle_mode = true
		btn.button_pressed = (tier == GameManager.current_staff_tier)
		btn.pressed.connect(_on_tier_selected.bind(tier))
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_content_vbox.add_child(btn)
		_tier_buttons.append(btn)

	_content_vbox.add_child(HSeparator.new())

	# Effects display
	var effects_title = Label.new()
	effects_title.text = "Current Effects:"
	effects_title.add_theme_font_size_override("font_size", 14)
	_content_vbox.add_child(effects_title)

	_effects_label = Label.new()
	_effects_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content_vbox.add_child(_effects_label)

	_update_effects_display()

func _on_tier_selected(tier: int) -> void:
	GameManager.current_staff_tier = tier
	tier_changed.emit(tier)

	# Update button states
	for i in range(_tier_buttons.size()):
		_tier_buttons[i].button_pressed = (i == tier)

	_update_effects_display()
	EventBus.notify("Staff changed to %s" % GameManager.STAFF_TIER_DATA[tier]["name"], "info")

func _update_effects_display() -> void:
	if not _effects_label:
		return

	var tier_data = GameManager.STAFF_TIER_DATA.get(GameManager.current_staff_tier, {})
	var condition_mod = tier_data.get("condition_modifier", 1.0)
	var satisfaction_mod = tier_data.get("satisfaction_modifier", 1.0)

	var condition_text = "Course Condition: %.0f%%" % (condition_mod * 100)
	var satisfaction_text = "Golfer Satisfaction: %.0f%%" % (satisfaction_mod * 100)

	_effects_label.text = "%s\n%s" % [condition_text, satisfaction_text]

func _on_close_pressed() -> void:
	close_requested.emit()
	hide()

func toggle() -> void:
	if visible:
		hide()
	else:
		_update_effects_display()
		# Update button states in case tier changed elsewhere
		for i in range(_tier_buttons.size()):
			_tier_buttons[i].button_pressed = (i == GameManager.current_staff_tier)
		# Resize panel to fit content before showing
		size = get_combined_minimum_size()
		show()
