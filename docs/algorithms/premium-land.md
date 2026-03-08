# Premium Land & Prebuilt Courses

## Overview

Land parcels have quality tiers that affect cost, visual presentation, and pre-placed terrain features when purchased. Prebuilt course packages allow players to instantly create playable courses.

## Land Tiers

### Tier Definitions

| Tier | Cost Multiplier | Reputation Gate | Features on Purchase |
|------|----------------|-----------------|---------------------|
| Standard | 1.0x | None | Blank grass (default) |
| Premium | 2.5x | None | Water feature, elevation, themed trees/rocks |
| Elite | 5.0x | 50+ reputation | Premium features + cart paths + fairway corridors |

### Cost Formula

```
parcel_cost = BASE_PARCEL_COST × COST_ESCALATION^total_purchased × TIER_MULTIPLIER

where:
  BASE_PARCEL_COST = $5,000
  COST_ESCALATION = 1.3 (30% increase per parcel purchased)
  TIER_MULTIPLIER = {Standard: 1.0, Premium: 2.5, Elite: 5.0}
```

### Layout Assignment

Each theme has a fixed layout of 4 Premium + 2 Elite parcels, positioned at edges and corners of the 6x6 grid. The center 2x2 (starting parcels) are always Standard. Layouts are deterministic per theme.

### Elite Unlock

Elite parcels are gated behind 50+ reputation. When the player's reputation reaches 50, a notification fires and Elite parcels become purchasable. The unlock state persists through save/load.

## Premium Feature Generation

When a Premium or Elite parcel is purchased, `PremiumLandFeatures` generates terrain features:

1. **Clear existing entities** on the parcel (trees/rocks from natural generation)
2. **Paint water feature** (pond via random walk, stream via Bresenham, or lagoon)
3. **Sculpt elevation** (distance-based falloff from parcel center, range per theme)
4. **Place trees** (theme-appropriate types, 4-16 per parcel)
5. **Place rocks** (1-10 per parcel depending on theme)
6. **Elite only: Paint paths** along one edge
7. **Elite only: Paint fairway/rough corridor** through the parcel center

Features use `set_tile_natural()` to mark tiles as non-player-placed. Seed is deterministic: `parcel.x * 1000 + parcel.y + theme * 10000`.

### Theme Templates

Each theme defines water shape, elevation range, tree types, and counts. Examples:
- **Parkland**: Pond (12 tiles), gentle hills (1-2), oaks/birch (6-10), few rocks
- **Desert**: Oasis (8 tiles), flat (0-1), cactus/dead tree (4-7), many rocks
- **Links**: Stream (6 tiles), dunes (1-2), fescue/heather (3-6), moderate rocks
- **Mountain**: Stream (8 tiles), dramatic hills (2-3), pines (8-14), many rocks

## Prebuilt Course Packages

### Package Data

| Package | Cost | Holes | Par | Requirements |
|---------|------|-------|-----|-------------|
| Starter | $25,000 | 3 | 10 | 3+ parcels |
| Executive | $75,000 | 9 | 27 | 5+ parcels |
| Standard | $100,000 | 9 | 36 | 6+ parcels, 3-star |
| Championship | $200,000 | 18 | 72 | 10+ parcels, 4-star, 50+ rep |

### Layout Algorithm

Holes are placed using a snake/zigzag pattern:

1. Compute bounding rect of all owned parcels
2. Determine holes per row based on count and available space
3. Snake rows: odd rows go left-to-right, even rows right-to-left
4. Per hole, tee/green distance is par-based: Par 3 = 8 tiles, Par 4 = 16, Par 5 = 22
5. Hazards added every 3rd hole (alternating water and bunker)

Courses are painted using `QuickStartCourse` static helpers (`_paint_hole`, `_create_hole`, etc.).

### Gating

- Cannot purchase a package if the course already has holes
- Money, parcel count, star rating, and reputation are all checked
- After purchase, the money is deducted and the course is immediately playable

## Tuning Levers

| Parameter | Location | Default | Effect |
|-----------|----------|---------|--------|
| `TIER_COST_MULTIPLIERS` | `land_manager.gd` | 1.0/2.5/5.0 | Cost scaling per tier |
| `PREMIUM_PARCEL_LAYOUTS` | `land_manager.gd` | Per-theme | Which parcels are premium/elite |
| Elite reputation gate | `land_manager.gd` | 50.0 | When elite parcels unlock |
| Template water/tree counts | `premium_land_features.gd` | Per-theme | Feature density |
| Package costs/requirements | `prebuilt_courses.gd` | See table | Package accessibility |
| Par-to-tile distances | `prebuilt_courses.gd` | 8/16/22 | Hole length in tiles |

## Visual Indicators

- **Land Panel**: Gold buttons for Premium, platinum for Elite, dark gray for locked Elite
- **Land Boundary Overlay**: Gold borders (3.5px) for Premium parcels, platinum borders for Elite, subtle tier-specific tints on unowned land
- **Course Packages Panel**: Card-based UI with requirement checklist, accessible via `P` hotkey or button in Land Panel
