extends Node2D
class_name Building
## Building - Represents a building entity on the course

@export var building_type: String = "clubhouse"
@export var grid_position: Vector2i = Vector2i(0, 0)
@export var width: int = 4
@export var height: int = 4

var terrain_grid: TerrainGrid
var building_data: Dictionary = {}

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $Area2D/CollisionShape2D if has_node("Area2D/CollisionShape2D") else null

signal building_selected(building: Building)
signal building_destroyed(building: Building)

func _ready() -> void:
	add_to_group("buildings")
	
	# Load building data if not already set
	if building_data.is_empty():
		var buildings_json = FileAccess.open("res://data/buildings.json", FileAccess.READ)
		if buildings_json:
			var data = JSON.parse_string(buildings_json.get_as_text())
			if data and data.has("buildings") and data["buildings"].has(building_type):
				building_data = data["buildings"][building_type]
	
	# Update size from building data if available
	if building_data.has("size"):
		var size = building_data["size"]
		width = size[0]
		height = size[1]
	
	_update_visuals()

func _input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		building_selected.emit(self)

func set_terrain_grid(grid: TerrainGrid) -> void:
	terrain_grid = grid

func set_position_in_grid(pos: Vector2i) -> void:
	grid_position = pos
	# Calculate world position from grid position
	if terrain_grid:
		var world_pos = terrain_grid.grid_to_screen(pos)
		global_position = world_pos

func get_footprint() -> Array:
	"""Returns array of grid positions occupied by this building"""
	var footprint: Array = []
	for x in range(width):
		for y in range(height):
			footprint.append(grid_position + Vector2i(x, y))
	return footprint

func destroy() -> void:
	building_destroyed.emit(self)
	queue_free()

func _update_visuals() -> void:
	# Set a placeholder sprite (can be replaced with actual building sprites)
	if sprite:
		# Create a simple colored rectangle for now
		var rect_size = Vector2(width * 16, height * 16)  # Approximate tile size
		# This would be replaced with actual sprite sheets in a real implementation
		sprite.modulate = Color.GRAY

func get_building_info() -> Dictionary:
	return {
		"type": building_type,
		"position": grid_position,
		"width": width,
		"height": height,
		"cost": building_data.get("cost", 0),
		"data": building_data
	}
