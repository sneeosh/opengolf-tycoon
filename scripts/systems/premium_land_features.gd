extends RefCounted
class_name PremiumLandFeatures
## PremiumLandFeatures - Generates terrain features for premium/elite parcels
##
## When a premium or elite parcel is purchased, this system paints themed
## terrain features (water, elevation, trees, rocks, paths) on the parcel.
## Features are deterministic per parcel position and theme.

## Generate premium parcel features: water feature, elevation, trees, rocks
static func generate_premium_features(
	terrain_grid: TerrainGrid,
	entity_layer: EntityLayer,
	parcel: Vector2i,
	tile_rect: Rect2i,
	theme: int,
	seed_value: int = 0
) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value if seed_value != 0 else (parcel.x * 1000 + parcel.y + theme * 10000)

	var template = _get_premium_template(theme)

	# Clear existing entities first
	_clear_parcel_entities(entity_layer, tile_rect)

	# Paint water feature
	if template.water_tiles > 0:
		var water_center = Vector2i(
			tile_rect.position.x + tile_rect.size.x / 2 + rng.randi_range(-3, 3),
			tile_rect.position.y + tile_rect.size.y / 2 + rng.randi_range(-3, 3)
		)
		if template.water_shape == "pond":
			_paint_pond(terrain_grid, water_center, rng, template.water_tiles)
		elif template.water_shape == "stream":
			_paint_stream(terrain_grid, tile_rect, rng)
		elif template.water_shape == "oasis":
			_paint_pond(terrain_grid, water_center, rng, template.water_tiles)
		elif template.water_shape == "lagoon":
			_paint_pond(terrain_grid, water_center, rng, template.water_tiles + 4)

	# Sculpt elevation
	if template.elevation_range.y > 0:
		_sculpt_elevation(terrain_grid, tile_rect, rng, template.elevation_range)

	# Place trees
	var tree_count = rng.randi_range(template.tree_count.x, template.tree_count.y)
	_place_trees(terrain_grid, entity_layer, tile_rect, rng, template.tree_types, tree_count)

	# Place rocks
	var rock_count = rng.randi_range(template.rock_count.x, template.rock_count.y)
	_place_rocks(terrain_grid, entity_layer, tile_rect, rng, rock_count)


## Generate elite parcel features: all premium features + paths + fairway suggestions
static func generate_elite_features(
	terrain_grid: TerrainGrid,
	entity_layer: EntityLayer,
	parcel: Vector2i,
	tile_rect: Rect2i,
	theme: int,
	seed_value: int = 0
) -> void:
	# Start with premium features
	generate_premium_features(terrain_grid, entity_layer, parcel, tile_rect, theme, seed_value)

	var rng = RandomNumberGenerator.new()
	rng.seed = (seed_value if seed_value != 0 else (parcel.x * 1000 + parcel.y + theme * 10000)) + 9999

	# Add cart paths along edges
	_paint_paths(terrain_grid, tile_rect, rng)

	# Add rough/fairway suggestion corridors
	_paint_fairway_suggestions(terrain_grid, tile_rect, rng)


static func _get_premium_template(theme: int) -> Dictionary:
	match theme:
		CourseTheme.Type.PARKLAND:
			return {
				water_shape = "pond",
				water_tiles = 12,
				elevation_range = Vector2i(1, 2),
				tree_types = ["oak", "oak", "birch", "maple"],
				tree_count = Vector2i(6, 10),
				rock_count = Vector2i(1, 3),
			}
		CourseTheme.Type.DESERT:
			return {
				water_shape = "oasis",
				water_tiles = 8,
				elevation_range = Vector2i(0, 1),
				tree_types = ["cactus", "cactus", "dead_tree", "palm"],
				tree_count = Vector2i(4, 7),
				rock_count = Vector2i(4, 8),
			}
		CourseTheme.Type.LINKS:
			return {
				water_shape = "stream",
				water_tiles = 6,
				elevation_range = Vector2i(1, 2),
				tree_types = ["fescue", "heather", "bush"],
				tree_count = Vector2i(3, 6),
				rock_count = Vector2i(2, 5),
			}
		CourseTheme.Type.MOUNTAIN:
			return {
				water_shape = "stream",
				water_tiles = 8,
				elevation_range = Vector2i(2, 3),
				tree_types = ["pine", "pine", "birch"],
				tree_count = Vector2i(8, 14),
				rock_count = Vector2i(5, 10),
			}
		CourseTheme.Type.CITY:
			return {
				water_shape = "pond",
				water_tiles = 8,
				elevation_range = Vector2i(0, 1),
				tree_types = ["oak", "maple", "bush"],
				tree_count = Vector2i(4, 8),
				rock_count = Vector2i(1, 3),
			}
		CourseTheme.Type.RESORT:
			return {
				water_shape = "lagoon",
				water_tiles = 14,
				elevation_range = Vector2i(1, 2),
				tree_types = ["palm", "palm", "oak", "bush"],
				tree_count = Vector2i(6, 12),
				rock_count = Vector2i(1, 3),
			}
		CourseTheme.Type.HEATHLAND:
			return {
				water_shape = "pond",
				water_tiles = 6,
				elevation_range = Vector2i(1, 2),
				tree_types = ["pine", "birch", "heather", "bush"],
				tree_count = Vector2i(4, 8),
				rock_count = Vector2i(2, 5),
			}
		CourseTheme.Type.WOODLAND:
			return {
				water_shape = "pond",
				water_tiles = 8,
				elevation_range = Vector2i(1, 2),
				tree_types = ["pine", "oak", "birch", "maple"],
				tree_count = Vector2i(10, 16),
				rock_count = Vector2i(2, 5),
			}
		CourseTheme.Type.TROPICAL:
			return {
				water_shape = "lagoon",
				water_tiles = 12,
				elevation_range = Vector2i(1, 3),
				tree_types = ["palm", "palm", "dead_tree", "bush"],
				tree_count = Vector2i(6, 10),
				rock_count = Vector2i(5, 10),
			}
		CourseTheme.Type.MARSHLAND:
			return {
				water_shape = "pond",
				water_tiles = 16,
				elevation_range = Vector2i(0, 1),
				tree_types = ["oak", "cattails", "bush", "pine"],
				tree_count = Vector2i(5, 9),
				rock_count = Vector2i(1, 3),
			}
	# Fallback
	return {
		water_shape = "pond",
		water_tiles = 10,
		elevation_range = Vector2i(1, 2),
		tree_types = ["oak", "pine"],
		tree_count = Vector2i(5, 8),
		rock_count = Vector2i(2, 4),
	}


static func _clear_parcel_entities(entity_layer: EntityLayer, tile_rect: Rect2i) -> void:
	if not entity_layer:
		return
	var tree_positions: Array[Vector2i] = []
	for pos in entity_layer.trees.keys():
		if tile_rect.has_point(pos):
			tree_positions.append(pos)
	for pos in tree_positions:
		entity_layer.remove_tree(pos)

	var rock_positions: Array[Vector2i] = []
	for pos in entity_layer.rocks.keys():
		if tile_rect.has_point(pos):
			rock_positions.append(pos)
	for pos in rock_positions:
		entity_layer.remove_rock(pos)


static func _paint_pond(terrain_grid: TerrainGrid, center: Vector2i, rng: RandomNumberGenerator, approx_tiles: int) -> void:
	# Random walk from center to create organic pond shape
	var painted: Dictionary = {}
	var current = center

	for i in range(approx_tiles * 2):
		if painted.size() >= approx_tiles:
			break
		if terrain_grid.is_valid_position(current):
			terrain_grid.set_tile_natural(current, TerrainTypes.Type.WATER)
			painted[current] = true
			# Also paint immediate neighbors occasionally for width
			if rng.randf() < 0.4:
				var neighbor = current + [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)][rng.randi() % 4]
				if terrain_grid.is_valid_position(neighbor):
					terrain_grid.set_tile_natural(neighbor, TerrainTypes.Type.WATER)
					painted[neighbor] = true
		# Random walk step
		var dirs = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
		current = current + dirs[rng.randi() % 4]


static func _paint_stream(terrain_grid: TerrainGrid, tile_rect: Rect2i, rng: RandomNumberGenerator) -> void:
	# Paint a meandering stream across the parcel
	var start_x = tile_rect.position.x + rng.randi_range(2, 5)
	var end_x = tile_rect.position.x + tile_rect.size.x - rng.randi_range(2, 5)
	var y = tile_rect.position.y + tile_rect.size.y / 2

	for x in range(start_x, end_x + 1):
		y += rng.randi_range(-1, 1)
		y = clampi(y, tile_rect.position.y + 2, tile_rect.position.y + tile_rect.size.y - 3)
		var pos = Vector2i(x, y)
		if terrain_grid.is_valid_position(pos):
			terrain_grid.set_tile_natural(pos, TerrainTypes.Type.WATER)
		# Width variation
		if rng.randf() < 0.5:
			var neighbor = Vector2i(x, y + 1)
			if terrain_grid.is_valid_position(neighbor):
				terrain_grid.set_tile_natural(neighbor, TerrainTypes.Type.WATER)


static func _sculpt_elevation(terrain_grid: TerrainGrid, tile_rect: Rect2i, rng: RandomNumberGenerator, elev_range: Vector2i) -> void:
	# Create gentle hills using a simple noise-like pattern
	var cx = tile_rect.position.x + tile_rect.size.x / 2
	var cy = tile_rect.position.y + tile_rect.size.y / 2
	var max_radius = tile_rect.size.x / 2.0

	for x in range(tile_rect.position.x + 2, tile_rect.position.x + tile_rect.size.x - 2):
		for y in range(tile_rect.position.y + 2, tile_rect.position.y + tile_rect.size.y - 2):
			var pos = Vector2i(x, y)
			if not terrain_grid.is_valid_position(pos):
				continue
			# Don't change elevation of water tiles
			if terrain_grid.get_tile(pos) == TerrainTypes.Type.WATER:
				continue
			var dist = Vector2(x - cx, y - cy).length()
			var falloff = 1.0 - (dist / max_radius)
			if falloff <= 0:
				continue
			var elev = int(falloff * rng.randf_range(float(elev_range.x), float(elev_range.y) + 0.5))
			if elev > 0:
				terrain_grid.set_elevation(pos, elev)


static func _place_trees(terrain_grid: TerrainGrid, entity_layer: EntityLayer, tile_rect: Rect2i, rng: RandomNumberGenerator, tree_types: Array, count: int) -> void:
	if not entity_layer or tree_types.is_empty():
		return
	var placed = 0
	var attempts = 0
	while placed < count and attempts < count * 5:
		attempts += 1
		var x = rng.randi_range(tile_rect.position.x + 1, tile_rect.position.x + tile_rect.size.x - 2)
		var y = rng.randi_range(tile_rect.position.y + 1, tile_rect.position.y + tile_rect.size.y - 2)
		var pos = Vector2i(x, y)
		if not terrain_grid.is_valid_position(pos):
			continue
		# Don't place on water
		var current = terrain_grid.get_tile(pos)
		if current == TerrainTypes.Type.WATER or current == TerrainTypes.Type.PATH:
			continue
		# Don't place on existing entities
		if entity_layer.trees.has(pos) or entity_layer.rocks.has(pos):
			continue
		var tree_type = tree_types[rng.randi() % tree_types.size()]
		entity_layer.place_tree(pos, tree_type)
		placed += 1


static func _place_rocks(terrain_grid: TerrainGrid, entity_layer: EntityLayer, tile_rect: Rect2i, rng: RandomNumberGenerator, count: int) -> void:
	if not entity_layer:
		return
	var placed = 0
	var attempts = 0
	var sizes = ["small", "medium", "large"]
	while placed < count and attempts < count * 5:
		attempts += 1
		var x = rng.randi_range(tile_rect.position.x + 1, tile_rect.position.x + tile_rect.size.x - 2)
		var y = rng.randi_range(tile_rect.position.y + 1, tile_rect.position.y + tile_rect.size.y - 2)
		var pos = Vector2i(x, y)
		if not terrain_grid.is_valid_position(pos):
			continue
		var current = terrain_grid.get_tile(pos)
		if current == TerrainTypes.Type.WATER or current == TerrainTypes.Type.PATH:
			continue
		if entity_layer.trees.has(pos) or entity_layer.rocks.has(pos):
			continue
		var rock_size = sizes[rng.randi() % sizes.size()]
		entity_layer.place_rock(pos, rock_size)
		placed += 1


static func _paint_paths(terrain_grid: TerrainGrid, tile_rect: Rect2i, rng: RandomNumberGenerator) -> void:
	# Paint path tiles along one or two edges of the parcel
	var edge = rng.randi() % 4  # 0=top, 1=right, 2=bottom, 3=left

	match edge:
		0:  # Top edge path
			var y = tile_rect.position.y + 1
			for x in range(tile_rect.position.x + 2, tile_rect.position.x + tile_rect.size.x - 2):
				var pos = Vector2i(x, y)
				if terrain_grid.is_valid_position(pos) and terrain_grid.get_tile(pos) != TerrainTypes.Type.WATER:
					terrain_grid.set_tile_natural(pos, TerrainTypes.Type.PATH)
		1:  # Right edge path
			var x = tile_rect.position.x + tile_rect.size.x - 2
			for y in range(tile_rect.position.y + 2, tile_rect.position.y + tile_rect.size.y - 2):
				var pos = Vector2i(x, y)
				if terrain_grid.is_valid_position(pos) and terrain_grid.get_tile(pos) != TerrainTypes.Type.WATER:
					terrain_grid.set_tile_natural(pos, TerrainTypes.Type.PATH)
		2:  # Bottom edge path
			var y = tile_rect.position.y + tile_rect.size.y - 2
			for x in range(tile_rect.position.x + 2, tile_rect.position.x + tile_rect.size.x - 2):
				var pos = Vector2i(x, y)
				if terrain_grid.is_valid_position(pos) and terrain_grid.get_tile(pos) != TerrainTypes.Type.WATER:
					terrain_grid.set_tile_natural(pos, TerrainTypes.Type.PATH)
		3:  # Left edge path
			var x = tile_rect.position.x + 1
			for y in range(tile_rect.position.y + 2, tile_rect.position.y + tile_rect.size.y - 2):
				var pos = Vector2i(x, y)
				if terrain_grid.is_valid_position(pos) and terrain_grid.get_tile(pos) != TerrainTypes.Type.WATER:
					terrain_grid.set_tile_natural(pos, TerrainTypes.Type.PATH)


static func _paint_fairway_suggestions(terrain_grid: TerrainGrid, tile_rect: Rect2i, rng: RandomNumberGenerator) -> void:
	# Paint a rough/fairway corridor suggestion through the parcel
	var start = Vector2i(
		tile_rect.position.x + rng.randi_range(3, 6),
		tile_rect.position.y + tile_rect.size.y / 2
	)
	var end_pos = Vector2i(
		tile_rect.position.x + tile_rect.size.x - rng.randi_range(3, 6),
		tile_rect.position.y + tile_rect.size.y / 2 + rng.randi_range(-4, 4)
	)

	var direction = Vector2(end_pos - start).normalized()
	var distance = Vector2(start).distance_to(Vector2(end_pos))
	var perp = Vector2(-direction.y, direction.x)

	for i in range(int(distance) + 1):
		var center = Vector2(start) + direction * float(i)
		# Paint rough border (width 4)
		for w in range(-2, 3):
			var tile_pos = Vector2i(int(round(center.x + perp.x * w)), int(round(center.y + perp.y * w)))
			if terrain_grid.is_valid_position(tile_pos):
				var current = terrain_grid.get_tile(tile_pos)
				if current == TerrainTypes.Type.GRASS or current == TerrainTypes.Type.EMPTY:
					if abs(w) >= 2:
						terrain_grid.set_tile_natural(tile_pos, TerrainTypes.Type.ROUGH)
					else:
						terrain_grid.set_tile_natural(tile_pos, TerrainTypes.Type.FAIRWAY)
