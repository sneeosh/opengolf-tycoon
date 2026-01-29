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
- ⏳ Wind effects on ball flight (future enhancement)

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

### [] Water Hazard Placement Tools
_Note: Shot mechanics for water penalties already exist in code._
- Pond placement tool (brush-based painting)
- Lake/river creation with connected tiles
- Visual water animation
- Water affects hole difficulty rating

### [X] Sand Trap & Bunker Placement Tools
**STATUS: COMPLETE** - Bunker visual enhancements:
- ✅ Sand trap placement tool (brush-based painting) - already existed
- ✅ Visual sand spray particle effects (SandSprayEffect on bunker landing)
- ✅ Visual grain/stipple overlay on bunker tiles (BunkerOverlay)
- ✅ Bunker landing detection in ball physics (ball_landed_in_bunker signal)

### [] Wind Effects on Ball Flight
- Wind direction and strength (variable per day or per hole)
- Wind affects ball trajectory during flight
- Headwind reduces distance, tailwind increases it
- Crosswind pushes ball laterally
- AI golfers account for wind in shot planning
- Wind indicator in HUD

### [] Terrain Elevation System
- Hills and valleys
- Uphill/downhill shot adjustments (uphill shorter, downhill farther)
- Elevation affects ball roll direction and speed
- Visual elevation indicators

### [] Out of Bounds Areas
- OB markers and boundary painting
- Stroke and distance penalty enforcement
- Natural boundaries (trees, water)

---

## PRIORITY 4: Save/Load & Essential UX

### [] Save/Load System
- Save course layout, economy state, and day progress
- Auto-save at end of each day
- At least one save slot (multiple slots later)
- Load from main menu

### [] Day/Night Cycle & Course Closing
- Visual dimming as evening approaches
- Golfers finish current hole and leave at closing time (8 PM)
- New day begins at course open (6 AM)
- Day transition screen or notification

### [] End-of-Day Summary
- Revenue earned today
- Number of golfers served
- Notable scores (eagles, hole-in-ones)
- Average pace of play
- Daily profit/loss

### [] Golfer Feedback System
- Thought bubbles above golfers showing reactions ("Great hole!", "Too slow!", "Overpriced!")
- Feedback tied to actual game state (pace of play, green fee vs course quality, hole design)
- Gives the player actionable information about what to improve
- Aggregate feedback visible in a simple log or summary

---

## PRIORITY 5: Economy & Satisfaction Loop

### [] Operating Costs
- Daily maintenance costs per hole (based on terrain quality)
- Baseline daily operating cost for the course
- Player sees income vs expenses each day

### [] Golfer Satisfaction & Course Rating
- Course condition rating (based on maintenance)
- Pace of play tracking (slow play reduces satisfaction)
- Price/value perception (green fee vs course quality)
- Overall course rating (1-5 stars) affects golfer traffic
- Higher ratings attract more golfers and justify higher green fees

### [] Golfer Types & Skill Tiers
- Beginner, casual, serious, and pro skill tiers
- Each tier has different expectations and spending
- Better courses attract higher-tier golfers
- Pro golfers generate reputation

### [] Course Records & Notable Events
- Track course records (lowest round, hole-in-ones)
- Hole-in-one celebration animation
- Low round recognition notification
- Records displayed somewhere accessible

---

## PRIORITY 6: Buildings & Facilities

### [] Clubhouse
- Starting clubhouse (already implied by spawn system)
- Upgrade tiers that unlock amenities (pro shop, restaurant)
- Each upgrade increases golfer satisfaction and revenue
- Visual upgrades reflected on the map

### [] Cart Paths
- Paintable cart path terrain type
- Golfers prefer walking on paths (faster movement)
- Visual distinction on the isometric map
- Connects tees, greens, and clubhouse

### [] Additional Facilities (defer details until economy loop exists)
- Practice facilities (driving range, putting green) - additional revenue
- Restrooms along course - satisfaction boost
- Benches and shelters - satisfaction boost

---

## PRIORITY 7: UI/UX Improvements

### [] Course Overview Map
- Mini-map showing full course layout
- Click to jump to location
- Show active golfers on map
- Highlight selected hole

### [] Financial Dashboard
- Current budget display (already partial)
- Income/expense breakdown
- Revenue trends over time
- Daily and cumulative profit/loss

### [] Build Mode Improvements
- Categorized terrain menu
- Quick-select hotkeys
- Cost preview before placement
- Hover tooltips for terrain types

### [] Information Overlays
- Golfer stats when clicked
- Hole statistics (average score, pace of play)
- Building information panels

### [] Tutorial & Help
- First-time player guidance (optional)
- Tooltip hints for UI elements
- Help menu with tips

---

## PRIORITY 8: Advanced Features

### [] Weather System
- Weather conditions (sunny, cloudy, rain)
- Rain reduces golfer spawn rate
- Visual weather effects (rain particles, darker sky)
- Course never closes due to weather

### [] Tournament Mode
- Host tournaments on your course
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

- Mini-golf mode
- Disc golf variant
- Career mode with progressive challenges
- Seasonal visual changes (fall foliage, spring flowers)
- Course export/import and sharing

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
12. Start Priority 3: Terrain & Course Design Features (water hazards, bunkers, elevation)

**Long-term Vision:**
Create a deep, engaging golf course management game where players balance artistic course design with financial sustainability. The game should reward both creative design and smart business decisions, with satisfying golfer AI that makes the course feel alive.
