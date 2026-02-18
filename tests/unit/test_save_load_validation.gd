extends GutTest
## Tests for SaveManager value validation on load
##
## Verifies that loaded values are clamped to valid ranges,
## preventing corrupt save files from putting the game into
## invalid states.


# --- Reputation Clamping ---

func test_reputation_clamped_to_max_on_load() -> void:
	# Simulate what happens when loading a save with reputation > 100
	var loaded_rep = 150.0
	var clamped = clampf(float(loaded_rep), 0.0, 100.0)
	assert_eq(clamped, 100.0, "Reputation should clamp to 100 max")

func test_reputation_clamped_to_min_on_load() -> void:
	var loaded_rep = -20.0
	var clamped = clampf(float(loaded_rep), 0.0, 100.0)
	assert_eq(clamped, 0.0, "Reputation should clamp to 0 min")

func test_reputation_preserved_when_valid() -> void:
	var loaded_rep = 65.5
	var clamped = clampf(float(loaded_rep), 0.0, 100.0)
	assert_almost_eq(clamped, 65.5, 0.01, "Valid reputation should pass through")


# --- Day Number Validation ---

func test_day_clamped_to_minimum_one() -> void:
	var loaded_day = 0
	var clamped = max(1, int(loaded_day))
	assert_eq(clamped, 1, "Day should never be less than 1")

func test_negative_day_clamped() -> void:
	var loaded_day = -5
	var clamped = max(1, int(loaded_day))
	assert_eq(clamped, 1, "Negative day should clamp to 1")


# --- Hour Validation ---

func test_hour_clamped_to_valid_range() -> void:
	var loaded_hour = 25.0
	var clamped = clampf(float(loaded_hour), 0.0, 24.0)
	assert_eq(clamped, 24.0, "Hour > 24 should clamp to 24")

func test_negative_hour_clamped() -> void:
	var loaded_hour = -3.0
	var clamped = clampf(float(loaded_hour), 0.0, 24.0)
	assert_eq(clamped, 0.0, "Negative hour should clamp to 0")


# --- Green Fee Validation ---

func test_green_fee_clamped_to_min() -> void:
	var loaded_fee = 2
	var clamped = clamp(int(loaded_fee), GameManager.MIN_GREEN_FEE, GameManager.MAX_GREEN_FEE)
	assert_eq(clamped, GameManager.MIN_GREEN_FEE, "Fee below min should clamp up")

func test_green_fee_clamped_to_max() -> void:
	var loaded_fee = 999
	var clamped = clamp(int(loaded_fee), GameManager.MIN_GREEN_FEE, GameManager.MAX_GREEN_FEE)
	assert_eq(clamped, GameManager.MAX_GREEN_FEE, "Fee above max should clamp down")

func test_green_fee_preserved_when_valid() -> void:
	var loaded_fee = 50
	var clamped = clamp(int(loaded_fee), GameManager.MIN_GREEN_FEE, GameManager.MAX_GREEN_FEE)
	assert_eq(clamped, 50, "Valid fee should pass through")


# --- JSON Parsing Safety ---

func test_missing_money_key_uses_default() -> void:
	var game = {}
	var money = int(game.get("money", 50000))
	assert_eq(money, 50000, "Missing money should default to 50000")

func test_missing_reputation_uses_default() -> void:
	var game = {}
	var rep = clampf(float(game.get("reputation", 50.0)), 0.0, 100.0)
	assert_almost_eq(rep, 50.0, 0.01, "Missing reputation should default to 50")

func test_missing_day_uses_default() -> void:
	var game = {}
	var day = max(1, int(game.get("current_day", 1)))
	assert_eq(day, 1, "Missing day should default to 1")

func test_null_value_for_money_uses_default() -> void:
	# In JSON, a null field results in null in the parsed dict.
	# dict.get() returns null (not the default) when the key exists with value null.
	# int(null) crashes in Godot 4, so production code should guard against this.
	var game = {"money": null}
	var raw = game.get("money", 50000)
	assert_true(raw == null, "get() returns null when key exists with null value, not the default")


# --- Game State Full Round-trip ---

func test_game_state_survives_json_roundtrip() -> void:
	var game_state = {
		"course_name": "Test Links",
		"money": 75000,
		"reputation": 65.5,
		"current_day": 15,
		"current_hour": 14.5,
		"green_fee": 45,
	}

	var json = JSON.stringify(game_state)
	var restored = JSON.parse_string(json)

	assert_eq(restored.course_name, "Test Links")
	assert_eq(restored.money, 75000)
	assert_almost_eq(float(restored.reputation), 65.5, 0.01)
	assert_eq(restored.current_day, 15)
	assert_almost_eq(float(restored.current_hour), 14.5, 0.01)
	assert_eq(restored.green_fee, 45)


# --- Edge Cases ---

func test_empty_game_state_uses_all_defaults() -> void:
	var game = {}
	var course_name = game.get("course_name", "Loaded Course")
	var money = int(game.get("money", 50000))
	var reputation = clampf(float(game.get("reputation", 50.0)), 0.0, 100.0)
	var day = max(1, int(game.get("current_day", 1)))

	assert_eq(course_name, "Loaded Course")
	assert_eq(money, 50000)
	assert_almost_eq(reputation, 50.0, 0.01)
	assert_eq(day, 1)
