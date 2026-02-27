# Game Balance & Tuning Pass — Product Spec

**Author:** Claude (Product)
**Date:** 2026-02-27
**Status:** Proposal
**Milestone:** Beta Milestone 4
**Priority:** P1 — Core Quality
**Est. Scope:** Medium

---

## Problem Statement

Individual economic systems have been balanced in isolation — green fees are clamped, operating costs scale with course size, reputation decays by star level, and marketing has diminishing returns. But the full interaction of **all systems together** has not been tuned as a cohesive experience.

Phase 3 added three significant money sinks and sources (land: $5,000+ per parcel, staff: $40–$80/day per employee, marketing: $50–$250/day per campaign) that change the economic equilibrium. The seasonal system adds revenue peaks and troughs. Without a holistic tuning pass, players may hit unintended poverty traps or discover exploits that trivialize the game.

The goal is not to make the game "hard" or "easy" — it's to make it **interesting**. Every financial decision should feel like a meaningful tradeoff, and the player should feel steady progression from a 3-hole starter course to a thriving 18-hole resort.

---

## Current Economic Model

### Revenue Sources

| Source | Current Value | Notes |
|--------|--------------|-------|
| Green fees | $10–$200 per golfer per hole | Auto-clamped: min = $15 × open holes |
| Building revenue | $5–$25 per golfer in range | Proximity-based: Snack Bar $5, Pro Shop $15, Restaurant $25 |
| Pro Shop staff bonus | $5 per golfer per Pro staff | From `StaffManager.get_pro_shop_revenue_bonus()` |
| Tournament revenue | $800–$80,000 | Spectator + sponsorship by tier |

### Cost Sinks

| Sink | Current Value | Notes |
|------|--------------|-------|
| Starting money | $50,000 | Must cover ~3 holes + building + land expansion |
| Operating costs | $50 base + $25/hole + terrain maintenance | Daily fixed costs |
| Staff payroll | $40–$80/day per staff member | 4 types: Groundskeeper $80, Pro $60, Marshal $50, Cart $40 |
| Marketing campaigns | $50–$250/day + 2× setup cost | 5 channels with diminishing returns |
| Land parcels | $5,000 × 1.3^n escalation | Progressive pricing, adjacent-only |
| Buildings | $500–$10,000 one-time | 8 types, Clubhouse upgrades to $20,000 |
| Loan interest | 5% every 7 days | Max loan $50,000 |
| Reputation decay | 0.1–1.0/day by star tier | Higher stars decay faster |
| Seasonal maintenance | 0.7×–1.4× by season | Via `SeasonSystem.get_maintenance_modifier()` |

### Key Modifiers

| Modifier | Current Behavior |
|----------|-----------------|
| Difficulty presets | Easy: $75,000 start, bankruptcy at -$5,000. Normal: $50,000, -$1,000. Hard: $30,000, -$500. Sandbox: $500,000, no bankruptcy |
| Green fee tolerance | Golfers weigh fee vs. course quality. Seasonal modifier 0.7×–1.2× |
| Spawn rate | Composite: base × weather × reputation × marketing × seasonal × event |
| Course rating | 4-factor weighted (Condition 30%, Design 20%, Value 30%, Pace 20%) |

---

## User Stories

1. **As a player**, I want the early game to feel tight but not punishing — I should be able to afford my first 3 holes and a building or two without going bankrupt, but I shouldn't have excess cash.
2. **As a player**, I want the mid-game to present interesting tradeoffs — do I expand land, hire more staff, or invest in marketing?
3. **As a player**, I want the late game to feel rewarding — a well-run 18-hole course should generate strong profit, but there should still be decisions to make.
4. **As a player**, I don't want to discover an exploit that trivializes the game (e.g., one building combo that generates infinite money).
5. **As a player**, I want bankruptcy to be avoidable with reasonable play but possible with bad decisions.

---

## Functional Requirements

### FR-1: Progression Curve Targets

These are aspirational targets to verify through playtesting, not hard-coded constraints:

| Phase | Day Range | Expected Course State | Expected Money Range |
|-------|-----------|----------------------|---------------------|
| **Early** | Days 1–30 | 3 holes, 1–2 buildings, learning mechanics | $20K–$60K |
| **Growth** | Days 30–90 | 6–9 holes, first land expansion, first staff hires | $30K–$100K |
| **Mid** | Days 90–180 | 9–14 holes, full staff, marketing campaigns, first tournament | $50K–$200K |
| **Late** | Days 180–360 | 14–18 holes, regular tournaments, high reputation | $100K–$500K |
| **Endgame** | Days 360+ | Fully optimized course, trophy collection | $200K+ |

### FR-2: Economy Audit Areas

#### 2a. Golfer Spawn Rate vs. Hole Count
**Question:** Does adding holes proportionally increase revenue?

**Target:** A 9-hole course should earn ~2–3× a 3-hole course (not linearly, because traffic cap increases by 4 golfers per hole).

**Verification:**
- Play a 3-hole course for 30 days, record average daily revenue
- Expand to 9 holes, play 30 more days, compare
- If revenue doesn't scale meaningfully with holes, the spawn rate or max concurrent golfer formula needs adjustment

**Current formula:** `max_concurrent_golfers = max(4, open_holes * 4)` — 3 holes = 12 golfers, 9 holes = 36, 18 holes = 72. This may be too generous at scale.

#### 2b. Staff ROI
**Question:** Does each staff type pay for itself within 5–10 days?

**Target:** Groundskeepers are mandatory for good course rating. Marshals and Cart Operators are optional optimizations. Pro Staff is a revenue multiplier.

**Verification per staff type:**

| Staff | Daily Cost | Expected Daily Benefit | Break-Even |
|-------|-----------|----------------------|------------|
| Groundskeeper ($80) | Course condition → Condition rating → Course rating → spawn rate | Should recover via increased golfer traffic within 5 days |
| Marshal ($50) | Pace modifier → Pace rating → Course rating | Should recover via rating improvement within 7 days |
| Cart Operator ($40) | Golfer satisfaction modifier | Indirect ROI through satisfaction → reputation → spawns |
| Pro ($60) | $5/golfer bonus revenue | Break-even at 12 golfers/day — verify this is realistic |

#### 2c. Marketing ROI
**Question:** Are marketing campaigns profitable when the course has capacity?

**Target:** Positive ROI within campaign duration on a 6+ hole course. Wasteful on a 3-hole course (traffic cap reached quickly).

**Current formula:** Spawn modifier = `1.0 + sqrt(total_bonus)` where total_bonus sums campaign bonuses (0.15–0.50 each).

**Verification:**
- 6-hole course, Normal green fee: Run Local Ads ($50/day, 5 days, +15% spawn). Track additional golfers and revenue vs. $350 total cost (5 × $50 + $100 setup).
- Same test on 3-hole course: should show diminishing returns as max concurrent cap is reached faster.

#### 2d. Land Expansion Timing
**Question:** When should first land expansion feel natural?

**Target:** Day 20–40, when the player needs space for holes 4–6. Final parcels should be late-game purchases.

**Current pricing:** $5,000 × 1.3^n. First expansion = $5,000. 6th expansion = ~$9,300. Buying all 32 non-starting parcels costs ~$870,000 total.

**Verification:**
- Track when player money first exceeds $5,000 + current needs
- Ensure players aren't forced to expand (can build 3 holes on starting 40×40 plot)
- Ensure late-game parcels feel like investment decisions, not trivial purchases

#### 2e. Reputation Curve
**Question:** Does reputation climb at the right pace?

**Target:**
- ~50 reputation by Day 90 with good management
- ~80 by Day 270
- 90+ requires excellent course design AND management

**Current mechanics:** Reputation gains from golfer satisfaction (per golfer per day), decays based on star tier (higher stars decay faster). Floor at 0, ceiling at 100.

**Verification:**
- Track reputation over a 360-day playthrough
- Identify if any strategy trivially caps reputation early
- Identify if reputation ever feels impossible to grow

#### 2f. Green Fee Sweet Spot
**Question:** Is there a clear relationship between course quality and optimal green fee?

**Target:**
- 2-star course charging $80: dramatically fewer golfers than at $30
- 4-star course: can sustain $100+ green fee
- Fee sensitivity should be noticeable — overcharging visibly reduces traffic

**Current formula:** Value rating = `5.0 - (price_ratio - 0.5) * 2.67` where price_ratio = actual_cost / fair_price. Fair price derived from reputation and hole count.

**Verification:**
- On a 3-star, 9-hole course: test $20, $50, $80, $120 green fees
- Record golfer count and revenue at each level over 10 days
- There should be a clear revenue-maximizing sweet spot

#### 2g. Bankruptcy Prevention
**Question:** Does the game give adequate warning before bankruptcy?

**Target:**
- 3+ days of consecutive losses trigger contextual hint (from Milestone 3)
- Lowering green fees and firing staff should be viable recovery strategies
- Bankruptcy (-$1,000 on Normal) should require ~10+ days of ignoring warnings

**Verification:**
- Intentionally mismanage: overhire staff, overspend on marketing, set fees too high
- Track how many warning opportunities exist before hitting -$1,000
- Verify that corrective actions (fire staff, lower fees, cancel campaigns) can reverse the slide

### FR-3: Seasonal Balance Verification

**Question:** Does seasonal variation create meaningful but survivable cash flow planning?

**Target:**
- Summer peak revenue should be 1.5–2× average
- Winter trough should not bankrupt a well-managed course
- Players should feel the need to save during summer for winter
- Mountain course winter closure should be a real choice (some players might prefer to stay open)

**Verification:**
- Track revenue by season over a full year on a 9-hole Parkland course
- Repeat on a Mountain course to verify winter closure economics
- Repeat on a Desert/Resort course to verify softened winter

### FR-4: Exploit Hunting

Systematically test for degenerate strategies:

| Potential Exploit | Test | Expected Outcome |
|-------------------|------|-----------------|
| Spam Pro Shop staff | Hire 10 Pro staff ($600/day) on 3-hole course | Revenue from $5/golfer bonus should not exceed payroll |
| Marketing spam | Run all 5 channels simultaneously | Diminishing returns (sqrt formula) should cap benefit |
| Building spam | Place 10 Snack Bars in a cluster | Revenue should not scale linearly with count (proximity overlap) |
| Zero green fee | Set fee to $10 minimum, rely on building revenue | Should be viable but suboptimal — buildings alone shouldn't be enough |
| Max green fee | Set fee to $200 on a mediocre course | Should attract almost zero golfers |
| Loan abuse | Take max loan ($50,000), invest in rapid expansion | Interest (5%/week) should create pressure to repay |

### FR-5: Balance Tuning Adjustments

Based on FR-2 through FR-4 verification results, adjust these values:

#### Tuning Levers (data-driven, no code changes needed)

| Parameter | File | Key |
|-----------|------|-----|
| Green fee range | `game_manager.gd` constants | `MIN_GREEN_FEE`, `MAX_GREEN_FEE` |
| Operating costs | `game_manager.gd` | `BASE_OPERATING_COST`, `PER_HOLE_COST` |
| Staff salaries | `staff_manager.gd` | Per-type salary constants |
| Marketing costs | `marketing_manager.gd` | Per-channel cost/duration/bonus |
| Land escalation | `land_manager.gd` | `BASE_PARCEL_COST`, `COST_ESCALATION` |
| Building costs/revenue | `data/buildings.json` | Per-building values |
| Spawn rate formula | `golfer_manager.gd` | Modifier composition |
| Reputation decay | `game_manager.gd` | Per-star decay values |
| Seasonal modifiers | `season_system.gd` | Per-season multipliers |
| Difficulty presets | `scripts/systems/difficulty_presets.gd` | Per-preset modifiers |

#### Tuning Documentation
All final values must be documented in a balance reference:
- `docs/algorithms/economy.md` updated with final values
- `docs/algorithms/reputation.md` updated with decay curves
- New `docs/algorithms/balance-reference.md` with complete parameter table

---

## Acceptance Criteria

- [ ] Starting money ($50,000) allows building 3 holes + 1 building without going broke on Normal difficulty
- [ ] A "reasonable play" session reaches Day 90 without bankruptcy on Normal
- [ ] A "bad play" session (overspending, wrong green fees) hits bankruptcy but with clear warning signs
- [ ] No single exploit generates unlimited money (tested per FR-4 table)
- [ ] 18-hole late-game course generates $500–$2,000/day profit (not $10,000+)
- [ ] All staff types have positive ROI on appropriate-sized courses
- [ ] Marketing campaigns are profitable on 6+ hole courses, wasteful on 3-hole courses
- [ ] Reputation reaches ~50 by Day 90 with good management
- [ ] Green fee sensitivity is noticeable — overcharging visibly reduces traffic
- [ ] Summer revenue is measurably higher than winter revenue
- [ ] All tuning values documented in `docs/algorithms/balance-reference.md`
- [ ] Existing tests pass without regression

---

## Balance Testing Protocol

Play through 5 complete sessions (360 days each) with different strategies:

1. **Speedrun** — Build as fast as possible, maximum investment. Expected: early cash crunch, late-game wealth.
2. **Conservative** — Minimal spending, slow expansion. Expected: stable but slow growth, low reputation.
3. **Builder** — Focus on course design, ignore economy. Expected: beautiful course, financial pressure.
4. **Min-maxer** — Optimize revenue per golfer, exploit every system. Expected: high profit, but exploit cap should prevent infinite scaling.
5. **New player simulation** — Make mistakes, recover. Expected: some setbacks, but recoverable with 2-3 course corrections.

Document the financial trajectory of each playthrough and compare against FR-1 targets.

---

## Out of Scope

- Difficulty settings (Easy/Medium/Hard already exist via DifficultyPresets — this milestone tunes Normal difficulty)
- AI director that adjusts difficulty dynamically
- Detailed analytics dashboard for the player
- New economic systems or revenue sources
- Changing the fundamental economic model (this is a tuning pass, not a redesign)

---

## Dependencies

- **Milestone 1** (Phase 3 Verification): Land, Staff, Marketing must be verified working
- **Milestone 2** (Seasonal Calendar): Seasonal modifiers must be functional to test full-year cash flow
- Phase 3 systems (Land, Staff, Marketing) all contribute to the economic equation

---

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Balance changes break existing save files | Low | Medium | Only change constant values, not data structures |
| Tuning for Normal difficulty makes Easy too easy or Hard too hard | Medium | Medium | Verify all difficulty presets after Normal tuning |
| Seasonal variation dominates all other economic decisions | Medium | High | Keep seasonal modifiers moderate (0.5×–1.2×), not extreme |
| Balance depends on player skill (experienced vs. new) | High | Medium | Test with both playstyles; ensure the floor isn't punishing and the ceiling isn't trivial |

---

## Estimated Effort

- Playtesting (5 sessions × 360 days at Ultra speed): 5–10 hours
- Analysis and documentation: 2–3 hours
- Parameter tuning (adjusting constants): 1–2 hours
- Balance reference document: 1–2 hours
- Regression testing: 1 hour
- **Total: 10–18 hours**
