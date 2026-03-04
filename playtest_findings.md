# Playtest Findings — 9-Hole Woodland Course

## Test Setup
- Quick Start with 9-hole "Whispering Pines" course (Par 36, 3220 yds)
- Woodland theme, Normal difficulty, $25k starting cash

## Already Fixed (in current uncommitted changes)
- Bottom bar: dark background, visual separators, removed duplicate End Day button
- UI: migrated hardcoded colors/font sizes to UIConstants across financial_panel, marketing_panel, tournament_panel, top_hud_bar
- Terrain toolbar: removed emoji icons from section headers (rendering issues)
- Quick Start: upgraded from 3-hole to full 9-hole course with buildings

## Bugs Found

### BUG-1: Zero-indexed hole numbers in displays
- Feed shows "Hole #0" instead of "#1", "Hole #2" instead of "#3"
- Scorecard Best Scores section also uses 0-indexed: "#0", "#1"
- **Status: NOT FIXED**

### BUG-2: Course Records showing impossible scores
- "Lowest Round: 4 (-32) by Avid Scottie" — a score of 4 on par 36 is impossible
- Likely counting partial rounds (golfers who quit early) as full round scores
- **Status: NOT FIXED**

### BUG-3: Golfers not completing all 9 holes
- "Weekend Jon - Score: 22 (+6) - Paid: $40 (4 holes)" — only played 4 of 9
- Multiple golfers quitting mid-round, reducing green fee revenue
- May be intentional (needs/patience) but seems too frequent
- **Status: NEEDS INVESTIGATION**

### BUG-4: Amenities revenue $0
- Clubhouse, 2 restrooms, snack bar, 3 benches all placed — zero amenity income
- Either proximity revenue isn't working or buildings need golfer visits to generate
- **Status: NEEDS INVESTIGATION**

## Economic Tuning Issues

### ECON-1: Terrain maintenance costs crushing ($5,225/day)
- 9-hole course terrain costs $5,225/day vs $1,710 green fee revenue (3x costs)
- With ~1000+ painted tiles across 9 holes, linear per-tile costs scaled crushingly
- **Status: FIXED** — Added sqrt scaling to terrain costs: `sqrt(raw) * 20`
  - Per-tile costs: Fairway $1, Green $2, Tee $1, Bunker $1, Water $1
  - Seasonal modifiers softened (summer 1.4→1.2)
  - 9-hole terrain now ~$558/day (was $5,225). Full-day profit ~$550+

### ECON-2: Green fee capped too low
- $10/hole, $90/round at max — leaves no pricing headroom
- 19 golfers/day × partial rounds = only $1,710 revenue
- **Recommendation:** Raise max green fee or make it scale with course rating

### ECON-3: Milestones masking losses
- Cash went UP from $34,210 to $41,100 despite -$4,110 daily loss
- Milestone bonuses ($2k+) are hiding the unsustainable economics
- Once milestones dry up, player will hit a wall

## UX Issues

### UX-1: Financial panel not discoverable
- Only accessible by clicking money amount in top HUD bar
- No hotkey, no bottom bar button
- **Recommendation:** Add hotkey (F) and/or bottom bar button

### UX-2: Marketing panel missing green fee controls
- Expected green fee slider in Marketing; it's only in Financial panel
- **Recommendation:** Either add green fee to Marketing or make it more prominent

### UX-3: Course rating subcategories unexplained
- Condition: 2.1, Pace: 2.0 dragging overall to 3.1 stars
- Player has no guidance on how to improve these
- **Recommendation:** Add tooltips explaining what affects each subcategory

## Scorecard Observations
- Rating: 38.8, Slope: 129 (reasonable for mixed-skill golfers)
- Average scores: +7.8 over par (43.8 vs 36) — slightly high but acceptable
- Par 3s averaging bogey (4.0), Par 5s averaging par or +0.8
- Par 4s consistently 1+ over par — may need slight distance tuning

## Session Status
- Observed through Day 2 complete, Day 3 partial
- Rep reached 100% by Day 2 (very fast — may need tuning)
- Weather transitions working (Sunny → Overcast → Light Rain)
- Golfer groups spawning and progressing through holes correctly
