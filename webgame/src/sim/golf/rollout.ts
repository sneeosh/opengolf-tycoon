// Rollout — port of golfer.gd _calculate_rollout (lines 1739-1907), spec in
// docs/algorithms/ball-physics.md. Ground roll after carry: club-based roll
// fraction, backspin for skilled full wedges, terrain multiplier, slope
// blending, and a step-walked hazard check along the roll path.

import { Vec2, vec, lerp, clamp } from '../core/vec'
import { TerrainType } from '../terrain/terrain-types'
import { Club, CLUB_STATS, GolferSkills } from './clubs'
import type { ShotContext } from './shot'

export interface RolloutResult {
	finalPosition: Vec2
	rolloutDistance: number
	isBackspin: boolean
}

const TERRAIN_ROLL_MULT: Partial<Record<TerrainType, number>> = {
	[TerrainType.GREEN]: 1.3,
	[TerrainType.FAIRWAY]: 1.0,
	[TerrainType.TEE_BOX]: 1.0,
	[TerrainType.GRASS]: 0.35,
	[TerrainType.ROUGH]: 0.3,
	[TerrainType.HEAVY_ROUGH]: 0.12,
	[TerrainType.TREES]: 0.2,
	[TerrainType.ROCKS]: 0.15,
	[TerrainType.PATH]: 1.4,
}

export function calculateRollout(
	ctx: ShotContext,
	skills: GolferSkills,
	club: Club,
	carryPrecise: Vec2,
	shotOrigin: Vec2,
	carryDistance: number,
): RolloutResult {
	const { terrain, rng } = ctx
	const noRollout: RolloutResult = {
		finalPosition: carryPrecise,
		rolloutDistance: 0,
		isBackspin: false,
	}

	const carryTile = vec.round(carryPrecise)
	const carryTerrain = terrain.getTile(carryTile.x, carryTile.y)

	// No roll if the ball lands in water, OB/empty, bunker (plugs), or flowers
	if (
		carryTerrain === TerrainType.WATER ||
		carryTerrain === TerrainType.OUT_OF_BOUNDS ||
		carryTerrain === TerrainType.EMPTY ||
		carryTerrain === TerrainType.BUNKER ||
		carryTerrain === TerrainType.FLOWER_BED
	) {
		return noRollout
	}

	// Base roll fraction of carry distance
	let rolloutMin: number
	let rolloutMax: number
	let isWedgeChip = false
	switch (club) {
		case Club.DRIVER:
			rolloutMin = 0.05
			rolloutMax = 0.15
			break
		case Club.FAIRWAY_WOOD:
			rolloutMin = 0.05
			rolloutMax = 0.14
			break
		case Club.IRON:
			rolloutMin = 0.05
			rolloutMax = 0.14
			break
		case Club.WEDGE: {
			const distanceRatio = carryDistance / CLUB_STATS[Club.WEDGE].maxDistance
			if (distanceRatio > 0.65) {
				// Full wedge — backspin potential
				rolloutMin = -0.04
				rolloutMax = 0.08
			} else {
				// Chip — always rolls forward
				isWedgeChip = true
				rolloutMin = 0.06
				rolloutMax = 0.18
			}
			break
		}
		default:
			return noRollout
	}

	// Skewed-toward-middle sample of the roll fraction
	const rollT = clamp(rng.randf() * 0.6 + rng.randf() * 0.4, 0, 1)
	let baseRolloutFraction = lerp(rolloutMin, rolloutMax, rollT)

	// Backspin for skilled full wedge shots
	let isBackspin = false
	if (club === Club.WEDGE && !isWedgeChip) {
		const spinSkill = skills.accuracySkill * 0.6 + skills.recoverySkill * 0.4
		if (spinSkill > 0.7) {
			const spinBonus = (spinSkill - 0.7) / 0.3
			baseRolloutFraction -= spinBonus * 0.1
		}
		baseRolloutFraction = Math.max(baseRolloutFraction, -0.04)
		if (baseRolloutFraction < 0) isBackspin = true
	}

	let terrainRollMult = TERRAIN_ROLL_MULT[carryTerrain] ?? 0.3
	// Backspin is on the ball, not the surface — only 40% of terrain effect
	if (isBackspin) terrainRollMult = lerp(1.0, terrainRollMult, 0.4)

	const rolloutFraction = baseRolloutFraction * terrainRollMult
	let rolloutDistance = carryDistance * Math.abs(rolloutFraction)

	// Below ~3 yards of roll, treat as no rollout
	if (rolloutDistance < 0.15) return noRollout

	// Roll direction: shot line (reversed for backspin), blended toward slope
	const shotDirection = vec.normalize(vec.sub(carryPrecise, shotOrigin))
	let rollDirection = isBackspin ? vec.scale(shotDirection, -1) : shotDirection

	const slope = terrain.getSlopeDirection(carryTile.x, carryTile.y)
	if (vec.length(slope) > 0) {
		const slopeInfluence = clamp(rolloutDistance / 3.0, 0.1, 0.5)
		rollDirection = vec.normalize(
			vec.add(vec.scale(rollDirection, 1.0 - slopeInfluence), vec.scale(slope, slopeInfluence)),
		)
	}

	const slopeDot = vec.dot(slope, rollDirection)
	if (slopeDot > 0) {
		rolloutDistance *= 1.0 + slopeDot * 0.5 // downhill: up to +50%
	} else if (slopeDot < 0) {
		rolloutDistance *= Math.max(0.2, 1.0 + slopeDot * 0.5) // uphill
	}

	// Walk the roll path in quarter-tile steps, checking for hazards
	let finalPosition = carryPrecise
	let steps = Math.ceil(rolloutDistance * 4.0)
	const stepSize = rolloutDistance / Math.max(steps, 1)

	for (let i = 1; i <= steps; i++) {
		const checkPoint = vec.add(carryPrecise, vec.scale(rollDirection, stepSize * i))
		const checkTile = vec.round(checkPoint)
		if (!terrain.isValidPosition(checkTile.x, checkTile.y)) break

		const checkTerrain = terrain.getTile(checkTile.x, checkTile.y)
		if (checkTerrain === TerrainType.WATER) {
			finalPosition = checkPoint // ball goes in the water
			break
		}
		if (checkTerrain === TerrainType.OUT_OF_BOUNDS || checkTerrain === TerrainType.EMPTY) {
			finalPosition = checkPoint // ball goes OB
			break
		}
		if (checkTerrain === TerrainType.BUNKER) {
			finalPosition = checkPoint // ball plugs into sand
			break
		}
		// Entering rough decelerates the remaining roll
		if (checkTerrain === TerrainType.ROUGH && carryTerrain !== TerrainType.ROUGH) {
			rolloutDistance *= 0.6
			steps = Math.ceil(rolloutDistance * 4.0)
		}
		finalPosition = checkPoint
	}

	return {
		finalPosition,
		rolloutDistance: vec.distance(carryPrecise, finalPosition),
		isBackspin,
	}
}
