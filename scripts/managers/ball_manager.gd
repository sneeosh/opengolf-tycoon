extends Node
class_name BallManager
## BallManager - Manages all golf balls on the course

var active_balls: Dictionary = {}  # key: golfer_id, value: Ball instance
var terrain_grid: TerrainGrid

@onready var balls_container: Node2D = get_parent().get_node("Entities/Balls") if get_parent().has_node("Entities/Balls") else null

signal ball_created(golfer_id: int, ball: Ball)
signal ball_flight_started(golfer_id: int, from: Vector2i, to: Vector2i)
signal ball_landed(golfer_id: int, position: Vector2i)
signal ball_in_hazard(golfer_id: int, hazard_type: String)

func _ready() -> void:
	# Connect to EventBus for golfer shot events
	EventBus.shot_taken.connect(_on_shot_taken)
	EventBus.ball_landed.connect(_on_ball_landed)
	EventBus.ball_putt_landed_precise.connect(_on_ball_putt_precise)
	EventBus.golfer_started_hole.connect(_on_golfer_started_hole)
	EventBus.golfer_finished_hole.connect(_on_golfer_finished_hole)
	EventBus.golfer_finished_round.connect(_on_golfer_finished_round)
	EventBus.hazard_penalty.connect(_on_hazard_penalty)

func _exit_tree() -> void:
	if EventBus.shot_taken.is_connected(_on_shot_taken):
		EventBus.shot_taken.disconnect(_on_shot_taken)
	if EventBus.ball_landed.is_connected(_on_ball_landed):
		EventBus.ball_landed.disconnect(_on_ball_landed)
	if EventBus.ball_putt_landed_precise.is_connected(_on_ball_putt_precise):
		EventBus.ball_putt_landed_precise.disconnect(_on_ball_putt_precise)
	if EventBus.golfer_started_hole.is_connected(_on_golfer_started_hole):
		EventBus.golfer_started_hole.disconnect(_on_golfer_started_hole)
	if EventBus.golfer_finished_hole.is_connected(_on_golfer_finished_hole):
		EventBus.golfer_finished_hole.disconnect(_on_golfer_finished_hole)
	if EventBus.golfer_finished_round.is_connected(_on_golfer_finished_round):
		EventBus.golfer_finished_round.disconnect(_on_golfer_finished_round)
	if EventBus.hazard_penalty.is_connected(_on_hazard_penalty):
		EventBus.hazard_penalty.disconnect(_on_hazard_penalty)

func set_terrain_grid(grid: TerrainGrid) -> void:
	terrain_grid = grid

## Create or get ball for a golfer
func get_or_create_ball(golfer_id: int) -> Ball:
	if active_balls.has(golfer_id):
		return active_balls[golfer_id]

	if not balls_container:
		push_error("BallManager: No balls container found")
		return null

	var ball = Ball.new()
	ball.golfer_id = golfer_id
	ball.set_terrain_grid(terrain_grid)

	balls_container.add_child(ball)
	active_balls[golfer_id] = ball

	# Connect signals
	ball.ball_landed.connect(_on_ball_landed_at_position.bind(golfer_id))
	ball.ball_state_changed.connect(_on_ball_state_changed.bind(golfer_id))
	ball.ball_landed_in_bunker.connect(_on_ball_landed_in_bunker.bind(golfer_id))

	ball_created.emit(golfer_id, ball)
	return ball

## Remove a ball from the course
func remove_ball(golfer_id: int) -> void:
	if not active_balls.has(golfer_id):
		return

	var ball = active_balls[golfer_id]
	ball.destroy()
	active_balls.erase(golfer_id)

## Hide ball (when golfer finishes hole)
func hide_ball(golfer_id: int) -> void:
	var ball = get_ball(golfer_id)
	if ball:
		ball.visible = false

## Show ball (when golfer starts new hole)
func show_ball(golfer_id: int) -> void:
	var ball = get_ball(golfer_id)
	if ball:
		ball.visible = true

## Handle ball going into water - show visual then reset
func handle_water_penalty(golfer_id: int, previous_position: Vector2i) -> void:
	var ball = get_ball(golfer_id)
	if not ball:
		return

	# Ball visual already shows water state
	# Wait a moment to show the splash, then drop at previous position
	await get_tree().create_timer(1.5).timeout

	# Drop ball at previous position (or designated drop zone)
	ball.set_position_in_grid(previous_position)
	ball.ball_state = Ball.BallState.AT_REST
	ball.visible = true

	ball_in_hazard.emit(golfer_id, "water")

## Handle ball going out of bounds - show visual then reset
func handle_ob_penalty(golfer_id: int, previous_position: Vector2i) -> void:
	var ball = get_ball(golfer_id)
	if not ball:
		return

	# Ball visual already shows OB state
	# Wait a moment, then reset to previous position
	await get_tree().create_timer(1.5).timeout

	# Re-hit from previous position (stroke and distance)
	ball.set_position_in_grid(previous_position)
	ball.ball_state = Ball.BallState.AT_REST
	ball.visible = true

	ball_in_hazard.emit(golfer_id, "ob")

## Animate ball flight from one position to another
func animate_shot(golfer_id: int, from_grid: Vector2i, to_grid: Vector2i, distance_yards: int, is_putt: bool = false) -> void:
	var ball = get_or_create_ball(golfer_id)
	if not ball:
		return

	# Make sure ball is visible
	ball.visible = true

	# Sand spray when hitting out of a bunker
	if terrain_grid and terrain_grid.get_tile(from_grid) == TerrainTypes.Type.BUNKER:
		var from_world = terrain_grid.grid_to_screen_center(from_grid)
		SandSprayEffect.create_at(ball.get_parent(), from_world)

	# Calculate wind visual offset for the flight animation
	var wind_offset = Vector2.ZERO
	if not is_putt and GameManager.wind_system and terrain_grid:
		var shot_direction = Vector2(to_grid - from_grid).normalized()
		var distance_tiles = Vector2(to_grid - from_grid).length()
		# Convert wind tile displacement to screen pixels for visual effect
		var wind_tile_disp = GameManager.wind_system.get_wind_displacement(shot_direction, distance_tiles, 1)  # Use IRON sensitivity for visual
		wind_offset = wind_tile_disp * terrain_grid.tile_width * 0.5  # Scale to screen space

	# Calculate flight duration based on distance (longer shots take longer)
	if is_putt:
		# Putts are ground rolls - shorter, consistent duration
		var duration = 0.3 + (distance_yards / 100.0) * 0.7
		duration = clamp(duration, 0.3, 1.5)
		ball.start_flight(from_grid, to_grid, duration, true)
	else:
		var base_duration = 1.0
		var duration = base_duration + (distance_yards / 300.0) * 1.5
		duration = clamp(duration, 0.5, 3.0)
		ball.start_flight(from_grid, to_grid, duration, false, wind_offset)

	ball_flight_started.emit(golfer_id, from_grid, to_grid)

## Place ball at rest position (for tee shots)
func place_ball_at_rest(golfer_id: int, grid_pos: Vector2i) -> void:
	var ball = get_or_create_ball(golfer_id)
	if not ball:
		return

	ball.set_position_in_grid(grid_pos)
	ball.ball_state = Ball.BallState.AT_REST
	ball.visible = true

## Get ball for a specific golfer
func get_ball(golfer_id: int) -> Ball:
	return active_balls.get(golfer_id, null)

## Get all active balls
func get_all_balls() -> Array:
	return active_balls.values()

## EventBus signal handlers
func _on_shot_taken(golfer_id: int, hole_number: int, stroke_count: int) -> void:
	# Shot taken signal received
	# The actual ball movement will be triggered by ball_landed signal
	# which contains the from/to positions
	pass

func _on_ball_landed(golfer_id: int, from_position: Vector2i, landing_position: Vector2i, terrain_type: int) -> void:
	# This is called from golfer._calculate_shot()
	# We need to animate the ball from the shot origin to landing position
	if terrain_grid:
		var distance = terrain_grid.calculate_distance_yards(from_position, landing_position)
		var is_putt = terrain_grid.get_tile(from_position) == TerrainTypes.Type.GREEN
		animate_shot(golfer_id, from_position, landing_position, distance, is_putt)

func _on_ball_landed_at_position(landing_pos: Vector2i, golfer_id: int) -> void:
	# Ball has finished landing animation
	ball_landed.emit(golfer_id, landing_pos)

func _on_hazard_penalty(golfer_id: int, hazard_type: String, reset_position: Vector2i) -> void:
	var ball = get_ball(golfer_id)
	if not ball:
		return

	# Reset ball to the drop/previous position
	ball.set_position_in_grid(reset_position)
	ball.ball_state = Ball.BallState.AT_REST
	ball.visible = true
	ball_in_hazard.emit(golfer_id, hazard_type)

func _on_ball_state_changed(old_state: Ball.BallState, new_state: Ball.BallState, golfer_id: int) -> void:
	# Ball state changes are logged here; penalty handling is triggered by golfer logic
	# via the hazard_penalty EventBus signal
	match new_state:
		Ball.BallState.IN_WATER:
			print("Ball %d went in water!" % golfer_id)
		Ball.BallState.OUT_OF_BOUNDS:
			print("Ball %d went out of bounds!" % golfer_id)

func _on_ball_landed_in_bunker(landing_pos: Vector2i, golfer_id: int) -> void:
	var ball = get_ball(golfer_id)
	if ball:
		SandSprayEffect.create_at(ball.get_parent(), ball.global_position)

func _on_golfer_started_hole(golfer_id: int, hole_number: int) -> void:
	# Golfer started a new hole - ball will be placed when they take their first shot
	# Make sure ball is visible for new hole
	show_ball(golfer_id)

func _on_golfer_finished_hole(golfer_id: int, hole_number: int, strokes: int, par: int) -> void:
	# Golfer finished the hole - hide the ball until next hole
	hide_ball(golfer_id)

func _on_ball_putt_precise(golfer_id: int, from_screen: Vector2, to_screen: Vector2, distance_yards: int) -> void:
	# Handle precise sub-tile putt animation
	var ball = get_or_create_ball(golfer_id)
	if not ball:
		return

	ball.visible = true
	var duration = 0.3 + (distance_yards / 100.0) * 0.7
	duration = clamp(duration, 0.3, 1.5)
	ball.start_flight_screen(from_screen, to_screen, duration, true)

func _on_golfer_finished_round(golfer_id: int, total_strokes: int) -> void:
	# Remove ball when golfer finishes their round
	remove_ball(golfer_id)
