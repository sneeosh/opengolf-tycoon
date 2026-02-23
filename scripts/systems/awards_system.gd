extends Node
class_name AwardsSystem
## AwardsSystem - End-of-year awards ceremony and hall of fame
##
## Tracks yearly performance and generates awards at the end of each game year
## (every 28 days). Awards provide reputation bonuses and are stored in a
## permanent hall of fame. Creates a "one more year" retention hook.

## Award definition
class Award:
	var id: String = ""
	var title: String = ""
	var description: String = ""
	var year: int = 0
	var value: String = ""  # Display value (e.g., "$12,450" or "4.2 stars")
	var reputation_bonus: float = 0.0
	var tier: int = 0  # 0=bronze, 1=silver, 2=gold

	func get_tier_name() -> String:
		match tier:
			0: return "Bronze"
			1: return "Silver"
			2: return "Gold"
		return ""

## Hall of fame — all awards ever earned (persisted)
var hall_of_fame: Array = []  # Array of Award

## Current year tracking stats
var yearly_stats: Dictionary = {
	"total_revenue": 0,
	"total_golfers": 0,
	"best_daily_revenue": 0,
	"best_daily_revenue_day": 0,
	"worst_daily_profit": 999999,
	"worst_daily_profit_day": 0,
	"tournaments_hosted": 0,
	"highest_tournament_tier": -1,
	"peak_reputation": 0.0,
	"total_holes_in_one": 0,
	"total_eagles": 0,
	"holes_built": 0,
	"buildings_placed": 0,
	"days_profitable": 0,
	"days_in_year": 0,
	"peak_rating": 0.0,
	"year_start_money": 0,
}

## Last generated awards (for display after ceremony)
var latest_awards: Array = []

signal awards_generated(awards: Array, year: int)

func _ready() -> void:
	EventBus.end_of_day.connect(_on_end_of_day)
	EventBus.day_changed.connect(_on_day_changed)
	EventBus.tournament_completed.connect(_on_tournament_completed)
	EventBus.hole_created.connect(_on_hole_created)
	EventBus.building_placed.connect(_on_building_placed)

func _exit_tree() -> void:
	if EventBus.end_of_day.is_connected(_on_end_of_day):
		EventBus.end_of_day.disconnect(_on_end_of_day)
	if EventBus.day_changed.is_connected(_on_day_changed):
		EventBus.day_changed.disconnect(_on_day_changed)
	if EventBus.tournament_completed.is_connected(_on_tournament_completed):
		EventBus.tournament_completed.disconnect(_on_tournament_completed)
	if EventBus.hole_created.is_connected(_on_hole_created):
		EventBus.hole_created.disconnect(_on_hole_created)
	if EventBus.building_placed.is_connected(_on_building_placed):
		EventBus.building_placed.disconnect(_on_building_placed)

func _on_day_changed(new_day: int) -> void:
	# Check if a new year just started (day 1 of year 2+)
	var prev_year = SeasonSystem.get_year(new_day - 1)
	var curr_year = SeasonSystem.get_year(new_day)
	if curr_year > prev_year and prev_year >= 1:
		_generate_yearly_awards(prev_year)
		_reset_yearly_stats()
		yearly_stats.year_start_money = GameManager.money

	# Initialize year_start_money on first day
	if new_day == 1:
		yearly_stats.year_start_money = GameManager.money

func _on_end_of_day(day_number: int) -> void:
	_track_daily_stats(day_number)

func _on_tournament_completed(tier: int, _results: Dictionary) -> void:
	yearly_stats.tournaments_hosted += 1
	if tier > yearly_stats.highest_tournament_tier:
		yearly_stats.highest_tournament_tier = tier

func _on_hole_created(_hole_number: int, _par: int, _distance: int) -> void:
	yearly_stats.holes_built += 1

func _on_building_placed(_building_type: String, _position: Vector2i) -> void:
	yearly_stats.buildings_placed += 1

func _track_daily_stats(day_number: int) -> void:
	yearly_stats.days_in_year += 1

	var daily_rev = GameManager.daily_stats.get_total_revenue()
	var daily_profit = GameManager.daily_stats.get_profit()
	var golfers = GameManager.daily_stats.golfers_served

	yearly_stats.total_revenue += daily_rev
	yearly_stats.total_golfers += golfers
	yearly_stats.total_holes_in_one += GameManager.daily_stats.holes_in_one
	yearly_stats.total_eagles += GameManager.daily_stats.eagles

	if daily_rev > yearly_stats.best_daily_revenue:
		yearly_stats.best_daily_revenue = daily_rev
		yearly_stats.best_daily_revenue_day = day_number

	if daily_profit < yearly_stats.worst_daily_profit:
		yearly_stats.worst_daily_profit = daily_profit
		yearly_stats.worst_daily_profit_day = day_number

	if daily_profit > 0:
		yearly_stats.days_profitable += 1

	if GameManager.reputation > yearly_stats.peak_reputation:
		yearly_stats.peak_reputation = GameManager.reputation

	var overall_rating = GameManager.course_rating.get("overall", 0.0)
	if overall_rating > yearly_stats.peak_rating:
		yearly_stats.peak_rating = overall_rating

func _reset_yearly_stats() -> void:
	yearly_stats = {
		"total_revenue": 0,
		"total_golfers": 0,
		"best_daily_revenue": 0,
		"best_daily_revenue_day": 0,
		"worst_daily_profit": 999999,
		"worst_daily_profit_day": 0,
		"tournaments_hosted": 0,
		"highest_tournament_tier": -1,
		"peak_reputation": 0.0,
		"total_holes_in_one": 0,
		"total_eagles": 0,
		"holes_built": 0,
		"buildings_placed": 0,
		"days_profitable": 0,
		"days_in_year": 0,
		"peak_rating": 0.0,
		"year_start_money": GameManager.money,
	}

## Generate awards for a completed year
func _generate_yearly_awards(year: int) -> void:
	latest_awards.clear()

	# Revenue award
	_evaluate_revenue_award(year)

	# Golfer count award
	_evaluate_golfer_award(year)

	# Profitability award
	_evaluate_profitability_award(year)

	# Tournament award
	_evaluate_tournament_award(year)

	# Reputation award
	_evaluate_reputation_award(year)

	# Course quality award
	_evaluate_quality_award(year)

	# Growth award
	_evaluate_growth_award(year)

	# Eagle/Ace award
	_evaluate_scoring_award(year)

	# Add all to hall of fame
	for award in latest_awards:
		hall_of_fame.append(award)

	# Apply reputation bonuses
	var total_rep_bonus: float = 0.0
	for award in latest_awards:
		total_rep_bonus += award.reputation_bonus

	if total_rep_bonus > 0:
		GameManager.modify_reputation(total_rep_bonus)

	if not latest_awards.is_empty():
		EventBus.notify("Year %d Awards Ceremony! You earned %d award(s)!" % [year, latest_awards.size()], "success")
		awards_generated.emit(latest_awards, year)

func _create_award(id: String, title: String, desc: String, value: String, year: int, tier: int, rep_bonus: float) -> Award:
	var award = Award.new()
	award.id = id
	award.title = title
	award.description = desc
	award.value = value
	award.year = year
	award.tier = tier
	award.reputation_bonus = rep_bonus
	return award

func _evaluate_revenue_award(year: int) -> void:
	var rev = yearly_stats.total_revenue
	if rev <= 0:
		return

	var tier: int
	var desc: String
	if rev >= 100000:
		tier = 2
		desc = "Generated over $100,000 in annual revenue. Outstanding business!"
	elif rev >= 50000:
		tier = 1
		desc = "Generated over $50,000 in annual revenue. Strong performance!"
	elif rev >= 20000:
		tier = 0
		desc = "Generated over $20,000 in annual revenue. Solid start!"
	else:
		return

	latest_awards.append(_create_award(
		"revenue_y%d" % year, "Top Revenue", desc,
		"$%d" % rev, year, tier, [1.0, 2.0, 4.0][tier]
	))

func _evaluate_golfer_award(year: int) -> void:
	var count = yearly_stats.total_golfers
	if count <= 0:
		return

	var tier: int
	var desc: String
	if count >= 200:
		tier = 2
		desc = "Hosted over 200 golfers this year. Your course is a destination!"
	elif count >= 100:
		tier = 1
		desc = "Hosted over 100 golfers this year. Growing popularity!"
	elif count >= 50:
		tier = 0
		desc = "Hosted over 50 golfers this year. Building a customer base."
	else:
		return

	latest_awards.append(_create_award(
		"golfers_y%d" % year, "Popular Destination", desc,
		"%d golfers" % count, year, tier, [0.5, 1.5, 3.0][tier]
	))

func _evaluate_profitability_award(year: int) -> void:
	if yearly_stats.days_in_year == 0:
		return

	var profit_rate = float(yearly_stats.days_profitable) / float(yearly_stats.days_in_year)

	var tier: int
	var desc: String
	if profit_rate >= 0.9:
		tier = 2
		desc = "Profitable on %d%% of days. Master of the bottom line!" % int(profit_rate * 100)
	elif profit_rate >= 0.7:
		tier = 1
		desc = "Profitable on %d%% of days. Well-managed finances." % int(profit_rate * 100)
	elif profit_rate >= 0.5:
		tier = 0
		desc = "Profitable on %d%% of days. Room for improvement." % int(profit_rate * 100)
	else:
		return

	latest_awards.append(_create_award(
		"profit_y%d" % year, "Fiscal Responsibility", desc,
		"%d%% profitable days" % int(profit_rate * 100), year, tier, [0.5, 1.5, 3.0][tier]
	))

func _evaluate_tournament_award(year: int) -> void:
	if yearly_stats.tournaments_hosted == 0:
		return

	var tier_names = ["Local", "Regional", "National", "Championship"]
	var best_tier = yearly_stats.highest_tournament_tier
	if best_tier < 0:
		return

	var tier: int
	var desc: String
	if best_tier >= 3:
		tier = 2
		desc = "Hosted a Championship tournament! The pinnacle of competitive golf."
	elif best_tier >= 2:
		tier = 1
		desc = "Hosted a National tournament. Your course is gaining recognition."
	elif best_tier >= 1:
		tier = 0
		desc = "Hosted a Regional tournament. Moving up the ranks!"
	else:
		return

	latest_awards.append(_create_award(
		"tournament_y%d" % year, "Tournament Host", desc,
		tier_names[best_tier], year, tier, [1.0, 2.5, 5.0][tier]
	))

func _evaluate_reputation_award(year: int) -> void:
	var peak = yearly_stats.peak_reputation

	var tier: int
	var desc: String
	if peak >= 90:
		tier = 2
		desc = "Peak reputation of %.0f — your course is legendary!" % peak
	elif peak >= 70:
		tier = 1
		desc = "Peak reputation of %.0f — well respected in the golf community." % peak
	elif peak >= 50:
		tier = 0
		desc = "Peak reputation of %.0f — establishing a solid name." % peak
	else:
		return

	latest_awards.append(_create_award(
		"reputation_y%d" % year, "Course Prestige", desc,
		"%.0f reputation" % peak, year, tier, [0.5, 1.5, 3.0][tier]
	))

func _evaluate_quality_award(year: int) -> void:
	var peak = yearly_stats.peak_rating

	var tier: int
	var desc: String
	if peak >= 4.5:
		tier = 2
		desc = "Achieved a %.1f-star rating — a world-class golfing experience!" % peak
	elif peak >= 3.5:
		tier = 1
		desc = "Achieved a %.1f-star rating — a quality course worth visiting." % peak
	elif peak >= 2.5:
		tier = 0
		desc = "Achieved a %.1f-star rating — showing promise." % peak
	else:
		return

	latest_awards.append(_create_award(
		"quality_y%d" % year, "Course Excellence", desc,
		"%.1f stars" % peak, year, tier, [0.5, 1.5, 3.0][tier]
	))

func _evaluate_growth_award(year: int) -> void:
	var holes = yearly_stats.holes_built
	var buildings = yearly_stats.buildings_placed
	var total = holes + buildings

	if total < 3:
		return

	var tier: int
	var desc: String
	if total >= 15:
		tier = 2
		desc = "Massive expansion: %d holes and %d buildings added!" % [holes, buildings]
	elif total >= 8:
		tier = 1
		desc = "Strong growth: %d holes and %d buildings added." % [holes, buildings]
	else:
		tier = 0
		desc = "Steady progress: %d holes and %d buildings added." % [holes, buildings]

	latest_awards.append(_create_award(
		"growth_y%d" % year, "Course Developer", desc,
		"%d additions" % total, year, tier, [0.5, 1.0, 2.0][tier]
	))

func _evaluate_scoring_award(year: int) -> void:
	var aces = yearly_stats.total_holes_in_one
	var eagles = yearly_stats.total_eagles

	if aces >= 3:
		latest_awards.append(_create_award(
			"aces_y%d" % year, "Ace Factory",
			"%d holes-in-one on your course this year! Your design creates magic moments." % aces,
			"%d aces" % aces, year, 2, 3.0
		))
	elif aces >= 1:
		latest_awards.append(_create_award(
			"aces_y%d" % year, "Hole-in-One Club",
			"%d hole(s)-in-one recorded this year!" % aces,
			"%d ace(s)" % aces, year, 1, 1.5
		))
	elif eagles >= 5:
		latest_awards.append(_create_award(
			"eagles_y%d" % year, "Eagle's Nest",
			"%d eagles scored this year. Your course rewards skilled play." % eagles,
			"%d eagles" % eagles, year, 0, 0.5
		))

## --- Serialization ---

func serialize() -> Dictionary:
	var fame_data: Array = []
	for award in hall_of_fame:
		fame_data.append({
			"id": award.id,
			"title": award.title,
			"description": award.description,
			"year": award.year,
			"value": award.value,
			"reputation_bonus": award.reputation_bonus,
			"tier": award.tier,
		})
	return {
		"hall_of_fame": fame_data,
		"yearly_stats": yearly_stats.duplicate(),
	}

func deserialize(data: Dictionary) -> void:
	hall_of_fame.clear()
	var fame_data = data.get("hall_of_fame", [])
	for ad in fame_data:
		var award = Award.new()
		award.id = ad.get("id", "")
		award.title = ad.get("title", "")
		award.description = ad.get("description", "")
		award.year = int(ad.get("year", 0))
		award.value = ad.get("value", "")
		award.reputation_bonus = float(ad.get("reputation_bonus", 0.0))
		award.tier = int(ad.get("tier", 0))
		hall_of_fame.append(award)

	var stats = data.get("yearly_stats", {})
	for key in yearly_stats.keys():
		if stats.has(key):
			yearly_stats[key] = stats[key]

## Get awards for a specific year
func get_awards_for_year(year: int) -> Array:
	return hall_of_fame.filter(func(a): return a.year == year)

## Get the total number of gold/silver/bronze awards
func get_award_counts() -> Dictionary:
	var counts = {"gold": 0, "silver": 0, "bronze": 0}
	for award in hall_of_fame:
		match award.tier:
			2: counts.gold += 1
			1: counts.silver += 1
			0: counts.bronze += 1
	return counts
