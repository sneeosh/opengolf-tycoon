extends Node2D
class_name PathOverlay
## PathOverlay - Renders gravel/pebble texture on cart paths

var terrain_grid: TerrainGrid
var _path_positions: Dictionary = {}  # pos -> pebble data
var _is_web: bool = false

func initialize(grid: TerrainGrid) -> void:
	terrain_grid = grid
	z_index = 1
	_is_web = OS.get_name() == "Web"
	_scan_path_tiles()
	EventBus.terrain_tile_changed.connect(_on_terrain_tile_changed)
	EventBus.load_completed.connect(_on_load_completed)

func _exit_tree() -> void:
	if EventBus.terrain_tile_changed.is_connected(_on_terrain_tile_changed):
		EventBus.terrain_tile_changed.disconnect(_on_terrain_tile_changed)
	if EventBus.load_completed.is_connected(_on_load_completed):
		EventBus.load_completed.disconnect(_on_load_completed)

func _on_load_completed(_success: bool) -> void:
	_scan_path_tiles()
	queue_redraw()

func _scan_path_tiles() -> void:
	_path_positions.clear()
	if not terrain_grid:
		return
	for x in range(terrain_grid.grid_width):
		for y in range(terrain_grid.grid_height):
			var pos = Vector2i(x, y)
			if terrain_grid.get_tile(pos) == TerrainTypes.Type.PATH:
				_generate_pebbles_for_tile(pos)

func _generate_pebbles_for_tile(pos: Vector2i) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = pos.x * 12289 ^ pos.y * 24593

	var pebbles: Array = []
	var pebble_count = rng.randi_range(4, 8) if _is_web else rng.randi_range(12, 20)

	for i in range(pebble_count):
		var pebble = {
			"x": rng.randf_range(2, terrain_grid.tile_width - 2),
			"y": rng.randf_range(1, terrain_grid.tile_height - 1),
			"size": rng.randf_range(1.2, 2.8),
			"shade": rng.randf_range(-0.08, 0.08)
		}
		pebbles.append(pebble)

	_path_positions[pos] = pebbles

func _on_terrain_tile_changed(position: Vector2i, old_type: int, new_type: int) -> void:
	if new_type == TerrainTypes.Type.PATH:
		_generate_pebbles_for_tile(position)
	elif old_type == TerrainTypes.Type.PATH:
		_path_positions.erase(position)
	queue_redraw()

func _draw() -> void:
	if not terrain_grid or _path_positions.is_empty():
		return

	for pos in _path_positions:
		var screen_pos = terrain_grid.grid_to_screen(pos)
		var local_pos = to_local(screen_pos)
		var pebbles = _path_positions[pos]

		# Draw path edge lines first
		_draw_path_edges(local_pos, pos)

		# Draw pebble texture
		for pebble in pebbles:
			_draw_pebble(local_pos, pebble)

func _draw_path_edges(tile_pos: Vector2, grid_pos: Vector2i) -> void:
	var tw = terrain_grid.tile_width
	var th = terrain_grid.tile_height

	# Check neighbors to draw edge lines where path meets other terrain
	var edge_color = Color(0.6, 0.58, 0.52, 0.5)

	# Left edge
	if terrain_grid.get_tile(grid_pos + Vector2i(-1, 0)) != TerrainTypes.Type.PATH:
		draw_line(tile_pos + Vector2(1, 0), tile_pos + Vector2(1, th), edge_color, 1.5)

	# Right edge
	if terrain_grid.get_tile(grid_pos + Vector2i(1, 0)) != TerrainTypes.Type.PATH:
		draw_line(tile_pos + Vector2(tw - 1, 0), tile_pos + Vector2(tw - 1, th), edge_color, 1.5)

	# Top edge
	if terrain_grid.get_tile(grid_pos + Vector2i(0, -1)) != TerrainTypes.Type.PATH:
		draw_line(tile_pos + Vector2(0, 1), tile_pos + Vector2(tw, 1), edge_color, 1.5)

	# Bottom edge
	if terrain_grid.get_tile(grid_pos + Vector2i(0, 1)) != TerrainTypes.Type.PATH:
		draw_line(tile_pos + Vector2(0, th - 1), tile_pos + Vector2(tw, th - 1), edge_color, 1.5)

func _draw_pebble(tile_pos: Vector2, pebble: Dictionary) -> void:
	var center = tile_pos + Vector2(pebble.x, pebble.y)
	var base_gray = 0.68 + pebble.shade

	# Small irregular pebble
	draw_circle(center, pebble.size, Color(base_gray, base_gray - 0.02, base_gray - 0.05, 0.4))

	# Tiny highlight (skip on web to reduce draw calls)
	if not _is_web and pebble.size > 2.0:
		draw_circle(center + Vector2(-0.5, -0.5), pebble.size * 0.4, Color(0.82, 0.8, 0.76, 0.3))
