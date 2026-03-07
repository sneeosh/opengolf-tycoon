# Heightmap Elevation Shader — Technical Spec

**Status:** Draft
**Author:** CTO
**Date:** 2026-03-07
**Target:** Godot 4.6, WebGL 2.0 (web export), Forward+ (desktop)

## Overview

Replace the current per-tile rectangle-overlay elevation shading (`ElevationOverlay` + `ElevationShadingOverlay`) with a unified **shader-driven heightmap system** that renders per-pixel lighting, contour lines, and terrain-type-aware elevation profiles. This gives the course rolling, sculpted depth while keeping the cartoon/tycoon cel-shaded aesthetic.

**Current state:** Elevation is an integer grid (`_elevation_grid`, -5 to +5). Visual feedback is two CPU-side `_draw()` overlays painting tinted rects and contour lines. There is no sub-tile height variation — a tile at elevation +2 is uniformly bright.

**Target state:** A single heightmap texture encodes sub-tile elevation as grayscale. A fragment shader reads this texture, computes pseudo-normals, applies directional cel-shading, and draws contour lines — all GPU-side.

---

## 1. Heightmap Data Model

### 1.1 Course-Wide Heightmap Texture

Use a **single course-wide heightmap** stored as an `ImageTexture` (R8 format, single-channel grayscale).

| Property | Value | Rationale |
|----------|-------|-----------|
| Resolution | 512×512 px (4 px per tile on a 128×128 grid) | Good sub-tile detail; 256 KB uncompressed R8. Small enough for web VRAM. |
| Value encoding | `0` = lowest (-5), `128` = sea level (0), `255` = highest (+5) | 8-bit gives 256 discrete levels. Each integer elevation step = ~25.6 grayscale units. |
| Coordinate mapping | Pixel `(tx * 4 + lx, ty * 4 + ly)` maps to tile `(tx, ty)`, local offset `(lx, ly)` ∈ [0,3] | Direct index arithmetic; no UV math needed on CPU side. |
| Update frequency | On elevation change (not every frame) | Heightmap is static between edits. |

```gdscript
# scripts/terrain/heightmap.gd
class_name Heightmap
extends RefCounted

const PIXELS_PER_TILE: int = 4
const SEA_LEVEL: int = 128  # Grayscale value for elevation 0
const ELEVATION_SCALE: float = 25.6  # Grayscale units per integer elevation level

var _image: Image
var _texture: ImageTexture
var _grid_width: int
var _grid_height: int

func _init(grid_width: int = 128, grid_height: int = 128) -> void:
	_grid_width = grid_width
	_grid_height = grid_height
	var tex_width := grid_width * PIXELS_PER_TILE   # 512
	var tex_height := grid_height * PIXELS_PER_TILE  # 512
	_image = Image.create(tex_width, tex_height, false, Image.FORMAT_R8)
	_image.fill(Color(float(SEA_LEVEL) / 255.0, 0, 0))  # R8: uses red channel only
	_texture = ImageTexture.create_from_image(_image)

func get_texture() -> ImageTexture:
	return _texture

## Convert integer elevation (-5..+5) to grayscale byte (0..255)
static func elevation_to_grayscale(elevation: int) -> int:
	return clampi(SEA_LEVEL + roundi(elevation * ELEVATION_SCALE), 0, 255)

## Convert grayscale byte back to float elevation
static func grayscale_to_elevation(gray: int) -> float:
	return (float(gray) - SEA_LEVEL) / ELEVATION_SCALE
```

### 1.2 Writing Elevation Data

When `TerrainGrid.set_elevation()` is called, we update the heightmap texture. The 4×4 sub-tile block for that tile gets filled with the **terrain-type elevation profile** (see §3) blended with the player-set base elevation.

```gdscript
## Update the heightmap for a single tile, applying its terrain profile
func set_tile_elevation(pos: Vector2i, base_elevation: int, terrain_type: int) -> void:
	var profile := ElevationProfiles.get_profile(terrain_type)
	var base_gray := elevation_to_grayscale(base_elevation)
	var px := pos.x * PIXELS_PER_TILE
	var py := pos.y * PIXELS_PER_TILE

	for ly in PIXELS_PER_TILE:
		for lx in PIXELS_PER_TILE:
			# profile is a 4×4 float array, values in [-1.0, +1.0] range
			# representing sub-tile elevation offset relative to base
			var offset_gray := roundi(profile[ly][lx] * ELEVATION_SCALE)
			var final_gray := clampi(base_gray + offset_gray, 0, 255)
			var value := float(final_gray) / 255.0
			_image.set_pixel(px + lx, py + ly, Color(value, 0, 0))

	_texture.update(_image)

## Bulk rebuild — call after loading a save or generating terrain
func rebuild_from_grids(terrain_grid: TerrainGrid) -> void:
	for y in _grid_height:
		for x in _grid_width:
			var pos := Vector2i(x, y)
			var elev := terrain_grid.get_elevation(pos)
			var ttype := terrain_grid.get_tile(pos)
			set_tile_elevation(pos, elev, ttype)
	_texture.update(_image)
```

### 1.3 Integration with TerrainGrid

`Heightmap` is owned by `TerrainGrid` and updated in response to existing signals:

```gdscript
# In terrain_grid.gd — additions
var _heightmap: Heightmap = null

func _ready() -> void:
	# ... existing setup ...
	_heightmap = Heightmap.new(grid_width, grid_height)
	elevation_changed.connect(_on_elevation_changed_heightmap)
	tile_changed.connect(_on_tile_changed_heightmap)

func _on_elevation_changed_heightmap(pos: Vector2i, _old: int, new_elev: int) -> void:
	_heightmap.set_tile_elevation(pos, new_elev, get_tile(pos))

func _on_tile_changed_heightmap(pos: Vector2i, _old: int, new_type: int) -> void:
	_heightmap.set_tile_elevation(pos, get_elevation(pos), new_type)

func get_heightmap_texture() -> ImageTexture:
	return _heightmap.get_texture()
```

---

## 2. Elevation Shader

### 2.1 Architecture

A single `elevation_lighting.gdshader` applied to a full-screen `ColorRect` (child of `TerrainGrid`, z_index = 3) that composites lighting on top of the existing terrain rendering. This is **additive/multiplicative** — it does not replace tile rendering, it shades it.

Two shader files:
- `shaders/elevation_lighting.gdshader` — desktop (full quality)
- `shaders/elevation_lighting_web.gdshader` — web (reduced samples)

### 2.2 Desktop Shader

```glsl
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
// These are set from GDScript each frame to map screen pixels → heightmap UVs
uniform vec2 camera_offset = vec2(0.0, 0.0);
uniform float camera_zoom = 1.0;
uniform vec2 viewport_size = vec2(1600.0, 1000.0);

varying vec2 world_position;

void vertex() {
	world_position = VERTEX;
}

// Sample heightmap at a world position, converting through isometric grid coords
vec2 world_to_heightmap_uv(vec2 world_pos) {
	// Screen → grid coordinate (inverse isometric transform)
	float grid_x = world_pos.x / tile_size.x + world_pos.y / tile_size.y;
	float grid_y = world_pos.y / tile_size.y - world_pos.x / tile_size.x;

	// Grid → heightmap UV
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
	float texel = 1.0 / heightmap_size.x;  // One heightmap pixel in UV
	// Step size in world space corresponding to one heightmap texel
	float step_world = tile_size.x / 4.0;  // 4 pixels per tile → 16 world px

	float h_l = sample_height(world_pos - vec2(step_world, 0.0));
	float h_r = sample_height(world_pos + vec2(step_world, 0.0));
	float h_u = sample_height(world_pos - vec2(0.0, step_world));
	float h_d = sample_height(world_pos + vec2(0.0, step_world));

	// Gradient (dh/dx, dh/dy) — height is [0,1], we scale to make normals visible
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

	// Check bounds — don't shade outside the grid
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

	// --- Contour lines ---
	float contour_mask = 0.0;
	if (contour_enabled) {
		// Height relative to sea level
		float rel_height = height - 0.5;  // 0.5 = sea level in [0,1]

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
```

### 2.3 Web Shader (Reduced)

Key differences from desktop:
- **2 height samples** instead of 4 for normal computation (forward differences only)
- **No `smoothstep` cel edges** — hard quantization only
- **Contour lines use `step()`** instead of `smoothstep()` (no AA)
- **No major/minor contour distinction**

```glsl
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
```

### 2.4 Shader Parameters Summary

| Parameter | Type | Default | Art Direction Purpose |
|-----------|------|---------|----------------------|
| `light_direction` | vec2 | (-0.7, -0.7) | Sun angle; sync with DayNightSystem |
| `light_intensity` | float | 0.45 | Strength of highlights on lit slopes |
| `shadow_intensity` | float | 0.35 | Depth of shadows on dark slopes |
| `ambient_light` | float | 0.3 | Minimum light level (prevents pure black) |
| `cel_steps` | int | 4 | Number of quantized light bands (fewer = more cartoony) |
| `cel_smoothness` | float | 0.02 | Softness at cel-shading step boundaries |
| `contour_enabled` | bool | true | Toggle topo-map contour lines |
| `contour_interval` | float | 0.1 | Elevation spacing between contour lines (~1 elevation level) |
| `contour_line_width` | float | 0.003 | Contour line thickness |
| `contour_opacity` | float | 0.35 | Contour line transparency |
| `contour_color_high` | vec3 | brown | Contour color for above sea level |
| `contour_color_low` | vec3 | blue-gray | Contour color for below sea level |

### 2.5 DayNight & Weather Integration

The shader's `light_direction` and intensity uniforms are updated from GDScript each frame to track the sun:

```gdscript
# In the new ElevationShaderController (scripts/terrain/elevation_shader_controller.gd)
extends Node

var _shader_material: ShaderMaterial
var _color_rect: ColorRect
var _terrain_grid: TerrainGrid

func _process(_delta: float) -> void:
	if not _shader_material:
		return

	# Update camera mapping uniforms
	var camera := get_viewport().get_camera_2d()
	if camera:
		_shader_material.set_shader_parameter("camera_offset", camera.global_position)
		_shader_material.set_shader_parameter("camera_zoom", camera.zoom.x)
		_shader_material.set_shader_parameter("viewport_size", get_viewport().get_visible_rect().size)

	# Sync light direction with time of day
	_update_light_from_time()

func _update_light_from_time() -> void:
	var hour: float = GameManager.current_hour
	var angle: float

	# Sun arc: rises east (right), sets west (left)
	# 6 AM = east (1, -0.3), noon = overhead (0, -1), 6 PM = west (-1, -0.3)
	if hour >= 6.0 and hour <= 18.0:
		var t := (hour - 6.0) / 12.0  # 0.0 at 6AM, 1.0 at 6PM
		angle = lerp(-PI * 0.15, -PI * 0.85, t)  # East to west arc
		var sun_dir := Vector2(cos(angle), sin(angle)).normalized()
		_shader_material.set_shader_parameter("light_direction", sun_dir)
		_shader_material.set_shader_parameter("light_intensity", 0.45)
		_shader_material.set_shader_parameter("shadow_intensity", 0.35)
	else:
		# Night: dim moonlight from above-left
		_shader_material.set_shader_parameter("light_direction", Vector2(-0.5, -0.8))
		_shader_material.set_shader_parameter("light_intensity", 0.15)
		_shader_material.set_shader_parameter("shadow_intensity", 0.15)

	# Weather dimming
	if GameManager.weather_system:
		var weather_mod := GameManager.weather_system.get_light_modifier()
		# Overcast/rain reduces contrast
		var current_light: float = _shader_material.get_shader_parameter("light_intensity")
		_shader_material.set_shader_parameter("light_intensity", current_light * weather_mod)
```

---

## 3. Terrain Type Elevation Profiles

Each terrain type has a default 4×4 sub-tile elevation profile. Values are **float offsets in elevation units** (±1.0 = ±1 full elevation level) added to the tile's base elevation.

### 3.1 Profile Definitions

```gdscript
# scripts/terrain/elevation_profiles.gd
class_name ElevationProfiles
extends RefCounted

## 4x4 sub-tile elevation profiles per terrain type.
## Each value is an offset in elevation units from the tile's base elevation.
## Positive = raised, negative = depressed relative to base.

const PROFILES: Dictionary = {
	# BUNKER: Bowl-shaped depression, steep lip at edges
	TerrainTypes.Type.BUNKER: [
		[ -0.15, -0.40, -0.40, -0.15 ],
		[ -0.40, -0.75, -0.75, -0.40 ],
		[ -0.40, -0.75, -0.75, -0.40 ],
		[ -0.15, -0.40, -0.40, -0.15 ],
	],

	# GREEN: Gentle undulation with subtle slopes
	TerrainTypes.Type.GREEN: [
		[  0.00,  0.05,  0.08,  0.05 ],
		[ -0.03,  0.02,  0.06,  0.10 ],
		[ -0.05, -0.02,  0.03,  0.08 ],
		[ -0.03,  0.00,  0.04,  0.05 ],
	],

	# FAIRWAY: Mild rolling terrain
	TerrainTypes.Type.FAIRWAY: [
		[  0.00,  0.02,  0.04,  0.03 ],
		[ -0.02,  0.00,  0.03,  0.05 ],
		[ -0.03, -0.01,  0.02,  0.04 ],
		[ -0.01,  0.01,  0.03,  0.02 ],
	],

	# TEE_BOX: Flat elevated platform
	TerrainTypes.Type.TEE_BOX: [
		[  0.20,  0.25,  0.25,  0.20 ],
		[  0.25,  0.30,  0.30,  0.25 ],
		[  0.25,  0.30,  0.30,  0.25 ],
		[  0.20,  0.25,  0.25,  0.20 ],
	],

	# ROUGH: Slightly uneven
	TerrainTypes.Type.ROUGH: [
		[  0.02, -0.03,  0.04, -0.01 ],
		[ -0.04,  0.03, -0.02,  0.05 ],
		[  0.05, -0.01,  0.03, -0.04 ],
		[ -0.02,  0.04, -0.03,  0.02 ],
	],

	# HEAVY_ROUGH: More pronounced unevenness
	TerrainTypes.Type.HEAVY_ROUGH: [
		[  0.05, -0.08,  0.10, -0.05 ],
		[ -0.10,  0.07, -0.06,  0.12 ],
		[  0.08, -0.05,  0.09, -0.10 ],
		[ -0.06,  0.10, -0.08,  0.05 ],
	],

	# WATER: Flat, lowest point
	TerrainTypes.Type.WATER: [
		[ -0.30, -0.30, -0.30, -0.30 ],
		[ -0.30, -0.30, -0.30, -0.30 ],
		[ -0.30, -0.30, -0.30, -0.30 ],
		[ -0.30, -0.30, -0.30, -0.30 ],
	],

	# GRASS: Essentially flat (no profile offset)
	TerrainTypes.Type.GRASS: [
		[  0.00,  0.00,  0.00,  0.00 ],
		[  0.00,  0.00,  0.00,  0.00 ],
		[  0.00,  0.00,  0.00,  0.00 ],
		[  0.00,  0.00,  0.00,  0.00 ],
	],

	# PATH: Flat
	TerrainTypes.Type.PATH: [
		[  0.00,  0.00,  0.00,  0.00 ],
		[  0.00,  0.00,  0.00,  0.00 ],
		[  0.00,  0.00,  0.00,  0.00 ],
		[  0.00,  0.00,  0.00,  0.00 ],
	],

	# ROCKS: Jagged, raised
	TerrainTypes.Type.ROCKS: [
		[  0.10,  0.30,  0.15,  0.05 ],
		[  0.25,  0.50,  0.40,  0.20 ],
		[  0.15,  0.35,  0.45,  0.30 ],
		[  0.05,  0.15,  0.25,  0.10 ],
	],

	# TREES: Raised mound at base
	TerrainTypes.Type.TREES: [
		[  0.00,  0.05,  0.05,  0.00 ],
		[  0.05,  0.15,  0.15,  0.05 ],
		[  0.05,  0.15,  0.15,  0.05 ],
		[  0.00,  0.05,  0.05,  0.00 ],
	],
}

## Get the 4×4 profile for a terrain type. Returns flat (zeros) if no profile defined.
static func get_profile(terrain_type: int) -> Array:
	if PROFILES.has(terrain_type):
		return PROFILES[terrain_type]
	# Default: flat
	return [
		[ 0.0, 0.0, 0.0, 0.0 ],
		[ 0.0, 0.0, 0.0, 0.0 ],
		[ 0.0, 0.0, 0.0, 0.0 ],
		[ 0.0, 0.0, 0.0, 0.0 ],
	]
```

### 3.2 Player Customization

Players modify elevation with the existing `ElevationTool` (raise/lower by ±1). The heightmap integrates:

1. **Base elevation** from `_elevation_grid` (player-controlled, -5 to +5)
2. **Profile offset** from `ElevationProfiles` (terrain-type-dependent sub-tile shape)
3. **Result**: `final_height = base + profile_offset`

Players don't manually sculpt sub-tile profiles — that would be too granular for a tycoon game. The profiles add automatic visual richness. If we later add a "sculpt" mode for course designers, we'd store per-tile profile overrides in a separate dictionary.

### 3.3 Procedural Variation

To prevent identical tiles from looking stamped, add noise-based variation to profiles:

```gdscript
## Apply pseudo-random variation to a profile for a specific tile position.
## Uses the tile position as seed so it's deterministic (consistent across redraws).
static func get_varied_profile(terrain_type: int, tile_pos: Vector2i) -> Array:
	var base_profile := get_profile(terrain_type)
	var seed_val := tile_pos.x * 7919 + tile_pos.y * 6271  # Deterministic hash

	var result: Array = []
	for y in 4:
		var row: Array = []
		for x in 4:
			var noise_seed := seed_val + y * 37 + x * 13
			# Pseudo-random in [-0.05, +0.05] range
			var noise := (fmod(abs(sin(float(noise_seed) * 43758.5453)), 1.0) - 0.5) * 0.10
			row.append(base_profile[y][x] + noise)
		result.append(row)
	return result
```

---

## 4. Edge Blending

### 4.1 Strategy: Heightmap-Level Bilinear Interpolation

Since we use `filter_linear` on the heightmap texture, the GPU automatically interpolates between neighboring pixels. At 4px per tile, this means the outermost pixel ring of each tile naturally blends with adjacent tiles.

However, 4px resolution means the blend zone is only 1/4 of a tile width. To get smoother transitions:

### 4.2 Overlap Writing

When writing a tile's heightmap data, also write blended values into the border pixels of adjacent tiles:

```gdscript
## Write heightmap with 1-pixel border blending into neighbors
func set_tile_elevation_blended(pos: Vector2i, base_elevation: int, terrain_type: int,
                                 terrain_grid: TerrainGrid) -> void:
	var profile := ElevationProfiles.get_varied_profile(terrain_type, pos)
	var base_gray := elevation_to_grayscale(base_elevation)
	var px := pos.x * PIXELS_PER_TILE
	var py := pos.y * PIXELS_PER_TILE

	# Write the core 4×4 block
	for ly in PIXELS_PER_TILE:
		for lx in PIXELS_PER_TILE:
			var offset_gray := roundi(profile[ly][lx] * ELEVATION_SCALE)
			var final_gray := clampi(base_gray + offset_gray, 0, 255)
			_set_pixel_safe(px + lx, py + ly, final_gray)

	# Blend border pixels with each neighbor
	for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n_pos := pos + dir
		if not terrain_grid.is_valid_position(n_pos):
			continue
		var n_elev := terrain_grid.get_elevation(n_pos)
		var n_type := terrain_grid.get_tile(n_pos)
		var n_profile := ElevationProfiles.get_varied_profile(n_type, n_pos)
		var n_base_gray := elevation_to_grayscale(n_elev)

		# Average the border pixels where tiles meet
		_blend_border(px, py, profile, base_gray,
		              n_pos.x * PIXELS_PER_TILE, n_pos.y * PIXELS_PER_TILE,
		              n_profile, n_base_gray, dir)

func _blend_border(px1: int, py1: int, prof1: Array, base1: int,
                   px2: int, py2: int, prof2: Array, base2: int,
                   dir: Vector2i) -> void:
	# For each pixel on the shared edge, average values from both tiles
	if dir == Vector2i(1, 0):  # Neighbor to the right
		for ly in PIXELS_PER_TILE:
			var v1 := base1 + roundi(prof1[ly][PIXELS_PER_TILE - 1] * ELEVATION_SCALE)
			var v2 := base2 + roundi(prof2[ly][0] * ELEVATION_SCALE)
			var avg := clampi((v1 + v2) / 2, 0, 255)
			_set_pixel_safe(px1 + PIXELS_PER_TILE - 1, py1 + ly, avg)
			_set_pixel_safe(px2, py2 + ly, avg)
	elif dir == Vector2i(0, 1):  # Neighbor below
		for lx in PIXELS_PER_TILE:
			var v1 := base1 + roundi(prof1[PIXELS_PER_TILE - 1][lx] * ELEVATION_SCALE)
			var v2 := base2 + roundi(prof2[0][lx] * ELEVATION_SCALE)
			var avg := clampi((v1 + v2) / 2, 0, 255)
			_set_pixel_safe(px1 + lx, py1 + PIXELS_PER_TILE - 1, avg)
			_set_pixel_safe(px2 + lx, py2, avg)
	# Left and up handled when those neighbors call this function

func _set_pixel_safe(x: int, y: int, gray_value: int) -> void:
	if x >= 0 and x < _image.get_width() and y >= 0 and y < _image.get_height():
		_image.set_pixel(x, y, Color(float(gray_value) / 255.0, 0, 0))
```

### 4.3 GPU-Side Smoothing

The shader's `filter_linear` on the heightmap sampler does bilinear interpolation, giving smooth transitions between any two adjacent heightmap pixels. Combined with the border blending above, this eliminates visible seams.

For the contour lines specifically, the smooth height gradient from interpolation means contour lines naturally curve across tile boundaries rather than snapping to grid edges.

---

## 5. Performance Considerations

### 5.1 Web Performance Budget

| Resource | Budget | Actual |
|----------|--------|--------|
| Heightmap VRAM | < 1 MB | 256 KB (512×512 R8) |
| Shader texture samples per fragment | ≤ 4 | 3 (web), 5 (desktop) |
| Additional draw calls | +1 | +1 (single full-screen ColorRect) |
| CPU per-frame overhead | < 0.5 ms | ~0.1 ms (uniform updates only) |
| Heightmap rebuild (full) | < 100 ms | ~60 ms (128×128 × 16 pixel writes) |

### 5.2 Why One Course-Wide Texture

| Approach | Pros | Cons |
|----------|------|------|
| **Course-wide texture** (chosen) | Single draw call; seamless blending; simple UV math | Must rebuild regions on edit |
| Per-tile textures | Isolated updates | 16,384 textures; no blending; massive draw call overhead |
| Texture array | Good GPU batching | Complex to manage; WebGL limits on array size |

**Decision:** Course-wide texture. The 512×512 R8 texture is tiny. Partial updates (updating a 4×4 pixel region per tile edit) are essentially free.

### 5.3 Optimization Strategies

1. **Partial heightmap updates**: On `elevation_changed` or `tile_changed`, only rewrite the affected tile's 4×4 block + neighbor borders (~40 pixel writes). Call `_texture.update(_image)` once.

2. **Shader LOD via zoom**: When camera is zoomed far out, disable contour lines and reduce cel_steps:
   ```gdscript
   if camera.zoom.x < 0.3:
       _shader_material.set_shader_parameter("contour_enabled", false)
       _shader_material.set_shader_parameter("cel_steps", 2)
   else:
       _shader_material.set_shader_parameter("contour_enabled", true)
       _shader_material.set_shader_parameter("cel_steps", 4)
   ```

3. **Web simplifications**: The web shader uses forward differences (2 samples) instead of central differences (4 samples), skips anti-aliased contour lines, and uses fewer cel-shading steps.

4. **No per-frame heightmap updates**: The heightmap texture only changes when the player modifies elevation or terrain. The shader reads it as a static texture.

5. **Viewport-sized ColorRect**: The overlay `ColorRect` covers only the viewport, not the entire world. Screen-to-world mapping happens in the shader.

---

## 6. Implementation Plan

### Phase 1: Core Heightmap + Basic Lighting (Maximum Visual Impact)

**Goal:** Get the shader rendering directional lighting on the existing elevation data.

**Files to create:**
| File | Purpose |
|------|---------|
| `scripts/terrain/heightmap.gd` | Heightmap data model (§1) |
| `scripts/terrain/elevation_profiles.gd` | Per-terrain-type profiles (§3) |
| `scripts/terrain/elevation_shader_controller.gd` | GDScript ↔ shader bridge (§2.5) |
| `shaders/elevation_lighting.gdshader` | Desktop elevation shader (§2.2) |
| `shaders/elevation_lighting_web.gdshader` | Web elevation shader (§2.3) |

**Files to modify:**
| File | Change |
|------|--------|
| `scripts/terrain/terrain_grid.gd` | Add `_heightmap` member; connect signals; add `_setup_elevation_shader()` |
| `scripts/terrain/elevation_overlay.gd` | Keep for active-mode (tool selected) contour lines + elevation numbers; disable passive hillshade (shader handles it now) |
| `scripts/terrain/elevation_shading_overlay.gd` | **Remove entirely** — replaced by shader |

**Steps:**
1. Create `Heightmap` class with `_init()`, `set_tile_elevation()`, `rebuild_from_grids()`
2. Create `ElevationProfiles` with static profile data
3. Write the desktop `elevation_lighting.gdshader`
4. Write the web `elevation_lighting_web.gdshader`
5. Create `ElevationShaderController` to manage the `ColorRect` + shader material
6. Integrate into `TerrainGrid._ready()`:
   - Create `Heightmap` instance
   - Create `ColorRect` child node with shader material
   - Create `ElevationShaderController` child node
   - Connect `elevation_changed` and `tile_changed` to heightmap updates
7. Update `ElevationOverlay`: remove passive hillshade/gradient drawing (keep active-mode numbers + contour lines for tool UX)
8. Delete `ElevationShadingOverlay` class and remove setup from `TerrainGrid`
9. Wire up `rebuild_from_grids()` in save/load path (`SaveManager` restore flow)

**Estimated integration points:**
```
terrain_grid.gd: ~30 lines added
elevation_overlay.gd: ~20 lines removed (passive mode simplification)
elevation_shading_overlay.gd: deleted
main.gd: no changes (TerrainGrid self-configures)
```

### Phase 2: Day/Night + Weather Sync

**Goal:** Shader lighting tracks the sun position and weather conditions.

1. Add `_update_light_from_time()` to `ElevationShaderController`
2. Connect to `EventBus.hour_changed` and `EventBus.weather_changed`
3. Add `WeatherSystem.get_light_modifier()` if not already present
4. Test sunrise/sunset shadow movement and overcast dimming

### Phase 3: Edge Blending + Profile Refinement

**Goal:** Smooth transitions between tiles with different elevations/terrain types.

1. Implement `set_tile_elevation_blended()` with neighbor border averaging
2. Add `get_varied_profile()` for per-tile noise variation
3. Test with bunker→fairway, fairway→green, and water→rough transitions
4. Tune profile values based on visual testing

### Phase 4: Contour Line Polish

**Goal:** Topo-map contour lines that are readable at all zoom levels.

1. Tune `contour_interval`, `contour_line_width`, `contour_opacity` for the 1600×1000 viewport
2. Add zoom-dependent contour density (more lines when zoomed in, fewer when zoomed out)
3. Ensure major contour lines (every 2 elevation levels) are visually distinct
4. Test contour line continuity across tile boundaries

### Phase 5: Art Direction Pass

**Goal:** Lock in final visual values with the cartoon/tycoon aesthetic.

1. Tune `cel_steps` (3-4 for cartoony, 6-8 for more realistic)
2. Adjust shadow/highlight colors to match each CourseTheme
3. Consider theme-specific contour colors (desert = sandy brown, links = gray)
4. Test with all 10 course themes
5. Update algorithm docs (`docs/algorithms/`) with new elevation rendering documentation

---

## Appendix A: Scene Tree After Implementation

```
TerrainGrid (Node2D)
├── TileMapLayer                      # Base terrain tiles
├── [Overlays]                        # Existing overlays (water, bunker, grass, etc.)
├── ElevationShaderRect (ColorRect)   # NEW — full-viewport, z_index=3
│   └── ShaderMaterial                #   elevation_lighting.gdshader
└── ElevationShaderController (Node)  # NEW — updates uniforms each frame
```

## Appendix B: Data Flow

```
Player raises tile (3,5) to elevation +2
  ↓
TerrainGrid.set_elevation(Vector2i(3,5), 2)
  ↓
elevation_changed signal emitted
  ↓
Heightmap._on_elevation_changed()
  ↓
set_tile_elevation_blended(Vector2i(3,5), 2, FAIRWAY)
  ↓
Write 4×4 pixels (base_gray=179 + fairway profile offsets)
  ↓
Blend border pixels with 4 neighbors
  ↓
_texture.update(_image)  ← GPU picks up new data
  ↓
Next frame: shader reads updated heightmap
  ↓
compute_normal() sees slope at tile boundary
  ↓
cel_shade() quantizes into 4 light bands
  ↓
Bright highlight on NW face, shadow on SE face
  ↓
Contour line drawn at elevation boundary
```

## Appendix C: Relation to Existing Overlays

| Overlay | Phase 1 Status | Long-term Status |
|---------|---------------|-----------------|
| `ElevationOverlay` | Keep: active-mode numbers + contour lines for tool UX | Keep (tool-specific feedback) |
| `ElevationShadingOverlay` | **Delete**: replaced by shader | Removed |
| `WaterOverlay` | Unchanged | May integrate water depth from heightmap later |
| `BunkerOverlay` | Unchanged | Bunker depression visible via shader; stipple stays |
| `GrassOverlay` | Unchanged | Grass blade length could respond to slope later |
| `FairwayOverlay` | Unchanged | Mowing stripe direction could follow slope later |
