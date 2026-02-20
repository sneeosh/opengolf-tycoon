# Satisfaction & Feedback System

> **Source:** `scripts/autoload/feedback_manager.gd` and `scripts/systems/feedback_triggers.gd`

## Plain English

The feedback system creates the visible "thought bubbles" that golfers show during play and aggregates them into a daily satisfaction metric. Each thought bubble has a **sentiment** (positive, negative, or neutral) and a **trigger type** that describes the event.

### How It Works

When a game event happens (birdie, shank, water hazard, etc.), the system checks if a thought bubble should appear based on a **probability roll**. Common events like bogeys only trigger 50% of the time (to avoid spam), while rare events like hole-in-ones always trigger.

Golfers judge their experience relative to their own skill level — a beginner doesn't feel bad about bogey because they expect to score over par. The "expected over par" calculation means a beginner (skill 0.3) expects to shoot about +2.1 per hole, so they only complain about BOGEY_PLUS when they score 2+ strokes worse than their personal expectation.

### Price Sensitivity

Golfers judge pricing against the course's reputation and hole count. At 50 reputation with 18 holes, $100 is considered "fair." Charging more than 1.5x fair price triggers an "Overpriced!" complaint; charging less than 0.6x triggers a "Great value!" compliment.

### Daily Satisfaction

At the end of each day, the FeedbackManager calculates a satisfaction rating from 0.0 to 1.0 based on the ratio of positive to negative feedback. This feeds into the end-of-day summary and is used by the reputation system (see [reputation.md](reputation.md)) to determine each golfer's reputation impact.

---

## Algorithm

### 1. Feedback Triggers

| Trigger | Sentiment | Probability | When |
| ------- | --------- | ----------- | ---- |
| HOLE_IN_ONE | positive | 100% | Strokes = 1 |
| EAGLE | positive | 90% | Score <= par - 2 |
| BIRDIE | positive | 70% | Score = par - 1 |
| BOGEY_PLUS | negative | 50% | 2+ strokes worse than personal expectation |
| OVERPRICED | negative | 60% | Round cost > 1.5x fair price |
| GOOD_VALUE | positive | 50% | Round cost < 0.6x fair price |
| SLOW_PACE | negative | 70% | Pace-related delays |
| NICE_COURSE | positive | 60% | Final score within 3 strokes of expected total |
| HAZARD_WATER | negative | 80% | Ball lands in water |
| HAZARD_BUNKER | neutral | 60% | Ball lands in bunker |
| GREAT_SHOT | positive | 40% | Particularly good shot |
| BAD_LIE | neutral | 40% | Ball in difficult terrain |
| TOO_FEW_HOLES | negative | 80% | Course has very few holes |
| SHANK | negative | 100% | Catastrophic miss (shanks are rare enough) |

### 2. Score-Based Trigger Logic

```
# Positive triggers are unconditional
if strokes == 1:    return HOLE_IN_ONE
if score <= par-2:  return EAGLE
if score == par-1:  return BIRDIE

# Negative trigger uses personal expectation
expected_over_par = (1.0 - avg_skill) * 3.0

# Examples:
#   Beginner (skill 0.3): expects par + 2.1
#   Casual   (skill 0.6): expects par + 1.2
#   Serious  (skill 0.8): expects par + 0.6
#   Pro      (skill 0.95): expects par + 0.15

expected_strokes = par + expected_over_par

# Only trigger if 2+ strokes WORSE than personal expectation
if strokes >= expected_strokes + 2.0:
    return BOGEY_PLUS
```

### 3. Price Trigger Logic

```
hole_factor = clamp(hole_count / 18.0, 0.15, 1.0)
fair_price  = reputation * 2.0 * hole_factor

if total_round_cost > fair_price * 1.5:
    return OVERPRICED
elif total_round_cost < fair_price * 0.6:
    return GOOD_VALUE
else:
    return no_trigger    # Fair pricing, no comment
```

**Fair price examples:**

| Reputation | Holes | Fair Price | Overpriced Threshold | Good Value Threshold |
| ---------- | ----- | ---------- | -------------------- | -------------------- |
| 30 | 4 | $13.33 | > $20 | < $8 |
| 50 | 9 | $50 | > $75 | < $30 |
| 50 | 18 | $100 | > $150 | < $60 |
| 80 | 18 | $160 | > $240 | < $96 |

### 4. Course Satisfaction Trigger

```
# After finishing a round, evaluate overall satisfaction
expected_total = total_par + hole_count * expected_over_par

if total_strokes <= expected_total + 3.0:
    return NICE_COURSE    # Scored within reasonable range of expectation
else:
    return no_trigger     # Already complained per-hole via BOGEY_PLUS
```

### 5. Probability Gate

```
# Each trigger has a probability — not all events produce visible thoughts
should_show = randf() < trigger_probability

# This prevents feedback spam on common events
# Rare events (hole-in-one, shanks) always show (probability = 1.0)
```

### 6. Daily Satisfaction Rating

```
satisfaction = positive_count / (positive_count + negative_count)

# If no feedback recorded:
satisfaction = 0.5    # Neutral default

# Neutral feedback is tracked but excluded from satisfaction ratio
```

### 7. End-of-Day Summary

```
summary = {
    satisfaction:     0.0 to 1.0,
    positive_count:   count of positive thoughts,
    negative_count:   count of negative thoughts,
    neutral_count:    count of neutral thoughts,
    total_count:      sum of all,
    top_complaint:    most frequent negative trigger message,
    top_compliment:   most frequent positive trigger message,
}
```

### 8. Feedback Signal Flow

```
1. Game event occurs (score recorded, hazard hit, etc.)
2. Golfer calls show_thought(trigger_type)
3. If should_trigger(trigger_type) → probability check passes:
   a. Display thought bubble above golfer
   b. Emit golfer_thought signal (golfer_id, trigger_type, sentiment)
4. FeedbackManager receives signal:
   a. Increment daily_counts[sentiment]
   b. Increment trigger_counts[trigger_type]
5. At end of day:
   a. Calculate satisfaction rating
   b. Populate end-of-day summary
   c. Feed satisfaction into reputation system
```

### Tuning Levers

| Parameter | Location | Current Value | Effect |
| --- | --- | --- | --- |
| Trigger probabilities | `feedback_triggers.gd:27-97` | 0.4–1.0 | Higher = more frequent feedback |
| Expected over par formula | `feedback_triggers.gd:128` | `(1-skill)*3.0` | Higher multiplier = higher personal expectation |
| Bogey trigger threshold | `feedback_triggers.gd:141` | +2 strokes over expected | Lower = more complaints |
| Fair price formula | `feedback_triggers.gd:151` | `rep * 2.0 * hole_factor` | Higher = more pricing room |
| Overpriced threshold | `feedback_triggers.gd:152` | 1.5x fair | Lower = more price complaints |
| Good value threshold | `feedback_triggers.gd:154` | 0.6x fair | Higher = easier to earn value praise |
| Course satisfaction range | `feedback_triggers.gd:163` | +3 strokes | Higher = easier to trigger NICE_COURSE |
| Neutral default | `feedback_manager.gd:48` | 0.5 | Starting assumption when no data |
