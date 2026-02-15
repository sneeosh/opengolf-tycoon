extends Node2D
class_name TerrainGrid
## TerrainGrid - Manages the isometric tile grid for the golf course

@export var grid_width: int = 128
@export var grid_height: int = 128
@export var tile_width: int = 64
@export var tile_height: int = 32

var _grid: Dictionary = {}
var _elevation_grid: Dictionary = {}  # Vector2i -> int (-5 to +5)
var _player_placed_tiles: Dictionary = {}  # Vector2i -> true for tiles player placed (for maintenance)
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
var _debug_overlay: TerrainDebugOverlay = null
var _noise_overlay: TerrainNoiseOverlay = null

func _ready() -> void:
	_generate_tileset()
	_apply_variation_shader()
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
	_setup_debug_overlay()
	_setup_noise_overlay()

	# Force a complete redraw after one frame to ensure shader is fully applied
	# This fixes the issue where initial tiles don't get shader variation
	call_deferred("_refresh_all_tiles")

func _refresh_all_tiles() -> void:
	# Force redraw of all tiles to ensure shader is applied correctly
	# This is called deferred after _ready() to fix initial tile rendering
	if not tile_map:
		return
	for x in range(grid_width):
		for y in range(grid_height):
			_update_tile_visual(Vector2i(x, y))
	# Also force the TileMapLayer to redraw
	tile_map.queue_redraw()

func _generate_tileset() -> void:
	if not tile_map:
		return
	# Generate expanded textured tileset with autotile variants at runtime
	var texture = TilesetGenerator.generate_expanded_tileset()
	var tileset = TileSet.new()
	tileset.tile_size = Vector2i(tile_width, tile_height)

	var source = TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(tile_width, tile_height)

	# Create tiles for expanded atlas (16 columns, 16 rows)
	for row in range(TilesetGenerator.ATLAS_ROWS):
		for col in range(TilesetGenerator.ATLAS_COLS):
			source.create_tile(Vector2i(col, row))

	tileset.add_source(source)
	tile_map.tile_set = tileset

## Regenerate the tileset (e.g. after theme change)
func regenerate_tileset() -> void:
	_generate_tileset()
	_apply_variation_shader()  # Re-apply shader with new theme colors
	# Re-render all existing tiles
	queue_redraw()
	if tile_map:
		tile_map.queue_redraw()

func _apply_variation_shader() -> void:
	if not tile_map:
		return
	# Check if shader file exists before loading
	if not ResourceLoader.exists("res://shaders/terrain_variation.gdshader"):
		return

	var shader = load("res://shaders/terrain_variation.gdshader")
	if not shader:
		return

	var material = ShaderMaterial.new()
	material.shader = shader

	# Atlas layout for proper tile center sampling
	material.set_shader_parameter("tile_size", Vector2(tile_width, tile_height))
	material.set_shader_parameter("atlas_size", Vector2(
		TilesetGenerator.TILE_WIDTH * TilesetGenerator.ATLAS_COLS,
		TilesetGenerator.TILE_HEIGHT * TilesetGenerator.ATLAS_ROWS
	))

	# Get terrain base colors from theme (shader detects terrain type and uses these)
	var grass = TilesetGenerator.get_color("grass")
	var fairway = TilesetGenerator.get_color("fairway_light")
	var green = TilesetGenerator.get_color("green_light")
	var rough = TilesetGenerator.get_color("rough")
	var heavy_rough = TilesetGenerator.get_color("heavy_rough")

	material.set_shader_parameter("grass_color", Vector3(grass.r, grass.g, grass.b))
	material.set_shader_parameter("fairway_color", Vector3(fairway.r, fairway.g, fairway.b))
	material.set_shader_parameter("green_color", Vector3(green.r, green.g, green.b))
	material.set_shader_parameter("rough_color", Vector3(rough.r, rough.g, rough.b))
	material.set_shader_parameter("heavy_rough_color", Vector3(heavy_rough.r, heavy_rough.g, heavy_rough.b))

	# Procedural variation amounts
	material.set_shader_parameter("hue_variation", 0.04)
	material.set_shader_parameter("value_variation", 0.18)
	material.set_shader_parameter("saturation_variation", 0.06)

	tile_map.material = material

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

func set_tile(pos: Vector2i, terrain_type: int, player_placed: bool = true) -> void:
	if not is_valid_position(pos):
		return
	var old_type = _grid.get(pos, TerrainTypes.Type.EMPTY)
	if old_type == terrain_type:
		return
	_grid[pos] = terrain_type
	# Track player-placed tiles for maintenance cost calculation
	if player_placed:
		_player_placed_tiles[pos] = true
	_update_tile_with_neighbors(pos)
	tile_changed.emit(pos, old_type, terrain_type)
	EventBus.terrain_tile_changed.emit(pos, old_type, terrain_type)

## Set tile without marking as player-placed (for auto-generation)
func set_tile_natural(pos: Vector2i, terrain_type: int) -> void:
	set_tile(pos, terrain_type, false)

func _update_tile_with_neighbors(pos: Vector2i) -> void:
	# Update the tile and all 8 neighbors for seamless autotile transitions
	_update_tile_visual(pos)
	for neighbor in _get_4_neighbors(pos):
		if is_valid_position(neighbor):
			_update_tile_visual(neighbor)

func _get_4_neighbors(pos: Vector2i) -> Array[Vector2i]:
	return [
		pos + Vector2i(0, -1),  # North
		pos + Vector2i(1, 0),   # East
		pos + Vector2i(0, 1),   # South
		pos + Vector2i(-1, 0)   # West
	]

func _calculate_edge_mask(pos: Vector2i, terrain_type: int) -> int:
	# Calculate which edges need transition visuals
	# An edge is marked if the neighbor is a DIFFERENT terrain type
	var edge_mask = 0
	var n_pos = pos + Vector2i(0, -1)
	var e_pos = pos + Vector2i(1, 0)
	var s_pos = pos + Vector2i(0, 1)
	var w_pos = pos + Vector2i(-1, 0)

	if _is_different_terrain(n_pos, terrain_type):
		edge_mask |= TilesetGenerator.EDGE_N
	if _is_different_terrain(e_pos, terrain_type):
		edge_mask |= TilesetGenerator.EDGE_E
	if _is_different_terrain(s_pos, terrain_type):
		edge_mask |= TilesetGenerator.EDGE_S
	if _is_different_terrain(w_pos, terrain_type):
		edge_mask |= TilesetGenerator.EDGE_W

	return edge_mask

func _is_different_terrain(pos: Vector2i, terrain_type: int) -> bool:
	if not is_valid_position(pos):
		return true  # Treat out-of-bounds as different
	var neighbor_type = get_tile(pos)
	if neighbor_type == terrain_type:
		return false
	# Special case: grass family transitions are smooth within family
	var grass_family = [TerrainTypes.Type.GRASS, TerrainTypes.Type.FAIRWAY,
						TerrainTypes.Type.ROUGH, TerrainTypes.Type.HEAVY_ROUGH]
	if terrain_type in grass_family and neighbor_type in grass_family:
		return false
	return true

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
	const YARDS_PER_TILE: float = 22.0
	var distance_tiles = Vector2(to - from).length()
	return int(distance_tiles * YARDS_PER_TILE)

func get_total_maintenance_cost() -> int:
	## Only count maintenance for player-placed tiles, not auto-generated terrain
	var total: int = 0
	for pos in _player_placed_tiles:
		if _grid.has(pos):
			total += TerrainTypes.get_maintenance_cost(_grid[pos])
	return total

func _update_tile_visual(pos: Vector2i) -> void:
	if tile_map:
		var terrain_type = get_tile(pos)
		var edge_mask = 0
		# Only calculate edge mask for autotileable terrains
		if TilesetGenerator.terrain_uses_autotile(terrain_type):
			edge_mask = _calculate_edge_mask(pos, terrain_type)
		var atlas_coords = TilesetGenerator.get_autotile_coords(terrain_type, edge_mask)
		tile_map.set_cell(pos, 0, atlas_coords)

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

func _setup_debug_overlay() -> void:
	_debug_overlay = TerrainDebugOverlay.new()
	_debug_overlay.name = "TerrainDebugOverlay"
	add_child(_debug_overlay)
	_debug_overlay.initialize(self)

func _setup_noise_overlay() -> void:
	# Disabled - noise overlay doesn't help with tile boundary visibility
	# The terrain_variation shader handles all variation
	pass

## Toggle debug overlay visibility
func toggle_debug_overlay() -> void:
	if _debug_overlay:
		_debug_overlay.toggle()

## Check if debug overlay is enabled
func is_debug_overlay_enabled() -> bool:
	return _debug_overlay and _debug_overlay.is_enabled()

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

func serialize_player_placed() -> Array:
	## Serialize player-placed tile positions for maintenance tracking
	var data: Array = []
	for pos in _player_placed_tiles:
		data.append("%d,%d" % [pos.x, pos.y])
	return data

func serialize_elevation() -> Dictionary:
	var data: Dictionary = {}
	for pos in _elevation_grid:
		data["%d,%d" % [pos.x, pos.y]] = _elevation_grid[pos]
	return data

func deserialize(data: Dictionary) -> void:
	_initialize_grid()
	_player_placed_tiles.clear()
	# First pass: set all terrain types
	for key in data:
		var parts = key.split(",")
		if parts.size() == 2:
			var pos = Vector2i(int(parts[0]), int(parts[1]))
			if is_valid_position(pos):
				_grid[pos] = data[key]
	# Second pass: update visuals with correct autotile edges
	for x in range(grid_width):
		for y in range(grid_height):
			_update_tile_visual(Vector2i(x, y))

func deserialize_player_placed(data: Array) -> void:
	## Restore player-placed tile tracking for maintenance
	_player_placed_tiles.clear()
	for key in data:
		var parts = key.split(",")
		if parts.size() == 2:
			var pos = Vector2i(int(parts[0]), int(parts[1]))
			if is_valid_position(pos):
				_player_placed_tiles[pos] = true

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
