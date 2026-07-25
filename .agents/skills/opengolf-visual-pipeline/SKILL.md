---
name: opengolf-visual-pipeline
description: Plan, generate, prepare, integrate, and visually validate cohesive 2D isometric art for OpenGolf Tycoon. Use for visual overhauls, sprite or tileset generation, UI reskins, art-direction work, visual-quality audits, Godogen-assisted asset work, and screenshot-based polish in this repository.
---

# OpenGolf visual pipeline

Improve the existing Godot/GDScript game; do not scaffold a replacement game.

## Required reading

- Read `references/art-direction.md` before planning or generating art.
- Read `references/asset-contracts.md` before modifying runtime assets or their consumers.

## Workflow

1. Run `python3 .agents/skills/opengolf-visual-pipeline/scripts/check_environment.py`.
2. Inspect the relevant scene, renderer, asset paths, import settings, placement preview, and collision/selection behavior.
3. Capture a reproducible baseline from the running game. Use the same course, camera, zoom, time, weather, and UI state for comparisons.
4. Select one bounded batch. Default to the Parkland vertical slice: terrain, one golfer family, core buildings, vegetation, and HUD chrome visible in a single representative screen.
5. Write the batch acceptance criteria and planned runtime files before generation.
6. Before any paid API call, tell the user the provider, call count, maximum cost, and outputs; wait for confirmation.
7. Generate high-resolution candidates into `.visual-pipeline/generated/<batch>/`, never directly into `assets/`. Use an approved in-game asset as an image-to-image style reference after the first hero asset is accepted.
8. Review every candidate at source size and final in-game size. Reject inconsistent projection, lighting, outline weight, palette, transparency, or footprint.
9. Prepare approved assets with `scripts/prepare_sprite.py`; preserve the asset contract or update every dependent path/anchor deliberately.
10. Promote approved files into `assets/`, make the smallest necessary GDScript/scene changes, and update `docs/visual-asset-manifest.md`.
11. Run Godot import, relevant GUT tests, and a visual comparison. Inspect the result rather than treating a clean build as visual proof.

## Generation tools

Use `scripts/asset_gen.py` for Gemini or xAI image/video generation. Prefer:

- Gemini for the hero style reference, exact multi-object kits, rotations, and image-to-image variants.
- Grok for inexpensive texture exploration and simple props when precise geometry is not required.
- A 2x2 or 3x3 kit at 1K plus `scripts/grid_slice.py` for small props; direct 1K-to-48px generation usually loses detail.

The tools print JSON including estimated cost. API keys are `GOOGLE_API_KEY` and `XAI_API_KEY`. Tripo3D is intentionally excluded because this is a 2D isometric pipeline.

## Visual QA gates

- Projection: consistent 2:1 isometric view; no perspective convergence.
- Light: upper-left key light; lower-right cast shadows; no baked shadow that conflicts with runtime shadows unless the whole asset family uses it.
- Silhouette: recognizable at the actual gameplay zoom.
- Pixel behavior: hard or deliberately softened edges consistently; no mixed pixel-art and painterly rendering.
- Footprint: bottom-center anchor and placement bounds match the existing entity.
- Theme: Parkland is the canonical first slice; variants follow the same material and value hierarchy.
- Performance: maintain the web target with 8 golfers and a 128x128 course.
- Regression: placement preview, selection, colorblind mode, seasons, day/night, saves, and web import remain functional.

## Non-negotiable safeguards

- Do not run Godogen `publish.sh` in this repo.
- Do not add C#, `.csproj`, build-time scene generators, 3D physics, or a replacement `project.godot`.
- Do not overwrite approved runtime assets without a recoverable branch and a before/after review.
- Do not generate all ten themes before the Parkland slice is accepted.
