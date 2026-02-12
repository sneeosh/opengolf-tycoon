extends Node2D
class_name PlacementPreview
## PlacementPreview - Enhanced placement preview with ghost sprites and validity indication

signal placement_confirmed(grid_pos: Vector2i, placement_type: String)

var terrain_grid: TerrainGrid
var placement_manager: PlacementManager
var camera: IsometricCamera
var current_terrain_tool: int = -1  # Current terrain painting tool
var terrain_painting_enabled: bool = false  # Whether to show terrain preview

# Preview state
var current_grid_pos: Vector2i = Vector2i(-1, -1)
var current_preview_valid: bool = false
var current_preview_positions: Array = []
var current_world_pos: Vector2 = Vector2.ZERO
var smooth_world_pos: Vector2 = Vector2.ZERO

# Visual settings
const VALID_COLOR := Color(0.3, 0.9, 0.3, 0.6)
const INVALID_COLOR := Color(0.9, 0.3, 0.3, 0.6)
const VALID_OUTLINE := Color(0.5, 1.0, 0.5, 0.9)
const INVALID_OUTLINE := Color(1.0, 0.4, 0.4, 0.9)
const BLOCKED_TILE_COLOR := Color(0.8, 0.2, 0.2, 0.4)
const SMOOTH_SPEED := 20.0

# Animation state
var _pulse_time: float = 0.0
var _current_alpha: float = 0.0
var _target_alpha: float = 0.0

func _ready() -> void:
	set_process(true)
	z_index = 100  # Render above terrain

func _process(delta: float) -> void:
	_pulse_time += delta * 3.0

	# Show preview for entity placement OR terrain painting
	var show_entity_preview = placement_manager and placement_manager.placement_mode != PlacementManager.PlacementMode.NONE
	var show_terrain_preview = terrain_painting_enabled and current_terrain_tool >= 0

	if show_entity_preview or show_terrain_preview:
		_target_alpha = 1.0
		_update_preview(delta)
	else:
		_target_alpha = 0.0
		current_preview_positions = []

	# Smooth alpha transition
	_current_alpha = lerp(_current_alpha, _target_alpha, delta * 10.0)

	if _current_alpha > 0.01:
		queue_redraw()

func set_terrain_grid(grid: TerrainGrid) -> void:
	terrain_grid = grid

func set_placement_manager(manager: PlacementManager) -> void:
	placement_manager = manager

func set_camera(cam: IsometricCamera) -> void:
	camera = cam

func set_terrain_tool(tool_type: int) -> void:
	current_terrain_tool = tool_type

func set_terrain_painting_enabled(enabled: bool) -> void:
	terrain_painting_enabled = enabled

func _update_preview(delta: float) -> void:
	if not terrain_grid or not camera:
		return

	var mouse_world = camera.get_mouse_world_position()
	var grid_pos = terrain_grid.screen_to_grid(mouse_world)

	# Smooth world position for fluid movement
	current_world_pos = terrain_grid.grid_to_screen_center(grid_pos)
	smooth_world_pos = smooth_world_pos.lerp(current_world_pos, SMOOTH_SPEED * delta)

	current_grid_pos = grid_pos

	# Get positions to preview based on placement mode
	if placement_manager and placement_manager.placement_mode != PlacementManager.PlacementMode.NONE:
		match placement_manager.placement_mode:
			PlacementManager.PlacementMode.TREE:
				current_preview_positions = [grid_pos]
			PlacementManager.PlacementMode.ROCK:
				current_preview_positions = [grid_pos]
			PlacementManager.PlacementMode.BUILDING:
				current_preview_positions = _get_building_footprint(grid_pos)
			_:
				current_preview_positions = [grid_pos]
		# Check overall validity for entity placement
		current_preview_valid = placement_manager.can_place_at(grid_pos, terrain_grid)
	else:
		# Terrain painting mode - single tile preview
		current_preview_positions = [grid_pos]
		# Terrain is always valid to paint on valid positions
		current_preview_valid = terrain_grid.is_valid_position(grid_pos)

	queue_redraw()

func _get_building_footprint(grid_pos: Vector2i) -> Array:
	var footprint = placement_manager.get_building_footprint()
	var result: Array = []
	for offset in footprint:
		result.append(grid_pos + offset)
	return result

func _draw() -> void:
	if not terrain_grid or _current_alpha < 0.01:
		return

	var is_entity_mode = placement_manager and placement_manager.placement_mode != PlacementManager.PlacementMode.NONE
	var is_terrain_mode = terrain_painting_enabled and current_terrain_tool >= 0

	if not is_entity_mode and not is_terrain_mode:
		return

	# Pulsing effect
	var pulse = 0.85 + sin(_pulse_time) * 0.15
	var alpha_mod = _current_alpha * pulse

	# Draw footprint tiles
	for i in range(current_preview_positions.size()):
		var grid_pos = current_preview_positions[i]
		if terrain_grid.is_valid_position(grid_pos):
			var tile_valid: bool
			if is_entity_mode:
				tile_valid = _is_tile_valid_for_placement(grid_pos)
			else:
				tile_valid = true  # Terrain painting is always valid on valid tiles
			_draw_isometric_tile(grid_pos, tile_valid, alpha_mod, i == 0, is_terrain_mode)

	# Draw entity ghost preview (only for entity placement)
	if is_entity_mode:
		_draw_entity_ghost(alpha_mod)

func _is_tile_valid_for_placement(grid_pos: Vector2i) -> bool:
	if not terrain_grid.is_valid_position(grid_pos):
		return false

	var terrain_type = terrain_grid.get_terrain_at(grid_pos)

	match placement_manager.placement_mode:
		PlacementManager.PlacementMode.TREE:
			return terrain_type in [
				TerrainTypes.Type.GRASS,
				TerrainTypes.Type.FAIRWAY,
				TerrainTypes.Type.ROUGH,
				TerrainTypes.Type.HEAVY_ROUGH,
				TerrainTypes.Type.PATH
			]
		PlacementManager.PlacementMode.ROCK:
			return terrain_type in [
				TerrainTypes.Type.GRASS,
				TerrainTypes.Type.FAIRWAY,
				TerrainTypes.Type.ROUGH,
				TerrainTypes.Type.HEAVY_ROUGH
			]
		PlacementManager.PlacementMode.BUILDING:
			var building_data = placement_manager.building_data
			if building_data and building_data.get("placeable_on_course", false):
				return terrain_type in [
					TerrainTypes.Type.GRASS,
					TerrainTypes.Type.FAIRWAY,
					TerrainTypes.Type.ROUGH,
					TerrainTypes.Type.PATH
				]
			return terrain_type == TerrainTypes.Type.GRASS

	return false

func _draw_isometric_tile(grid_pos: Vector2i, is_valid: bool, alpha_mod: float, is_primary: bool, is_terrain_mode: bool = false) -> void:
	var screen_pos = terrain_grid.grid_to_screen(grid_pos)
	var tw = terrain_grid.tile_width
	var th = terrain_grid.tile_height

	# Fill color based on validity and mode
	var fill_color: Color
	var outline_color: Color

	if is_terrain_mode:
		# Use terrain-specific color for painting preview
		fill_color = _get_terrain_preview_color()
		outline_color = Color(1.0, 1.0, 1.0, 0.8)
	elif is_valid:
		fill_color = VALID_COLOR
		outline_color = VALID_OUTLINE
	else:
		fill_color = INVALID_COLOR if is_primary else BLOCKED_TILE_COLOR
		outline_color = INVALID_OUTLINE

	fill_color.a *= alpha_mod
	outline_color.a *= alpha_mod

	# Draw filled rectangle (matching actual terrain tile shape)
	var rect = Rect2(screen_pos, Vector2(tw, th))
	draw_rect(rect, fill_color)

	# Draw outline
	var outline_width = 2.0 if is_primary else 1.0
	draw_rect(rect, outline_color, false, outline_width)

func _get_terrain_preview_color() -> Color:
	"""Get a preview color based on the current terrain tool"""
	match current_terrain_tool:
		TerrainTypes.Type.FAIRWAY:
			return Color(0.4, 0.8, 0.4, 0.5)  # Light green
		TerrainTypes.Type.ROUGH:
			return Color(0.5, 0.7, 0.3, 0.5)  # Yellow-green
		TerrainTypes.Type.GREEN:
			return Color(0.3, 0.9, 0.5, 0.5)  # Bright green
		TerrainTypes.Type.TEE_BOX:
			return Color(0.4, 0.85, 0.45, 0.5)  # Medium green
		TerrainTypes.Type.BUNKER:
			return Color(0.9, 0.85, 0.6, 0.5)  # Sand color
		TerrainTypes.Type.WATER:
			return Color(0.3, 0.5, 0.9, 0.5)  # Blue
		TerrainTypes.Type.PATH:
			return Color(0.6, 0.55, 0.5, 0.5)  # Brown/gray
		TerrainTypes.Type.OUT_OF_BOUNDS:
			return Color(0.9, 0.3, 0.3, 0.5)  # Red
		TerrainTypes.Type.FLOWER_BED:
			return Color(0.9, 0.5, 0.7, 0.5)  # Pink
		_:
			return Color(0.5, 0.5, 0.5, 0.5)  # Gray default

func _draw_entity_ghost(alpha_mod: float) -> void:
	if current_preview_positions.is_empty():
		return

	var base_pos = terrain_grid.grid_to_screen_center(current_grid_pos)
	var ghost_color = VALID_COLOR if current_preview_valid else INVALID_COLOR
	ghost_color.a = alpha_mod * 0.8

	match placement_manager.placement_mode:
		PlacementManager.PlacementMode.TREE:
			_draw_tree_ghost(base_pos, ghost_color)
		PlacementManager.PlacementMode.ROCK:
			_draw_rock_ghost(base_pos, ghost_color)
		PlacementManager.PlacementMode.BUILDING:
			_draw_building_ghost(base_pos, ghost_color)

func _draw_tree_ghost(pos: Vector2, color: Color) -> void:
	# Draw a simple tree shape
	var trunk_color = Color(0.4, 0.25, 0.1, color.a)
	var foliage_color = color

	# Trunk
	var trunk_width = 6.0
	var trunk_height = 20.0
	draw_rect(Rect2(pos.x - trunk_width/2, pos.y - trunk_height, trunk_width, trunk_height), trunk_color)

	# Foliage (circle shape)
	var foliage_radius = 18.0
	draw_circle(pos + Vector2(0, -trunk_height - foliage_radius * 0.7), foliage_radius, foliage_color)

	# Smaller top circle
	draw_circle(pos + Vector2(0, -trunk_height - foliage_radius * 1.5), foliage_radius * 0.7, foliage_color)

func _draw_rock_ghost(pos: Vector2, color: Color) -> void:
	# Draw a simple rock shape (irregular polygon)
	var rock_color = Color(0.5, 0.5, 0.5, color.a)
	var points = PackedVector2Array([
		pos + Vector2(-12, 0),
		pos + Vector2(-8, -10),
		pos + Vector2(0, -14),
		pos + Vector2(10, -8),
		pos + Vector2(14, 0),
		pos + Vector2(8, 6),
		pos + Vector2(-6, 4)
	])
	draw_colored_polygon(points, rock_color)

	# Highlight
	var highlight = rock_color
	highlight.a *= 0.5
	draw_circle(pos + Vector2(-3, -6), 4, highlight)

func _draw_building_ghost(pos: Vector2, color: Color) -> void:
	# Draw a simple building shape
	var building_color = color
	var roof_color = Color(color.r * 0.7, color.g * 0.7, color.b * 0.7, color.a)

	var footprint = placement_manager.get_building_footprint()
	var width = 1
	var height = 1
	for offset in footprint:
		width = max(width, offset.x + 1)
		height = max(height, offset.y + 1)

	# Scale building visualization
	var base_width = width * 32.0
	var building_height = 30.0

	# Base rectangle
	draw_rect(Rect2(pos.x - base_width/2, pos.y - building_height, base_width, building_height), building_color)

	# Roof (darker)
	var roof_points = PackedVector2Array([
		pos + Vector2(-base_width/2, -building_height),
		pos + Vector2(0, -building_height - 15),
		pos + Vector2(base_width/2, -building_height)
	])
	draw_colored_polygon(roof_points, roof_color)

	# Door
	var door_color = Color(0.3, 0.2, 0.1, color.a)
	draw_rect(Rect2(pos.x - 5, pos.y - 15, 10, 15), door_color)

# =============================================================================
# PUBLIC API
# =============================================================================

func get_preview_valid() -> bool:
	return current_preview_valid

func get_preview_positions() -> Array:
	return current_preview_positions

func get_current_grid_pos() -> Vector2i:
	return current_grid_pos

func confirm_placement() -> void:
	if current_preview_valid and current_grid_pos != Vector2i(-1, -1):
		var placement_type = ""
		match placement_manager.placement_mode:
			PlacementManager.PlacementMode.TREE:
				placement_type = "tree"
			PlacementManager.PlacementMode.ROCK:
				placement_type = "rock"
			PlacementManager.PlacementMode.BUILDING:
				placement_type = "building"
		placement_confirmed.emit(current_grid_pos, placement_type)
