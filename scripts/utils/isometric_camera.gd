extends Camera2D
class_name IsometricCamera
## IsometricCamera - Camera controller for isometric view

@export var pan_speed: float = 500.0
@export var zoom_speed: float = 0.1
@export var min_zoom: float = 0.5
@export var max_zoom: float = 2.0
@export var smoothing_speed: float = 10.0
@export var bounds_enabled: bool = true
@export var bounds_min: Vector2 = Vector2(-2000, -2000)
@export var bounds_max: Vector2 = Vector2(6000, 4000)

var _target_position: Vector2
var _target_zoom: float
var _is_dragging: bool = false
var _drag_start_mouse: Vector2
var _drag_start_camera: Vector2

func _ready() -> void:
	_target_position = global_position
	_target_zoom = zoom.x
	position_smoothing_enabled = true
	position_smoothing_speed = smoothing_speed

func _process(delta: float) -> void:
	_handle_keyboard_input(delta)
	_apply_movement(delta)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_camera(-zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_camera(zoom_speed)
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_is_dragging = event.pressed
			if event.pressed:
				_drag_start_mouse = event.position
				_drag_start_camera = global_position
	
	if event is InputEventMouseMotion and _is_dragging:
		var drag_offset = event.position - _drag_start_mouse
		_target_position = _drag_start_camera - drag_offset / zoom.x

func _handle_keyboard_input(delta: float) -> void:
	var direction := Vector2.ZERO
	if Input.is_action_pressed("camera_pan_up"): direction.y -= 1
	if Input.is_action_pressed("camera_pan_down"): direction.y += 1
	if Input.is_action_pressed("camera_pan_left"): direction.x -= 1
	if Input.is_action_pressed("camera_pan_right"): direction.x += 1
	
	if direction != Vector2.ZERO:
		direction = direction.normalized()
		var iso_direction = Vector2(direction.x - direction.y, (direction.x + direction.y) * 0.5).normalized()
		_target_position += iso_direction * pan_speed * delta / zoom.x

func _zoom_camera(zoom_delta: float) -> void:
	_target_zoom = clamp(_target_zoom + zoom_delta, min_zoom, max_zoom)

func _apply_movement(delta: float) -> void:
	if bounds_enabled:
		_target_position.x = clamp(_target_position.x, bounds_min.x, bounds_max.x)
		_target_position.y = clamp(_target_position.y, bounds_min.y, bounds_max.y)
	
	var new_zoom = lerp(zoom.x, _target_zoom, smoothing_speed * delta)
	zoom = Vector2(new_zoom, new_zoom)
	global_position = _target_position

func focus_on(world_position: Vector2, instant: bool = false) -> void:
	_target_position = world_position
	if instant: global_position = world_position

func get_mouse_world_position() -> Vector2:
	return get_global_mouse_position()
