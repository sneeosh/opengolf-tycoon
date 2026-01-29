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
8. **Ball physics and visualization system** - Complete arc trajectory animation with terrain-based rolling
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
- ✅ Debug output showing club, distance, and accuracy for each shot
- ✅ Short game accuracy boost: distance-based floor for wedge shots matches real amateur averages (20yds ~7yd error, 100yds ~20yd error)
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

### [] Hole Open/Close Management
- UI to mark holes as open or closed
- Closed holes removed from play rotation
- Prevent golfers from playing closed holes
- Display hole status on course
- Require minimum one open hole to play

### [~] Green Fee & Revenue System
**STATUS: PARTIAL** - Core green fee mechanics implemented, UI and traffic tuning pending:
- ✅ Golfers pay green fee on spawn
- ✅ Green fee configurable ($10-$200, default $30)
- ✅ Floating "+$XX" payment notification appears above golfer's head
- ✅ Green fee affects group size distribution (higher fees attract foursomes)
- ✅ Revenue tracked in budget system
- ⏳ UI to adjust green fee during gameplay
- ⏳ Golfer traffic varies based on course rating and difficulty
- ⏳ Payment happens at clubhouse (currently on spawn)

---

## PRIORITY 3: Terrain & Course Design Features

### [] Water Hazards
- Pond placement tool
- Lake/river creation
- Penalty stroke for water balls
- Water affects hole fun and difficulty rating

### [] Sand Traps & Bunkers
- Sand trap placement tool
- Reduced shot accuracy from sand
- Bunkers should affect hole fun and difficulty rating
- Visual sand spray effects

### [] Terrain Elevation System
- Hills and valleys
- Uphill/downhill shot adjustments (uphill shots should go shorter and downhill should go farther)
- Elevation affects ball roll
- Visual elevation indicators

### [] Advanced Fairway & Rough System
- Differentiated rough levels (light, heavy)
- Rough affects shot distance/accuracy
- Maintenance costs for different grass types

### [] Out of Bounds Areas
- OB markers and boundaries
- Stroke and distance penalty
- Prevent building in certain areas
- Natural boundaries (trees, water)

---

## PRIORITY 4: Buildings & Facilities

### [] Clubhouse Expansion
- Upgrade system for clubhouse
- Pro shop revenue
- Restaurant/bar facilities
- Locker rooms
- Impact on golfer satisfaction

### [] Maintenance Buildings
- Equipment shed
- Maintenance crew quarters
- Storage facilities
- Reduce upkeep costs over time

### [] Practice Facilities
- Driving range
- Putting green
- Chipping area
- Attracts better golfers
- Additional revenue stream

### [] Parking & Amenities
- Cart barn and cart paths
- Restrooms along course
- Water stations
- Benches and shelters

---

## PRIORITY 5: Economy & Management


### [] Operating Costs
- Maintenance crew salaries
- Utilities (water, electricity)

### [] Course Maintenance Schedule
- Mowing schedule and costs
- Equipment upgrades

### [] Staff Management
- Hire groundskeepers
- Pro shop employees
- Starter/marshal positions
- Staff quality affects course condition
- Salary vs. performance balance

---

## PRIORITY 6: Golfer Systems & Satisfaction

### [] Golfer Attributes & Personalities
- Skill levels (beginner to pro)
- Personality types (cautious, aggressive, etc.)
- Preferences (course difficulty, amenities)
- Loyalty and return visits

### [] Satisfaction & Rating System
- Course condition rating
- Pace of play tracking
- Amenity satisfaction
- Price/value perception
- Overall course rating (1-5 stars)

### [] Golfer Types & Demographics
- Casual players
- Serious golfers
- Families
- Party golfers
- Pros
- Members

### [] Achievement & Progression
- Course records tracking
- Hole-in-one celebrations
- Low round recognition
- Regular player benefits
- Pro shop discounts for loyal customers

---

## PRIORITY 7: UI/UX Improvements

### [] Course Overview Map
- Mini-map showing full course layout
- Zoom in/out controls
- Click to jump to location
- Show active golfers on map
- Highlight selected hole

### [] Financial Dashboard
- Current budget display
- Income/expense breakdown
- Revenue trends over time
- Cost per hole analysis
- Profitability metrics

### [] Build Mode Improvements
- Categorized terrain menu
- Quick-select hotkeys
- Undo/redo functionality
- Copy/paste terrain sections
- Template saving for hole designs

### [] Information Overlays
- Hover tooltips for terrain types
- Building information panels
- Golfer stats when clicked
- Hole statistics
- Cost preview before placement

### [] Tutorial System
- First-time player guidance
- Progressive feature unlocking
- Tooltip hints
- Achievement-based tutorials
- Help menu with tips

---

## PRIORITY 8: Advanced Features

### [] Weather System
- Different weather conditions (sunny, rain, wind)
- Weather affects ball flight
- Weather affects golfer spawn rate
- The course should never close
- Ball accuracy and distance affected by rain and wind
- Seasonal changes

### [] Tournament Mode
- Host tournaments
- Prize money system
- Attract pro golfers

### [] Course Certification System
- Difficulty rating (slope/rating)
- Professional certification levels
- Unlock features with better ratings
- Attract higher-paying golfers
- Tour event hosting opportunities

---

## PRIORITY 9: Polish & Content

### [] Visual & Audio Polish
- Create custom sprites for all terrain types
- Animated water and flags
- Ambient sounds (birds, wind, golf shots)
- Music tracks for different game states
- Particle effects (sand spray, water splash)

### [] Additional Terrain Objects
- Flower beds and gardens
- Decorative rocks and boulders
- Statues and monuments
- Bridges over water
- Cart paths (visual and functional)

### [] Seasonal Content
- Fall foliage colors
- Spring flowers
- Summer lush greens
- Seasonal events and tournaments

### [~] Zoom & Scale Tuning
**STATUS: PARTIAL** - Yardage scale adjusted, zoom polish remaining:
- ✅ Yardage scale tripled (5 → 15 yards/tile) for more realistic hole yardages
- ✅ All club distances, ball rolling, safety radii, and thresholds scaled to match
- ⏳ Adjust default zoom for realistic yardage
- ⏳ Smooth zoom transitions
- ⏳ Remember zoom preference

---

## PRIORITY 10: Optimization & Expansion

### [] Performance Optimization
- Optimize rendering for large courses
- Reduce memory usage
- Improve pathfinding efficiency
- Object pooling for golfers/balls
- Level of detail system

### [] Save/Load System
- Save course progress
- Multiple save slots
- Auto-save functionality
- Export/import course designs

### [] Achievements & Unlockables
- Unlock new terrain types
- Special buildings
- Legendary golfers
- Unique decorations
- Bonus challenges

### [] Expansion Ideas
- Mini-golf mode
- Disc golf variant
- Historical famous courses
- Fantasy/themed courses
- Career mode progression

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
9. Finish Green Fee & Revenue System (UI to adjust fees, traffic tuning) OR Implement Hole Open/Close Management (Priority 2 - NEXT UP)

**Long-term Vision:**
Create a deep, engaging golf course management game where players balance artistic course design with financial sustainability. The game should reward both creative design and smart business decisions, with satisfying golfer AI that makes the course feel alive.