extends CenteredPanel
class_name TournamentPanel
## TournamentPanel - UI for viewing and hosting tournaments

signal close_requested

var _tournament_manager: TournamentManager = null
var _content_vbox: VBoxContainer = null
var _status_label: Label = null
var _title_label: Label = null

func _ready() -> void:
	super._ready()
	# Connect to tournament events
	EventBus.tournament_scheduled.connect(_on_tournament_scheduled)
	EventBus.tournament_started.connect(_on_tournament_started)
	EventBus.tournament_completed.connect(_on_tournament_completed)

func _build_ui() -> void:
	custom_minimum_size = Vector2(340, 480)

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

	_title_label = Label.new()
	_title_label.text = "Tournaments"
	_title_label.add_theme_font_size_override("font_size", 18)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(_title_label)

	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(30, 30)
	close_btn.pressed.connect(_on_close_pressed)
	title_row.add_child(close_btn)

	main_vbox.add_child(HSeparator.new())

	# Status label
	_status_label = Label.new()
	_status_label.text = "Select a tournament to host:"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main_vbox.add_child(_status_label)

	main_vbox.add_child(HSeparator.new())

	# Scrollable content area
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 350)
	main_vbox.add_child(scroll)

	_content_vbox = VBoxContainer.new()
	_content_vbox.add_theme_constant_override("separation", 6)
	_content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_content_vbox)

func setup(tournament_manager: TournamentManager) -> void:
	_tournament_manager = tournament_manager

func toggle() -> void:
	if visible:
		hide()
	else:
		_refresh_display()
		show_centered()

func _refresh_display() -> void:
	if not _tournament_manager:
		return

	# Clear content
	for child in _content_vbox.get_children():
		child.queue_free()

	# Check current tournament status
	var info = _tournament_manager.get_tournament_info()
	if info.is_empty():
		_show_available_tournaments()
	else:
		_show_current_tournament(info)

func _show_available_tournaments() -> void:
	var cooldown = _tournament_manager.get_cooldown_remaining()
	if cooldown > 0:
		_status_label.text = "Cooldown: %d days until next tournament" % cooldown
		_status_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.5))
	else:
		_status_label.text = "Select a tournament to host:"
		_status_label.remove_theme_color_override("font_color")

	# Show all tournament tiers
	for tier in TournamentSystem.TournamentTier.values():
		var tier_data = TournamentSystem.get_tier_data(tier)
		var can_schedule = _tournament_manager.can_schedule_tournament(tier)

		# Tournament name
		var name_label = Label.new()
		name_label.text = tier_data.name
		name_label.add_theme_font_size_override("font_size", 14)
		_content_vbox.add_child(name_label)

		# Requirements row
		var req_row = _create_stat_row(
			"Requirements:",
			"%d holes, %.1f stars" % [tier_data.min_holes, tier_data.min_rating],
			Color(0.7, 0.7, 0.7)
		)
		_content_vbox.add_child(req_row)

		# Cost/Prize row
		var cost_row = _create_stat_row(
			"Entry / Prize:",
			"$%d / $%d" % [tier_data.entry_cost, tier_data.prize_pool],
			Color(0.7, 0.9, 0.7)
		)
		_content_vbox.add_child(cost_row)

		# Reward row
		var reward_row = _create_stat_row(
			"Reputation:",
			"+%d (%d days)" % [tier_data.reputation_reward, tier_data.duration_days],
			Color(0.7, 0.8, 0.9)
		)
		_content_vbox.add_child(reward_row)

		# Host button
		var btn_container = HBoxContainer.new()
		btn_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_content_vbox.add_child(btn_container)

		var spacer = Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_container.add_child(spacer)

		var host_btn = Button.new()
		host_btn.text = "Host Tournament"
		host_btn.custom_minimum_size = Vector2(140, 32)
		host_btn.disabled = not can_schedule.can_schedule
		if can_schedule.can_schedule:
			host_btn.pressed.connect(_on_host_pressed.bind(tier))
		else:
			host_btn.tooltip_text = can_schedule.reason
		btn_container.add_child(host_btn)

		_content_vbox.add_child(HSeparator.new())

func _show_current_tournament(info: Dictionary) -> void:
	var state_text = ""
	match info.state:
		TournamentSystem.TournamentState.SCHEDULED:
			state_text = "Starts in %d days" % info.days_remaining
			_status_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.3))
		TournamentSystem.TournamentState.IN_PROGRESS:
			state_text = "In Progress"
			_status_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))

	_status_label.text = "%s\n%s" % [info.name, state_text]

	# Show tournament info
	var info_label = Label.new()
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))

	if info.state == TournamentSystem.TournamentState.IN_PROGRESS:
		info_label.text = "Professional golfers are competing on your course. Watch the tournament or press End Day to skip ahead."
		_content_vbox.add_child(info_label)

		var hint_label = Label.new()
		hint_label.text = "The live leaderboard is shown on the right side of the screen."
		hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint_label.add_theme_font_size_override("font_size", 11)
		hint_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_content_vbox.add_child(hint_label)
	else:
		info_label.text = "Tournament scheduled. Professional golfers will compete on your course."
		_content_vbox.add_child(info_label)

	# Show last results if available
	if not _tournament_manager.tournament_results.is_empty():
		_content_vbox.add_child(HSeparator.new())

		var results_title = Label.new()
		results_title.text = "Previous Tournament Results"
		results_title.add_theme_font_size_override("font_size", 14)
		_content_vbox.add_child(results_title)

		var results = _tournament_manager.tournament_results
		var winner_row = _create_stat_row("Winner:", results.get("winner_name", "Unknown"), Color(1.0, 0.85, 0.0))
		_content_vbox.add_child(winner_row)

		var score_row = _create_stat_row("Score:", "%d (Par %d)" % [results.get("winning_score", 0), results.get("par", 72)], Color.WHITE)
		_content_vbox.add_child(score_row)

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

func _on_host_pressed(tier: int) -> void:
	if _tournament_manager.schedule_tournament(tier):
		_refresh_display()

func _on_close_pressed() -> void:
	close_requested.emit()
	hide()

func _on_tournament_scheduled(_tier: int, start_day: int) -> void:
	EventBus.notify("Tournament scheduled for Day %d!" % start_day, "success")
	if visible:
		_refresh_display()

func _on_tournament_started(tier: int) -> void:
	var name = TournamentSystem.get_tier_name(tier)
	EventBus.notify("%s has begun!" % name, "success")
	if visible:
		_refresh_display()

func _on_tournament_completed(tier: int, results: Dictionary) -> void:
	var name = TournamentSystem.get_tier_name(tier)
	EventBus.notify("%s completed! Winner: %s (%d)" % [name, results.winner_name, results.winning_score], "success")
	if visible:
		_refresh_display()
