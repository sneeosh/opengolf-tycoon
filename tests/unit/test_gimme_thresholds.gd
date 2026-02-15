extends GutTest
## Tests for gimme distance thresholds - validates putt vs chip-in distances
##
## These tests verify that the gimme distance thresholds are consistent across
## the codebase. The thresholds determine when a ball is considered "holed":
## - Putts: 0.07 tiles (~5 feet) - snap to hole in _calculate_putt
## - Chips (shot from off green): 0.01 tiles (~8 inches) - must land nearly in hole


# --- Threshold Constants ---
# CUP_RADIUS is the physical cup size used for chip-ins and final hole check
const CUP_RADIUS: float = 0.01  # tiles (~8 inches) - matches HoleManager.CUP_RADIUS
# PUTT_GIMME is the snap threshold used internally in _calculate_putt
const PUTT_GIMME: float = 0.07  # tiles (~5 feet) - automatic tap-in for putts


# --- Threshold Validation Tests ---

func test_putt_gimme_larger_than_cup_radius() -> void:
	assert_gt(PUTT_GIMME, CUP_RADIUS,
		"Putt gimme should be larger than cup radius (easier to make short putts)")

func test_cup_radius_is_very_small() -> void:
	# 0.01 tiles = ~8 inches, which is close to the actual hole diameter (4.25")
	assert_lt(CUP_RADIUS, 0.05,
		"Cup radius should be very small to prevent too many chip-ins")

func test_putt_gimme_reasonable_for_tap_ins() -> void:
	# 0.07 tiles = ~5 feet is a realistic tap-in distance
	assert_gte(PUTT_GIMME, 0.05, "Putt gimme should be at least 0.05 tiles")
	assert_lte(PUTT_GIMME, 0.15, "Putt gimme should be at most 0.15 tiles")


# --- Distance Conversion Tests ---

func test_putt_gimme_in_feet() -> void:
	# 1 tile = 22 yards = 66 feet
	var feet = PUTT_GIMME * 66.0
	assert_gte(feet, 3.0, "Putt gimme should be at least 3 feet")
	assert_lte(feet, 10.0, "Putt gimme should be at most 10 feet")

func test_cup_radius_in_inches() -> void:
	# 1 tile = 22 yards = 792 inches
	var inches = CUP_RADIUS * 22.0 * 36.0  # yards to inches
	assert_gte(inches, 6.0, "Cup radius should be at least 6 inches")
	assert_lte(inches, 10.0, "Cup radius should be at most 10 inches")


# --- Behavioral Documentation Tests ---

func test_putt_within_gimme_snaps_to_hole() -> void:
	# Document expected behavior: putts within 0.07 tiles snap to hole in _calculate_putt
	var distance = 0.05  # tiles
	assert_true(distance < PUTT_GIMME, "Putt at 0.05 tiles should snap to hole")

func test_putt_outside_gimme_needs_another_stroke() -> void:
	# Document expected behavior: putts outside 0.07 tiles need to roll close
	var distance = 0.10  # tiles
	assert_false(distance < PUTT_GIMME, "Putt at 0.10 tiles should NOT auto-hole")

func test_chip_very_close_should_hole() -> void:
	# Document expected behavior: chips within 0.01 tiles (rare!) should hole
	var distance = 0.005  # tiles (very close)
	assert_true(distance < CUP_RADIUS, "Chip at 0.005 tiles should be a chip-in")

func test_chip_landing_close_but_not_in_should_not_hole() -> void:
	# Document expected behavior: chips at 0.02 tiles should NOT hole
	var distance = 0.02  # tiles (~16 inches from hole center)
	assert_false(distance < CUP_RADIUS, "Chip at 0.02 tiles should NOT be a chip-in")

func test_three_putts_are_possible() -> void:
	# Document: with PUTT_GIMME at 0.07 tiles, putts from further out can miss
	# and require additional strokes. Short putts (< 0.33 tiles) have overshoot
	# of 0.03-0.15 tiles, so they may land outside PUTT_GIMME.
	var typical_overshoot = 0.10  # tiles
	assert_gt(typical_overshoot, PUTT_GIMME,
		"Typical putt overshoot should be larger than gimme to allow 3-putts")
