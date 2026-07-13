// Root simulation object. Owns the sim subsystems and advances them in
// fixed-timestep ticks. Phase 1 only carries terrain state; the day/hour
// clock, golfers, and economy arrive in later phases.

import { Rng } from './core/rng'
import { TerrainGrid } from './terrain/terrain-grid'
import { ThemeType } from './course/theme'

export const SIM_TICK_RATE = 60 // ticks per second at 1x speed
export const SIM_DT = 1 / SIM_TICK_RATE

export enum GameSpeed {
	PAUSED = 0,
	NORMAL = 1,
	FAST = 3,
	ULTRA = 8,
}

export class Game {
	readonly rng: Rng
	readonly terrain: TerrainGrid
	theme: ThemeType = ThemeType.PARKLAND
	speed: GameSpeed = GameSpeed.NORMAL

	constructor(seed = 1) {
		this.rng = new Rng(seed)
		this.terrain = new TerrainGrid()
	}

	/** Advance one fixed sim tick (SIM_DT seconds of game time). */
	tick(): void {
		// Phase 2+: clock, wind drift, weather transitions, golfers...
	}
}
