extends Node2D
class_name TreeOverlay
## TreeOverlay - Renders varied, attractive trees on tree tiles

var terrain_grid: TerrainGrid
var _tree_positions: Dictionary = {}  # pos -> tree data

func initialize(grid: TerrainGrid) -> void:
	terrain_grid = grid
	z_index = 10  # Render well above terrain tiles
	_scan_tree_tiles()
	EventBus.terrain_tile_changed.connect(_on_terrain_tile_changed)
	EventBus.load_completed.connect(_on_load_completed)

func _exit_tree() -> void:
	if EventBus.terrain_tile_changed.is_connected(_on_terrain_tile_changed):
		EventBus.terrain_tile_changed.disconnect(_on_terrain_tile_changed)
	if EventBus.load_completed.is_connected(_on_load_completed):
		EventBus.load_completed.disconnect(_on_load_completed)

func _on_load_completed(_success: bool) -> void:
	_scan_tree_tiles()
	queue_redraw()

func _scan_tree_tiles() -> void:
	_tree_positions.clear()
	if not terrain_grid:
		return
	for x in range(terrain_grid.grid_width):
		for y in range(terrain_grid.grid_height):
			var pos = Vector2i(x, y)
			if terrain_grid.get_tile(pos) == TerrainTypes.Type.TREES:
				_generate_tree_for_tile(pos)

func _generate_tree_for_tile(pos: Vector2i) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = pos.x * 73856093 ^ pos.y * 19349663

	# Tree type: 0=pine, 1=oak/deciduous, 2=bushy
	var tree_type = rng.randi_range(0, 2)
	var tree_size = rng.randf_range(0.8, 1.3)
	var tree_offset_x = rng.randf_range(-8, 8)
	var tree_offset_y = rng.randf_range(-4, 4)

	# Color variations
	var green_shift = rng.randf_range(-0.08, 0.08)

	_tree_positions[pos] = {
		"type": tree_type,
		"size": tree_size,
		"offset_x": tree_offset_x,
		"offset_y": tree_offset_y,
		"green_shift": green_shift
	}

func _on_terrain_tile_changed(position: Vector2i, old_type: int, new_type: int) -> void:
	if new_type == TerrainTypes.Type.TREES:
		_generate_tree_for_tile(position)
	elif old_type == TerrainTypes.Type.TREES:
		_tree_positions.erase(position)
	queue_redraw()

func _draw() -> void:
	if not terrain_grid or _tree_positions.is_empty():
		return

	var canvas_transform = get_canvas_transform()
	var viewport_rect = get_viewport_rect()
	var visible_rect = Rect2(
		-canvas_transform.origin / canvas_transform.get_scale(),
		viewport_rect.size / canvas_transform.get_scale()
	)

	for pos in _tree_positions:
		var screen_pos = terrain_grid.grid_to_screen(pos)
		if not visible_rect.has_point(screen_pos):
			continue

		var tree_data = _tree_positions[pos]
		var local_pos = to_local(screen_pos)
		var center = local_pos + Vector2(terrain_grid.tile_width / 2.0 + tree_data.offset_x,
										  terrain_grid.tile_height / 2.0 + tree_data.offset_y)

		match tree_data.type:
			0:
				_draw_pine_tree(center, tree_data)
			1:
				_draw_oak_tree(center, tree_data)
			2:
				_draw_bushy_tree(center, tree_data)

func _draw_pine_tree(center: Vector2, data: Dictionary) -> void:
	var size = data.size * 1.4  # Make trees bigger
	var gs = data.green_shift

	# Shadow on ground
	var shadow_points = PackedVector2Array([
		center + Vector2(-12, 10) * size,
		center + Vector2(12, 10) * size,
		center + Vector2(8, 14) * size,
		center + Vector2(-8, 14) * size
	])
	draw_colored_polygon(shadow_points, Color(0, 0, 0, 0.25))

	# Trunk
	var trunk_color = Color(0.5, 0.35, 0.22)
	var trunk_points = PackedVector2Array([
		center + Vector2(-4, 10) * size,
		center + Vector2(4, 10) * size,
		center + Vector2(3, -4) * size,
		center + Vector2(-3, -4) * size
	])
	draw_colored_polygon(trunk_points, trunk_color)

	# Three layers of foliage (bottom to top) - more vibrant colors
	var foliage_colors = [
		Color(0.15 + gs, 0.45 + gs, 0.18),
		Color(0.18 + gs, 0.52 + gs, 0.22),
		Color(0.22 + gs, 0.58 + gs, 0.26)
	]

	for i in range(3):
		var layer_y = -6 - i * 12
		var layer_width = (22 - i * 5) * size
		var layer_height = 14 * size

		var foliage = PackedVector2Array([
			center + Vector2(-layer_width / 2, layer_y + layer_height),
			center + Vector2(layer_width / 2, layer_y + layer_height),
			center + Vector2(0, layer_y)
		])
		draw_colored_polygon(foliage, foliage_colors[i])

func _draw_oak_tree(center: Vector2, data: Dictionary) -> void:
	var size = data.size * 1.4  # Make trees bigger
	var gs = data.green_shift

	# Shadow on ground
	var shadow_points = PackedVector2Array([
		center + Vector2(-14, 10) * size,
		center + Vector2(14, 10) * size,
		center + Vector2(10, 16) * size,
		center + Vector2(-10, 16) * size
	])
	draw_colored_polygon(shadow_points, Color(0, 0, 0, 0.25))

	# Trunk
	var trunk_color = Color(0.45, 0.32, 0.2)
	var trunk_points = PackedVector2Array([
		center + Vector2(-5, 12) * size,
		center + Vector2(5, 12) * size,
		center + Vector2(4, -6) * size,
		center + Vector2(-4, -6) * size
	])
	draw_colored_polygon(trunk_points, trunk_color)

	# Round, fluffy foliage - more vibrant colors
	var dark_green = Color(0.18 + gs, 0.48 + gs, 0.2)
	var mid_green = Color(0.25 + gs, 0.58 + gs, 0.28)
	var light_green = Color(0.32 + gs, 0.65 + gs, 0.35)

	# Shadow/back layer
	_draw_foliage_blob(center + Vector2(0, -14) * size, 20 * size, dark_green)

	# Main canopy
	_draw_foliage_blob(center + Vector2(-8, -16) * size, 14 * size, mid_green)
	_draw_foliage_blob(center + Vector2(8, -16) * size, 14 * size, mid_green)
	_draw_foliage_blob(center + Vector2(0, -22) * size, 15 * size, mid_green)

	# Highlights
	_draw_foliage_blob(center + Vector2(-5, -20) * size, 10 * size, light_green)
	_draw_foliage_blob(center + Vector2(5, -24) * size, 8 * size, light_green)

func _draw_bushy_tree(center: Vector2, data: Dictionary) -> void:
	var size = data.size * 1.4  # Make trees bigger
	var gs = data.green_shift

	# Shadow on ground
	var shadow_points = PackedVector2Array([
		center + Vector2(-16, 8) * size,
		center + Vector2(16, 8) * size,
		center + Vector2(12, 14) * size,
		center + Vector2(-12, 14) * size
	])
	draw_colored_polygon(shadow_points, Color(0, 0, 0, 0.25))

	# Short trunk
	var trunk_color = Color(0.48, 0.35, 0.22)
	var trunk_points = PackedVector2Array([
		center + Vector2(-4, 10) * size,
		center + Vector2(4, 10) * size,
		center + Vector2(3, 0) * size,
		center + Vector2(-3, 0) * size
	])
	draw_colored_polygon(trunk_points, trunk_color)

	# Wide, bushy foliage - more vibrant
	var dark_green = Color(0.2 + gs, 0.52 + gs, 0.25)
	var light_green = Color(0.3 + gs, 0.62 + gs, 0.32)

	# Base bush shape
	_draw_foliage_blob(center + Vector2(0, -8) * size, 22 * size, dark_green)
	_draw_foliage_blob(center + Vector2(-10, -6) * size, 16 * size, dark_green)
	_draw_foliage_blob(center + Vector2(10, -6) * size, 16 * size, dark_green)

	# Top highlights
	_draw_foliage_blob(center + Vector2(0, -14) * size, 16 * size, light_green)
	_draw_foliage_blob(center + Vector2(-6, -10) * size, 10 * size, light_green)

func _draw_foliage_blob(center: Vector2, radius: float, color: Color) -> void:
	# Draw an irregular blob shape for natural-looking foliage
	var points = PackedVector2Array()
	var segments = 8
	for i in range(segments):
		var angle = i * TAU / segments
		var r = radius * (0.85 + 0.15 * sin(angle * 3))  # Slight irregularity
		points.append(center + Vector2(cos(angle), sin(angle)) * r)
	draw_colored_polygon(points, color)
