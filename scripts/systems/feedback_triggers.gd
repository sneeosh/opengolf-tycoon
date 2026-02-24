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
	SHANK,
	TIRED,
	HUNGRY,
	NEEDS_RESTROOM,
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
		"messages": ["Too short!", "Only a few holes?", "Not a real course", "Barely got started"],
		"sentiment": "negative",
		"probability": 0.8,
	},
	TriggerType.SHANK: {
		"messages": ["D'oh! Shank!", "Shank city!!", "Hosel rocket!", "Yikes!! Shank!"],
		"sentiment": "negative",
		"probability": 1.0,  # Always show — shanks are rare enough already
	},
	TriggerType.TIRED: {
		"messages": ["Getting tired...", "Need a break", "Legs are heavy", "Long walk..."],
		"sentiment": "negative",
		"probability": 0.7,
	},
	TriggerType.HUNGRY: {
		"messages": ["Getting hungry...", "Need a snack", "Where's the snack bar?", "Starving!"],
		"sentiment": "negative",
		"probability": 0.6,
	},
	TriggerType.NEEDS_RESTROOM: {
		"messages": ["Need a restroom!", "Where's the restroom?", "Nature calls...", "Bathroom break?"],
		"sentiment": "negative",
		"probability": 0.7,
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

## Expected strokes over par per hole, based on average skill (0.0-1.0).
## Used as a rough handicap so golfers judge performance against their own ability.
static func get_expected_over_par(avg_skill: float) -> float:
	return (1.0 - avg_skill) * 3.0

## Determine score-based trigger from strokes, par, and golfer skill.
## Positive triggers (hole-in-one/eagle/birdie) are unconditional — great golf is always exciting.
## Negative trigger (BOGEY_PLUS) only fires when significantly worse than personal expectation.
static func get_score_trigger(strokes: int, par: int, avg_skill: float = 0.5) -> TriggerType:
	var classification = GolfRules.classify_score(strokes, par)
	match classification:
		"hole_in_one": return TriggerType.HOLE_IN_ONE
		"eagle": return TriggerType.EAGLE
		"birdie": return TriggerType.BIRDIE
	# Negative trigger only if 2+ strokes worse than personal expectation
	var expected = par + get_expected_over_par(avg_skill)
	if strokes >= expected + 2.0:
		return TriggerType.BOGEY_PLUS
	return -1  # At or near expected — no trigger

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

## Determine course satisfaction trigger based on final score vs personal expectation.
## Golfers are happy if they scored within ~3 strokes of their expected total.
static func get_course_trigger(total_strokes: int, total_par: int,
		avg_skill: float = 0.5, hole_count: int = 18) -> TriggerType:
	var expected_total = total_par + hole_count * get_expected_over_par(avg_skill)
	if total_strokes <= expected_total + 3.0:
		return TriggerType.NICE_COURSE
	return -1  # No trigger — scored well below expectation (already complained per-hole)
