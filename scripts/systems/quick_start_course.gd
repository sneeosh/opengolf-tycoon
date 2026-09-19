extends RefCounted
class_name QuickStartCourse
## QuickStartCourse - Builds a pre-made 9-hole course for Quick Start
##
## Programmatically lays out fairways, greens, and tee boxes
## so first-time players can immediately press Play and see golfers.
## A modest clubhouse garden and a few essential services demonstrate the management loop.

## Build a 9-hole course on the given terrain grid.
## Par distribution: 2x par 3, 5x par 4, 2x par 5 = Par 36
## Paints terrain and creates holes. Clears trees/rocks from course areas.
## Assumes terrain_grid is initialised with natural terrain already generated.
## Layout fits within the starting owned land (center 2x2 parcels = tiles 44-83).
static func build(terrain_grid: TerrainGrid, entity_layer: EntityLayer, hole_tool: HoleCreationTool) -> void:
	# Layout fits within owned land bounds (tiles 44-83 in both axes).
	# Holes snake around the perimeter then cut through the middle.

	# ─── Hole 1: Par 4 (~354 yds, ~16 tiles, welcoming opener heading E) ───
	var h1_tee := Vector2i(46, 46)
	var h1_green := Vector2i(62, 48)
	_paint_hole(terrain_grid, h1_tee, h1_green, 5)
	_create_hole(terrain_grid, hole_tool, h1_tee, h1_green)

	# ─── Hole 2: Par 3 (~198 yds, ~9 tiles, short challenge heading E) ───
	var h2_tee := Vector2i(65, 46)
	var h2_green := Vector2i(74, 46)
	_paint_hole(terrain_grid, h2_tee, h2_green, 3)
	_create_hole(terrain_grid, hole_tool, h2_tee, h2_green)

	# ─── Hole 3: Par 5 (~535 yds, ~24 tiles, risk/reward heading S) ───
	var h3_tee := Vector2i(76, 48)
	var h3_green := Vector2i(80, 72)
	_paint_hole(terrain_grid, h3_tee, h3_green, 5)
	_paint_water_hazard(terrain_grid, Vector2i(78, 60), 2)
	_create_hole(terrain_grid, hole_tool, h3_tee, h3_green)

	# ─── Hole 4: Par 4 (~370 yds, ~17 tiles, heading W along bottom) ───
	var h4_tee := Vector2i(78, 75)
	var h4_green := Vector2i(62, 80)
	_paint_hole(terrain_grid, h4_tee, h4_green, 5)
	_paint_extra_bunker(terrain_grid, Vector2i(68, 78))
	_create_hole(terrain_grid, hole_tool, h4_tee, h4_green)

	# ─── Hole 5: Par 4 (~361 yds, ~16 tiles, heading NW) ───
	var h5_tee := Vector2i(59, 80)
	var h5_green := Vector2i(46, 70)
	_paint_hole(terrain_grid, h5_tee, h5_green, 5)
	_create_hole(terrain_grid, hole_tool, h5_tee, h5_green)

	# ─── Hole 6: Par 4 (~332 yds, ~15 tiles, heading N up left side) ───
	var h6_tee := Vector2i(46, 67)
	var h6_green := Vector2i(48, 52)
	_paint_hole(terrain_grid, h6_tee, h6_green, 5)
	_create_hole(terrain_grid, hole_tool, h6_tee, h6_green)

	# ─── Hole 7: Par 5 (~502 yds, ~23 tiles, heading E through the middle) ───
	var h7_tee := Vector2i(50, 50)
	var h7_green := Vector2i(72, 56)
	_paint_hole(terrain_grid, h7_tee, h7_green, 5)
	_paint_water_hazard(terrain_grid, Vector2i(62, 56), 2)
	_create_hole(terrain_grid, hole_tool, h7_tee, h7_green)

	# ─── Hole 8: Par 3 (~196 yds, ~9 tiles, signature water carry heading SE) ───
	var h8_tee := Vector2i(74, 58)
	var h8_green := Vector2i(78, 66)
	_paint_hole(terrain_grid, h8_tee, h8_green, 3)
	_paint_water_hazard(terrain_grid, Vector2i(76, 62), 2)
	_create_hole(terrain_grid, hole_tool, h8_tee, h8_green)

	# ─── Hole 9: Par 4 (~321 yds, ~15 tiles, fun finisher heading W) ───
	var h9_tee := Vector2i(76, 68)
	var h9_green := Vector2i(62, 64)
	_paint_hole(terrain_grid, h9_tee, h9_green, 5)
	_create_hole(terrain_grid, hole_tool, h9_tee, h9_green)

	# Remove trees and rocks that ended up on fairways, greens, tee boxes, or bunkers
	_clear_entities_on_course(terrain_grid, entity_layer)

	_build_arrival_garden(terrain_grid, entity_layer)
	_plant_arrival_groups(terrain_grid, entity_layer)
	GameManager.set_green_fee(5)
	EventBus.notify("Nine holes, a clubhouse garden and starter amenities are ready. Review the course or Start Day.", "success")


## Check if a tile is within owned land (safety net for corridor painting).
static func _is_owned(pos: Vector2i) -> bool:
	if GameManager.land_manager:
		return GameManager.land_manager.is_tile_owned(pos)
	return true  # No land manager = no restriction


## Paint a fairway corridor between tee and green, plus a small green patch and tee pad.
static func _paint_hole(terrain_grid: TerrainGrid, tee: Vector2i, green: Vector2i, corridor_width: int) -> void:
	# Paint tee box
	terrain_grid.set_tile(tee, TerrainTypes.Type.TEE_BOX)

	# Paint green (3x3 area)
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var pos := green + Vector2i(dx, dy)
			if terrain_grid.is_valid_position(pos) and _is_owned(pos):
				terrain_grid.set_tile(pos, TerrainTypes.Type.GREEN)

	# Gently bending, variable-width landing areas replace ruler-straight strips.
	var direction := Vector2(green - tee).normalized()
	var distance := Vector2(tee).distance_to(Vector2(green))
	var perp := Vector2(-direction.y, direction.x)
	var steps := int(distance * 2)
	for i in range(steps + 1):
		var t := float(i) / maxi(steps, 1)
		var bend := sin(t * PI) * sin(t * PI * 1.6) * 1.7
		var center := Vector2(tee).lerp(Vector2(green), t) + perp * bend
		var radius := lerpf(1.0, corridor_width * .5, sin(t * PI) * .65 + .35)
		for dx in range(-4,5):
			for dy in range(-4,5):
				var delta := Vector2(dx,dy)
				var point := Vector2i(center.round()) + Vector2i(dx,dy)
				if delta.length() > radius or not terrain_grid.is_valid_position(point) or not _is_owned(point): continue
				var current := terrain_grid.get_tile(point)
				if current not in [TerrainTypes.Type.TEE_BOX, TerrainTypes.Type.GREEN, TerrainTypes.Type.WATER, TerrainTypes.Type.BUNKER]:
					terrain_grid.set_tile(point, TerrainTypes.Type.FAIRWAY)

	# Place a small bunker near the green
	var bunker_offset := Vector2i(int(-direction.x * 3 + perp.x * 2), int(-direction.y * 3 + perp.y * 2))
	var bunker_center := green + bunker_offset
	for dx in range(-1, 2):
		for dy in range(-1, 1):
			var bp := bunker_center + Vector2i(dx, dy)
			if terrain_grid.is_valid_position(bp) and _is_owned(bp):
				var current := terrain_grid.get_tile(bp)
				if current != TerrainTypes.Type.GREEN and current != TerrainTypes.Type.TEE_BOX:
					terrain_grid.set_tile(bp, TerrainTypes.Type.BUNKER)

	# Three signature holes have real elevation, rather than decorative shading.
	if tee in [Vector2i(65, 46), Vector2i(59, 80), Vector2i(74, 58)]:
		SculptedTerrain.stamp(terrain_grid, green, 5, 2)
		SculptedTerrain.stamp(terrain_grid, tee, 4, 3)
		SculptedTerrain.stamp(terrain_grid, Vector2i((Vector2(tee) + Vector2(green)) * 0.5), 4, -1)


## Paint a water hazard at the given position
static func _paint_water_hazard(terrain_grid: TerrainGrid, center: Vector2i, radius: int) -> void:
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			if dx * dx + dy * dy <= radius * radius + 1:
				var pos := center + Vector2i(dx, dy)
				if terrain_grid.is_valid_position(pos) and _is_owned(pos):
					var current := terrain_grid.get_tile(pos)
					if current != TerrainTypes.Type.TEE_BOX and current != TerrainTypes.Type.GREEN and current != TerrainTypes.Type.FAIRWAY:
						terrain_grid.set_tile(pos, TerrainTypes.Type.WATER)


## Paint an extra bunker cluster
static func _paint_extra_bunker(terrain_grid: TerrainGrid, center: Vector2i) -> void:
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var pos := center + Vector2i(dx, dy)
			if terrain_grid.is_valid_position(pos) and _is_owned(pos):
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
	# Auto-generate multiple tee boxes and pin positions
	hole.tee_positions = {"back": hole.tee_position, "middle": hole.tee_position, "forward": hole.tee_position}
	if GameManager.multi_tee_enabled:
		hole.auto_generate_tee_positions(terrain_grid)
		for tee_key in ["forward", "middle"]:
			var tee_pos: Vector2i = hole.tee_positions[tee_key]
			if tee_pos != hole.tee_position and terrain_grid.is_valid_position(tee_pos):
				terrain_grid.set_tile(tee_pos, TerrainTypes.Type.TEE_BOX)
	hole.pin_positions = [hole.hole_position]
	hole.auto_generate_pin_positions(terrain_grid)
	hole.recalculate_par_by_tee(terrain_grid)

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
		TerrainTypes.Type.WATER,
	]

	# Remove trees on course surfaces
	var tree_positions_to_remove: Array[Vector2i] = []
	for pos in entity_layer.trees.keys():
		if terrain_grid.get_tile(pos) in course_terrain:
			tree_positions_to_remove.append(pos)
	for pos in tree_positions_to_remove:
		var surface := terrain_grid.get_tile(pos)
		entity_layer.remove_tree(pos)
		terrain_grid.set_tile(pos, surface)

	# Remove rocks on course surfaces
	var rock_positions_to_remove: Array[Vector2i] = []
	for pos in entity_layer.rocks.keys():
		if terrain_grid.get_tile(pos) in course_terrain:
			rock_positions_to_remove.append(pos)
	for pos in rock_positions_to_remove:
		var surface := terrain_grid.get_tile(pos)
		entity_layer.remove_rock(pos)
		terrain_grid.set_tile(pos, surface)

## Compact central arrival garden, outside the nine playing corridors.
static func _build_arrival_garden(grid: TerrainGrid, entities: EntityLayer) -> void:
	if not entities: return
	var buildings: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/buildings.json")).buildings
	var decor: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/decorations.json")).decorations
	for x in range(53,61):
		for y in range(60,70):
			var p := Vector2i(x,y)
			if not _is_owned(p): continue
			if grid.get_tile(p) in [TerrainTypes.Type.GREEN,TerrainTypes.Type.TEE_BOX,TerrainTypes.Type.FAIRWAY]: continue
			entities.remove_tree(p)
			entities.remove_rock(p)
			grid.set_tile(p, TerrainTypes.Type.PATH if y >= 65 and y <= 67 else TerrainTypes.Type.GRASS)
	for item in [["clubhouse",Vector2i(54,61)],["coffee_house",Vector2i(59,61)],["restroom",Vector2i(56,68)],["snack_bar",Vector2i(66,74)]]:
		var kind: String = item[0]
		var position: Vector2i = item[1]
		for dx in range(buildings[kind].size[0]):
			for dy in range(buildings[kind].size[1]):
				var p := position + Vector2i(dx,dy)
				entities.remove_tree(p)
				entities.remove_rock(p)
				grid.set_tile(p,TerrainTypes.Type.GRASS)
		entities.place_building(kind, position, buildings)
	# The same player-placeable items compose a legible entrance, terrace and garden.
	var dry := GameManager.current_theme in [CourseTheme.Type.DESERT,CourseTheme.Type.LINKS,CourseTheme.Type.HEATHLAND]
	for item in [["rose_arch",Vector2i(57,67)],["patio_table",Vector2i(59,65)],["patio_table",Vector2i(60,66)],["park_bench",Vector2i(54,66)],["lily_pool",Vector2i(54,68)],["garden_lamp",Vector2i(53,65)],["garden_lamp",Vector2i(60,67)],["course_clock",Vector2i(58,67)],["terracotta_planters",Vector2i(58,65)],["pergola",Vector2i(53,67)]]:
		entities.place_decoration(item[0],item[1],decor)
	for x in range(53,61):
		for y in [59,69]:
			var p := Vector2i(x,y)
			if grid.get_tile(p) in [TerrainTypes.Type.FAIRWAY,TerrainTypes.Type.GREEN,TerrainTypes.Type.TEE_BOX]: continue
			entities.remove_tree(p)
			entities.remove_rock(p)
			grid.set_tile(p,TerrainTypes.Type.GRASS)
			entities.place_decoration("ornamental_grass" if dry else ("lavender_bed" if x%2 else "rose_border"),p,decor)
	for item in [[Vector2i(50,69),"park_bench"],[Vector2i(70,58),"park_bench"],[Vector2i(65,74),"park_bench"]]:
		var p: Vector2i = item[0]
		if grid.get_tile(p) in [TerrainTypes.Type.GREEN, TerrainTypes.Type.TEE_BOX]: continue
		if entities.get_decoration_at(p) or entities.is_tile_occupied_by_building(p): continue
		entities.remove_tree(p)
		entities.remove_rock(p)
		grid.set_tile(p,TerrainTypes.Type.PATH)
		entities.place_decoration(item[1],p,decor)

## Small layered planting groups keep the entrance from reading as isolated props.
static func _plant_arrival_groups(grid: TerrainGrid, entities: EntityLayer) -> void:
	var dry := GameManager.current_theme in [CourseTheme.Type.DESERT,CourseTheme.Type.LINKS,CourseTheme.Type.HEATHLAND]
	for item in [[Vector2i(51,60),"birch"],[Vector2i(52,59),"bush"],[Vector2i(51,62),"heather"],[Vector2i(61,59),"maple"],[Vector2i(62,60),"bush"],[Vector2i(52,70),"birch"],[Vector2i(53,71),"heather"],[Vector2i(60,70),"bush"]]:
		var pos: Vector2i = item[0]
		if not _is_owned(pos) or grid.get_tile(pos) not in [TerrainTypes.Type.GRASS,TerrainTypes.Type.ROUGH]: continue
		if entities.get_tree_at(pos) or entities.get_rock_at(pos) or entities.is_tile_occupied_by_building(pos) or entities.get_decoration_at(pos): continue
		entities.place_tree(pos,"fescue" if dry else item[1])
