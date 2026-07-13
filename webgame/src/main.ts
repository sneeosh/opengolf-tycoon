// Boot: load data → create sim → create Pixi renderer → wire UI → run loop.

import { Application, Container } from 'pixi.js'
import { Game, GameSpeed } from '@sim/game'
import { getTerrainColors } from '@sim/course/theme'
import { TerrainType } from '@sim/terrain/terrain-types'
import { EventBus } from './events'
import { GameLoop } from './loop'
import { loadGameData } from './data/loader'
import { Camera } from '@render/camera'
import { TerrainRenderer } from '@render/terrain/terrain-renderer'
import { worldToGrid, gridToWorldCenter, TILE_W, TILE_H } from '@render/grid-transform'
import { Toolbar } from '@ui/toolbar'

async function boot(): Promise<void> {
	const gameData = await loadGameData()

	const events = new EventBus()
	const game = new Game()
	game.speed = GameSpeed.PAUSED // no sim systems yet in Phase 1
	const loop = new GameLoop(game)

	// Wire terrain change callbacks to the event bus
	game.terrain.onTileChanged = (c) =>
		events.emit('terrainTileChanged', { x: c.x, y: c.y, oldType: c.oldType, newType: c.newType })
	game.terrain.onElevationChanged = (c) =>
		events.emit('elevationChanged', {
			x: c.x,
			y: c.y,
			oldElevation: c.oldElevation,
			newElevation: c.newElevation,
		})

	// Pixi application
	const app = new Application()
	await app.init({
		resizeTo: window,
		background: 0x10140f,
		antialias: false,
		preference: 'webgl',
	})
	document.getElementById('game')!.appendChild(app.canvas)

	const world = new Container()
	app.stage.addChild(world)

	const terrainRenderer = new TerrainRenderer(
		app.renderer,
		game.terrain,
		getTerrainColors(game.theme),
	)
	world.addChild(terrainRenderer.container)

	events.on('terrainTileChanged', ({ x, y }) => terrainRenderer.markTileDirty(x, y))
	events.on('elevationChanged', ({ x, y }) => terrainRenderer.markTileDirty(x, y))

	const camera = new Camera(world, app.canvas)
	camera.resize(app.screen.width, app.screen.height)
	app.renderer.on('resize', () => camera.resize(app.screen.width, app.screen.height))
	const center = gridToWorldCenter(game.terrain.width / 2, game.terrain.height / 2)
	camera.centerOn(center.x, center.y)

	// Toolbar + painting input
	const ui = document.getElementById('ui')!
	const toolbar = new Toolbar(ui, {
		onThemeChanged: (theme) => {
			game.theme = theme
			terrainRenderer.setTheme(getTerrainColors(theme))
			toolbar.refreshSwatches(theme)
			events.emit('themeChanged', { themeType: theme })
		},
	})
	toolbar.refreshSwatches(game.theme)

	let painting = false
	// Elevation strokes apply once per tile per stroke
	const strokeVisited = new Set<number>()

	function applyTool(screenX: number, screenY: number): void {
		const worldPos = camera.screenToWorld(screenX, screenY)
		const gridPos = worldToGrid(worldPos.x, worldPos.y)
		if (!game.terrain.isValidPosition(gridPos.x, gridPos.y)) return
		const tool = toolbar.tool
		const tiles = game.terrain.getBrushTiles(gridPos.x, gridPos.y, toolbar.brushSize)
		if (tool.kind === 'paint') {
			game.terrain.paintTiles(tiles, tool.terrain)
		} else {
			for (const t of tiles) {
				const key = t.y * game.terrain.width + t.x
				if (strokeVisited.has(key)) continue
				strokeVisited.add(key)
				game.terrain.setElevation(t.x, t.y, game.terrain.getElevation(t.x, t.y) + tool.delta)
			}
		}
		const type = game.terrain.getTile(gridPos.x, gridPos.y)
		const elevation = game.terrain.getElevation(gridPos.x, gridPos.y)
		toolbar.setStatus(
			`(${gridPos.x}, ${gridPos.y}) ${TerrainType[type]} elev ${elevation >= 0 ? '+' : ''}${elevation}`,
		)
	}

	app.canvas.addEventListener('pointerdown', (e) => {
		if (e.button !== 0) return
		painting = true
		strokeVisited.clear()
		applyTool(e.offsetX, e.offsetY)
	})
	app.canvas.addEventListener('pointermove', (e) => {
		if (painting) applyTool(e.offsetX, e.offsetY)
	})
	const endStroke = () => {
		painting = false
		strokeVisited.clear()
	}
	app.canvas.addEventListener('pointerup', endStroke)
	app.canvas.addEventListener('pointerleave', endStroke)

	// Frame loop: sim ticks (fixed timestep) + camera + terrain rebake/cull
	app.ticker.add((ticker) => {
		const dt = ticker.deltaMS / 1000
		loop.advance(dt)
		camera.update(dt)
		terrainRenderer.update(camera.getVisibleWorldRect())
		toolbar.setFps(ticker.FPS)
	})

	// Dev console handle + sanity: JSON data ids must match the TS enum
	for (const [key, data] of Object.entries(gameData.terrainTypes)) {
		const enumValue = TerrainType[key.toUpperCase() as keyof typeof TerrainType]
		if (enumValue !== data.id) {
			console.warn(`terrain_types.json mismatch: ${key} json=${data.id} enum=${enumValue}`)
		}
	}
	console.log(
		`OpenGolf Tycoon web — ${game.terrain.width}x${game.terrain.height} grid, ` +
			`tile ${TILE_W}x${TILE_H}, ${Object.keys(gameData.terrainTypes).length} terrain types loaded`,
	)
	;(window as unknown as Record<string, unknown>).__game = game
}

boot().catch((err) => {
	console.error('boot failed', err)
	document.body.innerHTML = `<pre style="color:#f66;padding:20px;">Boot failed: ${err}</pre>`
})
