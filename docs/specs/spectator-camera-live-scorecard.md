# Spectator Camera & Live Scorecard — Product Spec

**Author:** Claude (Product)
**Date:** 2026-02-27
**Status:** Proposal
**Priority:** HIGH
**Version:** 0.1.0-alpha context

---

## Problem Statement

The game simulates golfers playing through a player-designed course, but there is no way to meaningfully watch an individual golfer's round. The camera is free-roaming only (WASD/mouse), there is no follow mode, and the only round feedback is a 5-second `RoundSummaryPopup` toast showing total score, mood, and payment after a golfer finishes. The `HoleStatsPanel` shows per-hole statistics but only for one hole at a time — there is no live scorecard showing a golfer's hole-by-hole progress.

The simulation is the payoff for course design. If a player spends 30 minutes crafting a challenging par-4 with strategic bunkers, they should be able to watch a golfer navigate it, see the scorecard update shot by shot, and feel the tension of a difficult approach. Currently the simulation is background noise — golfers walk around, swing, and leave, with minimal observability.

---

## Design Principles

- **Follow mode is opt-in, not forced.** The default camera behavior remains free-roam. Follow mode activates on click and deactivates on Escape.
- **The scorecard is the primary feedback loop.** It tells the player whether their course design is producing the intended challenge.
- **Camera motion should feel cinematic, not robotic.** Smooth tracking during walks, slight zoom on swings, hold on ball landings.
- **Group play stays visible.** When following a golfer in a group, show all group members' scores.

---

## Current System Analysis

### Camera Infrastructure (`IsometricCamera`)
- `focus_on(world_position, instant=false)` — smooth camera pan to position
- `focus_on_smooth(world_position, duration=0.5)` — tween-based focus
- `zoom_to_point(world_position, new_zoom, duration=0.3)` — zoom centered on a point
- `shake(intensity, duration)` and `micro_shake(intensity)` — camera shake effects
- `set_zoom_level(level, instant=false)` — smooth zoom transitions
- WASD panning, mouse wheel zoom, middle-click drag all functional
- Bounds enforcement prevents going off-grid
- `subtle_follow_enabled` property exists (cursor-aware movement) but is unrelated to golfer following

### Golfer State Machine
States: `IDLE → WALKING → PREPARING_SHOT → SWINGING → WATCHING → FINISHED`
- Position available via `global_position` (screen) and `ball_position` (grid)
- `state_changed` signal emits `(old_state, new_state)` on every transition
- `golfer_selected` signal emits on click
- `current_hole`, `current_strokes`, `total_strokes`, `total_par`, `hole_scores[]` all accessible
- `golfer_tier`, `golfer_name`, `current_mood`, `needs` available for display
- `previous_hole_strokes` tracks last hole's score (for honor system)

### Existing Round Summary
- `RoundSummaryPopup`: 260px-wide toast, bottom-right, 5-second auto-dismiss
- Shows: name, total score with +/- par, satisfaction text, payment
- Color-coded score (eagle gold, birdie green, par white, bogey amber, double+ red)
- Queue-based — multiple notifications shown sequentially
- Only fires on `golfer_finished_round` — no per-hole feedback

### Group Play
- Groups of 1–4 golfers sharing a `group_id`
- Turn order: honor system on tee (lowest previous score), away rule on fairway
- `GolferManager` tracks all active golfers and can look up by ID or group

---

## Feature Design

### 1. Follow Mode Activation

**Enter follow mode:**
- Click a golfer on the course → camera smoothly centers on them, follow mode activates
- Alternative: Click a golfer name in a future golfer list panel
- `EventBus.golfer_selected` already fires on click — hook into this signal

**Exit follow mode:**
- Press Escape
- Click empty terrain (no golfer under cursor)
- Click a different golfer (switches follow target)
- Followed golfer finishes round and leaves course

**Follow mode state:**
```gdscript
var followed_golfer: Golfer = null     # null = free camera mode
var follow_mode: bool = false
```

**Visual indicators when following:**
- Subtle highlight ring around followed golfer (golden glow, pulsing)
- Other golfers in the same group get a dimmer highlight ring
- "Following: [Name]" label in top-left corner with tier badge and Escape hint

---

### 2. Camera Behavior by Golfer State

The camera should feel natural, matching what a spectator would watch:

**IDLE (waiting for turn):**
- Camera holds position, pulled back slightly for context
- Zoom level: 1.0× (default)
- If idle for >5 seconds, camera slowly drifts to show surrounding area

**WALKING (between shots / between holes):**
- Camera follows golfer at walking pace with smooth tracking
- Offset: camera leads slightly in the direction of movement
- Zoom level: 0.9× (slightly pulled back for environmental context)
- Damping: high (camera doesn't jitter on direction changes)

**PREPARING_SHOT (lining up):**
- Camera smoothly zooms to 1.2× centered on golfer
- Duration: 0.5s transition
- Show shot target indicator (line from golfer to intended landing zone, if ShotAI data is accessible)

**SWINGING (taking shot):**
- Micro camera shake on impact (existing `micro_shake` at intensity 2.0)
- Brief hold on golfer (0.3s) then track ball if visible

**WATCHING (ball in flight):**
- Camera pans to follow ball flight path
- If ball flight is short (<3 tiles): camera stays centered between golfer and landing spot
- If ball flight is long (>3 tiles): camera leads the ball toward landing zone
- On ball landing: hold for 1.0s at landing position
- Zoom during flight: pull back to 0.8× for long shots, stay at 1.2× for short chips

**FINISHED (round complete):**
- Camera holds position
- Full scorecard popup appears (see section 4)
- After popup dismissed, follow mode exits

**Between holes (walking to next tee):**
- Same as WALKING behavior
- Camera tracks golfer walking to next tee box
- On arrival at next tee, camera holds and shows hole context (pull back to 0.8× briefly to show the hole layout, then zoom in as golfer approaches)

---

### 3. Live Scorecard Overlay

A translucent panel that appears when following a golfer, showing real-time hole-by-hole scoring.

**Layout — Individual Golfer:**
```
┌─────────────────────────────────────────────────────┐
│ Pro Anderson  ★★★★  │  Thru 14  │  Score: -3 (69)  │
├──────┬──┬──┬──┬──┬──┬──┬──┬──┬──┬───────┬──────────┤
│ Hole │ 1│ 2│ 3│ 4│ 5│ 6│ 7│ 8│ 9│ OUT   │          │
│ Par  │ 4│ 3│ 5│ 4│ 4│ 3│ 4│ 5│ 4│  36   │          │
│ Score│ 4│ 2│ 5│ 3│ 4│ 3│ 3│ 5│ 4│  33   │          │
├──────┼──┼──┼──┼──┼──┼──┼──┼──┼──┼───────┤          │
│ Hole │10│11│12│13│14│15│16│17│18│ IN    │ TOT      │
│ Par  │ 4│ 5│ 3│ 4│ 4│ 5│ 3│ 4│ 4│  36   │  72      │
│ Score│ 3│ 5│ 3│ 4│ ·│  │  │  │  │  15   │  48      │
└──────┴──┴──┴──┴──┴──┴──┴──┴──┴──┴───────┴──────────┘
```

**Score cell coloring:**
| Score vs Par | Color | Indicator |
|-------------|-------|-----------|
| ≤ -3 (Double Eagle+) | Gold | Circle with "2" |
| -2 (Eagle) | Gold | Double circle |
| -1 (Birdie) | Red/Circle | Circle |
| 0 (Par) | Black/White | Plain |
| +1 (Bogey) | Blue | Square |
| +2 (Double Bogey) | Dark Blue | Double square |
| +3+ (Triple+) | Dark Blue | Triple square |

**Current hole indicator:** The hole being played gets a subtle highlight/underline. Unplayed holes show empty cells.

**Position:** Bottom-left of screen, semi-transparent background (alpha 0.85). Does not overlap with existing BottomBar.

**Size:** Compact — approximately 500×120 pixels. Scales down to single-row format if course has ≤9 holes (skip the IN row).

---

### 4. Group Scorecard

When the followed golfer is in a group (2–4 players), expand the scorecard to show all group members:

```
┌──────────────────────────────────────────────────────┐
│ Group 3  │  Hole 7  │  Par 4                         │
├──────────┼──┬──┬──┬──┬──┬──┬──┬──┬──┬───────────────┤
│ Par      │ 4│ 3│ 5│ 4│ 4│ 3│ 4│ 5│ 4│  36           │
├──────────┼──┼──┼──┼──┼──┼──┼──┼──┼──┼───────────────┤
│►Anderson │ 4│ 2│ 5│ 3│ 4│ 3│ ·│  │  │  -1           │
│ Williams │ 5│ 3│ 4│ 4│ 5│ 3│ ·│  │  │  +2           │
│ Chen     │ 4│ 3│ 5│ 4│ 4│ 2│ ·│  │  │  E            │
└──────────┴──┴──┴──┴──┴──┴──┴──┴──┴──┴───────────────┘
```

- `►` marker indicates the followed golfer
- Running score-to-par shown in rightmost column (color-coded)
- All group members' rows update in real-time as they complete holes
- Click another golfer's name row to switch follow target within the group

---

### 5. Quick-Switch Between Golfers

**Keyboard shortcuts:**
- `Tab` — cycle to next active golfer (wraps around)
- `Shift+Tab` — cycle to previous active golfer
- Number keys `1`–`4` — select golfer within current group (if following a group member)

**Golfer list (optional enhancement):**
- Small floating panel showing all active golfers with name, tier icon, and current hole
- Click to follow
- Sorted by group, then by hole number

---

### 6. Enhanced Thought Bubbles in Follow Mode

When following a golfer, enhance the existing thought bubble system:

**Current behavior:** `ThoughtBubble` appears above golfer head, floats up, fades in 2.5 seconds. `FeedbackManager` tracks daily satisfaction metrics from these triggers.

**Follow mode enhancements:**
- Thought bubbles for the followed golfer last longer (4.0s instead of 2.5s)
- Thought bubbles appear larger when camera is zoomed in
- Additional thought triggers when following:
  - After a great shot: "Perfect drive!" / "Nailed it!"
  - After a poor shot: "Ugh, pulled it left" / "Into the bunker..."
  - On approach to facilities: "Could use a snack" / "Need a rest"
  - On seeing course features: "Beautiful hole" / "This green is tough"
- These additional thoughts only fire in follow mode (they'd be spam at course-level view)

---

### 7. Round Summary Popup (Enhanced)

Replace the current 5-second toast with a full scorecard popup when the followed golfer finishes:

**Full round summary:**
```
┌────────────────────────────────────────────┐
│         ROUND COMPLETE                     │
│         Pro Anderson                       │
│                                            │
│  [Full 18-hole scorecard grid]             │
│                                            │
│  Total: 69 (-3)                            │
│  Best Hole: Birdie on #2 (Par 3)           │
│  Worst Hole: Bogey on #1 (Par 4)           │
│                                            │
│  Satisfaction: Very Happy (0.85)           │
│  Paid: $1,800 (18 holes × $100)            │
│  Spent at facilities: $45                  │
│                                            │
│  [Close]                                   │
└────────────────────────────────────────────┘
```

- Only shows for the **followed** golfer (non-followed golfers still get the existing 5-second toast)
- Manual dismiss required (click Close or press Escape)
- After dismissal, follow mode exits and camera returns to free-roam

---

### 8. Tournament Integration

When following a golfer during a tournament (Spec: Simulated Tournament Rounds):

**Additional UI elements:**
- Leaderboard position badge next to golfer name: "T3" (tied 3rd)
- Score-to-par in context of the field: "5 back of leader"
- After each hole, brief flash showing position movement: "↑ Moved to 3rd"

**During tournament simulation (fast-forward):**
- Follow mode pauses if the followed golfer is being simulated (headless)
- Notification: "Tournament simulation in progress — follow mode will resume when [Name] is playing live"
- If all golfers are simulated, follow mode exits

---

## Signals

### New EventBus signals:
```gdscript
signal follow_mode_entered(golfer_id: int)
signal follow_mode_exited()
signal follow_target_changed(old_id: int, new_id: int)
```

### Existing signals consumed:
- `golfer_selected(golfer)` — enter follow mode
- `state_changed(old_state, new_state)` — camera behavior transitions
- `golfer_finished_hole(id, hole, strokes, par)` — update scorecard
- `golfer_finished_round(id, total, par)` — show round summary
- `golfer_left_course(id)` — exit follow mode if following this golfer
- `shot_taken(id, hole, strokes)` — scorecard stroke counter
- `ball_in_hole(id, hole)` — hole completion animation

---

## Implementation Components

### New files:
- `scripts/systems/follow_mode.gd` — Follow mode state machine, camera control logic
- `scripts/ui/live_scorecard.gd` — Scorecard overlay panel
- `scripts/ui/enhanced_round_summary.gd` — Full scorecard round summary popup

### Modified files:
- `scripts/utils/isometric_camera.gd` — Add follow-mode target tracking, state-based zoom/pan
- `scripts/entities/golfer.gd` — Expose shot target data for follow-mode camera, extended thought triggers
- `scripts/ui/thought_bubble.gd` — Configurable duration, follow-mode size scaling
- `scripts/main/main.gd` — Wire follow mode signals, manage scorecard lifecycle
- `scripts/autoload/event_bus.gd` — Add follow mode signals

---

## Implementation Sequence

```
Phase 1 (Core Follow Mode):
  1. FollowMode class — state machine, enter/exit, target tracking
  2. Camera integration — smooth follow with state-based zoom
  3. Follow mode UI indicators (name label, highlight ring)
  4. Escape/click-empty to exit

Phase 2 (Live Scorecard):
  5. LiveScorecard panel — single golfer, front/back nine layout
  6. Score cell coloring (birdie circles, bogey squares)
  7. Real-time updates on golfer_finished_hole signal
  8. Group scorecard expansion

Phase 3 (Polish):
  9. Quick-switch (Tab cycling, number keys for group)
  10. Enhanced thought bubbles in follow mode
  11. Enhanced round summary popup (full scorecard)
  12. Camera behavior per golfer state (zoom on swing, track ball flight)

Phase 4 (Integration):
  13. Tournament leaderboard position badge
  14. Follow mode during tournament play
```

---

## Success Criteria

- Player can click any golfer to smoothly enter follow mode with camera tracking
- Live scorecard updates after each hole with correct score coloring
- Camera zooms slightly on swing and tracks ball flight for shots >3 tiles
- Group scorecard shows all group members' scores simultaneously
- Pressing Escape cleanly exits follow mode and returns to free-roam
- Tab cycles through all active golfers on the course
- Enhanced round summary shows full scorecard with best/worst hole analysis
- Follow mode works during tournament play with leaderboard position shown
- Camera motion feels smooth and cinematic, not jarring or robotic

---

## Out of Scope

| Feature | Reason |
|---------|--------|
| Replay/rewind of shots | Requires recording shot data — significant complexity |
| Picture-in-picture camera | Multi-viewport rendering — performance cost on web |
| Commentary/narration text | Audio design dependency (Spec: Audio Design) |
| Automated director mode | AI-driven camera switching — defer to post-career-mode |
| Shot trail visualization | Ball flight already shows arc — adding trails is visual clutter |
| Slow-motion replay | Requires time manipulation system |
