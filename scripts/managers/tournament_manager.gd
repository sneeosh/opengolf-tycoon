extends Node
class_name TournamentManager
## TournamentManager - Handles tournament scheduling, execution, and rewards

signal tournament_scheduled(tier: int, start_day: int)
signal tournament_started(tier: int)
signal tournament_completed(tier: int, results: Dictionary)

var current_tournament_tier: int = -1  # -1 = no tournament
var current_tournament_state: int = TournamentSystem.TournamentState.NONE
var tournament_start_day: int = 0
var tournament_end_day: int = 0
var tournament_results: Dictionary = {}

# Cooldown between tournaments (days)
const TOURNAMENT_COOLDOWN: int = 7
var last_tournament_end_day: int = -100

func _ready() -> void:
	EventBus.end_of_day.connect(_on_end_of_day)

func _on_end_of_day(_day: int) -> void:
	var current_day = GameManager.current_day

	match current_tournament_state:
		TournamentSystem.TournamentState.SCHEDULED:
			if current_day >= tournament_start_day:
				_start_tournament()
		TournamentSystem.TournamentState.IN_PROGRESS:
			if current_day >= tournament_end_day:
				_complete_tournament()

## Check if a tournament can be scheduled
func can_schedule_tournament(tier: int) -> Dictionary:
	var result = {"can_schedule": true, "reason": ""}

	# Check if tournament already active
	if current_tournament_state != TournamentSystem.TournamentState.NONE:
		result.can_schedule = false
		result.reason = "Tournament already scheduled or in progress"
		return result

	# Check cooldown
	var days_since_last = GameManager.current_day - last_tournament_end_day
	if days_since_last < TOURNAMENT_COOLDOWN:
		result.can_schedule = false
		result.reason = "Must wait %d more days" % (TOURNAMENT_COOLDOWN - days_since_last)
		return result

	# Check qualification
	var qualification = TournamentSystem.check_qualification(
		tier,
		GameManager.current_course,
		GameManager.course_rating
	)
	if not qualification.qualified:
		result.can_schedule = false
		result.reason = qualification.missing[0] if not qualification.missing.is_empty() else "Course not qualified"
		return result

	# Check if can afford entry cost
	var tier_data = TournamentSystem.get_tier_data(tier)
	if GameManager.money < tier_data.entry_cost:
		result.can_schedule = false
		result.reason = "Need $%d to host (have $%d)" % [tier_data.entry_cost, GameManager.money]
		return result

	return result

## Schedule a tournament to start in 3 days
func schedule_tournament(tier: int) -> bool:
	var check = can_schedule_tournament(tier)
	if not check.can_schedule:
		return false

	var tier_data = TournamentSystem.get_tier_data(tier)

	# Pay entry cost
	GameManager.money -= tier_data.entry_cost

	# Schedule tournament
	current_tournament_tier = tier
	current_tournament_state = TournamentSystem.TournamentState.SCHEDULED
	tournament_start_day = GameManager.current_day + 3  # Starts in 3 days
	tournament_end_day = tournament_start_day + tier_data.duration_days - 1

	tournament_scheduled.emit(tier, tournament_start_day)
	EventBus.tournament_scheduled.emit(tier, tournament_start_day)

	return true

func _start_tournament() -> void:
	current_tournament_state = TournamentSystem.TournamentState.IN_PROGRESS
	tournament_started.emit(current_tournament_tier)
	EventBus.tournament_started.emit(current_tournament_tier)

func _complete_tournament() -> void:
	var tier_data = TournamentSystem.get_tier_data(current_tournament_tier)

	# Generate results
	tournament_results = TournamentSystem.generate_tournament_results(
		current_tournament_tier,
		GameManager.current_course,
		GameManager.course_rating
	)

	# Award reputation
	GameManager.reputation += tier_data.reputation_reward

	# Record completion
	last_tournament_end_day = GameManager.current_day
	var completed_tier = current_tournament_tier

	# Reset state
	current_tournament_tier = -1
	current_tournament_state = TournamentSystem.TournamentState.NONE

	tournament_completed.emit(completed_tier, tournament_results)
	EventBus.tournament_completed.emit(completed_tier, tournament_results)

## Get current tournament info for display
func get_tournament_info() -> Dictionary:
	if current_tournament_state == TournamentSystem.TournamentState.NONE:
		return {}

	var tier_data = TournamentSystem.get_tier_data(current_tournament_tier)
	return {
		"tier": current_tournament_tier,
		"name": tier_data.name,
		"state": current_tournament_state,
		"start_day": tournament_start_day,
		"end_day": tournament_end_day,
		"days_remaining": tournament_end_day - GameManager.current_day + 1 if current_tournament_state == TournamentSystem.TournamentState.IN_PROGRESS else tournament_start_day - GameManager.current_day,
	}

## Get days until next tournament can be scheduled
func get_cooldown_remaining() -> int:
	var days_since = GameManager.current_day - last_tournament_end_day
	return max(0, TOURNAMENT_COOLDOWN - days_since)

## Save tournament state
func get_save_data() -> Dictionary:
	return {
		"current_tier": current_tournament_tier,
		"state": current_tournament_state,
		"start_day": tournament_start_day,
		"end_day": tournament_end_day,
		"last_end_day": last_tournament_end_day,
	}

## Load tournament state
func load_save_data(data: Dictionary) -> void:
	current_tournament_tier = data.get("current_tier", -1)
	current_tournament_state = data.get("state", TournamentSystem.TournamentState.NONE)
	tournament_start_day = data.get("start_day", 0)
	tournament_end_day = data.get("end_day", 0)
	last_tournament_end_day = data.get("last_end_day", -100)
