# Seasonal Calendar & Event System — Product Spec

**Author:** Claude (Product)
**Date:** 2026-02-27
**Status:** Proposal
**Milestone:** Beta Milestone 2
**Priority:** P1 — Core Feature
**Est. Scope:** Medium

---

## Problem Statement

Every day in OpenGolf Tycoon is identical. Same weather probabilities, same golfer spawn rates, same maintenance costs, same tournament viability. There is no concept of time beyond the day counter. This creates two problems:

1. **Flat mid-to-late game** — Once a player optimizes their course, the daily cycle becomes monotonous. Revenue stabilizes, costs are predictable, and there's no reason to change strategy.
2. **Missing tycoon staple** — Seasonal variation is a genre expectation. RollerCoaster Tycoon has rainy months that kill revenue. Two Point Hospital has epidemics. SimGolf had seasons. Without it, OpenGolf Tycoon lacks the natural revenue peaks and troughs that force players to plan ahead, save cash reserves, and time their investments.

---

## Design Principles

- **Predictable, not punishing.** Seasons follow a fixed calendar. Players can see what's coming and plan accordingly. No random "disaster months."
- **Theme-aware.** A desert course shouldn't suffer the same winter as a mountain course. Themes already have gameplay modifiers — seasons should stack with them.
- **Gradual transitions.** No jarring cutoffs between seasons. Modifiers blend over transition windows to feel natural.
- **Data-driven.** All seasonal values live in a JSON file for easy tuning without code changes.

---

## Background

### Current Systems Affected

| System | Current Behavior | Seasonal Change |
|--------|-----------------|-----------------|
| **GolferManager** | Fixed spawn rate based on weather/reputation/marketing | Multiply by seasonal spawn modifier |
| **WeatherSystem** | Fixed probability tables for all weather types | Season shifts rain/severe probabilities |
| **GameManager** | Fixed daily maintenance costs | Season multiplier on maintenance |
| **TournamentSystem** | Fixed prestige calculation | Season affects prestige bonus |
| **DayNightSystem** | 6 AM – 8 PM fixed hours | No change (post-beta: shorter winter days) |

### Prior Art

The `phase4-seasons-calendar` branches in the repo attempted a seasonal system but were rejected because they deleted Phase 3 systems (LandManager, StaffManager, MarketingManager). This spec describes a **standalone addition** that integrates cleanly with all existing systems.

---

## User Stories

1. **As a player**, I want to see the current season and month so I understand where I am in the yearly cycle.
2. **As a player**, I want summer to bring more golfers and winter to bring fewer, so I need to save money during good months to survive lean months.
3. **As a player**, I want weather patterns to change by season (more rain in spring, hot/dry in summer) so the course feels different throughout the year.
4. **As a player**, I want maintenance costs to vary by season so staffing decisions change throughout the year.
5. **As a player**, I want occasional holiday bonus events with advance notice so I can prepare (raise green fees, run marketing campaigns).
6. **As a Desert/Resort player**, I want winter to be less punishing since those courses are warm year-round.
7. **As a Mountain player**, I want the option to close the course in winter and skip ahead rather than bleed money with near-zero golfers.

---

## Functional Requirements

### FR-1: Calendar System

#### Year Structure
- **360 days** per year = 4 seasons × 90 days each
- **12 months** of 30 days each (named Month 1–12 or generic names: Early Spring, Mid Spring, Late Spring, etc.)
- **Seasons:**
  - Spring: Days 1–90
  - Summer: Days 91–180
  - Fall: Days 181–270
  - Winter: Days 271–360
- Day counter resets to 1 at start of each new year. Year counter increments.
- Existing `GameManager.current_day` continues to increment globally; `SeasonalCalendar` derives season/month from `current_day % 360`.

#### Season Transitions
- Modifiers blend over a **10-day transition window** at each season boundary.
- During transition, modifiers linearly interpolate between outgoing and incoming season values.
- Example: Days 85–95 blend Spring→Summer modifiers. Day 85 = 100% Spring. Day 90 = 50/50. Day 95 = 100% Summer.

### FR-2: Seasonal Modifiers

#### Base Modifier Table

| Modifier | Spring | Summer | Fall | Winter |
|----------|--------|--------|------|--------|
| Golfer spawn rate | 0.8× | 1.2× | 1.0× | 0.5× |
| Rain chance adjustment | +20% | -10% | -5% | +10% |
| Severe weather chance | +10% | +5% | -10% | +15% |
| Maintenance cost | 1.2× | 1.0× | 1.0× | 0.7× |
| Green fee tolerance | 0.9× | 1.2× | 1.0× | 0.7× |
| Tournament prestige bonus | 1.0× | 1.0× | 1.3× | 0.5× |

#### Modifier Application
- **Spawn rate**: Stacks multiplicatively with existing modifiers (weather × reputation × marketing × seasonal). Applied in `GolferManager` spawn calculation.
- **Weather adjustments**: Added to base probability in `WeatherSystem` state machine transition weights. Clamped to 0–100%.
- **Maintenance cost**: Multiplied against `GameManager._calculate_daily_costs()` maintenance component.
- **Green fee tolerance**: Scales the fee-sensitivity threshold in golfer spawn decisions. Higher tolerance = golfers accept higher fees.
- **Tournament prestige**: Multiplied against prestige calculation in `TournamentSystem`.

### FR-3: Theme-Aware Season Scaling

Themes modulate seasonal modifiers, primarily softening or intensifying winter:

| Theme | Winter Spawn | Winter Maintenance | Winter Special |
|-------|-------------|-------------------|----------------|
| **Parkland** | 0.5× (standard) | 0.7× (standard) | — |
| **City** | 0.5× (standard) | 0.7× (standard) | — |
| **Desert** | 0.75× (halved penalty) | 0.7× (no increase) | Summer heat penalty: spawn 0.9× |
| **Resort** | 0.75× (halved penalty) | 0.7× (standard) | Green fee tolerance stays 1.0× |
| **Links** | 0.5× (standard) | 0.7× (standard) | Winter wind +30% base strength |
| **Mountain** | 0.1× (near-closed) | 0.5× (reduced) | "Close for season" option (see FR-4) |
| **Heathland** | 0.5× (standard) | 0.7× (standard) | — |
| **Woodland** | 0.5× (standard) | 0.7× (standard) | Fall foliage bonus: +10% green fee tolerance |
| **Tropical** | 0.75× (halved penalty) | 0.7× (standard) | Monsoon season in fall: +25% rain chance |
| **Marshland** | 0.5× (standard) | 1.0× (higher) | Spring flooding: maintenance 1.4× |

Theme overrides are defined in the seasonal calendar JSON data file alongside base modifiers.

### FR-4: Mountain Course Winter Closure

- When theme is MOUNTAIN and season transitions to Winter, show a notification: "Winter is approaching. Would you like to close the course for the season?"
- **Close for season**: Skip to Day 1 of next Spring. During skip:
  - No golfer spawning
  - Reduced maintenance costs (50% of winter rate)
  - Staff on payroll still costs money (incentivizes firing seasonal staff)
  - Time advances at Ultra speed with minimal processing
- **Stay open**: Play through winter with 0.1× spawn rate. Viable for desperate players who need any revenue.
- Closing is optional and prompted once per winter season.

### FR-5: Holiday Events

#### Event Schedule
3–5 fixed events per year, evenly distributed:

| Event | Day | Duration | Effect |
|-------|-----|----------|--------|
| Spring Open | Day 30 | 3 days | 2.0× golfer spawn, +10% green fee tolerance |
| Summer Classic | Day 120 | 3 days | 2.0× golfer spawn, +15% green fee tolerance |
| Golf Festival | Day 200 | 2 days | 1.8× golfer spawn, +20% green fee tolerance |
| Charity Open | Day 250 | 2 days | 1.5× golfer spawn, reputation gain +50% |
| Holiday Weekend | Day 340 | 3 days | 1.5× golfer spawn (even in winter) |

#### Event Behavior
- **Advance notice**: Notification 5 days before event: "Spring Open in 5 days! Expect a surge of golfers."
- **Reminder**: Notification 1 day before: "Spring Open starts tomorrow!"
- **Active indicator**: During event, HUD shows event name and remaining days.
- **Spawn modifier**: Event spawn multiplier stacks with seasonal modifier.
- **No mandatory action**: Events happen automatically. Smart players prepare (adjust fees, run marketing, ensure buildings are placed) but passive players still benefit.

### FR-6: UI Requirements

#### Calendar Widget (Top HUD Bar)
- Displays: Season icon (colored circle or symbol), month name, day of year
- Season color coding:
  - Spring: Green (#4a8c3f)
  - Summer: Yellow/Gold (#FFD700)
  - Fall: Orange (#D2691E)
  - Winter: Blue (#4682B4)
- Click to expand: Shows upcoming events in next 30 days
- Fits alongside existing top bar elements (Money, Day/Time, Reputation, Weather, Wind)

#### Season Transition Notification
- Full-width banner at top of screen: "Summer has arrived! Peak golf season is here."
- Auto-dismisses after 5 seconds or click to dismiss
- Each season has a unique message and color

#### End-of-Day Summary Addition
- Show current season name in the daily summary header
- Show any active seasonal modifiers that differ from 1.0× (e.g., "Summer: +20% golfer traffic, Green fees tolerated +20%")
- Show holiday bonus if active

#### Event Notification
- Toast notification for advance notice (5 days out, 1 day out)
- Banner during active event with event name and countdown

---

## Technical Requirements

### New Class: `SeasonalCalendar`

```
Class: SeasonalCalendar (RefCounted)
Owner: GameManager (instance variable)

Public API:
  get_season() -> String              # "spring", "summer", "fall", "winter"
  get_season_enum() -> int            # 0-3
  get_month() -> int                  # 1-12
  get_month_name() -> String          # "Early Spring", etc.
  get_day_of_year() -> int            # 1-360
  get_year() -> int                   # 1+
  get_seasonal_modifier(key: String) -> float  # e.g., "spawn_rate" → 1.2
  get_upcoming_events(days_ahead: int) -> Array  # events in next N days
  is_event_active() -> bool
  get_active_event() -> Dictionary    # {name, remaining_days, modifiers}
  advance_day()                       # called by GameManager at end of day
```

### Data File: `data/seasonal_calendar.json`

```json
{
  "year_length": 360,
  "season_length": 90,
  "transition_days": 10,
  "seasons": {
    "spring": {
      "spawn_rate": 0.8,
      "rain_chance_adjust": 0.20,
      "severe_chance_adjust": 0.10,
      "maintenance_cost": 1.2,
      "green_fee_tolerance": 0.9,
      "tournament_prestige": 1.0
    },
    ...
  },
  "theme_overrides": {
    "desert": { "winter": { "spawn_rate": 0.75 } },
    ...
  },
  "events": [
    { "name": "Spring Open", "day": 30, "duration": 3, "spawn_multiplier": 2.0, "fee_tolerance_bonus": 0.10 },
    ...
  ]
}
```

### EventBus Signals

```gdscript
signal season_changed(season: String)           # Emitted on season transition
signal holiday_started(event_name: String)       # Emitted when event begins
signal holiday_ended(event_name: String)         # Emitted when event ends
signal holiday_approaching(event_name: String, days_away: int)  # 5-day and 1-day warnings
```

### Integration Points

| System | Change Required |
|--------|----------------|
| **GameManager** | Hold `SeasonalCalendar` instance. Call `advance_day()` in end-of-day. Apply maintenance modifier in `_calculate_daily_costs()`. |
| **GolferManager** | Query `get_seasonal_modifier("spawn_rate")` in spawn calculation. Multiply with existing modifiers. |
| **WeatherSystem** | Query rain/severe chance adjustments. Add to base transition probabilities. |
| **TournamentSystem** | Query prestige modifier. Apply in prestige calculation. |
| **SaveManager** | Serialize: `day_of_year`, `year`, `active_event_state`. Old saves default to Day 1, Year 1 (Spring). |
| **HUD** | New calendar widget node in top bar. Listen to `season_changed`, `holiday_started`, `holiday_approaching`. |
| **EndOfDaySummary** | Display season name and active modifiers. |

### Save/Load

- Serialize: `{ "day_of_year": int, "year": int, "dismissed_events": Array }`
- Season is derived from day_of_year (not stored separately)
- Old saves (no seasonal data): default to Day 1, Year 1
- Event state reconstructed from day_of_year on load

---

## Acceptance Criteria

- [ ] Calendar widget visible in HUD showing season, month, and day
- [ ] Playing through a full year (360 days at Ultra speed) shows clear seasonal variation in golfer traffic
- [ ] Summer revenue is measurably higher than winter revenue over multiple play sessions
- [ ] Desert/Resort courses have noticeably milder winters than Parkland/Mountain
- [ ] Mountain course offers "close for winter" option and can skip ahead
- [ ] At least 3 holiday events fire per year with 5-day advance notice
- [ ] Season transitions are smooth (no jarring jumps in spawn rates during 10-day blend window)
- [ ] Seasonal data survives save/load correctly (day_of_year, year, event state)
- [ ] End-of-day summary reflects seasonal context (season name, active modifiers)
- [ ] Existing tests pass without regression
- [ ] Holiday events stack with seasonal modifiers (e.g., Holiday Weekend in Winter gives 1.5× on top of 0.5× = 0.75× net spawn rate)

---

## Out of Scope

- Visual seasonal changes (fall foliage, snow, spring flowers) — deferred to post-beta
- Per-season tournament types — use existing tournament system as-is
- Seasonal green fee auto-adjustment — player manages this manually
- Day length variation (shorter winter days) — deferred to post-beta
- Multi-year progression unlocks — deferred to post-beta

---

## Dependencies

- **Milestone 1** (Phase 3 Verification): Staff system must be verified working (maintenance cost modifiers interact with groundskeeper effectiveness)
- **Marketing system**: Seasonal campaigns become more strategically interesting (run marketing before summer peak)
- **Weather system**: Season modifies probability tables; WeatherSystem must accept external probability adjustments

---

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Seasonal spawn reduction makes winter too punishing | Medium | High | Data-driven tuning in JSON; playtest across themes |
| Mountain winter closure skip feels like cheating | Low | Medium | Charge maintenance during skip; staff payroll continues |
| Holiday events feel arbitrary without visual celebration | Medium | Low | Notification text creates anticipation; visual celebration is post-beta |
| Modifier stacking creates unexpected extremes | Medium | Medium | Clamp final modifiers; log effective values for debugging |

---

## Algorithm Documentation

Create `docs/algorithms/seasonal-calendar.md` with:
- Year/season/month calculation formulas
- Transition blending math
- Modifier stacking rules
- Theme override application order
- Event schedule and advance notice timing

---

## Estimated Effort

- `SeasonalCalendar` class: 200–300 lines
- Data file: 50–100 lines JSON
- GameManager integration: 30–50 lines
- GolferManager/WeatherSystem/TournamentSystem hooks: 10–20 lines each
- UI (calendar widget, notifications): 100–200 lines
- Save/load: 20–30 lines
- Tests: 100–150 lines
- Algorithm doc: 1–2 pages
- **Total: ~600–900 lines of code + data + docs**
