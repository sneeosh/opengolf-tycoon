extends Node2D
class_name Decoration
## Decoration - Represents a decorative object on the course (fountain, gazebo, statue, etc.)
## Decorations contribute to the Aesthetics rating in CourseRatingSystem.

var grid_position: Vector2i = Vector2i(0, 0)
var decoration_type: String = ""
var category: String = ""
var size: Vector2i = Vector2i(1, 1)
var cost: int = 0
var daily_upkeep: int = 0
var aesthetics_value: float = 0.0
var decoration_data: Dictionary = {}

var terrain_grid: TerrainGrid

## Shadow references for updates when sun changes
var _shadow_refs: Dictionary = {}
var _shadow_config: ShadowRenderer.ShadowConfig = null

## Variation data for this decoration instance
var _variation: PropVariation.VariationResult = null

signal decoration_selected(decoration: Decoration)
signal decoration_destroyed(decoration: Decoration)

## Sprite textures for decorations that have pixel art assets
const SPRITE_PATHS: Dictionary = {
	"flower_garden": "res://assets/sprites/decorations/flower_garden.png",
	"ornamental_grass": "res://assets/sprites/decorations/ornamental_grass.png",
	"topiary": "res://assets/sprites/decorations/topiary.png",
	"fountain": "res://assets/sprites/decorations/fountain.png",
	"bird_bath": "res://assets/sprites/decorations/bird_bath.png",
	"gazebo": "res://assets/sprites/decorations/gazebo.png",
	"course_signage": "res://assets/sprites/decorations/course_signage.png",
	"ball_washer": "res://assets/sprites/decorations/ball_washer.png",
	"park_bench": "res://assets/sprites/decorations/park_bench.png",
	"waste_bin": "res://assets/sprites/decorations/waste_bin.png",
	"golfer_statue": "res://assets/sprites/decorations/golfer_statue.png",
	"sundial": "res://assets/sprites/decorations/sundial.png",
}

## Base offsets for sprite positioning (half sprite height to align base with tile center)
const SPRITE_BASE_OFFSETS: Dictionary = {
	"flower_garden": 16.0,
	"ornamental_grass": 12.0,
	"topiary": 16.0,
	"fountain": 20.0,
	"bird_bath": 14.0,
	"gazebo": 20.0,
	"course_signage": 16.0,
	"ball_washer": 12.0,
	"park_bench": 10.0,
	"waste_bin": 10.0,
	"golfer_statue": 20.0,
	"sundial": 16.0,
}

## Visual dimensions for shadow configuration
const DECORATION_VISUALS: Dictionary = {
	"flower_garden": {"visual_height": 16.0, "base_width": 40.0},
	"ornamental_grass": {"visual_height": 14.0, "base_width": 18.0},
	"topiary": {"visual_height": 28.0, "base_width": 18.0},
	"fountain": {"visual_height": 36.0, "base_width": 40.0},
	"bird_bath": {"visual_height": 20.0, "base_width": 16.0},
	"gazebo": {"visual_height": 36.0, "base_width": 44.0},
	"course_signage": {"visual_height": 24.0, "base_width": 10.0},
	"ball_washer": {"visual_height": 18.0, "base_width": 10.0},
	"park_bench": {"visual_height": 14.0, "base_width": 22.0},
	"waste_bin": {"visual_height": 16.0, "base_width": 10.0},
	"golfer_statue": {"visual_height": 36.0, "base_width": 16.0},
	"sundial": {"visual_height": 24.0, "base_width": 18.0},
}

## Variation parameters per decoration type
const DECORATION_VARIATION: Dictionary = {
	"flower_garden": {"scale": Vector2(0.90, 1.10), "rotation": Vector2(-3.0, 3.0), "hue": Vector2(-0.06, 0.06)},
	"ornamental_grass": {"scale": Vector2(0.85, 1.15), "rotation": Vector2(-8.0, 8.0), "hue": Vector2(-0.04, 0.04)},
	"topiary": {"scale": Vector2(0.90, 1.10), "rotation": Vector2(-2.0, 2.0), "hue": Vector2(-0.03, 0.03)},
	"fountain": {"scale": Vector2(0.95, 1.05), "rotation": Vector2(0.0, 0.0), "hue": Vector2(-0.02, 0.02)},
	"bird_bath": {"scale": Vector2(0.90, 1.10), "rotation": Vector2(-5.0, 5.0), "hue": Vector2(-0.02, 0.02)},
	"gazebo": {"scale": Vector2(0.95, 1.05), "rotation": Vector2(0.0, 0.0), "hue": Vector2(-0.02, 0.02)},
	"course_signage": {"scale": Vector2(0.90, 1.10), "rotation": Vector2(-5.0, 5.0), "hue": Vector2(-0.02, 0.02)},
	"ball_washer": {"scale": Vector2(0.95, 1.05), "rotation": Vector2(-3.0, 3.0), "hue": Vector2(-0.01, 0.01)},
	"park_bench": {"scale": Vector2(0.95, 1.05), "rotation": Vector2(-3.0, 3.0), "hue": Vector2(-0.02, 0.02)},
	"waste_bin": {"scale": Vector2(0.95, 1.05), "rotation": Vector2(-5.0, 5.0), "hue": Vector2(-0.02, 0.02)},
	"golfer_statue": {"scale": Vector2(0.95, 1.05), "rotation": Vector2(0.0, 0.0), "hue": Vector2(-0.01, 0.01)},
	"sundial": {"scale": Vector2(0.95, 1.05), "rotation": Vector2(-3.0, 3.0), "hue": Vector2(-0.01, 0.01)},
}

## Procedural fallback colors per decoration type
const DECORATION_COLORS: Dictionary = {
	"flower_garden": Color(0.85, 0.30, 0.45),
	"ornamental_grass": Color(0.45, 0.60, 0.30),
	"topiary": Color(0.20, 0.50, 0.20),
	"fountain": Color(0.50, 0.65, 0.80),
	"bird_bath": Color(0.65, 0.65, 0.65),
	"gazebo": Color(0.55, 0.35, 0.20),
	"course_signage": Color(0.30, 0.50, 0.20),
	"ball_washer": Color(0.50, 0.50, 0.55),
	"park_bench": Color(0.45, 0.30, 0.18),
	"waste_bin": Color(0.35, 0.45, 0.35),
	"golfer_statue": Color(0.60, 0.50, 0.30),
	"sundial": Color(0.70, 0.65, 0.55),
}


func _ready() -> void:
	add_to_group("decorations")

	if not decoration_type.is_empty():
		_generate_variation()
		_update_visuals()

	# Connect to sun direction changes if ShadowSystem is available
	if has_node("/root/ShadowSystem"):
		var shadow_system = get_node("/root/ShadowSystem")
		if shadow_system.has_signal("sun_direction_changed"):
			shadow_system.sun_direction_changed.connect(_on_sun_direction_changed)


func _exit_tree() -> void:
	if has_node("/root/ShadowSystem"):
		var shadow_system = get_node("/root/ShadowSystem")
		if shadow_system.sun_direction_changed.is_connected(_on_sun_direction_changed):
			shadow_system.sun_direction_changed.disconnect(_on_sun_direction_changed)


func set_decoration_type(type: String, data: Dictionary) -> void:
	"""Set the decoration type and load its data"""
	decoration_type = type
	decoration_data = data.duplicate(true)
	category = data.get("category", "")
	var sz = data.get("size", [1, 1])
	size = Vector2i(int(sz[0]), int(sz[1]))
	cost = data.get("cost", 0)
	daily_upkeep = data.get("daily_upkeep", 0)
	aesthetics_value = data.get("aesthetics_value", 0.0)

	if is_inside_tree():
		_generate_variation()
		_update_visuals()


func _generate_variation() -> void:
	"""Generate deterministic variation based on grid position"""
	var var_params = DECORATION_VARIATION.get(decoration_type, {
		"scale": Vector2(0.95, 1.05),
		"rotation": Vector2(0.0, 0.0),
		"hue": Vector2(-0.02, 0.02)
	})

	# Use salt offset 200 to differentiate from trees (0) and rocks (100)
	_variation = PropVariation.generate_custom_variation(
		grid_position,
		var_params["scale"],
		var_params["rotation"],
		var_params["hue"],
		Vector2(-0.03, 0.03),  # Saturation
		Vector2(-0.05, 0.05)   # Value
	)


func _input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		decoration_selected.emit(self)


func set_terrain_grid(grid: TerrainGrid) -> void:
	terrain_grid = grid


func set_position_in_grid(pos: Vector2i) -> void:
	var old_pos = grid_position
	grid_position = pos
	if terrain_grid:
		# For multi-tile decorations, position at center of footprint
		if size.x > 1 or size.y > 1:
			var center_offset = Vector2(size.x - 1, size.y - 1) * 0.5
			var center_pos = Vector2(pos.x, pos.y) + center_offset
			var world_pos = terrain_grid.grid_to_screen_center(Vector2i(int(center_pos.x), int(center_pos.y)))
			global_position = world_pos
		else:
			var world_pos = terrain_grid.grid_to_screen_center(pos)
			global_position = world_pos

	if old_pos != pos and is_inside_tree():
		_generate_variation()
		_update_visuals()


func get_footprint() -> Array:
	"""Returns array of Vector2i positions this decoration occupies"""
	var footprint: Array = []
	for x in range(size.x):
		for y in range(size.y):
			footprint.append(grid_position + Vector2i(x, y))
	return footprint


func destroy() -> void:
	decoration_destroyed.emit(self)
	queue_free()


func get_decoration_info() -> Dictionary:
	"""Returns serializable info for saving"""
	return {
		"type": decoration_type,
		"position": {"x": grid_position.x, "y": grid_position.y},
		"category": category,
		"cost": cost,
	}


func _update_visuals() -> void:
	"""Create visual representation with shadows and variation"""
	if has_node("Visual"):
		get_node("Visual").queue_free()

	var visual = Node2D.new()
	visual.name = "Visual"
	add_child(visual)

	var base_color = DECORATION_COLORS.get(decoration_type, Color.WHITE)
	var color = base_color
	if _variation:
		color = _variation.apply_color_shift(base_color)

	# Configure shadow
	var vis_data = DECORATION_VISUALS.get(decoration_type, {"visual_height": 16.0, "base_width": 20.0})
	var visual_height = vis_data["visual_height"]
	var base_width = vis_data["base_width"]
	var scale_mult = _variation.scale if _variation else 1.0
	_shadow_config = ShadowRenderer.ShadowConfig.new(visual_height * scale_mult, base_width * scale_mult)
	_shadow_config.base_offset = Vector2(0, 12 * scale_mult)

	# Small decorations skip drop shadow
	if visual_height <= 16.0:
		_shadow_config.cast_drop_shadow = false

	var shadow_system: Node = null
	if has_node("/root/ShadowSystem"):
		shadow_system = get_node("/root/ShadowSystem")

	_shadow_refs = ShadowRenderer.add_shadows_to_entity(visual, _shadow_config, shadow_system)

	# Use sprite if available, otherwise procedural fallback
	if decoration_type in SPRITE_PATHS and ResourceLoader.exists(SPRITE_PATHS[decoration_type]):
		var sprite = Sprite2D.new()
		sprite.name = "DecorationSprite"
		sprite.texture = load(SPRITE_PATHS[decoration_type])
		sprite.centered = true
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if _variation:
			sprite.modulate = _variation.apply_color_shift(Color.WHITE)
		var offset_y = SPRITE_BASE_OFFSETS.get(decoration_type, 16.0)
		sprite.position.y = -offset_y
		visual.add_child(sprite)
	else:
		_draw_procedural(visual, color)

	# Apply scale and rotation variation
	if _variation:
		visual.scale = Vector2(_variation.scale, _variation.scale)
		visual.rotation = _variation.rotation


func _draw_procedural(visual: Node2D, color: Color) -> void:
	"""Draw a simple procedural representation based on decoration type"""
	match category:
		"landscaping":
			_draw_landscaping(visual, color)
		"water":
			_draw_water_feature(visual, color)
		"structures":
			_draw_structure(visual, color)
		"furniture":
			_draw_furniture(visual, color)
		"sculptures":
			_draw_sculpture(visual, color)
		_:
			_draw_generic(visual, color)


func _draw_landscaping(visual: Node2D, color: Color) -> void:
	"""Draw landscaping decorations (flower garden, ornamental grass, topiary)"""
	if decoration_type == "flower_garden":
		# Cluster of colorful circles
		for i in range(5):
			var flower = Polygon2D.new()
			var offset = Vector2(
				(i % 3 - 1) * 10.0,
				(i / 3 - 0.5) * 8.0 - 6.0
			)
			var flower_color = color
			if i % 2 == 1:
				flower_color = Color(color.r * 0.8, color.g * 1.2, color.b * 0.9)
			flower.color = flower_color
			flower.polygon = _make_circle_polygon(5.0, 6, offset)
			visual.add_child(flower)
		# Green base
		var base = Polygon2D.new()
		base.color = Color(0.25, 0.50, 0.20)
		base.polygon = PackedVector2Array([
			Vector2(-16, 2), Vector2(-14, -4), Vector2(14, -4), Vector2(16, 2), Vector2(12, 6), Vector2(-12, 6)
		])
		visual.add_child(base)
	elif decoration_type == "topiary":
		# Sphere on short trunk
		var trunk = Polygon2D.new()
		trunk.color = Color(0.35, 0.25, 0.15)
		trunk.polygon = PackedVector2Array([
			Vector2(-2, 0), Vector2(2, 0), Vector2(2, 8), Vector2(-2, 8)
		])
		visual.add_child(trunk)
		var sphere = Polygon2D.new()
		sphere.color = color
		sphere.polygon = _make_circle_polygon(10.0, 8, Vector2(0, -8))
		visual.add_child(sphere)
		# Highlight
		var highlight = Polygon2D.new()
		highlight.color = Color(color.r * 1.3, color.g * 1.3, color.b * 1.3)
		highlight.polygon = _make_circle_polygon(5.0, 6, Vector2(-3, -11))
		visual.add_child(highlight)
	else:
		# Ornamental grass - wispy lines
		for i in range(4):
			var blade = Polygon2D.new()
			blade.color = color
			var x_off = (i - 1.5) * 5.0
			blade.polygon = PackedVector2Array([
				Vector2(x_off - 1, 4), Vector2(x_off + 1, 4),
				Vector2(x_off + 2 + i, -8 - i * 2), Vector2(x_off + i, -8 - i * 2)
			])
			visual.add_child(blade)


func _draw_water_feature(visual: Node2D, color: Color) -> void:
	"""Draw water feature decorations (fountain, bird bath)"""
	if decoration_type == "fountain":
		# Basin
		var basin = Polygon2D.new()
		basin.color = Color(0.55, 0.55, 0.60)
		basin.polygon = PackedVector2Array([
			Vector2(-16, 4), Vector2(-14, -2), Vector2(14, -2), Vector2(16, 4),
			Vector2(14, 8), Vector2(-14, 8)
		])
		visual.add_child(basin)
		# Water surface
		var water = Polygon2D.new()
		water.color = Color(color.r, color.g, color.b, 0.7)
		water.polygon = PackedVector2Array([
			Vector2(-12, 2), Vector2(-10, -1), Vector2(10, -1), Vector2(12, 2),
			Vector2(10, 5), Vector2(-10, 5)
		])
		visual.add_child(water)
		# Center pillar
		var pillar = Polygon2D.new()
		pillar.color = Color(0.60, 0.60, 0.65)
		pillar.polygon = PackedVector2Array([
			Vector2(-2, 2), Vector2(2, 2), Vector2(2, -14), Vector2(-2, -14)
		])
		visual.add_child(pillar)
		# Water spray highlight
		var spray = Polygon2D.new()
		spray.color = Color(0.7, 0.85, 1.0, 0.6)
		spray.polygon = _make_circle_polygon(4.0, 5, Vector2(0, -16))
		visual.add_child(spray)
	else:
		# Bird bath - small bowl on pedestal
		var pedestal = Polygon2D.new()
		pedestal.color = Color(0.55, 0.55, 0.55)
		pedestal.polygon = PackedVector2Array([
			Vector2(-3, 4), Vector2(3, 4), Vector2(2, -4), Vector2(-2, -4)
		])
		visual.add_child(pedestal)
		var bowl = Polygon2D.new()
		bowl.color = Color(0.60, 0.60, 0.65)
		bowl.polygon = PackedVector2Array([
			Vector2(-8, -4), Vector2(-6, -8), Vector2(6, -8), Vector2(8, -4)
		])
		visual.add_child(bowl)
		var water = Polygon2D.new()
		water.color = Color(color.r, color.g, color.b, 0.5)
		water.polygon = PackedVector2Array([
			Vector2(-6, -5), Vector2(-4, -7), Vector2(4, -7), Vector2(6, -5)
		])
		visual.add_child(water)


func _draw_structure(visual: Node2D, color: Color) -> void:
	"""Draw structure decorations (gazebo, signage, ball washer)"""
	if decoration_type == "gazebo":
		# Roof
		var roof = Polygon2D.new()
		roof.color = Color(0.45, 0.25, 0.15)
		roof.polygon = PackedVector2Array([
			Vector2(0, -24), Vector2(-18, -10), Vector2(-16, -8),
			Vector2(0, -20), Vector2(16, -8), Vector2(18, -10)
		])
		visual.add_child(roof)
		# Posts
		for x_off in [-12, 12]:
			var post = Polygon2D.new()
			post.color = color
			post.polygon = PackedVector2Array([
				Vector2(x_off - 1, -8), Vector2(x_off + 1, -8),
				Vector2(x_off + 1, 6), Vector2(x_off - 1, 6)
			])
			visual.add_child(post)
		# Base platform
		var base = Polygon2D.new()
		base.color = Color(0.60, 0.55, 0.45)
		base.polygon = PackedVector2Array([
			Vector2(-16, 6), Vector2(16, 6), Vector2(14, 10), Vector2(-14, 10)
		])
		visual.add_child(base)
	elif decoration_type == "course_signage":
		# Sign post
		var post = Polygon2D.new()
		post.color = Color(0.40, 0.30, 0.18)
		post.polygon = PackedVector2Array([
			Vector2(-1, 4), Vector2(1, 4), Vector2(1, -10), Vector2(-1, -10)
		])
		visual.add_child(post)
		# Sign board
		var board = Polygon2D.new()
		board.color = color
		board.polygon = PackedVector2Array([
			Vector2(-8, -10), Vector2(8, -10), Vector2(8, -18), Vector2(-8, -18)
		])
		visual.add_child(board)
	else:
		# Ball washer - small post with mechanism
		var post = Polygon2D.new()
		post.color = Color(0.40, 0.40, 0.45)
		post.polygon = PackedVector2Array([
			Vector2(-1, 4), Vector2(1, 4), Vector2(1, -6), Vector2(-1, -6)
		])
		visual.add_child(post)
		var washer = Polygon2D.new()
		washer.color = color
		washer.polygon = PackedVector2Array([
			Vector2(-4, -6), Vector2(4, -6), Vector2(4, -12), Vector2(-4, -12)
		])
		visual.add_child(washer)


func _draw_furniture(visual: Node2D, color: Color) -> void:
	"""Draw furniture decorations (park bench, waste bin)"""
	if decoration_type == "park_bench":
		# Bench seat
		var seat = Polygon2D.new()
		seat.color = color
		seat.polygon = PackedVector2Array([
			Vector2(-12, 0), Vector2(12, 0), Vector2(12, 3), Vector2(-12, 3)
		])
		visual.add_child(seat)
		# Back rest
		var back = Polygon2D.new()
		back.color = Color(color.r * 0.85, color.g * 0.85, color.b * 0.85)
		back.polygon = PackedVector2Array([
			Vector2(-12, 0), Vector2(12, 0), Vector2(12, -6), Vector2(-12, -6)
		])
		visual.add_child(back)
		# Legs
		for x_off in [-10, 10]:
			var leg = Polygon2D.new()
			leg.color = Color(0.30, 0.30, 0.30)
			leg.polygon = PackedVector2Array([
				Vector2(x_off - 1, 3), Vector2(x_off + 1, 3),
				Vector2(x_off + 1, 7), Vector2(x_off - 1, 7)
			])
			visual.add_child(leg)
	else:
		# Waste bin - cylindrical shape
		var body = Polygon2D.new()
		body.color = color
		body.polygon = PackedVector2Array([
			Vector2(-5, -8), Vector2(5, -8), Vector2(6, 4), Vector2(-6, 4)
		])
		visual.add_child(body)
		# Lid
		var lid = Polygon2D.new()
		lid.color = Color(color.r * 1.2, color.g * 1.2, color.b * 1.2)
		lid.polygon = PackedVector2Array([
			Vector2(-6, -10), Vector2(6, -10), Vector2(5, -8), Vector2(-5, -8)
		])
		visual.add_child(lid)


func _draw_sculpture(visual: Node2D, color: Color) -> void:
	"""Draw sculpture decorations (golfer statue, sundial)"""
	if decoration_type == "golfer_statue":
		# Pedestal
		var pedestal = Polygon2D.new()
		pedestal.color = Color(0.50, 0.50, 0.50)
		pedestal.polygon = PackedVector2Array([
			Vector2(-8, 4), Vector2(8, 4), Vector2(6, -2), Vector2(-6, -2)
		])
		visual.add_child(pedestal)
		# Figure (simplified golfer silhouette)
		var figure = Polygon2D.new()
		figure.color = color
		figure.polygon = PackedVector2Array([
			Vector2(-3, -2), Vector2(3, -2), Vector2(4, -16), Vector2(6, -20),
			Vector2(4, -22), Vector2(2, -18), Vector2(-2, -18), Vector2(-2, -24),
			Vector2(2, -24), Vector2(0, -26), Vector2(-4, -22), Vector2(-4, -16)
		])
		visual.add_child(figure)
	else:
		# Sundial - flat disc on pedestal
		var pedestal = Polygon2D.new()
		pedestal.color = Color(0.55, 0.55, 0.55)
		pedestal.polygon = PackedVector2Array([
			Vector2(-4, 4), Vector2(4, 4), Vector2(3, -4), Vector2(-3, -4)
		])
		visual.add_child(pedestal)
		var disc = Polygon2D.new()
		disc.color = color
		disc.polygon = PackedVector2Array([
			Vector2(-8, -4), Vector2(8, -4), Vector2(10, -7), Vector2(8, -10),
			Vector2(-8, -10), Vector2(-10, -7)
		])
		visual.add_child(disc)
		# Gnomon (shadow casting pin)
		var gnomon = Polygon2D.new()
		gnomon.color = Color(0.30, 0.30, 0.30)
		gnomon.polygon = PackedVector2Array([
			Vector2(-1, -7), Vector2(1, -7), Vector2(0, -14)
		])
		visual.add_child(gnomon)


func _draw_generic(visual: Node2D, color: Color) -> void:
	"""Fallback generic decoration shape"""
	var shape = Polygon2D.new()
	shape.color = color
	shape.polygon = _make_circle_polygon(10.0, 6, Vector2(0, -4))
	visual.add_child(shape)


func _make_circle_polygon(radius: float, segments: int, offset: Vector2 = Vector2.ZERO) -> PackedVector2Array:
	"""Generate a circle-approximating polygon"""
	var points = PackedVector2Array()
	for i in range(segments):
		var angle = TAU * i / segments
		points.append(Vector2(cos(angle) * radius, sin(angle) * radius) + offset)
	return points


func _on_sun_direction_changed(_direction: Vector2) -> void:
	"""Update shadows when sun direction changes"""
	if _shadow_config and has_node("Visual"):
		var visual = get_node("Visual")
		var shadow_system: Node = null
		if has_node("/root/ShadowSystem"):
			shadow_system = get_node("/root/ShadowSystem")
		# Remove old shadows
		for key in _shadow_refs:
			if _shadow_refs[key] and is_instance_valid(_shadow_refs[key]):
				_shadow_refs[key].queue_free()
		_shadow_refs = ShadowRenderer.add_shadows_to_entity(visual, _shadow_config, shadow_system)
