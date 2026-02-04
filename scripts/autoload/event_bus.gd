extends Node
## EventBus - Global signal hub for decoupled communication

# Game State Signals
signal game_mode_changed(old_mode: int, new_mode: int)
signal game_speed_changed(new_speed: int)
signal pause_toggled(is_paused: bool)
signal new_game_started()

# Time Signals
signal day_changed(new_day: int)
signal hour_changed(new_hour: float)

# Economic Signals
signal money_changed(old_amount: int, new_amount: int)
signal reputation_changed(old_rep: float, new_rep: float)
signal transaction_completed(description: String, amount: int)
signal green_fee_changed(old_fee: int, new_fee: int)
signal green_fee_paid(golfer_id: int, golfer_name: String, amount: int)

# Terrain/Building Signals
signal terrain_tile_changed(position: Vector2i, old_type: int, new_type: int)
signal building_placed(building_type: String, position: Vector2i)
signal building_removed(position: Vector2i)
signal terrain_tool_selected(tool_type: String)

# Course Design Signals
signal hole_created(hole_number: int, par: int, distance_yards: int)
signal hole_modified(hole_number: int)
signal hole_updated(hole_number: int)
signal hole_selected(hole_number: int)
signal hole_deleted(hole_number: int)
signal hole_toggled(hole_number: int, is_open: bool)
signal tee_placed(hole_number: int, position: Vector2i)
signal green_placed(hole_number: int, position: Vector2i)
signal par_calculated(hole_number: int, par: int)
signal hole_difficulty_changed(hole_number: int, difficulty: float)

# Golfer Signals
signal golfer_spawned(golfer_id: int, golfer_name: String)
signal golfer_started_hole(golfer_id: int, hole_number: int)
signal golfer_finished_hole(golfer_id: int, hole_number: int, strokes: int, par: int)
signal golfer_finished_round(golfer_id: int, total_score: int)
signal golfer_mood_changed(golfer_id: int, new_mood: float)
signal golfer_left_course(golfer_id: int)

# Shot Signals
signal shot_taken(golfer_id: int, hole_number: int, strokes: int)
signal ball_landed(golfer_id: int, from_position: Vector2i, position: Vector2i, terrain_type: int)
signal ball_in_hole(golfer_id: int, hole_number: int)
signal hazard_penalty(golfer_id: int, hazard_type: String, reset_position: Vector2i)
signal ball_putt_landed_precise(golfer_id: int, from_screen: Vector2, to_screen: Vector2, distance_yards: int)

# UI Signals
signal ui_notification(message: String, type: String)
signal tooltip_requested(text: String, position: Vector2)
signal tooltip_hidden()

# Wind Signals
signal wind_changed(direction: float, speed: float)

# Camera Signals
signal camera_moved(new_position: Vector2)
signal camera_zoomed(new_zoom: float)

# Selection Signals
signal tile_selected(position: Vector2i)
signal tile_hovered(position: Vector2i)
signal selection_cleared()

# Day Cycle Signals
signal end_of_day(day_number: int)
signal course_closing()

# Save/Load Signals
signal save_requested()
signal save_completed(success: bool)
signal load_requested(save_name: String)
signal load_completed(success: bool)

func _ready() -> void:
	print("EventBus initialized")

func notify(message: String, type: String = "info") -> void:
	emit_signal("ui_notification", message, type)

func log_transaction(description: String, amount: int) -> void:
	var sign_str = "+" if amount >= 0 else ""
	print("[Transaction] %s: %s$%d" % [description, sign_str, amount])
	emit_signal("transaction_completed", description, amount)
