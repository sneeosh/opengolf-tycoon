extends RefCounted
class_name StrokeIndexCalculator
## StrokeIndexCalculator - Derives stroke index (handicap allocation) from hole difficulty ratings.
##
## Stroke index ranks holes 1–N by difficulty (1 = hardest). For 10+ holes,
## odd indices go to front 9 and even to back 9 per standard golf convention.

## Calculate stroke indices for an array of HoleData.
## Returns {hole_number: stroke_index} mapping.
static func calculate(holes: Array) -> Dictionary:
	var open_holes: Array = []
	for hole in holes:
		if hole.is_open:
			open_holes.append(hole)

	if open_holes.is_empty():
		return {}

	# Sort by difficulty descending (hardest first), break ties by lower hole number
	var sorted_holes = open_holes.duplicate()
	sorted_holes.sort_custom(func(a, b):
		if abs(a.difficulty_rating - b.difficulty_rating) > 0.01:
			return a.difficulty_rating > b.difficulty_rating
		return a.hole_number < b.hole_number
	)

	# For 9 or fewer holes: simple sequential assignment
	if sorted_holes.size() <= 9:
		var result: Dictionary = {}
		for i in sorted_holes.size():
			result[sorted_holes[i].hole_number] = i + 1
		return result

	# For 10+ holes: interleave front/back nine
	# Front 9 (holes 1-9) get odd stroke indices: 1, 3, 5, 7, ...
	# Back 9 (holes 10+) get even stroke indices: 2, 4, 6, 8, ...
	var front_sorted: Array = []
	var back_sorted: Array = []
	for hole in sorted_holes:
		if hole.hole_number <= 9:
			front_sorted.append(hole)
		else:
			back_sorted.append(hole)

	var odd_slots: Array = []  # 1, 3, 5, 7, 9, 11, 13, 15, 17
	var even_slots: Array = []  # 2, 4, 6, 8, 10, 12, 14, 16, 18
	for i in range(1, sorted_holes.size() + 1):
		if i % 2 == 1:
			odd_slots.append(i)
		else:
			even_slots.append(i)

	var result: Dictionary = {}
	for i in front_sorted.size():
		if i < odd_slots.size():
			result[front_sorted[i].hole_number] = odd_slots[i]
		else:
			# More front holes than odd slots — use remaining even slots
			var overflow_idx = i - odd_slots.size()
			if overflow_idx + back_sorted.size() < even_slots.size():
				result[front_sorted[i].hole_number] = even_slots[overflow_idx + back_sorted.size()]

	for i in back_sorted.size():
		if i < even_slots.size():
			result[back_sorted[i].hole_number] = even_slots[i]
		else:
			# More back holes than even slots — use remaining odd slots
			var overflow_idx = i - even_slots.size()
			if overflow_idx + front_sorted.size() < odd_slots.size():
				result[back_sorted[i].hole_number] = odd_slots[overflow_idx + front_sorted.size()]

	return result

## Recalculate stroke indices for all holes in the current course and store on HoleData.
static func recalculate_for_course() -> void:
	if not GameManager.current_course:
		return
	var indices = calculate(GameManager.current_course.holes)
	for hole in GameManager.current_course.holes:
		hole.stroke_index = indices.get(hole.hole_number, 0)
