# Event Feed System

> **Source:** `scripts/managers/event_feed_manager.gd` (autoload) and `scripts/ui/event_feed_panel.gd`

## Plain English

The event feed captures important game events and stores them in a persistent, scrollable log. Unlike toast notifications that vanish after a few seconds, the feed persists for the entire session so players can review what happened during fast-forward or while zoomed into another part of the course.

### Event Categories

Events are grouped into 8 categories, each with a distinctive icon and color:

- **Records** (gold) — Hole-in-ones, course records, hole records, eagles, albatrosses
- **Economy** (green) — Money milestones, bankruptcy warnings, reputation milestones
- **Golfers** (blue) — Outstanding rounds (3+ under par)
- **Weather** (cyan) — Weather and season changes
- **Tournament** (purple) — Scheduled, started, completed tournaments
- **Milestone** (orange) — Achievement milestones reached
- **Course** (yellow) — Holes created/deleted, buildings placed, rating changes
- **Daily** (gray) — End-of-day summary with revenue, golfers, satisfaction

### Priority System

Each event has a priority that controls how prominently it's shown:

- **INFO** — Feed only, no toast notification. Used for: weather changes, building placements, green fee changes
- **NORMAL** — Standard 3.5s toast + feed. Used for: hole creation, season changes, daily summaries, reputation milestones
- **HIGH** — Extended 5.0s toast + feed badge pulse. Used for: records, eagles, tournament events
- **CRITICAL** — Persistent toast (click to dismiss) + feed. Used for: bankruptcy warnings, funds depleted

### Fast-Forward Handling

During FAST speed (2x), toast duration is shortened to 2.0 seconds.

During ULTRA speed (4x), NORMAL-priority toasts are suppressed entirely (events still appear in feed). Additionally, if more than 3 NORMAL events of the same category accumulate within a single game-hour, new events of that category are added silently (no toast triggered, but still stored in the feed).

When the player slows from FAST/ULTRA to NORMAL or PAUSED, a summary toast fires showing what happened during the fast-forward period: day range, rounds completed, records set, and money gained/lost.

### Click-to-Navigate

Events can reference a navigation target. Clicking the ">" button on an event entry pans the camera to the relevant location:

- **Hole** — Centers camera between the hole's tee and green positions
- **Position** — Pans camera to a grid coordinate (e.g., building placement)
- **Golfer** — Pans to the golfer's current position (if still on course)
- **Panel** — Opens a named panel (e.g., "financial")

### Storage

The feed stores up to 200 events in memory (FIFO eviction). Events are not saved to disk — they're ephemeral session data. Daily summaries provide the most important recap information.

---

## Algorithm

### 1. Event Priority Filtering (Toast Display)

```
For each new event:
  if priority == INFO:
    → Add to feed, no toast

  if game_speed == ULTRA:
    if priority == NORMAL:
      → Add to feed, no toast
    if priority >= HIGH:
      → Add to feed, show toast

  if game_speed == FAST:
    if priority >= NORMAL:
      → Add to feed, show toast (2.0s duration)

  if game_speed <= NORMAL:
    → Add to feed, show toast (standard durations)

Toast durations:
  NORMAL priority:  3.5s (default), 2.0s (FAST speed)
  HIGH priority:    5.0s (all speeds)
  CRITICAL:         No auto-dismiss, requires click
```

### 2. ULTRA Speed Batching

```
Maintain per-category count per game-hour:
  batch_counts: Dictionary = {category → count}
  batch_hour: float = floor(current_hour)

When adding a NORMAL event at ULTRA speed:
  if floor(current_hour) != batch_hour:
    reset batch_counts, update batch_hour
  batch_counts[category] += 1
  if batch_counts[category] > 3:
    add entry silently (no event_added signal → no toast)
  else:
    add entry normally
```

### 3. Fast-Forward Summary

```
On speed change to FAST/ULTRA:
  record: ff_start_day, initial money

While fast-forwarding, track:
  rounds_completed (from GOLFERS category events)
  records_set (from RECORDS category events)

On speed change back to NORMAL/PAUSED:
  days_elapsed = current_day - ff_start_day
  revenue_change = current_money - start_money

  if days_elapsed > 0 or rounds_completed > 0:
    emit summary toast: "Fast-forward: Day X-Y, N rounds, M records, +$Z"
```

### 4. Event Signal Mapping

```
EventBus Signal              → Category    → Priority  → Navigate
─────────────────────────────┼─────────────┼───────────┼──────────
record_broken(hole_in_one)   → RECORDS     → HIGH      → HOLE
record_broken(lowest_round)  → RECORDS     → HIGH      → HOLE
record_broken(best_hole)     → RECORDS     → HIGH      → HOLE
golfer_finished_hole (eagle) → RECORDS     → HIGH      → HOLE
golfer_finished_round (-3+)  → GOLFERS     → NORMAL    → GOLFER
money_changed (milestone)    → ECONOMY     → NORMAL    → NONE
money_changed (bankruptcy)   → ECONOMY     → CRITICAL  → NONE
reputation_changed (25pts)   → ECONOMY     → NORMAL    → NONE
green_fee_changed            → ECONOMY     → INFO      → NONE
course_rating_changed        → COURSE      → NORMAL    → NONE
weather_changed              → WEATHER     → INFO      → NONE
season_changed               → WEATHER     → NORMAL    → NONE
tournament_scheduled         → TOURNAMENT  → NORMAL    → NONE
tournament_started           → TOURNAMENT  → HIGH      → NONE
tournament_completed         → TOURNAMENT  → HIGH      → NONE
hole_created                 → COURSE      → NORMAL    → NONE
hole_deleted                 → COURSE      → NORMAL    → NONE
building_placed              → COURSE      → INFO      → POSITION
end_of_day                   → DAILY       → NORMAL    → NONE
new_game_started             → COURSE      → NORMAL    → NONE
```

### 5. Daily Summary Format

```
On end_of_day(day_number):
  msg = "Day {day}: {golfers} golfers, ${revenue} revenue, ${profit} profit, {satisfaction}% satisfaction"

  if holes_in_one > 0: append "{N} HIO"
  if eagles > 0: append "{N} eagle(s)"
```

---

## Tuning Levers

| Parameter | Location | Current Value | Effect of Changing |
|-----------|----------|---------------|-------------------|
| `MAX_EVENTS` | `event_feed_manager.gd:9` | 200 | More events stored = more scrollback history, slightly more memory |
| `DISPLAY_DURATION` | `notification_toast.gd:12` | 3.5s | How long NORMAL toasts show |
| `DISPLAY_DURATION_HIGH` | `notification_toast.gd:13` | 5.0s | How long HIGH priority toasts show |
| FAST speed toast duration | `notification_toast.gd` (in `_show_toast`) | 2.0s | How quickly toasts dismiss during FAST speed |
| Batch threshold | `event_feed_manager.gd` (in `add_event`) | 3 events/hour/category | How many same-category events before batching at ULTRA. Lower = less spam, higher = more granularity |
| Outstanding round threshold | `event_feed_manager.gd` (in `_on_golfer_finished_round`) | -3 | Score-to-par threshold for logging a round. -2 would log more rounds, -5 fewer |
| Money milestones | `event_feed_manager.gd` (in `_on_money_changed`) | [$100K, $250K, $500K, $1M] | Which dollar milestones trigger events |
| Reputation bracket size | `event_feed_manager.gd` (in `_on_reputation_changed`) | 25 points | How often reputation milestones fire |
| `PANEL_WIDTH` | `event_feed_panel.gd:12` | 340px | Width of the feed panel sidebar |
