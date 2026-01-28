# Quick Integration Guide

## Adding UI Buttons

To use the building and tree placement features, you need to add buttons to your ToolPanel in the main scene.

### In the Scene Editor (main.tscn)

1. **Add Tree Button**
   - Select the ToolPanel (VBoxContainer)
   - Add a new Button child named "TreeBtn"
   - Set the text to "Plant Tree" or similar
   - The button will automatically connect via the `_connect_ui_buttons()` method

2. **Add Building Button**
   - Select the ToolPanel (VBoxContainer)
   - Add a new Button child named "BuildingBtn"
   - Set the text to "Place Building" or similar
   - The button will automatically connect via the `_connect_ui_buttons()` method

### GDScript Alternative

If you prefer to add buttons programmatically:

```gdscript
# In main.gd, in the _initialize_game() or _ready() function:

var tree_btn = Button.new()
tree_btn.name = "TreeBtn"
tree_btn.text = "Plant Tree"
tree_btn.pressed.connect(_on_tree_placement_pressed)
tool_panel.add_child(tree_btn)

var building_btn = Button.new()
building_btn.name = "BuildingBtn"
building_btn.text = "Place Building"
building_btn.pressed.connect(_on_building_placement_pressed)
tool_panel.add_child(building_btn)
```

## Optional: Add Placement Preview

To show a preview before placement:

1. Create a PlacementPreview node in your main scene
2. Connect it in main.gd:

```gdscript
@onready var placement_preview: PlacementPreview = $PlacementPreview

func _ready() -> void:
    # ... existing code ...
    placement_preview.set_terrain_grid(terrain_grid)
    placement_preview.set_placement_manager(placement_manager)
    placement_preview.set_camera(camera)
```

## Testing the System

### Manual Test Steps

1. Start the game
2. Click "Plant Tree"
3. Click on a grass tile - a tree should appear and $20 should be deducted
4. Click "Plant Tree" again
5. Click "Cancel" to exit placement mode
6. Click "Place Building"
7. Select a building from the menu
8. Click on a grass tile - building should appear and cost should be deducted

### Expected Behavior

- **Cost Verification**: If you have insufficient funds, placement fails
- **Terrain Validation**: Can't place on water, bunkers, or other invalid terrain
- **Building Size**: Multi-tile buildings should occupy all specified tiles
- **Persistence**: Entities should remain after placing other items

## Troubleshooting

### Buildings/Trees Not Appearing
- Check that EntityLayer node is properly added to the scene
- Verify building_registry is initialized in _ready()
- Check console for error messages

### Placement Failing Silently
- Check money amount - not enough funds?
- Check terrain type - can you place there?
- Look at console messages for specific errors

### Buttons Not Working
- Verify button names match exactly: "TreeBtn" and "BuildingBtn"
- Check that _connect_ui_buttons() is called in _ready()
- Confirm buttons exist before trying to connect (optional buttons use has_node())

## Accessing Placed Entities

After placement, you can access buildings and trees:

```gdscript
# Get all buildings
var all_buildings = entity_layer.get_all_buildings()

# Get specific building
var building = entity_layer.get_building_at(Vector2i(10, 5))

# Get all trees
var all_trees = entity_layer.get_all_trees()

# Get specific tree
var tree = entity_layer.get_tree_at(Vector2i(15, 20))

# Remove an entity
entity_layer.remove_building(Vector2i(10, 5))
entity_layer.remove_tree(Vector2i(15, 20))
```

## Extending Functionality

### Add Custom Building Types

Edit `data/buildings.json`:

```json
"my_custom_building": {
    "id": "my_custom_building",
    "name": "My Custom Building",
    "size": [3, 2],
    "cost": 7500,
    "placeable_on_course": true,
    "income_per_golfer": 10
}
```

Then place it:

```gdscript
placement_manager.start_building_placement("my_custom_building", 
    building_registry.get_building("my_custom_building"))
```

### Add Custom Tree Types

Edit the TREE_PROPERTIES in `scripts/entities/tree.gd`:

```gdscript
"willow": {
    "name": "Willow Tree", 
    "cost": 28, 
    "height": 3.8, 
    "width": 2.8, 
    "color": Color(0.3, 0.5, 0.3)
}
```

Then place it:

```gdscript
entity_layer.place_tree(Vector2i(10, 10), "willow")
```

## Events and Signals

Listen for placement events:

```gdscript
# When entity_layer emits these signals:
entity_layer.building_placed.connect(_on_building_placed)
entity_layer.tree_placed.connect(_on_tree_placed)

func _on_building_placed(building: Building, cost: int):
    print("Building placed! Cost: $%d" % cost)

func _on_tree_placed(tree: Tree, cost: int):
    print("Tree placed! Cost: $%d" % cost)
```
