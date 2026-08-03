// Putting — port of golfer.gd _calculate_putt (lines 1349-1449), spec in
// docs/algorithms/putting-system.md. Probability-based make/miss model
// calibrated to PGA Tour stats: exponential-decay make rate, then realistic
// miss position (distance/lateral error, long bias, miss caps), constrained
// to stop at the green edge.

import type { Rng } from '../core/rng'
import { Vec2, vec } from '../core/vec'
import type { TerrainGrid } from '../terrain/terrain-grid'
import { TerrainType } from '../terrain/terrain-types'
import {
	CUP_RADIUS,
	TAP_IN_DISTANCE,
	getPuttMakeRate,
	getPuttMissCharacteristics,
} from './golf-rules'

export interface PuttResult {
	landingPrecise: Vec2
	distanceYards: number
	isMade: boolean
}

export function calculatePutt(
	terrain: TerrainGrid,
	rng: Rng,
	puttingSkill: number,
	fromPrecise: Vec2,
	holePos: Vec2,
): PuttResult {
	const distance = vec.distance(fromPrecise, holePos)
	const direction =
		distance > 0.001 ? vec.normalize(vec.sub(holePos, fromPrecise)) : { x: 0, y: 0 }
	const perpendicular = vec.perp(direction)

	let landing: Vec2

	if (distance < TAP_IN_DISTANCE) {
		landing = { ...holePos }
	} else {
		const makeRate = getPuttMakeRate(distance, puttingSkill)
		if (rng.randf() < makeRate) {
			landing = { ...holePos }
		} else {
			const miss = getPuttMissCharacteristics(distance, puttingSkill)
			// Positive distance error = past the hole
			const distanceError = rng.gaussian() * miss.distanceStd + miss.longBias
			const lateralError = rng.gaussian() * miss.lateralStd
			landing = vec.add(
				vec.add(holePos, vec.scale(direction, distanceError)),
				vec.scale(perpendicular, lateralError),
			)

			// Cap miss distance from the hole to prevent multi-putt cascades
			let maxMissFromHole: number
			if (distance < 0.15) {
				maxMissFromHole = 0.03 + (1.0 - puttingSkill) * 0.025 // ~2-3.6 ft
			} else if (distance < 0.45) {
				maxMissFromHole = 0.04 + (1.0 - puttingSkill) * 0.05 // ~2.6-5.9 ft
			} else {
				maxMissFromHole = distance * (0.08 + (1.0 - puttingSkill) * 0.12)
			}
			const missDist = vec.distance(landing, holePos)
			if (missDist > maxMissFromHole) {
				landing = vec.add(
					holePos,
					vec.scale(vec.normalize(vec.sub(landing, holePos)), maxMissFromHole),
				)
			}

			// Snap into the cup if the miss accidentally landed within it
			if (vec.distance(landing, holePos) < CUP_RADIUS) {
				landing = { ...holePos }
			}
		}
	}

	// Green edge constraint: if the landing tile isn't green, walk the path and
	// stop at the last green point. Fringe putts that never reach the green
	// keep their calculated landing (ball ends up on the fringe grass).
	const landingTile = vec.round(landing)
	if (
		!terrain.isValidPosition(landingTile.x, landingTile.y) ||
		terrain.getTile(landingTile.x, landingTile.y) !== TerrainType.GREEN
	) {
		const steps = Math.max(Math.trunc(vec.distance(fromPrecise, landing) * 10.0), 1)
		let lastValid = fromPrecise
		let enteredGreen = false
		for (let i = 1; i <= steps; i++) {
			const check = vec.lerp(fromPrecise, landing, i / steps)
			const checkTile = vec.round(check)
			if (
				terrain.isValidPosition(checkTile.x, checkTile.y) &&
				terrain.getTile(checkTile.x, checkTile.y) === TerrainType.GREEN
			) {
				enteredGreen = true
				lastValid = check
			} else if (enteredGreen) {
				break // left the green after entering — stop at the edge
			}
		}
		if (enteredGreen) landing = lastValid
	}

	const isMade = vec.distance(landing, holePos) < CUP_RADIUS
	return {
		landingPrecise: landing,
		distanceYards: Math.trunc(vec.distance(fromPrecise, landing) * 22.0),
		isMade,
	}
}
