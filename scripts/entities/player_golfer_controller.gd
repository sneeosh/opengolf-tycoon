extends Node
class_name PlayerGolferController
## PlayerGolferController - Handles player input for controlling a golfer
##
## Manages aim direction, club selection, power meter, and shot execution.
## Works with an existing Golfer instance by intercepting the PREPARING_SHOT state.

signal shot_aimed(target: Vector2i)
signal club_changed(club: int)
signal power_changed(power: float)
signal aim_updated(direction: Vector2, distance: float)
signal player_shot_taken()
signal player_round_finished(total_strokes: int)

## The golfer being controlled
var controlled_golfer: Golfer = null

## Aim state
var aim_direction: Vector2 = Vector2.RIGHT
var aim_distance: float = 10.0  # tiles
var selected_club: int = Golfer.Club.DRIVER
var shot_power: float = 1.0  # 0.0 to 1.0

## Power meter state
var _power_meter_active: bool = false
var _power_meter_direction: int = 1  # 1 = increasing, -1 = decreasing
var _power_meter_speed: float = 2.0  # cycles per second
var _is_aiming: bool = false

## Course data cache
var _current_hole_data = null
var _terrain_grid: TerrainGrid = null

func setup(golfer: Golfer, terrain_grid: TerrainGrid) -> void:
	controlled_golfer = golfer
	_terrain_grid = terrain_grid
	# Override AI behavior - player controls the shots
	golfer.set_meta("is_player_controlled", true)

func _process(delta: float) -> void:
	if not controlled_golfer:
		return
	if controlled_golfer.current_state != Golfer.State.PREPARING_SHOT:
		_is_aiming = false
		_power_meter_active = false
		return

	# Player is in shot preparation mode
	if not _is_aiming:
		_start_aiming()

	# Update power meter if active
	if _power_meter_active:
		_update_power_meter(delta)

func _start_aiming() -> void:
	_is_aiming = true
	_power_meter_active = false
	shot_power = 1.0

	# Get current hole target for initial aim direction
	var course_data = GameManager.course_data
	if course_data and controlled_golfer.current_hole < course_data.holes.size():
		_current_hole_data = course_data.holes[controlled_golfer.current_hole]
		var hole_pos = Vector2(_current_hole_data.hole_position)
		var ball_pos = controlled_golfer.ball_position_precise
		aim_direction = (hole_pos - ball_pos).normalized()
		aim_distance = ball_pos.distance_to(hole_pos)

	# Auto-select club based on distance
	_auto_select_club()
	aim_updated.emit(aim_direction, aim_distance)

func _unhandled_input(event: InputEvent) -> void:
	if not controlled_golfer or not _is_aiming:
		return

	# Club selection with number keys
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				_set_club(Golfer.Club.DRIVER)
			KEY_2:
				_set_club(Golfer.Club.FAIRWAY_WOOD)
			KEY_3:
				_set_club(Golfer.Club.IRON)
			KEY_4:
				_set_club(Golfer.Club.WEDGE)
			KEY_5:
				_set_club(Golfer.Club.PUTTER)
			KEY_SPACE:
				if not _power_meter_active:
					# Start power meter
					_power_meter_active = true
					shot_power = 0.0
					_power_meter_direction = 1
				else:
					# Lock power and take shot
					_power_meter_active = false
					_execute_player_shot()

	# Mouse-based aiming
	if event is InputEventMouseMotion and _is_aiming and not _power_meter_active:
		_update_aim_from_mouse()

	# Click to start power meter (alternative to spacebar)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _is_aiming and not _power_meter_active:
			_power_meter_active = true
			shot_power = 0.0
			_power_meter_direction = 1
		elif _power_meter_active:
			_power_meter_active = false
			_execute_player_shot()

func _update_aim_from_mouse() -> void:
	if not _terrain_grid or not controlled_golfer:
		return

	var camera = get_viewport().get_camera_2d()
	if not camera:
		return

	var mouse_pos = camera.get_global_mouse_position()
	var golfer_pos = controlled_golfer.global_position

	var direction = (mouse_pos - golfer_pos).normalized()
	if direction.length_squared() > 0.01:
		aim_direction = direction

	# Calculate distance in tiles
	var mouse_grid = _terrain_grid.screen_to_grid(mouse_pos)
	var ball_grid = controlled_golfer.ball_position
	aim_distance = Vector2(ball_grid).distance_to(Vector2(mouse_grid))

	aim_updated.emit(aim_direction, aim_distance)

func _update_power_meter(delta: float) -> void:
	shot_power += _power_meter_direction * _power_meter_speed * delta
	if shot_power >= 1.0:
		shot_power = 1.0
		_power_meter_direction = -1
	elif shot_power <= 0.0:
		shot_power = 0.0
		_power_meter_direction = 1
	power_changed.emit(shot_power)

func _set_club(club: int) -> void:
	selected_club = club
	club_changed.emit(club)
	# Update aim distance based on club range
	var stats = Golfer.CLUB_STATS[club]
	aim_distance = lerpf(stats["min_distance"], stats["max_distance"], 0.8)
	aim_updated.emit(aim_direction, aim_distance)

func _auto_select_club() -> void:
	if not controlled_golfer or not _terrain_grid:
		return
	var terrain = _terrain_grid.get_tile(controlled_golfer.ball_position)
	var club = controlled_golfer.select_club(aim_distance, terrain)
	selected_club = club
	club_changed.emit(club)

func _execute_player_shot() -> void:
	if not controlled_golfer:
		return

	_is_aiming = false

	# Calculate target position from aim direction and power-scaled distance
	var stats = Golfer.CLUB_STATS[selected_club]
	var max_dist = stats["max_distance"]
	var min_dist = stats["min_distance"]
	var shot_distance = lerpf(min_dist, max_dist, shot_power)

	var ball_pos = controlled_golfer.ball_position_precise
	var target_precise = ball_pos + aim_direction * shot_distance
	var target = Vector2i(target_precise.round())

	# Let the golfer execute the shot using existing mechanics
	controlled_golfer.take_shot(target)
	player_shot_taken.emit()

func get_club_name() -> String:
	return Golfer.CLUB_STATS[selected_club]["name"]

func get_club_max_distance_yards() -> int:
	return Golfer.CLUB_STATS[selected_club]["max_distance"] * 22

func get_shot_distance_yards() -> int:
	var stats = Golfer.CLUB_STATS[selected_club]
	var dist = lerpf(stats["min_distance"], stats["max_distance"], shot_power)
	return int(dist * 22)
