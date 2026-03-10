extends Node2D
class_name FairwayWidthOverlay
## FairwayWidthOverlay - Shows fairway width markers at key distances from tee

var terrain_grid: TerrainGrid = null
var _enabled: bool = false
var _marker_data: Array = []  # Array of {screen_pos, width, color, label, line_start, line_end}

const MARKER_DISTANCES_YARDS = [150, 200, 250]
const YARDS_PER_TILE: float = 22.0

func initialize(grid: TerrainGrid) -> void:
	terrain_grid = grid
	z_index = 98
	visible = false
	EventBus.terrain_tile_changed.connect(_on_terrain_changed)
	EventBus.hole_created.connect(_on_hole_changed)
	EventBus.hole_deleted.connect(_on_hole_changed)
	EventBus.load_completed.connect(_on_load_completed)

func _exit_tree() -> void:
	if EventBus.terrain_tile_changed.is_connected(_on_terrain_changed):
		EventBus.terrain_tile_changed.disconnect(_on_terrain_changed)
	if EventBus.hole_created.is_connected(_on_hole_changed):
		EventBus.hole_created.disconnect(_on_hole_changed)
	if EventBus.hole_deleted.is_connected(_on_hole_changed):
		EventBus.hole_deleted.disconnect(_on_hole_changed)
	if EventBus.load_completed.is_connected(_on_load_completed):
		EventBus.load_completed.disconnect(_on_load_completed)

func toggle() -> void:
	_enabled = not _enabled
	visible = _enabled
	if _enabled:
		_recalculate()
		EventBus.notify("Fairway Width Overlay: ON", "info")
	else:
		EventBus.notify("Fairway Width Overlay: OFF", "info")

func _on_terrain_changed(_pos: Vector2i, _old: int, _new: int) -> void:
	if _enabled:
		_recalculate()

func _on_hole_changed(_a = null, _b = null, _c = null) -> void:
	if _enabled:
		_recalculate()

func _on_load_completed(_success: bool) -> void:
	if _enabled:
		_recalculate()

func _recalculate() -> void:
	_marker_data.clear()
	if not terrain_grid or not GameManager.current_course:
		queue_redraw()
		return

	for hole in GameManager.current_course.holes:
		if not hole.is_open:
			continue
		var tee = Vector2(hole.tee_position)
		var green = Vector2(hole.green_position)
		var grid_dir = (green - tee).normalized()
		var total_dist = tee.distance_to(green)
		var grid_perp = Vector2(-grid_dir.y, grid_dir.x)

		# Compute screen-space perpendicular (tiles are 64x32, not square)
		var tee_screen = terrain_grid.grid_to_screen_center(hole.tee_position)
		var green_screen = terrain_grid.grid_to_screen_center(hole.green_position)
		var screen_dir = (green_screen - tee_screen).normalized()
		var screen_perp = Vector2(-screen_dir.y, screen_dir.x)

		for yards in MARKER_DISTANCES_YARDS:
			var tile_dist = yards / YARDS_PER_TILE
			if tile_dist >= total_dist:
				continue  # Beyond the green

			var sample_center = tee + grid_dir * tile_dist
			var sample_pos = Vector2i(sample_center.round())

			# Count fairway width perpendicular to hole line (in grid space)
			var width = 0
			var left_count = 0
			for i in range(1, 15):
				var check = Vector2i((sample_center + grid_perp * i).round())
				if terrain_grid.is_valid_position(check) and terrain_grid.get_tile(check) == TerrainTypes.Type.FAIRWAY:
					left_count += 1
				else:
					break
			var right_count = 0
			for i in range(1, 15):
				var check = Vector2i((sample_center - grid_perp * i).round())
				if terrain_grid.is_valid_position(check) and terrain_grid.get_tile(check) == TerrainTypes.Type.FAIRWAY:
					right_count += 1
				else:
					break
			var center_is_fairway = terrain_grid.is_valid_position(sample_pos) and terrain_grid.get_tile(sample_pos) == TerrainTypes.Type.FAIRWAY
			width = left_count + right_count + (1 if center_is_fairway else 0)

			if width == 0:
				continue

			# Color coding
			var color: Color
			if width <= 2:
				color = Color(0.9, 0.3, 0.3, 0.7)  # Red - tight
			elif width <= 4:
				color = Color(0.9, 0.8, 0.2, 0.7)  # Yellow - moderate
			else:
				color = Color(0.3, 0.8, 0.3, 0.7)  # Green - generous

			# Convert exact grid positions to screen space (no rounding)
			var screen_center = terrain_grid.grid_to_screen_precise(sample_center)
			var screen_left = terrain_grid.grid_to_screen_precise(sample_center + grid_perp * (left_count + 0.5))
			var screen_right = terrain_grid.grid_to_screen_precise(sample_center - grid_perp * (right_count + 0.5))

			_marker_data.append({
				"screen_pos": screen_center,
				"line_start": screen_left,
				"line_end": screen_right,
				"width": width,
				"yards": yards,
				"color": color,
			})

	queue_redraw()

func _draw() -> void:
	if not _enabled or _marker_data.is_empty():
		return

	for marker in _marker_data:
		# Draw perpendicular line
		draw_line(marker.line_start, marker.line_end, marker.color, 2.0)

		# Draw end caps
		draw_circle(marker.line_start, 2.5, marker.color)
		draw_circle(marker.line_end, 2.5, marker.color)

		# Draw label with outline for readability
		var label_pos = (marker.line_start + marker.line_end) * 0.5 + Vector2(0, -8)
		var text = "%dy: %d wide" % [marker.yards, marker.width]
		var font = ThemeDB.fallback_font
		font.draw_string_outline(get_canvas_item(), label_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, 11, 4, Color(0, 0, 0, 0.95))
		draw_string(font, label_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, 11, marker.color)
