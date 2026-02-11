extends Node2D
## Main - Primary game scene controller

@onready var terrain_grid: TerrainGrid = $TerrainGrid
@onready var camera: IsometricCamera = $IsometricCamera
@onready var ball_manager: BallManager = $BallManager
@onready var hole_manager: HoleManager = $HoleManager
@onready var golfer_manager: GolferManager = $GolferManager
@onready var money_label: Label = $UI/HUD/TopBar/MoneyLabel
@onready var day_label: Label = $UI/HUD/TopBar/DayLabel
@onready var reputation_label: Label = $UI/HUD/TopBar/ReputationLabel
@onready var coordinate_label: Label = $UI/HUD/BottomBar/CoordinateLabel
@onready var tool_panel_container: Control = $UI/HUD/ToolPanel
var terrain_toolbar: TerrainToolbar = null
@onready var hole_list: VBoxContainer = $UI/HUD/HoleInfoPanel/VBoxContainer/ScrollContainer/HoleList
@onready var pause_btn: Button = $UI/HUD/BottomBar/SpeedControls/PauseBtn
@onready var play_btn: Button = $UI/HUD/BottomBar/SpeedControls/PlayBtn
@onready var fast_btn: Button = $UI/HUD/BottomBar/SpeedControls/FastBtn
@onready var speed_controls: HBoxContainer = $UI/HUD/BottomBar/SpeedControls

var game_mode_label: Label = null
var build_mode_btn: Button = null
var green_fee_label: Label = null
var green_fee_decrease_btn: Button = null
var green_fee_increase_btn: Button = null

var current_tool: int = TerrainTypes.Type.FAIRWAY
var brush_size: int = 1
var is_painting: bool = false
var last_paint_pos: Vector2i = Vector2i(-1, -1)

var hole_tool: HoleCreationTool = HoleCreationTool.new()
var placement_manager: PlacementManager = PlacementManager.new()
var undo_manager: UndoManager = UndoManager.new()
var wind_system: WindSystem = null
var wind_indicator: WindIndicator = null
var day_night_system: DayNightSystem = null
var elevation_tool: ElevationTool = ElevationTool.new()
var building_registry: Dictionary = {}
var entity_layer: EntityLayer = null
var building_info_panel: BuildingInfoPanel = null
var financial_panel: FinancialPanel = null
var mini_map: MiniMap = null
var hole_stats_panel: HoleStatsPanel = null
var selected_tree_type: String = "oak"
var selected_rock_size: String = "medium"

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

	# Add elevation tool
	add_child(elevation_tool)

	# Set up day/night cycle
	day_night_system = DayNightSystem.new()
	day_night_system.name = "DayNightSystem"
	add_child(day_night_system)

	# Set up save manager references
	SaveManager.set_references(terrain_grid, entity_layer, golfer_manager, ball_manager)

	_connect_signals()
	_connect_ui_buttons()
	_create_game_mode_label()
	_create_green_fee_controls()
	_create_wind_indicator()
	_create_save_load_button()
	_setup_building_info_panel()
	_setup_financial_panel()
	_setup_mini_map()
	_setup_hole_stats_panel()
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

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("select"):
		_start_painting()
	elif event.is_action_released("select"):
		_stop_painting()
	if event.is_action_pressed("cancel"):
		_cancel_action()
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

	# Create and add new toolbar
	terrain_toolbar = TerrainToolbar.new()
	terrain_toolbar.name = "TerrainToolbar"
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

func _initialize_game() -> void:
	GameManager.new_game("My Golf Course")
	# Center camera on the middle of the grid
	var center_x = (terrain_grid.grid_width / 2) * terrain_grid.tile_width
	var center_y = (terrain_grid.grid_height / 2) * terrain_grid.tile_height
	camera.focus_on(Vector2(center_x, center_y), true)

func _create_game_mode_label() -> void:
	"""Create a label to show the current game mode"""
	game_mode_label = Label.new()
	game_mode_label.name = "GameModeLabel"

	# Add theme overrides for visibility
	game_mode_label.add_theme_font_size_override("font_size", 18)

	# Insert as first child in top bar
	var top_bar = $UI/HUD/TopBar
	top_bar.add_child(game_mode_label)
	top_bar.move_child(game_mode_label, 0)

	# Create "Build Mode" button to return from simulation
	build_mode_btn = Button.new()
	build_mode_btn.name = "BuildModeBtn"
	build_mode_btn.text = "🔨 Build"
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

func _create_wind_indicator() -> void:
	wind_indicator = WindIndicator.new()
	wind_indicator.name = "WindIndicator"
	var bottom_bar = $UI/HUD/BottomBar
	bottom_bar.add_child(wind_indicator)
	# Set initial wind state
	if wind_system:
		wind_indicator.set_wind(wind_system.wind_direction, wind_system.wind_speed)

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
	# Update money with trend indicator
	var trend_indicator = ""
	if GameManager.yesterday_stats != null:
		var today_profit = GameManager.daily_stats.get_profit()
		var yesterday_profit = GameManager.yesterday_stats.get_profit()
		if today_profit > yesterday_profit:
			trend_indicator = " ^"  # Up arrow
		elif today_profit < yesterday_profit:
			trend_indicator = " v"  # Down arrow
	money_label.text = "$%d%s" % [GameManager.money, trend_indicator]
	day_label.text = "Day %d - %s" % [GameManager.current_day, GameManager.get_time_string()]
	reputation_label.text = "Rep: %.0f" % GameManager.reputation

	# Update game mode label
	if game_mode_label:
		match GameManager.current_mode:
			GameManager.GameMode.BUILDING:
				game_mode_label.text = "🔨 BUILDING MODE"
				game_mode_label.add_theme_color_override("font_color", Color(0.8, 0.6, 0.2))
			GameManager.GameMode.SIMULATING:
				var speed_text = ""
				match GameManager.current_speed:
					GameManager.GameSpeed.PAUSED:
						speed_text = "⏸ PAUSED"
					GameManager.GameSpeed.NORMAL:
						speed_text = "▶ PLAYING"
					GameManager.GameSpeed.FAST:
						speed_text = "⏩ FAST"
				game_mode_label.text = speed_text
				game_mode_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
			_:
				game_mode_label.text = "MODE: %s" % GameManager.current_mode

	# Update button states
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
		hole_tool.handle_click(grid_pos)
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
	if cost > 0 and GameManager.money < cost:
		EventBus.notify("Not enough money!", "error")
		return
	
	var tiles_to_paint = [grid_pos] if brush_size <= 1 else terrain_grid.get_brush_tiles(grid_pos, brush_size)
	var total_cost = 0
	for tile_pos in tiles_to_paint:
		if terrain_grid.get_tile(tile_pos) != current_tool:
			terrain_grid.set_tile(tile_pos, current_tool)
			total_cost += cost
	
	if total_cost > 0:
		GameManager.modify_money(-total_cost)
		EventBus.log_transaction("Terrain: " + TerrainTypes.get_type_name(current_tool), -total_cost)

func _cancel_action() -> void:
	is_painting = false
	last_paint_pos = Vector2i(-1, -1)
	if elevation_tool.is_active():
		_cancel_elevation_mode()
		print("Cancelled elevation mode")
	if placement_manager.placement_mode != PlacementManager.PlacementMode.NONE:
		placement_manager.cancel_placement()
		print("Cancelled placement mode")

func _on_tool_selected(tool_type: int) -> void:
	# Cancel any hole placement, building/tree placement, and elevation mode
	hole_tool.cancel_placement()
	placement_manager.cancel_placement()
	_cancel_elevation_mode()
	is_painting = false

	current_tool = tool_type
	# Update toolbar highlight
	if terrain_toolbar:
		terrain_toolbar.set_current_tool(tool_type)
	print("Tool selected: " + TerrainTypes.get_type_name(tool_type))

func _on_create_hole_pressed() -> void:
	# Cancel any building/tree placement, elevation, or terrain painting
	placement_manager.cancel_placement()
	_cancel_elevation_mode()
	is_painting = false
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
	is_painting = false

	# Create tree selection dialog
	var dialog = AcceptDialog.new()
	dialog.title = "Select Tree Type"
	dialog.size = Vector2i(350, 250)

	var vbox = VBoxContainer.new()

	# Add button for each tree type
	var tree_types = {
		"oak": {"name": "Oak Tree", "cost": 20},
		"pine": {"name": "Pine Tree", "cost": 18},
		"maple": {"name": "Maple Tree", "cost": 25},
		"birch": {"name": "Birch Tree", "cost": 22}
	}

	for tree_type in tree_types.keys():
		var tree_data = tree_types[tree_type]
		var btn = Button.new()
		btn.text = "%s ($%d)" % [tree_data["name"], tree_data["cost"]]
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
	is_painting = false
	
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
	is_painting = false

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

func _on_flower_bed_placement_pressed() -> void:
	"""Flower bed placement - to be implemented"""
	EventBus.notify("Flower beds coming soon!", "info")

func _on_raise_elevation_pressed() -> void:
	hole_tool.cancel_placement()
	placement_manager.cancel_placement()
	is_painting = false
	elevation_tool.start_raising()
	terrain_grid.set_elevation_overlay_active(true)
	print("Elevation mode: RAISING")

func _on_lower_elevation_pressed() -> void:
	hole_tool.cancel_placement()
	placement_manager.cancel_placement()
	is_painting = false
	elevation_tool.start_lowering()
	terrain_grid.set_elevation_overlay_active(true)
	print("Elevation mode: LOWERING")

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

	var changes = elevation_tool.paint_elevation(grid_pos, terrain_grid, brush_size)
	if not changes.is_empty():
		undo_manager.record_elevation_stroke(changes)

func _handle_placement_click(grid_pos: Vector2i) -> void:
	"""Handle clicking during building/tree placement"""
	if not placement_manager.can_place_at(grid_pos, terrain_grid):
		EventBus.notify("Cannot place here!", "error")
		return
	
	var cost = placement_manager.get_placement_cost()
	if cost > 0 and GameManager.money < cost:
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
	else:
		EventBus.notify("Failed to place rock!", "error")

# --- Day/Night Cycle ---

func _on_end_of_day(day_number: int) -> void:
	"""Handle end of day — show summary panel."""
	# Pause the game while showing the summary
	GameManager.is_paused = true

	# Calculate and deduct operating costs BEFORE showing summary
	var terrain_cost = terrain_grid.get_total_maintenance_cost()
	var hole_count = GameManager.current_course.holes.size() if GameManager.current_course else 0
	GameManager.daily_stats.calculate_operating_costs(terrain_cost, hole_count)

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

	# Center the panel on screen (use custom_minimum_size since layout happens next frame)
	var viewport_size = get_viewport().get_visible_rect().size
	summary.position = (viewport_size - summary.custom_minimum_size) / 2

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
	panel.anchors_preset = Control.PRESET_CENTER
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
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
	"""Add financial panel to the HUD and make money label clickable."""
	var hud = $UI/HUD

	# Create financial panel
	financial_panel = FinancialPanel.new()
	financial_panel.name = "FinancialPanel"
	financial_panel.close_requested.connect(_on_financial_panel_closed)
	hud.add_child(financial_panel)
	financial_panel.hide()

	# Make money label clickable by wrapping it in a button-like container
	var money_btn = Button.new()
	money_btn.name = "MoneyButton"
	money_btn.flat = true
	money_btn.pressed.connect(_on_money_clicked)
	money_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	# Get the parent and index of the money label
	var top_bar = money_label.get_parent()
	var label_index = money_label.get_index()

	# Remove the label, add it to button, then add button to top bar
	top_bar.remove_child(money_label)
	money_btn.add_child(money_label)
	top_bar.add_child(money_btn)
	top_bar.move_child(money_btn, label_index)

	# Update reference to still point to the label
	money_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _on_money_clicked() -> void:
	"""Toggle the financial panel when money is clicked."""
	financial_panel.toggle()
	if financial_panel.visible:
		# Center the panel on screen
		var viewport_size = get_viewport().get_visible_rect().size
		financial_panel.position = (viewport_size - financial_panel.custom_minimum_size) / 2

func _on_financial_panel_closed() -> void:
	"""Hide the financial panel."""
	financial_panel.hide()

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
