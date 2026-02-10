extends Node2D
class_name HoleInOneCelebration
## HoleInOneCelebration - Celebratory effect for hole-in-one achievements

const PARTICLE_COUNT: int = 30
const PARTICLE_LIFETIME: float = 2.0
const PARTICLE_COLORS: Array = [
	Color(1.0, 0.85, 0.0),    # Gold
	Color(1.0, 0.9, 0.4),     # Light gold
	Color(0.9, 0.7, 0.0),     # Dark gold
	Color(1.0, 1.0, 0.6),     # Pale gold
]

var _particles_finished: int = 0
var _label: Label = null

func _ready() -> void:
	z_index = 300  # Above everything
	_spawn_particles()
	_show_text()

func _spawn_particles() -> void:
	for i in range(PARTICLE_COUNT):
		var particle = Polygon2D.new()
		particle.color = PARTICLE_COLORS[randi() % PARTICLE_COLORS.size()]

		# Star-shaped particle
		var size = randf_range(3.0, 6.0)
		var points: PackedVector2Array = []
		for j in range(10):
			var angle = (j / 10.0) * TAU - PI / 2
			var r = size if j % 2 == 0 else size * 0.5
			points.append(Vector2(cos(angle) * r, sin(angle) * r))
		particle.polygon = points

		add_child(particle)

		# Explosive outward trajectory
		var angle = randf_range(0, TAU)
		var speed = randf_range(80.0, 180.0)
		var target_offset = Vector2(cos(angle), sin(angle)) * speed
		var lifetime = randf_range(PARTICLE_LIFETIME * 0.7, PARTICLE_LIFETIME)

		# Add some gravity effect
		var gravity_offset = Vector2(0, 50)

		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", target_offset + gravity_offset, lifetime).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(particle, "modulate:a", 0.0, lifetime).set_ease(Tween.EASE_IN)
		tween.tween_property(particle, "rotation", randf_range(-TAU, TAU), lifetime)
		tween.set_parallel(false)
		tween.tween_callback(_on_particle_finished)

func _show_text() -> void:
	_label = Label.new()
	_label.text = "HOLE IN ONE!"
	_label.add_theme_font_size_override("font_size", 28)
	_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.position = Vector2(-80, -70)
	add_child(_label)

	# Animate text
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(_label, "position:y", -130, PARTICLE_LIFETIME).set_ease(Tween.EASE_OUT)
	tween.tween_property(_label, "modulate:a", 0.0, PARTICLE_LIFETIME).set_ease(Tween.EASE_IN).set_delay(0.5)
	tween.tween_property(_label, "scale", Vector2(1.2, 1.2), 0.3).set_ease(Tween.EASE_OUT)

func _on_particle_finished() -> void:
	_particles_finished += 1
	if _particles_finished >= PARTICLE_COUNT:
		queue_free()

## Play the effect at a world position
static func create_at(parent: Node, world_position: Vector2) -> HoleInOneCelebration:
	var effect = HoleInOneCelebration.new()
	effect.global_position = world_position
	parent.add_child(effect)
	return effect
