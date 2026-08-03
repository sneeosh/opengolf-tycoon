import { describe, expect, it } from 'vitest'
import { Rng } from '../core/rng'
import { vec } from '../core/vec'
import { TerrainGrid } from '../terrain/terrain-grid'
import { TerrainType } from '../terrain/terrain-types'
import { getPuttMakeRate, TAP_IN_DISTANCE, CUP_RADIUS } from './golf-rules'
import { calculatePutt } from './putting'

/** A big green around the hole so edge constraints don't interfere. */
function greenGrid(): TerrainGrid {
	const grid = new TerrainGrid()
	grid.beginBatch()
	for (let x = 50; x < 80; x++) {
		for (let y = 50; y < 80; y++) grid.setTileNatural(x, y, TerrainType.GREEN)
	}
	grid.endBatchQuiet()
	return grid
}

const HOLE = { x: 64, y: 64 }

describe('calculatePutt (putting-system.md parity)', () => {
	it('tap-ins always drop', () => {
		const grid = greenGrid()
		const rng = new Rng(1)
		for (let i = 0; i < 500; i++) {
			const from = { x: HOLE.x - TAP_IN_DISTANCE * 0.9, y: HOLE.y }
			const r = calculatePutt(grid, rng, 0.1, from, HOLE)
			expect(r.isMade).toBe(true)
			expect(r.landingPrecise).toEqual(HOLE)
		}
	})

	it('observed make rate matches getPuttMakeRate at 10 feet, skill 0.95', () => {
		const grid = greenGrid()
		const rng = new Rng(777)
		const distTiles = 10 / 66
		const from = { x: HOLE.x - distTiles, y: HOLE.y }
		const expected = getPuttMakeRate(distTiles, 0.95)
		let made = 0
		const n = 20_000
		for (let i = 0; i < n; i++) {
			if (calculatePutt(grid, rng, 0.95, from, HOLE).isMade) made++
		}
		const observed = made / n
		expect(observed).toBeGreaterThan(expected - 0.02)
		expect(observed).toBeLessThan(expected + 0.02)
	})

	it('beginners make far fewer 10-footers than pros', () => {
		const grid = greenGrid()
		const distTiles = 10 / 66
		const from = { x: HOLE.x - distTiles, y: HOLE.y }
		const rate = (skill: number, seed: number) => {
			const rng = new Rng(seed)
			let made = 0
			for (let i = 0; i < 8000; i++) {
				if (calculatePutt(grid, rng, skill, from, HOLE).isMade) made++
			}
			return made / 8000
		}
		expect(rate(0.95, 10)).toBeGreaterThan(0.5)
		expect(rate(0.35, 11)).toBeLessThan(0.3)
	})

	it('misses respect the distance-category caps from the hole', () => {
		const grid = greenGrid()
		const cases: Array<{ dist: number; skill: number; cap: number }> = [
			// Short putt (<0.15): cap = 0.03 + (1-skill)*0.025
			{ dist: 0.12, skill: 0.5, cap: 0.03 + 0.5 * 0.025 },
			// Medium putt: cap = 0.04 + (1-skill)*0.05
			{ dist: 0.3, skill: 0.5, cap: 0.04 + 0.5 * 0.05 },
			// Long putt: cap = dist * (0.08 + (1-skill)*0.12)
			{ dist: 0.7, skill: 0.5, cap: 0.7 * (0.08 + 0.5 * 0.12) },
		]
		for (const { dist, skill, cap } of cases) {
			const rng = new Rng(Math.trunc(dist * 1000))
			const from = { x: HOLE.x - dist, y: HOLE.y }
			for (let i = 0; i < 4000; i++) {
				const r = calculatePutt(grid, rng, skill, from, HOLE)
				if (r.isMade) continue
				const missDist = vec.distance(r.landingPrecise, HOLE)
				expect(missDist).toBeLessThanOrEqual(cap + 1e-9)
				// Never closer than the cup radius without dropping
				expect(missDist).toBeGreaterThanOrEqual(CUP_RADIUS - 1e-9)
			}
		}
	})

	it('long putts show the pro long bias (misses end up past the hole on average)', () => {
		const grid = greenGrid()
		const rng = new Rng(31415)
		const dist = 0.5 // ~33 ft
		const from = { x: HOLE.x - dist, y: HOLE.y }
		let sumAlong = 0
		let misses = 0
		for (let i = 0; i < 12_000; i++) {
			const r = calculatePutt(grid, rng, 0.9, from, HOLE)
			if (r.isMade) continue
			misses++
			// Positive = past the hole (direction of the putt is +x)
			sumAlong += r.landingPrecise.x - HOLE.x
		}
		expect(sumAlong / misses).toBeGreaterThan(0)
	})

	it('putts that would run off the green stop at the green edge', () => {
		// Narrow green strip: x 60-68 only
		const grid = new TerrainGrid()
		grid.beginBatch()
		for (let x = 60; x <= 68; x++) grid.setTileNatural(x, 64, TerrainType.GREEN)
		grid.endBatchQuiet()
		const rng = new Rng(999)
		// Putt from the west edge at a hole near the east edge; long-bias misses
		// would run past x=68 onto grass — they must stop on the green.
		const from = { x: 60.2, y: 64 }
		const hole = { x: 68, y: 64 }
		for (let i = 0; i < 3000; i++) {
			const r = calculatePutt(grid, rng, 0.5, from, hole)
			const tile = vec.round(r.landingPrecise)
			expect(grid.getTile(tile.x, tile.y)).toBe(TerrainType.GREEN)
		}
	})
})
