extends RefCounted
class_name CourseAdvisor
## Evidence-based next steps. Every location points to the hole that was inspected.
static func review(grid, course, entities, rating: Dictionary, stats) -> Array[Dictionary]:
	var advice: Array[Dictionary] = []
	if not course or course.get_open_holes().is_empty():
		return [{"title":"Create your first hole", "detail":"Place a tee and a green, then open the hole to welcome golfers.", "action":"build"}]
	if stats and stats.operating_costs > 0 and stats.golfers_arrived > stats.golfers_served:
		advice.append({"title":"%d guests did not finish" % (stats.golfers_arrived-stats.golfers_served),"detail":"Completed-visit satisfaction excludes these guests. Reduce bookings and inspect traffic delays before expanding.","action":"finance"})
	for item in FeedbackManager.get_hotspots():
		advice.append({"title":"%s: hole %d (%d guests)" % [FeedbackManager.incident_title(item.trigger),item.hole,item.count],"detail":FeedbackManager.incident_guidance(item.trigger),"position":Vector2i(item.x,item.y),"action":"locate"})
	var worst_ratio := 1.0
	var worst_hole = null
	for hole in course.get_open_holes():
		if grid.get_tile(hole.tee_position) != TerrainTypes.Type.TEE_BOX or grid.get_tile(hole.hole_position) != TerrainTypes.Type.GREEN:
			advice.append({"title":"Finish hole %d" % hole.hole_number, "detail":"Its tee or cup is no longer on the correct surface. Restore a tee box and putting green.", "position":hole.hole_position, "action":"locate"})
			break
		var premium := 0
		var samples := 0
		for point in TerrainBrush.centers(hole.tee_position, hole.green_position):
			for offset in TerrainBrush.offsets(3):
				var tile: Vector2i = point + offset
				if not grid.is_valid_position(tile): continue
				samples += 1
				if grid.get_tile(tile) in [TerrainTypes.Type.FAIRWAY,TerrainTypes.Type.GREEN,TerrainTypes.Type.TEE_BOX]: premium += 1
		var ratio := float(premium) / maxi(samples, 1)
		if ratio < worst_ratio:
			worst_ratio = ratio
			worst_hole = hole
	if worst_hole and worst_ratio < .65:
		advice.append({"title":"Improve hole %d's landing area" % worst_hole.hole_number, "detail":"Only %d%% of its direct tee-to-green corridor is short turf. Widen landing areas; retain hazards where they create a deliberate choice." % int(worst_ratio*100), "position":worst_hole.tee_position, "action":"locate"})
	if rating.get("value",5.0) < 2.8:
		advice.append({"title":"Review your green fee", "detail":"Golfers rate value %.1f/5. Lower the fee or improve the course before charging more." % rating.get("value",0.0), "action":"finance"})
	var unserved = null
	for hole in course.get_open_holes():
		var has_food := false
		if entities:
			for building in entities.get_all_buildings():
				var service: String = building.building_data.get("needs_service", building.building_type)
				if service not in ["snack_bar","restaurant","clubhouse"]: continue
				var reach: float = building.building_data.get("effect_radius",5)
				if Vector2(building.grid_position).distance_to(Vector2(hole.tee_position)) <= reach: has_food = true
		if not has_food and hole.hole_number >= 4:
			unserved = hole
			break
	if unserved:
		advice.append({"title":"Add a refreshment stop near hole %d" % unserved.hole_number, "detail":"There is no food service within reach of this tee. A nearby snack bar or coffee house can restore hunger and earn revenue.", "position":unserved.tee_position, "action":"locate"})
	if stats and stats.operating_costs > 0 and stats.get_profit() < 0:
		advice.append({"title":"Close the operating gap", "detail":"Today's operations lost $%d before construction and milestones. Review staffing, amenities and fees against actual demand." % -stats.get_profit(), "action":"finance"})
	if rating.get("aesthetics",5.0) < 2.5:
		advice.append({"title":"Give the course a sense of place", "detail":"Group trees, flowers and seating near tees and greens. Mix decoration types instead of repeating one item everywhere.", "action":"garden"})
	if advice.is_empty():
		advice.append({"title":"Watch a round before expanding", "detail":"The basic checks look good. Follow golfers, inspect hole scores and use the next day's operating profit to decide what to build.", "action":"observe"})
	return advice.slice(0,4)
