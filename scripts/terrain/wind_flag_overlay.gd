extends Node2D
class_name WindFlagOverlay
## Manages animated wind flags on greens (replacing static Flag entities).
## Follows the overlay pattern: listens to hole signals, creates/removes WindFlag instances.

var _terrain_grid: TerrainGrid = null
var _flags: Array[WindFlag] = []

func initialize(grid: TerrainGrid) -> void:
	_terrain_grid = grid
	EventBus.hole_created.connect(_on_hole_created)
	EventBus.hole_deleted.connect(_on_hole_deleted)
	EventBus.load_completed.connect(_on_load_completed)
	# Build flags for any existing holes
	_rebuild_all_flags()

func _exit_tree() -> void:
	if EventBus.hole_created.is_connected(_on_hole_created):
		EventBus.hole_created.disconnect(_on_hole_created)
	if EventBus.hole_deleted.is_connected(_on_hole_deleted):
		EventBus.hole_deleted.disconnect(_on_hole_deleted)
	if EventBus.load_completed.is_connected(_on_load_completed):
		EventBus.load_completed.disconnect(_on_load_completed)

func _on_hole_created(_hole_number: int, _par: int, _distance_yards: int) -> void:
	_rebuild_all_flags()

func _on_hole_deleted(_hole_number: int) -> void:
	_rebuild_all_flags()

func _on_load_completed(_success: bool) -> void:
	# Rebuild flags after a save is loaded
	call_deferred("_rebuild_all_flags")

func _rebuild_all_flags() -> void:
	# Remove existing flags
	for flag in _flags:
		if is_instance_valid(flag):
			flag.queue_free()
	_flags.clear()

	if not _terrain_grid or not GameManager.course_data:
		return

	# Create animated wind flag on each green (replaces static Flag entity)
	for hole_data in GameManager.course_data.holes:
		var green_flag := WindFlag.new()
		green_flag.name = "GreenFlag_H%d" % hole_data.hole_number
		green_flag._flag_color = Color(0.9, 0.15, 0.15)  # Red for pin
		green_flag._pole_height = 28.0
		green_flag.position = _terrain_grid.grid_to_screen_center(hole_data.hole_position)
		add_child(green_flag)
		_flags.append(green_flag)
