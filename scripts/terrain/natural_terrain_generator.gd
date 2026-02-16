extends RefCounted
class_name NaturalTerrainGenerator
## NaturalTerrainGenerator - Generates natural terrain features for new courses
## Creates realistic undeveloped land that requires clearing before course construction

const DEFAULT_TREE_TYPES = ["oak", "pine", "maple", "birch"]
const ROCK_SIZES = ["small", "medium", "large"]

## Generate natural terrain for a new course, using theme parameters
static func generate(terrain_grid: TerrainGrid, entity_layer: EntityLayer, seed_value: int = 0) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value if seed_value != 0 else int(Time.get_unix_time_from_system())

	print("Generating natural terrain with seed: %d (theme: %s)" % [rng.seed, CourseTheme.get_theme_name(GameManager.current_theme)])

	# Generate elevation first (hills and valleys)
	_generate_elevation(terrain_grid, rng)

	# Generate large water bodies (coastal ocean for Links, lagoon for Resort)
	_generate_large_water_body(terrain_grid, rng)

	# Generate smaller water features (ponds)
	_generate_water(terrain_grid, rng)

	# Generate rough/heavy rough patches (overgrown undeveloped land)
	_generate_rough_patches(terrain_grid, rng)

	# Generate wildflower patches
	_generate_flower_patches(terrain_grid, rng)

	# Generate trees (clusters + scattered)
	_generate_trees(terrain_grid, entity_layer, rng)

	# Generate waterside vegetation (cattails, reeds near water)
	_generate_waterside_vegetation(terrain_grid, entity_layer, rng)

	# Generate rocks
	_generate_rocks(terrain_grid, entity_layer, rng)

	print("Natural terrain generation complete")

static func _generate_elevation(terrain_grid: TerrainGrid, rng: RandomNumberGenerator) -> void:
	## Generate natural elevation using FastNoiseLite for organic distribution
	var width = terrain_grid.grid_width
	var height = terrain_grid.grid_height

	# Use Godot's noise generator for natural-looking terrain
	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.seed = rng.randi()
	noise.frequency = 0.02  # Controls hill size (lower = larger hills)
	noise.fractal_octaves = 3  # Adds detail variation

	# Theme-aware elevation range
	var params = CourseTheme.get_generation_params(GameManager.current_theme)
	var elev_range = params.get("elevation_range", 3)

	# Apply noise-based elevation across the entire map
	for x in range(width):
		for y in range(height):
			var pos = Vector2i(x, y)
			var noise_value = noise.get_noise_2d(float(x), float(y))
			var elevation = roundi(noise_value * (elev_range + 0.5))
			elevation = clampi(elevation, -elev_range, elev_range)

			if elevation != 0:
				terrain_grid.set_elevation(pos, elevation)

static func _generate_large_water_body(terrain_grid: TerrainGrid, rng: RandomNumberGenerator) -> void:
	## Generate large water bodies - coastal ocean for Links, lagoon for Resort
	var params = CourseTheme.get_generation_params(GameManager.current_theme)
	if not params.get("large_water_body", false):
		return

	var width = terrain_grid.grid_width
	var height = terrain_grid.grid_height
	var water_type = params.get("large_water_edge", "random")
	var depth_range: Vector2i = params.get("large_water_depth", Vector2i(8, 14))

	if water_type == "interior":
		# Interior lagoon (Resort style) - large organic body in a random quadrant
		_generate_lagoon(terrain_grid, rng, width, height, depth_range)
	else:
		# Coastal water along a map edge (Links style)
		_generate_coastal_water(terrain_grid, rng, width, height, depth_range)

static func _generate_coastal_water(terrain_grid: TerrainGrid, rng: RandomNumberGenerator, width: int, height: int, depth_range: Vector2i) -> void:
	## Create a coastal ocean/sea along one edge of the map with an irregular shoreline
	var edge = rng.randi_range(0, 3)  # 0=north, 1=east, 2=south, 3=west
	var base_depth = rng.randi_range(depth_range.x, depth_range.y)

	# Create shoreline noise for irregular coast
	var shore_noise = FastNoiseLite.new()
	shore_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	shore_noise.seed = rng.randi()
	shore_noise.frequency = 0.04

	# Secondary noise for fine detail
	var detail_noise = FastNoiseLite.new()
	detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	detail_noise.seed = rng.randi()
	detail_noise.frequency = 0.12

	for x in range(width):
		for y in range(height):
			var pos = Vector2i(x, y)
			var dist_from_edge: float

			match edge:
				0: dist_from_edge = float(y)                   # North edge
				1: dist_from_edge = float(width - 1 - x)       # East edge
				2: dist_from_edge = float(height - 1 - y)      # South edge
				3: dist_from_edge = float(x)                    # West edge
				_: dist_from_edge = float(y)

			# Irregular shoreline using noise
			var coord_along_edge: float
			match edge:
				0, 2: coord_along_edge = float(x)
				_: coord_along_edge = float(y)

			var shore_variation = shore_noise.get_noise_2d(coord_along_edge, 0.0) * 5.0
			var detail_variation = detail_noise.get_noise_2d(coord_along_edge, 0.0) * 2.0
			var effective_depth = base_depth + shore_variation + detail_variation

			if dist_from_edge < effective_depth:
				terrain_grid.set_tile_natural(pos, TerrainTypes.Type.WATER)
				terrain_grid.set_elevation(pos, -2 if dist_from_edge < effective_depth * 0.5 else -1)

static func _generate_lagoon(terrain_grid: TerrainGrid, rng: RandomNumberGenerator, width: int, height: int, depth_range: Vector2i) -> void:
	## Create an interior lagoon with organic shape
	# Place lagoon in a random area, biased away from dead center
	var center_x = rng.randi_range(int(width * 0.2), int(width * 0.8))
	var center_y = rng.randi_range(int(height * 0.2), int(height * 0.8))
	var center = Vector2(center_x, center_y)

	var base_radius_x = rng.randf_range(depth_range.x, depth_range.y)
	var base_radius_y = rng.randf_range(depth_range.x * 0.6, depth_range.y * 0.8)

	# Organic shape noise
	var shape_noise = FastNoiseLite.new()
	shape_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	shape_noise.seed = rng.randi()
	shape_noise.frequency = 0.08

	var search_radius = int(max(base_radius_x, base_radius_y)) + 6
	for x in range(center_x - search_radius, center_x + search_radius):
		for y in range(center_y - search_radius, center_y + search_radius):
			if x < 1 or x >= width - 1 or y < 1 or y >= height - 1:
				continue

			var pos = Vector2i(x, y)
			var dx = float(x - center_x) / base_radius_x
			var dy = float(y - center_y) / base_radius_y
			var normalized_dist = sqrt(dx * dx + dy * dy)

			# Add noise to the boundary for organic shape
			var angle = atan2(float(y - center_y), float(x - center_x))
			var noise_val = shape_noise.get_noise_2d(float(x), float(y)) * 0.3
			noise_val += sin(angle * 2) * 0.1 + cos(angle * 3) * 0.08

			if normalized_dist < 1.0 + noise_val:
				terrain_grid.set_tile_natural(pos, TerrainTypes.Type.WATER)
				terrain_grid.set_elevation(pos, -2 if normalized_dist < 0.5 else -1)

	# Add a secondary smaller pond connected or nearby for more natural look
	var offset_angle = rng.randf() * TAU
	var offset_dist = base_radius_x * rng.randf_range(0.8, 1.4)
	var pond2_x = center_x + int(cos(offset_angle) * offset_dist)
	var pond2_y = center_y + int(sin(offset_angle) * offset_dist * 0.6)
	pond2_x = clampi(pond2_x, 10, width - 10)
	pond2_y = clampi(pond2_y, 10, height - 10)
	var pond2_radius = base_radius_x * rng.randf_range(0.3, 0.5)

	for x in range(pond2_x - int(pond2_radius) - 3, pond2_x + int(pond2_radius) + 3):
		for y in range(pond2_y - int(pond2_radius) - 3, pond2_y + int(pond2_radius) + 3):
			if x < 1 or x >= width - 1 or y < 1 or y >= height - 1:
				continue
			var pos = Vector2i(x, y)
			var dist = Vector2(x, y).distance_to(Vector2(pond2_x, pond2_y))
			var angle = atan2(y - pond2_y, x - pond2_x)
			var noise_offset = sin(angle * 3) * 1.5 + cos(angle * 5) * 1.0
			if dist <= pond2_radius + noise_offset:
				terrain_grid.set_tile_natural(pos, TerrainTypes.Type.WATER)
				terrain_grid.set_elevation(pos, -1)

static func _generate_water(terrain_grid: TerrainGrid, rng: RandomNumberGenerator) -> void:
	## Generate natural water features (ponds)
	var width = terrain_grid.grid_width
	var height = terrain_grid.grid_height

	# Theme-aware pond count
	var params = CourseTheme.get_generation_params(GameManager.current_theme)
	var pond_range: Vector2i = params.get("water_ponds", Vector2i(1, 3))
	var pond_count = rng.randi_range(pond_range.x, pond_range.y)

	for i in range(pond_count):
		# Pond center - avoid edges
		var center_x = rng.randi_range(20, width - 20)
		var center_y = rng.randi_range(20, height - 20)
		var center = Vector2(center_x, center_y)

		# Skip if this spot is already water (from large water body)
		if terrain_grid.get_tile(Vector2i(center_x, center_y)) == TerrainTypes.Type.WATER:
			continue

		# Pond size (irregular shape)
		var base_radius = rng.randf_range(4, 10)

		# Create irregular pond shape
		for x in range(center_x - int(base_radius) - 3, center_x + int(base_radius) + 3):
			for y in range(center_y - int(base_radius) - 3, center_y + int(base_radius) + 3):
				if x < 0 or x >= width or y < 0 or y >= height:
					continue

				var pos = Vector2i(x, y)
				var dist = Vector2(x, y).distance_to(center)

				# Add noise to radius for irregular shape
				var angle = atan2(y - center_y, x - center_x)
				var noise_offset = sin(angle * 3) * 2 + cos(angle * 5) * 1.5
				var effective_radius = base_radius + noise_offset

				if dist <= effective_radius:
					terrain_grid.set_tile_natural(pos, TerrainTypes.Type.WATER)
					# Ponds are typically in low areas
					terrain_grid.set_elevation(pos, -1)

static func _generate_rough_patches(terrain_grid: TerrainGrid, rng: RandomNumberGenerator) -> void:
	## Generate patches of rough and heavy rough to simulate overgrown undeveloped land
	var width = terrain_grid.grid_width
	var height = terrain_grid.grid_height

	var params = CourseTheme.get_generation_params(GameManager.current_theme)
	var rough_range: Vector2i = params.get("rough_patches", Vector2i(6, 12))
	var heavy_range: Vector2i = params.get("heavy_rough_patches", Vector2i(3, 6))

	# Generate regular rough patches (tall grass, unmowed areas)
	var rough_count = rng.randi_range(rough_range.x, rough_range.y)
	for i in range(rough_count):
		var center_x = rng.randi_range(8, width - 8)
		var center_y = rng.randi_range(8, height - 8)
		var center = Vector2(center_x, center_y)
		var radius_x = rng.randf_range(6, 16)
		var radius_y = rng.randf_range(6, 16)

		# Use noise for organic blob shape
		var blob_noise = FastNoiseLite.new()
		blob_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
		blob_noise.seed = rng.randi()
		blob_noise.frequency = 0.1

		var search_r = int(max(radius_x, radius_y)) + 3
		for x in range(center_x - search_r, center_x + search_r):
			for y in range(center_y - search_r, center_y + search_r):
				if x < 0 or x >= width or y < 0 or y >= height:
					continue

				var pos = Vector2i(x, y)
				# Only convert grass tiles (don't overwrite water etc.)
				if terrain_grid.get_tile(pos) != TerrainTypes.Type.GRASS:
					continue

				var dx = float(x - center_x) / radius_x
				var dy = float(y - center_y) / radius_y
				var normalized_dist = sqrt(dx * dx + dy * dy)

				var noise_val = blob_noise.get_noise_2d(float(x), float(y)) * 0.35
				if normalized_dist < 1.0 + noise_val:
					# Density falls off at edges - some tiles stay as grass for natural look
					var edge_factor = 1.0 - normalized_dist
					if rng.randf() < 0.6 + edge_factor * 0.4:
						terrain_grid.set_tile_natural(pos, TerrainTypes.Type.ROUGH)

	# Generate heavy rough patches (dense brush, overgrown areas)
	var heavy_count = rng.randi_range(heavy_range.x, heavy_range.y)
	for i in range(heavy_count):
		var center_x = rng.randi_range(10, width - 10)
		var center_y = rng.randi_range(10, height - 10)
		var center = Vector2(center_x, center_y)
		var radius = rng.randf_range(4, 10)

		var blob_noise = FastNoiseLite.new()
		blob_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
		blob_noise.seed = rng.randi()
		blob_noise.frequency = 0.12

		var search_r = int(radius) + 3
		for x in range(center_x - search_r, center_x + search_r):
			for y in range(center_y - search_r, center_y + search_r):
				if x < 0 or x >= width or y < 0 or y >= height:
					continue

				var pos = Vector2i(x, y)
				var tile = terrain_grid.get_tile(pos)
				# Only convert grass or rough (don't overwrite water, etc.)
				if tile != TerrainTypes.Type.GRASS and tile != TerrainTypes.Type.ROUGH:
					continue

				var dist = Vector2(x, y).distance_to(center)
				var noise_val = blob_noise.get_noise_2d(float(x), float(y)) * 2.0
				if dist <= radius + noise_val:
					var edge_factor = 1.0 - (dist / (radius + noise_val))
					if rng.randf() < 0.5 + edge_factor * 0.4:
						terrain_grid.set_tile_natural(pos, TerrainTypes.Type.HEAVY_ROUGH)

static func _generate_flower_patches(terrain_grid: TerrainGrid, rng: RandomNumberGenerator) -> void:
	## Generate wildflower patches for visual variety
	var width = terrain_grid.grid_width
	var height = terrain_grid.grid_height

	var params = CourseTheme.get_generation_params(GameManager.current_theme)
	var flower_range: Vector2i = params.get("flower_patches", Vector2i(2, 5))
	var flower_count = rng.randi_range(flower_range.x, flower_range.y)

	for i in range(flower_count):
		var center_x = rng.randi_range(10, width - 10)
		var center_y = rng.randi_range(10, height - 10)
		var center = Vector2(center_x, center_y)
		# Flower patches are smaller than rough patches
		var radius = rng.randf_range(3, 7)

		for x in range(center_x - int(radius) - 2, center_x + int(radius) + 2):
			for y in range(center_y - int(radius) - 2, center_y + int(radius) + 2):
				if x < 0 or x >= width or y < 0 or y >= height:
					continue

				var pos = Vector2i(x, y)
				var tile = terrain_grid.get_tile(pos)
				# Only place flowers on grass or rough
				if tile != TerrainTypes.Type.GRASS and tile != TerrainTypes.Type.ROUGH:
					continue

				var dist = Vector2(x, y).distance_to(center)
				var angle = atan2(y - center_y, x - center_x)
				var noise_offset = sin(angle * 4) * 1.2 + cos(angle * 7) * 0.8
				if dist <= radius + noise_offset:
					# Scattered placement, not solid fill
					if rng.randf() < 0.5:
						terrain_grid.set_tile_natural(pos, TerrainTypes.Type.FLOWER_BED)

static func _generate_trees(terrain_grid: TerrainGrid, entity_layer: EntityLayer, rng: RandomNumberGenerator) -> void:
	## Generate scattered trees across the terrain
	var width = terrain_grid.grid_width
	var height = terrain_grid.grid_height

	# Theme-aware tree generation — exclude waterside-only types from general placement
	var params = CourseTheme.get_generation_params(GameManager.current_theme)
	var all_tree_types = CourseTheme.get_tree_types(GameManager.current_theme)
	var waterside_only: Array = ["cattails"]
	var tree_types: Array = all_tree_types.filter(func(t): return t not in waterside_only)
	var cluster_range: Vector2i = params.get("tree_clusters", Vector2i(5, 10))
	var cluster_count = rng.randi_range(cluster_range.x, cluster_range.y)
	var radius_range: Vector2 = params.get("tree_cluster_radius", Vector2(8, 20))
	var density_range: Vector2 = params.get("tree_density", Vector2(0.15, 0.35))

	for i in range(cluster_count):
		var cluster_center = Vector2(rng.randf_range(10, width - 10), rng.randf_range(10, height - 10))
		var cluster_radius = rng.randf_range(radius_range.x, radius_range.y)
		var tree_density = rng.randf_range(density_range.x, density_range.y)

		# Determine dominant tree type for this cluster (theme-aware)
		var dominant_type = tree_types[rng.randi_range(0, tree_types.size() - 1)]

		for x in range(int(cluster_center.x - cluster_radius), int(cluster_center.x + cluster_radius)):
			for y in range(int(cluster_center.y - cluster_radius), int(cluster_center.y + cluster_radius)):
				if x < 0 or x >= width or y < 0 or y >= height:
					continue

				var pos = Vector2i(x, y)
				var dist = Vector2(x, y).distance_to(cluster_center)

				if dist > cluster_radius:
					continue

				# Check if tile is suitable for trees
				var tile_type = terrain_grid.get_tile(pos)
				if tile_type == TerrainTypes.Type.WATER or tile_type == TerrainTypes.Type.FLOWER_BED:
					continue

				# Check if already has a tree or rock
				if entity_layer.get_tree_at(pos) != null or entity_layer.get_rock_at(pos) != null:
					continue

				# Density falls off towards edges
				var density_factor = 1.0 - (dist / cluster_radius)
				if rng.randf() < tree_density * density_factor:
					# 70% chance of dominant type, 30% chance of other types
					var tree_type = dominant_type
					if rng.randf() < 0.3:
						tree_type = tree_types[rng.randi_range(0, tree_types.size() - 1)]

					entity_layer.place_tree(pos, tree_type)

	# Add scattered individual trees (theme-aware count)
	var scatter_range: Vector2i = params.get("scattered_trees", Vector2i(30, 60))
	var scattered_count = rng.randi_range(scatter_range.x, scatter_range.y)
	for i in range(scattered_count):
		var x = rng.randi_range(5, width - 5)
		var y = rng.randi_range(5, height - 5)
		var pos = Vector2i(x, y)

		var tile_type = terrain_grid.get_tile(pos)
		if tile_type == TerrainTypes.Type.WATER or tile_type == TerrainTypes.Type.FLOWER_BED:
			continue

		if entity_layer.get_tree_at(pos) != null or entity_layer.get_rock_at(pos) != null:
			continue

		# Trees are more likely to appear in rough/heavy rough (overgrown areas)
		var place_chance = 1.0
		if tile_type == TerrainTypes.Type.ROUGH or tile_type == TerrainTypes.Type.HEAVY_ROUGH:
			place_chance = 1.0  # Always attempt in rough areas
		elif tile_type == TerrainTypes.Type.GRASS:
			place_chance = 0.8  # Slightly less likely on open grass

		if rng.randf() > place_chance:
			continue

		var tree_type = tree_types[rng.randi_range(0, tree_types.size() - 1)]
		entity_layer.place_tree(pos, tree_type)

static func _generate_rocks(terrain_grid: TerrainGrid, entity_layer: EntityLayer, rng: RandomNumberGenerator) -> void:
	## Generate scattered rocks, often near elevation changes
	var width = terrain_grid.grid_width
	var height = terrain_grid.grid_height

	# Theme-aware rock count
	var params = CourseTheme.get_generation_params(GameManager.current_theme)
	var rock_range: Vector2i = params.get("rocks", Vector2i(40, 80))
	var rock_count = rng.randi_range(rock_range.x, rock_range.y)
	var attempts = 0
	var placed = 0

	while placed < rock_count and attempts < rock_count * 3:
		attempts += 1

		var x = rng.randi_range(3, width - 3)
		var y = rng.randi_range(3, height - 3)
		var pos = Vector2i(x, y)

		var tile_type = terrain_grid.get_tile(pos)
		if tile_type == TerrainTypes.Type.WATER:
			continue

		if entity_layer.get_tree_at(pos) != null or entity_layer.get_rock_at(pos) != null:
			continue

		# Higher chance of rocks near elevation changes
		var elevation = terrain_grid.get_elevation(pos)
		var base_chance = 0.3
		if abs(elevation) >= 2:
			base_chance = 0.7
		elif abs(elevation) >= 1:
			base_chance = 0.5

		if rng.randf() > base_chance:
			continue

		# Random rock size, with larger rocks being rarer
		var size_roll = rng.randf()
		var rock_size: String
		if size_roll < 0.5:
			rock_size = "small"
		elif size_roll < 0.85:
			rock_size = "medium"
		else:
			rock_size = "large"

		entity_layer.place_rock(pos, rock_size)
		placed += 1

static func _generate_waterside_vegetation(terrain_grid: TerrainGrid, entity_layer: EntityLayer, rng: RandomNumberGenerator) -> void:
	## Place cattails and reeds along the edges of water bodies
	var width = terrain_grid.grid_width
	var height = terrain_grid.grid_height
	var tree_types = CourseTheme.get_tree_types(GameManager.current_theme)

	# Only place waterside vegetation if the theme supports cattails
	if "cattails" not in tree_types:
		return

	# Scan for water-adjacent tiles and place cattails along shorelines
	var placed = 0
	var max_cattails = rng.randi_range(15, 35)

	for x in range(2, width - 2):
		for y in range(2, height - 2):
			if placed >= max_cattails:
				break

			var pos = Vector2i(x, y)
			var tile = terrain_grid.get_tile(pos)

			# Must be a non-water tile
			if tile == TerrainTypes.Type.WATER:
				continue

			# Check if adjacent to water
			var adjacent_water = false
			for offset in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				var neighbor = pos + offset
				if terrain_grid.is_valid_position(neighbor) and terrain_grid.get_tile(neighbor) == TerrainTypes.Type.WATER:
					adjacent_water = true
					break

			if not adjacent_water:
				continue

			# Skip if already occupied
			if entity_layer.get_tree_at(pos) != null or entity_layer.get_rock_at(pos) != null:
				continue

			# 40% chance to place cattails on any water-adjacent tile
			if rng.randf() < 0.4:
				entity_layer.place_tree(pos, "cattails")
				placed += 1

		if placed >= max_cattails:
			break
