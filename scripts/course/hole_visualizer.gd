extends Node2D
class_name HoleVisualizer
## HoleVisualizer - Manages visual representation of a golf hole

var hole_data: GameManager.HoleData
var terrain_grid: TerrainGrid
var flag: Flag

# Visual components
var line: Line2D
var info_label: Label

signal hole_selected(hole_number: int)

func _ready() -> void:
	z_index = 10  # Render above terrain but below entities

func initialize(hole: GameManager.HoleData, grid: TerrainGrid) -> void:
	hole_data = hole
	terrain_grid = grid
	_create_visuals()

func _create_visuals() -> void:
	# Create line connecting tee to green
	_create_connection_line()

	# Create flag at hole position
	_create_flag()

	# Create info label
	_create_info_label()

func _create_connection_line() -> void:
	if line:
		line.queue_free()

	line = Line2D.new()
	line.name = "ConnectionLine"
	line.width = 2.0
	line.default_color = Color(1, 1, 1, 0.4)  # Semi-transparent white
	line.antialiased = true
	line.z_index = -1  # Behind everything else
	add_child(line)

	_update_line()

func _update_line() -> void:
	if not line or not terrain_grid or not hole_data:
		return

	var tee_screen = terrain_grid.grid_to_screen(hole_data.tee_position)
	var green_screen = terrain_grid.grid_to_screen(hole_data.green_position)

	# Convert to local coordinates
	line.clear_points()
	line.add_point(to_local(tee_screen))
	line.add_point(to_local(green_screen))

func _create_flag() -> void:
	if flag:
		flag.queue_free()

	flag = Flag.new()
	flag.name = "Flag"
	flag.set_terrain_grid(terrain_grid)
	flag.set_hole_number(hole_data.hole_number)
	flag.set_position_in_grid(hole_data.hole_position)
	add_child(flag)

	# Connect flag signals
	flag.flag_selected.connect(_on_flag_selected)
	flag.flag_moved.connect(_on_flag_moved)

func _create_info_label() -> void:
	if info_label:
		info_label.queue_free()

	info_label = Label.new()
	info_label.name = "InfoLabel"
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	add_child(info_label)

	_update_info_label()

func _update_info_label() -> void:
	if not info_label or not terrain_grid or not hole_data:
		return

	# Position label at midpoint between tee and green
	var tee_screen = terrain_grid.grid_to_screen(hole_data.tee_position)
	var green_screen = terrain_grid.grid_to_screen(hole_data.green_position)
	var midpoint = (tee_screen + green_screen) / 2.0

	info_label.position = to_local(midpoint) + Vector2(-40, -20)

	# Update text
	var info_text = "Hole %d\nPar %d\n%d yards" % [
		hole_data.hole_number,
		hole_data.par,
		hole_data.distance_yards
	]
	info_label.text = info_text

	# Styling
	info_label.add_theme_font_size_override("font_size", 12)
	info_label.add_theme_color_override("font_color", Color.WHITE)
	info_label.add_theme_color_override("font_outline_color", Color.BLACK)
	info_label.add_theme_constant_override("outline_size", 2)

func set_visible_state(is_visible: bool) -> void:
	visible = is_visible

func highlight(enabled: bool) -> void:
	if not line:
		return

	if enabled:
		line.default_color = Color(1, 1, 0, 0.7)  # Yellow when highlighted
		line.width = 3.0
	else:
		line.default_color = Color(1, 1, 1, 0.4)  # Normal white
		line.width = 2.0

func _on_flag_selected(selected_flag: Flag) -> void:
	hole_selected.emit(hole_data.hole_number)

func _on_flag_moved(old_position: Vector2i, new_position: Vector2i) -> void:
	# Update hole data
	hole_data.hole_position = new_position

	# Recalculate distance and par if green position changed
	hole_data.distance_yards = terrain_grid.calculate_distance_yards(
		hole_data.tee_position,
		new_position
	)
	hole_data.par = HoleCreationTool.calculate_par(hole_data.distance_yards)

	# Update visuals
	_update_line()
	_update_info_label()

	EventBus.emit_signal("hole_updated", hole_data.hole_number)

func update_visualization() -> void:
	_update_line()
	_update_info_label()

func get_hole_number() -> int:
	return hole_data.hole_number if hole_data else 0

func destroy() -> void:
	if flag:
		flag.destroy()
	queue_free()
