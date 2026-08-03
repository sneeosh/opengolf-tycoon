// HoleData — port of the HoleData inner class from game_manager.gd:
// tee/green/cup positions, auto-par from yardage, multiple tee boxes
// (forward/middle/back), daily pin rotation across up to 4 positions.

import type { Rng } from '../core/rng'
import { Vec2, vec } from '../core/vec'
import type { TerrainGrid } from '../terrain/terrain-grid'
import { TerrainType } from '../terrain/terrain-types'
import { calculatePar } from '../golf/golf-rules'
import { Tier } from '../golfer/tier'

export type TeeKey = 'forward' | 'middle' | 'back'

export interface HoleData {
	holeNumber: number
	par: number
	teePosition: Vec2 // back tee (synced)
	greenPosition: Vec2
	holePosition: Vec2 // actual cup position (current pin)
	distanceYards: number
	isOpen: boolean
	difficultyRating: number // 1.0-10.0
	strokeIndex: number // 1 = hardest, 0 = unassigned
	totalRevenue: number
	parOverride: number // -1 = auto par from distance

	teePositions: Partial<Record<TeeKey, Vec2>>
	parByTee: Partial<Record<TeeKey, number>>

	pinPositions: Vec2[]
	currentPinIndex: number
}

export function createHole(
	holeNumber: number,
	tee: Vec2,
	green: Vec2,
	cup: Vec2,
	grid: TerrainGrid,
): HoleData {
	const distanceYards = grid.calculateDistanceYards(tee.x, tee.y, green.x, green.y)
	const hole: HoleData = {
		holeNumber,
		par: calculatePar(distanceYards),
		teePosition: tee,
		greenPosition: green,
		holePosition: cup,
		distanceYards,
		isOpen: true,
		difficultyRating: 1.0,
		strokeIndex: 0,
		totalRevenue: 0,
		parOverride: -1,
		teePositions: {},
		parByTee: {},
		pinPositions: [cup],
		currentPinIndex: 0,
	}
	autoGenerateTeePositions(hole, grid)
	autoGeneratePinPositions(hole, grid)
	recalculateParByTee(hole, grid)
	return hole
}

/** Keep teePosition synced with the back tee. */
export function syncTeePositions(hole: HoleData): void {
	if (hole.teePositions.back) hole.teePosition = hole.teePositions.back
}

/** Keep holePosition synced with the current pin. */
export function syncPinPosition(hole: HoleData): void {
	if (hole.pinPositions.length > 0 && hole.currentPinIndex < hole.pinPositions.length) {
		hole.holePosition = hole.pinPositions[hole.currentPinIndex]
	}
}

/** Rotate to the next pin position (called daily). */
export function rotatePin(hole: HoleData): void {
	if (hole.pinPositions.length === 0) return
	hole.currentPinIndex = (hole.currentPinIndex + 1) % hole.pinPositions.length
	syncPinPosition(hole)
}

/** Tee position for a golfer tier: beginners forward, pros back. */
export function getTeeForTier(hole: HoleData, tier: Tier, rng: Rng): Vec2 {
	const tees = hole.teePositions
	if (!tees.forward && !tees.middle && !tees.back) return hole.teePosition
	switch (tier) {
		case Tier.BEGINNER:
			return tees.forward ?? hole.teePosition
		case Tier.CASUAL:
			if (rng.randf() < 0.5) return tees.forward ?? hole.teePosition
			return tees.middle ?? hole.teePosition
		case Tier.SERIOUS:
			if (rng.randf() < 0.5) return tees.middle ?? hole.teePosition
			return tees.back ?? hole.teePosition
		case Tier.PRO:
			return tees.back ?? hole.teePosition
	}
}

/** Auto-generate forward (60% of distance) and middle (75%) tees. */
export function autoGenerateTeePositions(hole: HoleData, grid: TerrainGrid): void {
	const backTee = hole.teePosition
	const direction = vec.sub(hole.greenPosition, backTee)
	const length = vec.length(direction)
	if (length < 2.0) {
		hole.teePositions = { forward: backTee, middle: backTee, back: backTee }
		return
	}
	// Forward tee plays 60% of distance → 40% along tee→green; middle 75% → 25%
	const forwardPos = vec.round(vec.add(backTee, vec.scale(direction, 0.4)))
	const middlePos = vec.round(vec.add(backTee, vec.scale(direction, 0.25)))
	hole.teePositions = {
		forward: grid.isValidPosition(forwardPos.x, forwardPos.y) ? forwardPos : backTee,
		middle: grid.isValidPosition(middlePos.x, middlePos.y) ? middlePos : backTee,
		back: backTee,
	}
}

/** Flood-fill green tiles from a start point, capped at 100 tiles. */
export function floodGreenTiles(grid: TerrainGrid, start: Vec2): Vec2[] {
	const greenTiles: Vec2[] = []
	const toCheck: Vec2[] = [vec.round(start)]
	const checked = new Set<string>()
	while (toCheck.length > 0 && greenTiles.length < 100) {
		const pos = toCheck.shift()!
		const key = `${pos.x},${pos.y}`
		if (checked.has(key)) continue
		checked.add(key)
		if (!grid.isValidPosition(pos.x, pos.y)) continue
		if (grid.getTile(pos.x, pos.y) !== TerrainType.GREEN) continue
		greenTiles.push(pos)
		for (const [dx, dy] of [
			[1, 0],
			[-1, 0],
			[0, 1],
			[0, -1],
		] as const) {
			toCheck.push({ x: pos.x + dx, y: pos.y + dy })
		}
	}
	return greenTiles
}

/** Auto-generate up to 4 pin positions in the green's quadrants. */
export function autoGeneratePinPositions(hole: HoleData, grid: TerrainGrid): void {
	const greenTiles = floodGreenTiles(grid, hole.greenPosition)
	if (greenTiles.length <= 2) {
		// Too small for rotation — single pin
		hole.pinPositions = [hole.holePosition]
		hole.currentPinIndex = 0
		return
	}

	let center = { x: 0, y: 0 }
	for (const tile of greenTiles) center = vec.add(center, tile)
	center = vec.scale(center, 1 / greenTiles.length)

	const teeDir = vec.normalize(vec.sub(hole.greenPosition, hole.teePosition))
	const perpDir = vec.perp(teeDir)

	// Bucket tiles into front/back x left/right quadrants relative to center
	const quadrants: Record<string, Vec2[]> = { fl: [], fr: [], bl: [], br: [] }
	for (const tile of greenTiles) {
		const rel = vec.sub(tile, center)
		const key =
			(vec.dot(rel, teeDir) >= 0 ? 'f' : 'b') + (vec.dot(rel, perpDir) >= 0 ? 'l' : 'r')
		quadrants[key].push(tile)
	}

	// Pick the tile furthest from center in each populated quadrant
	const pins: Vec2[] = []
	for (const qkey of ['fl', 'fr', 'bl', 'br']) {
		const tiles = quadrants[qkey]
		if (tiles.length === 0) continue
		let best = tiles[0]
		let bestDist = 0
		for (const tile of tiles) {
			const d = vec.distance(tile, center)
			if (d > bestDist) {
				bestDist = d
				best = tile
			}
		}
		pins.push(best)
	}

	hole.pinPositions = pins.length > 0 ? pins : [hole.holePosition]
	hole.currentPinIndex = 0
	hole.holePosition = hole.pinPositions[0]
}

/** Recalculate per-tee par from each tee's yardage. */
export function recalculateParByTee(hole: HoleData, grid: TerrainGrid): void {
	for (const key of Object.keys(hole.teePositions) as TeeKey[]) {
		const tee = hole.teePositions[key]!
		const dist = grid.calculateDistanceYards(tee.x, tee.y, hole.greenPosition.x, hole.greenPosition.y)
		hole.parByTee[key] = calculatePar(dist)
	}
}

export function getParForTee(hole: HoleData, teeKey: TeeKey): number {
	return hole.parByTee[teeKey] ?? hole.par
}
