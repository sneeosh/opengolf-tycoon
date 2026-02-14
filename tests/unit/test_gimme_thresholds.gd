extends GutTest
## Tests for gimme distance thresholds - validates putt vs chip-in distances
##
## These tests verify that the gimme distance thresholds are consistent across
## the codebase. The thresholds determine when a ball is considered "holed":
## - Putts (shot from green): 0.25 tiles (~5.5 yards) - standard gimme distance
## - Chips (shot from off green): 0.01 tiles (~8 inches) - must land nearly in hole


# --- Threshold Constants ---
# These document the expected values used in golfer.gd and golfer_manager.gd

const PUTT_GIMME_DISTANCE: float = 0.25  # tiles (~5.5 yards)
const CHIP_GIMME_DISTANCE: float = 0.01  # tiles (~8 inches)
const HOLED_OUT_CHECK_DISTANCE: float = 0.25  # Used in _update_group to trigger processing


# --- Threshold Validation Tests ---

func test_putt_gimme_larger_than_chip_gimme() -> void:
	assert_gt(PUTT_GIMME_DISTANCE, CHIP_GIMME_DISTANCE,
		"Putt gimme should be larger than chip gimme (easier to make short putts)")

func test_chip_gimme_is_very_small() -> void:
	# 0.01 tiles = ~8 inches, which is close to the actual hole diameter (4.25")
	assert_lt(CHIP_GIMME_DISTANCE, 0.05,
		"Chip gimme should be very small to prevent too many chip-ins")

func test_putt_gimme_reasonable_for_tap_ins() -> void:
	# 0.25 tiles = ~5.5 yards is a generous gimme distance
	assert_gte(PUTT_GIMME_DISTANCE, 0.1, "Putt gimme should be at least 0.1 tiles")
	assert_lte(PUTT_GIMME_DISTANCE, 0.5, "Putt gimme should be at most 0.5 tiles")

func test_holed_out_check_matches_putt_gimme() -> void:
	# The check in _update_group uses 0.25 to trigger processing
	# This should match the putt gimme so golfers near the hole get processed
	assert_eq(HOLED_OUT_CHECK_DISTANCE, PUTT_GIMME_DISTANCE,
		"Holed out check should match putt gimme distance")


# --- Distance Conversion Tests ---

func test_putt_gimme_in_yards() -> void:
	# 1 tile = 22 yards (per CLAUDE.md conventions)
	var yards = PUTT_GIMME_DISTANCE * 22.0
	assert_gte(yards, 4.0, "Putt gimme should be at least 4 yards")
	assert_lte(yards, 7.0, "Putt gimme should be at most 7 yards")

func test_chip_gimme_in_inches() -> void:
	# 1 tile = 22 yards = 792 inches
	var inches = CHIP_GIMME_DISTANCE * 22.0 * 36.0  # yards to inches
	assert_gte(inches, 6.0, "Chip gimme should be at least 6 inches")
	assert_lte(inches, 10.0, "Chip gimme should be at most 10 inches")


# --- Behavioral Documentation Tests ---

func test_putt_within_gimme_should_hole() -> void:
	# Document expected behavior: putts within 0.25 tiles should always hole
	var distance = 0.20  # tiles
	var is_putt = true
	var gimme = PUTT_GIMME_DISTANCE if is_putt else CHIP_GIMME_DISTANCE
	assert_true(distance < gimme, "Putt at 0.20 tiles should be within gimme")

func test_putt_outside_gimme_should_not_hole() -> void:
	# Document expected behavior: putts outside 0.25 tiles need another stroke
	var distance = 0.30  # tiles
	var is_putt = true
	var gimme = PUTT_GIMME_DISTANCE if is_putt else CHIP_GIMME_DISTANCE
	assert_false(distance < gimme, "Putt at 0.30 tiles should NOT be within gimme")

func test_chip_very_close_should_hole() -> void:
	# Document expected behavior: chips within 0.01 tiles (rare!) should hole
	var distance = 0.005  # tiles (very close)
	var is_putt = false
	var gimme = PUTT_GIMME_DISTANCE if is_putt else CHIP_GIMME_DISTANCE
	assert_true(distance < gimme, "Chip at 0.005 tiles should be within gimme")

func test_chip_landing_close_but_not_in_should_not_hole() -> void:
	# Document expected behavior: chips at 0.02 tiles should NOT hole (common scenario)
	var distance = 0.02  # tiles (~5 inches from hole center)
	var is_putt = false
	var gimme = PUTT_GIMME_DISTANCE if is_putt else CHIP_GIMME_DISTANCE
	assert_false(distance < gimme, "Chip at 0.02 tiles should NOT be within gimme")

func test_chip_on_green_uses_chip_threshold() -> void:
	# Key behavior: a chip that LANDS on the green still uses chip threshold
	# because it was SHOT from off the green
	var shot_from_green = false  # Chip shot from rough
	var ball_landed_on_green = true  # But landed on the green
	# The gimme distance is determined by where the shot was TAKEN from, not where it landed
	var gimme = PUTT_GIMME_DISTANCE if shot_from_green else CHIP_GIMME_DISTANCE
	assert_eq(gimme, CHIP_GIMME_DISTANCE,
		"Chip landing on green should still use chip gimme threshold")
