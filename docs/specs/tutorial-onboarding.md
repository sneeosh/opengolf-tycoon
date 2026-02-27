# Tutorial & Onboarding — Product Spec

**Author:** Claude (Product)
**Date:** 2026-02-27
**Status:** Proposal
**Milestone:** Beta Milestone 3
**Priority:** P1 — Core Feature
**Est. Scope:** Medium

---

## Problem Statement

A new player launching OpenGolf Tycoon faces a blank isometric grid with a toolbar of 14+ terrain types, 8 building types, and no guidance on what to do. The most fundamental workflow — paint terrain → create hole (tee → green → flag) → start simulation — is invisible. Without onboarding, beta testers will bounce within minutes.

This is the single biggest barrier to external playtesting. Tycoon games live or die on their first 15 minutes.

---

## Current State

### What Already Exists

A `TutorialSystem` class (`scripts/systems/tutorial_system.gd`, 307 lines) is **already fully implemented** with a 7-step guided overlay:

| Step | Trigger | Signal |
|------|---------|--------|
| WELCOME | Manual (Next button) | — |
| PAINT_TERRAIN | Auto-advance on terrain painted | `terrain_tile_changed` |
| CREATE_HOLE | Auto-advance on hole created | `hole_created` |
| PLACE_BUILDING | Auto-advance or skippable | `building_placed` |
| START_SIMULATION | Auto-advance on simulation start | `game_mode_changed` |
| ADJUST_FEES | Auto-advance or skippable | `green_fee_changed` |
| COMPLETED | Manual (Finish button) | — |

**Integration**: Instantiated in `main.gd` after `new_game()` (not Quick Start). Persists completion to `user://settings.cfg`. Non-modal overlay at top-center of screen — players can interact freely while tutorial is visible.

Additionally:
- **Quick Start** exists: pre-built 3-hole course accessible from main menu
- **F1 hotkey panel** exists: keyboard shortcut reference
- **Settings menu** exists: 4-tab panel (Audio, Display, Gameplay, Controls)

### What's Missing

Despite the tutorial system existing, the milestone spec identifies gaps that still need to be filled:

1. **Tooltips** — No terrain type or building button has a hover tooltip explaining what it does, what it costs, or what gameplay effect it has.
2. **Contextual hints** — No reactive hints that trigger on game state (losing money for 3 days, low satisfaction, tournament eligibility).
3. **Help panel depth** — F1 only shows hotkeys, not gameplay basics, building guides, or mechanic explanations.
4. **Tooltip coverage** — Top bar elements (money, reputation, rating, weather) lack click/hover explanations.

---

## Design Principles

- **Non-blocking.** All guidance overlays allow gameplay to continue. No modal dialogs that freeze the game (except the initial welcome popup).
- **Dismissable and forgettable.** Every hint can be dismissed. Dismissed hints don't return. Tutorial can be skipped entirely.
- **State-driven.** Hints trigger from game state, not timers. A player who never loses money never sees the bankruptcy warning.
- **Layered depth.** FTE teaches the basics. Tooltips provide on-demand detail. Contextual hints teach strategy. Help panel provides reference.

---

## User Stories

1. **As a new player**, I want to understand the basic workflow (design a hole → start simulation → watch golfers play → earn money) within my first 5 minutes.
2. **As a new player**, I want to know what each terrain type does and costs before I paint it.
3. **As a new player**, I want to know what each building does and where to place it.
4. **As a returning player**, I want to dismiss or skip all tutorial hints permanently.
5. **As a struggling player**, I want the game to give me a nudge when I'm doing something wrong (losing money, low satisfaction).
6. **As an experienced player**, I want zero tutorial interference during normal gameplay.

---

## Functional Requirements

### FR-1: Tooltip System

#### Terrain Type Tooltips
Every terrain type button in the toolbar shows a tooltip on hover containing:
- **Name**: e.g., "Fairway"
- **Cost**: e.g., "$5 per tile"
- **Maintenance**: e.g., "$0.50/day per tile"
- **Effect**: e.g., "Standard playing surface. Golfers walk faster on fairway."

Tooltip data sourced from `data/terrain_types.json` (already has cost data).

#### Building Type Tooltips
Every building button shows a tooltip on hover:
- **Name**: e.g., "Snack Bar"
- **Cost**: e.g., "$2,000"
- **Revenue**: e.g., "$5 per golfer in range"
- **Radius**: e.g., "5 tiles"
- **Need satisfied**: e.g., "Hunger"
- **Hotkey**: e.g., "B → select from list"

Tooltip data sourced from `data/buildings.json` (already has cost/revenue/radius data).

#### Top Bar Tooltips
- **Money display**: "Click to open Financial Summary (F)"
- **Reputation display**: "Course reputation (0-100). Higher reputation attracts more and better golfers."
- **Rating display**: "Click to see Course Rating breakdown"
- **Weather icon**: "Current weather: [type]. Affects golfer spawn rates and shot accuracy."
- **Wind indicator**: "Wind: [speed] mph [direction]. Affects shot distance and accuracy."
- **Season/Day**: "Click to open Seasonal Calendar (C)"

#### Implementation Approach
- Use Godot's built-in `tooltip_text` property on Control nodes where possible
- For rich tooltips (multi-line, colored), use a custom `TooltipPanel` class that positions below the hovered element
- Tooltip content defined in `data/tooltips.json` for easy editing, or pulled from existing data files

### FR-2: Contextual Hints

Reactive hints triggered by game state. Each hint:
- Appears as a non-modal floating panel (top-center or bottom-center)
- Has a dismiss button (X)
- Once dismissed, never appears again (tracked in `user://settings.cfg`)
- Has a 1-day cooldown after trigger condition is first met (no spam on rapid state changes)

#### Hint Definitions

| ID | Trigger Condition | Message | Signal/Check |
|----|------------------|---------|--------------|
| `hint_losing_money` | 3 consecutive days with negative profit | "Your course is losing money! Try lowering green fees or adding revenue buildings like a Pro Shop." | Check `daily_history` at end of day |
| `hint_no_space` | Player tries to build on unowned land 3+ times | "You've run out of space! Purchase adjacent land parcels to expand. Press L to open the Land panel." | Count blocked paint attempts in `main.gd` |
| `hint_low_satisfaction` | FeedbackManager satisfaction drops below 0.40 | "Golfer satisfaction is low. Check their thought bubbles for clues — they may need buildings like restrooms or benches." | Check at end of day |
| `hint_tournament_eligible` | Course meets Local tournament requirements for first time | "You can host a tournament to earn prestige and bonus revenue! Press T to open the Tournament panel." | Check after `course_rating_changed` |
| `hint_staff_needed` | Course condition drops below 0.5 with no groundskeepers hired | "Your course condition is declining. Hire a Groundskeeper from the Staff panel (S) to maintain the course." | Check at end of day |
| `hint_expand_course` | Player has 3 holes and money > $30,000 but hasn't created a 4th | "Your course is doing well! Consider adding more holes to attract more golfers and increase revenue." | Check at end of day, after Day 10 |
| `hint_winter_coming` | Season transitions to Fall for first time | "Fall is here — winter is coming. Golfer traffic drops significantly in winter. Build up your cash reserves!" | Listen to `season_changed` |

### FR-3: Help Panel Expansion

Expand the existing F1 hotkey reference into a tabbed help panel:

#### Tab 1: Getting Started
- Core workflow: Paint terrain → Create hole → Start simulation → Earn money
- Quick reference for hole creation: H key → place tee → place green → place flag
- How green fees work: golfers pay per hole played
- How to expand: buy land, build buildings, hire staff

#### Tab 2: Building Guide
- Table of all 8 building types with cost, revenue, radius, and need satisfaction
- Placement tips: "Place buildings near paths between holes for maximum golfer traffic"

#### Tab 3: Keyboard Shortcuts
- Existing hotkey reference (already implemented)

#### Tab 4: Game Mechanics
- Brief explanation of: reputation, course rating, weather effects, seasonal variation, tournaments
- Each section is 2-3 sentences, not a manual

### FR-4: Tutorial Polish

Minor improvements to the existing TutorialSystem:

- Add a "Skip Tutorial" button on the WELCOME step (currently only Next is available)
- Add step numbers to the overlay: "Step 2 of 7: Create a Hole"
- Ensure tutorial overlay doesn't overlap with the calendar widget or weather display

---

## Technical Requirements

### New Class: `ContextualHintManager`

```
Class: ContextualHintManager (Node)
Owner: main.gd (child node)

State:
  _dismissed_hints: Dictionary  # {hint_id: true}
  _trigger_cooldowns: Dictionary  # {hint_id: day_first_triggered}
  _blocked_land_attempts: int

Methods:
  check_daily_hints()         # called at end of day
  check_event_hint(event)     # called on specific signals
  dismiss_hint(hint_id)       # called by UI dismiss button
  is_hint_dismissed(hint_id)  # checks user settings
  _show_hint(hint_id, message)  # creates floating panel
  _load_dismissed() / _save_dismissed()  # user://settings.cfg
```

### Data File: `data/contextual_hints.json`

```json
{
  "hints": [
    {
      "id": "hint_losing_money",
      "message": "Your course is losing money! Try lowering green fees or adding revenue buildings like a Pro Shop.",
      "trigger": "daily_check",
      "condition": "consecutive_loss_days >= 3"
    },
    ...
  ]
}
```

### Integration Points

| System | Change Required |
|--------|----------------|
| **main.gd** | Instantiate `ContextualHintManager`. Call `check_daily_hints()` at end of day. Track blocked land attempts. |
| **Toolbar buttons** | Add `tooltip_text` or custom tooltip to terrain/building buttons |
| **TopHUDBar** | Add `tooltip_text` to money, reputation, rating, weather, wind widgets |
| **F1 Help panel** | Expand from single-tab hotkey list to 4-tab reference panel |
| **TutorialSystem** | Add Skip button, step numbering |
| **user://settings.cfg** | Store dismissed hint IDs alongside tutorial completion flag |

### Persistence

All hint/tutorial state stored in `user://settings.cfg` (NOT in course save data):
- `tutorial.completed = true`
- `hints.dismissed = ["hint_losing_money", "hint_low_satisfaction", ...]`

This ensures:
- Starting a new course doesn't replay dismissed hints
- Tutorial/hint state is per-player, not per-course

---

## Acceptance Criteria

- [ ] Every terrain type button has a hover tooltip showing name, cost, maintenance, and effect
- [ ] Every building type button has a hover tooltip showing name, cost, revenue, radius, and need
- [ ] Top bar elements (money, reputation, rating, weather, wind, season) have tooltips
- [ ] Contextual hints trigger correctly based on game state
- [ ] Dismissed hints don't reappear in the same session or future sessions
- [ ] F1 help panel has 4 tabs: Getting Started, Building Guide, Shortcuts, Mechanics
- [ ] Tutorial has a Skip button on the welcome step
- [ ] Tutorial shows step progress ("Step 2 of 7")
- [ ] New player (no prior saves) can create first hole within 5 minutes using tutorial and tooltips
- [ ] Experienced player sees zero tutorial interference (all hints dismissed, tutorial completed)
- [ ] Hint/tutorial state persists across game sessions via `user://settings.cfg`
- [ ] Existing tests pass without regression

---

## Out of Scope

- Video tutorials or animated demonstrations
- Interactive "click here" highlighting with arrow overlays (shimmer effects, spotlight)
- Difficulty modes or assisted gameplay
- In-game wiki or encyclopedia
- Tooltip localization (English only for beta)
- Context-sensitive cursor changes

---

## Dependencies

- None — can be developed in parallel with other milestones
- Benefits from Milestone 5 (UI Polish) if tooltip styling uses the custom theme

---

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Tooltips obscure game content | Medium | Low | Position tooltips below/beside the hovered element; auto-dismiss on mouse leave |
| Too many contextual hints feel nagging | Medium | Medium | 1-day cooldown, permanent dismissal, max 1 hint visible at a time |
| Hint trigger conditions are too sensitive or insensitive | Medium | Medium | Tune thresholds during Milestone 4 (Balance Pass) |
| Help panel text becomes outdated as features change | Low | Low | Reference data files where possible; keep text concise |

---

## Estimated Effort

- Tooltip system (terrain + building + HUD): 150–200 lines
- Contextual hint manager: 100–150 lines
- Help panel expansion: 150–200 lines
- Tutorial polish (skip button, step numbers): 20–30 lines
- Data file (hints JSON): 30–50 lines
- **Total: ~450–630 lines of code + data**
