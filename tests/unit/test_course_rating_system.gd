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
	# Only par 4s = base 2.0, no variety bonus
	var course = _make_course([
		{"par": 4}, {"par": 4}, {"par": 4}
	])
	var rating = CourseRatingSystem._calculate_design_rating(course)
	assert_eq(rating, 2.0, "All par 4s = base 2.0 only")

func test_design_rating_with_par_3_bonus() -> void:
	var course = _make_course([
		{"par": 3}, {"par": 4}, {"par": 4}
	])
	var rating = CourseRatingSystem._calculate_design_rating(course)
	assert_eq(rating, 3.0, "Par 3 adds 1.0 to base 2.0")

func test_design_rating_with_par_3_and_5() -> void:
	var course = _make_course([
		{"par": 3}, {"par": 4}, {"par": 5}
	])
	var rating = CourseRatingSystem._calculate_design_rating(course)
	assert_eq(rating, 4.0, "Par 3 + par 5 adds 2.0 to base 2.0")

func test_design_rating_full_course_with_variety() -> void:
	# 9+ holes with par 3, 4, 5 variety = base 2 + 1 (par3) + 1 (par5) + 1 (9+holes) = 5.0
	var holes = []
	for i in range(9):
		holes.append({"par": [3, 4, 5][i % 3]})
	var course = _make_course(holes)
	var rating = CourseRatingSystem._calculate_design_rating(course)
	assert_eq(rating, 5.0, "Full varied course should get max 5.0")

func test_design_rating_ignores_closed_holes() -> void:
	var course = _make_course([
		{"par": 3, "is_open": false}, {"par": 4}, {"par": 5, "is_open": false}
	])
	# Only par 4 is open: base 2.0, no variety
	var rating = CourseRatingSystem._calculate_design_rating(course)
	assert_eq(rating, 2.0, "Closed holes should not count for variety")


# --- Value Rating ---

func test_value_rating_fair_price() -> void:
	# reputation=50, fair_price = max(50*2, 20) = 100
	# green_fee=100: ratio=1.0 => 5.0 - (1.0-0.5)*2.67 = 5.0 - 1.335 = 3.665
	var rating = CourseRatingSystem._calculate_value_rating(100, 50.0)
	assert_almost_eq(rating, 3.665, 0.01, "Fair price should give ~3.67 stars")

func test_value_rating_cheap() -> void:
	# reputation=50, fair=100, fee=30 => ratio=0.3
	var rating = CourseRatingSystem._calculate_value_rating(30, 50.0)
	# 5.0 - (0.3 - 0.5)*2.67 = 5.0 + 0.534 = 5.534 -> clamped to 5.0
	assert_eq(rating, 5.0, "Very cheap should clamp to 5.0")

func test_value_rating_expensive() -> void:
	# reputation=50, fair=100, fee=200 => ratio=2.0
	var rating = CourseRatingSystem._calculate_value_rating(200, 50.0)
	# 5.0 - (2.0 - 0.5)*2.67 = 5.0 - 4.005 = 0.995 -> clamped to 1.0
	assert_eq(rating, 1.0, "Very expensive should clamp to 1.0")

func test_value_rating_low_reputation() -> void:
	# reputation=5, fair=max(5*2, 20)=20, fee=20 => ratio=1.0
	var rating = CourseRatingSystem._calculate_value_rating(20, 5.0)
	assert_almost_eq(rating, 3.665, 0.01, "Low rep with matching low fee should be ~fair")


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
