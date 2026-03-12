# Premium Land & Prebuilt Courses

## Plain English

Players expand their course by buying adjacent land parcels from a 6x6 grid. Parcels now have quality tiers — Standard (blank grass), Premium (pre-built terrain features), and Elite (dramatic terrain with dense vegetation). Premium and Elite parcels cost more but give a design head start. Elite parcels are gated behind 50 reputation.

Players can also buy prebuilt course packages that auto-build playable holes on owned land, ranging from a 3-hole Starter to a full Championship 18.

## Parcel Tier Assignment

Each theme defines which grid positions are Premium or Elite. The center 2x2 (starting parcels) are always Standard. Typically 4-6 Premium parcels at edges/corners and 1-2 Elite parcels at high-value positions. City theme has no Elite parcels (urban theme has a satisfaction ceiling).

Positions are deterministic per theme — same theme always has the same tier layout.

## Cost Formula

```
base_cost = $5,000 * 1.3^(total_parcels_purchased)
parcel_cost = base_cost * tier_multiplier

Tier multipliers:
  Standard: 1.0x
  Premium:  2.5x
  Elite:    5.0x
```

The escalation exponent (`total_parcels_purchased`) counts all purchased parcels regardless of tier.

## Feature Generation

When a Premium or Elite parcel is purchased, terrain features are generated within its 20x20 tile rect. Features are theme-specific:

| Feature | Premium | Elite |
|---------|---------|-------|
| Pond | 3-5 tile radius | 4-7 tile radius |
| Trees | 4-8 trees | 8-16 trees |
| Elevation | ±2 range | ±4 range |
| Rough | 1-2 patches | 2-4 patches |
| Rocks | 3-6 rocks | 6-12 rocks |

Each theme selects 2 features for Premium and 3 for Elite from the table above. For example:
- Parkland: Premium gets water + trees; Elite adds elevation
- Desert: Premium gets elevation + rough; Elite adds rocks
- Mountain: Premium gets elevation + trees; Elite adds water

Generation uses a deterministic RNG seed based on parcel position, so the same parcel always generates the same features.

## Prebuilt Course Packages

Prebuilt courses are purchased from the **Main Menu** before starting a new game. Money earned in previous games carries over (GameManager is an autoload that persists across scene reloads). The package cost is deducted, then a new game starts with the course pre-built.

| Package | Holes | Par | Cost |
|---------|-------|-----|------|
| Starter | 3 | ~12 | $25,000 |
| Executive 9 | 9 par-3 | 27 | $75,000 |
| Standard 9 | 9 mixed | 36 | $100,000 |
| Championship 18 | 18 mixed | 72 | $200,000 |

Packages build complete holes with fairways, greens, bunkers, and water hazards. The player can modify everything after purchase.

## Tuning Levers

| Parameter | Location | Default | Effect |
|-----------|----------|---------|--------|
| `BASE_PARCEL_COST` | `land_manager.gd` | $5,000 | Starting expansion cost |
| `COST_ESCALATION` | `land_manager.gd` | 1.3 | Per-purchase cost growth |
| `TIER_COST_MULTIPLIER` | `land_manager.gd` | 1.0/2.5/5.0 | Premium/Elite price premiums |
| `ELITE_REPUTATION_REQUIREMENT` | `land_manager.gd` | 50.0 | Rep gate for Elite parcels |
| `PACKAGE_COSTS` | `prebuilt_course_generator.gd` | see table | Package prices |
| Pond radius ranges | `premium_feature_generator.gd` | 3-5 / 4-7 | Water feature size |
| Tree count ranges | `premium_feature_generator.gd` | 4-8 / 8-16 | Vegetation density |
| Elevation ranges | `premium_feature_generator.gd` | ±2 / ±4 | Terrain drama |
