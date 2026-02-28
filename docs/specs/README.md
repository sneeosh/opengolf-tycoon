# Proposed Specs — Priority Review

**Date:** 2026-02-27
**Context:** Alpha 0.1.0, LAUNCH_EVALUATION rated 6.5/10

This document reviews the current game state and proposes specs that should be written next, ordered by impact. Each entry includes the rationale, what the spec should cover, and suggested scope.

---

## Spec Inventory

| # | Document | Location | Priority | Status |
|---|----------|----------|----------|--------|
| — | Course Design Upgrades | [`course-design-upgrades.md`](course-design-upgrades.md) | HIGH | Proposal |
| 1 | Simulated Tournament Rounds | [`simulated-tournament-rounds.md`](simulated-tournament-rounds.md) | CRITICAL | Proposal |
| 2 | Spectator Camera & Live Scorecard | [`spectator-camera-live-scorecard.md`](spectator-camera-live-scorecard.md) | HIGH | Proposal |
| 3 | Seasonal System Expansion | [`seasonal-system-expansion.md`](seasonal-system-expansion.md) | HIGH | Proposal |
| 4 | Economic Balance & Tuning | [`economic-balance-tuning.md`](economic-balance-tuning.md) | HIGH | Proposal |
| 5 | Premium Land & Prebuilt Courses | [`premium-land-prebuilt-courses.md`](premium-land-prebuilt-courses.md) | MEDIUM-HIGH | Proposal |
| 6 | Career / Progression Mode | [`career-progression-mode.md`](career-progression-mode.md) | MEDIUM-HIGH | Proposal |
| 7 | Audio Design Document | [`audio-design.md`](audio-design.md) | MEDIUM | Proposal |
| 8 | Notification & Event Feed | [`notification-event-feed.md`](notification-event-feed.md) | MEDIUM | **Implemented (Phase 1-2)** |
| 9 | Expanded Decorations & Aesthetics | [`expanded-decorations-aesthetic-rating.md`](expanded-decorations-aesthetic-rating.md) | MEDIUM | Proposal |
| 10 | Course Scorecard & Hole Handicaps | [`course-scorecard-hole-handicaps.md`](course-scorecard-hole-handicaps.md) | MEDIUM | Proposal |
| 11 | Golfer Visual Differentiation | [`golfer-visual-differentiation.md`](golfer-visual-differentiation.md) | MEDIUM | Proposal |
| 12 | Visual Polish (Sprites/Art) | [`visual-polish.md`](visual-polish.md) | MEDIUM | Proposal |
| 13 | Pathfinding Upgrade (A*) | [`pathfinding-upgrade.md`](pathfinding-upgrade.md) | MEDIUM-LOW | Proposal |
| 14 | Web Build & Distribution | [`web-build-distribution.md`](web-build-distribution.md) | MEDIUM-LOW | Proposal |

### Other Documents

| Document | Location | Status |
|----------|----------|--------|
| Beta Milestone Specs | `docs/beta-milestone-specs.md` | 7 milestones defined — several now outdated (tutorial, onboarding done) |
| Algorithm Docs (15) | `docs/algorithms/` | Living reference — comprehensive coverage of existing systems |

---

## Proposed New Specs (Prioritized)

### 1. Simulated Tournament Rounds

**Priority: CRITICAL — This is the single highest-impact missing spec.**

**Why:** Tournaments are the endgame. Currently `generate_tournament_results()` produces random scores — the player's course design has zero influence on tournament outcomes. This breaks the core promise of the game: *design a great course and watch great golf happen on it*.

**What the spec should cover:**
- Accelerated simulation using the real shot engine (angular dispersion, wind, terrain) with animations skipped
- Tournament golfer generation (SERIOUS/PRO tier, N=20-60 field size per tier)
- Multi-round format (1 round for Local, 2 for Regional, 4 for National/Championship)
- Cut line mechanics (top N after round 2 advance)
- Live leaderboard UI during tournament days (scrollable, updating as holes complete)
- Scoring relative to par with tournament-appropriate distribution (not all golfers shooting par)
- Course design → tournament outcome causality (hazards produce bogeys, well-designed holes produce birdie chances, poor routing slows pace)
- Prize money calculation (entry fees from field × multiplier by tier)
- Record tracking: tournament winners, course records set during tournaments
- "Dramatic moment" detection: eagles, hole-in-ones, leaderboard swings flagged for notification
- Performance budget: simulating 60 golfers × 18 holes × 4 rounds must complete within a few seconds of real time

**Scope:** Medium — the shot engine, golfer tier system, and wind/weather are all production-ready. The work is wiring them together in an accelerated loop and building the leaderboard UI.

**Depends on:** Nothing new. All underlying systems exist.

---

### 2. Spectator Camera & Live Scorecard

**Priority: HIGH — Makes the simulation watchable.**

**Why:** The game simulates golfers playing your course, but you can't meaningfully watch them. There's no camera follow, no live scorecard, no way to engage with an individual round. The simulation is the payoff for course design — it needs to be a spectacle, not background noise.

**What the spec should cover:**
- **Follow mode:** Click golfer (or select from a group list) to attach camera with smooth tracking
- Camera behavior during shots: zoom slightly on swing, track ball flight, hold on landing, return to golfer
- Camera behavior between shots: gentle follow at walking pace, pull back for wider view
- **Live scorecard overlay:** Translucent panel showing the followed golfer/group's hole-by-hole scores
- Scorecard shows: golfer name, tier, hole number, par, score, running total, score-to-par color coding
- **Group scorecard:** When following a group, show all group members' scores
- **Quick-switch:** Arrow keys or number keys to cycle between active golfers/groups
- **Exit follow mode:** Escape or click empty space returns to free camera
- **Enhanced thought bubbles:** When following a golfer, show their satisfaction feedback as speech bubbles (already generated by FeedbackManager, just not surfaced in follow mode)
- **Round summary popup:** When a followed golfer finishes, show their full scorecard, best/worst hole, satisfaction rating, money spent at facilities
- Integration with tournament mode: follow mode during tournaments with leaderboard position shown

**Scope:** Medium — camera infrastructure exists (IsometricCamera), golfer state machine exposes position/state. The work is the follow-mode state machine, UI overlays, and camera motion smoothing.

**Depends on:** Independent, but synergizes strongly with Spec #1 (tournaments).

---

### 3. Seasonal System Expansion & Theme-Awareness

**Priority: HIGH — The foundation exists but needs depth.**

**Why:** `SeasonSystem` and `SeasonalEvents` already exist with a compact 28-day year (7 days per season), spawn/maintenance/weather modifiers, and 8 seasonal events. The `SeasonalCalendarPanel` UI is integrated. However, the system lacks theme-aware scaling (Desert winters should be milder than Mountain winters), gradual season transitions (currently hard cutoffs), green fee tolerance variation by season, and tournament prestige modifiers. The 28-day year also compresses seasons so much that economic pressure from winter is brief.

**What the spec should cover:**
- Whether to extend the year length (28 days is very compressed — should it be 120 or 360 days?) and the gameplay implications of each choice
- Theme-aware season modifiers: Desert/Resort mild winters, Mountain harsh winters with optional course closure, Links extra wind in winter
- Gradual season transition blending (spawn rate ramps over 1-2 days instead of hard cutoffs)
- Green fee tolerance modifier by season (summer: players accept premium pricing; winter: only bargain-seekers)
- Tournament prestige modifier by season (fall classics are more prestigious, winter tournaments less so)
- Whether seasonal events need advance notification (currently they just happen)
- Algorithm doc: `docs/algorithms/seasonal-calendar.md` documenting the full modifier stack

**Scope:** Low-Medium — the core system is built and integrated across 12 files. The work is adding modifier dimensions and theme awareness.

**Depends on:** Nothing. All integration points exist.

---

### 4. Economic Balance & Tuning Framework

**Priority: HIGH — All levers exist but are unvalidated.**

**Why:** The game has green fees, building revenue, staff payroll, marketing costs, maintenance, land expansion, and reputation — but nobody has validated that these interact to produce an engaging economic curve. The starting money ($50K), default green fee ($30), and bankruptcy threshold (-$1000) are educated guesses. A spec is needed not just for the target numbers, but for the *methodology* of how to validate them.

**What the spec should cover:**
- Target progression curve: expected player state at Day 30/90/180/360 (holes built, money, reputation, staff)
- Economic pressure points: when should the player feel "tight"? When should they feel wealthy?
- Difficulty preset calibration: Easy should be forgiving, Hard should threaten bankruptcy
- Balance testing protocol: 5 defined playstyles (speedrun, conservative, builder, optimizer, new player), each played through 360 days
- Specific tuning questions with acceptance criteria:
  - Can a player coast on 3 holes forever? (Should be: no, maintenance costs should eventually force expansion or fee optimization)
  - Is there a building combo that generates infinite money? (Should be: no)
  - Does reputation reach 50 by Day 90 with good play? (Should be: yes)
  - Does green fee sensitivity work? ($100 on a 2-star course should crater traffic)
- Exploit checklist: document any strategy that trivializes the economy
- Output: tuned values committed to `data/` JSON files, documented in `docs/algorithms/economy.md`

**Scope:** Unusual — this is more of a testing/tuning spec than a feature spec. Requires systematic playtesting.

**Depends on:** Ideally after Seasonal Calendar (Spec #3), since seasons dramatically affect the economic curve.

---

### 5. Premium Land & Prebuilt Courses

**Priority: MEDIUM-HIGH — Gives wealthy players something to spend on and feeds career progression.**

**Why:** Currently all land parcels are identical — $5,000 base with 30% escalation per purchase, 20×20 tiles each, no differentiation. There's no concept of premium real estate or turnkey courses. Once a player accumulates significant capital ($200K+), there's nothing aspirational to spend it on. Premium land and prebuilt courses create a capital sink that rewards long-term play and provides a shortcut for players who want to skip the early grind on subsequent playthroughs.

**What the spec should cover:**
- **Premium parcels:** Certain map positions designated as premium (lakefront, hilltop, scenic) with higher cost (2-5× base) but built-in terrain features (existing water features, natural elevation, mature trees). These aren't just expensive — they come with pre-painted terrain that gives a design head start.
- **Prebuilt course packages:** Purchasable templates that auto-build a 3-hole, 9-hole, or 18-hole layout on owned land. Tiers: Starter ($25K, basic 3-hole), Executive ($75K, polished 9-hole par-3), Championship ($200K, full 18-hole). The player can then customize and improve the template.
- **Acquisition requirements:** Premium land and prebuilt courses gated behind progression milestones or star ratings (e.g., 3-star course rating to unlock Executive package, 4-star for Championship)
- **Land quality tiers:** Standard (current), Premium (pre-landscaped), Elite (pre-landscaped + pre-built infrastructure like paths and irrigation)
- **Map generation:** How premium parcels are placed on the 6×6 grid — fixed positions? Random per new game? Theme-dependent? (Desert might have "oasis" premium parcels, Links might have "clifftop")
- **Integration with career mode:** Prebuilt courses as scenario starting points ("You've purchased this rundown 9-hole — renovate it into a 4-star course")
- **Save/load:** Serialize land quality tier and prebuilt status per parcel

**Scope:** Medium — `LandManager` exists with parcel grid, cost escalation, and adjacency logic. The work is adding quality tiers, prebuilt course templates (extending `QuickStartCourse` pattern), and gating logic.

**Depends on:** Synergizes with Career/Progression Mode (Spec #6). Can be implemented independently but is more meaningful with progression gates.

---

### 6. Career / Progression Mode

**Priority: MEDIUM-HIGH — Solves the "what do I do after 18 holes?" problem.**

**Why:** After building a good 18-hole course and hosting a Championship tournament, there's limited incentive to continue. The game needs longer-term goals beyond the current 27 milestones. This is the difference between a sandbox toy and a tycoon game.

**What the spec should cover:**
- **Star-gate progression:** Content unlocks tied to course star rating (2 stars → access to Regional tournaments, 3 stars → National, 4 stars → Championship, 5 stars → Hall of Fame)
- **Rival courses:** AI-managed competing courses that set pricing benchmarks and steal golfers if your reputation drops
- **Prestige system:** Lifetime achievement score across multiple courses — incentivizes starting new courses with different themes
- **Unlockable content:** New building types, premium decorations, special terrain features earned through milestones. Premium land parcels and prebuilt course packages (Spec #5) as late-game purchases
- **Scenario/challenge mode:** Pre-built courses with objectives ("Turn this failing 9-hole into a profitable course in 90 days", "Host a Championship tournament within 1 year"). Prebuilt courses (Spec #5) provide the templates for scenarios
- **Victory conditions:** Define what "winning" looks like — multiple victory paths (economic, prestige, tournament, design)
- Scope boundaries: what's in v1 career mode vs. what's deferred

**Scope:** Large — this is the biggest feature gap between "sandbox alpha" and "tycoon game." Should be specced thoroughly before any implementation begins.

**Depends on:** Simulated tournaments (Spec #1), Seasonal calendar (Spec #3), Economic balance (Spec #4). Premium Land (Spec #5) provides progression rewards.

---

### 6. Audio Design Document

**Priority: MEDIUM — The system exists but is muted by default.**

**Why:** `SoundManager` (602 LOC) and `ProceduralAudio` are fully built and generate swing, impact, ambient, and UI sounds procedurally. But `is_muted = true` by default because the quality was deemed insufficient. No spec exists for what "good enough" sounds like or what the path to enabling audio is.

**What the spec should cover:**
- Audio quality targets: reference recordings or descriptions for each sound category (swing whoosh, iron impact, putt click, ball-in-cup, ambient wind/birds/rain)
- Decision: pure procedural vs. hybrid (procedural ambient + recorded samples for core SFX)
- If hybrid: minimal sample list (estimate 10-15 sound files), licensing requirements (CC0/MIT compatible)
- Volume mixing: relative levels for SFX, ambient, UI
- Spatial audio: sounds attenuate with camera distance to golfer
- Weather audio layers: rain intensity, wind gusting, thunder
- Tournament audio: crowd reactions, applause
- Music: ambient background music or intentionally music-free? If music, procedural or composed?
- Browser autoplay policy handling for web build
- Acceptance criteria: "audio defaults to ON" is the success metric

**Scope:** Medium — the architecture is done. The work is either improving procedural generation algorithms or sourcing/integrating recorded samples.

**Depends on:** Nothing.

---

### 7. Notification & Event Feed System

**Priority: MEDIUM — Bridges the gap between "stuff happening" and "player awareness."**

**Why:** Important events (hole-in-one, course record, tournament result, bankruptcy warning, seasonal change) trigger `NotificationToast` popups that auto-dismiss in a few seconds. If you miss them, they're gone. There's no persistent event log, no click-to-navigate, no event history. Players in fast-forward mode miss most events.

**What the spec should cover:**
- Persistent notification feed (sidebar or pull-out panel) showing last N events
- Event categories: Records, Economy, Golfers, Weather, Tournaments, Milestones
- Category filtering and color coding
- Click-to-pan: clicking a golfer event pans camera to that golfer; clicking a hole event pans to that hole
- Priority levels: Critical (bankruptcy warning, game over) interrupts gameplay; Normal auto-dismisses; Info only appears in feed
- Fast-forward handling: batch events during ULTRA speed, show summary on pause/speed-change
- Integration with Follow Mode (Spec #2): events about the followed golfer get priority
- Algorithm doc: event priority ranking and deduplication rules

**Scope:** Low-Medium — `NotificationToast` and `EventBus` signals exist. The work is the persistent feed UI and click-to-navigate behavior.

**Depends on:** Nothing, but synergizes with Spec #2 (Follow Mode).

---

### 8. Expanded Decorations & Aesthetic Rating

**Priority: MEDIUM — Makes course design more expressive and gives decorations gameplay purpose.**

**Why:** The current decoration palette is limited: 11 tree varieties, 3 rock sizes, flower bed terrain tiles, and 8 functional buildings. There are no purely aesthetic objects (fountains, statues, benches with views, signage, flower gardens, bird baths, etc.). More importantly, decorations have zero impact on course rating — the `CourseRatingSystem` calculates stars from Condition (30%), Design (20%), Value (30%), and Pace (20%), with no aesthetics factor. A beautifully landscaped course scores identically to a bare one. This removes a core tycoon motivation: making your creation *look* good should *matter*.

**What the spec should cover:**
- **New decoration categories:**
  - **Landscaping:** Flower gardens (multi-tile), hedge rows, ornamental grasses, topiaries
  - **Water features:** Fountains, waterfalls (adjacent to elevation changes), decorative ponds
  - **Structures:** Gazebos, pergolas, bridges (decorative, over paths), course signage, tee markers, yardage markers, ball washers
  - **Furniture:** Park benches with scenic overlooks, picnic areas, waste bins
  - **Sculptures:** Course logo statue, golfer statue, sundial — unlockable prestige items
- **Aesthetics rating subcategory:** Add a 5th factor to `CourseRatingSystem` or fold into existing Design category. Proposed: Aesthetics (10%, taken from Design which becomes 10%). Factors: decoration density near holes, variety of decoration types, landscaping around tee boxes and greens, scenic viewpoints (bench + elevation + water in proximity)
- **Decoration placement rules:** Radius-based — decorations near tee boxes and greens contribute more than those in the middle of nowhere. Diminishing returns — first 5 decorations per hole area matter most
- **Cost and maintenance:** Each decoration type has placement cost and daily upkeep. Premium decorations (fountains, sculptures) are expensive but high-impact
- **Theme-appropriate bonuses:** Desert theme gets extra credit for cactus gardens and rock arrangements. Links gets credit for fescue grass and heather. Resort gets credit for palm-lined paths and water features
- **Unlockable decorations:** Tie premium decorations to milestones or career progression (Spec #6). Sculptures unlock at 4-star rating, fountains at reputation 50, etc.
- **Data format:** New `data/decorations.json` or extend `data/buildings.json` with a "decorative" category

**Scope:** Medium — entity placement system exists, building/tree patterns are well-established. The work is new entity types, the aesthetics rating formula, and placement UI.

**Depends on:** Nothing required, but synergizes with Career Mode (Spec #6) for unlockable decorations and Visual Polish (Spec #11) for rendering quality.

---

### 9. Course Scorecard & Hole Handicaps

**Priority: MEDIUM — Makes the game feel like a real golf course, not just a simulation toy.**

**Why:** There is no proper course scorecard. The `RoundSummaryPopup` is a 5-second toast notification showing total score and satisfaction. The `HoleStatsPanel` shows per-hole statistics (average score, distribution) but only for one hole at a time. There's no view that shows all 18 holes at once the way a real golf scorecard does — with hole number, par, yardage, handicap index, and a golfer's scores. Stroke index / hole handicap doesn't exist anywhere in the system. This is a missed opportunity: the scorecard is the most iconic artifact in golf, and displaying it properly adds both authenticity and practical design feedback.

**What the spec should cover:**
- **Scorecard layout:** Modeled after a real golf scorecard with:
  - Header row: Hole numbers (1-18), split into Front 9 / Back 9
  - Par row: Par for each hole
  - Yardage row: Distance from tee to green (back tees, or per-tee if multiple tee boxes from Course Design Upgrades Spec 1.2)
  - Handicap/Stroke Index row: Hole difficulty ranking 1-18 (hardest = 1)
  - Player score rows: One row per golfer in a group, with per-hole scores
  - Totals column: Front 9 total, Back 9 total, Overall total, Score vs par
- **Stroke index calculation:** Auto-derived from `DifficultyCalculator` hole ratings. Hardest hole = SI 1, easiest = SI 18. Recalculates when holes are added/modified. Algorithm doc: `docs/algorithms/stroke-index.md`
- **Score color coding:** Eagle or better (gold), Birdie (red/circle), Par (black), Bogey (blue/square), Double+ (dark blue/double-square) — matching standard scorecard convention
- **Access points:**
  - Persistent "Course Scorecard" button in HUD or hole info panel — shows empty scorecard with pars, yardage, handicaps
  - When following a golfer (Spec #2): live scorecard fills in as holes are completed
  - Round summary: full scorecard shown when a golfer finishes (replaces current 5-second toast)
  - Tournament mode: multi-player scorecard with leaderboard position
- **Course info section:** Course name, theme, slope rating, course rating, total yardage, total par
- **Print/export style:** Clean enough to screenshot and share — white background, clear grid lines, readable font sizes
- **Historical scores:** Optional: store last N completed rounds for the "best scores" view. Shows course record holder's full scorecard

**Scope:** Low-Medium — all the underlying data exists (hole par, yardage, difficulty, golfer scores). The work is the scorecard UI layout, stroke index derivation, and connecting it to follow mode and round completion events.

**Depends on:** Nothing required. Enhanced by Spectator Camera (Spec #2) for live scorecard and Simulated Tournaments (Spec #1) for tournament scorecards.

---

### 10. Golfer Visual Differentiation & Identity

**Priority: MEDIUM — Quality of life, not blocking.**

**Why:** All golfers look identical (same stick-figure rendering). You can't tell a Beginner from a Pro by looking at them, can't identify returning golfers, and can't visually distinguish groups. This reduces the connection between "watching simulation" and "caring about outcomes."

**What the spec should cover:**
- Tier-based color coding: Beginner=green shirt, Casual=blue, Serious=red, Pro=gold/black
- Name labels visible on hover (currently requires click)
- Group number indicator (small badge)
- "Regular" golfers: named golfers who return if satisfaction was high, building course familiarity over time
- Visual state indicators: fatigue (slouching when low energy), hunger (thought bubble near snack bar), frustration (red tint when angry)
- Tournament golfer differentiation: special appearance or badge during tournament play
- Minimal approach: colored circles/outlines per tier rather than full sprite art

**Scope:** Low-Medium — rendering infrastructure exists. The work is per-tier color palettes and hover label improvements.

**Depends on:** Nothing.

---

### 11. Visual Polish — Sprites, Buildings, Decorations & Terrain

**Priority: MEDIUM — Elevates the game from "developer art" to "indie release quality."**

**Why:** Everything in the game is rendered as procedural polygons — golfers are ~14-polygon stick figures, buildings are hand-drawn polygon assemblies, trees are ellipses with trunk lines, and terrain is runtime-generated tileset imagery. The visual quality is *functional* and stylistically consistent (isometric, theme-colored, shadowed), but it reads as programmer art rather than polished indie art. For a public release — especially screenshots on a store page or landing page — the visuals need to look intentional and appealing, not just "good enough."

**What the spec should cover:**
- **Art direction decision:** Should the game move to sprite-based assets, improve the procedural rendering, or use a hybrid approach? Each has tradeoffs:
  - *Sprite-based:* Higher visual quality ceiling, but requires asset creation pipeline, increases download size, loses the "zero external assets" philosophy
  - *Improved procedural:* Maintains tiny download, but limited visual ceiling — adding more polygons, shading, and detail hits diminishing returns
  - *Hybrid:* Sprites for key focal elements (golfers, buildings) with procedural terrain. Best visual ROI
- **Golfer visual upgrade:**
  - Current: 11-14 Polygon2D nodes with frame-swapped walk animation, tier-based shirt colors, randomized accessories
  - Target: Recognizable human figures with distinct silhouettes per tier. Smooth walk/swing animations (at least 4 frames). Visible clubs. Expressiveness (posture changes with mood)
  - If sprites: 4 directional sprite sheets per tier (walk cycle, swing, idle, putt). ~16 frames per action per direction
  - If improved procedural: Better body proportions, arm swing during walk, face/expression detail, clothing detail (collars, belts, shoes)
- **Building visual upgrade:**
  - Current: Detailed procedural buildings (clubhouse has siding, windows, roof trim, chimney, awning). Already medium-high quality
  - Target: More architectural detail, signage, lighting (warm window glow at dusk), activity indicators (smoke from restaurant, golfers visible inside pro shop)
  - Building upgrades should be more visually distinct — currently level 1 vs level 3 clubhouse differs by a chimney and flower boxes
- **Decoration visual upgrade:**
  - Current: Trees have theme-aware coloring, bark texture, crown highlights. Rocks have faceted shading. Reasonable quality
  - Target: Seasonal visual variation (fall foliage for deciduous trees, bare branches in winter). Flower beds with visible blooms. New decoration types (Spec #8) need visual designs
- **Terrain visual upgrade:**
  - Current: Procedural tileset with Perlin noise, mowing stripes, autotile edge blending, animated water shimmer
  - Target: Richer terrain textures, visible fairway mowing patterns, bunker lip edges, rough grass tufts, water reflections, path wear patterns
  - Consider: Shader-based enhancements vs. higher-resolution procedural tileset
- **Art asset pipeline:** If moving to sprites, define: file format (PNG atlas vs. individual frames), resolution (32×32? 64×64?), art style reference (which indie games to emulate), tooling (Aseprite? Pixaki?), licensing (if commissioning or using CC0 packs)
- **Performance budget:** More visual detail must not drop below 30 FPS on web build with 8 golfers + full overlays on a 128×128 grid
- **Phased approach:** Prioritize golfers first (most visible, most impactful for screenshots), then buildings, then decorations, then terrain last (already the strongest visual element)

**Scope:** Large — this is an ongoing effort, not a single milestone. The spec should define the art direction and phase 1 deliverables, not try to spec every asset.

**Depends on:** Nothing technically. Synergizes with Expanded Decorations (Spec #8) and Golfer Differentiation (Spec #10). Should be specced after gameplay specs are settled to avoid rework.

---

### 12. Pathfinding Upgrade (A* on Terrain Grid)

**Priority: MEDIUM-LOW — The current heuristic works but has edge cases.**

**Why:** CLAUDE.md notes "No full A* pathfinding (heuristic-based)." Golfers currently use a heuristic approach that works for most layouts but can produce odd walking paths on complex courses with many water hazards or buildings. As courses get more elaborate (18 holes, multiple buildings, winding paths), pathfinding quality matters more.

**What the spec should cover:**
- A* implementation on the 128×128 terrain grid with terrain-type movement costs
- Movement cost table: PATH=1.0, GRASS/FAIRWAY=1.5, ROUGH=2.0, HEAVY_ROUGH=2.5, TREES=3.0, WATER/OB=impassable
- Building collision avoidance
- Path caching: cache paths between common waypoints (green N → tee N+1) and invalidate on terrain changes
- Performance budget: pathfinding for 8 concurrent golfers must not cause frame drops
- Integration with hole-to-hole routing (Course Design Upgrades Spec 1.1)
- Algorithm doc: `docs/algorithms/pathfinding.md`

**Scope:** Medium — well-understood algorithm, but needs careful performance tuning on a 128×128 grid with 8 concurrent agents.

**Depends on:** Nothing, but synergizes with routing (Course Design Upgrades 1.1).

---

### 13. Web Build & Distribution Spec

**Priority: MEDIUM-LOW for spec, but HIGH for execution timing.**

**Why:** The web build is the primary distribution channel (zero install friction), but `docs/beta-milestone-specs.md` Milestone 7 is the only documentation. A dedicated spec should cover browser compatibility testing, IndexedDB save persistence, autoplay audio handling, and the distribution landing page.

**What the spec should cover:**
- Browser compatibility matrix: Chrome, Firefox, Safari (versions, known issues)
- IndexedDB save reliability: what happens on private browsing, storage limits, cross-session persistence
- Audio autoplay policy: user-interaction gate for enabling audio in browser
- Performance targets: 30+ FPS with 8 golfers on a mid-range laptop
- Custom HTML shell requirements (current `web/custom_shell.html` fixes)
- Cloudflare Pages deployment: URL structure, caching, versioning
- Landing page: what information a first-time visitor needs
- Analytics: basic session tracking for playtesting feedback (optional)

**Scope:** Small-Medium — most infrastructure exists. The spec is about defining quality bars and test plans.

**Depends on:** Nothing.

---

## Specs NOT Recommended Right Now

These are features mentioned in various docs that should **not** get specs yet:

| Feature | Why Defer |
|---------|-----------|
| **Mobile/touch input** | Too different from current input model; distracts from core game quality |
| **Localization/i18n** | No international audience yet; premature optimization |
| **Steam achievements** | Map to milestones later; no Steam integration exists |
| **Course sharing/export** | Needs stable save format and community to share with |
| **Player-controlled golfer mode** | Different game genre (sports vs. tycoon); explicitly deferred in beta milestones |
| **Bridges (paths over water)** | Nice-to-have terrain feature, not blocking any core loop |

---

## Recommended Writing Order

```
Now (Core Gameplay):
  1. Simulated Tournament Rounds       ← Biggest single impact on game quality
  2. Spectator Camera & Scorecard      ← Makes #1 watchable
  9. Course Scorecard & Hole Handicaps ← Complements #2, low effort, high authenticity

Next (Tycoon Depth):
  3. Seasonal System Expansion         ← Theme-aware seasons
  4. Economic Balance Framework        ← Validate the numbers
  5. Premium Land & Prebuilt Courses   ← Capital sink, progression reward
  6. Career / Progression Mode         ← Long-term engagement design

When Ready (Polish & Expression):
  7. Audio Design Document             ← Unblock audio-on-by-default
  8. Expanded Decorations & Aesthetics ← Design expression, rating impact
  10. Golfer Visual Differentiation    ← Simulation readability
  11. Visual Polish (Sprites/Art)      ← Store page quality

As Needed:
  12. Pathfinding Upgrade              ← When complex courses expose issues
  13. Web Build & Distribution         ← Before public beta launch
```

---

## Relationship to Existing Docs

- **`docs/beta-milestone-specs.md`** — Milestones 1 (Phase 3 verification) and 3 (Tutorial/Onboarding) are now complete and should be marked done. Milestone 2 (Seasonal Calendar) is partially implemented (`SeasonSystem`, `SeasonalEvents`, `SeasonalCalendarPanel` exist) and needs a spec for theme-awareness expansion. Milestones 4-7 remain relevant.
- **`docs/specs/course-design-upgrades.md`** — Remains valid. Priority 1 items (routing, tee boxes, pins, forced carry) align with and complement the specs proposed here. Multiple tee boxes (1.2) feeds into the scorecard spec (#9). Stroke index (2.4) is now covered more thoroughly by Spec #9.
- **`LAUNCH_EVALUATION.md`** — The Phase 1/2/3 roadmap in Part 8 aligns with this proposal. Specs #1 and #2 here correspond to LAUNCH_EVALUATION Phase 1A and 1B.
- **Algorithm docs** — Each new spec that modifies gameplay should include requirements for new or updated algorithm docs. Specifically: Spec #8 needs an aesthetics rating algorithm, Spec #9 needs stroke index calculation, Spec #1 needs tournament simulation algorithm.
