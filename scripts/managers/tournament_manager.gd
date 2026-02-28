extends Node
class_name TournamentManager
## TournamentManager - Handles tournament scheduling, execution, and rewards.
##
## Supports multi-round tournaments with cut lines:
## - LOCAL: 1 round, 1 day
## - REGIONAL: 2 rounds, 2 days
## - NATIONAL: 4 rounds, 3 days (rounds 3-4 on day 3)
## - CHAMPIONSHIP: 4 rounds, 4 days
##
## Round 1 uses live golfer nodes on-course. Subsequent rounds and End Day
## fast-forward use TournamentSimulator for shot-by-shot headless simulation.

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

# Multi-round state
var current_round: int = 0           # 1-based round number (0 = not started)
var total_rounds: int = 1            # Total rounds for this tier
var _round_day_map: Array = []       # Which rounds play on which tournament day

# Tournament field (persistent across rounds)
var _sim_field: Array = []           # Array of TournamentSimulator.SimGolfer
var _round_scores: Dictionary = {}   # golfer_id → Array of RoundResult
var _cumulative_scores: Dictionary = {} # golfer_id → {total_strokes, total_par}
var _cut_golfer_ids: Array = []      # IDs of golfers who made the cut (empty = no cut yet)
var _eliminated_ids: Array = []      # IDs of golfers who missed the cut
var _tournament_moments: Array = []  # TournamentMoment entries across all rounds

# Live play tracking (round 1 only)
var _tournament_golfer_ids: Array[int] = []
var _tournament_scores: Dictionary = {}  # golfer_id -> {name, total_strokes, total_par, holes_completed, is_finished, skill}
var _groups_spawned: int = 0
var _total_groups: int = 0
var _spawn_timer: float = 0.0
var _live_round_active: bool = false  # True when live golfers are playing round 1

# Stagger interval: 30 game-seconds between groups
const GROUP_SPAWN_INTERVAL: float = 30.0

# External references (set via setup())
var _golfer_manager: GolferManager = null
var _leaderboard: TournamentLeaderboard = null
var _pre_tournament_speed: int = -1

# Rounds per tier
const ROUNDS_PER_TIER: Dictionary = {
	TournamentSystem.TournamentTier.LOCAL: 1,
	TournamentSystem.TournamentTier.REGIONAL: 2,
	TournamentSystem.TournamentTier.NATIONAL: 4,
	TournamentSystem.TournamentTier.CHAMPIONSHIP: 4,
}

# Cut line rules: {round_after_which_cut_applies: cut_rule}
# "top_50pct" = top 50% advance, "top_40_ties" = top 40 + ties advance
const CUT_RULES: Dictionary = {
	TournamentSystem.TournamentTier.NATIONAL: {"after_round": 2, "rule": "top_50pct"},
	TournamentSystem.TournamentTier.CHAMPIONSHIP: {"after_round": 2, "rule": "top_40_ties"},
}

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
	if current_tournament_state == TournamentSystem.TournamentState.SCHEDULED:
		if GameManager.current_day >= tournament_start_day and _golfer_manager != null \
				and GameManager.current_mode == GameManager.GameMode.SIMULATING:
			_start_tournament()
		return

	if current_tournament_state != TournamentSystem.TournamentState.IN_PROGRESS:
		return

	# Force-complete current round if past 10 PM
	if _live_round_active and GameManager.current_hour >= GameManager.COURSE_CLOSE_HOUR + 2.0:
		_end_current_day_round()
		return

	# Stagger group spawning for live round
	if _live_round_active and _groups_spawned < _total_groups:
		var time_scale = GameManager.get_game_speed_multiplier()
		_spawn_timer += delta * time_scale
		if _spawn_timer >= GROUP_SPAWN_INTERVAL:
			_spawn_timer -= GROUP_SPAWN_INTERVAL
			_spawn_next_group()

func _on_day_changed(new_day: int) -> void:
	if current_tournament_state == TournamentSystem.TournamentState.SCHEDULED:
		if new_day >= tournament_start_day:
			_start_tournament()
		return

	if current_tournament_state != TournamentSystem.TournamentState.IN_PROGRESS:
		return

	# Which tournament day is this? (0-based offset from start)
	var tournament_day = new_day - tournament_start_day
	if tournament_day < 0:
		return

	# Determine which rounds to play today
	var rounds_today = _get_rounds_for_day(tournament_day)
	if rounds_today.is_empty():
		return

	# Clear regular golfers for tournament day
	if _golfer_manager:
		_golfer_manager.clear_all_golfers()

	# Play each round scheduled for today
	for round_num in rounds_today:
		if round_num <= current_round:
			continue  # Already played
		_play_round(round_num)

func _on_end_of_day(_day: int) -> void:
	if current_tournament_state != TournamentSystem.TournamentState.IN_PROGRESS:
		return

	# If live round is active, simulate remaining and advance
	if _live_round_active:
		_end_current_day_round()

func _on_golfer_finished_hole(golfer_id: int, hole: int, strokes: int, par: int) -> void:
	if not _live_round_active or golfer_id not in _tournament_golfer_ids:
		return

	if _tournament_scores.has(golfer_id):
		var entry = _tournament_scores[golfer_id]
		entry.total_strokes += strokes
		entry.total_par += par
		entry.holes_completed += 1
		entry.current_hole = hole + 1

	if _leaderboard:
		_leaderboard.update_score(golfer_id, hole, strokes, par)

func _on_golfer_finished_round(golfer_id: int, total_strokes: int, _total_par: int) -> void:
	if not _live_round_active or golfer_id not in _tournament_golfer_ids:
		return

	if _tournament_scores.has(golfer_id):
		var entry = _tournament_scores[golfer_id]
		entry.is_finished = true
		entry.total_strokes = total_strokes

	if _leaderboard:
		_leaderboard.mark_finished(golfer_id, total_strokes)

	# Check if all live golfers finished
	_check_live_round_completion()

# ============================================================================
# SCHEDULING
# ============================================================================

func can_schedule_tournament(tier: int) -> Dictionary:
	var result = {"can_schedule": true, "reason": ""}

	if current_tournament_state != TournamentSystem.TournamentState.NONE:
		result.can_schedule = false
		result.reason = "Tournament already scheduled or in progress"
		return result

	var days_since_last = GameManager.current_day - last_tournament_end_day
	if days_since_last < TOURNAMENT_COOLDOWN:
		result.can_schedule = false
		result.reason = "Must wait %d more days" % (TOURNAMENT_COOLDOWN - days_since_last)
		return result

	GameManager.update_course_rating()

	var qualification = TournamentSystem.check_qualification(
		tier, GameManager.current_course, GameManager.course_rating
	)
	if not qualification.qualified:
		result.can_schedule = false
		result.reason = qualification.missing[0] if not qualification.missing.is_empty() else "Course not qualified"
		return result

	var tier_data = TournamentSystem.get_tier_data(tier)
	if GameManager.money < tier_data.entry_cost:
		result.can_schedule = false
		result.reason = "Need $%d to host (have $%d)" % [tier_data.entry_cost, GameManager.money]
		return result

	return result

func schedule_tournament(tier: int) -> bool:
	var check = can_schedule_tournament(tier)
	if not check.can_schedule:
		return false

	var tier_data = TournamentSystem.get_tier_data(tier)

	GameManager.modify_money(-tier_data.entry_cost)
	GameManager.daily_stats.tournament_entry_fee += tier_data.entry_cost
	EventBus.log_transaction("Tournament entry fee (%s)" % tier_data.name, -tier_data.entry_cost)

	var lead_days = 1 if tier == TournamentSystem.TournamentTier.LOCAL else 3

	current_tournament_tier = tier
	current_tournament_state = TournamentSystem.TournamentState.SCHEDULED
	tournament_start_day = GameManager.current_day + lead_days
	tournament_end_day = tournament_start_day + tier_data.duration_days - 1
	total_rounds = ROUNDS_PER_TIER.get(tier, 1)
	current_round = 0
	_round_day_map = _build_round_day_map(tier)

	tournament_scheduled.emit(tier, tournament_start_day)
	EventBus.tournament_scheduled.emit(tier, tournament_start_day)

	return true

# ============================================================================
# TOURNAMENT START
# ============================================================================

func _start_tournament() -> void:
	current_tournament_state = TournamentSystem.TournamentState.IN_PROGRESS

	_pre_tournament_speed = GameManager.current_speed
	if GameManager.current_speed < GameManager.GameSpeed.FAST:
		GameManager.current_speed = GameManager.GameSpeed.FAST

	if _golfer_manager:
		_golfer_manager.clear_all_golfers()

	# Reset all tournament tracking
	_tournament_golfer_ids.clear()
	_tournament_scores.clear()
	_round_scores.clear()
	_cumulative_scores.clear()
	_cut_golfer_ids.clear()
	_eliminated_ids.clear()
	_tournament_moments.clear()
	_groups_spawned = 0
	_spawn_timer = 0.0
	_live_round_active = false

	var tier_data = TournamentSystem.get_tier_data(current_tournament_tier)

	# Generate the full tournament field using TournamentSimulator
	_sim_field = TournamentSimulator.generate_field(current_tournament_tier, tier_data.participant_count)

	# Initialize cumulative scores
	for sg in _sim_field:
		_cumulative_scores[sg.id] = {"total_strokes": 0, "total_par": 0}
		_round_scores[sg.id] = []

	# Show leaderboard
	if _leaderboard:
		var round_text = "Round 1/%d" % total_rounds if total_rounds > 1 else ""
		_leaderboard.show_for_tournament(tier_data.name, tier_data.participant_count, total_rounds, round_text)

	tournament_started.emit(current_tournament_tier)
	EventBus.tournament_started.emit(current_tournament_tier)

	# Play round 1 — with live golfers on day 1
	_play_round(1)

# ============================================================================
# ROUND EXECUTION
# ============================================================================

## Play a specific round. Round 1 uses live golfers; rounds 2+ are simulated.
func _play_round(round_number: int) -> void:
	current_round = round_number

	var tier_data = TournamentSystem.get_tier_data(current_tournament_tier)
	var round_label = "Round %d/%d" % [round_number, total_rounds] if total_rounds > 1 else ""

	if _leaderboard:
		_leaderboard.update_round_info(round_number, total_rounds, round_label)

	EventBus.tournament_simulation_started.emit(current_tournament_tier, round_number)

	if round_number == 1:
		# Round 1: spawn live golfers
		_start_live_round()
	else:
		# Rounds 2+: simulate headlessly
		_simulate_round_headless(round_number)

## Start live round with on-course golfer nodes (round 1 only)
func _start_live_round() -> void:
	_live_round_active = true
	_groups_spawned = 0
	_spawn_timer = 0.0
	_tournament_golfer_ids.clear()
	_tournament_scores.clear()

	# Determine how many groups to spawn for live play
	var active_field = _get_active_field()
	_total_groups = ceili(float(active_field.size()) / 4.0)

	# Spawn first group immediately
	_spawn_next_group()

func _spawn_next_group() -> void:
	if not _golfer_manager:
		return
	if _groups_spawned >= _total_groups:
		return

	var active_field = _get_active_field()
	var start_idx = _groups_spawned * 4
	var end_idx = mini(start_idx + 4, active_field.size())
	var group_size = end_idx - start_idx
	if group_size <= 0:
		_groups_spawned = _total_groups
		return

	var group_id = _golfer_manager.next_group_id
	_golfer_manager.next_group_id += 1

	for i in range(start_idx, end_idx):
		var sg: TournamentSimulator.SimGolfer = active_field[i]
		var tier = sg.tier
		var golfer = _golfer_manager.spawn_tournament_golfer(tier, group_id)
		if golfer:
			# Apply the simulated golfer's skills to the live golfer
			golfer.driving_skill = sg.driving_skill
			golfer.accuracy_skill = sg.accuracy_skill
			golfer.putting_skill = sg.putting_skill
			golfer.recovery_skill = sg.recovery_skill
			golfer.miss_tendency = sg.miss_tendency
			golfer.aggression = sg.aggression
			golfer.patience = sg.patience
			golfer.golfer_name = sg.name

			_tournament_golfer_ids.append(golfer.golfer_id)
			var avg_skill = (sg.driving_skill + sg.accuracy_skill + sg.putting_skill + sg.recovery_skill) / 4.0
			_tournament_scores[golfer.golfer_id] = {
				"name": sg.name,
				"sim_id": sg.id,
				"total_strokes": 0,
				"total_par": 0,
				"holes_completed": 0,
				"is_finished": false,
				"skill": avg_skill,
				"current_hole": 0,
			}
			if _leaderboard:
				_leaderboard.register_golfer(golfer.golfer_id, sg.name, sg.id)

	_groups_spawned += 1
	print("Tournament group %d/%d spawned (%d golfers)" % [_groups_spawned, _total_groups, group_size])

## Simulate a round headlessly for all active golfers using real shot physics
func _simulate_round_headless(round_number: int) -> void:
	var active_field = _get_active_field()
	var round_moments: Array = []

	print("Simulating round %d for %d golfers..." % [round_number, active_field.size()])

	for sg in active_field:
		var result: TournamentSimulator.RoundResult = TournamentSimulator.simulate_round(sg, round_number)

		# Store round result
		if not _round_scores.has(sg.id):
			_round_scores[sg.id] = []
		_round_scores[sg.id].append(result)

		# Update cumulative scores
		if _cumulative_scores.has(sg.id):
			_cumulative_scores[sg.id].total_strokes += result.total_strokes
			_cumulative_scores[sg.id].total_par += result.total_par

		# Collect moments
		round_moments.append_array(result.moments)

		# Update leaderboard
		if _leaderboard:
			_leaderboard.set_round_score(sg.id, round_number,
				result.total_strokes, result.total_par,
				_cumulative_scores[sg.id].total_strokes,
				_cumulative_scores[sg.id].total_par)

	# Store moments
	_tournament_moments.append_array(round_moments)

	# Emit moment notifications
	_emit_moments(round_moments)

	# Emit round completed
	var standings = _get_standings()
	EventBus.tournament_round_completed.emit(current_tournament_tier, round_number, standings)
	EventBus.tournament_simulation_completed.emit(current_tournament_tier, round_number)

	print("Round %d complete. Leader: %s at %s" % [
		round_number,
		standings[0].name if not standings.is_empty() else "N/A",
		_format_score(standings[0]) if not standings.is_empty() else "N/A"
	])

	# Apply cut line after round 2 if applicable
	if CUT_RULES.has(current_tournament_tier):
		var cut_info = CUT_RULES[current_tournament_tier]
		if round_number == cut_info.after_round and _cut_golfer_ids.is_empty():
			_apply_cut_line(cut_info.rule)

	# Check if tournament is complete after this round
	if current_round >= total_rounds:
		_complete_tournament()
	elif _leaderboard:
		_leaderboard.update_round_info(current_round, total_rounds,
			"Round %d/%d Complete" % [current_round, total_rounds])

## End the current day's live round — simulate remaining golfers and advance
func _end_current_day_round() -> void:
	if not _live_round_active:
		return

	# Spawn and simulate any unspawned groups using TournamentSimulator
	var active_field = _get_active_field()
	while _groups_spawned < _total_groups:
		_spawn_remaining_group_headless(active_field)

	# Simulate remaining holes for unfinished live golfers using TournamentSimulator
	var simulated_results: Array = []
	for gid in _tournament_golfer_ids:
		if not _tournament_scores.has(gid):
			continue
		var entry = _tournament_scores[gid]
		if entry.is_finished:
			continue

		# Find the matching SimGolfer
		var sim_id = entry.get("sim_id", gid)
		var sg = _find_sim_golfer(sim_id)
		if not sg:
			# Fallback: create from existing data
			sg = TournamentSimulator.SimGolfer.new()
			sg.id = sim_id
			sg.name = entry.name
			sg.driving_skill = entry.skill
			sg.accuracy_skill = entry.skill
			sg.putting_skill = entry.skill
			sg.recovery_skill = entry.skill

		var result = TournamentSimulator.simulate_remaining(sg,
			entry.current_hole, entry.total_strokes, entry.total_par)

		entry.total_strokes = result.total_strokes
		entry.total_par = result.total_par
		entry.holes_completed += result.hole_scores.size()
		entry.is_finished = true

		simulated_results.append({
			"golfer_id": gid,
			"total_strokes": result.total_strokes,
			"total_par": result.total_par,
			"holes_completed": entry.holes_completed,
		})

		_tournament_moments.append_array(result.moments)

	# Update leaderboard
	if _leaderboard and not simulated_results.is_empty():
		_leaderboard.set_simulated_results(simulated_results)

	# Remove live golfers from course
	if _golfer_manager:
		_golfer_manager.remove_tournament_golfers()

	# Record round 1 results into round_scores and cumulative_scores
	_record_live_round_results()

	_live_round_active = false

	# Emit round completion
	var standings = _get_standings()
	EventBus.tournament_round_completed.emit(current_tournament_tier, current_round, standings)

	# Apply cut if needed
	if CUT_RULES.has(current_tournament_tier):
		var cut_info = CUT_RULES[current_tournament_tier]
		if current_round == cut_info.after_round and _cut_golfer_ids.is_empty():
			_apply_cut_line(cut_info.rule)

	# Check if this was the last round
	if current_round >= total_rounds:
		_complete_tournament()
	else:
		# Determine if more rounds play today
		var tournament_day = GameManager.current_day - tournament_start_day
		var rounds_today = _get_rounds_for_day(tournament_day)
		for round_num in rounds_today:
			if round_num > current_round:
				_play_round(round_num)
				return

## Spawn unspawned groups headlessly using TournamentSimulator
func _spawn_remaining_group_headless(active_field: Array) -> void:
	var start_idx = _groups_spawned * 4
	var end_idx = mini(start_idx + 4, active_field.size())
	var group_size = end_idx - start_idx
	if group_size <= 0:
		_groups_spawned = _total_groups
		return

	for i in range(start_idx, end_idx):
		var sg: TournamentSimulator.SimGolfer = active_field[i]
		var result = TournamentSimulator.simulate_round(sg, current_round)

		var fake_id = sg.id  # Use sim golfer's negative ID
		_tournament_golfer_ids.append(fake_id)

		_tournament_scores[fake_id] = {
			"name": sg.name,
			"sim_id": sg.id,
			"total_strokes": result.total_strokes,
			"total_par": result.total_par,
			"holes_completed": result.hole_scores.size(),
			"is_finished": true,
			"skill": (sg.driving_skill + sg.accuracy_skill + sg.putting_skill + sg.recovery_skill) / 4.0,
			"current_hole": result.hole_scores.size(),
		}

		_tournament_moments.append_array(result.moments)

		if _leaderboard:
			_leaderboard.register_golfer(fake_id, sg.name, sg.id)
			_leaderboard.set_simulated_results([{
				"golfer_id": fake_id,
				"total_strokes": result.total_strokes,
				"total_par": result.total_par,
				"holes_completed": result.hole_scores.size(),
			}])

	_groups_spawned += 1

func _check_live_round_completion() -> void:
	var all_done = true
	for gid in _tournament_golfer_ids:
		if _tournament_scores.has(gid) and not _tournament_scores[gid].is_finished:
			all_done = false
			break

	if all_done and _groups_spawned >= _total_groups:
		# Record results and check for more rounds today
		if _golfer_manager:
			_golfer_manager.remove_tournament_golfers()

		_record_live_round_results()
		_live_round_active = false

		var standings = _get_standings()
		EventBus.tournament_round_completed.emit(current_tournament_tier, current_round, standings)

		# Apply cut if needed
		if CUT_RULES.has(current_tournament_tier):
			var cut_info = CUT_RULES[current_tournament_tier]
			if current_round == cut_info.after_round and _cut_golfer_ids.is_empty():
				_apply_cut_line(cut_info.rule)

		if current_round >= total_rounds:
			_complete_tournament()
		else:
			# Check if more rounds play today
			var tournament_day = GameManager.current_day - tournament_start_day
			var rounds_today = _get_rounds_for_day(tournament_day)
			for round_num in rounds_today:
				if round_num > current_round:
					_play_round(round_num)
					return

## Record live round results into the persistent round_scores/cumulative_scores
func _record_live_round_results() -> void:
	for gid in _tournament_golfer_ids:
		if not _tournament_scores.has(gid):
			continue
		var entry = _tournament_scores[gid]
		var sim_id = entry.get("sim_id", gid)

		# Create a RoundResult from live play data
		var rr = TournamentSimulator.RoundResult.new()
		rr.golfer_id = sim_id
		rr.golfer_name = entry.name
		rr.round_number = current_round
		rr.total_strokes = entry.total_strokes
		rr.total_par = entry.total_par

		if not _round_scores.has(sim_id):
			_round_scores[sim_id] = []
		_round_scores[sim_id].append(rr)

		# Update cumulative
		if _cumulative_scores.has(sim_id):
			_cumulative_scores[sim_id].total_strokes += entry.total_strokes
			_cumulative_scores[sim_id].total_par += entry.total_par
		else:
			_cumulative_scores[sim_id] = {
				"total_strokes": entry.total_strokes,
				"total_par": entry.total_par,
			}

		# Update leaderboard with cumulative scores
		if _leaderboard:
			_leaderboard.set_round_score(sim_id, current_round,
				entry.total_strokes, entry.total_par,
				_cumulative_scores[sim_id].total_strokes,
				_cumulative_scores[sim_id].total_par)

# ============================================================================
# CUT LINE
# ============================================================================

func _apply_cut_line(rule: String) -> void:
	var standings = _get_standings()
	var cut_count: int = 0

	if rule == "top_50pct":
		cut_count = ceili(standings.size() / 2.0)
	elif rule == "top_40_ties":
		cut_count = 40

	if cut_count <= 0 or cut_count >= standings.size():
		return

	# Find the score at the cut position
	var cut_score = standings[mini(cut_count - 1, standings.size() - 1)].score_to_par

	# Include ties: all golfers at or better than cut_score advance
	_cut_golfer_ids.clear()
	_eliminated_ids.clear()

	for entry in standings:
		if entry.score_to_par <= cut_score:
			_cut_golfer_ids.append(entry.id)
		else:
			_eliminated_ids.append(entry.id)

	# Notify
	EventBus.tournament_cut_applied.emit(current_tournament_tier, _cut_golfer_ids, _eliminated_ids)

	if _leaderboard:
		_leaderboard.apply_cut_line(_cut_golfer_ids, _eliminated_ids)

	var cut_score_text = _format_score_diff(cut_score)
	EventBus.notify("Cut line at %s — %d golfers advance, %d eliminated" % [
		cut_score_text, _cut_golfer_ids.size(), _eliminated_ids.size()
	], "info")

	print("Cut applied: %d advance at %s, %d eliminated" % [
		_cut_golfer_ids.size(), cut_score_text, _eliminated_ids.size()
	])

# ============================================================================
# TOURNAMENT COMPLETION
# ============================================================================

func _complete_tournament() -> void:
	var tier_data = TournamentSystem.get_tier_data(current_tournament_tier)

	# Build final standings
	var standings = _get_standings()

	var winner_name = standings[0].name if not standings.is_empty() else "Unknown"
	var winning_score = standings[0].total_strokes if not standings.is_empty() else 0
	var course_par = TournamentSystem._get_course_par(GameManager.current_course)

	# Build all_entries array for results popup
	var all_entries: Array = []
	for s in standings:
		all_entries.append({
			"name": s.name,
			"total_strokes": s.total_strokes,
			"total_par": s.total_par,
			"score_to_par": s.score_to_par,
			"missed_cut": s.id in _eliminated_ids,
			"round_scores": _get_round_score_diffs(s.id),
		})

	# Calculate drama multiplier for spectator revenue
	var drama_multiplier = _calculate_drama_multiplier()

	tournament_results = {
		"winner_name": winner_name,
		"winning_score": winning_score,
		"par": course_par,
		"scores": standings.map(func(s): return s.total_strokes),
		"participant_count": _sim_field.size(),
		"prize_pool": tier_data.prize_pool,
		"all_entries": all_entries,
		"rounds_played": current_round,
		"total_rounds": total_rounds,
		"moments": _tournament_moments,
		"cut_golfers": _cut_golfer_ids.size(),
		"eliminated_golfers": _eliminated_ids.size(),
	}

	# Prize pool payout
	var prize_cost = tier_data.prize_pool
	if prize_cost > 0:
		GameManager.modify_money(-prize_cost)
		EventBus.log_transaction("Tournament prize pool payout", -prize_cost)

	# Revenue with drama multiplier
	var spectator_rev = int(tier_data.get("spectator_revenue", 0) * drama_multiplier)
	var sponsor_rev = tier_data.get("sponsorship_revenue", 0)
	var total_revenue = spectator_rev + sponsor_rev
	if total_revenue > 0:
		GameManager.modify_money(total_revenue)
		GameManager.daily_stats.tournament_revenue += total_revenue
		EventBus.log_transaction("Tournament revenue (spectators + sponsors)", total_revenue)

	tournament_results["spectator_revenue"] = spectator_rev
	tournament_results["sponsorship_revenue"] = sponsor_rev
	tournament_results["total_revenue"] = total_revenue
	tournament_results["drama_multiplier"] = drama_multiplier

	GameManager.modify_reputation(tier_data.reputation_reward)

	if _leaderboard:
		_leaderboard.show_final_results()

	last_tournament_end_day = GameManager.current_day
	var completed_tier = current_tournament_tier

	if _pre_tournament_speed >= 0:
		GameManager.current_speed = _pre_tournament_speed
		_pre_tournament_speed = -1

	# Emit moment notifications for any remaining
	_emit_moments(_tournament_moments)

	# Reset state
	current_tournament_tier = -1
	current_tournament_state = TournamentSystem.TournamentState.NONE
	current_round = 0
	total_rounds = 1
	_tournament_golfer_ids.clear()
	_tournament_scores.clear()
	_sim_field.clear()
	_round_scores.clear()
	_cumulative_scores.clear()
	_cut_golfer_ids.clear()
	_eliminated_ids.clear()
	_tournament_moments.clear()

	var score_diff = winning_score - course_par
	var score_text = _format_score_diff(score_diff)

	tournament_completed.emit(completed_tier, tournament_results)
	EventBus.tournament_completed.emit(completed_tier, tournament_results)
	EventBus.notify("Tournament complete! Winner: %s (%s)" % [winner_name, score_text], "success")

## Called when End Day is pressed during a tournament
func simulate_remaining_and_complete() -> void:
	if current_tournament_state != TournamentSystem.TournamentState.IN_PROGRESS:
		return

	# End current live round if active
	if _live_round_active:
		_end_current_day_round()

	# Simulate all remaining rounds
	while current_round < total_rounds:
		_play_round(current_round + 1)

	# Tournament should be complete after all rounds
	if current_tournament_state == TournamentSystem.TournamentState.IN_PROGRESS:
		_complete_tournament()

# ============================================================================
# STANDINGS & HELPERS
# ============================================================================

## Get active field (golfers who haven't been cut)
func _get_active_field() -> Array:
	if _cut_golfer_ids.is_empty():
		return _sim_field  # No cut yet, everyone plays
	return _sim_field.filter(func(sg): return sg.id in _cut_golfer_ids)

## Get current standings sorted by cumulative score-to-par
func _get_standings() -> Array:
	var standings: Array = []
	for sg in _sim_field:
		if not _cumulative_scores.has(sg.id):
			continue
		var cum = _cumulative_scores[sg.id]
		standings.append({
			"id": sg.id,
			"name": sg.name,
			"total_strokes": cum.total_strokes,
			"total_par": cum.total_par,
			"score_to_par": cum.total_strokes - cum.total_par,
		})

	standings.sort_custom(func(a, b): return a.score_to_par < b.score_to_par)
	return standings

## Get per-round score-to-par diffs for a golfer
func _get_round_score_diffs(sim_id: int) -> Array:
	var diffs: Array = []
	if _round_scores.has(sim_id):
		for rr in _round_scores[sim_id]:
			diffs.append(rr.total_strokes - rr.total_par)
	return diffs

## Find a SimGolfer by ID
func _find_sim_golfer(sim_id: int) -> TournamentSimulator.SimGolfer:
	for sg in _sim_field:
		if sg.id == sim_id:
			return sg
	return null

## Build map of which rounds play on which tournament day (0-based)
func _build_round_day_map(tier: int) -> Array:
	match tier:
		TournamentSystem.TournamentTier.LOCAL:
			return [[1]]              # Day 0: Round 1
		TournamentSystem.TournamentTier.REGIONAL:
			return [[1], [2]]         # Day 0: R1, Day 1: R2
		TournamentSystem.TournamentTier.NATIONAL:
			return [[1], [2], [3, 4]] # Day 0: R1, Day 1: R2, Day 2: R3+R4
		TournamentSystem.TournamentTier.CHAMPIONSHIP:
			return [[1], [2], [3], [4]] # Day 0-3: R1-R4
		_:
			return [[1]]

## Get rounds to play for a given tournament day (0-based)
func _get_rounds_for_day(tournament_day: int) -> Array:
	if tournament_day < 0 or tournament_day >= _round_day_map.size():
		return []
	return _round_day_map[tournament_day]

## Calculate drama multiplier based on tournament moments
func _calculate_drama_multiplier() -> float:
	var multiplier = 1.0
	for moment in _tournament_moments:
		match moment.type:
			"eagle":
				multiplier += 0.05
			"hole_in_one":
				multiplier += 0.10
			"albatross":
				multiplier += 0.15
			"lead_change":
				multiplier += 0.05
	return minf(multiplier, 1.5)

## Emit notifications for dramatic moments
func _emit_moments(moments: Array) -> void:
	for moment in moments:
		if moment.importance >= 2:
			EventBus.notify(moment.detail, "success")
		EventBus.tournament_moment.emit({
			"type": moment.type,
			"round": moment.round_number,
			"hole": moment.hole,
			"golfer_name": moment.golfer_name,
			"detail": moment.detail,
			"importance": moment.importance,
		})

## Format score-to-par difference
func _format_score_diff(diff: int) -> String:
	if diff == 0:
		return "E"
	elif diff > 0:
		return "+%d" % diff
	else:
		return "%d" % diff

## Format a standings entry
func _format_score(entry: Dictionary) -> String:
	return _format_score_diff(entry.get("score_to_par", 0))

# ============================================================================
# PUBLIC QUERY METHODS
# ============================================================================

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
		"current_round": current_round,
		"total_rounds": total_rounds,
		"days_remaining": tournament_end_day - GameManager.current_day + 1 if current_tournament_state == TournamentSystem.TournamentState.IN_PROGRESS else tournament_start_day - GameManager.current_day,
	}

func get_cooldown_remaining() -> int:
	var days_since = GameManager.current_day - last_tournament_end_day
	return max(0, TOURNAMENT_COOLDOWN - days_since)

func is_tournament_in_progress() -> bool:
	return current_tournament_state == TournamentSystem.TournamentState.IN_PROGRESS

func get_save_data() -> Dictionary:
	return {
		"current_tier": current_tournament_tier,
		"state": current_tournament_state,
		"start_day": tournament_start_day,
		"end_day": tournament_end_day,
		"last_end_day": last_tournament_end_day,
	}

func load_save_data(data: Dictionary) -> void:
	current_tournament_tier = data.get("current_tier", -1)
	var loaded_state = data.get("state", TournamentSystem.TournamentState.NONE)
	if loaded_state == TournamentSystem.TournamentState.IN_PROGRESS:
		current_tournament_state = TournamentSystem.TournamentState.NONE
		current_tournament_tier = -1
	else:
		current_tournament_state = loaded_state
	tournament_start_day = data.get("start_day", 0)
	tournament_end_day = data.get("end_day", 0)
	last_tournament_end_day = data.get("last_end_day", -100)
