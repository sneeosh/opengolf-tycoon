extends Node2D
class_name FairwayOverlay
## FairwayOverlay - Renders mowing stripe patterns on fairways and greens

var terrain_grid: TerrainGrid
var _fairway_positions: Array = []
var _green_positions: Array = []
const STRIPE_TYPES = [TerrainTypes.Type.FAIRWAY, TerrainTypes.Type.GREEN, TerrainTypes.Type.TEE_BOX]

func initialize(grid: TerrainGrid) -> void:
	terrain_grid = grid
	z_index = 1
	_scan_tiles()
	EventBus.terrain_tile_changed.connect(_on_terrain_tile_changed)
	EventBus.load_completed.connect(_on_load_completed)

func _exit_tree() -> void:
	if EventBus.terrain_tile_changed.is_connected(_on_terrain_tile_changed):
		EventBus.terrain_tile_changed.disconnect(_on_terrain_tile_changed)
	if EventBus.load_completed.is_connected(_on_load_completed):
		EventBus.load_completed.disconnect(_on_load_completed)

func _on_load_completed(_success: bool) -> void:
	_scan_tiles()
	queue_redraw()

func _scan_tiles() -> void:
	_fairway_positions.clear()
	_green_positions.clear()
	if not terrain_grid:
		return
	for x in range(terrain_grid.grid_width):
		for y in range(terrain_grid.grid_height):
			var pos = Vector2i(x, y)
			var tile_type = terrain_grid.get_tile(pos)
			if tile_type == TerrainTypes.Type.FAIRWAY or tile_type == TerrainTypes.Type.TEE_BOX:
				_fairway_positions.append(pos)
			elif tile_type == TerrainTypes.Type.GREEN:
				_green_positions.append(pos)

func _on_terrain_tile_changed(position: Vector2i, old_type: int, new_type: int) -> void:
	# Remove from old lists
	if old_type == TerrainTypes.Type.FAIRWAY or old_type == TerrainTypes.Type.TEE_BOX:
		_fairway_positions.erase(position)
	elif old_type == TerrainTypes.Type.GREEN:
		_green_positions.erase(position)

	# Add to new lists
	if new_type == TerrainTypes.Type.FAIRWAY or new_type == TerrainTypes.Type.TEE_BOX:
		if position not in _fairway_positions:
			_fairway_positions.append(position)
	elif new_type == TerrainTypes.Type.GREEN:
		if position not in _green_positions:
			_green_positions.append(position)

	queue_redraw()

func _draw() -> void:
	if not terrain_grid:
		return

	# Draw fairway stripes (diagonal pattern)
	for pos in _fairway_positions:
		var screen_pos = terrain_grid.grid_to_screen(pos)
		_draw_fairway_stripes(pos, screen_pos)

	# Draw green stripes (concentric/circular pattern for putting greens)
	for pos in _green_positions:
		var screen_pos = terrain_grid.grid_to_screen(pos)
		_draw_green_pattern(pos, screen_pos)

func _draw_fairway_stripes(pos: Vector2i, screen_pos: Vector2) -> void:
	var local_pos = to_local(screen_pos)
	var tw = terrain_grid.tile_width
	var th = terrain_grid.tile_height

	# Alternating stripe pattern based on position (creates diagonal mowing effect)
	var stripe_phase = (pos.x + pos.y) % 2
	var stripe_color: Color

	if stripe_phase == 0:
		stripe_color = Color(0.35, 0.75, 0.35, 0.15)  # Slightly lighter
	else:
		stripe_color = Color(0.3, 0.68, 0.3, 0.12)  # Slightly darker

	# Draw the stripe as a subtle overlay
	draw_rect(Rect2(local_pos, Vector2(tw, th)), stripe_color)

	# Add subtle mowing line details
	var line_color = Color(0.45, 0.82, 0.45, 0.08)
	var line_count = 3
	for i in range(line_count):
		var y_offset = th * (0.2 + i * 0.3)
		var start = local_pos + Vector2(2, y_offset)
		var end = local_pos + Vector2(tw - 2, y_offset)
		draw_line(start, end, line_color, 1.0)

func _draw_green_pattern(pos: Vector2i, screen_pos: Vector2) -> void:
	var local_pos = to_local(screen_pos)
	var tw = terrain_grid.tile_width
	var th = terrain_grid.tile_height
	var center = local_pos + Vector2(tw / 2.0, th / 2.0)

	# Greens have a finer, more manicured pattern
	var stripe_phase = (pos.x + pos.y) % 2
	var stripe_color: Color

	if stripe_phase == 0:
		stripe_color = Color(0.32, 0.85, 0.42, 0.12)
	else:
		stripe_color = Color(0.28, 0.78, 0.38, 0.1)

	draw_rect(Rect2(local_pos, Vector2(tw, th)), stripe_color)

	# Fine horizontal lines for putting green effect
	var line_color = Color(0.4, 0.9, 0.5, 0.06)
	for i in range(4):
		var y_offset = th * (0.15 + i * 0.22)
		var start = local_pos + Vector2(3, y_offset)
		var end = local_pos + Vector2(tw - 3, y_offset)
		draw_line(start, end, line_color, 0.5)
