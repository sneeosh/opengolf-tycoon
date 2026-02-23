extends CenteredPanel
class_name AdvisorPanel
## AdvisorPanel - Displays context-sensitive advisor tips
##
## Shows tips grouped by priority with dismiss functionality.
## Accessed via hotkey or from end-of-day summary.

var _content_container: VBoxContainer = null
var _tip_list: VBoxContainer = null
var _no_tips_label: Label = null
var _advisor_system: AdvisorSystem = null

func setup(advisor: AdvisorSystem) -> void:
	_advisor_system = advisor
	if _advisor_system:
		_advisor_system.tips_updated.connect(_on_tips_updated)

func _build_ui() -> void:
	custom_minimum_size = Vector2(480, 300)

	var style = StyleBoxFlat.new()
	style.bg_color = UIConstants.COLOR_BG_PANEL
	style.border_color = UIConstants.COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = UIConstants.MARGIN_LG
	style.content_margin_right = UIConstants.MARGIN_LG
	style.content_margin_top = UIConstants.MARGIN_MD
	style.content_margin_bottom = UIConstants.MARGIN_LG
	add_theme_stylebox_override("panel", style)

	_content_container = VBoxContainer.new()
	_content_container.add_theme_constant_override("separation", UIConstants.SEPARATION_LG)
	add_child(_content_container)

	# Header
	var header_row = HBoxContainer.new()
	_content_container.add_child(header_row)

	var title = Label.new()
	title.text = "Course Advisor"
	title.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_LG)
	title.add_theme_color_override("font_color", UIConstants.COLOR_GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(title)

	var refresh_btn = Button.new()
	refresh_btn.text = "Refresh"
	refresh_btn.custom_minimum_size = Vector2(70, 28)
	refresh_btn.pressed.connect(_on_refresh_pressed)
	header_row.add_child(refresh_btn)

	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(28, 28)
	close_btn.pressed.connect(func(): hide())
	header_row.add_child(close_btn)

	# Separator
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	_content_container.add_child(sep)

	# Scrollable tip list
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(440, 250)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_container.add_child(scroll)

	_tip_list = VBoxContainer.new()
	_tip_list.add_theme_constant_override("separation", UIConstants.SEPARATION_MD)
	_tip_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_tip_list)

	# "No tips" label
	_no_tips_label = Label.new()
	_no_tips_label.text = "No advisor tips right now. Everything looks good!"
	_no_tips_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BASE)
	_no_tips_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_DIM)
	_no_tips_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_no_tips_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_tip_list.add_child(_no_tips_label)

func _on_refresh_pressed() -> void:
	if _advisor_system:
		_advisor_system.refresh_tips()

func _on_tips_updated(tips: Array) -> void:
	if not _tip_list:
		return
	_rebuild_tip_list(tips)

func _rebuild_tip_list(tips: Array) -> void:
	# Clear existing tips (keep the no_tips_label)
	for child in _tip_list.get_children():
		if child != _no_tips_label:
			child.queue_free()

	if tips.is_empty():
		_no_tips_label.visible = true
		return

	_no_tips_label.visible = false

	for tip in tips:
		var tip_row = _create_tip_row(tip)
		_tip_list.add_child(tip_row)

func _create_tip_row(tip: AdvisorSystem.AdvisorTip) -> PanelContainer:
	var panel = PanelContainer.new()

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.14, 0.9)
	style.border_color = _get_priority_color(tip.priority)
	style.border_width_left = 3
	style.set_corner_radius_all(3)
	style.content_margin_left = UIConstants.MARGIN_MD
	style.content_margin_right = UIConstants.MARGIN_SM
	style.content_margin_top = UIConstants.MARGIN_SM
	style.content_margin_bottom = UIConstants.MARGIN_SM
	panel.add_theme_stylebox_override("panel", style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", UIConstants.SEPARATION_LG)
	panel.add_child(hbox)

	var text_vbox = VBoxContainer.new()
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(text_vbox)

	# Priority badge + title
	var title_row = HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 6)
	text_vbox.add_child(title_row)

	var badge = Label.new()
	badge.text = "[%s]" % tip.get_priority_label()
	badge.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_XS)
	badge.add_theme_color_override("font_color", _get_priority_color(tip.priority))
	title_row.add_child(badge)

	var title = Label.new()
	title.text = tip.title
	title.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
	title.add_theme_color_override("font_color", UIConstants.COLOR_TEXT)
	title_row.add_child(title)

	# Message
	var msg = Label.new()
	msg.text = tip.message
	msg.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
	msg.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_DIM)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD
	msg.custom_minimum_size = Vector2(350, 0)
	text_vbox.add_child(msg)

	# Dismiss button
	var dismiss_btn = Button.new()
	dismiss_btn.text = "OK"
	dismiss_btn.custom_minimum_size = Vector2(36, 24)
	dismiss_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dismiss_btn.pressed.connect(func():
		if _advisor_system:
			_advisor_system.dismiss_tip(tip.id)
		panel.queue_free()
		# Check if list is now empty
		await get_tree().process_frame
		var remaining = 0
		for child in _tip_list.get_children():
			if child != _no_tips_label and is_instance_valid(child):
				remaining += 1
		if remaining == 0:
			_no_tips_label.visible = true
	)
	hbox.add_child(dismiss_btn)

	return panel

func _get_priority_color(priority: int) -> Color:
	match priority:
		AdvisorSystem.TipPriority.CRITICAL: return UIConstants.COLOR_DANGER
		AdvisorSystem.TipPriority.WARNING: return UIConstants.COLOR_WARNING
		AdvisorSystem.TipPriority.SUGGESTION: return UIConstants.COLOR_INFO
		AdvisorSystem.TipPriority.INFO: return UIConstants.COLOR_TEXT_DIM
	return UIConstants.COLOR_TEXT_DIM

## Show with current tips
func show_with_tips() -> void:
	if _advisor_system:
		_rebuild_tip_list(_advisor_system.current_tips)
	show_centered()
