extends RefCounted
class_name ShotSimulator
## ShotSimulator - Headless hole-level simulation for tournament End Day fast-forward.
## Uses gaussian distributions around expected scores per hole — no scene tree dependency.

## Simulate remaining holes for a golfer and return final totals.
## golfer_data: {total_strokes, total_par, current_hole, skill}
## course_data: GameManager.CourseData with holes array
## Returns: {total_strokes, total_par, holes_played}
static func simulate_remaining_holes(golfer_data: Dictionary, course_data, difficulty: float) -> Dictionary:
	var total_strokes: int = golfer_data.get("total_strokes", 0)
	var total_par: int = golfer_data.get("total_par", 0)
	var current_hole: int = golfer_data.get("current_hole", 0)
	var skill: float = golfer_data.get("skill", 0.5)
	var holes_played: int = 0

	for i in range(current_hole, course_data.holes.size()):
		var hole = course_data.holes[i]
		if not hole.is_open:
			continue
		var strokes = simulate_hole(hole.par, difficulty, skill)
		total_strokes += strokes
		total_par += hole.par
		holes_played += 1

	return {
		"total_strokes": total_strokes,
		"total_par": total_par,
		"holes_played": holes_played,
	}

## Simulate a single hole. Returns number of strokes.
## Expected strokes = par + (1 - skill) * 2.0 - 0.5
## Pros (skill ~0.85-0.95) average slightly under par.
## Beginners (skill ~0.3-0.5) average 1-2 over par.
static func simulate_hole(par: int, difficulty: float, skill: float) -> int:
	var expected = par + (1.0 - skill) * 2.0 - 0.5
	# Difficulty adds a fraction of a stroke per hole
	expected += difficulty * 0.1
	# Gaussian noise — std dev scales with skill gap
	var noise = _gaussian_random() * (1.0 - skill) * 1.5
	var strokes = int(round(expected + noise))
	# Clamp to reasonable range
	return clampi(strokes, 1, par + 4)

## Gaussian random using Central Limit Theorem (sum of 4 uniform randoms).
## Returns approximately N(0, 1). Mean=2.0, stddev=sqrt(4/12)≈0.577
static func _gaussian_random() -> float:
	var sum = 0.0
	for i in range(4):
		sum += randf()
	return (sum - 2.0) / 0.577  # Normalize to approx N(0,1)
