// WindSystem — port of scripts/systems/wind_system.gd as a plain class.
// Daily random direction/speed with hourly drift; crosswind displacement and
// headwind/tailwind distance modifier scaled by club sensitivity.

import type { Rng } from '../core/rng'
import { Vec2, vec } from '../core/vec'
import { Club } from '../golf/clubs'
import { getClubWindSensitivity } from '../golf/golf-rules'

const TAU = Math.PI * 2

export class WindSystem {
	/** Radians (0 = North/up, PI/2 = East — Godot convention). */
	windDirection = 0
	/** MPH, 0-30. */
	windSpeed = 5

	private baseDirection = 0
	private driftRate = 0

	onWindChanged: ((direction: number, speed: number) => void) | null = null

	generateDailyWind(rng: Rng): void {
		this.baseDirection = rng.randf() * TAU
		this.windDirection = this.baseDirection
		this.windSpeed = rng.randfRange(2.0, 20.0)
		this.driftRate = rng.randfRange(-0.3, 0.3) // radians per hour
		this.onWindChanged?.(this.windDirection, this.windSpeed)
	}

	updateWindDrift(rng: Rng, hoursElapsed: number): void {
		this.windDirection = this.baseDirection + this.driftRate * hoursElapsed
		this.windSpeed = Math.max(0, Math.min(30, this.windSpeed + rng.randfRange(-0.5, 0.5)))
		this.onWindChanged?.(this.windDirection, this.windSpeed)
	}

	private windVector(): Vec2 {
		return {
			x: -Math.sin(this.windDirection) * this.windSpeed,
			y: Math.cos(this.windDirection) * this.windSpeed,
		}
	}

	/** Lateral crosswind displacement for a shot, in tiles. */
	getWindDisplacement(shotDirection: Vec2, distanceTiles: number, club: Club): Vec2 {
		const sensitivity = getClubWindSensitivity(club)
		if (sensitivity === 0) return { x: 0, y: 0 }

		const wind = this.windVector()
		const dir = vec.normalize(shotDirection)
		const headwind = vec.dot(wind, dir) // positive = tailwind
		const crosswind = vec.sub(wind, vec.scale(dir, headwind))

		const distanceFactor = distanceTiles / 20.0 // normalize to ~driver distance
		return vec.scale(crosswind, sensitivity * distanceFactor * 0.15)
	}

	/** Distance multiplier from headwind/tailwind: [0.75, 1.15]. */
	getDistanceModifier(shotDirection: Vec2, club: Club): number {
		const sensitivity = getClubWindSensitivity(club)
		if (sensitivity === 0) return 1.0

		const wind = this.windVector()
		const dir = vec.normalize(shotDirection)
		const headwindComponent = vec.dot(wind, dir)

		let modifier = 1.0
		if (headwindComponent < 0) {
			// Headwind: up to 15% reduction at 30 mph
			modifier -= (Math.abs(headwindComponent) / 30.0) * 0.15 * sensitivity
		} else {
			// Tailwind: up to 10% increase at 30 mph
			modifier += (headwindComponent / 30.0) * 0.1 * sensitivity
		}
		return Math.max(0.75, Math.min(1.15, modifier))
	}

	getDirectionText(): string {
		const degrees = (((this.windDirection * 180) / Math.PI) % 360 + 360) % 360
		const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW']
		return directions[Math.round(degrees / 45.0) % 8]
	}

	getStrengthText(): string {
		if (this.windSpeed < 5) return 'Calm'
		if (this.windSpeed < 10) return 'Light'
		if (this.windSpeed < 15) return 'Moderate'
		if (this.windSpeed < 20) return 'Strong'
		return 'Very Strong'
	}
}
