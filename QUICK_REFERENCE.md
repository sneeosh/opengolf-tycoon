# Building & Tree Placement - Quick Reference

## 🚀 Getting Started (5 Minutes)

1. **Add Buttons to Main Scene** (in scene editor):
   - Add `TreeBtn` (Button) to ToolPanel - text: "Plant Tree"
   - Add `BuildingBtn` (Button) to ToolPanel - text: "Place Building"

2. **Done!** The system automatically integrates.

## 🎮 How to Use (Player Perspective)

### Plant Trees
1. Click "Plant Tree" button
2. Click on grass/fairway/path
3. Tree placed! ($20)
4. Press Cancel to stop

### Place Buildings  
1. Click "Place Building" button
2. Select building type from menu
3. Click on valid terrain
4. Building placed! (cost varies)
5. Press Cancel to stop

## 💻 Quick Code Integration

### Access Placed Entities
```gdscript
# Get all buildings and trees
var buildings = entity_layer.get_all_buildings()
var trees = entity_layer.get_all_trees()

# Get specific entity
var building = entity_layer.get_building_at(Vector2i(10, 10))
var tree = entity_layer.get_tree_at(Vector2i(15, 20))
```

### Listen to Events
```gdscript
entity_layer.building_placed.connect(_on_building_placed)
entity_layer.tree_placed.connect(_on_tree_placed)
```

### Place Entities Programmatically
```gdscript
# Trees
entity_layer.place_tree(Vector2i(10, 10), "oak")

# Buildings
entity_layer.place_building("clubhouse", Vector2i(20, 20), building_registry)
```

### Remove Entities
```gdscript
entity_layer.remove_tree(Vector2i(10, 10))
entity_layer.remove_building(Vector2i(20, 20))
```

## 📋 Valid Placement Locations

### Trees ($20 each)
- ✓ Grass, Fairway, Rough, Heavy Rough, Path
- ✗ Water, Bunker, Green, Tee Box

### Buildings (varies by type)
- ✓ Standard buildings: Grass only
- ✓ Placeable-on-course buildings: Grass, Fairway, Path
- ✗ Multi-tile buildings: ALL tiles must be valid

## 🏗️ Building Types (From buildings.json)

| Building | Size | Cost | Notes |
|----------|------|------|-------|
| Clubhouse | 4×4 | $10,000 | Required |
| Pro Shop | 2×2 | $5,000 | On-course |
| Restaurant | 3×3 | $15,000 | On-course |
| Snack Bar | 1×1 | $2,000 | On-course |
| Driving Range | 6×3 | $8,000 | - |
| Cart Shed | 2×3 | $4,000 | - |
| Restroom | 1×1 | $1,500 | On-course |
| Bench | 1×1 | $200 | On-course |

## 🌳 Tree Types (Automatic)

| Tree | Cost | Size | Color |
|------|------|------|-------|
| Oak | $20 | 2×2 | Dark green |
| Pine | $18 | 1.5×4 | Forest green |
| Maple | $25 | 2.5×3.5 | Medium green |
| Birch | $22 | 1.8×3.2 | Light green |

## 🔧 File Locations

```
scripts/
├── managers/
│   ├── placement_manager.gd      ← Handles placement logic
│   └── building_registry.gd      ← Loads building data
├── entities/
│   ├── building.gd               ← Building entity
│   └── tree.gd                   ← Tree entity
├── course/
│   └── entity_layer.gd           ← Storage & management
└── ui/
    ├── building_selection_ui.gd  ← Building menu
    └── placement_preview.gd      ← Visual feedback
```

## 🐛 Common Issues

| Problem | Solution |
|---------|----------|
| Buttons don't work | Check names: `TreeBtn`, `BuildingBtn` |
| "Cannot place" error | Check terrain type - some terrains invalid |
| No money deducted | Verify GameManager is initialized |
| Trees/buildings invisible | Check EntityLayer is created in _ready() |

## 📚 Full Documentation

- `BUILDING_PLACEMENT_GUIDE.md` - Complete system docs
- `INTEGRATION_GUIDE.md` - Integration instructions
- `CODE_EXAMPLES.md` - 10 practical examples
- `SETUP_CHECKLIST.md` - Detailed setup steps
- `IMPLEMENTATION_SUMMARY.md` - Technical overview

## ⚡ Quick Stats

- **Lines of Code**: ~1,200
- **Classes Created**: 7
- **Files Created**: 7
- **Files Modified**: 1
- **Documentation Pages**: 5

## 🎯 What's Included

✅ Tree placement system
✅ Building placement with multi-tile support
✅ Terrain validation
✅ Cost system integration
✅ Building registry & data loading
✅ Entity serialization (save/load)
✅ Placement preview (optional)
✅ Signal-based architecture
✅ Comprehensive documentation
✅ Code examples

## 💡 Tips & Tricks

### Add More Building Types
Edit `data/buildings.json` and add new entries - automatic!

### Add More Tree Types
Edit `TREE_PROPERTIES` in `scripts/entities/tree.gd`

### Build Feature Walls
Plant trees in patterns to create scenic walls

### Layout Planning
Use placement preview to visualize before committing

### Budget Tracking
Access building cost via `building_registry.get_building_cost(type)`

### Demolition
Remove buildings: `entity_layer.remove_building(grid_pos)`

## 🚦 Setup Status

✅ Core system complete
✅ Main integration complete  
✅ Documentation complete
⏳ Scene UI buttons - YOUR TURN
⏳ Testing - YOUR TURN
⏳ Customization - YOUR TURN

## Next: Add UI Buttons!

1. Open `scenes/main/main.tscn` in editor
2. Add `TreeBtn` and `BuildingBtn` buttons to ToolPanel
3. Test by playing the scene
4. You're done!

---

**Questions?** See CODE_EXAMPLES.md or BUILDING_PLACEMENT_GUIDE.md
