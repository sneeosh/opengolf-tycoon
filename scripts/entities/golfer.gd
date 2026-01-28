extends CharacterBody2D
class_name Golfer
## Golfer - Base class for AI golfers playing the course

enum State {
	IDLE,           # Waiting to start
	WALKING,        # Moving to next position
	PREPARING_SHOT, # Lining up shot
	SWINGING,       # Taking a shot
	WATCHING,       # Watching ball flight
	PUTTING,        # On the green
	FINISHED        # Completed round
}

## Golfer identification
@export var golfer_name: String = "Golfer"
@export var golfer_id: int = -1

## Skill stats (0.0 to 1.0, where 1.0 is best)
@export_range(0.0, 1.0) var driving_skill: float = 0.5
@export_range(0.0, 1.0) var accuracy_skill: float = 0.5
@export_range(0.0, 1.0) var putting_skill: float = 0.5
@export_range(0.0, 1.0) var recovery_skill: float = 0.5

## Current state
var current_state: State = State.IDLE
var current_mood: float = 0.5  # 0.0 = angry, 1.0 = happy
var fatigue: float = 0.0       # 0.0 = fresh, 1.0 = exhausted

## Course progress
var current_hole: int = 0
var current_strokes: int = 0
var total_strokes: int = 0
var ball_position: Vector2i = Vector2i.ZERO
var target_position: Vector2i = Vector2i.ZERO

## Movement
@export var walk_speed: float = 100.0
var path: Array[Vector2] = []
var path_index: int = 0

## Visual components (to be added in scene)
@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
@onready var label: Label = $Label if has_node("Label") else null

signal state_changed(old_state: State, new_state: State)
signal shot_completed(distance: int, accuracy: float)
signal hole_completed(strokes: int, par: int)

func _ready() -> void:
	# Set up collision layers
	collision_layer = 4  # Layer 3 (golfers)
	collision_mask = 1   # Layer 1 (terrain/obstacles)

	if label:
		label.text = golfer_name

	_update_visual()

func _process(delta: float) -> void:
	match current_state:
		State.WALKING:
			_process_walking(delta)
		State.PREPARING_SHOT:
			_process_preparing_shot(delta)
		State.SWINGING:
			_process_swinging(delta)

func _process_walking(delta: float) -> void:
	if path.is_empty() or path_index >= path.size():
		_change_state(State.IDLE)
		return

	var target = path[path_index]
	var direction = (target - global_position).normalized()
	var distance = global_position.distance_to(target)

	if distance < 5.0:
		path_index += 1
		if path_index >= path.size():
			global_position = target
			_change_state(State.IDLE)
			_on_reached_destination()
		return

	velocity = direction * walk_speed
	move_and_slide()

func _process_preparing_shot(_delta: float) -> void:
	# AI thinks about the shot
	pass

func _process_swinging(_delta: float) -> void:
	# Animation plays
	pass

## Start playing a hole
func start_hole(hole_number: int, tee_position: Vector2i) -> void:
	current_hole = hole_number
	current_strokes = 0
	ball_position = tee_position

	var screen_pos = GameManager.terrain_grid.grid_to_screen(tee_position) if GameManager.terrain_grid else Vector2.ZERO
	global_position = screen_pos

	EventBus.emit_signal("golfer_started_hole", golfer_id, hole_number)
	_change_state(State.PREPARING_SHOT)

## Take a shot
func take_shot(target: Vector2i) -> void:
	current_strokes += 1
	_change_state(State.SWINGING)

	# Calculate shot outcome based on skill and terrain
	var shot_result = _calculate_shot(ball_position, target)

	# Update ball position
	ball_position = shot_result.landing_position

	# Emit events
	EventBus.emit_signal("shot_taken", golfer_id, current_hole, current_strokes)
	emit_signal("shot_completed", shot_result.distance, shot_result.accuracy)

	# Move to ball
	_walk_to_ball()

## Finish current hole
func finish_hole(par: int) -> void:
	total_strokes += current_strokes

	# Update mood based on performance
	var score_diff = current_strokes - par
	if score_diff <= -2:      # Eagle or better
		_adjust_mood(0.3)
	elif score_diff == -1:    # Birdie
		_adjust_mood(0.15)
	elif score_diff == 0:     # Par
		_adjust_mood(0.05)
	elif score_diff == 1:     # Bogey
		_adjust_mood(-0.1)
	else:                     # Double bogey or worse
		_adjust_mood(-0.2)

	EventBus.emit_signal("golfer_finished_hole", golfer_id, current_hole, current_strokes, par)
	emit_signal("hole_completed", current_strokes, par)

	_change_state(State.IDLE)

## Finish the round
func finish_round() -> void:
	EventBus.emit_signal("golfer_finished_round", golfer_id, total_strokes)
	_change_state(State.FINISHED)

## AI decision making - decide where to aim shot
func decide_shot_target(hole_position: Vector2i) -> Vector2i:
	# Simple AI: aim for the hole with some randomness based on skill
	var skill_factor = (driving_skill + accuracy_skill) / 2.0
	var max_distance = int(250.0 * skill_factor)  # Max drive distance in yards (tiles)

	var direction = Vector2(hole_position - ball_position).normalized()
	var distance = min(Vector2(ball_position).distance_to(Vector2(hole_position)), max_distance)

	# Add some randomness
	var accuracy_variance = (1.0 - accuracy_skill) * 20.0
	var random_offset = Vector2i(
		randi_range(-int(accuracy_variance), int(accuracy_variance)),
		randi_range(-int(accuracy_variance), int(accuracy_variance))
	)

	return ball_position + Vector2i(direction * distance) + random_offset

## Calculate shot outcome
func _calculate_shot(from: Vector2i, target: Vector2i) -> Dictionary:
	var terrain_grid = GameManager.terrain_grid
	if not terrain_grid:
		return {"landing_position": target, "distance": 0, "accuracy": 1.0}

	# Get terrain difficulty at start
	var terrain_type = terrain_grid.get_tile(from)
	var difficulty = TerrainTypes.get_properties(terrain_type).get("shot_difficulty", 0.0)

	# Calculate actual landing position with skill and terrain modifiers
	var skill_modifier = (driving_skill + accuracy_skill) / 2.0
	var total_accuracy = skill_modifier * (1.0 - difficulty)

	# Add randomness based on accuracy
	var error_range = int((1.0 - total_accuracy) * 30.0)
	var landing_position = target + Vector2i(
		randi_range(-error_range, error_range),
		randi_range(-error_range, error_range)
	)

	# Ensure landing position is valid
	if not terrain_grid.is_valid_position(landing_position):
		landing_position = target

	var distance = terrain_grid.calculate_distance_yards(from, landing_position)

	EventBus.emit_signal("ball_landed", golfer_id, landing_position, terrain_grid.get_tile(landing_position))

	return {
		"landing_position": landing_position,
		"distance": distance,
		"accuracy": total_accuracy
	}

## Walk to ball position
func _walk_to_ball() -> void:
	if not GameManager.terrain_grid:
		return

	var ball_screen_pos = GameManager.terrain_grid.grid_to_screen(ball_position)
	path = _find_path_to(ball_screen_pos)
	path_index = 0
	_change_state(State.WALKING)

## Simple pathfinding (straight line for now)
func _find_path_to(target_pos: Vector2) -> Array[Vector2]:
	var result: Array[Vector2] = []
	result.append(target_pos)
	return result

## Called when golfer reaches destination
func _on_reached_destination() -> void:
	if current_state == State.WALKING:
		_change_state(State.PREPARING_SHOT)

## Change state with signal emission
func _change_state(new_state: State) -> void:
	if current_state == new_state:
		return

	var old_state = current_state
	current_state = new_state
	emit_signal("state_changed", old_state, new_state)
	_update_visual()

## Adjust mood
func _adjust_mood(amount: float) -> void:
	var old_mood = current_mood
	current_mood = clamp(current_mood + amount, 0.0, 1.0)

	if abs(old_mood - current_mood) > 0.05:
		EventBus.emit_signal("golfer_mood_changed", golfer_id, current_mood)

## Update visual representation
func _update_visual() -> void:
	if not sprite:
		return

	# Placeholder visual updates
	match current_state:
		State.IDLE:
			modulate = Color.WHITE
		State.WALKING:
			modulate = Color.LIGHT_BLUE
		State.PREPARING_SHOT:
			modulate = Color.YELLOW
		State.SWINGING:
			modulate = Color.ORANGE
		State.FINISHED:
			modulate = Color.GRAY

## Serialize golfer state
func serialize() -> Dictionary:
	return {
		"golfer_id": golfer_id,
		"golfer_name": golfer_name,
		"current_hole": current_hole,
		"total_strokes": total_strokes,
		"current_mood": current_mood,
		"position": {"x": global_position.x, "y": global_position.y}
	}

## Deserialize golfer state
func deserialize(data: Dictionary) -> void:
	golfer_id = data.get("golfer_id", -1)
	golfer_name = data.get("golfer_name", "Golfer")
	current_hole = data.get("current_hole", 0)
	total_strokes = data.get("total_strokes", 0)
	current_mood = data.get("current_mood", 0.5)

	var pos_data = data.get("position", {})
	if pos_data:
		global_position = Vector2(pos_data.get("x", 0), pos_data.get("y", 0))
