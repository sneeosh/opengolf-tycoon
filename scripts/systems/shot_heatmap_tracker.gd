extends Node
class_name ShotHeatmapTracker
## ShotHeatmapTracker - Collects shot landing data for heatmap visualization

# Shot landing density: grid_pos (Vector2i) -> count (int)
var landing_counts: Dictionary = {}

# Trouble zone data: grid_pos (Vector2i) -> { "total_score_diff": int, "shot_count": int }
var trouble_data: Dictionary = {}

# Buffer: golfer_id -> Array[Vector2i] of shot landing positions during current hole
var _active_hole_shots: Dictionary = {}

func initialize() -> void:
	EventBus.golfer_started_hole.connect(_on_golfer_started_hole)
	EventBus.ball_shot_landed_precise.connect(_on_shot_landed)
	EventBus.ball_putt_landed_precise.connect(_on_putt_landed)
	EventBus.golfer_finished_hole.connect(_on_golfer_finished_hole)
	EventBus.golfer_left_course.connect(_on_golfer_left)

func _exit_tree() -> void:
	if EventBus.golfer_started_hole.is_connected(_on_golfer_started_hole):
		EventBus.golfer_started_hole.disconnect(_on_golfer_started_hole)
	if EventBus.ball_shot_landed_precise.is_connected(_on_shot_landed):
		EventBus.ball_shot_landed_precise.disconnect(_on_shot_landed)
	if EventBus.ball_putt_landed_precise.is_connected(_on_putt_landed):
		EventBus.ball_putt_landed_precise.disconnect(_on_putt_landed)
	if EventBus.golfer_finished_hole.is_connected(_on_golfer_finished_hole):
		EventBus.golfer_finished_hole.disconnect(_on_golfer_finished_hole)
	if EventBus.golfer_left_course.is_connected(_on_golfer_left):
		EventBus.golfer_left_course.disconnect(_on_golfer_left)

func _record_landing(golfer_id: int, to_screen: Vector2) -> void:
	if not GameManager.terrain_grid:
		return
	var grid_pos: Vector2i = GameManager.terrain_grid.screen_to_grid(to_screen)
	landing_counts[grid_pos] = landing_counts.get(grid_pos, 0) + 1
	if _active_hole_shots.has(golfer_id):
		_active_hole_shots[golfer_id].append(grid_pos)

func _on_golfer_started_hole(golfer_id: int, _hole_number: int) -> void:
	_active_hole_shots[golfer_id] = []

func _on_shot_landed(golfer_id: int, _from_screen: Vector2, to_screen: Vector2,
		_distance_yards: int, _carry_screen: Vector2) -> void:
	_record_landing(golfer_id, to_screen)

func _on_putt_landed(golfer_id: int, _from_screen: Vector2, to_screen: Vector2,
		_distance_yards: int) -> void:
	_record_landing(golfer_id, to_screen)

func _on_golfer_finished_hole(_golfer_id: int, _hole_number: int, strokes: int, par: int) -> void:
	var score_diff: int = strokes - par
	if _active_hole_shots.has(_golfer_id):
		for grid_pos in _active_hole_shots[_golfer_id]:
			if not trouble_data.has(grid_pos):
				trouble_data[grid_pos] = { "total_score_diff": 0, "shot_count": 0 }
			trouble_data[grid_pos]["total_score_diff"] += score_diff
			trouble_data[grid_pos]["shot_count"] += 1
		_active_hole_shots.erase(_golfer_id)

func _on_golfer_left(golfer_id: int) -> void:
	_active_hole_shots.erase(golfer_id)

func clear() -> void:
	landing_counts.clear()
	trouble_data.clear()
	_active_hole_shots.clear()

## Returns the maximum landing count across all tiles
func get_max_landing_count() -> int:
	var max_count: int = 0
	for pos in landing_counts:
		max_count = maxi(max_count, landing_counts[pos])
	return max_count

## Returns average strokes over/under par for shots landing at this tile
func get_trouble_score(grid_pos: Vector2i) -> float:
	if not trouble_data.has(grid_pos):
		return 0.0
	var td = trouble_data[grid_pos]
	if td["shot_count"] == 0:
		return 0.0
	return float(td["total_score_diff"]) / float(td["shot_count"])

## Serialize for save
func serialize() -> Dictionary:
	var landings: Dictionary = {}
	for pos in landing_counts:
		landings["%d,%d" % [pos.x, pos.y]] = landing_counts[pos]

	var trouble: Dictionary = {}
	for pos in trouble_data:
		trouble["%d,%d" % [pos.x, pos.y]] = trouble_data[pos]

	return { "landing_counts": landings, "trouble_data": trouble }

## Deserialize from save
func deserialize(data: Dictionary) -> void:
	clear()
	if data.has("landing_counts"):
		for key in data["landing_counts"]:
			var parts = key.split(",")
			if parts.size() == 2:
				var pos = Vector2i(int(parts[0]), int(parts[1]))
				landing_counts[pos] = int(data["landing_counts"][key])
	if data.has("trouble_data"):
		for key in data["trouble_data"]:
			var parts = key.split(",")
			if parts.size() == 2:
				var pos = Vector2i(int(parts[0]), int(parts[1]))
				trouble_data[pos] = data["trouble_data"][key]
