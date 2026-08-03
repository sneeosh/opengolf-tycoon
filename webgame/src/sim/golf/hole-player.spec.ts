import { describe, expect, it } from 'vitest'
import { Rng } from '../core/rng'
import { vec } from '../core/vec'
import { TerrainGrid } from '../terrain/terrain-grid'
import { TerrainType } from '../terrain/terrain-types'
import { createHole } from '../course/hole'
import { playHole, HolePlayerGolfer } from './hole-player'
import type { ShotAIContext } from './shot-ai'

/** Straight 18-tile par-4 with fairway corridor and a 5x5 green. */
function buildPar4() {
	const grid = new TerrainGrid()
	grid.beginBatch()
	for (let x = 18; x <= 42; x++) {
		for (let y = 58; y <= 70; y++) grid.setTileNatural(x, y, TerrainType.ROUGH)
	}
	for (let x = 20; x <= 40; x++) {
		for (let y = 61; y <= 67; y++) grid.setTileNatural(x, y, TerrainType.FAIRWAY)
	}
	for (let x = 19; x <= 21; x++) {
		for (let y = 63; y <= 65; y++) grid.setTileNatural(x, y, TerrainType.TEE_BOX)
	}
	for (let x = 36; x <= 40; x++) {
		for (let y = 62; y <= 66; y++) grid.setTileNatural(x, y, TerrainType.GREEN)
	}
	grid.endBatchQuiet()
	const hole = createHole(1, { x: 20, y: 64 }, { x: 38, y: 64 }, { x: 38, y: 64 }, grid)
	return { grid, hole }
}

function golfer(skill: number, aggression = 0.5): HolePlayerGolfer {
	return {
		drivingSkill: skill,
		accuracySkill: skill,
		puttingSkill: skill,
		recoverySkill: skill,
		missTendency: 0.1,
		aggression,
		patience: 0.5,
	}
}

function ctx(grid: TerrainGrid, seed: number): ShotAIContext {
	return { terrain: grid, rng: new Rng(seed), wind: null, course: null }
}

describe('playHole (headless shot-by-shot loop)', () => {
	it('a pro holes out within the pickup cap and near par on average', () => {
		const { grid, hole } = buildPar4()
		const c = ctx(grid, 42)
		let totalStrokes = 0
		let holedCount = 0
		const rounds = 150
		for (let i = 0; i < rounds; i++) {
			const result = playHole(c, golfer(0.92), hole)
			expect(result.strokes).toBeLessThanOrEqual(hole.par + 3)
			totalStrokes += result.strokes
			if (result.holed) holedCount++
		}
		const avg = totalStrokes / rounds
		// Pros average close to par on a plain par 4
		expect(avg).toBeGreaterThan(3.0)
		expect(avg).toBeLessThan(4.8)
		expect(holedCount / rounds).toBeGreaterThan(0.9)
	})

	it('beginners score meaningfully worse than pros', { timeout: 30_000 }, () => {
		const { grid, hole } = buildPar4()
		const avg = (skill: number, seed: number) => {
			const c = ctx(grid, seed)
			let total = 0
			for (let i = 0; i < 60; i++) total += playHole(c, golfer(skill), hole).strokes
			return total / 60
		}
		expect(avg(0.32, 7)).toBeGreaterThan(avg(0.92, 8) + 0.7)
	})

	it('traces are contiguous: each shot starts where the last ended', () => {
		const { grid, hole } = buildPar4()
		const result = playHole(ctx(grid, 99), golfer(0.7), hole)
		for (let i = 1; i < result.trace.length; i++) {
			expect(result.trace[i].from).toEqual(result.trace[i - 1].to)
		}
		// First shot leaves the tee
		expect(result.trace[0].from).toEqual(hole.teePosition)
		// Holed rounds end at the cup
		if (result.holed) {
			const last = result.trace[result.trace.length - 1]
			expect(vec.distance(last.to, hole.holePosition)).toBeLessThan(0.05)
		}
	})

	it('water crossings incur penalty strokes and return the ball', () => {
		const { grid, hole } = buildPar4()
		// Water moat right in front of the green
		for (let x = 33; x <= 34; x++) {
			for (let y = 58; y <= 70; y++) grid.setTileNatural(x, y, TerrainType.WATER)
		}
		const c = ctx(grid, 1234)
		let sawPenalty = false
		for (let i = 0; i < 200 && !sawPenalty; i++) {
			const result = playHole(c, golfer(0.4, 0.9), hole)
			if (result.penalties > 0) {
				sawPenalty = true
				const penaltyEntry = result.trace.find((t) => t.isPenalty)!
				const idx = result.trace.indexOf(penaltyEntry)
				const shotBefore = result.trace[idx - 1]
				// Drop-at-entry: the drop point is NOT in water and lies short of
				// the water band (x < 33) on the tee side of the shot line
				const dropTile = vec.round(penaltyEntry.to)
				expect(grid.getTile(dropTile.x, dropTile.y)).not.toBe(TerrainType.WATER)
				expect(penaltyEntry.to.x).toBeLessThan(33)
				// The drop advanced the ball from where the shot was hit (entry
				// point relief, not stroke-and-distance back to the origin)
				expect(penaltyEntry.to.x).toBeGreaterThanOrEqual(shotBefore.from.x)
			}
		}
		expect(sawPenalty).toBe(true)
	})

	it('is deterministic for the same seed', () => {
		const { grid, hole } = buildPar4()
		const a = playHole(ctx(grid, 555), golfer(0.6), hole)
		const b = playHole(ctx(grid, 555), golfer(0.6), hole)
		expect(a).toEqual(b)
	})
})
