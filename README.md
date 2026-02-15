# OpenGolf Tycoon

An open source golf course builder and management game inspired by Sid Meier's SimGolf, built with Godot 4.

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Godot](https://img.shields.io/badge/Godot-4.6+-blue.svg)
![Status](https://img.shields.io/badge/status-alpha-orange.svg)
![Version](https://img.shields.io/badge/version-0.1.0-green.svg)

## About

OpenGolf Tycoon is a spiritual successor to the classic SimGolf (2002). Design and build your own golf courses, manage your country club, attract members, and compete to create the ultimate golfing destination.

## Current Features

### Course Themes

Choose from 6 distinct course environments, each with unique terrain colors, gameplay modifiers, and visual style:

- **Parkland** — Classic lush green grass, deciduous trees, balanced gameplay
- **Desert** — Sandy tan terrain, oasis-green fairways, cacti and rocky outcroppings
- **Links** — Coastal Scottish-style with golden-brown fescue, strong persistent wind (+20%)
- **Mountain** — Deep alpine greens, pine forests, +5% shot distance (thinner air)
- **City/Municipal** — Muted urban greens, lower maintenance costs
- **Resort** — Vibrant tropical colors, turquoise water, white sand bunkers, premium pricing

Theme selection happens on the main menu before starting a new game. Themes affect terrain colors, water/grass overlay rendering, and gameplay modifiers (wind strength, shot distance, maintenance costs, green fee baseline).

### Course Designer

- **Terrain painting** — 11 terrain types: fairway, rough, green, tee box, bunker, water, path, trees, and more
- **Elevation system** — raise/lower individual tiles (-5 to +5), with slope affecting shots and ball roll
- **Hole creation** — 3-step flow (tee box → green → flag); auto-calculates par based on yardage; holes numbered and renameable
- **Object placement** — 4 tree varieties (Oak, Pine, Maple, Birch), 3 rock sizes, decorative flower beds
- **Building placement** — 8 building types with proximity-based revenue/satisfaction effects and placement validation
- **Undo/redo** — 50-action stack covering terrain changes and entity placement, with cost refunds on undo
- **OB markers** — automatic white-stake placement at out-of-bounds boundaries

### Golfer Simulation

- **AI golfers** — skill-tiered (Beginner / Casual / Serious / Pro) with animated walking and swing cycles
- **Shot system** — full club set (Driver, Fairway Wood, Iron, Wedge, Putter) with realistic distance ranges and accuracy curves
- **Shot modifiers** — lie penalties (rough -25%, bunker -40–60%, trees -70%), elevation effects (±3%/unit), wind displacement (club-weighted), terrain roll distances
- **Ball physics** — 5-state machine (AT_REST, IN_FLIGHT, ROLLING, IN_WATER, OUT_OF_BOUNDS) with parabolic arc trajectories
- **Pathfinding** — terrain-aware, prefers cart paths, avoids water/OB, deadlock-safe group spacing
- **Group play** — groups of 1–4; turn order follows "away" rule; par-3 hold until preceding group clears; double-par pickup prevents infinite loops
- **Hazard rules** — water penalty (1 stroke + lateral drop), OB (stroke + distance)
- **Personality traits** — aggression (0.0–1.0) affects risk/reward club selection and target choice
- **Green reading** — putts aim past the hole accounting for slope break
- **Score tracking** — per-hole scores, running total, displayed on course

### Economy & Management

- **Green fees** — configurable; fee level affects group-size distribution (low fee → singles, high fee → foursomes)
- **Building revenue** — proximity-based income per golfer (Pro Shop $15, Restaurant $25, Snack Bar $5, Clubhouse bonuses)
- **Clubhouse upgrades** — 3 tiers (Basic → Pro Shop → Full Service), each unlocking higher revenue and satisfaction bonuses
- **Terrain costs** — placement and per-day maintenance costs vary by terrain type
- **Operating costs** — base daily cost scales with hole count and staff
- **Budget tracking** — real-time balance, deductions on placement, refunds on undo, daily cost settlement

### Ratings & Satisfaction

- **Course rating** — 1–5 stars computed from four sub-ratings: Condition, Design, Value, and Pace
- **Golfer feedback** — 12+ trigger types (hole-in-one, birdie, bogey, bunker, water, pricing reactions); thought bubbles with sentiment-coded colors
- **Reputation** — gains/losses daily based on aggregate golfer satisfaction
- **Mood states** — Ecstatic, Happy, Content, Annoyed, Angry
- **Course records** — lowest round, hole-in-one counter, best score per hole; gold particle burst celebration

### Weather & Time

- **Day/night cycle** — visual dimming from 6 AM to 8 PM course hours; golfers finish current hole and exit at closing
- **Weather system** — 6 states (sunny → heavy rain); modifies golfer spawn rates 30–100%; animated rain overlay with sky tinting
- **Wind system** — per-day direction and speed (0–30 mph); affects all clubs except putters; AI compensates based on skill level; HUD compass indicator with color-coded speed

### Tournaments

- **4 tiers** — Local, Regional, National, Championship — each with minimum hole count, star rating, difficulty, and yardage requirements
- **Scheduling** — 3-day lead time, 7-day cooldown between events
- **Results** — generated winner names and scores; prize money awarded

### UI & Controls

- **Isometric camera** — arrow-key pan (W/A/S/D in screen direction), mouse-wheel zoom, Q to rotate
- **Tool palette** — terrain tools, object placement, hole creation (right panel)
- **Speed controls** — Play / Pause / Fast-forward with visual game-state indicator
- **Mini-map** — course overview with terrain colors, hole markers, buildings, golfers; click to navigate (toggle with M)
- **Financial dashboard** — click money display to open; shows daily and yesterday income/expense breakdown
- **Hole stats panel** — per-hole averages, best scores, score distributions
- **Building info panel** — stats, upgrade options, costs
- **End-of-day summary** — daily revenue, costs, golfer feedback summary, day transition
- **Tournament panel** — schedule tournaments, view requirements and results (toggle with T)
- **Save/load panel** — named save slots with save/load UI

### Save / Load

Saved state includes: terrain tiles, elevation, entity positions, hole configurations, economy state (money, reputation, green fee), day/hour, wind, weather, course theme, and course records. Auto-saves at day end; manual save with named slots. Quit to Menu option available from save/load panel.

---

## Getting Started

### Prerequisites

- [Godot Engine 4.6+](https://godotengine.org/download) (standard version, not .NET)

### Installation

No build steps or setup scripts required — all assets are included.

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
│   ├── terrain_types.json  # Terrain type constants and properties
│   └── golfer_traits.json  # Golfer archetypes, spawn weights, skill ranges
├── scenes/
│   ├── main/main.tscn      # Primary game scene
│   └── entities/golfer.tscn
├── scripts/
│   ├── autoload/           # Singletons: GameManager, EventBus, SaveManager, FeedbackManager
│   ├── course/             # HoleVisualizer, DifficultyCalculator, EntityLayer
│   ├── effects/            # RainOverlay, HoleInOneCelebration, SandSprayEffect
│   ├── entities/           # Golfer, Ball, Building, Tree, Rock, Flag
│   ├── managers/           # GolferManager, BallManager, HoleManager, PlacementManager,
│   │                       #   BuildingRegistry, TournamentManager
│   ├── systems/            # WeatherSystem, WindSystem, DayNightSystem, CourseRatingSystem,
│   │                       #   CourseRecords, FeedbackTriggers, GolferTier, TournamentSystem
│   ├── terrain/            # TerrainGrid, TerrainTypes, TilesetGenerator, overlays (14 types)
│   ├── tools/              # HoleCreationTool, ElevationTool, UndoManager, GenerateTileset
│   ├── ui/                 # MiniMap, FinancialPanel, HoleStatsPanel, BuildingInfoPanel,
│   │                       #   EndOfDaySummary, TournamentPanel, SaveLoadPanel,
│   │                       #   WeatherIndicator, WindIndicator, ThoughtBubble, and more
│   └── utils/              # IsometricCamera
└── project.godot
```

---

## Planned / Not Yet Implemented

- **Audio** — music, sound effects, ambient sounds
- **Animated tiles** — waving flags, animated water
- **Bridges** — path over water hazards
- **Golfer needs** — thirst, hunger, fatigue affecting satisfaction
- **Advanced pathfinding** — full A* rather than current heuristic
- **Performance optimization** — object pooling, occlusion for 18+ hole courses
- **Career mode** — progression, unlockables, achievements
- **Course sharing** — export/import course layouts
- **Tutorial system** — onboarding for new players
- **Seasonal visuals** — spring/summer/fall/winter appearance changes
- **Keyboard hotkeys** — 1–9 for quick tool selection

---

## Contributing

Contributions welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Areas Needing Help

- **Art** — isometric sprites for terrain, buildings, golfers; animated tiles
- **Audio** — background music, swing SFX, ambient course sounds
- **Code** — pathfinding improvements, performance optimization, missing features above
- **Documentation** — tutorials, wiki pages

---

## License

MIT License — see [LICENSE](LICENSE) for details.

## Acknowledgments

- Sid Meier and Firaxis for the original SimGolf
- The Godot Engine community

---

*This is a fan project and is not affiliated with Firaxis Games.*
