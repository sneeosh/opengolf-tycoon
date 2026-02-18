extends Node2D
class_name ElevationShadingOverlay
## ElevationShadingOverlay - Subtle brightness adjustment based on terrain elevation
## Higher tiles appear slightly brighter, lower tiles slightly darker

var _terrain_grid: TerrainGrid = null
const BRIGHTNESS_PER_LEVEL: float = 0.025  # Brightness shift per elevation level

func _ready() -> void:
	z_index = 2  # Above base terrain and grass overlays

func setup(terrain_grid: TerrainGrid) -> void:
	_terrain_grid = terrain_grid
	terrain_grid.elevation_changed.connect(_on_elevation_changed)
	queue_redraw()

func _on_elevation_changed(_pos: Vector2i, _old: int, _new: int) -> void:
	queue_redraw()

func _draw() -> void:
	if not _terrain_grid:
		return

	var tw = _terrain_grid.tile_width
	var th = _terrain_grid.tile_height

	for pos in _terrain_grid._elevation_grid:
		var elevation = _terrain_grid._elevation_grid[pos]
		if elevation == 0:
			continue

		var screen_pos = _terrain_grid.grid_to_screen(pos)
		var local_pos = screen_pos - global_position

		if elevation > 0:
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
