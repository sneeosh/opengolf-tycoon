extends Node2D
class_name MeasurementOverlay
## Draws a yardage measurement line when user ctrl-click-drags on the course.

var terrain_grid: TerrainGrid
var measuring: bool = false
var start_pos: Vector2i = Vector2i.ZERO
var end_pos: Vector2i = Vector2i.ZERO

func update_measurement(start: Vector2i, end: Vector2i, active: bool) -> void:
	start_pos = start
	end_pos = end
	measuring = active
	queue_redraw()

func _draw() -> void:
	if not measuring or not terrain_grid:
		return
	if start_pos == end_pos:
		return

	var start_screen = terrain_grid.grid_to_screen_center(start_pos)
	var end_screen = terrain_grid.grid_to_screen_center(end_pos)
	var distance_yards = terrain_grid.calculate_distance_yards(start_pos, end_pos)

	# Draw main line
	var line_color = Color(0.3, 0.8, 1.0, 0.8)
	draw_line(start_screen, end_screen, line_color, 2.5, true)

	# Draw dashed white overlay
	var line_length = start_screen.distance_to(end_screen)
	var direction = (end_screen - start_screen).normalized()
	var dash_length = 8.0
	var current_dist = 0.0
	var dash_on = true
	while current_dist < line_length:
		if dash_on:
			var dash_start = start_screen + direction * current_dist
			var dash_end_dist = min(current_dist + dash_length, line_length)
			var dash_end = start_screen + direction * dash_end_dist
			draw_line(dash_start, dash_end, Color(1.0, 1.0, 1.0, 0.3), 1.5, true)
		dash_on = not dash_on
		current_dist += dash_length

	# Draw endpoint circles
	draw_circle(start_screen, 4.0, line_color)
	draw_circle(end_screen, 4.0, line_color)

	# Draw yardage label at midpoint
	var midpoint = (start_screen + end_screen) / 2.0
	var font = ThemeDB.fallback_font
	var font_size = 14
	var text = "%d yds" % distance_yards

	# Background box
	var box_width = 70.0
	var box_height = 24.0
	var box_pos = midpoint - Vector2(box_width / 2, box_height / 2)
	draw_rect(Rect2(box_pos, Vector2(box_width, box_height)), Color(0.1, 0.1, 0.1, 0.85))
	draw_rect(Rect2(box_pos, Vector2(box_width, box_height)), line_color, false, 1.5)

	# Text
	draw_string(font, midpoint + Vector2(-25, 5), text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)
