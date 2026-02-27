# Course Scorecard & Hole Handicaps — Product Spec

**Author:** Claude (Product)
**Date:** 2026-02-27
**Status:** Proposal
**Priority:** MEDIUM
**Version:** 0.1.0-alpha context

---

## Problem Statement

There is no proper course scorecard. The `RoundSummaryPopup` is a 5-second toast notification showing total score and satisfaction. The `HoleStatsPanel` shows per-hole statistics (average score, distribution) but only for one hole at a time. There is no view that shows all 18 holes at once the way a real golf scorecard does — with hole number, par, yardage, handicap index, and a golfer's scores.

Stroke index (hole handicap ranking) does not exist anywhere in the system. `DifficultyCalculator` rates holes 1–10, but this rating is not mapped to the standard 1–18 handicap allocation that appears on every real golf scorecard. This is a missed opportunity: the scorecard is the most iconic artifact in golf, and displaying it properly adds both authenticity and practical design feedback.

---

## Design Principles

- **Model the real thing.** The scorecard should look like a physical golf scorecard — Front 9 / Back 9 split, par row, yardage row, handicap row, player score rows, and totals.
- **Design feedback tool.** The scorecard doubles as a course design diagnostic. Par distribution, yardage variety, and handicap allocation tell the designer whether their course is well-balanced.
- **Zero data entry.** Everything on the scorecard is auto-computed from existing systems (hole par, yardage, difficulty rating, golfer scores).
- **Clean and shareable.** The scorecard should be visually clean enough to screenshot for sharing.

---

## Current System Analysis

### Available Data
- **HoleData** (in `GameManager.CourseData`): `par`, `distance_yards`, `difficulty_rating` (1–10), `tee_position`, `hole_position` (green), `green_tiles[]`, `is_open`
- **Golfer scoring**: `hole_scores[]` array of `{hole, strokes, par}` dictionaries
- **DifficultyCalculator**: Computes per-hole difficulty from length, hazards, slope, obstacles. Returns float 1.0–10.0.
- **HoleStatsPanel**: Shows per-hole average score, best score, score distribution (HIO/eagle/birdie/par/bogey/double+). One hole at a time.
- **CourseRecords**: Tracks `lowest_round`, `hole_in_ones[]`, `best_per_hole{}`.

### Missing Data
- **Stroke index**: Not computed. No 1–18 ranking of holes by difficulty.
- **Course-wide scorecard view**: No UI shows all holes simultaneously.
- **Per-round historical scores**: Individual golfer round scorecards are not persisted after the golfer leaves.

---

## Feature Design

### 1. Stroke Index Calculation

Derive stroke index (handicap allocation) automatically from `DifficultyCalculator` ratings.

**Algorithm:**
```
1. Collect difficulty_rating for all open holes
2. Sort holes by difficulty_rating descending (hardest first)
3. Assign stroke index 1 to hardest, 2 to second hardest, etc.
4. For ties: lower hole number gets the lower (harder) stroke index
5. If fewer than 18 holes: stroke indices are 1..N (not 1..18)
```

**Stroke index allocation pattern (for 18 holes):**

Standard golf convention distributes odd stroke indices to the front nine and even to the back nine to spread difficulty evenly. Adapt this:

```
Front 9 gets odd stroke indices: 1, 3, 5, 7, 9, 11, 13, 15, 17
Back 9 gets even stroke indices: 2, 4, 6, 8, 10, 12, 14, 16, 18
```

**Implementation:**
```gdscript
static func calculate_stroke_indices(holes: Array) -> Dictionary:
    # Returns {hole_number: stroke_index} mapping
    var open_holes = holes.filter(func(h): return h.is_open)

    # Sort by difficulty descending, break ties by hole number
    var sorted = open_holes.duplicate()
    sorted.sort_custom(func(a, b):
        if abs(a.difficulty_rating - b.difficulty_rating) > 0.01:
            return a.difficulty_rating > b.difficulty_rating
        return a.hole_number < b.hole_number
    )

    # Simple sequential assignment for courses with ≤9 holes
    if sorted.size() <= 9:
        var result = {}
        for i in sorted.size():
            result[sorted[i].hole_number] = i + 1
        return result

    # For 10+ holes: interleave front/back nine
    var front_slots = []  # Odd indices: 1,3,5,7,9,11,13,15,17
    var back_slots = []   # Even indices: 2,4,6,8,10,12,14,16,18
    for i in range(1, sorted.size() + 1):
        if i % 2 == 1: front_slots.append(i)
        else: back_slots.append(i)

    var front_holes = sorted.filter(func(h): return h.hole_number <= 9)
    var back_holes = sorted.filter(func(h): return h.hole_number > 9)

    var result = {}
    for i in front_holes.size():
        result[front_holes[i].hole_number] = front_slots[i] if i < front_slots.size() else i + 1
    for i in back_holes.size():
        result[back_holes[i].hole_number] = back_slots[i] if i < back_slots.size() else i + 1

    return result
```

**Recalculation triggers:**
- Hole created or deleted
- Hole difficulty changes (terrain modified near hole, elevation changed)
- Hole toggled open/closed

**Algorithm doc:** Create `docs/algorithms/stroke-index.md` documenting the calculation, the front/back interleaving pattern, and the rationale for tie-breaking.

---

### 2. Course Scorecard Panel

A dedicated panel accessible from the HUD that displays the full course scorecard.

**Layout (18-hole course):**
```
┌──────────────────────────────────────────────────────────────────────────┐
│  PEBBLE CREEK GOLF COURSE                          PARKLAND Theme      │
│  Course Rating: 72.3  │  Slope: 121  │  ★★★★  │  Par 72             │
├────────┬──┬──┬──┬──┬──┬──┬──┬──┬──┬─────┬──────────────────────────────┤
│        │ 1│ 2│ 3│ 4│ 5│ 6│ 7│ 8│ 9│ OUT │                              │
├────────┼──┼──┼──┼──┼──┼──┼──┼──┼──┼─────┤                              │
│ Yards  │420│185│510│380│405│165│445│530│390│3430│                        │
│ Par    │ 4│ 3│ 5│ 4│ 4│ 3│ 4│ 5│ 4│ 36  │                              │
│ Hcp    │ 3│15│ 1│ 9│ 5│17│ 7│11│13│     │                              │
├────────┼──┼──┼──┼──┼──┼──┼──┼──┼──┼─────┼──────────────────────────────┤
│        │10│11│12│13│14│15│16│17│18│  IN  │ TOTAL                        │
├────────┼──┼──┼──┼──┼──┼──┼──┼──┼──┼─────┼─────┬───────────────────────┤
│ Yards  │395│505│175│410│435│540│190│365│440│3455│ 6885                  │
│ Par    │ 4│ 5│ 3│ 4│ 4│ 5│ 3│ 4│ 4│ 36  │  72                        │
│ Hcp    │ 2│10│16│ 8│ 4│12│18│14│ 6│     │                              │
├────────┼──┼──┼──┼──┼──┼──┼──┼──┼──┼─────┼─────┼───────────────────────┤
│ Avg    │4.3│3.1│5.2│4.1│4.4│3.2│4.2│5.1│4.1│37.7│37.2 │ 74.9          │
└────────┴──┴──┴──┴──┴──┴──┴──┴──┴──┴─────┴─────┴───────────────────────┘
```

**Rows:**
1. **Header**: Course name, theme, course rating (scratch golfer expected score), slope rating, star rating, total par
2. **Yards**: Distance from tee to green per hole (from `HoleData.distance_yards`)
3. **Par**: Par value per hole. OUT/IN/TOTAL sums.
4. **Hcp** (Handicap/Stroke Index): 1–18 ranking from stroke index calculation
5. **Avg** (Average Score): Historical average from `HoleManager` statistics. Color-coded: green if ≤par, amber if +0.1 to +0.5, red if >+0.5.

**Adaptive layout:**
- ≤9 holes: Single row (OUT only), no IN section
- 10–18 holes: Front 9 / Back 9 split. Holes 1–9 on top, 10–18 on bottom.
- Fewer than 9 front or back: Show available holes, leave unused cells blank

**Access points:**
- Hotkey `C` (for Course scorecard) — toggleable
- Button in HUD toolbar or hole info area
- Menu: Course → View Scorecard

---

### 3. Score Color Coding

Match standard golf scorecard convention throughout all scorecard displays:

| Score vs Par | Name | Color | Visual Indicator |
|-------------|------|-------|-----------------|
| ≤ -3 | Albatross+ | Gold (#FFD700) | Double circle |
| -2 | Eagle | Gold (#FFD700) | Circle |
| -1 | Birdie | Red (#CC3333) | Circle outline |
| 0 | Par | Default text color | None |
| +1 | Bogey | Blue (#3366CC) | Square outline |
| +2 | Double Bogey | Dark Blue (#1A3366) | Filled square |
| ≥ +3 | Triple+ | Dark Blue (#1A3366) | Double square |

These colors and indicators apply to:
- Course scorecard average row
- Live scorecard in follow mode (Spec: Spectator Camera)
- Round summary popup
- Tournament leaderboard per-round columns

---

### 4. Golfer Round Scorecard

When viewing a specific golfer's completed round (from round summary or follow mode), display their full scorecard with the course scorecard as context:

```
┌──────────────────────────────────────────────────────────┐
│  Pro Anderson  │  Round Score: 69 (-3)  │  Thru: 18/18  │
├────────┬──┬──┬──┬──┬──┬──┬──┬──┬──┬─────┬───────────────┤
│ Par    │ 4│ 3│ 5│ 4│ 4│ 3│ 4│ 5│ 4│ 36  │               │
│ Score  │ 4│②│ 5│ 3│ 4│ 3│③│ 5│ 4│ 33  │               │
├────────┼──┼──┼──┼──┼──┼──┼──┼──┼──┼─────┼───────────────┤
│ Par    │ 4│ 5│ 3│ 4│ 4│ 5│ 3│ 4│ 4│ 36  │  72           │
│ Score  │ 3│ 5│ 3│ 4│ 3│ 5│ 3│ 4│ 4│ 34  │  67  (-5)     │
└────────┴──┴──┴──┴──┴──┴──┴──┴──┴──┴─────┴───────────────┘
```

- ② = birdie (circled 2), ③ = birdie (circled 3)
- Score cells color-coded per the standard (section 3)
- Shows running score-to-par in the total column

---

### 5. Course Info Section

The scorecard header displays computed course metrics:

**Course Rating** (expected score for scratch golfer):
- Already calculated by `CourseRatingSystem` as `total_par + (avg_difficulty - 5.0) * 0.15 * hole_count`
- Display as decimal (e.g., "72.3")

**Slope Rating** (difficulty for bogey golfer relative to scratch):
- Already calculated: `113 + (avg_difficulty - 5.0) * 8.0`
- Range 55–155, standard 113
- Display as integer (e.g., "121")

**Total Yardage**: Sum of all hole distances.

**Star Rating**: Overall course rating (1–5 stars) from `CourseRatingSystem`.

---

### 6. Historical Best Scores

Display the course record holder's scorecard in a dedicated tab or section:

**Course Records section:**
```
┌─────────────────────────────────────────────┐
│  COURSE RECORDS                              │
├─────────────────────────────────────────────┤
│  Lowest Round: 65 (-7) by Pro Martinez      │
│  Day 47                                      │
│                                              │
│  Best Per Hole:                              │
│  #1: 2 (Eagle) by Pro Anderson              │
│  #2: 1 (HIO!) by Serious Kim               │
│  #3: 3 (Eagle) by Pro Williams              │
│  ...                                         │
│                                              │
│  Total Holes-in-One: 3                       │
└─────────────────────────────────────────────┘
```

Data source: `CourseRecords` singleton, which already tracks `lowest_round`, `best_per_hole`, and `hole_in_ones[]`.

---

### 7. Scorecard Print/Export Style

The scorecard should be visually clean for screenshots:

- White or off-white background
- Clear grid lines (1px, medium gray)
- Readable font sizes (12–14px for data, 16px for headers)
- High contrast text (dark gray on white)
- No transparency or overlay effects when viewed standalone
- Course logo area (top-left) — shows theme icon or course name in stylized text

---

## Data Model Changes

### HoleData additions:
```gdscript
# In GameManager.HoleData or computed on demand:
var stroke_index: int = 0    # 1-18, recalculated on course changes
```

### StrokeIndexCalculator (new utility class):
```gdscript
# scripts/systems/stroke_index_calculator.gd
class_name StrokeIndexCalculator

static func calculate(holes: Array) -> Dictionary:
    # Returns {hole_number: stroke_index}
    ...

static func recalculate_for_course(course_data: CourseData) -> void:
    # Updates stroke_index on all HoleData objects
    ...
```

### No save format changes needed:
- Stroke index is derived data — recalculated on load from difficulty ratings
- Course records already persisted by `SaveManager`
- No new persistent state required

---

## Signals

### Existing signals consumed:
- `hole_created`, `hole_deleted`, `hole_updated` — trigger stroke index recalculation
- `hole_difficulty_changed` — trigger stroke index recalculation
- `golfer_finished_hole` — update live scorecard (in follow mode)
- `golfer_finished_round` — show round summary scorecard
- `course_rating_changed` — update scorecard header metrics
- `record_broken` — update course records display

---

## Implementation Sequence

```
Phase 1 (Foundation):
  1. StrokeIndexCalculator — derive stroke indices from difficulty ratings
  2. Wire recalculation to hole create/delete/update signals
  3. Display stroke index in HoleStatsPanel (existing panel, add one line)

Phase 2 (Course Scorecard):
  4. CourseScorecard panel — full 18-hole grid layout
  5. Adaptive layout for <18 holes
  6. Score color coding system (shared utility)
  7. Course info header (rating, slope, yardage, stars)
  8. Hotkey 'C' to toggle

Phase 3 (Golfer Integration):
  9. Golfer round scorecard in enhanced round summary
  10. Historical course records section
  11. Average score row with color coding

Phase 4 (Integration with Follow Mode):
  12. Live scorecard in follow mode uses same color coding
  13. Tournament scorecard integration
```

---

## Success Criteria

- Course scorecard displays all holes with par, yardage, and stroke index
- Stroke index correctly ranks holes by difficulty (hardest = 1)
- Score color coding matches standard golf conventions (birdie = red circle, bogey = blue square)
- Scorecard adapts to courses with fewer than 18 holes
- Course info header shows accurate course rating, slope, and star rating
- Scorecard is visually clean enough to screenshot and share
- Stroke index recalculates automatically when holes are modified
- Course records section shows lowest round and best-per-hole data

---

## Out of Scope

| Feature | Reason |
|---------|--------|
| Handicap differential calculation | Requires player handicap system — future feature |
| Net score computation | Needs handicap system |
| Printable PDF export | Browser print handles this adequately |
| Multiple tee box yardage rows | Depends on Multiple Tee Boxes feature (Course Design Upgrades 1.2) |
| Match play scoring | Different scoring format — separate spec if needed |
| Stableford scoring | Alternative scoring — separate spec |
