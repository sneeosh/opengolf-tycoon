# Continuous course surface

## Plain English

The terrain is drawn as one connected landscape, with diagonal mower passes,
fine putting turf, green collars, recessed sand, and gently moving water. Pixel
art entities retain their existing assets. The simulation still uses the same
64 × 32 world grid: this is a surface renderer, not an isometric coordinate or
physics migration. Camera controls, saved courses, hazards, and shot logic keep
their existing coordinates. Small visual edge blends do not redefine a ball's lie.

Desktop and web use the same shader. A 128 × 128 RGBA8 data texture costs 64 KiB;
each pixel stores a terrain ID in red and bunker depth in green. Theme colors
live in a separate 14 × 1 palette. Trees and rocks use native grass underneath.
The former per-tile turf, water, bunker, and path overlays are not instantiated,
so their rectangular patterns cannot cover the continuous surface.

## Algorithm

`CourseSurface` listens to local tile changes and coalesces GPU uploads to one
per frame. Quiet terrain generation explicitly rebuilds through
`TerrainGrid.refresh_all_overlays()`. Terrain/depth deserialization and successful
load events rebuild the data; theme changes replace only the palette.

For each fragment, sample the four surrounding tile centers. Add their bilinear
weights by material ID to obtain coverage `c`. Each sample's final weight is
`w × c^5`, normalized by the total. This preserves clear material boundaries
while softening connected corners. A low frequency coordinate perturbation of
at most 0.08 tiles breaks repeated stair steps. Tile centers retain their IDs.
Out-of-map sampling clamps to the nearest map texel.

Noise and mower passes use world pixels, so moving/zooming the camera does not
move the pattern. Water animation uses GPU time and requires no per-water-tile
script updates. Bunker coverage controls the shaded lip; depth increases its
shadow. Greens blend into the theme's fringe color at their edges.

Foliage uses one shared vertex shader, phased by each tree's world position.
Movement falls off quadratically toward the base. Cacti and dead trees are still.
EntityLayer sits at Z=2, keeping its existing relative shadow layers (-2/-1)
above the ground and below the sprites. Elevation lighting remains independent;
contour markings appear only while the elevation tool is active. Continuous
light and smoothly gated ambient occlusion avoid rectangular bands from the
low-resolution heightmap.

Quick Start cleanup preserves the freshly painted terrain before removing a
tree/rock and reapplies it afterward. Removal previously restored native ground,
leaving holes in fairways and greens. Water is now included in cleanup.

## Tuning levers

| Setting | Location | Value | Effect |
| --- | --- | --- | --- |
| Coverage exponent | `course_surface.gdshader` | 5 | Higher gives sharper edges |
| Contour perturbation | Same | 0.16 (±0.08 tiles) | Breaks mechanical outlines |
| Mower pass frequency | Same | 0.048 | Higher makes narrower passes |
| Bunker lip depth | Same | 0.23 + 0.19 × depth | Distinguishes deep bunkers |
| Breeze amplitude | `foliage_breeze.gdshader` | 1.15 pixels | Subtle canopy motion |
| Terrain light/shadow | `elevation_shader_controller.gd` | 0.28 / 0.28 | Retains turf color on slopes |

Validation covers normal painting, deep bunkers, quiet batches, deserialization,
all ten theme palettes, unchanged serialization, and tree/rock cleanup. Native
Compatibility rendering also exercises shader compilation; a browser-specific
performance/device test remains separate.
