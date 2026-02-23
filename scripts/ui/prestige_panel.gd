extends CenteredPanel
class_name PrestigePanel
## PrestigePanel - Displays current prestige tier, progress, and unlock info

var _content_container: VBoxContainer = null
var _prestige_system: PrestigeSystem = null
var _tier_label: Label = null
var _progress_bar: ProgressBar = null
var _progress_label: Label = null
var _reqs_list: VBoxContainer = null
var _unlocks_label: Label = null

func setup(prestige: PrestigeSystem) -> void:
	_prestige_system = prestige
	if _prestige_system:
		_prestige_system.prestige_changed.connect(_on_prestige_changed)
		_prestige_system.prestige_progress_updated.connect(_on_progress_updated)

func _build_ui() -> void:
	custom_minimum_size = Vector2(440, 320)

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
	var header = HBoxContainer.new()
	_content_container.add_child(header)

	var title = Label.new()
	title.text = "Course Prestige"
	title.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_LG)
	title.add_theme_color_override("font_color", UIConstants.COLOR_GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(28, 28)
	close_btn.pressed.connect(func(): hide())
	header.add_child(close_btn)

	# Current tier display
	_tier_label = Label.new()
	_tier_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_XL)
	_tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content_container.add_child(_tier_label)

	# Progress bar to next tier
	var progress_container = VBoxContainer.new()
	progress_container.add_theme_constant_override("separation", 2)
	_content_container.add_child(progress_container)

	_progress_label = Label.new()
	_progress_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
	_progress_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_DIM)
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_container.add_child(_progress_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(380, 20)
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = 1.0
	_progress_bar.show_percentage = false
	progress_container.add_child(_progress_bar)

	# Separator
	var sep = HSeparator.new()
	_content_container.add_child(sep)

	# Requirements for next tier
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(400, 160)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_container.add_child(scroll)

	_reqs_list = VBoxContainer.new()
	_reqs_list.add_theme_constant_override("separation", UIConstants.SEPARATION_SM)
	_reqs_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_reqs_list)

	# Current tier unlocks
	_unlocks_label = Label.new()
	_unlocks_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
	_unlocks_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_DIM)
	_unlocks_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_content_container.add_child(_unlocks_label)

func _on_prestige_changed(_old_tier: int, _new_tier: int) -> void:
	_refresh_display()

func _on_progress_updated(_tier: int, _progress: float) -> void:
	if visible:
		_refresh_display()

func show_centered() -> void:
	_refresh_display()
	super.show_centered()

func _refresh_display() -> void:
	if not _prestige_system:
		return

	var tier = _prestige_system.current_tier
	var tier_name = PrestigeSystem.get_tier_name(tier)
	var tier_color = PrestigeSystem.get_tier_color(tier)

	_tier_label.text = "[%s] %s Club" % [tier_name.to_upper(), tier_name]
	_tier_label.add_theme_color_override("font_color", tier_color)

	# Progress
	var next_tier = tier + 1
	if next_tier > PrestigeSystem.PrestigeTier.PLATINUM:
		_progress_label.text = "Maximum prestige achieved!"
		_progress_bar.value = 1.0
	else:
		var next_name = PrestigeSystem.get_tier_name(next_tier)
		_progress_label.text = "Progress to %s: %d%%" % [next_name, int(_prestige_system.tier_progress * 100)]
		_progress_bar.value = _prestige_system.tier_progress

	# Style progress bar color
	var bar_style = StyleBoxFlat.new()
	bar_style.bg_color = Color(0.15, 0.15, 0.15)
	bar_style.set_corner_radius_all(3)
	_progress_bar.add_theme_stylebox_override("background", bar_style)

	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = PrestigeSystem.get_tier_color(min(next_tier, PrestigeSystem.PrestigeTier.PLATINUM))
	fill_style.set_corner_radius_all(3)
	_progress_bar.add_theme_stylebox_override("fill", fill_style)

	# Requirements
	_rebuild_requirements(next_tier)

	# Current unlocks
	var unlocks = PrestigeSystem.TIER_UNLOCKS.get(tier, {})
	if unlocks.has("description"):
		_unlocks_label.text = "Current bonuses: %s" % unlocks["description"]
	else:
		_unlocks_label.text = "Earn prestige by building a successful course!"

func _rebuild_requirements(next_tier: int) -> void:
	for child in _reqs_list.get_children():
		child.queue_free()

	if next_tier > PrestigeSystem.PrestigeTier.PLATINUM:
		var label = Label.new()
		label.text = "You've reached the highest prestige tier! Maintain your legendary status."
		label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
		label.add_theme_color_override("font_color", UIConstants.COLOR_GOLD)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		_reqs_list.add_child(label)
		return

	var header = Label.new()
	header.text = "Requirements for %s:" % PrestigeSystem.get_tier_name(next_tier)
	header.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
	header.add_theme_color_override("font_color", UIConstants.COLOR_TEXT)
	_reqs_list.add_child(header)

	var reqs = _prestige_system.get_tier_requirements_display(next_tier)
	for req in reqs:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", UIConstants.SEPARATION_LG)
		_reqs_list.add_child(row)

		var check = Label.new()
		check.text = "[X]" if req.met else "[ ]"
		check.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
		check.add_theme_color_override("font_color", UIConstants.COLOR_SUCCESS if req.met else UIConstants.COLOR_TEXT_MUTED)
		check.custom_minimum_size = Vector2(30, 0)
		row.add_child(check)

		var label = Label.new()
		label.text = "%s: %s / %s" % [req.label, req.current, req.required]
		label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
		label.add_theme_color_override("font_color", UIConstants.COLOR_SUCCESS if req.met else UIConstants.COLOR_TEXT_DIM)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)

	# Show what next tier unlocks
	var next_unlocks = PrestigeSystem.TIER_UNLOCKS.get(next_tier, {})
	if next_unlocks.has("description"):
		var unlock_label = Label.new()
		unlock_label.text = "\nUnlocks: %s" % next_unlocks["description"]
		unlock_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
		unlock_label.add_theme_color_override("font_color", UIConstants.COLOR_INFO_DIM)
		unlock_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		_reqs_list.add_child(unlock_label)
