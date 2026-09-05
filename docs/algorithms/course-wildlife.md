# Living course details

## Plain English

Connected ponds attract a small duck family: an adult followed by two gold
ducklings. Flower beds and placed flower gardens attract fluttering butterflies
in fair daylight. Warm-season gardens have fireflies at dusk. Bird baths receive
an occasional robin, and fountains have moving droplets and basin ripples.
Flower-bed foliage and blooms change with the season; tropical and resort
gardens remain colorful in winter.

These are cosmetic residents. They do not block shots, incur upkeep, grant rating
bonuses, consume simulation randomness, or add fields to saved games. The
existing costs, unlocks, and aesthetics values of decorations still apply. The
garden-shed picker shows their actual artwork, price, upkeep, and unlock status.

## Algorithm

`CourseWildlife` indexes water and flower tiles. A full scan happens at initial
setup, successful load, or quiet-generation refresh. Ordinary painting changes
only the affected entries and marks residents dirty. Resident selection is
coalesced to at most four times per second during editing.

A duck home must have at least three cardinal water neighbors. Candidates are
sorted by distance to the playable map center, with a stable coordinate tie-break.
Accept at most 12 homes spaced at least five tiles apart. Garden visitors use
the same scheme with 24 homes and two-tile spacing. Placed flower gardens and
bird baths also provide garden homes. The resident lists are independent of
dictionary insertion order and use no random-number calls. Decoration placement
and removal publish habitat invalidation from `EntityLayer`, including undo/redo.

Each family follows an ellipse within its home tile:

`offset(t) = (17 cos(t), 5.5 sin(t))`

The adult advances at 0.32 radians per real second, with each duckling trailing
by 0.65 radians. Horizontal body/beak extent stays within the 64-pixel tile.
Rechecking the current terrain before drawing hides a family immediately when
its water tile is painted over; rebuilding removes or relocates the habitat.

Butterflies are visible from 07:00–18:00 outside winter when it is not raining.
Fireflies are visible from 17:30–21:00 in spring/summer when it is not raining.
Ducks shelter in heavy rain. Birds leave bird baths at 18:00 or when rain starts.
These constraints use the existing weather and season systems.

Animation is capped at 15 redraws/second, operates only on the bounded resident
lists, and culls offscreen detail. Ambient movement uses real time (dividing
scaled delta by `Engine.time_scale`) so speeding up a golf day does not make
ducks race around the pond. Pause stops movement. Camera movement still redraws
the frozen scene. Cosmetic nodes do not capture input.

`DecorationAtmosphere` attaches to the existing visual node of fountains and
bird baths. Rebuilding or removing the decoration removes the effect with it.
Fountain beads follow a quadratic fall from the original sprite's jet to its
basin; ripples stay within the basin. A robin visits a bird bath for eight seconds
of each sixteen-second cycle and periodically dips its head. Decorative contact
shadows anchor at the sprite foot and inherit the same variation transform.
The course surface receives the existing day/night canvas modulation, keeping
water, turf, and residents in the same light.

## Tuning levers

| Parameter | Value | Effect |
| --- | --- | --- |
| Duck families | 12 maximum | Bounded draw cost across large maps |
| Garden homes | 24 maximum | Butterfly/firefly population |
| Duck/garden spacing | 5 / 2 tiles | Prevents crowding |
| Habitat refresh | 0.25 seconds | Coalesces continuous painting |
| Animation redraw | 15 Hz | Same budget on desktop and web |
| Flower count | 7–10 per bed; 3 dormant | Fuller garden silhouette |
| Duck orbit | 17 × 5.5 pixels | Keeps waterline inside its tile |

Integration tests cover caps, repeatability, no terrain/RNG mutation, repainting
and loading, orbit bounds, season/weather conditions, and placed-garden removal.
Native render checks include a planted garden, pond, fountain, bird bath, daytime,
dusk, and the decoration picker. Browser/device performance remains a separate
validation step.
