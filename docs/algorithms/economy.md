# Economy & Financial System

> **Source:** `scripts/autoload/game_manager.gd` (lines 1–700)

## Plain English

The economy system governs how money flows in and out of the golf course business. Players start with $50,000 (adjustable by difficulty preset) and must balance revenue against operating costs. If money drops below the bankruptcy threshold (-$1,000 by default), the player goes bankrupt.

### Revenue Sources

1. **Green fees** — The primary income. Each golfer pays a per-hole fee multiplied by the number of open holes. The fee is player-configurable ($10–$200), but the maximum allowed fee scales with hole count ($15 per hole cap) to prevent 1-hole courses from charging $200.

2. **Pro shop bonus** — If a pro shop staff member is hired, each golfer generates a small bonus on top of their green fee.

3. **Building revenue** — Amenity buildings (restaurants, pro shops, snack bars) generate daily revenue based on golfer foot traffic.

4. **Tournament revenue** — Hosting tournaments generates spectator gate revenue and sponsorship deals (see [tournament-system.md](tournament-system.md)).

### Expenses

1. **Terrain maintenance** — Based on the actual tiles on the course, scaled by seasonal modifier (higher in summer when grass grows faster).

2. **Base operating cost** — A fixed daily cost: $50 + $25 per hole.

3. **Staff wages** — Per-hole cost based on staff tier: Part-Time $5, Full-Time $10, Premium $20 per hole.

4. **Building upkeep** — Each building has a daily operating cost.

### Loans

Players can take loans up to $50,000 total. Interest compounds at 5% every 7 days. This provides an emergency lifeline but creates a debt spiral if not repaid.

### Green Fee Dynamics

The green fee creates a tension between revenue and golfer attraction. Higher fees generate more per golfer but reduce the value rating (see [course-rating.md](course-rating.md)), which reduces golfer spawn rates. The optimal fee depends on reputation, hole count, and the player's goals.

---

## Algorithm

### 1. Starting Money & Bankruptcy

```
starting_money       = 50000    # Modified by difficulty preset
bankruptcy_threshold = -1000    # Modified by difficulty preset

# Can afford check (blocks spending at threshold, not at $0)
can_afford(cost) = (money - cost) >= bankruptcy_threshold
is_bankrupt()    = money < bankruptcy_threshold
```

### 2. Green Fee Revenue (Per Golfer)

```
MIN_GREEN_FEE = 10
MAX_GREEN_FEE = 200

# Maximum fee scales with hole count
effective_max = max(MIN_GREEN_FEE, min(holes * 15, MAX_GREEN_FEE))

# Revenue per golfer
holes = open_hole_count
total_per_golfer = green_fee * max(holes, 1) + pro_shop_bonus
```

**Effective max fee examples:**

| Holes | Max Fee |
| ----- | ------- |
| 1 | $15 |
| 3 | $45 |
| 6 | $90 |
| 9 | $135 |
| 14+ | $200 |

### 3. Daily Operating Costs

```
# Terrain maintenance (seasonal)
season_mod = SeasonSystem.get_maintenance_modifier(season)
terrain_maintenance = terrain_tile_cost * season_mod

# Base cost (fixed + per-hole)
base_operating_cost = 50 + (hole_count * 25)

# Staff wages (per-hole, by tier)
staff_wages = hole_count * cost_per_hole
    Part-Time:  $5  per hole
    Full-Time:  $10 per hole
    Premium:    $20 per hole

# Building upkeep
building_operating_costs = sum of all building daily costs

# Total
operating_costs = terrain_maintenance + base_operating_cost + staff_wages + building_operating_costs
```

### 4. Daily Profit

```
total_revenue = green_fee_revenue + building_revenue
daily_profit  = total_revenue - operating_costs
```

### 5. Loan System

```
MAX_LOAN = 50000
LOAN_INTEREST_RATE = 0.05   # 5% per 7-day period

# Taking a loan
amount = clamp(amount, 10000, MAX_LOAN)
if loan_balance + amount > MAX_LOAN: reject
loan_balance += amount
money += amount

# Interest (compounds every 7 days)
if current_day % 7 == 0:
    interest = max(int(loan_balance * 0.05), 1)
    loan_balance += interest

# Repayment
amount = min(requested_amount, loan_balance)
if can_afford(amount):
    loan_balance -= amount
    money -= amount
```

### 6. Staff Tier System

| Tier | Cost/Hole | Condition Modifier | Satisfaction Modifier |
| ---- | --------- | ------------------ | --------------------- |
| Part-Time | $5 | 0.85 | 0.90 |
| Full-Time | $10 | 1.00 | 1.00 |
| Premium | $20 | 1.15 | 1.10 |

### 7. Maintenance Multiplier

```
# Theme and difficulty both scale maintenance costs
multiplier = theme_maintenance_multiplier * difficulty_maintenance_multiplier
```

### Tuning Levers

| Parameter | Location | Current Value | Effect |
| --- | --- | --- | --- |
| Starting money | `game_manager.gd:18` | $50,000 | Higher = easier start |
| Bankruptcy threshold | `game_manager.gd:39` | -$1,000 | Lower = more debt allowed |
| Min green fee | `game_manager.gd:35` | $10 | Floor for pricing |
| Max green fee | `game_manager.gd:36` | $200 | Ceiling for pricing |
| Fee per hole cap | `game_manager.gd:318` | $15/hole | Higher = more pricing freedom |
| Base operating cost | `game_manager.gd:683` | $50 + $25/hole | Higher = more expensive to run |
| Max loan | `game_manager.gd:27` | $50,000 | Higher = more emergency funding |
| Loan interest rate | `game_manager.gd:28` | 5% per 7 days | Higher = faster debt spiral |
| Staff costs | `game_manager.gd:44-66` | $5/$10/$20 per hole | Higher = more expensive staff |
