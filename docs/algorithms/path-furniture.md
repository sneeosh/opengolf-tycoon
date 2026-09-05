# Path furniture placement

## Plain English

Benches, signs, bins, and ball washers use ground-plane artwork aligned with the
walk. They no longer inherit a fixed diagonal sprite angle or a patch of grass
under their feet. Small fixtures, including bird baths, sit inside an exposed
edge of their selected path tile. Benches on grass beside a walk face it.

The same artwork, position, and orientation appear in the placement ghost.
Existing decorations realign after path painting, undo/redo, or a bulk refresh.
The original tile remains the selection/removal/save anchor; furniture does not
move into a neighboring tile or change pathfinding, cost, or terrain.

## Algorithm

`PathFurniture.layout` examines the four cardinal neighbors. For a path tile,
choose the first exposed edge beside land (north, west, east, south), excluding
water, bunkers, invalid positions, and other paths. Offset the visual toward
that edge and face inward. The ground footprint stays within the selected tile.
For furniture off the path, face the first adjacent path without an offset.
Fully surrounded plaza/intersection tiles retain their center. Large decorations
such as fountains and gazebos retain their placement center.

The bench projects its length and depth onto the existing rectangular ground
grid, with height drawn upward. Horizontal walks use a horizontal bench; vertical
walks use a bench receding vertically at half scale. Legs and contact marks share
the same foot coordinates. Backrest thickness remains visible in the edge-on view.

Remaining decoration sprites use the visible bottom of the artwork as their
foot anchor, accounting for transparent canvas padding. Fountain/bird-bath
animation moves by the same correction. Built fixtures stay upright; natural
plantings retain their variation. Ghost sprites share the same anchor and
deterministic variation function as placed sprites.

Ordinary edits within one cardinal tile queue a single deferred visual rebuild.
`TerrainGrid.surface_refreshed` also requests a rebuild after quiet generation or
deserialization refreshes. There is no per-frame neighbor scan.

## Tuning levers

| Setting | Value | Effect |
| --- | --- | --- |
| Horizontal edge offset | 23 px | Leaves the center of a vertical walk open |
| Vertical edge offset | 10 px | Leaves the center of a horizontal walk open |
| Bench length | 36 px | Fits a 64 px tile |
| Bench ground depth | 8 px, projected at half depth | Keeps feet within its path tile |
| Bench back height | 23 px | Matches the scale of small fixtures |
| Edge priority | North, west, east, south | Stable orientation on load/repaint |

Integration coverage includes both walk directions, water/map edges, ordinary
painting and quiet refresh, stable selection/save anchors, plazas, large objects,
and sprite/animation grounding. Native renders check the actual course and ghost.
