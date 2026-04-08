# Bug Bash & Stability — Product Spec

**Author:** Claude (Product)
**Date:** 2026-02-27
**Status:** Proposal
**Milestone:** Beta Milestone 6
**Priority:** P2 — Quality
**Est. Scope:** Medium

---

## Problem Statement

The codebase is clean (no TODO/FIXME comments, zero known critical bugs) and the architecture is solid (signal-driven, well-decoupled managers). However, the interaction of all systems together — Phase 3 managers, seasonal calendar, tutorial, UI theme, balance changes — has not been stress-tested as a cohesive whole.

Edge cases around bankruptcy, maximum values, rapid state changes, and save/load across feature boundaries are where bugs hide. For beta, the game must be stable for 1+ hour sessions without crashes, and save files must always load correctly.

---

## Goal

Systematic testing of all game systems to find and fix crashes, data corruption, edge cases, and visual glitches before external playtesting. Zero crashes in normal play. Graceful handling of abnormal play.

---

## User Stories

1. **As a playtester**, I want the game to never crash during normal play.
2. **As a playtester**, I want my save files to always load correctly, even if I saved in a weird state.
3. **As a playtester**, I want to recover from mistakes (bankruptcy, bad decisions) without the game entering an unrecoverable state.
4. **As a developer**, I want automated tests covering the new systems so future changes don't regress.

---

## Functional Requirements

### FR-1: Save/Load Stress Tests

The `SaveManager` (443 lines) serializes game state, terrain, entities, holes, wind, weather, tournaments, course records, land, staff, marketing, daily history, milestones, and shot heatmap. Golfers are explicitly NOT saved. Test every save/load boundary.

| # | Test Scenario | Expected Behavior |
|---|--------------|-------------------|
| 1 | Save immediately after starting new game (Day 1, no actions) | Loads correctly, all defaults preserved |
| 2 | Save during active simulation with 8 golfers on course | Loads correctly. Golfers cleared and respawn naturally (by design) |
| 3 | Save with maximum staff hired (all 4 types, multiple of each) | Staff data round-trips correctly; payroll resumes |
| 4 | Save with active marketing campaigns mid-duration | Campaign timers preserved; campaigns resume countdown |
| 5 | Save with all purchasable land parcels bought | Land ownership map preserved; boundary overlay correct |
| 6 | Save at end of year (Day 360 / Day 28 in current 28-day calendar) | Season derived correctly on load; year increments properly |
| 7 | Save during active holiday event | Event state reconstructed from day_of_year on load |
| 8 | Load a save from before seasonal system was added | Graceful defaults: Day 1, Year 1, Spring |
| 9 | Load, play 1 day, save again, load again | No data drift; values identical to pre-save |
| 10 | Corrupt a save file (delete a required field) | Graceful error message, no crash; player returned to main menu |
| 11 | Save with active tournament in progress | Tournament state preserved; results still generate correctly |
| 12 | Save with loan balance and interest accruing | Loan balance and interest timing preserved |
| 13 | Save with 18 holes, some open and some closed | Hole open/closed state preserved; closed holes don't accept golfers |

### FR-2: Economy Edge Cases

| # | Test Scenario | Expected Behavior |
|---|--------------|-------------------|
| 1 | Reach exactly $0 balance | Game continues normally (bankruptcy at -$1,000 on Normal) |
| 2 | Trigger bankruptcy (-$1,000 on Normal) | Game over panel shows with stats; offers Retry/Load/Quit |
| 3 | Maximum daily revenue: 18 holes, max green fee, all buildings, peak season | No integer overflow; values display correctly |
| 4 | Fire all staff during active simulation | No crashes; condition starts decaying; payroll stops immediately |
| 5 | Cancel all marketing campaigns simultaneously | No crashes; spawn rate modifier returns to 1.0 |
| 6 | Set green fee to minimum ($10) then maximum ($200) rapidly | No crashes; golfer spawn adjusts within one spawn cycle |
| 7 | Take max loan ($50,000) with existing debt | Blocked or warned; no double-loan exploit |
| 8 | Repay loan with insufficient funds | Blocked with clear message; no negative loan balance |
| 9 | Earn revenue while bankrupt (edge case: green fee arrives same frame as bankruptcy check) | Bankruptcy check should happen at end of day, not mid-day |

### FR-3: Gameplay Edge Cases

| # | Test Scenario | Expected Behavior |
|---|--------------|-------------------|
| 1 | Delete all holes during build mode | Simulation can't start (no holes); clear message to player |
| 2 | Delete a hole that golfers are currently playing | Golfers finish current hole then advance; no crash on reference to deleted hole |
| 3 | Place tee on edge of owned land, green requires unowned land | Green placement blocked; clear feedback ("You need to purchase adjacent land") |
| 4 | Fill entire owned land with water | No playable holes; golfers don't spawn; no crash |
| 5 | Create 18 holes on minimum land (cramped layout) | All holes function; potential overlap is allowed but impacts design rating |
| 6 | Run simulation for 100+ days at Ultra speed | No memory leak; no performance degradation over time |
| 7 | Quit to menu and start new game 10 times consecutively | No resource leaks; memory stable; no orphaned nodes |
| 8 | Create a hole with tee and green on same tile | Should be blocked or produce a par 1; no crash |
| 9 | Paint terrain on every tile of owned land | No performance issue; overlay redraws correctly |
| 10 | Raise all tiles to max elevation (+5) then lower to min (-5) | Elevation renders correctly; no visual glitches at extremes |
| 11 | Place the same building type 20+ times | All buildings function; proximity revenue doesn't scale infinitely |

### FR-4: UI Edge Cases

| # | Test Scenario | Expected Behavior |
|---|--------------|-------------------|
| 1 | Open every panel simultaneously (all hotkeys) | No Z-order conflicts; most recent panel on top; close all with Esc |
| 2 | Rapidly toggle between build mode and simulation | State transitions cleanly; no stuck tools or phantom selections |
| 3 | Click minimap while panels are open | Camera pans correctly; panel stays open or closes consistently |
| 4 | Open tutorial overlay + help panel + notification toast simultaneously | All render without overlap; layering is correct |
| 5 | Trigger 20+ toast notifications rapidly | Max 4 visible; oldest dismissed gracefully; no layout corruption |
| 6 | Open financial panel with 1000+ transaction history entries | Panel renders without lag; scrolling is smooth |
| 7 | Toggle every setting in Settings menu rapidly | No crashes; settings apply correctly; persist on save |
| 8 | Press all hotkeys during main menu (before game starts) | No crashes; hotkeys should be disabled on main menu |

### FR-5: Seasonal System Edge Cases

| # | Test Scenario | Expected Behavior |
|---|--------------|-------------------|
| 1 | Fast-forward through 10 full years (2800+ days at 28-day year) | Year counter correct; seasonal modifiers cycle; no drift |
| 2 | Save at exact season boundary (day 7, 14, 21, 28) | Season derived correctly on load; no off-by-one |
| 3 | Mountain course: close for winter then reopen | Game advances to Spring correctly; costs deducted during skip |
| 4 | Holiday event spanning season boundary | Event continues or ends correctly; no duplicate notifications |
| 5 | Multiple events active simultaneously (if possible) | Effects stack correctly; UI shows both |

### FR-6: Cross-System Interaction Tests

| # | Systems Tested | Scenario | Expected |
|---|---------------|----------|----------|
| 1 | Season + Marketing | Run marketing during winter (low spawn) | Marketing boost stacks with seasonal penalty; net modifier is correct |
| 2 | Staff + Season | Groundskeeper condition in winter (low maintenance cost) | Condition still degrades/restores; maintenance cost modifier applied |
| 3 | Land + Save/Load | Buy land, save, load, verify boundary | Boundary overlay redraws correctly; new tiles are paintable |
| 4 | Tournament + Season | Host tournament in winter (0.5× prestige) | Prestige modifier applied; tournament still completes; results accurate |
| 5 | Tutorial + New Game | Start new game, skip tutorial, start another new game | Tutorial state persists; second new game doesn't re-trigger FTE |
| 6 | Balance + Difficulty | Switch from Normal to Hard mid-game (if possible) | If not possible, verify difficulty is locked at game start |
| 7 | Theme + UI | Switch between all 10 themes in consecutive new games | UI theme doesn't bleed between sessions; terrain colors correct |

---

## Test Coverage: New GUT Unit Tests

Expand the automated test suite to cover systems that currently have no tests:

### Required New Test Files

| Test File | System Under Test | Key Test Cases |
|-----------|------------------|----------------|
| `test_land_manager.gd` | LandManager | Parcel purchase, adjacency check, progressive pricing, boundary enforcement, serialize/deserialize |
| `test_staff_manager.gd` | StaffManager | Hire/fire, payroll calculation, condition decay/restore, modifier getters, serialize/deserialize |
| `test_marketing_manager.gd` | MarketingManager | Campaign start/end, daily processing, diminishing returns (sqrt formula), serialize/deserialize |
| `test_season_system.gd` | SeasonSystem | Season from day, year from day, spawn modifiers, maintenance modifiers, weather weights |
| `test_seasonal_events.gd` | SeasonalEvents | Active event detection, upcoming event lookahead, event modifiers |
| `test_tutorial_system.gd` | TutorialSystem | Step progression, completion persistence, skip behavior |

### Existing Tests to Verify

All 14 existing test files should continue to pass:
- `test_shot_ai.gd` (939 lines)
- `test_golfer_needs.gd` (516 lines)
- `test_golf_rules.gd` (314 lines)
- `test_game_manager.gd` (329 lines)
- `test_course_rating_system.gd` (276 lines)
- `test_penalty_drop.gd` (262 lines)
- `test_daily_statistics.gd` (267 lines)
- `test_save_manager.gd` (172 lines)
- `test_golfer_tier.gd` (212 lines)
- `test_save_load_validation.gd` (133 lines)
- `test_spawn_rate.gd` (134 lines)
- `test_shot_simulator.gd` (204 lines)
- `test_course_records.gd` (108 lines)
- `test_gimme_thresholds.gd` (62 lines)

---

## Acceptance Criteria

- [ ] Zero crashes in all FR-1 through FR-6 test scenarios
- [ ] Save/load round-trip works for all game states tested
- [ ] Old saves (pre-seasonal, pre-tutorial, pre-theme) load with graceful defaults
- [ ] 1-hour continuous play session at Normal speed: no crashes, no visual glitches, no memory growth
- [ ] All 14 existing GUT tests pass without regression
- [ ] 6 new GUT test files added and passing (LandManager, StaffManager, MarketingManager, SeasonSystem, SeasonalEvents, TutorialSystem)
- [ ] All edge cases either handled gracefully or blocked with clear error messages
- [ ] Bankruptcy produces a clear game-over flow (not a crash or soft-lock)
- [ ] No integer overflow or display corruption with large financial values

---

## Out of Scope

- Performance optimization (unless a crash or freeze is discovered during testing)
- Fuzz testing or automated random input testing
- Multiplayer or networked testing
- Mobile or touch input testing
- Automated UI testing (manual testing only for UI edge cases)

---

## Bug Triage Protocol

When a bug is found during testing:

1. **Severity classification:**
   - **P0 (Blocker):** Crash, data loss, or soft-lock. Fix immediately.
   - **P1 (Major):** Incorrect behavior affecting gameplay. Fix in this milestone.
   - **P2 (Minor):** Visual glitch or cosmetic issue. Fix if time permits, defer if not.
   - **P3 (Trivial):** Negligible impact. Document and defer to post-beta.

2. **Documentation:** Each bug gets a one-line description, reproduction steps, and severity.

3. **Fix verification:** After fixing, re-run the failing test scenario to confirm resolution.

---

## Dependencies

- All other milestones (1–5) should be feature-complete before the final comprehensive bug bash
- Can run iteratively: test after each milestone, then a final pass
- Milestone 1 (Phase 3 Verification) covers initial manual verification; this milestone is the systematic expansion

---

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Bug fixes introduce new bugs | Medium | Medium | Run full test suite after each fix; incremental commits |
| Edge cases reveal architectural issues requiring refactoring | Low | High | Document the issue; defer refactoring to post-beta if game is stable |
| Manual testing is time-consuming and incomplete | High | Medium | Prioritize automated unit tests for repeatable scenarios; manual testing for UI/integration |
| Save format changes during earlier milestones break old test saves | Medium | Low | Regenerate test saves after each milestone; version check handles old saves |

---

## Estimated Effort

- Manual testing (FR-1 through FR-6): 6–10 hours
- New unit tests (6 files, ~100–200 lines each): 4–8 hours
- Bug fixes: 4–12 hours (highly variable based on findings)
- Regression testing: 2–3 hours
- **Total: 16–33 hours**
