import { describe, expect, it } from 'vitest'
import { TerrainGrid, YARDS_PER_TILE } from './terrain-grid'
import { TerrainType } from './terrain-types'
import { EDGE_N, EDGE_E, EDGE_S, EDGE_W, getAutotileCoords, TerrainRow } from './autotile'

describe('TerrainGrid', () => {
	it('defaults every valid tile to GRASS (Godot grid init parity)', () => {
		const grid = new TerrainGrid()
		expect(grid.getTile(0, 0)).toBe(TerrainType.GRASS)
		expect(grid.getTile(127, 127)).toBe(TerrainType.GRASS)
	})

	it('returns OUT_OF_BOUNDS outside the grid', () => {
		const grid = new TerrainGrid()
		expect(grid.getTile(-1, 0)).toBe(TerrainType.OUT_OF_BOUNDS)
		expect(grid.getTile(128, 5)).toBe(TerrainType.OUT_OF_BOUNDS)
		expect(grid.getTile(5, 128)).toBe(TerrainType.OUT_OF_BOUNDS)
	})

	it('sets and gets tiles, firing the change callback', () => {
		const grid = new TerrainGrid()
		const changes: number[] = []
		grid.onTileChanged = (c) => changes.push(c.newType)
		grid.setTile(10, 10, TerrainType.FAIRWAY)
		expect(grid.getTile(10, 10)).toBe(TerrainType.FAIRWAY)
		expect(changes).toEqual([TerrainType.FAIRWAY])
		// Setting the same type again is a no-op
		grid.setTile(10, 10, TerrainType.FAIRWAY)
		expect(changes).toHaveLength(1)
	})

	it('defers change callbacks in batch mode', () => {
		const grid = new TerrainGrid()
		const changes: number[] = []
		grid.onTileChanged = (c) => changes.push(c.newType)
		grid.beginBatch()
		grid.setTile(1, 1, TerrainType.WATER)
		grid.setTile(2, 1, TerrainType.WATER)
		expect(changes).toHaveLength(0)
		grid.endBatch()
		expect(changes).toHaveLength(2)
	})

	it('clamps elevation to -5..+5 and drops zero entries', () => {
		const grid = new TerrainGrid()
		grid.setElevation(3, 3, 99)
		expect(grid.getElevation(3, 3)).toBe(5)
		grid.setElevation(3, 3, -99)
		expect(grid.getElevation(3, 3)).toBe(-5)
		grid.setElevation(3, 3, 0)
		expect(grid.getElevation(3, 3)).toBe(0)
		expect(grid.serializeElevation()).toEqual({})
	})

	it('calculates distance in yards at 22 yards/tile (3-4-5 triangle)', () => {
		const grid = new TerrainGrid()
		expect(grid.calculateDistanceYards(0, 0, 3, 4)).toBe(5 * YARDS_PER_TILE)
		expect(grid.calculateDistanceYards(0, 0, 10, 0)).toBe(220)
	})

	it('computes slope direction pointing downhill', () => {
		const grid = new TerrainGrid()
		grid.setElevation(5, 5, 3)
		// (5,5) is a peak; slope at the peak points away from it — all
		// neighbors are lower and equal, so contributions cancel except none.
		// Check a tile east of the peak: downhill is further east (+x).
		const slope = grid.getSlopeDirection(5, 5)
		// Symmetric peak: contributions cancel to zero
		expect(slope).toEqual({ x: 0, y: 0 })

		grid.setElevation(4, 5, 3) // ridge extending west — now east/north/south are downhill
		const ridgeSlope = grid.getSlopeDirection(5, 5)
		expect(ridgeSlope.x).toBeGreaterThan(0) // net downhill points east
	})

	it('calculates autotile edge masks with grass-family smoothing', () => {
		const grid = new TerrainGrid()
		grid.setTile(10, 10, TerrainType.BUNKER)
		// Bunker surrounded by grass: all four edges differ
		expect(grid.calculateEdgeMask(10, 10, TerrainType.BUNKER)).toBe(
			EDGE_N | EDGE_E | EDGE_S | EDGE_W,
		)
		// Fairway next to grass: same family, no edges
		grid.setTile(20, 20, TerrainType.FAIRWAY)
		expect(grid.calculateEdgeMask(20, 20, TerrainType.FAIRWAY)).toBe(0)
		// Green next to fairway IS an edge (green is not in the grass family)
		grid.setTile(30, 30, TerrainType.GREEN)
		grid.setTile(31, 30, TerrainType.FAIRWAY)
		expect(grid.calculateEdgeMask(30, 30, TerrainType.GREEN)).toBe(
			EDGE_N | EDGE_E | EDGE_S | EDGE_W,
		)
		// Two adjacent water tiles don't edge against each other
		grid.setTile(50, 50, TerrainType.WATER)
		grid.setTile(51, 50, TerrainType.WATER)
		expect(grid.calculateEdgeMask(50, 50, TerrainType.WATER)).toBe(EDGE_N | EDGE_S | EDGE_W)
	})

	it('treats grid borders as different terrain for edge masks', () => {
		const grid = new TerrainGrid()
		grid.setTile(0, 0, TerrainType.WATER)
		expect(grid.calculateEdgeMask(0, 0, TerrainType.WATER)).toBe(
			EDGE_N | EDGE_E | EDGE_S | EDGE_W,
		)
	})

	it('builds square brush footprints clipped to the grid', () => {
		const grid = new TerrainGrid()
		expect(grid.getBrushTiles(5, 5, 1)).toHaveLength(1)
		expect(grid.getBrushTiles(5, 5, 3)).toHaveLength(9)
		expect(grid.getBrushTiles(0, 0, 3)).toHaveLength(4) // clipped at corner
	})

	it('flood-fills connected same-type tiles', () => {
		const grid = new TerrainGrid()
		grid.setTile(1, 1, TerrainType.WATER)
		grid.setTile(2, 1, TerrainType.WATER)
		grid.setTile(2, 2, TerrainType.WATER)
		grid.setTile(9, 9, TerrainType.WATER) // disconnected
		expect(grid.getConnectedTiles(1, 1, TerrainType.WATER)).toHaveLength(3)
	})

	it('scales maintenance with sqrt (raw 900 → 600, Godot parity)', () => {
		const grid = new TerrainGrid()
		// GREEN has maintenance cost 2; place 450 player tiles → raw 900
		grid.beginBatch()
		let placed = 0
		for (let y = 0; y < 128 && placed < 450; y++) {
			for (let x = 0; x < 128 && placed < 450; x++) {
				grid.setTile(x, y, TerrainType.GREEN)
				placed++
			}
		}
		grid.endBatchQuiet()
		expect(grid.getTotalMaintenanceCost()).toBe(600)
	})

	it('round-trips the Godot save format ("x,y" keys, GRASS omitted)', () => {
		const grid = new TerrainGrid()
		grid.setTile(3, 4, TerrainType.WATER)
		grid.setTile(10, 20, TerrainType.BUNKER)
		grid.setElevation(7, 8, -3)
		grid.setBunkerDepth(10, 20, 1)

		const tiles = grid.serialize()
		expect(tiles).toEqual({ '3,4': TerrainType.WATER, '10,20': TerrainType.BUNKER })

		const restored = new TerrainGrid()
		restored.deserialize(tiles)
		restored.deserializeElevation(grid.serializeElevation())
		restored.deserializeBunkerDepth(grid.serializeBunkerDepth())
		restored.deserializePlayerPlaced(grid.serializePlayerPlaced())

		expect(restored.getTile(3, 4)).toBe(TerrainType.WATER)
		expect(restored.getTile(10, 20)).toBe(TerrainType.BUNKER)
		expect(restored.getTile(0, 0)).toBe(TerrainType.GRASS)
		expect(restored.getElevation(7, 8)).toBe(-3)
		expect(restored.getBunkerDepth(10, 20)).toBe(1)
		expect(restored.getTotalMaintenanceCost()).toBe(grid.getTotalMaintenanceCost())
	})
})

describe('autotile atlas layout (tileset_generator.gd parity)', () => {
	it('maps autotiled terrains to their rows with edge mask as column', () => {
		expect(getAutotileCoords(TerrainType.GRASS, 5)).toEqual([5, TerrainRow.GRASS])
		expect(getAutotileCoords(TerrainType.FAIRWAY, 0)).toEqual([0, TerrainRow.FAIRWAY])
		expect(getAutotileCoords(TerrainType.GREEN, 15)).toEqual([15, TerrainRow.GREEN])
		expect(getAutotileCoords(TerrainType.ROUGH, 3)).toEqual([3, TerrainRow.ROUGH])
		expect(getAutotileCoords(TerrainType.HEAVY_ROUGH, 8)).toEqual([8, TerrainRow.HEAVY_ROUGH])
		expect(getAutotileCoords(TerrainType.BUNKER, 12)).toEqual([12, TerrainRow.BUNKER])
		expect(getAutotileCoords(TerrainType.WATER, 15)).toEqual([15, TerrainRow.WATER])
	})

	it('maps single-tile terrains to the SINGLES row columns', () => {
		expect(getAutotileCoords(TerrainType.EMPTY, 0)).toEqual([0, TerrainRow.SINGLES])
		expect(getAutotileCoords(TerrainType.TEE_BOX, 9)).toEqual([1, TerrainRow.SINGLES])
		expect(getAutotileCoords(TerrainType.PATH, 0)).toEqual([2, TerrainRow.SINGLES])
		expect(getAutotileCoords(TerrainType.OUT_OF_BOUNDS, 0)).toEqual([3, TerrainRow.SINGLES])
		expect(getAutotileCoords(TerrainType.TREES, 0)).toEqual([4, TerrainRow.SINGLES])
		expect(getAutotileCoords(TerrainType.FLOWER_BED, 0)).toEqual([5, TerrainRow.SINGLES])
		expect(getAutotileCoords(TerrainType.ROCKS, 0)).toEqual([6, TerrainRow.SINGLES])
	})
})
