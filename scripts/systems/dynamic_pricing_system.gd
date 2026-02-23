extends Node
class_name DynamicPricingSystem
## DynamicPricingSystem - Suggests optimal green fees based on demand analysis
##
## Analyzes course reputation, rating, golfer demand, and historical revenue
## to recommend green fee pricing. Can optionally auto-adjust fees daily.

## Whether auto-pricing is enabled (player opts in)
var auto_pricing_enabled: bool = false

## Pricing strategy when auto-pricing is active
enum PricingStrategy { MAXIMIZE_REVENUE, MAXIMIZE_GOLFERS, BALANCED }
var current_strategy: PricingStrategy = PricingStrategy.BALANCED

## Historical tracking for demand analysis
var daily_revenue_history: Array = []  # Last 28 days of revenue
var daily_golfer_history: Array = []  # Last 28 days of golfer counts
var daily_fee_history: Array = []  # Last 28 days of green fees
const HISTORY_WINDOW: int = 28

## Last calculated suggestion
var suggested_fee: int = 30
var suggestion_reason: String = ""
var revenue_estimate: int = 0
var golfer_estimate: int = 0

signal pricing_updated(suggested_fee: int, reason: String)

func _ready() -> void:
	EventBus.end_of_day.connect(_on_end_of_day)

func _exit_tree() -> void:
	if EventBus.end_of_day.is_connected(_on_end_of_day):
		EventBus.end_of_day.disconnect(_on_end_of_day)

func _on_end_of_day(_day_number: int) -> void:
	_record_daily_data()
	_calculate_suggested_fee()

	if auto_pricing_enabled:
		_apply_auto_pricing()

func _record_daily_data() -> void:
	var revenue = GameManager.daily_stats.get_total_revenue()
	var golfers = GameManager.daily_stats.golfers_served
	var fee = GameManager.green_fee

	daily_revenue_history.append(revenue)
	daily_golfer_history.append(golfers)
	daily_fee_history.append(fee)

	# Trim to history window
	while daily_revenue_history.size() > HISTORY_WINDOW:
		daily_revenue_history.pop_front()
	while daily_golfer_history.size() > HISTORY_WINDOW:
		daily_golfer_history.pop_front()
	while daily_fee_history.size() > HISTORY_WINDOW:
		daily_fee_history.pop_front()

func _calculate_suggested_fee() -> void:
	var holes = GameManager.get_open_hole_count()
	if holes <= 0:
		suggested_fee = GameManager.MIN_GREEN_FEE
		suggestion_reason = "No holes open"
		return

	var reputation = GameManager.reputation
	var rating = GameManager.course_rating.get("overall", 2.0)
	var current_fee = GameManager.green_fee
	var max_fee = GameManager.get_effective_max_green_fee()

	# Calculate fair price based on reputation (matches FeedbackTriggers formula)
	var hole_factor = clampf(float(holes) / 18.0, 0.15, 1.0)
	var fair_price_total = reputation * 2.0 * hole_factor
	var fair_per_hole = int(fair_price_total / max(holes, 1))

	# Base suggestion starts from fair price
	var base_suggestion = fair_per_hole

	# Adjust based on demand signals
	var demand_adjustment = _analyze_demand()

	# Adjust based on strategy
	match current_strategy:
		PricingStrategy.MAXIMIZE_REVENUE:
			# Push toward the overpriced threshold — squeeze maximum revenue
			base_suggestion = int(fair_per_hole * 1.3)
			suggestion_reason = "Maximizing revenue (risk of fewer golfers)"
		PricingStrategy.MAXIMIZE_GOLFERS:
			# Stay well under fair price — attract maximum visitors
			base_suggestion = int(fair_per_hole * 0.7)
			suggestion_reason = "Attracting maximum golfers (lower revenue per visit)"
		PricingStrategy.BALANCED:
			# Near fair price with demand adjustment
			base_suggestion = int(fair_per_hole * (1.0 + demand_adjustment * 0.15))
			if demand_adjustment > 0.1:
				suggestion_reason = "High demand — room to increase price"
			elif demand_adjustment < -0.1:
				suggestion_reason = "Low demand — consider lowering price"
			else:
				suggestion_reason = "Price matches demand"

	# Apply rating bonus (better courses can charge more)
	if rating >= 4.0:
		base_suggestion = int(base_suggestion * 1.15)
	elif rating >= 3.0:
		base_suggestion = int(base_suggestion * 1.05)
	elif rating < 2.0:
		base_suggestion = int(base_suggestion * 0.85)

	# Clamp to valid range
	suggested_fee = clamp(base_suggestion, GameManager.MIN_GREEN_FEE, max_fee)

	# Estimate revenue and golfers at suggested price
	_estimate_outcomes()

	pricing_updated.emit(suggested_fee, suggestion_reason)

func _analyze_demand() -> float:
	"""Analyze recent demand trends. Returns -1.0 to 1.0.
	Positive = high demand (can raise prices), negative = low demand (should lower)."""
	if daily_golfer_history.size() < 3:
		return 0.0

	var max_golfers = GameManager.golfer_manager.get_max_concurrent_golfers() if GameManager.golfer_manager else 20
	var recent_avg = 0.0
	var count = mini(daily_golfer_history.size(), 7)
	for i in range(daily_golfer_history.size() - count, daily_golfer_history.size()):
		recent_avg += daily_golfer_history[i]
	recent_avg /= count

	# Demand signal: ratio of actual golfers to capacity
	# At capacity = high demand, well below = low demand
	var capacity_ratio = clampf(recent_avg / max(float(max_golfers) * 0.6, 1.0), 0.0, 2.0)

	if capacity_ratio > 1.2:
		return 0.5  # Very high demand
	elif capacity_ratio > 0.8:
		return 0.2  # Good demand
	elif capacity_ratio > 0.5:
		return 0.0  # Normal
	elif capacity_ratio > 0.3:
		return -0.2  # Low demand
	else:
		return -0.5  # Very low demand

func _estimate_outcomes() -> void:
	"""Estimate revenue and golfer count at the suggested fee."""
	var holes = GameManager.get_open_hole_count()
	var max_golfers = GameManager.golfer_manager.get_max_concurrent_golfers() if GameManager.golfer_manager else 20

	# Simple demand curve: higher fees = fewer golfers
	var reputation = GameManager.reputation
	var hole_factor = clampf(float(holes) / 18.0, 0.15, 1.0)
	var fair_total = reputation * 2.0 * hole_factor
	var suggested_total = suggested_fee * max(holes, 1)

	# Price elasticity: at fair price, expect ~70% capacity; over/under adjusts
	var price_ratio = suggested_total / max(fair_total, 1.0)
	var demand_factor = clampf(1.5 - price_ratio * 0.8, 0.2, 1.2)

	golfer_estimate = int(max_golfers * demand_factor * 0.5)  # Average per day
	revenue_estimate = golfer_estimate * suggested_total

func _apply_auto_pricing() -> void:
	"""Apply the suggested fee automatically."""
	if suggested_fee != GameManager.green_fee:
		var old_fee = GameManager.green_fee
		GameManager.set_green_fee(suggested_fee)
		if abs(suggested_fee - old_fee) >= 5:
			EventBus.notify("Auto-pricing: $%d -> $%d/hole (%s)" % [old_fee, suggested_fee, suggestion_reason], "info")

## --- Display helpers ---

func get_price_analysis() -> Array:
	"""Get analysis data for UI display."""
	var holes = GameManager.get_open_hole_count()
	var reputation = GameManager.reputation
	var hole_factor = clampf(float(holes) / 18.0, 0.15, 1.0)
	var fair_total = reputation * 2.0 * hole_factor
	var fair_per_hole = int(fair_total / max(holes, 1))
	var current_fee = GameManager.green_fee
	var current_total = current_fee * max(holes, 1)
	var max_fee = GameManager.get_effective_max_green_fee()

	var analysis: Array = []
	analysis.append({"label": "Current Fee", "value": "$%d/hole ($%d total)" % [current_fee, current_total]})
	analysis.append({"label": "Fair Price", "value": "$%d/hole ($%d total)" % [fair_per_hole, int(fair_total)]})
	analysis.append({"label": "Suggested Fee", "value": "$%d/hole" % suggested_fee})
	analysis.append({"label": "Max Allowed", "value": "$%d/hole" % max_fee})
	analysis.append({"label": "Est. Golfers/Day", "value": str(golfer_estimate)})
	analysis.append({"label": "Est. Revenue/Day", "value": "$%d" % revenue_estimate})

	# Price status
	if current_total > fair_total * 1.5:
		analysis.append({"label": "Price Status", "value": "OVERPRICED", "color": "error"})
	elif current_total < fair_total * 0.6:
		analysis.append({"label": "Price Status", "value": "UNDERPRICED", "color": "warning"})
	else:
		analysis.append({"label": "Price Status", "value": "Fair", "color": "success"})

	# Demand trend
	var demand = _analyze_demand()
	if demand > 0.1:
		analysis.append({"label": "Demand Trend", "value": "High", "color": "success"})
	elif demand < -0.1:
		analysis.append({"label": "Demand Trend", "value": "Low", "color": "warning"})
	else:
		analysis.append({"label": "Demand Trend", "value": "Normal", "color": "info"})

	return analysis

static func get_strategy_name(strategy: int) -> String:
	match strategy:
		PricingStrategy.MAXIMIZE_REVENUE: return "Maximize Revenue"
		PricingStrategy.MAXIMIZE_GOLFERS: return "Maximize Golfers"
		PricingStrategy.BALANCED: return "Balanced"
	return "Unknown"

## --- Serialization ---

func serialize() -> Dictionary:
	return {
		"auto_pricing_enabled": auto_pricing_enabled,
		"current_strategy": current_strategy,
		"daily_revenue_history": daily_revenue_history.duplicate(),
		"daily_golfer_history": daily_golfer_history.duplicate(),
		"daily_fee_history": daily_fee_history.duplicate(),
		"suggested_fee": suggested_fee,
	}

func deserialize(data: Dictionary) -> void:
	auto_pricing_enabled = bool(data.get("auto_pricing_enabled", false))
	current_strategy = int(data.get("current_strategy", PricingStrategy.BALANCED))
	daily_revenue_history = data.get("daily_revenue_history", [])
	daily_golfer_history = data.get("daily_golfer_history", [])
	daily_fee_history = data.get("daily_fee_history", [])
	suggested_fee = int(data.get("suggested_fee", 30))
