extends RefCounted
class_name PrebuiltCourseGenerator
## PrebuiltCourseGenerator - Builds prebuilt course packages on owned land
##
## Extends the QuickStartCourse pattern to support 4 package types.
## Reuses QuickStartCourse helpers for terrain painting and hole creation.
## Layouts are relative to the center of owned land.

const PACKAGE_COSTS: Dictionary = {
	"starter": 25000,
	"executive": 75000,
	"standard9": 100000,
	"championship18": 200000,
}

const PACKAGE_NAMES: Dictionary = {
	"starter": "Starter Pack",
	"executive": "Executive 9",
	"standard9": "Standard 9",
	"championship18": "Championship 18",
}

## Build a prebuilt course package on owned land.
static func build(
	package_id: String,
	terrain_grid: TerrainGrid,
	entity_layer: EntityLayer,
	hole_tool: HoleCreationTool
) -> void:
	# Clear existing holes first
	_clear_existing_course(hole_tool)

	terrain_grid.begin_batch()

	match package_id:
		"starter":
			_build_starter(terrain_grid, entity_layer, hole_tool)
		"executive":
			_build_executive(terrain_grid, entity_layer, hole_tool)
		"standard9":
			_build_standard9(terrain_grid, entity_layer, hole_tool)
		"championship18":
			_build_championship18(terrain_grid, entity_layer, hole_tool)

	terrain_grid.end_batch_quiet()
	terrain_grid.refresh_all_overlays()


## Get the approximate center tile of all owned land.
static func _get_owned_center() -> Vector2i:
	var lm = GameManager.land_manager
	if not lm or lm.owned_parcels.is_empty():
		return Vector2i(64, 64)
	var sum := Vector2i.ZERO
	var count := 0
	for parcel in lm.owned_parcels:
		var rect := lm.parcel_to_tile_rect(parcel)
		sum += Vector2i(rect.position.x + rect.size.x / 2, rect.position.y + rect.size.y / 2)
		count += 1
	return sum / count


## Clear all existing holes from the course.
static func _clear_existing_course(hole_tool: HoleCreationTool) -> void:
	if not GameManager.current_course:
		GameManager.current_course = GameManager.CourseData.new()
		return

	# Emit hole_deleted for each hole so HoleManager cleans up visualizations
	var hole_numbers: Array = []
	for hole in GameManager.current_course.holes:
		hole_numbers.append(hole.hole_number)

	GameManager.current_course.holes.clear()
	GameManager.current_course.total_par = 0

	for num in hole_numbers:
		EventBus.hole_deleted.emit(num)

	hole_tool.current_hole_number = 1


## Starter Pack: 3 holes (Par 4, Par 3, Par 5) in a compact layout.
static func _build_starter(
	terrain_grid: TerrainGrid,
	entity_layer: EntityLayer,
	hole_tool: HoleCreationTool
) -> void:
	var c := _get_owned_center()

	# Hole 1: Par 4 heading east (~350 yds)
	var h1_tee := c + Vector2i(-14, -8)
	var h1_green := c + Vector2i(2, -6)
	QuickStartCourse._paint_hole(terrain_grid, h1_tee, h1_green, 5)
	QuickStartCourse._create_hole(terrain_grid, hole_tool, h1_tee, h1_green)

	# Hole 2: Par 3 heading south (~190 yds)
	var h2_tee := c + Vector2i(5, -8)
	var h2_green := c + Vector2i(6, 1)
	QuickStartCourse._paint_hole(terrain_grid, h2_tee, h2_green, 3)
	QuickStartCourse._create_hole(terrain_grid, hole_tool, h2_tee, h2_green)

	# Hole 3: Par 5 heading west (~500 yds)
	var h3_tee := c + Vector2i(8, 4)
	var h3_green := c + Vector2i(-14, 6)
	QuickStartCourse._paint_hole(terrain_grid, h3_tee, h3_green, 5)
	QuickStartCourse._paint_water_hazard(terrain_grid, c + Vector2i(-4, 5), 2)
	QuickStartCourse._create_hole(terrain_grid, hole_tool, h3_tee, h3_green)

	QuickStartCourse._clear_entities_on_course(terrain_grid, entity_layer)
	EventBus.notify("Starter Pack: 3-hole course created!", "success")


## Executive 9: Nine par-3 holes in a clockwise oval.
static func _build_executive(
	terrain_grid: TerrainGrid,
	entity_layer: EntityLayer,
	hole_tool: HoleCreationTool
) -> void:
	var c := _get_owned_center()

	# Nine par-3 holes arranged in a clockwise oval pattern
	# Each hole is 7-10 tiles long (150-220 yards)
	var holes: Array = [
		# [tee_offset, green_offset, corridor_width]
		[Vector2i(-14, -12), Vector2i(-6, -14), 3],   # H1: NE
		[Vector2i(-3, -14), Vector2i(6, -12), 3],      # H2: E
		[Vector2i(8, -10), Vector2i(14, -4), 3],        # H3: SE
		[Vector2i(14, -1), Vector2i(12, 8), 3],         # H4: S
		[Vector2i(10, 10), Vector2i(2, 14), 3],         # H5: SW
		[Vector2i(0, 14), Vector2i(-8, 10), 3],         # H6: W
		[Vector2i(-10, 8), Vector2i(-14, 0), 3],        # H7: NW
		[Vector2i(-14, -2), Vector2i(-8, -8), 3],       # H8: N
		[Vector2i(-6, -6), Vector2i(2, -2), 3],         # H9: finishing
	]

	for i in range(holes.size()):
		var h = holes[i]
		var tee: Vector2i = c + Vector2i(h[0])
		var green: Vector2i = c + Vector2i(h[1])
		var width: int = h[2]
		QuickStartCourse._paint_hole(terrain_grid, tee, green, width)
		QuickStartCourse._create_hole(terrain_grid, hole_tool, tee, green)

	# Add one water hazard for variety
	QuickStartCourse._paint_water_hazard(terrain_grid, c + Vector2i(4, 4), 2)

	QuickStartCourse._clear_entities_on_course(terrain_grid, entity_layer)
	EventBus.notify("Executive 9: Par-3 course created!", "success")


## Standard 9: Mixed par 3/4/5 course. Par 36.
## Layout based on QuickStartCourse but offset from owned land center.
static func _build_standard9(
	terrain_grid: TerrainGrid,
	entity_layer: EntityLayer,
	hole_tool: HoleCreationTool
) -> void:
	var c := _get_owned_center()

	# 9-hole Par 36: 2x par 3, 5x par 4, 2x par 5
	# Holes snake around perimeter then cut through middle
	var holes: Array = [
		# [tee_offset, green_offset, width, water_offset_or_null, extra_bunker_or_null]
		[Vector2i(-17, -17), Vector2i(-1, -15), 5, null, null],              # H1: Par 4, E
		[Vector2i(2, -17), Vector2i(11, -17), 3, null, null],                # H2: Par 3, E
		[Vector2i(13, -15), Vector2i(17, 9), 5, Vector2i(15, -3), null],    # H3: Par 5, S
		[Vector2i(15, 12), Vector2i(-1, 17), 5, null, Vector2i(5, 15)],     # H4: Par 4, W
		[Vector2i(-4, 17), Vector2i(-17, 7), 5, null, null],                 # H5: Par 4, NW
		[Vector2i(-17, 4), Vector2i(-15, -11), 5, null, null],               # H6: Par 4, N
		[Vector2i(-13, -13), Vector2i(9, -7), 5, Vector2i(-1, -7), null],   # H7: Par 5, E
		[Vector2i(11, -5), Vector2i(15, 3), 3, Vector2i(13, -1), null],     # H8: Par 3, SE
		[Vector2i(13, 5), Vector2i(-1, 1), 5, null, null],                   # H9: Par 4, W
	]

	for h in holes:
		var tee: Vector2i = c + Vector2i(h[0])
		var green: Vector2i = c + Vector2i(h[1])
		QuickStartCourse._paint_hole(terrain_grid, tee, green, h[2])
		if h[3] != null:
			QuickStartCourse._paint_water_hazard(terrain_grid, c + Vector2i(h[3]), 2)
		if h[4] != null:
			QuickStartCourse._paint_extra_bunker(terrain_grid, c + Vector2i(h[4]))
		QuickStartCourse._create_hole(terrain_grid, hole_tool, tee, green)

	QuickStartCourse._clear_entities_on_course(terrain_grid, entity_layer)
	EventBus.notify("Standard 9: Par 36 course created!", "success")


## Championship 18: Full mixed course requiring 8+ parcels.
## Two 9-hole loops — inner and outer.
static func _build_championship18(
	terrain_grid: TerrainGrid,
	entity_layer: EntityLayer,
	hole_tool: HoleCreationTool
) -> void:
	var c := _get_owned_center()

	# Front 9: Inner loop (closer to center)
	# Par distribution: 2x par 3, 5x par 4, 2x par 5 = Par 36
	var front_nine: Array = [
		# [tee_offset, green_offset, width, water_pos_or_null]
		[Vector2i(-16, -16), Vector2i(0, -18), 5, null],            # H1: Par 4, E
		[Vector2i(3, -18), Vector2i(12, -16), 3, null],             # H2: Par 3, E
		[Vector2i(14, -14), Vector2i(18, 2), 5, Vector2i(16, -6)], # H3: Par 5, S
		[Vector2i(16, 5), Vector2i(2, 10), 5, null],                # H4: Par 4, W
		[Vector2i(0, 12), Vector2i(-12, 6), 5, null],               # H5: Par 4, NW
		[Vector2i(-14, 4), Vector2i(-18, -10), 5, null],            # H6: Par 4, N
		[Vector2i(-16, -12), Vector2i(4, -6), 5, Vector2i(-6, -8)],# H7: Par 5, E
		[Vector2i(6, -4), Vector2i(14, -8), 3, null],               # H8: Par 3, NE
		[Vector2i(14, -6), Vector2i(0, -2), 5, null],               # H9: Par 4, W
	]

	# Back 9: Outer loop (farther from center)
	var back_nine: Array = [
		[Vector2i(-2, 2), Vector2i(-18, -2), 5, null],               # H10: Par 4, W
		[Vector2i(-20, -4), Vector2i(-24, -18), 5, Vector2i(-22, -12)], # H11: Par 5, N
		[Vector2i(-22, -20), Vector2i(-14, -24), 3, null],           # H12: Par 3, E
		[Vector2i(-12, -24), Vector2i(4, -24), 5, null],             # H13: Par 4, E
		[Vector2i(6, -22), Vector2i(18, -24), 5, null],              # H14: Par 4, E
		[Vector2i(20, -22), Vector2i(24, -8), 5, null],              # H15: Par 5, S
		[Vector2i(22, -6), Vector2i(22, 8), 5, null],                # H16: Par 4, S
		[Vector2i(20, 10), Vector2i(10, 16), 3, null],               # H17: Par 3, SW
		[Vector2i(8, 18), Vector2i(-8, 14), 5, Vector2i(0, 16)],    # H18: Par 4, W
	]

	for h in front_nine:
		var tee: Vector2i = c + Vector2i(h[0])
		var green: Vector2i = c + Vector2i(h[1])
		QuickStartCourse._paint_hole(terrain_grid, tee, green, h[2])
		if h[3] != null:
			QuickStartCourse._paint_water_hazard(terrain_grid, c + Vector2i(h[3]), 2)
		QuickStartCourse._create_hole(terrain_grid, hole_tool, tee, green)

	for h in back_nine:
		var tee: Vector2i = c + Vector2i(h[0])
		var green: Vector2i = c + Vector2i(h[1])
		QuickStartCourse._paint_hole(terrain_grid, tee, green, h[2])
		if h[3] != null:
			QuickStartCourse._paint_water_hazard(terrain_grid, c + Vector2i(h[3]), 2)
		QuickStartCourse._create_hole(terrain_grid, hole_tool, tee, green)

	# Add extra bunkers at strategic locations
	QuickStartCourse._paint_extra_bunker(terrain_grid, c + Vector2i(10, -16))
	QuickStartCourse._paint_extra_bunker(terrain_grid, c + Vector2i(-10, 8))
	QuickStartCourse._paint_extra_bunker(terrain_grid, c + Vector2i(20, -14))

	QuickStartCourse._clear_entities_on_course(terrain_grid, entity_layer)
	EventBus.notify("Championship 18: Full course created! Par 72.", "success")
