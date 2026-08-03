// Full-swing shot engine — port of golfer.gd _calculate_shot (lines 1452-1712),
// reimplemented from docs/algorithms/shot-accuracy.md. Angular dispersion model:
// the shot direction is rotated by a gaussian miss angle, with persistent
// hook/slice tendency, rare shanks, a lateral dispersion floor for short shots,
// topped/fat distance loss, and wind/terrain/elevation distance modifiers.

import type { Rng } from '../core/rng'
import { Vec2, vec, lerp, clamp, DEG_TO_RAD } from '../core/vec'
import type { TerrainGrid } from '../terrain/terrain-grid'
import { TerrainType } from '../terrain/terrain-types'
import { Club, CLUB_STATS, GolferSkills, getSkillAccuracy, getDistanceVarianceRange } from './clubs'
import { getLieModifier, getTerrainDistanceModifier } from './golf-rules'
import type { WindSystem } from '../world/wind'
import { calculateRollout } from './rollout'

export interface ShotContext {
	terrain: TerrainGrid
	rng: Rng
	wind?: WindSystem | null
}

export interface ShotResult {
	/** Final resting position (after rollout), sub-tile precision. */
	landingPrecise: Vec2
	/** Carry position (first ground contact), sub-tile precision. */
	carryPrecise: Vec2
	distanceYards: number
	totalAccuracy: number
	club: Club
	rolloutTiles: number
	isBackspin: boolean
	missAngleDeg: number
	isShank: boolean
}

/**
 * Total accuracy for a shot: club modifier x skill blend x lie, with the
 * wedge short-game floor and skill-scaled putt floor (golfer.gd:1487-1510).
 */
export function computeTotalAccuracy(
	club: Club,
	skills: GolferSkills,
	lieModifier: number,
	distanceToTarget: number,
): number {
	const stats = CLUB_STATS[club]
	let totalAccuracy = stats.accuracyModifier * getSkillAccuracy(club, skills) * lieModifier

	if (club === Club.WEDGE) {
		// Close chips are always accurate: floor 0.96 point-blank -> 0.80 at max range
		const distanceRatio = clamp(distanceToTarget / stats.maxDistance, 0, 1)
		totalAccuracy = Math.max(totalAccuracy, lerp(0.96, 0.8, distanceRatio))
	}
	if (club === Club.PUTTER) {
		const distanceRatio = clamp(distanceToTarget / stats.maxDistance, 0, 1)
		const skillFloorMin = lerp(0.5, 0.8, skills.puttingSkill)
		const skillFloorMax = lerp(0.85, 0.95, skills.puttingSkill)
		totalAccuracy = Math.max(totalAccuracy, lerp(skillFloorMax, skillFloorMin, distanceRatio))
	}
	return totalAccuracy
}

/**
 * Execute a full-swing shot (not a putt — see putting.ts for the green).
 * `from` and `target` are grid positions (tiles); sub-tile floats allowed.
 */
export function calculateShot(
	ctx: ShotContext,
	skills: GolferSkills,
	from: Vec2,
	target: Vec2,
	club: Club,
): ShotResult {
	const { terrain, rng, wind } = ctx
	const stats = CLUB_STATS[club]
	const fromTile = vec.round(from)
	const currentTerrain = terrain.getTile(fromTile.x, fromTile.y)
	const bunkerDepth =
		currentTerrain === TerrainType.BUNKER ? terrain.getBunkerDepth(fromTile.x, fromTile.y) : 0
	const distanceToTarget = vec.distance(from, target)

	const lieModifier = getLieModifier(currentTerrain, club, bunkerDepth)
	const totalAccuracy = computeTotalAccuracy(club, skills, lieModifier, distanceToTarget)

	// Distance modifier: per-shot execution variance x terrain x wind x elevation
	const variance = getDistanceVarianceRange(club)
	let distanceModifier = variance.base + rng.randfRange(variance.min, variance.max)
	distanceModifier *= getTerrainDistanceModifier(currentTerrain, bunkerDepth)

	const direction = vec.normalize(vec.sub(target, from))
	if (wind) {
		distanceModifier *= wind.getDistanceModifier(direction, club)
	}
	const targetTile = vec.round(target)
	const elevationDiff = terrain.getElevationDifference(
		fromTile.x,
		fromTile.y,
		targetTile.x,
		targetTile.y,
	)
	distanceModifier *= clamp(1.0 - elevationDiff * 0.03, 0.75, 1.25)

	let actualDistance = distanceToTarget * distanceModifier

	// Angular spread: worst case 12 deg, ~95% of shots within max via /2.5
	const maxSpreadDeg = (1.0 - totalAccuracy) * 12.0
	let spreadStdDev = maxSpreadDeg / 2.5
	if (club === Club.WEDGE) {
		// Controlled partial swings are tighter
		const wedgeRatio = clamp(actualDistance / stats.maxDistance, 0, 1)
		spreadStdDev *= lerp(0.3, 1.0, wedgeRatio)
	}

	const baseAngleDeg = rng.gaussian() * spreadStdDev
	const tendencyStrength = skills.missTendency * (1.0 - totalAccuracy) * 6.0
	let missAngleDeg = baseAngleDeg + tendencyStrength

	// Rare catastrophic shank (full swings only)
	let isShank = false
	if (club !== Club.PUTTER && club !== Club.WEDGE) {
		const shankChance = (1.0 - totalAccuracy) * 0.04
		if (rng.randf() < shankChance) {
			isShank = true
			let shankDir: number
			if (skills.missTendency > 0) shankDir = 1
			else if (skills.missTendency < 0) shankDir = -1
			else shankDir = rng.randf() < 0.5 ? 1 : -1
			missAngleDeg = shankDir * rng.randfRange(35.0, 55.0)
			actualDistance *= rng.randfRange(0.3, 0.6)
		}
	}

	const missDirection = vec.rotate(direction, missAngleDeg * DEG_TO_RAD)
	let landingPoint = vec.add(from, vec.scale(missDirection, actualDistance))

	// Lateral dispersion floor: the angular model clusters too tightly at short
	// range; add extra lateral scatter so beginners spread across the green.
	if (club !== Club.PUTTER) {
		const angularLateralStd = actualDistance * Math.sin(spreadStdDev * DEG_TO_RAD)
		const minLateralStd = (1.0 - totalAccuracy) * 0.8
		if (angularLateralStd < minLateralStd) {
			const extraStd = Math.sqrt(minLateralStd ** 2 - angularLateralStd ** 2)
			landingPoint = vec.add(
				landingPoint,
				vec.scale(vec.perp(missDirection), rng.gaussian() * extraStd),
			)
		}
	}

	// Topped/fat shots lose distance (never gain)
	const distanceLoss = Math.abs(rng.gaussian()) * (1.0 - totalAccuracy) * 0.12
	landingPoint = vec.sub(landingPoint, vec.scale(missDirection, actualDistance * distanceLoss))

	// Crosswind displacement
	if (wind) {
		landingPoint = vec.add(landingPoint, wind.getWindDisplacement(direction, actualDistance, club))
	}

	let carryPrecise = landingPoint
	let carryTile = vec.round(carryPrecise)
	if (!terrain.isValidPosition(carryTile.x, carryTile.y)) {
		carryPrecise = { ...target }
		carryTile = vec.round(target)
	}

	// Rollout after carry
	const rollout = calculateRollout(ctx, skills, club, carryPrecise, from, actualDistance)
	let finalPrecise = rollout.finalPosition
	const finalTile = vec.round(finalPrecise)
	if (!terrain.isValidPosition(finalTile.x, finalTile.y)) {
		finalPrecise = carryPrecise
	}

	return {
		landingPrecise: finalPrecise,
		carryPrecise,
		distanceYards: Math.trunc(vec.distance(from, finalPrecise) * 22.0),
		totalAccuracy,
		club,
		rolloutTiles: rollout.rolloutDistance,
		isBackspin: rollout.isBackspin,
		missAngleDeg,
		isShank,
	}
}
