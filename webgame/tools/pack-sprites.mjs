// Build-time sprite packer: walks ../assets/sprites (shared with the Godot
// build), shelf-packs each group into 2048px-wide atlas pages, and emits
// PixiJS spritesheet JSON + PNG into public/atlas/.
//
// Frame names are the sprite's repo-relative path without extension
// (e.g. "golfer/pro/animations/walk/east/frame_000") so the two codebases
// stay greppable against each other.
//
// Usage: node tools/pack-sprites.mjs [--force]

import { readdir, readFile, writeFile, mkdir, stat } from 'node:fs/promises'
import { dirname, join, relative, sep } from 'node:path'
import { fileURLToPath } from 'node:url'
import { PNG } from 'pngjs'

const here = dirname(fileURLToPath(import.meta.url))
const spritesRoot = join(here, '..', '..', 'assets', 'sprites')
const outDir = join(here, '..', 'public', 'atlas')

const PAGE_WIDTH = 2048
const PADDING = 2 // guard pixels between frames (prevents bleeding)

// Group name -> top-level directories included. "tiles" is skipped — terrain
// is procedurally generated at runtime.
const GROUPS = {
	'golfer-beginner': ['golfer/beginner'],
	'golfer-casual': ['golfer/casual'],
	'golfer-serious': ['golfer/serious'],
	'golfer-pro': ['golfer/pro'],
	buildings: ['buildings'],
	environment: ['trees', 'rocks', 'decorations', 'flag', 'golf_cart'],
}

async function walkPngs(dir) {
	const out = []
	let entries
	try {
		entries = await readdir(dir, { withFileTypes: true })
	} catch {
		return out
	}
	for (const entry of entries) {
		const full = join(dir, entry.name)
		if (entry.isDirectory()) out.push(...(await walkPngs(full)))
		else if (entry.name.endsWith('.png')) out.push(full)
	}
	return out
}

async function exists(path) {
	try {
		await stat(path)
		return true
	} catch {
		return false
	}
}

async function packGroup(groupName, dirs) {
	// Collect frames
	const frames = []
	for (const dir of dirs) {
		for (const file of await walkPngs(join(spritesRoot, dir))) {
			const png = PNG.sync.read(await readFile(file))
			const name = relative(spritesRoot, file).split(sep).join('/').replace(/\.png$/, '')
			frames.push({ name, png })
		}
	}
	if (frames.length === 0) return null

	// Shelf pack: tallest first, rows across a fixed-width page
	frames.sort((a, b) => b.png.height - a.png.height || a.name.localeCompare(b.name))
	let x = PADDING
	let y = PADDING
	let rowHeight = 0
	let pageWidth = 0
	for (const frame of frames) {
		if (x + frame.png.width + PADDING > PAGE_WIDTH) {
			x = PADDING
			y += rowHeight + PADDING
			rowHeight = 0
		}
		frame.x = x
		frame.y = y
		x += frame.png.width + PADDING
		rowHeight = Math.max(rowHeight, frame.png.height)
		pageWidth = Math.max(pageWidth, frame.x + frame.png.width + PADDING)
	}
	const pageHeight = y + rowHeight + PADDING

	// Compose the atlas
	const atlas = new PNG({ width: pageWidth, height: pageHeight })
	for (const frame of frames) {
		PNG.bitblt(frame.png, atlas, 0, 0, frame.png.width, frame.png.height, frame.x, frame.y)
	}

	// Pixi spritesheet JSON
	const sheet = {
		frames: Object.fromEntries(
			frames.map((f) => [
				f.name,
				{
					frame: { x: f.x, y: f.y, w: f.png.width, h: f.png.height },
					rotated: false,
					trimmed: false,
					spriteSourceSize: { x: 0, y: 0, w: f.png.width, h: f.png.height },
					sourceSize: { w: f.png.width, h: f.png.height },
				},
			]),
		),
		meta: {
			image: `${groupName}.png`,
			format: 'RGBA8888',
			size: { w: pageWidth, h: pageHeight },
			scale: '1',
		},
	}

	await writeFile(join(outDir, `${groupName}.png`), PNG.sync.write(atlas))
	await writeFile(join(outDir, `${groupName}.json`), JSON.stringify(sheet))
	return { frames: frames.length, width: pageWidth, height: pageHeight }
}

const force = process.argv.includes('--force')
await mkdir(outDir, { recursive: true })

if (!force && (await exists(join(outDir, 'golfer-pro.json')))) {
	console.log('atlas already packed — use --force to rebuild')
	process.exit(0)
}

for (const [groupName, dirs] of Object.entries(GROUPS)) {
	const result = await packGroup(groupName, dirs)
	if (result) {
		console.log(
			`${groupName}: ${result.frames} frames -> ${result.width}x${result.height}`,
		)
	} else {
		console.log(`${groupName}: no frames found, skipped`)
	}
}
