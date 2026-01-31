extends Node2D
class_name WaterOverlay
## WaterOverlay - Renders animated shimmer effect on water tiles

var terrain_grid: TerrainGrid
var _water_positions: Array = []
var _time: float = 0.0

func initialize(grid: TerrainGrid) -> void:
	terrain_grid = grid
	z_index = 1  # Render just above terrain tiles
	_scan_water_tiles()
	EventBus.connect("terrain_tile_changed", _on_terrain_tile_changed)

func _scan_water_tiles() -> void:
	_water_positions.clear()
	if not terrain_grid:
		return
	for x in range(terrain_grid.grid_width):
		for y in range(terrain_grid.grid_height):
			var pos = Vector2i(x, y)
			if terrain_grid.get_tile(pos) == TerrainTypes.Type.WATER:
				_water_positions.append(pos)

func _on_terrain_tile_changed(position: Vector2i, old_type: int, new_type: int) -> void:
	if new_type == TerrainTypes.Type.WATER:
		if position not in _water_positions:
			_water_positions.append(position)
	elif old_type == TerrainTypes.Type.WATER:
		_water_positions.erase(position)
	queue_redraw()

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	if not terrain_grid or _water_positions.is_empty():
		return

	# Only draw water tiles visible in the viewport
	var canvas_transform = get_canvas_transform()
	var viewport_rect = get_viewport_rect()
	var visible_rect = Rect2(
		-canvas_transform.origin / canvas_transform.get_scale(),
		viewport_rect.size / canvas_transform.get_scale()
	)

	for pos in _water_positions:
		var screen_pos = terrain_grid.grid_to_screen(pos)
		if not visible_rect.has_point(screen_pos):
			continue

		var local_pos = to_local(screen_pos)

		# Animated shimmer using sine waves with position-based offset
		var wave_offset = float(pos.x * 3 + pos.y * 7)
		var alpha = 0.08 + 0.06 * sin(_time * 2.5 + wave_offset)
		var highlight_alpha = 0.04 + 0.04 * sin(_time * 1.8 + wave_offset + 1.5)

		# Draw shimmer rectangle covering the tile
		var tile_rect = Rect2(local_pos, Vector2(terrain_grid.tile_width, terrain_grid.tile_height))

		# Base wave tint
		draw_rect(tile_rect, Color(0.4, 0.7, 1.0, alpha))

		# Highlight streak
		var streak_y = local_pos.y + terrain_grid.tile_height * 0.3 + sin(_time * 1.5 + wave_offset) * 4.0
		var streak_rect = Rect2(
			Vector2(local_pos.x + 4, streak_y),
			Vector2(terrain_grid.tile_width - 8, 3)
		)
		draw_rect(streak_rect, Color(0.8, 0.9, 1.0, highlight_alpha))
