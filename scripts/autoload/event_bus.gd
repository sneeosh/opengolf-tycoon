extends Node
## EventBus - Global signal hub for decoupled communication

# Transaction history tracking (prevents memory leak from unbounded growth)
var transaction_history: Array = []
const MAX_TRANSACTION_HISTORY: int = 1000

# Game State Signals
signal game_mode_changed(old_mode: int, new_mode: int)
signal game_speed_changed(new_speed: int)
signal pause_toggled(is_paused: bool)
signal new_game_started()
signal theme_changed(theme_type: int)

# Time Signals
signal day_changed(new_day: int)
signal hour_changed(new_hour: float)

# Economic Signals
signal money_changed(old_amount: int, new_amount: int)
signal reputation_changed(old_rep: float, new_rep: float)
signal transaction_completed(description: String, amount: int)
signal green_fee_changed(old_fee: int, new_fee: int)
signal green_fee_paid(golfer_id: int, golfer_name: String, amount: int)
signal course_rating_changed(rating: Dictionary)

# Terrain/Building Signals
signal terrain_tile_changed(position: Vector2i, old_type: int, new_type: int)
signal building_placed(building_type: String, position: Vector2i)
signal building_removed(position: Vector2i)
signal building_upgraded(building, new_level: int)

# Course Design Signals
signal hole_created(hole_number: int, par: int, distance_yards: int)
signal hole_updated(hole_number: int)
signal hole_selected(hole_number: int)
signal hole_deleted(hole_number: int)
signal hole_toggled(hole_number: int, is_open: bool)
signal hole_difficulty_changed(hole_number: int, difficulty: float)

# Golfer Signals
signal golfer_spawned(golfer_id: int, golfer_name: String)
signal golfer_started_hole(golfer_id: int, hole_number: int)
signal golfer_finished_hole(golfer_id: int, hole_number: int, strokes: int, par: int)
signal golfer_finished_round(golfer_id: int, total_score: int, total_par: int)
signal golfer_mood_changed(golfer_id: int, new_mood: float)
signal golfer_left_course(golfer_id: int)
signal golfer_thought(golfer_id: int, trigger_type: int, sentiment: String)

# Shot Signals
signal shot_taken(golfer_id: int, hole_number: int, strokes: int)
signal ball_in_hole(golfer_id: int, hole_number: int)
signal hazard_penalty(golfer_id: int, hazard_type: String, reset_position: Vector2i)
signal ball_putt_landed_precise(golfer_id: int, from_screen: Vector2, to_screen: Vector2, distance_yards: int)
signal ball_shot_landed_precise(golfer_id: int, from_screen: Vector2, to_screen: Vector2, distance_yards: int, carry_screen: Vector2)

# UI Signals
signal ui_notification(message: String, type: String)
signal tooltip_requested(text: String, position: Vector2)
signal tooltip_hidden()

# Wind Signals
signal wind_changed(direction: float, speed: float)

# Weather Signals
signal weather_changed(weather_type: int, intensity: float)

# Day Cycle Signals
signal end_of_day(day_number: int)
signal course_closing()

# Season Signals
signal season_changed(old_season: int, new_season: int)

# Tournament Signals
signal tournament_scheduled(tier: int, start_day: int)
signal tournament_started(tier: int)
signal tournament_completed(tier: int, results: Dictionary)
signal tournament_round_completed(tier: int, round_number: int, standings: Array)
signal tournament_cut_applied(tier: int, advancing: Array, eliminated: Array)
signal tournament_moment(moment: Dictionary)
signal tournament_simulation_started(tier: int, round_number: int)
signal tournament_simulation_completed(tier: int, round_number: int)

# Save/Load Signals
signal save_requested()
signal save_completed(success: bool)
signal load_requested(save_name: String)
signal load_completed(success: bool)

# Records Signals
signal record_broken(record_type: String, golfer_name: String, value: int, hole_number: int)

func _ready() -> void:
	print("EventBus initialized")

func notify(message: String, type: String = "info") -> void:
	ui_notification.emit(message, type)

func log_transaction(description: String, amount: int) -> void:
	var sign_str = "+" if amount >= 0 else ""
	print("[Transaction] %s: %s$%d" % [description, sign_str, amount])

	# Store transaction with timestamp (prevents unbounded memory growth)
	transaction_history.append({
		"description": description,
		"amount": amount,
		"day": GameManager.current_day if GameManager else 1,
		"time": Time.get_ticks_msec()
	})

	# Purge oldest entries if over limit
	while transaction_history.size() > MAX_TRANSACTION_HISTORY:
		transaction_history.pop_front()

	transaction_completed.emit(description, amount)

func clear_transaction_history() -> void:
	transaction_history.clear()

func get_recent_transactions(count: int = 50) -> Array:
	var start_idx = max(0, transaction_history.size() - count)
	return transaction_history.slice(start_idx)
