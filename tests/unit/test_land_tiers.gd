extends GutTest
## Tests for LandManager parcel tiers and PrebuiltCourses packages


# --- Parcel Tier Defaults ---

func test_parcel_tier_defaults_to_standard() -> void:
	var lm = LandManager.new()
	add_child_autofree(lm)
	# Any parcel not explicitly assigned a tier should be STANDARD
	assert_eq(lm.get_parcel_tier(Vector2i(0, 0)), LandManager.ParcelTier.STANDARD)
	assert_eq(lm.get_parcel_tier(Vector2i(3, 3)), LandManager.ParcelTier.STANDARD)


func test_initialize_parcel_tiers_assigns_premium_and_elite() -> void:
	var lm = LandManager.new()
	add_child_autofree(lm)
	lm.initialize_parcel_tiers(CourseTheme.Type.PARKLAND)

	# PARKLAND layout has Premium at (0,0) and Elite at (5,2)
	assert_eq(lm.get_parcel_tier(Vector2i(0, 0)), LandManager.ParcelTier.PREMIUM)
	assert_eq(lm.get_parcel_tier(Vector2i(5, 2)), LandManager.ParcelTier.ELITE)
	# Center parcels should still be STANDARD
	assert_eq(lm.get_parcel_tier(Vector2i(2, 2)), LandManager.ParcelTier.STANDARD)


# --- Cost Multipliers ---

func test_premium_cost_multiplier() -> void:
	var lm = LandManager.new()
	add_child_autofree(lm)
	lm.initialize_parcel_tiers(CourseTheme.Type.PARKLAND)

	var base = lm.get_parcel_cost()
	var premium_cost = lm.get_parcel_cost(Vector2i(0, 0))
	assert_eq(premium_cost, int(base * 2.5), "Premium should cost 2.5x base")


func test_elite_cost_multiplier() -> void:
	var lm = LandManager.new()
	add_child_autofree(lm)
	lm.initialize_parcel_tiers(CourseTheme.Type.PARKLAND)

	var base = lm.get_parcel_cost()
	var elite_cost = lm.get_parcel_cost(Vector2i(5, 2))
	assert_eq(elite_cost, int(base * 5.0), "Elite should cost 5.0x base")


func test_standard_cost_unchanged() -> void:
	var lm = LandManager.new()
	add_child_autofree(lm)
	lm.initialize_parcel_tiers(CourseTheme.Type.PARKLAND)

	var base = lm.get_parcel_cost()
	var standard_cost = lm.get_parcel_cost(Vector2i(1, 1))
	assert_eq(standard_cost, base, "Standard should cost 1.0x base")


# --- Elite Gating ---

func test_elite_locked_below_50_rep() -> void:
	var lm = LandManager.new()
	add_child_autofree(lm)
	lm.initialize_parcel_tiers(CourseTheme.Type.PARKLAND)

	# Elite is at (5,2) — but first, make it adjacent by owning a neighbor
	lm.owned_parcels[Vector2i(4, 2)] = true
	assert_false(lm.is_parcel_purchasable(Vector2i(5, 2)),
		"Elite should not be purchasable when reputation < 50")


func test_elite_unlocked_at_50_rep() -> void:
	var lm = LandManager.new()
	add_child_autofree(lm)
	lm.initialize_parcel_tiers(CourseTheme.Type.PARKLAND)

	# Simulate reputation reaching 50
	lm._on_reputation_changed(40.0, 50.0)
	assert_true(lm._elite_unlocked, "Elite should unlock at 50+ reputation")

	# Now make it adjacent and check purchasable
	lm.owned_parcels[Vector2i(4, 2)] = true
	assert_true(lm.is_parcel_purchasable(Vector2i(5, 2)),
		"Elite should be purchasable after unlock")


func test_is_parcel_adjacent_ignores_tier_gate() -> void:
	var lm = LandManager.new()
	add_child_autofree(lm)
	lm.initialize_parcel_tiers(CourseTheme.Type.PARKLAND)
	lm.owned_parcels[Vector2i(4, 2)] = true
	# is_parcel_adjacent should return true even for locked elite
	assert_true(lm.is_parcel_adjacent(Vector2i(5, 2)),
		"is_parcel_adjacent should ignore tier gating")


# --- Serialization ---

func test_parcel_tier_serialization() -> void:
	var lm = LandManager.new()
	add_child_autofree(lm)
	lm.initialize_parcel_tiers(CourseTheme.Type.PARKLAND)
	lm._elite_unlocked = true

	var data = lm.serialize()
	assert_true(data.has("parcel_tiers"), "Serialized data should include parcel_tiers")
	assert_true(data.has("elite_unlocked"), "Serialized data should include elite_unlocked")
	assert_true(data.elite_unlocked, "elite_unlocked should be true")

	# Deserialize into a new instance
	var lm2 = LandManager.new()
	add_child_autofree(lm2)
	lm2.deserialize(data)

	assert_eq(lm2.get_parcel_tier(Vector2i(0, 0)), LandManager.ParcelTier.PREMIUM,
		"Deserialized tier should match")
	assert_eq(lm2.get_parcel_tier(Vector2i(5, 2)), LandManager.ParcelTier.ELITE,
		"Deserialized elite tier should match")
	assert_true(lm2._elite_unlocked, "elite_unlocked should persist through save/load")


func test_backward_compatible_deserialize() -> void:
	# Old save data has no tier info
	var old_data = {
		"owned_parcels": [{"x": 2, "y": 2}, {"x": 2, "y": 3}, {"x": 3, "y": 2}, {"x": 3, "y": 3}],
		"total_purchased": 0,
	}
	var lm = LandManager.new()
	add_child_autofree(lm)
	lm.deserialize(old_data)

	# All parcels default to STANDARD
	assert_eq(lm.get_parcel_tier(Vector2i(0, 0)), LandManager.ParcelTier.STANDARD)
	assert_false(lm._elite_unlocked)
	assert_eq(lm.owned_parcels.size(), 4)


# --- Tier Description ---

func test_tier_description_returns_text_for_premium() -> void:
	var lm = LandManager.new()
	add_child_autofree(lm)
	lm.initialize_parcel_tiers(CourseTheme.Type.PARKLAND)

	# Store reference for GameManager lookup
	var prev = GameManager.land_manager
	GameManager.land_manager = lm
	GameManager.current_theme = CourseTheme.Type.PARKLAND

	var desc = lm.get_parcel_tier_description(Vector2i(0, 0))
	assert_true(desc.length() > 0, "Premium parcel should have a description")

	GameManager.land_manager = prev


# --- Package Purchase Checks ---

func test_package_blocked_with_existing_holes() -> void:
	# Create a course with holes
	var prev_course = GameManager.current_course
	GameManager.current_course = GameManager.CourseData.new()
	var hole = GameManager.HoleData.new()
	hole.hole_number = 1
	GameManager.current_course.add_hole(hole)

	var check = PrebuiltCourses.can_purchase(PrebuiltCourses.PackageType.STARTER)
	assert_false(check.can_buy, "Should not be purchasable with existing holes")
	assert_true(check.reason.find("already has holes") >= 0, "Reason should mention existing holes")

	# Restore
	GameManager.current_course = prev_course


func test_package_data_has_required_fields() -> void:
	for pkg_type in PrebuiltCourses.get_all_package_types():
		var data = PrebuiltCourses.get_package_data(pkg_type)
		assert_true(data.has("name"), "Package should have name")
		assert_true(data.has("cost"), "Package should have cost")
		assert_true(data.has("holes"), "Package should have holes")
		assert_true(data.has("pars"), "Package should have pars")
		assert_eq(data.pars.size(), data.holes, "Pars array size should match hole count")


func test_tier_cost_multipliers_exist_for_all_tiers() -> void:
	assert_true(LandManager.TIER_COST_MULTIPLIERS.has(LandManager.ParcelTier.STANDARD))
	assert_true(LandManager.TIER_COST_MULTIPLIERS.has(LandManager.ParcelTier.PREMIUM))
	assert_true(LandManager.TIER_COST_MULTIPLIERS.has(LandManager.ParcelTier.ELITE))
	assert_almost_eq(LandManager.TIER_COST_MULTIPLIERS[LandManager.ParcelTier.STANDARD], 1.0, 0.01)
	assert_almost_eq(LandManager.TIER_COST_MULTIPLIERS[LandManager.ParcelTier.PREMIUM], 2.5, 0.01)
	assert_almost_eq(LandManager.TIER_COST_MULTIPLIERS[LandManager.ParcelTier.ELITE], 5.0, 0.01)


func test_all_themes_have_parcel_layouts() -> void:
	for theme in CourseTheme.get_all_types():
		assert_true(LandManager.PREMIUM_PARCEL_LAYOUTS.has(theme),
			"Theme %s should have a parcel layout" % CourseTheme.get_theme_name(theme))
		var layout = LandManager.PREMIUM_PARCEL_LAYOUTS[theme]
		assert_true(layout.size() >= 4, "Each theme should have at least 4 tier-assigned parcels")
