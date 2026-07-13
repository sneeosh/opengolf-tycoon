// Loads the repo's data/*.json files (shared verbatim with the Godot build)
// from public/data/, where tools/copy-data.mjs places them.

export interface TerrainTypeData {
	id: number
	name: string
	playable: boolean
	placement_cost: number
	maintenance_cost?: number
	is_hazard?: boolean
	penalty_strokes?: number
	blocks_shots?: boolean
}

export interface GameData {
	terrainTypes: Record<string, TerrainTypeData>
}

async function fetchJson<T>(path: string): Promise<T> {
	const response = await fetch(path)
	if (!response.ok) throw new Error(`Failed to load ${path}: ${response.status}`)
	return response.json() as Promise<T>
}

export async function loadGameData(): Promise<GameData> {
	const terrainJson = await fetchJson<{ terrain_types: Record<string, TerrainTypeData> }>(
		'./data/terrain_types.json',
	)
	return { terrainTypes: terrainJson.terrain_types }
}
