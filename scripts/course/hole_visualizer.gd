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
var carry_annotations: Array[Node2D] = []
static var carry_annotations_visible: bool = false  # Toggled by J hotkey with fairway width
var tee_markers: Array[Node2D] = []
var pin_markers: Array[Node2D] = []
var _line_update_pending: bool = false

signal hole_selected(hole_number: int)

func _ready() -> void:
	z_index = 10  # Render above terrain but below entities

func initialize(hole: GameManager.HoleData, grid: TerrainGrid) -> void:
	hole_data = hole
	terrain_grid = grid
	_create_visuals()
	EventBus.terrain_tile_changed.connect(_on_terrain_tile_changed)
	EventBus.pins_rotated.connect(_on_pins_rotated)

func _create_visuals() -> void:
	# Create shot path line (routed through golfer AI waypoints)
	_create_connection_line()

	# Create flag at hole position
	_create_flag()

	# Create info label
	_create_info_label()

	# Create forced carry annotations
	_update_carry_annotations()

	# Create tee box and pin position markers
	_update_tee_markers()
	_update_pin_markers()

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

	# Update text
	var par_text = "Par %d" % hole_data.par
	if hole_data.par_override > 0:
		par_text += "*"
	var info_text = "Hole %d\n%s\n%d yards\nDiff: %.1f" % [
		hole_data.hole_number,
		par_text,
		hole_data.distance_yards,
		hole_data.difficulty_rating
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

	# Sync pin_positions array: update the current pin index entry
	if hole_data.pin_positions.size() > 0 and hole_data.current_pin_index < hole_data.pin_positions.size():
		hole_data.pin_positions[hole_data.current_pin_index] = new_position

	# Recalculate distance and par if green position changed
	hole_data.distance_yards = terrain_grid.calculate_distance_yards(
		hole_data.tee_position,
		new_position
	)
	_recalculate_par_with_override()

	# Recalculate difficulty
	hole_data.difficulty_rating = DifficultyCalculator.calculate_hole_difficulty(hole_data, terrain_grid)

	# Update visuals (shot path recalculates based on new flag position)
	_update_line()
	_update_info_label()
	_update_carry_annotations()
	_update_pin_markers()

	EventBus.hole_updated.emit(hole_data.hole_number)

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
		_update_carry_annotations()

func update_tee_position(new_tee_pos: Vector2i) -> void:
	hole_data.tee_position = new_tee_pos
	hole_data.tee_positions["back"] = new_tee_pos
	# Regenerate forward/middle tees relative to new back tee
	if GameManager.multi_tee_enabled:
		hole_data.auto_generate_tee_positions(terrain_grid)
		for tee_key in ["forward", "middle"]:
			var tee_pos: Vector2i = hole_data.tee_positions[tee_key]
			if tee_pos != new_tee_pos and terrain_grid.is_valid_position(tee_pos):
				terrain_grid.set_tile(tee_pos, TerrainTypes.Type.TEE_BOX)
	hole_data.distance_yards = terrain_grid.calculate_distance_yards(new_tee_pos, hole_data.hole_position)
	_recalculate_par_with_override()
	hole_data.recalculate_par_by_tee(terrain_grid)
	hole_data.difficulty_rating = DifficultyCalculator.calculate_hole_difficulty(hole_data, terrain_grid)
	_update_line()
	_update_info_label()
	_update_carry_annotations()
	_update_tee_markers()
	EventBus.hole_updated.emit(hole_data.hole_number)

func update_green_position(new_green_pos: Vector2i, move_pin: bool = true) -> void:
	hole_data.green_position = new_green_pos
	if move_pin:
		hole_data.hole_position = new_green_pos
		flag.set_position_in_grid(new_green_pos)
	# Regenerate pin positions for the new green
	hole_data.auto_generate_pin_positions(terrain_grid)
	if flag:
		flag.set_position_in_grid(hole_data.hole_position)
	# Regenerate tee positions (forward/middle depend on green location)
	if GameManager.multi_tee_enabled:
		hole_data.auto_generate_tee_positions(terrain_grid)
		for tee_key in ["forward", "middle"]:
			var tee_pos: Vector2i = hole_data.tee_positions[tee_key]
			if tee_pos != hole_data.tee_position and terrain_grid.is_valid_position(tee_pos):
				terrain_grid.set_tile(tee_pos, TerrainTypes.Type.TEE_BOX)
	hole_data.distance_yards = terrain_grid.calculate_distance_yards(hole_data.tee_position, hole_data.hole_position)
	_recalculate_par_with_override()
	hole_data.recalculate_par_by_tee(terrain_grid)
	hole_data.difficulty_rating = DifficultyCalculator.calculate_hole_difficulty(hole_data, terrain_grid)
	_update_line()
	_update_info_label()
	_update_carry_annotations()
	_update_tee_markers()
	_update_pin_markers()
	EventBus.hole_updated.emit(hole_data.hole_number)

func _recalculate_par_with_override() -> void:
	var auto_par = HoleCreationTool.calculate_par(hole_data.distance_yards)
	if hole_data.par_override > 0 and abs(hole_data.par_override - auto_par) <= 1:
		hole_data.par = hole_data.par_override
	else:
		hole_data.par_override = -1
		hole_data.par = auto_par

func _update_carry_annotations() -> void:
	for ann in carry_annotations:
		if is_instance_valid(ann):
			remove_child(ann)
			ann.free()
	carry_annotations.clear()

	if not hole_data or not terrain_grid:
		return
	if not carry_annotations_visible:
		return

	var segments = ForcedCarryCalculator.calculate_carries(hole_data, terrain_grid)
	for seg in segments:
		var ann = _create_carry_annotation(seg)
		add_child(ann)
		carry_annotations.append(ann)

func _create_carry_annotation(seg: ForcedCarryCalculator.CarrySegment) -> Node2D:
	var ann = Node2D.new()
	ann.z_index = 0

	var start_screen = terrain_grid.grid_to_screen_center(seg.start_grid)
	var end_screen = terrain_grid.grid_to_screen_center(seg.end_grid)
	var color = Color(0.9, 0.2, 0.2, 0.9) if seg.exceeds_beginner_range else Color(0.9, 0.5, 0.1, 0.8)

	# Draw carry line as series of short dashes
	var from_local = to_local(start_screen)
	var to_local_pos = to_local(end_screen)
	var dir = to_local_pos - from_local
	var total_len = dir.length()
	if total_len < 1.0:
		return ann
	var norm_dir = dir / total_len
	var dash_len = 6.0
	var gap_len = 4.0
	var pos = 0.0
	while pos < total_len:
		var dash_end = minf(pos + dash_len, total_len)
		var dash_line = Line2D.new()
		dash_line.width = 2.0
		dash_line.default_color = color
		dash_line.add_point(from_local + norm_dir * pos)
		dash_line.add_point(from_local + norm_dir * dash_end)
		ann.add_child(dash_line)
		pos = dash_end + gap_len

	# Yardage label at midpoint
	var mid = (from_local + to_local_pos) / 2.0
	var label = Label.new()
	label.text = "%dy carry" % seg.carry_yards
	label.position = mid + Vector2(-25, -15)
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 4)
	ann.add_child(label)

	return ann

func _update_tee_markers() -> void:
	for marker in tee_markers:
		if is_instance_valid(marker):
			remove_child(marker)
			marker.free()
	tee_markers.clear()

	if not hole_data or not terrain_grid or hole_data.tee_positions.is_empty():
		return
	if not GameManager.multi_tee_enabled:
		return

	# Draw markers for forward (red) and middle (white) tees only — back tee is implied by the shot line start
	var tee_configs = [
		{"key": "forward", "color": Color(0.9, 0.2, 0.2, 0.7)},  # Red
		{"key": "middle", "color": Color(0.9, 0.9, 0.9, 0.7)},   # White
	]
	for config in tee_configs:
		var tee_key: String = config["key"]
		if not hole_data.tee_positions.has(tee_key):
			continue
		var tee_pos: Vector2i = hole_data.tee_positions[tee_key]
		# Don't draw marker if same position as back tee
		if tee_pos == hole_data.tee_position:
			continue
		var marker = _create_tee_marker(tee_pos, config["color"])
		add_child(marker)
		tee_markers.append(marker)

func _create_tee_marker(grid_pos: Vector2i, color: Color) -> Node2D:
	var marker := Node2D.new()
	var screen_pos: Vector2 = terrain_grid.grid_to_screen_center(grid_pos)
	marker.position = to_local(screen_pos)
	marker.z_index = -1

	# Small filled rectangle to represent tee box
	var rect := Polygon2D.new()
	rect.polygon = PackedVector2Array([
		Vector2(-4, -2), Vector2(4, -2), Vector2(4, 2), Vector2(-4, 2)
	])
	rect.color = color
	marker.add_child(rect)

	# Dark outline
	var outline := Polygon2D.new()
	outline.polygon = PackedVector2Array([
		Vector2(-5, -3), Vector2(5, -3), Vector2(5, 3), Vector2(-5, 3)
	])
	outline.color = Color(0, 0, 0, 0.4)
	outline.z_index = -1
	marker.add_child(outline)
	# Move outline behind fill
	marker.move_child(outline, 0)

	return marker

func _update_pin_markers() -> void:
	for marker in pin_markers:
		if is_instance_valid(marker):
			remove_child(marker)
			marker.free()
	pin_markers.clear()

	if not hole_data or not terrain_grid or hole_data.pin_positions.size() <= 1:
		return

	# Draw dim markers at inactive pin positions
	for i in range(hole_data.pin_positions.size()):
		if i == hole_data.current_pin_index:
			continue  # Skip the active pin (it has the flag)
		var pin_pos: Vector2i = hole_data.pin_positions[i]
		var marker = _create_pin_marker(pin_pos)
		add_child(marker)
		pin_markers.append(marker)

func _create_pin_marker(grid_pos: Vector2i) -> Node2D:
	var marker := Node2D.new()
	var screen_pos: Vector2 = terrain_grid.grid_to_screen_center(grid_pos)
	marker.position = to_local(screen_pos)
	marker.z_index = -1

	# Small dim gold circle
	var circle := Polygon2D.new()
	var points := PackedVector2Array()
	for i in range(8):
		var angle: float = (i / 8.0) * TAU
		points.append(Vector2(cos(angle) * 3.0, sin(angle) * 3.0))
	circle.polygon = points
	circle.color = Color(0.8, 0.7, 0.2, 0.4)  # Dim gold
	marker.add_child(circle)

	return marker

func _on_pins_rotated() -> void:
	if not hole_data:
		return
	# Update flag to new pin position
	if flag and hole_data.pin_positions.size() > 0:
		flag.set_position_in_grid(hole_data.hole_position)
	# Refresh pin markers
	_update_pin_markers()
	# Recalculate shot path and carry for new pin
	_update_line()
	_update_carry_annotations()

func update_visualization() -> void:
	_update_line()
	_update_info_label()
	_update_carry_annotations()
	_update_tee_markers()
	_update_pin_markers()

func get_hole_number() -> int:
	return hole_data.hole_number if hole_data else 0

func _exit_tree() -> void:
	if EventBus.terrain_tile_changed.is_connected(_on_terrain_tile_changed):
		EventBus.terrain_tile_changed.disconnect(_on_terrain_tile_changed)
	if EventBus.pins_rotated.is_connected(_on_pins_rotated):
		EventBus.pins_rotated.disconnect(_on_pins_rotated)

func destroy() -> void:
	if flag:
		flag.destroy()
	queue_free()
