// StrokeIndexCalculator — port of scripts/systems/stroke_index_calculator.gd.
// Ranks holes 1-N by difficulty (1 = hardest). For 10+ holes, front nine
// takes odd indices and back nine even, per standard golf convention.

import type { HoleData } from './hole'

/** Returns {holeNumber: strokeIndex}. */
export function calculateStrokeIndices(holes: HoleData[]): Map<number, number> {
	const openHoles = holes.filter((h) => h.isOpen)
	if (openHoles.length === 0) return new Map()

	// Hardest first; ties broken by lower hole number
	const sorted = [...openHoles].sort((a, b) => {
		if (Math.abs(a.difficultyRating - b.difficultyRating) > 0.01) {
			return b.difficultyRating - a.difficultyRating
		}
		return a.holeNumber - b.holeNumber
	})

	const result = new Map<number, number>()

	if (sorted.length <= 9) {
		sorted.forEach((hole, i) => result.set(hole.holeNumber, i + 1))
		return result
	}

	// 10+ holes: interleave front (odd indices) and back (even indices)
	const frontSorted = sorted.filter((h) => h.holeNumber <= 9)
	const backSorted = sorted.filter((h) => h.holeNumber > 9)

	const oddSlots: number[] = []
	const evenSlots: number[] = []
	for (let i = 1; i <= sorted.length; i++) {
		if (i % 2 === 1) oddSlots.push(i)
		else evenSlots.push(i)
	}

	frontSorted.forEach((hole, i) => {
		if (i < oddSlots.length) {
			result.set(hole.holeNumber, oddSlots[i])
		} else {
			const overflowIdx = i - oddSlots.length
			if (overflowIdx + backSorted.length < evenSlots.length) {
				result.set(hole.holeNumber, evenSlots[overflowIdx + backSorted.length])
			}
		}
	})
	backSorted.forEach((hole, i) => {
		if (i < evenSlots.length) {
			result.set(hole.holeNumber, evenSlots[i])
		} else {
			const overflowIdx = i - evenSlots.length
			if (overflowIdx + frontSorted.length < oddSlots.length) {
				result.set(hole.holeNumber, oddSlots[overflowIdx + frontSorted.length])
			}
		}
	})

	return result
}

/** Recalculate and store stroke indices on the holes. */
export function applyStrokeIndices(holes: HoleData[]): void {
	const indices = calculateStrokeIndices(holes)
	for (const hole of holes) {
		hole.strokeIndex = indices.get(hole.holeNumber) ?? 0
	}
}
