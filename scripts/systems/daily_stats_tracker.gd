extends Node
class_name DailyStatsTracker
## DailyStatsTracker - Accumulates daily statistics for the end-of-day summary

var revenue_today: int = 0
var maintenance_today: int = 0
var golfers_served: int = 0
var golfers_spawned: int = 0
var notable_scores: Array[Dictionary] = []  # {golfer_name, hole_number, score_name, strokes, par}
var hole_scores: Dictionary = {}  # hole_number → Array of (strokes - par)
var round_start_hours: Dictionary = {}  # golfer_id → start_hour
var round_durations: Array[float] = []

func _ready() -> void:
	EventBus.connect("green_fee_paid", _on_green_fee_paid)
	EventBus.connect("golfer_spawned", _on_golfer_spawned)
	EventBus.connect("golfer_started_hole", _on_golfer_started_hole)
	EventBus.connect("golfer_finished_hole", _on_golfer_finished_hole)
	EventBus.connect("golfer_finished_round", _on_golfer_finished_round)
	EventBus.connect("day_changed", _on_day_changed)
	EventBus.connect("transaction_completed", _on_transaction_completed)

func get_daily_summary() -> Dictionary:
	var avg_pace := 0.0
	if not round_durations.is_empty():
		var total := 0.0
		for d in round_durations:
			total += d
		avg_pace = total / round_durations.size()

	var avg_score := 0.0
	var total_diffs := 0
	var count := 0
	for hole_num in hole_scores:
		for diff in hole_scores[hole_num]:
			total_diffs += diff
			count += 1
	if count > 0:
		avg_score = float(total_diffs) / count

	return {
		"revenue": revenue_today,
		"expenses": maintenance_today,
		"profit": revenue_today - maintenance_today,
		"golfers_served": golfers_served,
		"golfers_spawned": golfers_spawned,
		"notable_scores": notable_scores,
		"average_pace_of_play": avg_pace,
		"average_score_vs_par": avg_score,
	}

func reset() -> void:
	revenue_today = 0
	maintenance_today = 0
	golfers_served = 0
	golfers_spawned = 0
	notable_scores.clear()
	hole_scores.clear()
	round_start_hours.clear()
	round_durations.clear()

func _on_green_fee_paid(_golfer_id: int, _golfer_name: String, amount: int) -> void:
	revenue_today += amount

func _on_golfer_spawned(_golfer_id: int, _golfer_name: String) -> void:
	golfers_spawned += 1

func _on_golfer_started_hole(golfer_id: int, _hole_number: int) -> void:
	# Track round start time (first hole only)
	if not round_start_hours.has(golfer_id):
		round_start_hours[golfer_id] = GameManager.current_hour

func _on_golfer_finished_hole(_golfer_id: int, hole_number: int, strokes: int, par: int) -> void:
	var diff = strokes - par

	# Track hole scores
	if not hole_scores.has(hole_number):
		hole_scores[hole_number] = []
	hole_scores[hole_number].append(diff)

	# Track notable scores
	if diff <= -2 or strokes == 1:
		var score_name := ""
		if strokes == 1:
			score_name = "Hole-in-One"
		elif diff == -3:
			score_name = "Albatross"
		elif diff == -2:
			score_name = "Eagle"
		notable_scores.append({
			"hole_number": hole_number,
			"score_name": score_name,
			"strokes": strokes,
			"par": par,
		})

func _on_golfer_finished_round(golfer_id: int, _total_score: int) -> void:
	golfers_served += 1
	if round_start_hours.has(golfer_id):
		var duration = GameManager.current_hour - round_start_hours[golfer_id]
		if duration > 0.0:
			round_durations.append(duration)
		round_start_hours.erase(golfer_id)

func _on_transaction_completed(description: String, amount: int) -> void:
	# Track maintenance expenses (negative transactions on day change)
	if amount < 0 and description.begins_with("Daily"):
		maintenance_today += abs(amount)

func _on_day_changed(_new_day: int) -> void:
	reset()
