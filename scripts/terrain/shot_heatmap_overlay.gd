extends Node2D
class_name ShotHeatmapOverlay
## ShotHeatmapOverlay - Renders shot landing heatmap over terrain tiles

const TerrainTypes = preload("res://scripts/terrain/terrain_types.gd")

const ARC_POINTS: int = 12
const ARC_WIDTH: float = 1.5
const ARC_ALPHA: float = 0.45

const ARC_COLOR_PUTT := Color(1.0, 1.0, 1.0, ARC_ALPHA)
const ARC_COLOR_GOOD := Color(0.3, 0.9, 0.3, ARC_ALPHA)
const ARC_COLOR_OK := Color(0.9, 0.9, 0.3, ARC_ALPHA)
const ARC_COLOR_TROUBLE := Color(0.9, 0.3, 0.3, ARC_ALPHA)

enum HeatmapMode { DENSITY, TROUBLE }

var terrain_grid: TerrainGrid = null
var tracker: ShotHeatmapTracker = null
var _enabled: bool = false
var _mode: HeatmapMode = HeatmapMode.DENSITY

func initialize(grid: TerrainGrid, heatmap_tracker: ShotHeatmapTracker) -> void:
	terrain_grid = grid
	tracker = heatmap_tracker
	z_index = 99
	visible = false

func toggle() -> void:
	_enabled = not _enabled
	visible = _enabled
	if _enabled:
		var mode_name = "Shot Density" if _mode == HeatmapMode.DENSITY else "Trouble Zones"
		EventBus.notify("Heatmap: %s" % mode_name, "info")
		queue_redraw()

func cycle_mode() -> void:
	if _mode == HeatmapMode.DENSITY:
		_mode = HeatmapMode.TROUBLE
	else:
		_mode = HeatmapMode.DENSITY
	var mode_name = "Shot Density" if _mode == HeatmapMode.DENSITY else "Trouble Zones"
	EventBus.notify("Heatmap: %s" % mode_name, "info")
	if _enabled:
		queue_redraw()

func is_enabled() -> bool:
	return _enabled

func _draw() -> void:
	if not _enabled or not terrain_grid or not tracker:
		return

	var tw: int = terrain_grid.tile_width
	var th: int = terrain_grid.tile_height

	if _mode == HeatmapMode.DENSITY:
		_draw_density(tw, th)
	else:
		_draw_trouble(tw, th)

	_draw_shot_arcs()

func _draw_density(tw: int, th: int) -> void:
	var max_count: int = tracker.get_max_landing_count()
	if max_count == 0:
		return

	for pos in tracker.landing_counts:
		var count: int = tracker.landing_counts[pos]
		var normalized: float = float(count) / float(max_count)
		var color: Color = _density_color(normalized)

		var screen_pos = terrain_grid.grid_to_screen(pos)
		var local_pos = to_local(screen_pos)
		draw_rect(Rect2(local_pos, Vector2(tw, th)), color)

func _draw_trouble(tw: int, th: int) -> void:
	for pos in tracker.trouble_data:
		var score: float = tracker.get_trouble_score(pos)
		if absf(score) < 0.01:
			continue

		var color: Color = _trouble_color(score)
		var screen_pos = terrain_grid.grid_to_screen(pos)
		var local_pos = to_local(screen_pos)
		draw_rect(Rect2(local_pos, Vector2(tw, th)), color)

func _density_color(normalized: float) -> Color:
	# Cool-to-hot gradient: blue -> cyan -> green -> yellow -> red
	var alpha: float = 0.3 + normalized * 0.4
	if normalized < 0.25:
		var t = normalized / 0.25
		return Color(0.0, t, 1.0, alpha)
	elif normalized < 0.5:
		var t = (normalized - 0.25) / 0.25
		return Color(0.0, 1.0, 1.0 - t, alpha)
	elif normalized < 0.75:
		var t = (normalized - 0.5) / 0.25
		return Color(t, 1.0, 0.0, alpha)
	else:
		var t = (normalized - 0.75) / 0.25
		return Color(1.0, 1.0 - t, 0.0, alpha)

func _trouble_color(score: float) -> Color:
	# Negative = under par (green), positive = over par (red)
	var clamped: float = clampf(score, -3.0, 3.0)
	var alpha: float = 0.3 + absf(clamped) / 3.0 * 0.35

	if clamped < 0:
		var t: float = absf(clamped) / 3.0
		return Color(0.0, 0.4 + t * 0.6, 0.1, alpha)
	else:
		var t: float = clamped / 3.0
		return Color(0.4 + t * 0.6, 0.0, 0.0, alpha)

## --- Shot Arc Rendering ---

func _draw_shot_arcs() -> void:
	for arc in tracker.shot_arcs:
		var points: PackedVector2Array = _build_arc_points(arc)
		if points.size() < 2:
			continue
		var color: Color = _arc_color(arc["is_putt"], arc["landing_terrain"])
		# Convert to local coordinates
		var local_points: PackedVector2Array = PackedVector2Array()
		for pt in points:
			local_points.append(to_local(pt))
		draw_polyline(local_points, color, ARC_WIDTH, true)

func _build_arc_points(arc: Dictionary) -> PackedVector2Array:
	var from_pos: Vector2 = arc["from"]
	var carry_pos: Vector2 = arc["carry"]
	var to_pos: Vector2 = arc["to"]
	var is_putt: bool = arc["is_putt"]

	var points: PackedVector2Array = PackedVector2Array()
	if is_putt:
		points.append(from_pos)
		points.append(to_pos)
		return points

	# Parabolic arc from launch to carry point
	var arc_height: float = minf(from_pos.distance_to(carry_pos) * 0.3, 150.0)
	for i in range(ARC_POINTS + 1):
		var t: float = float(i) / ARC_POINTS
		var pos: Vector2 = from_pos.lerp(carry_pos, t)
		pos.y -= arc_height * 4.0 * t * (1.0 - t)
		points.append(pos)

	# Straight rollout from carry to final position
	if carry_pos.distance_to(to_pos) > 2.0:
		points.append(to_pos)

	return points

func _arc_color(is_putt: bool, landing_terrain: int) -> Color:
	if is_putt:
		return ARC_COLOR_PUTT
	match landing_terrain:
		TerrainTypes.Type.GREEN, TerrainTypes.Type.FAIRWAY:
			return ARC_COLOR_GOOD
		TerrainTypes.Type.ROUGH, TerrainTypes.Type.HEAVY_ROUGH, TerrainTypes.Type.BUNKER:
			return ARC_COLOR_OK
		TerrainTypes.Type.WATER, TerrainTypes.Type.OUT_OF_BOUNDS:
			return ARC_COLOR_TROUBLE
		_:
			return ARC_COLOR_GOOD
