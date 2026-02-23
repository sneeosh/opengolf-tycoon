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
		"min_distance": 9,     # tiles (198 yards) — lowered from 10 so casual golfers can use Driver
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

## Tournament flag — tournament golfers skip green fees and course-closing checks
var is_tournament_golfer: bool = false

## Per-hole score tracking for scorecard display
var hole_scores: Array = []  # Array of {hole: int, strokes: int, par: int}

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

## Needs system — tracks energy, comfort, hunger, pace satisfaction
var needs: GolferNeeds = GolferNeeds.new()

## Waiting time accumulator (seconds spent in IDLE waiting for turn)
var _wait_time_accumulated: float = 0.0

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

## Club chosen by decide_shot_target() — used by _calculate_shot() to avoid mismatch
var _chosen_club: Club = Club.DRIVER
## Strategy chosen by ShotAI (normal/recovery/layup/attack) — for debug/feedback
var _shot_strategy: String = "normal"

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

## Walk animation state
var _walk_frame: int = 0  # 0 or 1, alternates for leg swap
var _walk_timer: float = 0.0
const WALK_FRAME_DURATION: float = 0.25  # seconds per frame

## Leg polygon data for walk animation frames
## Frame 0 = standing (matches scene default), Frame 1 = mid-stride
var LEGS_FRAME_0 := PackedVector2Array([
	Vector2(-4, 4), Vector2(-3, 11), Vector2(-1, 11), Vector2(0, 4),
	Vector2(0, 4), Vector2(1, 11), Vector2(3, 11), Vector2(4, 4)
])
var LEGS_FRAME_1 := PackedVector2Array([
	Vector2(-4, 4), Vector2(-4, 11), Vector2(-2, 11), Vector2(-1, 5),
	Vector2(1, 5), Vector2(2, 11), Vector2(4, 11), Vector2(4, 4)
])
var SHOES_FRAME_0 := PackedVector2Array([
	Vector2(-4, 11), Vector2(-4, 14), Vector2(-1, 14), Vector2(-1, 11),
	Vector2(1, 11), Vector2(1, 14), Vector2(4, 14), Vector2(4, 11)
])
var SHOES_FRAME_1 := PackedVector2Array([
	Vector2(-5, 11), Vector2(-5, 14), Vector2(-2, 14), Vector2(-2, 11),
	Vector2(2, 11), Vector2(2, 14), Vector2(5, 14), Vector2(5, 11)
])

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
signal golfer_selected(golfer: Golfer)

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

	# Enable click detection on the CharacterBody2D's own collision shape
	input_pickable = true
	input_event.connect(_on_click_area_input_event)

	# Set up labels with tier-colored name
	if name_label:
		name_label.text = golfer_name
		_apply_tier_name_color()

	# Create highlight ring for active golfer indication
	_create_highlight_ring()

	# Connect to green fee payment signal
	EventBus.green_fee_paid.connect(_on_green_fee_paid)

	_update_visual()
	_update_score_display()

## Randomize golfer appearance with variety
func _randomize_appearance() -> void:
	# Tier-specific shirt color palettes for visual differentiation at a glance
	var shirt_colors: Array
	match golfer_tier:
		GolferTier.Tier.BEGINNER:
			# Beginners: bright, casual, mismatched colors
			shirt_colors = [
				Color(0.95, 0.55, 0.3),   # Bright orange
				Color(0.9, 0.75, 0.3),    # Yellow
				Color(0.8, 0.45, 0.7),    # Pink
				Color(0.5, 0.85, 0.5),    # Lime green
				Color(0.95, 0.4, 0.4),    # Bright red
				Color(0.3, 0.75, 0.75),   # Turquoise
			]
		GolferTier.Tier.CASUAL:
			# Casual: standard polo shirt colors
			shirt_colors = [
				Color(0.35, 0.6, 0.9),    # Blue
				Color(0.35, 0.8, 0.45),   # Green
				Color(0.9, 0.35, 0.35),   # Red
				Color(0.95, 0.95, 0.95),  # White
				Color(0.3, 0.7, 0.7),     # Teal
				Color(0.5, 0.35, 0.7),    # Purple
			]
		GolferTier.Tier.SERIOUS:
			# Serious: refined, coordinated athletic colors
			shirt_colors = [
				Color(0.2, 0.2, 0.3),     # Dark navy
				Color(0.15, 0.35, 0.15),  # Forest green
				Color(0.3, 0.3, 0.35),    # Charcoal
				Color(0.85, 0.85, 0.85),  # Light gray
				Color(0.6, 0.15, 0.15),   # Burgundy
				Color(0.25, 0.4, 0.55),   # Steel blue
			]
		GolferTier.Tier.PRO:
			# Pro: sponsored, branded, muted professional colors
			shirt_colors = [
				Color(0.1, 0.1, 0.15),    # Near-black
				Color(0.95, 0.95, 0.95),  # Tour white
				Color(0.15, 0.2, 0.35),   # Midnight blue
				Color(0.6, 0.55, 0.5),    # Khaki tour
				Color(0.25, 0.25, 0.25),  # Carbon
			]
		_:
			shirt_colors = [
				Color(0.9, 0.35, 0.35),
				Color(0.35, 0.6, 0.9),
				Color(0.35, 0.8, 0.45),
				Color(0.95, 0.95, 0.95),
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

	# Add body shading overlays for visual depth
	_add_body_shading()

func _add_body_shading() -> void:
	if not visual:
		return
	# Shirt shadow on lower half - subtle darkening
	var shirt_shadow = Polygon2D.new()
	shirt_shadow.name = "ShirtShadow"
	shirt_shadow.color = Color(0, 0, 0, 0.12)
	shirt_shadow.polygon = PackedVector2Array([
		Vector2(-5, 1), Vector2(-5, 5), Vector2(5, 5), Vector2(6, 1)
	])
	visual.add_child(shirt_shadow)

	# Shirt highlight on upper chest
	var shirt_highlight = Polygon2D.new()
	shirt_highlight.name = "ShirtHighlight"
	shirt_highlight.color = Color(1, 1, 1, 0.1)
	shirt_highlight.polygon = PackedVector2Array([
		Vector2(-4, -4), Vector2(-3, -3), Vector2(3, -3), Vector2(4, -4)
	])
	visual.add_child(shirt_highlight)

	# Head highlight on upper portion for volume
	var head_highlight = Polygon2D.new()
	head_highlight.name = "HeadHighlight"
	head_highlight.color = Color(1, 1, 1, 0.15)
	var hl_points = PackedVector2Array()
	for i in range(8):
		var angle = (i / 8.0) * PI  # Only upper half arc
		var x = cos(angle) * 3
		var y = sin(angle) * 3 - 11  # Offset up to match head
		hl_points.append(Vector2(x, y))
	head_highlight.polygon = hl_points
	visual.add_child(head_highlight)

	# Shoe sole accent - slightly lighter strip
	var shoe_sole = Polygon2D.new()
	shoe_sole.name = "ShoeSole"
	shoe_sole.color = Color(0.35, 0.35, 0.35)
	shoe_sole.polygon = PackedVector2Array([
		Vector2(-4, 13), Vector2(-1, 13), Vector2(-1, 14), Vector2(-4, 14),
		Vector2(1, 13), Vector2(4, 13), Vector2(4, 14), Vector2(1, 14)
	])
	visual.add_child(shoe_sole)

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

	# Initialize needs system with tier and patience
	needs.setup(tier, patience)

	# Apply tier-based visual differentiation
	_apply_tier_visuals(tier)

func _apply_tier_visuals(tier: int) -> void:
	if not visual:
		return
	match tier:
		GolferTier.Tier.BEGINNER:
			# Beginners: no cap, casual look (hide cap, show hair)
			if cap:
				cap.visible = false
			if cap_brim:
				cap_brim.visible = false
			if hair:
				hair.visible = true
		GolferTier.Tier.CASUAL:
			# Casual: standard look (cap visible, default appearance)
			pass
		GolferTier.Tier.SERIOUS:
			# Serious: visor (cap with no top) + stripe accent on shirt
			if cap:
				cap.visible = false
			if cap_brim:
				cap_brim.visible = true
				cap_brim.color = cap_color
			# Add shirt stripe for serious golfers
			var stripe = Polygon2D.new()
			stripe.name = "TierStripe"
			stripe.color = Color(1, 1, 1, 0.25)
			stripe.polygon = PackedVector2Array([
				Vector2(-5, -1), Vector2(5, -1),
				Vector2(5, 1), Vector2(-5, 1)
			])
			visual.add_child(stripe)
		GolferTier.Tier.PRO:
			# Pro: distinct cap + logo mark + belt detail
			if cap:
				cap.color = Color(0.1, 0.1, 0.15)  # Dark branded cap
			if cap_brim:
				cap_brim.color = Color(0.08, 0.08, 0.12)
			# Logo on cap
			var logo = Polygon2D.new()
			logo.name = "CapLogo"
			logo.color = Color(1, 1, 1, 0.5)
			logo.polygon = PackedVector2Array([
				Vector2(-2, -14), Vector2(2, -14),
				Vector2(2, -12.5), Vector2(-2, -12.5)
			])
			visual.add_child(logo)
			# Belt detail
			var belt = Polygon2D.new()
			belt.name = "Belt"
			belt.color = Color(0.2, 0.2, 0.22)
			belt.polygon = PackedVector2Array([
				Vector2(-5, 4), Vector2(5, 4),
				Vector2(5, 5.5), Vector2(-5, 5.5)
			])
			visual.add_child(belt)
			# Belt buckle
			var buckle = Polygon2D.new()
			buckle.name = "Buckle"
			buckle.color = Color(0.8, 0.7, 0.3)
			buckle.polygon = PackedVector2Array([
				Vector2(-1, 4), Vector2(1, 4),
				Vector2(1, 5.5), Vector2(-1, 5.5)
			])
			visual.add_child(buckle)

## Color the floating name label by tier for at-a-glance identification
func _apply_tier_name_color() -> void:
	if not name_label:
		return
	var tier_color: Color
	match golfer_tier:
		GolferTier.Tier.BEGINNER:
			tier_color = Color(0.6, 0.8, 0.6)   # Light green
		GolferTier.Tier.CASUAL:
			tier_color = Color(0.6, 0.6, 0.9)   # Blue
		GolferTier.Tier.SERIOUS:
			tier_color = Color(0.9, 0.7, 0.3)   # Gold
		GolferTier.Tier.PRO:
			tier_color = Color(0.9, 0.3, 0.9)   # Purple
		_:
			tier_color = Color.WHITE
	name_label.add_theme_color_override("font_color", tier_color)

func _process(delta: float) -> void:
	_update_highlight_ring()

	# Track waiting time for pace satisfaction decay
	if current_state == State.IDLE and current_hole > 0:
		_wait_time_accumulated += delta
		# Apply waiting decay in 5-second chunks to avoid per-frame overhead
		if _wait_time_accumulated >= 5.0:
			needs.on_waiting(_wait_time_accumulated)
			_wait_time_accumulated = 0.0
			_check_need_triggers()

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

	# Walking animation - bob + leg swap
	if visual:
		var bob_amount = sin(Time.get_ticks_msec() / 150.0) * 1.5
		visual.position = visual_offset + Vector2(0, bob_amount)

	# 2-frame walk cycle: alternate leg positions
	_walk_timer += delta
	if _walk_timer >= WALK_FRAME_DURATION:
		_walk_timer -= WALK_FRAME_DURATION
		_walk_frame = 1 - _walk_frame
		if legs:
			legs.polygon = LEGS_FRAME_1 if _walk_frame == 1 else LEGS_FRAME_0
		if shoes:
			shoes.polygon = SHOES_FRAME_1 if _walk_frame == 1 else SHOES_FRAME_0

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
		var terrain_grid = GameManager.terrain_grid
		var current_terrain = terrain_grid.get_tile(ball_position) if terrain_grid else -1
		var on_green = current_terrain == TerrainTypes.Type.GREEN
		_play_swing_animation(on_green)

func _play_swing_animation(is_putt: bool = false) -> void:
	if not arms:
		return

	# Prevent double-triggering from both take_shot() and _process_swinging()
	swing_animation_playing = true

	# Show the golf club during swing
	if golf_club:
		golf_club.visible = true

	# IMPORTANT: In Godot 4, tween.chain().set_parallel(true) is BROKEN.
	# chain() sets parallel_enabled=false, but set_parallel(true) immediately
	# re-enables it, so the next tweener joins the current step instead of
	# creating a new one. The correct pattern is:
	#   tween.chain().tween_property(...)  — first tweener creates the new step
	#   tween.tween_property(...)          — subsequent ones are parallel (default_parallel=true)
	var tween = create_tween().set_parallel(true)

	if is_putt:
		# Putt: Gentle pendulum stroke — rotation only, no position change
		# Step 1: Slight forward press
		tween.tween_property(arms, "rotation", -0.08, 0.10).set_ease(Tween.EASE_IN_OUT)
		if hands:
			tween.tween_property(hands, "rotation", -0.08, 0.10).set_ease(Tween.EASE_IN_OUT)
		if golf_club:
			tween.tween_property(golf_club, "rotation", -0.1, 0.10).set_ease(Tween.EASE_IN_OUT)

		# Step 2: Pendulum back
		tween.chain().tween_property(arms, "rotation", 0.25, 0.20).set_ease(Tween.EASE_IN_OUT)
		if hands:
			tween.tween_property(hands, "rotation", 0.25, 0.20).set_ease(Tween.EASE_IN_OUT)
		if golf_club:
			tween.tween_property(golf_club, "rotation", 0.35, 0.20).set_ease(Tween.EASE_IN_OUT)

		# Step 3: Forward stroke
		tween.chain().tween_property(arms, "rotation", -0.2, 0.15).set_ease(Tween.EASE_IN_OUT)
		if hands:
			tween.tween_property(hands, "rotation", -0.2, 0.15).set_ease(Tween.EASE_IN_OUT)
		if golf_club:
			tween.tween_property(golf_club, "rotation", -0.3, 0.15).set_ease(Tween.EASE_IN_OUT)

		# Step 4: Return to neutral
		tween.chain().tween_property(arms, "rotation", 0.0, 0.20).set_ease(Tween.EASE_IN_OUT)
		if hands:
			tween.tween_property(hands, "rotation", 0.0, 0.20).set_ease(Tween.EASE_IN_OUT)
		if golf_club:
			tween.tween_property(golf_club, "rotation", 0.0, 0.20).set_ease(Tween.EASE_IN_OUT)
	else:
		# Full swing using position + rotation keyframes (P1-P10 swing positions).
		# Nodes must MOVE to new positions — rotation alone can't produce a backswing
		# because all nodes share the same pivot at (0,0).

		# P1 → P3: Takeaway — club and arms begin lifting back and up
		tween.tween_property(arms, "position", Vector2(2, -2), 0.14).set_ease(Tween.EASE_OUT)
		tween.tween_property(arms, "rotation", -0.5, 0.14).set_ease(Tween.EASE_OUT)
		if hands:
			tween.tween_property(hands, "position", Vector2(3, -3), 0.14).set_ease(Tween.EASE_OUT)
			tween.tween_property(hands, "rotation", -0.6, 0.14).set_ease(Tween.EASE_OUT)
		if golf_club:
			tween.tween_property(golf_club, "position", Vector2(3, -3), 0.14).set_ease(Tween.EASE_OUT)
			tween.tween_property(golf_club, "rotation", 1.5, 0.14).set_ease(Tween.EASE_OUT)
		if body:
			tween.tween_property(body, "rotation", 0.08, 0.14).set_ease(Tween.EASE_OUT)

		# P3 → P4: Top of backswing — arms raised high, club overhead pointing back
		tween.chain().tween_property(arms, "position", Vector2(4, -5), 0.22).set_ease(Tween.EASE_OUT)
		tween.tween_property(arms, "rotation", -0.8, 0.22).set_ease(Tween.EASE_OUT)
		if hands:
			tween.tween_property(hands, "position", Vector2(5, -6), 0.22).set_ease(Tween.EASE_OUT)
			tween.tween_property(hands, "rotation", -0.9, 0.22).set_ease(Tween.EASE_OUT)
		if golf_club:
			tween.tween_property(golf_club, "position", Vector2(5, -6), 0.22).set_ease(Tween.EASE_OUT)
			tween.tween_property(golf_club, "rotation", 2.8, 0.22).set_ease(Tween.EASE_OUT)
		if body:
			tween.tween_property(body, "rotation", 0.15, 0.22).set_ease(Tween.EASE_OUT)

		# Pause at top of backswing
		tween.chain().tween_interval(0.08)

		# P4 → P6: Downswing through impact — everything snaps back down
		tween.chain().tween_property(arms, "position", Vector2(0, 1), 0.06).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)
		tween.tween_property(arms, "rotation", 0.0, 0.06).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)
		if hands:
			tween.tween_property(hands, "position", Vector2(0, 1), 0.06).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)
			tween.tween_property(hands, "rotation", 0.0, 0.06).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)
		if golf_club:
			tween.tween_property(golf_club, "position", Vector2(0, 1), 0.06).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)
			tween.tween_property(golf_club, "rotation", -0.1, 0.06).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)
		if body:
			tween.tween_property(body, "rotation", -0.04, 0.06).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)

		# P6 → P8: Follow-through — arms and club sweep to the other side
		tween.chain().tween_property(arms, "position", Vector2(-3, -3), 0.14).set_ease(Tween.EASE_OUT)
		tween.tween_property(arms, "rotation", 0.6, 0.14).set_ease(Tween.EASE_OUT)
		if hands:
			tween.tween_property(hands, "position", Vector2(-4, -4), 0.14).set_ease(Tween.EASE_OUT)
			tween.tween_property(hands, "rotation", 0.7, 0.14).set_ease(Tween.EASE_OUT)
		if golf_club:
			tween.tween_property(golf_club, "position", Vector2(-3, -4), 0.14).set_ease(Tween.EASE_OUT)
			tween.tween_property(golf_club, "rotation", -2.2, 0.14).set_ease(Tween.EASE_OUT)
		if body:
			tween.tween_property(body, "rotation", -0.12, 0.14).set_ease(Tween.EASE_OUT)

		# P8 → P10: Return to neutral
		tween.chain().tween_property(arms, "position", Vector2.ZERO, 0.25).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(arms, "rotation", 0.0, 0.25).set_ease(Tween.EASE_IN_OUT)
		if hands:
			tween.tween_property(hands, "position", Vector2.ZERO, 0.25).set_ease(Tween.EASE_IN_OUT)
			tween.tween_property(hands, "rotation", 0.0, 0.25).set_ease(Tween.EASE_IN_OUT)
		if golf_club:
			tween.tween_property(golf_club, "position", Vector2.ZERO, 0.25).set_ease(Tween.EASE_IN_OUT)
			tween.tween_property(golf_club, "rotation", 0.0, 0.25).set_ease(Tween.EASE_IN_OUT)
		if body:
			tween.tween_property(body, "rotation", 0.0, 0.25).set_ease(Tween.EASE_IN_OUT)

	await tween.finished
	if not is_instance_valid(self):
		return
	swing_animation_playing = false

## Start playing a hole
func start_hole(hole_number: int, tee_position: Vector2i) -> void:
	current_hole = hole_number
	current_strokes = 0
	ball_position = tee_position
	ball_position_precise = Vector2(tee_position)
	# Clear visited buildings and reset wait timer at start of round
	if hole_number == 0:
		_visited_buildings.clear()
		_wait_time_accumulated = 0.0

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

	var terrain_grid = GameManager.terrain_grid
	# Use rounded precise position for terrain check to handle sub-tile edge cases
	var terrain_check_pos = Vector2i(ball_position_precise.round()) if terrain_grid else ball_position
	var current_terrain = terrain_grid.get_tile(terrain_check_pos) if terrain_grid else -1
	var is_putt = current_terrain == TerrainTypes.Type.GREEN

	# Play swing animation before the ball leaves
	await _play_swing_animation(is_putt)
	if not is_instance_valid(self):
		return

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
	var hole_data_dbg = GameManager.course_data.holes[current_hole]
	var hole_par = hole_data_dbg.par
	var hole_yardage = hole_data_dbg.distance_yards
	var tier_name = GolferTier.get_tier_name(golfer_tier)

	# Distance remaining to hole after this shot
	var hole_pos_dbg = Vector2(hole_data_dbg.hole_position)
	var remaining_tiles = ball_position_precise.distance_to(hole_pos_dbg)
	var remaining_yards = int(remaining_tiles * 22.0)

	# Landing terrain
	var terrain_grid_dbg = GameManager.terrain_grid
	var landing_terrain_name = "?"
	if terrain_grid_dbg:
		var landing_terrain_type = terrain_grid_dbg.get_tile(ball_position)
		landing_terrain_name = TerrainTypes.get_type_name(landing_terrain_type)

	# Extra details
	var extras = []
	if is_putt:
		var dist_to_hole_ft = remaining_tiles * 22.0 * 3.0
		extras.append("%.1fft to hole" % dist_to_hole_ft)
	else:
		# Miss angle
		var miss_deg = shot_result.get("miss_angle_deg", 0.0)
		if absf(miss_deg) > 0.1:
			var miss_dir = "slice" if miss_deg > 0 else "hook"
			extras.append("%.1f° %s" % [absf(miss_deg), miss_dir])
		if shot_result.get("is_shank", false):
			extras.append("SHANK")
		# Rollout
		if shot_result.get("rollout_tiles", 0.0) > 0.0:
			var roll_yards = shot_result.rollout_tiles * 22.0
			var spin_label = " backspin" if shot_result.get("is_backspin", false) else ""
			extras.append("%.0fyd roll%s" % [roll_yards, spin_label])
		# Yards off target
		var target_pos = shot_result.get("target", Vector2i.ZERO)
		if target_pos != Vector2i.ZERO:
			var off_target_tiles = ball_position_precise.distance_to(Vector2(target_pos))
			var off_target_yards = int(off_target_tiles * 22.0)
			if off_target_yards > 0:
				extras.append("%dyd off target" % off_target_yards)

	# Wind info
	var wind_str = ""
	if GameManager.wind_system and not is_putt:
		var ws = GameManager.wind_system
		if ws.wind_speed > 1.0:
			var wind_deg = rad_to_deg(ws.wind_direction)
			var compass = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
			var compass_idx = int(round(wind_deg / 45.0)) % 8
			wind_str = " | Wind: %dmph %s" % [int(ws.wind_speed), compass[compass_idx]]

	var extra_str = " | " + ", ".join(extras) if extras.size() > 0 else ""
	var strategy_str = " [%s]" % _shot_strategy if _shot_strategy != "normal" else ""
	print("[SHOT] %s (%s) H%d S%d | Par %d, %dyd | %s %dyd, %.1f%% acc | Remaining: %dyd (%s)%s%s%s" % [
		golfer_name, tier_name,
		current_hole + 1, current_strokes,
		hole_par, hole_yardage,
		club_name, shot_result.distance, shot_result.accuracy * 100,
		remaining_yards, landing_terrain_name,
		extra_str, wind_str, strategy_str
	])

	# Shank thought bubble
	if shot_result.get("is_shank", false):
		show_thought(FeedbackTriggers.TriggerType.SHANK)

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
	if not is_instance_valid(self):
		return

	# Check for hazards at landing position and apply penalties (skip if ball holed)
	if not ball_holed and _handle_hazard_penalty(previous_position):
		await get_tree().create_timer(1.0).timeout
		if not is_instance_valid(self):
			return

	# Walk to the ball (or to the hole to grab it if holed)
	_walk_to_ball()

## Finish current hole
func finish_hole(par: int) -> void:
	hole_scores.append({"hole": current_hole, "strokes": current_strokes, "par": par})
	total_strokes += current_strokes
	total_par += par
	previous_hole_strokes = current_strokes  # Store for honor system on next tee

	# Update mood based on performance relative to personal expectation
	var avg_skill = (driving_skill + accuracy_skill + putting_skill + recovery_skill) / 4.0
	var expected_score = par + FeedbackTriggers.get_expected_over_par(avg_skill)
	var performance = current_strokes - expected_score  # negative = better than expected
	if performance <= -2.0:       # Way better than expected
		_adjust_mood(0.3)
	elif performance <= -1.0:     # Better than expected
		_adjust_mood(0.15)
	elif performance <= 0.5:      # At or near expected
		_adjust_mood(0.05)
	elif performance <= 1.5:      # Slightly worse than expected
		_adjust_mood(-0.1)
	else:                         # Much worse than expected
		_adjust_mood(-0.2)

	# Decay needs after completing a hole
	needs.on_hole_completed()
	# Apply mood penalty from critically low needs
	var need_penalty = needs.get_mood_penalty()
	if need_penalty < 0.0:
		_adjust_mood(need_penalty)
	# Check for needs-based feedback triggers
	_check_need_triggers()
	# Reset wait timer (golfer is actively playing)
	_wait_time_accumulated = 0.0

	# Show thought bubble for notable scores
	var score_trigger = FeedbackTriggers.get_score_trigger(current_strokes, par, avg_skill)
	if score_trigger != -1:
		show_thought(score_trigger)

	# Check for records
	var records = GameManager.check_hole_records(golfer_name, current_hole, current_strokes)
	for record in records:
		if record.type == "hole_in_one":
			# Spawn celebration effect
			HoleInOneCelebration.create_at(get_parent(), global_position)

	# Per-hole debug summary
	var _score_diff = current_strokes - par
	var _score_label: String
	if _score_diff <= -3: _score_label = "Double Eagle"
	elif _score_diff == -2: _score_label = "Eagle"
	elif _score_diff == -1: _score_label = "Birdie"
	elif _score_diff == 0: _score_label = "Par"
	elif _score_diff == 1: _score_label = "Bogey"
	elif _score_diff == 2: _score_label = "Double Bogey"
	elif _score_diff == 3: _score_label = "Triple Bogey"
	else: _score_label = "+%d" % _score_diff
	var _hole_yardage = 0
	var _course_data = GameManager.course_data
	if _course_data and current_hole < _course_data.holes.size():
		_hole_yardage = _course_data.holes[current_hole].distance_yards
	if current_strokes == 1: _score_label = "HOLE IN ONE"
	print("[HOLE] %s (%s) H%d: %s (%d/%d) | %dyd par %d | Skills: D%.2f A%.2f P%.2f R%.2f | Tendency: %.2f" % [
		golfer_name, GolferTier.get_tier_name(golfer_tier),
		current_hole + 1, _score_label, current_strokes, par,
		_hole_yardage, par,
		driving_skill, accuracy_skill, putting_skill, recovery_skill, miss_tendency
	])

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

	# Check if course has too few holes — golfers are disappointed by short courses
	var open_holes = GameManager.get_open_hole_count()
	if open_holes < 9 and open_holes > 0:
		show_thought(FeedbackTriggers.TriggerType.TOO_FEW_HOLES)
	else:
		# Show course satisfaction feedback (only if course has enough holes)
		var avg_skill = (driving_skill + accuracy_skill + putting_skill + recovery_skill) / 4.0
		var holes_played = hole_scores.size()
		var course_trigger = FeedbackTriggers.get_course_trigger(total_strokes, total_par, avg_skill, holes_played)
		if course_trigger != -1:
			show_thought(course_trigger)

	# Per-round debug summary
	var _eagles = 0
	var _birdies = 0
	var _pars = 0
	var _bogeys = 0
	var _doubles = 0
	var _triples_plus = 0
	for hs in hole_scores:
		var diff = hs.strokes - hs.par
		if diff <= -2: _eagles += 1
		elif diff == -1: _birdies += 1
		elif diff == 0: _pars += 1
		elif diff == 1: _bogeys += 1
		elif diff == 2: _doubles += 1
		else: _triples_plus += 1
	var _vs_par = total_strokes - total_par
	var _vs_par_str = "E" if _vs_par == 0 else ("%+d" % _vs_par)
	var _needs = needs.to_dict()
	print("[ROUND] %s (%s): %s (%d/%d) | %d holes | %dE %dB %dP %dBo %dDB %d+3 | Skills: D%.2f A%.2f P%.2f R%.2f | Tendency: %.2f | Needs: E%.2f C%.2f H%.2f P%.2f" % [
		golfer_name, GolferTier.get_tier_name(golfer_tier),
		_vs_par_str, total_strokes, total_par,
		hole_scores.size(),
		_eagles, _birdies, _pars, _bogeys, _doubles, _triples_plus,
		driving_skill, accuracy_skill, putting_skill, recovery_skill, miss_tendency,
		_needs.energy, _needs.comfort, _needs.hunger, _needs.pace,
	])

	EventBus.golfer_finished_round.emit(golfer_id, total_strokes)

## Select appropriate club based on distance and terrain (legacy compatibility).
## Primary club selection is now handled by ShotAI.decide_shot().
func select_club(distance_to_target: float, current_terrain: int) -> Club:
	if current_terrain == TerrainTypes.Type.GREEN:
		return Club.PUTTER
	if distance_to_target >= CLUB_STATS[Club.DRIVER]["min_distance"]:
		return Club.DRIVER
	elif distance_to_target >= CLUB_STATS[Club.FAIRWAY_WOOD]["min_distance"]:
		return Club.FAIRWAY_WOOD
	elif distance_to_target >= CLUB_STATS[Club.IRON]["min_distance"]:
		return Club.IRON
	else:
		return Club.WEDGE

## Get the fraction of a club's max distance this golfer can achieve.
## Skill-based distance scaling: beginners reach ~45-60% of max, pros reach ~89-94%.
## Used in targeting so golfers aim at spots within their actual range.
## Target carry distances (before rollout):
##   Beginner (0.30-0.50): Driver 174-208yd, FW 110-143yd, Iron 92-123yd
##   Casual   (0.50-0.70): Driver 208-242yd, FW 143-176yd, Iron 123-152yd
##   Serious  (0.70-0.85): Driver 242-267yd, FW 176-198yd, Iron 152-169yd
##   Pro      (0.85-0.98): Driver 267-289yd, FW 198-217yd, Iron 169-183yd
func _get_skill_distance_factor(club: Club) -> float:
	match club:
		Club.DRIVER:
			return 0.40 + driving_skill * 0.55
		Club.FAIRWAY_WOOD:
			return 0.40 + driving_skill * 0.50
		Club.IRON:
			return 0.50 + accuracy_skill * 0.42
		Club.WEDGE:
			return 0.80 + accuracy_skill * 0.18
		Club.PUTTER:
			return 0.92 + putting_skill * 0.06
		_:
			return 0.85

## AI decision making - decide where to aim shot.
## Delegates to ShotAI for multi-shot planning, wind compensation, recovery logic,
## green reading, and risk analysis. Returns aim point and stores chosen club.
func decide_shot_target(hole_position: Vector2i) -> Vector2i:
	var decision: ShotAI.ShotDecision = ShotAI.decide_shot(self, hole_position)
	_chosen_club = decision.club
	_shot_strategy = decision.strategy
	return decision.target

## Legacy club selection (kept for ShotPathCalculator compatibility).
## New shot AI uses ShotAI.decide_shot() which handles club selection internally.

## Calculate putt with sub-tile precision
## Uses probability-based make model calibrated to PGA Tour putting stats,
## scaled by putting_skill. Misses are realistic: putts can go past the hole,
## stop short, or miss laterally. Three-putts are possible.
##
## Make rates (at skill=0.95, roughly PGA Tour level):
##   3 ft (~0.045 tiles): tap-in     5 ft (~0.076 tiles): ~77%
##  10 ft (~0.15 tiles):  ~45%      20 ft (~0.30 tiles):  ~22%
##  30 ft (~0.45 tiles):  ~11%      50 ft (~0.76 tiles):  ~3%
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

	# Step 1: Tap-in check — automatic make within ~3 feet
	if distance < GolfRules.TAP_IN_DISTANCE:
		landing = hole_pos
	else:
		# Step 2: Determine if the putt is made (probability-based)
		var make_rate = GolfRules.get_putt_make_rate(distance, putting_skill)
		var is_made = randf() < make_rate

		if is_made:
			# Putt drops — ball ends up in the hole
			landing = hole_pos
		else:
			# Putt misses — calculate realistic miss position
			var miss_chars = GolfRules.get_putt_miss_characteristics(distance, putting_skill)

			# Distance error: gaussian sample around the hole position
			# Positive = past the hole, negative = short of the hole
			var distance_error = _gaussian_random() * miss_chars.distance_std + miss_chars.long_bias

			# Lateral error: gaussian sample for left/right miss
			var lateral_error = _gaussian_random() * miss_chars.lateral_std

			# Landing point is relative to the hole position (not the start)
			landing = hole_pos + direction * distance_error + perpendicular * lateral_error

			# Safety: cap miss distance so putts don't end up absurdly far from the hole
			# Tighter caps prevent cascading multi-putt cycles.
			# Skilled putters (0.8+) should leave misses within easy tap-in range.
			var max_miss_from_hole: float
			if distance < 0.15:
				# Short putts (<10ft): misses stay very close
				max_miss_from_hole = 0.03 + (1.0 - putting_skill) * 0.025   # ~2-3.6 ft
			elif distance < 0.45:
				# Medium putts (10-30ft): tighter cap, skilled putters leave ~3ft not 5+ft
				max_miss_from_hole = 0.04 + (1.0 - putting_skill) * 0.05    # ~2.6-5.9 ft
			else:
				# Long putts (30ft+): proportional but tighter
				max_miss_from_hole = distance * (0.08 + (1.0 - putting_skill) * 0.12)

			var miss_dist = landing.distance_to(hole_pos)
			if miss_dist > max_miss_from_hole:
				landing = hole_pos + (landing - hole_pos).normalized() * max_miss_from_hole

			# Snap to hole if the miss accidentally ended up very close (cup radius)
			if landing.distance_to(hole_pos) < GolfRules.CUP_RADIUS:
				landing = hole_pos

	# Ensure landing stays on or near green terrain.
	# For fringe putts (starting off-green), the path may cross grass before reaching
	# the green — only constrain the landing once the path has entered the green.
	var landing_tile = Vector2i(landing.round())
	if not terrain_grid.is_valid_position(landing_tile) or terrain_grid.get_tile(landing_tile) != TerrainTypes.Type.GREEN:
		var steps = max(int(from_precise.distance_to(landing) * 10.0), 1)
		var last_valid = from_precise
		var entered_green = false
		for i in range(1, steps + 1):
			var t = i / float(steps)
			var check = from_precise.lerp(landing, t)
			var check_tile = Vector2i(check.round())
			if terrain_grid.is_valid_position(check_tile) and terrain_grid.get_tile(check_tile) == TerrainTypes.Type.GREEN:
				entered_green = true
				last_valid = check
			elif entered_green:
				break  # Left the green after entering — stop at the edge
		if entered_green:
			landing = last_valid
		# If path never crossed the green (fringe putt that missed), keep calculated
		# landing position — the ball ends up on grass/rough near the green.

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

	# Use the club chosen during targeting (decide_shot_target) to avoid mismatch.
	# Previously select_club() re-derived the club from distance alone, which could
	# pick a different club than what the targeting AI evaluated (e.g., targeting
	# chose Driver at 9.4 tiles but select_club picked FW because 9.4 < 10).
	var current_terrain = terrain_grid.get_tile(from)
	var distance_to_target = Vector2(from).distance_to(Vector2(target))
	var club: Club
	if current_terrain == TerrainTypes.Type.GREEN:
		club = Club.PUTTER  # Always putt on the green
	else:
		club = _chosen_club
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

	# Distance modifier: shot-to-shot variance only.
	# Skill-based distance scaling is handled in targeting (_get_skill_distance_factor),
	# so the golfer already aims at a spot within their range. Execution applies only
	# small random variance representing natural swing inconsistency.
	var distance_modifier = 1.0
	if club == Club.DRIVER:
		distance_modifier = 0.97 + randf_range(-0.06, 0.04)    # 0.91-1.01
	elif club == Club.FAIRWAY_WOOD:
		distance_modifier = 0.97 + randf_range(-0.05, 0.04)    # 0.92-1.01
	elif club == Club.IRON:
		distance_modifier = 0.98 + randf_range(-0.04, 0.03)    # 0.94-1.01
	elif club == Club.WEDGE:
		distance_modifier = 0.98 + randf_range(-0.03, 0.02)    # 0.95-1.00
	elif club == Club.PUTTER:
		distance_modifier = 0.99 + randf_range(-0.02, 0.01)    # 0.97-1.00

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

	# Guard against degenerate zero-distance shots (e.g. target rounded to ball position)
	# Use the hole as a fallback direction with a minimum 1-tile chip
	if intended_distance < 0.5:
		var course_data = GameManager.course_data
		if course_data and current_hole < course_data.holes.size():
			var hole_pos = course_data.holes[current_hole].hole_position
			var dist_to_hole = Vector2(from).distance_to(Vector2(hole_pos))
			if dist_to_hole > 0.1:
				target = hole_pos
				intended_distance = dist_to_hole

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
	# ~3% for worst beginners, <0.3% for pros
	var is_shank = false
	if club != Club.PUTTER and club != Club.WEDGE:
		var shank_chance = (1.0 - total_accuracy) * 0.04
		if randf() < shank_chance:
			is_shank = true
			var shank_dir = 1.0 if miss_tendency >= 0.0 else -1.0
			miss_angle_deg = shank_dir * randf_range(35.0, 55.0)
			actual_distance *= randf_range(0.3, 0.6)

	# Rotate direction by miss angle
	var miss_angle_rad = deg_to_rad(miss_angle_deg)
	var miss_direction = direction.rotated(miss_angle_rad)
	var landing_point = Vector2(from) + (miss_direction * actual_distance)

	# Minimum lateral dispersion floor for short/medium-range shots.
	# The angular model produces tight clusters at close range (same angle = fewer
	# yards off-target), but real golfers have swing inconsistencies (alignment,
	# contact quality, tempo) that spread short iron shots across the target area.
	# This floor ensures beginners scatter across the green on short par 3s rather
	# than all landing in a tight cluster.
	if club != Club.PUTTER:
		var angular_lateral_std = actual_distance * sin(deg_to_rad(spread_std_dev))
		var min_lateral_std = (1.0 - total_accuracy) * 0.8
		if angular_lateral_std < min_lateral_std:
			var perpendicular = Vector2(-miss_direction.y, miss_direction.x)
			var extra_std = sqrt(min_lateral_std * min_lateral_std - angular_lateral_std * angular_lateral_std)
			landing_point += perpendicular * (_gaussian_random() * extra_std)

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

		var distance_yards = terrain_grid.calculate_distance_yards_precise(Vector2(from), carry_position_precise)
		return {
			"landing_position": carry_position,
			"landing_position_precise": carry_position_precise,
			"carry_position_precise": carry_position_precise,
			"distance": distance_yards,
			"accuracy": total_accuracy,
			"club": club,
			"rollout_tiles": 0.0,
			"is_backspin": false,
			"miss_angle_deg": miss_angle_deg,
			"is_shank": is_shank,
			"target": target,
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

	var distance_yards = terrain_grid.calculate_distance_yards_precise(Vector2(from), final_position_precise)

	return {
		"landing_position": final_position,
		"landing_position_precise": final_position_precise,
		"carry_position_precise": carry_position_precise,
		"distance": distance_yards,
		"accuracy": total_accuracy,
		"club": club,
		"rollout_tiles": rollout.rollout_distance,
		"is_backspin": rollout.is_backspin,
		"miss_angle_deg": miss_angle_deg,
		"is_shank": is_shank,
		"target": target,
	}

## Approximate gaussian random using Central Limit Theorem (sum of uniform randoms).
## Returns value with mean ~0 and std dev ~1. Range approximately -3.5 to +3.5.
## 68% of values within ±1, 95% within ±2, 99.7% within ±3.
func _gaussian_random() -> float:
	return (randf() + randf() + randf() + randf() - 2.0) / 0.5774

## Get lie modifier based on terrain type and club — delegates to GolfRules
func _get_lie_modifier(terrain_type: int, club: Club) -> float:
	return GolfRules.get_lie_modifier(terrain_type, club)

## Get distance modifier based on terrain — delegates to GolfRules
func _get_terrain_distance_modifier(terrain_type: int) -> float:
	return GolfRules.get_terrain_distance_modifier(terrain_type)

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

	# No rollout if ball lands in water, OB, bunker (plugs in sand), or flower beds
	if carry_terrain in [TerrainTypes.Type.WATER, TerrainTypes.Type.OUT_OF_BOUNDS,
			TerrainTypes.Type.BUNKER, TerrainTypes.Type.FLOWER_BED]:
		return no_rollout

	# --- Base rollout fraction (proportion of carry distance) ---
	# Real golf: driver rolls 5-15%, fairway 5-14%, irons 5-14%, wedges 0-10%
	var rollout_min: float
	var rollout_max: float
	var is_wedge_chip = false

	match club:
		Club.DRIVER:
			rollout_min = 0.05
			rollout_max = 0.15
		Club.FAIRWAY_WOOD:
			rollout_min = 0.05
			rollout_max = 0.14
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
		TerrainTypes.Type.TEE_BOX:
			terrain_roll_mult = 1.0   # Mowed short like fairway
		TerrainTypes.Type.GRASS:
			terrain_roll_mult = 0.35  # Natural grass — slightly better than rough
		TerrainTypes.Type.ROUGH:
			terrain_roll_mult = 0.3   # Rough grabs the ball
		TerrainTypes.Type.HEAVY_ROUGH:
			terrain_roll_mult = 0.12  # Thick stuff — ball stops fast
		TerrainTypes.Type.TREES:
			terrain_roll_mult = 0.2   # Dense ground cover
		TerrainTypes.Type.ROCKS:
			terrain_roll_mult = 0.15  # Rocky ground kills momentum
		TerrainTypes.Type.PATH:
			terrain_roll_mult = 1.4   # Hard surface — extra bounce/roll
		_:
			terrain_roll_mult = 0.3   # Unknown terrain — conservative

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

## Handle hazard penalties and non-playable terrain. Returns true if relief was applied.
## Uses GolfRules.get_relief_type() to determine correct USGA-based relief procedure.
func _handle_hazard_penalty(previous_position: Vector2i) -> bool:
	var terrain_grid = GameManager.terrain_grid
	if not terrain_grid:
		return false

	var landing_terrain = terrain_grid.get_tile(ball_position)
	var relief_type = GolfRules.get_relief_type(landing_terrain)

	if relief_type == GolfRules.ReliefType.NONE:
		return false

	var penalty = GolfRules.get_penalty_strokes(landing_terrain)
	current_strokes += penalty

	match relief_type:
		GolfRules.ReliefType.DROP_AT_ENTRY:
			# Water/penalty area: drop near point of entry, no closer to hole
			var entry_point = _find_water_entry_point(previous_position, ball_position)
			var drop_position = _find_water_drop_position(entry_point)
			print("%s: Ball in water! Penalty stroke. Dropping at point of entry. Now on stroke %d" % [golfer_name, current_strokes])
			EventBus.hazard_penalty.emit(golfer_id, "water", drop_position)
			show_thought(FeedbackTriggers.TriggerType.HAZARD_WATER)
			ball_position = drop_position
			ball_position_precise = Vector2(drop_position)

		GolfRules.ReliefType.STROKE_AND_DISTANCE:
			# OB: replay from previous position (USGA Rule 18.2)
			print("%s: Ball out of bounds! Penalty stroke. Replaying from previous position. Now on stroke %d" % [golfer_name, current_strokes])
			EventBus.hazard_penalty.emit(golfer_id, "ob", previous_position)
			ball_position = previous_position
			ball_position_precise = Vector2(previous_position)

		GolfRules.ReliefType.FREE_RELIEF:
			# Ground under repair (flower beds, empty terrain): free drop to nearest playable
			var drop_position = _find_water_drop_position(ball_position)
			print("%s: Ball on non-playable ground. Free relief to nearest playable area." % [golfer_name])
			ball_position = drop_position
			ball_position_precise = Vector2(drop_position)

	return true

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
## landing penalties are handled separately by ShotAI._score_landing_zone.
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
			# Landing in water/OB is penalized by ShotAI terrain scoring.
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

## Check needs and show thought bubbles for unmet needs
func _check_need_triggers() -> void:
	var triggers = needs.check_need_triggers()
	for trigger in triggers:
		show_thought(trigger)

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
		arms.position = Vector2.ZERO
	if hands:
		hands.rotation = 0
		hands.position = Vector2.ZERO
	if body:
		body.rotation = 0

	# Reset legs to default pose (undo walk animation)
	if legs:
		legs.polygon = LEGS_FRAME_0
	if shoes:
		shoes.polygon = SHOES_FRAME_0
	_walk_frame = 0
	_walk_timer = 0.0

	# Hide golf club by default
	if golf_club:
		golf_club.visible = false
		golf_club.rotation = 0
		golf_club.position = Vector2.ZERO

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
			# Show golf club — tween animation handles all positioning
			if golf_club:
				golf_club.visible = true
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
			if not is_instance_valid(self):
				return
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

			# Check if golfer decides to stop at this building
			# Lower needs = higher chance of interacting; prevents revenue spam
			var interact_chance = needs.get_interaction_chance(building.building_type)
			if randf() > interact_chance:
				continue  # Golfer walks past without stopping

			# Apply effect based on type
			# Use building methods to get upgrade-aware values
			if effect_type == "revenue":
				var income = building.get_income_per_golfer()
				if income > 0:
					GameManager.modify_money(income)
					GameManager.daily_stats.building_revenue += income
					EventBus.log_transaction("%s at %s" % [golfer_name, building.building_type], income)
					_show_building_revenue_notification(income, building.building_type)

			# Apply needs-based satisfaction from buildings
			var mood_boost = needs.apply_building_effect(building.building_type)
			if mood_boost > 0.0:
				_adjust_mood(mood_boost)

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

		# Apply needs-based satisfaction from clubhouse visit
		var mood_boost = needs.apply_building_effect("clubhouse")
		# Also apply upgrade-specific satisfaction bonus on top
		var upgrade_bonus = building.get_satisfaction_bonus()
		if upgrade_bonus > 0:
			_adjust_mood(upgrade_bonus)
		if mood_boost > 0.0:
			_adjust_mood(mood_boost)

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

## Click detection handler (mirrors Building pattern)
func _on_click_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		golfer_selected.emit(self)

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
