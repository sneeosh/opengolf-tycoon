// TerrainGrid — port of the data-model half of scripts/terrain/terrain_grid.gd.
// Pure simulation state: no rendering. Tile/elevation/bunker-depth storage,
// edge masks for autotiling, spatial queries, and Godot-save-compatible
// (de)serialization. Rendering listens to the change callbacks.

import { TerrainType, GRASS_FAMILY, getTerrainProperties } from './terrain-types'
import { EDGE_N, EDGE_E, EDGE_S, EDGE_W, terrainUsesAutotile } from './autotile'

export const YARDS_PER_TILE = 22.0

export interface TileChange {
	x: number
	y: number
	oldType: TerrainType
	newType: TerrainType
}

export interface ElevationChange {
	x: number
	y: number
	oldElevation: number
	newElevation: number
}

export interface Vec2i {
	x: number
	y: number
}

const NEIGHBORS_4: readonly Vec2i[] = [
	{ x: 0, y: -1 }, // North
	{ x: 1, y: 0 }, // East
	{ x: 0, y: 1 }, // South
	{ x: -1, y: 0 }, // West
]

export class TerrainGrid {
	readonly width: number
	readonly height: number

	// Sparse maps keyed by packed y*width+x. Tiles default to GRASS (the Godot
	// grid initializes every cell to GRASS), elevation/bunker depth to 0.
	private grid = new Map<number, TerrainType>()
	private elevationGrid = new Map<number, number>()
	private bunkerDepthGrid = new Map<number, number>()
	private playerPlacedTiles = new Set<number>()

	private batchMode = false
	private batchChanges: TileChange[] = []

	onTileChanged: ((change: TileChange) => void) | null = null
	onElevationChanged: ((change: ElevationChange) => void) | null = null

	constructor(width = 128, height = 128) {
		this.width = width
		this.height = height
	}

	private key(x: number, y: number): number {
		return y * this.width + x
	}

	isValidPosition(x: number, y: number): boolean {
		return x >= 0 && x < this.width && y >= 0 && y < this.height
	}

	getTile(x: number, y: number): TerrainType {
		if (!this.isValidPosition(x, y)) return TerrainType.OUT_OF_BOUNDS
		return this.grid.get(this.key(x, y)) ?? TerrainType.GRASS
	}

	setTile(x: number, y: number, type: TerrainType, playerPlaced = true): void {
		if (!this.isValidPosition(x, y)) return
		const oldType = this.getTile(x, y)
		if (oldType === type) return
		if (type === TerrainType.GRASS) {
			this.grid.delete(this.key(x, y))
		} else {
			this.grid.set(this.key(x, y), type)
		}
		if (playerPlaced) this.playerPlacedTiles.add(this.key(x, y))
		const change: TileChange = { x, y, oldType, newType: type }
		if (this.batchMode) {
			this.batchChanges.push(change)
		} else {
			this.onTileChanged?.(change)
		}
	}

	/** Set tile without marking as player-placed (auto-generation). */
	setTileNatural(x: number, y: number, type: TerrainType): void {
		this.setTile(x, y, type, false)
	}

	/** Defer change callbacks until endBatch() (bulk generation/painting). */
	beginBatch(): void {
		this.batchMode = true
		this.batchChanges = []
	}

	endBatch(): void {
		this.batchMode = false
		for (const change of this.batchChanges) {
			this.onTileChanged?.(change)
		}
		this.batchChanges = []
	}

	/** End batch without emitting deferred changes (bulk load — caller refreshes). */
	endBatchQuiet(): void {
		this.batchMode = false
		this.batchChanges = []
	}

	getElevation(x: number, y: number): number {
		return this.elevationGrid.get(this.key(x, y)) ?? 0
	}

	/** Clamped to -5..+5, matching the Godot elevation range. */
	setElevation(x: number, y: number, elevation: number): void {
		if (!this.isValidPosition(x, y)) return
		const oldElevation = this.getElevation(x, y)
		const newElevation = Math.max(-5, Math.min(5, Math.trunc(elevation)))
		if (oldElevation === newElevation) return
		if (newElevation === 0) {
			this.elevationGrid.delete(this.key(x, y))
		} else {
			this.elevationGrid.set(this.key(x, y), newElevation)
		}
		this.onElevationChanged?.({ x, y, oldElevation, newElevation })
	}

	getElevationDifference(fromX: number, fromY: number, toX: number, toY: number): number {
		return this.getElevation(toX, toY) - this.getElevation(fromX, fromY)
	}

	/** Downhill slope direction (normalized), or (0,0) on flat ground. */
	getSlopeDirection(x: number, y: number): { x: number; y: number } {
		const currentElev = this.getElevation(x, y)
		let sx = 0
		let sy = 0
		for (const n of NEIGHBORS_4) {
			const nx = x + n.x
			const ny = y + n.y
			if (!this.isValidPosition(nx, ny)) continue
			const diff = currentElev - this.getElevation(nx, ny)
			if (diff > 0) {
				sx += n.x * diff
				sy += n.y * diff
			}
		}
		const len = Math.hypot(sx, sy)
		if (len === 0) return { x: 0, y: 0 }
		return { x: sx / len, y: sy / len }
	}

	getBunkerDepth(x: number, y: number): number {
		return this.bunkerDepthGrid.get(this.key(x, y)) ?? 0
	}

	setBunkerDepth(x: number, y: number, depth: number): void {
		if (depth === 0) {
			this.bunkerDepthGrid.delete(this.key(x, y))
		} else {
			this.bunkerDepthGrid.set(this.key(x, y), depth)
		}
	}

	calculateDistanceYards(fromX: number, fromY: number, toX: number, toY: number): number {
		return Math.trunc(Math.hypot(toX - fromX, toY - fromY) * YARDS_PER_TILE)
	}

	/**
	 * Edge mask for autotiling: bit set where the neighbor is a different
	 * terrain. Grass-family terrains blend smoothly (no edge between them).
	 */
	calculateEdgeMask(x: number, y: number, type: TerrainType): number {
		if (!terrainUsesAutotile(type)) return 0
		let mask = 0
		if (this.isDifferentTerrain(x, y - 1, type)) mask |= EDGE_N
		if (this.isDifferentTerrain(x + 1, y, type)) mask |= EDGE_E
		if (this.isDifferentTerrain(x, y + 1, type)) mask |= EDGE_S
		if (this.isDifferentTerrain(x - 1, y, type)) mask |= EDGE_W
		return mask
	}

	private isDifferentTerrain(x: number, y: number, type: TerrainType): boolean {
		if (!this.isValidPosition(x, y)) return true
		const neighborType = this.getTile(x, y)
		if (neighborType === type) return false
		if (GRASS_FAMILY.includes(type) && GRASS_FAMILY.includes(neighborType)) return false
		return true
	}

	/** Square brush of tiles centered on (cx, cy), clipped to the grid. */
	getBrushTiles(cx: number, cy: number, brushSize: number): Vec2i[] {
		const tiles: Vec2i[] = []
		const half = Math.trunc((brushSize - 1) / 2)
		for (let dx = -half; dx <= half; dx++) {
			for (let dy = -half; dy <= half; dy++) {
				const x = cx + dx
				const y = cy + dy
				if (this.isValidPosition(x, y)) tiles.push({ x, y })
			}
		}
		return tiles
	}

	paintTiles(tiles: Vec2i[], type: TerrainType): void {
		for (const t of tiles) this.setTile(t.x, t.y, type)
	}

	/**
	 * Daily maintenance for player-placed tiles, with sqrt scaling so large
	 * courses aren't crushed by per-tile costs (raw $900 → ~$600).
	 */
	getTotalMaintenanceCost(): number {
		let rawTotal = 0
		for (const key of this.playerPlacedTiles) {
			const type = this.grid.get(key)
			if (type !== undefined) rawTotal += getTerrainProperties(type).maintenanceCost
		}
		return Math.trunc(Math.sqrt(rawTotal) * 20.0)
	}

	/** Flood-fill of connected same-type tiles (4-neighbor). */
	getConnectedTiles(startX: number, startY: number, type: TerrainType): Vec2i[] {
		const connected: Vec2i[] = []
		const visited = new Set<number>()
		const queue: Vec2i[] = [{ x: startX, y: startY }]
		while (queue.length > 0) {
			const pos = queue.shift()!
			if (!this.isValidPosition(pos.x, pos.y)) continue
			const k = this.key(pos.x, pos.y)
			if (visited.has(k)) continue
			visited.add(k)
			if (this.getTile(pos.x, pos.y) !== type) continue
			connected.push(pos)
			for (const n of NEIGHBORS_4) queue.push({ x: pos.x + n.x, y: pos.y + n.y })
		}
		return connected
	}

	// ---- Save format (matches Godot SaveManager v2: "x,y" string keys, ----
	// ---- GRASS omitted from the tile dictionary) ----

	serialize(): Record<string, number> {
		const data: Record<string, number> = {}
		for (const [key, type] of this.grid) {
			const x = key % this.width
			const y = Math.trunc(key / this.width)
			data[`${x},${y}`] = type
		}
		return data
	}

	serializeElevation(): Record<string, number> {
		const data: Record<string, number> = {}
		for (const [key, elev] of this.elevationGrid) {
			const x = key % this.width
			const y = Math.trunc(key / this.width)
			data[`${x},${y}`] = elev
		}
		return data
	}

	serializePlayerPlaced(): string[] {
		const data: string[] = []
		for (const key of this.playerPlacedTiles) {
			const x = key % this.width
			const y = Math.trunc(key / this.width)
			data.push(`${x},${y}`)
		}
		return data
	}

	serializeBunkerDepth(): Record<string, number> {
		const data: Record<string, number> = {}
		for (const [key, depth] of this.bunkerDepthGrid) {
			const x = key % this.width
			const y = Math.trunc(key / this.width)
			data[`${x},${y}`] = depth
		}
		return data
	}

	deserialize(data: Record<string, number>): void {
		this.grid.clear()
		this.playerPlacedTiles.clear()
		for (const [key, type] of Object.entries(data)) {
			const [x, y] = key.split(',').map(Number)
			if (this.isValidPosition(x, y) && type !== TerrainType.GRASS) {
				this.grid.set(this.key(x, y), type)
			}
		}
	}

	deserializeElevation(data: Record<string, number>): void {
		this.elevationGrid.clear()
		for (const [key, elev] of Object.entries(data)) {
			const [x, y] = key.split(',').map(Number)
			if (this.isValidPosition(x, y) && elev !== 0) {
				this.elevationGrid.set(this.key(x, y), elev)
			}
		}
	}

	deserializePlayerPlaced(data: string[]): void {
		this.playerPlacedTiles.clear()
		for (const key of data) {
			const [x, y] = key.split(',').map(Number)
			if (this.isValidPosition(x, y)) this.playerPlacedTiles.add(this.key(x, y))
		}
	}

	deserializeBunkerDepth(data: Record<string, number>): void {
		this.bunkerDepthGrid.clear()
		for (const [key, depth] of Object.entries(data)) {
			const [x, y] = key.split(',').map(Number)
			if (this.isValidPosition(x, y) && depth !== 0) {
				this.bunkerDepthGrid.set(this.key(x, y), depth)
			}
		}
	}
}
