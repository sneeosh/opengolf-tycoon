class_name ElevationProfiles
extends RefCounted
## ElevationProfiles - Per-terrain-type 4x4 sub-tile elevation profiles
##
## Each terrain type has a default 4x4 sub-tile elevation profile.
## Values are float offsets in elevation units (+-1.0 = +-1 full elevation level)
## added to the tile's base elevation.

## 4x4 sub-tile elevation profiles per terrain type.
## Each value is an offset in elevation units from the tile's base elevation.
## Positive = raised, negative = depressed relative to base.
const PROFILES: Dictionary = {
	# BUNKER: Deep bowl-shaped depression, steep lip at edges
	TerrainTypes.Type.BUNKER: [
		[ -0.25, -0.55, -0.55, -0.25 ],
		[ -0.55, -0.90, -0.90, -0.55 ],
		[ -0.55, -0.90, -0.90, -0.55 ],
		[ -0.25, -0.55, -0.55, -0.25 ],
	],

	# GREEN: Noticeable undulation with readable slopes
	TerrainTypes.Type.GREEN: [
		[  0.00,  0.10,  0.16,  0.10 ],
		[ -0.06,  0.04,  0.12,  0.20 ],
		[ -0.10, -0.04,  0.06,  0.16 ],
		[ -0.06,  0.00,  0.08,  0.10 ],
	],

	# FAIRWAY: Visible rolling terrain
	TerrainTypes.Type.FAIRWAY: [
		[  0.00,  0.06,  0.10,  0.08 ],
		[ -0.05,  0.00,  0.08,  0.12 ],
		[ -0.08, -0.03,  0.05,  0.10 ],
		[ -0.03,  0.03,  0.08,  0.05 ],
	],

	# TEE_BOX: Flat elevated platform (kept similar — constructed surface)
	TerrainTypes.Type.TEE_BOX: [
		[  0.22,  0.28,  0.28,  0.22 ],
		[  0.28,  0.35,  0.35,  0.28 ],
		[  0.28,  0.35,  0.35,  0.28 ],
		[  0.22,  0.28,  0.28,  0.22 ],
	],

	# ROUGH: Noticeably uneven ground
	TerrainTypes.Type.ROUGH: [
		[  0.05, -0.08,  0.10, -0.03 ],
		[ -0.10,  0.08, -0.05,  0.12 ],
		[  0.12, -0.03,  0.08, -0.10 ],
		[ -0.05,  0.10, -0.08,  0.05 ],
	],

	# HEAVY_ROUGH: Quite bumpy, unmaintained terrain
	TerrainTypes.Type.HEAVY_ROUGH: [
		[  0.12, -0.15,  0.18, -0.10 ],
		[ -0.18,  0.14, -0.12,  0.20 ],
		[  0.15, -0.10,  0.16, -0.18 ],
		[ -0.12,  0.18, -0.15,  0.10 ],
	],

	# WATER: Flat, lowest point
	TerrainTypes.Type.WATER: [
		[ -0.35, -0.35, -0.35, -0.35 ],
		[ -0.35, -0.35, -0.35, -0.35 ],
		[ -0.35, -0.35, -0.35, -0.35 ],
		[ -0.35, -0.35, -0.35, -0.35 ],
	],

	# GRASS: Slight natural undulation (not perfectly flat)
	TerrainTypes.Type.GRASS: [
		[  0.00,  0.02, -0.01,  0.01 ],
		[ -0.02,  0.00,  0.03, -0.01 ],
		[  0.01, -0.02,  0.00,  0.02 ],
		[ -0.01,  0.01, -0.02,  0.00 ],
	],

	# PATH: Flat (paved/maintained)
	TerrainTypes.Type.PATH: [
		[  0.00,  0.00,  0.00,  0.00 ],
		[  0.00,  0.00,  0.00,  0.00 ],
		[  0.00,  0.00,  0.00,  0.00 ],
		[  0.00,  0.00,  0.00,  0.00 ],
	],

	# ROCKS: Jagged, raised prominently
	TerrainTypes.Type.ROCKS: [
		[  0.15,  0.40,  0.22,  0.08 ],
		[  0.35,  0.65,  0.55,  0.28 ],
		[  0.22,  0.48,  0.60,  0.40 ],
		[  0.08,  0.22,  0.35,  0.15 ],
	],

	# TREES: Raised mound at base (root system)
	TerrainTypes.Type.TREES: [
		[  0.00,  0.08,  0.08,  0.00 ],
		[  0.08,  0.22,  0.22,  0.08 ],
		[  0.08,  0.22,  0.22,  0.08 ],
		[  0.00,  0.08,  0.08,  0.00 ],
	],
}

## Get the 4x4 profile for a terrain type. Returns flat (zeros) if no profile defined.
static func get_profile(terrain_type: int) -> Array:
	if PROFILES.has(terrain_type):
		return PROFILES[terrain_type]
	# Default: flat
	return [
		[ 0.0, 0.0, 0.0, 0.0 ],
		[ 0.0, 0.0, 0.0, 0.0 ],
		[ 0.0, 0.0, 0.0, 0.0 ],
		[ 0.0, 0.0, 0.0, 0.0 ],
	]

## Apply pseudo-random variation to a profile for a specific tile position.
## Uses the tile position as seed so it's deterministic (consistent across redraws).
static func get_varied_profile(terrain_type: int, tile_pos: Vector2i) -> Array:
	var base_profile: Array = get_profile(terrain_type)
	var seed_val: int = tile_pos.x * 7919 + tile_pos.y * 6271  # Deterministic hash

	var result: Array = []
	for y in 4:
		var row: Array = []
		for x in 4:
			var noise_seed: int = seed_val + y * 37 + x * 13
			# Pseudo-random in [-0.10, +0.10] range
			var noise: float = (fmod(abs(sin(float(noise_seed) * 43758.5453)), 1.0) - 0.5) * 0.20
			row.append(base_profile[y][x] + noise)
		result.append(row)
	return result
