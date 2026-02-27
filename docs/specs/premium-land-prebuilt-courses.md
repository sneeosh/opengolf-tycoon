# Premium Land & Prebuilt Courses — Product Spec

**Author:** Claude (Product)
**Date:** 2026-02-27
**Status:** Proposal
**Priority:** MEDIUM-HIGH
**Version:** 0.1.0-alpha context

---

## Problem Statement

Currently all land parcels are identical — $5,000 base with 30% escalation per purchase, 20×20 tiles each, no differentiation. The 6×6 parcel grid offers 36 potential parcels, but position on the grid carries no significance. There is no concept of premium real estate, turnkey courses, or land quality variation.

Once a player accumulates significant capital ($200K+), there is nothing aspirational to spend it on. The cost escalation means the 10th parcel costs ~$67K, which is expensive but offers the same blank 20×20 tile space as the first. Premium land and prebuilt courses create a capital sink that rewards long-term play and provides variety across playthroughs.

---

## Design Principles

- **Land is not just space.** Premium parcels come with pre-painted terrain, natural features, and design advantages that justify their cost.
- **Prebuilt courses save time, not skill.** Templates give a head start but are not optimal — the player improves them through their own design choices.
- **Progression gates feel earned.** Premium content unlocks through gameplay milestones, not just money.
- **Theme identity.** Premium land features differ by theme — a Desert "oasis parcel" is different from a Links "clifftop parcel."

---

## Current System Analysis

### LandManager (`scripts/managers/land_manager.gd`)
- 6×6 grid = 36 parcels, each 20×20 tiles
- Starting land: center 2×2 (parcels 2,2 / 2,3 / 3,2 / 3,3) = 40×40 tiles
- Adjacency-only expansion (must border an owned parcel)
- Cost: `BASE_PARCEL_COST * pow(COST_ESCALATION, total_purchased)` = $5K × 1.3^N
- `tile_to_parcel()`, `parcel_to_tile_rect()`, `is_tile_owned()` utility methods
- Serialization: owned parcels + total purchased count

### Existing Terrain Tools
- `TerrainGrid` supports batch painting (14 terrain types)
- `TilesetGenerator` handles procedural tileset with theme colors
- Elevation grid (-5 to +5) allows pre-sculpted terrain
- Trees and rocks can be pre-placed as entities

### QuickStartCourse Pattern
- `QuickStartCourse` exists for generating a starter 3-hole course on new games
- Programmatically places tee boxes, fairways, greens, flags, trees
- Template-based hole generation with simple layouts

---

## Feature Design

### 1. Land Quality Tiers

Introduce 3 quality tiers for parcels:

| Tier | Cost Multiplier | Pre-painted Terrain | Pre-placed Entities | Description |
|------|----------------|--------------------|--------------------|-------------|
| Standard | 1.0× | None (blank grass) | None | Current behavior |
| Premium | 2.5× | Natural terrain features | 3–8 trees/rocks | Scenic, design-ready |
| Elite | 5.0× | Full terrain layout | 10–20 trees/rocks + paths | Ready for holes |

**Standard parcels** (current behavior): 20×20 blank grass tiles. The player designs everything from scratch.

**Premium parcels** come with pre-painted natural features:
- Water feature (pond or stream — 8–15 WATER tiles in a natural pattern)
- Elevation variation (gentle hills, ±1–2 elevation changes)
- Mature trees (3–5 large trees, 2–3 smaller trees)
- Natural rock formations (1–2 rock clusters)
- The player adds holes and fairways around these features

**Elite parcels** come with infrastructure ready for hole design:
- All Premium features plus:
- Cart paths connecting to adjacent parcels
- Pre-painted rough/fairway areas suggesting hole corridors
- Elevation sculpted for interesting shot angles
- The player adds tee boxes, greens, and flags to complete holes

---

### 2. Theme-Specific Premium Features

Each theme generates different premium parcel features:

| Theme | Premium Feature | Elite Bonus |
|-------|----------------|-------------|
| PARKLAND | Pond with willow trees | Rolling hills, mature oak grove |
| DESERT | Oasis water feature, cacti clusters | Arroyos (dry creek beds), mesa elevation |
| LINKS | Coastal dune ridge, fescue grass | Wind-swept terrain, pot bunker areas |
| MOUNTAIN | Mountain stream, pine forest | Dramatic elevation (±3–4), rock outcrops |
| CITY | Decorative pond, manicured hedges | Paved paths, urban park layout |
| RESORT | Pool-side water feature, palm trees | Tropical garden, elevated tee platforms |
| HEATHLAND | Heather patches, gorse bushes | Rolling moorland, exposed rock |
| WOODLAND | Forest clearing, birch groves | Winding paths through trees, elevation |
| TROPICAL | Lagoon, palm clusters, cattails | Volcanic rock, waterfall (elevation + water) |
| MARSHLAND | Wetland areas, reed beds | Island green opportunity, raised paths |

**Generation approach:**
- Each theme defines a set of "feature templates" — patterns of terrain tiles, elevation changes, and entity placements
- Templates are placed with slight randomization (position jitter, rotation, scale variation)
- Features are generated deterministically from the parcel grid position as a seed (same position always generates the same features in a new game)

---

### 3. Premium Parcel Placement on Grid

Premium and elite parcels are placed at specific grid positions based on theme:

**Placement rules:**
- 4–6 Premium parcels per game (of 36 total)
- 1–2 Elite parcels per game
- Premium parcels placed at grid edges and corners (scenic positions)
- Elite parcels placed at high-value positions (theme-dependent)
- Center 2×2 starting area is always Standard
- Placement is deterministic per theme (players learn where premium parcels are)

**Example layout (Parkland theme):**
```
  0   1   2   3   4   5
0 [P] [ ] [ ] [ ] [ ] [P]
1 [ ] [ ] [ ] [ ] [ ] [ ]
2 [ ] [ ] [S] [S] [ ] [ ]
3 [ ] [ ] [S] [S] [ ] [E]
4 [ ] [ ] [ ] [ ] [ ] [ ]
5 [P] [ ] [ ] [P] [ ] [P]

S = Starting (Standard, owned)
P = Premium (unowned)
E = Elite (unowned)
[ ] = Standard (unowned)
```

**Visibility:** Premium and elite parcels are visually marked on the `LandBoundaryOverlay`:
- Premium: Gold border with subtle shimmer
- Elite: Diamond/platinum border with feature preview icons
- Hovering shows: tier name, cost, and a brief description of features

---

### 4. Prebuilt Course Packages

Purchasable templates that auto-build playable holes on owned land.

| Package | Holes | Type | Cost | Requirements |
|---------|-------|------|------|-------------|
| Starter | 3 | Par 3, Par 4, Par 3 | $25K | 3+ parcels owned |
| Executive | 9 | All par 3 | $75K | 5+ parcels, 3-star rating |
| Standard | 9 | Mixed par 3/4/5 | $100K | 6+ parcels, 3-star rating |
| Championship | 18 | Full mixed course | $200K | 10+ parcels, 4-star rating |

**Package contents:**
Each package includes:
- Complete holes with tee boxes, fairways, rough, greens, and flags
- Basic hazards (bunkers, some water)
- Connecting cart paths between holes
- Trees and landscaping around holes

**Package quality:**
- Starter: Simple, flat layouts — functional but unexciting (3–4 difficulty)
- Executive: Well-designed par 3s with variety — good for learning (4–5 difficulty)
- Standard: Professional-quality routing with strategic hazards (5–6 difficulty)
- Championship: Tournament-ready with challenging features (6–7 difficulty)

**Player modification:**
After purchase, the player can modify everything. Prebuilt courses are not locked — they're starting points. Players can:
- Move or delete any terrain, hole, or entity
- Redesign individual holes
- Add buildings and amenities
- Reshape the course layout entirely

**Placement process:**
1. Player selects package from a "Course Packages" menu
2. System validates: enough parcels, meets star rating requirement, can afford
3. Preview overlay shows where holes will be placed (semi-transparent)
4. Player confirms placement
5. Terrain, holes, and entities are generated
6. Cost deducted

---

### 5. Acquisition Requirements

Gate premium content behind progression milestones:

| Content | Gate | Rationale |
|---------|------|-----------|
| Premium parcels | Available from game start | Visible aspiration — player sees gold borders and saves money |
| Elite parcels | 50+ reputation | Earned through good play |
| Starter package | None (always available) | Helps new players get started |
| Executive package | 3-star course rating | Proven they can design quality |
| Standard package | 3-star + 9 holes completed | Mid-game investment |
| Championship package | 4-star + 50 reputation | Late-game reward |

**Locked content visibility:** Locked packages and parcels are visible in the UI with requirements shown. Players can see what they're working toward.

---

### 6. Scenario Integration

Prebuilt courses serve as starting points for future scenario/challenge mode (Career Spec):

**Scenario examples:**
- "Renovation Challenge": Start with a poorly designed prebuilt 9-hole. Renovate it into a 4-star course within 90 days.
- "Desert Oasis": Start with elite desert parcels. Build a Championship course using the natural features.
- "Budget Executive": Start with $15K and a Starter package. Grow it to 18 holes profitably.

These scenarios are future scope (Career Mode) but the prebuilt course system enables them.

---

## Data Model Changes

### LandManager additions:
```gdscript
enum ParcelTier { STANDARD, PREMIUM, ELITE }

var parcel_tiers: Dictionary = {}       # Vector2i → ParcelTier
var parcel_features: Dictionary = {}    # Vector2i → Array[FeatureTemplate]

const PREMIUM_PARCEL_LAYOUTS: Dictionary = {
    # theme → Array of {position: Vector2i, tier: ParcelTier}
    CourseTheme.Type.PARKLAND: [
        {position = Vector2i(0,0), tier = ParcelTier.PREMIUM},
        {position = Vector2i(5,0), tier = ParcelTier.PREMIUM},
        ...
    ],
    ...
}
```

### FeatureTemplate (new class):
```gdscript
class FeatureTemplate:
    var terrain_tiles: Dictionary = {}    # Vector2i offset → terrain type
    var elevation_changes: Dictionary = {} # Vector2i offset → elevation delta
    var entities: Array = []               # [{type, variety, offset}]
    var description: String = ""

    static func generate_for_theme(theme: CourseTheme.Type, tier: ParcelTier, seed: int) -> FeatureTemplate:
        # Procedurally generate features based on theme and tier
        ...
```

### PrebuiltCourse (new class):
```gdscript
class PrebuiltCourse:
    var package_type: String             # "starter", "executive", "standard", "championship"
    var holes: Array[HoleTemplate] = []
    var terrain: Dictionary = {}
    var entities: Array = []

    static func generate(package_type: String, theme: CourseTheme.Type, parcels: Array[Vector2i]) -> PrebuiltCourse:
        # Generate course layout on specified parcels
        ...
```

### Save/Load changes:
```gdscript
# Add to land manager serialization:
{
    "parcel_tiers": {
        "0,0": "premium",
        "5,3": "elite",
        ...
    },
    "parcels_unlocked": {  # Track which gated parcels are accessible
        "elite_unlocked": true,
        ...
    }
}
```

---

## Implementation Sequence

```
Phase 1 (Land Tiers):
  1. Add ParcelTier enum to LandManager
  2. Define premium/elite parcel positions per theme
  3. Apply cost multipliers for premium/elite parcels
  4. Visual indicators on LandBoundaryOverlay (gold/platinum borders)

Phase 2 (Terrain Features):
  5. FeatureTemplate system — terrain, elevation, entity placement
  6. Theme-specific feature generation
  7. Premium parcel feature generation on new game start
  8. Elite parcel feature generation

Phase 3 (Prebuilt Courses):
  9. Extend QuickStartCourse pattern into PrebuiltCourse class
  10. Starter package (3 holes)
  11. Executive package (9 par-3 holes)
  12. Standard package (9 mixed holes)
  13. Championship package (18 holes)

Phase 4 (Gating & UI):
  14. Acquisition requirement checks
  15. Course Packages purchase UI
  16. Preview overlay for package placement
  17. Locked content display with requirements
  18. Save/load integration
```

---

## Success Criteria

- Premium parcels are visually distinct on the land grid (gold border, feature preview)
- Premium parcel terrain features match the chosen theme (oasis in desert, dunes on links)
- Cost multipliers make premium/elite parcels a significant investment
- Prebuilt courses generate playable, well-designed holes
- Players can modify prebuilt courses freely after purchase
- Acquisition requirements create a natural progression arc
- Elite parcels feel rewarding — the terrain features provide a genuine design advantage
- New game generation is deterministic per theme (same premium parcel positions)

---

## Out of Scope

| Feature | Reason |
|---------|--------|
| Player-designed templates | Complexity — requires course serialization/sharing |
| Real estate market (price fluctuation) | Unnecessary economic complexity |
| Selling land parcels | One-way expansion is simpler and prevents exploits |
| Multiple maps / course locations | Single contiguous map is core design |
| Land rental / lease model | Tycoon depth without sufficient payoff |
| Procedural course generation for daily play | Prebuilt courses are purchase-once, not procedural |
