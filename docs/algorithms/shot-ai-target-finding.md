# Target Finding & Club Selection (ShotAI)

> **Source:** `scripts/systems/shot_ai.gd`

## Plain English

When a golfer's turn comes, they need to decide **where to aim** and **which club to use**. This is handled by the ShotAI system, which acts as the golfer's "brain." It follows a structured decision pipeline:

1. **Assess the lie** — Is the ball in trouble (trees, deep rough, rocks)? If the lie quality is below 0.4, switch to recovery mode.
2. **Plan the shot sequence** — How many shots will it take to reach the hole? Work backwards from the green to figure out the ideal distance for THIS shot.
3. **Evaluate candidates** — For each possible club, scan a fan of angles and distances around the target direction. Score each landing zone on terrain quality, distance advancement, hazard risk, and next-shot setup.
4. **Apply personality** — Aggressive golfers discount hazard penalties; cautious golfers amplify them. Golfers who are over par play more aggressively; those under par play conservatively.
5. **Pick the best** — Sort candidates by score, return the highest-scoring option.

### Recovery Mode

When in trees, deep rough, bunkers, or rocks, the golfer enters recovery mode. Club selection is restricted (no woods through trees, wedge-only from rocks). The AI scans a full 360 degrees for escape routes — even sideways or backwards is a valid option. It strongly prefers nearby safe targets (distance penalty of 2.0 per tile from ball) and rewards advancing toward the hole, with modest bonuses for landing on fairway (+30) or green (+50). This prevents golfers from choosing a distant fairway over a nearby green strip when escaping bunkers.

### Wind Compensation

The AI accounts for wind by predicting where the ball will actually land (wind-adjusted), then shifting the aim point in the opposite direction. Better players compensate more accurately: pros adjust ~80% of the wind effect, beginners only ~20%.

### Green Center Bias

On approach shots, less skilled golfers aim more toward the center of the green rather than directly at the pin. This reduces the chance of missing the green entirely. Pros aim 90% at the pin; beginners aim 60% at the pin and 40% toward center.

### Multi-Shot Planning

For par 4s and par 5s, the AI plans backwards from the green. The ideal strategy is to leave a comfortable wedge approach (~77 yards) for the final shot. On a par 5, it splits the remaining distance into two long shots plus the approach.

---

## Algorithm

### 1. Lie Assessment

```
lie_quality = terrain_to_quality_score:
    Fairway / Tee Box / Green:  1.0
    Grass:                       0.8
    Path:                        0.7
    Rough:                       0.5
    Heavy Rough / Bunker:        0.3
    Trees:                       0.15
    Rocks:                       0.1

if lie_quality < 0.4:  → enter recovery mode
```

### 2. Multi-Shot Planning

```gdscript
# Estimate shots remaining
max_driver_dist = CLUB_STATS[DRIVER].max_distance * skill_distance_factor

if distance_to_hole <= 1.0:         shots = 1  # Chip/putt range
elif distance_to_hole <= wedge_max:  shots = 1  # Wedge range
elif distance_to_hole <= driver_max: shots = 1  # Can reach in one
elif distance_to_hole <= driver_max * 2.0: shots = 2
else:                                shots = 3

# Ideal distance for current shot
ideal_approach = 3.5 tiles  # ~77 yards, comfortable wedge

if shots_remaining == 1:  target_distance = distance_to_hole
if shots_remaining == 2:  target_distance = min(distance_to_hole - ideal_approach, max_driver)
if shots_remaining == 3:  target_distance = min((distance_to_hole - ideal_approach) / 2, max_driver)
```

### 3. Skill-Based Distance Factor

How far each golfer can hit relative to the club's maximum:

```
Driver:       0.40 + driving_skill  * 0.55    → range: 0.40 – 0.95
Fairway Wood: 0.40 + driving_skill  * 0.50    → range: 0.40 – 0.90
Iron:         0.50 + accuracy_skill * 0.42    → range: 0.50 – 0.92
Wedge:        0.80 + accuracy_skill * 0.18    → range: 0.80 – 0.98
Putter:       0.92 + putting_skill  * 0.06    → range: 0.92 – 0.98
```

### 4. Candidate Evaluation (Core Decision Engine)

For each candidate club, scan angles and distances:

**Scan parameters:**
- Approach shots (can reach green): +/-15 degrees, 15 angle samples, 7 distance samples
- Layup shots: +/-50 degrees, 25 angle samples, 7 distance samples
- **Wide re-scan**: If approach scan's best candidate lands on grass/rough (not fairway/green/tee), re-scans at +/-50 degrees filtering for good terrain only. Prevents AI from aiming through grass when fairway is at an angle.

**Distance scan range:**
- Wedge approach: from 0.25 tiles (~5.5 yards) up to 110% of effective max
- Standard: from 60% to 110% of effective max

**Terrain scores** (large gaps to dominate over distance bonuses):

| Terrain      | Score   |
| ------------ | ------- |
| Green        | +180    |
| Fairway      | +150    |
| Tee Box      | +130    |
| Grass        | +40     |
| Path         | +35     |
| Rough        | +10     |
| Heavy Rough  | -20     |
| Flower Bed   | -40     |
| Bunker       | -50     |
| Trees        | -80     |
| Rocks        | -100    |
| Empty        | -200    |
| Water        | -1000   |
| Out of Bounds| -1000   |

### 5. Landing Zone Scoring

```
score  = terrain_score[landing_terrain]

# Tree collision check — instant disqualification if flight path blocked
if path_crosses_trees(ball_pos, landing) at low altitude:
    score = -2000

# Graduated tree overfly penalty (density scaling for tree lines)
trees_overflown = count_trees_along_path(ball_pos, landing)
density_multiplier = 1.0 + max(trees_overflown - 2, 0) * 0.5  # 3+ trees = near-impassable
tree_penalty = 50.0 * trees_overflown * (1.0 - accuracy_skill * 0.3) * density_multiplier
score -= tree_penalty

# Advancement toward hole
advancement = current_distance_to_hole - new_distance_to_hole
if advancement <= 0:  score -= 500  # Harsh penalty for no progress

# Distance scoring
if shots_remaining <= 1:
    score -= distance_to_hole * 5.0      # Approach: getting close is paramount
else:
    score -= distance_to_hole * 2.0      # Layup: terrain quality matters more
    # Bonus for ideal approach distance (~3.5 tiles)
    if abs(distance_to_hole - 3.5) < 2.0:
        score += (2.0 - abs(distance_to_hole - 3.5)) * 25.0  # Up to +50

# Next-shot setup bonus (clear path to hole from landing zone)
if shots_remaining > 1 and terrain is fairway/grass/tee:
    if no trees between landing and hole:
        score += 40

# Nearby hazard penalty
for each tile within 2-tile radius:
    if water or OB or EMPTY:
        penalty += (20.0 / distance_to_hazard) * (1.0 - aggression * 0.5)
    elif TREES:
        penalty += (10.0 / distance_to_hazard) * (1.0 - aggression * 0.3)
score -= nearby_hazard_penalty
```

### 6. Risk Analysis (Monte Carlo Miss Sampling)

```
# Sample 8 deterministic miss positions across the dispersion distribution
sigma_values = [-2.0, -1.0, -0.5, -0.25, 0.25, 0.5, 1.0, 2.0]

for each sigma in sigma_values:
    sample_angle = sigma * spread_std_dev + tendency_bias
    miss_landing = ball_pos + rotated_direction * distance
    if miss_landing is water or OB:
        hazard_hits += 1

hit_fraction = hazard_hits / 8
risk_penalty = hit_fraction * 200.0  # Up to 200 points
risk_penalty *= (1.0 - aggression * 0.4)  # Aggressive golfers discount risk
```

### 7. Wind Compensation

```
wind_displacement = WindSystem.get_wind_displacement(direction, distance, club)
wind_adjusted_landing = target + wind_displacement

# Aim into the wind
compensation_factor = 0.2 + accuracy_skill * 0.6     # Pros: ~0.77, Beginners: ~0.32
aim_point = target - wind_displacement * compensation_factor
```

### 8. Approach Shot Club Preference

```
# When multiple clubs can reach the green, prefer the most accurate
if shots_remaining <= 1:
    score += club_accuracy_modifier * 20.0
# This prevents driver selection on short par 3s
```

### 9. Green Center Bias

```
pin_weight = clamp(accuracy_skill * 0.6 + 0.4, 0.5, 0.95)
# Pros: ~0.95 (aim at pin)    Beginners: ~0.58 (aim toward center)

for each "attack" candidate:
    blended_aim = aim_point * pin_weight + green_center * (1.0 - pin_weight)
```

### 10. Personality & Situation Modifiers

```
# Cautious players (aggression < 0.3)
if bunker: score -= 80
if rough/heavy_rough: score -= 30

# Aggressive players (aggression > 0.7)
score += 20  # Discount hazard penalties

# Situation awareness
if score_to_par >= 3 and approaching green:
    score += 15    # Play aggressive to catch up
if score_to_par <= -2:
    score -= 10    # Play safe to protect lead
```

### 11. Recovery Mode (Trouble Lies)

```
allowed_clubs:
    Trees:      [Wedge, Iron]         # No woods through trees
    Rocks:      [Wedge]               # Wedge only
    Bunker:     [Wedge, Iron]         # Sand wedge preferred
    Heavy Rough:[Wedge, Iron]         # Can't get wood through thick stuff

# Scan 360 degrees in 24 directions, 4 distances each
max_distance = club_max * skill_factor * 0.7  # Don't try max distance from trouble

for each direction (24 samples):
    for each distance (4 samples, 30%-100% of max):
        score = terrain_score
        score -= distance_from_ball * 2.0  # Prefer nearby safe targets
        if advancing toward hole: score += advancement * 3.0
        if going backwards: score -= 50
        if landing on fairway: score += 30
        if landing on green: score += 50   # Escaping onto green is ideal
        score -= nearby_hazard_penalty
        score += recovery_skill * 30.0
```

### 12. Tree Collision Detection

```
# Ball flight follows a parabolic arc
# Trees block when ball is in the low portion (first/last 30% of flight)

for each sample along flight path:
    t = sample_position / total_distance
    height_factor = 4.0 * t * (1.0 - t)    # Parabolic arc
    if terrain is TREES and height_factor < 0.3:
        path_blocked = true  # Ball would hit tree canopy
```

### Tuning Levers

| Parameter | Location | Current Value | Effect |
| --- | --- | --- | --- |
| Approach scan angle | `shot_ai.gd:76` | +/-15 degrees | Wider = considers more off-line targets |
| Layup scan angle | `shot_ai.gd:77` | +/-50 degrees | Wider = considers more creative layup routes |
| Ideal approach distance | `shot_ai.gd:341` | 3.5 tiles (~77 yards) | Higher = longer approach preference |
| Terrain scores | `shot_ai.gd:83-98` | See table above | Higher = more attractive landing zone |
| Miss sample count | `shot_ai.gd:80` | 8 | Higher = more accurate risk assessment |
| Risk penalty scale | `shot_ai.gd:675` | 200.0 | Higher = more risk-averse targeting |
| Aggression risk discount | `shot_ai.gd:678` | 0.4 | Higher = aggressive players care less about risk |
| Wind compensation range | `shot_ai.gd:439` | 0.2–0.8 | Range of wind adjustment by skill |
| Pin weight range | `shot_ai.gd:702` | 0.5–0.95 | Lower min = beginners aim more at center |
| Tree height threshold | `shot_ai.gd:786` | 0.3 | Higher = harder to clear trees |
| Recovery max distance | `shot_ai.gd:219` | 0.7x | Lower = shorter recovery shots |
| Recovery scan directions | `shot_ai.gd:222` | 24 | Higher = more escape routes evaluated |
