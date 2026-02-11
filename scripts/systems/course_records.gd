extends RefCounted
class_name CourseRecords
## CourseRecords - Tracks course records and notable events
##
## Records tracked:
## - Lowest round (course record)
## - Total hole-in-ones
## - Best score per hole

## Structure for a record entry
class RecordEntry:
	var golfer_name: String = ""
	var value: int = 0
	var date_day: int = 0
	var hole_number: int = -1  # For hole-specific records

	func _init(name: String = "", val: int = 0, day: int = 0, hole: int = -1):
		golfer_name = name
		value = val
		date_day = day
		hole_number = hole

	func to_dict() -> Dictionary:
		return {
			"golfer_name": golfer_name,
			"value": value,
			"date_day": date_day,
			"hole_number": hole_number,
		}

	static func from_dict(data: Dictionary) -> RecordEntry:
		return RecordEntry.new(
			data.get("golfer_name", ""),
			int(data.get("value", 0)),
			int(data.get("date_day", 0)),
			int(data.get("hole_number", -1))
		)

## Serialize records dictionary for saving
static func serialize_records(records: Dictionary) -> Dictionary:
	var data: Dictionary = {
		"total_hole_in_ones": records.get("total_hole_in_ones", 0),
		"lowest_round": null,
		"hole_in_ones": [],
		"best_per_hole": {},
	}

	if records.has("lowest_round") and records.lowest_round != null:
		data.lowest_round = records.lowest_round.to_dict()

	if records.has("hole_in_ones"):
		for entry in records.hole_in_ones:
			data.hole_in_ones.append(entry.to_dict())

	if records.has("best_per_hole"):
		for hole_num in records.best_per_hole:
			data.best_per_hole[str(hole_num)] = records.best_per_hole[hole_num].to_dict()

	return data

## Deserialize records dictionary from save data
static func deserialize_records(data: Dictionary) -> Dictionary:
	var records: Dictionary = {
		"total_hole_in_ones": data.get("total_hole_in_ones", 0),
		"lowest_round": null,
		"hole_in_ones": [],
		"best_per_hole": {},
	}

	if data.has("lowest_round") and data.lowest_round != null:
		records.lowest_round = RecordEntry.from_dict(data.lowest_round)

	if data.has("hole_in_ones"):
		for entry_data in data.hole_in_ones:
			records.hole_in_ones.append(RecordEntry.from_dict(entry_data))

	if data.has("best_per_hole"):
		for hole_num_str in data.best_per_hole:
			var hole_num = int(hole_num_str)
			records.best_per_hole[hole_num] = RecordEntry.from_dict(data.best_per_hole[hole_num_str])

	return records

## Create an empty records dictionary
static func create_empty_records() -> Dictionary:
	return {
		"total_hole_in_ones": 0,
		"lowest_round": null,
		"hole_in_ones": [],
		"best_per_hole": {},
	}
