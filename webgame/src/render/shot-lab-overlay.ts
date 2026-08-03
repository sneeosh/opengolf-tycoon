// Shot Lab scatter overlay — draws shot volleys in world space: origin tee
// marker, target crosshair, carry points, final resting points, and rollout
// trails. Color-coded by outcome.

import { Container, Graphics } from 'pixi.js'
import type { ShotResult } from '@sim/golf/shot'
import type { TerrainGrid } from '@sim/terrain/terrain-grid'
import { TerrainType } from '@sim/terrain/terrain-types'
import { vec } from '@sim/core/vec'
import { gridToWorldCenter } from './grid-transform'

const COLORS = {
	origin: 0xffffff,
	target: 0xff5555,
	carry: 0x88ccff,
	shank: 0xff4444,
	water: 0x3388ff,
	sand: 0xddcc77,
	good: 0x66ff88, // fairway/green/tee
	other: 0xffee66, // rough etc.
	backspin: 0xff88ff,
}

export class ShotLabOverlay {
	readonly container = new Container()
	private dots = new Graphics()
	private markers = new Graphics()

	constructor() {
		this.container.addChild(this.dots, this.markers)
	}

	clear(): void {
		this.dots.clear()
		this.markers.clear()
	}

	setMarkers(origin: { x: number; y: number }, target: { x: number; y: number } | null): void {
		this.markers.clear()
		const o = gridToWorldCenter(origin.x, origin.y)
		this.markers.circle(o.x, o.y, 10).stroke({ color: COLORS.origin, width: 3 })
		this.markers.circle(o.x, o.y, 3).fill(COLORS.origin)
		if (target) {
			const t = gridToWorldCenter(target.x, target.y)
			this.markers
				.moveTo(t.x - 12, t.y)
				.lineTo(t.x + 12, t.y)
				.moveTo(t.x, t.y - 12)
				.lineTo(t.x, t.y + 12)
				.stroke({ color: COLORS.target, width: 3 })
			this.markers.circle(t.x, t.y, 8).stroke({ color: COLORS.target, width: 2 })
			// Target line
			this.markers.moveTo(o.x, o.y).lineTo(t.x, t.y).stroke({
				color: COLORS.target,
				width: 1,
				alpha: 0.35,
			})
		}
	}

	plotVolley(results: ShotResult[], terrain: TerrainGrid): void {
		for (const r of results) {
			const carry = gridToWorldCenter(r.carryPrecise.x, r.carryPrecise.y)
			const final = gridToWorldCenter(r.landingPrecise.x, r.landingPrecise.y)

			// Rollout trail from carry to final
			if (r.rolloutTiles > 0.01) {
				this.dots.moveTo(carry.x, carry.y).lineTo(final.x, final.y).stroke({
					color: r.isBackspin ? COLORS.backspin : COLORS.carry,
					width: 1,
					alpha: 0.4,
				})
			}
			// Carry point (faint)
			this.dots.circle(carry.x, carry.y, 2.5).fill({ color: COLORS.carry, alpha: 0.45 })

			// Final point colored by outcome
			const tile = vec.round(r.landingPrecise)
			const landTerrain = terrain.getTile(tile.x, tile.y)
			let color = COLORS.other
			if (r.isShank) color = COLORS.shank
			else if (landTerrain === TerrainType.WATER) color = COLORS.water
			else if (landTerrain === TerrainType.BUNKER) color = COLORS.sand
			else if (
				landTerrain === TerrainType.FAIRWAY ||
				landTerrain === TerrainType.GREEN ||
				landTerrain === TerrainType.TEE_BOX
			) {
				color = COLORS.good
			}
			this.dots.circle(final.x, final.y, 3.5).fill({ color, alpha: 0.9 })
		}
	}
}
