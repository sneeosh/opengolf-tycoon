# OpenGolf Tycoon

An open source golf course builder and management game inspired by Sid Meier's SimGolf, built with Godot 4.

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Godot](https://img.shields.io/badge/Godot-4.6+-blue.svg)
![Status](https://img.shields.io/badge/status-alpha-orange.svg)
![Version](https://img.shields.io/badge/version-0.1.0-green.svg)

## About

OpenGolf Tycoon is a spiritual successor to the classic SimGolf (2002). Design and build your own golf courses, manage your country club, attract golfers, and compete to create the ultimate golfing destination.

## Current Features

### Course Themes

Choose from 10 distinct course environments, each with unique terrain colors, gameplay modifiers, and visual style:

- **Parkland** — Classic lush green grass, deciduous trees, balanced gameplay
- **Desert** — Sandy tan terrain, oasis-green fairways, cacti and rocky outcroppings
- **Links** — Coastal Scottish-style with golden-brown fescue, strong persistent wind (+20%)
- **Mountain** — Deep alpine greens, pine forests, +5% shot distance (thinner air)
- **City/Municipal** — Muted urban greens, lower maintenance costs
- **Resort** — Vibrant tropical colors, turquoise water, white sand bunkers, premium pricing
- **Heathland** — Sandy inland soil with heather, gorse, and scattered pines
- **Woodland** — Dense tree-lined fairways with dappled light
- **Tropical** — Lush palms, vibrant greens, warm tones
- **Marshland** — Wetland terrain with cattails, soft ground, and water features

Theme selection happens on the main menu before starting a new game. Themes affect terrain colors, water/grass overlay rendering, gameplay modifiers (wind strength, shot distance, maintenance costs, green fee baseline), and available vegetation types.

### Course Designer

- **Terrain painting** — 14 terrain types: fairway, rough, heavy rough, green, tee box, bunker, water, path, out of bounds, trees, flower beds, rocks, and more
- **Elevation system** — Raise/lower individual tiles (-5 to +5), with slope affecting shots and ball roll; gradient hillshade visualization with contour lines
- **Hole creation** — 3-step flow (tee box → green → flag); auto-calculates par based on yardage; holes numbered and renameable
- **Object placement** — Theme-specific vegetation (oaks, pines, palms, cacti, fescue, heather, and more), 3 rock sizes, decorative flower beds
- **Building placement** — 8 building types (Clubhouse, Pro Shop, Restaurant, Snack Bar, Driving Range, Cart Shed, Restroom, Bench) with proximity-based revenue/satisfaction effects and placement validation
- **Undo/redo** — 50-action stack covering terrain changes and entity placement, with cost refunds on undo
- **OB markers** — Automatic white-stake placement at out-of-bounds boundaries

### Golfer Simulation

- **AI golfers** — Skill-tiered (Beginner / Casual / Serious / Pro) with animated walking and swing cycles
- **Shot AI** — Structured decision pipeline with multi-shot planning, wind compensation, recovery mode, and Monte Carlo risk analysis
- **Shot physics** — Angular dispersion model with gaussian miss distribution, persistent hook/slice tendencies per golfer, rare shank events, and club-specific accuracy
- **Ball physics** — 5-state machine (AT_REST, IN_FLIGHT, ROLLING, IN_WATER, OUT_OF_BOUNDS) with parabolic arc trajectories and terrain-based rollout
- **Golfer needs** — Energy, comfort, hunger, and pace needs that decay over time; buildings restore specific needs; low needs trigger mood penalties and thought bubbles
- **Pathfinding** — Terrain-aware, prefers cart paths, avoids water/OB, deadlock-safe group spacing
- **Group play** — Groups of 1–4; turn order follows "away" rule; par-3 hold until preceding group clears; double-par pickup prevents infinite loops
- **Hazard rules** — Water penalty (1 stroke + lateral drop), OB (stroke + distance)
- **Personality traits** — Aggression (0.0–1.0) affects risk/reward club selection and target choice
- **Green reading** — Putts account for slope break with skill-based accuracy
- **Score tracking** — Per-hole scores, running total, displayed on course

### Economy & Management

- **Green fees** — Configurable ($10–$200); fee level affects group-size distribution (low fee → singles, high fee → foursomes)
- **Building revenue** — Proximity-based income per golfer (Pro Shop, Restaurant, Snack Bar, Clubhouse bonuses)
- **Clubhouse upgrades** — 3 tiers (Basic → Pro Shop → Full Service), each unlocking higher revenue and satisfaction bonuses
- **Terrain costs** — Placement and per-day maintenance costs vary by terrain type
- **Operating costs** — Base daily cost scales with hole count and staff
- **Budget tracking** — Real-time balance, deductions on placement, refunds on undo, daily cost settlement
- **Difficulty presets** — Easy, Normal, and Hard modes with different starting conditions

### Ratings & Satisfaction

- **Course rating** — 1–5 stars computed from four sub-ratings: Condition, Design, Value, and Pace
- **Golfer feedback** — 17 trigger types (hole-in-one, birdie, bogey, bunker, water, pricing, needs, and more); thought bubbles with sentiment-coded colors
- **Reputation** — Gains/losses daily based on aggregate golfer satisfaction
- **Milestones** — Trackable objectives (star ratings, tournament hosting, revenue goals, and more)
- **Course records** — Lowest round, hole-in-one counter, best score per hole; gold particle burst celebration

### Weather & Time

- **Day/night cycle** — Visual tinting from 6 AM to 8 PM course hours; golfers finish current hole and exit at closing
- **Weather system** — 6 states (sunny → heavy rain); modifies golfer spawn rates and accuracy; animated rain overlay with sky tinting
- **Wind system** — Per-day direction and speed (0–30 mph); affects all clubs except putters; AI compensates based on skill level; HUD compass indicator with color-coded speed
- **Seasons** — Seasonal calendar affecting weather patterns, golfer traffic, and maintenance costs

### Tournaments

- **4 tiers** — Local, Regional, National, Championship — each with minimum hole count, star rating, difficulty, and yardage requirements
- **Scheduling** — 3-day lead time, 7-day cooldown between events
- **Results** — Generated winner names and scores; prize money awarded; leaderboard display

### Audio

- **Procedural sound** — Synthesized swing, impact, and UI sounds generated at runtime (no audio files needed)
- **Ambient audio** — Wind, birdsong, and rain audio that responds to weather conditions
- **Volume controls** — Master, SFX, and ambient volume sliders with mute toggle

### UI & Controls

- **Isometric camera** — Arrow-key pan (W/A/S/D in screen direction), mouse-wheel zoom, Q to rotate
- **Main menu** — New Game (with theme selection and course naming), Load Game, Settings, Quit
- **Pause menu** — Escape key opens pause overlay with Resume, Settings, Save, and Quit options
- **Settings menu** — Display, audio, and gameplay options
- **Tool palette** — Terrain tools, object placement, hole creation, elevation tools
- **Speed controls** — Play / Pause / Fast / Ultra with keyboard shortcuts
- **Mini-map** — Course overview with terrain colors, hole markers, buildings, golfers; click to navigate (toggle with M)
- **Financial dashboard** — Click money display to open; shows daily and yesterday income/expense breakdown
- **Hole stats panel** — Per-hole averages, best scores, score distributions
- **Building info panel** — Stats, upgrade options, costs
- **End-of-day summary** — Daily revenue, costs, golfer feedback summary, day transition
- **Tournament panel** — Schedule tournaments, view requirements and results (toggle with T)
- **Milestones panel** — Track course objectives and achievements
- **Hotkey reference** — F1 opens keyboard shortcut panel
- **Save/load panel** — Named save slots with save/load UI
- **Colorblind mode** — Alternative color palette for accessibility

### Save / Load

Saved state includes: terrain tiles, elevation, entity positions, hole configurations, economy state (money, reputation, green fee), day/hour, wind, weather, seasons, course theme, and course records. Auto-saves at day end (with indicator); manual save with named slots. Quit to Menu option available from pause menu.

---

## Getting Started

### Prerequisites

- [Godot Engine 4.6+](https://godotengine.org/download) (standard version, not .NET)

### Installation

No build steps or setup scripts required — all assets are procedurally generated at runtime.

1. Clone the repository:
   ```bash
   git clone https://github.com/sneeosh/simgolf-godot.git
   ```
2. Open Godot Engine
3. Click **Import** and navigate to `project.godot`
4. Click **Import & Edit**
5. Press **F5** to run

Godot will automatically import all assets on first load.

---

## Project Structure

```
simgolf-godot/
├── assets/
│   └── tilesets/           # Terrain tileset image and .tres resource
├── data/
│   ├── buildings.json      # Building types, costs, revenue, upgrade tiers
│   ├── terrain_types.json  # Terrain type definitions and properties
│   └── golfer_traits.json  # Golfer archetypes, spawn weights, skill ranges
├── docs/
│   └── algorithms/         # Detailed algorithm documentation with tuning levers
├── scenes/
│   ├── main/main.tscn      # Primary game scene
│   └── entities/golfer.tscn
├── scripts/
│   ├── autoload/           # Singletons: GameManager, EventBus, SaveManager,
│   │                       #   FeedbackManager, SoundManager, ShadowSystem
│   ├── course/             # HoleVisualizer, DifficultyCalculator, EntityLayer
│   ├── effects/            # RainOverlay, HoleInOneCelebration, SandSprayEffect
│   ├── entities/           # Golfer, Ball, Building, Tree, Rock, Flag
│   ├── managers/           # GolferManager, BallManager, HoleManager, PlacementManager,
│   │                       #   BuildingRegistry, TournamentManager
│   ├── systems/            # WindSystem, WeatherSystem, DayNightSystem, CourseRatingSystem,
│   │                       #   CourseTheme, ShotAI, GolferNeeds, SeasonSystem,
│   │                       #   MilestoneSystem, TutorialSystem, and more
│   ├── terrain/            # TerrainGrid, TerrainTypes, TilesetGenerator, overlays
│   ├── tools/              # HoleCreationTool, ElevationTool, UndoManager
│   ├── ui/                 # 39 UI components: MainMenu, PauseMenu, SettingsMenu,
│   │                       #   MiniMap, FinancialPanel, MilestonesPanel, and more
│   └── utils/              # IsometricCamera
├── tests/
│   └── unit/               # GUT framework unit tests
└── project.godot
```

---

## Documentation

- **[Algorithm docs](docs/algorithms/)** — Detailed documentation for all simulation algorithms with plain-English explanations, formulas, and tuning levers. See the [algorithm index](docs/algorithms/README.md).
- **[Development milestones](DEVELOPMENT_MILESTONES.md)** — Full development history and roadmap
- **[Game critique](GAME_CRITIQUE.md)** — Honest critical analysis of the game's strengths and weaknesses
- **[Beta readiness analysis](BETA_READINESS.md)** — Gap analysis for reaching public beta
- **[Launch evaluation](LAUNCH_EVALUATION.md)** — Current state assessment and ratings
- **[Tycoon genre review](docs/tycoon-genre-review.md)** — Feature comparison against genre staples

---

## Planned / Not Yet Implemented

- **Animated tiles** — Waving flags, animated water
- **Bridges** — Path over water hazards
- **Simulated tournaments** — AI golfers playing real rounds instead of generated results
- **Spectator tools** — Follow a golfer with the camera, live scorecards, shot replays
- **Player-controlled golfer mode** — Play your own course as a golfer
- **Performance optimization** — Object pooling, occlusion for large courses
- **Career mode** — Progression, unlockables, achievements
- **Course sharing** — Export/import course layouts
- **Seasonal visuals** — Spring/summer/fall/winter terrain appearance changes

---

## Testing

Unit tests use the [GUT](https://github.com/bitwes/Gut) (Godot Unit Test) framework. Tests are in `tests/unit/`.

```bash
make test          # Using Makefile
./test.sh          # Using shell script
```

---

## Contributing

Contributions welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Areas Needing Help

- **Art** — Isometric sprites for terrain, buildings, golfers; animated tiles
- **Audio** — Composed music tracks, improved sound design
- **Code** — Simulated tournaments, spectator camera, performance optimization
- **Documentation** — Wiki pages, gameplay guides

---

## License

MIT License — see [LICENSE](LICENSE) for details.

## Acknowledgments

- Sid Meier and Firaxis for the original SimGolf
- The Godot Engine community

---

*This is a fan project and is not affiliated with Firaxis Games.*
