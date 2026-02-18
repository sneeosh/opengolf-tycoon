extends RefCounted
class_name QuickStartCourse
## QuickStartCourse - Builds a pre-made 3-hole starter course for Quick Start
##
## Programmatically lays out fairways, greens, tee boxes, and a few buildings
## so first-time players can immediately press Play and see golfers.

## Build a demo 3-hole course on the given terrain grid.
## Paints terrain, creates holes, places a clubhouse and benches.
## Assumes terrain_grid is initialised with natural terrain already generated.
static func build(terrain_grid: TerrainGrid, entity_layer: EntityLayer, hole_tool: HoleCreationTool) -> void:
	var cx: int = terrain_grid.grid_width / 2
	var cy: int = terrain_grid.grid_height / 2

	# ─── Hole 1: Par 3 (short, straight south-east) ───
	var h1_tee := Vector2i(cx - 12, cy - 6)
	var h1_green := Vector2i(cx - 4, cy - 2)
	_paint_hole(terrain_grid, h1_tee, h1_green, 3)
	_create_hole(terrain_grid, hole_tool, h1_tee, h1_green)

	# ─── Hole 2: Par 4 (medium, south) ───
	var h2_tee := Vector2i(cx - 2, cy - 8)
	var h2_green := Vector2i(cx + 4, cy + 6)
	_paint_hole(terrain_grid, h2_tee, h2_green, 5)
	_create_hole(terrain_grid, hole_tool, h2_tee, h2_green)

	# ─── Hole 3: Par 4 (medium, south-west) ───
	var h3_tee := Vector2i(cx + 6, cy - 6)
	var h3_green := Vector2i(cx + 14, cy + 2)
	_paint_hole(terrain_grid, h3_tee, h3_green, 5)
	_create_hole(terrain_grid, hole_tool, h3_tee, h3_green)

	# ─── Place a Clubhouse near the first tee ───
	var clubhouse_pos := Vector2i(cx - 14, cy - 4)
	if entity_layer:
		var building_data := _load_building_data("clubhouse")
		if not building_data.is_empty():
			entity_layer.place_building("clubhouse", clubhouse_pos, {"clubhouse": building_data})

	# ─── Place a Bench between holes ───
	var bench_pos := Vector2i(cx - 6, cy - 8)
	if entity_layer:
		var bench_data := _load_building_data("bench")
		if not bench_data.is_empty():
			entity_layer.place_building("bench", bench_pos, {"bench": bench_data})

	EventBus.notify("Quick Start course created! Press Start Day to play.", "success")


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


## Load a single building definition from buildings.json
static func _load_building_data(building_type: String) -> Dictionary:
	var file := FileAccess.open("res://data/buildings.json", FileAccess.READ)
	if file == null:
		return {}
	var data = JSON.parse_string(file.get_as_text())
	if data and data.has("buildings") and data["buildings"].has(building_type):
		return data["buildings"][building_type]
	return {}
