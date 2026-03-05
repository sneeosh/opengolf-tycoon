extends RefCounted
class_name QuickStartCourse
## QuickStartCourse - Builds a pre-made 9-hole course for Quick Start
##
## Programmatically lays out fairways, greens, and tee boxes
## so first-time players can immediately press Play and see golfers.
## Buildings are NOT placed — players must build their own amenities.

## Build a 9-hole course on the given terrain grid.
## Par distribution: 2x par 3, 5x par 4, 2x par 5 = Par 36
## Paints terrain and creates holes. Clears trees/rocks from course areas.
## Assumes terrain_grid is initialised with natural terrain already generated.
static func build(terrain_grid: TerrainGrid, entity_layer: EntityLayer, hole_tool: HoleCreationTool) -> void:
	# Layout uses the full 128x128 grid
	# Holes snake around the course for good flow

	# ─── Hole 1: Par 4 (380 yds, ~17 tiles, welcoming opener heading SE) ───
	var h1_tee := Vector2i(20, 20)
	var h1_green := Vector2i(32, 30)
	_paint_hole(terrain_grid, h1_tee, h1_green, 5)
	_create_hole(terrain_grid, hole_tool, h1_tee, h1_green)

	# ─── Hole 2: Par 3 (165 yds, ~8 tiles, short challenge heading E) ───
	var h2_tee := Vector2i(35, 32)
	var h2_green := Vector2i(43, 30)
	_paint_hole(terrain_grid, h2_tee, h2_green, 3)
	_create_hole(terrain_grid, hole_tool, h2_tee, h2_green)

	# ─── Hole 3: Par 5 (520 yds, ~24 tiles, risk/reward heading S) ───
	var h3_tee := Vector2i(46, 28)
	var h3_green := Vector2i(58, 48)
	_paint_hole(terrain_grid, h3_tee, h3_green, 5)
	_paint_water_hazard(terrain_grid, Vector2i(52, 38), 2)
	_create_hole(terrain_grid, hole_tool, h3_tee, h3_green)

	# ─── Hole 4: Par 4 (350 yds, ~16 tiles, dogleg right heading E then SE) ───
	var h4_tee := Vector2i(60, 50)
	var h4_green := Vector2i(74, 56)
	_paint_hole(terrain_grid, h4_tee, h4_green, 5)
	_create_hole(terrain_grid, hole_tool, h4_tee, h4_green)

	# ─── Hole 5: Par 4 (400 yds, ~18 tiles, mid-course test heading S) ───
	var h5_tee := Vector2i(76, 58)
	var h5_green := Vector2i(84, 74)
	_paint_hole(terrain_grid, h5_tee, h5_green, 5)
	_create_hole(terrain_grid, hole_tool, h5_tee, h5_green)

	# ─── Hole 6: Par 4 (370 yds, ~17 tiles, bunker-guarded heading W) ───
	var h6_tee := Vector2i(82, 78)
	var h6_green := Vector2i(68, 86)
	_paint_hole(terrain_grid, h6_tee, h6_green, 5)
	_paint_extra_bunker(terrain_grid, Vector2i(72, 84))
	_create_hole(terrain_grid, hole_tool, h6_tee, h6_green)

	# ─── Hole 7: Par 5 (530 yds, ~24 tiles, reachable par 5 heading NW) ───
	var h7_tee := Vector2i(65, 88)
	var h7_green := Vector2i(44, 76)
	_paint_hole(terrain_grid, h7_tee, h7_green, 5)
	_paint_water_hazard(terrain_grid, Vector2i(54, 82), 2)
	_create_hole(terrain_grid, hole_tool, h7_tee, h7_green)

	# ─── Hole 8: Par 3 (185 yds, ~8 tiles, signature water carry heading N) ───
	var h8_tee := Vector2i(42, 74)
	var h8_green := Vector2i(38, 66)
	_paint_hole(terrain_grid, h8_tee, h8_green, 3)
	_paint_water_hazard(terrain_grid, Vector2i(40, 70), 2)
	_create_hole(terrain_grid, hole_tool, h8_tee, h8_green)

	# ─── Hole 9: Par 4 (360 yds, ~16 tiles, fun finisher heading NW back to clubhouse) ───
	var h9_tee := Vector2i(36, 64)
	var h9_green := Vector2i(24, 52)
	_paint_hole(terrain_grid, h9_tee, h9_green, 5)
	_create_hole(terrain_grid, hole_tool, h9_tee, h9_green)

	# Remove trees and rocks that ended up on fairways, greens, tee boxes, or bunkers
	_clear_entities_on_course(terrain_grid, entity_layer)

	EventBus.notify("9-hole Whispering Pines course created! Par 36. Press Start Day to play.", "success")


## Paint a fairway corridor between tee and green, plus a small green patch and tee pad.
static func _paint_hole(terrain_grid: TerrainGrid, tee: Vector2i, green: Vector2i, corridor_width: int) -> void:
	# Paint tee box
	terrain_grid.set_tile(tee, TerrainTypes.Type.TEE_BOX)

	# Paint green (3x3 area)
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var pos := green + Vector2i(dx, dy)
			if terrain_grid.is_valid_position(pos):
				terrain_grid.set_tile(pos, TerrainTypes.Type.GREEN)

	# Paint fairway corridor using Bresenham-like line with width
	var direction := Vector2(green - tee).normalized()
	var distance := Vector2(tee).distance_to(Vector2(green))
	var steps := int(distance)

	# Perpendicular direction for corridor width
	var perp := Vector2(-direction.y, direction.x)

	for i in range(steps + 1):
		var center := Vector2(tee) + direction * float(i)
		var half_w := corridor_width / 2
		for w in range(-half_w, half_w + 1):
			var tile_pos := Vector2i(int(round(center.x + perp.x * w)), int(round(center.y + perp.y * w)))
			if terrain_grid.is_valid_position(tile_pos):
				var current := terrain_grid.get_tile(tile_pos)
				# Don't overwrite tee or green tiles
				if current != TerrainTypes.Type.TEE_BOX and current != TerrainTypes.Type.GREEN:
					terrain_grid.set_tile(tile_pos, TerrainTypes.Type.FAIRWAY)

	# Paint rough border around fairway (1 tile wider on each side)
	for i in range(steps + 1):
		var center := Vector2(tee) + direction * float(i)
		var outer_w := corridor_width / 2 + 1
		for w in [-outer_w, outer_w]:
			var tile_pos := Vector2i(int(round(center.x + perp.x * w)), int(round(center.y + perp.y * w)))
			if terrain_grid.is_valid_position(tile_pos):
				var current := terrain_grid.get_tile(tile_pos)
				if current == TerrainTypes.Type.GRASS or current == TerrainTypes.Type.EMPTY:
					terrain_grid.set_tile(tile_pos, TerrainTypes.Type.ROUGH)

	# Place a small bunker near the green
	var bunker_offset := Vector2i(int(-direction.x * 3 + perp.x * 2), int(-direction.y * 3 + perp.y * 2))
	var bunker_center := green + bunker_offset
	for dx in range(-1, 2):
		for dy in range(-1, 1):
			var bp := bunker_center + Vector2i(dx, dy)
			if terrain_grid.is_valid_position(bp):
				var current := terrain_grid.get_tile(bp)
				if current != TerrainTypes.Type.GREEN and current != TerrainTypes.Type.TEE_BOX:
					terrain_grid.set_tile(bp, TerrainTypes.Type.BUNKER)


## Paint a water hazard at the given position
static func _paint_water_hazard(terrain_grid: TerrainGrid, center: Vector2i, radius: int) -> void:
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			if dx * dx + dy * dy <= radius * radius + 1:
				var pos := center + Vector2i(dx, dy)
				if terrain_grid.is_valid_position(pos):
					var current := terrain_grid.get_tile(pos)
					if current != TerrainTypes.Type.TEE_BOX and current != TerrainTypes.Type.GREEN and current != TerrainTypes.Type.FAIRWAY:
						terrain_grid.set_tile(pos, TerrainTypes.Type.WATER)


## Paint an extra bunker cluster
static func _paint_extra_bunker(terrain_grid: TerrainGrid, center: Vector2i) -> void:
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var pos := center + Vector2i(dx, dy)
			if terrain_grid.is_valid_position(pos):
				var current := terrain_grid.get_tile(pos)
				if current != TerrainTypes.Type.GREEN and current != TerrainTypes.Type.TEE_BOX and current != TerrainTypes.Type.FAIRWAY:
					terrain_grid.set_tile(pos, TerrainTypes.Type.BUNKER)


## Programmatically create a hole entry using the HoleCreationTool internals
static func _create_hole(terrain_grid: TerrainGrid, hole_tool: HoleCreationTool, tee: Vector2i, green: Vector2i) -> void:
	var hole := GameManager.HoleData.new()
	hole.hole_number = hole_tool.current_hole_number
	hole.tee_position = tee
	hole.green_position = green
	hole.hole_position = green
	hole.distance_yards = terrain_grid.calculate_distance_yards(tee, green)
	hole.par = HoleCreationTool.calculate_par(hole.distance_yards)
	hole.difficulty_rating = DifficultyCalculator.calculate_hole_difficulty(hole, terrain_grid)

	if not GameManager.current_course:
		GameManager.current_course = GameManager.CourseData.new()

	GameManager.current_course.add_hole(hole)
	EventBus.hole_created.emit(hole.hole_number, hole.par, hole.distance_yards)
	hole_tool.current_hole_number += 1


## Remove trees and rocks that sit on course surfaces (fairway, green, tee box, bunker)
static func _clear_entities_on_course(terrain_grid: TerrainGrid, entity_layer: EntityLayer) -> void:
	if not entity_layer:
		return

	var course_terrain := [
		TerrainTypes.Type.FAIRWAY,
		TerrainTypes.Type.GREEN,
		TerrainTypes.Type.TEE_BOX,
		TerrainTypes.Type.BUNKER,
	]

	# Remove trees on course surfaces
	var tree_positions_to_remove: Array[Vector2i] = []
	for pos in entity_layer.trees.keys():
		if terrain_grid.get_tile(pos) in course_terrain:
			tree_positions_to_remove.append(pos)
	for pos in tree_positions_to_remove:
		entity_layer.remove_tree(pos)

	# Remove rocks on course surfaces
	var rock_positions_to_remove: Array[Vector2i] = []
	for pos in entity_layer.rocks.keys():
		if terrain_grid.get_tile(pos) in course_terrain:
			rock_positions_to_remove.append(pos)
	for pos in rock_positions_to_remove:
		entity_layer.remove_rock(pos)
