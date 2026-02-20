# Day/Night Cycle

> **Source:** `scripts/systems/day_night_system.gd` and `scripts/autoload/game_manager.gd` (lines 124–196)

## Plain English

The day/night system creates visual time-of-day effects by tinting the entire scene through a CanvasModulate node. The course operates from 6 AM to 8 PM (14 hours of play), with sunrise and sunset transitions adding visual atmosphere.

### Time Progression

Game time advances in real time: **1 real minute = 1 game hour** at normal speed. Fast and ultra speed multiply this accordingly. The game clock ticks every frame, and each integer hour boundary triggers wind drift and weather updates.

### Visual Tinting

The system blends two tint layers:
1. **Time-of-day tint** — A smooth color gradient that follows the sun: dark blue at night, warm orange at sunrise/sunset, and full white during daytime.
2. **Weather tint** — An overlay that darkens the scene during cloudy/rainy conditions.

The weather tint smoothly interpolates toward its target (delta * 2.0 per frame) to prevent jarring color jumps when weather changes.

### Course Hours

The course opens at 6 AM and closes at 8 PM. A closing warning fires at 7 PM. After closing, golfers finish their current hole but don't start new ones. The day doesn't advance automatically — it waits for the end-of-day summary to be acknowledged before starting the next morning.

---

## Algorithm

### 1. Time Progression

```
HOURS_PER_DAY  = 24.0
COURSE_OPEN    = 6.0    # 6 AM
COURSE_CLOSE   = 20.0   # 8 PM

# Per frame:
time_multiplier = float(game_speed)    # NORMAL=1, FAST=2, ULTRA=4
current_hour += (delta * time_multiplier) / 60.0

# 1 real minute = 1 game hour at NORMAL
# 1 real minute = 2 game hours at FAST
# 1 real minute = 4 game hours at ULTRA
```

### 2. Time-of-Day Tint Colors

```
Deep Night   (< 5 AM):    Color(0.15, 0.15, 0.30)   # Dark blue
Sunrise      (5-7 AM):    Transition through 3 phases
    5:00 AM → 6:00 AM:    night_color → dawn_color    # Dark blue → warm orange
    6:00 AM → 7:00 AM:    dawn_color → day_color      # Warm orange → white
Daytime      (7 AM-5 PM): Color(1.0, 1.0, 1.0)       # Full white (no tint)
Sunset       (5-8 PM):    Transition through 3 phases
    5:00 PM → 6:30 PM:    day_color → sunset_color    # White → warm orange
    6:30 PM → 8:00 PM:    sunset_color → dusk_color   # Warm orange → evening blue
Night        (8 PM+):     Transition over 4 hours
    8:00 PM → 12:00 AM:   dusk_color → night_color    # Evening blue → dark blue
```

### 3. Sunrise Transition (5 AM – 7 AM)

```
t = (hour - 5.0) / 2.0    # 0.0 at 5 AM, 1.0 at 7 AM

night_color = Color(0.15, 0.15, 0.3)
dawn_color  = Color(1.0, 0.85, 0.7)     # Warm orange
day_color   = Color.WHITE

if t < 0.5:
    tint = night_color.lerp(dawn_color, t * 2.0)
else:
    tint = dawn_color.lerp(day_color, (t - 0.5) * 2.0)
```

### 4. Sunset Transition (5 PM – 8 PM)

```
t = (hour - 17.0) / 3.0    # 0.0 at 5 PM, 1.0 at 8 PM

day_color    = Color.WHITE
sunset_color = Color(1.0, 0.75, 0.5)     # Warm sunset orange
dusk_color   = Color(0.3, 0.25, 0.45)    # Evening blue

if t < 0.5:
    tint = day_color.lerp(sunset_color, t * 2.0)
else:
    tint = sunset_color.lerp(dusk_color, (t - 0.5) * 2.0)
```

### 5. Night Transition (8 PM – midnight)

```
t = clamp((hour - 20.0) / 4.0, 0.0, 1.0)

dusk_color  = Color(0.3, 0.25, 0.45)
night_color = Color(0.15, 0.15, 0.3)

tint = dusk_color.lerp(night_color, t)
```

### 6. Weather Tint Integration

```
# Smooth interpolation toward target weather tint
weather_tint = weather_tint.lerp(target_weather_tint, clamp(delta * 2.0, 0.0, 1.0))

# Blend with time-of-day tint
weather_strength = weather_tint.a       # Alpha channel = effect strength
weather_color    = Color(weather_tint.r, weather_tint.g, weather_tint.b, 1.0)

final_tint = time_tint.lerp(time_tint * weather_color, weather_strength)
```

The multiplication (`time_tint * weather_color`) means weather darkening compounds with time-of-day darkening — a rainy sunset is darker than either effect alone.

### 7. Course Hours & Day Transitions

```
# Closing warning at 7 PM
if hour >= COURSE_CLOSE - 1.0 and not announced:
    emit course_closing signal

# End of day at 8 PM
if hour >= COURSE_CLOSE and not triggered:
    mark end_of_day_triggered

# Day doesn't auto-advance — waits for advance_to_next_day() call
# New day resets to 6 AM
```

### Visual Timeline

```
Time  |  Brightness  |  Color
------+--------------+--------
5 AM  |  15%         |  Dark blue
6 AM  |  ~50%        |  Warm orange (dawn)
7 AM  |  100%        |  White (full day)
 ...  |  100%        |  White
5 PM  |  100%        |  White
6:30  |  ~75%        |  Warm orange (sunset)
8 PM  |  ~30%        |  Evening blue
12 AM |  15%         |  Dark blue
```

### Tuning Levers

| Parameter | Location | Current Value | Effect |
| --- | --- | --- | --- |
| Course open hour | `game_manager.gd:126` | 6.0 (6 AM) | Earlier = longer play day |
| Course close hour | `game_manager.gd:127` | 20.0 (8 PM) | Later = longer play day |
| Closing warning offset | `game_manager.gd:184` | 1.0 hour before close | Earlier = more warning time |
| Time scale | `game_manager.gd:171` | 1 min = 1 hour at 1x | Higher = faster days |
| Night color | `day_night_system.gd:60` | (0.15, 0.15, 0.3) | Darker = more dramatic nights |
| Dawn color | `day_night_system.gd:65` | (1.0, 0.85, 0.7) | Warmer = more orange sunrise |
| Sunset color | `day_night_system.gd:78` | (1.0, 0.75, 0.5) | Warmer = more orange sunset |
| Dusk color | `day_night_system.gd:79` | (0.3, 0.25, 0.45) | Darker = more dramatic dusk |
| Weather tint speed | `day_night_system.gd:37` | delta * 2.0 | Higher = faster weather tint changes |
| Sunrise duration | `day_night_system.gd:63` | 2 hours (5-7 AM) | Longer = more gradual sunrise |
| Sunset duration | `day_night_system.gd:76` | 3 hours (5-8 PM) | Longer = more gradual sunset |
