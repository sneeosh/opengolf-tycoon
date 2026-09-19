extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main._on_main_menu_quick_start("Builder verification", 0)
	for i in range(8): await process_frame
	var gm = root.get_node("GameManager")
	for hole in gm.current_course.holes:
		assert(main.terrain_grid.get_tile(hole.tee_position) == TerrainTypes.Type.TEE_BOX)
		assert(main.terrain_grid.get_tile(hole.hole_position) == TerrainTypes.Type.GREEN, "Every starter cup must stay on its green")
	# Ownership and decorations must survive terrain brushes unchanged.
	main.current_tool = TerrainTypes.Type.FAIRWAY
	main.brush_size = 1
	var protected_cash: int = gm.money
	var outside := Vector2i(0, 0)
	var outside_type: int = main.terrain_grid.get_tile(outside)
	main.undo_manager.begin_stroke()
	main._paint_terrain_stamp(outside)
	main.undo_manager.end_stroke()
	assert(main.terrain_grid.get_tile(outside) == outside_type)
	assert(gm.money == protected_cash)
	var bench := Vector2i(54, 66)
	var bench_type: int = main.terrain_grid.get_tile(bench)
	main.undo_manager.begin_stroke()
	main._paint_terrain_stamp(bench)
	main.undo_manager.end_stroke()
	assert(main.terrain_grid.get_tile(bench) == bench_type)
	assert(main.entity_layer.get_decoration_at(bench) != null)
	assert(gm.money == protected_cash)
	gm.land_manager = null
	var pos := Vector2i(30,30)
	main.entity_layer.remove_tree(pos)
	main.entity_layer.remove_rock(pos)
	main.terrain_grid.set_tile(pos, TerrainTypes.Type.GRASS)
	main.entity_layer.place_tree(pos, "oak")
	var before_type: int = main.terrain_grid.get_tile(pos)
	var cash: int = gm.money
	main.undo_manager.clear()
	main.current_tool = TerrainTypes.Type.FAIRWAY
	main.brush_size = 1
	main.undo_manager.begin_stroke()
	main.is_painting = true
	main._paint_terrain_stamp(pos)
	main._cancel_action()
	assert(main.entity_layer.get_tree_at(pos) == null)
	assert(main.terrain_grid.get_tile(pos) == TerrainTypes.Type.FAIRWAY)
	var paid: int = cash - gm.money
	assert(paid > 0)
	main._perform_undo()
	assert(main.entity_layer.get_tree_at(pos) != null)
	assert(main.terrain_grid.get_tile(pos) == before_type)
	assert(gm.money == cash)
	gm.money = 0
	main._perform_redo()
	assert(main.undo_manager.can_redo())
	assert(main.entity_layer.get_tree_at(pos) != null)
	gm.money = cash
	main._perform_redo()
	assert(main.entity_layer.get_tree_at(pos) == null)
	assert(gm.money == cash - paid)
	var natural := Vector2i(31,31)
	main.entity_layer.remove_tree(natural)
	main.entity_layer.remove_rock(natural)
	main.terrain_grid.set_tile(natural, TerrainTypes.Type.BUNKER)
	main.terrain_grid._player_placed_tiles.erase(natural)
	main.terrain_grid.set_bunker_depth(natural, 1)
	main.undo_manager.begin_stroke()
	main._paint_terrain_stamp(natural)
	main.undo_manager.end_stroke()
	main._perform_undo()
	assert(main.terrain_grid.get_bunker_depth(natural) == 1)
	assert(not main.terrain_grid._player_placed_tiles.has(natural))
	var sm = root.get_node("SaveManager")
	gm.daily_stats.revenue = 321
	gm.daily_stats.golfers_arrived = 7
	var data: Dictionary = JSON.parse_string(JSON.stringify(sm._build_save_data()))
	sm._apply_save_data(data)
	assert(gm.daily_stats.revenue == 321)
	assert(gm.daily_stats.golfers_arrived == 7)
	print("BUILDER_REGRESSION_PASS: starter surfaces, obstacle restore, exact cash undo/redo, unaffordable redo, cancel stroke, save accounting")
	quit(0)
