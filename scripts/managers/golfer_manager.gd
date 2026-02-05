extends Node
class_name GolferManager
## GolferManager - Spawns and manages AI golfers on the course

const GOLFER_SCENE = preload("res://scenes/entities/golfer.tscn")

@export var max_concurrent_golfers: int = 8
@export var min_spawn_cooldown_seconds: float = 10.0  # Minimum cooldown between group spawns

var active_golfers: Array[Golfer] = []
var next_golfer_id: int = 0
var next_group_id: int = 0
var time_since_last_spawn: float = 0.0

@onready var golfers_container: Node2D = get_parent().get_node("Entities/Golfers") if get_parent().has_node("Entities/Golfers") else null

signal golfer_spawned(golfer: Golfer)
signal golfer_removed(golfer_id: int)

func _ready() -> void:
	# Connect to EventBus
	EventBus.golfer_finished_round.connect(_on_golfer_finished_round)

func _exit_tree() -> void:
	if EventBus.golfer_finished_round.is_connected(_on_golfer_finished_round):
		EventBus.golfer_finished_round.disconnect(_on_golfer_finished_round)

func get_group_size_weights() -> Array:
	"""Get weighted probabilities for group sizes based on green fee"""
	var fee = GameManager.green_fee

	# Lower fees attract more casual/single golfers
	# Higher fees attract more serious golfers (foursomes)

	if fee < 25:
		# Budget course: More singles and pairs
		return [0.4, 0.3, 0.2, 0.1]  # 40% singles, 30% pairs, 20% threesomes, 10% foursomes
	elif fee < 50:
		# Mid-range: Balanced groups
		return [0.2, 0.3, 0.3, 0.2]  # 20% singles, 30% pairs, 30% threesomes, 20% foursomes
	elif fee < 100:
		# Premium: More foursomes
		return [0.1, 0.2, 0.3, 0.4]  # 10% singles, 20% pairs, 30% threesomes, 40% foursomes
	else:
		# Exclusive: Mostly foursomes
		return [0.05, 0.15, 0.25, 0.55]  # 5% singles, 15% pairs, 25% threesomes, 55% foursomes

func _is_first_tee_clear() -> bool:
	"""Check if the first tee is clear (no golfer on hole 0 still in tee-off sequence)"""
	for golfer in active_golfers:
		if golfer.current_state == Golfer.State.FINISHED:
			continue
		if golfer.current_hole == 0:
			# Block if anyone hasn't teed off yet
			if golfer.current_strokes == 0:
				return false
			# Block if anyone is still mid-shot or walking to their ball
			if golfer.current_state in [Golfer.State.WALKING, Golfer.State.PREPARING_SHOT, Golfer.State.SWINGING, Golfer.State.WATCHING]:
				return false
	return true

func _process(delta: float) -> void:
	if GameManager.game_mode != GameManager.GameMode.SIMULATING:
		return

	# Dynamic spawning: spawn when first tee is clear (with minimum cooldown)
	# Only spawn during open hours
	time_since_last_spawn += delta * GameManager.get_game_speed_multiplier()

	if GameManager.is_course_open():
		if time_since_last_spawn >= min_spawn_cooldown_seconds:
			if active_golfers.size() < max_concurrent_golfers and _is_first_tee_clear():
				spawn_initial_group()
				time_since_last_spawn = 0.0

	# Check if all golfers have left after closing
	_check_end_of_day()

	# Update active golfers
	_update_golfers(delta)

func _update_golfers(delta: float) -> void:
	# Get all unique groups currently on the course
	var groups: Dictionary = {}  # group_id -> Array[Golfer]
	for golfer in active_golfers:
		if golfer.group_id not in groups:
			groups[golfer.group_id] = []
		groups[golfer.group_id].append(golfer)

	# Process each group independently
	for group_id in groups.keys():
		var group_golfers = groups[group_id]
		_update_group(group_golfers)

func _update_group(group_golfers: Array) -> void:
	"""Update a single group of golfers - handle turn-based play within the group"""
	# Check if anyone in the group is currently busy (shooting or walking)
	var someone_busy = false
	for golfer in group_golfers:
		if golfer.current_state in [Golfer.State.PREPARING_SHOT, Golfer.State.SWINGING, Golfer.State.WATCHING, Golfer.State.WALKING]:
			someone_busy = true
			break

	# If no one is busy, determine whose turn it is in this group
	if not someone_busy:
		var next_golfer = _determine_next_golfer_in_group(group_golfers)
		if next_golfer:
			# Check if landing area is clear before advancing
			if _is_landing_area_clear(next_golfer, group_golfers):
				_advance_golfer(next_golfer)

func _determine_next_golfer_in_group(group_golfers: Array) -> Golfer:
	"""Determine which golfer in this group should shoot next"""
	var course_data = GameManager.course_data
	if not course_data or course_data.holes.is_empty():
		return null

	# Get golfers who are ready to play (IDLE state and not finished)
	var ready_golfers: Array[Golfer] = []
	for golfer in group_golfers:
		if golfer.current_state == Golfer.State.IDLE and golfer.current_state != Golfer.State.FINISHED:
			# Check if golfer has holes left to play
			if golfer.current_hole < course_data.holes.size():
				ready_golfers.append(golfer)

	if ready_golfers.is_empty():
		return null

	# Separate golfers on tee vs off tee
	var on_tee: Array[Golfer] = []
	var off_tee: Array[Golfer] = []

	for golfer in ready_golfers:
		if golfer.current_strokes == 0:
			on_tee.append(golfer)
		else:
			off_tee.append(golfer)

	# If golfers are on the tee, they go in order (by golfer_id)
	if not on_tee.is_empty():
		on_tee.sort_custom(func(a, b): return a.golfer_id < b.golfer_id)
		return on_tee[0]

	# After tee shots, use "away" logic (furthest from hole shoots first)
	if not off_tee.is_empty():
		return _get_away_golfer_in_group(off_tee)

	return null

func _get_away_golfer_in_group(golfers: Array[Golfer]) -> Golfer:
	"""Get the golfer in this group who is furthest from the hole"""
	var course_data = GameManager.course_data
	if not course_data or course_data.holes.is_empty():
		return golfers[0]

	var furthest_golfer: Golfer = null
	var furthest_distance: float = -1.0

	for golfer in golfers:
		if golfer.current_hole >= course_data.holes.size():
			continue

		var hole_data = course_data.holes[golfer.current_hole]
		var hole_position = hole_data.hole_position
		var distance = golfer.ball_position_precise.distance_to(Vector2(hole_position))

		if distance > furthest_distance:
			furthest_distance = distance
			furthest_golfer = golfer

	return furthest_golfer if furthest_golfer else golfers[0]

func _is_landing_area_clear(shooting_golfer: Golfer, group_golfers: Array) -> bool:
	"""Check if the landing area is clear of golfers from groups ahead"""
	var course_data = GameManager.course_data
	if not course_data or course_data.holes.is_empty():
		return true

	if shooting_golfer.current_hole >= course_data.holes.size():
		return true

	var hole_data = course_data.holes[shooting_golfer.current_hole]
	var hole_position = hole_data.hole_position

	# Par 3 tee shot rule: don't tee off until all earlier groups have cleared the hole
	if shooting_golfer.current_strokes == 0 and hole_data.par == 3:
		for golfer in active_golfers:
			if golfer.group_id == shooting_golfer.group_id:
				continue
			if golfer.current_state == Golfer.State.FINISHED:
				continue
			# Only check groups that started before us (they're ahead on the course)
			if golfer.group_id > shooting_golfer.group_id:
				continue
			if golfer.current_hole == shooting_golfer.current_hole:
				return false  # An earlier group is still on this par 3

	# Estimate where the golfer will aim
	var target = shooting_golfer.decide_shot_target(hole_position)

	# Define a landing zone (radius around target)
	const LANDING_ZONE_RADIUS = 5.0  # tiles (50 yards at 10 yards/tile)

	# Check if any golfer from EARLIER groups is in the landing zone
	# Only check groups ahead (lower group_id) to prevent deadlocks
	for golfer in active_golfers:
		# Skip golfers in the same group (they play turn-based, only one shoots at a time)
		if golfer.group_id == shooting_golfer.group_id:
			continue

		# Skip finished golfers - they're leaving the course and shouldn't block play
		if golfer.current_state == Golfer.State.FINISHED:
			continue

		# Only check groups that started before us (lower group_id = ahead on course)
		# This prevents circular deadlocks between groups
		if golfer.group_id > shooting_golfer.group_id:
			continue

		# Only check golfers who are on the same hole
		if golfer.current_hole != shooting_golfer.current_hole:
			continue

		# Check if golfer is in the landing zone
		var distance_to_target = Vector2(golfer.ball_position).distance_to(Vector2(target))
		if distance_to_target < LANDING_ZONE_RADIUS:
			return false  # Landing area is not clear

	return true  # Landing area is clear

func _check_end_of_day() -> void:
	"""Check if all golfers have left after course closing, then trigger end of day."""
	if not GameManager.is_end_of_day_pending():
		return
	if active_golfers.is_empty():
		GameManager.request_end_of_day()

func _advance_golfer(golfer: Golfer) -> void:
	"""Advance a specific golfer to their next shot"""
	var course_data = GameManager.course_data
	if not course_data or course_data.holes.is_empty():
		return

	var next_hole_index = golfer.current_hole

	# Skip closed holes when starting a new hole
	if golfer.current_strokes == 0:
		next_hole_index = _find_next_open_hole(next_hole_index, course_data)
		golfer.current_hole = next_hole_index

	if next_hole_index >= course_data.holes.size():
		# Round completed
		golfer.finish_round()
		return

	# Course closing: finish current hole but don't start new ones
	if not GameManager.is_course_open() and golfer.current_strokes == 0:
		golfer.finish_round()
		return

	var hole_data = course_data.holes[next_hole_index]

	# Start the hole or prepare for next shot
	if golfer.current_strokes == 0:
		# For holes after the first, walk from previous green to the next tee
		if next_hole_index > 0 and GameManager.terrain_grid:
			var tee_screen_pos = GameManager.terrain_grid.grid_to_screen_center(hole_data.tee_position)
			var distance_to_tee = golfer.global_position.distance_to(tee_screen_pos)
			if distance_to_tee > 10.0:
				# Walk to the next tee first
				golfer.path = golfer._find_path_to(tee_screen_pos)
				golfer.path_index = 0
				golfer._change_state(Golfer.State.WALKING)
				return
		# At the tee (or first hole) - start the hole
		golfer.start_hole(next_hole_index, hole_data.tee_position)
	else:
		# Already hit at least one shot
		# Check if close enough to hole it (use sub-tile precision for putting accuracy)
		var hole_position = hole_data.hole_position
		var distance_to_hole = golfer.ball_position_precise.distance_to(Vector2(hole_position))

		# Max stroke limit: double par pickup rule (standard in casual golf)
		var max_strokes = hole_data.par * 2
		if golfer.current_strokes >= max_strokes:
			print("%s picking up on hole %d (max %d strokes)" % [golfer.golfer_name, golfer.current_hole + 1, max_strokes])
			golfer.ball_position = hole_position
			golfer.ball_position_precise = Vector2(hole_position)
			distance_to_hole = 0.0

		if distance_to_hole < 0.25:
			# Close enough to hole out (gimme putt ~3.75 yards)
			var score_diff = golfer.current_strokes - hole_data.par
			var score_name = ""
			match score_diff:
				-3: score_name = "Albatross"
				-2: score_name = "Eagle"
				-1: score_name = "Birdie"
				0: score_name = "Par"
				1: score_name = "Bogey"
				2: score_name = "Double Bogey"
				_: score_name = "+%d" % score_diff if score_diff > 0 else "%d" % score_diff
			print("%s holes out on hole %d: %d strokes (Par %d) - %s" % [golfer.golfer_name, golfer.current_hole + 1, golfer.current_strokes, hole_data.par, score_name])
			EventBus.ball_in_hole.emit(golfer.golfer_id, hole_data.hole_number)
			golfer.finish_hole(hole_data.par)
			golfer.current_hole += 1
			golfer.current_strokes = 0

			# Skip any closed holes after finishing
			golfer.current_hole = _find_next_open_hole(golfer.current_hole, course_data)

			# Check if round is complete after advancing to next hole
			if golfer.current_hole >= course_data.holes.size():
				golfer.finish_round()
		else:
			# Golfer is already at their ball (walked there after last shot)
			# Just transition to PREPARING_SHOT to start their turn
			golfer._change_state(Golfer.State.PREPARING_SHOT)

func _find_next_open_hole(from_index: int, course_data: GameManager.CourseData) -> int:
	"""Find the next open hole starting from from_index, skipping closed holes"""
	var index = from_index
	while index < course_data.holes.size():
		if course_data.holes[index].is_open:
			return index
		# Closed hole, skip to next
		index += 1
	return index  # Past end = round complete

## Spawn a new golfer
func spawn_golfer(golfer_name: String, skill_level: float = 0.5, group_id: int = -1) -> Golfer:
	if not golfers_container:
		push_error("No golfers container found")
		return null

	var golfer = GOLFER_SCENE.instantiate() as Golfer
	golfer.golfer_id = next_golfer_id
	next_golfer_id += 1
	golfer.golfer_name = golfer_name
	golfer.group_id = group_id

	# Set skill levels with some randomness
	golfer.driving_skill = clamp(skill_level + randf_range(-0.1, 0.1), 0.0, 1.0)
	golfer.accuracy_skill = clamp(skill_level + randf_range(-0.1, 0.1), 0.0, 1.0)
	golfer.putting_skill = clamp(skill_level + randf_range(-0.1, 0.1), 0.0, 1.0)
	golfer.recovery_skill = clamp(skill_level + randf_range(-0.1, 0.1), 0.0, 1.0)

	# Set personality traits (independent of skill)
	golfer.aggression = randf_range(0.2, 0.9)  # Range from cautious to aggressive
	golfer.patience = randf_range(0.3, 0.8)    # Range from impatient to patient

	golfers_container.add_child(golfer)
	active_golfers.append(golfer)

	# Process green fee payment
	GameManager.process_green_fee_payment(golfer.golfer_id, golfer_name)

	EventBus.golfer_spawned.emit(golfer.golfer_id, golfer_name)
	golfer_spawned.emit(golfer)

	return golfer

## Spawn a random golfer
func spawn_random_golfer(group_id: int = -1) -> Golfer:
	var names = [
		"Tiger", "Jack", "Arnold", "Phil", "Rory", "Jordan", "Brooks",
		"Dustin", "Justin", "Bryson", "Jon", "Collin", "Scottie", "Xander"
	]

	var random_name = names[randi() % names.size()]
	var random_skill = randf_range(0.5, 0.9)  # Increased from 0.3-0.8 to 0.5-0.9

	return spawn_golfer(random_name, random_skill, group_id)

## Spawn initial group of golfers when course opens
func spawn_initial_group() -> void:
	var group_size = _select_weighted_group_size()
	var new_group_id = next_group_id
	next_group_id += 1

	print("New group %d: %d golfers (Fee: $%d)" % [new_group_id, group_size, GameManager.green_fee])

	for i in range(group_size):
		spawn_random_golfer(new_group_id)
		# Small delay between spawns in the same group
		await get_tree().create_timer(0.5).timeout

func _select_weighted_group_size() -> int:
	"""Select group size based on weighted probabilities from green fee"""
	var weights = get_group_size_weights()
	var random_value = randf()
	var cumulative = 0.0

	for i in range(weights.size()):
		cumulative += weights[i]
		if random_value <= cumulative:
			return i + 1  # Return 1-4 (array index 0-3 maps to group size 1-4)

	return 4  # Fallback to foursome

## Remove a golfer from the course
func remove_golfer(golfer_id: int) -> void:
	for i in range(active_golfers.size()):
		if active_golfers[i].golfer_id == golfer_id:
			var golfer = active_golfers[i]
			active_golfers.remove_at(i)
			golfer.queue_free()
			EventBus.golfer_left_course.emit(golfer_id)
			golfer_removed.emit(golfer_id)
			return

func _on_golfer_finished_round(golfer_id: int, total_strokes: int) -> void:
	# Increase reputation based on golfer satisfaction
	var reputation_gain = randi_range(1, 5)
	GameManager.reputation += reputation_gain

	# Find the golfer to get their group_id
	var finished_golfer = get_golfer(golfer_id)
	if not finished_golfer:
		return

	var group_id = finished_golfer.group_id

	# Check if all golfers in this group are finished
	var all_finished = true
	var group_golfers: Array[Golfer] = []
	for golfer in active_golfers:
		if golfer.group_id == group_id:
			group_golfers.append(golfer)
			if golfer.current_state != Golfer.State.FINISHED:
				all_finished = false

	if all_finished:
		# Wait a moment so players can see the group finish
		await get_tree().create_timer(1.0).timeout
		# Remove all golfers in the group
		for golfer in group_golfers:
			remove_golfer(golfer.golfer_id)

## Get all active golfers
func get_active_golfers() -> Array[Golfer]:
	return active_golfers

## Get golfer by ID
func get_golfer(golfer_id: int) -> Golfer:
	for golfer in active_golfers:
		if golfer.golfer_id == golfer_id:
			return golfer
	return null

## Clear all golfers from the course (used when loading saves)
func clear_all_golfers() -> void:
	for golfer in active_golfers:
		golfer.queue_free()
	active_golfers.clear()
	next_golfer_id = 0
	next_group_id = 0
	time_since_last_spawn = 0.0

## Serialize all active golfers
func serialize_golfers() -> Array:
	var data: Array = []
	for golfer in active_golfers:
		data.append(golfer.serialize())
	return data

## Restore golfers from save data
func deserialize_golfers(golfers_data: Array) -> void:
	clear_all_golfers()

	if not golfers_container:
		push_error("No golfers container found")
		return

	var max_id = 0
	var max_group = 0

	for golfer_data in golfers_data:
		# Use the scene to ensure all child nodes are properly created
		var golfer = GOLFER_SCENE.instantiate() as Golfer
		golfers_container.add_child(golfer)
		golfer.deserialize(golfer_data)
		active_golfers.append(golfer)

		# Track max IDs to prevent collisions with new golfers
		if golfer.golfer_id > max_id:
			max_id = golfer.golfer_id
		if golfer.group_id > max_group:
			max_group = golfer.group_id

	next_golfer_id = max_id + 1
	next_group_id = max_group + 1
