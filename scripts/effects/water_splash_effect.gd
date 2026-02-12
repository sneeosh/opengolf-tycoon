extends Node2D
class_name WaterSplashEffect
## WaterSplashEffect - Temporary particle effect for water hazard shots

const PARTICLE_COUNT: int = 12
const PARTICLE_LIFETIME: float = 1.0
const PARTICLE_COLORS: Array = [
	Color(0.4, 0.6, 0.9, 0.8),  # Light blue
	Color(0.3, 0.5, 0.85, 0.7),  # Medium blue
	Color(0.5, 0.7, 0.95, 0.6),  # Pale blue
	Color(1.0, 1.0, 1.0, 0.5),  # White foam
]

var _particles_finished: int = 0

func _ready() -> void:
	z_index = 200  # Above everything
	_spawn_particles()

func _spawn_particles() -> void:
	for i in range(PARTICLE_COUNT):
		var particle = Polygon2D.new()
		particle.color = PARTICLE_COLORS[randi() % PARTICLE_COLORS.size()]

		# Water droplet shape (small circle-ish)
		var size = randf_range(2.0, 5.0)
		var points = PackedVector2Array()
		for j in range(6):
			var angle = (j / 6.0) * TAU
			points.append(Vector2(cos(angle) * size, sin(angle) * size * 0.7))
		particle.polygon = points

		add_child(particle)

		# Upward splash trajectory then fall back down
		var angle = randf_range(-PI * 0.85, -PI * 0.15)  # Upward arc
		var speed = randf_range(40.0, 100.0)
		var target_offset = Vector2(cos(angle), sin(angle)) * speed
		var lifetime = randf_range(PARTICLE_LIFETIME * 0.5, PARTICLE_LIFETIME)

		# Create separate tweens: one for position arc, one for alpha fade
		# Position tween: arc up then down (sequential)
		var pos_tween = create_tween()
		pos_tween.tween_property(particle, "position", target_offset, lifetime * 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		pos_tween.tween_property(particle, "position", target_offset + Vector2(0, 20), lifetime * 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		pos_tween.tween_callback(_on_particle_finished)

		# Alpha tween: fade out over full lifetime (runs in parallel with position)
		var alpha_tween = create_tween()
		alpha_tween.tween_property(particle, "modulate:a", 0.0, lifetime).set_ease(Tween.EASE_IN)

## Play the effect at a world position
static func create_at(parent: Node, world_position: Vector2) -> WaterSplashEffect:
	var effect = WaterSplashEffect.new()
	effect.global_position = world_position
	parent.add_child(effect)
	return effect

func _on_particle_finished() -> void:
	_particles_finished += 1
	if _particles_finished >= PARTICLE_COUNT:
		queue_free()
