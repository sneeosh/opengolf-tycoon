extends Node2D
class_name Flag
## Flag - Represents a golf hole flag on the green.
## Static visual replaced by animated WindFlag from WindFlagOverlay.
## This node retains click-to-select functionality via Area2D.

var grid_position: Vector2i = Vector2i.ZERO
var hole_number: int = 1
var terrain_grid: TerrainGrid

signal flag_selected(flag: Flag)
signal flag_right_clicked(flag: Flag, global_pos: Vector2)
signal flag_moved(old_position: Vector2i, new_position: Vector2i)

func _ready() -> void:
	z_index = 50
	_create_input_area()

func set_terrain_grid(grid: TerrainGrid) -> void:
	terrain_grid = grid

func set_position_in_grid(pos: Vector2i) -> void:
	grid_position = pos
	if terrain_grid:
		global_position = terrain_grid.grid_to_screen_center(pos)

func set_hole_number(number: int) -> void:
	hole_number = number

func _create_input_area() -> void:
	var input_area = Area2D.new()
	input_area.name = "InputArea"
	add_child(input_area)

	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 10.0
	collision.shape = shape
	input_area.add_child(collision)

	input_area.input_event.connect(_on_input_event)

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			flag_selected.emit(self)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			flag_right_clicked.emit(self, event.global_position)

func move_to(new_grid_position: Vector2i) -> void:
	if not terrain_grid:
		return

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
