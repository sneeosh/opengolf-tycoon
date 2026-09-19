extends SceneTree
## Twelve real simulation days; management interventions use normal placement/purchase paths.
var main: Node
var results: Array = []
var purchases: Array = []
func _initialize() -> void: call_deferred("run")
func buy_near(kind: String, center: Vector2i, decoration: bool = false) -> void:
	var registry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/decorations.json" if decoration else "res://data/buildings.json"))["decorations" if decoration else "buildings"]
	if decoration: main.placement_manager.start_decoration_placement(kind, registry[kind])
	else: main.placement_manager.start_building_placement(kind, registry[kind])
	for radius in range(1,5):
		for dx in range(-radius,radius+1):
			for dy in range(-radius,radius+1):
				var pos := center+Vector2i(dx,dy)
				if main.terrain_grid.get_tile(pos) in [TerrainTypes.Type.GREEN,TerrainTypes.Type.TEE_BOX,TerrainTypes.Type.FAIRWAY]: continue
				if main.placement_manager.can_place_at(pos, main.terrain_grid):
					main._handle_placement_click(pos)
					purchases.append({"kind":kind,"x":pos.x,"y":pos.y,"day":root.get_node("GameManager").current_day,"cost":registry[kind].cost})
					return
	assert(false,"No legal location for " + kind)
func run() -> void:
	seed(42618)
	main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main._on_main_menu_quick_start("Guest experience campaign",0)
	for i in range(8): await process_frame
	var gm = root.get_node("GameManager")
	var fm = root.get_node("FeedbackManager")
	var sm = root.get_node("SaveManager")
	var start_cash: int = gm.money
	for day in range(12):
		gm.set_green_fee(12 if day < 3 else (6 if day < 6 else 8))
		gm.tee_booking_interval = 60 if day < 3 else (180 if day < 6 else 90)
		if day == 3:
			for hn in [4,6,8]:
				var hole = gm.current_course.holes[hn-1]
				buy_near("park_bench",hole.tee_position,true)
			buy_near("snack_bar",gm.current_course.holes[3].tee_position)
			buy_near("restroom",gm.current_course.holes[5].tee_position)
			gm.staff_manager.hire_staff(gm.staff_manager.StaffType.GROUNDSKEEPER)
			gm.staff_manager.hire_staff(gm.staff_manager.StaffType.MARSHAL)
		# Hold weather steady to make operational changes easier to interpret.
		gm.weather_system.weather_type = gm.weather_system.WeatherType.PARTLY_CLOUDY
		gm.weather_system._target_weather = gm.weather_system.WeatherType.PARTLY_CLOUDY
		gm.weather_system.intensity = .1
		gm.weather_system._weather_duration = 1000
		gm.weather_system._transition_progress = 1.0
		main._on_mode_toggle_pressed()
		gm.set_speed(16)
		var started := Time.get_ticks_msec()
		while not gm._end_of_day_emitted and Time.get_ticks_msec()-started < 600000:
			await create_timer(1,true,false,true).timeout
		assert(gm._end_of_day_emitted)
		var s = gm.daily_stats
		var row: Dictionary = fm.visit_summary()
		row.merge({"day":gm.current_day,"fee":gm.green_fee,"booking_interval":gm.tee_booking_interval,"arrivals":s.golfers_arrived,"completed":s.golfers_served,"revenue":s.get_total_revenue(),"costs":s.operating_costs,"profit":s.get_profit(),"cash":gm.money,"condition":gm.staff_manager.course_condition,"reputation":gm.reputation,"positive_thoughts":fm.get_satisfaction_rating(),"hotspots":fm.get_hotspots()})
		results.append(row)
		print("CAMPAIGN_DAY ",JSON.stringify(row))
		var panel = main.get_node_or_null("UI/HUD/EndOfDaySummary")
		if panel:
			panel.get_parent().remove_child(panel)
			panel.queue_free()
		var args := OS.get_cmdline_user_args()
		if args.size() > 0:
			var f := FileAccess.open(args[0],FileAccess.WRITE)
			f.store_string(JSON.stringify({"starting_cash":start_cash,"days":results,"purchases":purchases},"\t"))
		if day == 11 and args.size() > 1:
			var save := FileAccess.open(args[1],FileAccess.WRITE)
			save.store_string(JSON.stringify(sm._build_save_data()))
		main._on_summary_build_mode()
		await process_frame
		if day == 5:
			var before: int = fm.customers.size()
			var money: int = gm.money
			sm._apply_save_data(JSON.parse_string(JSON.stringify(sm._build_save_data())))
			assert(gm.money == money and fm.customers.size() == before)
	assert(results.size() == 12)
	print("CAMPAIGN_COMPLETE")
	quit(0)
