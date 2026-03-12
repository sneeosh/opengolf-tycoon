# Aesthetics Rating

> **Source:** `scripts/systems/course_rating_system.gd` → `_calculate_aesthetics_rating()`

## Plain English

The aesthetics rating measures how well-landscaped and visually appealing the course is. It's one of five categories in the course rating system, weighted at **10%** of the overall star rating.

For each open hole, the system looks at decorations, trees, and rocks within an **8-tile radius** of both the tee box and green. More decorations = higher score, but with **diminishing returns** — spamming the same decoration type yields less and less benefit. Using a **variety** of decoration types earns a bonus. Decorations that match the course's **theme** (e.g., fountains on a Resort course) get a 1.5× multiplier.

Trees and rocks also contribute small amounts (0.15 and 0.1 per entity respectively), rewarding natural landscaping even without purchased decorations.

The per-hole scores are averaged across all open holes, so a course with only one beautifully decorated hole and several bare ones will score lower than one with consistent landscaping throughout.

---

## Algorithm

### 1. Per-Hole Scoring

For each open hole:

```
search_radius = 8 tiles

# Find decorations near tee and green (deduplicated)
tee_decorations  = decorations within 8 tiles of tee_position
green_decorations = decorations within 8 tiles of green_position
all_decorations  = union(tee_decorations, green_decorations)  # no duplicates

decoration_score = 0.0
type_counts = {}  # track count per decoration type

for each decoration:
    type_counts[type] += 1

    # Diminishing returns per type
    diminished_value = aesthetics_value / (1.0 + 0.2 * (same_type_count - 1))

    # Theme bonus: 1.5x if decoration matches course theme
    if decoration.theme_bonus contains current_theme:
        diminished_value *= 1.5

    decoration_score += diminished_value

# Trees contribute 0.15 each (deduplicated across tee/green areas)
decoration_score += tree_count_nearby * 0.15

# Rocks contribute 0.1 each
decoration_score += rock_count_nearby * 0.1

# Variety bonus
if unique_decoration_types >= 4: decoration_score += 0.5
elif unique_decoration_types >= 2: decoration_score += 0.25

# Cap per-hole at 4.0 raw points
decoration_score = min(decoration_score, 4.0)

# Map to 1-5 star range (0 pts = 1 star, 2+ pts = 5 stars)
hole_rating = clamp(1.0 + decoration_score * 2.0, 1.0, 5.0)
```

### 2. Final Aesthetics Rating

```
aesthetics = average(all_hole_ratings)
aesthetics = clamp(aesthetics, 1.0, 5.0)
```

### 3. Diminishing Returns Example

| Same Type Count | Effective Value (base 1.0) |
|----------------|---------------------------|
| 1st | 1.00 |
| 2nd | 0.83 |
| 3rd | 0.71 |
| 4th | 0.63 |
| 5th | 0.56 |

### 4. Theme Bonus

Each decoration has a `theme_bonus` array listing which course themes it matches. When placed on a matching-theme course, its contribution is multiplied by 1.5×.

Example: A fountain (`theme_bonus: ["CITY", "TROPICAL", "RESORT"]`) on a Resort course contributes `1.0 × 1.5 = 1.5` aesthetics points (before diminishing returns).

---

## Tuning Levers

| Parameter | Location | Current Value | Effect |
|-----------|----------|---------------|--------|
| Search radius | `course_rating_system.gd` | 8 tiles | How far from tee/green decorations are counted |
| Diminishing returns factor | `course_rating_system.gd` | 0.2 | Higher = faster diminishing returns per same type |
| Theme multiplier | `course_rating_system.gd` | 1.5× | Bonus for theme-appropriate decorations |
| Tree contribution | `course_rating_system.gd` | 0.15 per tree | How much trees help aesthetics |
| Rock contribution | `course_rating_system.gd` | 0.1 per rock | How much rocks help aesthetics |
| Variety bonus (2+ types) | `course_rating_system.gd` | +0.25 | Reward for using 2+ decoration types |
| Variety bonus (4+ types) | `course_rating_system.gd` | +0.5 | Reward for using 4+ decoration types |
| Per-hole cap | `course_rating_system.gd` | 4.0 | Maximum raw score per hole |
| Score-to-stars multiplier | `course_rating_system.gd` | 2.0 | How quickly raw score maps to stars |
| Aesthetics weight in overall | `course_rating_system.gd` | 10% | Weight of aesthetics in overall course rating |
| Per-decoration aesthetics_value | `data/decorations.json` | 0.1–1.0 | Base value per decoration type |
