extends CenteredPanel
class_name MilestonesPanel
## MilestonesPanel - Shows milestone progress and achievements

signal close_requested

var _milestone_manager: MilestoneManager = null
var _content: VBoxContainer = null

func set_milestone_manager(manager: MilestoneManager) -> void:
	_milestone_manager = manager

func _build_ui() -> void:
	custom_minimum_size = Vector2(420, 500)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Title row
	var title_row = HBoxContainer.new()
	vbox.add_child(title_row)

	var title = Label.new()
	title.text = "Milestones"
	title.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_LG)
	title.add_theme_color_override("font_color", UIConstants.COLOR_GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.pressed.connect(func(): close_requested.emit())
	title_row.add_child(close_btn)

	vbox.add_child(HSeparator.new())

	# Progress summary
	var progress = Label.new()
	progress.name = "ProgressLabel"
	progress.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
	progress.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_DIM)
	vbox.add_child(progress)

	# Scrollable content
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 380)
	vbox.add_child(scroll)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 4)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_content)

func show_centered() -> void:
	_refresh_display()
	await super.show_centered()

func _refresh_display() -> void:
	if not _milestone_manager:
		return

	# Update progress label
	var progress_label = find_child("ProgressLabel", true, false)
	if progress_label:
		progress_label.text = "Completed: %d / %d" % [
			_milestone_manager.get_completion_count(),
			_milestone_manager.get_total_count()
		]

	# Clear content
	for child in _content.get_children():
		child.queue_free()

	# Group milestones by category
	var by_category: Dictionary = {}
	for m in _milestone_manager.milestones:
		if not by_category.has(m.category):
			by_category[m.category] = []
		by_category[m.category].append(m)

	# Display each category
	for category in by_category:
		var cat_label = Label.new()
		cat_label.text = MilestoneSystem.get_category_name(category)
		cat_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BASE)
		cat_label.add_theme_color_override("font_color", MilestoneSystem.get_category_color(category))
		_content.add_child(cat_label)

		for m in by_category[category]:
			_content.add_child(_create_milestone_row(m))

		_content.add_child(HSeparator.new())

func _create_milestone_row(m: MilestoneSystem.Milestone) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	# Status icon
	var status = Label.new()
	status.text = "[+]" if m.is_completed else "[ ]"
	status.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
	status.add_theme_color_override("font_color", UIConstants.COLOR_SUCCESS if m.is_completed else UIConstants.COLOR_TEXT_MUTED)
	status.custom_minimum_size = Vector2(28, 0)
	row.add_child(status)

	# Title + description
	var text_vbox = VBoxContainer.new()
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var title = Label.new()
	title.text = m.title
	title.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
	if m.is_completed:
		title.add_theme_color_override("font_color", UIConstants.COLOR_TEXT)
	else:
		title.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_DIM)
	text_vbox.add_child(title)

	var desc = Label.new()
	desc.text = m.description
	desc.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_XS)
	desc.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_MUTED)
	text_vbox.add_child(desc)

	row.add_child(text_vbox)

	# Reward info
	if m.reward_money > 0 or m.reward_reputation > 0.0:
		var reward = Label.new()
		var parts: Array = []
		if m.reward_money > 0:
			parts.append("$%d" % m.reward_money)
		if m.reward_reputation > 0.0:
			parts.append("+%.0f rep" % m.reward_reputation)
		reward.text = ", ".join(parts)
		reward.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_XS)
		reward.add_theme_color_override("font_color", UIConstants.COLOR_SUCCESS_DIM if m.is_completed else UIConstants.COLOR_TEXT_MUTED)
		reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		reward.custom_minimum_size = Vector2(80, 0)
		row.add_child(reward)

	# Completion day
	if m.is_completed:
		var day_label = Label.new()
		day_label.text = "Day %d" % m.completion_day
		day_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_XS)
		day_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_MUTED)
		day_label.custom_minimum_size = Vector2(50, 0)
		day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(day_label)

	return row
