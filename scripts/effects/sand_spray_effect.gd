extends Node2D
class_name SandSprayEffect
## SandSprayEffect - Temporary particle effect for bunker shots

const PARTICLE_COUNT: int = 10
const PARTICLE_LIFETIME: float = 0.8
const PARTICLE_COLORS: Array = [
	Color(0.85, 0.78, 0.55),  # Light sand
	Color(0.9, 0.82, 0.58),   # Pale sand
	Color(0.78, 0.72, 0.5),   # Dark sand
]

var _particles_finished: int = 0

func _ready() -> void:
	z_index = 200  # Above everything
	_spawn_particles()

func _spawn_particles() -> void:
	for i in range(PARTICLE_COUNT):
		var particle = Polygon2D.new()
		particle.color = PARTICLE_COLORS[randi() % PARTICLE_COLORS.size()]

		# Small triangle particle
		var size = randf_range(2.0, 4.0)
		particle.polygon = PackedVector2Array([
			Vector2(-size, size * 0.5),
			Vector2(size, size * 0.5),
			Vector2(0, -size)
		])

		add_child(particle)

		# Randomized upward + outward trajectory
		var angle = randf_range(-PI * 0.8, -PI * 0.2)  # Upward arc
		var speed = randf_range(30.0, 80.0)
		var target_offset = Vector2(cos(angle), sin(angle)) * speed
		var lifetime = randf_range(PARTICLE_LIFETIME * 0.6, PARTICLE_LIFETIME)

		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", target_offset, lifetime).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(particle, "modulate:a", 0.0, lifetime).set_ease(Tween.EASE_IN)
		tween.set_parallel(false)
		tween.tween_callback(_on_particle_finished)

func _on_particle_finished() -> void:
	_particles_finished += 1
	if _particles_finished >= PARTICLE_COUNT:
		queue_free()

## Play the effect at a world position
static func create_at(parent: Node, world_position: Vector2) -> SandSprayEffect:
	var effect = SandSprayEffect.new()
	effect.global_position = world_position
	parent.add_child(effect)
	return effect
