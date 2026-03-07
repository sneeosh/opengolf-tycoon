shader_type canvas_item;

// --- Heightmap input ---
uniform sampler2D heightmap : filter_linear, repeat_disable;
uniform vec2 heightmap_size = vec2(512.0, 512.0);
uniform vec2 grid_size = vec2(128.0, 128.0);

// --- Isometric grid geometry ---
uniform vec2 tile_size = vec2(64.0, 32.0);

// --- Lighting ---
uniform vec2 light_direction = vec2(-0.7, -0.7);  // NW, normalized
uniform float light_intensity : hint_range(0.0, 1.0) = 0.45;
uniform float shadow_intensity : hint_range(0.0, 1.0) = 0.35;
uniform float ambient_light : hint_range(0.0, 1.0) = 0.3;

// --- Cel shading ---
uniform int cel_steps : hint_range(2, 8) = 4;
uniform float cel_smoothness : hint_range(0.0, 0.1) = 0.02;

// --- Contour lines ---
uniform bool contour_enabled = true;
uniform float contour_interval = 0.1;      // In heightmap UV-space elevation units
uniform float contour_line_width = 0.003;   // Thickness in UV space
uniform float contour_opacity : hint_range(0.0, 1.0) = 0.35;
uniform vec3 contour_color_high = vec3(0.55, 0.40, 0.25);  // Warm brown
uniform vec3 contour_color_low = vec3(0.20, 0.25, 0.40);   // Cool blue-gray

// --- Camera mapping ---
// These are set from GDScript each frame to map screen pixels -> heightmap UVs
uniform vec2 camera_offset = vec2(0.0, 0.0);
uniform float camera_zoom = 1.0;
uniform vec2 viewport_size = vec2(1600.0, 1000.0);

varying vec2 world_position;

void vertex() {
	world_position = VERTEX;
}

// Sample heightmap at a world position, converting through isometric grid coords
vec2 world_to_heightmap_uv(vec2 world_pos) {
	// Screen -> grid coordinate (inverse isometric transform)
	float grid_x = world_pos.x / tile_size.x + world_pos.y / tile_size.y;
	float grid_y = world_pos.y / tile_size.y - world_pos.x / tile_size.x;

	// Grid -> heightmap UV
	return vec2(grid_x, grid_y) / grid_size;
}

float sample_height(vec2 world_pos) {
	vec2 uv = world_to_heightmap_uv(world_pos);
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		return 0.5;  // Sea level for out-of-bounds
	}
	return texture(heightmap, uv).r;
}

// Compute pseudo-normal from heightmap gradient using central differences
vec3 compute_normal(vec2 world_pos) {
	// Step size in world space corresponding to one heightmap texel
	float step_world = tile_size.x / 4.0;  // 4 pixels per tile -> 16 world px

	float h_l = sample_height(world_pos - vec2(step_world, 0.0));
	float h_r = sample_height(world_pos + vec2(step_world, 0.0));
	float h_u = sample_height(world_pos - vec2(0.0, step_world));
	float h_d = sample_height(world_pos + vec2(0.0, step_world));

	// Gradient (dh/dx, dh/dy) -- height is [0,1], we scale to make normals visible
	float height_scale = 4.0;  // Amplify height differences for visual effect
	float dx = (h_r - h_l) * height_scale;
	float dy = (h_d - h_u) * height_scale;

	// Construct normal from gradient (pointing "up" with z=1, tilted by slope)
	return normalize(vec3(-dx, -dy, 1.0));
}

// Quantize lighting into cel-shading steps
float cel_shade(float ndotl) {
	float steps_f = float(cel_steps);
	float quantized = floor(ndotl * steps_f) / steps_f;
	// Smooth transition at step boundaries to avoid harsh banding
	float frac_part = fract(ndotl * steps_f);
	float smooth_edge = smoothstep(0.0, cel_smoothness * steps_f, frac_part);
	return mix(quantized, quantized + 1.0 / steps_f, smooth_edge);
}

void fragment() {
	// Map this fragment to world position
	vec2 screen_pos = FRAGCOORD.xy;
	vec2 world_pos = (screen_pos - viewport_size * 0.5) / camera_zoom + camera_offset;

	// Sample height at this pixel
	float height = sample_height(world_pos);
	vec2 hm_uv = world_to_heightmap_uv(world_pos);

	// Check bounds -- don't shade outside the grid
	if (hm_uv.x < 0.0 || hm_uv.x > 1.0 || hm_uv.y < 0.0 || hm_uv.y > 1.0) {
		COLOR = vec4(0.0);
		return;
	}

	// --- Normal-based directional lighting ---
	vec3 normal = compute_normal(world_pos);
	// Light direction in 3D (flatten 2D direction onto XY, pointing up in Z)
	vec3 light_dir_3d = normalize(vec3(light_direction, 0.5));
	float ndotl = dot(normal, light_dir_3d);

	// Remap from [-1,1] to [0,1] and apply cel shading
	float lighting = cel_shade(ndotl * 0.5 + 0.5);

	// Compute final shade multiplier
	float shade = mix(1.0 - shadow_intensity, 1.0 + light_intensity, lighting);
	shade = mix(1.0, shade, 1.0 - ambient_light);  // Blend toward 1.0 by ambient amount

	// Height relative to sea level
	float rel_height = height - 0.5;  // 0.5 = sea level in [0,1]

	// --- Contour lines ---
	float contour_mask = 0.0;
	if (contour_enabled) {
		// Distance to nearest contour interval
		float contour_pos = rel_height / contour_interval;
		float dist_to_line = abs(fract(contour_pos + 0.5) - 0.5);

		// Anti-aliased contour line using screen-space derivatives
		float line_half_width = contour_line_width * 0.5;
		contour_mask = 1.0 - smoothstep(0.0, line_half_width, dist_to_line);
		contour_mask *= contour_opacity;

		// Major contour lines every 2 intervals are thicker
		float major_pos = rel_height / (contour_interval * 2.0);
		float major_dist = abs(fract(major_pos + 0.5) - 0.5);
		float major_mask = 1.0 - smoothstep(0.0, line_half_width * 1.8, major_dist);
		contour_mask = max(contour_mask, major_mask * contour_opacity * 1.3);
	}

	// --- Compose output ---
	// Shade < 1.0 = darken (multiply), shade > 1.0 = lighten (screen blend)
	// Output as multiplicative overlay: RGB = shade color, A = blend strength

	float alpha = 0.0;
	vec3 out_color = vec3(1.0);

	if (shade < 1.0) {
		// Shadow: darken underlying terrain
		out_color = vec3(0.05, 0.05, 0.15);  // Cool shadow color
		alpha = (1.0 - shade) * 0.7;
	} else if (shade > 1.0) {
		// Highlight: brighten underlying terrain
		out_color = vec3(1.0, 0.97, 0.90);  // Warm highlight
		alpha = (shade - 1.0) * 0.5;
	}

	// Blend contour lines
	vec3 c_color = rel_height >= 0.0 ? contour_color_high : contour_color_low;
	out_color = mix(out_color, c_color, contour_mask);
	alpha = max(alpha, contour_mask);

	COLOR = vec4(out_color, alpha);
}
