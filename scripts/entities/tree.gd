extends Node2D
class_name TreeEntity
## TreeEntity - Represents a tree or vegetation entity on the course

var grid_position: Vector2i = Vector2i(0, 0)
var tree_type: String = "oak"  # oak, pine, maple, birch, cactus, fescue, cattails, bush, palm, dead_tree, heather

var terrain_grid: TerrainGrid
var tree_data: Dictionary = {}

## Shadow references for updates when sun changes
var _shadow_refs: Dictionary = {}
var _shadow_config: ShadowRenderer.ShadowConfig = null

## Variation data for this tree instance
var _variation: PropVariation.VariationResult = null
var _base_foliage_color: Color = Color.GREEN
var _base_trunk_color: Color = Color(0.35, 0.25, 0.18)

signal tree_selected(tree: TreeEntity)
signal tree_destroyed(tree: TreeEntity)

const TREE_PROPERTIES: Dictionary = {
	# Classic trees
	"oak": {"name": "Oak Tree", "cost": 20, "height": 3, "width": 2, "color": Color(0.2, 0.5, 0.2), "visual_height": 48.0, "base_width": 32.0},
	"pine": {"name": "Pine Tree", "cost": 18, "height": 4, "width": 1.5, "color": Color(0.15, 0.4, 0.15), "visual_height": 56.0, "base_width": 24.0},
	"maple": {"name": "Maple Tree", "cost": 25, "height": 3.5, "width": 2.5, "color": Color(0.3, 0.5, 0.25), "visual_height": 52.0, "base_width": 36.0},
	"birch": {"name": "Birch Tree", "cost": 22, "height": 3.2, "width": 1.8, "color": Color(0.25, 0.45, 0.2), "visual_height": 50.0, "base_width": 28.0},
	# New vegetation types
	"cactus": {"name": "Cactus", "cost": 15, "height": 2.5, "width": 1.0, "color": Color(0.28, 0.55, 0.30), "trunk_color": Color(0.22, 0.48, 0.25), "visual_height": 40.0, "base_width": 18.0, "has_trunk": false},
	"fescue": {"name": "Fescue Grass", "cost": 5, "height": 1.0, "width": 1.2, "color": Color(0.58, 0.55, 0.32), "visual_height": 18.0, "base_width": 20.0, "has_trunk": false},
	"cattails": {"name": "Cattails", "cost": 8, "height": 1.8, "width": 0.8, "color": Color(0.30, 0.48, 0.22), "trunk_color": Color(0.45, 0.30, 0.15), "visual_height": 28.0, "base_width": 14.0, "has_trunk": false},
	"bush": {"name": "Shrub", "cost": 12, "height": 1.2, "width": 1.5, "color": Color(0.22, 0.48, 0.22), "visual_height": 16.0, "base_width": 22.0, "has_trunk": false},
	"palm": {"name": "Palm Tree", "cost": 30, "height": 4.5, "width": 2.0, "color": Color(0.20, 0.58, 0.28), "trunk_color": Color(0.55, 0.40, 0.25), "visual_height": 60.0, "base_width": 28.0},
	"dead_tree": {"name": "Dead Tree", "cost": 10, "height": 3.0, "width": 1.8, "color": Color(0.45, 0.38, 0.28), "trunk_color": Color(0.40, 0.32, 0.22), "visual_height": 44.0, "base_width": 26.0},
	"heather": {"name": "Heather", "cost": 8, "height": 0.8, "width": 1.5, "color": Color(0.55, 0.28, 0.55), "visual_height": 12.0, "base_width": 20.0, "has_trunk": false},
}

## Variation parameters per tree type
const TREE_VARIATION: Dictionary = {
	"oak": {"scale": Vector2(0.80, 1.20), "rotation": Vector2(-5.0, 5.0), "hue": Vector2(-0.04, 0.04)},
	"pine": {"scale": Vector2(0.85, 1.15), "rotation": Vector2(-3.0, 3.0), "hue": Vector2(-0.03, 0.03)},
	"maple": {"scale": Vector2(0.82, 1.18), "rotation": Vector2(-6.0, 6.0), "hue": Vector2(-0.05, 0.05)},
	"birch": {"scale": Vector2(0.85, 1.15), "rotation": Vector2(-4.0, 4.0), "hue": Vector2(-0.03, 0.03)},
	"cactus": {"scale": Vector2(0.75, 1.25), "rotation": Vector2(-3.0, 3.0), "hue": Vector2(-0.03, 0.03)},
	"fescue": {"scale": Vector2(0.70, 1.30), "rotation": Vector2(-8.0, 8.0), "hue": Vector2(-0.05, 0.05)},
	"cattails": {"scale": Vector2(0.80, 1.20), "rotation": Vector2(-5.0, 5.0), "hue": Vector2(-0.03, 0.03)},
	"bush": {"scale": Vector2(0.75, 1.25), "rotation": Vector2(-10.0, 10.0), "hue": Vector2(-0.06, 0.06)},
	"palm": {"scale": Vector2(0.85, 1.15), "rotation": Vector2(-4.0, 4.0), "hue": Vector2(-0.03, 0.03)},
	"dead_tree": {"scale": Vector2(0.80, 1.20), "rotation": Vector2(-6.0, 6.0), "hue": Vector2(-0.02, 0.02)},
	"heather": {"scale": Vector2(0.70, 1.30), "rotation": Vector2(-12.0, 12.0), "hue": Vector2(-0.06, 0.06)},
}

## Types that don't draw a standard tree trunk
const TRUNKLESS_TYPES: Array = ["cactus", "fescue", "cattails", "bush", "heather"]

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
	_base_trunk_color = tree_data.get("trunk_color", Color(0.4, 0.2, 0.1))

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
	# Calculate world position from center of tile
	if terrain_grid:
		var world_pos = terrain_grid.grid_to_screen_center(pos)
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

	# Adjust shadow anchor based on vegetation type
	if tree_type in TRUNKLESS_TYPES:
		_shadow_config.base_offset = Vector2(0, 12 * scale_mult)
		# Small ground vegetation only gets contact shadow
		if visual_height < 20.0:
			_shadow_config.cast_drop_shadow = false
	else:
		_shadow_config.base_offset = Vector2(0, 42 * scale_mult)

	# Get shadow system reference
	var shadow_system: Node = null
	if has_node("/root/ShadowSystem"):
		shadow_system = get_node("/root/ShadowSystem")

	# Add shadows (rendered below tree)
	_shadow_refs = ShadowRenderer.add_shadows_to_entity(visual, _shadow_config, shadow_system)

	# Draw trunk only for types that have one
	if tree_type not in TRUNKLESS_TYPES:
		_draw_trunk(visual, trunk_color)

	# Draw canopy/body based on tree type
	match tree_type:
		"oak":
			_draw_oak_canopy(visual, color)
		"pine":
			_draw_pine_canopy(visual, color)
		"maple":
			_draw_maple_canopy(visual, color)
		"birch":
			_draw_birch_canopy(visual, color)
		"cactus":
			_draw_cactus(visual, color, trunk_color)
		"fescue":
			_draw_fescue(visual, color)
		"cattails":
			_draw_cattails(visual, color, trunk_color)
		"bush":
			_draw_bush(visual, color)
		"palm":
			_draw_palm_canopy(visual, color)
		"dead_tree":
			_draw_dead_tree(visual, color, trunk_color)
		"heather":
			_draw_heather(visual, color)
		_:
			_draw_oak_canopy(visual, color)

	# Apply scale and rotation variation to the visual node
	if _variation:
		visual.scale = Vector2(_variation.scale, _variation.scale)
		visual.rotation = _variation.rotation

func _draw_trunk(visual: Node2D, trunk_color: Color) -> void:
	"""Draw a standard tree trunk with bark texture"""
	var trunk = Polygon2D.new()
	trunk.name = "Trunk"
	trunk.color = trunk_color
	var trunk_top: float = 20.0
	var trunk_bottom: float = 45.0
	match tree_type:
		"palm":
			# Palm trunk: curved, thinner, taller
			trunk.polygon = PackedVector2Array([
				Vector2(-5, 15),
				Vector2(5, 15),
				Vector2(7, 48),
				Vector2(-3, 48)
			])
			trunk_top = 15.0
			trunk_bottom = 48.0
		"dead_tree":
			# Dead tree trunk: slightly wider, gnarled
			trunk.polygon = PackedVector2Array([
				Vector2(-7, 18),
				Vector2(7, 18),
				Vector2(8, 46),
				Vector2(-6, 46)
			])
			trunk_top = 18.0
			trunk_bottom = 46.0
		_:
			# Standard tree trunk
			trunk.polygon = PackedVector2Array([
				Vector2(-6, 20),
				Vector2(6, 20),
				Vector2(6, 45),
				Vector2(-6, 45)
			])
	visual.add_child(trunk)

	# Bark texture lines — 2 thin horizontal darker lines
	var bark_color = trunk_color.darkened(0.08)
	for i in range(2):
		var line_y = trunk_top + (trunk_bottom - trunk_top) * (0.3 + i * 0.35)
		var bark_line = Polygon2D.new()
		bark_line.color = bark_color
		bark_line.polygon = PackedVector2Array([
			Vector2(-4, line_y), Vector2(4, line_y),
			Vector2(4, line_y + 1.5), Vector2(-4, line_y + 1.5)
		])
		visual.add_child(bark_line)


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

	# Crown highlight — lighter ellipse at upper-left (11 o'clock)
	var highlight = Polygon2D.new()
	highlight.color = Color(color.r * 1.2, color.g * 1.2, color.b * 1.15, 0.7)
	var hl_points = PackedVector2Array()
	for i in range(10):
		var angle = (i / 10.0) * TAU
		hl_points.append(Vector2(cos(angle) * 14 - 6, sin(angle) * 10 - 4))
	highlight.polygon = hl_points
	visual.add_child(highlight)

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

	# Left-face highlight strip for volume
	var highlight = Polygon2D.new()
	highlight.color = Color(color.r * 1.2, color.g * 1.2, color.b * 1.1, 0.5)
	highlight.polygon = PackedVector2Array([
		Vector2(-2, -33),
		Vector2(-16, -8),
		Vector2(-8, 4),
		Vector2(-12, 14),
		Vector2(-4, 12),
		Vector2(-4, 0),
		Vector2(-8, -6),
	])
	visual.add_child(highlight)

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

	# Crown highlight — upper-left quadrant
	var highlight = Polygon2D.new()
	highlight.color = Color(color.r * 1.18, color.g * 1.18, color.b * 1.12, 0.6)
	highlight.polygon = PackedVector2Array([
		Vector2(-4, -23),
		Vector2(-18, -12),
		Vector2(-24, 0),
		Vector2(-16, 8),
		Vector2(-6, 2),
		Vector2(-2, -10),
	])
	visual.add_child(highlight)

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

func _draw_cactus(visual: Node2D, color: Color, _trunk_color: Color) -> void:
	"""Draw a saguaro-style cactus with arms"""
	# Main body - tall rounded column
	var body = Polygon2D.new()
	body.color = color
	body.polygon = PackedVector2Array([
		Vector2(-6, -30),     # Top left
		Vector2(0, -34),      # Top center (rounded)
		Vector2(6, -30),      # Top right
		Vector2(7, 12),       # Right side
		Vector2(5, 14),       # Right base
		Vector2(-5, 14),      # Left base
		Vector2(-7, 12),      # Left side
	])
	visual.add_child(body)

	# Left arm - extends from body and curves up
	var left_arm = Polygon2D.new()
	left_arm.color = color
	left_arm.polygon = PackedVector2Array([
		Vector2(-7, -8),      # Attach to body
		Vector2(-16, -6),     # Extend left
		Vector2(-18, -10),    # Bend up
		Vector2(-17, -20),    # Arm top
		Vector2(-14, -22),    # Arm tip (rounded)
		Vector2(-12, -20),    # Right side of arm top
		Vector2(-13, -10),    # Right side down
		Vector2(-7, -4),      # Back to body
	])
	visual.add_child(left_arm)

	# Right arm - shorter, extends right and curves up
	var right_arm = Polygon2D.new()
	right_arm.color = color
	right_arm.polygon = PackedVector2Array([
		Vector2(7, -2),       # Attach to body
		Vector2(14, 0),       # Extend right
		Vector2(15, -4),      # Bend up
		Vector2(14, -14),     # Arm top
		Vector2(11, -16),     # Arm tip (rounded)
		Vector2(9, -14),      # Left side of arm top
		Vector2(10, -4),      # Left side down
		Vector2(7, 2),        # Back to body
	])
	visual.add_child(right_arm)

	# Highlight ridge lines on main body (lighter vertical stripe)
	var ridge = Polygon2D.new()
	ridge.color = Color(color.r * 1.15, color.g * 1.15, color.b * 1.12)
	ridge.polygon = PackedVector2Array([
		Vector2(-2, -32),
		Vector2(2, -32),
		Vector2(2, 12),
		Vector2(-2, 12),
	])
	visual.add_child(ridge)

func _draw_fescue(visual: Node2D, color: Color) -> void:
	"""Draw tall fescue grass - a clump of wavy grass blades"""
	# Multiple grass blades fanning outward
	var blade_data = [
		# [base_x, tip_x, tip_y] - each blade goes from base to tip
		[-8, -12, -18],
		[-5, -7, -22],
		[-2, -1, -24],
		[1, 3, -22],
		[4, 8, -20],
		[7, 13, -16],
		[-3, -5, -20],
		[0, 2, -18],
	]

	for blade in blade_data:
		var grass = Polygon2D.new()
		# Alternate slightly between lighter and darker blades
		var blade_color = color
		if blade[0] % 2 == 0:
			blade_color = Color(color.r * 1.1, color.g * 1.1, color.b * 1.05)
		grass.color = blade_color
		grass.polygon = PackedVector2Array([
			Vector2(blade[0] - 1.5, 6),    # Base left
			Vector2(blade[0] + 1.5, 6),    # Base right
			Vector2(blade[1] + 0.5, blade[2]),  # Tip right
			Vector2(blade[1] - 0.5, blade[2] - 1),  # Tip left
		])
		visual.add_child(grass)

	# Seed heads at top of some blades (small ovals)
	var seed_positions = [Vector2(-7, -18), Vector2(-1, -24), Vector2(3, -22), Vector2(8, -20)]
	for pos in seed_positions:
		var seed_head = Polygon2D.new()
		seed_head.color = Color(color.r * 0.9, color.g * 0.85, color.b * 0.7)
		var points = PackedVector2Array()
		for i in range(6):
			var angle = (i / 6.0) * TAU
			points.append(Vector2(pos.x + cos(angle) * 2.0, pos.y + sin(angle) * 3.5))
		seed_head.polygon = points
		visual.add_child(seed_head)

func _draw_cattails(visual: Node2D, color: Color, head_color: Color) -> void:
	"""Draw cattail reeds - thin stems with distinctive brown oval tops"""
	# Multiple reed stems at slightly different positions
	var stem_data = [
		# [x_offset, height, has_head]
		[-5, -24, true],
		[-1, -28, true],
		[3, -22, true],
		[6, -20, false],
		[-3, -18, false],
		[1, -16, false],
	]

	for stem in stem_data:
		# Draw stem
		var reed = Polygon2D.new()
		reed.color = color
		reed.polygon = PackedVector2Array([
			Vector2(stem[0] - 1, 8),        # Base left
			Vector2(stem[0] + 1, 8),        # Base right
			Vector2(stem[0] + 0.5, stem[1]),  # Top right
			Vector2(stem[0] - 0.5, stem[1] - 1),  # Top left
		])
		visual.add_child(reed)

		# Draw cattail head (brown oval) on taller stems
		if stem[2]:
			var head = Polygon2D.new()
			head.color = head_color
			var points = PackedVector2Array()
			for i in range(8):
				var angle = (i / 8.0) * TAU
				var hx = stem[0] + cos(angle) * 2.5
				var hy = stem[1] - 4 + sin(angle) * 5.0
				points.append(Vector2(hx, hy))
			head.polygon = points
			visual.add_child(head)

	# Small leaf blade at base
	var leaf = Polygon2D.new()
	leaf.color = Color(color.r * 1.1, color.g * 1.1, color.b * 1.0)
	leaf.polygon = PackedVector2Array([
		Vector2(-2, 6),
		Vector2(-8, -8),
		Vector2(-7, -9),
		Vector2(0, 4),
	])
	visual.add_child(leaf)

func _draw_bush(visual: Node2D, color: Color) -> void:
	"""Draw a low rounded shrub"""
	# Main bush body - organic rounded shape
	var body = Polygon2D.new()
	body.color = color
	body.polygon = PackedVector2Array([
		Vector2(-14, 6),      # Left base
		Vector2(-16, 0),      # Left side
		Vector2(-14, -6),     # Upper left
		Vector2(-8, -10),     # Top left
		Vector2(0, -12),      # Top center
		Vector2(8, -10),      # Top right
		Vector2(14, -6),      # Upper right
		Vector2(16, 0),       # Right side
		Vector2(14, 6),       # Right base
		Vector2(0, 8),        # Bottom center
	])
	visual.add_child(body)

	# Highlight bumps on top for volume
	var highlight = Polygon2D.new()
	highlight.color = Color(color.r * 1.15, color.g * 1.2, color.b * 1.1)
	highlight.polygon = PackedVector2Array([
		Vector2(-10, -4),
		Vector2(-6, -9),
		Vector2(0, -10),
		Vector2(6, -8),
		Vector2(2, -4),
		Vector2(-4, -3),
	])
	visual.add_child(highlight)

	# Dark underside for depth
	var shadow_area = Polygon2D.new()
	shadow_area.color = Color(color.r * 0.8, color.g * 0.8, color.b * 0.75)
	shadow_area.polygon = PackedVector2Array([
		Vector2(-12, 4),
		Vector2(-8, 1),
		Vector2(0, 0),
		Vector2(8, 1),
		Vector2(12, 4),
		Vector2(0, 7),
	])
	visual.add_child(shadow_area)

func _draw_palm_canopy(visual: Node2D, color: Color) -> void:
	"""Draw palm tree fronds - fan of long drooping leaves"""
	# Draw 6 fronds radiating from trunk top
	var frond_angles = [-2.2, -1.3, -0.5, 0.3, 1.1, 2.0]

	for fa in frond_angles:
		var frond = Polygon2D.new()
		# Alternate slightly between shades for depth
		if fa < 0:
			frond.color = color
		else:
			frond.color = Color(color.r * 0.9, color.g * 0.92, color.b * 0.88)

		# Each frond is a long leaf shape curving outward and drooping down
		var cx = cos(fa)
		var sy = sin(fa)
		var base_y = 16.0  # Top of trunk
		frond.polygon = PackedVector2Array([
			Vector2(0, base_y),                                        # Base at trunk
			Vector2(cx * 6, base_y - 4),                               # Near base, lifted
			Vector2(cx * 16, base_y - 10 + sy * 4),                   # Mid section, arched up
			Vector2(cx * 24, base_y - 6 + sy * 8),                    # Outer section, starting droop
			Vector2(cx * 28, base_y + 2 + sy * 10),                   # Tip, drooping down
			Vector2(cx * 24, base_y + 4 + sy * 8),                    # Return path (wider)
			Vector2(cx * 16, base_y - 4 + sy * 4),                    # Return mid
			Vector2(cx * 6, base_y + 2),                               # Return near base
		])
		visual.add_child(frond)

	# Central coconut cluster (small brown circles at frond base)
	var coconuts = Polygon2D.new()
	coconuts.color = Color(0.45, 0.30, 0.15)
	var coco_points = PackedVector2Array()
	for i in range(8):
		var angle = (i / 8.0) * TAU
		coco_points.append(Vector2(cos(angle) * 4, 14 + sin(angle) * 3))
	coconuts.polygon = coco_points
	visual.add_child(coconuts)

func _draw_dead_tree(visual: Node2D, color: Color, _trunk_color: Color) -> void:
	"""Draw a dead/bare tree with exposed branches"""
	# Main branches extending from trunk top
	# Left branch
	var branch_l = Polygon2D.new()
	branch_l.color = color
	branch_l.polygon = PackedVector2Array([
		Vector2(-4, 20),       # Trunk connection
		Vector2(-18, 2),       # Branch extends left-up
		Vector2(-22, -4),      # Branch tip
		Vector2(-20, -2),      # Thin tip return
		Vector2(-15, 4),       # Return path
		Vector2(-2, 22),       # Back to trunk
	])
	visual.add_child(branch_l)

	# Right branch
	var branch_r = Polygon2D.new()
	branch_r.color = color
	branch_r.polygon = PackedVector2Array([
		Vector2(4, 22),
		Vector2(16, 6),
		Vector2(20, 0),
		Vector2(18, 2),
		Vector2(14, 8),
		Vector2(2, 24),
	])
	visual.add_child(branch_r)

	# Upper left twig
	var twig_l = Polygon2D.new()
	twig_l.color = Color(color.r * 0.9, color.g * 0.9, color.b * 0.88)
	twig_l.polygon = PackedVector2Array([
		Vector2(-14, 6),
		Vector2(-20, -6),
		Vector2(-18, -5),
		Vector2(-12, 7),
	])
	visual.add_child(twig_l)

	# Upper right twig
	var twig_r = Polygon2D.new()
	twig_r.color = Color(color.r * 0.9, color.g * 0.9, color.b * 0.88)
	twig_r.polygon = PackedVector2Array([
		Vector2(12, 10),
		Vector2(16, -2),
		Vector2(14, -1),
		Vector2(10, 11),
	])
	visual.add_child(twig_r)

	# Top spike
	var spike = Polygon2D.new()
	spike.color = color
	spike.polygon = PackedVector2Array([
		Vector2(-2, 20),
		Vector2(0, 6),
		Vector2(2, 20),
	])
	visual.add_child(spike)

func _draw_heather(visual: Node2D, color: Color) -> void:
	"""Draw low heather bush with small flowers"""
	# Green foliage base (low mound)
	var foliage_color = Color(0.25, 0.40, 0.22)
	if _variation:
		foliage_color = _variation.apply_color_shift(foliage_color)

	var base = Polygon2D.new()
	base.color = foliage_color
	base.polygon = PackedVector2Array([
		Vector2(-13, 6),
		Vector2(-15, 0),
		Vector2(-12, -4),
		Vector2(-6, -7),
		Vector2(0, -8),
		Vector2(6, -7),
		Vector2(12, -4),
		Vector2(15, 0),
		Vector2(13, 6),
		Vector2(0, 8),
	])
	visual.add_child(base)

	# Flower clusters on top (small dots of the flower color)
	var flower_positions = [
		Vector2(-9, -3), Vector2(-5, -6), Vector2(-1, -7),
		Vector2(3, -6), Vector2(7, -4), Vector2(10, -2),
		Vector2(-7, -1), Vector2(0, -4), Vector2(5, -2),
		Vector2(-3, -5), Vector2(8, -5), Vector2(-11, 0),
	]

	for pos in flower_positions:
		var flower = Polygon2D.new()
		flower.color = color
		var points = PackedVector2Array()
		for i in range(5):
			var angle = (i / 5.0) * TAU
			points.append(Vector2(pos.x + cos(angle) * 1.8, pos.y + sin(angle) * 1.8))
		flower.polygon = points
		visual.add_child(flower)

	# A few lighter flower accents
	var accent_positions = [Vector2(-4, -3), Vector2(2, -5), Vector2(6, -1)]
	for pos in accent_positions:
		var accent = Polygon2D.new()
		accent.color = Color(color.r * 1.3, color.g * 1.2, color.b * 1.3, 0.8)
		var points = PackedVector2Array()
		for i in range(4):
			var angle = (i / 4.0) * TAU
			points.append(Vector2(pos.x + cos(angle) * 1.2, pos.y + sin(angle) * 1.2))
		accent.polygon = points
		visual.add_child(accent)

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
