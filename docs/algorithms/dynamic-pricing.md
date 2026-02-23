# Dynamic Pricing System

## Overview

The Dynamic Pricing system analyzes course demand, reputation, rating, and historical performance to suggest optimal green fees. It can optionally auto-adjust fees daily using one of three strategies: maximize revenue, maximize golfers, or balanced.

## Fair Price Formula

The base "fair price" uses the same formula as FeedbackTriggers (golfer price sensitivity):

```
hole_factor = clamp(hole_count / 18.0, 0.15, 1.0)
fair_price_total = reputation * 2.0 * hole_factor
fair_per_hole = fair_price_total / hole_count
```

At 50 reputation with 18 holes: fair total = $100, fair per hole = ~$5.5
At 80 reputation with 18 holes: fair total = $160, fair per hole = ~$8.9

## Pricing Strategies

### Maximize Revenue
Pushes price to 130% of fair value. Higher revenue per golfer but fewer visitors.
```
suggested = fair_per_hole * 1.3
```

### Maximize Golfers
Sets price to 70% of fair value. More visitors but lower revenue per visit.
```
suggested = fair_per_hole * 0.7
```

### Balanced (Default)
Adjusts around fair price based on demand signals:
```
suggested = fair_per_hole * (1.0 + demand_adjustment * 0.15)
```

## Demand Analysis

Demand is measured from recent golfer counts relative to course capacity:

```
capacity_ratio = recent_7day_avg / (max_concurrent * 0.6)
```

| Capacity Ratio | Demand Signal | Adjustment |
|---------------|---------------|------------|
| > 1.2 | Very high | +0.5 |
| 0.8 - 1.2 | Good | +0.2 |
| 0.5 - 0.8 | Normal | 0.0 |
| 0.3 - 0.5 | Low | -0.2 |
| < 0.3 | Very low | -0.5 |

## Rating Bonus

Course rating modifies the suggested price:
- 4.0+ stars: +15%
- 3.0+ stars: +5%
- Below 2.0: -15%

## Revenue & Golfer Estimates

The system estimates outcomes at the suggested price:

```
price_ratio = suggested_total / fair_total
demand_factor = clamp(1.5 - price_ratio * 0.8, 0.2, 1.2)
est_golfers = max_concurrent * demand_factor * 0.5
est_revenue = est_golfers * suggested_total
```

## Auto-Pricing

When enabled, the system applies the suggested fee automatically at end-of-day. Changes of $5 or more trigger a notification. The player can disable auto-pricing at any time.

## Historical Tracking

The system tracks 28 days of history:
- Daily revenue
- Daily golfer counts
- Daily green fee levels

This data drives the demand analysis and trend detection.

## Integration Points

- **GameManager.set_green_fee()** — applies fee changes
- **EventBus.end_of_day** — triggers daily analysis and auto-pricing
- **SaveManager** — pricing history and settings persisted
- **Hotkey: I** — open pricing panel

## Tuning Levers

| Parameter | Location | Effect |
|-----------|----------|--------|
| Strategy multipliers | `_calculate_suggested_fee()` | Revenue vs. golfer balance |
| Rating bonuses | `_calculate_suggested_fee()` | Price boost for high-rated courses |
| Demand thresholds | `_analyze_demand()` | Sensitivity to demand changes |
| History window | `HISTORY_WINDOW` constant | Days of data for analysis |
| Demand elasticity | `_estimate_outcomes()` | Price sensitivity curve |
