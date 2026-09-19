extends SceneTree
## Reproducible fresh-start playtest: 3 operating days, then save/reload.
var main: Node
var results: Array = []
func _initialize() -> void: call_deferred("run")
func run() -> void:
	seed(74109)
	main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main._on_main_menu_quick_start("Garden Club playtest", 0)
	for i in range(8): await process_frame
	var gm := root.get_node("GameManager")
	var sm := root.get_node("SaveManager")
	assert(gm.current_course.holes.size() == 9)
	assert(main.entity_layer.get_all_buildings().size() == 4)
	for hole in gm.current_course.holes:
		assert(main.terrain_grid.get_tile(hole.hole_position) == TerrainTypes.Type.GREEN)
	var start_money: int = gm.money
	for day in range(3):
		# A deliberately overpriced middle day tests the demand tradeoff.
		gm.set_green_fee(20 if day == 1 else 5)
		main._on_mode_toggle_pressed()
		gm.set_speed(8)
		var ticks := Time.get_ticks_msec()
		while not gm._end_of_day_emitted and Time.get_ticks_msec()-ticks < 600000:
			await create_timer(1, true, false, true).timeout
		assert(gm._end_of_day_emitted, "Day must finish without intervention")
		var stats = gm.daily_stats
		var report := {"day":gm.current_day,"fee":gm.green_fee,"arrivals":stats.golfers_arrived,"completed":stats.golfers_served,"revenue":stats.get_total_revenue(),"costs":stats.operating_costs,"profit":stats.get_profit(),"cash":gm.money,"reputation":gm.reputation,"weather":gm.weather_system.weather_type,"satisfaction":root.get_node("FeedbackManager").get_satisfaction_rating()}
		results.append(report)
		print("MANAGEMENT_DAY ", JSON.stringify(report))
		var panel = main.get_node_or_null("UI/HUD/EndOfDaySummary")
		if panel:
			panel.get_parent().remove_child(panel)
			panel.queue_free()
		main._on_summary_build_mode()
		await process_frame
	var data: Dictionary = sm._build_save_data()
	var balance: int = gm.money
	sm._apply_save_data(data)
	assert(gm.money == balance)
	assert(gm.daily_history.size() == 3)
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		var output := FileAccess.open(args[0], FileAccess.WRITE)
		output.store_string(JSON.stringify({"starting_cash":start_money,"days":results,"reload_cash":gm.money},"\t"))
	print("MANAGEMENT_COMPLETE ",JSON.stringify(results))
	quit(0)
