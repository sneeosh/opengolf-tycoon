extends Node2D
class_name FlowerOverlay
## FlowerOverlay - Renders colorful flower patterns on flower bed tiles

var terrain_grid: TerrainGrid
var _flower_positions: Dictionary = {}  # pos -> flower data

# Flower color palettes
const FLOWER_COLORS = [
	Color(0.95, 0.3, 0.4),   # Red
	Color(0.95, 0.7, 0.2),   # Yellow
	Color(0.95, 0.55, 0.7),  # Pink
	Color(0.6, 0.4, 0.85),   # Purple
	Color(0.95, 0.95, 0.95), # White
	Color(0.95, 0.6, 0.3),   # Orange
]

func initialize(grid: TerrainGrid) -> void:
	terrain_grid = grid
	z_index = 10  # Render well above terrain tiles
	_scan_flower_tiles()
	EventBus.terrain_tile_changed.connect(_on_terrain_tile_changed)
	EventBus.load_completed.connect(_on_load_completed)

func _exit_tree() -> void:
	if EventBus.terrain_tile_changed.is_connected(_on_terrain_tile_changed):
		EventBus.terrain_tile_changed.disconnect(_on_terrain_tile_changed)
	if EventBus.load_completed.is_connected(_on_load_completed):
		EventBus.load_completed.disconnect(_on_load_completed)

func _on_load_completed(_success: bool) -> void:
	_scan_flower_tiles()
	queue_redraw()

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
	var flower_count = rng.randi_range(8, 15)

	# Pick 2-3 colors for this bed (for a cohesive look)
	var bed_colors: Array = []
	var color_count = rng.randi_range(2, 3)
	for i in range(color_count):
		bed_colors.append(FLOWER_COLORS[rng.randi_range(0, FLOWER_COLORS.size() - 1)])

	for i in range(flower_count):
		var flower = {
			"x": rng.randf_range(6, terrain_grid.tile_width - 6),
			"y": rng.randf_range(3, terrain_grid.tile_height - 3),
			"size": rng.randf_range(2.5, 5.0),
			"petals": rng.randi_range(4, 7),
			"color": bed_colors[rng.randi_range(0, bed_colors.size() - 1)],
			"rotation": rng.randf_range(0, TAU)
		}
		flowers.append(flower)

	# Also add some green foliage patches
	var foliage: Array = []
	var foliage_count = rng.randi_range(4, 8)
	for i in range(foliage_count):
		foliage.append({
			"x": rng.randf_range(4, terrain_grid.tile_width - 4),
			"y": rng.randf_range(2, terrain_grid.tile_height - 2),
			"size": rng.randf_range(3, 6)
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

	var canvas_transform = get_canvas_transform()
	var viewport_rect = get_viewport_rect()
	var visible_rect = Rect2(
		-canvas_transform.origin / canvas_transform.get_scale(),
		viewport_rect.size / canvas_transform.get_scale()
	)

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

	# Small green leaf clusters
	var leaf_color = Color(0.3, 0.55, 0.28)
	for i in range(3):
		var angle = i * TAU / 3
		var leaf_center = center + Vector2(cos(angle), sin(angle)) * size * 0.5
		draw_circle(leaf_center, size * 0.4, leaf_color)

func _draw_flower(tile_pos: Vector2, flower: Dictionary) -> void:
	var center = tile_pos + Vector2(flower.x, flower.y)
	var size = flower.size
	var petals = flower.petals
	var color = flower.color
	var rot = flower.rotation

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
