# Routing Overlay & Walk Distance Pace Penalty

> **Source:** `scripts/course/routing_overlay.gd`, `scripts/systems/course_rating_system.gd`

## Plain English

The routing overlay shows colored lines connecting each hole's green to the next hole's tee box. This helps players visualize their course layout and identify where golfers face long walks between holes.

Long walks slow down pace of play, which feeds into the Pace rating category (20% of overall course rating). Players are incentivized to cluster holes or connect them with cart paths.

Toggle the overlay with the `R` hotkey.

---

## Algorithm

### 1. Route Segments

```
For each consecutive hole pair (hole N, hole N+1):
  from = hole_N.green_position
  to   = hole_N+1.tee_position
  distance = euclidean_distance(from, to)   # in tiles
```

Uses straight-line distance (not A* pathfinding) as a cheap, deterministic proxy. If the straight-line distance is long, the actual walking distance is at least that long.

### 2. Color Coding

| Distance (tiles) | Color | Meaning |
| --- | --- | --- |
| < 30 | Green | Short walk, good routing |
| 30–60 | Yellow | Moderate walk, acceptable |
| > 60 | Red | Long walk, pace penalty |

At 22 yards/tile: 30 tiles ≈ 660 yards, 60 tiles ≈ 1,320 yards.

### 3. Pace Rating Walk Penalty

Applied in `_calculate_pace_rating()` before the marshal modifier:

```
avg_walk = average inter-hole walk distance (tiles)

if avg_walk > 60:
  walk_penalty = clamp((avg_walk - 60) × 0.033, 0, 1.0)
elif avg_walk > 40:
  walk_penalty = (avg_walk - 40) × 0.005
else:
  walk_penalty = 0

pace_rating = (base_rating - walk_penalty) × marshal_modifier
```

Maximum penalty: -1.0 star (at ~90+ tile average walks).

---

## Tuning Levers

| Parameter | Location | Current Value | Effect |
| --- | --- | --- | --- |
| Short threshold | `routing_overlay.gd` | 30 tiles | Below = green color |
| Moderate threshold | `routing_overlay.gd` | 60 tiles | Below = yellow, above = red |
| Walk penalty start | `course_rating_system.gd` | 40 tiles avg | Average walk before any penalty |
| Walk penalty max | `course_rating_system.gd` | 1.0 star | Maximum pace rating reduction |
| Walk penalty scale (high) | `course_rating_system.gd` | 0.033/tile | Rate of penalty above 60 tiles |
| Walk penalty scale (low) | `course_rating_system.gd` | 0.005/tile | Rate of penalty 40-60 tiles |
