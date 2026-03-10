extends RefCounted
class_name ForcedCarryCalculator
## ForcedCarryCalculator - Calculates forced carry distances over hazards along the tee-to-pin line.
## Used by HoleVisualizer for display and DifficultyCalculator for difficulty scoring.

class CarrySegment:
	var hazard_type: int  # TerrainTypes.Type (WATER or BUNKER)
	var start_grid: Vector2i  # Last safe tile before hazard
	var end_grid: Vector2i  # First safe tile after hazard
	var carry_yards: int
	var exceeds_beginner_range: bool  # > 150 yards

## Calculate all forced carry segments along the tee-to-pin corridor.
## Walks the center-line from tee to pin, tracking contiguous hazard runs.
static func calculate_carries(hole_data: GameManager.HoleData, terrain_grid: TerrainGrid) -> Array:
	var segments: Array = []
	if not hole_data or not terrain_grid:
		return segments

	var tee = hole_data.tee_position
	var pin = hole_data.hole_position
	var direction = Vector2(pin - tee)
	var length = direction.length()
	if length < 2.0:
		return segments

	var normalized = direction.normalized()
	var num_samples = int(length) + 1

	var in_hazard: bool = false
	var hazard_type: int = -1
	var last_safe_pos: Vector2i = tee

	for i in range(num_samples + 1):
		var t = float(i) / float(num_samples)
		var sample_pos = Vector2i(Vector2(tee) + normalized * length * t)
		if not terrain_grid.is_valid_position(sample_pos):
			continue

		var terrain = terrain_grid.get_tile(sample_pos)
		var is_hazard = terrain in [TerrainTypes.Type.WATER, TerrainTypes.Type.BUNKER]

		if is_hazard and not in_hazard:
			in_hazard = true
			hazard_type = terrain
		elif not is_hazard and in_hazard:
			# Exiting hazard — record carry segment
			var seg = CarrySegment.new()
			seg.hazard_type = hazard_type
			seg.start_grid = last_safe_pos
			seg.end_grid = sample_pos
			seg.carry_yards = terrain_grid.calculate_distance_yards(last_safe_pos, sample_pos)
			seg.exceeds_beginner_range = seg.carry_yards > 150
			segments.append(seg)
			in_hazard = false

		if not is_hazard:
			# Only update last_safe_pos from fairway-quality terrain — carry measures
			# from where a golfer would reasonably land, not from rough/trees
			if terrain in [TerrainTypes.Type.FAIRWAY, TerrainTypes.Type.TEE_BOX,
						   TerrainTypes.Type.GREEN, TerrainTypes.Type.PATH]:
				last_safe_pos = sample_pos

	return segments
