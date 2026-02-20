# Wind System

> **Source:** `scripts/systems/wind_system.gd` and `scripts/systems/golf_rules.gd` (lines 255–272)

## Plain English

Wind is generated fresh each day with a random direction (full 360 degrees) and speed (2–20 mph). Throughout the day, the wind slowly drifts in direction and fluctuates slightly in speed, simulating real weather patterns.

Wind affects ball flight in two ways:

1. **Crosswind displacement** — Pushes the ball laterally off its intended line. This is the most visible effect and creates the classic challenge of aiming into the wind.

2. **Headwind/tailwind distance modifier** — Headwinds reduce how far the ball travels (up to 15% at 30 mph), tailwinds increase it (up to 10%). The asymmetry is intentional — headwinds hurt more than tailwinds help, matching real golf.

The wind effect scales with **club sensitivity**. High-trajectory clubs (Driver) are fully affected; ground-level clubs (Putter) are not affected at all. The effect also scales with shot distance — longer shots spend more time in the air and are pushed more.

The ShotAI compensates for wind by aiming into it (see [shot-ai-target-finding.md](shot-ai-target-finding.md)), but the compensation is skill-dependent — pros adjust ~80% of the wind, beginners only ~20%.

---

## Algorithm

### 1. Daily Wind Generation

```
wind_direction = randf() * TAU           # 0 to 2*PI (full circle)
wind_speed     = randf_range(2.0, 20.0)  # MPH
drift_rate     = randf_range(-0.3, 0.3)  # Radians per hour
```

### 2. Hourly Wind Drift

```
wind_direction = base_direction + drift_rate * hours_elapsed
wind_speed     = clamp(wind_speed + randf_range(-0.5, 0.5), 0.0, 30.0)
```

- Direction drifts smoothly based on drift_rate
- Speed fluctuates by +/-0.5 mph per hour
- Speed clamped to 0–30 mph range

### 3. Crosswind Displacement

```
# Wind as a vector
wind_vector = Vector2(-sin(wind_direction), cos(wind_direction)) * wind_speed

# Decompose into headwind and crosswind components
headwind      = wind_vector.dot(shot_direction_normalized)    # Positive = tailwind
crosswind_vec = wind_vector - shot_direction_normalized * headwind

# Scale by distance and club sensitivity
distance_factor = distance_tiles / 20.0    # Normalize to ~driver distance
wind_factor     = sensitivity * distance_factor

# Final lateral displacement
displacement = crosswind_vec * wind_factor * 0.15
```

### 4. Distance Modifier (Headwind/Tailwind)

```
headwind_component = wind_vector.dot(shot_direction_normalized)

if headwind_component < 0:
    # Headwind: up to 15% distance reduction at 30 mph
    modifier = 1.0 - abs(headwind_component) / 30.0 * 0.15 * sensitivity

else:
    # Tailwind: up to 10% distance increase at 30 mph
    modifier = 1.0 + headwind_component / 30.0 * 0.10 * sensitivity

modifier = clamp(modifier, 0.75, 1.15)
```

**Distance modifier at 30 mph, driver (sensitivity 1.0):**

| Wind Type | Modifier | Effect |
| --------- | -------- | ------ |
| Direct headwind | 0.85 | -15% distance |
| Crosswind | 1.0 | No distance change (only lateral push) |
| Direct tailwind | 1.10 | +10% distance |

### 5. Club Wind Sensitivity

| Club | Sensitivity | Rationale |
| ---- | ----------- | --------- |
| Driver | 1.0 | High trajectory, long hang time |
| Fairway Wood | 0.85 | Slightly lower trajectory |
| Iron | 0.7 | Medium trajectory |
| Wedge | 0.4 | High but short flight |
| Putter | 0.0 | Ground ball, no wind effect |

### 6. Wind Strength Descriptions

| Speed (mph) | Description |
| ----------- | ----------- |
| 0–5 | Calm |
| 5–10 | Light |
| 10–15 | Moderate |
| 15–20 | Strong |
| 20+ | Very Strong |

### 7. Wind Direction Compass

Wind direction is converted to 8-point compass using:
```
degrees = rad_to_deg(wind_direction) % 360
directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
index = round(degrees / 45.0) % 8
```

### Tuning Levers

| Parameter | Location | Current Value | Effect |
| --- | --- | --- | --- |
| Daily speed range | `wind_system.gd:31` | 2.0–20.0 mph | Wider = more wind variety |
| Max wind speed | `wind_system.gd:39` | 30.0 mph | Higher = stronger possible gusts |
| Drift rate range | `wind_system.gd:32` | -0.3–0.3 rad/hr | Higher = more wind direction shift |
| Speed fluctuation | `wind_system.gd:39` | +/-0.5 mph/hr | Higher = more gusty |
| Crosswind multiplier | `wind_system.gd:62` | 0.15 | Higher = more lateral push |
| Distance normalization | `wind_system.gd:58` | 20.0 tiles | Lower = more effect on shorter shots |
| Headwind max effect | `wind_system.gd:86` | 15% at 30 mph | Higher = more distance penalty |
| Tailwind max effect | `wind_system.gd:89` | 10% at 30 mph | Higher = more distance bonus |
| Distance modifier clamp | `wind_system.gd:91` | [0.75, 1.15] | Wider = more extreme wind effects |
| Club sensitivities | `golf_rules.gd:259-272` | See table | Lower = less wind effect for that club |
