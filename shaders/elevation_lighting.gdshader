shader_type canvas_item;

// --- Heightmap input ---
uniform sampler2D heightmap : filter_linear, repeat_disable;
uniform vec2 heightmap_size = vec2(512.0, 512.0);
uniform vec2 grid_size = vec2(128.0, 128.0);

// --- Isometric grid geometry ---
uniform vec2 tile_size = vec2(64.0, 32.0);

// --- Lighting ---
uniform vec2 light_direction = vec2(-0.7, -0.7);  // NW, normalized
uniform float light_intensity : hint_range(0.0, 1.0) = 0.5;
uniform float shadow_intensity : hint_range(0.0, 1.0) = 0.4;

// --- Cel shading ---
uniform int cel_steps : hint_range(2, 8) = 3;
uniform float cel_smoothness : hint_range(0.0, 0.1) = 0.03;

// --- Debug ---
uniform bool debug_heightmap = false;  // Set true to visualize raw heightmap data

// --- Contour lines ---
uniform bool contour_enabled = true;
uniform float contour_line_width = 1.5;  // In world pixels
uniform float contour_opacity : hint_range(0.0, 1.0) = 0.3;
uniform vec3 contour_color_high = vec3(0.45, 0.35, 0.25);  // Warm brown
uniform vec3 contour_color_low = vec3(0.25, 0.30, 0.40);   // Cool blue-gray

varying vec2 world_pos;

void vertex() {
	world_pos = VERTEX;
}

// Convert world position to heightmap UV
vec2 world_to_uv(vec2 wp) {
	return wp / (grid_size * tile_size);
}

float sample_height(vec2 wp) {
	vec2 uv = world_to_uv(wp);
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		return 0.5;  // Sea level for out-of-bounds
	}
	return texture(heightmap, uv).r;
}

// Compute pseudo-normal from heightmap gradient using central differences
vec3 compute_normal(vec2 wp, out float slope_mag) {
	float step_x = tile_size.x / 4.0;
	float step_y = tile_size.y / 4.0;

	float h_l = sample_height(wp - vec2(step_x, 0.0));
	float h_r = sample_height(wp + vec2(step_x, 0.0));
	float h_u = sample_height(wp - vec2(0.0, step_y));
	float h_d = sample_height(wp + vec2(0.0, step_y));

	// Scale for visible slopes — more = steeper perceived hills
	float height_scale = 8.0;
	float dx = (h_r - h_l) * height_scale;
	float dy = (h_d - h_u) * height_scale;

	slope_mag = length(vec2(dx, dy));
	return normalize(vec3(-dx, -dy, 1.0));
}

// Compute ambient occlusion from heightmap curvature (Laplacian)
// Concavities (valleys) return positive values, convexities (ridges) return negative
float compute_ao(vec2 wp, float center_height) {
	float step_x = tile_size.x / 4.0;
	float step_y = tile_size.y / 4.0;

	float h_l = sample_height(wp - vec2(step_x, 0.0));
	float h_r = sample_height(wp + vec2(step_x, 0.0));
	float h_u = sample_height(wp - vec2(0.0, step_y));
	float h_d = sample_height(wp + vec2(0.0, step_y));

	// Laplacian: sum of neighbors minus 4x center
	// Positive = valley (concave), negative = ridge (convex)
	float laplacian = (h_l + h_r + h_u + h_d) - 4.0 * center_height;
	return laplacian * 40.0;  // Scale for visibility
}

// Quantize lighting into clean cel-shading bands
float cel_shade(float ndotl) {
	float steps_f = float(cel_steps);
	float quantized = floor(ndotl * steps_f) / steps_f;
	float frac_part = fract(ndotl * steps_f);
	float smooth_edge = smoothstep(0.0, cel_smoothness * steps_f, frac_part);
	return mix(quantized, quantized + 1.0 / steps_f, smooth_edge);
}

void fragment() {
	vec2 uv = world_to_uv(world_pos);
	float height = sample_height(world_pos);
	float rel_height = height - 0.5;

	bool in_bounds = uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0;

	if (!in_bounds) {
		COLOR = vec4(0.0);
	} else if (debug_heightmap) {
		if (abs(rel_height) > 0.005) {
			if (rel_height > 0.0) {
				COLOR = vec4(1.0, 0.0, 1.0, 0.6);
			} else {
				COLOR = vec4(0.0, 1.0, 1.0, 0.6);
			}
		} else {
			float grid_line = step(0.98, fract(uv.x * grid_size.x)) + step(0.98, fract(uv.y * grid_size.y));
			COLOR = vec4(0.0, 1.0, 0.0, grid_line * 0.15);
		}
	} else {
		// --- Directional cel-shading ---
		float slope_mag = 0.0;
		vec3 normal = compute_normal(world_pos, slope_mag);
		vec3 light_dir_3d = normalize(vec3(light_direction, 0.6));
		float ndotl = dot(normal, light_dir_3d);
		float lighting = cel_shade(ndotl * 0.5 + 0.5);

		// Shade range: shadow_intensity below neutral, light_intensity above
		float shade = mix(1.0 - shadow_intensity, 1.0 + light_intensity, lighting);

		float alpha = 0.0;
		vec3 out_color = vec3(1.0);

		// Tight dead zone — only truly flat terrain stays clean
		if (shade < 0.99) {
			// Shadow: cool-tinted darkening
			out_color = vec3(0.12, 0.10, 0.20);
			alpha = (1.0 - shade) * 0.85;
		} else if (shade > 1.01) {
			// Highlight: warm-tinted brightening
			out_color = vec3(1.0, 0.98, 0.93);
			alpha = (shade - 1.0) * 0.70;
		}

		// --- Ambient occlusion from curvature ---
		float ao = compute_ao(world_pos, height);
		// Positive ao = valley (darken), negative ao = ridge (lighten slightly)
		if (ao > 0.03) {
			// Valley darkening — cool shadow
			float ao_alpha = clamp(ao * 0.5, 0.0, 0.30);
			out_color = mix(out_color, vec3(0.10, 0.08, 0.15), ao_alpha);
			alpha = max(alpha, ao_alpha);
		} else if (ao < -0.03) {
			// Ridge brightening — warm highlight
			float ao_alpha = clamp(-ao * 0.25, 0.0, 0.15);
			out_color = mix(out_color, vec3(1.0, 0.97, 0.90), ao_alpha);
			alpha = max(alpha, ao_alpha);
		}

		// --- Slope-dependent terrain tinting ---
		// Steep slopes shift toward earth/soil tone (exposed ground on hillsides)
		float slope_tint = smoothstep(0.2, 1.2, slope_mag);
		if (slope_tint > 0.0) {
			vec3 soil_color = vec3(0.45, 0.38, 0.28);  // Earthy brown
			float slope_alpha = slope_tint * 0.25;
			out_color = mix(out_color, soil_color, slope_alpha);
			alpha = max(alpha, slope_alpha);
		}

		// --- Height-based tint ---
		float height_tint_alpha = abs(rel_height) * 2.0;
		height_tint_alpha = clamp(height_tint_alpha, 0.0, 0.25);

		if (rel_height > 0.03) {
			out_color = mix(out_color, vec3(1.0, 0.95, 0.88), 0.4);
			alpha = max(alpha, height_tint_alpha);
		} else if (rel_height < -0.03) {
			out_color = mix(out_color, vec3(0.15, 0.18, 0.25), 0.4);
			alpha = max(alpha, height_tint_alpha);
		}

		// --- Contour lines (only at integer elevation boundaries) ---
		float contour_mask = 0.0;
		if (contour_enabled && abs(rel_height) > 0.02) {
			float elev_scale = 25.6 / 255.0;
			float elev_continuous = rel_height / elev_scale;
			float dist_to_boundary = abs(fract(elev_continuous + 0.5) - 0.5);

			float grad_mag = length(vec2(dFdx(elev_continuous), dFdy(elev_continuous)));
			float line_width_elev = contour_line_width * grad_mag;
			line_width_elev = max(line_width_elev, 0.04);

			contour_mask = 1.0 - smoothstep(0.0, line_width_elev, dist_to_boundary);
			contour_mask *= contour_opacity;

			// Major contour lines every 2 levels slightly thicker
			float major_continuous = elev_continuous * 0.5;
			float major_dist = abs(fract(major_continuous + 0.5) - 0.5);
			float major_mask = 1.0 - smoothstep(0.0, line_width_elev * 1.8, major_dist);
			contour_mask = max(contour_mask, major_mask * contour_opacity * 1.3);
		}

		vec3 c_color = rel_height >= 0.0 ? contour_color_high : contour_color_low;
		out_color = mix(out_color, c_color, contour_mask);
		alpha = max(alpha, contour_mask);

		// Cap alpha to keep terrain readable underneath
		COLOR = vec4(out_color, clamp(alpha, 0.0, 0.75));
	}
}
