// Typed event bus replacing the Godot EventBus autoload.
// Event names are camelCase versions of the Godot signal names
// (scripts/autoload/event_bus.gd) so the two codebases stay greppable
// against each other. Past tense = completed events, present = state changes.

import type { TerrainType } from '@sim/terrain/terrain-types'
import type { ThemeType } from '@sim/course/theme'

export interface GameEvents {
	// Game state
	gameModeChanged: { oldMode: number; newMode: number }
	gameSpeedChanged: { newSpeed: number }
	newGameStarted: void
	themeChanged: { themeType: ThemeType }

	// Day cycle
	dayChanged: { newDay: number }
	hourChanged: { newHour: number }

	// Economy
	moneyChanged: { oldAmount: number; newAmount: number }

	// Terrain
	terrainTileChanged: { x: number; y: number; oldType: TerrainType; newType: TerrainType }
	elevationChanged: { x: number; y: number; oldElevation: number; newElevation: number }

	// UI
	uiNotification: { message: string; type: string }
}

type Handler<T> = (payload: T) => void

export class EventBus {
	private handlers = new Map<keyof GameEvents, Set<Handler<never>>>()

	on<K extends keyof GameEvents>(event: K, handler: Handler<GameEvents[K]>): () => void {
		let set = this.handlers.get(event)
		if (!set) {
			set = new Set()
			this.handlers.set(event, set)
		}
		set.add(handler as Handler<never>)
		return () => this.off(event, handler)
	}

	off<K extends keyof GameEvents>(event: K, handler: Handler<GameEvents[K]>): void {
		this.handlers.get(event)?.delete(handler as Handler<never>)
	}

	emit<K extends keyof GameEvents>(
		event: K,
		...payload: GameEvents[K] extends void ? [] : [GameEvents[K]]
	): void {
		const set = this.handlers.get(event)
		if (!set) return
		for (const handler of set) {
			;(handler as Handler<GameEvents[K] | undefined>)(payload[0])
		}
	}
}
