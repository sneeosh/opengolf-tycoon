# Course Rating System (Stars)

> **Source:** `scripts/systems/course_rating_system.gd`

## Plain English

The course rating system evaluates the course on a **1-5 star scale** across four categories. Each category measures a different aspect of the golfer experience:

- **Condition (30% weight):** How well-maintained is the course? Measures the ratio of premium terrain (fairway, green, tee box) in play corridors. A course that's mostly rough with thin fairways scores poorly; wide, well-manicured fairways score well. Staff quality (groundskeepers) applies a condition modifier.

- **Design (20% weight):** Does the course have variety? Rewards having a mix of par 3s, 4s, and 5s. The biggest factor is hole count — an 18-hole course gets a large bonus; a 1-hole course barely registers. A single hole with no variety starts at a low base score.

- **Value (30% weight):** Is the course fairly priced? Compares what the golfer pays (green fee x holes) to what the course "should" charge based on reputation and hole count. Charging half the fair price earns 5 stars; charging double earns 1 star. This creates natural pricing pressure — raising fees without improving reputation tanks the rating.

- **Pace (20% weight):** How fast does play move? Uses the bogey-or-worse ratio as a proxy for slow play (more bogeys = more strokes = slower rounds). Marshals (from staff system) improve pace.

The system also calculates **slope rating** (how much harder the course is for average vs scratch golfers) and **course rating** (expected score for a scratch golfer), following USGA conventions.

### Prestige Multiplier

A separate prestige multiplier scales reputation gains. Difficult courses (7+ difficulty) with good ratings (4+ stars) earn bonus reputation — this rewards players who build challenging championship courses rather than easy beginner courses.

---

## Algorithm

### 1. Overall Rating

```
overall = condition * 0.30 + design * 0.20 + value * 0.30 + pace * 0.20
overall = clamp(overall, 1.0, 5.0)
stars   = round(overall)    # Integer for display
```

### 2. Condition Rating

```
# Scan a 12-tile-wide corridor from tee to green for each hole
corridor = get_tiles_in_corridor(tee_position, green_position, width=12)

# Count premium terrain tiles
premium_tiles = count of GREEN, FAIRWAY, TEE_BOX tiles in corridor
total_tiles   = all tiles in corridor

ratio = premium_tiles / total_tiles

# 0% premium = 1 star, 60%+ premium = 5 stars
base_rating = clamp(1.0 + (ratio / 0.15), 1.0, 5.0)

# Staff condition modifier (groundskeeper quality)
# course_condition ranges 0.0 to 1.0 from staff_manager
condition_mod = 0.5 + (course_condition * 0.5)    # Range: 0.5 to 1.0

final_condition = clamp(base_rating * condition_mod, 1.0, 5.0)
```

**Premium ratio to stars:**

| Premium Ratio | Base Rating |
| ------------- | ----------- |
| 0% | 1.0 |
| 15% | 2.0 |
| 30% | 3.0 |
| 45% | 4.0 |
| 60%+ | 5.0 |

### 3. Design Rating

```
base = 1.5    # Low base — a single hole is not good design

# Par variety bonuses
if has_par_3_holes: base += 0.75
if has_par_5_holes: base += 0.75

# Hole count bonuses (biggest factor)
if open_holes >= 18:  base += 2.0    # Full 18-hole course
elif open_holes >= 9: base += 1.5    # Full front nine
elif open_holes >= 6: base += 0.75   # Decent number
elif open_holes >= 4: base += 0.25   # Barely enough variety

design_rating = clamp(base, 1.0, 5.0)
```

**Maximum design score examples:**

| Course Layout | Max Score |
| --- | --- |
| 1 par-4 hole | 1.5 |
| 4 holes, mixed pars | 3.0 |
| 9 holes, par 3+4+5 mix | 4.5 |
| 18 holes, full variety | 5.0 |

### 4. Value Rating

```
hole_count = number of open holes
total_round_cost = green_fee * max(hole_count, 1)

# Fair price scales with reputation AND hole count
hole_factor = clamp(hole_count / 18.0, 0.15, 1.0)
fair_price  = max(reputation * 2.0, 20.0) * hole_factor

price_ratio = total_round_cost / max(fair_price, 1.0)

# Linear mapping:
#   0.5x fair = 5 stars (great value)
#   1.0x fair = ~3.7 stars (fair)
#   2.0x fair = 1 star (overpriced)
rating = 5.0 - (price_ratio - 0.5) * 2.67

value_rating = clamp(rating, 1.0, 5.0)
```

**Fair price examples:**

| Reputation | Holes | Fair Price | $30 Fee = Total | Value Stars |
| ---------- | ----- | ---------- | --------------- | ----------- |
| 50 | 18 | $100 | $540 | ~1 (overpriced) |
| 50 | 9 | $50 | $270 | ~1 (overpriced) |
| 50 | 1 | $15 | $30 | ~1.7 |
| 50 | 18 | $100 | $90 (fee=$5) | 5.0 (great value) |
| 100 | 18 | $200 | $540 | ~2.4 |

### 5. Pace Rating

```
total_scores = birdies + bogeys_or_worse + holes_in_one + eagles
bad_ratio    = bogeys_or_worse / total_scores

# 0% bad = 5 stars, ~50% bad = 2 stars
base_rating = 5.0 - (bad_ratio * 6.0)

# Marshal modifier from staff_manager (0.6 to 1.0)
pace_mod = staff_manager.get_pace_modifier()

pace_rating = clamp(base_rating * pace_mod, 2.0, 5.0)    # Floor of 2.0
```

### 6. Course Difficulty (Average Hole Difficulty)

```
avg_difficulty = sum(hole.difficulty_rating) / open_hole_count
# Scale: 1.0 to 10.0 (see difficulty-calculator.md)
```

### 7. Slope Rating (55-155)

```
slope = 113 + int((avg_difficulty - 5.0) * 8.0)
slope = clamp(slope, 55, 155)
```

- Standard slope: **113** (at difficulty 5.0)
- Each difficulty point above/below 5.0 adjusts slope by ~8
- Example: difficulty 7.0 → slope = 113 + 16 = **129**

### 8. Course Rating (Expected Scratch Score)

```
difficulty_adjustment = (avg_difficulty - 5.0) * 0.15 * open_hole_count
course_rating = total_par + difficulty_adjustment
```

- At difficulty 5.0: course rating equals par
- At difficulty 7.0 with 18 holes: course rating = par + 5.4

### 9. Prestige Multiplier (Reputation Gain Scaling)

```
multiplier = 1.0

# High difficulty + high quality = prestigious
if difficulty >= 7.0 and overall >= 4.0:
    multiplier += 0.5    # +50% reputation
elif difficulty >= 6.0 and overall >= 3.5:
    multiplier += 0.25   # +25% reputation

# Very high quality bonus
if overall >= 4.5:
    multiplier += 0.25   # +25% reputation

# Low quality penalty
if overall < 2.0:
    multiplier *= 0.75   # -25% reputation
```

### Tuning Levers

| Parameter | Location | Current Value | Effect |
| --- | --- | --- | --- |
| Category weights | `course_rating_system.gd:33-37` | 30/20/30/20 | How much each category matters |
| Corridor width | `course_rating_system.gd:163` | 12 tiles | Width of terrain scan |
| Premium ratio divisor | `course_rating_system.gd:178` | 0.15 | Lower = easier to get 5-star condition |
| Design base score | `course_rating_system.gd:211` | 1.5 | Starting design score |
| Par 3/5 bonus | `course_rating_system.gd:214-219` | +0.75 each | Reward for par variety |
| Hole count bonuses | `course_rating_system.gd:223-230` | 0.25-2.0 | Reward for more holes |
| Fair price formula | `course_rating_system.gd:248` | `rep * 2.0` | How reputation maps to fair price |
| Value slope | `course_rating_system.gd:255` | 2.67 | Steepness of value curve |
| Pace bad ratio multiplier | `course_rating_system.gd:276` | 6.0 | How much bogeys hurt pace |
| Slope adjustment per point | `course_rating_system.gd:80` | 8.0 | Slope sensitivity to difficulty |
| Prestige thresholds | `course_rating_system.gd:105-116` | See above | When prestige bonuses kick in |
