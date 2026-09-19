extends GutTest
var saved_experience: Dictionary
var saved_stats
func before_each() -> void:
	saved_experience = FeedbackManager.serialize_experience()
	saved_stats = GameManager.daily_stats
	FeedbackManager.restore_experience({})
	GameManager.daily_stats = GameManager.DailyStatistics.new()
func after_each() -> void:
	FeedbackManager.restore_experience(saved_experience)
	GameManager.daily_stats = saved_stats

func test_normal_play_recovers_patience_but_traffic_reduces_it() -> void:
	var needs := GolferNeeds.new()
	needs.setup(1,.5)
	needs.on_waiting(100)
	assert_lt(needs.pace,.5)
	var before := needs.pace
	needs.on_playing(100)
	assert_gt(needs.pace,before)
	needs.on_playing(-100)
	assert_gte(needs.pace,before)

func test_incidents_are_located_deduplicated_and_survive_json() -> void:
	var golfer := Golfer.new()
	golfer.golfer_id = 400
	golfer.golfer_name = "Visitor"
	golfer.current_hole = 3
	golfer.needs = GolferNeeds.new()
	FeedbackManager.record_incident(golfer,FeedbackTriggers.TriggerType.HUNGRY)
	FeedbackManager.record_incident(golfer,FeedbackTriggers.TriggerType.HUNGRY)
	assert_eq(FeedbackManager.incidents.size(),1)
	assert_eq(FeedbackManager.get_hotspots()[0].hole,4)
	assert_true(FeedbackManager.guest_incident_text(400).contains("Needs food"))
	FeedbackManager.restore_experience(JSON.parse_string(JSON.stringify(FeedbackManager.serialize_experience())))
	assert_eq(FeedbackManager.get_hotspots()[0].count,1)
	golfer.current_hole = 0
	FeedbackManager.record_incident(golfer,FeedbackTriggers.TriggerType.SHANK)
	golfer.golfer_id = 401
	FeedbackManager.record_incident(golfer,FeedbackTriggers.TriggerType.SHANK)
	FeedbackManager.restore_experience(JSON.parse_string(JSON.stringify(FeedbackManager.serialize_experience())))
	assert_eq(int(FeedbackManager.get_hotspots()[0].trigger),FeedbackTriggers.TriggerType.HUNGRY,"Loaded actionable needs outrank mishits")
	golfer.free()

func test_service_and_value_improvements_raise_visit_score_and_return_intent() -> void:
	var golfer := Golfer.new()
	golfer.guest_key = "test"
	golfer.golfer_name = "Visitor"
	golfer._round_total_holes = 9
	golfer.paid_round_fee = 500
	golfer.current_mood = .4
	golfer.needs = GolferNeeds.new()
	golfer.needs.energy = .1
	golfer.needs.hunger = .1
	golfer.needs.comfort = .1
	FeedbackManager.record_visit(golfer)
	var poor: Dictionary = FeedbackManager.visits[0].duplicate()
	FeedbackManager.visits.clear()
	golfer.needs.apply_building_effect("bench")
	golfer.needs.apply_building_effect("restaurant")
	golfer.needs.apply_building_effect("restroom")
	golfer.paid_round_fee = 10
	FeedbackManager.record_visit(golfer)
	assert_gt(FeedbackManager.visits[0].score, poor.score)
	assert_gt(FeedbackManager.visits[0].return_intent, poor.return_intent)
	assert_eq(FeedbackManager.customers.size(),1,"Returning profile updates rather than duplicating")
	FeedbackManager.record_visit(golfer)
	assert_eq(FeedbackManager.visits.size(),1,"One review per completed visit")
	golfer.free()

func test_recent_customers_cannot_return_twice_on_the_same_day() -> void:
	FeedbackManager.customers = [{"key":"one","last_day":GameManager.current_day,"intent":1.0}]
	for i in range(20):
		assert_true(FeedbackManager.take_returning_guest().is_empty())
	assert_eq(FeedbackManager.returning_today,0)

func test_new_day_keeps_customers_but_clears_daily_experience() -> void:
	FeedbackManager.customers = [{"key":"one","last_day":1,"intent":.8}]
	FeedbackManager.service_visits = 4
	FeedbackManager.service_revenue = 20
	FeedbackManager.reset_daily_stats()
	assert_eq(FeedbackManager.customers.size(),1)
	assert_eq(FeedbackManager.service_visits,0)
	assert_eq(FeedbackManager.service_revenue,0)

func test_guest_identity_sequence_survives_save_and_is_not_reused() -> void:
	var first := FeedbackManager.next_guest_key()
	FeedbackManager.restore_experience(JSON.parse_string(JSON.stringify(FeedbackManager.serialize_experience())))
	assert_ne(FeedbackManager.next_guest_key(),first)

func test_recent_satisfaction_is_weighted_by_reviews_and_profit_excludes_rewards() -> void:
	var history = GameManager.daily_history
	GameManager.daily_history = [{"profit":100,"guest_experience":{"reviews":1,"satisfaction":1.0}},{"profit":-50,"guest_experience":{"reviews":3,"satisfaction":.0}}]
	var recent := FeedbackManager.recent_experience()
	assert_eq(recent.reviews,4)
	assert_eq(recent.satisfaction,.25)
	assert_eq(recent.profit,25.0)
	GameManager.daily_history = history

func test_relaxed_bookings_limit_on_course_crowding() -> void:
	var course = GameManager.current_course
	var interval: int = GameManager.tee_booking_interval
	GameManager.current_course = GameManager.CourseData.new()
	for i in range(9):
		var hole = GameManager.HoleData.new()
		hole.hole_number = i + 1
		hole.is_open = true
		GameManager.current_course.add_hole(hole)
	var manager := GolferManager.new()
	GameManager.tee_booking_interval = 90
	assert_eq(manager.get_max_concurrent_golfers(),36)
	GameManager.tee_booking_interval = 180
	assert_eq(manager.get_max_concurrent_golfers(),18)
	manager.free()
	GameManager.current_course = course
	GameManager.tee_booking_interval = interval

func test_pause_button_stops_clock_and_slows_tweens_without_freezing_input() -> void:
	var mode = GameManager.current_mode
	var speed = GameManager.current_speed
	var hour: float = GameManager.current_hour
	GameManager.current_mode = GameManager.GameMode.SIMULATING
	GameManager.set_speed(GameManager.GameSpeed.PAUSED)
	GameManager._process(10.0)
	assert_eq(GameManager.current_hour,hour)
	assert_lt(Engine.time_scale,.00001)
	GameManager.set_speed(speed)
	GameManager.current_mode = mode
