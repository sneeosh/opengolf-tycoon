extends RefCounted
class_name DifficultyCalculator
## DifficultyCalculator - Calculates hole difficulty based on hazards, terrain, and design

## Calculate difficulty rating for a hole (1.0 - 10.0 scale)
static func calculate_hole_difficulty(hole_data: GameManager.HoleData, terrain_grid: TerrainGrid) -> float:
	if not hole_data or not terrain_grid:
		return 1.0

	# Base difficulty from par (longer holes are harder)
	var base_difficulty: float = hole_data.par - 2.0  # Par 3 = 1.0, Par 4 = 2.0, Par 5 = 3.0

	# Sample tiles in a corridor between tee and green
	var corridor_tiles = _get_corridor_tiles(
		hole_data.tee_position,
		hole_data.green_position,
		terrain_grid,
		10  # corridor width in tiles
	)

	# Calculate various difficulty factors
	var hazard_difficulty = _calculate_hazard_difficulty(corridor_tiles, terrain_grid)
	var elevation_difficulty = _calculate_elevation_difficulty(hole_data, terrain_grid)
	var dogleg_difficulty = _calculate_dogleg_difficulty(hole_data, terrain_grid)
	var green_difficulty = _calculate_green_difficulty(hole_data, terrain_grid)
	var landing_zone_difficulty = _calculate_landing_zone_difficulty(hole_data, terrain_grid)

	var total_difficulty = base_difficulty + hazard_difficulty + elevation_difficulty + dogleg_difficulty + green_difficulty + landing_zone_difficulty
	return clampf(total_difficulty, 1.0, 10.0)

## Count and weight hazards in the corridor
static func _calculate_hazard_difficulty(corridor_tiles: Array, terrain_grid: TerrainGrid) -> float:
	var water_count: int = 0
	var bunker_count: int = 0
	var ob_count: int = 0
	var tree_count: int = 0

	for tile_pos in corridor_tiles:
		var terrain_type = terrain_grid.get_tile(tile_pos)
		match terrain_type:
			TerrainTypes.Type.WATER:
				water_count += 1
			TerrainTypes.Type.BUNKER:
				bunker_count += 1
			TerrainTypes.Type.OUT_OF_BOUNDS:
				ob_count += 1
			TerrainTypes.Type.TREES:
				tree_count += 1

	var difficulty: float = 0.0
	difficulty += water_count * 0.3
	difficulty += bunker_count * 0.15
	difficulty += ob_count * 0.2
	difficulty += tree_count * 0.1
	return difficulty

## Calculate difficulty from elevation changes along the hole
static func _calculate_elevation_difficulty(hole_data: GameManager.HoleData, terrain_grid: TerrainGrid) -> float:
	var tee = hole_data.tee_position
	var green = hole_data.green_position

	# Sample elevation along the hole
	var direction = Vector2(green - tee).normalized()
	var distance = Vector2(tee).distance_to(Vector2(green))
	var samples = int(distance) + 1

	if samples < 2:
		return 0.0

	var total_elevation_change: int = 0
	var prev_elevation: int = terrain_grid.get_elevation(tee)

	for i in range(1, samples + 1):
		var t = float(i) / float(samples)
		var sample_pos = Vector2i(Vector2(tee) + direction * distance * t)
		if terrain_grid.is_valid_position(sample_pos):
			var current_elevation = terrain_grid.get_elevation(sample_pos)
			total_elevation_change += abs(current_elevation - prev_elevation)
			prev_elevation = current_elevation

	# Each unit of total elevation change adds difficulty
	return clampf(total_elevation_change * 0.15, 0.0, 1.5)

## Detect doglegs (holes that bend) - harder to play
static func _calculate_dogleg_difficulty(hole_data: GameManager.HoleData, terrain_grid: TerrainGrid) -> float:
	var tee = Vector2(hole_data.tee_position)
	var green = Vector2(hole_data.green_position)
	var direct_direction = (green - tee).normalized()
	var distance = tee.distance_to(green)

	# For par 4s and 5s, check midpoint area for fairway deviation
	if hole_data.par >= 4 and distance > 8:
		var midpoint = Vector2i((tee + green) * 0.5)
		var perpendicular = Vector2(-direct_direction.y, direct_direction.x)

		# Check if fairway exists off the direct line (indicating dogleg)
		var has_left_fairway = false
		var has_right_fairway = false

		for offset in range(2, 6):
			var left_pos = Vector2i(Vector2(midpoint) + perpendicular * offset)
			var right_pos = Vector2i(Vector2(midpoint) - perpendicular * offset)

			if terrain_grid.is_valid_position(left_pos) and terrain_grid.get_tile(left_pos) == TerrainTypes.Type.FAIRWAY:
				has_left_fairway = true
			if terrain_grid.is_valid_position(right_pos) and terrain_grid.get_tile(right_pos) == TerrainTypes.Type.FAIRWAY:
				has_right_fairway = true

		# Strong dogleg if fairway only extends to one side
		if has_left_fairway != has_right_fairway:
			return 0.8  # Significant dogleg

	return 0.0

## Calculate green difficulty based on size and slope
static func _calculate_green_difficulty(hole_data: GameManager.HoleData, terrain_grid: TerrainGrid) -> float:
	var green_pos = hole_data.green_position

	# Count green tiles using flood fill approach
	var green_tiles: Array = []
	var to_check: Array = [green_pos]
	var checked: Dictionary = {}

	while to_check.size() > 0 and green_tiles.size() < 100:  # Safety limit
		var pos = to_check.pop_front()
		if checked.has(pos):
			continue
		checked[pos] = true

		if not terrain_grid.is_valid_position(pos):
			continue
		if terrain_grid.get_tile(pos) != TerrainTypes.Type.GREEN:
			continue

		green_tiles.append(pos)
		# Check neighbors
		for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var neighbor = pos + offset
			if not checked.has(neighbor):
				to_check.append(neighbor)

	var green_size = green_tiles.size()

	# Standard green is ~20-30 tiles. Small is <15, large is >35
	var size_difficulty: float = 0.0
	if green_size < 12:
		size_difficulty = 0.8  # Very small green
	elif green_size < 18:
		size_difficulty = 0.4  # Small green
	elif green_size > 40:
		size_difficulty = -0.2  # Large green is easier

	# Check green slope (elevation variance)
	var slope_difficulty: float = 0.0
	if green_tiles.size() > 1:
		var min_elev: int = 999
		var max_elev: int = -999
		for tile in green_tiles:
			var elev = terrain_grid.get_elevation(tile)
			min_elev = min(min_elev, elev)
			max_elev = max(max_elev, elev)
		var slope_range = max_elev - min_elev
		slope_difficulty = clampf(slope_range * 0.25, 0.0, 0.6)

	return size_difficulty + slope_difficulty

## Calculate difficulty from hazards near typical landing zones
static func _calculate_landing_zone_difficulty(hole_data: GameManager.HoleData, terrain_grid: TerrainGrid) -> float:
	var tee = Vector2(hole_data.tee_position)
	var green = Vector2(hole_data.green_position)
	var direction = (green - tee).normalized()
	var total_distance = tee.distance_to(green)

	var difficulty: float = 0.0

	# Landing zones based on par
	# Par 3: No real landing zone (approach shot)
	# Par 4: One landing zone around 200-250 yards (9-11 tiles)
	# Par 5: Two landing zones
	var landing_zones: Array = []
	if hole_data.par >= 4:
		landing_zones.append(10.0)  # ~220 yards from tee
	if hole_data.par >= 5:
		landing_zones.append(minf(total_distance - 6, 18.0))  # Second shot landing

	for lz_distance in landing_zones:
		if lz_distance > total_distance:
			continue
		var lz_center = Vector2i(tee + direction * lz_distance)

		# Check 3-tile radius around landing zone for hazards
		for dx in range(-3, 4):
			for dy in range(-3, 4):
				var check_pos = lz_center + Vector2i(dx, dy)
				if not terrain_grid.is_valid_position(check_pos):
					continue
				var terrain = terrain_grid.get_tile(check_pos)
				if terrain == TerrainTypes.Type.WATER:
					difficulty += 0.15
				elif terrain == TerrainTypes.Type.BUNKER:
					difficulty += 0.08
				elif terrain == TerrainTypes.Type.OUT_OF_BOUNDS:
					difficulty += 0.12

	return clampf(difficulty, 0.0, 1.5)

## Get tiles in a corridor between two points
static func _get_corridor_tiles(from: Vector2i, to: Vector2i, terrain_grid: TerrainGrid, width: int) -> Array:
	var tiles: Array = []
	var direction = Vector2(to - from)
	var length = direction.length()
	if length < 1.0:
		return tiles

	var normalized = direction.normalized()
	# Perpendicular vector for corridor width
	var perp = Vector2(-normalized.y, normalized.x)
	var half_width = width / 2.0

	# Sample along the corridor
	var steps = int(length) + 1
	for i in range(steps):
		var t = float(i) / float(max(steps - 1, 1))
		var center = Vector2(from) + direction * t

		# Sample across the width
		for w in range(-int(half_width), int(half_width) + 1):
			var sample_pos = Vector2i(center + perp * float(w))
			if terrain_grid.is_valid_position(sample_pos) and sample_pos not in tiles:
				tiles.append(sample_pos)

	return tiles
