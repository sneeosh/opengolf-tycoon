extends Node2D
class_name FlowerOverlay
## FlowerOverlay - Renders colorful flower patterns on flower bed tiles

var terrain_grid: TerrainGrid
var _flower_positions: Dictionary = {}  # pos -> flower data

func initialize(grid: TerrainGrid) -> void:
	terrain_grid = grid
	z_index = 1  # Garden ground cover belongs beneath entities and their shadows
	_scan_flower_tiles()
	EventBus.terrain_tile_changed.connect(_on_terrain_tile_changed)
	EventBus.load_completed.connect(_on_load_completed)
	EventBus.season_changed.connect(_on_season_changed)
	EventBus.theme_changed.connect(_on_theme_changed)

func _exit_tree() -> void:
	EventBus.season_changed.disconnect(_on_season_changed)
	EventBus.theme_changed.disconnect(_on_theme_changed)
	if EventBus.terrain_tile_changed.is_connected(_on_terrain_tile_changed):
		EventBus.terrain_tile_changed.disconnect(_on_terrain_tile_changed)
	if EventBus.load_completed.is_connected(_on_load_completed):
		EventBus.load_completed.disconnect(_on_load_completed)

func _on_load_completed(_success: bool) -> void:
	_scan_flower_tiles()
	queue_redraw()

func _on_season_changed(_old: int, _new: int) -> void:
	_scan_flower_tiles()
	queue_redraw()

func _on_theme_changed(_theme: int) -> void:
	_scan_flower_tiles()
	queue_redraw()

func _season_palette() -> Array:
	var season := SeasonSystem.get_season(GameManager.current_day)
	if GameManager.current_theme in [CourseTheme.Type.TROPICAL, CourseTheme.Type.RESORT]:
		return [Color("f28b91"), Color("ffca68"), Color("f9e5b2")]
	match season:
		SeasonSystem.Season.SPRING:
			return [Color("f4b2c9"), Color("eddfad"), Color("bdb0de")]
		SeasonSystem.Season.SUMMER:
			return [Color("f2c85e"), Color("f18675"), Color("f4ebca")]
		SeasonSystem.Season.FALL:
			return [Color("d79949"), Color("b86553"), Color("dfbc6b")]
		_:
			return [Color("a6b8b0"), Color("beccbd"), Color("92a292")]

func _scan_flower_tiles() -> void:
	_flower_positions.clear()
	if not terrain_grid:
		return
	for x in range(terrain_grid.grid_width):
		for y in range(terrain_grid.grid_height):
			var pos = Vector2i(x, y)
			if terrain_grid.get_tile(pos) == TerrainTypes.Type.FLOWER_BED:
				_generate_flowers_for_tile(pos)

func _generate_flowers_for_tile(pos: Vector2i) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = pos.x * 31337 ^ pos.y * 65537

	var flowers: Array = []
	var flower_count = rng.randi_range(7, 10)
	var dormant := SeasonSystem.get_season(GameManager.current_day) == SeasonSystem.Season.WINTER and GameManager.current_theme not in [CourseTheme.Type.TROPICAL, CourseTheme.Type.RESORT]
	if dormant:
		flower_count = 3
	var seasonal_colors := _season_palette()

	# Pick 1-2 colors for this bed (restrained palette)
	var bed_colors: Array = []
	var color_count = rng.randi_range(1, 2)
	for i in range(color_count):
		bed_colors.append(seasonal_colors[rng.randi_range(0, seasonal_colors.size() - 1)])

	for i in range(flower_count):
		var flower = {
			"x": rng.randf_range(6, terrain_grid.tile_width - 6),
			"y": rng.randf_range(8, terrain_grid.tile_height - 3),
			"size": rng.randf_range(3.5, 5.5),
			"petals": rng.randi_range(4, 6),
			"color": bed_colors[rng.randi_range(0, bed_colors.size() - 1)],
			"rotation": rng.randf_range(0, TAU)
		}
		flowers.append(flower)

	# Layer foliage beneath the blooms
	var foliage: Array = []
	var foliage_count = rng.randi_range(5, 8)
	for i in range(foliage_count):
		foliage.append({
			"x": rng.randf_range(4, terrain_grid.tile_width - 4),
			"y": rng.randf_range(2, terrain_grid.tile_height - 2),
			"size": rng.randf_range(4.5, 7.5)
		})

	_flower_positions[pos] = {"flowers": flowers, "foliage": foliage}

func _on_terrain_tile_changed(position: Vector2i, old_type: int, new_type: int) -> void:
	if new_type == TerrainTypes.Type.FLOWER_BED:
		_generate_flowers_for_tile(position)
	elif old_type == TerrainTypes.Type.FLOWER_BED:
		_flower_positions.erase(position)
	queue_redraw()

func _draw() -> void:
	if not terrain_grid or _flower_positions.is_empty():
		return

	# Viewport culling
	var visible_rect = terrain_grid.get_visible_world_rect()
	var margin = Vector2(terrain_grid.tile_width, terrain_grid.tile_height)
	visible_rect = visible_rect.grow_individual(margin.x, margin.y, margin.x, margin.y)

	for pos in _flower_positions:
		var screen_pos = terrain_grid.grid_to_screen(pos)
		if not visible_rect.has_point(screen_pos):
			continue
		var local_pos = to_local(screen_pos)
		var data = _flower_positions[pos]

		# Draw foliage first (background)
		for leaf in data.foliage:
			_draw_foliage(local_pos, leaf)

		# Draw flowers on top
		for flower in data.flowers:
			_draw_flower(local_pos, flower)

func _draw_foliage(tile_pos: Vector2, leaf: Dictionary) -> void:
	var center = tile_pos + Vector2(leaf.x, leaf.y)
	var size = leaf.size

	var leaf_color := TilesetGenerator.get_color("rough").darkened(0.12)
	draw_set_transform(center, 0.0, Vector2(1.0, 0.55))
	draw_circle(Vector2.ZERO, size, leaf_color)
	draw_circle(Vector2(-size * 0.35, -size * 0.25), size * 0.65, leaf_color.lightened(0.10))
	draw_set_transform(Vector2.ZERO)

func _draw_flower(tile_pos: Vector2, flower: Dictionary) -> void:
	var center = tile_pos + Vector2(flower.x, flower.y)
	var size = flower.size
	var petals = flower.petals
	var color = flower.color
	var rot = flower.rotation

	# Small stems and shaded bases give the bed height without adding nodes.
	draw_line(center + Vector2(0, 4), center + Vector2(0, -1), Color("476336"), 1.0)
	center.y -= 2.0
	draw_circle(center + Vector2(1, 1), size * 0.8, Color(0.19, 0.29, 0.13, 0.28))
	# Draw petals
	for i in range(petals):
		var angle = rot + i * TAU / petals
		var petal_center = center + Vector2(cos(angle), sin(angle)) * size * 0.5
		var petal_size = size * 0.45
		draw_circle(petal_center, petal_size, color)

	# Draw center
	var center_color = Color(0.95, 0.85, 0.3)  # Yellow center
	if color.g > 0.6 and color.r > 0.8:  # If flower is yellow, use brown center
		center_color = Color(0.5, 0.35, 0.2)
	draw_circle(center, size * 0.35, center_color)
