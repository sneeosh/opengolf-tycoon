extends Line2D
class_name ShotTrail
## ShotTrail - Visual arc showing shot path, fades and self-destructs.

const TerrainTypes = preload("res://scripts/terrain/terrain_types.gd")

const FADE_DURATION: float = 4.0
const ARC_POINTS: int = 12
const TRAIL_WIDTH: float = 2.0

const COLOR_PUTT := Color(1.0, 1.0, 1.0, 0.5)
const COLOR_GOOD := Color(0.3, 0.9, 0.3, 0.5)
const COLOR_OK := Color(0.9, 0.9, 0.3, 0.5)
const COLOR_TROUBLE := Color(0.9, 0.3, 0.3, 0.5)

static func create(parent: Node, from_pos: Vector2, to_pos: Vector2,
		carry_pos: Vector2, is_putt: bool, landing_terrain: int) -> ShotTrail:
	var trail = ShotTrail.new()
	trail.width = TRAIL_WIDTH
	trail.z_index = 50
	trail.default_color = trail._get_trail_color(is_putt, landing_terrain)
	trail._build_arc(from_pos, carry_pos, to_pos, is_putt)
	parent.add_child(trail)
	trail._start_fade()
	return trail

func _build_arc(from_pos: Vector2, carry_pos: Vector2, to_pos: Vector2, is_putt: bool) -> void:
	if is_putt:
		add_point(from_pos)
		add_point(to_pos)
		return

	# Parabolic arc from launch to carry point
	var arc_height = min(from_pos.distance_to(carry_pos) * 0.3, 150.0)
	for i in range(ARC_POINTS + 1):
		var t = float(i) / ARC_POINTS
		var pos = from_pos.lerp(carry_pos, t)
		pos.y -= arc_height * 4.0 * t * (1.0 - t)
		add_point(pos)

	# Straight rollout from carry to final position
	if carry_pos.distance_to(to_pos) > 2.0:
		add_point(to_pos)

func _get_trail_color(is_putt: bool, landing_terrain: int) -> Color:
	if is_putt:
		return COLOR_PUTT
	match landing_terrain:
		TerrainTypes.Type.GREEN, TerrainTypes.Type.FAIRWAY:
			return COLOR_GOOD
		TerrainTypes.Type.ROUGH, TerrainTypes.Type.HEAVY_ROUGH, TerrainTypes.Type.BUNKER:
			return COLOR_OK
		TerrainTypes.Type.WATER, TerrainTypes.Type.OUT_OF_BOUNDS:
			return COLOR_TROUBLE
		_:
			return COLOR_GOOD

func _start_fade() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION)
	tween.tween_callback(queue_free)
