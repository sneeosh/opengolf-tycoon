extends Node2D
class_name PlacementPreview
## PlacementPreview - Enhanced placement preview with ghost sprites and validity indication

signal placement_confirmed(grid_pos: Vector2i, placement_type: String)

var terrain_grid: TerrainGrid
var placement_manager: PlacementManager
var camera: IsometricCamera
var hole_tool: HoleCreationTool  # Reference for hole creation preview
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

	# Show preview for entity placement, terrain painting, OR hole creation
	var show_entity_preview = placement_manager and placement_manager.placement_mode != PlacementManager.PlacementMode.NONE
	var show_terrain_preview = terrain_painting_enabled and current_terrain_tool >= 0
	var show_hole_preview = hole_tool and hole_tool.placement_mode != HoleCreationTool.PlacementMode.NONE

	if show_entity_preview or show_terrain_preview or show_hole_preview:
		_target_alpha = 1.0
		_update_preview(delta)
	else:
		_target_alpha = 0.0
		current_preview_positions = []

	# Smooth alpha transition
	_current_alpha = lerp(_current_alpha, _target_alpha, delta * 10.0)

	if _current_alpha > 0.01 or show_hole_preview:
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

func set_hole_tool(tool: HoleCreationTool) -> void:
	hole_tool = tool

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
	if not terrain_grid:
		return

	# Check for hole creation preview (always draw regardless of alpha)
	if hole_tool and hole_tool.placement_mode != HoleCreationTool.PlacementMode.NONE:
		if hole_tool.placement_mode == HoleCreationTool.PlacementMode.PLACING_TEE:
			_draw_tee_placement_preview()
		else:
			_draw_hole_creation_preview()

	if _current_alpha < 0.01:
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

	var terrain_type = terrain_grid.get_tile(grid_pos)

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
			var building_data = placement_manager.current_placement_data
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
			var top_left = terrain_grid.grid_to_screen(current_grid_pos)
			_draw_building_ghost(top_left, ghost_color)

func _draw_tree_ghost(pos: Vector2, color: Color) -> void:
	var tree_type = placement_manager.selected_tree_type if placement_manager else "oak"
	var props = TreeEntity.TREE_PROPERTIES.get(tree_type, {})
	var base_foliage = props.get("color", Color(0.2, 0.5, 0.2))
	var base_trunk = props.get("trunk_color", Color(0.4, 0.2, 0.1))

	# Generate position-based variation to match what the placed tree will look like
	var var_params = TreeEntity.TREE_VARIATION.get(tree_type, TreeEntity.TREE_VARIATION["oak"])
	var variation = PropVariation.generate_custom_variation(
		current_grid_pos, var_params["scale"], var_params["rotation"], var_params["hue"])

	var scale_v = variation.scale
	var visual_h = props.get("visual_height", 48.0) * scale_v
	var base_w = props.get("base_width", 32.0) * scale_v

	# Apply color variation then blend with ghost tint
	var varied_foliage = variation.apply_color_shift(base_foliage)
	var foliage_color = Color(varied_foliage.r, varied_foliage.g, varied_foliage.b, color.a)
	var varied_trunk = variation.apply_color_shift(base_trunk)
	var trunk_color = Color(varied_trunk.r, varied_trunk.g, varied_trunk.b, color.a)

	# Apply rotation around the base point
	draw_set_transform(pos, variation.rotation)
	# Draw relative to origin (pos is now the transform origin)
	var o = Vector2.ZERO

	if tree_type in TreeEntity.TRUNKLESS_TYPES:
		match tree_type:
			"cactus":
				var body_w = base_w * 0.35
				draw_rect(Rect2(o.x - body_w / 2, o.y - visual_h, body_w, visual_h), foliage_color)
				draw_rect(Rect2(o.x - base_w * 0.45, o.y - visual_h * 0.7, base_w * 0.25, body_w * 0.6), foliage_color)
				draw_rect(Rect2(o.x - base_w * 0.45, o.y - visual_h * 0.85, body_w * 0.5, visual_h * 0.2), foliage_color)
				draw_rect(Rect2(o.x + base_w * 0.2, o.y - visual_h * 0.45, base_w * 0.25, body_w * 0.6), foliage_color)
				draw_rect(Rect2(o.x + base_w * 0.2, o.y - visual_h * 0.6, body_w * 0.5, visual_h * 0.2), foliage_color)
			"fescue":
				for i in range(5):
					var x_off = (i - 2) * base_w * 0.2
					draw_line(o + Vector2(x_off, 0), o + Vector2(x_off, -visual_h), foliage_color, 2.0)
			"cattails":
				for i in range(3):
					var x_off = (i - 1) * 5.0 * scale_v
					draw_line(o + Vector2(x_off, 0), o + Vector2(x_off, -visual_h), foliage_color, 1.5)
					var head_color = Color(varied_trunk.r, varied_trunk.g, varied_trunk.b, color.a)
					draw_rect(Rect2(o.x + x_off - 2 * scale_v, o.y - visual_h - 6 * scale_v, 4 * scale_v, 8 * scale_v), head_color)
			"bush":
				draw_circle(o + Vector2(0, -visual_h * 0.5), base_w * 0.45, foliage_color)
			"heather":
				draw_circle(o + Vector2(0, -visual_h * 0.4), base_w * 0.4, foliage_color)
				var flower_color = Color(0.6, 0.3, 0.6, color.a)
				draw_circle(o + Vector2(-4 * scale_v, -visual_h * 0.6), 3 * scale_v, flower_color)
				draw_circle(o + Vector2(4 * scale_v, -visual_h * 0.5), 2.5 * scale_v, flower_color)
	else:
		var trunk_w = 6.0 * scale_v
		var trunk_h = visual_h * 0.4

		match tree_type:
			"palm":
				trunk_w = 5.0 * scale_v
				trunk_h = visual_h * 0.6
				draw_rect(Rect2(o.x - trunk_w / 2, o.y - trunk_h, trunk_w, trunk_h), trunk_color)
				for angle in [0, 60, 120, 180, 240, 300]:
					var rad = deg_to_rad(angle)
					var tip = o + Vector2(cos(rad) * base_w * 0.5, -trunk_h + sin(rad) * 10 * scale_v - 8 * scale_v)
					draw_line(o + Vector2(0, -trunk_h), tip, foliage_color, 2.5)
			"dead_tree":
				trunk_w = 8.0 * scale_v
				trunk_h = visual_h * 0.5
				draw_rect(Rect2(o.x - trunk_w / 2, o.y - trunk_h, trunk_w, trunk_h), trunk_color)
				var branch_color = Color(varied_trunk.r * 0.95, varied_trunk.g * 0.94, varied_trunk.b * 0.91, color.a)
				draw_line(o + Vector2(0, -trunk_h), o + Vector2(-14 * scale_v, -visual_h), branch_color, 2.0)
				draw_line(o + Vector2(0, -trunk_h), o + Vector2(12 * scale_v, -visual_h * 0.9), branch_color, 2.0)
				draw_line(o + Vector2(0, -trunk_h * 0.8), o + Vector2(-10 * scale_v, -trunk_h * 1.2), branch_color, 1.5)
			"pine":
				draw_rect(Rect2(o.x - trunk_w / 2, o.y - trunk_h, trunk_w, trunk_h), trunk_color)
				var tri = PackedVector2Array([
					o + Vector2(0, -visual_h),
					o + Vector2(-base_w * 0.5, -trunk_h),
					o + Vector2(base_w * 0.5, -trunk_h)
				])
				draw_colored_polygon(tri, foliage_color)
			_:
				draw_rect(Rect2(o.x - trunk_w / 2, o.y - trunk_h, trunk_w, trunk_h), trunk_color)
				var foliage_r = base_w * 0.5
				draw_circle(o + Vector2(0, -trunk_h - foliage_r * 0.7), foliage_r, foliage_color)
				draw_circle(o + Vector2(0, -trunk_h - foliage_r * 1.5), foliage_r * 0.7, foliage_color)

	# Reset transform so subsequent draws aren't affected
	draw_set_transform(Vector2.ZERO, 0.0)

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
	# pos is the top-left screen position of the footprint
	var footprint = placement_manager.get_building_footprint()
	var fw = 1
	var fh = 1
	for offset in footprint:
		fw = max(fw, offset.x + 1)
		fh = max(fh, offset.y + 1)

	var w = fw * 64.0
	var h = fh * 32.0
	var a = color.a
	var building_type = placement_manager.selected_building_type

	match building_type:
		"clubhouse":
			_draw_ghost_clubhouse(pos, w, h, a)
		"pro_shop":
			_draw_ghost_pro_shop(pos, w, h, a)
		"restaurant":
			_draw_ghost_restaurant(pos, w, h, a)
		"snack_bar":
			_draw_ghost_snack_bar(pos, w, h, a)
		"driving_range":
			_draw_ghost_driving_range(pos, w, h, a)
		"cart_shed":
			_draw_ghost_cart_shed(pos, w, h, a)
		"restroom":
			_draw_ghost_restroom(pos, w, h, a)
		"bench":
			_draw_ghost_bench(pos, w, h, a)
		_:
			_draw_ghost_generic(pos, w, h, a)

func _draw_ghost_clubhouse(pos: Vector2, w: float, h: float, a: float) -> void:
	var cx = pos.x + w / 2.0
	# Wall
	draw_rect(Rect2(pos.x, pos.y + h * 0.18, w, h * 0.82), Color(0.96, 0.94, 0.88, a))
	# Roof
	draw_colored_polygon(PackedVector2Array([
		Vector2(pos.x - 6, pos.y + h * 0.16),
		Vector2(cx, pos.y - h * 0.22),
		Vector2(pos.x + w + 6, pos.y + h * 0.16)
	]), Color(0.52, 0.32, 0.26, a))
	# Door
	var dw = w * 0.22
	draw_rect(Rect2(cx - dw / 2.0, pos.y + h * 0.42, dw, h * 0.58), Color(0.48, 0.3, 0.18, a))
	# Windows
	for xr in [0.18, 0.78]:
		draw_rect(Rect2(pos.x + w * xr - 11, pos.y + h * 0.34, 22, 28), Color(0.6, 0.78, 0.88, a))

func _draw_ghost_pro_shop(pos: Vector2, w: float, h: float, a: float) -> void:
	# White building with green awning
	draw_rect(Rect2(pos.x, pos.y + h * 0.15, w, h * 0.85), Color(0.95, 0.95, 0.92, a))
	# Green awning roof
	draw_colored_polygon(PackedVector2Array([
		Vector2(pos.x - 3, pos.y + h * 0.12),
		Vector2(pos.x + w + 3, pos.y + h * 0.12),
		Vector2(pos.x + w + 5, pos.y + h * 0.2),
		Vector2(pos.x - 5, pos.y + h * 0.2)
	]), Color(0.2, 0.5, 0.3, a))
	# Storefront window
	draw_rect(Rect2(pos.x + w * 0.1, pos.y + h * 0.3, w * 0.55, h * 0.55), Color(0.75, 0.88, 0.95, a))
	# Door
	draw_rect(Rect2(pos.x + w * 0.72, pos.y + h * 0.45, w * 0.2, h * 0.55), Color(0.55, 0.4, 0.25, a))

func _draw_ghost_restaurant(pos: Vector2, w: float, h: float, a: float) -> void:
	var cx = pos.x + w / 2.0
	# Warm brick walls
	draw_rect(Rect2(pos.x, pos.y + h * 0.15, w, h * 0.85), Color(0.75, 0.55, 0.45, a))
	# Peaked roof
	draw_colored_polygon(PackedVector2Array([
		Vector2(pos.x - 3, pos.y + h * 0.15),
		Vector2(cx, pos.y - h * 0.15),
		Vector2(pos.x + w + 3, pos.y + h * 0.15)
	]), Color(0.45, 0.3, 0.25, a))
	# Warm glowing windows
	for i in range(3):
		var xo = pos.x + w * (0.18 + i * 0.28)
		draw_rect(Rect2(xo - 11, pos.y + h * 0.38, 22, h * 0.29), Color(1.0, 0.9, 0.6, a * 0.9))
	# Door
	draw_rect(Rect2(pos.x + w * 0.42, pos.y + h * 0.78, w * 0.16, h * 0.22), Color(0.45, 0.3, 0.2, a))

func _draw_ghost_snack_bar(pos: Vector2, w: float, h: float, a: float) -> void:
	# Yellow kiosk
	draw_rect(Rect2(pos.x, pos.y + h * 0.2, w, h * 0.8), Color(0.95, 0.8, 0.3, a))
	# Red striped awning
	draw_colored_polygon(PackedVector2Array([
		Vector2(pos.x - 4, pos.y + h * 0.15),
		Vector2(pos.x + w + 4, pos.y + h * 0.15),
		Vector2(pos.x + w + 6, pos.y + h * 0.28),
		Vector2(pos.x - 6, pos.y + h * 0.28)
	]), Color(0.9, 0.3, 0.2, a))
	# White stripes on awning
	for i in range(5):
		var x1 = pos.x + i * w / 4.5
		draw_rect(Rect2(x1, pos.y + h * 0.16, w / 9, h * 0.11), Color(0.95, 0.95, 0.95, a))
	# Counter window
	draw_rect(Rect2(pos.x + w * 0.1, pos.y + h * 0.35, w * 0.8, h * 0.4), Color(0.25, 0.2, 0.18, a))

func _draw_ghost_driving_range(pos: Vector2, w: float, h: float, a: float) -> void:
	# Green turf outfield
	draw_rect(Rect2(pos.x, pos.y, w, h * 0.35), Color(0.35, 0.65, 0.35, a))
	# Concrete pad
	draw_rect(Rect2(pos.x, pos.y + h * 0.35, w, h * 0.65), Color(0.75, 0.72, 0.68, a))
	# Canopy roof
	draw_colored_polygon(PackedVector2Array([
		Vector2(pos.x - 3, pos.y + h * 0.32),
		Vector2(pos.x + w + 3, pos.y + h * 0.32),
		Vector2(pos.x + w + 5, pos.y + h * 0.42),
		Vector2(pos.x - 5, pos.y + h * 0.42)
	]), Color(0.4, 0.35, 0.3, a))
	# Hitting mats
	for i in range(3):
		var mx = pos.x + w * (0.2 + i * 0.28)
		draw_rect(Rect2(mx - 18, pos.y + h * 0.55, 36, h * 0.35), Color(0.25, 0.55, 0.3, a))

func _draw_ghost_cart_shed(pos: Vector2, w: float, h: float, a: float) -> void:
	# Back wall
	draw_rect(Rect2(pos.x, pos.y + h * 0.15, w, h * 0.45), Color(0.55, 0.48, 0.42, a))
	# Concrete floor
	draw_rect(Rect2(pos.x, pos.y + h * 0.6, w, h * 0.4), Color(0.7, 0.68, 0.65, a))
	# Roof
	draw_colored_polygon(PackedVector2Array([
		Vector2(pos.x - 4, pos.y + h * 0.1),
		Vector2(pos.x + w + 4, pos.y + h * 0.1),
		Vector2(pos.x + w + 6, pos.y + h * 0.22),
		Vector2(pos.x - 6, pos.y + h * 0.22)
	]), Color(0.35, 0.32, 0.28, a))
	# Golf carts
	for i in range(2):
		var cx = pos.x + w * (0.25 + i * 0.45)
		draw_rect(Rect2(cx - 20, pos.y + h * 0.45, 40, h * 0.4), Color(0.95, 0.95, 0.9, a))
		draw_rect(Rect2(cx - 18, pos.y + h * 0.35, 36, h * 0.13), Color(0.3, 0.5, 0.35, a))

func _draw_ghost_restroom(pos: Vector2, w: float, h: float, a: float) -> void:
	# Light gray building
	draw_rect(Rect2(pos.x, pos.y + h * 0.2, w, h * 0.8), Color(0.88, 0.88, 0.85, a))
	# Flat roof
	draw_colored_polygon(PackedVector2Array([
		Vector2(pos.x - 2, pos.y + h * 0.15),
		Vector2(pos.x + w + 2, pos.y + h * 0.15),
		Vector2(pos.x + w + 3, pos.y + h * 0.25),
		Vector2(pos.x - 3, pos.y + h * 0.25)
	]), Color(0.45, 0.42, 0.38, a))
	# Two doors
	for i in range(2):
		var dx = pos.x + w * (0.2 + i * 0.45)
		draw_rect(Rect2(dx - 10, pos.y + h * 0.38, 20, h * 0.62), Color(0.5, 0.45, 0.4, a))
	# Gender signs
	draw_rect(Rect2(pos.x + w * 0.15, pos.y + h * 0.45, w * 0.1, h * 0.13), Color(0.3, 0.5, 0.7, a))
	draw_rect(Rect2(pos.x + w * 0.6, pos.y + h * 0.45, w * 0.1, h * 0.13), Color(0.7, 0.4, 0.5, a))

func _draw_ghost_bench(pos: Vector2, w: float, h: float, a: float) -> void:
	# Metal frame legs
	var frame_color = Color(0.25, 0.25, 0.28, a)
	for xr in [0.18, 0.82]:
		draw_rect(Rect2(pos.x + w * xr - 4, pos.y + h * 0.25, 8, h * 0.7), frame_color)
	# Wooden backrest slats
	for i in range(3):
		var sy = pos.y + h * (0.28 + i * 0.08)
		var c = Color(0.55, 0.38, 0.22, a) if i % 2 == 0 else Color(0.65, 0.48, 0.3, a)
		draw_rect(Rect2(pos.x + w * 0.15, sy, w * 0.7, 5), c)
	# Wooden seat slats
	for i in range(3):
		var sy = pos.y + h * (0.52 + i * 0.1)
		var c = Color(0.55, 0.38, 0.22, a) if i % 2 == 0 else Color(0.65, 0.48, 0.3, a)
		draw_rect(Rect2(pos.x + w * 0.12, sy, w * 0.76, 6), c)

func _draw_ghost_generic(pos: Vector2, w: float, h: float, a: float) -> void:
	# Gray building
	draw_rect(Rect2(pos.x, pos.y + h * 0.2, w, h * 0.8), Color(0.72, 0.7, 0.68, a))
	# Flat roof
	draw_colored_polygon(PackedVector2Array([
		Vector2(pos.x - 2, pos.y + h * 0.15),
		Vector2(pos.x + w + 2, pos.y + h * 0.15),
		Vector2(pos.x + w + 3, pos.y + h * 0.25),
		Vector2(pos.x - 3, pos.y + h * 0.25)
	]), Color(0.5, 0.45, 0.4, a))
	# Window
	draw_rect(Rect2(pos.x + w * 0.3, pos.y + h * 0.35, w * 0.4, h * 0.25), Color(0.7, 0.82, 0.9, a))
	# Door
	draw_rect(Rect2(pos.x + w * 0.4, pos.y + h * 0.65, w * 0.2, h * 0.35), Color(0.45, 0.35, 0.28, a))

func _draw_tee_placement_preview() -> void:
	if not hole_tool or not camera or not terrain_grid:
		return

	var mouse_world = camera.get_mouse_world_position()
	var hover_grid_pos = terrain_grid.screen_to_grid(mouse_world)
	if not terrain_grid.is_valid_position(hover_grid_pos):
		return

	var pulse = 0.7 + sin(_pulse_time) * 0.3
	var tee_color = Color(0.4, 0.85, 0.45, 0.5 * pulse)
	var screen_pos = terrain_grid.grid_to_screen(hover_grid_pos)
	var tw = terrain_grid.tile_width
	var th = terrain_grid.tile_height
	draw_rect(Rect2(screen_pos, Vector2(tw, th)), tee_color)
	draw_rect(Rect2(screen_pos, Vector2(tw, th)), Color(1.0, 1.0, 1.0, 0.7 * pulse), false, 2.0)

	# Label
	var font = ThemeDB.fallback_font
	var center = terrain_grid.grid_to_screen_center(hover_grid_pos)
	draw_string(font, center + Vector2(-28, -20), "Place Tee", HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color(1, 1, 1, 0.9))

func _draw_hole_creation_preview() -> void:
	"""Draw preview line and info label during green placement"""
	if not hole_tool or not camera:
		return

	var tee_pos = hole_tool.pending_tee_position
	if tee_pos == Vector2i(-1, -1):
		return

	# Get current mouse position as potential green position
	var mouse_world = camera.get_mouse_world_position()
	var hover_grid_pos = terrain_grid.screen_to_grid(mouse_world)

	if not terrain_grid.is_valid_position(hover_grid_pos):
		return

	# Calculate positions
	var tee_screen = terrain_grid.grid_to_screen_center(tee_pos)
	var hover_screen = terrain_grid.grid_to_screen_center(hover_grid_pos)
	var midpoint = (tee_screen + hover_screen) / 2.0

	# Calculate distance and par
	const YARDS_PER_TILE: float = 22.0
	var distance_tiles = Vector2(hover_grid_pos - tee_pos).length()
	var distance_yards = int(distance_tiles * YARDS_PER_TILE)
	var par = HoleCreationTool.calculate_par(distance_yards)

	# Check if distance is valid (minimum 5 tiles / 110 yards)
	var is_valid = distance_tiles >= 5

	# Draw connection line
	var line_color = Color(0.3, 1.0, 0.3, 0.7) if is_valid else Color(1.0, 0.3, 0.3, 0.7)
	draw_line(tee_screen, hover_screen, line_color, 3.0, true)

	# Draw dashed effect on the line
	var line_length = tee_screen.distance_to(hover_screen)
	var dash_length = 10.0
	var direction = (hover_screen - tee_screen).normalized()
	var dash_color = Color(1.0, 1.0, 1.0, 0.4)
	var current_dist = 0.0
	var dash_on = true
	while current_dist < line_length:
		if dash_on:
			var start = tee_screen + direction * current_dist
			var end_dist = min(current_dist + dash_length, line_length)
			var end = tee_screen + direction * end_dist
			draw_line(start, end, dash_color, 1.5, true)
		dash_on = not dash_on
		current_dist += dash_length

	# Draw info box at midpoint
	var box_width = 90.0
	var box_height = 50.0
	var box_pos = midpoint - Vector2(box_width / 2, box_height / 2)

	# Background with rounded corners effect
	var bg_color = Color(0.1, 0.1, 0.1, 0.85)
	var border_color = line_color
	draw_rect(Rect2(box_pos, Vector2(box_width, box_height)), bg_color)
	draw_rect(Rect2(box_pos, Vector2(box_width, box_height)), border_color, false, 2.0)

	# Draw text using draw_string
	var font = ThemeDB.fallback_font
	var font_size = 14

	# Par text
	var par_text = "Par %d" % par
	var par_color = Color.WHITE
	draw_string(font, midpoint + Vector2(-20, -8), par_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, par_color)

	# Distance text
	var dist_text = "%d yds" % distance_yards
	var dist_color = Color(0.8, 0.8, 0.8) if is_valid else Color(1.0, 0.5, 0.5)
	draw_string(font, midpoint + Vector2(-22, 12), dist_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, dist_color)

	# Show warning if too short
	if not is_valid:
		var warn_text = "Too short!"
		draw_string(font, midpoint + Vector2(-30, 30), warn_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color(1.0, 0.4, 0.4))

	# Draw green hover preview (single tile — player expands with brush)
	var pulse = 0.7 + sin(_pulse_time) * 0.3
	var green_preview_color = Color(0.3, 0.9, 0.5, 0.4 * pulse) if is_valid else Color(0.9, 0.3, 0.3, 0.4 * pulse)
	if terrain_grid.is_valid_position(hover_grid_pos):
		var screen_pos = terrain_grid.grid_to_screen(hover_grid_pos)
		var tw = terrain_grid.tile_width
		var th = terrain_grid.tile_height
		draw_rect(Rect2(screen_pos, Vector2(tw, th)), green_preview_color)

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
