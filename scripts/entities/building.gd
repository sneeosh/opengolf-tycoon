extends Node2D
class_name Building
## Building - Represents a building entity on the course

var building_type: String = "clubhouse"
var grid_position: Vector2i = Vector2i(0, 0)
var width: int = 4
var height: int = 4

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
	"""Create visual representation for the building"""
	# Create a Node2D to hold the visual
	var visual = Node2D.new()
	visual.name = "Visual"
	add_child(visual)
	
	# Define colors and styles for each building type
	var tile_w = 64
	var tile_h = 32
	
	var size_x = width * tile_w
	var size_y = height * tile_h
	
	# Draw based on building type
	match building_type:
		"clubhouse":
			_draw_clubhouse(visual, size_x, size_y)
		"pro_shop":
			_draw_pro_shop(visual, size_x, size_y)
		"restaurant":
			_draw_restaurant(visual, size_x, size_y)
		"snack_bar":
			_draw_snack_bar(visual, size_x, size_y)
		"driving_range":
			_draw_driving_range(visual, size_x, size_y)
		"cart_shed":
			_draw_cart_shed(visual, size_x, size_y)
		"restroom":
			_draw_restroom(visual, size_x, size_y)
		"bench":
			_draw_bench(visual, size_x, size_y)
		_:
			_draw_generic(visual, size_x, size_y)

func _draw_clubhouse(visual: Node2D, width_px: int, height_px: int) -> void:
	"""Draw clubhouse - large main building"""
	var polygon = Polygon2D.new()
	polygon.color = Color(0.8, 0.6, 0.2)  # Tan/beige
	polygon.polygon = PackedVector2Array([
		Vector2(0, 0),
		Vector2(width_px, 0),
		Vector2(width_px, height_px),
		Vector2(0, height_px)
	])
	visual.add_child(polygon)
	
	# Add a roof
	var roof = Polygon2D.new()
	roof.color = Color(0.6, 0.2, 0.2)  # Red roof
	roof.polygon = PackedVector2Array([
		Vector2(width_px * 0.1, 0),
		Vector2(width_px * 0.9, 0),
		Vector2(width_px / 2, height_px * 0.3)
	])
	visual.add_child(roof)

func _draw_pro_shop(visual: Node2D, width_px: int, height_px: int) -> void:
	"""Draw pro shop - shop building"""
	var shop = Polygon2D.new()
	shop.color = Color(0.2, 0.5, 0.8)  # Blue shop
	shop.polygon = PackedVector2Array([
		Vector2(0, 0),
		Vector2(width_px, 0),
		Vector2(width_px, height_px),
		Vector2(0, height_px)
	])
	visual.add_child(shop)
	
	# Add door
	var door = Polygon2D.new()
	door.color = Color(0.5, 0.3, 0.1)
	door.polygon = PackedVector2Array([
		Vector2(width_px * 0.4, height_px * 0.5),
		Vector2(width_px * 0.6, height_px * 0.5),
		Vector2(width_px * 0.6, height_px),
		Vector2(width_px * 0.4, height_px)
	])
	visual.add_child(door)

func _draw_restaurant(visual: Node2D, width_px: int, height_px: int) -> void:
	"""Draw restaurant - dining building"""
	var main = Polygon2D.new()
	main.color = Color(0.8, 0.7, 0.5)  # Light brown
	main.polygon = PackedVector2Array([
		Vector2(0, 0),
		Vector2(width_px, 0),
		Vector2(width_px, height_px),
		Vector2(0, height_px)
	])
	visual.add_child(main)
	
	# Add windows
	for i in range(3):
		var window = Polygon2D.new()
		window.color = Color(0.3, 0.7, 0.9)
		var x_offset = (i + 1) * width_px / 4
		window.polygon = PackedVector2Array([
			Vector2(x_offset - 15, 10),
			Vector2(x_offset + 15, 10),
			Vector2(x_offset + 15, 25),
			Vector2(x_offset - 15, 25)
		])
		visual.add_child(window)

func _draw_snack_bar(visual: Node2D, width_px: int, height_px: int) -> void:
	"""Draw snack bar - small kiosk"""
	var kiosk = Polygon2D.new()
	kiosk.color = Color(0.9, 0.6, 0.2)  # Orange
	kiosk.polygon = PackedVector2Array([
		Vector2(0, 0),
		Vector2(width_px, 0),
		Vector2(width_px, height_px),
		Vector2(0, height_px)
	])
	visual.add_child(kiosk)
	
	# Add counter window
	var counter = Polygon2D.new()
	counter.color = Color(0.2, 0.2, 0.2)
	counter.polygon = PackedVector2Array([
		Vector2(width_px * 0.15, height_px * 0.3),
		Vector2(width_px * 0.85, height_px * 0.3),
		Vector2(width_px * 0.85, height_px * 0.7),
		Vector2(width_px * 0.15, height_px * 0.7)
	])
	visual.add_child(counter)

func _draw_driving_range(visual: Node2D, width_px: int, height_px: int) -> void:
	"""Draw driving range - practice area"""
	var range_area = Polygon2D.new()
	range_area.color = Color(0.3, 0.6, 0.3)  # Green grass
	range_area.polygon = PackedVector2Array([
		Vector2(0, 0),
		Vector2(width_px, 0),
		Vector2(width_px, height_px),
		Vector2(0, height_px)
	])
	visual.add_child(range_area)
	
	# Add practice bays
	for i in range(3):
		var bay = Polygon2D.new()
		bay.color = Color(0.7, 0.7, 0.5)
		var y_offset = (i + 1) * height_px / 4
		bay.polygon = PackedVector2Array([
			Vector2(10, y_offset - 8),
			Vector2(width_px - 10, y_offset - 8),
			Vector2(width_px - 10, y_offset + 8),
			Vector2(10, y_offset + 8)
		])
		visual.add_child(bay)

func _draw_cart_shed(visual: Node2D, width_px: int, height_px: int) -> void:
	"""Draw cart shed - equipment storage"""
	var shed = Polygon2D.new()
	shed.color = Color(0.6, 0.5, 0.4)  # Brown shed
	shed.polygon = PackedVector2Array([
		Vector2(0, 0),
		Vector2(width_px, 0),
		Vector2(width_px, height_px),
		Vector2(0, height_px)
	])
	visual.add_child(shed)
	
	# Add garage doors
	for i in range(2):
		var door = Polygon2D.new()
		door.color = Color(0.4, 0.3, 0.2)
		var x_offset = (i + 1) * width_px / 3
		door.polygon = PackedVector2Array([
			Vector2(x_offset - 30, 10),
			Vector2(x_offset + 30, 10),
			Vector2(x_offset + 30, height_px - 10),
			Vector2(x_offset - 30, height_px - 10)
		])
		visual.add_child(door)

func _draw_restroom(visual: Node2D, width_px: int, height_px: int) -> void:
	"""Draw restroom - facility building"""
	var facility = Polygon2D.new()
	facility.color = Color(0.7, 0.7, 0.7)  # Gray
	facility.polygon = PackedVector2Array([
		Vector2(0, 0),
		Vector2(width_px, 0),
		Vector2(width_px, height_px),
		Vector2(0, height_px)
	])
	visual.add_child(facility)
	
	# Add door
	var door = Polygon2D.new()
	door.color = Color(0.4, 0.2, 0.1)
	door.polygon = PackedVector2Array([
		Vector2(width_px * 0.35, height_px * 0.4),
		Vector2(width_px * 0.65, height_px * 0.4),
		Vector2(width_px * 0.65, height_px),
		Vector2(width_px * 0.35, height_px)
	])
	visual.add_child(door)

func _draw_bench(visual: Node2D, width_px: int, height_px: int) -> void:
	"""Draw bench - seating"""
	# Bench seat
	var seat = Polygon2D.new()
	seat.color = Color(0.6, 0.4, 0.2)  # Brown wood
	seat.polygon = PackedVector2Array([
		Vector2(width_px * 0.1, height_px * 0.4),
		Vector2(width_px * 0.9, height_px * 0.4),
		Vector2(width_px * 0.9, height_px * 0.7),
		Vector2(width_px * 0.1, height_px * 0.7)
	])
	visual.add_child(seat)
	
	# Legs
	for x_pos in [width_px * 0.2, width_px * 0.8]:
		var leg = Polygon2D.new()
		leg.color = Color(0.4, 0.3, 0.1)
		leg.polygon = PackedVector2Array([
			Vector2(x_pos - 5, height_px * 0.7),
			Vector2(x_pos + 5, height_px * 0.7),
			Vector2(x_pos + 5, height_px),
			Vector2(x_pos - 5, height_px)
		])
		visual.add_child(leg)

func _draw_generic(visual: Node2D, width_px: int, height_px: int) -> void:
	"""Draw generic building"""
	var rect = Polygon2D.new()
	rect.color = Color(0.5, 0.5, 0.5)  # Gray
	rect.polygon = PackedVector2Array([
		Vector2(0, 0),
		Vector2(width_px, 0),
		Vector2(width_px, height_px),
		Vector2(0, height_px)
	])
	visual.add_child(rect)

func get_building_info() -> Dictionary:
	return {
		"type": building_type,
		"position": grid_position,
		"width": width,
		"height": height,
		"cost": building_data.get("cost", 0),
		"data": building_data
	}
