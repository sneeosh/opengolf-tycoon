extends Node2D
class_name Tree
## Tree - Represents a tree entity on the course

@export var grid_position: Vector2i = Vector2i(0, 0)
@export var tree_type: String = "oak"  # oak, pine, maple, birch

var terrain_grid: TerrainGrid
var tree_data: Dictionary = {}

@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
@onready var collision_shape: CollisionShape2D = $Area2D/CollisionShape2D if has_node("Area2D/CollisionShape2D") else null

signal tree_selected(tree: Tree)
signal tree_destroyed(tree: Tree)

const TREE_PROPERTIES: Dictionary = {
	"oak": {"name": "Oak Tree", "cost": 20, "height": 3, "width": 2, "color": Color(0.2, 0.5, 0.2)},
	"pine": {"name": "Pine Tree", "cost": 18, "height": 4, "width": 1.5, "color": Color(0.15, 0.4, 0.15)},
	"maple": {"name": "Maple Tree", "cost": 25, "height": 3.5, "width": 2.5, "color": Color(0.3, 0.5, 0.25)},
	"birch": {"name": "Birch Tree", "cost": 22, "height": 3.2, "width": 1.8, "color": Color(0.25, 0.45, 0.2)},
}

func _ready() -> void:
	add_to_group("trees")
	
	# Load tree data
	if tree_type in TREE_PROPERTIES:
		tree_data = TREE_PROPERTIES[tree_type].duplicate(true)
	else:
		tree_type = "oak"
		tree_data = TREE_PROPERTIES["oak"].duplicate(true)
	
	_update_visuals()

func _input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tree_selected.emit(self)

func set_terrain_grid(grid: TerrainGrid) -> void:
	terrain_grid = grid

func set_position_in_grid(pos: Vector2i) -> void:
	grid_position = pos
	# Calculate world position from grid position
	if terrain_grid:
		var world_pos = terrain_grid.grid_to_screen(pos)
		global_position = world_pos

func destroy() -> void:
	tree_destroyed.emit(self)
	queue_free()

func _update_visuals() -> void:
	"""Create visual representation for the tree"""
	# Create a Node2D to hold the visual
	var visual = Node2D.new()
	visual.name = "Visual"
	add_child(visual)
	
	var color = tree_data.get("color", Color.GREEN)
	
	# Draw trunk
	var trunk = Polygon2D.new()
	trunk.color = Color(0.4, 0.2, 0.1)  # Brown trunk
	trunk.polygon = PackedVector2Array([
		Vector2(-6, 20),
		Vector2(6, 20),
		Vector2(6, 45),
		Vector2(-6, 45)
	])
	visual.add_child(trunk)
	
	# Draw canopy based on tree type
	match tree_type:
		"oak":
			_draw_oak_canopy(visual, color)
		"pine":
			_draw_pine_canopy(visual, color)
		"maple":
			_draw_maple_canopy(visual, color)
		"birch":
			_draw_birch_canopy(visual, color)
		_:
			_draw_oak_canopy(visual, color)

func _draw_oak_canopy(visual: Node2D, color: Color) -> void:
	"""Draw oak tree canopy - round and full"""
	var canopy = Polygon2D.new()
	canopy.color = color
	# Create a circular canopy
	var points = PackedVector2Array()
	for i in range(16):
		var angle = (i / 16.0) * TAU
		var x = cos(angle) * 25
		var y = sin(angle) * 20 - 15
		points.append(Vector2(x, y))
	canopy.polygon = points
	visual.add_child(canopy)

func _draw_pine_canopy(visual: Node2D, color: Color) -> void:
	"""Draw pine tree canopy - tall and narrow"""
	var canopy = Polygon2D.new()
	canopy.color = color
	canopy.polygon = PackedVector2Array([
		Vector2(0, -35),      # Top point
		Vector2(20, -10),     # Right side
		Vector2(10, 5),
		Vector2(15, 15),
		Vector2(0, 20),
		Vector2(-15, 15),
		Vector2(-10, 5),
		Vector2(-20, -10)
	])
	visual.add_child(canopy)

func _draw_maple_canopy(visual: Node2D, color: Color) -> void:
	"""Draw maple tree canopy - medium and rounded"""
	var canopy = Polygon2D.new()
	canopy.color = color
	canopy.polygon = PackedVector2Array([
		Vector2(0, -25),
		Vector2(22, -15),
		Vector2(25, 0),
		Vector2(20, 15),
		Vector2(0, 22),
		Vector2(-20, 15),
		Vector2(-25, 0),
		Vector2(-22, -15)
	])
	visual.add_child(canopy)

func _draw_birch_canopy(visual: Node2D, color: Color) -> void:
	"""Draw birch tree canopy - light and airy"""
	var canopy1 = Polygon2D.new()
	canopy1.color = color
	canopy1.polygon = PackedVector2Array([
		Vector2(0, -20),
		Vector2(18, -10),
		Vector2(15, 5),
		Vector2(0, 10),
		Vector2(-15, 5),
		Vector2(-18, -10)
	])
	visual.add_child(canopy1)
	
	# Add a lighter section below
	var canopy2 = Polygon2D.new()
	canopy2.color = Color(color.r * 1.2, color.g * 1.2, color.b * 1.2)
	canopy2.polygon = PackedVector2Array([
		Vector2(-10, 5),
		Vector2(10, 5),
		Vector2(12, 18),
		Vector2(0, 20),
		Vector2(-12, 18)
	])
	visual.add_child(canopy2)

func get_tree_info() -> Dictionary:
	return {
		"type": tree_type,
		"position": grid_position,
		"cost": tree_data.get("cost", 20),
		"height": tree_data.get("height", 3),
		"width": tree_data.get("width", 2),
		"name": tree_data.get("name", "Tree")
	}
