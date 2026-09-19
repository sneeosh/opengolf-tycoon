extends SceneTree
## Run with --path . --script tests/integration/lions_muni_regression.gd -- <save path>
var rounds := 0
var furthest_hole := 0
var main: Node
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var args := OS.get_cmdline_user_args()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var gm := root.get_node("GameManager")
	var sm := root.get_node("SaveManager")
	var bus := root.get_node("EventBus")
	sm._apply_save_data(data)
	bus.load_completed.emit(true)
	main._on_main_menu_load_completed(true)
	assert(gm.money == int(data.game_state.money), "Load must preserve money exactly")
	sm._apply_save_data(data)
	bus.load_completed.emit(true)
	assert(gm.money == int(data.game_state.money), "Repeated load must not replay rewards")
	print("REGRESSION: load and repeated load preserve $", gm.money)
	bus.golfer_finished_round.connect(func(_id, _strokes, _par): rounds += 1)
	bus.golfer_finished_hole.connect(func(_id, hole, _strokes, _par): furthest_hole = maxi(furthest_hole, hole))
	main._on_mode_toggle_pressed()
	gm.set_speed(8)
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 150000 and rounds == 0 and gm.current_mode == gm.GameMode.SIMULATING:
		await create_timer(5, true, false, true).timeout
		print("PACE: hour=",gm.current_hour," furthest=",furthest_hole," rounds=",rounds)
	print("REGRESSION RESULT: rounds=",rounds," furthest=",furthest_hole," hour=",gm.current_hour)
	quit(0 if rounds > 0 else 1)
