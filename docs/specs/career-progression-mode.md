# Career / Progression Mode — Product Spec

**Author:** Claude (Product)
**Date:** 2026-02-27
**Status:** Proposal
**Priority:** MEDIUM-HIGH
**Version:** 0.1.0-alpha context

---

## Problem Statement

After building a good 18-hole course and hosting a Championship tournament, there is limited incentive to continue playing. The current milestone system (26 milestones across 5 categories) provides short-term goals, but once they're achieved, there's no longer-term structure. The game needs progression beyond "build holes, get money, host tournament" to sustain engagement across multiple hours of play.

This is the difference between a sandbox toy and a tycoon game. Sandbox mode is valuable and should remain, but a structured career mode provides the "one more turn" motivation that keeps players engaged.

---

## Design Principles

- **Sandbox stays.** Career mode is a new option alongside the existing free-play sandbox. Neither replaces the other.
- **Star-gating is natural.** Content unlocks tied to course star rating feel intuitive — "build a better course to unlock better opportunities."
- **Multiple victory paths.** Players should be able to "win" through economic success, tournament prestige, design excellence, or reputation — not just one path.
- **Courses are disposable.** Career mode should encourage starting new courses (different themes, different challenges) rather than grinding one course forever.
- **Pressure creates decisions.** Career mode should create time pressure and resource constraints that force interesting decisions.

---

## Current System Analysis

### Existing Progression Systems
- **Milestones**: 26 achievements across 5 categories (Course Design, Economy, Golfers, Records, Reputation). Rewards: money and reputation bonuses.
- **Course Rating**: 1–5 stars from Condition (30%), Design (20%), Value (30%), Pace (20%). Already gates tournament tiers.
- **Tournament Tiers**: LOCAL (2-star, 4 holes) → REGIONAL (3-star, 9 holes) → NATIONAL (4-star, 18 holes) → CHAMPIONSHIP (4.5-star, 18 holes).
- **Reputation**: 0–100, affects golfer spawning and tier access. Daily decay modulated by star level.
- **Land Expansion**: 36 parcels with escalating costs.

### Gaps
- No overarching objective beyond "accumulate money and reputation"
- No rival courses or competitive pressure
- No reason to start a second course
- No prestige system across multiple playthroughs
- No unlockable content beyond existing milestones
- No scenario/challenge mode with constrained objectives
- No victory screen or endgame

---

## Feature Design

### 1. Star-Gate Progression

Content unlocks are tied to course star rating milestones:

| Star Rating | Unlocks |
|-------------|---------|
| 1 star | Basic tools, 3 terrain types, bench, restroom |
| 2 stars | All terrain types, snack bar, pro shop, LOCAL tournaments |
| 3 stars | Cart shed, driving range, REGIONAL tournaments, Executive prebuilt package |
| 4 stars | Restaurant, clubhouse upgrades, NATIONAL tournaments, Standard prebuilt package |
| 4.5 stars | CHAMPIONSHIP tournaments, Championship prebuilt package |
| 5 stars | Hall of Fame entry, prestige points, premium unlockables |

**Already implemented gates:**
- Tournament tiers are already gated by star rating in `TournamentSystem.check_qualification()`
- Green fee max is gated by hole count

**New gates to implement:**
- Building availability (currently all buildings available from start)
- Prebuilt course packages (from Premium Land spec)
- Premium decorations (from Expanded Decorations spec)

**Gate enforcement:** When a player's rating drops below a threshold, already-purchased content is not removed — they just can't buy more until they regain the rating. Tournaments already handle this correctly.

---

### 2. Career Objectives

A career consists of a series of objectives organized into tiers. Each tier has a primary goal and optional bonus objectives.

**Career Tier Structure:**

**Tier 1: Getting Started (Days 1–30)**
- Primary: Build 3 holes and attract your first 10 golfers
- Bonus: Achieve 2-star rating
- Bonus: End tier with $40K+ remaining
- Reward: $5,000 bonus, unlock Tier 2

**Tier 2: Building a Course (Days 30–90)**
- Primary: Build 9 holes and achieve 3-star rating
- Bonus: Host a LOCAL tournament
- Bonus: Reach 50 reputation
- Reward: $10,000 bonus, unlock Tier 3

**Tier 3: Establishing Excellence (Days 90–180)**
- Primary: Build 14 holes, achieve 4-star rating, host REGIONAL tournament
- Bonus: Reach 70 reputation
- Bonus: Accumulate $100K total
- Bonus: Achieve a course record (any golfer shooting under par)
- Reward: $25,000 bonus, unlock Tier 4

**Tier 4: Championship Aspirations (Days 180–360)**
- Primary: Build 18 holes, achieve 4.5-star rating, host NATIONAL tournament
- Bonus: Host CHAMPIONSHIP tournament
- Bonus: Reach 90 reputation
- Bonus: Record a hole-in-one during a tournament
- Reward: $50,000 bonus, prestige points, unlock Tier 5

**Tier 5: Legacy (Day 360+)**
- Primary: Achieve 5-star rating and host a Championship tournament
- Bonus: Reach 100 reputation
- Bonus: Accumulate $500K
- Bonus: Complete all milestones
- Reward: Hall of Fame entry, career completion badge

**Career panel:** A dedicated UI panel showing current tier, objectives with progress bars, and upcoming tiers (locked, showing requirements).

---

### 3. Rival Courses

AI-managed competing courses that create economic pressure:

**Rival behavior:**
- 2–3 rival courses exist per career game (generated at start)
- Each rival has a name, theme, star rating, green fee, and reputation
- Rivals progress slowly over time (improving their ratings and adjusting fees)
- Rivals affect the player through competition for golfers

**Competition mechanics:**
- Golfer spawn rate is modified by the player's **competitive position**: if a rival has a better value rating (quality-to-price ratio), some potential golfers go there instead
- Competitive modifier: `1.0 - (rival_advantage * 0.15)` where rival_advantage is the number of rivals with better value ratings
- Maximum impact: -30% spawn rate (2 rivals both better)
- This creates pressure to either improve quality or lower prices

**Rival information display:**
- "Rival Courses" panel accessible from HUD
- Shows each rival's name, star rating, green fee, and relative position
- Updated daily with small changes (rival rating ±0.1, fee ±$5)
- Player gets notifications when a rival surpasses them: "Riverside Golf Club has reached 4 stars!"

**Rival progression formula:**
```gdscript
# Daily rival update
rival.star_rating += randf_range(-0.02, 0.05)  # Slow upward trend
rival.star_rating = clamp(rival.star_rating, rival.min_rating, rival.max_rating)
rival.green_fee = int(rival.star_rating * 20 + randf_range(-5, 5))
```

**Rival defeat:** When the player's course surpasses a rival in both star rating AND reputation, the rival is "defeated" — they stop competing and the player gets a reputation bonus. Rivals are not eliminated from the game but no longer affect spawn rates.

---

### 4. Prestige System

A lifetime achievement score that persists across multiple career games:

**Prestige points are earned by:**
| Achievement | Points |
|-------------|--------|
| Complete Career Tier 1 | 10 |
| Complete Career Tier 2 | 25 |
| Complete Career Tier 3 | 50 |
| Complete Career Tier 4 | 100 |
| Complete Career Tier 5 (Career Complete) | 200 |
| Host Championship tournament | 50 |
| Defeat rival course | 25 |
| Achieve 5-star rating | 100 |
| Reach 100 reputation | 50 |
| Complete all milestones | 75 |
| Each unique theme completed | 30 |

**Prestige levels:**
| Level | Points Required | Title |
|-------|----------------|-------|
| 1 | 0 | Greenkeeper |
| 2 | 50 | Club Manager |
| 3 | 150 | Course Designer |
| 4 | 350 | Golf Director |
| 5 | 600 | Tour Commissioner |
| 6 | 1000 | Golf Legend |

**Prestige rewards:**
- Starting money bonus: +$5K per prestige level on new career games
- Cosmetic: Title displayed on main menu and career panel
- Unlock: Completing all 10 themes grants a "Grand Slam" achievement

**Persistence:** Prestige data stored in a separate file (`user://prestige.json`) that persists across career games. Not tied to individual save files.

---

### 5. Scenario / Challenge Mode

Pre-configured challenges with specific starting conditions and objectives:

**Scenario 1: "The Renovation"**
- Start with a poorly designed prebuilt 9-hole course (2-star)
- Budget: $30K
- Objective: Renovate to 4-star rating within 90 days
- Constraint: Cannot build new holes (only improve existing ones)

**Scenario 2: "Desert Oasis"**
- Theme: Desert (forced)
- Start with elite parcels containing oasis features
- Budget: $60K
- Objective: Build an 18-hole championship course and host a tournament

**Scenario 3: "Budget Course"**
- Start with $15K and 1 hole (Starter package)
- Objective: Grow to 9 profitable holes without going below $0
- Constraint: No loans allowed

**Scenario 4: "Tournament Trail"**
- Start with a decent 9-hole course (3-star)
- Budget: $100K
- Objective: Host tournaments at all 4 tiers within 180 days
- Constraint: Must maintain 3-star rating throughout

**Scenario 5: "Winter Challenge"**
- Theme: Mountain
- Start in winter (day 22)
- Budget: $40K
- Objective: Survive to summer and achieve 3-star rating
- Constraint: Winter spawn rate of 0.1× means almost no revenue

**Scenario UI:**
- Scenario selection screen accessible from main menu
- Each scenario shows: title, description, starting conditions, objectives, difficulty rating
- Completion tracked per scenario (completed/not completed)
- Scenarios award prestige points on first completion

---

### 6. Victory Conditions

Define what "winning" means with multiple paths:

**Victory Type 1: Economic Victory**
- Accumulate $500K with 18 holes and no outstanding loans
- Represents financial mastery

**Victory Type 2: Prestige Victory**
- Reach 100 reputation and 5-star rating
- Represents quality excellence

**Victory Type 3: Tournament Victory**
- Host 5 Championship tournaments with positive net profit on each
- Represents competitive excellence

**Victory Type 4: Design Victory**
- Complete all milestones and have every hole rated 6+ difficulty
- Represents design mastery

**Victory screen:** When any victory condition is met, show a congratulatory screen with:
- Victory type achieved
- Course statistics summary (days played, total golfers served, total revenue, total tournaments)
- Prestige points earned
- Option to continue playing (sandbox transition) or start a new career

---

## Data Model Changes

### CareerManager (new singleton):
```gdscript
# scripts/managers/career_manager.gd

var career_mode: bool = false           # false = sandbox mode
var current_tier: int = 1               # Career tier (1-5)
var tier_objectives: Dictionary = {}    # objective_id → {completed, progress}
var rivals: Array[RivalCourse] = []
var victories: Array[String] = []       # Victory types achieved

class RivalCourse:
    var name: String
    var theme: CourseTheme.Type
    var star_rating: float
    var green_fee: int
    var reputation: float
    var min_rating: float               # Floor for rival progression
    var max_rating: float               # Ceiling for rival progression
    var defeated: bool = false
```

### PrestigeManager (new):
```gdscript
# scripts/managers/prestige_manager.gd

var prestige_points: int = 0
var prestige_level: int = 1
var completed_themes: Array[int] = []   # Theme types with career completion
var completed_scenarios: Array[String] = []

func save_prestige() -> void:
    # Save to user://prestige.json (separate from game saves)

func load_prestige() -> void:
    # Load on game start
```

### Save/Load changes:
```gdscript
# Add career data to save format:
{
    "career": {
        "enabled": true,
        "current_tier": 2,
        "objectives": { ... },
        "rivals": [ ... ],
        "victories": []
    }
}
```

---

## Implementation Sequence

```
Phase 1 (Career Framework):
  1. CareerManager singleton with tier/objective tracking
  2. Career mode toggle on main menu (Sandbox vs Career)
  3. Career Tier 1 and 2 objectives
  4. Career panel UI showing objectives and progress

Phase 2 (Rival System):
  5. RivalCourse data model and daily progression
  6. Spawn rate competitive modifier
  7. Rival Courses info panel
  8. Rival defeat detection and notification

Phase 3 (Full Career):
  9. Career Tiers 3, 4, 5 objectives
  10. Victory conditions and victory screen
  11. Star-gate building availability
  12. Career completion flow

Phase 4 (Prestige & Scenarios):
  13. PrestigeManager with cross-game persistence
  14. Prestige points and levels
  15. Scenario mode with 5 scenarios
  16. Scenario selection UI
  17. Prestige rewards (starting money bonus)
```

---

## Success Criteria

- Career mode provides clear "what to do next" direction at every point
- Career tiers create natural pacing (players reach Tier 3 around day 90–120)
- Rival courses create competitive pressure without feeling unfair
- Players feel motivated to start new careers with different themes
- Victory screen provides satisfying closure
- Sandbox mode remains fully functional and unaffected by career features
- Prestige system creates cross-game progression incentive
- Scenarios provide focused, replayable challenges

---

## Dependencies

| Dependency | Status | Impact |
|-----------|--------|--------|
| Simulated Tournament Rounds (Spec 1) | Proposed | Career Tier 4–5 require meaningful tournaments |
| Seasonal System Expansion (Spec 3) | Proposed | Season variation adds economic depth to career |
| Economic Balance (Spec 4) | Proposed | Career pacing requires validated economy |
| Premium Land (Spec 5) | Proposed | Provides late-game content for career rewards |

---

## Out of Scope

| Feature | Reason |
|---------|--------|
| Multiplayer / competitive careers | Requires networking — fundamentally different game |
| Story mode / narrative | Not a narrative game |
| Course trading / marketplace | Requires online infrastructure |
| Procedural career generation | Fixed tiers provide consistent experience |
| Staff progression / leveling | Adds complexity without sufficient decision depth |
| Real-time rival visualization | Rivals are economic pressure, not visible courses |
