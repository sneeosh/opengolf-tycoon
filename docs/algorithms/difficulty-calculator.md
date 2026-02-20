# Hole Difficulty Calculator

> **Source:** `scripts/course/difficulty_calculator.gd`

## Plain English

Every hole gets a difficulty rating from 1.0 (easy) to 10.0 (extremely hard). This rating is calculated automatically based on the physical design of the hole — its length, hazard placement, elevation changes, doglegs, green size, and landing zone safety.

The difficulty rating feeds into several other systems:
- **Course slope rating** — aggregated across all holes (see [course-rating.md](course-rating.md))
- **Golfer tier attraction** — difficult courses attract pros, easy courses attract beginners (see [golfer-spawning.md](golfer-spawning.md))
- **Tournament qualification** — regional+ tournaments require minimum difficulty
- **Prestige multiplier** — difficult + well-rated courses earn bonus reputation

The calculator analyzes a 10-tile-wide corridor between tee and green, then checks specific areas like landing zones and the green complex for additional hazards. This means strategic hazard placement matters — a bunker near the typical landing zone adds more difficulty than one far off the fairway.

---

## Algorithm

### 1. Total Difficulty (1.0–10.0)

```
total = base_difficulty + hazard_difficulty + elevation_difficulty
      + dogleg_difficulty + green_difficulty + landing_zone_difficulty

total = clamp(total, 1.0, 10.0)
```

### 2. Base Difficulty (from Par)

```
base_difficulty = par - 2.0

Par 3 → 1.0
Par 4 → 2.0
Par 5 → 3.0
```

Longer holes are inherently harder because they require more shots and more things can go wrong.

### 3. Hazard Difficulty (Corridor Analysis)

Scans a 10-tile-wide corridor from tee to green and counts hazard tiles:

```
difficulty  = water_count  * 0.3
            + bunker_count * 0.15
            + ob_count     * 0.2
            + tree_count   * 0.1
```

| Hazard | Per-Tile Weight | Rationale |
| ------ | --------------- | --------- |
| Water | 0.30 | Penalty stroke + re-tee |
| Out of Bounds | 0.20 | Stroke and distance penalty |
| Bunker | 0.15 | Difficult to escape, no penalty |
| Trees | 0.10 | Blocked shots, limited recovery |

### 4. Elevation Difficulty

Samples elevation along the tee-to-green line:

```
for each sample point along the hole:
    total_elevation_change += abs(current_elev - previous_elev)

difficulty = clamp(total_elevation_change * 0.15, 0.0, 1.5)
```

- Each unit of elevation change adds 0.15 difficulty
- Capped at 1.5 (10 units of total change)
- Measures total change, not net change — an up-and-down hole is harder than a flat one even if start and end are the same elevation

### 5. Dogleg Difficulty

Checks if the hole bends (fairway exists off the direct tee-to-green line):

```
# Only applies to par 4+ holes longer than 8 tiles
if par >= 4 and distance > 8:
    midpoint = (tee + green) / 2
    perpendicular = orthogonal to tee-green line

    # Check offsets 2-6 tiles left and right of midpoint
    has_left_fairway  = any fairway tile at midpoint + perpendicular * [2..6]
    has_right_fairway = any fairway tile at midpoint - perpendicular * [2..6]

    # Strong dogleg: fairway only on one side
    if has_left_fairway XOR has_right_fairway:
        difficulty += 0.8
```

### 6. Green Difficulty

Two factors: green size and green slope.

**Green Size (flood-fill from green position):**

```
green_size = flood_fill_count of GREEN tiles (capped at 100)

if green_size < 2:   size_difficulty = +0.8    # Tiny (1 tile) — very hard target
elif green_size < 4: size_difficulty = +0.4    # Small (2-3 tiles)
elif green_size > 6: size_difficulty = -0.2    # Large (7+ tiles) — easier target
else:                size_difficulty = 0.0     # Standard (4-6 tiles)
```

**Green Slope:**

```
slope_range = max_elevation - min_elevation across green tiles
slope_difficulty = clamp(slope_range * 0.25, 0.0, 0.6)
```

- Each unit of slope range adds 0.25 difficulty
- Capped at 0.6 (slope range of 2.4+)
- Sloped greens make putting harder and approach shots more demanding

### 7. Landing Zone Difficulty

Checks for hazards near typical landing areas:

```
# Par 3: No landing zone (approach shot to green)
# Par 4: Landing zone at ~10 tiles (~220 yards) from tee
# Par 5: Two landing zones — 10 tiles and min(hole_length - 6, 18) tiles

for each landing zone:
    check 3-tile radius around center:
        if WATER:            difficulty += 0.15
        if BUNKER:           difficulty += 0.08
        if OUT_OF_BOUNDS:    difficulty += 0.12

difficulty = clamp(total, 0.0, 1.5)
```

### 8. Corridor Sampling Method

```
# Creates a rectangular corridor between two points
direction = (green - tee).normalized()
perpendicular = orthogonal(direction)
half_width = corridor_width / 2    # Default: 5 tiles each side

for each step along the corridor length:
    for each offset across the width (-half_width to +half_width):
        sample_pos = center + perpendicular * offset
        add to corridor tiles
```

### Example Difficulty Calculations

| Hole | Par | Hazards | Features | Approx Difficulty |
| ---- | --- | ------- | -------- | ----------------- |
| Straight par 3, no hazards, big green | 3 | None | Large green | 0.8 |
| Par 4 with 2 bunkers near landing zone | 4 | 2 bunkers | Normal green | 3.0 |
| Par 5 dogleg, water carry, small green | 5 | 5 water tiles | Dogleg, small green | 6.5 |
| Par 4 with water, trees, OB, sloped green | 4 | 8 water, 6 trees, 4 OB | Elevation, small green | 7.5 |

### Tuning Levers

| Parameter | Location | Current Value | Effect |
| --- | --- | --- | --- |
| Corridor width | `difficulty_calculator.gd:18` | 10 tiles | Wider = more hazards counted |
| Water weight | `difficulty_calculator.gd:51` | 0.30 per tile | Higher = water is scarier |
| Bunker weight | `difficulty_calculator.gd:52` | 0.15 per tile | Higher = bunkers are scarier |
| OB weight | `difficulty_calculator.gd:53` | 0.20 per tile | Higher = OB is scarier |
| Tree weight | `difficulty_calculator.gd:54` | 0.10 per tile | Higher = trees are scarier |
| Elevation multiplier | `difficulty_calculator.gd:82` | 0.15 per unit | Higher = hills matter more |
| Elevation cap | `difficulty_calculator.gd:82` | 1.5 | Higher = more elevation difficulty possible |
| Dogleg value | `difficulty_calculator.gd:111` | 0.8 | Higher = doglegs are harder |
| Green size thresholds | `difficulty_calculator.gd:146-151` | 2/4/7 tiles | Adjusts what's "small" vs "large" |
| Slope multiplier | `difficulty_calculator.gd:163` | 0.25 per unit | Higher = sloped greens are harder |
| Landing zone check radius | `difficulty_calculator.gd:192` | 3 tiles | Wider = more landing zone hazards counted |
| Landing zone hazard weights | `difficulty_calculator.gd:199-203` | 0.15/0.08/0.12 | Per-tile weight near landing zones |
