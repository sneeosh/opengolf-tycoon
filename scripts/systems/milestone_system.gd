extends RefCounted
class_name MilestoneSystem
## MilestoneSystem - Tracks per-course milestone achievements
##
## Milestones provide goals and feedback to the player. Each milestone
## has an ID, description, check function, and reward. Milestones are
## checked at end-of-day and on key events.

enum Category { COURSE, ECONOMY, GOLFERS, RECORDS, REPUTATION }

class Milestone:
	var id: String
	var title: String
	var description: String
	var category: int  # Category enum
	var reward_money: int = 0
	var reward_reputation: float = 0.0
	var is_completed: bool = false
	var completion_day: int = 0

	func _init(p_id: String, p_title: String, p_desc: String, p_cat: int, p_money: int = 0, p_rep: float = 0.0) -> void:
		id = p_id
		title = p_title
		description = p_desc
		category = p_cat
		reward_money = p_money
		reward_reputation = p_rep

## All milestone definitions
static func get_all_milestones() -> Array:
	return [
		# Course milestones
		Milestone.new("first_hole", "First Tee", "Build your first hole", Category.COURSE, 500, 2.0),
		Milestone.new("three_holes", "Front Three", "Build 3 holes", Category.COURSE, 1000, 3.0),
		Milestone.new("nine_holes", "The Front Nine", "Build 9 holes", Category.COURSE, 5000, 10.0),
		Milestone.new("eighteen_holes", "Full Course", "Build 18 holes", Category.COURSE, 15000, 20.0),
		Milestone.new("par_3_course", "Short Game Special", "Build a course with all par 3s", Category.COURSE, 2000, 5.0),
		Milestone.new("first_building", "Amenities", "Place your first building", Category.COURSE, 500, 1.0),
		Milestone.new("five_buildings", "Full Service", "Place 5 buildings", Category.COURSE, 2000, 5.0),

		# Economy milestones
		Milestone.new("first_profit", "In the Black", "Finish a day with positive profit", Category.ECONOMY, 0, 2.0),
		Milestone.new("earn_10k", "Making Money", "Accumulate $10,000 total revenue in a day", Category.ECONOMY, 1000, 3.0),
		Milestone.new("earn_50k", "Big Business", "Accumulate $50,000 total revenue in a day", Category.ECONOMY, 5000, 5.0),
		Milestone.new("survive_30_days", "One Month", "Survive 30 days", Category.ECONOMY, 3000, 5.0),
		Milestone.new("survive_100_days", "Seasoned Operator", "Survive 100 days", Category.ECONOMY, 10000, 10.0),
		Milestone.new("no_debt", "Debt Free", "Reach $100,000 with no loans", Category.ECONOMY, 0, 5.0),

		# Golfer milestones
		Milestone.new("first_golfer", "Open for Business", "Have your first golfer play a round", Category.GOLFERS, 0, 1.0),
		Milestone.new("serve_50", "Getting Popular", "Serve 50 golfers in a single day", Category.GOLFERS, 2000, 5.0),
		Milestone.new("pro_visit", "Pro Tour Stop", "Attract a Pro-tier golfer", Category.GOLFERS, 3000, 8.0),
		Milestone.new("full_house", "Tee Time Rush", "Have maximum concurrent golfers on course", Category.GOLFERS, 1000, 3.0),

		# Records milestones
		Milestone.new("first_hio", "Ace!", "Witness a hole-in-one", Category.RECORDS, 2000, 5.0),
		Milestone.new("five_hio", "Ace Factory", "Witness 5 holes-in-one", Category.RECORDS, 5000, 8.0),
		Milestone.new("first_eagle", "Eagle Eye", "Witness an eagle", Category.RECORDS, 1000, 3.0),

		# Reputation milestones
		Milestone.new("rep_25", "Getting Noticed", "Reach 25 reputation", Category.REPUTATION, 0, 0.0),
		Milestone.new("rep_50", "Established Course", "Reach 50 reputation", Category.REPUTATION, 2000, 0.0),
		Milestone.new("rep_75", "Prestigious Club", "Reach 75 reputation", Category.REPUTATION, 5000, 0.0),
		Milestone.new("rep_100", "Legendary Course", "Reach 100 reputation", Category.REPUTATION, 10000, 0.0),
		Milestone.new("four_star", "Four Stars", "Achieve a 4-star course rating", Category.REPUTATION, 3000, 5.0),
		Milestone.new("five_star", "Five Stars", "Achieve a 5-star course rating", Category.REPUTATION, 10000, 10.0),
	]

static func get_category_name(category: int) -> String:
	match category:
		Category.COURSE: return "Course Design"
		Category.ECONOMY: return "Economy"
		Category.GOLFERS: return "Golfers"
		Category.RECORDS: return "Records"
		Category.REPUTATION: return "Reputation"
	return "Other"

static func get_category_color(category: int) -> Color:
	match category:
		Category.COURSE: return Color(0.4, 0.8, 0.4)
		Category.ECONOMY: return Color(0.9, 0.85, 0.3)
		Category.GOLFERS: return Color(0.4, 0.7, 1.0)
		Category.RECORDS: return Color(1.0, 0.6, 0.2)
		Category.REPUTATION: return Color(0.9, 0.3, 0.9)
	return Color.WHITE
