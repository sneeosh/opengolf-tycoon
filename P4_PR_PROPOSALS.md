# P4 Milestone PR Proposals

Each P4 milestone is scoped as a standalone PR. They are ordered by dependency: PR 1 (Save/Load) and PR 2 (Day/Night Cycle) have no interdependencies and can be built in parallel. PR 3 (End-of-Day Summary) depends on PR 2. PR 4 (Golfer Feedback) is independent.

---

## PR 1: Save/Load System

### What exists today
- `SaveManager` autoload (`scripts/autoload/save_manager.gd`) — skeleton only. It saves/loads 5 fields (course_name, money, reputation, day, hour) using `store_var`/`get_var`. It does **not** persist terrain, entities, holes, elevation, green fee, or wind state.
- `TerrainGrid` already has `serialize()` / `deserialize()` and `serialize_elevation()` / `deserialize_elevation()`.
- `EntityLayer` has `serialize()` (buildings, trees, rocks) but no `deserialize()`.
- `Golfer` has `serialize()` / `deserialize()` stubs but they are not called from anywhere.
- `EventBus` has `save_requested`, `save_completed`, `load_requested`, `load_completed` signals already defined.
- Save version constant (`SAVE_VERSION = 1`) is already defined.

### Scope of work

**1. Complete SaveManager serialization** (`scripts/autoload/save_manager.gd`)
- Expand `save_game()` to also serialize:
  - `green_fee` from GameManager
  - Terrain grid data via `terrain_grid.serialize()`
  - Elevation grid data via `terrain_grid.serialize_elevation()`
  - Entity layer data via `entity_layer.serialize()`
  - Hole data from `GameManager.current_course.holes` (each hole's tee/green/hole positions, par, distance, is_open, difficulty)
  - Wind system state (direction, speed)
- Switch from `store_var` to JSON (`JSON.stringify` / `JSON.parse_string`) for human-readable saves and forward compatibility.
- Add save metadata: timestamp, save version, course name, day number (for UI display in load screen).

**2. Complete SaveManager deserialization** (`scripts/autoload/save_manager.gd`)
- Expand `_apply_save_data()` to:
  - Restore green fee via `GameManager.set_green_fee()`
  - Restore terrain via `terrain_grid.deserialize()` and `terrain_grid.deserialize_elevation()`
  - Restore entities — add `EntityLayer.deserialize()` method to reconstruct buildings, trees, rocks from saved positions/types
  - Restore holes — rebuild `GameManager.current_course.holes` array and emit `hole_created` signals to trigger HoleManager visualizations
  - Restore wind state
- Stop any active simulation, clear existing golfers, and switch to BUILDING mode on load.
- Emit `load_completed` signal so UI can react.

**3. Add EntityLayer.deserialize()** (`scripts/course/entity_layer.gd`)
- Add `deserialize(data: Dictionary)` that clears existing entities and recreates them from saved data using `place_building()`, `place_tree()`, `place_rock()`.
- Needs a `clear_all()` helper to remove all entities before loading.

**4. Wire save/load to Main scene** (`scripts/main/main.gd`)
- Pass `terrain_grid` and `entity_layer` references to SaveManager (either via GameManager or direct reference).
- Add Ctrl+S keyboard shortcut in `_input()` to trigger quicksave.
- Connect `load_completed` signal to rebuild hole list UI via `_rebuild_hole_list()`.

**5. Auto-save at end of each day** (`scripts/autoload/save_manager.gd`)
- Connect to `EventBus.day_changed` signal.
- Call `save_game("autosave")` whenever a new day begins.

**6. Save slot UI** — minimal
- Add a simple save/load panel (PanelContainer with VBoxContainer) accessible from a "Menu" button in the top bar.
- Show list of saves via `SaveManager.get_save_list()` with timestamp and course name.
- "Save" button creates a named save (default: `slot_1`).
- "Load" button loads selected save.
- No main menu screen yet — that's a future scope item.

### Godot best practices & tech debt considerations
- Use `JSON.stringify` with indentation for saves (not `store_var` which is binary and fragile across Godot versions).
- Keep SaveManager as an autoload singleton — it already is. Don't add scene-tree dependencies; instead, have Main pass references in `_ready()`.
- Add version migration: `_apply_save_data()` should check `SAVE_VERSION` and handle missing keys with defaults, so older saves remain loadable as features are added.
- Avoid storing node references in save data. Serialize only plain data (Dictionaries, Arrays, primitives).

### Files touched
- `scripts/autoload/save_manager.gd` — major expansion
- `scripts/course/entity_layer.gd` — add `deserialize()`, `clear_all()`
- `scripts/main/main.gd` — wire shortcuts, pass references, handle load
- New: `scripts/ui/save_load_panel.gd` — simple save/load UI

### Estimated complexity
Medium-high. The serialization/deserialization plumbing is the bulk of the work. The UI is intentionally minimal.

---

## PR 2: Day/Night Cycle & Course Closing

### What exists today
- `GameManager._advance_time()` ticks `current_hour` during simulation.
- `COURSE_OPEN_HOUR = 6.0` and `COURSE_CLOSE_HOUR = 20.0` are defined.
- `is_course_open()` returns whether the current hour is within operating hours.
- `day_changed` signal fires when hour wraps past 24.
- `hour_changed` signal is defined but **never emitted**.
- GolferManager spawns golfers with no regard for closing time.
- There is no visual time-of-day effect.
- When `current_hour` wraps past 24, a new day starts but there's no transition UX.

### Scope of work

**1. Emit hour_changed signal** (`scripts/autoload/game_manager.gd`)
- In `_advance_time()`, emit `hour_changed(current_hour)` every frame (or every game-minute). Other systems listen to this for gradual effects.

**2. Visual dimming — CanvasModulate overlay** (new: `scripts/systems/day_night_system.gd`)
- Create a new `DayNightSystem` node (added as child of Main).
- Use a `CanvasModulate` node to tint the entire scene based on time of day:
  - 6 AM–8 AM: warm sunrise tint (lerp from dim orange to white)
  - 8 AM–5 PM: full brightness (white)
  - 5 PM–8 PM: gradual dimming (lerp from white to warm orange/dark blue)
  - 8 PM–6 AM: night (dark blue, though gameplay won't normally run here)
- Listen to `hour_changed` signal for smooth interpolation.
- This is a purely visual system — no gameplay logic.

**3. Stop spawning after course close** (`scripts/managers/golfer_manager.gd`)
- In `_process()`, check `GameManager.is_course_open()` before spawning new groups.
- After `COURSE_CLOSE_HOUR`, stop calling `spawn_initial_group()`.
- Existing golfers continue playing until they finish their **current hole**, then leave (FINISHED state).

**4. Golfer leave-at-closing behavior** (`scripts/managers/golfer_manager.gd`)
- Add a `_check_course_closing()` method called in `_process()`.
- When `!GameManager.is_course_open()`:
  - Any golfer who finishes a hole transitions to FINISHED instead of advancing to the next hole.
  - Golfers mid-hole continue playing until they hole out, then leave.
- This naturally clears the course by ~8:30–9 PM game time.

**5. Day transition** (`scripts/autoload/game_manager.gd` + `scripts/main/main.gd`)
- When all golfers have left and hour >= COURSE_CLOSE_HOUR:
  - Emit a new `end_of_day` signal with the day number.
  - Fast-forward `current_hour` to `COURSE_OPEN_HOUR` of the next day.
  - Increment `current_day` and emit `day_changed`.
  - Generate new daily wind via `wind_system.generate_daily_wind()`.
- Show a simple notification or brief overlay: "Day X Complete — Day X+1 begins" (reuse EventBus.notify for now; a richer end-of-day screen comes in PR 3).

**6. Add EventBus signals** (`scripts/autoload/event_bus.gd`)
- Add `signal end_of_day(day_number: int)` for the summary screen (PR 3) to hook into.
- Add `signal course_closing()` so UI can show "Course closing soon" notification.

### Godot best practices & tech debt considerations
- Use `CanvasModulate` for the scene-wide tint — this is the idiomatic Godot approach for 2D lighting. Don't add per-node modulation.
- Keep DayNightSystem as a simple Node with `_process()`, not an autoload. It's a scene-specific visual system.
- The `hour_changed` signal should emit with `float` precision (not int), so listeners can smoothly interpolate.
- Don't add artificial "sleep" timers for the day transition. Use signal-driven flow: end_of_day → (PR 3 summary) → new day begins.

### Files touched
- `scripts/autoload/game_manager.gd` — emit hour_changed, end_of_day logic, day transition
- `scripts/autoload/event_bus.gd` — add end_of_day, course_closing signals
- `scripts/managers/golfer_manager.gd` — close-time spawn gating, golfer leave behavior
- New: `scripts/systems/day_night_system.gd` — visual dimming
- `scripts/main/main.gd` — instantiate DayNightSystem, show day transition notification

### Estimated complexity
Medium. The visual dimming is straightforward. The golfer leave-at-closing logic requires care to avoid edge cases (golfer mid-swing at closing, last golfer stuck, etc.).

---

## PR 3: End-of-Day Summary

**Depends on:** PR 2 (Day/Night Cycle) for the `end_of_day` signal and day transition flow.

### What exists today
- `transaction_completed` signal fires for every financial event (green fees, maintenance, terrain costs).
- `golfer_finished_hole` signal includes golfer_id, hole_number, strokes, and par.
- `golfer_finished_round` signal includes golfer_id and total_strokes.
- `golfer_spawned` fires for every golfer.
- No daily statistics tracking. No summary UI.

### Scope of work

**1. DailyStatsTracker** (new: `scripts/systems/daily_stats_tracker.gd`)
- A Node added as child of Main (not an autoload — it's per-session state).
- Connects to EventBus signals and accumulates daily stats:
  - `revenue_today: int` — sum of green_fee_paid amounts
  - `maintenance_today: int` — from day_changed maintenance deduction
  - `golfers_served: int` — count of golfer_finished_round signals
  - `golfers_spawned: int` — count of golfer_spawned signals
  - `notable_scores: Array[Dictionary]` — tracks eagles, albatrosses, hole-in-ones (strokes == 1)
  - `hole_scores: Dictionary` — maps hole_number → Array of (strokes - par) for average calculation
  - `round_start_times: Dictionary` — maps golfer_id → start_hour for pace-of-play
  - `round_durations: Array[float]` — list of completed round durations in game-hours
- Exposes `get_daily_summary() -> Dictionary` that returns:
  - `revenue`, `expenses`, `profit` (revenue - expenses)
  - `golfers_served`
  - `notable_scores` (list of {golfer_name, hole_number, score_name})
  - `average_pace_of_play` (average game-hours per round)
  - `average_score` (average strokes relative to par)
- Resets all accumulators when a new day starts (`day_changed` signal).

**2. EndOfDaySummaryPanel** (new: `scripts/ui/end_of_day_panel.gd`)
- A CenterContainer > PanelContainer > VBoxContainer popup.
- Listens to `end_of_day` signal from EventBus.
- Fetches data from DailyStatsTracker and displays:
  - Header: "Day X Summary"
  - Revenue: "+$XXX"
  - Expenses: "-$XXX" (maintenance)
  - Net Profit/Loss: "+$XXX" or "-$XXX" (color-coded green/red)
  - Golfers Served: "XX golfers"
  - Notable Scores: List of eagles/aces (or "None today" if empty)
  - Average Pace: "X.X hours per round"
- "Continue" button dismisses the panel and triggers the day transition to the next morning.
- Pauses the game speed while the panel is visible.

**3. Hook into day transition flow** (`scripts/main/main.gd`)
- When `end_of_day` fires:
  1. Pause simulation
  2. Show EndOfDaySummaryPanel
  3. On "Continue" pressed → advance to next day, unpause

**4. Track green fee payments per golfer** (`scripts/systems/daily_stats_tracker.gd`)
- Listen to `green_fee_paid(golfer_id, golfer_name, amount)` to accumulate revenue.
- Listen to `transaction_completed` for maintenance costs (filter by negative amounts on day_changed).

### Godot best practices & tech debt considerations
- DailyStatsTracker is a pure data node with no visual components — clean separation of concerns.
- The summary panel should be a scene or a script-constructed UI node, matching the existing pattern of programmatic UI construction in main.gd.
- Don't store stats permanently between sessions (they're transient per-day). If save/load (PR 1) is merged first, daily stats reset on load (player loads into a new day).
- Use typed arrays and dictionaries for stats — avoid stringly-typed data.

### Files touched
- New: `scripts/systems/daily_stats_tracker.gd` — stats accumulation
- New: `scripts/ui/end_of_day_panel.gd` — summary popup UI
- `scripts/autoload/event_bus.gd` — no changes if PR 2 already added `end_of_day` signal
- `scripts/main/main.gd` — instantiate tracker and panel, hook into day transition

### Estimated complexity
Medium. Mostly data plumbing and UI construction. The tricky part is correctly pausing/resuming the game around the summary panel.

---

## PR 4: Golfer Feedback System

### What exists today
- `Golfer.current_mood: float` (0.0–1.0) is tracked and adjusted after each hole based on score vs par.
- `golfer_mood_changed` signal exists on EventBus.
- `Golfer.patience: float` personality trait exists.
- `Golfer.show_payment_notification()` already creates floating labels with tween animations above golfers — this is the exact pattern to reuse for thought bubbles.
- `golfer_traits.json` defines mood states with thresholds (ecstatic > 90, happy > 70, etc.) but this data is never loaded or used.

### Scope of work

**1. Feedback trigger system** (`scripts/entities/golfer.gd`)
- Add a `_maybe_show_feedback()` method called after key events:
  - After `finish_hole()` — react to score (eagle: "What a shot!", bogey: "Tough hole...")
  - After being blocked by a group ahead for too long — "Slow play!" (track wait time in `_process()`)
  - After paying green fee — if fee is high relative to mood: "Overpriced!", if good value: "Great course!"
  - Periodically while walking — compliment or complain about course design (random, mood-weighted)
- Each feedback trigger has a cooldown (e.g., 30 game-seconds minimum between bubbles per golfer) to avoid spam.
- Feedback selection is mood-weighted: happier golfers say positive things more often, unhappier golfers complain.

**2. Thought bubble display** (`scripts/entities/golfer.gd`)
- Add `show_thought_bubble(text: String, type: String)` method.
- Reuse the existing `show_payment_notification()` pattern: create a Label child, tween position upward and fade out.
- Use a slightly different style: white background panel (PanelContainer) with rounded look, positioned above the golfer's head.
- Types: "positive" (green text), "negative" (red text), "neutral" (white text).
- Duration: 2–3 seconds, then fade out.

**3. Feedback text data** (new: `data/golfer_feedback.json`)
- JSON file with categorized feedback strings:
  ```json
  {
    "score_reactions": {
      "eagle_or_better": ["Incredible!", "What a shot!"],
      "birdie": ["Nice birdie!", "Great hole!"],
      "par": ["Solid par.", "Good hole."],
      "bogey": ["Tough hole...", "Could be better."],
      "double_plus": ["Rough hole.", "Forget that one."]
    },
    "pace_of_play": {
      "slow": ["So slow!", "This pace is brutal.", "Move it along!"],
      "good": ["Nice pace today.", "Smooth round."]
    },
    "value": {
      "overpriced": ["Overpriced!", "Not worth the fee.", "Too expensive."],
      "good_value": ["Great value!", "Worth every penny.", "Good course for the price."],
      "fair": ["Fair price.", "Reasonable."]
    },
    "course_quality": {
      "positive": ["Beautiful course!", "Love the layout!", "Well maintained!"],
      "negative": ["Course needs work.", "Rough conditions.", "Seen better."]
    }
  }
  ```
- Load in golfer `_ready()` or lazily on first feedback request.

**4. Slow-play detection** (`scripts/entities/golfer.gd`)
- Track `wait_time_accumulated: float` — incremented in `_process()` when state is IDLE and the golfer is waiting for their turn (blocked by landing zone check or group ahead).
- When `wait_time_accumulated` exceeds a patience-based threshold (e.g., `60.0 / patience` game-seconds), trigger a slow-play complaint and adjust mood downward.
- Reset `wait_time_accumulated` when the golfer takes a shot.

**5. Value perception** (`scripts/entities/golfer.gd`)
- After paying green fee, evaluate: `green_fee` vs. a "perceived value" based on course difficulty, number of holes, and current mood.
- Simple formula: `value_ratio = perceived_value / green_fee`. If < 0.7 → "overpriced", > 1.3 → "great value", else "fair".
- Perceived value scales with number of open holes (more holes = more value) and course reputation.

**6. Feedback log** (new: `scripts/ui/feedback_log.gd`)
- A simple scrollable panel (visible via a toggle button in the HUD).
- Stores the last ~50 feedback messages with timestamp, golfer name, and message.
- Provides a quick overview for the player to understand golfer sentiment without watching individual bubbles.
- Connect to a new `EventBus.golfer_feedback(golfer_id, golfer_name, message, type)` signal.

**7. Add EventBus signal** (`scripts/autoload/event_bus.gd`)
- Add `signal golfer_feedback(golfer_id: int, golfer_name: String, message: String, type: String)`.

### Godot best practices & tech debt considerations
- Keep feedback text in a data file (`golfer_feedback.json`), not hardcoded in GDScript. This matches the existing pattern of `golfer_traits.json` and `buildings.json`.
- Reuse the existing tween-based floating label pattern from `show_payment_notification()`. Don't introduce a new animation system.
- Thought bubble frequency should be governed by cooldowns, not timers that tick independently. Check elapsed time since last bubble in `_maybe_show_feedback()`.
- The feedback log should be a UI-only component with no game logic — it just listens to signals and displays them.
- Don't tie mood changes directly to feedback display. Mood is already adjusted in `finish_hole()`. Feedback is a *reflection* of mood, not a cause of it (though slow play can additionally reduce mood).
- Load `golfer_feedback.json` once and cache it, don't re-read every feedback request.

### Files touched
- `scripts/entities/golfer.gd` — feedback triggers, thought bubbles, slow-play tracking, value perception
- `scripts/autoload/event_bus.gd` — add golfer_feedback signal
- New: `data/golfer_feedback.json` — feedback text data
- New: `scripts/ui/feedback_log.gd` — scrollable feedback history panel
- `scripts/main/main.gd` — instantiate feedback log, add toggle button

### Estimated complexity
Medium. The feedback trigger logic needs tuning to feel natural (not too frequent, not too rare). The visual implementation reuses existing patterns.

---

## Dependency Graph

```
PR 1 (Save/Load)  ──────────────────────────┐
                                              │ (independent)
PR 2 (Day/Night Cycle) ──→ PR 3 (End-of-Day) │
                                              │
PR 4 (Golfer Feedback) ─────────────────────┘
```

**Recommended implementation order:**
1. PR 2 (Day/Night Cycle) — foundational for day flow
2. PR 1 (Save/Load) — can be done in parallel with PR 2
3. PR 3 (End-of-Day Summary) — depends on PR 2's `end_of_day` signal
4. PR 4 (Golfer Feedback) — independent, can be done anytime

---

## Cross-Cutting Concerns

### Existing tech debt to avoid extending
- **Programmatic UI construction**: `main.gd` builds all UI in code (~870 lines). New UI should follow this pattern for consistency but ideally as separate scripts (e.g., `save_load_panel.gd`, `end_of_day_panel.gd`) instantiated by Main, rather than adding more code to `main.gd`.
- **SaveManager references**: SaveManager currently accesses GameManager directly as an autoload, but needs terrain_grid and entity_layer which are scene-tree nodes. Solution: have Main set these references on SaveManager in `_ready()`, similar to how `GameManager.terrain_grid` is already set.
- **Signal naming**: EventBus uses both `emit_signal("name", ...)` (old style) and should prefer the typed `signal_name.emit(...)` style going forward, but don't refactor existing code — only use the newer style in new code.

### Testing considerations
- Save/Load: Test round-trip (save → load → verify terrain, entities, holes match). Test loading older save versions with missing keys.
- Day/Night: Test golfer behavior at boundary (mid-swing at closing, last golfer leaving, empty course transition).
- End-of-Day: Test with 0 golfers (edge case), test notable score detection.
- Feedback: Test cooldown prevents spam, test mood-weighted selection produces varied output.
