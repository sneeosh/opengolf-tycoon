extends RefCounted
class_name PlacementManager
## PlacementManager - Handles placement of buildings and trees on the course

signal placement_mode_changed(mode: PlacementMode)
signal placement_preview_updated(grid_pos: Vector2i, valid: bool)

enum PlacementMode {
	NONE = 0,
	BUILDING = 1,
	TREE = 2,
	ROCK = 3,
	DECORATION = 4
}

var placement_mode: PlacementMode = PlacementMode.NONE
var selected_building_type: String = ""
var selected_tree_type: String = "oak"
var selected_rock_size: String = "medium"
var selected_decoration_type: String = ""
var selected_decoration_data: Dictionary = {}
var current_placement_data: Dictionary = {}

func start_building_placement(building_type: String, building_data: Dictionary) -> void:
	placement_mode = PlacementMode.BUILDING
	selected_building_type = building_type
	current_placement_data = building_data.duplicate(true)
	placement_mode_changed.emit(placement_mode)
	print("Started building placement: %s" % building_type)

func start_tree_placement(tree_type: String = "oak") -> void:
	placement_mode = PlacementMode.TREE
	selected_building_type = ""
	selected_tree_type = tree_type
	current_placement_data = {}
	placement_mode_changed.emit(placement_mode)
	print("Started tree placement: %s" % tree_type)

func start_rock_placement(rock_size: String = "medium") -> void:
	placement_mode = PlacementMode.ROCK
	selected_building_type = ""
	selected_rock_size = rock_size
	current_placement_data = {}
	placement_mode_changed.emit(placement_mode)
	print("Started rock placement: %s" % rock_size)

func start_decoration_placement(dec_type: String, dec_data: Dictionary) -> void:
	placement_mode = PlacementMode.DECORATION
	selected_building_type = ""
	selected_decoration_type = dec_type
	selected_decoration_data = dec_data.duplicate(true)
	current_placement_data = dec_data.duplicate(true)
	placement_mode_changed.emit(placement_mode)
	print("Started decoration placement: %s" % dec_type)

func cancel_placement() -> void:
	placement_mode = PlacementMode.NONE
	selected_building_type = ""
	selected_decoration_type = ""
	selected_decoration_data = {}
	current_placement_data = {}
	placement_mode_changed.emit(placement_mode)

func can_place_at(grid_pos: Vector2i, terrain_grid: TerrainGrid) -> bool:
	if placement_mode == PlacementMode.NONE:
		return false

	if placement_mode == PlacementMode.TREE:
		return _can_place_tree(grid_pos, terrain_grid)
	elif placement_mode == PlacementMode.BUILDING:
		return _can_place_building(grid_pos, terrain_grid)
	elif placement_mode == PlacementMode.ROCK:
		return _can_place_rock(grid_pos, terrain_grid)
	elif placement_mode == PlacementMode.DECORATION:
		return _can_place_decoration(grid_pos, terrain_grid)

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

func _can_place_rock(grid_pos: Vector2i, terrain_grid: TerrainGrid) -> bool:
	# Rocks can be placed on grass, rough, fairway, and heavy rough
	if not terrain_grid.is_valid_position(grid_pos):
		return false

	var tile_type = terrain_grid.get_tile(grid_pos)
	return tile_type in [
		TerrainTypes.Type.GRASS,
		TerrainTypes.Type.FAIRWAY,
		TerrainTypes.Type.ROUGH,
		TerrainTypes.Type.HEAVY_ROUGH
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
			
			# Buildings can be placed on any grass-type terrain
			# placeable_on_course buildings can also be placed on path
			var valid_tiles = [
				TerrainTypes.Type.GRASS,
				TerrainTypes.Type.ROUGH,
				TerrainTypes.Type.HEAVY_ROUGH,
				TerrainTypes.Type.FAIRWAY
			]
			if placeable_on_course:
				valid_tiles += [TerrainTypes.Type.PATH]
			
			if not (tile_type in valid_tiles):
				return false
	
	return true

func _can_place_decoration(grid_pos: Vector2i, terrain_grid: TerrainGrid) -> bool:
	if not terrain_grid.is_valid_position(grid_pos):
		return false

	var sz = selected_decoration_data.get("size", [1, 1])
	var width = int(sz[0])
	var height = int(sz[1])
	var placeable = selected_decoration_data.get("placeable_terrain", ["grass"])

	# Map terrain name strings to TerrainTypes
	var valid_types: Array = []
	for terrain_name in placeable:
		match terrain_name:
			"grass": valid_types.append(TerrainTypes.Type.GRASS)
			"fairway": valid_types.append(TerrainTypes.Type.FAIRWAY)
			"rough": valid_types.append(TerrainTypes.Type.ROUGH)
			"heavy_rough": valid_types.append(TerrainTypes.Type.HEAVY_ROUGH)
			"path": valid_types.append(TerrainTypes.Type.PATH)

	for x in range(width):
		for y in range(height):
			var check_pos = grid_pos + Vector2i(x, y)
			if not terrain_grid.is_valid_position(check_pos):
				return false
			var tile_type = terrain_grid.get_tile(check_pos)
			if not (tile_type in valid_types):
				return false

	return true

func get_placement_cost() -> int:
	if placement_mode == PlacementMode.TREE:
		var tree_data = TreeEntity.TREE_PROPERTIES.get(selected_tree_type, {})
		return tree_data.get("cost", 20)
	elif placement_mode == PlacementMode.ROCK:
		# Return cost based on rock size
		var rock_costs = {
			"small": 10,
			"medium": 15,
			"large": 20
		}
		return rock_costs.get(selected_rock_size, 15)
	elif placement_mode == PlacementMode.BUILDING:
		return current_placement_data.get("cost", 0)
	elif placement_mode == PlacementMode.DECORATION:
		return selected_decoration_data.get("cost", 0)

	return 0

func get_placement_footprint() -> Array:
	"""Returns array of Vector2i positions for building or decoration footprint"""
	if placement_mode != PlacementMode.BUILDING and placement_mode != PlacementMode.DECORATION:
		return []

	var size = current_placement_data.get("size", [1, 1])
	var width = size[0] as int
	var height = size[1] as int
	var footprint: Array = []

	for x in range(width):
		for y in range(height):
			footprint.append(Vector2i(x, y))

	return footprint

func get_building_footprint() -> Array:
	"""Returns array of Vector2i positions for building footprint (legacy, calls get_placement_footprint)"""
	return get_placement_footprint()
