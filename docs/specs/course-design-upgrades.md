# Course Design Upgrades — Product Spec

**Author:** Claude (Product)
**Date:** 2026-02-18
**Status:** Proposal
**Version:** 0.1.0-alpha context

---

## Problem Statement

The current course designer lets players place holes, terrain, and buildings independently, but lacks the connective tissue that makes a collection of holes feel like a designed golf course. The most impactful gaps fall into three categories:

1. **Routing** — Holes exist in isolation with no walking path between them
2. **Strategic depth** — Limited tools for creating risk/reward decisions
3. **Playability variation** — Every golfer plays the same hole the same way regardless of skill

These gaps reduce replayability and flatten the design skill ceiling. A player who carefully sculpts terrain around hazards gets little more reward than one who drops tees and greens randomly.

---

## Design Principles

- **Tycoon-first, simulator-second.** Features should create interesting management decisions, not golf physics fidelity.
- **Visible consequences.** Every design choice should produce observable golfer behavior changes.
- **Incremental complexity.** New systems unlock as the player's course grows, not all at once.
- **Respect the tile grid.** Work within the existing 128×128 isometric grid and terrain-type system rather than fighting it.

---

## Priority 1 — High Impact, Moderate Effort

These features address the most glaring gaps and build on existing systems.

### 1.1 Hole-to-Hole Routing & Walking Paths

**Problem:** Golfers teleport between holes. There's no sense of a course "layout."

**Proposal:**
- After completing a hole, golfers walk to the next tee box using pathfinding (A* on the terrain grid).
- PATH tiles become the preferred walking surface (1.5× speed already exists).
- If no path connects green N to tee N+1, golfers walk through grass/rough at normal speed.
- Add a **routing overlay** toggle that shows the walk path between consecutive holes with colored lines (green = short walk, yellow = moderate, red = long detour).
- Walking time between holes contributes to **pace of play**, which already feeds into the Pace Rating (20% of course rating).

**Metrics affected:** Pace rating, golfer satisfaction, course rating.

**Scope:**
- A* pathfinding on terrain grid (avoid water, OB, buildings)
- Walking animation between holes (reuse existing WALKING state)
- Routing overlay visualization
- Pace of play penalty for long walks (>60 tiles between green and next tee)

**Does NOT include:** Mandatory path placement, auto-generated cart paths, or hole reordering UI. Players organically learn that clustered holes with connecting paths score better.

---

### 1.2 Multiple Tee Boxes (3 Tiers)

**Problem:** A 450-yard par 4 is equally punishing for beginners and pros. No yardage variation, no accessibility.

**Proposal:**
- Each hole gets **3 tee positions**: Forward (red), Middle (white), Back (blue).
- During hole creation, the player places the **back tee** (existing workflow). The system auto-suggests forward and middle tee positions along the tee-to-green line at ~75% and ~60% of back-tee distance.
- Players can manually reposition forward/middle tees after creation.
- Golfer tier determines which tee they use:
  - BEGINNER → Forward tees
  - CASUAL → Forward or Middle (random)
  - SERIOUS → Middle or Back
  - PRO → Back tees
- Par recalculates per tee position (a 480y par 5 from the back might be a 360y par 4 from the forward tees).
- Tournament mode forces all players to back tees.

**Data model change:**
```
HoleData:
  tee_positions: { "forward": Vector2i, "middle": Vector2i, "back": Vector2i }
  par_by_tee: { "forward": int, "middle": int, "back": int }
  # Existing tee_position becomes alias for tee_positions["back"]
```

**Metrics affected:** Golfer satisfaction (beginners less frustrated), difficulty rating (per-tee), course design rating (variety bonus for well-differentiated tees).

---

### 1.3 Pin Positions (Flag Placement Rotation)

**Problem:** The flag sits in one spot forever. Real courses rotate pin positions daily to change hole character.

**Proposal:**
- Each hole stores **4 pin positions** (front-left, front-right, back-left, back-right), auto-generated as offsets from green center based on green shape.
- Players can manually place/adjust pin positions by clicking on green tiles.
- Pins rotate daily (automatic, sequential).
- Different pin positions change effective hole difficulty:
  - Front pin on a green behind a bunker = easier (carry over bunker shorter)
  - Back pin on a tiered green = harder (longer putt, elevation)
- Golfer AI already blends "aim at pin" vs "aim at green center" based on skill — this gives that system more to work with.

**Data model change:**
```
HoleData:
  pin_positions: Array[Vector2i]  # 4 positions on the green
  current_pin_index: int          # Rotates daily
  # Existing hole_position becomes pin_positions[current_pin_index]
```

**Metrics affected:** Day-to-day variety, difficulty variance, golfer shot patterns.

---

### 1.4 Forced Carry Distance Display

**Problem:** Players can't see how far golfers must carry over hazards. The most fundamental risk/reward element in course design is invisible.

**Proposal:**
- When a water or bunker hazard sits between the tee and the fairway (or between fairway and green), calculate and display the **minimum carry distance** to clear it.
- Show this on the hole visualization overlay as a dashed line with yardage label.
- DifficultyCalculator already scans the tee-green corridor for hazards — extend it to compute carry distances.
- Golfer AI already evaluates landing zones and avoids water. The forced carry display makes the designer aware of what golfers "see."
- If carry distance exceeds a golfer tier's max club range, that golfer may refuse to attempt the shot and lay up — creating visible behavioral feedback.

**Scope:** Visualization + difficulty modifier. No new terrain types. Reuse existing corridor scan logic.

---

## Priority 2 — Medium Impact, Low-to-Moderate Effort

These features add polish and strategic nuance using mostly existing infrastructure.

### 2.1 Green Size & Shape Tools

**Problem:** Greens are just clusters of green-type tiles painted one at a time. No shaping tools.

**Proposal:**
- Add **green brush presets** to the terrain tool when painting GREEN tiles:
  - Small circle (~12 tiles) — demanding target
  - Medium oval (~24 tiles) — standard
  - Large kidney (~36 tiles) — generous
- Presets are starting points; players can edit individual tiles after.
- Green size already affects difficulty (the calculator checks tile count). This makes it easier to create intentionally-sized greens.
- Display green size (sq. yards) in the hole info label.

**Scope:** UI brush presets for GREEN terrain. No new terrain types.

---

### 2.2 Fairway Width Indicator

**Problem:** Players can't tell how "tight" or "generous" their fairway is at key distances.

**Proposal:**
- On the hole visualization overlay, show **fairway width markers** at 150y, 200y, and 250y from the tee.
- Each marker shows the fairway width in yards (count of FAIRWAY tiles perpendicular to the tee-green line at that distance).
- Color coding: <20y wide = red (tight), 20-35y = yellow (moderate), 35y+ = green (generous).
- This teaches players that tight fairways near landing zones create difficulty, while wide fairways are forgiving.

**Scope:** Overlay visualization only. No gameplay changes.

---

### 2.3 Par Override

**Problem:** Auto-par from distance prevents designing signature holes (e.g., a 280-yard driveable par 4, or a 245-yard par 3 with significant elevation).

**Proposal:**
- Allow manual par override via the hole info panel: click the par number to cycle through valid options (par ±1 from auto-calculated).
- A 460-yard hole could be set to par 4 or par 5, but not par 3.
- Override triggers difficulty recalculation (a short par 5 is easy; a long par 4 is hard).
- Visual indicator on hole info when par is overridden (e.g., "Par 4*").
- Golfer scoring adjusts to the set par, which affects satisfaction and course rating.

**Scope:** UI change to hole info panel + par storage in HoleData. Difficulty formula already uses par as input.

---

### 2.4 Stroke Index / Handicap Allocation

**Problem:** No hole ranking for handicap purposes. Tournaments and golfer scoring lack a handicap dimension.

**Proposal:**
- Auto-assign stroke index 1-18 based on hole difficulty rating (hardest = SI 1).
- Display on scorecard and hole info panel.
- Used in match play scoring (future) and net score calculation.
- Recalculates when difficulty changes.

**Scope:** Derived value from existing difficulty ratings. Display-only initially.

---

### 2.5 Bunker Depth (Shallow vs Deep)

**Problem:** All bunkers are identical. A flat practice bunker and a steep pot bunker play the same.

**Proposal:**
- Add a **bunker depth** property: SHALLOW (default) or DEEP.
- Deep bunkers: higher difficulty modifier (0.8 vs 0.6), reduced recovery distance (ball pops out shorter), visual differentiation (darker sand, steep lip drawn).
- Player toggles depth when placing bunkers (or clicks existing bunker to toggle).
- Links theme defaults to DEEP (pot bunkers are a links staple).

**Data model:** Extend terrain metadata dict — `bunker_depth` key for BUNKER tiles.

---

## Priority 3 — Lower Priority, Higher Effort or Niche Value

Worthwhile features that either require significant new systems or serve a narrower audience.

### 3.1 Hole-to-Hole Ordering UI

**Problem:** Holes are numbered in creation order, not routing order. Rearranging requires deleting and recreating.

**Proposal:**
- Add a **hole order panel** where players drag-and-drop hole numbers to reorder.
- Reordering updates all hole numbers, routing paths, and scorecard display.
- Routing overlay updates to reflect new order.

**Depends on:** 1.1 (Routing) to be meaningful.

---

### 3.2 Tournament Course Setup

**Problem:** Tournaments use the same course configuration as daily play.

**Proposal:**
- Before a tournament, allow the player to configure:
  - **Pin positions** (select which of the 4 pins per hole)
  - **Rough penalty** (increase heavy rough difficulty by 10-25%)
  - **Green speed** (faster greens = more 3-putts, less accuracy on approach)
- Tournament setup costs money (grounds crew overtime).
- Harder setups produce more dramatic scoring, which increases spectator interest and prize pool.

**Depends on:** 1.3 (Pin Positions).

---

### 3.3 Individual Tree Placement

**Problem:** Trees as terrain tiles can't model individual specimen trees that frame holes or block specific shot lines.

**Proposal:**
- Add **tree entities** (like buildings) that occupy a single tile but have a canopy radius (2-3 tiles) that blocks high shots.
- Golfers hitting into the canopy radius trigger a "tree strike" — ball deflects with reduced distance and random direction.
- Tree entity types: Small (1-tile canopy, $50), Medium (2-tile, $100), Large (3-tile, $200).
- Existing TREES terrain type remains for dense forest/tree lines.

**Scope:** New entity type, collision detection during shot flight, placement tool.

**Note:** The entity system already has Tree in `scripts/entities/`. This may be partially implemented — needs investigation.

---

### 3.4 Drainage & Irrigation (Maintenance Depth)

**Problem:** Course condition is a flat rating with no spatial dimension.

**Proposal:**
- Tiles near water sources or with irrigation structures maintain better condition.
- Tiles in low-elevation areas with no drainage degrade faster in rain.
- Adds a spatial maintenance puzzle: "my 7th green keeps flooding because it's in a valley with no drainage."

**Scope:** New terrain metadata layer, weather interaction, maintenance cost spatial modeling. High effort.

---

## Out of Scope (Intentionally Excluded)

| Feature | Reason |
|---------|--------|
| Smooth terrain contouring | Conflicts with tile-grid architecture; would require terrain system rewrite |
| Real-world course recreation tools | Scope creep; not aligned with tycoon gameplay |
| Golf cart simulation | Low strategic value for high implementation cost |
| Spectator/gallery system | Nice-to-have but doesn't affect core design loop |
| Practice green/driving range gameplay | Buildings exist but active practice simulation is low-ROI |
| Irrigation sprinkler placement | Too granular for tycoon gameplay; see 3.4 for simplified version |
| Shot height / punch shots | Requires 3D flight model; current 2D parabolic system is sufficient |

---

## Implementation Sequence

```
Phase 1 (Foundation):
  1.1 Routing & Walking Paths  ←  unlocks pace-of-play feedback loop
  1.4 Forced Carry Display     ←  cheap win, high design insight

Phase 2 (Strategic Depth):
  1.2 Multiple Tee Boxes       ←  biggest single gameplay improvement
  1.3 Pin Positions            ←  daily variety, replayability
  2.3 Par Override             ←  small effort, big design freedom

Phase 3 (Polish):
  2.1 Green Shape Presets      ←  quality of life
  2.2 Fairway Width Indicator  ←  teaching tool
  2.5 Bunker Depth             ←  strategic nuance
  2.4 Stroke Index             ←  derived data, display-only

Phase 4 (Advanced):
  3.1 Hole Ordering UI         ←  after routing exists
  3.2 Tournament Setup         ←  after pin positions exist
  3.3 Individual Trees         ←  new entity, moderate effort
```

---

## Success Criteria

- **Routing feedback:** Players can see a course rating penalty when holes are poorly routed (long walks) and improve it by adding paths.
- **Tee box impact:** Beginner golfer satisfaction increases measurably when forward tees are available on long holes.
- **Design ceiling:** An expertly designed 18-hole course scores noticeably higher (0.5+ stars) than a haphazardly placed one of equal hole count.
- **Observable behavior:** Players can watch a golfer lay up short of water because the forced carry exceeds their range, and then decide to move the hazard or add a forward tee.
