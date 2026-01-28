extends Node2D
## Main - Primary game scene controller

@onready var terrain_grid: TerrainGrid = $TerrainGrid
@onready var camera: IsometricCamera = $IsometricCamera
@onready var money_label: Label = $UI/HUD/TopBar/MoneyLabel
@onready var day_label: Label = $UI/HUD/TopBar/DayLabel
@onready var reputation_label: Label = $UI/HUD/TopBar/ReputationLabel
@onready var coordinate_label: Label = $UI/HUD/BottomBar/CoordinateLabel
@onready var tool_panel: VBoxContainer = $UI/HUD/ToolPanel
@onready var hole_list: VBoxContainer = $UI/HUD/HoleInfoPanel/VBoxContainer/ScrollContainer/HoleList

var current_tool: int = TerrainTypes.Type.FAIRWAY
var brush_size: int = 1
var is_painting: bool = false
var last_paint_pos: Vector2i = Vector2i(-1, -1)

var hole_tool: HoleCreationTool = HoleCreationTool.new()
var placement_manager: PlacementManager = PlacementManager.new()
var building_registry: Node = null
var entity_layer: EntityLayer = null

func _ready() -> void:
	# Set terrain grid reference in GameManager
	GameManager.terrain_grid = terrain_grid

	# Initialize building registry and entity layer
	building_registry = Node.new()
	add_child(building_registry)
	building_registry.script = load("res://scripts/managers/building_registry.gd")
	
	entity_layer = EntityLayer.new()
	add_child(entity_layer)
	entity_layer.set_terrain_grid(terrain_grid)
	entity_layer.set_building_registry(building_registry)

	# Add hole creation tool
	add_child(hole_tool)

	_connect_signals()
	_connect_ui_buttons()
	_initialize_game()
	print("Main scene ready")

func _process(_delta: float) -> void:
	_update_ui()
	_handle_mouse_hover()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("select"):
		_start_painting()
	elif event.is_action_released("select"):
		_stop_painting()
	if event.is_action_pressed("cancel"):
		_cancel_action()
	if is_painting and event is InputEventMouseMotion:
		_paint_at_mouse()

func _connect_signals() -> void:
	EventBus.connect("money_changed", _on_money_changed)
	EventBus.connect("day_changed", _on_day_changed)
	EventBus.connect("hole_created", _on_hole_created)

func _connect_ui_buttons() -> void:
	tool_panel.get_node("FairwayBtn").pressed.connect(_on_tool_selected.bind(TerrainTypes.Type.FAIRWAY))
	tool_panel.get_node("RoughBtn").pressed.connect(_on_tool_selected.bind(TerrainTypes.Type.ROUGH))
	tool_panel.get_node("GreenBtn").pressed.connect(_on_tool_selected.bind(TerrainTypes.Type.GREEN))
	tool_panel.get_node("BunkerBtn").pressed.connect(_on_tool_selected.bind(TerrainTypes.Type.BUNKER))
	tool_panel.get_node("WaterBtn").pressed.connect(_on_tool_selected.bind(TerrainTypes.Type.WATER))
	tool_panel.get_node("PathBtn").pressed.connect(_on_tool_selected.bind(TerrainTypes.Type.PATH))
	tool_panel.get_node("TeeBtn").pressed.connect(_on_tool_selected.bind(TerrainTypes.Type.TEE_BOX))
	tool_panel.get_node("CreateHoleBtn").pressed.connect(_on_create_hole_pressed)

	$UI/HUD/BottomBar/SpeedControls/PauseBtn.pressed.connect(_on_speed_selected.bind(GameManager.GameSpeed.PAUSED))
	$UI/HUD/BottomBar/SpeedControls/PlayBtn.pressed.connect(_on_speed_selected.bind(GameManager.GameSpeed.NORMAL))
	$UI/HUD/BottomBar/SpeedControls/FastBtn.pressed.connect(_on_speed_selected.bind(GameManager.GameSpeed.FAST))
	
	# Connect building and tree placement buttons if they exist
	if tool_panel.has_node("TreeBtn"):
		tool_panel.get_node("TreeBtn").pressed.connect(_on_tree_placement_pressed)
	if tool_panel.has_node("BuildingBtn"):
		tool_panel.get_node("BuildingBtn").pressed.connect(_on_building_placement_pressed)

func _initialize_game() -> void:
	GameManager.new_game("My Golf Course")
	# Center camera on the middle of the grid
	var center_x = (terrain_grid.grid_width / 2) * terrain_grid.tile_width
	var center_y = (terrain_grid.grid_height / 2) * terrain_grid.tile_height
	camera.focus_on(Vector2(center_x, center_y), true)

func _update_ui() -> void:
	money_label.text = "$%d" % GameManager.money
	day_label.text = "Day %d - %s" % [GameManager.current_day, GameManager.get_time_string()]
	reputation_label.text = "Rep: %.0f" % GameManager.reputation

func _handle_mouse_hover() -> void:
	var mouse_world = camera.get_mouse_world_position()
	var grid_pos = terrain_grid.screen_to_grid(mouse_world)
	if terrain_grid.is_valid_position(grid_pos):
		var terrain_name = TerrainTypes.get_type_name(terrain_grid.get_tile(grid_pos))
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

	is_painting = true
	_paint_at_mouse()

func _stop_painting() -> void:
	is_painting = false
	last_paint_pos = Vector2i(-1, -1)

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
	if placement_manager.placement_mode != PlacementManager.PlacementMode.NONE:
		placement_manager.cancel_placement()
		print("Cancelled placement mode")

func _on_tool_selected(tool_type: int) -> void:
	# Cancel any hole placement
	hole_tool.cancel_placement()

	current_tool = tool_type
	print("Tool selected: " + TerrainTypes.get_type_name(tool_type))

func _on_create_hole_pressed() -> void:
	hole_tool.start_tee_placement()

func _on_speed_selected(speed: int) -> void:
	GameManager.set_speed(speed)

func _on_money_changed(_old: int, _new: int) -> void:
	pass

func _on_day_changed(new_day: int) -> void:
	var maintenance = terrain_grid.get_total_maintenance_cost()
	if maintenance > 0:
		GameManager.modify_money(-maintenance)
		EventBus.log_transaction("Daily maintenance", -maintenance)

func _on_hole_created(hole_number: int, par: int, distance_yards: int) -> void:
	var hole_label = Label.new()
	hole_label.text = "Hole %d: Par %d (%d yds)" % [hole_number, par, distance_yards]
	hole_list.add_child(hole_label)

func _on_tree_placement_pressed() -> void:
	"""Start tree placement mode"""
	hole_tool.cancel_placement()
	is_painting = false
	placement_manager.start_tree_placement()

func _on_building_placement_pressed() -> void:
	"""Show building selection menu and start building placement"""
	hole_tool.cancel_placement()
	is_painting = false
	# For now, just start with clubhouse as default
	if building_registry:
		var clubhouse_data = building_registry.get_building("clubhouse")
		if not clubhouse_data.is_empty():
			placement_manager.start_building_placement("clubhouse", clubhouse_data)

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

func _place_tree(grid_pos: Vector2i, cost: int) -> void:
	"""Place a tree at the grid position"""
	entity_layer.place_tree(grid_pos, "oak")
	GameManager.modify_money(-cost)
	EventBus.log_transaction("Tree placement", -cost)
	print("Placed tree at %s" % grid_pos)

func _place_building(grid_pos: Vector2i, cost: int) -> void:
	"""Place a building at the grid position"""
	var building_type = placement_manager.selected_building_type
	var building = entity_layer.place_building(building_type, grid_pos, building_registry)
	
	if building:
		GameManager.modify_money(-cost)
		EventBus.log_transaction("Building: %s" % building_registry.get_building_name(building_type), -cost)
		print("Placed %s at %s" % [building_type, grid_pos])
	else:
		EventBus.notify("Failed to place building!", "error")

