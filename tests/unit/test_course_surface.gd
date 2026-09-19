extends GutTest
## Integration regressions for terrain rendering and generated-course cleanup.

var grid: TerrainGrid

func before_each() -> void:
	grid = TerrainGrid.new()
	grid.grid_width = 8
	grid.grid_height = 8
	add_child_autofree(grid)

func after_each() -> void:
	TilesetGenerator.set_theme_colors(CourseTheme.get_terrain_colors(GameManager.current_theme))

func test_paint_and_bunker_depth_reach_surface_without_changing_save_schema() -> void:
	var pos := Vector2i(3, 3)
	grid.set_tile(pos, TerrainTypes.Type.BUNKER)
	grid.set_bunker_depth(pos, 1)
	var data := grid._course_surface._data.get_pixel(3, 3)
	assert_eq(roundi(data.r * 255.0), TerrainTypes.Type.BUNKER)
	assert_eq(data.g, 1.0)
	assert_eq(grid.serialize()["3,3"], TerrainTypes.Type.BUNKER)
	assert_eq(grid.serialize_bunker_depth()["3,3"], 1)

func test_quiet_generation_and_deserialize_refresh_surface() -> void:
	grid.begin_batch()
	grid.set_tile(Vector2i(0, 0), TerrainTypes.Type.WATER)
	grid.set_tile(Vector2i(7, 7), TerrainTypes.Type.GREEN)
	grid.end_batch_quiet()
	grid.refresh_all_overlays()
	assert_eq(roundi(grid._course_surface._data.get_pixel(0, 0).r * 255.0), TerrainTypes.Type.WATER)
	assert_eq(roundi(grid._course_surface._data.get_pixel(7, 7).r * 255.0), TerrainTypes.Type.GREEN)
	var saved := grid.serialize()
	grid.set_tile(Vector2i(0, 0), TerrainTypes.Type.GRASS)
	grid.deserialize(saved)
	assert_eq(roundi(grid._course_surface._data.get_pixel(0, 0).r * 255.0), TerrainTypes.Type.WATER)

func test_theme_refresh_preserves_terrain_and_player_placement() -> void:
	grid.set_tile(Vector2i(2, 2), TerrainTypes.Type.FAIRWAY)
	var saved := grid.serialize()
	var placed := grid.serialize_player_placed()
	for theme in CourseTheme.Type.values():
		TilesetGenerator.set_theme_colors(CourseTheme.get_terrain_colors(theme))
		grid.regenerate_tileset()
		assert_eq(grid.serialize(), saved)
		assert_eq(grid.serialize_player_placed(), placed)

func test_quick_start_clearing_keeps_painted_surfaces_and_removes_water_trees() -> void:
	var entities := EntityLayer.new()
	entities.map_seed = 2417
	add_child_autofree(entities)
	entities.set_terrain_grid(grid)
	entities.place_tree(Vector2i(2, 2), "oak")
	entities.place_tree(Vector2i(3, 3), "oak")
	entities.place_rock(Vector2i(4, 4), "small")
	grid.set_tile(Vector2i(2, 2), TerrainTypes.Type.FAIRWAY)
	grid.set_tile(Vector2i(3, 3), TerrainTypes.Type.WATER)
	grid.set_tile(Vector2i(4, 4), TerrainTypes.Type.BUNKER)
	QuickStartCourse._clear_entities_on_course(grid, entities)
	assert_true(entities.trees.is_empty())
	assert_true(entities.rocks.is_empty())
	assert_eq(grid.get_tile(Vector2i(2, 2)), TerrainTypes.Type.FAIRWAY)
	assert_eq(grid.get_tile(Vector2i(3, 3)), TerrainTypes.Type.WATER)
	assert_eq(grid.get_tile(Vector2i(4, 4)), TerrainTypes.Type.BUNKER)
