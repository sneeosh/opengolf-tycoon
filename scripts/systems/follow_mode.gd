extends Node
class_name FollowMode
## FollowMode - Spectator camera system that follows a golfer around the course.
##
## Manages follow target selection, camera behavior per golfer state,
## and cycling between active golfers. Opt-in via click; opt-out via Escape.

var followed_golfer: Golfer = null
var is_active: bool = false

## Camera reference (set by main.gd during setup)
var camera: IsometricCamera = null

## GolferManager reference (set by main.gd during setup)
var golfer_manager: GolferManager = null

## Camera zoom presets per golfer state
const ZOOM_IDLE: float = 1.0
const ZOOM_WALKING: float = 0.9
const ZOOM_PREPARING: float = 1.2
const ZOOM_WATCHING_SHORT: float = 1.2  # < 3 tiles
const ZOOM_WATCHING_LONG: float = 0.8   # > 3 tiles
const ZOOM_BETWEEN_HOLES: float = 0.8

## Camera transition durations
const ZOOM_TRANSITION_DURATION: float = 0.5
const FOCUS_TRANSITION_DURATION: float = 0.4

## Tracking state
var _last_golfer_state: int = -1
var _ball_landing_hold_timer: float = 0.0
const BALL_LANDING_HOLD_DURATION: float = 1.0
var _holding_on_landing: bool = false

## Highlight ring for followed golfer
var _follow_highlight: Node2D = null

func setup(cam: IsometricCamera, gm: GolferManager) -> void:
	camera = cam
	golfer_manager = gm

func enter_follow_mode(golfer: Golfer) -> void:
	if not golfer or not is_instance_valid(golfer):
		return

	var old_id = followed_golfer.golfer_id if followed_golfer else -1
	var was_active = is_active

	followed_golfer = golfer
	is_active = true
	_last_golfer_state = -1
	_holding_on_landing = false

	_update_follow_highlight()

	if was_active and old_id != golfer.golfer_id:
		EventBus.follow_target_changed.emit(old_id, golfer.golfer_id)
	elif not was_active:
		EventBus.follow_mode_entered.emit(golfer.golfer_id)

	# Connect to golfer state changes
	if not golfer.state_changed.is_connected(_on_golfer_state_changed):
		golfer.state_changed.connect(_on_golfer_state_changed)

	# Immediately focus camera
	if camera:
		camera.focus_on_smooth(golfer.global_position, FOCUS_TRANSITION_DURATION)
		_apply_zoom_for_state(golfer.current_state)

func exit_follow_mode() -> void:
	if not is_active:
		return

	if followed_golfer and is_instance_valid(followed_golfer):
		if followed_golfer.state_changed.is_connected(_on_golfer_state_changed):
			followed_golfer.state_changed.disconnect(_on_golfer_state_changed)

	is_active = false
	followed_golfer = null
	_last_golfer_state = -1
	_holding_on_landing = false
	_clear_follow_highlight()

	EventBus.follow_mode_exited.emit()

func _process(delta: float) -> void:
	if not is_active or not followed_golfer:
		return

	if not is_instance_valid(followed_golfer):
		exit_follow_mode()
		return

	# Handle ball landing hold
	if _holding_on_landing:
		_ball_landing_hold_timer -= delta
		if _ball_landing_hold_timer <= 0:
			_holding_on_landing = false
		return  # Don't move camera while holding on landing

	# Smooth camera tracking based on golfer state
	if camera:
		var target_pos = followed_golfer.global_position
		camera.focus_on(target_pos)

func _on_golfer_state_changed(old_state: int, new_state: int) -> void:
	if not is_active or not camera:
		return

	_last_golfer_state = new_state
	_apply_zoom_for_state(new_state)

	match new_state:
		Golfer.State.SWINGING:
			# Micro shake on swing impact
			camera.micro_shake(2.0)
		Golfer.State.WATCHING:
			# Brief hold on golfer, then will track ball
			pass
		Golfer.State.IDLE:
			if old_state == Golfer.State.WATCHING:
				# Ball just landed — hold camera briefly
				_holding_on_landing = true
				_ball_landing_hold_timer = BALL_LANDING_HOLD_DURATION
		Golfer.State.FINISHED:
			# Golfer finished round — don't exit yet, let round summary handle it
			pass

func _apply_zoom_for_state(state: int) -> void:
	if not camera:
		return
	var target_zoom: float
	match state:
		Golfer.State.IDLE:
			target_zoom = ZOOM_IDLE
		Golfer.State.WALKING:
			target_zoom = ZOOM_WALKING
		Golfer.State.PREPARING_SHOT:
			target_zoom = ZOOM_PREPARING
		Golfer.State.SWINGING:
			target_zoom = ZOOM_PREPARING  # Keep zoom from preparation
		Golfer.State.WATCHING:
			target_zoom = ZOOM_WATCHING_LONG  # Default to pulled back
		Golfer.State.FINISHED:
			target_zoom = ZOOM_IDLE
		_:
			target_zoom = ZOOM_IDLE
	camera.zoom_to_point(camera.global_position, target_zoom, ZOOM_TRANSITION_DURATION)

## Cycle to the next active (non-finished) golfer on the course
func cycle_next_golfer() -> void:
	if not golfer_manager:
		return
	var golfers = golfer_manager.get_active_golfers()
	if golfers.is_empty():
		return

	# Filter to non-finished golfers
	var active: Array[Golfer] = []
	for g in golfers:
		if g.current_state != Golfer.State.FINISHED:
			active.append(g)
	if active.is_empty():
		return

	if not followed_golfer or not is_instance_valid(followed_golfer):
		enter_follow_mode(active[0])
		return

	# Find current index and advance
	var current_idx = -1
	for i in range(active.size()):
		if active[i].golfer_id == followed_golfer.golfer_id:
			current_idx = i
			break

	var next_idx = (current_idx + 1) % active.size()
	enter_follow_mode(active[next_idx])

## Cycle to the previous active golfer
func cycle_prev_golfer() -> void:
	if not golfer_manager:
		return
	var golfers = golfer_manager.get_active_golfers()
	if golfers.is_empty():
		return

	var active: Array[Golfer] = []
	for g in golfers:
		if g.current_state != Golfer.State.FINISHED:
			active.append(g)
	if active.is_empty():
		return

	if not followed_golfer or not is_instance_valid(followed_golfer):
		enter_follow_mode(active[active.size() - 1])
		return

	var current_idx = -1
	for i in range(active.size()):
		if active[i].golfer_id == followed_golfer.golfer_id:
			current_idx = i
			break

	var prev_idx = (current_idx - 1 + active.size()) % active.size()
	enter_follow_mode(active[prev_idx])

## Select golfer by index within their group (1-based, for number keys)
func select_group_member(index: int) -> void:
	if not is_active or not followed_golfer or not golfer_manager:
		return
	var group_id = followed_golfer.group_id
	var group_members: Array[Golfer] = []
	for g in golfer_manager.get_active_golfers():
		if g.group_id == group_id and g.current_state != Golfer.State.FINISHED:
			group_members.append(g)
	group_members.sort_custom(func(a, b): return a.golfer_id < b.golfer_id)
	if index >= 1 and index <= group_members.size():
		enter_follow_mode(group_members[index - 1])

## Get group members of the currently followed golfer
func get_followed_group() -> Array[Golfer]:
	if not is_active or not followed_golfer or not golfer_manager:
		return []
	var result: Array[Golfer] = []
	for g in golfer_manager.get_active_golfers():
		if g.group_id == followed_golfer.group_id:
			result.append(g)
	result.sort_custom(func(a, b): return a.golfer_id < b.golfer_id)
	return result

## Handle followed golfer leaving the course
func _on_golfer_left_course(golfer_id: int) -> void:
	if is_active and followed_golfer and followed_golfer.golfer_id == golfer_id:
		exit_follow_mode()

## Highlight ring management
func _update_follow_highlight() -> void:
	_clear_follow_highlight()
	if not followed_golfer or not is_instance_valid(followed_golfer):
		return

	_follow_highlight = Node2D.new()
	_follow_highlight.name = "FollowHighlight"
	followed_golfer.add_child(_follow_highlight)

	# Golden pulsing ring
	var ring = Polygon2D.new()
	ring.color = Color(1.0, 0.85, 0.0, 0.4)
	var points: PackedVector2Array = []
	var num_points = 24
	var radius = 18.0
	for i in range(num_points):
		var angle = TAU * i / num_points
		points.append(Vector2(cos(angle), sin(angle) * 0.6) * radius)
	ring.polygon = points
	ring.position = Vector2(0, 4)
	_follow_highlight.add_child(ring)

	# Pulse animation
	var tween = ring.create_tween()
	tween.set_loops()
	tween.tween_property(ring, "modulate:a", 0.6, 0.8).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(ring, "modulate:a", 1.0, 0.8).set_ease(Tween.EASE_IN_OUT)

func _clear_follow_highlight() -> void:
	if _follow_highlight and is_instance_valid(_follow_highlight):
		_follow_highlight.queue_free()
	_follow_highlight = null
