extends RefCounted
class_name ShotCalculator
## ShotCalculator - Pure shot physics extracted from Golfer
##
## Calculates shot outcomes (direction, distance, accuracy, rollout) using an
## angular dispersion model with gaussian error distribution. Stateless — all
## golfer-specific data is passed via ShotContext.
##
## Extracted to enable:
## 1. Independent unit testing of shot physics
## 2. Reuse for tournament simulation, practice range, etc.
## 3. Reducing golfer.gd complexity (~400 lines moved here)

## Context object holding all golfer-specific data needed for a shot
class ShotContext:
	var driving_skill: float = 0.5
	var accuracy_skill: float = 0.5
	var putting_skill: float = 0.5
	var recovery_skill: float = 0.5
	var miss_tendency: float = 0.0
	var aggression: float = 0.5
	var current_hole: int = 0

	static func from_golfer(golfer) -> ShotContext:
		var ctx = ShotContext.new()
		ctx.driving_skill = golfer.driving_skill
		ctx.accuracy_skill = golfer.accuracy_skill
		ctx.putting_skill = golfer.putting_skill
		ctx.recovery_skill = golfer.recovery_skill
		ctx.miss_tendency = golfer.miss_tendency
		ctx.aggression = golfer.aggression
		ctx.current_hole = golfer.current_hole
		return ctx


## Calculate a full swing shot outcome.
## Returns Dictionary with: landing_position, landing_position_precise,
## carry_position_precise, distance, accuracy, club, rollout_tiles, is_backspin
static func calculate_shot(from: Vector2i, target: Vector2i, club: int,
		ctx: ShotContext, terrain_grid: TerrainGrid,
		wind_system = null, course_data = null) -> Dictionary:
	if not terrain_grid:
		return {"landing_position": target, "landing_position_precise": Vector2(target),
			"carry_position_precise": Vector2(target), "distance": 0, "accuracy": 1.0,
			"club": club, "rollout_tiles": 0.0, "is_backspin": false}

	var club_stats = Golfer.CLUB_STATS[club]
	var current_terrain = terrain_grid.get_tile(from)
	var distance_to_target = Vector2(from).distance_to(Vector2(target))

	# Get terrain modifiers
	var lie_modifier = GolfRules.get_lie_modifier(current_terrain, club)

	# Calculate skill-based accuracy
	var skill_accuracy = _get_skill_accuracy(club, ctx)

	# Combine all accuracy factors
	var base_accuracy = club_stats["accuracy_modifier"]
	var total_accuracy = base_accuracy * skill_accuracy * lie_modifier

	# Short game accuracy boost for wedge shots
	if club == Golfer.Club.WEDGE:
		var distance_ratio = clamp(distance_to_target / float(club_stats["max_distance"]), 0.0, 1.0)
		var short_game_floor = lerpf(0.96, 0.80, distance_ratio)
		total_accuracy = max(total_accuracy, short_game_floor)

	# Putt accuracy floor
	if club == Golfer.Club.PUTTER:
		var putt_distance_ratio = clamp(distance_to_target / float(club_stats["max_distance"]), 0.0, 1.0)
		var skill_floor_min = lerpf(0.50, 0.80, ctx.putting_skill)
		var skill_floor_max = lerpf(0.85, 0.95, ctx.putting_skill)
		var putt_floor = lerpf(skill_floor_max, skill_floor_min, putt_distance_ratio)
		total_accuracy = max(total_accuracy, putt_floor)

	# Distance modifier
	var distance_modifier = _get_distance_modifier(club, ctx)

	# Apply terrain distance penalty
	var terrain_distance_modifier = GolfRules.get_terrain_distance_modifier(current_terrain)
	distance_modifier *= terrain_distance_modifier

	# Apply wind effect on distance
	if wind_system:
		var shot_direction = Vector2(target - from).normalized()
		var wind_distance_mod = wind_system.get_distance_modifier(shot_direction, club)
		distance_modifier *= wind_distance_mod

	# Apply elevation effect on distance
	var elevation_diff = terrain_grid.get_elevation_difference(from, target)
	var elevation_factor = 1.0 - (elevation_diff * 0.03)
	distance_modifier *= clampf(elevation_factor, 0.75, 1.25)

	# Calculate actual distance
	var intended_distance = Vector2(from).distance_to(Vector2(target))
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
	var base_angle_deg = gaussian_random() * spread_std_dev

	# Apply golfer's natural miss tendency
	var tendency_strength = ctx.miss_tendency * (1.0 - total_accuracy) * 6.0
	var miss_angle_deg = base_angle_deg + tendency_strength

	# Rare shank
	if club != Golfer.Club.PUTTER and club != Golfer.Club.WEDGE:
		var shank_chance = (1.0 - total_accuracy) * 0.06
		if randf() < shank_chance:
			var shank_dir = 1.0 if ctx.miss_tendency >= 0.0 else -1.0
			miss_angle_deg = shank_dir * randf_range(35.0, 55.0)
			actual_distance *= randf_range(0.3, 0.6)

	# Rotate direction by miss angle
	var miss_angle_rad = deg_to_rad(miss_angle_deg)
	var miss_direction = direction.rotated(miss_angle_rad)
	var landing_point = Vector2(from) + (miss_direction * actual_distance)

	# Distance error: topped/fat shots
	var distance_loss = absf(gaussian_random()) * (1.0 - total_accuracy) * 0.12
	landing_point -= miss_direction * (actual_distance * distance_loss)

	# Apply wind displacement
	if wind_system:
		var wind_displacement = wind_system.get_wind_displacement(direction, actual_distance, club)
		landing_point += wind_displacement

	# Carry position
	var carry_position_precise = landing_point
	var carry_position = Vector2i(landing_point.round())

	if not terrain_grid.is_valid_position(carry_position):
		carry_position = target
		carry_position_precise = Vector2(target)

	# Handle putter edge case (kept for backward compat, normally putts use calculate_putt)
	if club == Golfer.Club.PUTTER:
		return _handle_putter_carry(from, carry_position, carry_position_precise,
			total_accuracy, terrain_grid, course_data, ctx.current_hole)

	# Rollout calculation
	var rollout = calculate_rollout(club, carry_position, carry_position_precise,
		Vector2(from), actual_distance, total_accuracy, ctx, terrain_grid)

	var final_position_precise = rollout.final_position
	var final_position = Vector2i(final_position_precise.round())

	if not terrain_grid.is_valid_position(final_position):
		final_position = carry_position
		final_position_precise = carry_position_precise

	var distance_yards = terrain_grid.calculate_distance_yards(from, final_position)

	return {
		"landing_position": final_position,
		"landing_position_precise": final_position_precise,
		"carry_position_precise": carry_position_precise,
		"distance": distance_yards,
		"accuracy": total_accuracy,
		"club": club,
		"rollout_tiles": rollout.rollout_distance,
		"is_backspin": rollout.is_backspin,
	}


## Calculate putt with sub-tile precision.
## Uses probability-based make model calibrated to PGA Tour putting stats.
static func calculate_putt(from_precise: Vector2, ctx: ShotContext,
		terrain_grid: TerrainGrid, course_data = null) -> Dictionary:
	if not terrain_grid or not course_data or course_data.holes.is_empty() or ctx.current_hole >= course_data.holes.size():
		return {
			"landing_position": Vector2i(from_precise.round()),
			"landing_precise": from_precise,
			"from_precise": from_precise,
			"distance": 0,
			"accuracy": 1.0,
			"club": Golfer.Club.PUTTER
		}

	var hole_data = course_data.holes[ctx.current_hole]
	var hole_pos = Vector2(hole_data.hole_position)

	var distance = from_precise.distance_to(hole_pos)
	var direction = (hole_pos - from_precise).normalized() if distance > 0.001 else Vector2.ZERO
	var perpendicular = Vector2(-direction.y, direction.x)

	var landing: Vector2

	# Step 1: Tap-in check
	if distance < GolfRules.TAP_IN_DISTANCE:
		landing = hole_pos
	else:
		# Step 2: Determine if the putt is made
		var make_rate = GolfRules.get_putt_make_rate(distance, ctx.putting_skill)
		var is_made = randf() < make_rate

		if is_made:
			landing = hole_pos
		else:
			# Putt misses — calculate realistic miss position
			var miss_chars = GolfRules.get_putt_miss_characteristics(distance, ctx.putting_skill)

			var distance_error = gaussian_random() * miss_chars.distance_std + miss_chars.long_bias
			var lateral_error = gaussian_random() * miss_chars.lateral_std

			landing = hole_pos + direction * distance_error + perpendicular * lateral_error

			# Cap miss distance
			var max_miss_from_hole: float
			if distance < 0.15:
				max_miss_from_hole = 0.06 + (1.0 - ctx.putting_skill) * 0.04
			elif distance < 0.45:
				max_miss_from_hole = 0.10 + (1.0 - ctx.putting_skill) * 0.10
			else:
				max_miss_from_hole = distance * (0.15 + (1.0 - ctx.putting_skill) * 0.20)

			var miss_dist = landing.distance_to(hole_pos)
			if miss_dist > max_miss_from_hole:
				landing = hole_pos + (landing - hole_pos).normalized() * max_miss_from_hole

			# Snap to hole if very close
			if landing.distance_to(hole_pos) < GolfRules.CUP_RADIUS:
				landing = hole_pos

	# Ensure landing stays on green terrain
	var landing_tile = Vector2i(landing.round())
	if not terrain_grid.is_valid_position(landing_tile) or terrain_grid.get_tile(landing_tile) != TerrainTypes.Type.GREEN:
		var steps = max(int(from_precise.distance_to(landing) * 10.0), 1)
		var last_valid = from_precise
		for i in range(1, steps + 1):
			var t = i / float(steps)
			var check = from_precise.lerp(landing, t)
			var check_tile = Vector2i(check.round())
			if terrain_grid.is_valid_position(check_tile) and terrain_grid.get_tile(check_tile) == TerrainTypes.Type.GREEN:
				last_valid = check
			else:
				break
		landing = last_valid

	var distance_yards = int(from_precise.distance_to(landing) * 22.0)

	return {
		"landing_position": Vector2i(landing.round()),
		"landing_precise": landing,
		"from_precise": from_precise,
		"distance": distance_yards,
		"accuracy": clampf(ctx.putting_skill, 0.0, 1.0),
		"club": Golfer.Club.PUTTER
	}


## Calculate rollout after ball lands.
## Returns Dictionary with final_position, rollout_distance, is_backspin.
static func calculate_rollout(club: int, carry_grid: Vector2i, carry_precise: Vector2,
		shot_origin: Vector2, carry_distance: float, total_accuracy: float,
		ctx: ShotContext, terrain_grid: TerrainGrid) -> Dictionary:
	var no_rollout = {
		"final_position": carry_precise,
		"rollout_distance": 0.0,
		"is_backspin": false,
	}
	if not terrain_grid:
		return no_rollout

	var carry_terrain = terrain_grid.get_tile(carry_grid)

	# No rollout in water, OB, bunker, or flower beds
	if carry_terrain in [TerrainTypes.Type.WATER, TerrainTypes.Type.OUT_OF_BOUNDS,
			TerrainTypes.Type.BUNKER, TerrainTypes.Type.FLOWER_BED]:
		return no_rollout

	# Base rollout fraction
	var rollout_min: float
	var rollout_max: float
	var is_wedge_chip = false

	match club:
		Golfer.Club.DRIVER:
			rollout_min = 0.12
			rollout_max = 0.28
		Golfer.Club.FAIRWAY_WOOD:
			rollout_min = 0.08
			rollout_max = 0.20
		Golfer.Club.IRON:
			rollout_min = 0.05
			rollout_max = 0.14
		Golfer.Club.WEDGE:
			var club_stats = Golfer.CLUB_STATS[Golfer.Club.WEDGE]
			var distance_ratio = carry_distance / float(club_stats["max_distance"])
			if distance_ratio > 0.65:
				rollout_min = -0.04
				rollout_max = 0.08
			else:
				is_wedge_chip = true
				rollout_min = 0.06
				rollout_max = 0.18
		_:
			return no_rollout

	# Sample rollout fraction
	var roll_t = clampf(randf() * 0.6 + randf() * 0.4, 0.0, 1.0)
	var base_rollout_fraction = lerpf(rollout_min, rollout_max, roll_t)

	# Backspin for full wedge shots
	var is_backspin = false
	if club == Golfer.Club.WEDGE and not is_wedge_chip:
		var spin_skill = (ctx.accuracy_skill * 0.6 + ctx.recovery_skill * 0.4)
		if spin_skill > 0.7:
			var spin_bonus = (spin_skill - 0.7) / 0.3
			base_rollout_fraction -= spin_bonus * 0.10
		base_rollout_fraction = maxf(base_rollout_fraction, -0.04)

		if base_rollout_fraction < 0.0:
			is_backspin = true

	# Landing terrain multiplier
	var terrain_roll_mult = _get_terrain_roll_multiplier(carry_terrain)

	# Backspin less affected by terrain
	if is_backspin:
		terrain_roll_mult = lerpf(1.0, terrain_roll_mult, 0.4)

	var rollout_fraction = base_rollout_fraction * terrain_roll_mult
	var rollout_distance = carry_distance * absf(rollout_fraction)

	# Minimum visible rollout threshold
	if rollout_distance < 0.15:
		return no_rollout

	# Slope influence
	var slope = terrain_grid.get_slope_direction(carry_grid)
	var shot_direction = (carry_precise - shot_origin).normalized()
	var roll_direction: Vector2

	if is_backspin:
		roll_direction = -shot_direction
	else:
		roll_direction = shot_direction

	# Blend slope into roll direction
	if slope.length() > 0:
		var slope_influence = clampf(rollout_distance / 3.0, 0.1, 0.5)
		roll_direction = (roll_direction * (1.0 - slope_influence) + slope * slope_influence).normalized()

	# Slope dot product
	var slope_dot = slope.dot(roll_direction)
	if slope_dot > 0:
		rollout_distance *= 1.0 + slope_dot * 0.5
	elif slope_dot < 0:
		rollout_distance *= maxf(0.2, 1.0 + slope_dot * 0.5)

	# Walk rollout path checking for hazards
	var final_position = carry_precise
	var steps = int(ceilf(rollout_distance * 4.0))
	var step_size = rollout_distance / maxf(steps, 1)

	for i in range(1, steps + 1):
		var check_point = carry_precise + roll_direction * (step_size * i)
		var check_grid = Vector2i(check_point.round())

		if not terrain_grid.is_valid_position(check_grid):
			break

		var check_terrain = terrain_grid.get_tile(check_grid)

		if check_terrain == TerrainTypes.Type.WATER:
			final_position = check_point
			break
		if check_terrain == TerrainTypes.Type.OUT_OF_BOUNDS:
			final_position = check_point
			break
		if check_terrain == TerrainTypes.Type.BUNKER:
			final_position = check_point
			break

		if check_terrain == TerrainTypes.Type.ROUGH and carry_terrain != TerrainTypes.Type.ROUGH:
			rollout_distance *= 0.6
			steps = int(ceilf(rollout_distance * 4.0))

		final_position = check_point

	return {
		"final_position": final_position,
		"rollout_distance": carry_precise.distance_to(final_position),
		"is_backspin": is_backspin,
	}


## Approximate gaussian random using Central Limit Theorem.
## Returns value with mean ~0 and std dev ~1. Range approximately -3.5 to +3.5.
static func gaussian_random() -> float:
	return (randf() + randf() + randf() + randf() - 2.0) / 0.5774


# --- Private helpers ---

static func _get_skill_accuracy(club: int, ctx: ShotContext) -> float:
	match club:
		Golfer.Club.DRIVER:
			return (ctx.driving_skill * 0.7 + ctx.accuracy_skill * 0.3)
		Golfer.Club.FAIRWAY_WOOD:
			return (ctx.driving_skill * 0.5 + ctx.accuracy_skill * 0.5)
		Golfer.Club.IRON:
			return (ctx.driving_skill * 0.4 + ctx.accuracy_skill * 0.6)
		Golfer.Club.WEDGE:
			return (ctx.accuracy_skill * 0.7 + ctx.recovery_skill * 0.3)
		Golfer.Club.PUTTER:
			return ctx.putting_skill
		_:
			return ctx.accuracy_skill


static func _get_distance_modifier(club: int, ctx: ShotContext) -> float:
	var distance_modifier = 1.0
	match club:
		Golfer.Club.DRIVER:
			var skill_bonus = ctx.driving_skill * 0.08
			var shot_variance = randf_range(-0.08, 0.06)
			distance_modifier = 0.92 + skill_bonus + shot_variance
		Golfer.Club.FAIRWAY_WOOD:
			var skill_bonus = ctx.driving_skill * 0.06
			var shot_variance = randf_range(-0.06, 0.05)
			distance_modifier = 0.94 + skill_bonus + shot_variance
		Golfer.Club.IRON:
			var skill_bonus = ctx.accuracy_skill * 0.05
			var shot_variance = randf_range(-0.05, 0.04)
			distance_modifier = 0.95 + skill_bonus + shot_variance
		Golfer.Club.WEDGE:
			var skill_bonus = ctx.accuracy_skill * 0.03
			var shot_variance = randf_range(-0.04, 0.03)
			distance_modifier = 0.97 + skill_bonus + shot_variance
		Golfer.Club.PUTTER:
			var skill_bonus = ctx.putting_skill * 0.02
			var shot_variance = randf_range(-0.03, 0.02)
			distance_modifier = 0.98 + skill_bonus + shot_variance
	return distance_modifier


static func _get_terrain_roll_multiplier(terrain_type: int) -> float:
	match terrain_type:
		TerrainTypes.Type.GREEN:
			return 1.3
		TerrainTypes.Type.FAIRWAY:
			return 1.0
		TerrainTypes.Type.TEE_BOX:
			return 1.0
		TerrainTypes.Type.GRASS:
			return 0.35
		TerrainTypes.Type.ROUGH:
			return 0.3
		TerrainTypes.Type.HEAVY_ROUGH:
			return 0.12
		TerrainTypes.Type.TREES:
			return 0.2
		TerrainTypes.Type.ROCKS:
			return 0.15
		TerrainTypes.Type.PATH:
			return 1.4
		_:
			return 0.3


static func _handle_putter_carry(from: Vector2i, carry_position: Vector2i,
		carry_position_precise: Vector2, total_accuracy: float,
		terrain_grid: TerrainGrid, course_data, current_hole: int) -> Dictionary:
	if course_data and not course_data.holes.is_empty() and current_hole < course_data.holes.size():
		var hole_data = course_data.holes[current_hole]
		var hole_position = hole_data.hole_position
		var distance_to_hole = Vector2(carry_position).distance_to(Vector2(hole_position))

		if distance_to_hole < 1.0:
			carry_position = hole_position
		else:
			var landing_terrain = terrain_grid.get_tile(carry_position)
			if landing_terrain != TerrainTypes.Type.GREEN:
				var dir = Vector2(carry_position - from).normalized()
				var edge_pos = from
				for i in range(1, int(Vector2(from).distance_to(Vector2(carry_position))) + 1):
					var check = Vector2i((Vector2(from) + dir * i).round())
					if terrain_grid.is_valid_position(check) and terrain_grid.get_tile(check) == TerrainTypes.Type.GREEN:
						edge_pos = check
					else:
						break
				carry_position = edge_pos

	var distance_yards = terrain_grid.calculate_distance_yards(from, carry_position)
	return {
		"landing_position": carry_position,
		"landing_position_precise": carry_position_precise,
		"carry_position_precise": carry_position_precise,
		"distance": distance_yards,
		"accuracy": total_accuracy,
		"club": Golfer.Club.PUTTER,
		"rollout_tiles": 0.0,
		"is_backspin": false,
	}
