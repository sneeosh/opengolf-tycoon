// Headless shot-by-shot hole player: composes ShotAI decisions with the shot
// engine and putting model to play a hole start to finish. Used by the Hole
// Lab trace visualization and scenario tests; the full golfer entity state
// machine (Phase 4) follows this same loop with animation in between.

import { Vec2, vec } from '../core/vec'
import { Club } from './clubs'
import { calculateShot } from './shot'
import { calculatePutt } from './putting'
import { decideShot, GolferData, ShotAIContext, ShotStrategy } from './shot-ai'
import { getMaxStrokes, getPenaltyStrokes, getReliefType, ReliefType, CUP_RADIUS } from './golf-rules'
import { TerrainType } from '../terrain/terrain-types'
import type { TerrainGrid } from '../terrain/terrain-grid'
import type { HoleData } from '../course/hole'

export interface ShotTraceEntry {
	from: Vec2
	to: Vec2
	club: Club
	isPutt: boolean
	/** True for the penalty-drop pseudo-entry after water/OB. */
	isPenalty: boolean
	isShank: boolean
	strategy: ShotStrategy
}

export interface HolePlayResult {
	strokes: number
	par: number
	penalties: number
	holed: boolean
	/** True if the golfer hit the pickup cap (par + 3) without holing out. */
	pickedUp: boolean
	trace: ShotTraceEntry[]
}

export interface HolePlayerGolfer {
	drivingSkill: number
	accuracySkill: number
	puttingSkill: number
	recoverySkill: number
	missTendency: number
	aggression: number
	patience: number
}

const SAFETY_CAP = 25 // absolute stroke bound against pathological loops

export function playHole(
	ctx: ShotAIContext,
	golfer: HolePlayerGolfer,
	hole: HoleData,
	teePosition?: Vec2,
): HolePlayResult {
	const maxStrokes = getMaxStrokes(hole.par)
	const holePos = hole.holePosition
	let ballPrecise: Vec2 = { ...(teePosition ?? hole.teePosition) }
	let strokes = 0
	let penalties = 0
	let holed = false
	const trace: ShotTraceEntry[] = []

	while (!holed && strokes < maxStrokes && strokes < SAFETY_CAP) {
		const gd: GolferData = {
			...golfer,
			ballPosition: vec.round(ballPrecise),
			ballPositionPrecise: ballPrecise,
			currentHole: 0,
			totalStrokes: strokes,
			totalPar: 0,
		}
		const decision = decideShot(ctx, gd, vec.round(holePos))

		if (decision.club === Club.PUTTER) {
			const putt = calculatePutt(ctx.terrain, ctx.rng, golfer.puttingSkill, ballPrecise, holePos)
			strokes++
			trace.push({
				from: ballPrecise,
				to: putt.landingPrecise,
				club: Club.PUTTER,
				isPutt: true,
				isPenalty: false,
				isShank: false,
				strategy: decision.strategy,
			})
			ballPrecise = putt.landingPrecise
			if (putt.isMade || vec.distance(ballPrecise, holePos) < CUP_RADIUS) holed = true
			continue
		}

		const from = vec.round(ballPrecise)
		const result = calculateShot(ctx, golfer, from, decision.target, decision.club)
		strokes++
		trace.push({
			from: ballPrecise,
			to: result.landingPrecise,
			club: decision.club,
			isPutt: false,
			isPenalty: false,
			isShank: result.isShank,
			strategy: decision.strategy,
		})

		// Hazard relief per GolfRules: water = 1 stroke + drop at point of entry
		// (USGA Rule 17); OB = 1 stroke + replay from previous position (Rule 18.2).
		const landTile = vec.round(result.landingPrecise)
		const landTerrain = ctx.terrain.getTile(landTile.x, landTile.y)
		const penalty = getPenaltyStrokes(landTerrain)
		if (penalty > 0) {
			strokes += penalty
			penalties += penalty
			const relief = getReliefType(landTerrain)
			const dropPosition =
				relief === ReliefType.DROP_AT_ENTRY
					? findDropAtEntry(ctx.terrain, ballPrecise, result.landingPrecise)
					: ballPrecise // stroke and distance
			trace.push({
				from: result.landingPrecise,
				to: dropPosition,
				club: decision.club,
				isPutt: false,
				isPenalty: true,
				isShank: false,
				strategy: decision.strategy,
			})
			ballPrecise = dropPosition
			continue
		}
		ballPrecise = result.landingPrecise
	}

	return {
		strokes,
		par: hole.par,
		penalties,
		holed,
		pickedUp: !holed,
		trace,
	}
}

/**
 * Point-of-entry drop: walk the shot line in quarter-tile steps and return
 * the last position before the ball crossed into a penalty area.
 */
function findDropAtEntry(terrain: TerrainGrid, from: Vec2, landing: Vec2): Vec2 {
	const distance = vec.distance(from, landing)
	const steps = Math.max(Math.ceil(distance * 4), 1)
	let lastSafe = from
	for (let i = 1; i <= steps; i++) {
		const point = vec.lerp(from, landing, i / steps)
		const tile = vec.round(point)
		if (!terrain.isValidPosition(tile.x, tile.y)) break
		const t = terrain.getTile(tile.x, tile.y)
		if (t === TerrainType.WATER || t === TerrainType.OUT_OF_BOUNDS) break
		lastSafe = point
	}
	return lastSafe
}
