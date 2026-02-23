extends Node
class_name AdvisorSystem
## AdvisorSystem - Context-sensitive tips and recommendations
##
## Analyzes game state at end-of-day and on-demand to generate actionable tips.
## Tips are categorized by priority (critical/warning/suggestion) and cover
## pricing, course design, amenities, staffing, pace of play, and progression.
## Integrates with the end-of-day summary and has a dedicated advisor panel.

enum TipPriority { CRITICAL, WARNING, SUGGESTION, INFO }

class AdvisorTip:
	var id: String = ""
	var priority: int = TipPriority.SUGGESTION
	var title: String = ""
	var message: String = ""
	var category: String = ""  # "pricing", "design", "amenities", "staff", "pace", "progression", "finance"
	var day_generated: int = 0

	func get_priority_label() -> String:
		match priority:
			TipPriority.CRITICAL: return "URGENT"
			TipPriority.WARNING: return "WARNING"
			TipPriority.SUGGESTION: return "TIP"
			TipPriority.INFO: return "INFO"
		return "TIP"

## Currently active tips (refreshed each day)
var current_tips: Array = []  # Array of AdvisorTip

## Tips that have been dismissed (by ID) — don't re-show until conditions change
var _dismissed_tip_ids: Array = []

## Cooldown: don't show the same tip ID within N days
var _tip_cooldowns: Dictionary = {}  # tip_id -> day_last_shown
const TIP_COOLDOWN_DAYS: int = 5

signal tips_updated(tips: Array)

func _ready() -> void:
	EventBus.end_of_day.connect(_on_end_of_day)

func _exit_tree() -> void:
	if EventBus.end_of_day.is_connected(_on_end_of_day):
		EventBus.end_of_day.disconnect(_on_end_of_day)

func _on_end_of_day(_day_number: int) -> void:
	refresh_tips()

## Regenerate all tips based on current game state
func refresh_tips() -> void:
	current_tips.clear()
	_generate_pricing_tips()
	_generate_design_tips()
	_generate_amenity_tips()
	_generate_pace_tips()
	_generate_finance_tips()
	_generate_progression_tips()
	_generate_staffing_tips()
	_generate_event_tips()

	# Sort by priority (critical first)
	current_tips.sort_custom(func(a, b): return a.priority < b.priority)

	# Notify listeners
	tips_updated.emit(current_tips)

	# Show top critical/warning tip as a toast notification
	_show_top_tip_notification()

## Dismiss a tip so it doesn't show again for a while
func dismiss_tip(tip_id: String) -> void:
	_dismissed_tip_ids.append(tip_id)
	_tip_cooldowns[tip_id] = GameManager.current_day
	current_tips = current_tips.filter(func(t): return t.id != tip_id)

func _is_tip_on_cooldown(tip_id: String) -> bool:
	if tip_id in _dismissed_tip_ids:
		var last_shown = _tip_cooldowns.get(tip_id, 0)
		if GameManager.current_day - last_shown < TIP_COOLDOWN_DAYS:
			return true
		# Cooldown expired — remove from dismissed
		_dismissed_tip_ids.erase(tip_id)
	return false

func _add_tip(id: String, priority: int, title: String, message: String, category: String) -> void:
	if _is_tip_on_cooldown(id):
		return
	var tip = AdvisorTip.new()
	tip.id = id
	tip.priority = priority
	tip.title = title
	tip.message = message
	tip.category = category
	tip.day_generated = GameManager.current_day
	current_tips.append(tip)

func _show_top_tip_notification() -> void:
	# Only show the most important tip as a toast
	for tip in current_tips:
		if tip.priority <= TipPriority.WARNING:
			var type_str = "warning" if tip.priority == TipPriority.CRITICAL else "info"
			EventBus.notify("Advisor: %s" % tip.message, type_str)
			return  # Only show one

## --- Pricing Tips ---

func _generate_pricing_tips() -> void:
	var hole_count = GameManager.get_open_hole_count()
	if hole_count == 0:
		return

	var fee = GameManager.green_fee
	var rating = GameManager.course_rating.get("overall", 3.0)
	var reputation = GameManager.reputation

	# Check if green fee is too high relative to reputation
	var hole_factor = clampf(float(hole_count) / 18.0, 0.15, 1.0)
	var fair_price_per_hole = reputation * 2.0 * hole_factor / max(hole_count, 1)

	if fee > fair_price_per_hole * 1.8:
		_add_tip("pricing_too_high", TipPriority.WARNING,
			"Green Fees Too High",
			"Green fees ($%d/hole) seem high for your reputation (%.0f). Golfers may feel overcharged. Consider lowering to ~$%d." % [fee, reputation, int(fair_price_per_hole * 1.2)],
			"pricing")
	elif fee < fair_price_per_hole * 0.5 and reputation > 30:
		_add_tip("pricing_too_low", TipPriority.SUGGESTION,
			"Green Fees Could Be Higher",
			"Your course's reputation supports higher fees. You could charge $%d/hole without losing golfers." % int(fair_price_per_hole * 0.9),
			"pricing")

	# Value rating is low
	var value_rating = GameManager.course_rating.get("value", 3.0)
	if value_rating < 2.0:
		_add_tip("low_value_rating", TipPriority.WARNING,
			"Poor Value Rating",
			"Golfers think your course is overpriced for its quality. Lower fees or improve course condition to boost value rating.",
			"pricing")

## --- Course Design Tips ---

func _generate_design_tips() -> void:
	if not GameManager.current_course:
		return

	var holes = GameManager.current_course.holes
	var open_holes = GameManager.current_course.get_open_holes()

	# No holes built yet
	if holes.is_empty():
		_add_tip("no_holes", TipPriority.CRITICAL,
			"Build Your First Hole",
			"Your course has no holes! Press H to start the hole creation tool. Place a tee box, then a green.",
			"design")
		return

	# Too few holes
	if open_holes.size() < 9 and GameManager.current_day > 3:
		_add_tip("few_holes", TipPriority.SUGGESTION,
			"Expand Your Course",
			"You have %d holes. Most golfers expect at least 9. More holes = higher green fee cap and more revenue." % open_holes.size(),
			"design")

	# Check par variety
	var par_counts = {3: 0, 4: 0, 5: 0}
	for hole in open_holes:
		par_counts[hole.par] = par_counts.get(hole.par, 0) + 1

	if open_holes.size() >= 6:
		if par_counts.get(3, 0) == 0:
			_add_tip("no_par3", TipPriority.SUGGESTION,
				"Add a Par 3",
				"Your course has no par 3 holes. Short holes add variety and improve the design rating. Try building one under 250 yards.",
				"design")
		elif par_counts.get(5, 0) == 0 and open_holes.size() >= 9:
			_add_tip("no_par5", TipPriority.SUGGESTION,
				"Add a Par 5",
				"No par 5 holes on your course. Long holes create exciting eagle opportunities and improve course variety.",
				"design")

	# Low design rating
	var design_rating = GameManager.course_rating.get("design", 3.0)
	if design_rating < 2.0 and open_holes.size() >= 6:
		_add_tip("low_design", TipPriority.WARNING,
			"Course Design Needs Work",
			"Design rating is low. Try adding more par variety, elevation changes, and strategic hazard placement.",
			"design")

	# Check for holes with high difficulty but low variety
	for hole in open_holes:
		if hole.difficulty_rating > 8.0:
			_add_tip("very_hard_hole_%d" % hole.hole_number, TipPriority.SUGGESTION,
				"Hole %d May Be Too Difficult" % hole.hole_number,
				"Hole %d has a difficulty rating of %.1f/10. Casual golfers may get frustrated. Consider widening the fairway or reducing hazards." % [hole.hole_number, hole.difficulty_rating],
				"design")
			break  # Only one of these

## --- Amenity Tips ---

func _generate_amenity_tips() -> void:
	var hole_count = GameManager.get_open_hole_count()
	if hole_count < 3:
		return

	# Check for missing key buildings
	var has_restroom = _has_building("restroom")
	var has_snack_bar = _has_building("snack_bar")
	var has_clubhouse = _has_building("clubhouse")
	var has_pro_shop = _has_building("pro_shop")
	var has_driving_range = _has_building("driving_range")

	if not has_clubhouse and hole_count >= 3:
		_add_tip("no_clubhouse", TipPriority.WARNING,
			"Build a Clubhouse",
			"You don't have a clubhouse! It's the centerpiece of any golf course and unlocks pro shop + restaurant upgrades.",
			"amenities")

	if not has_restroom and hole_count >= 6:
		_add_tip("no_restroom", TipPriority.SUGGESTION,
			"Golfers Need Restrooms",
			"With %d holes and no restroom, golfers will be unhappy on longer rounds. Build one near the turn (between holes 9 and 10)." % hole_count,
			"amenities")

	if not has_snack_bar and hole_count >= 9:
		_add_tip("no_snack_bar", TipPriority.SUGGESTION,
			"Add a Snack Bar",
			"A snack bar placed on the course generates revenue per golfer and improves satisfaction. Great for the halfway point.",
			"amenities")

	if not has_pro_shop and GameManager.reputation > 40:
		_add_tip("no_pro_shop", TipPriority.SUGGESTION,
			"Open a Pro Shop",
			"A pro shop earns $15 per golfer who passes by. With your reputation at %.0f, it would pay for itself quickly." % GameManager.reputation,
			"amenities")

	if not has_driving_range and hole_count >= 9 and GameManager.reputation > 50:
		_add_tip("no_driving_range", TipPriority.INFO,
			"Consider a Driving Range",
			"A driving range adds prestige to your facility and generates additional revenue.",
			"amenities")

## --- Pace of Play Tips ---

func _generate_pace_tips() -> void:
	var pace_rating = GameManager.course_rating.get("pace", 3.0)
	if pace_rating < 2.0:
		# Check if the complaint feedback shows slow pace
		var pace_complaints = FeedbackManager.trigger_counts.get(FeedbackTriggers.TriggerType.SLOW_PACE, 0)
		if pace_complaints > 3:
			_add_tip("slow_pace", TipPriority.WARNING,
				"Pace of Play Is Slow",
				"%d golfers complained about slow play today. Consider building wider fairways, adding cart paths, or reducing the number of difficult holes." % pace_complaints,
				"pace")
		else:
			_add_tip("low_pace_rating", TipPriority.SUGGESTION,
				"Improve Pace of Play",
				"Pace rating is only %.1f stars. Fewer bottlenecks and easier holes help golfers move faster." % pace_rating,
				"pace")

## --- Financial Tips ---

func _generate_finance_tips() -> void:
	# Bankruptcy warning
	if GameManager.money < 5000 and GameManager.money > GameManager.bankruptcy_threshold:
		_add_tip("low_money", TipPriority.CRITICAL,
			"Low Funds Warning",
			"Your balance is only $%d. Bankruptcy occurs at $%d. Consider taking a loan or cutting costs." % [GameManager.money, GameManager.bankruptcy_threshold],
			"finance")

	# Losing money consistently
	if GameManager.daily_history.size() >= 3:
		var recent_profits: Array = []
		for i in range(max(0, GameManager.daily_history.size() - 3), GameManager.daily_history.size()):
			recent_profits.append(GameManager.daily_history[i].get("profit", 0))
		var all_negative = true
		for p in recent_profits:
			if p >= 0:
				all_negative = false
				break
		if all_negative:
			_add_tip("losing_money", TipPriority.WARNING,
				"Consistent Losses",
				"You've lost money 3 days in a row. Review your operating costs in the Financial panel (F) or raise green fees.",
				"finance")

	# Loan reminder
	if GameManager.loan_balance > 0:
		var interest = int(GameManager.loan_balance * GameManager.LOAN_INTEREST_RATE)
		_add_tip("loan_reminder", TipPriority.INFO,
			"Outstanding Loan",
			"You owe $%d with $%d interest accruing weekly. Repay when possible to reduce costs." % [GameManager.loan_balance, interest],
			"finance")

	# High operating costs relative to revenue
	if GameManager.yesterday_stats:
		var rev = GameManager.yesterday_stats.get_total_revenue()
		var cost = GameManager.yesterday_stats.operating_costs
		if rev > 0 and cost > rev * 1.5:
			_add_tip("high_costs", TipPriority.WARNING,
				"Operating Costs Too High",
				"Yesterday's costs ($%d) were much higher than revenue ($%d). Consider downgrading staff tier or closing unprofitable buildings." % [cost, rev],
				"finance")

## --- Progression Tips ---

func _generate_progression_tips() -> void:
	var rating = GameManager.course_rating.get("overall", 3.0)
	var holes = GameManager.get_open_hole_count()

	# Tournament suggestions
	if GameManager.tournament_manager:
		var tm = GameManager.tournament_manager
		if holes >= 9 and rating >= 2.5 and not tm.is_tournament_in_progress():
			if GameManager.current_day > 14 and GameManager.reputation > 30:
				_add_tip("try_tournament", TipPriority.INFO,
					"Ready for a Tournament?",
					"Your course may qualify for a tournament. Check the Tournament panel (U) to see available tiers.",
					"progression")

	# Reputation stalling
	if GameManager.reputation < 30 and GameManager.current_day > 10:
		_add_tip("low_reputation", TipPriority.SUGGESTION,
			"Build Your Reputation",
			"Reputation is only %.0f. Happy golfers boost it — focus on fair pricing, good course condition, and amenities." % GameManager.reputation,
			"progression")
	elif GameManager.reputation > 80:
		_add_tip("high_reputation", TipPriority.INFO,
			"Excellent Reputation!",
			"Your reputation is %.0f — among the best. Maintain quality to keep attracting pro golfers and tournament eligibility." % GameManager.reputation,
			"progression")

## --- Staffing Tips ---

func _generate_staffing_tips() -> void:
	var condition_rating = GameManager.course_rating.get("condition", 3.0)

	# Poor condition with part-time staff
	if condition_rating < 2.5 and GameManager.current_staff_tier == GameManager.StaffTier.PART_TIME:
		_add_tip("upgrade_staff", TipPriority.WARNING,
			"Staff Quality Too Low",
			"Course condition is suffering with part-time staff. Upgrade to full-time in the Staff panel (P) for better maintenance.",
			"staff")

	# Premium staff but low revenue
	if GameManager.current_staff_tier == GameManager.StaffTier.PREMIUM:
		if GameManager.yesterday_stats:
			var rev = GameManager.yesterday_stats.get_total_revenue()
			var holes = GameManager.get_open_hole_count()
			var staff_cost = holes * 20  # Premium is $20/hole
			if staff_cost > rev * 0.4:
				_add_tip("expensive_staff", TipPriority.SUGGESTION,
					"Staff Costs Are High",
					"Premium staff costs $%d/day — that's over 40%% of yesterday's revenue. Consider full-time staff to save money." % staff_cost,
					"staff")

## --- Event-related Tips ---

func _generate_event_tips() -> void:
	if not GameManager.random_event_system:
		return

	var active_events = GameManager.random_event_system.get_active_event_summaries()
	for event in active_events:
		if event.get("days_remaining", 0) > 0:
			var cat = event.get("category", -1)
			if cat == RandomEventSystem.EventCategory.WEATHER_DISASTER:
				_add_tip("event_weather_%s" % event.get("title", ""), TipPriority.INFO,
					"Active Event: %s" % event.get("title", "Event"),
					"%s (%d days remaining)" % [event.get("description", ""), event.get("days_remaining", 0)],
					"events")

## --- Helpers ---

func _has_building(building_type: String) -> bool:
	if not GameManager.entity_layer:
		return false
	var buildings = GameManager.entity_layer.get_all_buildings()
	for building in buildings:
		if building.building_type == building_type:
			return true
	return false

## Get tips filtered by category
func get_tips_by_category(category: String) -> Array:
	return current_tips.filter(func(t): return t.category == category)

## Get the number of active tips by priority
func get_tip_count_by_priority(priority: int) -> int:
	var count = 0
	for tip in current_tips:
		if tip.priority == priority:
			count += 1
	return count

## Serialization for save/load
func serialize() -> Dictionary:
	return {
		"dismissed_tip_ids": _dismissed_tip_ids.duplicate(),
		"tip_cooldowns": _tip_cooldowns.duplicate(),
	}

func deserialize(data: Dictionary) -> void:
	_dismissed_tip_ids = data.get("dismissed_tip_ids", [])
	_tip_cooldowns = {}
	var raw_cooldowns = data.get("tip_cooldowns", {})
	for key in raw_cooldowns:
		_tip_cooldowns[key] = int(raw_cooldowns[key])
