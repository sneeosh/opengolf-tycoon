extends Node2D
class_name LandBoundaryOverlay
## LandBoundaryOverlay - Draws property lines around owned land
##
## Shows a visible border between owned and unowned parcels, and
## applies a subtle tint to unowned areas so players know where
## they can and cannot build.

var terrain_grid: TerrainGrid

## Visual settings
const BOUNDARY_COLOR = Color(0.9, 0.6, 0.2, 0.8)  # Orange/gold property line
const BOUNDARY_WIDTH: float = 2.5
const UNOWNED_TINT = Color(0.4, 0.3, 0.3, 0.15)  # Subtle dark tint on unowned land

## Cache the boundary edges to avoid recalculating every frame
var _boundary_edges: Array = []  # Array of {start: Vector2, end: Vector2}
var _needs_recalculate: bool = true

func initialize(grid: TerrainGrid) -> void:
	terrain_grid = grid
	z_index = 5  # Above terrain but below UI elements

	# Defer signal connection - land_manager may not exist yet
	call_deferred("_connect_land_signals")

	_needs_recalculate = true
	queue_redraw()

func _connect_land_signals() -> void:
	# Connect to land manager signals (deferred to ensure manager exists)
	if GameManager.land_manager:
		if not GameManager.land_manager.land_purchased.is_connected(_on_land_changed):
			GameManager.land_manager.land_purchased.connect(_on_land_changed)
		if not GameManager.land_manager.land_boundary_changed.is_connected(_on_land_boundary_changed):
			GameManager.land_manager.land_boundary_changed.connect(_on_land_boundary_changed)

func _on_land_boundary_changed() -> void:
	_needs_recalculate = true
	queue_redraw()

func _on_land_changed(_parcel = null) -> void:
	_needs_recalculate = true
	queue_redraw()

func _process(_delta: float) -> void:
	# Redraw each frame for camera panning (viewport culling handles performance)
	queue_redraw()

func _draw() -> void:
	if not terrain_grid:
		return
	if not GameManager.land_manager:
		return

	# Recalculate boundary edges if needed
	if _needs_recalculate:
		_calculate_boundary_edges()
		_needs_recalculate = false

	# Viewport culling
	var canvas_transform = get_canvas_transform()
	var viewport_rect = get_viewport_rect()
	var visible_rect = Rect2(
		-canvas_transform.origin / canvas_transform.get_scale(),
		viewport_rect.size / canvas_transform.get_scale()
	).grow(100)

	var tw = terrain_grid.tile_width
	var th = terrain_grid.tile_height
	var lm = GameManager.land_manager

	# Draw tint on unowned tiles (only visible portion)
	var start_x = max(0, int((visible_rect.position.x - 100) / tw))
	var end_x = min(terrain_grid.grid_width, int((visible_rect.end.x + 100) / tw) + 1)
	var start_y = max(0, int((visible_rect.position.y - 100) / th))
	var end_y = min(terrain_grid.grid_height, int((visible_rect.end.y + 100) / th) + 1)

	for x in range(start_x, end_x):
		for y in range(start_y, end_y):
			var pos = Vector2i(x, y)
			if not lm.is_tile_owned(pos):
				var screen_pos = terrain_grid.grid_to_screen(pos)
				if visible_rect.has_point(screen_pos):
					var local_pos = to_local(screen_pos)
					draw_rect(Rect2(local_pos, Vector2(tw, th)), UNOWNED_TINT)

	# Draw property line borders
	for edge in _boundary_edges:
		var start_screen = terrain_grid.grid_to_screen(edge.start_tile) + edge.start_offset
		var end_screen = terrain_grid.grid_to_screen(edge.end_tile) + edge.end_offset

		if not visible_rect.has_point(start_screen) and not visible_rect.has_point(end_screen):
			continue

		var local_start = to_local(start_screen)
		var local_end = to_local(end_screen)
		draw_line(local_start, local_end, BOUNDARY_COLOR, BOUNDARY_WIDTH, true)

func _calculate_boundary_edges() -> void:
	"""Calculate all boundary edges between owned and unowned tiles."""
	_boundary_edges.clear()

	if not GameManager.land_manager:
		return

	var lm = GameManager.land_manager
	var tw = terrain_grid.tile_width
	var th = terrain_grid.tile_height

	# Check every tile for boundary edges
	for x in range(terrain_grid.grid_width):
		for y in range(terrain_grid.grid_height):
			var pos = Vector2i(x, y)
			var is_owned = lm.is_tile_owned(pos)

			if not is_owned:
				continue  # Only draw borders from owned side

			# Check each neighbor
			# Right neighbor
			var right = Vector2i(x + 1, y)
			if not lm.is_tile_owned(right):
				_boundary_edges.append({
					"start_tile": pos,
					"start_offset": Vector2(tw, 0),
					"end_tile": pos,
					"end_offset": Vector2(tw, th)
				})

			# Bottom neighbor
			var bottom = Vector2i(x, y + 1)
			if not lm.is_tile_owned(bottom):
				_boundary_edges.append({
					"start_tile": pos,
					"start_offset": Vector2(0, th),
					"end_tile": pos,
					"end_offset": Vector2(tw, th)
				})

			# Left neighbor
			var left = Vector2i(x - 1, y)
			if not lm.is_tile_owned(left):
				_boundary_edges.append({
					"start_tile": pos,
					"start_offset": Vector2(0, 0),
					"end_tile": pos,
					"end_offset": Vector2(0, th)
				})

			# Top neighbor
			var top = Vector2i(x, y - 1)
			if not lm.is_tile_owned(top):
				_boundary_edges.append({
					"start_tile": pos,
					"start_offset": Vector2(0, 0),
					"end_tile": pos,
					"end_offset": Vector2(tw, 0)
				})
