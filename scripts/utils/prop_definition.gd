extends Resource
class_name PropDefinition
## Resource defining variation parameters for a prop type.
## Used by trees, rocks, and other decorative objects.

## Unique identifier for this prop type (e.g., "oak", "pine", "small_rock")
@export var prop_id: String = ""

## Display name for UI
@export var display_name: String = ""

## Cost to place this prop
@export var cost: int = 0

## Base visual height in pixels (used for shadow calculations)
@export var visual_height: float = 32.0

## Base width in pixels (used for shadow calculations)
@export var base_width: float = 24.0

## Scale variation range
@export var scale_min: float = 0.85
@export var scale_max: float = 1.15

## Rotation variation range in degrees
@export var rotation_min: float = -8.0
@export var rotation_max: float = 8.0

## Hue shift range (0.0 = no shift, 0.1 = 10% hue rotation)
@export var hue_shift_min: float = -0.03
@export var hue_shift_max: float = 0.03

## Saturation variation
@export var saturation_shift_min: float = -0.1
@export var saturation_shift_max: float = 0.1

## Value/brightness variation
@export var value_shift_min: float = -0.08
@export var value_shift_max: float = 0.08

## Base color for procedural rendering
@export var base_color: Color = Color.WHITE

## Secondary color (for two-tone props like tree trunks)
@export var secondary_color: Color = Color.BROWN

## Category for grouping (e.g., "tree", "rock", "flower")
@export var category: String = "prop"


## Create a PropDefinition with common defaults
static func create(id: String, name: String, cost_val: int, height: float, width: float, color: Color) -> PropDefinition:
	var def = PropDefinition.new()
	def.prop_id = id
	def.display_name = name
	def.cost = cost_val
	def.visual_height = height
	def.base_width = width
	def.base_color = color
	return def


## Create tree-specific definition with appropriate defaults
static func create_tree(id: String, name: String, cost_val: int, height: float, width: float, foliage_color: Color) -> PropDefinition:
	var def = create(id, name, cost_val, height, width, foliage_color)
	def.category = "tree"
	def.secondary_color = Color(0.4, 0.2, 0.1)  # Brown trunk
	# Trees have more variation
	def.scale_min = 0.80
	def.scale_max = 1.20
	def.rotation_min = -5.0
	def.rotation_max = 5.0
	def.hue_shift_min = -0.04
	def.hue_shift_max = 0.04
	return def


## Create rock-specific definition with appropriate defaults
static func create_rock(id: String, name: String, cost_val: int, height: float, width: float, rock_color: Color) -> PropDefinition:
	var def = create(id, name, cost_val, height, width, rock_color)
	def.category = "rock"
	# Rocks have more rotation variety but less color shift
	def.scale_min = 0.85
	def.scale_max = 1.15
	def.rotation_min = -15.0
	def.rotation_max = 15.0
	def.hue_shift_min = -0.02
	def.hue_shift_max = 0.02
	def.saturation_shift_min = -0.05
	def.saturation_shift_max = 0.05
	return def
