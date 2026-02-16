extends Node
class_name HoleManager
## HoleManager - Manages all hole visualizations on the course

## Cup radius and ball-holed check — delegates to GolfRules for single source of truth.
## Kept here as a convenience wrapper since many systems reference HoleManager.is_ball_holed.
const CUP_RADIUS: float = GolfRules.CUP_RADIUS

static func is_ball_holed(ball_pos: Vector2, hole_pos: Vector2) -> bool:
	return GolfRules.is_ball_holed(ball_pos, hole_pos)

var terrain_grid: TerrainGrid
var hole_visualizers: Dictionary = {}  # key: hole_number, value: HoleVisualizer

@onready var holes_container: Node2D = get_parent().get_node("Holes") if get_parent().has_node("Holes") else null

signal hole_visualization_created(hole_number: int)
signal hole_visualization_removed(hole_number: int)
signal hole_selected(hole_number: int)

func _ready() -> void:
	# Connect to EventBus for hole events
	EventBus.hole_created.connect(_on_hole_created)
	EventBus.hole_deleted.connect(_on_hole_deleted)
	EventBus.hole_updated.connect(_on_hole_updated)
	EventBus.hole_toggled.connect(_on_hole_toggled)

func _exit_tree() -> void:
	if EventBus.hole_created.is_connected(_on_hole_created):
		EventBus.hole_created.disconnect(_on_hole_created)
	if EventBus.hole_deleted.is_connected(_on_hole_deleted):
		EventBus.hole_deleted.disconnect(_on_hole_deleted)
	if EventBus.hole_updated.is_connected(_on_hole_updated):
		EventBus.hole_updated.disconnect(_on_hole_updated)
	if EventBus.hole_toggled.is_connected(_on_hole_toggled):
		EventBus.hole_toggled.disconnect(_on_hole_toggled)

func set_terrain_grid(grid: TerrainGrid) -> void:
	terrain_grid = grid

	# Initialize visualizations for existing holes
	_initialize_existing_holes()

func _initialize_existing_holes() -> void:
	if not GameManager.current_course:
		return

	for hole in GameManager.current_course.holes:
		_create_hole_visualization(hole)

func _create_hole_visualization(hole: GameManager.HoleData) -> void:
	if not holes_container:
		push_error("HoleManager: No holes container found")
		return

	if not terrain_grid:
		push_error("HoleManager: Terrain grid not set")
		return

	# Remove existing visualization if it exists
	if hole_visualizers.has(hole.hole_number):
		remove_hole_visualization(hole.hole_number)

	# Create new visualizer
	var visualizer = HoleVisualizer.new()
	visualizer.name = "Hole%d" % hole.hole_number
	holes_container.add_child(visualizer)

	visualizer.initialize(hole, terrain_grid)
	visualizer.hole_selected.connect(_on_hole_visualization_selected)

	hole_visualizers[hole.hole_number] = visualizer
	hole_visualization_created.emit(hole.hole_number)

func remove_hole_visualization(hole_number: int) -> void:
	if not hole_visualizers.has(hole_number):
		return

	var visualizer = hole_visualizers[hole_number]
	visualizer.destroy()
	hole_visualizers.erase(hole_number)
	hole_visualization_removed.emit(hole_number)

func get_hole_visualizer(hole_number: int) -> HoleVisualizer:
	return hole_visualizers.get(hole_number, null)

func get_all_hole_visualizers() -> Array:
	return hole_visualizers.values()

func highlight_hole(hole_number: int, enabled: bool) -> void:
	var visualizer = get_hole_visualizer(hole_number)
	if visualizer:
		visualizer.highlight(enabled)

func set_hole_visibility(hole_number: int, is_visible: bool) -> void:
	var visualizer = get_hole_visualizer(hole_number)
	if visualizer:
		visualizer.set_visible_state(is_visible)

func set_all_holes_visibility(is_visible: bool) -> void:
	for visualizer in hole_visualizers.values():
		visualizer.set_visible_state(is_visible)

func update_hole_visualization(hole_number: int) -> void:
	var visualizer = get_hole_visualizer(hole_number)
	if visualizer:
		visualizer.update_visualization()

func update_all_visualizations() -> void:
	for visualizer in hole_visualizers.values():
		visualizer.update_visualization()

## EventBus signal handlers
func _on_hole_created(hole_number: int, par: int, distance_yards: int) -> void:
	# Get the hole data from GameManager
	if not GameManager.current_course:
		return

	for hole in GameManager.current_course.holes:
		if hole.hole_number == hole_number:
			_create_hole_visualization(hole)
			break

func _on_hole_deleted(hole_number: int) -> void:
	remove_hole_visualization(hole_number)

func _on_hole_updated(hole_number: int) -> void:
	update_hole_visualization(hole_number)

func _on_hole_toggled(hole_number: int, is_open: bool) -> void:
	var visualizer = get_hole_visualizer(hole_number)
	if visualizer:
		visualizer.modulate = Color(1, 1, 1, 1) if is_open else Color(0.4, 0.4, 0.4, 0.5)

func _on_hole_visualization_selected(hole_number: int) -> void:
	hole_selected.emit(hole_number)
	EventBus.hole_selected.emit(hole_number)

## Get hole count
func get_hole_count() -> int:
	return hole_visualizers.size()

## Get total par for all holes
func get_total_par() -> int:
	if GameManager.current_course:
		return GameManager.current_course.total_par
	return 0
