extends Node
class_name HoleCreationTool
## HoleCreationTool - Handles creation of golf holes with tees and greens

enum PlacementMode {
	NONE,
	PLACING_TEE,
	PLACING_GREEN
}

var placement_mode: PlacementMode = PlacementMode.NONE
var current_hole_number: int = 1
var pending_tee_position: Vector2i = Vector2i(-1, -1)
var pending_green_position: Vector2i = Vector2i(-1, -1)

signal hole_created(hole_data: GameManager.HoleData)
signal placement_mode_changed(mode: PlacementMode)

## Start placing a tee for a new hole
func start_tee_placement() -> void:
	placement_mode = PlacementMode.PLACING_TEE
	pending_tee_position = Vector2i(-1, -1)
	pending_green_position = Vector2i(-1, -1)
	emit_signal("placement_mode_changed", placement_mode)
	print("Click to place tee box for hole ", current_hole_number)

## Start placing a green
func start_green_placement() -> void:
	if pending_tee_position == Vector2i(-1, -1):
		push_error("Must place tee before placing green")
		return

	placement_mode = PlacementMode.PLACING_GREEN
	emit_signal("placement_mode_changed", placement_mode)
	print("Click to place green for hole ", current_hole_number)

## Cancel current placement
func cancel_placement() -> void:
	placement_mode = PlacementMode.NONE
	emit_signal("placement_mode_changed", placement_mode)

## Handle click to place tee or green
func handle_click(grid_position: Vector2i) -> bool:
	if not GameManager.terrain_grid:
		return false

	match placement_mode:
		PlacementMode.PLACING_TEE:
			return _place_tee(grid_position)
		PlacementMode.PLACING_GREEN:
			return _place_green(grid_position)

	return false

## Place tee box at position
func _place_tee(position: Vector2i) -> bool:
	if not GameManager.terrain_grid.is_valid_position(position):
		return false

	# Paint tee box tiles in a 3x3 area
	var tee_tiles = GameManager.terrain_grid.get_brush_tiles(position, 1)

	# Check if we can afford it
	var cost = TerrainTypes.get_placement_cost(TerrainTypes.Type.TEE_BOX) * tee_tiles.size()
	if GameManager.money < cost:
		print("Not enough money to place tee box (need $", cost, ")")
		return false

	# Place the tee box
	for tile_pos in tee_tiles:
		GameManager.terrain_grid.set_tile(tile_pos, TerrainTypes.Type.TEE_BOX)

	GameManager.modify_money(-cost)
	pending_tee_position = position

	print("Tee box placed at ", position)

	# Automatically move to green placement
	start_green_placement()

	return true

## Place green at position
func _place_green(position: Vector2i) -> bool:
	if not GameManager.terrain_grid.is_valid_position(position):
		return false

	# Ensure green is reasonable distance from tee
	var distance = pending_tee_position.distance_to(position)
	if distance < 20:
		print("Green must be at least 20 tiles from tee (100 yards)")
		return false

	# Paint green tiles in a 5x5 area
	var green_tiles = GameManager.terrain_grid.get_brush_tiles(position, 2)

	# Check if we can afford it
	var cost = TerrainTypes.get_placement_cost(TerrainTypes.Type.GREEN) * green_tiles.size()
	if GameManager.money < cost:
		print("Not enough money to place green (need $", cost, ")")
		return false

	# Place the green
	for tile_pos in green_tiles:
		GameManager.terrain_grid.set_tile(tile_pos, TerrainTypes.Type.GREEN)

	GameManager.modify_money(-cost)
	pending_green_position = position

	print("Green placed at ", position)

	# Create the hole
	_create_hole()

	return true

## Create a hole from tee and green positions
func _create_hole() -> void:
	if pending_tee_position == Vector2i(-1, -1) or pending_green_position == Vector2i(-1, -1):
		return

	var hole = GameManager.HoleData.new()
	hole.hole_number = current_hole_number
	hole.tee_position = pending_tee_position
	hole.green_position = pending_green_position
	hole.hole_position = pending_green_position  # Cup is at center of green

	# Calculate distance in yards
	hole.distance_yards = GameManager.terrain_grid.calculate_distance_yards(
		pending_tee_position,
		pending_green_position
	)

	# Calculate par based on distance
	hole.par = calculate_par(hole.distance_yards)

	# Add hole to course
	if not GameManager.current_course:
		GameManager.current_course = GameManager.CourseData.new()

	GameManager.current_course.add_hole(hole)

	print("Hole ", current_hole_number, " created! Par ", hole.par, " (", hole.distance_yards, " yards)")

	EventBus.emit_signal("hole_created", hole.hole_number, hole.par, hole.distance_yards)
	emit_signal("hole_created", hole)

	# Reset for next hole
	current_hole_number += 1
	pending_tee_position = Vector2i(-1, -1)
	pending_green_position = Vector2i(-1, -1)
	placement_mode = PlacementMode.NONE
	emit_signal("placement_mode_changed", placement_mode)

## Calculate par based on hole distance
static func calculate_par(distance_yards: int) -> int:
	# Standard par calculation based on USGA guidelines
	# Par 3: < 250 yards
	# Par 4: 250-470 yards
	# Par 5: > 470 yards

	if distance_yards < 250:
		return 3
	elif distance_yards < 470:
		return 4
	else:
		return 5

## Get all holes in the current course
func get_holes() -> Array:
	if GameManager.current_course:
		return GameManager.current_course.holes
	return []

## Get total par for the course
func get_total_par() -> int:
	if GameManager.current_course:
		return GameManager.current_course.total_par
	return 0

## Delete a hole
func delete_hole(hole_number: int) -> bool:
	if not GameManager.current_course:
		return false

	for i in range(GameManager.current_course.holes.size()):
		var hole = GameManager.current_course.holes[i]
		if hole.hole_number == hole_number:
			GameManager.current_course.holes.remove_at(i)
			GameManager.current_course._recalculate_par()

			# Renumber subsequent holes
			for j in range(i, GameManager.current_course.holes.size()):
				GameManager.current_course.holes[j].hole_number = j + 1

			current_hole_number = GameManager.current_course.holes.size() + 1
			EventBus.emit_signal("hole_deleted", hole_number)
			return true

	return false
