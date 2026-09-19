extends RefCounted
class_name TerrainBrush
## A continuous sequence of grid stamps, independent of mouse-event frequency.
static func centers(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	var span := to - from
	var steps := maxi(absi(span.x), absi(span.y))
	if steps == 0: return [to]
	for i in range(steps + 1):
		var p := Vector2i((Vector2(from).lerp(Vector2(to), float(i) / steps)).round())
		if points.is_empty() or points[-1] != p: points.append(p)
	return points

static func offsets(diameter: int, round_shape: bool = true) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var radius := (diameter - 1) / 2
	for x in range(-radius, radius + 1):
		for y in range(-radius, radius + 1):
			if not round_shape or x*x + y*y <= radius*radius + radius*.5:
				result.append(Vector2i(x, y))
	return result
