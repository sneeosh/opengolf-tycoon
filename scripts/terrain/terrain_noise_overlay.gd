extends Node2D
class_name TerrainNoiseOverlay
## Renders procedural noise variation over grass terrain using a full-screen approach
## This bypasses TileMapLayer shader limitations by using continuous screen coordinates

var _terrain_grid: TerrainGrid = null
var _material: ShaderMaterial = null

func _ready() -> void:
	# Render on top of base terrain but before decorative overlays
	# TileMapLayer is z=0, GrassOverlay is z=1
	# We use z=0 so we multiply terrain but not grass blades
	z_index = 0

	# Create the shader material
	_setup_shader()

func initialize(terrain_grid: TerrainGrid) -> void:
	_terrain_grid = terrain_grid
	queue_redraw()

func _setup_shader() -> void:
	var shader_code = """
shader_type canvas_item;
render_mode blend_mul;

// Procedural hash function
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// Smooth value noise
float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);

	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));

	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// FBM
float fbm(vec2 p, int octaves) {
	float value = 0.0;
	float amplitude = 0.5;
	float frequency = 1.0;

	for (int i = 0; i < octaves; i++) {
		value += amplitude * value_noise(p * frequency);
		frequency *= 2.0;
		amplitude *= 0.5;
	}
	return value;
}

uniform vec2 camera_offset = vec2(0.0, 0.0);
uniform float variation_strength = 0.15;

void fragment() {
	// Get world position from screen position + camera offset
	vec2 world_pos = FRAGCOORD.xy + camera_offset;

	// Generate multi-scale noise
	float n_large = fbm(world_pos * 0.006, 4);
	float n_medium = fbm(world_pos * 0.02 + 100.0, 3);
	float n_fine = fbm(world_pos * 0.05 + 200.0, 2);

	// Combine noise values
	float noise = (n_large * 0.4 + n_medium * 0.35 + n_fine * 0.25) - 0.5;

	// Output as grayscale variation with multiply blend
	float brightness = 1.0 + noise * variation_strength;
	COLOR = vec4(brightness, brightness, brightness, 1.0);
}
"""
	var shader = Shader.new()
	shader.code = shader_code

	_material = ShaderMaterial.new()
	_material.shader = shader
	# Use stronger variation (0.25) to help break up grid pattern
	_material.set_shader_parameter("variation_strength", 0.25)
	_material.set_shader_parameter("camera_offset", Vector2.ZERO)

	material = _material
	# Blend mode is set via render_mode blend_mul in the shader

func _process(_delta: float) -> void:
	# Update camera offset for world-space noise
	if _material:
		var camera = get_viewport().get_camera_2d()
		if camera:
			var viewport_size = get_viewport().get_visible_rect().size
			var camera_offset = camera.global_position - viewport_size / 2.0
			_material.set_shader_parameter("camera_offset", camera_offset)

func _draw() -> void:
	if not _terrain_grid:
		return

	# Draw a rectangle covering the entire terrain
	var terrain_size = Vector2(
		_terrain_grid.grid_width * _terrain_grid.tile_width,
		_terrain_grid.grid_height * _terrain_grid.tile_height
	)
	draw_rect(Rect2(Vector2.ZERO, terrain_size), Color.WHITE)
