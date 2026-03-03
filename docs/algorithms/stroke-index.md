# Stroke Index (Hole Handicap Allocation)

**Source:** `scripts/systems/stroke_index_calculator.gd`
**Depends on:** `DifficultyCalculator` hole difficulty ratings (1.0–10.0)

## Overview

Stroke index ranks holes from 1 (hardest) to N (easiest), matching the "Hcp" row on a real golf scorecard. It is derived automatically from `DifficultyCalculator` ratings — no manual assignment needed.

## Algorithm

### Input
- Array of `HoleData` with `difficulty_rating` (float, 1.0–10.0) and `is_open` (bool)

### Step 1: Filter and Sort
1. Include only open holes
2. Sort descending by `difficulty_rating` (hardest first)
3. Tie-break: lower hole number gets the harder (lower) stroke index

### Step 2: Assign Indices

**For 9 or fewer holes:** Simple sequential — hardest = 1, next = 2, ..., easiest = N.

**For 10+ holes:** Interleave front/back nine per standard golf convention:
- Front 9 (holes 1–9) receive **odd** stroke indices: 1, 3, 5, 7, 9, 11, ...
- Back 9 (holes 10+) receive **even** stroke indices: 2, 4, 6, 8, 10, 12, ...

This spreads difficulty evenly across the two nines, matching how real courses allocate handicap strokes.

### Step 3: Store
Store the computed `stroke_index` on each `HoleData`. This is derived data — not persisted in save files, recalculated on load.

## Recalculation Triggers

- Hole created
- Hole deleted
- Hole toggled open/closed
- Game loaded from save

## Example

| Hole | Difficulty | Stroke Index |
|------|-----------|-------------|
| 3    | 7.8       | 1 (hardest) |
| 7    | 6.5       | 3           |
| 1    | 5.9       | 5           |
| 5    | 4.2       | 7           |
| 9    | 3.1       | 9 (easiest) |

## Tuning Levers

| Lever | Current | Effect |
|-------|---------|--------|
| Tie-break rule | Lower hole number wins | Could use secondary criteria (hazard count, length) |
| Front/back threshold | 10 holes | Below this, simple sequential assignment |
| Difficulty source | `DifficultyCalculator.calculate_hole_difficulty()` | Any change to the difficulty formula cascades to stroke indices |
