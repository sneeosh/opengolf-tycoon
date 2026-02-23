extends Node2D
class_name Decoration
## Decoration - Placeable decorative items that boost golfer satisfaction
##
## Decorations are single-tile items placed on the course for aesthetic appeal.
## Each type provides a satisfaction bonus in a radius around it. Different
## decoration types are available per course theme.

var grid_position: Vector2i = Vector2i(0, 0)
var decoration_type: String = "fountain"

var terrain_grid: TerrainGrid
var decoration_data: Dictionary = {}

## Shadow references for updates when sun changes
var _shadow_refs: Dictionary = {}
var _shadow_config: ShadowRenderer.ShadowConfig = null

## Variation data for this decoration instance
var _variation: PropVariation.VariationResult = null

signal decoration_selected(decoration: Decoration)
signal decoration_destroyed(decoration: Decoration)

const DECORATION_PROPERTIES: Dictionary = {
	# Water features
	"fountain": {"name": "Fountain", "cost": 500, "satisfaction_bonus": 0.08, "effect_radius": 5, "visual_height": 32.0, "base_width": 24.0, "category": "water"},
	"bird_bath": {"name": "Bird Bath", "cost": 150, "satisfaction_bonus": 0.03, "effect_radius": 3, "visual_height": 18.0, "base_width": 14.0, "category": "water"},
	# Garden features
	"flower_planter": {"name": "Flower Planter", "cost": 100, "satisfaction_bonus": 0.03, "effect_radius": 3, "visual_height": 12.0, "base_width": 18.0, "category": "garden"},
	"topiary": {"name": "Topiary", "cost": 250, "satisfaction_bonus": 0.05, "effect_radius": 4, "visual_height": 36.0, "base_width": 20.0, "category": "garden"},
	# Lighting
	"stone_lantern": {"name": "Stone Lantern", "cost": 200, "satisfaction_bonus": 0.04, "effect_radius": 4, "visual_height": 28.0, "base_width": 12.0, "category": "lighting"},
	"path_light": {"name": "Path Light", "cost": 120, "satisfaction_bonus": 0.02, "effect_radius": 3, "visual_height": 24.0, "base_width": 8.0, "category": "lighting"},
	# Structures
	"sundial": {"name": "Sundial", "cost": 300, "satisfaction_bonus": 0.05, "effect_radius": 4, "visual_height": 20.0, "base_width": 16.0, "category": "structure"},
	"statue": {"name": "Statue", "cost": 800, "satisfaction_bonus": 0.10, "effect_radius": 6, "visual_height": 44.0, "base_width": 20.0, "category": "structure"},
	"flag_banner": {"name": "Flag Banner", "cost": 80, "satisfaction_bonus": 0.02, "effect_radius": 3, "visual_height": 36.0, "base_width": 10.0, "category": "structure"},
	"course_sign": {"name": "Course Sign", "cost": 200, "satisfaction_bonus": 0.03, "effect_radius": 4, "visual_height": 28.0, "base_width": 22.0, "category": "structure"},
	# Boundaries
	"picket_fence": {"name": "Picket Fence", "cost": 60, "satisfaction_bonus": 0.01, "effect_radius": 2, "visual_height": 14.0, "base_width": 28.0, "category": "boundary"},
	"stone_wall": {"name": "Stone Wall", "cost": 100, "satisfaction_bonus": 0.02, "effect_radius": 2, "visual_height": 16.0, "base_width": 28.0, "category": "boundary"},
	"hedge": {"name": "Hedge", "cost": 80, "satisfaction_bonus": 0.02, "effect_radius": 2, "visual_height": 18.0, "base_width": 26.0, "category": "boundary"},
	# Theme-specific
	"tiki_torch": {"name": "Tiki Torch", "cost": 150, "satisfaction_bonus": 0.04, "effect_radius": 3, "visual_height": 32.0, "base_width": 10.0, "category": "themed"},
	"wind_chime": {"name": "Wind Chime", "cost": 120, "satisfaction_bonus": 0.03, "effect_radius": 3, "visual_height": 20.0, "base_width": 12.0, "category": "themed"},
	"cactus_garden": {"name": "Cactus Garden", "cost": 180, "satisfaction_bonus": 0.04, "effect_radius": 3, "visual_height": 16.0, "base_width": 22.0, "category": "themed"},
}

## Variation parameters per decoration type
const DECORATION_VARIATION: Dictionary = {
	"fountain": {"scale": Vector2(0.90, 1.10), "rotation": Vector2(-3.0, 3.0), "hue": Vector2(-0.03, 0.03)},
	"bird_bath": {"scale": Vector2(0.88, 1.12), "rotation": Vector2(-5.0, 5.0), "hue": Vector2(-0.03, 0.03)},
	"flower_planter": {"scale": Vector2(0.85, 1.15), "rotation": Vector2(-8.0, 8.0), "hue": Vector2(-0.06, 0.06)},
	"topiary": {"scale": Vector2(0.88, 1.12), "rotation": Vector2(-4.0, 4.0), "hue": Vector2(-0.04, 0.04)},
	"stone_lantern": {"scale": Vector2(0.92, 1.08), "rotation": Vector2(-3.0, 3.0), "hue": Vector2(-0.02, 0.02)},
	"path_light": {"scale": Vector2(0.90, 1.10), "rotation": Vector2(-2.0, 2.0), "hue": Vector2(-0.02, 0.02)},
	"sundial": {"scale": Vector2(0.92, 1.08), "rotation": Vector2(-5.0, 5.0), "hue": Vector2(-0.02, 0.02)},
	"statue": {"scale": Vector2(0.92, 1.08), "rotation": Vector2(-3.0, 3.0), "hue": Vector2(-0.02, 0.02)},
	"flag_banner": {"scale": Vector2(0.90, 1.10), "rotation": Vector2(-6.0, 6.0), "hue": Vector2(-0.03, 0.03)},
	"course_sign": {"scale": Vector2(0.92, 1.08), "rotation": Vector2(-2.0, 2.0), "hue": Vector2(-0.02, 0.02)},
	"picket_fence": {"scale": Vector2(0.95, 1.05), "rotation": Vector2(-2.0, 2.0), "hue": Vector2(-0.02, 0.02)},
	"stone_wall": {"scale": Vector2(0.92, 1.08), "rotation": Vector2(-3.0, 3.0), "hue": Vector2(-0.02, 0.02)},
	"hedge": {"scale": Vector2(0.88, 1.12), "rotation": Vector2(-4.0, 4.0), "hue": Vector2(-0.04, 0.04)},
	"tiki_torch": {"scale": Vector2(0.90, 1.10), "rotation": Vector2(-4.0, 4.0), "hue": Vector2(-0.03, 0.03)},
	"wind_chime": {"scale": Vector2(0.88, 1.12), "rotation": Vector2(-6.0, 6.0), "hue": Vector2(-0.03, 0.03)},
	"cactus_garden": {"scale": Vector2(0.85, 1.15), "rotation": Vector2(-5.0, 5.0), "hue": Vector2(-0.04, 0.04)},
}

func _ready() -> void:
	add_to_group("decorations")

	if decoration_data.is_empty():
		if decoration_type in DECORATION_PROPERTIES:
			decoration_data = DECORATION_PROPERTIES[decoration_type].duplicate(true)
		else:
			decoration_type = "fountain"
			decoration_data = DECORATION_PROPERTIES["fountain"].duplicate(true)
		_generate_variation()
		_update_visuals()

func set_decoration_type(type: String) -> void:
	decoration_type = type
	if decoration_type in DECORATION_PROPERTIES:
		decoration_data = DECORATION_PROPERTIES[decoration_type].duplicate(true)
	else:
		decoration_type = "fountain"
		decoration_data = DECORATION_PROPERTIES["fountain"].duplicate(true)

	if is_inside_tree():
		_generate_variation()
		_update_visuals()

func _generate_variation() -> void:
	var var_params = DECORATION_VARIATION.get(decoration_type, {"scale": Vector2(0.90, 1.10), "rotation": Vector2(-3.0, 3.0), "hue": Vector2(-0.03, 0.03)})

	# Use a salt of 200 to differentiate from trees (0) and rocks (100)
	_variation = PropVariation.generate_custom_variation(
		grid_position,
		var_params["scale"],
		var_params["rotation"],
		var_params["hue"],
		Vector2(-0.03, 0.03),
		Vector2(-0.08, 0.08)
	)

func set_terrain_grid(grid: TerrainGrid) -> void:
	terrain_grid = grid

func set_position_in_grid(pos: Vector2i) -> void:
	var old_pos = grid_position
	grid_position = pos
	if terrain_grid:
		var world_pos = terrain_grid.grid_to_screen(pos)
		global_position = world_pos

	if old_pos != pos and is_inside_tree():
		_generate_variation()
		_update_visuals()

func destroy() -> void:
	decoration_destroyed.emit(self)
	queue_free()

func get_satisfaction_bonus() -> float:
	return decoration_data.get("satisfaction_bonus", 0.0)

func get_effect_radius() -> int:
	return decoration_data.get("effect_radius", 3)

func _update_visuals() -> void:
	if has_node("Visual"):
		get_node("Visual").queue_free()

	var visual = Node2D.new()
	visual.name = "Visual"
	add_child(visual)

	var visual_height = decoration_data.get("visual_height", 16.0)
	var base_width = decoration_data.get("base_width", 16.0)
	var scale_mult = _variation.scale if _variation else 1.0
	_shadow_config = ShadowRenderer.ShadowConfig.new(visual_height * scale_mult, base_width * scale_mult)
	_shadow_config.base_offset = Vector2(0, 12 * scale_mult)

	var shadow_system: Node = null
	if has_node("/root/ShadowSystem"):
		shadow_system = get_node("/root/ShadowSystem")

	_shadow_refs = ShadowRenderer.add_shadows_to_entity(visual, _shadow_config, shadow_system)

	match decoration_type:
		"fountain": _draw_fountain(visual)
		"bird_bath": _draw_bird_bath(visual)
		"flower_planter": _draw_flower_planter(visual)
		"topiary": _draw_topiary(visual)
		"stone_lantern": _draw_stone_lantern(visual)
		"path_light": _draw_path_light(visual)
		"sundial": _draw_sundial(visual)
		"statue": _draw_statue(visual)
		"flag_banner": _draw_flag_banner(visual)
		"course_sign": _draw_course_sign(visual)
		"picket_fence": _draw_picket_fence(visual)
		"stone_wall": _draw_stone_wall(visual)
		"hedge": _draw_hedge(visual)
		"tiki_torch": _draw_tiki_torch(visual)
		"wind_chime": _draw_wind_chime(visual)
		"cactus_garden": _draw_cactus_garden(visual)
		_: _draw_fountain(visual)

	if _variation:
		visual.scale = Vector2(_variation.scale, _variation.scale)
		visual.rotation = _variation.rotation

## --- Drawing methods ---

func _draw_fountain(visual: Node2D) -> void:
	# Base basin
	var basin = Polygon2D.new()
	basin.color = Color(0.55, 0.55, 0.60)
	basin.polygon = PackedVector2Array([
		Vector2(-14, 8), Vector2(-12, 0), Vector2(-8, -4),
		Vector2(8, -4), Vector2(12, 0), Vector2(14, 8),
		Vector2(10, 12), Vector2(-10, 12)
	])
	visual.add_child(basin)
	# Water surface
	var water = Polygon2D.new()
	water.color = Color(0.3, 0.5, 0.75, 0.7)
	water.polygon = PackedVector2Array([
		Vector2(-10, 4), Vector2(-6, 0), Vector2(6, 0),
		Vector2(10, 4), Vector2(8, 8), Vector2(-8, 8)
	])
	visual.add_child(water)
	# Center spout
	var spout = Polygon2D.new()
	spout.color = Color(0.60, 0.60, 0.65)
	spout.polygon = PackedVector2Array([
		Vector2(-3, 0), Vector2(-2, -16), Vector2(2, -16), Vector2(3, 0)
	])
	visual.add_child(spout)
	# Water spray
	var spray = Polygon2D.new()
	spray.color = Color(0.5, 0.7, 0.9, 0.5)
	spray.polygon = PackedVector2Array([
		Vector2(-6, -8), Vector2(0, -20), Vector2(6, -8)
	])
	visual.add_child(spray)

func _draw_bird_bath(visual: Node2D) -> void:
	# Pedestal
	var pedestal = Polygon2D.new()
	pedestal.color = Color(0.6, 0.58, 0.55)
	pedestal.polygon = PackedVector2Array([
		Vector2(-4, 10), Vector2(-3, -2), Vector2(3, -2), Vector2(4, 10)
	])
	visual.add_child(pedestal)
	# Bowl
	var bowl = Polygon2D.new()
	bowl.color = Color(0.55, 0.55, 0.58)
	bowl.polygon = PackedVector2Array([
		Vector2(-10, 0), Vector2(-8, -6), Vector2(8, -6),
		Vector2(10, 0), Vector2(8, 3), Vector2(-8, 3)
	])
	visual.add_child(bowl)
	# Water
	var water = Polygon2D.new()
	water.color = Color(0.35, 0.55, 0.75, 0.6)
	water.polygon = PackedVector2Array([
		Vector2(-7, -2), Vector2(7, -2), Vector2(6, 1), Vector2(-6, 1)
	])
	visual.add_child(water)

func _draw_flower_planter(visual: Node2D) -> void:
	# Pot
	var pot = Polygon2D.new()
	pot.color = Color(0.6, 0.35, 0.2)
	pot.polygon = PackedVector2Array([
		Vector2(-10, 6), Vector2(-8, 0), Vector2(8, 0),
		Vector2(10, 6), Vector2(8, 10), Vector2(-8, 10)
	])
	visual.add_child(pot)
	# Flowers (colorful dots)
	var colors = [Color(0.9, 0.3, 0.3), Color(0.9, 0.7, 0.2), Color(0.9, 0.4, 0.6), Color(0.6, 0.3, 0.8)]
	var positions = [Vector2(-5, -4), Vector2(0, -6), Vector2(5, -4), Vector2(-2, -2), Vector2(3, -2)]
	for i in range(positions.size()):
		var flower = Polygon2D.new()
		flower.color = colors[i % colors.size()]
		var p = positions[i]
		flower.polygon = PackedVector2Array([
			p + Vector2(-3, 0), p + Vector2(0, -3),
			p + Vector2(3, 0), p + Vector2(0, 3)
		])
		visual.add_child(flower)
	# Leaves
	var leaves = Polygon2D.new()
	leaves.color = Color(0.25, 0.5, 0.25)
	leaves.polygon = PackedVector2Array([
		Vector2(-8, -1), Vector2(-4, -5), Vector2(0, -3),
		Vector2(4, -5), Vector2(8, -1), Vector2(6, 0), Vector2(-6, 0)
	])
	visual.add_child(leaves)

func _draw_topiary(visual: Node2D) -> void:
	# Pot
	var pot = Polygon2D.new()
	pot.color = Color(0.55, 0.35, 0.2)
	pot.polygon = PackedVector2Array([
		Vector2(-8, 10), Vector2(-6, 2), Vector2(6, 2), Vector2(8, 10)
	])
	visual.add_child(pot)
	# Trunk
	var trunk = Polygon2D.new()
	trunk.color = Color(0.4, 0.3, 0.2)
	trunk.polygon = PackedVector2Array([
		Vector2(-2, 4), Vector2(-2, -10), Vector2(2, -10), Vector2(2, 4)
	])
	visual.add_child(trunk)
	# Sphere foliage
	var foliage = Polygon2D.new()
	foliage.color = Color(0.2, 0.5, 0.2)
	foliage.polygon = PackedVector2Array([
		Vector2(-10, -10), Vector2(-8, -18), Vector2(-4, -22),
		Vector2(4, -22), Vector2(8, -18), Vector2(10, -10),
		Vector2(8, -6), Vector2(-8, -6)
	])
	visual.add_child(foliage)
	# Highlight
	var highlight = Polygon2D.new()
	highlight.color = Color(0.25, 0.58, 0.25)
	highlight.polygon = PackedVector2Array([
		Vector2(-4, -16), Vector2(0, -20), Vector2(4, -16), Vector2(2, -12), Vector2(-2, -12)
	])
	visual.add_child(highlight)

func _draw_stone_lantern(visual: Node2D) -> void:
	# Base
	var base = Polygon2D.new()
	base.color = Color(0.5, 0.5, 0.5)
	base.polygon = PackedVector2Array([
		Vector2(-8, 10), Vector2(-6, 6), Vector2(6, 6), Vector2(8, 10)
	])
	visual.add_child(base)
	# Pillar
	var pillar = Polygon2D.new()
	pillar.color = Color(0.55, 0.55, 0.55)
	pillar.polygon = PackedVector2Array([
		Vector2(-3, 6), Vector2(-3, -6), Vector2(3, -6), Vector2(3, 6)
	])
	visual.add_child(pillar)
	# Light housing
	var housing = Polygon2D.new()
	housing.color = Color(0.5, 0.5, 0.52)
	housing.polygon = PackedVector2Array([
		Vector2(-6, -4), Vector2(-5, -12), Vector2(5, -12), Vector2(6, -4)
	])
	visual.add_child(housing)
	# Light glow
	var glow = Polygon2D.new()
	glow.color = Color(1.0, 0.9, 0.5, 0.6)
	glow.polygon = PackedVector2Array([
		Vector2(-4, -6), Vector2(-3, -10), Vector2(3, -10), Vector2(4, -6)
	])
	visual.add_child(glow)
	# Roof cap
	var roof = Polygon2D.new()
	roof.color = Color(0.45, 0.45, 0.48)
	roof.polygon = PackedVector2Array([
		Vector2(-8, -11), Vector2(0, -18), Vector2(8, -11)
	])
	visual.add_child(roof)

func _draw_path_light(visual: Node2D) -> void:
	# Pole
	var pole = Polygon2D.new()
	pole.color = Color(0.3, 0.3, 0.32)
	pole.polygon = PackedVector2Array([
		Vector2(-2, 10), Vector2(-1, -10), Vector2(1, -10), Vector2(2, 10)
	])
	visual.add_child(pole)
	# Lamp head
	var lamp = Polygon2D.new()
	lamp.color = Color(0.35, 0.35, 0.38)
	lamp.polygon = PackedVector2Array([
		Vector2(-5, -8), Vector2(-4, -14), Vector2(4, -14), Vector2(5, -8)
	])
	visual.add_child(lamp)
	# Light glow
	var glow = Polygon2D.new()
	glow.color = Color(1.0, 0.95, 0.6, 0.5)
	glow.polygon = PackedVector2Array([
		Vector2(-3, -9), Vector2(-2, -12), Vector2(2, -12), Vector2(3, -9)
	])
	visual.add_child(glow)

func _draw_sundial(visual: Node2D) -> void:
	# Base platform
	var base = Polygon2D.new()
	base.color = Color(0.6, 0.58, 0.55)
	base.polygon = PackedVector2Array([
		Vector2(-12, 6), Vector2(-10, 0), Vector2(10, 0),
		Vector2(12, 6), Vector2(10, 10), Vector2(-10, 10)
	])
	visual.add_child(base)
	# Dial face
	var dial = Polygon2D.new()
	dial.color = Color(0.7, 0.68, 0.65)
	dial.polygon = PackedVector2Array([
		Vector2(-8, 2), Vector2(-6, -2), Vector2(6, -2),
		Vector2(8, 2), Vector2(6, 6), Vector2(-6, 6)
	])
	visual.add_child(dial)
	# Gnomon (shadow caster)
	var gnomon = Polygon2D.new()
	gnomon.color = Color(0.4, 0.38, 0.35)
	gnomon.polygon = PackedVector2Array([
		Vector2(-1, 2), Vector2(0, -10), Vector2(1, 2)
	])
	visual.add_child(gnomon)

func _draw_statue(visual: Node2D) -> void:
	# Pedestal
	var pedestal = Polygon2D.new()
	pedestal.color = Color(0.55, 0.55, 0.55)
	pedestal.polygon = PackedVector2Array([
		Vector2(-10, 10), Vector2(-8, 0), Vector2(8, 0), Vector2(10, 10)
	])
	visual.add_child(pedestal)
	# Figure body
	var body = Polygon2D.new()
	body.color = Color(0.6, 0.6, 0.62)
	body.polygon = PackedVector2Array([
		Vector2(-5, 2), Vector2(-6, -12), Vector2(-4, -18),
		Vector2(4, -18), Vector2(6, -12), Vector2(5, 2)
	])
	visual.add_child(body)
	# Head
	var head = Polygon2D.new()
	head.color = Color(0.62, 0.62, 0.64)
	head.polygon = PackedVector2Array([
		Vector2(-3, -17), Vector2(-2, -24), Vector2(2, -24), Vector2(3, -17)
	])
	visual.add_child(head)
	# Golf club in hand
	var club = Polygon2D.new()
	club.color = Color(0.4, 0.4, 0.42)
	club.polygon = PackedVector2Array([
		Vector2(5, -8), Vector2(10, -22), Vector2(11, -22), Vector2(6, -8)
	])
	visual.add_child(club)

func _draw_flag_banner(visual: Node2D) -> void:
	# Pole
	var pole = Polygon2D.new()
	pole.color = Color(0.4, 0.3, 0.2)
	pole.polygon = PackedVector2Array([
		Vector2(-1, 10), Vector2(-1, -18), Vector2(1, -18), Vector2(1, 10)
	])
	visual.add_child(pole)
	# Banner
	var banner = Polygon2D.new()
	banner.color = Color(0.8, 0.2, 0.2)
	banner.polygon = PackedVector2Array([
		Vector2(1, -16), Vector2(12, -14), Vector2(10, -8), Vector2(1, -6)
	])
	visual.add_child(banner)

func _draw_course_sign(visual: Node2D) -> void:
	# Posts
	var post_l = Polygon2D.new()
	post_l.color = Color(0.4, 0.3, 0.2)
	post_l.polygon = PackedVector2Array([
		Vector2(-10, 10), Vector2(-10, -8), Vector2(-8, -8), Vector2(-8, 10)
	])
	visual.add_child(post_l)
	var post_r = Polygon2D.new()
	post_r.color = Color(0.4, 0.3, 0.2)
	post_r.polygon = PackedVector2Array([
		Vector2(8, 10), Vector2(8, -8), Vector2(10, -8), Vector2(10, 10)
	])
	visual.add_child(post_r)
	# Sign board
	var board = Polygon2D.new()
	board.color = Color(0.2, 0.35, 0.2)
	board.polygon = PackedVector2Array([
		Vector2(-12, -4), Vector2(-12, -14), Vector2(12, -14), Vector2(12, -4)
	])
	visual.add_child(board)
	# Gold trim
	var trim = Polygon2D.new()
	trim.color = Color(0.85, 0.7, 0.2)
	trim.polygon = PackedVector2Array([
		Vector2(-11, -5), Vector2(-11, -6), Vector2(11, -6), Vector2(11, -5)
	])
	visual.add_child(trim)

func _draw_picket_fence(visual: Node2D) -> void:
	var fence_color = Color(0.85, 0.82, 0.78)
	# Rail
	var rail = Polygon2D.new()
	rail.color = fence_color
	rail.polygon = PackedVector2Array([
		Vector2(-14, 2), Vector2(-14, 0), Vector2(14, 0), Vector2(14, 2)
	])
	visual.add_child(rail)
	# Pickets
	for x in [-12, -6, 0, 6, 12]:
		var picket = Polygon2D.new()
		picket.color = fence_color
		picket.polygon = PackedVector2Array([
			Vector2(x - 2, 8), Vector2(x - 2, -4),
			Vector2(x, -7), Vector2(x + 2, -4), Vector2(x + 2, 8)
		])
		visual.add_child(picket)

func _draw_stone_wall(visual: Node2D) -> void:
	var wall_color = Color(0.5, 0.48, 0.45)
	# Main wall body
	var wall = Polygon2D.new()
	wall.color = wall_color
	wall.polygon = PackedVector2Array([
		Vector2(-14, 8), Vector2(-14, -4), Vector2(14, -4), Vector2(14, 8)
	])
	visual.add_child(wall)
	# Stone lines (mortar gaps)
	var mortar = Polygon2D.new()
	mortar.color = Color(0.4, 0.38, 0.35)
	mortar.polygon = PackedVector2Array([
		Vector2(-14, 2), Vector2(-14, 1), Vector2(14, 1), Vector2(14, 2)
	])
	visual.add_child(mortar)
	# Highlight on top
	var highlight = Polygon2D.new()
	highlight.color = Color(0.58, 0.56, 0.53)
	highlight.polygon = PackedVector2Array([
		Vector2(-14, -2), Vector2(-14, -4), Vector2(14, -4), Vector2(14, -2)
	])
	visual.add_child(highlight)

func _draw_hedge(visual: Node2D) -> void:
	# Main hedge body
	var hedge = Polygon2D.new()
	hedge.color = Color(0.2, 0.42, 0.2)
	hedge.polygon = PackedVector2Array([
		Vector2(-14, 8), Vector2(-14, -2), Vector2(-12, -6),
		Vector2(-4, -8), Vector2(4, -8), Vector2(12, -6),
		Vector2(14, -2), Vector2(14, 8)
	])
	visual.add_child(hedge)
	# Highlight
	var highlight = Polygon2D.new()
	highlight.color = Color(0.25, 0.5, 0.25)
	highlight.polygon = PackedVector2Array([
		Vector2(-10, -2), Vector2(-6, -6), Vector2(6, -6),
		Vector2(10, -2), Vector2(6, 0), Vector2(-6, 0)
	])
	visual.add_child(highlight)

func _draw_tiki_torch(visual: Node2D) -> void:
	# Bamboo pole
	var pole = Polygon2D.new()
	pole.color = Color(0.55, 0.42, 0.25)
	pole.polygon = PackedVector2Array([
		Vector2(-2, 10), Vector2(-2, -12), Vector2(2, -12), Vector2(2, 10)
	])
	visual.add_child(pole)
	# Torch head
	var head = Polygon2D.new()
	head.color = Color(0.5, 0.38, 0.22)
	head.polygon = PackedVector2Array([
		Vector2(-4, -10), Vector2(-3, -16), Vector2(3, -16), Vector2(4, -10)
	])
	visual.add_child(head)
	# Flame
	var flame = Polygon2D.new()
	flame.color = Color(1.0, 0.6, 0.1, 0.8)
	flame.polygon = PackedVector2Array([
		Vector2(-3, -14), Vector2(0, -22), Vector2(3, -14)
	])
	visual.add_child(flame)
	# Inner flame
	var inner = Polygon2D.new()
	inner.color = Color(1.0, 0.9, 0.3, 0.7)
	inner.polygon = PackedVector2Array([
		Vector2(-1, -15), Vector2(0, -20), Vector2(1, -15)
	])
	visual.add_child(inner)

func _draw_wind_chime(visual: Node2D) -> void:
	# Hanging hook
	var hook = Polygon2D.new()
	hook.color = Color(0.4, 0.4, 0.42)
	hook.polygon = PackedVector2Array([
		Vector2(-1, -12), Vector2(0, -16), Vector2(1, -12)
	])
	visual.add_child(hook)
	# Top disc
	var disc = Polygon2D.new()
	disc.color = Color(0.5, 0.45, 0.4)
	disc.polygon = PackedVector2Array([
		Vector2(-6, -10), Vector2(-6, -12), Vector2(6, -12), Vector2(6, -10)
	])
	visual.add_child(disc)
	# Chime tubes
	var tube_color = Color(0.6, 0.55, 0.5)
	for x in [-4, -2, 0, 2, 4]:
		var tube = Polygon2D.new()
		tube.color = tube_color
		tube.polygon = PackedVector2Array([
			Vector2(x - 0.5, -10), Vector2(x - 0.5, -10 + abs(x) + 4),
			Vector2(x + 0.5, -10 + abs(x) + 4), Vector2(x + 0.5, -10)
		])
		visual.add_child(tube)

func _draw_cactus_garden(visual: Node2D) -> void:
	# Sandy base
	var base = Polygon2D.new()
	base.color = Color(0.7, 0.6, 0.45)
	base.polygon = PackedVector2Array([
		Vector2(-12, 6), Vector2(-10, 2), Vector2(10, 2),
		Vector2(12, 6), Vector2(10, 10), Vector2(-10, 10)
	])
	visual.add_child(base)
	# Small cacti
	var cactus_color = Color(0.28, 0.52, 0.3)
	# Left cactus
	var c1 = Polygon2D.new()
	c1.color = cactus_color
	c1.polygon = PackedVector2Array([
		Vector2(-7, 4), Vector2(-8, -4), Vector2(-5, -8), Vector2(-4, -4), Vector2(-3, 4)
	])
	visual.add_child(c1)
	# Center cactus (taller)
	var c2 = Polygon2D.new()
	c2.color = cactus_color
	c2.polygon = PackedVector2Array([
		Vector2(-2, 4), Vector2(-2, -6), Vector2(0, -10), Vector2(2, -6), Vector2(2, 4)
	])
	visual.add_child(c2)
	# Right cactus
	var c3 = Polygon2D.new()
	c3.color = cactus_color
	c3.polygon = PackedVector2Array([
		Vector2(4, 4), Vector2(4, -2), Vector2(6, -5), Vector2(8, -2), Vector2(8, 4)
	])
	visual.add_child(c3)

## --- Info ---

func get_decoration_info() -> Dictionary:
	return {
		"type": decoration_type,
		"position": grid_position,
		"cost": decoration_data.get("cost", 100),
		"name": decoration_data.get("name", "Decoration"),
		"satisfaction_bonus": decoration_data.get("satisfaction_bonus", 0.0),
		"effect_radius": decoration_data.get("effect_radius", 3),
	}

## Get decoration types available for a given course theme
static func get_theme_decorations(theme_type: int) -> Array:
	# Universal decorations available on all themes
	var universal = ["fountain", "bird_bath", "flower_planter", "sundial", "statue",
		"flag_banner", "course_sign", "picket_fence", "stone_wall", "path_light"]

	# Theme-specific additions
	match theme_type:
		CourseTheme.Type.PARKLAND:
			return universal + ["topiary", "hedge", "wind_chime"]
		CourseTheme.Type.DESERT:
			return universal + ["cactus_garden", "tiki_torch"]
		CourseTheme.Type.LINKS:
			return universal + ["stone_lantern", "hedge"]
		CourseTheme.Type.MOUNTAIN:
			return universal + ["stone_lantern", "hedge", "wind_chime"]
		CourseTheme.Type.CITY:
			return universal + ["topiary", "hedge"]
		CourseTheme.Type.RESORT:
			return universal + ["tiki_torch", "topiary", "wind_chime"]
	return universal
