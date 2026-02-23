extends Camera2D
class_name IsometricCamera
## IsometricCamera - Enhanced camera controller with smooth zoom and subtle follow

@export var pan_speed: float = 500.0
@export var zoom_speed: float = 0.1
@export var min_zoom: float = 0.5
@export var max_zoom: float = 2.0
@export var smoothing_speed: float = 10.0
@export var zoom_smoothing_speed: float = 8.0
@export var bounds_enabled: bool = true
@export var bounds_min: Vector2 = Vector2(-2000, -2000)
@export var bounds_max: Vector2 = Vector2(6000, 4000)

# Subtle follow settings (for cursor-aware movement)
# NOTE: Disabled by default as it can cause unwanted camera drift
@export var subtle_follow_enabled: bool = false
@export var subtle_follow_strength: float = 0.02
@export var subtle_follow_deadzone: float = 100.0

var _target_position: Vector2
var _target_zoom: float
var _is_dragging: bool = false
var _drag_start_mouse: Vector2
var _drag_start_camera: Vector2

# Zoom easing state
var _zoom_velocity: float = 0.0
var _zoom_tween: Tween = null

# Shake state
var _shake_offset: Vector2 = Vector2.ZERO
var _shake_tween: Tween = null

func _ready() -> void:
	_target_position = global_position
	_target_zoom = zoom.x
	position_smoothing_enabled = true
	position_smoothing_speed = smoothing_speed

func _process(delta: float) -> void:
	_handle_keyboard_input(delta)
	_handle_subtle_follow(delta)
	_apply_movement(delta)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		# Skip camera input when mouse is over a UI control.
		# On web exports, wheel events may not be consumed by the GUI system
		# even when hovering over panels/menus, causing unwanted zoom.
		if get_viewport().gui_get_hovered_control() != null:
			return
		var scroll_direction := 1.0 if GameManager.invert_zoom_scroll else -1.0
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_camera_smooth(scroll_direction * zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_camera_smooth(-scroll_direction * zoom_speed)
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_is_dragging = event.pressed
			if event.pressed:
				_drag_start_mouse = event.position
				_drag_start_camera = global_position

	if event is InputEventMouseMotion and _is_dragging:
		var drag_offset = event.position - _drag_start_mouse
		_target_position = _drag_start_camera - drag_offset / zoom.x

	# Mac trackpad pinch-to-zoom gesture
	if event is InputEventMagnifyGesture:
		var pinch_zoom_speed = 0.5
		var pinch_direction := -1.0 if GameManager.invert_zoom_scroll else 1.0
		_zoom_camera_smooth((1.0 - event.factor) * pinch_zoom_speed * pinch_direction)

	# Keyboard zoom hotkeys: ] to zoom in, [ to zoom out
	if event is InputEventKey and event.pressed:
		# Don't process any gameplay hotkeys while in main menu
		if GameManager.current_mode == GameManager.GameMode.MAIN_MENU:
			return
		# Don't process hotkeys if a text input has focus
		var focused = get_viewport().gui_get_focus_owner()
		if focused is LineEdit or focused is TextEdit:
			return
		if event.keycode == KEY_BRACKETRIGHT:
			_zoom_camera_smooth(-zoom_speed * 2)
		elif event.keycode == KEY_BRACKETLEFT:
			_zoom_camera_smooth(zoom_speed * 2)

func _handle_keyboard_input(delta: float) -> void:
	var direction := Vector2.ZERO
	if Input.is_action_pressed("camera_pan_up"): direction.y -= 1
	if Input.is_action_pressed("camera_pan_down"): direction.y += 1
	if Input.is_action_pressed("camera_pan_left"): direction.x -= 1
	if Input.is_action_pressed("camera_pan_right"): direction.x += 1

	if direction != Vector2.ZERO:
		direction = direction.normalized()
		# Move camera in screen space (visual direction) instead of isometric coordinates
		_target_position += direction * pan_speed * delta / zoom.x

func _handle_subtle_follow(delta: float) -> void:
	if not subtle_follow_enabled or _is_dragging:
		return

	var viewport_size = get_viewport_rect().size
	var viewport_center = viewport_size / 2.0
	var mouse_pos = get_viewport().get_mouse_position()

	# Calculate offset from center
	var offset_from_center = mouse_pos - viewport_center

	# Only apply if outside deadzone
	if offset_from_center.length() > subtle_follow_deadzone:
		var follow_direction = offset_from_center.normalized()
		var follow_strength = (offset_from_center.length() - subtle_follow_deadzone) / viewport_center.length()
		follow_strength = clamp(follow_strength, 0.0, 1.0)

		# Apply subtle movement toward mouse
		_target_position += follow_direction * subtle_follow_strength * follow_strength * pan_speed * delta / zoom.x

func _zoom_camera_smooth(zoom_delta: float) -> void:
	var new_target = clamp(_target_zoom + zoom_delta, min_zoom, max_zoom)

	# Kill existing zoom tween
	if _zoom_tween and _zoom_tween.is_valid():
		_zoom_tween.kill()

	# Create smooth zoom tween
	_zoom_tween = create_tween()
	_zoom_tween.set_ease(Tween.EASE_OUT)
	_zoom_tween.set_trans(Tween.TRANS_QUINT)
	_zoom_tween.tween_property(self, "_target_zoom", new_target, 0.25)

func _apply_movement(delta: float) -> void:
	if bounds_enabled:
		_target_position.x = clamp(_target_position.x, bounds_min.x, bounds_max.x)
		_target_position.y = clamp(_target_position.y, bounds_min.y, bounds_max.y)

	# Smooth zoom with easing
	var zoom_diff = _target_zoom - zoom.x
	var new_zoom = zoom.x + zoom_diff * zoom_smoothing_speed * delta
	zoom = Vector2(new_zoom, new_zoom)

	# Apply position with shake offset
	global_position = _target_position + _shake_offset

# =============================================================================
# PUBLIC API
# =============================================================================

func focus_on(world_position: Vector2, instant: bool = false) -> void:
	_target_position = world_position
	if instant:
		global_position = world_position

func focus_on_smooth(world_position: Vector2, duration: float = 0.5) -> void:
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "_target_position", world_position, duration)

func get_mouse_world_position() -> Vector2:
	return get_global_mouse_position()

func set_zoom_level(level: float, instant: bool = false) -> void:
	var clamped = clamp(level, min_zoom, max_zoom)
	if instant:
		_target_zoom = clamped
		zoom = Vector2(clamped, clamped)
	else:
		_zoom_camera_smooth(clamped - _target_zoom)

func get_zoom_level() -> float:
	return zoom.x

# =============================================================================
# CAMERA SHAKE
# =============================================================================

func shake(intensity: float = 5.0, duration: float = 0.2) -> void:
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()

	_shake_tween = create_tween()

	var shake_count = int(duration / 0.03)
	for i in range(shake_count):
		var shake_offset_target = Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		# Decay intensity over time
		var decay = 1.0 - (float(i) / shake_count)
		shake_offset_target *= decay

		_shake_tween.tween_property(self, "_shake_offset", shake_offset_target, 0.03)

	_shake_tween.tween_property(self, "_shake_offset", Vector2.ZERO, 0.05)

func micro_shake(intensity: float = 2.0) -> void:
	shake(intensity, 0.1)

# =============================================================================
# ZOOM TO POINT (Zoom centered on a world position)
# =============================================================================

func zoom_to_point(world_position: Vector2, new_zoom_level: float, duration: float = 0.3) -> void:
	var clamped_zoom = clamp(new_zoom_level, min_zoom, max_zoom)

	# Calculate position adjustment to keep world_position centered
	var viewport_size = get_viewport_rect().size
	var screen_center = viewport_size / 2.0

	# Focus on the point while zooming
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUINT)
	tween.set_parallel(true)

	tween.tween_property(self, "_target_position", world_position, duration)
	tween.tween_property(self, "_target_zoom", clamped_zoom, duration)
