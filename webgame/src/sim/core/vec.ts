// Minimal 2D vector helpers over plain {x, y} objects (grid-space math).

export interface Vec2 {
	x: number
	y: number
}

export const vec = {
	add: (a: Vec2, b: Vec2): Vec2 => ({ x: a.x + b.x, y: a.y + b.y }),
	sub: (a: Vec2, b: Vec2): Vec2 => ({ x: a.x - b.x, y: a.y - b.y }),
	scale: (a: Vec2, s: number): Vec2 => ({ x: a.x * s, y: a.y * s }),
	length: (a: Vec2): number => Math.hypot(a.x, a.y),
	distance: (a: Vec2, b: Vec2): number => Math.hypot(b.x - a.x, b.y - a.y),
	dot: (a: Vec2, b: Vec2): number => a.x * b.x + a.y * b.y,
	normalize(a: Vec2): Vec2 {
		const len = Math.hypot(a.x, a.y)
		return len === 0 ? { x: 0, y: 0 } : { x: a.x / len, y: a.y / len }
	},
	/** Rotate by angle in radians (matches Godot Vector2.rotated). */
	rotate(a: Vec2, radians: number): Vec2 {
		const c = Math.cos(radians)
		const s = Math.sin(radians)
		return { x: a.x * c - a.y * s, y: a.x * s + a.y * c }
	},
	/** Perpendicular (-y, x), matching the Godot convention used in shot code. */
	perp: (a: Vec2): Vec2 => ({ x: -a.y, y: a.x }),
	lerp: (a: Vec2, b: Vec2, t: number): Vec2 => ({
		x: a.x + (b.x - a.x) * t,
		y: a.y + (b.y - a.y) * t,
	}),
	round: (a: Vec2): Vec2 => ({ x: Math.round(a.x), y: Math.round(a.y) }),
}

export function lerp(a: number, b: number, t: number): number {
	return a + (b - a) * t
}

export function clamp(v: number, min: number, max: number): number {
	return Math.max(min, Math.min(max, v))
}

export const DEG_TO_RAD = Math.PI / 180
