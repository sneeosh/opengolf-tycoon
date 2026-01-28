# Building and Tree Placement - Code Examples

## Example 1: Programmatic Building Placement

```gdscript
# Place a building directly from code
func spawn_tutorial_buildings() -> void:
    if not building_registry or not entity_layer:
        return
    
    # Place a clubhouse at grid position (10, 10)
    var clubhouse = entity_layer.place_building("clubhouse", Vector2i(10, 10), building_registry)
    
    # Place a pro shop at (15, 10)
    var pro_shop = entity_layer.place_building("pro_shop", Vector2i(15, 10), building_registry)
    
    # Deduct costs if this is for tutorial demonstration
    var clubhouse_cost = building_registry.get_building_cost("clubhouse")
    var pro_shop_cost = building_registry.get_building_cost("pro_shop")
    GameManager.modify_money(-(clubhouse_cost + pro_shop_cost))
```

## Example 2: Placing Trees in a Pattern

```gdscript
# Plant trees in a line to create a tree alley
func create_tree_alley(start_pos: Vector2i, length: int, tree_type: String = "oak") -> void:
    for i in range(length):
        var pos = start_pos + Vector2i(i, 0)
        if terrain_grid.is_valid_position(pos):
            var tile_type = terrain_grid.get_tile(pos)
            # Only plant on grass and fairway
            if tile_type in [TerrainTypes.Type.GRASS, TerrainTypes.Type.FAIRWAY]:
                var tree = entity_layer.place_tree(pos, tree_type)
                GameManager.modify_money(-20)  # Tree cost
```

## Example 3: Querying Placed Entities

```gdscript
# Get all buildings and their information
func print_course_summary() -> void:
    var buildings = entity_layer.get_all_buildings()
    var trees = entity_layer.get_all_trees()
    
    print("Course Summary:")
    print("Buildings: %d" % buildings.size())
    for building in buildings:
        var info = building.get_building_info()
        print("  - %s at (%d, %d)" % [info.type, info.position.x, info.position.y])
    
    print("Trees: %d" % trees.size())
    print("Total entities: %d" % (buildings.size() + trees.size()))
    
    # Calculate total value
    var total_cost = 0
    for building in buildings:
        total_cost += building.building_data.get("cost", 0)
    total_cost += trees.size() * 20  # Trees cost $20 each
    print("Total invested: $%d" % total_cost)
```

## Example 4: Finding Buildings in an Area

```gdscript
# Find all buildings within a rectangular area
func find_buildings_in_area(top_left: Vector2i, bottom_right: Vector2i) -> Array:
    return entity_layer.get_buildings_in_area(top_left, bottom_right)

# Usage: Find buildings near the clubhouse
func locate_nearby_buildings() -> void:
    var clubhouse_area = Rect2i(Vector2i(5, 5), Vector2i(20, 20))
    var nearby = entity_layer.get_buildings_in_area(
        clubhouse_area.position,
        clubhouse_area.position + clubhouse_area.size
    )
    print("Found %d buildings near clubhouse" % nearby.size())
```

## Example 5: Listening to Placement Events

```gdscript
# In your main scene or game controller
func _ready() -> void:
    entity_layer.building_placed.connect(_on_building_placed)
    entity_layer.tree_placed.connect(_on_tree_placed)
    entity_layer.building_removed.connect(_on_building_removed)
    entity_layer.tree_removed.connect(_on_tree_removed)

func _on_building_placed(building: Building, cost: int) -> void:
    print("Building '%s' placed at %s for $%d" % [
        building.building_type,
        building.grid_position,
        cost
    ])
    # Could trigger sounds, animations, notifications, etc.
    EventBus.notify("Building placed!", "success")

func _on_tree_placed(tree: Tree, cost: int) -> void:
    print("Tree '%s' placed at %s for $%d" % [
        tree.tree_type,
        tree.grid_position,
        cost
    ])

func _on_building_removed(grid_pos: Vector2i) -> void:
    print("Building removed from %s" % grid_pos)

func _on_tree_removed(grid_pos: Vector2i) -> void:
    print("Tree removed from %s" % grid_pos)
```

## Example 6: Custom Placement Validation

```gdscript
# Extend PlacementManager to add custom rules
class_name CustomPlacementManager
extends PlacementManager

# Override to prevent buildings near water
func _can_place_building(grid_pos: Vector2i, terrain_grid: TerrainGrid) -> bool:
    # First check standard validation
    if not super._can_place_building(grid_pos, terrain_grid):
        return false
    
    var size = current_placement_data.get("size", [1, 1])
    var width = size[0] as int
    var height = size[1] as int
    
    # Check for water in surrounding tiles
    for x in range(-1, width + 1):
        for y in range(-1, height + 1):
            var check_pos = grid_pos + Vector2i(x, y)
            if terrain_grid.is_valid_position(check_pos):
                var tile_type = terrain_grid.get_tile(check_pos)
                if tile_type == TerrainTypes.Type.WATER:
                    return false
    
    return true
```

## Example 7: Building Demolition System

```gdscript
# Add demolition functionality
func demolish_building(grid_pos: Vector2i, refund_percentage: float = 0.5) -> void:
    var building = entity_layer.get_building_at(grid_pos)
    if not building:
        EventBus.notify("No building to demolish", "error")
        return
    
    var building_info = building.get_building_info()
    var original_cost = building_info.get("cost", 0)
    var refund = int(original_cost * refund_percentage)
    
    # Remove the building
    entity_layer.remove_building(grid_pos)
    
    # Apply refund
    GameManager.modify_money(refund)
    EventBus.log_transaction("Building demolition refund", refund)
    EventBus.notify("Building demolished. Refund: $%d" % refund, "success")

# Usage in mouse click handler
func _on_demolish_mode_click(grid_pos: Vector2i) -> void:
    demolish_building(grid_pos, 0.75)  # 75% refund
```

## Example 8: Save and Load System

```gdscript
# Save buildings and trees to a file
func save_entities() -> void:
    var entity_data = entity_layer.serialize()
    
    var save_dict = {
        "buildings": entity_data.get("buildings", {}),
        "trees": entity_data.get("trees", {})
    }
    
    var json = JSON.stringify(save_dict)
    var file = FileAccess.open("user://course_entities.json", FileAccess.WRITE)
    if file:
        file.store_string(json)
        print("Entities saved")

# Load buildings and trees from file
func load_entities() -> void:
    var file = FileAccess.open("user://course_entities.json", FileAccess.READ)
    if file == null:
        print("No entities to load")
        return
    
    var json_string = file.get_as_text()
    var data = JSON.parse_string(json_string)
    
    if data == null:
        print("Failed to parse entities")
        return
    
    # Load buildings
    var buildings = data.get("buildings", {})
    for pos_str in buildings.keys():
        var building_data = buildings[pos_str]
        var pos = _parse_grid_pos(pos_str)
        entity_layer.place_building(
            building_data.get("type", ""),
            pos,
            building_registry
        )
    
    # Load trees
    var trees = data.get("trees", {})
    for pos_str in trees.keys():
        var tree_data = trees[pos_str]
        var pos = _parse_grid_pos(pos_str)
        entity_layer.place_tree(pos, tree_data.get("type", "oak"))
    
    print("Entities loaded")

func _parse_grid_pos(pos_str: String) -> Vector2i:
    var parts = pos_str.split(",")
    return Vector2i(int(parts[0]), int(parts[1]))
```

## Example 9: Building-Specific Income

```gdscript
# Calculate income from income-generating buildings
func calculate_daily_building_income() -> int:
    var total_income = 0
    var buildings = entity_layer.get_all_buildings()
    var golfers_on_course = GameManager.get_active_golfers()  # Your method
    
    for building in buildings:
        var building_data = building.building_data
        var income_per_golfer = building_data.get("income_per_golfer", 0)
        if income_per_golfer > 0:
            total_income += income_per_golfer * golfers_on_course.size()
    
    return total_income

# Called daily
func _on_day_changed(new_day: int) -> void:
    var building_income = calculate_daily_building_income()
    if building_income > 0:
        GameManager.modify_money(building_income)
        EventBus.log_transaction("Building income", building_income)
```

## Example 10: Building Statistics Dashboard

```gdscript
# Display building statistics in UI
func update_building_stats() -> void:
    var buildings = entity_layer.get_all_buildings()
    var trees = entity_layer.get_all_trees()
    
    # Group buildings by type
    var building_counts: Dictionary = {}
    for building in buildings:
        var building_type = building.building_type
        building_counts[building_type] = building_counts.get(building_type, 0) + 1
    
    # Group trees by type
    var tree_counts: Dictionary = {}
    for tree in trees:
        var tree_type = tree.tree_type
        tree_counts[tree_type] = tree_counts.get(tree_type, 0) + 1
    
    # Update UI labels
    var stats_text = ""
    
    stats_text += "BUILDINGS:\n"
    for building_type in building_counts.keys():
        var count = building_counts[building_type]
        var name = building_registry.get_building_name(building_type)
        stats_text += "  %s: %d\n" % [name, count]
    
    stats_text += "\nTREES:\n"
    for tree_type in tree_counts.keys():
        var count = tree_counts[tree_type]
        stats_text += "  %s: %d\n" % [tree_type.capitalize(), count]
    
    stats_text += "\nTOTAL:\n"
    stats_text += "  Buildings: %d\n" % buildings.size()
    stats_text += "  Trees: %d\n" % trees.size()
    
    # Set UI text (assuming you have a stats_label)
    if has_node("UI/StatsLabel"):
        $UI/StatsLabel.text = stats_text
```

These examples demonstrate:
- Direct placement and manipulation
- Event listening and reaction
- Querying and searching entities
- Data persistence (save/load)
- Game mechanics integration (income, demolition)
- UI updates and reporting

Feel free to adapt these patterns to your specific game needs!
