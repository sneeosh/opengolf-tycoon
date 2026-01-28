extends Node2D
class_name PlacementPreview
## PlacementPreview - Shows preview of where buildings/trees will be placed

var terrain_grid: TerrainGrid
var placement_manager: PlacementManager
var camera: IsometricCamera

var current_preview_valid: bool = false
var current_preview_positions: Array = []

func _ready() -> void:
	set_process(true)

func _process(_delta: float) -> void:
	if placement_manager and placement_manager.placement_mode != PlacementManager.PlacementMode.NONE:
		_update_preview()
	else:
		queue_redraw()

func set_terrain_grid(grid: TerrainGrid) -> void:
	terrain_grid = grid

func set_placement_manager(manager: PlacementManager) -> void:
	placement_manager = manager

func set_camera(cam: IsometricCamera) -> void:
	camera = cam

func _update_preview() -> void:
	if not terrain_grid or not camera:
		return
	
	var mouse_world = camera.get_mouse_world_position()
	var grid_pos = terrain_grid.screen_to_grid(mouse_world)
	
	# Get positions to preview
	if placement_manager.placement_mode == PlacementManager.PlacementMode.TREE:
		current_preview_positions = [grid_pos]
	elif placement_manager.placement_mode == PlacementManager.PlacementMode.BUILDING:
		current_preview_positions = _get_building_footprint(grid_pos)
	
	# Check validity
	current_preview_valid = placement_manager.can_place_at(grid_pos, terrain_grid)
	queue_redraw()

func _get_building_footprint(grid_pos: Vector2i) -> Array:
	var footprint = placement_manager.get_building_footprint()
	var result: Array = []
	for offset in footprint:
		result.append(grid_pos + offset)
	return result

func _draw() -> void:
	if placement_manager.placement_mode == PlacementManager.PlacementMode.NONE:
		return
	
	if not terrain_grid:
		return
	
	var color = Color.GREEN if current_preview_valid else Color.RED
	color.a = 0.3
	
	for grid_pos in current_preview_positions:
		if terrain_grid.is_valid_position(grid_pos):
			var world_pos = terrain_grid.grid_to_screen(grid_pos)
			var size = Vector2(terrain_grid.tile_width, terrain_grid.tile_height)
			draw_rect(Rect2(world_pos, size), color)
			draw_rect(Rect2(world_pos, size), Color.WHITE if current_preview_valid else Color.RED, false, 2.0)

func get_preview_valid() -> bool:
	return current_preview_valid

func get_preview_positions() -> Array:
	return current_preview_positions
