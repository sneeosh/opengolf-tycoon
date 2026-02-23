extends Node
class_name PrestigeSystem
## PrestigeSystem - Course prestige tiers with unlock progression
##
## Tracks course prestige level (Bronze -> Silver -> Gold -> Platinum) based on
## sustained performance. Each tier has requirements (reputation, rating, revenue,
## awards) and unlocks (buildings, terrain types, decorations, gameplay features).
## Higher prestige increases golfer expectations and unlocks endgame content.

enum PrestigeTier { UNRANKED, BRONZE, SILVER, GOLD, PLATINUM }

## Current prestige tier
var current_tier: int = PrestigeTier.UNRANKED

## Progress toward next tier (0.0 to 1.0)
var tier_progress: float = 0.0

## Lifetime stats for prestige calculation
var lifetime_stats: Dictionary = {
	"total_revenue": 0,
	"total_golfers": 0,
	"total_awards": 0,
	"peak_reputation": 0.0,
	"peak_rating": 0.0,
	"days_at_4_stars": 0,
	"days_at_5_stars": 0,
	"championships_hosted": 0,
	"total_days": 0,
}

## Tier requirement definitions
const TIER_REQUIREMENTS: Dictionary = {
	PrestigeTier.BRONZE: {
		"name": "Bronze",
		"min_reputation": 40.0,
		"min_rating": 2.5,
		"min_total_revenue": 30000,
		"min_total_golfers": 100,
		"min_days": 28,
		"description": "A recognized local course with steady visitors.",
	},
	PrestigeTier.SILVER: {
		"name": "Silver",
		"min_reputation": 60.0,
		"min_rating": 3.5,
		"min_total_revenue": 100000,
		"min_total_golfers": 300,
		"min_awards": 3,
		"min_days": 56,
		"description": "A well-respected course attracting regional attention.",
	},
	PrestigeTier.GOLD: {
		"name": "Gold",
		"min_reputation": 80.0,
		"min_rating": 4.0,
		"min_total_revenue": 300000,
		"min_total_golfers": 800,
		"min_awards": 8,
		"min_championships": 1,
		"min_days": 112,
		"description": "An elite destination course known nationally.",
	},
	PrestigeTier.PLATINUM: {
		"name": "Platinum",
		"min_reputation": 90.0,
		"min_rating": 4.5,
		"min_total_revenue": 750000,
		"min_total_golfers": 2000,
		"min_awards": 15,
		"min_championships": 3,
		"min_days_at_5_stars": 14,
		"min_days": 224,
		"description": "A legendary world-class golfing institution.",
	},
}

## Tier unlock definitions
const TIER_UNLOCKS: Dictionary = {
	PrestigeTier.BRONZE: {
		"green_fee_bonus": 10,  # Can charge $10 more than normal max
		"spawn_rate_bonus": 0.1,  # +10% golfer spawns
		"description": "Green fee cap +$10, +10% golfer interest",
	},
	PrestigeTier.SILVER: {
		"green_fee_bonus": 25,
		"spawn_rate_bonus": 0.2,
		"pro_spawn_bonus": 0.15,  # +15% chance of pro golfers
		"description": "Green fee cap +$25, +20% golfer interest, +15% pro golfers",
	},
	PrestigeTier.GOLD: {
		"green_fee_bonus": 50,
		"spawn_rate_bonus": 0.35,
		"pro_spawn_bonus": 0.25,
		"maintenance_discount": 0.1,  # 10% off maintenance
		"description": "Green fee cap +$50, +35% golfer interest, +25% pro golfers, 10% maintenance discount",
	},
	PrestigeTier.PLATINUM: {
		"green_fee_bonus": 100,
		"spawn_rate_bonus": 0.5,
		"pro_spawn_bonus": 0.4,
		"maintenance_discount": 0.2,
		"reputation_decay_reduction": 0.5,  # 50% less reputation decay
		"description": "Green fee cap +$100, +50% golfer interest, +40% pro golfers, 20% maintenance discount, 50% less reputation decay",
	},
}

signal prestige_changed(old_tier: int, new_tier: int)
signal prestige_progress_updated(tier: int, progress: float)

func _ready() -> void:
	EventBus.end_of_day.connect(_on_end_of_day)

func _exit_tree() -> void:
	if EventBus.end_of_day.is_connected(_on_end_of_day):
		EventBus.end_of_day.disconnect(_on_end_of_day)

func _on_end_of_day(_day_number: int) -> void:
	_update_lifetime_stats()
	_check_tier_promotion()

func _update_lifetime_stats() -> void:
	lifetime_stats.total_days += 1
	lifetime_stats.total_revenue += GameManager.daily_stats.get_total_revenue()
	lifetime_stats.total_golfers += GameManager.daily_stats.golfers_served

	if GameManager.reputation > lifetime_stats.peak_reputation:
		lifetime_stats.peak_reputation = GameManager.reputation

	var overall_rating = GameManager.course_rating.get("overall", 0.0)
	if overall_rating > lifetime_stats.peak_rating:
		lifetime_stats.peak_rating = overall_rating

	var stars = GameManager.course_rating.get("stars", 0)
	if stars >= 4:
		lifetime_stats.days_at_4_stars += 1
	if stars >= 5:
		lifetime_stats.days_at_5_stars += 1

	# Count awards from awards system
	if GameManager.awards_system:
		lifetime_stats.total_awards = GameManager.awards_system.hall_of_fame.size()

	# Count championship tournaments
	if GameManager.tournament_manager:
		# Already tracked via tournament_completed signal
		pass

func _check_tier_promotion() -> void:
	var next_tier = current_tier + 1
	if next_tier > PrestigeTier.PLATINUM:
		tier_progress = 1.0
		return

	var reqs = TIER_REQUIREMENTS.get(next_tier, {})
	var progress = _calculate_progress(reqs)
	tier_progress = progress
	prestige_progress_updated.emit(current_tier, progress)

	if progress >= 1.0:
		_promote(next_tier)

func _calculate_progress(reqs: Dictionary) -> float:
	if reqs.is_empty():
		return 0.0

	var checks: Array = []

	# Each requirement contributes equally to progress
	if reqs.has("min_reputation"):
		checks.append(clampf(GameManager.reputation / reqs["min_reputation"], 0.0, 1.0))

	if reqs.has("min_rating"):
		var rating = GameManager.course_rating.get("overall", 0.0)
		checks.append(clampf(rating / reqs["min_rating"], 0.0, 1.0))

	if reqs.has("min_total_revenue"):
		checks.append(clampf(float(lifetime_stats.total_revenue) / float(reqs["min_total_revenue"]), 0.0, 1.0))

	if reqs.has("min_total_golfers"):
		checks.append(clampf(float(lifetime_stats.total_golfers) / float(reqs["min_total_golfers"]), 0.0, 1.0))

	if reqs.has("min_awards"):
		checks.append(clampf(float(lifetime_stats.total_awards) / float(reqs["min_awards"]), 0.0, 1.0))

	if reqs.has("min_championships"):
		checks.append(clampf(float(lifetime_stats.championships_hosted) / float(reqs["min_championships"]), 0.0, 1.0))

	if reqs.has("min_days"):
		checks.append(clampf(float(lifetime_stats.total_days) / float(reqs["min_days"]), 0.0, 1.0))

	if reqs.has("min_days_at_5_stars"):
		checks.append(clampf(float(lifetime_stats.days_at_5_stars) / float(reqs["min_days_at_5_stars"]), 0.0, 1.0))

	if checks.is_empty():
		return 0.0

	# Progress is the MINIMUM of all checks (all must be met to promote)
	# But we show average for the progress bar to feel rewarding
	var min_check = checks.min()
	var avg_check = 0.0
	for c in checks:
		avg_check += c
	avg_check /= checks.size()

	# Return average for display, but only hit 1.0 if all checks pass
	if min_check >= 1.0:
		return 1.0
	return clampf(avg_check * 0.95, 0.0, 0.99)  # Cap at 0.99 until all checks pass

func _promote(new_tier: int) -> void:
	var old_tier = current_tier
	current_tier = new_tier
	tier_progress = 0.0

	var tier_name = get_tier_name(new_tier)
	EventBus.notify("PRESTIGE UP! Your course has reached %s status!" % tier_name, "success")

	# Reputation bonus for reaching new tier
	var rep_bonus = [0, 5.0, 10.0, 15.0, 25.0][new_tier]
	GameManager.modify_reputation(rep_bonus)

	prestige_changed.emit(old_tier, new_tier)
	EventBus.prestige_changed.emit(old_tier, new_tier)

## --- Modifier queries ---

## Get green fee cap bonus from current prestige tier
func get_green_fee_bonus() -> int:
	var unlocks = TIER_UNLOCKS.get(current_tier, {})
	return int(unlocks.get("green_fee_bonus", 0))

## Get spawn rate bonus from current prestige tier
func get_spawn_rate_bonus() -> float:
	var unlocks = TIER_UNLOCKS.get(current_tier, {})
	return float(unlocks.get("spawn_rate_bonus", 0.0))

## Get pro golfer spawn bonus
func get_pro_spawn_bonus() -> float:
	var unlocks = TIER_UNLOCKS.get(current_tier, {})
	return float(unlocks.get("pro_spawn_bonus", 0.0))

## Get maintenance cost discount (0.0 to 0.2)
func get_maintenance_discount() -> float:
	var unlocks = TIER_UNLOCKS.get(current_tier, {})
	return float(unlocks.get("maintenance_discount", 0.0))

## Get reputation decay reduction factor (0.0 to 0.5)
func get_reputation_decay_reduction() -> float:
	var unlocks = TIER_UNLOCKS.get(current_tier, {})
	return float(unlocks.get("reputation_decay_reduction", 0.0))

## --- Display helpers ---

static func get_tier_name(tier: int) -> String:
	match tier:
		PrestigeTier.UNRANKED: return "Unranked"
		PrestigeTier.BRONZE: return "Bronze"
		PrestigeTier.SILVER: return "Silver"
		PrestigeTier.GOLD: return "Gold"
		PrestigeTier.PLATINUM: return "Platinum"
	return "Unknown"

static func get_tier_color(tier: int) -> Color:
	match tier:
		PrestigeTier.UNRANKED: return Color(0.5, 0.5, 0.5)
		PrestigeTier.BRONZE: return Color(0.8, 0.5, 0.2)
		PrestigeTier.SILVER: return Color(0.75, 0.75, 0.78)
		PrestigeTier.GOLD: return Color(1.0, 0.85, 0.0)
		PrestigeTier.PLATINUM: return Color(0.7, 0.9, 1.0)
	return Color.WHITE

## Get requirement details for a specific tier
func get_tier_requirements_display(tier: int) -> Array:
	var reqs = TIER_REQUIREMENTS.get(tier, {})
	var display: Array = []

	if reqs.has("min_reputation"):
		var met = GameManager.reputation >= reqs["min_reputation"]
		display.append({"label": "Reputation", "required": "%.0f" % reqs["min_reputation"], "current": "%.0f" % GameManager.reputation, "met": met})

	if reqs.has("min_rating"):
		var rating = GameManager.course_rating.get("overall", 0.0)
		var met = rating >= reqs["min_rating"]
		display.append({"label": "Course Rating", "required": "%.1f stars" % reqs["min_rating"], "current": "%.1f stars" % rating, "met": met})

	if reqs.has("min_total_revenue"):
		var met = lifetime_stats.total_revenue >= reqs["min_total_revenue"]
		display.append({"label": "Lifetime Revenue", "required": "$%d" % reqs["min_total_revenue"], "current": "$%d" % lifetime_stats.total_revenue, "met": met})

	if reqs.has("min_total_golfers"):
		var met = lifetime_stats.total_golfers >= reqs["min_total_golfers"]
		display.append({"label": "Total Golfers", "required": "%d" % reqs["min_total_golfers"], "current": "%d" % lifetime_stats.total_golfers, "met": met})

	if reqs.has("min_awards"):
		var met = lifetime_stats.total_awards >= reqs["min_awards"]
		display.append({"label": "Awards Earned", "required": "%d" % reqs["min_awards"], "current": "%d" % lifetime_stats.total_awards, "met": met})

	if reqs.has("min_championships"):
		var met = lifetime_stats.championships_hosted >= reqs["min_championships"]
		display.append({"label": "Championships", "required": "%d" % reqs["min_championships"], "current": "%d" % lifetime_stats.championships_hosted, "met": met})

	if reqs.has("min_days"):
		var met = lifetime_stats.total_days >= reqs["min_days"]
		display.append({"label": "Days Played", "required": "%d" % reqs["min_days"], "current": "%d" % lifetime_stats.total_days, "met": met})

	if reqs.has("min_days_at_5_stars"):
		var met = lifetime_stats.days_at_5_stars >= reqs["min_days_at_5_stars"]
		display.append({"label": "Days at 5 Stars", "required": "%d" % reqs["min_days_at_5_stars"], "current": "%d" % lifetime_stats.days_at_5_stars, "met": met})

	return display

## --- Serialization ---

func serialize() -> Dictionary:
	return {
		"current_tier": current_tier,
		"tier_progress": tier_progress,
		"lifetime_stats": lifetime_stats.duplicate(),
	}

func deserialize(data: Dictionary) -> void:
	current_tier = int(data.get("current_tier", PrestigeTier.UNRANKED))
	tier_progress = float(data.get("tier_progress", 0.0))

	var stats = data.get("lifetime_stats", {})
	for key in lifetime_stats.keys():
		if stats.has(key):
			lifetime_stats[key] = stats[key]
