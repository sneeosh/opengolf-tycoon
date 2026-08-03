import { describe, expect, it } from 'vitest'
import { Rng } from '../core/rng'
import { vec, DEG_TO_RAD } from '../core/vec'
import { TerrainGrid } from '../terrain/terrain-grid'
import { TerrainType } from '../terrain/terrain-types'
import { Club, GolferSkills } from './clubs'
import { calculateShot, computeTotalAccuracy, ShotContext } from './shot'
import { WindSystem } from '../world/wind'

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

/** Grid that is all fairway (flat) for clean statistical tests. */
function fairwayGrid(): TerrainGrid {
	const grid = new TerrainGrid()
	grid.beginBatch()
	for (let y = 0; y < grid.height; y++) {
		for (let x = 0; x < grid.width; x++) {
			grid.setTileNatural(x, y, TerrainType.FAIRWAY)
		}
	}
	grid.endBatchQuiet()
	return grid
}

function ctx(seed: number, grid = fairwayGrid(), wind: WindSystem | null = null): ShotContext {
	return { terrain: grid, rng: new Rng(seed), wind }
}

const FROM = { x: 20, y: 64 }

describe('computeTotalAccuracy (golden values from shot-accuracy.md)', () => {
	it('driver from fairway: club 0.70 x blend x lie 1.0', () => {
		const s = skills({ drivingSkill: 0.8, accuracySkill: 0.6 })
		// skill_accuracy = 0.8*0.7 + 0.6*0.3 = 0.74
		expect(computeTotalAccuracy(Club.DRIVER, s, 1.0, 12)).toBeCloseTo(0.7 * 0.74, 10)
	})

	it('iron from rough applies the 0.75 lie modifier', () => {
		const s = skills({ drivingSkill: 0.5, accuracySkill: 0.5 })
		// skill_accuracy = 0.5*0.4 + 0.5*0.6 = 0.5; total = 0.85*0.5*0.75
		expect(computeTotalAccuracy(Club.IRON, s, 0.75, 7)).toBeCloseTo(0.85 * 0.5 * 0.75, 10)
	})

	it('wedge short-game floor: 0.96 point-blank to 0.80 at max range', () => {
		const bad = skills({ accuracySkill: 0.1, recoverySkill: 0.1 })
		// Raw accuracy would be 0.95*0.1*1.0 = 0.095 — floor takes over
		expect(computeTotalAccuracy(Club.WEDGE, bad, 1.0, 0)).toBeCloseTo(0.96, 10)
		expect(computeTotalAccuracy(Club.WEDGE, bad, 1.0, 5)).toBeCloseTo(0.8, 10)
		expect(computeTotalAccuracy(Club.WEDGE, bad, 1.0, 2.5)).toBeCloseTo(0.88, 10)
	})

	it('putt floor scales with skill and distance', () => {
		const low = skills({ puttingSkill: 0.3 })
		const high = skills({ puttingSkill: 0.95 })
		// skill 0.3: floors lerp(0.85,0.95,0.3)=0.88 at 0 dist → lerp(0.50,0.80,0.3)=0.59 at max
		expect(computeTotalAccuracy(Club.PUTTER, low, 1.0, 0)).toBeCloseTo(0.88, 10)
		expect(computeTotalAccuracy(Club.PUTTER, low, 1.0, 1)).toBeCloseTo(0.59, 10)
		// skill 0.95: 0.945 at 0 dist; raw 0.98*0.95=0.931 exceeds long floor 0.785
		expect(computeTotalAccuracy(Club.PUTTER, high, 1.0, 0)).toBeCloseTo(0.945, 10)
		expect(computeTotalAccuracy(Club.PUTTER, high, 1.0, 1)).toBeCloseTo(0.931, 10)
	})
})

describe('calculateShot statistical behavior (10k seeded samples)', () => {
	const TARGET = { x: 32, y: 64 } // 12 tiles due east

	it('is deterministic for the same seed', () => {
		const a = calculateShot(ctx(42), skills(), FROM, TARGET, Club.DRIVER)
		const b = calculateShot(ctx(42), skills(), FROM, TARGET, Club.DRIVER)
		expect(a).toEqual(b)
	})

	it('~95% of non-shank shots land within max_spread_deg of the target line', () => {
		const c = ctx(1001)
		const s = skills({ drivingSkill: 0.6, accuracySkill: 0.6 })
		// total_accuracy = 0.7 * (0.6*0.7+0.6*0.3) * 1.0 = 0.42; max_spread = 6.96°
		const maxSpread = (1 - 0.42) * 12
		let within = 0
		let count = 0
		for (let i = 0; i < 10_000; i++) {
			const r = calculateShot(c, s, FROM, TARGET, Club.DRIVER)
			if (r.isShank) continue
			count++
			if (Math.abs(r.missAngleDeg) <= maxSpread) within++
		}
		// The CLT sum-of-4 gaussian has thinner tails than a true gaussian, so
		// coverage at 2.5 sigma lands ~99% (the doc's "~95%" is conservative).
		const ratio = within / count
		expect(ratio).toBeGreaterThan(0.95)
		expect(ratio).toBeLessThanOrEqual(1.0)
	})

	it('mean miss angle matches the tendency bias term', () => {
		const c = ctx(2002)
		const s = skills({ drivingSkill: 0.6, accuracySkill: 0.6, missTendency: 0.5 })
		// tendency_strength = 0.5 * (1-0.42) * 6 = 1.74°
		let sum = 0
		let count = 0
		for (let i = 0; i < 10_000; i++) {
			const r = calculateShot(c, s, FROM, TARGET, Club.DRIVER)
			if (r.isShank) continue
			sum += r.missAngleDeg
			count++
		}
		expect(sum / count).toBeGreaterThan(1.74 - 0.15)
		expect(sum / count).toBeLessThan(1.74 + 0.15)
	})

	it('shank rate ≈ (1-accuracy)*4% and shanks follow tendency sign', () => {
		const c = ctx(3003)
		const s = skills({ drivingSkill: 0.6, accuracySkill: 0.6, missTendency: -0.4 })
		const expectedRate = (1 - 0.42) * 0.04 // 2.32%
		let shanks = 0
		const n = 20_000
		for (let i = 0; i < n; i++) {
			const r = calculateShot(c, s, FROM, TARGET, Club.DRIVER)
			if (r.isShank) {
				shanks++
				// Hook tendency → shank goes left (negative angle), 35-55° off
				expect(r.missAngleDeg).toBeLessThanOrEqual(-35)
				expect(r.missAngleDeg).toBeGreaterThanOrEqual(-55)
			}
		}
		const rate = shanks / n
		expect(rate).toBeGreaterThan(expectedRate * 0.75)
		expect(rate).toBeLessThan(expectedRate * 1.25)
	})

	it('wedges and putters never shank', () => {
		const c = ctx(4004)
		const bad = skills({ accuracySkill: 0.05, recoverySkill: 0.05 })
		for (let i = 0; i < 3000; i++) {
			const r = calculateShot(c, bad, FROM, { x: 24, y: 64 }, Club.WEDGE)
			expect(r.isShank).toBe(false)
		}
	})

	it('carry distance never exceeds intended x max variance (no wind, flat)', () => {
		const c = ctx(5005)
		const s = skills({ drivingSkill: 0.9, accuracySkill: 0.9 })
		const intended = vec.distance(FROM, TARGET)
		for (let i = 0; i < 5000; i++) {
			const r = calculateShot(c, s, FROM, TARGET, Club.DRIVER)
			const carryDist = vec.distance(FROM, r.carryPrecise)
			// Max driver variance is 1.01; lateral floor adds a hair of length
			expect(carryDist).toBeLessThanOrEqual(intended * 1.01 * 1.05)
		}
	})

	it('pros cluster far tighter than beginners', () => {
		const pro = skills({ drivingSkill: 0.95, accuracySkill: 0.95 })
		const beginner = skills({ drivingSkill: 0.3, accuracySkill: 0.3 })
		const spread = (who: GolferSkills, seed: number) => {
			const c = ctx(seed)
			let sumSq = 0
			const n = 4000
			for (let i = 0; i < n; i++) {
				const r = calculateShot(c, who, FROM, TARGET, Club.DRIVER)
				if (r.isShank) continue
				// Lateral deviation from the target line (east), in tiles
				sumSq += (r.carryPrecise.y - FROM.y) ** 2
			}
			return Math.sqrt(sumSq / n)
		}
		// Accuracy 0.665 (pro) vs 0.21 (beginner) → spread ratio ~2.4x
		expect(spread(pro, 6006)).toBeLessThan(spread(beginner, 6007) / 2)
	})

	it('headwind shortens carry, tailwind lengthens it', () => {
		const wind = new WindSystem()
		wind.windSpeed = 25
		wind.windDirection = Math.PI / 2 // wind vector = (-25, 0): blows toward -x
		const s = skills({ drivingSkill: 0.8, accuracySkill: 0.8 })
		const meanCarry = (target: { x: number; y: number }, seed: number) => {
			const c = ctx(seed, fairwayGrid(), wind)
			let sum = 0
			const n = 2500
			for (let i = 0; i < n; i++) {
				const r = calculateShot(c, s, FROM, target, Club.DRIVER)
				sum += vec.distance(FROM, r.carryPrecise)
			}
			return sum / n
		}
		const intoWind = meanCarry({ x: 32, y: 64 }, 7007) // shooting +x into -x wind
		const withWind = meanCarry({ x: 8, y: 64 }, 7008) // shooting -x with the wind
		expect(intoWind).toBeLessThan(withWind * 0.93)
	})

	it('uphill targets play shorter (elevation distance modifier)', () => {
		const grid = fairwayGrid()
		// Raise a plateau at the target
		for (let x = 30; x < 35; x++)
			for (let y = 62; y < 67; y++) grid.setElevation(x, y, 5)
		const s = skills({ drivingSkill: 0.8, accuracySkill: 0.8 })
		const mean = (g: TerrainGrid, seed: number) => {
			const c = ctx(seed, g)
			let sum = 0
			for (let i = 0; i < 2500; i++) {
				sum += vec.distance(FROM, calculateShot(c, s, FROM, { x: 32, y: 64 }, Club.DRIVER).carryPrecise)
			}
			return sum / 2500
		}
		const uphill = mean(grid, 8008)
		const flat = mean(fairwayGrid(), 8009)
		// +5 elevation → x0.85 distance factor
		expect(uphill / flat).toBeGreaterThan(0.82)
		expect(uphill / flat).toBeLessThan(0.89)
	})

	it('shots from trees are wilder and shorter than from fairway', () => {
		const grid = fairwayGrid()
		grid.setTileNatural(FROM.x, FROM.y, TerrainType.TREES)
		const s = skills({ drivingSkill: 0.7, accuracySkill: 0.7 })
		const c = ctx(9009, grid)
		let sumDist = 0
		const n = 4000
		for (let i = 0; i < n; i++) {
			const r = calculateShot(c, s, FROM, { x: 29, y: 64 }, Club.IRON)
			sumDist += vec.distance(FROM, r.carryPrecise)
			// Lie modifier 0.3 crushes accuracy
			expect(r.totalAccuracy).toBeCloseTo(0.85 * 0.7 * 0.3, 10)
		}
		// Trees distance modifier is 0.6 of the 9-tile intent (before variance/loss)
		expect(sumDist / n).toBeLessThan(9 * 0.68)
	})
})

describe('angular dispersion geometry', () => {
	it('rotating by the miss angle lands the ball off the target line accordingly', () => {
		// Directly verify the rotation math the model relies on
		const dir = { x: 1, y: 0 }
		const rotated = vec.rotate(dir, 10 * DEG_TO_RAD)
		expect(rotated.x).toBeCloseTo(Math.cos(10 * DEG_TO_RAD), 10)
		expect(rotated.y).toBeCloseTo(Math.sin(10 * DEG_TO_RAD), 10)
	})
})
