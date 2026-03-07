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
	# BUNKER: Bowl-shaped depression, steep lip at edges
	TerrainTypes.Type.BUNKER: [
		[ -0.15, -0.40, -0.40, -0.15 ],
		[ -0.40, -0.75, -0.75, -0.40 ],
		[ -0.40, -0.75, -0.75, -0.40 ],
		[ -0.15, -0.40, -0.40, -0.15 ],
	],

	# GREEN: Gentle undulation with subtle slopes
	TerrainTypes.Type.GREEN: [
		[  0.00,  0.05,  0.08,  0.05 ],
		[ -0.03,  0.02,  0.06,  0.10 ],
		[ -0.05, -0.02,  0.03,  0.08 ],
		[ -0.03,  0.00,  0.04,  0.05 ],
	],

	# FAIRWAY: Mild rolling terrain
	TerrainTypes.Type.FAIRWAY: [
		[  0.00,  0.02,  0.04,  0.03 ],
		[ -0.02,  0.00,  0.03,  0.05 ],
		[ -0.03, -0.01,  0.02,  0.04 ],
		[ -0.01,  0.01,  0.03,  0.02 ],
	],

	# TEE_BOX: Flat elevated platform
	TerrainTypes.Type.TEE_BOX: [
		[  0.20,  0.25,  0.25,  0.20 ],
		[  0.25,  0.30,  0.30,  0.25 ],
		[  0.25,  0.30,  0.30,  0.25 ],
		[  0.20,  0.25,  0.25,  0.20 ],
	],

	# ROUGH: Slightly uneven
	TerrainTypes.Type.ROUGH: [
		[  0.02, -0.03,  0.04, -0.01 ],
		[ -0.04,  0.03, -0.02,  0.05 ],
		[  0.05, -0.01,  0.03, -0.04 ],
		[ -0.02,  0.04, -0.03,  0.02 ],
	],

	# HEAVY_ROUGH: More pronounced unevenness
	TerrainTypes.Type.HEAVY_ROUGH: [
		[  0.05, -0.08,  0.10, -0.05 ],
		[ -0.10,  0.07, -0.06,  0.12 ],
		[  0.08, -0.05,  0.09, -0.10 ],
		[ -0.06,  0.10, -0.08,  0.05 ],
	],

	# WATER: Flat, lowest point
	TerrainTypes.Type.WATER: [
		[ -0.30, -0.30, -0.30, -0.30 ],
		[ -0.30, -0.30, -0.30, -0.30 ],
		[ -0.30, -0.30, -0.30, -0.30 ],
		[ -0.30, -0.30, -0.30, -0.30 ],
	],

	# GRASS: Essentially flat (no profile offset)
	TerrainTypes.Type.GRASS: [
		[  0.00,  0.00,  0.00,  0.00 ],
		[  0.00,  0.00,  0.00,  0.00 ],
		[  0.00,  0.00,  0.00,  0.00 ],
		[  0.00,  0.00,  0.00,  0.00 ],
	],

	# PATH: Flat
	TerrainTypes.Type.PATH: [
		[  0.00,  0.00,  0.00,  0.00 ],
		[  0.00,  0.00,  0.00,  0.00 ],
		[  0.00,  0.00,  0.00,  0.00 ],
		[  0.00,  0.00,  0.00,  0.00 ],
	],

	# ROCKS: Jagged, raised
	TerrainTypes.Type.ROCKS: [
		[  0.10,  0.30,  0.15,  0.05 ],
		[  0.25,  0.50,  0.40,  0.20 ],
		[  0.15,  0.35,  0.45,  0.30 ],
		[  0.05,  0.15,  0.25,  0.10 ],
	],

	# TREES: Raised mound at base
	TerrainTypes.Type.TREES: [
		[  0.00,  0.05,  0.05,  0.00 ],
		[  0.05,  0.15,  0.15,  0.05 ],
		[  0.05,  0.15,  0.15,  0.05 ],
		[  0.00,  0.05,  0.05,  0.00 ],
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
	var base_profile := get_profile(terrain_type)
	var seed_val := tile_pos.x * 7919 + tile_pos.y * 6271  # Deterministic hash

	var result: Array = []
	for y in 4:
		var row: Array = []
		for x in 4:
			var noise_seed := seed_val + y * 37 + x * 13
			# Pseudo-random in [-0.05, +0.05] range
			var noise := (fmod(abs(sin(float(noise_seed) * 43758.5453)), 1.0) - 0.5) * 0.10
			row.append(base_profile[y][x] + noise)
		result.append(row)
	return result
