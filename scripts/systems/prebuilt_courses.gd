extends RefCounted
class_name PrebuiltCourses
## PrebuiltCourses - Prebuilt course packages that players can purchase
##
## Provides 4 package tiers (Starter/Executive/Standard/Championship) with
## different hole counts, costs, and requirements. Uses QuickStartCourse's
## static helpers for actual course painting.

enum PackageType { STARTER, EXECUTIVE, STANDARD, CHAMPIONSHIP }

const PACKAGE_DATA = {
	PackageType.STARTER: {
		"name": "Starter Course",
		"cost": 25000,
		"holes": 3,
		"pars": [3, 4, 3],
		"min_parcels": 3,
		"min_stars": 0,
		"min_reputation": 0.0,
		"description": "3 simple holes to get started. Par 10.",
	},
	PackageType.EXECUTIVE: {
		"name": "Executive Course",
		"cost": 75000,
		"holes": 9,
		"pars": [3, 3, 3, 3, 3, 3, 3, 3, 3],
		"min_parcels": 5,
		"min_stars": 0,
		"min_reputation": 0.0,
		"description": "9 par-3 holes. Compact executive layout. Par 27.",
	},
	PackageType.STANDARD: {
		"name": "Standard Course",
		"cost": 100000,
		"holes": 9,
		"pars": [4, 3, 5, 4, 4, 3, 4, 5, 4],
		"min_parcels": 6,
		"min_stars": 3,
		"min_reputation": 0.0,
		"description": "9 mixed holes with strategic hazards. Par 36.",
	},
	PackageType.CHAMPIONSHIP: {
		"name": "Championship Course",
		"cost": 200000,
		"holes": 18,
		"pars": [4, 5, 3, 4, 4, 3, 5, 4, 4, 4, 3, 5, 4, 4, 3, 4, 5, 4],
		"min_parcels": 10,
		"min_stars": 4,
		"min_reputation": 50.0,
		"description": "18 tournament-ready holes. Par 72.",
	},
}

## Check if a package can be purchased
static func can_purchase(package_type: int) -> Dictionary:
	var data = PACKAGE_DATA[package_type]

	if not GameManager.can_afford(data.cost):
		return {can_buy = false, reason = "Need $%d" % data.cost}

	if GameManager.land_manager and GameManager.land_manager.owned_parcels.size() < data.min_parcels:
		return {can_buy = false, reason = "Need %d+ parcels" % data.min_parcels}

	if data.min_stars > 0:
		var stars = 0
		if GameManager.current_course:
			var rating = CourseRatingSystem.calculate_rating(
				GameManager.terrain_grid, GameManager.current_course,
				GameManager.daily_stats, GameManager.green_fee, GameManager.reputation)
			stars = rating.get("stars", 0)
		if stars < data.min_stars:
			return {can_buy = false, reason = "Need %d-star rating" % data.min_stars}

	if data.min_reputation > 0.0 and GameManager.reputation < data.min_reputation:
		return {can_buy = false, reason = "Need %.0f reputation" % data.min_reputation}

	if GameManager.current_course and GameManager.current_course.holes.size() > 0:
		return {can_buy = false, reason = "Course already has holes"}

	return {can_buy = true, reason = ""}

## Build the course on owned land
static func build(
	package_type: int,
	terrain_grid: TerrainGrid,
	entity_layer: EntityLayer,
	hole_tool: HoleCreationTool
) -> bool:
	var check = can_purchase(package_type)
	if not check.can_buy:
		EventBus.notify(check.reason, "error")
		return false

	var data = PACKAGE_DATA[package_type]
	GameManager.modify_money(-data.cost)
	EventBus.log_transaction("Course Package: %s" % data.name, -data.cost)

	_generate_course(package_type, terrain_grid, entity_layer, hole_tool)
	EventBus.notify("%s created! %d holes, Par %d." % [data.name, data.holes, _sum_pars(data.pars)], "success")
	return true


static func _sum_pars(pars: Array) -> int:
	var total = 0
	for p in pars:
		total += p
	return total


static func _generate_course(package_type: int, terrain_grid: TerrainGrid, entity_layer: EntityLayer, hole_tool: HoleCreationTool) -> void:
	var data = PACKAGE_DATA[package_type]
	var pars: Array = data.pars
	var positions = _compute_hole_positions(pars, terrain_grid)

	for i in range(positions.size()):
		var tee = positions[i].tee
		var green = positions[i].green
		var par = pars[i]

		# Paint the hole using QuickStartCourse helpers
		var corridor_width = 3 if par == 3 else 5
		QuickStartCourse._paint_hole(terrain_grid, tee, green, corridor_width)

		# Add hazards for variety
		if par >= 4 and i % 3 == 1:
			# Water hazard mid-fairway
			var mid = Vector2i((tee.x + green.x) / 2, (tee.y + green.y) / 2)
			var offset_dir = Vector2(green - tee).normalized()
			var perp = Vector2(-offset_dir.y, offset_dir.x)
			var hazard_pos = mid + Vector2i(int(perp.x * 3), int(perp.y * 3))
			QuickStartCourse._paint_water_hazard(terrain_grid, hazard_pos, 2)
		elif par >= 4 and i % 3 == 2:
			# Extra bunker
			var direction = Vector2(green - tee).normalized()
			var bunker_pos = green - Vector2i(int(direction.x * 4), int(direction.y * 4))
			QuickStartCourse._paint_extra_bunker(terrain_grid, bunker_pos)

		# Create the hole entry
		QuickStartCourse._create_hole(terrain_grid, hole_tool, tee, green)

	# Remove trees and rocks on course surfaces
	QuickStartCourse._clear_entities_on_course(terrain_grid, entity_layer)


static func _compute_hole_positions(pars: Array, terrain_grid: TerrainGrid) -> Array:
	"""Compute tee and green positions for each hole using a snake pattern on owned land."""
	var positions: Array = []

	if not GameManager.land_manager:
		return positions

	var lm = GameManager.land_manager

	# Find bounding rect of owned parcels
	var min_tile = Vector2i(999, 999)
	var max_tile = Vector2i(0, 0)
	for parcel in lm.owned_parcels:
		var rect = lm.parcel_to_tile_rect(parcel)
		min_tile.x = mini(min_tile.x, rect.position.x)
		min_tile.y = mini(min_tile.y, rect.position.y)
		max_tile.x = maxi(max_tile.x, rect.position.x + rect.size.x)
		max_tile.y = maxi(max_tile.y, rect.position.y + rect.size.y)

	# Add margin from edges
	min_tile += Vector2i(3, 3)
	max_tile -= Vector2i(3, 3)

	var usable_width = max_tile.x - min_tile.x
	var usable_height = max_tile.y - min_tile.y

	# Calculate hole spacing based on number of holes and available space
	var num_holes = pars.size()

	# Use snake pattern: rows of holes going left-to-right, then right-to-left
	var holes_per_row = _calc_holes_per_row(num_holes, usable_width, usable_height)
	var num_rows = ceili(float(num_holes) / float(holes_per_row))
	var row_height = usable_height / num_rows

	var current_tee = min_tile + Vector2i(2, 2)

	for i in range(num_holes):
		var row = i / holes_per_row
		var col = i % holes_per_row
		var going_right = (row % 2 == 0)

		if not going_right:
			col = holes_per_row - 1 - col

		var par = pars[i]
		var hole_length = _par_to_tile_distance(par)

		# Compute tee position in the grid
		var col_width = usable_width / holes_per_row
		var tee_x: int
		var tee_y: int

		if going_right:
			tee_x = min_tile.x + col * col_width + 3
			tee_y = min_tile.y + row * row_height + 3
		else:
			tee_x = min_tile.x + col * col_width + col_width - 3
			tee_y = min_tile.y + row * row_height + 3

		# Green position: extend from tee in the dominant direction
		var green_x: int
		var green_y: int

		if num_rows == 1:
			# Single row: holes go right
			green_x = tee_x + hole_length
			green_y = tee_y + _rng_offset(i, 3)
		elif going_right:
			# Going right: green is right and slightly down
			green_x = tee_x + int(hole_length * 0.8)
			green_y = tee_y + int(hole_length * 0.4) + _rng_offset(i, 2)
		else:
			# Going left: green is left and slightly down
			green_x = tee_x - int(hole_length * 0.8)
			green_y = tee_y + int(hole_length * 0.4) + _rng_offset(i, 2)

		# Clamp to valid terrain
		tee_x = clampi(tee_x, min_tile.x + 2, max_tile.x - 4)
		tee_y = clampi(tee_y, min_tile.y + 2, max_tile.y - 4)
		green_x = clampi(green_x, min_tile.x + 2, max_tile.x - 4)
		green_y = clampi(green_y, min_tile.y + 2, max_tile.y - 4)

		# Ensure minimum distance
		var tee_pos = Vector2i(tee_x, tee_y)
		var green_pos = Vector2i(green_x, green_y)
		if Vector2(tee_pos).distance_to(Vector2(green_pos)) < 5:
			if going_right:
				green_pos.x = tee_pos.x + 6
			else:
				green_pos.x = tee_pos.x - 6

		positions.append({tee = tee_pos, green = green_pos})

	return positions


static func _calc_holes_per_row(num_holes: int, width: int, height: int) -> int:
	if num_holes <= 3:
		return num_holes
	if num_holes <= 5:
		return ceili(float(num_holes) / 2.0)
	if num_holes <= 9:
		return ceili(float(num_holes) / 3.0)
	# 18 holes: 6 per row, 3 rows
	return 6


static func _par_to_tile_distance(par: int) -> int:
	match par:
		3: return 8
		4: return 16
		5: return 22
	return 14


static func _rng_offset(seed_val: int, max_offset: int) -> int:
	# Simple deterministic offset based on hole index
	return ((seed_val * 7 + 3) % (max_offset * 2 + 1)) - max_offset


static func get_package_name(package_type: int) -> String:
	return PACKAGE_DATA[package_type].name


static func get_package_data(package_type: int) -> Dictionary:
	return PACKAGE_DATA[package_type]


static func get_all_package_types() -> Array:
	return [PackageType.STARTER, PackageType.EXECUTIVE, PackageType.STANDARD, PackageType.CHAMPIONSHIP]
