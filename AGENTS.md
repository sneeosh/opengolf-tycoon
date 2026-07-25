# OpenGolf Tycoon agent guide

OpenGolf Tycoon is a Godot 4.6, Forward+ 2D isometric game written in GDScript. The main scene is `res://scenes/main/main.tscn`; the viewport is 1600x1000 and terrain uses 64x32 isometric tiles.

## Architecture guardrails

- Preserve the GDScript, `.tscn`, signal-driven, manager, save/load, and GUT-test architecture.
- Do not convert the project to C#/.NET, rebuild scenes from scratch, or introduce Jolt/3D systems as part of visual work.
- Do not replace simulation or economy code during an art pass. Keep visual changes isolated and reviewable.
- Treat `assets/`, `.import` settings, sprite anchors, collision shapes, placement previews, and runtime asset paths as one contract.
- Never run Godogen's `publish.sh --force` in this repository.
- Keep paid asset generation opt-in: state the provider, number of calls, maximum cost, and intended files, then obtain user confirmation before the first call.
- Generate into `.visual-pipeline/` first. Promote only approved assets into `assets/`.
- Preserve or deliberately migrate saved-game compatibility.

## Visual work

Use the repository-local `$opengolf-visual-pipeline` skill for art direction, asset generation, integration, and visual QA. Work one visual batch at a time, beginning with the Parkland vertical slice unless the user chooses another theme.

Before changing visuals, capture or identify a baseline. After changes, run the available import/tests and compare the running game at the same course, camera, zoom, time, and weather.

## Build and test

Use `make test`, `make run`, and `make editor`. Override the executable with `GODOT=/absolute/path/to/godot` when it is not on `PATH`.

Run `make visual-check` to inspect visual-pipeline dependencies and `make visual-audit` to inventory committed PNG dimensions.
