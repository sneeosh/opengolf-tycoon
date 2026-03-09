# Pin Position Rotation

> **Source:** `scripts/autoload/game_manager.gd` (HoleData class, `_rotate_pin_positions()`), `scripts/course/hole_visualizer.gd`

## Plain English

Each hole has up to 4 pin positions spread across the green. Pins rotate automatically at the start of each new day (sequential, wrapping). Different pin positions subtly change hole character — a front pin behind a bunker is a shorter carry than a back pin.

Pin positions are auto-generated when a hole is created by analyzing the green tiles and picking spread-out positions in 4 quadrants (front-left, front-right, back-left, back-right relative to the tee direction). Players can manually reposition the active pin using the existing "Move Pin" action.

---

## Algorithm

### 1. Auto-Generation

```
1. Flood fill from green_position to find all GREEN tiles (cardinal directions, max 100)
2. Compute green center = average of all green tile positions
3. Define orientation:
    tee_dir = (green_position - tee_position).normalized()  # "forward" toward tee
    perp_dir = perpendicular to tee_dir                     # "left/right"
4. For each green tile:
    Classify into quadrant based on dot products with tee_dir and perp_dir
    Quadrants: front-left, front-right, back-left, back-right
5. For each populated quadrant:
    Pick the tile furthest from green center (maximizes spread)
6. Result: 1-4 pin positions depending on green size/shape

If green has ≤2 tiles → single pin position only (too small for rotation)
```

### 2. Daily Rotation

```
On advance_to_next_day():
    For each hole with pin_positions.size() > 1:
        current_pin_index = (current_pin_index + 1) % pin_positions.size()
        hole_position = pin_positions[current_pin_index]

    Emit EventBus.pins_rotated signal
```

The `pins_rotated` signal triggers HoleVisualizer to:
- Move the flag to the new pin position
- Refresh inactive pin markers
- Recalculate shot path and forced carry annotations

### 3. Visualization

- **Active pin:** The Flag entity (existing, clickable/draggable)
- **Inactive pins:** Dim gold circles (3px radius, 40% alpha) at each non-active pin position
- Markers are only drawn when the hole has 2+ pin positions

### 4. Manual Override

Players can move the active pin using "Move Pin" in the context menu. This updates `pin_positions[current_pin_index]` to the new location, preserving the rotation cycle.

---

## Tuning Levers

| Parameter | Location | Current Value | Effect |
| --- | --- | --- | --- |
| Min green size for rotation | `game_manager.gd` HoleData | 3 tiles | Greens with ≤2 tiles get single pin |
| Max green flood fill | `game_manager.gd` HoleData | 100 tiles | Safety limit for flood fill |
| Rotation frequency | `game_manager.gd` `_rotate_pin_positions()` | Daily (every day change) | How often pins rotate |
| Inactive pin color | `hole_visualizer.gd` | Gold (0.8, 0.7, 0.2, 0.4) | Visual appearance of non-active pins |
| Inactive pin size | `hole_visualizer.gd` | 3px radius | Size of non-active pin markers |
