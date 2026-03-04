# Seasonal Calendar & Theme-Aware Modifiers

## Plain English

OpenGolf Tycoon uses a compressed **28-day year** (7 days per season) to create economic pressure and variety. Each season affects golfer demand, maintenance costs, weather, tournament prestige, and green fee tolerance.

**Theme awareness** means a Desert course and a Mountain course experience seasons completely differently. Desert courses peak in winter (mild weather), while Mountain courses are nearly empty (snow). This makes the theme choice a fundamental strategic decision that affects the entire year's economics.

**Gradual transitions** prevent jarring overnight traffic cliffs. At season boundaries, modifiers blend over a 2-day window so the change feels natural.

**Green fee tolerance** varies with demand — peak-season golfers accept premium pricing, while off-season golfers are bargain-seekers. This pressures players to adjust pricing throughout the year.

**Tournament prestige** scales by season so that hosting a tournament in a thematically appropriate season (fall classic on Parkland, winter open on Desert) yields more reputation.

---

## Algorithm

### Calendar Structure

```
Year = 28 days
  Spring: Days 1-7
  Summer: Days 8-14
  Fall:   Days 15-21
  Winter: Days 22-28

get_season(day) = floor((day - 1) % 28 / 7)
get_day_in_season(day) = ((day - 1) % 7) + 1
get_year(day) = floor((day - 1) / 28) + 1
```

### Theme × Season Spawn Rate Modifiers

Multiplier applied to golfer spawn rate. Higher = more golfers.

| Theme | Spring | Summer | Fall | Winter | Peak Season |
|-------|--------|--------|------|--------|-------------|
| PARKLAND | 0.9 | **1.4** | 0.8 | 0.3 | Summer |
| DESERT | 0.6 | 0.3 | 0.9 | **1.4** | Winter |
| LINKS | 0.8 | **1.3** | 0.9 | 0.4 | Summer |
| MOUNTAIN | 1.0 | **1.5** | 0.7 | 0.1 | Summer |
| CITY | 0.9 | **1.2** | 1.0 | 0.6 | Summer |
| RESORT | 1.0 | **1.3** | 0.8 | 1.2 | Summer/Winter |
| HEATHLAND | 0.8 | **1.3** | 0.9 | 0.3 | Summer |
| WOODLAND | 1.0 | **1.4** | 1.1 | 0.2 | Summer/Fall |
| TROPICAL | 1.1 | 0.8 | 1.2 | **1.3** | Winter |
| MARSHLAND | 0.7 | 0.9 | 0.8 | 0.4 | Fall |

### Theme × Season Maintenance Cost Modifiers

Multiplier applied to terrain maintenance costs. Higher = more expensive.

| Theme | Spring | Summer | Fall | Winter |
|-------|--------|--------|------|--------|
| PARKLAND | 1.1 | 1.4 | 0.7 | 1.1 |
| DESERT | 0.8 | 0.6 | 0.8 | 1.0 |
| LINKS | 1.0 | 1.1 | 0.8 | 1.3 |
| MOUNTAIN | 1.2 | 1.3 | 0.8 | 1.5 |
| CITY | 1.0 | 1.2 | 0.9 | 1.0 |
| RESORT | 1.1 | 1.3 | 0.9 | 1.2 |
| HEATHLAND | 0.9 | 1.1 | 0.8 | 1.0 |
| WOODLAND | 1.0 | 1.2 | 1.0 | 0.9 |
| TROPICAL | 1.3 | 1.5 | 1.1 | 0.9 |
| MARSHLAND | 1.2 | 1.4 | 0.9 | 1.0 |

### Gradual Season Transitions

At season boundaries, modifiers blend over a 2-day window:

```
Day 6 of season: 100% current season
Day 7 of season: lerp(current, next, 0.34) = 66% current + 34% next
Day 1 of next:   lerp(current, prev, 0.34) = 66% current + 34% previous
Day 2 of next:   100% current season
```

Blending applies to:
- Spawn rate modifiers
- Maintenance cost modifiers
- Weather probability thresholds

### Green Fee Tolerance

Maps demand (spawn modifier) to a willingness-to-pay range:

```
fee_tolerance = clamp(0.5 + spawn_mod × 0.55, 0.7, 1.3)
```

| Effective Demand | Tolerance | Effect |
|-----------------|-----------|--------|
| 1.4× (peak summer) | ~1.27× | Golfers accept 27% higher fees |
| 1.0× (shoulder) | ~1.05× | Near-standard pricing |
| 0.3× (deep winter) | ~0.67→0.70× | Golfers expect 30% discount |

Integrated into `CourseRatingSystem._calculate_value_rating()`:
```
fair_price = base_fair_price × fee_tolerance
```

### Tournament Prestige

Reputation reward from tournaments is multiplied by seasonal prestige:

| Theme | 1.2× Season | 0.5× Season |
|-------|-------------|-------------|
| PARKLAND | Fall | Winter |
| DESERT | Fall | Summer |
| LINKS | Summer | Winter |
| MOUNTAIN | Summer | Winter |
| CITY | Fall | Winter (0.8×) |
| RESORT | Winter | — (0.8× min) |
| HEATHLAND | Summer | Winter |
| WOODLAND | Fall | Winter |
| TROPICAL | Winter | Summer |
| MARSHLAND | Fall | Winter |

```
final_rep = base_rep × prestige_modifier
```

### Theme Weather Modifiers

Applied on top of seasonal weather probability tables:

| Theme | Wind Mod | Rain Mod | Notes |
|-------|----------|----------|-------|
| DESERT | 0.8× | 0.3× | Rarely rains |
| LINKS | 1.5× | 1.2× | Windy, wet |
| MOUNTAIN | 1.2× | 1.3× | Variable weather |
| TROPICAL | 0.7× | 1.8× | Calm but very rainy |
| MARSHLAND | 0.9× | 1.4× | Damp |
| Others | 1.0× | 1.0× | Standard |

**Wind modifier**: Scales `WindSystem` base speed on daily generation.

**Rain modifier**: Adjusts weather cumulative probability thresholds. Converts to individual probabilities, scales rain categories (LIGHT_RAIN, RAIN, HEAVY_RAIN) by the modifier, then normalizes back to 1.0.

### Seasonal Events (8 events, 2 per season)

| Event | Season | Day | Revenue | Spawn | Rep | Duration |
|-------|--------|-----|---------|-------|-----|----------|
| Spring Opening Day | Spring | 1 | 1.5× | 1.5× | +2 | 1 day |
| Charity Scramble | Spring | 4 | 1.2× | 1.3× | +3 | 1 day |
| Peak Season | Summer | 1 | 1.5× | 1.0× | 0 | 3 days |
| Junior Golf Day | Summer | 5 | 0.8× | 1.8× | +2 | 1 day |
| Fall Classic | Fall | 2 | 1.3× | 1.4× | +5 | 2 days |
| Twilight Golf Week | Fall | 6 | 0.9× | 1.6× | +1 | 1 day |
| Winter Open | Winter | 3 | 1.0× | 0.8× | +1 | 1 day |
| Maintenance Week | Winter | 6 | 0.5× | 0.3× | 0 | 1 day |

**Advance notifications**: 2-day lookahead on each new day. Events are announced at N-2, N-1, and day N.

---

## Tuning Levers

| Parameter | File | Current Value | Effect of Increasing |
|-----------|------|---------------|---------------------|
| `THEME_SPAWN_MODIFIERS` | `season_system.gd` | Per-theme 4-season table | More/fewer golfers per theme-season |
| `THEME_MAINTENANCE_MODIFIERS` | `season_system.gd` | Per-theme 4-season table | Higher/lower maintenance costs |
| `THEME_TOURNAMENT_PRESTIGE` | `season_system.gd` | Per-theme 4-season table | More/less reputation from tournaments |
| `THEME_WEATHER_MODIFIERS` | `season_system.gd` | Per-theme wind/rain dict | More wind/rain for specific themes |
| Blend factor (0.34) | `season_system.gd` | 0.34 | Smoother transitions (closer to 0.5 = more blending) |
| Fee tolerance range | `season_system.gd` | 0.7–1.3 | Wider range = more pricing pressure |
| Fee tolerance formula | `season_system.gd` | `0.5 + spawn × 0.55` | Steeper slope = more demand-sensitive pricing |
| Notification lookahead | `game_manager.gd` | 2 days | Earlier/later advance warnings |
