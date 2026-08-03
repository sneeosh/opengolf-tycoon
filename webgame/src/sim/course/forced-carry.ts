// ForcedCarryCalculator — port of scripts/course/forced_carry_calculator.gd.
// Walks the tee-to-pin center line tracking contiguous water/bunker runs and
// measures the carry from the last fairway-quality safe tile.

import { Vec2, vec } from '../core/vec'
import type { TerrainGrid } from '../terrain/terrain-grid'
import { TerrainType } from '../terrain/terrain-types'

export interface CarrySegment {
	hazardType: TerrainType // WATER or BUNKER
	startGrid: Vec2 // last safe tile before hazard
	endGrid: Vec2 // first safe tile after hazard
	carryYards: number
	exceedsBeginnerRange: boolean // > 150 yards
}

const SAFE_TERRAIN: readonly TerrainType[] = [
	TerrainType.FAIRWAY,
	TerrainType.TEE_BOX,
	TerrainType.GREEN,
	TerrainType.PATH,
]

export function calculateCarries(
	tee: Vec2,
	pin: Vec2,
	terrain: TerrainGrid,
): CarrySegment[] {
	const segments: CarrySegment[] = []
	const direction = vec.sub(pin, tee)
	const length = vec.length(direction)
	if (length < 2.0) return segments

	const normalized = vec.normalize(direction)
	const numSamples = Math.trunc(length) + 1

	let inHazard = false
	let hazardType = TerrainType.WATER
	let lastSafePos = vec.round(tee)

	for (let i = 0; i <= numSamples; i++) {
		const t = i / numSamples
		const samplePos = vec.round(vec.add(tee, vec.scale(normalized, length * t)))
		if (!terrain.isValidPosition(samplePos.x, samplePos.y)) continue

		const terrainType = terrain.getTile(samplePos.x, samplePos.y)
		const isHazard = terrainType === TerrainType.WATER || terrainType === TerrainType.BUNKER

		if (isHazard && !inHazard) {
			inHazard = true
			hazardType = terrainType
		} else if (!isHazard && inHazard) {
			const carryYards = terrain.calculateDistanceYards(
				lastSafePos.x,
				lastSafePos.y,
				samplePos.x,
				samplePos.y,
			)
			segments.push({
				hazardType,
				startGrid: lastSafePos,
				endGrid: samplePos,
				carryYards,
				exceedsBeginnerRange: carryYards > 150,
			})
			inHazard = false
		}

		if (!isHazard && SAFE_TERRAIN.includes(terrainType)) {
			// Carry measures from where a golfer would reasonably land
			lastSafePos = samplePos
		}
	}

	return segments
}
