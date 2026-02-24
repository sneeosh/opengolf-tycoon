extends GutTest
## Tests for GolferNeeds - Golfer needs tracking, decay, restoration, and satisfaction


# --- Helpers ---

func _make_needs(overrides: Dictionary = {}) -> GolferNeeds:
	var n = GolferNeeds.new()
	n.setup(
		overrides.get("tier", 1),        # CASUAL by default
		overrides.get("patience", 0.5)   # moderate patience
	)
	if overrides.has("energy"):
		n.energy = overrides["energy"]
	if overrides.has("comfort"):
		n.comfort = overrides["comfort"]
	if overrides.has("hunger"):
		n.hunger = overrides["hunger"]
	if overrides.has("pace"):
		n.pace = overrides["pace"]
	return n


# --- Section 1: Initialization and Setup ---

func test_default_needs_all_full() -> void:
	var n = GolferNeeds.new()
	n.setup(1, 0.5)
	assert_eq(n.energy, 1.0, "Energy should start at 1.0")
	assert_eq(n.comfort, 1.0, "Comfort should start at 1.0")
	assert_eq(n.hunger, 1.0, "Hunger should start at 1.0")
	assert_eq(n.pace, 1.0, "Pace should start at 1.0")

func test_setup_resets_all_needs() -> void:
	var n = _make_needs()
	n.energy = 0.3
	n.comfort = 0.2
	n.hunger = 0.1
	n.pace = 0.0
	n.setup(1, 0.5)
	assert_eq(n.energy, 1.0, "Energy should reset to 1.0 after setup")
	assert_eq(n.comfort, 1.0, "Comfort should reset to 1.0 after setup")
	assert_eq(n.hunger, 1.0, "Hunger should reset to 1.0 after setup")
	assert_eq(n.pace, 1.0, "Pace should reset to 1.0 after setup")

func test_setup_stores_tier() -> void:
	var n = GolferNeeds.new()
	n.setup(2, 0.5)
	assert_eq(n.golfer_tier, 2, "Tier should be stored from setup")

func test_setup_stores_patience() -> void:
	var n = GolferNeeds.new()
	n.setup(1, 0.7)
	assert_almost_eq(n.patience, 0.7, 0.001, "Patience should be stored from setup")

func test_setup_clears_trigger_flags() -> void:
	var n = _make_needs({"energy": 0.25})
	# Fire the trigger
	var first = n.check_need_triggers()
	assert_eq(first.size(), 1, "Should fire TIRED trigger")
	# Reset via setup
	n.setup(1, 0.5)
	n.energy = 0.25
	var second = n.check_need_triggers()
	assert_eq(second.size(), 1, "Should fire TIRED again after setup reset")


# --- Section 2: Per-Hole Decay Mechanics ---

func test_on_hole_completed_decays_energy() -> void:
	var n = _make_needs()
	n.on_hole_completed()
	assert_lt(n.energy, 1.0, "Energy should decrease after hole")

func test_on_hole_completed_decays_comfort() -> void:
	var n = _make_needs()
	n.on_hole_completed()
	assert_lt(n.comfort, 1.0, "Comfort should decrease after hole")

func test_on_hole_completed_decays_hunger() -> void:
	var n = _make_needs()
	n.on_hole_completed()
	assert_lt(n.hunger, 1.0, "Hunger should decrease after hole")

func test_on_hole_completed_does_not_decay_pace() -> void:
	var n = _make_needs()
	n.on_hole_completed()
	assert_eq(n.pace, 1.0, "Pace should not change from hole completion")

func test_on_hole_completed_exact_decay_casual() -> void:
	var n = _make_needs({"tier": 1})  # CASUAL, modifier 1.0
	n.on_hole_completed()
	assert_almost_eq(n.energy, 1.0 - 0.08, 0.001, "Casual energy decay = 0.08")
	assert_almost_eq(n.comfort, 1.0 - 0.06, 0.001, "Casual comfort decay = 0.06")
	assert_almost_eq(n.hunger, 1.0 - 0.05, 0.001, "Casual hunger decay = 0.05")

func test_multiple_holes_cumulative_decay() -> void:
	var n = _make_needs({"tier": 1})
	for i in 5:
		n.on_hole_completed()
	assert_almost_eq(n.energy, 1.0 - 0.08 * 5, 0.001, "5 holes of energy decay")
	assert_almost_eq(n.comfort, 1.0 - 0.06 * 5, 0.001, "5 holes of comfort decay")
	assert_almost_eq(n.hunger, 1.0 - 0.05 * 5, 0.001, "5 holes of hunger decay")

func test_energy_low_after_12_holes_casual() -> void:
	var n = _make_needs({"tier": 1})
	for i in 12:
		n.on_hole_completed()
	# 1.0 - 12*0.08 = 0.04
	assert_lt(n.energy, GolferNeeds.LOW_NEED_THRESHOLD,
		"Energy should be below LOW threshold after 12 holes for casual")


# --- Section 3: Boundary Clamping ---

func test_needs_clamped_at_zero_floor() -> void:
	var n = _make_needs({"tier": 1})
	for i in 20:
		n.on_hole_completed()
	assert_eq(n.energy, 0.0, "Energy should not go below 0")
	assert_eq(n.comfort, 0.0, "Comfort should not go below 0")
	assert_eq(n.hunger, 0.0, "Hunger should not go below 0")

func test_building_restore_clamped_at_one_ceiling() -> void:
	var n = _make_needs({"energy": 0.95})
	n.apply_building_effect("bench")  # +0.20 would be 1.15
	assert_eq(n.energy, 1.0, "Energy should not exceed 1.0 after restoration")

func test_pace_clamped_at_zero() -> void:
	var n = _make_needs()
	n.on_waiting(10000.0)
	assert_eq(n.pace, 0.0, "Pace should not go below 0")


# --- Section 4: Waiting / Pace Decay ---

func test_on_waiting_decays_pace() -> void:
	var n = _make_needs()
	n.on_waiting(5.0)
	assert_lt(n.pace, 1.0, "Pace should decrease after waiting")

func test_on_waiting_patient_golfer_decays_slower() -> void:
	var patient = _make_needs({"patience": 0.9})
	var impatient = _make_needs({"patience": 0.2})
	patient.on_waiting(10.0)
	impatient.on_waiting(10.0)
	assert_gt(patient.pace, impatient.pace,
		"Patient golfer should have more pace remaining than impatient")

func test_on_waiting_exact_decay_calculation() -> void:
	var n = _make_needs({"patience": 0.5})
	# patience_modifier = 1.0 + (1.0 - 0.5) * 1.5 = 1.75
	# decay = 5.0 * 0.003 * 1.75 = 0.02625
	n.on_waiting(5.0)
	assert_almost_eq(n.pace, 1.0 - 0.02625, 0.0001,
		"Pace decay should match formula: wait * 0.003 * patience_modifier")

func test_pace_survives_reasonable_round() -> void:
	# Bug #4 verification: 240 seconds total wait should NOT tank a patient golfer
	var n = _make_needs({"patience": 0.9})
	# patience_modifier = 1.0 + (1.0 - 0.9) * 1.5 = 1.15
	# decay = 240 * 0.003 * 1.15 = 0.828
	n.on_waiting(240.0)
	assert_gt(n.pace, GolferNeeds.CRITICAL_NEED_THRESHOLD,
		"Patient golfer should survive 240s total wait without critical pace")

func test_on_waiting_does_not_affect_other_needs() -> void:
	var n = _make_needs()
	n.on_waiting(30.0)
	assert_eq(n.energy, 1.0, "Energy should not change from waiting")
	assert_eq(n.comfort, 1.0, "Comfort should not change from waiting")
	assert_eq(n.hunger, 1.0, "Hunger should not change from waiting")


# --- Section 5: Tier Modifier Effects ---

func test_tier_beginner_decays_slower() -> void:
	var beginner = _make_needs({"tier": 0})
	var casual = _make_needs({"tier": 1})
	beginner.on_hole_completed()
	casual.on_hole_completed()
	assert_gt(beginner.energy, casual.energy,
		"Beginner should have more energy than casual after 1 hole")

func test_tier_pro_decays_faster() -> void:
	var pro = _make_needs({"tier": 3})
	var casual = _make_needs({"tier": 1})
	pro.on_hole_completed()
	casual.on_hole_completed()
	assert_lt(pro.energy, casual.energy,
		"Pro should have less energy than casual after 1 hole")

func test_tier_beginner_exact_energy_after_hole() -> void:
	var n = _make_needs({"tier": 0})  # modifier = 0.8
	n.on_hole_completed()
	assert_almost_eq(n.energy, 1.0 - 0.08 * 0.8, 0.001,
		"Beginner energy: 1.0 - 0.08*0.8 = 0.936")

func test_tier_pro_exact_energy_after_hole() -> void:
	var n = _make_needs({"tier": 3})  # modifier = 1.3
	n.on_hole_completed()
	assert_almost_eq(n.energy, 1.0 - 0.08 * 1.3, 0.001,
		"Pro energy: 1.0 - 0.08*1.3 = 0.896")

func test_tier_serious_exact_energy_after_hole() -> void:
	var n = _make_needs({"tier": 2})  # modifier = 1.1
	n.on_hole_completed()
	assert_almost_eq(n.energy, 1.0 - 0.08 * 1.1, 0.001,
		"Serious energy: 1.0 - 0.08*1.1 = 0.912")


# --- Section 6: Building Restoration ---

func test_bench_restores_energy() -> void:
	var n = _make_needs({"energy": 0.5})
	n.apply_building_effect("bench")
	assert_almost_eq(n.energy, 0.7, 0.001, "Bench should restore +0.20 energy")

func test_restroom_restores_comfort() -> void:
	var n = _make_needs({"comfort": 0.4})
	n.apply_building_effect("restroom")
	assert_almost_eq(n.comfort, 0.75, 0.001, "Restroom should restore +0.35 comfort")

func test_snack_bar_restores_hunger() -> void:
	var n = _make_needs({"hunger": 0.4})
	n.apply_building_effect("snack_bar")
	assert_almost_eq(n.hunger, 0.7, 0.001, "Snack bar should restore +0.30 hunger")

func test_restaurant_restores_hunger() -> void:
	var n = _make_needs({"hunger": 0.3})
	n.apply_building_effect("restaurant")
	assert_almost_eq(n.hunger, 0.8, 0.001, "Restaurant should restore +0.50 hunger")

func test_clubhouse_restores_all() -> void:
	var n = _make_needs({"energy": 0.5, "comfort": 0.5, "hunger": 0.5})
	n.apply_building_effect("clubhouse")
	assert_almost_eq(n.energy, 0.65, 0.001, "Clubhouse should restore +0.15 energy")
	assert_almost_eq(n.comfort, 0.65, 0.001, "Clubhouse should restore +0.15 comfort")
	assert_almost_eq(n.hunger, 0.65, 0.001, "Clubhouse should restore +0.15 hunger")

func test_building_returns_mood_boost() -> void:
	var n = _make_needs({"energy": 0.5})
	var boost = n.apply_building_effect("bench")
	assert_almost_eq(boost, 0.02, 0.001, "Bench mood boost should be 0.02")

func test_restroom_mood_boost() -> void:
	var n = _make_needs({"comfort": 0.5})
	var boost = n.apply_building_effect("restroom")
	assert_almost_eq(boost, 0.05, 0.001, "Restroom mood boost should be 0.05")

func test_unknown_building_no_effect() -> void:
	var n = _make_needs({"energy": 0.5, "comfort": 0.5, "hunger": 0.5})
	var boost = n.apply_building_effect("pro_shop")
	assert_eq(boost, 0.0, "Unknown building should return 0 mood boost")
	assert_almost_eq(n.energy, 0.5, 0.001, "Energy unchanged by unknown building")

func test_restaurant_better_than_snack_bar() -> void:
	var n1 = _make_needs({"hunger": 0.3})
	var n2 = _make_needs({"hunger": 0.3})
	n1.apply_building_effect("snack_bar")
	n2.apply_building_effect("restaurant")
	assert_gt(n2.hunger, n1.hunger, "Restaurant should restore more hunger than snack bar")


# --- Section 7: Interaction Chance Logic ---

func test_interaction_chance_desperate_always() -> void:
	var n = _make_needs({"energy": 0.1})
	assert_eq(n.get_interaction_chance("bench"), 1.0,
		"Desperate need (<0.3) should return 100% interaction chance")

func test_interaction_chance_mid_need() -> void:
	var n = _make_needs({"energy": 0.5})
	assert_eq(n.get_interaction_chance("bench"), 0.50,
		"Mid need (0.3-0.7) should return 50% interaction chance")

func test_interaction_chance_high_need() -> void:
	var n = _make_needs({"energy": 0.9})
	assert_eq(n.get_interaction_chance("bench"), 0.20,
		"High need (>0.7) should return 20% interaction chance")

func test_interaction_chance_unmapped_building() -> void:
	var n = _make_needs()
	assert_eq(n.get_interaction_chance("pro_shop"), 0.30,
		"Unmapped building should return base 30% chance")

func test_interaction_chance_bench_maps_to_energy() -> void:
	var n = _make_needs({"energy": 0.1, "comfort": 1.0, "hunger": 1.0})
	assert_eq(n.get_interaction_chance("bench"), 1.0,
		"Bench should check energy, not other needs")

func test_interaction_chance_restroom_maps_to_comfort() -> void:
	var n = _make_needs({"comfort": 0.1, "energy": 1.0, "hunger": 1.0})
	assert_eq(n.get_interaction_chance("restroom"), 1.0,
		"Restroom should check comfort, not other needs")

func test_interaction_chance_restaurant_maps_to_hunger() -> void:
	var n = _make_needs({"hunger": 0.1, "energy": 1.0, "comfort": 1.0})
	assert_eq(n.get_interaction_chance("restaurant"), 1.0,
		"Restaurant should check hunger")

func test_interaction_chance_boundary_at_threshold() -> void:
	# 0.3 is NOT < 0.3, so should get mid chance (0.50)
	var n = _make_needs({"energy": 0.3})
	assert_eq(n.get_interaction_chance("bench"), 0.50,
		"Energy exactly at 0.3 should return mid chance (0.50)")


# --- Section 8: Mood Penalty Calculation ---

func test_mood_penalty_all_needs_fine() -> void:
	var n = _make_needs()
	assert_eq(n.get_mood_penalty(), 0.0, "No penalty when all needs above critical")

func test_mood_penalty_one_critical_energy() -> void:
	var n = _make_needs({"energy": 0.1})
	assert_almost_eq(n.get_mood_penalty(), -0.05, 0.001,
		"Critical energy penalty should be -0.05")

func test_mood_penalty_one_critical_pace() -> void:
	var n = _make_needs({"pace": 0.1})
	assert_almost_eq(n.get_mood_penalty(), -0.08, 0.001,
		"Critical pace penalty should be -0.08 (strongest)")

func test_mood_penalty_all_critical() -> void:
	var n = _make_needs({"energy": 0.05, "comfort": 0.05, "hunger": 0.05, "pace": 0.05})
	# -(0.05 + 0.05 + 0.03 + 0.08) = -0.21
	assert_almost_eq(n.get_mood_penalty(), -0.21, 0.001,
		"All critical penalty = -0.21")

func test_mood_penalty_only_fires_once_per_critical_transition() -> void:
	# Bug #2 verification: calling get_mood_penalty() twice should return 0.0 the second time
	var n = _make_needs({"energy": 0.1})
	var first = n.get_mood_penalty()
	assert_almost_eq(first, -0.05, 0.001, "First call should return penalty")
	var second = n.get_mood_penalty()
	assert_eq(second, 0.0, "Second call should return 0 (already applied)")

func test_mood_penalty_refires_after_recovery() -> void:
	# Bug #2 verification: penalty should fire again after recovery and re-drop
	var n = _make_needs({"energy": 0.1})
	n.get_mood_penalty()  # Fires, sets _applied_critical_energy = true
	# Recover via bench: 0.1 + 0.20 = 0.30, above CRITICAL (0.15)
	n.apply_building_effect("bench")
	assert_eq(n._applied_critical_energy, false,
		"Critical flag should reset after recovery above threshold")
	# Drop energy back to critical
	n.energy = 0.1
	var penalty = n.get_mood_penalty()
	assert_almost_eq(penalty, -0.05, 0.001,
		"Penalty should fire again after recovery and re-drop")


# --- Section 9: Trigger Flag Behavior ---

func test_trigger_fires_when_energy_low() -> void:
	var n = _make_needs({"energy": 0.25})
	var triggers = n.check_need_triggers()
	assert_eq(triggers.size(), 1, "Should fire one trigger")
	assert_eq(triggers[0], FeedbackTriggers.TriggerType.TIRED, "Should be TIRED trigger")

func test_trigger_fires_once_only() -> void:
	var n = _make_needs({"energy": 0.25})
	var first = n.check_need_triggers()
	assert_eq(first.size(), 1, "First call should fire trigger")
	var second = n.check_need_triggers()
	assert_eq(second.size(), 0, "Second call should not fire (already triggered)")

func test_trigger_does_not_fire_above_threshold() -> void:
	var n = _make_needs({"energy": 0.35})
	var triggers = n.check_need_triggers()
	assert_eq(triggers.size(), 0, "Should not trigger above LOW_NEED_THRESHOLD")

func test_multiple_needs_trigger_together() -> void:
	var n = _make_needs({"energy": 0.2, "comfort": 0.2, "hunger": 0.2, "pace": 0.2})
	var triggers = n.check_need_triggers()
	assert_eq(triggers.size(), 4, "All 4 low needs should trigger")

func test_trigger_resets_after_building_visit() -> void:
	# Bug #3 verification: trigger flags should reset when need recovers above threshold
	var n = _make_needs({"energy": 0.2})
	var first = n.check_need_triggers()
	assert_eq(first.size(), 1, "Should fire TIRED trigger")
	# Bench restores: 0.2 + 0.20 = 0.40, above LOW (0.30)
	n.apply_building_effect("bench")
	assert_eq(n._triggered_low_energy, false,
		"Trigger flag should reset after recovery above LOW threshold")
	# Drop energy low again
	n.energy = 0.2
	var second = n.check_need_triggers()
	assert_eq(second.size(), 1, "Should fire TIRED again after recovery and re-drop")

func test_trigger_does_not_reset_if_still_low() -> void:
	# Building visit that doesn't raise above threshold keeps flag set
	var n = _make_needs({"energy": 0.05})
	n.check_need_triggers()  # Flag set
	# Bench restores: 0.05 + 0.20 = 0.25, still below LOW (0.30)
	n.apply_building_effect("bench")
	assert_eq(n._triggered_low_energy, true,
		"Trigger flag should stay set if still below LOW threshold")

func test_pace_trigger_fires_for_slow_pace() -> void:
	var n = _make_needs({"pace": 0.2})
	var triggers = n.check_need_triggers()
	assert_true(triggers.has(FeedbackTriggers.TriggerType.SLOW_PACE),
		"Should fire SLOW_PACE trigger when pace is low")

func test_comfort_trigger_fires_for_restroom() -> void:
	var n = _make_needs({"comfort": 0.2})
	var triggers = n.check_need_triggers()
	assert_true(triggers.has(FeedbackTriggers.TriggerType.NEEDS_RESTROOM),
		"Should fire NEEDS_RESTROOM trigger when comfort is low")

func test_hunger_trigger_fires() -> void:
	var n = _make_needs({"hunger": 0.2})
	var triggers = n.check_need_triggers()
	assert_true(triggers.has(FeedbackTriggers.TriggerType.HUNGRY),
		"Should fire HUNGRY trigger when hunger is low")


# --- Section 10: Overall Satisfaction ---

func test_overall_satisfaction_all_full() -> void:
	var n = _make_needs()
	assert_eq(n.get_overall_satisfaction(), 1.0, "All full should give 1.0")

func test_overall_satisfaction_all_zero() -> void:
	var n = _make_needs({"energy": 0.0, "comfort": 0.0, "hunger": 0.0, "pace": 0.0})
	# Need to force these since make_needs starts at 1.0 then overrides
	n.energy = 0.0
	n.comfort = 0.0
	n.hunger = 0.0
	n.pace = 0.0
	assert_eq(n.get_overall_satisfaction(), 0.0, "All zero should give 0.0")

func test_overall_satisfaction_weighted() -> void:
	var n = _make_needs()
	n.energy = 0.5
	n.comfort = 1.0
	n.hunger = 1.0
	n.pace = 1.0
	# 0.5*0.3 + 1.0*0.2 + 1.0*0.2 + 1.0*0.3 = 0.15 + 0.2 + 0.2 + 0.3 = 0.85
	assert_almost_eq(n.get_overall_satisfaction(), 0.85, 0.001,
		"Weighted satisfaction with energy=0.5 should be 0.85")

func test_overall_satisfaction_pace_weighted_heavily() -> void:
	var n = _make_needs()
	n.pace = 0.0  # Only pace at zero
	# 1.0*0.3 + 1.0*0.2 + 1.0*0.2 + 0.0*0.3 = 0.7
	assert_almost_eq(n.get_overall_satisfaction(), 0.7, 0.001,
		"Pace at zero should drop satisfaction to 0.7 (30% weight)")


# --- Section 11: Serialization / Debug ---

func test_to_dict_has_all_keys() -> void:
	var n = _make_needs()
	var d = n.to_dict()
	assert_true(d.has("energy"), "Dict should have energy")
	assert_true(d.has("comfort"), "Dict should have comfort")
	assert_true(d.has("hunger"), "Dict should have hunger")
	assert_true(d.has("pace"), "Dict should have pace")
	assert_true(d.has("overall"), "Dict should have overall")

func test_to_dict_values_match() -> void:
	var n = _make_needs({"energy": 0.75, "comfort": 0.50})
	var d = n.to_dict()
	assert_almost_eq(d["energy"], 0.75, 0.01, "Dict energy should match")
	assert_almost_eq(d["comfort"], 0.50, 0.01, "Dict comfort should match")


# --- Section 12: Edge Cases ---

func test_zero_wait_time_no_change() -> void:
	var n = _make_needs()
	n.on_waiting(0.0)
	assert_eq(n.pace, 1.0, "Zero wait time should not change pace")

func test_negative_wait_time_no_increase() -> void:
	var n = _make_needs()
	n.on_waiting(-1.0)
	assert_lte(n.pace, 1.0, "Negative wait time should not increase pace")

func test_setup_can_be_called_multiple_times() -> void:
	var n = GolferNeeds.new()
	n.setup(0, 0.3)
	assert_eq(n.golfer_tier, 0)
	n.setup(3, 0.9)
	assert_eq(n.golfer_tier, 3)
	assert_almost_eq(n.patience, 0.9, 0.001)
	assert_eq(n.energy, 1.0, "Energy should be 1.0 after re-setup")

func test_all_building_types_produce_valid_results() -> void:
	var building_types = ["bench", "restroom", "snack_bar", "restaurant", "clubhouse", "pro_shop", "driving_range"]
	for btype in building_types:
		var n = _make_needs({"energy": 0.5, "comfort": 0.5, "hunger": 0.5})
		var boost = n.apply_building_effect(btype)
		assert_gte(boost, 0.0, "Mood boost for %s should be >= 0" % btype)

func test_clubhouse_resets_all_flags() -> void:
	# Clubhouse should reset energy, comfort, and hunger flags
	var n = _make_needs({"energy": 0.1, "comfort": 0.1, "hunger": 0.1})
	n.check_need_triggers()  # Set all trigger flags
	n.get_mood_penalty()  # Set all critical flags
	n.apply_building_effect("clubhouse")  # +0.15 to all -> 0.25 each
	# 0.25 is above CRITICAL (0.15) but below LOW (0.30)
	# Critical flags should reset, trigger flags should NOT reset (still below 0.30)
	assert_eq(n._applied_critical_energy, false, "Critical energy flag should reset")
	assert_eq(n._applied_critical_comfort, false, "Critical comfort flag should reset")
	assert_eq(n._applied_critical_hunger, false, "Critical hunger flag should reset")
	assert_eq(n._triggered_low_energy, true, "Trigger energy flag should stay (still below 0.30)")

func test_building_no_mood_boost_when_already_full() -> void:
	var n = _make_needs()  # All at 1.0
	var boost = n.apply_building_effect("bench")
	assert_eq(boost, 0.0, "No mood boost when energy already at max")
