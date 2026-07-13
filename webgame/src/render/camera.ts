// Camera — port of scripts/utils/isometric_camera.gd interactions:
// WASD/arrow pan, middle-mouse drag pan, wheel zoom to cursor, [ ] zoom keys.
// Implemented as a transform on the world container.

import { Container, Rectangle } from 'pixi.js'

const PAN_SPEED = 800 // world px/sec at zoom 1
const ZOOM_MIN = 0.15
const ZOOM_MAX = 3.0
const ZOOM_STEP = 1.15

export class Camera {
	private world: Container
	private screenW = 0
	private screenH = 0
	private keys = new Set<string>()
	private dragging = false
	private lastDrag = { x: 0, y: 0 }

	// World-space center the camera looks at
	x = 0
	y = 0
	zoom = 1

	constructor(world: Container, canvas: HTMLCanvasElement) {
		this.world = world

		window.addEventListener('keydown', (e) => {
			if (e.target instanceof HTMLInputElement || e.target instanceof HTMLSelectElement) return
			this.keys.add(e.key.toLowerCase())
			if (e.key === '[') this.zoomBy(1 / ZOOM_STEP)
			if (e.key === ']') this.zoomBy(ZOOM_STEP)
		})
		window.addEventListener('keyup', (e) => this.keys.delete(e.key.toLowerCase()))
		window.addEventListener('blur', () => this.keys.clear())

		canvas.addEventListener('wheel', (e) => {
			e.preventDefault()
			const factor = e.deltaY < 0 ? ZOOM_STEP : 1 / ZOOM_STEP
			this.zoomAt(e.offsetX, e.offsetY, factor)
		})

		canvas.addEventListener('pointerdown', (e) => {
			if (e.button === 1 || e.button === 2) {
				this.dragging = true
				this.lastDrag = { x: e.clientX, y: e.clientY }
				canvas.setPointerCapture(e.pointerId)
				e.preventDefault()
			}
		})
		canvas.addEventListener('pointermove', (e) => {
			if (!this.dragging) return
			this.x -= (e.clientX - this.lastDrag.x) / this.zoom
			this.y -= (e.clientY - this.lastDrag.y) / this.zoom
			this.lastDrag = { x: e.clientX, y: e.clientY }
		})
		const endDrag = () => (this.dragging = false)
		canvas.addEventListener('pointerup', endDrag)
		canvas.addEventListener('pointercancel', endDrag)
		canvas.addEventListener('contextmenu', (e) => e.preventDefault())
	}

	resize(width: number, height: number): void {
		this.screenW = width
		this.screenH = height
	}

	centerOn(worldX: number, worldY: number): void {
		this.x = worldX
		this.y = worldY
	}

	private zoomBy(factor: number): void {
		this.zoomAt(this.screenW / 2, this.screenH / 2, factor)
	}

	/** Zoom keeping the world point under (screenX, screenY) fixed. */
	private zoomAt(screenX: number, screenY: number, factor: number): void {
		const before = this.screenToWorld(screenX, screenY)
		this.zoom = Math.max(ZOOM_MIN, Math.min(ZOOM_MAX, this.zoom * factor))
		const after = this.screenToWorld(screenX, screenY)
		this.x += before.x - after.x
		this.y += before.y - after.y
	}

	screenToWorld(screenX: number, screenY: number): { x: number; y: number } {
		return {
			x: this.x + (screenX - this.screenW / 2) / this.zoom,
			y: this.y + (screenY - this.screenH / 2) / this.zoom,
		}
	}

	/** Apply keyboard panning and push the transform to the world container. */
	update(dtSeconds: number): void {
		const speed = (PAN_SPEED / this.zoom) * dtSeconds
		if (this.keys.has('w') || this.keys.has('arrowup')) this.y -= speed
		if (this.keys.has('s') || this.keys.has('arrowdown')) this.y += speed
		if (this.keys.has('a') || this.keys.has('arrowleft')) this.x -= speed
		if (this.keys.has('d') || this.keys.has('arrowright')) this.x += speed

		this.world.scale.set(this.zoom)
		this.world.position.set(
			this.screenW / 2 - this.x * this.zoom,
			this.screenH / 2 - this.y * this.zoom,
		)
	}

	/** Visible world-space rectangle (for chunk culling). */
	getVisibleWorldRect(): Rectangle {
		const w = this.screenW / this.zoom
		const h = this.screenH / this.zoom
		return new Rectangle(this.x - w / 2, this.y - h / 2, w, h)
	}
}
