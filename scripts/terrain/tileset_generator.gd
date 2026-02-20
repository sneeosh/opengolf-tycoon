extends Node
class_name TilesetGenerator
## Generates a textured tileset image with autotile variants for terrain transitions

const TILE_WIDTH = 64
const TILE_HEIGHT = 32
const ATLAS_COLS = 16
const ATLAS_ROWS = 16

## Web platform detection (cached once)
static var _is_web: bool = false
static var _web_checked: bool = false

static func _check_web() -> void:
	if not _web_checked:
		_is_web = OS.get_name() == "Web"
		_web_checked = true

# Edge mask bits for autotiling (cardinal directions only for simplified approach)
const EDGE_N = 1
const EDGE_E = 2
const EDGE_S = 4
const EDGE_W = 8

# Atlas layout: Each terrain type gets a row, with 16 variants per row
# Variant index = edge mask (0-15 for all combinations of N/E/S/W edges)
enum TerrainRow {
	GRASS = 0,
	FAIRWAY = 1,
	GREEN = 2,
	ROUGH = 3,
	HEAVY_ROUGH = 4,
	BUNKER = 5,
	WATER = 6,
	# Single-tile terrains (no autotiling needed)
	SINGLES = 7  # TEE_BOX, PATH, OB, TREES, FLOWER_BED, ROCKS, EMPTY
}

# Active color palette (set by theme system, falls back to TERRAIN_COLORS)
static var _active_colors: Dictionary = {}

# Default base colors for each terrain type (Parkland theme)
const TERRAIN_COLORS = {
	"grass": Color(0.42, 0.58, 0.32),
	"fairway_light": Color(0.42, 0.78, 0.42),
	"fairway_dark": Color(0.36, 0.72, 0.36),
	"green_light": Color(0.38, 0.88, 0.48),
	"green_dark": Color(0.34, 0.82, 0.44),
	"fringe": Color(0.40, 0.80, 0.44),  # Between green and fairway for edge collar
	"rough": Color(0.36, 0.52, 0.30),
	"heavy_rough": Color(0.30, 0.45, 0.26),
	"bunker": Color(0.92, 0.85, 0.62),
	"water": Color(0.25, 0.55, 0.85),
	"empty": Color(0.18, 0.22, 0.18),
	"tee_box_light": Color(0.48, 0.76, 0.45),
	"tee_box_dark": Color(0.42, 0.70, 0.40),
	"path": Color(0.75, 0.72, 0.65),
	"oob": Color(0.40, 0.33, 0.30),
	"trees": Color(0.20, 0.42, 0.20),
	"flower_bed": Color(0.45, 0.32, 0.22),
	"rocks": Color(0.48, 0.46, 0.42),
}

## Apply a theme's color palette for the next tileset generation
static func set_theme_colors(colors: Dictionary) -> void:
	_active_colors = colors

## Get the active color for a terrain key, falling back to default
static func get_color(key: String) -> Color:
	if _active_colors.has(key):
		return _active_colors[key]
	return TERRAIN_COLORS.get(key, Color.MAGENTA)

# Legacy function for backward compatibility
static func generate_tileset() -> ImageTexture:
	return generate_expanded_tileset()

static func generate_expanded_tileset() -> ImageTexture:
	_check_web()
	var image = Image.create(TILE_WIDTH * ATLAS_COLS, TILE_HEIGHT * ATLAS_ROWS, false, Image.FORMAT_RGBA8)

	if _is_web:
		# Web: Use fast flat-fill tileset with edge blending only (no per-pixel noise)
		# The shader provides all visual variation — tileset just needs base colors + edges
		_generate_terrain_row_fast(image, TerrainRow.GRASS, "grass", "rough")
		_generate_terrain_row_fast(image, TerrainRow.FAIRWAY, "fairway_light", "rough")
		_generate_terrain_row_fast(image, TerrainRow.GREEN, "green_light", "fringe")
		_generate_terrain_row_fast(image, TerrainRow.ROUGH, "rough", "heavy_rough")
		_generate_terrain_row_fast(image, TerrainRow.HEAVY_ROUGH, "heavy_rough", "grass")
		_generate_terrain_row_fast(image, TerrainRow.BUNKER, "bunker", "grass")
		_generate_terrain_row_fast(image, TerrainRow.WATER, "water", "grass")

		# Single-tile terrains — flat fill only
		_fill_tile(image, 0, TerrainRow.SINGLES, get_color("empty"))
		_fill_tile(image, 1, TerrainRow.SINGLES, get_color("tee_box_light"))
		_fill_tile(image, 2, TerrainRow.SINGLES, get_color("path"))
		_fill_tile(image, 3, TerrainRow.SINGLES, get_color("oob"))
		_fill_tile(image, 4, TerrainRow.SINGLES, get_color("trees"))
		_fill_tile(image, 5, TerrainRow.SINGLES, get_color("flower_bed"))
		_fill_tile(image, 6, TerrainRow.SINGLES, get_color("rocks"))
	else:
		# Desktop: Full per-pixel detail tileset
		_generate_terrain_row(image, TerrainRow.GRASS, "_draw_grass_variant")
		_generate_terrain_row(image, TerrainRow.FAIRWAY, "_draw_fairway_variant")
		_generate_terrain_row(image, TerrainRow.GREEN, "_draw_green_variant")
		_generate_terrain_row(image, TerrainRow.ROUGH, "_draw_rough_variant")
		_generate_terrain_row(image, TerrainRow.HEAVY_ROUGH, "_draw_heavy_rough_variant")
		_generate_terrain_row(image, TerrainRow.BUNKER, "_draw_bunker_variant")
		_generate_terrain_row(image, TerrainRow.WATER, "_draw_water_variant")

		# Single-tile terrains in row 7
		_draw_empty_tile(image, 0, TerrainRow.SINGLES)
		_draw_tee_box_tile(image, 1, TerrainRow.SINGLES)
		_draw_path_tile(image, 2, TerrainRow.SINGLES)
		_draw_oob_tile(image, 3, TerrainRow.SINGLES)
		_draw_trees_tile(image, 4, TerrainRow.SINGLES)
		_draw_flower_bed_tile(image, 5, TerrainRow.SINGLES)
		_draw_rocks_tile(image, 6, TerrainRow.SINGLES)

	var texture = ImageTexture.create_from_image(image)
	return texture

## Fast tileset generation for web: flat-fill base color with simple edge blending
## Uses fill_rect for base and only iterates edge pixels, ~10x faster than per-pixel
static func _generate_terrain_row_fast(image: Image, row: int, base_key: String, edge_key: String) -> void:
	var base_color = get_color(base_key)
	var edge_color = get_color(edge_key)

	for edge_mask in range(16):
		var col = edge_mask
		var rect = _get_tile_rect(col, row)

		# Fast base fill
		image.fill_rect(rect, base_color)

		# Only do edge blending if there are edges
		if edge_mask == 0:
			continue

		# Simplified edge blending — only iterate edge zone pixels
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			for y in range(rect.position.y, rect.position.y + rect.size.y):
				var local_x = x - rect.position.x
				var local_y = y - rect.position.y

				# Quick check: skip interior pixels (not in any edge zone)
				if not _is_in_edge_zone(local_x, local_y, edge_mask):
					continue

				var blend = _get_edge_blend_factor(local_x, local_y, edge_mask)
				if blend > 0.05:
					var blended = base_color.lerp(edge_color, blend * 0.5)
					image.set_pixel(x, y, blended)

static func _generate_terrain_row(image: Image, row: int, draw_func_name: String) -> void:
	# Generate 16 variants (edge_mask 0-15)
	for edge_mask in range(16):
		var col = edge_mask
		match draw_func_name:
			"_draw_grass_variant":
				_draw_grass_variant(image, col, row, edge_mask)
			"_draw_fairway_variant":
				_draw_fairway_variant(image, col, row, edge_mask)
			"_draw_green_variant":
				_draw_green_variant(image, col, row, edge_mask)
			"_draw_rough_variant":
				_draw_rough_variant(image, col, row, edge_mask)
			"_draw_heavy_rough_variant":
				_draw_heavy_rough_variant(image, col, row, edge_mask)
			"_draw_bunker_variant":
				_draw_bunker_variant(image, col, row, edge_mask)
			"_draw_water_variant":
				_draw_water_variant(image, col, row, edge_mask)

static func _get_tile_rect(col: int, row: int) -> Rect2i:
	return Rect2i(col * TILE_WIDTH, row * TILE_HEIGHT, TILE_WIDTH, TILE_HEIGHT)

static func _fill_tile(image: Image, col: int, row: int, color: Color) -> void:
	var rect = _get_tile_rect(col, row)
	image.fill_rect(rect, color)

# Edge thickness for transition drawing - larger for smoother gradients
const EDGE_WIDTH = 16
const CORNER_BLEND_RADIUS = 20.0  # For diagonal corner smoothing

static func _is_in_edge_zone(local_x: int, local_y: int, edge_mask: int) -> bool:
	var in_n = local_y < EDGE_WIDTH and (edge_mask & EDGE_N)
	var in_s = local_y >= TILE_HEIGHT - EDGE_WIDTH and (edge_mask & EDGE_S)
	var in_w = local_x < EDGE_WIDTH and (edge_mask & EDGE_W)
	var in_e = local_x >= TILE_WIDTH - EDGE_WIDTH and (edge_mask & EDGE_E)
	return in_n or in_s or in_w or in_e

static func _get_edge_blend_factor(local_x: int, local_y: int, edge_mask: int) -> float:
	# Returns 0.0-1.0 for how much to blend toward edge color
	# Uses smooth falloff and handles corners properly
	var blend_factors: Array[float] = []

	# Cardinal edge blends with smooth cubic falloff
	if edge_mask & EDGE_N:
		var t = float(local_y) / EDGE_WIDTH
		if t < 1.0:
			blend_factors.append(_smooth_falloff(1.0 - t))
	if edge_mask & EDGE_S:
		var t = float(TILE_HEIGHT - 1 - local_y) / EDGE_WIDTH
		if t < 1.0:
			blend_factors.append(_smooth_falloff(1.0 - t))
	if edge_mask & EDGE_W:
		var t = float(local_x) / EDGE_WIDTH
		if t < 1.0:
			blend_factors.append(_smooth_falloff(1.0 - t))
	if edge_mask & EDGE_E:
		var t = float(TILE_WIDTH - 1 - local_x) / EDGE_WIDTH
		if t < 1.0:
			blend_factors.append(_smooth_falloff(1.0 - t))

	# Handle corners - blend based on distance from corner
	var corner_blend = _get_corner_blend(local_x, local_y, edge_mask)
	if corner_blend > 0:
		blend_factors.append(corner_blend)

	if blend_factors.is_empty():
		return 0.0

	# Use max blend factor for final result
	var max_blend = 0.0
	for f in blend_factors:
		max_blend = max(max_blend, f)

	return clamp(max_blend, 0.0, 1.0)

static func _smooth_falloff(t: float) -> float:
	# Smooth cubic falloff (ease-in-out style) for natural gradient
	t = clamp(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

static func _get_corner_blend(local_x: int, local_y: int, edge_mask: int) -> float:
	# Check diagonal corners and blend based on distance
	var corner_blend = 0.0

	# NW corner
	if (edge_mask & EDGE_N) and (edge_mask & EDGE_W):
		var dist = Vector2(local_x, local_y).length()
		if dist < CORNER_BLEND_RADIUS:
			corner_blend = max(corner_blend, _smooth_falloff(1.0 - dist / CORNER_BLEND_RADIUS))

	# NE corner
	if (edge_mask & EDGE_N) and (edge_mask & EDGE_E):
		var dist = Vector2(TILE_WIDTH - 1 - local_x, local_y).length()
		if dist < CORNER_BLEND_RADIUS:
			corner_blend = max(corner_blend, _smooth_falloff(1.0 - dist / CORNER_BLEND_RADIUS))

	# SW corner
	if (edge_mask & EDGE_S) and (edge_mask & EDGE_W):
		var dist = Vector2(local_x, TILE_HEIGHT - 1 - local_y).length()
		if dist < CORNER_BLEND_RADIUS:
			corner_blend = max(corner_blend, _smooth_falloff(1.0 - dist / CORNER_BLEND_RADIUS))

	# SE corner
	if (edge_mask & EDGE_S) and (edge_mask & EDGE_E):
		var dist = Vector2(TILE_WIDTH - 1 - local_x, TILE_HEIGHT - 1 - local_y).length()
		if dist < CORNER_BLEND_RADIUS:
			corner_blend = max(corner_blend, _smooth_falloff(1.0 - dist / CORNER_BLEND_RADIUS))

	return corner_blend

# ============ GRASS VARIANTS ============
# Grass tiles have subtle random grain texture. The runtime shader adds larger-scale
# continuous variation, so we only add fine detail here that won't create visible tile seams.

static func _draw_grass_variant(image: Image, col: int, row: int, edge_mask: int) -> void:
	var base = get_color("grass")
	var edge_color = get_color("rough")  # Grass edges blend to rough
	var rect = _get_tile_rect(col, row)
	var rng = RandomNumberGenerator.new()
	# Use edge_mask as part of seed so edge variants look slightly different
	rng.seed = 98765 + edge_mask * 111

	for x in range(rect.position.x, rect.position.x + rect.size.x):
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			var local_x = x - rect.position.x
			var local_y = y - rect.position.y

			# Add fine random grain texture (per-pixel noise)
			# This creates subtle grass-like texture without creating tile-boundary patterns
			var grain = rng.randf_range(-0.03, 0.03)

			var base_color = Color(
				base.r + grain,
				base.g + grain * 1.3,  # Slightly more variation in green channel
				base.b + grain * 0.7
			)

			# Only blend edges for autotile transitions (when edge_mask != 0)
			var blend = _get_edge_blend_factor(local_x, local_y, edge_mask)
			if blend > 0:
				base_color = base_color.lerp(edge_color, blend * 0.55)

			image.set_pixel(x, y, base_color)

# ============ FAIRWAY VARIANTS ============

static func _draw_fairway_variant(image: Image, col: int, row: int, edge_mask: int) -> void:
	var light = get_color("fairway_light")
	var dark = get_color("fairway_dark")
	var edge_color = get_color("rough")  # Fairway edges blend to rough
	var rect = _get_tile_rect(col, row)
	var rng = RandomNumberGenerator.new()
	rng.seed = 34567 + edge_mask * 1000

	for x in range(rect.position.x, rect.position.x + rect.size.x):
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			var local_x = x - rect.position.x
			var local_y = y - rect.position.y

			# Diagonal mowing stripes with soft edges
			var stripe_pos = float(local_x + local_y) / 8.0
			var stripe_t = fmod(stripe_pos, 1.0)
			# Smooth stripe transition instead of hard edge
			var stripe_blend = smoothstep(0.4, 0.6, stripe_t) if stripe_t < 0.5 else 1.0 - smoothstep(0.9, 1.0, stripe_t)
			var base = light.lerp(dark, stripe_blend)

			# Add subtle variation within stripes
			var noise = rng.randf_range(-0.025, 0.025)
			var grain = sin(x * 0.9 + y * 0.4) * 0.015
			var base_color = Color(
				base.r + noise + grain,
				base.g + noise * 1.1 + grain,
				base.b + noise * 0.9
			)

			# Blend edges - mowing stripes fade out at edges
			var blend = _get_edge_blend_factor(local_x, local_y, edge_mask)
			if blend > 0:
				# Edges lose the stripe pattern and blend to rough
				# Derive intermediate color from theme (between fairway and rough)
				var edge_base = light.lerp(edge_color, 0.4)
				base_color = base_color.lerp(edge_base, blend * 0.5)
				base_color = base_color.lerp(edge_color, blend * 0.4)

			image.set_pixel(x, y, base_color)

# Smoothstep helper for soft transitions
static func smoothstep(edge0: float, edge1: float, x: float) -> float:
	var t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

# ============ GREEN VARIANTS (with fringe at edges) ============

static func _draw_green_variant(image: Image, col: int, row: int, edge_mask: int) -> void:
	var light = get_color("green_light")
	var dark = get_color("green_dark")
	var fringe_color = get_color("fringe")
	# Derive outer fringe from theme (between fringe and fairway colors)
	var fairway_color = get_color("fairway_light")
	var outer_fringe = fringe_color.lerp(fairway_color, 0.5).darkened(0.08)
	var rect = _get_tile_rect(col, row)
	var rng = RandomNumberGenerator.new()
	rng.seed = 67890 + edge_mask * 1000

	for x in range(rect.position.x, rect.position.x + rect.size.x):
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			var local_x = x - rect.position.x
			var local_y = y - rect.position.y

			# Fine horizontal stripes for putting green
			var stripe = int(local_y / 4) % 2
			var base = light if stripe == 0 else dark
			var noise = rng.randf_range(-0.015, 0.015)
			var base_color = Color(base.r + noise, base.g + noise, base.b + noise)

			# Fringe collar at edges - key feature for green autotiling
			var blend = _get_edge_blend_factor(local_x, local_y, edge_mask)
			if blend > 0:
				# Two-zone fringe: inner fringe (light) and outer fringe (darker, rougher)
				if blend < 0.5:
					# Inner fringe - stripes fade out, slight color shift
					var t = blend / 0.5
					var fringe_noise = rng.randf_range(-0.02, 0.02)
					var inner_fringe = Color(
						fringe_color.r + fringe_noise,
						fringe_color.g + fringe_noise * 1.1,
						fringe_color.b + fringe_noise * 0.8
					)
					# Fade stripes and shift color
					base_color = base_color.lerp(inner_fringe, _smooth_falloff(t) * 0.7)
				else:
					# Outer fringe - rougher texture, darker color
					var t = (blend - 0.5) / 0.5
					var fringe_noise = rng.randf_range(-0.04, 0.04)
					# Add some grass tuft texture
					var tuft = sin(x * 0.6 + y * 0.4) * 0.03
					var outer = Color(
						outer_fringe.r + fringe_noise + tuft,
						outer_fringe.g + fringe_noise * 1.2 + tuft,
						outer_fringe.b + fringe_noise * 0.7
					)
					base_color = fringe_color.lerp(outer, _smooth_falloff(t))

			image.set_pixel(x, y, base_color)

# ============ ROUGH VARIANTS ============

static func _draw_rough_variant(image: Image, col: int, row: int, edge_mask: int) -> void:
	var base = get_color("rough")
	var edge_color = get_color("heavy_rough")
	var rect = _get_tile_rect(col, row)
	var rng = RandomNumberGenerator.new()
	rng.seed = 45678 + edge_mask * 1000

	for x in range(rect.position.x, rect.position.x + rect.size.x):
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			var local_x = x - rect.position.x
			var local_y = y - rect.position.y

			# Multi-frequency noise for organic variation
			var noise = rng.randf_range(-0.10, 0.10)
			var tuft_large = sin(x * 0.4 + y * 0.2) * 0.06
			var tuft_med = sin(x * 0.8 + y * 0.3) * 0.045
			var grain = sin(x * 1.5 + y * 0.6) * 0.025

			var combined = noise + tuft_large + tuft_med + grain

			var base_color = Color(
				base.r + combined,
				base.g + combined * 1.35,
				base.b + combined * 0.65
			)

			var blend = _get_edge_blend_factor(local_x, local_y, edge_mask)
			if blend > 0:
				base_color = base_color.lerp(edge_color, blend * 0.5)

			image.set_pixel(x, y, base_color)

# ============ HEAVY ROUGH VARIANTS ============

static func _draw_heavy_rough_variant(image: Image, col: int, row: int, edge_mask: int) -> void:
	var base = get_color("heavy_rough")
	var edge_color = get_color("grass")  # Heavy rough edges blend back to grass
	var rect = _get_tile_rect(col, row)
	var rng = RandomNumberGenerator.new()
	rng.seed = 56789 + edge_mask * 1000

	for x in range(rect.position.x, rect.position.x + rect.size.x):
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			var local_x = x - rect.position.x
			var local_y = y - rect.position.y

			# Multi-frequency noise with extra variation for wild appearance
			var noise = rng.randf_range(-0.12, 0.12)
			var clump_large = sin(x * 0.3 + y * 0.25) * 0.07
			var clump_med = sin(x * 0.6) * sin(y * 0.9) * 0.06
			var grain = sin(x * 1.1 + y * 0.7) * cos(x * 0.5) * 0.03

			var combined = noise + clump_large + clump_med + grain

			var base_color = Color(
				base.r + combined,
				base.g + combined * 1.4,
				base.b + combined * 0.55
			)

			var blend = _get_edge_blend_factor(local_x, local_y, edge_mask)
			if blend > 0:
				base_color = base_color.lerp(edge_color, blend * 0.5)

			image.set_pixel(x, y, base_color)

# ============ BUNKER VARIANTS ============

static func _draw_bunker_variant(image: Image, col: int, row: int, edge_mask: int) -> void:
	var base = get_color("bunker")
	var edge_color = get_color("grass")  # Sand edges blend to grass (lip)
	var rect = _get_tile_rect(col, row)
	var rng = RandomNumberGenerator.new()
	rng.seed = 89012 + edge_mask * 1000

	for x in range(rect.position.x, rect.position.x + rect.size.x):
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			var local_x = x - rect.position.x
			var local_y = y - rect.position.y

			var noise = rng.randf_range(-0.08, 0.08)
			var grain = rng.randf_range(-0.04, 0.04)
			var base_color = Color(base.r + noise + grain, base.g + noise * 0.9 + grain, base.b + noise * 0.5)

			# Bunker lip at edges
			var blend = _get_edge_blend_factor(local_x, local_y, edge_mask)
			if blend > 0:
				# Create darker sand lip, then grass
				var lip_color = Color(base.r * 0.85, base.g * 0.82, base.b * 0.7)
				if blend < 0.5:
					base_color = base_color.lerp(lip_color, blend * 1.5)
				else:
					base_color = lip_color.lerp(edge_color, (blend - 0.5) * 1.5)

			image.set_pixel(x, y, base_color)

# ============ WATER VARIANTS ============

static func _draw_water_variant(image: Image, col: int, row: int, edge_mask: int) -> void:
	var base = get_color("water")
	var rect = _get_tile_rect(col, row)
	var rng = RandomNumberGenerator.new()
	rng.seed = 90123 + edge_mask * 1000

	# Multi-zone shoreline colors - derived from theme colors
	var shallow_water = base.lightened(0.15)  # Lighter version of theme water
	var bunker_color = get_color("bunker")
	var wet_sand = bunker_color.darkened(0.25)  # Wet sand from theme bunker
	var dry_sand = bunker_color.darkened(0.10)  # Dry sand lighter
	var grass_edge = get_color("grass")  # Use theme grass

	for x in range(rect.position.x, rect.position.x + rect.size.x):
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			var local_x = x - rect.position.x
			var local_y = y - rect.position.y

			var wave = sin(local_x * 0.2 + local_y * 0.1) * 0.06
			var noise = rng.randf_range(-0.03, 0.03)
			var base_color = Color(base.r + wave + noise, base.g + wave * 0.8 + noise, base.b + wave * 0.3 + noise)

			# Multi-zone shoreline transition
			var blend = _get_edge_blend_factor(local_x, local_y, edge_mask)
			if blend > 0:
				# Zone 1 (0.0-0.25): Deep water -> Shallow water
				# Zone 2 (0.25-0.5): Shallow water -> Wet sand
				# Zone 3 (0.5-0.75): Wet sand -> Dry sand
				# Zone 4 (0.75-1.0): Dry sand -> Grass edge
				if blend < 0.25:
					var t = blend / 0.25
					base_color = base_color.lerp(shallow_water, _smooth_falloff(t))
				elif blend < 0.5:
					var t = (blend - 0.25) / 0.25
					base_color = shallow_water.lerp(wet_sand, _smooth_falloff(t))
					# Add some foam/splash variation
					if rng.randf() < 0.15:
						base_color = base_color.lightened(0.2)
				elif blend < 0.75:
					var t = (blend - 0.5) / 0.25
					var sand_noise = rng.randf_range(-0.05, 0.05)
					var sand = Color(wet_sand.r + sand_noise, wet_sand.g + sand_noise * 0.9, wet_sand.b + sand_noise * 0.8)
					base_color = sand.lerp(dry_sand, _smooth_falloff(t))
				else:
					var t = (blend - 0.75) / 0.25
					var sand_noise = rng.randf_range(-0.04, 0.04)
					var dry = Color(dry_sand.r + sand_noise, dry_sand.g + sand_noise, dry_sand.b + sand_noise * 0.8)
					base_color = dry.lerp(grass_edge, _smooth_falloff(t))

			image.set_pixel(x, y, base_color)

# ============ SINGLE TILE TERRAINS (no autotiling) ============

static func _draw_empty_tile(image: Image, col: int, row: int) -> void:
	var base = get_color("empty")
	var rect = _get_tile_rect(col, row)
	var rng = RandomNumberGenerator.new()
	rng.seed = 12345

	for x in range(rect.position.x, rect.position.x + rect.size.x):
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			var noise = rng.randf_range(-0.03, 0.03)
			image.set_pixel(x, y, Color(base.r + noise, base.g + noise, base.b + noise))

static func _draw_tee_box_tile(image: Image, col: int, row: int) -> void:
	var light = get_color("tee_box_light")
	var dark = get_color("tee_box_dark")
	var rect = _get_tile_rect(col, row)
	var rng = RandomNumberGenerator.new()
	rng.seed = 78901

	# Tee marker positions (local coords within 64x32 tile)
	var marker_color = Color(0.85, 0.15, 0.15)
	var marker_radius = 3.0
	var left_marker = Vector2(20, 16)
	var right_marker = Vector2(44, 16)

	for x in range(rect.position.x, rect.position.x + rect.size.x):
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			var local_x = x - rect.position.x
			var local_y = y - rect.position.y
			var check = (int(local_x / 8) + int(local_y / 4)) % 2
			var base = light if check == 0 else dark
			var noise = rng.randf_range(-0.02, 0.02)

			# Check if pixel is inside either tee marker circle
			var local_pos = Vector2(local_x, local_y)
			if local_pos.distance_to(left_marker) <= marker_radius or local_pos.distance_to(right_marker) <= marker_radius:
				image.set_pixel(x, y, marker_color)
			else:
				image.set_pixel(x, y, Color(base.r + noise, base.g + noise, base.b + noise))

static func _draw_path_tile(image: Image, col: int, row: int) -> void:
	var base = get_color("path")
	var rect = _get_tile_rect(col, row)
	var rng = RandomNumberGenerator.new()
	rng.seed = 1234

	for x in range(rect.position.x, rect.position.x + rect.size.x):
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			var noise = rng.randf_range(-0.1, 0.1)
			var pebble = 0.0
			if rng.randf() < 0.08:
				pebble = -0.15
			image.set_pixel(x, y, Color(base.r + noise + pebble, base.g + noise * 0.95 + pebble, base.b + noise * 0.9 + pebble))

static func _draw_oob_tile(image: Image, col: int, row: int) -> void:
	var base = get_color("oob")
	var rect = _get_tile_rect(col, row)
	var rng = RandomNumberGenerator.new()
	rng.seed = 2345

	for x in range(rect.position.x, rect.position.x + rect.size.x):
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			var noise = rng.randf_range(-0.05, 0.05)
			image.set_pixel(x, y, Color(base.r + noise, base.g + noise, base.b + noise))

static func _draw_trees_tile(image: Image, col: int, row: int) -> void:
	var base = get_color("trees")
	var rect = _get_tile_rect(col, row)
	var rng = RandomNumberGenerator.new()
	rng.seed = 3456

	for x in range(rect.position.x, rect.position.x + rect.size.x):
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			var noise = rng.randf_range(-0.06, 0.06)
			var dapple = sin(x * 0.4) * cos(y * 0.6) * 0.05
			image.set_pixel(x, y, Color(base.r + noise + dapple, base.g + noise * 1.2 + dapple, base.b + noise * 0.8))

static func _draw_flower_bed_tile(image: Image, col: int, row: int) -> void:
	var base = get_color("flower_bed")
	var rect = _get_tile_rect(col, row)
	var rng = RandomNumberGenerator.new()
	rng.seed = 4567

	for x in range(rect.position.x, rect.position.x + rect.size.x):
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			var noise = rng.randf_range(-0.08, 0.08)
			var mulch = 0.0
			if rng.randf() < 0.15:
				mulch = rng.randf_range(-0.1, 0.1)
			image.set_pixel(x, y, Color(base.r + noise + mulch, base.g + noise * 0.8 + mulch, base.b + noise * 0.6 + mulch))

static func _draw_rocks_tile(image: Image, col: int, row: int) -> void:
	var base = get_color("rocks")
	var rect = _get_tile_rect(col, row)
	var rng = RandomNumberGenerator.new()
	rng.seed = 5678

	for x in range(rect.position.x, rect.position.x + rect.size.x):
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			var noise = rng.randf_range(-0.1, 0.1)
			var rocky = sin(x * 0.3 + y * 0.2) * 0.06
			image.set_pixel(x, y, Color(base.r + noise + rocky, base.g + noise * 0.98 + rocky, base.b + noise * 0.95 + rocky))

# ============ UTILITY FUNCTIONS FOR TERRAIN GRID ============

# Get atlas coordinates for a terrain type with given edge mask
static func get_autotile_coords(terrain_type: int, edge_mask: int) -> Vector2i:
	var row = _get_row_for_terrain_type(terrain_type)
	if row == TerrainRow.SINGLES:
		# Single tiles don't use edge mask, return specific column
		var col = _get_single_tile_column(terrain_type)
		return Vector2i(col, row)
	else:
		# Autotiled terrain: column = edge mask
		return Vector2i(edge_mask, row)

static func _get_row_for_terrain_type(terrain_type: int) -> int:
	match terrain_type:
		1:  # GRASS
			return TerrainRow.GRASS
		2:  # FAIRWAY
			return TerrainRow.FAIRWAY
		5:  # GREEN
			return TerrainRow.GREEN
		3:  # ROUGH
			return TerrainRow.ROUGH
		4:  # HEAVY_ROUGH
			return TerrainRow.HEAVY_ROUGH
		7:  # BUNKER
			return TerrainRow.BUNKER
		8:  # WATER
			return TerrainRow.WATER
		_:  # Single tiles
			return TerrainRow.SINGLES

static func _get_single_tile_column(terrain_type: int) -> int:
	match terrain_type:
		0:  # EMPTY
			return 0
		6:  # TEE_BOX
			return 1
		9:  # PATH
			return 2
		10:  # OUT_OF_BOUNDS
			return 3
		11:  # TREES
			return 4
		12:  # FLOWER_BED
			return 5
		13:  # ROCKS
			return 6
		_:
			return 0

# Check if a terrain type uses autotiling
static func terrain_uses_autotile(terrain_type: int) -> bool:
	return terrain_type in [1, 2, 3, 4, 5, 7, 8]  # GRASS, FAIRWAY, ROUGH, HEAVY_ROUGH, GREEN, BUNKER, WATER
