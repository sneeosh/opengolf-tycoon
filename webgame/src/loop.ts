// Fixed-timestep game loop. The sim ticks at a fixed 60 Hz of *game* time;
// the speed multiplier (1x/3x/8x, mirroring Godot's >/>>/>>>) runs more sim
// ticks per rendered frame. Rendering reads sim state every frame.

import { Game, GameSpeed, SIM_TICK_RATE } from '@sim/game'

const MAX_TICKS_PER_FRAME = 16 // don't spiral after a tab-suspend

export class GameLoop {
	private game: Game
	private accumulator = 0

	constructor(game: Game) {
		this.game = game
	}

	/** Call once per rendered frame with the elapsed real seconds. */
	advance(realDtSeconds: number): void {
		if (this.game.speed === GameSpeed.PAUSED) {
			this.accumulator = 0
			return
		}
		this.accumulator += Math.min(realDtSeconds, 0.25) * this.game.speed * SIM_TICK_RATE
		let ticks = Math.floor(this.accumulator)
		this.accumulator -= ticks
		// Cap ticks per frame; excess game time is dropped rather than spiraling
		ticks = Math.min(ticks, MAX_TICKS_PER_FRAME)
		while (ticks-- > 0) {
			this.game.tick()
		}
	}
}
