extends GutTest

func test_restoring_holes_does_not_emit_construction_rewards() -> void:
	var old_course = GameManager.current_course
	GameManager.current_course = GameManager.CourseData.new()
	watch_signals(EventBus)
	SaveManager._deserialize_holes([{"hole_number": 1, "par": 4}])
	assert_signal_not_emitted(EventBus, "hole_created", "Loading is not construction")
	GameManager.current_course = old_course

func test_hole_one_statistics_are_keyed_by_public_number() -> void:
	var old_stats = GameManager.hole_statistics
	var old_daily = GameManager.daily_stats
	GameManager.hole_statistics = {}
	GameManager.daily_stats = GameManager.DailyStatistics.new()
	GameManager._on_golfer_finished_hole_for_stats(42, 1, 3, 4)
	assert_true(GameManager.hole_statistics.has(1))
	assert_false(GameManager.hole_statistics.has(2))
	assert_eq(GameManager.get_hole_statistics(1).get_average_score(), 3.0)
	var serialized = SaveManager._serialize_hole_statistics()
	SaveManager._restore_hole_statistics(JSON.parse_string(JSON.stringify(serialized)))
	assert_eq(GameManager.get_hole_statistics(1).total_rounds, 1)
	assert_eq(GameManager.get_hole_statistics(1).birdies, 1)
	SaveManager._restore_hole_statistics({})
	assert_true(GameManager.hole_statistics.is_empty(), "Older saves cannot inherit another course's scores")
	GameManager.hole_statistics = old_stats
	GameManager.daily_stats = old_daily

func test_milestone_deserialize_resets_previous_course_flags() -> void:
	var manager := MilestoneManager.new()
	manager.milestones = MilestoneSystem.get_all_milestones()
	var first = manager.milestones[0]
	first.is_completed = true
	first.completion_day = 3
	manager.deserialize({})
	assert_false(first.is_completed)
	assert_eq(first.completion_day, 0)
	manager.free()

func test_loading_blocks_rewards_even_when_event_is_received() -> void:
	var manager := MilestoneManager.new()
	manager.milestones = MilestoneSystem.get_all_milestones()
	var money := GameManager.money
	SaveManager._is_loading = true
	manager._complete_milestone(manager.milestones[0])
	assert_eq(manager.get_completion_count(), 0)
	assert_true(manager.serialize().completed.is_empty())
	SaveManager._is_loading = false
	assert_eq(GameManager.money, money)
	assert_false(manager.milestones[0].is_completed)
	manager.free()

func test_expanded_catalog_has_valid_services_and_shared_garden_art() -> void:
	var buildings: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/buildings.json")).buildings
	var decorations: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/decorations.json")).decorations
	assert_eq(buildings.size(), 16)
	assert_eq(decorations.size(), 28)
	for type in GardenArt.KINDS:
		assert_true(decorations.has(type), type)
	for type in buildings:
		var item: Dictionary = buildings[type]
		if item.has("needs_service"):
			assert_true(item.needs_service in ["snack_bar", "restaurant", "bench", "restroom", "clubhouse", "pro_shop"], type)

func test_fast_brush_drag_has_no_gaps_and_includes_endpoints() -> void:
	var points := TerrainBrush.centers(Vector2i(3, 4), Vector2i(32, 19))
	assert_eq(points.front(), Vector2i(3, 4))
	assert_eq(points.back(), Vector2i(32, 19))
	for i in range(1, points.size()):
		assert_lte(absi(points[i].x - points[i-1].x), 1)
		assert_lte(absi(points[i].y - points[i-1].y), 1)
	assert_false(TerrainBrush.offsets(5).has(Vector2i(2, 2)))
	assert_true(TerrainBrush.offsets(5, false).has(Vector2i(2, 2)))

func test_overpricing_reduces_demand_and_expected_green_fee_income() -> void:
	var fair_demand := CourseEconomy.price_demand(5, 9, 45.0)
	var expensive_demand := CourseEconomy.price_demand(10, 9, 45.0)
	assert_eq(fair_demand, 1.0)
	assert_eq(expensive_demand, .25)
	assert_lt(10 * expensive_demand, 5 * fair_demand)
	assert_lt(CourseEconomy.price_demand(100, 9, 45.0), .01)

func test_daily_accounts_survive_json_round_trip() -> void:
	var old_stats = GameManager.daily_stats
	GameManager.daily_stats = GameManager.DailyStatistics.new()
	GameManager.daily_stats.revenue = 540
	GameManager.daily_stats.operating_costs = 150
	GameManager.daily_stats.hired_staff_payroll = 40
	GameManager.daily_stats.marketing_cost = 20
	GameManager.daily_stats.golfers_arrived = 12
	GameManager.daily_stats.tier_counts[GolferTier.Tier.CASUAL] = 7
	SaveManager._restore_daily_stats(JSON.parse_string(JSON.stringify(SaveManager._serialize_daily_stats())))
	assert_eq(GameManager.daily_stats.get_profit(), 390)
	assert_eq(GameManager.daily_stats.golfers_arrived, 12)
	assert_eq(GameManager.daily_stats.hired_staff_payroll, 40)
	assert_eq(GameManager.daily_stats.marketing_cost, 20)
	assert_eq(GameManager.daily_stats.tier_counts[GolferTier.Tier.CASUAL], 7)
	SaveManager._restore_daily_stats({})
	assert_eq(GameManager.daily_stats.revenue, 0)
	GameManager.daily_stats = old_stats

func test_stroke_keeps_actual_cost_and_cleared_objects_as_one_action() -> void:
	var undo := UndoManager.new()
	undo.begin_stroke()
	undo.record_tile_change(Vector2i(2, 3), 0, 1)
	undo.record_stroke_cost(37)
	undo.record_stroke_removal("tree", Vector2i(2, 3), "oak")
	undo.end_stroke()
	var action := undo.undo()
	assert_eq(action.paid_cost, 37)
	assert_eq(action.removed_entities.size(), 1)
	assert_eq(action.removed_entities[0].subtype, "oak")
	assert_eq(undo.redo(), action)
	undo.free()

func test_partial_round_departure_does_not_count_as_completed_round() -> void:
	var old_stats = GameManager.daily_stats
	GameManager.daily_stats = GameManager.DailyStatistics.new()
	EventBus.golfer_finished_round.emit(-1, 12, 12)
	assert_eq(GameManager.daily_stats.golfers_served, 0)
	EventBus.golfer_completed_round.emit(-1, 36, 36)
	assert_eq(GameManager.daily_stats.golfers_served, 1)
	GameManager.daily_stats = old_stats
