# Garden and facility catalog

The catalog contains 28 decorations and 16 buildings. Sixteen new decorations use `GardenArt` for consistent miniature artwork: rose and lavender borders, hydrangeas, hedges, rose arches, pergolas, picnic and parasol tables, lanterns, walls, fences, planters, lily pools, rock gardens, clocks and viewing decks. Lily pools and decks are ornamental; they do not replace water hazards or bridges.

Eight new facilities use `CourseArchitecture`: coffee house, halfway house, tea pavilion, ice cream kiosk, locker room, garden spa, conservatory and golf academy. Each defines construction cost, daily operating cost and its golfer service. `needs_service` maps a facility to the existing needs rules; revenue is earned only on a golfer's normal interaction check.

`CatalogArtwork`, placed objects and ghosts share the same drawing routines. Sprite thumbnails keep a strong texture reference for the lifetime of the control. Garden ghosts tint red on invalid placement. Footprint validation is shared between the preview and placement click: all tiles must be on owned compatible ground and clear of buildings, decorations, trees and rocks. Buildings can sit on paths. Failure messages describe the obstruction.

Placement, bulldozing, undo, aesthetics and JSON saving use the existing entity machinery. New items are data-driven, and older saves need no migration.
