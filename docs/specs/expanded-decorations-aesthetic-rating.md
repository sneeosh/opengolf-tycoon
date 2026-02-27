# Expanded Decorations & Aesthetic Rating — Product Spec

**Author:** Claude (Product)
**Date:** 2026-02-27
**Status:** Proposal
**Priority:** MEDIUM
**Version:** 0.1.0-alpha context

---

## Problem Statement

The current decoration palette is limited: 11 tree varieties, 3 rock sizes, flower bed terrain tiles, and 8 functional buildings. There are no purely aesthetic objects — no fountains, statues, benches with views, signage, or ornamental gardens. More importantly, decorations have zero impact on course rating.

The `CourseRatingSystem` calculates stars from Condition (30%), Design (20%), Value (30%), and Pace (20%) with no aesthetics factor. A beautifully landscaped course scores identically to a bare one with the same holes and buildings. This removes a core tycoon motivation: making your creation look good should matter.

---

## Design Principles

- **Decorations should have gameplay purpose.** They affect the aesthetics rating, which feeds into the overall course rating.
- **Proximity matters.** Decorations near tee boxes and greens matter more than decorations in the middle of nowhere.
- **Diminishing returns prevent spam.** The first few decorations per hole area contribute the most.
- **Theme bonuses reward thematic consistency.** Desert courses get extra credit for desert-appropriate decorations.
- **Cost creates decisions.** Premium decorations are expensive to place and maintain.

---

## Current System Analysis

### Existing Decoration Entities

**Trees** (`scripts/entities/tree.gd`):
- 11 varieties: oak, pine, maple, birch, cactus, fescue, cattails, bush, palm, dead_tree, heather
- Cost: $5–$30 per tree
- Procedural Polygon2D rendering with theme-aware coloring
- Position-seeded variation (scale, rotation, hue)
- Shadow integration with ShadowSystem
- Placed via hotkey dialog (T key)

**Rocks** (`scripts/entities/rock.gd`):
- 3 sizes: small ($10), medium ($15), large ($20)
- Multi-faceted polygon with highlights
- Theme-aware base color, moss on appropriate themes
- Placed via hotkey dialog (R key)

**Flower Bed**: Terrain tile type (FLOWER_BED = 12), not an entity. Painted with terrain tools.

### Course Rating System
```
Overall = Condition(30%) + Design(20%) + Value(30%) + Pace(20%)
```
No aesthetics component exists.

---

## Feature Design

### 1. New Decoration Categories

Organize decorations into 5 categories with distinct gameplay and visual roles:

**Category A: Landscaping**
| Decoration | Size | Cost | Daily Upkeep | Aesthetics Value |
|-----------|------|------|-------------|-----------------|
| Flower Garden | 2×2 tiles | $150 | $5 | High |
| Hedge Row | 1×3 tiles | $100 | $3 | Medium |
| Ornamental Grass | 1×1 tile | $40 | $1 | Low |
| Topiary | 1×1 tile | $200 | $8 | High |
| Planter Box | 1×1 tile | $60 | $2 | Medium |

**Category B: Water Features**
| Decoration | Size | Cost | Daily Upkeep | Aesthetics Value |
|-----------|------|------|-------------|-----------------|
| Fountain | 2×2 tiles | $500 | $15 | Very High |
| Decorative Pond | 3×3 tiles | $350 | $10 | High |
| Bird Bath | 1×1 tile | $75 | $2 | Medium |
| Waterfall | 2×2 tiles | $800 | $20 | Very High |

**Category C: Structures**
| Decoration | Size | Cost | Daily Upkeep | Aesthetics Value |
|-----------|------|------|-------------|-----------------|
| Gazebo | 2×2 tiles | $300 | $5 | High |
| Bridge (decorative) | 1×3 tiles | $250 | $3 | Medium |
| Course Signage | 1×1 tile | $50 | $0 | Low |
| Tee Marker | 1×1 tile | $30 | $0 | Low |
| Yardage Marker | 1×1 tile | $20 | $0 | Low |
| Ball Washer | 1×1 tile | $25 | $1 | Low |
| Pergola | 2×3 tiles | $400 | $8 | High |

**Category D: Furniture**
| Decoration | Size | Cost | Daily Upkeep | Aesthetics Value |
|-----------|------|------|-------------|-----------------|
| Park Bench (scenic) | 1×1 tile | $80 | $0 | Medium |
| Picnic Area | 2×2 tiles | $200 | $3 | Medium |
| Waste Bin | 1×1 tile | $15 | $0 | Low |

**Category E: Sculptures (Prestige)**
| Decoration | Size | Cost | Daily Upkeep | Aesthetics Value | Unlock |
|-----------|------|------|-------------|-----------------|--------|
| Golfer Statue | 1×1 tile | $1,000 | $5 | Very High | 4-star rating |
| Sundial | 1×1 tile | $500 | $0 | High | 50 reputation |
| Course Logo Stone | 2×1 tiles | $750 | $0 | High | 9 holes built |
| Trophy Display | 1×1 tile | $2,000 | $10 | Very High | Championship hosted |

---

### 2. Aesthetics Rating Component

Add aesthetics as a factor in the course rating system.

**Revised course rating formula:**
```
Overall = Condition(25%) + Design(15%) + Value(30%) + Pace(20%) + Aesthetics(10%)
```

Design weight reduced from 20% to 15%. Condition reduced from 30% to 25%. Aesthetics takes the freed 10%.

**Aesthetics rating calculation (1–5 scale):**

```gdscript
static func calculate_aesthetics_rating(course_data: CourseData) -> float:
    var total_score = 0.0
    var max_possible = 0.0

    for hole in course_data.get_open_holes():
        var hole_score = _calculate_hole_aesthetics(hole, course_data)
        total_score += hole_score
        max_possible += 5.0

    if max_possible == 0:
        return 1.0

    return clamp(total_score / max_possible * 5.0, 1.0, 5.0)
```

**Per-hole aesthetics scoring:**
```
1. Count decorations within 8 tiles of tee box → tee_area_score
2. Count decorations within 8 tiles of green → green_area_score
3. Count decorations within the fairway corridor → corridor_score
4. Apply variety bonus (different decoration types)
5. Apply theme bonus (theme-appropriate decorations)
6. Apply diminishing returns curve
```

**Scoring detail:**

```gdscript
static func _calculate_hole_aesthetics(hole, course_data) -> float:
    var score = 0.0

    # Tee area decorations (8-tile radius from tee)
    var tee_decor = count_decorations_near(hole.tee_position, 8)
    score += min(tee_decor.total_value, 2.0)  # Cap at 2.0 points

    # Green area decorations (8-tile radius from green center)
    var green_decor = count_decorations_near(hole.hole_position, 8)
    score += min(green_decor.total_value, 2.0)  # Cap at 2.0 points

    # Variety bonus: different types of decorations near this hole
    var unique_types = tee_decor.unique_types + green_decor.unique_types
    if unique_types >= 4: score += 0.5
    elif unique_types >= 2: score += 0.25

    # Theme bonus: theme-appropriate decorations
    score += calculate_theme_bonus(tee_decor, green_decor, theme)

    return clamp(score, 0.0, 5.0)
```

**Decoration value mapping:**
| Aesthetics Value | Score Contribution |
|-----------------|-------------------|
| Low | 0.1 per decoration |
| Medium | 0.25 per decoration |
| High | 0.5 per decoration |
| Very High | 1.0 per decoration |

**Diminishing returns:** Each decoration's contribution is multiplied by `1.0 / (1.0 + 0.2 * count_same_type_nearby)`. The 6th fountain near the same hole contributes 50% of the first.

---

### 3. Theme-Appropriate Bonuses

Each theme has decorations that earn a 1.5× bonus:

| Theme | Bonus Decorations |
|-------|-------------------|
| PARKLAND | Oak trees, flower gardens, park benches, gazebos |
| DESERT | Cactus, rocks, sundial, ornamental grass |
| LINKS | Fescue, heather, course signage, yardage markers |
| MOUNTAIN | Pine trees, rocks, bridges, pergolas |
| CITY | Topiary, fountains, sculptures, planter boxes |
| RESORT | Palm trees, decorative ponds, gazebos, picnic areas |
| HEATHLAND | Heather, bush, rocks, course signage |
| WOODLAND | Birch, maple, oak, bridges, bird baths |
| TROPICAL | Palm, cattails, fountains, flower gardens |
| MARSHLAND | Cattails, fescue, bridges, bird baths |

A Links course with fescue grass, heather, and yardage markers earns more aesthetics points than the same decorations on a City course.

---

### 4. Decoration Placement Rules

**Placement constraints:**
- Decorations cannot overlap other decorations, buildings, or hole elements (tee/green/flag)
- Decorations can be placed on GRASS, ROUGH, FAIRWAY, or PATH terrain
- Water features (fountain, pond, bird bath) can be placed adjacent to WATER terrain
- Waterfall requires adjacent elevation change (≥2 elevation delta between adjacent tiles)
- Bridge requires adjacent WATER or PATH tiles on both ends

**Placement UI:**
- New "Decorations" hotkey: `D` key opens decoration dialog
- Dialog organized by category tabs (Landscaping / Water / Structures / Furniture / Sculptures)
- Locked decorations show requirements (grayed out with tooltip)
- Preview ghost shows placement before confirming
- Multi-place mode: hold Shift to place multiple of the same decoration without reopening dialog

---

### 5. Decoration Maintenance

Decorations with daily upkeep contribute to operating costs:

```gdscript
# In DailyStatistics.calculate_operating_costs():
var decoration_upkeep = sum of all placed decoration daily costs
operating_costs += decoration_upkeep
```

**Condition interaction:** If course condition drops below 0.5 (Fair), decoration aesthetics contribution is halved. Poorly maintained courses don't get credit for decorations. This creates a natural coupling: hiring groundskeepers benefits both condition rating and aesthetics rating.

---

### 6. Unlock Progression

Premium decorations gate behind progression milestones:

| Decoration | Unlock Requirement |
|-----------|-------------------|
| All landscaping | Available from start |
| All furniture | Available from start |
| Fountain | 3-star rating |
| Decorative Pond | Available from start |
| Bird Bath | Available from start |
| Waterfall | 4-star rating + adjacent elevation |
| Gazebo | 2-star rating |
| Bridge | 2-star rating |
| Pergola | 3-star rating |
| Course signage, markers, ball washer | Available from start |
| Golfer Statue | 4-star rating |
| Sundial | 50 reputation |
| Course Logo Stone | 9 holes built |
| Trophy Display | Championship tournament hosted |

---

## Data Model Changes

### Decoration entity (new base class):
```gdscript
# scripts/entities/decoration.gd
class_name Decoration extends Node2D

var decoration_type: String          # "fountain", "flower_garden", etc.
var category: String                 # "landscaping", "water", etc.
var grid_position: Vector2i
var size: Vector2i                   # Tile footprint
var cost: int
var daily_upkeep: int
var aesthetics_value: float          # 0.1, 0.25, 0.5, 1.0

func _draw() -> void:
    # Procedural rendering per decoration type
    ...
```

### Decoration data file:
```json
// data/decorations.json
{
    "flower_garden": {
        "name": "Flower Garden",
        "category": "landscaping",
        "size": [2, 2],
        "cost": 150,
        "daily_upkeep": 5,
        "aesthetics_value": 0.5,
        "placeable_terrain": ["grass", "rough"],
        "unlock": null
    },
    "fountain": {
        "name": "Fountain",
        "category": "water",
        "size": [2, 2],
        "cost": 500,
        "daily_upkeep": 15,
        "aesthetics_value": 1.0,
        "placeable_terrain": ["grass", "path"],
        "unlock": {"type": "star_rating", "value": 3}
    }
}
```

### CourseRatingSystem changes:
```gdscript
# Revised weights:
const CONDITION_WEIGHT: float = 0.25   # Was 0.30
const DESIGN_WEIGHT: float = 0.15      # Was 0.20
const VALUE_WEIGHT: float = 0.30       # Unchanged
const PACE_WEIGHT: float = 0.20        # Unchanged
const AESTHETICS_WEIGHT: float = 0.10  # New

func calculate_rating() -> Dictionary:
    # ... existing calculation ...
    var aesthetics = _calculate_aesthetics_rating()
    overall = condition * CONDITION_WEIGHT + design * DESIGN_WEIGHT + \
              value * VALUE_WEIGHT + pace * PACE_WEIGHT + \
              aesthetics * AESTHETICS_WEIGHT
```

### Save/Load:
```gdscript
# Decorations serialized like buildings:
{
    "decorations": [
        {"type": "fountain", "position": [45, 23]},
        {"type": "flower_garden", "position": [12, 67]},
        ...
    ]
}
```

---

## Implementation Sequence

```
Phase 1 (Foundation):
  1. Decoration base class with procedural rendering
  2. data/decorations.json with all decoration definitions
  3. Decoration placement system (reuse building placement patterns)
  4. Decoration hotkey dialog (D key, categorized tabs)

Phase 2 (Aesthetics Rating):
  5. Aesthetics rating calculation
  6. Revise CourseRatingSystem weights (Condition 25%, Design 15%, Aesthetics 10%)
  7. Per-hole aesthetics scoring with proximity zones
  8. Theme-appropriate bonus multipliers
  9. Diminishing returns curve

Phase 3 (Decorations):
  10. Landscaping decorations (flower garden, hedge, grass, topiary, planter)
  11. Water features (fountain, pond, bird bath, waterfall)
  12. Structures (gazebo, bridge, signage, markers, ball washer, pergola)
  13. Furniture (scenic bench, picnic area, waste bin)

Phase 4 (Prestige & Polish):
  14. Sculpture decorations with unlock gates
  15. Decoration maintenance cost integration
  16. Condition × aesthetics coupling
  17. Multi-place mode (Shift to repeat)
  18. Save/load integration

Phase 5 (Algorithm Doc):
  19. Create docs/algorithms/aesthetics-rating.md
  20. Update docs/algorithms/course-rating.md with new weights
```

---

## Success Criteria

- Course rating changes when decorations are placed near holes
- Theme-appropriate decorations earn visibly more aesthetics points
- Diminishing returns prevent "spam 50 fountains" from maxing the rating
- Decoration placement is intuitive (same patterns as building placement)
- Premium decorations (sculptures) feel like earned prestige items
- Aesthetics rating provides clear feedback: bare courses score 1 star, well-landscaped courses score 4–5 stars
- Overall course rating shifts by 0.3–0.5 stars between bare and well-decorated courses (10% weight impact)
- Decoration upkeep is visible in daily operating costs

---

## Out of Scope

| Feature | Reason |
|---------|--------|
| Animated decorations (spinning windmill, flowing fountain) | Performance cost; procedural rendering limitation |
| Seasonal decoration changes (fall flowers, winter bare branches) | Depends on Visual Polish spec |
| Player-created decoration presets | UI complexity |
| Decoration "sets" / themed packs | Simple individual placement is sufficient |
| Golfer interaction with decorations (sitting on bench) | Requires new golfer states |
| Decoration tool (drag-to-resize hedge rows) | Individual placement is simpler |
