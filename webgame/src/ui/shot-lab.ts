// Shot Lab panel — Phase 2 debug UI for the headless shot engine.
// Pick a club, skill preset, and wind; click the map to fire a volley of
// shots and see the landing scatter. Shift+click moves the tee.

import { Club, CLUB_STATS, GolferSkills } from '@sim/golf/clubs'
import { ThemeColors } from '@sim/course/theme'

export interface SkillPreset {
	name: string
	skills: GolferSkills
}

// Lab presets approximating the four golfer tiers (the real GolferTier
// generator arrives with Phase 4).
export const SKILL_PRESETS: SkillPreset[] = [
	{
		name: 'Beginner',
		skills: {
			drivingSkill: 0.32,
			accuracySkill: 0.32,
			puttingSkill: 0.35,
			recoverySkill: 0.3,
			missTendency: 0.6,
		},
	},
	{
		name: 'Casual',
		skills: {
			drivingSkill: 0.55,
			accuracySkill: 0.55,
			puttingSkill: 0.55,
			recoverySkill: 0.5,
			missTendency: 0.35,
		},
	},
	{
		name: 'Serious',
		skills: {
			drivingSkill: 0.75,
			accuracySkill: 0.75,
			puttingSkill: 0.75,
			recoverySkill: 0.72,
			missTendency: -0.18,
		},
	},
	{
		name: 'Pro',
		skills: {
			drivingSkill: 0.94,
			accuracySkill: 0.93,
			puttingSkill: 0.94,
			recoverySkill: 0.92,
			missTendency: 0.08,
		},
	},
]

const PANEL_STYLE = `
	position: absolute; right: 12px; top: 12px; pointer-events: auto;
	background: rgba(16, 20, 15, 0.92); color: #e8e8e0;
	border: 1px solid #3a4a35; border-radius: 8px; padding: 10px 12px;
	font-size: 12px; width: 230px; user-select: none;
`

export class ShotLabPanel {
	active = false
	club: Club = Club.DRIVER
	presetIndex = 3 // Pro
	missTendency = 0.08
	windSpeed = 10
	windDirectionDeg = 90
	volleySize = 100

	onSettingsChanged: (() => void) | null = null
	onClear: (() => void) | null = null
	onDefineHole: (() => void) | null = null
	onPlayHole: (() => void) | null = null
	onClearHole: (() => void) | null = null

	private root: HTMLDivElement
	private toggleButton: HTMLButtonElement
	private body: HTMLDivElement
	private statsLabel: HTMLDivElement
	private tendencySlider!: HTMLInputElement
	private tendencyReadout!: HTMLSpanElement
	private defineHoleButton!: HTMLButtonElement

	get skills(): GolferSkills {
		return { ...SKILL_PRESETS[this.presetIndex].skills, missTendency: this.missTendency }
	}

	constructor(parent: HTMLElement) {
		this.root = document.createElement('div')
		this.root.style.cssText = PANEL_STYLE

		const header = document.createElement('div')
		header.style.cssText = 'display: flex; justify-content: space-between; align-items: center;'
		const title = document.createElement('span')
		title.textContent = '🏌 Shot Lab'
		title.style.cssText = 'font-weight: 600; font-size: 13px;'
		this.toggleButton = this.button('Enable', () => this.setActive(!this.active))
		header.append(title, this.toggleButton)
		this.root.appendChild(header)

		this.body = document.createElement('div')
		this.body.style.cssText = 'display: none; margin-top: 8px;'
		this.root.appendChild(this.body)

		// Club selector
		this.body.appendChild(this.label('Club'))
		const clubRow = document.createElement('div')
		clubRow.style.cssText = 'display: flex; gap: 4px; flex-wrap: wrap; margin-bottom: 6px;'
		const clubButtons = new Map<Club, HTMLButtonElement>()
		for (const club of [Club.DRIVER, Club.FAIRWAY_WOOD, Club.IRON, Club.WEDGE]) {
			const b = this.button(CLUB_STATS[club].name.replace('Fairway Wood', 'FW'), () => {
				this.club = club
				highlight(clubButtons, club)
				this.onSettingsChanged?.()
			})
			clubButtons.set(club, b)
			clubRow.appendChild(b)
		}
		highlight(clubButtons, this.club)
		this.body.appendChild(clubRow)

		// Skill preset
		this.body.appendChild(this.label('Golfer'))
		const presetRow = document.createElement('div')
		presetRow.style.cssText = 'display: flex; gap: 4px; flex-wrap: wrap; margin-bottom: 6px;'
		const presetButtons = new Map<number, HTMLButtonElement>()
		SKILL_PRESETS.forEach((preset, i) => {
			const b = this.button(preset.name, () => {
				this.presetIndex = i
				this.missTendency = preset.skills.missTendency
				this.tendencySlider.value = String(this.missTendency)
				this.tendencyReadout.textContent = this.missTendency.toFixed(2)
				highlight(presetButtons, i)
				this.onSettingsChanged?.()
			})
			presetButtons.set(i, b)
			presetRow.appendChild(b)
		})
		highlight(presetButtons, this.presetIndex)
		this.body.appendChild(presetRow)

		// Miss tendency slider
		const tendencyRow = document.createElement('div')
		tendencyRow.style.cssText = 'display: flex; gap: 6px; align-items: center; margin-bottom: 6px;'
		tendencyRow.appendChild(this.label('Hook/Slice', false))
		this.tendencySlider = this.slider(-1, 1, 0.01, this.missTendency, (v) => {
			this.missTendency = v
			this.tendencyReadout.textContent = v.toFixed(2)
			this.onSettingsChanged?.()
		})
		this.tendencyReadout = document.createElement('span')
		this.tendencyReadout.textContent = this.missTendency.toFixed(2)
		tendencyRow.append(this.tendencySlider, this.tendencyReadout)
		this.body.appendChild(tendencyRow)

		// Wind controls
		const windRow = document.createElement('div')
		windRow.style.cssText = 'display: flex; gap: 6px; align-items: center; margin-bottom: 2px;'
		windRow.appendChild(this.label('Wind mph', false))
		const windReadout = document.createElement('span')
		windReadout.textContent = String(this.windSpeed)
		windRow.append(
			this.slider(0, 30, 1, this.windSpeed, (v) => {
				this.windSpeed = v
				windReadout.textContent = String(v)
				this.onSettingsChanged?.()
			}),
			windReadout,
		)
		this.body.appendChild(windRow)

		const windDirRow = document.createElement('div')
		windDirRow.style.cssText = 'display: flex; gap: 6px; align-items: center; margin-bottom: 6px;'
		windDirRow.appendChild(this.label('Wind dir°', false))
		const dirReadout = document.createElement('span')
		dirReadout.textContent = String(this.windDirectionDeg)
		windDirRow.append(
			this.slider(0, 359, 1, this.windDirectionDeg, (v) => {
				this.windDirectionDeg = v
				dirReadout.textContent = String(v)
				this.onSettingsChanged?.()
			}),
			dirReadout,
		)
		this.body.appendChild(windDirRow)

		// Volley size + clear
		const volleyRow = document.createElement('div')
		volleyRow.style.cssText = 'display: flex; gap: 4px; align-items: center; margin-bottom: 6px;'
		volleyRow.appendChild(this.label('Shots', false))
		for (const n of [1, 20, 100, 500]) {
			const b = this.button(String(n), () => {
				this.volleySize = n
				volleyRow.querySelectorAll('button').forEach((x) => {
					x.style.borderColor = x.textContent === String(n) ? '#8fd14f' : '#3a4a35'
				})
			})
			if (n === this.volleySize) b.style.borderColor = '#8fd14f'
			volleyRow.appendChild(b)
		}
		volleyRow.appendChild(this.button('Clear', () => this.onClear?.()))
		this.body.appendChild(volleyRow)

		// Hole simulation section
		this.body.appendChild(this.label('Hole simulation'))
		const holeRow = document.createElement('div')
		holeRow.style.cssText = 'display: flex; gap: 4px; flex-wrap: wrap; margin-bottom: 6px;'
		this.defineHoleButton = this.button('Define hole', () => this.onDefineHole?.())
		holeRow.appendChild(this.defineHoleButton)
		holeRow.appendChild(this.button('▶ Play hole', () => this.onPlayHole?.()))
		holeRow.appendChild(this.button('Clear hole', () => this.onClearHole?.()))
		this.body.appendChild(holeRow)

		this.statsLabel = document.createElement('div')
		this.statsLabel.style.cssText = 'opacity: 0.8; line-height: 1.5; white-space: pre-line;'
		this.body.appendChild(this.statsLabel)

		const help = document.createElement('div')
		help.style.cssText = 'margin-top: 6px; opacity: 0.5; line-height: 1.5;'
		help.textContent = 'Click: fire volley at point · Shift+click: move tee'
		this.body.appendChild(help)

		parent.appendChild(this.root)
	}

	setActive(active: boolean): void {
		this.active = active
		this.toggleButton.textContent = active ? 'Disable' : 'Enable'
		this.toggleButton.style.borderColor = active ? '#8fd14f' : '#3a4a35'
		this.body.style.display = active ? 'block' : 'none'
		if (!active) this.onClear?.()
	}

	setStats(text: string): void {
		this.statsLabel.textContent = text
	}

	setDefiningHole(active: boolean): void {
		this.defineHoleButton.style.borderColor = active ? '#8fd14f' : '#3a4a35'
		this.defineHoleButton.style.background = active ? '#33421f' : '#222b1f'
	}

	private label(text: string, block = true): HTMLSpanElement {
		const el = document.createElement('span')
		el.textContent = text
		el.style.cssText = block
			? 'display: block; opacity: 0.7; margin-bottom: 3px;'
			: 'opacity: 0.7; width: 64px; flex-shrink: 0;'
		return el
	}

	private button(text: string, onClick: () => void): HTMLButtonElement {
		const b = document.createElement('button')
		b.textContent = text
		b.style.cssText = `
			background: #222b1f; color: #e8e8e0; border: 1px solid #3a4a35;
			border-radius: 4px; padding: 3px 7px; cursor: pointer; font-size: 11px;
		`
		b.addEventListener('click', onClick)
		return b
	}

	private slider(
		min: number,
		max: number,
		step: number,
		value: number,
		onInput: (v: number) => void,
	): HTMLInputElement {
		const s = document.createElement('input')
		s.type = 'range'
		s.min = String(min)
		s.max = String(max)
		s.step = String(step)
		s.value = String(value)
		s.style.cssText = 'flex: 1;'
		s.addEventListener('input', () => onInput(Number(s.value)))
		return s
	}

	/** Recolor accent when theme changes (kept minimal for now). */
	refreshTheme(_colors: ThemeColors): void {}
}

function highlight<K>(buttons: Map<K, HTMLButtonElement>, active: K): void {
	for (const [key, b] of buttons) {
		b.style.borderColor = key === active ? '#8fd14f' : '#3a4a35'
		b.style.background = key === active ? '#33421f' : '#222b1f'
	}
}
