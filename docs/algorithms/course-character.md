# Landforms and clubhouse life

## Plain English

Rolling hill and Hollow tools create rounded changes in the existing elevation
map. They preserve paths, water, buildings, and land ownership, and use the
existing undo/save system. Quick Start holes 2, 5, and 8 now have raised tees,
crowned greens, and a shallow valley between them. Other courses are not
reshaped on load. These are real elevation changes used by the simulation;
the rendering still uses the existing world coordinates, without geometric
terrain displacement or an isometric-grid migration.

Clubhouses gain a paved forecourt, side tables, planters, golf bags, and a walking
attendant. Level 2 adds parasols and a seated visitor; level 3 adds another visitor.
All activity stays within the existing building footprint. These ambient staff
and visitors do not add paid golfers, alter revenue, or occupy pathfinding tiles.

Golfer preparation gains a small address waggle. Finishing under par produces a
brief happy hop and glints; over par produces a slump; par gets a small nod. These
poses accompany the existing score thoughts and walking/swing sprites.

## Algorithms

For a stamp of radius `r`, compute normalized distance `d = distance / r` and
an elevation increment `round(amount * max(0, 1 - d²)²)`. Clamp resulting levels
to -5..5. Collect each changed tile's old and new elevation for the existing undo
manager. Built-in hill/hollow tools use +3/-3 and a brush diameter of at least 7.
They are additional tools; the original one-level Raise and Lower remain.
Quick Start uses smaller +2 green and +3 tee stamps, plus a -1 hollow.

The surface texture's blue channel stores `(base elevation + 5) / 10`. A second,
linearly filtered sampler reads that same texture at ±1.5 tiles to estimate a
broad normal. Sun direction drives restrained material shading (0.75–1.12), with
flat ground remaining neutral. Existing detailed elevation shading/contours are
visible only while sculpting. Four extra texture samples avoid the repeating
sub-tile profile patches. Elevation edits update the same coalesced texture upload;
physics elevations do not change through rendering.

`ClubhouseTerrace` draws furniture inside side bays, leaving the central door
approach open. Its 10 Hz cosmetic clock uses unscaled real time, respects pause,
and culls offscreen detail. The attendant follows a short sinusoidal route.
Outdoor people appear from 07:00 to 19:00 in dry weather. Terrace detail follows
the existing building upgrade level and is rebuilt with the building. Rebuilding
also removes the old click area so upgrades do not accumulate duplicate targets.

`GolferExpression` is a parent of the existing Visual node. Its local position,
rotation, and scale affect only the body, keeping the actor's world position,
ball, path, and labels unchanged. A real-time 2.2-second reaction begins after
`finish_hole`. Starting preparation or a swing cancels any remaining reaction.
The existing shot-preparation duration, swing completion signal, and shot timing
remain authoritative. Pause freezes the cosmetic timer.

## Tuning levers

| Setting | Value | Effect |
| --- | --- | --- |
| Hill/hollow amount | +3 / -3 | Height change per stamp |
| Sculpt brush | 7 or 9 tiles | Width of tapering slope |
| Green / tee radius | 5 / 4 tiles | Quick Start landform size |
| Landscape gradient step | 1.5 tiles | Broader, more readable lighting |
| Terrace redraw | 10 Hz | Bounded ambient drawing |
| Reaction duration | 2.2 real seconds | Readable without slowing the game |
| Happy hop height | 4 pixels | Small celebration with feet returning to ground |

Integration tests check tapering, surface preservation, save/undo, buildings and
height limits, unique upgraded terrace/click areas, pose isolation, pause, and
cancellation when the next shot starts. Native QA includes the clubhouse,
illustrated reaction poses, sculpted Quick Start holes, and a live simulation.
