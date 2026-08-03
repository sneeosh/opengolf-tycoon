import { describe, expect, it } from 'vitest'
import { TerrainType } from '../terrain/terrain-types'
import { Club } from './clubs'
import {
	calculatePar,
	classifyScore,
	getClubWindSensitivity,
	getLieModifier,
	getMaxStrokes,
	getPenaltyStrokes,
	getPuttMakeRate,
	getPuttMissCharacteristics,
	getReliefType,
	getScoreName,
	getTerrainDistanceModifier,
	ReliefType,
	TAP_IN_DISTANCE,
} from './golf-rules'

describe('GolfRules (golf_rules.gd parity)', () => {
	it('names scores per USGA terminology', () => {
		expect(getScoreName(1, 4)).toBe('Hole-in-One')
		expect(getScoreName(2, 5)).toBe('Albatross')
		expect(getScoreName(3, 5)).toBe('Eagle')
		expect(getScoreName(3, 4)).toBe('Birdie')
		expect(getScoreName(4, 4)).toBe('Par')
		expect(getScoreName(5, 4)).toBe('Bogey')
		expect(getScoreName(6, 4)).toBe('Double Bogey')
		expect(getScoreName(8, 4)).toBe('+4')
	})

	it('classifies scores for statistics', () => {
		expect(classifyScore(1, 3)).toBe('hole_in_one')
		expect(classifyScore(2, 4)).toBe('eagle')
		expect(classifyScore(3, 4)).toBe('birdie')
		expect(classifyScore(6, 4)).toBe('double_bogey_plus')
	})

	it('derives par from USGA yardage boundaries (250/470)', () => {
		expect(calculatePar(120)).toBe(3)
		expect(calculatePar(250)).toBe(3)
		expect(calculatePar(251)).toBe(4)
		expect(calculatePar(470)).toBe(4)
		expect(calculatePar(471)).toBe(5)
		expect(calculatePar(600)).toBe(5)
	})

	it('pickup at triple bogey', () => {
		expect(getMaxStrokes(3)).toBe(6)
		expect(getMaxStrokes(5)).toBe(8)
	})

	it('penalizes water and OB one stroke, with correct relief', () => {
		expect(getPenaltyStrokes(TerrainType.WATER)).toBe(1)
		expect(getPenaltyStrokes(TerrainType.OUT_OF_BOUNDS)).toBe(1)
		expect(getPenaltyStrokes(TerrainType.BUNKER)).toBe(0)
		expect(getReliefType(TerrainType.WATER)).toBe(ReliefType.DROP_AT_ENTRY)
		expect(getReliefType(TerrainType.OUT_OF_BOUNDS)).toBe(ReliefType.STROKE_AND_DISTANCE)
		expect(getReliefType(TerrainType.FLOWER_BED)).toBe(ReliefType.FREE_RELIEF)
		expect(getReliefType(TerrainType.FAIRWAY)).toBe(ReliefType.NONE)
	})

	describe('putt make rates (exponential decay, PGA-calibrated)', () => {
		it('tap-ins inside 3 feet are automatic', () => {
			expect(getPuttMakeRate(TAP_IN_DISTANCE - 0.001, 0.1)).toBe(1.0)
		})

		it('matches the decay formula exactly at skill 0.95', () => {
			// decay = 0.053 * (1 + 0.05*2.5) = 0.053 * 1.125 = 0.059625 per foot
			const decay = 0.053 * 1.125
			expect(getPuttMakeRate(5 / 66, 0.95)).toBeCloseTo(Math.exp(-5 * decay), 10)
			expect(getPuttMakeRate(10 / 66, 0.95)).toBeCloseTo(Math.exp(-10 * decay), 10)
			expect(getPuttMakeRate(30 / 66, 0.95)).toBeCloseTo(Math.exp(-30 * decay), 10)
		})

		it('gives beginners ~3x steeper decay than pros', () => {
			// skill 0.35 → multiplier 2.625 vs pro 1.125
			const pro10ft = getPuttMakeRate(10 / 66, 0.95)
			const beginner10ft = getPuttMakeRate(10 / 66, 0.35)
			expect(pro10ft).toBeGreaterThan(0.5)
			expect(beginner10ft).toBeLessThan(0.3)
		})

		it('floors at 1% for any putt', () => {
			expect(getPuttMakeRate(3.0, 0.1)).toBe(0.01)
		})
	})

	describe('putt miss characteristics by distance category', () => {
		it('uses doc formulas for short/medium/long putts', () => {
			// Short (< 10 ft): distance_std = 0.015 + (1-skill)*0.02
			const short = getPuttMissCharacteristics(8 / 66, 0.5)
			expect(short.distanceStd).toBeCloseTo(0.015 + 0.5 * 0.02, 10)
			expect(short.lateralStd).toBeCloseTo(0.008 + 0.5 * 0.017, 10)
			// Medium (10-30 ft)
			const medium = getPuttMissCharacteristics(20 / 66, 0.5)
			expect(medium.distanceStd).toBeCloseTo(0.03 + 0.5 * 0.06, 10)
			// Long (30+ ft): proportional to distance
			const distTiles = 40 / 66
			const long = getPuttMissCharacteristics(distTiles, 0.5)
			expect(long.distanceStd).toBeCloseTo(distTiles * (0.06 + 0.5 * 0.12), 10)
		})

		it('long bias grows with skill (never up, never in)', () => {
			expect(getPuttMissCharacteristics(0.3, 0.35).longBias).toBeCloseTo(0.0305, 10)
			expect(getPuttMissCharacteristics(0.3, 0.95).longBias).toBeCloseTo(0.0485, 10)
		})
	})

	describe('lie modifiers', () => {
		it('matches the golf_rules.gd table', () => {
			expect(getLieModifier(TerrainType.FAIRWAY, Club.IRON)).toBe(1.0)
			expect(getLieModifier(TerrainType.TEE_BOX, Club.DRIVER)).toBe(1.05)
			expect(getLieModifier(TerrainType.TEE_BOX, Club.IRON)).toBe(1.0)
			expect(getLieModifier(TerrainType.ROUGH, Club.IRON)).toBe(0.75)
			expect(getLieModifier(TerrainType.HEAVY_ROUGH, Club.IRON)).toBe(0.5)
			expect(getLieModifier(TerrainType.BUNKER, Club.WEDGE, 0)).toBe(0.6)
			expect(getLieModifier(TerrainType.BUNKER, Club.IRON, 0)).toBe(0.4)
			expect(getLieModifier(TerrainType.BUNKER, Club.WEDGE, 1)).toBe(0.45)
			expect(getLieModifier(TerrainType.BUNKER, Club.IRON, 1)).toBe(0.25)
			expect(getLieModifier(TerrainType.TREES, Club.IRON)).toBe(0.3)
			expect(getLieModifier(TerrainType.ROCKS, Club.IRON)).toBe(0.25)
		})
	})

	describe('terrain distance modifiers', () => {
		it('matches the golf_rules.gd table', () => {
			expect(getTerrainDistanceModifier(TerrainType.FAIRWAY)).toBe(1.0)
			expect(getTerrainDistanceModifier(TerrainType.ROUGH)).toBe(0.85)
			expect(getTerrainDistanceModifier(TerrainType.HEAVY_ROUGH)).toBe(0.7)
			expect(getTerrainDistanceModifier(TerrainType.BUNKER, 0)).toBe(0.75)
			expect(getTerrainDistanceModifier(TerrainType.BUNKER, 1)).toBe(0.6)
			expect(getTerrainDistanceModifier(TerrainType.TREES)).toBe(0.6)
			expect(getTerrainDistanceModifier(TerrainType.ROCKS)).toBe(0.5)
		})
	})

	it('scales wind sensitivity by trajectory (driver 1.0 → putter 0.0)', () => {
		expect(getClubWindSensitivity(Club.DRIVER)).toBe(1.0)
		expect(getClubWindSensitivity(Club.FAIRWAY_WOOD)).toBe(0.85)
		expect(getClubWindSensitivity(Club.IRON)).toBe(0.7)
		expect(getClubWindSensitivity(Club.WEDGE)).toBe(0.4)
		expect(getClubWindSensitivity(Club.PUTTER)).toBe(0.0)
	})
})
