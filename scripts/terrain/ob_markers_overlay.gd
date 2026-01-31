extends Node2D
class_name OBMarkersOverlay
## OBMarkersOverlay - Renders white stake markers at OB boundary edges

var terrain_grid: TerrainGrid
var _boundary_positions: Array = []

func initialize(grid: TerrainGrid) -> void:
	terrain_grid = grid
	z_index = 2  # Render above terrain overlays
	_calculate_boundaries()
	EventBus.connect("terrain_tile_changed", _on_terrain_tile_changed)

func _calculate_boundaries() -> void:
	_boundary_positions.clear()
	if not terrain_grid:
		return

	for x in range(terrain_grid.grid_width):
		for y in range(terrain_grid.grid_height):
			var pos = Vector2i(x, y)
			if terrain_grid.get_tile(pos) == TerrainTypes.Type.OUT_OF_BOUNDS:
				if _is_boundary_tile(pos):
					_boundary_positions.append(pos)
	queue_redraw()

func _is_boundary_tile(pos: Vector2i) -> bool:
	# A boundary tile is an OB tile adjacent to at least one non-OB tile
	var neighbors = [
		pos + Vector2i(1, 0),
		pos + Vector2i(-1, 0),
		pos + Vector2i(0, 1),
		pos + Vector2i(0, -1)
	]
	for neighbor in neighbors:
		if not terrain_grid.is_valid_position(neighbor):
			continue
		if terrain_grid.get_tile(neighbor) != TerrainTypes.Type.OUT_OF_BOUNDS:
			return true
	return false

func _on_terrain_tile_changed(position: Vector2i, old_type: int, new_type: int) -> void:
	# Recalculate if OB tiles changed or neighbors of OB changed
	if old_type == TerrainTypes.Type.OUT_OF_BOUNDS or new_type == TerrainTypes.Type.OUT_OF_BOUNDS:
		_calculate_boundaries()

func _draw() -> void:
	if not terrain_grid or _boundary_positions.is_empty():
		return

	# Only draw stakes visible in the viewport
	var canvas_transform = get_canvas_transform()
	var viewport_rect = get_viewport_rect()
	var visible_rect = Rect2(
		-canvas_transform.origin / canvas_transform.get_scale(),
		viewport_rect.size / canvas_transform.get_scale()
	)

	for pos in _boundary_positions:
		var screen_pos = terrain_grid.grid_to_screen(pos)
		if not visible_rect.has_point(screen_pos):
			continue

		var local_pos = to_local(screen_pos)
		# Center the stake in the tile
		var stake_x = local_pos.x + terrain_grid.tile_width * 0.5
		var stake_base_y = local_pos.y + terrain_grid.tile_height * 0.5

		# White stake: thin white rectangle
		var stake_rect = Rect2(
			Vector2(stake_x - 1.5, stake_base_y - 14),
			Vector2(3, 14)
		)
		draw_rect(stake_rect, Color.WHITE)

		# Small red top cap
		var cap_rect = Rect2(
			Vector2(stake_x - 2, stake_base_y - 16),
			Vector2(4, 3)
		)
		draw_rect(cap_rect, Color(0.9, 0.2, 0.2))
