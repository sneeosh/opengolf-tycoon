extends RefCounted
class_name CourseRatingSystem
## CourseRatingSystem - Calculates 1-5 star course rating and course difficulty
##
## Rating categories:
## - Condition: Quality of terrain in play corridors (premium vs rough)
## - Design: Variety of hole pars (has par 3s, 4s, 5s)
## - Value: Green fee vs reputation (fair pricing)
## - Pace: Ratio of bogeys (proxy for slow play)
##
## Course Difficulty:
## - Average of all hole difficulty ratings (1-10 scale)
## - Slope Rating: How much harder course is for avg vs scratch golfer (55-155)
##
## Overall rating is weighted average: condition 30%, design 20%, value 30%, pace 20%

## Calculate overall course rating (returns Dictionary with all ratings)
static func calculate_rating(
	terrain_grid,  # TerrainGrid
	course_data,   # GameManager.CourseData
	daily_stats,   # GameManager.DailyStatistics
	green_fee: int,
	reputation: float
) -> Dictionary:
	var ratings = {
		"condition": _calculate_condition_rating(terrain_grid, course_data),
		"design": _calculate_design_rating(course_data),
		"value": _calculate_value_rating(green_fee, reputation),
		"pace": _calculate_pace_rating(daily_stats),
	}

	# Weighted average (condition and value matter most)
	var overall = (
		ratings.condition * 0.30 +
		ratings.design * 0.20 +
		ratings.value * 0.30 +
		ratings.pace * 0.20
	)
	ratings["overall"] = clampf(overall, 1.0, 5.0)
	ratings["stars"] = int(round(ratings.overall))  # For display

	# Calculate course difficulty and slope rating
	var difficulty_data = _calculate_course_difficulty(course_data)
	ratings["difficulty"] = difficulty_data.average
	ratings["slope"] = difficulty_data.slope
	ratings["course_rating"] = difficulty_data.course_rating

	return ratings

## Calculate average course difficulty from hole difficulties
static func _calculate_course_difficulty(course_data) -> Dictionary:
	var result = {"average": 5.0, "slope": 113, "course_rating": 72.0}

	if not course_data:
		return result

	var holes = course_data.holes
	if holes.is_empty():
		return result

	var total_difficulty: float = 0.0
	var total_par: int = 0
	var open_count: int = 0

	for hole in holes:
		if hole.is_open:
			total_difficulty += hole.difficulty_rating
			total_par += hole.par
			open_count += 1

	if open_count == 0:
		return result

	# Average difficulty (1-10 scale)
	var avg_difficulty = total_difficulty / float(open_count)

	# Slope rating (55-155, standard is 113)
	# Based on average difficulty: 5.0 difficulty = 113 slope
	# Each point above/below 5 adjusts slope by ~8 points
	var slope = 113 + int((avg_difficulty - 5.0) * 8.0)
	slope = clampi(slope, 55, 155)

	# Course rating (expected score for scratch golfer)
	# Based on total par adjusted by difficulty
	# Courses with more hazards/difficulty add strokes
	var difficulty_adjustment = (avg_difficulty - 5.0) * 0.15 * open_count
	var course_rating = total_par + difficulty_adjustment

	result.average = avg_difficulty
	result.slope = slope
	result.course_rating = course_rating

	return result

## Get prestige multiplier based on difficulty and quality
## High difficulty + high quality = more prestigious = more reputation
static func get_prestige_multiplier(course_rating: Dictionary) -> float:
	var difficulty = course_rating.get("difficulty", 5.0)
	var overall = course_rating.get("overall", 3.0)

	# Base multiplier of 1.0
	var multiplier = 1.0

	# Difficult courses (7+ difficulty) with good ratings (4+ stars) get prestige bonus
	if difficulty >= 7.0 and overall >= 4.0:
		multiplier += 0.5  # +50% reputation
	elif difficulty >= 6.0 and overall >= 3.5:
		multiplier += 0.25  # +25% reputation

	# Very high quality courses (5 stars) get additional bonus
	if overall >= 4.5:
		multiplier += 0.25

	# Low quality courses get penalty
	if overall < 2.0:
		multiplier *= 0.75

	return multiplier

## Get difficulty text description
static func get_difficulty_text(difficulty: float) -> String:
	if difficulty < 3.0:
		return "Easy"
	elif difficulty < 5.0:
		return "Moderate"
	elif difficulty < 7.0:
		return "Challenging"
	elif difficulty < 9.0:
		return "Difficult"
	else:
		return "Very Difficult"

## Get slope rating text description
static func get_slope_text(slope: int) -> String:
	if slope < 80:
		return "Beginner Friendly"
	elif slope < 100:
		return "Below Average"
	elif slope < 120:
		return "Average"
	elif slope < 140:
		return "Above Average"
	else:
		return "Championship"

## Condition rating: ratio of premium terrain in play corridors
static func _calculate_condition_rating(terrain_grid, course_data) -> float:
	if not terrain_grid or not course_data:
		return 2.5

	var holes = course_data.holes
	if holes.is_empty():
		return 2.5

	var premium_tiles: int = 0
	var total_tiles: int = 0

	for hole in holes:
		if not hole.is_open:
			continue

		var corridor = terrain_grid.get_tiles_in_corridor(
			hole.tee_position, hole.green_position, 12
		)

		for pos in corridor:
			total_tiles += 1
			var terrain = terrain_grid.get_tile(pos)
			# Premium terrain: fairway, green, tee box
			if terrain in [TerrainTypes.Type.GREEN, TerrainTypes.Type.FAIRWAY, TerrainTypes.Type.TEE_BOX]:
				premium_tiles += 1

	if total_tiles == 0:
		return 2.5

	var ratio = float(premium_tiles) / float(total_tiles)
	# 0% premium = 1 star, 60%+ premium = 5 stars
	var base_rating = clampf(1.0 + (ratio / 0.15), 1.0, 5.0)

	# Apply groundskeeper condition modifier (0.0-1.0 from staff_manager)
	# Poor condition (0.0) reduces rating by up to 50%, pristine (1.0) has no penalty
	var condition_mod = 1.0
	if GameManager.staff_manager:
		var course_condition = GameManager.staff_manager.course_condition
		condition_mod = 0.5 + (course_condition * 0.5)  # Range: 0.5 to 1.0
	return clampf(base_rating * condition_mod, 1.0, 5.0)

## Design rating: variety of hole pars
static func _calculate_design_rating(course_data) -> float:
	if not course_data:
		return 2.5

	var holes = course_data.holes
	if holes.is_empty():
		return 1.0

	# Count open holes by par
	var par_counts = {3: 0, 4: 0, 5: 0}
	var open_holes = 0

	for hole in holes:
		if hole.is_open:
			open_holes += 1
			if hole.par in par_counts:
				par_counts[hole.par] += 1

	if open_holes == 0:
		return 1.0

	# Good design has variety
	var variety_score = 2.0  # Base score

	# Bonus for having par 3s
	if par_counts[3] > 0:
		variety_score += 1.0

	# Bonus for having par 5s
	if par_counts[5] > 0:
		variety_score += 1.0

	# Bonus for having enough holes (9+ is a full front nine)
	if open_holes >= 9:
		variety_score += 1.0
	elif open_holes >= 4:
		variety_score += 0.5

	return clampf(variety_score, 1.0, 5.0)

## Value rating: green fee vs reputation
static func _calculate_value_rating(green_fee: int, reputation: float) -> float:
	# Fair price based on reputation: $2 per reputation point
	var fair_price = max(reputation * 2.0, 20.0)  # At least $20 is fair
	var price_ratio = float(green_fee) / fair_price

	# 0.5x fair price = 5 stars (great value)
	# 1.0x fair price = 3 stars (fair)
	# 2.0x fair price = 1 star (overpriced)
	var rating = 5.0 - (price_ratio - 0.5) * 2.67
	return clampf(rating, 1.0, 5.0)

## Pace rating: based on bogeys_or_worse ratio (proxy for slow play)
## Marshals improve pace by keeping play moving
static func _calculate_pace_rating(daily_stats) -> float:
	if not daily_stats:
		return 3.0

	var total_scores = (
		daily_stats.birdies +
		daily_stats.bogeys_or_worse +
		daily_stats.holes_in_one +
		daily_stats.eagles
	)

	if total_scores == 0:
		return 3.0  # Neutral if no data

	var bad_ratio = float(daily_stats.bogeys_or_worse) / float(total_scores)
	# 0% bad = 5 stars, 50%+ bad = 2 stars
	var base_rating = 5.0 - (bad_ratio * 6.0)

	# Apply marshal pace modifier (0.6-1.0 from staff_manager)
	# Without marshals (0.6) pace rating is reduced, with marshals (1.0) full rating
	var pace_mod = 1.0
	if GameManager.staff_manager:
		pace_mod = GameManager.staff_manager.get_pace_modifier()
	var rating = base_rating * pace_mod

	return clampf(rating, 2.0, 5.0)

## Get a text description of the rating
static func get_rating_text(stars: int) -> String:
	match stars:
		1:
			return "Poor"
		2:
			return "Below Average"
		3:
			return "Average"
		4:
			return "Good"
		5:
			return "Excellent"
		_:
			return "Unrated"

## Get star display string
static func get_star_display(overall: float) -> String:
	var full_stars = int(overall)
	var remainder = overall - full_stars
	var result = ""

	for i in range(full_stars):
		result += "*"

	if remainder >= 0.5 and full_stars < 5:
		result += "+"  # Half star indicator

	return result
