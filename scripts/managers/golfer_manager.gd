extends Node
class_name GolferManager
## GolferManager - Spawns and manages AI golfers on the course

const GOLFER_SCENE = preload("res://scenes/entities/golfer.tscn")
const TerrainTypes = preload("res://scripts/terrain/terrain_types.gd")

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

func get_spawn_rate_modifier() -> float:
	"""Get spawn rate modifier based on course rating and weather.
	1 star = 0.5x (fewer golfers), 3 stars = 1x, 5 stars = 1.5x (more golfers)
	Bad weather further reduces spawn rate."""
	var rating = GameManager.course_rating.get("overall", 3.0)
	var base_modifier = 0.5 + (rating - 1.0) * 0.25

	# Apply weather penalty (rain discourages golfers)
	if GameManager.weather_system:
		var weather_modifier = GameManager.weather_system.get_spawn_rate_modifier()
		base_modifier *= weather_modifier

	return base_modifier

func get_effective_spawn_cooldown() -> float:
	"""Get spawn cooldown adjusted by course rating.
	Higher rating = shorter cooldown = more golfers."""
	var modifier = get_spawn_rate_modifier()
	# Invert modifier for cooldown (higher rate = shorter cooldown)
	return min_spawn_cooldown_seconds / modifier

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

	# Don't spawn regular golfers during tournaments
	var tournament_active = GameManager.tournament_manager and GameManager.tournament_manager.is_tournament_in_progress()

	if GameManager.is_course_open() and not tournament_active:
		var effective_cooldown = get_effective_spawn_cooldown()
		if time_since_last_spawn >= effective_cooldown:
			if active_golfers.size() < max_concurrent_golfers and _is_first_tee_clear():
				spawn_initial_group()
				time_since_last_spawn = 0.0

	# Check if all golfers have left after closing
	_check_end_of_day()

	# Update active golfers
	_update_golfers(delta)

func _update_golfers(_delta: float) -> void:
	# Build groups dictionary
	var groups: Dictionary = {}  # group_id -> Array[Golfer]
	for golfer in active_golfers:
		if golfer.group_id not in groups:
			groups[golfer.group_id] = []
		groups[golfer.group_id].append(golfer)

	# Process groups in deterministic order (sorted by group_id)
	# This ensures consistent behavior across frames
	var sorted_group_ids = groups.keys()
	sorted_group_ids.sort()
	for group_id in sorted_group_ids:
		_update_group(groups[group_id])

func _update_group(group: Array) -> void:
	"""Update a single group - determine and advance the next golfer to play."""
	# Block if anyone is mid-shot (preparing, swinging, or watching ball)
	for golfer in group:
		if golfer.current_state in [Golfer.State.PREPARING_SHOT, Golfer.State.SWINGING, Golfer.State.WATCHING]:
			return

	# Get the next golfer to play based on golf rules
	var next_golfer = _determine_next_golfer_in_group(group)
	if not next_golfer:
		return

	var is_tee_shot = next_golfer.current_strokes == 0

	# Check if anyone is walking
	var someone_walking = false
	for golfer in group:
		if golfer.current_state == Golfer.State.WALKING:
			someone_walking = true
			break

	# TEE SHOTS: Can proceed while others walk to their balls (all tee off first)
	# FAIRWAY SHOTS: Wait for everyone to finish walking (then apply away rule)
	if is_tee_shot or not someone_walking:
		if _is_landing_area_clear(next_golfer, group):
			_advance_golfer(next_golfer)

## ============================================================================
## GOLF TURN ORDER RULES (based on USGA etiquette)
## ============================================================================
## 1. HOLE PROGRESSION: Groups play together - all must finish hole N before
##    anyone starts hole N+1.
## 2. TEE ORDER (Honor System):
##    - Hole 1: Golfers tee off in golfer_id order (deterministic)
##    - Later holes: Golfer with best (lowest) score on previous hole has "honor"
##      and tees off first. Ties retain previous order.
## 3. FAIRWAY/GREEN (Away Rule): Golfer furthest from the hole plays first.
## ============================================================================

func _get_group_min_hole(group: Array) -> int:
	"""Find the minimum hole being played by any non-finished golfer in the group."""
	var min_hole: int = 999
	for golfer in group:
		if golfer.current_state != Golfer.State.FINISHED:
			if golfer.current_hole < min_hole:
				min_hole = golfer.current_hole
	return min_hole if min_hole < 999 else -1

func _get_honor_golfer(golfers: Array[Golfer], current_hole: int) -> Golfer:
	"""Get the golfer with honor (best score on previous hole) for tee shots."""
	if golfers.is_empty():
		return null

	if current_hole == 0:
		# First hole: tee off in golfer_id order (deterministic)
		golfers.sort_custom(func(a, b): return a.golfer_id < b.golfer_id)
		return golfers[0]

	# Honor system: lowest previous_hole_strokes goes first
	# Ties: retain order by golfer_id (earlier spawned = earlier in order)
	golfers.sort_custom(func(a, b):
		if a.previous_hole_strokes != b.previous_hole_strokes:
			return a.previous_hole_strokes < b.previous_hole_strokes
		return a.golfer_id < b.golfer_id
	)
	return golfers[0]

func _get_away_golfer(golfers: Array[Golfer], hole_index: int) -> Golfer:
	"""Get the golfer furthest from the hole (away rule)."""
	if golfers.is_empty():
		return null

	var course_data = GameManager.course_data
	if not course_data or hole_index >= course_data.holes.size():
		return golfers[0]

	var hole_pos = Vector2(course_data.holes[hole_index].hole_position)
	var furthest: Golfer = null
	var max_dist: float = -1.0

	for golfer in golfers:
		var dist = golfer.ball_position_precise.distance_to(hole_pos)
		if dist > max_dist:
			max_dist = dist
			furthest = golfer

	return furthest if furthest else golfers[0]

func _determine_next_golfer_in_group(group_golfers: Array) -> Golfer:
	"""Determine which golfer in this group should shoot next using golf rules."""
	var course_data = GameManager.course_data
	if not course_data or course_data.holes.is_empty():
		return null

	# 1. Find the minimum hole (group stays together)
	var min_hole = _get_group_min_hole(group_golfers)
	if min_hole == -1:
		return null  # Everyone is finished

	# 2. Get golfers who are IDLE and on the minimum hole
	var eligible: Array[Golfer] = []
	for golfer in group_golfers:
		if golfer.current_state == Golfer.State.IDLE:
			if golfer.current_hole == min_hole:
				if golfer.current_hole < course_data.holes.size():
					eligible.append(golfer)

	if eligible.is_empty():
		return null

	# 3. Separate tee shots from fairway/green shots
	var on_tee: Array[Golfer] = []
	var on_fairway: Array[Golfer] = []

	for golfer in eligible:
		if golfer.current_strokes == 0:
			on_tee.append(golfer)
		else:
			on_fairway.append(golfer)

	# 4. Tee shots: Honor system (best score on previous hole)
	if not on_tee.is_empty():
		return _get_honor_golfer(on_tee, min_hole)

	# 5. Fairway/green: Away rule (furthest from hole)
	if not on_fairway.is_empty():
		return _get_away_golfer(on_fairway, min_hole)

	return null

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
	const LANDING_ZONE_RADIUS = 5.0  # tiles (110 yards at 22 yards/tile)

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

		# Check if ball is on the green (last shot was a putt/chip)
		var ball_terrain = GameManager.terrain_grid.get_tile(golfer.ball_position) if GameManager.terrain_grid else -1
		var is_on_green = ball_terrain == TerrainTypes.Type.GREEN

		# Gimme distance depends on whether this was a putt or approach shot
		# Putts: 0.25 tiles (~5.5 yards) - standard gimme distance
		# Approach shots: must land essentially in the hole (0.05 tiles ~1 yard)
		# with a tiny chance of holing out from farther (hole-in-one magic)
		var gimme_distance = 0.25 if is_on_green else 0.05

		# Rare hole-out from approach: ~1 in 3000 chance if within 0.25 tiles
		# (Real golf hole-in-one odds are ~1 in 12,500 for amateurs)
		if not is_on_green and distance_to_hole < 0.25 and distance_to_hole >= 0.05:
			if randf() < 0.0003:  # 0.03% chance
				gimme_distance = 0.25  # Allow the hole-out

		if distance_to_hole < gimme_distance:
			# Close enough to hole out
			var score_diff = golfer.current_strokes - hole_data.par
			var score_name = ""
			if golfer.current_strokes == 1:
				score_name = "Hole-in-One"
			else:
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
				return

			# If course is closed, don't start a new hole - finish the round
			if not GameManager.is_course_open():
				golfer.finish_round()
				return

			# Immediately walk to the next tee to clear the green
			# Don't wait for turn - golfers should move off the green right away
			if GameManager.terrain_grid and golfer.current_hole < course_data.holes.size():
				var next_hole_data = course_data.holes[golfer.current_hole]
				# Update ball position to next tee immediately to prevent visual glitch
				# where ball briefly appears at old hole position while walking
				golfer.ball_position = next_hole_data.tee_position
				golfer.ball_position_precise = Vector2(next_hole_data.tee_position)
				var tee_screen_pos = GameManager.terrain_grid.grid_to_screen_center(next_hole_data.tee_position)
				golfer.path = golfer._find_path_to(tee_screen_pos)
				golfer.path_index = 0
				golfer._change_state(Golfer.State.WALKING)
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

	# Set miss tendency: lower skill = stronger bias, random hook vs slice
	var tendency_magnitude = (1.0 - skill_level) * randf_range(0.2, 0.7)
	golfer.miss_tendency = tendency_magnitude * (1.0 if randf() > 0.5 else -1.0)

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

## Spawn a random golfer with tier-based skills
func spawn_random_golfer(group_id: int = -1) -> Golfer:
	var names = [
		"Tiger", "Jack", "Arnold", "Phil", "Rory", "Jordan", "Brooks",
		"Dustin", "Justin", "Bryson", "Jon", "Collin", "Scottie", "Xander"
	]

	# Select tier based on course quality and difficulty
	var tier = GolferTier.select_tier(GameManager.course_rating, GameManager.green_fee, GameManager.reputation)

	# Build name with tier-appropriate prefix
	var base_name = names[randi() % names.size()]
	var prefix = GolferTier.get_name_prefix(tier)
	var full_name = prefix + " " + base_name if prefix != "" else base_name

	# Spawn with default skill (will be overridden by initialize_from_tier)
	var golfer = spawn_golfer(full_name, 0.5, group_id)
	if golfer:
		golfer.initialize_from_tier(tier)
		print("Spawned %s (%s tier)" % [full_name, GolferTier.get_tier_name(tier)])

	return golfer

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
	# Find the golfer to get their tier and group_id
	var finished_golfer = get_golfer(golfer_id)
	if not finished_golfer:
		return

	# Record tier for daily statistics
	GameManager.daily_stats.record_golfer_tier(finished_golfer.golfer_tier)

	# Tier-based reputation gain
	var reputation_gain = GolferTier.get_reputation_gain(finished_golfer.golfer_tier)

	# Pro golfers give bonus reputation if they had a good round
	if finished_golfer.golfer_tier == GolferTier.Tier.PRO:
		var score_to_par = total_strokes - finished_golfer.total_par
		if score_to_par <= 0:
			reputation_gain *= 2  # Double rep for pro under par

	# Apply prestige multiplier (harder courses with good ratings = more reputation)
	var prestige_mult = CourseRatingSystem.get_prestige_multiplier(GameManager.course_rating)
	reputation_gain = int(float(reputation_gain) * prestige_mult)

	GameManager.modify_reputation(reputation_gain)

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
