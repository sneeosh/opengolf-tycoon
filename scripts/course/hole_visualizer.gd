extends Node2D
class_name HoleVisualizer
## HoleVisualizer - Manages visual representation of a golf hole

var hole_data: GameManager.HoleData
var terrain_grid: TerrainGrid
var flag: Flag

# Visual components
var line: Line2D
var info_label: Label
var waypoint_markers: Array[Node2D] = []
var _line_update_pending: bool = false

# Tee box markers for forward/back tees
var _tee_markers: Array[Node2D] = []

signal hole_selected(hole_number: int)

func _ready() -> void:
	z_index = 10  # Render above terrain but below entities

func initialize(hole: GameManager.HoleData, grid: TerrainGrid) -> void:
	hole_data = hole
	terrain_grid = grid
	_create_visuals()
	EventBus.terrain_tile_changed.connect(_on_terrain_tile_changed)
	EventBus.hole_updated.connect(_on_hole_updated)

func _create_visuals() -> void:
	# Create shot path line (routed through golfer AI waypoints)
	_create_connection_line()

	# Create flag at hole position
	_create_flag()

	# Create info label
	_create_info_label()

	# Create tee box markers for forward/back tees
	_update_tee_markers()

func _create_connection_line() -> void:
	if line:
		remove_child(line)
		line.free()

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

	# Calculate shot path waypoints using golfer AI logic
	var waypoints: Array[Vector2i] = ShotPathCalculator.calculate_waypoints(hole_data, terrain_grid)

	# Draw line through all waypoints
	line.clear_points()
	for wp in waypoints:
		var screen_pos: Vector2 = terrain_grid.grid_to_screen_center(wp)
		line.add_point(to_local(screen_pos))

	# Update landing zone markers at intermediate waypoints
	_update_waypoint_markers(waypoints)

func _update_waypoint_markers(waypoints: Array[Vector2i]) -> void:
	# Clear existing markers immediately (not queue_free) to prevent stale rendering
	for marker in waypoint_markers:
		if is_instance_valid(marker):
			remove_child(marker)
			marker.free()
	waypoint_markers.clear()

	# Create markers at intermediate waypoints (skip first=tee and last=flag)
	for i in range(1, waypoints.size() - 1):
		var marker: Node2D = _create_waypoint_marker(waypoints[i])
		add_child(marker)
		waypoint_markers.append(marker)

func _create_waypoint_marker(grid_pos: Vector2i) -> Node2D:
	var marker := Node2D.new()
	var screen_pos: Vector2 = terrain_grid.grid_to_screen_center(grid_pos)
	marker.position = to_local(screen_pos)
	marker.z_index = -1

	# Outer ring (dark outline for contrast)
	var outer_ring := Polygon2D.new()
	var outer_points := PackedVector2Array()
	for i in range(12):
		var angle: float = (i / 12.0) * TAU
		outer_points.append(Vector2(cos(angle) * 5.0, sin(angle) * 5.0))
	outer_ring.polygon = outer_points
	outer_ring.color = Color(0.0, 0.0, 0.0, 0.5)
	marker.add_child(outer_ring)

	# Inner filled circle (landing zone indicator)
	var inner_circle := Polygon2D.new()
	var inner_points := PackedVector2Array()
	for i in range(12):
		var angle: float = (i / 12.0) * TAU
		inner_points.append(Vector2(cos(angle) * 3.5, sin(angle) * 3.5))
	inner_circle.polygon = inner_points
	inner_circle.color = Color(0.5, 0.85, 1.0, 0.7)  # Light blue
	marker.add_child(inner_circle)

	return marker

func _update_tee_markers() -> void:
	# Clear existing tee markers
	for marker in _tee_markers:
		if is_instance_valid(marker):
			remove_child(marker)
			marker.free()
	_tee_markers.clear()

	if not hole_data or not terrain_grid:
		return

	# Forward tee marker (red diamond)
	if hole_data.has_forward_tee():
		var fwd_marker = _create_tee_marker(hole_data.forward_tee, Color(0.9, 0.3, 0.3, 0.8), "F")
		add_child(fwd_marker)
		_tee_markers.append(fwd_marker)

	# Back tee marker (dark blue diamond)
	if hole_data.has_back_tee():
		var back_marker = _create_tee_marker(hole_data.back_tee, Color(0.2, 0.3, 0.8, 0.8), "B")
		add_child(back_marker)
		_tee_markers.append(back_marker)

func _create_tee_marker(grid_pos: Vector2i, color: Color, label_text: String) -> Node2D:
	var marker := Node2D.new()
	var screen_pos: Vector2 = terrain_grid.grid_to_screen_center(grid_pos)
	marker.position = to_local(screen_pos)
	marker.z_index = 5

	# Diamond shape
	var diamond := Polygon2D.new()
	diamond.polygon = PackedVector2Array([
		Vector2(0, -6),   # Top
		Vector2(5, 0),    # Right
		Vector2(0, 6),    # Bottom
		Vector2(-5, 0),   # Left
	])
	diamond.color = color
	marker.add_child(diamond)

	# Outline
	var outline := Polygon2D.new()
	outline.polygon = PackedVector2Array([
		Vector2(0, -7),
		Vector2(6, 0),
		Vector2(0, 7),
		Vector2(-6, 0),
	])
	outline.color = Color(0, 0, 0, 0.5)
	outline.z_index = -1
	marker.add_child(outline)

	# Label
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 2)
	lbl.position = Vector2(-3, -16)
	marker.add_child(lbl)

	return marker

func _create_flag() -> void:
	if flag:
		# Disconnect signals before freeing to prevent leaks
		if flag.flag_selected.is_connected(_on_flag_selected):
			flag.flag_selected.disconnect(_on_flag_selected)
		if flag.flag_moved.is_connected(_on_flag_moved):
			flag.flag_moved.disconnect(_on_flag_moved)
		remove_child(flag)
		flag.free()

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
		remove_child(info_label)
		info_label.free()

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
	var tee_screen = terrain_grid.grid_to_screen_center(hole_data.tee_position)
	var green_screen = terrain_grid.grid_to_screen_center(hole_data.green_position)
	var midpoint = (tee_screen + green_screen) / 2.0

	info_label.position = to_local(midpoint) + Vector2(-40, -20)

	# Update text — show tee count if multiple tees exist
	var tee_info = ""
	if hole_data.get_tee_count() > 1:
		tee_info = "\nTees: %d" % hole_data.get_tee_count()

	var info_text = "Hole %d\nPar %d\n%d yards\nDiff: %.1f%s" % [
		hole_data.hole_number,
		hole_data.par,
		hole_data.distance_yards,
		hole_data.difficulty_rating,
		tee_info
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
		for marker in waypoint_markers:
			if is_instance_valid(marker):
				var inner: Polygon2D = marker.get_child(1) if marker.get_child_count() > 1 else null
				if inner:
					inner.color = Color(1.0, 1.0, 0.3, 0.8)  # Yellow to match line
	else:
		line.default_color = Color(1, 1, 1, 0.4)  # Normal white
		line.width = 2.0
		for marker in waypoint_markers:
			if is_instance_valid(marker):
				var inner: Polygon2D = marker.get_child(1) if marker.get_child_count() > 1 else null
				if inner:
					inner.color = Color(0.5, 0.85, 1.0, 0.7)  # Normal light blue

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

	# Recalculate difficulty
	hole_data.difficulty_rating = DifficultyCalculator.calculate_hole_difficulty(hole_data, terrain_grid)

	# Update visuals (shot path recalculates based on new flag position)
	_update_line()
	_update_info_label()
	_update_tee_markers()

	EventBus.hole_updated.emit(hole_data.hole_number)

func _on_hole_updated(hole_number: int) -> void:
	if hole_data and hole_data.hole_number == hole_number:
		_update_tee_markers()
		_update_info_label()

func _on_terrain_tile_changed(_position: Vector2i, _old_type: int, _new_type: int) -> void:
	# Debounce: only recalculate once per frame even if many tiles change
	if not _line_update_pending:
		_line_update_pending = true
		call_deferred("_deferred_terrain_update")

func _deferred_terrain_update() -> void:
	_line_update_pending = false
	if hole_data and terrain_grid:
		var new_difficulty = DifficultyCalculator.calculate_hole_difficulty(hole_data, terrain_grid)
		if absf(new_difficulty - hole_data.difficulty_rating) > 0.05:
			hole_data.difficulty_rating = new_difficulty
			_update_info_label()
			EventBus.hole_difficulty_changed.emit(hole_data.hole_number, new_difficulty)

		# Recalculate shot path (terrain changes affect golfer routing)
		_update_line()

func update_visualization() -> void:
	_update_line()
	_update_info_label()
	_update_tee_markers()

func get_hole_number() -> int:
	return hole_data.hole_number if hole_data else 0

func _exit_tree() -> void:
	if EventBus.terrain_tile_changed.is_connected(_on_terrain_tile_changed):
		EventBus.terrain_tile_changed.disconnect(_on_terrain_tile_changed)
	if EventBus.hole_updated.is_connected(_on_hole_updated):
		EventBus.hole_updated.disconnect(_on_hole_updated)

func destroy() -> void:
	if flag:
		flag.destroy()
	queue_free()
