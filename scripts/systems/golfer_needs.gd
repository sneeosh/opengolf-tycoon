extends RefCounted
class_name GolferNeeds
## GolferNeeds - Explicit needs tracking for golfer satisfaction
##
## Tracks individual golfer needs that decay over time and are satisfied by
## buildings, course conditions, and gameplay events. Each need ranges from
## 0.0 (desperate) to 1.0 (fully satisfied).
##
## Needs feed into mood adjustments and thought bubble triggers, replacing
## the implicit satisfaction checks scattered across golfer.gd.

## Need levels (0.0 = desperate, 1.0 = fully satisfied)
var energy: float = 1.0       # Decreases as golfer walks/plays, restored by benches
var comfort: float = 1.0      # Decreases over time, restored by restrooms
var hunger: float = 1.0       # Decreases over time, restored by snack bars/restaurants
var pace: float = 1.0         # Decreases when waiting, affected by patience trait

## Golfer traits that modify need decay rates
var patience: float = 0.5     # 0.0 = impatient, 1.0 = very patient
var golfer_tier: int = 1      # GolferTier.Tier value — higher tiers are more demanding

## Track which needs have triggered feedback (prevent spam)
var _triggered_low_energy: bool = false
var _triggered_low_comfort: bool = false
var _triggered_low_hunger: bool = false
var _triggered_low_pace: bool = false

## Thresholds for triggering feedback
const LOW_NEED_THRESHOLD: float = 0.3      # Below this, golfer may complain
const CRITICAL_NEED_THRESHOLD: float = 0.15 # Below this, mood penalty applied

## Decay rates per hole played (base values, modified by tier)
const ENERGY_DECAY_PER_HOLE: float = 0.08    # ~12 holes before energy is low
const COMFORT_DECAY_PER_HOLE: float = 0.06   # ~16 holes before comfort is low
const HUNGER_DECAY_PER_HOLE: float = 0.05    # ~20 holes before hunger is low

## Decay rate for pace (per second of waiting)
const PACE_DECAY_PER_WAIT_SECOND: float = 0.02

## Satisfaction amounts from buildings
const BENCH_ENERGY_RESTORE: float = 0.20
const RESTROOM_COMFORT_RESTORE: float = 0.35
const SNACK_BAR_HUNGER_RESTORE: float = 0.30
const RESTAURANT_HUNGER_RESTORE: float = 0.50
const CLUBHOUSE_ALL_RESTORE: float = 0.15     # Small boost to all needs

## Initialize needs for a golfer based on their tier and personality
func setup(tier: int, patience_trait: float) -> void:
	golfer_tier = tier
	patience = patience_trait
	# All needs start full
	energy = 1.0
	comfort = 1.0
	hunger = 1.0
	pace = 1.0
	_triggered_low_energy = false
	_triggered_low_comfort = false
	_triggered_low_hunger = false
	_triggered_low_pace = false

## Called after each hole is completed — decay needs based on play
func on_hole_completed() -> void:
	var tier_modifier = _get_tier_decay_modifier()
	energy = maxf(energy - ENERGY_DECAY_PER_HOLE * tier_modifier, 0.0)
	comfort = maxf(comfort - COMFORT_DECAY_PER_HOLE * tier_modifier, 0.0)
	hunger = maxf(hunger - HUNGER_DECAY_PER_HOLE * tier_modifier, 0.0)

## Called when golfer is waiting (not their turn) — decay pace satisfaction
func on_waiting(wait_seconds: float) -> void:
	# Impatient golfers (low patience) lose pace satisfaction faster
	var patience_modifier = 1.0 + (1.0 - patience) * 1.5  # Range: 1.0 (patient) to 2.5 (impatient)
	var decay = wait_seconds * PACE_DECAY_PER_WAIT_SECOND * patience_modifier
	pace = maxf(pace - decay, 0.0)

## Apply building effect to needs based on building type
## Returns the mood boost amount (0.0 if no mood change)
func apply_building_effect(building_type: String) -> float:
	var mood_boost: float = 0.0

	match building_type:
		"bench":
			var old_energy = energy
			energy = minf(energy + BENCH_ENERGY_RESTORE, 1.0)
			if energy > old_energy:
				mood_boost = 0.02
		"restroom":
			var old_comfort = comfort
			comfort = minf(comfort + RESTROOM_COMFORT_RESTORE, 1.0)
			if comfort > old_comfort:
				mood_boost = 0.05
		"snack_bar":
			var old_hunger = hunger
			hunger = minf(hunger + SNACK_BAR_HUNGER_RESTORE, 1.0)
			if hunger > old_hunger:
				mood_boost = 0.03
		"restaurant":
			var old_hunger = hunger
			hunger = minf(hunger + RESTAURANT_HUNGER_RESTORE, 1.0)
			if hunger > old_hunger:
				mood_boost = 0.05
		"clubhouse":
			energy = minf(energy + CLUBHOUSE_ALL_RESTORE, 1.0)
			comfort = minf(comfort + CLUBHOUSE_ALL_RESTORE, 1.0)
			hunger = minf(hunger + CLUBHOUSE_ALL_RESTORE, 1.0)
			mood_boost = 0.03

	return mood_boost

## Get the overall needs satisfaction (0.0 to 1.0)
## Weighted average — pace and energy matter most
func get_overall_satisfaction() -> float:
	return (
		energy * 0.30 +
		comfort * 0.20 +
		hunger * 0.20 +
		pace * 0.30
	)

## Get mood penalty from unmet needs (negative value to subtract from mood)
## Only applies when needs are critically low
func get_mood_penalty() -> float:
	var penalty: float = 0.0
	if energy < CRITICAL_NEED_THRESHOLD:
		penalty -= 0.05
	if comfort < CRITICAL_NEED_THRESHOLD:
		penalty -= 0.05
	if hunger < CRITICAL_NEED_THRESHOLD:
		penalty -= 0.03
	if pace < CRITICAL_NEED_THRESHOLD:
		penalty -= 0.08  # Pace frustration is the strongest penalty
	return penalty

## Check which needs are low and should trigger feedback
## Returns an array of trigger type integers (FeedbackTriggers.TriggerType)
func check_need_triggers() -> Array:
	var triggers: Array = []

	if energy < LOW_NEED_THRESHOLD and not _triggered_low_energy:
		triggers.append(FeedbackTriggers.TriggerType.TIRED)
		_triggered_low_energy = true

	if comfort < LOW_NEED_THRESHOLD and not _triggered_low_comfort:
		triggers.append(FeedbackTriggers.TriggerType.NEEDS_RESTROOM)
		_triggered_low_comfort = true

	if hunger < LOW_NEED_THRESHOLD and not _triggered_low_hunger:
		triggers.append(FeedbackTriggers.TriggerType.HUNGRY)
		_triggered_low_hunger = true

	if pace < LOW_NEED_THRESHOLD and not _triggered_low_pace:
		triggers.append(FeedbackTriggers.TriggerType.SLOW_PACE)
		_triggered_low_pace = true

	return triggers

## Get the tier-based decay modifier
## Higher tiers have slightly faster decay (more demanding)
func _get_tier_decay_modifier() -> float:
	match golfer_tier:
		0:  # BEGINNER
			return 0.8   # Beginners are more resilient
		1:  # CASUAL
			return 1.0
		2:  # SERIOUS
			return 1.1
		3:  # PRO
			return 1.3   # Pros are more demanding
	return 1.0

## Serialize for debug/display
func to_dict() -> Dictionary:
	return {
		"energy": snappedf(energy, 0.01),
		"comfort": snappedf(comfort, 0.01),
		"hunger": snappedf(hunger, 0.01),
		"pace": snappedf(pace, 0.01),
		"overall": snappedf(get_overall_satisfaction(), 0.01),
	}
