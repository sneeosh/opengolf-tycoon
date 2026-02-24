extends Node2D
class_name TerrainDebugOverlay
## Debug overlay that visualizes terrain types per tile

var terrain_grid: TerrainGrid = null
var _enabled: bool = false

# Colors for each terrain type (semi-transparent for overlay)
const TYPE_COLORS = {
	0: Color(0.2, 0.2, 0.2, 0.5),   # EMPTY - dark gray
	1: Color(0.4, 0.7, 0.3, 0.5),   # GRASS - green
	2: Color(0.3, 0.9, 0.3, 0.5),   # FAIRWAY - bright green
	3: Color(0.5, 0.6, 0.4, 0.5),   # ROUGH - muted green
	4: Color(0.4, 0.5, 0.3, 0.5),   # HEAVY_ROUGH - dark green
	5: Color(0.2, 1.0, 0.4, 0.5),   # GREEN - cyan-green
	6: Color(0.5, 0.8, 0.5, 0.5),   # TEE_BOX - light green
	7: Color(0.9, 0.8, 0.5, 0.5),   # BUNKER - tan/sand
	8: Color(0.2, 0.4, 0.9, 0.5),   # WATER - blue
	9: Color(0.7, 0.7, 0.6, 0.5),   # PATH - gray-tan
	10: Color(0.8, 0.2, 0.2, 0.5),  # OUT_OF_BOUNDS - red
	11: Color(0.1, 0.4, 0.1, 0.5),  # TREES - dark green
	12: Color(0.9, 0.4, 0.6, 0.5),  # FLOWER_BED - pink
	13: Color(0.5, 0.5, 0.5, 0.5),  # ROCKS - gray
}

func initialize(grid: TerrainGrid) -> void:
	terrain_grid = grid
	z_index = 100  # Render on top of everything
	visible = false

func toggle() -> void:
	_enabled = not _enabled
	visible = _enabled
	if _enabled:
		queue_redraw()

func is_enabled() -> bool:
	return _enabled

func _draw() -> void:
	if not _enabled or not terrain_grid:
		return

	var tile_width = terrain_grid.tile_width
	var tile_height = terrain_grid.tile_height

	# Only draw visible tiles instead of full 128x128 grid
	var tile_range = terrain_grid.get_visible_tile_range()
	var min_tile = tile_range[0]
	var max_tile = tile_range[1]

	for x in range(min_tile.x, max_tile.x + 1):
		for y in range(min_tile.y, max_tile.y + 1):
			var pos = Vector2i(x, y)
			var screen_pos = terrain_grid.grid_to_screen(pos)
			var local_pos = to_local(screen_pos)
			var terrain_type = terrain_grid.get_tile(pos)
			var color = TYPE_COLORS.get(terrain_type, Color.MAGENTA)

			# Draw colored overlay rectangle
			var rect = Rect2(local_pos, Vector2(tile_width, tile_height))
			draw_rect(rect, color)

			# Draw terrain type number in center
			var center = local_pos + Vector2(tile_width / 2.0 - 4, tile_height / 2.0 + 4)
			var font = ThemeDB.fallback_font
			if font:
				draw_string(font, center, str(terrain_type), HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color.WHITE)
