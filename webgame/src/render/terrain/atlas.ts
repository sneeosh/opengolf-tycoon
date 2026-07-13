// Runtime terrain tile atlas — port of tileset_generator.gd's web branch
// (flat-fill base + smooth edge blending, no per-pixel noise). Generates a
// 1024x512 canvas: rows 0-6 are autotiled terrains with 16 edge-mask variants,
// row 7 holds single-tile terrains. Regenerated on theme change.

import type { ThemeColors, Rgb, TerrainColorKey } from '@sim/course/theme'
import { ATLAS_COLS, TerrainRow } from '@sim/terrain/autotile'
import { EDGE_N, EDGE_E, EDGE_S, EDGE_W } from '@sim/terrain/autotile'
import { TILE_W, TILE_H } from '../grid-transform'

const EDGE_WIDTH = 16
const CORNER_BLEND_RADIUS = 20.0

export const ATLAS_W = TILE_W * ATLAS_COLS // 1024
export const ATLAS_H = TILE_H * 16 // 512 (16 rows reserved, 8 used)

// Autotiled rows blend toward a neighbor-family color at flagged edges,
// mirroring _generate_terrain_row_fast calls in tileset_generator.gd.
const AUTOTILE_ROW_COLORS: Array<{ row: TerrainRow; base: TerrainColorKey; edge: TerrainColorKey }> = [
	{ row: TerrainRow.GRASS, base: 'grass', edge: 'rough' },
	{ row: TerrainRow.FAIRWAY, base: 'fairway_light', edge: 'rough' },
	{ row: TerrainRow.GREEN, base: 'green_light', edge: 'fringe' },
	{ row: TerrainRow.ROUGH, base: 'rough', edge: 'heavy_rough' },
	{ row: TerrainRow.HEAVY_ROUGH, base: 'heavy_rough', edge: 'grass' },
	{ row: TerrainRow.BUNKER, base: 'bunker', edge: 'grass' },
	{ row: TerrainRow.WATER, base: 'water', edge: 'grass' },
]

// SINGLES row columns (order matches tileset_generator.gd / autotile.ts)
const SINGLE_TILE_COLORS: TerrainColorKey[] = [
	'empty',
	'tee_box_light',
	'path',
	'oob',
	'trees',
	'flower_bed',
	'rocks',
]

function smoothFalloff(t: number): number {
	t = Math.max(0, Math.min(1, t))
	return t * t * (3.0 - 2.0 * t)
}

function isInEdgeZone(localX: number, localY: number, edgeMask: number): boolean {
	const inN = localY < EDGE_WIDTH && (edgeMask & EDGE_N) !== 0
	const inS = localY >= TILE_H - EDGE_WIDTH && (edgeMask & EDGE_S) !== 0
	const inW = localX < EDGE_WIDTH && (edgeMask & EDGE_W) !== 0
	const inE = localX >= TILE_W - EDGE_WIDTH && (edgeMask & EDGE_E) !== 0
	return inN || inS || inW || inE
}

function edgeBlendFactor(localX: number, localY: number, edgeMask: number): number {
	let maxBlend = 0

	if (edgeMask & EDGE_N) {
		const t = localY / EDGE_WIDTH
		if (t < 1.0) maxBlend = Math.max(maxBlend, smoothFalloff(1.0 - t))
	}
	if (edgeMask & EDGE_S) {
		const t = (TILE_H - 1 - localY) / EDGE_WIDTH
		if (t < 1.0) maxBlend = Math.max(maxBlend, smoothFalloff(1.0 - t))
	}
	if (edgeMask & EDGE_W) {
		const t = localX / EDGE_WIDTH
		if (t < 1.0) maxBlend = Math.max(maxBlend, smoothFalloff(1.0 - t))
	}
	if (edgeMask & EDGE_E) {
		const t = (TILE_W - 1 - localX) / EDGE_WIDTH
		if (t < 1.0) maxBlend = Math.max(maxBlend, smoothFalloff(1.0 - t))
	}

	// Diagonal corner smoothing where two edges meet
	const corners: Array<[number, number, number]> = [
		[EDGE_N | EDGE_W, localX, localY],
		[EDGE_N | EDGE_E, TILE_W - 1 - localX, localY],
		[EDGE_S | EDGE_W, localX, TILE_H - 1 - localY],
		[EDGE_S | EDGE_E, TILE_W - 1 - localX, TILE_H - 1 - localY],
	]
	for (const [bits, dx, dy] of corners) {
		if ((edgeMask & bits) === bits) {
			const dist = Math.hypot(dx, dy)
			if (dist < CORNER_BLEND_RADIUS) {
				maxBlend = Math.max(maxBlend, smoothFalloff(1.0 - dist / CORNER_BLEND_RADIUS))
			}
		}
	}

	return Math.min(1, maxBlend)
}

function setPixel(data: Uint8ClampedArray, idx: number, rgb: Rgb): void {
	data[idx] = Math.round(rgb[0] * 255)
	data[idx + 1] = Math.round(rgb[1] * 255)
	data[idx + 2] = Math.round(rgb[2] * 255)
	data[idx + 3] = 255
}

function lerpRgb(a: Rgb, b: Rgb, t: number): Rgb {
	return [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t]
}

/** Generate the full tile atlas onto a canvas for the given theme palette. */
export function generateAtlas(colors: ThemeColors): HTMLCanvasElement {
	const canvas = document.createElement('canvas')
	canvas.width = ATLAS_W
	canvas.height = ATLAS_H
	const ctx = canvas.getContext('2d')!
	const imageData = ctx.createImageData(ATLAS_W, ATLAS_H)
	const data = imageData.data

	for (const { row, base, edge } of AUTOTILE_ROW_COLORS) {
		const baseColor = colors[base]
		const edgeColor = colors[edge]
		for (let edgeMask = 0; edgeMask < 16; edgeMask++) {
			const tileX = edgeMask * TILE_W
			const tileY = row * TILE_H
			for (let ly = 0; ly < TILE_H; ly++) {
				let idx = ((tileY + ly) * ATLAS_W + tileX) * 4
				for (let lx = 0; lx < TILE_W; lx++, idx += 4) {
					let rgb = baseColor
					if (edgeMask !== 0 && isInEdgeZone(lx, ly, edgeMask)) {
						const blend = edgeBlendFactor(lx, ly, edgeMask)
						if (blend > 0.05) rgb = lerpRgb(baseColor, edgeColor, blend * 0.5)
					}
					setPixel(data, idx, rgb)
				}
			}
		}
	}

	SINGLE_TILE_COLORS.forEach((key, col) => {
		const rgb = colors[key]
		const tileX = col * TILE_W
		const tileY = TerrainRow.SINGLES * TILE_H
		for (let ly = 0; ly < TILE_H; ly++) {
			let idx = ((tileY + ly) * ATLAS_W + tileX) * 4
			for (let lx = 0; lx < TILE_W; lx++, idx += 4) {
				setPixel(data, idx, rgb)
			}
		}
	})

	ctx.putImageData(imageData, 0, 0)
	return canvas
}
