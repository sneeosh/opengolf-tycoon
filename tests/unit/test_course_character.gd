extends GutTest
var grid: TerrainGrid
var previous_land
var previous_pause: bool
var previous_speed: int

func before_each() -> void:
	previous_land = GameManager.land_manager
	GameManager.land_manager = null
	previous_pause = GameManager.is_paused
	previous_speed = GameManager.current_speed
	GameManager.is_paused = false
	GameManager.current_speed = GameManager.GameSpeed.NORMAL
	grid = TerrainGrid.new()
	grid.grid_width = 16
	grid.grid_height = 16
	add_child_autofree(grid)
	for x in range(16):
		for y in range(16):
			grid.set_tile(Vector2i(x, y), TerrainTypes.Type.GRASS)

func after_each() -> void:
	GameManager.land_manager = previous_land
	GameManager.is_paused = previous_pause
	GameManager.current_speed = previous_speed

func test_sculpted_brush_tapers_preserves_surfaces_and_can_be_undone() -> void:
	grid.set_tile(Vector2i(8, 7), TerrainTypes.Type.WATER)
	grid.set_tile(Vector2i(7, 8), TerrainTypes.Type.PATH)
	var saved := grid.serialize()
	var tool := ElevationTool.new()
	add_child_autofree(tool)
	tool.start_raising()
	tool.sculpted = true
	var changes := tool.paint_elevation(Vector2i(8, 8), grid, 9)
	assert_eq(grid.get_elevation(Vector2i(8, 8)), 3)
	assert_eq(grid.get_elevation(Vector2i(11, 8)), 1)
	assert_eq(grid.get_elevation(Vector2i(12, 8)), 0)
	assert_eq(grid.get_elevation(Vector2i(8, 7)), 0)
	assert_eq(grid.get_elevation(Vector2i(7, 8)), 0)
	assert_eq(grid.serialize(), saved)
	assert_eq(roundi(grid._course_surface._data.get_pixel(8, 8).b * 10.0 - 5.0), 3)
	var heights := grid.serialize_elevation()
	grid.deserialize_elevation(heights)
	assert_eq(grid.get_elevation(Vector2i(8, 8)), 3)
	assert_eq(roundi(grid._course_surface._data.get_pixel(8, 8).b * 10.0 - 5.0), 3)
	for change in changes:
		grid.set_elevation(change.position, change.old_elevation)
	assert_eq(grid.get_elevation(Vector2i(8, 8)), 0)
	assert_eq(grid.get_elevation(Vector2i(11, 8)), 0)
	grid.deserialize_elevation({})
	assert_eq(roundi(grid._course_surface._data.get_pixel(8, 8).b * 10.0 - 5.0), 0)

func test_sculpting_respects_buildings_and_height_limits() -> void:
	var entities := EntityLayer.new()
	entities.map_seed = 1234
	add_child_autofree(entities)
	entities.set_terrain_grid(grid)
	var registry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/buildings.json"))["buildings"]
	entities.place_building("clubhouse", Vector2i(6, 6), registry)
	SculptedTerrain.stamp(grid, Vector2i(8, 8), 5, 3, entities)
	assert_eq(grid.get_elevation(Vector2i(8, 8)), 0)
	grid.set_elevation(Vector2i(3, 3), 4)
	SculptedTerrain.stamp(grid, Vector2i(3, 3), 3, 3)
	assert_eq(grid.get_elevation(Vector2i(3, 3)), 5)
	SculptedTerrain.stamp(grid, Vector2i(3, 3), 3, -20)
	assert_eq(grid.get_elevation(Vector2i(3, 3)), -5)

func test_clubhouse_upgrades_grow_without_changing_footprint_or_duplicate_clicks() -> void:
	var building := Building.new()
	add_child_autofree(building)
	var previous_width := 0.0
	for level in range(1, 4):
		building.upgrade_level = level
		building._update_visuals()
		assert_eq(building.get_node("Visual/Architecture").level, level)
		var architecture = building.get_node("Visual/Architecture")
		var body_width := CourseArchitecture.body_width("clubhouse", architecture.footprint, level)
		assert_gt(body_width, previous_width)
		assert_lt(body_width, architecture.footprint.x)
		assert_eq(architecture.footprint, Vector2(256, 128))
		previous_width = body_width
		var clicks := 0
		var visuals := 0
		for child in building.get_children():
			if child is Area2D: clicks += 1
			if child.name == "Visual": visuals += 1
		assert_eq(clicks, 1)
		assert_eq(visuals, 1)
		await get_tree().process_frame

func test_golfer_expression_does_not_move_actor_or_delay_next_shot() -> void:
	var golfer = load("res://scenes/entities/golfer.tscn").instantiate()
	add_child_autofree(golfer)
	golfer.set_process(false)
	var expression: GolferExpression = golfer._expression
	expression.set_process(false)
	var position_before: Vector2 = golfer.position
	var score_before: int = golfer.current_strokes
	expression.react_to_score(-1)
	expression._process(0.1)
	assert_lt(expression.position.y, 0.0)
	assert_eq(golfer.position, position_before)
	assert_eq(golfer.current_strokes, score_before)
	GameManager.is_paused = true
	var remaining := expression._reaction_remaining
	expression._process(1.0)
	assert_eq(expression._reaction_remaining, remaining)
	GameManager.is_paused = false
	golfer.current_state = Golfer.State.PREPARING_SHOT
	expression._process(0.1)
	assert_eq(expression._reaction_remaining, 0.0)
	assert_eq(golfer.preparation_time, 0.0)
	assert_eq(GolferExpression.reaction_for_score(2), -1)
	assert_eq(GolferExpression.reaction_for_score(0), 0)

func test_building_ghost_matches_facility_and_clears_when_preview_ends() -> void:
	var manager := PlacementManager.new()
	add_child_autofree(manager)
	manager.selected_building_type = "restaurant"
	manager.current_placement_data = {"size": {"width": 3, "height": 3}}
	var preview := PlacementPreview.new()
	add_child_autofree(preview)
	preview.set_process(false)
	preview.placement_manager = manager
	preview._draw_building_ghost(Vector2(120, 80), Color(0.3, 0.9, 0.3, 0.4))
	assert_eq(preview._building_ghost.kind, "restaurant")
	assert_eq(preview._building_ghost.position, Vector2(120, 80))
	assert_almost_eq(preview._building_ghost.modulate.a, 0.4, 0.001)
	assert_true(preview._building_ghost.visible)
	# With no terrain/active preview, drawing must hide the previous building.
	preview._draw()
	assert_false(preview._building_ghost.visible)
