extends RefCounted
class_name GolfRules
## GolfRules - Centralized golf rules engine
##
## Single source of truth for core golf rules: scoring, penalties, par calculation,
## lie modifiers, club data, and putting make rates. All methods are static/const
## so this class carries no state.
##
## References: USGA Rules of Golf (2023), PGA Tour putting statistics.

# =============================================================================
# SCORING
# =============================================================================

## Score name from strokes relative to par (USGA terminology)
static func get_score_name(strokes: int, par: int) -> String:
	if strokes == 1:
		return "Hole-in-One"
	var diff = strokes - par
	match diff:
		-3: return "Albatross"
		-2: return "Eagle"
		-1: return "Birdie"
		0: return "Par"
		1: return "Bogey"
		2: return "Double Bogey"
		3: return "Triple Bogey"
		_: return "+%d" % diff if diff > 0 else "%d" % diff

## Classify score for statistics tracking. Returns one of:
## "hole_in_one", "eagle", "birdie", "par", "bogey", "double_bogey_plus"
static func classify_score(strokes: int, par: int) -> String:
	if strokes == 1:
		return "hole_in_one"
	var diff = strokes - par
	if diff <= -2:
		return "eagle"
	elif diff == -1:
		return "birdie"
	elif diff == 0:
		return "par"
	elif diff == 1:
		return "bogey"
	else:
		return "double_bogey_plus"

# =============================================================================
# PAR CALCULATION (USGA guidelines for men's courses)
# =============================================================================

## Calculate par from hole distance in yards.
## USGA men's guidelines: Par 3 up to 250y, Par 4 251-470y, Par 5 471y+.
static func calculate_par(distance_yards: int) -> int:
	if distance_yards <= 250:
		return 3
	elif distance_yards <= 470:
		return 4
	else:
		return 5

# =============================================================================
# PICKUP / MAX STROKES
# =============================================================================

## Maximum strokes before a golfer picks up (casual play pace-of-play rule).
## Uses triple bogey (par + 3) which aligns with common casual course rules
## and is closer to the WHS net double bogey concept than double-par.
static func get_max_strokes(par: int) -> int:
	return par + 3

# =============================================================================
# PENALTIES
# =============================================================================

enum ReliefType {
	NONE,               ## No relief needed (playable lie)
	DROP_AT_ENTRY,      ## 1 stroke penalty, drop at point of entry (water/penalty area)
	STROKE_AND_DISTANCE,## 1 stroke penalty, replay from previous position (OB)
	FREE_RELIEF,        ## No penalty, nearest point of relief (cart path, GUR)
}

## Get penalty strokes for a terrain type (USGA Rules 17-18).
## Water (penalty area): 1 stroke. OB: 1 stroke (+ distance via ReliefType).
static func get_penalty_strokes(terrain_type: int) -> int:
	match terrain_type:
		TerrainTypes.Type.WATER:
			return 1
		TerrainTypes.Type.OUT_OF_BOUNDS:
			return 1  # USGA Rule 18.2: stroke and distance = 1 penalty stroke
		_:
			return 0

## Get relief type for a terrain type.
static func get_relief_type(terrain_type: int) -> ReliefType:
	match terrain_type:
		TerrainTypes.Type.WATER:
			return ReliefType.DROP_AT_ENTRY
		TerrainTypes.Type.OUT_OF_BOUNDS:
			return ReliefType.STROKE_AND_DISTANCE
		TerrainTypes.Type.FLOWER_BED:
			return ReliefType.FREE_RELIEF  # Ground under repair
		TerrainTypes.Type.EMPTY:
			return ReliefType.FREE_RELIEF  # Ground under repair
		TerrainTypes.Type.PATH:
			return ReliefType.NONE  # Playable (simplified — real rules offer free relief)
		_:
			return ReliefType.NONE

# =============================================================================
# HOLING
# =============================================================================

## Cup radius in tiles — ball is holed if within this distance.
## 0.01 tiles ≈ 8 inches (actual USGA cup: 4.25" diameter).
const CUP_RADIUS: float = 0.01

## Tap-in distance in tiles — automatic make for very short putts.
## 0.045 tiles ≈ 3 feet (inside-the-leather gimme range).
const TAP_IN_DISTANCE: float = 0.045

static func is_ball_holed(ball_pos: Vector2, hole_pos: Vector2) -> bool:
	return ball_pos.distance_to(hole_pos) < CUP_RADIUS

# =============================================================================
# PUTTING MAKE RATES
# =============================================================================
## Based on PGA Tour averages, scaled by putting_skill.
##
## PGA Tour make rates (putting_skill ≈ 0.90-0.98):
##   3 ft: ~99%    5 ft: ~77%    8 ft: ~50%    10 ft: ~40%
##  15 ft: ~25%   20 ft: ~15%   25 ft: ~10%    30 ft: ~7%
##  40 ft: ~3%    50 ft: ~2%
##
## The model uses an exponential decay: make_rate = exp(-distance * k)
## where k is scaled inversely with putting_skill.

## Get probability of making a putt at a given distance (in tiles).
## putting_skill: 0.0-1.0 (beginner to pro).
static func get_putt_make_rate(distance_tiles: float, putting_skill: float) -> float:
	if distance_tiles < TAP_IN_DISTANCE:
		return 1.0  # Tap-in, automatic

	var distance_feet = distance_tiles * 66.0  # 1 tile = 22 yards = 66 feet

	# Decay constant calibrated to PGA Tour stats at skill=0.95:
	#   At 5ft: exp(-5 * 0.053) = 0.77 ✓
	#   At 8ft: exp(-8 * 0.053) = 0.65 (slightly generous vs real 0.50)
	#   At 15ft: exp(-15 * 0.053) = 0.45 (generous — balanced by miss severity)
	#   At 30ft: exp(-30 * 0.053) = 0.20
	# For beginners (skill=0.35), decay is ~3x steeper.
	var base_decay = 0.053
	# Skill scales the decay: lower skill = steeper decay = harder to make putts
	# skill 0.95 → multiplier 1.125, skill 0.35 → multiplier ~2.625
	var skill_multiplier = 1.0 + (1.0 - putting_skill) * 2.5
	var decay = base_decay * skill_multiplier

	var make_rate = exp(-distance_feet * decay)

	# Floor: even a complete beginner has a small chance on any putt
	return maxf(make_rate, 0.01)

## Get miss distance characteristics for a missed putt.
## Returns {"distance_ratio": float, "lateral_std": float}
## distance_ratio: how far past/short of hole (1.0 = at hole, >1.0 = past, <1.0 = short)
## lateral_std: standard deviation of lateral miss in tiles.
static func get_putt_miss_characteristics(distance_tiles: float, putting_skill: float) -> Dictionary:
	var distance_feet = distance_tiles * 66.0

	# Short putts (< 10 ft): misses are mostly lateral (lip-outs), slight long bias
	# Medium putts (10-30 ft): mix of distance and direction error
	# Long putts (30+ ft): mostly distance control issues

	# Distance error (how far past/short of hole the miss ends up)
	# Skilled putters have tighter distance control
	# Tighter values prevent cascading 3-4 putt cycles for beginners
	var distance_std: float
	if distance_feet < 10.0:
		# Short putts: small overshoot, tight control
		distance_std = 0.015 + (1.0 - putting_skill) * 0.02
	elif distance_feet < 30.0:
		# Medium putts: moderate distance error
		distance_std = 0.03 + (1.0 - putting_skill) * 0.06
	else:
		# Long putts: distance control is the main challenge
		# Error proportional to distance (lag putting)
		distance_std = distance_tiles * (0.06 + (1.0 - putting_skill) * 0.12)

	# Lateral error (left/right miss)
	var lateral_std: float
	if distance_feet < 10.0:
		# Short putts: small lateral miss (lip-out territory)
		lateral_std = 0.008 + (1.0 - putting_skill) * 0.017
	elif distance_feet < 30.0:
		# Medium putts: moderate read error
		lateral_std = 0.015 + (1.0 - putting_skill) * 0.035
	else:
		# Long putts: significant read error
		lateral_std = 0.025 + (1.0 - putting_skill) * 0.06

	# Slight long bias — pros are taught "never up, never in"
	# Aggressive putters tend to run it past; cautious ones leave it short
	var long_bias = 0.02 + putting_skill * 0.03  # Better players hit it firmer

	return {
		"distance_std": distance_std,
		"lateral_std": lateral_std,
		"long_bias": long_bias,
	}

# =============================================================================
# LIE MODIFIERS (terrain → accuracy penalty)
# =============================================================================

## Get accuracy modifier for a given terrain type and club.
## Returns 0.0-1.05 where 1.0 = perfect lie, lower = harder.
static func get_lie_modifier(terrain_type: int, club: int) -> float:
	match terrain_type:
		TerrainTypes.Type.GRASS, TerrainTypes.Type.FAIRWAY:
			return 1.0  # Perfect lie
		TerrainTypes.Type.TEE_BOX:
			return 1.05 if club == Golfer.Club.DRIVER else 1.0  # Slight tee bonus for driver
		TerrainTypes.Type.GREEN:
			return 1.0  # Putting surface
		TerrainTypes.Type.ROUGH:
			return 0.75  # 25% accuracy penalty
		TerrainTypes.Type.HEAVY_ROUGH:
			return 0.5   # 50% accuracy penalty
		TerrainTypes.Type.BUNKER:
			# Wedges handle sand better
			return 0.6 if club == Golfer.Club.WEDGE else 0.4
		TerrainTypes.Type.TREES:
			return 0.3   # Very difficult shot
		TerrainTypes.Type.ROCKS:
			return 0.25  # Extremely difficult — risk of injury/club damage
		_:
			return 0.8   # Default penalty

## Get distance modifier for a given terrain type.
## Returns 0.0-1.0 where 1.0 = full distance.
static func get_terrain_distance_modifier(terrain_type: int) -> float:
	match terrain_type:
		TerrainTypes.Type.ROUGH:
			return 0.85  # 15% distance loss
		TerrainTypes.Type.HEAVY_ROUGH:
			return 0.7   # 30% distance loss
		TerrainTypes.Type.BUNKER:
			return 0.75  # 25% distance loss
		TerrainTypes.Type.TREES:
			return 0.6   # 40% distance loss (punch out)
		TerrainTypes.Type.ROCKS:
			return 0.5   # 50% distance loss
		_:
			return 1.0   # No penalty

# =============================================================================
# CLUB WIND SENSITIVITY
# =============================================================================
## Higher trajectory clubs are more affected by wind.
static func get_club_wind_sensitivity(club: int) -> float:
	match club:
		Golfer.Club.DRIVER:
			return 1.0   # High trajectory, long hang time, full wind effect
		Golfer.Club.FAIRWAY_WOOD:
			return 0.85  # Slightly lower trajectory than driver
		Golfer.Club.IRON:
			return 0.7   # Medium trajectory
		Golfer.Club.WEDGE:
			return 0.4   # High but short, moderate wind effect
		Golfer.Club.PUTTER:
			return 0.0   # Ground ball, no wind effect
		_:
			return 0.5
