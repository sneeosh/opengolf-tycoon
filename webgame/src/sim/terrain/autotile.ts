// Autotile atlas layout — pure-logic half of scripts/terrain/tileset_generator.gd.
// The atlas has one row per autotiled terrain with 16 edge-mask variants
// (columns), plus a SINGLES row for terrains that don't autotile.

import { TerrainType } from './terrain-types'

export const EDGE_N = 1
export const EDGE_E = 2
export const EDGE_S = 4
export const EDGE_W = 8

export enum TerrainRow {
	GRASS = 0,
	FAIRWAY = 1,
	GREEN = 2,
	ROUGH = 3,
	HEAVY_ROUGH = 4,
	BUNKER = 5,
	WATER = 6,
	SINGLES = 7,
}

export const ATLAS_COLS = 16
export const ATLAS_ROWS = 16

const AUTOTILE_ROWS: Partial<Record<TerrainType, TerrainRow>> = {
	[TerrainType.GRASS]: TerrainRow.GRASS,
	[TerrainType.FAIRWAY]: TerrainRow.FAIRWAY,
	[TerrainType.GREEN]: TerrainRow.GREEN,
	[TerrainType.ROUGH]: TerrainRow.ROUGH,
	[TerrainType.HEAVY_ROUGH]: TerrainRow.HEAVY_ROUGH,
	[TerrainType.BUNKER]: TerrainRow.BUNKER,
	[TerrainType.WATER]: TerrainRow.WATER,
}

const SINGLE_TILE_COLUMNS: Partial<Record<TerrainType, number>> = {
	[TerrainType.EMPTY]: 0,
	[TerrainType.TEE_BOX]: 1,
	[TerrainType.PATH]: 2,
	[TerrainType.OUT_OF_BOUNDS]: 3,
	[TerrainType.TREES]: 4,
	[TerrainType.FLOWER_BED]: 5,
	[TerrainType.ROCKS]: 6,
}

export function terrainUsesAutotile(type: TerrainType): boolean {
	return AUTOTILE_ROWS[type] !== undefined
}

/** Atlas [col, row] for a terrain type with the given edge mask. */
export function getAutotileCoords(type: TerrainType, edgeMask: number): [number, number] {
	const row = AUTOTILE_ROWS[type]
	if (row === undefined) {
		return [SINGLE_TILE_COLUMNS[type] ?? 0, TerrainRow.SINGLES]
	}
	return [edgeMask, row]
}
