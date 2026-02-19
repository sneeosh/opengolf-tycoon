extends Node
class_name TournamentManager
## TournamentManager - Handles tournament scheduling, execution, and rewards.
## Spawns real golfer scene nodes for visible tournament play.
## Tracks live scores and supports End Day fast-forward via ShotSimulator.

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

# Tournament golfer tracking
var _tournament_golfer_ids: Array[int] = []
var _tournament_scores: Dictionary = {}  # golfer_id -> {name, total_strokes, total_par, holes_completed, is_finished, skill}
var _groups_spawned: int = 0
var _total_groups: int = 0
var _spawn_timer: float = 0.0

# Stagger interval: 2 game-minutes between groups
const GROUP_SPAWN_INTERVAL: float = 120.0  # seconds in game time

# External references (set via setup())
var _golfer_manager: GolferManager = null
var _leaderboard: TournamentLeaderboard = null

func setup(golfer_manager: GolferManager, leaderboard: TournamentLeaderboard) -> void:
	_golfer_manager = golfer_manager
	_leaderboard = leaderboard

func _ready() -> void:
	EventBus.day_changed.connect(_on_day_changed)
	EventBus.end_of_day.connect(_on_end_of_day)
	EventBus.golfer_finished_hole.connect(_on_golfer_finished_hole)
	EventBus.golfer_finished_round.connect(_on_golfer_finished_round)

func _process(delta: float) -> void:
	# Safety fallback: start a scheduled tournament if day_changed was missed
	# (e.g., after save/load on the start day)
	if current_tournament_state == TournamentSystem.TournamentState.SCHEDULED:
		if GameManager.current_day >= tournament_start_day and _golfer_manager != null \
				and GameManager.current_mode == GameManager.GameMode.SIMULATING:
			_start_tournament()
		return

	if current_tournament_state != TournamentSystem.TournamentState.IN_PROGRESS:
		return
	if _groups_spawned >= _total_groups:
		return

	# Stagger group spawning using game time
	var time_scale = GameManager.get_game_speed_multiplier()
	_spawn_timer += delta * time_scale
	if _spawn_timer >= GROUP_SPAWN_INTERVAL:
		_spawn_timer -= GROUP_SPAWN_INTERVAL
		_spawn_next_group()

func _on_day_changed(new_day: int) -> void:
	# Start tournament at the BEGINNING of the scheduled day
	if current_tournament_state == TournamentSystem.TournamentState.SCHEDULED:
		if new_day >= tournament_start_day:
			_start_tournament()

func _on_end_of_day(_day: int) -> void:
	# Complete in-progress tournaments at end of day
	if current_tournament_state == TournamentSystem.TournamentState.IN_PROGRESS:
		simulate_remaining_and_complete()

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

## Schedule a tournament
func schedule_tournament(tier: int) -> bool:
	var check = can_schedule_tournament(tier)
	if not check.can_schedule:
		return false

	var tier_data = TournamentSystem.get_tier_data(tier)

	# Pay entry cost
	GameManager.money -= tier_data.entry_cost

	# Lead time: local tournaments start next day, larger ones need 3 days prep
	var lead_days = 1 if tier == TournamentSystem.TournamentTier.LOCAL else 3

	# Schedule tournament
	current_tournament_tier = tier
	current_tournament_state = TournamentSystem.TournamentState.SCHEDULED
	tournament_start_day = GameManager.current_day + lead_days
	tournament_end_day = tournament_start_day + tier_data.duration_days - 1

	tournament_scheduled.emit(tier, tournament_start_day)
	EventBus.tournament_scheduled.emit(tier, tournament_start_day)

	return true

func _start_tournament() -> void:
	current_tournament_state = TournamentSystem.TournamentState.IN_PROGRESS

	# Clear regular golfers from the course
	if _golfer_manager:
		_golfer_manager.clear_all_golfers()

	# Reset tournament tracking
	_tournament_golfer_ids.clear()
	_tournament_scores.clear()
	_groups_spawned = 0
	_spawn_timer = 0.0

	var tier_data = TournamentSystem.get_tier_data(current_tournament_tier)
	_total_groups = ceili(float(tier_data.participant_count) / 4.0)

	# Show leaderboard
	if _leaderboard:
		_leaderboard.show_for_tournament(tier_data.name)

	# Spawn first group immediately
	_spawn_next_group()

	tournament_started.emit(current_tournament_tier)
	EventBus.tournament_started.emit(current_tournament_tier)

func _spawn_next_group() -> void:
	if not _golfer_manager:
		return
	if _groups_spawned >= _total_groups:
		return

	var tier_data = TournamentSystem.get_tier_data(current_tournament_tier)
	var remaining = tier_data.participant_count - (_groups_spawned * 4)
	var group_size = mini(4, remaining)
	var group_id = _golfer_manager.next_group_id
	_golfer_manager.next_group_id += 1

	for i in range(group_size):
		# 50% PRO, 50% SERIOUS
		var tier = GolferTier.Tier.PRO if randf() > 0.5 else GolferTier.Tier.SERIOUS
		var golfer = _golfer_manager.spawn_tournament_golfer(tier, group_id)
		if golfer:
			_tournament_golfer_ids.append(golfer.golfer_id)
			var avg_skill = (golfer.driving_skill + golfer.accuracy_skill + golfer.putting_skill + golfer.recovery_skill) / 4.0
			_tournament_scores[golfer.golfer_id] = {
				"name": golfer.golfer_name,
				"total_strokes": 0,
				"total_par": 0,
				"holes_completed": 0,
				"is_finished": false,
				"skill": avg_skill,
				"current_hole": 0,
			}
			if _leaderboard:
				_leaderboard.register_golfer(golfer.golfer_id, golfer.golfer_name)

	_groups_spawned += 1
	print("Tournament group %d/%d spawned (%d golfers)" % [_groups_spawned, _total_groups, group_size])

func _on_golfer_finished_hole(golfer_id: int, hole: int, strokes: int, par: int) -> void:
	if golfer_id not in _tournament_golfer_ids:
		return

	if _tournament_scores.has(golfer_id):
		var entry = _tournament_scores[golfer_id]
		entry.total_strokes += strokes
		entry.total_par += par
		entry.holes_completed += 1
		entry.current_hole = hole + 1

	if _leaderboard:
		_leaderboard.update_score(golfer_id, hole, strokes, par)

func _on_golfer_finished_round(golfer_id: int, total_strokes: int) -> void:
	if golfer_id not in _tournament_golfer_ids:
		return

	if _tournament_scores.has(golfer_id):
		var entry = _tournament_scores[golfer_id]
		entry.is_finished = true
		entry.total_strokes = total_strokes  # Use authoritative total

	if _leaderboard:
		_leaderboard.mark_finished(golfer_id, total_strokes)

	# Check if all tournament golfers are finished
	var all_done = true
	for gid in _tournament_golfer_ids:
		if _tournament_scores.has(gid) and not _tournament_scores[gid].is_finished:
			all_done = false
			break

	if all_done and _groups_spawned >= _total_groups:
		# Complete immediately — no delay to avoid race with end-of-day
		_complete_tournament()

## Simulate remaining holes for unfinished golfers and complete the tournament.
## Called from main.gd when End Day is pressed during a tournament.
func simulate_remaining_and_complete() -> void:
	if current_tournament_state != TournamentSystem.TournamentState.IN_PROGRESS:
		return

	# Spawn any remaining unspawned groups and simulate them entirely
	while _groups_spawned < _total_groups:
		_spawn_remaining_group_headless()

	# Simulate remaining holes for unfinished golfers
	var simulated_results: Array = []
	for gid in _tournament_golfer_ids:
		if not _tournament_scores.has(gid):
			continue
		var entry = _tournament_scores[gid]
		if entry.is_finished:
			continue

		var golfer_data = {
			"total_strokes": entry.total_strokes,
			"total_par": entry.total_par,
			"current_hole": entry.current_hole,
			"skill": entry.skill,
		}
		var difficulty = GameManager.course_rating.get("difficulty", 5.0)
		var result = ShotSimulator.simulate_remaining_holes(golfer_data, GameManager.current_course, difficulty)
		entry.total_strokes = result.total_strokes
		entry.total_par = result.total_par
		entry.holes_completed += result.holes_played
		entry.is_finished = true

		simulated_results.append({
			"golfer_id": gid,
			"total_strokes": entry.total_strokes,
			"total_par": entry.total_par,
			"holes_completed": entry.holes_completed,
		})

	# Update leaderboard with simulated results
	if _leaderboard and not simulated_results.is_empty():
		_leaderboard.set_simulated_results(simulated_results)

	# Remove remaining tournament golfers from the course
	if _golfer_manager:
		_golfer_manager.remove_tournament_golfers()

	_complete_tournament()

## Spawn a group headlessly (for End Day fast-forward of unspawned groups)
func _spawn_remaining_group_headless() -> void:
	var tier_data = TournamentSystem.get_tier_data(current_tournament_tier)
	var remaining = tier_data.participant_count - (_groups_spawned * 4)
	var group_size = mini(4, remaining)

	for i in range(group_size):
		var tier = GolferTier.Tier.PRO if randf() > 0.5 else GolferTier.Tier.SERIOUS
		var skills = GolferTier.generate_skills(tier)
		var avg_skill = (skills.driving + skills.accuracy + skills.putting + skills.recovery) / 4.0

		var fake_id = -1000 - (_groups_spawned * 4 + i)  # Negative IDs for headless golfers
		var pro_names = ["Seve", "Vijay", "Ernie", "Lee", "Gary", "Sam", "Ben", "Walter"]
		var name = GolferTier.get_name_prefix(tier) + " " + pro_names[randi() % pro_names.size()]

		_tournament_golfer_ids.append(fake_id)

		# Simulate entire round headlessly
		var golfer_data = {
			"total_strokes": 0,
			"total_par": 0,
			"current_hole": 0,
			"skill": avg_skill,
		}
		var difficulty = GameManager.course_rating.get("difficulty", 5.0)
		var result = ShotSimulator.simulate_remaining_holes(golfer_data, GameManager.current_course, difficulty)

		_tournament_scores[fake_id] = {
			"name": name,
			"total_strokes": result.total_strokes,
			"total_par": result.total_par,
			"holes_completed": result.holes_played,
			"is_finished": true,
			"skill": avg_skill,
			"current_hole": result.holes_played,
		}

		if _leaderboard:
			_leaderboard.register_golfer(fake_id, name)
			# Immediately update leaderboard with simulated scores
			_leaderboard.set_simulated_results([{
				"golfer_id": fake_id,
				"total_strokes": result.total_strokes,
				"total_par": result.total_par,
				"holes_completed": result.holes_played,
			}])

	_groups_spawned += 1

func _complete_tournament() -> void:
	var tier_data = TournamentSystem.get_tier_data(current_tournament_tier)

	# Build results from real tournament scores
	var scores: Array = []
	var all_entries: Array = []
	for gid in _tournament_golfer_ids:
		if _tournament_scores.has(gid):
			var entry = _tournament_scores[gid]
			scores.append(entry.total_strokes)
			all_entries.append(entry)

	# Sort by score vs par
	all_entries.sort_custom(func(a, b):
		var a_diff = a.total_strokes - a.total_par
		var b_diff = b.total_strokes - b.total_par
		return a_diff < b_diff
	)
	scores.sort()

	var winner_name = all_entries[0].name if not all_entries.is_empty() else "Unknown"
	var winning_score = scores[0] if not scores.is_empty() else 0
	var course_par = TournamentSystem._get_course_par(GameManager.current_course)

	tournament_results = {
		"winner_name": winner_name,
		"winning_score": winning_score,
		"par": course_par,
		"scores": scores,
		"participant_count": _tournament_golfer_ids.size(),
		"prize_pool": tier_data.prize_pool,
	}

	# Award tournament revenue (spectators + sponsorships)
	var spectator_rev = tier_data.get("spectator_revenue", 0)
	var sponsor_rev = tier_data.get("sponsorship_revenue", 0)
	var total_revenue = spectator_rev + sponsor_rev
	if total_revenue > 0:
		GameManager.modify_money(total_revenue)
		EventBus.log_transaction("Tournament revenue (spectators + sponsors)", total_revenue)

	# Store revenue in results for display
	tournament_results["spectator_revenue"] = spectator_rev
	tournament_results["sponsorship_revenue"] = sponsor_rev
	tournament_results["total_revenue"] = total_revenue

	# Award reputation
	GameManager.modify_reputation(tier_data.reputation_reward)

	# Show final results on leaderboard
	if _leaderboard:
		_leaderboard.show_final_results()

	# Record completion
	last_tournament_end_day = GameManager.current_day
	var completed_tier = current_tournament_tier

	# Reset state
	current_tournament_tier = -1
	current_tournament_state = TournamentSystem.TournamentState.NONE
	_tournament_golfer_ids.clear()
	_tournament_scores.clear()

	tournament_completed.emit(completed_tier, tournament_results)
	EventBus.tournament_completed.emit(completed_tier, tournament_results)

	EventBus.notify("Tournament complete! Winner: %s (%d)" % [winner_name, winning_score], "success")

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

## Check if a tournament is currently in progress (course closed to regular play)
func is_tournament_in_progress() -> bool:
	return current_tournament_state == TournamentSystem.TournamentState.IN_PROGRESS

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
	var loaded_state = data.get("state", TournamentSystem.TournamentState.NONE)
	# If saved during IN_PROGRESS, revert to NONE — tournament golfers aren't persisted
	if loaded_state == TournamentSystem.TournamentState.IN_PROGRESS:
		current_tournament_state = TournamentSystem.TournamentState.NONE
		current_tournament_tier = -1
	else:
		current_tournament_state = loaded_state
	tournament_start_day = data.get("start_day", 0)
	tournament_end_day = data.get("end_day", 0)
	last_tournament_end_day = data.get("last_end_day", -100)
