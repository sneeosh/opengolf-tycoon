// Course themes — port of scripts/systems/course_theme.gd (names, descriptions,
// and per-theme terrain color palettes). Colors are [r, g, b] floats 0–1,
// matching the Godot Color values exactly.

export enum ThemeType {
	PARKLAND = 0,
	DESERT = 1,
	LINKS = 2,
	MOUNTAIN = 3,
	CITY = 4,
	RESORT = 5,
	HEATHLAND = 6,
	WOODLAND = 7,
	TROPICAL = 8,
	MARSHLAND = 9,
}

export type Rgb = readonly [number, number, number]

export type TerrainColorKey =
	| 'grass'
	| 'fairway_light'
	| 'fairway_dark'
	| 'green_light'
	| 'green_dark'
	| 'fringe'
	| 'rough'
	| 'heavy_rough'
	| 'bunker'
	| 'water'
	| 'empty'
	| 'tee_box_light'
	| 'tee_box_dark'
	| 'path'
	| 'oob'
	| 'trees'
	| 'flower_bed'
	| 'rocks'

export type ThemeColors = Record<TerrainColorKey, Rgb>

export const THEME_NAMES: Record<ThemeType, string> = {
	[ThemeType.PARKLAND]: 'Parkland',
	[ThemeType.DESERT]: 'Desert',
	[ThemeType.LINKS]: 'Links',
	[ThemeType.MOUNTAIN]: 'Mountain',
	[ThemeType.CITY]: 'City/Municipal',
	[ThemeType.RESORT]: 'Resort',
	[ThemeType.HEATHLAND]: 'Heathland',
	[ThemeType.WOODLAND]: 'Woodland',
	[ThemeType.TROPICAL]: 'Tropical',
	[ThemeType.MARSHLAND]: 'Marshland',
}

export const ALL_THEMES: ThemeType[] = Object.keys(THEME_NAMES).map(Number)

const PALETTES: Record<ThemeType, ThemeColors> = {
	[ThemeType.PARKLAND]: {
		grass: [0.42, 0.58, 0.32],
		fairway_light: [0.42, 0.78, 0.42],
		fairway_dark: [0.36, 0.72, 0.36],
		green_light: [0.38, 0.88, 0.48],
		green_dark: [0.34, 0.82, 0.44],
		fringe: [0.4, 0.8, 0.44],
		rough: [0.36, 0.52, 0.3],
		heavy_rough: [0.3, 0.45, 0.26],
		bunker: [0.92, 0.85, 0.62],
		water: [0.25, 0.55, 0.85],
		empty: [0.18, 0.22, 0.18],
		tee_box_light: [0.48, 0.76, 0.45],
		tee_box_dark: [0.42, 0.7, 0.4],
		path: [0.75, 0.72, 0.65],
		oob: [0.4, 0.33, 0.3],
		trees: [0.2, 0.42, 0.2],
		flower_bed: [0.45, 0.32, 0.22],
		rocks: [0.48, 0.46, 0.42],
	},
	[ThemeType.DESERT]: {
		grass: [0.72, 0.62, 0.45],
		fairway_light: [0.45, 0.68, 0.38],
		fairway_dark: [0.4, 0.62, 0.34],
		green_light: [0.4, 0.82, 0.42],
		green_dark: [0.36, 0.76, 0.38],
		fringe: [0.42, 0.72, 0.38],
		rough: [0.65, 0.55, 0.38],
		heavy_rough: [0.6, 0.48, 0.32],
		bunker: [0.88, 0.78, 0.52],
		water: [0.3, 0.55, 0.7],
		empty: [0.62, 0.52, 0.38],
		tee_box_light: [0.48, 0.72, 0.42],
		tee_box_dark: [0.42, 0.66, 0.38],
		path: [0.78, 0.7, 0.55],
		oob: [0.55, 0.45, 0.32],
		trees: [0.35, 0.45, 0.28],
		flower_bed: [0.7, 0.5, 0.3],
		rocks: [0.65, 0.55, 0.42],
	},
	[ThemeType.LINKS]: {
		grass: [0.55, 0.58, 0.38],
		fairway_light: [0.48, 0.68, 0.4],
		fairway_dark: [0.42, 0.62, 0.36],
		green_light: [0.42, 0.78, 0.45],
		green_dark: [0.38, 0.72, 0.4],
		fringe: [0.44, 0.7, 0.4],
		rough: [0.52, 0.5, 0.32],
		heavy_rough: [0.48, 0.42, 0.28],
		bunker: [0.88, 0.82, 0.6],
		water: [0.35, 0.52, 0.62],
		empty: [0.45, 0.42, 0.32],
		tee_box_light: [0.48, 0.7, 0.42],
		tee_box_dark: [0.42, 0.64, 0.38],
		path: [0.68, 0.65, 0.55],
		oob: [0.45, 0.4, 0.3],
		trees: [0.3, 0.38, 0.25],
		flower_bed: [0.5, 0.42, 0.3],
		rocks: [0.55, 0.52, 0.48],
	},
	[ThemeType.MOUNTAIN]: {
		grass: [0.32, 0.52, 0.28],
		fairway_light: [0.38, 0.72, 0.38],
		fairway_dark: [0.32, 0.66, 0.32],
		green_light: [0.36, 0.82, 0.42],
		green_dark: [0.32, 0.76, 0.38],
		fringe: [0.35, 0.74, 0.38],
		rough: [0.28, 0.46, 0.24],
		heavy_rough: [0.24, 0.38, 0.2],
		bunker: [0.78, 0.72, 0.55],
		water: [0.22, 0.5, 0.75],
		empty: [0.42, 0.4, 0.38],
		tee_box_light: [0.42, 0.72, 0.42],
		tee_box_dark: [0.36, 0.66, 0.36],
		path: [0.62, 0.58, 0.5],
		oob: [0.38, 0.35, 0.3],
		trees: [0.15, 0.35, 0.18],
		flower_bed: [0.42, 0.3, 0.22],
		rocks: [0.52, 0.5, 0.48],
	},
	[ThemeType.CITY]: {
		grass: [0.42, 0.52, 0.32],
		fairway_light: [0.42, 0.7, 0.4],
		fairway_dark: [0.38, 0.64, 0.36],
		green_light: [0.4, 0.8, 0.44],
		green_dark: [0.36, 0.74, 0.4],
		fringe: [0.4, 0.72, 0.42],
		rough: [0.38, 0.48, 0.3],
		heavy_rough: [0.32, 0.4, 0.26],
		bunker: [0.85, 0.8, 0.62],
		water: [0.3, 0.48, 0.65],
		empty: [0.35, 0.35, 0.33],
		tee_box_light: [0.45, 0.7, 0.42],
		tee_box_dark: [0.4, 0.64, 0.38],
		path: [0.68, 0.68, 0.65],
		oob: [0.45, 0.42, 0.4],
		trees: [0.25, 0.38, 0.22],
		flower_bed: [0.48, 0.35, 0.28],
		rocks: [0.5, 0.5, 0.48],
	},
	[ThemeType.RESORT]: {
		grass: [0.38, 0.62, 0.35],
		fairway_light: [0.4, 0.82, 0.45],
		fairway_dark: [0.35, 0.76, 0.4],
		green_light: [0.38, 0.9, 0.5],
		green_dark: [0.34, 0.84, 0.46],
		fringe: [0.38, 0.82, 0.46],
		rough: [0.34, 0.55, 0.32],
		heavy_rough: [0.28, 0.48, 0.26],
		bunker: [0.95, 0.92, 0.78],
		water: [0.2, 0.62, 0.82],
		empty: [0.22, 0.28, 0.22],
		tee_box_light: [0.48, 0.8, 0.48],
		tee_box_dark: [0.42, 0.74, 0.42],
		path: [0.8, 0.78, 0.72],
		oob: [0.42, 0.36, 0.3],
		trees: [0.18, 0.45, 0.22],
		flower_bed: [0.55, 0.3, 0.35],
		rocks: [0.55, 0.52, 0.45],
	},
	[ThemeType.HEATHLAND]: {
		grass: [0.5, 0.52, 0.35],
		fairway_light: [0.45, 0.68, 0.38],
		fairway_dark: [0.4, 0.62, 0.34],
		green_light: [0.4, 0.8, 0.44],
		green_dark: [0.36, 0.74, 0.4],
		fringe: [0.42, 0.72, 0.4],
		rough: [0.48, 0.38, 0.42],
		heavy_rough: [0.42, 0.3, 0.38],
		bunker: [0.88, 0.82, 0.58],
		water: [0.28, 0.52, 0.72],
		empty: [0.52, 0.48, 0.36],
		tee_box_light: [0.48, 0.7, 0.42],
		tee_box_dark: [0.42, 0.64, 0.38],
		path: [0.65, 0.6, 0.48],
		oob: [0.45, 0.38, 0.32],
		trees: [0.22, 0.38, 0.22],
		flower_bed: [0.55, 0.35, 0.48],
		rocks: [0.52, 0.5, 0.45],
	},
	[ThemeType.WOODLAND]: {
		grass: [0.28, 0.42, 0.25],
		fairway_light: [0.35, 0.65, 0.35],
		fairway_dark: [0.3, 0.58, 0.3],
		green_light: [0.34, 0.8, 0.42],
		green_dark: [0.3, 0.74, 0.38],
		fringe: [0.32, 0.72, 0.38],
		rough: [0.32, 0.4, 0.25],
		heavy_rough: [0.26, 0.32, 0.2],
		bunker: [0.82, 0.76, 0.55],
		water: [0.22, 0.45, 0.62],
		empty: [0.3, 0.28, 0.22],
		tee_box_light: [0.38, 0.68, 0.38],
		tee_box_dark: [0.32, 0.62, 0.32],
		path: [0.55, 0.48, 0.35],
		oob: [0.22, 0.24, 0.18],
		trees: [0.12, 0.3, 0.14],
		flower_bed: [0.38, 0.28, 0.18],
		rocks: [0.42, 0.4, 0.38],
	},
	[ThemeType.TROPICAL]: {
		grass: [0.35, 0.58, 0.32],
		fairway_light: [0.38, 0.78, 0.42],
		fairway_dark: [0.33, 0.72, 0.38],
		green_light: [0.36, 0.88, 0.48],
		green_dark: [0.32, 0.82, 0.44],
		fringe: [0.36, 0.8, 0.44],
		rough: [0.28, 0.48, 0.28],
		heavy_rough: [0.22, 0.4, 0.22],
		bunker: [0.92, 0.88, 0.8],
		water: [0.15, 0.58, 0.82],
		empty: [0.25, 0.22, 0.2],
		tee_box_light: [0.42, 0.76, 0.45],
		tee_box_dark: [0.36, 0.7, 0.4],
		path: [0.72, 0.68, 0.58],
		oob: [0.2, 0.18, 0.16],
		trees: [0.15, 0.42, 0.2],
		flower_bed: [0.65, 0.32, 0.28],
		rocks: [0.3, 0.28, 0.26],
	},
	[ThemeType.MARSHLAND]: {
		grass: [0.45, 0.52, 0.35],
		fairway_light: [0.42, 0.72, 0.4],
		fairway_dark: [0.38, 0.66, 0.36],
		green_light: [0.4, 0.82, 0.45],
		green_dark: [0.36, 0.76, 0.42],
		fringe: [0.4, 0.74, 0.42],
		rough: [0.42, 0.48, 0.32],
		heavy_rough: [0.38, 0.42, 0.28],
		bunker: [0.82, 0.78, 0.62],
		water: [0.32, 0.45, 0.48],
		empty: [0.38, 0.36, 0.3],
		tee_box_light: [0.45, 0.72, 0.42],
		tee_box_dark: [0.4, 0.66, 0.38],
		path: [0.62, 0.58, 0.48],
		oob: [0.35, 0.32, 0.28],
		trees: [0.28, 0.4, 0.25],
		flower_bed: [0.52, 0.45, 0.3],
		rocks: [0.45, 0.42, 0.38],
	},
}

export function getTerrainColors(theme: ThemeType): ThemeColors {
	return PALETTES[theme] ?? PALETTES[ThemeType.PARKLAND]
}

/** Godot saves themes as lowercase strings (CourseTheme.from_string). */
export function themeFromString(name: string): ThemeType {
	const entry = Object.entries(THEME_NAMES).find(
		([, n]) => n.toLowerCase().split('/')[0] === name.toLowerCase(),
	)
	return entry ? Number(entry[0]) : ThemeType.PARKLAND
}
