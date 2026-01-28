extends RefCounted
class_name PlacementManager
## PlacementManager - Handles placement of buildings and trees on the course

signal placement_mode_changed(mode: PlacementMode)
signal placement_preview_updated(grid_pos: Vector2i, valid: bool)

enum PlacementMode {
	NONE = 0,
	BUILDING = 1,
	TREE = 2
}

var placement_mode: PlacementMode = PlacementMode.NONE
var selected_building_type: String = ""
var current_placement_data: Dictionary = {}

func start_building_placement(building_type: String, building_data: Dictionary) -> void:
	placement_mode = PlacementMode.BUILDING
	selected_building_type = building_type
	current_placement_data = building_data.duplicate(true)
	placement_mode_changed.emit(placement_mode)
	print("Started building placement: %s" % building_type)

func start_tree_placement() -> void:
	placement_mode = PlacementMode.TREE
	selected_building_type = ""
	current_placement_data = {}
	placement_mode_changed.emit(placement_mode)
	print("Started tree placement")

func cancel_placement() -> void:
	placement_mode = PlacementMode.NONE
	selected_building_type = ""
	current_placement_data = {}
	placement_mode_changed.emit(placement_mode)

func can_place_at(grid_pos: Vector2i, terrain_grid: TerrainGrid) -> bool:
	if placement_mode == PlacementMode.NONE:
		return false
	
	if placement_mode == PlacementMode.TREE:
		return _can_place_tree(grid_pos, terrain_grid)
	elif placement_mode == PlacementMode.BUILDING:
		return _can_place_building(grid_pos, terrain_grid)
	
	return false

func _can_place_tree(grid_pos: Vector2i, terrain_grid: TerrainGrid) -> bool:
	# Trees can be placed on grass, rough, fairway, heavy rough, and path
	if not terrain_grid.is_valid_position(grid_pos):
		return false
	
	var tile_type = terrain_grid.get_tile(grid_pos)
	return tile_type in [
		TerrainTypes.Type.GRASS,
		TerrainTypes.Type.FAIRWAY,
		TerrainTypes.Type.ROUGH,
		TerrainTypes.Type.HEAVY_ROUGH,
		TerrainTypes.Type.PATH
	]

func _can_place_building(grid_pos: Vector2i, terrain_grid: TerrainGrid) -> bool:
	if not terrain_grid.is_valid_position(grid_pos):
		return false
	
	var size = current_placement_data.get("size", [1, 1])
	var width = size[0] as int
	var height = size[1] as int
	var placeable_on_course = current_placement_data.get("placeable_on_course", false)
	
	# Check all tiles that the building would occupy
	for x in range(width):
		for y in range(height):
			var check_pos = grid_pos + Vector2i(x, y)
			if not terrain_grid.is_valid_position(check_pos):
				return false
			
			var tile_type = terrain_grid.get_tile(check_pos)
			
			# Buildings can be placed on grass by default
			# placeable_on_course buildings can also be placed on fairway, path, etc.
			var valid_tiles = [TerrainTypes.Type.GRASS]
			if placeable_on_course:
				valid_tiles += [
					TerrainTypes.Type.FAIRWAY,
					TerrainTypes.Type.ROUGH,
					TerrainTypes.Type.PATH
				]
			
			if not (tile_type in valid_tiles):
				return false
	
	return true

func get_placement_cost() -> int:
	if placement_mode == PlacementMode.TREE:
		return 20  # Trees cost $20
	elif placement_mode == PlacementMode.BUILDING:
		return current_placement_data.get("cost", 0)
	
	return 0

func get_building_footprint() -> Array:
	"""Returns array of Vector2i positions for building footprint"""
	if placement_mode != PlacementMode.BUILDING:
		return []
	
	var size = current_placement_data.get("size", [1, 1])
	var width = size[0] as int
	var height = size[1] as int
	var footprint: Array = []
	
	for x in range(width):
		for y in range(height):
			footprint.append(Vector2i(x, y))
	
	return footprint
