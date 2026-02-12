extends RefCounted
class_name PropVariation
## Utility class for generating deterministic prop variations.
## Uses seeded randomness based on grid position for consistent results.

## Global map seed - set this once at game start for consistent variations
static var map_seed: int = 0

## Variation result containing all computed values
class VariationResult:
	var scale: float = 1.0
	var rotation: float = 0.0  # In radians
	var hue_shift: float = 0.0
	var saturation_shift: float = 0.0
	var value_shift: float = 0.0
	var variant_index: int = 0  # For future texture variant selection

	func apply_color_shift(base_color: Color) -> Color:
		"""Apply HSV shifts to a base color"""
		var h = base_color.h + hue_shift
		var s = clampf(base_color.s + saturation_shift, 0.0, 1.0)
		var v = clampf(base_color.v + value_shift, 0.0, 1.0)
		# Wrap hue around
		if h < 0.0:
			h += 1.0
		elif h > 1.0:
			h -= 1.0
		return Color.from_hsv(h, s, v, base_color.a)


## Set the global map seed (call once at game initialization or load)
static func set_map_seed(seed_value: int) -> void:
	map_seed = seed_value


## Generate a deterministic seed from grid position
## Uses a hash function to distribute values evenly
static func _position_to_seed(grid_pos: Vector2i, extra_salt: int = 0) -> int:
	# Combine position with map seed using a hash-like function
	# Uses prime multipliers for better distribution
	var x = grid_pos.x
	var y = grid_pos.y
	var hash_val = map_seed
	hash_val = hash_val * 31 + x * 73856093
	hash_val = hash_val * 31 + y * 19349663
	hash_val = hash_val * 31 + extra_salt * 83492791
	# Ensure positive
	return absi(hash_val)


## Get a deterministic random float in range [0, 1] for a position
static func _seeded_random(grid_pos: Vector2i, channel: int = 0) -> float:
	var seed_val = _position_to_seed(grid_pos, channel)
	# Use a simple LCG (Linear Congruential Generator)
	# These constants are from Numerical Recipes
	seed_val = (seed_val * 1103515245 + 12345) & 0x7FFFFFFF
	return float(seed_val) / float(0x7FFFFFFF)


## Get a deterministic random float in a range for a position
static func _seeded_range(grid_pos: Vector2i, min_val: float, max_val: float, channel: int = 0) -> float:
	var t = _seeded_random(grid_pos, channel)
	return lerpf(min_val, max_val, t)


## Get a deterministic random integer in a range for a position
static func _seeded_int_range(grid_pos: Vector2i, min_val: int, max_val: int, channel: int = 0) -> int:
	var t = _seeded_random(grid_pos, channel)
	return int(lerpf(float(min_val), float(max_val + 1), t))


## Generate variation for a prop at a specific grid position
static func generate_variation(grid_pos: Vector2i, definition: PropDefinition) -> VariationResult:
	var result = VariationResult.new()

	# Each parameter uses a different "channel" for independent randomness
	result.scale = _seeded_range(grid_pos, definition.scale_min, definition.scale_max, 0)
	result.rotation = deg_to_rad(_seeded_range(grid_pos, definition.rotation_min, definition.rotation_max, 1))
	result.hue_shift = _seeded_range(grid_pos, definition.hue_shift_min, definition.hue_shift_max, 2)
	result.saturation_shift = _seeded_range(grid_pos, definition.saturation_shift_min, definition.saturation_shift_max, 3)
	result.value_shift = _seeded_range(grid_pos, definition.value_shift_min, definition.value_shift_max, 4)
	result.variant_index = 0  # For future texture variant support

	return result


## Generate variation with custom parameters (for non-resource based props)
static func generate_custom_variation(
	grid_pos: Vector2i,
	scale_range: Vector2 = Vector2(0.85, 1.15),
	rotation_range: Vector2 = Vector2(-8.0, 8.0),
	hue_range: Vector2 = Vector2(-0.03, 0.03),
	saturation_range: Vector2 = Vector2(-0.1, 0.1),
	value_range: Vector2 = Vector2(-0.08, 0.08)
) -> VariationResult:
	var result = VariationResult.new()

	result.scale = _seeded_range(grid_pos, scale_range.x, scale_range.y, 0)
	result.rotation = deg_to_rad(_seeded_range(grid_pos, rotation_range.x, rotation_range.y, 1))
	result.hue_shift = _seeded_range(grid_pos, hue_range.x, hue_range.y, 2)
	result.saturation_shift = _seeded_range(grid_pos, saturation_range.x, saturation_range.y, 3)
	result.value_shift = _seeded_range(grid_pos, value_range.x, value_range.y, 4)

	return result


## Apply variation transforms to a Node2D
static func apply_to_node(node: Node2D, variation: VariationResult) -> void:
	node.scale = Vector2(variation.scale, variation.scale)
	node.rotation = variation.rotation


## Apply color variation to a Polygon2D
static func apply_to_polygon(polygon: Polygon2D, base_color: Color, variation: VariationResult) -> void:
	polygon.color = variation.apply_color_shift(base_color)


## Apply color variation to all Polygon2D children of a node
static func apply_color_to_children(parent: Node2D, base_colors: Dictionary, variation: VariationResult) -> void:
	"""
	Apply color shifts to named Polygon2D children.
	base_colors is a Dictionary mapping child names to their base colors.
	Example: {"Canopy": Color.GREEN, "Trunk": Color.BROWN}
	"""
	for child in parent.get_children():
		if child is Polygon2D and child.name in base_colors:
			child.color = variation.apply_color_shift(base_colors[child.name])


## Generate a unique identifier for batching similar props
## Props with the same batch key can potentially be batched together
static func get_batch_key(prop_type: String, variant_index: int) -> String:
	return "%s_%d" % [prop_type, variant_index]
