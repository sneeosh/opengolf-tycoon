extends Node
class_name StaffManager
## StaffManager - Manages staff hiring/firing and course condition
##
## 4 staff types with skill levels. Staff maintain course condition
## which degrades daily without sufficient maintenance coverage.

enum StaffType { GROUNDSKEEPER, MARSHAL, CART_OPERATOR, PRO_SHOP }

const STAFF_DATA = {
	StaffType.GROUNDSKEEPER: {
		"name": "Groundskeeper",
		"base_salary": 80,  # Per day
		"description": "Maintains fairways, greens, and bunkers",
	},
	StaffType.MARSHAL: {
		"name": "Course Marshal",
		"base_salary": 50,
		"description": "Keeps pace of play and handles golfer issues",
	},
	StaffType.CART_OPERATOR: {
		"name": "Cart Operator",
		"base_salary": 40,
		"description": "Manages golf cart fleet and path maintenance",
	},
	StaffType.PRO_SHOP: {
		"name": "Pro Shop Staff",
		"base_salary": 60,
		"description": "Runs the pro shop and provides lessons",
	},
}

signal staff_changed()
signal condition_changed(new_condition: float)

## Hired staff: Array of {type: StaffType, skill: float (0-1), salary: int}
var hired_staff: Array = []

## Course condition: 0.0 (terrible) to 1.0 (pristine)
var course_condition: float = 1.0

## Condition affects gameplay
const CONDITION_DEGRADATION_BASE: float = 0.05  # Daily degradation without staff
const CONDITION_RESTORATION_PER_GROUNDSKEEPER: float = 0.08

func get_daily_payroll() -> int:
	"""Calculate total daily staff salary."""
	var total: int = 0
	for staff in hired_staff:
		total += staff.salary
	return total

func hire_staff(staff_type: int) -> bool:
	"""Hire a new staff member of the given type."""
	var data = STAFF_DATA.get(staff_type, {})
	if data.is_empty():
		return false

	var salary = data.base_salary
	var skill = randf_range(0.3, 0.7)  # Random starting skill

	hired_staff.append({
		"type": staff_type,
		"skill": skill,
		"salary": salary,
		"name": _generate_staff_name(),
	})

	staff_changed.emit()
	EventBus.notify("Hired %s ($%d/day)" % [data.name, salary], "success")
	return true

func fire_staff(index: int) -> bool:
	"""Fire a staff member by index."""
	if index < 0 or index >= hired_staff.size():
		return false

	var staff = hired_staff[index]
	var data = STAFF_DATA.get(staff.type, {})
	var name_str = data.get("name", "Staff")
	hired_staff.remove_at(index)
	staff_changed.emit()
	EventBus.notify("Fired %s" % name_str, "info")
	return true

func get_staff_count_by_type(staff_type: int) -> int:
	var count = 0
	for staff in hired_staff:
		if staff.type == staff_type:
			count += 1
	return count

func process_daily_maintenance() -> void:
	"""Called at end of day to update course condition and pay staff."""
	# Count groundskeepers
	var groundskeeper_count = get_staff_count_by_type(StaffType.GROUNDSKEEPER)

	# Calculate condition change
	var degradation = CONDITION_DEGRADATION_BASE
	var restoration = groundskeeper_count * CONDITION_RESTORATION_PER_GROUNDSKEEPER

	# Net condition change
	var delta = restoration - degradation
	course_condition = clampf(course_condition + delta, 0.0, 1.0)
	condition_changed.emit(course_condition)

func get_condition_description() -> String:
	if course_condition >= 0.9:
		return "Pristine"
	elif course_condition >= 0.7:
		return "Good"
	elif course_condition >= 0.5:
		return "Fair"
	elif course_condition >= 0.3:
		return "Poor"
	else:
		return "Terrible"

func get_pace_modifier() -> float:
	"""Marshal count affects pace of play satisfaction."""
	var marshal_count = get_staff_count_by_type(StaffType.MARSHAL)
	# Each marshal improves pace rating up to a cap
	return minf(1.0, 0.6 + marshal_count * 0.15)

func get_cart_modifier() -> float:
	"""Cart operators affect golfer walk speed satisfaction."""
	var cart_count = get_staff_count_by_type(StaffType.CART_OPERATOR)
	return minf(1.0, 0.7 + cart_count * 0.15)

func get_pro_shop_revenue_bonus() -> float:
	"""Pro shop staff add revenue bonus per golfer."""
	var pro_count = get_staff_count_by_type(StaffType.PRO_SHOP)
	return pro_count * 5.0  # $5 extra revenue per golfer per pro shop staff

static func _generate_staff_name() -> String:
	var first_names = ["Alex", "Sam", "Jordan", "Pat", "Chris", "Morgan", "Casey", "Riley", "Quinn", "Drew"]
	var last_initials = ["A", "B", "C", "D", "E", "F", "G", "H", "J", "K", "L", "M", "N", "P", "R", "S", "T", "W"]
	return first_names[randi() % first_names.size()] + " " + last_initials[randi() % last_initials.size()] + "."

## Serialization
func serialize() -> Dictionary:
	var staff_arr: Array = []
	for s in hired_staff:
		staff_arr.append({
			"type": s.type,
			"skill": s.skill,
			"salary": s.salary,
			"name": s.get("name", "Staff"),
		})
	return {
		"hired_staff": staff_arr,
		"course_condition": course_condition,
	}

func deserialize(data: Dictionary) -> void:
	hired_staff.clear()
	course_condition = data.get("course_condition", 1.0)
	for s in data.get("hired_staff", []):
		hired_staff.append({
			"type": int(s.type),
			"skill": float(s.skill),
			"salary": int(s.salary),
			"name": s.get("name", "Staff"),
		})
	staff_changed.emit()
