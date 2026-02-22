# Golfer Needs System

> **Source:** `scripts/systems/golfer_needs.gd`, integrated via `scripts/entities/golfer.gd`

## Plain English

The golfer needs system tracks four explicit needs for each golfer during their round: **energy**, **comfort**, **hunger**, and **pace satisfaction**. Each need starts at 1.0 (fully satisfied) and decays as the golfer plays holes and waits for their turn.

### How It Works

Needs decay naturally as golfers play:
- **Energy** drops after each hole (walking the course is tiring)
- **Comfort** drops after each hole (need for restroom facilities)
- **Hunger** drops after each hole (the slowest decay)
- **Pace** drops when golfers are idle waiting for their turn, modified by their patience trait

When a need drops below the **low threshold** (0.30), the golfer may show a thought bubble complaint (e.g., "Getting tired...", "Need a restroom!"). When a need drops below the **critical threshold** (0.15), the golfer takes a direct mood penalty each hole.

### Buildings Satisfy Needs

Buildings placed on the course restore specific needs when a golfer walks within range:
- **Bench**: Restores energy (+0.20)
- **Restroom**: Restores comfort (+0.35)
- **Snack Bar**: Restores hunger (+0.30)
- **Restaurant**: Restores hunger (+0.50)
- **Clubhouse**: Small boost to all needs (+0.15 each) at end of round

This creates a strategic incentive: players must place amenity buildings along the course to keep golfers happy during long rounds.

### Tier Differences

Higher-tier golfers are more demanding — their needs decay faster:
- Beginners: 0.8x decay rate (resilient)
- Casual: 1.0x (baseline)
- Serious: 1.1x (slightly demanding)
- Pro: 1.3x (very demanding)

### Patience and Pace

The golfer's patience trait (set by tier) directly affects how fast pace satisfaction drops during waits. Impatient golfers (pros, patience ~0.3) lose pace satisfaction 2.5x faster than patient golfers (beginners/retirees, patience ~0.9).

---

## Algorithm

### 1. Need Decay Per Hole

```
tier_modifier = { BEGINNER: 0.8, CASUAL: 1.0, SERIOUS: 1.1, PRO: 1.3 }

on_hole_completed():
    energy  -= 0.08 * tier_modifier    # Low after ~12 holes (beginner) or ~9 holes (pro)
    comfort -= 0.06 * tier_modifier    # Low after ~16 holes (beginner) or ~12 holes (pro)
    hunger  -= 0.05 * tier_modifier    # Low after ~20 holes (beginner) or ~15 holes (pro)
```

### 2. Pace Decay (Waiting)

```
on_waiting(wait_seconds):
    patience_modifier = 1.0 + (1.0 - patience) * 1.5
    # Patient (0.9):   modifier = 1.15
    # Impatient (0.3):  modifier = 2.05

    pace -= wait_seconds * 0.02 * patience_modifier
```

Pace is checked in 5-second chunks during the golfer's `_process()` loop to avoid per-frame overhead.

### 3. Building Interaction Chance

When a golfer walks within a building's `effect_radius`, they don't automatically stop — they roll against an **interaction chance** based on how much they need that building. This prevents revenue spam from placing many buildings and makes need levels matter for building placement strategy.

```
relevant_need = need mapped to building type (bench→energy, restroom→comfort, etc.)

if relevant_need < 0.30:  interaction_chance = 1.00   # Desperate — always stop
elif relevant_need < 0.70: interaction_chance = 0.50   # Could use it — coin flip
else:                      interaction_chance = 0.20   # Doing fine — usually walk past

# Buildings with no need mapping (pro_shop): flat 0.30 base chance
```

Golfers do NOT pathfind to buildings — they only interact when they happen to walk within proximity range. The interaction check is one-time-per-round per building (tracked via `_visited_buildings`).

### 4. Building Need Restoration

| Building | Need | Restore Amount | Mood Boost |
| --- | --- | --- | --- |
| Bench | Energy | +0.20 | +0.02 |
| Restroom | Comfort | +0.35 | +0.05 |
| Snack Bar | Hunger | +0.30 | +0.03 |
| Restaurant | Hunger | +0.50 | +0.05 |
| Clubhouse | All | +0.15 each | +0.03 |

Restoration only happens when the golfer decides to interact (passes the chance roll above). Clubhouse interaction happens at end of round and is always guaranteed.

### 4. Feedback Triggers

| Need | Trigger Type | Threshold | Probability | Messages |
| --- | --- | --- | --- | --- |
| Energy < 0.30 | TIRED | LOW_NEED_THRESHOLD | 70% | "Getting tired...", "Need a break", etc. |
| Comfort < 0.30 | NEEDS_RESTROOM | LOW_NEED_THRESHOLD | 70% | "Need a restroom!", "Where's the restroom?", etc. |
| Hunger < 0.30 | HUNGRY | LOW_NEED_THRESHOLD | 60% | "Getting hungry...", "Need a snack", etc. |
| Pace < 0.30 | SLOW_PACE | LOW_NEED_THRESHOLD | 70% | "Slow play...", "C'mon!", etc. |

Each trigger fires at most once per round per golfer (tracked by `_triggered_low_*` flags).

### 5. Mood Penalties (Critical Needs)

```
get_mood_penalty():
    penalty = 0.0
    if energy  < 0.15: penalty -= 0.05
    if comfort < 0.15: penalty -= 0.05
    if hunger  < 0.15: penalty -= 0.03
    if pace    < 0.15: penalty -= 0.08    # Pace frustration is strongest
    return penalty

# Applied once per hole in finish_hole()
```

### 6. Overall Satisfaction

```
overall = energy * 0.30 + comfort * 0.20 + hunger * 0.20 + pace * 0.30
```

### 7. Signal Flow

```
1. Golfer plays hole → needs.on_hole_completed() → decay energy/comfort/hunger
2. Golfer waits (IDLE) → needs.on_waiting() → decay pace
3. Golfer walks near building → needs.get_interaction_chance() → random roll → apply_building_effect() if passed
4. Need drops below 0.30 → needs.check_need_triggers() → show_thought() → EventBus.golfer_thought
5. Need drops below 0.15 → needs.get_mood_penalty() → _adjust_mood() → EventBus.golfer_mood_changed
6. FeedbackManager receives golfer_thought → tracks needs_complaints for daily summary
```

### Tuning Levers

| Parameter | Location | Current Value | Effect |
| --- | --- | --- | --- |
| ENERGY_DECAY_PER_HOLE | `golfer_needs.gd:34` | 0.08 | Higher = golfers tire faster |
| COMFORT_DECAY_PER_HOLE | `golfer_needs.gd:35` | 0.06 | Higher = more restroom demand |
| HUNGER_DECAY_PER_HOLE | `golfer_needs.gd:36` | 0.05 | Higher = more food demand |
| PACE_DECAY_PER_WAIT_SECOND | `golfer_needs.gd:39` | 0.02 | Higher = more pace complaints |
| LOW_NEED_THRESHOLD | `golfer_needs.gd:28` | 0.30 | Higher = complaints start sooner |
| CRITICAL_NEED_THRESHOLD | `golfer_needs.gd:29` | 0.15 | Higher = mood penalties start sooner |
| BENCH_ENERGY_RESTORE | `golfer_needs.gd:42` | 0.20 | Higher = benches more effective |
| RESTROOM_COMFORT_RESTORE | `golfer_needs.gd:43` | 0.35 | Higher = restrooms more effective |
| SNACK_BAR_HUNGER_RESTORE | `golfer_needs.gd:44` | 0.30 | Higher = snack bars more effective |
| RESTAURANT_HUNGER_RESTORE | `golfer_needs.gd:45` | 0.50 | Higher = restaurants more effective |
| CLUBHOUSE_ALL_RESTORE | `golfer_needs.gd:46` | 0.15 | Higher = clubhouse more effective |
| INTERACT_CHANCE_HIGH_NEED | `golfer_needs.gd` | 0.20 | Chance of stopping when need > 0.7. Lower = buildings less useful when golfer is satisfied |
| INTERACT_CHANCE_MID_NEED | `golfer_needs.gd` | 0.50 | Chance of stopping when need is 0.3–0.7 |
| INTERACT_CHANCE_LOW_NEED | `golfer_needs.gd` | 1.00 | Chance of stopping when need < 0.3 (guaranteed) |
| INTERACT_CHANCE_BASE | `golfer_needs.gd` | 0.30 | Fallback chance for buildings with no need mapping (pro_shop) |
| Tier decay modifiers | `golfer_needs.gd:_get_tier_decay_modifier()` | 0.8–1.3 | Higher = tier is more demanding |
| Overall satisfaction weights | `golfer_needs.gd:get_overall_satisfaction()` | E:0.30 C:0.20 H:0.20 P:0.30 | Adjust relative importance of each need |
