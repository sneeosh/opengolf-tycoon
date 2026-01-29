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
9. Intuitive camera controls with arrow keys moving in visual direction

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

### [] Golfer Visual Rendering
Make golfers visible on the course:
- Add sprite or simple shape to golfer.tscn
- Position golfers correctly on isometric grid
- Animate walking between shots
- Add swing animation state
- Display golfer name labels
- Show current score/hole info above golfer

### [] Hole Tracker & Visual Connection
After placing a teebox, guide the green placement:
- Add visual line connecting teebox to green
- Display hole number label
- Show projected par based on distance
- Display yardage calculation
- Allow multiple green tiles to be placed after teebox
- Validate hole completion (must have tee + green)
- Show a flag on the primary green section. Allow for moving the flag around if multiple green tiles are present

---

## PRIORITY 2: Core Golf Gameplay

### [] Implement Play/Pause System
- Game starts in paused state
- Require at least one valid hole before allowing play
- Add play/pause button to UI
- Display game state clearly

### [] Golfer Spawn & Management System
- Spawn golfers in groups of 1-4 players randomly (course fun rating should bias for more foursomes)
- Start golfers near clubhouse
- New golfers should spawn once a group gets to the fairway on the first hole
- Track active golfers on course
- Remove golfers after completing round

### [] Complete Golfer Shot System
Implement all shot types with ability-based calculations:
- **Driver**: Long distance, lower accuracy (tee shots)
- **Iron**: Medium distance, medium accuracy (approach shots)
- **Wedge/Chip**: Short distance, high accuracy (around green)
- **Putter**: Green only, distance-based accuracy
- Shot calculations based on golfer ability stats
- Lie type affects shot quality (fairway, rough, sand, etc.)
- Wind effects on ball flight

### [] Golfer AI & Path Finding
Smart shot selection and course navigation:
- Prefer fairway landing zones
- Avoid hazards when possible
- Choose appropriate club for distance
- Green reading for putts
- Risk/reward decision making based on golfer personality
- Navigate between holes efficiently (prefer walking on golf paths if nearby. Can also walk on grass. Cannot walk on water.)

### [] Hole Open/Close Management
- UI to mark holes as open or closed
- Closed holes removed from play rotation
- Prevent golfers from playing closed holes
- Display hole status on course
- Require minimum one open hole to play

### [] Green Fee & Revenue System
- Golfers pay green fee before starting round
- Green fee can be increased or decreased. Green fee and overall course rating should then determine how frequently new golfers spawn and their group size.
- Payment happens at clubhouse
- Golfer traffic should vary based on green fee and course rating and difficulty
- When a golfer pays, a small notification should appear above their head.

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

### [] Zoom & Scale Tuning
- Adjust default zoom for realistic yardage
- Ensure par 5s are achievable without extreme zoom
- Smooth zoom transitions
- Remember zoom preference
- Realistic distance scaling

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

### Minor
- (Add bugs as discovered)

---

## Development Notes

**Next Immediate Steps:**
1. ✅ ~~Fix the three critical bugs~~ - COMPLETE
2. ✅ ~~Implement ball visualization~~ - COMPLETE
3. Make golfers visible and animated (Priority 1 remaining)
4. Complete the hole tracker visual system (Priority 1 remaining)
5. Implement play/pause with golfer spawning (Priority 2)

**Long-term Vision:**
Create a deep, engaging golf course management game where players balance artistic course design with financial sustainability. The game should reward both creative design and smart business decisions, with satisfying golfer AI that makes the course feel alive.