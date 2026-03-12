extends RefCounted
class_name CourseRatingSystem
## CourseRatingSystem - Calculates 1-5 star course rating and course difficulty
##
## Rating categories:
## - Condition (25%): Quality of terrain in play corridors (premium vs rough)
## - Design (15%): Variety of hole pars (has par 3s, 4s, 5s)
## - Value (30%): Green fee vs reputation (fair pricing)
## - Pace (20%): Ratio of bogeys (proxy for slow play)
## - Aesthetics (10%): Decorations, trees, and landscaping near holes
##
## Course Difficulty:
## - Average of all hole difficulty ratings (1-10 scale)
## - Slope Rating: How much harder course is for avg vs scratch golfer (55-155)
##
## Overall rating is weighted average: condition 25%, design 15%, value 30%, pace 20%, aesthetics 10%

## Calculate overall course rating (returns Dictionary with all ratings)
## entity_layer is optional — pass null to skip aesthetics (defaults to 2.5)
static func calculate_rating(
	terrain_grid,  # TerrainGrid
	course_data,   # GameManager.CourseData
	daily_stats,   # GameManager.DailyStatistics
	green_fee: int,
	reputation: float,
	entity_layer = null  # EntityLayer (optional)
) -> Dictionary:
	var ratings = {
		"condition": _calculate_condition_rating(terrain_grid, course_data),
		"design": _calculate_design_rating(course_data),
		"value": _calculate_value_rating(green_fee, reputation),
		"pace": _calculate_pace_rating(daily_stats),
		"aesthetics": _calculate_aesthetics_rating(entity_layer, course_data),
	}

	# Weighted average
	var overall = (
		ratings.condition * 0.25 +
		ratings.design * 0.15 +
		ratings.value * 0.30 +
		ratings.pace * 0.20 +
		ratings.aesthetics * 0.10
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

	# Good design has variety — base score starts low and rewards investment
	var variety_score = 1.5  # Low base — a single hole is not good design

	# Bonus for having par 3s
	if par_counts[3] > 0:
		variety_score += 0.75

	# Bonus for having par 5s
	if par_counts[5] > 0:
		variety_score += 0.75

	# Hole count is the biggest factor in design quality
	# 18 holes = full credit, fewer holes = significant penalty
	if open_holes >= 18:
		variety_score += 2.0   # Full 18-hole course — excellent design
	elif open_holes >= 9:
		variety_score += 1.5   # Full front nine — good design
	elif open_holes >= 6:
		variety_score += 0.75  # Decent number of holes
	elif open_holes >= 4:
		variety_score += 0.25  # Barely enough variety

	return clampf(variety_score, 1.0, 5.0)

## Value rating: total round cost vs reputation and hole count
## A $30/hole fee on an 18-hole course ($540 total) is fair at high reputation,
## but $30/hole on a 1-hole course ($30 total) should still feel overpriced
## because the "experience" is so short.
static func _calculate_value_rating(green_fee: int, reputation: float) -> float:
	# Total cost of a round = per-hole fee x hole count
	var hole_count = GameManager.get_open_hole_count()
	var total_round_cost = green_fee * max(hole_count, 1)

	# Fair total price scales with reputation AND hole count:
	# At 50 rep with 18 holes: fair = $100 * (18/18) = $100
	# At 50 rep with 1 hole: fair = $100 * max(1/18, 0.15) = $15
	# At 100 rep with 18 holes: fair = $200
	var hole_factor = clampf(float(hole_count) / 18.0, 0.15, 1.0)
	var fair_price = max(reputation * 2.0, 20.0) * hole_factor

	# Seasonal fee tolerance: peak-season golfers accept higher fees, off-season expects lower
	var fee_tolerance = SeasonSystem.get_fee_tolerance(GameManager.current_day, GameManager.current_theme)
	fair_price *= fee_tolerance

	var price_ratio = float(total_round_cost) / max(fair_price, 1.0)

	# Apply difficulty-based green fee sensitivity
	# Higher sensitivity makes overpricing hurt the value rating more
	var diff_mods := DifficultyPresets.get_modifiers(GameManager.current_difficulty)
	var sensitivity: float = diff_mods.get("green_fee_sensitivity", 1.0)
	var adjusted_ratio = 0.5 + (price_ratio - 0.5) * sensitivity

	# 0.5x fair price = 5 stars (great value)
	# 1.0x fair price = 3 stars (fair)
	# 2.0x fair price = 1 star (overpriced)
	var rating = 5.0 - (adjusted_ratio - 0.5) * 2.67
	return clampf(rating, 1.0, 5.0)

## Pace rating: based on bogeys_or_worse ratio (proxy for slow play)
## Marshals improve pace by keeping play moving
static func _calculate_pace_rating(daily_stats) -> float:
	if not daily_stats:
		return 3.0

	var total_scores = (
		daily_stats.birdies +
		daily_stats.pars +
		daily_stats.bogeys_or_worse +
		daily_stats.holes_in_one +
		daily_stats.eagles
	)

	if total_scores == 0:
		return 3.0  # Neutral if no data

	var bad_ratio = float(daily_stats.bogeys_or_worse) / float(total_scores)
	# 0% bad = 5 stars, 50%+ bad = 2 stars
	var base_rating = 5.0 - (bad_ratio * 6.0)

	# Walk distance penalty: long average walks between holes slow pace
	var avg_walk = RoutingOverlay.calculate_avg_walk_distance()
	var walk_penalty: float = 0.0
	if avg_walk > 60.0:
		walk_penalty = clampf((avg_walk - 60.0) * 0.033, 0.0, 1.0)  # Up to -1.0 star at 90+ tiles
	elif avg_walk > 40.0:
		walk_penalty = (avg_walk - 40.0) * 0.005  # Mild penalty 0-0.1

	# Apply marshal pace modifier (0.6-1.0 from staff_manager)
	# Without marshals (0.6) pace rating is reduced, with marshals (1.0) full rating
	var pace_mod = 1.0
	if GameManager.staff_manager:
		pace_mod = GameManager.staff_manager.get_pace_modifier()
	var rating = (base_rating - walk_penalty) * pace_mod

	return clampf(rating, 2.0, 5.0)

## Aesthetics rating: decorations, trees, and rocks near holes
## Scores each open hole based on nearby decorations within 8-tile radius of tee and green.
## Variety bonus for using different decoration types, theme bonus for matching decorations.
## Trees and rocks also contribute small amounts.
static func _calculate_aesthetics_rating(entity_layer, course_data) -> float:
	if not entity_layer or not course_data:
		return 2.5

	var holes = course_data.holes
	if holes.is_empty():
		return 2.5

	var open_count: int = 0
	var total_score: float = 0.0
	var search_radius: int = 8

	for hole in holes:
		if not hole.is_open:
			continue
		open_count += 1

		# Gather decorations near tee and green
		var tee_pos: Vector2i = hole.tee_position
		var green_pos: Vector2i = hole.green_position

		var tee_area_min = tee_pos - Vector2i(search_radius, search_radius)
		var tee_area_max = tee_pos + Vector2i(search_radius, search_radius)
		var green_area_min = green_pos - Vector2i(search_radius, search_radius)
		var green_area_max = green_pos + Vector2i(search_radius, search_radius)

		# Get decorations near tee and green (may overlap — deduplicate)
		var tee_decorations = entity_layer.get_decorations_in_area(tee_area_min, tee_area_max)
		var green_decorations = entity_layer.get_decorations_in_area(green_area_min, green_area_max)

		# Deduplicate by position
		var seen_positions: Dictionary = {}
		var all_decorations: Array = []
		for dec in tee_decorations + green_decorations:
			var pos_key = dec.grid_position
			if not seen_positions.has(pos_key):
				seen_positions[pos_key] = true
				all_decorations.append(dec)

		# Score decorations with diminishing returns per type
		var type_counts: Dictionary = {}
		var decoration_score: float = 0.0
		var unique_types: int = 0

		for dec in all_decorations:
			var dec_type = dec.decoration_type
			if not type_counts.has(dec_type):
				type_counts[dec_type] = 0
				unique_types += 1
			type_counts[dec_type] += 1

			var base_value = dec.aesthetics_value
			# Diminishing returns: value / (1 + 0.2 * same_type_count_nearby)
			var diminished = base_value / (1.0 + 0.2 * (type_counts[dec_type] - 1))

			# Theme bonus: 1.5x for theme-appropriate decorations
			if _is_theme_appropriate(dec):
				diminished *= 1.5

			decoration_score += diminished

		# Trees contribute 0.15 each, rocks 0.1 each
		var tee_trees = entity_layer.get_trees_in_area(tee_area_min, tee_area_max)
		var green_trees = entity_layer.get_trees_in_area(green_area_min, green_area_max)
		var tree_positions: Dictionary = {}
		for tree in tee_trees + green_trees:
			if not tree_positions.has(tree.grid_position):
				tree_positions[tree.grid_position] = true
				decoration_score += 0.15

		# Count rocks in area (rocks dict keyed by position)
		var all_rocks = entity_layer.get_all_rocks()
		for rock in all_rocks:
			var rpos = rock.grid_position
			if (rpos.x >= tee_area_min.x and rpos.x <= tee_area_max.x and
				rpos.y >= tee_area_min.y and rpos.y <= tee_area_max.y) or \
			   (rpos.x >= green_area_min.x and rpos.x <= green_area_max.x and
				rpos.y >= green_area_min.y and rpos.y <= green_area_max.y):
				decoration_score += 0.1

		# Variety bonus
		if unique_types >= 4:
			decoration_score += 0.5
		elif unique_types >= 2:
			decoration_score += 0.25

		# Cap per-hole contribution at 4.0 raw points
		decoration_score = minf(decoration_score, 4.0)

		# Map raw score to 1-5 star range
		# 0 points = 1 star, 2+ points = 5 stars
		var hole_rating = clampf(1.0 + decoration_score * 2.0, 1.0, 5.0)
		total_score += hole_rating

	if open_count == 0:
		return 2.5

	return clampf(total_score / float(open_count), 1.0, 5.0)

## Check if decoration matches current course theme
static func _is_theme_appropriate(decoration) -> bool:
	var theme_bonus = decoration.decoration_data.get("theme_bonus", [])
	if theme_bonus.is_empty():
		return false
	var current_theme_name = CourseTheme.Type.keys()[GameManager.current_theme] if GameManager.current_theme < CourseTheme.Type.size() else ""
	return current_theme_name in theme_bonus

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
