import { describe, expect, it } from 'vitest'
import { Rng } from '../core/rng'
import { Club } from '../golf/clubs'
import { WindSystem } from './wind'

function windAt(direction: number, speed: number): WindSystem {
	const wind = new WindSystem()
	wind.windDirection = direction
	wind.windSpeed = speed
	return wind
}

describe('WindSystem (wind_system.gd parity)', () => {
	it('generates daily wind within documented ranges', () => {
		const rng = new Rng(7)
		const wind = new WindSystem()
		for (let day = 0; day < 200; day++) {
			wind.generateDailyWind(rng)
			expect(wind.windDirection).toBeGreaterThanOrEqual(0)
			expect(wind.windDirection).toBeLessThan(Math.PI * 2)
			expect(wind.windSpeed).toBeGreaterThanOrEqual(2.0)
			expect(wind.windSpeed).toBeLessThan(20.0)
		}
	})

	it('clamps drifted speed to 0-30 mph', () => {
		const rng = new Rng(3)
		const wind = new WindSystem()
		wind.generateDailyWind(rng)
		for (let h = 0; h < 500; h++) {
			wind.updateWindDrift(rng, h)
			expect(wind.windSpeed).toBeGreaterThanOrEqual(0)
			expect(wind.windSpeed).toBeLessThanOrEqual(30)
		}
	})

	it('putter is immune to wind', () => {
		const wind = windAt(Math.PI / 3, 30)
		expect(wind.getWindDisplacement({ x: 1, y: 0 }, 10, Club.PUTTER)).toEqual({ x: 0, y: 0 })
		expect(wind.getDistanceModifier({ x: 1, y: 0 }, Club.PUTTER)).toBe(1.0)
	})

	it('direct 30mph headwind on a driver gives 0.85, tailwind 1.10', () => {
		// wind_vector = (-sin θ, cos θ)*speed; θ=0 → wind blows toward +y
		const wind = windAt(0, 30)
		// Shot into the wind (direction -y): headwind
		expect(wind.getDistanceModifier({ x: 0, y: -1 }, Club.DRIVER)).toBeCloseTo(0.85, 10)
		// Shot with the wind (+y): tailwind
		expect(wind.getDistanceModifier({ x: 0, y: 1 }, Club.DRIVER)).toBeCloseTo(1.1, 10)
		// Pure crosswind (+x): no distance change
		expect(wind.getDistanceModifier({ x: 1, y: 0 }, Club.DRIVER)).toBeCloseTo(1.0, 10)
	})

	it('scales distance modifier by club sensitivity', () => {
		const wind = windAt(0, 30)
		// Iron sensitivity 0.7: headwind = 1 - 0.15*0.7 = 0.895
		expect(wind.getDistanceModifier({ x: 0, y: -1 }, Club.IRON)).toBeCloseTo(1 - 0.15 * 0.7, 10)
	})

	it('crosswind displaces laterally, scaled by distance and sensitivity', () => {
		const wind = windAt(0, 10) // wind toward +y
		const shotDir = { x: 1, y: 0 } // crosswind from the left
		// displacement = crosswind(0,10) * sensitivity(1.0) * (dist/20) * 0.15
		const d20 = wind.getWindDisplacement(shotDir, 20, Club.DRIVER)
		expect(d20.x).toBeCloseTo(0, 10)
		expect(d20.y).toBeCloseTo(10 * 1.0 * 1.0 * 0.15, 10)
		// Half the distance = half the push
		const d10 = wind.getWindDisplacement(shotDir, 10, Club.DRIVER)
		expect(d10.y).toBeCloseTo(d20.y / 2, 10)
		// Wedge sensitivity 0.4
		const dw = wind.getWindDisplacement(shotDir, 20, Club.WEDGE)
		expect(dw.y).toBeCloseTo(10 * 0.4 * 1.0 * 0.15, 10)
	})

	it('pure headwind produces no lateral displacement', () => {
		const wind = windAt(0, 20)
		const d = wind.getWindDisplacement({ x: 0, y: -1 }, 14, Club.DRIVER)
		expect(Math.hypot(d.x, d.y)).toBeCloseTo(0, 10)
	})

	it('reports compass direction and strength text', () => {
		expect(windAt(0, 3).getDirectionText()).toBe('N')
		expect(windAt(Math.PI / 2, 3).getDirectionText()).toBe('E')
		expect(windAt(Math.PI, 3).getDirectionText()).toBe('S')
		expect(windAt(0, 3).getStrengthText()).toBe('Calm')
		expect(windAt(0, 12).getStrengthText()).toBe('Moderate')
		expect(windAt(0, 25).getStrengthText()).toBe('Very Strong')
	})
})
