extends Node2D
## Main - Primary game scene controller

@onready var terrain_grid: TerrainGrid = $TerrainGrid
@onready var camera: IsometricCamera = $IsometricCamera
@onready var ball_manager: BallManager = $BallManager
@onready var hole_manager: HoleManager = $HoleManager
@onready var golfer_manager: GolferManager = $GolferManager
@onready var coordinate_label: Label = $UI/HUD/BottomBar/CoordinateLabel
@onready var tool_panel_container: Control = $UI/HUD/ToolPanel
var terrain_toolbar: TerrainToolbar = null
@onready var hole_list: VBoxContainer = $UI/HUD/HoleInfoPanel/VBoxContainer/ScrollContainer/HoleList
@onready var pause_btn: Button = $UI/HUD/BottomBar/SpeedControls/PauseBtn
@onready var play_btn: Button = $UI/HUD/BottomBar/SpeedControls/PlayBtn
@onready var fast_btn: Button = $UI/HUD/BottomBar/SpeedControls/FastBtn
@onready var speed_controls: HBoxContainer = $UI/HUD/BottomBar/SpeedControls

# New UI components
var top_hud_bar: TopHUDBar = null

# Legacy references (kept for compatibility, now managed by TopHUDBar)
var money_label: Label = null
var day_label: Label = null
var reputation_label: Label = null
var game_mode_label: Label = null
var build_mode_btn: Button = null
var selection_label: Label = null

var current_tool: int = -1  # Start with no tool selected
var brush_size: int = 1
var is_painting: bool = false
var last_paint_pos: Vector2i = Vector2i(-1, -1)

var hole_tool: HoleCreationTool = HoleCreationTool.new()
var placement_manager: PlacementManager = PlacementManager.new()
var undo_manager: UndoManager = UndoManager.new()
var wind_system: WindSystem = null
var weather_system: WeatherSystem = null
var rain_overlay: RainOverlay = null
var day_night_system: DayNightSystem = null
var elevation_tool: ElevationTool = ElevationTool.new()
var building_registry: Dictionary = {}
var entity_layer: EntityLayer = null
var building_info_panel: BuildingInfoPanel = null
var financial_panel: FinancialPanel = null
var staff_panel: StaffPanel = null
var mini_map: MiniMap = null
var hole_stats_panel: HoleStatsPanel = null
var tournament_manager: TournamentManager = null
var tournament_panel: TournamentPanel = null
var land_panel: LandPanel = null
var marketing_panel: MarketingPanel = null
var random_event_system: RandomEventSystem = null
var advisor_system: AdvisorSystem = null
var advisor_panel: AdvisorPanel = null
var awards_system: AwardsSystem = null
var awards_panel: AwardsPanel = null
var prestige_system: PrestigeSystem = null
var prestige_panel: PrestigePanel = null
var loyalty_system: LoyaltySystem = null
var loyalty_panel: LoyaltyPanel = null
var dynamic_pricing_system: DynamicPricingSystem = null
var pricing_panel: PricingPanel = null
var scenario_system: ScenarioSystem = null
var scenario_panel: ScenarioPanel = null
var scenario_objectives_hud: ScenarioObjectivesHUD = null
var hotkey_panel: HotkeyPanel = null
var weather_debug_panel: WeatherDebugPanel = null
var season_debug_panel: SeasonDebugPanel = null
var analytics_panel_ui: AnalyticsPanel = null
var golfer_info_popup: GolferInfoPopup = null
var round_summary_popup: RoundSummaryPopup = null
var tournament_leaderboard: TournamentLeaderboard = null
var pause_menu: PauseMenu = null
var milestone_manager: MilestoneManager = null
var milestones_panel: MilestonesPanel = null
var seasonal_calendar_panel: SeasonalCalendarPanel = null
var tutorial_system: TutorialSystem = null
var course_rating_overlay: CourseRatingOverlay = null
var shot_heatmap_tracker: ShotHeatmapTracker = null
var _active_panel: CenteredPanel = null  # Tracks the currently open panel to prevent stacking
var selected_tree_type: String = "oak"
var selected_rock_size: String = "medium"
var bulldozer_mode: bool = false
var _bulldoze_drag_count: int = 0
var _bulldoze_drag_cost: int = 0
var placement_preview: PlacementPreview = null
var main_menu: MainMenu = null

func _ready() -> void:
	# Set terrain grid reference in GameManager
	GameManager.terrain_grid = terrain_grid

	# Load buildings from JSON
	_load_buildings_data()

	entity_layer = EntityLayer.new()
	add_child(entity_layer)
	entity_layer.set_terrain_grid(terrain_grid)
	entity_layer.set_building_registry(building_registry)
	entity_layer.building_selected.connect(_on_building_clicked)
	GameManager.entity_layer = entity_layer

	# Create building info panel (added to UI layer later)
	building_info_panel = BuildingInfoPanel.new()
	building_info_panel.close_requested.connect(_on_building_panel_closed)

	# Set up ball manager
	ball_manager.set_terrain_grid(terrain_grid)

	# Set up hole manager
	hole_manager.set_terrain_grid(terrain_grid)

	# Add hole creation tool
	add_child(hole_tool)

	# Add undo manager
	add_child(undo_manager)
	terrain_grid.tile_changed.connect(_on_terrain_tile_changed_for_undo)

	# Set up wind system
	wind_system = WindSystem.new()
	wind_system.name = "WindSystem"
	add_child(wind_system)
	GameManager.wind_system = wind_system

	# Set up weather system
	weather_system = WeatherSystem.new()
	weather_system.name = "WeatherSystem"
	add_child(weather_system)
	GameManager.weather_system = weather_system

	# Add elevation tool
	add_child(elevation_tool)

	# Set up day/night cycle
	day_night_system = DayNightSystem.new()
	day_night_system.name = "DayNightSystem"
	add_child(day_night_system)

	# Set up tournament manager
	tournament_manager = TournamentManager.new()
	tournament_manager.name = "TournamentManager"
	add_child(tournament_manager)
	GameManager.tournament_manager = tournament_manager

	# Set up tournament leaderboard
	tournament_leaderboard = TournamentLeaderboard.new()
	tournament_leaderboard.name = "TournamentLeaderboard"
	$UI/HUD.add_child(tournament_leaderboard)
	tournament_manager.setup(golfer_manager, tournament_leaderboard)

	# Set up economy managers
	var land_mgr = LandManager.new()
	land_mgr.name = "LandManager"
	add_child(land_mgr)
	GameManager.land_manager = land_mgr

	var staff_mgr = StaffManager.new()
	staff_mgr.name = "StaffManager"
	add_child(staff_mgr)
	GameManager.staff_manager = staff_mgr

	var marketing_mgr = MarketingManager.new()
	marketing_mgr.name = "MarketingManager"
	add_child(marketing_mgr)
	GameManager.marketing_manager = marketing_mgr

	# Set up random event system
	random_event_system = RandomEventSystem.new()
	random_event_system.name = "RandomEventSystem"
	add_child(random_event_system)
	GameManager.random_event_system = random_event_system

	# Set up advisor system
	advisor_system = AdvisorSystem.new()
	advisor_system.name = "AdvisorSystem"
	add_child(advisor_system)
	GameManager.advisor_system = advisor_system

	# Set up awards system
	awards_system = AwardsSystem.new()
	awards_system.name = "AwardsSystem"
	add_child(awards_system)
	GameManager.awards_system = awards_system

	# Set up prestige system
	prestige_system = PrestigeSystem.new()
	prestige_system.name = "PrestigeSystem"
	add_child(prestige_system)
	GameManager.prestige_system = prestige_system

	# Set up loyalty system
	loyalty_system = LoyaltySystem.new()
	loyalty_system.name = "LoyaltySystem"
	add_child(loyalty_system)
	GameManager.loyalty_system = loyalty_system

	# Set up dynamic pricing system
	dynamic_pricing_system = DynamicPricingSystem.new()
	dynamic_pricing_system.name = "DynamicPricingSystem"
	add_child(dynamic_pricing_system)
	GameManager.dynamic_pricing_system = dynamic_pricing_system

	# Set up scenario system
	scenario_system = ScenarioSystem.new()
	GameManager.scenario_system = scenario_system

	# Set up save manager references
	SaveManager.set_references(terrain_grid, entity_layer, golfer_manager, ball_manager)

	_connect_signals()
	_connect_ui_buttons()
	_setup_top_hud_bar()
	_setup_rain_overlay()
	_setup_placement_preview()
	_create_selection_indicator()
	_create_save_load_button()
	_setup_building_info_panel()
	_setup_financial_panel()
	_setup_mini_map()
	_setup_hole_stats_panel()
	_setup_tournament_panel()
	_setup_land_panel()
	_setup_marketing_panel()
	_setup_hotkey_panel()
	_setup_weather_debug_panel()
	_setup_season_debug_panel()
	_setup_analytics_panel()
	_setup_golfer_info_popup()
	_setup_round_summary_popup()
	_setup_milestone_system()
	_setup_seasonal_calendar()
	_setup_autosave_indicator()
	_setup_notification_toast()
	_setup_advisor_panel()
	_setup_awards_panel()
	_setup_prestige_panel()
	_setup_loyalty_panel()
	_setup_pricing_panel()
	_setup_course_rating_overlay()
	_setup_floating_text()
	_setup_shot_trails()
	_setup_shot_heatmap()
	_setup_audio_controls()
	_setup_scenario_panel()
	_setup_scenario_objectives_hud()
	_initialize_game()
	print("Main scene ready")

func _load_buildings_data() -> void:
	"""Load buildings from buildings.json"""
	var file = FileAccess.open("res://data/buildings.json", FileAccess.READ)
	if file == null:
		push_error("Failed to load buildings.json")
		return
	
	var json_string = file.get_as_text()
	var data = JSON.parse_string(json_string)
	
	if data and data.has("buildings"):
		building_registry = data["buildings"]
		print("Loaded %d building types" % building_registry.size())
	else:
		push_error("Invalid buildings.json format")

func _process(_delta: float) -> void:
	_update_ui()
	_handle_mouse_hover()
	_update_mini_map_camera()
	_update_selection_indicator()

func _input(event: InputEvent) -> void:
	# Keyboard shortcuts - handled in _input so UI controls don't swallow them
	if event is InputEventKey and event.pressed and not event.echo:
		# Escape key: deselect active tool/panel first, then open pause menu
		if event.keycode == KEY_ESCAPE:
			if GameManager.current_mode != GameManager.GameMode.MAIN_MENU:
				# Close open panel first
				if _active_panel and _active_panel.visible:
					_active_panel.hide()
					_active_panel = null
					get_viewport().set_input_as_handled()
					return
				# Deselect active tool/selection — let _unhandled_input handle it
				if _has_active_tool():
					return
				# Nothing active — open pause menu
				_toggle_pause_menu()
				get_viewport().set_input_as_handled()
				return

		# Don't process any gameplay hotkeys while in main menu
		if GameManager.current_mode == GameManager.GameMode.MAIN_MENU:
			return

		# Don't process hotkeys while pause menu is open
		if pause_menu:
			return

		# Skip non-modifier hotkeys if a text input has focus
		var focused = get_viewport().gui_get_focus_owner()
		var text_input_focused = focused is LineEdit or focused is TextEdit

		# F1 help works in any mode (including main menu)
		if event.keycode == KEY_F1:
			_toggle_hotkey_panel()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_F2:
			_toggle_weather_debug_panel()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_F4:
			_toggle_season_debug_panel()
			get_viewport().set_input_as_handled()
			return

		if event.is_command_or_control_pressed():
			if event.keycode == KEY_S:
				SaveManager.save_game("quicksave")
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_Z and not event.shift_pressed:
				_perform_undo()
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_Z and event.shift_pressed:
				_perform_redo()
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_Y:
				_perform_redo()
				get_viewport().set_input_as_handled()
		elif not text_input_focused:
			# Only process single-key hotkeys when not typing in a text field
			if event.keycode == KEY_U:
				_toggle_tournament_panel()
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_L:
				_toggle_land_panel()
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_M:
				_toggle_marketing_panel()
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_Z:
				_toggle_analytics_panel()
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_G:
				_toggle_milestones_panel()
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_C:
				_toggle_seasonal_calendar()
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_A:
				_toggle_advisor_panel()
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_N:
				_toggle_awards_panel()
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_J:
				_toggle_prestige_panel()
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_D:
				_on_decoration_placement_pressed()
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_K:
				_toggle_loyalty_panel()
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_I:
				_toggle_pricing_panel()
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_F3:
				_toggle_terrain_debug_overlay()
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_V:
				if event.shift_pressed:
					if terrain_grid.is_shot_heatmap_enabled():
						terrain_grid.cycle_shot_heatmap_mode()
				else:
					terrain_grid.toggle_shot_heatmap()
				get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	# Cancel action (ESC/right-click) should always work to deselect tools
	if event.is_action_pressed("cancel"):
		_cancel_action()
		return

	# All tools work in both BUILDING and SIMULATING modes (tycoon-style)
	if GameManager.current_mode == GameManager.GameMode.MAIN_MENU:
		return

	if event.is_action_pressed("select"):
		_start_painting()
	elif event.is_action_released("select"):
		_stop_painting()
	if is_painting and event is InputEventMouseMotion:
		if elevation_tool.is_active():
			_paint_elevation_at_mouse()
		elif bulldozer_mode:
			_bulldoze_at_mouse()
		else:
			_paint_at_mouse()

func _connect_signals() -> void:
	EventBus.money_changed.connect(_on_money_changed)
	EventBus.day_changed.connect(_on_day_changed)
	EventBus.hole_created.connect(_on_hole_created)
	EventBus.hole_deleted.connect(_on_hole_deleted)
	EventBus.hole_toggled.connect(_on_hole_toggled)
	hole_tool.tee_added.connect(_on_tee_added)
	EventBus.end_of_day.connect(_on_end_of_day)
	EventBus.load_completed.connect(_on_load_completed)
	EventBus.new_game_started.connect(_on_new_game_started)

func _connect_ui_buttons() -> void:
	# Replace old tool panel with new terrain toolbar
	_setup_terrain_toolbar()

	$UI/HUD/BottomBar/SpeedControls/PauseBtn.pressed.connect(_on_speed_selected.bind(GameManager.GameSpeed.PAUSED))
	$UI/HUD/BottomBar/SpeedControls/PlayBtn.pressed.connect(_on_speed_selected.bind(GameManager.GameSpeed.NORMAL))
	$UI/HUD/BottomBar/SpeedControls/FastBtn.pressed.connect(_on_speed_selected.bind(GameManager.GameSpeed.FAST))

func _setup_terrain_toolbar() -> void:
	"""Replace old tool panel with organized terrain toolbar"""
	# Hide old tool panel children (keep container for positioning)
	for child in tool_panel_container.get_children():
		child.queue_free()

	# Ensure tool panel container expands
	tool_panel_container.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Create and add new toolbar
	terrain_toolbar = TerrainToolbar.new()
	terrain_toolbar.name = "TerrainToolbar"
	terrain_toolbar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	terrain_toolbar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tool_panel_container.add_child(terrain_toolbar)

	# Connect toolbar signals
	terrain_toolbar.tool_selected.connect(_on_tool_selected)
	terrain_toolbar.create_hole_pressed.connect(_on_create_hole_pressed)
	terrain_toolbar.tree_placement_pressed.connect(_on_tree_placement_pressed)
	terrain_toolbar.rock_placement_pressed.connect(_on_rock_placement_pressed)
	terrain_toolbar.building_placement_pressed.connect(_on_building_placement_pressed)
	terrain_toolbar.raise_elevation_pressed.connect(_on_raise_elevation_pressed)
	terrain_toolbar.lower_elevation_pressed.connect(_on_lower_elevation_pressed)
	terrain_toolbar.bulldozer_pressed.connect(_on_bulldozer_pressed)
	terrain_toolbar.staff_pressed.connect(_on_staff_pressed)
	terrain_toolbar.brush_size_changed.connect(_on_brush_size_changed)

func _initialize_game() -> void:
	# Show main menu instead of auto-starting
	_show_main_menu()

func _show_main_menu() -> void:
	main_menu = MainMenu.new()
	main_menu.name = "MainMenu"
	main_menu.new_game_requested.connect(_on_main_menu_new_game)
	main_menu.quick_start_requested.connect(_on_main_menu_quick_start)
	main_menu.load_game_requested.connect(_on_main_menu_load)
	main_menu.settings_requested.connect(_on_main_menu_settings)
	main_menu.credits_requested.connect(_on_main_menu_credits)
	main_menu.scenarios_requested.connect(_on_main_menu_scenarios)
	$UI/HUD.add_child(main_menu)
	# Hide gameplay UI while in menu
	_set_gameplay_ui_visible(false)

func _on_main_menu_new_game(course_name: String, theme_type: int) -> void:
	var difficulty := main_menu.get_selected_difficulty() if main_menu else DifficultyPresets.Preset.NORMAL
	if main_menu:
		main_menu.queue_free()
		main_menu = null
	_set_gameplay_ui_visible(true)

	GameManager.new_game(course_name, theme_type, difficulty)

	# Regenerate tileset with theme colors
	terrain_grid.regenerate_tileset()

	# Center camera on the middle of the grid
	var center_x = (terrain_grid.grid_width / 2) * terrain_grid.tile_width
	var center_y = (terrain_grid.grid_height / 2) * terrain_grid.tile_height
	camera.focus_on(Vector2(center_x, center_y), true)
	# Start with no tool selected — player chooses their first action
	current_tool = -1
	if terrain_toolbar:
		terrain_toolbar.clear_selection()
	if placement_preview:
		placement_preview.set_terrain_painting_enabled(false)

var _quick_start_pending: bool = false

func _on_main_menu_quick_start(course_name: String, theme_type: int) -> void:
	"""Start a new game with a pre-built 3-hole course."""
	var difficulty := main_menu.get_selected_difficulty() if main_menu else DifficultyPresets.Preset.NORMAL
	if main_menu:
		main_menu.queue_free()
		main_menu = null
	_set_gameplay_ui_visible(true)

	# Flag so _on_new_game_started knows to build the quick-start course
	_quick_start_pending = true
	GameManager.new_game(course_name, theme_type, difficulty)

	var center_x = (terrain_grid.grid_width / 2) * terrain_grid.tile_width
	var center_y = (terrain_grid.grid_height / 2) * terrain_grid.tile_height
	camera.focus_on(Vector2(center_x, center_y), true)
	current_tool = -1
	if terrain_toolbar:
		terrain_toolbar.clear_selection()
	if placement_preview:
		placement_preview.set_terrain_painting_enabled(false)

func _on_main_menu_load() -> void:
	# Show save/load panel overlaid on the main menu (don't dismiss menu yet)
	var hud = $UI/HUD
	var existing = hud.get_node_or_null("SaveLoadPanel")
	if existing:
		existing.queue_free()
		return

	var panel = SaveLoadPanel.new()
	panel.name = "SaveLoadPanel"
	panel.anchors_preset = Control.PRESET_CENTER
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)

	# When a save is loaded, dismiss the main menu
	panel.panel_closed.connect(_on_main_menu_load_panel_closed)
	panel.quit_to_menu_requested.connect(_on_quit_to_menu)
	hud.add_child(panel)

	# Connect load_completed to dismiss the menu on successful load
	if not EventBus.load_completed.is_connected(_on_main_menu_load_completed):
		EventBus.load_completed.connect(_on_main_menu_load_completed)

func _on_main_menu_settings() -> void:
	"""Show settings from main menu."""
	var settings = SettingsMenu.new()
	settings.name = "SettingsMenu"
	# No need to re-show anything when closing from main menu
	settings.close_requested.connect(func(): pass)
	$UI/HUD.add_child(settings)

func _on_main_menu_credits() -> void:
	"""Show credits screen from main menu."""
	var credits = CreditsScreen.new()
	credits.name = "CreditsScreen"
	credits.close_requested.connect(func(): pass)
	$UI/HUD.add_child(credits)

func _on_main_menu_scenarios() -> void:
	"""Show scenario selection panel from main menu."""
	if scenario_panel:
		scenario_panel.show_centered()

func _on_main_menu_load_panel_closed() -> void:
	"""Save/load panel closed without loading — return to main menu."""
	_disconnect_main_menu_load_signal()

func _on_main_menu_load_completed(success: bool) -> void:
	"""A save was loaded from the main menu — dismiss menu and show game."""
	_disconnect_main_menu_load_signal()
	if success and main_menu:
		main_menu.queue_free()
		main_menu = null
		_set_gameplay_ui_visible(true)

func _disconnect_main_menu_load_signal() -> void:
	if EventBus.load_completed.is_connected(_on_main_menu_load_completed):
		EventBus.load_completed.disconnect(_on_main_menu_load_completed)

func _set_gameplay_ui_visible(visible_flag: bool) -> void:
	# Toggle visibility of gameplay HUD elements
	# Exclude popup panels that should remain hidden until explicitly toggled
	var popup_panels = ["MainMenu", "PauseMenu", "GameOverPanel", "SettingsMenu", "MilestonesPanel", "SeasonalCalendarPanel", "TournamentPanel", "FinancialPanel", "StaffPanel", "HoleStatsPanel", "SaveLoadPanel", "BuildingInfoPanel", "LandPanel", "MarketingPanel", "HotkeyPanel", "WeatherDebugPanel", "SeasonDebugPanel", "AnalyticsPanel", "GolferInfoPopup", "TournamentLeaderboard", "CourseRatingOverlay", "AdvisorPanel", "AwardsPanel", "PrestigePanel"]
	var hud = $UI/HUD
	for child in hud.get_children():
		if child.name not in popup_panels:
			child.visible = visible_flag

func _setup_top_hud_bar() -> void:
	"""Replace old TopBar with new TopHUDBar component"""
	var old_top_bar = $UI/HUD/TopBar
	var hud = $UI/HUD

	# Remove old top bar children
	for child in old_top_bar.get_children():
		child.queue_free()
	old_top_bar.queue_free()

	# Create new TopHUDBar
	top_hud_bar = TopHUDBar.new()
	top_hud_bar.name = "TopHUDBar"

	# Set anchors to top, full width
	top_hud_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_hud_bar.offset_bottom = UIConstants.TOP_HUD_HEIGHT

	# Connect top bar clicks to panels
	top_hud_bar.money_clicked.connect(_on_money_clicked)
	top_hud_bar.rating_clicked.connect(_toggle_course_rating_panel)

	# Add to HUD as first child
	hud.add_child(top_hud_bar)
	hud.move_child(top_hud_bar, 0)

	# Create mode toggle button (Start Day / Stop & Edit)
	build_mode_btn = Button.new()
	build_mode_btn.name = "ModeToggleBtn"
	build_mode_btn.text = "Start Day"
	build_mode_btn.custom_minimum_size = Vector2(120, 34)
	build_mode_btn.pressed.connect(_on_mode_toggle_pressed)
	speed_controls.add_child(build_mode_btn)
	speed_controls.move_child(build_mode_btn, 0)

func _setup_rain_overlay() -> void:
	rain_overlay = RainOverlay.new()
	rain_overlay.name = "RainOverlay"
	# Use a CanvasLayer so rain renders in screen space (not world space)
	# This way rain stays visible regardless of camera position/zoom
	var rain_canvas := CanvasLayer.new()
	rain_canvas.name = "RainCanvas"
	rain_canvas.layer = 90  # Above game world, below UI
	add_child(rain_canvas)
	rain_canvas.add_child(rain_overlay)
	if weather_system:
		rain_overlay.setup(weather_system)

func _setup_placement_preview() -> void:
	"""Create placement preview overlay for building/tree/rock placement"""
	placement_preview = PlacementPreview.new()
	placement_preview.name = "PlacementPreview"
	placement_preview.set_terrain_grid(terrain_grid)
	placement_preview.set_placement_manager(placement_manager)
	placement_preview.set_camera(camera)
	placement_preview.set_hole_tool(hole_tool)
	# Add as child of main scene so it renders above terrain
	add_child(placement_preview)

func _create_selection_indicator() -> void:
	"""Create a label showing the currently selected tool/placement mode."""
	var bottom_bar = $UI/HUD/BottomBar

	# Create container with background
	var container = PanelContainer.new()
	container.name = "SelectionIndicator"

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_bottom", 2)
	container.add_child(margin)

	selection_label = Label.new()
	selection_label.name = "SelectionLabel"
	selection_label.text = "Selected: Fairway"
	selection_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))  # Yellow-ish
	margin.add_child(selection_label)

	# Insert before the coordinate label (which is at the end)
	bottom_bar.add_child(container)
	var coord_index = coordinate_label.get_index()
	bottom_bar.move_child(container, coord_index)

func _update_selection_indicator() -> void:
	"""Update the selection indicator based on current mode."""
	if not selection_label:
		return

	var text = "Selected: "
	var color = Color(1.0, 0.9, 0.5)  # Default yellow

	# Check null selector state first
	if not _has_active_tool():
		text += "None (press a tool key to select)"
		color = Color(0.6, 0.6, 0.6)  # Gray
		selection_label.text = text
		selection_label.add_theme_color_override("font_color", color)
		return

	# Check placement modes first (they take priority)
	if hole_tool.placement_mode == HoleCreationTool.PlacementMode.PLACING_TEE:
		text += "Place Tee Box"
		color = Color(0.5, 1.0, 0.5)  # Green
	elif hole_tool.placement_mode == HoleCreationTool.PlacementMode.PLACING_GREEN:
		text += "Place Green"
		color = Color(0.5, 1.0, 0.5)  # Green
	elif hole_tool.placement_mode == HoleCreationTool.PlacementMode.PLACING_FORWARD_TEE:
		text += "Place Forward Tee"
		color = Color(0.9, 0.4, 0.4)  # Red
	elif hole_tool.placement_mode == HoleCreationTool.PlacementMode.PLACING_BACK_TEE:
		text += "Place Back Tee"
		color = Color(0.3, 0.4, 0.9)  # Blue
	elif placement_manager.placement_mode == PlacementManager.PlacementMode.TREE:
		text += "Tree (%s)" % selected_tree_type.capitalize()
		color = Color(0.4, 0.8, 0.4)  # Forest green
	elif placement_manager.placement_mode == PlacementManager.PlacementMode.ROCK:
		text += "Rock (%s)" % selected_rock_size.capitalize()
		color = Color(0.7, 0.7, 0.7)  # Gray
	elif placement_manager.placement_mode == PlacementManager.PlacementMode.BUILDING:
		var building_name = placement_manager.selected_building_type.capitalize().replace("_", " ")
		text += "Building (%s)" % building_name
		color = Color(0.8, 0.6, 0.4)  # Brown
	elif bulldozer_mode:
		text += "Bulldozer"
		color = Color(1.0, 0.5, 0.3)  # Orange
	elif elevation_tool.is_active():
		if elevation_tool.elevation_mode == ElevationTool.ElevationMode.RAISING:
			text += "Raise Elevation"
			color = Color(0.6, 0.8, 1.0)  # Light blue
		else:
			text += "Lower Elevation"
			color = Color(1.0, 0.6, 0.6)  # Light red
	else:
		# Default to terrain tool
		text += TerrainTypes.get_type_name(current_tool)
		# Color based on terrain type
		match current_tool:
			TerrainTypes.Type.FAIRWAY, TerrainTypes.Type.GREEN, TerrainTypes.Type.TEE_BOX:
				color = Color(0.5, 0.9, 0.5)  # Green
			TerrainTypes.Type.ROUGH:
				color = Color(0.6, 0.8, 0.4)  # Darker green
			TerrainTypes.Type.BUNKER:
				color = Color(0.9, 0.85, 0.6)  # Sand
			TerrainTypes.Type.WATER:
				color = Color(0.4, 0.6, 1.0)  # Blue
			TerrainTypes.Type.PATH:
				color = Color(0.7, 0.7, 0.7)  # Gray
			TerrainTypes.Type.OUT_OF_BOUNDS:
				color = Color(0.9, 0.4, 0.4)  # Red
			TerrainTypes.Type.FLOWER_BED:
				color = Color(0.9, 0.5, 0.7)  # Pink

	selection_label.text = text
	selection_label.add_theme_color_override("font_color", color)

func _toggle_panel(panel: CenteredPanel) -> void:
	"""Toggle a panel with mutual exclusion — opening one closes the previous."""
	if panel == _active_panel and panel.visible:
		panel.hide()
		_active_panel = null
		return
	# Close the currently open panel (if different)
	if _active_panel and _active_panel != panel and _active_panel.visible:
		_active_panel.hide()
	_active_panel = panel
	panel.toggle()

func _on_mode_toggle_pressed() -> void:
	"""Start the day or end it early."""
	if GameManager.current_mode == GameManager.GameMode.BUILDING:
		# Start simulation
		if GameManager.start_simulation():
			# Don't spawn regular golfers during a tournament
			if not tournament_manager.is_tournament_in_progress():
				golfer_manager.spawn_initial_group()
	elif GameManager.current_mode == GameManager.GameMode.SIMULATING:
		# End the day early
		if tournament_manager.is_tournament_in_progress():
			tournament_manager.simulate_remaining_and_complete()
		GameManager.force_end_day()

func _update_ui() -> void:
	# TopHUDBar now handles money/day/reputation/weather/wind updates via signals
	# Only update button states here
	_update_button_states()

func _update_button_states() -> void:
	"""Update button appearance based on game mode and speed"""
	# Speed controls are always visible — tycoon-style, build while playing
	pause_btn.visible = true
	play_btn.visible = true
	fast_btn.visible = true
	pause_btn.disabled = false
	play_btn.disabled = false
	fast_btn.disabled = false
	play_btn.text = ">"
	pause_btn.text = "||"
	fast_btn.text = ">>"

	if build_mode_btn:
		build_mode_btn.visible = true
		if GameManager.current_mode == GameManager.GameMode.BUILDING:
			build_mode_btn.text = "Start Day"
			build_mode_btn.modulate = Color(0.5, 1.0, 0.5)  # Green tint
		else:
			build_mode_btn.text = "End Day"
			build_mode_btn.modulate = Color(1.0, 0.8, 0.4)  # Orange tint

	# Highlight active speed button
	pause_btn.modulate = Color(1, 1, 1, 0.5) if GameManager.current_speed != GameManager.GameSpeed.PAUSED else Color(1, 1, 1, 1)
	play_btn.modulate = Color(1, 1, 1, 0.5) if GameManager.current_speed != GameManager.GameSpeed.NORMAL else Color(1, 1, 1, 1)
	fast_btn.modulate = Color(1, 1, 1, 0.5) if GameManager.current_speed != GameManager.GameSpeed.FAST else Color(1, 1, 1, 1)

func _handle_mouse_hover() -> void:
	# Only show coordinates when a tool is active (reduces clutter)
	if not _has_active_tool():
		coordinate_label.text = ""
		return

	var mouse_world = camera.get_mouse_world_position()
	var grid_pos = terrain_grid.screen_to_grid(mouse_world)
	if terrain_grid.is_valid_position(grid_pos):
		var terrain_name = TerrainTypes.get_type_name(terrain_grid.get_tile(grid_pos))
		var elevation = terrain_grid.get_elevation(grid_pos)
		if elevation != 0:
			var sign_str = "+" if elevation > 0 else ""
			coordinate_label.text = "(%d, %d) %s [Elev: %s%d]" % [grid_pos.x, grid_pos.y, terrain_name, sign_str, elevation]
		else:
			coordinate_label.text = "(%d, %d) %s" % [grid_pos.x, grid_pos.y, terrain_name]
	else:
		coordinate_label.text = ""

func _start_painting() -> void:
	# Check if in null selector state - do nothing, allow clicking buildings/UI
	if not _has_active_tool():
		return

	# Check if we're in bulldozer mode — supports click-and-drag
	if bulldozer_mode:
		is_painting = true
		_bulldoze_drag_count = 0
		_bulldoze_drag_cost = 0
		_bulldoze_at_mouse()
		return

	# Check if we're in placement mode (building or tree)
	if placement_manager.placement_mode != PlacementManager.PlacementMode.NONE:
		var mouse_world = camera.get_mouse_world_position()
		var grid_pos = terrain_grid.screen_to_grid(mouse_world)
		_handle_placement_click(grid_pos)
		return

	# Check if we're in hole placement mode
	if hole_tool.placement_mode != HoleCreationTool.PlacementMode.NONE:
		var mouse_world = camera.get_mouse_world_position()
		var grid_pos = terrain_grid.screen_to_grid(mouse_world)
		# Group all tee/green tiles into a single undo action
		undo_manager.begin_stroke()
		hole_tool.handle_click(grid_pos)
		undo_manager.end_stroke()
		return

	# Check if we're in elevation painting mode
	if elevation_tool.is_active():
		is_painting = true
		_paint_elevation_at_mouse()
		return

	is_painting = true
	undo_manager.begin_stroke()
	_paint_at_mouse()

func _stop_painting() -> void:
	# Show bulldozer drag summary if items were cleared
	if bulldozer_mode and _bulldoze_drag_count > 0:
		EventBus.notify("Cleared %d item%s (-$%d)" % [_bulldoze_drag_count, "s" if _bulldoze_drag_count != 1 else "", _bulldoze_drag_cost], "info")
	is_painting = false
	last_paint_pos = Vector2i(-1, -1)
	if not elevation_tool.is_active():
		undo_manager.end_stroke()

func _paint_at_mouse() -> void:
	var mouse_world = camera.get_mouse_world_position()
	var grid_pos = terrain_grid.screen_to_grid(mouse_world)
	if grid_pos == last_paint_pos: return
	last_paint_pos = grid_pos
	if not terrain_grid.is_valid_position(grid_pos): return
	
	var cost = TerrainTypes.get_placement_cost(current_tool)
	if cost > 0 and not GameManager.can_afford(cost):
		if GameManager.is_bankrupt():
			EventBus.notify("Spending blocked! Balance below -$1,000", "error")
		else:
			EventBus.notify("Not enough money!", "error")
		return

	var tiles_to_paint = [grid_pos] if brush_size <= 1 else terrain_grid.get_brush_tiles(grid_pos, brush_size)
	var total_cost = 0
	var obstacle_removal_cost = 0
	var blocked_by_land = false
	# Terrain types that auto-remove trees and rocks when placed
	var clears_obstacles = current_tool in [
		TerrainTypes.Type.FAIRWAY, TerrainTypes.Type.BUNKER, TerrainTypes.Type.WATER,
		TerrainTypes.Type.TEE_BOX, TerrainTypes.Type.GREEN
	]
	for tile_pos in tiles_to_paint:
		# Check land ownership first
		if GameManager.land_manager and not GameManager.land_manager.is_tile_owned(tile_pos):
			blocked_by_land = true
			continue
		# Skip tiles occupied by buildings
		if entity_layer and entity_layer.is_tile_occupied_by_building(tile_pos):
			continue
		if terrain_grid.get_tile(tile_pos) != current_tool:
			# Auto-remove trees, rocks, and decorations when placing course terrain
			var tile_removal_cost = 0
			if clears_obstacles and entity_layer:
				if entity_layer.get_tree_at(tile_pos):
					tile_removal_cost += BULLDOZER_COSTS["tree"]
				if entity_layer.get_rock_at(tile_pos):
					tile_removal_cost += BULLDOZER_COSTS["rock"]
				if entity_layer.get_decoration_at(tile_pos):
					tile_removal_cost += BULLDOZER_COSTS["decoration"]
			# Check affordability including removal costs
			var tile_total = cost + tile_removal_cost
			if tile_total > 0 and not GameManager.can_afford(total_cost + obstacle_removal_cost + tile_total):
				continue
			# Perform removals
			if tile_removal_cost > 0:
				if entity_layer.get_tree_at(tile_pos):
					entity_layer.remove_tree(tile_pos)
				if entity_layer.get_rock_at(tile_pos):
					entity_layer.remove_rock(tile_pos)
				if entity_layer.get_decoration_at(tile_pos):
					entity_layer.remove_decoration(tile_pos)
				obstacle_removal_cost += tile_removal_cost
			terrain_grid.set_tile(tile_pos, current_tool)
			total_cost += cost

	if blocked_by_land and total_cost == 0:
		EventBus.notify("You don't own this land! Press L to buy parcels.", "error")

	if obstacle_removal_cost > 0:
		GameManager.modify_money(-obstacle_removal_cost)
		EventBus.log_transaction("Clear obstacles", -obstacle_removal_cost)
	if total_cost > 0:
		GameManager.modify_money(-total_cost)
		EventBus.log_transaction("Terrain: " + TerrainTypes.get_type_name(current_tool), -total_cost)

func _cancel_action() -> void:
	is_painting = false
	last_paint_pos = Vector2i(-1, -1)

	# Two-tier cancel: first ESC cancels the active operation, second deselects tool
	var had_active_operation = false

	if bulldozer_mode:
		_cancel_bulldozer_mode()
		had_active_operation = true
	if elevation_tool.is_active():
		_cancel_elevation_mode()
		had_active_operation = true
	if placement_manager.placement_mode != PlacementManager.PlacementMode.NONE:
		placement_manager.cancel_placement()
		had_active_operation = true
	if hole_tool.placement_mode != HoleCreationTool.PlacementMode.NONE:
		hole_tool.cancel_placement()
		had_active_operation = true

	if had_active_operation:
		# First ESC: cancelled the active operation, keep terrain tool selected
		return

	# Second ESC (or no active operation): deselect terrain tool entirely
	if terrain_toolbar and terrain_toolbar.has_selection():
		terrain_toolbar.clear_selection()
		_disable_terrain_painting_preview()
		return

func _has_active_tool() -> bool:
	"""Check if any tool is currently active (not in null selector state)"""
	if bulldozer_mode:
		return true
	if elevation_tool.is_active():
		return true
	if placement_manager.placement_mode != PlacementManager.PlacementMode.NONE:
		return true
	if hole_tool.placement_mode != HoleCreationTool.PlacementMode.NONE:
		return true
	if terrain_toolbar and terrain_toolbar.has_selection():
		return true
	return false

func _on_tool_selected(tool_type: int) -> void:
	# Cancel any hole placement, building/tree placement, elevation mode, and bulldozer mode
	hole_tool.cancel_placement()
	placement_manager.cancel_placement()
	_cancel_elevation_mode()
	_cancel_bulldozer_mode()
	is_painting = false

	current_tool = tool_type
	# Update toolbar highlight
	if terrain_toolbar:
		terrain_toolbar.set_current_tool(tool_type)
	# Update placement preview for terrain painting
	if placement_preview:
		placement_preview.set_terrain_tool(tool_type)
		placement_preview.set_terrain_painting_enabled(true)
	print("Tool selected: " + TerrainTypes.get_type_name(tool_type))

func _on_brush_size_changed(new_size: int) -> void:
	brush_size = new_size

func _on_create_hole_pressed() -> void:
	# Cancel any building/tree placement, elevation, bulldozer, or terrain painting
	placement_manager.cancel_placement()
	_cancel_elevation_mode()
	_cancel_bulldozer_mode()
	_disable_terrain_painting_preview()
	is_painting = false
	if terrain_toolbar:
		terrain_toolbar.clear_selection()
	hole_tool.start_tee_placement()

func _on_speed_selected(speed: int) -> void:
	# Speed buttons only work during simulation
	if GameManager.current_mode != GameManager.GameMode.SIMULATING:
		return

	GameManager.set_speed(speed)

var _game_over_shown: bool = false

func _on_money_changed(_old: int, _new: int) -> void:
	# Check for bankruptcy game over
	if GameManager.is_bankrupt() and not _game_over_shown:
		_show_game_over()

func _on_day_changed(_new_day: int) -> void:
	# Operating costs are now calculated at end of day before summary
	pass

func _on_hole_created(hole_number: int, par: int, distance_yards: int) -> void:
	var row = HBoxContainer.new()
	row.name = "HoleRow%d" % hole_number

	# Make hole label a clickable button
	var hole_btn = Button.new()
	hole_btn.name = "HoleBtn"
	hole_btn.text = "Hole %d: Par %d (%d yds)" % [hole_number, par, distance_yards]
	hole_btn.flat = true
	hole_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	hole_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hole_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hole_btn.tooltip_text = "Click to view statistics"
	hole_btn.pressed.connect(_show_hole_stats.bind(hole_number))
	row.add_child(hole_btn)

	# Tees button — manage forward/back tees
	var tees_btn = Button.new()
	tees_btn.name = "TeesBtn"
	tees_btn.text = "Tees"
	tees_btn.custom_minimum_size = Vector2(42, 0)
	tees_btn.tooltip_text = "Add forward/back tee boxes"
	tees_btn.pressed.connect(_on_tees_pressed.bind(hole_number))
	row.add_child(tees_btn)

	var toggle_btn = Button.new()
	toggle_btn.name = "ToggleBtn"
	toggle_btn.text = "Open"
	toggle_btn.custom_minimum_size = Vector2(55, 0)
	toggle_btn.pressed.connect(_on_hole_toggle_pressed.bind(hole_number))
	row.add_child(toggle_btn)

	var delete_btn = Button.new()
	delete_btn.name = "DeleteBtn"
	delete_btn.text = "X"
	delete_btn.custom_minimum_size = Vector2(30, 0)
	delete_btn.pressed.connect(_on_hole_delete_pressed.bind(hole_number))
	row.add_child(delete_btn)

	hole_list.add_child(row)

	# Update tees button label if extra tees exist
	_update_tees_button(hole_number)

func _on_tee_added(hole_number: int, _tee_type: String) -> void:
	_update_tees_button(hole_number)

func _on_hole_toggle_pressed(hole_number: int) -> void:
	if not GameManager.current_course:
		return
	var is_open = GameManager.current_course.toggle_hole_open(hole_number)
	var status = "opened" if is_open else "closed"
	EventBus.notify("Hole %d %s" % [hole_number, status], "info")

func _on_hole_delete_pressed(hole_number: int) -> void:
	# Don't allow deletion during simulation
	if GameManager.current_mode == GameManager.GameMode.SIMULATING:
		EventBus.notify("Cannot delete holes while playing!", "error")
		return
	hole_tool.delete_hole(hole_number)

func _on_hole_deleted(hole_number: int) -> void:
	# Remove the hole row from the UI
	var row_name = "HoleRow%d" % hole_number
	if hole_list.has_node(row_name):
		hole_list.get_node(row_name).queue_free()
	# Rebuild the hole list to reflect renumbered holes
	_rebuild_hole_list()

func _on_hole_toggled(hole_number: int, is_open: bool) -> void:
	var row_name = "HoleRow%d" % hole_number
	if hole_list.has_node(row_name):
		var row = hole_list.get_node(row_name)
		var toggle_btn = row.get_node("ToggleBtn") as Button
		var hole_btn = row.get_node("HoleBtn") as Button
		if toggle_btn:
			toggle_btn.text = "Open" if is_open else "Closed"
			toggle_btn.modulate = Color(1, 1, 1) if is_open else Color(0.6, 0.6, 0.6)
		if hole_btn:
			hole_btn.modulate = Color(1, 1, 1) if is_open else Color(0.5, 0.5, 0.5)

func _rebuild_hole_list() -> void:
	# Clear existing hole rows
	for child in hole_list.get_children():
		child.queue_free()
	# Re-add from course data
	if GameManager.current_course:
		for hole in GameManager.current_course.holes:
			_on_hole_created(hole.hole_number, hole.par, hole.distance_yards)
			# Re-apply closed state
			if not hole.is_open:
				_on_hole_toggled(hole.hole_number, false)

var _tee_dialog: AcceptDialog = null

func _on_tees_pressed(hole_number: int) -> void:
	"""Show tee management dialog for a hole."""
	if GameManager.current_mode == GameManager.GameMode.SIMULATING:
		EventBus.notify("Cannot modify tees while playing!", "error")
		return

	if not GameManager.current_course:
		return

	var hole: GameManager.HoleData = null
	var hole_index: int = -1
	for i in range(GameManager.current_course.holes.size()):
		if GameManager.current_course.holes[i].hole_number == hole_number:
			hole = GameManager.current_course.holes[i]
			hole_index = i
			break
	if not hole:
		return

	# Clean up any existing dialog
	if _tee_dialog and is_instance_valid(_tee_dialog):
		_tee_dialog.queue_free()
		_tee_dialog = null

	_tee_dialog = AcceptDialog.new()
	_tee_dialog.title = "Tee Boxes — Hole %d" % hole_number
	_tee_dialog.size = Vector2i(360, 280)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	# Current tees status
	var status_label = Label.new()
	var middle_yds = hole.distance_yards
	status_label.text = "Middle Tee: %d yards (Par %d)" % [middle_yds, hole.par]
	vbox.add_child(status_label)

	# Forward tee
	var fwd_row = HBoxContainer.new()
	fwd_row.add_theme_constant_override("separation", 8)
	if hole.has_forward_tee():
		var fwd_dist = terrain_grid.calculate_distance_yards(hole.forward_tee, hole.green_position) if terrain_grid else 0
		var fwd_label = Label.new()
		fwd_label.text = "Forward Tee: %d yards" % fwd_dist
		fwd_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fwd_row.add_child(fwd_label)
		var remove_fwd = Button.new()
		remove_fwd.text = "Remove"
		remove_fwd.pressed.connect(func():
			hole_tool.remove_extra_tee(hole_number, "forward")
			_update_tees_button(hole_number)
			_tee_dialog.queue_free()
			_tee_dialog = null
		)
		fwd_row.add_child(remove_fwd)
	else:
		var fwd_label = Label.new()
		fwd_label.text = "Forward Tee: Not set"
		fwd_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fwd_row.add_child(fwd_label)
		var add_fwd = Button.new()
		add_fwd.text = "Place Forward Tee"
		add_fwd.pressed.connect(func():
			_tee_dialog.queue_free()
			_tee_dialog = null
			_cancel_all_modes()
			hole_tool.start_forward_tee_placement(hole_index)
		)
		fwd_row.add_child(add_fwd)
	vbox.add_child(fwd_row)

	# Back tee
	var back_row = HBoxContainer.new()
	back_row.add_theme_constant_override("separation", 8)
	if hole.has_back_tee():
		var back_dist = terrain_grid.calculate_distance_yards(hole.back_tee, hole.green_position) if terrain_grid else 0
		var back_label = Label.new()
		back_label.text = "Back Tee: %d yards" % back_dist
		back_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		back_row.add_child(back_label)
		var remove_back = Button.new()
		remove_back.text = "Remove"
		remove_back.pressed.connect(func():
			hole_tool.remove_extra_tee(hole_number, "back")
			_update_tees_button(hole_number)
			_tee_dialog.queue_free()
			_tee_dialog = null
		)
		back_row.add_child(remove_back)
	else:
		var back_label = Label.new()
		back_label.text = "Back Tee: Not set"
		back_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		back_row.add_child(back_label)
		var add_back = Button.new()
		add_back.text = "Place Back Tee"
		add_back.pressed.connect(func():
			_tee_dialog.queue_free()
			_tee_dialog = null
			_cancel_all_modes()
			hole_tool.start_back_tee_placement(hole_index)
		)
		back_row.add_child(add_back)
	vbox.add_child(back_row)

	vbox.add_child(HSeparator.new())

	# Explanation
	var help_label = Label.new()
	help_label.text = "Forward tees: shorter distance for beginners.\nBack tees: longer distance for pros & tournaments.\nGolfers auto-select tee based on skill tier."
	help_label.add_theme_font_size_override("font_size", 12)
	help_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(help_label)

	_tee_dialog.add_child(vbox)
	_tee_dialog.canceled.connect(func():
		_tee_dialog.queue_free()
		_tee_dialog = null
	)

	add_child(_tee_dialog)
	_tee_dialog.popup_centered()

func _update_tees_button(hole_number: int) -> void:
	"""Update the tees button label to show tee count."""
	var row_name = "HoleRow%d" % hole_number
	if not hole_list.has_node(row_name):
		return
	var row = hole_list.get_node(row_name)
	var tees_btn = row.get_node_or_null("TeesBtn")
	if not tees_btn:
		return
	# Find the hole data
	if not GameManager.current_course:
		return
	for hole in GameManager.current_course.holes:
		if hole.hole_number == hole_number:
			var count = hole.get_tee_count()
			if count > 1:
				tees_btn.text = "Tees(%d)" % count
			else:
				tees_btn.text = "Tees"
			break

func _cancel_all_modes() -> void:
	"""Cancel all active placement/painting modes."""
	hole_tool.cancel_placement()
	placement_manager.cancel_placement()
	_cancel_elevation_mode()
	_cancel_bulldozer_mode()
	_disable_terrain_painting_preview()
	is_painting = false
	if terrain_toolbar:
		terrain_toolbar.clear_selection()

func _on_tree_placement_pressed() -> void:
	"""Show tree selection menu and start tree placement mode"""
	hole_tool.cancel_placement()
	_cancel_elevation_mode()
	_cancel_bulldozer_mode()
	_disable_terrain_painting_preview()
	is_painting = false
	if terrain_toolbar:
		terrain_toolbar.clear_selection()

	# Create tree selection dialog
	var dialog = AcceptDialog.new()
	dialog.title = "Select Tree Type"
	dialog.size = Vector2i(350, 50 + CourseTheme.get_tree_types(GameManager.current_theme).size() * 50)

	var vbox = VBoxContainer.new()

	# Add button for each tree type available in the current theme
	var theme_trees = CourseTheme.get_tree_types(GameManager.current_theme)
	for tree_type in theme_trees:
		var tree_data = TreeEntity.TREE_PROPERTIES.get(tree_type, {})
		var btn = Button.new()
		btn.text = "%s ($%d)" % [tree_data.get("name", tree_type.capitalize()), tree_data.get("cost", 20)]
		btn.custom_minimum_size = Vector2(300, 40)
		btn.pressed.connect(_on_tree_type_selected.bind(tree_type, dialog))
		vbox.add_child(btn)

	dialog.add_child(vbox)
	get_tree().root.add_child(dialog)
	dialog.popup_centered_ratio(0.3)

func _on_building_placement_pressed() -> void:
	"""Show building selection menu and start building placement"""
	print("Building button pressed!")
	hole_tool.cancel_placement()
	_cancel_elevation_mode()
	_cancel_bulldozer_mode()
	_disable_terrain_painting_preview()
	is_painting = false
	if terrain_toolbar:
		terrain_toolbar.clear_selection()

	if building_registry.is_empty():
		print("ERROR: Building registry is empty!")
		EventBus.notify("Building system not initialized!", "error")
		return
	
	# Get building names from dictionary
	var building_names = building_registry.keys()
	print("Available buildings: ", building_names)
	if building_names.is_empty():
		EventBus.notify("No buildings available!", "error")
		return
	
	# Create a simple dialog with building options
	var dialog = AcceptDialog.new()
	dialog.title = "Select Building"
	dialog.size = Vector2i(400, 300)
	
	# Create scroll container for many buildings
	var scroll = ScrollContainer.new()
	var vbox = VBoxContainer.new()
	
	for building_type in building_names:
		var building_data = building_registry[building_type]
		var name_text = building_data.get("name", building_type)
		var cost = building_data.get("cost", 0)

		var btn = Button.new()
		btn.text = "%s ($%d)" % [name_text, cost]
		btn.custom_minimum_size = Vector2(350, 30)

		# Disable button for unique buildings that are already placed
		var is_unique = building_data.get("required", false)
		if is_unique and entity_layer.has_building_of_type(building_type):
			btn.disabled = true
			btn.text = "%s (Already placed)" % name_text
		else:
			btn.pressed.connect(_on_building_type_selected.bind(building_type, dialog))

		vbox.add_child(btn)
	
	scroll.add_child(vbox)
	dialog.add_child(scroll)
	get_tree().root.add_child(dialog)
	dialog.popup_centered_ratio(0.4)

func _on_building_type_selected(building_type: String, dialog: AcceptDialog) -> void:
	"""Handle building type selection"""
	print("Selected building: %s" % building_type)
	dialog.queue_free()

	if building_type in building_registry:
		var building_data = building_registry[building_type]
		placement_manager.start_building_placement(building_type, building_data)
		print("Building placement mode: %s" % building_type)
	else:
		print("ERROR: Building type not found: %s" % building_type)

func _on_tree_type_selected(tree_type: String, dialog: AcceptDialog) -> void:
	"""Handle tree type selection"""
	print("Selected tree: %s" % tree_type)
	dialog.queue_free()
	selected_tree_type = tree_type
	placement_manager.start_tree_placement(tree_type)
	print("Tree placement mode: %s" % tree_type)

func _on_rock_placement_pressed() -> void:
	"""Show rock size selection menu and start rock placement mode"""
	hole_tool.cancel_placement()
	_cancel_elevation_mode()
	_cancel_bulldozer_mode()
	_disable_terrain_painting_preview()
	is_painting = false
	if terrain_toolbar:
		terrain_toolbar.clear_selection()

	# Create rock selection dialog
	var dialog = AcceptDialog.new()
	dialog.title = "Select Rock Size"
	dialog.size = Vector2i(350, 200)

	var vbox = VBoxContainer.new()

	# Add button for each rock size
	var rock_sizes = {
		"small": {"name": "Small Rock", "cost": 10},
		"medium": {"name": "Medium Rock", "cost": 15},
		"large": {"name": "Large Rock", "cost": 20}
	}

	for rock_size in rock_sizes.keys():
		var rock_data = rock_sizes[rock_size]
		var btn = Button.new()
		btn.text = "%s ($%d)" % [rock_data["name"], rock_data["cost"]]
		btn.custom_minimum_size = Vector2(300, 40)
		btn.pressed.connect(_on_rock_size_selected.bind(rock_size, dialog))
		vbox.add_child(btn)

	dialog.add_child(vbox)
	get_tree().root.add_child(dialog)
	dialog.popup_centered_ratio(0.3)

func _on_rock_size_selected(rock_size: String, dialog: AcceptDialog) -> void:
	"""Handle rock size selection"""
	print("Selected rock size: %s" % rock_size)
	dialog.queue_free()
	selected_rock_size = rock_size
	placement_manager.start_rock_placement(rock_size)
	print("Rock placement mode: %s" % rock_size)

func _on_decoration_placement_pressed() -> void:
	"""Show decoration selection menu and start decoration placement mode"""
	hole_tool.cancel_placement()
	_cancel_elevation_mode()
	_cancel_bulldozer_mode()
	_disable_terrain_painting_preview()
	is_painting = false
	if terrain_toolbar:
		terrain_toolbar.clear_selection()

	var dialog = AcceptDialog.new()
	dialog.title = "Select Decoration"

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(350, 300)
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var theme_decos = Decoration.get_theme_decorations(GameManager.current_theme)
	for deco_type in theme_decos:
		var deco_data = Decoration.DECORATION_PROPERTIES.get(deco_type, {})
		var btn = Button.new()
		btn.text = "%s ($%d)" % [deco_data.get("name", deco_type.capitalize()), deco_data.get("cost", 100)]
		btn.custom_minimum_size = Vector2(300, 36)
		btn.pressed.connect(_on_decoration_type_selected.bind(deco_type, dialog))
		vbox.add_child(btn)

	scroll.add_child(vbox)
	dialog.add_child(scroll)
	dialog.size = Vector2i(400, 350)
	get_tree().root.add_child(dialog)
	dialog.popup_centered_ratio(0.35)

func _on_decoration_type_selected(deco_type: String, dialog: AcceptDialog) -> void:
	"""Handle decoration type selection"""
	dialog.queue_free()
	placement_manager.start_decoration_placement(deco_type)

func _on_raise_elevation_pressed() -> void:
	hole_tool.cancel_placement()
	placement_manager.cancel_placement()
	_cancel_bulldozer_mode()
	_disable_terrain_painting_preview()
	is_painting = false
	if terrain_toolbar:
		terrain_toolbar.clear_selection()
	elevation_tool.start_raising()
	terrain_grid.set_elevation_overlay_active(true)
	print("Elevation mode: RAISING")

func _on_lower_elevation_pressed() -> void:
	hole_tool.cancel_placement()
	placement_manager.cancel_placement()
	_cancel_bulldozer_mode()
	_disable_terrain_painting_preview()
	is_painting = false
	if terrain_toolbar:
		terrain_toolbar.clear_selection()
	elevation_tool.start_lowering()
	terrain_grid.set_elevation_overlay_active(true)
	print("Elevation mode: LOWERING")

func _on_bulldozer_pressed() -> void:
	"""Activate bulldozer mode to remove trees, rocks, and flower beds"""
	hole_tool.cancel_placement()
	placement_manager.cancel_placement()
	_cancel_elevation_mode()
	_disable_terrain_painting_preview()
	is_painting = false
	if terrain_toolbar:
		terrain_toolbar.clear_selection()
	bulldozer_mode = true
	EventBus.notify("Bulldozer mode - Click to remove objects", "info")
	print("Bulldozer mode: ACTIVE")

func _cancel_bulldozer_mode() -> void:
	bulldozer_mode = false

func _disable_terrain_painting_preview() -> void:
	"""Disable terrain painting preview when switching to other modes"""
	if placement_preview:
		placement_preview.set_terrain_painting_enabled(false)

func _on_new_game_started() -> void:
	"""Generate natural terrain when a new game starts"""
	_game_over_shown = false
	# Regenerate tileset with the selected theme colors
	if terrain_grid:
		terrain_grid.regenerate_tileset()

	# Clear shot heatmap data for new game
	if shot_heatmap_tracker:
		shot_heatmap_tracker.clear()

	# Generate natural terrain features
	NaturalTerrainGenerator.generate(terrain_grid, entity_layer)
	print("Natural terrain generated for new course")

	# Build pre-made course if Quick Start was selected
	var is_quick_start := _quick_start_pending
	if _quick_start_pending:
		_quick_start_pending = false
		QuickStartCourse.build(terrain_grid, entity_layer, hole_tool)

	# Start tutorial for first-time players (skip for Quick Start — they already have a course)
	if not is_quick_start and not TutorialSystem.is_tutorial_completed():
		_start_tutorial()

func _cancel_elevation_mode() -> void:
	if elevation_tool.is_active():
		elevation_tool.cancel()
		terrain_grid.set_elevation_overlay_active(false)

func _paint_elevation_at_mouse() -> void:
	var mouse_world = camera.get_mouse_world_position()
	var grid_pos = terrain_grid.screen_to_grid(mouse_world)
	if grid_pos == last_paint_pos:
		return
	last_paint_pos = grid_pos
	if not terrain_grid.is_valid_position(grid_pos):
		return

	var changes = elevation_tool.paint_elevation(grid_pos, terrain_grid, brush_size, entity_layer)
	if not changes.is_empty():
		undo_manager.record_elevation_stroke(changes)

func _handle_placement_click(grid_pos: Vector2i) -> void:
	"""Handle clicking during building/tree placement"""
	# Check land ownership first
	if GameManager.land_manager and not GameManager.land_manager.is_tile_owned(grid_pos):
		EventBus.notify("You don't own this land! Press L to buy parcels.", "error")
		return

	if not placement_manager.can_place_at(grid_pos, terrain_grid):
		EventBus.notify("Cannot place here!", "error")
		return

	var cost = placement_manager.get_placement_cost()
	if cost > 0 and not GameManager.can_afford(cost):
		if GameManager.is_bankrupt():
			EventBus.notify("Spending blocked! Balance below -$1,000", "error")
		else:
			EventBus.notify("Not enough money!", "error")
		return

	if placement_manager.placement_mode == PlacementManager.PlacementMode.TREE:
		_place_tree(grid_pos, cost)
	elif placement_manager.placement_mode == PlacementManager.PlacementMode.BUILDING:
		_place_building(grid_pos, cost)
	elif placement_manager.placement_mode == PlacementManager.PlacementMode.ROCK:
		_place_rock(grid_pos, cost)
	elif placement_manager.placement_mode == PlacementManager.PlacementMode.DECORATION:
		_place_decoration(grid_pos, cost)

func _place_tree(grid_pos: Vector2i, cost: int) -> void:
	"""Place a tree at the grid position"""
	var tree = entity_layer.place_tree(grid_pos, selected_tree_type)
	if tree:
		GameManager.modify_money(-cost)
		EventBus.log_transaction("Tree: %s" % selected_tree_type.capitalize(), -cost)
		undo_manager.record_entity_placement("tree", grid_pos, selected_tree_type, cost)
		print("Placed %s tree at %s" % [selected_tree_type, grid_pos])
		# Placement feedback
		_play_placement_feedback(grid_pos, "tree")
	else:
		EventBus.notify("Failed to place tree!", "error")

func _place_building(grid_pos: Vector2i, cost: int) -> void:
	"""Place a building at the grid position"""
	var building_type = placement_manager.selected_building_type
	var building_data = building_registry.get(building_type, {})
	var building_name = building_data.get("name", building_type)

	# Check if this is a unique building that already exists
	if building_data.get("required", false) and entity_layer.has_building_of_type(building_type):
		EventBus.notify("Only one %s allowed!" % building_name, "error")
		return

	var building = entity_layer.place_building(building_type, grid_pos, building_registry)

	if building:
		GameManager.modify_money(-cost)
		EventBus.log_transaction("Building: %s" % building_name, -cost)
		EventBus.building_placed.emit(building_type, grid_pos)
		undo_manager.record_entity_placement("building", grid_pos, building_type, cost)
		print("Placed %s at %s" % [building_type, grid_pos])
		# Placement feedback
		_play_placement_feedback(grid_pos, "building")
		# Clear the building selector after successful placement
		placement_manager.cancel_placement()
	else:
		EventBus.notify("Cannot place here - overlaps with existing building!", "error")

func _place_rock(grid_pos: Vector2i, cost: int) -> void:
	"""Place a rock at the grid position"""
	var rock = entity_layer.place_rock(grid_pos, selected_rock_size)
	if rock:
		GameManager.modify_money(-cost)
		EventBus.log_transaction("Rock: %s" % selected_rock_size.capitalize(), -cost)
		undo_manager.record_entity_placement("rock", grid_pos, selected_rock_size, cost)
		print("Placed %s rock at %s" % [selected_rock_size, grid_pos])
		# Placement feedback
		_play_placement_feedback(grid_pos, "rock")
	else:
		EventBus.notify("Failed to place rock!", "error")

func _place_decoration(grid_pos: Vector2i, cost: int) -> void:
	"""Place a decoration at the grid position"""
	var deco_type = placement_manager.selected_decoration_type
	var decoration = entity_layer.place_decoration(grid_pos, deco_type)
	if decoration:
		var deco_name = decoration.decoration_data.get("name", deco_type.capitalize())
		GameManager.modify_money(-cost)
		EventBus.log_transaction("Decoration: %s" % deco_name, -cost)
		undo_manager.record_entity_placement("decoration", grid_pos, deco_type, cost)
		_play_placement_feedback(grid_pos, "decoration")
	else:
		EventBus.notify("Failed to place decoration!", "error")

func _play_placement_feedback(grid_pos: Vector2i, placement_type: String) -> void:
	"""Play visual feedback effects when placing an entity"""
	var world_pos = terrain_grid.grid_to_screen_center(grid_pos)

	# Spawn particle burst
	PlacementFeedback.create_at(self, world_pos, placement_type)

	# Ring burst effect with success color
	PlacementFeedback.create_ring_burst(self, world_pos, UIConstants.COLOR_SUCCESS)

	# Micro camera shake for satisfying feedback
	if camera:
		camera.micro_shake()

	# Sound hook (placeholder for future audio)
	PlacementFeedback.play_placement_sound(placement_type)

func _is_mouse_over_entity(mouse_world: Vector2, entity: Node2D, entity_data: Dictionary) -> bool:
	"""Check if mouse world position overlaps the entity's visual bounding box."""
	var vh = entity_data.get("visual_height", 32.0)
	var bw = entity_data.get("base_width", 24.0)
	var scale_mult = 1.0
	if entity.has_meta("_variation") or "_variation" in entity:
		var variation = entity.get("_variation")
		if variation:
			scale_mult = variation.scale
	var half_w = bw * scale_mult * 0.5
	var local = mouse_world - entity.global_position
	# Visual polygons: x centered at 0 (±half_w), y from -vh*0.7 (canopy top) to +vh*0.6 (trunk base)
	return local.x >= -half_w and local.x <= half_w and local.y >= -vh * scale_mult * 0.7 and local.y <= vh * scale_mult * 0.6

func _bulldoze_at_mouse() -> void:
	var mouse_world = camera.get_mouse_world_position()
	var grid_pos = terrain_grid.screen_to_grid(mouse_world)
	if grid_pos == last_paint_pos: return
	last_paint_pos = grid_pos
	if not terrain_grid.is_valid_position(grid_pos): return
	_handle_bulldozer_click(grid_pos, mouse_world)

# Bulldozer removal costs
const BULLDOZER_COSTS = {
	"tree": 15,
	"rock": 10,
	"decoration": 25,
	"flower_bed": 20
}

func _handle_bulldozer_click(grid_pos: Vector2i, mouse_world: Vector2 = Vector2.ZERO) -> void:
	"""Handle bulldozer removal at a single tile. Supports both single-click and drag."""
	var dragging = is_painting
	# Check land ownership
	if GameManager.land_manager and not GameManager.land_manager.is_tile_owned(grid_pos):
		if not dragging:
			EventBus.notify("You don't own this land! Press L to buy parcels.", "error")
		return

	# Search clicked tile + neighbors for entities whose visual bounds contain the mouse.
	# Entities visually extend beyond their grid tile, so exact-tile lookup misses clicks
	# on the visible trunk/canopy that overflow into adjacent tiles.
	var hit_tree_pos: Vector2i = Vector2i(-1, -1)
	var hit_rock_pos: Vector2i = Vector2i(-1, -1)
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var check_pos = grid_pos + Vector2i(dx, dy)
			if not terrain_grid.is_valid_position(check_pos):
				continue
			if hit_tree_pos == Vector2i(-1, -1):
				var t = entity_layer.get_tree_at(check_pos)
				if t and _is_mouse_over_entity(mouse_world, t, t.tree_data):
					hit_tree_pos = check_pos
			if hit_rock_pos == Vector2i(-1, -1):
				var r = entity_layer.get_rock_at(check_pos)
				if r and _is_mouse_over_entity(mouse_world, r, r.rock_data):
					hit_rock_pos = check_pos

	# Remove hit tree (prefer tree over rock when overlapping)
	if hit_tree_pos != Vector2i(-1, -1):
		var cost = BULLDOZER_COSTS["tree"]
		if not GameManager.can_afford(cost):
			if not dragging:
				if GameManager.is_bankrupt():
					EventBus.notify("Spending blocked! Balance below -$1,000", "error")
				else:
					EventBus.notify("Not enough money to remove tree ($%d)" % cost, "error")
			return
		GameManager.modify_money(-cost)
		EventBus.log_transaction("Remove tree", -cost)
		entity_layer.remove_tree(hit_tree_pos)
		_bulldoze_drag_count += 1
		_bulldoze_drag_cost += cost
		if not dragging:
			EventBus.notify("Tree removed (-$%d)" % cost, "info")
		return

	# Remove hit rock
	if hit_rock_pos != Vector2i(-1, -1):
		var cost = BULLDOZER_COSTS["rock"]
		if not GameManager.can_afford(cost):
			if not dragging:
				if GameManager.is_bankrupt():
					EventBus.notify("Spending blocked! Balance below -$1,000", "error")
				else:
					EventBus.notify("Not enough money to remove rock ($%d)" % cost, "error")
			return
		GameManager.modify_money(-cost)
		EventBus.log_transaction("Remove rock", -cost)
		entity_layer.remove_rock(hit_rock_pos)
		_bulldoze_drag_count += 1
		_bulldoze_drag_cost += cost
		if not dragging:
			EventBus.notify("Rock removed (-$%d)" % cost, "info")
		return

	# Remove decoration at exact tile position
	var decoration = entity_layer.get_decoration_at(grid_pos)
	if decoration:
		var cost = BULLDOZER_COSTS["decoration"]
		if not GameManager.can_afford(cost):
			if not dragging:
				if GameManager.is_bankrupt():
					EventBus.notify("Spending blocked! Balance below -$1,000", "error")
				else:
					EventBus.notify("Not enough money to remove decoration ($%d)" % cost, "error")
			return
		GameManager.modify_money(-cost)
		EventBus.log_transaction("Remove decoration", -cost)
		entity_layer.remove_decoration(grid_pos)
		_bulldoze_drag_count += 1
		_bulldoze_drag_cost += cost
		if not dragging:
			EventBus.notify("Decoration removed (-$%d)" % cost, "info")
		return

	# Check for flower bed terrain (exact tile only — flower beds fill their tile)
	var tile_type = terrain_grid.get_tile(grid_pos)
	if tile_type == TerrainTypes.Type.FLOWER_BED:
		var cost = BULLDOZER_COSTS["flower_bed"]
		if not GameManager.can_afford(cost):
			if not dragging:
				if GameManager.is_bankrupt():
					EventBus.notify("Spending blocked! Balance below -$1,000", "error")
				else:
					EventBus.notify("Not enough money to remove flower bed ($%d)" % cost, "error")
			return
		GameManager.modify_money(-cost)
		EventBus.log_transaction("Remove flower bed", -cost)
		terrain_grid.set_tile(grid_pos, TerrainTypes.Type.GRASS)
		_bulldoze_drag_count += 1
		_bulldoze_drag_cost += cost
		if not dragging:
			EventBus.notify("Flower bed removed (-$%d)" % cost, "info")
		return

	# Nothing to remove at this position
	if not dragging:
		EventBus.notify("Nothing to bulldoze here", "info")

# --- Day/Night Cycle ---

func _calculate_building_operating_costs() -> int:
	"""Sum operating costs from all placed buildings."""
	var total: int = 0
	if entity_layer:
		for building in entity_layer.get_all_buildings():
			var op_cost = building.building_data.get("operating_cost", 0)
			total += op_cost
	return total

func _on_end_of_day(day_number: int) -> void:
	"""Handle end of day — show summary panel."""
	# Pause the game while showing the summary
	GameManager.is_paused = true

	# Calculate and deduct operating costs BEFORE showing summary
	var terrain_cost = terrain_grid.get_total_maintenance_cost()
	var hole_count = GameManager.current_course.holes.size() if GameManager.current_course else 0
	var building_costs = _calculate_building_operating_costs()

	# Staff payroll
	var staff_payroll: int = 0
	if GameManager.staff_manager:
		staff_payroll = GameManager.staff_manager.get_daily_payroll()
		GameManager.staff_manager.process_daily_maintenance()

	# Marketing costs
	var marketing_cost: int = 0
	if GameManager.marketing_manager:
		marketing_cost = GameManager.marketing_manager.process_daily()

	GameManager.daily_stats.calculate_operating_costs(terrain_cost, hole_count, building_costs)

	var total_cost = GameManager.daily_stats.operating_costs + staff_payroll + marketing_cost
	if total_cost > 0:
		GameManager.modify_money(-total_cost)
		EventBus.log_transaction("Daily operating costs", -total_cost)

	# Update course rating before showing summary
	GameManager.update_course_rating()

	# Check scenario progress
	if scenario_system and scenario_system.is_scenario_active:
		scenario_system.check_progress()

	# Prevent duplicate panels
	var hud = $UI/HUD
	var existing = hud.get_node_or_null("EndOfDaySummary")
	if existing:
		return

	# Create and show the end of day summary panel
	var summary = EndOfDaySummaryPanel.new(day_number)
	summary.name = "EndOfDaySummary"

	# Connect signals BEFORE add_child (ready signal fires during add_child)
	summary.continue_pressed.connect(_on_summary_continue)
	summary.build_mode_pressed.connect(_on_summary_build_mode)

	hud.add_child(summary)

	# Center the panel on screen (use custom_minimum_size since layout happens next frame)
	var viewport_size = get_viewport().get_visible_rect().size
	summary.position = (viewport_size - summary.custom_minimum_size) / 2

func _on_summary_continue() -> void:
	"""Called when player clicks Continue on the end of day summary."""
	GameManager.is_paused = false
	GameManager.advance_to_next_day()

func _on_summary_build_mode() -> void:
	"""Called when player clicks Return to Build Mode on the end of day summary."""
	GameManager.is_paused = false
	GameManager.stop_simulation()

# --- Save/Load ---

func _create_save_load_button() -> void:
	var bottom_bar = $UI/HUD/BottomBar
	var menu_btn = Button.new()
	menu_btn.name = "MenuBtn"
	menu_btn.text = "Menu"
	menu_btn.custom_minimum_size = Vector2(60, 30)
	menu_btn.pressed.connect(_on_menu_pressed)
	bottom_bar.add_child(menu_btn)

	# End Day button (for testing/convenience)
	var end_day_btn = Button.new()
	end_day_btn.name = "EndDayBtn"
	end_day_btn.text = "End Day"
	end_day_btn.custom_minimum_size = Vector2(70, 30)
	end_day_btn.pressed.connect(_on_end_day_pressed)
	bottom_bar.add_child(end_day_btn)

func _on_end_day_pressed() -> void:
	if tournament_manager.is_tournament_in_progress():
		tournament_manager.simulate_remaining_and_complete()
	GameManager.force_end_day()

func _on_menu_pressed() -> void:
	# Toggle save/load panel
	var hud = $UI/HUD
	var existing = hud.get_node_or_null("SaveLoadPanel")
	if existing:
		existing.queue_free()
		return
	var panel = SaveLoadPanel.new()
	panel.name = "SaveLoadPanel"
	panel.anchors_preset = Control.PRESET_CENTER
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.quit_to_menu_requested.connect(_on_quit_to_menu)
	hud.add_child(panel)

func _on_quit_to_menu() -> void:
	# Return to main menu by reloading the scene
	# This resets all game state cleanly
	GameManager.set_mode(GameManager.GameMode.MAIN_MENU)
	get_tree().reload_current_scene()

func _on_load_completed(_success: bool) -> void:
	if _success:
		_game_over_shown = false
		_rebuild_hole_list()
		# Sync hole creation tool so the next hole gets the correct number
		if GameManager.current_course:
			hole_tool.current_hole_number = GameManager.current_course.holes.size() + 1
		# Regenerate tileset with loaded theme colors
		if terrain_grid:
			terrain_grid.regenerate_tileset()
		# Center camera on grid (same as new game) so player starts on their course
		var center_x = (terrain_grid.grid_width / 2) * terrain_grid.tile_width
		var center_y = (terrain_grid.grid_height / 2) * terrain_grid.tile_height
		camera.focus_on(Vector2(center_x, center_y), true)
		# Show scenario objectives HUD if a scenario is active
		if scenario_system and scenario_system.is_scenario_active and scenario_objectives_hud:
			scenario_objectives_hud.show_objectives()

# --- Undo/Redo System ---

var _is_undoing: bool = false  # Prevent re-recording changes triggered by undo/redo

func _on_terrain_tile_changed_for_undo(position: Vector2i, old_type: int, new_type: int) -> void:
	if _is_undoing:
		# Tile change during undo/redo, don't re-record
		return
	undo_manager.record_tile_change(position, old_type, new_type)

func _perform_undo() -> void:
	if not undo_manager.can_undo():
		return

	var action = undo_manager.undo()
	if action.is_empty():
		return

	_is_undoing = true
	_execute_undo_action(action)
	_is_undoing = false
	EventBus.notify("Undo", "info")

func _perform_redo() -> void:
	if not undo_manager.can_redo():
		return

	var action = undo_manager.redo()
	if action.is_empty():
		return

	_is_undoing = true
	_execute_redo_action(action)
	_is_undoing = false
	EventBus.notify("Redo", "info")

func _execute_undo_action(action: Dictionary) -> void:
	match action.get("type", ""):
		"terrain":
			# Revert all tile changes in reverse order
			var changes = action.get("changes", [])
			var refund = 0
			for i in range(changes.size() - 1, -1, -1):
				var change = changes[i]
				terrain_grid.set_tile(change["position"], change["old_type"])
				refund += TerrainTypes.get_placement_cost(change["new_type"])
			if refund > 0:
				GameManager.modify_money(refund)
		"elevation":
			# Revert elevation changes in reverse order
			var changes = action.get("changes", [])
			for i in range(changes.size() - 1, -1, -1):
				var change = changes[i]
				terrain_grid.set_elevation(change["position"], change["old_elevation"])
		"entity_place":
			# Remove the entity and refund cost
			var grid_pos = action.get("grid_pos", Vector2i.ZERO)
			var entity_type = action.get("entity_type", "")
			var cost = action.get("cost", 0)
			match entity_type:
				"tree":
					entity_layer.remove_tree(grid_pos)
				"building":
					entity_layer.remove_building(grid_pos)
				"rock":
					entity_layer.remove_rock(grid_pos)
			if cost > 0:
				GameManager.modify_money(cost)

func _execute_redo_action(action: Dictionary) -> void:
	match action.get("type", ""):
		"terrain":
			# Re-apply all tile changes in order
			var changes = action.get("changes", [])
			var cost = 0
			for change in changes:
				terrain_grid.set_tile(change["position"], change["new_type"])
				cost += TerrainTypes.get_placement_cost(change["new_type"])
			if cost > 0:
				GameManager.modify_money(-cost)
		"elevation":
			# Re-apply elevation changes in order
			var changes = action.get("changes", [])
			for change in changes:
				terrain_grid.set_elevation(change["position"], change["new_elevation"])
		"entity_place":
			# Re-place the entity and deduct cost
			var grid_pos = action.get("grid_pos", Vector2i.ZERO)
			var entity_type = action.get("entity_type", "")
			var subtype = action.get("subtype", "")
			var cost = action.get("cost", 0)
			match entity_type:
				"tree":
					entity_layer.place_tree(grid_pos, subtype)
				"building":
					entity_layer.place_building(subtype, grid_pos, building_registry)
				"rock":
					entity_layer.place_rock(grid_pos, subtype)
			if cost > 0:
				GameManager.modify_money(-cost)

# --- Building Info Panel ---

func _setup_building_info_panel() -> void:
	"""Add building info panel to the HUD."""
	var hud = $UI/HUD
	building_info_panel.name = "BuildingInfoPanel"
	hud.add_child(building_info_panel)
	building_info_panel.hide()

func _on_building_clicked(building: Building) -> void:
	"""Show building info panel when a building is clicked."""
	# If in any placement mode, don't open the panel
	if placement_manager.placement_mode != PlacementManager.PlacementMode.NONE:
		if placement_manager.placement_mode == PlacementManager.PlacementMode.BUILDING:
			EventBus.notify("Cannot place here - overlaps with existing building!", "error")
		return

	# Only show for upgradeable buildings or buildings with stats
	if building.building_data.get("upgradeable", false) or building.get_income_per_golfer() > 0:
		building_info_panel.show_for_building(building)

		# Center the panel on screen
		var viewport_size = get_viewport().get_visible_rect().size
		building_info_panel.position = (viewport_size - building_info_panel.custom_minimum_size) / 2

func _on_building_panel_closed() -> void:
	"""Hide the building info panel."""
	building_info_panel.hide()

# --- Financial Panel ---

func _setup_financial_panel() -> void:
	"""Add financial panel to the HUD."""
	var hud = $UI/HUD

	# Create financial panel
	financial_panel = FinancialPanel.new()
	financial_panel.name = "FinancialPanel"
	financial_panel.close_requested.connect(_on_financial_panel_closed)
	hud.add_child(financial_panel)
	financial_panel.hide()

	# Create staff panel
	staff_panel = StaffPanel.new()
	staff_panel.name = "StaffPanel"
	staff_panel.close_requested.connect(_on_staff_panel_closed)
	hud.add_child(staff_panel)
	staff_panel.hide()

	# Note: Money click is now handled by TopHUDBar.money_clicked signal

func _on_money_clicked() -> void:
	## Toggle the financial panel when money is clicked.
	_toggle_panel(financial_panel)

func _on_financial_panel_closed() -> void:
	"""Hide the financial panel."""
	financial_panel.hide()
	if _active_panel == financial_panel:
		_active_panel = null

func _on_staff_pressed() -> void:
	## Toggle staff management panel.
	if staff_panel:
		_toggle_panel(staff_panel)

func _on_staff_panel_closed() -> void:
	"""Hide the staff panel."""
	staff_panel.hide()
	if _active_panel == staff_panel:
		_active_panel = null

# --- Mini Map ---

func _setup_mini_map() -> void:
	"""Add mini-map to the HUD in bottom-left corner."""
	var hud = $UI/HUD

	mini_map = MiniMap.new()
	mini_map.name = "MiniMap"
	mini_map.setup(terrain_grid, entity_layer, golfer_manager)
	mini_map.camera_move_requested.connect(_on_mini_map_camera_move)

	# Position in bottom-left corner, above the bottom bar
	mini_map.anchor_left = 0
	mini_map.anchor_top = 1
	mini_map.anchor_right = 0
	mini_map.anchor_bottom = 1
	mini_map.offset_left = 10
	mini_map.offset_top = -240  # Height + margin + space for bottom bar
	mini_map.offset_right = 200  # Approximate width
	mini_map.offset_bottom = -50  # Stay above bottom bar

	hud.add_child(mini_map)

func _on_mini_map_camera_move(world_position: Vector2) -> void:
	"""Move camera to the position clicked on mini-map."""
	camera.focus_on(world_position, false)

func _update_mini_map_camera() -> void:
	"""Update the mini-map camera viewport indicator."""
	if not mini_map or not mini_map.visible:
		return

	# Get current camera viewport in world coordinates
	var viewport_size = get_viewport().get_visible_rect().size
	var camera_pos = camera.global_position
	var zoom = camera.zoom

	# Calculate visible world rect
	var visible_size = viewport_size / zoom
	var top_left = camera_pos - visible_size / 2
	var viewport_rect = Rect2(top_left, visible_size)

	mini_map.set_camera_rect(viewport_rect, terrain_grid.grid_width, terrain_grid.grid_height)

# --- Hole Stats Panel ---

func _setup_hole_stats_panel() -> void:
	"""Add hole stats panel to the HUD."""
	var hud = $UI/HUD

	hole_stats_panel = HoleStatsPanel.new()
	hole_stats_panel.name = "HoleStatsPanel"
	hole_stats_panel.close_requested.connect(_on_hole_stats_panel_closed)
	hole_stats_panel.hole_selected.connect(_on_hole_stats_selected)
	hud.add_child(hole_stats_panel)
	hole_stats_panel.hide()

func _on_hole_stats_panel_closed() -> void:
	"""Hide the hole stats panel."""
	hole_stats_panel.hide()
	if _active_panel == hole_stats_panel:
		_active_panel = null

func _on_hole_stats_selected(hole_number: int) -> void:
	"""Highlight hole on course and move camera to it."""
	if not GameManager.current_course:
		return

	for hole in GameManager.current_course.holes:
		if hole.hole_number == hole_number:
			# Move camera to center between tee and green
			var tee_world = terrain_grid.grid_to_screen_center(hole.tee_position)
			var green_world = terrain_grid.grid_to_screen_center(hole.green_position)
			var center = (tee_world + green_world) / 2
			camera.focus_on(center, false)
			break

func _show_hole_stats(hole_number: int) -> void:
	"""Show hole stats panel for the given hole number."""
	if not GameManager.current_course:
		return

	for hole in GameManager.current_course.holes:
		if hole.hole_number == hole_number:
			# Close any active panel first
			if _active_panel and _active_panel.visible:
				_active_panel.hide()
			hole_stats_panel.show_for_hole(hole)
			_active_panel = hole_stats_panel
			break

# --- Tournament Panel ---

func _setup_tournament_panel() -> void:
	"""Add tournament panel to the HUD."""
	var hud = $UI/HUD

	tournament_panel = TournamentPanel.new()
	tournament_panel.name = "TournamentPanel"
	tournament_panel.close_requested.connect(_on_tournament_panel_closed)
	hud.add_child(tournament_panel)
	tournament_panel.setup(tournament_manager)

	# Add tournament button to bottom bar
	var bottom_bar = $UI/HUD/BottomBar
	var tournament_btn = Button.new()
	tournament_btn.name = "TournamentBtn"
	tournament_btn.text = "Tournament"
	tournament_btn.tooltip_text = "Host tournaments (U)"
	tournament_btn.pressed.connect(_toggle_tournament_panel)
	bottom_bar.add_child(tournament_btn)

func _on_tournament_panel_closed() -> void:
	"""Hide the tournament panel."""
	tournament_panel.hide()
	if _active_panel == tournament_panel:
		_active_panel = null

func _toggle_tournament_panel() -> void:
	"""Toggle the tournament panel visibility."""
	_toggle_panel(tournament_panel)

func _toggle_terrain_debug_overlay() -> void:
	"""Toggle the terrain debug overlay (F3)."""
	if terrain_grid:
		terrain_grid.toggle_debug_overlay()

# --- Land Panel ---

func _setup_land_panel() -> void:
	"""Add land panel to the HUD."""
	var hud = $UI/HUD

	land_panel = LandPanel.new()
	land_panel.name = "LandPanel"
	land_panel.close_requested.connect(_on_land_panel_closed)
	hud.add_child(land_panel)
	land_panel.hide()

	# Add land button to bottom bar
	var bottom_bar = $UI/HUD/BottomBar
	var land_btn = Button.new()
	land_btn.name = "LandBtn"
	land_btn.text = "Land"
	land_btn.tooltip_text = "Buy land parcels (L)"
	land_btn.pressed.connect(_toggle_land_panel)
	bottom_bar.add_child(land_btn)

func _on_land_panel_closed() -> void:
	"""Hide the land panel."""
	land_panel.hide()
	if _active_panel == land_panel:
		_active_panel = null

func _toggle_land_panel() -> void:
	"""Toggle the land panel visibility."""
	if land_panel:
		_toggle_panel(land_panel)

# --- Marketing Panel ---

func _setup_marketing_panel() -> void:
	"""Add marketing panel to the HUD."""
	var hud = $UI/HUD

	marketing_panel = MarketingPanel.new()
	marketing_panel.name = "MarketingPanel"
	marketing_panel.close_requested.connect(_on_marketing_panel_closed)
	hud.add_child(marketing_panel)
	marketing_panel.hide()

	# Add marketing button to bottom bar
	var bottom_bar = $UI/HUD/BottomBar
	var marketing_btn = Button.new()
	marketing_btn.name = "MarketingBtn"
	marketing_btn.text = "Marketing"
	marketing_btn.tooltip_text = "Marketing campaigns (M)"
	marketing_btn.pressed.connect(_toggle_marketing_panel)
	bottom_bar.add_child(marketing_btn)

func _on_marketing_panel_closed() -> void:
	"""Hide the marketing panel."""
	marketing_panel.hide()
	if _active_panel == marketing_panel:
		_active_panel = null

# --- Hotkey Panel ---

func _setup_hotkey_panel() -> void:
	"""Add hotkey reference panel to the HUD."""
	var hud = $UI/HUD

	hotkey_panel = HotkeyPanel.new()
	hotkey_panel.name = "HotkeyPanel"
	hud.add_child(hotkey_panel)
	hotkey_panel.hide()

func _toggle_hotkey_panel() -> void:
	"""Toggle the hotkey reference panel."""
	if hotkey_panel:
		_toggle_panel(hotkey_panel)

func _toggle_marketing_panel() -> void:
	"""Toggle the marketing panel visibility."""
	if marketing_panel:
		_toggle_panel(marketing_panel)

# --- Weather Debug ---

func _setup_weather_debug_panel() -> void:
	"""Add weather debug panel to the HUD."""
	var hud = $UI/HUD
	weather_debug_panel = WeatherDebugPanel.new()
	weather_debug_panel.name = "WeatherDebugPanel"
	weather_debug_panel.close_requested.connect(_on_weather_debug_panel_closed)
	hud.add_child(weather_debug_panel)
	weather_debug_panel.hide()

func _on_weather_debug_panel_closed() -> void:
	weather_debug_panel.hide()
	_active_panel = null

func _toggle_weather_debug_panel() -> void:
	"""Toggle the weather debug panel."""
	if weather_debug_panel:
		_toggle_panel(weather_debug_panel)

# --- Season Debug ---

func _setup_season_debug_panel() -> void:
	"""Add season debug panel to the HUD."""
	var hud = $UI/HUD
	season_debug_panel = SeasonDebugPanel.new()
	season_debug_panel.name = "SeasonDebugPanel"
	season_debug_panel.close_requested.connect(_on_season_debug_panel_closed)
	hud.add_child(season_debug_panel)
	season_debug_panel.hide()

func _on_season_debug_panel_closed() -> void:
	season_debug_panel.hide()
	_active_panel = null

func _toggle_season_debug_panel() -> void:
	"""Toggle the season debug panel."""
	if season_debug_panel:
		_toggle_panel(season_debug_panel)

# --- Analytics Panel ---

func _setup_analytics_panel() -> void:
	"""Add analytics panel to the HUD."""
	var hud = $UI/HUD
	analytics_panel_ui = AnalyticsPanel.new()
	analytics_panel_ui.name = "AnalyticsPanel"
	analytics_panel_ui.close_requested.connect(_on_analytics_panel_closed)
	hud.add_child(analytics_panel_ui)
	analytics_panel_ui.hide()

func _on_analytics_panel_closed() -> void:
	analytics_panel_ui.hide()
	if _active_panel == analytics_panel_ui:
		_active_panel = null

func _toggle_analytics_panel() -> void:
	"""Toggle the analytics panel visibility."""
	if analytics_panel_ui:
		_toggle_panel(analytics_panel_ui)

# --- Audio Controls ---

func _setup_audio_controls() -> void:
	"""Add audio volume controls to the bottom bar."""
	var bottom_bar = $UI/HUD/BottomBar
	var audio_controls = AudioControls.new()
	audio_controls.name = "AudioControls"
	bottom_bar.add_child(audio_controls)

# --- Golfer Info Popup ---

func _setup_golfer_info_popup() -> void:
	var hud = $UI/HUD
	golfer_info_popup = GolferInfoPopup.new()
	golfer_info_popup.name = "GolferInfoPopup"
	golfer_info_popup.close_requested.connect(_on_golfer_info_popup_closed)
	hud.add_child(golfer_info_popup)
	golfer_info_popup.hide()
	golfer_manager.golfer_clicked.connect(_on_golfer_clicked)

func _on_golfer_info_popup_closed() -> void:
	golfer_info_popup.hide()
	_active_panel = null

func _on_golfer_clicked(golfer: Golfer) -> void:
	if placement_manager.placement_mode != PlacementManager.PlacementMode.NONE:
		return
	if _active_panel and _active_panel != golfer_info_popup and _active_panel.visible:
		_active_panel.hide()
	_active_panel = golfer_info_popup
	golfer_info_popup.show_for_golfer(golfer)

# --- Round Summary ---

func _setup_round_summary_popup() -> void:
	round_summary_popup = RoundSummaryPopup.new()
	round_summary_popup.name = "RoundSummaryPopup"
	$UI.add_child(round_summary_popup)
	EventBus.golfer_finished_round.connect(_on_golfer_round_for_summary)

func _on_golfer_round_for_summary(golfer_id: int, total_strokes: int) -> void:
	var golfer = golfer_manager.get_golfer(golfer_id)
	if not golfer:
		return
	round_summary_popup.queue_notification({
		"name": golfer.golfer_name,
		"total_strokes": total_strokes,
		"total_par": golfer.total_par,
		"mood": golfer.current_mood,
		"tier": golfer.golfer_tier,
		"green_fee": GameManager.green_fee,
		"holes_played": golfer.hole_scores.size(),
	})

# --- Milestone System ---

func _setup_milestone_system() -> void:
	milestone_manager = MilestoneManager.new()
	milestone_manager.name = "MilestoneManager"
	add_child(milestone_manager)

	milestones_panel = MilestonesPanel.new()
	milestones_panel.name = "MilestonesPanel"
	milestones_panel.set_milestone_manager(milestone_manager)
	milestones_panel.close_requested.connect(func():
		milestones_panel.hide()
		_active_panel = null
	)
	$UI/HUD.add_child(milestones_panel)

	# Add milestones button to bottom bar
	var bottom_bar = $UI/HUD/BottomBar
	var milestones_btn = Button.new()
	milestones_btn.name = "MilestonesBtn"
	milestones_btn.text = "Milestones"
	milestones_btn.tooltip_text = "Goals & achievements (G)"
	milestones_btn.pressed.connect(_toggle_milestones_panel)
	bottom_bar.add_child(milestones_btn)

	# Update SaveManager reference to include milestone manager
	SaveManager.milestone_manager = milestone_manager

func _toggle_milestones_panel() -> void:
	_toggle_panel(milestones_panel)

# --- Seasonal Calendar ---

func _setup_seasonal_calendar() -> void:
	seasonal_calendar_panel = SeasonalCalendarPanel.new()
	seasonal_calendar_panel.name = "SeasonalCalendarPanel"
	seasonal_calendar_panel.close_requested.connect(func():
		seasonal_calendar_panel.hide()
		_active_panel = null
	)
	$UI/HUD.add_child(seasonal_calendar_panel)

	# Listen for day changes to announce seasonal events
	EventBus.day_changed.connect(_on_day_changed_for_events)
	EventBus.season_changed.connect(_on_season_changed_notification)

func _toggle_seasonal_calendar() -> void:
	_toggle_panel(seasonal_calendar_panel)

func _on_day_changed_for_events(_new_day: int) -> void:
	# Check if there's a seasonal event starting today
	var event = SeasonalEvents.get_active_event(_new_day)
	if event:
		var day_in_season = SeasonSystem.get_day_in_season(_new_day)
		if day_in_season == event.day_in_season:
			EventBus.notify("Event: %s" % event.name, "success")
			if event.reputation_bonus > 0:
				GameManager.modify_reputation(event.reputation_bonus)

func _on_season_changed_notification(old_season: int, new_season: int) -> void:
	var season_name = SeasonSystem.get_season_name(new_season)
	EventBus.notify("%s has arrived!" % season_name, "info")

# --- Tutorial ---

func _start_tutorial() -> void:
	if tutorial_system and tutorial_system.is_active:
		return
	tutorial_system = TutorialSystem.new()
	tutorial_system.name = "TutorialSystem"
	add_child(tutorial_system)
	tutorial_system.start_tutorial()
	var overlay = tutorial_system.get_overlay()
	if overlay:
		$UI.add_child(overlay)
	tutorial_system.tutorial_completed.connect(_on_tutorial_completed)

func _on_tutorial_completed() -> void:
	EventBus.notify("Tutorial complete! Press F1 for hotkeys anytime.", "success")

# --- Notification Toast ---

func _setup_notification_toast() -> void:
	var toast = NotificationToast.new()
	toast.name = "NotificationToast"
	$UI.add_child(toast)

# --- Advisor Panel ---

func _setup_advisor_panel() -> void:
	"""Add advisor panel to the HUD."""
	advisor_panel = AdvisorPanel.new()
	advisor_panel.name = "AdvisorPanel"
	advisor_panel.setup(advisor_system)
	$UI/HUD.add_child(advisor_panel)
	advisor_panel.hide()

func _toggle_advisor_panel() -> void:
	if advisor_panel:
		if not advisor_panel.visible and advisor_system:
			advisor_system.refresh_tips()
		_toggle_panel(advisor_panel)

# --- Awards Panel ---

func _setup_awards_panel() -> void:
	"""Add awards panel to the HUD."""
	awards_panel = AwardsPanel.new()
	awards_panel.name = "AwardsPanel"
	awards_panel.setup(awards_system)
	$UI/HUD.add_child(awards_panel)
	awards_panel.hide()

func _toggle_awards_panel() -> void:
	if awards_panel:
		_toggle_panel(awards_panel)

# --- Prestige Panel ---

func _setup_prestige_panel() -> void:
	"""Add prestige panel to the HUD."""
	prestige_panel = PrestigePanel.new()
	prestige_panel.name = "PrestigePanel"
	prestige_panel.setup(prestige_system)
	$UI/HUD.add_child(prestige_panel)
	prestige_panel.hide()

func _toggle_prestige_panel() -> void:
	if prestige_panel:
		_toggle_panel(prestige_panel)

func _setup_loyalty_panel() -> void:
	"""Add loyalty/membership panel to the HUD."""
	loyalty_panel = LoyaltyPanel.new()
	loyalty_panel.name = "LoyaltyPanel"
	loyalty_panel.setup(loyalty_system)
	$UI/HUD.add_child(loyalty_panel)
	loyalty_panel.hide()

func _toggle_loyalty_panel() -> void:
	if loyalty_panel:
		_toggle_panel(loyalty_panel)

func _setup_pricing_panel() -> void:
	"""Add dynamic pricing panel to the HUD."""
	pricing_panel = PricingPanel.new()
	pricing_panel.name = "PricingPanel"
	pricing_panel.setup(dynamic_pricing_system)
	$UI/HUD.add_child(pricing_panel)
	pricing_panel.hide()

func _toggle_pricing_panel() -> void:
	if pricing_panel:
		_toggle_panel(pricing_panel)

# --- Scenario System ---

func _setup_scenario_panel() -> void:
	scenario_panel = ScenarioPanel.new()
	scenario_panel.name = "ScenarioPanel"
	scenario_panel.setup(scenario_system)
	scenario_panel.scenario_selected.connect(_on_scenario_selected)
	$UI/HUD.add_child(scenario_panel)
	scenario_panel.hide()

func _setup_scenario_objectives_hud() -> void:
	scenario_objectives_hud = ScenarioObjectivesHUD.new()
	scenario_objectives_hud.name = "ScenarioObjectivesHUD"
	scenario_objectives_hud.setup(scenario_system)
	# Position in top-right corner
	scenario_objectives_hud.anchor_left = 1.0
	scenario_objectives_hud.anchor_right = 1.0
	scenario_objectives_hud.anchor_top = 0.0
	scenario_objectives_hud.anchor_bottom = 0.0
	scenario_objectives_hud.offset_left = -240
	scenario_objectives_hud.offset_right = -10
	scenario_objectives_hud.offset_top = 50
	$UI/HUD.add_child(scenario_objectives_hud)

func _on_scenario_selected(scenario_id: String, theme_type: int) -> void:
	"""Start a scenario — similar to new game but with scenario constraints."""
	var scenario = scenario_system.get_scenario(scenario_id)
	if scenario.is_empty():
		return

	# Determine theme — use scenario's theme or default to parkland
	var actual_theme = theme_type if theme_type >= 0 else CourseTheme.Type.PARKLAND
	var difficulty = scenario.get("difficulty", -1)
	var actual_difficulty = difficulty if difficulty >= 0 else DifficultyPresets.Preset.NORMAL

	# Start new game with scenario settings
	if main_menu and is_instance_valid(main_menu):
		main_menu.queue_free()
		main_menu = null
	_set_gameplay_ui_visible(true)

	GameManager.new_game(scenario.get("name", "Scenario"), actual_theme, actual_difficulty)

	# Apply scenario-specific settings (starting money override)
	scenario_system.apply_scenario_settings(scenario)
	scenario_system.start_scenario(scenario_id)

	# Regenerate tileset after theme change
	if terrain_grid:
		terrain_grid.regenerate_tileset()

	# Center camera
	var center = terrain_grid.grid_to_screen_center(Vector2i(terrain_grid.grid_width / 2, terrain_grid.grid_height / 2))
	camera.focus_on(center, false)

	# Show objectives HUD
	if scenario_objectives_hud:
		scenario_objectives_hud.show_objectives()

func _toggle_scenario_panel() -> void:
	if scenario_panel:
		_toggle_panel(scenario_panel)

# --- Course Rating Overlay ---

func _setup_course_rating_overlay() -> void:
	"""Add course rating panel (toggled from top bar star rating)."""
	course_rating_overlay = CourseRatingOverlay.new()
	course_rating_overlay.name = "CourseRatingOverlay"
	course_rating_overlay.close_requested.connect(func():
		course_rating_overlay.hide()
		if _active_panel == course_rating_overlay:
			_active_panel = null
	)
	course_rating_overlay.rating_updated.connect(func(stars: float):
		if top_hud_bar:
			top_hud_bar.update_rating(stars)
	)
	$UI/HUD.add_child(course_rating_overlay)
	course_rating_overlay.hide()
	# Update top bar whenever course rating changes (end of day, etc.)
	EventBus.course_rating_changed.connect(func(rating: Dictionary):
		if top_hud_bar:
			top_hud_bar.update_rating(rating.get("overall", 3.0))
	)
	# Push initial rating to top bar (deferred so GameManager is ready)
	_update_top_bar_rating.call_deferred()

func _update_top_bar_rating() -> void:
	if not GameManager.current_course or not GameManager.terrain_grid or not top_hud_bar:
		return
	var rating := CourseRatingSystem.calculate_rating(
		GameManager.terrain_grid,
		GameManager.current_course,
		GameManager.daily_stats,
		GameManager.green_fee,
		GameManager.reputation
	)
	var stars: float = rating.get("overall", 3.0)
	top_hud_bar.update_rating(stars)

func _toggle_course_rating_panel() -> void:
	_toggle_panel(course_rating_overlay)

# --- Floating Transaction Text ---

func _setup_floating_text() -> void:
	"""Connect money changes to spawn floating +$/-$ text on transactions."""
	EventBus.transaction_completed.connect(_on_transaction_for_floating_text)

func _on_transaction_for_floating_text(_description: String, amount: int) -> void:
	"""Spawn floating text at a relevant screen position for transactions."""
	if GameManager.current_mode == GameManager.GameMode.MAIN_MENU:
		return
	if abs(amount) < 1:
		return

	# Show floating text near the money display in the top HUD
	# Convert HUD position to world-space so it renders above terrain
	var vp_size := get_viewport().get_visible_rect().size
	var screen_pos := Vector2(120, 28)  # Near top-left money display
	# For world-space, convert screen coords to camera-relative position
	var world_pos := camera.global_position + (screen_pos - vp_size / 2) / camera.zoom
	FloatingText.create_at(self, world_pos, amount)

# --- Autosave Indicator ---

func _setup_autosave_indicator() -> void:
	var indicator = AutosaveIndicator.new()
	indicator.name = "AutosaveIndicator"
	$UI.add_child(indicator)

# --- Pause Menu ---

func _toggle_pause_menu() -> void:
	"""Toggle the pause menu overlay."""
	if pause_menu:
		_close_pause_menu()
	else:
		_show_pause_menu()

func _show_pause_menu() -> void:
	"""Show the pause menu and pause the game."""
	if pause_menu:
		return
	# Close any active panel
	if _active_panel and _active_panel.visible:
		_active_panel.hide()
		_active_panel = null

	# Pause game
	GameManager.is_paused = true

	pause_menu = PauseMenu.new()
	pause_menu.name = "PauseMenu"
	pause_menu.resume_requested.connect(_on_pause_resume)
	pause_menu.save_requested.connect(_on_pause_save)
	pause_menu.load_requested.connect(_on_pause_load)
	pause_menu.settings_requested.connect(_on_pause_settings)
	pause_menu.quit_to_menu_requested.connect(_on_pause_quit_to_menu)
	pause_menu.quit_to_desktop_requested.connect(_on_pause_quit_to_desktop)
	$UI/HUD.add_child(pause_menu)

func _close_pause_menu() -> void:
	"""Close the pause menu and resume the game."""
	if pause_menu:
		pause_menu.queue_free()
		pause_menu = null
	GameManager.is_paused = false

func _on_pause_resume() -> void:
	_close_pause_menu()

func _on_pause_save() -> void:
	_close_pause_menu()
	_on_menu_pressed()

func _on_pause_load() -> void:
	_close_pause_menu()
	_on_menu_pressed()

func _on_pause_settings() -> void:
	_close_pause_menu()
	_show_settings_menu()

func _show_settings_menu() -> void:
	"""Show the settings menu overlay."""
	var settings = SettingsMenu.new()
	settings.name = "SettingsMenu"
	settings.close_requested.connect(func():
		# Re-show pause menu when settings closes (if not from main menu)
		if GameManager.current_mode != GameManager.GameMode.MAIN_MENU:
			_show_pause_menu()
	)
	$UI/HUD.add_child(settings)

func _on_pause_quit_to_menu() -> void:
	_close_pause_menu()
	_show_quit_confirm("Unsaved progress will be lost.\nReturn to main menu?", "Quit to Menu", _on_quit_to_menu)

func _on_pause_quit_to_desktop() -> void:
	_close_pause_menu()
	_show_quit_confirm("Unsaved progress will be lost.\nQuit to desktop?", "Quit", func(): get_tree().quit())

func _show_quit_confirm(message: String, confirm_text: String, on_confirm: Callable) -> void:
	"""Show a confirmation dialog for a destructive action."""
	var dialog = ConfirmDialog.new(message, confirm_text, "Cancel")
	dialog.name = "QuitConfirmDialog"
	dialog.confirmed.connect(on_confirm)
	dialog.cancelled.connect(func():
		# Re-show pause menu if the user cancels
		_show_pause_menu()
	)
	$UI/HUD.add_child(dialog)

# --- Game Over ---

func _show_game_over() -> void:
	"""Show the bankruptcy game over screen."""
	_game_over_shown = true
	GameManager.is_paused = true

	# Close any active panels
	if _active_panel and _active_panel.visible:
		_active_panel.hide()
		_active_panel = null
	if pause_menu:
		_close_pause_menu()

	var game_over = GameOverPanel.new()
	game_over.name = "GameOverPanel"
	game_over.retry_requested.connect(func():
		game_over.queue_free()
		_game_over_shown = false
		_on_quit_to_menu()
	)
	game_over.load_requested.connect(func():
		game_over.queue_free()
		_game_over_shown = false
		GameManager.is_paused = false
		_on_menu_pressed()
	)
	game_over.quit_to_menu_requested.connect(func():
		game_over.queue_free()
		_game_over_shown = false
		_on_quit_to_menu()
	)
	$UI/HUD.add_child(game_over)

# --- Shot Heatmap ---

func _setup_shot_heatmap() -> void:
	shot_heatmap_tracker = ShotHeatmapTracker.new()
	shot_heatmap_tracker.name = "ShotHeatmapTracker"
	add_child(shot_heatmap_tracker)
	shot_heatmap_tracker.initialize()
	GameManager.shot_heatmap_tracker = shot_heatmap_tracker
	terrain_grid.setup_shot_heatmap_overlay(shot_heatmap_tracker)

# --- Shot Trails ---

func _setup_shot_trails() -> void:
	EventBus.ball_shot_landed_precise.connect(_on_shot_for_trail)
	EventBus.ball_putt_landed_precise.connect(_on_putt_for_trail)

func _on_shot_for_trail(_golfer_id: int, from_screen: Vector2, to_screen: Vector2,
		_distance_yards: int, carry_screen: Vector2) -> void:
	if not _is_screen_visible(from_screen) and not _is_screen_visible(to_screen):
		return
	var landing_terrain = terrain_grid.get_tile(terrain_grid.screen_to_grid(to_screen))
	ShotTrail.create($Entities, from_screen, to_screen, carry_screen, false, landing_terrain)

func _on_putt_for_trail(_golfer_id: int, from_screen: Vector2, to_screen: Vector2,
		_distance_yards: int) -> void:
	if not _is_screen_visible(from_screen) and not _is_screen_visible(to_screen):
		return
	var terrain_types_ref = preload("res://scripts/terrain/terrain_types.gd")
	ShotTrail.create($Entities, from_screen, to_screen, to_screen, true, terrain_types_ref.Type.GREEN)

func _is_screen_visible(world_pos: Vector2) -> bool:
	var vp_size = get_viewport().get_visible_rect().size
	var cam_pos = camera.global_position
	var cam_zoom = camera.zoom
	var half_vp = vp_size / (2.0 * cam_zoom)
	var margin = 100.0
	return abs(world_pos.x - cam_pos.x) < half_vp.x + margin and abs(world_pos.y - cam_pos.y) < half_vp.y + margin

func _exit_tree() -> void:
	"""Disconnect all signals to prevent memory leaks on scene unload."""
	# EventBus signal cleanup
	if EventBus.money_changed.is_connected(_on_money_changed):
		EventBus.money_changed.disconnect(_on_money_changed)
	if EventBus.day_changed.is_connected(_on_day_changed):
		EventBus.day_changed.disconnect(_on_day_changed)
	if EventBus.hole_created.is_connected(_on_hole_created):
		EventBus.hole_created.disconnect(_on_hole_created)
	if EventBus.hole_deleted.is_connected(_on_hole_deleted):
		EventBus.hole_deleted.disconnect(_on_hole_deleted)
	if EventBus.hole_toggled.is_connected(_on_hole_toggled):
		EventBus.hole_toggled.disconnect(_on_hole_toggled)
	if hole_tool.tee_added.is_connected(_on_tee_added):
		hole_tool.tee_added.disconnect(_on_tee_added)
	if EventBus.end_of_day.is_connected(_on_end_of_day):
		EventBus.end_of_day.disconnect(_on_end_of_day)
	if EventBus.load_completed.is_connected(_on_load_completed):
		EventBus.load_completed.disconnect(_on_load_completed)
	if EventBus.new_game_started.is_connected(_on_new_game_started):
		EventBus.new_game_started.disconnect(_on_new_game_started)
