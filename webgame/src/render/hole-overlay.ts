// Hole overlay — renders hole furniture on the map: tee markers
// (forward/middle/back), the flagstick at the current pin, alternate pin
// dots, and AI shot traces from hole simulation.

import { Container, Graphics, Text } from 'pixi.js'
import type { HoleData } from '@sim/course/hole'
import type { Vec2 } from '@sim/core/vec'
import { gridToWorldCenter } from './grid-transform'

const TEE_COLORS: Record<string, number> = {
	forward: 0xdd4444, // red
	middle: 0xf5f5f5, // white
	back: 0x4477ee, // blue
}

export interface ShotTracePoint {
	from: Vec2
	to: Vec2
	isPutt: boolean
	isPenalty?: boolean
}

export class HoleOverlay {
	readonly container = new Container()
	private furniture = new Graphics()
	private traces = new Graphics()
	private labels = new Container()

	constructor() {
		this.container.addChild(this.traces, this.furniture, this.labels)
	}

	clear(): void {
		this.furniture.clear()
		this.traces.clear()
		this.labels.removeChildren().forEach((c) => c.destroy())
	}

	clearTraces(): void {
		this.traces.clear()
	}

	drawHole(hole: HoleData): void {
		this.furniture.clear()
		this.labels.removeChildren().forEach((c) => c.destroy())

		// Tee markers
		for (const [key, color] of Object.entries(TEE_COLORS)) {
			const pos = hole.teePositions[key as keyof typeof hole.teePositions]
			if (!pos) continue
			const w = gridToWorldCenter(pos.x, pos.y)
			this.furniture.rect(w.x - 5, w.y - 5, 10, 10).fill(color).stroke({
				color: 0x222222,
				width: 1,
			})
		}

		// Alternate pins as hollow dots
		hole.pinPositions.forEach((pin, i) => {
			if (i === hole.currentPinIndex) return
			const w = gridToWorldCenter(pin.x, pin.y)
			this.furniture.circle(w.x, w.y, 4).stroke({ color: 0xffffff, width: 1.5, alpha: 0.6 })
		})

		// Flagstick at the current pin
		const pin = gridToWorldCenter(hole.holePosition.x, hole.holePosition.y)
		this.furniture.circle(pin.x, pin.y, 4).fill(0x222222) // cup
		this.furniture
			.moveTo(pin.x, pin.y)
			.lineTo(pin.x, pin.y - 34)
			.stroke({ color: 0xeeeeee, width: 2 })
		this.furniture
			.poly([pin.x, pin.y - 34, pin.x + 16, pin.y - 28, pin.x, pin.y - 22])
			.fill(0xee3333)

		// Hole number + par label near the back tee
		const tee = gridToWorldCenter(hole.teePosition.x, hole.teePosition.y)
		const label = new Text({
			text: `#${hole.holeNumber} · Par ${hole.par} · ${hole.distanceYards}yd · D${hole.difficultyRating.toFixed(1)}`,
			style: {
				fontFamily: 'system-ui',
				fontSize: 13,
				fill: 0xffffff,
				stroke: { color: 0x000000, width: 3 },
			},
		})
		label.position.set(tee.x - 30, tee.y + 14)
		this.labels.addChild(label)
	}

	/** Draw a sequence of AI shots as a numbered polyline trace. */
	drawShotTrace(trace: ShotTracePoint[]): void {
		trace.forEach((shot, i) => {
			const from = gridToWorldCenter(shot.from.x, shot.from.y)
			const to = gridToWorldCenter(shot.to.x, shot.to.y)
			const color = shot.isPenalty ? 0xff5555 : shot.isPutt ? 0xffee66 : 0x66ddff
			this.traces
				.moveTo(from.x, from.y)
				.lineTo(to.x, to.y)
				.stroke({ color, width: 2, alpha: 0.85 })
			this.traces.circle(to.x, to.y, 3.5).fill({ color, alpha: 0.95 })
			const num = new Text({
				text: String(i + 1),
				style: {
					fontFamily: 'system-ui',
					fontSize: 11,
					fill: color,
					stroke: { color: 0x000000, width: 2 },
				},
			})
			num.position.set((from.x + to.x) / 2 + 4, (from.y + to.y) / 2 - 14)
			this.labels.addChild(num)
		})
	}
}
