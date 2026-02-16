extends CharacterBody2D
class_name Golfer
## Golfer - Base class for AI golfers playing the course

enum State {
	IDLE,           # Waiting to start or for turn
	WALKING,        # Moving to next position
	PREPARING_SHOT, # Lining up shot
	SWINGING,       # Taking a shot
	WATCHING,       # Watching ball flight
	FINISHED        # Completed round
}

enum Club {
	DRIVER,       # Long distance, lower accuracy (220-308 yards)
	FAIRWAY_WOOD, # Mid-long distance, moderate accuracy (176-242 yards)
	IRON,         # Medium distance, medium accuracy (110-198 yards)
	WEDGE,        # Short distance, high accuracy (44-110 yards)
	PUTTER        # Putting surface, distance-based accuracy (0-66 feet)
}

## Club characteristics (distances in tiles, 1 tile = 22 yards)
const CLUB_STATS = {
	Club.DRIVER: {
		"max_distance": 14,    # tiles (308 yards)
		"min_distance": 10,    # tiles (220 yards)
		"accuracy_modifier": 0.7,
		"name": "Driver"
	},
	Club.FAIRWAY_WOOD: {
		"max_distance": 11,    # tiles (242 yards)
		"min_distance": 8,     # tiles (176 yards)
		"accuracy_modifier": 0.78,
		"name": "Fairway Wood"
	},
	Club.IRON: {
		"max_distance": 9,     # tiles (198 yards)
		"min_distance": 5,     # tiles (110 yards)
		"accuracy_modifier": 0.85,
		"name": "Iron"
	},
	Club.WEDGE: {
		"max_distance": 5,     # tiles (110 yards)
		"min_distance": 2,     # tiles (44 yards)
		"accuracy_modifier": 0.95,
		"name": "Wedge"
	},
	Club.PUTTER: {
		"max_distance": 1,     # tiles (22 yards, ~66 feet)
		"min_distance": 0,     # tiles
		"accuracy_modifier": 0.98,
		"name": "Putter"
	}
}

## Golfer identification
@export var golfer_name: String = "Golfer"
@export var golfer_id: int = -1
@export var group_id: int = -1  # Which group this golfer belongs to

## Golfer tier (Beginner, Casual, Serious, Pro)
var golfer_tier: int = GolferTier.Tier.CASUAL

## Skill stats (0.0 to 1.0, where 1.0 is best)
@export_range(0.0, 1.0) var driving_skill: float = 0.5
@export_range(0.0, 1.0) var accuracy_skill: float = 0.5
@export_range(0.0, 1.0) var putting_skill: float = 0.5
@export_range(0.0, 1.0) var recovery_skill: float = 0.5

## Personality traits
@export_range(0.0, 1.0) var aggression: float = 0.5  # 0.0 = cautious, 1.0 = aggressive/risky
@export_range(0.0, 1.0) var patience: float = 0.5    # 0.0 = impatient, 1.0 = patient

## Shot shape tendency: -1.0 = strong hook bias, +1.0 = strong slice bias, 0.0 = neutral
## Beginners have stronger tendencies; pros are more neutral
var miss_tendency: float = 0.0

## Current state
var current_state: State = State.IDLE
var current_mood: float = 0.5  # 0.0 = angry, 1.0 = happy
var fatigue: float = 0.0       # 0.0 = fresh, 1.0 = exhausted

## Course progress
var current_hole: int = 0
var current_strokes: int = 0
var total_strokes: int = 0
var total_par: int = 0  # Sum of par for all completed holes (for accurate score display)
var previous_hole_strokes: int = 0  # Strokes on last completed hole (for honor system)
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

## Building interaction tracking (for proximity-based revenue)
var _visited_buildings: Dictionary = {}  # instance_id -> true

## Z-ordering: visual offset to prevent stacking when golfers share a tile
var visual_offset: Vector2 = Vector2.ZERO

## Active golfer highlight (shows who is currently taking their shot)
var is_active_golfer: bool = false
var _highlight_ring: Polygon2D = null

## Visual components
@onready var visual: Node2D = $Visual if has_node("Visual") else null
@onready var name_label: Label = $InfoContainer/NameLabel if has_node("InfoContainer/NameLabel") else null
@onready var score_label: Label = $InfoContainer/ScoreLabel if has_node("InfoContainer/ScoreLabel") else null
@onready var head: Polygon2D = $Visual/Head if has_node("Visual/Head") else null
@onready var body: Polygon2D = $Visual/Body if has_node("Visual/Body") else null
@onready var arms: Polygon2D = $Visual/Arms if has_node("Visual/Arms") else null
@onready var legs: Polygon2D = $Visual/Legs if has_node("Visual/Legs") else null
@onready var shoes: Polygon2D = $Visual/Shoes if has_node("Visual/Shoes") else null
@onready var collar: Polygon2D = $Visual/Collar if has_node("Visual/Collar") else null
@onready var hands: Polygon2D = $Visual/Hands if has_node("Visual/Hands") else null
@onready var hair: Polygon2D = $Visual/Hair if has_node("Visual/Hair") else null
@onready var cap: Polygon2D = $Visual/Cap if has_node("Visual/Cap") else null
@onready var cap_brim: Polygon2D = $Visual/CapBrim if has_node("Visual/CapBrim") else null
@onready var golf_club: Node2D = $Visual/GolfClub if has_node("Visual/GolfClub") else null

## Golfer appearance colors (randomized on spawn)
var shirt_color: Color = Color(0.9, 0.35, 0.35)
var pants_color: Color = Color(0.25, 0.25, 0.35)
var cap_color: Color = Color(0.2, 0.4, 0.7)
var hair_color: Color = Color(0.3, 0.2, 0.1)
var skin_tone: Color = Color(0.95, 0.8, 0.65)

## Thought bubble feedback system
var _last_thought_time: float = 0.0
const THOUGHT_COOLDOWN: float = 3.0  # Seconds between thoughts (in real time)

signal state_changed(old_state: State, new_state: State)
signal shot_completed(distance: int, accuracy: float)
signal hole_completed(strokes: int, par: int)

func _ready() -> void:
	# Set up collision layers
	collision_layer = 4  # Layer 3 (golfers)
	collision_mask = 1   # Layer 1 (terrain/obstacles)

	# Randomize golfer appearance
	_randomize_appearance()

	# Set up head as a circle
	if head:
		var head_points = PackedVector2Array()
		for i in range(12):
			var angle = (i / 12.0) * TAU
			var x = cos(angle) * 5
			var y = sin(angle) * 5 - 9  # Offset up to sit on body
			head_points.append(Vector2(x, y))
		head.polygon = head_points
		head.color = skin_tone

	# Apply randomized colors to visual components
	_apply_appearance()

	# Set up labels
	if name_label:
		name_label.text = golfer_name

	# Create highlight ring for active golfer indication
	_create_highlight_ring()

	# Connect to green fee payment signal
	EventBus.green_fee_paid.connect(_on_green_fee_paid)

	_update_visual()
	_update_score_display()

## Randomize golfer appearance with variety
func _randomize_appearance() -> void:
	# Shirt colors - bright polo shirt colors
	var shirt_colors = [
		Color(0.9, 0.35, 0.35),   # Red
		Color(0.35, 0.6, 0.9),    # Blue
		Color(0.35, 0.8, 0.45),   # Green
		Color(0.9, 0.75, 0.3),    # Yellow/Gold
		Color(0.8, 0.45, 0.7),    # Pink
		Color(0.95, 0.55, 0.3),   # Orange
		Color(0.5, 0.35, 0.7),    # Purple
		Color(0.3, 0.7, 0.7),     # Teal
		Color(0.95, 0.95, 0.95),  # White
		Color(0.15, 0.15, 0.2),   # Navy
	]
	shirt_color = shirt_colors[randi() % shirt_colors.size()]

	# Pants colors - khakis, navy, white, gray
	var pants_colors = [
		Color(0.7, 0.6, 0.45),    # Khaki
		Color(0.25, 0.25, 0.35),  # Navy
		Color(0.9, 0.9, 0.88),    # White/cream
		Color(0.4, 0.4, 0.4),     # Gray
		Color(0.2, 0.2, 0.2),     # Black
	]
	pants_color = pants_colors[randi() % pants_colors.size()]

	# Cap colors - match or complement shirt
	var cap_colors = [
		Color(0.95, 0.95, 0.95),  # White
		Color(0.15, 0.15, 0.2),   # Navy
		Color(0.2, 0.2, 0.2),     # Black
		Color(0.9, 0.35, 0.35),   # Red
		Color(0.35, 0.6, 0.9),    # Blue
		Color(0.35, 0.7, 0.4),    # Green
	]
	cap_color = cap_colors[randi() % cap_colors.size()]

	# Hair colors
	var hair_colors = [
		Color(0.3, 0.2, 0.1),     # Brown
		Color(0.15, 0.1, 0.05),   # Dark brown
		Color(0.9, 0.8, 0.5),     # Blonde
		Color(0.1, 0.1, 0.1),     # Black
		Color(0.5, 0.3, 0.2),     # Auburn
		Color(0.7, 0.7, 0.7),     # Gray/white
	]
	hair_color = hair_colors[randi() % hair_colors.size()]

	# Skin tones
	var skin_tones = [
		Color(0.95, 0.82, 0.68),  # Light
		Color(0.87, 0.72, 0.55),  # Medium light
		Color(0.75, 0.58, 0.42),  # Medium
		Color(0.6, 0.45, 0.32),   # Medium dark
		Color(0.45, 0.32, 0.22),  # Dark
	]
	skin_tone = skin_tones[randi() % skin_tones.size()]

## Apply appearance colors to visual components
func _apply_appearance() -> void:
	if body:
		body.color = shirt_color
	if legs:
		legs.color = pants_color
	if cap:
		cap.color = cap_color
	if cap_brim:
		# Slightly darker than cap
		cap_brim.color = cap_color.darkened(0.2)
	if hair:
		hair.color = hair_color
	if head:
		head.color = skin_tone
	if arms:
		arms.color = skin_tone
	if hands:
		hands.color = skin_tone

func _exit_tree() -> void:
	if EventBus.green_fee_paid.is_connected(_on_green_fee_paid):
		EventBus.green_fee_paid.disconnect(_on_green_fee_paid)

## Initialize golfer from a tier (sets skills and personality)
func initialize_from_tier(tier: int) -> void:
	golfer_tier = tier

	# Generate skills based on tier
	var skills = GolferTier.generate_skills(tier)
	driving_skill = skills.driving
	accuracy_skill = skills.accuracy
	putting_skill = skills.putting
	recovery_skill = skills.recovery
	miss_tendency = skills.miss_tendency

	# Set personality based on tier
	var personality = GolferTier.get_personality(tier)
	aggression = personality.aggression
	patience = personality.patience

func _process(delta: float) -> void:
	_update_highlight_ring()
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

	# Apply terrain speed modifier (cart paths are faster)
	var effective_speed = walk_speed
	var terrain_grid = GameManager.terrain_grid
	if terrain_grid:
		var current_grid_pos = terrain_grid.screen_to_grid(global_position)
		var terrain_type = terrain_grid.get_tile(current_grid_pos)
		effective_speed *= TerrainTypes.get_speed_modifier(terrain_type)

	velocity = direction * effective_speed
	move_and_slide()

	# Check for building proximity (revenue/satisfaction effects)
	_check_building_proximity()

	# Simple walking animation - bob up and down, preserving visual offset
	if visual:
		var bob_amount = sin(Time.get_ticks_msec() / 150.0) * 1.5
		visual.position = visual_offset + Vector2(0, bob_amount)

	# Swing arms while walking
	var swing_amount = sin(Time.get_ticks_msec() / 200.0) * 0.15
	if arms:
		arms.rotation = swing_amount
	if hands:
		hands.rotation = swing_amount

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

	# Show the golf club during swing
	if golf_club:
		golf_club.visible = true

	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_parallel(true)

	# Backswing - arms and club rotate back
	tween.tween_property(arms, "rotation", 1.0, 0.3)
	if hands:
		tween.tween_property(hands, "rotation", 1.0, 0.3)
	if golf_club:
		tween.tween_property(golf_club, "rotation", -1.5, 0.3)

	tween.chain().set_parallel(true)

	# Downswing - fast forward swing
	tween.tween_property(arms, "rotation", -0.6, 0.12)
	if hands:
		tween.tween_property(hands, "rotation", -0.6, 0.12)
	if golf_club:
		tween.tween_property(golf_club, "rotation", 0.8, 0.12)

	tween.chain().set_parallel(true)

	# Follow through
	tween.tween_property(arms, "rotation", 0.0, 0.25)
	if hands:
		tween.tween_property(hands, "rotation", 0.0, 0.25)
	if golf_club:
		tween.tween_property(golf_club, "rotation", 0.3, 0.25)

	await tween.finished
	swing_animation_playing = false

## Start playing a hole
func start_hole(hole_number: int, tee_position: Vector2i) -> void:
	current_hole = hole_number
	current_strokes = 0
	ball_position = tee_position
	ball_position_precise = Vector2(tee_position)
	# Clear visited buildings at start of round
	if hole_number == 0:
		_visited_buildings.clear()

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
	# Use rounded precise position for terrain check to handle sub-tile edge cases
	var terrain_check_pos = Vector2i(ball_position_precise.round()) if terrain_grid else ball_position
	var current_terrain = terrain_grid.get_tile(terrain_check_pos) if terrain_grid else -1
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
		var from_precise = ball_position_precise
		shot_result = _calculate_shot(ball_position, target)
		ball_position = shot_result.landing_position
		ball_position_precise = shot_result.landing_position_precise

		# Check if this is a chip-in using unified hole detection
		var hole_data_for_anim = GameManager.course_data.holes[current_hole]
		var hole_pos_vec = Vector2(hole_data_for_anim.hole_position)
		var is_chip_in = HoleManager.is_ball_holed(ball_position_precise, hole_pos_vec)

		# For chip-ins, snap ball position to hole (like putts do) and skip rollout
		if is_chip_in:
			ball_position = hole_data_for_anim.hole_position
			ball_position_precise = hole_pos_vec

		# Emit precise ball landed signal for sub-tile flight + rollout animation
		# carry_screen = where ball first hits ground (end of flight arc)
		# to_screen = final resting position (after rollout)
		if terrain_grid:
			var from_screen = terrain_grid.grid_to_screen_precise(from_precise)
			var carry_screen: Vector2
			var to_screen: Vector2
			if is_chip_in:
				carry_screen = terrain_grid.grid_to_screen_precise(hole_pos_vec)
				to_screen = carry_screen
			else:
				carry_screen = terrain_grid.grid_to_screen_precise(shot_result.carry_position_precise)
				to_screen = terrain_grid.grid_to_screen_precise(shot_result.landing_position_precise)
			EventBus.ball_shot_landed_precise.emit(golfer_id, from_screen, to_screen, shot_result.distance, carry_screen)

	# Debug output
	var club_name = CLUB_STATS[shot_result.club]["name"]
	var extra_detail = ""
	if is_putt:
		var hole_pos = GameManager.course_data.holes[current_hole].hole_position
		var dist_to_hole_debug = ball_position_precise.distance_to(Vector2(hole_pos))
		extra_detail = " (%.1fft to hole)" % (dist_to_hole_debug * 22.0 * 3.0)  # tiles -> yards -> feet
	elif shot_result.get("rollout_tiles", 0.0) > 0.0:
		var roll_yards = shot_result.rollout_tiles * 22.0
		var spin_label = " BACKSPIN" if shot_result.get("is_backspin", false) else ""
		extra_detail = " (%.0fyd rollout%s)" % [roll_yards, spin_label]
	print("%s (ID:%d) - Hole %d, Stroke %d: %s shot, %d yards, %.1f%% accuracy%s" % [
		golfer_name,
		golfer_id,
		current_hole + 1,
		current_strokes,
		club_name,
		shot_result.distance,
		shot_result.accuracy * 100,
		extra_detail
	])

	# Emit events
	EventBus.shot_taken.emit(golfer_id, current_hole, current_strokes)
	shot_completed.emit(shot_result.distance, shot_result.accuracy)

	# Check if ball will land in the hole - schedule hide for when animation completes
	var hole_data = GameManager.course_data.holes[current_hole]
	var ball_holed = HoleManager.is_ball_holed(ball_position_precise, Vector2(hole_data.hole_position))

	if ball_holed:
		# Calculate animation duration to match BallManager's putt/shot animation
		var anim_duration: float
		if is_putt:
			anim_duration = 0.3 + (shot_result.distance / 100.0) * 0.7
			anim_duration = clampf(anim_duration, 0.3, 1.5)
		else:
			anim_duration = 1.0 + (shot_result.distance / 300.0) * 1.5
			anim_duration = clampf(anim_duration, 0.5, 3.0)
		# Hide ball when animation reaches the hole
		var hole_num = hole_data.hole_number
		var gid = golfer_id
		get_tree().create_timer(anim_duration).timeout.connect(
			func(): EventBus.ball_in_hole.emit(gid, hole_num)
		)

	# Watch the ball fly (and roll) before walking to it
	_change_state(State.WATCHING)
	var flight_time = _estimate_flight_duration(shot_result.distance)
	var rollout_time = _estimate_rollout_duration(shot_result.get("rollout_tiles", 0.0))
	await get_tree().create_timer(flight_time + rollout_time + 0.5).timeout

	# Check for hazards at landing position and apply penalties (skip if ball holed)
	if not ball_holed and _handle_hazard_penalty(previous_position):
		await get_tree().create_timer(1.0).timeout

	# Walk to the ball (or to the hole to grab it if holed)
	_walk_to_ball()

## Finish current hole
func finish_hole(par: int) -> void:
	total_strokes += current_strokes
	total_par += par
	previous_hole_strokes = current_strokes  # Store for honor system on next tee

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

	# Show thought bubble for notable scores
	var score_trigger = FeedbackTriggers.get_score_trigger(current_strokes, par)
	if score_trigger != -1:
		show_thought(score_trigger)

	# Check for records
	var records = GameManager.check_hole_records(golfer_name, current_hole, current_strokes)
	for record in records:
		if record.type == "hole_in_one":
			# Spawn celebration effect
			HoleInOneCelebration.create_at(get_parent(), global_position)

	EventBus.golfer_finished_hole.emit(golfer_id, current_hole, current_strokes, par)
	hole_completed.emit(current_strokes, par)

	_update_score_display()
	_change_state(State.IDLE)

## Finish the round
func finish_round() -> void:
	_change_state(State.FINISHED)

	# Check for course record
	GameManager.check_round_record(golfer_name, total_strokes)

	# Apply clubhouse effects (golfer visits clubhouse after round)
	_apply_clubhouse_effects()

	# Show course satisfaction feedback
	var course_trigger = FeedbackTriggers.get_course_trigger(total_strokes, total_par)
	if course_trigger != -1:
		show_thought(course_trigger)

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

	# Check if shot path will hit trees mid-flight (low ball near takeoff/landing)
	if _path_crosses_obstacle(ball_position, position, false):
		return -2000.0  # Trees block low-altitude flight!

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

	# Distances in tiles (1 tile = 22 yards = 66 feet):
	#   0.07 tiles  = ~5 feet   (tap-in gimme)
	#   0.33 tiles  = ~22 feet  (mid-range)
	#   0.50 tiles  = ~33 feet  (challenging)
	#   1.00 tiles  = ~66 feet  (long putt / lag putt)
	const PUTT_GIMME: float = 0.07  # ~5 feet - automatic tap-in for putts

	if distance < PUTT_GIMME:
		# Tap-in — ball is already within the cup radius
		landing = hole_pos

	elif distance < 0.33:
		# Short putt: ball rolls just past the hole with slight lateral deviation
		# If landing is within PUTT_GIMME (~5 feet), it drops in
		var overshoot = randf_range(0.03, 0.15) * (1.2 - putting_skill * 0.4)
		var lateral = randf_range(-0.1, 0.1) * (1.0 - putting_skill * 0.5)
		landing = hole_pos + direction * overshoot + perpendicular * lateral

	elif distance < 1.0:
		# Medium putt (15-45 feet): mostly about distance control
		var skill_factor = 0.85 + putting_skill * 0.15
		var progress_ratio = randf_range(0.80, 1.08) * skill_factor
		progress_ratio = clampf(progress_ratio, 0.60, 1.15)
		var lateral = randf_range(-0.2, 0.2) * (1.0 - putting_skill * 0.3)
		landing = from_precise + direction * distance * progress_ratio + perpendicular * lateral

	else:
		# Long putt / lag putt (45+ feet): goal is to get close, not hole it
		var skill_factor = 0.80 + putting_skill * 0.20
		var progress_ratio = randf_range(0.60, 0.90) * skill_factor
		var lateral = randf_range(-0.35, 0.35) * (1.0 - putting_skill * 0.2)
		landing = from_precise + direction * distance * progress_ratio + perpendicular * lateral

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
		else:
			# Very short putt that somehow didn't progress — force minimum advance
			var min_advance = 0.05 + putting_skill * 0.05
			landing = from_precise + direction * max(distance * 0.5, min_advance)

	# Snap to hole if ball lands within putt gimme distance (~5 feet)
	if landing.distance_to(hole_pos) < PUTT_GIMME:
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

	var distance_yards = int(from_precise.distance_to(landing) * 22.0)

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
	# At 22 yards/tile: 50yds = ~2.3 tiles, shots under 50yds should hit green most of the time
	if club == Club.WEDGE:
		var distance_ratio = clamp(distance_to_target / float(club_stats["max_distance"]), 0.0, 1.0)
		# Much higher floor for close shots: 0.96 at point blank, 0.80 at max wedge distance
		var short_game_floor = lerpf(0.96, 0.80, distance_ratio)
		total_accuracy = max(total_accuracy, short_game_floor)

	# Putt accuracy floor - scales with putting skill
	# Short putts still have high floor, but low-skill golfers struggle more on long putts
	if club == Club.PUTTER:
		var putt_distance_ratio = clamp(distance_to_target / float(club_stats["max_distance"]), 0.0, 1.0)
		# Scale floor based on putting skill:
		# Low skill (0.3): 50% to 85% floor range
		# High skill (0.95): 80% to 95% floor range
		var skill_floor_min = lerpf(0.50, 0.80, putting_skill)
		var skill_floor_max = lerpf(0.85, 0.95, putting_skill)
		var putt_floor = lerpf(skill_floor_max, skill_floor_min, putt_distance_ratio)
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

	# Angular dispersion model - realistic miss patterns (hooks, slices, shanks)
	# Instead of uniform random offset, we rotate the shot direction by an error
	# angle sampled from a bell curve. This means:
	#   - Most shots land near the target line (small angular miss)
	#   - Occasional big hooks/slices (tail of the distribution)
	#   - Misses scale naturally with distance (same angle = more yards off at range)
	#   - Each golfer has a consistent miss tendency (slice or hook bias)
	var direction = Vector2(target - from).normalized()

	# Max angular spread based on inaccuracy (degrees)
	# Worst case ~12° = severe slice/hook, pro-level ~1.2° = tight dispersion
	var max_spread_deg = (1.0 - total_accuracy) * 12.0
	var spread_std_dev = max_spread_deg / 2.5  # ~95% of shots within max_spread

	# Reduce spread for controlled partial swings (short wedges)
	if club == Club.WEDGE:
		var wedge_distance_ratio = clamp(actual_distance / float(club_stats["max_distance"]), 0.0, 1.0)
		spread_std_dev *= lerpf(0.3, 1.0, wedge_distance_ratio)

	# Sample miss angle from gaussian distribution (bell curve, not uniform)
	var base_angle_deg = _gaussian_random() * spread_std_dev

	# Apply golfer's natural miss tendency (consistent slice or hook bias)
	# Lower accuracy amplifies the tendency — skilled players compensate better
	var tendency_strength = miss_tendency * (1.0 - total_accuracy) * 6.0
	var miss_angle_deg = base_angle_deg + tendency_strength

	# Rare shank: catastrophic sideways miss (only on full swings, not putts/wedges)
	# ~5% for worst beginners, <0.5% for pros
	if club != Club.PUTTER and club != Club.WEDGE:
		var shank_chance = (1.0 - total_accuracy) * 0.06
		if randf() < shank_chance:
			var shank_dir = 1.0 if miss_tendency >= 0.0 else -1.0
			miss_angle_deg = shank_dir * randf_range(35.0, 55.0)
			actual_distance *= randf_range(0.3, 0.6)

	# Rotate direction by miss angle
	var miss_angle_rad = deg_to_rad(miss_angle_deg)
	var miss_direction = direction.rotated(miss_angle_rad)
	var landing_point = Vector2(from) + (miss_direction * actual_distance)

	# Distance error: topped/fat shots lose distance (never gain)
	# Bell curve - most shots near full distance, occasional chunk/top
	var distance_loss = absf(_gaussian_random()) * (1.0 - total_accuracy) * 0.12
	landing_point -= miss_direction * (actual_distance * distance_loss)

	# Apply wind displacement
	if GameManager.wind_system:
		var wind_displacement = GameManager.wind_system.get_wind_displacement(direction, actual_distance, club)
		landing_point += wind_displacement

	# Keep sub-tile precision - use round for accurate grid cell
	# This is the CARRY position (where ball first contacts the ground)
	var carry_position_precise = landing_point
	var carry_position = Vector2i(landing_point.round())

	# Ensure carry position is valid
	if not terrain_grid.is_valid_position(carry_position):
		carry_position = target
		carry_position_precise = Vector2(target)

	# For putts, ensure ball stays on green or goes in hole (no rollout on putts)
	if club == Club.PUTTER:
		var course_data = GameManager.course_data
		if course_data and not course_data.holes.is_empty() and current_hole < course_data.holes.size():
			var hole_data = course_data.holes[current_hole]
			var hole_position = hole_data.hole_position
			var distance_to_hole = Vector2(carry_position).distance_to(Vector2(hole_position))

			# Check if putt landed on the hole tile
			if distance_to_hole < 1.0:
				carry_position = hole_position
			else:
				var landing_terrain = terrain_grid.get_tile(carry_position)
				if landing_terrain != TerrainTypes.Type.GREEN:
					# Putt went off green - find the last green tile along the path
					var dir = Vector2(carry_position - from).normalized()
					var edge_pos = from
					for i in range(1, int(Vector2(from).distance_to(Vector2(carry_position))) + 1):
						var check = Vector2i((Vector2(from) + dir * i).round())
						if terrain_grid.is_valid_position(check) and terrain_grid.get_tile(check) == TerrainTypes.Type.GREEN:
							edge_pos = check
						else:
							break
					carry_position = edge_pos

		var distance_yards = terrain_grid.calculate_distance_yards(from, carry_position)
		return {
			"landing_position": carry_position,
			"landing_position_precise": carry_position_precise,
			"carry_position_precise": carry_position_precise,
			"distance": distance_yards,
			"accuracy": total_accuracy,
			"club": club,
			"rollout_tiles": 0.0,
			"is_backspin": false,
		}

	# --- Rollout calculation ---
	# Calculate how far the ball rolls after landing based on club, terrain, slope, and skill
	var rollout = _calculate_rollout(club, carry_position, carry_position_precise,
		Vector2(from), actual_distance, total_accuracy)

	var final_position_precise = rollout.final_position
	var final_position = Vector2i(final_position_precise.round())

	# Ensure final position is valid
	if not terrain_grid.is_valid_position(final_position):
		final_position = carry_position
		final_position_precise = carry_position_precise

	var distance_yards = terrain_grid.calculate_distance_yards(from, final_position)

	return {
		"landing_position": final_position,
		"landing_position_precise": final_position_precise,
		"carry_position_precise": carry_position_precise,
		"distance": distance_yards,
		"accuracy": total_accuracy,
		"club": club,
		"rollout_tiles": rollout.rollout_distance,
		"is_backspin": rollout.is_backspin,
	}

## Approximate gaussian random using Central Limit Theorem (sum of uniform randoms).
## Returns value with mean ~0 and std dev ~1. Range approximately -3.5 to +3.5.
## 68% of values within ±1, 95% within ±2, 99.7% within ±3.
func _gaussian_random() -> float:
	return (randf() + randf() + randf() + randf() - 2.0) / 0.5774

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

## Calculate rollout after ball lands. Returns Dictionary with final_position,
## rollout_distance (tiles), and is_backspin flag.
## Rollout depends on club, landing terrain, slope, and player skill (backspin).
func _calculate_rollout(club: Club, carry_grid: Vector2i, carry_precise: Vector2,
		shot_origin: Vector2, carry_distance: float, total_accuracy: float) -> Dictionary:
	var terrain_grid = GameManager.terrain_grid
	var no_rollout = {
		"final_position": carry_precise,
		"rollout_distance": 0.0,
		"is_backspin": false,
	}
	if not terrain_grid:
		return no_rollout

	var carry_terrain = terrain_grid.get_tile(carry_grid)

	# No rollout if ball lands in water, OB, or bunker (plugs in sand)
	if carry_terrain in [TerrainTypes.Type.WATER, TerrainTypes.Type.OUT_OF_BOUNDS, TerrainTypes.Type.BUNKER]:
		return no_rollout

	# --- Base rollout fraction (proportion of carry distance) ---
	# Real golf: driver rolls 15-30%, irons 6-15%, wedges 0-10%
	var rollout_min: float
	var rollout_max: float
	var is_wedge_chip = false

	match club:
		Club.DRIVER:
			rollout_min = 0.12
			rollout_max = 0.28
		Club.FAIRWAY_WOOD:
			rollout_min = 0.08
			rollout_max = 0.20
		Club.IRON:
			rollout_min = 0.05
			rollout_max = 0.14
		Club.WEDGE:
			# Determine if this is a full wedge or a chip (partial swing)
			var club_stats = CLUB_STATS[Club.WEDGE]
			var distance_ratio = carry_distance / float(club_stats["max_distance"])
			if distance_ratio > 0.65:
				# Full wedge shot — backspin potential for skilled players
				rollout_min = -0.04  # Negative = backspin (for skilled players)
				rollout_max = 0.08
			else:
				# Chip shot — always rolls forward, lower trajectory
				is_wedge_chip = true
				rollout_min = 0.06
				rollout_max = 0.18
		_:
			return no_rollout

	# Sample rollout fraction with slight variance (gaussian-ish)
	var roll_t = clampf(randf() * 0.6 + randf() * 0.4, 0.0, 1.0)  # Skewed toward middle
	var base_rollout_fraction = lerpf(rollout_min, rollout_max, roll_t)

	# --- Backspin for full wedge shots ---
	var is_backspin = false
	if club == Club.WEDGE and not is_wedge_chip:
		# Backspin ability scales with accuracy and recovery skill
		var spin_skill = (accuracy_skill * 0.6 + recovery_skill * 0.4)
		# High-skill players (>0.7) can generate backspin; lower skill just reduces roll
		if spin_skill > 0.7:
			# Shift rollout toward negative (backspin) based on skill above threshold
			var spin_bonus = (spin_skill - 0.7) / 0.3  # 0.0 to 1.0 for skill 0.7 to 1.0
			base_rollout_fraction -= spin_bonus * 0.10
		# Clamp: even best players can't spin back more than ~4% of carry
		base_rollout_fraction = maxf(base_rollout_fraction, -0.04)

		if base_rollout_fraction < 0.0:
			is_backspin = true

	# --- Landing terrain multiplier on rollout ---
	var terrain_roll_mult = 1.0
	match carry_terrain:
		TerrainTypes.Type.GREEN:
			terrain_roll_mult = 1.3   # Fast, smooth surface — more roll
		TerrainTypes.Type.FAIRWAY:
			terrain_roll_mult = 1.0   # Baseline
		TerrainTypes.Type.GRASS:
			terrain_roll_mult = 0.8   # Light rough slows ball
		TerrainTypes.Type.ROUGH:
			terrain_roll_mult = 0.3   # Rough grabs the ball
		TerrainTypes.Type.HEAVY_ROUGH:
			terrain_roll_mult = 0.15  # Ball stops quickly
		TerrainTypes.Type.TREES:
			terrain_roll_mult = 0.2   # Dense ground cover
		TerrainTypes.Type.PATH:
			terrain_roll_mult = 1.4   # Hard surface — extra bounce/roll
		_:
			terrain_roll_mult = 0.5

	# Backspin is less affected by terrain (spin is on the ball, not surface)
	# But rough does kill spin somewhat
	if is_backspin:
		terrain_roll_mult = lerpf(1.0, terrain_roll_mult, 0.4)

	var rollout_fraction = base_rollout_fraction * terrain_roll_mult
	var rollout_distance = carry_distance * absf(rollout_fraction)

	# Minimum visible rollout threshold (0.15 tiles ≈ 3 yards)
	if rollout_distance < 0.15:
		return no_rollout

	# --- Slope influence on rollout ---
	var slope = terrain_grid.get_slope_direction(carry_grid)

	# Roll direction: continue along shot line, blended with slope
	var shot_direction = (carry_precise - shot_origin).normalized()
	var roll_direction: Vector2

	if is_backspin:
		# Backspin: ball rolls backwards (toward shot origin)
		roll_direction = -shot_direction
	else:
		roll_direction = shot_direction

	# Blend slope into roll direction (slope has more effect on longer rolls)
	if slope.length() > 0:
		var slope_influence = clampf(rollout_distance / 3.0, 0.1, 0.5)
		roll_direction = (roll_direction * (1.0 - slope_influence) + slope * slope_influence).normalized()

	# Slope dot product: positive = rolling downhill, negative = uphill
	var slope_dot = slope.dot(roll_direction)
	if slope_dot > 0:
		rollout_distance *= 1.0 + slope_dot * 0.5   # Downhill: up to +50% roll
	elif slope_dot < 0:
		rollout_distance *= maxf(0.2, 1.0 + slope_dot * 0.5)  # Uphill: reduce roll

	# --- Walk rollout path checking for hazards ---
	var final_position = carry_precise
	var steps = int(ceilf(rollout_distance * 4.0))  # Check every quarter-tile
	var step_size = rollout_distance / maxf(steps, 1)

	for i in range(1, steps + 1):
		var check_point = carry_precise + roll_direction * (step_size * i)
		var check_grid = Vector2i(check_point.round())

		if not terrain_grid.is_valid_position(check_grid):
			break  # Stop at map edge

		var check_terrain = terrain_grid.get_tile(check_grid)

		# Ball stops if it rolls into certain terrain
		if check_terrain == TerrainTypes.Type.WATER:
			final_position = check_point  # Ball goes in the water
			break
		if check_terrain == TerrainTypes.Type.OUT_OF_BOUNDS:
			final_position = check_point  # Ball goes OB
			break
		if check_terrain == TerrainTypes.Type.BUNKER:
			final_position = check_point  # Ball plugs into bunker
			break

		# Rough slows progressively — reduce remaining roll
		if check_terrain == TerrainTypes.Type.ROUGH and carry_terrain != TerrainTypes.Type.ROUGH:
			# Entering rough from fairway/green — ball decelerates faster
			rollout_distance *= 0.6
			steps = int(ceilf(rollout_distance * 4.0))

		final_position = check_point

	return {
		"final_position": final_position,
		"rollout_distance": carry_precise.distance_to(final_position),
		"is_backspin": is_backspin,
	}

## Estimate ball flight duration (mirrors BallManager calculation)
func _estimate_flight_duration(distance_yards: int) -> float:
	var duration = 1.0 + (distance_yards / 300.0) * 1.5
	return clampf(duration, 0.5, 3.0)

## Estimate rollout animation duration (mirrors BallManager calculation)
func _estimate_rollout_duration(rollout_tiles: float) -> float:
	if rollout_tiles < 0.15:
		return 0.0
	# Approximate screen distance from tile distance (tile_width ~64px)
	var screen_dist = rollout_tiles * 64.0
	var duration = 0.3 + (screen_dist / 200.0) * 0.8
	return clampf(duration, 0.2, 1.2)

## Handle hazard penalties (water or OB). Returns true if a penalty was applied.
func _handle_hazard_penalty(previous_position: Vector2i) -> bool:
	var terrain_grid = GameManager.terrain_grid
	if not terrain_grid:
		return false

	var landing_terrain = terrain_grid.get_tile(ball_position)

	if landing_terrain == TerrainTypes.Type.WATER:
		# Water: 1 penalty stroke, drop at point of entry no closer to the hole
		current_strokes += 1
		var entry_point = _find_water_entry_point(previous_position, ball_position)
		var drop_position = _find_water_drop_position(entry_point)
		print("%s: Ball in water! Penalty stroke. Dropping at point of entry. Now on stroke %d" % [golfer_name, current_strokes])
		EventBus.hazard_penalty.emit(golfer_id, "water", drop_position)
		show_thought(FeedbackTriggers.TriggerType.HAZARD_WATER)
		ball_position = drop_position
		ball_position_precise = Vector2(drop_position)
		return true

	elif landing_terrain == TerrainTypes.Type.OUT_OF_BOUNDS:
		# OB: 1 penalty stroke, replay from previous position (stroke and distance)
		current_strokes += 1
		print("%s: Ball out of bounds! Penalty stroke. Replaying from previous position. Now on stroke %d" % [golfer_name, current_strokes])
		EventBus.hazard_penalty.emit(golfer_id, "ob", previous_position)
		ball_position = previous_position
		ball_position_precise = Vector2(previous_position)
		return true

	return false

## Trace the ball's trajectory to find where it first entered water (point of entry).
## Uses Bresenham-style line walk from shot origin to water landing position.
## Returns the first water tile along the path (the margin crossing point).
func _find_water_entry_point(from_pos: Vector2i, water_pos: Vector2i) -> Vector2i:
	var terrain_grid = GameManager.terrain_grid
	if not terrain_grid:
		return water_pos

	# Walk tiles along the line from shot origin to water landing
	var points = _bresenham_line(from_pos, water_pos)

	# Find the first water tile — that's where the ball crossed the hazard margin
	for point in points:
		if not terrain_grid.is_valid_position(point):
			continue
		if terrain_grid.get_tile(point) == TerrainTypes.Type.WATER:
			return point

	# Fallback: if no entry point found along trajectory, use landing position
	return water_pos

## Bresenham's line algorithm — returns all grid tiles along a line from p0 to p1.
func _bresenham_line(p0: Vector2i, p1: Vector2i) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	var dx = absi(p1.x - p0.x)
	var dy = -absi(p1.y - p0.y)
	var sx = 1 if p0.x < p1.x else -1
	var sy = 1 if p0.y < p1.y else -1
	var err = dx + dy
	var x = p0.x
	var y = p0.y

	while true:
		points.append(Vector2i(x, y))
		if x == p1.x and y == p1.y:
			break
		var e2 = 2 * err
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy

	return points

## Find a valid drop position near the water entry point, no closer to the hole.
## entry_position is where the ball's trajectory first crossed into the water hazard.
func _find_water_drop_position(entry_position: Vector2i) -> Vector2i:
	var terrain_grid = GameManager.terrain_grid
	if not terrain_grid:
		return entry_position

	# Get hole position for "no closer to the hole" rule
	var course_data = GameManager.course_data
	var hole_position = entry_position
	if course_data and not course_data.holes.is_empty() and current_hole < course_data.holes.size():
		hole_position = course_data.holes[current_hole].hole_position

	# "No closer to hole" is measured from the point of entry
	var entry_distance_to_hole = Vector2(entry_position).distance_to(Vector2(hole_position))

	# Search expanding rings around the entry point
	var best_position = entry_position
	var best_score = -999.0

	for radius in range(1, 6):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if abs(dx) != radius and abs(dy) != radius:
					continue  # Only check the ring edge

				var candidate = entry_position + Vector2i(dx, dy)
				if not terrain_grid.is_valid_position(candidate):
					continue

				var candidate_terrain = terrain_grid.get_tile(candidate)
				# Must be playable terrain
				if candidate_terrain in [TerrainTypes.Type.WATER, TerrainTypes.Type.OUT_OF_BOUNDS]:
					continue

				# Must not be closer to the hole than the point of entry
				var candidate_distance_to_hole = Vector2(candidate).distance_to(Vector2(hole_position))
				if candidate_distance_to_hole < entry_distance_to_hole:
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

				# Prefer closer to the entry point (shorter walk)
				score -= Vector2(candidate).distance_to(Vector2(entry_position)) * 5.0

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

	# Always use sub-tile precision for accurate ball positioning
	var ball_screen_pos = GameManager.terrain_grid.grid_to_screen_precise(ball_position_precise)
	path = _find_path_to(ball_screen_pos)
	path_index = 0
	_change_state(State.WALKING)

## Pathfinding with terrain awareness and obstacle avoidance
func _find_path_to(target_pos: Vector2) -> Array[Vector2]:
	var terrain_grid = GameManager.terrain_grid
	if not terrain_grid:
		var result: Array[Vector2] = []
		result.append(target_pos)
		return result

	# Convert to grid positions
	var start_grid = terrain_grid.screen_to_grid(global_position)
	var end_grid = terrain_grid.screen_to_grid(target_pos)

	var path_distance = Vector2(start_grid).distance_to(Vector2(end_grid))

	if path_distance < 2.5:
		# Very short distance - go direct
		var result: Array[Vector2] = []
		result.append(target_pos)
		return result

	# Check for obstacles first, then decide routing strategy
	var has_obstacles = _path_crosses_obstacle(start_grid, end_grid, true)

	if not has_obstacles:
		# Direct path is clear — optionally use cart path if it's genuinely faster
		if path_distance >= 5.0:
			var cart_path_route = _find_cart_path_route(start_grid, end_grid)
			if not cart_path_route.is_empty():
				return cart_path_route
		# Go direct
		var result: Array[Vector2] = []
		result.append(target_pos)
		return result

	# Obstacles detected — use A* to find path around water/OB
	return _find_path_around_obstacles(start_grid, end_grid)

## Check if path crosses obstacles (water/OB for walking, trees for flight)
## For ball flight, only trees block — and only when the ball is low
## (first/last 20% of flight). Water and OB are cleared by the airborne ball;
## landing penalties are handled separately by _evaluate_landing_zone.
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
			# Ball flight: the ball flies through the air and clears water/OB below.
			# Landing in water/OB is penalized by _evaluate_landing_zone terrain scoring.
			# Trees block when the ball is low - use parabolic height model.
			if terrain_type == TerrainTypes.Type.TREES:
				# Ball trajectory: parabolic arc with peak at midpoint
				# At t=0.0 and t=1.0, ball is at ground level
				# At t=0.5, ball is at maximum height (apex)
				var height_factor = 4.0 * t * (1.0 - t)  # 0 at edges, 1 at midpoint
				var tree_clear_threshold = 0.3  # Must be above 30% of max height to clear
				if height_factor < tree_clear_threshold:
					return true

	return false

## A* pathfinding on the terrain grid, avoiding water and OB.
## Returns simplified waypoints (not every grid cell).
func _find_path_around_obstacles(start: Vector2i, end: Vector2i) -> Array[Vector2]:
	var terrain_grid = GameManager.terrain_grid
	if not terrain_grid:
		var result: Array[Vector2] = []
		result.append(terrain_grid.grid_to_screen_center(end))
		return result

	# A* with 8-directional movement
	var open_set: Dictionary = {}  # Vector2i -> f_score
	var closed_set: Dictionary = {}
	var came_from: Dictionary = {}
	var g_score: Dictionary = {}

	g_score[start] = 0.0
	open_set[start] = _astar_heuristic(start, end)

	var directions: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)
	]

	var max_iterations: int = 5000
	var iterations: int = 0

	while not open_set.is_empty() and iterations < max_iterations:
		iterations += 1

		# Find node in open_set with lowest f_score
		var current: Vector2i = open_set.keys()[0]
		var current_f: float = open_set[current]
		for node in open_set:
			if open_set[node] < current_f:
				current_f = open_set[node]
				current = node

		if current == end:
			# Reconstruct and simplify path into screen-space waypoints
			var grid_path: Array[Vector2i] = _reconstruct_grid_path(came_from, end)
			return _simplify_grid_path(grid_path)

		open_set.erase(current)
		closed_set[current] = true

		for dir in directions:
			var neighbor: Vector2i = current + dir

			if neighbor in closed_set:
				continue
			if not terrain_grid.is_valid_position(neighbor):
				continue

			var terrain_type = terrain_grid.get_tile(neighbor)
			if terrain_type == TerrainTypes.Type.WATER or terrain_type == TerrainTypes.Type.OUT_OF_BOUNDS:
				continue

			# Diagonal costs sqrt(2), cardinal costs 1
			var move_cost: float = 1.414 if (dir.x != 0 and dir.y != 0) else 1.0
			var tentative_g: float = g_score[current] + move_cost

			if neighbor not in g_score or tentative_g < g_score[neighbor]:
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g
				open_set[neighbor] = tentative_g + _astar_heuristic(neighbor, end)

	# A* couldn't reach target (completely walled off) — go direct as last resort
	var result: Array[Vector2] = []
	result.append(terrain_grid.grid_to_screen_center(end))
	return result

## A* heuristic: octile distance (consistent with 8-directional movement)
func _astar_heuristic(a: Vector2i, b: Vector2i) -> float:
	var dx: int = abs(a.x - b.x)
	var dy: int = abs(a.y - b.y)
	# Octile distance: cardinal cost 1.0, diagonal cost sqrt(2)
	return 1.0 * (dx + dy) + (1.414 - 2.0) * min(dx, dy)

## Reconstruct grid path from A* came_from map
func _reconstruct_grid_path(came_from: Dictionary, end: Vector2i) -> Array[Vector2i]:
	var grid_path: Array[Vector2i] = []
	var current: Vector2i = end
	while current in came_from:
		grid_path.push_front(current)
		current = came_from[current]
	grid_path.push_front(current)  # Add start
	return grid_path

## Simplify a grid-cell path into minimal screen-space waypoints using line-of-sight
func _simplify_grid_path(grid_path: Array[Vector2i]) -> Array[Vector2]:
	var terrain_grid = GameManager.terrain_grid
	var result: Array[Vector2] = []

	if grid_path.size() <= 2:
		result.append(terrain_grid.grid_to_screen_center(grid_path[grid_path.size() - 1]))
		return result

	# Line-of-sight simplification: only add waypoints where direct line is blocked
	var anchor_idx: int = 0
	while anchor_idx < grid_path.size() - 1:
		var farthest_visible: int = anchor_idx + 1
		for i in range(anchor_idx + 2, grid_path.size()):
			if not _path_crosses_obstacle(grid_path[anchor_idx], grid_path[i], true):
				farthest_visible = i
			else:
				break

		if farthest_visible < grid_path.size() - 1:
			# Need an intermediate waypoint here
			result.append(terrain_grid.grid_to_screen_center(grid_path[farthest_visible]))
		anchor_idx = farthest_visible

	# Always end at the final destination
	result.append(terrain_grid.grid_to_screen_center(grid_path[grid_path.size() - 1]))
	return result

## Find a route through nearby cart paths for speed bonus.
## Only returns a route if it's genuinely faster than walking directly.
func _find_cart_path_route(start: Vector2i, end: Vector2i) -> Array[Vector2]:
	var terrain_grid = GameManager.terrain_grid
	if not terrain_grid:
		return []

	# Search for cart path tiles near the direct path
	var distance = Vector2(start).distance_to(Vector2(end))
	var search_radius: int = 4  # How far from direct path to search

	var cart_path_tiles: Array[Vector2i] = []

	# Sample along the path and search nearby for cart paths
	var num_samples = int(distance / 3) + 1
	for i in range(num_samples):
		var t = float(i) / float(num_samples)
		var sample = Vector2(start).lerp(Vector2(end), t)

		# Search in a box around the sample point
		for dx in range(-search_radius, search_radius + 1):
			for dy in range(-search_radius, search_radius + 1):
				var check_pos = Vector2i(int(sample.x) + dx, int(sample.y) + dy)
				if not terrain_grid.is_valid_position(check_pos):
					continue
				if terrain_grid.get_tile(check_pos) == TerrainTypes.Type.PATH:
					if not cart_path_tiles.has(check_pos):
						cart_path_tiles.append(check_pos)

	if cart_path_tiles.is_empty():
		return []

	# Find cart path tiles closest to start and end
	var closest_to_start: Vector2i = cart_path_tiles[0]
	var closest_to_end: Vector2i = cart_path_tiles[0]
	var min_dist_start: float = Vector2(start).distance_to(Vector2(closest_to_start))
	var min_dist_end: float = Vector2(end).distance_to(Vector2(closest_to_end))

	for tile in cart_path_tiles:
		var dist_start = Vector2(start).distance_to(Vector2(tile))
		var dist_end = Vector2(end).distance_to(Vector2(tile))
		if dist_start < min_dist_start:
			min_dist_start = dist_start
			closest_to_start = tile
		if dist_end < min_dist_end:
			min_dist_end = dist_end
			closest_to_end = tile

	# Entry/exit must be reasonably close to start/end
	if min_dist_start > 6 or min_dist_end > 6:
		return []

	# Check that the cart path route doesn't cross obstacles
	if _path_crosses_obstacle(start, closest_to_start, true):
		return []
	if _path_crosses_obstacle(closest_to_end, end, true):
		return []

	# Compare travel time: cart path route vs direct walk
	# PATH tiles give 1.5x speed, so time on path = distance / 1.5
	var direct_time = distance  # direct distance at 1.0x speed
	var entry_dist = Vector2(start).distance_to(Vector2(closest_to_start))
	var path_dist = Vector2(closest_to_start).distance_to(Vector2(closest_to_end))
	var exit_dist = Vector2(closest_to_end).distance_to(Vector2(end))
	var cart_time = entry_dist + (path_dist / 1.5) + exit_dist

	if cart_time >= direct_time:
		return []  # Cart path detour is slower than walking directly

	# Build the route: start -> cart path entry -> cart path exit -> end
	var result: Array[Vector2] = []
	if closest_to_start != closest_to_end:
		result.append(terrain_grid.grid_to_screen_center(closest_to_start))
		result.append(terrain_grid.grid_to_screen_center(closest_to_end))
	else:
		result.append(terrain_grid.grid_to_screen_center(closest_to_start))
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

## Create highlight ring node for active golfer indication
func _create_highlight_ring() -> void:
	_highlight_ring = Polygon2D.new()
	_highlight_ring.name = "HighlightRing"
	# Draw a larger ellipse at the golfer's feet for better visibility
	var points = PackedVector2Array()
	for i in range(24):
		var angle = (i / 24.0) * TAU
		points.append(Vector2(cos(angle) * 16, sin(angle) * 8 + 12))
	_highlight_ring.polygon = points
	_highlight_ring.color = Color(1.0, 0.9, 0.2, 0.6)  # Brighter yellow, more opaque
	_highlight_ring.z_index = -1  # Just below golfer body
	_highlight_ring.visible = false
	add_child(_highlight_ring)

## Update highlight ring visibility based on active golfer state
func _update_highlight_ring() -> void:
	if _highlight_ring:
		_highlight_ring.visible = is_active_golfer
		_highlight_ring.position = visual_offset

## Update visual representation
func _update_visual() -> void:
	if not visual:
		return

	# Reset to default pose — apply visual offset for co-location separation
	visual.position = visual_offset
	if arms:
		arms.rotation = 0
	if hands:
		hands.rotation = 0

	# Hide golf club by default
	if golf_club:
		golf_club.visible = false
		golf_club.rotation = 0

	# Reset body modulate to show true shirt color
	if body:
		body.modulate = Color.WHITE

	# Update visual based on state
	match current_state:
		State.IDLE:
			pass  # Default appearance
		State.WALKING:
			pass  # Walk animation handled in _process_walking
		State.PREPARING_SHOT:
			# Show golf club while preparing
			if golf_club:
				golf_club.visible = true
				golf_club.rotation = -0.3
		State.SWINGING:
			# Show golf club during swing
			if golf_club:
				golf_club.visible = true
				golf_club.rotation = -1.2  # Club rotated back
			if arms:
				arms.rotation = -0.3
			if hands:
				hands.rotation = -0.3
		State.WATCHING:
			# Show club while watching ball
			if golf_club:
				golf_club.visible = true
				golf_club.rotation = 0.2  # Follow through position
		State.FINISHED:
			# Dim the golfer slightly when finished
			if body:
				body.modulate = Color(0.85, 0.85, 0.85, 1)

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
func _on_green_fee_paid(paid_golfer_id: int, _paid_golfer_name: String, amount: int) -> void:
	# Only show notification for this specific golfer
	if paid_golfer_id == golfer_id:
		show_payment_notification(amount)

		# Check price sensitivity and show thought
		var price_trigger = FeedbackTriggers.get_price_trigger(amount, GameManager.reputation)
		if price_trigger != -1:
			# Delay price feedback slightly so it doesn't overlap with payment notification
			await get_tree().create_timer(1.0).timeout
			show_thought(price_trigger)

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

## Check proximity to buildings and generate revenue/satisfaction effects
func _check_building_proximity() -> void:
	var entity_layer = GameManager.entity_layer
	if not entity_layer:
		return

	var terrain_grid = GameManager.terrain_grid
	if not terrain_grid:
		return

	var current_grid_pos = terrain_grid.screen_to_grid(global_position)
	var buildings = entity_layer.get_all_buildings()

	for building in buildings:
		# Skip if already visited this building
		var building_id = building.get_instance_id()
		if _visited_buildings.has(building_id):
			continue

		# Check if building has effect properties
		var building_data = building.building_data
		var effect_type = building_data.get("effect_type", "")
		if effect_type.is_empty():
			continue

		# Check proximity
		var effect_radius = building_data.get("effect_radius", 5)
		var distance = Vector2(current_grid_pos).distance_to(Vector2(building.grid_position))

		if distance <= effect_radius:
			_visited_buildings[building_id] = true

			# Apply effect based on type
			# Use building methods to get upgrade-aware values
			if effect_type == "revenue":
				var income = building.get_income_per_golfer()
				if income > 0:
					GameManager.modify_money(income)
					GameManager.daily_stats.building_revenue += income
					EventBus.log_transaction("%s at %s" % [golfer_name, building.building_type], income)
					_show_building_revenue_notification(income, building.building_type)

			elif effect_type == "satisfaction":
				var bonus = building.get_satisfaction_bonus()
				if bonus > 0:
					# Boost mood slightly when passing amenities
					current_mood = clampf(current_mood + bonus, 0.0, 1.0)

## Show floating notification for building revenue
func _show_building_revenue_notification(amount: int, _building_type: String) -> void:
	var notification = Label.new()
	notification.text = "+$%d" % amount
	notification.modulate = Color(0.4, 0.8, 1.0, 1.0)  # Blue for building revenue
	notification.position = Vector2(15, -30)

	notification.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notification.add_theme_font_size_override("font_size", 12)

	add_child(notification)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(notification, "position:y", -50, 1.2)
	tween.tween_property(notification, "modulate:a", 0.0, 1.2)
	tween.finished.connect(func(): notification.queue_free())

## Apply clubhouse effects when golfer finishes round (visits clubhouse)
func _apply_clubhouse_effects() -> void:
	var entity_layer = GameManager.entity_layer
	if not entity_layer:
		return

	# Find the clubhouse
	var buildings = entity_layer.get_all_buildings()
	for building in buildings:
		if building.building_type != "clubhouse":
			continue

		# Skip if already visited this round (to prevent double-charging)
		var building_id = building.get_instance_id()
		if _visited_buildings.has(building_id):
			break

		# Mark as visited
		_visited_buildings[building_id] = true

		# Apply revenue from upgraded clubhouse
		var income = building.get_income_per_golfer()
		if income > 0:
			GameManager.modify_money(income)
			GameManager.daily_stats.building_revenue += income
			EventBus.log_transaction("%s at Clubhouse" % golfer_name, income)
			_show_building_revenue_notification(income, "clubhouse")

		# Apply satisfaction from upgraded clubhouse
		var bonus = building.get_satisfaction_bonus()
		if bonus > 0:
			current_mood = clampf(current_mood + bonus, 0.0, 1.0)

		break  # Only one clubhouse

## Show a thought bubble with golfer feedback
## Respects cooldown to prevent spam
func show_thought(trigger_type: int) -> void:
	# Enforce cooldown
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - _last_thought_time < THOUGHT_COOLDOWN:
		return

	# Check probability
	if not FeedbackTriggers.should_trigger(trigger_type):
		return

	_last_thought_time = current_time

	var message = FeedbackTriggers.get_random_message(trigger_type)
	var sentiment_str = FeedbackTriggers.get_sentiment(trigger_type)

	var sentiment: int = ThoughtBubble.Sentiment.NEUTRAL
	if sentiment_str == "positive":
		sentiment = ThoughtBubble.Sentiment.POSITIVE
	elif sentiment_str == "negative":
		sentiment = ThoughtBubble.Sentiment.NEGATIVE

	var bubble = ThoughtBubble.create(message, sentiment)
	add_child(bubble)

	# Notify FeedbackManager for aggregate tracking
	EventBus.golfer_thought.emit(golfer_id, trigger_type, sentiment_str)

## Serialize golfer state
func serialize() -> Dictionary:
	return {
		"golfer_id": golfer_id,
		"golfer_name": golfer_name,
		"group_id": group_id,
		"golfer_tier": golfer_tier,
		"driving_skill": driving_skill,
		"accuracy_skill": accuracy_skill,
		"putting_skill": putting_skill,
		"recovery_skill": recovery_skill,
		"miss_tendency": miss_tendency,
		"aggression": aggression,
		"patience": patience,
		"current_hole": current_hole,
		"current_strokes": current_strokes,
		"total_strokes": total_strokes,
		"total_par": total_par,
		"previous_hole_strokes": previous_hole_strokes,
		"current_mood": current_mood,
		"current_state": current_state,
		"ball_position": {"x": ball_position.x, "y": ball_position.y},
		"ball_position_precise": {"x": ball_position_precise.x, "y": ball_position_precise.y},
		"position": {"x": global_position.x, "y": global_position.y}
	}

## Deserialize golfer state
func deserialize(data: Dictionary) -> void:
	golfer_id = data.get("golfer_id", -1)
	golfer_name = data.get("golfer_name", "Golfer")
	group_id = data.get("group_id", -1)
	golfer_tier = data.get("golfer_tier", GolferTier.Tier.CASUAL)
	driving_skill = data.get("driving_skill", 0.5)
	accuracy_skill = data.get("accuracy_skill", 0.5)
	putting_skill = data.get("putting_skill", 0.5)
	recovery_skill = data.get("recovery_skill", 0.5)
	miss_tendency = data.get("miss_tendency", 0.0)
	aggression = data.get("aggression", 0.5)
	patience = data.get("patience", 0.5)
	current_hole = data.get("current_hole", 0)
	current_strokes = data.get("current_strokes", 0)
	total_strokes = data.get("total_strokes", 0)
	total_par = data.get("total_par", 0)
	previous_hole_strokes = data.get("previous_hole_strokes", 0)
	current_mood = data.get("current_mood", 0.5)
	# Always restore to IDLE state so golfer can resume cleanly
	# The current_strokes and ball_position tell us where they are in the hole
	current_state = State.IDLE

	var ball_pos = data.get("ball_position", {})
	if ball_pos:
		ball_position = Vector2i(int(ball_pos.get("x", 0)), int(ball_pos.get("y", 0)))

	var ball_precise = data.get("ball_position_precise", {})
	if ball_precise:
		ball_position_precise = Vector2(ball_precise.get("x", 0), ball_precise.get("y", 0))

	var pos_data = data.get("position", {})
	if pos_data:
		global_position = Vector2(pos_data.get("x", 0), pos_data.get("y", 0))

	_update_visual()
	_update_score_display()
