# Hole Context Menu & Pin Position — Product Spec

**Author:** Claude (Product)
**Date:** 2026-02-27
**Status:** Proposal
**Version:** 0.1.0-alpha context

---

## Problem Statement

When a player clicks a hole's flag, the only response is highlighting the hole and (via the sidebar) opening a stats panel. There is no in-world interaction menu for the hole itself. Players cannot:

1. **Move the pin** — The flag/cup is permanently fixed at the green position set during hole creation. Real courses change pin positions daily to vary difficulty and wear.
2. **Relocate tee or green** — Once placed, tee boxes and greens are permanent. If the terrain is painted over (e.g., bulldozed or replaced with grass), the hole data still references the old position, creating an **orphaned hole** — a hole whose tee or green tile no longer exists on the map but still appears in the hole list and affects golfer routing.
3. **Quickly open/close a hole** — The toggle exists in the sidebar hole list, but there's no way to do it from the course view.
4. **See hole info at a glance** — Revenue and rating data require navigating to separate panels.

This spec introduces a **Hole Context Menu** that appears when clicking a hole's tee box or green, providing quick access to hole management actions including a dedicated **Pin Move Mode** with hover preview, and **Move Tee / Move Green** actions that also solve the orphaned hole bug.

---

## Design Principles

- **Direct manipulation.** Players should interact with holes on the course map, not just through sidebar lists.
- **Modal with clear exit.** Pin Move Mode is a focused interaction with obvious entry/exit — no ambiguity about what clicks do.
- **Non-destructive.** Moving the pin doesn't change the green terrain — it repositions the cup within the existing green tiles.
- **Information at the point of need.** Show hole revenue and rating in the context menu so players don't have to hunt for it.

---

## Feature Overview

### 1. Hole Context Menu

A popup menu that appears when the player clicks on a hole's **tee box tile** or **green tile** (or the existing **flag click target**).

#### Trigger

- **Left-click** on any tile whose terrain type is `TEE_BOX` or `GREEN` that belongs to an existing hole.
- **Left-click** on a hole's Flag entity (existing `flag_selected` signal — currently highlights the hole; will now open this menu instead).
- Only activates when no other tool is active (no terrain painting, no placement mode, no elevation tool, no bulldozer).

#### Menu Contents

The menu is a compact popup (similar to existing `AcceptDialog`-based selection menus) anchored near the clicked position. It contains:

| Item | Type | Description |
|------|------|-------------|
| **Hole N — Par P** | Header label | Title row showing hole number and par |
| **Move Pin Position** | Button | Enters Pin Move Mode (see Section 2) |
| **Move Tee** / **Place Tee** | Button | Enters Tee Move Mode (see Section 2b). Label is "Place Tee" if the tee tile is missing (orphaned). |
| **Move Green** / **Place Green** | Button | Enters Green Move Mode (see Section 2c). Label is "Place Green" if the green tile is missing (orphaned). |
| **Open / Close Hole** | Toggle button | Toggles `hole_data.is_open`. Text and color reflect current state. Calls `GameManager.current_course.toggle_hole_open()` and emits `EventBus.hole_toggled`. |
| **Hole Rating** | Info row | Shows difficulty rating (1.0–10.0) with color coding (green < 4, yellow 4–7, red >= 7) |
| **Hole Revenue** | Info row | Shows total green fee revenue attributed to this hole (see Section 3) |
| **View Statistics** | Button | Opens the existing `HoleStatsPanel` for this hole (reuses `_show_hole_stats()`) |

#### Behavior

- Menu closes when the player clicks outside it, presses Escape, or selects an action.
- Only one hole context menu can be open at a time.
- Opening the menu highlights the hole (yellow path line) via existing `HoleVisualizer.highlight()`.
- Closing the menu removes the highlight.
- During `SIMULATING` mode, the "Move Pin Position", "Move Tee", and "Move Green" buttons are disabled with a tooltip explaining why. Open/Close and info rows remain available.

#### Detecting Which Hole Was Clicked

When the player clicks a `TEE_BOX` or `GREEN` tile, the system must determine which hole it belongs to:

1. Iterate `GameManager.current_course.holes`.
2. For each `HoleData`, check if the clicked `Vector2i` matches `tee_position`, `green_position`, or `hole_position`.
3. Additionally, check against any expanded green tiles by comparing the clicked position to all tiles of type `GREEN` within a reasonable radius of each hole's `green_position` (greens may be multi-tile in the future).
4. If multiple holes share the position (unlikely but possible with overlapping greens), prefer the hole whose `green_position` or `tee_position` is an exact match.

For the initial implementation, since tee boxes and greens are single tiles, an exact match against `tee_position`, `green_position`, and `hole_position` is sufficient.

---

### 2. Pin Move Mode

A modal interaction state where the player repositions the flag/cup on the green.

#### Entry

- Player clicks "Move Pin Position" in the Hole Context Menu.
- The context menu closes.
- The game enters Pin Move Mode (a new state, not a full `GameMode` — more like the existing `HoleCreationTool.PlacementMode`).

#### Visual Feedback During Pin Move Mode

- **Status bar message:** "Click a green tile to place the pin. Press Escape or right-click to cancel."
- **Cursor change:** The cursor changes to a crosshair or placement cursor (reuse existing placement preview style).
- **Hover preview:** As the mouse moves over the course, a semi-transparent flag sprite is drawn at the hovered tile position — but **only when hovering over valid green tiles** that belong to the selected hole's green. On invalid tiles, the preview is hidden (no red X — just absent).
- **Current pin highlight:** The existing flag position pulses or has a subtle glow to show where the pin currently is.
- **Hole highlight:** The hole remains highlighted (yellow) throughout the mode.

#### Valid Pin Positions

A tile is a valid pin position if:

1. `terrain_grid.get_tile(pos) == TerrainTypes.Type.GREEN` — Must be a green tile.
2. The green tile belongs to the selected hole — For the initial single-tile-green implementation, this means `pos == hole_data.green_position`. When multi-tile greens are added, this will check membership in the hole's green tile set.
3. The position is not occupied by another hole's pin.

#### Placement

- **Left-click** on a valid green tile:
  1. Calls `Flag.move_to(new_position)` on the hole's flag.
  2. This triggers `flag_moved` signal → `HoleVisualizer._on_flag_moved()` updates `hole_data.hole_position`, recalculates distance/par/difficulty, and refreshes visuals.
  3. Emits `EventBus.hole_updated` signal.
  4. Exits Pin Move Mode.
  5. Shows a notification: "Hole N pin moved."

- **Left-click** on an invalid tile: Nothing happens (no error sound, just ignored).

#### Cancellation

- **Escape key** or **right-click**: Exits Pin Move Mode without changes.
- **Selecting a different tool** (terrain brush, placement, etc.): Cancels Pin Move Mode.

#### Constraints

- Pin cannot be moved while the game is in `SIMULATING` mode (button disabled in context menu).
- Moving the pin is free (no cost). Pin position is a design tool, not a purchasable action.
- The pin move is **undoable** via the existing `UndoManager` — store the old and new `hole_position` as an undo action.

---

### 2b. Move Tee / Place Tee Mode

A modal interaction state where the player relocates (or restores) the hole's tee box.

#### Motivation — The Orphaned Hole Bug

Currently, hole data (`HoleData.tee_position`) is never updated after creation. If the player paints over the tee tile with another terrain type (e.g., grass, fairway, or uses bulldozer), the hole data still references the old position. This creates an orphaned tee — golfers try to start from a tile that is no longer a tee box, and the hole visualization draws a path from a non-existent tee. Similarly, `delete_hole()` removes the hole data but leaves the `TEE_BOX` terrain tile on the map.

"Move Tee" / "Place Tee" lets the player fix this by repositioning the tee to a valid location.

#### Dynamic Label

The button label adapts to the current state:
- **"Move Tee"** — The tee tile exists at `hole_data.tee_position` (terrain type is `TEE_BOX`).
- **"Place Tee"** — The tee tile is missing (terrain at `hole_data.tee_position` is no longer `TEE_BOX`). Shown with a warning color/icon to alert the player that the hole is broken.

#### Entry

- Player clicks "Move Tee" or "Place Tee" in the Hole Context Menu.
- The context menu closes.
- The game enters Tee Move Mode.

#### Visual Feedback

- **Status bar message:** "Click to place the tee box. Press Escape or right-click to cancel."
- **Hover preview:** A semi-transparent tee box indicator at the hovered tile. Shown on any valid position; hidden on invalid positions.
- **Hole highlight:** The hole remains highlighted (yellow) throughout the mode.
- **Old tee marker:** If the old tee tile still exists, it pulses to show the current position.

#### Valid Tee Positions

A tile is a valid new tee position if:

1. `terrain_grid.is_valid_position(pos)` — Within the grid bounds.
2. The tile is not water, out of bounds, or occupied by a building.
3. The position is at least 5 tiles from the hole's green (same minimum distance rule as `HoleCreationTool`, enforcing the ~110 yard minimum).
4. The position is not another hole's tee or green.

#### Placement

- **Left-click** on a valid tile:
  1. **Revert old tee tile:** If the terrain at the old `tee_position` is still `TEE_BOX`, change it back to `GRASS` (restore the terrain).
  2. **Remove obstacles** at the new position (reuse `HoleCreationTool._remove_obstacles_at()`).
  3. **Place new tee tile:** Set `terrain_grid.set_tile(new_pos, TerrainTypes.Type.TEE_BOX)`.
  4. **Update hole data:** Set `hole_data.tee_position = new_pos`.
  5. **Recalculate:** Distance, par, and difficulty via the same logic in `HoleVisualizer._on_flag_moved()`.
  6. **Emit signals:** `EventBus.hole_updated.emit(hole_number)`.
  7. **Cost:** Placement costs the standard `TEE_BOX` placement cost ($12). If the old tee was reverted to grass, refund its placement cost.
  8. Exit Tee Move Mode.
  9. Show notification: "Hole N tee box moved." (or "Hole N tee box placed." if it was missing).

- **Left-click** on an invalid tile: Ignored.

#### Cancellation

Same as Pin Move Mode — Escape, right-click, or selecting another tool.

#### Undo

Store as an undo action: old tee position, new tee position, old terrain type at new position (for full reversal).

---

### 2c. Move Green / Place Green Mode

A modal interaction state where the player relocates (or restores) the hole's green.

#### Dynamic Label

- **"Move Green"** — The green tile exists at `hole_data.green_position` (terrain type is `GREEN`).
- **"Place Green"** — The green tile is missing. Shown with a warning color/icon.

#### Entry

Same pattern as Tee Move Mode.

#### Visual Feedback

- **Status bar message:** "Click to place the green. Press Escape or right-click to cancel."
- **Hover preview:** A semi-transparent green tile indicator at the hovered position.
- **Old green marker:** If the old green tile still exists, it pulses to show the current position.

#### Valid Green Positions

A tile is a valid new green position if:

1. `terrain_grid.is_valid_position(pos)` — Within the grid bounds.
2. The tile is not water, out of bounds, or occupied by a building.
3. The position is at least 5 tiles from the hole's tee (minimum distance rule).
4. The position is not another hole's tee or green.

#### Placement

- **Left-click** on a valid tile:
  1. **Revert old green tile:** If the terrain at the old `green_position` is still `GREEN`, change it back to `GRASS`.
  2. **Remove obstacles** at the new position.
  3. **Place new green tile:** Set `terrain_grid.set_tile(new_pos, TerrainTypes.Type.GREEN)`.
  4. **Update hole data:** Set `hole_data.green_position = new_pos`.
  5. **Move pin:** If `hole_data.hole_position` was at the old green position, move the pin to the new green position too. Otherwise, if the pin position is no longer a valid green tile, move it to the new green position.
  6. **Move flag entity:** Call `Flag.set_position_in_grid(hole_data.hole_position)` and emit `flag_moved`.
  7. **Recalculate:** Distance, par, and difficulty.
  8. **Emit signals:** `EventBus.hole_updated.emit(hole_number)`.
  9. **Cost:** Standard `GREEN` placement cost ($20). Refund if old green tile was reverted.
  10. Exit Green Move Mode.
  11. Show notification: "Hole N green moved." (or "Hole N green placed.").

- **Left-click** on an invalid tile: Ignored.

#### Cancellation & Undo

Same pattern as Tee Move Mode.

---

### 2d. Shared Move Mode Infrastructure

All three move modes (Pin, Tee, Green) share a common pattern. Implementation should use a single state machine or enum:

```gdscript
enum HoleMoveMode {
    NONE,
    MOVING_PIN,
    MOVING_TEE,
    MOVING_GREEN
}
```

Common behavior across all modes:
- Cancel on Escape / right-click.
- Cancel when another tool is activated.
- Hover preview only on valid tiles.
- Single-click to confirm placement.
- Undo support.
- Hole remains highlighted during the mode.

The validation and placement logic differ per mode, but the input handling, preview rendering, and state transitions are shared.

---

### 3. Hole Revenue Tracking

Currently, green fees are tracked globally per round (`DailyStatistics.record_green_fee()`), not per hole. To show meaningful revenue in the context menu, we need per-hole revenue attribution.

#### Approach

Since golfers pay a single green fee for their entire round (all holes), per-hole revenue is calculated as:

```
hole_revenue = total_green_fee / number_of_holes_played
```

#### Data Model

Add to `GameManager.HoleStatistics`:

```gdscript
var total_revenue: int = 0  # Cumulative revenue attributed to this hole
```

#### Tracking

When `EventBus.golfer_finished_round` fires:
1. Get the number of holes the golfer played.
2. Get the green fee they paid (stored on the golfer or calculated from `GameManager.green_fee * holes_played`).
3. Attribute `green_fee_per_hole = green_fee / holes_played` to each hole's `HoleStatistics.total_revenue`.

This is an approximation — it treats all holes as equally valuable — but it's simple and directionally useful. A future enhancement could weight revenue by hole difficulty or satisfaction.

#### Display

In the context menu, show:
- **Revenue:** `$X,XXX` (cumulative)
- If no rounds played: "No revenue yet"

---

### 4. Integration with Existing Systems

#### EventBus

New signal needed:
```gdscript
signal pin_position_changed(hole_number: int, old_position: Vector2i, new_position: Vector2i)
```

This is distinct from the existing `hole_updated` signal to allow systems to react specifically to pin changes (e.g., recalculating shot paths, updating the wind flag overlay position).

#### Save/Load

No changes needed — `hole_position` is already persisted in `HoleData` serialization via `SaveManager`. Moving the pin updates `hole_data.hole_position`, which is saved automatically.

#### Golfer AI

No changes needed — `ShotAI.decide_shot()` already targets `hole_data.hole_position`, not `hole_data.green_position`. Moving the pin automatically changes golfer targeting.

#### WindFlagOverlay

The wind flag overlay renders the animated flag at the flag entity's position. Since `Flag.move_to()` updates the node's `global_position`, the wind flag should track correctly. Verify this during implementation.

#### HoleVisualizer

Already handles `flag_moved` signal — updates hole data, recalculates difficulty/par/distance, refreshes shot path and info label.

---

## New Files

| File | Type | Purpose |
|------|------|---------|
| `scripts/ui/hole_context_menu.gd` | UI class | The popup context menu (extends `PanelContainer` or `PopupPanel`) |

## Modified Files

| File | Change |
|------|--------|
| `scripts/main/main.gd` | Add click detection for tee/green tiles, create and manage `HoleContextMenu`, implement `HoleMoveMode` state machine (pin/tee/green), hover preview rendering, validation, and placement logic |
| `scripts/autoload/event_bus.gd` | Add `pin_position_changed` signal, add `hole_tee_moved` and `hole_green_moved` signals |
| `scripts/autoload/game_manager.gd` | Add `total_revenue` to `HoleStatistics`, add per-hole revenue tracking in `_on_golfer_finished_round_for_stats` |
| `scripts/entities/flag.gd` | No changes needed (existing `move_to()` and `flag_moved` signal are sufficient) |
| `scripts/managers/hole_manager.gd` | Add helper method `get_hole_at_position(grid_pos: Vector2i) -> HoleData` to find which hole a tile belongs to |
| `scripts/course/hole_visualizer.gd` | Handle tee/green position updates — update shot path line endpoints, recalculate waypoints, refresh info label |
| `scripts/tools/hole_creation_tool.gd` | Extract shared validation logic (min distance, obstacle removal) into reusable static methods for the move modes to call |

---

## UX Flow

```
Player clicks GREEN or TEE_BOX tile (or flag)
  │
  ├─ No hole found at position → Nothing happens (normal click behavior)
  │
  └─ Hole found → Open Hole Context Menu
       │
       ├─ "Move Pin Position" clicked
       │     └─ Enter Pin Move Mode
       │           ├─ Hover over GREEN tile → Show flag preview
       │           ├─ Click GREEN tile → Move pin, exit mode, show notification
       │           ├─ Escape / Right-click → Cancel, exit mode
       │           └─ Click non-GREEN tile → Ignored
       │
       ├─ "Move Tee" / "Place Tee" clicked
       │     └─ Enter Tee Move Mode
       │           ├─ Hover over valid tile → Show tee preview
       │           ├─ Click valid tile → Move tee, exit mode, show notification
       │           ├─ Escape / Right-click → Cancel, exit mode
       │           └─ Click invalid tile → Ignored
       │
       ├─ "Move Green" / "Place Green" clicked
       │     └─ Enter Green Move Mode
       │           ├─ Hover over valid tile → Show green preview
       │           ├─ Click valid tile → Move green + pin, exit mode, show notification
       │           ├─ Escape / Right-click → Cancel, exit mode
       │           └─ Click invalid tile → Ignored
       │
       ├─ "Open/Close Hole" clicked → Toggle state, update UI, close menu
       │
       ├─ "View Statistics" clicked → Open HoleStatsPanel, close menu
       │
       └─ Click outside / Escape → Close menu
```

---

## Edge Cases

1. **Single-tile green:** Currently greens are one tile, so the pin can only be at that one position. "Move Pin Position" will still work — the player can click the same tile (no-op) or cancel. This becomes truly useful once multi-tile greens are implemented.
2. **Hole closed while in a move mode:** If another system closes the hole during any move mode, cancel the mode and show a notification.
3. **Multiple holes with adjacent greens:** The `get_hole_at_position()` lookup must handle ambiguity. Prefer exact matches (`green_position`, `tee_position`) over proximity.
4. **Pin/tee/green moved while golfer is playing the hole:** The golfer should finish their current shot targeting the old position. The new position takes effect for subsequent shots. This happens naturally since the golfer caches positions at shot decision time.
5. **Undo pin move:** Restores `hole_position` to previous value, moves flag entity back, recalculates difficulty/distance/par.
6. **Orphaned tee/green (terrain painted over):** The context menu detects this by checking `terrain_grid.get_tile(hole_data.tee_position) != TerrainTypes.Type.TEE_BOX` (and similarly for green). The button label switches to "Place Tee" / "Place Green" and a warning indicator (e.g., yellow text or icon) is shown in the menu header to alert the player. The hole should also be auto-closed (`is_open = false`) if either its tee or green is missing, preventing golfers from being routed to a broken hole.
7. **Moving tee/green to a tile occupied by another hole's tee or green:** Rejected as invalid — the validation step checks all hole positions.
8. **Moving green when pin is at a custom position:** If the pin was on the old green and the green moves, the pin follows to the new green position. If the pin was at a separate position that's still a valid green tile, it stays — but this scenario only arises with multi-tile greens (future).
9. **Placing tee/green when the old tile still exists:** The old tile is reverted to GRASS. This means a player can use "Move Tee" to relocate a tee box without manually cleaning up the old tile.

---

## Future Enhancements

- **Multi-tile greens:** Expand green placement to paint multiple GREEN tiles. Pin can be placed on any of them. This is the primary motivation for the pin move feature.
- **Multi-tile tee boxes:** Allow multiple TEE_BOX tiles per hole. Different tiers of golfers use different tees (forward/middle/back).
- **Daily pin rotation:** Auto-move the pin to a random valid green tile each day (toggleable per hole). Adds variety and maintenance flavor.
- **Pin position difficulty modifier:** Pins placed near the edge of the green or near bunkers increase difficulty. Feed this into `DifficultyCalculator`.
- **Orphan auto-detection:** Proactively detect orphaned tees/greens when terrain is painted over (via `terrain_tile_changed` signal) and auto-close affected holes with a warning notification, rather than waiting for the player to open the context menu.
- **Context menu for buildings:** Extend the context menu pattern to buildings for upgrade/demolish/info actions.
