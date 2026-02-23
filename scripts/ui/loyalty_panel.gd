extends CenteredPanel
class_name LoyaltyPanel
## LoyaltyPanel - Displays loyalty stats, memberships, and word-of-mouth

var _content_container: VBoxContainer = null
var _loyalty_system: LoyaltySystem = null
var _stats_container: VBoxContainer = null
var _membership_container: VBoxContainer = null
var _membership_toggle: CheckButton = null

func setup(loyalty: LoyaltySystem) -> void:
	_loyalty_system = loyalty
	if _loyalty_system:
		_loyalty_system.membership_changed.connect(_on_membership_changed)

func _build_ui() -> void:
	custom_minimum_size = Vector2(460, 380)

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
	title.text = "Loyalty & Memberships"
	title.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_LG)
	title.add_theme_color_override("font_color", UIConstants.COLOR_GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(28, 28)
	close_btn.pressed.connect(func(): hide())
	header.add_child(close_btn)

	# Scrollable content
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(420, 300)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_container.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UIConstants.SEPARATION_LG)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# Loyalty Stats Section
	var stats_header = Label.new()
	stats_header.text = "Golfer Loyalty"
	stats_header.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_MD)
	stats_header.add_theme_color_override("font_color", UIConstants.COLOR_TEXT)
	vbox.add_child(stats_header)

	_stats_container = VBoxContainer.new()
	_stats_container.add_theme_constant_override("separation", UIConstants.SEPARATION_SM)
	vbox.add_child(_stats_container)

	vbox.add_child(HSeparator.new())

	# Membership Section
	var mem_header_row = HBoxContainer.new()
	vbox.add_child(mem_header_row)

	var mem_header = Label.new()
	mem_header.text = "Memberships"
	mem_header.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_MD)
	mem_header.add_theme_color_override("font_color", UIConstants.COLOR_TEXT)
	mem_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mem_header_row.add_child(mem_header)

	_membership_toggle = CheckButton.new()
	_membership_toggle.text = "Sell Memberships"
	_membership_toggle.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
	_membership_toggle.toggled.connect(_on_membership_toggled)
	mem_header_row.add_child(_membership_toggle)

	_membership_container = VBoxContainer.new()
	_membership_container.add_theme_constant_override("separation", UIConstants.SEPARATION_MD)
	vbox.add_child(_membership_container)

func _on_membership_changed(_tier: int, _count: int) -> void:
	if visible:
		_refresh_display()

func _on_membership_toggled(enabled: bool) -> void:
	if _loyalty_system:
		_loyalty_system.set_memberships_enabled(enabled)
		_refresh_display()

func show_centered() -> void:
	_refresh_display()
	super.show_centered()

func _refresh_display() -> void:
	if not _loyalty_system:
		return

	_refresh_stats()
	_refresh_memberships()

	if _membership_toggle:
		_membership_toggle.button_pressed = _loyalty_system.memberships_enabled

func _refresh_stats() -> void:
	for child in _stats_container.get_children():
		child.queue_free()

	var stats = [
		["Total Visits", str(_loyalty_system.total_visits)],
		["Happy Visits", "%d (%.0f%%)" % [_loyalty_system.total_happy_visits, _loyalty_system._get_average_satisfaction() * 100]],
		["Unhappy Visits", str(_loyalty_system.total_unhappy_visits)],
		["Word of Mouth", _format_word_of_mouth(_loyalty_system.word_of_mouth_score)],
		["Loyalty Points", str(_loyalty_system.loyalty_points)],
		["Spawn Bonus", "%+.0f%%" % (_loyalty_system.get_spawn_rate_bonus() * 100)],
	]

	for stat in stats:
		var row = HBoxContainer.new()
		_stats_container.add_child(row)

		var label = Label.new()
		label.text = stat[0]
		label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
		label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_DIM)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)

		var value = Label.new()
		value.text = stat[1]
		value.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
		value.add_theme_color_override("font_color", UIConstants.COLOR_TEXT)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.custom_minimum_size = Vector2(120, 0)
		row.add_child(value)

func _refresh_memberships() -> void:
	for child in _membership_container.get_children():
		child.queue_free()

	if not _loyalty_system.memberships_enabled:
		var hint = Label.new()
		hint.text = "Enable membership sales to attract loyal golfers and earn steady revenue."
		hint.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
		hint.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_MUTED)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD
		_membership_container.add_child(hint)
		return

	for tier in LoyaltySystem.MEMBERSHIP_CONFIG.keys():
		var config = LoyaltySystem.MEMBERSHIP_CONFIG[tier]
		var count = _loyalty_system.members.get(tier, 0)
		var max_cap = config["max_members"]
		var tier_name = LoyaltySystem.get_tier_name(tier)
		var tier_color = LoyaltySystem.get_tier_color(tier)

		var panel = PanelContainer.new()
		var panel_style = StyleBoxFlat.new()
		panel_style.bg_color = Color(0.12, 0.12, 0.14, 0.9)
		panel_style.border_color = tier_color
		panel_style.border_width_left = 3
		panel_style.set_corner_radius_all(3)
		panel_style.content_margin_left = UIConstants.MARGIN_MD
		panel_style.content_margin_right = UIConstants.MARGIN_SM
		panel_style.content_margin_top = UIConstants.MARGIN_SM
		panel_style.content_margin_bottom = UIConstants.MARGIN_SM
		panel.add_theme_stylebox_override("panel", panel_style)
		_membership_container.add_child(panel)

		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 2)
		panel.add_child(vbox)

		# Tier name and count
		var top_row = HBoxContainer.new()
		vbox.add_child(top_row)

		var name_label = Label.new()
		name_label.text = "%s Membership" % tier_name
		name_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
		name_label.add_theme_color_override("font_color", tier_color)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_row.add_child(name_label)

		var count_label = Label.new()
		count_label.text = "%d / %d members" % [count, max_cap]
		count_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
		count_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT)
		top_row.add_child(count_label)

		# Details
		var locked = GameManager.reputation < config["min_reputation"]
		var desc = Label.new()
		if locked:
			desc.text = "Requires %d reputation (current: %.0f)" % [config["min_reputation"], GameManager.reputation]
			desc.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_MUTED)
		else:
			desc.text = "$%d/year | %s" % [config["monthly_fee"], config["description"]]
			desc.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_DIM)
		desc.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_XS)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD
		desc.custom_minimum_size = Vector2(380, 0)
		vbox.add_child(desc)

		# Revenue line
		if count > 0:
			var rev = Label.new()
			rev.text = "Annual revenue: $%d" % (config["monthly_fee"] * count)
			rev.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_XS)
			rev.add_theme_color_override("font_color", UIConstants.COLOR_SUCCESS)
			vbox.add_child(rev)

func _format_word_of_mouth(score: float) -> String:
	if score > 0.3:
		return "Excellent (+%.0f%%)" % (score * 15)
	elif score > 0.1:
		return "Good (+%.0f%%)" % (score * 15)
	elif score > -0.1:
		return "Neutral"
	elif score > -0.3:
		return "Poor (%.0f%%)" % (score * 15)
	else:
		return "Bad (%.0f%%)" % (score * 15)
