# Seasonal Calendar & Theme-Aware Modifiers

## Plain English

The game uses a compressed **28-day year** (7 days per season). Each of the 10 course themes has distinct seasonal profiles — a Desert course peaks in winter while a Mountain course peaks in summer. Seasons affect golfer demand, maintenance costs, fee tolerance, tournament prestige, and weather.

All modifiers use **2-day blending** at season boundaries so transitions are gradual, not overnight cliffs.

## Algorithm

### Year Structure
- 4 seasons: Spring (days 1-7), Summer (8-14), Fall (15-21), Winter (22-28)
- `season = (day - 1) / 7 % 4`
- `day_in_season = (day - 1) % 7 + 1`
- `year = (day - 1) / 28 + 1`

### Transition Blending (2-day window)
```
Day 6 of season:  100% current
Day 7 of season:  lerp(current, next, 0.34)
Day 1 of next:    lerp(current, previous, 0.34)
Day 2+ of season: 100% current
```

### Spawn Rate Modifiers (theme × season)

| Theme | Spring | Summer | Fall | Winter | Peak |
|-------|--------|--------|------|--------|------|
| Parkland | 0.9 | 1.4 | 0.8 | 0.3 | Summer |
| Desert | 0.6 | 0.3 | 0.9 | 1.4 | Winter |
| Links | 0.8 | 1.3 | 0.9 | 0.4 | Summer |
| Mountain | 1.0 | 1.5 | 0.7 | 0.1 | Summer |
| City | 0.9 | 1.2 | 1.0 | 0.6 | Summer |
| Resort | 1.0 | 1.3 | 0.8 | 1.2 | Summer/Winter |
| Heathland | 0.8 | 1.3 | 0.9 | 0.3 | Summer |
| Woodland | 1.0 | 1.4 | 1.1 | 0.2 | Summer/Fall |
| Tropical | 1.1 | 0.8 | 1.2 | 1.3 | Winter |
| Marshland | 0.7 | 0.9 | 0.8 | 0.4 | Fall |

### Maintenance Cost Modifiers (theme × season)

| Theme | Spring | Summer | Fall | Winter |
|-------|--------|--------|------|--------|
| Parkland | 1.1 | 1.4 | 0.7 | 1.1 |
| Desert | 0.8 | 0.6 | 0.8 | 1.0 |
| Links | 1.0 | 1.1 | 0.8 | 1.3 |
| Mountain | 1.2 | 1.3 | 0.8 | 1.5 |
| City | 1.0 | 1.2 | 0.9 | 1.0 |
| Resort | 1.1 | 1.3 | 0.9 | 1.2 |
| Heathland | 0.9 | 1.1 | 0.8 | 1.0 |
| Woodland | 1.0 | 1.2 | 1.0 | 0.9 |
| Tropical | 1.3 | 1.5 | 1.1 | 0.9 |
| Marshland | 1.2 | 1.4 | 0.9 | 1.0 |

### Fee Tolerance
Maps spawn modifier to golfer willingness to pay:
```
fee_tolerance = clamp(0.5 + spawn_mod * 0.55, 0.7, 1.3)
```
- 1.3 = peak season, golfers accept 30% higher fees
- 1.0 = normal pricing expectations
- 0.7 = off season, golfers expect 30% lower fees

Applied in CourseRatingSystem Value rating: `fair_price *= fee_tolerance`

### Tournament Prestige
Per-theme prestige season (1.2× reputation) and off-season (0.5×):

| Theme | 1.2× Season | 0.5× Season |
|-------|-------------|-------------|
| Parkland | Fall | Winter |
| Desert | Fall | Summer |
| Links | Summer | Winter |
| Mountain | Summer | Winter |
| City | Fall | Winter |
| Resort | Winter | Summer |
| Heathland | Summer | Winter |
| Woodland | Fall | Winter |
| Tropical | Winter | Summer |
| Marshland | Fall | Winter |

### Theme Weather Modifiers
Applied to seasonal weather probability thresholds:

| Theme | Wind | Rain |
|-------|------|------|
| Desert | 0.8× | 0.3× |
| Links | 1.5× | 1.2× |
| Mountain | 1.2× | 1.3× |
| Tropical | 0.7× | 1.8× |
| Marshland | 0.9× | 1.4× |
| Others | 1.0× | 1.0× |

Rain modifier compresses sunny/clear probability thresholds, making rainy weather more likely.

### Seasonal Events (8 total, 2 per season)

| Event | Season | Day | Duration | Revenue | Spawns | Rep |
|-------|--------|-----|----------|---------|--------|-----|
| Spring Opening Day | Spring | 1 | 1 | 1.5× | 1.5× | +2 |
| Charity Scramble | Spring | 4 | 1 | 1.2× | 1.3× | +3 |
| Peak Season | Summer | 1 | 3 | 1.5× | 1.0× | +0 |
| Junior Golf Day | Summer | 5 | 1 | 0.8× | 1.8× | +2 |
| Fall Classic | Fall | 2 | 2 | 1.3× | 1.4× | +5 |
| Twilight Golf Week | Fall | 6 | 1 | 0.9× | 1.6× | +1 |
| Winter Open | Winter | 3 | 1 | 1.0× | 0.8× | +1 |
| Maintenance Week | Winter | 6 | 1 | 0.5× | 0.3× | +0 |

2-day advance notifications appear in the event feed.

## Integration Points

| System | Method | File |
|--------|--------|------|
| Golfer spawning | `SeasonSystem.get_spawn_modifier(season, theme)` | `golfer_manager.gd` |
| Maintenance costs | `SeasonSystem.get_maintenance_modifier(season, theme)` | `game_manager.gd` |
| Value rating | `SeasonSystem.get_fee_tolerance(day, theme)` | `course_rating_system.gd` |
| Tournament reputation | `SeasonSystem.get_tournament_prestige(day, theme)` | `tournament_manager.gd` |
| Weather generation | `SeasonSystem.get_blended_weather_weights(day, theme)` | `weather_system.gd` |

## Tuning Levers

| Parameter | Location | Current Value | Effect |
|-----------|----------|---------------|--------|
| Spawn modifier tables | `season_system.gd` THEME_SPAWN_MODIFIERS | 0.1–1.5 per theme | Higher = more golfers in that season |
| Maintenance modifier tables | `season_system.gd` THEME_MAINTENANCE_MODIFIERS | 0.6–1.5 per theme | Higher = more expensive upkeep |
| Fee tolerance range | `season_system.gd` get_fee_tolerance() | 0.7–1.3 | Wider range = more seasonal pricing pressure |
| Tournament prestige tables | `season_system.gd` THEME_TOURNAMENT_PRESTIGE | 0.5–1.2 | Higher = more reputation from tournaments |
| Transition blend factor | `season_system.gd` TRANSITION_BLEND_FACTOR | 0.34 | Higher = smoother transitions (0.5 = full blend) |
| Event advance warning | `game_manager.gd` advance_to_next_day() | 2 days | How far ahead to warn about upcoming events |
