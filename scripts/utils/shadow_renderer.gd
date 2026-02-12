extends RefCounted
class_name ShadowRenderer
## Utility class for rendering consistent drop shadows and contact shadows (AO).
## Used by all prop entities (trees, rocks, buildings, flags).

## Shadow configuration for an entity type
class ShadowConfig:
	var height: float = 32.0           ## Visual height of the object in pixels
	var base_width: float = 24.0       ## Width of the object's base
	var base_offset: Vector2 = Vector2.ZERO  ## Offset from entity position to shadow anchor
	var use_ellipse: bool = true       ## Use ellipse (true) or custom polygon (false)
	var custom_polygon: PackedVector2Array = PackedVector2Array()  ## For non-ellipse shapes
	var cast_drop_shadow: bool = true  ## Whether to cast a directional drop shadow
	var cast_contact_shadow: bool = true  ## Whether to show contact/AO shadow

	func _init(h: float = 32.0, w: float = 24.0) -> void:
		height = h
		base_width = w

## Generate an ellipse polygon for contact shadows
## Resolution controls smoothness (more points = smoother)
static func generate_ellipse(center: Vector2, radius_x: float, radius_y: float, resolution: int = 16) -> PackedVector2Array:
	var points = PackedVector2Array()
	for i in range(resolution):
		var angle = (float(i) / resolution) * TAU
		var x = center.x + cos(angle) * radius_x
		var y = center.y + sin(angle) * radius_y
		points.append(Vector2(x, y))
	return points

## Generate a drop shadow polygon (stretched ellipse in sun direction)
static func generate_drop_shadow(
	base_center: Vector2,
	config: ShadowConfig,
	sun_direction: Vector2,
	sun_elevation: float
) -> PackedVector2Array:
	# Calculate shadow stretch based on sun elevation
	var shadow_length = config.height / tan(deg_to_rad(sun_elevation))
	shadow_length = clamp(shadow_length, config.height * 0.3, config.height * 1.2)

	# Shadow tip position
	var shadow_tip = base_center + sun_direction * shadow_length

	# Generate stretched ellipse from base to tip
	var points = PackedVector2Array()
	var base_radius = config.base_width * 0.4
	var tip_radius = config.base_width * 0.15  # Tapers toward tip

	# Perpendicular vector for width
	var perp = Vector2(-sun_direction.y, sun_direction.x)

	# Build shadow shape: base arc -> tip -> back
	var resolution = 12

	# Base arc (semi-circle on the near side)
	for i in range(resolution + 1):
		var t = float(i) / resolution
		var angle = PI * t - PI / 2  # -90° to +90° relative to sun direction
		var offset = perp * cos(angle) * base_radius + sun_direction * sin(angle) * base_radius * 0.3
		points.append(base_center + offset)

	# Sides tapering to tip
	var side_steps = 6
	for i in range(1, side_steps):
		var t = float(i) / side_steps
		var pos = base_center.lerp(shadow_tip, t)
		var radius = lerp(base_radius, tip_radius, t)
		points.append(pos + perp * radius)

	# Tip
	points.append(shadow_tip)

	# Return side (mirror)
	for i in range(side_steps - 1, 0, -1):
		var t = float(i) / side_steps
		var pos = base_center.lerp(shadow_tip, t)
		var radius = lerp(base_radius, tip_radius, t)
		points.append(pos - perp * radius)

	return points

## Generate a soft contact shadow (ground AO ellipse)
static func generate_contact_shadow(
	base_center: Vector2,
	config: ShadowConfig
) -> PackedVector2Array:
	# Contact shadow is a simple ellipse at the base
	# Slightly wider than tall for isometric perspective
	var radius_x = config.base_width * 0.5
	var radius_y = config.base_width * 0.25  # Flattened for isometric
	return generate_ellipse(base_center + config.base_offset, radius_x, radius_y, 16)

## Create a Polygon2D node for the drop shadow
static func create_drop_shadow_polygon(
	config: ShadowConfig,
	shadow_system: Node = null  # ShadowSystem reference
) -> Polygon2D:
	var polygon = Polygon2D.new()
	polygon.name = "DropShadow"

	# Get sun parameters
	var sun_dir = Vector2(0.707, 0.707)  # Default SE
	var sun_elev = 45.0
	var shadow_color = Color(0, 0, 0, 0.3)

	if shadow_system:
		sun_dir = shadow_system.get_sun_direction_vector()
		sun_elev = shadow_system.sun_elevation
		shadow_color = shadow_system.get_shadow_color()

	polygon.polygon = generate_drop_shadow(config.base_offset, config, sun_dir, sun_elev)
	polygon.color = shadow_color
	polygon.z_index = -1  # Render below entity

	return polygon

## Create a Polygon2D node for the contact shadow (AO)
static func create_contact_shadow_polygon(
	config: ShadowConfig,
	shadow_system: Node = null
) -> Polygon2D:
	var polygon = Polygon2D.new()
	polygon.name = "ContactShadow"

	var shadow_color = Color(0, 0, 0, 0.25)
	if shadow_system:
		shadow_color = shadow_system.get_contact_shadow_color()

	polygon.polygon = generate_contact_shadow(config.base_offset, config)
	polygon.color = shadow_color
	polygon.z_index = -2  # Render below drop shadow

	return polygon

## Create both shadow polygons and add to parent node
static func add_shadows_to_entity(
	parent: Node2D,
	config: ShadowConfig,
	shadow_system: Node = null
) -> Dictionary:
	var shadows = {}

	if config.cast_contact_shadow:
		var contact = create_contact_shadow_polygon(config, shadow_system)
		parent.add_child(contact)
		shadows["contact"] = contact

	if config.cast_drop_shadow:
		var drop = create_drop_shadow_polygon(config, shadow_system)
		parent.add_child(drop)
		shadows["drop"] = drop

	return shadows

## Update existing shadow polygons when sun direction changes
static func update_shadows(
	shadows: Dictionary,
	config: ShadowConfig,
	shadow_system: Node
) -> void:
	if shadows.has("drop") and is_instance_valid(shadows["drop"]):
		var sun_dir = shadow_system.get_sun_direction_vector()
		var sun_elev = shadow_system.sun_elevation
		shadows["drop"].polygon = generate_drop_shadow(config.base_offset, config, sun_dir, sun_elev)
		shadows["drop"].color = shadow_system.get_shadow_color()

	if shadows.has("contact") and is_instance_valid(shadows["contact"]):
		shadows["contact"].color = shadow_system.get_contact_shadow_color()


# ============ MultiMesh2D Support for Performance ============

## Create a MultiMesh2D for batched shadow rendering (trees, rocks)
## Returns a configured MultiMesh2D node
static func create_shadow_multimesh(instance_count: int, shadow_texture: Texture2D = null) -> MultiMeshInstance2D:
	var mm_instance = MultiMeshInstance2D.new()
	mm_instance.name = "ShadowMultiMesh"

	var multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.use_colors = true
	multimesh.instance_count = instance_count

	# Create a simple quad mesh for the shadow
	var quad = QuadMesh.new()
	quad.size = Vector2(32, 16)  # Base size, will be scaled per instance
	multimesh.mesh = quad

	mm_instance.multimesh = multimesh

	if shadow_texture:
		mm_instance.texture = shadow_texture
	else:
		# Use a gradient texture for soft shadows
		mm_instance.texture = _create_soft_shadow_texture()

	mm_instance.z_index = -1

	return mm_instance

## Create a soft radial gradient texture for shadows
static func _create_soft_shadow_texture() -> GradientTexture2D:
	var texture = GradientTexture2D.new()
	texture.width = 64
	texture.height = 32
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)

	var gradient = Gradient.new()
	gradient.set_color(0, Color(0, 0, 0, 0.4))
	gradient.set_color(1, Color(0, 0, 0, 0.0))
	gradient.set_offset(0, 0.0)
	gradient.set_offset(1, 1.0)
	texture.gradient = gradient

	return texture

## Update a single instance in a MultiMesh shadow batch
static func update_multimesh_instance(
	multimesh: MultiMesh,
	index: int,
	position: Vector2,
	scale: Vector2,
	rotation: float = 0.0,
	color: Color = Color(1, 1, 1, 1)
) -> void:
	if index >= multimesh.instance_count:
		return

	var transform = Transform2D()
	transform = transform.rotated(rotation)
	transform = transform.scaled(scale)
	transform.origin = position

	multimesh.set_instance_transform_2d(index, transform)
	multimesh.set_instance_color(index, color)

## Batch update all shadow instances from position array
static func batch_update_shadows(
	multimesh: MultiMesh,
	positions: Array,  # Array of Vector2
	config: ShadowConfig,
	shadow_system: Node = null
) -> void:
	var sun_dir = Vector2(0.707, 0.707)
	var sun_elev = 45.0
	if shadow_system:
		sun_dir = shadow_system.get_sun_direction_vector()
		sun_elev = shadow_system.sun_elevation

	var shadow_offset = config.height / tan(deg_to_rad(sun_elev))
	shadow_offset = clamp(shadow_offset, config.height * 0.3, config.height * 1.2)
	var offset_vec = sun_dir * shadow_offset

	var scale = Vector2(config.base_width / 32.0, config.base_width / 64.0)
	var rotation = sun_dir.angle()

	for i in range(min(positions.size(), multimesh.instance_count)):
		var pos = positions[i] + offset_vec * 0.5 + config.base_offset
		update_multimesh_instance(multimesh, i, pos, scale, rotation)

	# Hide unused instances
	for i in range(positions.size(), multimesh.instance_count):
		update_multimesh_instance(multimesh, i, Vector2(-9999, -9999), Vector2.ZERO)


# ============ Preset Configurations ============

## Get shadow config for common entity types
static func get_preset(entity_type: String) -> ShadowConfig:
	match entity_type:
		"tree_oak":
			var config = ShadowConfig.new(48.0, 32.0)
			config.base_offset = Vector2(0, 8)
			return config
		"tree_pine":
			var config = ShadowConfig.new(56.0, 24.0)
			config.base_offset = Vector2(0, 8)
			return config
		"tree_palm":
			var config = ShadowConfig.new(52.0, 20.0)
			config.base_offset = Vector2(0, 8)
			return config
		"rock_small":
			var config = ShadowConfig.new(8.0, 12.0)
			config.base_offset = Vector2(0, 4)
			config.cast_drop_shadow = false  # Too small for drop shadow
			return config
		"rock_medium":
			var config = ShadowConfig.new(16.0, 20.0)
			config.base_offset = Vector2(0, 6)
			return config
		"rock_large":
			var config = ShadowConfig.new(24.0, 28.0)
			config.base_offset = Vector2(0, 8)
			return config
		"building_small":
			var config = ShadowConfig.new(32.0, 40.0)
			config.base_offset = Vector2(0, 16)
			return config
		"building_medium":
			var config = ShadowConfig.new(48.0, 64.0)
			config.base_offset = Vector2(0, 24)
			return config
		"building_large":
			var config = ShadowConfig.new(64.0, 96.0)
			config.base_offset = Vector2(0, 32)
			return config
		"flag":
			var config = ShadowConfig.new(40.0, 8.0)
			config.base_offset = Vector2(0, 2)
			return config
		_:
			return ShadowConfig.new()
