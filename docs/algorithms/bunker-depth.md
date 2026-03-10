# Bunker Depth (Shallow vs Deep)

> **Source:** `scripts/terrain/terrain_grid.gd` (_bunker_depth_grid), `scripts/systems/golf_rules.gd`, `scripts/course/difficulty_calculator.gd`, `scripts/terrain/bunker_overlay.gd`

## Plain English

Bunkers have two depths: SHALLOW (default) and DEEP. Deep bunkers (pot bunkers) are harder to escape — shots from deep bunkers are less accurate and travel shorter distances. They also contribute more to hole difficulty.

Players toggle depth by Shift+clicking on bunker tiles. Links and Heathland themes default to DEEP when placing new bunkers.

---

## Algorithm

### 1. Data Model

```
_bunker_depth_grid: Dictionary  # Vector2i -> 0 (SHALLOW) or 1 (DEEP)
```

Stored separately from the terrain grid. Only non-zero depths are persisted.

### 2. Lie Modifier (Accuracy)

```
SHALLOW bunker:
  Wedge:  0.6  (40% accuracy penalty)
  Other:  0.4  (60% accuracy penalty)

DEEP bunker:
  Wedge:  0.45 (55% accuracy penalty)
  Other:  0.25 (75% accuracy penalty)
```

### 3. Distance Modifier

```
SHALLOW: 0.75 (25% distance loss)
DEEP:    0.60 (40% distance loss — ball pops out shorter)
```

### 4. Difficulty Rating

```
Per bunker tile in corridor:
  SHALLOW: +0.15 difficulty
  DEEP:    +0.25 difficulty
```

### 5. Visual Differentiation

```
SHALLOW bunkers:
  Dot count: 6-12 (3-5 on web)
  Dot radius: 0.8-1.5px
  Dot color: Color(0.75, 0.68, 0.45, 0.35)

DEEP bunkers:
  Dot count: 10-18 (5-8 on web)
  Dot radius: 1.0-2.0px
  Dot color: Color(0.60, 0.55, 0.35, 0.45)
```

### 6. Theme Defaults

```
LINKS:     default_bunker_depth = 1 (DEEP)
All others: default_bunker_depth = 0 (SHALLOW)
```

---

## Tuning Levers

| Parameter | Location | Current Value | Effect |
| --- | --- | --- | --- |
| Shallow lie modifier (wedge) | `golf_rules.gd` | 0.6 | Accuracy from shallow bunker with wedge |
| Shallow lie modifier (other) | `golf_rules.gd` | 0.4 | Accuracy from shallow bunker with non-wedge |
| Deep lie modifier (wedge) | `golf_rules.gd` | 0.45 | Accuracy from deep bunker with wedge |
| Deep lie modifier (other) | `golf_rules.gd` | 0.25 | Accuracy from deep bunker with non-wedge |
| Shallow distance modifier | `golf_rules.gd` | 0.75 | Distance retention from shallow bunker |
| Deep distance modifier | `golf_rules.gd` | 0.60 | Distance retention from deep bunker |
| Shallow difficulty per tile | `difficulty_calculator.gd` | 0.15 | Difficulty contribution per shallow bunker tile |
| Deep difficulty per tile | `difficulty_calculator.gd` | 0.25 | Difficulty contribution per deep bunker tile |
| Deep dot count range | `bunker_overlay.gd` | 10-18 | Visual density of deep bunker overlay |
| Deep dot color | `bunker_overlay.gd` | (0.60, 0.55, 0.35, 0.45) | Visual darkness of deep bunker |
