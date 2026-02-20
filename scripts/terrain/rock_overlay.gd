extends Node2D
class_name RockOverlay
## RockOverlay - Renders natural-looking rock clusters on rock tiles

var terrain_grid: TerrainGrid
var _rock_positions: Dictionary = {}  # pos -> rock data
var _is_web: bool = false

func initialize(grid: TerrainGrid) -> void:
	terrain_grid = grid
	z_index = 10  # Render well above terrain tiles
	_is_web = OS.get_name() == "Web"
	_scan_rock_tiles()
	EventBus.terrain_tile_changed.connect(_on_terrain_tile_changed)
	EventBus.load_completed.connect(_on_load_completed)

func _exit_tree() -> void:
	if EventBus.terrain_tile_changed.is_connected(_on_terrain_tile_changed):
		EventBus.terrain_tile_changed.disconnect(_on_terrain_tile_changed)
	if EventBus.load_completed.is_connected(_on_load_completed):
		EventBus.load_completed.disconnect(_on_load_completed)

func _on_load_completed(_success: bool) -> void:
	_scan_rock_tiles()
	queue_redraw()

func _scan_rock_tiles() -> void:
	_rock_positions.clear()
	if not terrain_grid:
		return
	for x in range(terrain_grid.grid_width):
		for y in range(terrain_grid.grid_height):
			var pos = Vector2i(x, y)
			if terrain_grid.get_tile(pos) == TerrainTypes.Type.ROCKS:
				_generate_rocks_for_tile(pos)

func _generate_rocks_for_tile(pos: Vector2i) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = pos.x * 48271 ^ pos.y * 16807

	var rocks: Array = []
	var rock_count = rng.randi_range(2, 5)

	for i in range(rock_count):
		var rock = {
			"x": rng.randf_range(8, terrain_grid.tile_width - 8),
			"y": rng.randf_range(4, terrain_grid.tile_height - 4),
			"width": rng.randf_range(8, 18),
			"height": rng.randf_range(5, 12),
			"shade": rng.randf_range(-0.1, 0.1),
			"rotation": rng.randf_range(-0.3, 0.3)
		}
		rocks.append(rock)

	# Sort by y position for proper depth
	rocks.sort_custom(func(a, b): return a.y < b.y)

	_rock_positions[pos] = rocks

func _on_terrain_tile_changed(position: Vector2i, old_type: int, new_type: int) -> void:
	if new_type == TerrainTypes.Type.ROCKS:
		_generate_rocks_for_tile(position)
	elif old_type == TerrainTypes.Type.ROCKS:
		_rock_positions.erase(position)
	queue_redraw()

func _draw() -> void:
	if not terrain_grid or _rock_positions.is_empty():
		return

	for pos in _rock_positions:
		var screen_pos = terrain_grid.grid_to_screen(pos)
		var local_pos = to_local(screen_pos)
		var rocks = _rock_positions[pos]

		for rock in rocks:
			_draw_rock(local_pos, rock)

func _draw_rock(tile_pos: Vector2, rock: Dictionary) -> void:
	var center = tile_pos + Vector2(rock.x, rock.y)
	var w = rock.width
	var h = rock.height
	var shade = rock.shade

	# On web: simplified 2-polygon rocks (skip shadow + specular = 2 fewer draw calls per rock)
	if _is_web:
		var base_gray = 0.45 + shade
		var base_points = _get_rock_shape(center, w, h, rock.rotation)
		draw_colored_polygon(base_points, Color(base_gray, base_gray - 0.02, base_gray - 0.05))
		var highlight_center = center + Vector2(-w * 0.1, -h * 0.2)
		var highlight_points = _get_rock_shape(highlight_center, w * 0.7, h * 0.6, rock.rotation)
		var light_gray = 0.58 + shade
		draw_colored_polygon(highlight_points, Color(light_gray, light_gray - 0.02, light_gray - 0.04))
		return

	# Shadow
	var shadow_points = _get_rock_shape(center + Vector2(2, 2), w, h * 0.6, rock.rotation)
	draw_colored_polygon(shadow_points, Color(0, 0, 0, 0.2))

	# Main rock body (dark base)
	var base_gray = 0.45 + shade
	var base_points = _get_rock_shape(center, w, h, rock.rotation)
	draw_colored_polygon(base_points, Color(base_gray, base_gray - 0.02, base_gray - 0.05))

	# Rock highlight (top surface)
	var highlight_center = center + Vector2(-w * 0.1, -h * 0.2)
	var highlight_points = _get_rock_shape(highlight_center, w * 0.7, h * 0.6, rock.rotation)
	var light_gray = 0.58 + shade
	draw_colored_polygon(highlight_points, Color(light_gray, light_gray - 0.02, light_gray - 0.04))

	# Specular highlight
	var spec_center = center + Vector2(-w * 0.2, -h * 0.35)
	var spec_points = _get_rock_shape(spec_center, w * 0.3, h * 0.25, rock.rotation)
	draw_colored_polygon(spec_points, Color(0.68 + shade, 0.66 + shade, 0.62 + shade))

func _get_rock_shape(center: Vector2, w: float, h: float, rot: float) -> PackedVector2Array:
	# Create an irregular rock shape
	var points = PackedVector2Array()
	var segments = 8

	for i in range(segments):
		var angle = i * TAU / segments + rot
		# Irregular radius with some randomness baked in via sin
		var rx = w / 2 * (0.8 + 0.2 * sin(angle * 2.5 + center.x * 0.1))
		var ry = h / 2 * (0.85 + 0.15 * cos(angle * 3.1 + center.y * 0.1))
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))

	return points
