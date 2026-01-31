extends Node2D
class_name ElevationOverlay
## ElevationOverlay - Visual shading for terrain elevation

var terrain_grid: TerrainGrid
var _elevation_active: bool = false  # More prominent when elevation tool is selected

func initialize(grid: TerrainGrid) -> void:
	terrain_grid = grid
	z_index = 1

func set_elevation_mode_active(active: bool) -> void:
	_elevation_active = active
	queue_redraw()

func _process(_delta: float) -> void:
	# Only redraw occasionally to save performance
	if _elevation_active:
		queue_redraw()

func _draw() -> void:
	if not terrain_grid:
		return

	# Only draw tiles visible in the viewport
	var canvas_transform = get_canvas_transform()
	var viewport_rect = get_viewport_rect()
	var visible_rect = Rect2(
		-canvas_transform.origin / canvas_transform.get_scale(),
		viewport_rect.size / canvas_transform.get_scale()
	)

	# Base alpha: always visible, more prominent when elevation tool is active
	var base_alpha = 0.2 if _elevation_active else 0.15

	for x in range(terrain_grid.grid_width):
		for y in range(terrain_grid.grid_height):
			var pos = Vector2i(x, y)
			var elevation = terrain_grid.get_elevation(pos)
			if elevation == 0:
				continue

			var screen_pos = terrain_grid.grid_to_screen(pos)
			if not visible_rect.has_point(screen_pos):
				continue

			var local_pos = to_local(screen_pos)
			var tile_rect = Rect2(local_pos, Vector2(terrain_grid.tile_width, terrain_grid.tile_height))

			var color: Color
			if elevation > 0:
				# Higher = lighter/brighter tint
				var intensity = float(elevation) / 5.0
				color = Color(1.0, 1.0, 0.8, base_alpha * intensity)
			else:
				# Lower = darker tint
				var intensity = float(abs(elevation)) / 5.0
				color = Color(0.0, 0.0, 0.2, base_alpha * intensity)

			draw_rect(tile_rect, color)

			# Draw contour lines at elevation boundaries
			var contour_color = Color(0.0, 0.0, 0.0, 0.3) if elevation < 0 else Color(1.0, 1.0, 0.8, 0.3)
			var tw = terrain_grid.tile_width
			var th = terrain_grid.tile_height
			# Right neighbor
			var right_pos = Vector2i(x + 1, y)
			if terrain_grid.is_valid_position(right_pos) and terrain_grid.get_elevation(right_pos) != elevation:
				draw_line(local_pos + Vector2(tw, 0), local_pos + Vector2(tw, th), contour_color, 1.5)
			# Bottom neighbor
			var bottom_pos = Vector2i(x, y + 1)
			if terrain_grid.is_valid_position(bottom_pos) and terrain_grid.get_elevation(bottom_pos) != elevation:
				draw_line(local_pos + Vector2(0, th), local_pos + Vector2(tw, th), contour_color, 1.5)
			# Left neighbor
			var left_pos = Vector2i(x - 1, y)
			if terrain_grid.is_valid_position(left_pos) and terrain_grid.get_elevation(left_pos) != elevation:
				draw_line(local_pos, local_pos + Vector2(0, th), contour_color, 1.5)
			# Top neighbor
			var top_pos = Vector2i(x, y - 1)
			if terrain_grid.is_valid_position(top_pos) and terrain_grid.get_elevation(top_pos) != elevation:
				draw_line(local_pos, local_pos + Vector2(tw, 0), contour_color, 1.5)

			# In elevation mode, also draw the elevation number
			if _elevation_active and abs(elevation) > 0:
				var text_pos = local_pos + Vector2(terrain_grid.tile_width * 0.35, terrain_grid.tile_height * 0.7)
				var sign_str = "+" if elevation > 0 else ""
				draw_string(
					ThemeDB.fallback_font,
					text_pos,
					"%s%d" % [sign_str, elevation],
					HORIZONTAL_ALIGNMENT_LEFT,
					-1,
					9,
					Color(1, 1, 1, 0.6) if _elevation_active else Color(1, 1, 1, 0.3)
				)
