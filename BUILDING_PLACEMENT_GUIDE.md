# Building and Tree Placement System

## Overview

This extension adds building and tree placement functionality to the SimGolf project. Players can now place trees and buildings on their golf course.

## Components Created

### 1. **PlacementManager** (`scripts/managers/placement_manager.gd`)
- Manages placement mode state (NONE, BUILDING, TREE)
- Validates placement locations
- Calculates placement costs
- Handles building footprints

**Key Methods:**
- `start_building_placement(building_type, building_data)` - Start placing a building
- `start_tree_placement()` - Start placing trees
- `cancel_placement()` - Cancel current placement mode
- `can_place_at(grid_pos, terrain_grid)` - Check if location is valid
- `get_placement_cost()` - Get cost of placement

### 2. **Building** (`scripts/entities/building.gd`)
- Represents a placed building on the course
- Stores building type, grid position, and dimensions
- Loads data from buildings.json
- Signals for selection and destruction

**Key Properties:**
- `building_type` - Type of building (e.g., "clubhouse", "pro_shop")
- `grid_position` - Location on the grid
- `width`, `height` - Building dimensions
- `building_data` - Full building configuration

### 3. **Tree** (`scripts/entities/tree.gd`)
- Represents a placed tree on the course
- Supports multiple tree types: oak, pine, maple, birch
- Each type has unique properties (cost, height, width, color)
- Signals for selection and destruction

**Tree Types:**
- Oak: $20, medium size
- Pine: $18, tall and narrow
- Maple: $25, medium-large
- Birch: $22, medium

### 4. **EntityLayer** (`scripts/course/entity_layer.gd`)
- Container that manages all placed buildings and trees
- Maintains dictionaries for quick lookup by position
- Provides placement and removal methods
- Handles serialization for saving

**Key Methods:**
- `place_building(building_type, grid_pos, building_registry)` - Place a building
- `place_tree(grid_pos, tree_type)` - Place a tree
- `get_building_at(grid_pos)` - Get building at position
- `get_tree_at(grid_pos)` - Get tree at position
- `remove_building(grid_pos)` - Remove a building
- `remove_tree(grid_pos)` - Remove a tree
- `get_all_buildings()`, `get_all_trees()` - Get all entities

### 5. **BuildingRegistry** (`scripts/managers/building_registry.gd`)
- Loads building data from `data/buildings.json`
- Provides interface to query building information
- Validates building types

**Key Methods:**
- `get_building(building_type)` - Get building data
- `get_all_buildings()` - Get all building definitions
- `get_building_names()` - List all building types
- `get_building_cost(building_type)` - Get cost
- `get_building_size(building_type)` - Get dimensions

### 6. **BuildingSelectionUI** (`scripts/ui/building_selection_ui.gd`)
- PopupPanel for selecting building types to place
- Displays building names and costs
- Emits signals when building is selected

## Integration with Main Scene

The building and tree placement system is integrated into `scripts/main/main.gd`:

1. **Initialization**
   ```gdscript
   building_registry = Node.new()
   building_registry.script = load("res://scripts/managers/building_registry.gd")
   
   entity_layer = EntityLayer.new()
   entity_layer.set_terrain_grid(terrain_grid)
   ```

2. **Input Handling**
   - Placement mode takes priority over terrain painting
   - Click to place when in placement mode
   - Press Cancel to exit placement mode

3. **UI Integration**
   - `TreeBtn` starts tree placement
   - `BuildingBtn` starts building selection menu
   - Buttons are checked for existence with `has_node()` for flexibility

## Usage Instructions

### Placing Trees
1. Click the "Plant Tree" button (TreeBtn) in the tool panel
2. Click on any valid terrain (grass, fairway, rough, path)
3. Tree is placed and $20 is deducted from your account
4. Press Cancel to exit placement mode

### Placing Buildings
1. Click the "Place Building" button (BuildingBtn) in the tool panel
2. A building selection menu appears
3. Select a building type
4. Click on valid terrain to place (depends on building type)
5. Building is placed and cost is deducted

**Building Placement Rules:**
- Most buildings can only be placed on grass
- Some buildings (marked as `placeable_on_course`) can be placed on fairway, path, etc.
- Buildings occupy multiple tiles based on their size
- All tiles in the building footprint must be valid

## Buildings Data Format

The `data/buildings.json` file defines available buildings:

```json
{
  "buildings": {
    "clubhouse": {
      "id": "clubhouse",
      "name": "Clubhouse",
      "size": [4, 4],
      "cost": 10000,
      "required": true
    },
    "pro_shop": {
      "id": "pro_shop",
      "name": "Pro Shop",
      "size": [2, 2],
      "cost": 5000,
      "income_per_golfer": 15
    }
  }
}
```

**Building Properties:**
- `id` - Unique identifier
- `name` - Display name
- `size` - [width, height] in grid tiles
- `cost` - Placement cost in dollars
- `placeable_on_course` - Can be placed on grass only (default) or also on fairway/path
- `income_per_golfer` - Revenue generated (optional)
- `required` - Must be placed to start (optional)

## Terrain Compatibility

### Tree Placement (Cost: $20)
- ✓ Grass
- ✓ Fairway
- ✓ Rough
- ✓ Heavy Rough
- ✓ Path

### Standard Building Placement
- ✓ Grass only

### Placeable-on-Course Buildings
- ✓ Grass
- ✓ Fairway
- ✓ Rough
- ✓ Path

## Extension Points

### Adding More Tree Types
Edit the `TREE_PROPERTIES` dictionary in `scripts/entities/tree.gd`:

```gdscript
"ash": {"name": "Ash Tree", "cost": 23, "height": 3.5, "width": 2.2, "color": Color(0.25, 0.45, 0.22)},
```

### Adding More Buildings
1. Add entries to `data/buildings.json`
2. Optionally add sprites to `resources/sprites/buildings/`
3. Buildings are automatically loaded at runtime

### Custom Placement Validation
Override `can_place_at()` in PlacementManager for custom rules:

```gdscript
func _can_place_tree(grid_pos: Vector2i, terrain_grid: TerrainGrid) -> bool:
    # Custom validation logic
    pass
```

## Saving and Loading

Both buildings and trees are serialized via EntityLayer:

```gdscript
var save_data = entity_layer.serialize()
# Returns: {"buildings": {...}, "trees": {...}}
```

Buildings and trees should be saved alongside terrain data in your save system.

## Future Enhancements

Possible improvements:
1. Building sprites and animations
2. Tree seasonal appearance
3. Demolition with refund
4. Building upgrade system
5. Building maintenance costs
6. Landscaping tools (fences, paths decoration)
7. Multi-tile building placement visual guide
8. Building collision detection for golf balls
