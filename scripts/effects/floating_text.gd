extends Node2D
class_name FloatingText
## FloatingText - Animated floating +$XX / -$XX text for transaction feedback
##
## Spawns at world position, floats upward, fades out. Color-coded:
## green for income, red for expenses, gold for milestones.

const FLOAT_DISTANCE := 40.0
const FLOAT_DURATION := 1.2
const FADE_START := 0.6  # Start fading at 60% through animation

var _label: Label = null
var _elapsed: float = 0.0
var _start_pos: Vector2 = Vector2.ZERO
var _color: Color = Color.WHITE

## Create a floating text effect at a world position.
## amount > 0 shows green "+$XX", amount < 0 shows red "-$XX"
static func create_at(parent: Node, world_position: Vector2, amount: int) -> FloatingText:
	var ft := FloatingText.new()
	ft._start_pos = world_position
	ft.global_position = world_position
	ft.z_index = 100

	# Configure text and color
	if amount >= 0:
		ft._color = UIConstants.COLOR_SUCCESS
		ft._setup_label("+$%d" % amount)
	else:
		ft._color = UIConstants.COLOR_DANGER
		ft._setup_label("-$%d" % abs(amount))

	parent.add_child(ft)
	return ft

## Create a custom-text floating label (for milestones, records, etc.)
static func create_custom(parent: Node, world_position: Vector2, text: String, color: Color) -> FloatingText:
	var ft := FloatingText.new()
	ft._start_pos = world_position
	ft.global_position = world_position
	ft.z_index = 100
	ft._color = color
	ft._setup_label(text)
	parent.add_child(ft)
	return ft

func _setup_label(text: String) -> void:
	_label = Label.new()
	_label.text = text
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", _color)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_label.add_theme_constant_override("outline_size", 3)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.position = Vector2(-40, -10)
	_label.custom_minimum_size = Vector2(80, 0)
	add_child(_label)

func _process(delta: float) -> void:
	_elapsed += delta
	var progress := _elapsed / FLOAT_DURATION

	if progress >= 1.0:
		queue_free()
		return

	# Float upward with ease-out
	var ease_progress := 1.0 - pow(1.0 - progress, 2.0)
	global_position = _start_pos + Vector2(0, -FLOAT_DISTANCE * ease_progress)

	# Scale: pop in then shrink slightly
	var scale_val: float
	if progress < 0.1:
		scale_val = progress / 0.1 * 1.2
	elif progress < 0.2:
		scale_val = 1.2 - (progress - 0.1) / 0.1 * 0.2
	else:
		scale_val = 1.0
	scale = Vector2(scale_val, scale_val)

	# Fade out
	if progress > FADE_START:
		var fade_progress := (progress - FADE_START) / (1.0 - FADE_START)
		modulate.a = 1.0 - fade_progress
