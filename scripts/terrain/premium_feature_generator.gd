extends RefCounted
class_name PremiumFeatureGenerator
## PremiumFeatureGenerator - Generates terrain features on Premium/Elite parcel purchase
##
## Called when a premium or elite parcel is purchased. Generates features within
## the parcel's 20x20 tile rect. Reuses NaturalTerrainGenerator patterns.
## Standard parcels get no special treatment.

## Generate terrain features for a purchased premium/elite parcel.
## Call within begin_batch()/end_batch_quiet() for performance.
static func generate_for_parcel(
	parcel: Vector2i,
	terrain_grid: TerrainGrid,
	entity_layer: EntityLayer,
	rng: RandomNumberGenerator
) -> void:
	var lm = GameManager.land_manager
	if not lm:
		return
	var tier: int = lm.get_parcel_tier(parcel)
	var rect: Rect2i = lm.parcel_to_tile_rect(parcel)

	match tier:
		1:  # TIER_PREMIUM
			_generate_premium_features(rect, terrain_grid, entity_layer, rng)
		2:  # TIER_ELITE
			_generate_elite_features(rect, terrain_grid, entity_layer, rng)

	lm.mark_features_generated(parcel)


static func _get_premium_features(theme: int) -> Array:
	"""Returns feature types appropriate for premium parcels of this theme."""
	match theme:
		CourseTheme.Type.DESERT:    return ["elevation", "rough"]
		CourseTheme.Type.LINKS:     return ["rough", "elevation"]
		CourseTheme.Type.MOUNTAIN:  return ["elevation", "trees"]
		CourseTheme.Type.WOODLAND:  return ["trees", "rough"]
		CourseTheme.Type.MARSHLAND: return ["water", "rough"]
		CourseTheme.Type.HEATHLAND: return ["rough", "elevation"]
		_:                          return ["water", "trees"]  # PARKLAND, CITY, RESORT, TROPICAL


static func _get_elite_features(theme: int) -> Array:
	"""Returns feature types appropriate for elite parcels of this theme."""
	match theme:
		CourseTheme.Type.DESERT:    return ["elevation", "rough", "rocks"]
		CourseTheme.Type.LINKS:     return ["elevation", "rough", "trees"]
		CourseTheme.Type.MOUNTAIN:  return ["elevation", "trees", "water"]
		CourseTheme.Type.WOODLAND:  return ["trees", "rough", "elevation"]
		CourseTheme.Type.MARSHLAND: return ["water", "rough", "trees"]
		CourseTheme.Type.HEATHLAND: return ["rough", "elevation", "trees"]
		_:                          return ["water", "elevation", "trees"]


static func _generate_premium_features(
	bounds: Rect2i,
	terrain_grid: TerrainGrid,
	entity_layer: EntityLayer,
	rng: RandomNumberGenerator
) -> void:
	var features := _get_premium_features(GameManager.current_theme)
	for feature in features:
		match feature:
			"water":     _generate_scoped_pond(bounds, terrain_grid, rng, 3, 5)
			"trees":     _generate_scoped_tree_cluster(bounds, terrain_grid, entity_layer, rng, 4, 8)
			"elevation": _generate_scoped_elevation(bounds, terrain_grid, rng, 2)
			"rough":     _generate_scoped_rough(bounds, terrain_grid, rng, 1, 2)
			"rocks":     _generate_scoped_rocks(bounds, terrain_grid, entity_layer, rng, 3, 6)


static func _generate_elite_features(
	bounds: Rect2i,
	terrain_grid: TerrainGrid,
	entity_layer: EntityLayer,
	rng: RandomNumberGenerator
) -> void:
	var features := _get_elite_features(GameManager.current_theme)
	for feature in features:
		match feature:
			"water":     _generate_scoped_pond(bounds, terrain_grid, rng, 4, 7)
			"trees":     _generate_scoped_tree_cluster(bounds, terrain_grid, entity_layer, rng, 8, 16)
			"elevation": _generate_scoped_elevation(bounds, terrain_grid, rng, 4)
			"rough":     _generate_scoped_rough(bounds, terrain_grid, rng, 2, 4)
			"rocks":     _generate_scoped_rocks(bounds, terrain_grid, entity_layer, rng, 6, 12)


## Generate a natural-looking pond within the parcel bounds.
static func _generate_scoped_pond(
	bounds: Rect2i,
	terrain_grid: TerrainGrid,
	rng: RandomNumberGenerator,
	min_radius: int,
	max_radius: int
) -> void:
	# Place pond center within inner 60% of parcel to avoid edge clipping
	var margin := int(bounds.size.x * 0.2)
	var center_x := rng.randi_range(bounds.position.x + margin, bounds.end.x - margin)
	var center_y := rng.randi_range(bounds.position.y + margin, bounds.end.y - margin)
	var center := Vector2(center_x, center_y)
	var base_radius := rng.randf_range(min_radius, max_radius)

	for x in range(bounds.position.x, bounds.end.x):
		for y in range(bounds.position.y, bounds.end.y):
			var pos := Vector2i(x, y)
			if not terrain_grid.is_valid_position(pos):
				continue
			var dist := Vector2(x, y).distance_to(center)
			var angle := atan2(y - center_y, x - center_x)
			var noise_offset := sin(angle * 3) * 1.5 + cos(angle * 5) * 1.0
			if dist <= base_radius + noise_offset:
				terrain_grid.set_tile_natural(pos, TerrainTypes.Type.WATER)
				terrain_grid.set_elevation(pos, -1)


## Generate a cluster of theme-appropriate trees within the parcel bounds.
static func _generate_scoped_tree_cluster(
	bounds: Rect2i,
	terrain_grid: TerrainGrid,
	entity_layer: EntityLayer,
	rng: RandomNumberGenerator,
	min_trees: int,
	max_trees: int
) -> void:
	var tree_types := CourseTheme.get_tree_types(GameManager.current_theme)
	var waterside_only: Array = ["cattails"]
	tree_types = tree_types.filter(func(t): return t not in waterside_only)
	if tree_types.is_empty():
		return

	var target_count := rng.randi_range(min_trees, max_trees)
	var placed := 0
	var attempts := 0
	var dominant_type: String = tree_types[rng.randi_range(0, tree_types.size() - 1)]

	while placed < target_count and attempts < target_count * 5:
		attempts += 1
		var x := rng.randi_range(bounds.position.x, bounds.end.x - 1)
		var y := rng.randi_range(bounds.position.y, bounds.end.y - 1)
		var pos := Vector2i(x, y)

		if not terrain_grid.is_valid_position(pos):
			continue
		var tile := terrain_grid.get_tile(pos)
		if tile == TerrainTypes.Type.WATER or tile == TerrainTypes.Type.FLOWER_BED:
			continue
		if entity_layer.get_tree_at(pos) != null or entity_layer.get_rock_at(pos) != null:
			continue

		var tree_type := dominant_type
		if rng.randf() < 0.3:
			tree_type = tree_types[rng.randi_range(0, tree_types.size() - 1)]

		entity_layer.place_tree(pos, tree_type)
		placed += 1


## Generate elevation variation within the parcel bounds using Simplex noise.
static func _generate_scoped_elevation(
	bounds: Rect2i,
	terrain_grid: TerrainGrid,
	rng: RandomNumberGenerator,
	max_elevation: int
) -> void:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.seed = rng.randi()
	noise.frequency = 0.06  # Smaller features within parcel

	for x in range(bounds.position.x, bounds.end.x):
		for y in range(bounds.position.y, bounds.end.y):
			var pos := Vector2i(x, y)
			if not terrain_grid.is_valid_position(pos):
				continue
			# Skip water tiles
			if terrain_grid.get_tile(pos) == TerrainTypes.Type.WATER:
				continue
			var noise_value := noise.get_noise_2d(float(x), float(y))
			var elevation := roundi(noise_value * (max_elevation + 0.3))
			elevation = clampi(elevation, -max_elevation, max_elevation)
			if elevation != 0:
				# Add to existing elevation rather than replacing
				var current := terrain_grid.get_elevation(pos)
				var new_elev := clampi(current + elevation, -5, 5)
				if new_elev != current:
					terrain_grid.set_elevation(pos, new_elev)


## Generate rough and heavy rough patches within the parcel bounds.
static func _generate_scoped_rough(
	bounds: Rect2i,
	terrain_grid: TerrainGrid,
	rng: RandomNumberGenerator,
	min_patches: int,
	max_patches: int
) -> void:
	var patch_count := rng.randi_range(min_patches, max_patches)

	for _i in range(patch_count):
		var center_x := rng.randi_range(bounds.position.x + 2, bounds.end.x - 2)
		var center_y := rng.randi_range(bounds.position.y + 2, bounds.end.y - 2)
		var center := Vector2(center_x, center_y)
		var radius := rng.randf_range(3, 6)

		for x in range(bounds.position.x, bounds.end.x):
			for y in range(bounds.position.y, bounds.end.y):
				var pos := Vector2i(x, y)
				if not terrain_grid.is_valid_position(pos):
					continue
				if terrain_grid.get_tile(pos) != TerrainTypes.Type.GRASS:
					continue
				var dist := Vector2(x, y).distance_to(center)
				if dist <= radius:
					var edge_factor := 1.0 - (dist / radius)
					if rng.randf() < 0.5 + edge_factor * 0.4:
						var rough_type := TerrainTypes.Type.ROUGH
						if dist < radius * 0.4 and rng.randf() < 0.3:
							rough_type = TerrainTypes.Type.HEAVY_ROUGH
						terrain_grid.set_tile_natural(pos, rough_type)


## Generate scattered rocks within the parcel bounds.
static func _generate_scoped_rocks(
	bounds: Rect2i,
	terrain_grid: TerrainGrid,
	entity_layer: EntityLayer,
	rng: RandomNumberGenerator,
	min_rocks: int,
	max_rocks: int
) -> void:
	var target := rng.randi_range(min_rocks, max_rocks)
	var placed := 0
	var attempts := 0

	while placed < target and attempts < target * 5:
		attempts += 1
		var x := rng.randi_range(bounds.position.x, bounds.end.x - 1)
		var y := rng.randi_range(bounds.position.y, bounds.end.y - 1)
		var pos := Vector2i(x, y)

		if not terrain_grid.is_valid_position(pos):
			continue
		if terrain_grid.get_tile(pos) == TerrainTypes.Type.WATER:
			continue
		if entity_layer.get_tree_at(pos) != null or entity_layer.get_rock_at(pos) != null:
			continue

		var size_roll := rng.randf()
		var rock_size: String
		if size_roll < 0.5:
			rock_size = "small"
		elif size_roll < 0.85:
			rock_size = "medium"
		else:
			rock_size = "large"

		entity_layer.place_rock(pos, rock_size)
		placed += 1
