extends GutTest
## Tests for GameManager - Core game state management

# We test GameManager as an autoload singleton, so we access it directly.
# GUT runs inside the Godot engine with the project's autoloads active.


# --- Money & Bankruptcy ---

func test_modify_money_adds_positive_amount() -> void:
	var before = GameManager.money
	GameManager.modify_money(100)
	assert_eq(GameManager.money, before + 100, "Money should increase by 100")
	# Restore
	GameManager.modify_money(-100)

func test_modify_money_subtracts_negative_amount() -> void:
	var before = GameManager.money
	GameManager.modify_money(-50)
	assert_eq(GameManager.money, before - 50, "Money should decrease by 50")
	# Restore
	GameManager.modify_money(50)

func test_can_afford_returns_true_for_affordable_cost() -> void:
	GameManager.money = 10000
	assert_true(GameManager.can_afford(5000), "Should afford 5000 with 10000")

func test_can_afford_returns_true_when_cost_dips_into_negative() -> void:
	GameManager.money = 500
	# Bankruptcy threshold is -1000, so 500 - 1400 = -900 >= -1000
	assert_true(GameManager.can_afford(1400), "Should allow spending that keeps above bankruptcy threshold")

func test_can_afford_returns_false_when_below_bankruptcy() -> void:
	GameManager.money = 500
	# 500 - 1600 = -1100 < -1000 (BANKRUPTCY_THRESHOLD)
	assert_false(GameManager.can_afford(1600), "Should reject spending below bankruptcy threshold")

func test_can_afford_returns_true_for_zero_cost() -> void:
	GameManager.money = 100
	assert_true(GameManager.can_afford(0), "Zero cost should always be affordable")

func test_can_afford_returns_true_for_negative_cost() -> void:
	# Negative cost means gaining money (not a purchase)
	GameManager.money = -5000
	assert_true(GameManager.can_afford(-100), "Negative cost (income) should always be true")

func test_is_bankrupt_when_below_threshold() -> void:
	GameManager.money = -1001
	assert_true(GameManager.is_bankrupt(), "Should be bankrupt below -1000")

func test_is_not_bankrupt_above_threshold() -> void:
	GameManager.money = -999
	assert_false(GameManager.is_bankrupt(), "Should not be bankrupt above threshold")

func test_is_not_bankrupt_at_threshold() -> void:
	GameManager.money = -1000
	assert_false(GameManager.is_bankrupt(), "-1000 is exactly at threshold, not below it")


# --- Green Fee ---

func test_set_green_fee_clamps_to_min() -> void:
	GameManager.set_green_fee(1)
	assert_eq(GameManager.green_fee, GameManager.MIN_GREEN_FEE, "Should clamp to minimum")

func test_set_green_fee_clamps_to_effective_max() -> void:
	# With 18 holes, effective max = min(18*15, 200) = $200
	var course = GameManager.CourseData.new()
	for i in range(18):
		var hole = GameManager.HoleData.new()
		hole.par = 4
		hole.is_open = true
		course.add_hole(hole)
	GameManager.current_course = course
	GameManager.set_green_fee(999)
	assert_eq(GameManager.green_fee, GameManager.MAX_GREEN_FEE, "18 holes should allow max $200")

func test_set_green_fee_clamps_by_hole_count() -> void:
	# With 3 holes, effective max = 3*15 = $45
	var course = GameManager.CourseData.new()
	for i in range(3):
		var hole = GameManager.HoleData.new()
		hole.par = 4
		hole.is_open = true
		course.add_hole(hole)
	GameManager.current_course = course
	GameManager.set_green_fee(100)
	assert_eq(GameManager.green_fee, 45, "3 holes should cap fee at $45")

func test_set_green_fee_accepts_valid_value() -> void:
	# Set up enough holes so $75 is under the cap (need 5+ holes: 5*15=75)
	var course = GameManager.CourseData.new()
	for i in range(5):
		var hole = GameManager.HoleData.new()
		hole.par = 4
		hole.is_open = true
		course.add_hole(hole)
	GameManager.current_course = course
	GameManager.set_green_fee(75)
	assert_eq(GameManager.green_fee, 75, "Should accept 75 as valid fee with 5 holes")

func test_set_green_fee_accepts_min_boundary() -> void:
	GameManager.set_green_fee(GameManager.MIN_GREEN_FEE)
	assert_eq(GameManager.green_fee, GameManager.MIN_GREEN_FEE, "Should accept min boundary")

func test_get_effective_max_fee_scales_with_holes() -> void:
	var course = GameManager.CourseData.new()
	for i in range(6):
		var hole = GameManager.HoleData.new()
		hole.par = 4
		hole.is_open = true
		course.add_hole(hole)
	GameManager.current_course = course
	# 6 holes * $15 = $90
	assert_eq(GameManager.get_effective_max_green_fee(), 90, "6 holes should have max fee $90")


# --- Reputation ---

func test_modify_reputation_clamps_to_max() -> void:
	GameManager.reputation = 95.0
	GameManager.modify_reputation(10.0)
	assert_eq(GameManager.reputation, 100.0, "Should clamp to 100")

func test_modify_reputation_clamps_to_min() -> void:
	GameManager.reputation = 5.0
	GameManager.modify_reputation(-10.0)
	assert_eq(GameManager.reputation, 0.0, "Should clamp to 0")

func test_modify_reputation_normal_range() -> void:
	GameManager.reputation = 50.0
	GameManager.modify_reputation(10.0)
	assert_eq(GameManager.reputation, 60.0, "Should increase normally")


# --- Game Speed ---

func test_get_game_speed_multiplier_normal() -> void:
	GameManager.is_paused = false
	GameManager.current_speed = GameManager.GameSpeed.NORMAL
	assert_eq(GameManager.get_game_speed_multiplier(), 1.0)

func test_get_game_speed_multiplier_fast() -> void:
	GameManager.is_paused = false
	GameManager.current_speed = GameManager.GameSpeed.FAST
	assert_eq(GameManager.get_game_speed_multiplier(), 2.0)

func test_get_game_speed_multiplier_ultra() -> void:
	GameManager.is_paused = false
	GameManager.current_speed = GameManager.GameSpeed.ULTRA
	assert_eq(GameManager.get_game_speed_multiplier(), 4.0)

func test_get_game_speed_multiplier_paused() -> void:
	GameManager.is_paused = true
	assert_eq(GameManager.get_game_speed_multiplier(), 0.0, "Paused should return 0")
	GameManager.is_paused = false

func test_toggle_pause() -> void:
	GameManager.is_paused = false
	GameManager.toggle_pause()
	assert_true(GameManager.is_paused, "Should be paused after toggle")
	GameManager.toggle_pause()
	assert_false(GameManager.is_paused, "Should be unpaused after second toggle")


# --- Course Open/Close ---

func test_is_course_open_during_hours() -> void:
	GameManager.current_hour = 12.0
	assert_true(GameManager.is_course_open(), "Course should be open at noon")

func test_is_course_closed_before_open() -> void:
	GameManager.current_hour = 5.0
	assert_false(GameManager.is_course_open(), "Course should be closed at 5 AM")

func test_is_course_closed_at_closing_time() -> void:
	GameManager.current_hour = 20.0
	assert_false(GameManager.is_course_open(), "Course should be closed at 8 PM (exact)")

func test_is_course_open_at_opening_time() -> void:
	GameManager.current_hour = 6.0
	assert_true(GameManager.is_course_open(), "Course should be open exactly at 6 AM")


# --- Time Display ---

func test_get_time_string_morning() -> void:
	GameManager.current_hour = 9.5
	assert_eq(GameManager.get_time_string(), "9:30 AM")

func test_get_time_string_afternoon() -> void:
	GameManager.current_hour = 14.25
	assert_eq(GameManager.get_time_string(), "2:15 PM")

func test_get_time_string_noon() -> void:
	GameManager.current_hour = 12.0
	assert_eq(GameManager.get_time_string(), "12:00 PM")

func test_get_time_string_midnight() -> void:
	GameManager.current_hour = 0.0
	assert_eq(GameManager.get_time_string(), "12:00 AM")


# --- New Game ---

func test_new_game_resets_state() -> void:
	# Modify state
	GameManager.money = 999
	GameManager.reputation = 10.0
	GameManager.current_day = 50
	GameManager.green_fee = 100

	GameManager.new_game("Test Course")

	assert_eq(GameManager.money, 50000, "Money should reset to 50000")
	assert_eq(GameManager.reputation, 50.0, "Reputation should reset to 50")
	assert_eq(GameManager.current_day, 1, "Day should reset to 1")
	assert_eq(GameManager.course_name, "Test Course", "Course name should be set")
	assert_eq(GameManager.green_fee, 30, "Green fee should reset to 30")
	assert_eq(GameManager.current_hour, GameManager.COURSE_OPEN_HOUR, "Hour should reset to opening")


# --- Staff Tier Data ---

func test_staff_tier_data_has_all_tiers() -> void:
	assert_true(GameManager.STAFF_TIER_DATA.has(GameManager.StaffTier.PART_TIME))
	assert_true(GameManager.STAFF_TIER_DATA.has(GameManager.StaffTier.FULL_TIME))
	assert_true(GameManager.STAFF_TIER_DATA.has(GameManager.StaffTier.PREMIUM))

func test_staff_tier_costs_increase() -> void:
	var pt = GameManager.STAFF_TIER_DATA[GameManager.StaffTier.PART_TIME].cost_per_hole
	var ft = GameManager.STAFF_TIER_DATA[GameManager.StaffTier.FULL_TIME].cost_per_hole
	var pm = GameManager.STAFF_TIER_DATA[GameManager.StaffTier.PREMIUM].cost_per_hole
	assert_lt(pt, ft, "Part-time should be cheaper than full-time")
	assert_lt(ft, pm, "Full-time should be cheaper than premium")


# --- CourseData ---

func test_course_data_add_hole() -> void:
	var course = GameManager.CourseData.new()
	var hole = GameManager.HoleData.new()
	hole.par = 4
	course.add_hole(hole)
	assert_eq(course.holes.size(), 1, "Should have one hole")
	assert_eq(course.total_par, 4, "Total par should be 4")

func test_course_data_multiple_holes_par() -> void:
	var course = GameManager.CourseData.new()
	for par in [3, 4, 5, 4]:
		var hole = GameManager.HoleData.new()
		hole.par = par
		course.add_hole(hole)
	assert_eq(course.total_par, 16, "Total par should be sum: 3+4+5+4=16")

func test_course_data_get_open_holes() -> void:
	var course = GameManager.CourseData.new()
	for i in range(3):
		var hole = GameManager.HoleData.new()
		hole.hole_number = i + 1
		hole.is_open = (i != 1)  # Close hole 2
		course.add_hole(hole)
	assert_eq(course.get_open_holes().size(), 2, "Should have 2 open holes")


# --- HoleData ---

func test_hole_data_defaults() -> void:
	var hole = GameManager.HoleData.new()
	assert_eq(hole.par, 4, "Default par should be 4")
	assert_true(hole.is_open, "Holes should be open by default")
	assert_eq(hole.difficulty_rating, 1.0, "Default difficulty should be 1.0")


# --- Check Hole Records ---

func test_check_hole_records_hole_in_one() -> void:
	GameManager.reset_course_records()
	GameManager.current_day = 5
	var records = GameManager.check_hole_records("Tiger", 1, 1)
	assert_eq(records.size(), 1, "Should have one record")
	assert_eq(records[0].type, "hole_in_one", "Record type should be hole_in_one")
	assert_eq(GameManager.course_records.total_hole_in_ones, 1, "Should track hole-in-one count")

func test_check_hole_records_best_score_new() -> void:
	GameManager.reset_course_records()
	GameManager.current_day = 1
	# First score for hole 1 - sets the record but doesn't "break" it
	var records = GameManager.check_hole_records("Alice", 1, 3)
	# First score sets the record but only announces "broken" if there was an existing record
	assert_eq(GameManager.course_records.best_per_hole.has(1), true, "Should have best for hole 1")
	assert_eq(GameManager.course_records.best_per_hole[1].value, 3, "Best score should be 3")

func test_check_hole_records_best_score_broken() -> void:
	GameManager.reset_course_records()
	GameManager.current_day = 1
	# Set initial record
	GameManager.check_hole_records("Alice", 1, 4)
	# Beat it
	var records = GameManager.check_hole_records("Bob", 1, 3)
	var has_hole_record = false
	for r in records:
		if r.type == "hole_record":
			has_hole_record = true
	assert_true(has_hole_record, "Should announce broken hole record")
	assert_eq(GameManager.course_records.best_per_hole[1].golfer_name, "Bob", "Bob should hold record")

func test_check_round_record_first_round() -> void:
	GameManager.reset_course_records()
	GameManager.current_day = 1
	var is_record = GameManager.check_round_record("Alice", 72)
	assert_true(is_record, "First round should always be a course record")
	assert_eq(GameManager.course_records.lowest_round.value, 72)

func test_check_round_record_beaten() -> void:
	GameManager.reset_course_records()
	GameManager.current_day = 1
	GameManager.check_round_record("Alice", 72)
	var is_record = GameManager.check_round_record("Bob", 70)
	assert_true(is_record, "Lower score should beat the record")
	assert_eq(GameManager.course_records.lowest_round.golfer_name, "Bob")

func test_check_round_record_not_beaten() -> void:
	GameManager.reset_course_records()
	GameManager.current_day = 1
	GameManager.check_round_record("Alice", 70)
	var is_record = GameManager.check_round_record("Bob", 72)
	assert_false(is_record, "Higher score should not beat the record")
	assert_eq(GameManager.course_records.lowest_round.golfer_name, "Alice")
