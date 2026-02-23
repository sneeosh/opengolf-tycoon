extends RefCounted
class_name ScenarioSystem
## ScenarioSystem - Hand-crafted scenario challenges with objectives and star ratings

signal scenario_started(scenario_id: String)
signal objective_completed(scenario_id: String, objective_index: int)
signal scenario_won(scenario_id: String, stars: int)
signal scenario_failed(scenario_id: String, reason: String)
signal progress_updated()

enum ObjectiveType {
	HOLES_CREATED,
	GOLFERS_SERVED,
	REPUTATION_REACHED,
	TOTAL_PROFIT,
	RATING_STARS,
	TOURNAMENT_HOSTED,
	MONEY_REACHED,
	DAYS_SURVIVED,
}

var current_scenario_id: String = ""
var is_scenario_active: bool = false
var scenario_day_start: int = 0

# Persistent progress across saves
var completed_scenarios: Dictionary = {}  # scenario_id -> stars earned (1-3)

# Runtime tracking for active scenario
var _objective_progress: Array = []  # Array of current progress values per objective
var _objectives_met: Array = []  # Array of bool per objective

const SCENARIOS: Array = [
	{
		"id": "first_tee",
		"name": "First Tee",
		"description": "Welcome to golf course management! Build a small course and attract your first golfers.",
		"theme": -1,  # Player's choice
		"difficulty": -1,  # Player's choice
		"starting_money": 30000,
		"time_limit_days": 0,  # No time limit
		"unlock_requires": "",
		"objectives": [
			{"type": ObjectiveType.HOLES_CREATED, "target": 3, "label": "Build 3 holes"},
			{"type": ObjectiveType.GOLFERS_SERVED, "target": 10, "label": "Serve 10 golfers"},
		],
		"star_2": {"total_profit": 2000},
		"star_3": {"total_profit": 5000, "reputation": 60},
	},
	{
		"id": "budget_build",
		"name": "Budget Build",
		"description": "Build a 3-star course with a shoestring budget. Every dollar counts.",
		"theme": -1,
		"difficulty": -1,
		"starting_money": 20000,
		"time_limit_days": 56,  # 2 game years
		"unlock_requires": "first_tee",
		"objectives": [
			{"type": ObjectiveType.RATING_STARS, "target": 3, "label": "Reach 3-star rating"},
			{"type": ObjectiveType.HOLES_CREATED, "target": 6, "label": "Build 6 holes"},
		],
		"star_2": {"total_profit": 5000},
		"star_3": {"total_profit": 15000, "reputation": 70},
	},
	{
		"id": "the_nine",
		"name": "The Nine",
		"description": "Build a complete 9-hole course and run it profitably.",
		"theme": -1,
		"difficulty": -1,
		"starting_money": 40000,
		"time_limit_days": 84,  # 3 game years
		"unlock_requires": "first_tee",
		"objectives": [
			{"type": ObjectiveType.HOLES_CREATED, "target": 9, "label": "Build 9 holes"},
			{"type": ObjectiveType.TOTAL_PROFIT, "target": 10000, "label": "Earn $10,000 total profit"},
			{"type": ObjectiveType.GOLFERS_SERVED, "target": 50, "label": "Serve 50 golfers"},
		],
		"star_2": {"reputation": 65},
		"star_3": {"total_profit": 30000, "rating_stars": 4},
	},
	{
		"id": "weather_storm",
		"name": "Weather the Storm",
		"description": "Survive a full year on a windswept links course. The weather won't be kind.",
		"theme": 2,  # LINKS
		"difficulty": -1,
		"starting_money": 35000,
		"time_limit_days": 28,  # 1 game year
		"unlock_requires": "budget_build",
		"objectives": [
			{"type": ObjectiveType.DAYS_SURVIVED, "target": 28, "label": "Survive 28 days"},
			{"type": ObjectiveType.GOLFERS_SERVED, "target": 30, "label": "Serve 30 golfers"},
			{"type": ObjectiveType.MONEY_REACHED, "target": 25000, "label": "End with $25,000+"},
		],
		"star_2": {"reputation": 60},
		"star_3": {"total_profit": 20000, "reputation": 75},
	},
	{
		"id": "desert_oasis",
		"name": "Desert Oasis",
		"description": "Create a profitable oasis in the desert. High maintenance costs demand smart design.",
		"theme": 1,  # DESERT
		"difficulty": -1,
		"starting_money": 35000,
		"time_limit_days": 56,
		"unlock_requires": "the_nine",
		"objectives": [
			{"type": ObjectiveType.HOLES_CREATED, "target": 9, "label": "Build 9 holes"},
			{"type": ObjectiveType.TOTAL_PROFIT, "target": 15000, "label": "Earn $15,000 profit"},
			{"type": ObjectiveType.RATING_STARS, "target": 3, "label": "Reach 3-star rating"},
		],
		"star_2": {"reputation": 70},
		"star_3": {"total_profit": 40000, "rating_stars": 4},
	},
	{
		"id": "mountain_majesty",
		"name": "Mountain Majesty",
		"description": "Build a challenging mountain course worthy of hosting a Regional tournament.",
		"theme": 3,  # MOUNTAIN
		"difficulty": -1,
		"starting_money": 45000,
		"time_limit_days": 84,
		"unlock_requires": "the_nine",
		"objectives": [
			{"type": ObjectiveType.HOLES_CREATED, "target": 9, "label": "Build 9 holes"},
			{"type": ObjectiveType.TOURNAMENT_HOSTED, "target": 2, "label": "Host Regional tournament"},
			{"type": ObjectiveType.REPUTATION_REACHED, "target": 65, "label": "Reach 65 reputation"},
		],
		"star_2": {"total_profit": 20000},
		"star_3": {"total_profit": 50000, "rating_stars": 4},
	},
	{
		"id": "city_slicker",
		"name": "City Slicker",
		"description": "Build a popular urban course. Limited space, but high foot traffic.",
		"theme": 4,  # CITY
		"difficulty": -1,
		"starting_money": 40000,
		"time_limit_days": 56,
		"unlock_requires": "budget_build",
		"objectives": [
			{"type": ObjectiveType.REPUTATION_REACHED, "target": 75, "label": "Reach 75 reputation"},
			{"type": ObjectiveType.GOLFERS_SERVED, "target": 80, "label": "Serve 80 golfers"},
		],
		"star_2": {"total_profit": 25000},
		"star_3": {"total_profit": 50000, "rating_stars": 4},
	},
	{
		"id": "the_turnaround",
		"name": "The Turnaround",
		"description": "You've inherited a struggling course with debt. Turn it around before going bankrupt.",
		"theme": -1,
		"difficulty": -1,
		"starting_money": -5000,  # Start in debt
		"time_limit_days": 56,
		"unlock_requires": "desert_oasis",
		"objectives": [
			{"type": ObjectiveType.MONEY_REACHED, "target": 20000, "label": "Reach $20,000 balance"},
			{"type": ObjectiveType.RATING_STARS, "target": 3, "label": "Reach 3-star rating"},
			{"type": ObjectiveType.GOLFERS_SERVED, "target": 60, "label": "Serve 60 golfers"},
		],
		"star_2": {"reputation": 70},
		"star_3": {"total_profit": 40000, "reputation": 80},
	},
	{
		"id": "championship_dream",
		"name": "Championship Dream",
		"description": "Build a world-class course and host all four tournament tiers.",
		"theme": -1,
		"difficulty": -1,
		"starting_money": 50000,
		"time_limit_days": 168,  # 6 game years
		"unlock_requires": "mountain_majesty",
		"objectives": [
			{"type": ObjectiveType.HOLES_CREATED, "target": 18, "label": "Build 18 holes"},
			{"type": ObjectiveType.TOURNAMENT_HOSTED, "target": 4, "label": "Host Championship tournament"},
			{"type": ObjectiveType.REPUTATION_REACHED, "target": 85, "label": "Reach 85 reputation"},
		],
		"star_2": {"total_profit": 80000},
		"star_3": {"total_profit": 150000, "rating_stars": 5},
	},
	{
		"id": "resort_paradise",
		"name": "Resort Paradise",
		"description": "Create the ultimate luxury resort course. Spare no expense.",
		"theme": 5,  # RESORT
		"difficulty": -1,
		"starting_money": 60000,
		"time_limit_days": 112,  # 4 game years
		"unlock_requires": "championship_dream",
		"objectives": [
			{"type": ObjectiveType.HOLES_CREATED, "target": 18, "label": "Build 18 holes"},
			{"type": ObjectiveType.RATING_STARS, "target": 5, "label": "Reach 5-star rating"},
			{"type": ObjectiveType.REPUTATION_REACHED, "target": 90, "label": "Reach 90 reputation"},
			{"type": ObjectiveType.TOTAL_PROFIT, "target": 100000, "label": "Earn $100,000 profit"},
		],
		"star_2": {"total_profit": 200000},
		"star_3": {"total_profit": 500000},
	},
]

func get_scenario(scenario_id: String) -> Dictionary:
	for s in SCENARIOS:
		if s["id"] == scenario_id:
			return s
	return {}

func is_scenario_unlocked(scenario_id: String) -> bool:
	var scenario = get_scenario(scenario_id)
	if scenario.is_empty():
		return false
	var requires = scenario.get("unlock_requires", "")
	if requires.is_empty():
		return true
	return completed_scenarios.has(requires)

func get_scenario_stars(scenario_id: String) -> int:
	return completed_scenarios.get(scenario_id, 0)

func start_scenario(scenario_id: String) -> bool:
	var scenario = get_scenario(scenario_id)
	if scenario.is_empty():
		return false
	if not is_scenario_unlocked(scenario_id):
		return false

	current_scenario_id = scenario_id
	is_scenario_active = true
	scenario_day_start = GameManager.current_day

	# Initialize progress tracking
	var objectives = scenario.get("objectives", [])
	_objective_progress.clear()
	_objectives_met.clear()
	for i in range(objectives.size()):
		_objective_progress.append(0)
		_objectives_met.append(false)

	scenario_started.emit(scenario_id)
	return true

func apply_scenario_settings(scenario: Dictionary) -> void:
	"""Apply scenario-specific settings to GameManager. Called by main.gd after new_game."""
	var starting_money = scenario.get("starting_money", 50000)
	# Adjust from default starting money
	var diff = starting_money - GameManager.money
	if diff != 0:
		GameManager.modify_money(diff)

func get_current_scenario() -> Dictionary:
	if not is_scenario_active:
		return {}
	return get_scenario(current_scenario_id)

func get_objectives_display() -> Array:
	"""Get array of {label, progress, target, met} for UI display."""
	var scenario = get_current_scenario()
	if scenario.is_empty():
		return []

	var objectives = scenario.get("objectives", [])
	var result: Array = []
	for i in range(objectives.size()):
		var obj = objectives[i]
		result.append({
			"label": obj.get("label", ""),
			"progress": _objective_progress[i] if i < _objective_progress.size() else 0,
			"target": obj.get("target", 0),
			"met": _objectives_met[i] if i < _objectives_met.size() else false,
		})
	return result

func get_time_remaining() -> int:
	"""Get remaining days, or -1 if no time limit."""
	var scenario = get_current_scenario()
	var limit = scenario.get("time_limit_days", 0)
	if limit <= 0:
		return -1
	var elapsed = GameManager.current_day - scenario_day_start
	return max(0, limit - elapsed)

func check_progress() -> void:
	"""Update objective progress and check for win/loss conditions."""
	if not is_scenario_active:
		return

	var scenario = get_current_scenario()
	if scenario.is_empty():
		return

	var objectives = scenario.get("objectives", [])
	var all_met = true

	for i in range(objectives.size()):
		if i >= _objective_progress.size():
			break
		var obj = objectives[i]
		var old_met = _objectives_met[i]
		_objective_progress[i] = _get_objective_value(obj)
		_objectives_met[i] = _objective_progress[i] >= obj.get("target", 0)

		if _objectives_met[i] and not old_met:
			objective_completed.emit(current_scenario_id, i)
			EventBus.notify("Objective complete: %s" % obj.get("label", ""), "success")

		if not _objectives_met[i]:
			all_met = false

	progress_updated.emit()

	# Check win condition
	if all_met:
		var stars = _calculate_stars(scenario)
		_complete_scenario(stars)
		return

	# Check time limit loss
	var time_limit = scenario.get("time_limit_days", 0)
	if time_limit > 0:
		var elapsed = GameManager.current_day - scenario_day_start
		if elapsed >= time_limit:
			if not all_met:
				scenario_failed.emit(current_scenario_id, "Time limit reached")
				EventBus.notify("Scenario failed: Time limit reached!", "error")

func _get_objective_value(objective: Dictionary) -> int:
	var obj_type = objective.get("type", -1)
	match obj_type:
		ObjectiveType.HOLES_CREATED:
			return GameManager.get_open_hole_count()
		ObjectiveType.GOLFERS_SERVED:
			return _get_total_golfers_served()
		ObjectiveType.REPUTATION_REACHED:
			return int(GameManager.reputation)
		ObjectiveType.TOTAL_PROFIT:
			return _get_cumulative_profit()
		ObjectiveType.RATING_STARS:
			return GameManager.course_rating.get("stars", 0)
		ObjectiveType.TOURNAMENT_HOSTED:
			return _get_tournaments_hosted()
		ObjectiveType.MONEY_REACHED:
			return GameManager.money
		ObjectiveType.DAYS_SURVIVED:
			return GameManager.current_day - scenario_day_start
	return 0

func _get_total_golfers_served() -> int:
	var total = GameManager.daily_stats.golfers_served
	for entry in GameManager.daily_history:
		total += entry.get("golfers_served", 0)
	return total

func _get_cumulative_profit() -> int:
	var total = GameManager.daily_stats.get_profit()
	for entry in GameManager.daily_history:
		total += entry.get("profit", 0)
	return total

func _get_tournaments_hosted() -> int:
	"""Return the highest tournament tier hosted (1-based for objective matching).
	Uses awards_system yearly stats which track highest_tournament_tier (0-3)."""
	if GameManager.awards_system:
		var highest = GameManager.awards_system.yearly_stats.get("highest_tournament_tier", -1)
		return highest + 1  # Convert from 0-based tier to 1-based count
	return 0

func _calculate_stars(scenario: Dictionary) -> int:
	var stars = 1  # Completing objectives = 1 star

	# Check 2-star conditions
	var star_2 = scenario.get("star_2", {})
	if _meets_star_conditions(star_2):
		stars = 2

	# Check 3-star conditions
	var star_3 = scenario.get("star_3", {})
	if _meets_star_conditions(star_3):
		stars = 3

	return stars

func _meets_star_conditions(conditions: Dictionary) -> bool:
	for key in conditions.keys():
		var target = conditions[key]
		match key:
			"total_profit":
				if _get_cumulative_profit() < target:
					return false
			"reputation":
				if GameManager.reputation < target:
					return false
			"rating_stars":
				if GameManager.course_rating.get("stars", 0) < target:
					return false
			"money":
				if GameManager.money < target:
					return false
	return true

func _complete_scenario(stars: int) -> void:
	var prev_stars = completed_scenarios.get(current_scenario_id, 0)
	if stars > prev_stars:
		completed_scenarios[current_scenario_id] = stars

	is_scenario_active = false
	scenario_won.emit(current_scenario_id, stars)

	var star_str = ""
	for i in range(stars):
		star_str += "*"

	EventBus.notify("Scenario complete! %s (%s)" % [get_current_scenario().get("name", ""), star_str], "success")

func abandon_scenario() -> void:
	is_scenario_active = false
	current_scenario_id = ""
	_objective_progress.clear()
	_objectives_met.clear()

func serialize() -> Dictionary:
	var data: Dictionary = {
		"completed_scenarios": completed_scenarios,
	}
	if is_scenario_active:
		data["active_scenario"] = current_scenario_id
		data["scenario_day_start"] = scenario_day_start
	return data

func deserialize(data: Dictionary) -> void:
	completed_scenarios = data.get("completed_scenarios", {})
	var active = data.get("active_scenario", "")
	if not active.is_empty():
		current_scenario_id = active
		scenario_day_start = int(data.get("scenario_day_start", 1))
		is_scenario_active = true
		# Re-initialize progress tracking
		var scenario = get_current_scenario()
		var objectives = scenario.get("objectives", [])
		_objective_progress.clear()
		_objectives_met.clear()
		for i in range(objectives.size()):
			_objective_progress.append(0)
			_objectives_met.append(false)
		# Immediately check current progress
		check_progress()
