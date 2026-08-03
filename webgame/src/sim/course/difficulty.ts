// DifficultyCalculator — port of scripts/course/difficulty_calculator.gd.
// Per-hole rating 1.0-10.0 from par, corridor hazards, elevation change,
// doglegs, green size/slope, landing-zone hazards, and forced carries.

import { Vec2, vec, clamp } from '../core/vec'
import type { TerrainGrid } from '../terrain/terrain-grid'
import { TerrainType } from '../terrain/terrain-types'
import type { HoleData } from './hole'
import { floodGreenTiles } from './hole'
import { calculateCarries } from './forced-carry'

export function calculateHoleDifficulty(hole: HoleData, terrain: TerrainGrid): number {
	// Base difficulty from par: Par 3 = 1.0, Par 4 = 2.0, Par 5 = 3.0
	const baseDifficulty = hole.par - 2.0

	const corridorTiles = getCorridorTiles(hole.teePosition, hole.greenPosition, terrain, 10)

	const total =
		baseDifficulty +
		hazardDifficulty(corridorTiles, terrain) +
		elevationDifficulty(hole, terrain) +
		doglegDifficulty(hole, terrain) +
		greenDifficulty(hole, terrain) +
		landingZoneDifficulty(hole, terrain) +
		carryDifficulty(hole, terrain)

	return clamp(total, 1.0, 10.0)
}

function hazardDifficulty(corridorTiles: Vec2[], terrain: TerrainGrid): number {
	let waterCount = 0
	let obCount = 0
	let treeCount = 0
	let bunkerDifficulty = 0
	for (const pos of corridorTiles) {
		switch (terrain.getTile(pos.x, pos.y)) {
			case TerrainType.WATER:
				waterCount++
				break
			case TerrainType.BUNKER:
				bunkerDifficulty += terrain.getBunkerDepth(pos.x, pos.y) === 1 ? 0.25 : 0.15
				break
			case TerrainType.OUT_OF_BOUNDS:
				obCount++
				break
			case TerrainType.TREES:
				treeCount++
				break
		}
	}
	return waterCount * 0.3 + bunkerDifficulty + obCount * 0.2 + treeCount * 0.1
}

function elevationDifficulty(hole: HoleData, terrain: TerrainGrid): number {
	const tee = hole.teePosition
	const green = hole.greenPosition
	const direction = vec.normalize(vec.sub(green, tee))
	const distance = vec.distance(tee, green)
	const samples = Math.trunc(distance) + 1
	if (samples < 2) return 0

	let totalChange = 0
	const teeTile = vec.round(tee)
	let prevElevation = terrain.getElevation(teeTile.x, teeTile.y)
	for (let i = 1; i <= samples; i++) {
		const t = i / samples
		const samplePos = vec.round(vec.add(tee, vec.scale(direction, distance * t)))
		if (terrain.isValidPosition(samplePos.x, samplePos.y)) {
			const elevation = terrain.getElevation(samplePos.x, samplePos.y)
			totalChange += Math.abs(elevation - prevElevation)
			prevElevation = elevation
		}
	}
	return clamp(totalChange * 0.15, 0, 1.5)
}

function doglegDifficulty(hole: HoleData, terrain: TerrainGrid): number {
	const tee = hole.teePosition
	const green = hole.greenPosition
	const directDirection = vec.normalize(vec.sub(green, tee))
	const distance = vec.distance(tee, green)

	if (hole.par >= 4 && distance > 8) {
		const midpoint = vec.round(vec.scale(vec.add(tee, green), 0.5))
		const perpendicular = vec.perp(directDirection)

		let hasLeftFairway = false
		let hasRightFairway = false
		for (let offset = 2; offset < 6; offset++) {
			const left = vec.round(vec.add(midpoint, vec.scale(perpendicular, offset)))
			const right = vec.round(vec.sub(midpoint, vec.scale(perpendicular, offset)))
			if (
				terrain.isValidPosition(left.x, left.y) &&
				terrain.getTile(left.x, left.y) === TerrainType.FAIRWAY
			) {
				hasLeftFairway = true
			}
			if (
				terrain.isValidPosition(right.x, right.y) &&
				terrain.getTile(right.x, right.y) === TerrainType.FAIRWAY
			) {
				hasRightFairway = true
			}
		}
		// Fairway extending to only one side = significant dogleg
		if (hasLeftFairway !== hasRightFairway) return 0.8
	}
	return 0
}

function greenDifficulty(hole: HoleData, terrain: TerrainGrid): number {
	const greenTiles = floodGreenTiles(terrain, hole.greenPosition)
	const greenSize = greenTiles.length

	let sizeDifficulty = 0
	if (greenSize < 2) sizeDifficulty = 0.8 // tiny green — demanding target
	else if (greenSize < 4) sizeDifficulty = 0.4
	else if (greenSize > 6) sizeDifficulty = -0.2 // large green is easier

	let slopeDifficulty = 0
	if (greenTiles.length > 1) {
		let minElev = Infinity
		let maxElev = -Infinity
		for (const tile of greenTiles) {
			const elev = terrain.getElevation(tile.x, tile.y)
			minElev = Math.min(minElev, elev)
			maxElev = Math.max(maxElev, elev)
		}
		slopeDifficulty = clamp((maxElev - minElev) * 0.25, 0, 0.6)
	}

	return sizeDifficulty + slopeDifficulty
}

function landingZoneDifficulty(hole: HoleData, terrain: TerrainGrid): number {
	const tee = hole.teePosition
	const green = hole.greenPosition
	const direction = vec.normalize(vec.sub(green, tee))
	const totalDistance = vec.distance(tee, green)

	// Par 4: one landing zone ~220yd out; par 5: a second for the layup
	const landingZones: number[] = []
	if (hole.par >= 4) landingZones.push(10.0)
	if (hole.par >= 5) landingZones.push(Math.min(totalDistance - 6, 18.0))

	let difficulty = 0
	for (const lzDistance of landingZones) {
		if (lzDistance > totalDistance) continue
		const lzCenter = vec.round(vec.add(tee, vec.scale(direction, lzDistance)))
		for (let dx = -3; dx <= 3; dx++) {
			for (let dy = -3; dy <= 3; dy++) {
				const x = lzCenter.x + dx
				const y = lzCenter.y + dy
				if (!terrain.isValidPosition(x, y)) continue
				switch (terrain.getTile(x, y)) {
					case TerrainType.WATER:
						difficulty += 0.15
						break
					case TerrainType.BUNKER:
						difficulty += 0.08
						break
					case TerrainType.OUT_OF_BOUNDS:
						difficulty += 0.12
						break
				}
			}
		}
	}
	return clamp(difficulty, 0, 1.5)
}

function carryDifficulty(hole: HoleData, terrain: TerrainGrid): number {
	const segments = calculateCarries(hole.teePosition, hole.holePosition, terrain)
	let difficulty = 0
	for (const seg of segments) {
		if (seg.hazardType === TerrainType.WATER) {
			if (seg.carryYards > 200) difficulty += 1.5
			else if (seg.carryYards > 150) difficulty += 1.0
			else if (seg.carryYards > 100) difficulty += 0.5
			else difficulty += 0.2
		} else if (seg.hazardType === TerrainType.BUNKER) {
			if (seg.carryYards > 150) difficulty += 0.5
			else if (seg.carryYards > 80) difficulty += 0.3
			else difficulty += 0.1
		}
	}
	return clamp(difficulty, 0, 2.0)
}

/** Tiles in a corridor between two points (matches _get_corridor_tiles). */
export function getCorridorTiles(
	from: Vec2,
	to: Vec2,
	terrain: TerrainGrid,
	width: number,
): Vec2[] {
	const tiles: Vec2[] = []
	const seen = new Set<string>()
	const direction = vec.sub(to, from)
	const length = vec.length(direction)
	if (length < 1.0) return tiles

	const normalized = vec.normalize(direction)
	const perp = vec.perp(normalized)
	const halfWidth = Math.trunc(width / 2)

	const steps = Math.trunc(length) + 1
	for (let i = 0; i < steps; i++) {
		const t = i / Math.max(steps - 1, 1)
		const center = vec.add(from, vec.scale(direction, t))
		for (let w = -halfWidth; w <= halfWidth; w++) {
			const samplePos = vec.round(vec.add(center, vec.scale(perp, w)))
			const key = `${samplePos.x},${samplePos.y}`
			if (terrain.isValidPosition(samplePos.x, samplePos.y) && !seen.has(key)) {
				seen.add(key)
				tiles.push(samplePos)
			}
		}
	}
	return tiles
}
