# Runtime asset contracts

## Global rules

- Keep source images in RGBA PNG.
- Use transparent padding rather than cropping ground contact or animation extremes.
- Anchor sprites at bottom center unless the consumer explicitly uses another offset.
- Preserve filenames when making a drop-in replacement. If paths change, update placement previews and all preload/load tables together.
- Commit Godot `.import` metadata when it controls filtering, mipmaps, repeat, or compression behavior.

## Current families

| Family | Current examples | Contract to verify |
|---|---|---|
| Terrain | `assets/tilesets/terrain_tileset.png` | Seven 64x64 atlas cells; each contains a 64x32 diamond aligned to the same origin. Verify `.tres` regions and terrain indices. |
| Buildings | `assets/sprites/buildings/*.png` | Transparent isometric sprites, usually 200x160. Verify `building.gd` offsets, footprint, selection shape, upgrade variants, and placement preview. |
| Golfers | `assets/sprites/golfer/**` | 48x48 frames. Preserve feet position, tier/direction/action folder layout, flip behavior, and animation frame counts consumed by `golfer.gd`. |
| Trees | `assets/sprites/trees/**` | Transparent, bottom-centered sprites. Verify season fallback and theme-specific lookup in `tree.gd`. |
| Decorations | `assets/sprites/decorations/*.png` | Verify `decoration.gd` lookup, footprint, and preview scaling. |
| Rocks | `assets/sprites/rocks/*.png` | Small/medium/large keys must remain intact. |

## Import and rendering checks

- The project sets the default canvas texture filter to nearest. Inspect `.import` overrides before changing edge treatment.
- Verify Forward+ and web shader paths where terrain appearance changes.
- Test at 0.5x, 1x, and close zoom. A source asset that looks attractive at 1K can fail at 48px.
- Check daylight, dusk, rain, winter/fall variants, colorblind mode, selected/hovered state, and transparent-edge halos.
- Compare runtime shadows with shadows baked into generated sprites. Remove one system if they double up.
