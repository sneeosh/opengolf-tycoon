extends Node2D
class_name LandingImpactEffect
## LandingImpactEffect - Radial particle burst when a ball lands

const PARTICLE_COUNT: int = 8
const PARTICLE_LIFETIME: float = 0.4

## Terrain-based particle colors
const TERRAIN_PARTICLE_COLORS: Dictionary = {
	"grass": [Color(0.35, 0.55, 0.25), Color(0.4, 0.6, 0.3), Color(0.3, 0.5, 0.2)],
	"bunker": [Color(0.85, 0.78, 0.55), Color(0.9, 0.82, 0.58), Color(0.78, 0.72, 0.5)],
	"water": [Color(0.4, 0.6, 0.9), Color(0.5, 0.7, 1.0), Color(0.3, 0.5, 0.85)],
	"fairway": [Color(0.4, 0.7, 0.35), Color(0.45, 0.75, 0.4), Color(0.35, 0.65, 0.3)],
	"default": [Color(0.5, 0.5, 0.45), Color(0.55, 0.55, 0.5), Color(0.45, 0.45, 0.4)],
}

var _particles_finished: int = 0
var _terrain_type: String = "default"

func _ready() -> void:
	z_index = 150
	_spawn_particles()

func set_terrain_type(type: String) -> void:
	_terrain_type = type

func _spawn_particles() -> void:
	var colors = TERRAIN_PARTICLE_COLORS.get(_terrain_type, TERRAIN_PARTICLE_COLORS["default"])

	for i in range(PARTICLE_COUNT):
		var particle = Polygon2D.new()
		particle.color = colors[randi() % colors.size()]

		# Small diamond particle
		var size = randf_range(1.5, 3.0)
		particle.polygon = PackedVector2Array([
			Vector2(0, -size), Vector2(size * 0.6, 0),
			Vector2(0, size), Vector2(-size * 0.6, 0)
		])

		add_child(particle)

		# Radial burst — particles fly outward in all directions
		var angle = (i / float(PARTICLE_COUNT)) * TAU + randf_range(-0.3, 0.3)
		var speed = randf_range(15.0, 40.0)
		var target_offset = Vector2(cos(angle), sin(angle) * 0.5) * speed  # Flatten Y for isometric
		var lifetime = randf_range(PARTICLE_LIFETIME * 0.6, PARTICLE_LIFETIME)

		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", target_offset, lifetime).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(particle, "modulate:a", 0.0, lifetime).set_ease(Tween.EASE_IN)
		tween.set_parallel(false)
		tween.tween_callback(_on_particle_finished)

	# Expanding ring for visual impact
	var ring = Polygon2D.new()
	ring.color = Color(1, 1, 1, 0.3)
	var ring_points = PackedVector2Array()
	for i in range(12):
		var angle = (i / 12.0) * TAU
		ring_points.append(Vector2(cos(angle) * 3, sin(angle) * 1.5))
	ring.polygon = ring_points
	add_child(ring)

	var ring_tween = create_tween()
	ring_tween.set_parallel(true)
	ring_tween.tween_property(ring, "scale", Vector2(4, 4), 0.3).set_ease(Tween.EASE_OUT)
	ring_tween.tween_property(ring, "modulate:a", 0.0, 0.3).set_ease(Tween.EASE_IN)

func _on_particle_finished() -> void:
	_particles_finished += 1
	if _particles_finished >= PARTICLE_COUNT:
		queue_free()

## Create impact effect at a world position with terrain-aware coloring
static func create_at(parent: Node, world_position: Vector2, terrain_type: String = "default") -> LandingImpactEffect:
	var effect = LandingImpactEffect.new()
	effect._terrain_type = terrain_type
	effect.global_position = world_position
	parent.add_child(effect)
	return effect
