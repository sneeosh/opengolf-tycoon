shader_type canvas_item;

// Web-optimized terrain shader - reduced complexity for WebGL 2.0 performance
// Uses fewer noise octaves and simpler calculations than the desktop version

// Atlas layout information for proper tile center sampling
uniform vec2 tile_size = vec2(64.0, 32.0);
uniform vec2 atlas_size = vec2(1024.0, 512.0);

// Fixed base colors for each terrain type (matched to tileset_generator.gd)
uniform vec3 grass_color = vec3(0.42, 0.58, 0.32);
uniform vec3 fairway_color = vec3(0.39, 0.75, 0.39);
uniform vec3 green_color = vec3(0.36, 0.85, 0.46);
uniform vec3 rough_color = vec3(0.36, 0.52, 0.30);
uniform vec3 heavy_rough_color = vec3(0.30, 0.45, 0.26);

// Variation amounts
uniform float hue_variation : hint_range(0.0, 0.1) = 0.04;
uniform float value_variation : hint_range(0.0, 0.3) = 0.18;
uniform float saturation_variation : hint_range(0.0, 0.1) = 0.06;

// World-space position passed from vertex shader (stable during camera pan)
varying vec2 world_position;

void vertex() {
	world_position = VERTEX;
}

// Convert RGB to HSV
vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

// Convert HSV to RGB
vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// Procedural hash function
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// Smooth value noise from hash
float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	// Cubic interpolation (cheaper than quintic, good enough for web)
	f = f * f * (3.0 - 2.0 * f);

	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));

	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Simplified FBM - only 2 octaves for web performance
float fbm_web(vec2 p) {
	float value = 0.0;
	value += 0.5 * value_noise(p);
	value += 0.25 * value_noise(p * 2.0);
	return value;
}

// Detect terrain type from tile color and return fixed base color
vec3 get_terrain_base_color(vec3 tile_rgb) {
	vec3 hsv = rgb2hsv(tile_rgb);
	float hue = hsv.x;
	float sat = hsv.y;
	float val = hsv.z;

	if (val > 0.78 && sat > 0.45 && hue > 0.26 && hue < 0.42) {
		return green_color;
	}
	if (val > 0.68 && sat > 0.42 && hue > 0.24 && hue < 0.40) {
		return fairway_color;
	}
	if (val < 0.48 && hue > 0.20 && hue < 0.38) {
		return heavy_rough_color;
	}
	if (val < 0.55 && hue > 0.22 && hue < 0.38) {
		return rough_color;
	}
	return grass_color;
}

void fragment() {
	vec4 tile_color = texture(TEXTURE, UV);

	// Skip transparent pixels
	if (tile_color.a < 0.1) {
		COLOR = tile_color;
		return;
	}

	// Calculate the tile center UV within the atlas
	vec2 atlas_uv = UV * atlas_size;
	vec2 tile_index = floor(atlas_uv / tile_size);
	vec2 tile_center_uv = (tile_index * tile_size + tile_size * 0.5) / atlas_size;

	vec4 center_color = texture(TEXTURE, tile_center_uv);
	vec3 center_hsv = rgb2hsv(center_color.rgb);

	// Use world-space position from vertex shader - stable when camera pans
	vec2 world_pos = world_position;

	// Non-grass terrains: simple hash-based variation (no FBM loops)
	if (center_hsv.x < 0.15 || center_hsv.x > 0.45) {
		float subtle_noise = hash(world_pos * 0.02) - 0.5;
		vec3 hsv = rgb2hsv(tile_color.rgb);
		hsv.z += subtle_noise * 0.08;
		hsv.z = clamp(hsv.z, 0.0, 1.0);
		COLOR = vec4(hsv2rgb(hsv), 1.0);
		return;
	}

	// Grass terrain: 2-scale noise instead of 4
	vec3 base_color = get_terrain_base_color(center_color.rgb);
	vec3 base_hsv = rgb2hsv(base_color);

	float n_large = fbm_web(world_pos * 0.008);
	float n_fine = value_noise(world_pos * 0.06 + 200.0);

	// Combine into value pattern - 2 scales instead of 4
	float value_pattern = (n_large * 0.55 + n_fine * 0.45) - 0.5;

	// Single noise sample for hue (skip separate saturation noise)
	float hue_pattern = value_noise(world_pos * 0.012 + 500.0) - 0.5;

	// Apply variations to base HSV
	vec3 final_hsv = base_hsv;
	final_hsv.x += hue_pattern * hue_variation;
	final_hsv.y += value_pattern * saturation_variation * 0.5;
	final_hsv.z += value_pattern * value_variation;

	// Clamp to valid ranges
	final_hsv.x = fract(final_hsv.x);
	final_hsv.y = clamp(final_hsv.y, 0.1, 0.9);
	final_hsv.z = clamp(final_hsv.z, 0.12, 0.88);

	COLOR = vec4(hsv2rgb(final_hsv), 1.0);
}
