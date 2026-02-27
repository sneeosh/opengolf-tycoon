# Simulated Tournament Rounds — Product Spec

**Author:** Claude (Product)
**Date:** 2026-02-27
**Status:** Proposal
**Priority:** CRITICAL
**Version:** 0.1.0-alpha context

---

## Problem Statement

Tournaments are the endgame of OpenGolf Tycoon. Currently `TournamentManager` spawns real golfer entities that play through the course using the full shot engine, which is excellent — but only 50% of tournament participants actually play live. The `simulate_remaining_and_complete()` path uses `ShotSimulator.simulate_hole()`, a simplified statistical model (`expected = par + (1.0 - skill) * 2.0 - 0.5 + difficulty * 0.1 + gaussian_noise`) that ignores wind, weather, terrain hazards, elevation, and course layout entirely.

This means the player's course design has **partial** influence on tournament outcomes — live golfers interact with the real course, but headless-simulated golfers produce generic scores. When a player ends the day early or when groups haven't spawned yet, the remaining golfers bypass every design decision the player made.

The core promise of the game is: *design a great course and watch great golf happen on it*. Tournament outcomes must reflect course design faithfully, whether golfers play live or are simulated.

---

## Design Principles

- **Course design drives outcomes.** A tournament on a well-designed links course with strategic bunkers should produce different scoring patterns than one on a wide-open resort course. The simulation must use the real shot engine's accuracy model, wind system, and terrain interactions.
- **Speed over spectacle for simulation.** Accelerated simulation skips animations but preserves shot calculation fidelity. The player can choose to watch live or fast-forward.
- **Multi-round tournaments feel like events.** Championship tournaments span 4 rounds with cut lines — they should feel like a multi-day event, not a single scoring pass.
- **Dramatic moments surface automatically.** Eagles, holes-in-one, and leaderboard swings during simulation should be captured and reported, not lost to fast-forward.

---

## Current System Analysis

### What Works Well
- `TournamentManager` already handles scheduling, qualification, live play, and result aggregation
- `TournamentLeaderboard` UI provides real-time score display with color-coded score-to-par
- `TournamentSystem` defines tier requirements, field sizes (12–72 participants), and revenue
- Live golfers use the full shot engine (angular dispersion, wind compensation, terrain modifiers)
- `ShotSimulator` exists as a headless simulation path (used for End Day fast-forward)
- Group staggering works (30-second intervals between groups)

### What Needs Improvement
- `ShotSimulator.simulate_hole()` is a statistical stub — it doesn't use wind, weather, hazards, elevation, or course layout
- No multi-round support — all tournaments are single-round regardless of tier
- No cut line mechanics
- `simulate_remaining_and_complete()` assigns negative IDs to headless golfers — these are never visible on the leaderboard during simulation
- No dramatic moment detection — eagles and holes-in-one during simulation are untracked
- No course-design-to-outcome causality for simulated golfers
- Field sizes are fixed per tier with no variation

---

## Feature Design

### 1. Accelerated Shot Simulation Engine

Replace `ShotSimulator.simulate_hole()` with a hole-by-hole simulation that uses the real shot calculation pipeline.

**Per-hole simulation loop:**
```
1. Position golfer at tee box (tee_position from HoleData)
2. Select club using ShotAI logic (distance to pin, hazard scan, wind)
3. Calculate shot using angular dispersion model:
   - total_accuracy = club_modifier * skill * lie_modifier
   - miss_angle = gaussian_random() * spread_std_dev + tendency_bias
   - Apply wind offset (WindSystem.calculate_wind_effect)
   - Check for shank (rare catastrophic miss)
4. Determine landing position from shot angle + distance
5. Evaluate terrain at landing:
   - Water → penalty stroke + drop position
   - OOB → penalty stroke + replay
   - Bunker → lie modifier for next shot
   - Green → switch to putting
6. Repeat from step 2 until ball is holed or double-par reached
7. Record: strokes, score vs par, notable events (HIO, eagle, penalty)
```

**What to reuse from existing code:**
- `golfer.gd` shot calculation: `_calculate_shot_direction()`, `_apply_accuracy()`, `_get_lie_modifier()`
- `ShotAI` target selection: `find_best_target()`, `evaluate_landing_zone()`
- `WindSystem.calculate_wind_effect()` for wind offset
- `WeatherSystem` accuracy modifier
- `DifficultyCalculator` terrain scanning

**What to skip (for speed):**
- Ball flight animation and parabolic arcs
- Golfer walking animation between shots
- Thought bubbles and satisfaction feedback
- Visual rendering of any kind
- Group turn-order management (simulate each golfer independently)

**Performance target:** Simulate one golfer's full 18-hole round in <50ms. A 72-golfer Championship field should complete in <4 seconds.

**Implementation approach:** Create a new `TournamentSimulator` class (RefCounted, stateless) with a static `simulate_round()` method that takes golfer skills, course data, wind state, and weather, and returns a complete round scorecard.

---

### 2. Multi-Round Format

Tournaments currently play one round regardless of tier. Extend to multi-round format:

| Tier | Rounds | Days | Cut After Round |
|------|--------|------|-----------------|
| LOCAL | 1 | 1 | — |
| REGIONAL | 2 | 2 | — |
| NATIONAL | 4 | 3 | Round 2 (top 50%) |
| CHAMPIONSHIP | 4 | 4 | Round 2 (top 40 + ties) |

**Multi-round flow:**
1. **Round 1:** All participants play. Scores recorded to leaderboard.
2. **Round 2:** All participants play. After completion, cut line applied for NATIONAL/CHAMPIONSHIP.
3. **Cut line:** Top N golfers (by cumulative score-to-par) advance. Ties at the cut number are included. Eliminated golfers shown in gray on leaderboard with "MC" (missed cut) label.
4. **Rounds 3–4:** Only golfers who made the cut play. Final standings by cumulative score.

**Daily round assignment:**
- LOCAL: 1 round on day 1
- REGIONAL: 1 round per day × 2 days
- NATIONAL: Rounds 1–2 on days 1–2, rounds 3–4 on day 3 (double round on final day)
- CHAMPIONSHIP: 1 round per day × 4 days

**Between rounds:**
- Wind and weather regenerate for each new day (existing daily refresh)
- Pin positions rotate if Pin Positions feature is implemented (Course Design Upgrades 1.3)
- Leaderboard persists across rounds showing cumulative totals

---

### 3. Tournament Golfer Generation

Currently 50/50 PRO/SERIOUS split. Refine per tier:

| Tier | PRO % | SERIOUS % | Field Size | Skill Floor |
|------|-------|-----------|------------|-------------|
| LOCAL | 10% | 40% | 12–16 | 0.55 |
| REGIONAL | 30% | 50% | 20–28 | 0.65 |
| NATIONAL | 60% | 35% | 40–52 | 0.75 |
| CHAMPIONSHIP | 80% | 20% | 60–72 | 0.85 |

- Add CASUAL tier participants for LOCAL tournaments (50% of remaining)
- Generate distinct names from expanded name pool (no duplicates within a tournament)
- Each golfer gets a persistent seed for the tournament duration (consistent hook/slice tendency across rounds)
- **Marquee golfers:** CHAMPIONSHIP tournaments include 2–4 "star" golfers with skills in the 0.95–0.99 range and recognizable names, creating fan-favorite narratives

---

### 4. Scoring Distribution & Course Causality

The simulation must produce realistic scoring distributions that reflect course design:

**Target scoring distribution (relative to par, per round):**

| Score | Real PGA % | Target % (PRO-heavy) |
|-------|-----------|----------------------|
| Eagle or better | 1–2% of holes | 1–3% of par 5s |
| Birdie | 15–20% of holes | 12–18% |
| Par | 55–65% | 50–60% |
| Bogey | 15–20% | 15–22% |
| Double+ | 3–5% | 5–10% |

**Course design → scoring causality:**
- **Narrow fairways** (tight corridors) → more bogeys from offline tee shots
- **Water hazards in play** → occasional doubles/triples from penalty strokes, but also risk/reward birdie chances
- **Large greens** → fewer 3-putts, more pars
- **Small/elevated greens** → more missed greens, more bogeys but also more exciting up-and-downs
- **Strategic bunker placement** → bunker saves become dramatic moments
- **Long par 5s** → eagle opportunities for long hitters (PRO tier)
- **High wind** → increased scoring variance, more bogeys, fewer birdies
- **Rain** → accuracy penalties compound across the field

**Validation:** After simulation, compute the field's scoring average. A well-designed par-72 course should produce a field average of 72–76 depending on difficulty rating. If the average is outside 70–80, log a warning for balance tuning.

---

### 5. Live Leaderboard Enhancements

Extend `TournamentLeaderboard` for multi-round display:

**Column layout:**
```
Pos | Name           | R1  | R2  | R3  | R4  | Total | Thru
  1 | Pro Anderson   | -3  | -2  |     |     |   -5  | F
  2 | Pro Williams   | -1  | -3  |     |     |   -4  | 14
  3 | Serious Chen   |  E  | -2  |     |     |   -2  | F
 ...
CUT LINE ─────────────────────────────────────────────────
 41 | Serious Rivera | +3  | +5  |     |     |   +8  | MC
```

**Leaderboard features:**
- Scrollable list (virtual scroll for 72 entries)
- Position column with movement indicator (↑ ↓ —)
- Per-round score columns (show dash for unplayed rounds)
- "Thru" column: holes completed in current round (1–18 or "F" for finished)
- Cut line visual separator after round 2
- "MC" label for missed-cut golfers
- Color coding: under par (green), even (yellow), over par (red)
- Click golfer name to pan camera to their position (if playing live)
- Auto-scroll to leader during updates

**Update frequency:**
- During live play: update after each hole completion (existing behavior)
- During simulation: batch-update after each simulated round completes

---

### 6. Dramatic Moment Detection

Track notable events during simulation and surface them as notifications:

**Detectable moments:**
| Event | Detection | Notification Priority |
|-------|-----------|----------------------|
| Hole-in-one | Strokes == 1 on any hole | CRITICAL — pause simulation, show popup |
| Eagle | Score ≤ -2 vs par | HIGH — toast notification |
| Albatross | Score ≤ -3 vs par (par 5 in 2) | CRITICAL — pause simulation, show popup |
| Double eagle | Score ≤ -3 vs par (par 4 in 1) | CRITICAL — this is a hole-in-one on par 4 |
| Leaderboard change | New leader after a hole | MEDIUM — toast with old/new leader |
| Playoff scenario | 2+ golfers tied after final round | HIGH — announce playoff |
| Course record | Round score beats existing lowest | HIGH — toast notification |
| Collapse | Golfer drops 5+ positions in one round | LOW — info feed only |
| Comeback | Golfer gains 5+ positions in one round | LOW — info feed only |

**Moment storage:**
```gdscript
class TournamentMoment:
    var type: String          # "hole_in_one", "eagle", "lead_change", etc.
    var round: int            # Which round (1-4)
    var hole: int             # Which hole
    var golfer_name: String   # Who did it
    var detail: String        # "Eagle on Hole 7" or "Takes the lead at -5"
    var importance: int       # 0=info, 1=medium, 2=high, 3=critical
```

Moments are collected during simulation and replayed as notifications after the round, or shown in real-time during live play. Critical moments (HIO, albatross) during fast-forward should briefly pause and show a popup.

---

### 7. Prize Money & Revenue

Refine the existing revenue model:

**Prize pool distribution (top finishers):**
| Position | % of Prize Pool |
|----------|----------------|
| 1st | 30% |
| 2nd | 18% |
| 3rd | 12% |
| 4th–5th | 7% each |
| 6th–10th | 3% each |
| Remainder | Split among rest who made cut |

The player's course **pays out** the prize pool from tournament revenue (entry fees + sponsorship). This is already modeled — `TournamentSystem.get_tier_data()` defines prize pools per tier.

**Spectator revenue scaling:** Multiply base spectator revenue by a drama multiplier based on tournament moments:
- Base spectator revenue as defined in `TournamentSystem.TIER_DATA`
- +5% per eagle during the tournament
- +10% per hole-in-one
- +15% if final round has a lead change on the last 3 holes
- Cap at 1.5× base spectator revenue

---

### 8. Record Tracking Integration

Extend `CourseRecords` for tournament context:

**New record categories:**
- Tournament lowest round (per tier)
- Tournament winning score (per tier)
- Most dramatic tournament (highest moment count)
- Tournament hole-in-ones (separate from regular play HIO tracking)

**Record checking during simulation:**
After each simulated round, check `CourseRecords` for:
- New lowest round overall (if simulated score < current record)
- New best per-hole score (if any hole score beats current best)
- Record the golfer name and tournament context

---

## Data Model Changes

### TournamentManager additions:
```gdscript
var current_round: int = 0                    # 1-based round number
var total_rounds: int = 1                     # Rounds for current tier
var round_scores: Dictionary = {}             # golfer_id → Array[round_scorecards]
var cut_golfers: Array[int] = []              # IDs of golfers who made the cut
var tournament_moments: Array = []            # TournamentMoment entries
var is_simulating: bool = false               # True during accelerated sim
```

### TournamentScorecard (new inner class):
```gdscript
class TournamentScorecard:
    var golfer_id: int
    var golfer_name: String
    var round_number: int
    var hole_scores: Array[int]               # Per-hole stroke counts
    var hole_pars: Array[int]                 # Per-hole par values
    var total_strokes: int
    var total_par: int
    var moments: Array[TournamentMoment]      # Notable events this round
```

### Save/Load changes:
```gdscript
# Tournament state already resets to NONE on load if IN_PROGRESS.
# Multi-round tournaments in progress will be lost on load.
# This is acceptable — tournaments are time-bounded events.
# Add round_scores to serialization for SCHEDULED tournaments
# that haven't started yet (preserve scheduling across save/load).
```

---

## Signals

### New EventBus signals:
```gdscript
signal tournament_round_completed(tier: int, round_number: int, standings: Array)
signal tournament_cut_applied(tier: int, cut_golfers: Array, eliminated: Array)
signal tournament_moment(moment: Dictionary)
signal tournament_simulation_started(tier: int, round_number: int)
signal tournament_simulation_completed(tier: int, round_number: int)
```

---

## Algorithm Documentation

Create `docs/algorithms/tournament-simulation.md` covering:
- Accelerated shot simulation loop (step-by-step)
- Scoring distribution validation targets
- Multi-round flow with cut lines
- Dramatic moment detection criteria
- Performance benchmarks

Update `docs/algorithms/tournament-system.md` with:
- Multi-round format per tier
- Cut line mechanics
- Field composition changes
- Prize distribution model

---

## Implementation Sequence

```
Phase 1 (Foundation):
  1. TournamentSimulator class — accelerated shot simulation using real engine
  2. Validate scoring distributions against targets
  3. Replace ShotSimulator.simulate_hole() calls with TournamentSimulator

Phase 2 (Multi-Round):
  4. Multi-round state machine in TournamentManager
  5. Cut line logic after round 2
  6. Leaderboard multi-round column display
  7. Round-to-round wind/weather refresh

Phase 3 (Polish):
  8. Dramatic moment detection and notification
  9. Tournament golfer generation refinement (marquee golfers)
  10. Spectator revenue drama multiplier
  11. Record tracking integration
  12. Playoff tie-breaking (sudden death on signature hole)
```

---

## Success Criteria

- A Championship tournament on a challenging 18-hole course produces meaningfully different scoring from the same tournament on an easy course
- Scoring distributions match PGA-like patterns (most pars, fewer birdies/bogeys, rare eagles)
- Full 72-golfer × 4-round simulation completes in under 10 seconds
- Dramatic moments (eagles, HIOs, lead changes) are surfaced to the player via notifications
- Cut line visually separates the leaderboard after round 2
- Hazard-heavy holes produce higher average scores than open holes in tournament results
- Wind and weather meaningfully shift field scoring (rainy rounds score higher)

---

## Out of Scope

| Feature | Reason |
|---------|--------|
| Player-controlled shots during tournaments | Different game genre |
| TV broadcast camera angles | Requires 3D camera system |
| Sponsor logo placement | Visual complexity with no gameplay value |
| Caddie system | Adds complexity without tycoon depth |
| Practice rounds before tournament | Nice-to-have, defer to career mode |
| Disqualification / rules violations | Edge case complexity |
