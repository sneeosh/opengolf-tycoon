extends Node2D
class_name Ball
## Ball - Represents a golf ball in flight or at rest

enum BallState {
	AT_REST,      # Ball is sitting still
	IN_FLIGHT,    # Ball is flying through the air
	ROLLING,      # Ball is rolling on ground/green
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

signal ball_landed(landing_pos: Vector2i)
signal ball_state_changed(old_state: BallState, new_state: BallState)

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

## Start a flight animation from one position to another
func start_flight(from_grid: Vector2i, to_grid: Vector2i, duration: float = 1.5) -> void:
	if not terrain_grid:
		return

	grid_position = from_grid
	flight_start_pos = terrain_grid.grid_to_screen_center(from_grid)
	flight_end_pos = terrain_grid.grid_to_screen_center(to_grid)
	flight_progress = 0.0
	flight_duration = duration

	# Calculate max height based on distance
	var distance = flight_start_pos.distance_to(flight_end_pos)
	flight_max_height = min(distance * 0.3, 150.0)

	_change_state(BallState.IN_FLIGHT)
	global_position = flight_start_pos

func _process_flight(delta: float) -> void:
	flight_progress += delta / flight_duration

	if flight_progress >= 1.0:
		# Flight complete - land the ball
		flight_progress = 1.0
		global_position = flight_end_pos

		# Update grid position to landing spot
		if terrain_grid:
			grid_position = terrain_grid.screen_to_grid(flight_end_pos)

		_land_ball()
		return

	# Parabolic arc animation
	var linear_pos = flight_start_pos.lerp(flight_end_pos, flight_progress)
	var arc_height = sin(flight_progress * PI) * flight_max_height

	global_position = linear_pos - Vector2(0, arc_height)

	# Update visual scale for depth perception
	var scale_factor = 1.0 + (arc_height / flight_max_height) * 0.5
	scale = Vector2(scale_factor, scale_factor)

func _process_rolling(_delta: float) -> void:
	# Roll animation is handled by _simulate_roll
	pass

## Simulate ball rolling based on terrain
func _simulate_roll(max_tiles: int, duration: float) -> void:
	if not terrain_grid:
		return

	# Calculate roll direction (continue in same direction as flight)
	var roll_direction = (flight_end_pos - flight_start_pos).normalized()

	# Determine how far the ball will actually roll
	var roll_distance = randi_range(max_tiles / 2, max_tiles)
	var roll_target_pos = global_position + (roll_direction * roll_distance * 16)  # 16 pixels per tile approx

	# Animate the roll
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "global_position", roll_target_pos, duration)

	await tween.finished

	# Update grid position after roll
	if terrain_grid:
		grid_position = terrain_grid.screen_to_grid(global_position)

func _land_ball() -> void:
	if not terrain_grid:
		_change_state(BallState.AT_REST)
		return

	# Check terrain type at landing
	var terrain_type = terrain_grid.get_tile(grid_position)

	match terrain_type:
		TerrainTypes.Type.WATER:
			_change_state(BallState.IN_WATER)
		TerrainTypes.Type.GREEN:
			# Ball rolls smoothly on green (longest roll)
			_change_state(BallState.ROLLING)
			await _simulate_roll(4, 0.6)  # 4 tiles max, 0.6 sec duration
			_change_state(BallState.AT_REST)
		TerrainTypes.Type.FAIRWAY:
			# Ball rolls well on fairway (medium roll)
			_change_state(BallState.ROLLING)
			await _simulate_roll(3, 0.4)  # 3 tiles max, 0.4 sec duration
			_change_state(BallState.AT_REST)
		TerrainTypes.Type.ROUGH, TerrainTypes.Type.HEAVY_ROUGH:
			# Ball rolls minimally in rough (short roll)
			_change_state(BallState.ROLLING)
			await _simulate_roll(1, 0.3)  # 1 tile max, 0.3 sec duration
			_change_state(BallState.AT_REST)
		_:
			# Default for other terrain types
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
