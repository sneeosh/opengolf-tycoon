extends RefCounted
class_name CourseRatingSystem
## CourseRatingSystem - Calculates 1-5 star course rating
##
## Rating categories:
## - Condition: Quality of terrain in play corridors (premium vs rough)
## - Design: Variety of hole pars (has par 3s, 4s, 5s)
## - Value: Green fee vs reputation (fair pricing)
## - Pace: Ratio of bogeys (proxy for slow play)
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

	return ratings

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
	return clampf(1.0 + (ratio / 0.15), 1.0, 5.0)

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
	var rating = 5.0 - (bad_ratio * 6.0)
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
