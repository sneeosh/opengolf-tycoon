extends Node2D
class_name Rock
## Rock - Represents a decorative rock entity on the course

var grid_position: Vector2i = Vector2i(0, 0)
var rock_size: String = "medium"  # small, medium, large

var terrain_grid: TerrainGrid
var rock_data: Dictionary = {}

## Shadow references for updates when sun changes
var _shadow_refs: Dictionary = {}
var _shadow_config: ShadowRenderer.ShadowConfig = null

## Variation data for this rock instance
var _variation: PropVariation.VariationResult = null
var _base_rock_color: Color = Color.GRAY

signal rock_selected(rock: Rock)
signal rock_destroyed(rock: Rock)

const ROCK_PROPERTIES: Dictionary = {
	"small": {"name": "Small Rock", "cost": 10, "width": 0.5, "height": 0.5, "color": Color(0.6, 0.6, 0.6), "visual_height": 8.0, "base_width": 12.0},
	"medium": {"name": "Medium Rock", "cost": 15, "width": 1.0, "height": 0.8, "color": Color(0.5, 0.5, 0.5), "visual_height": 16.0, "base_width": 20.0},
	"large": {"name": "Large Rock", "cost": 20, "width": 1.5, "height": 1.2, "color": Color(0.55, 0.55, 0.55), "visual_height": 24.0, "base_width": 28.0},
}

## Variation parameters per rock size (rocks have more rotation variety)
const ROCK_VARIATION: Dictionary = {
	"small": {"scale": Vector2(0.85, 1.15), "rotation": Vector2(-20.0, 20.0), "hue": Vector2(-0.02, 0.02)},
	"medium": {"scale": Vector2(0.85, 1.15), "rotation": Vector2(-15.0, 15.0), "hue": Vector2(-0.02, 0.02)},
	"large": {"scale": Vector2(0.88, 1.12), "rotation": Vector2(-10.0, 10.0), "hue": Vector2(-0.02, 0.02)},
}

func _ready() -> void:
	add_to_group("rocks")

	# Load rock data (only if not already set by set_rock_size)
	if rock_data.is_empty():
		if rock_size in ROCK_PROPERTIES:
			rock_data = ROCK_PROPERTIES[rock_size].duplicate(true)
		else:
			rock_size = "medium"
			rock_data = ROCK_PROPERTIES["medium"].duplicate(true)
		_generate_variation()
		_update_visuals()

	# Connect to sun direction changes if ShadowSystem is available
	if has_node("/root/ShadowSystem"):
		var shadow_system = get_node("/root/ShadowSystem")
		if shadow_system.has_signal("sun_direction_changed"):
			shadow_system.sun_direction_changed.connect(_on_sun_direction_changed)

func set_rock_size(size: String) -> void:
	"""Set the rock size and load its data"""
	rock_size = size
	if rock_size in ROCK_PROPERTIES:
		rock_data = ROCK_PROPERTIES[rock_size].duplicate(true)
	else:
		rock_size = "medium"
		rock_data = ROCK_PROPERTIES["medium"].duplicate(true)

	# Update visuals if already in tree (after _ready was called)
	if is_inside_tree():
		_generate_variation()
		_update_visuals()


func _generate_variation() -> void:
	"""Generate deterministic variation based on grid position"""
	# Use theme-tinted rock color if available
	var theme_colors = CourseTheme.get_terrain_colors(GameManager.current_theme)
	if theme_colors.has("rocks"):
		_base_rock_color = theme_colors["rocks"]
	else:
		_base_rock_color = rock_data.get("color", Color.GRAY)

	# Get variation parameters for this rock size
	var var_params = ROCK_VARIATION.get(rock_size, ROCK_VARIATION["medium"])

	# Generate variation using position-based seeded randomness
	# Use a different salt (100) to differentiate from trees at the same position
	_variation = PropVariation.generate_custom_variation(
		grid_position,
		var_params["scale"],
		var_params["rotation"],
		var_params["hue"],
		Vector2(-0.05, 0.05),  # Saturation (rocks are less colorful)
		Vector2(-0.1, 0.1)    # Value (rocks vary more in brightness)
	)

func _input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		rock_selected.emit(self)

func set_terrain_grid(grid: TerrainGrid) -> void:
	terrain_grid = grid

func set_position_in_grid(pos: Vector2i) -> void:
	var old_pos = grid_position
	grid_position = pos
	# Calculate world position from grid position
	if terrain_grid:
		var world_pos = terrain_grid.grid_to_screen(pos)
		global_position = world_pos

	# Regenerate variation if position changed (deterministic based on position)
	if old_pos != pos and is_inside_tree():
		_generate_variation()
		_update_visuals()

func destroy() -> void:
	rock_destroyed.emit(self)
	queue_free()

func _update_visuals() -> void:
	"""Create visual representation for the rock with shadows and variation"""
	# Remove existing visual if it exists
	if has_node("Visual"):
		get_node("Visual").queue_free()

	# Create a Node2D to hold the visual
	var visual = Node2D.new()
	visual.name = "Visual"
	add_child(visual)

	# Apply variation to rock color
	var color = _base_rock_color
	if _variation:
		color = _variation.apply_color_shift(_base_rock_color)

	# Configure shadow based on rock size (scale with variation)
	var visual_height = rock_data.get("visual_height", 16.0)
	var base_width = rock_data.get("base_width", 20.0)
	var scale_mult = _variation.scale if _variation else 1.0
	_shadow_config = ShadowRenderer.ShadowConfig.new(visual_height * scale_mult, base_width * scale_mult)
	_shadow_config.base_offset = Vector2(0, 12 * scale_mult)  # Shadow at rock base

	# Small rocks only get contact shadow (AO), larger rocks get both
	if rock_size == "small":
		_shadow_config.cast_drop_shadow = false

	# Get shadow system reference
	var shadow_system: Node = null
	if has_node("/root/ShadowSystem"):
		shadow_system = get_node("/root/ShadowSystem")

	# Add shadows (rendered below rock)
	_shadow_refs = ShadowRenderer.add_shadows_to_entity(visual, _shadow_config, shadow_system)

	# Draw rock shape based on size
	match rock_size:
		"small":
			_draw_small_rock(visual, color)
		"medium":
			_draw_medium_rock(visual, color)
		"large":
			_draw_large_rock(visual, color)
		_:
			_draw_medium_rock(visual, color)

	# Apply scale and rotation variation to the visual node
	if _variation:
		visual.scale = Vector2(_variation.scale, _variation.scale)
		visual.rotation = _variation.rotation

func _draw_small_rock(visual: Node2D, color: Color) -> void:
	"""Draw a small rock"""
	var rock = Polygon2D.new()
	rock.color = color
	rock.polygon = PackedVector2Array([
		Vector2(-8, 5),
		Vector2(0, -5),
		Vector2(8, 5),
		Vector2(4, 10),
		Vector2(-4, 10)
	])
	visual.add_child(rock)

	# Add highlight
	var highlight = Polygon2D.new()
	highlight.color = Color(color.r * 1.3, color.g * 1.3, color.b * 1.3)
	highlight.polygon = PackedVector2Array([
		Vector2(-4, 2),
		Vector2(0, -3),
		Vector2(4, 2)
	])
	visual.add_child(highlight)

func _draw_medium_rock(visual: Node2D, color: Color) -> void:
	"""Draw a medium rock"""
	var rock = Polygon2D.new()
	rock.color = color
	rock.polygon = PackedVector2Array([
		Vector2(-15, 8),
		Vector2(-10, -8),
		Vector2(0, -10),
		Vector2(12, -5),
		Vector2(15, 8),
		Vector2(8, 15),
		Vector2(-8, 15)
	])
	visual.add_child(rock)

	# Primary highlight — upper-left facet
	var highlight = Polygon2D.new()
	highlight.color = Color(color.r * 1.3, color.g * 1.3, color.b * 1.3)
	highlight.polygon = PackedVector2Array([
		Vector2(-8, 4),
		Vector2(-4, -6),
		Vector2(4, -6),
		Vector2(8, 4)
	])
	visual.add_child(highlight)

	# Secondary highlight — upper-right facet for irregular surface
	var highlight2 = Polygon2D.new()
	highlight2.color = Color(color.r * 1.15, color.g * 1.15, color.b * 1.15)
	highlight2.polygon = PackedVector2Array([
		Vector2(6, -4),
		Vector2(10, -3),
		Vector2(12, 2),
		Vector2(8, 1)
	])
	visual.add_child(highlight2)

	# Moss accent on shadow side (PARKLAND, MOUNTAIN, RESORT themes)
	var theme = GameManager.current_theme
	if theme == CourseTheme.Type.PARKLAND or theme == CourseTheme.Type.MOUNTAIN or theme == CourseTheme.Type.RESORT:
		var moss = Polygon2D.new()
		moss.color = Color(0.3, 0.45, 0.3, 0.5)
		moss.polygon = PackedVector2Array([
			Vector2(-12, 10),
			Vector2(-6, 6),
			Vector2(-2, 8),
			Vector2(-4, 13),
			Vector2(-10, 14)
		])
		visual.add_child(moss)

func _draw_large_rock(visual: Node2D, color: Color) -> void:
	"""Draw a large rock"""
	var rock = Polygon2D.new()
	rock.color = color
	rock.polygon = PackedVector2Array([
		Vector2(-20, 10),
		Vector2(-15, -10),
		Vector2(0, -15),
		Vector2(18, -8),
		Vector2(22, 10),
		Vector2(12, 20),
		Vector2(-12, 20)
	])
	visual.add_child(rock)

	# Primary highlight — upper-left facet
	var highlight = Polygon2D.new()
	highlight.color = Color(color.r * 1.3, color.g * 1.3, color.b * 1.3)
	highlight.polygon = PackedVector2Array([
		Vector2(-10, 5),
		Vector2(-6, -8),
		Vector2(6, -8),
		Vector2(10, 5)
	])
	visual.add_child(highlight)

	# Secondary highlight — right facet
	var highlight2 = Polygon2D.new()
	highlight2.color = Color(color.r * 1.18, color.g * 1.18, color.b * 1.18)
	highlight2.polygon = PackedVector2Array([
		Vector2(10, -6),
		Vector2(16, -5),
		Vector2(18, 4),
		Vector2(12, 2)
	])
	visual.add_child(highlight2)

	# Moss accent on shadow side (PARKLAND, MOUNTAIN, RESORT themes)
	var theme = GameManager.current_theme
	if theme == CourseTheme.Type.PARKLAND or theme == CourseTheme.Type.MOUNTAIN or theme == CourseTheme.Type.RESORT:
		var moss = Polygon2D.new()
		moss.color = Color(0.3, 0.45, 0.3, 0.45)
		moss.polygon = PackedVector2Array([
			Vector2(-16, 14),
			Vector2(-10, 8),
			Vector2(-4, 10),
			Vector2(-2, 16),
			Vector2(-8, 18),
			Vector2(-14, 18)
		])
		visual.add_child(moss)

func get_rock_info() -> Dictionary:
	var info = {
		"size": rock_size,
		"position": grid_position,
		"cost": rock_data.get("cost", 15),
		"width": rock_data.get("width", 1.0),
		"height": rock_data.get("height", 0.8),
		"name": rock_data.get("name", "Rock")
	}
	# Include variation for debugging/inspection (not needed for restore since it's deterministic)
	if _variation:
		info["variation"] = {
			"scale": _variation.scale,
			"rotation_deg": rad_to_deg(_variation.rotation),
			"hue_shift": _variation.hue_shift
		}
	return info

func _on_sun_direction_changed(_new_direction: float) -> void:
	"""Update shadows when sun direction changes"""
	if _shadow_config and not _shadow_refs.is_empty():
		var shadow_system: Node = null
		if has_node("/root/ShadowSystem"):
			shadow_system = get_node("/root/ShadowSystem")
		if shadow_system:
			ShadowRenderer.update_shadows(_shadow_refs, _shadow_config, shadow_system)
