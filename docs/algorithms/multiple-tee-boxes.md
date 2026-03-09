# Multiple Tee Boxes (3 Tiers)

> **Source:** `scripts/autoload/game_manager.gd` (HoleData class), `scripts/managers/golfer_manager.gd`

## Plain English

Each hole has three tee positions: Forward (red), Middle (white), and Back (blue). The back tee is where the player places the tee during hole creation — the forward and middle tees are auto-generated at 60% and 75% of the back-tee distance along the tee-to-green line.

Golfers select their tee based on skill tier. Beginners play from the forward tees, pros play from the back tees, and intermediate tiers get a random mix. Tournament mode forces all players to back tees.

Each tee has its own par calculation based on its distance to the green, so a 480-yard par 5 from the back might be a 360-yard par 4 from the forward tees. Golfers are scored against the par for their selected tee.

---

## Algorithm

### 1. Auto-Generation

```
Given: back_tee (placed by player), green_position

direction = (green - back_tee) normalized
length = distance(back_tee, green)

if length < 2 tiles:
    all tees = back_tee (too short to differentiate)
else:
    forward_tee = back_tee + direction × (0.4 × length)   # 60% of distance remains
    middle_tee  = back_tee + direction × (0.25 × length)   # 75% of distance remains

    Snap each to nearest valid grid position
    If invalid position → fall back to back_tee
```

### 2. Tier-Based Tee Selection

```
For each golfer starting a hole:
  if tournament_golfer → back tee (always)
  else:
    BEGINNER → forward
    CASUAL   → random(forward, middle)  [50/50]
    SERIOUS  → random(middle, back)     [50/50]
    PRO      → back
```

The selected tee key is stored on the golfer as `current_tee_key` for per-tee par scoring.

### 3. Per-Tee Par

```
For each tee position:
    distance_yards = euclidean_distance(tee, green) × 22 yards/tile
    par = GolfRules.calculate_par(distance_yards)
        < 250 yards → Par 3
        250–470 yards → Par 4
        > 470 yards → Par 5
```

### 4. Scoring

When a golfer finishes a hole, their score is compared against `par_by_tee[current_tee_key]` rather than the hole's default par. The default `hole.par` remains the back-tee par for scorecard display and course rating purposes.

---

## Tuning Levers

| Parameter | Location | Current Value | Effect |
| --- | --- | --- | --- |
| Forward tee distance | `game_manager.gd` HoleData | 60% of back-tee distance | Closer = easier for beginners |
| Middle tee distance | `game_manager.gd` HoleData | 75% of back-tee distance | Closer = more accessible |
| BEGINNER tee | `game_manager.gd` HoleData | forward | Which tee beginners use |
| CASUAL tee mix | `game_manager.gd` HoleData | 50% forward, 50% middle | Casual golfer tee distribution |
| SERIOUS tee mix | `game_manager.gd` HoleData | 50% middle, 50% back | Serious golfer tee distribution |
| PRO tee | `game_manager.gd` HoleData | back | Which tee pros use |
| Tournament tee | `golfer_manager.gd` | back (forced) | Tournament always uses back tee |
