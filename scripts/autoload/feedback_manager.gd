extends Node
## FeedbackManager - Tracks aggregate golfer feedback for end-of-day summaries
##
## Listens to golfer_thought signals and maintains counts for daily satisfaction rating.

## Daily feedback counts (reset each day)
var daily_counts: Dictionary = {
	"positive": 0,
	"negative": 0,
	"neutral": 0,
}

## Track specific trigger counts for detailed feedback
var trigger_counts: Dictionary = {}

## Track needs-related complaints separately for actionable insights
var needs_complaints: Dictionary = {
	"tired": 0,
	"hungry": 0,
	"restroom": 0,
	"slow_pace": 0,
}

func _ready() -> void:
	EventBus.golfer_thought.connect(_on_golfer_thought)
	EventBus.day_changed.connect(_on_day_changed)
	print("FeedbackManager initialized")

func _on_golfer_thought(_golfer_id: int, trigger_type: int, sentiment: String) -> void:
	# Count by sentiment
	if sentiment in daily_counts:
		daily_counts[sentiment] += 1

	# Count by trigger type
	if trigger_type not in trigger_counts:
		trigger_counts[trigger_type] = 0
	trigger_counts[trigger_type] += 1

	# Track needs-related complaints for actionable feedback
	match trigger_type:
		FeedbackTriggers.TriggerType.TIRED:
			needs_complaints["tired"] += 1
		FeedbackTriggers.TriggerType.HUNGRY:
			needs_complaints["hungry"] += 1
		FeedbackTriggers.TriggerType.NEEDS_RESTROOM:
			needs_complaints["restroom"] += 1
		FeedbackTriggers.TriggerType.SLOW_PACE:
			needs_complaints["slow_pace"] += 1

func _on_day_changed(_new_day: int) -> void:
	reset_daily_stats()

## Reset stats for new day
func reset_daily_stats() -> void:
	daily_counts = {
		"positive": 0,
		"negative": 0,
		"neutral": 0,
	}
	trigger_counts.clear()
	needs_complaints = {
		"tired": 0,
		"hungry": 0,
		"restroom": 0,
		"slow_pace": 0,
	}

## Get overall satisfaction rating (0.0 to 1.0)
## Returns 0.5 if no feedback recorded
func get_satisfaction_rating() -> float:
	var total = daily_counts["positive"] + daily_counts["negative"]
	if total == 0:
		return 0.5  # Neutral if no feedback

	return float(daily_counts["positive"]) / float(total)

## Get total feedback count for the day
func get_total_count() -> int:
	return daily_counts["positive"] + daily_counts["negative"] + daily_counts["neutral"]

## Get the most common complaint (negative trigger)
func get_top_complaint() -> String:
	var worst_trigger: int = -1
	var worst_count: int = 0

	for trigger_type in trigger_counts:
		var sentiment = FeedbackTriggers.get_sentiment(trigger_type)
		if sentiment == "negative" and trigger_counts[trigger_type] > worst_count:
			worst_count = trigger_counts[trigger_type]
			worst_trigger = trigger_type

	if worst_trigger == -1:
		return ""

	# Return a representative message for this trigger
	return FeedbackTriggers.get_random_message(worst_trigger)

## Get the most common compliment (positive trigger)
func get_top_compliment() -> String:
	var best_trigger: int = -1
	var best_count: int = 0

	for trigger_type in trigger_counts:
		var sentiment = FeedbackTriggers.get_sentiment(trigger_type)
		if sentiment == "positive" and trigger_counts[trigger_type] > best_count:
			best_count = trigger_counts[trigger_type]
			best_trigger = trigger_type

	if best_trigger == -1:
		return ""

	return FeedbackTriggers.get_random_message(best_trigger)

## Get summary dictionary for end-of-day panel
func get_daily_summary() -> Dictionary:
	return {
		"satisfaction": get_satisfaction_rating(),
		"positive_count": daily_counts["positive"],
		"negative_count": daily_counts["negative"],
		"neutral_count": daily_counts["neutral"],
		"total_count": get_total_count(),
		"top_complaint": get_top_complaint(),
		"top_compliment": get_top_compliment(),
		"needs_complaints": needs_complaints.duplicate(),
	}

## Get the top unmet need (most complained about)
## Returns empty string if no needs complaints
func get_top_unmet_need() -> String:
	var worst_need: String = ""
	var worst_count: int = 0
	for need_name in needs_complaints:
		if needs_complaints[need_name] > worst_count:
			worst_count = needs_complaints[need_name]
			worst_need = need_name
	return worst_need

func _exit_tree() -> void:
	# Disconnect signals to prevent memory leaks on reload
	if EventBus.golfer_thought.is_connected(_on_golfer_thought):
		EventBus.golfer_thought.disconnect(_on_golfer_thought)
	if EventBus.day_changed.is_connected(_on_day_changed):
		EventBus.day_changed.disconnect(_on_day_changed)
