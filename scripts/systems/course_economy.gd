extends RefCounted
class_name CourseEconomy
## One price reference shared by ratings, demand and financial guidance.
static func fair_round_price(reputation: float, holes: int, day: int, theme: int) -> float:
	var size_factor := clampf(holes / 18.0, .15, 1.0)
	return maxf(reputation * 2.0, 20.0) * size_factor * SeasonSystem.get_fee_tolerance(day, theme)

static func price_demand(fee_per_hole: int, holes: int, fair_price: float) -> float:
	var ratio := fee_per_hole * maxi(holes, 1) / maxf(fair_price, 1.0)
	# Doubling an already-fair fee attracts one quarter as many potential groups.
	# Avoid a demand floor that would make extreme overpricing profitable.
	return minf(1.25, 1.0 / pow(maxf(ratio, .1), 2.0))
