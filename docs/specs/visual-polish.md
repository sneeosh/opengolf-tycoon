# Visual Polish — Sprites, Buildings, Decorations & Terrain — Product Spec

**Author:** Claude (Product)
**Date:** 2026-02-27
**Status:** Proposal
**Priority:** MEDIUM
**Version:** 0.1.0-alpha context

---

## Problem Statement

Everything in the game is rendered as procedural polygons. Golfers are ~14-polygon stick figures, buildings are hand-drawn polygon assemblies, trees are ellipses with trunk lines, and terrain is a runtime-generated tileset. The visual quality is functional and stylistically consistent (isometric, theme-colored, shadowed), but it reads as programmer art rather than polished indie art.

For a public release — especially screenshots on a store page or landing page — the visuals need to look intentional and appealing. The question is not "should we improve visuals?" but "what approach gives the best visual quality per development effort?"

---

## Design Principles

- **Art direction before assets.** Decide what the game should look like before creating any new art.
- **Procedural is a feature, not a limitation.** The zero-external-assets philosophy enables tiny downloads and runtime theme adaptation. Only abandon it where the quality ceiling is too low.
- **Focal elements first.** Golfers are the most watched element. Improve them first, then buildings, decorations, and terrain last (terrain is already the strongest visual element).
- **Performance budget is real.** Web build must maintain 30+ FPS with 8 golfers, full overlays, on a 128×128 grid. Every visual improvement must fit within this budget.

---

## Art Direction Decision

### Recommendation: Improved Procedural (with Hybrid Fallback for Golfers)

**Rationale:**

| Approach | Quality Ceiling | Dev Cost | Download Size | Theme Adaptability |
|----------|----------------|----------|---------------|-------------------|
| Pure sprite-based | High | Very High (create all assets ×10 themes) | Large (5–20 MB) | Requires 10 palette-swapped sets |
| Improved procedural | Medium-High | Medium | Zero (runtime gen) | Perfect (theme colors drive rendering) |
| Hybrid | High | Medium-High | Small (1–3 MB) | Good (sprites for golfers, procedural terrain) |

The existing procedural system is well-architected — each entity (tree, rock, building) has a `_draw()` method that renders themed, shadowed, variation-aware polygons. The visual ceiling is limited primarily by polygon count and shading complexity, not by the approach itself.

**Decision:** Improve the procedural rendering first. If golfer quality cannot reach an acceptable bar with polygons alone, consider sprite-based golfer rendering as a targeted hybrid.

---

## Current Visual Quality Assessment

### Golfers (Lowest Quality — Priority 1)
**Current:** 11–14 Polygon2D nodes forming a stick figure. 2-frame walk animation (legs swap). Tier-based shirt colors. Randomized hair/cap.

**Issues:**
- Proportions are non-human (head too large relative to body, no neck)
- Walk cycle is a 2-frame toggle — no smooth motion
- Arms are rigid during walk (only sway via rotation)
- No visible golf club during walking (only during swing)
- Shoe polygons clip through legs during stride frame
- Face is blank (no features)

**Quality target:** Recognizable human silhouettes with smooth walk animation, distinct posture per tier, and visible clubs. The golfer should read as "a person playing golf" at a glance, not "a colored stick figure."

### Buildings (Medium Quality — Priority 2)
**Current:** Detailed procedural buildings. Clubhouse has siding, windows, roof trim, chimney, awning, flower boxes. Pro Shop has a display window. Restaurant has signage.

**Issues:**
- Building upgrades are visually similar (level 1 vs level 3 clubhouse differs by chimney and flower boxes)
- No activity indicators (no smoke from restaurant, no golfers visible inside pro shop)
- No lighting effects (no warm window glow at dusk)
- Signage is basic text rendering

**Quality target:** More distinct upgrade tiers, environmental activity hints, and subtle lighting for dusk/night scenes.

### Trees & Decorations (Medium-High Quality — Priority 3)
**Current:** 11 tree varieties with theme-aware coloring, bark texture, crown highlights, variation. 3 rock sizes with faceted shading and moss. Already good.

**Issues:**
- No seasonal variation (no fall foliage, no bare winter branches)
- Flower beds are terrain tiles only (no 3D flower rendering)
- Limited crown shape variation within species (all oaks are circles)

**Quality target:** Optional seasonal variation, richer crown shapes, and 3D flower rendering for flower bed tiles.

### Terrain (Highest Quality — Priority 4)
**Current:** Procedural tileset with Perlin noise, mowing stripes, autotile edge blending, animated water shimmer. Already the strongest visual element.

**Issues:**
- Fairway mowing patterns are uniform (no stripe direction variation)
- Bunker lips aren't visually distinct from sand center
- Rough grass lacks individual tuft detail
- Path tiles are flat (no wear pattern or texture depth)

**Quality target:** Subtle texture improvements. Terrain is already good enough — this is polish, not a priority.

---

## Phased Visual Improvements

### Phase 1: Golfer Visual Upgrade (Highest Impact)

**1.1 Improved body proportions:**
```
Current:                    Target:
  O      (circle head)        O      (slightly smaller head)
 /|\     (triangle body)     /|\     (slightly taller body)
 / \     (V-legs)           | |     (straight legs when standing)
                            / \     (legs during stride)
```

Specific adjustments:
- Head radius: reduce from current to 80% (more proportional)
- Body height: increase by 20%
- Add neck: 2px connection between head and body
- Leg separation: increase slightly for clearer stride

**1.2 4-frame walk cycle:**
Replace 2-frame toggle with 4 distinct frames:
```
Frame 0: Standing (both legs together)
Frame 1: Right leg forward, left back
Frame 2: Standing (both legs together, slight bend)
Frame 3: Left leg forward, right back
```
Duration: 0.2s per frame (0.8s full cycle). This produces smooth walking motion visible even at small scales.

**1.3 Arm swing during walk:**
Currently `sin() * 0.15 radians` rotation. Improve to:
- Left arm swings opposite to right leg (natural human walk)
- Swing amplitude: 0.2 radians (more visible)
- Golf club held in right hand visible during walk (small polygon extending from hand)

**1.4 Swing animation improvement:**
Current swing is a simple rotation. Improve to:
- 3-frame swing: backswing (0.2s), downswing (0.1s), follow-through (0.3s)
- Club visible throughout swing arc
- Body rotation during swing (slight twist at waist)
- Head follows ball after impact (turn toward target)

**1.5 Tier-based posture:**
- BEGINNER: Slightly hunched posture (body lean 3°), casual stance
- CASUAL: Normal upright posture
- SERIOUS: Confident posture, shoulders slightly back
- PRO: Athletic posture, wider stance, focused head angle

**1.6 Face features (minimal):**
At current scale, face detail is nearly invisible. Add:
- Two dots for eyes (2px each, visible at 1.0× zoom and above)
- Cap/visor shadow line (already partially implemented)
- No mouth, nose, or other detail (too small to render clearly)

---

### Phase 2: Building Visual Upgrade

**2.1 Upgrade tier differentiation:**
Make building upgrade levels visually distinct:

| Building | Level 1 | Level 2 | Level 3 |
|----------|---------|---------|---------|
| Clubhouse | Basic structure | + Extended wing, awning | + Second floor, clock tower |
| (Visual cues) | Simple roof, 2 windows | Wider footprint, 4 windows, planters | Taller, dormer windows, flag |

Each level should be immediately recognizable as "bigger/better" without reading the tooltip.

**2.2 Activity indicators:**
- Restaurant: Small smoke wisps from chimney (2-3 animated polygon lines, rising and fading)
- Pro Shop: Display window glow (slight yellow rectangle at window position)
- Snack Bar: Small "OPEN" sign (colored rectangle when operational)
- Driving Range: Occasional small ball arc animation (rare, subtle)

**2.3 Dusk/night lighting:**
When `DayNightSystem` hour is 17:00–20:00:
- Windows emit warm yellow glow (overlay rectangle at window positions, `Color(1.0, 0.9, 0.5, 0.4)`)
- Entrance areas have subtle light pool on ground
- Only applies to buildings within camera viewport (performance)

---

### Phase 3: Decoration Visual Upgrade

**3.1 Seasonal tree variation (if Seasonal System expanded):**
- Spring: Normal coloring + small blossom dots on deciduous trees
- Summer: Full, rich foliage (default/current)
- Fall: Warm palette shift (maple → orange/red, oak → golden brown, birch → yellow)
- Winter: Bare branches for deciduous trees (simplified polygon), evergreens unchanged

Implementation: In `Tree._draw()`, check `SeasonSystem.get_season()` and adjust:
- Canopy color via HSV shift (fall: hue +30°, saturation -20%)
- Winter: skip canopy polygon, draw branch polygons instead
- Spring: canopy + small circle dots (pink/white) at random offsets

**3.2 Richer tree crown shapes:**
Add crown shape variation within species:
- Oak: 3 crown templates (round, wide, tall) — selected by position seed
- Pine: 2 templates (narrow, full) — selected by seed
- Maple: 2 templates (compact, spreading) — selected by seed

Each template is a different `PackedVector2Array` for the canopy polygon.

**3.3 Flower bed enhancement:**
Currently flower beds are flat terrain tiles. Enhance with:
- Small colored dots (3–5 per tile) drawn as circles on the flower bed overlay
- Colors: random from {red, pink, yellow, white, purple} per tile (seeded by position)
- Provides visible "garden" look at all zoom levels

---

### Phase 4: Terrain Visual Enhancement

**4.1 Fairway mowing stripe variation:**
Currently all mowing stripes run the same direction. Add:
- Stripe direction varies by fairway section (every 4–6 tiles, rotate 90°)
- Creates the classic "striped fairway" look seen from above
- Alternate dark/light green within the Perlin noise pattern

**4.2 Bunker lip rendering:**
- Edge tiles of bunker (adjacent to non-bunker) render with a darker sand border (lip edge)
- 2px darker strip along the edge closest to the green (player-facing side)
- Creates visual depth that reads as "sand trap with raised edges"

**4.3 Rough grass tufts:**
- Rough and heavy rough tiles get small grass tuft accents
- 2–3 small triangle shapes per tile (2–3px tall) in slightly different green
- Heavy rough: tufts are taller (4–5px) and denser (4–5 per tile)
- Subtle but adds texture that distinguishes rough from fairway visually

---

## Performance Considerations

### Budget:
- Target: 30+ FPS on web build (mid-range laptop)
- 8 concurrent golfers, each with enhanced rendering
- Full terrain overlays active
- 128×128 grid

### Optimization strategies:
- **Golfer rendering**: Pre-compute walk frame polygons at initialization (don't recalculate every frame)
- **Building effects**: Only render smoke/glow for buildings within camera viewport
- **Seasonal trees**: Cache seasonal color at season change, not per frame
- **Terrain enhancements**: Baked into tileset generation, not drawn per frame

### Web-specific:
- `DayNightSystem` already throttles to 10 FPS on web (0.1s interval)
- Building glow effects: limit to 3 closest buildings to camera center
- Smoke animations: limit to 1 building at a time (cycle between restaurants)

---

## Implementation Sequence

```
Phase 1 (Golfers — Highest Impact):
  1. Improved body proportions (head, neck, body height)
  2. 4-frame walk cycle
  3. Enhanced arm swing with visible golf club
  4. Tier-based posture differences
  5. 3-frame swing animation
  6. Minimal face features (eyes at 1.0× zoom)

Phase 2 (Buildings):
  7. Upgrade tier visual differentiation (clubhouse 3 levels)
  8. Restaurant chimney smoke animation
  9. Window glow at dusk/night

Phase 3 (Decorations):
  10. Seasonal tree variation (spring blossoms, fall foliage, winter bare)
  11. Crown shape variation per species
  12. Flower bed enhancement (colored dots)

Phase 4 (Terrain):
  13. Fairway mowing stripe variation
  14. Bunker lip rendering
  15. Rough grass tufts

Phase 5 (Hybrid Fallback — Only If Needed):
  16. Evaluate: do improved procedural golfers look good enough?
  17. If not: Create 4-directional sprite sheets per tier
  18. Sprite format: 32×32 PNG atlas, 16 frames per action
  19. Integrate sprite rendering alongside procedural (toggle per entity)
```

---

## Art Style Reference

The target visual style is **"clean isometric pixel art with procedural depth"** — similar to:
- **SimGolf (2002)**: The spiritual predecessor. Simple but readable characters.
- **RollerCoaster Tycoon**: Small isometric characters that are instantly readable by color and posture.
- **Two Point Hospital**: Clean, colorful, exaggerated proportions for readability.

Key qualities to emulate:
- Exaggerated proportions for readability at small scales
- High-contrast color palettes (bright colors on dark terrain)
- Clear silhouettes (each entity reads as a distinct shape)
- Consistent isometric projection (no perspective cheating)

---

## Success Criteria

- Golfers are identifiable as "people" at 0.8× zoom (not abstract shapes)
- Walk animation is smooth enough that movement looks natural
- Tier differences are visible through posture and ring color
- Building upgrades are visually distinct without reading tooltips
- Dusk lighting adds atmospheric depth to the course
- Seasonal tree variation is visible and theme-appropriate
- Overall visual quality supports a store page screenshot that looks like an indie game, not a prototype
- 30+ FPS maintained on web build with all enhancements active

---

## Out of Scope

| Feature | Reason |
|---------|--------|
| 3D rendering / perspective shift | Fundamental architecture change |
| Character creator / customization | Not a character game |
| Particle effects system | Performance risk on web; procedural effects are sufficient |
| Dynamic shadows (realtime) | ShadowSystem already handles static shadows adequately |
| Parallax scrolling / depth layers | 2D isometric doesn't use parallax |
| Screen-space effects (bloom, DOF) | WebGL performance cost too high |
| Sprite animation tool / pipeline | Only needed if hybrid approach is chosen |
