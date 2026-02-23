# Prestige System

## Overview

The Prestige system provides long-term progression through 5 tiers: Unranked -> Bronze -> Silver -> Gold -> Platinum. Each tier has requirements based on sustained performance and unlocks gameplay bonuses. This is the "what do I do after the Championship?" answer — it keeps raising the bar.

## Tiers

| Tier | Requirements | Key Unlocks |
|------|-------------|-------------|
| **Unranked** | Starting state | No bonuses |
| **Bronze** | 40 rep, 2.5 stars, $30k revenue, 100 golfers, 28 days | +$10 fee cap, +10% spawns |
| **Silver** | 60 rep, 3.5 stars, $100k revenue, 300 golfers, 3 awards, 56 days | +$25 fee cap, +20% spawns, +15% pros |
| **Gold** | 80 rep, 4.0 stars, $300k revenue, 800 golfers, 8 awards, 1 championship, 112 days | +$50 fee cap, +35% spawns, +25% pros, 10% maint. discount |
| **Platinum** | 90 rep, 4.5 stars, $750k revenue, 2000 golfers, 15 awards, 3 championships, 14 days at 5 stars, 224 days | +$100 fee cap, +50% spawns, +40% pros, 20% maint. discount, 50% rep decay reduction |

## Progress Calculation

Progress toward the next tier is calculated daily at end-of-day. Each requirement is checked independently:

```
check_i = clamp(current_value / required_value, 0.0, 1.0)
```

**Display progress** = average of all checks (so partial progress feels rewarding)
**Promotion** = only when ALL checks reach 1.0 (minimum of checks >= 1.0)

The display caps at 99% until all requirements are actually met, preventing false "almost there" at e.g. 5/8 requirements.

## Gameplay Effects

### Green Fee Cap
`get_effective_max_green_fee()` adds the prestige bonus on top of the hole-count-based cap:
```
base_max = min(holes * 15, 200) + prestige_green_fee_bonus
```

### Spawn Rate
`GolferManager.get_spawn_rate_modifier()` multiplied by `(1.0 + prestige_spawn_bonus)`.

### Maintenance Costs
`GameManager.get_maintenance_multiplier()` reduced by `(1.0 - prestige_discount)`.

### Reputation Decay
`advance_to_next_day()` applies `(1.0 - decay_reduction)` to daily reputation decay.

## Lifetime Stats Tracked

- Total revenue, total golfers served
- Peak reputation, peak course rating
- Days at 4+ stars, days at 5 stars
- Championships hosted
- Total awards earned (from Awards system)
- Total days played

## Integration Points

- **GameManager.get_effective_max_green_fee()** — adds green fee bonus
- **GameManager.get_maintenance_multiplier()** — applies maintenance discount
- **GameManager.advance_to_next_day()** — reduces reputation decay
- **GolferManager.get_spawn_rate_modifier()** — adds spawn rate bonus
- **EventBus.prestige_changed** — emitted on tier promotion
- **SaveManager** — prestige tier and lifetime stats persisted

## Tuning Levers

| Parameter | Location | Effect |
|-----------|----------|--------|
| Tier requirements | `TIER_REQUIREMENTS` dict | Change promotion thresholds |
| Tier unlock bonuses | `TIER_UNLOCKS` dict | Change gameplay rewards per tier |
| Reputation bonus per promotion | `_promote()` array | One-time rep boost on tier-up |
| Progress display formula | `_calculate_progress()` | How progress bar fills |
