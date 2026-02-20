# Golfer Spawning & Tier System

> **Source:** `scripts/managers/golfer_manager.gd` and `scripts/systems/golfer_tier.gd`

## Plain English

The golfer spawning system controls how many golfers visit the course and what types they are. It balances several factors to create a dynamic flow of golfers that responds to how the player designs and manages their course.

### Spawn Rate

Golfers arrive in groups with a cooldown between each spawn. The cooldown is shortened when the course has a high rating, good weather, active marketing campaigns, and seasonal demand (summer is busier). A 5-star course in good weather spawns golfers roughly twice as fast as a 1-star course in rain.

### Capacity

The maximum number of golfers on the course scales with hole count — each hole supports up to 4 concurrent golfers. This prevents overcrowding but rewards building more holes with increased revenue potential.

### Tier Selection

Each golfer belongs to one of four tiers: Beginner, Casual, Serious, or Pro. Tier selection uses a **weighted random system** where the weights are dynamically adjusted based on:
- **Course rating** — Higher-tier golfers require higher minimum ratings
- **Green fee** — Expensive courses repel budget players, attract premium ones
- **Reputation** — Pros won't visit unknown courses (reputation < 70)
- **Hole count** — Serious/pro golfers expect at least 9 holes
- **Course difficulty** — Hard courses attract pros, easy courses attract beginners

### Group Size

Groups of 1–4 golfers spawn together. Higher green fees attract larger groups (foursomes), while budget courses see more singles and pairs.

### Landing Zone Safety

Before spawning a new group, the system checks that the first tee's landing zone is clear using a **cone-shaped directional check**. This prevents new groups from hitting into golfers already on the course.

---

## Algorithm

### 1. Spawn Rate Modifier (Compound)

```
# Base: 1-star = 0.5x, 3-star = 1.0x, 5-star = 1.5x
base_modifier = 0.5 + (overall_rating - 1.0) * 0.25

# Compound with other factors
base_modifier *= weather_spawn_modifier          # 0.3 (heavy rain) to 1.0 (sunny)
base_modifier *= marketing_spawn_modifier        # 1.0 (none) to higher (active campaign)
base_modifier *= seasonal_spawn_modifier         # Varies by season
base_modifier *= seasonal_event_modifier         # Special event boost/reduction
```

### 2. Effective Spawn Cooldown

```
min_spawn_cooldown = 10.0 seconds   # Configurable @export
cooldown = min_spawn_cooldown / spawn_rate_modifier

# Example: 3-star course, sunny weather
# modifier = 1.0, cooldown = 10 seconds
# Example: 1-star course, heavy rain
# modifier = 0.5 * 0.3 = 0.15, cooldown = 67 seconds
```

### 3. Maximum Concurrent Golfers

```
max_golfers = max(4, open_hole_count * 4)
```

| Holes | Max Golfers |
| ----- | ----------- |
| 1 | 4 |
| 4 | 16 |
| 9 | 36 |
| 18 | 72 |

### 4. Tier Data

| Tier | Skill Range | Tendency | Spending | Min Rating | Min Holes | Rep Gain | Base Weight |
| ---- | ----------- | -------- | -------- | ---------- | --------- | -------- | ----------- |
| Beginner | 0.30–0.50 | 0.4–0.8 | 0.7x | 1.0 | 1 | 1 | 0.35 |
| Casual | 0.50–0.70 | 0.2–0.5 | 1.0x | 2.0 | 4 | 2 | 0.40 |
| Serious | 0.70–0.85 | 0.1–0.3 | 1.5x | 3.0 | 9 | 4 | 0.20 |
| Pro | 0.85–0.98 | 0.0–0.15 | 2.0x | 4.0 | 9 | 10 | 0.05 |

### 5. Tier Weight Calculation

Starting from `spawn_weight_base`, apply multipliers:

```
weight = base_weight

# Rating filter
if course_rating < min_course_rating:
    weight *= 0.1                   # Drastically reduce

# Hole count filter
if hole_count < min_holes:
    weight *= 0.05                  # Nearly eliminate

# Fee attractiveness
fee_factor = green_fee / 50.0      # Normalize around $50
if fee_factor > spending_modifier * 1.5:
    weight *= 0.3                   # Too expensive
elif fee_factor < spending_modifier * 0.5:
    weight *= 1.5                   # Good value

# Reputation requirements
if tier == PRO and reputation < 70:
    weight *= 0.1                   # Pros don't visit unknown courses
elif tier == SERIOUS and reputation < 50:
    weight *= 0.5

# Difficulty attraction
if difficulty >= 7.0:
    PRO:      weight *= 2.0         # Love challenging courses
    SERIOUS:  weight *= 1.5
    BEGINNER: weight *= 0.5         # Avoid hard courses
elif difficulty >= 5.0:
    SERIOUS:  weight *= 1.25        # Moderate challenge appeals
elif difficulty < 3.0:
    BEGINNER: weight *= 1.5         # Easy courses attract beginners
    CASUAL:   weight *= 1.25
    PRO:      weight *= 0.3         # Pros avoid easy courses
```

### 6. Weighted Random Selection

```
total = sum of all tier weights
roll  = randf() * total

cumulative = 0.0
for each tier:
    cumulative += weight[tier]
    if roll <= cumulative:
        return tier
```

### 7. Skill Generation (Per Golfer)

```
skills = {
    driving:  randf_range(skill_low, skill_high),
    accuracy: randf_range(skill_low, skill_high),
    putting:  randf_range(skill_low, skill_high),
    recovery: randf_range(skill_low, skill_high),
}

# Miss tendency
tendency_magnitude = randf_range(tendency_low, tendency_high)
tendency_sign = +1 or -1 (50/50)
miss_tendency = magnitude * sign
```

### 8. Personality Generation (Per Tier)

| Tier | Aggression Range | Patience Range |
| ---- | ---------------- | -------------- |
| Beginner | 0.2–0.4 (conservative) | 0.6–0.9 (patient) |
| Casual | 0.3–0.6 | 0.4–0.7 |
| Serious | 0.5–0.7 | 0.3–0.6 |
| Pro | 0.6–0.9 (confident) | 0.2–0.5 (expects fast pace) |

### 9. Group Size Distribution

| Fee Range | Singles | Pairs | Threesomes | Foursomes |
| --------- | ------- | ----- | ---------- | --------- |
| < $25 | 40% | 30% | 20% | 10% |
| $25–50 | 20% | 30% | 30% | 20% |
| $50–100 | 10% | 20% | 30% | 40% |
| > $100 | 5% | 15% | 25% | 55% |

### 10. Landing Zone Safety Check

Before spawning a new group, check the first tee's landing zone:

```
# Par 3: Check if any golfer is still on the hole
if first_hole.par == 3:
    return no golfer on hole 0

# Par 4+: Cone-based check
effective_distance = min(TYPICAL_DRIVER_DISTANCE, hole_length * 0.7)
landing_target = tee + direction * effective_distance
lateral_radius = LANDING_ZONE_BASE_RADIUS + effective_distance * LANDING_ZONE_VARIANCE
               = 2.0 + effective_distance * 0.3

CONE_HALF_ANGLE = 45 degrees

for each active golfer (from earlier groups):
    skip if behind the tee (negative dot product)
    skip if too close (< 60% of shot distance)
    skip if too far (> shot distance + radius)
    if angle to golfer < 45 degrees:
        landing zone blocked → don't spawn
```

### Tuning Levers

| Parameter | Location | Current Value | Effect |
| --- | --- | --- | --- |
| Min spawn cooldown | `golfer_manager.gd:8` | 10.0 seconds | Lower = more frequent spawns |
| Rating-to-modifier formula | `golfer_manager.gd:54` | 0.5 + (rating-1)*0.25 | Higher = more golfers at low ratings |
| Max golfers per hole | `golfer_manager.gd:98` | 4 | Higher = more crowded course |
| Tier base weights | `golfer_tier.gd:16-60` | 0.35/0.40/0.20/0.05 | Base probability of each tier |
| Tier skill ranges | `golfer_tier.gd:16-60` | See table | Skill bounds per tier |
| Rating filter multiplier | `golfer_tier.gd:86` | 0.1 | Lower = harder to attract above-tier golfers |
| Hole count filter | `golfer_tier.gd:91` | 0.05 | Lower = stricter hole count requirement |
| Fee normalization | `golfer_tier.gd:95` | $50 | Changes what's considered "normal" price |
| Pro reputation threshold | `golfer_tier.gd:102` | 70 | Lower = pros visit less-known courses |
| Serious rep threshold | `golfer_tier.gd:104` | 50 | Lower = serious golfers visit sooner |
| Difficulty thresholds | `golfer_tier.gd:110-126` | 3.0/5.0/7.0 | When difficulty bonuses kick in |
| Landing zone base radius | `golfer_manager.gd:85` | 2.0 tiles | Wider = more cautious spawning |
| Landing zone variance | `golfer_manager.gd:86` | 0.3 (30%) | Higher = more cautious on long shots |
| Cone half-angle | `golfer_manager.gd:147` | 45 degrees | Wider = more conservative safety check |
