# OpenGolf Tycoon — Codebase Context

A SimGolf (2002) spiritual successor built in **Godot 4.6+** with GDScript. Players design golf courses, manage operations, attract golfers, and host tournaments.

**Main scene:** `res://scenes/main/main.tscn` (Node2D root)
**Engine:** Godot 4.6, Forward+ renderer, 1600x1000 viewport
**License:** MIT | **Version:** 0.1.0 (Alpha)

## Project Structure

```
scripts/
├── autoload/       # 4 singletons: GameManager, EventBus, SaveManager, FeedbackManager
├── course/         # HoleVisualizer, DifficultyCalculator, EntityLayer
├── effects/        # RainOverlay, HoleInOneCelebration, SandSprayEffect
├── entities/       # Golfer, Ball, Building, Tree, Rock, Flag
├── managers/       # GolferManager, BallManager, HoleManager, PlacementManager, BuildingRegistry, TournamentManager
├── systems/        # WindSystem, WeatherSystem, CourseRatingSystem, FeedbackTriggers, GolferTier, TournamentSystem, DayNightSystem, CourseRecords
├── terrain/        # TerrainGrid, TerrainTypes, TilesetGenerator, + 10 overlay classes
├── tools/          # HoleCreationTool, ElevationTool, UndoManager, GenerateTileset
├── ui/             # 12 UI components (MiniMap, FinancialPanel, HoleStatsPanel, etc.)
├── main/           # main.gd (scene controller)
└── utils/          # IsometricCamera
scenes/
├── main/main.tscn  # Primary game scene
└── entities/golfer.tscn
data/
├── buildings.json      # 8 building types with upgrade tiers
├── terrain_types.json  # 11 terrain type definitions
└── golfer_traits.json  # 5 golfer archetypes with spawn weights
assets/tilesets/        # Terrain tileset (PNG + .tres)
```

## Architecture

### Autoloads (Singletons, registered in project.godot)

1. **GameManager** (`scripts/autoload/game_manager.gd`) — Central game state: money ($50k start), reputation (0-100), day/hour cycle, game mode (MAIN_MENU/BUILDING/SIMULATING/PLAYING/PAUSED), game speed (PAUSED/NORMAL/FAST/ULTRA). Holds `CourseData`, `DailyStatistics`, `HoleStatistics` inner classes. References terrain_grid, wind_system, weather_system, entity_layer, tournament_manager.
2. **EventBus** (`scripts/autoload/event_bus.gd`) — ~60 signals for decoupled cross-system communication. Categories: game state, economy, terrain/building, course design, golfers, shots, UI, wind/weather, camera, selection, day cycle, tournaments, save/load. Has `notify()` and `log_transaction()` convenience methods.
3. **SaveManager** (`scripts/autoload/save_manager.gd`) — JSON-based persistence (v2 format). Auto-saves on day change. Serializes game state, terrain, entities, holes, wind, weather, tournaments, course records. Golfers are NOT persisted (they respawn naturally on load).
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

## Core Systems

### Terrain
- **TerrainGrid**: 128x128 isometric grid (64x32 px tiles). `_grid` dict (Vector2i → terrain type int), `_elevation_grid` (Vector2i → -5..+5).
- **14 terrain types**: EMPTY, GRASS, FAIRWAY, ROUGH, HEAVY_ROUGH, GREEN, TEE_BOX, BUNKER, WATER, PATH, OUT_OF_BOUNDS, TREES, FLOWER_BED, ROCKS.
- **TilesetGenerator**: Runtime procedural tileset (no external image assets required). Perlin noise, mowing stripes, sand stipple, water shimmer.

### Golfer Simulation
- **Golfer** (`scripts/entities/golfer.gd`, ~61KB — most complex file): Skills (driving/accuracy/putting/recovery 0.0-1.0), personality (aggression/patience), 5 clubs (DRIVER/FAIRWAY_WOOD/IRON/WEDGE/PUTTER) with range/accuracy data. Shot calculation, target evaluation, tree collision, hazard avoidance. Group play (1-4 per group, "away" rule, double-par pickup).
- **GolferManager**: Spawns groups based on green fee, max 8 concurrent golfers, spawn rate modified by course rating and weather. 4 tiers: BEGINNER/CASUAL/SERIOUS/PRO.
- **Ball**: Parabolic flight animation, terrain-based rolling distances, wind visual offset. Signals: `ball_landed`, `ball_state_changed`.

#### Shot Accuracy — Angular Dispersion Model
Shot error uses an **angular dispersion** model rather than absolute tile offsets. The shot direction is rotated by a miss angle sampled from a **gaussian (bell curve) distribution**, so most shots land near the target line with occasional big hooks/slices in the tails. Key properties:

- **`miss_tendency`** (per-golfer, -1.0 to +1.0): Persistent hook/slice bias. Negative = hook, positive = slice. Amplitude set by tier (beginners: 0.4–0.8, pros: 0.0–0.15). Generated in `GolferTier.generate_skills()`.
- **Angular spread**: `max_spread_deg = (1.0 - total_accuracy) * 12.0`, with `spread_std_dev = max_spread / 2.5`. ~95% of shots land within `max_spread_deg` of target line.
- **Tendency bias**: `miss_tendency * (1.0 - total_accuracy) * 6.0` degrees added to every shot — lower-skill golfers can't compensate for their natural shot shape.
- **Shanks**: Rare catastrophic miss (35–55° off-line, 30–60% distance). Probability: `(1.0 - total_accuracy) * 6%`. Only on full swings (not putts/wedges). Direction follows `miss_tendency` sign.
- **Distance loss**: Topped/fat shots use gaussian distribution: `abs(gaussian) * (1.0 - accuracy) * 12%` max distance loss. Most shots near full distance.
- **Gaussian helper** (`_gaussian_random()`): Central Limit Theorem approximation using sum of 4 `randf()` calls. Mean ~0, std dev ~1, range ~±3.5.
- **Accuracy factors**: `total_accuracy = club_accuracy_modifier * skill_accuracy * lie_modifier`, with floors for wedges (0.80–0.96) and putts (skill-scaled). Club modifiers: Driver 0.70, FW 0.78, Iron 0.85, Wedge 0.95, Putter 0.98.

### Economy
- Green fee configurable $10-$200. Bankruptcy threshold at -$1000.
- Buildings: 8 types (Clubhouse, Pro Shop, Restaurant, Snack Bar, Driving Range, Cart Shed, Restroom, Bench). Proximity-based revenue. Clubhouse has 3 upgrade tiers.
- CourseRatingSystem: 4-star rating from Condition (30%), Design (20%), Value (30%), Pace (20%).

### Weather & Time
- **WindSystem**: Per-day random direction/speed (0-30 mph), hourly drift. Club-specific sensitivity (Driver 1.0x, Putter 0.0x). Crosswind displacement and distance modifiers.
- **WeatherSystem**: 6 types (SUNNY → HEAVY_RAIN). Affects spawn rate (100% → 30%), accuracy (95-100%), sky tint.
- **DayNightSystem**: 6 AM - 8 PM course hours. Visual dimming. 1 real minute = 1 game hour at normal speed.
- **TournamentSystem**: 4 tiers (Local/Regional/National/Championship) with escalating hole/rating/difficulty requirements and prize pools.

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

- **SelectorDialog utility** (`scripts/ui/selector_dialog.gd`): Reusable `RefCounted` class for popup selection menus (trees, rocks, buildings). Handles AcceptDialog creation, hotkey toggle, and cleanup in one place. Usage:
  ```gdscript
  # Declare once (e.g., in _ready):
  var _tree_selector = SelectorDialog.new(self, KEY_T)

  # Show with items — pressing T again closes (toggle behavior):
  var items = [{"id": "oak", "label": "Oak Tree ($20)"}, ...]
  _tree_selector.show_items("Select Tree", items, _on_tree_selected)

  # Items support {"id": String, "label": String, "disabled": bool}
  ```
  Each instance manages one dialog's lifecycle. Modal behavior and hotkey interception are handled internally.

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

- No audio system yet. No full A* pathfinding (heuristic-based). No career mode. No course sharing. No tutorial.
- Golfers are NOT saved/loaded (respawn naturally to avoid complex mid-action state serialization).
- Save format is versioned (SAVE_VERSION = 2) for forward compatibility.
