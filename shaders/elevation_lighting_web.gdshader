shader_type canvas_item;

uniform sampler2D heightmap : filter_linear, repeat_disable;
uniform vec2 heightmap_size = vec2(512.0, 512.0);
uniform vec2 grid_size = vec2(128.0, 128.0);
uniform vec2 tile_size = vec2(64.0, 32.0);

uniform vec2 light_direction = vec2(-0.7, -0.7);
uniform float light_intensity : hint_range(0.0, 1.0) = 0.5;
uniform float shadow_intensity : hint_range(0.0, 1.0) = 0.4;
uniform int cel_steps : hint_range(2, 8) = 3;

uniform bool contour_enabled = true;
uniform float contour_line_width = 1.5;
uniform float contour_opacity : hint_range(0.0, 1.0) = 0.3;

varying vec2 world_pos;

void vertex() {
	world_pos = VERTEX;
}

vec2 world_to_uv(vec2 wp) {
	return wp / (grid_size * tile_size);
}

float sample_height(vec2 wp) {
	vec2 uv = world_to_uv(wp);
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		return 0.5;
	}
	return texture(heightmap, uv).r;
}

void fragment() {
	vec2 uv = world_to_uv(world_pos);
	float height = sample_height(world_pos);
	float rel_height = height - 0.5;
	bool in_bounds = uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0;

	if (!in_bounds) {
		COLOR = vec4(0.0);
	} else {
		float step_x = tile_size.x / 4.0;
		float step_y = tile_size.y / 4.0;

		// Forward differences (2 samples for web perf) + extra 2 for AO
		float h_r = sample_height(world_pos + vec2(step_x, 0.0));
		float h_d = sample_height(world_pos + vec2(0.0, step_y));
		float h_l = sample_height(world_pos - vec2(step_x, 0.0));
		float h_u = sample_height(world_pos - vec2(0.0, step_y));

		float dx = (h_r - h_l) * 8.0;
		float dy = (h_d - h_u) * 8.0;
		float slope_mag = length(vec2(dx, dy));
		vec3 normal = normalize(vec3(-dx, -dy, 1.0));

		vec3 light_dir_3d = normalize(vec3(light_direction, 0.6));
		float ndotl = dot(normal, light_dir_3d) * 0.5 + 0.5;

		float steps_f = float(cel_steps);
		float lighting = floor(ndotl * steps_f) / steps_f;
		float shade = mix(1.0 - shadow_intensity, 1.0 + light_intensity, lighting);

		float alpha = 0.0;
		vec3 out_color = vec3(1.0);

		if (shade < 0.99) {
			out_color = vec3(0.12, 0.10, 0.20);
			alpha = (1.0 - shade) * 0.85;
		} else if (shade > 1.01) {
			out_color = vec3(1.0, 0.98, 0.93);
			alpha = (shade - 1.0) * 0.70;
		}

		// Ambient occlusion from Laplacian curvature
		float ao = ((h_l + h_r + h_u + h_d) - 4.0 * height) * 40.0;
		if (ao > 0.03) {
			float ao_alpha = clamp(ao * 0.5, 0.0, 0.30);
			out_color = mix(out_color, vec3(0.10, 0.08, 0.15), ao_alpha);
			alpha = max(alpha, ao_alpha);
		} else if (ao < -0.03) {
			float ao_alpha = clamp(-ao * 0.25, 0.0, 0.15);
			out_color = mix(out_color, vec3(1.0, 0.97, 0.90), ao_alpha);
			alpha = max(alpha, ao_alpha);
		}

		// Slope-dependent earth tinting
		float slope_tint = smoothstep(0.2, 1.2, slope_mag);
		if (slope_tint > 0.0) {
			float slope_alpha = slope_tint * 0.25;
			out_color = mix(out_color, vec3(0.45, 0.38, 0.28), slope_alpha);
			alpha = max(alpha, slope_alpha);
		}

		// Height tint
		float height_tint_alpha = abs(rel_height) * 2.0;
		height_tint_alpha = clamp(height_tint_alpha, 0.0, 0.25);
		if (rel_height > 0.03) {
			out_color = mix(out_color, vec3(1.0, 0.95, 0.88), 0.4);
			alpha = max(alpha, height_tint_alpha);
		} else if (rel_height < -0.03) {
			out_color = mix(out_color, vec3(0.15, 0.18, 0.25), 0.4);
			alpha = max(alpha, height_tint_alpha);
		}

		// Simple contour lines
		if (contour_enabled && abs(rel_height) > 0.02) {
			float elev_scale = 25.6 / 255.0;
			float elev_continuous = rel_height / elev_scale;
			float dist_to_line = abs(fract(elev_continuous + 0.5) - 0.5);
			float contour_mask = step(dist_to_line, 0.12) * contour_opacity;
			out_color = mix(out_color, vec3(0.4, 0.35, 0.3), contour_mask);
			alpha = max(alpha, contour_mask);
		}

		COLOR = vec4(out_color, clamp(alpha, 0.0, 0.75));
	}
}
