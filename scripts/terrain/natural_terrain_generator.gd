extends RefCounted
class_name NaturalTerrainGenerator
## NaturalTerrainGenerator - Generates natural terrain features for new courses

const DEFAULT_TREE_TYPES = ["oak", "pine", "maple", "birch"]
const ROCK_SIZES = ["small", "medium", "large"]

## Generate natural terrain for a new course, using theme parameters
static func generate(terrain_grid: TerrainGrid, entity_layer: EntityLayer, seed_value: int = 0) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value if seed_value != 0 else int(Time.get_unix_time_from_system())

	print("Generating natural terrain with seed: %d (theme: %s)" % [rng.seed, CourseTheme.get_name(GameManager.current_theme)])

	# Generate elevation first (hills and valleys)
	_generate_elevation(terrain_grid, rng)

	# Generate water features (ponds)
	_generate_water(terrain_grid, rng)

	# Generate trees
	_generate_trees(terrain_grid, entity_layer, rng)

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
					terrain_grid.set_tile(pos, TerrainTypes.Type.WATER)
					# Ponds are typically in low areas
					terrain_grid.set_elevation(pos, -1)

static func _generate_trees(terrain_grid: TerrainGrid, entity_layer: EntityLayer, rng: RandomNumberGenerator) -> void:
	## Generate scattered trees across the terrain
	var width = terrain_grid.grid_width
	var height = terrain_grid.grid_height

	# Theme-aware tree generation
	var params = CourseTheme.get_generation_params(GameManager.current_theme)
	var tree_types = CourseTheme.get_tree_types(GameManager.current_theme)
	var cluster_range: Vector2i = params.get("tree_clusters", Vector2i(5, 10))
	var cluster_count = rng.randi_range(cluster_range.x, cluster_range.y)

	for i in range(cluster_count):
		var cluster_center = Vector2(rng.randf_range(10, width - 10), rng.randf_range(10, height - 10))
		var cluster_radius = rng.randf_range(8, 20)
		var tree_density = rng.randf_range(0.15, 0.35)  # Percentage of tiles with trees

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

				# Check if tile is suitable for trees (grass only)
				var tile_type = terrain_grid.get_tile(pos)
				if tile_type != TerrainTypes.Type.GRASS:
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

	# Add some scattered individual trees (theme-aware count)
	var scatter_range: Vector2i = params.get("scattered_trees", Vector2i(30, 60))
	var scattered_count = rng.randi_range(scatter_range.x, scatter_range.y)
	for i in range(scattered_count):
		var x = rng.randi_range(5, width - 5)
		var y = rng.randi_range(5, height - 5)
		var pos = Vector2i(x, y)

		var tile_type = terrain_grid.get_tile(pos)
		if tile_type != TerrainTypes.Type.GRASS:
			continue

		if entity_layer.get_tree_at(pos) != null or entity_layer.get_rock_at(pos) != null:
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
