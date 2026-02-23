# Decorations System

## Overview

The Decorations system adds 16 placeable decorative items across 5 categories: water features, garden items, lighting, structures, and boundaries. Each decoration provides a satisfaction bonus to golfers within a configurable radius, encouraging players to beautify their course. Different course themes unlock different decoration subsets.

## Decoration Categories

### Water Features
| Item | Cost | Satisfaction | Radius |
|------|------|-------------|--------|
| Fountain | $500 | +0.08 | 5 tiles |
| Bird Bath | $150 | +0.03 | 3 tiles |

### Garden
| Item | Cost | Satisfaction | Radius |
|------|------|-------------|--------|
| Flower Planter | $100 | +0.03 | 3 tiles |
| Topiary | $250 | +0.05 | 4 tiles |

### Lighting
| Item | Cost | Satisfaction | Radius |
|------|------|-------------|--------|
| Stone Lantern | $200 | +0.04 | 4 tiles |
| Path Light | $120 | +0.02 | 3 tiles |

### Structures
| Item | Cost | Satisfaction | Radius |
|------|------|-------------|--------|
| Sundial | $300 | +0.05 | 4 tiles |
| Statue | $800 | +0.10 | 6 tiles |
| Flag Banner | $80 | +0.02 | 3 tiles |
| Course Sign | $200 | +0.03 | 4 tiles |

### Boundaries
| Item | Cost | Satisfaction | Radius |
|------|------|-------------|--------|
| Picket Fence | $60 | +0.01 | 2 tiles |
| Stone Wall | $100 | +0.02 | 2 tiles |
| Hedge | $80 | +0.02 | 2 tiles |

### Theme-Specific
| Item | Cost | Satisfaction | Radius | Themes |
|------|------|-------------|--------|--------|
| Tiki Torch | $150 | +0.04 | 3 tiles | Desert, Resort |
| Wind Chime | $120 | +0.03 | 3 tiles | Parkland, Mountain, Resort |
| Cactus Garden | $180 | +0.04 | 3 tiles | Desert |

## Satisfaction Bonus Calculation

Each decoration provides a satisfaction bonus to golfers within its effect radius, with linear distance falloff:

```
bonus = satisfaction_bonus * (1.0 - distance / (effect_radius + 1))
```

Multiple decorations stack additively. The `EntityLayer.get_decoration_satisfaction_bonus(grid_pos)` method sums all nearby decoration bonuses for a given position.

## Theme Availability

Each course theme has a set of universal decorations (10 items) plus 2-3 theme-specific items:

| Theme | Unique Items |
|-------|-------------|
| Parkland | Topiary, Hedge, Wind Chime |
| Desert | Cactus Garden, Tiki Torch |
| Links | Stone Lantern, Hedge |
| Mountain | Stone Lantern, Hedge, Wind Chime |
| City | Topiary, Hedge |
| Resort | Tiki Torch, Topiary, Wind Chime |

## Placement Rules

- Single-tile placement (same as trees/rocks)
- Valid terrain: Grass, Fairway, Rough, Heavy Rough, Path
- Removed automatically when terrain is painted over with course features
- Bulldozer removal cost: $25

## Visual System

Each decoration has a procedural polygon-based visual with:
- Position-based deterministic variation (scale, rotation, hue shift)
- Shadow rendering via ShadowRenderer
- Y-sort ordering for proper isometric depth

## Integration Points

- **EntityLayer.place_decoration()** — place a decoration on the grid
- **EntityLayer.get_decoration_satisfaction_bonus()** — query satisfaction bonus at a position
- **PlacementManager.start_decoration_placement()** — enter decoration placement mode
- **SaveManager** — decorations persisted in entity layer serialization
- **Hotkey: D** — open decoration selection dialog

## Tuning Levers

| Parameter | Location | Effect |
|-----------|----------|--------|
| Decoration costs | `DECORATION_PROPERTIES` dict | Change purchase prices |
| Satisfaction bonuses | `DECORATION_PROPERTIES` dict | Change mood impact |
| Effect radii | `DECORATION_PROPERTIES` dict | Change area of influence |
| Theme availability | `get_theme_decorations()` | Which decorations per theme |
| Bulldozer cost | `BULLDOZER_COSTS["decoration"]` in main.gd | Removal cost |
