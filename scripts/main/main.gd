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
var green_fee_label: Label = null
var green_fee_decrease_btn: Button = null
var green_fee_increase_btn: Button = null
var selection_label: Label = null

var current_tool: int = TerrainTypes.Type.FAIRWAY
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
var selected_tree_type: String = "oak"
var selected_rock_size: String = "medium"
var bulldozer_mode: bool = false
var placement_preview: PlacementPreview = null

# Selector dialogs for entity placement (see SelectorDialog)
var _tree_selector: SelectorDialog = null
var _rock_selector: SelectorDialog = null
var _building_selector: SelectorDialog = null

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

	# Set up save manager references
	SaveManager.set_references(terrain_grid, entity_layer, golfer_manager, ball_manager)

	_connect_signals()
	_connect_ui_buttons()
	_tree_selector = SelectorDialog.new(self, KEY_T)
	_rock_selector = SelectorDialog.new(self, KEY_R)
	_building_selector = SelectorDialog.new(self, KEY_B)
	_setup_top_hud_bar()
	_create_green_fee_controls()
	_create_zoom_hint()
	_setup_rain_overlay()
	_setup_placement_preview()
	_create_selection_indicator()
	_create_save_load_button()
	_setup_building_info_panel()
	_setup_financial_panel()
	_setup_mini_map()
	_setup_hole_stats_panel()
	_setup_tournament_panel()
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
		elif event.keycode == KEY_U:
			_toggle_tournament_panel()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F3:
			_toggle_terrain_debug_overlay()
			get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	# Cancel action should always work regardless of game mode
	if event.is_action_pressed("cancel"):
		_cancel_action()
		return

	# Allow building/tree/rock placement in any mode
	var in_placement_mode = placement_manager.placement_mode != PlacementManager.PlacementMode.NONE

	# Other tools (terrain painting, elevation, hole creation, bulldozer) require BUILDING mode
	if not in_placement_mode and GameManager.current_mode != GameManager.GameMode.BUILDING:
		return

	if event.is_action_pressed("select"):
		_start_painting()
	elif event.is_action_released("select"):
		_stop_painting()
	if is_painting and event is InputEventMouseMotion:
		if elevation_tool.is_active():
			_paint_elevation_at_mouse()
		else:
			_paint_at_mouse()

func _connect_signals() -> void:
	EventBus.money_changed.connect(_on_money_changed)
	EventBus.day_changed.connect(_on_day_changed)
	EventBus.hole_created.connect(_on_hole_created)
	EventBus.hole_deleted.connect(_on_hole_deleted)
	EventBus.hole_toggled.connect(_on_hole_toggled)
	EventBus.green_fee_changed.connect(_on_green_fee_changed)
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

	# Resize tool panel container to fit the wider toolbar and fill vertical space
	tool_panel_container.anchor_top = 0.0
	tool_panel_container.anchor_bottom = 1.0
	tool_panel_container.offset_left = -270
	tool_panel_container.offset_top = 55   # below top bar
	tool_panel_container.offset_bottom = -65  # above bottom bar
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
	terrain_toolbar.flower_bed_pressed.connect(_on_flower_bed_placement_pressed)
	terrain_toolbar.building_placement_pressed.connect(_on_building_placement_pressed)
	terrain_toolbar.raise_elevation_pressed.connect(_on_raise_elevation_pressed)
	terrain_toolbar.lower_elevation_pressed.connect(_on_lower_elevation_pressed)
	terrain_toolbar.bulldozer_pressed.connect(_on_bulldozer_pressed)
	terrain_toolbar.staff_pressed.connect(_on_staff_pressed)

func _initialize_game() -> void:
	GameManager.new_game("My Golf Course")
	# Center camera on the middle of the grid
	var center_x = (terrain_grid.grid_width / 2) * terrain_grid.tile_width
	var center_y = (terrain_grid.grid_height / 2) * terrain_grid.tile_height
	camera.focus_on(Vector2(center_x, center_y), true)
	# Initialize terrain painting preview with default tool
	if placement_preview:
		placement_preview.set_terrain_tool(current_tool)
		placement_preview.set_terrain_painting_enabled(true)

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

	# Connect money click to financial panel
	top_hud_bar.money_clicked.connect(_on_money_clicked)
	# Connect reputation click to financial panel (shows course rating details)
	top_hud_bar.reputation_clicked.connect(_on_money_clicked)

	# Add to HUD as first child
	hud.add_child(top_hud_bar)
	hud.move_child(top_hud_bar, 0)

	# Create "Build Mode" button to return from simulation
	build_mode_btn = Button.new()
	build_mode_btn.name = "BuildModeBtn"
	build_mode_btn.text = "# Build"
	build_mode_btn.pressed.connect(_on_build_mode_pressed)
	speed_controls.add_child(build_mode_btn)

func _create_green_fee_controls() -> void:
	"""Create UI controls for adjusting green fee"""
	var bottom_bar = $UI/HUD/BottomBar

	# Create container for green fee controls
	var green_fee_container = HBoxContainer.new()
	green_fee_container.name = "GreenFeeControls"

	# Create decrease button
	green_fee_decrease_btn = Button.new()
	green_fee_decrease_btn.text = "-"
	green_fee_decrease_btn.custom_minimum_size = Vector2(30, 30)
	green_fee_decrease_btn.pressed.connect(_on_green_fee_decrease)
	green_fee_container.add_child(green_fee_decrease_btn)

	# Create label
	green_fee_label = Label.new()
	green_fee_label.text = "Fee: $%d" % GameManager.green_fee
	green_fee_label.custom_minimum_size = Vector2(80, 30)
	green_fee_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	green_fee_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	green_fee_container.add_child(green_fee_label)

	# Create increase button
	green_fee_increase_btn = Button.new()
	green_fee_increase_btn.text = "+"
	green_fee_increase_btn.custom_minimum_size = Vector2(30, 30)
	green_fee_increase_btn.pressed.connect(_on_green_fee_increase)
	green_fee_container.add_child(green_fee_increase_btn)

	# Add to bottom bar (after speed controls)
	bottom_bar.add_child(green_fee_container)
	bottom_bar.move_child(green_fee_container, 1)  # Position after SpeedControls

func _create_zoom_hint() -> void:
	var bottom_bar = $UI/HUD/BottomBar
	var zoom_label = Label.new()
	zoom_label.name = "ZoomHint"
	zoom_label.text = "Zoom: [ - ] +"
	zoom_label.add_theme_font_size_override("font_size", 12)
	zoom_label.add_theme_color_override("font_color", Color.WHITE)
	bottom_bar.add_child(zoom_label)

func _setup_rain_overlay() -> void:
	rain_overlay = RainOverlay.new()
	rain_overlay.name = "RainOverlay"
	# Add to the main scene so it renders over everything
	add_child(rain_overlay)
	if weather_system:
		rain_overlay.setup(weather_system)

func _setup_placement_preview() -> void:
	"""Create placement preview overlay for building/tree/rock placement"""
	placement_preview = PlacementPreview.new()
	placement_preview.name = "PlacementPreview"
	placement_preview.set_terrain_grid(terrain_grid)
	placement_preview.set_placement_manager(placement_manager)
	placement_preview.set_camera(camera)
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

	selection_label.text = text
	selection_label.add_theme_color_override("font_color", color)

func _on_green_fee_decrease() -> void:
	"""Decrease green fee by $5"""
	GameManager.set_green_fee(GameManager.green_fee - 5)

func _on_green_fee_increase() -> void:
	"""Increase green fee by $5"""
	GameManager.set_green_fee(GameManager.green_fee + 5)

func _on_green_fee_changed(_old_fee: int, new_fee: int) -> void:
	"""Update green fee label when fee changes"""
	if green_fee_label:
		green_fee_label.text = "Fee: $%d" % new_fee

func _on_build_mode_pressed() -> void:
	"""Return to building mode from simulation"""
	if GameManager.current_mode == GameManager.GameMode.SIMULATING:
		GameManager.stop_simulation()
		print("Returned to building mode")

func _update_ui() -> void:
	# TopHUDBar now handles money/day/reputation/weather/wind updates via signals
	# Only update button states here
	_update_button_states()

func _update_button_states() -> void:
	"""Update button appearance based on game mode and speed"""
	if GameManager.current_mode == GameManager.GameMode.BUILDING:
		# In building mode, only play button is relevant
		pause_btn.disabled = true
		play_btn.disabled = false
		fast_btn.disabled = true
		play_btn.text = "▶ Start"

		# Hide build mode button when in building mode
		if build_mode_btn:
			build_mode_btn.visible = false
	else:
		# In simulation mode, all buttons are enabled
		pause_btn.disabled = false
		play_btn.disabled = false
		fast_btn.disabled = false
		play_btn.text = "▶"

		# Show build mode button in simulation
		if build_mode_btn:
			build_mode_btn.visible = true

		# Highlight active speed button
		pause_btn.modulate = Color(1, 1, 1, 0.5) if GameManager.current_speed != GameManager.GameSpeed.PAUSED else Color(1, 1, 1, 1)
		play_btn.modulate = Color(1, 1, 1, 0.5) if GameManager.current_speed != GameManager.GameSpeed.NORMAL else Color(1, 1, 1, 1)
		fast_btn.modulate = Color(1, 1, 1, 0.5) if GameManager.current_speed != GameManager.GameSpeed.FAST else Color(1, 1, 1, 1)

func _handle_mouse_hover() -> void:
	var mouse_world = camera.get_mouse_world_position()
	var grid_pos = terrain_grid.screen_to_grid(mouse_world)
	if terrain_grid.is_valid_position(grid_pos):
		var terrain_name = TerrainTypes.get_type_name(terrain_grid.get_tile(grid_pos))
		var elevation = terrain_grid.get_elevation(grid_pos)
		if elevation != 0:
			var sign_str = "+" if elevation > 0 else ""
			coordinate_label.text = "Tile: (%d, %d) - %s [Elev: %s%d]" % [grid_pos.x, grid_pos.y, terrain_name, sign_str, elevation]
		else:
			coordinate_label.text = "Tile: (%d, %d) - %s" % [grid_pos.x, grid_pos.y, terrain_name]
	else:
		coordinate_label.text = "Out of bounds"

func _start_painting() -> void:
	# Check if in null selector state - do nothing, allow clicking buildings/UI
	if not _has_active_tool():
		return

	# Check if we're in bulldozer mode
	if bulldozer_mode:
		var mouse_world = camera.get_mouse_world_position()
		var grid_pos = terrain_grid.screen_to_grid(mouse_world)
		_handle_bulldozer_click(grid_pos)
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
	for tile_pos in tiles_to_paint:
		# Skip tiles occupied by buildings
		if entity_layer and entity_layer.is_tile_occupied_by_building(tile_pos):
			continue
		if terrain_grid.get_tile(tile_pos) != current_tool:
			terrain_grid.set_tile(tile_pos, current_tool)
			total_cost += cost
	
	if total_cost > 0:
		GameManager.modify_money(-total_cost)
		EventBus.log_transaction("Terrain: " + TerrainTypes.get_type_name(current_tool), -total_cost)

func _cancel_action() -> void:
	is_painting = false
	last_paint_pos = Vector2i(-1, -1)
	if bulldozer_mode:
		_cancel_bulldozer_mode()
		print("Cancelled bulldozer mode")
	if elevation_tool.is_active():
		_cancel_elevation_mode()
		print("Cancelled elevation mode")
	if placement_manager.placement_mode != PlacementManager.PlacementMode.NONE:
		placement_manager.cancel_placement()
		print("Cancelled placement mode")
	if hole_tool.placement_mode != HoleCreationTool.PlacementMode.NONE:
		hole_tool.cancel_placement()
		print("Cancelled hole placement")
	# Enter null selector state - deselect terrain tool
	if terrain_toolbar:
		terrain_toolbar.clear_selection()
	_disable_terrain_painting_preview()
	print("Deselected all tools (null selector mode)")

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
	# Handle transition from building mode to simulation
	if GameManager.current_mode == GameManager.GameMode.BUILDING:
		# Only allow transition if trying to play (not pause)
		if speed == GameManager.GameSpeed.PAUSED:
			EventBus.notify("Course is in building mode", "info")
			return

		# Validate and start simulation
		if GameManager.start_simulation():
			print("Started simulation mode")
			# Spawn initial group of golfers
			golfer_manager.spawn_initial_group()
		return

	# Handle normal speed changes during simulation
	if GameManager.current_mode == GameManager.GameMode.SIMULATING:
		GameManager.set_speed(speed)

		var speed_name = "Paused" if speed == GameManager.GameSpeed.PAUSED else ("Fast" if speed == GameManager.GameSpeed.FAST else "Normal")
		print("Game speed: %s" % speed_name)

func _on_money_changed(_old: int, _new: int) -> void:
	pass

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

func _on_tree_placement_pressed() -> void:
	"""Show tree selection menu and start tree placement mode"""
	hole_tool.cancel_placement()
	_cancel_elevation_mode()
	_cancel_bulldozer_mode()
	_disable_terrain_painting_preview()
	is_painting = false
	if terrain_toolbar:
		terrain_toolbar.clear_selection()

	var items = [
		{"id": "oak", "label": "Oak Tree ($20)"},
		{"id": "pine", "label": "Pine Tree ($18)"},
		{"id": "maple", "label": "Maple Tree ($25)"},
		{"id": "birch", "label": "Birch Tree ($22)"},
	]
	_tree_selector.show_items("Select Tree Type", items, _on_tree_type_selected)

func _on_tree_type_selected(tree_type: String) -> void:
	"""Handle tree type selection"""
	selected_tree_type = tree_type
	placement_manager.start_tree_placement(tree_type)
	print("Tree placement mode: %s" % tree_type)

func _on_building_placement_pressed() -> void:
	"""Show building selection menu and start building placement"""
	hole_tool.cancel_placement()
	_cancel_elevation_mode()
	_cancel_bulldozer_mode()
	_disable_terrain_painting_preview()
	is_painting = false
	if terrain_toolbar:
		terrain_toolbar.clear_selection()

	if building_registry.is_empty():
		EventBus.notify("Building system not initialized!", "error")
		return

	var items = []
	for building_type in building_registry.keys():
		var building_data = building_registry[building_type]
		var name_text = building_data.get("name", building_type)
		var cost = building_data.get("cost", 0)
		var is_unique = building_data.get("required", false)
		var already_placed = is_unique and entity_layer.has_building_of_type(building_type)
		items.append({
			"id": building_type,
			"label": "%s (Already placed)" % name_text if already_placed else "%s ($%d)" % [name_text, cost],
			"disabled": already_placed,
		})
	_building_selector.show_items("Select Building", items, _on_building_type_selected, Vector2i(400, 300), 0.4)

func _on_building_type_selected(building_type: String) -> void:
	"""Handle building type selection"""
	if building_type in building_registry:
		var building_data = building_registry[building_type]
		placement_manager.start_building_placement(building_type, building_data)
		print("Building placement mode: %s" % building_type)

func _on_rock_placement_pressed() -> void:
	"""Show rock size selection menu and start rock placement mode"""
	hole_tool.cancel_placement()
	_cancel_elevation_mode()
	_cancel_bulldozer_mode()
	_disable_terrain_painting_preview()
	is_painting = false
	if terrain_toolbar:
		terrain_toolbar.clear_selection()

	var items = [
		{"id": "small", "label": "Small Rock ($10)"},
		{"id": "medium", "label": "Medium Rock ($15)"},
		{"id": "large", "label": "Large Rock ($20)"},
	]
	_rock_selector.show_items("Select Rock Size", items, _on_rock_size_selected, Vector2i(350, 200))

func _on_rock_size_selected(rock_size: String) -> void:
	"""Handle rock size selection"""
	selected_rock_size = rock_size
	placement_manager.start_rock_placement(rock_size)
	print("Rock placement mode: %s" % rock_size)

func _on_flower_bed_placement_pressed() -> void:
	"""Start flower bed painting mode"""
	_on_tool_selected(TerrainTypes.Type.FLOWER_BED)

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
	# Generate natural terrain features
	NaturalTerrainGenerator.generate(terrain_grid, entity_layer)
	print("Natural terrain generated for new course")

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

# Bulldozer removal costs
const BULLDOZER_COSTS = {
	"tree": 15,
	"rock": 10,
	"flower_bed": 20
}

func _handle_bulldozer_click(grid_pos: Vector2i) -> void:
	"""Handle bulldozer click - remove trees, rocks, or flower beds"""
	# Check for tree at position
	var tree = entity_layer.get_tree_at(grid_pos)
	if tree:
		var cost = BULLDOZER_COSTS["tree"]
		if not GameManager.can_afford(cost):
			if GameManager.is_bankrupt():
				EventBus.notify("Spending blocked! Balance below -$1,000", "error")
			else:
				EventBus.notify("Not enough money to remove tree ($%d)" % cost, "error")
			return
		GameManager.modify_money(-cost)
		EventBus.log_transaction("Remove tree", -cost)
		entity_layer.remove_tree(grid_pos)
		EventBus.notify("Tree removed (-$%d)" % cost, "info")
		return

	# Check for rock at position
	var rock = entity_layer.get_rock_at(grid_pos)
	if rock:
		var cost = BULLDOZER_COSTS["rock"]
		if not GameManager.can_afford(cost):
			if GameManager.is_bankrupt():
				EventBus.notify("Spending blocked! Balance below -$1,000", "error")
			else:
				EventBus.notify("Not enough money to remove rock ($%d)" % cost, "error")
			return
		GameManager.modify_money(-cost)
		EventBus.log_transaction("Remove rock", -cost)
		entity_layer.remove_rock(grid_pos)
		EventBus.notify("Rock removed (-$%d)" % cost, "info")
		return

	# Check for flower bed terrain
	var tile_type = terrain_grid.get_tile(grid_pos)
	if tile_type == TerrainTypes.Type.FLOWER_BED:
		var cost = BULLDOZER_COSTS["flower_bed"]
		if not GameManager.can_afford(cost):
			if GameManager.is_bankrupt():
				EventBus.notify("Spending blocked! Balance below -$1,000", "error")
			else:
				EventBus.notify("Not enough money to remove flower bed ($%d)" % cost, "error")
			return
		GameManager.modify_money(-cost)
		EventBus.log_transaction("Remove flower bed", -cost)
		terrain_grid.set_tile(grid_pos, TerrainTypes.Type.GRASS)
		EventBus.notify("Flower bed removed (-$%d)" % cost, "info")
		return

	# Nothing to remove at this position
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
	GameManager.daily_stats.calculate_operating_costs(terrain_cost, hole_count, building_costs)

	var total_cost = GameManager.daily_stats.operating_costs
	if total_cost > 0:
		GameManager.modify_money(-total_cost)
		EventBus.log_transaction("Daily operating costs", -total_cost)

	# Update course rating before showing summary
	GameManager.update_course_rating()

	# Prevent duplicate panels
	var hud = $UI/HUD
	var existing = hud.get_node_or_null("EndOfDaySummary")
	if existing:
		return

	# Create and show the end of day summary panel
	var summary = EndOfDaySummaryPanel.new(day_number)
	summary.name = "EndOfDaySummary"

	# Connect the signal BEFORE add_child (ready signal fires during add_child)
	summary.continue_pressed.connect(_on_summary_continue)

	hud.add_child(summary)

func _on_summary_continue() -> void:
	"""Called when player clicks Continue on the end of day summary."""
	GameManager.is_paused = false
	GameManager.advance_to_next_day()

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
	hud.add_child(panel)

func _on_load_completed(_success: bool) -> void:
	if _success:
		_rebuild_hole_list()

# --- Undo/Redo System ---

var _is_undoing: bool = false  # Prevent re-recording changes triggered by undo/redo

func _on_terrain_tile_changed_for_undo(position: Vector2i, old_type: int, new_type: int) -> void:
	if _is_undoing:
		# Tile change during undo/redo, don't re-record
		return
	undo_manager.record_tile_change(position, old_type, new_type)

func _perform_undo() -> void:
	if GameManager.current_mode != GameManager.GameMode.BUILDING:
		EventBus.notify("Undo only available in build mode", "info")
		return
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
	if GameManager.current_mode != GameManager.GameMode.BUILDING:
		EventBus.notify("Redo only available in build mode", "info")
		return
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
	hud.add_child(staff_panel)

	# Note: Money click is now handled by TopHUDBar.money_clicked signal

func _on_money_clicked() -> void:
	## Toggle the financial panel when money is clicked.
	financial_panel.toggle()

func _on_financial_panel_closed() -> void:
	"""Hide the financial panel."""
	financial_panel.hide()

func _on_staff_pressed() -> void:
	## Toggle staff management panel.
	if staff_panel:
		staff_panel.toggle()

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
			hole_stats_panel.show_for_hole(hole)
			# Center the panel on screen
			var viewport_size = get_viewport().get_visible_rect().size
			hole_stats_panel.position = (viewport_size - hole_stats_panel.custom_minimum_size) / 2
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

func _toggle_tournament_panel() -> void:
	"""Toggle the tournament panel visibility."""
	tournament_panel.toggle()

func _toggle_terrain_debug_overlay() -> void:
	"""Toggle the terrain debug overlay (F3)."""
	if terrain_grid:
		terrain_grid.toggle_debug_overlay()

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
	if EventBus.green_fee_changed.is_connected(_on_green_fee_changed):
		EventBus.green_fee_changed.disconnect(_on_green_fee_changed)
	if EventBus.end_of_day.is_connected(_on_end_of_day):
		EventBus.end_of_day.disconnect(_on_end_of_day)
	if EventBus.load_completed.is_connected(_on_load_completed):
		EventBus.load_completed.disconnect(_on_load_completed)
	if EventBus.new_game_started.is_connected(_on_new_game_started):
		EventBus.new_game_started.disconnect(_on_new_game_started)
