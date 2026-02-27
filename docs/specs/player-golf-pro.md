# Player Golf Pro — Feature Spec

## Overview

Players can create and develop their own golf pro to play the courses they build. The pro starts as a beginner with modest initial skill points, improves through XP earned by playing well, and can enter tournaments hosted on the player's course. This transforms OpenGolf Tycoon from a pure management sim into a hybrid where you both *build* the course and *play* it.

The existing `GameMode.PLAYING` enum value (currently reserved/unused) becomes the home for this feature.

---

## 1. Player Pro Creation

### 1.1 Setup Flow

When the player first clicks "Play Course" (available during SIMULATING mode), a **Pro Creation Panel** appears:

- **Name Input** — Free-text field for the pro's name (default: "Player 1")
- **Appearance** — Select from a set of shirt/hat color combinations (purely cosmetic; reuses existing golfer sprite with a distinct accent color or outline glow so the player pro is always visually identifiable)
- **Initial Skill Point Allocation** — The player is given **8 skill points** to distribute across 5 skills (see 2.2). Each skill starts at a base value and each point raises it by a fixed increment. This forces meaningful early-game trade-offs (e.g., "do I invest in driving distance or putting?")

### 1.2 Persistence

The player pro is saved as part of `SaveManager` data (new top-level `"player_pro"` key). Unlike AI golfers who are transient, the player pro persists across sessions:

```
player_pro: {
    name: String,
    appearance: int,           # Color preset index
    skills: { driving, accuracy, putting, recovery, wind_reading },
    miss_tendency: float,
    xp: int,
    level: int,
    available_skill_points: int,
    total_rounds_played: int,
    best_round_score: int,     # Best total strokes (absolute)
    best_round_to_par: int,    # Best score relative to par
    eagles: int,
    birdies: int,
    pars: int,
    bogeys: int,
    holes_in_one: int,
    tournament_wins: int,
    is_on_course: bool,        # Currently playing a round
    current_round_state: {}    # Mid-round state if on course (see 5.5)
}
```

---

## 2. Skill System

### 2.1 The Five Skills

The player pro uses the same 4 core skills as AI golfers, plus one new skill:

| Skill | Effect | Existing? |
|-------|--------|-----------|
| **Driving** | Max distance on long clubs (Driver, FW Wood). Higher = longer carries. | Yes |
| **Accuracy** | Shot dispersion angle. Higher = tighter cone. Affects all clubs. | Yes |
| **Putting** | Putt make rate and miss distance. Higher = more makes, shorter misses. | Yes |
| **Recovery** | Effectiveness from trouble lies (rough, bunker, trees). | Yes |
| **Wind Reading** | Accuracy of the projected wind-affected landing zone (new — see 7.3). | **New** |

### 2.2 Starting Stats & Point Allocation

**Base values** (before any allocation):

| Skill | Base Value |
|-------|-----------|
| Driving | 0.30 |
| Accuracy | 0.30 |
| Putting | 0.30 |
| Recovery | 0.30 |
| Wind Reading | 0.20 |

**Per skill point:** +0.05 to any skill.

**Initial points:** 8 points.

This means a player who dumps all 8 points into one skill reaches 0.70 (low-Serious tier), while spreading evenly reaches 0.38 across the board (still solidly Beginner). The trade-off is intentional — specialization makes you competent in one area but fragile elsewhere.

**Skill cap:** 0.95 (reserve 0.96–1.0 as "superhuman" zone that even pros can't reach, keeping challenge alive).

### 2.3 Miss Tendency

At creation, the player pro is assigned a random `miss_tendency`:
- **Magnitude:** 0.3–0.6 (moderate beginner bias)
- **Direction:** Random (hook or slice)

Miss tendency is **not directly upgradeable** with skill points. Instead, it naturally reduces as accuracy improves (the angular dispersion model already scales tendency effect by `(1.0 - total_accuracy)`). A player who invests heavily in accuracy will see their slice/hook tighten over time. This mirrors real golf — you don't "fix" a slice by reading about it, you fix it by getting more accurate.

---

## 3. XP & Progression

### 3.1 XP Sources

XP is earned by playing rounds. Better play earns more XP.

| Action | XP Award |
|--------|----------|
| Complete a hole | 10 |
| Par | 15 |
| Birdie (-1) | 40 |
| Eagle (-2) | 100 |
| Albatross (-3) | 300 |
| Hole-in-one | 500 |
| Break personal best round score | 75 |
| Break the course record | 200 |
| Complete a full round (all holes) | 50 |
| Win a tournament (any tier) | See 3.3 |

XP for completion (the base 10 per hole + 50 for round) ensures that even a bad round progresses the player, avoiding frustration.

### 3.2 Leveling

| Level | Cumulative XP Required | Skill Points Earned |
|-------|----------------------|---------------------|
| 1 | 0 (start) | 8 (initial) |
| 2 | 150 | 2 |
| 3 | 350 | 2 |
| 4 | 600 | 2 |
| 5 | 1,000 | 2 |
| 6 | 1,500 | 2 |
| 7 | 2,200 | 2 |
| 8 | 3,100 | 2 |
| 9 | 4,200 | 2 |
| 10 | 5,500 | 3 |
| 11 | 7,000 | 3 |
| 12 | 9,000 | 3 |
| 13 | 11,500 | 3 |
| 14 | 14,500 | 3 |
| 15 | 18,000 | 3 |

**Total at max level:** 8 + (8 × 2) + (6 × 3) = 42 skill points.

At 42 points × 0.05 per point = 2.10 total skill increase spread across 5 skills. If distributed evenly: each skill reaches ~0.72 (Serious tier). If specialized into 3 skills: those reach ~0.80–0.85 with the others lagging around 0.45–0.50. This ceiling means the player pro can become *good* but never trivially dominant — course design still matters.

### 3.3 Tournament XP Bonuses

| Tournament Tier | Participation XP | Win XP | Top 3 XP |
|----------------|------------------|--------|----------|
| LOCAL | 50 | 150 | 100 |
| REGIONAL | 100 | 400 | 250 |
| NATIONAL | 200 | 800 | 500 |
| CHAMPIONSHIP | 400 | 1,500 | 1,000 |

### 3.4 Skill Point Spending

When the player earns skill points, they can allocate them immediately via a **Level Up Panel** that appears on level-up, or later through the **Pro Stats Panel** (accessible any time from the HUD). Unspent points are banked.

---

## 4. Sending the Pro Out to Play

### 4.1 Entry Point

A **"Play Course"** button appears in the HUD during SIMULATING mode (when the course is open and has at least 1 hole). Clicking it:

1. If the player has no pro yet → opens Pro Creation Panel (see 1.1)
2. If the pro is already on course → shows message: *"Your pro is already playing. Follow them or wait for them to finish."*
3. If the pro just finished a round → shows the Round Summary first (see 10.2) before allowing a new round
4. Otherwise → sends the pro out to play

### 4.2 Round Start

When the pro is sent out:

1. The pro golfer entity is spawned at the first hole's tee box
2. The pro joins the course as a **solo player** (group size 1) — no AI group mates
3. The pro follows the standard hole order (hole 1, 2, 3, etc.)
4. The game mode transitions: `SIMULATING → PLAYING`
5. The game speed is set to `NORMAL` (no fast-forward while player is actively playing)
6. The camera centers on the pro's ball position
7. The **Score Tracker** overlay appears (see 10.1)
8. AI golfers continue playing in the background (they don't freeze), but the game is effectively real-time during the player's round

### 4.3 Round-in-Progress Lock

**The pro must complete all holes before the player can start another round.** There is no quitting mid-round. This prevents XP farming by replaying only easy holes.

If the player switches back to BUILDING or SIMULATING mode while the pro is on-course, the pro continues playing **autonomously using AI** (same ShotAI as regular golfers, but with the player pro's actual skills). The player can return to PLAYING mode at any time to resume manual control. This means:

- The player is never *trapped* in PLAYING mode
- The pro finishes their round even if the player wants to build
- When the player re-enters PLAYING mode, the camera snaps to the pro's current position and control resumes from wherever the AI left off

### 4.4 Interaction with Game Time

While in PLAYING mode, game time still advances but at a fixed rate (1x speed). The player cannot fast-forward time. Each shot takes a realistic amount of game-time (walking to ball, shot animation, ball flight). A full 9-hole round takes roughly 2–3 in-game hours, and 18 holes takes 4–5 hours.

If the in-game day ends (8 PM) while the pro is still playing:
- The pro is allowed to **finish their current hole** (golf etiquette — you don't stop mid-hole)
- After completing the current hole, the round ends as a **partial round**
- Partial rounds still earn per-hole XP but not the "complete a full round" bonus
- This encourages players to send their pro out early enough to finish

---

## 5. Shot Interaction — The Player's Turn

### 5.1 Turn Flow

When the player pro reaches their ball, the game enters **shot selection mode**:

```
Pro reaches ball
    ↓
Camera centers on ball, zooms to shot view
    ↓
Club Selection UI appears (bottom of screen)
    ↓
Player selects club (or accepts AI recommendation)
    ↓
Shot type selector appears
    ↓
Player moves mouse to choose landing zone
    ↓
Landing zone indicator + wind projection + shot arc update in real-time
    ↓
Player clicks to confirm shot
    ↓
Shot executes using existing accuracy/dispersion model
    ↓
Ball flight animation plays
    ↓
Camera follows ball to landing
    ↓
Pro walks to ball → next shot (or hole complete)
```

### 5.2 Club Selection

A horizontal club bar appears at the bottom of the screen showing all 5 clubs:

```
┌─────────┬───────────────┬────────┬─────────┬──────────┐
│ DRIVER  │ FAIRWAY WOOD  │  IRON  │  WEDGE  │  PUTTER  │
│  1      │      2        │   3    │    4    │    5     │
│ 284 yds │   220 yds     │ 178 yds│  99 yds │  22 yds  │
└─────────┴───────────────┴────────┴─────────┴──────────┘
```

- Each club shows its max carry distance (based on the player's current driving/accuracy skill and the `_get_skill_distance_factor()` formula)
- Clubs are selectable via click or number keys **1–5**
- The AI-recommended club is highlighted with a subtle indicator
- Clubs inappropriate for the current lie are dimmed (e.g., Driver from heavy rough)
- On the green, only PUTTER is available

### 5.3 Shot Types

After selecting a club, the player chooses a shot type. Available types depend on the club:

| Shot Type | Available Clubs | Effect |
|-----------|----------------|--------|
| **Normal** | All | Standard shot. Full distance, standard accuracy. |
| **Power** | Driver, FW Wood, Iron | +10% distance, -15% accuracy (wider dispersion). |
| **Punch** | Iron, Wedge | -30% distance, +20% accuracy. Lower trajectory — useful for wind or under trees. |
| **Flop** | Wedge | -40% distance, +10% accuracy. High trajectory, minimal roll. Good for clearing obstacles near the green. |
| **Chip** | Wedge | Short game only (<50 yards). Very high accuracy floor (0.90+). Low trajectory, controlled roll. |
| **Putt** | Putter | Standard putt. Uses putting accuracy model. |

Shot type is selected via a radial menu or button row that appears above the club bar. Default is always **Normal**.

### 5.4 Landing Zone Selection

Once club and shot type are chosen, the player **moves their mouse** across the course to select a landing zone:

- A **target reticle** appears at the mouse cursor position, snapped to valid landing tiles
- The target reticle is constrained to the club's max distance radius from the ball
- If the player moves the mouse beyond max range, the reticle clamps to the nearest point on the max range circle

**Two indicators are shown simultaneously** (see sections 7 and 8 for full detail):

1. **Target Reticle (no wind)** — Where the player is aiming. This is the "intended" landing spot assuming zero wind and perfect accuracy.
2. **Projected Landing Zone (with wind)** — An ellipse/cone showing where the ball will *actually* land after wind pushes it. The size and accuracy of this projection depend on the **Wind Reading** skill.

### 5.5 Mid-Round State (for Save/Load & AI Handoff)

When the player pro is on-course, the following state is tracked for save/load and for AI continuation:

```
current_round_state: {
    current_hole_index: int,
    current_strokes: int,
    total_strokes: int,
    total_par: int,
    ball_position: Vector2i,
    ball_position_precise: Vector2,
    hole_scores: Array[{hole, strokes, par}],
    is_player_controlled: bool   # false if AI took over
}
```

---

## 6. Shot Execution & Outcome

### 6.1 Accuracy Model

Player pro shots use the **exact same angular dispersion model** as AI golfers. The player picks *where* to aim (the target), but the *result* is determined by:

- `total_accuracy = club_accuracy_modifier × skill_accuracy × lie_modifier`
- Gaussian miss angle: `miss_angle = gaussian() × spread_std_dev + tendency_bias`
- Shank probability: `(1.0 - total_accuracy) × 4%`
- Distance variance: Same per-club gaussian modifiers

This is critical: the player controls *strategy* (club choice, landing zone, shot type), but the *execution* is skill-dependent. A beginner pro will spray shots even with a perfect plan. As skills improve, the gap between intention and outcome narrows. This creates a satisfying progression arc.

### 6.2 Shot Result Feedback

After each shot, the player sees:

- Ball flight animation (existing system, camera follows)
- **Distance text** floats above the ball: "245 yds" (or "32 ft" for putts)
- **Result text** appears briefly:
  - Great shots: "On the green!", "In the fairway", "Nice approach"
  - Trouble: "In the rough", "Bunker!", "In the water!", "Out of bounds!"
  - Putts: "Sinks it!", "Lip out", "Just missed"
- **Score update** on the Score Tracker (see 10.1)

### 6.3 Putting

When on the green:
- Club auto-selects to PUTTER
- The **shot arc preview** changes to a **putt line** (flat, along the ground)
- The target reticle shows a small circle at the mouse position
- A **break indicator** shows the green slope direction (arrow overlay on the green) — read accuracy is blended with putting skill similar to `ShotAI._decide_putt()` green-reading logic
- Wind does not affect putts (existing behavior: putter wind sensitivity = 0.0)

---

## 7. Landing Zone Display — No-Wind Target

### 7.1 Target Reticle

The player's mouse position determines the target. A **crosshair reticle** marks the exact aim point. This represents: "Where you are trying to hit the ball, ignoring wind."

### 7.2 Accuracy Cone (No Wind)

Around the target reticle, an **accuracy ellipse** is drawn representing the shot dispersion:

- **Size** is derived from the angular dispersion model:
  - `max_spread_deg = (1.0 - total_accuracy) × 12.0`
  - At the target distance, this angular spread translates to a lateral width
  - `lateral_spread_tiles = distance × tan(max_spread_deg in radians)`
- **Shape**: An ellipse elongated along the shot direction (distance variance > lateral variance)
- **Color**: Semi-transparent white/light blue
- **Opacity**: ~30% fill, solid outline
- The ellipse represents the ~95% confidence zone (2 standard deviations) — most shots land inside this area

As the player's accuracy skill improves, this ellipse visibly shrinks, providing clear visual feedback of progression.

---

## 8. Projected Landing Zone — With Wind

### 8.1 Wind-Adjusted Projection

A second indicator shows where the ball will **actually** land after wind displacement:

- **Position**: The no-wind target reticle position **plus** the calculated wind displacement vector
- **Wind displacement** uses the existing `WindSystem.get_wind_displacement(shot_direction, distance, club)` formula
- This gives the player a critical planning tool: "I'm aiming *here*, but the wind will push the ball *there*"

### 8.2 Wind Reading Skill — Projection Accuracy

The key innovation: **the projected wind zone is not perfectly accurate.** Its precision depends on the player pro's **Wind Reading** skill:

| Wind Reading Skill | Projection Error | Visual Effect |
|-------------------|------------------|---------------|
| 0.20 (starting) | ±60% of actual wind displacement | Large, blurry ellipse. Almost useless — you know wind exists but not how much. |
| 0.40 | ±40% | Moderately sized zone. Gives a general direction. |
| 0.60 | ±20% | Tighter zone. Useful for planning. |
| 0.80 | ±10% | Quite accurate. Experienced wind reader. |
| 0.95 (cap) | ±3% | Near-perfect. You can trust the projection. |

**Implementation:**

```
actual_wind_displacement = WindSystem.get_wind_displacement(...)

# Add error based on wind reading skill
error_factor = 1.0 - wind_reading_skill  # 0.80 at start, 0.05 at cap
error_magnitude = error_factor * 0.75     # Max ±60% error at 0.20 skill

# Random error offset (consistent per-shot, re-randomized each new shot setup)
error_x = randf_range(-error_magnitude, error_magnitude) * actual_wind_displacement.x
error_y = randf_range(-error_magnitude, error_magnitude) * actual_wind_displacement.y

displayed_displacement = actual_wind_displacement + Vector2(error_x, error_y)
```

The error is randomized **once** when the player starts aiming (not every frame), so the projection doesn't jitter. It re-randomizes when the player changes clubs or shot type.

### 8.3 Wind Zone Visual

The wind-projected landing zone is shown as:

- **Ellipse** centered at the wind-displaced position
- **Size** reflects the uncertainty from wind reading skill:
  - Low skill → large fuzzy ellipse (could land anywhere in this area)
  - High skill → tight ellipse nearly matching the no-wind accuracy cone
- **Color**: Semi-transparent orange/amber (distinct from the white no-wind cone)
- **Connecting line**: A dashed line from the no-wind target to the wind-projected center, showing the wind push direction and magnitude

### 8.4 Wind Arrow Overlay

A wind direction arrow appears in the top-right corner of the screen (or near the ball) during shot selection:
- Arrow rotates to match current wind direction
- Length scales with wind speed
- Text label shows: "12 mph NW" (speed + compass direction)
- Uses existing `WindSystem.get_direction_text()` and `wind_speed`

---

## 9. Shot Arc Preview

### 9.1 Arc Visualization

While the player is aiming, a **shot arc** is drawn from the ball to the target:

- **3D-projected parabolic curve** rendered as a dotted/dashed line in the isometric view
- The arc height matches the existing `Ball` flight arc formula: `height = sin(progress × PI) × max_height`
- `max_height = min(distance × 0.3, 150px)` (same as `Ball` entity)
- The arc updates in real-time as the player moves their mouse

### 9.2 Arc Details by Shot Type

| Shot Type | Arc Shape |
|-----------|-----------|
| Normal | Standard parabola |
| Power | Slightly flatter, longer arc |
| Punch | Low, piercing trajectory — peak height reduced by 60% |
| Flop | Very high, steep arc — peak height increased by 50%, shorter distance |
| Chip | Low bump arc, rolls out on landing |
| Putt | Flat line along the ground (no arc) |

### 9.3 Arc Rendering

- **Line style**: Dashed line (6px dash, 4px gap) for the flight portion
- **Color**: White with slight transparency, transitions to the wind-zone color (orange) past the carry point to indicate rollout
- **Landing dot**: A solid circle at the carry point (where ball first hits ground)
- **Rollout segment**: A second dashed line from carry point to final resting position (shorter, ground-level), showing estimated roll based on landing terrain
- The arc is purely cosmetic — it shows the *intended* trajectory, not the actual result (which includes dispersion)

### 9.4 Putt Line

On the green, the arc is replaced by:
- A **flat line** from ball to target
- A **break curve** if slope is present — the line bends to show how the player is reading the green
- The green slope direction is shown as subtle arrows overlaid on the green tiles

---

## 10. On-Screen Score Tracker

### 10.1 Score Tracker HUD

A persistent overlay during PLAYING mode, docked to the top-right corner:

```
┌──────────────────────────────┐
│  PLAYER NAME         Lv. 5  │
├──────────────────────────────┤
│  Hole  3 / 9     Par 4      │
│  Stroke  2                   │
│                              │
│  ──────────────────────────  │
│  Hole │ 1  │ 2  │ 3  │ ...  │
│  Par  │ 4  │ 3  │ 4  │      │
│  Score│ 5  │ 3  │ -  │      │
│  ──────────────────────────  │
│                              │
│  Total:  +1 (8 strokes)     │
│  Thru:   2 holes             │
└──────────────────────────────┘
```

**Features:**
- Shows current hole number, par, and stroke count
- Scrollable scorecard grid (hole-by-hole results)
- Color coding: red for bogey+, white for par, green for birdie, gold for eagle+
- Running total relative to par ("+3", "E", "-2")
- Total absolute strokes and holes completed
- Compact enough not to obscure gameplay (expandable on hover/click)

### 10.2 Round Summary

When the round completes (all holes finished or day ends), a **Round Summary Panel** appears:

```
┌──────────────────────────────────────┐
│          ROUND COMPLETE              │
│                                      │
│  Course: Windy Pines     Day 14      │
│  Player: Alex Torres     Lv. 5       │
│                                      │
│  SCORECARD                           │
│  Hole │ 1  2  3  4  5  6  7  8  9   │
│  Par  │ 4  3  5  4  4  3  4  5  4   │
│  Score│ 5  3  6  4  3  4  4  5  5   │
│                                      │
│  Total: 39 (+3)                      │
│  Best Round: 37 (+1) on Day 10       │
│                                      │
│  HIGHLIGHTS                          │
│   Birdie on Hole 5                   │
│   Personal best on Hole 2            │
│                                      │
│  XP EARNED                           │
│   9 holes completed ......... 90     │
│   1 birdie .................. 40     │
│   4 pars .................... 60     │
│   Full round bonus .......... 50     │
│                        Total: 240    │
│                                      │
│  ████████████████░░░░ 740/1000 XP    │
│                                      │
│         [ Continue ]                 │
└──────────────────────────────────────┘
```

If the player leveled up, an additional **Level Up Panel** appears after the summary, prompting skill point allocation (see 3.4).

---

## 11. Player Pro in Tournaments

### 11.1 Tournament Entry

When a tournament is scheduled on the player's course, a new option appears: **"Enter Pro in Tournament"**.

Requirements:
- The player pro must exist (created at least once)
- The pro must not currently be on-course (round-in-progress lock)
- The pro must meet a minimum level for the tournament tier:

| Tournament Tier | Min Player Level |
|----------------|-----------------|
| LOCAL | 1 (any) |
| REGIONAL | 3 |
| NATIONAL | 6 |
| CHAMPIONSHIP | 10 |

### 11.2 Tournament Play

When the player pro enters a tournament:

1. The pro is added to the tournament participant list alongside AI golfers
2. The player can choose to **play manually** or **let the AI play** for their pro
3. If playing manually:
   - Same shot interaction as regular play (sections 5–9)
   - The tournament leaderboard (existing UI) updates with the pro's scores alongside AI golfers
   - Between holes, AI golfers continue their rounds in the background
4. If AI plays:
   - The pro uses ShotAI with their actual skill stats
   - The player watches or fast-forwards (game speed unlocked for AI tournament play)

### 11.3 Tournament Results

After the tournament:
- The player pro's final position is shown on the leaderboard
- XP is awarded based on tier + placement (see 3.3)
- Tournament wins are tracked in the pro's career stats
- If the pro wins, a special celebration animation plays (reuse/extend HoleInOneCelebration)

### 11.4 Tournament Leaderboard Integration

The existing `TournamentLeaderboard` is extended to highlight the player pro's row:
- Pro row gets a distinct background color (gold/highlight)
- Pro row is always visible (pinned) even when scrolling through other participants
- Position indicator: "T3" (tied 3rd), "1st", etc.

---

## 12. Camera Behavior

### 12.1 During Shot Selection

- Camera centers on the ball position with a moderate zoom level
- As the player moves the mouse toward distant landing zones, the camera **pans smoothly** to keep both the ball and the target visible (or at least the target area)
- Zoom level adjusts based on shot distance: short chips keep tight zoom, driver shots zoom out

### 12.2 During Ball Flight

- Camera follows the ball during flight (existing behavior from `Ball` entity)
- After the ball lands, the camera smoothly pans to the final resting position
- Brief pause (0.5s) to let the player see the result, then transition to next-shot state

### 12.3 Free Camera

- During shot selection, the player can hold **middle mouse button** to temporarily free the camera and look around the course (scout the hole)
- Releasing returns the camera to the ball
- The player can also press **Tab** to get an overhead view of the entire hole (hole layout preview)

---

## 13. Pro Stats Panel

Accessible from the HUD at any time (hotkey **P**), this panel shows:

```
┌──────────────────────────────────────┐
│          PRO STATS                   │
│                                      │
│  Alex Torres           Level 7       │
│  XP: 2,450 / 3,100    ████████░░    │
│  Unspent Points: 2                   │
│                                      │
│  SKILLS                              │
│  Driving ........ 0.55  [+]          │
│  Accuracy ....... 0.60  [+]          │
│  Putting ........ 0.50  [+]          │
│  Recovery ....... 0.40  [+]          │
│  Wind Reading ... 0.35  [+]          │
│                                      │
│  Miss Tendency: Slight Fade (0.25)   │
│                                      │
│  CAREER STATS                        │
│  Rounds Played .......... 23         │
│  Best Round ............. +1 (37)    │
│  Holes-in-One ........... 0          │
│  Eagles ................. 1          │
│  Birdies ................ 12         │
│  Tournament Wins ........ 0          │
│                                      │
│  CLUB DISTANCES (max carry)          │
│  Driver ......... 214 yds            │
│  FW Wood ........ 176 yds            │
│  Iron ........... 145 yds            │
│  Wedge .......... 92 yds             │
│  Putter ......... 21 yds             │
│                                      │
│         [ Close ]                    │
└──────────────────────────────────────┘
```

The `[+]` buttons are only active when the player has unspent skill points.

---

## 14. Visual Differentiation

The player pro must be visually distinct from AI golfers:

- **Outline glow**: A colored outline (player-selected accent color) around the pro's sprite
- **Name label**: The pro's name is always displayed above their head (AI golfer names only show on hover)
- **Ball marker**: The pro's ball uses a distinct color or a small flag marker so it's identifiable at a distance
- **Mini-map icon**: A distinct icon on the mini-map for the pro (star or diamond shape vs. dots for AI golfers)

---

## 15. Integration Points

### 15.1 New Signals (EventBus)

```gdscript
# Player pro lifecycle
signal player_pro_created(pro_name: String)
signal player_pro_round_started(hole_count: int)
signal player_pro_shot_taken(club: int, shot_type: int, result: Dictionary)
signal player_pro_hole_completed(hole_number: int, strokes: int, par: int)
signal player_pro_round_completed(total_strokes: int, total_par: int)
signal player_pro_xp_gained(amount: int, source: String)
signal player_pro_leveled_up(new_level: int, skill_points: int)
signal player_pro_entered_tournament(tier: int)

# Shot interaction
signal shot_selection_started()
signal shot_selection_confirmed(target: Vector2i, club: int, shot_type: int)
signal shot_selection_cancelled()
```

### 15.2 New & Modified Files

| File | Status | Purpose |
|------|--------|---------|
| `scripts/entities/player_pro.gd` | **New** | Extends Golfer. Adds XP, leveling, career stats, manual shot interface. |
| `scripts/systems/player_progression.gd` | **New** | XP tables, level-up logic, skill point allocation. |
| `scripts/ui/shot_selection_ui.gd` | **New** | Club bar, shot type selector, landing zone display. |
| `scripts/ui/shot_arc_preview.gd` | **New** | Parabolic arc rendering that follows the mouse. |
| `scripts/ui/wind_projection.gd` | **New** | Wind-adjusted landing zone display with skill-based error. |
| `scripts/ui/score_tracker.gd` | **New** | On-screen scorecard during play. |
| `scripts/ui/pro_creation_panel.gd` | **New** | Pro setup screen (name, appearance, initial skill allocation). |
| `scripts/ui/pro_stats_panel.gd` | **New** | Career stats and skill point spending. |
| `scripts/ui/round_summary_panel.gd` | **New** | End-of-round results and XP breakdown. |
| `scripts/ui/level_up_panel.gd` | **New** | Skill point allocation on level-up. |
| `scripts/managers/player_pro_manager.gd` | **New** | Manages pro spawning, round lifecycle, mode transitions. |
| `scripts/autoload/game_manager.gd` | **Modified** | Add PLAYING mode transitions, player pro state tracking. |
| `scripts/autoload/save_manager.gd` | **Modified** | Serialize/deserialize player pro data. |
| `scripts/autoload/event_bus.gd` | **Modified** | Add player pro and shot selection signals. |
| `scripts/managers/tournament_manager.gd` | **Modified** | Support player pro as tournament participant. |
| `scripts/ui/tournament_panel.gd` | **Modified** | Add "Enter Pro" button. |
| `scripts/ui/tournament_leaderboard.gd` | **Modified** | Highlight player pro row. |
| `scripts/main/main.gd` | **Modified** | Wire up PLAYING mode, shot selection UI, new panels. |
| `scripts/systems/wind_system.gd` | **Modified** | Expose wind reading error API for projection display. |

### 15.3 New Algorithm Doc

Create `docs/algorithms/player-progression.md` covering:
- XP formula and sources
- Level thresholds
- Skill point economy
- Wind reading error model
- Shot type modifiers

---

## 16. UX Flow Summary

```
                    ┌──────────────────────┐
                    │    SIMULATING MODE   │
                    │  (course is open)    │
                    └──────────┬───────────┘
                               │
                     Click "Play Course"
                               │
              ┌────────────────┼────────────────┐
              │ No pro exists  │  Pro exists     │  Pro on course
              ▼                ▼                 ▼
     Pro Creation Panel   Send pro out      "Already playing"
              │                │              (offer to follow)
              │                │
              ▼                ▼
         Create pro ──► Spawn at Hole 1
                               │
                    Mode → PLAYING (1x speed)
                    Score Tracker appears
                               │
                    ┌──────────▼───────────┐
                    │   Pro reaches ball   │
                    └──────────┬───────────┘
                               │
                    ┌──────────▼───────────┐
                    │  SHOT SELECTION MODE  │
                    │                      │
                    │  1. Pick club (1-5)  │
                    │  2. Pick shot type   │
                    │  3. Move mouse for   │
                    │     landing zone     │
                    │  4. See:             │
                    │   - Accuracy cone    │
                    │   - Wind projection  │
                    │   - Shot arc preview │
                    │  5. Click to shoot   │
                    └──────────┬───────────┘
                               │
                    ┌──────────▼───────────┐
                    │  SHOT EXECUTES       │
                    │  (dispersion model)  │
                    │  Ball flight anim    │
                    │  Camera follows      │
                    └──────────┬───────────┘
                               │
                    ┌──────────▼───────────┐
                    │  Ball at rest        │
                    │  Score updates       │
                    │  Holed? ─────────────┼──► Hole complete
                    │  No → walk to ball   │    Next hole or
                    │       → next shot    │    round summary
                    └──────────────────────┘
                               │
                    ┌──────────▼───────────┐
                    │   ROUND COMPLETE     │
                    │  Round Summary Panel │
                    │  XP awarded          │
                    │  Level up? → Points  │
                    │  Mode → SIMULATING   │
                    └──────────────────────┘
```

---

## 17. Open Questions

1. **Multiplayer future-proofing**: Should the pro system be designed to support a second local player eventually (split-screen or hot-seat)?
2. **Difficulty scaling**: Should the player pro's XP gains scale with course difficulty? Harder courses could offer an XP multiplier.
3. **Practice mode**: Should there be a "practice hole" option where the player can replay a single hole without affecting career stats?
4. **Club upgrades**: Should the player be able to buy better clubs (from the Pro Shop building) that improve club-specific stats? This would tie the tycoon and golf-playing systems together.
5. **Fatigue**: Should the player pro use the existing `GolferNeeds` system, or should player-controlled pros be exempt from needs decay?
6. **Spectator mode**: When the player isn't in PLAYING mode but their pro is AI-playing, should there be a "spectate" button that follows the pro without enabling manual control?
