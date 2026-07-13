// Terrain sandbox toolbar — minimal DOM overlay for Phase 1.
// Terrain paint buttons, elevation raise/lower, brush size, theme picker.

import { TerrainType, getTerrainProperties, ALL_TERRAIN_TYPES } from '@sim/terrain/terrain-types'
import { ThemeType, THEME_NAMES, ALL_THEMES, getTerrainColors } from '@sim/course/theme'

export type Tool =
	| { kind: 'paint'; terrain: TerrainType }
	| { kind: 'elevation'; delta: 1 | -1 }

export interface ToolbarCallbacks {
	onThemeChanged: (theme: ThemeType) => void
}

const PANEL_STYLE = `
	position: absolute; left: 12px; top: 12px; pointer-events: auto;
	background: rgba(16, 20, 15, 0.92); color: #e8e8e0;
	border: 1px solid #3a4a35; border-radius: 8px; padding: 10px 12px;
	font-size: 12px; max-width: 240px; user-select: none;
`

export class Toolbar {
	tool: Tool = { kind: 'paint', terrain: TerrainType.FAIRWAY }
	brushSize = 3
	theme = ThemeType.PARKLAND

	private root: HTMLDivElement
	private buttons = new Map<string, HTMLButtonElement>()
	private fpsLabel: HTMLSpanElement
	private statusLabel: HTMLDivElement

	constructor(parent: HTMLElement, callbacks: ToolbarCallbacks) {
		this.root = document.createElement('div')
		this.root.style.cssText = PANEL_STYLE

		const title = document.createElement('div')
		title.textContent = 'OpenGolf Tycoon — Terrain Sandbox'
		title.style.cssText = 'font-weight: 600; margin-bottom: 8px; font-size: 13px;'
		this.root.appendChild(title)

		// Theme picker
		const themeRow = document.createElement('div')
		themeRow.style.cssText = 'margin-bottom: 8px; display: flex; gap: 6px; align-items: center;'
		const themeLabel = document.createElement('span')
		themeLabel.textContent = 'Theme'
		const themeSelect = document.createElement('select')
		themeSelect.style.cssText =
			'flex: 1; background: #222b1f; color: #e8e8e0; border: 1px solid #3a4a35; border-radius: 4px; padding: 2px;'
		for (const theme of ALL_THEMES) {
			const option = document.createElement('option')
			option.value = String(theme)
			option.textContent = THEME_NAMES[theme as ThemeType]
			themeSelect.appendChild(option)
		}
		themeSelect.addEventListener('change', () => {
			this.theme = Number(themeSelect.value) as ThemeType
			callbacks.onThemeChanged(this.theme)
		})
		themeRow.append(themeLabel, themeSelect)
		this.root.appendChild(themeRow)

		// Terrain paint buttons
		const grid = document.createElement('div')
		grid.style.cssText = 'display: grid; grid-template-columns: 1fr 1fr; gap: 4px;'
		for (const type of ALL_TERRAIN_TYPES) {
			const button = this.makeButton(
				getTerrainProperties(type).name,
				`paint-${type}`,
				() => (this.tool = { kind: 'paint', terrain: type }),
			)
			button.prepend(this.makeSwatch(type))
			grid.appendChild(button)
		}
		this.root.appendChild(grid)

		// Elevation tools
		const elevRow = document.createElement('div')
		elevRow.style.cssText = 'display: flex; gap: 4px; margin-top: 6px;'
		elevRow.appendChild(
			this.makeButton('▲ Raise', 'elev-up', () => (this.tool = { kind: 'elevation', delta: 1 })),
		)
		elevRow.appendChild(
			this.makeButton('▼ Lower', 'elev-down', () => (this.tool = { kind: 'elevation', delta: -1 })),
		)
		this.root.appendChild(elevRow)

		// Brush size
		const brushRow = document.createElement('div')
		brushRow.style.cssText = 'display: flex; gap: 4px; margin-top: 6px; align-items: center;'
		const brushLabel = document.createElement('span')
		brushLabel.textContent = 'Brush'
		brushRow.appendChild(brushLabel)
		for (const size of [1, 3, 5]) {
			brushRow.appendChild(
				this.makeButton(`${size}×${size}`, `brush-${size}`, () => {
					this.brushSize = size
					this.highlightBrush()
				}),
			)
		}
		this.root.appendChild(brushRow)

		// Status + FPS
		this.statusLabel = document.createElement('div')
		this.statusLabel.style.cssText = 'margin-top: 8px; opacity: 0.7;'
		this.root.appendChild(this.statusLabel)
		const fpsRow = document.createElement('div')
		fpsRow.style.cssText = 'margin-top: 2px; opacity: 0.7;'
		this.fpsLabel = document.createElement('span')
		fpsRow.append('FPS: ', this.fpsLabel)
		this.root.appendChild(fpsRow)

		const help = document.createElement('div')
		help.style.cssText = 'margin-top: 6px; opacity: 0.5; line-height: 1.5;'
		help.textContent =
			'Left-drag: apply tool · Middle/right-drag: pan · Wheel or [ ]: zoom · WASD/arrows: pan'
		this.root.appendChild(help)

		parent.appendChild(this.root)
		this.highlightTool()
		this.highlightBrush()
	}

	private makeSwatch(type: TerrainType): HTMLSpanElement {
		const swatch = document.createElement('span')
		swatch.dataset.terrain = String(type)
		swatch.style.cssText =
			'display: inline-block; width: 10px; height: 10px; border-radius: 2px; margin-right: 5px;'
		return swatch
	}

	/** Update paint-button swatches to the active theme's palette. */
	refreshSwatches(theme: ThemeType): void {
		const colors = getTerrainColors(theme)
		const keyByType: Partial<Record<TerrainType, keyof typeof colors>> = {
			[TerrainType.EMPTY]: 'empty',
			[TerrainType.GRASS]: 'grass',
			[TerrainType.FAIRWAY]: 'fairway_light',
			[TerrainType.ROUGH]: 'rough',
			[TerrainType.HEAVY_ROUGH]: 'heavy_rough',
			[TerrainType.GREEN]: 'green_light',
			[TerrainType.TEE_BOX]: 'tee_box_light',
			[TerrainType.BUNKER]: 'bunker',
			[TerrainType.WATER]: 'water',
			[TerrainType.PATH]: 'path',
			[TerrainType.OUT_OF_BOUNDS]: 'oob',
			[TerrainType.TREES]: 'trees',
			[TerrainType.FLOWER_BED]: 'flower_bed',
			[TerrainType.ROCKS]: 'rocks',
		}
		this.root.querySelectorAll<HTMLSpanElement>('span[data-terrain]').forEach((swatch) => {
			const type = Number(swatch.dataset.terrain) as TerrainType
			const rgb = colors[keyByType[type] ?? 'grass']
			swatch.style.background = `rgb(${rgb.map((c) => Math.round(c * 255)).join(',')})`
		})
	}

	private makeButton(label: string, id: string, onClick: () => void): HTMLButtonElement {
		const button = document.createElement('button')
		button.textContent = label
		button.style.cssText = `
			background: #222b1f; color: #e8e8e0; border: 1px solid #3a4a35;
			border-radius: 4px; padding: 3px 6px; cursor: pointer; font-size: 11px;
			display: flex; align-items: center; text-align: left;
		`
		button.addEventListener('click', () => {
			onClick()
			this.highlightTool()
		})
		this.buttons.set(id, button)
		return button
	}

	private highlightTool(): void {
		for (const [id, button] of this.buttons) {
			if (id.startsWith('brush-')) continue
			const active =
				(this.tool.kind === 'paint' && id === `paint-${this.tool.terrain}`) ||
				(this.tool.kind === 'elevation' && id === (this.tool.delta > 0 ? 'elev-up' : 'elev-down'))
			button.style.borderColor = active ? '#8fd14f' : '#3a4a35'
			button.style.background = active ? '#33421f' : '#222b1f'
		}
	}

	private highlightBrush(): void {
		for (const size of [1, 3, 5]) {
			const button = this.buttons.get(`brush-${size}`)!
			button.style.borderColor = size === this.brushSize ? '#8fd14f' : '#3a4a35'
			button.style.background = size === this.brushSize ? '#33421f' : '#222b1f'
		}
	}

	setStatus(text: string): void {
		this.statusLabel.textContent = text
	}

	setFps(fps: number): void {
		this.fpsLabel.textContent = fps.toFixed(0)
	}
}
