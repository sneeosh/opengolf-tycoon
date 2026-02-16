extends Node2D
class_name PlacementFeedback
## PlacementFeedback - Particle effects and animations for entity placement

# Particle colors by placement type
const TREE_COLORS := [
	Color(0.3, 0.7, 0.3),  # Green
	Color(0.4, 0.6, 0.2),  # Yellow-green
	Color(0.25, 0.5, 0.2), # Dark green
]

const ROCK_COLORS := [
	Color(0.6, 0.6, 0.6),  # Gray
	Color(0.5, 0.5, 0.5),  # Medium gray
	Color(0.7, 0.65, 0.6), # Warm gray
]

const BUILDING_COLORS := [
	Color(0.9, 0.8, 0.6),  # Sand
	Color(0.8, 0.7, 0.5),  # Tan
	Color(0.7, 0.6, 0.4),  # Brown
]

const TERRAIN_COLORS := [
	Color(0.5, 0.8, 0.4),  # Grass green
	Color(0.6, 0.7, 0.3),  # Yellow-green
	Color(0.4, 0.6, 0.3),  # Dark green
]

# Particle settings
const PARTICLE_COUNT := 12
const PARTICLE_LIFETIME := 0.6
const PARTICLE_SPEED_MIN := 40.0
const PARTICLE_SPEED_MAX := 100.0
const PARTICLE_SIZE := 4.0
const GRAVITY := 120.0

# Animation settings
const POP_SCALE_MAX := 1.3
const POP_DURATION := 0.25

var _particles: Array = []
var _active := false

# =============================================================================
# STATIC FACTORY METHODS
# =============================================================================

static func create_at(parent: Node, world_position: Vector2, placement_type: String) -> PlacementFeedback:
	var effect = PlacementFeedback.new()
	effect.global_position = world_position
	parent.add_child(effect)
	effect._start_effect(placement_type)
	return effect

static func create_terrain_effect(parent: Node, world_position: Vector2) -> PlacementFeedback:
	var effect = PlacementFeedback.new()
	effect.global_position = world_position
	parent.add_child(effect)
	effect._start_terrain_effect()
	return effect

# =============================================================================
# EFFECT INITIALIZATION
# =============================================================================

func _start_effect(placement_type: String) -> void:
	_active = true

	var colors: Array
	match placement_type:
		"tree":
			colors = TREE_COLORS
		"rock":
			colors = ROCK_COLORS
		"building":
			colors = BUILDING_COLORS
		_:
			colors = TERRAIN_COLORS

	_spawn_particles(colors)
	_play_pop_animation()

func _start_terrain_effect() -> void:
	_active = true
	_spawn_dust_particles()

func _spawn_particles(colors: Array) -> void:
	for i in range(PARTICLE_COUNT):
		var angle = randf() * TAU
		var speed = randf_range(PARTICLE_SPEED_MIN, PARTICLE_SPEED_MAX)
		var color = colors[randi() % colors.size()]

		var particle = {
			"position": Vector2.ZERO,
			"velocity": Vector2(cos(angle), sin(angle)) * speed + Vector2(0, -speed * 0.5),
			"color": color,
			"size": PARTICLE_SIZE * randf_range(0.7, 1.3),
			"lifetime": PARTICLE_LIFETIME * randf_range(0.8, 1.2),
			"age": 0.0,
			"rotation": randf() * TAU,
			"rotation_speed": randf_range(-5.0, 5.0)
		}
		_particles.append(particle)

func _spawn_dust_particles() -> void:
	for i in range(6):
		var angle = randf() * TAU
		var speed = randf_range(20.0, 50.0)
		var color = TERRAIN_COLORS[randi() % TERRAIN_COLORS.size()]
		color.a = 0.6

		var particle = {
			"position": Vector2.ZERO,
			"velocity": Vector2(cos(angle), sin(angle)) * speed,
			"color": color,
			"size": 3.0 * randf_range(0.8, 1.2),
			"lifetime": 0.4,
			"age": 0.0,
			"rotation": 0.0,
			"rotation_speed": 0.0
		}
		_particles.append(particle)

func _play_pop_animation() -> void:
	# Create a temporary node for the pop effect
	var pop_circle = Node2D.new()
	add_child(pop_circle)

	# Animate scale and alpha
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)

	# Scale up then down
	pop_circle.scale = Vector2(0.5, 0.5)
	tween.tween_property(pop_circle, "scale", Vector2(POP_SCALE_MAX, POP_SCALE_MAX), POP_DURATION * 0.4)
	tween.tween_property(pop_circle, "scale", Vector2(1.0, 1.0), POP_DURATION * 0.6)
	tween.tween_callback(pop_circle.queue_free)

# =============================================================================
# UPDATE & DRAW
# =============================================================================

func _process(delta: float) -> void:
	if not _active:
		return

	var all_dead = true

	for particle in _particles:
		particle["age"] += delta

		if particle["age"] < particle["lifetime"]:
			all_dead = false

			# Apply gravity
			particle["velocity"].y += GRAVITY * delta

			# Update position
			particle["position"] += particle["velocity"] * delta

			# Update rotation
			particle["rotation"] += particle["rotation_speed"] * delta

	queue_redraw()

	if all_dead:
		queue_free()

func _draw() -> void:
	for particle in _particles:
		if particle["age"] >= particle["lifetime"]:
			continue

		var progress = particle["age"] / particle["lifetime"]
		var alpha = 1.0 - ease(progress, 2.0)  # Ease out

		var color = particle["color"]
		color.a *= alpha

		var pos = particle["position"]
		var size = particle["size"] * (1.0 - progress * 0.5)

		# Draw as diamond/star shape
		_draw_particle(pos, size, particle["rotation"], color)

func _draw_particle(pos: Vector2, size: float, rotation: float, color: Color) -> void:
	var points = PackedVector2Array()

	# Create diamond shape
	for i in range(4):
		var angle = rotation + i * PI / 2.0
		points.append(pos + Vector2(cos(angle), sin(angle)) * size)

	draw_colored_polygon(points, color)

# =============================================================================
# RING BURST EFFECT (Alternative visual)
# =============================================================================

static func create_ring_burst(parent: Node, world_position: Vector2, color: Color = Color.WHITE) -> void:
	var ring = Node2D.new()
	ring.global_position = world_position
	ring.z_index = 50
	parent.add_child(ring)

	# Custom draw for expanding ring
	var ring_data = {"radius": 5.0, "alpha": 1.0, "width": 3.0, "color": color}

	ring.set_meta("ring_data", ring_data)
	ring.draw.connect(func():
		var data = ring.get_meta("ring_data")
		var c = data["color"]
		c.a = data["alpha"]
		ring.draw_arc(Vector2.ZERO, data["radius"], 0, TAU, 32, c, data["width"], true)
	)

	var tween = ring.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_parallel(true)

	tween.tween_method(func(r): ring_data["radius"] = r; ring.queue_redraw(), 5.0, 40.0, 0.4)
	tween.tween_method(func(a): ring_data["alpha"] = a; ring.queue_redraw(), 1.0, 0.0, 0.4)
	tween.tween_method(func(w): ring_data["width"] = w; ring.queue_redraw(), 3.0, 1.0, 0.4)

	tween.chain().tween_callback(ring.queue_free)

# =============================================================================
# SCREEN SHAKE (Call on camera)
# =============================================================================

static func apply_screen_shake(camera: Camera2D, intensity: float = 5.0, duration: float = 0.15) -> void:
	if not camera:
		return

	var original_offset = camera.offset
	var tween = camera.create_tween()

	for i in range(4):
		var shake_offset = Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		tween.tween_property(camera, "offset", original_offset + shake_offset, duration / 4.0)

	tween.tween_property(camera, "offset", original_offset, duration / 4.0)

# =============================================================================
# SOUND HOOK (Placeholder for future audio)
# =============================================================================

static func play_placement_sound(placement_type: String) -> void:
	SoundManager.play_placement_sound(placement_type)
