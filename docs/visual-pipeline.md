# Adapted Godogen visual pipeline

This repository uses Godogen's strongest ideas—prompted asset generation, explicit cost tracking, and proof from the running game—without adopting its fresh-project C#/.NET scaffold. OpenGolf remains a Godot 4.6 GDScript project.

## What is installed

- `AGENTS.md`: architecture and safety guardrails for future Codex tasks.
- `.agents/skills/opengolf-visual-pipeline/`: project-local workflow, art direction, asset contracts, and deterministic preparation tools.
- `visual_pipeline/parkland-vertical-slice.json`: the first bounded art batch.
- `docs/visual-asset-manifest.md`: provenance and approval log for generated runtime art.

The adaptation is derived in part from [htdt/godogen](https://github.com/htdt/godogen) under its MIT license. It intentionally excludes Godogen's C#, scene-generation, Jolt, and Tripo3D paths.

## Environment

Check the active task environment:

```bash
make visual-check
```

If the dependencies live in another virtual environment, point the target at its Python executable:

```bash
make visual-check VISUAL_PYTHON=/absolute/path/to/.venv/bin/python
```

To create a portable project environment:

```bash
python3 -m venv .venv
.venv/bin/python -m pip install -r .agents/skills/opengolf-visual-pipeline/scripts/requirements.txt
```

The API variables are `GOOGLE_API_KEY` and `XAI_API_KEY`. Never write their values into the repository.

## Batch workflow

1. Capture a reproducible before image.
2. Choose a small set of asset slots from the Parkland batch.
3. Establish one accepted hero asset and use it as the reference for related assets.
4. State the proposed API calls and maximum spend, then wait for approval.
5. Generate candidates under `.visual-pipeline/generated/`.
6. Remove the solid background, inspect the QA preview, and fit the selected sprite to its runtime canvas.
7. Promote the approved file into `assets/` and update its manifest entry.
8. Import/run the game, compare the same view, and check selection/placement/season/weather states.

Example candidate preparation:

```bash
VISUAL_PYTHON=/path/to/python
SKILL=.agents/skills/opengolf-visual-pipeline

$VISUAL_PYTHON $SKILL/scripts/remove_solid_bg.py \
  .visual-pipeline/generated/parkland/clubhouse.png \
  -o .visual-pipeline/prepared/clubhouse_rgba.png --preview

$VISUAL_PYTHON $SKILL/scripts/prepare_sprite.py \
  .visual-pipeline/prepared/clubhouse_rgba.png \
  -o .visual-pipeline/prepared/clubhouse_1.png \
  --canvas 200x160 --content 184x148
```

## Approval strategy

Approve the visual language in this order:

1. One Parkland proof screen.
2. Golfer family and animation readability.
3. Building family and upgrade hierarchy.
4. Vegetation/decorations.
5. Terrain and UI polish.
6. Other course themes through controlled palette/material variants.

This avoids paying for ten themes before projection, scale, lighting, and edge treatment are proven in the running game.
