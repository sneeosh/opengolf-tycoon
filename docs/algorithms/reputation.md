# Reputation System

> **Source:** `scripts/autoload/game_manager.gd` (lines 279–478) and `scripts/managers/golfer_manager.gd` (lines 753–803)

## Plain English

Reputation is a 0–100 score that represents how well-known and respected the golf course is. It starts at 50 and is the primary driver of golfer attraction — higher reputation brings more golfers and higher-tier golfers (serious players, pros).

Reputation changes through two mechanisms:

### Daily Decay (Automatic)

Every night, reputation decays slightly. The rate depends on the course's star rating — poorly-rated courses decay faster, excellent courses decay very slowly. This creates constant pressure to maintain quality and ensures that a course can't coast on past success forever.

### Golfer Mood (Per Golfer)

When a golfer finishes their round, they contribute positive or negative reputation based on their mood (satisfaction level 0.0–1.0). Happy golfers (mood > 0.6) spread the word and increase reputation. Unhappy golfers (mood < 0.4) hurt reputation. Neutral golfers (0.4–0.6) provide a small positive contribution.

The reputation gain is scaled by:
- **Golfer tier** — Pro golfers have 10x the reputation impact of beginners
- **Prestige multiplier** — Harder courses with good ratings earn bonus reputation
- **Pro performance bonus** — A pro who scores under par gives double reputation

This means the optimal strategy is building a challenging, well-rated course that attracts and satisfies pro golfers — each happy pro is worth 10 beginners.

---

## Algorithm

### 1. Reputation Range

```
reputation: float = 50.0    # Starting value
range: [0.0, 100.0]         # Clamped on every modification
```

### 2. Daily Decay

Called during `advance_to_next_day()`:

```
if reputation > 0:
    stars = course_rating.stars    # Integer 1-5

    if stars < 3:    decay = 1.0     # Poor course: fast decay
    elif stars == 3: decay = 0.5     # Average: moderate decay
    elif stars == 4: decay = 0.25    # Good: slow decay
    else:            decay = 0.1     # Excellent: minimal decay

    # Difficulty preset can scale decay
    decay *= difficulty_preset.reputation_decay_multiplier

    reputation -= decay
```

**Daily decay examples:**

| Stars | Base Decay | After 30 days |
| ----- | ---------- | ------------- |
| 1-2 | -1.0/day | -30 points |
| 3 | -0.5/day | -15 points |
| 4 | -0.25/day | -7.5 points |
| 5 | -0.1/day | -3 points |

### 3. Per-Golfer Reputation Gain

Called when a golfer finishes their round:

```
# Step 1: Base reputation from tier
base_rep = GolferTier.get_reputation_gain(tier)
    BEGINNER:  1
    CASUAL:    2
    SERIOUS:   4
    PRO:       10

# Step 2: Pro performance bonus
if tier == PRO and total_strokes <= total_par:
    base_rep *= 2    # Double reputation for pro under par

# Step 3: Prestige multiplier (see course-rating.md)
prestige = CourseRatingSystem.get_prestige_multiplier(course_rating)
base_rep = int(base_rep * prestige)

# Step 4: Scale by golfer mood
mood = golfer.current_mood    # 0.0 to 1.0

if mood >= 0.6:
    # Happy golfer: positive reputation (scales 0.5x to 1.0x of base)
    reputation_gain = base_rep * lerp(0.5, 1.0, (mood - 0.6) / 0.4)

elif mood >= 0.4:
    # Neutral golfer: small positive gain
    reputation_gain = base_rep * 0.25

else:
    # Unhappy golfer: negative reputation (scales 0x to -1.0x of base)
    reputation_gain = -base_rep * lerp(0.0, 1.0, (0.4 - mood) / 0.4)

reputation += reputation_gain
```

### 4. Reputation Impact Examples

| Golfer | Mood | Base | Prestige | Final Gain |
| ------ | ---- | ---- | -------- | ---------- |
| Happy Beginner (0.8) | 0.8 | 1 | 1.0x | +0.75 |
| Happy Casual (0.7) | 0.7 | 2 | 1.0x | +1.25 |
| Happy Pro (0.9) | 0.9 | 10 | 1.5x | +11.25 |
| Neutral Casual (0.5) | 0.5 | 2 | 1.0x | +0.5 |
| Unhappy Pro (0.2) | 0.2 | 10 | 1.0x | -5.0 |
| Pro under par (0.8) | 0.8 | 20 | 1.5x | +22.5 |

### 5. Tournament Reputation

Tournaments award a flat reputation bonus on completion (bypasses the mood system):

```
LOCAL:        +15 reputation
REGIONAL:     +40 reputation
NATIONAL:     +100 reputation
CHAMPIONSHIP: +300 reputation
```

### 6. Reputation Effects on Gameplay

Reputation influences several systems:

- **Golfer spawn rate**: Higher reputation = more golfers visit (see [golfer-spawning.md](golfer-spawning.md))
- **Tier attraction**: Pro golfers require 70+ reputation, serious golfers are filtered below 50 (see [golfer-spawning.md](golfer-spawning.md))
- **Value rating**: Fair pricing is based on reputation (see [course-rating.md](course-rating.md))
- **Tournament qualification**: Indirectly, through course rating which depends on value rating

### Tuning Levers

| Parameter | Location | Current Value | Effect |
| --- | --- | --- | --- |
| Starting reputation | `game_manager.gd:18` | 50.0 | Higher = earlier access to better golfers |
| Decay by star level | `game_manager.gd:467-475` | 1.0/0.5/0.25/0.1 | Higher = faster reputation loss |
| Tier reputation gains | `golfer_tier.gd:24-58` | 1/2/4/10 | Higher = faster reputation growth |
| Pro under-par bonus | `golfer_manager.gd:787` | 2x | Higher = more reward for satisfying pros |
| Happy mood threshold | `golfer_manager.gd:796` | 0.6 | Lower = easier to get positive rep |
| Unhappy mood threshold | `golfer_manager.gd:800` | 0.4 | Higher = more golfers hurt reputation |
| Neutral gain multiplier | `golfer_manager.gd:799` | 0.25 | Higher = more rep from neutral golfers |
| Tournament rep rewards | `tournament_system.gd:35-77` | 15/40/100/300 | Higher = more tournament incentive |
