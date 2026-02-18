extends RefCounted
class_name ShotPathCalculator
## ShotPathCalculator - Calculates expected shot path for hole visualization
##
## Uses ShotAI to show where an average golfer would aim their drive and
## approach shots. This helps course designers understand how golfers will
## play each hole.
##
## Creates a lightweight GolferData with average CASUAL tier skills to run
## through ShotAI's decision pipeline without needing a real Golfer node.

## Average CASUAL golfer skills (midpoint of CASUAL tier [0.5, 0.7]):
const AVG_SKILL: float = 0.6
const AVG_AGGRESSION: float = 0.45
const AVG_PATIENCE: float = 0.55

## Calculate shot path waypoints from tee to flag.
## Returns array of grid positions: [tee, landing1, ..., flag]
## Par 3: [tee, flag] (direct shot)
## Par 4: [tee, drive_landing, flag]
## Par 5: [tee, drive_landing, second_landing, flag]
static func calculate_waypoints(hole_data: GameManager.HoleData, _terrain_grid: TerrainGrid) -> Array[Vector2i]:
	var waypoints: Array[Vector2i] = [hole_data.tee_position]

	# Shots to reach the green = par - 2 putts
	var shots_to_green: int = hole_data.par - 2
	var num_intermediate: int = shots_to_green - 1
	if num_intermediate <= 0:
		waypoints.append(hole_data.hole_position)
		return waypoints

	# Create lightweight golfer data for visualization (no scene tree needed)
	var gd: ShotAI.GolferData = _create_avg_golfer_data(hole_data.tee_position)

	for i in range(num_intermediate):
		# Use ShotAI to decide the shot from this position
		var decision: ShotAI.ShotDecision = ShotAI.decide_shot_for(gd, hole_data.hole_position)
		var landing: Vector2i = decision.target

		# Safety: don't add same position or positions that don't advance
		if landing == gd.ball_position:
			break

		# If landing reached the green area, stop adding intermediates
		var terrain_grid: TerrainGrid = GameManager.terrain_grid
		if terrain_grid:
			var landing_terrain: int = terrain_grid.get_tile(landing)
			if landing_terrain == TerrainTypes.Type.GREEN:
				break

		waypoints.append(landing)

		# Move phantom to the new position for next shot
		gd.ball_position = landing
		gd.ball_position_precise = Vector2(landing)

	waypoints.append(hole_data.hole_position)
	return waypoints

## Create a GolferData with average CASUAL tier skills for visualization.
static func _create_avg_golfer_data(tee_pos: Vector2i) -> ShotAI.GolferData:
	var gd: ShotAI.GolferData = ShotAI.GolferData.new()
	gd.ball_position = tee_pos
	gd.ball_position_precise = Vector2(tee_pos)
	gd.driving_skill = AVG_SKILL
	gd.accuracy_skill = AVG_SKILL
	gd.putting_skill = AVG_SKILL
	gd.recovery_skill = AVG_SKILL
	gd.miss_tendency = 0.0
	gd.aggression = AVG_AGGRESSION
	gd.patience = AVG_PATIENCE
	gd.current_hole = 0
	gd.total_strokes = 0
	gd.total_par = 0
	return gd
