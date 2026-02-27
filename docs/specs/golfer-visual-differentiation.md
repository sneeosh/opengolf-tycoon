# Golfer Visual Differentiation & Identity — Product Spec

**Author:** Claude (Product)
**Date:** 2026-02-27
**Status:** Proposal
**Priority:** MEDIUM
**Version:** 0.1.0-alpha context

---

## Problem Statement

All golfers are procedurally rendered stick figures composed of 11–14 Polygon2D nodes. While the rendering system already supports tier-based shirt color palettes and randomized accessories (cap, hair, collar), the visual differentiation is subtle — players can't glance at the course and quickly identify a Beginner from a Pro, can't distinguish groups, and can't recognize "regular" golfers who return to the course.

This reduces the connection between observing the simulation and caring about outcomes. When every golfer looks like a generic stick figure, a Pro shooting -5 is indistinguishable from a Beginner struggling to break 100.

---

## Design Principles

- **Tier identity at a glance.** Players should identify a golfer's tier from the zoomed-out course view without clicking.
- **Minimal approach preferred.** Colored outlines and badges are cheaper and more effective than detailed sprite art for isometric stick figures.
- **Identity builds connection.** Named "regular" golfers who return create attachment and narrative.
- **State readability.** Visual indicators should communicate golfer state (tired, frustrated, playing well) without requiring thought bubble text.

---

## Current System Analysis

### Golfer Visual System
- **Body**: 11–14 Polygon2D nodes (head, body, arms, legs, shoes, collar, hands, hair, cap, cap_brim, golf_club)
- **Walk animation**: 2-frame cycle (0.25s per frame), legs and shoes swap between standing and stride
- **Vertical bob**: `sin(Time.get_ticks_msec() / 150.0) * 1.5` pixels during walk
- **Arm swing**: `sin(Time.get_ticks_msec() / 200.0) * 0.15` radians during walk

### Existing Color Differentiation
Already implemented but subtle:
- **Beginners**: Bright mismatched colors (orange, yellow, pink, lime, turquoise)
- **Casual**: Standard polo colors (blue, green, red, white, teal, purple)
- **Serious**: Refined athletics (navy, forest green, charcoal, burgundy, steel blue)
- **Pro**: Sponsored/branded (near-black, tour white, midnight blue, carbon)

### Name Labels
- Visible on click (golfer selection)
- Tier-colored text in name label
- Not visible during general gameplay (hover not implemented)

### Group System
- Groups of 1–4 golfers sharing `group_id`
- No visual group indicator (badge, color coding, or numbering)
- Turn order managed by `GolferManager` (honor system / away rule)

---

## Feature Design

### 1. Tier-Based Visual Ring

Add a colored circle/ring beneath each golfer that indicates their tier at all zoom levels:

| Tier | Ring Color | Ring Style |
|------|-----------|------------|
| BEGINNER | Green (#4CAF50) | Solid thin ring |
| CASUAL | Blue (#2196F3) | Solid thin ring |
| SERIOUS | Red (#F44336) | Solid ring, slightly thicker |
| PRO | Gold (#FFD700) | Solid ring with subtle pulse |

**Implementation:**
```gdscript
func _draw() -> void:
    # Draw tier ring beneath golfer (before body rendering)
    var ring_color = TIER_RING_COLORS[golfer_tier]
    var ring_radius = 8.0
    var ring_width = 1.5 if golfer_tier <= Tier.CASUAL else 2.0
    draw_arc(Vector2(0, 2), ring_radius, 0, TAU, 32, ring_color, ring_width)

    # Pro tier: subtle pulse
    if golfer_tier == Tier.PRO:
        var pulse = 0.7 + 0.3 * sin(Time.get_ticks_msec() / 500.0)
        draw_arc(Vector2(0, 2), ring_radius + 1, 0, TAU, 32,
                 Color(ring_color, pulse), 1.0)
```

**Visibility:** Ring is always visible at all zoom levels. At zoomed-out views (0.5× zoom), the ring is the primary visual identifier since the stick figure is too small for detail.

---

### 2. Name Label on Hover

Show golfer name and tier on mouse hover without clicking:

**Hover label:**
```
┌──────────────────┐
│ Pro Anderson  ★★★★│
└──────────────────┘
```

- Appears on mouse hover within 20px of golfer
- Background: dark semi-transparent panel
- Text color: tier ring color
- Stars: tier indicator (1 star per tier level — Beginner ★, Pro ★★★★)
- Disappears on mouse exit
- Does not require clicking (click still opens full info)

**Implementation:** Use `_input` with mouse position detection. Show a lightweight `Label` node offset above the golfer. Pool label nodes to avoid allocation churn.

---

### 3. Group Number Badge

Small badge showing group number for multi-golfer groups:

**Badge display:**
```
    G3
  [golfer]
  ○ ring
```

- Tiny badge (12×12px) positioned above and to the right of the golfer head
- Background: group-unique color (generated from group_id hash)
- Text: "G" + group_id (e.g., "G1", "G2", "G3")
- Only visible when 2+ golfers share the same group_id
- Solo golfers (group size 1) don't show a badge

**Color generation:**
```gdscript
func _get_group_color(group_id: int) -> Color:
    var hue = fmod(group_id * 0.618033988749895, 1.0)  # Golden ratio
    return Color.from_hsv(hue, 0.6, 0.9)
```

---

### 4. Regular Golfer System

Named golfers who return to the course if satisfaction was high:

**Regular golfer mechanics:**
- When a golfer finishes a round with mood ≥ 0.7 (Satisfied or Very Happy), there's a 20% chance they become a "regular"
- Regular golfers are stored in a persistent list (max 20 regulars)
- Each regular has: name, tier, skills (frozen at time of first visit), visit count, last visit day
- Regular golfers have a 30% chance to appear in the daily spawn pool (replacing a random golfer of the same tier)
- After 3+ visits, regulars get a small heart icon next to their name (visible on hover)

**Regular golfer data:**
```gdscript
class RegularGolfer:
    var name: String
    var tier: int
    var skills: Dictionary           # {driving, accuracy, putting, recovery}
    var miss_tendency: float
    var visit_count: int = 1
    var last_visit_day: int
    var first_visit_day: int
    var best_score: int = -1         # Best round score on this course
    var satisfaction_avg: float = 0.0
```

**Regular golfer benefits:**
- Regulars increase reputation gain by 1.5× (they tell their friends)
- Regulars are less price-sensitive (fee tolerance +20%)
- Regulars have established expectations — if the course quality drops below their first visit, they stop returning

**Persistence:** Regular golfer list is saved/loaded with the game. They respawn from the stored data, not from the golfer entity state.

---

### 5. Visual State Indicators

Communicate golfer internal state through visual changes:

**Fatigue (low energy):**
- When energy < 0.3: golfer walk speed reduces by 15% (already implemented via needs)
- Visual: golfer body offset tilts slightly (1-2 pixel lean forward)
- Visual: walk animation slows (0.35s per frame instead of 0.25s)

**Hunger (low hunger need):**
- When hunger < 0.3: thought bubble fires (already implemented)
- Visual: no additional visual change (thought bubble is sufficient)

**Frustration (low mood):**
- When mood < 0.3: subtle red tint on golfer body
- Implementation: `modulate = Color(1.2, 0.85, 0.85)` — slight red shift
- Resets to `Color.WHITE` when mood recovers above 0.4

**Playing well (mood > 0.8):**
- Visual: subtle golden glow around golfer (additive blend, very faint)
- Implementation: extra ring at `Color(1.0, 0.95, 0.5, 0.3)` — barely visible warm aura

**Tournament indicator:**
- Tournament golfers get a small flag badge (instead of or in addition to group badge)
- Badge color matches tournament tier (LOCAL blue, REGIONAL green, NATIONAL red, CHAMPIONSHIP gold)

---

### 6. Active Golfer Highlight

The golfer whose turn it is (currently taking a shot or preparing) should be more prominent:

**Current behavior:** An active highlight ring exists but is subtle.

**Enhanced highlight:**
- Golfer whose turn it is: ring brightens to full opacity + slight scale increase (1.05×)
- Other golfers in same group: ring at 50% opacity
- Golfers in different groups: ring at 30% opacity

This creates a natural visual hierarchy: "Who's playing right now?" is immediately clear.

---

## Data Model Changes

### Golfer entity additions:
```gdscript
# Visual state
var is_hovered: bool = false
var frustration_tint: float = 0.0     # 0-1, mapped to red shift

# Regular golfer
var is_regular: bool = false
var regular_data: RegularGolfer = null  # Reference if this is a regular
```

### RegularGolferManager (new):
```gdscript
# scripts/managers/regular_golfer_manager.gd

var regulars: Array[RegularGolfer] = []
const MAX_REGULARS: int = 20
const REGULAR_CHANCE: float = 0.20     # 20% chance on high satisfaction
const REGULAR_SPAWN_CHANCE: float = 0.30  # 30% chance to appear in spawn pool

func check_for_regular(golfer: Golfer) -> void:
    if golfer.current_mood >= 0.7 and randf() < REGULAR_CHANCE:
        _add_regular(golfer)

func get_regular_for_spawn(tier: int) -> RegularGolfer:
    var tier_regulars = regulars.filter(func(r): return r.tier == tier)
    if tier_regulars.is_empty() or randf() > REGULAR_SPAWN_CHANCE:
        return null
    return tier_regulars.pick_random()
```

### Save/Load:
```gdscript
# Regular golfers persisted:
{
    "regular_golfers": [
        {
            "name": "Pro Anderson",
            "tier": 3,
            "skills": {"driving": 0.92, "accuracy": 0.88, ...},
            "miss_tendency": -0.05,
            "visit_count": 4,
            "last_visit_day": 45,
            "best_score": 68
        },
        ...
    ]
}
```

---

## Implementation Sequence

```
Phase 1 (Immediate Visual Impact):
  1. Tier-based colored rings beneath all golfers
  2. Name label on hover (without click)
  3. Group number badge

Phase 2 (State Indicators):
  4. Frustration red tint (mood < 0.3)
  5. Fatigue visual (walk slow, lean)
  6. Playing-well golden glow (mood > 0.8)
  7. Active golfer highlight enhancement

Phase 3 (Regular Golfers):
  8. RegularGolferManager with persistence
  9. Regular golfer spawn integration
  10. Heart icon for 3+ visits
  11. Regular golfer reputation bonus
  12. Save/load integration

Phase 4 (Tournament):
  13. Tournament golfer badge (tier-colored flag)
  14. Tournament visual distinction during play
```

---

## Success Criteria

- Players can identify golfer tier from the zoomed-out course view by ring color
- Hovering over a golfer shows name and tier without clicking
- Groups are visually distinguishable by group number badge
- Frustrated golfers (mood < 0.3) have a visible red tint
- Regular golfers return to the course and are recognizable (heart icon)
- Tournament golfers are visually distinct from regular golfers
- Pro golfers feel special (gold ring with pulse)
- Visual indicators don't clutter the screen or cause performance issues

---

## Out of Scope

| Feature | Reason |
|---------|--------|
| Full sprite replacement for golfers | Covered by Visual Polish spec |
| Golfer customization by player | Not a character creation game |
| Golfer face/expression details | Too small for isometric view |
| Golfer equipment visibility (golf bag, cart) | Visual complexity |
| Named golfer storylines / dialogue | No narrative system |
| Golfer achievements / records per regular | Excessive tracking |
