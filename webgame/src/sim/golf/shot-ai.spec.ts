import { describe, expect, it } from 'vitest'
import { Rng } from '../core/rng'
import { vec } from '../core/vec'
import { TerrainGrid } from '../terrain/terrain-grid'
import { TerrainType } from '../terrain/terrain-types'
import { Club } from './clubs'
import { WindSystem } from '../world/wind'
import {
	GolferData,
	ShotAIContext,
	assessLieQuality,
	assessMissRisk,
	countTreesAlongPath,
	decideShot,
	estimateShotsToHole,
	getCandidateClubs,
	getIdealShotDistance,
	getRecoveryClubs,
	nearbyHazardPenalty,
	pathCrossesTrees,
	scoreLandingZone,
} from './shot-ai'

function golfer(overrides: Partial<GolferData> = {}): GolferData {
	return {
		ballPosition: { x: 20, y: 64 },
		ballPositionPrecise: { x: 20, y: 64 },
		drivingSkill: 0.5,
		accuracySkill: 0.5,
		puttingSkill: 0.5,
		recoverySkill: 0.5,
		missTendency: 0,
		aggression: 0.5,
		patience: 0.5,
		currentHole: 0,
		totalStrokes: 0,
		totalPar: 0,
		...overrides,
	}
}

/** Grid that is all fairway (flat) for clean deterministic tests. */
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

function ctx(seed: number, grid = fairwayGrid(), wind: WindSystem | null = null): ShotAIContext {
	return { terrain: grid, rng: new Rng(seed), wind }
}

// ============================================================================
// Golden values for the planning helpers (constants from shot_ai.gd)
// ============================================================================

describe('multi-shot planning golden values', () => {
	// driving 0.8 → driver factor 0.4+0.55*0.8=0.84 → max 14*0.84 = 11.76 tiles
	const g = golfer({ drivingSkill: 0.8 })

	it('estimateShotsToHole thresholds (chip / wedge / driver / x2)', () => {
		expect(estimateShotsToHole(g, 0.5)).toBe(1) // chip/putt range
		expect(estimateShotsToHole(g, 4.5)).toBe(1) // wedge max_distance = 5
		expect(estimateShotsToHole(g, 10)).toBe(1) // can reach: 10 <= 11.76
		expect(estimateShotsToHole(g, 20)).toBe(2) // <= 2x driver
		expect(estimateShotsToHole(g, 30)).toBe(3) // par 5 territory
	})

	it('getIdealShotDistance plans backwards from a 3.5-tile approach', () => {
		expect(getIdealShotDistance(g, 8, 1)).toBe(8) // go for the green
		// 2 shots: min(d - 3.5, maxDriver)
		expect(getIdealShotDistance(g, 13, 2)).toBeCloseTo(9.5, 10)
		expect(getIdealShotDistance(g, 20, 2)).toBeCloseTo(11.76, 10)
		// 3 shots: min((d - 3.5) / 2, maxDriver)
		expect(getIdealShotDistance(g, 24, 3)).toBeCloseTo(10.25, 10)
		expect(getIdealShotDistance(g, 40, 3)).toBeCloseTo(11.76, 10)
	})

	it('getCandidateClubs drops the wedge on long shots and long clubs on chips', () => {
		// 20 tiles out: wedge max (0.89*5=4.45) < useful threshold 5.88 → dropped
		expect(getCandidateClubs(golfer(), 20, 11.76)).toEqual([
			Club.DRIVER,
			Club.FAIRWAY_WOOD,
			Club.IRON,
		])
		// Chip from 1.5 tiles: every long club min_distance overshoots → wedge only
		expect(getCandidateClubs(golfer(), 1.5, 1.5)).toEqual([Club.WEDGE])
	})

	it('assessLieQuality matches the shot_ai.gd table', () => {
		expect(assessLieQuality(TerrainType.FAIRWAY)).toBe(1.0)
		expect(assessLieQuality(TerrainType.TEE_BOX)).toBe(1.0)
		expect(assessLieQuality(TerrainType.GRASS)).toBe(0.8)
		expect(assessLieQuality(TerrainType.PATH)).toBe(0.7)
		expect(assessLieQuality(TerrainType.ROUGH)).toBe(0.5)
		expect(assessLieQuality(TerrainType.HEAVY_ROUGH)).toBe(0.3)
		expect(assessLieQuality(TerrainType.BUNKER)).toBe(0.3)
		expect(assessLieQuality(TerrainType.TREES)).toBe(0.15)
		expect(assessLieQuality(TerrainType.ROCKS)).toBe(0.1)
		expect(assessLieQuality(TerrainType.OUT_OF_BOUNDS)).toBe(0.0)
	})

	it('getRecoveryClubs restricts clubs per trouble lie', () => {
		expect(getRecoveryClubs(TerrainType.TREES)).toEqual([Club.WEDGE, Club.IRON])
		expect(getRecoveryClubs(TerrainType.ROCKS)).toEqual([Club.WEDGE])
		expect(getRecoveryClubs(TerrainType.BUNKER)).toEqual([Club.WEDGE, Club.IRON])
		expect(getRecoveryClubs(TerrainType.HEAVY_ROUGH)).toEqual([Club.WEDGE, Club.IRON])
		expect(getRecoveryClubs(TerrainType.ROUGH)).toEqual([
			Club.WEDGE,
			Club.IRON,
			Club.FAIRWAY_WOOD,
		])
	})
})

// ============================================================================
// (1) Putting — green reading
// ============================================================================

describe('putting: green-read aim adjustment', () => {
	/** Green x54-70, y60-68 with an eastward slope at the hole (64,64). */
	function slopedGreen(): TerrainGrid {
		const grid = fairwayGrid()
		for (let x = 54; x <= 70; x++)
			for (let y = 60; y <= 68; y++) grid.setTileNatural(x, y, TerrainType.GREEN)
		// East neighbor lower → getSlopeDirection(64,64) = (1, 0)
		grid.setElevation(64, 64, 1)
		grid.setElevation(63, 64, 1)
		grid.setElevation(64, 63, 1)
		grid.setElevation(64, 65, 1)
		return grid
	}

	function putter(skill: number, ball = { x: 56, y: 64 }): GolferData {
		return golfer({ ballPosition: ball, ballPositionPrecise: ball, puttingSkill: skill })
	}

	const HOLE = { x: 64, y: 64 }

	it('flat green: putter aimed dead at the hole', () => {
		const grid = fairwayGrid()
		for (let x = 54; x <= 70; x++)
			for (let y = 60; y <= 68; y++) grid.setTileNatural(x, y, TerrainType.GREEN)
		const d = decideShot(ctx(1, grid), putter(0.8), HOLE)
		expect(d).toEqual({ target: HOLE, club: Club.PUTTER, strategy: 'normal', confidence: 1.0 })
	})

	it('sloped green: aim offset opposite the slope, capped at 30% of distance', () => {
		// 8-tile putt, slope east. read = 0.2 + skill*0.7.
		// skill 0.8: break = 1*8*0.76*0.5 = 3.04 → capped to 8*0.3 = 2.4 → aim x = 61.6 → 62
		const high = decideShot(ctx(1, slopedGreen()), putter(0.8), HOLE)
		expect(high.club).toBe(Club.PUTTER)
		expect(high.target).toEqual({ x: 62, y: 64 })

		// skill 0.2: break = 8*0.34*0.5 = 1.36 (below cap) → aim x = 62.64 → 63
		const low = decideShot(ctx(1, slopedGreen()), putter(0.2), HOLE)
		expect(low.target).toEqual({ x: 63, y: 64 })

		// Weaker read → less break compensation (closer to the hole)
		expect(vec.distance(low.target, HOLE)).toBeLessThan(vec.distance(high.target, HOLE))
	})

	it('aim point that would leave the green falls back to the hole', () => {
		const grid = fairwayGrid()
		for (let x = 54; x <= 70; x++)
			for (let y = 60; y <= 68; y++) grid.setTileNatural(x, y, TerrainType.GREEN)
		// Hole at the left green edge with slope pointing east: compensation
		// would aim at (53,64), which is fairway → pulled back to the hole.
		const hole = { x: 54, y: 64 }
		grid.setElevation(54, 64, 1)
		grid.setElevation(53, 64, 1)
		grid.setElevation(54, 63, 1)
		grid.setElevation(54, 65, 1)
		const d = decideShot(ctx(1, grid), putter(0.8, { x: 58, y: 64 }), hole)
		expect(d.target).toEqual(hole)
		expect(d.club).toBe(Club.PUTTER)
	})
})

// ============================================================================
// (2) Long par-4 tee shot
// ============================================================================

describe('long par-4 tee shot', () => {
	// Ball (20,64), hole 20 tiles due east → 2-shot plan, layup strategy.
	// driving 0.8 → driver eff max 11.76; scan 60%-110% → max sample 12.94 → +13.
	// All-fairway: straight max-distance driver wins →
	// score = 150 (fairway) + 13*8 (alignment) - 7*4 (remaining) + 40 (clear line) = 266
	const HOLE = { x: 40, y: 64 }

	it('picks driver at max scanned distance straight down the line', () => {
		const g = golfer({ drivingSkill: 0.8 })
		const d = decideShot(ctx(7, fairwayGrid()), g, HOLE)
		expect(d.club).toBe(Club.DRIVER)
		expect(d.strategy).toBe('layup')
		expect(d.target).toEqual({ x: 33, y: 64 })
		expect(d.confidence).toBeCloseTo(266, 8)
	})

	it('aim distance stays within the skill distance factor scan window', () => {
		for (const driving of [0.2, 0.5, 0.9]) {
			const g = golfer({ drivingSkill: driving })
			const d = decideShot(ctx(7, fairwayGrid()), g, HOLE)
			const dist = vec.distance(g.ballPosition, d.target)
			const skillMax = 14 * (0.4 + driving * 0.55)
			// Scan window is 60%..110% of effective max; lateral offsets (±2 tiles
			// perpendicular) plus double rounding can add up to ~1.5 tiles.
			expect(dist).toBeLessThanOrEqual(skillMax * 1.1 + 1.5)
			expect(dist).toBeGreaterThanOrEqual(skillMax * 0.5)
		}
	})

	it('weaker drivers are assigned shorter targets', () => {
		const short = decideShot(ctx(7, fairwayGrid()), golfer({ drivingSkill: 0.1 }), HOLE)
		const long = decideShot(ctx(7, fairwayGrid()), golfer({ drivingSkill: 0.9 }), HOLE)
		expect(vec.distance({ x: 20, y: 64 }, short.target)).toBeLessThan(
			vec.distance({ x: 20, y: 64 }, long.target),
		)
	})
})

// ============================================================================
// (3) Wind compensation — skill-scaled aim into the wind
// ============================================================================

describe('wind compensation', () => {
	const HOLE = { x: 40, y: 64 }

	function crossWind(): WindSystem {
		const wind = new WindSystem()
		wind.windDirection = 0 // wind vector (0, +25): pushes shots toward +y
		wind.windSpeed = 25
		return wind
	}

	it('shifts aim into the wind, more for high accuracy skill', () => {
		const high = golfer({ drivingSkill: 0.8, accuracySkill: 0.9 })
		const low = golfer({ drivingSkill: 0.8, accuracySkill: 0.1 })
		const noWind = decideShot(ctx(3, fairwayGrid()), high, HOLE)
		const dHigh = decideShot(ctx(3, fairwayGrid(), crossWind()), high, HOLE)
		const dLow = decideShot(ctx(3, fairwayGrid(), crossWind()), low, HOLE)

		// No wind: dead straight (y=64). With +y crosswind: aim upwind (y < 64).
		expect(noWind.target.y).toBe(64)
		expect(dHigh.target.y).toBeLessThan(64)
		expect(dLow.target.y).toBeLessThan(64)
		// compensation_factor = 0.2 + accuracy*0.6 → 0.74 vs 0.26: pros aim further upwind
		expect(dHigh.target.y).toBeLessThan(dLow.target.y)
	})

	it('exact compensation from the source constants', () => {
		// Chosen landing test_pos is (33,62) for both golfers (scores are
		// skill-independent here); driver disp = 25 * (12.94/20) * 0.15 = 2.43 tiles.
		// aim.y = round(62 - 2.43*comp): comp 0.74 → 60.2 → 60; comp 0.26 → 61.4 → 61.
		const dHigh = decideShot(
			ctx(3, fairwayGrid(), crossWind()),
			golfer({ drivingSkill: 0.8, accuracySkill: 0.9 }),
			HOLE,
		)
		const dLow = decideShot(
			ctx(3, fairwayGrid(), crossWind()),
			golfer({ drivingSkill: 0.8, accuracySkill: 0.1 }),
			HOLE,
		)
		expect(dHigh.target).toEqual({ x: 33, y: 60 })
		expect(dLow.target).toEqual({ x: 33, y: 61 })
	})

	it('ignoreWind disables compensation entirely', () => {
		const g = golfer({ drivingSkill: 0.8, accuracySkill: 0.9 })
		const d = decideShot(ctx(3, fairwayGrid(), crossWind()), g, HOLE, true)
		expect(d.target).toEqual({ x: 33, y: 64 })
	})
})

// ============================================================================
// (4) Recovery mode — trouble lies
// ============================================================================

describe('recovery mode', () => {
	it('escapes a tree patch onto fairway with a restricted club', () => {
		const grid = fairwayGrid()
		for (let x = 28; x <= 32; x++)
			for (let y = 62; y <= 66; y++) grid.setTileNatural(x, y, TerrainType.TREES)
		const g = golfer({ ballPosition: { x: 30, y: 64 }, ballPositionPrecise: { x: 30, y: 64 } })
		const d = decideShot(ctx(5, grid), g, { x: 45, y: 64 })

		expect(d.strategy).toBe('recovery')
		expect([Club.WEDGE, Club.IRON]).toContain(d.club) // no woods through trees
		expect(grid.getTile(d.target.x, d.target.y)).toBe(TerrainType.FAIRWAY)
		// Advances toward the hole (escape route east of the patch)
		expect(vec.distance(d.target, { x: 45, y: 64 })).toBeLessThan(
			vec.distance(g.ballPosition, { x: 45, y: 64 }),
		)
	})

	it('recovery shots stay short: max 70% of skill-adjusted club distance', () => {
		const grid = fairwayGrid()
		grid.setTileNatural(30, 64, TerrainType.HEAVY_ROUGH)
		const g = golfer({ ballPosition: { x: 30, y: 64 }, ballPositionPrecise: { x: 30, y: 64 } })
		const d = decideShot(ctx(5, grid), g, { x: 45, y: 64 })
		expect(d.strategy).toBe('recovery')
		// Iron is the longest allowed club: 9 * (0.5+0.42*0.5) * 0.7 = 4.47 tiles
		expect(vec.distance(g.ballPosition, d.target)).toBeLessThanOrEqual(4.47 + 0.71)
	})

	it('rocks force wedge-only recovery', () => {
		const grid = fairwayGrid()
		grid.setTileNatural(30, 64, TerrainType.ROCKS)
		const g = golfer({ ballPosition: { x: 30, y: 64 }, ballPositionPrecise: { x: 30, y: 64 } })
		const d = decideShot(ctx(5, grid), g, { x: 45, y: 64 })
		expect(d.strategy).toBe('recovery')
		expect(d.club).toBe(Club.WEDGE)
	})

	it('bunker lie (quality 0.3 < 0.4) also enters recovery mode', () => {
		const grid = fairwayGrid()
		grid.setTileNatural(30, 64, TerrainType.BUNKER)
		const g = golfer({ ballPosition: { x: 30, y: 64 }, ballPositionPrecise: { x: 30, y: 64 } })
		const d = decideShot(ctx(5, grid), g, { x: 45, y: 64 })
		expect(d.strategy).toBe('recovery')
		expect([Club.WEDGE, Club.IRON]).toContain(d.club)
	})
})

// ============================================================================
// (5) Water hazards — target choice and aggression scaling
// ============================================================================

describe('water hazards', () => {
	const HOLE = { x: 44, y: 64 }

	function waterBand(withWater: boolean): TerrainGrid {
		const grid = fairwayGrid()
		if (withWater) {
			for (let x = 29; x <= 31; x++)
				for (let y = 54; y <= 74; y++) grid.setTileNatural(x, y, TerrainType.WATER)
		}
		return grid
	}

	it('water between ball and hole moves the layup target short of the hazard', () => {
		const cautious = golfer({ aggression: 0.1 })
		const noWater = decideShot(ctx(9, waterBand(false)), cautious, HOLE)
		const withWater = decideShot(ctx(9, waterBand(true)), cautious, HOLE)

		// Without water the ideal layup lands inside the (future) hazard zone…
		expect(noWater.target.x).toBeGreaterThanOrEqual(29)
		// …with water the golfer lays up short of it, on dry land
		expect(withWater.target.x).toBeLessThan(29)
		expect(waterBand(true).getTile(withWater.target.x, withWater.target.y)).toBe(
			TerrainType.FAIRWAY,
		)
	})

	it('aggressive golfers never target the water either, but score it higher', () => {
		const cautious = decideShot(ctx(9, waterBand(true)), golfer({ aggression: 0.1 }), HOLE)
		const aggressive = decideShot(ctx(9, waterBand(true)), golfer({ aggression: 0.9 }), HOLE)
		expect(waterBand(true).getTile(aggressive.target.x, aggressive.target.y)).not.toBe(
			TerrainType.WATER,
		)
		// Both land safe; aggression adds its flat +20 landing-zone bonus
		expect(aggressive.confidence).toBeGreaterThan(cautious.confidence)
	})

	it('nearbyHazardPenalty: 20/dist for water scaled by (1 - aggression*0.5)', () => {
		const grid = fairwayGrid()
		grid.setTileNatural(52, 50, TerrainType.WATER) // 2 tiles east of pos
		expect(nearbyHazardPenalty({ x: 50, y: 50 }, grid, 0.0)).toBeCloseTo(10, 10)
		expect(nearbyHazardPenalty({ x: 50, y: 50 }, grid, 1.0)).toBeCloseTo(5, 10)
	})

	it('nearbyHazardPenalty: 10/dist for trees scaled by (1 - aggression*0.3)', () => {
		const grid = fairwayGrid()
		grid.setTileNatural(51, 50, TerrainType.TREES) // adjacent east
		expect(nearbyHazardPenalty({ x: 50, y: 50 }, grid, 0.0)).toBeCloseTo(10, 10)
		expect(nearbyHazardPenalty({ x: 50, y: 50 }, grid, 1.0)).toBeCloseTo(7, 10)
	})

	it('assessMissRisk: deterministic sigma samples against a water wall', () => {
		// Ball (20,64) → target (32,64), 12 tiles. Skills 0.3/0.3 with driver:
		// total_accuracy = 0.7 * (0.3*0.7+0.3*0.3) * 1.0 = 0.21 → spread_std = 3.792°.
		// Water at x=32, y∈{62,63,65,66}: the ±1σ and ±2σ samples land in it
		// (offsets ±0.79 and ±1.58 tiles) while ±0.25σ/±0.5σ round to y=64.
		// → 4/8 hits → 0.5 * 200 * (1 - 0.4*aggression).
		const grid = fairwayGrid()
		for (const y of [62, 63, 65, 66]) grid.setTileNatural(32, y, TerrainType.WATER)
		const gd = (aggression: number) =>
			golfer({ drivingSkill: 0.3, accuracySkill: 0.3, aggression })
		const ball = { x: 20, y: 64 }
		const target = { x: 32, y: 64 }
		expect(assessMissRisk(gd(0.0), ball, target, grid, Club.DRIVER)).toBeCloseTo(100, 10)
		expect(assessMissRisk(gd(1.0), ball, target, grid, Club.DRIVER)).toBeCloseTo(60, 10)
	})

	it('assessMissRisk: miss tendency biases the sample fan toward the hazard', () => {
		const grid = fairwayGrid()
		for (const y of [62, 63, 65, 66]) grid.setTileNatural(32, y, TerrainType.WATER)
		const ball = { x: 20, y: 64 }
		const target = { x: 32, y: 64 }
		const neutral = golfer({ drivingSkill: 0.3, accuracySkill: 0.3, aggression: 0 })
		const slicer = golfer({
			drivingSkill: 0.3,
			accuracySkill: 0.3,
			aggression: 0,
			missTendency: 1,
		})
		expect(assessMissRisk(slicer, ball, target, grid, Club.DRIVER)).toBeGreaterThan(
			assessMissRisk(neutral, ball, target, grid, Club.DRIVER),
		)
	})
})

// ============================================================================
// Approach shots — club accuracy preference and green center bias
// ============================================================================

describe('approach shots', () => {
	it('short par-3: iron preferred over woods via accuracy_modifier * 20 bonus', () => {
		// Small green x26-28 y63-65, pin at the far edge (28,64), ball 8 tiles out.
		// Driver, FW and iron can all land on the pin tile → the accuracy bonus
		// decides: iron 0.85*20=17 > FW 15.6 > driver 14.
		const grid = fairwayGrid()
		for (let x = 26; x <= 28; x++)
			for (let y = 63; y <= 65; y++) grid.setTileNatural(x, y, TerrainType.GREEN)
		const g = golfer({ drivingSkill: 0.8, accuracySkill: 0.8 })
		const d = decideShot(ctx(11, grid), g, { x: 28, y: 64 })
		expect(d.strategy).toBe('attack')
		expect(d.club).toBe(Club.IRON)
		expect(d.target).toEqual({ x: 28, y: 64 })
		// 180 (green) + 8*8 (alignment) - 0 (at pin) + 17 (accuracy pref) = 261
		expect(d.confidence).toBeCloseTo(261, 8)
	})

	it('green center bias pulls low-accuracy aim toward the center (Phase 4 course data)', () => {
		const grid = fairwayGrid()
		for (let x = 26; x <= 31; x++)
			for (let y = 58; y <= 67; y++) grid.setTileNatural(x, y, TerrainType.GREEN)
		const center = { x: 28, y: 61 }
		const course = { holes: [{ greenPosition: center }] }
		const hole = { x: 28, y: 64 }

		const pro = decideShot(
			{ ...ctx(13, grid), course },
			golfer({ drivingSkill: 0.8, accuracySkill: 0.9 }),
			hole,
		)
		const beginner = decideShot(
			{ ...ctx(13, grid), course },
			golfer({ drivingSkill: 0.8, accuracySkill: 0.1 }),
			hole,
		)
		// pin_weight = clamp(acc*0.6 + 0.4, 0.5, 0.95): pro 0.94 vs beginner 0.5
		expect(vec.distance(beginner.target, center)).toBeLessThan(
			vec.distance(pro.target, center),
		)
	})
})

// ============================================================================
// Tree collision — flight paths avoid blocked lines
// ============================================================================

describe('tree collision handling', () => {
	it('pathCrossesTrees blocks low-trajectory crossings near the end of a long flight', () => {
		const grid = fairwayGrid()
		// 14-tile flight (20,64)→(34,64): last sample is t=14/15=0.933 at tile 33,
		// height 4t(1-t)=0.249 < 0.3 → a tree just short of the landing blocks.
		grid.setTileNatural(33, 64, TerrainType.TREES)
		expect(pathCrossesTrees({ x: 20, y: 64 }, { x: 34, y: 64 }, grid)).toBe(true)
		// The same tree mid-flight is overflown (height ~1.0 at t=0.5)
		expect(pathCrossesTrees({ x: 26, y: 64 }, { x: 40, y: 64 }, grid)).toBe(false)
	})

	it('scoreLandingZone returns -2000 for a blocked flight path', () => {
		const grid = fairwayGrid()
		grid.setTileNatural(33, 64, TerrainType.TREES)
		const s = scoreLandingZone(
			golfer(),
			{ x: 20, y: 64 },
			{ x: 34, y: 64 },
			{ x: 40, y: 64 },
			grid,
			Club.DRIVER,
			1,
		)
		expect(s).toBe(-2000)
	})

	it('routes the tee shot around a tall tree wall (zero trees overflown)', () => {
		const grid = fairwayGrid()
		for (let x = 28; x <= 29; x++)
			for (let y = 56; y <= 72; y++) grid.setTileNatural(x, y, TerrainType.TREES)
		const g = golfer({ drivingSkill: 0.8 })
		const d = decideShot(ctx(17, grid), g, { x: 40, y: 64 })

		expect(pathCrossesTrees(g.ballPosition, d.target, grid)).toBe(false)
		expect(countTreesAlongPath(g.ballPosition, d.target, grid)).toBe(0)
		expect(grid.getTile(d.target.x, d.target.y)).toBe(TerrainType.FAIRWAY)
	})
})

// ============================================================================
// (6) Determinism
// ============================================================================

describe('determinism', () => {
	it('identical inputs produce identical decisions', () => {
		const g = golfer({ drivingSkill: 0.7, accuracySkill: 0.6, aggression: 0.8 })
		const a = decideShot(ctx(42), g, { x: 40, y: 64 })
		const b = decideShot(ctx(42), g, { x: 40, y: 64 })
		expect(a).toEqual(b)
	})

	it('decision is independent of the rng seed (pipeline consumes no randomness)', () => {
		const g = golfer({ drivingSkill: 0.7, accuracySkill: 0.6 })
		const a = decideShot(ctx(1), g, { x: 40, y: 64 })
		const b = decideShot(ctx(999_999), g, { x: 40, y: 64 })
		expect(a).toEqual(b)
	})
})

// ============================================================================
// Invariant sweep over randomized golfers (statistical)
// ============================================================================

describe('invariant sweep (randomized golfers on a lake course)', () => {
	it('always returns a valid, non-hazard target with a legal club', { timeout: 60_000 }, () => {
		const grid = fairwayGrid()
		// A lake mid-course
		for (let x = 60; x <= 65; x++)
			for (let y = 50; y <= 80; y++) grid.setTileNatural(x, y, TerrainType.WATER)
		const hole = { x: 100, y: 64 }
		const rng = new Rng(20260803)

		for (let i = 0; i < 500; i++) {
			let ball = { x: rng.randiRange(5, 96), y: rng.randiRange(30, 98) }
			if (grid.getTile(ball.x, ball.y) !== TerrainType.FAIRWAY) ball = { x: 40, y: 64 }
			const g = golfer({
				ballPosition: ball,
				ballPositionPrecise: ball,
				drivingSkill: rng.randfRange(0.05, 0.95),
				accuracySkill: rng.randfRange(0.05, 0.95),
				puttingSkill: rng.randfRange(0.05, 0.95),
				recoverySkill: rng.randfRange(0.05, 0.95),
				missTendency: rng.randfRange(-1, 1),
				aggression: rng.randfRange(0, 1),
				totalStrokes: rng.randiRange(0, 40),
				totalPar: rng.randiRange(0, 36),
			})
			const d = decideShot({ terrain: grid, rng, wind: null }, g, hole)

			expect(grid.isValidPosition(d.target.x, d.target.y)).toBe(true)
			expect([Club.DRIVER, Club.FAIRWAY_WOOD, Club.IRON, Club.WEDGE, Club.PUTTER]).toContain(
				d.club,
			)
			expect(['normal', 'recovery', 'layup', 'attack']).toContain(d.strategy)
			const targetTerrain = grid.getTile(d.target.x, d.target.y)
			expect(targetTerrain).not.toBe(TerrainType.WATER)
			expect(Number.isFinite(d.confidence)).toBe(true)
		}
	})
})
