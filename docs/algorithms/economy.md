# Economy & Financial System

> **Source:** `scripts/autoload/game_manager.gd`, `scripts/managers/staff_manager.gd`, `scripts/systems/difficulty_presets.gd`

## Plain English

The economy system governs how money flows in and out of the golf course business. Players start with $25,000 on Normal difficulty (adjustable by difficulty preset) and must balance revenue against operating costs. If money drops below the bankruptcy threshold (-$1,000 by default), the player goes bankrupt.

### Revenue Sources

1. **Green fees** — The primary income. Each golfer pays a per-hole fee multiplied by the number of open holes. The fee is player-configurable ($10–$200), but the maximum allowed fee scales with hole count ($10 per hole cap) to prevent small courses from charging excessive fees.

2. **Pro shop bonus** — If a pro shop staff member is hired, each golfer generates $5 bonus on top of their green fee.

3. **Building revenue** — Amenity buildings (restaurants, pro shops, snack bars) generate revenue per golfer within their effect radius. Revenue depends on golfer proximity and interaction chance (need-based probability).

4. **Tournament revenue** — Hosting tournaments generates spectator gate revenue and sponsorship deals (see [tournament-system.md](tournament-system.md)). Tournaments are primarily reputation machines, not profit generators — most tiers break even or lose money.

### Expenses

1. **Terrain maintenance** — Based on placed tiles, sqrt-scaled, modified by season × theme × difficulty.

2. **Base operating cost** — A fixed daily cost: $100 + $50 per hole.

3. **Staff salaries** — Individual staff members have fixed daily salaries: Groundskeeper $80, Pro Shop $60, Marshal $50, Cart Operator $40.

4. **Building upkeep** — Each building has a daily operating cost (Clubhouse $100, Restaurant $60, Pro Shop $40, Snack Bar $15, Cart Shed $25, Driving Range $30, Restroom $10, Bench $0).

### Loans

Players can take loans up to $50,000 total. Interest compounds at 5% every 7 days. This provides an emergency lifeline but creates a debt spiral if not repaid.

### Green Fee Dynamics

The green fee creates a tension between revenue and golfer attraction. Higher fees generate more per golfer but reduce the value rating (see [course-rating.md](course-rating.md)), which reduces golfer spawn rates. Seasonal fee tolerance (see [seasonal-calendar.md](seasonal-calendar.md)) adjusts what golfers consider "fair" — peak-season golfers accept higher fees, off-season golfers expect discounts.

---

## Algorithm

### 1. Starting Money & Bankruptcy

```
starting_money       = 25000    # Modified by difficulty preset (Easy: 40K, Hard: 15K)
bankruptcy_threshold = -1000    # Modified by difficulty preset

# Can afford check (blocks spending at threshold, not at $0)
can_afford(cost) = (money - cost) >= bankruptcy_threshold
is_bankrupt()    = money < bankruptcy_threshold
```

### 2. Green Fee Revenue (Per Golfer)

```
MIN_GREEN_FEE = 10
MAX_GREEN_FEE = 200

# Maximum fee scales with hole count ($10/hole cap)
effective_max = max(MIN_GREEN_FEE, min(holes * 10, MAX_GREEN_FEE))

# Revenue per golfer
holes = open_hole_count
total_per_golfer = green_fee * max(holes, 1) + pro_shop_bonus
```

**Effective max fee examples:**

| Holes | Max Fee |
| ----- | ------- |
| 1 | $10 |
| 3 | $30 |
| 6 | $60 |
| 9 | $90 |
| 20+ | $200 |

### 3. Daily Operating Costs

```
# Terrain maintenance (seasonal, theme-aware, sqrt-scaled)
raw_tile_cost = sum of per-tile maintenance costs for player-placed tiles
scaled_tile_cost = sqrt(raw_tile_cost) * 20    # sub-linear scaling
season_mod = SeasonSystem.get_blended_maintenance_modifier(day, theme)
terrain_maintenance = scaled_tile_cost * season_mod * difficulty_modifier

# Base cost (fixed + per-hole)
base_operating_cost = 100 + (hole_count * 50)

# Staff salaries (individual per staff member)
staff_salaries = sum of daily salary for each hired staff member
    Groundskeeper: $80/day
    Pro Shop:      $60/day
    Marshal:       $50/day
    Cart Operator: $40/day

# Building upkeep
building_operating_costs = sum of all building daily costs

# Total
operating_costs = terrain_maintenance + base_operating_cost + staff_salaries + building_operating_costs
```

### 4. Daily Profit

```
total_revenue = green_fee_revenue + building_revenue + tournament_revenue
daily_profit  = total_revenue - operating_costs - tournament_entry_fee
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

### 6. Staff System

Two separate staff systems exist:

**GameManager staff tier** (legacy, used for wage calculation in operating costs):

| Tier | Cost/Hole/Day | Condition Modifier | Satisfaction Modifier |
| ---- | ------------- | ------------------ | --------------------- |
| Part-Time | $5 | 0.85 | 0.90 |
| Full-Time | $10 | 1.00 | 1.00 |
| Premium | $20 | 1.15 | 1.10 |

**StaffManager individual staff** (functional staff with specific roles):

| Type | Salary/Day | Effect |
| ---- | ---------- | ------ |
| Groundskeeper | $80 | +0.08 condition/day (offsets 0.05 base degradation) |
| Marshal | $50 | Pace modifier for course rating |
| Cart Operator | $40 | Golfer walk speed satisfaction |
| Pro Shop | $60 | +$5 revenue per golfer |

**Course condition** degrades at 0.05/day without groundskeepers and restores at 0.08/day per groundskeeper (net +0.03/day with one). Condition ranges 0.0–1.0 and affects the Condition rating category (30% of overall star rating). Firing a groundskeeper incurs an immediate 0.10 condition penalty (maintenance disruption), preventing costless fire/rehire cycling.

### 7. Seasonal & Theme Modifiers

Maintenance and spawn rates are modified by both season and course theme:

```
# Maintenance: theme-aware seasonal modifier (see seasonal-calendar.md)
season_mod = SeasonSystem.get_blended_maintenance_modifier(day, theme)

# Spawn rate: theme-aware seasonal modifier
spawn_mod = SeasonSystem.get_blended_spawn_modifier(day, theme)

# Fee tolerance: seasonal modifier on what golfers consider "fair"
fee_tolerance = SeasonSystem.get_fee_tolerance(day, theme)
fair_price *= fee_tolerance   # Applied in CourseRatingSystem value rating
```

Example: Parkland theme in summer has 1.4× spawn rate but 1.4× maintenance cost. Desert theme in winter has 1.4× spawn rate but only 1.0× maintenance. See [seasonal-calendar.md](seasonal-calendar.md) for full theme × season tables.

### 8. Difficulty Presets

| Parameter | Easy | Normal | Hard |
| --- | --- | --- | --- |
| Starting money | $40,000 | $25,000 | $15,000 |
| Maintenance multiplier | 0.8x | 1.0x | 1.3x |
| Spawn rate multiplier | 1.2x | 1.0x | 0.8x |
| Reputation decay multiplier | 0.5x | 1.0x | 2.0x |
| Bankruptcy threshold | -$5,000 | -$1,000 | $0 |
| Green fee sensitivity | 0.7x | 1.0x | 1.5x |
| Building cost multiplier | 0.8x | 1.0x | 1.2x |

Green fee sensitivity scales how harshly overpricing is penalized in the value
rating (see [course-rating.md](course-rating.md)). Higher = overpricing hurts more.

---

## Exploit Analysis

All potential exploits have been mathematically analyzed and tested:

| # | Exploit | Status | Analysis |
|---|---------|--------|----------|
| 1 | 3-hole coast forever | **Mitigated** | Stagnation penalty (-0.3 rep/day after 28 days at same hole count), power 2.0 spawn curve (2★ = 0.44× golfers), winter squeeze (0.3× seasonal × 0.44× rating = 0.13×). Coasting on 3 holes becomes unprofitable by day 60. |
| 2 | Max loan → buildings → profit | **Not exploitable** | $50k loan at 5%/7days = ~$357/day interest. Buildings alone (no green fees) generate ~$200/day revenue vs $535/day operating costs = -$335/day loss. Loan makes it worse. Buildings are supplements, not replacements for green fees. |
| 3 | $200 green fee on 1 hole | **Mitigated** | Fee cap ($10/hole) limits 1-hole course to $10 max. |
| 4 | Spam marketing for infinite golfers | **Mitigated** | sqrt() diminishing returns on marketing campaigns. |
| 5 | Fire all staff, rehire later | **Mitigated** | Firing groundskeeper now applies immediate 0.10 condition penalty. Condition degrades at 0.05/day without groundskeeper. Recovery takes ~3 days per groundskeeper. $240 savings over 3 days not worth the rating hit. |
| 6 | Never buy land, 40×40 forever | **Self-limiting** | Starting 40×40 fits ~4-5 holes max. Stagnation penalty kicks in at 28 days (-0.3 rep/day, floor 40). Design rating capped at ~2.75 stars. Local tournaments only ($300 net). Strategy stagnates — revenue capped, rep decays to floor. |
| 7 | Tournament spam every 8 days | **Already balanced** | 7-day cooldown. Net profit per tier: Local -$200, Regional $0, National $0, Championship -$10k. Tournaments lose regular green fee revenue on tournament days (~$1,000). Value is reputation (+15 to +300), not money. |
| 8 | Bench spam ($0 upkeep) | **Self-limiting** | `_visited_buildings` prevents re-visits per round. Interaction chance only 20% when energy is high. Tiny mood boost (0.02 per bench). Only restores energy (not comfort/hunger/pace). A $1,500 restroom provides more value than 7 benches ($1,400). |

---

## Tuning Levers

| Parameter | Location | Current Value | Effect |
| --- | --- | --- | --- |
| Starting money | `difficulty_presets.gd` | $40K/$25K/$15K | Higher = easier start |
| Bankruptcy threshold | `difficulty_presets.gd` | -$5K/-$1K/$0 | Lower = more debt allowed |
| Min green fee | `game_manager.gd` | $10 | Floor for pricing |
| Max green fee | `game_manager.gd` | $200 | Ceiling for pricing |
| Fee per hole cap | `game_manager.gd` | $10/hole | Higher = more pricing freedom |
| Base operating cost | `game_manager.gd` | $100 + $50/hole | Higher = more expensive to run |
| Max loan | `game_manager.gd` | $50,000 | Higher = more emergency funding |
| Loan interest rate | `game_manager.gd` | 5% per 7 days | Higher = faster debt spiral |
| Staff salaries | `staff_manager.gd` | $40–$80/day | Higher = more expensive staff |
| Groundskeeper firing penalty | `staff_manager.gd` | 0.10 condition | Higher = more penalty for cycling |
| Green fee sensitivity | `difficulty_presets.gd` | 0.7/1.0/1.5 | Higher = overpricing penalized more |
| Stagnation threshold | `game_manager.gd` | 28 days | Lower = faster penalty for not expanding |
| Stagnation decay | `game_manager.gd` | -0.3 rep/day | Higher = more pressure to expand |
