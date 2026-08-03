// GolferTier — full port of scripts/systems/golfer_tier.gd.
// Four tiers with skill ranges, miss-tendency amplitudes, spawn weighting
// by course rating/fee/reputation/difficulty, and personality generation.

import type { Rng } from '../core/rng'
import type { GolferSkills } from '../golf/clubs'

export enum Tier {
	BEGINNER = 0,
	CASUAL = 1,
	SERIOUS = 2,
	PRO = 3,
}

export const ALL_TIERS: Tier[] = [Tier.BEGINNER, Tier.CASUAL, Tier.SERIOUS, Tier.PRO]

export interface TierData {
	name: string
	skillRange: [number, number]
	tendencyRange: [number, number]
	spendingModifier: number
	expectationTolerance: number
	minCourseRating: number
	minHoles: number
	reputationGain: number
	spawnWeightBase: number
}

export const TIER_DATA: Record<Tier, TierData> = {
	[Tier.BEGINNER]: {
		name: 'Beginner',
		skillRange: [0.3, 0.5],
		tendencyRange: [0.4, 0.8], // strong slice/hook bias
		spendingModifier: 0.7,
		expectationTolerance: 0.3,
		minCourseRating: 1.0,
		minHoles: 1,
		reputationGain: 1,
		spawnWeightBase: 0.35,
	},
	[Tier.CASUAL]: {
		name: 'Casual',
		skillRange: [0.5, 0.7],
		tendencyRange: [0.2, 0.5],
		spendingModifier: 1.0,
		expectationTolerance: 0.2,
		minCourseRating: 2.0,
		minHoles: 4,
		reputationGain: 2,
		spawnWeightBase: 0.4,
	},
	[Tier.SERIOUS]: {
		name: 'Serious',
		skillRange: [0.7, 0.85],
		tendencyRange: [0.1, 0.3],
		spendingModifier: 1.5,
		expectationTolerance: 0.1,
		minCourseRating: 3.0,
		minHoles: 9,
		reputationGain: 4,
		spawnWeightBase: 0.2,
	},
	[Tier.PRO]: {
		name: 'Pro',
		skillRange: [0.85, 0.98],
		tendencyRange: [0.0, 0.15], // nearly neutral shot shape
		spendingModifier: 2.0,
		expectationTolerance: 0.05,
		minCourseRating: 4.0,
		minHoles: 9,
		reputationGain: 10,
		spawnWeightBase: 0.05,
	},
}

export const TIER_NAMES: Record<Tier, string> = {
	[Tier.BEGINNER]: TIER_DATA[Tier.BEGINNER].name,
	[Tier.CASUAL]: TIER_DATA[Tier.CASUAL].name,
	[Tier.SERIOUS]: TIER_DATA[Tier.SERIOUS].name,
	[Tier.PRO]: TIER_DATA[Tier.PRO].name,
}

export interface CourseRatingInfo {
	overall: number // star rating 1-5 scale (Godot "overall")
	difficulty: number // 1-10
}

/** Spawn weights per tier for the current course conditions. */
export function calculateTierWeights(
	rating: CourseRatingInfo,
	greenFee: number,
	reputation: number,
	holeCount = 18,
): Record<Tier, number> {
	const weights = {} as Record<Tier, number>

	for (const tier of ALL_TIERS) {
		const data = TIER_DATA[tier]
		let weight = data.spawnWeightBase

		// Rating filter — drastically reduce, don't eliminate
		if (rating.overall < data.minCourseRating) weight *= 0.1

		// Hole count filter — nearly eliminate if the course is too short
		if (holeCount < data.minHoles) weight *= 0.05

		// High fees repel low tiers; bargains attract
		const feeFactor = greenFee / 50.0 // normalize around $50
		if (feeFactor > data.spendingModifier * 1.5) weight *= 0.3
		else if (feeFactor < data.spendingModifier * 0.5) weight *= 1.5

		// Reputation gates for the upper tiers
		if (tier === Tier.PRO && reputation < 70) weight *= 0.1
		else if (tier === Tier.SERIOUS && reputation < 50) weight *= 0.5

		// Difficulty preferences
		if (rating.difficulty >= 7.0) {
			if (tier === Tier.PRO) weight *= 2.0
			else if (tier === Tier.SERIOUS) weight *= 1.5
			else if (tier === Tier.BEGINNER) weight *= 0.5
		} else if (rating.difficulty >= 5.0) {
			if (tier === Tier.SERIOUS) weight *= 1.25
		} else if (rating.difficulty < 3.0) {
			if (tier === Tier.BEGINNER) weight *= 1.5
			else if (tier === Tier.CASUAL) weight *= 1.25
			else if (tier === Tier.PRO) weight *= 0.3
		}

		weights[tier] = weight
	}

	return weights
}

export function selectTier(
	rng: Rng,
	rating: CourseRatingInfo,
	greenFee: number,
	reputation: number,
	holeCount = 18,
): Tier {
	const weights = calculateTierWeights(rating, greenFee, reputation, holeCount)
	let total = 0
	for (const tier of ALL_TIERS) total += weights[tier]
	if (total <= 0) return Tier.CASUAL

	const roll = rng.randf() * total
	let cumulative = 0
	for (const tier of ALL_TIERS) {
		cumulative += weights[tier]
		if (roll <= cumulative) return tier
	}
	return Tier.CASUAL
}

/** Generate skill values for a tier (magnitude from tier, hook/slice sign random). */
export function generateSkills(rng: Rng, tier: Tier): GolferSkills {
	const data = TIER_DATA[tier]
	const [low, high] = data.skillRange
	const [tLow, tHigh] = data.tendencyRange
	const tendencyMagnitude = rng.randfRange(tLow, tHigh)
	const tendencySign = rng.randf() > 0.5 ? 1.0 : -1.0
	return {
		drivingSkill: rng.randfRange(low, high),
		accuracySkill: rng.randfRange(low, high),
		puttingSkill: rng.randfRange(low, high),
		recoverySkill: rng.randfRange(low, high),
		missTendency: tendencyMagnitude * tendencySign,
	}
}

export interface Personality {
	aggression: number
	patience: number
}

export function getPersonality(rng: Rng, tier: Tier): Personality {
	switch (tier) {
		case Tier.BEGINNER:
			return { aggression: rng.randfRange(0.2, 0.4), patience: rng.randfRange(0.6, 0.9) }
		case Tier.CASUAL:
			return { aggression: rng.randfRange(0.3, 0.6), patience: rng.randfRange(0.4, 0.7) }
		case Tier.SERIOUS:
			return { aggression: rng.randfRange(0.5, 0.7), patience: rng.randfRange(0.3, 0.6) }
		case Tier.PRO:
			return { aggression: rng.randfRange(0.6, 0.9), patience: rng.randfRange(0.2, 0.5) }
	}
}

const NAME_PREFIXES: Record<Tier, string[]> = {
	[Tier.BEGINNER]: ['Newbie', 'Rookie', 'First-timer'],
	[Tier.CASUAL]: ['Weekend', 'Casual'],
	[Tier.SERIOUS]: ['Avid', 'Regular', 'Dedicated'],
	[Tier.PRO]: ['Pro', 'Champion', 'Star'],
}

export function getNamePrefix(rng: Rng, tier: Tier): string {
	const prefixes = NAME_PREFIXES[tier]
	return prefixes[rng.randiRange(0, prefixes.length - 1)]
}

export function getReputationGain(tier: Tier): number {
	return TIER_DATA[tier].reputationGain
}

export function getPriceTolerance(tier: Tier): number {
	return TIER_DATA[tier].expectationTolerance
}
