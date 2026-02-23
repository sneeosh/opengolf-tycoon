# Tycoon Genre Feature Review

A veteran tycoon-game-player analysis of OpenGolf Tycoon's feature set measured against genre staples from RollerCoaster Tycoon, Two Point Hospital, Golf Resort Tycoon, and SimGolf (2002). What's here, what's missing, and what matters most.

---

## Verdict Up Front

OpenGolf Tycoon has **strong simulation bones** — the golf engine (shot physics, wind, weather, course rating) is genuinely deep. But as a *tycoon game*, it's missing several pillars that RCT/TPH players expect on day one. The biggest gaps: no staff you can see or manage meaningfully, no rival competition, no random crises, and no late-game prestige loop. The seasonal calendar and milestone system are good starts, but the mid-to-late game currently plateaus once you've built 18 holes and hosted a Championship.

**Overall Tycoon Completeness: ~55%** — Excellent foundation, but noticeable holes in the genre checklist.

---

## What's Already Solid

These systems meet or exceed genre standards:

### Course Design Tools (A)
- 14 terrain types, elevation (-5 to +5), 6 course themes with gameplay modifiers
- Hole creation wizard (tee → green → flag), auto-par from yardage
- Undo stack (50 actions), terrain brush, elevation tool
- This is the SimGolf DNA and it works. The procedural tileset per theme is a nice touch.

### Golfer Simulation (A)
- 4 tiers (Beginner → Pro) with distinct skill ranges, patience, spending
- 5 archetypes with weighted spawning (Casual 40%, Pro 5%)
- Full shot physics: angular dispersion, wind compensation, shanks, recovery
- Group play (1-4), double-par pickup, state machine behavior
- Thought bubble feedback with 14 trigger types
- This exceeds what SimGolf and Golf Resort Tycoon had. The shot AI with Monte Carlo risk analysis is particularly well done.

### Weather & Wind (A-)
- 6 weather states with smooth state-machine transitions
- Seasonal weather distribution (Summer skews sunny, Winter skews rain)
- Wind: daily generation, hourly drift, club-specific sensitivity
- Crosswind displacement, headwind/tailwind distance modifiers
- Affects spawn rates and shot accuracy

### Economy Fundamentals (B+)
- Green fees ($10-$200), 8 building types, proximity-based revenue
- Daily operating costs (terrain maintenance, staff wages, building upkeep)
- Loan system (up to $50k, 5% weekly interest)
- Marketing campaigns (5 channels with ROI tracking)
- Land expansion with escalating costs ($5k base, +30% per parcel)
- Transaction history, financial panel, 7-day trending

### Course Rating (A-)
- 4-category weighted formula: Condition (30%), Design (20%), Value (30%), Pace (20%)
- USGA slope rating calculation (55-155 scale)
- Prestige multiplier for high-difficulty + high-quality courses
- Directly drives golfer spawning, tier distribution, reputation

### Progression Basics (B)
- Reputation 0-100 with daily decay scaled by star level
- 26 milestones across 5 categories (Course, Economy, Golfers, Records, Reputation)
- Tournament ladder: Local → Regional → National → Championship
- Seasonal calendar (28-day year) with 8 themed events

---

## The Missing Genre Staples

Organized by impact — what a tycoon veteran would notice first.

### 1. Staff Management (CRITICAL)

**Genre standard:** RCT has handymen, mechanics, security, entertainers you place and patrol-route. TPH has doctors, nurses, janitors, receptionists with skill levels, training, happiness, salary negotiation. SimGolf had a pro golfer you could control.

**Current state:** Staff exists as an abstract system — 4 types (Groundskeeper, Marshal, Cart Operator, Pro Shop), hire/fire in a panel, daily payroll. But staff members are **invisible**. No sprites on the map, no patrol routes, no individual skill progression, no staff happiness, no training, no salary demands.

**What's missing:**
- Visible staff on the course (mowing greens, raking bunkers, directing golfers)
- Individual staff profiles (name, skill, morale, salary expectations)
- Training system (send staff to training → skill improves → costs money)
- Staff happiness affecting work quality (unhappy groundskeeper → condition degrades faster)
- Understaffing consequences (visible: unraked bunkers, overgrown rough, slow pace)
- Overstaffing waste (salary drain with diminishing returns)
- Staff scheduling (part-time for quiet seasons, full crew for summer/tournaments)

**Priority: HIGH** — Every tycoon game since Theme Park (1994) has had visible staff. This is the single most noticeable omission.

---

### 2. Rival Courses / Competition (HIGH)

**Genre standard:** RCT has competing parks in scenarios. TPH has competing hospitals and star ratings to beat. Golf Resort Tycoon had neighboring courses stealing your golfers.

**Current state:** The course exists in a vacuum. No other courses, no market share, no competitive pressure. Golfers appear from nothing and leave to nothing.

**What's missing:**
- 2-3 AI rival courses per map/scenario with their own ratings, fees, reputation
- Golfers choosing between your course and rivals based on value/rating/distance
- Rival actions (price wars, marketing blitzes, poaching your tournament tier)
- "Beat the competitor" scenario objectives
- Market share percentage visible in UI
- News ticker: "Rival Pines Golf Club just upgraded to 4 stars!"

**Priority: HIGH** — Without competition, there's no external pressure. The game becomes a zero-resistance sandbox after the initial money crunch.

---

### 3. Random Events / Crises (HIGH)

**Genre standard:** RCT has ride breakdowns, vandalism, vomiting guests. TPH has epidemics, VIP visits, emergency patients. Every tycoon game has "something just went wrong" moments.

**What's missing:**
- **Weather disasters:** Lightning strike damages a building, flooding closes a hole for 2 days, drought kills fairway condition
- **Equipment breakdowns:** Cart shed breaks down, driving range nets tear, irrigation system fails
- **PR events:** Golf magazine wants to review your course (temporary +50% pro spawns if rating > 4), negative review if poor
- **Celebrity/VIP visits:** Famous golfer wants to play — high satisfaction = huge reputation boost, low = reputation hit
- **Pest/wildlife:** Geese on the green (satisfaction penalty), moles damaging fairways (condition drop)
- **Vandalism/theft:** If security low, course damage overnight (requires a "security" staff type or building)
- **Economic events:** Local recession (-30% golfer spawns for a season), golf boom (+50% spawns)
- **Sponsorship offers:** "MegaCorp wants to sponsor Hole 7 for $5k/season — but you must rename it"

**Priority: HIGH** — Random events are what create stories. Right now every day feels the same except for weather.

---

### 4. Guest Needs System (MEDIUM-HIGH)

**Genre standard:** RCT guests have hunger, thirst, happiness, nausea, bathroom need. TPH patients have specific illnesses requiring specific rooms. SimGolf golfers got thirsty and hungry.

**Current state:** Golfers have satisfaction from scoring performance and pricing, but no physiological needs. Restrooms and snack bars give flat satisfaction bonuses but golfers don't actively *seek* them.

**What's missing:**
- Golfer needs: Thirst (increases over holes played, hot weather), Hunger (after 9 holes), Restroom (after 6+ holes), Rest (for retirees/beginners)
- Need-driven pathfinding to amenities between holes
- Need failure consequences: "I was dying of thirst out there" thought bubble → satisfaction penalty
- Temperature interaction: Hot weather = more thirst, more snack bar revenue
- Premium vs. budget amenities: Snack bar satisfies hunger cheaply, Restaurant satisfies hunger + adds satisfaction bonus

**Priority: MEDIUM-HIGH** — This directly generates demand for buildings. Right now buildings feel like checkbox items rather than responding to visible golfer suffering.

---

### 5. Scenario / Challenge Mode (MEDIUM-HIGH)

**Genre standard:** RCT has 50+ hand-crafted scenarios with win conditions. TPH has a campaign. SimGolf had career progression across courses.

**Current state:** Sandbox only with 3 difficulty presets (Easy/Normal/Hard). Milestones provide goals but no fail-states or structured progression.

**What's missing:**
- 15-20 hand-crafted scenarios with specific objectives:
  - "Reach 3-star rating in 30 days with only $20k"
  - "Host a Regional tournament on this swampy terrain"
  - "Turn this failing 9-hole into a profitable resort"
  - "Build a championship course on mountainous terrain"
- Star rating per scenario (bronze/silver/gold based on performance)
- Scenario unlock chains (beat Scenario 1 → unlock Scenario 2)
- Pre-built courses with problems to fix (bad layout, no amenities, debt)
- Time-limited challenges (not just sandbox with no end)

**Priority: MEDIUM-HIGH** — Sandbox is fine for creative players, but tycoon veterans expect structured challenges. This is what drives replayability in RCT and TPH.

---

### 6. Prestige / Late-Game Progression (MEDIUM)

**Genre standard:** TPH has hospital prestige levels, star targets, Kudosh currency for unlocks. RCT has park awards and scenario medals. Even idle games have prestige resets.

**Current state:** Reputation goes to 100, milestones complete, Championship tournament unlocks. Then what? No meta-progression, no prestige tiers, no "new game+" incentive.

**What's missing:**
- **Course prestige tiers** (like TPH hospital stars): Bronze → Silver → Gold → Platinum club status
- Each tier unlocks new buildings, terrain types, decoration options
- **Legacy bonuses:** Completing a course grants permanent bonuses to next course (e.g., "Pro Shop revenue +5% on all future courses")
- **Awards ceremony:** End-of-year awards (Best New Course, Most Profitable, Best Designed)
- **Hall of Fame:** Track best tournament scores, lowest rounds, most profitable days across all saves
- **Endgame crisis:** At 90+ reputation, the game should get *harder* — rivals target you, maintenance costs spike, golfer expectations rise. Staying at the top should require effort.

**Priority: MEDIUM** — This is what separates "I played for 2 hours" from "I played for 200 hours." The current game has no answer for "what do I do after the Championship?"

---

### 7. Visible Golfer Needs & Pathfinding (MEDIUM)

**Genre standard:** RCT guests walk paths, queue at rides, sit on benches, buy food. You can click any guest and see their thoughts, needs, and route. SimGolf golfers walked between holes.

**Current state:** Golfers teleport between holes. No walking animation between holes, no visible pathfinding, no queuing at amenities.

**What's missing:**
- Golfers walk cart paths between holes (or ride carts if Cart Shed is built)
- Visible queuing at Tee Box 1 when course is busy
- Golfers visiting amenities between holes (Pro Shop after round, Snack Bar at turn)
- "Following" a golfer — click to watch their full round with commentary
- Cart path routing matters: bad cart path layout = slow pace = lower Pace rating

**Priority: MEDIUM** — This is the "ant farm" appeal of tycoon games. Watching tiny people do things is half the fun.

---

### 8. Notifications / Advisor System (MEDIUM)

**Genre standard:** RCT has thought aggregation ("Most guests think the park is untidy"). TPH has an advisor popping up with tips. SimGolf had a caddie advisor.

**Current state:** Toast notifications exist, end-of-day summary is good, financial panel tracks trends. But no proactive advice system.

**What's missing:**
- **Advisor character** (e.g., a caddie or club manager) who pops up with context-sensitive tips:
  - "Your green fees are too high — golfers are leaving before teeing off"
  - "Hole 7 has a 78% bogey rate — consider widening the fairway"
  - "You haven't built a restroom — golfers are complaining"
  - "A Regional tournament is available — your course qualifies!"
- **Aggregated complaint tracking:** "Top 3 complaints this week: 1. Overpriced (23 golfers), 2. Slow pace (18), 3. Not enough holes (12)"
- **Heatmaps:** Where do golfers lose balls? Which holes are bottlenecks? Where do shots land?
- **What-if tools:** "If you lower green fee by $10, you'd attract 20% more golfers but lose $X revenue"

**Priority: MEDIUM** — TPH's advisor is a major quality-of-life feature. New players especially need guidance about what to do next.

---

### 9. Decorations & Theming (MEDIUM-LOW)

**Genre standard:** RCT has hundreds of scenery items (trees, flowers, fountains, statues, fencing, themed areas). TPH has wall decorations, posters, plants. Even SimGolf had flower beds and statues.

**Current state:** 4 tree types, 3 rock sizes, flower bed terrain, bench. That's it. No fencing, water features, signage, sculptures, or aesthetic items.

**What's missing:**
- **Fencing/hedges:** Define course boundaries visually
- **Water features:** Decorative fountains, ponds (not hazards — aesthetic)
- **Signage:** Hole markers, course entrance sign, sponsor banners
- **Sculptures/statues:** Decorative items that boost satisfaction in radius
- **Flower gardens:** More variety than single terrain type
- **Lighting:** Path lights, tee box markers (for dusk play)
- **Themed items per course theme:** Desert has cacti, Links has dune grass, Resort has palm trees

**Priority: MEDIUM-LOW** — Decorations don't affect core gameplay much, but they're what makes players feel ownership over their creation. The "it's MY course" factor.

---

### 10. Audio (CRITICAL BUT NON-GENRE)

**Genre standard:** Every game has audio. Period.

**Current state:** Complete silence. No swing sounds, no ball impacts, no ambient birds, no rain, no crowd murmur, no UI clicks, no music.

**Why it matters for tycoon feel:** Audio is how players *feel* activity. A bustling course with golfers chatting, clubs clinking, and birds chirping *feels* successful. Silence feels broken.

**Priority: CRITICAL** — This isn't a genre staple analysis point, but it needs to be said: the game will feel like a tech demo without audio regardless of how many features are added.

---

## Feature Gap Matrix

| Feature | RCT | TPH | SimGolf | GRT | OpenGolf | Gap? |
|---------|-----|-----|---------|-----|----------|------|
| Visible staff | Yes | Yes | Yes | Yes | **No** | CRITICAL |
| Staff management (hire/train/fire) | Yes | Yes | Partial | Yes | Abstract | HIGH |
| Guest needs (hunger/thirst/etc.) | Yes | Yes (illness) | Yes | Yes | **No** | HIGH |
| Random events/crises | Yes | Yes | Partial | Yes | **No** | HIGH |
| Rival competition | Scenario | Yes | **No** | Yes | **No** | HIGH |
| Scenario/campaign mode | Yes | Yes | Yes | Yes | **No** | HIGH |
| Guest pathfinding | Yes | Yes | Yes | Yes | **No** (teleport) | MEDIUM |
| Advisor/tips system | Partial | Yes | Yes (caddie) | Partial | **No** | MEDIUM |
| Prestige/meta-progression | Awards | Yes (Kudosh) | Career | Partial | **No** | MEDIUM |
| Awards/end-of-year | Yes | Yes | Yes | Yes | **No** | MEDIUM |
| Decorations variety | 100+ | 50+ | 20+ | 20+ | ~8 | MEDIUM-LOW |
| Audio | Yes | Yes | Yes | Yes | **No** | CRITICAL |
| Financial graphs/reports | Partial | Yes | Partial | Yes | Yes (7-day) | OK |
| Weather effects | Yes | No | No | Yes | Yes | OK |
| Seasonal calendar | No | No | No | Partial | Yes | GOOD |
| Tournament system | No | No | Yes | Yes | Yes | GOOD |
| Course rating system | No | No | Partial | Partial | Yes (deep) | EXCELLENT |
| Terrain/elevation tools | No | No | Yes | Partial | Yes | EXCELLENT |
| Golfer simulation depth | N/A | N/A | Good | Basic | Excellent | EXCELLENT |
| Milestones/achievements | Scenario goals | Kudosh | Career | Partial | Yes (26) | GOOD |
| Marketing system | No | Partial | No | Yes | Yes (5 ch.) | GOOD |
| Land expansion | Scenario-based | Yes | No | Yes | Yes | GOOD |
| Save/load | Yes | Yes | Yes | Yes | Yes (v2) | OK |

---

## Prioritized Implementation Roadmap

Based on genre impact, player retention, and implementation complexity.

### Phase 1 — "It Feels Like a Game" (Foundation)
1. **Audio system** — ambient, SFX, music. Non-negotiable.
2. **Random events** — 8-10 event types (weather disasters, VIP visits, equipment failures). Creates storytelling.
3. **Golfer needs** — Thirst/hunger/restroom drives amenity demand. Makes buildings matter.
4. **Advisor system** — Context-sensitive tips panel. Guides new players, surfaced useful data for veterans.

### Phase 2 — "It Feels Like a Tycoon Game" (Core Loops)
5. **Visible staff** — Sprites on course, patrol areas, individual stats.
6. **Staff training/morale** — Staff skill improves with training, degrades with low morale. Salary negotiation.
7. **Guest pathfinding** — Walk cart paths between holes. Visit amenities. Queue at tee boxes.
8. **Scenario mode** — 10 hand-crafted scenarios with star ratings and unlock chains.

### Phase 3 — "It Has Staying Power" (Retention)
9. **Rival courses** — 2-3 AI competitors per scenario. Market share, price wars.
10. **Prestige system** — Course tiers with unlock chains. Legacy bonuses across saves.
11. **Decorations expansion** — 30+ items (fencing, fountains, signage, themed props).
12. **Awards & Hall of Fame** — End-of-year ceremony, all-time records, course ranking.

### Phase 4 — "It's Complete" (Polish)
13. **Advanced analytics** — Heatmaps, flow visualization, what-if pricing tools.
14. **Golfer loyalty** — Repeat visitors, word-of-mouth, membership system.
15. **Dynamic pricing AI** — Suggested green fees based on demand curves.
16. **Multiple tee boxes** — Forward/middle/back tees per hole for different tiers.

---

## Comparison to Direct Competitors

### vs. SimGolf (2002)
- **OpenGolf wins:** Weather system, course rating depth, shot physics, terrain variety, seasonal calendar, marketing, milestones
- **SimGolf wins:** Playable golfer character, visible staff, guest pathfinding, audio, scenarios, social interactions between golfers, decorations, caddie advisor
- **Verdict:** OpenGolf has deeper *simulation* but SimGolf has deeper *tycoon gameplay*

### vs. Golf Resort Tycoon (2001)
- **OpenGolf wins:** Shot physics, weather/wind, course themes, terrain tools, save system, financial tracking
- **GRT wins:** Guest needs, rival courses, staff management, scenarios, audio, decorations, water features
- **Verdict:** OpenGolf is technically superior but GRT had more gameplay variety

### vs. RollerCoaster Tycoon (genre gold standard)
- **Shared strengths:** Terrain tools, weather, financial tracking, milestones
- **RCT has that OpenGolf lacks:** 100+ decorations, visible staff, guest needs, random events, scenarios, awards, guest pathfinding, audio, rival parks (scenario), thought aggregation
- **Verdict:** RCT sets the bar. OpenGolf needs Phase 1-2 features to reach RCT's baseline tycoon quality.

### vs. Two Point Hospital (modern standard)
- **Shared strengths:** Financial panel, seasonal content, milestones
- **TPH has that OpenGolf lacks:** Visible staff with training/morale, advisor, prestige/Kudosh meta-currency, rival hospitals, scenario campaign, room customization, VIP events, epidemic crises, deep analytics
- **Verdict:** TPH represents the modern tycoon expectations bar. OpenGolf needs Phase 1-3 to compete.

---

## Bottom Line

OpenGolf Tycoon has built the **hard part** — a golf simulation engine with real depth in shot physics, course rating, and weather. Most golf tycoon games never got the *golf* right. This one did.

What's needed now is the **tycoon wrapper**: visible staff mowing greens, golfers complaining about thirst, a rival course stealing your pros, a lightning strike closing Hole 12, and an advisor telling you your green fees are scaring off beginners. These are the systems that transform a simulation into a *game* — that create tension, narrative, and "one more day" compulsion.

The architecture (signal-driven EventBus, manager pattern, data-driven configs) is well-suited to support all of these additions. The foundation is sound. It just needs the walls and roof.
