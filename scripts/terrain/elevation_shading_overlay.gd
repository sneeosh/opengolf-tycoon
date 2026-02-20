extends Node2D
class_name ElevationShadingOverlay
## ElevationShadingOverlay - Subtle brightness adjustment based on terrain elevation
## Higher tiles appear slightly brighter, lower tiles slightly darker

var _terrain_grid: TerrainGrid = null
var _is_web: bool = false
const BRIGHTNESS_PER_LEVEL: float = 0.025  # Brightness shift per elevation level

func _ready() -> void:
	z_index = 2  # Above base terrain and grass overlays
	_is_web = OS.get_name() == "Web"

func setup(terrain_grid: TerrainGrid) -> void:
	_terrain_grid = terrain_grid
	terrain_grid.elevation_changed.connect(_on_elevation_changed)
	queue_redraw()

func _on_elevation_changed(_pos: Vector2i, _old: int, _new: int) -> void:
	queue_redraw()

func _draw() -> void:
	if not _terrain_grid:
		return

	# On web, use simple rectangles instead of isometric diamond polygons
	# to reduce per-tile polygon vertex count (4-vertex rect vs 4-vertex polygon,
	# but Rect2 is GPU-optimized vs colored_polygon requiring CPU vertex assembly)
	var tw = _terrain_grid.tile_width
	var th = _terrain_grid.tile_height

	for pos in _terrain_grid._elevation_grid:
		var elevation = _terrain_grid._elevation_grid[pos]
		if elevation == 0:
			continue

		var screen_pos = _terrain_grid.grid_to_screen(pos)
		var local_pos = screen_pos - global_position

		if _is_web:
			# Web: fast axis-aligned rect (cheaper than colored_polygon)
			var alpha = abs(elevation) * BRIGHTNESS_PER_LEVEL
			var tint_color = Color(1, 1, 1, alpha) if elevation > 0 else Color(0, 0, 0, alpha)
			draw_rect(Rect2(local_pos, Vector2(tw, th)), tint_color)
		elif elevation > 0:
			# Higher ground — subtle white tint
			var alpha = elevation * BRIGHTNESS_PER_LEVEL
			var iso_diamond = PackedVector2Array([
				Vector2(local_pos.x + tw * 0.5, local_pos.y),
				Vector2(local_pos.x + tw, local_pos.y + th * 0.5),
				Vector2(local_pos.x + tw * 0.5, local_pos.y + th),
				Vector2(local_pos.x, local_pos.y + th * 0.5)
			])
			draw_colored_polygon(iso_diamond, Color(1, 1, 1, alpha))
		else:
			# Lower ground — subtle dark tint
			var alpha = abs(elevation) * BRIGHTNESS_PER_LEVEL
			var iso_diamond = PackedVector2Array([
				Vector2(local_pos.x + tw * 0.5, local_pos.y),
				Vector2(local_pos.x + tw, local_pos.y + th * 0.5),
				Vector2(local_pos.x + tw * 0.5, local_pos.y + th),
				Vector2(local_pos.x, local_pos.y + th * 0.5)
			])
			draw_colored_polygon(iso_diamond, Color(0, 0, 0, alpha))
