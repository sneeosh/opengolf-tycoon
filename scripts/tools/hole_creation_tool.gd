extends Node
class_name HoleCreationTool
## HoleCreationTool - Handles creation of golf holes with tees and greens

enum PlacementMode {
	NONE,
	PLACING_TEE,
	PLACING_GREEN,
	PLACING_FORWARD_TEE,
	PLACING_BACK_TEE,
}

var placement_mode: PlacementMode = PlacementMode.NONE
var current_hole_number: int = 1
var pending_tee_position: Vector2i = Vector2i(-1, -1)
var pending_green_position: Vector2i = Vector2i(-1, -1)

# For adding tees to existing holes
var target_hole_index: int = -1

signal hole_created(hole_data: GameManager.HoleData)
signal tee_added(hole_number: int, tee_type: String)
signal placement_mode_changed(mode: PlacementMode)

## Start placing a tee for a new hole
func start_tee_placement() -> void:
	placement_mode = PlacementMode.PLACING_TEE
	pending_tee_position = Vector2i(-1, -1)
	pending_green_position = Vector2i(-1, -1)
	target_hole_index = -1
	placement_mode_changed.emit(placement_mode)
	print("Click to place tee box for hole ", current_hole_number)

## Start placing a green
func start_green_placement() -> void:
	if pending_tee_position == Vector2i(-1, -1):
		push_error("Must place tee before placing green")
		return

	placement_mode = PlacementMode.PLACING_GREEN
	placement_mode_changed.emit(placement_mode)
	print("Click to place green for hole ", current_hole_number)

## Start placing a forward tee for an existing hole
func start_forward_tee_placement(hole_index: int) -> void:
	if not GameManager.current_course or hole_index >= GameManager.current_course.holes.size():
		return
	target_hole_index = hole_index
	placement_mode = PlacementMode.PLACING_FORWARD_TEE
	placement_mode_changed.emit(placement_mode)
	var hole = GameManager.current_course.holes[hole_index]
	print("Click to place forward tee for hole %d (closer to green)" % hole.hole_number)

## Start placing a back tee for an existing hole
func start_back_tee_placement(hole_index: int) -> void:
	if not GameManager.current_course or hole_index >= GameManager.current_course.holes.size():
		return
	target_hole_index = hole_index
	placement_mode = PlacementMode.PLACING_BACK_TEE
	placement_mode_changed.emit(placement_mode)
	var hole = GameManager.current_course.holes[hole_index]
	print("Click to place back tee for hole %d (further from green)" % hole.hole_number)

## Cancel current placement
func cancel_placement() -> void:
	placement_mode = PlacementMode.NONE
	target_hole_index = -1
	placement_mode_changed.emit(placement_mode)

## Handle click to place tee or green
func handle_click(grid_position: Vector2i) -> bool:
	if not GameManager.terrain_grid:
		return false

	match placement_mode:
		PlacementMode.PLACING_TEE:
			return _place_tee(grid_position)
		PlacementMode.PLACING_GREEN:
			return _place_green(grid_position)
		PlacementMode.PLACING_FORWARD_TEE:
			return _place_forward_tee(grid_position)
		PlacementMode.PLACING_BACK_TEE:
			return _place_back_tee(grid_position)

	return false

## Place tee box at position
func _place_tee(position: Vector2i) -> bool:
	if not GameManager.terrain_grid.is_valid_position(position):
		return false

	# Check if we can afford it
	var cost = TerrainTypes.get_placement_cost(TerrainTypes.Type.TEE_BOX)
	if not GameManager.can_afford(cost):
		if GameManager.is_bankrupt():
			EventBus.notify("Spending blocked! Balance below -$1,000", "error")
		else:
			EventBus.notify("Not enough money to place tee box (need $%d)" % cost, "error")
		return false

	# Place a single tee box tile
	GameManager.terrain_grid.set_tile(position, TerrainTypes.Type.TEE_BOX)

	GameManager.modify_money(-cost)
	pending_tee_position = position

	# Automatically move to green placement
	start_green_placement()

	return true

## Place green at position
func _place_green(position: Vector2i) -> bool:
	if not GameManager.terrain_grid.is_valid_position(position):
		return false

	# Ensure green is reasonable distance from tee
	var distance = Vector2(pending_tee_position).distance_to(Vector2(position))
	if distance < 5:
		print("Green must be at least 5 tiles from tee (110 yards)")
		return false

	# Place a single green tile — player can expand with terrain brush
	var cost = TerrainTypes.get_placement_cost(TerrainTypes.Type.GREEN)
	if not GameManager.can_afford(cost):
		if GameManager.is_bankrupt():
			EventBus.notify("Spending blocked! Balance below -$1,000", "error")
		else:
			EventBus.notify("Not enough money to place green (need $%d)" % cost, "error")
		return false

	# Place the green
	GameManager.terrain_grid.set_tile(position, TerrainTypes.Type.GREEN)

	GameManager.modify_money(-cost)
	pending_green_position = position

	print("Green placed at ", position)

	# Create the hole
	_create_hole()

	return true

## Place a forward tee for an existing hole
func _place_forward_tee(position: Vector2i) -> bool:
	if target_hole_index < 0:
		return false
	var hole = GameManager.current_course.holes[target_hole_index]
	return _place_extra_tee(position, hole, "forward")

## Place a back tee for an existing hole
func _place_back_tee(position: Vector2i) -> bool:
	if target_hole_index < 0:
		return false
	var hole = GameManager.current_course.holes[target_hole_index]
	return _place_extra_tee(position, hole, "back")

## Shared logic for placing forward/back tees
func _place_extra_tee(position: Vector2i, hole: GameManager.HoleData, tee_type: String) -> bool:
	if not GameManager.terrain_grid.is_valid_position(position):
		return false

	var green_pos = Vector2(hole.green_position)
	var middle_tee_pos = Vector2(hole.tee_position)
	var new_tee_pos = Vector2(position)

	var dist_new_to_green = new_tee_pos.distance_to(green_pos)
	var dist_middle_to_green = middle_tee_pos.distance_to(green_pos)

	# Validate placement relative to middle tee
	if tee_type == "forward":
		# Forward tee must be closer to green than middle tee
		if dist_new_to_green >= dist_middle_to_green:
			EventBus.notify("Forward tee must be closer to the green than the middle tee", "error")
			return false
		# Must be at least 3 tiles from green (not on the green itself)
		if dist_new_to_green < 3:
			EventBus.notify("Forward tee too close to the green", "error")
			return false
	else:
		# Back tee must be further from green than middle tee
		if dist_new_to_green <= dist_middle_to_green:
			EventBus.notify("Back tee must be further from the green than the middle tee", "error")
			return false

	# Check cost
	var cost = TerrainTypes.get_placement_cost(TerrainTypes.Type.TEE_BOX)
	if not GameManager.can_afford(cost):
		if GameManager.is_bankrupt():
			EventBus.notify("Spending blocked! Balance below -$1,000", "error")
		else:
			EventBus.notify("Not enough money to place tee box (need $%d)" % cost, "error")
		return false

	# Place the tee box tile
	GameManager.terrain_grid.set_tile(position, TerrainTypes.Type.TEE_BOX)
	GameManager.modify_money(-cost)

	# Assign to the hole
	if tee_type == "forward":
		hole.forward_tee = position
	else:
		hole.back_tee = position

	var distance_yards = GameManager.terrain_grid.calculate_distance_yards(position, hole.green_position)
	print("%s tee placed for hole %d at %s (%d yards)" % [tee_type.capitalize(), hole.hole_number, str(position), distance_yards])
	EventBus.notify("%s tee added to Hole %d (%d yds)" % [tee_type.capitalize(), hole.hole_number, distance_yards], "success")

	tee_added.emit(hole.hole_number, tee_type)
	EventBus.hole_updated.emit(hole.hole_number)

	# Reset placement mode
	placement_mode = PlacementMode.NONE
	target_hole_index = -1
	placement_mode_changed.emit(placement_mode)

	return true

## Remove a forward or back tee from a hole
func remove_extra_tee(hole_number: int, tee_type: String) -> bool:
	if not GameManager.current_course:
		return false
	for hole in GameManager.current_course.holes:
		if hole.hole_number == hole_number:
			if tee_type == "forward" and hole.has_forward_tee():
				hole.forward_tee = Vector2i(-1, -1)
				EventBus.notify("Forward tee removed from Hole %d" % hole_number, "info")
				EventBus.hole_updated.emit(hole_number)
				return true
			elif tee_type == "back" and hole.has_back_tee():
				hole.back_tee = Vector2i(-1, -1)
				EventBus.notify("Back tee removed from Hole %d" % hole_number, "info")
				EventBus.hole_updated.emit(hole_number)
				return true
	return false

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

	# Calculate difficulty rating based on surrounding terrain
	hole.difficulty_rating = DifficultyCalculator.calculate_hole_difficulty(hole, GameManager.terrain_grid)

	# Add hole to course
	if not GameManager.current_course:
		GameManager.current_course = GameManager.CourseData.new()

	GameManager.current_course.add_hole(hole)

	print("Hole ", current_hole_number, " created! Par ", hole.par, " (", hole.distance_yards, " yards)")

	EventBus.hole_created.emit(hole.hole_number, hole.par, hole.distance_yards)
	hole_created.emit(hole)

	# Reset for next hole
	current_hole_number += 1
	pending_tee_position = Vector2i(-1, -1)
	pending_green_position = Vector2i(-1, -1)
	placement_mode = PlacementMode.NONE
	placement_mode_changed.emit(placement_mode)

## Calculate par based on hole distance — delegates to GolfRules
static func calculate_par(distance_yards: int) -> int:
	return GolfRules.calculate_par(distance_yards)

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
			EventBus.hole_deleted.emit(hole_number)
			return true

	return false
