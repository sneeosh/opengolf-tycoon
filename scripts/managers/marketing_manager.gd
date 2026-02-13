extends Node
class_name MarketingManager
## MarketingManager - Marketing campaigns that increase golfer spawn rates
##
## 5 marketing channels with varying cost, duration, and effectiveness.
## Stacked campaigns have diminishing returns.

enum Channel {
	LOCAL_ADS,       # Cheap, short, modest effect
	SOCIAL_MEDIA,    # Moderate cost, targets younger golfers
	GOLF_MAGAZINE,   # Expensive, targets serious golfers
	RADIO,           # Moderate cost, broad reach
	TOURNAMENT_PROMO # Very expensive, big spike
}

const CHANNEL_DATA = {
	Channel.LOCAL_ADS: {
		"name": "Local Newspaper Ads",
		"daily_cost": 50,
		"duration_days": 5,
		"spawn_rate_bonus": 0.15,  # +15% spawn rate
		"description": "Affordable local advertising in community newspapers",
	},
	Channel.SOCIAL_MEDIA: {
		"name": "Social Media Campaign",
		"daily_cost": 80,
		"duration_days": 7,
		"spawn_rate_bonus": 0.20,
		"description": "Targeted online ads reaching younger golfers",
	},
	Channel.GOLF_MAGAZINE: {
		"name": "Golf Magazine Feature",
		"daily_cost": 150,
		"duration_days": 10,
		"spawn_rate_bonus": 0.30,
		"description": "Premium magazine placement for serious golf enthusiasts",
	},
	Channel.RADIO: {
		"name": "Radio Advertising",
		"daily_cost": 100,
		"duration_days": 7,
		"spawn_rate_bonus": 0.25,
		"description": "Broad-reach radio spots during drive time",
	},
	Channel.TOURNAMENT_PROMO: {
		"name": "Tournament Promotion",
		"daily_cost": 250,
		"duration_days": 3,
		"spawn_rate_bonus": 0.50,
		"description": "Intensive promotion around tournament events",
	},
}

signal campaign_started(channel: int)
signal campaign_ended(channel: int)
signal campaigns_changed()

## Active campaigns: Array of {channel: Channel, days_remaining: int, daily_cost: int}
var active_campaigns: Array = []

## Historical data for ROI tracking
var total_marketing_spent: int = 0
var campaigns_completed: int = 0

func start_campaign(channel: int) -> bool:
	"""Start a new marketing campaign."""
	var data = CHANNEL_DATA.get(channel, {})
	if data.is_empty():
		return false

	# Check if same channel is already active (allow stacking, but warn)
	for campaign in active_campaigns:
		if campaign.channel == channel:
			EventBus.notify("Already running %s - stacking has diminishing returns" % data.name, "info")
			break

	var setup_cost = data.daily_cost * 2  # Upfront setup fee
	if not GameManager.can_afford(setup_cost):
		EventBus.notify("Not enough money! Setup cost: $%d" % setup_cost, "error")
		return false

	GameManager.modify_money(-setup_cost)
	EventBus.log_transaction("Marketing setup: %s" % data.name, -setup_cost)
	total_marketing_spent += setup_cost

	active_campaigns.append({
		"channel": channel,
		"days_remaining": data.duration_days,
		"daily_cost": data.daily_cost,
	})

	campaign_started.emit(channel)
	campaigns_changed.emit()
	EventBus.notify("Started %s campaign (%d days)" % [data.name, data.duration_days], "success")
	return true

func process_daily() -> int:
	"""Process campaigns at end of day. Returns total daily marketing cost."""
	var daily_total: int = 0
	var expired: Array = []

	for i in range(active_campaigns.size()):
		var campaign = active_campaigns[i]
		daily_total += campaign.daily_cost
		campaign.days_remaining -= 1

		if campaign.days_remaining <= 0:
			expired.append(i)

	# Remove expired campaigns (in reverse to preserve indices)
	for i in range(expired.size() - 1, -1, -1):
		var campaign = active_campaigns[expired[i]]
		var data = CHANNEL_DATA.get(campaign.channel, {})
		EventBus.notify("%s campaign ended" % data.get("name", "Marketing"), "info")
		campaign_ended.emit(campaign.channel)
		active_campaigns.remove_at(expired[i])
		campaigns_completed += 1

	total_marketing_spent += daily_total

	if not expired.is_empty():
		campaigns_changed.emit()

	return daily_total

func get_spawn_rate_modifier() -> float:
	"""Get the combined spawn rate bonus from all active campaigns.
	Stacked campaigns have diminishing returns (square root scaling)."""
	if active_campaigns.is_empty():
		return 1.0

	var total_bonus: float = 0.0
	for campaign in active_campaigns:
		var data = CHANNEL_DATA.get(campaign.channel, {})
		total_bonus += data.get("spawn_rate_bonus", 0.0)

	# Diminishing returns: sqrt scaling prevents infinite stacking benefit
	# 1 campaign at 0.25 = 1.25x, 4 campaigns at 0.25 each = sqrt(1.0) + 1 = 2.0x (not 2.0x)
	return 1.0 + sqrt(total_bonus)

func get_daily_marketing_cost() -> int:
	"""Get total daily cost of all active campaigns."""
	var total: int = 0
	for campaign in active_campaigns:
		total += campaign.daily_cost
	return total

func get_active_campaign_count() -> int:
	return active_campaigns.size()

func get_channel_name(channel: int) -> String:
	var data = CHANNEL_DATA.get(channel, {})
	return data.get("name", "Unknown")

## Serialization
func serialize() -> Dictionary:
	var campaigns_arr: Array = []
	for c in active_campaigns:
		campaigns_arr.append({
			"channel": c.channel,
			"days_remaining": c.days_remaining,
			"daily_cost": c.daily_cost,
		})
	return {
		"active_campaigns": campaigns_arr,
		"total_marketing_spent": total_marketing_spent,
		"campaigns_completed": campaigns_completed,
	}

func deserialize(data: Dictionary) -> void:
	active_campaigns.clear()
	total_marketing_spent = data.get("total_marketing_spent", 0)
	campaigns_completed = data.get("campaigns_completed", 0)
	for c in data.get("active_campaigns", []):
		active_campaigns.append({
			"channel": int(c.channel),
			"days_remaining": int(c.days_remaining),
			"daily_cost": int(c.daily_cost),
		})
	campaigns_changed.emit()
