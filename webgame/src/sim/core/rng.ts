// Seeded RNG for the deterministic sim. All sim randomness must flow through
// an injected Rng instance — never Math.random() — so headless runs and tests
// are reproducible.

export class Rng {
	private state: number

	constructor(seed: number) {
		this.state = seed >>> 0
	}

	/** mulberry32 — uniform float in [0, 1). */
	randf(): number {
		this.state = (this.state + 0x6d2b79f5) >>> 0
		let t = this.state
		t = Math.imul(t ^ (t >>> 15), t | 1)
		t ^= t + Math.imul(t ^ (t >>> 7), t | 61)
		return ((t ^ (t >>> 14)) >>> 0) / 4294967296
	}

	/** Uniform float in [min, max). */
	randfRange(min: number, max: number): number {
		return min + this.randf() * (max - min)
	}

	/** Uniform integer in [min, max] inclusive. */
	randiRange(min: number, max: number): number {
		return min + Math.floor(this.randf() * (max - min + 1))
	}

	/**
	 * Gaussian sample, mean ~0, std dev ~1, range ~±3.46.
	 * Exact clone of Godot's `_gaussian_random()` (golfer.gd:1717) — a Central
	 * Limit Theorem approximation from 4 uniform samples — so the web sim's
	 * shot dispersion distribution matches the Godot game's shape.
	 */
	gaussian(): number {
		return (this.randf() + this.randf() + this.randf() + this.randf() - 2.0) / 0.5774
	}
}
