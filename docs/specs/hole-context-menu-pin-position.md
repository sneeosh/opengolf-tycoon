# Hole Context Menu & Pin Position — Product Spec

**Author:** Claude (Product)
**Date:** 2026-02-27
**Status:** Proposal
**Version:** 0.1.0-alpha context

---

## Problem Statement

When a player clicks a hole's flag, the only response is highlighting the hole and (via the sidebar) opening a stats panel. There is no in-world interaction menu for the hole itself. Players cannot:

1. **Move the pin** — The flag/cup is permanently fixed at the green position set during hole creation. Real courses change pin positions daily to vary difficulty and wear.
2. **Quickly open/close a hole** — The toggle exists in the sidebar hole list, but there's no way to do it from the course view.
3. **See hole info at a glance** — Revenue and rating data require navigating to separate panels.

This spec introduces a **Hole Context Menu** that appears when clicking a hole's tee box or green, providing quick access to hole management actions including a dedicated **Pin Move Mode** with hover preview.

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
| **Open / Close Hole** | Toggle button | Toggles `hole_data.is_open`. Text and color reflect current state. Calls `GameManager.current_course.toggle_hole_open()` and emits `EventBus.hole_toggled`. |
| **Hole Rating** | Info row | Shows difficulty rating (1.0–10.0) with color coding (green < 4, yellow 4–7, red >= 7) |
| **Hole Revenue** | Info row | Shows total green fee revenue attributed to this hole (see Section 3) |
| **View Statistics** | Button | Opens the existing `HoleStatsPanel` for this hole (reuses `_show_hole_stats()`) |

#### Behavior

- Menu closes when the player clicks outside it, presses Escape, or selects an action.
- Only one hole context menu can be open at a time.
- Opening the menu highlights the hole (yellow path line) via existing `HoleVisualizer.highlight()`.
- Closing the menu removes the highlight.
- Menu does not open during `SIMULATING` mode for the "Move Pin Position" action — the button is disabled with a tooltip explaining why. Open/Close and info rows remain available.

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
| `scripts/main/main.gd` | Add click detection for tee/green tiles, create and manage `HoleContextMenu`, implement Pin Move Mode state |
| `scripts/autoload/event_bus.gd` | Add `pin_position_changed` signal |
| `scripts/autoload/game_manager.gd` | Add `total_revenue` to `HoleStatistics`, add per-hole revenue tracking in `_on_golfer_finished_round_for_stats` |
| `scripts/entities/flag.gd` | No changes needed (existing `move_to()` and `flag_moved` signal are sufficient) |
| `scripts/managers/hole_manager.gd` | Add helper method `get_hole_at_position(grid_pos: Vector2i) -> HoleData` to find which hole a tile belongs to |
| `scripts/course/hole_visualizer.gd` | No changes needed (already handles `flag_moved`) |

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
       │     │
       │     └─ Enter Pin Move Mode
       │           │
       │           ├─ Hover over GREEN tile → Show flag preview
       │           ├─ Click GREEN tile → Move pin, exit mode, show notification
       │           ├─ Escape / Right-click → Cancel, exit mode
       │           └─ Click non-GREEN tile → Ignored
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
2. **Hole closed while pin move is active:** If another system closes the hole during pin move mode, cancel the mode and show a notification.
3. **Multiple holes with adjacent greens:** The `get_hole_at_position()` lookup must handle ambiguity. Prefer exact matches (`green_position`, `tee_position`) over proximity.
4. **Pin moved while golfer is putting:** The golfer should finish their current shot targeting the old position. The new position takes effect for subsequent shots. This happens naturally since the golfer caches `hole_data.hole_position` at shot decision time.
5. **Undo pin move:** Restores `hole_position` to previous value, moves flag entity back, recalculates difficulty/distance/par.

---

## Future Enhancements

- **Multi-tile greens:** Expand green placement to paint multiple GREEN tiles. Pin can be placed on any of them. This is the primary motivation for the pin move feature.
- **Daily pin rotation:** Auto-move the pin to a random valid green tile each day (toggleable per hole). Adds variety and maintenance flavor.
- **Pin position difficulty modifier:** Pins placed near the edge of the green or near bunkers increase difficulty. Feed this into `DifficultyCalculator`.
- **Tee box selection (multiple tees):** Similar to pin positions, allow multiple tee boxes per hole for different skill tiers (forward/middle/back tees).
- **Context menu for buildings:** Extend the right-click context menu pattern to buildings for upgrade/demolish/info actions.
