extends Node2D
class_name Ball
## Ball - Represents a golf ball in flight or at rest

enum BallState {
	AT_REST,      # Ball is sitting still
	IN_FLIGHT,    # Ball is flying through the air
	ROLLING,      # Ball is rolling on ground after landing
	IN_WATER,     # Ball is in water hazard
	OUT_OF_BOUNDS # Ball is OB
}

var golfer_id: int = -1
var grid_position: Vector2i = Vector2i.ZERO
var ball_state: BallState = BallState.AT_REST
var terrain_grid: TerrainGrid

# Flight animation properties
var flight_start_pos: Vector2 = Vector2.ZERO
var flight_end_pos: Vector2 = Vector2.ZERO
var flight_progress: float = 0.0
var flight_duration: float = 1.0
var flight_max_height: float = 100.0
var wind_visual_offset: Vector2 = Vector2.ZERO  # Visual wind drift during flight

# Rollout animation properties
var roll_start_pos: Vector2 = Vector2.ZERO
var roll_end_pos: Vector2 = Vector2.ZERO
var roll_progress: float = 0.0
var roll_duration: float = 0.0
var _has_pending_rollout: bool = false

signal ball_landed(landing_pos: Vector2i)
signal ball_state_changed(old_state: BallState, new_state: BallState)
signal ball_landed_in_bunker(landing_pos: Vector2i)
signal ball_landed_in_water(landing_pos: Vector2i)

func _ready() -> void:
	z_index = 100  # Render above terrain and entities
	_update_visual()

func _process(delta: float) -> void:
	if ball_state == BallState.IN_FLIGHT:
		_process_flight(delta)
	elif ball_state == BallState.ROLLING:
		_process_rolling(delta)

func set_terrain_grid(grid: TerrainGrid) -> void:
	terrain_grid = grid

func set_position_in_grid(pos: Vector2i) -> void:
	grid_position = pos
	if terrain_grid:
		var world_pos = terrain_grid.grid_to_screen_center(pos)
		global_position = world_pos
	_update_visual()

## Configure rollout to play after the current flight lands.
## carry_screen is where the ball first hits ground (should match flight_end_pos).
## final_screen is where it comes to rest after rolling.
func set_rollout(final_screen: Vector2, duration: float) -> void:
	roll_end_pos = final_screen
	roll_duration = duration
	_has_pending_rollout = true

## Start a flight animation from one position to another
func start_flight(from_grid: Vector2i, to_grid: Vector2i, duration: float = 1.5, is_putt: bool = false, wind_offset: Vector2 = Vector2.ZERO) -> void:
	if not terrain_grid:
		return

	grid_position = from_grid
	flight_start_pos = terrain_grid.grid_to_screen_center(from_grid)
	flight_end_pos = terrain_grid.grid_to_screen_center(to_grid)
	flight_progress = 0.0
	flight_duration = duration

	# Putts roll along the ground; other shots fly in an arc
	if is_putt:
		flight_max_height = 0.0
		wind_visual_offset = Vector2.ZERO  # No wind on putts
	else:
		var distance = flight_start_pos.distance_to(flight_end_pos)
		flight_max_height = min(distance * 0.3, 150.0)
		wind_visual_offset = wind_offset

	_change_state(BallState.IN_FLIGHT)
	global_position = flight_start_pos

## Start a flight animation using precise screen coordinates (for sub-tile putting)
func start_flight_screen(from_screen: Vector2, to_screen: Vector2, duration: float = 1.5, is_putt: bool = false) -> void:
	flight_start_pos = from_screen
	flight_end_pos = to_screen
	flight_progress = 0.0
	flight_duration = duration

	if is_putt:
		flight_max_height = 0.0
		wind_visual_offset = Vector2.ZERO  # No wind drift on putts
	else:
		var distance = flight_start_pos.distance_to(flight_end_pos)
		flight_max_height = min(distance * 0.3, 150.0)

	_change_state(BallState.IN_FLIGHT)
	global_position = flight_start_pos

## Start a flight animation with arc using precise screen coordinates (for sub-tile shots)
func start_flight_screen_with_arc(from_screen: Vector2, to_screen: Vector2, duration: float = 1.5, wind_offset: Vector2 = Vector2.ZERO) -> void:
	flight_start_pos = from_screen
	flight_end_pos = to_screen
	flight_progress = 0.0
	flight_duration = duration

	var distance = flight_start_pos.distance_to(flight_end_pos)
	flight_max_height = min(distance * 0.3, 150.0)
	wind_visual_offset = wind_offset

	_change_state(BallState.IN_FLIGHT)
	global_position = flight_start_pos

func _process_flight(delta: float) -> void:
	flight_progress += delta / flight_duration

	if flight_progress >= 1.0:
		# Flight complete - ball hits the ground
		flight_progress = 1.0
		global_position = flight_end_pos

		# Update grid position to carry spot
		if terrain_grid:
			grid_position = terrain_grid.screen_to_grid(flight_end_pos)

		scale = Vector2.ONE  # Reset scale from flight

		# Check if rollout was configured — if so, start rolling instead of landing
		if _has_pending_rollout and roll_end_pos.distance_to(flight_end_pos) > 1.0:
			_has_pending_rollout = false
			_start_rollout()
		else:
			_has_pending_rollout = false
			_land_ball()
		return

	# Parabolic arc animation
	var linear_pos = flight_start_pos.lerp(flight_end_pos, flight_progress)
	var arc_height = sin(flight_progress * PI) * flight_max_height

	# Apply wind visual drift as a bell curve: peaks at mid-flight, smoothly
	# returns to zero at landing so the ball arrives at the correct position
	var wind_drift = wind_visual_offset * sin(flight_progress * PI)

	global_position = linear_pos - Vector2(0, arc_height) + wind_drift

	# Update visual scale for depth perception (skip for putts rolling on ground)
	if flight_max_height > 0.0:
		var scale_factor = 1.0 + (arc_height / flight_max_height) * 0.5
		scale = Vector2(scale_factor, scale_factor)

## Begin rollout animation from current position to roll_end_pos
func _start_rollout() -> void:
	roll_start_pos = global_position
	roll_progress = 0.0
	_change_state(BallState.ROLLING)

func _process_rolling(delta: float) -> void:
	if roll_duration <= 0.0:
		_finish_rollout()
		return

	roll_progress += delta / roll_duration

	if roll_progress >= 1.0:
		roll_progress = 1.0
		global_position = roll_end_pos
		_finish_rollout()
		return

	# Ease-out deceleration: ball slows down as it rolls
	var eased_t = 1.0 - pow(1.0 - roll_progress, 2.0)
	global_position = roll_start_pos.lerp(roll_end_pos, eased_t)

func _finish_rollout() -> void:
	global_position = roll_end_pos
	if terrain_grid:
		grid_position = terrain_grid.screen_to_grid(roll_end_pos)
	_land_ball()

func _land_ball() -> void:
	if not terrain_grid:
		_change_state(BallState.AT_REST)
		ball_landed.emit(grid_position)
		scale = Vector2.ONE
		return

	# Check terrain type at final resting position
	var terrain_type = terrain_grid.get_tile(grid_position)

	# Spawn landing impact effect based on terrain
	var impact_terrain = "default"
	match terrain_type:
		TerrainTypes.Type.FAIRWAY, TerrainTypes.Type.TEE_BOX:
			impact_terrain = "fairway"
		TerrainTypes.Type.GRASS, TerrainTypes.Type.ROUGH, TerrainTypes.Type.HEAVY_ROUGH:
			impact_terrain = "grass"
		TerrainTypes.Type.BUNKER:
			impact_terrain = "bunker"
		TerrainTypes.Type.WATER:
			impact_terrain = "water"
		TerrainTypes.Type.GREEN:
			impact_terrain = "fairway"
	LandingImpactEffect.create_at(get_parent(), global_position, impact_terrain)

	match terrain_type:
		TerrainTypes.Type.WATER:
			_change_state(BallState.IN_WATER)
			ball_landed_in_water.emit(grid_position)
		TerrainTypes.Type.OUT_OF_BOUNDS:
			_change_state(BallState.OUT_OF_BOUNDS)
		TerrainTypes.Type.BUNKER:
			_change_state(BallState.AT_REST)
			ball_landed_in_bunker.emit(grid_position)
		_:
			_change_state(BallState.AT_REST)

	ball_landed.emit(grid_position)
	scale = Vector2.ONE  # Reset scale

func _change_state(new_state: BallState) -> void:
	if ball_state == new_state:
		return

	var old_state = ball_state
	ball_state = new_state
	ball_state_changed.emit(old_state, new_state)
	_update_visual()

func _update_visual() -> void:
	# Remove existing visual if it exists
	if has_node("Visual"):
		get_node("Visual").queue_free()

	var visual = Node2D.new()
	visual.name = "Visual"
	add_child(visual)

	# Draw ball based on state
	match ball_state:
		BallState.AT_REST, BallState.ROLLING:
			_draw_ball_at_rest(visual)
		BallState.IN_FLIGHT:
			_draw_ball_in_flight(visual)
		BallState.IN_WATER:
			_draw_ball_in_water(visual)
		BallState.OUT_OF_BOUNDS:
			_draw_ball_out_of_bounds(visual)

func _draw_ball_at_rest(visual: Node2D) -> void:
	# White golf ball
	var ball = Polygon2D.new()
	ball.color = Color.WHITE
	var points = PackedVector2Array()
	for i in range(12):
		var angle = (i / 12.0) * TAU
		var x = cos(angle) * 4
		var y = sin(angle) * 4
		points.append(Vector2(x, y))
	ball.polygon = points
	visual.add_child(ball)

	# Shadow
	var shadow = Polygon2D.new()
	shadow.color = Color(0, 0, 0, 0.3)
	shadow.position = Vector2(2, 3)
	var shadow_points = PackedVector2Array()
	for i in range(8):
		var angle = (i / 8.0) * TAU
		var x = cos(angle) * 3
		var y = sin(angle) * 1.5
		shadow_points.append(Vector2(x, y))
	shadow.polygon = shadow_points
	visual.add_child(shadow)

func _draw_ball_in_flight(visual: Node2D) -> void:
	# Slightly larger for visibility
	var ball = Polygon2D.new()
	ball.color = Color.WHITE
	var points = PackedVector2Array()
	for i in range(12):
		var angle = (i / 12.0) * TAU
		var x = cos(angle) * 5
		var y = sin(angle) * 5
		points.append(Vector2(x, y))
	ball.polygon = points
	visual.add_child(ball)

	# Add motion blur effect
	var blur = Polygon2D.new()
	blur.color = Color(1, 1, 1, 0.3)
	blur.position = Vector2(-3, 1)
	var blur_points = PackedVector2Array()
	for i in range(8):
		var angle = (i / 8.0) * TAU
		var x = cos(angle) * 4
		var y = sin(angle) * 4
		blur_points.append(Vector2(x, y))
	blur.polygon = blur_points
	visual.add_child(blur)

func _draw_ball_in_water(visual: Node2D) -> void:
	# Semi-transparent ball in water
	var ball = Polygon2D.new()
	ball.color = Color(1, 1, 1, 0.5)
	var points = PackedVector2Array()
	for i in range(12):
		var angle = (i / 12.0) * TAU
		var x = cos(angle) * 4
		var y = sin(angle) * 4
		points.append(Vector2(x, y))
	ball.polygon = points
	visual.add_child(ball)

	# Water splash effect
	var splash = Polygon2D.new()
	splash.color = Color(0.3, 0.5, 0.8, 0.6)
	var splash_points = PackedVector2Array([
		Vector2(-6, 0), Vector2(-3, -4), Vector2(0, -2),
		Vector2(3, -4), Vector2(6, 0), Vector2(3, 2),
		Vector2(0, 4), Vector2(-3, 2)
	])
	splash.polygon = splash_points
	visual.add_child(splash)

func _draw_ball_out_of_bounds(visual: Node2D) -> void:
	# Red X over ball
	var ball = Polygon2D.new()
	ball.color = Color.GRAY
	var points = PackedVector2Array()
	for i in range(12):
		var angle = (i / 12.0) * TAU
		var x = cos(angle) * 4
		var y = sin(angle) * 4
		points.append(Vector2(x, y))
	ball.polygon = points
	visual.add_child(ball)

func get_ball_info() -> Dictionary:
	return {
		"golfer_id": golfer_id,
		"position": grid_position,
		"state": ball_state,
		"world_position": global_position
	}

func destroy() -> void:
	queue_free()
