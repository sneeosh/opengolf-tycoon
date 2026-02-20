extends Node2D
class_name BunkerOverlay
## BunkerOverlay - Renders subtle grain/stipple pattern on bunker tiles

var terrain_grid: TerrainGrid
var _bunker_positions: Array = []
var _dot_offsets: Dictionary = {}  # Cached dot positions per tile
var _is_web: bool = false

func initialize(grid: TerrainGrid) -> void:
	terrain_grid = grid
	z_index = 1  # Render just above terrain tiles
	_is_web = OS.get_name() == "Web"
	_scan_bunker_tiles()
	EventBus.terrain_tile_changed.connect(_on_terrain_tile_changed)
	EventBus.load_completed.connect(_on_load_completed)

func _exit_tree() -> void:
	if EventBus.terrain_tile_changed.is_connected(_on_terrain_tile_changed):
		EventBus.terrain_tile_changed.disconnect(_on_terrain_tile_changed)
	if EventBus.load_completed.is_connected(_on_load_completed):
		EventBus.load_completed.disconnect(_on_load_completed)

func _on_load_completed(_success: bool) -> void:
	_scan_bunker_tiles()
	queue_redraw()

func _scan_bunker_tiles() -> void:
	_bunker_positions.clear()
	_dot_offsets.clear()
	if not terrain_grid:
		return
	for x in range(terrain_grid.grid_width):
		for y in range(terrain_grid.grid_height):
			var pos = Vector2i(x, y)
			if terrain_grid.get_tile(pos) == TerrainTypes.Type.BUNKER:
				_bunker_positions.append(pos)
				_generate_dots_for_tile(pos)

func _generate_dots_for_tile(pos: Vector2i) -> void:
	# Generate consistent random dots using position as seed
	var dots: Array = []
	var seed_val = pos.x * 1000 + pos.y
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val

	var dot_count = rng.randi_range(3, 5) if _is_web else rng.randi_range(6, 12)
	for i in range(dot_count):
		var dx = rng.randf_range(4.0, terrain_grid.tile_width - 4.0)
		var dy = rng.randf_range(3.0, terrain_grid.tile_height - 3.0)
		var radius = rng.randf_range(0.8, 1.5)
		dots.append(Vector3(dx, dy, radius))

	_dot_offsets[pos] = dots

func _on_terrain_tile_changed(position: Vector2i, old_type: int, new_type: int) -> void:
	if new_type == TerrainTypes.Type.BUNKER:
		if position not in _bunker_positions:
			_bunker_positions.append(position)
			_generate_dots_for_tile(position)
	elif old_type == TerrainTypes.Type.BUNKER:
		_bunker_positions.erase(position)
		_dot_offsets.erase(position)
	queue_redraw()

func _draw() -> void:
	if not terrain_grid or _bunker_positions.is_empty():
		return

	for pos in _bunker_positions:
		var screen_pos = terrain_grid.grid_to_screen(pos)
		var local_pos = to_local(screen_pos)

		if not _dot_offsets.has(pos):
			continue

		var dots = _dot_offsets[pos]
		for dot in dots:
			var dot_pos = local_pos + Vector2(dot.x, dot.y)
			draw_circle(dot_pos, dot.z, Color(0.75, 0.68, 0.45, 0.35))
