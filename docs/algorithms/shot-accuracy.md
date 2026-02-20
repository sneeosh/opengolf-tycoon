# Shot Accuracy & Angular Dispersion

> **Source:** `scripts/entities/golfer.gd` (lines 1176–1437) and `scripts/systems/golf_rules.gd`

## Plain English

When a golfer swings, the ball doesn't go exactly where they aimed. Instead of randomly scattering shots in a circle around the target, the game uses an **angular dispersion model** — the shot direction is rotated by a small error angle. This produces realistic miss patterns: hooks (curving left), slices (curving right), and the occasional catastrophic shank.

The error angle is sampled from a **bell curve (gaussian distribution)**, so most shots land close to the target line with only occasional big misses in the tails. This is more realistic than a uniform random spread because:

- **Misses scale with distance**: the same 3-degree error produces a bigger miss at 250 yards than at 100 yards.
- **Each golfer has a consistent miss tendency**: some slice, some hook. This is a persistent personality trait, not random per-shot.
- **Skilled players compensate**: high-accuracy golfers can counteract their natural miss tendency; low-accuracy golfers can't.

### Miss Tendency (Hook/Slice Bias)

Every golfer is born with a `miss_tendency` value between -1.0 (strong hook) and +1.0 (strong slice). The magnitude depends on their tier — beginners have strong tendencies (0.4–0.8), pros are nearly neutral (0.0–0.15). This creates a "natural shot shape" that the golfer either fights or plays into, depending on skill.

### Shanks

Rarely, a golfer will hit a shank — a catastrophic sideways miss where the ball flies 35–55 degrees off line at 30–60% of normal distance. Only happens on full swings (not putts or wedges). The probability scales inversely with accuracy, so beginners shank much more often than pros. The shank direction follows the golfer's natural miss tendency.

### Distance Loss (Topped/Fat Shots)

Independently of the angular miss, each shot has a small chance of distance loss — a topped or fat shot that doesn't travel full distance. This is also bell-curve distributed, so most shots are near full distance with occasional chunks.

### Minimum Lateral Dispersion Floor

The angular model produces very tight clusters at short range (same angle = fewer yards off-target), but real golfers still scatter short iron shots due to alignment, contact quality, and tempo inconsistencies. A lateral dispersion floor ensures that beginners scatter across the green on short par 3s rather than all landing in a tight cluster.

---

## Algorithm

### 1. Accuracy Calculation

```
skill_accuracy = weighted blend of driving_skill and accuracy_skill (varies by club)
base_accuracy  = club_accuracy_modifier (Driver: 0.70, FW: 0.78, Iron: 0.85, Wedge: 0.95, Putter: 0.98)
lie_modifier   = terrain penalty (Fairway: 1.0, Rough: 0.75, Heavy Rough: 0.5, Bunker: 0.4–0.6, Trees: 0.3, Rocks: 0.25)

total_accuracy = base_accuracy * skill_accuracy * lie_modifier
```

**Skill accuracy blending by club:**

| Club         | Formula                                       |
| ------------ | --------------------------------------------- |
| Driver       | `driving_skill * 0.7 + accuracy_skill * 0.3`  |
| Fairway Wood | `driving_skill * 0.5 + accuracy_skill * 0.5`  |
| Iron         | `driving_skill * 0.4 + accuracy_skill * 0.6`  |
| Wedge        | `accuracy_skill * 0.7 + recovery_skill * 0.3` |
| Putter       | `putting_skill`                                |

**Accuracy floors:**

- Wedge: floor from `lerp(0.96, 0.80, distance_ratio)` — close chips are always accurate
- Putter: skill-scaled floor from `lerp(skill_floor_max, skill_floor_min, distance_ratio)`
  - Low skill (0.3): 50%–85% range
  - High skill (0.95): 80%–95% range

### 2. Angular Spread

```
max_spread_deg = (1.0 - total_accuracy) * 12.0
spread_std_dev = max_spread_deg / 2.5
```

- Worst case (beginner, ~0% accuracy): **12 degree** max spread
- Pro-level (95% accuracy): **~0.6 degree** max spread
- The 2.5 divisor means ~95% of shots land within `max_spread_deg` of the target line

**Wedge partial-swing reduction:**

```
if club == WEDGE:
    distance_ratio = actual_distance / club_max_distance
    spread_std_dev *= lerp(0.3, 1.0, distance_ratio)
```

### 3. Miss Angle Sampling

```
base_angle_deg    = gaussian_random() * spread_std_dev
tendency_strength = miss_tendency * (1.0 - total_accuracy) * 6.0
miss_angle_deg    = base_angle_deg + tendency_strength
```

- `gaussian_random()` returns a value with mean ~0, std dev ~1
- `tendency_strength` adds a persistent directional bias — lower accuracy amplifies it
- Maximum tendency bias at worst accuracy: **6 degrees** of consistent hook/slice

### 4. Gaussian Random Generator

```gdscript
func _gaussian_random() -> float:
    return (randf() + randf() + randf() + randf() - 2.0) / 0.5774
```

Uses the Central Limit Theorem: sum of 4 uniform random values, centered and scaled.
- Mean: ~0
- Standard deviation: ~1
- Range: approximately -3.5 to +3.5
- 68% of values within +/-1, 95% within +/-2, 99.7% within +/-3

### 5. Shank Detection

```
if club != PUTTER and club != WEDGE:
    shank_chance = (1.0 - total_accuracy) * 0.04
    if randf() < shank_chance:
        shank_direction = +1.0 if miss_tendency >= 0 else -1.0
        miss_angle_deg  = shank_direction * randf_range(35.0, 55.0)
        actual_distance *= randf_range(0.3, 0.6)
```

| Accuracy | Shank Chance |
| -------- | ------------ |
| 0.30     | 2.8%         |
| 0.50     | 2.0%         |
| 0.70     | 1.2%         |
| 0.95     | 0.2%         |

### 6. Direction Rotation and Landing

```
miss_angle_rad = deg_to_rad(miss_angle_deg)
miss_direction = direction.rotated(miss_angle_rad)
landing_point  = from + (miss_direction * actual_distance)
```

### 7. Minimum Lateral Dispersion Floor

```
angular_lateral_std = actual_distance * sin(deg_to_rad(spread_std_dev))
min_lateral_std     = (1.0 - total_accuracy) * 0.8

if angular_lateral_std < min_lateral_std:
    extra_std = sqrt(min_lateral_std^2 - angular_lateral_std^2)
    landing_point += perpendicular * (gaussian_random() * extra_std)
```

### 8. Distance Loss (Topped/Fat)

```
distance_loss = abs(gaussian_random()) * (1.0 - total_accuracy) * 0.12
landing_point -= miss_direction * (actual_distance * distance_loss)
```

- Maximum 12% distance loss at worst accuracy
- `abs()` ensures loss is always a reduction, never a gain
- Bell curve distribution: most shots near full distance

### 9. Distance Execution Variance

Small per-shot variance representing natural swing inconsistency:

| Club         | Modifier Range | Example   |
| ------------ | -------------- | --------- |
| Driver       | 0.91 – 1.01   | +/-5%     |
| Fairway Wood | 0.92 – 1.01   | +/-4.5%   |
| Iron         | 0.94 – 1.01   | +/-3.5%   |
| Wedge        | 0.95 – 1.00   | +/-2.5%   |
| Putter       | 0.97 – 1.00   | +/-1.5%   |

### 10. External Distance Modifiers

Applied multiplicatively to the distance modifier:

- **Terrain distance penalty**: Rough 0.85, Heavy Rough 0.70, Bunker 0.75, Trees 0.60, Rocks 0.50
- **Wind**: headwind/tailwind modifier from `WindSystem.get_distance_modifier()` (see [wind-system.md](wind-system.md))
- **Elevation**: `1.0 - (elevation_diff * 0.03)`, clamped to [0.75, 1.25] — ~3% per elevation unit

### Tuning Levers

| Parameter | Location | Current Value | Effect |
| --- | --- | --- | --- |
| Max angular spread multiplier | `golfer.gd:1298` | `12.0` | Higher = wider spread for inaccurate players |
| Spread divisor (95% coverage) | `golfer.gd:1299` | `2.5` | Higher = tighter spread within max |
| Tendency multiplier | `golfer.gd:1311` | `6.0` | Higher = more hook/slice for inaccurate players |
| Shank probability multiplier | `golfer.gd:1318` | `0.04` | Higher = more shanks |
| Shank angle range | `golfer.gd:1322` | `35.0–55.0` | Wider = more severe shanks |
| Shank distance range | `golfer.gd:1323` | `0.3–0.6` | Lower = shorter shanks |
| Distance loss multiplier | `golfer.gd:1346` | `0.12` | Higher = more topped/fat shots |
| Min lateral dispersion | `golfer.gd:1338` | `0.8` | Higher = more scatter on short shots |
| Club accuracy modifiers | `golfer.gd` CLUB_STATS | 0.70–0.98 | Lower = less accurate club |
