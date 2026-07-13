// Terrain type definitions — port of scripts/terrain/terrain_types.gd.
// IDs match data/terrain_types.json and the Godot save format.

export enum TerrainType {
	EMPTY = 0,
	GRASS = 1,
	FAIRWAY = 2,
	ROUGH = 3,
	HEAVY_ROUGH = 4,
	GREEN = 5,
	TEE_BOX = 6,
	BUNKER = 7,
	WATER = 8,
	PATH = 9,
	OUT_OF_BOUNDS = 10,
	TREES = 11,
	FLOWER_BED = 12,
	ROCKS = 13,
}

export interface TerrainProperties {
	name: string
	playable: boolean
	placementCost: number
	maintenanceCost: number
	shotDifficulty: number
	isHazard: boolean
	penaltyStrokes: number
	blocksShots: boolean
	speedModifier: number
	beautyBonus: number
}

const DEFAULTS: Omit<TerrainProperties, 'name'> = {
	playable: false,
	placementCost: 0,
	maintenanceCost: 0,
	shotDifficulty: 0,
	isHazard: false,
	penaltyStrokes: 0,
	blocksShots: false,
	speedModifier: 1.0,
	beautyBonus: 0,
}

function props(name: string, overrides: Partial<TerrainProperties> = {}): TerrainProperties {
	return { name, ...DEFAULTS, ...overrides }
}

export const TERRAIN_PROPERTIES: Record<TerrainType, TerrainProperties> = {
	[TerrainType.EMPTY]: props('Empty'),
	[TerrainType.GRASS]: props('Natural Grass', { playable: true, shotDifficulty: 0.3 }),
	[TerrainType.FAIRWAY]: props('Fairway', { playable: true, placementCost: 5, maintenanceCost: 1 }),
	[TerrainType.ROUGH]: props('Rough', { playable: true, placementCost: 2, shotDifficulty: 0.2 }),
	[TerrainType.HEAVY_ROUGH]: props('Heavy Rough', { playable: true, shotDifficulty: 0.5 }),
	[TerrainType.GREEN]: props('Green', { playable: true, placementCost: 20, maintenanceCost: 2 }),
	[TerrainType.TEE_BOX]: props('Tee Box', { playable: true, placementCost: 12, maintenanceCost: 1 }),
	[TerrainType.BUNKER]: props('Bunker', {
		playable: true,
		placementCost: 10,
		maintenanceCost: 1,
		shotDifficulty: 0.6,
		isHazard: true,
	}),
	[TerrainType.WATER]: props('Water', {
		placementCost: 20,
		maintenanceCost: 1,
		isHazard: true,
		penaltyStrokes: 1,
	}),
	[TerrainType.PATH]: props('Cart Path', {
		playable: true,
		placementCost: 8,
		shotDifficulty: 0.1,
		speedModifier: 1.5,
	}),
	[TerrainType.OUT_OF_BOUNDS]: props('Out of Bounds', { penaltyStrokes: 1 }),
	[TerrainType.TREES]: props('Trees', {
		playable: true,
		placementCost: 10,
		shotDifficulty: 0.7,
		blocksShots: true,
	}),
	[TerrainType.FLOWER_BED]: props('Flower Bed', {
		placementCost: 15,
		maintenanceCost: 1,
		beautyBonus: 5,
	}),
	[TerrainType.ROCKS]: props('Rocks', { playable: true, placementCost: 8, shotDifficulty: 0.8 }),
}

export function getTerrainProperties(type: TerrainType): TerrainProperties {
	return TERRAIN_PROPERTIES[type] ?? TERRAIN_PROPERTIES[TerrainType.EMPTY]
}

export const ALL_TERRAIN_TYPES: TerrainType[] = Object.keys(TERRAIN_PROPERTIES).map(Number)

/** Grass-family terrains transition smoothly into each other (no autotile edge). */
export const GRASS_FAMILY: readonly TerrainType[] = [
	TerrainType.GRASS,
	TerrainType.FAIRWAY,
	TerrainType.ROUGH,
	TerrainType.HEAVY_ROUGH,
]
