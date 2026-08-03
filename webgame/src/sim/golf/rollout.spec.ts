import { describe, expect, it } from 'vitest'
import { Rng } from '../core/rng'
import { vec } from '../core/vec'
import { TerrainGrid } from '../terrain/terrain-grid'
import { TerrainType } from '../terrain/terrain-types'
import { Club, GolferSkills } from './clubs'
import { calculateRollout } from './rollout'
import type { ShotContext } from './shot'

function skills(overrides: Partial<GolferSkills> = {}): GolferSkills {
	return {
		drivingSkill: 0.5,
		accuracySkill: 0.5,
		puttingSkill: 0.5,
		recoverySkill: 0.5,
		missTendency: 0,
		...overrides,
	}
}

function grid(fill: TerrainType): TerrainGrid {
	const g = new TerrainGrid()
	g.beginBatch()
	for (let y = 0; y < g.height; y++) {
		for (let x = 0; x < g.width; x++) g.setTileNatural(x, y, fill)
	}
	g.endBatchQuiet()
	return g
}

function ctx(seed: number, g: TerrainGrid): ShotContext {
	return { terrain: g, rng: new Rng(seed), wind: null }
}

const ORIGIN = { x: 20, y: 64 }
const CARRY = { x: 32, y: 64 } // 12 tiles east
const CARRY_DIST = 12

describe('calculateRollout (ball-physics.md parity)', () => {
	it('driver on fairway rolls 5-15% of carry (x1.0 terrain)', () => {
		const c = ctx(1, grid(TerrainType.FAIRWAY))
		for (let i = 0; i < 3000; i++) {
			const r = calculateRollout(c, skills(), Club.DRIVER, CARRY, ORIGIN, CARRY_DIST)
			expect(r.isBackspin).toBe(false)
			// Either below the 0.15-tile visibility threshold, or within fraction bounds
			if (r.rolloutDistance > 0) {
				expect(r.rolloutDistance).toBeGreaterThanOrEqual(0.15)
				expect(r.rolloutDistance).toBeLessThanOrEqual(CARRY_DIST * 0.15 + 1e-9)
				// Rolls forward (east)
				expect(r.finalPosition.x).toBeGreaterThan(CARRY.x)
			}
		}
	})

	it('landing on the green rolls farther than heavy rough (1.3x vs 0.12x)', () => {
		const mean = (terrain: TerrainType, seed: number) => {
			const c = ctx(seed, grid(terrain))
			let sum = 0
			const n = 4000
			for (let i = 0; i < n; i++) {
				sum += calculateRollout(c, skills(), Club.DRIVER, CARRY, ORIGIN, CARRY_DIST)
					.rolloutDistance
			}
			return sum / n
		}
		const green = mean(TerrainType.GREEN, 2)
		const heavyRough = mean(TerrainType.HEAVY_ROUGH, 3)
		expect(green).toBeGreaterThan(heavyRough * 5)
		// Heavy rough kills almost all roll: 12 * 0.15 * 0.12 = 0.216 max
		expect(heavyRough).toBeLessThan(0.25)
	})

	it('no rollout when the ball lands in bunker, water, or flowers', () => {
		for (const t of [TerrainType.BUNKER, TerrainType.WATER, TerrainType.FLOWER_BED]) {
			const c = ctx(4, grid(t))
			const r = calculateRollout(c, skills(), Club.DRIVER, CARRY, ORIGIN, CARRY_DIST)
			expect(r.rolloutDistance).toBe(0)
			expect(r.finalPosition).toEqual(CARRY)
		}
	})

	it('skilled full wedges can spin backwards; chips never do', () => {
		const spinner = skills({ accuracySkill: 0.95, recoverySkill: 0.95 }) // spin_skill 0.95
		const fairway = grid(TerrainType.GREEN)
		// Full wedge: carry ratio > 0.65 of max 5 tiles → 4 tiles
		const fullCarry = { x: 24, y: 64 }
		let backspins = 0
		const c = ctx(5, fairway)
		for (let i = 0; i < 4000; i++) {
			const r = calculateRollout(c, spinner, Club.WEDGE, fullCarry, ORIGIN, 4)
			if (r.isBackspin) {
				backspins++
				// Ball rolled back toward the origin (west)
				expect(r.finalPosition.x).toBeLessThan(fullCarry.x)
			}
		}
		expect(backspins).toBeGreaterThan(0)

		// Chip (ratio 0.4 < 0.65): never backspin, always forward
		const c2 = ctx(6, fairway)
		for (let i = 0; i < 2000; i++) {
			const r = calculateRollout(c2, spinner, Club.WEDGE, { x: 22, y: 64 }, ORIGIN, 2)
			expect(r.isBackspin).toBe(false)
		}
	})

	it('skilled players backspin full wedges far more often than hackers', () => {
		// Source parity note: golfer.gd samples the full-wedge roll fraction from
		// lerp(-0.04, 0.08), so even unskilled players occasionally spin one back
		// slightly — skill (>0.7 spin_skill) shifts the distribution negative.
		const count = (s: GolferSkills, seed: number) => {
			const c = ctx(seed, grid(TerrainType.GREEN))
			let backspins = 0
			for (let i = 0; i < 4000; i++) {
				if (calculateRollout(c, s, Club.WEDGE, { x: 24, y: 64 }, ORIGIN, 4).isBackspin) {
					backspins++
				}
			}
			return backspins
		}
		const hacker = count(skills({ accuracySkill: 0.4, recoverySkill: 0.4 }), 7)
		const spinner = count(skills({ accuracySkill: 0.95, recoverySkill: 0.95 }), 8)
		expect(spinner).toBeGreaterThan(hacker * 2)
	})

	it('roll into water stops the ball in the water', () => {
		const g = grid(TerrainType.GREEN)
		// Water wall just east of the carry point
		for (let y = 0; y < g.height; y++) g.setTileNatural(34, y, TerrainType.WATER)
		const c = ctx(8, g)
		let wetBalls = 0
		for (let i = 0; i < 3000; i++) {
			const r = calculateRollout(c, skills(), Club.DRIVER, { x: 33.4, y: 64 }, ORIGIN, CARRY_DIST)
			const tile = vec.round(r.finalPosition)
			if (g.getTile(tile.x, tile.y) === TerrainType.WATER) {
				wetBalls++
				// Stopped at the water's edge, not rolled through to x=35+
				expect(r.finalPosition.x).toBeLessThan(34.6)
			}
		}
		expect(wetBalls).toBeGreaterThan(0)
	})

	it('downhill slope extends roll versus flat', () => {
		const flat = grid(TerrainType.FAIRWAY)
		const sloped = grid(TerrainType.FAIRWAY)
		// Descending staircase east of the carry point: downhill in roll direction
		for (let x = 30; x < 45; x++) {
			for (let y = 55; y < 75; y++) sloped.setElevation(x, y, Math.max(-5, 35 - x))
		}
		const mean = (g: TerrainGrid, seed: number) => {
			const c = ctx(seed, g)
			let sum = 0
			for (let i = 0; i < 4000; i++) {
				sum += calculateRollout(c, skills(), Club.DRIVER, CARRY, ORIGIN, CARRY_DIST)
					.rolloutDistance
			}
			return sum / 4000
		}
		expect(mean(sloped, 9)).toBeGreaterThan(mean(flat, 10) * 1.15)
	})
})
