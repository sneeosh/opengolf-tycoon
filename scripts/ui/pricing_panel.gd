extends CenteredPanel
class_name PricingPanel
## PricingPanel - Dynamic pricing analysis and auto-pricing controls

var _content_container: VBoxContainer = null
var _pricing_system: DynamicPricingSystem = null
var _analysis_container: VBoxContainer = null
var _auto_toggle: CheckButton = null
var _strategy_buttons: Array = []
var _apply_btn: Button = null
var _fee_slider: HSlider = null
var _fee_label: Label = null

func setup(pricing: DynamicPricingSystem) -> void:
	_pricing_system = pricing
	if _pricing_system:
		_pricing_system.pricing_updated.connect(_on_pricing_updated)

func _build_ui() -> void:
	custom_minimum_size = Vector2(460, 420)

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
	title.text = "Dynamic Pricing"
	title.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_LG)
	title.add_theme_color_override("font_color", UIConstants.COLOR_GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(28, 28)
	close_btn.pressed.connect(func(): hide())
	header.add_child(close_btn)

	# Fee slider
	var slider_section = VBoxContainer.new()
	slider_section.add_theme_constant_override("separation", 4)
	_content_container.add_child(slider_section)

	var slider_header = HBoxContainer.new()
	slider_section.add_child(slider_header)

	var slider_title = Label.new()
	slider_title.text = "Green Fee:"
	slider_title.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
	slider_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider_header.add_child(slider_title)

	_fee_label = Label.new()
	_fee_label.text = "$%d/hole" % GameManager.green_fee
	_fee_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
	_fee_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT)
	slider_header.add_child(_fee_label)

	_fee_slider = HSlider.new()
	_fee_slider.min_value = GameManager.MIN_GREEN_FEE
	_fee_slider.max_value = GameManager.get_effective_max_green_fee()
	_fee_slider.step = 5
	_fee_slider.value = GameManager.green_fee
	_fee_slider.custom_minimum_size = Vector2(380, 20)
	_fee_slider.value_changed.connect(_on_fee_slider_changed)
	slider_section.add_child(_fee_slider)

	# Apply suggested button
	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", UIConstants.SEPARATION_MD)
	_content_container.add_child(btn_row)

	_apply_btn = Button.new()
	_apply_btn.text = "Apply Suggested"
	_apply_btn.custom_minimum_size = Vector2(140, 30)
	_apply_btn.pressed.connect(_on_apply_suggested)
	btn_row.add_child(_apply_btn)

	_auto_toggle = CheckButton.new()
	_auto_toggle.text = "Auto-Pricing"
	_auto_toggle.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
	_auto_toggle.toggled.connect(_on_auto_toggled)
	btn_row.add_child(_auto_toggle)

	_content_container.add_child(HSeparator.new())

	# Strategy selection
	var strategy_label = Label.new()
	strategy_label.text = "Pricing Strategy:"
	strategy_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
	strategy_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT)
	_content_container.add_child(strategy_label)

	var strategy_row = HBoxContainer.new()
	strategy_row.add_theme_constant_override("separation", UIConstants.SEPARATION_SM)
	_content_container.add_child(strategy_row)

	var strategies = [
		[DynamicPricingSystem.PricingStrategy.MAXIMIZE_GOLFERS, "Max Golfers"],
		[DynamicPricingSystem.PricingStrategy.BALANCED, "Balanced"],
		[DynamicPricingSystem.PricingStrategy.MAXIMIZE_REVENUE, "Max Revenue"],
	]
	for strat in strategies:
		var btn = Button.new()
		btn.text = strat[1]
		btn.custom_minimum_size = Vector2(120, 28)
		btn.pressed.connect(_on_strategy_selected.bind(strat[0]))
		strategy_row.add_child(btn)
		_strategy_buttons.append({"button": btn, "strategy": strat[0]})

	_content_container.add_child(HSeparator.new())

	# Analysis section
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(420, 160)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_container.add_child(scroll)

	_analysis_container = VBoxContainer.new()
	_analysis_container.add_theme_constant_override("separation", UIConstants.SEPARATION_SM)
	_analysis_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_analysis_container)

func _on_pricing_updated(_suggested: int, _reason: String) -> void:
	if visible:
		_refresh_display()

func _on_fee_slider_changed(value: float) -> void:
	GameManager.set_green_fee(int(value))
	if _fee_label:
		_fee_label.text = "$%d/hole" % int(value)

func _on_apply_suggested() -> void:
	if _pricing_system:
		GameManager.set_green_fee(_pricing_system.suggested_fee)
		if _fee_slider:
			_fee_slider.value = _pricing_system.suggested_fee
		_refresh_display()

func _on_auto_toggled(enabled: bool) -> void:
	if _pricing_system:
		_pricing_system.auto_pricing_enabled = enabled
		_refresh_display()

func _on_strategy_selected(strategy: int) -> void:
	if _pricing_system:
		_pricing_system.current_strategy = strategy
		_pricing_system._calculate_suggested_fee()
		_refresh_display()

func show_centered() -> void:
	_refresh_display()
	super.show_centered()

func _refresh_display() -> void:
	if not _pricing_system:
		return

	# Update slider range and value
	if _fee_slider:
		_fee_slider.max_value = GameManager.get_effective_max_green_fee()
		_fee_slider.value = GameManager.green_fee
	if _fee_label:
		_fee_label.text = "$%d/hole" % GameManager.green_fee

	if _auto_toggle:
		_auto_toggle.button_pressed = _pricing_system.auto_pricing_enabled

	# Update strategy button highlights
	for item in _strategy_buttons:
		var btn = item["button"] as Button
		if item["strategy"] == _pricing_system.current_strategy:
			btn.add_theme_color_override("font_color", UIConstants.COLOR_GOLD)
		else:
			btn.remove_theme_color_override("font_color")

	# Update apply button text
	if _apply_btn:
		_apply_btn.text = "Apply Suggested ($%d)" % _pricing_system.suggested_fee
		_apply_btn.disabled = _pricing_system.auto_pricing_enabled

	_refresh_analysis()

func _refresh_analysis() -> void:
	for child in _analysis_container.get_children():
		child.queue_free()

	var analysis = _pricing_system.get_price_analysis()
	for item in analysis:
		var row = HBoxContainer.new()
		_analysis_container.add_child(row)

		var label = Label.new()
		label.text = item["label"]
		label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
		label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_DIM)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)

		var value = Label.new()
		value.text = item["value"]
		value.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.custom_minimum_size = Vector2(160, 0)

		var color_key = item.get("color", "")
		match color_key:
			"success": value.add_theme_color_override("font_color", UIConstants.COLOR_SUCCESS)
			"error": value.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
			"warning": value.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
			_: value.add_theme_color_override("font_color", UIConstants.COLOR_TEXT)

		row.add_child(value)

	# Suggestion reason
	if not _pricing_system.suggestion_reason.is_empty():
		var reason_label = Label.new()
		reason_label.text = "\nSuggestion: %s" % _pricing_system.suggestion_reason
		reason_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
		reason_label.add_theme_color_override("font_color", UIConstants.COLOR_INFO_DIM)
		reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		_analysis_container.add_child(reason_label)
