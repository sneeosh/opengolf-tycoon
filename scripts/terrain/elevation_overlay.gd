extends Node2D
class_name ElevationOverlay
## ElevationOverlay - Active-mode elevation tool feedback
##
## When the elevation tool is selected, renders:
## - Contour lines at elevation boundaries with variable weight
## - Elevation numbers on non-zero tiles
##
## Passive hillshade and gradient shading are now handled by the
## elevation_lighting shader (see heightmap.gd, elevation_shader_controller.gd).

var terrain_grid: TerrainGrid
var _elevation_active: bool = false  # More prominent when elevation tool is selected
var _needs_redraw: bool = true       # Track when elevation data changes

## Cached set of tiles that need drawing (elevated tiles + their neighbors)
var _relevant_tiles: Dictionary = {}  # Vector2i -> true

## Alpha levels
const CONTOUR_ALPHA_MINOR: float = 0.2  # Thin contour lines (every level)
const CONTOUR_ALPHA_MAJOR: float = 0.45 # Thick contour lines (every 2 levels)

func initialize(grid: TerrainGrid) -> void:
	terrain_grid = grid
	z_index = 4  # Above the shader overlay (z_index=3)

	# Listen for elevation changes to invalidate cache
	if terrain_grid.has_signal("elevation_changed"):
		terrain_grid.elevation_changed.connect(_on_elevation_changed)

	_needs_redraw = true

func set_elevation_mode_active(active: bool) -> void:
	_elevation_active = active
	_needs_redraw = true
	queue_redraw()

func _on_elevation_changed(_pos: Vector2i, _old: int, _new: int) -> void:
	_needs_redraw = true
	queue_redraw()

## Rebuild the set of tiles that need drawing: any tile with elevation + neighbors
func _rebuild_relevant_tiles() -> void:
	_relevant_tiles.clear()
	for pos in terrain_grid._elevation_grid:
		_relevant_tiles[pos] = true
		# Include all 4 neighbors (for contour rendering at boundaries)
		for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var neighbor = pos + offset
			if terrain_grid.is_valid_position(neighbor):
				_relevant_tiles[neighbor] = true

func _draw() -> void:
	if not terrain_grid:
		return

	# Only draw when elevation tool is active
	if not _elevation_active:
		return

	if _needs_redraw:
		_rebuild_relevant_tiles()
		_needs_redraw = false

	if _relevant_tiles.is_empty():
		return

	var tw = terrain_grid.tile_width
	var th = terrain_grid.tile_height

	for pos in _relevant_tiles:
		var elevation = terrain_grid.get_elevation(pos)
		var screen_pos = terrain_grid.grid_to_screen(pos)
		var local_pos = to_local(screen_pos)

		# --- Contour lines at elevation boundaries ---
		if elevation != 0 or _has_elevated_neighbor(pos):
			_draw_contour_lines(pos, local_pos, tw, th)

		# --- Elevation numbers ---
		if elevation != 0:
			var text_pos = local_pos + Vector2(tw * 0.35, th * 0.7)
			var sign_str = "+" if elevation > 0 else ""
			draw_string(
				ThemeDB.fallback_font,
				text_pos,
				"%s%d" % [sign_str, elevation],
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				9,
				Color(1, 1, 1, 0.7)
			)

## Check if any of the 4 neighbors has non-zero elevation
func _has_elevated_neighbor(pos: Vector2i) -> bool:
	for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var neighbor = pos + offset
		if terrain_grid.is_valid_position(neighbor) and terrain_grid.get_elevation(neighbor) != 0:
			return true
	return false

## Draw contour lines with variable weight at elevation boundaries
func _draw_contour_lines(pos: Vector2i, local_pos: Vector2, tw: int, th: int) -> void:
	var elevation = terrain_grid.get_elevation(pos)

	# Check each edge for elevation change
	var neighbors = {
		"right": Vector2i(pos.x + 1, pos.y),
		"bottom": Vector2i(pos.x, pos.y + 1),
		"left": Vector2i(pos.x - 1, pos.y),
		"top": Vector2i(pos.x, pos.y - 1),
	}

	for edge in neighbors:
		var n_pos = neighbors[edge]
		if not terrain_grid.is_valid_position(n_pos):
			continue
		var n_elev = terrain_grid.get_elevation(n_pos)
		if n_elev == elevation:
			continue

		# Determine line weight: thick for major intervals (crossing even levels)
		var elev_diff = abs(elevation - n_elev)
		var is_major = elev_diff >= 2 or (elevation % 2 == 0 and n_elev % 2 != 0) or (elevation != 0 and n_elev == 0)
		var line_width = 2.0 if is_major else 1.0
		var alpha = CONTOUR_ALPHA_MAJOR if is_major else CONTOUR_ALPHA_MINOR

		# Color: brown for boundaries, darker for deeper
		var avg_elev = (elevation + n_elev) / 2.0
		var contour_color: Color
		if avg_elev >= 0:
			contour_color = Color(0.55, 0.4, 0.25, alpha)  # Warm brown
		else:
			contour_color = Color(0.2, 0.25, 0.4, alpha)    # Cool blue-gray

		# Draw the edge line
		match edge:
			"right":
				draw_line(local_pos + Vector2(tw, 0), local_pos + Vector2(tw, th), contour_color, line_width, true)
			"bottom":
				draw_line(local_pos + Vector2(0, th), local_pos + Vector2(tw, th), contour_color, line_width, true)
			"left":
				draw_line(local_pos, local_pos + Vector2(0, th), contour_color, line_width, true)
			"top":
				draw_line(local_pos, local_pos + Vector2(tw, 0), contour_color, line_width, true)
