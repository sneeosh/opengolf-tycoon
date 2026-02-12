extends Node2D
class_name PropBatcher
## Manages batched rendering of prop shadows using MultiMesh2D.
## Individual prop visuals remain as Polygon2D for flexibility,
## but shadows are batched together for performance.

## Dictionary of shadow batches keyed by shadow type
## Key format: "contact" or "drop"
var _shadow_batches: Dictionary = {}

## Registered props for batch management
## Key: prop instance ID, Value: {position, config, etc.}
var _registered_props: Dictionary = {}

## Maximum props per batch (MultiMesh instance limit)
const MAX_BATCH_SIZE: int = 1024

## Shadow mesh templates
var _contact_shadow_mesh: QuadMesh = null
var _drop_shadow_mesh: QuadMesh = null

## Shadow material with proper blending
var _shadow_material: CanvasItemMaterial = null


func _ready() -> void:
	_setup_shadow_meshes()
	_setup_shadow_material()


func _setup_shadow_meshes() -> void:
	# Contact shadow is a simple quad (ellipse handled by shader/texture)
	_contact_shadow_mesh = QuadMesh.new()
	_contact_shadow_mesh.size = Vector2(1, 1)  # Unit size, scaled per instance

	# Drop shadow is also a quad
	_drop_shadow_mesh = QuadMesh.new()
	_drop_shadow_mesh.size = Vector2(1, 1)


func _setup_shadow_material() -> void:
	_shadow_material = CanvasItemMaterial.new()
	_shadow_material.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX


## Register a prop for batched shadow rendering
## Returns true if registration successful
func register_prop(prop: Node2D, config: ShadowRenderer.ShadowConfig, world_position: Vector2) -> bool:
	if not is_instance_valid(prop):
		return false

	var prop_id = prop.get_instance_id()

	_registered_props[prop_id] = {
		"prop": prop,
		"config": config,
		"position": world_position,
		"variation": null  # Will be set by apply_variation
	}

	_mark_batch_dirty()
	return true


## Unregister a prop from batched rendering
func unregister_prop(prop: Node2D) -> void:
	var prop_id = prop.get_instance_id()
	if prop_id in _registered_props:
		_registered_props.erase(prop_id)
		_mark_batch_dirty()


## Apply variation to a registered prop
func apply_variation(prop: Node2D, variation: PropVariation.VariationResult) -> void:
	var prop_id = prop.get_instance_id()
	if prop_id in _registered_props:
		_registered_props[prop_id]["variation"] = variation
		_mark_batch_dirty()


## Mark batches as needing rebuild
func _mark_batch_dirty() -> void:
	# Defer rebuild to avoid multiple rebuilds in same frame
	call_deferred("_rebuild_batches")


## Rebuild all shadow batches
func _rebuild_batches() -> void:
	_clear_batches()

	if _registered_props.is_empty():
		return

	# Get shadow system for colors
	var shadow_system: Node = null
	if has_node("/root/ShadowSystem"):
		shadow_system = get_node("/root/ShadowSystem")

	var contact_color = Color(0, 0, 0, 0.25)
	var drop_color = Color(0, 0, 0, 0.3)
	if shadow_system:
		contact_color = shadow_system.get_contact_shadow_color()
		drop_color = shadow_system.get_shadow_color()

	# Collect shadow transforms
	var contact_transforms: Array[Transform2D] = []
	var contact_sizes: Array[Vector2] = []
	var drop_transforms: Array[Transform2D] = []
	var drop_sizes: Array[Vector2] = []

	for prop_id in _registered_props:
		var data = _registered_props[prop_id]
		var config: ShadowRenderer.ShadowConfig = data["config"]
		var pos: Vector2 = data["position"]
		var variation = data.get("variation")

		var scale_mult = 1.0
		if variation:
			scale_mult = variation.scale

		# Contact shadow
		if config.cast_contact_shadow:
			var contact_pos = pos + config.base_offset
			var contact_size = Vector2(config.base_width * 0.8, config.base_width * 0.4) * scale_mult
			contact_transforms.append(Transform2D(0, contact_pos))
			contact_sizes.append(contact_size)

		# Drop shadow
		if config.cast_drop_shadow and shadow_system:
			var sun_dir = shadow_system.get_sun_direction_vector()
			var sun_elev = shadow_system.sun_elevation
			var shadow_offset = shadow_system.calculate_shadow_offset(config.height * scale_mult)
			var drop_pos = pos + config.base_offset + shadow_offset
			var drop_size = shadow_system.calculate_shadow_scale(config.height * scale_mult, config.base_width * scale_mult)
			drop_transforms.append(Transform2D(0, drop_pos))
			drop_sizes.append(drop_size)

	# Create contact shadow batch
	if not contact_transforms.is_empty():
		_create_shadow_batch("contact", contact_transforms, contact_sizes, contact_color, -2)

	# Create drop shadow batch
	if not drop_transforms.is_empty():
		_create_shadow_batch("drop", drop_transforms, drop_sizes, drop_color, -1)


## Create a MultiMeshInstance2D for a shadow batch
func _create_shadow_batch(batch_name: String, transforms: Array[Transform2D], sizes: Array[Vector2], color: Color, z_idx: int) -> void:
	var multi_mesh = MultiMesh.new()
	multi_mesh.mesh = _contact_shadow_mesh if batch_name == "contact" else _drop_shadow_mesh
	multi_mesh.transform_format = MultiMesh.TRANSFORM_2D
	multi_mesh.use_custom_data = true
	multi_mesh.instance_count = transforms.size()

	for i in range(transforms.size()):
		var t = transforms[i]
		var s = sizes[i]
		# Encode size in the transform scale
		var scaled_transform = Transform2D(t.get_rotation(), t.get_origin())
		scaled_transform = scaled_transform.scaled(s)
		multi_mesh.set_instance_transform_2d(i, scaled_transform)
		# Store color in custom data (RGBA as 4 floats packed into Color)
		multi_mesh.set_instance_custom_data(i, color)

	var instance = MultiMeshInstance2D.new()
	instance.name = "ShadowBatch_" + batch_name
	instance.multimesh = multi_mesh
	instance.z_index = z_idx
	instance.modulate = color

	# Create ellipse texture for shadows
	var ellipse_texture = _create_ellipse_texture(64, 32)
	instance.texture = ellipse_texture

	add_child(instance)
	_shadow_batches[batch_name] = instance


## Create a soft ellipse texture for shadow rendering
func _create_ellipse_texture(width: int, height: int) -> ImageTexture:
	var img = Image.create(width, height, false, Image.FORMAT_RGBA8)
	var center = Vector2(width / 2.0, height / 2.0)
	var radius = Vector2(width / 2.0, height / 2.0)

	for y in range(height):
		for x in range(width):
			var pos = Vector2(x, y)
			var normalized = (pos - center) / radius
			var dist = normalized.length()
			# Soft falloff
			var alpha = clampf(1.0 - dist, 0.0, 1.0)
			alpha = alpha * alpha  # Quadratic falloff for softer edges
			img.set_pixel(x, y, Color(0, 0, 0, alpha))

	return ImageTexture.create_from_image(img)


## Clear all shadow batches
func _clear_batches() -> void:
	for batch_name in _shadow_batches:
		var batch = _shadow_batches[batch_name]
		if is_instance_valid(batch):
			batch.queue_free()
	_shadow_batches.clear()


## Update shadow colors when sun direction changes
func update_shadow_colors() -> void:
	var shadow_system: Node = null
	if has_node("/root/ShadowSystem"):
		shadow_system = get_node("/root/ShadowSystem")
	if not shadow_system:
		return

	if "contact" in _shadow_batches and is_instance_valid(_shadow_batches["contact"]):
		_shadow_batches["contact"].modulate = shadow_system.get_contact_shadow_color()

	if "drop" in _shadow_batches and is_instance_valid(_shadow_batches["drop"]):
		_shadow_batches["drop"].modulate = shadow_system.get_shadow_color()


## Get total number of registered props
func get_prop_count() -> int:
	return _registered_props.size()


## Get total number of batched shadow instances
func get_shadow_instance_count() -> int:
	var count = 0
	for batch_name in _shadow_batches:
		var batch = _shadow_batches[batch_name]
		if is_instance_valid(batch) and batch.multimesh:
			count += batch.multimesh.instance_count
	return count
