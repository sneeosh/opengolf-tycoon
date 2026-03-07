shader_type canvas_item;

uniform sampler2D heightmap : filter_linear, repeat_disable;
uniform vec2 heightmap_size = vec2(512.0, 512.0);
uniform vec2 grid_size = vec2(128.0, 128.0);
uniform vec2 tile_size = vec2(64.0, 32.0);

uniform vec2 light_direction = vec2(-0.7, -0.7);
uniform float light_intensity : hint_range(0.0, 1.0) = 0.40;
uniform float shadow_intensity : hint_range(0.0, 1.0) = 0.30;
uniform int cel_steps : hint_range(2, 8) = 3;

uniform bool contour_enabled = true;
uniform float contour_interval = 0.1;
uniform float contour_opacity : hint_range(0.0, 1.0) = 0.25;

uniform vec2 camera_offset = vec2(0.0, 0.0);
uniform float camera_zoom = 1.0;
uniform vec2 viewport_size = vec2(1600.0, 1000.0);

varying vec2 world_position;

void vertex() {
	world_position = VERTEX;
}

vec2 world_to_heightmap_uv(vec2 world_pos) {
	float grid_x = world_pos.x / tile_size.x + world_pos.y / tile_size.y;
	float grid_y = world_pos.y / tile_size.y - world_pos.x / tile_size.x;
	return vec2(grid_x, grid_y) / grid_size;
}

float sample_height(vec2 world_pos) {
	vec2 uv = world_to_heightmap_uv(world_pos);
	return texture(heightmap, uv).r;
}

void fragment() {
	vec2 screen_pos = FRAGCOORD.xy;
	vec2 world_pos = (screen_pos - viewport_size * 0.5) / camera_zoom + camera_offset;
	vec2 hm_uv = world_to_heightmap_uv(world_pos);

	if (hm_uv.x < 0.0 || hm_uv.x > 1.0 || hm_uv.y < 0.0 || hm_uv.y > 1.0) {
		COLOR = vec4(0.0);
		return;
	}

	float height = sample_height(world_pos);
	float step_world = tile_size.x / 4.0;

	// Forward differences only (2 samples vs 4)
	float h_r = sample_height(world_pos + vec2(step_world, 0.0));
	float h_d = sample_height(world_pos + vec2(0.0, step_world));
	float dx = (h_r - height) * 4.0;
	float dy = (h_d - height) * 4.0;
	vec3 normal = normalize(vec3(-dx, -dy, 1.0));

	vec3 light_dir_3d = normalize(vec3(light_direction, 0.5));
	float ndotl = dot(normal, light_dir_3d) * 0.5 + 0.5;

	// Hard quantize (no smoothstep)
	float steps_f = float(cel_steps);
	float lighting = floor(ndotl * steps_f) / steps_f;
	float shade = mix(1.0 - shadow_intensity, 1.0 + light_intensity, lighting);

	float alpha = 0.0;
	vec3 out_color = vec3(1.0);

	if (shade < 1.0) {
		out_color = vec3(0.05, 0.05, 0.15);
		alpha = (1.0 - shade) * 0.6;
	} else if (shade > 1.0) {
		out_color = vec3(1.0, 0.97, 0.90);
		alpha = (shade - 1.0) * 0.4;
	}

	// Simple contour lines
	if (contour_enabled) {
		float rel_height = height - 0.5;
		float contour_pos = rel_height / contour_interval;
		float dist_to_line = abs(fract(contour_pos + 0.5) - 0.5);
		float contour_mask = step(dist_to_line, 0.15) * contour_opacity;
		out_color = mix(out_color, vec3(0.4, 0.35, 0.3), contour_mask);
		alpha = max(alpha, contour_mask);
	}

	COLOR = vec4(out_color, alpha);
}
