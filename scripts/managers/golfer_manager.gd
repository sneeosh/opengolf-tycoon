extends Node
class_name GolferManager
## GolferManager - Spawns and manages AI golfers on the course

const GOLFER_SCENE = preload("res://scenes/entities/golfer.tscn")

@export var max_concurrent_golfers: int = 8
@export var spawn_interval_seconds: float = 300.0  # 5 minutes game time

var active_golfers: Array[Golfer] = []
var next_golfer_id: int = 0
var next_group_id: int = 0
var time_since_last_spawn: float = 0.0

@onready var golfers_container: Node2D = get_parent().get_node("Entities/Golfers") if get_parent().has_node("Entities/Golfers") else null

signal golfer_spawned(golfer: Golfer)
signal golfer_removed(golfer_id: int)

func _ready() -> void:
	# Connect to EventBus
	EventBus.connect("golfer_finished_round", _on_golfer_finished_round)

func _process(delta: float) -> void:
	if GameManager.game_mode != GameManager.GameMode.SIMULATING:
		return

	# Auto-spawn golfers at intervals
	time_since_last_spawn += delta * GameManager.get_game_speed_multiplier()

	if time_since_last_spawn >= spawn_interval_seconds:
		if active_golfers.size() < max_concurrent_golfers:
			# Spawn a new group
			spawn_initial_group()
		time_since_last_spawn = 0.0

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
	# Check if anyone in the group is currently taking a shot
	var someone_shooting = false
	for golfer in group_golfers:
		if golfer.current_state in [Golfer.State.PREPARING_SHOT, Golfer.State.SWINGING, Golfer.State.WATCHING]:
			someone_shooting = true
			print("DEBUG: %s (ID:%d) is shooting, state=%s" % [golfer.golfer_name, golfer.golfer_id, golfer.current_state])
			break

	# If no one is shooting, determine whose turn it is in this group
	if not someone_shooting:
		# Debug: print all golfer states
		print("DEBUG: No one shooting in group. Golfer states:")
		for golfer in group_golfers:
			print("  - %s (ID:%d): state=%s, strokes=%d, hole=%d" % [
				golfer.golfer_name, golfer.golfer_id, golfer.current_state, golfer.current_strokes, golfer.current_hole
			])

		var next_golfer = _determine_next_golfer_in_group(group_golfers)
		if next_golfer:
			print("DEBUG: Next golfer is %s (ID:%d)" % [next_golfer.golfer_name, next_golfer.golfer_id])
			# Check if landing area is clear before advancing
			if _is_landing_area_clear(next_golfer, group_golfers):
				print("DEBUG: Landing area clear, advancing %s" % next_golfer.golfer_name)
				_advance_golfer(next_golfer)
			else:
				print("DEBUG: Landing area NOT clear for %s" % next_golfer.golfer_name)
		else:
			print("DEBUG: No next golfer determined")

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
		var distance = Vector2(golfer.ball_position).distance_to(Vector2(hole_position))

		if distance > furthest_distance:
			furthest_distance = distance
			furthest_golfer = golfer

	return furthest_golfer if furthest_golfer else golfers[0]

func _is_landing_area_clear(shooting_golfer: Golfer, group_golfers: Array) -> bool:
	"""Check if the landing area is clear of golfers from OTHER groups"""
	var course_data = GameManager.course_data
	if not course_data or course_data.holes.is_empty():
		return true

	if shooting_golfer.current_hole >= course_data.holes.size():
		return true

	var hole_data = course_data.holes[shooting_golfer.current_hole]
	var hole_position = hole_data.hole_position

	# Estimate where the golfer will aim
	var target = shooting_golfer.decide_shot_target(hole_position)

	# Define a landing zone (radius around target)
	const LANDING_ZONE_RADIUS = 15.0  # tiles

	# Check if any golfer from OTHER groups is in the landing zone
	for golfer in active_golfers:
		# Skip golfers in the same group (they play turn-based, only one shoots at a time)
		if golfer.group_id == shooting_golfer.group_id:
			continue

		# Only check golfers who are on the same hole
		if golfer.current_hole != shooting_golfer.current_hole:
			continue

		# Check if golfer is in the landing zone
		var distance_to_target = Vector2(golfer.ball_position).distance_to(Vector2(target))
		if distance_to_target < LANDING_ZONE_RADIUS:
			print("DEBUG: Landing area blocked by %s (ID:%d) from group %d" % [golfer.golfer_name, golfer.golfer_id, golfer.group_id])
			return false  # Landing area is not clear

	return true  # Landing area is clear

func _advance_golfer(golfer: Golfer) -> void:
	"""Advance a specific golfer to their next shot"""
	print("DEBUG: _advance_golfer called for %s (ID:%d)" % [golfer.golfer_name, golfer.golfer_id])

	var course_data = GameManager.course_data
	if not course_data or course_data.holes.is_empty():
		print("DEBUG: No course data or holes")
		return

	var next_hole_index = golfer.current_hole
	if next_hole_index >= course_data.holes.size():
		# Round completed
		print("DEBUG: Round completed for %s" % golfer.golfer_name)
		golfer.finish_round()
		return

	var hole_data = course_data.holes[next_hole_index]

	# Start the hole or prepare for next shot
	if golfer.current_strokes == 0:
		# Starting new hole - move to tee position and prepare for tee shot
		print("DEBUG: Starting hole %d for %s" % [next_hole_index, golfer.golfer_name])
		golfer.start_hole(next_hole_index, hole_data.tee_position)
	else:
		# Already hit at least one shot
		# Check if close enough to hole it
		var hole_position = hole_data.hole_position
		var distance_to_hole = Vector2(golfer.ball_position).distance_to(Vector2(hole_position))

		print("DEBUG: %s at ball, distance to hole: %.1f tiles" % [golfer.golfer_name, distance_to_hole])

		if distance_to_hole < 2.0:
			# Close enough to hole out
			print("DEBUG: %s holing out" % golfer.golfer_name)
			EventBus.emit_signal("ball_in_hole", golfer.golfer_id, hole_data.hole_number)
			golfer.finish_hole(hole_data.par)
			golfer.current_hole += 1
		else:
			# Golfer is already at their ball (walked there after last shot)
			# Just transition to PREPARING_SHOT to start their turn
			print("DEBUG: Transitioning %s to PREPARING_SHOT" % golfer.golfer_name)
			golfer._change_state(Golfer.State.PREPARING_SHOT)

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

	print("Spawned %s: Driving=%.2f, Accuracy=%.2f, Putting=%.2f, Aggression=%.2f" % [
		golfer_name, golfer.driving_skill, golfer.accuracy_skill, golfer.putting_skill, golfer.aggression
	])

	golfers_container.add_child(golfer)
	active_golfers.append(golfer)

	EventBus.emit_signal("golfer_spawned", golfer.golfer_id, golfer_name)
	emit_signal("golfer_spawned", golfer)

	return golfer

## Spawn a random golfer
func spawn_random_golfer(group_id: int = -1) -> Golfer:
	var names = [
		"Tiger", "Jack", "Arnold", "Phil", "Rory", "Jordan", "Brooks",
		"Dustin", "Justin", "Bryson", "Jon", "Collin", "Scottie", "Xander"
	]

	var random_name = names[randi() % names.size()]
	var random_skill = randf_range(0.3, 0.8)

	return spawn_golfer(random_name, random_skill, group_id)

## Spawn initial group of golfers when course opens
func spawn_initial_group() -> void:
	var group_size = randi_range(1, 4)  # Groups of 1-4 players
	var new_group_id = next_group_id
	next_group_id += 1

	print("Spawning initial group of %d golfers (Group %d)" % [group_size, new_group_id])

	for i in range(group_size):
		spawn_random_golfer(new_group_id)
		# Small delay between spawns in the same group
		await get_tree().create_timer(0.5).timeout

## Remove a golfer from the course
func remove_golfer(golfer_id: int) -> void:
	for i in range(active_golfers.size()):
		if active_golfers[i].golfer_id == golfer_id:
			var golfer = active_golfers[i]
			active_golfers.remove_at(i)
			golfer.queue_free()
			EventBus.emit_signal("golfer_left_course", golfer_id)
			emit_signal("golfer_removed", golfer_id)
			return

func _on_golfer_finished_round(golfer_id: int, total_strokes: int) -> void:
	print("Golfer %d finished round with %d strokes" % [golfer_id, total_strokes])

	# Increase reputation based on golfer satisfaction
	var reputation_gain = randi_range(1, 5)
	GameManager.reputation += reputation_gain

	# Remove golfer after a delay
	await get_tree().create_timer(5.0).timeout
	remove_golfer(golfer_id)

## Get all active golfers
func get_active_golfers() -> Array[Golfer]:
	return active_golfers

## Get golfer by ID
func get_golfer(golfer_id: int) -> Golfer:
	for golfer in active_golfers:
		if golfer.golfer_id == golfer_id:
			return golfer
	return null
