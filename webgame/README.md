# OpenGolf Tycoon — Native Web Version

A from-scratch browser implementation of OpenGolf Tycoon in **Vite + TypeScript + PixiJS**,
being built alongside the Godot version. The simulation is re-implemented from the
formula specs in [`../docs/algorithms/`](../docs/algorithms/README.md); rendering and UI
are rebuilt natively (PixiJS world + DOM overlay). `../data/*.json` and
`../assets/sprites/` are shared with the Godot build.

## Commands

```bash
npm install
npm run dev      # dev server (copies ../data → public/data first)
npm test         # vitest — sim unit tests
npm run build    # typecheck + production bundle
```

## Architecture

```
src/
├── main.ts        # boot: data → sim → pixi → UI → loop
├── loop.ts        # fixed-timestep sim driver (60 Hz · 1x/3x/8x speed)
├── events.ts      # typed EventBus (camelCase Godot signal names)
├── data/          # loaders for the shared ../data/*.json
├── sim/           # PURE LOGIC — no pixi/DOM imports, seeded Rng, vitest-covered
│   ├── core/      # rng (mulberry32 + Godot-parity CLT gaussian)
│   ├── terrain/   # terrain grid data model, autotile edge masks
│   ├── course/    # themes (10 palettes)
│   └── game.ts    # root sim object
├── render/        # PixiJS: camera, runtime tile atlas, chunked terrain renderer
└── ui/            # DOM overlay panels
```

Key renderer design: the 128×128 map bakes into 4×4 chunks of 32×32 tiles, each a
RenderTexture — panning/zooming draws ~16 sprites instead of 16,384. Tile edits mark
affected chunks dirty (including neighbors, for autotile edge masks) and rebake with a
per-frame budget. The tile atlas is generated at runtime onto a canvas from the theme
palette (port of `tileset_generator.gd`'s web branch), so theme swaps are instant and no
image assets are needed for terrain.

## Status

- [x] **Phase 1 — terrain sandbox**: paint all 14 terrain types with autotile edge
      blending, elevation raise/lower (-5..+5) with shading, 3 brush sizes, all 10 theme
      palettes, pan/zoom camera, Godot-save-compatible terrain serialization, 23 sim tests
- [ ] Phase 2 — shot engine (headless) from docs/algorithms specs
- [ ] Phase 3 — holes + ShotAI port
- [ ] Phase 4 — golfers (sprites shared from ../assets/sprites)
- [ ] Phase 5 — tycoon core loop (economy, spawning, day cycle, HUD)
- [ ] …through Phase 12 — full parity + deploy (see plan in repo history)

Note: in headless/software-GL environments the renderer is fill-rate limited (~20 fps);
on any hardware GPU the visible scene is a handful of textured quads.
