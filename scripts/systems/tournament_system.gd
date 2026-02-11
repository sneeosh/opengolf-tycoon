extends RefCounted
class_name TournamentSystem
## TournamentSystem - Manages golf tournaments on the course
##
## Tournament tiers have different requirements and rewards:
## - Local: 4+ holes, 2+ rating, small prize pool
## - Regional: 9+ holes, 3+ rating, medium prize pool
## - National: 18 holes, 4+ rating, large prize pool
## - Championship: 18 holes, 4.5+ rating, 6+ difficulty, huge prize pool

enum TournamentTier {
	LOCAL,       # Small local event
	REGIONAL,    # Regional competition
	NATIONAL,    # National-level event
	CHAMPIONSHIP # Prestigious championship
}

enum TournamentState {
	NONE,        # No tournament
	SCHEDULED,   # Tournament upcoming
	IN_PROGRESS, # Tournament happening today
	COMPLETED    # Tournament just finished
}

const TIER_DATA: Dictionary = {
	TournamentTier.LOCAL: {
		"name": "Local Tournament",
		"min_holes": 4,
		"min_rating": 2.0,
		"min_difficulty": 0.0,
		"min_yardage": 1500,
		"entry_cost": 500,       # Cost to host
		"prize_pool": 1000,      # Course pays out
		"participant_count": 12,
		"reputation_reward": 15,
		"duration_days": 1,
	},
	TournamentTier.REGIONAL: {
		"name": "Regional Championship",
		"min_holes": 9,
		"min_rating": 3.0,
		"min_difficulty": 4.0,
		"min_yardage": 3000,
		"entry_cost": 2000,
		"prize_pool": 5000,
		"participant_count": 24,
		"reputation_reward": 40,
		"duration_days": 2,
	},
	TournamentTier.NATIONAL: {
		"name": "National Open",
		"min_holes": 18,
		"min_rating": 4.0,
		"min_difficulty": 5.0,
		"min_yardage": 6000,
		"entry_cost": 10000,
		"prize_pool": 25000,
		"participant_count": 48,
		"reputation_reward": 100,
		"duration_days": 3,
	},
	TournamentTier.CHAMPIONSHIP: {
		"name": "Grand Championship",
		"min_holes": 18,
		"min_rating": 4.5,
		"min_difficulty": 6.0,
		"min_yardage": 6500,
		"entry_cost": 50000,
		"prize_pool": 100000,
		"participant_count": 72,
		"reputation_reward": 300,
		"duration_days": 4,
	},
}

## Check if course qualifies for a tournament tier
static func check_qualification(tier: TournamentTier, course_data, course_rating: Dictionary) -> Dictionary:
	var requirements = TIER_DATA[tier]
	var result = {
		"qualified": true,
		"missing": []
	}

	if not course_data:
		result.qualified = false
		result.missing.append("No course data")
		return result

	# Count open holes and total yardage
	var open_holes = 0
	var total_yardage = 0
	for hole in course_data.holes:
		if hole.is_open:
			open_holes += 1
			total_yardage += hole.yardage

	# Check hole count
	if open_holes < requirements.min_holes:
		result.qualified = false
		result.missing.append("Need %d holes (have %d)" % [requirements.min_holes, open_holes])

	# Check course rating
	var overall_rating = course_rating.get("overall", 0.0)
	if overall_rating < requirements.min_rating:
		result.qualified = false
		result.missing.append("Need %.1f star rating (have %.1f)" % [requirements.min_rating, overall_rating])

	# Check difficulty
	var difficulty = course_rating.get("difficulty", 0.0)
	if difficulty < requirements.min_difficulty:
		result.qualified = false
		result.missing.append("Need %.1f difficulty (have %.1f)" % [requirements.min_difficulty, difficulty])

	# Check yardage
	if total_yardage < requirements.min_yardage:
		result.qualified = false
		result.missing.append("Need %d yards (have %d)" % [requirements.min_yardage, total_yardage])

	return result

## Get all tiers the course qualifies for
static func get_qualified_tiers(course_data, course_rating: Dictionary) -> Array:
	var qualified = []
	for tier in TIER_DATA.keys():
		var check = check_qualification(tier, course_data, course_rating)
		if check.qualified:
			qualified.append(tier)
	return qualified

## Get tier name
static func get_tier_name(tier: TournamentTier) -> String:
	return TIER_DATA.get(tier, {}).get("name", "Unknown")

## Get tier data
static func get_tier_data(tier: TournamentTier) -> Dictionary:
	return TIER_DATA.get(tier, {})

## Calculate tournament results - returns winner info and scores
static func generate_tournament_results(tier: TournamentTier, course_data, course_rating: Dictionary) -> Dictionary:
	var tier_data = TIER_DATA[tier]
	var participant_count = tier_data.participant_count
	var course_par = _get_course_par(course_data)
	var difficulty = course_rating.get("difficulty", 5.0)

	# Generate scores for all participants
	var scores = []
	for i in range(participant_count):
		# Better players (lower index) tend to score better
		var skill_factor = 1.0 - (float(i) / participant_count * 0.5)
		# Difficulty makes scores higher
		var difficulty_factor = 1.0 + (difficulty - 5.0) * 0.02
		# Random variation
		var variation = randf_range(-3, 5)

		var score = int(course_par * difficulty_factor + variation - skill_factor * 4)
		scores.append(score)

	scores.sort()

	# Generate winner name
	var winner_prefixes = ["Tiger", "Jack", "Arnold", "Ben", "Bobby", "Phil", "Rory", "Jordan"]
	var winner_suffixes = ["Woods", "Nicklaus", "Palmer", "Hogan", "Jones", "Mickelson", "McIlroy", "Spieth"]
	var winner_name = winner_prefixes[randi() % winner_prefixes.size()] + " " + winner_suffixes[randi() % winner_suffixes.size()]

	return {
		"winner_name": winner_name,
		"winning_score": scores[0],
		"par": course_par,
		"scores": scores,
		"participant_count": participant_count,
		"prize_pool": tier_data.prize_pool,
	}

static func _get_course_par(course_data) -> int:
	if not course_data:
		return 72
	var total_par = 0
	for hole in course_data.holes:
		if hole.is_open:
			total_par += hole.par
	return max(total_par, 18)

## Get description text for a tier
static func get_tier_description(tier: TournamentTier) -> String:
	var data = TIER_DATA[tier]
	return "%s\nRequires: %d holes, %.1f★ rating, %d yards\nEntry: $%d | Prize Pool: $%d\nReward: +%d reputation" % [
		data.name,
		data.min_holes,
		data.min_rating,
		data.min_yardage,
		data.entry_cost,
		data.prize_pool,
		data.reputation_reward
	]
