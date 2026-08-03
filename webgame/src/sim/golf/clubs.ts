// Club definitions — port of CLUB_STATS and the per-club skill blends from
// scripts/entities/golfer.gd. Distances are in tiles (1 tile = 22 yards).

export enum Club {
	DRIVER = 0,
	FAIRWAY_WOOD = 1,
	IRON = 2,
	WEDGE = 3,
	PUTTER = 4,
}

export interface ClubStats {
	name: string
	maxDistance: number // tiles
	minDistance: number // tiles
	accuracyModifier: number
}

export const CLUB_STATS: Record<Club, ClubStats> = {
	[Club.DRIVER]: { name: 'Driver', maxDistance: 14, minDistance: 9, accuracyModifier: 0.7 },
	[Club.FAIRWAY_WOOD]: {
		name: 'Fairway Wood',
		maxDistance: 11,
		minDistance: 8,
		accuracyModifier: 0.78,
	},
	[Club.IRON]: { name: 'Iron', maxDistance: 9, minDistance: 5, accuracyModifier: 0.85 },
	[Club.WEDGE]: { name: 'Wedge', maxDistance: 5, minDistance: 2, accuracyModifier: 0.95 },
	[Club.PUTTER]: { name: 'Putter', maxDistance: 1, minDistance: 0, accuracyModifier: 0.98 },
}

/** Skill snapshot used by the shot engine (subset of the golfer entity). */
export interface GolferSkills {
	drivingSkill: number
	accuracySkill: number
	puttingSkill: number
	recoverySkill: number
	/** Persistent hook(-)/slice(+) bias, -1..+1. */
	missTendency: number
}

/** Per-club skill accuracy blend (golfer.gd:1475-1485). */
export function getSkillAccuracy(club: Club, s: GolferSkills): number {
	switch (club) {
		case Club.DRIVER:
			return s.drivingSkill * 0.7 + s.accuracySkill * 0.3
		case Club.FAIRWAY_WOOD:
			return s.drivingSkill * 0.5 + s.accuracySkill * 0.5
		case Club.IRON:
			return s.drivingSkill * 0.4 + s.accuracySkill * 0.6
		case Club.WEDGE:
			return s.accuracySkill * 0.7 + s.recoverySkill * 0.3
		case Club.PUTTER:
			return s.puttingSkill
	}
}

/**
 * Fraction of a club's max distance this golfer can carry
 * (golfer.gd:1305-1318). Used by targeting so golfers aim within range.
 */
export function getSkillDistanceFactor(club: Club, s: GolferSkills): number {
	switch (club) {
		case Club.DRIVER:
			return 0.4 + s.drivingSkill * 0.55
		case Club.FAIRWAY_WOOD:
			return 0.4 + s.drivingSkill * 0.5
		case Club.IRON:
			return 0.5 + s.accuracySkill * 0.42
		case Club.WEDGE:
			return 0.8 + s.accuracySkill * 0.18
		case Club.PUTTER:
			return 0.92 + s.puttingSkill * 0.06
	}
}

/** Distance execution variance range per club (golfer.gd:1516-1526). */
export function getDistanceVarianceRange(club: Club): { base: number; min: number; max: number } {
	switch (club) {
		case Club.DRIVER:
			return { base: 0.97, min: -0.06, max: 0.04 } // 0.91-1.01
		case Club.FAIRWAY_WOOD:
			return { base: 0.97, min: -0.05, max: 0.04 } // 0.92-1.01
		case Club.IRON:
			return { base: 0.98, min: -0.04, max: 0.03 } // 0.94-1.01
		case Club.WEDGE:
			return { base: 0.98, min: -0.03, max: 0.02 } // 0.95-1.00
		case Club.PUTTER:
			return { base: 0.99, min: -0.02, max: 0.01 } // 0.97-1.00
	}
}
