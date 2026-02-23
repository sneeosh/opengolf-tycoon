# Loyalty & Membership System

## Overview

The Loyalty system tracks golfer visits, satisfaction history, word-of-mouth reputation, and an optional membership program. Happy golfers spread positive word-of-mouth attracting more visitors, while memberships provide steady revenue and increased golfer interest.

## Visit Tracking

Every golfer that finishes a round updates loyalty stats:
- **Happy visit** (mood >= 0.6): +1 loyalty point, word-of-mouth +0.005
- **Unhappy visit** (mood < 0.4): word-of-mouth -0.01 (negative spreads faster)
- Word-of-mouth decays 2% daily toward neutral

## Word-of-Mouth

The word-of-mouth score (-1.0 to 1.0) affects golfer spawn rates:

```
spawn_bonus = word_of_mouth_score * 0.15  # Up to +/- 15%
```

Positive word-of-mouth is earned slowly through happy golfers. Negative word-of-mouth spreads twice as fast (one unhappy golfer does more damage than one happy golfer helps).

## Loyalty Milestones

| Total Visits | Milestone | Reward |
|-------------|-----------|--------|
| 50 | Getting Known | +2 reputation |
| 200 | Local Favorite | +5 reputation |
| 500 | Regional Attraction | +10 reputation |
| 1,000 | Golf Destination | +15 reputation |
| 2,500 | Legendary Course | +25 reputation |

## Membership Tiers

Players can enable membership sales to earn steady annual revenue. Members automatically join/leave based on reputation and satisfaction.

| Tier | Annual Fee | Green Fee Discount | Max Members | Min Reputation |
|------|-----------|-------------------|-------------|---------------|
| Basic | $200 | 15% | 50 | 20 |
| Premium | $500 | 25% | 30 | 45 |
| VIP | $1,200 | 40% | 10 | 70 |

### Membership Growth

Daily growth chance per tier:
```
rep_factor = clamp((reputation - min_reputation) / 30.0, 0.0, 1.0)
growth_chance = rep_factor * satisfaction_ratio * 0.15
```

### Membership Churn

Members leave if satisfaction drops:
```
churn_chance = (1.0 - satisfaction_ratio) * 0.05  # Max 5% daily
```

If reputation drops below 70% of tier minimum, members leave at 1/day.

### Revenue Collection

Membership fees are collected every 28 days (game year boundary). Revenue = fee x member_count per tier.

### Spawn Rate Bonus from Members

Members bring friends — each 10 members adds a spawn bonus:
```
per_tier_bonus = (member_count / 10.0) * tier_spawn_bonus
```
Where tier_spawn_bonus is: Basic 5%, Premium 8%, VIP 12%.

## Integration Points

- **GolferManager.get_spawn_rate_modifier()** — includes loyalty spawn bonus
- **EventBus.golfer_finished_round** — triggers visit tracking
- **EventBus.end_of_day** — triggers membership updates and fee collection
- **SaveManager** — loyalty stats and membership counts persisted
- **Hotkey: K** — open loyalty panel

## Tuning Levers

| Parameter | Location | Effect |
|-----------|----------|--------|
| Membership fees | `MEMBERSHIP_CONFIG` dict | Annual revenue per member |
| Green fee discounts | `MEMBERSHIP_CONFIG` dict | Member discount percentage |
| Max members per tier | `MEMBERSHIP_CONFIG` dict | Membership capacity |
| Min reputation per tier | `MEMBERSHIP_CONFIG` dict | Unlock threshold |
| Word-of-mouth gain/loss | `_on_golfer_finished_round()` | Speed of reputation spread |
| Word-of-mouth decay | `_on_end_of_day()` | How fast WoM returns to neutral |
| Growth/churn chances | `_update_membership_counts()` | Membership turnover rate |
| Loyalty milestones | `_check_loyalty_milestones()` | Visit count thresholds |
