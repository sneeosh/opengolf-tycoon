# OpenGolf Tycoon — Codebase Context

A SimGolf (2002) spiritual successor built in **Godot 4.6+** with GDScript. Players design golf courses, manage operations, attract golfers, and host tournaments.

**Main scene:** `res://scenes/main/main.tscn` (Node2D root)
**Engine:** Godot 4.6, Forward+ renderer, 1600x1000 viewport
**License:** MIT | **Version:** 0.1.0 (Alpha)

## Project Structure

```
scripts/
├── autoload/       # Singletons: GameManager, EventBus, SaveManager, FeedbackManager, SoundManager, ShadowSystem
├── course/         # HoleVisualizer, DifficultyCalculator, EntityLayer
├── effects/        # RainOverlay, HoleInOneCelebration, SandSprayEffect
├── entities/       # Golfer, Ball, Building, Tree, Rock, Flag
├── managers/       # GolferManager, BallManager, HoleManager, PlacementManager, BuildingRegistry, TournamentManager
├── systems/        # WindSystem, WeatherSystem, CourseRatingSystem, CourseTheme, FeedbackTriggers, GolferTier, TournamentSystem, DayNightSystem, CourseRecords, ShotAI, GolferNeeds, SeasonSystem, MilestoneSystem, TutorialSystem, DifficultyPresets, ColorblindMode
├── terrain/        # TerrainGrid, TerrainTypes, TilesetGenerator, + 10 overlay classes
├── tools/          # HoleCreationTool, ElevationTool, UndoManager, GenerateTileset
├── ui/             # 39 UI components (MainMenu, PauseMenu, SettingsMenu, MiniMap, FinancialPanel, MilestonesPanel, HoleStatsPanel, SaveLoadPanel, HotkeyPanel, etc.)
├── main/           # main.gd (scene controller)
└── utils/          # IsometricCamera
scenes/
├── main/main.tscn  # Primary game scene
└── entities/golfer.tscn
data/
├── buildings.json      # 8 building types with upgrade tiers
├── terrain_types.json  # 14 terrain type definitions
└── golfer_traits.json  # 5 golfer archetypes with spawn weights
assets/tilesets/        # Terrain tileset (PNG + .tres)
```

## Architecture

### Autoloads (Singletons, registered in project.godot)

1. **GameManager** (`scripts/autoload/game_manager.gd`) — Central game state: money ($50k start), reputation (0-100), day/hour cycle, game mode (MAIN_MENU/BUILDING/SIMULATING/PLAYING/PAUSED), game speed (PAUSED/NORMAL/FAST/ULTRA), current_theme (CourseTheme.Type). Holds `CourseData`, `DailyStatistics`, `HoleStatistics` inner classes. References terrain_grid, wind_system, weather_system, entity_layer, tournament_manager.
2. **EventBus** (`scripts/autoload/event_bus.gd`) — ~60 signals for decoupled cross-system communication. Categories: game state, economy, terrain/building, course design, golfers, shots, UI, wind/weather, camera, selection, day cycle, tournaments, save/load. Has `notify()` and `log_transaction()` convenience methods.
3. **SaveManager** (`scripts/autoload/save_manager.gd`) — JSON-based persistence (v2 format). Auto-saves on day change. Serializes game state, terrain, entities, holes, wind, weather, tournaments, course records, and course theme. Golfers are NOT persisted (they respawn naturally on load). Emits `theme_changed` on load to refresh overlays.
4. **FeedbackManager** (`scripts/autoload/feedback_manager.gd`) — Aggregates golfer thought bubbles into daily satisfaction metrics (positive/negative/neutral counts, satisfaction rating 0.0-1.0).

### Key Design Patterns

- **Signal-driven architecture**: Systems communicate through EventBus signals, not direct references. Past tense for events (`golfer_finished_hole`), present tense for state changes (`money_changed`).
- **Manager pattern**: Dedicated manager per entity type (GolferManager, BallManager, HoleManager). Managers handle spawning, removal, lifecycle.
- **State machines**: Golfer states (IDLE/WALKING/PREPARING_SHOT/SWINGING/WATCHING/FINISHED), Ball states (AT_REST/IN_FLIGHT/ROLLING/IN_WATER/OUT_OF_BOUNDS), Game modes.
- **Data-driven config**: Buildings, terrain types, golfer traits loaded from JSON files in `data/`.
- **Overlay pattern**: Each terrain visual effect (water shimmer, bunker stipple, etc.) is a separate overlay class managed by TerrainGrid.
- **RefCounted systems**: WindSystem, WeatherSystem, CourseRatingSystem are stateless/near-stateless with static calculation methods.

### Scene Tree (main.tscn)

```
Main (Node2D) ← main.gd
├── TerrainGrid (Node2D) ← terrain_grid.gd
│   └── TileMapLayer
├── Entities (Node2D)
│   ├── Golfers, Balls, Buildings (Node2D containers)
├── GolferManager, BallManager, HoleManager (Node)
├── Holes (Node2D)
├── IsometricCamera (Camera2D)
└── UI (CanvasLayer)
    └── HUD (Control) → TopBar, HoleInfoPanel, ToolPanel, BottomBar
```

## Algorithm Documentation

Detailed algorithm docs live in **`docs/algorithms/`** — see [`docs/algorithms/README.md`](docs/algorithms/README.md) for the full index. Each doc has a plain-English explanation and the actual math/code, plus a tuning levers table.

**When modifying any algorithm or adding a new one, update the corresponding doc in `docs/algorithms/`.** If adding a new system, create a new markdown file and add it to the README index.

Key docs: [shot-accuracy](docs/algorithms/shot-accuracy.md) · [putting](docs/algorithms/putting-system.md) · [shot-ai](docs/algorithms/shot-ai-target-finding.md) · [ball-physics](docs/algorithms/ball-physics.md) · [wind](docs/algorithms/wind-system.md) · [weather](docs/algorithms/weather-system.md) · [course-rating](docs/algorithms/course-rating.md) · [difficulty](docs/algorithms/difficulty-calculator.md) · [economy](docs/algorithms/economy.md) · [reputation](docs/algorithms/reputation.md) · [golfer-spawning](docs/algorithms/golfer-spawning.md) · [satisfaction](docs/algorithms/satisfaction-feedback.md) · [golfer-needs](docs/algorithms/golfer-needs.md) · [tournaments](docs/algorithms/tournament-system.md) · [day-night](docs/algorithms/day-night-cycle.md)

## Core Systems

### Terrain
- **TerrainGrid**: 128x128 isometric grid (64x32 px tiles). `_grid` dict (Vector2i → terrain type int), `_elevation_grid` (Vector2i → -5..+5).
- **14 terrain types**: EMPTY, GRASS, FAIRWAY, ROUGH, HEAVY_ROUGH, GREEN, TEE_BOX, BUNKER, WATER, PATH, OUT_OF_BOUNDS, TREES, FLOWER_BED, ROCKS.
- **TilesetGenerator**: Runtime procedural tileset (no external image assets required). Perlin noise, mowing stripes, sand stipple, water shimmer. Theme-aware via `set_theme_colors()` and `get_color()` methods.

### Golfer Simulation
- **Golfer** (`scripts/entities/golfer.gd`, ~61KB — most complex file): Skills (driving/accuracy/putting/recovery 0.0-1.0), personality (aggression/patience), 5 clubs (DRIVER/FAIRWAY_WOOD/IRON/WEDGE/PUTTER) with range/accuracy data. Shot calculation, target evaluation, tree collision, hazard avoidance. Group play (1-4 per group, "away" rule, double-par pickup). Explicit needs system (energy/comfort/hunger/pace) via `GolferNeeds` class.
- **GolferNeeds** (`scripts/systems/golfer_needs.gd`): Tracks 4 needs (energy, comfort, hunger, pace) that decay per-hole and while waiting. Buildings restore needs (bench→energy, restroom→comfort, snack bar/restaurant→hunger, clubhouse→all). Low needs trigger thought bubbles; critical needs apply mood penalties. Tier-modified decay rates. See [golfer-needs docs](docs/algorithms/golfer-needs.md).
- **ShotAI** (`scripts/systems/shot_ai.gd`): Structured decision pipeline for club selection and target finding. Multi-shot planning, wind compensation, recovery mode, Monte Carlo risk analysis. See [shot-ai docs](docs/algorithms/shot-ai-target-finding.md).
- **GolferManager**: Spawns groups based on green fee, max 8 concurrent golfers, spawn rate modified by course rating and weather. 4 tiers: BEGINNER/CASUAL/SERIOUS/PRO. See [golfer-spawning docs](docs/algorithms/golfer-spawning.md).
- **Ball**: Parabolic flight animation, terrain-based rolling distances, wind visual offset. Signals: `ball_landed`, `ball_state_changed`. See [ball-physics docs](docs/algorithms/ball-physics.md).

#### Shot Accuracy — Angular Dispersion Model
Shot error uses an **angular dispersion** model rather than absolute tile offsets. The shot direction is rotated by a miss angle sampled from a **gaussian (bell curve) distribution**, so most shots land near the target line with occasional big hooks/slices in the tails. Full details: [shot-accuracy docs](docs/algorithms/shot-accuracy.md). Key properties:

- **`miss_tendency`** (per-golfer, -1.0 to +1.0): Persistent hook/slice bias. Negative = hook, positive = slice. Amplitude set by tier (beginners: 0.4–0.8, pros: 0.0–0.15). Generated in `GolferTier.generate_skills()`.
- **Angular spread**: `max_spread_deg = (1.0 - total_accuracy) * 12.0`, with `spread_std_dev = max_spread / 2.5`. ~95% of shots land within `max_spread_deg` of target line.
- **Tendency bias**: `miss_tendency * (1.0 - total_accuracy) * 6.0` degrees added to every shot — lower-skill golfers can't compensate for their natural shot shape.
- **Shanks**: Rare catastrophic miss (35–55° off-line, 30–60% distance). Probability: `(1.0 - total_accuracy) * 4%`. Only on full swings (not putts/wedges). Direction follows `miss_tendency` sign.
- **Distance loss**: Topped/fat shots use gaussian distribution: `abs(gaussian) * (1.0 - accuracy) * 12%` max distance loss. Most shots near full distance.
- **Gaussian helper** (`_gaussian_random()`): Central Limit Theorem approximation using sum of 4 `randf()` calls. Mean ~0, std dev ~1, range ~±3.5.
- **Accuracy factors**: `total_accuracy = club_accuracy_modifier * skill_accuracy * lie_modifier`, with floors for wedges (0.80–0.96) and putts (skill-scaled). Club modifiers: Driver 0.70, FW 0.78, Iron 0.85, Wedge 0.95, Putter 0.98.

### Economy
- Green fee configurable $10-$200. Bankruptcy threshold at -$1000. See [economy docs](docs/algorithms/economy.md).
- Buildings: 8 types (Clubhouse, Pro Shop, Restaurant, Snack Bar, Driving Range, Cart Shed, Restroom, Bench). Proximity-based revenue. Clubhouse has 3 upgrade tiers.
- CourseRatingSystem: 4-star rating from Condition (30%), Design (20%), Value (30%), Pace (20%). See [course-rating docs](docs/algorithms/course-rating.md).
- Reputation: 0-100, daily decay by star level, per-golfer mood-based gains. See [reputation docs](docs/algorithms/reputation.md).

### Weather & Time
- **WindSystem**: Per-day random direction/speed (0-30 mph), hourly drift. Club-specific sensitivity (Driver 1.0x, Putter 0.0x). See [wind docs](docs/algorithms/wind-system.md).
- **WeatherSystem**: 6 types (SUNNY → HEAVY_RAIN). State machine transitions. See [weather docs](docs/algorithms/weather-system.md).
- **DayNightSystem**: 6 AM - 8 PM course hours. Visual tinting with sunrise/sunset. See [day-night docs](docs/algorithms/day-night-cycle.md).
- **TournamentSystem**: 4 tiers (Local/Regional/National/Championship) with escalating requirements. See [tournament docs](docs/algorithms/tournament-system.md).

### Course Themes
- **CourseTheme** (`scripts/systems/course_theme.gd`): Static class with 10 theme types (PARKLAND, DESERT, LINKS, MOUNTAIN, CITY, RESORT, HEATHLAND, WOODLAND, TROPICAL, MARSHLAND). Each theme provides:
  - `get_terrain_colors()` → per-theme color palette for all terrain types
  - `get_gameplay_modifiers()` → wind_base_strength, distance_modifier, maintenance_cost_multiplier, green_fee_baseline
  - `get_accent_color()`, `get_description()` → UI display helpers
- **Theme selection**: Happens on main menu via `MainMenu` class. User selects theme card, enters course name, starts game.
- **Theme application flow**:
  1. `GameManager.new_game()` sets `current_theme` and calls `TilesetGenerator.set_theme_colors()`
  2. `EventBus.theme_changed` signal emitted
  3. `TerrainGrid.regenerate_tileset()` rebuilds tileset with new colors
  4. Overlays (WaterOverlay, GrassOverlay) listen to `theme_changed` and update their colors
- **Save/load**: Theme stored as string in save data, restored via `CourseTheme.from_string()`. On load, theme colors re-applied and `theme_changed` emitted.
- **Theme-aware components**: TilesetGenerator, WaterOverlay, GrassOverlay, terrain shader parameters.

### Holes
- **HoleCreationTool**: 3-step workflow (tee box → green → flag).
- Auto-par from yardage: Par 3 <250y, Par 4 250-470y, Par 5 >470y.
- **DifficultyCalculator**: Per-hole rating (1-10) from length, hazards, slope, obstacles.

### Tools
- **ElevationTool**: Raise/lower tiles (-5 to +5). Affects shot distance and ball roll.
- **UndoManager**: 50-action stack with cost refunds.
- **IsometricCamera**: WASD pan, mouse wheel zoom, Q rotate.

## Conventions

- **Class naming**: PascalCase for entities (`Golfer`, `Ball`) and systems (`WindSystem`, `CourseRatingSystem`). Inner data classes inside GameManager (`CourseData`, `HoleData`, `DailyStatistics`).
- **Enums**: Heavily used — `State`, `Club`, `TriggerType`, `Tier`, `WeatherType`, `Type` (terrain), etc.
- **Signals**: Past tense for completed events, present tense for state changes. Request/response pairs (`save_requested` / `save_completed`).
- **Safe access**: `.get("key", fallback)` for dictionary access. Null checks before operations. Signal connection safety checks.
- **Export vars**: `@export` for tunable gameplay constants (max_concurrent_golfers, spawn cooldowns, grid dimensions).
- **Performance**: Transaction history capped at 1000 entries. Object pooling for balls. Weather transitions smooth over time.

### UI Patterns

- **CenteredPanel base class** (`scripts/ui/centered_panel.gd`): Extend this for panels that need to be centered on screen. Provides `show_centered()` (shows offscreen, waits for layout, then centers) and `toggle()` methods. Handles Godot's layout timing issues where `get_combined_minimum_size()` returns wrong values before first frame.

- **AcceptDialog with hotkey toggle**: For popup selection menus (trees, rocks, buildings) that open via hotkey, implement toggle behavior so pressing the same key closes the dialog:
  1. Store dialog reference as instance variable (e.g., `var _tree_dialog: AcceptDialog = null`)
  2. Keep dialog modal (default `exclusive = true`) so it captures keyboard input
  3. Connect to `window_input` signal to detect the hotkey and close:
     ```gdscript
     _tree_dialog.window_input.connect(_on_tree_dialog_input)

     func _on_tree_dialog_input(event: InputEvent) -> void:
         if event is InputEventKey and event.pressed and not event.echo:
             if event.keycode == KEY_T:
                 _on_tree_dialog_closed()
     ```
  4. Connect `canceled` and `confirmed` signals to cleanup function that frees dialog and sets reference to null
  5. In selection callbacks, also free dialog and set reference to null

## Build & Export

- **4 export targets** in `export_presets.cfg`: Windows, macOS, Linux, Web
- **CI/CD**: `.github/workflows/export-game.yml` — Godot 4.6 headless export on version tags, creates GitHub Release, deploys web build to Cloudflare Pages.

## Testing

Unit tests use **GUT** (Godot Unit Test) framework. Tests are in `tests/unit/`.

**Run tests:**
```bash
make test          # Using Makefile
./test.sh          # Using shell script
```

**Test coverage:** GameManager, SaveManager, CourseRatingSystem, CourseRecords, DailyStatistics, GolferTier.

**Override Godot path:** `make test GODOT=/path/to/godot` or `GODOT=/path/to/godot ./test.sh`

**User preference:** Run Godot tests manually via the editor (faster execution than CLI).

## Development Notes

- **SoundManager** (`scripts/autoload/sound_manager.gd`): Procedural audio system using `AudioStreamGenerator`. Synthesized swing, impact, ambient (wind, birds, rain), and UI sounds. Event-driven via EventBus signals. Master/SFX/ambient volume controls with mute toggle.
- Golfers are NOT saved/loaded (respawn naturally to avoid complex mid-action state serialization).
- Save format is versioned (SAVE_VERSION = 2) for forward compatibility.
- **Additional systems**: TutorialSystem (interactive onboarding), MilestoneSystem (trackable objectives), SeasonSystem (seasonal calendar), DifficultyPresets (Easy/Normal/Hard), ColorblindMode (accessibility), PauseMenu (Escape key), SettingsMenu, QuickStartCourse (pre-built demo course).
