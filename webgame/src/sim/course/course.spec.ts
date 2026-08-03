import { describe, expect, it } from 'vitest'
import { Rng } from '../core/rng'
import { TerrainGrid } from '../terrain/terrain-grid'
import { TerrainType } from '../terrain/terrain-types'
import { Tier } from '../golfer/tier'
import {
	createHole,
	getParForTee,
	getTeeForTier,
	rotatePin,
	HoleData,
} from './hole'
import { calculateCarries } from './forced-carry'
import { calculateHoleDifficulty } from './difficulty'
import { calculateStrokeIndices, applyStrokeIndices } from './stroke-index'

/** Build a simple straight par-4: tee at (20,64), 5x5 green centered (38,64). */
function buildHoleCourse(): { grid: TerrainGrid; hole: HoleData } {
	const grid = new TerrainGrid()
	grid.beginBatch()
	// Fairway corridor
	for (let x = 20; x <= 40; x++) {
		for (let y = 61; y <= 67; y++) grid.setTileNatural(x, y, TerrainType.FAIRWAY)
	}
	// Tee box
	for (let x = 19; x <= 21; x++) {
		for (let y = 63; y <= 65; y++) grid.setTileNatural(x, y, TerrainType.TEE_BOX)
	}
	// Green 5x5
	for (let x = 36; x <= 40; x++) {
		for (let y = 62; y <= 66; y++) grid.setTileNatural(x, y, TerrainType.GREEN)
	}
	grid.endBatchQuiet()
	const hole = createHole(1, { x: 20, y: 64 }, { x: 38, y: 64 }, { x: 38, y: 64 }, grid)
	return { grid, hole }
}

describe('HoleData (game_manager.gd HoleData parity)', () => {
	it('auto-derives par from yardage (18 tiles = 396yd = par 4)', () => {
		const { hole } = buildHoleCourse()
		expect(hole.distanceYards).toBe(396)
		expect(hole.par).toBe(4)
	})

	it('generates forward/middle tees at 40%/25% along the line', () => {
		const { hole } = buildHoleCourse()
		expect(hole.teePositions.back).toEqual({ x: 20, y: 64 })
		// 40% of 18 tiles = 7.2 → x=27; 25% = 4.5 → x=24 or 25 (rounding)
		expect(hole.teePositions.forward!.x).toBe(Math.round(20 + 18 * 0.4))
		expect(hole.teePositions.middle!.x).toBe(Math.round(20 + 18 * 0.25))
	})

	it('per-tee par: forward tee plays shorter', () => {
		const { hole } = buildHoleCourse()
		// Forward tee at x=27: 11 tiles = 242yd → par 3
		expect(getParForTee(hole, 'forward')).toBe(3)
		expect(getParForTee(hole, 'back')).toBe(4)
	})

	it('assigns tees by tier: beginners forward, pros back', () => {
		const { hole } = buildHoleCourse()
		const rng = new Rng(5)
		expect(getTeeForTier(hole, Tier.BEGINNER, rng)).toEqual(hole.teePositions.forward)
		expect(getTeeForTier(hole, Tier.PRO, rng)).toEqual(hole.teePositions.back)
		// Casual is a 50/50 forward/middle mix
		const casualTees = new Set<number>()
		for (let i = 0; i < 100; i++) casualTees.add(getTeeForTier(hole, Tier.CASUAL, rng).x)
		expect(casualTees.size).toBe(2)
	})

	it('generates up to 4 pins in green quadrants and rotates daily', () => {
		const { hole } = buildHoleCourse()
		expect(hole.pinPositions.length).toBeGreaterThanOrEqual(2)
		expect(hole.pinPositions.length).toBeLessThanOrEqual(4)
		const first = hole.holePosition
		rotatePin(hole)
		expect(hole.holePosition).not.toEqual(first)
		// Full cycle returns to the first pin
		for (let i = 1; i < hole.pinPositions.length; i++) rotatePin(hole)
		expect(hole.holePosition).toEqual(first)
	})

	it('single-tile green gets a single pin', () => {
		const grid = new TerrainGrid()
		grid.setTileNatural(38, 64, TerrainType.GREEN)
		const hole = createHole(1, { x: 20, y: 64 }, { x: 38, y: 64 }, { x: 38, y: 64 }, grid)
		expect(hole.pinPositions).toEqual([{ x: 38, y: 64 }])
	})
})

describe('ForcedCarryCalculator (forced_carry_calculator.gd parity)', () => {
	it('finds a water carry segment on the tee-to-pin line', () => {
		const { grid, hole } = buildHoleCourse()
		// Water band across the corridor at x 28-30
		for (let x = 28; x <= 30; x++) {
			for (let y = 60; y <= 68; y++) grid.setTileNatural(x, y, TerrainType.WATER)
		}
		const segments = calculateCarries(hole.teePosition, hole.holePosition, grid)
		expect(segments).toHaveLength(1)
		expect(segments[0].hazardType).toBe(TerrainType.WATER)
		// Carry from last safe fairway tile (x=27) to first safe after (x=31): 4 tiles = 88yd
		expect(segments[0].carryYards).toBe(88)
		expect(segments[0].exceedsBeginnerRange).toBe(false)
	})

	it('flags carries over 150 yards as exceeding beginner range', () => {
		const grid = new TerrainGrid()
		grid.beginBatch()
		for (let x = 10; x <= 50; x++) {
			for (let y = 62; y <= 66; y++) grid.setTileNatural(x, y, TerrainType.FAIRWAY)
		}
		// 8-tile water band = 176yd+ carry
		for (let x = 20; x <= 27; x++) {
			for (let y = 60; y <= 68; y++) grid.setTileNatural(x, y, TerrainType.WATER)
		}
		grid.endBatchQuiet()
		const segments = calculateCarries({ x: 12, y: 64 }, { x: 45, y: 64 }, grid)
		expect(segments).toHaveLength(1)
		expect(segments[0].carryYards).toBeGreaterThan(150)
		expect(segments[0].exceedsBeginnerRange).toBe(true)
	})
})

describe('DifficultyCalculator (difficulty_calculator.gd parity)', () => {
	it('a plain straight hole rates near its par baseline', () => {
		const { grid, hole } = buildHoleCourse()
		const difficulty = calculateHoleDifficulty(hole, grid)
		// Par 4 base = 2.0; big 25-tile green subtracts 0.2; no hazards
		expect(difficulty).toBeGreaterThanOrEqual(1.0)
		expect(difficulty).toBeLessThan(2.5)
	})

	it('water, bunkers, and elevation raise the rating', () => {
		const plain = buildHoleCourse()
		const plainRating = calculateHoleDifficulty(plain.hole, plain.grid)

		const hazardous = buildHoleCourse()
		// Water band forcing a carry + flanking bunkers + elevation steps
		for (let x = 28; x <= 30; x++) {
			for (let y = 60; y <= 68; y++) hazardous.grid.setTileNatural(x, y, TerrainType.WATER)
		}
		for (let y = 61; y <= 67; y++) hazardous.grid.setTileNatural(33, y, TerrainType.BUNKER)
		for (let x = 24; x <= 26; x++) {
			for (let y = 61; y <= 67; y++) hazardous.grid.setElevation(x, y, x - 23)
		}
		const hazardRating = calculateHoleDifficulty(hazardous.hole, hazardous.grid)
		expect(hazardRating).toBeGreaterThan(plainRating + 1.0)
	})

	it('clamps to the 1-10 range', () => {
		const { grid, hole } = buildHoleCourse()
		expect(calculateHoleDifficulty(hole, grid)).toBeGreaterThanOrEqual(1)
		expect(calculateHoleDifficulty(hole, grid)).toBeLessThanOrEqual(10)
	})
})

describe('StrokeIndexCalculator (stroke_index_calculator.gd parity)', () => {
	function fakeHole(holeNumber: number, difficulty: number, isOpen = true): HoleData {
		return {
			holeNumber,
			par: 4,
			teePosition: { x: 0, y: 0 },
			greenPosition: { x: 10, y: 0 },
			holePosition: { x: 10, y: 0 },
			distanceYards: 300,
			isOpen,
			difficultyRating: difficulty,
			strokeIndex: 0,
			totalRevenue: 0,
			parOverride: -1,
			teePositions: {},
			parByTee: {},
			pinPositions: [],
			currentPinIndex: 0,
		}
	}

	it('assigns 1 to the hardest hole for 9 or fewer', () => {
		const holes = [fakeHole(1, 3.0), fakeHole(2, 7.5), fakeHole(3, 5.0)]
		const indices = calculateStrokeIndices(holes)
		expect(indices.get(2)).toBe(1)
		expect(indices.get(3)).toBe(2)
		expect(indices.get(1)).toBe(3)
	})

	it('breaks difficulty ties by lower hole number', () => {
		const holes = [fakeHole(5, 4.0), fakeHole(2, 4.0)]
		const indices = calculateStrokeIndices(holes)
		expect(indices.get(2)).toBe(1)
		expect(indices.get(5)).toBe(2)
	})

	it('skips closed holes', () => {
		const holes = [fakeHole(1, 3.0), fakeHole(2, 9.0, false)]
		const indices = calculateStrokeIndices(holes)
		expect(indices.has(2)).toBe(false)
		expect(indices.get(1)).toBe(1)
	})

	it('interleaves front nine (odd) and back nine (even) for 18 holes', () => {
		const holes: HoleData[] = []
		for (let i = 1; i <= 18; i++) holes.push(fakeHole(i, 10 - i * 0.3))
		applyStrokeIndices(holes)
		for (const hole of holes) {
			if (hole.holeNumber <= 9) expect(hole.strokeIndex % 2).toBe(1)
			else expect(hole.strokeIndex % 2).toBe(0)
		}
		// All 18 indices assigned exactly once
		const all = holes.map((h) => h.strokeIndex).sort((a, b) => a - b)
		expect(all).toEqual(Array.from({ length: 18 }, (_, i) => i + 1))
		// Hardest front hole (hole 1) gets index 1
		expect(holes[0].strokeIndex).toBe(1)
		// Hardest back hole (hole 10) gets index 2
		expect(holes[9].strokeIndex).toBe(2)
	})
})
