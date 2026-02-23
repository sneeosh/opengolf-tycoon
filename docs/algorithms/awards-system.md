# Awards System

## Overview

The Awards system tracks yearly performance metrics and generates awards at the end of each game year (every 28 days). Awards come in Bronze, Silver, and Gold tiers with increasing reputation bonuses. All awards are stored permanently in a Hall of Fame for cross-year tracking.

## Timing

- Game year = 28 days (4 seasons x 7 days)
- Awards ceremony triggers when `day_changed` crosses a year boundary
- Year number: `((day - 1) / 28) + 1`

## Award Categories

### Top Revenue
| Tier | Threshold | Rep Bonus |
|------|----------|-----------|
| Bronze | $20,000+ annual revenue | +1.0 |
| Silver | $50,000+ annual revenue | +2.0 |
| Gold | $100,000+ annual revenue | +4.0 |

### Popular Destination
| Tier | Threshold | Rep Bonus |
|------|----------|-----------|
| Bronze | 50+ golfers served | +0.5 |
| Silver | 100+ golfers served | +1.5 |
| Gold | 200+ golfers served | +3.0 |

### Fiscal Responsibility
| Tier | Threshold | Rep Bonus |
|------|----------|-----------|
| Bronze | 50%+ profitable days | +0.5 |
| Silver | 70%+ profitable days | +1.5 |
| Gold | 90%+ profitable days | +3.0 |

### Tournament Host
| Tier | Threshold | Rep Bonus |
|------|----------|-----------|
| Bronze | Regional tournament hosted | +1.0 |
| Silver | National tournament hosted | +2.5 |
| Gold | Championship tournament hosted | +5.0 |

### Course Prestige (Reputation)
| Tier | Threshold | Rep Bonus |
|------|----------|-----------|
| Bronze | Peak reputation 50+ | +0.5 |
| Silver | Peak reputation 70+ | +1.5 |
| Gold | Peak reputation 90+ | +3.0 |

### Course Excellence (Rating)
| Tier | Threshold | Rep Bonus |
|------|----------|-----------|
| Bronze | Peak 2.5+ star rating | +0.5 |
| Silver | Peak 3.5+ star rating | +1.5 |
| Gold | Peak 4.5+ star rating | +3.0 |

### Course Developer (Growth)
| Tier | Threshold | Rep Bonus |
|------|----------|-----------|
| Bronze | 3+ holes/buildings added | +0.5 |
| Silver | 8+ holes/buildings added | +1.0 |
| Gold | 15+ holes/buildings added | +2.0 |

### Scoring Awards
| Award | Condition | Rep Bonus |
|-------|----------|-----------|
| Eagle's Nest (Bronze) | 5+ eagles in a year | +0.5 |
| Hole-in-One Club (Silver) | 1+ aces in a year | +1.5 |
| Ace Factory (Gold) | 3+ aces in a year | +3.0 |

## Yearly Stats Tracked

- Total revenue, total golfers served
- Best/worst daily revenue and profit (with day numbers)
- Tournaments hosted and highest tier achieved
- Peak reputation and peak course rating
- Holes-in-one and eagles
- Holes built and buildings placed
- Profitable days count

## Integration

- **EventBus signals**: Listens to `end_of_day`, `day_changed`, `tournament_completed`, `hole_created`, `building_placed`
- **Reputation**: Awards grant cumulative reputation bonuses
- **Save/Load**: Hall of fame and yearly stats persisted
- **UI**: Awards panel (N hotkey) with ceremony view and hall of fame view

## Tuning Levers

| Parameter | Location | Effect |
|-----------|----------|--------|
| Revenue thresholds | `_evaluate_revenue_award()` | $20k/50k/100k tiers |
| Golfer count thresholds | `_evaluate_golfer_award()` | 50/100/200 tiers |
| Profitability thresholds | `_evaluate_profitability_award()` | 50%/70%/90% tiers |
| Reputation bonus per tier | Each `_evaluate_*` function | Rep reward for awards |
