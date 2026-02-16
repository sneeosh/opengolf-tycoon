extends CenteredPanel
class_name MarketingPanel
## MarketingPanel - UI for launching and tracking marketing campaigns
##
## Displays spawn rate bonus, daily costs, launch buttons for 5 channels,
## and a list of active campaigns with countdown timers.

signal close_requested

var _bonus_label: Label = null
var _cost_label: Label = null
var _campaigns_container: VBoxContainer = null
var _stats_label: Label = null

func _build_ui() -> void:
	custom_minimum_size = Vector2(360, 480)

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
	title.text = "Marketing"
	title.add_theme_font_size_override("font_size", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(30, 30)
	close_btn.pressed.connect(_on_close_pressed)
	title_row.add_child(close_btn)

	main_vbox.add_child(HSeparator.new())

	# Status row
	var status_row = HBoxContainer.new()
	main_vbox.add_child(status_row)

	_bonus_label = Label.new()
	_bonus_label.text = "Spawn Bonus: +0%"
	_bonus_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	_bonus_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_row.add_child(_bonus_label)

	_cost_label = Label.new()
	_cost_label.text = "Daily: $0"
	_cost_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.4))
	status_row.add_child(_cost_label)

	main_vbox.add_child(HSeparator.new())

	# Launch section
	var launch_label = Label.new()
	launch_label.text = "LAUNCH CAMPAIGN:"
	launch_label.add_theme_font_size_override("font_size", 14)
	main_vbox.add_child(launch_label)

	# Campaign buttons
	var campaigns_vbox = VBoxContainer.new()
	campaigns_vbox.add_theme_constant_override("separation", 4)
	main_vbox.add_child(campaigns_vbox)

	for channel in MarketingManager.CHANNEL_DATA.keys():
		_add_campaign_button(campaigns_vbox, channel)

	main_vbox.add_child(HSeparator.new())

	# Active campaigns section
	var active_label = Label.new()
	active_label.text = "ACTIVE CAMPAIGNS:"
	active_label.add_theme_font_size_override("font_size", 14)
	main_vbox.add_child(active_label)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 80)
	main_vbox.add_child(scroll)

	_campaigns_container = VBoxContainer.new()
	_campaigns_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_campaigns_container.add_theme_constant_override("separation", 4)
	scroll.add_child(_campaigns_container)

	main_vbox.add_child(HSeparator.new())

	# Stats row
	_stats_label = Label.new()
	_stats_label.text = "Total spent: $0 | Campaigns: 0"
	_stats_label.add_theme_font_size_override("font_size", 12)
	_stats_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	main_vbox.add_child(_stats_label)

func _add_campaign_button(parent: VBoxContainer, channel: int) -> void:
	var data = MarketingManager.CHANNEL_DATA.get(channel, {})
	var setup_cost = data.get("daily_cost", 50) * 2
	var daily_cost = data.get("daily_cost", 50)
	var duration = data.get("duration_days", 5)
	var bonus = int(data.get("spawn_rate_bonus", 0.15) * 100)

	var btn = Button.new()
	btn.text = "%s  $%d setup  %dd  +%d%%" % [data.get("name", "Campaign"), setup_cost, duration, bonus]
	btn.tooltip_text = "%s\nSetup: $%d | Daily: $%d | Duration: %d days | Bonus: +%d%%" % [
		data.get("description", ""),
		setup_cost,
		daily_cost,
		duration,
		bonus
	]
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(_on_launch_pressed.bind(channel))
	parent.add_child(btn)

func _ready() -> void:
	super._ready()
	# Connect to marketing manager signals for reactive updates
	if GameManager.marketing_manager:
		GameManager.marketing_manager.campaigns_changed.connect(_on_campaigns_changed)
		GameManager.marketing_manager.campaign_started.connect(_on_campaign_started)
		GameManager.marketing_manager.campaign_ended.connect(_on_campaign_ended)

func _on_campaigns_changed() -> void:
	_update_display()

func _on_campaign_started(_channel: int) -> void:
	_update_display()

func _on_campaign_ended(_channel: int) -> void:
	_update_display()

func _update_display() -> void:
	if not GameManager.marketing_manager:
		return

	var mm = GameManager.marketing_manager

	# Update spawn bonus
	var spawn_mod = mm.get_spawn_rate_modifier()
	var bonus_pct = int((spawn_mod - 1.0) * 100)
	_bonus_label.text = "Spawn Bonus: +%d%%" % bonus_pct
	if bonus_pct > 0:
		_bonus_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	else:
		_bonus_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))

	# Update daily cost
	var daily_cost = mm.get_daily_marketing_cost()
	_cost_label.text = "Daily: $%d" % daily_cost

	# Update active campaigns list
	for child in _campaigns_container.get_children():
		child.queue_free()

	if mm.active_campaigns.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No active campaigns"
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_campaigns_container.add_child(empty_label)
	else:
		for campaign in mm.active_campaigns:
			_add_campaign_row(campaign)

	# Update stats
	_stats_label.text = "Total spent: $%d | Campaigns: %d" % [mm.total_marketing_spent, mm.campaigns_completed]

func _add_campaign_row(campaign: Dictionary) -> void:
	var row = HBoxContainer.new()
	_campaigns_container.add_child(row)

	var data = MarketingManager.CHANNEL_DATA.get(campaign.channel, {})
	var name_str = data.get("name", "Campaign")

	var bullet = Label.new()
	bullet.text = "  "
	row.add_child(bullet)

	var info_label = Label.new()
	info_label.text = "%s - %d day%s left" % [
		name_str,
		campaign.days_remaining,
		"" if campaign.days_remaining == 1 else "s"
	]
	info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info_label)

	var cost_label = Label.new()
	cost_label.text = "$%d/day" % campaign.daily_cost
	cost_label.add_theme_color_override("font_color", Color(0.8, 0.7, 0.5))
	row.add_child(cost_label)

func _on_launch_pressed(channel: int) -> void:
	if GameManager.marketing_manager:
		GameManager.marketing_manager.start_campaign(channel)
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
