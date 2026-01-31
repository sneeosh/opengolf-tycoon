extends Node
class_name ElevationTool
## ElevationTool - Manages raise/lower terrain elevation painting

enum ElevationMode {
	NONE,
	RAISING,
	LOWERING
}

var elevation_mode: ElevationMode = ElevationMode.NONE
var is_painting: bool = false
var last_paint_pos: Vector2i = Vector2i(-1, -1)

signal elevation_mode_changed(mode: ElevationMode)

func start_raising() -> void:
	elevation_mode = ElevationMode.RAISING
	elevation_mode_changed.emit(elevation_mode)

func start_lowering() -> void:
	elevation_mode = ElevationMode.LOWERING
	elevation_mode_changed.emit(elevation_mode)

func cancel() -> void:
	elevation_mode = ElevationMode.NONE
	is_painting = false
	last_paint_pos = Vector2i(-1, -1)
	elevation_mode_changed.emit(elevation_mode)

func is_active() -> bool:
	return elevation_mode != ElevationMode.NONE

## Paint elevation at the given grid position using the current mode
## Returns array of changes for undo tracking: [{position, old_elevation, new_elevation}]
func paint_elevation(grid_pos: Vector2i, terrain_grid: TerrainGrid, brush_size: int = 1) -> Array:
	if elevation_mode == ElevationMode.NONE:
		return []
	if not terrain_grid or not terrain_grid.is_valid_position(grid_pos):
		return []

	var change_amount = 1 if elevation_mode == ElevationMode.RAISING else -1
	var tiles = [grid_pos] if brush_size <= 1 else terrain_grid.get_brush_tiles(grid_pos, brush_size)
	var changes: Array = []

	for tile_pos in tiles:
		var old_elevation = terrain_grid.get_elevation(tile_pos)
		var new_elevation = clampi(old_elevation + change_amount, -5, 5)
		if new_elevation != old_elevation:
			terrain_grid.set_elevation(tile_pos, new_elevation)
			changes.append({
				"position": tile_pos,
				"old_elevation": old_elevation,
				"new_elevation": new_elevation
			})

	return changes
