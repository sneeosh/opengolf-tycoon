# Parkland runtime validation

Validated on 2026-07-25 with the official Godot 4.6.3 macOS universal build on Apple Silicon.

## Results

- The project imports all reviewed Parkland PNGs and reaches `Main scene ready`.
- The clubhouse, pro shop, snack bar, restroom, bench, and driving range preserve their footprints and bottom alignment at runtime.
- Oak, pine, and small-rock ground-contact offsets are correct.
- The deep-green, ivory, and brass theme remains legible across the HUD, information panels, and build tools.
- Daylight, dusk, deterministic light rain, 0.5x zoom, 1x zoom, and 1.5x zoom were captured and visually inspected.
- Both Compatibility/OpenGL and production Forward+/Metal render paths produced valid captures.
- The GUT suite completed 418 tests: 415 passed and 3 pre-existing course-value expectation tests failed. This branch does not modify the rating implementation or those tests.

## Accepted observations

- The six-building family is cohesive and readable at normal gameplay zoom.
- The 384x128 driving range correctly spans its six-tile footprint; its long, low silhouette remains identifiable at 0.5x.
- Runtime shadows do not visibly double the generated art.
- Dusk toning preserves entity and UI contrast. Old hard-coded glow rectangles remain disabled because they do not match the new windows.

## Follow-ups before calling the full Parkland screen complete

1. Generate or adapt spring, fall, and winter oak variants plus the winter pine variant. Seasonal overrides currently reveal the older art family.
2. Decide how prepared flower-bed, flag, and golf-cart assets should enter gameplay. The current course flower beds and flags are procedural, and the cart image has no active consumer.
3. Produce contract-safe 48x48 golfer walk and swing frames; the current motion pass remains reference-only.
4. Translate the approved terrain material board into the existing procedural/autotile contracts rather than replacing the atlas directly.
5. Either install the git-ignored local `godot_mcp` addon or remove its local project references before clean-clone validation. Its absent autoload produces startup errors but does not prevent the game from reaching the main scene.

The deterministic capture harness lives under ignored `.visual-pipeline/validation/` and does not ship with the game.
