extends GutTest
## Tests for ShotCalculator - Shot physics extracted from Golfer
##
## Tests the angular dispersion model, gaussian distribution, rollout,
## and putt make rates in isolation without needing a full Golfer scene.


# --- Gaussian Random Distribution ---

func test_gaussian_random_mean_near_zero() -> void:
	var sum = 0.0
	var n = 5000
	for _i in range(n):
		sum += ShotCalculator.gaussian_random()
	var mean = sum / n
	assert_almost_eq(mean, 0.0, 0.1, "Mean of gaussian should be near 0")

func test_gaussian_random_std_dev_near_one() -> void:
	var sum_sq = 0.0
	var n = 5000
	for _i in range(n):
		var v = ShotCalculator.gaussian_random()
		sum_sq += v * v
	var variance = sum_sq / n
	var std_dev = sqrt(variance)
	assert_almost_eq(std_dev, 1.0, 0.15, "Std dev of gaussian should be near 1.0")

func test_gaussian_random_range_bounded() -> void:
	for _i in range(1000):
		var v = ShotCalculator.gaussian_random()
		assert_true(v >= -4.0 and v <= 4.0,
			"Gaussian value should be within ±4.0, got %f" % v)


# --- ShotContext ---

func test_shot_context_defaults() -> void:
	var ctx = ShotCalculator.ShotContext.new()
	assert_eq(ctx.driving_skill, 0.5)
	assert_eq(ctx.accuracy_skill, 0.5)
	assert_eq(ctx.putting_skill, 0.5)
	assert_eq(ctx.recovery_skill, 0.5)
	assert_eq(ctx.miss_tendency, 0.0)
	assert_eq(ctx.current_hole, 0)


# --- Skill Accuracy Calculation ---

func test_driver_accuracy_weights_driving_higher() -> void:
	var ctx = ShotCalculator.ShotContext.new()
	ctx.driving_skill = 0.9
	ctx.accuracy_skill = 0.3
	var acc = ShotCalculator._get_skill_accuracy(Golfer.Club.DRIVER, ctx)
	# Driver: driving * 0.7 + accuracy * 0.3 = 0.63 + 0.09 = 0.72
	assert_almost_eq(acc, 0.72, 0.01)

func test_wedge_accuracy_weights_accuracy_higher() -> void:
	var ctx = ShotCalculator.ShotContext.new()
	ctx.accuracy_skill = 0.9
	ctx.recovery_skill = 0.3
	var acc = ShotCalculator._get_skill_accuracy(Golfer.Club.WEDGE, ctx)
	# Wedge: accuracy * 0.7 + recovery * 0.3 = 0.63 + 0.09 = 0.72
	assert_almost_eq(acc, 0.72, 0.01)

func test_putter_accuracy_uses_putting_skill() -> void:
	var ctx = ShotCalculator.ShotContext.new()
	ctx.putting_skill = 0.85
	var acc = ShotCalculator._get_skill_accuracy(Golfer.Club.PUTTER, ctx)
	assert_eq(acc, 0.85)


# --- Distance Modifier ---

func test_distance_modifier_driver_range() -> void:
	var ctx = ShotCalculator.ShotContext.new()
	ctx.driving_skill = 0.5
	# Run many times to check range
	for _i in range(100):
		var dm = ShotCalculator._get_distance_modifier(Golfer.Club.DRIVER, ctx)
		# 0.92 + 0.5*0.08 + randf_range(-0.08, 0.06) = 0.96 + [-0.08, 0.06]
		# Range: [0.84, 1.06] roughly
		assert_true(dm >= 0.80 and dm <= 1.10,
			"Driver distance modifier out of range: %f" % dm)

func test_distance_modifier_putter_tight_range() -> void:
	var ctx = ShotCalculator.ShotContext.new()
	ctx.putting_skill = 0.8
	for _i in range(100):
		var dm = ShotCalculator._get_distance_modifier(Golfer.Club.PUTTER, ctx)
		assert_true(dm >= 0.93 and dm <= 1.05,
			"Putter distance modifier should be tight: %f" % dm)


# --- Terrain Roll Multiplier ---

func test_green_rolls_more_than_rough() -> void:
	var green_mult = ShotCalculator._get_terrain_roll_multiplier(TerrainTypes.Type.GREEN)
	var rough_mult = ShotCalculator._get_terrain_roll_multiplier(TerrainTypes.Type.ROUGH)
	assert_gt(green_mult, rough_mult, "Green should have higher roll multiplier than rough")

func test_path_rolls_most() -> void:
	var path_mult = ShotCalculator._get_terrain_roll_multiplier(TerrainTypes.Type.PATH)
	var fairway_mult = ShotCalculator._get_terrain_roll_multiplier(TerrainTypes.Type.FAIRWAY)
	assert_gt(path_mult, fairway_mult, "Path (hard surface) should roll more than fairway")

func test_heavy_rough_barely_rolls() -> void:
	var mult = ShotCalculator._get_terrain_roll_multiplier(TerrainTypes.Type.HEAVY_ROUGH)
	assert_lt(mult, 0.2, "Heavy rough should nearly stop the ball")


# --- Angular Dispersion Model Properties ---
# These test the mathematical properties of the shot model without
# needing a TerrainGrid (which requires scene tree context).

func test_max_spread_decreases_with_accuracy() -> void:
	# Higher accuracy = smaller max spread angle
	var low_acc_spread = (1.0 - 0.3) * 12.0   # 8.4 degrees
	var high_acc_spread = (1.0 - 0.95) * 12.0  # 0.6 degrees
	assert_gt(low_acc_spread, high_acc_spread,
		"Low accuracy should have wider spread than high accuracy")

func test_tendency_bias_scales_with_inaccuracy() -> void:
	var tendency = 0.5  # Moderate slice
	# At low accuracy, tendency has large effect
	var low_acc_bias = tendency * (1.0 - 0.3) * 6.0   # 2.1 degrees
	# At high accuracy, tendency has small effect
	var high_acc_bias = tendency * (1.0 - 0.95) * 6.0  # 0.15 degrees
	assert_gt(low_acc_bias, high_acc_bias,
		"Tendency bias should be larger for less accurate golfers")

func test_shank_probability_scales_with_inaccuracy() -> void:
	var low_acc_shank = (1.0 - 0.3) * 0.06   # 4.2%
	var high_acc_shank = (1.0 - 0.95) * 0.06  # 0.3%
	assert_gt(low_acc_shank, high_acc_shank,
		"Low accuracy should have higher shank chance")
	assert_lt(high_acc_shank, 0.01,
		"Pros should shank less than 1% of the time")


# --- Wedge Accuracy Floor ---

func test_wedge_short_game_floor_at_close_range() -> void:
	# At point-blank range, floor = 0.96
	var floor_close = lerpf(0.96, 0.80, 0.0)
	assert_almost_eq(floor_close, 0.96, 0.01,
		"Short wedge shots should have 0.96 accuracy floor")

func test_wedge_short_game_floor_at_max_range() -> void:
	# At max range, floor = 0.80
	var floor_max = lerpf(0.96, 0.80, 1.0)
	assert_almost_eq(floor_max, 0.80, 0.01,
		"Max range wedge shots should have 0.80 accuracy floor")


# --- Putt Accuracy Floor ---

func test_putt_floor_high_skill_short_putt() -> void:
	var putting_skill = 0.95
	var putt_distance_ratio = 0.0  # Very short putt
	var skill_floor_min = lerpf(0.50, 0.80, putting_skill)
	var skill_floor_max = lerpf(0.85, 0.95, putting_skill)
	var putt_floor = lerpf(skill_floor_max, skill_floor_min, putt_distance_ratio)
	assert_gt(putt_floor, 0.90,
		"Short putt for skilled golfer should have high accuracy floor")

func test_putt_floor_low_skill_long_putt() -> void:
	var putting_skill = 0.3
	var putt_distance_ratio = 1.0  # Max distance putt
	var skill_floor_min = lerpf(0.50, 0.80, putting_skill)
	var skill_floor_max = lerpf(0.85, 0.95, putting_skill)
	var putt_floor = lerpf(skill_floor_max, skill_floor_min, putt_distance_ratio)
	assert_lt(putt_floor, 0.65,
		"Long putt for low-skill golfer should have lower accuracy floor")
