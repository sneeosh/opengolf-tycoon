extends Node2D
class_name TreeEntity
## TreeEntity - Represents a tree entity on the course

var grid_position: Vector2i = Vector2i(0, 0)
var tree_type: String = "oak"  # oak, pine, maple, birch

var terrain_grid: TerrainGrid
var tree_data: Dictionary = {}

## Shadow references for updates when sun changes
var _shadow_refs: Dictionary = {}
var _shadow_config: ShadowRenderer.ShadowConfig = null

## Variation data for this tree instance
var _variation: PropVariation.VariationResult = null
var _base_foliage_color: Color = Color.GREEN
var _base_trunk_color: Color = Color(0.4, 0.2, 0.1)

signal tree_selected(tree: TreeEntity)
signal tree_destroyed(tree: TreeEntity)

const TREE_PROPERTIES: Dictionary = {
	"oak": {"name": "Oak Tree", "cost": 20, "height": 3, "width": 2, "color": Color(0.2, 0.5, 0.2), "visual_height": 48.0, "base_width": 32.0},
	"pine": {"name": "Pine Tree", "cost": 18, "height": 4, "width": 1.5, "color": Color(0.15, 0.4, 0.15), "visual_height": 56.0, "base_width": 24.0},
	"maple": {"name": "Maple Tree", "cost": 25, "height": 3.5, "width": 2.5, "color": Color(0.3, 0.5, 0.25), "visual_height": 52.0, "base_width": 36.0},
	"birch": {"name": "Birch Tree", "cost": 22, "height": 3.2, "width": 1.8, "color": Color(0.25, 0.45, 0.2), "visual_height": 50.0, "base_width": 28.0},
}

## Variation parameters per tree type
const TREE_VARIATION: Dictionary = {
	"oak": {"scale": Vector2(0.80, 1.20), "rotation": Vector2(-5.0, 5.0), "hue": Vector2(-0.04, 0.04)},
	"pine": {"scale": Vector2(0.85, 1.15), "rotation": Vector2(-3.0, 3.0), "hue": Vector2(-0.03, 0.03)},
	"maple": {"scale": Vector2(0.82, 1.18), "rotation": Vector2(-6.0, 6.0), "hue": Vector2(-0.05, 0.05)},
	"birch": {"scale": Vector2(0.85, 1.15), "rotation": Vector2(-4.0, 4.0), "hue": Vector2(-0.03, 0.03)},
}

func _ready() -> void:
	add_to_group("trees")

	# Load tree data (only if not already set by set_tree_type)
	if tree_data.is_empty():
		if tree_type in TREE_PROPERTIES:
			tree_data = TREE_PROPERTIES[tree_type].duplicate(true)
		else:
			tree_type = "oak"
			tree_data = TREE_PROPERTIES["oak"].duplicate(true)
		_generate_variation()
		_update_visuals()

	# Connect to sun direction changes if ShadowSystem is available
	if has_node("/root/ShadowSystem"):
		var shadow_system = get_node("/root/ShadowSystem")
		if shadow_system.has_signal("sun_direction_changed"):
			shadow_system.sun_direction_changed.connect(_on_sun_direction_changed)

func set_tree_type(type: String) -> void:
	"""Set the tree type and load its data"""
	tree_type = type
	if tree_type in TREE_PROPERTIES:
		tree_data = TREE_PROPERTIES[tree_type].duplicate(true)
	else:
		tree_type = "oak"
		tree_data = TREE_PROPERTIES["oak"].duplicate(true)

	# Update visuals if already in tree (after _ready was called)
	if is_inside_tree():
		_generate_variation()
		_update_visuals()


func _generate_variation() -> void:
	"""Generate deterministic variation based on grid position"""
	_base_foliage_color = tree_data.get("color", Color.GREEN)
	_base_trunk_color = Color(0.4, 0.2, 0.1)

	# Get variation parameters for this tree type
	var var_params = TREE_VARIATION.get(tree_type, TREE_VARIATION["oak"])

	# Generate variation using position-based seeded randomness
	_variation = PropVariation.generate_custom_variation(
		grid_position,
		var_params["scale"],
		var_params["rotation"],
		var_params["hue"],
		Vector2(-0.1, 0.1),  # Saturation
		Vector2(-0.08, 0.08)  # Value
	)

func _input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tree_selected.emit(self)

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
	tree_destroyed.emit(self)
	queue_free()

func _update_visuals() -> void:
	"""Create visual representation for the tree with shadows and variation"""
	# Remove existing visual if it exists
	if has_node("Visual"):
		get_node("Visual").queue_free()

	# Create a Node2D to hold the visual
	var visual = Node2D.new()
	visual.name = "Visual"
	add_child(visual)

	# Apply variation to foliage color
	var color = _base_foliage_color
	var trunk_color = _base_trunk_color
	if _variation:
		color = _variation.apply_color_shift(_base_foliage_color)
		trunk_color = _variation.apply_color_shift(_base_trunk_color)

	# Configure shadow based on tree type (scale with variation)
	var visual_height = tree_data.get("visual_height", 48.0)
	var base_width = tree_data.get("base_width", 32.0)
	var scale_mult = _variation.scale if _variation else 1.0
	_shadow_config = ShadowRenderer.ShadowConfig.new(visual_height * scale_mult, base_width * scale_mult)
	_shadow_config.base_offset = Vector2(0, 42 * scale_mult)  # Shadow anchored at trunk base

	# Get shadow system reference
	var shadow_system: Node = null
	if has_node("/root/ShadowSystem"):
		shadow_system = get_node("/root/ShadowSystem")

	# Add shadows (rendered below tree)
	_shadow_refs = ShadowRenderer.add_shadows_to_entity(visual, _shadow_config, shadow_system)

	# Draw trunk with variation color
	var trunk = Polygon2D.new()
	trunk.name = "Trunk"
	trunk.color = trunk_color
	trunk.polygon = PackedVector2Array([
		Vector2(-6, 20),
		Vector2(6, 20),
		Vector2(6, 45),
		Vector2(-6, 45)
	])
	visual.add_child(trunk)

	# Draw canopy based on tree type
	match tree_type:
		"oak":
			_draw_oak_canopy(visual, color)
		"pine":
			_draw_pine_canopy(visual, color)
		"maple":
			_draw_maple_canopy(visual, color)
		"birch":
			_draw_birch_canopy(visual, color)
		_:
			_draw_oak_canopy(visual, color)

	# Apply scale and rotation variation to the visual node
	if _variation:
		visual.scale = Vector2(_variation.scale, _variation.scale)
		visual.rotation = _variation.rotation

func _draw_oak_canopy(visual: Node2D, color: Color) -> void:
	"""Draw oak tree canopy - round and full"""
	var canopy = Polygon2D.new()
	canopy.color = color
	# Create a circular canopy - shifted down to overlap trunk (top at y=20)
	var points = PackedVector2Array()
	for i in range(16):
		var angle = (i / 16.0) * TAU
		var x = cos(angle) * 28
		var y = sin(angle) * 22 + 5  # Center at y=5, bottom reaches y=27 to overlap trunk
		points.append(Vector2(x, y))
	canopy.polygon = points
	visual.add_child(canopy)

func _draw_pine_canopy(visual: Node2D, color: Color) -> void:
	"""Draw pine tree canopy - tall and narrow"""
	var canopy = Polygon2D.new()
	canopy.color = color
	canopy.polygon = PackedVector2Array([
		Vector2(0, -35),      # Top point
		Vector2(20, -10),     # Right side
		Vector2(10, 5),
		Vector2(15, 15),
		Vector2(0, 20),
		Vector2(-15, 15),
		Vector2(-10, 5),
		Vector2(-20, -10)
	])
	visual.add_child(canopy)

func _draw_maple_canopy(visual: Node2D, color: Color) -> void:
	"""Draw maple tree canopy - medium and rounded"""
	var canopy = Polygon2D.new()
	canopy.color = color
	canopy.polygon = PackedVector2Array([
		Vector2(0, -25),
		Vector2(22, -15),
		Vector2(28, 0),
		Vector2(22, 18),
		Vector2(8, 32),      # Extended down to overlap trunk
		Vector2(0, 35),      # Bottom center overlaps trunk well
		Vector2(-8, 32),     # Extended down to overlap trunk
		Vector2(-22, 18),
		Vector2(-28, 0),
		Vector2(-22, -15)
	])
	visual.add_child(canopy)

func _draw_birch_canopy(visual: Node2D, color: Color) -> void:
	"""Draw birch tree canopy - light and airy"""
	var canopy1 = Polygon2D.new()
	canopy1.color = color
	canopy1.polygon = PackedVector2Array([
		Vector2(0, -20),
		Vector2(18, -10),
		Vector2(15, 5),
		Vector2(0, 10),
		Vector2(-15, 5),
		Vector2(-18, -10)
	])
	visual.add_child(canopy1)
	
	# Add a lighter section below
	var canopy2 = Polygon2D.new()
	canopy2.color = Color(color.r * 1.2, color.g * 1.2, color.b * 1.2)
	canopy2.polygon = PackedVector2Array([
		Vector2(-10, 5),
		Vector2(10, 5),
		Vector2(12, 18),
		Vector2(0, 20),
		Vector2(-12, 18)
	])
	visual.add_child(canopy2)

func get_tree_info() -> Dictionary:
	var info = {
		"type": tree_type,
		"position": grid_position,
		"cost": tree_data.get("cost", 20),
		"height": tree_data.get("height", 3),
		"width": tree_data.get("width", 2),
		"name": tree_data.get("name", "Tree")
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
