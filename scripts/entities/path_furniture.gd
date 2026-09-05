extends Node2D
class_name PathFurniture
## Ground-plane furniture shared by the placed object and its placement ghost.

const EDGE_ORDER := [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]
const SMALL_FIXTURES := ["park_bench", "course_signage", "waste_bin", "ball_washer", "bird_bath"]
var kind := "park_bench"
var facing := Vector2i.DOWN

static func has_art(type: String) -> bool:
	return type in ["park_bench", "course_signage", "waste_bin", "ball_washer"]

static func layout(grid: TerrainGrid, pos: Vector2i, type: String) -> Dictionary:
	var result := {"offset": Vector2.ZERO, "facing": Vector2i.DOWN}
	if not grid or type not in SMALL_FIXTURES:
		return result
	if grid.get_tile(pos) == TerrainTypes.Type.PATH:
		# Stay inside the selected tile, along an exposed edge. Never put a
		# fixture against a neighboring path tile, into water, or off the map.
		for side in EDGE_ORDER:
			var neighbor: Vector2i = pos + side
			if grid.is_valid_position(neighbor) and grid.get_tile(neighbor) in [
				TerrainTypes.Type.GRASS, TerrainTypes.Type.ROUGH,
				TerrainTypes.Type.HEAVY_ROUGH, TerrainTypes.Type.FAIRWAY,
				TerrainTypes.Type.FLOWER_BED, TerrainTypes.Type.GREEN,
				TerrainTypes.Type.TEE_BOX]:
				result.offset = Vector2(side.x * 23.0, side.y * 10.0)
				result.facing = -side
				return result
	else:
		# Furniture on the verge faces the adjacent walk without moving tiles.
		for side in EDGE_ORDER:
			if grid.get_tile(pos + side) == TerrainTypes.Type.PATH:
				result.facing = side
				return result
	return result # A plaza/intersection has no exposed edge: retain its anchor.

func _draw() -> void:
	draw_item(self, kind, facing)

static func _color(hex: String, alpha: float) -> Color:
	var c := Color(hex)
	c.a *= alpha
	return c

static func _p(x: float, y: float, height: float, front: Vector2i) -> Vector2:
	var along := Vector2.RIGHT if front.y != 0 else Vector2(0, 0.5)
	return along * x + Vector2(front.x, front.y * 0.5) * y + Vector2(0, -height)

static func _board(canvas: CanvasItem, front: Vector2i, y: float, z: float, alpha: float) -> void:
	var a := _p(-18, y, z, front)
	var b := _p(18, y, z, front)
	# On a vertical walk the back is edge-on; retain its visible board thickness.
	var thickness := Vector2(0, 3) if front.y != 0 else Vector2(2, 0)
	canvas.draw_colored_polygon(PackedVector2Array([a, b, b + thickness, a + thickness]), _color("8b5839", alpha))
	canvas.draw_line(a, b, _color("d2a471", alpha), 1.0)

static func _back(canvas: CanvasItem, front: Vector2i, alpha: float) -> void:
	for x in [-14, 14]:
		canvas.draw_line(_p(x, -4, 7, front), _p(x, -4, 23, front), _color("354641", alpha), 2.0)
	for z in [15, 20]:
		_board(canvas, front, -4, z, alpha)

static func draw_item(canvas: CanvasItem, type: String, front: Vector2i, alpha: float = 1.0) -> void:
	match type:
		"park_bench":
			# Feet and contact marks share exactly the same projected ground plane.
			for x in [-14, 14]:
				for y in [-4, 4]:
					var foot := _p(x, y, 0, front)
					canvas.draw_line(foot + Vector2(-2, 1), foot + Vector2(3, 1), _color("26362c66", alpha), 2.0)
					canvas.draw_line(foot, _p(x, y, 8, front), _color("354641", alpha), 2.0)
			if front.y >= 0:
				_back(canvas, front, alpha)
			for y in [-3, 0, 3]:
				var a := _p(-18, y - 1, 8, front)
				var b := _p(18, y - 1, 8, front)
				var c := _p(18, y + 1, 8, front)
				var d := _p(-18, y + 1, 8, front)
				canvas.draw_colored_polygon(PackedVector2Array([a, b, c, d]), _color("bc8856", alpha))
				canvas.draw_line(a, b, _color("e0b985", alpha), 1.0)
			if front.y < 0:
				_back(canvas, front, alpha)
		"course_signage":
			canvas.draw_line(Vector2(-3, 1), Vector2(4, 1), _color("26362c66", alpha), 2.0)
			canvas.draw_rect(Rect2(-1, -29, 3, 29), _color("705139", alpha))
			var direction := -1.0 if front.x < 0 else 1.0
			for y in [-26, -18]:
				canvas.draw_colored_polygon(PackedVector2Array([Vector2(-10 * direction, y), Vector2(9 * direction, y), Vector2(13 * direction, y + 3), Vector2(9 * direction, y + 6), Vector2(-10 * direction, y + 6)]), _color("365b43", alpha))
				canvas.draw_line(Vector2(-7 * direction, y + 1), Vector2(7 * direction, y + 1), _color("d4ba80", alpha), 1.0)
				canvas.draw_line(Vector2(-5 * direction, y + 3), Vector2(4 * direction, y + 3), _color("eee2b7", alpha), 1.0)
		"waste_bin":
			canvas.draw_line(Vector2(-6, 1), Vector2(6, 1), _color("26362c66", alpha), 3.0)
			canvas.draw_rect(Rect2(-6, -15, 12, 15), _color("36564b", alpha))
			for x in [-3, 1, 5]:
				canvas.draw_line(Vector2(x, -13), Vector2(x, -2), _color("638071", alpha), 1.0)
			canvas.draw_rect(Rect2(-7, -17, 14, 3), _color("263e37", alpha))
			canvas.draw_line(Vector2(-5, -18), Vector2(5, -18), _color("91a38b", alpha), 1.0)
		"ball_washer":
			canvas.draw_line(Vector2(-4, 1), Vector2(4, 1), _color("26362c66", alpha), 2.0)
			canvas.draw_rect(Rect2(-1, -18, 3, 18), _color("42594c", alpha))
			canvas.draw_rect(Rect2(-5, -25, 10, 9), _color("945347", alpha))
			canvas.draw_line(Vector2(-5, -25), Vector2(5, -25), _color("d89871", alpha), 1.0)
			canvas.draw_line(Vector2(0, -26), Vector2(0, -29), _color("d2d2b9", alpha), 2.0)
			canvas.draw_rect(Rect2(3, -16, 5, 7), _color("e4dfc9", alpha))
