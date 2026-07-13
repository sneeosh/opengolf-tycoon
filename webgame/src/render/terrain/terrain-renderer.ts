// Chunked terrain renderer. The 128x128 map is split into 4x4 chunks of 32x32
// tiles; each chunk is baked once into a RenderTexture, so panning/zooming
// costs 16 sprites instead of 16,384. Tile edits mark their chunk (and any
// neighbor chunks whose edge masks changed) dirty; dirty chunks rebake with a
// per-frame budget. Theme changes regenerate the atlas and rebake everything.

import {
	Container,
	Graphics,
	Rectangle,
	RenderTexture,
	Sprite,
	Texture,
	type Renderer,
} from 'pixi.js'
import type { TerrainGrid } from '@sim/terrain/terrain-grid'
import { getAutotileCoords, ATLAS_COLS } from '@sim/terrain/autotile'
import type { ThemeColors } from '@sim/course/theme'
import { TILE_W, TILE_H } from '../grid-transform'
import { generateAtlas } from './atlas'

export const CHUNK_TILES = 32
const REBAKES_PER_FRAME = 2

export class TerrainRenderer {
	readonly container = new Container()

	private renderer: Renderer
	private grid: TerrainGrid
	private chunksX: number
	private chunksY: number
	private chunkSprites: Sprite[] = []
	private chunkTextures: RenderTexture[] = []
	private dirtyChunks = new Set<number>()

	private atlasTexture: Texture | null = null
	private tileFrames: Texture[] = []

	// Scratch container reused for each chunk bake
	private scratch = new Container()

	constructor(renderer: Renderer, grid: TerrainGrid, colors: ThemeColors) {
		this.renderer = renderer
		this.grid = grid
		this.chunksX = Math.ceil(grid.width / CHUNK_TILES)
		this.chunksY = Math.ceil(grid.height / CHUNK_TILES)

		this.buildAtlas(colors)

		for (let cy = 0; cy < this.chunksY; cy++) {
			for (let cx = 0; cx < this.chunksX; cx++) {
				const texture = RenderTexture.create({
					width: CHUNK_TILES * TILE_W,
					height: CHUNK_TILES * TILE_H,
				})
				const sprite = new Sprite(texture)
				sprite.position.set(cx * CHUNK_TILES * TILE_W, cy * CHUNK_TILES * TILE_H)
				this.container.addChild(sprite)
				this.chunkTextures.push(texture)
				this.chunkSprites.push(sprite)
				this.dirtyChunks.add(cy * this.chunksX + cx)
			}
		}
	}

	/** Regenerate the atlas for a new theme and rebake all chunks. */
	setTheme(colors: ThemeColors): void {
		this.buildAtlas(colors)
		for (let i = 0; i < this.chunkSprites.length; i++) this.dirtyChunks.add(i)
	}

	private buildAtlas(colors: ThemeColors): void {
		this.atlasTexture?.destroy(true)
		const canvas = generateAtlas(colors)
		this.atlasTexture = Texture.from(canvas)
		this.tileFrames = []
		for (let row = 0; row < 8; row++) {
			for (let col = 0; col < ATLAS_COLS; col++) {
				this.tileFrames[row * ATLAS_COLS + col] = new Texture({
					source: this.atlasTexture.source,
					frame: new Rectangle(col * TILE_W, row * TILE_H, TILE_W, TILE_H),
				})
			}
		}
	}

	private chunkIndexOf(tileX: number, tileY: number): number {
		return Math.floor(tileY / CHUNK_TILES) * this.chunksX + Math.floor(tileX / CHUNK_TILES)
	}

	/** Mark the chunk containing (x, y) dirty, plus neighbor chunks whose
	 *  tiles' edge masks depend on this tile. */
	markTileDirty(x: number, y: number): void {
		this.dirtyChunks.add(this.chunkIndexOf(x, y))
		for (const [dx, dy] of [
			[0, -1],
			[1, 0],
			[0, 1],
			[-1, 0],
		] as const) {
			const nx = x + dx
			const ny = y + dy
			if (this.grid.isValidPosition(nx, ny)) {
				this.dirtyChunks.add(this.chunkIndexOf(nx, ny))
			}
		}
	}

	/** Rebake up to REBAKES_PER_FRAME dirty chunks and cull offscreen chunks.
	 *  viewRect is the visible world-space rectangle. */
	update(viewRect: Rectangle): void {
		let budget = REBAKES_PER_FRAME
		for (const index of this.dirtyChunks) {
			if (budget-- <= 0) break
			this.bakeChunk(index)
			this.dirtyChunks.delete(index)
		}

		const chunkW = CHUNK_TILES * TILE_W
		const chunkH = CHUNK_TILES * TILE_H
		for (let i = 0; i < this.chunkSprites.length; i++) {
			const cx = (i % this.chunksX) * chunkW
			const cy = Math.floor(i / this.chunksX) * chunkH
			this.chunkSprites[i].visible =
				cx < viewRect.right &&
				cx + chunkW > viewRect.left &&
				cy < viewRect.bottom &&
				cy + chunkH > viewRect.top
		}
	}

	get pendingRebakes(): number {
		return this.dirtyChunks.size
	}

	private bakeChunk(index: number): void {
		const chunkX = (index % this.chunksX) * CHUNK_TILES
		const chunkY = Math.floor(index / this.chunksX) * CHUNK_TILES

		this.scratch.removeChildren().forEach((c) => c.destroy())

		const elevationOverlay = new Graphics()
		for (let ty = 0; ty < CHUNK_TILES; ty++) {
			for (let tx = 0; tx < CHUNK_TILES; tx++) {
				const gx = chunkX + tx
				const gy = chunkY + ty
				if (!this.grid.isValidPosition(gx, gy)) continue
				const type = this.grid.getTile(gx, gy)
				const edgeMask = this.grid.calculateEdgeMask(gx, gy, type)
				const [col, row] = getAutotileCoords(type, edgeMask)
				const sprite = new Sprite(this.tileFrames[row * ATLAS_COLS + col])
				sprite.position.set(tx * TILE_W, ty * TILE_H)
				this.scratch.addChild(sprite)

				// Elevation shading: lighten raised tiles, darken sunken ones.
				// (Placeholder for the heightmap lighting shader — Phase 8.)
				const elevation = this.grid.getElevation(gx, gy)
				if (elevation !== 0) {
					const color = elevation > 0 ? 0xffffff : 0x000000
					const alpha = Math.min(0.3, Math.abs(elevation) * 0.06)
					elevationOverlay
						.rect(tx * TILE_W, ty * TILE_H, TILE_W, TILE_H)
						.fill({ color, alpha })
				}
			}
		}
		this.scratch.addChild(elevationOverlay)

		this.renderer.render({
			container: this.scratch,
			target: this.chunkTextures[index],
			clear: true,
		})
		this.scratch.removeChildren().forEach((c) => c.destroy())
	}
}
