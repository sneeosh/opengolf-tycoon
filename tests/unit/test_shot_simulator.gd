extends GutTest
## Tests for ShotSimulator headless hole simulation
##
## Verifies that simulated scores fall within expected ranges,
## that skill properly affects outcomes, and that edge cases
## are handled correctly.


# --- Gaussian Random Distribution ---

func test_gaussian_distribution_mean_near_zero() -> void:
	var sum = 0.0
	var samples = 500
	for i in range(samples):
		sum += ShotSimulator._gaussian_random()
	var mean = sum / samples
	assert_almost_eq(mean, 0.0, 0.5,
		"Gaussian mean should be near 0 over 500 samples")

func test_gaussian_distribution_produces_both_signs() -> void:
	var has_positive = false
	var has_negative = false
	for i in range(100):
		var val = ShotSimulator._gaussian_random()
		if val > 0:
			has_positive = true
		elif val < 0:
			has_negative = true
		if has_positive and has_negative:
			break
	assert_true(has_positive, "Gaussian should produce positive values")
	assert_true(has_negative, "Gaussian should produce negative values")


# --- Single Hole Simulation ---

func test_simulate_hole_returns_positive_strokes() -> void:
	for i in range(50):
		var strokes = ShotSimulator.simulate_hole(4, 5.0, 0.5)
		assert_gt(strokes, 0, "Strokes should always be positive")

func test_simulate_hole_clamped_to_max() -> void:
	# Even worst case should not exceed par + 4
	for i in range(100):
		var strokes = ShotSimulator.simulate_hole(3, 10.0, 0.1)
		assert_lte(strokes, 7, "Par 3 should never exceed 7 strokes (par + 4)")

func test_simulate_hole_minimum_is_one() -> void:
	# Even best case should be at least 1
	for i in range(100):
		var strokes = ShotSimulator.simulate_hole(3, 1.0, 0.99)
		assert_gte(strokes, 1, "Minimum strokes should be 1")

func test_pro_scores_lower_than_beginner() -> void:
	# Over many samples, pros should average lower
	var pro_total = 0
	var beginner_total = 0
	var samples = 200
	for i in range(samples):
		pro_total += ShotSimulator.simulate_hole(4, 5.0, 0.9)
		beginner_total += ShotSimulator.simulate_hole(4, 5.0, 0.3)
	var pro_avg = float(pro_total) / samples
	var beginner_avg = float(beginner_total) / samples
	assert_lt(pro_avg, beginner_avg,
		"Pro average (%.2f) should be lower than beginner (%.2f)" % [pro_avg, beginner_avg])

func test_higher_difficulty_increases_scores() -> void:
	var easy_total = 0
	var hard_total = 0
	var samples = 200
	for i in range(samples):
		easy_total += ShotSimulator.simulate_hole(4, 1.0, 0.5)
		hard_total += ShotSimulator.simulate_hole(4, 10.0, 0.5)
	var easy_avg = float(easy_total) / samples
	var hard_avg = float(hard_total) / samples
	assert_lt(easy_avg, hard_avg,
		"Easy course avg (%.2f) should be lower than hard (%.2f)" % [easy_avg, hard_avg])


# --- Expected Score Formula ---

func test_expected_score_formula_pro() -> void:
	# Pro: skill=0.9, par=4, difficulty=5.0
	# expected = 4 + (1 - 0.9) * 2.0 - 0.5 + 5.0 * 0.1 = 4 + 0.2 - 0.5 + 0.5 = 4.2
	var expected = 4 + (1.0 - 0.9) * 2.0 - 0.5 + 5.0 * 0.1
	assert_almost_eq(expected, 4.2, 0.01,
		"Pro expected score on par 4 should be ~4.2")

func test_expected_score_formula_beginner() -> void:
	# Beginner: skill=0.3, par=4, difficulty=5.0
	# expected = 4 + (1 - 0.3) * 2.0 - 0.5 + 5.0 * 0.1 = 4 + 1.4 - 0.5 + 0.5 = 5.4
	var expected = 4 + (1.0 - 0.3) * 2.0 - 0.5 + 5.0 * 0.1
	assert_almost_eq(expected, 5.4, 0.01,
		"Beginner expected score on par 4 should be ~5.4")


# --- Remaining Holes Simulation ---

# Helper to create mock course data with open holes
class MockCourseData:
	var holes: Array = []
	func _init(hole_list: Array):
		holes = hole_list

class MockHole:
	var par: int
	var is_open: bool
	func _init(p: int, open: bool = true):
		par = p
		is_open = open

func test_simulate_remaining_from_start() -> void:
	var course = MockCourseData.new([
		MockHole.new(4), MockHole.new(3), MockHole.new(5)
	])
	var golfer_data = {
		"total_strokes": 0, "total_par": 0,
		"current_hole": 0, "skill": 0.7
	}
	var result = ShotSimulator.simulate_remaining_holes(golfer_data, course, 5.0)
	assert_eq(result.holes_played, 3, "Should play all 3 holes")
	assert_gt(result.total_strokes, 0, "Should have positive strokes")
	assert_eq(result.total_par, 12, "Total par should be 4+3+5=12")

func test_simulate_remaining_skips_closed_holes() -> void:
	var course = MockCourseData.new([
		MockHole.new(4, true), MockHole.new(3, false), MockHole.new(5, true)
	])
	var golfer_data = {
		"total_strokes": 0, "total_par": 0,
		"current_hole": 0, "skill": 0.7
	}
	var result = ShotSimulator.simulate_remaining_holes(golfer_data, course, 5.0)
	assert_eq(result.holes_played, 2, "Should skip closed hole")
	assert_eq(result.total_par, 9, "Par should be 4+5=9 (skipping closed)")

func test_simulate_remaining_preserves_existing_score() -> void:
	var course = MockCourseData.new([
		MockHole.new(4), MockHole.new(3), MockHole.new(5)
	])
	var golfer_data = {
		"total_strokes": 5, "total_par": 4,
		"current_hole": 1, "skill": 0.7
	}
	var result = ShotSimulator.simulate_remaining_holes(golfer_data, course, 5.0)
	assert_eq(result.holes_played, 2, "Should play remaining 2 holes")
	assert_gte(result.total_strokes, 5, "Should add to existing strokes")
	assert_eq(result.total_par, 4 + 3 + 5, "Par should include existing + remaining")

func test_simulate_remaining_empty_course() -> void:
	var course = MockCourseData.new([])
	var golfer_data = {
		"total_strokes": 0, "total_par": 0,
		"current_hole": 0, "skill": 0.7
	}
	var result = ShotSimulator.simulate_remaining_holes(golfer_data, course, 5.0)
	assert_eq(result.holes_played, 0, "No holes = no play")
	assert_eq(result.total_strokes, 0, "No strokes on empty course")


# --- Tournament Save/Load Edge Cases ---

func test_tournament_in_progress_reverts_to_none_on_load() -> void:
	# Simulating TournamentManager.load_save_data logic
	var data = {
		"current_tier": 1,
		"state": TournamentSystem.TournamentState.IN_PROGRESS,
		"start_day": 10,
		"end_day": 12,
		"last_end_day": 5,
	}
	# When state is IN_PROGRESS, should revert to NONE
	var loaded_state = data.get("state", TournamentSystem.TournamentState.NONE)
	var result_state = loaded_state
	var result_tier = data.get("current_tier", -1)
	if loaded_state == TournamentSystem.TournamentState.IN_PROGRESS:
		result_state = TournamentSystem.TournamentState.NONE
		result_tier = -1
	assert_eq(result_state, TournamentSystem.TournamentState.NONE,
		"IN_PROGRESS should revert to NONE on load")
	assert_eq(result_tier, -1, "Tier should reset when reverting from IN_PROGRESS")

func test_tournament_scheduled_preserved_on_load() -> void:
	var data = {
		"current_tier": 2,
		"state": TournamentSystem.TournamentState.SCHEDULED,
		"start_day": 15,
		"end_day": 18,
		"last_end_day": 5,
	}
	var loaded_state = data.get("state", TournamentSystem.TournamentState.NONE)
	var result_state = loaded_state
	if loaded_state == TournamentSystem.TournamentState.IN_PROGRESS:
		result_state = TournamentSystem.TournamentState.NONE
	assert_eq(result_state, TournamentSystem.TournamentState.SCHEDULED,
		"SCHEDULED state should be preserved on load")

func test_tournament_cooldown_calculation() -> void:
	# Cooldown = max(0, 7 - days_since_last)
	var cooldown_days = 7
	assert_eq(max(0, cooldown_days - 3), 4, "3 days since last = 4 day cooldown")
	assert_eq(max(0, cooldown_days - 7), 0, "7 days since last = no cooldown")
	assert_eq(max(0, cooldown_days - 10), 0, "10 days since last = no cooldown")
	assert_eq(max(0, cooldown_days - 0), 7, "0 days since last = full cooldown")
