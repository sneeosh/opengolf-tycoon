extends Node
class_name GolferManager
## GolferManager - Spawns and manages AI golfers on the course

const GOLFER_SCENE = preload("res://scenes/entities/golfer.tscn")

@export var max_concurrent_golfers: int = 8
@export var spawn_interval_seconds: float = 300.0  # 5 minutes game time

var active_golfers: Array[Golfer] = []
var next_golfer_id: int = 0
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
			spawn_random_golfer()
		time_since_last_spawn = 0.0

	# Update active golfers
	_update_golfers(delta)

func _update_golfers(delta: float) -> void:
	for golfer in active_golfers:
		if golfer.current_state == Golfer.State.IDLE:
			_advance_golfer(golfer)

func _advance_golfer(golfer: Golfer) -> void:
	# Check if golfer should play next hole
	var course_data = GameManager.course_data
	if not course_data or course_data.holes.is_empty():
		return

	var next_hole_index = golfer.current_hole
	if next_hole_index >= course_data.holes.size():
		# Round completed
		golfer.finish_round()
		return

	var hole_data = course_data.holes[next_hole_index]

	# Start the hole or take next shot
	if golfer.current_strokes == 0:
		# Starting new hole
		golfer.start_hole(next_hole_index, hole_data.tee_position)
	else:
		# Take next shot
		_ai_take_shot(golfer, hole_data)

func _ai_take_shot(golfer: Golfer, hole_data: Dictionary) -> void:
	var green_position = hole_data.green_position
	var hole_position = hole_data.hole_position

	# Check if on the green
	var distance_to_hole = Vector2(golfer.ball_position).distance_to(Vector2(hole_position))

	if distance_to_hole < 2.0:
		# Close enough to hole it
		EventBus.emit_signal("ball_in_hole", golfer.golfer_id, hole_data.hole_number)
		golfer.finish_hole(hole_data.par)
		golfer.current_hole += 1
		return

	# AI decides where to aim
	var target = golfer.decide_shot_target(hole_position)
	golfer.take_shot(target)

## Spawn a new golfer
func spawn_golfer(golfer_name: String, skill_level: float = 0.5) -> Golfer:
	if not golfers_container:
		push_error("No golfers container found")
		return null

	var golfer = GOLFER_SCENE.instantiate() as Golfer
	golfer.golfer_id = next_golfer_id
	next_golfer_id += 1
	golfer.golfer_name = golfer_name

	# Set skill levels with some randomness
	golfer.driving_skill = clamp(skill_level + randf_range(-0.1, 0.1), 0.0, 1.0)
	golfer.accuracy_skill = clamp(skill_level + randf_range(-0.1, 0.1), 0.0, 1.0)
	golfer.putting_skill = clamp(skill_level + randf_range(-0.1, 0.1), 0.0, 1.0)
	golfer.recovery_skill = clamp(skill_level + randf_range(-0.1, 0.1), 0.0, 1.0)

	golfers_container.add_child(golfer)
	active_golfers.append(golfer)

	EventBus.emit_signal("golfer_spawned", golfer.golfer_id, golfer_name)
	emit_signal("golfer_spawned", golfer)

	return golfer

## Spawn a random golfer
func spawn_random_golfer() -> Golfer:
	var names = [
		"Tiger", "Jack", "Arnold", "Phil", "Rory", "Jordan", "Brooks",
		"Dustin", "Justin", "Bryson", "Jon", "Collin", "Scottie", "Xander"
	]

	var random_name = names[randi() % names.size()]
	var random_skill = randf_range(0.3, 0.8)

	return spawn_golfer(random_name, random_skill)

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
