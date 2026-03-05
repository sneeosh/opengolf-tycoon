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

---

## Visual Playtest — Building Sprite Assessment (2026-03-05)

### Test Setup
- Quick Start with all 8 building types placed (added Pro Shop, Restaurant, Driving Range, Cart Shed to Quick Start temporarily)
- Parkland theme, Normal difficulty
- Assessed sprites both as standalone files and in-game on terrain

### Building-by-Building Assessment

**Note:** The game uses a **high top-down** camera perspective. Trees, rocks, and terrain are all viewed from above with slight angle. Buildings should match this — primarily showing rooftops with a bit of the front wall visible, NOT full 3/4 isometric views.

#### 1. Clubhouse (clubhouse_1.png) — NEEDS IMPROVEMENT (perspective)
- Warm tan/yellow walls, brown roof, porch entrance — looks inviting
- Good detail level, stairs visible
- **Problem:** Uses a full 3/4 isometric perspective showing prominent side walls — this is more isometric than the game's high top-down style. You should mainly see the roof from above.
- Upgrade tiers (clubhouse_2, clubhouse_3) have the same perspective issue
- **Rating: 5/10** — Nice art, wrong perspective. Regenerate in high top-down view to match trees/rocks/terrain

#### 2. Pro Shop (pro_shop.png) — NEEDS IMPROVEMENT (perspective + style)
- Has "GOLF SHOP" signage, dark green/teal storefront look
- Bushes flanking the entrance are a nice touch
- **Problem:** Nearly front-facing perspective — neither top-down nor isometric. Inconsistent with everything.
- **Rating: 4/10** — Regenerate in high top-down view

#### 3. Restaurant (restaurant.png) — NEEDS IMPROVEMENT (perspective + colors)
- Dark brick building with warm orange-lit windows
- Chimney is a nice touch, lit windows add atmosphere
- **Problem 1:** Full 3/4 isometric perspective, same as clubhouse — too much side wall visible
- **Problem 2:** Dark color palette makes it look like a haunted house, not a golf course restaurant
- **Rating: 4/10** — Regenerate in high top-down view with lighter daytime color palette

#### 4. Snack Bar (snack_bar.png) — DECENT
- Red/white striped awning gives a clear "food stand" vibe
- Small and appropriate scale
- Perspective is close to correct — slightly angled top-down
- Could use more detail
- **Rating: 6/10** — Closest to correct perspective. Could improve detail.

#### 5. Driving Range (driving_range.png) — NEEDS IMPROVEMENT (content, not perspective)
- Top-down perspective is actually CORRECT for this game's art style
- **Problem:** Looks like a flat field/layout diagram rather than a recognizable building — needs covered hitting bays, stalls, netting visible from above
- The rectangular shape is fine but the interior detail makes it look like a sports field, not a driving range facility
- **Rating: 4/10** — Correct perspective, but regenerate with better building content (covered stalls, practice area from above)

#### 6. Cart Shed (cart_shed.png) — DECENT
- Small building with green roof and garage-style openings
- Identifiable as a vehicle storage building
- Perspective is moderate — not as extreme as clubhouse
- A bit dark/muddy in overall coloring
- **Rating: 6/10** — Acceptable, could benefit from brighter colors and visible golf carts from above

#### 7. Restroom (restroom.png) — DECENT
- Small building with dark blue roof
- Appropriate size for a restroom facility
- Perspective is moderate — mostly top-down
- Slightly dark color scheme
- **Rating: 6/10** — Functional, minor improvements possible

#### 8. Bench (bench.png) — GOOD
- Simple wooden park bench design
- Appropriate scale — small, decorative
- Top-down view works well for this object
- **Rating: 7/10** — Works well, no changes needed

### Overall Visual Issues

#### VISUAL-1: Perspective Inconsistency (PRIMARY ISSUE)
- Game uses **high top-down** camera. Trees, rocks, terrain all match this.
- Clubhouse, Restaurant, Pro Shop use 3/4 isometric views showing prominent walls — too much side visible
- Driving Range uses correct top-down but has wrong content
- **Recommendation:** Regenerate Clubhouse, Restaurant, Pro Shop in high top-down view (primarily showing rooftops). Keep warm color palettes but fix the camera angle.

#### VISUAL-2: Dark Building Palettes
- Restaurant, Cart Shed, and Restroom use dark color palettes
- Golf course buildings should feel light, airy, professional
- **Recommendation:** Use lighter base colors (whites, light grays, warm tans) like rooftops seen from above

### Tree & Rock Assessment

#### Trees — GOOD
- Oak, Pine, Birch, Maple, Bush, Palm sprites all look great
- Varied sizes and shapes provide natural visual diversity
- Good isometric perspective, nice detail levels
- Trees render well on terrain at game zoom
- The green color palette across tree types provides variety without clashing
- **Rating: 8/10** — One of the strongest visual elements

#### Rocks — GOOD
- Small, Medium, Large variants with good gradation
- Gray stone color with green grass base circles
- Natural-looking shapes with appropriate pixel detail
- Known issue from previous sessions: background squares slightly visible (already documented)
- **Rating: 7/10** — Look good, minor background artifact issue

### Terrain Assessment

#### Terrain — GOOD
- Procedural tileset renders well with distinct terrain types
- Fairways show mowing stripe patterns — excellent detail
- Greens are clearly distinct from fairways
- Water tiles (blue) are highly visible and read well
- Bunkers (sandy yellow) are identifiable
- Rain overlay effect works well — visible streaks without obscuring gameplay
- Day/night tinting visible (orange line for sunset transition)
- **Rating: 7/10** — Solid overall, minor flower bed rendering could be improved

### Golfer Assessment

- Golfers are very small at default zoom but have distinct colored sprites
- AnimatedSprite2D integration working (confirmed GolferSprite nodes on all golfers)
- 25+ golfers visible on course during active play
- Hard to assess individual golfer detail at game zoom — would benefit from slightly larger sprites or zoom-to-golfer feature
- **Rating: 6/10** — Functional but golfers are hard to see at default zoom

### Priority Recommendations
1. **HIGH: Regenerate Clubhouse** — Fix from 3/4 isometric to high top-down (mainly rooftop visible). Keep warm colors.
2. **HIGH: Regenerate Pro Shop** — Fix from front-facing to high top-down view
3. **HIGH: Regenerate Restaurant** — Fix perspective to high top-down + brighten colors
4. **MEDIUM: Regenerate Driving Range** — Keep top-down perspective but improve content (covered hitting bays, not a flat field)
5. **LOW: Brighten Cart Shed and Restroom** — Use lighter color palettes
