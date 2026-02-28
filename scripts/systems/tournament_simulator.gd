extends RefCounted
class_name TournamentSimulator
## TournamentSimulator - Headless shot-by-shot tournament simulation
##
## Replaces the statistical stub in ShotSimulator with a full per-shot simulation
## using the real angular dispersion model, wind system, terrain interactions,
## and ShotAI decision-making. No scene tree dependency — all static methods.
##
## Performance target: 1 golfer × 18 holes in <50ms, 72 golfers in <4s.

# ============================================================================
# DATA CLASSES
# ============================================================================

## Lightweight golfer representation for headless simulation
class SimGolfer:
	var id: int = 0
	var name: String = ""
	var tier: int = GolferTier.Tier.SERIOUS
	var driving_skill: float = 0.7
	var accuracy_skill: float = 0.7
	var putting_skill: float = 0.7
	var recovery_skill: float = 0.7
	var miss_tendency: float = 0.0
	var aggression: float = 0.5
	var patience: float = 0.5

	## Create a GolferData snapshot for ShotAI compatibility
	func to_golfer_data(ball_pos: Vector2i, hole_index: int, total_strokes: int, total_par: int) -> ShotAI.GolferData:
		var gd = ShotAI.GolferData.new()
		gd.ball_position = ball_pos
		gd.ball_position_precise = Vector2(ball_pos)
		gd.driving_skill = driving_skill
		gd.accuracy_skill = accuracy_skill
		gd.putting_skill = putting_skill
		gd.recovery_skill = recovery_skill
		gd.miss_tendency = miss_tendency
		gd.aggression = aggression
		gd.patience = patience
		gd.current_hole = hole_index
		gd.total_strokes = total_strokes
		gd.total_par = total_par
		return gd

	static func from_skills(golfer_id: int, golfer_name: String, golfer_tier: int, skills: Dictionary, personality: Dictionary) -> SimGolfer:
		var sg = SimGolfer.new()
		sg.id = golfer_id
		sg.name = golfer_name
		sg.tier = golfer_tier
		sg.driving_skill = skills.get("driving", 0.7)
		sg.accuracy_skill = skills.get("accuracy", 0.7)
		sg.putting_skill = skills.get("putting", 0.7)
		sg.recovery_skill = skills.get("recovery", 0.7)
		sg.miss_tendency = skills.get("miss_tendency", 0.0)
		sg.aggression = personality.get("aggression", 0.5)
		sg.patience = personality.get("patience", 0.5)
		return sg

## Result of simulating one round for one golfer
class RoundResult:
	var golfer_id: int = 0
	var golfer_name: String = ""
	var round_number: int = 1
	var hole_scores: Array = []   # Per-hole stroke counts
	var hole_pars: Array = []     # Per-hole par values
	var total_strokes: int = 0
	var total_par: int = 0
	var moments: Array = []       # TournamentMoment entries

## Notable event during tournament play
class TournamentMoment:
	var type: String = ""          # "hole_in_one", "eagle", "albatross", "lead_change", "course_record"
	var round_number: int = 1
	var hole: int = 0
	var golfer_name: String = ""
	var detail: String = ""
	var importance: int = 0        # 0=info, 1=medium, 2=high, 3=critical

	static func create(t: String, rnd: int, h: int, name: String, det: String, imp: int) -> TournamentMoment:
		var m = TournamentMoment.new()
		m.type = t
		m.round_number = rnd
		m.hole = h
		m.golfer_name = name
		m.detail = det
		m.importance = imp
		return m

# ============================================================================
# PUBLIC API
# ============================================================================

## Simulate a complete round for one golfer on the course.
## Returns a RoundResult with per-hole scores and notable moments.
static func simulate_round(sim_golfer: SimGolfer, round_number: int = 1) -> RoundResult:
	var course_data = GameManager.course_data
	var terrain_grid = GameManager.terrain_grid
	if not course_data or not terrain_grid:
		return _empty_result(sim_golfer, round_number)

	var result = RoundResult.new()
	result.golfer_id = sim_golfer.id
	result.golfer_name = sim_golfer.name
	result.round_number = round_number

	var cumulative_strokes: int = 0
	var cumulative_par: int = 0

	for hole_index in range(course_data.holes.size()):
		var hole = course_data.holes[hole_index]
		if not hole.is_open:
			continue

		var hole_result = _simulate_hole(sim_golfer, hole, hole_index, cumulative_strokes, cumulative_par)
		result.hole_scores.append(hole_result.strokes)
		result.hole_pars.append(hole.par)
		cumulative_strokes += hole_result.strokes
		cumulative_par += hole.par

		# Detect dramatic moments
		var score_diff = hole_result.strokes - hole.par
		if hole_result.strokes == 1:
			result.moments.append(TournamentMoment.create(
				"hole_in_one", round_number, hole.hole_number,
				sim_golfer.name, "Hole-in-one on Hole %d!" % hole.hole_number, 3
			))
		elif score_diff <= -3:
			result.moments.append(TournamentMoment.create(
				"albatross", round_number, hole.hole_number,
				sim_golfer.name, "Albatross on Hole %d!" % hole.hole_number, 3
			))
		elif score_diff <= -2:
			result.moments.append(TournamentMoment.create(
				"eagle", round_number, hole.hole_number,
				sim_golfer.name, "Eagle on Hole %d" % hole.hole_number, 2
			))

	result.total_strokes = cumulative_strokes
	result.total_par = cumulative_par
	return result

## Simulate remaining holes for a partially-completed round.
## Used when End Day is pressed during a tournament with live golfers.
static func simulate_remaining(sim_golfer: SimGolfer, current_hole: int,
		total_strokes: int, total_par: int) -> RoundResult:
	var course_data = GameManager.course_data
	if not course_data:
		return _empty_result(sim_golfer, 1)

	var result = RoundResult.new()
	result.golfer_id = sim_golfer.id
	result.golfer_name = sim_golfer.name
	result.round_number = 1

	var cumulative_strokes: int = total_strokes
	var cumulative_par: int = total_par

	for hole_index in range(current_hole, course_data.holes.size()):
		var hole = course_data.holes[hole_index]
		if not hole.is_open:
			continue

		var hole_result = _simulate_hole(sim_golfer, hole, hole_index, cumulative_strokes, cumulative_par)
		result.hole_scores.append(hole_result.strokes)
		result.hole_pars.append(hole.par)
		cumulative_strokes += hole_result.strokes
		cumulative_par += hole.par

	result.total_strokes = cumulative_strokes
	result.total_par = cumulative_par
	return result

# ============================================================================
# HOLE SIMULATION
# ============================================================================

## Simulate a single hole shot-by-shot. Returns {strokes: int, moments: Array}.
static func _simulate_hole(sim_golfer: SimGolfer, hole_data, hole_index: int,
		cumulative_strokes: int, cumulative_par: int) -> Dictionary:
	var terrain_grid = GameManager.terrain_grid
	if not terrain_grid:
		return {"strokes": hole_data.par, "moments": []}

	var ball_pos: Vector2i = hole_data.tee_position
	var ball_precise: Vector2 = Vector2(ball_pos)
	var hole_pos: Vector2i = hole_data.hole_position
	var green_pos: Vector2i = hole_data.green_position
	var max_strokes: int = GolfRules.get_max_strokes(hole_data.par)
	var strokes: int = 0

	for _shot in range(max_strokes):
		strokes += 1

		var current_terrain = terrain_grid.get_tile(ball_pos)

		# Check if on the green — putt
		if current_terrain == TerrainTypes.Type.GREEN:
			var putt_result = _calculate_putt_headless(
				ball_precise, Vector2(hole_pos),
				sim_golfer.putting_skill, sim_golfer.miss_tendency
			)
			if putt_result.is_holed:
				break  # Ball in hole
			ball_pos = putt_result.landing_position
			ball_precise = putt_result.landing_precise
			continue

		# Use ShotAI for club/target decision
		var gd = sim_golfer.to_golfer_data(ball_pos, hole_index, cumulative_strokes + strokes, cumulative_par)
		gd.ball_position_precise = ball_precise
		var decision = ShotAI.decide_shot_for(gd, hole_pos)

		# Calculate shot outcome
		var shot_result = _calculate_shot_headless(
			ball_pos, decision.target, decision.club,
			sim_golfer, terrain_grid
		)

		var landing = shot_result.landing_position
		var landing_precise = shot_result.get("landing_precise", Vector2(landing))

		# Handle hazard penalties
		if terrain_grid.is_valid_position(landing):
			var landing_terrain = terrain_grid.get_tile(landing)
			var penalty = GolfRules.get_penalty_strokes(landing_terrain)
			if penalty > 0:
				strokes += penalty
				var relief = GolfRules.get_relief_type(landing_terrain)
				if relief == GolfRules.ReliefType.STROKE_AND_DISTANCE:
					# OOB: replay from previous position
					landing = ball_pos
					landing_precise = ball_precise
				else:
					# Water: drop at entry point (approximate as nearest non-hazard)
					landing = _find_drop_position(ball_pos, landing, terrain_grid)
					landing_precise = Vector2(landing)
		else:
			# Off grid — treat as OOB
			strokes += 1
			landing = ball_pos
			landing_precise = ball_precise

		# Check if holed (chip-in, hole-out)
		var dist_to_hole = Vector2(landing).distance_to(Vector2(hole_pos))
		if dist_to_hole < GolfRules.CUP_RADIUS * 2.0:
			break  # Ball in hole

		ball_pos = landing
		ball_precise = landing_precise

	return {"strokes": strokes, "moments": []}

# ============================================================================
# SHOT PHYSICS (headless, mirrors golfer.gd _calculate_shot)
# ============================================================================

## Calculate a full shot using the angular dispersion model.
## Mirrors Golfer._calculate_shot() but operates on data, no scene nodes.
static func _calculate_shot_headless(from: Vector2i, target: Vector2i, club: int,
		sim_golfer: SimGolfer, terrain_grid: TerrainGrid) -> Dictionary:
	var club_stats = Golfer.CLUB_STATS[club]
	var current_terrain = terrain_grid.get_tile(from)
	var distance_to_target = Vector2(from).distance_to(Vector2(target))

	# Lie modifier
	var lie_modifier = GolfRules.get_lie_modifier(current_terrain, club)

	# Skill-based accuracy
	var skill_accuracy = _get_shot_accuracy(sim_golfer, club)

	# Combined accuracy
	var total_accuracy = club_stats["accuracy_modifier"] * skill_accuracy * lie_modifier

	# Short game accuracy floors
	if club == Golfer.Club.WEDGE:
		var distance_ratio = clamp(distance_to_target / float(club_stats["max_distance"]), 0.0, 1.0)
		var short_game_floor = lerpf(0.96, 0.80, distance_ratio)
		total_accuracy = max(total_accuracy, short_game_floor)

	if club == Golfer.Club.PUTTER:
		var putt_distance_ratio = clamp(distance_to_target / float(club_stats["max_distance"]), 0.0, 1.0)
		var skill_floor_min = lerpf(0.50, 0.80, sim_golfer.putting_skill)
		var skill_floor_max = lerpf(0.85, 0.95, sim_golfer.putting_skill)
		var putt_floor = lerpf(skill_floor_max, skill_floor_min, putt_distance_ratio)
		total_accuracy = max(total_accuracy, putt_floor)

	# Distance modifier
	var distance_modifier = _get_distance_modifier(club)

	# Terrain distance penalty
	var terrain_distance_modifier = GolfRules.get_terrain_distance_modifier(current_terrain)
	distance_modifier *= terrain_distance_modifier

	# Wind effects
	if GameManager.wind_system:
		var shot_direction = Vector2(target - from).normalized()
		var wind_distance_mod = GameManager.wind_system.get_distance_modifier(shot_direction, club)
		distance_modifier *= wind_distance_mod

	# Elevation effect
	var elevation_diff = terrain_grid.get_elevation_difference(from, target)
	var elevation_factor = 1.0 - (elevation_diff * 0.03)
	distance_modifier *= clampf(elevation_factor, 0.75, 1.25)

	# Actual distance
	var intended_distance = Vector2(from).distance_to(Vector2(target))
	if intended_distance < 0.5:
		intended_distance = 1.0  # Minimum chip

	var actual_distance = intended_distance * distance_modifier

	# Angular dispersion model
	var direction = Vector2(target - from).normalized()
	var max_spread_deg = (1.0 - total_accuracy) * 12.0
	var spread_std_dev = max_spread_deg / 2.5

	# Reduce spread for controlled partial swings (short wedges)
	if club == Golfer.Club.WEDGE:
		var wedge_distance_ratio = clamp(actual_distance / float(club_stats["max_distance"]), 0.0, 1.0)
		spread_std_dev *= lerpf(0.3, 1.0, wedge_distance_ratio)

	# Sample miss angle from gaussian distribution
	var base_angle_deg = _gaussian_random() * spread_std_dev

	# Apply golfer's natural miss tendency
	var tendency_strength = sim_golfer.miss_tendency * (1.0 - total_accuracy) * 6.0
	var miss_angle_deg = base_angle_deg + tendency_strength

	# Rare shank
	var is_shank = false
	if club != Golfer.Club.PUTTER and club != Golfer.Club.WEDGE:
		var shank_chance = (1.0 - total_accuracy) * 0.04
		if randf() < shank_chance:
			is_shank = true
			var shank_dir = 1.0 if sim_golfer.miss_tendency >= 0.0 else -1.0
			miss_angle_deg = shank_dir * randf_range(35.0, 55.0)
			actual_distance *= randf_range(0.3, 0.6)

	# Rotate direction by miss angle
	var miss_angle_rad = deg_to_rad(miss_angle_deg)
	var miss_direction = direction.rotated(miss_angle_rad)
	var landing_point = Vector2(from) + (miss_direction * actual_distance)

	# Minimum lateral dispersion floor
	if club != Golfer.Club.PUTTER:
		var angular_lateral_std = actual_distance * sin(deg_to_rad(spread_std_dev))
		var min_lateral_std = (1.0 - total_accuracy) * 0.8
		if angular_lateral_std < min_lateral_std:
			var perpendicular = Vector2(-miss_direction.y, miss_direction.x)
			var extra_std = sqrt(max(min_lateral_std * min_lateral_std - angular_lateral_std * angular_lateral_std, 0.0))
			landing_point += perpendicular * (_gaussian_random() * extra_std)

	# Distance error (topped/fat shots)
	var distance_loss = absf(_gaussian_random()) * (1.0 - total_accuracy) * 0.12
	landing_point -= miss_direction * (actual_distance * distance_loss)

	# Wind displacement
	if GameManager.wind_system:
		var wind_displacement = GameManager.wind_system.get_wind_displacement(direction, actual_distance, club)
		landing_point += wind_displacement

	# Grid position
	var landing_position = Vector2i(landing_point.round())
	if not terrain_grid.is_valid_position(landing_position):
		landing_position = target

	# Simplified rollout (skip full rollout calculation for speed, use estimate)
	if club != Golfer.Club.PUTTER:
		var rollout_fraction = _get_rollout_fraction(club, total_accuracy)
		if rollout_fraction != 0.0:
			var roll_vec = miss_direction * actual_distance * rollout_fraction
			var rolled_pos = Vector2(landing_position) + roll_vec
			var rolled_grid = Vector2i(rolled_pos.round())
			if terrain_grid.is_valid_position(rolled_grid):
				var roll_terrain = terrain_grid.get_tile(rolled_grid)
				# Don't roll into impassable terrain
				if roll_terrain != TerrainTypes.Type.WATER and roll_terrain != TerrainTypes.Type.OUT_OF_BOUNDS and roll_terrain != TerrainTypes.Type.EMPTY:
					landing_position = rolled_grid
					landing_point = rolled_pos

	return {
		"landing_position": landing_position,
		"landing_precise": landing_point,
		"club": club,
		"is_shank": is_shank,
	}

# ============================================================================
# PUTTING (headless, mirrors golfer.gd _calculate_putt)
# ============================================================================

## Calculate a putt using the probability-based make model.
## Returns {landing_position, landing_precise, is_holed}.
static func _calculate_putt_headless(from_precise: Vector2, hole_pos: Vector2,
		putting_skill: float, miss_tendency: float) -> Dictionary:
	var distance = from_precise.distance_to(hole_pos)
	var direction = (hole_pos - from_precise).normalized() if distance > 0.001 else Vector2.ZERO
	var perpendicular = Vector2(-direction.y, direction.x)

	# Tap-in check
	if distance < GolfRules.TAP_IN_DISTANCE:
		return {
			"landing_position": Vector2i(hole_pos.round()),
			"landing_precise": hole_pos,
			"is_holed": true,
		}

	# Probability-based make
	var make_rate = GolfRules.get_putt_make_rate(distance, putting_skill)
	if randf() < make_rate:
		return {
			"landing_position": Vector2i(hole_pos.round()),
			"landing_precise": hole_pos,
			"is_holed": true,
		}

	# Putt misses — calculate miss position
	var miss_chars = GolfRules.get_putt_miss_characteristics(distance, putting_skill)
	var distance_error = _gaussian_random() * miss_chars.distance_std + miss_chars.long_bias
	var lateral_error = _gaussian_random() * miss_chars.lateral_std

	var landing = hole_pos + direction * distance_error + perpendicular * lateral_error

	# Cap miss distance
	var max_miss_from_hole: float
	if distance < 0.15:
		max_miss_from_hole = 0.03 + (1.0 - putting_skill) * 0.025
	elif distance < 0.45:
		max_miss_from_hole = 0.04 + (1.0 - putting_skill) * 0.05
	else:
		max_miss_from_hole = distance * (0.08 + (1.0 - putting_skill) * 0.12)

	var miss_dist = landing.distance_to(hole_pos)
	if miss_dist > max_miss_from_hole:
		landing = hole_pos + (landing - hole_pos).normalized() * max_miss_from_hole

	# Snap to hole if very close
	if landing.distance_to(hole_pos) < GolfRules.CUP_RADIUS:
		return {
			"landing_position": Vector2i(hole_pos.round()),
			"landing_precise": hole_pos,
			"is_holed": true,
		}

	return {
		"landing_position": Vector2i(landing.round()),
		"landing_precise": landing,
		"is_holed": false,
	}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

## Gaussian random using Central Limit Theorem (sum of 4 uniform randoms).
static func _gaussian_random() -> float:
	return (randf() + randf() + randf() + randf() - 2.0) / 0.5774

## Get skill-weighted accuracy for a club (mirrors ShotAI._get_shot_accuracy)
static func _get_shot_accuracy(sg: SimGolfer, club: int) -> float:
	match club:
		Golfer.Club.DRIVER:
			return sg.driving_skill * 0.7 + sg.accuracy_skill * 0.3
		Golfer.Club.FAIRWAY_WOOD:
			return sg.driving_skill * 0.5 + sg.accuracy_skill * 0.5
		Golfer.Club.IRON:
			return sg.driving_skill * 0.4 + sg.accuracy_skill * 0.6
		Golfer.Club.WEDGE:
			return sg.accuracy_skill * 0.7 + sg.recovery_skill * 0.3
		Golfer.Club.PUTTER:
			return sg.putting_skill
		_:
			return 0.5

## Get distance modifier per club (random shot-to-shot variance)
static func _get_distance_modifier(club: int) -> float:
	match club:
		Golfer.Club.DRIVER:
			return 0.97 + randf_range(-0.06, 0.04)
		Golfer.Club.FAIRWAY_WOOD:
			return 0.97 + randf_range(-0.05, 0.04)
		Golfer.Club.IRON:
			return 0.98 + randf_range(-0.04, 0.03)
		Golfer.Club.WEDGE:
			return 0.98 + randf_range(-0.03, 0.02)
		Golfer.Club.PUTTER:
			return 0.99 + randf_range(-0.02, 0.01)
		_:
			return 1.0

## Get simplified rollout fraction for headless simulation
static func _get_rollout_fraction(club: int, total_accuracy: float) -> float:
	var roll_t = clampf(randf() * 0.6 + randf() * 0.4, 0.0, 1.0)
	match club:
		Golfer.Club.DRIVER:
			return lerpf(0.05, 0.15, roll_t)
		Golfer.Club.FAIRWAY_WOOD:
			return lerpf(0.05, 0.14, roll_t)
		Golfer.Club.IRON:
			return lerpf(0.05, 0.14, roll_t)
		Golfer.Club.WEDGE:
			# Skilled players get backspin on full wedges
			if total_accuracy > 0.8:
				return lerpf(-0.02, 0.06, roll_t)
			return lerpf(0.03, 0.12, roll_t)
		_:
			return 0.0

## Find a safe drop position after a water hazard (nearest non-hazard tile along the path)
static func _find_drop_position(from: Vector2i, water_pos: Vector2i, terrain_grid: TerrainGrid) -> Vector2i:
	var direction = Vector2(water_pos - from).normalized()
	var distance = Vector2(from).distance_to(Vector2(water_pos))

	# Walk backwards from water position to find last safe tile
	for i in range(int(distance), 0, -1):
		var check = Vector2i((Vector2(from) + direction * i).round())
		if terrain_grid.is_valid_position(check):
			var t = terrain_grid.get_tile(check)
			if t != TerrainTypes.Type.WATER and t != TerrainTypes.Type.OUT_OF_BOUNDS and t != TerrainTypes.Type.EMPTY:
				return check

	return from  # Fallback to original position

## Create empty result for error cases
static func _empty_result(sim_golfer: SimGolfer, round_number: int) -> RoundResult:
	var result = RoundResult.new()
	result.golfer_id = sim_golfer.id
	result.golfer_name = sim_golfer.name
	result.round_number = round_number
	return result

# ============================================================================
# TOURNAMENT FIELD GENERATION
# ============================================================================

## Generate tournament field with tier-appropriate skill distributions.
## Returns Array of SimGolfer.
static func generate_field(tier: int, field_size: int) -> Array:
	var field: Array = []
	var tier_composition = _get_tier_composition(tier)
	var used_names: Dictionary = {}

	for i in range(field_size):
		# Determine golfer tier from composition percentages
		var roll = randf()
		var golfer_tier: int
		var cumulative = 0.0
		golfer_tier = GolferTier.Tier.SERIOUS  # Default
		for t_key in tier_composition:
			cumulative += tier_composition[t_key]
			if roll <= cumulative:
				golfer_tier = t_key
				break

		var skills = GolferTier.generate_skills(golfer_tier)

		# Apply skill floor per tournament tier
		var skill_floor = _get_skill_floor(tier)
		skills.driving = maxf(skills.driving, skill_floor)
		skills.accuracy = maxf(skills.accuracy, skill_floor)
		skills.putting = maxf(skills.putting, skill_floor)
		skills.recovery = maxf(skills.recovery, skill_floor)

		var personality = GolferTier.get_personality(golfer_tier)
		var golfer_name = _generate_unique_name(golfer_tier, used_names)
		used_names[golfer_name] = true

		# Marquee golfers for Championship tier
		var is_marquee = (tier == TournamentSystem.TournamentTier.CHAMPIONSHIP and i < 4)
		if is_marquee:
			golfer_tier = GolferTier.Tier.PRO
			skills.driving = randf_range(0.93, 0.99)
			skills.accuracy = randf_range(0.93, 0.99)
			skills.putting = randf_range(0.93, 0.99)
			skills.recovery = randf_range(0.90, 0.98)
			skills.miss_tendency = randf_range(-0.08, 0.08)
			golfer_name = _get_marquee_name(i, used_names)
			used_names[golfer_name] = true

		var sg = SimGolfer.from_skills(-(i + 1), golfer_name, golfer_tier, skills, personality)
		field.append(sg)

	return field

## Get tier composition percentages
static func _get_tier_composition(tier: int) -> Dictionary:
	match tier:
		TournamentSystem.TournamentTier.LOCAL:
			return {
				GolferTier.Tier.CASUAL: 0.50,
				GolferTier.Tier.SERIOUS: 0.40,
				GolferTier.Tier.PRO: 0.10,
			}
		TournamentSystem.TournamentTier.REGIONAL:
			return {
				GolferTier.Tier.CASUAL: 0.20,
				GolferTier.Tier.SERIOUS: 0.50,
				GolferTier.Tier.PRO: 0.30,
			}
		TournamentSystem.TournamentTier.NATIONAL:
			return {
				GolferTier.Tier.CASUAL: 0.05,
				GolferTier.Tier.SERIOUS: 0.35,
				GolferTier.Tier.PRO: 0.60,
			}
		TournamentSystem.TournamentTier.CHAMPIONSHIP:
			return {
				GolferTier.Tier.SERIOUS: 0.20,
				GolferTier.Tier.PRO: 0.80,
			}
		_:
			return {GolferTier.Tier.SERIOUS: 0.50, GolferTier.Tier.PRO: 0.50}

## Get skill floor per tournament tier
static func _get_skill_floor(tier: int) -> float:
	match tier:
		TournamentSystem.TournamentTier.LOCAL: return 0.55
		TournamentSystem.TournamentTier.REGIONAL: return 0.65
		TournamentSystem.TournamentTier.NATIONAL: return 0.75
		TournamentSystem.TournamentTier.CHAMPIONSHIP: return 0.85
		_: return 0.5

## Generate a unique golfer name
static func _generate_unique_name(tier: int, used: Dictionary) -> String:
	var first_names = [
		"Alex", "Blake", "Casey", "Drew", "Evan", "Finn", "Grant", "Hayes",
		"Ian", "Jake", "Kyle", "Liam", "Max", "Noah", "Owen", "Pete",
		"Quinn", "Reid", "Sam", "Troy", "Vince", "Will", "Xander", "Yuri",
		"Zach", "Aiden", "Ben", "Cole", "Dean", "Eric", "Ford", "Glen",
		"Hugo", "Ike", "Joel", "Kent", "Lars", "Mark", "Nate", "Oscar",
		"Paul", "Roy", "Sean", "Todd", "Uri", "Wade", "Wyatt", "York",
	]
	var last_names = [
		"Anderson", "Baker", "Chen", "Davis", "Ellis", "Ford", "Garcia",
		"Hill", "Ivanov", "Jones", "Kim", "Lee", "Miller", "Nelson",
		"O'Brien", "Park", "Quinn", "Rivera", "Smith", "Taylor",
		"Ueda", "Vance", "Williams", "Xu", "Young", "Zhang",
		"Adams", "Brown", "Clark", "Diaz", "Evans", "Fisher",
		"Green", "Hayes", "Ingram", "Jackson", "Klein", "Lopez",
		"Moore", "Nguyen", "Olsen", "Patel", "Reed", "Scott",
		"Thomas", "Underwood", "Vargas", "Ward", "Yamamoto", "Zimmer",
	]

	for _attempt in range(100):
		var first = first_names[randi() % first_names.size()]
		var last = last_names[randi() % last_names.size()]
		var full = first + " " + last
		if not used.has(full):
			return full

	# Fallback with number
	return GolferTier.get_name_prefix(tier) + " #%d" % (used.size() + 1)

## Get marquee golfer name
static func _get_marquee_name(index: int, used: Dictionary) -> String:
	var marquee_names = [
		"Tiger Woods", "Jack Nicklaus", "Arnold Palmer", "Ben Hogan",
		"Bobby Jones", "Phil Mickelson", "Rory McIlroy", "Jordan Spieth",
		"Seve Ballesteros", "Gary Player", "Tom Watson", "Greg Norman",
	]
	for name in marquee_names:
		if not used.has(name):
			return name
	return "Star Player #%d" % (index + 1)
