// Golfer tiers. Phase 3 needs only the enum (tee selection); the full
// GolferTier skill generator (spawn weights, skill ranges, miss-tendency
// amplitudes) is ported in Phase 4 from scripts/systems/golfer_tier.gd.

export enum Tier {
	BEGINNER = 0,
	CASUAL = 1,
	SERIOUS = 2,
	PRO = 3,
}

export const TIER_NAMES: Record<Tier, string> = {
	[Tier.BEGINNER]: 'Beginner',
	[Tier.CASUAL]: 'Casual',
	[Tier.SERIOUS]: 'Serious',
	[Tier.PRO]: 'Pro',
}
