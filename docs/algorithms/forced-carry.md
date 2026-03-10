# Forced Carry Distance

> **Source:** `scripts/course/forced_carry_calculator.gd`, `scripts/course/difficulty_calculator.gd`, `scripts/course/hole_visualizer.gd`

## Plain English

A "forced carry" is a stretch of hazard (water or bunker) that sits directly between the tee and pin, forcing golfers to hit the ball over it. The system scans along the tee-to-pin center-line, finds contiguous hazard segments, and measures the carry distance in yards from the last safe tile before the hazard to the first safe tile after.

Carry distances are displayed as dashed lines with yardage labels on the hole visualization. Orange lines indicate normal carries; red lines indicate carries exceeding 150 yards (beyond beginner club range). Carries also contribute to hole difficulty rating.

---

## Algorithm

### 1. Hazard Scan

```
Walk the center-line from tee to pin at 1-tile intervals.
For each sample position:
  - If entering a hazard (WATER or BUNKER): record start
  - If exiting a hazard: compute carry from last safe tile to current tile
  - Track "last safe tile" (most recent non-hazard position)
```

The scan uses straight-line Euclidean distance, not A* or ShotAI waypoints. This is deterministic and represents the geometric design of the hole, not golfer decision-making.

### 2. Carry Segment Data

```
CarrySegment:
  hazard_type    = WATER or BUNKER
  start_grid     = last safe tile before hazard
  end_grid       = first safe tile after hazard
  carry_yards    = distance in yards (tiles × 22)
  exceeds_beginner_range = carry_yards > 150
```

### 3. Difficulty Contribution

```
For each carry segment:
  WATER:
    > 200 yards → +1.5 difficulty
    > 150 yards → +1.0
    > 100 yards → +0.5
    ≤ 100 yards → +0.2

  BUNKER:
    > 150 yards → +0.5
    > 80 yards  → +0.3
    ≤ 80 yards  → +0.1

Total carry difficulty capped at 2.0
```

### 4. Visualization

- Orange dashed line: carry ≤ 150 yards (within beginner range)
- Red dashed line: carry > 150 yards (exceeds beginner range)
- Yardage label at midpoint of each carry segment

---

## Tuning Levers

| Parameter | Location | Current Value | Effect |
| --- | --- | --- | --- |
| Beginner range threshold | `forced_carry_calculator.gd` | 150 yards | Threshold for red vs orange display |
| Water carry difficulty | `difficulty_calculator.gd` | 0.2–1.5 per segment | Higher = more difficulty for water carries |
| Bunker carry difficulty | `difficulty_calculator.gd` | 0.1–0.5 per segment | Higher = more difficulty for bunker carries |
| Max carry difficulty | `difficulty_calculator.gd` | 2.0 | Cap on total carry contribution |
