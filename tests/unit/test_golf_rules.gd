extends GutTest
## Tests for centralized GolfRules system


# =============================================================================
# SCORING
# =============================================================================

func test_score_name_hole_in_one() -> void:
	assert_eq(GolfRules.get_score_name(1, 3), "Hole-in-One")
	assert_eq(GolfRules.get_score_name(1, 4), "Hole-in-One")

func test_score_name_albatross() -> void:
	assert_eq(GolfRules.get_score_name(2, 5), "Albatross")

func test_score_name_eagle() -> void:
	assert_eq(GolfRules.get_score_name(3, 5), "Eagle")
	assert_eq(GolfRules.get_score_name(2, 4), "Eagle")

func test_score_name_birdie() -> void:
	assert_eq(GolfRules.get_score_name(3, 4), "Birdie")
	assert_eq(GolfRules.get_score_name(2, 3), "Birdie")

func test_score_name_par() -> void:
	assert_eq(GolfRules.get_score_name(3, 3), "Par")
	assert_eq(GolfRules.get_score_name(4, 4), "Par")
	assert_eq(GolfRules.get_score_name(5, 5), "Par")

func test_score_name_bogey() -> void:
	assert_eq(GolfRules.get_score_name(5, 4), "Bogey")

func test_score_name_double_bogey() -> void:
	assert_eq(GolfRules.get_score_name(6, 4), "Double Bogey")

func test_score_name_triple_bogey() -> void:
	assert_eq(GolfRules.get_score_name(7, 4), "Triple Bogey")

func test_score_name_high_score() -> void:
	assert_eq(GolfRules.get_score_name(8, 4), "+4")

func test_score_name_very_under_par() -> void:
	# Condor or extreme theoretical case
	assert_eq(GolfRules.get_score_name(1, 5), "Hole-in-One")  # Still hole-in-one


# --- Score Classification ---

func test_classify_hole_in_one() -> void:
	assert_eq(GolfRules.classify_score(1, 3), "hole_in_one")
	assert_eq(GolfRules.classify_score(1, 5), "hole_in_one")

func test_classify_eagle() -> void:
	assert_eq(GolfRules.classify_score(3, 5), "eagle")
	assert_eq(GolfRules.classify_score(2, 4), "eagle")

func test_classify_birdie() -> void:
	assert_eq(GolfRules.classify_score(3, 4), "birdie")

func test_classify_par() -> void:
	assert_eq(GolfRules.classify_score(4, 4), "par")

func test_classify_bogey() -> void:
	assert_eq(GolfRules.classify_score(5, 4), "bogey")

func test_classify_double_bogey_plus() -> void:
	assert_eq(GolfRules.classify_score(6, 4), "double_bogey_plus")
	assert_eq(GolfRules.classify_score(8, 4), "double_bogey_plus")


# =============================================================================
# PAR CALCULATION
# =============================================================================

func test_par_3_short() -> void:
	assert_eq(GolfRules.calculate_par(100), 3)

func test_par_3_boundary() -> void:
	assert_eq(GolfRules.calculate_par(250), 3)

func test_par_4_just_over() -> void:
	assert_eq(GolfRules.calculate_par(251), 4)

func test_par_4_mid() -> void:
	assert_eq(GolfRules.calculate_par(400), 4)

func test_par_4_boundary() -> void:
	assert_eq(GolfRules.calculate_par(470), 4)

func test_par_5_just_over() -> void:
	assert_eq(GolfRules.calculate_par(471), 5)

func test_par_5_long() -> void:
	assert_eq(GolfRules.calculate_par(600), 5)


# =============================================================================
# MAX STROKES (PICKUP)
# =============================================================================

func test_max_strokes_par_3() -> void:
	# Triple bogey on par 3 = 6
	assert_eq(GolfRules.get_max_strokes(3), 6)

func test_max_strokes_par_4() -> void:
	# Triple bogey on par 4 = 7
	assert_eq(GolfRules.get_max_strokes(4), 7)

func test_max_strokes_par_5() -> void:
	# Triple bogey on par 5 = 8
	assert_eq(GolfRules.get_max_strokes(5), 8)


# =============================================================================
# PENALTIES
# =============================================================================

func test_water_penalty_strokes() -> void:
	assert_eq(GolfRules.get_penalty_strokes(TerrainTypes.Type.WATER), 1)

func test_ob_penalty_strokes() -> void:
	assert_eq(GolfRules.get_penalty_strokes(TerrainTypes.Type.OUT_OF_BOUNDS), 1)

func test_fairway_no_penalty() -> void:
	assert_eq(GolfRules.get_penalty_strokes(TerrainTypes.Type.FAIRWAY), 0)

func test_bunker_no_penalty() -> void:
	assert_eq(GolfRules.get_penalty_strokes(TerrainTypes.Type.BUNKER), 0)

func test_flower_bed_no_penalty() -> void:
	assert_eq(GolfRules.get_penalty_strokes(TerrainTypes.Type.FLOWER_BED), 0)


# --- Relief Types ---

func test_water_relief_type() -> void:
	assert_eq(GolfRules.get_relief_type(TerrainTypes.Type.WATER), GolfRules.ReliefType.DROP_AT_ENTRY)

func test_ob_relief_type() -> void:
	assert_eq(GolfRules.get_relief_type(TerrainTypes.Type.OUT_OF_BOUNDS), GolfRules.ReliefType.STROKE_AND_DISTANCE)

func test_flower_bed_relief_type() -> void:
	assert_eq(GolfRules.get_relief_type(TerrainTypes.Type.FLOWER_BED), GolfRules.ReliefType.FREE_RELIEF)

func test_empty_relief_type() -> void:
	assert_eq(GolfRules.get_relief_type(TerrainTypes.Type.EMPTY), GolfRules.ReliefType.FREE_RELIEF)

func test_fairway_no_relief() -> void:
	assert_eq(GolfRules.get_relief_type(TerrainTypes.Type.FAIRWAY), GolfRules.ReliefType.NONE)

func test_bunker_no_relief() -> void:
	assert_eq(GolfRules.get_relief_type(TerrainTypes.Type.BUNKER), GolfRules.ReliefType.NONE)

func test_rough_no_relief() -> void:
	assert_eq(GolfRules.get_relief_type(TerrainTypes.Type.ROUGH), GolfRules.ReliefType.NONE)


# =============================================================================
# HOLING
# =============================================================================

func test_ball_holed_exact() -> void:
	assert_true(GolfRules.is_ball_holed(Vector2(5.0, 5.0), Vector2(5.0, 5.0)))

func test_ball_holed_within_cup() -> void:
	assert_true(GolfRules.is_ball_holed(Vector2(5.005, 5.0), Vector2(5.0, 5.0)))

func test_ball_not_holed_outside_cup() -> void:
	assert_false(GolfRules.is_ball_holed(Vector2(5.02, 5.0), Vector2(5.0, 5.0)))


# =============================================================================
# PUTTING MAKE RATES
# =============================================================================

func test_tap_in_always_makes() -> void:
	assert_eq(GolfRules.get_putt_make_rate(0.03, 0.3), 1.0)
	assert_eq(GolfRules.get_putt_make_rate(0.04, 0.95), 1.0)

func test_pro_make_rate_5_feet() -> void:
	# 5 feet = 0.076 tiles, pro skill = 0.95
	var rate = GolfRules.get_putt_make_rate(0.076, 0.95)
	assert_gt(rate, 0.60, "Pro should make >60% of 5-footers")
	assert_lt(rate, 0.95, "Pro shouldn't make >95% of 5-footers")

func test_beginner_make_rate_5_feet() -> void:
	# 5 feet = 0.076 tiles, beginner = 0.35
	var rate = GolfRules.get_putt_make_rate(0.076, 0.35)
	assert_lt(rate, 0.50, "Beginner should make fewer 5-footers than pro")

func test_make_rate_decreases_with_distance() -> void:
	var rate_5ft = GolfRules.get_putt_make_rate(0.076, 0.7)
	var rate_15ft = GolfRules.get_putt_make_rate(0.23, 0.7)
	var rate_30ft = GolfRules.get_putt_make_rate(0.45, 0.7)
	assert_gt(rate_5ft, rate_15ft, "5-ft rate should be > 15-ft rate")
	assert_gt(rate_15ft, rate_30ft, "15-ft rate should be > 30-ft rate")

func test_make_rate_increases_with_skill() -> void:
	var distance = 0.15  # ~10 feet
	var rate_beginner = GolfRules.get_putt_make_rate(distance, 0.35)
	var rate_casual = GolfRules.get_putt_make_rate(distance, 0.6)
	var rate_pro = GolfRules.get_putt_make_rate(distance, 0.95)
	assert_gt(rate_pro, rate_casual, "Pro should make more 10-footers than casual")
	assert_gt(rate_casual, rate_beginner, "Casual should make more than beginner")

func test_make_rate_never_zero() -> void:
	# Even very long putts for beginners should have a tiny chance
	var rate = GolfRules.get_putt_make_rate(1.5, 0.3)
	assert_gt(rate, 0.0, "Make rate should never be exactly zero")

func test_make_rate_long_putt_very_low() -> void:
	# 50-foot putt for a pro should be very unlikely
	var rate = GolfRules.get_putt_make_rate(0.76, 0.95)
	assert_lt(rate, 0.15, "50-ft putt make rate should be low even for pros")


# --- Miss Characteristics ---

func test_miss_characteristics_short_putt() -> void:
	var chars = GolfRules.get_putt_miss_characteristics(0.076, 0.7)
	assert_gt(chars.distance_std, 0.0, "Distance std should be positive")
	assert_gt(chars.lateral_std, 0.0, "Lateral std should be positive")

func test_miss_distance_increases_with_putt_length() -> void:
	var chars_short = GolfRules.get_putt_miss_characteristics(0.076, 0.7)
	var chars_long = GolfRules.get_putt_miss_characteristics(0.76, 0.7)
	assert_gt(chars_long.distance_std, chars_short.distance_std,
		"Long putts should have more distance error than short putts")

func test_miss_wider_for_lower_skill() -> void:
	var chars_pro = GolfRules.get_putt_miss_characteristics(0.15, 0.95)
	var chars_beginner = GolfRules.get_putt_miss_characteristics(0.15, 0.35)
	assert_gt(chars_beginner.lateral_std, chars_pro.lateral_std,
		"Beginner should have wider lateral miss than pro")


# =============================================================================
# LIE MODIFIERS
# =============================================================================

func test_fairway_perfect_lie() -> void:
	assert_eq(GolfRules.get_lie_modifier(TerrainTypes.Type.FAIRWAY, Golfer.Club.IRON), 1.0)

func test_tee_box_driver_bonus() -> void:
	assert_gt(GolfRules.get_lie_modifier(TerrainTypes.Type.TEE_BOX, Golfer.Club.DRIVER), 1.0,
		"Driver from tee should get slight bonus")

func test_rough_penalty() -> void:
	assert_lt(GolfRules.get_lie_modifier(TerrainTypes.Type.ROUGH, Golfer.Club.IRON), 1.0)

func test_heavy_rough_worse_than_rough() -> void:
	var rough = GolfRules.get_lie_modifier(TerrainTypes.Type.ROUGH, Golfer.Club.IRON)
	var heavy = GolfRules.get_lie_modifier(TerrainTypes.Type.HEAVY_ROUGH, Golfer.Club.IRON)
	assert_lt(heavy, rough, "Heavy rough should be harder than rough")

func test_bunker_wedge_easier() -> void:
	var wedge = GolfRules.get_lie_modifier(TerrainTypes.Type.BUNKER, Golfer.Club.WEDGE)
	var iron = GolfRules.get_lie_modifier(TerrainTypes.Type.BUNKER, Golfer.Club.IRON)
	assert_gt(wedge, iron, "Wedge should be easier from bunker than iron")

func test_trees_very_difficult() -> void:
	assert_lte(GolfRules.get_lie_modifier(TerrainTypes.Type.TREES, Golfer.Club.IRON), 0.3)


# =============================================================================
# TERRAIN DISTANCE MODIFIERS
# =============================================================================

func test_fairway_full_distance() -> void:
	assert_eq(GolfRules.get_terrain_distance_modifier(TerrainTypes.Type.FAIRWAY), 1.0)

func test_rough_distance_loss() -> void:
	assert_lt(GolfRules.get_terrain_distance_modifier(TerrainTypes.Type.ROUGH), 1.0)

func test_trees_heavy_distance_loss() -> void:
	var trees = GolfRules.get_terrain_distance_modifier(TerrainTypes.Type.TREES)
	var rough = GolfRules.get_terrain_distance_modifier(TerrainTypes.Type.ROUGH)
	assert_lt(trees, rough, "Trees should lose more distance than rough")


# =============================================================================
# CLUB WIND SENSITIVITY
# =============================================================================

func test_driver_full_wind() -> void:
	assert_eq(GolfRules.get_club_wind_sensitivity(Golfer.Club.DRIVER), 1.0)

func test_fairway_wood_high_wind() -> void:
	var fw = GolfRules.get_club_wind_sensitivity(Golfer.Club.FAIRWAY_WOOD)
	assert_gt(fw, 0.5, "Fairway wood should have significant wind sensitivity")
	assert_lt(fw, 1.0, "Fairway wood should have less wind than driver")

func test_iron_moderate_wind() -> void:
	var iron = GolfRules.get_club_wind_sensitivity(Golfer.Club.IRON)
	assert_gt(iron, 0.3)
	assert_lt(iron, 0.9)

func test_wedge_low_wind() -> void:
	var wedge = GolfRules.get_club_wind_sensitivity(Golfer.Club.WEDGE)
	assert_gt(wedge, 0.0, "Wedges should have some wind effect")
	assert_lt(wedge, 0.6, "Wedges should have less wind than irons")

func test_putter_no_wind() -> void:
	assert_eq(GolfRules.get_club_wind_sensitivity(Golfer.Club.PUTTER), 0.0)

func test_wind_sensitivity_decreasing_order() -> void:
	var driver = GolfRules.get_club_wind_sensitivity(Golfer.Club.DRIVER)
	var fw = GolfRules.get_club_wind_sensitivity(Golfer.Club.FAIRWAY_WOOD)
	var iron = GolfRules.get_club_wind_sensitivity(Golfer.Club.IRON)
	var wedge = GolfRules.get_club_wind_sensitivity(Golfer.Club.WEDGE)
	var putter = GolfRules.get_club_wind_sensitivity(Golfer.Club.PUTTER)
	assert_gt(driver, fw, "Driver > Fairway Wood")
	assert_gt(fw, iron, "Fairway Wood > Iron")
	assert_gt(iron, wedge, "Iron > Wedge")
	assert_gt(wedge, putter, "Wedge > Putter")
