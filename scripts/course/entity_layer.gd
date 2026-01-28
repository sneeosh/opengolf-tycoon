extends Node2D
class_name EntityLayer
## EntityLayer - Manages all placed buildings and trees on the course

var buildings: Dictionary = {}  # key: Vector2i (grid_pos), value: Building node
var trees: Dictionary = {}      # key: Vector2i (grid_pos), value: Tree node

var terrain_grid: TerrainGrid
var building_registry: Dictionary = {}  # Can accept either Node or Dictionary

signal building_placed(building: Building, cost: int)
signal tree_placed(tree: Tree, cost: int)
signal building_removed(grid_pos: Vector2i)
signal tree_removed(grid_pos: Vector2i)

@onready var buildings_container = Node2D.new()
@onready var trees_container = Node2D.new()

func _ready() -> void:
	buildings_container.name = "Buildings"
	trees_container.name = "Trees"
	add_child(buildings_container)
	add_child(trees_container)

func set_terrain_grid(grid: TerrainGrid) -> void:
	terrain_grid = grid

func set_building_registry(registry) -> void:
	building_registry = registry

func place_building(building_type: String, grid_pos: Vector2i, building_registry) -> Building:
	"""Place a building at the specified grid position"""
	if building_registry == null or (building_registry is Dictionary and building_registry.is_empty()):
		push_error("Building registry not set")
		return null
	
	var building_data
	if building_registry is Dictionary:
		building_data = building_registry.get(building_type, {})
	else:
		# Support legacy Node-based registry
		building_data = building_registry.get_building(building_type) if building_registry.has_method("get_building") else {}
	
	if building_data.is_empty():
		push_error("Unknown building type: %s" % building_type)
		return null
	
	var building = Building.new()
	building.building_type = building_type
	building.set_terrain_grid(terrain_grid)
	building.set_position_in_grid(grid_pos)
	
	buildings_container.add_child(building)
	
	# Store by grid position
	buildings[grid_pos] = building
	
	# Connect signals
	building.building_selected.connect(_on_building_selected)
	building.building_destroyed.connect(_on_building_destroyed)
	
	building_placed.emit(building, building_data.get("cost", 0))
	return building

func place_tree(grid_pos: Vector2i, tree_type: String = "oak") -> Tree:
	"""Place a tree at the specified grid position"""
	var tree = Tree.new()
	tree.tree_type = tree_type
	tree.set_terrain_grid(terrain_grid)
	tree.set_position_in_grid(grid_pos)
	
	trees_container.add_child(tree)
	
	# Store by grid position
	trees[grid_pos] = tree
	
	# Connect signals
	tree.tree_selected.connect(_on_tree_selected)
	tree.tree_destroyed.connect(_on_tree_destroyed)
	
	tree_placed.emit(tree, 20)  # Tree cost is hardcoded to 20
	return tree

func get_building_at(grid_pos: Vector2i) -> Building:
	return buildings.get(grid_pos, null)

func get_tree_at(grid_pos: Vector2i) -> Tree:
	return trees.get(grid_pos, null)

func get_buildings_in_area(top_left: Vector2i, bottom_right: Vector2i) -> Array:
	"""Get all buildings within the specified area"""
	var result: Array = []
	for pos in buildings.keys():
		if pos.x >= top_left.x and pos.x <= bottom_right.x and \
		   pos.y >= top_left.y and pos.y <= bottom_right.y:
			result.append(buildings[pos])
	return result

func get_trees_in_area(top_left: Vector2i, bottom_right: Vector2i) -> Array:
	"""Get all trees within the specified area"""
	var result: Array = []
	for pos in trees.keys():
		if pos.x >= top_left.x and pos.x <= bottom_right.x and \
		   pos.y >= top_left.y and pos.y <= bottom_right.y:
			result.append(trees[pos])
	return result

func remove_building(grid_pos: Vector2i) -> void:
	var building = buildings.get(grid_pos, null)
	if building:
		building.destroy()
		buildings.erase(grid_pos)
		building_removed.emit(grid_pos)

func remove_tree(grid_pos: Vector2i) -> void:
	var tree = trees.get(grid_pos, null)
	if tree:
		tree.destroy()
		trees.erase(grid_pos)
		tree_removed.emit(grid_pos)

func get_all_buildings() -> Array:
	return buildings.values()

func get_all_trees() -> Array:
	return trees.values()

func serialize() -> Dictionary:
	var data: Dictionary = {
		"buildings": {},
		"trees": {}
	}
	
	for pos in buildings:
		data["buildings"]["%d,%d" % [pos.x, pos.y]] = buildings[pos].get_building_info()
	
	for pos in trees:
		data["trees"]["%d,%d" % [pos.x, pos.y]] = trees[pos].get_tree_info()
	
	return data

func _on_building_selected(building: Building) -> void:
	pass  # Handle building selection if needed

func _on_building_destroyed(building: Building) -> void:
	pass  # Clean up if needed

func _on_tree_selected(tree: Tree) -> void:
	pass  # Handle tree selection if needed

func _on_tree_destroyed(tree: Tree) -> void:
	pass  # Clean up if needed
