extends RefCounted
class_name ShotAI
## ShotAI - Golf shot decision-making engine
##
## Replaces the monolithic targeting code in golfer.gd with a structured
## decision pipeline:
##   1. Assess lie → if in trouble, enter recovery mode
##   2. Plan shot sequence to hole (backwards from green)
##   3. For current shot: evaluate clubs with wind-adjusted aim points
##   4. Score candidates on terrain, miss-distribution hazard overlap, next-shot setup
##   5. Apply personality (aggression shifts risk tolerance)
##
## The execution model (_calculate_shot, _calculate_putt, _calculate_rollout)
## remains in golfer.gd — this class only decides WHERE and WITH WHAT to hit.

# ============================================================================
# TYPES
# ============================================================================

## Result of a shot decision — everything the golfer needs to execute
class ShotDecision:
	var target: Vector2i          ## Where to aim (wind-compensated)
	var club: int                 ## Golfer.Club enum
	var strategy: String          ## "normal", "recovery", "layup", "attack"
	var confidence: float         ## 0-1, how good this option is

## Lightweight data snapshot of a golfer's stats — used by all ShotAI methods.
## Avoids requiring a full Golfer node (which extends CharacterBody2D).
## Create via from_golfer() for real golfers, or construct directly for visualization.
class GolferData:
	var ball_position: Vector2i = Vector2i.ZERO
	var ball_position_precise: Vector2 = Vector2.ZERO
	var driving_skill: float = 0.5
	var accuracy_skill: float = 0.5
	var putting_skill: float = 0.5
	var recovery_skill: float = 0.5
	var miss_tendency: float = 0.0
	var aggression: float = 0.5
	var patience: float = 0.5
	var current_hole: int = 0
	var total_strokes: int = 0
	var total_par: int = 0

	static func from_golfer(golfer: Golfer) -> GolferData:
		var data: GolferData = GolferData.new()
		data.ball_position = golfer.ball_position
		data.ball_position_precise = golfer.ball_position_precise
		data.driving_skill = golfer.driving_skill
		data.accuracy_skill = golfer.accuracy_skill
		data.putting_skill = golfer.putting_skill
		data.recovery_skill = golfer.recovery_skill
		data.miss_tendency = golfer.miss_tendency
		data.aggression = golfer.aggression
		data.patience = golfer.patience
		data.current_hole = golfer.current_hole
		data.total_strokes = golfer.total_strokes
		data.total_par = golfer.total_par
		return data

## Internal candidate during evaluation
class _ShotCandidate:
	var aim_point: Vector2i       ## Where to aim (pre-wind-compensation)
	var landing_zone: Vector2i    ## Where ball is expected to land (post-wind)
	var club: int
	var score: float
	var strategy: String

# ============================================================================
# CONFIGURATION
# ============================================================================

## Scan resolution for landing zone search
const APPROACH_ANGLE_SAMPLES: int = 15    ## Narrow scan (±15°) for approach shots
const LAYUP_ANGLE_SAMPLES: int = 25       ## Wide scan (±50°) for layup/recovery
const DISTANCE_SAMPLES: int = 7           ## Distance steps per angle
const APPROACH_HALF_ANGLE: float = 0.26   ## ±15° in radians
const LAYUP_HALF_ANGLE: float = 0.87      ## ±50° in radians

## Miss distribution sampling for risk analysis
const MISS_SAMPLE_COUNT: int = 8          ## Monte Carlo samples for hazard risk

## Terrain scores (large gaps to dominate over distance bonuses at similar ranges)
const TERRAIN_SCORES: Dictionary = {
	TerrainTypes.Type.GREEN: 180.0,
	TerrainTypes.Type.FAIRWAY: 150.0,
	TerrainTypes.Type.TEE_BOX: 130.0,
	TerrainTypes.Type.GRASS: 40.0,
	TerrainTypes.Type.PATH: 35.0,
	TerrainTypes.Type.ROUGH: 10.0,
	TerrainTypes.Type.HEAVY_ROUGH: -20.0,
	TerrainTypes.Type.BUNKER: -50.0,
	TerrainTypes.Type.TREES: -80.0,
	TerrainTypes.Type.ROCKS: -100.0,
	TerrainTypes.Type.WATER: -1000.0,
	TerrainTypes.Type.OUT_OF_BOUNDS: -1000.0,
	TerrainTypes.Type.FLOWER_BED: -40.0,
	TerrainTypes.Type.EMPTY: -200.0,
}

# ============================================================================
# PUBLIC API
# ============================================================================

## Main entry point (convenience): decide what shot to hit for a real Golfer node.
static func decide_shot(golfer: Golfer, hole_position: Vector2i) -> ShotDecision:
	return decide_shot_for(GolferData.from_golfer(golfer), hole_position)

## Main entry point: decide what shot to hit from GolferData.
## Works with both real golfers (via from_golfer) and phantom visualization golfers.
static func decide_shot_for(gd: GolferData, hole_position: Vector2i) -> ShotDecision:
	var terrain_grid: TerrainGrid = GameManager.terrain_grid
	if not terrain_grid:
		return _make_decision(hole_position, Golfer.Club.IRON, "normal", 0.0)

	var current_terrain: int = terrain_grid.get_tile(gd.ball_position)

	# --- Putting: delegate to green-reading system ---
	if current_terrain == TerrainTypes.Type.GREEN:
		return _decide_putt(gd, hole_position, terrain_grid)

	# --- Assess lie quality ---
	var lie_quality: float = _assess_lie_quality(current_terrain)

	# --- Recovery mode for trouble lies ---
	if lie_quality < 0.4:
		return _decide_recovery_shot(gd, hole_position, terrain_grid, current_terrain)

	# --- Plan shot sequence (multi-shot lookahead) ---
	var distance_to_hole: float = Vector2(gd.ball_position).distance_to(Vector2(hole_position))
	var shots_remaining: int = _estimate_shots_to_hole(gd, distance_to_hole)
	var target_distance: float = _get_ideal_shot_distance(gd, distance_to_hole, shots_remaining)

	# --- Evaluate all candidate clubs ---
	var candidates: Array = _evaluate_all_candidates(
		gd, hole_position, terrain_grid, target_distance, shots_remaining
	)

	if candidates.is_empty():
		return _make_decision(hole_position, Golfer.Club.WEDGE, "normal", 0.0)

	# --- Pick the best candidate ---
	candidates.sort_custom(func(a, b): return a.score > b.score)
	var best: _ShotCandidate = candidates[0]

	return _make_decision(best.aim_point, best.club, best.strategy, best.score)

# ============================================================================
# PUTTING — Green-reading system
# ============================================================================

## Decide where to aim a putt, accounting for green slope.
## On sloped greens, aim uphill of the hole so gravity brings the ball back.
static func _decide_putt(gd: GolferData, hole_position: Vector2i, terrain_grid: TerrainGrid) -> ShotDecision:
	var slope: Vector2 = terrain_grid.get_slope_direction(hole_position)

	# No slope or very weak slope: aim straight at the hole
	if slope.length() < 0.1:
		return _make_decision(hole_position, Golfer.Club.PUTTER, "normal", 1.0)

	# Green reading ability scales with putting skill
	# Pros read 70-90% of the break; beginners read 20-40%
	var read_ability: float = 0.2 + gd.putting_skill * 0.7

	# The ball will break in the direction of slope, so aim OPPOSITE to slope.
	# Amount of compensation depends on distance (longer putts break more)
	# and the golfer's ability to read greens.
	var putt_distance: float = gd.ball_position_precise.distance_to(Vector2(hole_position))

	# Break amount: slope strength × distance × read ability
	# Capped to prevent aiming wildly off-target
	var break_compensation: float = slope.length() * putt_distance * read_ability * 0.5
	break_compensation = minf(break_compensation, putt_distance * 0.3)  # Max 30% of distance as break

	# Aim point: offset from hole in opposite direction of slope
	var aim_offset: Vector2 = -slope.normalized() * break_compensation
	var aim_point: Vector2i = Vector2i((Vector2(hole_position) + aim_offset).round())

	# Ensure aim point is on the green (or close to it)
	if terrain_grid.is_valid_position(aim_point):
		var aim_terrain: int = terrain_grid.get_tile(aim_point)
		if aim_terrain != TerrainTypes.Type.GREEN:
			# Aim point went off the green — pull it back toward hole
			aim_point = hole_position

	return _make_decision(aim_point, Golfer.Club.PUTTER, "normal", 1.0)

# ============================================================================
# RECOVERY SHOTS — Trouble lie decision-making
# ============================================================================

## When in trees, deep rough, bunkers, or rocks: plan an escape.
## Beginners punch out sideways; skilled players may advance toward the hole.
static func _decide_recovery_shot(
	gd: GolferData, hole_position: Vector2i,
	terrain_grid: TerrainGrid, current_terrain: int
) -> ShotDecision:

	var ball_pos: Vector2i = gd.ball_position
	var distance_to_hole: float = Vector2(ball_pos).distance_to(Vector2(hole_position))

	# --- Forced club selection for trouble lies ---
	# Trees: max iron (no woods/driver through trees)
	# Bunker: prefer wedge (club-specific lie modifier already handles this)
	# Rocks: wedge only
	var allowed_clubs: Array = _get_recovery_clubs(current_terrain)

	# --- Scan a full 360° for escape routes ---
	# Recovery scans wider angles than normal shots because "sideways" and
	# even "backwards" are legitimate escape routes from deep trouble.
	var direction_to_hole: Vector2 = Vector2(hole_position - ball_pos).normalized()
	var best_candidate: _ShotCandidate = null
	var best_score: float = -99999.0

	for club in allowed_clubs:
		var stats: Dictionary = Golfer.CLUB_STATS[club]
		var skill_factor: float = _get_skill_distance_factor(gd, club)
		var max_dist: float = stats["max_distance"] * skill_factor
		# In trouble, don't try to hit max distance
		max_dist *= 0.7

		# Scan 360° in 24 directions
		for angle_idx in range(24):
			var angle: float = (angle_idx / 24.0) * TAU
			var scan_dir: Vector2 = Vector2.RIGHT.rotated(angle)

			# Sample 4 distances along this direction
			for d_idx in range(4):
				var test_dist: float = max_dist * (0.3 + (d_idx / 3.0) * 0.7)
				var test_pos: Vector2i = ball_pos + Vector2i((scan_dir * test_dist).round())

				if test_pos == ball_pos:
					continue
				if not terrain_grid.is_valid_position(test_pos):
					continue

				# Skip tree-path check: recovery shots are low punch-outs
				# designed to escape trees. Club restrictions + terrain scoring
				# already model the difficulty.
				var terrain_type: int = terrain_grid.get_tile(test_pos)
				var score: float = TERRAIN_SCORES.get(terrain_type, -50.0)

				# Bonus for advancing toward the hole (but not required)
				var new_dist_to_hole: float = Vector2(test_pos).distance_to(Vector2(hole_position))
				var advancement: float = distance_to_hole - new_dist_to_hole

				if advancement > 0:
					score += advancement * 3.0  # Reward advancing
				else:
					score -= 50.0  # Mild penalty for going backwards (but allowed)

				# Bonus for ending up on fairway (sets up next shot well)
				if terrain_type == TerrainTypes.Type.FAIRWAY:
					score += 80.0

				# Penalty for nearby hazards at landing zone
				score -= _nearby_hazard_penalty(test_pos, terrain_grid, gd.aggression)

				# Recovery skill bonus — skilled recovery players find better escape routes
				score += gd.recovery_skill * 30.0

				if score > best_score:
					best_score = score
					best_candidate = _ShotCandidate.new()
					best_candidate.aim_point = test_pos
					best_candidate.landing_zone = test_pos
					best_candidate.club = club
					best_candidate.score = score
					best_candidate.strategy = "recovery"

	if best_candidate:
		return _make_decision(best_candidate.aim_point, best_candidate.club, "recovery", best_score)

	# Absolute fallback: find nearest non-hazard tile, preferring toward the hole
	var fallback_target: Vector2i = ball_pos + Vector2i((direction_to_hole * 2.0).round())
	var best_fallback_score: float = -99999.0
	for radius in range(1, 6):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if absi(dx) != radius and absi(dy) != radius:
					continue  # Only check perimeter
				var check_pos: Vector2i = ball_pos + Vector2i(dx, dy)
				if not terrain_grid.is_valid_position(check_pos):
					continue
				var t: int = terrain_grid.get_tile(check_pos)
				var s: float = TERRAIN_SCORES.get(t, -50.0)
				# Prefer tiles toward the hole
				var adv: float = distance_to_hole - Vector2(check_pos).distance_to(Vector2(hole_position))
				s += adv * 2.0
				if s > best_fallback_score:
					best_fallback_score = s
					fallback_target = check_pos
		if best_fallback_score > 0:
			break  # Found a decent tile, stop expanding
	return _make_decision(fallback_target, Golfer.Club.WEDGE, "recovery", -100.0)

## Get clubs allowed from a trouble lie
static func _get_recovery_clubs(terrain_type: int) -> Array:
	match terrain_type:
		TerrainTypes.Type.TREES:
			return [Golfer.Club.WEDGE, Golfer.Club.IRON]  # No woods through trees
		TerrainTypes.Type.ROCKS:
			return [Golfer.Club.WEDGE]  # Wedge only from rocks
		TerrainTypes.Type.BUNKER:
			return [Golfer.Club.WEDGE, Golfer.Club.IRON]  # Sand wedge preferred
		TerrainTypes.Type.HEAVY_ROUGH:
			return [Golfer.Club.WEDGE, Golfer.Club.IRON]  # Can't get wood through thick stuff
		_:
			return [Golfer.Club.WEDGE, Golfer.Club.IRON, Golfer.Club.FAIRWAY_WOOD]

# ============================================================================
# MULTI-SHOT PLANNING
# ============================================================================

## Estimate how many shots it will take to reach the hole from current distance.
## Works backwards: par = regulation shots + 2 putts, so shots_to_green = par - 2.
## But also considers the golfer's actual max distance with each club.
static func _estimate_shots_to_hole(gd: GolferData, distance_to_hole: float) -> int:
	var max_driver_dist: float = Golfer.CLUB_STATS[Golfer.Club.DRIVER]["max_distance"] * _get_skill_distance_factor(gd, Golfer.Club.DRIVER)

	if distance_to_hole <= 1.0:
		return 1  # Chip/putt range
	elif distance_to_hole <= Golfer.CLUB_STATS[Golfer.Club.WEDGE]["max_distance"]:
		return 1  # Wedge range
	elif distance_to_hole <= max_driver_dist:
		return 1  # Can reach in one
	elif distance_to_hole <= max_driver_dist * 2.0:
		return 2  # Two shots
	else:
		return 3  # Three shots (par 5 territory)

## Get the ideal distance for THIS shot, given how many shots remain.
## Implements backward planning: divide remaining distance into efficient segments.
static func _get_ideal_shot_distance(
	gd: GolferData, distance_to_hole: float, shots_remaining: int
) -> float:
	if shots_remaining <= 1:
		return distance_to_hole  # Go for the green

	# Multi-shot strategy: plan from the green backwards
	# Last shot should be a comfortable approach distance (wedge range = 3-4 tiles)
	var ideal_approach: float = 3.5  # ~77 yards, comfortable wedge

	if shots_remaining == 2:
		# Two shots: hit first shot so second is a comfortable approach
		var first_shot_ideal: float = distance_to_hole - ideal_approach
		var max_driver: float = Golfer.CLUB_STATS[Golfer.Club.DRIVER]["max_distance"] * _get_skill_distance_factor(gd, Golfer.Club.DRIVER)
		return minf(first_shot_ideal, max_driver)

	if shots_remaining == 3:
		# Three shots: split into two long shots + approach
		var long_shot_total: float = distance_to_hole - ideal_approach
		var per_shot: float = long_shot_total / 2.0
		var max_driver: float = Golfer.CLUB_STATS[Golfer.Club.DRIVER]["max_distance"] * _get_skill_distance_factor(gd, Golfer.Club.DRIVER)
		return minf(per_shot, max_driver)

	# Fallback: even split
	return distance_to_hole / float(shots_remaining)

# ============================================================================
# CANDIDATE EVALUATION — Core decision engine
# ============================================================================

## Evaluate all candidate clubs and landing zones, return scored candidates.
static func _evaluate_all_candidates(
	gd: GolferData, hole_position: Vector2i,
	terrain_grid: TerrainGrid, target_distance: float, shots_remaining: int
) -> Array:
	var ball_pos: Vector2i = gd.ball_position
	var distance_to_hole: float = Vector2(ball_pos).distance_to(Vector2(hole_position))
	var direction_to_hole: Vector2 = Vector2(hole_position - ball_pos).normalized()
	var candidates: Array = []

	# --- Build candidate club list ---
	var club_list: Array = _get_candidate_clubs(gd, distance_to_hole, target_distance)

	var can_reach_green: bool = false
	for club in club_list:
		var max_dist: float = Golfer.CLUB_STATS[club]["max_distance"] * _get_skill_distance_factor(gd, club)
		if max_dist >= distance_to_hole * 0.9:
			can_reach_green = true
			break

	# --- Scan parameters based on shot type ---
	var scan_half_angle: float = APPROACH_HALF_ANGLE if can_reach_green else LAYUP_HALF_ANGLE
	var num_angles: int = APPROACH_ANGLE_SAMPLES if can_reach_green else LAYUP_ANGLE_SAMPLES

	for club in club_list:
		var stats: Dictionary = Golfer.CLUB_STATS[club]
		var skill_factor: float = _get_skill_distance_factor(gd, club)
		var max_dist: float = stats["max_distance"] * skill_factor
		var min_dist: float = stats["min_distance"] * 0.8  # Slight flexibility on min

		# For layup shots, cap distance to target
		var effective_max: float = max_dist
		if shots_remaining > 1:
			effective_max = minf(max_dist, target_distance * 1.15)

		# Scan angles and distances
		for a in range(num_angles):
			var t_angle: float = a / float(max(num_angles - 1, 1))
			var offset_angle: float = -scan_half_angle + t_angle * scan_half_angle * 2.0
			var scan_dir: Vector2 = direction_to_hole.rotated(offset_angle)

			for d in range(DISTANCE_SAMPLES):
				var t_dist: float = d / float(max(DISTANCE_SAMPLES - 1, 1))
				var test_dist: float
				# Wedge approach shots scan from chip distance to max,
				# so golfers near the green can target the actual distance
				# instead of overshooting to 60+ yards.
				var is_wedge_approach: bool = (club == Golfer.Club.WEDGE and shots_remaining <= 1)
				if is_wedge_approach:
					var chip_floor: float = 0.25  # ~5.5 yards — covers any tile off the green
					test_dist = chip_floor + t_dist * (effective_max * 1.1 - chip_floor)
				else:
					# Standard scan: 60% to 110% of effective max
					test_dist = effective_max * (0.6 + t_dist * 0.5)

				# Skip distances below club minimum (waived for wedge chips)
				if not is_wedge_approach and test_dist < min_dist * 0.7:
					continue

				var test_pos: Vector2i = ball_pos + Vector2i((scan_dir * test_dist).round())
				if test_pos == ball_pos:
					continue
				if not terrain_grid.is_valid_position(test_pos):
					continue

				# --- Wind compensation: adjust aim to account for wind ---
				var wind_adjusted_landing: Vector2i = test_pos
				var aim_point: Vector2i = test_pos
				if GameManager.wind_system:
					var wind_disp: Vector2 = GameManager.wind_system.get_wind_displacement(
						scan_dir, test_dist, club
					)
					# The ball will be pushed by wind_disp. Evaluate the wind-affected landing.
					wind_adjusted_landing = Vector2i((Vector2(test_pos) + wind_disp).round())
					# Aim INTO the wind: shift aim point opposite to wind displacement.
					# Compensation scales with accuracy skill (pros compensate ~80%, beginners ~20%)
					var compensation_factor: float = 0.2 + gd.accuracy_skill * 0.6
					aim_point = Vector2i((Vector2(test_pos) - wind_disp * compensation_factor).round())

					if not terrain_grid.is_valid_position(wind_adjusted_landing):
						wind_adjusted_landing = test_pos
					if not terrain_grid.is_valid_position(aim_point):
						aim_point = test_pos

				# --- Score the landing zone ---
				var score: float = _score_landing_zone(
					gd, ball_pos, wind_adjusted_landing, hole_position,
					terrain_grid, club, shots_remaining
				)

				# --- Risk analysis: sample miss distribution against hazards ---
				var risk_penalty: float = _assess_miss_risk(
					gd, ball_pos, wind_adjusted_landing, terrain_grid, club
				)
				score -= risk_penalty

				# --- Club accuracy preference for approach shots ---
				# When multiple clubs can reach the green, prefer the most
				# accurate (iron > fairway wood > driver). This prevents
				# driver selection on short par 3s where all clubs score
				# similarly on terrain alone.
				if shots_remaining <= 1:
					score += stats["accuracy_modifier"] * 20.0

				var strategy: String = "attack" if can_reach_green else "layup"

				var candidate: _ShotCandidate = _ShotCandidate.new()
				candidate.aim_point = aim_point
				candidate.landing_zone = wind_adjusted_landing
				candidate.club = club
				candidate.score = score
				candidate.strategy = strategy
				candidates.append(candidate)

	# --- Approach shot: blend toward green center for less skilled golfers ---
	# Apply BEFORE returning so it's part of the candidate set, not an override
	if can_reach_green and not candidates.is_empty():
		_apply_green_center_bias(gd, hole_position, candidates)

	return candidates

## Build candidate club list, filtering out clubs that can't reach or would massively overshoot.
static func _get_candidate_clubs(gd: GolferData, distance_to_hole: float, target_distance: float) -> Array:
	var clubs: Array = []

	for club_type in [Golfer.Club.DRIVER, Golfer.Club.FAIRWAY_WOOD, Golfer.Club.IRON, Golfer.Club.WEDGE]:
		var stats: Dictionary = Golfer.CLUB_STATS[club_type]
		var skill_factor: float = _get_skill_distance_factor(gd, club_type)
		var max_dist: float = stats["max_distance"] * skill_factor
		var min_dist: float = stats["min_distance"]

		# Filter: club minimum must not massively overshoot the target
		# A club whose min distance is 2x the target is not appropriate
		if min_dist > target_distance * 1.5 and min_dist > distance_to_hole * 1.2:
			continue

		# Filter: club must be able to reach a useful distance
		# (at least 50% of target distance or 50% of distance to hole)
		var useful_threshold: float = minf(target_distance, distance_to_hole) * 0.5
		if max_dist < useful_threshold and distance_to_hole > 2.0:
			continue

		clubs.append(club_type)

	# Always have at least a wedge
	if clubs.is_empty():
		clubs.append(Golfer.Club.WEDGE)

	return clubs

# ============================================================================
# LANDING ZONE SCORING
# ============================================================================

## Score a landing zone considering terrain, distance, next-shot setup, and personality.
static func _score_landing_zone(
	gd: GolferData, ball_pos: Vector2i, landing: Vector2i,
	hole_position: Vector2i, terrain_grid: TerrainGrid,
	club: int, shots_remaining: int
) -> float:
	# --- Tree collision check (ball flight path) ---
	if _path_crosses_trees(ball_pos, landing, terrain_grid):
		return -2000.0

	# --- Graduated penalty for flying over tree canopy ---
	var trees_overflown: int = _count_trees_along_path(ball_pos, landing, terrain_grid)
	var tree_fly_penalty: float = 0.0
	if trees_overflown > 0:
		var risk_factor: float = 1.0 - gd.accuracy_skill * 0.3
		tree_fly_penalty = 15.0 * trees_overflown * risk_factor

	# --- Base terrain score ---
	var terrain_type: int = terrain_grid.get_tile(landing)
	var score: float = TERRAIN_SCORES.get(terrain_type, -50.0)

	# --- Distance scoring: reward advancement toward hole ---
	var distance_to_hole: float = Vector2(landing).distance_to(Vector2(hole_position))
	var current_distance: float = Vector2(ball_pos).distance_to(Vector2(hole_position))
	var advancement: float = current_distance - distance_to_hole

	# Harsh penalty for shots that don't advance
	if advancement <= 0:
		score -= 500.0

	# Score based on remaining distance, weighted by shot context
	if shots_remaining <= 1:
		# Approach/attack: getting close to the hole is paramount
		score -= distance_to_hole * 5.0
	else:
		# Layup: terrain quality matters more, distance less critical
		score -= distance_to_hole * 2.0
		# Bonus for landing at a good approach distance (wedge range)
		var ideal_remaining: float = 3.5  # ~77 yards
		var distance_from_ideal: float = absf(distance_to_hole - ideal_remaining)
		if distance_from_ideal < 2.0:
			score += (2.0 - distance_from_ideal) * 25.0  # Up to +50 for ideal layup

	# --- Next-shot setup bonus ---
	# Reward landing zones that leave a clear path to the hole
	if shots_remaining > 1 and terrain_type in [TerrainTypes.Type.FAIRWAY, TerrainTypes.Type.GRASS, TerrainTypes.Type.TEE_BOX]:
		if not _path_crosses_trees(landing, hole_position, terrain_grid):
			score += 40.0  # Clear approach line bonus

	# --- Nearby hazard penalty (risk of rollout into trouble) ---
	score -= _nearby_hazard_penalty(landing, terrain_grid, gd.aggression)

	# --- Personality adjustments ---
	if gd.aggression < 0.3:
		# Cautious players extra-penalize hazards
		if terrain_type == TerrainTypes.Type.BUNKER:
			score -= 80.0
		if terrain_type in [TerrainTypes.Type.ROUGH, TerrainTypes.Type.HEAVY_ROUGH]:
			score -= 30.0
	elif gd.aggression > 0.7:
		# Aggressive players discount hazard penalties slightly
		score += 20.0

	# --- Situation awareness: score-based strategy ---
	score += _situation_modifier(gd, shots_remaining)

	score -= tree_fly_penalty
	return score

## Calculate penalty from nearby hazards (water, OB within 2 tiles).
static func _nearby_hazard_penalty(pos: Vector2i, terrain_grid: TerrainGrid, aggression: float) -> float:
	var penalty: float = 0.0
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			if dx == 0 and dy == 0:
				continue
			var check: Vector2i = pos + Vector2i(dx, dy)
			if not terrain_grid.is_valid_position(check):
				continue
			var t: int = terrain_grid.get_tile(check)
			if t == TerrainTypes.Type.WATER or t == TerrainTypes.Type.OUT_OF_BOUNDS:
				# Distance falloff: adjacent tiles (dist=1) are worst
				var dist: float = Vector2(dx, dy).length()
				penalty += (20.0 / dist) * (1.0 - aggression * 0.5)
	return penalty

## Adjust scoring based on golfer's current situation (score relative to par).
static func _situation_modifier(gd: GolferData, shots_remaining: int) -> float:
	if gd.total_par == 0:
		return 0.0  # No holes completed yet

	var score_to_par: int = gd.total_strokes - gd.total_par

	# Behind par (over par): play more aggressively to catch up
	if score_to_par >= 3 and shots_remaining <= 1:
		return 15.0  # Slight bonus for aggressive approach targets

	# Ahead of par (under par): play more conservatively to protect lead
	if score_to_par <= -2:
		return -10.0  # Slight penalty for risky targets (favors safe options)

	return 0.0

# ============================================================================
# RISK ANALYSIS — Miss distribution vs hazard overlap
# ============================================================================

## Estimate how many of the golfer's typical misses would land in hazards.
## Uses Monte Carlo sampling of the angular dispersion model.
static func _assess_miss_risk(
	gd: GolferData, ball_pos: Vector2i, target: Vector2i,
	terrain_grid: TerrainGrid, club: int
) -> float:
	var stats: Dictionary = Golfer.CLUB_STATS[club]
	var distance: float = Vector2(ball_pos).distance_to(Vector2(target))
	var direction: Vector2 = Vector2(target - ball_pos).normalized()

	if distance < 1.0:
		return 0.0

	# Calculate accuracy for spread estimation
	var skill_accuracy: float = _get_shot_accuracy(gd, club)
	var lie_modifier: float = GolfRules.get_lie_modifier(
		terrain_grid.get_tile(ball_pos), club
	)
	var total_accuracy: float = stats["accuracy_modifier"] * skill_accuracy * lie_modifier

	# Angular spread (same model as _calculate_shot)
	var max_spread_deg: float = (1.0 - total_accuracy) * 12.0
	var spread_std: float = max_spread_deg / 2.5

	# Tendency bias
	var tendency_bias: float = gd.miss_tendency * (1.0 - total_accuracy) * 6.0

	# Sample miss positions
	var hazard_hits: int = 0
	for i in range(MISS_SAMPLE_COUNT):
		# Deterministic spread sampling (evenly spaced across distribution)
		# Use ±0.5σ, ±1.0σ, ±1.5σ, ±2.0σ for even coverage
		var sigma_values: Array = [-2.0, -1.0, -0.5, -0.25, 0.25, 0.5, 1.0, 2.0]
		var sample_angle_deg: float = sigma_values[i] * spread_std + tendency_bias
		var sample_angle_rad: float = deg_to_rad(sample_angle_deg)

		var miss_dir: Vector2 = direction.rotated(sample_angle_rad)
		var miss_landing: Vector2i = ball_pos + Vector2i((miss_dir * distance).round())

		if not terrain_grid.is_valid_position(miss_landing):
			hazard_hits += 1
			continue

		var miss_terrain: int = terrain_grid.get_tile(miss_landing)
		if miss_terrain == TerrainTypes.Type.WATER or miss_terrain == TerrainTypes.Type.OUT_OF_BOUNDS:
			hazard_hits += 1

	# Convert hit fraction to penalty
	# Each hazard hit in our sample represents ~12.5% of shots
	# Penalty scales: 1 hit = mild concern, 4+ hits = very dangerous
	var hit_fraction: float = hazard_hits / float(MISS_SAMPLE_COUNT)
	var risk_penalty: float = hit_fraction * 200.0  # Up to 200 points penalty

	# Aggressive golfers discount risk
	risk_penalty *= (1.0 - gd.aggression * 0.4)

	return risk_penalty

# ============================================================================
# GREEN CENTER BIAS (for approach shots)
# ============================================================================

## For approach shots, less skilled golfers should aim more toward the green center
## rather than directly at the pin. This modifies candidate aim points rather than
## overriding the best candidate after evaluation.
static func _apply_green_center_bias(
	gd: GolferData, hole_position: Vector2i, candidates: Array
) -> void:
	var course_data = GameManager.course_data
	if not course_data or gd.current_hole >= course_data.holes.size():
		return

	var hole_data = course_data.holes[gd.current_hole]
	var green_center: Vector2i = hole_data.green_position
	if green_center == Vector2i.ZERO or green_center == hole_position:
		return

	# Pin weight: pros aim 90% at pin, beginners aim 60% at pin (40% at center)
	var pin_weight: float = clampf(gd.accuracy_skill * 0.6 + 0.4, 0.5, 0.95)

	for candidate in candidates:
		# Only adjust approach-strategy candidates near the green
		if candidate.strategy != "attack":
			continue

		var blended: Vector2 = Vector2(candidate.aim_point) * pin_weight + Vector2(green_center) * (1.0 - pin_weight)
		candidate.aim_point = Vector2i(blended.round())

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

## Assess how good the current lie is (0.0 = terrible, 1.0 = perfect)
static func _assess_lie_quality(terrain_type: int) -> float:
	match terrain_type:
		TerrainTypes.Type.FAIRWAY, TerrainTypes.Type.TEE_BOX, TerrainTypes.Type.GREEN:
			return 1.0
		TerrainTypes.Type.GRASS:
			return 0.8
		TerrainTypes.Type.PATH:
			return 0.7
		TerrainTypes.Type.ROUGH:
			return 0.5
		TerrainTypes.Type.HEAVY_ROUGH:
			return 0.3
		TerrainTypes.Type.BUNKER:
			return 0.3
		TerrainTypes.Type.TREES:
			return 0.15
		TerrainTypes.Type.ROCKS:
			return 0.1
		_:
			return 0.2

## Get skill-adjusted distance factor (mirrors Golfer._get_skill_distance_factor)
static func _get_skill_distance_factor(gd: GolferData, club: int) -> float:
	match club:
		Golfer.Club.DRIVER:
			return 0.40 + gd.driving_skill * 0.55
		Golfer.Club.FAIRWAY_WOOD:
			return 0.40 + gd.driving_skill * 0.50
		Golfer.Club.IRON:
			return 0.50 + gd.accuracy_skill * 0.42
		Golfer.Club.WEDGE:
			return 0.80 + gd.accuracy_skill * 0.18
		Golfer.Club.PUTTER:
			return 0.92 + gd.putting_skill * 0.06
		_:
			return 0.85

## Get skill-weighted accuracy for a club (mirrors _calculate_shot skill_accuracy)
static func _get_shot_accuracy(gd: GolferData, club: int) -> float:
	match club:
		Golfer.Club.DRIVER:
			return gd.driving_skill * 0.7 + gd.accuracy_skill * 0.3
		Golfer.Club.FAIRWAY_WOOD:
			return gd.driving_skill * 0.5 + gd.accuracy_skill * 0.5
		Golfer.Club.IRON:
			return gd.driving_skill * 0.4 + gd.accuracy_skill * 0.6
		Golfer.Club.WEDGE:
			return gd.accuracy_skill * 0.7 + gd.recovery_skill * 0.3
		Golfer.Club.PUTTER:
			return gd.putting_skill
		_:
			return 0.5

## Check if a ball flight path crosses trees at low altitude.
## Trees block when ball is in the first/last 30% of flight (low trajectory).
static func _path_crosses_trees(start: Vector2i, end: Vector2i, terrain_grid: TerrainGrid) -> bool:
	var distance: float = Vector2(start).distance_to(Vector2(end))
	var num_samples: int = int(distance) + 1

	for i in range(num_samples):
		var t: float = i / float(max(num_samples, 1))
		var sample_pos: Vector2i = Vector2i(Vector2(start).lerp(Vector2(end), t))

		if not terrain_grid.is_valid_position(sample_pos):
			continue

		if terrain_grid.get_tile(sample_pos) == TerrainTypes.Type.TREES:
			# Parabolic arc: ball is low at start and end, high in the middle
			var height_factor: float = 4.0 * t * (1.0 - t)
			if height_factor < 0.3:  # Must be above 30% of max height to clear
				return true

	return false

## Count tree tiles along a flight path (for graduated risk penalty)
static func _count_trees_along_path(start: Vector2i, end: Vector2i, terrain_grid: TerrainGrid) -> int:
	var distance: float = Vector2(start).distance_to(Vector2(end))
	var num_samples: int = int(distance) + 1
	var count: int = 0

	for i in range(num_samples):
		var t: float = i / float(max(num_samples, 1))
		var sample_pos: Vector2i = Vector2i(Vector2(start).lerp(Vector2(end), t))

		if not terrain_grid.is_valid_position(sample_pos):
			continue

		if terrain_grid.get_tile(sample_pos) == TerrainTypes.Type.TREES:
			count += 1

	return count

## Create a ShotDecision from components
static func _make_decision(target: Vector2i, club: int, strategy: String, confidence: float) -> ShotDecision:
	var decision: ShotDecision = ShotDecision.new()
	decision.target = target
	decision.club = club
	decision.strategy = strategy
	decision.confidence = confidence
	return decision
