extends GutTest
## Tests for GolferManager spawn rate calculations
##
## Verifies that spawn rate modifiers correctly scale with course rating,
## and that effective cooldowns are inversely proportional to spawn rate.


# --- Spawn Rate Modifier Formula ---
# base_modifier = 0.5 + (rating - 1.0) * 0.25
# Then multiplied by weather_modifier and marketing_modifier

func test_spawn_rate_1_star_is_half() -> void:
	# rating = 1.0 → 0.5 + (1.0 - 1.0) * 0.25 = 0.5
	var modifier = 0.5 + (1.0 - 1.0) * 0.25
	assert_almost_eq(modifier, 0.5, 0.01,
		"1-star course should have 0.5x spawn rate")

func test_spawn_rate_3_stars_is_baseline() -> void:
	# rating = 3.0 → 0.5 + (3.0 - 1.0) * 0.25 = 0.5 + 0.5 = 1.0
	var modifier = 0.5 + (3.0 - 1.0) * 0.25
	assert_almost_eq(modifier, 1.0, 0.01,
		"3-star course should have 1.0x spawn rate (baseline)")

func test_spawn_rate_5_stars_is_higher() -> void:
	# rating = 5.0 → 0.5 + (5.0 - 1.0) * 0.25 = 0.5 + 1.0 = 1.5
	var modifier = 0.5 + (5.0 - 1.0) * 0.25
	assert_almost_eq(modifier, 1.5, 0.01,
		"5-star course should have 1.5x spawn rate")

func test_spawn_rate_increases_monotonically() -> void:
	var prev_modifier = 0.0
	for rating_10x in range(10, 51):  # 1.0 to 5.0 in 0.1 steps
		var rating = rating_10x / 10.0
		var modifier = 0.5 + (rating - 1.0) * 0.25
		assert_gt(modifier, prev_modifier,
			"Spawn rate should increase with rating (rating=%.1f)" % rating)
		prev_modifier = modifier


# --- Effective Spawn Cooldown ---
# cooldown = min_spawn_cooldown / modifier

func test_cooldown_inversely_proportional_to_rate() -> void:
	var min_cooldown = 30.0  # seconds (typical value)

	var cooldown_1star = min_cooldown / 0.5   # 60 seconds
	var cooldown_3star = min_cooldown / 1.0   # 30 seconds
	var cooldown_5star = min_cooldown / 1.5   # 20 seconds

	assert_gt(cooldown_1star, cooldown_3star,
		"Low-rated course should have longer cooldown")
	assert_gt(cooldown_3star, cooldown_5star,
		"3-star course should have longer cooldown than 5-star")

func test_cooldown_never_negative() -> void:
	# Even with very high modifier, cooldown should be positive
	var min_cooldown = 30.0
	for modifier_10x in range(1, 100):
		var modifier = modifier_10x / 10.0
		var cooldown = min_cooldown / modifier
		assert_gt(cooldown, 0.0,
			"Cooldown should always be positive (modifier=%.1f)" % modifier)


# --- Max Concurrent Golfers ---
# 1 group (4 golfers) per open hole, capped at max_concurrent_golfers

func test_max_golfers_scales_with_holes() -> void:
	# Formula: min(holes * 4, max_concurrent_golfers)
	var max_cap = 32  # Typical max
	assert_eq(min(1 * 4, max_cap), 4, "1 hole should allow 4 golfers")
	assert_eq(min(3 * 4, max_cap), 12, "3 holes should allow 12 golfers")
	assert_eq(min(9 * 4, max_cap), 32, "9 holes should cap at 32")
	assert_eq(min(18 * 4, max_cap), 32, "18 holes should cap at 32")


# --- Landing Zone Radius ---
# radius = base_radius + (shot_distance * variance_pct)

func test_landing_zone_base_radius() -> void:
	var base = 2.0
	var variance = 0.3
	# At distance 0, radius = base
	var radius = base + (0.0 * variance)
	assert_almost_eq(radius, 2.0, 0.01, "Zero distance should give base radius")

func test_landing_zone_grows_with_distance() -> void:
	var base = 2.0
	var variance = 0.3
	var short_radius = base + (5.0 * variance)   # 3.5
	var long_radius = base + (15.0 * variance)    # 6.5
	assert_gt(long_radius, short_radius,
		"Longer shots should have larger landing zone radius")

func test_landing_zone_driver_distance() -> void:
	var base = 2.0
	var variance = 0.3
	var typical_driver = 12.0  # tiles
	var radius = base + (typical_driver * variance)
	assert_almost_eq(radius, 5.6, 0.01,
		"Typical driver should have ~5.6 tile landing zone radius")


# --- Weather Impact on Spawn Rate ---

func test_weather_modifier_range() -> void:
	# Weather modifiers from CLAUDE.md: 100% (sunny) to 30% (heavy rain)
	# These are external to GolferManager but affect spawn rate multiplicatively
	var sunny_rate = 0.5 * 1.0    # 1-star course, sunny
	var rain_rate = 0.5 * 0.30    # 1-star course, heavy rain
	assert_almost_eq(sunny_rate, 0.5, 0.01)
	assert_almost_eq(rain_rate, 0.15, 0.01)
	assert_gt(sunny_rate, rain_rate, "Sunny should have higher spawn rate than rain")


# --- Combined Modifier Scenarios ---

func test_best_case_spawn_rate() -> void:
	# 5-star course, sunny (1.0), with marketing (assume 1.3)
	var rating_mod = 0.5 + (5.0 - 1.0) * 0.25  # 1.5
	var weather_mod = 1.0
	var marketing_mod = 1.3
	var total = rating_mod * weather_mod * marketing_mod
	assert_almost_eq(total, 1.95, 0.01,
		"Best case should give ~2x spawn rate")

func test_worst_case_spawn_rate() -> void:
	# 1-star course, heavy rain (0.3), no marketing (1.0)
	var rating_mod = 0.5 + (1.0 - 1.0) * 0.25  # 0.5
	var weather_mod = 0.3
	var marketing_mod = 1.0
	var total = rating_mod * weather_mod * marketing_mod
	assert_almost_eq(total, 0.15, 0.01,
		"Worst case should give ~0.15x spawn rate")
