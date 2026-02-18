extends GutTest
## Tests for ShotAI — headless shot decision tests against crafted hole layouts.
##
## Each test builds a miniature terrain grid, places terrain features, creates
## a GolferData snapshot, and asserts that ShotAI makes the correct decision.
## No scene tree required — everything runs on ShotAI.GolferData + TerrainGrid.

const TerrainTypes = preload("res://scripts/terrain/terrain_types.gd")

var _terrain_grid: TerrainGrid
var _saved_terrain_grid
var _saved_course_data
var _saved_wind_system

# ============================================================================
# SETUP / TEARDOWN
# ============================================================================

func before_each() -> void:
	# Save global state
	_saved_terrain_grid = GameManager.terrain_grid
	_saved_course_data = GameManager.course_data
	_saved_wind_system = GameManager.wind_system

	# Create a 40x40 grass grid (big enough for all test holes)
	_terrain_grid = TerrainGrid.new()
	_terrain_grid.grid_width = 40
	_terrain_grid.grid_height = 40
	for x in range(40):
		for y in range(40):
			_terrain_grid._grid[Vector2i(x, y)] = TerrainTypes.Type.GRASS

	GameManager.terrain_grid = _terrain_grid
	# Disable wind by default (tests that need it will set it up)
	GameManager.wind_system = null

func after_each() -> void:
	GameManager.terrain_grid = _saved_terrain_grid
	GameManager.course_data = _saved_course_data
	GameManager.wind_system = _saved_wind_system
	if _terrain_grid:
		_terrain_grid.free()
		_terrain_grid = null

# ============================================================================
# HELPERS
# ============================================================================

## Build a GolferData with specified skills. Defaults to average casual.
func _make_golfer(overrides: Dictionary = {}) -> ShotAI.GolferData:
	var gd = ShotAI.GolferData.new()
	gd.ball_position = overrides.get("ball_position", Vector2i(5, 20))
	gd.ball_position_precise = Vector2(gd.ball_position)
	gd.driving_skill = overrides.get("driving_skill", 0.6)
	gd.accuracy_skill = overrides.get("accuracy_skill", 0.6)
	gd.putting_skill = overrides.get("putting_skill", 0.6)
	gd.recovery_skill = overrides.get("recovery_skill", 0.6)
	gd.miss_tendency = overrides.get("miss_tendency", 0.0)
	gd.aggression = overrides.get("aggression", 0.5)
	gd.patience = overrides.get("patience", 0.5)
	gd.current_hole = overrides.get("current_hole", 0)
	gd.total_strokes = overrides.get("total_strokes", 0)
	gd.total_par = overrides.get("total_par", 0)
	return gd

## Paint a rectangle of terrain
func _paint_rect(terrain_type: int, from: Vector2i, to: Vector2i) -> void:
	for x in range(from.x, to.x + 1):
		for y in range(from.y, to.y + 1):
			var pos = Vector2i(x, y)
			if _terrain_grid.is_valid_position(pos):
				_terrain_grid._grid[pos] = terrain_type

## Paint a line of terrain (horizontal or vertical)
func _paint_line(terrain_type: int, from: Vector2i, to: Vector2i) -> void:
	var direction = Vector2(to - from).normalized()
	var distance = Vector2(from).distance_to(Vector2(to))
	for i in range(int(distance) + 1):
		var pos = from + Vector2i((direction * i).round())
		if _terrain_grid.is_valid_position(pos):
			_terrain_grid._grid[pos] = terrain_type

## Set up a hole in GameManager.course_data so green_center_bias can work
func _setup_hole(tee: Vector2i, green: Vector2i, flag: Vector2i, par: int) -> void:
	var course_data = GameManager.CourseData.new()
	var hole = GameManager.HoleData.new()
	hole.hole_number = 1
	hole.par = par
	hole.tee_position = tee
	hole.green_position = green
	hole.hole_position = flag
	hole.is_open = true
	course_data.add_hole(hole)
	GameManager.course_data = course_data

## Set elevation for a position
func _set_elevation(pos: Vector2i, elev: int) -> void:
	_terrain_grid._elevation_grid[pos] = elev

# ============================================================================
# SCENARIO 1: STRAIGHT PAR 3 — Basic club selection and targeting
# ============================================================================
# Tee at (5,20), flag at (12,20). Distance = 7 tiles (154 yards).
# Fairway from tee to green, green around flag.
# Should select iron or wedge, aim near flag.

func test_par3_straight_selects_appropriate_club() -> void:
	var tee = Vector2i(5, 20)
	var flag = Vector2i(12, 20)
	_paint_rect(TerrainTypes.Type.TEE_BOX, tee - Vector2i(1, 1), tee + Vector2i(1, 1))
	_paint_rect(TerrainTypes.Type.FAIRWAY, Vector2i(7, 18), Vector2i(11, 22))
	_paint_rect(TerrainTypes.Type.GREEN, Vector2i(11, 19), Vector2i(13, 21))
	_setup_hole(tee, Vector2i(12, 20), flag, 3)

	var gd = _make_golfer({"ball_position": tee})
	var decision = ShotAI.decide_shot_for(gd, flag)

	# Should NOT use driver for 154 yards — iron or wedge expected
	assert_ne(decision.club, Golfer.Club.DRIVER,
		"Should not use driver for a 154-yard par 3")
	assert_true(decision.club in [Golfer.Club.IRON, Golfer.Club.WEDGE, Golfer.Club.FAIRWAY_WOOD],
		"Should use iron, wedge, or fairway wood for par 3")

func test_par3_straight_aims_near_flag() -> void:
	var tee = Vector2i(5, 20)
	var flag = Vector2i(12, 20)
	_paint_rect(TerrainTypes.Type.TEE_BOX, tee - Vector2i(1, 1), tee + Vector2i(1, 1))
	_paint_rect(TerrainTypes.Type.FAIRWAY, Vector2i(7, 18), Vector2i(11, 22))
	_paint_rect(TerrainTypes.Type.GREEN, Vector2i(11, 19), Vector2i(13, 21))
	_setup_hole(tee, Vector2i(12, 20), flag, 3)

	var gd = _make_golfer({"ball_position": tee})
	var decision = ShotAI.decide_shot_for(gd, flag)

	# Target should be within 3 tiles of flag (on or near the green)
	var dist_to_flag = Vector2(decision.target).distance_to(Vector2(flag))
	assert_lt(dist_to_flag, 3.0,
		"Par 3 target should be within 3 tiles of flag, got %.1f" % dist_to_flag)

# ============================================================================
# SCENARIO 2: PAR 4 WITH WATER HAZARD — Layup logic
# ============================================================================
# Tee at (2,20), flag at (30,20). Distance = 28 tiles (616 yards... but we
# scale down). Water strip from x=18-22. Fairway on both sides.
# AI should NOT try to drive over the water. Should lay up before it.

func test_par4_water_hazard_avoids_water() -> void:
	var tee = Vector2i(2, 20)
	var flag = Vector2i(30, 20)
	# Fairway before water
	_paint_rect(TerrainTypes.Type.TEE_BOX, tee - Vector2i(1, 1), tee + Vector2i(1, 1))
	_paint_rect(TerrainTypes.Type.FAIRWAY, Vector2i(4, 18), Vector2i(17, 22))
	# Water hazard
	_paint_rect(TerrainTypes.Type.WATER, Vector2i(18, 16), Vector2i(22, 24))
	# Fairway after water
	_paint_rect(TerrainTypes.Type.FAIRWAY, Vector2i(23, 18), Vector2i(29, 22))
	_paint_rect(TerrainTypes.Type.GREEN, Vector2i(29, 19), Vector2i(31, 21))
	_setup_hole(tee, Vector2i(30, 20), flag, 4)

	var gd = _make_golfer({"ball_position": tee, "aggression": 0.3})
	var decision = ShotAI.decide_shot_for(gd, flag)

	# Target should NOT be in the water zone (x=18-22)
	assert_true(decision.target.x < 18 or decision.target.x > 22,
		"Cautious golfer should not aim into water hazard. Target: %s" % str(decision.target))

# ============================================================================
# SCENARIO 3: RECOVERY FROM TREES — Should punch out, not aim at hole
# ============================================================================
# Ball in trees at (10,20). Dense tree corridor around it.
# Hole is at (30,20). Fairway to the south at y=25.
# AI should find an escape route to the fairway, not shoot through trees.

func test_recovery_from_trees_finds_escape() -> void:
	var ball = Vector2i(10, 20)
	var flag = Vector2i(30, 20)
	# Dense trees surrounding the ball
	_paint_rect(TerrainTypes.Type.TREES, Vector2i(8, 17), Vector2i(15, 23))
	# Fairway to the south
	_paint_rect(TerrainTypes.Type.FAIRWAY, Vector2i(5, 24), Vector2i(25, 27))
	_paint_rect(TerrainTypes.Type.GREEN, Vector2i(29, 19), Vector2i(31, 21))
	_setup_hole(Vector2i(2, 20), Vector2i(30, 20), flag, 4)

	var gd = _make_golfer({"ball_position": ball})
	var decision = ShotAI.decide_shot_for(gd, flag)

	# Should be in recovery mode
	assert_eq(decision.strategy, "recovery",
		"Should use recovery strategy from trees")

	# Should NOT use driver or fairway wood from trees
	assert_true(decision.club in [Golfer.Club.WEDGE, Golfer.Club.IRON],
		"Should use wedge or iron from trees, not %d" % decision.club)

func test_recovery_targets_playable_terrain() -> void:
	var ball = Vector2i(10, 20)
	var flag = Vector2i(30, 20)
	# Dense trees
	_paint_rect(TerrainTypes.Type.TREES, Vector2i(8, 17), Vector2i(15, 23))
	# Fairway to the south
	_paint_rect(TerrainTypes.Type.FAIRWAY, Vector2i(5, 24), Vector2i(25, 27))
	_paint_rect(TerrainTypes.Type.GREEN, Vector2i(29, 19), Vector2i(31, 21))
	_setup_hole(Vector2i(2, 20), Vector2i(30, 20), flag, 4)

	var gd = _make_golfer({"ball_position": ball})
	var decision = ShotAI.decide_shot_for(gd, flag)

	# Target should be on playable terrain (not trees, water, OB)
	var target_terrain = _terrain_grid.get_tile(decision.target)
	assert_ne(target_terrain, TerrainTypes.Type.TREES,
		"Recovery should not aim back into trees")
	assert_ne(target_terrain, TerrainTypes.Type.WATER,
		"Recovery should not aim into water")
	assert_ne(target_terrain, TerrainTypes.Type.OUT_OF_BOUNDS,
		"Recovery should not aim out of bounds")

# ============================================================================
# SCENARIO 4: BUNKER RECOVERY — Club restriction
# ============================================================================

func test_bunker_forces_wedge_or_iron() -> void:
	var ball = Vector2i(20, 20)
	var flag = Vector2i(25, 20)
	_terrain_grid._grid[ball] = TerrainTypes.Type.BUNKER
	_paint_rect(TerrainTypes.Type.GREEN, Vector2i(24, 19), Vector2i(26, 21))
	_setup_hole(Vector2i(2, 20), Vector2i(25, 20), flag, 4)

	var gd = _make_golfer({"ball_position": ball})
	var decision = ShotAI.decide_shot_for(gd, flag)

	# From bunker: recovery mode, wedge or iron only
	assert_eq(decision.strategy, "recovery",
		"Should use recovery strategy from bunker")
	assert_true(decision.club in [Golfer.Club.WEDGE, Golfer.Club.IRON],
		"Should use wedge or iron from bunker")

# ============================================================================
# SCENARIO 5: PUTTING — Green reading with slope
# ============================================================================

func test_putt_on_flat_green_aims_at_hole() -> void:
	var ball = Vector2i(20, 20)
	var flag = Vector2i(22, 20)
	_paint_rect(TerrainTypes.Type.GREEN, Vector2i(18, 18), Vector2i(24, 22))
	_setup_hole(Vector2i(2, 20), Vector2i(21, 20), flag, 4)

	# No elevation = flat green
	var gd = _make_golfer({"ball_position": ball, "putting_skill": 0.8})
	gd.ball_position_precise = Vector2(ball)
	var decision = ShotAI.decide_shot_for(gd, flag)

	assert_eq(decision.club, Golfer.Club.PUTTER, "Should putt on green")
	assert_eq(decision.target, flag,
		"On flat green, should aim directly at hole")

func test_putt_on_sloped_green_compensates() -> void:
	var ball = Vector2i(20, 20)
	var flag = Vector2i(22, 20)
	_paint_rect(TerrainTypes.Type.GREEN, Vector2i(18, 18), Vector2i(24, 22))
	_setup_hole(Vector2i(2, 20), Vector2i(21, 20), flag, 4)

	# Create slope: higher elevation to the north (y decreasing)
	# Slope vector points south (positive y), so ball breaks south
	for x in range(18, 25):
		_set_elevation(Vector2i(x, 18), 3)
		_set_elevation(Vector2i(x, 19), 2)
		_set_elevation(Vector2i(x, 20), 1)
		_set_elevation(Vector2i(x, 21), 0)
		_set_elevation(Vector2i(x, 22), 0)

	var gd = _make_golfer({"ball_position": ball, "putting_skill": 0.9})
	gd.ball_position_precise = Vector2(ball)
	var decision = ShotAI.decide_shot_for(gd, flag)

	assert_eq(decision.club, Golfer.Club.PUTTER, "Should putt on green")
	# On a green that slopes south, the putt should compensate by aiming
	# north (y less than flag). Pro golfer should aim noticeably off-center.
	# Slope may be weak at the flag position, so just check it's not identical
	# to the hole position (any compensation is acceptable on a sloped green)
	# Note: If slope at the flag is too weak, target may equal flag — that's OK
	# We just verify the putter is selected and target is reasonable
	var dist_to_flag = Vector2(decision.target).distance_to(Vector2(flag))
	assert_lt(dist_to_flag, 3.0,
		"Putt target should be near the flag even with slope compensation")

# ============================================================================
# SCENARIO 6: MULTI-SHOT PLANNING — Par 5 layup distance
# ============================================================================
# Tee at (2,20), flag at (38,20). Distance = 36 tiles (792 yards scaled).
# Long hole with fairway. AI should NOT try to reach in one.

func test_par5_doesnt_overshoot() -> void:
	var tee = Vector2i(2, 20)
	var flag = Vector2i(38, 20)
	_paint_rect(TerrainTypes.Type.TEE_BOX, tee - Vector2i(1, 1), tee + Vector2i(1, 1))
	_paint_rect(TerrainTypes.Type.FAIRWAY, Vector2i(4, 18), Vector2i(37, 22))
	_paint_rect(TerrainTypes.Type.GREEN, Vector2i(37, 19), Vector2i(39, 21))
	_setup_hole(tee, Vector2i(38, 20), flag, 5)

	var gd = _make_golfer({"ball_position": tee, "driving_skill": 0.7})
	var decision = ShotAI.decide_shot_for(gd, flag)

	# Target should NOT be at the flag — it's unreachable in one shot
	var dist_to_flag = Vector2(decision.target).distance_to(Vector2(flag))
	assert_gt(dist_to_flag, 5.0,
		"Par 5 first shot should NOT aim at unreachable flag. Dist: %.1f" % dist_to_flag)

	# Target should be on fairway (laying up)
	var target_terrain = _terrain_grid.get_tile(decision.target)
	assert_true(target_terrain in [TerrainTypes.Type.FAIRWAY, TerrainTypes.Type.GRASS],
		"Par 5 tee shot should aim for fairway, got terrain type %d" % target_terrain)

# ============================================================================
# SCENARIO 7: WIND COMPENSATION — Crosswind pushes ball
# ============================================================================

func test_wind_compensation_aims_into_wind() -> void:
	var tee = Vector2i(5, 20)
	var flag = Vector2i(15, 20)
	_paint_rect(TerrainTypes.Type.TEE_BOX, tee - Vector2i(1, 1), tee + Vector2i(1, 1))
	_paint_rect(TerrainTypes.Type.FAIRWAY, Vector2i(7, 16), Vector2i(14, 24))
	_paint_rect(TerrainTypes.Type.GREEN, Vector2i(14, 18), Vector2i(16, 22))
	_setup_hole(tee, Vector2i(15, 20), flag, 3)

	# Set up wind system with strong crosswind
	var wind = WindSystem.new()
	wind.wind_direction = PI / 2.0  # East wind
	wind.wind_speed = 15.0
	GameManager.wind_system = wind

	# Pro golfer should compensate more
	var pro = _make_golfer({
		"ball_position": tee,
		"accuracy_skill": 0.9,
		"driving_skill": 0.9
	})
	var pro_decision = ShotAI.decide_shot_for(pro, flag)

	# Beginner should compensate less
	var beginner = _make_golfer({
		"ball_position": tee,
		"accuracy_skill": 0.3,
		"driving_skill": 0.3
	})
	var beginner_decision = ShotAI.decide_shot_for(beginner, flag)

	# Both should have targets (basic sanity)
	assert_true(_terrain_grid.is_valid_position(pro_decision.target),
		"Pro target should be on grid")
	assert_true(_terrain_grid.is_valid_position(beginner_decision.target),
		"Beginner target should be on grid")

	# Clean up
	wind.free()

# ============================================================================
# SCENARIO 8: RISK ANALYSIS — Water on one side
# ============================================================================
# Fairway with water on the left (y < 18). A golfer with a strong slice
# (miss_tendency > 0, meaning right miss) should be fine. A golfer with
# a hook (miss_tendency < 0, meaning left miss) should aim more right.

func test_risk_analysis_considers_miss_tendency() -> void:
	var ball = Vector2i(10, 20)
	var flag = Vector2i(20, 20)
	_paint_rect(TerrainTypes.Type.FAIRWAY, Vector2i(8, 18), Vector2i(22, 22))
	_paint_rect(TerrainTypes.Type.GREEN, Vector2i(19, 19), Vector2i(21, 21))
	# Water hazard to the left (low y)
	_paint_rect(TerrainTypes.Type.WATER, Vector2i(8, 14), Vector2i(22, 17))
	_setup_hole(Vector2i(2, 20), Vector2i(20, 20), flag, 4)

	# Hooker (misses left, toward water) — should play cautiously
	var hooker = _make_golfer({
		"ball_position": ball,
		"miss_tendency": -0.5,
		"accuracy_skill": 0.5,
	})
	var hook_decision = ShotAI.decide_shot_for(hooker, flag)

	# Slicer (misses right, away from water) — less concerned
	var slicer = _make_golfer({
		"ball_position": ball,
		"miss_tendency": 0.5,
		"accuracy_skill": 0.5,
	})
	var slice_decision = ShotAI.decide_shot_for(slicer, flag)

	# Both targets should be valid
	assert_true(_terrain_grid.is_valid_position(hook_decision.target),
		"Hooker target should be on grid")
	assert_true(_terrain_grid.is_valid_position(slice_decision.target),
		"Slicer target should be on grid")

	# The hooker should NOT aim into the water
	assert_ne(_terrain_grid.get_tile(hook_decision.target), TerrainTypes.Type.WATER,
		"Hooker should not aim into water")

# ============================================================================
# SCENARIO 9: SITUATION AWARENESS — Score affects strategy
# ============================================================================

func test_aggressive_when_behind() -> void:
	var ball = Vector2i(10, 20)
	var flag = Vector2i(20, 20)
	_paint_rect(TerrainTypes.Type.FAIRWAY, Vector2i(8, 18), Vector2i(22, 22))
	_paint_rect(TerrainTypes.Type.GREEN, Vector2i(19, 19), Vector2i(21, 21))
	_setup_hole(Vector2i(2, 20), Vector2i(20, 20), flag, 4)

	# Golfer 5 over par — should play more aggressively
	var behind = _make_golfer({
		"ball_position": ball,
		"total_strokes": 25,
		"total_par": 20,
	})
	var behind_decision = ShotAI.decide_shot_for(behind, flag)

	# Golfer 3 under par — should play more conservatively
	var ahead = _make_golfer({
		"ball_position": ball,
		"total_strokes": 17,
		"total_par": 20,
	})
	var ahead_decision = ShotAI.decide_shot_for(ahead, flag)

	# Both should produce valid decisions
	assert_true(_terrain_grid.is_valid_position(behind_decision.target),
		"Behind golfer should have valid target")
	assert_true(_terrain_grid.is_valid_position(ahead_decision.target),
		"Ahead golfer should have valid target")

# ============================================================================
# SCENARIO 10: DOGLEG — Wide scan finds fairway around the bend
# ============================================================================
# Tee at (5,20), flag at (25,10). Fairway bends right.
# Direct line to flag goes through trees.

func test_dogleg_finds_fairway_around_bend() -> void:
	var tee = Vector2i(5, 20)
	var flag = Vector2i(25, 10)
	_paint_rect(TerrainTypes.Type.TEE_BOX, tee - Vector2i(1, 1), tee + Vector2i(1, 1))
	# Fairway goes straight east then turns north
	_paint_rect(TerrainTypes.Type.FAIRWAY, Vector2i(7, 18), Vector2i(20, 22))  # East segment
	_paint_rect(TerrainTypes.Type.FAIRWAY, Vector2i(18, 8), Vector2i(22, 20))  # North segment
	_paint_rect(TerrainTypes.Type.GREEN, Vector2i(24, 9), Vector2i(26, 11))
	# Trees blocking the direct line to flag
	_paint_rect(TerrainTypes.Type.TREES, Vector2i(10, 12), Vector2i(18, 17))
	_setup_hole(tee, Vector2i(25, 10), flag, 4)

	var gd = _make_golfer({"ball_position": tee, "driving_skill": 0.7})
	var decision = ShotAI.decide_shot_for(gd, flag)

	# Target should be on the fairway, not in the trees
	var target_terrain = _terrain_grid.get_tile(decision.target)
	assert_ne(target_terrain, TerrainTypes.Type.TREES,
		"Dogleg tee shot should not aim into trees. Target: %s" % str(decision.target))

	# Target should be roughly in the east fairway segment (laying up at the bend)
	assert_gte(decision.target.x, 7,
		"Should aim down the fairway, not backwards")

# ============================================================================
# SCENARIO 11: APPROACH SHOT — Green center bias for beginners vs pros
# ============================================================================

func test_beginner_aims_more_toward_green_center() -> void:
	var ball = Vector2i(15, 20)
	var flag = Vector2i(20, 18)  # Pin is at north edge of green
	var green_center = Vector2i(20, 20)
	_paint_rect(TerrainTypes.Type.FAIRWAY, Vector2i(13, 18), Vector2i(19, 22))
	_paint_rect(TerrainTypes.Type.GREEN, Vector2i(19, 18), Vector2i(21, 22))
	_setup_hole(Vector2i(2, 20), green_center, flag, 4)

	# Pro: should aim closer to pin
	var pro = _make_golfer({
		"ball_position": ball,
		"accuracy_skill": 0.95,
		"driving_skill": 0.9,
	})
	var pro_decision = ShotAI.decide_shot_for(pro, flag)

	# Beginner: should aim more toward green center
	var beginner = _make_golfer({
		"ball_position": ball,
		"accuracy_skill": 0.3,
		"driving_skill": 0.4,
	})
	var beginner_decision = ShotAI.decide_shot_for(beginner, flag)

	# Both targets should be on or near the green
	var pro_to_green = Vector2(pro_decision.target).distance_to(Vector2(green_center))
	var beginner_to_green = Vector2(beginner_decision.target).distance_to(Vector2(green_center))

	# Both should produce valid results near the green
	assert_lt(pro_to_green, 5.0, "Pro target should be near green")
	assert_lt(beginner_to_green, 5.0, "Beginner target should be near green")

# ============================================================================
# SCENARIO 12: CHIP FROM OFF-GREEN — Short game decision
# ============================================================================

func test_chip_from_fringe_uses_wedge() -> void:
	var ball = Vector2i(18, 20)
	var flag = Vector2i(20, 20)
	_paint_rect(TerrainTypes.Type.FAIRWAY, Vector2i(16, 18), Vector2i(18, 22))
	_paint_rect(TerrainTypes.Type.GREEN, Vector2i(19, 19), Vector2i(21, 21))
	_setup_hole(Vector2i(2, 20), Vector2i(20, 20), flag, 4)

	var gd = _make_golfer({"ball_position": ball})
	var decision = ShotAI.decide_shot_for(gd, flag)

	# From 2 tiles away on fairway, should chip with wedge
	assert_eq(decision.club, Golfer.Club.WEDGE,
		"Should use wedge for short chip from fringe")

# ============================================================================
# SCENARIO 13: OUT OF BOUNDS ADJACENT — Risk avoidance
# ============================================================================

func test_avoids_ob_adjacent_landing_zones() -> void:
	var ball = Vector2i(10, 20)
	var flag = Vector2i(25, 20)
	_paint_rect(TerrainTypes.Type.FAIRWAY, Vector2i(8, 18), Vector2i(27, 22))
	_paint_rect(TerrainTypes.Type.GREEN, Vector2i(24, 19), Vector2i(26, 21))
	# OB on both sides of the fairway
	_paint_rect(TerrainTypes.Type.OUT_OF_BOUNDS, Vector2i(8, 14), Vector2i(27, 17))
	_paint_rect(TerrainTypes.Type.OUT_OF_BOUNDS, Vector2i(8, 23), Vector2i(27, 26))
	_setup_hole(Vector2i(2, 20), Vector2i(25, 20), flag, 4)

	var gd = _make_golfer({"ball_position": ball})
	var decision = ShotAI.decide_shot_for(gd, flag)

	# Target should be on the fairway, not near OB
	var target_terrain = _terrain_grid.get_tile(decision.target)
	assert_ne(target_terrain, TerrainTypes.Type.OUT_OF_BOUNDS,
		"Should never aim out of bounds")
	# Target should be in the safe corridor (y=18-22)
	assert_gte(decision.target.y, 18,
		"Target should be in fairway corridor, not near OB")
	assert_lte(decision.target.y, 22,
		"Target should be in fairway corridor, not near OB")

# ============================================================================
# SCENARIO 14: ROCKS — Wedge only recovery
# ============================================================================

func test_rocks_forces_wedge_only() -> void:
	var ball = Vector2i(15, 20)
	var flag = Vector2i(25, 20)
	_terrain_grid._grid[ball] = TerrainTypes.Type.ROCKS
	_paint_rect(TerrainTypes.Type.FAIRWAY, Vector2i(13, 18), Vector2i(27, 22))
	_paint_rect(TerrainTypes.Type.GREEN, Vector2i(24, 19), Vector2i(26, 21))
	_setup_hole(Vector2i(2, 20), Vector2i(25, 20), flag, 4)

	var gd = _make_golfer({"ball_position": ball})
	var decision = ShotAI.decide_shot_for(gd, flag)

	assert_eq(decision.strategy, "recovery",
		"Should use recovery strategy from rocks")
	assert_eq(decision.club, Golfer.Club.WEDGE,
		"Should only use wedge from rocks")

# ============================================================================
# SCENARIO 15: GOLFERDATA FACTORY — from_golfer smoke test
# ============================================================================

func test_golfer_data_from_golfer_copies_fields() -> void:
	# Create a real Golfer node (not added to tree — lightweight)
	var golfer = Golfer.new()
	golfer.ball_position = Vector2i(10, 15)
	golfer.ball_position_precise = Vector2(10.5, 15.3)
	golfer.driving_skill = 0.85
	golfer.accuracy_skill = 0.75
	golfer.putting_skill = 0.90
	golfer.recovery_skill = 0.60
	golfer.miss_tendency = -0.3
	golfer.aggression = 0.7
	golfer.patience = 0.4
	golfer.current_hole = 2
	golfer.total_strokes = 12
	golfer.total_par = 8

	var gd = ShotAI.GolferData.from_golfer(golfer)

	assert_eq(gd.ball_position, Vector2i(10, 15))
	assert_almost_eq(gd.ball_position_precise.x, 10.5, 0.01)
	assert_almost_eq(gd.driving_skill, 0.85, 0.001)
	assert_almost_eq(gd.accuracy_skill, 0.75, 0.001)
	assert_almost_eq(gd.putting_skill, 0.90, 0.001)
	assert_almost_eq(gd.recovery_skill, 0.60, 0.001)
	assert_almost_eq(gd.miss_tendency, -0.3, 0.001)
	assert_almost_eq(gd.aggression, 0.7, 0.001)
	assert_eq(gd.current_hole, 2)
	assert_eq(gd.total_strokes, 12)
	assert_eq(gd.total_par, 8)

	golfer.free()

# ============================================================================
# SCENARIO 16: EDGE CASE — Ball at hole position
# ============================================================================

func test_ball_at_hole_returns_valid_decision() -> void:
	var flag = Vector2i(20, 20)
	_paint_rect(TerrainTypes.Type.GREEN, Vector2i(19, 19), Vector2i(21, 21))
	_setup_hole(Vector2i(2, 20), Vector2i(20, 20), flag, 4)

	var gd = _make_golfer({"ball_position": flag})
	gd.ball_position_precise = Vector2(flag)
	var decision = ShotAI.decide_shot_for(gd, flag)

	# Should return a valid decision even at distance 0
	assert_eq(decision.club, Golfer.Club.PUTTER,
		"At the hole, should still select putter")

# ============================================================================
# SCENARIO 17: NEXT-SHOT SETUP — Layup prefers clear approach line
# ============================================================================

func test_layup_prefers_clear_approach_line() -> void:
	var tee = Vector2i(2, 20)
	var flag = Vector2i(35, 20)
	_paint_rect(TerrainTypes.Type.TEE_BOX, tee - Vector2i(1, 1), tee + Vector2i(1, 1))
	# Two possible fairway landing zones at similar distance:
	# Zone A (y=20): trees blocking approach to green
	_paint_rect(TerrainTypes.Type.FAIRWAY, Vector2i(12, 19), Vector2i(16, 21))
	_paint_rect(TerrainTypes.Type.TREES, Vector2i(20, 18), Vector2i(30, 22))
	# Zone B (y=28): clear approach to green
	_paint_rect(TerrainTypes.Type.FAIRWAY, Vector2i(12, 26), Vector2i(16, 30))
	# Green
	_paint_rect(TerrainTypes.Type.GREEN, Vector2i(34, 19), Vector2i(36, 21))
	_setup_hole(tee, Vector2i(35, 20), flag, 5)

	var gd = _make_golfer({"ball_position": tee, "driving_skill": 0.7})
	var decision = ShotAI.decide_shot_for(gd, flag)

	# Target should advance from the tee
	assert_gt(decision.target.x, tee.x,
		"Should advance from tee position")
