extends Node2D
class_name TerrainGrid
## TerrainGrid - Manages the isometric tile grid for the golf course

@export var grid_width: int = 128
@export var grid_height: int = 128
@export var tile_width: int = 64
@export var tile_height: int = 32

var _grid: Dictionary = {}
var _elevation_grid: Dictionary = {}  # Vector2i -> int (-5 to +5)
var _elevation_overlay: ElevationOverlay = null

@onready var tile_map: TileMapLayer = $TileMapLayer if has_node("TileMapLayer") else null

signal tile_changed(position: Vector2i, old_type: int, new_type: int)
signal elevation_changed(position: Vector2i, old_elevation: int, new_elevation: int)

var _ob_markers_overlay: OBMarkersOverlay = null
var _water_overlay: WaterOverlay = null
var _bunker_overlay: BunkerOverlay = null
var _grass_overlay: GrassOverlay = null
var _fairway_overlay: FairwayOverlay = null
var _tree_overlay: TreeOverlay = null
var _rock_overlay: RockOverlay = null
var _flower_overlay: FlowerOverlay = null
var _path_overlay: PathOverlay = null

func _ready() -> void:
	_generate_tileset()
	_initialize_grid()
	_setup_ob_markers_overlay()
	_setup_water_overlay()
	_setup_bunker_overlay()
	_setup_grass_overlay()
	_setup_fairway_overlay()
	_setup_tree_overlay()
	_setup_rock_overlay()
	_setup_flower_overlay()
	_setup_path_overlay()
	_setup_elevation_overlay()

func _generate_tileset() -> void:
	if not tile_map:
		return
	# Generate textured tileset at runtime
	var texture = TilesetGenerator.generate_tileset()
	var tileset = TileSet.new()
	tileset.tile_size = Vector2i(tile_width, tile_height)

	var source = TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(tile_width, tile_height)

	# Create tiles for each terrain type (7 columns, 2 rows)
	for row in range(2):
		for col in range(7):
			source.create_tile(Vector2i(col, row))

	tileset.add_source(source)
	tile_map.tile_set = tileset

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
	tile_changed.emit(pos, old_type, terrain_type)
	EventBus.terrain_tile_changed.emit(pos, old_type, terrain_type)

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

func _setup_ob_markers_overlay() -> void:
	_ob_markers_overlay = OBMarkersOverlay.new()
	_ob_markers_overlay.name = "OBMarkersOverlay"
	add_child(_ob_markers_overlay)
	_ob_markers_overlay.initialize(self)

func _setup_water_overlay() -> void:
	_water_overlay = WaterOverlay.new()
	_water_overlay.name = "WaterOverlay"
	add_child(_water_overlay)
	_water_overlay.initialize(self)

func _setup_bunker_overlay() -> void:
	_bunker_overlay = BunkerOverlay.new()
	_bunker_overlay.name = "BunkerOverlay"
	add_child(_bunker_overlay)
	_bunker_overlay.initialize(self)

func _setup_grass_overlay() -> void:
	_grass_overlay = GrassOverlay.new()
	_grass_overlay.name = "GrassOverlay"
	add_child(_grass_overlay)
	_grass_overlay.setup(self)

func _setup_fairway_overlay() -> void:
	_fairway_overlay = FairwayOverlay.new()
	_fairway_overlay.name = "FairwayOverlay"
	add_child(_fairway_overlay)
	_fairway_overlay.initialize(self)

func _setup_tree_overlay() -> void:
	_tree_overlay = TreeOverlay.new()
	_tree_overlay.name = "TreeOverlay"
	add_child(_tree_overlay)
	_tree_overlay.initialize(self)

func _setup_rock_overlay() -> void:
	_rock_overlay = RockOverlay.new()
	_rock_overlay.name = "RockOverlay"
	add_child(_rock_overlay)
	_rock_overlay.initialize(self)

func _setup_flower_overlay() -> void:
	_flower_overlay = FlowerOverlay.new()
	_flower_overlay.name = "FlowerOverlay"
	add_child(_flower_overlay)
	_flower_overlay.initialize(self)

func _setup_path_overlay() -> void:
	_path_overlay = PathOverlay.new()
	_path_overlay.name = "PathOverlay"
	add_child(_path_overlay)
	_path_overlay.initialize(self)

func _setup_elevation_overlay() -> void:
	_elevation_overlay = ElevationOverlay.new()
	_elevation_overlay.name = "ElevationOverlay"
	add_child(_elevation_overlay)
	_elevation_overlay.initialize(self)

## Get elevation at a position (default 0)
func get_elevation(pos: Vector2i) -> int:
	return _elevation_grid.get(pos, 0)

## Set elevation at a position (clamped to -5..+5)
func set_elevation(pos: Vector2i, height: int) -> void:
	if not is_valid_position(pos):
		return
	var old_elevation = _elevation_grid.get(pos, 0)
	var new_elevation = clampi(height, -5, 5)
	if old_elevation == new_elevation:
		return
	if new_elevation == 0:
		_elevation_grid.erase(pos)  # Don't store default value
	else:
		_elevation_grid[pos] = new_elevation
	elevation_changed.emit(pos, old_elevation, new_elevation)
	if _elevation_overlay:
		_elevation_overlay.queue_redraw()

## Get elevation difference between two points (positive = uphill from→to)
func get_elevation_difference(from: Vector2i, to: Vector2i) -> int:
	return get_elevation(to) - get_elevation(from)

## Get downhill slope direction at a position (Vector2 pointing downhill)
func get_slope_direction(pos: Vector2i) -> Vector2:
	var current_elev = get_elevation(pos)
	var slope = Vector2.ZERO
	var neighbors = [
		[Vector2i(1, 0), Vector2(1, 0)],
		[Vector2i(-1, 0), Vector2(-1, 0)],
		[Vector2i(0, 1), Vector2(0, 1)],
		[Vector2i(0, -1), Vector2(0, -1)]
	]
	for n in neighbors:
		var neighbor_pos: Vector2i = pos + n[0]
		if is_valid_position(neighbor_pos):
			var diff = current_elev - get_elevation(neighbor_pos)
			if diff > 0:
				slope += n[1] * float(diff)
	return slope.normalized() if slope.length() > 0 else Vector2.ZERO

## Toggle elevation overlay prominence
func set_elevation_overlay_active(active: bool) -> void:
	if _elevation_overlay:
		_elevation_overlay.set_elevation_mode_active(active)

## Get tiles of a given type that are at the boundary (adjacent to a different type)
func get_boundary_tiles(terrain_type: int) -> Array:
	var boundary: Array = []
	for x in range(grid_width):
		for y in range(grid_height):
			var pos = Vector2i(x, y)
			if get_tile(pos) != terrain_type:
				continue
			# Check if any neighbor is a different type
			var neighbors = [
				pos + Vector2i(1, 0), pos + Vector2i(-1, 0),
				pos + Vector2i(0, 1), pos + Vector2i(0, -1)
			]
			for neighbor in neighbors:
				if not is_valid_position(neighbor):
					continue
				if get_tile(neighbor) != terrain_type:
					boundary.append(pos)
					break
	return boundary

## Flood-fill to find all connected tiles of the same type
func get_connected_tiles(start_pos: Vector2i, terrain_type: int) -> Array:
	var connected: Array = []
	var visited: Dictionary = {}
	var queue: Array = [start_pos]

	while queue.size() > 0:
		var pos = queue.pop_front()
		if visited.has(pos):
			continue
		visited[pos] = true

		if not is_valid_position(pos):
			continue
		if get_tile(pos) != terrain_type:
			continue

		connected.append(pos)

		# Check 4 neighbors
		queue.append(pos + Vector2i(1, 0))
		queue.append(pos + Vector2i(-1, 0))
		queue.append(pos + Vector2i(0, 1))
		queue.append(pos + Vector2i(0, -1))

	return connected

## Get tiles in a corridor between two points (for difficulty calculation)
func get_tiles_in_corridor(from: Vector2i, to: Vector2i, width: int) -> Array:
	var tiles: Array = []
	var direction = Vector2(to - from)
	var length = direction.length()
	if length < 1.0:
		return tiles

	var normalized = direction.normalized()
	var perp = Vector2(-normalized.y, normalized.x)
	var half_width = width / 2.0

	var steps = int(length) + 1
	for i in range(steps):
		var t = float(i) / float(max(steps - 1, 1))
		var center = Vector2(from) + direction * t

		for w in range(-int(half_width), int(half_width) + 1):
			var sample_pos = Vector2i(center + perp * float(w))
			if is_valid_position(sample_pos) and sample_pos not in tiles:
				tiles.append(sample_pos)

	return tiles

func serialize() -> Dictionary:
	var data: Dictionary = {}
	for pos in _grid:
		if _grid[pos] != TerrainTypes.Type.GRASS:
			data["%d,%d" % [pos.x, pos.y]] = _grid[pos]
	return data

func serialize_elevation() -> Dictionary:
	var data: Dictionary = {}
	for pos in _elevation_grid:
		data["%d,%d" % [pos.x, pos.y]] = _elevation_grid[pos]
	return data

func deserialize(data: Dictionary) -> void:
	_initialize_grid()
	for key in data:
		var parts = key.split(",")
		if parts.size() == 2:
			var pos = Vector2i(int(parts[0]), int(parts[1]))
			if is_valid_position(pos):
				_grid[pos] = data[key]
				_update_tile_visual(pos)

func deserialize_elevation(data: Dictionary) -> void:
	_elevation_grid.clear()
	for key in data:
		var parts = key.split(",")
		if parts.size() == 2:
			var pos = Vector2i(int(parts[0]), int(parts[1]))
			if is_valid_position(pos):
				_elevation_grid[pos] = data[key]
	if _elevation_overlay:
		_elevation_overlay.queue_redraw()
