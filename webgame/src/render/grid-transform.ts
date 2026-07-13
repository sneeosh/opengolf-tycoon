// Grid <-> world transforms. The Godot game renders its "isometric" course as
// a plain rectangular grid of 64x32 tiles (terrain_grid.gd grid_to_screen is
// x*tile_width, y*tile_height — no diamond projection), so we mirror that
// exactly for visual and coordinate parity.

export const TILE_W = 64
export const TILE_H = 32

export function gridToWorld(gx: number, gy: number): { x: number; y: number } {
	return { x: gx * TILE_W, y: gy * TILE_H }
}

export function gridToWorldCenter(gx: number, gy: number): { x: number; y: number } {
	return { x: gx * TILE_W + TILE_W / 2, y: gy * TILE_H + TILE_H / 2 }
}

export function worldToGrid(wx: number, wy: number): { x: number; y: number } {
	return { x: Math.floor(wx / TILE_W), y: Math.floor(wy / TILE_H) }
}
