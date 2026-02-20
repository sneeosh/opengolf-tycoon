# Ball Physics & Rollout

> **Source:** `scripts/entities/ball.gd` and `scripts/entities/golfer.gd` (lines 1450–1633)

## Plain English

The ball physics system handles two phases of ball movement: **flight** (carry through the air) and **rollout** (ground roll after landing). These are purely visual animations — the actual landing position is calculated mathematically by the shot accuracy system before the animation begins.

### Flight Animation

Full shots follow a **parabolic arc**: the ball rises to a peak at mid-flight and descends to the landing point. The arc height scales with shot distance, capped at 150 pixels. Putts have zero arc height and roll along the ground.

During flight, **wind visual drift** creates a bell-curve displacement — the ball appears to drift sideways most at mid-flight and returns to the correct landing position at the end. This is purely cosmetic; the actual landing was already calculated with wind factored in.

The ball also scales up slightly during flight to create a depth perception effect — it appears closer to the camera at the peak of its arc.

### Rollout System

After the carry lands, the ball may roll forward (or backward with backspin on wedge shots). Rollout distance depends on:
- **Club type** — Drivers roll 5–15% of carry; wedge chips roll 6–18%
- **Landing terrain** — Greens are fast (1.3x roll), rough grabs the ball (0.3x)
- **Slope** — Downhill rolls up to 50% farther; uphill reduces roll
- **Backspin** — Skilled players (accuracy+recovery > 0.7) can generate backspin on full wedge shots, making the ball roll backwards

The rollout path is walked step-by-step, checking for hazards. If the ball rolls into water, OB, or a bunker, it stops there. Entering rough from fairway triggers a deceleration effect (60% remaining roll reduction).

---

## Algorithm

### 1. Flight Arc

```
# Per frame during flight:
flight_progress += delta / flight_duration

# Linear interpolation for horizontal position
linear_pos = start_pos.lerp(end_pos, flight_progress)

# Parabolic arc for height
arc_height = sin(flight_progress * PI) * max_height

# Max height scales with distance, capped
max_height = min(distance_pixels * 0.3, 150.0)
# Putts: max_height = 0.0

# Wind visual drift (bell curve, peaks at mid-flight)
wind_drift = wind_visual_offset * sin(flight_progress * PI)

# Final visual position
position = linear_pos - Vector2(0, arc_height) + wind_drift
```

### 2. Depth Perception Scale

```
if max_height > 0.0:
    scale_factor = 1.0 + (arc_height / max_height) * 0.5
    scale = Vector2(scale_factor, scale_factor)

# At peak: scale = 1.5x (50% larger)
# At ground: scale = 1.0x (normal)
```

### 3. Flight Duration

```
duration = 1.0 + (distance_yards / 300.0) * 1.5
duration = clamp(duration, 0.5, 3.0)

# 100 yard shot: ~1.5 seconds
# 250 yard drive: ~2.25 seconds
```

### 4. Rollout Base Fractions (% of Carry Distance)

| Club | Min Roll | Max Roll | Notes |
| ---- | -------- | -------- | ----- |
| Driver | 5% | 15% | Long, low-spin shots roll more |
| Fairway Wood | 5% | 14% | Similar to driver |
| Iron | 5% | 14% | Moderate trajectory |
| Wedge (full) | -4% | 8% | Negative = backspin (for skilled players) |
| Wedge (chip) | 6% | 18% | Lower trajectory, always rolls forward |

**Chip vs Full Wedge:**
```
distance_ratio = carry_distance / club_max_distance
if distance_ratio > 0.65:  → full wedge (backspin possible)
else:                       → chip shot (always rolls forward)
```

### 5. Backspin (Full Wedge Shots Only)

```
spin_skill = accuracy_skill * 0.6 + recovery_skill * 0.4

if spin_skill > 0.7:
    # Shift rollout toward negative (backspin)
    spin_bonus = (spin_skill - 0.7) / 0.3    # 0.0 to 1.0
    base_rollout -= spin_bonus * 0.10

# Clamp: even best players can't spin back more than 4% of carry
base_rollout = max(base_rollout, -0.04)

if base_rollout < 0.0:
    is_backspin = true    # Ball rolls backward
```

### 6. Terrain Roll Multiplier

| Landing Terrain | Multiplier | Effect |
| --------------- | ---------- | ------ |
| Green | 1.3x | Fast, smooth surface |
| Fairway | 1.0x | Baseline |
| Tee Box | 1.0x | Same as fairway |
| Grass | 0.35x | Natural grass grabs ball |
| Rough | 0.3x | Rough grabs the ball |
| Heavy Rough | 0.12x | Ball stops fast |
| Trees | 0.2x | Dense ground cover |
| Rocks | 0.15x | Rocky ground kills momentum |
| Path | 1.4x | Hard surface, extra bounce |

**Backspin terrain interaction:**
```
# Backspin is less affected by terrain (spin is on the ball)
if is_backspin:
    terrain_mult = lerp(1.0, terrain_mult, 0.4)
    # Only 40% of terrain effect applies to backspin
```

### 7. Slope Influence on Rollout

```
slope = terrain_grid.get_slope_direction(carry_position)

# Blend slope into roll direction (longer rolls are more affected)
slope_influence = clamp(rollout_distance / 3.0, 0.1, 0.5)
roll_direction = (shot_direction * (1 - slope_influence) + slope * slope_influence).normalized()

# Slope dot product with roll direction
slope_dot = slope.dot(roll_direction)

if slope_dot > 0:
    # Rolling downhill: up to +50% extra roll
    rollout_distance *= 1.0 + slope_dot * 0.5
elif slope_dot < 0:
    # Rolling uphill: reduce roll (minimum 20% of original)
    rollout_distance *= max(0.2, 1.0 + slope_dot * 0.5)
```

### 8. Rollout Path Hazard Check

```
steps = ceil(rollout_distance * 4.0)    # Check every quarter-tile
step_size = rollout_distance / steps

for each step along roll path:
    check_terrain = terrain at step position

    if WATER: stop (ball goes in water)
    if OUT_OF_BOUNDS: stop (ball goes OB)
    if BUNKER: stop (ball plugs in sand)

    # Rough deceleration when entering from fairway
    if ROUGH and previous terrain was FAIRWAY:
        rollout_distance *= 0.6  # 40% reduction in remaining roll
```

### 9. Rollout Animation (Visual)

```
# Ease-out deceleration: ball slows down as it rolls
eased_t = 1.0 - pow(1.0 - roll_progress, 2.0)
position = roll_start.lerp(roll_end, eased_t)

# Duration scales with screen distance
screen_dist = rollout_tiles * 64.0    # 64px per tile
duration = 0.3 + (screen_dist / 200.0) * 0.8
duration = clamp(duration, 0.2, 1.2)

# Minimum rollout threshold (below this, skip animation)
if rollout_tiles < 0.15:  → no rollout animation
```

### 10. Landing Impact Effects

```
if flight_max_height > 10.0:    # Skip for putts and short chips
    impact_type based on landing terrain:
        Fairway/Tee/Green: "fairway" (divot mark)
        Grass/Rough/Heavy: "grass" (turf spray)
        Bunker: "bunker" (sand explosion)
        Water: "water" (splash)
```

### Tuning Levers

| Parameter | Location | Current Value | Effect |
| --- | --- | --- | --- |
| Max arc height | `ball.gd:83` | 150.0 pixels | Higher = more dramatic arc |
| Arc height ratio | `ball.gd:83` | 0.3x distance | Higher = higher shots |
| Scale factor at peak | `ball.gd:156` | 1.5x (0.5 bonus) | Higher = more depth effect |
| Flight duration range | `golfer.gd:1622-1623` | 0.5–3.0 seconds | Longer = slower animation |
| Rollout fractions | `golfer.gd:1476-1497` | See table | Higher = more roll |
| Chip threshold | `golfer.gd:1488` | 0.65 distance ratio | Higher = more shots treated as chips |
| Backspin skill threshold | `golfer.gd:1510` | 0.7 | Lower = more players get backspin |
| Max backspin | `golfer.gd:1515` | -4% of carry | More negative = more backspin |
| Terrain roll multipliers | `golfer.gd:1522-1542` | See table | Higher = more roll on that surface |
| Slope influence range | `golfer.gd:1571` | 0.1–0.5 | Higher = slope affects roll direction more |
| Downhill bonus | `golfer.gd:1577` | +50% max | Higher = more downhill run |
| Rough deceleration | `golfer.gd:1609` | 0.6x (40% reduction) | Lower = rough stops ball faster |
| Min rollout threshold | `golfer.gd:1553` | 0.15 tiles | Lower = show shorter rolls |
| Ease-out exponent | `ball.gd:178` | 2.0 | Higher = more dramatic deceleration |
