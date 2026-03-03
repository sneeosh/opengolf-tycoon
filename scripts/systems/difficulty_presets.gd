extends RefCounted
class_name DifficultyPresets
## DifficultyPresets - Easy / Normal / Hard game difficulty modifiers
##
## Adjusts starting money, golfer spawn rates, maintenance costs, reputation
## decay, and bankruptcy threshold to create distinct difficulty experiences.

enum Preset { EASY, NORMAL, HARD }

## Returns a dictionary of gameplay modifiers for the given preset
static func get_modifiers(preset: int) -> Dictionary:
	match preset:
		Preset.EASY:
			return {
				"name": "Easy",
				"description": "Relaxed pace. More starting money, forgiving costs, slower reputation decay.",
				"starting_money": 40000,
				"maintenance_multiplier": 0.8,
				"spawn_rate_multiplier": 1.2,
				"reputation_decay_multiplier": 0.5,
				"bankruptcy_threshold": -5000,
				"green_fee_sensitivity": 0.7,  # Overpricing penalized less harshly
				"building_cost_multiplier": 0.8,
			}
		Preset.HARD:
			return {
				"name": "Hard",
				"description": "Tight budget, costly upkeep, demanding golfers. For experienced players.",
				"starting_money": 15000,
				"maintenance_multiplier": 1.3,
				"spawn_rate_multiplier": 0.8,
				"reputation_decay_multiplier": 2.0,
				"bankruptcy_threshold": 0,
				"green_fee_sensitivity": 1.5,  # Overpricing penalized more harshly
				"building_cost_multiplier": 1.2,
			}
		_:  # NORMAL
			return {
				"name": "Normal",
				"description": "Balanced challenge. The standard experience.",
				"starting_money": 25000,
				"maintenance_multiplier": 1.0,
				"spawn_rate_multiplier": 1.0,
				"reputation_decay_multiplier": 1.0,
				"bankruptcy_threshold": -1000,
				"green_fee_sensitivity": 1.0,
				"building_cost_multiplier": 1.0,
			}

## Get all preset types for iteration
static func get_all_presets() -> Array:
	return [Preset.EASY, Preset.NORMAL, Preset.HARD]

## Convert preset int to display name
static func get_preset_name(preset: int) -> String:
	var mods := get_modifiers(preset)
	return mods.get("name", "Normal")

## Convert string to preset enum
static func from_string(name: String) -> int:
	match name.to_lower():
		"easy": return Preset.EASY
		"hard": return Preset.HARD
		_: return Preset.NORMAL

## Convert preset enum to string (for save/load)
static func to_string_name(preset: int) -> String:
	match preset:
		Preset.EASY: return "easy"
		Preset.HARD: return "hard"
		_: return "normal"
