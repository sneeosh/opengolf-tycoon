extends Node
class_name LoyaltySystem
## LoyaltySystem - Tracks golfer loyalty, memberships, and word-of-mouth
##
## Manages three interconnected systems:
## 1. Visit tracking - Counts total visits and satisfaction history
## 2. Membership tiers - Players can sell memberships for steady revenue
## 3. Word-of-mouth - Happy golfers generate referral bonuses

## Membership tier definitions
enum MembershipTier { NONE, BASIC, PREMIUM, VIP }

## Membership pricing and benefits
const MEMBERSHIP_CONFIG: Dictionary = {
	MembershipTier.BASIC: {
		"name": "Basic",
		"monthly_fee": 200,  # Per 28-day year
		"green_fee_discount": 0.15,  # 15% off green fees
		"max_members": 50,
		"spawn_bonus": 0.05,  # +5% spawn rate per 10 members
		"satisfaction_bonus": 0.02,  # Members are slightly happier
		"min_reputation": 20,
		"description": "15% green fee discount, priority tee times",
	},
	MembershipTier.PREMIUM: {
		"name": "Premium",
		"monthly_fee": 500,
		"green_fee_discount": 0.25,
		"max_members": 30,
		"spawn_bonus": 0.08,
		"satisfaction_bonus": 0.05,
		"min_reputation": 45,
		"description": "25% green fee discount, pro shop perks, priority booking",
	},
	MembershipTier.VIP: {
		"name": "VIP",
		"monthly_fee": 1200,
		"green_fee_discount": 0.40,
		"max_members": 10,
		"spawn_bonus": 0.12,
		"satisfaction_bonus": 0.08,
		"min_reputation": 70,
		"description": "40% green fee discount, exclusive events, personal locker",
	},
}

## Current membership counts per tier
var members: Dictionary = {
	MembershipTier.BASIC: 0,
	MembershipTier.PREMIUM: 0,
	MembershipTier.VIP: 0,
}

## Loyalty tracking stats
var total_visits: int = 0
var total_happy_visits: int = 0  # Mood >= 0.6
var total_unhappy_visits: int = 0  # Mood < 0.4
var word_of_mouth_score: float = 0.0  # -1.0 to 1.0, affects spawn rate
var loyalty_points: int = 0  # Accumulated from happy visits

## Whether membership sales are enabled (player must opt in)
var memberships_enabled: bool = false

signal membership_changed(tier: int, count: int)
signal loyalty_milestone_reached(milestone: String, reward: String)

func _ready() -> void:
	EventBus.golfer_finished_round.connect(_on_golfer_finished_round)
	EventBus.end_of_day.connect(_on_end_of_day)

func _exit_tree() -> void:
	if EventBus.golfer_finished_round.is_connected(_on_golfer_finished_round):
		EventBus.golfer_finished_round.disconnect(_on_golfer_finished_round)
	if EventBus.end_of_day.is_connected(_on_end_of_day):
		EventBus.end_of_day.disconnect(_on_end_of_day)

func _on_golfer_finished_round(golfer_id: int, _total_strokes: int) -> void:
	# Find the golfer to check their mood
	var golfer_manager = GameManager.golfer_manager
	if not golfer_manager:
		return

	var golfer = golfer_manager.get_golfer(golfer_id)
	if not golfer or golfer.is_tournament_golfer:
		return

	total_visits += 1

	var mood = golfer.current_mood
	if mood >= 0.6:
		total_happy_visits += 1
		loyalty_points += 1
		# Word-of-mouth slowly increases from happy golfers
		word_of_mouth_score = clampf(word_of_mouth_score + 0.005, -1.0, 1.0)
	elif mood < 0.4:
		total_unhappy_visits += 1
		# Unhappy golfers spread negative word-of-mouth faster
		word_of_mouth_score = clampf(word_of_mouth_score - 0.01, -1.0, 1.0)

	_check_loyalty_milestones()

func _on_end_of_day(day_number: int) -> void:
	# Word-of-mouth decays slightly toward neutral each day
	word_of_mouth_score *= 0.98

	# Process membership revenue on year boundaries (every 28 days)
	if day_number > 1 and (day_number - 1) % 28 == 0:
		_collect_membership_fees()

	# Membership growth/churn based on reputation and satisfaction
	_update_membership_counts()

func _collect_membership_fees() -> void:
	var total_revenue = 0
	for tier in MEMBERSHIP_CONFIG.keys():
		var config = MEMBERSHIP_CONFIG[tier]
		var count = members.get(tier, 0)
		if count > 0:
			var revenue = config["monthly_fee"] * count
			total_revenue += revenue

	if total_revenue > 0:
		GameManager.modify_money(total_revenue)
		EventBus.log_transaction("Membership fees", total_revenue)
		EventBus.notify("Membership revenue: +$%d" % total_revenue, "success")

func _update_membership_counts() -> void:
	if not memberships_enabled:
		return

	var reputation = GameManager.reputation
	var satisfaction = _get_average_satisfaction()

	for tier in MEMBERSHIP_CONFIG.keys():
		var config = MEMBERSHIP_CONFIG[tier]
		var current = members.get(tier, 0)
		var max_cap = config["max_members"]

		# Can't have members if reputation is too low
		if reputation < config["min_reputation"]:
			# Existing members leave if reputation drops too far below threshold
			if current > 0 and reputation < config["min_reputation"] * 0.7:
				members[tier] = max(0, current - 1)
				if members[tier] != current:
					membership_changed.emit(tier, members[tier])
			continue

		# Growth: gain a member if satisfaction is good and reputation is high enough
		# Higher reputation relative to requirement = faster growth
		var rep_factor = clampf((reputation - config["min_reputation"]) / 30.0, 0.0, 1.0)
		var growth_chance = rep_factor * satisfaction * 0.15  # Max ~15% daily growth chance

		if current < max_cap and randf() < growth_chance:
			members[tier] = current + 1
			membership_changed.emit(tier, members[tier])

		# Churn: lose a member if satisfaction is poor
		var churn_chance = (1.0 - satisfaction) * 0.05  # Max 5% daily churn
		if current > 0 and randf() < churn_chance:
			members[tier] = current - 1
			membership_changed.emit(tier, members[tier])

func _get_average_satisfaction() -> float:
	if total_visits == 0:
		return 0.5
	return clampf(float(total_happy_visits) / float(total_visits), 0.0, 1.0)

func _check_loyalty_milestones() -> void:
	var milestones = {
		50: {"name": "Getting Known", "reward": "+2 reputation"},
		200: {"name": "Local Favorite", "reward": "+5 reputation"},
		500: {"name": "Regional Attraction", "reward": "+10 reputation"},
		1000: {"name": "Golf Destination", "reward": "+15 reputation"},
		2500: {"name": "Legendary Course", "reward": "+25 reputation"},
	}

	if total_visits in milestones:
		var milestone = milestones[total_visits]
		var rep_bonus = int(milestone["reward"].split("+")[1].split(" ")[0])
		GameManager.modify_reputation(rep_bonus)
		EventBus.notify("Loyalty milestone: %s! %s" % [milestone["name"], milestone["reward"]], "success")
		loyalty_milestone_reached.emit(milestone["name"], milestone["reward"])

## --- Modifier queries ---

## Get green fee discount for a golfer (probability-based: some golfers are members)
func get_member_discount_chance() -> float:
	var total_members = get_total_members()
	if total_members == 0:
		return 0.0
	# Probability that a random golfer is a member
	# Capped at 40% — most golfers are still walk-ins
	var member_ratio = clampf(float(total_members) / 100.0, 0.0, 0.4)
	return member_ratio

## Get the average discount across all membership tiers (weighted by count)
func get_weighted_average_discount() -> float:
	var total_members = get_total_members()
	if total_members == 0:
		return 0.0
	var weighted_discount = 0.0
	for tier in MEMBERSHIP_CONFIG.keys():
		var count = members.get(tier, 0)
		if count > 0:
			weighted_discount += count * MEMBERSHIP_CONFIG[tier]["green_fee_discount"]
	return weighted_discount / float(total_members)

## Get spawn rate bonus from memberships + word-of-mouth
func get_spawn_rate_bonus() -> float:
	var bonus = 0.0

	# Word-of-mouth effect (positive = more golfers, negative = fewer)
	bonus += word_of_mouth_score * 0.15  # Up to +/- 15% from word of mouth

	# Membership-driven interest (members bring friends)
	for tier in MEMBERSHIP_CONFIG.keys():
		var count = members.get(tier, 0)
		if count > 0:
			var per_10_bonus = MEMBERSHIP_CONFIG[tier]["spawn_bonus"]
			bonus += (float(count) / 10.0) * per_10_bonus

	return bonus

## Get total member count across all tiers
func get_total_members() -> int:
	var total = 0
	for count in members.values():
		total += count
	return total

## Get membership satisfaction bonus (members are happier on average)
func get_satisfaction_bonus() -> float:
	var bonus = 0.0
	for tier in MEMBERSHIP_CONFIG.keys():
		if members.get(tier, 0) > 0:
			bonus = maxf(bonus, MEMBERSHIP_CONFIG[tier]["satisfaction_bonus"])
	return bonus

## Toggle membership sales on/off
func set_memberships_enabled(enabled: bool) -> void:
	memberships_enabled = enabled
	if not enabled:
		# Members don't immediately leave, but no new members join
		pass

## --- Display helpers ---

static func get_tier_name(tier: int) -> String:
	match tier:
		MembershipTier.BASIC: return "Basic"
		MembershipTier.PREMIUM: return "Premium"
		MembershipTier.VIP: return "VIP"
	return "None"

static func get_tier_color(tier: int) -> Color:
	match tier:
		MembershipTier.BASIC: return Color(0.4, 0.6, 0.4)
		MembershipTier.PREMIUM: return Color(0.3, 0.5, 0.8)
		MembershipTier.VIP: return Color(0.85, 0.7, 0.2)
	return Color(0.5, 0.5, 0.5)

## --- Serialization ---

func serialize() -> Dictionary:
	return {
		"members": members.duplicate(),
		"total_visits": total_visits,
		"total_happy_visits": total_happy_visits,
		"total_unhappy_visits": total_unhappy_visits,
		"word_of_mouth_score": word_of_mouth_score,
		"loyalty_points": loyalty_points,
		"memberships_enabled": memberships_enabled,
	}

func deserialize(data: Dictionary) -> void:
	var saved_members = data.get("members", {})
	for tier in members.keys():
		# Dictionary keys from JSON may be strings
		var key_str = str(tier)
		if saved_members.has(tier):
			members[tier] = int(saved_members[tier])
		elif saved_members.has(key_str):
			members[tier] = int(saved_members[key_str])

	total_visits = int(data.get("total_visits", 0))
	total_happy_visits = int(data.get("total_happy_visits", 0))
	total_unhappy_visits = int(data.get("total_unhappy_visits", 0))
	word_of_mouth_score = float(data.get("word_of_mouth_score", 0.0))
	loyalty_points = int(data.get("loyalty_points", 0))
	memberships_enabled = bool(data.get("memberships_enabled", false))
