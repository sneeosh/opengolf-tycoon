extends GutTest
## Tests for penalty drop logic - water entry point and drop position calculation
##
## Validates that water hazard penalty drops use the point of entry (where the
## ball's trajectory first crosses into water) rather than the landing position,
## and that drops are never closer to the hole than the entry point.

var _golfer: Golfer
var _terrain_grid: TerrainGrid
var _saved_terrain_grid
var _saved_course_data


func before_each() -> void:
	# Create a lightweight Golfer instance (not added to tree — only need methods)
	_golfer = Golfer.new()

	# Create a minimal terrain grid with all grass (no visual setup needed)
	_terrain_grid = TerrainGrid.new()
	_terrain_grid.grid_width = 20
	_terrain_grid.grid_height = 20
	for x in range(20):
		for y in range(20):
			_terrain_grid._grid[Vector2i(x, y)] = TerrainTypes.Type.GRASS

	# Temporarily replace GameManager references
	_saved_terrain_grid = GameManager.terrain_grid
	_saved_course_data = GameManager.course_data
	GameManager.terrain_grid = _terrain_grid


func after_each() -> void:
	GameManager.terrain_grid = _saved_terrain_grid
	GameManager.course_data = _saved_course_data
	if _golfer:
		_golfer.free()
	if _terrain_grid:
		_terrain_grid.free()


func _setup_hole_at(hole_pos: Vector2i) -> void:
	var course_data = GameManager.CourseData.new()
	var hole = GameManager.HoleData.new()
	hole.hole_position = hole_pos
	course_data.add_hole(hole)
	GameManager.course_data = course_data
	_golfer.current_hole = 0


# --- Bresenham Line Algorithm ---

func test_bresenham_horizontal_line() -> void:
	var points = _golfer._bresenham_line(Vector2i(0, 0), Vector2i(5, 0))
	assert_eq(points.size(), 6, "Horizontal line 0→5 should have 6 points")
	assert_eq(points[0], Vector2i(0, 0), "Should start at origin")
	assert_eq(points[5], Vector2i(5, 0), "Should end at (5,0)")

func test_bresenham_vertical_line() -> void:
	var points = _golfer._bresenham_line(Vector2i(0, 0), Vector2i(0, 5))
	assert_eq(points.size(), 6, "Vertical line 0→5 should have 6 points")
	assert_eq(points[0], Vector2i(0, 0))
	assert_eq(points[5], Vector2i(0, 5))

func test_bresenham_diagonal_line() -> void:
	var points = _golfer._bresenham_line(Vector2i(0, 0), Vector2i(5, 5))
	assert_eq(points[0], Vector2i(0, 0))
	assert_eq(points.back(), Vector2i(5, 5))
	assert_eq(points.size(), 6, "Pure diagonal should have 6 points")

func test_bresenham_single_point() -> void:
	var points = _golfer._bresenham_line(Vector2i(3, 3), Vector2i(3, 3))
	assert_eq(points.size(), 1, "Same start/end should yield 1 point")
	assert_eq(points[0], Vector2i(3, 3))

func test_bresenham_reverse_direction() -> void:
	var points = _golfer._bresenham_line(Vector2i(5, 0), Vector2i(0, 0))
	assert_eq(points[0], Vector2i(5, 0), "Should start at (5,0)")
	assert_eq(points.back(), Vector2i(0, 0), "Should end at origin")
	assert_eq(points.size(), 6)

func test_bresenham_steep_line() -> void:
	var points = _golfer._bresenham_line(Vector2i(0, 0), Vector2i(2, 7))
	assert_eq(points[0], Vector2i(0, 0))
	assert_eq(points.back(), Vector2i(2, 7))
	# All points should be contiguous (no gaps > 1 tile)
	for i in range(1, points.size()):
		var diff = points[i] - points[i - 1]
		assert_lte(absi(diff.x), 1, "X step should be at most 1")
		assert_lte(absi(diff.y), 1, "Y step should be at most 1")


# --- Water Entry Point Detection ---

func test_entry_point_finds_first_water_tile() -> void:
	# Grass from x=0-4, water from x=5-9 along y=5
	for x in range(5, 10):
		_terrain_grid._grid[Vector2i(x, 5)] = TerrainTypes.Type.WATER

	var entry = _golfer._find_water_entry_point(Vector2i(0, 5), Vector2i(8, 5))
	assert_eq(entry, Vector2i(5, 5), "Should find first water tile at x=5")

func test_entry_point_at_water_edge_not_landing() -> void:
	# Large water body from x=5 to x=15, ball lands at x=12
	for x in range(5, 16):
		_terrain_grid._grid[Vector2i(x, 5)] = TerrainTypes.Type.WATER

	var entry = _golfer._find_water_entry_point(Vector2i(2, 5), Vector2i(12, 5))
	assert_eq(entry, Vector2i(5, 5), "Entry should be water edge (5,5), not landing (12,5)")

func test_entry_point_diagonal_trajectory() -> void:
	# Water block from (4,4) through (6,6)
	for x in range(4, 7):
		for y in range(4, 7):
			_terrain_grid._grid[Vector2i(x, y)] = TerrainTypes.Type.WATER

	var entry = _golfer._find_water_entry_point(Vector2i(0, 0), Vector2i(6, 6))
	assert_eq(entry, Vector2i(4, 4), "Diagonal trajectory should enter water at (4,4)")

func test_entry_point_fallback_when_no_water_on_path() -> void:
	# All grass — edge case where trajectory doesn't cross water
	var entry = _golfer._find_water_entry_point(Vector2i(0, 0), Vector2i(5, 5))
	assert_eq(entry, Vector2i(5, 5), "Should fallback to landing position")

func test_entry_point_water_immediately_adjacent() -> void:
	_terrain_grid._grid[Vector2i(1, 0)] = TerrainTypes.Type.WATER
	_terrain_grid._grid[Vector2i(2, 0)] = TerrainTypes.Type.WATER

	var entry = _golfer._find_water_entry_point(Vector2i(0, 0), Vector2i(2, 0))
	assert_eq(entry, Vector2i(1, 0), "Should find water at immediately adjacent tile")

func test_entry_point_with_island_in_water() -> void:
	# Water from x=3-8, but grass island at x=5 — ball should enter at first water
	for x in range(3, 9):
		_terrain_grid._grid[Vector2i(x, 5)] = TerrainTypes.Type.WATER
	_terrain_grid._grid[Vector2i(5, 5)] = TerrainTypes.Type.GRASS  # Island

	var entry = _golfer._find_water_entry_point(Vector2i(0, 5), Vector2i(8, 5))
	assert_eq(entry, Vector2i(3, 5), "Should find first water tile, ignoring island")


# --- Drop Position Rules ---

func test_drop_not_in_water() -> void:
	_terrain_grid._grid[Vector2i(5, 5)] = TerrainTypes.Type.WATER
	_setup_hole_at(Vector2i(19, 5))

	var drop = _golfer._find_water_drop_position(Vector2i(5, 5))
	var drop_terrain = _terrain_grid.get_tile(drop)
	assert_ne(drop_terrain, TerrainTypes.Type.WATER, "Drop position must not be in water")

func test_drop_not_out_of_bounds() -> void:
	_terrain_grid._grid[Vector2i(5, 5)] = TerrainTypes.Type.WATER
	_terrain_grid._grid[Vector2i(4, 5)] = TerrainTypes.Type.OUT_OF_BOUNDS
	_setup_hole_at(Vector2i(19, 19))

	var drop = _golfer._find_water_drop_position(Vector2i(5, 5))
	var drop_terrain = _terrain_grid.get_tile(drop)
	assert_ne(drop_terrain, TerrainTypes.Type.OUT_OF_BOUNDS, "Drop position must not be OB")

func test_drop_no_closer_to_hole_than_entry() -> void:
	# Water strip x=5-10, hole at x=19
	for x in range(5, 11):
		_terrain_grid._grid[Vector2i(x, 5)] = TerrainTypes.Type.WATER
	_setup_hole_at(Vector2i(19, 5))

	var entry = Vector2i(5, 5)
	var drop = _golfer._find_water_drop_position(entry)
	var entry_dist = Vector2(entry).distance_to(Vector2(19, 5))
	var drop_dist = Vector2(drop).distance_to(Vector2(19, 5))
	assert_gte(drop_dist, entry_dist,
		"Drop must not be closer to hole than the entry point")

func test_drop_prefers_fairway_over_rough() -> void:
	_terrain_grid._grid[Vector2i(5, 5)] = TerrainTypes.Type.WATER
	# Fairway and rough at equal distance from entry, both farther from hole
	_terrain_grid._grid[Vector2i(4, 5)] = TerrainTypes.Type.FAIRWAY
	_terrain_grid._grid[Vector2i(5, 4)] = TerrainTypes.Type.ROUGH
	_setup_hole_at(Vector2i(19, 19))

	var drop = _golfer._find_water_drop_position(Vector2i(5, 5))
	assert_eq(drop, Vector2i(4, 5), "Should prefer fairway (score 100) over rough (score 50)")

func test_drop_near_entry_not_far_away() -> void:
	# Single water tile at (5,5), grass everywhere else
	_terrain_grid._grid[Vector2i(5, 5)] = TerrainTypes.Type.WATER
	_setup_hole_at(Vector2i(19, 5))

	var drop = _golfer._find_water_drop_position(Vector2i(5, 5))
	var dist = Vector2(drop).distance_to(Vector2(5, 5))
	assert_lte(dist, 5.0, "Drop should be within search radius of entry point")


# --- Integration: Full Penalty Flow ---

func test_full_flow_drop_at_entry_not_landing() -> void:
	# KEY BUG FIX TEST: Ball shot from (2,5), enters water at (5,5), lands at (10,5)
	# Hole is at (15,5). Drop must be near entry (5,5), not landing (10,5).
	for x in range(5, 12):
		_terrain_grid._grid[Vector2i(x, 5)] = TerrainTypes.Type.WATER
	_setup_hole_at(Vector2i(15, 5))

	# Step 1: Find entry point
	var entry = _golfer._find_water_entry_point(Vector2i(2, 5), Vector2i(10, 5))
	assert_eq(entry, Vector2i(5, 5), "Entry should be at water edge")

	# Step 2: Find drop position from entry
	var drop = _golfer._find_water_drop_position(entry)

	# Drop must not be in water
	assert_ne(_terrain_grid.get_tile(drop), TerrainTypes.Type.WATER)

	# Drop must not be closer to hole than entry
	var entry_dist = Vector2(entry).distance_to(Vector2(15, 5))
	var drop_dist = Vector2(drop).distance_to(Vector2(15, 5))
	assert_gte(drop_dist, entry_dist,
		"Drop must not be closer to hole than entry point")

	# Drop should be near entry (5,5), not near landing (10,5)
	var drop_to_entry = Vector2(drop).distance_to(Vector2(entry))
	var drop_to_landing = Vector2(drop).distance_to(Vector2(10, 5))
	assert_lt(drop_to_entry, drop_to_landing,
		"Drop should be closer to entry point than to landing position")

func test_full_flow_large_water_hazard() -> void:
	# Large lake spanning x=4-16, y=3-7. Ball shot from (0,5) lands at (14,5).
	# Entry at (4,5). Hole at (19,5).
	for x in range(4, 17):
		for y in range(3, 8):
			_terrain_grid._grid[Vector2i(x, y)] = TerrainTypes.Type.WATER
	_setup_hole_at(Vector2i(19, 5))

	var entry = _golfer._find_water_entry_point(Vector2i(0, 5), Vector2i(14, 5))
	assert_eq(entry, Vector2i(4, 5), "Entry should be near-side water edge")

	var drop = _golfer._find_water_drop_position(entry)

	# The drop should be on the near side of the lake (x <= 4), not the far side (x >= 17)
	assert_lte(drop.x, 5, "Drop should be on the near side of the lake, not the far side")

	# No closer to hole
	var entry_dist = Vector2(entry).distance_to(Vector2(19, 5))
	var drop_dist = Vector2(drop).distance_to(Vector2(19, 5))
	assert_gte(drop_dist, entry_dist)

func test_full_flow_shot_from_side_of_water() -> void:
	# Ball approaches water at an angle: from (0,0) to (8,8), water at y>=6
	for x in range(0, 20):
		for y in range(6, 10):
			_terrain_grid._grid[Vector2i(x, y)] = TerrainTypes.Type.WATER
	_setup_hole_at(Vector2i(19, 10))

	var entry = _golfer._find_water_entry_point(Vector2i(0, 0), Vector2i(8, 8))
	# Diagonal line hits y=6 around x=6
	assert_eq(entry.y, 6, "Entry should be at y=6 (first water row)")

	var drop = _golfer._find_water_drop_position(entry)
	assert_ne(_terrain_grid.get_tile(drop), TerrainTypes.Type.WATER)

	var entry_dist = Vector2(entry).distance_to(Vector2(19, 10))
	var drop_dist = Vector2(drop).distance_to(Vector2(19, 10))
	assert_gte(drop_dist, entry_dist,
		"Drop must not be closer to hole than entry point")
