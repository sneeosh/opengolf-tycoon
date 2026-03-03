# Notification & Event Feed System — Product Spec

**Author:** Claude (Product)
**Date:** 2026-02-27
**Status:** Proposal
**Priority:** MEDIUM
**Version:** 0.1.0-alpha context

---

## Problem Statement

Important events trigger `NotificationToast` popups that auto-dismiss in 3.5 seconds. If the player misses them — common during FAST or ULTRA game speed — they're gone. There is no persistent event log, no click-to-navigate, no event history. The only feedback mechanisms are:

1. **NotificationToast**: Bottom-right, 3.5-second auto-dismiss, max 4 visible, 320px wide. Types: info/success/warning/error. Stacks vertically.
2. **RoundSummaryPopup**: Bottom-right, 5-second auto-dismiss. Shows golfer round completion.
3. **ThoughtBubble**: Floats above golfer heads for 2.5 seconds. Sentiment-colored.

At ULTRA speed, a 3.5-second toast covers approximately 2 game-hours. A hole-in-one notification, course record, or bankruptcy warning can scroll past while the player is zoomed into another part of the course.

---

## Design Principles

- **Nothing important should be missable.** Critical events (bankruptcy, records, milestones) must persist until acknowledged.
- **History is accessible.** Players should be able to scroll back through recent events to understand what happened while they were zoomed in or fast-forwarding.
- **Click-to-navigate connects events to the course.** Clicking a golfer event should pan the camera there.
- **Fast-forward needs special handling.** Events during ULTRA speed should batch and summarize, not spam.

---

## Current System Analysis

### NotificationToast (`scripts/ui/notification_toast.gd`)
- Max 4 visible simultaneously, queue-based overflow
- 320px wide, positioned bottom-right (20px margin)
- 3.5s display + 0.4s fade
- Type-colored left border (info blue, success green, warning amber, error red)
- Click to dismiss early
- Connected to `EventBus.ui_notification(message, type)` signal
- Disabled during main menu

### Events That Trigger Notifications
| Event | Signal | Type |
|-------|--------|------|
| Course record | `record_broken` | success |
| Milestone achieved | Various | success |
| Tournament scheduled/started/completed | `tournament_*` | info/success |
| Bankruptcy warning | Money check | error |
| Season changed | `season_changed` | info |
| Seasonal event | SeasonalEvents check | info |
| Building placed | `building_placed` | info |
| Hole created | `hole_created` | success |
| Loan taken/repaid | Various | warning/info |

### Missing Event Captures
| Event | Currently Surfaced? |
|-------|-------------------|
| Hole-in-one | Yes (course record signal) |
| Eagle during regular play | No |
| Golfer at max frustration | No |
| Course rating change | No |
| Revenue milestone ($X earned today) | No |
| Staff hired/fired | No |
| Marketing campaign started/ended | No |
| Rival course event (Career spec) | N/A (future) |

---

## Feature Design

### 1. Event Feed Panel

A persistent, scrollable panel showing recent events:

**Layout:**
```
┌─────── EVENT FEED ─── [Filter ▾] ── [×] ───┐
│                                              │
│ Day 47, 2:30 PM                              │
│ ★ COURSE RECORD! Pro Martinez shot 65 (-7)   │
│   → Click to view scorecard                  │
│                                              │
│ Day 47, 1:15 PM                              │
│ $ Revenue milestone: $2,000 earned today     │
│                                              │
│ Day 47, 11:00 AM                             │
│ ⛳ Hole-in-one! Serious Kim on Hole #2       │
│   → Click to view hole                       │
│                                              │
│ Day 47, 9:30 AM                              │
│ 🌤 Weather changed: Partly Cloudy           │
│                                              │
│ Day 46, 8:00 PM                              │
│ 📊 Day 46 Summary: 6 golfers, $840 revenue  │
│   Satisfaction: 78% | Rating: ★★★★          │
│                                              │
│ Day 46, 3:00 PM                              │
│ ⚠ Golfer complaint: "Course needs restrooms" │
│   → Click to view golfer needs panel         │
│                                              │
│          [Load More...]                       │
└──────────────────────────────────────────────┘
```

**Panel behavior:**
- Toggle visibility: hotkey `N` (for Notifications) or button in HUD toolbar
- Position: right side of screen, 300px wide, full height minus HUD margins
- Semi-transparent background (alpha 0.9)
- Scrollable with mouse wheel
- Click `[×]` to close
- Does not auto-open — player opens when they want history

**Event entry structure:**
```gdscript
class EventEntry:
    var timestamp_day: int
    var timestamp_hour: float
    var category: String          # "record", "economy", "golfer", "weather", etc.
    var priority: int             # 0=info, 1=normal, 2=high, 3=critical
    var message: String
    var icon: String              # Category icon character
    var navigate_target: Variant  # null, golfer_id, hole_number, Vector2i position
    var detail_action: String     # "view_scorecard", "view_hole", "view_panel", etc.
```

---

### 2. Event Categories & Icons

| Category | Icon | Color | Example Events |
|----------|------|-------|---------------|
| Records | ★ | Gold | Course record, hole-in-one, eagle |
| Economy | $ | Green | Revenue milestone, bankruptcy warning, loan, green fee change |
| Golfers | ⛳ | Blue | Round complete, satisfaction complaint, golfer spawned |
| Weather | ☀ | Cyan | Weather change, season change, wind shift |
| Tournament | 🏆 | Purple | Scheduled, started, completed, dramatic moment |
| Milestone | 🎯 | Orange | Milestone achieved |
| Course | 🏗 | Brown | Hole created/deleted, building placed, rating change |
| Daily | 📊 | Gray | End-of-day summary |

### Category Filtering

Filter dropdown allows showing/hiding categories:

```
[Filter ▾]
  ☑ All
  ☑ Records
  ☑ Economy
  ☑ Golfers
  ☐ Weather (hidden — too frequent)
  ☑ Tournament
  ☑ Milestone
  ☑ Course
  ☑ Daily Summary
```

Filter preference is persisted in settings.

---

### 3. Priority Levels & Behavior

| Priority | Behavior | Examples |
|----------|----------|---------|
| CRITICAL (3) | Toast persists until clicked. Auto-opens event feed. Pauses game at ULTRA speed. | Bankruptcy warning, game over |
| HIGH (2) | Toast shows for 5s (extended). Badge pulse on event feed button. | Course record, hole-in-one, tournament complete, milestone |
| NORMAL (1) | Standard 3.5s toast. Added to feed silently. | Round complete, building placed, season change |
| INFO (0) | No toast. Feed only. | Weather change, individual golfer spawn, hourly wind shift |

**Critical event handling:**
- Critical events always show a toast regardless of game speed
- At ULTRA speed, critical events pause the game briefly (0.5s) to ensure visibility
- Critical toast has a red pulsing border and requires click to dismiss (no auto-dismiss)
- Maximum 1 critical toast at a time (queue additional)

---

### 4. Click-to-Navigate

Events with a `navigate_target` show a clickable "→ Click to view" link:

| Target Type | Navigation Action |
|-------------|------------------|
| `golfer_id` | Pan camera to golfer position (if still on course) |
| `hole_number` | Pan camera to hole tee box |
| `position: Vector2i` | Pan camera to grid position |
| `panel: String` | Open specified panel ("scorecard", "financial", "hole_stats") |

**Implementation:** Clicking an event entry calls `IsometricCamera.focus_on_smooth(target_position, 0.5)` to smoothly pan the camera to the relevant location.

**Stale targets:** If a golfer has left the course, the click does nothing (or shows "Golfer has left the course" in a subtle tooltip).

---

### 5. Fast-Forward Event Batching

During FAST and ULTRA game speed, events can flood the feed. Handle this with batching:

**FAST speed (2× normal):**
- Events fire normally but toast display is shortened to 2.0s
- Feed accumulates events without spam

**ULTRA speed (4× or higher):**
- Suppress INFO-priority toasts entirely (feed only)
- Batch NORMAL-priority events: if >3 events of the same category accumulate within 1 game-hour, consolidate into a single entry: "3 golfers completed rounds this hour"
- HIGH and CRITICAL events always show individual toasts

**Speed change summary:**
When the player switches from FAST/ULTRA to NORMAL or PAUSED, show a brief summary toast:
```
"While fast-forwarding (Day 45-47): 12 rounds completed,
 1 course record set, $4,200 earned"
```

---

### 6. Daily Summary Event

At end of each day, automatically generate a summary event:

```
📊 Day 46 Summary
  Golfers served: 6
  Revenue: $840 | Costs: $285 | Profit: $555
  Satisfaction: 78%
  Rating: ★★★★ (4.1)
  Notable: Course record set by Pro Martinez
```

This entry is always priority NORMAL and provides a scannable daily recap.

---

### 7. Event History Storage

**Retention:**
- Keep last 200 events in memory
- Oldest events purged when limit exceeded (FIFO)
- Events are NOT saved to disk (they're ephemeral session data)
- Daily summaries could optionally persist in save data (lightweight)

**Performance:**
- Event feed panel uses virtual scrolling (render only visible entries)
- Event creation is O(1) — append to array
- Category filtering uses pre-filtered arrays cached on filter change

---

## Data Model Changes

### EventFeedManager (new singleton or component):
```gdscript
# scripts/managers/event_feed_manager.gd

var events: Array[EventEntry] = []
var max_events: int = 200
var category_filters: Dictionary = {}    # category → bool (show/hide)
var unread_count: int = 0                # Events since last feed open

signal event_added(entry: EventEntry)
signal unread_count_changed(count: int)

func add_event(category: String, priority: int, message: String,
               navigate_target: Variant = null, detail_action: String = "") -> void:
    var entry = EventEntry.new()
    entry.timestamp_day = GameManager.current_day
    entry.timestamp_hour = GameManager.current_hour
    entry.category = category
    entry.priority = priority
    entry.message = message
    entry.navigate_target = navigate_target
    entry.detail_action = detail_action
    events.append(entry)
    if events.size() > max_events:
        events.pop_front()
    unread_count += 1
    event_added.emit(entry)
    unread_count_changed.emit(unread_count)
```

### Integration points:
Connect to existing EventBus signals and translate to feed events:

```gdscript
# In EventFeedManager._ready():
EventBus.record_broken.connect(_on_record_broken)
EventBus.golfer_finished_round.connect(_on_golfer_finished_round)
EventBus.weather_changed.connect(_on_weather_changed)
EventBus.season_changed.connect(_on_season_changed)
EventBus.tournament_completed.connect(_on_tournament_completed)
EventBus.money_changed.connect(_on_money_changed)
EventBus.course_rating_changed.connect(_on_course_rating_changed)
EventBus.hole_created.connect(_on_hole_created)
EventBus.end_of_day.connect(_on_end_of_day)
# ... etc.
```

---

## Implementation Sequence

```
Phase 1 (Core Feed):
  1. EventEntry data class
  2. EventFeedManager with event storage and signals
  3. Connect to primary EventBus signals (records, rounds, weather, economy)
  4. Event feed panel UI (scrollable list, category icons, timestamps)

Phase 2 (Navigation & Filtering):
  5. Click-to-navigate for golfer/hole/position targets
  6. Category filter dropdown
  7. Filter persistence in settings
  8. Unread badge on feed toggle button

Phase 3 (Priority System):
  9. Priority-based toast behavior (critical persists, info suppressed)
  10. Fast-forward event batching
  11. Speed-change summary toast
  12. Daily summary auto-generation

Phase 4 (Integration):
  13. Tournament moment events (from Simulated Tournament spec)
  14. Follow mode event prioritization (from Spectator Camera spec)
  15. Career/rival events (from Career Mode spec)
  16. Seasonal event advance notifications (from Seasonal spec)
```

---

## Success Criteria

- Player can open the event feed and see what happened while fast-forwarding
- Critical events (bankruptcy, records) are never missable — they persist until acknowledged
- Clicking a golfer event pans the camera to that golfer's position
- Category filtering works and preferences persist across sessions
- During ULTRA speed, the feed doesn't spam 100 entries per game-hour
- Daily summary provides a useful at-a-glance recap
- Event feed stores 200 events without performance impact
- Unread badge on feed button tells the player there are new events

---

## Out of Scope

| Feature | Reason |
|---------|--------|
| Push notifications (desktop/mobile) | No native app notification system |
| Event export / log file | Developer debugging, not player feature |
| RSS / webhook integration | No external service integration |
| Sound per notification category | Handled by Audio Design spec |
| Event priority customization | Fixed priorities cover all use cases |
| Social sharing of events | No social integration |
