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
@export var group_id: int = -1  # Which group this golfer belongs to

## Skill stats (0.0 to 1.0, where 1.0 is best)
@export_range(0.0, 1.0) var driving_skill: float = 0.5
@export_range(0.0, 1.0) var accuracy_skill: float = 0.5
@export_range(0.0, 1.0) var putting_skill: float = 0.5
@export_range(0.0, 1.0) var recovery_skill: float = 0.5

## Personality traits
@export_range(0.0, 1.0) var aggression: float = 0.5  # 0.0 = cautious, 1.0 = aggressive/risky
@export_range(0.0, 1.0) var patience: float = 0.5    # 0.0 = impatient, 1.0 = patient

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

## Shot preparation
var preparation_time: float = 0.0
const PREPARATION_DURATION: float = 1.0  # 1 second to prepare shot

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

	# Connect to green fee payment signal
	EventBus.connect("green_fee_paid", _on_green_fee_paid)

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

func _process_preparing_shot(delta: float) -> void:
	# AI thinks about the shot
	preparation_time += delta

	if preparation_time >= PREPARATION_DURATION:
		preparation_time = 0.0
		# Ready to take shot - let AI decide target
		_take_ai_shot()

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

## AI automatically takes shot based on current hole
func _take_ai_shot() -> void:
	# Get current hole data
	var course_data = GameManager.course_data
	if not course_data or course_data.holes.is_empty():
		print("No course data available for shot")
		return

	if current_hole >= course_data.holes.size():
		print("Hole index out of range")
		return

	var hole_data = course_data.holes[current_hole]
	var hole_position = hole_data.hole_position

	# Decide where to aim
	var target = decide_shot_target(hole_position)

	# Take the shot
	take_shot(target)

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

	var current_terrain = terrain_grid.get_tile(ball_position)

	# Special logic for putting
	if current_terrain == TerrainTypes.Type.GREEN:
		return _decide_putt_target(hole_position)

	# Select appropriate club
	var distance_to_hole = Vector2(ball_position).distance_to(Vector2(hole_position))
	var club = select_club(distance_to_hole, current_terrain)
	var club_stats = CLUB_STATS[club]

	# Calculate ideal shot distance
	var skill_factor = driving_skill if club == Club.DRIVER else accuracy_skill
	var max_shot_distance = club_stats["max_distance"] * skill_factor

	# Find best landing target
	return _find_best_landing_zone(hole_position, max_shot_distance, club)

## Find best landing zone considering fairways and hazards
func _find_best_landing_zone(hole_position: Vector2i, max_distance: float, club: Club) -> Vector2i:
	var terrain_grid = GameManager.terrain_grid
	if not terrain_grid:
		return hole_position

	var direction_to_hole = Vector2(hole_position - ball_position).normalized()
	var distance_to_hole = Vector2(ball_position).distance_to(Vector2(hole_position))

	# Determine target distance (layup vs go for it)
	var target_distance = min(distance_to_hole, max_distance)

	# Aggressive players go for max distance more often
	if aggression > 0.7 and distance_to_hole > max_distance * 0.8:
		target_distance = max_distance

	# Evaluate potential landing zones
	var best_target = hole_position
	var best_score = -999.0

	# Sample points along the line to the hole
	var num_samples = 5
	for i in range(num_samples):
		var test_distance = target_distance * (0.7 + (i / float(num_samples)) * 0.6)  # 70% to 130% of target
		var test_position = ball_position + Vector2i(direction_to_hole * test_distance)

		if not terrain_grid.is_valid_position(test_position):
			continue

		var score = _evaluate_landing_zone(test_position, hole_position, club)
		if score > best_score:
			best_score = score
			best_target = test_position

	# Also consider slight left/right adjustments to avoid hazards
	for offset_angle in [-0.05, 0.0, 0.05]:  # -3°, 0°, +3° (reduced from ±8.5° for straighter shots)
		var adjusted_direction = direction_to_hole.rotated(offset_angle)
		var test_position = ball_position + Vector2i(adjusted_direction * target_distance)

		if not terrain_grid.is_valid_position(test_position):
			continue

		var score = _evaluate_landing_zone(test_position, hole_position, club)
		if score > best_score:
			best_score = score
			best_target = test_position

	return best_target

## Evaluate how good a landing zone is
func _evaluate_landing_zone(position: Vector2i, hole_position: Vector2i, club: Club) -> float:
	var terrain_grid = GameManager.terrain_grid
	if not terrain_grid:
		return 0.0

	# Check if shot path will hit trees or water mid-flight
	if _path_crosses_obstacle(ball_position, position, false):
		return -2000.0  # NEVER hit trees or water mid-flight!

	var terrain_type = terrain_grid.get_tile(position)
	var score = 0.0

	# Score based on terrain type
	match terrain_type:
		TerrainTypes.Type.FAIRWAY:
			score += 100.0  # Best landing zone
		TerrainTypes.Type.GREEN:
			score += 120.0  # Even better if we can reach green
		TerrainTypes.Type.GRASS:
			score += 80.0   # Decent
		TerrainTypes.Type.ROUGH:
			score += 30.0   # Not ideal
		TerrainTypes.Type.HEAVY_ROUGH:
			score += 10.0   # Bad
		TerrainTypes.Type.BUNKER:
			score -= 20.0   # Avoid if possible
		TerrainTypes.Type.WATER:
			score -= 1000.0 # Avoid at all costs!
		TerrainTypes.Type.OUT_OF_BOUNDS:
			score -= 1000.0 # Never go OB
		TerrainTypes.Type.TREES:
			score -= 50.0   # Avoid trees

	# Bonus for getting closer to hole
	var distance_to_hole = Vector2(position).distance_to(Vector2(hole_position))
	var current_distance_to_hole = Vector2(ball_position).distance_to(Vector2(hole_position))

	# Strong penalty if shot doesn't move us closer to the hole
	if distance_to_hole >= current_distance_to_hole:
		score -= 500.0  # Large penalty for shots that don't advance towards the hole

	score -= distance_to_hole * 4.0  # Increased from 2.0 to 4.0 - strongly prefer closer to hole

	# Personality adjustments
	if aggression < 0.3:  # Cautious players heavily penalize hazards
		if terrain_type == TerrainTypes.Type.BUNKER:
			score -= 80.0
		if terrain_type == TerrainTypes.Type.ROUGH or terrain_type == TerrainTypes.Type.HEAVY_ROUGH:
			score -= 30.0

	# Check surrounding tiles for hazards (risky if near water/OB)
	var hazard_penalty = 0.0
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			if dx == 0 and dy == 0:
				continue
			var check_pos = position + Vector2i(dx, dy)
			if not terrain_grid.is_valid_position(check_pos):
				continue

			var nearby_terrain = terrain_grid.get_tile(check_pos)
			if nearby_terrain == TerrainTypes.Type.WATER or nearby_terrain == TerrainTypes.Type.OUT_OF_BOUNDS:
				hazard_penalty += 20.0 * (1.0 - aggression)  # Cautious players avoid being near hazards

	score -= hazard_penalty

	return score

## Decide putt target with green reading
func _decide_putt_target(hole_position: Vector2i) -> Vector2i:
	var terrain_grid = GameManager.terrain_grid
	if not terrain_grid:
		return hole_position

	var distance_to_hole = Vector2(ball_position).distance_to(Vector2(hole_position))

	# For very short putts, just aim for the hole
	if distance_to_hole < 1.5:
		return hole_position

	# For longer putts, aim slightly past the hole (never up short!)
	# "Never up, never in" - golf wisdom
	var direction = Vector2(hole_position - ball_position).normalized()

	# Add 5-15% extra distance based on putting skill (better putters are more precise)
	var extra_distance = 0.05 + (0.10 * (1.0 - putting_skill))
	var target_distance = distance_to_hole * (1.0 + extra_distance)

	var putt_target = ball_position + Vector2i(direction * target_distance)

	# Ensure target is still on green
	if not terrain_grid.is_valid_position(putt_target) or terrain_grid.get_tile(putt_target) != TerrainTypes.Type.GREEN:
		return hole_position

	return putt_target

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
	var error_range = int((1.0 - total_accuracy) * 10.0)  # Reduced from 25.0 to 10.0 for better accuracy
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

## Simple pathfinding with terrain awareness
func _find_path_to(target_pos: Vector2) -> Array[Vector2]:
	var terrain_grid = GameManager.terrain_grid
	if not terrain_grid:
		var result: Array[Vector2] = []
		result.append(target_pos)
		return result

	# Convert to grid positions
	var start_grid = terrain_grid.screen_to_grid(global_position)
	var end_grid = terrain_grid.screen_to_grid(target_pos)

	# Check if path crosses water or is short enough to go direct
	var path_distance = Vector2(start_grid).distance_to(Vector2(end_grid))

	if path_distance < 5.0 or not _path_crosses_obstacle(start_grid, end_grid, true):
		# Short distance or no obstacles - go direct
		var result: Array[Vector2] = []
		result.append(target_pos)
		return result

	# Need to pathfind around water
	return _find_path_around_water(start_grid, end_grid)

## Check if path crosses obstacles (water for walking, or trees/water for flight)
func _path_crosses_obstacle(start: Vector2i, end: Vector2i, walking: bool) -> bool:
	var terrain_grid = GameManager.terrain_grid
	if not terrain_grid:
		return false

	# Sample points along the line
	var distance = Vector2(start).distance_to(Vector2(end))
	var num_samples = int(distance) + 1

	for i in range(num_samples):
		var t = i / float(num_samples)
		var sample_pos = Vector2i(Vector2(start).lerp(Vector2(end), t))

		if not terrain_grid.is_valid_position(sample_pos):
			continue

		var terrain_type = terrain_grid.get_tile(sample_pos)

		if walking:
			# When walking, only avoid water and OB
			if terrain_type == TerrainTypes.Type.WATER or terrain_type == TerrainTypes.Type.OUT_OF_BOUNDS:
				return true
		else:
			# When flying (shot), avoid trees too
			if terrain_type == TerrainTypes.Type.WATER or terrain_type == TerrainTypes.Type.OUT_OF_BOUNDS or terrain_type == TerrainTypes.Type.TREES:
				return true

	return false

## Find path around water (simple waypoint system)
func _find_path_around_water(start: Vector2i, end: Vector2i) -> Array[Vector2]:
	var terrain_grid = GameManager.terrain_grid
	var result: Array[Vector2] = []

	# Try going around left or right
	var direction = Vector2(end - start).normalized()
	var perpendicular = Vector2(-direction.y, direction.x)  # 90° rotation

	# Try offset to the left
	var waypoint_left = start + Vector2i(direction * Vector2(start).distance_to(Vector2(end)) / 2.0 + perpendicular * 10)
	if terrain_grid.is_valid_position(waypoint_left) and terrain_grid.get_tile(waypoint_left) != TerrainTypes.Type.WATER:
		result.append(terrain_grid.grid_to_screen(waypoint_left))

	# Add final destination
	result.append(terrain_grid.grid_to_screen(end))

	# If path is still bad, just go direct and hope for the best
	if result.is_empty():
		result.append(terrain_grid.grid_to_screen(end))

	return result

## Called when golfer reaches destination
func _on_reached_destination() -> void:
	if current_state == State.WALKING:
		# Transition to IDLE and wait for turn system to advance us
		_change_state(State.IDLE)

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

## Handle green fee payment notification
func _on_green_fee_paid(paid_golfer_id: int, paid_golfer_name: String, amount: int) -> void:
	# Only show notification for this specific golfer
	if paid_golfer_id == golfer_id:
		show_payment_notification(amount)

## Show floating payment notification above golfer
func show_payment_notification(amount: int) -> void:
	# Create a temporary label for the notification
	var notification = Label.new()
	notification.text = "+$%d" % amount
	notification.modulate = Color(0.2, 1.0, 0.2, 1.0)  # Green color
	notification.position = Vector2(0, -40)  # Above the golfer's head

	# Set label properties
	notification.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notification.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	notification.add_theme_font_size_override("font_size", 14)

	add_child(notification)

	# Animate the notification
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(notification, "position:y", -60, 1.5)  # Float up
	tween.tween_property(notification, "modulate:a", 0.0, 1.5)  # Fade out

	# Remove the notification when done
	tween.finished.connect(func(): notification.queue_free())

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
