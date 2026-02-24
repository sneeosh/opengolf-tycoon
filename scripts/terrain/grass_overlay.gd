extends Node2D
class_name GrassOverlay
## GrassOverlay - Adds subtle grass blade patterns to grass-type terrain

var _terrain_grid: TerrainGrid = null
var _grass_positions: Dictionary = {}  # tile_pos -> Array of blade positions
var _is_web: bool = false
# Note: Native GRASS excluded to avoid per-tile blade boundaries creating grid pattern
# The terrain shader provides sufficient procedural variation for GRASS
const GRASS_TYPES = [TerrainTypes.Type.FAIRWAY, TerrainTypes.Type.ROUGH, TerrainTypes.Type.HEAVY_ROUGH]

func _ready() -> void:
	z_index = 1

func setup(terrain_grid: TerrainGrid) -> void:
	_terrain_grid = terrain_grid
	_is_web = OS.get_name() == "Web"
	_regenerate_grass()
	terrain_grid.tile_changed.connect(_on_tile_changed)
	EventBus.theme_changed.connect(_on_theme_changed)
	EventBus.building_placed.connect(_on_building_changed)
	EventBus.building_removed.connect(_on_building_changed)

func _exit_tree() -> void:
	if EventBus.theme_changed.is_connected(_on_theme_changed):
		EventBus.theme_changed.disconnect(_on_theme_changed)
	if EventBus.building_placed.is_connected(_on_building_changed):
		EventBus.building_placed.disconnect(_on_building_changed)
	if EventBus.building_removed.is_connected(_on_building_changed):
		EventBus.building_removed.disconnect(_on_building_changed)

func _on_theme_changed(_theme_type: int) -> void:
	# Regenerate grass with new theme colors
	_regenerate_grass()
	queue_redraw()

func _on_building_changed(_arg1, _arg2 = null) -> void:
	# Regenerate to skip/restore tiles under buildings
	_regenerate_grass()
	queue_redraw()

func _on_tile_changed(pos: Vector2i, _old_type: int, new_type: int) -> void:
	if new_type in GRASS_TYPES:
		var el = GameManager.entity_layer if GameManager else null
		if el and el.is_tile_occupied_by_building(pos):
			_grass_positions.erase(pos)
		else:
			_generate_grass_for_tile(pos)
	else:
		_grass_positions.erase(pos)
	queue_redraw()

func _regenerate_grass() -> void:
	_grass_positions.clear()
	if not _terrain_grid:
		return

	var el = GameManager.entity_layer if GameManager else null
	for x in range(_terrain_grid.grid_width):
		for y in range(_terrain_grid.grid_height):
			var pos = Vector2i(x, y)
			var terrain_type = _terrain_grid.get_tile(pos)
			if terrain_type in GRASS_TYPES:
				if el and el.is_tile_occupied_by_building(pos):
					continue
				_generate_grass_for_tile(pos)

func _get_blade_color_for_terrain(terrain_type: int) -> Color:
	# Get base color from theme via TilesetGenerator
	var base_color: Color
	match terrain_type:
		TerrainTypes.Type.FAIRWAY:
			base_color = TilesetGenerator.get_color("fairway_light")
		TerrainTypes.Type.GREEN:
			base_color = TilesetGenerator.get_color("green_light")
		TerrainTypes.Type.ROUGH:
			base_color = TilesetGenerator.get_color("rough")
		TerrainTypes.Type.HEAVY_ROUGH:
			base_color = TilesetGenerator.get_color("heavy_rough")
		_:  # GRASS
			base_color = TilesetGenerator.get_color("grass")
	# Add transparency for blade rendering
	return Color(base_color.r, base_color.g, base_color.b, 0.4)

func _generate_grass_for_tile(pos: Vector2i) -> void:
	var terrain_type = _terrain_grid.get_tile(pos)
	var blades: Array = []

	# Use position as seed for consistent generation
	var rng = RandomNumberGenerator.new()
	rng.seed = pos.x * 73856093 ^ pos.y * 19349663

	# Different grass density based on terrain type
	var blade_count: int
	var blade_height_range: Vector2
	var blade_color_base: Color = _get_blade_color_for_terrain(terrain_type)

	match terrain_type:
		TerrainTypes.Type.FAIRWAY:
			blade_count = rng.randi_range(4, 7)
			blade_height_range = Vector2(2, 4)
			blade_color_base.a = 0.4
		TerrainTypes.Type.GREEN:
			blade_count = rng.randi_range(6, 10)
			blade_height_range = Vector2(1, 2)
			blade_color_base.a = 0.35
		TerrainTypes.Type.ROUGH:
			blade_count = rng.randi_range(6, 10)
			blade_height_range = Vector2(4, 7)
			blade_color_base.a = 0.45
		TerrainTypes.Type.HEAVY_ROUGH:
			blade_count = rng.randi_range(10, 15)
			blade_height_range = Vector2(6, 10)
			blade_color_base.a = 0.5
		_:  # GRASS
			blade_count = rng.randi_range(5, 8)
			blade_height_range = Vector2(3, 5)
			blade_color_base.a = 0.4

	# Aggressively reduce blade count on web to minimize draw calls
	# With 128x128 grid, even 2 blades per tile = 32k draw_line calls
	if _is_web:
		blade_count = maxi(blade_count / 3, 1)

	for i in range(blade_count):
		var local_x = rng.randf_range(-28, 28)
		var local_y = rng.randf_range(-12, 12)
		var height = rng.randf_range(blade_height_range.x, blade_height_range.y)
		var lean = rng.randf_range(-0.3, 0.3)
		# Slight color variation
		var color_var = rng.randf_range(-0.05, 0.05)
		var color = Color(
			blade_color_base.r + color_var,
			blade_color_base.g + color_var,
			blade_color_base.b + color_var,
			blade_color_base.a
		)
		blades.append({"x": local_x, "y": local_y, "height": height, "lean": lean, "color": color})

	_grass_positions[pos] = blades

func _draw() -> void:
	if not _terrain_grid:
		return

	for pos in _grass_positions:
		var screen_pos = _terrain_grid.grid_to_screen_center(pos)
		var blades = _grass_positions[pos]

		for blade in blades:
			var base = screen_pos + Vector2(blade.x, blade.y)
			var tip = base + Vector2(blade.lean * blade.height, -blade.height)
			draw_line(base, tip, blade.color, 1.0)

func force_redraw() -> void:
	_regenerate_grass()
	queue_redraw()
