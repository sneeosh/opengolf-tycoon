extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main._on_main_menu_quick_start("Amenity regression",0)
	for i in range(8): await process_frame
	var gm = root.get_node("GameManager")
	var fm = root.get_node("FeedbackManager")
	var golfer = main.golfer_manager.spawn_golfer("Hungry visitor",.5,0)
	golfer.set_process(false)
	golfer.global_position = main.terrain_grid.grid_to_screen_center(Vector2i(68,74))
	golfer.needs.hunger = .1
	var cash: int = gm.money
	golfer._check_building_proximity()
	assert(golfer._amenity_phase == 1,"Hungry guest should choose reachable snack bar")
	assert(gm.money == cash,"No charge before arrival")
	for i in range(800):
		golfer._process_amenity_visit(.05)
		if golfer._amenity_phase == 0: break
	assert(golfer.needs.hunger > .1,"Food must restore hunger")
	assert(golfer.amenities_used == 1)
	assert(fm.service_visits == 1)
	assert(gm.money == cash + 5)
	assert(fm.service_revenue == 5)
	assert(golfer._amenity_phase == 0,"Guest returns to play")
	var key: String = fm.next_guest_key()
	var sm = root.get_node("SaveManager")
	sm._apply_save_data(JSON.parse_string(JSON.stringify(sm._build_save_data())))
	assert(fm.service_revenue == 5)
	assert(fm.next_guest_key() != key,"Reload cannot reuse guest identities")
	gm.current_hour = gm.COURSE_CLOSE_HOUR
	gm.daily_stats.operating_costs = 100
	var previous_day: int = gm.current_day
	var settled_cash: int = gm.money
	assert(gm.start_simulation())
	assert(gm.current_day == previous_day + 1)
	assert(gm.daily_stats.operating_costs == 0)
	assert(gm.money == settled_cash,"A settled save must not pay the day's costs twice")
	gm.set_speed(gm.GameSpeed.PAUSED)
	var paused_hour: float = gm.current_hour
	for i in range(5): await process_frame
	assert(gm.current_hour == paused_hour)
	gm.stop_simulation()
	assert(Engine.time_scale == 1.0,"Building UI must remain responsive")
	print("AMENITY_PASS: walk to service, charge on arrival, need restoration, return to play, persisted income and unique identity")
	quit(0)
