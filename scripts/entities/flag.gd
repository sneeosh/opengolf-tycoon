extends Node2D
class_name Flag
## Flag - Represents a golf hole flag on the green

var grid_position: Vector2i = Vector2i.ZERO
var hole_number: int = 1
var terrain_grid: TerrainGrid

signal flag_selected(flag: Flag)
signal flag_moved(old_position: Vector2i, new_position: Vector2i)

func _ready() -> void:
	z_index = 50  # Render above terrain but below UI
	_create_visual()

func set_terrain_grid(grid: TerrainGrid) -> void:
	terrain_grid = grid

func set_position_in_grid(pos: Vector2i) -> void:
	grid_position = pos
	if terrain_grid:
		var world_pos = terrain_grid.grid_to_screen_center(pos)
		global_position = world_pos

func set_hole_number(number: int) -> void:
	hole_number = number
	_update_label()

func _create_visual() -> void:
	# Clear existing visual
	for child in get_children():
		child.queue_free()

	var visual = Node2D.new()
	visual.name = "Visual"
	add_child(visual)

	# Flag pole (vertical line)
	var pole = Polygon2D.new()
	pole.name = "Pole"
	pole.color = Color(0.8, 0.8, 0.8, 1)  # Light gray
	pole.polygon = PackedVector2Array([
		Vector2(-1, 0), Vector2(1, 0),
		Vector2(1, -40), Vector2(-1, -40)
	])
	visual.add_child(pole)

	# Flag (triangular shape)
	var flag = Polygon2D.new()
	flag.name = "Flag"
	flag.color = Color(0.9, 0.1, 0.1, 1)  # Red
	flag.polygon = PackedVector2Array([
		Vector2(1, -40),
		Vector2(18, -32),
		Vector2(1, -24)
	])
	visual.add_child(flag)

	# Hole number label
	var label = Label.new()
	label.name = "HoleNumberLabel"
	label.text = str(hole_number)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2(4, -36)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 2)
	visual.add_child(label)

	# Shadow for the pole
	var shadow = Polygon2D.new()
	shadow.name = "Shadow"
	shadow.color = Color(0, 0, 0, 0.3)
	shadow.position = Vector2(2, 2)
	shadow.polygon = PackedVector2Array([
		Vector2(-8, 2), Vector2(8, 2),
		Vector2(6, 0), Vector2(-6, 0)
	])
	visual.add_child(shadow)

	# Input detection area
	var input_area = Area2D.new()
	input_area.name = "InputArea"
	add_child(input_area)

	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 10.0
	collision.shape = shape
	input_area.add_child(collision)

	# Connect input events
	input_area.input_event.connect(_on_input_event)

func _update_label() -> void:
	if has_node("Visual/HoleNumberLabel"):
		get_node("Visual/HoleNumberLabel").text = str(hole_number)

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			flag_selected.emit(self)

func move_to(new_grid_position: Vector2i) -> void:
	if not terrain_grid:
		return

	# Validate that the new position is on a green
	var terrain_type = terrain_grid.get_tile(new_grid_position)
	if terrain_type != TerrainTypes.Type.GREEN:
		print("Flag can only be placed on green tiles")
		return

	var old_position = grid_position
	set_position_in_grid(new_grid_position)
	flag_moved.emit(old_position, new_grid_position)

func get_flag_info() -> Dictionary:
	return {
		"hole_number": hole_number,
		"position": grid_position,
		"world_position": global_position
	}

func destroy() -> void:
	queue_free()
