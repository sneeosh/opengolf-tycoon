# Tournament Simulation System

> Replaces the statistical scoring stub with shot-by-shot headless simulation using the real angular dispersion model, wind system, terrain interactions, and ShotAI decision-making.

## Overview

The TournamentSimulator (`scripts/systems/tournament_simulator.gd`) provides headless shot-by-shot simulation for tournament rounds. It reuses the same shot physics as live golfer play (angular dispersion, club selection, wind effects, terrain penalties) without requiring scene tree nodes.

## Multi-Round Format

| Tier | Rounds | Days | Field | Cut |
|------|--------|------|-------|-----|
| LOCAL | 1 | 1 | 12 | None |
| REGIONAL | 2 | 2 | 24 | None |
| NATIONAL | 4 | 3 | 48 | Top 50% after R2 |
| CHAMPIONSHIP | 4 | 4 | 72 | Top 40 + ties after R2 |

### Day-to-Round Mapping
- **LOCAL:** Day 1: R1
- **REGIONAL:** Day 1: R1, Day 2: R2
- **NATIONAL:** Day 1: R1, Day 2: R2, Day 3: R3 + R4
- **CHAMPIONSHIP:** Day 1: R1, Day 2: R2, Day 3: R3, Day 4: R4

## Shot Simulation Pipeline

Each simulated shot follows this pipeline:

### 1. Decision Phase (ShotAI)
```
GolferData snapshot → ShotAI.decide_shot_for() → ShotDecision {target, club, strategy}
```
Uses the same multi-shot planning, candidate evaluation, and risk analysis as live play.

### 2. Shot Execution (Angular Dispersion)
```
total_accuracy = club_accuracy × skill_accuracy × lie_modifier

max_spread_deg = (1.0 - total_accuracy) × 12.0°
spread_std_dev = max_spread / 2.5

base_angle = gaussian_random() × spread_std_dev
tendency_bias = miss_tendency × (1.0 - total_accuracy) × 6.0°
miss_angle = base_angle + tendency_bias

landing = from + rotated_direction × (distance × distance_modifier)
```

### 3. Distance Modifiers
```
distance_modifier = base_variance × terrain_modifier × wind_modifier × elevation_modifier
```

### 4. Post-Landing
- Wind displacement applied
- Rollout estimated (simplified for performance)
- Hazard penalties (water: +1 stroke + drop; OOB: +1 stroke + replay)

### 5. Putting
Uses the probability-based make model from GolfRules:
```
make_rate = exp(-distance_feet × decay_constant × skill_multiplier)
```
Misses use gaussian-distributed distance and lateral errors capped to prevent cascading multi-putt cycles.

## Field Generation

Tournament fields are generated with tier-appropriate skill distributions:

### Tier Composition

| Tier | Casual | Serious | Pro |
|------|--------|---------|-----|
| LOCAL | 50% | 40% | 10% |
| REGIONAL | 20% | 50% | 30% |
| NATIONAL | 5% | 35% | 60% |
| CHAMPIONSHIP | 0% | 20% | 80% |

### Skill Floors
Skills are floored per tournament tier to ensure competitive fields:
- LOCAL: 0.55
- REGIONAL: 0.65
- NATIONAL: 0.75
- CHAMPIONSHIP: 0.85

### Marquee Golfers
Championship tournaments feature 4 "marquee" golfers with near-maximum skills (0.93-0.99) and recognizable names.

## Cut Line Mechanics

After round 2, higher-tier tournaments apply a cut:

### NATIONAL: Top 50%
```
cut_count = ceil(field_size / 2)
cut_score = standings[cut_count - 1].score_to_par
# All golfers at or better than cut_score advance (includes ties)
```

### CHAMPIONSHIP: Top 40 + Ties
```
cut_count = 40
cut_score = standings[39].score_to_par
# All golfers at or better than cut_score advance
```

## Dramatic Moment Detection

The simulator detects notable events during play:

| Event | Importance | Detail |
|-------|-----------|--------|
| Hole-in-One | 3 (Critical) | "Hole-in-one on Hole N!" |
| Albatross | 3 (Critical) | "Albatross on Hole N!" |
| Eagle | 2 (High) | "Eagle on Hole N" |

Moments are surfaced via `EventBus.tournament_moment` signal and displayed in the results popup.

### Drama Multiplier
Dramatic moments increase spectator revenue through a multiplier:
- Eagle: +5%
- Hole-in-One: +10%
- Albatross: +15%
- Lead Change: +5%
- Maximum multiplier: 1.5x (50% bonus)

## Performance

Target: Simulate one golfer's 18-hole round in <50ms.

Key optimizations:
- No scene tree nodes or rendering
- Simplified rollout (fraction-based rather than tile-by-tile)
- ShotAI reused as-is (already static)
- Per-shot terrain/wind lookups are fast (dictionary access)

## Integration

### Round 1: Live + Simulated
Round 1 spawns live golfer nodes on-course with skills matching the generated SimGolfer field. If End Day is pressed, remaining golfers are simulated via TournamentSimulator.

### Rounds 2+: Fully Simulated
Subsequent rounds call `TournamentSimulator.simulate_round()` for each active golfer, updating the leaderboard with per-round scores.

### Leaderboard
The TournamentLeaderboard shows:
- Multi-round columns (R1, R2, R3, R4) with per-round score-to-par
- Cumulative total score
- Cut line separator between advancing and eliminated golfers
- "MC" (Missed Cut) label for eliminated golfers
- "F" for finished, hole count for in-progress

## Tuning Levers

| Parameter | Location | Default | Effect |
|-----------|----------|---------|--------|
| Skill floor per tier | `TournamentSimulator._get_skill_floor()` | 0.55-0.85 | Minimum skill in field |
| Tier composition | `TournamentSimulator._get_tier_composition()` | See table | Field quality mix |
| Cut rules | `TournamentManager.CUT_RULES` | Top 50%/40+ties | Cut strictness |
| Drama multiplier caps | `TournamentManager._calculate_drama_multiplier()` | 1.5x max | Revenue bonus |
| Max strokes per hole | `GolfRules.get_max_strokes()` | par + 3 | Pickup threshold |
| Rounds per tier | `TournamentManager.ROUNDS_PER_TIER` | 1/2/4/4 | Tournament length |
| Round-day mapping | `TournamentManager._build_round_day_map()` | See spec | Schedule |

## Files

- `scripts/systems/tournament_simulator.gd` — Core headless simulation engine
- `scripts/managers/tournament_manager.gd` — Multi-round lifecycle, cut lines, field management
- `scripts/systems/tournament_system.gd` — Tier data, qualification checks
- `scripts/ui/tournament_leaderboard.gd` — Multi-round leaderboard UI
- `scripts/ui/tournament_results_popup.gd` — Results popup with moments and per-round scores
