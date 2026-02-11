extends RefCounted
class_name GolferTier
## GolferTier - Defines golfer skill tiers and their characteristics
##
## Four tiers: Beginner, Casual, Serious, Pro
## Each tier has different skill ranges, expectations, and reputation gains.

enum Tier {
	BEGINNER,   # Learning the game
	CASUAL,     # Plays occasionally for fun
	SERIOUS,    # Regular golfer, wants challenge
	PRO,        # Expert, very high standards
}

const TIER_DATA: Dictionary = {
	Tier.BEGINNER: {
		"name": "Beginner",
		"skill_range": [0.3, 0.5],
		"spending_modifier": 0.7,        # Prefers budget courses
		"expectation_tolerance": 0.3,    # Very forgiving
		"min_course_rating": 1.0,        # Will play anywhere
		"reputation_gain": 1,            # Low reputation boost
		"spawn_weight_base": 0.35,       # Common at budget courses
	},
	Tier.CASUAL: {
		"name": "Casual",
		"skill_range": [0.5, 0.7],
		"spending_modifier": 1.0,
		"expectation_tolerance": 0.2,
		"min_course_rating": 2.0,
		"reputation_gain": 2,
		"spawn_weight_base": 0.40,
	},
	Tier.SERIOUS: {
		"name": "Serious",
		"skill_range": [0.7, 0.85],
		"spending_modifier": 1.5,        # Willing to pay more
		"expectation_tolerance": 0.1,    # Less forgiving
		"min_course_rating": 3.0,        # Wants decent course
		"reputation_gain": 4,
		"spawn_weight_base": 0.20,
	},
	Tier.PRO: {
		"name": "Pro",
		"skill_range": [0.85, 0.98],
		"spending_modifier": 2.0,        # Expects premium
		"expectation_tolerance": 0.05,   # Very demanding
		"min_course_rating": 4.0,        # Only plays quality courses
		"reputation_gain": 10,           # Big reputation boost
		"spawn_weight_base": 0.05,       # Rare
	},
}

## Select a tier based on course rating, green fee, and reputation
static func select_tier(course_rating: float, green_fee: int, reputation: float) -> Tier:
	var weights = _calculate_tier_weights(course_rating, green_fee, reputation)
	return _weighted_random_tier(weights)

static func _calculate_tier_weights(rating: float, fee: int, reputation: float) -> Dictionary:
	var weights: Dictionary = {}

	for tier in TIER_DATA.keys():
		var data = TIER_DATA[tier]
		var weight: float = data.spawn_weight_base

		# Rating filter: tiers won't spawn if course rating is too low
		if rating < data.min_course_rating:
			weight *= 0.1  # Drastically reduce, don't eliminate

		# High fees attract serious/pro, repel beginners
		var spending_mod: float = data.spending_modifier
		var fee_factor: float = float(fee) / 50.0  # Normalize around $50
		if fee_factor > spending_mod * 1.5:
			weight *= 0.3  # Too expensive for this tier
		elif fee_factor < spending_mod * 0.5:
			weight *= 1.5  # Great value for this tier

		# High reputation attracts better players
		if tier == Tier.PRO and reputation < 70:
			weight *= 0.1  # Pros don't come to unknown courses
		elif tier == Tier.SERIOUS and reputation < 50:
			weight *= 0.5

		weights[tier] = weight

	return weights

static func _weighted_random_tier(weights: Dictionary) -> Tier:
	var total: float = 0.0
	for w in weights.values():
		total += w

	if total <= 0:
		return Tier.CASUAL  # Fallback

	var roll = randf() * total
	var cumulative: float = 0.0
	for tier in weights.keys():
		cumulative += weights[tier]
		if roll <= cumulative:
			return tier

	return Tier.CASUAL  # Fallback

## Generate skill values for a tier
static func generate_skills(tier: Tier) -> Dictionary:
	var data = TIER_DATA[tier]
	var range_low: float = data.skill_range[0]
	var range_high: float = data.skill_range[1]

	return {
		"driving": randf_range(range_low, range_high),
		"accuracy": randf_range(range_low, range_high),
		"putting": randf_range(range_low, range_high),
		"recovery": randf_range(range_low, range_high),
	}

## Get tier name
static func get_tier_name(tier: Tier) -> String:
	return TIER_DATA.get(tier, {}).get("name", "Unknown")

## Get reputation gain for a tier
static func get_reputation_gain(tier: Tier) -> int:
	return TIER_DATA.get(tier, {}).get("reputation_gain", 2)

## Get tier-appropriate name prefix
static func get_name_prefix(tier: Tier) -> String:
	match tier:
		Tier.BEGINNER:
			var prefixes = ["Newbie", "Rookie", "First-timer"]
			return prefixes[randi() % prefixes.size()]
		Tier.CASUAL:
			var prefixes = ["Weekend", "Casual"]
			return prefixes[randi() % prefixes.size()]
		Tier.SERIOUS:
			var prefixes = ["Avid", "Regular", "Dedicated"]
			return prefixes[randi() % prefixes.size()]
		Tier.PRO:
			var prefixes = ["Pro", "Champion", "Star"]
			return prefixes[randi() % prefixes.size()]
	return ""

## Get personality traits based on tier
static func get_personality(tier: Tier) -> Dictionary:
	match tier:
		Tier.BEGINNER:
			return {
				"aggression": randf_range(0.2, 0.4),  # Conservative
				"patience": randf_range(0.6, 0.9),    # Patient
			}
		Tier.CASUAL:
			return {
				"aggression": randf_range(0.3, 0.6),
				"patience": randf_range(0.4, 0.7),
			}
		Tier.SERIOUS:
			return {
				"aggression": randf_range(0.5, 0.7),
				"patience": randf_range(0.3, 0.6),
			}
		Tier.PRO:
			return {
				"aggression": randf_range(0.6, 0.9),  # Confident
				"patience": randf_range(0.2, 0.5),    # Expects fast pace
			}
	return {"aggression": 0.5, "patience": 0.5}

## Get price tolerance modifier for feedback
static func get_price_tolerance(tier: Tier) -> float:
	return TIER_DATA.get(tier, {}).get("expectation_tolerance", 0.2)
