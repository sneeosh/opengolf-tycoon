# Shot Data Analysis — Round 3 (Post Skill-Factor Reduction)

## Test Course Layout
| Hole | Par | Yardage | Notes |
|------|-----|---------|-------|
| 1 | 4 | 396yd | ~18 tiles |
| 2 | 4 | 405yd | ~18.4 tiles |
| 3 | 5 | 585yd | ~26.6 tiles |
| 4 | 3 | 140yd | ~6.4 tiles |

**Weather:** Sunny, 8-9mph wind (SW then rotating to NE/E)
**Green fee:** $10

## Summary of Changes Since Last Round

Fixes applied before this test:
1. **Driver skill factor floor lowered** from `0.60 + D*0.37` to `0.30 + D*0.65`
2. **FW/Iron skill factors similarly reduced**
3. **Landing zone scan range capped** for lay-up shots

## Key Findings

### CRITICAL: Club Selection Regression — Golfers Hitting Iron/FW From the Tee

The skill factor reduction **overcorrected**. Most casual golfers are now hitting **Iron (150-161yd)** or **Fairway Wood (169-218yd)** off the tee on par 4s instead of Driver.

**Par 4 tee shots observed (Shot 1):**

| Golfer | Driving Skill | Club Used | Distance | Expected |
|--------|:------------:|-----------|:--------:|:--------:|
| Casual Dustin | 0.64 | Iron | 161yd | Driver ~220yd |
| Casual Justin | 0.57 | Iron | 150yd | Driver ~210yd |
| Casual Phil | 0.69 | Iron | 160yd | Driver ~235yd |
| Weekend Bryson | 0.56 | Iron | 154yd | Driver ~210yd |
| Casual Xander | 0.60 | Iron | 157yd | Driver ~215yd |
| Weekend Brooks | 0.62 | FW | 216yd | Driver ~220yd |
| FT Jordan | 0.48 | FW | 180yd | Driver ~190yd |
| Rookie Phil | 0.46 | Iron | 139yd | Driver ~180yd |
| FT Brooks | 0.38 | Iron | 151yd | Driver ~170yd |

**Only 4 Driver shots appeared in the entire dataset:**
- Casual Phil (D=0.69): 225yd, 234yd
- Casual Dustin (D=0.68): 238yd
- Casual Brooks (D=0.69): 219yd

All had driving_skill >= 0.68. Below that threshold, Driver is never selected.

#### Root Cause Analysis

Two compounding issues:

**1. `decide_shot_target()` and `_calculate_shot()` are disconnected.** The targeting function evaluates all candidate clubs and picks the best landing zone (e.g., Driver target at 9.4 tiles on fairway). But `_calculate_shot()` independently calls `select_club(distance_to_target)`, which may pick a DIFFERENT club. For a target at 9.4 tiles, `select_club()` returns FW (since 9.4 < 10, Driver's min_distance). The golfer aimed for a Driver target but executed with a Fairway Wood.

**2. Skill distance factors are slightly too low.** For a mid-casual golfer (D=0.57):
- Driver factor = 0.30 + 0.57 * 0.65 = **0.671**
- Driver max target = 14 * 0.671 = **9.39 tiles (207yd)**
- Driver min_distance = **10 tiles**
- Result: target (9.39) < min (10.0) → Driver never gets selected

Even when the landing zone evaluation correctly chooses Driver's target, the separate club selection rejects it.

### Par 3 (140yd) Plays Way Too Hard

Every golfer uses Wedge (not Iron) for the 140yd par 3 tee shot:

| Golfer | Shot | Club | Distance | Remaining |
|--------|------|------|:--------:|:---------:|
| Justin | S1 | Wedge | 78yd | 64yd (Rough) |
| Dustin | S1 | Wedge | 79yd | 63yd (Rough) |
| Phil | S1 | Wedge | 94yd | 53yd (Natural Grass) |
| Xander | S1 | Wedge | 94yd | 48yd (Natural Grass) |
| Bryson | S1 | Wedge | 75yd | 66yd (Rough) |

This means the par 3 requires 3 approach shots + putting = 5+ strokes consistently. The landing zone evaluation may be penalizing Iron/FW approaches due to terrain obstacles near the green.

### Scoring — Severely Inflated

**Completed rounds:**

| Golfer | Tier | Score | vs Par | Breakdown |
|--------|------|:-----:|:------:|-----------|
| Weekend Bryson | Casual | 21 | +5 | 3 Bogey, 1 Double |
| Casual Justin | Casual | 22 | +6 | 1 Par, 1 Bogey, 1 Double, 1 Triple |
| Casual Dustin | Casual | 23 | +7 | 1 Bogey, 3 Double |
| Casual Phil | Casual | 23 | +7 | 2 Bogey, 1 Double, 1 Triple |
| Casual Xander | Casual | 23 | +7 | 1 Bogey, 3 Double |
| Rookie Phil | Beginner | 25 | +9 | 1 Bogey, 1 Double, 2 Triple |

**Average casual: +6.4 over 4 holes (+1.6/hole)**

Expected for a 15-20 handicap casual: bogey golf (+1.0/hole) = +4 over 4 holes. We're running 60% over expected.

### Putting: FIXED (Holding Steady)

Putting performance looks excellent this round:
- Most golfers 2-putt or better
- 3-putt rate appears near 10-15% (down from 43% in round 1)
- No stuck-in-putter-loop incidents
- Short putt make rates look realistic

### Shanks: FIXED (No Occurrences)

Zero shanks in this entire dataset. The rate reduction from 0.06 to 0.04 multiplier is effective. With typical casual accuracy around 0.50, shank probability is now ~2%, which is reasonable.

## Comparison Across Three Rounds

| Metric | Round 1 | Round 2 | Round 3 | Target |
|--------|:-------:|:-------:|:-------:|:------:|
| Casual avg Driver distance | 280yd | 297yd | N/A (Iron used) | 210-240yd |
| Casual tee shot club | Driver | Driver | Iron/FW | Driver |
| 3-putt rate | 43% | 12.5% | ~12% | 10-15% |
| Shank rate | 13.9% | 5.6% | 0% | 1-3% |
| Casual score per hole | ~+0.75 | ~+0.75 | ~+1.6 | ~+1.0 |
| Putter stuck loop | Yes | No | No | No |

Round 1-2 had Driver distances that were **too high**. Round 3 overcorrected to the point where Driver is **never used** by average golfers. The target is in between.

## Proposed Fixes

### Fix 1: Eliminate Club Selection Mismatch (Critical)

`decide_shot_target()` evaluates and picks the best club + target combination, but only returns the target. `_calculate_shot()` then independently picks a club from scratch. These two systems can disagree.

**Fix:** Store the chosen club from targeting and use it in shot execution. Add a `_chosen_club` member variable that `decide_shot_target()` sets and `_calculate_shot()` reads.

### Fix 2: Raise Driver Skill Factor Floor (Moderate)

Adjust from `0.30 + D * 0.65` to `0.40 + D * 0.55`:

| Tier | Driving Skill | Old Max Target | New Max Target |
|------|:------------:|:--------------:|:--------------:|
| Beginner | 0.30 | 152yd | 174yd |
| Beginner | 0.50 | 193yd | 208yd |
| Casual | 0.57 | 207yd | 220yd |
| Casual | 0.70 | 233yd | 242yd |
| Serious | 0.85 | 263yd | 267yd |
| Pro | 0.98 | 289yd | 289yd |

This pushes casual Driver targets into better landing terrain (fairway starts further from tee) and ensures targets clear Driver's min_distance threshold.

### Fix 3: Lower Driver min_distance (Safety Net)

Reduce Driver min_distance from 10 tiles (220yd) to 9 tiles (198yd). This ensures `select_club()` picks Driver for targets in the 9-10 tile range, which is where casual golfers' Driver targets land.
