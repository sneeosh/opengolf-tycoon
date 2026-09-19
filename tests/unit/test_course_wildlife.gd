extends GutTest

var grid: TerrainGrid
var _previous_entities

func before_each() -> void:
	_previous_entities = GameManager.entity_layer
	GameManager.entity_layer = null
	grid = TerrainGrid.new()
	grid.grid_width = 16
	grid.grid_height = 16
	add_child_autofree(grid)

func after_each() -> void:
	GameManager.entity_layer = _previous_entities

func test_habitats_are_bounded_repeatable_and_do_not_modify_course_or_rng() -> void:
	grid.begin_batch()
	for x in range(16):
		for y in range(16):
			grid.set_tile(Vector2i(x, y), TerrainTypes.Type.WATER if x < 8 else TerrainTypes.Type.FLOWER_BED)
	grid.end_batch_quiet()
	var saved := grid.serialize()
	seed(9123)
	var expected := randi()
	seed(9123)
	grid._wildlife.rebuild()
	assert_eq(randi(), expected, "Residents must not change simulation randomness")
	var ducks := grid._wildlife._duck_homes.duplicate()
	var gardens := grid._wildlife._garden_homes.duplicate()
	assert_gt(ducks.size(), 0)
	assert_lte(ducks.size(), CourseWildlife.MAX_DUCK_FAMILIES)
	assert_lte(gardens.size(), CourseWildlife.MAX_GARDENS)
	grid._wildlife.rebuild()
	assert_eq(grid._wildlife._duck_homes, ducks)
	assert_eq(grid._wildlife._garden_homes, gardens)
	assert_eq(grid.serialize(), saved)

func test_repainting_a_pond_removes_its_family() -> void:
	for x in range(6, 9):
		for y in range(6, 9):
			grid.set_tile(Vector2i(x, y), TerrainTypes.Type.WATER)
	grid._wildlife._refresh_residents()
	assert_eq(grid._wildlife._duck_homes.size(), 1)
	var home: Vector2i = grid._wildlife._duck_homes[0]
	grid.set_tile(home, TerrainTypes.Type.FAIRWAY)
	grid._wildlife._refresh_residents()
	assert_false(grid._wildlife._duck_homes.has(home))
	grid.deserialize({})
	EventBus.load_completed.emit(true)
	assert_true(grid._wildlife._duck_homes.is_empty(), "Loading a dry course must clear old water residents")

func test_duck_family_route_stays_within_its_water_tile() -> void:
	for step in range(128):
		var offset := CourseWildlife.duck_offset(float(step) / 128.0 * TAU)
		assert_lt(absf(offset.x) + 12.0, 32.0, "Including beak/tail, ducks fit within a 64px water tile")
		assert_lt(absf(offset.y) + 4.0, 16.0, "Waterline stays within the 32px tile")

func test_season_and_weather_control_visitors() -> void:
	assert_true(CourseWildlife.butterflies_active(10.0, SeasonSystem.Season.SUMMER, false))
	assert_false(CourseWildlife.butterflies_active(10.0, SeasonSystem.Season.WINTER, false))
	assert_false(CourseWildlife.butterflies_active(10.0, SeasonSystem.Season.SPRING, true))
	assert_false(CourseWildlife.butterflies_active(19.0, SeasonSystem.Season.SUMMER, false))
	assert_true(CourseWildlife.fireflies_active(19.0, SeasonSystem.Season.SUMMER, false))
	assert_false(CourseWildlife.fireflies_active(10.0, SeasonSystem.Season.SUMMER, false))
	assert_false(CourseWildlife.fireflies_active(19.0, SeasonSystem.Season.WINTER, false))
	assert_false(CourseWildlife.fireflies_active(19.0, SeasonSystem.Season.SUMMER, true))

func test_placed_and_removed_garden_updates_visitors() -> void:
	var entities := EntityLayer.new()
	entities.map_seed = 9123
	add_child_autofree(entities)
	entities.set_terrain_grid(grid)
	GameManager.entity_layer = entities
	var registry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/decorations.json"))["decorations"]
	var pos := Vector2i(8, 8)
	entities.place_decoration("flower_garden", pos, registry)
	assert_true(grid._wildlife._habitats_dirty, "Placement invalidates the habitat cache")
	grid._wildlife._process(0.3 * Engine.time_scale)
	assert_true(grid._wildlife._garden_homes.has(pos))
	entities.remove_decoration(pos)
	assert_true(grid._wildlife._habitats_dirty, "Removal invalidates the habitat cache")
	grid._wildlife._process(0.3 * Engine.time_scale)
	assert_false(grid._wildlife._garden_homes.has(pos))
