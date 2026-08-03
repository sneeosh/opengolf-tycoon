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
import { ShotLabOverlay } from '@render/shot-lab-overlay'
import { worldToGrid, gridToWorldCenter, TILE_W, TILE_H } from '@render/grid-transform'
import { Toolbar } from '@ui/toolbar'
import { ShotLabPanel } from '@ui/shot-lab'
import { calculateShot, type ShotResult } from '@sim/golf/shot'
import { WindSystem } from '@sim/world/wind'
import { vec } from '@sim/core/vec'
import { HoleOverlay } from '@render/hole-overlay'
import { createHole, type HoleData } from '@sim/course/hole'
import { calculateHoleDifficulty } from '@sim/course/difficulty'
import { playHole } from '@sim/golf/hole-player'
import { getScoreName } from '@sim/golf/golf-rules'
import { CLUB_STATS } from '@sim/golf/clubs'

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

	// Shot Lab: fire volleys of engine shots at clicked targets
	const shotLabOverlay = new ShotLabOverlay()
	world.addChild(shotLabOverlay.container)
	const labWind = new WindSystem()
	const shotLab = new ShotLabPanel(ui)
	let labOrigin = { x: 44, y: 64 }
	let labTarget: { x: number; y: number } | null = null

	shotLab.onClear = () => {
		shotLabOverlay.clear()
		shotLab.setStats('')
		labTarget = null
		if (shotLab.active) shotLabOverlay.setMarkers(labOrigin, null)
	}
	shotLab.onSettingsChanged = () => {
		if (labTarget) fireVolley()
	}

	function fireVolley(): void {
		if (!labTarget) return
		labWind.windSpeed = shotLab.windSpeed
		labWind.windDirection = (shotLab.windDirectionDeg * Math.PI) / 180
		const ctx = { terrain: game.terrain, rng: game.rng, wind: labWind }
		const results: ShotResult[] = []
		for (let i = 0; i < shotLab.volleySize; i++) {
			results.push(calculateShot(ctx, shotLab.skills, labOrigin, labTarget, shotLab.club))
		}
		shotLabOverlay.clear()
		shotLabOverlay.setMarkers(labOrigin, labTarget)
		shotLabOverlay.plotVolley(results, game.terrain)

		const n = results.length
		const meanCarry =
			results.reduce((sum, r) => sum + vec.distance(labOrigin, r.carryPrecise), 0) / n
		const meanFinal =
			results.reduce((sum, r) => sum + vec.distance(labOrigin, r.landingPrecise), 0) / n
		const shanks = results.filter((r) => r.isShank).length
		const backspins = results.filter((r) => r.isBackspin).length
		const wet = results.filter((r) => {
			const t = vec.round(r.landingPrecise)
			return game.terrain.getTile(t.x, t.y) === TerrainType.WATER
		}).length
		shotLab.setStats(
			`${n} shots · carry ${(meanCarry * 22).toFixed(0)}yd · total ${(meanFinal * 22).toFixed(0)}yd\n` +
				`accuracy ${results[0].totalAccuracy.toFixed(2)} · shanks ${shanks}` +
				(backspins ? ` · backspin ${backspins}` : '') +
				(wet ? ` · in water ${wet}` : ''),
		)
	}

	// Hole Lab: define a hole (tee → green), then AI plays it with a shot trace
	const holeOverlay = new HoleOverlay()
	world.addChild(holeOverlay.container)
	let currentHole: HoleData | null = null
	let holeDefineStep: 0 | 1 | 2 = 0 // 0 = off, 1 = awaiting tee, 2 = awaiting green
	let pendingTee = { x: 0, y: 0 }

	shotLab.onDefineHole = () => {
		holeDefineStep = 1
		shotLab.setDefiningHole(true)
		shotLab.setStats('Click the TEE position…')
	}
	shotLab.onClearHole = () => {
		currentHole = null
		holeDefineStep = 0
		shotLab.setDefiningHole(false)
		holeOverlay.clear()
		shotLab.setStats('')
	}
	shotLab.onPlayHole = () => {
		if (!currentHole) {
			shotLab.setStats('Define a hole first.')
			return
		}
		labWind.windSpeed = shotLab.windSpeed
		labWind.windDirection = (shotLab.windDirectionDeg * Math.PI) / 180
		const ctx = { terrain: game.terrain, rng: game.rng, wind: labWind, course: null }
		const result = playHole(
			ctx,
			{ ...shotLab.skills, aggression: 0.5, patience: 0.5 },
			currentHole,
		)
		holeOverlay.clearTraces()
		holeOverlay.drawHole(currentHole)
		holeOverlay.drawShotTrace(result.trace)
		const clubs = result.trace
			.filter((t) => !t.isPenalty)
			.map((t) => CLUB_STATS[t.club].name.split(' ')[0])
			.join(', ')
		shotLab.setStats(
			`${result.holed ? getScoreName(result.strokes, result.par) : 'Picked up'}: ` +
				`${result.strokes} strokes (par ${result.par})` +
				(result.penalties ? ` · ${result.penalties} penalty` : '') +
				`\n${clubs}`,
		)
	}

	function defineHoleClick(gridPos: { x: number; y: number }): void {
		if (holeDefineStep === 1) {
			pendingTee = gridPos
			holeDefineStep = 2
			shotLab.setStats('Click the GREEN center…')
		} else if (holeDefineStep === 2) {
			currentHole = createHole(1, pendingTee, gridPos, gridPos, game.terrain)
			currentHole.difficultyRating = calculateHoleDifficulty(currentHole, game.terrain)
			holeDefineStep = 0
			shotLab.setDefiningHole(false)
			holeOverlay.clear()
			holeOverlay.drawHole(currentHole)
			shotLab.setStats(
				`Hole ready: par ${currentHole.par}, ${currentHole.distanceYards}yd, ` +
					`difficulty ${currentHole.difficultyRating.toFixed(1)}. ▶ Play hole!`,
			)
		}
	}

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
		if (shotLab.active) {
			const worldPos = camera.screenToWorld(e.offsetX, e.offsetY)
			const gridPos = worldToGrid(worldPos.x, worldPos.y)
			if (!game.terrain.isValidPosition(gridPos.x, gridPos.y)) return
			if (holeDefineStep > 0) {
				defineHoleClick(gridPos)
				return
			}
			if (e.shiftKey) {
				labOrigin = gridPos
				shotLabOverlay.clear()
				shotLabOverlay.setMarkers(labOrigin, labTarget)
			} else {
				labTarget = gridPos
				fireVolley()
			}
			return
		}
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
