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
	incidents.clear()
	visits.clear()
	returning_today = 0
	service_visits = 0
	service_revenue = 0
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

# Diagnostic records are independent of randomized thought-bubble display.
var incidents: Array = []
var visits: Array = []
var customers: Array = []
var returning_today: int = 0
var service_visits: int = 0
var service_revenue: int = 0
var guest_sequence: int = 0

func next_guest_key() -> String:
	guest_sequence += 1
	return "guest-%d" % guest_sequence

func record_incident(golfer, trigger: int) -> void:
	if FeedbackTriggers.get_sentiment(trigger) != "negative": return
	var hole: int = golfer.current_hole + 1
	for item in incidents:
		if item.golfer_id == golfer.golfer_id and item.hole == hole and item.trigger == trigger: return
	var position: Vector2i = GameManager.terrain_grid.screen_to_grid(golfer.global_position) if GameManager.terrain_grid else Vector2i.ZERO
	incidents.append({"golfer_id":golfer.golfer_id,"name":golfer.golfer_name,"hole":hole,"trigger":trigger,"x":position.x,"y":position.y,"hour":GameManager.current_hour,"needs":golfer.needs.to_dict()})
	if incidents.size() > 500: incidents.pop_front()

func incident_title(trigger: int) -> String:
	match trigger:
		FeedbackTriggers.TriggerType.SLOW_PACE: return "Traffic delay"
		FeedbackTriggers.TriggerType.TIRED: return "Needs a rest"
		FeedbackTriggers.TriggerType.HUNGRY: return "Needs food"
		FeedbackTriggers.TriggerType.NEEDS_RESTROOM: return "Needs a restroom"
		FeedbackTriggers.TriggerType.OVERPRICED: return "Poor value"
		FeedbackTriggers.TriggerType.HAZARD_WATER: return "Lost a ball in water"
		FeedbackTriggers.TriggerType.SHANK: return "Mishit"
		FeedbackTriggers.TriggerType.BOGEY_PLUS: return "Difficult scoring"
	return "Disappointing round"

func incident_guidance(trigger: int) -> String:
	match trigger:
		FeedbackTriggers.TriggerType.SLOW_PACE: return "Groups ahead blocked play. Reduce tee-time frequency or improve the congested landing area. Normal turns within a group do not count as traffic."
		FeedbackTriggers.TriggerType.TIRED: return "Add reachable seating beside the route. Rest restores energy and helps golfers keep walking comfortably."
		FeedbackTriggers.TriggerType.HUNGRY: return "Add a snack bar or coffee house beside the route. Food restores hunger and earns service income."
		FeedbackTriggers.TriggerType.NEEDS_RESTROOM: return "Add a restroom beside the route to restore comfort."
		FeedbackTriggers.TriggerType.OVERPRICED: return "The fee exceeded this course's fair-price reference. Poor value reduces return intent."
	return "Inspect this hole's scores and hazards. An occasional bad shot does not by itself mean the design needs changing."

func get_hotspots() -> Array:
	var groups := {}
	for item in incidents:
		var key := "%d:%d" % [item.hole,item.trigger]
		if not groups.has(key):
			groups[key] = item.duplicate(true)
			groups[key]["count"] = 0
		groups[key].count += 1
	var result: Array = groups.values()
	result.sort_custom(func(a,b):
		var actionable := [FeedbackTriggers.TriggerType.SLOW_PACE,FeedbackTriggers.TriggerType.TIRED,FeedbackTriggers.TriggerType.HUNGRY,FeedbackTriggers.TriggerType.NEEDS_RESTROOM,FeedbackTriggers.TriggerType.OVERPRICED]
		var a_priority: int = 1000 if int(a.trigger) in actionable else 0
		var b_priority: int = 1000 if int(b.trigger) in actionable else 0
		return a_priority + int(a.count) > b_priority + int(b.count)
	)
	return result.slice(0,3)

func guest_incident_text(id: int) -> String:
	var counts := {}
	var worst: Dictionary = {}
	var most := 0
	for item in incidents:
		if item.golfer_id != id: continue
		counts[item.trigger] = counts.get(item.trigger,0) + 1
		if counts[item.trigger] > most:
			most = counts[item.trigger]
			worst = item
	if worst.is_empty(): return "No complaints recorded this visit."
	return "%s (%d reports), including hole %d (%d,%d). %s" % [incident_title(worst.trigger),most,worst.hole,worst.x,worst.y,incident_guidance(worst.trigger)]

func record_visit(golfer) -> void:
	var key: String = golfer.guest_key
	for item in visits:
		if item.key == key: return
	var holes: int = maxi(golfer._round_total_holes, 1)
	var fair := CourseEconomy.fair_round_price(GameManager.reputation,holes,GameManager.current_day,GameManager.current_theme)
	var value := clampf(fair / maxf(golfer.paid_round_fee,1),0.0,1.0)
	var score := clampf(golfer.needs.get_overall_satisfaction()*.5 + golfer.current_mood*.25 + value*.25,0.0,1.0)
	var intent := clampf(score * .9 + value * .1, .05, .95)
	var review := {"key":key,"name":golfer.golfer_name,"score":score,"return_intent":intent,"wait_seconds":golfer.traffic_wait_seconds,"services":golfer.amenities_used,"needs":golfer.needs.to_dict(),"fee":golfer.paid_round_fee}
	visits.append(review)
	var profile := {"key":key,"name":golfer.golfer_name,"tier":golfer.golfer_tier,"last_day":GameManager.current_day,"intent":intent,"driving_skill":golfer.driving_skill,"accuracy_skill":golfer.accuracy_skill,"putting_skill":golfer.putting_skill,"recovery_skill":golfer.recovery_skill,"patience":golfer.patience,"aggression":golfer.aggression,"miss_tendency":golfer.miss_tendency}
	for i in range(customers.size()-1,-1,-1):
		if customers[i].key == key: customers.remove_at(i)
	customers.append(profile)
	if customers.size() > 200: customers.pop_front()

func take_returning_guest() -> Dictionary:
	var eligible: Array = []
	for customer in customers:
		if int(customer.last_day) < GameManager.current_day - 1: eligible.append(customer)
	if eligible.is_empty(): return {}
	var selected: Dictionary = eligible[randi() % eligible.size()]
	if randf() > float(selected.intent) * .5: return {}
	selected.last_day = GameManager.current_day
	returning_today += 1
	return selected.duplicate(true)

func visit_summary() -> Dictionary:
	var score := 0.0
	var intent := 0.0
	var wait := 0.0
	for visit in visits:
		score += visit.score
		intent += visit.return_intent
		wait += visit.wait_seconds
	var count := visits.size()
	return {"reviews":count,"satisfaction":score/maxi(count,1),"return_intent":intent/maxi(count,1),"traffic_minutes":wait/maxi(count,1)/60.0,"returning":returning_today,"service_visits":service_visits,"service_revenue":service_revenue,"complaints":incidents.size()}

func serialize_experience() -> Dictionary:
	return {"guest_sequence":guest_sequence,"incidents":incidents.duplicate(true),"visits":visits.duplicate(true),"customers":customers.duplicate(true),"returning_today":returning_today,"service_visits":service_visits,"service_revenue":service_revenue}

func restore_experience(data: Dictionary) -> void:
	guest_sequence = int(data.get("guest_sequence",0))
	incidents = data.get("incidents", []).duplicate(true)
	visits = data.get("visits", []).duplicate(true)
	customers = data.get("customers", []).duplicate(true)
	returning_today = int(data.get("returning_today", 0))
	service_visits = int(data.get("service_visits", 0))
	service_revenue = int(data.get("service_revenue", 0))

func recent_experience() -> Dictionary:
	var history: Array = GameManager.daily_history.slice(-3)
	var reviews := 0
	var weighted := 0.0
	var profit := 0.0
	for day in history:
		var experience: Dictionary = day.get("guest_experience",{})
		var count: int = int(experience.get("reviews",0))
		reviews += count
		weighted += float(experience.get("satisfaction",0.0)) * count
		profit += float(day.get("profit",0))
	return {"days":history.size(),"reviews":reviews,"satisfaction":weighted/maxi(reviews,1),"profit":profit/maxi(history.size(),1)}
