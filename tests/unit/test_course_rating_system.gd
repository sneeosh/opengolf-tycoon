extends GutTest
## Tests for CourseRatingSystem - Course quality and difficulty calculations


# --- Helper: create a mock CourseData with specified holes ---

func _make_course(holes_config: Array) -> GameManager.CourseData:
	var course = GameManager.CourseData.new()
	for config in holes_config:
		var hole = GameManager.HoleData.new()
		hole.hole_number = config.get("number", 1)
		hole.par = config.get("par", 4)
		hole.is_open = config.get("is_open", true)
		hole.difficulty_rating = config.get("difficulty", 5.0)
		course.add_hole(hole)
	return course

func _make_daily_stats(birdies: int = 0, bogeys: int = 0, eagles: int = 0, hio: int = 0) -> GameManager.DailyStatistics:
	var stats = GameManager.DailyStatistics.new()
	stats.birdies = birdies
	stats.bogeys_or_worse = bogeys
	stats.eagles = eagles
	stats.holes_in_one = hio
	return stats


# --- Design Rating ---

func test_design_rating_no_course() -> void:
	var rating = CourseRatingSystem._calculate_design_rating(null)
	assert_eq(rating, 2.5, "No course should give default 2.5")

func test_design_rating_empty_holes() -> void:
	var course = GameManager.CourseData.new()
	var rating = CourseRatingSystem._calculate_design_rating(course)
	assert_eq(rating, 1.0, "Empty course should give 1.0")

func test_design_rating_all_par_4s() -> void:
	# Only par 4s, 3 holes = base 1.5, no par variety, no hole count bonus
	var course = _make_course([
		{"par": 4}, {"par": 4}, {"par": 4}
	])
	var rating = CourseRatingSystem._calculate_design_rating(course)
	assert_eq(rating, 1.5, "All par 4s, 3 holes = base 1.5 only")

func test_design_rating_with_par_3_bonus() -> void:
	var course = _make_course([
		{"par": 3}, {"par": 4}, {"par": 4}
	])
	var rating = CourseRatingSystem._calculate_design_rating(course)
	# base 1.5 + 0.75 (par 3) = 2.25
	assert_eq(rating, 2.25, "Par 3 adds 0.75 to base 1.5")

func test_design_rating_with_par_3_and_5() -> void:
	var course = _make_course([
		{"par": 3}, {"par": 4}, {"par": 5}
	])
	var rating = CourseRatingSystem._calculate_design_rating(course)
	# base 1.5 + 0.75 (par 3) + 0.75 (par 5) = 3.0
	assert_eq(rating, 3.0, "Par 3 + par 5 adds 1.5 to base 1.5")

func test_design_rating_full_course_with_variety() -> void:
	# 9 holes with par 3, 4, 5 variety
	# base 1.5 + 0.75 (par3) + 0.75 (par5) + 1.5 (9+ holes) = 4.5
	var holes = []
	for i in range(9):
		holes.append({"par": [3, 4, 5][i % 3]})
	var course = _make_course(holes)
	var rating = CourseRatingSystem._calculate_design_rating(course)
	assert_eq(rating, 4.5, "9-hole varied course should get 4.5")

func test_design_rating_18_holes_max() -> void:
	# 18 holes with par 3, 4, 5 variety
	# base 1.5 + 0.75 (par3) + 0.75 (par5) + 2.0 (18+ holes) = 5.0
	var holes = []
	for i in range(18):
		holes.append({"par": [3, 4, 5][i % 3]})
	var course = _make_course(holes)
	var rating = CourseRatingSystem._calculate_design_rating(course)
	assert_eq(rating, 5.0, "Full 18-hole varied course should get max 5.0")

func test_design_rating_ignores_closed_holes() -> void:
	var course = _make_course([
		{"par": 3, "is_open": false}, {"par": 4}, {"par": 5, "is_open": false}
	])
	# Only par 4 is open: base 1.5, no variety
	var rating = CourseRatingSystem._calculate_design_rating(course)
	assert_eq(rating, 1.5, "Closed holes should not count for variety")


# --- Value Rating ---
# Note: Value rating now uses GameManager.get_open_hole_count(), so we set up a course.
# The green_fee parameter is per-hole fee; total = fee * holes.

func _setup_course_with_holes(count: int) -> void:
	"""Helper to set up GameManager with a course having N open holes."""
	var course = GameManager.CourseData.new()
	for i in range(count):
		var hole = GameManager.HoleData.new()
		hole.hole_number = i + 1
		hole.par = 4
		hole.is_open = true
		course.add_hole(hole)
	GameManager.current_course = course

func test_value_rating_fair_price_18_holes() -> void:
	_setup_course_with_holes(18)
	# 18-hole course: per-hole fee $6 (total $108), reputation=50
	# fair_price = max(100, 20) * clamp(18/18, 0.15, 1.0) = 100
	# total_round_cost = 6 * 18 = 108, ratio = 108/100 = 1.08
	# rating = 5.0 - (1.08 - 0.5) * 2.67 = 5.0 - 1.549 = 3.451
	var rating = CourseRatingSystem._calculate_value_rating(6, 50.0)
	assert_almost_eq(rating, 3.45, 0.05, "Fair price 18 holes should give ~3.45 stars")

func test_value_rating_cheap_18_holes() -> void:
	_setup_course_with_holes(18)
	# per-hole fee $2, total = $36, fair = $100, ratio = 0.36
	var rating = CourseRatingSystem._calculate_value_rating(2, 50.0)
	# 5.0 - (0.36 - 0.5)*2.67 = 5.0 + 0.374 = 5.374 -> clamped to 5.0
	assert_eq(rating, 5.0, "Very cheap should clamp to 5.0")

func test_value_rating_expensive_1_hole() -> void:
	_setup_course_with_holes(1)
	# 1-hole course: per-hole fee $15 (max for 1 hole), total = $15
	# fair_price = max(100, 20) * clamp(1/18, 0.15, 1.0) = 100 * 0.15 = 15
	# ratio = 15/15 = 1.0 => 5.0 - (1.0-0.5)*2.67 = 3.665
	var rating = CourseRatingSystem._calculate_value_rating(15, 50.0)
	assert_almost_eq(rating, 3.665, 0.05, "1-hole at max fee should be roughly fair")

func test_value_rating_low_reputation() -> void:
	_setup_course_with_holes(18)
	# reputation=5, fair=max(10, 20)*1.0=20, fee=$1/hole, total=$18
	# ratio = 18/20 = 0.9
	# rating = 5.0 - (0.9 - 0.5)*2.67 = 5.0 - 1.068 = 3.932
	var rating = CourseRatingSystem._calculate_value_rating(1, 5.0)
	assert_almost_eq(rating, 3.93, 0.05, "Low rep with low fee should be slightly above fair")


# --- Pace Rating ---

func test_pace_rating_no_data() -> void:
	var stats = _make_daily_stats()  # all zeros
	var rating = CourseRatingSystem._calculate_pace_rating(stats)
	assert_eq(rating, 3.0, "No scores should give neutral 3.0")

func test_pace_rating_null_stats() -> void:
	var rating = CourseRatingSystem._calculate_pace_rating(null)
	assert_eq(rating, 3.0, "Null stats should give neutral 3.0")

func test_pace_rating_all_birdies() -> void:
	var stats = _make_daily_stats(10, 0)
	var rating = CourseRatingSystem._calculate_pace_rating(stats)
	assert_eq(rating, 5.0, "All birdies = 0% bad ratio = max 5.0")

func test_pace_rating_all_bogeys() -> void:
	var stats = _make_daily_stats(0, 10)
	var rating = CourseRatingSystem._calculate_pace_rating(stats)
	# bad_ratio = 1.0, rating = 5.0 - 6.0 = -1.0 -> clamped to 2.0
	assert_eq(rating, 2.0, "All bogeys should clamp to minimum 2.0")

func test_pace_rating_mixed() -> void:
	var stats = _make_daily_stats(5, 5)
	# bad_ratio = 5/10 = 0.5, rating = 5.0 - 3.0 = 2.0
	var rating = CourseRatingSystem._calculate_pace_rating(stats)
	assert_eq(rating, 2.0, "50% bogey ratio should give 2.0")


# --- Course Difficulty ---

func test_course_difficulty_default_no_course() -> void:
	var result = CourseRatingSystem._calculate_course_difficulty(null)
	assert_eq(result.average, 5.0)
	assert_eq(result.slope, 113)
	assert_eq(result.course_rating, 72.0)

func test_course_difficulty_empty_course() -> void:
	var course = GameManager.CourseData.new()
	var result = CourseRatingSystem._calculate_course_difficulty(course)
	assert_eq(result.average, 5.0, "Empty course defaults to 5.0")

func test_course_difficulty_single_easy_hole() -> void:
	var course = _make_course([{"difficulty": 2.0, "par": 4}])
	var result = CourseRatingSystem._calculate_course_difficulty(course)
	assert_eq(result.average, 2.0, "Single hole with difficulty 2.0")
	# slope = 113 + (2.0-5.0)*8 = 113 - 24 = 89
	assert_eq(result.slope, 89, "Easy course should have low slope")

func test_course_difficulty_hard_course() -> void:
	var course = _make_course([
		{"difficulty": 8.0, "par": 4},
		{"difficulty": 9.0, "par": 5},
	])
	var result = CourseRatingSystem._calculate_course_difficulty(course)
	assert_eq(result.average, 8.5, "Average of 8.0 and 9.0")
	# slope = 113 + (8.5-5.0)*8 = 113 + 28 = 141
	assert_eq(result.slope, 141)

func test_course_difficulty_slope_clamped_low() -> void:
	var course = _make_course([{"difficulty": 1.0, "par": 3}])
	var result = CourseRatingSystem._calculate_course_difficulty(course)
	# slope = 113 + (1.0-5.0)*8 = 113 - 32 = 81
	assert_eq(result.slope, 81)

func test_course_difficulty_slope_clamped_high() -> void:
	var course = _make_course([{"difficulty": 10.0, "par": 5}])
	var result = CourseRatingSystem._calculate_course_difficulty(course)
	# slope = 113 + (10.0-5.0)*8 = 113 + 40 = 153
	assert_eq(result.slope, 153)

func test_course_difficulty_ignores_closed_holes() -> void:
	var course = _make_course([
		{"difficulty": 2.0, "par": 3, "is_open": true},
		{"difficulty": 9.0, "par": 5, "is_open": false},
	])
	var result = CourseRatingSystem._calculate_course_difficulty(course)
	assert_eq(result.average, 2.0, "Should only count open holes")


# --- Prestige Multiplier ---

func test_prestige_multiplier_base() -> void:
	var rating = {"difficulty": 5.0, "overall": 3.0}
	assert_eq(CourseRatingSystem.get_prestige_multiplier(rating), 1.0, "Average course = 1.0x")

func test_prestige_multiplier_hard_and_good() -> void:
	var rating = {"difficulty": 7.0, "overall": 4.0}
	# Hard + good: +0.5
	assert_eq(CourseRatingSystem.get_prestige_multiplier(rating), 1.5)

func test_prestige_multiplier_hard_and_excellent() -> void:
	var rating = {"difficulty": 7.0, "overall": 4.5}
	# Hard + good: +0.5, plus excellent bonus: +0.25
	assert_eq(CourseRatingSystem.get_prestige_multiplier(rating), 1.75)

func test_prestige_multiplier_low_quality() -> void:
	var rating = {"difficulty": 5.0, "overall": 1.5}
	# Low quality: *0.75
	assert_eq(CourseRatingSystem.get_prestige_multiplier(rating), 0.75)


# --- Text Descriptions ---

func test_difficulty_text_easy() -> void:
	assert_eq(CourseRatingSystem.get_difficulty_text(2.0), "Easy")

func test_difficulty_text_moderate() -> void:
	assert_eq(CourseRatingSystem.get_difficulty_text(4.0), "Moderate")

func test_difficulty_text_challenging() -> void:
	assert_eq(CourseRatingSystem.get_difficulty_text(6.0), "Challenging")

func test_difficulty_text_difficult() -> void:
	assert_eq(CourseRatingSystem.get_difficulty_text(8.0), "Difficult")

func test_difficulty_text_very_difficult() -> void:
	assert_eq(CourseRatingSystem.get_difficulty_text(9.5), "Very Difficult")

func test_slope_text_beginner() -> void:
	assert_eq(CourseRatingSystem.get_slope_text(70), "Beginner Friendly")

func test_slope_text_championship() -> void:
	assert_eq(CourseRatingSystem.get_slope_text(150), "Championship")

func test_rating_text_all_stars() -> void:
	assert_eq(CourseRatingSystem.get_rating_text(1), "Poor")
	assert_eq(CourseRatingSystem.get_rating_text(2), "Below Average")
	assert_eq(CourseRatingSystem.get_rating_text(3), "Average")
	assert_eq(CourseRatingSystem.get_rating_text(4), "Good")
	assert_eq(CourseRatingSystem.get_rating_text(5), "Excellent")
	assert_eq(CourseRatingSystem.get_rating_text(0), "Unrated")

func test_star_display() -> void:
	assert_eq(CourseRatingSystem.get_star_display(3.0), "***")
	assert_eq(CourseRatingSystem.get_star_display(3.5), "***+")
	assert_eq(CourseRatingSystem.get_star_display(5.0), "*****")
	assert_eq(CourseRatingSystem.get_star_display(0.0), "")
