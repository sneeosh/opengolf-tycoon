shader_type canvas_item;

// Web-optimized terrain shader - minimal complexity for WebGL 2.0 performance
// Key optimizations vs desktop:
// - No FBM loops (unrolled 2-sample noise)
// - No HSV<->RGB conversions (operates directly in RGB space)
// - Terrain detection uses simple component checks instead of HSV
// - Single noise sample for non-grass terrains

// Atlas layout information for proper tile center sampling
uniform vec2 tile_size = vec2(64.0, 32.0);
uniform vec2 atlas_size = vec2(1024.0, 512.0);

// Fixed base colors for each terrain type
uniform vec3 grass_color = vec3(0.42, 0.58, 0.32);
uniform vec3 fairway_color = vec3(0.39, 0.75, 0.39);
uniform vec3 green_color = vec3(0.36, 0.85, 0.46);
uniform vec3 rough_color = vec3(0.36, 0.52, 0.30);
uniform vec3 heavy_rough_color = vec3(0.30, 0.45, 0.26);

// Variation amounts
uniform float hue_variation : hint_range(0.0, 0.1) = 0.04;
uniform float value_variation : hint_range(0.0, 0.3) = 0.18;
uniform float saturation_variation : hint_range(0.0, 0.1) = 0.06;

// World-space position passed from vertex shader
varying vec2 world_position;

void vertex() {
	world_position = VERTEX;
}

// Cheap hash function
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// Single-sample smooth noise (no loops)
float cheap_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);  // Cubic smoothstep

	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));

	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Detect terrain type from tile center color using simple RGB checks
// Avoids expensive HSV conversion
vec3 get_terrain_base_color(vec3 c) {
	// Green channel dominant = grass-type terrain
	// Putting green: very bright green
	if (c.g > 0.78 && c.g > c.r + 0.15) return green_color;
	// Fairway: bright green
	if (c.g > 0.65 && c.g > c.r + 0.1) return fairway_color;
	// Heavy rough: dark green
	if (c.g < 0.48 && c.g > c.r) return heavy_rough_color;
	// Rough: medium green
	if (c.g < 0.55 && c.g > c.r) return rough_color;
	// Default: grass
	return grass_color;
}

void fragment() {
	vec4 tile_color = texture(TEXTURE, UV);

	// Skip transparent pixels
	if (tile_color.a < 0.1) {
		COLOR = tile_color;
		return;
	}

	// Get tile center for terrain detection
	vec2 atlas_uv = UV * atlas_size;
	vec2 tile_index = floor(atlas_uv / tile_size);
	vec2 tile_center_uv = (tile_index * tile_size + tile_size * 0.5) / atlas_size;
	vec4 center_color = texture(TEXTURE, tile_center_uv);

	vec2 world_pos = world_position;

	// Non-grass terrains: single hash variation (cheapest possible)
	float cg = center_color.g;
	float cr = center_color.r;
	if (cg <= cr || cg <= center_color.b) {
		float subtle = hash(world_pos * 0.02) - 0.5;
		COLOR = vec4(tile_color.rgb + vec3(subtle * 0.06), 1.0);
		return;
	}

	// Grass terrain: 2 noise samples at different scales (no FBM loops)
	vec3 base_color = get_terrain_base_color(center_color.rgb);

	float n_large = cheap_noise(world_pos * 0.008);
	float n_fine = cheap_noise(world_pos * 0.05 + 200.0);

	// Combine into variation pattern
	float value_pattern = (n_large * 0.6 + n_fine * 0.4) - 0.5;

	// Single cheap hash for hue shift (skip full noise sample)
	float hue_shift = hash(world_pos * 0.01 + 500.0) - 0.5;

	// Apply directly to RGB (skip HSV conversion entirely for speed)
	// Hue shift: rotate R/B around G axis
	vec3 final_color = base_color;
	final_color.r += hue_shift * hue_variation * 0.5;
	final_color.b -= hue_shift * hue_variation * 0.5;
	// Value pattern: uniform brightness shift
	final_color += value_pattern * value_variation;

	// Clamp
	final_color = clamp(final_color, vec3(0.08), vec3(0.92));

	COLOR = vec4(final_color, 1.0);
}
