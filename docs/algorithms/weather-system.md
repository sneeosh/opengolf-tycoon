# Weather System

> **Source:** `scripts/systems/weather_system.gd`

## Plain English

Weather changes daily and throughout the day using a **state machine** pattern. Each morning, the weather is generated based on seasonal weights — summer skews toward sunny, winter skews toward rain. Throughout the day, weather can transition between states following realistic patterns (sunny -> partly cloudy -> cloudy -> rain, and back).

Weather affects gameplay in three ways:

1. **Golfer spawn rate** — Bad weather discourages golfers from showing up. Heavy rain reduces spawning to just 30% of normal.

2. **Shot accuracy** — Rain makes aiming harder, with a progressive penalty from 95% (light rain) to 85% (heavy rain) accuracy modifier.

3. **Visual tinting** — Each weather type applies a color tint to the sky/scene via the Day/Night System (see [day-night-cycle.md](day-night-cycle.md)).

Weather transitions happen gradually — the system lerps between states over time rather than snapping instantly. A weather state lasts 3–8 hours before potentially changing, with only a 30% chance of actually changing when the duration expires.

The transition patterns are designed to feel natural: sunny weather can only become partly cloudy (not jump straight to heavy rain), and heavy rain tends to ease up to regular rain. This creates realistic weather arcs over the course of a day.

---

## Algorithm

### 1. Weather Types & Base Intensities

| Weather Type | Intensity | Spawn Rate | Accuracy | Sky Tint (RGB, Alpha) |
| ------------ | --------- | ---------- | -------- | --------------------- |
| SUNNY | 0.0 | 100% | 100% | (1.0, 1.0, 1.0, 0.0) |
| PARTLY_CLOUDY | 0.1 | 100% | 100% | (0.95, 0.95, 0.95, 0.1) |
| CLOUDY | 0.25 | 90% | 100% | (0.85, 0.85, 0.9, 0.2) |
| LIGHT_RAIN | 0.4 | 70% | 95% | (0.75, 0.78, 0.85, 0.3) |
| RAIN | 0.6 | 50% | 90% | (0.65, 0.68, 0.75, 0.35) |
| HEAVY_RAIN | 0.85 | 30% | 85% | (0.55, 0.58, 0.65, 0.4) |

### 2. Daily Weather Generation

```
season = SeasonSystem.get_season(current_day)
thresholds = SeasonSystem.get_weather_weights(season)    # Cumulative thresholds
roll = randf()

if roll < thresholds[0]:       SUNNY
elif roll < thresholds[1]:     PARTLY_CLOUDY
elif roll < thresholds[2]:     CLOUDY
elif roll < thresholds[3]:     LIGHT_RAIN
elif roll < thresholds[4]:     RAIN
else:                          HEAVY_RAIN

weather_duration = randf_range(3.0, 8.0)  # Hours before potential change
```

### 3. Hourly Update

```
hours_in_current_weather += hours_elapsed

if hours_in_current_weather >= weather_duration:
    maybe_change_weather()

# Handle smooth transitions
if transition_progress < 1.0:
    transition_progress = min(transition_progress + TRANSITION_SPEED * hours_elapsed, 1.0)
    intensity = lerp(current_intensity, target_intensity, transition_progress)
    if transition_progress >= 0.8:
        weather_type = target_weather    # Snap type when mostly done
```

### 4. Weather Change Logic

```
TRANSITION_SPEED = 0.5    # Per hour (full transition in ~2 hours)
change_chance = 0.3       # 30% chance when duration expires

if randf() > change_chance:
    # Weather stays the same, reset duration
    weather_duration = randf_range(2.0, 6.0)
    return

# Otherwise, transition to a new weather state
```

### 5. Weather State Transitions

```
SUNNY →
    70% → PARTLY_CLOUDY
    30% → stay SUNNY

PARTLY_CLOUDY →
    40% → SUNNY
    40% → CLOUDY
    20% → stay PARTLY_CLOUDY

CLOUDY →
    30% → PARTLY_CLOUDY
    40% → LIGHT_RAIN
    30% → stay CLOUDY

LIGHT_RAIN →
    40% → CLOUDY
    30% → RAIN
    30% → stay LIGHT_RAIN

RAIN →
    40% → LIGHT_RAIN
    20% → HEAVY_RAIN
    40% → stay RAIN

HEAVY_RAIN →
    70% → RAIN              # Heavy rain tends to let up
    30% → stay HEAVY_RAIN
```

Note: Weather can never skip steps (e.g., sunny can't jump directly to rain).

### 6. Spawn Rate Modifiers

```
SUNNY:         1.0    (100%)
PARTLY_CLOUDY: 1.0    (100%)
CLOUDY:        0.9    (90%)
LIGHT_RAIN:    0.7    (70%)
RAIN:          0.5    (50%)
HEAVY_RAIN:    0.3    (30%)
```

### 7. Accuracy Modifiers

```
SUNNY / PARTLY_CLOUDY / CLOUDY: 1.0    (no penalty)
LIGHT_RAIN:                     0.95   (-5%)
RAIN:                           0.90   (-10%)
HEAVY_RAIN:                     0.85   (-15%)
```

### Tuning Levers

| Parameter | Location | Current Value | Effect |
| --- | --- | --- | --- |
| Weather duration range | `weather_system.gd:67` | 3.0–8.0 hours | Shorter = more frequent changes |
| Post-change duration | `weather_system.gd:91,101` | 2.0–6.0 hours | Duration of new weather state |
| Transition speed | `weather_system.gd:22` | 0.5 per hour | Higher = faster visual transitions |
| Change chance | `weather_system.gd:88` | 30% | Higher = more weather changes |
| State transition probabilities | `weather_system.gd:103-146` | See table | Controls weather flow patterns |
| Spawn rate modifiers | `weather_system.gd:176-190` | See table | How much weather reduces golfer spawns |
| Accuracy modifiers | `weather_system.gd:193-203` | See table | How much rain hurts shot accuracy |
| Sky tint colors | `weather_system.gd:206-220` | See table | Visual darkening per weather type |
