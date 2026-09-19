extends GutTest

var grid: TerrainGrid
var entities: EntityLayer
var registry: Dictionary

func before_each() -> void:
	grid = TerrainGrid.new()
	grid.grid_width = 8
	grid.grid_height = 8
	add_child_autofree(grid)
	for x in range(8):
		for y in range(8):
			grid.set_tile(Vector2i(x, y), TerrainTypes.Type.GRASS)
	entities = EntityLayer.new()
	entities.map_seed = 1234
	add_child_autofree(entities)
	entities.set_terrain_grid(grid)
	registry = JSON.parse_string(FileAccess.get_file_as_string("res://data/decorations.json"))["decorations"]

func test_horizontal_and_vertical_walks_keep_furniture_off_center() -> void:
	for x in range(8):
		grid.set_tile(Vector2i(x, 3), TerrainTypes.Type.PATH)
	var bench := entities.place_decoration("park_bench", Vector2i(4, 3), registry)
	assert_eq(bench.get_node("Visual").position, Vector2(0, -10))
	assert_eq(bench.get_node("Visual/PathFurniture").facing, Vector2i.DOWN)
	for y in range(8):
		grid.set_tile(Vector2i(1, y), TerrainTypes.Type.PATH)
	var bin := entities.place_decoration("waste_bin", Vector2i(1, 5), registry)
	assert_eq(bin.get_node("Visual").position, Vector2(-23, 0))
	assert_eq(bin.get_node("Visual/PathFurniture").facing, Vector2i.RIGHT)

func test_edge_choice_avoids_water_and_map_boundary() -> void:
	grid.set_tile(Vector2i(0, 0), TerrainTypes.Type.PATH)
	grid.set_tile(Vector2i(1, 0), TerrainTypes.Type.WATER)
	var layout := PathFurniture.layout(grid, Vector2i.ZERO, "park_bench")
	assert_eq(layout.offset, Vector2(0, 10), "Only the southern edge has a safe verge")
	assert_eq(layout.facing, Vector2i.UP)

func test_repainting_and_quiet_refresh_realign_existing_furniture_without_moving_its_tile() -> void:
	for x in range(8):
		grid.set_tile(Vector2i(x, 3), TerrainTypes.Type.PATH)
	var pos := Vector2i(4, 3)
	var bench := entities.place_decoration("park_bench", pos, registry)
	var saved := bench.get_decoration_info()
	grid.set_tile(pos + Vector2i.UP, TerrainTypes.Type.PATH)
	await get_tree().process_frame
	assert_eq(bench.get_node("Visual").position, Vector2(0, 10))
	assert_eq(bench.get_node("Visual/PathFurniture").facing, Vector2i.UP)
	grid.begin_batch()
	grid.set_tile(pos + Vector2i.UP, TerrainTypes.Type.GRASS)
	grid.end_batch_quiet()
	grid.refresh_all_overlays()
	await get_tree().process_frame
	assert_eq(bench.get_node("Visual").position, Vector2(0, -10))
	assert_eq(bench.get_decoration_info(), saved)
	assert_eq(entities.get_decoration_at(pos), bench, "Selection/removal still resolves the original tile")

func test_plazas_and_large_decorations_retain_their_anchor() -> void:
	for x in range(2, 5):
		for y in range(2, 5):
			grid.set_tile(Vector2i(x, y), TerrainTypes.Type.PATH)
	assert_eq(PathFurniture.layout(grid, Vector2i(3, 3), "park_bench").offset, Vector2.ZERO)
	assert_eq(PathFurniture.layout(grid, Vector2i(3, 2), "fountain").offset, Vector2.ZERO)
	assert_eq(PathFurniture.layout(grid, Vector2i(3, 2), "gazebo").offset, Vector2.ZERO)

func test_sprite_feet_and_animated_details_use_the_same_anchor() -> void:
	for type in ["fountain", "bird_bath", "gazebo", "flower_garden", "topiary"]:
		var dec := entities.place_decoration(type, Vector2i(3, 3), registry)
		var sprite: Sprite2D = dec.get_node("Visual/DecorationSprite")
		var bottom := sprite.texture.get_image().get_used_rect().end.y
		assert_almost_eq(sprite.position.y + bottom - sprite.texture.get_height() * 0.5, 0.0, 0.01, "%s base meets its anchor" % type)
		if type in ["fountain", "bird_bath"]:
			assert_eq(dec.get_node("Visual/Atmosphere").position.y, -5.0 if type == "fountain" else -3.0)
		entities.remove_decoration(Vector2i(3, 3))
		await get_tree().process_frame
