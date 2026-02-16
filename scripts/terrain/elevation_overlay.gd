extends Node2D
class_name ElevationOverlay
## ElevationOverlay - Visual shading for terrain elevation
##
## Renders elevation as:
## - Always-visible subtle hillshade and gradient shading (passive mode)
## - More prominent contour lines and elevation numbers when elevation tool active
## - Only redraws when elevation data changes

var terrain_grid: TerrainGrid
var _elevation_active: bool = false  # More prominent when elevation tool is selected
var _needs_redraw: bool = true       # Track when elevation data changes

## Hillshade light direction (NW light source, conventional for maps)
const LIGHT_DIR: Vector2 = Vector2(-0.7, -0.7)  # Normalized NW direction
const HILLSHADE_INTENSITY: float = 0.18  # How strong the directional shading is

## Alpha levels
const PASSIVE_ALPHA: float = 0.12       # Subtle always-on shading
const ACTIVE_ALPHA: float = 0.25        # Prominent when tool is active
const CONTOUR_ALPHA_MINOR: float = 0.2  # Thin contour lines (every level)
const CONTOUR_ALPHA_MAJOR: float = 0.45 # Thick contour lines (every 2 levels)

func initialize(grid: TerrainGrid) -> void:
	terrain_grid = grid
	z_index = 1

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

func _draw() -> void:
	if not terrain_grid:
		return

	_needs_redraw = false

	var base_alpha = ACTIVE_ALPHA if _elevation_active else PASSIVE_ALPHA
	var tw = terrain_grid.tile_width
	var th = terrain_grid.tile_height

	for x in range(terrain_grid.grid_width):
		for y in range(terrain_grid.grid_height):
			var pos = Vector2i(x, y)
			var elevation = terrain_grid.get_elevation(pos)
			var screen_pos = terrain_grid.grid_to_screen(pos)
			var local_pos = to_local(screen_pos)

			# --- Gradient elevation shading (always drawn if non-zero) ---
			if elevation != 0:
				var color = _get_elevation_color(elevation, base_alpha)
				draw_rect(Rect2(local_pos, Vector2(tw, th)), color)

			# --- Hillshade effect (slope-based directional shading) ---
			var hillshade_color = _calculate_hillshade(pos, base_alpha * 0.8)
			if hillshade_color.a > 0.01:
				draw_rect(Rect2(local_pos, Vector2(tw, th)), hillshade_color)

			# --- Contour lines at elevation boundaries ---
			if elevation != 0 or _has_elevated_neighbor(pos):
				_draw_contour_lines(pos, local_pos, tw, th)

			# --- Elevation numbers (only in active mode) ---
			if _elevation_active and elevation != 0:
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

## Get a color representing this elevation level with natural relief tones
func _get_elevation_color(elevation: int, alpha: float) -> Color:
	if elevation > 0:
		# Higher = warm light tones (cream → pale yellow)
		var t = float(elevation) / 5.0
		return Color(
			lerp(0.9, 1.0, t),
			lerp(0.85, 0.95, t),
			lerp(0.7, 0.6, t),
			alpha * t
		)
	else:
		# Lower = cool dark tones (slate blue → deep blue)
		var t = float(abs(elevation)) / 5.0
		return Color(
			lerp(0.2, 0.05, t),
			lerp(0.2, 0.1, t),
			lerp(0.35, 0.4, t),
			alpha * t
		)

## Calculate hillshade color based on slope relative to light direction
func _calculate_hillshade(pos: Vector2i, max_alpha: float) -> Color:
	# Get elevation of this tile and its neighbors
	var elev_c = float(terrain_grid.get_elevation(pos))
	var elev_r = float(terrain_grid.get_elevation(Vector2i(pos.x + 1, pos.y))) if terrain_grid.is_valid_position(Vector2i(pos.x + 1, pos.y)) else elev_c
	var elev_b = float(terrain_grid.get_elevation(Vector2i(pos.x, pos.y + 1))) if terrain_grid.is_valid_position(Vector2i(pos.x, pos.y + 1)) else elev_c

	# Compute slope gradient (dz/dx, dz/dy)
	var slope = Vector2(elev_r - elev_c, elev_b - elev_c)

	if slope.length_squared() < 0.01:
		return Color(0, 0, 0, 0)  # Flat — no hillshade

	# Dot product with light direction: positive = lit face, negative = shadow
	var shade = slope.normalized().dot(LIGHT_DIR)

	if shade > 0:
		# Lit face — subtle warm highlight
		return Color(1.0, 0.95, 0.85, shade * max_alpha * HILLSHADE_INTENSITY * 3.0)
	else:
		# Shadow face — cool shadow
		return Color(0.1, 0.1, 0.25, abs(shade) * max_alpha * HILLSHADE_INTENSITY * 4.0)

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
		var line_width = 2.0 if (is_major and _elevation_active) else 1.0
		var alpha = CONTOUR_ALPHA_MAJOR if is_major else CONTOUR_ALPHA_MINOR
		if not _elevation_active:
			alpha *= 0.5  # Subtler in passive mode

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
