extends RefCounted
class_name DifficultyCalculator
## DifficultyCalculator - Calculates hole difficulty based on hazards and terrain

## Calculate difficulty rating for a hole (1.0 - 10.0 scale)
static func calculate_hole_difficulty(hole_data: GameManager.HoleData, terrain_grid: TerrainGrid) -> float:
	if not hole_data or not terrain_grid:
		return 1.0

	# Base difficulty from par (longer holes are harder)
	var base_difficulty: float = hole_data.par - 2.0  # Par 3 = 1.0, Par 4 = 2.0, Par 5 = 3.0

	# Sample tiles in a corridor between tee and green
	var corridor_tiles = _get_corridor_tiles(
		hole_data.tee_position,
		hole_data.green_position,
		terrain_grid,
		10  # corridor width in tiles
	)

	# Count hazard types in the corridor
	var water_count: int = 0
	var bunker_count: int = 0
	var ob_count: int = 0
	var tree_count: int = 0

	for tile_pos in corridor_tiles:
		var terrain_type = terrain_grid.get_tile(tile_pos)
		match terrain_type:
			TerrainTypes.Type.WATER:
				water_count += 1
			TerrainTypes.Type.BUNKER:
				bunker_count += 1
			TerrainTypes.Type.OUT_OF_BOUNDS:
				ob_count += 1
			TerrainTypes.Type.TREES:
				tree_count += 1

	# Weight hazards into difficulty
	var hazard_difficulty: float = 0.0
	hazard_difficulty += water_count * 0.3
	hazard_difficulty += bunker_count * 0.15
	hazard_difficulty += ob_count * 0.2
	hazard_difficulty += tree_count * 0.1

	var total_difficulty = base_difficulty + hazard_difficulty
	return clampf(total_difficulty, 1.0, 10.0)

## Get tiles in a corridor between two points
static func _get_corridor_tiles(from: Vector2i, to: Vector2i, terrain_grid: TerrainGrid, width: int) -> Array:
	var tiles: Array = []
	var direction = Vector2(to - from)
	var length = direction.length()
	if length < 1.0:
		return tiles

	var normalized = direction.normalized()
	# Perpendicular vector for corridor width
	var perp = Vector2(-normalized.y, normalized.x)
	var half_width = width / 2.0

	# Sample along the corridor
	var steps = int(length) + 1
	for i in range(steps):
		var t = float(i) / float(max(steps - 1, 1))
		var center = Vector2(from) + direction * t

		# Sample across the width
		for w in range(-int(half_width), int(half_width) + 1):
			var sample_pos = Vector2i(center + perp * float(w))
			if terrain_grid.is_valid_position(sample_pos) and sample_pos not in tiles:
				tiles.append(sample_pos)

	return tiles
