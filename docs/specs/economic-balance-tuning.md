# Economic Balance & Tuning Framework — Product Spec

**Author:** Claude (Product)
**Date:** 2026-02-27
**Status:** Proposal
**Priority:** HIGH
**Version:** 0.1.0-alpha context

---

## Problem Statement

The game has all the economic levers: green fees ($10–$200), building revenue, staff payroll, marketing costs, maintenance, land expansion, loans, and reputation decay. But nobody has validated that these interact to produce an engaging economic curve. The starting money ($50K), default green fee ($30), base operating cost ($50 + $25/hole), and bankruptcy threshold (-$1000) are educated guesses based on what felt reasonable during development.

This spec is not a feature spec — it's a **tuning and validation framework** that defines:
1. What the target economic progression should feel like
2. How to test whether current values achieve it
3. What to adjust if they don't

---

## Design Principles

- **Tension, not frustration.** The player should feel economic pressure at specific progression points, but never feel helpless.
- **Decisions matter.** Green fee pricing, building placement, staff hiring, and land expansion should all have visible economic consequences.
- **No dominant strategy.** There should be no single approach that trivially solves the economy.
- **Difficulty presets work.** Easy, Normal, and Hard should produce meaningfully different economic experiences.

---

## Current Economic State

### Revenue Sources
| Source | Current Values | Notes |
|--------|---------------|-------|
| Green fees | $10–$200 per golfer, scaled by holes played | Cap: $15/hole effective max |
| Building revenue | $5–$40/golfer (proximity-based) | Pro Shop $15, Restaurant $25, Snack Bar $5 |
| Tournament revenue | $800–$240K per tournament (spectator + sponsorship) | Entry cost $500–$50K |
| Pro Shop staff bonus | $5/golfer per staff hire | Scales with staff count |

### Cost Centers
| Cost | Current Values | Notes |
|------|---------------|-------|
| Base operating | $50 + $25/hole/day | Fixed daily overhead |
| Staff wages | $5–$20/hole/day (by tier) | Part-Time $5, Full-Time $10, Premium $20 |
| Terrain maintenance | Variable, seasonal modifier | Spring 1.1×, Summer 1.4×, Fall 0.7×, Winter 1.1× |
| Building upkeep | $0–$75/day per building | Bench $0, Clubhouse $75, Restaurant $60 |
| Marketing | $50–$250/day (active campaigns) | Plus setup fees |
| Land expansion | $5K base, 1.3× escalation | 30% more expensive each purchase |
| Loan interest | 5% per 7 days | Compounds weekly on outstanding balance |
| Building purchase | $200–$15K one-time | Bench $200, Restaurant $15K |
| Clubhouse upgrades | $8K–$15K per level | 3 upgrade tiers |

### Starting Conditions
| Parameter | Easy | Normal | Hard |
|-----------|------|--------|------|
| Starting money | $75K | $50K | $25K |
| Green fee | $30 | $30 | $30 |
| Bankruptcy threshold | -$5K | -$1K | $0 |
| Reputation decay multiplier | 0.5× | 1.0× | 2.0× |

---

## Target Progression Curve

### Day-by-Day Milestones (Normal Difficulty)

| Day | Expected State | Money Range | Reputation | Holes | Staff |
|-----|---------------|-------------|------------|-------|-------|
| 1 | First hole built, first golfer | $45K–$48K | 50 | 1 | 0 |
| 7 | 2–3 holes, first building | $35K–$45K | 48–52 | 2–3 | 0–1 |
| 14 | 3–4 holes, staffed up | $25K–$40K | 46–55 | 3–4 | 1–2 |
| 28 | 4–6 holes, first full year | $20K–$45K | 45–60 | 4–6 | 2–3 |
| 56 | 6–9 holes, 2 buildings | $15K–$50K | 50–65 | 6–9 | 2–4 |
| 90 | 9 holes, 3–4 buildings | $20K–$60K | 55–70 | 9 | 3–5 |
| 180 | 12–14 holes, first tournament | $30K–$80K | 60–80 | 12–14 | 4–6 |
| 360 | 18 holes, Championship hosted | $50K–$150K | 70–95 | 18 | 6–8 |

**Key inflection points:**
- **Days 7–14 (The Squeeze):** Player has spent money building holes and buying a building, but revenue from 2–3 holes is modest. This should feel tight but not panicky. Daily costs ≈ $125–$175 (base $75–$125 + staff $10–$40). Daily revenue from 2–4 golfers at $30/hole × 2–3 holes ≈ $120–$360. Margin is thin.
- **Days 28–56 (The Growth Phase):** Revenue scales with holes. 6 holes at $30 × 4–6 golfers/day ≈ $720–$1080. Costs ≈ $250–$400. Comfortable positive margin. Player reinvests in expansion.
- **Days 90–180 (The Plateau Decision):** 9 holes is profitable but not exciting. The player must decide: stay comfortable or invest heavily in expansion to reach 18 holes for National/Championship tournaments. This should feel like a deliberate risk.
- **Days 180–360 (Tournament Payoff):** Tournament revenue ($5K–$240K) justifies the expansion investment. Championship tournaments are the economic victory lap.

---

## Balance Testing Protocol

### 5 Playstyle Profiles

Each profile represents a distinct player strategy. The game should be viable (not bankrupt) for all profiles on Normal difficulty, though some should be harder than others.

**Profile 1: The Speedrunner**
- Build holes as fast as possible, minimal terrain shaping
- Skip buildings until forced by low satisfaction
- Aggressive green fee pricing (near maximum)
- Target: Reach 18 holes by day 90. Should be financially stressed but viable.

**Profile 2: The Conservative**
- Build slowly, one hole at a time
- Max out each hole's design quality before building the next
- Moderate green fees (60–70% of max)
- Target: Reach 9 holes by day 90. Should be comfortably profitable.

**Profile 3: The Builder**
- Focus on buildings and amenities before expanding holes
- Clubhouse fully upgraded early
- Uses building revenue as primary income
- Target: Should work but feel slower than hole-focused strategies.

**Profile 4: The Optimizer**
- 3 highly-designed holes, maximum green fee
- Invest in marketing and premium staff
- Target: Should be viable short-term but hit a ceiling (3 holes can't sustain long-term growth).

**Profile 5: The New Player**
- Makes suboptimal decisions (overstaffing, overpricing, random terrain)
- Doesn't use buildings until day 30+
- Target: Should survive to day 30 on Normal, may struggle on Hard.

### Testing Methodology

For each profile:
1. Play through 360 game-days (13 in-game years)
2. Record daily snapshots: money, revenue, costs, reputation, golfer count, rating
3. Flag any day where money drops below $5K (stress point) or above $200K (potential exploitation)
4. Flag any prolonged period (>14 days) of negative daily profit
5. Verify milestone achievements align with expected timing

**Automated testing approach:**
Create a `BalanceTester` script that simulates decisions without rendering. Uses the headless simulation path to fast-forward through 360 days with each profile's strategy encoded as decision rules.

---

## Specific Tuning Questions

### Q1: Can a player coast on 3 holes forever?

**Expected answer: No.** Reputation decay should eventually overwhelm the revenue from 3 holes.

**Current analysis:**
- 3 holes at $45/golfer × 3 holes = $135/golfer
- With 4–6 golfers/day: $540–$810 revenue
- Daily costs: $50 base + $75 (3 holes) + $30 staff = $155
- Profit: $385–$655/day → player accumulates money indefinitely

**Problem:** This is viable forever. Reputation decay is slow enough at 3-star (−0.5/day) that the player never feels pressure to expand.

**Proposed fix:** Introduce a **stagnation penalty**: if the player has the same hole count for >28 days and reputation is >40, apply an additional reputation decay of 0.3/day. Rationale: golfers get bored of the same 3 holes. This creates soft pressure to expand without punishing players who are actively building.

**Acceptance criteria:** On Normal difficulty with 3 holes and no expansion, reputation should drop below 40 by day 60, reducing golfer spawn rates enough to make the strategy uncompetitive.

### Q2: Is there a building combo that generates infinite money?

**Expected answer: No.**

**Current analysis:**
- Best revenue building: Restaurant at $25/golfer, $60/day upkeep
- With 8 golfers/day: $200 revenue − $60 upkeep = $140 profit from one restaurant
- A course with 4 restaurants: $560 revenue − $240 upkeep = $320 profit
- But restaurants have placement cost ($15K each) and proximity requirements

**Assessment:** Building revenue scales linearly with golfers, not exponentially. Multiple restaurants don't stack multiplicatively. This looks balanced.

**Acceptance criteria:** Building-only revenue (no green fees) should never exceed 50% of total revenue for a well-designed course.

### Q3: Does reputation reach 50 by Day 90 with good play?

**Expected answer: Yes.** Starting at 50, good play should maintain or grow reputation.

**Current analysis:**
- Starting reputation: 50
- Daily decay at 3 stars: −0.5
- Per-golfer gain: +1 (beginner) to +10 (pro), mood-scaled
- With 6 happy golfers/day: +6 to +18 reputation
- Net: +5.5 to +17.5/day

**Assessment:** Reputation grows fast with happy golfers. The concern is that decay could outpace gains if golfer satisfaction drops. Need to verify that the decay rates are calibrated correctly for each star level.

**Acceptance criteria:** A Conservative-profile player maintaining 3-star rating should have reputation ≥55 by day 90.

### Q4: Does green fee sensitivity work?

**Expected answer: $100 on a 2-star course should crater traffic.**

**Current analysis:**
- Value rating: compares `green_fee × holes` to `max(reputation × 2.0, 20.0) × hole_factor`
- 2-star course, reputation 40, 9 holes: fair price = $80 × 0.5 = $40
- $100 × 9 = $900 vs fair $40 → ratio = 22.5× → Value rating = 1 star
- Low Value rating → low overall rating → fewer golfers spawn

**Assessment:** The mechanism works but may be too indirect. The player might not connect "high green fee" → "low rating" → "fewer golfers." Consider adding a direct tooltip: "Green fee appears overpriced for current course quality."

**Acceptance criteria:** Setting green fee to 2× the fair price should reduce golfer traffic by at least 40% within 7 days.

### Q5: Is bankruptcy reachable on Normal difficulty?

**Expected answer: Only through actively bad decisions or deliberate overspending.**

**Acceptance criteria:** A New Player profile should not go bankrupt on Normal before day 30 unless they take out a max loan and spend it on buildings with no holes.

---

## Exploit Checklist

Document and validate each potential exploit:

| # | Exploit | Status | Mitigation |
|---|---------|--------|------------|
| 1 | 3-hole coast forever | **Vulnerable** | Stagnation reputation penalty |
| 2 | Max loan → buy buildings → profit from buildings alone | Needs testing | Loan interest should eat profit |
| 3 | Set $200 green fee on 1 hole | Needs testing | Fee cap ($15/hole) limits this |
| 4 | Spam marketing campaigns for infinite golfers | **Mitigated** | sqrt() diminishing returns |
| 5 | Fire all staff, keep money, rehire later | Needs testing | Course condition degrades → rating drops |
| 6 | Never buy land, play on starting 40×40 forever | Needs testing | 40×40 limits to ~4 holes max |
| 7 | Tournament spam (play every 8 days) | Needs testing | Entry cost + cooldown limits this |
| 8 | Buy bench army (cheap, $0 upkeep, satisfaction boost) | Needs testing | Diminishing returns on satisfaction? |

---

## Proposed Tuning Adjustments

Based on the analysis above, these values should be evaluated:

### Revenue Tuning
| Parameter | Current | Proposed | Rationale |
|-----------|---------|----------|-----------|
| Min green fee | $10 | $10 | OK |
| Max green fee | $200 | $200 | OK |
| Per-hole fee cap | $15/hole | $15/hole | OK |
| Building revenue | $5–$25/golfer | Review | May need proximity scaling tightened |

### Cost Tuning
| Parameter | Current | Proposed | Rationale |
|-----------|---------|----------|-----------|
| Base operating cost | $50 + $25/hole | $50 + $30/hole | Slightly increase per-hole cost to narrow margins |
| Land escalation | 1.3× | 1.3× | OK — feels right |
| Loan interest | 5% per 7 days | 5% per 7 days | Aggressive enough to punish borrowing |

### Reputation Tuning
| Parameter | Current | Proposed | Rationale |
|-----------|---------|----------|-----------|
| Starting reputation | 50 | 50 | OK |
| 3-star decay | −0.5/day | −0.5/day | OK |
| Stagnation penalty | None | −0.3/day after 28 days same hole count | Prevents coasting |

### Difficulty Presets
| Parameter | Easy | Normal | Hard |
|-----------|------|--------|------|
| Starting money | $75K | $50K | $25K |
| Green fee sensitivity | 0.7× | 1.0× | 1.5× |
| Maintenance cost multiplier | 0.8× | 1.0× | 1.3× |
| Reputation decay multiplier | 0.5× | 1.0× | 2.0× |
| Bankruptcy threshold | -$5K | -$1K | $0 |
| Golfer spawn rate | 1.2× | 1.0× | 0.8× |

---

## Output Deliverables

1. **Tuned values** committed to `data/` JSON files and constants in code
2. **Updated `docs/algorithms/economy.md`** with validated numbers and rationale
3. **Balance test results** document showing each profile's 360-day trajectory
4. **Exploit test results** for each item in the exploit checklist
5. **Difficulty preset calibration** with specific parameter values for Easy/Normal/Hard

---

## Implementation Sequence

```
Phase 1 (Measurement):
  1. Add daily economic snapshot logging (money, revenue, costs, reputation, golfer count)
  2. Create balance analysis script to process snapshot data
  3. Run 360-day simulation for each playstyle profile

Phase 2 (Initial Tuning):
  4. Implement stagnation reputation penalty
  5. Adjust per-hole operating costs if margins are too generous
  6. Verify exploit checklist items
  7. Document findings

Phase 3 (Difficulty Calibration):
  8. Run simulations at Easy/Normal/Hard
  9. Adjust difficulty preset multipliers
  10. Verify New Player profile survives 30 days on Normal

Phase 4 (Validation):
  11. Run all 5 profiles × 3 difficulties = 15 simulations
  12. Verify milestones are achievable at expected times
  13. Commit final tuned values
  14. Update algorithm docs with validated numbers
```

---

## Success Criteria

- All 5 playstyle profiles are viable (not bankrupt) on Normal through day 180
- The Optimizer profile (3 holes only) hits a clear ceiling by day 60
- The Speedrunner profile feels financially stressed but not doomed
- Difficulty presets produce meaningfully different experiences (Hard player has <$5K at day 30)
- No exploits in the exploit checklist trivialize the economy
- Green fee pricing decisions have visible consequences within 7 days
- Tournament revenue feels like a meaningful payoff for reaching 18 holes
- Documentation captures the target curve, actual measurements, and tuning rationale

---

## Out of Scope

| Feature | Reason |
|---------|--------|
| Dynamic difficulty adjustment | Players should choose difficulty, not have it adjusted |
| Economic advisor NPC | Nice-to-have UI, not a balance concern |
| Stock market / investment system | Scope creep beyond tycoon core |
| Tax system | Unnecessary complexity |
| Insurance (weather/disaster protection) | No disaster system exists |
