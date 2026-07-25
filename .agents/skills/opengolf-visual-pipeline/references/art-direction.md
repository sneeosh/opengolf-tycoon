# OpenGolf art direction

## Target

Create a polished, warm, readable isometric management-game look: classic golf-club charm, clean modern UI, restrained detail, and strong terrain readability. The game should feel authored rather than photorealistic or generically AI-painted.

## Canonical view

- Orthographic 2:1 isometric projection.
- Terrain diamond: 64x32 px.
- View azimuth and visible faces must match existing buildings and trees.
- Key light from upper-left; highlights on upper-left planes, shade on lower-right planes.
- Transparent runtime sprites, with bottom-center ground contact.

## Shape language

- Slightly chunky, simplified silhouettes that survive gameplay zoom.
- Buildings use readable rooflines, doors, windows, and one or two signature details.
- Golfers prioritize pose and club silhouette over facial detail.
- Vegetation uses grouped foliage masses rather than noisy individual leaves.
- Terrain uses low-contrast texture so golfers, flags, buildings, and UI remain focal.

## Rendering language

- Stylized 2D raster art with crisp silhouettes and controlled anti-aliasing.
- Avoid photorealism, painterly smears, heavy outlines, excessive microtexture, and inconsistent pixel density.
- Use a narrow value range for ground; reserve strongest darks and highlights for entities and interaction cues.
- Do not bake text into generated UI or signage unless it will never be localized.

## Parkland vertical-slice palette

- Fairway: fresh mid green.
- Rough: darker and slightly desaturated.
- Green: smoother, cooler, and brighter than fairway.
- Bunker: warm pale sand with a darker lip.
- Water: cool blue with restrained cyan highlights.
- Buildings: cream walls, warm timber/brick roofs, muted blue accents.
- UI: deep clubhouse green, warm ivory panels, brass/gold accent, readable neutral text.

## Prompt anchor

Use this stable prefix for new Parkland assets, then describe the subject and exact output layout:

> Polished 2D isometric management-game asset, orthographic 2:1 projection, warm classic golf-club character, crisp readable silhouette, simplified hand-authored forms, restrained texture, upper-left key light, lower-right shading, consistent scale, no text, centered on a solid medium-gray background.

For an image-to-image family, reference the accepted hero asset and prompt only for subject, pose, materials, and required canvas layout.

## First approval screen

The Parkland proof screen should contain:

- fairway, rough, green, bunker, water, path, and elevation;
- clubhouse, pro shop, snack bar, restroom, bench, and driving-range cues;
- at least two golfer tiers walking and swinging;
- oak/pine vegetation, rock, flowers, flag, and golf cart;
- normal HUD, placement preview, and one information panel;
- daylight plus a second dusk/weather comparison.

Do not expand to the remaining themes until this screen is cohesive at normal gameplay zoom.
