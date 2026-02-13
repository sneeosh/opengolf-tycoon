extends Node2D
class_name ShotAimOverlay
## ShotAimOverlay - Visual overlay showing aim direction and projected landing zone
##
## Draws an aim line from the golfer to the projected landing position,
## with a landing zone circle colored by terrain safety.

var _controller: PlayerGolferController = null
var _terrain_grid: TerrainGrid = null
var _golfer: Golfer = null

## Visual settings
const AIM_LINE_COLOR: Color = Color(1.0, 1.0, 1.0, 0.6)
const AIM_LINE_WIDTH: float = 2.0
const LANDING_ZONE_RADIUS: float = 24.0  # pixels
const SAFE_COLOR: Color = Color(0.3, 0.9, 0.3, 0.3)
const HAZARD_COLOR: Color = Color(0.9, 0.3, 0.3, 0.3)
const WATER_COLOR: Color = Color(0.3, 0.3, 0.9, 0.3)

func setup(controller: PlayerGolferController, golfer: Golfer, terrain_grid: TerrainGrid) -> void:
	_controller = controller
	_golfer = golfer
	_terrain_grid = terrain_grid
	_controller.aim_updated.connect(_on_aim_updated)
	_controller.player_shot_taken.connect(_on_shot_taken)

func _on_aim_updated(_direction: Vector2, _distance: float) -> void:
	queue_redraw()

func _on_shot_taken() -> void:
	queue_redraw()

func _process(_delta: float) -> void:
	if not _golfer or not _controller:
		visible = false
		return

	visible = _golfer.current_state == Golfer.State.PREPARING_SHOT

func _draw() -> void:
	if not _controller or not _golfer or not _terrain_grid:
		return
	if _golfer.current_state != Golfer.State.PREPARING_SHOT:
		return

	var golfer_screen = _golfer.global_position
	var ball_pos = _golfer.ball_position_precise

	# Calculate landing position based on aim
	var stats = Golfer.CLUB_STATS[_controller.selected_club]
	var shot_dist = lerpf(stats["min_distance"], stats["max_distance"], _controller.shot_power)
	var landing_precise = ball_pos + _controller.aim_direction * shot_dist
	var landing_screen = _terrain_grid.grid_to_screen_precise(landing_precise)

	# Convert to local coordinates
	var start = to_local(golfer_screen)
	var end = to_local(landing_screen)

	# Draw aim line (dashed)
	var line_length = start.distance_to(end)
	var dir = (end - start).normalized()
	var dash_length = 8.0
	var gap_length = 6.0
	var pos = 0.0
	while pos < line_length:
		var dash_start = start + dir * pos
		var dash_end = start + dir * minf(pos + dash_length, line_length)
		draw_line(dash_start, dash_end, AIM_LINE_COLOR, AIM_LINE_WIDTH)
		pos += dash_length + gap_length

	# Draw landing zone circle
	var landing_grid = Vector2i(landing_precise.round())
	var terrain_type = _terrain_grid.get_tile(landing_grid) if _terrain_grid.is_valid_position(landing_grid) else -1

	var zone_color = SAFE_COLOR
	match terrain_type:
		TerrainTypes.Type.WATER:
			zone_color = WATER_COLOR
		TerrainTypes.Type.BUNKER:
			zone_color = HAZARD_COLOR
		TerrainTypes.Type.OUT_OF_BOUNDS:
			zone_color = HAZARD_COLOR
		TerrainTypes.Type.HEAVY_ROUGH:
			zone_color = Color(0.8, 0.6, 0.2, 0.3)
		TerrainTypes.Type.TREES, TerrainTypes.Type.ROCKS:
			zone_color = HAZARD_COLOR
		TerrainTypes.Type.GREEN:
			zone_color = Color(0.2, 1.0, 0.2, 0.4)
		TerrainTypes.Type.FAIRWAY:
			zone_color = SAFE_COLOR

	# Draw filled circle for landing zone
	draw_circle(end, LANDING_ZONE_RADIUS, zone_color)
	# Draw outline
	var outline_color = Color(zone_color.r, zone_color.g, zone_color.b, 0.8)
	_draw_circle_outline(end, LANDING_ZONE_RADIUS, outline_color, 2.0)

	# Draw crosshair at center
	draw_line(end + Vector2(-6, 0), end + Vector2(6, 0), Color.WHITE * 0.7, 1.0)
	draw_line(end + Vector2(0, -6), end + Vector2(0, 6), Color.WHITE * 0.7, 1.0)

	# Draw distance text near landing zone
	# (Godot _draw doesn't support text easily, so we skip this - the HUD shows distance)

func _draw_circle_outline(center: Vector2, radius: float, color: Color, width: float) -> void:
	var points = 32
	for i in range(points):
		var angle_from = i * TAU / points
		var angle_to = (i + 1) * TAU / points
		var from = center + Vector2(cos(angle_from), sin(angle_from)) * radius
		var to = center + Vector2(cos(angle_to), sin(angle_to)) * radius
		draw_line(from, to, color, width)
