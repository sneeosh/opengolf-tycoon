extends Node2D
class_name EntityLayer
## EntityLayer - Manages all placed buildings and trees on the course

var buildings: Dictionary = {}  # key: Vector2i (grid_pos), value: Building node
var trees: Dictionary = {}      # key: Vector2i (grid_pos), value: TreeEntity node
var rocks: Dictionary = {}      # key: Vector2i (grid_pos), value: Rock node

var terrain_grid: TerrainGrid
var building_registry: Dictionary = {}  # Can accept either Node or Dictionary

signal building_placed(building: Building, cost: int)
signal tree_placed(tree: TreeEntity, cost: int)
signal rock_placed(rock: Rock, cost: int)
signal building_removed(grid_pos: Vector2i)
signal tree_removed(grid_pos: Vector2i)
signal rock_removed(grid_pos: Vector2i)
signal building_selected(building: Building)

@onready var buildings_container = Node2D.new()
@onready var trees_container = Node2D.new()
@onready var rocks_container = Node2D.new()

func _ready() -> void:
	buildings_container.name = "Buildings"
	trees_container.name = "Trees"
	rocks_container.name = "Rocks"
	add_child(buildings_container)
	add_child(trees_container)
	add_child(rocks_container)

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

func place_tree(grid_pos: Vector2i, tree_type: String = "oak") -> TreeEntity:
	"""Place a tree at the specified grid position"""
	var tree = TreeEntity.new()
	tree.set_terrain_grid(terrain_grid)
	tree.set_position_in_grid(grid_pos)

	trees_container.add_child(tree)

	# Set tree type after adding to tree so node is fully initialized
	tree.set_tree_type(tree_type)
	
	# Store by grid position
	trees[grid_pos] = tree
	
	# Connect signals
	tree.tree_selected.connect(_on_tree_selected)
	tree.tree_destroyed.connect(_on_tree_destroyed)

	# Get actual tree cost from tree data
	var tree_cost = tree.tree_data.get("cost", 20)
	tree_placed.emit(tree, tree_cost)
	return tree

func place_rock(grid_pos: Vector2i, rock_size: String = "medium") -> Rock:
	"""Place a rock at the specified grid position"""
	var rock = Rock.new()
	rock.set_terrain_grid(terrain_grid)
	rock.set_position_in_grid(grid_pos)

	rocks_container.add_child(rock)

	# Set rock size after adding to tree so node is fully initialized
	rock.set_rock_size(rock_size)

	# Store by grid position
	rocks[grid_pos] = rock

	# Connect signals
	rock.rock_selected.connect(_on_rock_selected)
	rock.rock_destroyed.connect(_on_rock_destroyed)

	# Get actual rock cost from rock data
	var rock_cost = rock.rock_data.get("cost", 15)
	rock_placed.emit(rock, rock_cost)
	return rock

func get_building_at(grid_pos: Vector2i) -> Building:
	return buildings.get(grid_pos, null)

func get_tree_at(grid_pos: Vector2i) -> TreeEntity:
	return trees.get(grid_pos, null)

func get_rock_at(grid_pos: Vector2i) -> Rock:
	return rocks.get(grid_pos, null)

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

func get_rocks_in_area(top_left: Vector2i, bottom_right: Vector2i) -> Array:
	"""Get all rocks within the specified area"""
	var result: Array = []
	for pos in rocks.keys():
		if pos.x >= top_left.x and pos.x <= bottom_right.x and \
		   pos.y >= top_left.y and pos.y <= bottom_right.y:
			result.append(rocks[pos])
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

func remove_rock(grid_pos: Vector2i) -> void:
	var rock = rocks.get(grid_pos, null)
	if rock:
		rock.destroy()
		rocks.erase(grid_pos)
		rock_removed.emit(grid_pos)

func get_all_buildings() -> Array:
	return buildings.values()

func get_all_trees() -> Array:
	return trees.values()

func get_all_rocks() -> Array:
	return rocks.values()

func serialize() -> Dictionary:
	var data: Dictionary = {
		"buildings": {},
		"trees": {},
		"rocks": {}
	}

	for pos in buildings:
		data["buildings"]["%d,%d" % [pos.x, pos.y]] = buildings[pos].get_building_info()

	for pos in trees:
		data["trees"]["%d,%d" % [pos.x, pos.y]] = trees[pos].get_tree_info()

	for pos in rocks:
		data["rocks"]["%d,%d" % [pos.x, pos.y]] = rocks[pos].get_rock_info()

	return data

func clear_all() -> void:
	"""Remove all entities from the layer."""
	for pos in buildings.keys():
		buildings[pos].destroy()
	buildings.clear()
	for pos in trees.keys():
		trees[pos].destroy()
	trees.clear()
	for pos in rocks.keys():
		rocks[pos].destroy()
	rocks.clear()

func deserialize(data: Dictionary) -> void:
	"""Reconstruct entities from saved data."""
	clear_all()

	if data.has("trees"):
		for key in data["trees"]:
			var parts = key.split(",")
			if parts.size() == 2:
				var pos = Vector2i(int(parts[0]), int(parts[1]))
				var tree_data = data["trees"][key]
				var tree_type = tree_data.get("tree_type", "oak") if tree_data is Dictionary else "oak"
				place_tree(pos, tree_type)

	if data.has("buildings"):
		for key in data["buildings"]:
			var parts = key.split(",")
			if parts.size() == 2:
				var pos = Vector2i(int(parts[0]), int(parts[1]))
				var building_info = data["buildings"][key]
				var building_type = building_info.get("building_type", "") if building_info is Dictionary else ""
				if building_type.is_empty():
					building_type = building_info.get("type", "") if building_info is Dictionary else ""
				if not building_type.is_empty():
					var building = place_building(building_type, pos, building_registry)
					if building and building_info is Dictionary:
						building.restore_from_info(building_info)

	if data.has("rocks"):
		for key in data["rocks"]:
			var parts = key.split(",")
			if parts.size() == 2:
				var pos = Vector2i(int(parts[0]), int(parts[1]))
				var rock_data = data["rocks"][key]
				var rock_size = rock_data.get("rock_size", "medium") if rock_data is Dictionary else "medium"
				place_rock(pos, rock_size)

func _on_building_selected(building: Building) -> void:
	building_selected.emit(building)

func _on_building_destroyed(building: Building) -> void:
	pass  # Clean up if needed

func _on_tree_selected(tree: TreeEntity) -> void:
	pass  # Handle tree selection if needed

func _on_tree_destroyed(tree: TreeEntity) -> void:
	pass  # Clean up if needed

func _on_rock_selected(rock: Rock) -> void:
	pass  # Handle rock selection if needed

func _on_rock_destroyed(rock: Rock) -> void:
	pass  # Clean up if needed
