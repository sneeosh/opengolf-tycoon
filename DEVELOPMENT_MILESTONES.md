# SimGolf Development Plan

## Current Implementation Status

The game currently supports:
1. Placing terrain objects of different types
2. Creating holes and greens
3. Tracking those holes in the hole register
4. Adding buildings
5. Adding trees (4 types: Oak, Pine, Maple, Birch) and decorative rocks (3 sizes)
6. Budget tracking - adding objects subtracts from overall budget
7. Golfer AI framework with basic shot calculation
8. **Ball physics and visualization system** - Arc trajectory for full shots, ground roll for putts, terrain-based physics
9. **Golfer visual rendering** - Animated golfers with walking/swinging animations and score tracking
10. **Hole visualization system** - Visual flags, connecting lines, hole info labels with par and yardage
11. **Play/Pause system with golfer spawning** - Game mode switching with validation and automatic golfer spawning
12. **Complete shot system with club types** - Driver, Iron, Wedge, Putter with terrain modifiers
13. **Intelligent golfer AI** - Smart target selection, hazard avoidance, personality traits, terrain-aware pathfinding
14. Intuitive camera controls with arrow keys moving in visual direction
15. **Green fee system** - Configurable green fees ($10-$200), golfers pay on spawn with floating notification
16. **Dynamic golfer spawning** - Groups spawn when first tee is clear, with group sizes weighted by green fee
17. **Turn-based group play** - Groups play holes turn-based with tee order and "away" rules, par 3 safety holds, deadlock prevention
18. **Calibrated game time** - 1 real minute = 1 game hour at normal speed; FAST (2x) and ULTRA (4x) scale proportionally
19. **Hole management** - Open/close holes, delete holes with renumbering, golfers skip closed holes
20. **Undo/Redo in build mode** - Ctrl+Z/Ctrl+Y for terrain painting and entity placements with cost refund
21. **Green fee UI controls** - In-game +/- buttons to adjust green fees during play
22. **Water hazard visual overlays** - Animated shimmer on water tiles, hole difficulty rating system
23. **Bunker visual effects** - Sand spray particles on landing, stipple overlay on bunker tiles
24. **OB detection fix & markers** - Ball correctly enters OUT_OF_BOUNDS state, white stake markers at boundaries
25. **Wind system** - Per-day wind with direction/speed, club-sensitive displacement, AI compensation, HUD indicator
26. **Terrain elevation system** - Raise/lower tools, always-visible elevation shading with contour lines, uphill/downhill shot effects, slope-influenced ball roll
27. **Golfer feedback system** - Thought bubbles for reactions (score, hazards, pricing), FeedbackManager for aggregate tracking, satisfaction in end-of-day summary
28. **Building effects system** - Proximity-based revenue from pro shop, restaurant, snack bar; satisfaction from restrooms and benches
29. **Clubhouse upgrades** - 3-tier upgrade system with revenue/satisfaction bonuses, clickable building info panels
30. **Cart path speed boost** - Golfers walk 50% faster on cart paths with pathfinding preference
31. **Mini-map navigation** - Course overview map with click-and-drag navigation, shows golfers/buildings/holes, toggle with M key
32. **Financial dashboard** - Detailed income/expense breakdown toggled by clicking money display
33. **Hole statistics panel** - Per-hole stats including average score, best score, score distribution
34. **Selection indicator** - Bottom bar shows currently selected tool with color coding
35. **Weather system** - Dynamic weather (sunny to heavy rain) with rain overlay, affects golfer spawn rates, sky tinting, HUD indicator

---

## PRIORITY 1: Critical Bugs & Core Playability

### [X] Allow for planting trees
**STATUS: COMPLETE** - Tree placement system implemented with 4 tree types (Oak, Pine, Maple, Birch).

### [X] Fix Critical Bugs Blocking Gameplay
**STATUS: COMPLETE** - All critical bugs resolved:
1. ✅ Fixed tree placement crash (renamed Tree class to TreeEntity to avoid conflict with Godot's built-in Tree UI control)
2. ✅ Rock placement functionality working (3 sizes: small, medium, large)
3. ✅ Arrow key camera movement now moves in visual screen direction instead of isometric coordinates
4. Tee/green placement validation working correctly

### [X] Ball Physics & Visualization System
**STATUS: COMPLETE** - Full ball visualization with realistic physics:
- ✅ Ball entity with visual representation (white ball with shadow, motion blur)
- ✅ Parabolic arc trajectory animation (height and duration scale with distance)
- ✅ Terrain-aware ball physics (greens roll 8 tiles, fairways 5 tiles, rough 2 tiles)
- ✅ Ball position tracking on course after each shot
- ✅ Terrain-based rolling physics with different speeds for green/fairway/rough
- ✅ Visual feedback for hazards (water splash effect, OB grayed out)
- ✅ Ball state management (AT_REST, IN_FLIGHT, ROLLING, IN_WATER, OUT_OF_BOUNDS)
- ✅ BallManager handles all ball instances and connects to golfer shot system
- ✅ Automatic ball visibility management (hidden between holes, visible during play)
- ✅ Golfers watch ball flight before walking (swing → watch → walk sequence)
- ✅ Putts roll along the ground instead of flying in an arc (club-aware animation)

### [X] Golfer Visual Rendering
**STATUS: COMPLETE** - Golfers fully visible with animations and info display:
- ✅ Human-like visual representation (head, body, arms, legs, shadow)
- ✅ Positioned correctly on isometric grid
- ✅ Walking animation with bobbing motion and arm swinging
- ✅ Swing animation with backswing, downswing, and follow-through
- ✅ Name label displays golfer's name
- ✅ Score label shows current score relative to par (E, +2, -1, etc.) and hole number
- ✅ State-based color changes (idle, walking, preparing, swinging, watching, putting, finished)
- ✅ Smooth animation transitions using tweens

### [X] Hole Tracker & Visual Connection
**STATUS: COMPLETE** - Full hole visualization system with flags and dynamic information:
- ✅ Visual line connects tee box to green with semi-transparent white line
- ✅ Flag entity marks hole position on green with red flag and pole
- ✅ Hole number displayed on flag
- ✅ Info label shows hole number, par, and yardage at midpoint between tee and green
- ✅ Par automatically calculated based on distance (Par 3: <250yds, Par 4: 250-470yds, Par 5: >470yds)
- ✅ Yardage calculated using 15 yards per tile conversion
- ✅ Flag can be repositioned on multi-tile greens (validates green terrain)
- ✅ HoleManager coordinates all hole visualizations
- ✅ Holes automatically visualized when created through EventBus integration
- ✅ Hole highlighting system for selection feedback

---

## PRIORITY 2: Core Golf Gameplay

### [X] Implement Play/Pause System
**STATUS: COMPLETE** - Full game mode management with play/pause controls:
- ✅ Game starts in BUILDING mode (paused)
- ✅ Validation requires at least one complete hole before allowing play
- ✅ Play/Pause/Fast speed controls with proper state management
- ✅ Visual game state display ("🔨 BUILDING MODE" / "▶ PLAYING" / "⏸ PAUSED" / "⏩ FAST")
- ✅ Button states update based on mode (disabled when not applicable)
- ✅ "🔨 Build" button allows returning from simulation to building mode
- ✅ Active speed button highlighted with visual feedback
- ✅ Initial golfer spawning (1-4 players) when entering play mode
- ✅ Notifications for state changes and validation errors
- ✅ Calibrated game time speed: 1 real minute = 1 game hour at NORMAL, 30s at FAST, 15s at ULTRA

### [X] Golfer Spawn & Management System
**STATUS: COMPLETE** - Full group spawning with dynamic tee-time management:
- ✅ Spawn golfers in groups of 1-4 players randomly when game starts
- ✅ Dynamic spawning based on first tee availability (new group spawns when tee is clear)
- ✅ Minimum 10-second cooldown between group spawns
- ✅ Group size weighted by green fee (budget courses = more singles, premium = more foursomes)
- ✅ Track active golfers on course (max 8 concurrent)
- ✅ Remove golfers after completing round (with 1-second delay for visibility)
- ✅ Turn-based play within groups (tee order by ID, then "away" rule for subsequent shots)
- ✅ Landing zone safety checks prevent shooting into groups ahead (10-tile radius)
- ✅ Par 3 tee shot hold: groups wait until earlier groups fully clear the hole
- ✅ Deadlock prevention: only groups ahead (lower group_id) can block, preventing circular waits
- ✅ Reputation gain when golfers finish rounds
- ⏳ Start golfers near clubhouse (currently spawn at tee box)
- ⏳ Course fun rating should bias for more foursomes

### [X] Complete Golfer Shot System
**STATUS: COMPLETE** - Full club-based shot mechanics with terrain modifiers:
- ✅ **Driver**: Long distance (200-300 yards), 70% base accuracy, driving skill primary
- ✅ **Iron**: Medium distance (100-200 yards), 85% base accuracy, accuracy skill primary
- ✅ **Wedge**: Short distance (20-100 yards), 95% base accuracy, great from sand
- ✅ **Putter**: Green only (0-40 yards), 98% base accuracy, putting skill based
- ✅ Club selection AI based on distance and terrain
- ✅ Shot calculations use appropriate skill stats per club type
- ✅ Lie type affects accuracy (rough: -25%, bunker: -40-60%, trees: -70%)
- ✅ Terrain affects distance (rough: -15%, bunker: -25%, trees: -40%)
- ✅ Short game accuracy boost: distance-based floor for wedge shots matches real amateur averages (20yds ~7yd error, 100yds ~20yd error)
- ✅ Putt accuracy floor: short putts 95% minimum, long putts 75% minimum (prevents wildly missed short putts)
- ✅ Double par pickup rule: golfers pick up after 2x par strokes to prevent infinite loops
- ✅ Wind effects on ball flight (implemented in P3)

### [X] Golfer AI & Path Finding
**STATUS: COMPLETE** - Intelligent shot selection and terrain-aware navigation:
- ✅ Evaluates multiple potential landing zones and scores each
- ✅ Strongly prefers fairways (100pts) over rough (30pts) and heavily penalizes hazards
- ✅ Avoids water (-1000pts) and out of bounds (-1000pts) at all costs
- ✅ Tree collision detection - will NOT take shots that fly through trees (-2000pts)
- ✅ Considers nearby hazards when evaluating safety of landing zone
- ✅ Personality traits: aggression (0.0-1.0) affects risk/reward decisions
- ✅ Cautious players (low aggression) heavily penalize risky shots near hazards
- ✅ Aggressive players willing to take riskier shots for better positioning
- ✅ Green reading for putts: aims 5-15% past hole ("never up, never in")
- ✅ Putting skill affects distance control on greens
- ✅ Terrain-aware pathfinding: golfers walk around water obstacles
- ✅ Cannot walk through water or out of bounds
- ✅ Hazard penalty handling: water (lateral drop) and OB (stroke and distance) with correct ball reset
- ✅ Improved accuracy system: Higher skill levels (0.5-0.9), 60% reduced error spread
- ✅ Straighter shots: ±3° angle variance (down from ±8.5°) for consistent ball striking
- ✅ Forward progress enforcement: 500pt penalty for shots that don't advance toward hole
- ✅ Strong distance preference: 4x penalty multiplier for distance from hole
- ✅ Debug output shows golfer personality on spawn
- ⏳ Prefer walking on paths (future enhancement)
- ⏳ More sophisticated A* pathfinding (future enhancement)

### [X] Hole Open/Close Management
**STATUS: COMPLETE** - Full hole management with UI controls:
- ✅ UI toggle button to mark holes as open or closed
- ✅ Delete button to remove holes from course (with renumbering)
- ✅ Closed holes skipped in golfer play rotation
- ✅ Closed holes dimmed on course visualization
- ✅ Requires at least one open hole to start playing
- ✅ Cannot delete holes during simulation

### [X] Undo/Redo in Build Mode
**STATUS: COMPLETE** - Full undo/redo system for build mode actions:
- ✅ Ctrl+Z to undo, Ctrl+Y / Ctrl+Shift+Z to redo
- ✅ Terrain painting strokes grouped as single undo action (mouse down → mouse up)
- ✅ Entity placements (trees, buildings, rocks) tracked and undoable
- ✅ Cost refunded on undo, re-deducted on redo
- ✅ 50-action undo stack limit
- ✅ Only available in build mode

### [X] Green Fee & Revenue System
**STATUS: COMPLETE** - Full green fee system with UI controls:
- ✅ Golfers pay green fee on spawn
- ✅ Green fee configurable ($10-$200, default $30)
- ✅ Floating "+$XX" payment notification appears above golfer's head
- ✅ Green fee affects group size distribution (higher fees attract foursomes)
- ✅ Revenue tracked in budget system
- ✅ UI +/- buttons to adjust green fee during gameplay
- ⏳ Golfer traffic varies based on course rating and difficulty (deferred to P6)
- ⏳ Payment happens at clubhouse (deferred to P4)

---

## PRIORITY 3: Terrain & Course Design Features

### [X] Water Hazard Placement Tools
**STATUS: COMPLETE** - Water hazard visual enhancements, difficulty rating, and penalty enforcement:
- ✅ Pond placement tool (brush-based painting) - already existed
- ✅ Lake/river creation with connected tiles (flood-fill detection in terrain_grid)
- ✅ Visual water animation (animated shimmer overlay on water tiles)
- ✅ Water affects hole difficulty rating (DifficultyCalculator system)
- ✅ Difficulty rating displayed in hole info labels
- ✅ Difficulty auto-recalculates when terrain changes near holes
- ✅ Water penalty enforcement: 1 penalty stroke, lateral drop near hazard no closer to hole
- ✅ Drop position finder searches expanding rings for best playable terrain
- ✅ Ball visual resets to drop position via hazard_penalty EventBus signal
- ✅ Golfer walks to drop position instead of into water

### [X] Sand Trap & Bunker Placement Tools
**STATUS: COMPLETE** - Bunker visual enhancements:
- ✅ Sand trap placement tool (brush-based painting) - already existed
- ✅ Visual sand spray particle effects (SandSprayEffect on bunker landing)
- ✅ Visual grain/stipple overlay on bunker tiles (BunkerOverlay)
- ✅ Bunker landing detection in ball physics (ball_landed_in_bunker signal)

### [X] Wind Effects on Ball Flight
**STATUS: COMPLETE** - Full wind system with visual feedback and AI compensation:
- ✅ Wind state management (direction in radians, speed 0-30 mph)
- ✅ Wind changes on day change with hourly drift
- ✅ Club sensitivity: Driver 1.0x, Iron 0.7x, Wedge 0.4x, Putter 0.0x (putts exempt)
- ✅ Headwind reduces distance up to -15%, tailwind increases up to +10%
- ✅ Crosswind pushes ball laterally based on perpendicular component
- ✅ Visual wind drift during ball flight animation
- ✅ AI wind compensation: skilled golfers aim upwind more accurately (accuracy * 0.7 factor)
- ✅ Wind indicator HUD widget with rotating arrow, compass text, color-coded speed

### [X] Out of Bounds Areas
**STATUS: COMPLETE** - OB visual markers, detection, and penalty enforcement:
- ✅ OB painting tool in terrain toolbar
- ✅ OB markers and boundary painting (white stakes with red caps at OB edges)
- ✅ OB landing detection in ball.gd (ball state changes to OUT_OF_BOUNDS)
- ✅ Stroke and distance penalty enforcement (golfer replays from previous position + 1 penalty stroke)
- ✅ OB boundary tile detection helper (get_boundary_tiles in terrain_grid)

### [X] Terrain Elevation System
**STATUS: COMPLETE** - Per-tile elevation with tools, visuals, and gameplay effects:
- ✅ Per-tile integer elevation (-5 to +5, each unit ~10 feet)
- ✅ Raise/Lower terrain tools with brush painting (integrates with existing brush system)
- ✅ Visual elevation shading overlay (lighter = higher, darker = lower)
- ✅ Elevation numbers displayed when elevation tool is active
- ✅ Uphill shots shorter, downhill shots longer (~3% per elevation unit, clamped 0.75-1.25)
- ✅ Ball roll influenced by slope direction (downhill +30% roll, uphill -30% roll)
- ✅ Putt break from slope (ball breaks toward lower side on greens)
- ✅ Undo/redo support for elevation changes
- ✅ Elevation shown in coordinate label when non-zero
- ✅ Elevation data serialized/deserialized for save/load
- ✅ Always-visible elevation tinting (alpha 0.15 passive, 0.2 when tool active)
- ✅ Contour lines at elevation boundaries for topographic map effect

---

## PRIORITY 4: Save/Load & Essential UX

### [~] Save/Load System
**STATUS: PARTIAL** - Core save/load working, golfer persistence deferred:
- ✅ Save course layout (terrain tiles, elevation data)
- ✅ Save entities (trees, buildings, rocks)
- ✅ Save hole configurations (tee/green/flag positions, par, open/closed state)
- ✅ Save economy state (money, reputation, green fee)
- ✅ Save day progress (current day, current hour)
- ✅ Save wind state (direction, speed)
- ✅ Auto-save at end of each day
- ✅ Manual save with named slots
- ✅ Load from save menu
- ⏳ Golfers NOT persisted - cleared on load, respawn when simulation resumes
- ⏳ Full mid-action golfer state persistence (see Future Enhancements below)

### [] Full Mid-Action Golfer State Persistence (Future Enhancement)
_Deferred until core gameplay loop is complete. Currently, golfers are cleared on load and respawn naturally._
- Persist golfer position, state machine state, current hole, stroke count
- Persist ball position for each golfer
- Handle mid-flight ball state (either complete flight before save, or persist trajectory)
- Restore golfer-to-ball associations correctly
- Validate golfer state against course state on load (handle deleted holes, terrain changes)
- This is complex because golfers can be in various mid-action states (walking, preparing shot, swinging, watching ball flight)

### [X] Day/Night Cycle & Course Closing
**STATUS: COMPLETE** - Full day/night visual system with course hours:
- ✅ Visual dimming as evening approaches (DayNightSystem with CanvasModulate)
- ✅ Golfers finish current hole and leave at closing time (8 PM)
- ✅ New day begins at course open (6 AM)
- ✅ Day transition via end-of-day summary screen

### [X] End-of-Day Summary
**STATUS: COMPLETE** - Daily statistics panel shown at end of each day:
- ✅ Revenue earned today (green fees collected)
- ✅ Number of golfers served
- ✅ Notable scores (hole-in-ones, eagles, birdies)
- ✅ Average score to par
- ✅ Daily profit/loss (revenue - operating costs)
- ✅ "Continue to Day X" button advances to next morning

### [X] Golfer Feedback System
**STATUS: COMPLETE** - Thought bubble reactions and satisfaction tracking:
- ✅ ThoughtBubble UI component with sentiment colors (positive/negative/neutral)
- ✅ FeedbackTriggers system with 12 trigger types and probability-based firing
- ✅ Score-based reactions (hole-in-one, birdie, bogey, etc.)
- ✅ Hazard reactions (water, bunker)
- ✅ Price sensitivity reactions (overpriced, good value)
- ✅ Course satisfaction at end of round
- ✅ FeedbackManager autoload tracks aggregate daily feedback
- ✅ End-of-day summary shows satisfaction percentage and top feedback

---

## PRIORITY 5: Economy & Satisfaction Loop

### [X] Operating Costs
**STATUS: COMPLETE** - Daily operating costs with itemized breakdown:
- ✅ Terrain maintenance costs based on tile types
- ✅ Base operating cost ($50 + $25 per hole)
- ✅ Staff wages ($10 per hole)
- ✅ Itemized breakdown shown in end-of-day summary
- ✅ Costs deducted at end of each day before summary

### [X] Golfer Satisfaction & Course Rating
**STATUS: COMPLETE** - 1-5 star course rating system:
- ✅ Condition rating based on premium terrain in play corridors
- ✅ Design rating based on par variety and hole count
- ✅ Value rating based on green fee vs reputation
- ✅ Pace rating based on bogey ratio (proxy for slow play)
- ✅ Overall rating displayed in end-of-day summary with breakdown
- ✅ Higher ratings increase golfer spawn rate

### [X] Golfer Types & Skill Tiers
**STATUS: COMPLETE** - Four golfer tiers with tier-based mechanics:
- ✅ Beginner, Casual, Serious, Pro skill tiers
- ✅ Tier selection based on course rating, green fee, and reputation
- ✅ Tier-based skill generation (Beginners: 0.3-0.5, Pros: 0.85-0.98)
- ✅ Tier-based reputation gain (Beginner: +1, Pro: +10, doubled if under par)
- ✅ End-of-day summary shows tier breakdown with color coding

### [X] Course Records & Notable Events
**STATUS: COMPLETE** - Course records tracking with celebrations:
- ✅ Track lowest round (course record)
- ✅ Track total hole-in-ones with golfer names
- ✅ Track best score per hole
- ✅ Gold particle burst celebration for hole-in-ones
- ✅ Records persist through save/load
- ✅ record_broken signal for notifications

---

## PRIORITY 6: Buildings & Facilities

### [X] Clubhouse Upgrade System
**STATUS: COMPLETE** - 3-tier clubhouse upgrade system:
- ✅ Click on clubhouse opens building info panel
- ✅ Level 1: Basic Clubhouse (starting)
- ✅ Level 2: Clubhouse with Pro Shop ($8,000) - +$15/golfer, +5% satisfaction
- ✅ Level 3: Full Service Clubhouse ($15,000) - +$40/golfer, +10% satisfaction
- ✅ Visual upgrades at each level (shop window, outdoor seating)
- ✅ Revenue and satisfaction applied when golfers finish round

### [X] Cart Paths
**STATUS: COMPLETE** - Cart path terrain with speed boost:
- ✅ Cart Path terrain type (uses existing PATH terrain)
- ✅ 1.5x speed modifier for golfers walking on paths
- ✅ Pathfinding prefers cart paths when available
- ✅ Visual distinction (tan/gray color)

### [X] Building Revenue & Satisfaction Effects
**STATUS: COMPLETE** - Proximity-based building effects:
- ✅ Pro Shop: $15/golfer within 8-tile radius
- ✅ Restaurant: $25/golfer within 8-tile radius
- ✅ Snack Bar: $5/golfer within 5-tile radius
- ✅ Restroom: +5% satisfaction within 8-tile radius
- ✅ Bench: +2% satisfaction within 3-tile radius
- ✅ Golfers track visited buildings (revenue only triggers once per round)
- ✅ Building revenue shown in end-of-day summary (separate from green fees)

### [X] Building Placement Improvements
**STATUS: COMPLETE** - Better building placement UX:
- ✅ Unique buildings (clubhouse) can only be placed once
- ✅ Grey out unique buildings in selection dialog if already placed
- ✅ Prevent placing buildings on top of other buildings
- ✅ Clear building selector after successful placement
- ✅ Error messages for placement failures

### [] Golfer Needs System (Future Enhancement)
- Add thirst, hunger, fatigue stats to golfers
- Needs increase over time during round
- Buildings satisfy specific needs (snack bar = hunger, restroom = bladder)
- Golfers with unmet needs have lower satisfaction
- Encourages strategic building placement along course

---

## PRIORITY 7: UI/UX Improvements

### [X] Course Overview Map
**STATUS: COMPLETE** - Mini-map with navigation and course visualization:
- ✅ Mini-map in bottom-left corner showing terrain colors
- ✅ Hole locations displayed (tee=circle, green=square)
- ✅ Buildings shown as rectangles
- ✅ Active golfers shown as moving red dots
- ✅ Camera viewport indicator rectangle
- ✅ Click-to-navigate camera movement
- ✅ Click-and-drag for smooth panning
- ✅ Toggle visibility with M key

### [X] Financial Dashboard
**STATUS: COMPLETE** - Detailed financial panel toggled by clicking money display:
- ✅ Click money label to toggle detailed panel
- ✅ Current balance display
- ✅ Today's revenue breakdown (green fees + amenities)
- ✅ Today's costs breakdown (terrain, base, staff)
- ✅ Today's profit/loss calculation
- ✅ Yesterday's comparison with trend indicator
- ✅ Course reputation and golfers served
- ✅ Scrollable content with close button

### [X] Information Overlays
**STATUS: COMPLETE** - Detailed information panels for game elements:
- ✅ Building info panels (implemented in P6)
- ✅ Hole statistics panel with detailed stats
- ✅ Par, yardage, difficulty rating display
- ✅ Average score and best score per hole
- ✅ Score distribution (birdies, pars, bogeys, etc.)
- ✅ Statistics persist across days (fixed index mismatch)
- ✅ Scrollable content with close button

### [X] Selection Indicator
**STATUS: COMPLETE** - Visual feedback for current tool selection:
- ✅ Bottom bar displays currently selected tool
- ✅ Color-coded by tool type (terrain, placement, elevation)
- ✅ Updates in real-time as tools are switched
- ✅ Shows placement mode (tree type, rock size, building name)

### [X] Panel Overflow Fixes
**STATUS: COMPLETE** - All panels properly handle content overflow:
- ✅ Financial panel with scroll container and close button
- ✅ End-of-day summary with scroll container, fixed title/button
- ✅ Hole stats panel with scroll container and close button
- ✅ Window display scaling fixed (viewport stretch mode)

### [X] Undo Improvements
**STATUS: COMPLETE** - Better undo grouping for complex operations:
- ✅ Tee box placement (9 tiles) undoes as single action
- ✅ Green placement (25 tiles) undoes as single action

### [] Build Mode Categorization (Deferred)
_Moved to Future Ideas - basic tool selection works well enough for now_
- Categorized terrain menu with collapsible sections
- Quick-select hotkeys (1-9)
- Hover tooltips for terrain types

### [] Tutorial & Help (Deferred)
_Moved to Future Ideas - low priority until core features complete_
- First-time player guidance
- Tooltip hints for UI elements
- Help menu with tips

---

## PRIORITY 8: Advanced Features

### [X] Weather System
**STATUS: COMPLETE** - Dynamic weather with gameplay effects:
- ✅ Weather conditions (sunny, partly cloudy, cloudy, light rain, rain, heavy rain)
- ✅ Rain reduces golfer spawn rate (30-100% based on severity)
- ✅ Visual rain overlay with animated drops and splashes
- ✅ Weather-based sky tinting (darker/grayer during bad weather)
- ✅ Weather indicator in HUD showing current conditions
- ✅ Weather changes hourly with realistic patterns
- ✅ Weather state saved/loaded
- ✅ Course stays open regardless of weather

### [] Tournament Mode
- Host tournaments on your course
- Add different tiers of tournament with course rating, yardage, and hole # requirements. more prestigious tournaments have more stringient requirements.
- Prize money system (course pays out, earns prestige)
- Attracts pro golfers and media attention
- Reputation boost for hosting

### [] Course Difficulty Rating
- Automatic slope/difficulty rating based on hole design
- Rating displayed to player
- Affects which golfer tiers are attracted
- Higher difficulty with good design = more prestige

---

## PRIORITY 9: Polish & Content

### [] Visual & Audio Polish
- Custom sprites for all terrain types
- Animated water and flags
- Ambient sounds (birds, wind, golf shots)
- Music tracks for different game states
- Particle effects (sand spray, water splash)

### [] Additional Terrain Objects
- Flower beds and gardens
- Bridges over water
- Cart paths (visual and functional)
- Additional decorative objects

### [~] Zoom & Scale Tuning
**STATUS: PARTIAL** - Yardage scale adjusted, zoom polish remaining:
- ✅ Yardage scale tripled (5 → 15 yards/tile) for more realistic hole yardages
- ✅ All club distances, ball rolling, safety radii, and thresholds scaled to match
- ⏳ Adjust default zoom for realistic yardage
- ⏳ Smooth zoom transitions
- ⏳ Remember zoom preference

---

## PRIORITY 10: Performance & Optimization

### [] Performance Optimization
- Optimize rendering for large courses (18+ holes)
- Reduce memory usage
- Improve pathfinding efficiency
- Object pooling for golfers/balls
- Level of detail system

### [] Achievements & Unlockables
- Unlock new terrain types
- Special buildings
- Bonus challenges

---

## Post-1.0 Ideas

_These are ambitious ideas that would each represent significant scope. Deferred until the core game is complete and polished._

- Career mode with progressive challenges
- Seasonal visual changes (fall foliage, spring flowers)
- Course export/import and sharing

---

## Future Ideas (Deferred from Earlier Priorities)

_These features were considered but deferred to focus on core gameplay. May be revisited later._

### UI/UX (from P7)
- Categorized terrain menu with collapsible sections
- Quick-select hotkeys (1-9) for common tools
- Hover tooltips showing terrain cost and maintenance
- First-time player tutorial guidance
- Tooltip hints for UI elements
- Help menu with gameplay tips

### Golfer AI (from P2)
- Prefer walking on cart paths
- More sophisticated A* pathfinding
- Start golfers at clubhouse instead of tee box

### Economy (from P6)
- Golfer needs system (thirst, hunger, fatigue)
- Buildings satisfy specific needs
- Strategic building placement incentives

### Save/Load (from P4)
- Full mid-action golfer state persistence
- Persist ball trajectories mid-flight

---

## Known Bugs

### Critical
- None currently! All critical bugs have been resolved.

### Fixed (Completed)
- ✅ Clicking plant tree causes the game to crash - Fixed by renaming Tree class to TreeEntity
- ✅ Placing rocks doesn't work - Fully implemented with 3 size options
- ✅ Arrow key camera movement is isometric instead of intuitive - Now moves in visual screen direction
- ✅ Landing zone check was blocking within the same group instead of only other groups
- ✅ Golfer accuracy too low - increased skill range to 0.5-0.9 and reduced error spread
- ✅ Round finish bug - golfers now properly clear the final green
- ✅ Groups deadlocking each other on par 3s - fixed with directional blocking and par 3 holds
- ✅ Ball flight not visible - BallManager failed to create ball on first shot; fixed by adding from_position to ball_landed signal and using get_or_create_ball
- ✅ Golfer/ball tile offset - entities positioned at tile corner instead of center; added grid_to_screen_center helper
- ✅ Infinite putting loop - putts never converged toward hole, blocking next group's tee shots; fixed with gimme range, short putts aim at hole, off-green putts stop at green edge
- ✅ Putter shots flying in arc like wedge shots - putts now roll along the ground with club-aware animation
- ✅ Landing zone deadlock from stuck putters - added putt accuracy floor (95% short, 75% long) and double-par pickup rule
- ✅ Too many groups spawning at once - tightened first tee clear check to also block when golfers are mid-action (walking, preparing, swinging, watching) on hole 0
- ✅ Golfers hitting from green instead of walking to next tee - reset current_strokes after hole-out and added walk-to-tee logic for subsequent holes
- ✅ Walk-to-tee broke first-hole spawning - added first-hole exemption so golfers teleport to tee on hole 1
- ✅ Golfers walking away from hole before heading to green when water/OB blocks path - rewrote pathfinding to try both sides at increasing offsets (3, 5, 8, 12 tiles) with validation
- ✅ Flag icon offset from putting target - flag and hole visualizer used grid_to_screen() (top-left) instead of grid_to_screen_center()
- ✅ Driver max distance unrealistic (450 yards) - reworked to 300 yard max, fairway wood to 255 yard max

### Minor
- (Add bugs as discovered)

---

## Development Notes

**Next Immediate Steps:**
1. ✅ ~~Fix the three critical bugs~~ - COMPLETE
2. ✅ ~~Implement ball visualization~~ - COMPLETE
3. ✅ ~~Make golfers visible and animated~~ - COMPLETE
4. ✅ ~~Complete the hole tracker visual system~~ - COMPLETE (All Priority 1 tasks done!)
5. ✅ ~~Implement play/pause with golfer spawning~~ - COMPLETE
6. ✅ ~~Complete Golfer Shot System with club types and shot mechanics~~ - COMPLETE
7. ✅ ~~Implement Golfer AI & Path Finding~~ - COMPLETE
8. ✅ ~~Golfer Spawn & Management System~~ - COMPLETE (dynamic tee-based spawning, group play, deadlock prevention)
9. ✅ ~~Hole Open/Close Management~~ - COMPLETE (toggle open/closed, delete holes, golfers skip closed holes)
10. ✅ ~~Undo/Redo in Build Mode~~ - COMPLETE (Ctrl+Z/Ctrl+Y, terrain strokes, entity placements)
11. ✅ ~~Green Fee UI~~ - COMPLETE (all P2 items done!)
12. ✅ ~~Priority 3: Terrain & Course Design Features~~ - COMPLETE (water overlays, bunker effects, OB fix + markers, wind system, elevation system)
13. ✅ ~~Priority 4: Save/Load & Essential UX~~ - COMPLETE (save/load, day/night, end-of-day summary, golfer feedback)
14. ✅ ~~Priority 5: Economy & Satisfaction Loop~~ - COMPLETE (operating costs, course rating, golfer tiers, course records)
15. ✅ ~~Priority 6: Buildings & Facilities~~ - COMPLETE (clubhouse upgrades, cart paths, building revenue/satisfaction effects)
16. ✅ ~~Priority 7: UI/UX Improvements~~ - COMPLETE (mini-map, financial dashboard, hole stats, selection indicator, panel fixes, undo improvements)
17. Start Priority 8: Advanced Features (Weather, Tournaments, Difficulty Rating)

**Long-term Vision:**
Create a deep, engaging golf course management game where players balance artistic course design with financial sustainability. The game should reward both creative design and smart business decisions, with satisfying golfer AI that makes the course feel alive.
