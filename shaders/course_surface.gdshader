shader_type canvas_item;
// Receive the same day/night CanvasModulate as course objects.

// Shared by desktop and WebGL 2. No screen reads or per-tile draw calls.
uniform sampler2D terrain_data : filter_nearest, repeat_disable;
uniform sampler2D elevation_data : filter_linear, repeat_disable;
uniform vec2 relief_light = vec2(-0.6, -0.8);
uniform sampler2D palette : source_color, filter_nearest, repeat_disable;
uniform vec2 grid_size = vec2(128.0);
uniform vec2 tile_size = vec2(64.0, 32.0);
uniform vec4 fringe_color : source_color = vec4(0.38, 0.65, 0.28, 1.0);

float hash(vec2 p) {
	// Keep intermediates small: large sin hashes form bands on mobile/GL drivers.
	vec3 q = fract(vec3(p.x, p.y, p.x) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), u.x), u.y);
}

vec2 tile_at(vec2 p) {
	vec2 data = texture(terrain_data, (clamp(p, vec2(0.0), grid_size - 1.0) + 0.5) / grid_size).rg;
	float id = floor(data.r * 255.0 + 0.5);
	// Object tiles share the surrounding native turf; sprites supply the object.
	if (id == 11.0 || id == 13.0) { id = 1.0; }
	return vec2(id, data.g);
}

float same(float a, float b) { return 1.0 - step(0.5, abs(a - b)); }

float coverage(float id, vec4 ids, vec4 weights) {
	return dot(vec4(same(id, ids.x), same(id, ids.y), same(id, ids.z), same(id, ids.w)), weights);
}

vec3 surface(float id, float cover, float depth, vec2 world, float grain, float patch) {
	vec3 base = texture(palette, vec2((id + 0.5) / 14.0, 0.5)).rgb;
	float variation = (patch - 0.5) * 0.13 + (grain - 0.5) * 0.075;
	float edge = 1.0 - smoothstep(0.48, 0.83, cover);
	if (id == 2.0 || id == 6.0) {
		// Broad diagonal mower passes continue across every tile boundary.
		float pass = sin((world.x + world.y * 1.7) * 0.048);
		float stripe = smoothstep(-0.15, 0.15, pass);
		base *= 0.94 + stripe * 0.09;
		variation *= 0.35;
		base *= 1.0 - edge * 0.08;
	} else if (id == 5.0) {
		float stripe = smoothstep(-0.2, 0.2, sin((world.x - world.y * 1.5) * 0.10));
		base *= 0.98 + stripe * 0.035;
		base = mix(base, fringe_color.rgb, edge * 0.8);
		variation *= 0.18;
	} else if (id == 7.0) {
		// Recessed sand with a grass lip, warm bowl, and fine rake marks.
		base *= 1.0 - edge * (0.23 + depth * 0.19);
		float rake = sin(world.y * 1.15 + sin(world.x * 0.022) * 3.0);
		variation = (grain - 0.5) * 0.06 + rake * 0.012;
	} else if (id == 8.0) {
		// Calm deep water, pale shallows, and sparse moving reflected light.
		base *= 0.76 + patch * 0.10;
		base = mix(base, vec3(0.40, 0.66, 0.56), edge * 0.55);
		float wave = sin(world.y * 0.16 + sin(world.x * 0.024 + TIME * 0.3) * 2.3 + TIME * 0.8);
		float glint = smoothstep(0.95, 1.0, wave) * smoothstep(0.55, 0.78, noise(world * 0.04 + vec2(TIME * 0.07, 0.0)));
		base += vec3(0.30, 0.39, 0.33) * glint * 0.25;
		variation = 0.0;
	} else if (id == 9.0) {
		variation = (grain - 0.5) * 0.045;
		base *= 1.0 - edge * 0.13;
	} else if (id == 3.0 || id == 4.0 || id == 1.0) {
		// Small irregular tufts, with larger color masses at landscape scale.
		variation += (noise(world * vec2(0.32, 0.65)) - 0.5) * 0.045;
	}
	return clamp(base + vec3(variation * 0.78, variation, variation * 0.48), vec3(0.0), vec3(1.0));
}

void fragment() {
	vec2 world = UV * grid_size * tile_size;
	vec2 p = UV * grid_size;
	// A restrained contour perturbation breaks stair steps without moving tile centers.
	vec2 warp = vec2(noise(p * 0.72), noise(p * 0.72 + 37.0)) - 0.5;
	vec2 sample_pos = p - 0.5 + warp * 0.16;
	vec2 cell = floor(sample_pos);
	vec2 f = fract(sample_pos);
	vec2 a = tile_at(cell);
	vec2 b = tile_at(cell + vec2(1.0, 0.0));
	vec2 c = tile_at(cell + vec2(0.0, 1.0));
	vec2 d = tile_at(cell + vec2(1.0));
	vec4 ids = vec4(a.x, b.x, c.x, d.x);
	vec4 weights = vec4((1.0-f.x)*(1.0-f.y), f.x*(1.0-f.y), (1.0-f.x)*f.y, f.x*f.y);
	vec4 covers = vec4(coverage(a.x, ids, weights), coverage(b.x, ids, weights),
		coverage(c.x, ids, weights), coverage(d.x, ids, weights));
	// Sharpen material boundaries while rounding the outside of connected corners.
	vec4 blends = weights * pow(covers, vec4(5.0));
	blends /= max(dot(blends, vec4(1.0)), 0.0001);
	float grain = hash(floor(world));
	float patch = noise(world * 0.009) * 0.65 + noise(world * 0.035) * 0.35;
	vec3 color = surface(a.x, covers.x, a.y, world, grain, patch) * blends.x
		+ surface(b.x, covers.y, b.y, world, grain, patch) * blends.y
		+ surface(c.x, covers.z, c.y, world, grain, patch) * blends.z
		+ surface(d.x, covers.w, d.y, world, grain, patch) * blends.w;
	// Base elevations provide broad, continuous relief without per-tile profiles.
	vec2 step_uv = 1.5 / grid_size;
	float left_h = texture(elevation_data, UV - vec2(step_uv.x, 0.0)).b;
	float right_h = texture(elevation_data, UV + vec2(step_uv.x, 0.0)).b;
	float up_h = texture(elevation_data, UV - vec2(0.0, step_uv.y)).b;
	float down_h = texture(elevation_data, UV + vec2(0.0, step_uv.y)).b;
	vec3 normal = normalize(vec3(-(right_h-left_h)*5.0, -(down_h-up_h)*5.0, 1.0));
	vec3 sunlight = normalize(vec3(relief_light, 1.5));
	float relief = clamp(1.0 + (dot(normal, sunlight) - sunlight.z) * 0.45, 0.75, 1.12);
	COLOR = vec4(color * relief, 1.0);
}
