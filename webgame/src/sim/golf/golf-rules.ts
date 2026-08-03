// GolfRules — direct port of scripts/systems/golf_rules.gd.
// Single source of truth for scoring, penalties, par, lie modifiers,
// putting make rates, and club wind sensitivity. Pure functions, no state.
// References: USGA Rules of Golf (2023), PGA Tour putting statistics.

import { TerrainType } from '../terrain/terrain-types'
import { Club } from './clubs'

// ---- Scoring ----

export function getScoreName(strokes: number, par: number): string {
	if (strokes === 1) return 'Hole-in-One'
	const diff = strokes - par
	switch (diff) {
		case -3:
			return 'Albatross'
		case -2:
			return 'Eagle'
		case -1:
			return 'Birdie'
		case 0:
			return 'Par'
		case 1:
			return 'Bogey'
		case 2:
			return 'Double Bogey'
		case 3:
			return 'Triple Bogey'
		default:
			return diff > 0 ? `+${diff}` : `${diff}`
	}
}

export type ScoreClass =
	| 'hole_in_one'
	| 'eagle'
	| 'birdie'
	| 'par'
	| 'bogey'
	| 'double_bogey_plus'

export function classifyScore(strokes: number, par: number): ScoreClass {
	if (strokes === 1) return 'hole_in_one'
	const diff = strokes - par
	if (diff <= -2) return 'eagle'
	if (diff === -1) return 'birdie'
	if (diff === 0) return 'par'
	if (diff === 1) return 'bogey'
	return 'double_bogey_plus'
}

// ---- Par (USGA men's guidelines) ----

export function calculatePar(distanceYards: number): number {
	if (distanceYards <= 250) return 3
	if (distanceYards <= 470) return 4
	return 5
}

/** Max strokes before pickup (casual pace-of-play rule: triple bogey). */
export function getMaxStrokes(par: number): number {
	return par + 3
}

// ---- Penalties & relief ----

export enum ReliefType {
	NONE = 0,
	DROP_AT_ENTRY = 1, // 1 stroke, drop at point of entry (water)
	STROKE_AND_DISTANCE = 2, // 1 stroke, replay from previous position (OB)
	FREE_RELIEF = 3, // no penalty (cart path, GUR)
}

export function getPenaltyStrokes(terrain: TerrainType): number {
	return terrain === TerrainType.WATER || terrain === TerrainType.OUT_OF_BOUNDS ? 1 : 0
}

export function getReliefType(terrain: TerrainType): ReliefType {
	switch (terrain) {
		case TerrainType.WATER:
			return ReliefType.DROP_AT_ENTRY
		case TerrainType.OUT_OF_BOUNDS:
			return ReliefType.STROKE_AND_DISTANCE
		case TerrainType.FLOWER_BED:
		case TerrainType.EMPTY:
			return ReliefType.FREE_RELIEF
		default:
			return ReliefType.NONE
	}
}

// ---- Holing ----

/** Cup radius in tiles (~8 inches). */
export const CUP_RADIUS = 0.01
/** Tap-in distance in tiles (~3 feet, inside-the-leather gimme). */
export const TAP_IN_DISTANCE = 0.045

export const FEET_PER_TILE = 66.0 // 1 tile = 22 yards = 66 feet

// ---- Putting make rates (PGA-Tour-calibrated exponential decay) ----

export function getPuttMakeRate(distanceTiles: number, puttingSkill: number): number {
	if (distanceTiles < TAP_IN_DISTANCE) return 1.0
	const distanceFeet = distanceTiles * FEET_PER_TILE
	const baseDecay = 0.053
	const skillMultiplier = 1.0 + (1.0 - puttingSkill) * 2.5
	const makeRate = Math.exp(-distanceFeet * baseDecay * skillMultiplier)
	return Math.max(makeRate, 0.01)
}

export interface PuttMissCharacteristics {
	distanceStd: number
	lateralStd: number
	longBias: number
}

export function getPuttMissCharacteristics(
	distanceTiles: number,
	puttingSkill: number,
): PuttMissCharacteristics {
	const distanceFeet = distanceTiles * FEET_PER_TILE

	let distanceStd: number
	if (distanceFeet < 10.0) {
		distanceStd = 0.015 + (1.0 - puttingSkill) * 0.02
	} else if (distanceFeet < 30.0) {
		distanceStd = 0.03 + (1.0 - puttingSkill) * 0.06
	} else {
		// Lag putting: error proportional to distance
		distanceStd = distanceTiles * (0.06 + (1.0 - puttingSkill) * 0.12)
	}

	let lateralStd: number
	if (distanceFeet < 10.0) {
		lateralStd = 0.008 + (1.0 - puttingSkill) * 0.017
	} else if (distanceFeet < 30.0) {
		lateralStd = 0.015 + (1.0 - puttingSkill) * 0.035
	} else {
		lateralStd = 0.025 + (1.0 - puttingSkill) * 0.06
	}

	// "Never up, never in" — better players hit firmer
	const longBias = 0.02 + puttingSkill * 0.03

	return { distanceStd, lateralStd, longBias }
}

// ---- Lie modifiers (terrain → accuracy penalty) ----

/** 0.0-1.05 where 1.0 = perfect lie. bunkerDepth: 0 shallow, 1 deep. */
export function getLieModifier(terrain: TerrainType, club: Club, bunkerDepth = 0): number {
	switch (terrain) {
		case TerrainType.GRASS:
		case TerrainType.FAIRWAY:
			return 1.0
		case TerrainType.TEE_BOX:
			return club === Club.DRIVER ? 1.05 : 1.0
		case TerrainType.GREEN:
			return 1.0
		case TerrainType.ROUGH:
			return 0.75
		case TerrainType.HEAVY_ROUGH:
			return 0.5
		case TerrainType.BUNKER:
			if (bunkerDepth === 1) return club === Club.WEDGE ? 0.45 : 0.25
			return club === Club.WEDGE ? 0.6 : 0.4
		case TerrainType.TREES:
			return 0.3
		case TerrainType.ROCKS:
			return 0.25
		default:
			return 0.8
	}
}

/** 0.0-1.0 where 1.0 = full distance. */
export function getTerrainDistanceModifier(terrain: TerrainType, bunkerDepth = 0): number {
	switch (terrain) {
		case TerrainType.ROUGH:
			return 0.85
		case TerrainType.HEAVY_ROUGH:
			return 0.7
		case TerrainType.BUNKER:
			return bunkerDepth === 1 ? 0.6 : 0.75
		case TerrainType.TREES:
			return 0.6
		case TerrainType.ROCKS:
			return 0.5
		default:
			return 1.0
	}
}

// ---- Club wind sensitivity (higher trajectory = more wind effect) ----

export function getClubWindSensitivity(club: Club): number {
	switch (club) {
		case Club.DRIVER:
			return 1.0
		case Club.FAIRWAY_WOOD:
			return 0.85
		case Club.IRON:
			return 0.7
		case Club.WEDGE:
			return 0.4
		case Club.PUTTER:
			return 0.0
	}
}
