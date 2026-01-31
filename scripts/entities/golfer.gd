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
	DRIVER,       # Long distance, lower accuracy (220-300 yards)
	FAIRWAY_WOOD, # Mid-long distance, moderate accuracy (180-250 yards)
	IRON,         # Medium distance, medium accuracy (120-195 yards)
	WEDGE,        # Short distance, high accuracy (30-120 yards)
	PUTTER        # Putting surface, distance-based accuracy (0-90 feet)
}

## Club characteristics (distances in tiles, 1 tile = 15 yards)
const CLUB_STATS = {
	Club.DRIVER: {
		"max_distance": 20,    # tiles (300 yards)
		"min_distance": 15,    # tiles (225 yards)
		"accuracy_modifier": 0.7,
		"name": "Driver"
	},
	Club.FAIRWAY_WOOD: {
		"max_distance": 17,    # tiles (255 yards)
		"min_distance": 12,    # tiles (180 yards)
		"accuracy_modifier": 0.78,
		"name": "Fairway Wood"
	},
	Club.IRON: {
		"max_distance": 13,    # tiles (195 yards)
		"min_distance": 8,     # tiles (120 yards)
		"accuracy_modifier": 0.85,
		"name": "Iron"
	},
	Club.WEDGE: {
		"max_distance": 8,     # tiles (120 yards)
		"min_distance": 2,     # tiles (30 yards)
		"accuracy_modifier": 0.95,
		"name": "Wedge"
	},
	Club.PUTTER: {
		"max_distance": 2,     # tiles (30 yards, ~90 feet)
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
var total_par: int = 0  # Sum of par for all completed holes (for accurate score display)
var ball_position: Vector2i = Vector2i.ZERO
var ball_position_precise: Vector2 = Vector2.ZERO  # Sub-tile precision for putting
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
	EventBus.green_fee_paid.connect(_on_green_fee_paid)

	_update_visual()
	_update_score_display()

func _exit_tree() -> void:
	if EventBus.green_fee_paid.is_connected(_on_green_fee_paid):
		EventBus.green_fee_paid.disconnect(_on_green_fee_paid)

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
	ball_position_precise = Vector2(tee_position)

	var screen_pos = GameManager.terrain_grid.grid_to_screen_center(tee_position) if GameManager.terrain_grid else Vector2.ZERO
	global_position = screen_pos

	EventBus.golfer_started_hole.emit(golfer_id, hole_number)
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

	# Play swing animation before the ball leaves
	await _play_swing_animation()

	var terrain_grid = GameManager.terrain_grid
	var current_terrain = terrain_grid.get_tile(ball_position) if terrain_grid else -1
	var is_putt = current_terrain == TerrainTypes.Type.GREEN

	# Save position before shot for OB stroke-and-distance penalty
	var previous_position = ball_position

	var shot_result: Dictionary

	if is_putt:
		# Use sub-tile precision putting system
		shot_result = _calculate_putt(ball_position_precise)
		ball_position_precise = shot_result.landing_precise
		ball_position = shot_result.landing_position

		# Emit precise putt signal for sub-tile animation
		if terrain_grid:
			var from_screen = terrain_grid.grid_to_screen_precise(shot_result.from_precise)
			var to_screen = terrain_grid.grid_to_screen_precise(shot_result.landing_precise)
			EventBus.ball_putt_landed_precise.emit(golfer_id, from_screen, to_screen, shot_result.distance)
	else:
		# Standard shot calculation
		var from_pos = ball_position
		shot_result = _calculate_shot(ball_position, target)
		ball_position = shot_result.landing_position
		ball_position_precise = Vector2(ball_position)

		# Emit ball landed signal for flight animation
		if terrain_grid:
			EventBus.ball_landed.emit(golfer_id, from_pos, shot_result.landing_position, terrain_grid.get_tile(shot_result.landing_position))

	# Debug output
	var club_name = CLUB_STATS[shot_result.club]["name"]
	var putt_detail = ""
	if is_putt:
		var hole_data = GameManager.course_data.holes[current_hole]
		var dist_to_hole = ball_position_precise.distance_to(Vector2(hole_data.hole_position))
		putt_detail = " (%.1fft to hole)" % (dist_to_hole * 15.0 * 3.0)  # tiles -> yards -> feet
	print("%s (ID:%d) - Hole %d, Stroke %d: %s shot, %d yards, %.1f%% accuracy%s" % [
		golfer_name,
		golfer_id,
		current_hole + 1,
		current_strokes,
		club_name,
		shot_result.distance,
		shot_result.accuracy * 100,
		putt_detail
	])

	# Emit events
	EventBus.shot_taken.emit(golfer_id, current_hole, current_strokes)
	shot_completed.emit(shot_result.distance, shot_result.accuracy)

	# Watch the ball fly before walking to it
	_change_state(State.WATCHING)
	var flight_time = _estimate_flight_duration(shot_result.distance)
	await get_tree().create_timer(flight_time + 0.5).timeout

	# Check for hazards at landing position and apply penalties
	if _handle_hazard_penalty(previous_position):
		await get_tree().create_timer(1.0).timeout

	# Now walk to the ball
	_walk_to_ball()

## Finish current hole
func finish_hole(par: int) -> void:
	total_strokes += current_strokes
	total_par += par

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

	EventBus.golfer_finished_hole.emit(golfer_id, current_hole, current_strokes, par)
	hole_completed.emit(current_strokes, par)

	_update_score_display()
	_change_state(State.IDLE)

## Finish the round
func finish_round() -> void:
	_change_state(State.FINISHED)
	EventBus.golfer_finished_round.emit(golfer_id, total_strokes)

## Select appropriate club based on distance and terrain
func select_club(distance_to_target: float, current_terrain: int) -> Club:
	# If on green, always use putter
	if current_terrain == TerrainTypes.Type.GREEN:
		return Club.PUTTER

	# Allow fringe putting: use putter from nearby off-green lies on easy terrain
	# Real golfers often putt from the fringe or short grass near the green
	if distance_to_target <= CLUB_STATS[Club.PUTTER]["max_distance"]:
		var is_puttable_surface = current_terrain in [
			TerrainTypes.Type.FAIRWAY,
			TerrainTypes.Type.GRASS,
			TerrainTypes.Type.TEE_BOX,
		]
		if is_puttable_surface:
			return Club.PUTTER

	# Select club based on distance (in tiles)
	if distance_to_target >= CLUB_STATS[Club.DRIVER]["min_distance"]:
		return Club.DRIVER
	elif distance_to_target >= CLUB_STATS[Club.FAIRWAY_WOOD]["min_distance"]:
		return Club.FAIRWAY_WOOD
	elif distance_to_target >= CLUB_STATS[Club.IRON]["min_distance"]:
		return Club.IRON
	else:
		return Club.WEDGE

## AI decision making - decide where to aim shot
## Evaluates multiple club options and picks the one with the best landing zone,
## enabling lay-up strategy when hazards make a longer club risky.
func decide_shot_target(hole_position: Vector2i) -> Vector2i:
	var terrain_grid = GameManager.terrain_grid
	if not terrain_grid:
		return hole_position

	var current_terrain = terrain_grid.get_tile(ball_position)

	# Special logic for putting
	if current_terrain == TerrainTypes.Type.GREEN:
		return _decide_putt_target(hole_position)

	# Fringe putting check
	var distance_to_hole = Vector2(ball_position).distance_to(Vector2(hole_position))
	if distance_to_hole <= CLUB_STATS[Club.PUTTER]["max_distance"]:
		var is_puttable = current_terrain in [
			TerrainTypes.Type.FAIRWAY, TerrainTypes.Type.GRASS, TerrainTypes.Type.TEE_BOX,
		]
		if is_puttable:
			return _decide_putt_target(hole_position)

	# Evaluate candidate clubs to find the best overall option (enables lay-up)
	var candidate_clubs: Array[Club] = []
	for club_type in [Club.DRIVER, Club.FAIRWAY_WOOD, Club.IRON, Club.WEDGE]:
		var stats = CLUB_STATS[club_type]
		# Club is a candidate if the hole is within or beyond its min range
		if distance_to_hole >= stats["min_distance"] * 0.7:
			candidate_clubs.append(club_type)

	if candidate_clubs.is_empty():
		candidate_clubs.append(Club.WEDGE)

	var best_club: Club = candidate_clubs[0]
	var best_target: Vector2i = hole_position
	var best_score: float = -9999.0

	for club in candidate_clubs:
		var stats = CLUB_STATS[club]
		var max_dist = stats["max_distance"] * 0.97  # Assume near-full distance
		var target = _find_best_landing_zone(hole_position, max_dist, club)
		var score = _evaluate_landing_zone(target, hole_position, club)

		if score > best_score:
			best_score = score
			best_target = target
			best_club = club

	return best_target

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

		# AI compensates for wind: evaluate where ball will actually land
		var eval_position = test_position
		if GameManager.wind_system:
			var wind_disp = GameManager.wind_system.get_wind_displacement(adjusted_direction, target_distance, club)
			# Better players compensate more accurately
			var compensation = wind_disp * accuracy_skill * 0.7
			eval_position = Vector2i(Vector2(test_position) + wind_disp - compensation)
			if not terrain_grid.is_valid_position(eval_position):
				eval_position = test_position

		var score = _evaluate_landing_zone(eval_position, hole_position, club)
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

## Decide putt target - always aim at the hole
## Actual putt outcome (sub-tile precision, error model) is handled by _calculate_putt
func _decide_putt_target(hole_position: Vector2i) -> Vector2i:
	return hole_position

## Calculate putt with sub-tile precision
## Uses realistic putting model: lateral error (miss left/right of the line),
## distance control (lag putts for long distance), and guaranteed progress toward hole
func _calculate_putt(from_precise: Vector2) -> Dictionary:
	var terrain_grid = GameManager.terrain_grid
	var course_data = GameManager.course_data
	if not terrain_grid or not course_data or course_data.holes.is_empty() or current_hole >= course_data.holes.size():
		return {
			"landing_position": Vector2i(from_precise.round()),
			"landing_precise": from_precise,
			"from_precise": from_precise,
			"distance": 0,
			"accuracy": 1.0,
			"club": Club.PUTTER
		}

	var hole_data = course_data.holes[current_hole]
	var hole_pos = Vector2(hole_data.hole_position)

	var distance = from_precise.distance_to(hole_pos)
	var direction = (hole_pos - from_precise).normalized() if distance > 0.001 else Vector2.ZERO
	var perpendicular = Vector2(-direction.y, direction.x)

	var landing: Vector2

	# Distances in tiles (1 tile = 15 yards = 45 feet):
	#   0.07 tiles =  ~3 feet  (tap-in gimme)
	#   0.15 tiles =  ~7 feet  (short putt)
	#   0.33 tiles = ~15 feet  (mid-range)
	#   0.50 tiles = ~22 feet  (challenging)
	#   1.00 tiles = ~45 feet  (long putt)
	#   2.00 tiles = ~90 feet  (lag putt territory)

	if distance < 0.07:
		# Tap-in gimme — automatic hole-out
		landing = hole_pos

	elif distance < 0.33:
		# Short putt (3-15 feet): high make chance, very small lateral miss
		var normalized_dist = (distance - 0.07) / 0.26
		var skill_factor = 0.6 + putting_skill * 0.4
		var make_chance = lerpf(0.75, 0.15, normalized_dist) * skill_factor
		if randf() < make_chance:
			landing = hole_pos
		else:
			# Missed — ball rolls just past the hole with slight lateral deviation
			var overshoot = randf_range(0.03, 0.15) * (1.2 - putting_skill * 0.4)
			var lateral = randf_range(-0.1, 0.1) * (1.0 - putting_skill * 0.5)
			landing = hole_pos + direction * overshoot + perpendicular * lateral

	elif distance < 1.0:
		# Medium putt (15-45 feet): mostly about distance control, some make chance
		var normalized_dist = (distance - 0.33) / 0.67
		var skill_factor = 0.85 + putting_skill * 0.15
		# Aim to roll the ball to the hole distance, with some error
		var progress_ratio = randf_range(0.80, 1.08) * skill_factor
		progress_ratio = clampf(progress_ratio, 0.60, 1.15)
		var lateral = randf_range(-0.2, 0.2) * (1.0 - putting_skill * 0.3)
		landing = from_precise + direction * distance * progress_ratio + perpendicular * lateral

		# Small chance of holing a medium-length putt
		var hole_chance = lerpf(0.10, 0.02, normalized_dist) * (0.5 + putting_skill * 0.5)
		if randf() < hole_chance:
			landing = hole_pos

	else:
		# Long putt / lag putt (45+ feet): goal is to get close, not hole it
		var skill_factor = 0.80 + putting_skill * 0.20
		var progress_ratio = randf_range(0.60, 0.90) * skill_factor
		var lateral = randf_range(-0.35, 0.35) * (1.0 - putting_skill * 0.2)
		landing = from_precise + direction * distance * progress_ratio + perpendicular * lateral

		# Very small chance of holing a long putt
		var hole_chance = 0.005 * (0.5 + putting_skill * 0.5)
		if randf() < hole_chance:
			landing = hole_pos

	# CRITICAL: Guarantee every putt makes meaningful progress toward the hole
	var new_distance = landing.distance_to(hole_pos)
	if new_distance >= distance:
		if distance >= 0.33:
			# Medium/long putt went sideways or backward — force progress
			var min_progress = 0.30 + putting_skill * 0.20
			landing = from_precise + direction * distance * min_progress
		elif new_distance > 0.25:
			# Short putt miss that ended up unreasonably far — cap it
			landing = hole_pos + (landing - hole_pos).normalized() * 0.20

	# Snap to hole if very close (simulates ball dropping in)
	if landing.distance_to(hole_pos) < 0.07:
		landing = hole_pos

	# Ensure landing stays on green terrain
	var landing_tile = Vector2i(landing.round())
	if not terrain_grid.is_valid_position(landing_tile) or terrain_grid.get_tile(landing_tile) != TerrainTypes.Type.GREEN:
		# Walk back along the putt path to find the last green tile
		var steps = max(int(from_precise.distance_to(landing) * 10.0), 1)
		var last_valid = from_precise
		for i in range(1, steps + 1):
			var t = i / float(steps)
			var check = from_precise.lerp(landing, t)
			var check_tile = Vector2i(check.round())
			if terrain_grid.is_valid_position(check_tile) and terrain_grid.get_tile(check_tile) == TerrainTypes.Type.GREEN:
				last_valid = check
			else:
				break
		landing = last_valid

	var distance_yards = int(from_precise.distance_to(landing) * 15.0)

	return {
		"landing_position": Vector2i(landing.round()),
		"landing_precise": landing,
		"from_precise": from_precise,
		"distance": distance_yards,
		"accuracy": clampf(putting_skill, 0.0, 1.0),
		"club": Club.PUTTER
	}

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
		Club.FAIRWAY_WOOD:
			skill_accuracy = (driving_skill * 0.5 + accuracy_skill * 0.5)
		Club.IRON:
			skill_accuracy = (driving_skill * 0.4 + accuracy_skill * 0.6)
		Club.WEDGE:
			skill_accuracy = (accuracy_skill * 0.7 + recovery_skill * 0.3)
		Club.PUTTER:
			skill_accuracy = putting_skill

	# Combine all accuracy factors
	var base_accuracy = club_stats["accuracy_modifier"]
	var total_accuracy = base_accuracy * skill_accuracy * lie_modifier

	# Short game accuracy boost for wedge shots based on real amateur golfer data
	# Closer wedge shots should be much more accurate regardless of skill level
	# Real-world averages: 20yds ~7yd error, 50yds ~15yd error, 100yds ~20yd error
	if club == Club.WEDGE:
		var distance_ratio = clamp(distance_to_target / float(club_stats["max_distance"]), 0.0, 1.0)
		var short_game_floor = lerpf(0.85, 0.6, distance_ratio)
		total_accuracy = max(total_accuracy, short_game_floor)

	# Putt accuracy floor - even bad putters don't wildly miss short putts
	# Short putts (<1 tile) are nearly automatic, longer putts still require skill
	if club == Club.PUTTER:
		var putt_distance_ratio = clamp(distance_to_target / float(club_stats["max_distance"]), 0.0, 1.0)
		var putt_floor = lerpf(0.95, 0.75, putt_distance_ratio)
		total_accuracy = max(total_accuracy, putt_floor)

	# Distance modifier: base ability + random shot-to-shot variance
	# Skill primarily affects accuracy (above), not raw distance — even high-handicap
	# players swing at full speed, they just miss more. Skill gives a small distance
	# consistency bonus (tighter variance) rather than a large range multiplier.
	var distance_modifier = 1.0
	var shot_variance = 0.0  # Random per-shot variation
	if club == Club.DRIVER:
		var skill_bonus = driving_skill * 0.08         # 0%-8% skill bonus
		shot_variance = randf_range(-0.08, 0.06)       # ±8%/6% random spread
		distance_modifier = 0.92 + skill_bonus + shot_variance  # ~0.84-1.06
	elif club == Club.FAIRWAY_WOOD:
		var skill_bonus = driving_skill * 0.06
		shot_variance = randf_range(-0.06, 0.05)
		distance_modifier = 0.94 + skill_bonus + shot_variance  # ~0.88-1.05
	elif club == Club.IRON:
		var skill_bonus = accuracy_skill * 0.05
		shot_variance = randf_range(-0.05, 0.04)
		distance_modifier = 0.95 + skill_bonus + shot_variance  # ~0.90-1.04
	elif club == Club.WEDGE:
		var skill_bonus = accuracy_skill * 0.03
		shot_variance = randf_range(-0.04, 0.03)
		distance_modifier = 0.97 + skill_bonus + shot_variance  # ~0.93-1.03
	elif club == Club.PUTTER:
		var skill_bonus = putting_skill * 0.02
		shot_variance = randf_range(-0.03, 0.02)
		distance_modifier = 0.98 + skill_bonus + shot_variance  # ~0.95-1.02

	# Apply terrain distance penalty
	var terrain_distance_modifier = _get_terrain_distance_modifier(current_terrain)
	distance_modifier *= terrain_distance_modifier

	# Apply wind headwind/tailwind effect on distance
	if GameManager.wind_system:
		var shot_direction = Vector2(target - from).normalized()
		var wind_distance_mod = GameManager.wind_system.get_distance_modifier(shot_direction, club)
		distance_modifier *= wind_distance_mod

	# Apply elevation effect on distance
	# Uphill = shorter effective distance, downhill = longer
	# ~3% change per elevation unit (~10 feet)
	if terrain_grid:
		var elevation_diff = terrain_grid.get_elevation_difference(from, target)
		var elevation_factor = 1.0 - (elevation_diff * 0.03)
		distance_modifier *= clampf(elevation_factor, 0.75, 1.25)

	# Calculate actual distance
	var intended_distance = Vector2(from).distance_to(Vector2(target))
	var actual_distance = intended_distance * distance_modifier

	# Add directional error using elliptical distribution
	# Real golf dispersion is wider laterally (draw/fade/slice) than long/short
	var error_range = (1.0 - total_accuracy) * 10.0
	var direction = Vector2(target - from).normalized()
	var landing_point = Vector2(from) + (direction * actual_distance)

	# Polar distribution: random angle + distance, stretched laterally
	var error_angle = randf_range(0.0, TAU)
	var error_magnitude = randf_range(0.0, error_range)
	# Perpendicular axis gets 1.5x the error (side-to-side miss is more common)
	var perpendicular = Vector2(-direction.y, direction.x)
	var lateral_error = cos(error_angle) * error_magnitude * 1.5  # Side-to-side
	var longitudinal_error = sin(error_angle) * error_magnitude    # Long/short
	var random_offset = perpendicular * lateral_error + direction * longitudinal_error
	landing_point += random_offset

	# Apply wind displacement
	if GameManager.wind_system:
		var wind_displacement = GameManager.wind_system.get_wind_displacement(direction, actual_distance, club)
		landing_point += wind_displacement

	var landing_position = Vector2i(landing_point.round())

	# Ensure landing position is valid
	if not terrain_grid.is_valid_position(landing_position):
		landing_position = target

	# For putts, ensure ball stays on green or goes in hole
	if club == Club.PUTTER:
		var course_data = GameManager.course_data
		if course_data and not course_data.holes.is_empty() and current_hole < course_data.holes.size():
			var hole_data = course_data.holes[current_hole]
			var hole_position = hole_data.hole_position
			var distance_to_hole = Vector2(landing_position).distance_to(Vector2(hole_position))

			# Check if putt landed on the hole tile
			if distance_to_hole < 1.0:
				landing_position = hole_position
			else:
				var landing_terrain = terrain_grid.get_tile(landing_position)
				if landing_terrain != TerrainTypes.Type.GREEN:
					# Putt went off green - find the last green tile along the path
					var dir = Vector2(landing_position - from).normalized()
					var edge_pos = from
					for i in range(1, int(Vector2(from).distance_to(Vector2(landing_position))) + 1):
						var check = Vector2i((Vector2(from) + dir * i).round())
						if terrain_grid.is_valid_position(check) and terrain_grid.get_tile(check) == TerrainTypes.Type.GREEN:
							edge_pos = check
						else:
							break
					landing_position = edge_pos

	var distance_yards = terrain_grid.calculate_distance_yards(from, landing_position)

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

## Estimate ball flight duration (mirrors BallManager calculation)
func _estimate_flight_duration(distance_yards: int) -> float:
	var duration = 1.0 + (distance_yards / 300.0) * 1.5
	return clampf(duration, 0.5, 3.0)

## Handle hazard penalties (water or OB). Returns true if a penalty was applied.
func _handle_hazard_penalty(previous_position: Vector2i) -> bool:
	var terrain_grid = GameManager.terrain_grid
	if not terrain_grid:
		return false

	var landing_terrain = terrain_grid.get_tile(ball_position)

	if landing_terrain == TerrainTypes.Type.WATER:
		# Water: 1 penalty stroke, drop near the hazard no closer to the hole
		current_strokes += 1
		var drop_position = _find_water_drop_position(ball_position)
		print("%s: Ball in water! Penalty stroke. Dropping near hazard. Now on stroke %d" % [golfer_name, current_strokes])
		EventBus.hazard_penalty.emit(golfer_id, "water", drop_position)
		ball_position = drop_position
		return true

	elif landing_terrain == TerrainTypes.Type.OUT_OF_BOUNDS:
		# OB: 1 penalty stroke, replay from previous position (stroke and distance)
		current_strokes += 1
		print("%s: Ball out of bounds! Penalty stroke. Replaying from previous position. Now on stroke %d" % [golfer_name, current_strokes])
		EventBus.hazard_penalty.emit(golfer_id, "ob", previous_position)
		ball_position = previous_position
		return true

	return false

## Find a valid drop position near a water hazard, no closer to the hole
func _find_water_drop_position(water_position: Vector2i) -> Vector2i:
	var terrain_grid = GameManager.terrain_grid
	if not terrain_grid:
		return water_position

	# Get hole position for "no closer to the hole" rule
	var course_data = GameManager.course_data
	var hole_position = water_position
	if course_data and not course_data.holes.is_empty() and current_hole < course_data.holes.size():
		hole_position = course_data.holes[current_hole].hole_position

	var water_distance_to_hole = Vector2(water_position).distance_to(Vector2(hole_position))

	# Search expanding rings around the water landing spot
	var best_position = water_position
	var best_score = -999.0

	for radius in range(1, 6):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if abs(dx) != radius and abs(dy) != radius:
					continue  # Only check the ring edge

				var candidate = water_position + Vector2i(dx, dy)
				if not terrain_grid.is_valid_position(candidate):
					continue

				var candidate_terrain = terrain_grid.get_tile(candidate)
				# Must be playable terrain
				if candidate_terrain in [TerrainTypes.Type.WATER, TerrainTypes.Type.OUT_OF_BOUNDS]:
					continue

				# Must not be closer to the hole than where ball entered water
				var candidate_distance_to_hole = Vector2(candidate).distance_to(Vector2(hole_position))
				if candidate_distance_to_hole < water_distance_to_hole - 0.5:
					continue

				# Score: prefer fairway/grass, penalize rough/trees
				var score = 0.0
				match candidate_terrain:
					TerrainTypes.Type.FAIRWAY:
						score = 100.0
					TerrainTypes.Type.GRASS, TerrainTypes.Type.TEE_BOX:
						score = 80.0
					TerrainTypes.Type.ROUGH:
						score = 50.0
					TerrainTypes.Type.HEAVY_ROUGH:
						score = 30.0
					TerrainTypes.Type.BUNKER:
						score = 20.0
					TerrainTypes.Type.TREES:
						score = 10.0

				# Prefer closer to the water (shorter walk)
				score -= Vector2(candidate).distance_to(Vector2(water_position)) * 5.0

				if score > best_score:
					best_score = score
					best_position = candidate

		if best_score > 0:
			break  # Found a good spot at this radius

	return best_position

## Walk to ball position
func _walk_to_ball() -> void:
	if not GameManager.terrain_grid:
		return

	# Use sub-tile precision on the green for accurate positioning
	var ball_screen_pos: Vector2
	var current_terrain = GameManager.terrain_grid.get_tile(ball_position)
	if current_terrain == TerrainTypes.Type.GREEN:
		ball_screen_pos = GameManager.terrain_grid.grid_to_screen_precise(ball_position_precise)
	else:
		ball_screen_pos = GameManager.terrain_grid.grid_to_screen_center(ball_position)
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

	if path_distance < 2.5 or not _path_crosses_obstacle(start_grid, end_grid, true):
		# Short distance or no obstacles - go direct
		var result: Array[Vector2] = []
		result.append(target_pos)
		return result

	# Need to pathfind around water
	return _find_path_around_water(start_grid, end_grid)

## Check if path crosses obstacles (water for walking, or trees/water for flight)
## For ball flight, uses parabolic arc: trees only block when the ball is low
## (near takeoff and landing). The ball clears obstacles at mid-flight.
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
			# When flying, water/OB block at any point along the ground path
			if terrain_type == TerrainTypes.Type.WATER or terrain_type == TerrainTypes.Type.OUT_OF_BOUNDS:
				return true
			# Trees only block when the ball is low (first/last 20% of flight)
			# At mid-flight the ball is high enough to clear tree canopy
			if terrain_type == TerrainTypes.Type.TREES:
				if t < 0.2 or t > 0.8:
					return true

	return false

## Find path around water/OB (waypoint system trying both sides at increasing offsets)
func _find_path_around_water(start: Vector2i, end: Vector2i) -> Array[Vector2]:
	var terrain_grid = GameManager.terrain_grid
	var direction = Vector2(end - start).normalized()
	var perpendicular = Vector2(-direction.y, direction.x)  # 90° rotation
	var half_dist = Vector2(start).distance_to(Vector2(end)) / 2.0

	# Try increasing perpendicular offsets on both sides
	for offset in [3, 5, 8, 12]:
		for side in [1.0, -1.0]:
			var mid_offset = direction * half_dist + perpendicular * (offset * side)
			var waypoint = start + Vector2i(mid_offset)

			if not terrain_grid.is_valid_position(waypoint):
				continue

			var wp_terrain = terrain_grid.get_tile(waypoint)
			if wp_terrain == TerrainTypes.Type.WATER or wp_terrain == TerrainTypes.Type.OUT_OF_BOUNDS:
				continue

			# Verify both legs (start→waypoint and waypoint→end) are clear
			if _path_crosses_obstacle(start, waypoint, true):
				continue
			if _path_crosses_obstacle(waypoint, end, true):
				continue

			# Found a clear path through this waypoint
			var result: Array[Vector2] = []
			result.append(terrain_grid.grid_to_screen_center(waypoint))
			result.append(terrain_grid.grid_to_screen_center(end))
			return result

	# No single waypoint works — go direct as fallback
	var result: Array[Vector2] = []
	result.append(terrain_grid.grid_to_screen_center(end))
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
	state_changed.emit(old_state, new_state)
	_update_visual()

## Adjust mood
func _adjust_mood(amount: float) -> void:
	var old_mood = current_mood
	current_mood = clamp(current_mood + amount, 0.0, 1.0)

	if abs(old_mood - current_mood) > 0.05:
		EventBus.golfer_mood_changed.emit(golfer_id, current_mood)

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

	# Calculate score relative to par using actual accumulated par values
	var score_relative_to_par = total_strokes - total_par
	var score_text = ""

	if total_par == 0:
		score_text = "E"  # No holes completed yet
	elif score_relative_to_par == 0:
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
		"total_par": total_par,
		"current_mood": current_mood,
		"position": {"x": global_position.x, "y": global_position.y}
	}

## Deserialize golfer state
func deserialize(data: Dictionary) -> void:
	golfer_id = data.get("golfer_id", -1)
	golfer_name = data.get("golfer_name", "Golfer")
	current_hole = data.get("current_hole", 0)
	total_strokes = data.get("total_strokes", 0)
	total_par = data.get("total_par", 0)
	current_mood = data.get("current_mood", 0.5)

	var pos_data = data.get("position", {})
	if pos_data:
		global_position = Vector2(pos_data.get("x", 0), pos_data.get("y", 0))
