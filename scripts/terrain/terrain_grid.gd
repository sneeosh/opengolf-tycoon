extends Node2D
class_name TerrainGrid
## TerrainGrid - Manages the isometric tile grid for the golf course

@export var grid_width: int = 128
@export var grid_height: int = 128
@export var tile_width: int = 64
@export var tile_height: int = 32

var _grid: Dictionary = {}

@onready var tile_map: TileMapLayer = $TileMapLayer if has_node("TileMapLayer") else null

signal tile_changed(position: Vector2i, old_type: int, new_type: int)

func _ready() -> void:
	_initialize_grid()

func _initialize_grid() -> void:
	for x in range(grid_width):
		for y in range(grid_height):
			var pos = Vector2i(x, y)
			_grid[pos] = TerrainTypes.Type.GRASS
			_update_tile_visual(pos)

func screen_to_grid(screen_pos: Vector2) -> Vector2i:
	# Simple grid conversion for regular tile layout
	return Vector2i(int(floor(screen_pos.x / tile_width)), int(floor(screen_pos.y / tile_height)))

func grid_to_screen(grid_pos: Vector2i) -> Vector2:
	# Simple grid conversion for regular tile layout
	return Vector2(grid_pos.x * tile_width, grid_pos.y * tile_height)

func grid_to_screen_center(grid_pos: Vector2i) -> Vector2:
	# Returns the center of the tile (for entity positioning)
	return Vector2(grid_pos.x * tile_width + tile_width / 2.0, grid_pos.y * tile_height + tile_height / 2.0)

func grid_to_screen_precise(grid_pos: Vector2) -> Vector2:
	# Returns screen position for a sub-tile grid coordinate (used for putting precision)
	return Vector2(grid_pos.x * tile_width + tile_width / 2.0, grid_pos.y * tile_height + tile_height / 2.0)

func is_valid_position(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < grid_width and pos.y >= 0 and pos.y < grid_height

func get_tile(pos: Vector2i) -> int:
	if not is_valid_position(pos):
		return TerrainTypes.Type.OUT_OF_BOUNDS
	return _grid.get(pos, TerrainTypes.Type.EMPTY)

func set_tile(pos: Vector2i, terrain_type: int) -> void:
	if not is_valid_position(pos):
		return
	var old_type = _grid.get(pos, TerrainTypes.Type.EMPTY)
	if old_type == terrain_type:
		return
	_grid[pos] = terrain_type
	_update_tile_visual(pos)
	emit_signal("tile_changed", pos, old_type, terrain_type)
	EventBus.emit_signal("terrain_tile_changed", pos, old_type, terrain_type)

func paint_tiles(positions: Array, terrain_type: int) -> void:
	for pos in positions:
		if pos is Vector2i:
			set_tile(pos, terrain_type)

func get_brush_tiles(center: Vector2i, radius: int) -> Array:
	var tiles: Array = []
	for x in range(-radius, radius + 1):
		for y in range(-radius, radius + 1):
			var offset = Vector2i(x, y)
			var pos = center + offset
			if Vector2(offset).length() <= radius and is_valid_position(pos):
				tiles.append(pos)
	return tiles

func calculate_distance_yards(from: Vector2i, to: Vector2i) -> int:
	const YARDS_PER_TILE: float = 15.0
	var distance_tiles = Vector2(to - from).length()
	return int(distance_tiles * YARDS_PER_TILE)

func get_total_maintenance_cost() -> int:
	var total: int = 0
	for pos in _grid:
		total += TerrainTypes.get_maintenance_cost(_grid[pos])
	return total

func _update_tile_visual(pos: Vector2i) -> void:
	if tile_map:
		var terrain_type = get_tile(pos)
		var atlas_coords = _get_atlas_coords_for_type(terrain_type)
		tile_map.set_cell(pos, 0, atlas_coords)

func _get_atlas_coords_for_type(terrain_type: int) -> Vector2i:
	# Tileset is arranged in a 7-column grid (2 rows)
	# Row 0: EMPTY, GRASS, FAIRWAY, ROUGH, HEAVY_ROUGH, GREEN, TEE_BOX
	# Row 1: BUNKER, WATER, PATH, OUT_OF_BOUNDS, TREES, FLOWER_BED, ROCKS
	const TILES_PER_ROW = 7
	var x = terrain_type % TILES_PER_ROW
	var y = terrain_type / TILES_PER_ROW
	return Vector2i(x, y)

func serialize() -> Dictionary:
	var data: Dictionary = {}
	for pos in _grid:
		if _grid[pos] != TerrainTypes.Type.GRASS:
			data["%d,%d" % [pos.x, pos.y]] = _grid[pos]
	return data

func deserialize(data: Dictionary) -> void:
	_initialize_grid()
	for key in data:
		var parts = key.split(",")
		if parts.size() == 2:
			var pos = Vector2i(int(parts[0]), int(parts[1]))
			if is_valid_position(pos):
				_grid[pos] = data[key]
