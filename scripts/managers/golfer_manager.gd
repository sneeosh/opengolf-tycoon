extends Node
class_name GolferManager
## GolferManager - Spawns and manages AI golfers on the course

const GOLFER_SCENE = preload("res://scenes/entities/golfer.tscn")
const TerrainTypes = preload("res://scripts/terrain/terrain_types.gd")

@export var min_spawn_cooldown_seconds: float = 10.0  # Minimum cooldown between group spawns

var active_golfers: Array[Golfer] = []
var next_golfer_id: int = 0
var next_group_id: int = 0
var time_since_last_spawn: float = 0.0

@onready var golfers_container: Node2D = get_parent().get_node("Entities/Golfers") if get_parent().has_node("Entities/Golfers") else null

signal golfer_spawned(golfer: Golfer)
signal golfer_removed(golfer_id: int)
signal golfer_clicked(golfer: Golfer)

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
	"""Get spawn rate modifier based on course rating, weather, and marketing.
	1 star = 0.5x (fewer golfers), 3 stars = 1x, 5 stars = 1.5x (more golfers)
	Bad weather further reduces spawn rate. Marketing campaigns increase it."""
	var rating = GameManager.course_rating.get("overall", 3.0)
	var base_modifier = 0.5 + (rating - 1.0) * 0.25

	# Apply weather penalty (rain discourages golfers)
	if GameManager.weather_system:
		var weather_modifier = GameManager.weather_system.get_spawn_rate_modifier()
		base_modifier *= weather_modifier

	# Apply marketing bonus (active campaigns attract more golfers)
	if GameManager.marketing_manager:
		var marketing_modifier = GameManager.marketing_manager.get_spawn_rate_modifier()
		base_modifier *= marketing_modifier

	return base_modifier

func get_effective_spawn_cooldown() -> float:
	"""Get spawn cooldown adjusted by course rating.
	Higher rating = shorter cooldown = more golfers."""
	var modifier = get_spawn_rate_modifier()
	# Invert modifier for cooldown (higher rate = shorter cooldown)
	return min_spawn_cooldown_seconds / modifier

## Landing zone constants
const LANDING_ZONE_BASE_RADIUS: float = 2.0    # Minimum radius in tiles (~44 yards)
const LANDING_ZONE_VARIANCE: float = 0.3       # 30% of shot distance added to radius
const TYPICAL_DRIVER_DISTANCE: float = 12.0    # Tiles (~264 yards) for estimating new group spawns

func _get_landing_zone_radius(shot_distance: float) -> float:
	"""Calculate landing zone radius based on shot distance.
	Longer shots have more variance, so larger radius."""
	return LANDING_ZONE_BASE_RADIUS + (shot_distance * LANDING_ZONE_VARIANCE)

func get_max_concurrent_golfers() -> int:
	"""Maximum golfers allowed on the course at once. Scales with hole count.
	1 group (4 golfers) per hole — more holes = more capacity = more revenue."""
	var holes = GameManager.get_open_hole_count()
	return max(4, holes * 4)  # Minimum of 4 (one group even with 1 hole)

func _is_at_golfer_cap() -> bool:
	"""Check if the course has reached its maximum golfer capacity."""
	var non_finished = 0
	for golfer in active_golfers:
		if golfer.current_state != Golfer.State.FINISHED:
			non_finished += 1
	return non_finished >= get_max_concurrent_golfers()

func _is_first_tee_clear() -> bool:
	"""Check if the first tee's landing zone is clear for a new group to spawn.
	Uses a cone-shaped check in the direction of play, so golfers on other holes
	in opposite directions don't block spawning."""
	var course_data = GameManager.course_data
	if not course_data or course_data.holes.is_empty():
		return true

	var first_hole = course_data.holes[0]
	var tee_pos = Vector2(first_hole.tee_position)
	var hole_pos = Vector2(first_hole.hole_position)
	var hole_distance = tee_pos.distance_to(hole_pos)

	# Par 3s: Use green-clear logic instead of landing zone
	# (the entire hole is reachable from the tee, so check if anyone is still playing)
	if first_hole.par == 3:
		return _is_hole_clear_of_earlier_golfers(0)

	# For longer holes: Estimate landing zone using cone-based directional check
	# Cap shot distance to 70% of hole length so we don't check past the green
	var effective_shot_distance = min(TYPICAL_DRIVER_DISTANCE, hole_distance * 0.7)
	var direction = (hole_pos - tee_pos).normalized()
	var landing_target = tee_pos + direction * effective_shot_distance
	var lateral_radius = _get_landing_zone_radius(effective_shot_distance)

	# Cone check: only blocks if golfer is ahead in the direction of play
	return _is_cone_clear_of_golfers(tee_pos, landing_target, lateral_radius, -1, 0)

func _is_hole_clear_of_earlier_golfers(hole_index: int) -> bool:
	"""Check if any golfers from earlier groups are still playing this hole.
	Used for par 3 green-clear checks."""
	for golfer in active_golfers:
		if golfer.current_state == Golfer.State.FINISHED:
			continue
		if golfer.current_hole == hole_index:
			return false  # Someone is still on this hole
	return true

## Cone-based landing zone checking
const LANDING_CONE_HALF_ANGLE: float = PI / 4.0  # 45 degrees - wider cone to catch golfers off the direct line

func _is_cone_clear_of_golfers(origin: Vector2, target: Vector2, lateral_radius: float, exclude_group_id: int, restrict_to_hole: int = -1) -> bool:
	"""Check if a cone-shaped landing zone is clear of golfers from groups ahead.
	The cone extends from origin toward target, with angular spread for shot variance.
	origin: where the shot is taken from
	target: where the shot is aimed (center of landing zone)
	lateral_radius: how far to check perpendicular to the shot line (for near-target checks)
	exclude_group_id: golfers in this group are skipped (-1 to check all groups)
	restrict_to_hole: only check golfers on this hole (-1 to check all holes)"""
	var shot_direction = (target - origin).normalized()
	var shot_distance = origin.distance_to(target)
	# Only check the landing zone area - from 60% of shot distance to shot distance + radius
	# This allows golfers past the landing zone (approaching the green) to not block
	var min_check_distance = shot_distance * 0.6  # Shots rarely land shorter than 60% of target
	var max_check_distance = shot_distance + lateral_radius  # Landing zone extends to target + spread

	for golfer in active_golfers:
		if golfer.current_state == Golfer.State.FINISHED:
			continue

		# Skip golfers in the excluded group (same group as shooter)
		if exclude_group_id >= 0 and golfer.group_id == exclude_group_id:
			continue

		# Only check groups that started before the excluded group (they're ahead)
		# For spawning (exclude_group_id = -1), check all existing golfers
		if exclude_group_id >= 0 and golfer.group_id > exclude_group_id:
			continue

		# Only check golfers on the specified hole (course design handles cross-hole safety)
		if restrict_to_hole >= 0 and golfer.current_hole != restrict_to_hole:
			continue

		var golfer_pos = Vector2(golfer.ball_position)
		var to_golfer = golfer_pos - origin
		var distance_to_golfer = to_golfer.length()

		# Skip if golfer is behind the shooter (negative dot product = opposite direction)
		if to_golfer.dot(shot_direction) < 0:
			continue

		# Skip if golfer is too close (not yet in landing zone) or too far (past landing zone)
		if distance_to_golfer < min_check_distance or distance_to_golfer > max_check_distance:
			continue

		# Check if golfer is within the cone angle
		if distance_to_golfer > 0.1:  # Avoid division by zero
			var angle_to_golfer = shot_direction.angle_to(to_golfer.normalized())
			if abs(angle_to_golfer) > LANDING_CONE_HALF_ANGLE:
				continue

		# Golfer is in the cone - area not clear
		return false

	return true

func _is_area_clear_of_golfers(target: Vector2, radius: float, exclude_group_id: int, restrict_to_hole: int = -1) -> bool:
	"""Check if an area is clear of golfers from groups ahead. (Legacy circular check)
	exclude_group_id: golfers in this group are skipped (-1 to check all groups)
	restrict_to_hole: only check golfers on this hole (-1 to check all holes)"""
	for golfer in active_golfers:
		if golfer.current_state == Golfer.State.FINISHED:
			continue

		# Skip golfers in the excluded group (same group as shooter)
		if exclude_group_id >= 0 and golfer.group_id == exclude_group_id:
			continue

		# Only check groups that started before the excluded group (they're ahead)
		# For spawning (exclude_group_id = -1), check all existing golfers
		if exclude_group_id >= 0 and golfer.group_id > exclude_group_id:
			continue

		# Only check golfers on the specified hole (course design handles cross-hole safety)
		if restrict_to_hole >= 0 and golfer.current_hole != restrict_to_hole:
			continue

		# Check if golfer is in the landing zone
		var golfer_pos = Vector2(golfer.ball_position)
		if golfer_pos.distance_to(target) < radius:
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
			if _is_at_golfer_cap():
				pass  # Course is full — wait for golfers to finish
			elif _is_first_tee_clear():
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

	# Update visual offsets so co-located golfers don't stack
	_update_visual_offsets()

	# Update active golfer highlights
	_update_active_golfer_highlights()

func _update_group(group: Array) -> void:
	"""Update a single group - determine and advance the next golfer to play."""
	# Block if anyone is mid-shot (preparing, swinging, or watching ball)
	for golfer in group:
		if golfer.current_state in [Golfer.State.PREPARING_SHOT, Golfer.State.SWINGING, Golfer.State.WATCHING]:
			return

	var course_data = GameManager.course_data
	var min_hole = _get_group_min_hole(group)

	# First, process any golfers who have holed out and need to clear the green
	# They should leave BEFORE the next player putts
	if min_hole >= 0 and min_hole < course_data.holes.size():
		var hole_data = course_data.holes[min_hole]
		var hole_pos = Vector2(hole_data.hole_position)
		for golfer in group:
			if golfer.current_state == Golfer.State.IDLE and golfer.current_hole == min_hole:
				if HoleManager.is_ball_holed(golfer.ball_position_precise, hole_pos) and golfer.current_strokes > 0:
					# This golfer has holed out - process them to send to next tee
					_advance_golfer(golfer)
					return  # Only process one golfer per frame

	# Check if anyone on the current hole is walking to their ball
	# Golfers walking to the NEXT tee (current_hole > min_hole) shouldn't block putting
	var someone_walking_on_hole = false
	for golfer in group:
		if golfer.current_state == Golfer.State.WALKING and golfer.current_hole == min_hole:
			someone_walking_on_hole = true
			break

	# Get the next golfer to play based on golf rules
	var next_golfer = _determine_next_golfer_in_group(group)
	if not next_golfer:
		return

	var is_tee_shot = next_golfer.current_strokes == 0

	# TEE SHOTS: Can proceed while others walk to their balls (all tee off first)
	# FAIRWAY SHOTS: Wait for everyone to finish walking on THIS hole (away rule)
	if is_tee_shot or not someone_walking_on_hole:
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

func _is_tee_clear_of_other_groups(hole_index: int, current_group_id: int) -> bool:
	"""Check if any other group is actively shooting from this tee.
	Only one group should be teeing off at a time on any given hole."""
	for golfer in active_golfers:
		# Skip golfers in our group or later groups
		if golfer.group_id >= current_group_id:
			continue
		# Skip finished golfers
		if golfer.current_state == Golfer.State.FINISHED:
			continue
		# Check if this golfer is at the same tee and actively shooting
		if golfer.current_hole == hole_index and golfer.current_strokes == 0:
			# Another group is still teeing off on this hole
			if golfer.current_state in [Golfer.State.PREPARING_SHOT, Golfer.State.SWINGING, Golfer.State.WATCHING, Golfer.State.IDLE]:
				return false
	return true

func _is_landing_area_clear(shooting_golfer: Golfer, _group_golfers: Array) -> bool:
	"""Check if the landing area is clear of golfers from groups ahead.
	Uses cone-based directional check - only blocks if golfers are in the direction of the shot."""
	var course_data = GameManager.course_data
	if not course_data or course_data.holes.is_empty():
		return true

	if shooting_golfer.current_hole >= course_data.holes.size():
		return true

	var hole_data = course_data.holes[shooting_golfer.current_hole]
	var hole_position = hole_data.hole_position

	# Tee shot rule: don't tee off if another group is still teeing off on this hole
	if shooting_golfer.current_strokes == 0:
		if not _is_tee_clear_of_other_groups(shooting_golfer.current_hole, shooting_golfer.group_id):
			return false

	# Par 3 tee shot rule: don't tee off until all earlier groups have cleared the green
	if shooting_golfer.current_strokes == 0 and hole_data.par == 3:
		for golfer in active_golfers:
			if golfer.group_id == shooting_golfer.group_id:
				continue
			if golfer.current_state == Golfer.State.FINISHED:
				continue
			if golfer.group_id > shooting_golfer.group_id:
				continue
			if golfer.current_hole == shooting_golfer.current_hole:
				return false  # An earlier group is still on this par 3

	# Get the golfer's intended target and calculate shot distance
	var ball_pos = Vector2(shooting_golfer.ball_position)
	var target = Vector2(shooting_golfer.decide_shot_target(hole_position))

	# Calculate lateral radius for cone check
	var shot_distance = ball_pos.distance_to(target)
	var lateral_radius = _get_landing_zone_radius(shot_distance)

	# Cone-based check: only blocks if golfers are ahead in the shot direction
	return _is_cone_clear_of_golfers(ball_pos, target, lateral_radius, shooting_golfer.group_id, shooting_golfer.current_hole)

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

		# Max stroke limit: triple bogey pickup (pace-of-play rule)
		var max_strokes = GolfRules.get_max_strokes(hole_data.par)
		if golfer.current_strokes >= max_strokes:
			print("%s picking up on hole %d (max %d strokes)" % [golfer.golfer_name, golfer.current_hole + 1, max_strokes])
			golfer.ball_position = hole_position
			golfer.ball_position_precise = Vector2(hole_position)

		if GolfRules.is_ball_holed(golfer.ball_position_precise, Vector2(hole_position)):
			# Close enough to hole out
			var score_name = GolfRules.get_score_name(golfer.current_strokes, hole_data.par)
			print("%s (ID:%d) holes out on hole %d: %d strokes (Par %d) - %s" % [golfer.golfer_name, golfer.golfer_id, golfer.current_hole + 1, golfer.current_strokes, hole_data.par, score_name])
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
	golfer.golfer_selected.connect(_on_golfer_selected)

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

	# Select tier based on course quality, difficulty, and hole count
	var hole_count = GameManager.get_open_hole_count()
	var tier = GolferTier.select_tier(GameManager.course_rating, GameManager.green_fee, GameManager.reputation, hole_count)

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

## Forward golfer click events to main scene
func _on_golfer_selected(golfer: Golfer) -> void:
	golfer_clicked.emit(golfer)

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

## ============================================================================
## VISUAL OFFSET SYSTEM - Prevents golfers from stacking on top of each other
## ============================================================================

const CO_LOCATION_RADIUS: float = 20.0  # Screen pixels — golfers closer than this get offset
const OFFSET_DISTANCE: float = 12.0     # Pixels to spread co-located golfers apart

func _update_visual_offsets() -> void:
	"""Assign small visual offsets to golfers occupying the same tile area,
	so they fan out instead of stacking on top of each other."""
	# Reset all offsets first
	for golfer in active_golfers:
		golfer.visual_offset = Vector2.ZERO

	# Group golfers by proximity (screen position)
	var clusters: Array[Array] = []
	var assigned: Dictionary = {}  # golfer_id -> true

	for i in range(active_golfers.size()):
		var golfer_a = active_golfers[i]
		if golfer_a.golfer_id in assigned:
			continue

		var cluster: Array = [golfer_a]
		assigned[golfer_a.golfer_id] = true

		for j in range(i + 1, active_golfers.size()):
			var golfer_b = active_golfers[j]
			if golfer_b.golfer_id in assigned:
				continue
			if golfer_a.global_position.distance_to(golfer_b.global_position) < CO_LOCATION_RADIUS:
				cluster.append(golfer_b)
				assigned[golfer_b.golfer_id] = true

		if cluster.size() > 1:
			clusters.append(cluster)

	# Apply fan-out offsets to each cluster
	for cluster in clusters:
		var count = cluster.size()
		for idx in range(count):
			# Arrange in a semicircle arc around the shared position
			var angle = PI * 0.3 + (PI * 0.4 / max(count - 1, 1)) * idx
			var offset = Vector2(cos(angle), sin(angle) * 0.5) * OFFSET_DISTANCE
			cluster[idx].visual_offset = offset

func _update_active_golfer_highlights() -> void:
	"""Mark the golfer who is currently taking their shot so they get a highlight ring."""
	for golfer in active_golfers:
		var was_active = golfer.is_active_golfer
		var is_active = golfer.current_state in [
			Golfer.State.PREPARING_SHOT,
			Golfer.State.SWINGING,
			Golfer.State.WATCHING
		]
		golfer.is_active_golfer = is_active
