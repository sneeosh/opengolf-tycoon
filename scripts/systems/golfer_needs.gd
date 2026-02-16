extends RefCounted
class_name GolferNeeds
## GolferNeeds - Tracks physiological and psychological needs for a golfer
##
## Five need dimensions, each 0.0 (depleted) to 1.0 (fully satisfied):
##   energy    — physical tiredness from walking/playing
##   attitude  — general positivity, affected by score and course quality
##   thirst    — hydration level, decays steadily
##   hunger    — satiation, decays slowly over a round
##   bathroom  — comfort level, decays steadily
##
## Needs decay each hole and are replenished by buildings.
## Low needs penalize mood; very low needs trigger thought bubbles.

enum Need {
	ENERGY,
	ATTITUDE,
	THIRST,
	HUNGER,
	BATHROOM,
}

## Current need levels (1.0 = fully satisfied)
var energy: float = 1.0
var attitude: float = 1.0
var thirst: float = 1.0
var hunger: float = 1.0
var bathroom: float = 1.0

## Per-hole base decay rates (before randomness)
## These represent an "average" 18-hole round where needs deplete naturally.
const DECAY_RATES: Dictionary = {
	Need.ENERGY: 0.07,
	Need.ATTITUDE: 0.02,
	Need.THIRST: 0.06,
	Need.HUNGER: 0.04,
	Need.BATHROOM: 0.055,
}

## Threshold below which a need starts hurting mood
const LOW_THRESHOLD: float = 0.35
## Threshold below which a need causes thought bubbles
const CRITICAL_THRESHOLD: float = 0.18

## How much each building type replenishes each need
## Key: building_type string → Dictionary of Need → amount
const BUILDING_EFFECTS: Dictionary = {
	"clubhouse": {
		Need.ENERGY: 1.0,
		Need.ATTITUDE: 1.0,
		Need.THIRST: 1.0,
		Need.HUNGER: 1.0,
		Need.BATHROOM: 1.0,
	},
	"restroom": {
		Need.BATHROOM: 1.0,
	},
	"snack_bar": {
		Need.HUNGER: 0.5,
		Need.THIRST: 0.3,
	},
	"restaurant": {
		Need.HUNGER: 0.8,
		Need.THIRST: 0.6,
		Need.ATTITUDE: 0.15,
	},
	"bench": {
		Need.ENERGY: 0.35,
		Need.ATTITUDE: 0.1,
	},
	"drink_cart": {
		Need.THIRST: 0.7,
	},
}

## ──────────────────────────────────────────────
## Lifecycle
## ──────────────────────────────────────────────

## Apply per-hole decay with slight randomness.
## patience_factor 0..1 — patient golfers tolerate needs better (slightly slower decay).
func decay_per_hole(patience: float = 0.5) -> void:
	var patience_factor = lerpf(1.1, 0.9, patience)  # impatient decays faster
	for need_type in DECAY_RATES:
		var base = DECAY_RATES[need_type]
		var amount = base * patience_factor * randf_range(0.8, 1.2)
		_modify_need(need_type, -amount)

## Apply weather-based extra decay.  Hotter/sunnier = more thirst/energy loss.
func apply_weather_effect(weather_type: int) -> void:
	# WeatherSystem.WeatherType: 0=SUNNY,1=PARTLY_CLOUDY,2=CLOUDY,3=LIGHT_RAIN,4=RAIN,5=HEAVY_RAIN
	match weather_type:
		0:  # SUNNY — extra thirst and energy drain
			_modify_need(Need.THIRST, -0.03)
			_modify_need(Need.ENERGY, -0.02)
		3, 4, 5:  # Rain — attitude hit
			_modify_need(Need.ATTITUDE, -0.04)

## ──────────────────────────────────────────────
## Building interaction
## ──────────────────────────────────────────────

## Apply the replenishment effects of a building.
## Returns a Dictionary { Need → amount_restored } of actual changes.
func apply_building(building_type: String) -> Dictionary:
	var effects = BUILDING_EFFECTS.get(building_type, {})
	var restored: Dictionary = {}
	for need_type in effects:
		var before = get_need(need_type)
		_set_need(need_type, before + effects[need_type])
		var delta = get_need(need_type) - before
		if delta > 0.01:
			restored[need_type] = delta
	return restored

## Return how strongly the golfer *wants* to visit this building type.
## 0.0 = no interest, 1.0 = desperate.  Used to scale revenue likelihood.
func get_building_desire(building_type: String) -> float:
	var effects = BUILDING_EFFECTS.get(building_type, {})
	if effects.is_empty():
		return 0.0
	var max_desire: float = 0.0
	for need_type in effects:
		var deficit = 1.0 - get_need(need_type)
		max_desire = max(max_desire, deficit)
	return max_desire

## ──────────────────────────────────────────────
## Mood impact
## ──────────────────────────────────────────────

## Total mood penalty from unmet needs.  Returns a negative float (or 0.0).
## Called at round end (or per-hole) to adjust golfer mood.
func get_mood_penalty() -> float:
	var penalty: float = 0.0
	var needs_array = [energy, attitude, thirst, hunger, bathroom]
	for value in needs_array:
		if value < LOW_THRESHOLD:
			# Quadratic penalty: gets much worse as need approaches 0
			var deficit = LOW_THRESHOLD - value
			penalty -= deficit * deficit * 2.5
	return penalty

## Average satisfaction across all needs (0.0–1.0).
func get_overall_satisfaction() -> float:
	return (energy + attitude + thirst + hunger + bathroom) / 5.0

## Return the most critical (lowest) need, or null if all are fine.
func get_most_critical_need() -> int:
	var lowest_val: float = 1.0
	var lowest_need: int = Need.ENERGY
	var needs_map = _get_needs_map()
	for need_type in needs_map:
		if needs_map[need_type] < lowest_val:
			lowest_val = needs_map[need_type]
			lowest_need = need_type
	return lowest_need

## Return the value of the most critical need.
func get_lowest_need_value() -> float:
	return min(energy, min(attitude, min(thirst, min(hunger, bathroom))))

## ──────────────────────────────────────────────
## Attitude-specific modifiers (score reactions)
## ──────────────────────────────────────────────

## Adjust attitude based on score result.
func adjust_attitude_for_score(score_diff: int) -> void:
	if score_diff <= -2:
		_modify_need(Need.ATTITUDE, 0.15)
	elif score_diff == -1:
		_modify_need(Need.ATTITUDE, 0.08)
	elif score_diff == 0:
		_modify_need(Need.ATTITUDE, 0.03)
	elif score_diff == 1:
		_modify_need(Need.ATTITUDE, -0.05)
	else:
		_modify_need(Need.ATTITUDE, -0.10)

## ──────────────────────────────────────────────
## Accessors
## ──────────────────────────────────────────────

func get_need(need_type: int) -> float:
	match need_type:
		Need.ENERGY: return energy
		Need.ATTITUDE: return attitude
		Need.THIRST: return thirst
		Need.HUNGER: return hunger
		Need.BATHROOM: return bathroom
	return 1.0

static func get_need_name(need_type: int) -> String:
	match need_type:
		Need.ENERGY: return "Energy"
		Need.ATTITUDE: return "Attitude"
		Need.THIRST: return "Thirst"
		Need.HUNGER: return "Hunger"
		Need.BATHROOM: return "Bathroom"
	return "Unknown"

## ──────────────────────────────────────────────
## Serialization
## ──────────────────────────────────────────────

func serialize() -> Dictionary:
	return {
		"energy": energy,
		"attitude": attitude,
		"thirst": thirst,
		"hunger": hunger,
		"bathroom": bathroom,
	}

func deserialize(data: Dictionary) -> void:
	energy = data.get("energy", 1.0)
	attitude = data.get("attitude", 1.0)
	thirst = data.get("thirst", 1.0)
	hunger = data.get("hunger", 1.0)
	bathroom = data.get("bathroom", 1.0)

## ──────────────────────────────────────────────
## Internal helpers
## ──────────────────────────────────────────────

func _modify_need(need_type: int, amount: float) -> void:
	_set_need(need_type, get_need(need_type) + amount)

func _set_need(need_type: int, value: float) -> void:
	value = clampf(value, 0.0, 1.0)
	match need_type:
		Need.ENERGY: energy = value
		Need.ATTITUDE: attitude = value
		Need.THIRST: thirst = value
		Need.HUNGER: hunger = value
		Need.BATHROOM: bathroom = value

func _get_needs_map() -> Dictionary:
	return {
		Need.ENERGY: energy,
		Need.ATTITUDE: attitude,
		Need.THIRST: thirst,
		Need.HUNGER: hunger,
		Need.BATHROOM: bathroom,
	}
