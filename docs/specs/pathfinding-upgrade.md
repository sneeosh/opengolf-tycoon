# Pathfinding Upgrade (A* on Terrain Grid) — Product Spec

**Author:** Claude (Product)
**Date:** 2026-02-27
**Status:** Proposal
**Priority:** MEDIUM-LOW
**Version:** 0.1.0-alpha context

---

## Problem Statement

Golfers currently use a heuristic pathfinding approach that works for most layouts but has edge cases. The existing system in `golfer.gd` implements:

1. Direct distance check (<2.5 tiles → go direct)
2. Obstacle detection along the straight-line path
3. A* pathfinding around obstacles (8-directional, max 5000 iterations)
4. Cart path optimization (search ±4 tiles for PATH terrain)
5. Line-of-sight path simplification

This system works well for simple courses but produces issues on complex layouts:
- Golfers sometimes walk through visually impassable areas when the heuristic path simplification removes too many waypoints
- Cart path detection has a limited search radius (±4 tiles) and misses nearby paths
- No terrain-type movement cost awareness (golfers don't prefer paths over rough)
- Building collision uses a different system than terrain pathfinding
- Path caching doesn't exist — paths are recalculated on every walk

As courses grow to 18 holes with multiple buildings, winding paths, and extensive water hazards, pathfinding quality becomes increasingly important for both visual polish and pace-of-play accuracy.

---

## Design Principles

- **Fix edge cases, not the architecture.** The existing A* implementation works. This spec addresses specific weaknesses rather than replacing the system.
- **Movement cost drives realistic walking.** Golfers should visibly prefer paths, avoid rough, and walk around hazards naturally.
- **Performance over perfection.** An approximate path that's fast beats a perfect path that causes frame drops.
- **Cache common routes.** The path from Green #1 to Tee #2 is the same for every golfer every day.

---

## Current System Analysis

### A* Implementation (in `golfer.gd`)
```gdscript
func _find_path_around_obstacles(start_grid, end_grid) -> Array[Vector2]:
    # 8-directional movement
    # Cardinal cost: 1.0, Diagonal cost: sqrt(2)
    # Heuristic: octile distance
    # Max iterations: 5000
    # Blocked: water, OOB, empty tiles
    # No terrain type cost differentiation
```

### Obstacle Detection
```gdscript
func _path_crosses_obstacle(start, end, walking: bool) -> bool:
    # Raycasts along the direct line
    # Checks terrain type at each sampled point
    # walking=true: water, OOB, empty are obstacles
    # walking=false: trees are obstacles for ball flight
```

### Cart Path Optimization
```gdscript
# Searches ±4 tiles perpendicular to direct path for PATH terrain
# If found, routes through nearest cart path
# Speed modifier: PATH = 1.5× walking speed
```

### Known Issues
1. **No movement cost per terrain:** Walking through HEAVY_ROUGH costs the same as FAIRWAY in pathfinding. Golfers take the shortest geometric path, not the fastest terrain path.
2. **Building collision is separate:** Buildings block placement but aren't part of the terrain pathfinding grid. Golfers can clip through building edges.
3. **Path simplification over-simplifies:** Line-of-sight simplification removes intermediate waypoints, sometimes creating paths that visually cross obstacles.
4. **No path caching:** Every golfer recalculates paths from scratch.
5. **Cart path search radius too small:** ±4 tiles misses paths that are 5–6 tiles away.

---

## Feature Design

### 1. Terrain-Type Movement Costs

Add movement cost awareness to the A* pathfinding:

| Terrain Type | Movement Cost | Rationale |
|-------------|---------------|-----------|
| PATH | 0.7 | Fastest walking surface (paved) |
| GRASS | 1.0 | Baseline |
| FAIRWAY | 0.9 | Mowed, smooth surface |
| GREEN | 0.9 | Smooth, but golfers shouldn't cut across greens |
| TEE_BOX | 0.9 | Smooth surface |
| ROUGH | 1.5 | Taller grass, slower walking |
| HEAVY_ROUGH | 2.0 | Very tall grass, significantly slower |
| TREES | 2.5 | Navigating through tree cover |
| FLOWER_BED | 1.8 | Golfers avoid walking through flower beds |
| ROCKS | 3.0 | Very difficult terrain, nearly impassable |
| BUNKER | 2.0 | Soft sand, slow walking |
| WATER | INF | Impassable |
| OUT_OF_BOUNDS | INF | Impassable |
| EMPTY | INF | Impassable |

**Green avoidance:** Add a special penalty (+2.0 cost) for crossing a GREEN tile that is NOT the golfer's current target hole's green. Golfers should not walk across other holes' putting surfaces as a shortcut.

**Implementation change in A*:**
```gdscript
# Replace fixed 1.0 / sqrt(2) costs with:
func _get_move_cost(from: Vector2i, to: Vector2i) -> float:
    var terrain = terrain_grid.get_tile(to)
    var base_cost = TERRAIN_MOVE_COSTS.get(terrain, 1.0)

    # Green avoidance for non-target greens
    if terrain == TerrainTypes.GREEN and not _is_target_green(to):
        base_cost += 2.0

    # Diagonal movement costs more
    if from.x != to.x and from.y != to.y:
        base_cost *= 1.414

    return base_cost
```

**Expected behavior change:** Golfers will visually route along paths and fairways instead of cutting through rough/trees. This makes cart path placement a meaningful design decision.

---

### 2. Building Collision Integration

Add buildings to the pathfinding grid as impassable obstacles:

**Current:** Building collision is handled separately from terrain pathfinding. `PlacementManager` prevents placement overlap, but the pathfinding A* doesn't know about buildings.

**Fix:**
```gdscript
func _is_tile_walkable(pos: Vector2i) -> bool:
    var terrain = terrain_grid.get_tile(pos)
    if terrain in [WATER, OUT_OF_BOUNDS, EMPTY]:
        return false

    # Check building occupancy
    if placement_manager.is_tile_occupied_by_building(pos):
        return false

    return true
```

**Building footprint awareness:** Buildings occupy a rectangular area. Mark all tiles within the building footprint as impassable in the pathfinding grid.

**Cache invalidation:** When a building is placed or removed, invalidate affected path caches (see section 4).

---

### 3. Improved Path Simplification

Replace the aggressive line-of-sight simplification with a safer approach:

**Current problem:** Simplification removes waypoints if there's a clear line of sight between non-adjacent waypoints. But the "clear line" check doesn't account for terrain costs — it might remove a waypoint that kept the golfer on a path rather than through rough.

**Improved simplification:**
```gdscript
func _simplify_path(raw_path: Array[Vector2i]) -> Array[Vector2]:
    if raw_path.size() <= 2:
        return raw_path.map(func(p): return grid_to_screen(p))

    var simplified = [raw_path[0]]
    var i = 0

    while i < raw_path.size() - 1:
        var farthest_clear = i + 1

        # Find farthest point with clear AND low-cost path
        for j in range(i + 2, raw_path.size()):
            if _direct_path_is_clear_and_cheap(raw_path[i], raw_path[j]):
                farthest_clear = j
            else:
                break

        simplified.append(raw_path[farthest_clear])
        i = farthest_clear

    return simplified.map(func(p): return grid_to_screen(p))

func _direct_path_is_clear_and_cheap(from: Vector2i, to: Vector2i) -> bool:
    # Sample terrain along direct line
    var steps = max(abs(to.x - from.x), abs(to.y - from.y))
    for s in range(steps + 1):
        var t = float(s) / max(steps, 1)
        var sample = Vector2i(
            int(lerp(from.x, to.x, t)),
            int(lerp(from.y, to.y, t))
        )
        if not _is_tile_walkable(sample):
            return false
        # Reject simplification if direct path goes through expensive terrain
        if TERRAIN_MOVE_COSTS.get(terrain_grid.get_tile(sample), 1.0) > 2.0:
            return false
    return true
```

This ensures simplified paths don't cross expensive terrain even if they're technically obstacle-free.

---

### 4. Path Caching

Cache frequently-used paths to avoid recalculating for every golfer:

**Cache structure:**
```gdscript
var _path_cache: Dictionary = {}  # "{from_x},{from_y}-{to_x},{to_y}" → Array[Vector2]
var _cache_version: int = 0       # Incremented on terrain/building changes

class PathCacheEntry:
    var path: Array[Vector2]
    var version: int               # Cache version when computed
    var last_used: int             # Frame number of last access
```

**Common cached routes:**
- Green N → Tee (N+1) for all consecutive holes
- Tee → midway point (for each hole's fairway)
- Course exit → entry point (after round completion)
- Clubhouse → nearest tee box (round start)

**Cache invalidation:**
```gdscript
func _invalidate_cache() -> void:
    _cache_version += 1
    # Don't clear the cache — entries validate their version on access

func _get_cached_path(from: Vector2i, to: Vector2i) -> Array[Vector2]:
    var key = "%d,%d-%d,%d" % [from.x, from.y, to.x, to.y]
    var entry = _path_cache.get(key)
    if entry and entry.version == _cache_version:
        entry.last_used = Engine.get_frames_drawn()
        return entry.path
    return []  # Cache miss

func _cache_path(from: Vector2i, to: Vector2i, path: Array[Vector2]) -> void:
    var key = "%d,%d-%d,%d" % [from.x, from.y, to.x, to.y]
    _path_cache[key] = PathCacheEntry.new(path, _cache_version, Engine.get_frames_drawn())

    # Evict old entries if cache exceeds 100 entries
    if _path_cache.size() > 100:
        _evict_least_recently_used()
```

**Invalidation triggers:**
- `EventBus.terrain_tile_changed` — invalidate all cached paths
- `EventBus.building_placed` / `building_removed` — invalidate all cached paths
- `EventBus.hole_created` / `hole_deleted` — invalidate all cached paths

**Performance note:** Full cache invalidation on any terrain change is simple and safe. Since terrain changes are infrequent (player design actions, not per-frame), this is acceptable. More granular invalidation (only invalidate paths crossing the changed area) is an optimization for later if needed.

---

### 5. Expanded Cart Path Search

Increase the cart path search radius and improve the routing logic:

**Current:** ±4 tiles perpendicular search.
**Proposed:** ±8 tiles perpendicular search + A*-based path-to-path routing.

```gdscript
func _find_nearest_path_tile(position: Vector2i, search_radius: int = 8) -> Vector2i:
    # BFS from position, looking for PATH terrain within radius
    var best = Vector2i(-1, -1)
    var best_dist = INF

    for dx in range(-search_radius, search_radius + 1):
        for dy in range(-search_radius, search_radius + 1):
            var check = position + Vector2i(dx, dy)
            if terrain_grid.get_tile(check) == TerrainTypes.PATH:
                var dist = position.distance_to(check)
                if dist < best_dist:
                    best_dist = dist
                    best = check

    return best
```

**Cart path routing decision:**
Only route via cart path if it's genuinely faster:
```gdscript
var direct_cost = _estimate_path_cost(from, to)
var via_path_cost = _estimate_path_cost(from, nearest_path) +
                    _estimate_path_on_path(nearest_path, exit_path) * 0.7 +
                    _estimate_path_cost(exit_path, to)

if via_path_cost < direct_cost * 0.85:  # 15% faster threshold
    use_cart_path()
```

---

### 6. Hole-to-Hole Routing Integration

When Course Design Upgrades Spec 1.1 (Routing) is implemented, pathfinding provides the core routing calculation:

**Pre-calculated routes:**
- On hole creation/modification, calculate and cache the optimal walking path from each green to the next tee
- Display path cost as "walking distance" in the routing overlay
- Long walks (>40 tiles) trigger a pace-of-play penalty suggestion

**Routing overlay data:**
```gdscript
func calculate_routing_cost(green_pos: Vector2i, next_tee_pos: Vector2i) -> Dictionary:
    var path = find_path(green_pos, next_tee_pos)
    var total_cost = _sum_path_cost(path)
    var distance_tiles = path.size()
    return {
        "path": path,
        "cost": total_cost,
        "distance": distance_tiles,
        "severity": "good" if distance_tiles < 20 else
                    "moderate" if distance_tiles < 40 else "poor"
    }
```

---

## Performance Budget

### Pathfinding cost analysis:

| Operation | Current | Target |
|-----------|---------|--------|
| A* on 128×128 grid (worst case) | 5000 iterations, ~2ms | Same |
| A* with terrain costs | N/A | 5000 iterations, ~3ms (dictionary lookup adds overhead) |
| Path simplification | ~0.1ms | ~0.2ms (more careful checking) |
| Cache hit | N/A | ~0.01ms (dictionary lookup) |

### With 8 concurrent golfers:
- Worst case: 8 simultaneous path calculations = ~24ms
- Reality: paths calculated on state transitions (entering WALKING), not every frame
- With caching: most paths are cache hits after the first golfer walks a route

### Optimization levers:
- Reduce max iterations from 5000 to 3000 (still finds paths on 128×128 grid)
- Use jump point search (JPS) for uniform-cost areas (faster than A* for open terrain)
- Limit path calculation to 1 per frame (queue others for next frame)

---

## Algorithm Documentation

Create `docs/algorithms/pathfinding.md` covering:
- Terrain movement cost table
- A* implementation details (heuristic, neighbor generation, cost function)
- Path simplification algorithm
- Cache strategy and invalidation
- Cart path routing decision
- Performance measurements and optimization notes

---

## Data Model Changes

### PathfindingSystem (new class):
```gdscript
# scripts/systems/pathfinding_system.gd
class_name PathfindingSystem

const TERRAIN_MOVE_COSTS: Dictionary = { ... }

var _path_cache: Dictionary = {}
var _cache_version: int = 0
var terrain_grid: TerrainGrid
var placement_manager: PlacementManager

func find_path(from: Vector2i, to: Vector2i) -> Array[Vector2]:
    # Check cache
    # Run A* with terrain costs
    # Simplify path
    # Cache result
    # Return screen-space waypoints

func invalidate_cache() -> void:
    _cache_version += 1

static func get_move_cost(terrain_type: int) -> float:
    return TERRAIN_MOVE_COSTS.get(terrain_type, 1.0)
```

### Golfer changes:
- Replace inline A* in `golfer.gd` with calls to `PathfindingSystem.find_path()`
- Remove duplicated pathfinding code from golfer entity
- Golfer only needs to follow waypoints, not calculate paths

---

## Implementation Sequence

```
Phase 1 (Core Improvements):
  1. PathfindingSystem class with terrain cost table
  2. Move A* from golfer.gd to PathfindingSystem
  3. Add terrain-type movement costs to A*
  4. Building collision integration

Phase 2 (Quality):
  5. Improved path simplification (cost-aware)
  6. Green avoidance penalty
  7. Expanded cart path search (±8 tiles)
  8. Cart path routing cost comparison

Phase 3 (Performance):
  9. Path caching system
  10. Cache invalidation on terrain/building changes
  11. Per-frame path calculation limiting
  12. Performance benchmarking

Phase 4 (Integration):
  13. Hole-to-hole routing cost calculation
  14. Routing overlay data feed
  15. Algorithm documentation
```

---

## Success Criteria

- Golfers visibly prefer walking on PATH terrain over cutting through rough
- Golfers route around buildings without clipping through edges
- No pathfinding failures on complex 18-hole courses with multiple buildings
- Path simplification doesn't create visually impossible routes (through water/buildings)
- Cart path routing activates when paths are reasonably nearby (within 8 tiles)
- Path caching reduces per-frame pathfinding cost by >80% in steady-state gameplay
- Pathfinding for 8 concurrent golfers doesn't cause frame drops (<5ms total per frame)

---

## Out of Scope

| Feature | Reason |
|---------|--------|
| Golf cart entities (ride instead of walk) | Vehicle simulation — separate feature |
| Dynamic obstacle avoidance (dodging other golfers) | Golfers are small; overlap is visually acceptable |
| Elevation-based path cost | Minimal visual impact; elevation affects shots, not walking |
| Real-time path visualization (debug) | Developer tool, not player feature |
| Navigation mesh (NavMesh) | Tile grid A* is sufficient for the game's scale |
| Crowd flow simulation | Only 8 concurrent golfers — not a crowd |
