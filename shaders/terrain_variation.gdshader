shader_type canvas_item;

// Fully procedural terrain shader - generates ALL visual detail from world coordinates
// Uses purely procedural noise (no texture) to guarantee seamless patterns across tiles

// Atlas layout information for proper tile center sampling
uniform vec2 tile_size = vec2(64.0, 32.0);
uniform vec2 atlas_size = vec2(1024.0, 512.0);  // 16 cols * 64, 16 rows * 32

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

// Procedural hash function - no texture dependency
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// Smooth value noise from hash
float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	// Quintic interpolation for smoother results
	f = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);

	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));

	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Fractal Brownian Motion - multiple octaves for organic look
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

// Detect terrain type from tile color and return fixed base color
vec3 get_terrain_base_color(vec3 tile_rgb) {
	vec3 hsv = rgb2hsv(tile_rgb);
	float hue = hsv.x;
	float sat = hsv.y;
	float val = hsv.z;

	// Detect terrain by hue and value ranges
	// All grass-type terrains have hue in green range (0.20-0.42)

	// Green (putting green): very high value, bright green
	if (val > 0.78 && sat > 0.45 && hue > 0.26 && hue < 0.42) {
		return green_color;
	}
	// Fairway: high value, saturated green
	if (val > 0.68 && sat > 0.42 && hue > 0.24 && hue < 0.40) {
		return fairway_color;
	}
	// Heavy rough: low value, darker
	if (val < 0.48 && hue > 0.20 && hue < 0.38) {
		return heavy_rough_color;
	}
	// Rough: medium-low value (below grass)
	if (val < 0.55 && hue > 0.22 && hue < 0.38) {
		return rough_color;
	}
	// Default: grass (val ~0.58, hue ~0.27)
	return grass_color;
}

void fragment() {
	vec4 tile_color = texture(TEXTURE, UV);

	// Skip transparent pixels
	if (tile_color.a < 0.1) {
		COLOR = tile_color;
		return;
	}

	// Calculate the actual tile center UV within the atlas
	// UV is in atlas space, so we need to find which tile we're in and sample its center
	vec2 atlas_uv = UV * atlas_size;  // Convert to pixel coordinates in atlas
	vec2 tile_index = floor(atlas_uv / tile_size);  // Which tile (0-15, 0-15)
	vec2 tile_center_uv = (tile_index * tile_size + tile_size * 0.5) / atlas_size;  // Center of this tile

	vec4 center_color = texture(TEXTURE, tile_center_uv);
	vec3 center_hsv = rgb2hsv(center_color.rgb);

	// Use FRAGCOORD for screen-space position - guaranteed unique per pixel
	// This eliminates tile repetition at the cost of pattern shifting when panning
	vec2 world_pos = FRAGCOORD.xy;

	// For non-grass terrains (bunker, water, etc.), use original with minor variation
	if (center_hsv.x < 0.15 || center_hsv.x > 0.45) {
		// Not a grass-type terrain, apply subtle variation only
		float subtle_noise = fbm(world_pos * 0.02, 3) - 0.5;
		vec3 hsv = rgb2hsv(tile_color.rgb);
		hsv.z += subtle_noise * 0.1;
		hsv.z = clamp(hsv.z, 0.0, 1.0);
		COLOR = vec4(hsv2rgb(hsv), 1.0);
		return;
	}

	// Get fixed base color using CENTER sample (consistent across entire tile)
	vec3 base_color = get_terrain_base_color(center_color.rgb);
	vec3 base_hsv = rgb2hsv(base_color);

	// Generate multi-scale procedural noise using world_pos
	// Different scales and offsets create organic, non-repeating patterns
	float n_large = fbm(world_pos * 0.008, 4);           // Large rolling patches
	float n_medium = fbm(world_pos * 0.025 + 100.0, 3);  // Medium clumps
	float n_fine = fbm(world_pos * 0.06 + 200.0, 2);     // Fine detail
	float n_micro = value_noise(world_pos * 0.15 + 300.0); // Micro grain

	// Combine into value pattern (brightness variation) - centered around 0
	float value_pattern = (n_large * 0.35 + n_medium * 0.30 + n_fine * 0.25 + n_micro * 0.10) - 0.5;

	// Separate noise for hue and saturation (use different coordinates)
	float hue_pattern = fbm(world_pos * 0.012 + 500.0, 3) - 0.5;
	float sat_pattern = fbm(world_pos * 0.03 + 700.0, 2) - 0.5;

	// Apply variations to base HSV
	vec3 final_hsv = base_hsv;
	final_hsv.x += hue_pattern * hue_variation;
	final_hsv.y += sat_pattern * saturation_variation;
	final_hsv.z += value_pattern * value_variation;

	// Clamp to valid ranges
	final_hsv.x = fract(final_hsv.x);
	final_hsv.y = clamp(final_hsv.y, 0.1, 0.9);
	final_hsv.z = clamp(final_hsv.z, 0.12, 0.88);

	// Use solid alpha to ensure no tile edge artifacts
	COLOR = vec4(hsv2rgb(final_hsv), 1.0);
}
