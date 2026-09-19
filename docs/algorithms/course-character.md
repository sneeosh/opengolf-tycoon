# Landforms and clubhouse life

## Plain English

Rolling hill and Hollow tools create rounded changes in the existing elevation
map. They preserve paths, water, buildings, and land ownership, and use the
existing undo/save system. Quick Start holes 2, 5, and 8 now have raised tees,
crowned greens, and a shallow valley between them. Other courses are not
reshaped on load. These are real elevation changes used by the simulation;
the rendering still uses the existing world coordinates, without geometric
terrain displacement or an isometric-grid migration.

Facilities share warm cream siding, green shutters, tiled gable roofs, and fixed
window/door proportions. Clubhouses grow by adding facade bays at each upgrade.
An attached veranda and compact stone apron replace the detached oversized patio.
Flower boxes, a clock dormer, striped shop awnings, cart bays, and chimney smoke
identify the different facilities. Windows turn warm at dusk. Recessed porch
floors, shaded posts, sheltered benches, entrance gables, climbing roses, and
wall lanterns add depth at the front door. Upgraded clubhouses fly a small
animated pennant; restaurants have a sheltered bistro table.

Every facility has purpose-specific detail: pro-shop merchandise, golf bags and
chalkboards; restaurant window boxes; snack-hut menus and cup signage; restroom
trellises and a sheltered threshold; cart-shed ventilation, equipment and wheel
stops; and range-pavilion bracing, mat dividers and ball baskets. All are cosmetic
and share the built/ghost geometry. The buildable bench uses the same grounded
`park_bench` renderer as decorative benches.

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

`CourseArchitecture` draws buildings and placement ghosts from identical geometry.
World footprints stay unchanged. Facades are horizontal; depth recedes by
`(-0.55 * depth, -0.5 * depth)`. Clubhouse facade widths are 138, 166, and 194
pixels, with fixed 14-pixel doors. Roof planes share one ridge and masonry return.
Foundation, porch posts, stairs, and apron use the same base coordinate.
The 10 Hz cosmetic clock respects pause; chimney smoke and window light are drawn
from the actual architecture, replacing offsets tied to old sprite dimensions.
Rebuilding removes the old visual and click area before adding replacements.

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
| Architecture redraw | 10 Hz | Bounded ambient drawing |
| Reaction duration | 2.2 real seconds | Readable without slowing the game |
| Happy hop height | 4 pixels | Small celebration with feet returning to ground |

Integration tests check tapering, surface preservation, save/undo, buildings and
height limits, monotonic upgrade growth and unique visual/click areas, pose isolation, pause, and
cancellation when the next shot starts. Native QA includes the clubhouse,
illustrated reaction poses, sculpted Quick Start holes, and a live simulation.
