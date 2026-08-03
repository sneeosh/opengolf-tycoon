import { describe, expect, it } from 'vitest'
import { Rng } from '../core/rng'
import {
	ALL_TIERS,
	calculateTierWeights,
	generateSkills,
	getPersonality,
	getReputationGain,
	selectTier,
	Tier,
	TIER_DATA,
} from './tier'

const GOOD_COURSE = { overall: 4.5, difficulty: 5.5 }

describe('GolferTier (golfer_tier.gd parity)', () => {
	it('generates skills within tier ranges with tier-scaled tendency', () => {
		const rng = new Rng(1)
		for (const tier of ALL_TIERS) {
			const [low, high] = TIER_DATA[tier].skillRange
			const [tLow, tHigh] = TIER_DATA[tier].tendencyRange
			for (let i = 0; i < 500; i++) {
				const s = generateSkills(rng, tier)
				for (const v of [s.drivingSkill, s.accuracySkill, s.puttingSkill, s.recoverySkill]) {
					expect(v).toBeGreaterThanOrEqual(low)
					expect(v).toBeLessThan(high)
				}
				expect(Math.abs(s.missTendency)).toBeGreaterThanOrEqual(tLow)
				expect(Math.abs(s.missTendency)).toBeLessThanOrEqual(tHigh)
			}
		}
	})

	it('miss tendency sign is ~50/50 hook vs slice', () => {
		const rng = new Rng(2)
		let hooks = 0
		for (let i = 0; i < 4000; i++) {
			if (generateSkills(rng, Tier.CASUAL).missTendency < 0) hooks++
		}
		expect(hooks / 4000).toBeGreaterThan(0.45)
		expect(hooks / 4000).toBeLessThan(0.55)
	})

	it('pros avoid low-reputation courses (weight x0.1 under rep 70)', () => {
		const lowRep = calculateTierWeights(GOOD_COURSE, 50, 40)
		const highRep = calculateTierWeights(GOOD_COURSE, 50, 90)
		expect(lowRep[Tier.PRO]).toBeCloseTo(highRep[Tier.PRO] * 0.1, 10)
	})

	it('short courses nearly eliminate serious/pro golfers', () => {
		const nineHoles = calculateTierWeights(GOOD_COURSE, 50, 90, 9)
		const threeHoles = calculateTierWeights(GOOD_COURSE, 50, 90, 3)
		expect(threeHoles[Tier.SERIOUS]).toBeCloseTo(nineHoles[Tier.SERIOUS] * 0.05, 10)
		expect(threeHoles[Tier.PRO]).toBeCloseTo(nineHoles[Tier.PRO] * 0.05, 10)
	})

	it('high fees repel beginners, bargains attract them', () => {
		// Beginner spending modifier 0.7: fee factor > 1.05 → x0.3; < 0.35 → x1.5
		const pricey = calculateTierWeights(GOOD_COURSE, 60, 60)
		const bargain = calculateTierWeights(GOOD_COURSE, 15, 60)
		expect(pricey[Tier.BEGINNER]).toBeCloseTo(0.35 * 0.3, 10)
		expect(bargain[Tier.BEGINNER]).toBeCloseTo(0.35 * 1.5, 10)
	})

	it('hard courses double pro weight, easy courses attract beginners', () => {
		const hard = calculateTierWeights({ overall: 4.5, difficulty: 8 }, 50, 90)
		const easy = calculateTierWeights({ overall: 4.5, difficulty: 2 }, 50, 90)
		expect(hard[Tier.PRO] / easy[Tier.PRO]).toBeCloseTo(2.0 / 0.3, 5)
		expect(easy[Tier.BEGINNER]).toBeCloseTo(0.35 * 1.5, 10)
	})

	it('selectTier respects the weight distribution', () => {
		const rng = new Rng(77)
		// Budget beginner haven: low rating, low fee, low rep, few holes
		const counts: Record<Tier, number> = { 0: 0, 1: 0, 2: 0, 3: 0 }
		for (let i = 0; i < 5000; i++) {
			counts[selectTier(rng, { overall: 1.5, difficulty: 2 }, 15, 20, 6)]++
		}
		// Beginners should dominate; pros nearly absent
		expect(counts[Tier.BEGINNER]).toBeGreaterThan(counts[Tier.SERIOUS])
		expect(counts[Tier.PRO]).toBeLessThan(100)
	})

	it('personality scales with tier (pros aggressive, beginners patient)', () => {
		const rng = new Rng(9)
		for (let i = 0; i < 200; i++) {
			const beginner = getPersonality(rng, Tier.BEGINNER)
			const pro = getPersonality(rng, Tier.PRO)
			expect(beginner.aggression).toBeLessThanOrEqual(0.4)
			expect(beginner.patience).toBeGreaterThanOrEqual(0.6)
			expect(pro.aggression).toBeGreaterThanOrEqual(0.6)
			expect(pro.patience).toBeLessThanOrEqual(0.5)
		}
	})

	it('reputation gains match the tier table', () => {
		expect(getReputationGain(Tier.BEGINNER)).toBe(1)
		expect(getReputationGain(Tier.CASUAL)).toBe(2)
		expect(getReputationGain(Tier.SERIOUS)).toBe(4)
		expect(getReputationGain(Tier.PRO)).toBe(10)
	})
})
