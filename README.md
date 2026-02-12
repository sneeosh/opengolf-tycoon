# OpenGolf Tycoon

An open source golf course builder and management game inspired by Sid Meier's SimGolf, built with Godot 4.

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Godot](https://img.shields.io/badge/Godot-4.6+-blue.svg)
![Status](https://img.shields.io/badge/status-early%20development-orange.svg)

## About

OpenGolf Tycoon is a spiritual successor to the classic SimGolf (2002). Design and build your own golf courses, manage your country club, attract members, and compete to create the ultimate golfing destination.

### Current Features (Early Development)

✅ **Course Designer**:
- Terrain painting (fairway, rough, green, bunker, water, paths)
- Hole creation with tee boxes and greens
- Visual hole markers with flags, connecting lines, and info labels
- Par calculation based on distance (Par 3/4/5)
- Yardage tracking and display
- Tree placement (Oak, Pine, Maple, Birch)
- Decorative rocks (small, medium, large)
- Building placement system
- Budget tracking

✅ **Golfer Simulation**:
- Animated AI golfers with walking and swing animations
- Ball physics with parabolic arc trajectories
- Terrain-based ball rolling (different for greens, fairways, rough)
- Complete club system (Driver, Iron, Wedge, Putter) with realistic characteristics
- Intelligent AI: prefers fairways, avoids hazards, detects tree collisions
- Personality traits affect decision-making (aggression, patience)
- Green reading for putts
- Terrain-aware pathfinding (avoids water obstacles)
- Score tracking and display
- Visual feedback for ball states (in flight, rolling, in water, OB)
- Automatic golfer spawning in groups of 1-4 players

✅ **Game Modes & Controls**:
- Building mode for course design and construction
- Play mode for golfer simulation
- Play/Pause/Fast speed controls
- Validation system (requires at least one hole to play)
- Visual game state indicators

✅ **UI & Controls**:
- Isometric camera with pan and zoom
- Intuitive arrow key controls
- Tool palette for terrain editing
- Real-time budget and day tracking
- Game mode status display

### Planned Features

- **Advanced Golfer AI**: Complete shot types (driver, irons, wedges, putters)
- **Club Management**: Build amenities, hire staff, set prices, and grow your membership
- **Economic System**: Balance income and expenses, unlock upgrades, expand your empire
- **Weather System**: Dynamic conditions affecting gameplay
- **Tournament Mode**: Host events and attract pro golfers
- **Play Mode**: Take to the course yourself and play the holes you've designed

## Getting Started

### Prerequisites

- [Godot Engine 4.6+](https://godotengine.org/download) (standard version, not .NET)

### Installation

No build steps or setup scripts required - all assets are included in the repository.

1. Clone this repository:
   ```bash
   git clone https://github.com/sneeosh/simgolf-godot.git
   ```
2. Open Godot Engine
3. Click "Import" and navigate to the `project.godot` file
4. Click "Import & Edit"
5. Press F5 to run the game

That's it! Godot will automatically import all assets on first load.

## Project Structure

```
simgolf-godot/
├── assets/                  # Game assets
│   └── tilesets/           # Terrain tileset images
├── data/                    # Game data (JSON configs)
├── scenes/                  # Godot scenes (.tscn files)
├── scripts/                 # GDScript files
│   ├── autoload/           # Singleton managers (GameManager, EventBus, etc.)
│   ├── course/             # Course and hole management
│   ├── entities/           # Golfers, balls, buildings, trees
│   ├── managers/           # Game subsystem managers
│   ├── systems/            # Wind, day/night, course rating
│   ├── terrain/            # Terrain grid and overlays
│   ├── tools/              # Editor tools and utilities
│   ├── ui/                 # UI panels and controls
│   └── utils/              # Camera, helpers
└── project.godot
```

## Contributing

Contributions welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Areas Needing Help

- Art: Isometric sprites for terrain, buildings, golfers
- Audio: Music and sound effects
- Code: Core systems implementation
- Documentation: Tutorials, wiki pages

## License

MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgments

- Sid Meier and Firaxis for the original SimGolf
- The Godot Engine community

---

*This is a fan project and is not affiliated with Firaxis Games.*
