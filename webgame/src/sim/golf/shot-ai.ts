// ShotAI — port of scripts/systems/shot_ai.gd. Golf shot decision-making engine.
//
// Structured decision pipeline (shot_ai.gd:3-14):
//   1. Assess lie → if in trouble, enter recovery mode
//   2. Plan shot sequence to hole (backwards from green)
//   3. For current shot: evaluate clubs with wind-adjusted aim points
//   4. Score candidates on terrain, miss-distribution hazard overlap, next-shot setup
//   5. Apply personality (aggression shifts risk tolerance)
//
// The execution model (calculateShot / putting / rollout) lives in shot.ts,
// putting.ts, rollout.ts — this module only decides WHERE and WITH WHAT to hit.
//
// NOTE: the whole pipeline is deterministic — the "Monte Carlo" risk analysis
// samples fixed sigma offsets (shot_ai.gd:762), so no Rng draws are consumed.
// ctx.rng is accepted for API symmetry with the rest of the sim layer.

import { Vec2, vec, DEG_TO_RAD } from '../core/vec'
import type { TerrainGrid } from '../terrain/terrain-grid'
import { TerrainType } from '../terrain/terrain-types'
import { Club, CLUB_STATS, getSkillAccuracy, getSkillDistanceFactor, GolferSkills } from './clubs'
import { getLieModifier } from './golf-rules'
import type { ShotContext } from './shot'

const TAU = Math.PI * 2

// ============================================================================
// TYPES
// ============================================================================

export type ShotStrategy = 'normal' | 'recovery' | 'layup' | 'attack'

/** Result of a shot decision — everything the golfer needs to execute. */
export interface ShotDecision {
	/** Where to aim (wind-compensated), integer tile coords. */
	target: Vec2
	club: Club
	strategy: ShotStrategy
	/** 0-1 for putts, raw candidate score otherwise (mirrors shot_ai.gd confidence). */
	confidence: number
}

/**
 * Lightweight data snapshot of a golfer's stats — used by all ShotAI functions.
 * Mirrors ShotAI.GolferData / from_golfer() (shot_ai.gd:30-58). Callers construct
 * this directly; there is no golfer entity dependency.
 */
export interface GolferData extends GolferSkills {
	/** Integer tile position of the ball (Vector2i in Godot). */
	ballPosition: Vec2
	/** Sub-tile precise ball position (used for putt distance). */
	ballPositionPrecise: Vec2
	aggression: number
	/** Copied by from_golfer(); not read by any ShotAI path (kept for parity). */
	patience: number
	currentHole: number
	totalStrokes: number
	totalPar: number
}

/** Internal candidate during evaluation (shot_ai.gd:61-66). */
interface ShotCandidate {
	/** Where to aim (pre-wind-compensation aim point after compensation shift). */
	aimPoint: Vec2
	/** Where ball is expected to land (post-wind). */
	landingZone: Vec2
	club: Club
	score: number
	strategy: ShotStrategy
}

// Phase 4: minimal course-data shape read by applyGreenCenterBias
// (GameManager.course_data.holes[n].green_position in Godot). Replace with the
// full CourseData port when GameManager lands.
export interface HoleGreenInfo {
	greenPosition: Vec2
}
export interface CourseHolesInfo {
	holes: HoleGreenInfo[]
}

/** ShotContext plus the optional course data used for green-center bias. */
export interface ShotAIContext extends ShotContext {
	course?: CourseHolesInfo | null
}

// ============================================================================
// CONFIGURATION
// ============================================================================

/** Scan resolution for landing zone search. */
export const APPROACH_ANGLE_SAMPLES = 15 // Narrow scan (±15°) for approach shots
export const LAYUP_ANGLE_SAMPLES = 25 // Wide scan (±50°) for layup/recovery
export const DISTANCE_SAMPLES = 7 // Distance steps per angle
export const APPROACH_HALF_ANGLE = 0.26 // ±15° in radians
export const LAYUP_HALF_ANGLE = 0.87 // ±50° in radians

/** Lateral offsets perpendicular to shot direction (in tiles) to discover nearby fairway. */
export const LATERAL_OFFSETS: readonly number[] = [0, -1, 1, -2, 2]

/** Re-scan parameters (lighter than full layup scan). */
export const RESCAN_ANGLE_SAMPLES = 12
export const RESCAN_LATERAL_OFFSETS: readonly number[] = [0, -1, 1]

/** Miss distribution sampling for risk analysis. */
export const MISS_SAMPLE_COUNT = 8

/** Terrain scores (large gaps to dominate over distance bonuses at similar ranges). */
export const TERRAIN_SCORES: Readonly<Record<TerrainType, number>> = {
	[TerrainType.GREEN]: 180.0,
	[TerrainType.FAIRWAY]: 150.0,
	[TerrainType.TEE_BOX]: 130.0,
	[TerrainType.GRASS]: 40.0,
	[TerrainType.PATH]: 35.0,
	[TerrainType.ROUGH]: 10.0,
	[TerrainType.HEAVY_ROUGH]: -20.0,
	[TerrainType.BUNKER]: -50.0,
	[TerrainType.TREES]: -80.0,
	[TerrainType.ROCKS]: -100.0,
	[TerrainType.WATER]: -1000.0,
	[TerrainType.OUT_OF_BOUNDS]: -1000.0,
	[TerrainType.FLOWER_BED]: -40.0,
	[TerrainType.EMPTY]: -1000.0, // Treat as OB — outside property line
}

function terrainScore(type: TerrainType): number {
	return TERRAIN_SCORES[type] ?? -50.0
}

/** Godot Vector2i(Vector2) cast — truncates toward zero. */
function toTileTrunc(p: Vec2): Vec2 {
	return { x: Math.trunc(p.x), y: Math.trunc(p.y) }
}

// ============================================================================
// PUBLIC API
// ============================================================================

/**
 * Main entry point: decide what shot to hit (shot_ai.gd:118 decide_shot_for).
 * Set ignoreWind=true for course design visualization.
 */
export function decideShot(
	ctx: ShotAIContext,
	gd: GolferData,
	holePosition: Vec2,
	ignoreWind = false,
): ShotDecision {
	const terrain = ctx.terrain
	const currentTerrain = terrain.getTile(gd.ballPosition.x, gd.ballPosition.y)

	// --- Putting: delegate to green-reading system ---
	if (currentTerrain === TerrainType.GREEN) {
		return decidePutt(gd, holePosition, terrain)
	}

	// --- Assess lie quality ---
	const lieQuality = assessLieQuality(currentTerrain)

	// --- Recovery mode for trouble lies ---
	if (lieQuality < 0.4) {
		return decideRecoveryShot(gd, holePosition, terrain, currentTerrain)
	}

	// --- Plan shot sequence (multi-shot lookahead) ---
	const distanceToHole = vec.distance(gd.ballPosition, holePosition)
	const shotsRemaining = estimateShotsToHole(gd, distanceToHole)
	const targetDistance = getIdealShotDistance(gd, distanceToHole, shotsRemaining)

	// --- Evaluate all candidate clubs ---
	const candidates = evaluateAllCandidates(
		ctx,
		gd,
		holePosition,
		targetDistance,
		shotsRemaining,
		ignoreWind,
	)

	if (candidates.length === 0) {
		return makeDecision(holePosition, Club.WEDGE, 'normal', 0.0)
	}

	// --- Pick the best candidate ---
	candidates.sort((a, b) => b.score - a.score)
	const best = candidates[0]

	return makeDecision(best.aimPoint, best.club, best.strategy, best.score)
}

// ============================================================================
// PUTTING — Green-reading system
// ============================================================================

/**
 * Decide where to aim a putt, accounting for green slope (shot_ai.gd:161).
 * On sloped greens, aim uphill of the hole so gravity brings the ball back.
 */
export function decidePutt(
	gd: GolferData,
	holePosition: Vec2,
	terrain: TerrainGrid,
): ShotDecision {
	const slope = terrain.getSlopeDirection(holePosition.x, holePosition.y)

	// No slope or very weak slope: aim straight at the hole
	if (vec.length(slope) < 0.1) {
		return makeDecision(holePosition, Club.PUTTER, 'normal', 1.0)
	}

	// Green reading ability scales with putting skill
	// Pros read 70-90% of the break; beginners read 20-40%
	const readAbility = 0.2 + gd.puttingSkill * 0.7

	// The ball will break in the direction of slope, so aim OPPOSITE to slope.
	const puttDistance = vec.distance(gd.ballPositionPrecise, holePosition)

	// Break amount: slope strength × distance × read ability
	// Capped to prevent aiming wildly off-target
	let breakCompensation = vec.length(slope) * puttDistance * readAbility * 0.5
	breakCompensation = Math.min(breakCompensation, puttDistance * 0.3) // Max 30% of distance as break

	// Aim point: offset from hole in opposite direction of slope
	const aimOffset = vec.scale(vec.normalize(slope), -breakCompensation)
	let aimPoint = vec.round(vec.add(holePosition, aimOffset))

	// Ensure aim point is on the green (or close to it)
	if (terrain.isValidPosition(aimPoint.x, aimPoint.y)) {
		const aimTerrain = terrain.getTile(aimPoint.x, aimPoint.y)
		if (aimTerrain !== TerrainType.GREEN) {
			// Aim point went off the green — pull it back toward hole
			aimPoint = holePosition
		}
	}

	return makeDecision(aimPoint, Club.PUTTER, 'normal', 1.0)
}

// ============================================================================
// RECOVERY SHOTS — Trouble lie decision-making
// ============================================================================

/**
 * When in trees, deep rough, bunkers, or rocks: plan an escape (shot_ai.gd:201).
 * Beginners punch out sideways; skilled players may advance toward the hole.
 */
export function decideRecoveryShot(
	gd: GolferData,
	holePosition: Vec2,
	terrain: TerrainGrid,
	currentTerrain: TerrainType,
): ShotDecision {
	const ballPos = gd.ballPosition
	const distanceToHole = vec.distance(ballPos, holePosition)

	// --- Forced club selection for trouble lies ---
	const allowedClubs = getRecoveryClubs(currentTerrain)

	// --- Scan a full 360° for escape routes ---
	// Recovery scans wider angles than normal shots because "sideways" and
	// even "backwards" are legitimate escape routes from deep trouble.
	const directionToHole = vec.normalize(vec.sub(holePosition, ballPos))
	let bestCandidate: ShotCandidate | null = null
	let bestScore = -99999.0

	for (const club of allowedClubs) {
		const stats = CLUB_STATS[club]
		const skillFactor = getSkillDistanceFactor(club, gd)
		let maxDist = stats.maxDistance * skillFactor
		// In trouble, don't try to hit max distance
		maxDist *= 0.7

		// Scan 360° in 24 directions
		for (let angleIdx = 0; angleIdx < 24; angleIdx++) {
			const angle = (angleIdx / 24.0) * TAU
			const scanDir = vec.rotate({ x: 1, y: 0 }, angle)

			// Sample 4 distances along this direction
			for (let dIdx = 0; dIdx < 4; dIdx++) {
				const testDist = maxDist * (0.3 + (dIdx / 3.0) * 0.7)
				const testPos = vec.add(ballPos, vec.round(vec.scale(scanDir, testDist)))

				if (testPos.x === ballPos.x && testPos.y === ballPos.y) continue
				if (!terrain.isValidPosition(testPos.x, testPos.y)) continue

				// Skip tree-path check: recovery shots are low punch-outs
				// designed to escape trees. Club restrictions + terrain scoring
				// already model the difficulty.
				const terrainType = terrain.getTile(testPos.x, testPos.y)
				let score = terrainScore(terrainType)

				// Prefer nearby safe targets over distant ones — recovery shots
				// should escape trouble, not try to advance aggressively
				score -= testDist * 2.0

				// Bonus for advancing toward the hole (but not required)
				const newDistToHole = vec.distance(testPos, holePosition)
				const advancement = distanceToHole - newDistToHole

				if (advancement > 0) {
					score += advancement * 3.0 // Reward advancing
				} else {
					score -= 50.0 // Mild penalty for going backwards (but allowed)
				}

				// Bonus for ending up on fairway or green (sets up next shot well)
				if (terrainType === TerrainType.FAIRWAY) {
					score += 30.0
				} else if (terrainType === TerrainType.GREEN) {
					score += 50.0 // Getting on the green from trouble is ideal
				}

				// Penalty for nearby hazards at landing zone
				score -= nearbyHazardPenalty(testPos, terrain, gd.aggression)

				// Recovery skill bonus — skilled recovery players find better escape routes
				score += gd.recoverySkill * 30.0

				if (score > bestScore) {
					bestScore = score
					bestCandidate = {
						aimPoint: testPos,
						landingZone: testPos,
						club,
						score,
						strategy: 'recovery',
					}
				}
			}
		}
	}

	if (bestCandidate) {
		return makeDecision(bestCandidate.aimPoint, bestCandidate.club, 'recovery', bestScore)
	}

	// Absolute fallback: find nearest non-hazard tile, preferring toward the hole
	let fallbackTarget = vec.add(ballPos, vec.round(vec.scale(directionToHole, 2.0)))
	let bestFallbackScore = -99999.0
	for (let radius = 1; radius < 6; radius++) {
		for (let dx = -radius; dx <= radius; dx++) {
			for (let dy = -radius; dy <= radius; dy++) {
				if (Math.abs(dx) !== radius && Math.abs(dy) !== radius) continue // Only check perimeter
				const checkPos = { x: ballPos.x + dx, y: ballPos.y + dy }
				if (!terrain.isValidPosition(checkPos.x, checkPos.y)) continue
				const t = terrain.getTile(checkPos.x, checkPos.y)
				let s = terrainScore(t)
				// Prefer tiles toward the hole
				const adv = distanceToHole - vec.distance(checkPos, holePosition)
				s += adv * 2.0
				if (s > bestFallbackScore) {
					bestFallbackScore = s
					fallbackTarget = checkPos
				}
			}
		}
		if (bestFallbackScore > 0) break // Found a decent tile, stop expanding
	}
	return makeDecision(fallbackTarget, Club.WEDGE, 'recovery', -100.0)
}

/** Get clubs allowed from a trouble lie (shot_ai.gd:311). */
export function getRecoveryClubs(terrainType: TerrainType): Club[] {
	switch (terrainType) {
		case TerrainType.TREES:
			return [Club.WEDGE, Club.IRON] // No woods through trees
		case TerrainType.ROCKS:
			return [Club.WEDGE] // Wedge only from rocks
		case TerrainType.BUNKER:
			return [Club.WEDGE, Club.IRON] // Sand wedge preferred
		case TerrainType.HEAVY_ROUGH:
			return [Club.WEDGE, Club.IRON] // Can't get wood through thick stuff
		default:
			return [Club.WEDGE, Club.IRON, Club.FAIRWAY_WOOD]
	}
}

// ============================================================================
// MULTI-SHOT PLANNING
// ============================================================================

/**
 * Estimate how many shots it will take to reach the hole (shot_ai.gd:331).
 * Works backwards: par = regulation shots + 2 putts, so shots_to_green = par - 2.
 * But also considers the golfer's actual max distance with each club.
 */
export function estimateShotsToHole(gd: GolferData, distanceToHole: number): number {
	const maxDriverDist =
		CLUB_STATS[Club.DRIVER].maxDistance * getSkillDistanceFactor(Club.DRIVER, gd)

	if (distanceToHole <= 1.0) {
		return 1 // Chip/putt range
	} else if (distanceToHole <= CLUB_STATS[Club.WEDGE].maxDistance) {
		return 1 // Wedge range
	} else if (distanceToHole <= maxDriverDist) {
		return 1 // Can reach in one
	} else if (distanceToHole <= maxDriverDist * 2.0) {
		return 2 // Two shots
	}
	return 3 // Three shots (par 5 territory)
}

/**
 * Get the ideal distance for THIS shot, given how many shots remain (shot_ai.gd:347).
 * Implements backward planning: divide remaining distance into efficient segments.
 */
export function getIdealShotDistance(
	gd: GolferData,
	distanceToHole: number,
	shotsRemaining: number,
): number {
	if (shotsRemaining <= 1) {
		return distanceToHole // Go for the green
	}

	// Multi-shot strategy: plan from the green backwards
	// Last shot should be a comfortable approach distance (wedge range = 3-4 tiles)
	const idealApproach = 3.5 // ~77 yards, comfortable wedge

	if (shotsRemaining === 2) {
		// Two shots: hit first shot so second is a comfortable approach
		const firstShotIdeal = distanceToHole - idealApproach
		const maxDriver =
			CLUB_STATS[Club.DRIVER].maxDistance * getSkillDistanceFactor(Club.DRIVER, gd)
		return Math.min(firstShotIdeal, maxDriver)
	}

	if (shotsRemaining === 3) {
		// Three shots: split into two long shots + approach
		const longShotTotal = distanceToHole - idealApproach
		const perShot = longShotTotal / 2.0
		const maxDriver =
			CLUB_STATS[Club.DRIVER].maxDistance * getSkillDistanceFactor(Club.DRIVER, gd)
		return Math.min(perShot, maxDriver)
	}

	// Fallback: even split
	return distanceToHole / shotsRemaining
}

// ============================================================================
// CANDIDATE EVALUATION — Core decision engine
// ============================================================================

const GOOD_TERRAINS: readonly TerrainType[] = [
	TerrainType.GREEN,
	TerrainType.FAIRWAY,
	TerrainType.TEE_BOX,
]

/** Evaluate all candidate clubs and landing zones, return scored candidates (shot_ai.gd:378). */
export function evaluateAllCandidates(
	ctx: ShotAIContext,
	gd: GolferData,
	holePosition: Vec2,
	targetDistance: number,
	shotsRemaining: number,
	ignoreWind = false,
): ShotCandidate[] {
	const terrain = ctx.terrain
	const ballPos = gd.ballPosition
	const distanceToHole = vec.distance(ballPos, holePosition)
	const directionToHole = vec.normalize(vec.sub(holePosition, ballPos))
	const candidates: ShotCandidate[] = []

	// --- Build candidate club list ---
	const clubList = getCandidateClubs(gd, distanceToHole, targetDistance)

	let canReachGreen = false
	for (const club of clubList) {
		const maxDist = CLUB_STATS[club].maxDistance * getSkillDistanceFactor(club, gd)
		if (maxDist >= distanceToHole * 0.9) {
			canReachGreen = true
			break
		}
	}

	// --- Scan parameters based on shot type ---
	const scanHalfAngle = canReachGreen ? APPROACH_HALF_ANGLE : LAYUP_HALF_ANGLE
	const numAngles = canReachGreen ? APPROACH_ANGLE_SAMPLES : LAYUP_ANGLE_SAMPLES

	for (const club of clubList) {
		const stats = CLUB_STATS[club]
		const skillFactor = getSkillDistanceFactor(club, gd)
		const maxDist = stats.maxDistance * skillFactor
		const minDist = stats.minDistance * 0.8 // Slight flexibility on min

		// For layup shots, cap distance to target
		let effectiveMax = maxDist
		if (shotsRemaining > 1) {
			effectiveMax = Math.min(maxDist, targetDistance * 1.15)
		}

		// Scan angles and distances
		for (let a = 0; a < numAngles; a++) {
			const tAngle = a / Math.max(numAngles - 1, 1)
			const offsetAngle = -scanHalfAngle + tAngle * scanHalfAngle * 2.0
			const scanDir = vec.rotate(directionToHole, offsetAngle)

			for (let d = 0; d < DISTANCE_SAMPLES; d++) {
				const tDist = d / Math.max(DISTANCE_SAMPLES - 1, 1)
				let testDist: number
				// Wedge approach shots scan from chip distance to max,
				// so golfers near the green can target the actual distance
				// instead of overshooting to 60+ yards.
				const isWedgeApproach = club === Club.WEDGE && shotsRemaining <= 1
				if (isWedgeApproach) {
					const chipFloor = 0.25 // ~5.5 yards — covers any tile off the green
					testDist = chipFloor + tDist * (effectiveMax * 1.1 - chipFloor)
				} else {
					// Standard scan: 60% to 110% of effective max
					testDist = effectiveMax * (0.6 + tDist * 0.5)
				}

				// Skip distances below club minimum (waived for wedge chips)
				if (!isWedgeApproach && testDist < minDist * 0.7) continue

				const basePos = vec.add(ballPos, vec.round(vec.scale(scanDir, testDist)))
				if (basePos.x === ballPos.x && basePos.y === ballPos.y) continue

				// Check the base position plus lateral offsets perpendicular to
				// the scan direction. This discovers nearby fairway that the
				// direct scan line might miss.
				const perp = { x: -scanDir.y, y: scanDir.x }

				for (const latOffset of LATERAL_OFFSETS) {
					let testPos = basePos
					if (latOffset !== 0) {
						testPos = vec.add(basePos, vec.round(vec.scale(perp, latOffset)))
					}
					if (!terrain.isValidPosition(testPos.x, testPos.y)) continue

					// --- Wind compensation: adjust aim to account for wind ---
					let windAdjustedLanding = testPos
					let aimPoint = testPos
					if (!ignoreWind && ctx.wind) {
						const windDisp = ctx.wind.getWindDisplacement(scanDir, testDist, club)
						windAdjustedLanding = vec.round(vec.add(testPos, windDisp))
						const compensationFactor = 0.2 + gd.accuracySkill * 0.6
						aimPoint = vec.round(vec.sub(testPos, vec.scale(windDisp, compensationFactor)))

						if (!terrain.isValidPosition(windAdjustedLanding.x, windAdjustedLanding.y)) {
							windAdjustedLanding = testPos
						}
						if (!terrain.isValidPosition(aimPoint.x, aimPoint.y)) {
							aimPoint = testPos
						}
					}

					// --- Score the landing zone ---
					let score = scoreLandingZone(
						gd,
						ballPos,
						windAdjustedLanding,
						holePosition,
						terrain,
						club,
						shotsRemaining,
					)

					// --- Risk analysis: sample miss distribution against hazards ---
					const riskPenalty = assessMissRisk(gd, ballPos, windAdjustedLanding, terrain, club)
					score -= riskPenalty

					// --- Club accuracy preference for approach shots ---
					if (shotsRemaining <= 1) {
						score += stats.accuracyModifier * 20.0
					}

					const strategy: ShotStrategy = canReachGreen ? 'attack' : 'layup'

					candidates.push({
						aimPoint,
						landingZone: windAdjustedLanding,
						club,
						score,
						strategy,
					})
				}
			}
		}
	}

	// --- Widen scan if narrow approach missed good terrain ---
	// When the best approach candidate lands on grass/rough instead of
	// fairway/green, the direct line to the hole bypasses the fairway.
	// Re-scan with wider angle but fewer samples — just finding fairway, not full risk analysis.
	if (canReachGreen && candidates.length > 0) {
		candidates.sort((a, b) => b.score - a.score)
		const bestTerrain = terrain.getTile(candidates[0].landingZone.x, candidates[0].landingZone.y)
		if (!GOOD_TERRAINS.includes(bestTerrain)) {
			for (const club of clubList) {
				const stats = CLUB_STATS[club]
				const skillFactor = getSkillDistanceFactor(club, gd)
				const maxDist = stats.maxDistance * skillFactor
				const minDist = stats.minDistance * 0.8

				for (let a = 0; a < RESCAN_ANGLE_SAMPLES; a++) {
					const tAngle = a / Math.max(RESCAN_ANGLE_SAMPLES - 1, 1)
					const offsetAngle = -LAYUP_HALF_ANGLE + tAngle * LAYUP_HALF_ANGLE * 2.0
					const scanDir = vec.rotate(directionToHole, offsetAngle)

					for (let d = 0; d < DISTANCE_SAMPLES; d++) {
						const tDist = d / Math.max(DISTANCE_SAMPLES - 1, 1)
						const testDist = maxDist * (0.6 + tDist * 0.5)
						if (testDist < minDist * 0.7) continue

						const basePos = vec.add(ballPos, vec.round(vec.scale(scanDir, testDist)))
						if (basePos.x === ballPos.x && basePos.y === ballPos.y) continue

						const perp = { x: -scanDir.y, y: scanDir.x }
						for (const latOffset of RESCAN_LATERAL_OFFSETS) {
							let testPos = basePos
							if (latOffset !== 0) {
								testPos = vec.add(basePos, vec.round(vec.scale(perp, latOffset)))
							}
							if (!terrain.isValidPosition(testPos.x, testPos.y)) continue
							// Filter terrain FIRST — skip all expensive work for non-fairway
							const t = terrain.getTile(testPos.x, testPos.y)
							if (!GOOD_TERRAINS.includes(t)) continue

							let windAdjustedLanding = testPos
							let aimPoint = testPos
							if (!ignoreWind && ctx.wind) {
								const windDisp = ctx.wind.getWindDisplacement(scanDir, testDist, club)
								windAdjustedLanding = vec.round(vec.add(testPos, windDisp))
								const compensationFactor = 0.2 + gd.accuracySkill * 0.6
								aimPoint = vec.round(vec.sub(testPos, vec.scale(windDisp, compensationFactor)))
								if (!terrain.isValidPosition(windAdjustedLanding.x, windAdjustedLanding.y)) {
									windAdjustedLanding = testPos
								}
								if (!terrain.isValidPosition(aimPoint.x, aimPoint.y)) {
									aimPoint = testPos
								}
							}

							// Score landing zone but skip risk analysis (just finding fairway)
							let score = scoreLandingZone(
								gd,
								ballPos,
								windAdjustedLanding,
								holePosition,
								terrain,
								club,
								shotsRemaining,
							)
							if (shotsRemaining <= 1) {
								score += stats.accuracyModifier * 20.0
							}

							candidates.push({
								aimPoint,
								landingZone: windAdjustedLanding,
								club,
								score,
								strategy: 'attack',
							})
						}
					}
				}
			}
		}
	}

	// --- Approach shot: blend toward green center for less skilled golfers ---
	// Apply BEFORE returning so it's part of the candidate set, not an override
	if (canReachGreen && candidates.length > 0) {
		applyGreenCenterBias(ctx, gd, holePosition, candidates)
	}

	return candidates
}

/**
 * Build candidate club list, filtering out clubs that can't reach or would
 * massively overshoot (shot_ai.gd:575).
 */
export function getCandidateClubs(
	gd: GolferData,
	distanceToHole: number,
	targetDistance: number,
): Club[] {
	const clubs: Club[] = []

	for (const clubType of [Club.DRIVER, Club.FAIRWAY_WOOD, Club.IRON, Club.WEDGE]) {
		const stats = CLUB_STATS[clubType]
		const skillFactor = getSkillDistanceFactor(clubType, gd)
		const maxDist = stats.maxDistance * skillFactor
		const minDist = stats.minDistance

		// Filter: club minimum must not massively overshoot the target
		// A club whose min distance is 2x the target is not appropriate
		if (minDist > targetDistance * 1.5 && minDist > distanceToHole * 1.2) continue

		// Filter: club must be able to reach a useful distance
		// (at least 50% of target distance or 50% of distance to hole)
		const usefulThreshold = Math.min(targetDistance, distanceToHole) * 0.5
		if (maxDist < usefulThreshold && distanceToHole > 2.0) continue

		clubs.push(clubType)
	}

	// Always have at least a wedge
	if (clubs.length === 0) clubs.push(Club.WEDGE)

	return clubs
}

// ============================================================================
// LANDING ZONE SCORING
// ============================================================================

/**
 * Score a landing zone considering terrain, distance, next-shot setup, and
 * personality (shot_ai.gd:608).
 */
export function scoreLandingZone(
	gd: GolferData,
	ballPos: Vec2,
	landing: Vec2,
	holePosition: Vec2,
	terrain: TerrainGrid,
	// Unused in the Godot source as well — kept for 1:1 signature parity.
	_club: Club,
	shotsRemaining: number,
): number {
	// --- Tree collision check (ball flight path) ---
	if (pathCrossesTrees(ballPos, landing, terrain)) {
		return -2000.0
	}

	// --- Graduated penalty for flying over tree canopy ---
	const treesOverflown = countTreesAlongPath(ballPos, landing, terrain)
	let treeFlyPenalty = 0.0
	if (treesOverflown > 0) {
		const riskFactor = 1.0 - gd.accuracySkill * 0.3
		// Dense tree lines (3+ consecutive) are near-impassable
		const densityMultiplier = 1.0 + Math.max(treesOverflown - 2, 0) * 0.5
		treeFlyPenalty = 50.0 * treesOverflown * riskFactor * densityMultiplier
	}

	// --- Base terrain score ---
	const terrainType = terrain.getTile(landing.x, landing.y)
	let score = terrainScore(terrainType)

	// --- Distance scoring: reward advancement toward hole ---
	const distanceToHole = vec.distance(landing, holePosition)
	const currentDistance = vec.distance(ballPos, holePosition)
	const advancement = currentDistance - distanceToHole

	// Harsh penalty for shots that don't advance
	if (advancement <= 0) {
		score -= 500.0
	}

	// --- Directional alignment: penalize sideways shots ---
	// A shot at 50° off-line barely advances but wastes distance laterally.
	// dot product: 1.0 = straight at hole, 0.0 = perpendicular, -1.0 = backwards.
	const shotVec = vec.sub(landing, ballPos)
	if (shotVec.x * shotVec.x + shotVec.y * shotVec.y > 0.01) {
		const holeDir = vec.normalize(vec.sub(holePosition, ballPos))
		const alignment = vec.dot(vec.normalize(shotVec), holeDir)
		// Scale penalty by shot distance — longer sideways shots are worse
		const shotLength = vec.length(shotVec)
		score += alignment * shotLength * 8.0 // Strong directional preference
	}

	// Score based on remaining distance, weighted by shot context
	if (shotsRemaining <= 1) {
		// Approach/attack: getting close to the hole is paramount
		score -= distanceToHole * 5.0
	} else {
		// Layup: advance toward the hole, terrain secondary
		score -= distanceToHole * 4.0
		// Bonus for landing at a good approach distance (wedge range)
		const idealRemaining = 3.5 // ~77 yards
		const distanceFromIdeal = Math.abs(distanceToHole - idealRemaining)
		if (distanceFromIdeal < 2.0) {
			score += (2.0 - distanceFromIdeal) * 25.0 // Up to +50 for ideal layup
		}
	}

	// --- Next-shot setup bonus ---
	// Reward landing zones that leave a clear path to the hole
	if (
		shotsRemaining > 1 &&
		(terrainType === TerrainType.FAIRWAY ||
			terrainType === TerrainType.GRASS ||
			terrainType === TerrainType.TEE_BOX)
	) {
		if (!pathCrossesTrees(landing, holePosition, terrain)) {
			score += 40.0 // Clear approach line bonus
		}
	}

	// --- Nearby hazard penalty (risk of rollout into trouble) ---
	score -= nearbyHazardPenalty(landing, terrain, gd.aggression)

	// --- Personality adjustments ---
	if (gd.aggression < 0.3) {
		// Cautious players extra-penalize hazards
		if (terrainType === TerrainType.BUNKER) score -= 80.0
		if (terrainType === TerrainType.ROUGH || terrainType === TerrainType.HEAVY_ROUGH) {
			score -= 30.0
		}
	} else if (gd.aggression > 0.7) {
		// Aggressive players discount hazard penalties slightly
		score += 20.0
	}

	// --- Situation awareness: score-based strategy ---
	score += situationModifier(gd, shotsRemaining)

	score -= treeFlyPenalty
	return score
}

/** Calculate penalty from nearby hazards (water, OB within 2 tiles) (shot_ai.gd:690). */
export function nearbyHazardPenalty(
	pos: Vec2,
	terrain: TerrainGrid,
	aggression: number,
): number {
	let penalty = 0.0
	for (let dx = -2; dx <= 2; dx++) {
		for (let dy = -2; dy <= 2; dy++) {
			if (dx === 0 && dy === 0) continue
			const cx = pos.x + dx
			const cy = pos.y + dy
			if (!terrain.isValidPosition(cx, cy)) continue
			const t = terrain.getTile(cx, cy)
			const dist = Math.hypot(dx, dy)
			if (
				t === TerrainType.WATER ||
				t === TerrainType.OUT_OF_BOUNDS ||
				t === TerrainType.EMPTY
			) {
				// Distance falloff: adjacent tiles (dist=1) are worst
				penalty += (20.0 / dist) * (1.0 - aggression * 0.5)
			} else if (t === TerrainType.TREES) {
				// Trees nearby add rollout risk penalty (less severe than water/OB)
				penalty += (10.0 / dist) * (1.0 - aggression * 0.3)
			}
		}
	}
	return penalty
}

/** Adjust scoring based on golfer's current situation, score relative to par (shot_ai.gd:710). */
export function situationModifier(gd: GolferData, shotsRemaining: number): number {
	if (gd.totalPar === 0) return 0.0 // No holes completed yet

	const scoreToPar = gd.totalStrokes - gd.totalPar

	// Behind par (over par): play more aggressively to catch up
	if (scoreToPar >= 3 && shotsRemaining <= 1) {
		return 15.0 // Slight bonus for aggressive approach targets
	}

	// Ahead of par (under par): play more conservatively to protect lead
	if (scoreToPar <= -2) {
		return -10.0 // Slight penalty for risky targets (favors safe options)
	}

	return 0.0
}

// ============================================================================
// RISK ANALYSIS — Miss distribution vs hazard overlap
// ============================================================================

// Deterministic spread sampling (evenly spaced across distribution)
// Use ±0.25σ, ±0.5σ, ±1.0σ, ±2.0σ for even coverage (shot_ai.gd:762)
const SIGMA_VALUES: readonly number[] = [-2.0, -1.0, -0.5, -0.25, 0.25, 0.5, 1.0, 2.0]

/**
 * Estimate how many of the golfer's typical misses would land in hazards
 * (shot_ai.gd:732). Samples the angular dispersion model deterministically.
 */
export function assessMissRisk(
	gd: GolferData,
	ballPos: Vec2,
	target: Vec2,
	terrain: TerrainGrid,
	club: Club,
): number {
	const stats = CLUB_STATS[club]
	const distance = vec.distance(ballPos, target)
	const direction = vec.normalize(vec.sub(target, ballPos))

	if (distance < 1.0) return 0.0

	// Calculate accuracy for spread estimation
	const skillAccuracy = getSkillAccuracy(club, gd)
	const ballTerrain = terrain.getTile(ballPos.x, ballPos.y)
	const bunkerDepth =
		ballTerrain === TerrainType.BUNKER ? terrain.getBunkerDepth(ballPos.x, ballPos.y) : 0
	const lieModifier = getLieModifier(ballTerrain, club, bunkerDepth)
	const totalAccuracy = stats.accuracyModifier * skillAccuracy * lieModifier

	// Angular spread (same model as calculateShot)
	const maxSpreadDeg = (1.0 - totalAccuracy) * 12.0
	const spreadStd = maxSpreadDeg / 2.5

	// Tendency bias
	const tendencyBias = gd.missTendency * (1.0 - totalAccuracy) * 6.0

	// Sample miss positions
	let hazardHits = 0
	for (let i = 0; i < MISS_SAMPLE_COUNT; i++) {
		const sampleAngleDeg = SIGMA_VALUES[i] * spreadStd + tendencyBias
		const sampleAngleRad = sampleAngleDeg * DEG_TO_RAD

		const missDir = vec.rotate(direction, sampleAngleRad)
		const missLanding = vec.add(ballPos, vec.round(vec.scale(missDir, distance)))

		if (!terrain.isValidPosition(missLanding.x, missLanding.y)) {
			hazardHits++
			continue
		}

		const missTerrain = terrain.getTile(missLanding.x, missLanding.y)
		if (missTerrain === TerrainType.WATER || missTerrain === TerrainType.OUT_OF_BOUNDS) {
			hazardHits++
		}
	}

	// Convert hit fraction to penalty
	// Each hazard hit in our sample represents ~12.5% of shots
	// Penalty scales: 1 hit = mild concern, 4+ hits = very dangerous
	const hitFraction = hazardHits / MISS_SAMPLE_COUNT
	let riskPenalty = hitFraction * 200.0 // Up to 200 points penalty

	// Aggressive golfers discount risk
	riskPenalty *= 1.0 - gd.aggression * 0.4

	return riskPenalty
}

// ============================================================================
// GREEN CENTER BIAS (for approach shots)
// ============================================================================

/**
 * For approach shots, less skilled golfers should aim more toward the green
 * center rather than directly at the pin (shot_ai.gd:795). This modifies
 * candidate aim points rather than overriding the best candidate after evaluation.
 */
export function applyGreenCenterBias(
	ctx: ShotAIContext,
	gd: GolferData,
	holePosition: Vec2,
	candidates: ShotCandidate[],
): void {
	const courseData = ctx.course
	if (!courseData || gd.currentHole >= courseData.holes.length) return

	const holeData = courseData.holes[gd.currentHole]
	const greenCenter = holeData.greenPosition
	if (
		(greenCenter.x === 0 && greenCenter.y === 0) ||
		(greenCenter.x === holePosition.x && greenCenter.y === holePosition.y)
	) {
		return
	}

	// Pin weight: pros aim 90% at pin, beginners aim 60% at pin (40% at center)
	const pinWeight = Math.min(Math.max(gd.accuracySkill * 0.6 + 0.4, 0.5), 0.95)

	for (const candidate of candidates) {
		// Only adjust approach-strategy candidates near the green
		if (candidate.strategy !== 'attack') continue

		const blended = vec.add(
			vec.scale(candidate.aimPoint, pinWeight),
			vec.scale(greenCenter, 1.0 - pinWeight),
		)
		candidate.aimPoint = vec.round(blended)
	}
}

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

/** Assess how good the current lie is: 0.0 = terrible, 1.0 = perfect (shot_ai.gd:823). */
export function assessLieQuality(terrainType: TerrainType): number {
	switch (terrainType) {
		case TerrainType.FAIRWAY:
		case TerrainType.TEE_BOX:
		case TerrainType.GREEN:
			return 1.0
		case TerrainType.GRASS:
			return 0.8
		case TerrainType.PATH:
			return 0.7
		case TerrainType.ROUGH:
			return 0.5
		case TerrainType.HEAVY_ROUGH:
			return 0.3
		case TerrainType.BUNKER:
			return 0.3
		case TerrainType.TREES:
			return 0.15
		case TerrainType.ROCKS:
			return 0.1
		case TerrainType.EMPTY:
		case TerrainType.OUT_OF_BOUNDS:
			return 0.0
		default:
			return 0.2
	}
}

// Note: shot_ai.gd's _get_skill_distance_factor and _get_shot_accuracy are the
// same formulas as getSkillDistanceFactor / getSkillAccuracy in clubs.ts, which
// this module imports instead of redefining.

/**
 * Check if a ball flight path crosses trees at low altitude (shot_ai.gd:880).
 * Trees block when ball is in the first/last 30% of flight (low trajectory).
 */
export function pathCrossesTrees(start: Vec2, end: Vec2, terrain: TerrainGrid): boolean {
	const distance = vec.distance(start, end)
	const numSamples = Math.trunc(distance) + 1

	for (let i = 0; i < numSamples; i++) {
		const t = i / Math.max(numSamples, 1)
		const samplePos = toTileTrunc(vec.lerp(start, end, t))

		if (!terrain.isValidPosition(samplePos.x, samplePos.y)) continue

		if (terrain.getTile(samplePos.x, samplePos.y) === TerrainType.TREES) {
			// Parabolic arc: ball is low at start and end, high in the middle
			const heightFactor = 4.0 * t * (1.0 - t)
			if (heightFactor < 0.3) return true // Must be above 30% of max height to clear
		}
	}

	return false
}

/** Count tree tiles along a flight path, for graduated risk penalty (shot_ai.gd:900). */
export function countTreesAlongPath(start: Vec2, end: Vec2, terrain: TerrainGrid): number {
	const distance = vec.distance(start, end)
	const numSamples = Math.trunc(distance) + 1
	let count = 0

	for (let i = 0; i < numSamples; i++) {
		const t = i / Math.max(numSamples, 1)
		const samplePos = toTileTrunc(vec.lerp(start, end, t))

		if (!terrain.isValidPosition(samplePos.x, samplePos.y)) continue

		if (terrain.getTile(samplePos.x, samplePos.y) === TerrainType.TREES) count++
	}

	return count
}

/** Create a ShotDecision from components (shot_ai.gd:918). */
function makeDecision(
	target: Vec2,
	club: Club,
	strategy: ShotStrategy,
	confidence: number,
): ShotDecision {
	return { target: { x: target.x, y: target.y }, club, strategy, confidence }
}
