extends RefCounted
class_name SculptedTerrain
## Rounded, editable landforms using the existing saved elevation grid.
static func stamp(grid: TerrainGrid, center: Vector2i, radius: int, amount: int, entities: EntityLayer = null) -> Array:
	var changes: Array = []
	if not grid or radius < 1:
		return changes
	for x in range(-radius, radius + 1):
		for y in range(-radius, radius + 1):
			var pos := center + Vector2i(x, y)
			if not grid.is_valid_position(pos):
				continue
			if GameManager.land_manager and not GameManager.land_manager.is_tile_owned(pos):
				continue
			if entities and entities.is_tile_occupied_by_building(pos):
				continue
			if grid.get_tile(pos) in [TerrainTypes.Type.WATER, TerrainTypes.Type.PATH, TerrainTypes.Type.OUT_OF_BOUNDS]:
				continue
			var distance := Vector2(x, y).length() / float(radius)
			var falloff := pow(maxf(0.0, 1.0 - distance * distance), 2.0)
			var delta := roundi(float(amount) * falloff)
			var old := grid.get_elevation(pos)
			var height := clampi(old + delta, -5, 5)
			if height != old:
				grid.set_elevation(pos, height)
				changes.append({"position": pos, "old_elevation": old, "new_elevation": height})
	return changes
