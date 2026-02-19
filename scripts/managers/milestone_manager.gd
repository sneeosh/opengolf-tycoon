extends Node
class_name MilestoneManager
## MilestoneManager - Tracks and checks milestone completion
##
## Listens to game events and checks milestones at end-of-day and on
## relevant signals. Awards money and reputation when milestones complete.

signal milestone_completed(milestone_id: String, title: String, description: String)

var milestones: Array = []  # Array of MilestoneSystem.Milestone
var _completed_ids: Dictionary = {}  # id -> true for quick lookup

func _ready() -> void:
	milestones = MilestoneSystem.get_all_milestones()
	_connect_signals()

func _connect_signals() -> void:
	EventBus.end_of_day.connect(_on_end_of_day)
	EventBus.hole_created.connect(_on_hole_created)
	EventBus.building_placed.connect(_on_building_placed)
	EventBus.golfer_finished_round.connect(_on_golfer_finished_round)
	EventBus.golfer_spawned.connect(_on_golfer_spawned)
	EventBus.record_broken.connect(_on_record_broken)
	EventBus.reputation_changed.connect(_on_reputation_changed)
	EventBus.course_rating_changed.connect(_on_course_rating_changed)
	EventBus.money_changed.connect(_on_money_changed)

func _exit_tree() -> void:
	if EventBus.end_of_day.is_connected(_on_end_of_day):
		EventBus.end_of_day.disconnect(_on_end_of_day)
	if EventBus.hole_created.is_connected(_on_hole_created):
		EventBus.hole_created.disconnect(_on_hole_created)
	if EventBus.building_placed.is_connected(_on_building_placed):
		EventBus.building_placed.disconnect(_on_building_placed)
	if EventBus.golfer_finished_round.is_connected(_on_golfer_finished_round):
		EventBus.golfer_finished_round.disconnect(_on_golfer_finished_round)
	if EventBus.golfer_spawned.is_connected(_on_golfer_spawned):
		EventBus.golfer_spawned.disconnect(_on_golfer_spawned)
	if EventBus.record_broken.is_connected(_on_record_broken):
		EventBus.record_broken.disconnect(_on_record_broken)
	if EventBus.reputation_changed.is_connected(_on_reputation_changed):
		EventBus.reputation_changed.disconnect(_on_reputation_changed)
	if EventBus.course_rating_changed.is_connected(_on_course_rating_changed):
		EventBus.course_rating_changed.disconnect(_on_course_rating_changed)
	if EventBus.money_changed.is_connected(_on_money_changed):
		EventBus.money_changed.disconnect(_on_money_changed)

func _complete_milestone(m: MilestoneSystem.Milestone) -> void:
	if m.is_completed:
		return
	m.is_completed = true
	m.completion_day = GameManager.current_day
	_completed_ids[m.id] = true

	# Award rewards
	if m.reward_money > 0:
		GameManager.modify_money(m.reward_money)
		EventBus.log_transaction("Milestone: %s" % m.title, m.reward_money)
	if m.reward_reputation > 0.0:
		GameManager.modify_reputation(m.reward_reputation)

	# Notify
	var reward_text = ""
	if m.reward_money > 0:
		reward_text += "+$%d" % m.reward_money
	if m.reward_reputation > 0.0:
		if reward_text != "":
			reward_text += ", "
		reward_text += "+%.0f rep" % m.reward_reputation

	var msg = "Milestone: %s" % m.title
	if reward_text != "":
		msg += " (%s)" % reward_text
	EventBus.notify(msg, "success")
	milestone_completed.emit(m.id, m.title, m.description)

func _is_done(id: String) -> bool:
	return _completed_ids.has(id)

func _check(id: String, condition: bool) -> void:
	if condition and not _is_done(id):
		for m in milestones:
			if m.id == id:
				_complete_milestone(m)
				return

## Get completion stats
func get_completion_count() -> int:
	var count = 0
	for m in milestones:
		if m.is_completed:
			count += 1
	return count

func get_total_count() -> int:
	return milestones.size()

## Serialize for save/load
func serialize() -> Dictionary:
	var completed: Array = []
	for m in milestones:
		if m.is_completed:
			completed.append({"id": m.id, "day": m.completion_day})
	return {"completed": completed}

func deserialize(data: Dictionary) -> void:
	var completed = data.get("completed", [])
	_completed_ids.clear()
	for entry in completed:
		var id = entry.get("id", "")
		var day = entry.get("day", 0)
		_completed_ids[id] = true
		for m in milestones:
			if m.id == id:
				m.is_completed = true
				m.completion_day = day
				break

# --- Signal handlers ---

func _on_end_of_day(_day: int) -> void:
	# Day survival milestones
	_check("survive_30_days", GameManager.current_day >= 30)
	_check("survive_100_days", GameManager.current_day >= 100)

	# Daily revenue milestone
	var daily_revenue = GameManager.daily_stats.get_total_revenue()
	_check("earn_10k", daily_revenue >= 10000)
	_check("earn_50k", daily_revenue >= 50000)

	# Profit milestone
	_check("first_profit", GameManager.daily_stats.get_profit() > 0)

	# Daily golfer count
	_check("serve_50", GameManager.daily_stats.golfers_served >= 50)

	# HIO count
	_check("five_hio", GameManager.course_records.get("total_hole_in_ones", 0) >= 5)

	# Eagle from daily stats
	_check("first_eagle", GameManager.daily_stats.eagles > 0)

	# Debt free with $100k
	_check("no_debt", GameManager.money >= 100000 and GameManager.loan_balance <= 0)

	# Par 3 course
	if GameManager.current_course:
		var all_par3 = true
		var holes = GameManager.current_course.holes
		if holes.size() >= 3:
			for hole in holes:
				if hole.par != 3:
					all_par3 = false
					break
			_check("par_3_course", all_par3)

func _on_hole_created(_hole_number: int, _par: int, _distance: int) -> void:
	if not GameManager.current_course:
		return
	var count = GameManager.current_course.holes.size()
	_check("first_hole", count >= 1)
	_check("three_holes", count >= 3)
	_check("nine_holes", count >= 9)
	_check("eighteen_holes", count >= 18)

func _on_building_placed(_type: String, _pos: Vector2i) -> void:
	if not GameManager.entity_layer:
		return
	var building_count = GameManager.entity_layer.get_building_count() if GameManager.entity_layer.has_method("get_building_count") else 1
	_check("first_building", building_count >= 1)
	_check("five_buildings", building_count >= 5)

func _on_golfer_finished_round(_golfer_id: int, _total_strokes: int) -> void:
	_check("first_golfer", true)

func _on_golfer_spawned(_golfer_id: int, _golfer_name: String) -> void:
	# Check for pro visit - GolferTier.get_name_prefix(PRO) returns "Pro"
	if _golfer_name.begins_with("Pro "):
		_check("pro_visit", true)

func _on_record_broken(record_type: String, _golfer_name: String, _value: int, _hole_number: int) -> void:
	if record_type == "hole_in_one":
		_check("first_hio", true)
		_check("five_hio", GameManager.course_records.get("total_hole_in_ones", 0) >= 5)

func _on_reputation_changed(_old_rep: float, new_rep: float) -> void:
	_check("rep_25", new_rep >= 25.0)
	_check("rep_50", new_rep >= 50.0)
	_check("rep_75", new_rep >= 75.0)
	_check("rep_100", new_rep >= 100.0)

func _on_course_rating_changed(rating: Dictionary) -> void:
	var stars = rating.get("stars", 0)
	_check("four_star", stars >= 4)
	_check("five_star", stars >= 5)

func _on_money_changed(_old: int, _new: int) -> void:
	_check("no_debt", GameManager.money >= 100000 and GameManager.loan_balance <= 0)

## Check if a pro golfer has been spawned (called from GolferManager)
func check_pro_visit(tier: int) -> void:
	if tier == GolferTier.Tier.PRO:
		_check("pro_visit", true)

## Check concurrent golfer count (called from GolferManager)
func check_full_house(current_count: int, max_count: int) -> void:
	if max_count > 0 and current_count >= max_count:
		_check("full_house", true)
