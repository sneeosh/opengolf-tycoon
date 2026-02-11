extends PanelContainer
class_name TournamentPanel
## TournamentPanel - UI for viewing and hosting tournaments

var _tournament_manager: TournamentManager = null

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var tournament_list: VBoxContainer = $VBoxContainer/ScrollContainer/TournamentList
@onready var results_container: VBoxContainer = $VBoxContainer/ResultsContainer
@onready var results_label: Label = $VBoxContainer/ResultsContainer/ResultsLabel
@onready var close_button: Button = $VBoxContainer/CloseButton

func _ready() -> void:
	visible = false
	close_button.pressed.connect(_on_close_pressed)

	# Connect to tournament events
	EventBus.tournament_scheduled.connect(_on_tournament_scheduled)
	EventBus.tournament_started.connect(_on_tournament_started)
	EventBus.tournament_completed.connect(_on_tournament_completed)

func setup(tournament_manager: TournamentManager) -> void:
	_tournament_manager = tournament_manager
	_refresh_display()

func toggle() -> void:
	visible = not visible
	if visible:
		_refresh_display()

func _refresh_display() -> void:
	if not _tournament_manager:
		return

	# Clear tournament list
	for child in tournament_list.get_children():
		child.queue_free()

	# Check current tournament status
	var info = _tournament_manager.get_tournament_info()
	if info.is_empty():
		_show_available_tournaments()
		results_container.visible = false
	else:
		_show_current_tournament(info)

func _show_available_tournaments() -> void:
	var cooldown = _tournament_manager.get_cooldown_remaining()
	if cooldown > 0:
		status_label.text = "Cooldown: %d days until next tournament" % cooldown
	else:
		status_label.text = "Select a tournament to host:"

	# Show all tournament tiers with qualification status
	for tier in TournamentSystem.TournamentTier.values():
		var tier_data = TournamentSystem.get_tier_data(tier)
		var qualification = TournamentSystem.check_qualification(
			tier,
			GameManager.current_course,
			GameManager.course_rating
		)
		var can_schedule = _tournament_manager.can_schedule_tournament(tier)

		var container = HBoxContainer.new()
		tournament_list.add_child(container)

		var info_vbox = VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		container.add_child(info_vbox)

		var name_label = Label.new()
		name_label.text = tier_data.name
		name_label.add_theme_font_size_override("font_size", 14)
		info_vbox.add_child(name_label)

		var details_label = Label.new()
		details_label.text = "Req: %d holes, %.1f★ | Entry: $%d | Prize: $%d" % [
			tier_data.min_holes,
			tier_data.min_rating,
			tier_data.entry_cost,
			tier_data.prize_pool
		]
		details_label.add_theme_font_size_override("font_size", 11)
		details_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		info_vbox.add_child(details_label)

		var reward_label = Label.new()
		reward_label.text = "Reputation: +%d | Duration: %d days" % [
			tier_data.reputation_reward,
			tier_data.duration_days
		]
		reward_label.add_theme_font_size_override("font_size", 11)
		reward_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
		info_vbox.add_child(reward_label)

		var host_button = Button.new()
		host_button.text = "Host"
		host_button.custom_minimum_size.x = 60
		host_button.disabled = not can_schedule.can_schedule
		if can_schedule.can_schedule:
			host_button.pressed.connect(_on_host_pressed.bind(tier))
		else:
			host_button.tooltip_text = can_schedule.reason
		container.add_child(host_button)

		# Add separator
		var sep = HSeparator.new()
		tournament_list.add_child(sep)

func _show_current_tournament(info: Dictionary) -> void:
	var state_text = ""
	match info.state:
		TournamentSystem.TournamentState.SCHEDULED:
			state_text = "Scheduled - starts in %d days" % info.days_remaining
			status_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.3))
		TournamentSystem.TournamentState.IN_PROGRESS:
			state_text = "In Progress - %d day(s) remaining" % info.days_remaining
			status_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))

	status_label.text = "%s\n%s" % [info.name, state_text]

	# Show tournament details
	var details = Label.new()
	details.text = "Tournament in progress. Course is hosting professional golfers."
	tournament_list.add_child(details)

func _on_host_pressed(tier: int) -> void:
	if _tournament_manager.schedule_tournament(tier):
		_refresh_display()

func _on_close_pressed() -> void:
	visible = false

func _on_tournament_scheduled(_tier: int, start_day: int) -> void:
	EventBus.notify("Tournament scheduled for Day %d!" % start_day, "success")
	_refresh_display()

func _on_tournament_started(tier: int) -> void:
	var name = TournamentSystem.get_tier_name(tier)
	EventBus.notify("%s has begun!" % name, "success")
	_refresh_display()

func _on_tournament_completed(tier: int, results: Dictionary) -> void:
	var name = TournamentSystem.get_tier_name(tier)
	EventBus.notify("%s completed! Winner: %s (%d)" % [name, results.winner_name, results.winning_score], "success")

	# Show results
	results_container.visible = true
	results_label.text = "Tournament Results:\nWinner: %s\nScore: %d (Par %d)\nPrize Pool: $%d" % [
		results.winner_name,
		results.winning_score,
		results.par,
		results.prize_pool
	]

	_refresh_display()

func _build_ui() -> void:
	# Build UI structure programmatically
	custom_minimum_size = Vector2(320, 400)

	var main_vbox = VBoxContainer.new()
	main_vbox.name = "VBoxContainer"
	add_child(main_vbox)

	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "Tournaments"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 18)
	main_vbox.add_child(title_label)

	var sep1 = HSeparator.new()
	main_vbox.add_child(sep1)

	status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.text = "Select a tournament to host:"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main_vbox.add_child(status_label)

	var scroll = ScrollContainer.new()
	scroll.name = "ScrollContainer"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 200
	main_vbox.add_child(scroll)

	tournament_list = VBoxContainer.new()
	tournament_list.name = "TournamentList"
	tournament_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(tournament_list)

	results_container = VBoxContainer.new()
	results_container.name = "ResultsContainer"
	results_container.visible = false
	main_vbox.add_child(results_container)

	var results_title = Label.new()
	results_title.text = "Last Tournament Results"
	results_title.add_theme_font_size_override("font_size", 14)
	results_container.add_child(results_title)

	results_label = Label.new()
	results_label.name = "ResultsLabel"
	results_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	results_container.add_child(results_label)

	close_button = Button.new()
	close_button.name = "CloseButton"
	close_button.text = "Close"
	main_vbox.add_child(close_button)
