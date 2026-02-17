# OpenGolf Tycoon — Beta Milestone Specs

> **Author:** Product Management | **Date:** 2026-02-17
> **Target:** Public Beta Release
> **Current State:** Alpha (Priorities 1–10 Phase 3 complete)

---

## Beta Definition

**Beta** means the game is feature-complete enough for external playtesting. All core gameplay loops work end-to-end, the game is stable for 30+ minute sessions, and a new player can figure out the basics without hand-holding from a developer. Beta does NOT require final art, perfect balance, or every planned feature.

**Beta Entry Criteria:**
- All core tycoon loops functional (build → simulate → earn → expand)
- No crash bugs or data-loss bugs in normal play
- New players can start and play without reading source code
- Save/load works reliably across all systems
- Web build playable in modern browsers
- At least 1 hour of engaging gameplay before hitting a wall

---

## Milestone Overview

| # | Milestone | Priority | Est. Scope | Status |
|---|-----------|----------|------------|--------|
| 1 | Phase 3 Verification & Doc Sync | P0 — Housekeeping | Small | Not Started |
| 2 | Seasonal Calendar & Event System | P1 — Core Feature | Medium | Not Started |
| 3 | Tutorial & Onboarding | P1 — Core Feature | Medium | Not Started |
| 4 | Game Balance & Tuning Pass | P1 — Core Quality | Medium | Not Started |
| 5 | UI/UX Polish Pass | P2 — Polish | Medium-Large | Not Started |
| 6 | Bug Bash & Stability | P2 — Quality | Medium | Not Started |
| 7 | Web Build & Cross-Platform QA | P2 — Release | Small-Medium | Not Started |

**Explicitly deferred to post-beta:**
- Player-Controlled Golfer Mode (Phase 5a/5b — very large scope, not required for tycoon beta)
- Improved Sprites (Phase 5b — art-heavy, procedural visuals are acceptable)
- Performance Optimization (Priority 11 — only if profiling reveals issues during beta testing)
- Achievements & Unlockables (Priority 11 — nice-to-have, not core)
- Career Mode, Course Sharing (Post-1.0)

---

## Milestone 1: Phase 3 Verification & Documentation Sync

### Goal
Verify that Land Purchase, Staff Management, and Marketing systems (implemented in code but not marked complete in the milestones doc) are fully working and properly documented. Update all project docs to reflect actual state.

### Background
Code exploration reveals that all three Phase 3 systems are implemented and integrated:
- `LandManager` (land_manager.gd) — 40x40 starting plot, 6x6 parcel grid, progressive pricing, adjacent-only purchases, boundary enforcement
- `StaffManager` (staff_manager.gd) — 4 staff types, hire/fire, course condition tracking, payroll integration
- `MarketingManager` (marketing_manager.gd) — 5 channels, campaign duration/cost, diminishing returns, spawn rate modifiers

All three are wired into `main.gd` _ready(), end-of-day processing, save/load, and the financial summary. However, DEVELOPMENT_MILESTONES.md still shows Phase 3 as "Pending."

### User Stories

1. **As a developer**, I want the milestones doc to accurately reflect what's implemented, so I don't waste time re-implementing existing features.
2. **As a playtester**, I want to verify that land purchase, staff hiring, and marketing campaigns all work correctly in a real play session.

### Acceptance Criteria

- [ ] Play through a full 10-day session exercising all Phase 3 features:
  - Purchase at least 2 land parcels and verify terrain tools are blocked on unowned land
  - Hire at least 1 of each staff type and verify payroll appears in end-of-day summary
  - Launch at least 2 marketing campaigns and verify spawn rate changes
  - Save, quit to menu, reload, and verify all Phase 3 state persists correctly
- [ ] `DEVELOPMENT_MILESTONES.md` updated: Phase 3 marked as ✅ COMPLETE with completed deliverables listed
- [ ] Phase 3 summary table in Priority 10 section updated from "Pending" to "✅ Complete"
- [ ] `README.md` updated to mention land expansion, staff management, and marketing as implemented features
- [ ] Any bugs found during verification logged and fixed

### Out of Scope
- New features for these systems (e.g., staff skill levels, new marketing channels)
- Golfer needs system (deferred — see P6 future enhancement)

---

## Milestone 2: Seasonal Calendar & Event System

### Goal
Add a yearly calendar that cycles through 4 seasons, affecting weather patterns, golfer traffic, maintenance costs, and tournament scheduling. This creates natural revenue fluctuations that force the player to plan ahead — a core tycoon mechanic that prevents the "set it and forget it" problem where optimized courses just print money forever.

### Background
Currently every day plays identically — same weather probabilities, same spawn rates, same costs. The game has no concept of time beyond the day counter. This makes the mid-to-late game feel flat. Seasonal variation creates peaks and troughs the player must navigate with cash reserves, staffing decisions, and marketing timing.

### User Stories

1. **As a player**, I want to see the current season and month so I understand where I am in the yearly cycle.
2. **As a player**, I want summer to bring more golfers (peak revenue) and winter to bring fewer (lean times), so I need to save money during good months.
3. **As a player**, I want weather patterns to change by season (more rain in spring, hot/dry in summer, mild in fall, cold in winter) so the course feels different throughout the year.
4. **As a player**, I want maintenance costs to vary by season (spring aeration is expensive, winter is cheap) so staffing decisions change throughout the year.
5. **As a player**, I want occasional holiday bonus events with advance notice so I can prepare (raise green fees, run marketing campaigns).
6. **As a player** on a Desert or Resort course, I want winter to be less punishing since those courses are warm year-round, reflecting the theme's gameplay identity.

### Functional Requirements

#### Calendar System
- **Year structure:** 360 days = 4 seasons × 90 days each
- **Seasons:** Spring (Days 1–90), Summer (91–180), Fall (181–270), Winter (271–360)
- **Month names:** Derive month from day number (12 months of 30 days each). Display as "Month X, Year Y" in the HUD.
- **Season transitions:** Gradual — modifiers blend over the first/last 10 days of each season rather than hard cutoffs.

#### Seasonal Modifiers

| Modifier | Spring | Summer | Fall | Winter |
|----------|--------|--------|------|--------|
| Golfer spawn rate | 0.8× | 1.2× | 1.0× | 0.5× |
| Weather: rain chance | +20% | -10% | -5% | +10% |
| Weather: severe chance | +10% | +5% | -10% | +15% |
| Maintenance cost | 1.2× | 1.0× | 1.0× | 0.7× |
| Green fee tolerance | 0.9× | 1.2× | 1.0× | 0.7× |
| Tournament prestige bonus | 1.0× | 1.0× | 1.3× | 0.5× |

#### Theme-Aware Season Scaling
Themes should modulate winter severity:
- **Desert:** Winter spawn penalty halved (0.75× instead of 0.5×), no maintenance increase
- **Resort:** Winter spawn penalty halved (0.75×), green fee tolerance stays at 1.0×
- **Links:** Extra wind in winter (+30% base wind strength)
- **Mountain:** Winter fully closes course (0.1× spawn, player can "close for season" to skip ahead and save costs)
- **City/Parkland:** Standard modifiers as listed above

#### Holiday Events
- 3–5 holiday events per year at fixed dates (announced 5 days in advance via notification)
- During holiday: 2× golfer spawn rate for 2–3 days
- Holiday names are generic (e.g., "Holiday Weekend", "Golf Festival", "Charity Open") to avoid real-world calendar specifics
- Player should see "Holiday Weekend in 5 days!" notification to prompt preparation

#### UI Requirements
- **Calendar widget** in the top HUD bar showing: season icon, month name, day of year
- **Season indicator** with color coding (green=spring, yellow=summer, orange=fall, blue=winter)
- **Upcoming events list** accessible from calendar widget (next 30 days)
- **End-of-day summary** shows season name and any active seasonal modifiers
- **Season transition notification** when a new season begins ("Summer has arrived! Peak golf season is here.")

### Technical Requirements

- New `SeasonalCalendar` class (RefCounted or Node) owned by `GameManager`
- Exposes: `get_season()`, `get_month()`, `get_day_of_year()`, `get_seasonal_modifier(modifier_name)`
- Integrates with `WeatherSystem` — season modifies weather probability tables
- Integrates with `GolferManager` — season multiplier on spawn rate (stacks multiplicatively with weather and marketing modifiers)
- Integrates with `GameManager._calculate_daily_costs()` — season multiplier on maintenance
- Integrates with `TournamentSystem` — season affects prestige multiplier
- New EventBus signals: `season_changed(season)`, `holiday_started(event_name)`, `holiday_ended(event_name)`
- Serialized in save data: current day of year (derive season from it). Old saves default to Day 1 (Spring).
- Calendar data defined in `data/seasonal_calendar.json` for data-driven tuning

### Acceptance Criteria

- [ ] Calendar widget visible in HUD showing season, month, and day
- [ ] Playing through a full year (360 days at Ultra speed) shows clear seasonal variation in golfer traffic
- [ ] Summer revenue is measurably higher than winter revenue over multiple play sessions
- [ ] Desert/Resort courses have noticeably milder winters than Parkland/Mountain
- [ ] Mountain course can "close for winter" and skip ahead
- [ ] At least 3 holiday events fire per year with 5-day advance notice
- [ ] Season transitions are smooth (no jarring jumps in spawn rates)
- [ ] Seasonal data survives save/load correctly
- [ ] End-of-day summary reflects seasonal context
- [ ] Existing tests pass without regression

### Out of Scope
- Visual seasonal changes (fall foliage, snow, spring flowers) — deferred to post-beta
- Per-season tournament types — use existing tournament system as-is
- Seasonal green fee auto-adjustment — player manages this manually

### Dependencies
- Staff system (maintenance cost modifiers interact with groundskeeper effectiveness)
- Marketing system (seasonal campaigns become more strategically interesting)
- Weather system (season modifies probability tables)

---

## Milestone 3: Tutorial & Onboarding

### Goal
Ensure a new player can start the game, understand the core mechanics, and play for 30+ minutes without getting stuck or confused. The game currently has zero guidance — no tooltips, no tutorial, no hints. This is the single biggest barrier to external playtesting.

### Background
The game has 20+ panels, 14 terrain types, 8 building types, complex economy mechanics, and a non-obvious workflow (paint terrain → place tee → place green → place flag → start simulation). A brand new player who launches the game has no idea what to do. For beta, we need enough guidance that players can discover the core loop on their own.

### User Stories

1. **As a new player**, I want to understand the basic workflow (design a hole → start simulation → watch golfers play → earn money) within my first 5 minutes.
2. **As a new player**, I want to know what each terrain type does and costs before I paint it.
3. **As a new player**, I want guided prompts for my first hole creation (place tee, then green, then flag) so I don't get stuck.
4. **As a new player**, I want to understand what buildings do and where to place them.
5. **As a returning player**, I want to be able to dismiss or skip all tutorial hints permanently.

### Functional Requirements

#### First-Time Experience (FTE) Flow
When a new game is started (no previous saves exist), guide the player through these steps:

1. **Welcome popup:** "Welcome to OpenGolf Tycoon! You have $50,000 to build your dream golf course. Let's start by creating your first hole." [Got it]
2. **Step 1 — Terrain hint:** Highlight the terrain toolbar. Tooltip: "Paint fairway terrain to create a path from tee to green. Click a terrain type, then click-drag on the map."
3. **Step 2 — Hole creation hint:** After painting at least 10 fairway tiles, show: "Great! Now create a hole. Press H or click 'Create Hole' to start. You'll place a tee box, then a green, then a flag."
4. **Step 3 — Start simulation hint:** After first hole is created, show: "Your first hole is ready! Press the Play button (or spacebar) to open the course and watch golfers play."
5. **Step 4 — Economy hint:** After first golfer finishes a round, show: "Golfers pay green fees when they arrive. Build amenities near the course to earn extra revenue. Expand your course with more holes to attract more golfers!"
6. **FTE complete:** Mark tutorial as complete in a persistent flag (saved in user settings, not in course save data).

#### Tooltip System
- Every terrain type button shows a tooltip on hover: name, cost per tile, maintenance cost, gameplay effect
- Every building button shows a tooltip: name, cost, revenue/satisfaction effect, radius
- Top bar elements show tooltips: click money for financials, click reputation for course rating details
- Hotkey reference: tooltips include keyboard shortcut where applicable

#### Contextual Hints
Triggered by game state, dismissable, don't repeat after dismissal:
- "Your course is losing money! Try lowering green fees or adding revenue buildings like a Pro Shop." (triggers after 3 consecutive loss days)
- "You've run out of space! Purchase adjacent land parcels to expand." (triggers when player tries to build on unowned land 3+ times)
- "Golfer satisfaction is low. Check their feedback for clues." (triggers when satisfaction drops below 40%)
- "You can host a tournament to earn prestige! Open the Tournament panel with T." (triggers when course meets Local tournament requirements)

#### Help Panel
- Accessible via F1 (already exists as hotkey reference)
- Expand to include: gameplay basics section, building guide section, keyboard shortcuts section
- Organize as tabbed panel with categories

### Technical Requirements

- New `TutorialManager` (autoload or child of Main) tracks FTE state and hint dismissals
- FTE state stored in `user://settings.json` (NOT in course save data — tutorial is per-player, not per-course)
- Tooltip system: extend existing UI buttons with `tooltip_text` property or custom tooltip Control
- Contextual hints use EventBus signals to detect trigger conditions
- Hints rendered as non-modal floating panels (top-center or bottom-center) with dismiss button
- All hint text defined in `data/tutorial_hints.json` for easy editing

### Acceptance Criteria

- [ ] New player (no prior saves) sees FTE flow and can create first hole within 5 minutes
- [ ] Every terrain type and building type has a hover tooltip showing name, cost, and effect
- [ ] FTE can be skipped with a "Skip Tutorial" button on the welcome popup
- [ ] FTE completion persists across game sessions (closing and reopening the game)
- [ ] Contextual hints trigger correctly and don't repeat after dismissal
- [ ] F1 help panel has organized gameplay information
- [ ] Tutorial does not interfere with normal gameplay for experienced players
- [ ] Tutorial state is separate from save data (new course on same machine doesn't replay FTE)

### Out of Scope
- Video tutorials or animated demonstrations
- Interactive "click here" highlighting with arrow overlays
- Difficulty modes or assisted gameplay
- In-game wiki or encyclopedia

### Dependencies
- None — can be developed in parallel with other milestones

---

## Milestone 4: Game Balance & Tuning Pass

### Goal
Ensure the economy, progression, and difficulty curves create an engaging experience across a full playthrough (Day 1 through Day 360+). The player should face meaningful decisions, occasional financial pressure, and a satisfying power curve without runaway inflation or frustrating poverty traps.

### Background
Individual systems have been balanced in isolation (green fees clamped, operating costs scaled, reputation decay added), but the full interaction of all systems together — land costs + staff payroll + marketing spend + building revenue + seasonal variation — has not been tuned as a cohesive experience. Phase 3 systems (land, staff, marketing) add significant new money sinks and sources that change the economic equilibrium.

### User Stories

1. **As a player**, I want the early game to feel tight but not punishing — I should be able to afford my first 3 holes and a building or two without going bankrupt, but I shouldn't have excess cash.
2. **As a player**, I want the mid-game to present interesting tradeoffs — do I expand land, hire more staff, or invest in marketing?
3. **As a player**, I want the late game to feel rewarding — a well-run 18-hole course should generate strong profit, but there should still be decisions to make (tournaments, upgrades, expansion).
4. **As a player**, I don't want to discover an exploit that trivializes the game (e.g., one building combo that generates infinite money).
5. **As a player**, I want bankruptcy to be avoidable with reasonable play but possible with bad decisions.

### Functional Requirements

#### Economy Audit
Review and tune these interconnected values:

| Parameter | Current Value | Notes |
|-----------|--------------|-------|
| Starting money | $50,000 | Must cover ~3 holes + 1 building + first land expansion |
| Green fee default | $30 | Should feel right for a 3-hole starter course |
| Green fee range | $10–$200 | High end should only be viable for elite courses |
| Land parcel cost | $5,000 base, +30% escalation | 6th parcel = ~$9,300 — is this right? |
| Staff salaries | Groundskeeper $50, Marshal $40, etc. | Daily cost per staff member |
| Marketing costs | $100–$500/day per channel | ROI must be positive but not overwhelming |
| Building revenue | Pro Shop $15, Restaurant $25, Snack Bar $5 per golfer | Per-golfer per-round |
| Operating costs | $50 base + $25/hole + terrain maintenance | Daily fixed costs |
| Bankruptcy threshold | -$1,000 | Should this be lower to give more runway? |

#### Progression Curve Targets

| Phase | Day Range | Expected State | Money Range |
|-------|-----------|----------------|-------------|
| Early Game | Days 1–30 | 3 holes, 1–2 buildings, learning mechanics | $20K–$60K |
| Growth | Days 30–90 | 6–9 holes, expanding land, hiring first staff | $30K–$100K |
| Mid Game | Days 90–180 | 9–14 holes, full staff, marketing campaigns | $50K–$200K |
| Late Game | Days 180–360 | 14–18 holes, tournaments, high reputation | $100K–$500K |
| Endgame | Days 360+ | Fully optimized course, trophy collection | $200K+ |

These are rough targets — the actual numbers should emerge from playtesting, not be hard-coded.

#### Specific Tuning Areas

1. **Golfer spawn rate vs. hole count:** Verify that adding holes increases revenue proportionally. A 9-hole course should earn roughly 2–3× what a 3-hole course earns (not linearly because of increased traffic capacity).

2. **Staff ROI:** Each staff type should pay for itself within 5–10 days of hiring on a reasonably-sized course. Groundskeepers should be mandatory for a good course rating; marshals and cart operators should be optional optimizations.

3. **Marketing ROI:** Marketing campaigns should have positive ROI within their duration if the course can handle the extra traffic. Running marketing on a 3-hole course should be wasteful (traffic cap hits quickly); running it on a 12-hole course should be profitable.

4. **Land expansion timing:** First land expansion should feel natural around Day 20–40 (when the player needs more space for holes 4–6). The final parcels should be late-game purchases.

5. **Reputation curve:** Reputation should climb steadily with good management but not cap out too early. A player should reach ~50 reputation by Day 90 and ~80 by Day 270 with good play. Reputation 90+ should require excellent course design AND management.

6. **Green fee sweet spot:** There should be a clear relationship between course quality and optimal green fee. A 2-star course charging $80 should see dramatically fewer golfers than one charging $30. A 4-star course should be able to charge $100+ sustainably.

7. **Bankruptcy prevention:** The game should give clear warnings before bankruptcy (3 days of losses in a row → contextual hint). Lowering green fees and firing staff should be viable recovery strategies.

#### Balance Testing Protocol
- Play through 5 complete sessions (360 days each) with different strategies:
  1. **Speedrun:** Build as fast as possible, maximum investment
  2. **Conservative:** Minimal spending, slow expansion
  3. **Builder:** Focus on course design, ignore economy
  4. **Min-maxer:** Optimize revenue per golfer, exploit every system
  5. **New player simulation:** Make some mistakes, recover
- Document the financial trajectory of each playthrough
- Identify any strategy that trivializes the game or leads to unavoidable bankruptcy

### Acceptance Criteria

- [ ] Starting money allows building 3 holes + 1 building without going broke
- [ ] A "reasonable play" session reaches Day 90 without bankruptcy
- [ ] A "bad play" session (overspending, wrong green fees) goes bankrupt but has clear warning signs
- [ ] No single exploit generates unlimited money (e.g., spamming one building type)
- [ ] 18-hole late-game course generates $500–$2000/day profit (not $10,000+)
- [ ] All staff types have positive ROI on appropriate-sized courses
- [ ] Marketing campaigns don't trivialize golfer attraction
- [ ] Reputation naturally reaches 50 by Day 90 with good management
- [ ] Green fee sensitivity is noticeable — overcharging visibly reduces traffic
- [ ] Seasonal variation (Milestone 2) creates meaningful cash flow planning
- [ ] All tuning values documented in a balance reference (data files or doc)

### Out of Scope
- Difficulty settings (Easy/Medium/Hard) — single balanced experience for beta
- AI director that adjusts difficulty dynamically
- Detailed analytics dashboard for the player

### Dependencies
- Milestone 2 (Seasonal Calendar) — seasonal modifiers affect balance significantly
- Phase 3 systems (Land, Staff, Marketing) — must be verified working first (Milestone 1)

---

## Milestone 5: UI/UX Polish Pass

### Goal
Bring the UI from "developer functional" to "playtester friendly." Every interactive element should be discoverable, readable, and responsive. The game should look like an indie game, not a debug tool.

### Background
The current UI works — all 20+ panels are functional and wired in. But there's no custom Godot Theme (everything uses default styles), no tooltips on most elements, text-only toolbar buttons, and no visual hierarchy in the HUD. For beta, we need players to feel comfortable using the interface within their first session.

### User Stories

1. **As a player**, I want buttons and panels to look consistent and polished, not like default Godot widgets.
2. **As a player**, I want the toolbar to use icons (or icon+text) so I can quickly identify tools.
3. **As a player**, I want clear visual hierarchy — important information (money, day, alerts) should be prominent; secondary info should be subdued.
4. **As a player**, I want notifications for important events (revenue earned, golfer feedback, season changes) that don't block gameplay.
5. **As a player**, I want the main menu to look inviting and professional.

### Functional Requirements

#### Custom Godot Theme Resource
Create a `theme.tres` that styles all standard Control nodes:
- **Color palette:** Golf greens (#2d5a27, #4a8c3f), warm wood (#8B7355), cream text (#FFF8E7), dark backgrounds (#1a1a2e)
- **Buttons:** Rounded corners (4px), subtle gradient, hover highlight, pressed state, disabled dimming
- **Panels:** Semi-transparent dark background with 1px border, consistent 12px padding
- **Labels:** Clean sans-serif font, size hierarchy (title: 18px, heading: 14px, body: 12px, caption: 10px)
- **ScrollContainer:** Styled scrollbar (thin, themed color, hover expand)
- **Separators:** Subtle lines matching theme

#### HUD Improvements
- **Top bar:** Segmented sections with subtle dividers and background. Each section (Money, Day/Time, Season, Reputation, Weather, Wind) is a self-contained widget.
- **Money display:** Larger font, coin-colored (#FFD700), red tint when losing money
- **Reputation display:** Star rating visual (filled/empty stars) alongside numeric value
- **Weather/Wind:** Icons or symbols instead of just text (☀️ ⛅ 🌧️ or similar ASCII indicators)

#### Toolbar Improvements
- **Icons for terrain types:** Simple colored squares with terrain pattern previews (or text abbreviation in colored box as minimum viable approach)
- **Tool categories:** Visual grouping with labeled dividers (Terrain | Landscaping | Structures | Holes | Tools)
- **Selected tool highlight:** Clear border or glow on the active tool button
- **Brush size indicator:** Visual representation of current brush size

#### Notification System
- **Toast notifications:** Stack in top-right corner, auto-dismiss after 3–5 seconds
- **Color coding:** Green (revenue/positive), Red (cost/negative), Blue (info), Gold (achievement/record)
- **Click to dismiss** early
- **Don't block** gameplay — notifications float over the game, not in modal dialogs
- Replace existing floating "+$XX" text with this system

#### Main Menu Polish
- **Background:** Static or slow-panning view of a procedurally generated course (reuse existing terrain rendering)
- **Title:** "OpenGolf Tycoon" in a display font
- **Buttons:** Large, centered, clearly labeled (New Game, Load Game, Settings, Quit)
- **Theme selection screen:** Card previews with terrain color samples and modifier summary

#### Settings Menu
- **Graphics tab:** Overlay toggles (water shimmer, grass blades, elevation shading), UI scale slider
- **Gameplay tab:** Auto-save toggle, notification preferences, game speed defaults
- **Audio tab:** Master volume, SFX volume, Ambient volume sliders
- **Controls tab:** Display current keybindings (rebinding is post-beta)
- Settings stored in `user://settings.json`

### Acceptance Criteria

- [ ] Custom theme applied — no default Godot grey widgets visible in normal gameplay
- [ ] Top bar has clear visual segmentation and hierarchy
- [ ] Toolbar tools have visual indicators (icons or colored text boxes) not just plain text
- [ ] Toast notification system replaces floating text for revenue/events
- [ ] Settings menu accessible from main menu and in-game (Esc or gear icon)
- [ ] Settings persist across sessions
- [ ] Main menu looks polished enough to screenshot for a store page
- [ ] All panels (Financial, Staff, Marketing, Land, Tournament, etc.) use the custom theme
- [ ] Font is legible at 1600×1000 viewport resolution
- [ ] Color-blind considerations: don't rely solely on red/green for critical information

### Out of Scope
- Icon art assets (use colored shapes/text abbreviations as placeholders)
- Animation/transitions between screens
- Responsive layout for different resolutions (fixed 1600×1000 for beta)
- Gamepad/controller support

### Dependencies
- None — can be developed in parallel, but Milestone 3 (Tutorial) benefits from tooltips added here

---

## Milestone 6: Bug Bash & Stability

### Goal
Systematic testing of all game systems to find and fix crashes, data corruption, edge cases, and visual glitches before external playtesting. The game should be stable for 1+ hour sessions without crashes.

### Background
The codebase currently has zero TODO/FIXME comments and no known critical bugs — a strong starting point. However, the interaction of Phase 3 systems (land, staff, marketing) with existing systems, seasonal modifiers, and save/load has not been stress-tested. Edge cases around bankruptcy, maximum values, and rapid state changes are likely hiding bugs.

### User Stories

1. **As a playtester**, I want the game to never crash during normal play.
2. **As a playtester**, I want my save files to always load correctly, even if I saved in a weird state.
3. **As a playtester**, I want to recover from mistakes (bankruptcy, bad decisions) without the game entering an unrecoverable state.

### Functional Requirements

#### Test Scenarios

**Save/Load Stress Tests:**
- [ ] Save immediately after starting a new game (Day 1, no actions taken)
- [ ] Save during active simulation with 8 golfers on course
- [ ] Save with maximum staff hired (all types)
- [ ] Save with active marketing campaigns mid-duration
- [ ] Save with all land parcels purchased
- [ ] Save at Day 360 (year boundary with seasonal system)
- [ ] Load a save from before seasonal system was added (migration test)
- [ ] Load, play 1 day, save again, load again — verify no data drift
- [ ] Corrupt a save file (delete a field) — verify graceful error handling, not crash

**Economy Edge Cases:**
- [ ] Reach exactly $0 — verify game continues (not bankrupt until -$1000)
- [ ] Go bankrupt — verify game ends gracefully with clear message
- [ ] Earn maximum possible revenue in one day (18 holes, max green fee, all buildings) — verify no overflow
- [ ] Fire all staff during active simulation — verify no crashes
- [ ] Cancel all marketing campaigns simultaneously
- [ ] Set green fee to minimum ($10) then maximum ($200) rapidly

**Gameplay Edge Cases:**
- [ ] Delete all holes during build mode — verify simulation can't start
- [ ] Delete a hole that golfers are currently playing — verify golfers handle it
- [ ] Place a tee box on the edge of owned land, green on unowned land — verify rejection
- [ ] Fill entire owned land with water — verify golfers don't spawn (no playable holes)
- [ ] Create 18 holes on minimum land (cramped layout) — verify no overlapping issues
- [ ] Run simulation for 100 days at Ultra speed — verify no memory leak or slowdown
- [ ] Quit to menu and start new game 10 times — verify no resource leaks

**UI Edge Cases:**
- [ ] Open every panel simultaneously — verify no Z-order or input conflicts
- [ ] Rapidly toggle between build mode and simulation — verify state consistency
- [ ] Resize window during gameplay (if supported)
- [ ] Click on minimap while panels are open

#### Automated Test Coverage
Expand GUT test suite to cover:
- SeasonalCalendar calculations (season from day, modifier lookups)
- TutorialManager state transitions
- LandManager boundary enforcement
- StaffManager payroll calculations
- MarketingManager campaign lifecycle
- Save/load round-trip for all new systems

### Acceptance Criteria

- [ ] Zero crashes in all test scenarios listed above
- [ ] Save/load round-trip works for all game states
- [ ] Old saves (pre-seasonal, pre-tutorial) load with graceful defaults
- [ ] 1-hour continuous play session at Normal speed: no crashes, no visual glitches, no memory growth
- [ ] GUT test suite passes with new tests for Milestones 1–5 features
- [ ] All edge cases either handled gracefully or blocked with clear error messages

### Out of Scope
- Performance optimization (unless a crash or freeze is discovered)
- Fuzz testing or automated random input testing
- Multiplayer or networked testing

### Dependencies
- All other milestones should be feature-complete before the final bug bash
- Can run iteratively: test after each milestone, then a final comprehensive pass

---

## Milestone 7: Web Build & Cross-Platform QA

### Goal
Ensure the web (HTML5) build works correctly in modern browsers and the desktop builds (Windows, macOS, Linux) export without errors. The web build is the primary distribution channel for beta since it has zero install friction.

### Background
The project already has CI/CD (`.github/workflows/export-game.yml`) that exports to 4 targets and deploys web builds to Cloudflare Pages. A custom HTML shell (`export/web/custom_shell.html`) was recently added to fix browser input conflicts. However, the web build hasn't been systematically tested with all current features.

### User Stories

1. **As a beta tester**, I want to play the game in my browser without installing anything.
2. **As a beta tester**, I want the web build to perform acceptably (30+ FPS on a modern laptop).
3. **As a beta tester on desktop**, I want the downloaded build to launch and run without issues.

### Functional Requirements

#### Web Build Testing
- Test in Chrome, Firefox, Safari (latest versions)
- Verify all input works: mouse click, drag, scroll, keyboard shortcuts
- Verify audio works (browser autoplay policies may block initial audio)
- Verify save/load works (IndexedDB storage in browser)
- Verify performance: 30+ FPS during simulation with 8 golfers
- Verify custom HTML shell properly handles input focus (recent PR #51 fix)
- Test on both high-DPI (Retina) and standard displays

#### Desktop Build Testing
- Windows: launch .exe, play for 10 minutes, verify save location
- macOS: launch .app, verify Gatekeeper doesn't block unsigned build (document workaround)
- Linux: launch binary, verify dependencies

#### Distribution
- Web build URL accessible and shareable
- Desktop builds available as GitHub Release downloads
- Clear "Beta — Expect Bugs" labeling on all distribution channels

### Acceptance Criteria

- [ ] Web build loads in Chrome, Firefox, Safari within 10 seconds
- [ ] All keyboard shortcuts work in web build (no browser shortcut conflicts)
- [ ] Save/load works in web build (persists across browser refresh)
- [ ] Audio plays in web build (with user interaction to satisfy autoplay policy)
- [ ] 30+ FPS in web build during active simulation
- [ ] Desktop builds launch on Windows/macOS/Linux without errors
- [ ] CI/CD pipeline successfully produces all 4 export targets
- [ ] Beta landing page or README with play instructions

### Out of Scope
- Mobile browser support (touch controls)
- Offline/PWA support
- Steam or itch.io distribution (post-beta)
- Code signing for desktop builds

### Dependencies
- All gameplay milestones (1–6) should be complete — this is the final "ship it" milestone

---

## Milestone Dependency Graph

```
Milestone 1 (Phase 3 Verification)
    │
    ├──→ Milestone 2 (Seasonal Calendar)
    │        │
    │        └──→ Milestone 4 (Game Balance) ──→ Milestone 6 (Bug Bash)
    │                                                   │
    │                                                   └──→ Milestone 7 (Web Build & QA)
    │
    ├──→ Milestone 3 (Tutorial) ─────────────────→ Milestone 6
    │
    └──→ Milestone 5 (UI Polish) ────────────────→ Milestone 6
```

**Parallelizable work:**
- Milestones 2, 3, and 5 can be developed in parallel after Milestone 1
- Milestone 4 (Balance) requires Milestone 2 (Seasonal) to be complete
- Milestone 6 (Bug Bash) is the final integration pass
- Milestone 7 (Web Build) is the release gate

---

## Success Metrics for Beta

After completing all 7 milestones, the beta should achieve:

1. **Retention:** A new player plays for 30+ minutes in their first session
2. **Stability:** Zero crashes reported in first 10 playtester sessions
3. **Comprehension:** New players can build and run a 3-hole course without external help
4. **Depth:** Players discover new mechanics (staff, marketing, tournaments, seasons) through natural play
5. **Fun:** Players voluntarily continue past Day 30 (the "one more day" test)

These will be measured through playtester feedback forms and session length tracking (if analytics are added post-beta).

---

## Appendix: What's Already Done

For reference, the following major systems are fully implemented and should NOT be re-built:

- Full golf simulation (shots, clubs, ball physics, wind, terrain effects, angular dispersion model)
- Golfer AI (pathfinding, hazard avoidance, target evaluation, group play, turn-based)
- Terrain system (14 types, elevation, overlays, procedural tileset)
- Building system (8 types, proximity revenue, clubhouse upgrades)
- Economy (green fees, operating costs, financial tracking, bankruptcy)
- Weather system (6 types, visual effects, gameplay modifiers)
- Tournament system (4 tiers, requirements, simulation, leaderboards)
- Course rating (4-factor system, difficulty calculator)
- Course themes (6 themes with colors, modifiers, and full save/load)
- Land purchase system (parcel grid, progressive pricing, boundary enforcement)
- Staff management (4 types, hire/fire, condition tracking, payroll)
- Marketing (5 channels, campaigns, spawn rate modifiers)
- Save/load (all systems serialized, auto-save, named slots)
- Procedural audio (ambient layers, SFX)
- 20+ UI panels (all functional)
- Day/night cycle, end-of-day summary
- Undo/redo, mini-map, hotkey system
