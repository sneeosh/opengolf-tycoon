extends Node2D
class_name GolferExpression
## A visual-only pose layer; shot timers, ball positions, and movement stay untouched.
var golfer: Node2D
var _time := 0.0
var _reaction_remaining := 0.0
var _reaction := 0

func initialize(actor: Node2D, body: Node2D) -> void:
	golfer = actor
	body.reparent(self)

static func reaction_for_score(over_par: int) -> int:
	return 1 if over_par < 0 else (-1 if over_par > 0 else 0)

func react_to_score(over_par: int) -> void:
	_reaction = reaction_for_score(over_par)
	_reaction_remaining = 2.2

func _process(delta: float) -> void:
	if not is_instance_valid(golfer):
		return
	if GameManager.is_paused or GameManager.current_speed == GameManager.GameSpeed.PAUSED:
		return
	var real_delta := delta / maxf(Engine.time_scale, 0.01)
	_time += real_delta
	position = Vector2.ZERO
	rotation = 0
	scale = Vector2.ONE
	# A new shot always wins over a lingering celebration.
	if golfer.current_state in [Golfer.State.PREPARING_SHOT, Golfer.State.SWINGING]:
		_reaction_remaining = 0
	if _reaction_remaining > 0:
		_reaction_remaining = maxf(0, _reaction_remaining - real_delta)
		var progress := 2.2 - _reaction_remaining
		var fade := minf(1, _reaction_remaining * 2)
		if _reaction > 0:
			position.y = -absf(sin(progress * 5)) * 4 * fade
			rotation = sin(progress * 8) * 0.055 * fade
		elif _reaction < 0:
			rotation = sin(progress * PI / 2.2) * 0.10 * fade
			position.y = sin(progress * PI / 2.2) * 1.5 * fade
		else:
			rotation = sin(progress * PI * 2) * 0.025 * fade
	elif golfer.current_state == Golfer.State.PREPARING_SHOT:
		# A restrained address waggle, without adding another full swing.
		rotation = sin(_time * 7) * 0.025
		position.x = sin(_time * 3.5) * 0.7
	elif golfer.current_state == Golfer.State.IDLE:
		scale.y = 1.0 + sin(_time * 2) * 0.012
	elif golfer.current_state == Golfer.State.WATCHING:
		rotation = sin(_time * 1.4) * 0.015
	queue_redraw()

func _draw() -> void:
	if _reaction_remaining <= 0 or _reaction <= 0:
		return
	# Brief, tiny glints emphasize a happy finish even when zoomed out.
	var alpha := minf(1, _reaction_remaining)
	for i in range(3):
		var p := Vector2(-12 + i * 12, -32 - sin(_time * 4 + i) * 3)
		var color := Color(0.97, 0.86, 0.49, alpha * 0.8)
		draw_line(p + Vector2(-2, 0), p + Vector2(2, 0), color, 1)
		draw_line(p + Vector2(0, -2), p + Vector2(0, 2), color, 1)
