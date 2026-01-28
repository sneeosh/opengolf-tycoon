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
	if sprite:
		# Create a simple colored circle for now (can be replaced with actual sprites)
		var image = Image.new()
		image.create(32, 32, false, Image.FORMAT_RGBA8)
		
		var color = tree_data.get("color", Color.GREEN)
		image.fill(Color.TRANSPARENT)
		
		# Draw a simple circle
		for x in range(32):
			for y in range(32):
				var center = Vector2(16, 16)
				var pos = Vector2(x, y)
				if pos.distance_to(center) <= 14:
					image.set_pixel(x, y, color)
		
		var texture = ImageTexture.create_from_image(image)
		sprite.texture = texture

func get_tree_info() -> Dictionary:
	return {
		"type": tree_type,
		"position": grid_position,
		"cost": tree_data.get("cost", 20),
		"height": tree_data.get("height", 3),
		"width": tree_data.get("width", 2),
		"name": tree_data.get("name", "Tree")
	}
