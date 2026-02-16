extends RefCounted
class_name FeedbackTriggers
## FeedbackTriggers - Defines all feedback trigger types and their messages
##
## This class provides static data for the feedback system. It maps game events
## to appropriate golfer reactions with randomized message selection.

enum TriggerType {
	HOLE_IN_ONE,
	EAGLE,
	BIRDIE,
	BOGEY_PLUS,
	OVERPRICED,
	GOOD_VALUE,
	SLOW_PACE,
	NICE_COURSE,
	HAZARD_WATER,
	HAZARD_BUNKER,
	GREAT_SHOT,
	BAD_LIE,
	TOO_FEW_HOLES,
}

## Trigger data: messages array and sentiment
const TRIGGERS: Dictionary = {
	TriggerType.HOLE_IN_ONE: {
		"messages": ["HOLE IN ONE!", "Unbelievable!", "Did that just happen?!"],
		"sentiment": "positive",
		"probability": 1.0,  # Always show for hole-in-one
	},
	TriggerType.EAGLE: {
		"messages": ["Eagle!", "What a hole!", "Incredible!"],
		"sentiment": "positive",
		"probability": 0.9,
	},
	TriggerType.BIRDIE: {
		"messages": ["Birdie!", "Nice!", "Great hole!"],
		"sentiment": "positive",
		"probability": 0.7,
	},
	TriggerType.BOGEY_PLUS: {
		"messages": ["Tough hole...", "Ugh!", "That was rough", "Could be better"],
		"sentiment": "negative",
		"probability": 0.5,
	},
	TriggerType.OVERPRICED: {
		"messages": ["Overpriced!", "Not worth it", "Too expensive", "Pricey..."],
		"sentiment": "negative",
		"probability": 0.6,
	},
	TriggerType.GOOD_VALUE: {
		"messages": ["Great value!", "Worth every penny", "Good deal!"],
		"sentiment": "positive",
		"probability": 0.5,
	},
	TriggerType.SLOW_PACE: {
		"messages": ["Slow play...", "C'mon!", "Waiting around", "Let's go!"],
		"sentiment": "negative",
		"probability": 0.7,
	},
	TriggerType.NICE_COURSE: {
		"messages": ["Nice course!", "I'll be back!", "Great layout", "Fun round!"],
		"sentiment": "positive",
		"probability": 0.6,
	},
	TriggerType.HAZARD_WATER: {
		"messages": ["Into the water!", "Splash!", "That's wet", "Need a new ball"],
		"sentiment": "negative",
		"probability": 0.8,
	},
	TriggerType.HAZARD_BUNKER: {
		"messages": ["Bunker!", "Sandy!", "Beach time", "In the trap"],
		"sentiment": "neutral",
		"probability": 0.6,
	},
	TriggerType.GREAT_SHOT: {
		"messages": ["Great shot!", "Perfect!", "Nailed it!", "Beauty!"],
		"sentiment": "positive",
		"probability": 0.4,
	},
	TriggerType.BAD_LIE: {
		"messages": ["Bad lie...", "Tough spot", "Hmm...", "Tricky"],
		"sentiment": "neutral",
		"probability": 0.4,
	},
	TriggerType.TOO_FEW_HOLES: {
		"messages": ["Too short!", "Only %d holes?", "Not a real course", "Barely got started"],
		"sentiment": "negative",
		"probability": 0.8,
	},
}

## Get a random message for a trigger type
static func get_random_message(trigger_type: TriggerType) -> String:
	var trigger_data = TRIGGERS.get(trigger_type, null)
	if trigger_data == null:
		return ""
	var messages: Array = trigger_data["messages"]
	return messages[randi() % messages.size()]

## Get the sentiment for a trigger type
static func get_sentiment(trigger_type: TriggerType) -> String:
	var trigger_data = TRIGGERS.get(trigger_type, null)
	if trigger_data == null:
		return "neutral"
	return trigger_data["sentiment"]

## Get the probability for a trigger type
static func get_probability(trigger_type: TriggerType) -> float:
	var trigger_data = TRIGGERS.get(trigger_type, null)
	if trigger_data == null:
		return 0.0
	return trigger_data["probability"]

## Check if trigger should fire based on probability
static func should_trigger(trigger_type: TriggerType) -> bool:
	return randf() < get_probability(trigger_type)

## Determine score-based trigger from strokes and par
static func get_score_trigger(strokes: int, par: int) -> TriggerType:
	if strokes == 1:
		return TriggerType.HOLE_IN_ONE
	var score_to_par = strokes - par
	if score_to_par <= -2:
		return TriggerType.EAGLE
	elif score_to_par == -1:
		return TriggerType.BIRDIE
	elif score_to_par >= 2:
		return TriggerType.BOGEY_PLUS
	# Par or bogey - no trigger
	return -1  # Invalid trigger

## Determine price trigger based on total round cost and reputation
static func get_price_trigger(total_round_cost: int, reputation: float) -> TriggerType:
	# Price tolerance: at 50 reputation with 18 holes, $100 is fair.
	# Scale by hole count so short courses feel overpriced at lower thresholds.
	var hole_count = GameManager.get_open_hole_count()
	var hole_factor = clampf(float(hole_count) / 18.0, 0.15, 1.0)
	var fair_price = reputation * 2.0 * hole_factor
	if total_round_cost > fair_price * 1.5:
		return TriggerType.OVERPRICED
	elif total_round_cost < fair_price * 0.6:
		return TriggerType.GOOD_VALUE
	return -1  # No trigger for fair pricing

## Determine course satisfaction trigger based on final score
static func get_course_trigger(total_strokes: int, total_par: int) -> TriggerType:
	var score_to_par = total_strokes - total_par
	# Happy if within 5 over par (realistic for casual golfers)
	if score_to_par <= 5:
		return TriggerType.NICE_COURSE
	return -1  # No trigger for poor scores (they already complained per-hole)
