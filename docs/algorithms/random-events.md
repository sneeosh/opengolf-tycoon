# Random Events System

## Overview

The Random Events system generates narrative variety by triggering random events at the start of each new day. Events range from weather disasters and equipment breakdowns to VIP visits and sponsorship offers. Each event has prerequisites, immediate/ongoing effects, and a duration.

## Event Generation

Each morning, the system rolls to decide if an event occurs:

```
effective_chance = BASE_EVENT_CHANCE + (days_without_event * 0.08)
effective_chance = min(effective_chance, 0.80)
```

- **Base chance**: 35% per day
- **Pity timer**: +8% per consecutive day without an event (caps at 80%)
- **Max active events**: 3 simultaneous (prevents overwhelming the player)

## Event Selection

From the pool of ~18 event definitions, the system filters to eligible events:

1. **Not recently occurred** — last 10 event IDs tracked to prevent repeats
2. **No duplicate category** — only one event per category (Weather, Equipment, VIP, PR, Economic, Sponsorship, Wildlife) at a time
3. **Minimum day** — each event has a `min_day` threshold (early game is protected)
4. **Rating gates** — some events require minimum/maximum course rating
5. **Hole count gates** — corporate outings need 9+ holes
6. **Weather prerequisites** — lightning only during rain, drought only during sunny+summer
7. **Season prerequisites** — drought restricted to summer
8. **Building prerequisites** — cart breakdown requires a cart shed

Eligible events are selected via **weighted random**, where each definition has a `weight` (0.3 to 1.0).

## Event Categories

| Category | Examples | Typical Effects |
|----------|----------|----------------|
| Weather Disaster | Lightning strike, flooding, drought | Money loss, condition penalty, spawn reduction |
| Equipment Breakdown | Cart breakdown, irrigation failure, range nets | Money loss, condition penalty |
| VIP Visit | Celebrity golfer, corporate outing | Money gain, pro spawn boost, reputation boost |
| PR Review | Magazine review (good/bad), viral social media | Spawn modifier, reputation change |
| Economic | Local recession, golf boom, supply cost spike | Spawn modifier, maintenance multiplier |
| Sponsorship | Hole sponsorship, tournament sponsor | Money gain, reputation boost |
| Wildlife | Geese invasion, mole damage | Satisfaction penalty, condition penalty |

## Effect Types

| Effect Key | Applied By | Description |
|-----------|-----------|-------------|
| `money` | Immediate | One-time money change (positive or negative) |
| `reputation_bonus` | Immediate + daily for multi-day | Reputation increase |
| `reputation_penalty` | Immediate + daily for multi-day | Reputation decrease |
| `spawn_modifier` | Queried by GolferManager | Multiplier on golfer spawn rate |
| `pro_spawn_boost` | Queried by GolferManager | Multiplier for pro-tier spawns |
| `maintenance_multiplier` | Queried by GameManager | Multiplier on maintenance costs |
| `condition_penalty` | Queried by CourseRatingSystem | Reduces course condition rating |
| `satisfaction_penalty` | Queried by systems | Reduces golfer satisfaction |
| `beginner_bias` | Queried by tier selection | Shifts tier distribution toward beginners |

## Duration

Events last 1-7 days depending on type:
- Instant events (sponsorships, VIP visits): 1 day
- Short disruptions (lightning, cart breakdown): 1-2 days
- Extended effects (flooding, economic shifts): 2-7 days

Multi-day reputation effects are divided across the duration to avoid front-loading.

## Integration Points

- **GolferManager.get_spawn_rate_modifier()** — multiplied by event spawn modifier
- **GameManager.get_maintenance_multiplier()** — multiplied by event maintenance modifier
- **CourseRatingSystem._calculate_condition_rating()** — reduced by event condition penalty
- **SaveManager** — events serialized/deserialized with save data

## Tuning Levers

| Parameter | Default | Effect |
|-----------|---------|--------|
| `BASE_EVENT_CHANCE` | 0.35 | Base daily probability of any event |
| `MAX_ACTIVE_EVENTS` | 3 | Maximum simultaneous active events |
| `MAX_RECENT_HISTORY` | 10 | How many recent event IDs to track (prevents repeats) |
| Pity timer increment | 0.08 | Chance increase per day without event |
| Pity timer cap | 0.80 | Maximum event chance after long drought |
| Per-event `weight` | 0.3-1.0 | Relative selection probability |
| Per-event `min_day` | 3-21 | Earliest day the event can occur |
