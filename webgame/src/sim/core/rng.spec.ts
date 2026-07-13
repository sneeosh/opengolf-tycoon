import { describe, expect, it } from 'vitest'
import { Rng } from './rng'

describe('Rng', () => {
	it('is deterministic for the same seed', () => {
		const a = new Rng(12345)
		const b = new Rng(12345)
		for (let i = 0; i < 100; i++) {
			expect(a.randf()).toBe(b.randf())
		}
	})

	it('produces different sequences for different seeds', () => {
		const a = new Rng(1)
		const b = new Rng(2)
		const seqA = Array.from({ length: 10 }, () => a.randf())
		const seqB = Array.from({ length: 10 }, () => b.randf())
		expect(seqA).not.toEqual(seqB)
	})

	it('randf stays in [0, 1)', () => {
		const rng = new Rng(999)
		for (let i = 0; i < 10_000; i++) {
			const v = rng.randf()
			expect(v).toBeGreaterThanOrEqual(0)
			expect(v).toBeLessThan(1)
		}
	})

	it('randfRange stays in [min, max)', () => {
		const rng = new Rng(7)
		for (let i = 0; i < 1000; i++) {
			const v = rng.randfRange(-3, 5)
			expect(v).toBeGreaterThanOrEqual(-3)
			expect(v).toBeLessThan(5)
		}
	})

	it('randiRange covers the inclusive range uniformly', () => {
		const rng = new Rng(42)
		const counts = new Map<number, number>()
		for (let i = 0; i < 10_000; i++) {
			const v = rng.randiRange(1, 6)
			counts.set(v, (counts.get(v) ?? 0) + 1)
		}
		expect([...counts.keys()].sort()).toEqual([1, 2, 3, 4, 5, 6])
		for (const count of counts.values()) {
			// ~1667 expected per face
			expect(count).toBeGreaterThan(1400)
			expect(count).toBeLessThan(1950)
		}
	})

	describe('gaussian (CLT sum-of-4 clone of Godot _gaussian_random)', () => {
		it('is bounded by ±(4-2)/0.5774 ≈ ±3.464', () => {
			const rng = new Rng(31337)
			for (let i = 0; i < 50_000; i++) {
				const v = rng.gaussian()
				expect(Math.abs(v)).toBeLessThanOrEqual(2.0 / 0.5774)
			}
		})

		it('has mean ~0 and std dev ~1 over 50k samples', () => {
			const rng = new Rng(2024)
			const n = 50_000
			let sum = 0
			let sumSq = 0
			for (let i = 0; i < n; i++) {
				const v = rng.gaussian()
				sum += v
				sumSq += v * v
			}
			const mean = sum / n
			const std = Math.sqrt(sumSq / n - mean * mean)
			expect(Math.abs(mean)).toBeLessThan(0.02)
			expect(std).toBeGreaterThan(0.95)
			expect(std).toBeLessThan(1.05)
		})

		it('~95% of samples fall within 2 std devs (bell-shaped, not uniform)', () => {
			const rng = new Rng(555)
			const n = 20_000
			let within2 = 0
			for (let i = 0; i < n; i++) {
				if (Math.abs(rng.gaussian()) <= 2.0) within2++
			}
			const ratio = within2 / n
			expect(ratio).toBeGreaterThan(0.93)
			expect(ratio).toBeLessThan(0.99)
		})
	})
})
