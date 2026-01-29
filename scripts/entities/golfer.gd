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

enum Club {
	DRIVER,   # Long distance, lower accuracy (250-300 yards)
	IRON,     # Medium distance, medium accuracy (150-200 yards)
	WEDGE,    # Short distance, high accuracy (50-100 yards)
	PUTTER    # Green only, distance-based accuracy (10-40 feet)
}

## Club characteristics
const CLUB_STATS = {
	Club.DRIVER: {
		"max_distance": 60,    # tiles (300 yards at 5 yards/tile)
		"min_distance": 40,    # tiles (200 yards)
		"accuracy_modifier": 0.7,
		"name": "Driver"
	},
	Club.IRON: {
		"max_distance": 40,    # tiles (200 yards)
		"min_distance": 20,    # tiles (100 yards)
		"accuracy_modifier": 0.85,
		"name": "Iron"
	},
	Club.WEDGE: {
		"max_distance": 20,    # tiles (100 yards)
		"min_distance": 4,     # tiles (20 yards)
		"accuracy_modifier": 0.95,
		"name": "Wedge"
	},
	Club.PUTTER: {
		"max_distance": 8,     # tiles (40 yards, ~120 feet)
		"min_distance": 0,     # tiles
		"accuracy_modifier": 0.98,
		"name": "Putter"
	}
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

## Visual components
@onready var visual: Node2D = $Visual if has_node("Visual") else null
@onready var name_label: Label = $InfoContainer/NameLabel if has_node("InfoContainer/NameLabel") else null
@onready var score_label: Label = $InfoContainer/ScoreLabel if has_node("InfoContainer/ScoreLabel") else null
@onready var head: Polygon2D = $Visual/Head if has_node("Visual/Head") else null
@onready var body: Polygon2D = $Visual/Body if has_node("Visual/Body") else null
@onready var arms: Polygon2D = $Visual/Arms if has_node("Visual/Arms") else null

signal state_changed(old_state: State, new_state: State)
signal shot_completed(distance: int, accuracy: float)
signal hole_completed(strokes: int, par: int)

func _ready() -> void:
	# Set up collision layers
	collision_layer = 4  # Layer 3 (golfers)
	collision_mask = 1   # Layer 1 (terrain/obstacles)

	# Set up head as a circle
	if head:
		var head_points = PackedVector2Array()
		for i in range(12):
			var angle = (i / 12.0) * TAU
			var x = cos(angle) * 4
			var y = sin(angle) * 4 - 8  # Offset up to sit on body
			head_points.append(Vector2(x, y))
		head.polygon = head_points

	# Set up labels
	if name_label:
		name_label.text = golfer_name

	_update_visual()
	_update_score_display()

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

	# Simple walking animation - bob up and down
	if visual:
		var bob_amount = sin(Time.get_ticks_msec() / 150.0) * 2.0
		visual.position.y = bob_amount

	# Swing arms while walking
	if arms:
		var swing_amount = sin(Time.get_ticks_msec() / 200.0) * 0.2
		arms.rotation = swing_amount

func _process_preparing_shot(_delta: float) -> void:
	# AI thinks about the shot
	# Could add a thinking timer here
	pass

var swing_animation_playing: bool = false

func _process_swinging(_delta: float) -> void:
	# Play swing animation once
	if not swing_animation_playing and arms:
		swing_animation_playing = true
		_play_swing_animation()

func _play_swing_animation() -> void:
	if not arms:
		return

	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)

	# Backswing
	tween.tween_property(arms, "rotation", 1.2, 0.3)
	# Downswing
	tween.tween_property(arms, "rotation", -0.8, 0.15)
	# Follow through
	tween.tween_property(arms, "rotation", 0.0, 0.2)

	await tween.finished
	swing_animation_playing = false

## Start playing a hole
func start_hole(hole_number: int, tee_position: Vector2i) -> void:
	current_hole = hole_number
	current_strokes = 0
	ball_position = tee_position

	var screen_pos = GameManager.terrain_grid.grid_to_screen(tee_position) if GameManager.terrain_grid else Vector2.ZERO
	global_position = screen_pos

	EventBus.emit_signal("golfer_started_hole", golfer_id, hole_number)
	_update_score_display()
	_change_state(State.PREPARING_SHOT)

## Take a shot
func take_shot(target: Vector2i) -> void:
	current_strokes += 1
	_change_state(State.SWINGING)

	# Calculate shot outcome based on skill and terrain
	var shot_result = _calculate_shot(ball_position, target)

	# Debug output
	var club_name = CLUB_STATS[shot_result.club]["name"]
	print("%s (ID:%d) - Hole %d, Stroke %d: %s shot, %d yards, %.1f%% accuracy" % [
		golfer_name,
		golfer_id,
		current_hole + 1,
		current_strokes,
		club_name,
		shot_result.distance,
		shot_result.accuracy * 100
	])

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

	_update_score_display()
	_change_state(State.IDLE)

## Finish the round
func finish_round() -> void:
	EventBus.emit_signal("golfer_finished_round", golfer_id, total_strokes)
	_change_state(State.FINISHED)

## Select appropriate club based on distance and terrain
func select_club(distance_to_target: float, current_terrain: int) -> Club:
	# If on green, always use putter
	if current_terrain == TerrainTypes.Type.GREEN:
		return Club.PUTTER

	# Select club based on distance (in tiles) - putter only valid on green
	if distance_to_target >= CLUB_STATS[Club.DRIVER]["min_distance"]:
		return Club.DRIVER
	elif distance_to_target >= CLUB_STATS[Club.IRON]["min_distance"]:
		return Club.IRON
	else:
		# For short distances off the green, use wedge (never putter off green)
		return Club.WEDGE

## AI decision making - decide where to aim shot
func decide_shot_target(hole_position: Vector2i) -> Vector2i:
	var terrain_grid = GameManager.terrain_grid
	if not terrain_grid:
		return hole_position

	var distance_to_hole = Vector2(ball_position).distance_to(Vector2(hole_position))
	var current_terrain = terrain_grid.get_tile(ball_position)

	# Select appropriate club
	var club = select_club(distance_to_hole, current_terrain)
	var club_stats = CLUB_STATS[club]

	# Calculate shot distance based on club and skill
	var skill_factor = driving_skill if club == Club.DRIVER else accuracy_skill
	var max_shot_distance = club_stats["max_distance"] * skill_factor

	# Aim for hole if within range, otherwise aim for max distance
	var direction = Vector2(hole_position - ball_position).normalized()
	var shot_distance = min(distance_to_hole, max_shot_distance)

	# Add accuracy variance based on club and skill
	var base_accuracy = club_stats["accuracy_modifier"]
	var skill_accuracy = accuracy_skill if club != Club.DRIVER else (accuracy_skill + driving_skill) / 2.0
	var total_accuracy = base_accuracy * skill_accuracy

	var accuracy_variance = (1.0 - total_accuracy) * 15.0
	var random_offset = Vector2i(
		randi_range(-int(accuracy_variance), int(accuracy_variance)),
		randi_range(-int(accuracy_variance), int(accuracy_variance))
	)

	return ball_position + Vector2i(direction * shot_distance) + random_offset

## Calculate shot outcome
func _calculate_shot(from: Vector2i, target: Vector2i) -> Dictionary:
	var terrain_grid = GameManager.terrain_grid
	if not terrain_grid:
		return {"landing_position": target, "distance": 0, "accuracy": 1.0, "club": Club.DRIVER}

	# Determine club selection
	var current_terrain = terrain_grid.get_tile(from)
	var distance_to_target = Vector2(from).distance_to(Vector2(target))
	var club = select_club(distance_to_target, current_terrain)
	var club_stats = CLUB_STATS[club]

	# Get terrain modifiers
	var lie_modifier = _get_lie_modifier(current_terrain, club)

	# Calculate skill-based accuracy
	var skill_accuracy = 0.0
	match club:
		Club.DRIVER:
			skill_accuracy = (driving_skill * 0.7 + accuracy_skill * 0.3)
		Club.IRON:
			skill_accuracy = (driving_skill * 0.4 + accuracy_skill * 0.6)
		Club.WEDGE:
			skill_accuracy = (accuracy_skill * 0.7 + recovery_skill * 0.3)
		Club.PUTTER:
			skill_accuracy = putting_skill

	# Combine all accuracy factors
	var base_accuracy = club_stats["accuracy_modifier"]
	var total_accuracy = base_accuracy * skill_accuracy * lie_modifier

	# Distance modifier based on club and skill
	var distance_modifier = 1.0
	if club == Club.DRIVER:
		distance_modifier = 0.85 + (driving_skill * 0.3)  # 85%-115% of intended distance
	elif club == Club.IRON:
		distance_modifier = 0.9 + (accuracy_skill * 0.2)  # 90%-110%
	elif club == Club.WEDGE:
		distance_modifier = 0.95 + (accuracy_skill * 0.1)  # 95%-105%
	elif club == Club.PUTTER:
		distance_modifier = 0.98 + (putting_skill * 0.04)  # 98%-102%

	# Apply terrain distance penalty
	var terrain_distance_modifier = _get_terrain_distance_modifier(current_terrain)
	distance_modifier *= terrain_distance_modifier

	# Calculate actual distance
	var intended_distance = Vector2(from).distance_to(Vector2(target))
	var actual_distance = intended_distance * distance_modifier

	# Add directional error based on accuracy
	var error_range = int((1.0 - total_accuracy) * 25.0)
	var direction = Vector2(target - from).normalized()
	var landing_point = Vector2(from) + (direction * actual_distance)

	# Add random offset
	var random_offset = Vector2(
		randf_range(-error_range, error_range),
		randf_range(-error_range, error_range)
	)
	landing_point += random_offset

	var landing_position = Vector2i(landing_point.round())

	# Ensure landing position is valid
	if not terrain_grid.is_valid_position(landing_position):
		landing_position = target

	var distance_yards = terrain_grid.calculate_distance_yards(from, landing_position)

	EventBus.emit_signal("ball_landed", golfer_id, landing_position, terrain_grid.get_tile(landing_position))

	return {
		"landing_position": landing_position,
		"distance": distance_yards,
		"accuracy": total_accuracy,
		"club": club
	}

## Get lie modifier based on terrain type and club
func _get_lie_modifier(terrain_type: int, club: Club) -> float:
	match terrain_type:
		TerrainTypes.Type.GRASS, TerrainTypes.Type.FAIRWAY:
			return 1.0  # Perfect lie
		TerrainTypes.Type.TEE_BOX:
			return 1.05 if club == Club.DRIVER else 1.0  # Slight bonus on tee
		TerrainTypes.Type.GREEN:
			return 1.0  # Putting surface
		TerrainTypes.Type.ROUGH:
			return 0.75  # 25% accuracy penalty
		TerrainTypes.Type.HEAVY_ROUGH:
			return 0.5   # 50% accuracy penalty
		TerrainTypes.Type.BUNKER:
			# Wedges handle sand better
			return 0.6 if club == Club.WEDGE else 0.4
		TerrainTypes.Type.TREES:
			return 0.3   # Very difficult shot
		_:
			return 0.8   # Default penalty

## Get distance modifier based on terrain
func _get_terrain_distance_modifier(terrain_type: int) -> float:
	match terrain_type:
		TerrainTypes.Type.ROUGH:
			return 0.85  # 15% distance loss
		TerrainTypes.Type.HEAVY_ROUGH:
			return 0.7   # 30% distance loss
		TerrainTypes.Type.BUNKER:
			return 0.75  # 25% distance loss
		TerrainTypes.Type.TREES:
			return 0.6   # 40% distance loss (punch out)
		_:
			return 1.0   # No penalty

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
	if not visual:
		return

	# Reset to default pose
	visual.position = Vector2.ZERO
	if arms:
		arms.rotation = 0

	# Update visual based on state
	match current_state:
		State.IDLE:
			if body:
				body.modulate = Color(0.3, 0.6, 0.9, 1)
		State.WALKING:
			if body:
				body.modulate = Color(0.4, 0.7, 1.0, 1)
			# Walk animation handled in _process_walking
		State.PREPARING_SHOT:
			if body:
				body.modulate = Color(1.0, 0.9, 0.3, 1)
			# Golfer is thinking/preparing
		State.SWINGING:
			if arms:
				# Rotate arms to simulate swing
				arms.rotation = -0.5
			if body:
				body.modulate = Color(1.0, 0.6, 0.2, 1)
		State.WATCHING:
			if body:
				body.modulate = Color(0.8, 0.8, 1.0, 1)
		State.PUTTING:
			if body:
				body.modulate = Color(0.5, 1.0, 0.5, 1)
		State.FINISHED:
			if body:
				body.modulate = Color(0.5, 0.5, 0.5, 1)

## Update score display
func _update_score_display() -> void:
	if not score_label:
		return

	# Calculate score relative to par
	var score_relative_to_par = total_strokes - (current_hole * 4)  # Assuming par 4 average
	var score_text = ""

	if score_relative_to_par == 0:
		score_text = "E"  # Even
	elif score_relative_to_par > 0:
		score_text = "+%d" % score_relative_to_par  # Over par
	else:
		score_text = "%d" % score_relative_to_par  # Under par (shows negative)

	# Show current hole
	var hole_text = "Hole %d" % (current_hole + 1)

	score_label.text = "%s, %s" % [score_text, hole_text]

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
