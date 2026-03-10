extends Node2D
class_name RoutingOverlay
## RoutingOverlay - Visualizes inter-hole walking routes (green N → tee N+1).
## Toggle with R key. Color-coded by distance: green (short), yellow (moderate), red (long).

var terrain_grid: TerrainGrid
var _visible_overlay: bool = false
var _route_segments: Array = []

const SHORT_THRESHOLD: float = 30.0  # tiles
const MODERATE_THRESHOLD: float = 60.0  # tiles

func initialize(grid: TerrainGrid) -> void:
	terrain_grid = grid
	z_index = 10
	visible = false
	EventBus.hole_created.connect(_on_holes_changed.bind())
	EventBus.hole_deleted.connect(_on_hole_changed_single)
	EventBus.hole_updated.connect(_on_hole_changed_single)
	EventBus.load_completed.connect(_on_load_completed)

func toggle() -> void:
	_visible_overlay = not _visible_overlay
	visible = _visible_overlay
	if _visible_overlay:
		_recalculate_routes()

func is_overlay_visible() -> bool:
	return _visible_overlay

func _recalculate_routes() -> void:
	_route_segments.clear()
	if not GameManager.current_course:
		queue_redraw()
		return

	var holes = GameManager.current_course.holes
	for i in range(holes.size() - 1):
		var from_hole = holes[i]
		var to_hole = holes[i + 1]
		var from_green = from_hole.green_position
		var to_tee = to_hole.tee_position
		var distance = Vector2(from_green).distance_to(Vector2(to_tee))

		var color: Color
		if distance < SHORT_THRESHOLD:
			color = Color(0.3, 0.9, 0.3, 0.6)
		elif distance < MODERATE_THRESHOLD:
			color = Color(0.9, 0.9, 0.3, 0.6)
		else:
			color = Color(0.9, 0.3, 0.3, 0.6)

		_route_segments.append({
			"from_green": from_green,
			"to_tee": to_tee,
			"distance_tiles": distance,
			"color": color,
			"from_hole": from_hole.hole_number,
			"to_hole": to_hole.hole_number,
		})

	queue_redraw()

func _draw() -> void:
	if not terrain_grid or not _visible_overlay:
		return

	for seg in _route_segments:
		var from_screen = terrain_grid.grid_to_screen_center(seg.from_green)
		var to_screen = terrain_grid.grid_to_screen_center(seg.to_tee)
		var from_local = to_local(from_screen)
		var to_local_pos = to_local(to_screen)

		# Draw dotted walking path line
		var dir = to_local_pos - from_local
		var total_len = dir.length()
		if total_len < 1.0:
			continue
		var norm_dir = dir / total_len
		var dash_len = 8.0
		var gap_len = 5.0
		var pos = 0.0
		while pos < total_len:
			var dash_end = minf(pos + dash_len, total_len)
			draw_line(
				from_local + norm_dir * pos,
				from_local + norm_dir * dash_end,
				seg.color, 2.5, true
			)
			pos = dash_end + gap_len

		# Distance label at midpoint
		var mid = (from_local + to_local_pos) / 2.0
		var font = ThemeDB.fallback_font
		var text = "%d tiles" % int(seg.distance_tiles)
		draw_string(font, mid + Vector2(-20, -8), text, HORIZONTAL_ALIGNMENT_CENTER, -1, 10, seg.color)

func _on_holes_changed(_hole_number: int = 0, _par: int = 0, _distance: int = 0) -> void:
	if _visible_overlay:
		_recalculate_routes()

func _on_hole_changed_single(_hole_number: int) -> void:
	if _visible_overlay:
		_recalculate_routes()

func _on_load_completed(_success: bool) -> void:
	if _visible_overlay:
		call_deferred("_recalculate_routes")

## Calculate average inter-hole walk distance for pace rating penalty.
static func calculate_avg_walk_distance() -> float:
	if not GameManager.current_course:
		return 0.0
	var holes = GameManager.current_course.holes
	if holes.size() < 2:
		return 0.0
	var total_distance: float = 0.0
	for i in range(holes.size() - 1):
		total_distance += Vector2(holes[i].green_position).distance_to(Vector2(holes[i + 1].tee_position))
	return total_distance / float(holes.size() - 1)
