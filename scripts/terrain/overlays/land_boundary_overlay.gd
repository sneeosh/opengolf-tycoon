extends Node2D
class_name LandBoundaryOverlay
## LandBoundaryOverlay - Draws property lines around owned land
##
## Shows a visible border between owned and unowned parcels, and
## applies a subtle tint to unowned areas so players know where
## they can and cannot build. Premium/Elite parcels get distinct
## border colors and tints.

var terrain_grid: TerrainGrid

## Visual settings
const BOUNDARY_COLOR = Color(0.9, 0.6, 0.2, 0.8)  # Orange/gold property line
const BOUNDARY_WIDTH: float = 2.5
const UNOWNED_TINT = Color(0.4, 0.3, 0.3, 0.15)  # Subtle dark tint on unowned land

## Tier-specific visuals
const PREMIUM_BORDER_COLOR = Color(0.9, 0.75, 0.2, 0.9)   # Gold
const ELITE_BORDER_COLOR = Color(0.7, 0.8, 0.95, 0.9)      # Platinum
const PREMIUM_TINT = Color(0.7, 0.6, 0.2, 0.08)            # Subtle gold tint
const ELITE_TINT = Color(0.5, 0.6, 0.8, 0.08)              # Subtle blue tint
const PREMIUM_BOUNDARY_WIDTH: float = 3.5
const ELITE_BOUNDARY_WIDTH: float = 3.5

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

func _draw() -> void:
	if not terrain_grid:
		return
	if not GameManager.land_manager:
		return

	# Recalculate boundary edges if needed
	if _needs_recalculate:
		_calculate_boundary_edges()
		_needs_recalculate = false

	var tw = terrain_grid.tile_width
	var th = terrain_grid.tile_height
	var lm = GameManager.land_manager

	# Draw tint on unowned tiles — tier-specific tints for premium/elite
	for x in range(terrain_grid.grid_width):
		for y in range(terrain_grid.grid_height):
			var pos = Vector2i(x, y)
			if not lm.is_tile_owned(pos):
				var screen_pos = terrain_grid.grid_to_screen(pos)
				var local_pos = to_local(screen_pos)
				var parcel = lm.tile_to_parcel(pos)
				var tint = UNOWNED_TINT
				if parcel != Vector2i(-1, -1):
					var tier = lm.get_parcel_tier(parcel)
					if tier == LandManager.ParcelTier.PREMIUM:
						tint = PREMIUM_TINT
					elif tier == LandManager.ParcelTier.ELITE:
						tint = ELITE_TINT
				draw_rect(Rect2(local_pos, Vector2(tw, th)), tint)

	# Draw property line borders with tier-specific colors
	for edge in _boundary_edges:
		var start_screen = terrain_grid.grid_to_screen(edge.start_tile) + edge.start_offset
		var end_screen = terrain_grid.grid_to_screen(edge.end_tile) + edge.end_offset
		var local_start = to_local(start_screen)
		var local_end = to_local(end_screen)

		var color = edge.get("color", BOUNDARY_COLOR)
		var width = edge.get("width", BOUNDARY_WIDTH)
		draw_line(local_start, local_end, color, width, true)

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

			# Determine border color based on the unowned neighbor's tier
			# Right neighbor
			var right = Vector2i(x + 1, y)
			if not lm.is_tile_owned(right):
				var edge_data = _make_edge(pos, Vector2(tw, 0), pos, Vector2(tw, th))
				_apply_tier_style(edge_data, right, lm)
				_boundary_edges.append(edge_data)

			# Bottom neighbor
			var bottom = Vector2i(x, y + 1)
			if not lm.is_tile_owned(bottom):
				var edge_data = _make_edge(pos, Vector2(0, th), pos, Vector2(tw, th))
				_apply_tier_style(edge_data, bottom, lm)
				_boundary_edges.append(edge_data)

			# Left neighbor
			var left = Vector2i(x - 1, y)
			if not lm.is_tile_owned(left):
				var edge_data = _make_edge(pos, Vector2(0, 0), pos, Vector2(0, th))
				_apply_tier_style(edge_data, left, lm)
				_boundary_edges.append(edge_data)

			# Top neighbor
			var top = Vector2i(x, y - 1)
			if not lm.is_tile_owned(top):
				var edge_data = _make_edge(pos, Vector2(0, 0), pos, Vector2(tw, 0))
				_apply_tier_style(edge_data, top, lm)
				_boundary_edges.append(edge_data)

func _make_edge(s_tile: Vector2i, s_off: Vector2, e_tile: Vector2i, e_off: Vector2) -> Dictionary:
	return {
		"start_tile": s_tile,
		"start_offset": s_off,
		"end_tile": e_tile,
		"end_offset": e_off,
		"color": BOUNDARY_COLOR,
		"width": BOUNDARY_WIDTH,
	}

func _apply_tier_style(edge: Dictionary, neighbor_tile: Vector2i, lm: LandManager) -> void:
	var parcel = lm.tile_to_parcel(neighbor_tile)
	if parcel == Vector2i(-1, -1):
		return
	var tier = lm.get_parcel_tier(parcel)
	if tier == LandManager.ParcelTier.PREMIUM:
		edge["color"] = PREMIUM_BORDER_COLOR
		edge["width"] = PREMIUM_BOUNDARY_WIDTH
	elif tier == LandManager.ParcelTier.ELITE:
		edge["color"] = ELITE_BORDER_COLOR
		edge["width"] = ELITE_BOUNDARY_WIDTH
