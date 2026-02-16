extends RefCounted
class_name ShotPathCalculator
## ShotPathCalculator - Calculates expected shot path for hole visualization
##
## Uses the same targeting logic as the Golfer AI to show where an average
## golfer would aim their drive and approach shots. This helps course designers
## understand how golfers will play each hole.
##
## Average CASUAL golfer skills (midpoint of CASUAL tier [0.5, 0.7]):

const AVG_ACCURACY: float = 0.6
const AVG_AGGRESSION: float = 0.45

## Calculate shot path waypoints from tee to flag.
## Returns array of grid positions: [tee, landing1, ..., flag]
## Par 3: [tee, flag] (direct shot)
## Par 4: [tee, drive_landing, flag]
## Par 5: [tee, drive_landing, second_landing, flag]
static func calculate_waypoints(hole_data: GameManager.HoleData, terrain_grid: TerrainGrid) -> Array[Vector2i]:
	var waypoints: Array[Vector2i] = [hole_data.tee_position]

	# Number of intermediate landing zones = par - 2
	# Par 3: 0 intermediate, Par 4: 1 intermediate, Par 5: 2 intermediate
	var num_intermediate: int = hole_data.par - 2
	if num_intermediate <= 0:
		waypoints.append(hole_data.hole_position)
		return waypoints

	var current_pos: Vector2i = hole_data.tee_position

	for i in range(num_intermediate):
		var landing: Vector2i = _decide_shot_target(current_pos, hole_data.hole_position, terrain_grid)

		# Safety: don't add same position or positions that don't advance
		if landing == current_pos:
			break

		# If landing reached the green area, stop adding intermediates
		var landing_terrain: int = terrain_grid.get_tile(landing)
		if landing_terrain == TerrainTypes.Type.GREEN:
			break

		waypoints.append(landing)
		current_pos = landing

	waypoints.append(hole_data.hole_position)
	return waypoints

## Decide shot target from a position - mirrors Golfer.decide_shot_target()
## Evaluates multiple club candidates and picks the one with the best landing zone.
static func _decide_shot_target(from_pos: Vector2i, hole_position: Vector2i, terrain_grid: TerrainGrid) -> Vector2i:
	var current_terrain: int = terrain_grid.get_tile(from_pos)
	var distance_to_hole: float = Vector2(from_pos).distance_to(Vector2(hole_position))

	# If close enough to putt, just aim at the hole
	if current_terrain == TerrainTypes.Type.GREEN:
		return hole_position
	if distance_to_hole <= Golfer.CLUB_STATS[Golfer.Club.PUTTER]["max_distance"]:
		var is_puttable: bool = current_terrain in [
			TerrainTypes.Type.FAIRWAY, TerrainTypes.Type.GRASS, TerrainTypes.Type.TEE_BOX,
		]
		if is_puttable:
			return hole_position

	# Evaluate candidate clubs to find the best overall option (enables lay-up)
	var candidate_clubs: Array = []
	for club_type in [Golfer.Club.DRIVER, Golfer.Club.FAIRWAY_WOOD, Golfer.Club.IRON, Golfer.Club.WEDGE]:
		var stats: Dictionary = Golfer.CLUB_STATS[club_type]
		# Club is a candidate if the hole is within or beyond its min range
		if distance_to_hole >= stats["min_distance"] * 0.7:
			candidate_clubs.append(club_type)

	if candidate_clubs.is_empty():
		candidate_clubs.append(Golfer.Club.WEDGE)

	var best_target: Vector2i = hole_position
	var best_score: float = -9999.0

	for club in candidate_clubs:
		var stats: Dictionary = Golfer.CLUB_STATS[club]
		var max_dist: float = stats["max_distance"] * 0.97  # Near-full distance
		var target: Vector2i = _find_best_landing_zone(from_pos, hole_position, max_dist, club, terrain_grid)
		var score: float = _evaluate_landing_zone(from_pos, target, hole_position, club, terrain_grid)

		if score > best_score:
			best_score = score
			best_target = target

	return best_target

## Find best landing zone - mirrors Golfer._find_best_landing_zone()
## Samples points along the target line and slight offsets to find optimal landing.
static func _find_best_landing_zone(from_pos: Vector2i, hole_position: Vector2i, max_distance: float, club: int, terrain_grid: TerrainGrid) -> Vector2i:
	var direction_to_hole: Vector2 = Vector2(hole_position - from_pos).normalized()
	var distance_to_hole: float = Vector2(from_pos).distance_to(Vector2(hole_position))

	var target_distance: float = min(distance_to_hole, max_distance)

	# Average aggression golfer (0.45) won't trigger aggressive override (>0.7)

	var best_target: Vector2i = hole_position
	var best_score: float = -999.0

	# Sample points along the line to the hole (70% to 130% of target distance)
	var num_samples: int = 5
	for i in range(num_samples):
		var test_distance: float = target_distance * (0.7 + (i / float(num_samples)) * 0.6)
		var test_position: Vector2i = from_pos + Vector2i(direction_to_hole * test_distance)

		if not terrain_grid.is_valid_position(test_position):
			continue

		var score: float = _evaluate_landing_zone(from_pos, test_position, hole_position, club, terrain_grid)
		if score > best_score:
			best_score = score
			best_target = test_position

	# Also consider slight left/right adjustments to avoid hazards (-3°, 0°, +3°)
	for offset_angle in [-0.05, 0.0, 0.05]:
		var adjusted_direction: Vector2 = direction_to_hole.rotated(offset_angle)
		var test_position: Vector2i = from_pos + Vector2i(adjusted_direction * target_distance)

		if not terrain_grid.is_valid_position(test_position):
			continue

		var score: float = _evaluate_landing_zone(from_pos, test_position, hole_position, club, terrain_grid)
		if score > best_score:
			best_score = score
			best_target = test_position

	return best_target

## Evaluate landing zone quality - mirrors Golfer._evaluate_landing_zone()
static func _evaluate_landing_zone(from_pos: Vector2i, position: Vector2i, hole_position: Vector2i, _club: int, terrain_grid: TerrainGrid) -> float:
	# Check if ball flight path crosses trees at low altitude
	if _path_crosses_obstacle(from_pos, position, terrain_grid):
		return -2000.0

	var terrain_type: int = terrain_grid.get_tile(position)
	var score: float = 0.0

	# Score based on terrain type
	match terrain_type:
		TerrainTypes.Type.FAIRWAY:
			score += 100.0
		TerrainTypes.Type.GREEN:
			score += 120.0
		TerrainTypes.Type.GRASS:
			score += 80.0
		TerrainTypes.Type.ROUGH:
			score += 30.0
		TerrainTypes.Type.HEAVY_ROUGH:
			score += 10.0
		TerrainTypes.Type.BUNKER:
			score -= 20.0
		TerrainTypes.Type.WATER:
			score -= 1000.0
		TerrainTypes.Type.OUT_OF_BOUNDS:
			score -= 1000.0
		TerrainTypes.Type.TREES:
			score -= 50.0

	# Bonus for getting closer to hole
	var distance_to_hole: float = Vector2(position).distance_to(Vector2(hole_position))
	var current_distance: float = Vector2(from_pos).distance_to(Vector2(hole_position))

	# Strong penalty if shot doesn't advance towards the hole
	if distance_to_hole >= current_distance:
		score -= 500.0

	score -= distance_to_hole * 4.0

	# Personality adjustments for average golfer (aggression 0.45)
	# Not cautious enough (<0.3) to trigger extra bunker/rough penalties

	# Check surrounding tiles for hazards (risky if near water/OB)
	var hazard_penalty: float = 0.0
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			if dx == 0 and dy == 0:
				continue
			var check_pos: Vector2i = position + Vector2i(dx, dy)
			if not terrain_grid.is_valid_position(check_pos):
				continue

			var nearby_terrain: int = terrain_grid.get_tile(check_pos)
			if nearby_terrain == TerrainTypes.Type.WATER or nearby_terrain == TerrainTypes.Type.OUT_OF_BOUNDS:
				hazard_penalty += 20.0 * (1.0 - AVG_AGGRESSION)

	score -= hazard_penalty
	return score

## Check if ball flight path crosses trees at low altitude
## Mirrors Golfer._path_crosses_obstacle() for ball flight (not walking)
static func _path_crosses_obstacle(start: Vector2i, end: Vector2i, terrain_grid: TerrainGrid) -> bool:
	var distance: float = Vector2(start).distance_to(Vector2(end))
	var num_samples: int = int(distance) + 1

	for i in range(num_samples):
		var t: float = i / float(num_samples)
		var sample_pos: Vector2i = Vector2i(Vector2(start).lerp(Vector2(end), t))

		if not terrain_grid.is_valid_position(sample_pos):
			continue

		var terrain_type: int = terrain_grid.get_tile(sample_pos)
		if terrain_type == TerrainTypes.Type.TREES:
			# Ball trajectory: parabolic arc, low near takeoff/landing
			var height_factor: float = 4.0 * t * (1.0 - t)
			var tree_clear_threshold: float = 0.3
			if height_factor < tree_clear_threshold:
				return true

	return false
