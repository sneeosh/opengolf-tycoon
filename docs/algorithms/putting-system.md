# Putting System

> **Source:** `scripts/entities/golfer.gd` (lines 1065–1174) and `scripts/systems/golf_rules.gd` (lines 127–208)

## Plain English

Putting uses a completely different model from full shots. Instead of the angular dispersion system, it uses a **probability-based make/miss model** calibrated to real PGA Tour putting statistics.

For each putt, the game first decides: **does the putt go in?** This is a simple yes/no roll based on an exponential decay curve — the farther the putt, the lower the chance. Very short putts (inside 3 feet / ~0.045 tiles) are automatic "tap-ins."

If the putt misses, the game generates a **realistic miss position** using separate distance error and lateral error distributions. Short putts tend to miss laterally (lip-outs), medium putts have a mix of distance and direction error, and long putts are dominated by distance control problems (lag putting).

Better putters (higher `putting_skill`) have:
- Higher make rates at all distances (the decay curve is gentler)
- Tighter miss distributions (shorter comeback putts)
- A slight "long bias" — good putters are taught "never up, never in" and tend to hit putts more firmly

### Green Reading

Before putting, the ShotAI reads the green slope and adjusts the aim point. The ball will break in the direction of the slope, so the golfer aims opposite to the slope. Better putters read more of the break: pros read 70-90%, beginners read 20-40%. The break compensation is capped at 30% of the putt distance to prevent aiming wildly off-target.

---

## Algorithm

### 1. Tap-In Check

```
TAP_IN_DISTANCE = 0.045 tiles  # ~3 feet
CUP_RADIUS = 0.01 tiles        # ~8 inches

if distance_to_hole < TAP_IN_DISTANCE:
    putt is made automatically
```

### 2. Make Rate (Exponential Decay)

```
distance_feet = distance_tiles * 66.0    # 1 tile = 22 yards = 66 feet

base_decay = 0.053
skill_multiplier = 1.0 + (1.0 - putting_skill) * 2.5
decay = base_decay * skill_multiplier

make_rate = exp(-distance_feet * decay)
make_rate = max(make_rate, 0.01)         # 1% floor for any putt
```

**Make rate examples (at skill = 0.95, ~PGA Tour level):**

| Distance | Feet | Make Rate |
| -------- | ---- | --------- |
| 0.045 tiles | 3 ft | ~99% (tap-in) |
| 0.076 tiles | 5 ft | ~77% |
| 0.121 tiles | 8 ft | ~65% |
| 0.152 tiles | 10 ft | ~45% |
| 0.227 tiles | 15 ft | ~45% |
| 0.455 tiles | 30 ft | ~20% |
| 0.758 tiles | 50 ft | ~3% |

**Skill multiplier effect on decay:**

| Putting Skill | Multiplier | Effect |
| ------------- | ---------- | ------ |
| 0.95 (Pro) | 1.125 | Gentle decay, high make rates |
| 0.70 (Serious) | 1.75 | Moderate decay |
| 0.50 (Casual) | 2.25 | Steeper decay |
| 0.35 (Beginner) | 2.625 | Very steep decay |

### 3. Miss Characteristics (by Distance Category)

**Short Putts (< 10 feet):**
```
distance_std = 0.015 + (1.0 - putting_skill) * 0.02    # ~1.0-2.3 ft
lateral_std  = 0.008 + (1.0 - putting_skill) * 0.017   # ~0.5-1.6 ft
```
Mostly lateral misses (lip-outs). Tight distance control.

**Medium Putts (10-30 feet):**
```
distance_std = 0.03 + (1.0 - putting_skill) * 0.06     # ~2.0-5.9 ft
lateral_std  = 0.015 + (1.0 - putting_skill) * 0.035   # ~1.0-3.3 ft
```
Mix of distance and direction error.

**Long Putts (30+ feet):**
```
distance_std = distance_tiles * (0.06 + (1.0 - putting_skill) * 0.12)  # Proportional to distance
lateral_std  = 0.025 + (1.0 - putting_skill) * 0.06    # ~1.7-5.6 ft
```
Distance control is the main challenge (lag putting). Error scales with putt length.

### 4. Long Bias

```
long_bias = 0.02 + putting_skill * 0.03
```

- Low skill (0.35): bias = 0.031 tiles (~2 ft past the hole)
- High skill (0.95): bias = 0.049 tiles (~3.2 ft past the hole)
- Better players hit firmer (they know the putt won't go in if it doesn't reach)

### 5. Miss Position Calculation

```
distance_error = gaussian_random() * distance_std + long_bias
lateral_error  = gaussian_random() * lateral_std

landing = hole_position + direction * distance_error + perpendicular * lateral_error
```

### 6. Miss Distance Caps

Prevents cascading multi-putt cycles by capping how far misses end up from the hole:

```
# Short putts (< 10 ft / 0.15 tiles):
max_miss = 0.03 + (1.0 - putting_skill) * 0.025    # ~2-3.6 ft

# Medium putts (10-30 ft / 0.15-0.45 tiles):
max_miss = 0.04 + (1.0 - putting_skill) * 0.05     # ~2.6-5.9 ft

# Long putts (30+ ft / 0.45+ tiles):
max_miss = distance * (0.08 + (1.0 - putting_skill) * 0.12)

if miss_distance > max_miss:
    landing = hole_pos + normalized_direction * max_miss

# Snap to hole if accidentally very close (inside cup radius)
if landing.distance_to(hole) < CUP_RADIUS:
    landing = hole_pos  # Ball drops in
```

### 7. Green Edge Constraint

If a putt would roll off the green, trace the path and stop at the last green tile:

```
for each point along putt path:
    if terrain is GREEN:
        entered_green = true
        last_valid = this point
    elif entered_green:
        break  # Left the green — stop here

landing = last_valid  # Ball stops at green edge
```

### 8. Green Reading (ShotAI)

```
slope = terrain_grid.get_slope_direction(hole_position)

if slope.length() < 0.1:
    aim at hole directly  # Flat green

# Read ability scales with putting skill
read_ability = 0.2 + putting_skill * 0.7
# Pros: 0.87 (read 87% of break), Beginners: 0.41

# Break compensation
break_compensation = slope.length() * putt_distance * read_ability * 0.5
break_compensation = min(break_compensation, putt_distance * 0.3)  # Cap at 30%

# Aim opposite to slope
aim_offset = -slope.normalized() * break_compensation
aim_point = hole_position + aim_offset
```

### Tuning Levers

| Parameter | Location | Current Value | Effect |
| --- | --- | --- | --- |
| Base decay constant | `golf_rules.gd:151` | 0.053 | Higher = harder to make putts at distance |
| Skill multiplier scale | `golf_rules.gd:154` | 2.5 | Higher = bigger gap between pros and beginners |
| Tap-in distance | `golf_rules.gd:119` | 0.045 tiles (~3 ft) | Higher = more automatic makes |
| Cup radius | `golf_rules.gd:115` | 0.01 tiles (~8 in) | Higher = easier to hole out |
| Make rate floor | `golf_rules.gd:160` | 0.01 (1%) | Higher = more lucky long makes |
| Long bias range | `golf_rules.gd:202` | 0.02-0.05 | Higher = putts roll further past |
| Short putt miss caps | `golfer.gd:1127` | 0.03-0.055 tiles | Higher = longer comeback putts |
| Green read ability | `shot_ai.gd:162` | 0.2-0.9 | Range of green reading skill |
| Max break compensation | `shot_ai.gd:172` | 30% of distance | Higher = more break adjustment |
