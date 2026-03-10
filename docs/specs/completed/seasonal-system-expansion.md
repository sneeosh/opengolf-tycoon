# Seasonal System Expansion & Theme-Awareness — Product Spec

**Author:** Claude (Product)
**Date:** 2026-02-27
**Status:** Proposal
**Priority:** HIGH
**Version:** 0.1.0-alpha context

---

## Problem Statement

`SeasonSystem` and `SeasonalEvents` already provide a compact 28-day year (7 days per season) with spawn modifiers, maintenance cost scaling, weather probability tables, and 8 seasonal events. The `SeasonalCalendarPanel` UI is integrated. However, three significant gaps remain:

1. **No theme awareness.** A Desert course experiences the same winter as a Mountain course — identical spawn rate (0.3×), identical maintenance cost (1.1×), identical weather probabilities. In reality, Desert winters are mild golfing weather (peak season), while Mountain winters may close the course entirely.

2. **Hard season transitions.** Seasons change instantly at day boundaries. On day 7 it's Summer (1.4× spawns); on day 8 it's Fall (0.8× spawns). This 43% drop in golfer traffic happens overnight with no gradual transition.

3. **No economic depth from seasons.** Green fee tolerance doesn't vary by season (summer golfers should accept premium pricing; winter golfers are bargain-seekers). Tournament prestige doesn't vary (a fall invitational should carry more weight than a winter event).

---

## Design Principles

- **Theme is identity.** A Links course and a Desert course should feel fundamentally different across the year. Season modifiers should reinforce the chosen theme's character.
- **Smooth transitions.** Players should feel seasons changing gradually, not as a cliff edge.
- **Economic consequences.** Seasons should create economic pressure that rewards adaptive pricing and planning.
- **Preserve simplicity.** The 28-day year is a game design choice, not a bug. The spec improves depth within this compressed timeframe rather than extending it.

---

## Current System Analysis

### SeasonSystem (`scripts/systems/season_system.gd`)
- 4 seasons: SPRING, SUMMER, FALL, WINTER
- 7 days per season, 28 days per year
- `get_season(day)` — returns season enum from day number
- `get_day_in_season(day)` — returns 1–7
- `get_year(day)` — returns year number

### Current Modifiers (Theme-Agnostic)
| Modifier | Spring | Summer | Fall | Winter |
|----------|--------|--------|------|--------|
| Spawn rate | 0.9× | 1.4× | 0.8× | 0.3× |
| Maintenance cost | 1.1× | 1.4× | 0.7× | 1.1× |

### SeasonalEvents (`scripts/systems/seasonal_events.gd`)
- 8 events across 4 seasons (2 per season)
- Each event has: spawn modifier, revenue modifier, reputation bonus, duration
- Events fire on specific day-in-season (no advance notification)
- `get_active_event(day)` returns current event or null
- `get_upcoming_events(day, lookahead)` returns events within N days

### Weather Probability Tables
Different per season but not per theme. Example: Summer has 55% SUNNY, Winter has 15% SUNNY.

### CourseTheme Integration
`CourseTheme.get_gameplay_modifiers()` returns per-theme `wind_base_strength`, `distance_modifier`, `maintenance_cost_multiplier`, and `green_fee_baseline`. These are static — they don't vary by season.

---

## Feature Design

### 1. Theme-Aware Season Modifiers

Replace the global spawn/maintenance modifier tables with per-theme seasonal profiles:

**Spawn Rate Modifiers by Theme × Season:**

| Theme | Spring | Summer | Fall | Winter | Peak Season |
|-------|--------|--------|------|--------|-------------|
| PARKLAND | 0.9 | 1.4 | 0.8 | 0.3 | Summer |
| DESERT | 0.6 | 0.3 | 0.9 | 1.4 | Winter |
| LINKS | 0.8 | 1.3 | 0.9 | 0.4 | Summer |
| MOUNTAIN | 1.0 | 1.5 | 0.7 | 0.1 | Summer |
| CITY | 0.9 | 1.2 | 1.0 | 0.6 | Summer |
| RESORT | 1.0 | 1.3 | 0.8 | 1.2 | Summer/Winter |
| HEATHLAND | 0.8 | 1.3 | 0.9 | 0.3 | Summer |
| WOODLAND | 1.0 | 1.4 | 1.1 | 0.2 | Summer/Fall |
| TROPICAL | 1.1 | 0.8 | 1.2 | 1.3 | Winter |
| MARSHLAND | 0.7 | 0.9 | 0.8 | 0.4 | Fall |

**Design rationale:**
- Desert and Tropical have **inverted** peak seasons — winter is the best time to play
- Resort courses attract winter vacationers (ski resort area, snowbird destination)
- Mountain courses are nearly closed in winter (0.1× — occasional hardy golfers only)
- Woodland courses get a fall boost (foliage tourism)
- City courses have the most stable year-round traffic (urban convenience)

**Maintenance Cost Modifiers by Theme × Season:**

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

**Design rationale:**
- Desert has low maintenance year-round (minimal irrigation, hardy ground cover)
- Tropical has high maintenance in summer (explosive growth, pest control)
- Mountain has expensive winters (snow protection, course winterizing)
- Links has expensive winters (wind damage, drainage maintenance)

---

### 2. Gradual Season Transitions

Replace hard season cutoffs with a 2-day blending window:

**Transition mechanics:**
```
Day 6 of current season: 100% current season modifiers
Day 7 of current season: 66% current + 34% next season (transition begins)
Day 1 of next season:   34% previous + 66% current (transition continues)
Day 2 of next season:   100% current season modifiers (transition complete)
```

**Implementation:**
```gdscript
static func get_blended_spawn_modifier(day: int, theme: CourseTheme.Type) -> float:
    var season = get_season(day)
    var day_in_season = get_day_in_season(day)
    var current_mod = get_theme_spawn_modifier(theme, season)

    # Last day of season: blend toward next
    if day_in_season == DAYS_PER_SEASON:  # Day 7
        var next_season = (season + 1) % 4
        var next_mod = get_theme_spawn_modifier(theme, next_season)
        return lerp(current_mod, next_mod, 0.34)

    # First day of season: blend from previous
    if day_in_season == 1:
        var prev_season = (season + 3) % 4  # Wrap around
        var prev_mod = get_theme_spawn_modifier(theme, prev_season)
        return lerp(current_mod, prev_mod, 0.34)

    return current_mod
```

This produces a smooth 2-day ramp instead of an overnight cliff. The blending applies to:
- Spawn rate modifiers
- Maintenance cost modifiers
- Weather probability tables (blend between season tables)

---

### 3. Green Fee Tolerance by Season

Golfers' willingness to pay varies by season. Peak-season golfers accept premium pricing; off-season golfers are price-sensitive bargain seekers.

**Green fee tolerance modifier:**

| Season Profile | Tolerance | Effect |
|---------------|-----------|--------|
| Peak season | 1.3× | Golfers accept 30% higher fees without rating penalty |
| Shoulder season | 1.0× | Standard price sensitivity |
| Off season | 0.7× | Golfers expect 30% lower fees; high fees crater traffic |

**Integration with Value rating:**
The `CourseRatingSystem` Value component compares `green_fee × holes` against a "fair price." Apply the tolerance modifier to the fair price calculation:

```gdscript
var seasonal_tolerance = SeasonSystem.get_fee_tolerance(day, theme)
var fair_price = base_fair_price * seasonal_tolerance
```

This means a $100 fee that's "fair" in summer might be "overpriced" in winter (for non-desert themes), naturally pressuring the player to lower fees in slow seasons.

**Per-theme tolerance mapping:**
Uses the spawn modifier as a proxy for demand. High-demand seasons have high tolerance:
```gdscript
static func get_fee_tolerance(day: int, theme: CourseTheme.Type) -> float:
    var spawn_mod = get_blended_spawn_modifier(day, theme)
    # Map 0.1-1.5 spawn range to 0.7-1.3 tolerance range
    return clamp(0.5 + spawn_mod * 0.55, 0.7, 1.3)
```

---

### 4. Tournament Prestige by Season

Tournament reputation rewards scale by season to create strategic scheduling:

**Prestige multiplier by season profile:**

| Season Profile | Prestige Modifier | Rationale |
|---------------|-------------------|-----------|
| Peak season | 1.0× | Standard prestige |
| Shoulder (high-demand side) | 1.2× | "Classic" tournament season — fall in temperate, spring in desert |
| Shoulder (low-demand side) | 0.8× | Less prestige in declining season |
| Off season | 0.5× | Minimal prestige — few spectators, weak field |

**Per-theme prestige season mapping:**

| Theme | 1.2× Prestige Season | 0.5× Prestige Season |
|-------|----------------------|----------------------|
| PARKLAND | Fall | Winter |
| DESERT | Fall | Summer |
| LINKS | Summer | Winter |
| MOUNTAIN | Summer | Winter |
| CITY | Fall | — (0.8× minimum) |
| RESORT | Winter | — (0.8× minimum) |
| HEATHLAND | Summer | Winter |
| WOODLAND | Fall | Winter |
| TROPICAL | Winter | Summer |
| MARSHLAND | Fall | Winter |

**Integration:** Multiply tournament reputation reward by prestige modifier:
```gdscript
var base_rep = TournamentSystem.get_tier_data(tier).reputation_reward
var prestige = SeasonSystem.get_tournament_prestige(day, theme)
var final_rep = int(base_rep * prestige)
```

---

### 5. Theme-Aware Weather Probabilities

Extend the existing per-season weather tables with theme adjustments:

**Theme weather modifiers (applied to base season probabilities):**

| Theme | Wind Modifier | Rain Modifier | Notes |
|-------|--------------|---------------|-------|
| DESERT | 0.8× | 0.3× | Rarely rains, moderate wind |
| LINKS | 1.5× | 1.2× | Windy year-round, frequent rain |
| MOUNTAIN | 1.2× | 1.3× | Variable, more precipitation |
| TROPICAL | 0.7× | 1.8× | Calm but very rainy (monsoon season) |
| MARSHLAND | 0.9× | 1.4× | Damp, frequent rain |
| Others | 1.0× | 1.0× | Standard tables |

**Wind modifier** adjusts `WindSystem` base speed for the day:
```gdscript
var theme_wind_mod = CourseTheme.get_gameplay_modifiers(theme).wind_base_strength
# Already exists — extend with seasonal scaling
```

**Rain modifier** shifts weather probability thresholds. A 1.5× rain modifier makes rainy weather 50% more likely by compressing the SUNNY/PARTLY_CLOUDY portion of the cumulative probability table.

---

### 6. Seasonal Event Advance Notification

Currently, events just happen — no advance warning. Add a 2-day notification:

**Notification flow:**
```
Day N-2: "Charity Scramble in 2 days — expect 1.3× golfer traffic"
Day N-1: "Charity Scramble tomorrow!"
Day N:   "Charity Scramble today! (+30% golfers, +20% revenue)"
```

**Implementation:**
- In `advance_to_next_day()`, check `SeasonalEvents.get_upcoming_events(current_day + 1, 2)`
- For each upcoming event, emit `EventBus.ui_notification` with event details
- Add event icon/badge to `SeasonalCalendarPanel` for upcoming events

---

### 7. Mountain Course Winter Closure (Optional)

For Mountain theme, winter can trigger a **voluntary course closure** mechanic:

- When `spawn_modifier < 0.15` (effectively Mountain winter), show prompt: "Winter conditions are severe. Close course for the season? (Saves maintenance costs, reputation preserved)"
- If closed: maintenance costs drop to 20% of normal, no golfers spawn, reputation decay is halved
- Course auto-reopens on spring day 1
- Player can choose to stay open and serve the rare hardy golfer

This is an **optional** mechanic — the player is never forced to close. The prompt is informational.

---

## Data Model Changes

### SeasonSystem additions:
```gdscript
# Theme-aware modifier tables
const THEME_SPAWN_MODIFIERS: Dictionary = {
    CourseTheme.Type.PARKLAND: {Season.SPRING: 0.9, Season.SUMMER: 1.4, ...},
    CourseTheme.Type.DESERT: {Season.SPRING: 0.6, Season.SUMMER: 0.3, ...},
    ...
}

const THEME_MAINTENANCE_MODIFIERS: Dictionary = { ... }

const THEME_FEE_TOLERANCE: Dictionary = { ... }

const THEME_TOURNAMENT_PRESTIGE: Dictionary = { ... }
```

### Modified methods:
```gdscript
# Existing methods gain theme parameter:
static func get_spawn_modifier(season: int) -> float
# Becomes:
static func get_spawn_modifier(season: int, theme: CourseTheme.Type = CourseTheme.Type.PARKLAND) -> float

# New methods:
static func get_blended_spawn_modifier(day: int, theme: CourseTheme.Type) -> float
static func get_fee_tolerance(day: int, theme: CourseTheme.Type) -> float
static func get_tournament_prestige(day: int, theme: CourseTheme.Type) -> float
```

### Save/Load:
No changes needed — theme is already persisted in save data, and all modifiers are derived from theme + day.

---

## Algorithm Documentation

Create `docs/algorithms/seasonal-calendar.md` covering:
- Theme × season modifier tables (spawn, maintenance, fee tolerance, prestige)
- Gradual transition blending formula
- Weather probability theme adjustments
- Seasonal event calendar with modifier values
- Tuning guidance: how to adjust if a theme feels too punishing/forgiving in a season

Update `docs/algorithms/economy.md`:
- Add fee tolerance seasonal modifier to revenue calculations
- Document maintenance cost seasonal × theme interaction

---

## Implementation Sequence

```
Phase 1 (Theme-Aware Modifiers):
  1. Define THEME_SPAWN_MODIFIERS and THEME_MAINTENANCE_MODIFIERS tables
  2. Add theme parameter to get_spawn_modifier() and get_maintenance_modifier()
  3. Wire GameManager.current_theme into all modifier call sites
  4. Verify existing GolferManager spawn rate uses new theme-aware modifier

Phase 2 (Smooth Transitions):
  5. Implement get_blended_spawn_modifier() with 2-day window
  6. Apply blending to maintenance cost modifiers
  7. Apply blending to weather probability tables

Phase 3 (Economic Depth):
  8. Implement fee tolerance modifier
  9. Integrate with CourseRatingSystem Value component
  10. Implement tournament prestige modifier
  11. Wire into TournamentManager reputation calculation

Phase 4 (Polish):
  12. Seasonal event advance notifications (2-day)
  13. Theme-aware weather probability adjustments
  14. Mountain winter closure prompt (optional)
  15. Algorithm documentation
```

---

## Success Criteria

- Desert courses experience peak season in winter with high traffic, not the current low traffic
- Mountain courses have nearly empty winters (0.1× spawn) with high maintenance
- Season transitions feel gradual — no overnight traffic cliff
- Green fee sensitivity changes by season: premium pricing works in peak season, penalizes in off-season
- Tournament prestige rewards match thematic expectations (fall classics on Parkland, winter opens on Desert)
- Seasonal events show advance notifications 2 days before
- All 10 themes have distinct seasonal profiles that reinforce their identity

---

## Out of Scope

| Feature | Reason |
|---------|--------|
| Extending year beyond 28 days | Fundamental game rhythm change — needs separate evaluation |
| Visual season changes (foliage, snow) | Depends on Visual Polish spec |
| Season-specific golfer clothing | Depends on Golfer Visual Differentiation spec |
| Dynamic pricing UI (auto-adjust fees by season) | Player agency — they should decide manually |
| Climate change / multi-year weather trends | Too complex, limited gameplay value |
