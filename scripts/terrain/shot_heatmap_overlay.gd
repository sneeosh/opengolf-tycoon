extends Node2D
class_name ShotHeatmapOverlay
## ShotHeatmapOverlay - Renders shot landing heatmap over terrain tiles

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
