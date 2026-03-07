extends GutTest
## Tests for SeasonSystem — theme-aware seasonal modifiers, blending, and helpers.

# --- Season Calculation ---

func test_get_season_spring() -> void:
	assert_eq(SeasonSystem.get_season(1), SeasonSystem.Season.SPRING)
	assert_eq(SeasonSystem.get_season(7), SeasonSystem.Season.SPRING)

func test_get_season_summer() -> void:
	assert_eq(SeasonSystem.get_season(8), SeasonSystem.Season.SUMMER)
	assert_eq(SeasonSystem.get_season(14), SeasonSystem.Season.SUMMER)

func test_get_season_fall() -> void:
	assert_eq(SeasonSystem.get_season(15), SeasonSystem.Season.FALL)
	assert_eq(SeasonSystem.get_season(21), SeasonSystem.Season.FALL)

func test_get_season_winter() -> void:
	assert_eq(SeasonSystem.get_season(22), SeasonSystem.Season.WINTER)
	assert_eq(SeasonSystem.get_season(28), SeasonSystem.Season.WINTER)

func test_get_season_wraps_year() -> void:
	assert_eq(SeasonSystem.get_season(29), SeasonSystem.Season.SPRING, "Day 29 = new year Spring")
	assert_eq(SeasonSystem.get_season(56), SeasonSystem.Season.WINTER, "Day 56 = year 2 Winter")

func test_get_day_in_season() -> void:
	assert_eq(SeasonSystem.get_day_in_season(1), 1)
	assert_eq(SeasonSystem.get_day_in_season(7), 7)
	assert_eq(SeasonSystem.get_day_in_season(8), 1, "First day of Summer")
	assert_eq(SeasonSystem.get_day_in_season(14), 7, "Last day of Summer")

func test_get_year() -> void:
	assert_eq(SeasonSystem.get_year(1), 1)
	assert_eq(SeasonSystem.get_year(28), 1)
	assert_eq(SeasonSystem.get_year(29), 2)

# --- Theme-Aware Modifiers (enum keys) ---

func test_spawn_modifier_parkland_matches_original() -> void:
	# Parkland is the default/fallback — should match original global values
	var parkland = CourseTheme.Type.PARKLAND
	assert_almost_eq(SeasonSystem.get_spawn_modifier(SeasonSystem.Season.SPRING, parkland), 0.9, 0.01)
	assert_almost_eq(SeasonSystem.get_spawn_modifier(SeasonSystem.Season.SUMMER, parkland), 1.4, 0.01)
	assert_almost_eq(SeasonSystem.get_spawn_modifier(SeasonSystem.Season.FALL, parkland), 0.8, 0.01)
	assert_almost_eq(SeasonSystem.get_spawn_modifier(SeasonSystem.Season.WINTER, parkland), 0.3, 0.01)

func test_spawn_modifier_desert_inverted() -> void:
	# Desert peaks in winter, low in summer (inverted)
	var desert = CourseTheme.Type.DESERT
	assert_almost_eq(SeasonSystem.get_spawn_modifier(SeasonSystem.Season.WINTER, desert), 1.4, 0.01)
	assert_almost_eq(SeasonSystem.get_spawn_modifier(SeasonSystem.Season.SUMMER, desert), 0.3, 0.01)

func test_spawn_modifier_default_falls_back_to_parkland() -> void:
	# No theme (-1) should fall back to Parkland
	assert_almost_eq(SeasonSystem.get_spawn_modifier(SeasonSystem.Season.SUMMER, -1), 1.4, 0.01)
	assert_almost_eq(SeasonSystem.get_spawn_modifier(SeasonSystem.Season.SUMMER), 1.4, 0.01)

func test_maintenance_modifier_theme_aware() -> void:
	var mountain = CourseTheme.Type.MOUNTAIN
	assert_almost_eq(SeasonSystem.get_maintenance_modifier(SeasonSystem.Season.WINTER, mountain), 1.5, 0.01, "Mountain winter = costly")
	var desert = CourseTheme.Type.DESERT
	assert_almost_eq(SeasonSystem.get_maintenance_modifier(SeasonSystem.Season.SUMMER, desert), 0.6, 0.01, "Desert summer = cheap")

func test_all_themes_have_spawn_modifiers() -> void:
	# Every CourseTheme.Type value should have an entry in the spawn table
	for theme_val in range(10):
		for season in range(4):
			var mod = SeasonSystem.get_spawn_modifier(season, theme_val)
			assert_gt(mod, 0.0, "Theme %d season %d should have positive spawn modifier" % [theme_val, season])
			assert_lt(mod, 5.0, "Theme %d season %d spawn modifier should be reasonable" % [theme_val, season])

func test_all_themes_have_maintenance_modifiers() -> void:
	for theme_val in range(10):
		for season in range(4):
			var mod = SeasonSystem.get_maintenance_modifier(season, theme_val)
			assert_gt(mod, 0.0, "Theme %d season %d should have positive maintenance modifier" % [theme_val, season])

# --- Blending at Season Boundaries ---

func test_blended_spawn_mid_season_equals_raw() -> void:
	# Mid-season days (2-6) should return the raw modifier, no blending
	var parkland = CourseTheme.Type.PARKLAND
	for day_offset in range(1, 6):  # days 2-6 of Spring
		var day = day_offset + 1
		var raw = SeasonSystem.get_spawn_modifier(SeasonSystem.Season.SPRING, parkland)
		var blended = SeasonSystem.get_blended_spawn_modifier(day, parkland)
		assert_almost_eq(blended, raw, 0.001, "Day %d mid-season should equal raw" % day)

func test_blended_spawn_last_day_of_season() -> void:
	# Day 7 (last day of Spring): should blend toward Summer
	var parkland = CourseTheme.Type.PARKLAND
	var spring_mod = SeasonSystem.get_spawn_modifier(SeasonSystem.Season.SPRING, parkland)  # 0.9
	var summer_mod = SeasonSystem.get_spawn_modifier(SeasonSystem.Season.SUMMER, parkland)  # 1.4
	var blended = SeasonSystem.get_blended_spawn_modifier(7, parkland)
	# Should be lerp(0.9, 1.4, 0.34) = 0.9 + 0.5 * 0.34 = 1.07
	var expected = lerpf(spring_mod, summer_mod, SeasonSystem.TRANSITION_BLEND_FACTOR)
	assert_almost_eq(blended, expected, 0.001, "Day 7 should blend Spring toward Summer")
	assert_gt(blended, spring_mod, "Blended should be higher than pure Spring")
	assert_lt(blended, summer_mod, "Blended should be lower than pure Summer")

func test_blended_spawn_first_day_of_season() -> void:
	# Day 8 (first day of Summer): should blend toward Spring (previous)
	var parkland = CourseTheme.Type.PARKLAND
	var summer_mod = SeasonSystem.get_spawn_modifier(SeasonSystem.Season.SUMMER, parkland)  # 1.4
	var spring_mod = SeasonSystem.get_spawn_modifier(SeasonSystem.Season.SPRING, parkland)  # 0.9
	var blended = SeasonSystem.get_blended_spawn_modifier(8, parkland)
	var expected = lerpf(summer_mod, spring_mod, SeasonSystem.TRANSITION_BLEND_FACTOR)
	assert_almost_eq(blended, expected, 0.001, "Day 8 should blend Summer toward Spring")
	assert_lt(blended, summer_mod, "Blended should be lower than pure Summer")
	assert_gt(blended, spring_mod, "Blended should be higher than pure Spring")

func test_blended_maintenance_boundary() -> void:
	# Same blending logic should work for maintenance
	var mountain = CourseTheme.Type.MOUNTAIN
	var fall_mod = SeasonSystem.get_maintenance_modifier(SeasonSystem.Season.FALL, mountain)  # 0.8
	var winter_mod = SeasonSystem.get_maintenance_modifier(SeasonSystem.Season.WINTER, mountain)  # 1.5
	var blended = SeasonSystem.get_blended_maintenance_modifier(21, mountain)  # Day 21 = last day of Fall
	var expected = lerpf(fall_mod, winter_mod, SeasonSystem.TRANSITION_BLEND_FACTOR)
	assert_almost_eq(blended, expected, 0.001, "Day 21 Fall->Winter boundary should blend")

func test_blended_winter_to_spring_wraps() -> void:
	# Day 28 (last day of Winter) should blend toward Spring (wraps around)
	var parkland = CourseTheme.Type.PARKLAND
	var winter_mod = SeasonSystem.get_spawn_modifier(SeasonSystem.Season.WINTER, parkland)  # 0.3
	var spring_mod = SeasonSystem.get_spawn_modifier(SeasonSystem.Season.SPRING, parkland)  # 0.9
	var blended = SeasonSystem.get_blended_spawn_modifier(28, parkland)
	var expected = lerpf(winter_mod, spring_mod, SeasonSystem.TRANSITION_BLEND_FACTOR)
	assert_almost_eq(blended, expected, 0.001, "Day 28 Winter->Spring wrap should blend")

# --- Fee Tolerance ---

func test_fee_tolerance_peak_season() -> void:
	# Parkland Summer (day 10, mid-season): spawn_mod = 1.4, tolerance = clamp(0.5 + 1.4*0.55, 0.7, 1.3)
	var tol = SeasonSystem.get_fee_tolerance(10, CourseTheme.Type.PARKLAND)
	assert_almost_eq(tol, 1.27, 0.01, "Peak summer tolerance should be ~1.27")

func test_fee_tolerance_off_season() -> void:
	# Parkland Winter (day 25, mid-season): spawn_mod = 0.3, tolerance = clamp(0.5 + 0.3*0.55, 0.7, 1.3) = 0.665 -> clamped to 0.7
	var tol = SeasonSystem.get_fee_tolerance(25, CourseTheme.Type.PARKLAND)
	assert_almost_eq(tol, 0.7, 0.01, "Off-season tolerance should clamp to 0.7")

func test_fee_tolerance_range() -> void:
	# Fee tolerance should always be in [0.7, 1.3] for any theme/day combo
	for theme_val in range(10):
		for day in range(1, 29):
			var tol = SeasonSystem.get_fee_tolerance(day, theme_val)
			assert_gte(tol, 0.7, "Theme %d day %d: fee tolerance should be >= 0.7" % [theme_val, day])
			assert_lte(tol, 1.3, "Theme %d day %d: fee tolerance should be <= 1.3" % [theme_val, day])

# --- Tournament Prestige ---

func test_tournament_prestige_themed() -> void:
	# Parkland Fall = 1.2x prestige
	var prestige = SeasonSystem.get_tournament_prestige(17, CourseTheme.Type.PARKLAND)  # Day 17 = Fall day 3
	assert_almost_eq(prestige, 1.2, 0.01)

func test_tournament_prestige_off_season() -> void:
	# Parkland Winter = 0.5x prestige
	var prestige = SeasonSystem.get_tournament_prestige(25, CourseTheme.Type.PARKLAND)
	assert_almost_eq(prestige, 0.5, 0.01)

# --- Weather Modifiers ---

func test_theme_weather_modifiers_desert() -> void:
	var mods = SeasonSystem.get_theme_weather_modifiers(CourseTheme.Type.DESERT)
	assert_almost_eq(mods["wind"], 0.8, 0.01)
	assert_almost_eq(mods["rain"], 0.3, 0.01)

func test_theme_weather_modifiers_links() -> void:
	var mods = SeasonSystem.get_theme_weather_modifiers(CourseTheme.Type.LINKS)
	assert_almost_eq(mods["wind"], 1.5, 0.01)
	assert_almost_eq(mods["rain"], 1.2, 0.01)

func test_theme_weather_modifiers_default_is_standard() -> void:
	var mods = SeasonSystem.get_theme_weather_modifiers(-1)
	assert_almost_eq(mods["wind"], 1.0, 0.01)
	assert_almost_eq(mods["rain"], 1.0, 0.01)

func test_blended_weather_weights_valid_probabilities() -> void:
	# For all themes and days, blended weather weights should be valid cumulative probs
	for theme_val in [0, 1, 2, 8]:  # Parkland, Desert, Links, Tropical
		for day in [4, 7, 8, 14]:  # mid-season, boundary, boundary, mid-season
			var weights = SeasonSystem.get_blended_weather_weights(day, theme_val)
			assert_eq(weights.size(), 6, "Should have 6 weather thresholds")
			assert_gt(weights[0], 0.0, "First threshold should be positive")
			assert_almost_eq(weights[5], 1.0, 0.001, "Last threshold should be 1.0")
			# Should be monotonically increasing
			for i in range(1, weights.size()):
				assert_gte(weights[i], weights[i - 1], "Thresholds should be non-decreasing")

# --- TRANSITION_BLEND_FACTOR constant ---

func test_blend_factor_constant_exists() -> void:
	assert_almost_eq(SeasonSystem.TRANSITION_BLEND_FACTOR, 0.34, 0.001)
