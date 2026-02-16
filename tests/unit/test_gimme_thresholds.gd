extends GutTest
## Tests for gimme distance thresholds - validates putt vs chip-in distances
##
## These tests verify that the gimme distance thresholds are consistent across
## the codebase. The thresholds are now centralized in GolfRules:
## - Tap-in: GolfRules.TAP_IN_DISTANCE (~3 feet) - automatic make in _calculate_putt
## - Chips (shot from off green): GolfRules.CUP_RADIUS (~8 inches) - must land nearly in hole


# --- Threshold Validation Tests ---

func test_tap_in_larger_than_cup_radius() -> void:
	assert_gt(GolfRules.TAP_IN_DISTANCE, GolfRules.CUP_RADIUS,
		"Tap-in distance should be larger than cup radius (easier to make short putts)")

func test_cup_radius_is_very_small() -> void:
	# 0.01 tiles = ~8 inches, which is close to the actual hole diameter (4.25")
	assert_lt(GolfRules.CUP_RADIUS, 0.05,
		"Cup radius should be very small to prevent too many chip-ins")

func test_tap_in_reasonable_distance() -> void:
	# ~3 feet is inside-the-leather gimme range (realistic for casual play)
	assert_gte(GolfRules.TAP_IN_DISTANCE, 0.03, "Tap-in should be at least 0.03 tiles (~2 feet)")
	assert_lte(GolfRules.TAP_IN_DISTANCE, 0.08, "Tap-in should be at most 0.08 tiles (~5 feet)")

func test_hole_manager_cup_radius_matches_golf_rules() -> void:
	assert_eq(HoleManager.CUP_RADIUS, GolfRules.CUP_RADIUS,
		"HoleManager.CUP_RADIUS should match GolfRules.CUP_RADIUS")


# --- Distance Conversion Tests ---

func test_tap_in_in_feet() -> void:
	# 1 tile = 22 yards = 66 feet
	var feet = GolfRules.TAP_IN_DISTANCE * 66.0
	assert_gte(feet, 2.0, "Tap-in should be at least 2 feet")
	assert_lte(feet, 5.0, "Tap-in should be at most 5 feet")

func test_cup_radius_in_inches() -> void:
	# 1 tile = 22 yards = 792 inches
	var inches = GolfRules.CUP_RADIUS * 22.0 * 36.0  # yards to inches
	assert_gte(inches, 6.0, "Cup radius should be at least 6 inches")
	assert_lte(inches, 10.0, "Cup radius should be at most 10 inches")


# --- Behavioral Documentation Tests ---

func test_putt_within_tap_in_snaps_to_hole() -> void:
	var distance = 0.03  # tiles (~2 feet)
	assert_true(distance < GolfRules.TAP_IN_DISTANCE, "Putt at 0.03 tiles should snap to hole")

func test_putt_outside_tap_in_uses_make_rate() -> void:
	var distance = 0.10  # tiles (~7 feet)
	assert_false(distance < GolfRules.TAP_IN_DISTANCE, "Putt at 0.10 tiles should use make-rate model")

func test_chip_very_close_should_hole() -> void:
	var distance = 0.005  # tiles (very close)
	assert_true(distance < GolfRules.CUP_RADIUS, "Chip at 0.005 tiles should be a chip-in")

func test_chip_landing_close_but_not_in_should_not_hole() -> void:
	var distance = 0.02  # tiles (~16 inches from hole center)
	assert_false(distance < GolfRules.CUP_RADIUS, "Chip at 0.02 tiles should NOT be a chip-in")
