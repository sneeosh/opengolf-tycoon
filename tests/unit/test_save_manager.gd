extends GutTest
## Tests for SaveManager - Save/load data serialization
##
## Note: These tests focus on data serialization logic (hole serialize/deserialize)
## since full save/load requires filesystem access and scene tree references.
## The SaveManager's _serialize_holes and _deserialize_holes methods are tested
## through GameManager's CourseData.


# --- Hole Serialization Round-trip ---

func test_hole_serialization_roundtrip() -> void:
	# Create holes
	var course = GameManager.CourseData.new()

	var hole1 = GameManager.HoleData.new()
	hole1.hole_number = 1
	hole1.par = 3
	hole1.tee_position = Vector2i(10, 20)
	hole1.green_position = Vector2i(30, 40)
	hole1.hole_position = Vector2i(31, 41)
	hole1.distance_yards = 150
	hole1.is_open = true
	hole1.difficulty_rating = 3.5
	course.add_hole(hole1)

	var hole2 = GameManager.HoleData.new()
	hole2.hole_number = 2
	hole2.par = 5
	hole2.tee_position = Vector2i(50, 60)
	hole2.green_position = Vector2i(100, 120)
	hole2.hole_position = Vector2i(101, 121)
	hole2.distance_yards = 520
	hole2.is_open = false
	hole2.difficulty_rating = 7.0
	course.add_hole(hole2)

	# Serialize (using the same logic SaveManager uses)
	var serialized = _serialize_holes(course.holes)
	assert_eq(serialized.size(), 2, "Should serialize 2 holes")

	# Check serialized format
	assert_eq(serialized[0].hole_number, 1)
	assert_eq(serialized[0].par, 3)
	assert_eq(serialized[0].tee_position.x, 10)
	assert_eq(serialized[0].tee_position.y, 20)
	assert_eq(serialized[0].is_open, true)
	assert_eq(serialized[0].difficulty_rating, 3.5)

	assert_eq(serialized[1].hole_number, 2)
	assert_eq(serialized[1].par, 5)
	assert_eq(serialized[1].is_open, false)
	assert_eq(serialized[1].difficulty_rating, 7.0)

	# Deserialize
	var loaded_course = GameManager.CourseData.new()
	_deserialize_holes(serialized, loaded_course)

	assert_eq(loaded_course.holes.size(), 2)
	assert_eq(loaded_course.holes[0].hole_number, 1)
	assert_eq(loaded_course.holes[0].par, 3)
	assert_eq(loaded_course.holes[0].tee_position, Vector2i(10, 20))
	assert_eq(loaded_course.holes[0].green_position, Vector2i(30, 40))
	assert_eq(loaded_course.holes[0].hole_position, Vector2i(31, 41))
	assert_eq(loaded_course.holes[0].distance_yards, 150)
	assert_eq(loaded_course.holes[0].is_open, true)
	assert_eq(loaded_course.holes[0].difficulty_rating, 3.5)

	assert_eq(loaded_course.holes[1].hole_number, 2)
	assert_eq(loaded_course.holes[1].par, 5)
	assert_eq(loaded_course.holes[1].is_open, false)

func test_hole_serialization_defaults() -> void:
	# Deserialize with missing fields - should use defaults
	var data = [{"hole_number": 1}]  # Minimal data
	var course = GameManager.CourseData.new()
	_deserialize_holes(data, course)

	assert_eq(course.holes.size(), 1)
	assert_eq(course.holes[0].hole_number, 1)
	assert_eq(course.holes[0].par, 4, "Default par should be 4")
	assert_eq(course.holes[0].is_open, true, "Default should be open")
	assert_eq(course.holes[0].difficulty_rating, 1.0, "Default difficulty should be 1.0")

func test_hole_serialization_empty() -> void:
	var course = GameManager.CourseData.new()
	_deserialize_holes([], course)
	assert_eq(course.holes.size(), 0)


# --- JSON Round-trip Test ---

func test_game_state_json_roundtrip() -> void:
	# Simulate the data structure that SaveManager creates
	var game_state = {
		"course_name": "Test Links",
		"money": 75000,
		"reputation": 65.5,
		"current_day": 15,
		"current_hour": 14.5,
		"green_fee": 45,
	}

	var save_data = {
		"version": 2,
		"timestamp": "2025-01-01T12:00:00",
		"game_state": game_state,
	}

	# Convert to JSON and back (simulating file write/read)
	var json_string = JSON.stringify(save_data)
	var parsed = JSON.parse_string(json_string)

	assert_not_null(parsed, "JSON should parse successfully")
	assert_eq(parsed.version, 2)
	assert_eq(parsed.game_state.course_name, "Test Links")
	assert_eq(parsed.game_state.money, 75000)
	assert_almost_eq(float(parsed.game_state.reputation), 65.5, 0.01)
	assert_eq(parsed.game_state.green_fee, 45)

func test_records_json_roundtrip() -> void:
	# Test that CourseRecords survive JSON serialization
	var records = CourseRecords.create_empty_records()
	records.total_hole_in_ones = 2
	records.lowest_round = CourseRecords.RecordEntry.new("Tiger", 65, 10, -1)
	records.best_per_hole[3] = CourseRecords.RecordEntry.new("Phil", 2, 5, 3)

	var serialized = CourseRecords.serialize_records(records)
	var json_string = JSON.stringify(serialized)
	var parsed = JSON.parse_string(json_string)
	var restored = CourseRecords.deserialize_records(parsed)

	assert_eq(restored.total_hole_in_ones, 2)
	assert_eq(restored.lowest_round.golfer_name, "Tiger")
	assert_eq(restored.lowest_round.value, 65)
	assert_eq(restored.best_per_hole[3].golfer_name, "Phil")


# --- Helper functions (mirror SaveManager's serialization logic) ---

func _serialize_holes(holes: Array) -> Array:
	var result: Array = []
	for hole in holes:
		result.append({
			"hole_number": hole.hole_number,
			"par": hole.par,
			"tee_position": {"x": hole.tee_position.x, "y": hole.tee_position.y},
			"green_position": {"x": hole.green_position.x, "y": hole.green_position.y},
			"hole_position": {"x": hole.hole_position.x, "y": hole.hole_position.y},
			"distance_yards": hole.distance_yards,
			"is_open": hole.is_open,
			"difficulty_rating": hole.difficulty_rating,
		})
	return result

func _deserialize_holes(holes_data: Array, course: GameManager.CourseData) -> void:
	course.holes.clear()
	for h in holes_data:
		var hole = GameManager.HoleData.new()
		hole.hole_number = int(h.get("hole_number", 1))
		hole.par = int(h.get("par", 4))
		var tee = h.get("tee_position", {"x": 0, "y": 0})
		hole.tee_position = Vector2i(int(tee.get("x", 0)), int(tee.get("y", 0)))
		var green = h.get("green_position", {"x": 0, "y": 0})
		hole.green_position = Vector2i(int(green.get("x", 0)), int(green.get("y", 0)))
		var hp = h.get("hole_position", {"x": 0, "y": 0})
		hole.hole_position = Vector2i(int(hp.get("x", 0)), int(hp.get("y", 0)))
		hole.distance_yards = int(h.get("distance_yards", 0))
		hole.is_open = h.get("is_open", true)
		hole.difficulty_rating = float(h.get("difficulty_rating", 1.0))
		course.holes.append(hole)
	course._recalculate_par()
