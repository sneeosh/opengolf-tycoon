extends GutTest
## Tests for GolferTier - Golfer skill tier selection and characteristics


# --- Tier Data Validation ---

func test_tier_data_has_all_tiers() -> void:
	assert_true(GolferTier.TIER_DATA.has(GolferTier.Tier.BEGINNER))
	assert_true(GolferTier.TIER_DATA.has(GolferTier.Tier.CASUAL))
	assert_true(GolferTier.TIER_DATA.has(GolferTier.Tier.SERIOUS))
	assert_true(GolferTier.TIER_DATA.has(GolferTier.Tier.PRO))

func test_tier_skill_ranges_ordered() -> void:
	var beginner = GolferTier.TIER_DATA[GolferTier.Tier.BEGINNER].skill_range
	var casual = GolferTier.TIER_DATA[GolferTier.Tier.CASUAL].skill_range
	var serious = GolferTier.TIER_DATA[GolferTier.Tier.SERIOUS].skill_range
	var pro = GolferTier.TIER_DATA[GolferTier.Tier.PRO].skill_range

	assert_lt(beginner[0], casual[0], "Beginner min < Casual min")
	assert_lt(casual[0], serious[0], "Casual min < Serious min")
	assert_lt(serious[0], pro[0], "Serious min < Pro min")

func test_tier_skill_ranges_valid() -> void:
	for tier in GolferTier.TIER_DATA.keys():
		var data = GolferTier.TIER_DATA[tier]
		assert_lt(data.skill_range[0], data.skill_range[1],
			"Skill range min should be less than max for tier %d" % tier)
		assert_gte(data.skill_range[0], 0.0, "Min skill should be >= 0")
		assert_lte(data.skill_range[1], 1.0, "Max skill should be <= 1")

func test_tier_reputation_gains_increase() -> void:
	var bg = GolferTier.TIER_DATA[GolferTier.Tier.BEGINNER].reputation_gain
	var ca = GolferTier.TIER_DATA[GolferTier.Tier.CASUAL].reputation_gain
	var sr = GolferTier.TIER_DATA[GolferTier.Tier.SERIOUS].reputation_gain
	var pr = GolferTier.TIER_DATA[GolferTier.Tier.PRO].reputation_gain

	assert_lt(bg, ca, "Beginner rep gain < Casual")
	assert_lt(ca, sr, "Casual rep gain < Serious")
	assert_lt(sr, pr, "Serious rep gain < Pro")


# --- Tier Weight Calculations ---

func test_weights_low_rating_penalizes_high_tiers() -> void:
	var rating_data = {"overall": 1.5, "difficulty": 5.0}
	var weights = GolferTier._calculate_tier_weights(rating_data, 30, 50.0)

	# Pro requires min 4.0 rating, serious requires 3.0
	# Both should have drastically reduced weights (multiplied by 0.1)
	var beginner_w = weights[GolferTier.Tier.BEGINNER]
	var pro_w = weights[GolferTier.Tier.PRO]

	assert_gt(beginner_w, pro_w, "Beginners should be more common at low-rated courses")

func test_weights_high_rating_allows_all_tiers() -> void:
	var rating_data = {"overall": 4.5, "difficulty": 5.0}
	var weights = GolferTier._calculate_tier_weights(rating_data, 50, 80.0)

	# All tiers should have non-zero weights
	for tier in weights:
		assert_gt(weights[tier], 0.0, "Tier %d should have positive weight at high-rated course" % tier)

func test_weights_expensive_fee_reduces_beginners() -> void:
	var rating_data = {"overall": 4.0, "difficulty": 5.0}
	var cheap_weights = GolferTier._calculate_tier_weights(rating_data, 20, 80.0)
	var expensive_weights = GolferTier._calculate_tier_weights(rating_data, 150, 80.0)

	# Beginners have spending_modifier 0.7, so $150 fee / $50 = 3.0, which is > 0.7*1.5=1.05
	# This should trigger the "too expensive" penalty (0.3x)
	assert_gt(
		cheap_weights[GolferTier.Tier.BEGINNER],
		expensive_weights[GolferTier.Tier.BEGINNER],
		"Expensive fee should reduce beginner weight"
	)

func test_weights_low_reputation_reduces_pro() -> void:
	var rating_data = {"overall": 4.0, "difficulty": 5.0}
	var low_rep = GolferTier._calculate_tier_weights(rating_data, 50, 30.0)
	var high_rep = GolferTier._calculate_tier_weights(rating_data, 50, 90.0)

	assert_gt(
		high_rep[GolferTier.Tier.PRO],
		low_rep[GolferTier.Tier.PRO],
		"Low reputation should reduce pro weight"
	)

func test_weights_hard_course_attracts_pros() -> void:
	var easy = {"overall": 4.0, "difficulty": 2.0}
	var hard = {"overall": 4.0, "difficulty": 8.0}
	var easy_weights = GolferTier._calculate_tier_weights(easy, 50, 80.0)
	var hard_weights = GolferTier._calculate_tier_weights(hard, 50, 80.0)

	assert_gt(
		hard_weights[GolferTier.Tier.PRO],
		easy_weights[GolferTier.Tier.PRO],
		"Hard course should attract more pros"
	)

func test_weights_easy_course_attracts_beginners() -> void:
	var easy = {"overall": 3.0, "difficulty": 2.0}
	var hard = {"overall": 3.0, "difficulty": 8.0}
	var easy_weights = GolferTier._calculate_tier_weights(easy, 30, 50.0)
	var hard_weights = GolferTier._calculate_tier_weights(hard, 30, 50.0)

	assert_gt(
		easy_weights[GolferTier.Tier.BEGINNER],
		hard_weights[GolferTier.Tier.BEGINNER],
		"Easy course should attract more beginners"
	)

func test_weights_legacy_float_rating() -> void:
	# Legacy code path: passing a float instead of Dictionary
	var weights = GolferTier._calculate_tier_weights(3.0, 50, 50.0)
	var total = 0.0
	for w in weights.values():
		total += w
	assert_gt(total, 0.0, "Legacy float rating should produce valid weights")


# --- Tier Selection ---

func test_select_tier_returns_valid_tier() -> void:
	var rating_data = {"overall": 3.0, "difficulty": 5.0}
	for _i in range(20):
		var tier = GolferTier.select_tier(rating_data, 50, 50.0)
		assert_true(
			tier in [GolferTier.Tier.BEGINNER, GolferTier.Tier.CASUAL,
					 GolferTier.Tier.SERIOUS, GolferTier.Tier.PRO],
			"Selected tier should be a valid tier enum"
		)


# --- Skill Generation ---

func test_generate_skills_within_range() -> void:
	for tier in GolferTier.TIER_DATA.keys():
		var data = GolferTier.TIER_DATA[tier]
		var skills = GolferTier.generate_skills(tier)

		assert_true(skills.has("driving"), "Should have driving skill")
		assert_true(skills.has("accuracy"), "Should have accuracy skill")
		assert_true(skills.has("putting"), "Should have putting skill")
		assert_true(skills.has("recovery"), "Should have recovery skill")
		assert_true(skills.has("miss_tendency"), "Should have miss_tendency")

		for skill_name in ["driving", "accuracy", "putting", "recovery"]:
			assert_gte(skills[skill_name], data.skill_range[0],
				"%s skill for tier %d should be >= min" % [skill_name, tier])
			assert_lte(skills[skill_name], data.skill_range[1],
				"%s skill for tier %d should be <= max" % [skill_name, tier])

func test_generate_skills_miss_tendency_within_range() -> void:
	for tier in GolferTier.TIER_DATA.keys():
		var data = GolferTier.TIER_DATA[tier]
		var tendency_range = data.tendency_range
		for _i in range(10):
			var skills = GolferTier.generate_skills(tier)
			var tendency = skills.miss_tendency
			# Magnitude should be within tendency_range, sign can be positive or negative
			assert_gte(absf(tendency), tendency_range[0],
				"miss_tendency magnitude for tier %d should be >= min" % tier)
			assert_lte(absf(tendency), tendency_range[1],
				"miss_tendency magnitude for tier %d should be <= max" % tier)


# --- Tier Utility Functions ---

func test_get_tier_name() -> void:
	assert_eq(GolferTier.get_tier_name(GolferTier.Tier.BEGINNER), "Beginner")
	assert_eq(GolferTier.get_tier_name(GolferTier.Tier.CASUAL), "Casual")
	assert_eq(GolferTier.get_tier_name(GolferTier.Tier.SERIOUS), "Serious")
	assert_eq(GolferTier.get_tier_name(GolferTier.Tier.PRO), "Pro")

func test_get_reputation_gain() -> void:
	assert_eq(GolferTier.get_reputation_gain(GolferTier.Tier.BEGINNER), 1)
	assert_eq(GolferTier.get_reputation_gain(GolferTier.Tier.CASUAL), 2)
	assert_eq(GolferTier.get_reputation_gain(GolferTier.Tier.SERIOUS), 4)
	assert_eq(GolferTier.get_reputation_gain(GolferTier.Tier.PRO), 10)

func test_get_price_tolerance() -> void:
	# Beginners are most forgiving, pros are least
	var bg = GolferTier.get_price_tolerance(GolferTier.Tier.BEGINNER)
	var pr = GolferTier.get_price_tolerance(GolferTier.Tier.PRO)
	assert_gt(bg, pr, "Beginners should have higher price tolerance than pros")

func test_get_personality_has_keys() -> void:
	for tier in GolferTier.TIER_DATA.keys():
		var personality = GolferTier.get_personality(tier)
		assert_true(personality.has("aggression"), "Should have aggression for tier %d" % tier)
		assert_true(personality.has("patience"), "Should have patience for tier %d" % tier)

func test_get_name_prefix_not_empty() -> void:
	for tier in GolferTier.TIER_DATA.keys():
		var prefix = GolferTier.get_name_prefix(tier)
		assert_ne(prefix, "", "Name prefix should not be empty for tier %d" % tier)
