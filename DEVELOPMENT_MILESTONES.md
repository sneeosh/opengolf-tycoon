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
36. **Angular dispersion shot model** - Realistic shot accuracy using bell-curve angular deviation instead of uniform random. Each golfer has persistent miss tendency (slice/hook bias) based on tier. Includes rare shank mechanic for dramatic misses.
37. **CenteredPanel UI system** - Base class for centered panels with proper layout timing. All popup dialogs (trees/rocks/buildings) support toggle behavior via hotkeys.

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
- ✅ **Angular dispersion shot model**: Replaces uniform random error with realistic bell-curve (gaussian) angular dispersion. Shots rotate by miss angle sampled from normal distribution, so most shots land near target line with occasional big hooks/slices in the tails
- ✅ **Miss tendency per golfer**: Each golfer has persistent `miss_tendency` (-1.0 to +1.0) for slice/hook bias. Beginners have strong tendencies (±0.4-0.8), pros are nearly neutral (±0.0-0.15). Generated in `GolferTier.generate_skills()`
- ✅ **Shank mechanic**: Rare catastrophic miss (35-55° off-line, 30-60% distance) with probability `(1.0 - accuracy) * 6%`. Only on full swings, direction follows miss_tendency
- ✅ **Gaussian distance loss**: Topped/fat shots use bell curve distribution for distance loss, so most shots are near full distance with occasional chunks

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
- ✅ Staff panel overflow fixed with proper sizing

### [X] CenteredPanel Base Class & Toggle Behavior
**STATUS: COMPLETE** - Centralized panel behavior and hotkey toggle support:
- ✅ `CenteredPanel` base class (`scripts/ui/centered_panel.gd`) for panels that need centering
- ✅ Handles Godot layout timing issues (show offscreen → await frame → resize/center)
- ✅ Provides `show_centered()` and `toggle()` methods
- ✅ Refactored panels to extend CenteredPanel: StaffPanel, FinancialPanel, TournamentPanel, BuildingInfoPanel, HoleStatsPanel, SaveLoadPanel, EndOfDaySummary
- ✅ Tree/Rock/Building selection dialogs (T/R/B keys) now toggle closed when pressed again
- ✅ Uses `window_input` signal on AcceptDialog to capture hotkey while modal dialog is open
- ✅ UI patterns documented in CLAUDE.md

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

## PRIORITY 8: Advanced Features ✅ COMPLETE

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

### [X] Tournament Mode
**STATUS: COMPLETE** - Host tournaments with tiered requirements:
- ✅ Four tournament tiers: Local, Regional, National, Championship
- ✅ Each tier has requirements (holes, rating, difficulty, yardage)
- ✅ Prize money system (course pays entry, earns prestige)
- ✅ 3-day scheduling lead time with 7-day cooldown
- ✅ Generated tournament results with winner names/scores
- ✅ Tournament panel UI with qualification status
- ✅ Toggle with T key or button
- ✅ Tournament state saved/loaded

### [X] Course Difficulty Rating
**STATUS: COMPLETE** - Automatic difficulty calculation:
- ✅ Course difficulty (1-10 scale) from hole ratings
- ✅ Slope rating (55-155) based on difficulty
- ✅ Course rating (expected score for scratch golfer)
- ✅ Displayed in end-of-day summary with color coding
- ✅ Prestige multiplier for reputation on challenging courses
- ✅ Difficulty affects golfer tier attraction (hard courses attract pros)

---

## PRIORITY 9: Polish & Content ✅ COMPLETE

### [X] Visual Polish
**STATUS: COMPLETE** - Terrain and building visuals significantly improved:
- ✅ Procedural textured tileset (mowing stripes, wave patterns, gravel textures)
- ✅ Tree overlay with 3 tree types (pine, oak, bushy) with shadows
- ✅ Flower bed overlay with colorful flower clusters
- ✅ Rock overlay with natural-looking formations
- ✅ Fairway and path visual overlays
- ✅ Improved building visuals (all building types)
- ✅ Particle effects (sand spray, water splash) - done in P3

### [X] Additional Terrain Objects
**STATUS: COMPLETE** - Core decorative objects implemented:
- ✅ Flower beds with FlowerOverlay
- ✅ Cart paths (visual and functional) - done in P6
- ✅ Trees and rocks with improved visuals

### [X] Zoom & Scale Tuning
**STATUS: COMPLETE** - Yardage and zoom controls:
- ✅ Yardage scale adjusted (22 yards/tile) for realistic hole distances
- ✅ All club distances scaled to match
- ✅ Pinch-to-zoom gesture support (Mac trackpad)
- ✅ Keyboard zoom hotkeys ([ and ])

### [X] Gameplay Polish
**STATUS: COMPLETE** - Shot accuracy and building fixes:
- ✅ Fixed shot accuracy (errors go short/sideways, never unrealistically long)
- ✅ Prevented terrain/elevation painting under buildings

---

## Priority 10 Development Plan

_This plan breaks Priority 10's 10 features into 5 sequential phases, ordered by dependencies, foundational impact, and risk. Each phase builds on the previous one._

### Dependency Analysis

```
Phase 1: Bug Fixes & Visual Foundation
  ├── Fix Golfer Overlap / Z-Ordering  (no dependencies, improves all future work)
  └── Improved Elevation Contour Visuals (no dependencies, contained refactor)

Phase 2: Theming & UI Infrastructure
  ├── Course Type / Theme System  (foundation for sprites, land costs, seasons)
  └── Menu & UI Overhaul           (main menu needed for theme selection; UI theme
  │                                  needed for all new panels in later phases)
  └── depends on: nothing, but all later UI-heavy features benefit from this

Phase 3: Progression & Economy Systems
  ├── Land Purchase & Course Size Progression  (depends on: theme for land pricing)
  ├── Staff & Grounds Maintenance System       (depends on: UI for staff panel)
  └── Marketing & Advertising System           (depends on: UI for marketing panel)

Phase 4: Time & Events
  └── Seasonal Calendar & Event System  (depends on: theme for seasonal modifiers,
                                          staff for seasonal maintenance costs,
                                          marketing for seasonal campaigns)

Phase 5: Major Gameplay & Art
  ├── Player-Controlled Golfer Mode       (largely independent, but benefits from
  │                                        UI overhaul for golf HUD)
  └── Improved Golfer & Natural Object Sprites  (depends on: theme system for
                                                  per-theme sprite variants)
```

### Phase 1 — Bug Fixes & Visual Polish (2 features)

**Why first:** These are self-contained improvements with no dependencies. Fixing Z-ordering eliminates a visual bug that would compound as more features add on-screen entities. Elevation contours improve the existing build-mode experience immediately.

| # | Feature | Scope | Key Files |
|---|---------|-------|-----------|
| 1 | Fix Golfer Overlap / Z-Ordering | Small-Medium | `golfer_manager.gd`, `golfer.gd` |
| 2 | Improved Elevation Contour Visuals | Medium | `elevation_overlay.gd` |

**Deliverables:**
- Isometric Y-sort on golfer parent node
- Positional offsets for co-located golfers (tee box fan-out, green semicircle)
- Name label collision avoidance
- Active golfer highlight ring
- Marching-squares contour interpolation
- Gradient elevation shading with hillshade effect
- Cached overlay texture (regenerate only on elevation change)

---

### Phase 2 — Theming & UI Infrastructure (2 features)

**Why second:** The theme system is the single most foundational feature in Priority 10 — sprites, land pricing, seasonal modifiers, and natural object distribution all depend on it. The UI overhaul provides the main menu (needed for theme selection) and establishes the visual language for every panel added in later phases.

| # | Feature | Scope | Key Files |
|---|---------|-------|-----------|
| 3 | Course Type / Theme System | Large | New `CourseTheme` resource, `tileset_generator.gd`, all 14 overlays, `game_manager.gd`, `terrain_types.json` |
| 4 | Menu & UI Overhaul | Large | New `main_menu.tscn`, new Godot `Theme` resource, `top_bar`, `tool_panel`, all existing UI scripts |

**Recommended order within phase:** Theme system first (provides content for the new-game screen), then UI overhaul (integrates the theme selection into the main menu).

**Deliverables:**
- `CourseTheme` enum/resource with 6 themes (Parkland, Desert, Links, Mountain, City, Resort)
- Per-theme color palettes fed into `TilesetGenerator`
- Per-theme overlay tinting (tree types, rock styles, rough color)
- Per-theme gameplay modifiers (wind, distance, costs)
- Theme selection screen (6 cards with preview, name, description)
- Theme stored in `GameManager` and serialized in saves
- Procedural natural object scattering on new-game start
- Main menu with New Game / Load / Settings / Quit
- Custom Godot `Theme` resource (buttons, panels, labels, scrollbars)
- Redesigned top bar with segmented sections and icons
- Tabbed toolbar with icon grid and tooltips
- Settings menu (graphics, gameplay, controls)
- Toast notification system

---

### Phase 3 — Progression & Economy Systems (3 features)

**Why third:** These add management depth and spending decisions, which are the core tycoon loop. They all require UI panels (benefiting from the Phase 2 UI overhaul) and interact with the theme system for cost balancing.

| # | Feature | Scope | Key Files |
|---|---------|-------|-----------|
| 5 | Land Purchase & Course Size Progression | Medium-Large | `terrain_grid.gd`, `game_manager.gd`, new land panel UI |
| 6 | Staff & Grounds Maintenance System | Medium-Large | New `staff_manager.gd`, `terrain_grid.gd` (condition tracking), staff panel UI |
| 7 | Marketing & Advertising System | Medium | New `marketing_manager.gd`, `golfer_manager.gd` (spawn modifiers), marketing panel UI |

**These three can be developed in parallel** since they have minimal inter-dependencies. Suggested priority order if done sequentially: Land → Staff → Marketing (land affects buildable area which is most fundamental; staff adds a persistent management layer; marketing is the most self-contained).

**Deliverables:**
- 40x40 starting plot with parcel grid overlay
- Purchasable adjacent parcels with progressive pricing
- Dark tint on unowned land, highlight on purchasable parcels
- Boundary enforcement on all build tools
- Land ownership serialized in saves
- 4 staff types (Groundskeeper, Marshal, Cart Operator, Pro Shop)
- Hire/fire UI with skill levels and salaries
- Per-tile course condition tracking with daily degradation/restoration
- Condition affects gameplay (green speed, fairway lies)
- Payroll as separate line item in financials
- 5 marketing channels with duration, cost, and effect
- Campaign management UI with ROI tracking
- Spawn rate modifiers from active campaigns
- Diminishing returns on stacked campaigns

---

### Phase 4 — Time & Events (1 feature)

**Why fourth:** Seasons affect weather tables, spawn rates, maintenance costs, and marketing effectiveness — all systems that should already exist before layering seasonal variation on top.

| # | Feature | Scope | Key Files |
|---|---------|-------|-----------|
| 8 | Seasonal Calendar & Event System | Medium | `game_manager.gd`, `weather_system.gd`, `golfer_manager.gd`, calendar UI |

**Deliverables:**
- 360-day year with 4 seasons (Spring/Summer/Fall/Winter)
- Per-season weather probability tables
- Per-season spawn rate and maintenance cost multipliers
- Green fee tolerance varies by season
- Calendar UI widget showing current month/season
- Holiday bonus traffic events with advance notice
- Theme-aware seasonal modifiers (Desert/Resort less affected by winter)

---

### Phase 5 — Major Gameplay & Art (2 features)

**Why last:** These are the largest individual features and benefit from every prior system being in place. Player-controlled golf needs the UI overhaul for its HUD. Sprite upgrades need the theme system to know which variants to create. Neither blocks other features, so deferring them reduces risk to the earlier phases.

| # | Feature | Scope | Key Files |
|---|---------|-------|-----------|
| 9 | Player-Controlled Golfer Mode | Very Large | New `player_golfer.gd` or mode in `golfer.gd`, new golf HUD, `ball.gd`, `camera` |
| 10 | Improved Golfer & Natural Object Sprites | Very Large (art-heavy) | `golfer.gd` (render pipeline), all overlay classes, new `assets/sprites/` directory |

**Player-Controlled Golfer can be split into two sub-phases:**
- **Phase 5a — Core shot mechanics:** Club selection bar, click-drag aim with landing zone preview, power meter, shot execution reusing existing ball physics. Scorecard UI.
- **Phase 5b — Full experience:** Putting interface with slope grid, course flyover, player customization, AI playing partners.

**Sprite upgrades can be split into two sub-phases:**
- **Phase 5a — Golfer sprites:** Replace `Polygon2D` rendering with `AnimatedSprite2D` + sprite sheets. 4-direction walk/swing/putt animations.
- **Phase 5b — Environment sprites:** Per-theme tree, rock, and building sprite sets.

---

### Risk Factors & Recommendations

1. **Theme system is the critical path.** It touches the most files (tileset generator + 14 overlays + game manager + save system). Prototype one theme (Desert) end-to-end before building all six.

2. **UI overhaul has high surface area.** Refactoring every panel is time-consuming. Consider doing it incrementally: main menu + theme resource first, then migrate existing panels one at a time rather than a big-bang rewrite.

3. **Player-controlled golfer is the highest-risk feature.** It introduces a fundamentally different input mode and requires a new camera system, shot UI, and game-time management. Build the simplest possible prototype (aim + shoot with existing physics) before investing in the full experience.

4. **Sprite art is a bottleneck.** If hand-drawn sprites aren't feasible, the "Enhanced Procedural" fallback (better shading/outlines on existing `Polygon2D` rendering) ships faster and still improves visual quality meaningfully.

5. **Test coverage matters.** The existing GUT tests cover core systems. Each phase should add tests for new managers (StaffManager, MarketingManager) and data structures (CourseTheme, LandParcel) to prevent regressions.

---

### Summary

| Phase | Features | Estimated Complexity |
|-------|----------|---------------------|
| 1 | Z-Ordering Fix + Elevation Contours | Small-Medium |
| 2 | Theme System + UI Overhaul | Large |
| 3 | Land Purchase + Staff + Marketing | Large (parallelizable) |
| 4 | Seasonal Calendar & Events | Medium |
| 5 | Player Golf Mode + Sprite Upgrade | Very Large |

**Total: 10 features across 5 phases, ordered to maximize foundational value and minimize rework.**

---

## PRIORITY 10: Course Theming, Visuals & Gameplay Expansion

### [] Course Type / Theme System
**Goal:** Let players choose a course environment at game start, each with distinct visuals, natural object distributions, and gameplay feel. This is foundational for replayability and will eventually support multi-course ownership.

**Course Types to Implement:**
1. **Parkland (Default)** - Current game style. Lush green grass, deciduous trees (oak, maple), gentle rolling hills, flower beds. Balanced difficulty.
2. **Desert** - Arid sandy base terrain, cacti and desert scrub instead of trees, rocky outcroppings, minimal water. Fairways are oases of green surrounded by sand/hardpan. Color palette: tan, burnt orange, sage green fairways, terracotta.
3. **Links (Oceanfront)** - Coastal Scottish-style. Fescue grass (golden-brown rough), pot bunkers (deep & small), dune mounds, sea grass, minimal trees. Strong persistent wind. Color palette: golden browns, muted greens, grey-blue water accents.
4. **Mountain** - Dramatic elevation changes, pine/fir forests, exposed rock faces, mountain streams. Thinner air = longer drives (+5% distance). Color palette: deep greens, grey stone, snow-capped backgrounds.
5. **City/Municipal** - Flat terrain, chain-link fencing instead of OB stakes, small ponds, minimal natural features, concrete cart paths. Cheaper land/maintenance but lower satisfaction ceiling. Color palette: muted greens, grey, urban browns.
6. **Resort** - Tropical lush. Palm trees, vibrant flower beds, white sand bunkers, lagoon-style water features. Higher construction costs but premium green fee tolerance. Color palette: vivid greens, turquoise water, white sand, bright flowers.

**Implementation Details:**
- Add `CourseTheme` resource/enum with per-type configuration:
  - `base_colors: Dictionary` — color overrides for each terrain tile type (passed to TilesetGenerator)
  - `natural_objects: Array[Dictionary]` — weighted spawn table for auto-placed decorative objects (tree types, rocks, flora)
  - `overlay_config: Dictionary` — per-overlay color/style parameters (e.g., links rough uses golden fescue tints)
  - `gameplay_modifiers: Dictionary` — wind_base_strength, distance_modifier, maintenance_cost_multiplier, green_fee_baseline
  - `ambient_description: String` — flavor text for UI
- Extend `TilesetGenerator` to accept a `CourseTheme` and use its color palette instead of hardcoded colors
- All 14 overlay classes need a `theme` parameter to tint/style their procedural drawing (e.g., `TreeOverlay` draws palms for Resort, pines for Mountain, cacti for Desert)
- Add course type selection screen shown before new game begins (grid of 6 cards with preview thumbnail, name, and 2-line description)
- Store selected course type in `GameManager` and serialize in save data
- Extend `terrain_types.json` with per-theme cost overrides (e.g., water is cheaper on Resort, bunkers cheaper on Links)
- Natural object auto-distribution: when a new game starts, procedurally scatter theme-appropriate objects on empty/grass tiles using noise-based density maps

**Future Extension (not this priority):**
- Multi-course ownership: player can start a second course of a different type, switching between them
- Unlockable course types based on reputation milestones

---

### [] Improved Elevation Contour Visuals
**Goal:** Make elevation contours look more natural and appealing rather than the current hard-edged topographic lines.

**Current State:** `ElevationOverlay` in `scripts/terrain/overlays/elevation_overlay.gd` draws contour lines at elevation boundaries with alpha 0.15-0.2. The lines are drawn per-tile where adjacent tiles have different elevation, producing a jagged staircase effect.

**Improvements:**
- **Smooth contour interpolation:** Instead of drawing hard lines at tile boundaries, use marching squares or a similar algorithm to interpolate contour positions within the tile grid, producing smooth curved contour lines
- **Gradient shading between contours:** Replace the flat alpha tinting with smooth gradient transitions. Tiles should blend gradually between elevation levels rather than having uniform tint per tile
- **Variable line weight:** Contour lines at major elevation intervals (every 2-3 levels) should be thicker/more prominent; intermediate lines should be thin and subtle
- **Natural color grading:** Higher elevations should shift subtly toward lighter/cooler tones; lower elevations toward darker/warmer tones, mimicking real topographic relief shading
- **Hillshade effect:** Add optional directional shading to simulate sunlight hitting slopes (northwest light source convention), giving the terrain a 3D feel without actual 3D rendering
- **Green contour awareness:** Greens should show subtle slope indicators (arrows or grain lines) to help players read putt breaks visually

**Technical Approach:**
- Refactor `ElevationOverlay._draw_elevation_visuals()` to pre-compute a smoothed elevation field using bilinear interpolation across the tile grid
- Use the interpolated field to draw anti-aliased contour lines via marching squares
- Apply per-pixel gradient shading based on interpolated elevation values
- Consider caching the overlay as an `ImageTexture` and only regenerating when elevation changes (performance optimization)

---

### [] Fix Golfer Overlap / Z-Ordering
**Goal:** Prevent golfers from stacking on top of each other and becoming invisible when multiple golfers occupy nearby tiles.

**Current State:** Golfers are rendered as `Node2D` children of the main scene. When multiple golfers stand on the same or adjacent tiles (e.g., waiting on a tee box, putting on a green), they overlap and obscure each other. There's no visual indication of hidden golfers.

**Fixes:**
- **Isometric Y-sort:** Ensure golfers are sorted by their isometric Y position (screen Y + a fraction of screen X) every frame. Godot's `CanvasItem.z_index` or a `YSort`/manual sort on the parent node can handle this. Golfers "in front" (lower on screen) should render on top of golfers "behind" them
- **Positional offset for co-located golfers:** When multiple golfers occupy the same tile (e.g., group waiting on tee), apply small visual offsets so they fan out slightly (like a group standing together). Offset by ~8-12px in screen space per additional golfer
- **Group clustering logic:** On tee boxes and greens, arrange waiting golfers in a semicircle or line formation rather than stacking them all at the tile center
- **Name label stacking:** When golfers are close together, stagger their name/score labels vertically so they don't overlap. Use a simple collision avoidance pass on label positions
- **Active golfer highlighting:** The golfer currently taking a shot should have a subtle highlight ring or always render on top (highest z_index) so the active player is always visible

**Implementation Notes:**
- Add a `_sort_golfers()` method to `GolferManager` called each frame (or when golfer positions change)
- Modify `golfer.gd` to expose a `visual_offset: Vector2` that shifts the sprite without changing the logical grid position
- On tee/green tiles, `GolferManager` assigns offsets to co-located golfers based on group position index

---

### [] Land Purchase & Course Size Progression
**Goal:** Start with a small plot of land and expand by purchasing adjacent parcels. Creates a natural progression curve and meaningful economic decisions.

**Implementation Details:**
- **Starting plot:** New courses begin with a limited buildable area (e.g., 40×40 tiles out of the 128×128 grid). Only tiles within owned land can have terrain placed or modified
- **Land parcels:** Divide the full 128×128 grid into purchasable rectangular parcels (e.g., 16×16 or 20×20 blocks). Display a grid overlay showing parcel boundaries when in a "Buy Land" mode
- **Progressive pricing:** Base land cost starts at $5,000 per parcel. Each subsequent parcel purchased increases the price by 15-25% (simulating market demand / scarcity). Parcels further from the course center cost more (distance premium). Parcels adjacent to water or with elevation variety could cost a premium
- **Visual feedback:** Owned land shown with normal terrain colors. Unowned land shown with a dark tint/hatch overlay. Purchasable parcels (adjacent to owned land) highlighted when in buy mode
- **Purchase UI:** New "Buy Land" button in build mode toolbar. Clicking shows available parcels with prices. Confirm dialog before purchase. Purchased parcels immediately become buildable
- **Boundary enforcement:** Terrain tools, entity placement, and hole creation all check land ownership. Show error message if player tries to build on unowned land
- **Save/load:** Serialize owned parcel list in save data. Migrate old saves to assume all land is owned (backwards compatibility)

**Gameplay Balance:**
- Starting 40×40 plot fits ~3-4 holes comfortably, forcing early decisions about layout
- A full 18-hole championship course requires ~6-8 parcel purchases ($30K-$80K total investment)
- Creates natural spending tension: invest in land expansion vs. buildings vs. course improvements
- Links and Desert themes could have cheaper land; Resort and City more expensive

---

### [] Improved Golfer & Natural Object Sprites
**Goal:** Upgrade the visual quality of golfers, trees, rocks, and other course objects from procedural primitives to more appealing hand-crafted or semi-procedural sprites.

**Current State:**
- Golfers: Procedurally drawn from `Polygon2D` shapes (9 body parts: head, body, arms, legs, shoes, collar, hands, hair, cap). Functional but blocky and toy-like at ~20px tall
- Trees: 3 procedural varieties in `TreeOverlay` (pine=triangle, oak=circle, bushy=wide circle) drawn with basic polygons and flat color fills
- Rocks: Simple grey blobs in `RockOverlay`
- Buildings: Procedurally drawn colored rectangles with minimal detail in `building.gd`

**Recommended Approach — Hybrid (procedural base + hand-drawn detail):**
- **Best practice for isometric 2D pixel art at this scale** is to hand-draw a small sprite sheet of base templates and then programmatically recolor/vary them. This gives much better visual quality than pure procedural generation while still allowing randomization
- **Golfer sprites:** Design a 4-direction sprite sheet (front, back, left, right) at 32×32px or 48×48px per frame. Include animation frames for: idle (2 frames), walk cycle (4-6 frames), swing (4 frames), putt (3 frames). Recolor via shader or palette swap for shirt/pants/cap variety. Tools: Aseprite (pixel art standard), LibreSprite (free), or Piskel (browser-based)
- **Tree sprites:** Hand-draw 4-5 tree varieties per course theme at 48×64px. Each theme needs its own set (palms for Resort, cacti for Desert, pines for Mountain, etc.). Can recolor/scale procedurally for variety
- **Rock sprites:** 3-4 rock formations per theme at 32×32px. Desert gets sandstone, Mountain gets granite, Links gets weathered stone
- **Building sprites:** Redesign as proper isometric sprites at 64×64px or larger. Each building type gets a unique identifiable silhouette
- **Implementation:** Replace `Polygon2D` drawing in `golfer.gd` with `AnimatedSprite2D` loading from sprite sheets. Replace overlay drawing with `Sprite2D` instances placed by the overlay system. This is a significant refactor of the rendering pipeline but greatly improves visual quality

**Alternative — Enhanced Procedural:**
- If hand-drawing is too time-intensive, invest in better procedural generation: add outlines, shading gradients, anti-aliasing, and more detail layers to the existing `Polygon2D` approach. This is cheaper but has a lower visual ceiling
- Could use AI sprite generation tools (Stable Diffusion with pixel art LoRA) to generate base sprites and then clean up manually

**Sprite Asset Pipeline:**
- Store sprites in `assets/sprites/` organized by category: `golfers/`, `trees/`, `rocks/`, `buildings/`
- Use Godot's `SpriteFrames` resource for animated sprites
- Theme-variant sprites stored in subdirectories per theme: `assets/sprites/trees/parkland/`, `assets/sprites/trees/desert/`, etc.

---

### [] Player-Controlled Golfer Mode
**Goal:** Let the player play their own course as a golfer, adding a "play the course" gameplay loop alongside the management sim. This is a signature SimGolf feature.

**Implementation — Phase 1 (Core Mechanics):**
- **Mode switch:** Add "Play Course" button that switches from management to player-golfer mode. Camera follows the player's golfer. Management UI hides; golf HUD appears
- **Shot interface:**
  - **Club selection:** Horizontal club bar at bottom of screen (Driver, 3-Wood, 5-Iron, 7-Iron, PW, SW, Putter). Click or number keys 1-7 to select
  - **Aim system:** Click-and-drag from ball to set direction. Show projected landing zone circle that accounts for club distance and accuracy. Direction line extends from ball with a cone showing accuracy spread
  - **Power meter:** After setting direction, press-and-hold spacebar for power (0-100%). Release to fire. Alternatively, a classic 3-click swing meter (tap to start, tap for power, tap for accuracy)
  - **Shot shape selector:** Straight, Draw, Fade toggle. Affects trajectory curve and landing offset
- **Shot sectors / zones:** When aiming, display a translucent overlay showing:
  - **Landing zone:** Circle/ellipse where the ball is expected to land based on club + power
  - **Danger zones:** Red tint on water/OB areas within range
  - **Optimal zone:** Green tint on fairway/green areas within range
  - Sector accuracy is affected by player skill (could be upgradable)

**Implementation — Phase 2 (Full Experience):**
- **Putting interface:** Overhead view of green with grid lines showing slope. Drag to set putt direction and power. Show predicted ball path based on slope/break
- **Score tracking:** Full scorecard UI showing hole-by-hole scores, running total, par comparison
- **Wind compensation:** Show wind arrow more prominently, player must manually adjust aim
- **Course flyover:** Before each hole, brief camera pan from tee to green showing layout
- **Player golfer customization:** Choose name, appearance (uses existing golfer color system)
- **AI playing partners:** Option to play alongside 1-3 AI golfers for group feel

**Technical Considerations:**
- Need a new `PlayerGolfer` class or mode flag on existing `Golfer` class that replaces AI decision-making with input handling
- Shot calculation reuses existing physics (`ball.gd` trajectory, terrain modifiers, wind effects) but with player-chosen parameters instead of AI-chosen
- Camera system needs a "follow" mode that tracks the player golfer smoothly
- Game time should pause or slow during player shots (real-time aiming doesn't work if time is running at 4x)
- Management simulation continues in the background (other golfers play, money accumulates) while player is on course

---

### [] Menu & UI Overhaul
**Goal:** Bring the UI up to tycoon-game standards (think Planet Coaster, Two Point Hospital, OpenTTD). The current UI is functional but feels like a debug interface rather than a polished game.

**Current Issues:**
- Top bar is a flat HBox of labels with no visual styling or hierarchy
- Tool palette is a plain list of buttons in a VBox with no grouping or visual separation
- Panels (financial, stats, etc.) use default Godot theme with minimal custom styling
- No main menu / title screen
- No settings/options menu
- Speed controls are small plain buttons
- No visual theme tying the UI together

**Improvements:**

1. **Main Menu / Title Screen:**
   - Game logo and title
   - "New Game" (leads to course type selection), "Load Game", "Settings", "Quit"
   - Animated background showing a procedurally generated course with golfers playing
   - Transition animation into gameplay

2. **Custom UI Theme:**
   - Design a cohesive Godot `Theme` resource with custom styles for: buttons, panels, labels, scrollbars, sliders, separators
   - Color palette: Golf-inspired greens, warm wood-tones for panels, cream/white text
   - Consistent border radius, shadow, and padding across all UI elements
   - Font upgrade: Use a clean sans-serif font (e.g., Nunito, Open Sans) for body text and a display font for headers

3. **Top Bar Redesign:**
   - Segmented bar with distinct sections: Money (with coin icon), Day/Time (with clock icon), Reputation (with star icon), Weather (with condition icon), Wind (with compass)
   - Each section is a clickable panel that opens its detailed view
   - Subtle background with rounded segments and dividers

4. **Toolbar Redesign:**
   - Tabbed categories: Terrain, Landscaping, Buildings, Holes, Utilities
   - Each tab shows a grid of icon buttons (not text lists)
   - Hover tooltip shows name, cost, and description
   - Selected tool highlighted with border glow
   - Collapsible/dockable panel

5. **Improved Speed Controls:**
   - Larger, more visible play/pause/fast/ultra buttons with icons
   - Current speed shown as text label next to controls
   - Keyboard shortcuts displayed on hover (1/2/3/4 or similar)

6. **Notification System Upgrade:**
   - Toast-style notifications that stack in corner and auto-dismiss
   - Color-coded by type (green=revenue, red=cost, blue=info, gold=achievement)
   - Click to expand for detail

7. **Settings Menu:**
   - Graphics: overlay toggle, zoom sensitivity
   - Gameplay: auto-save frequency, notification preferences
   - Audio: volume sliders (when audio is added)
   - Controls: key rebinding

---

### [] Staff & Grounds Maintenance System
**Goal:** Add a staff management layer where the player hires and manages course employees. Staff quality directly affects course condition, pace of play, and golfer satisfaction — a core tycoon mechanic.

**Staff Types:**
- **Groundskeepers:** Maintain terrain quality. Without enough groundskeepers, fairways slowly degrade toward rough, greens get slower (affects putt physics), bunkers become unkempt (reduced visual quality + harder lies). Each groundskeeper maintains ~20-30 tiles. Salary: $50-$150/day depending on skill
- **Course Marshals:** Speed up pace of play. Reduce average round time by nudging slow groups. Without marshals, groups can slow down and reduce daily throughput. Each marshal covers ~4-5 holes. Salary: $40-$80/day
- **Cart Operators:** Required to offer golf cart rentals (additional revenue stream: $15-$30/round). Carts make golfers move faster (2x path speed). Each operator supports ~8 carts. Salary: $30-$60/day
- **Pro Shop Staff:** Required for pro shop to generate revenue. Higher-skilled staff generates more sales. Salary: $40-$100/day

**Implementation:**
- Staff panel in management UI showing all hired staff with names, roles, skill levels, salaries
- Hire/fire with confirmation dialogs
- Staff skill levels (1-5 stars) affect their effectiveness — higher-skilled staff cost more
- Daily payroll added to operating costs (separate line item in financial dashboard)
- Course condition degrades over time based on groundskeeper coverage ratio
- `TerrainGrid` tracks per-tile condition value (0-100%) that groundskeepers restore each day
- Condition affects gameplay: degraded greens have more random putt deviation, degraded fairways give slight rough-like lie penalties

---

### [] Seasonal Calendar & Event System
**Goal:** Add a yearly calendar that cycles through seasons, affecting weather patterns, golfer traffic, maintenance costs, and creating natural revenue fluctuations that the player must plan around.

**Seasons:**
- **Spring (Days 1-90):** Moderate traffic, frequent rain, courses recovering from winter. Maintenance costs +20% (aeration, overseeding). Gradual traffic increase
- **Summer (Days 91-180):** Peak season. Maximum golfer traffic, hot weather, occasional thunderstorms. Premium pricing opportunity. Highest revenue potential
- **Fall (Days 181-270):** Traffic declining gradually, beautiful weather, lower rain. Tournament season bonuses. Leaf cleanup maintenance
- **Winter (Days 271-360):** Low traffic (50-70% reduction depending on course type). Desert/Resort courses less affected. Reduced maintenance costs. Good time for renovations (cheaper building costs)

**Implementation:**
- Add `season` property to `GameManager` derived from `current_day % 360`
- Season affects: weather probability tables, golfer spawn rate multiplier, maintenance cost multiplier, green fee tolerance (golfers accept higher fees in peak season)
- Seasonal visual hints (future enhancement, listed in Post-1.0): grass color shifts, leaf particles in fall, frost overlay in winter
- Calendar UI widget showing current month/season with upcoming events (tournaments, holidays)
- **Holiday events:** Random bonus traffic days (e.g., "Holiday Weekend" = 2x golfers for 2-3 days) with advance notice so player can prepare

---

### [] Marketing & Advertising System
**Goal:** Give players a way to actively attract more golfers rather than passively waiting for reputation to grow. Spending money on marketing is a classic tycoon lever.

**Marketing Channels:**
- **Local Newspaper Ad:** $200/week, +15% local traffic (Beginner/Casual golfers)
- **Golf Magazine Feature:** $1,000/month, +10% Serious/Pro golfers, requires 3+ star rating
- **Social Media Campaign:** $500/week, +20% traffic across all tiers, effect decays after campaign ends
- **Tournament Sponsorship:** $2,000 per event, doubles tournament prize money and reputation gain
- **Loyalty Program:** $100/month flat cost, 10% of golfers become "regulars" who visit 3x as often and have higher satisfaction baseline

**Implementation:**
- Marketing panel accessible from management UI
- Active campaigns shown with duration remaining and estimated effect
- ROI tracking: panel shows cost vs. estimated additional revenue from each campaign
- Campaigns require minimum reputation/rating thresholds
- Diminishing returns: running multiple campaigns of the same type gives reduced bonus

---

## PRIORITY 11: Performance & Optimization

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

### Audio & Animation (from P9)
- Ambient sounds (birds, wind, golf shots)
- Music tracks for different game states
- Animated water tiles
- Animated flag waving

### Additional Content (from P9)
- Bridges over water
- Smooth zoom transitions
- Remember zoom preference between sessions

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
17. ✅ ~~Priority 8: Advanced Features~~ - COMPLETE (weather system, tournaments, difficulty rating)
18. ✅ ~~Priority 9: Polish & Content~~ - COMPLETE (terrain visuals, zoom controls, shot accuracy fixes)
19. Start Priority 10: Course Theming, Visuals & Gameplay Expansion
20. Priority 11: Performance & Optimization (approaching Alpha!)

**Long-term Vision:**
Create a deep, engaging golf course management game where players balance artistic course design with financial sustainability. The game should reward both creative design and smart business decisions, with satisfying golfer AI that makes the course feel alive.
