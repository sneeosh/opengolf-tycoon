# UI/UX Polish Pass — Product Spec

**Author:** Claude (Product)
**Date:** 2026-02-27
**Status:** Proposal
**Milestone:** Beta Milestone 5
**Priority:** P2 — Polish
**Est. Scope:** Medium-Large

---

## Problem Statement

The game's UI is fully functional — 20+ panels are wired in, all hotkeys work, data flows correctly. But it looks and feels like a developer tool, not a game. Every panel uses default Godot Control styling. There are no icons on toolbar buttons, no visual hierarchy in the HUD, and no notification system beyond floating "+$XX" text. This creates three problems:

1. **First impression** — The main menu and in-game UI don't look like a finished game. Beta testers will judge quality before they experience the simulation depth.
2. **Discoverability** — Text-only toolbar buttons make it hard to quickly identify tools. Important information (money trend, seasonal state) is buried in undifferentiated text.
3. **Feedback loop** — Events happen silently. Revenue earned, milestones reached, and season changes need visible, non-blocking feedback.

---

## Current State

### What Already Exists

| Component | Status | Notes |
|-----------|--------|-------|
| **UIConstants** | Autoload singleton | Defines colors (`COLOR_PRIMARY`, `COLOR_SECONDARY`, `COLOR_BG`, etc.), font sizes, icon helpers |
| **TopHUDBar** | 430 lines, fully reactive | Segmented sections for money, day/season/time, reputation, rating, weather, wind |
| **MainMenu** | 370 lines, procedural | Theme cards, difficulty selector, course name input, Continue/New/Quick Start |
| **SettingsMenu** | 443 lines, 4 tabs | Audio, Display (colorblind mode included), Gameplay (placeholder), Controls |
| **CenteredPanel** | Base class for popups | `show_centered()`, `toggle()` — used by all popup panels |
| **20+ popup panels** | All functional | Financial, Staff, Marketing, Land, Tournament, Calendar, Analytics, etc. |
| **CreditsScreen** | 129 lines | Version, license, acknowledgments |
| **PauseMenu** | Complete | Resume/Save/Load/Settings/Quit |

### What's Missing

- No custom Godot Theme resource (`theme.tres`) — everything uses default grey styling
- Toolbar buttons are text-only — no icons, no color coding, no visual grouping
- No toast notification system — events are either floating text or modal dialogs
- Money display has no trend indicator or color coding
- Reputation has no star visual (just numeric display)
- Settings Gameplay tab is a placeholder

---

## Design Principles

- **Golf aesthetic.** Dark greens, warm wood tones, cream text. The UI should evoke a clubhouse, not a spreadsheet.
- **Hierarchy.** Primary information (money, day, alerts) is large and prominent. Secondary information (wind speed, maintenance cost) is smaller and subdued.
- **Non-blocking feedback.** Toast notifications for events, not dialogs. The player should never be pulled out of the flow.
- **Consistency.** One theme applied everywhere. No panels that feel like they're from a different game.

---

## User Stories

1. **As a player**, I want buttons and panels to look consistent and polished.
2. **As a player**, I want the toolbar to use icons (or icon+text) so I can quickly identify tools.
3. **As a player**, I want clear visual hierarchy — important information should be prominent.
4. **As a player**, I want notifications for important events that don't block gameplay.
5. **As a player**, I want the main menu to look inviting and professional.
6. **As a player**, I want a settings menu with all expected options.

---

## Functional Requirements

### FR-1: Custom Godot Theme Resource

Create a `theme.tres` (or procedural theme in code) that styles all standard Control nodes:

#### Color Palette

| Role | Color | Hex | Usage |
|------|-------|-----|-------|
| Primary | Golf Green | `#2d5a27` | Buttons, accents, active states |
| Secondary | Forest Green | `#4a8c3f` | Hover states, highlights |
| Background | Dark Night | `#1a1a2e` | Panel backgrounds, overlays |
| Surface | Dark Green | `#1e2d1e` | Card backgrounds, input fields |
| Text Primary | Cream | `#FFF8E7` | Body text, labels |
| Text Secondary | Muted Sage | `#a0b090` | Captions, secondary info |
| Accent Gold | Coin Gold | `#FFD700` | Money, achievements, records |
| Accent Red | Warning Red | `#CC4444` | Costs, negative values, alerts |
| Accent Blue | Info Blue | `#4682B4` | Information, winter, water |
| Border | Subtle Green | `#3a5a3a` | Panel borders, dividers |

#### Control Styles

| Control | Style |
|---------|-------|
| **Button** | Rounded corners (4px), subtle gradient (primary → slightly darker), hover: lighten 10%, pressed: darken 10%, disabled: 50% opacity |
| **PanelContainer** | Semi-transparent dark background (`#1a1a2e` at 90% opacity), 1px border (`#3a5a3a`), 12px padding |
| **Label** | Cream text, 4 size tiers: title (18px), heading (14px), body (12px), caption (10px) |
| **LineEdit** | Dark surface background, 1px border, cream text, focus: primary border |
| **ScrollContainer** | Thin scrollbar (4px, expands to 8px on hover), themed green color |
| **Separator** | 1px line in border color |
| **TabContainer** | Underline-style active tab indicator in primary color |
| **SpinBox** | Match LineEdit styling with themed increment buttons |
| **ProgressBar** | Primary fill on dark background, rounded ends |
| **HSlider** | Primary-colored track and grabber |

#### Font

- Use Godot's default font with size hierarchy
- Title: 18px bold
- Heading: 14px bold
- Body: 12px regular
- Caption: 10px regular

### FR-2: HUD Improvements

#### Top Bar Segmentation
The existing `TopHUDBar` already has sections. Enhance with:
- Subtle vertical dividers between sections (1px, 50% opacity border color)
- Consistent padding within each section (8px horizontal)
- Section background slightly lighter than bar background for grouping

#### Money Display Enhancement
- Larger font size (16px vs. 12px body)
- Gold color (`#FFD700`) for positive balance
- Red tint (`#CC4444`) when balance is negative
- Trend indicator: small up/down arrow based on last day's profit/loss
  - Green arrow up (▲) if yesterday's profit > 0
  - Red arrow down (▼) if yesterday's profit < 0
- Format: `$50,000 ▲` or `$-500 ▼`

#### Reputation Display Enhancement
- Star rating visual alongside numeric value
- Display: `★★★☆☆ 62` (filled/empty stars based on current course rating)
- Stars in gold color, numeric value in cream
- Animate star fill changes (brief pulse/glow on star gain)

#### Weather/Wind Icons
Replace text-only weather with icon-text combos:
- `☀ Sunny` / `⛅ Partly Cloudy` / `☁ Cloudy` / `🌦 Light Rain` / `🌧 Rain` / `⛈ Heavy Rain`
- Or use simple ASCII symbols if emoji rendering is inconsistent across platforms:
  - `[☀]` / `[⛅]` / `[☁]` / `[~]` / `[≈]` / `[≋]`
- Wind: `→ 15 mph` with arrow indicating direction (←↑→↓↗↘↙↖)

#### Season Indicator
- Color-coded season name (Spring=green, Summer=gold, Fall=orange, Winter=blue)
- Consistent with `SeasonSystem.get_season_color()` which already exists

### FR-3: Toolbar Improvements

#### Visual Grouping
Organize toolbar into labeled sections with subtle dividers:

```
| Terrain | Landscaping | Structures | Holes | Tools |
```

- **Terrain**: Fairway, Green, Tee Box, Rough, Heavy Rough, Bunker, Water, Path, OB
- **Landscaping**: Trees, Rocks, Flower Bed, Grass (natural)
- **Structures**: Buildings (opens building selection)
- **Holes**: Create Hole (H), Edit Hole
- **Tools**: Elevation (E), Eraser, Undo (Ctrl+Z), Redo (Ctrl+Y)

#### Terrain Button Enhancement
Replace text-only buttons with colored indicators:
- Each button: small colored square (8×8px) in the terrain's primary color + abbreviated text label
- Example: `[■] FWY` (green square + "FWY") for Fairway
- Selected tool: bright border highlight + slight background change
- Colors sourced from current theme's terrain palette (`CourseTheme.get_terrain_colors()`)

#### Brush Size Indicator
- Visual display of current brush size: "Brush: 3×3" or a small grid preview
- Already exists via F1 hotkey panel — just needs visual presence in toolbar

### FR-4: Toast Notification System

#### Notification Types

| Type | Color | Duration | Examples |
|------|-------|----------|---------|
| Revenue | Gold (`#FFD700`) | 3 seconds | "+$240 green fees", "+$500 tournament prize" |
| Cost | Red (`#CC4444`) | 3 seconds | "-$80 staff payroll", "-$5,000 land purchase" |
| Info | Blue (`#4682B4`) | 4 seconds | "Day 30 complete", "Spring has arrived!" |
| Achievement | Gold with border | 5 seconds | "New course record!", "Milestone: 9 holes!" |
| Warning | Orange (`#D2691E`) | 5 seconds | "Cash reserves low", "Course condition declining" |
| Event | Green (`#4a8c3f`) | 5 seconds | "Spring Open starts tomorrow!", "Holiday Weekend in progress" |

#### Notification Behavior
- Stack in **top-right corner**, below the HUD bar
- Maximum 4 visible at once (oldest auto-dismissed if more arrive)
- Slide in from right, fade out on dismissal
- Click any notification to dismiss early
- Translucent background (80% opacity) so game is visible behind

#### Replace Existing Floating Text
- Current floating "+$XX" revenue text replaced with toast notifications
- Current `EventBus.ui_notification(message, type)` signal can drive the toast system
- Batch frequent notifications: if 5 green fees arrive in 1 second, group as "+$240 green fees (8 golfers)"

#### Implementation

```
Class: ToastNotificationManager (CanvasLayer child)

Methods:
  show_toast(message: String, type: String, duration: float = 3.0)
  _create_toast_panel(message, color, duration) -> PanelContainer
  _stack_toasts()  # repositions visible toasts
  _dismiss_toast(toast: PanelContainer)

Connects to:
  EventBus.ui_notification
  EventBus.transaction_completed
  EventBus.season_changed
  EventBus.record_broken
  EventBus.tournament_completed
  EventBus.holiday_started
  EventBus.holiday_approaching
```

### FR-5: Main Menu Polish

#### Background
- Dark green gradient background (already exists: `#141e14`)
- Optionally: subtle parallax of terrain tiles in the background (reuse `TilesetGenerator` output)
- If too complex: keep solid dark green, which already looks clean

#### Title Treatment
- "OpenGolf Tycoon" in larger font (42px, already exists)
- Subtitle "Design. Build. Manage." in muted sage (already exists)
- Add version number below subtitle: "v0.1.0 Alpha" in caption size

#### Theme Selection Enhancement
- Current theme cards already show name, description, and modifier hints
- Enhance: Add terrain color sample strip (5 colors from the theme palette) at top of each card
- Enhance: Hover state brightens the card border in the theme's accent color

#### Button Layout
- Already well-organized in two rows
- Ensure consistent sizing and padding with new theme applied

### FR-6: Settings Menu Completion

Fill the Gameplay tab (currently placeholder):

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| Auto-save | Toggle | On | Save automatically at end of each day |
| Notification frequency | Dropdown | Normal | Low (summary only), Normal (individual events), High (every transaction) |
| Default game speed | Dropdown | Normal | Starting speed when simulation begins |
| Confirm land purchases | Toggle | On | Show confirmation dialog before buying land |
| Confirm staff changes | Toggle | Off | Show confirmation dialog before hire/fire |

Settings persist in `user://settings.cfg`.

---

## Technical Requirements

### Theme Application
- Create theme procedurally in `UIConstants` or as a `.tres` resource
- Apply to the root `UI` CanvasLayer node so all children inherit
- Individual panels may override specific styles where needed

### Notification Manager
- New `ToastNotificationManager` node added as child of `UI` CanvasLayer
- Self-managing: creates, positions, and removes toast panels automatically
- Connects to EventBus in `_ready()`

### Theme-Aware Components
- `TopHUDBar`: Apply new color scheme, add trend indicators
- `MainMenu`: Apply theme to all buttons and cards
- All `CenteredPanel` subclasses: Inherit base theme automatically
- `ToolPanel` (or equivalent toolbar): Add grouping dividers and colored indicators

---

## Acceptance Criteria

- [ ] Custom theme applied — no default Godot grey widgets visible in normal gameplay
- [ ] Top bar has clear visual segmentation with dividers and consistent padding
- [ ] Money display uses gold color with trend arrow (▲/▼)
- [ ] Reputation shows star visual (★★★☆☆) alongside numeric value
- [ ] Weather/wind use icon-text display instead of text-only
- [ ] Toolbar tools have colored indicators and are visually grouped by category
- [ ] Toast notification system displays revenue, cost, info, achievement, warning, and event notifications
- [ ] Notifications stack in top-right, auto-dismiss, and are clickable to dismiss
- [ ] Floating "+$XX" text replaced with toast notifications
- [ ] Settings Gameplay tab has functional options (auto-save, notification frequency, default speed)
- [ ] Main menu buttons use custom theme styling
- [ ] All panels (Financial, Staff, Marketing, Land, Tournament, etc.) use the custom theme
- [ ] Font is legible at 1600×1000 viewport resolution
- [ ] Color-blind considerations: don't rely solely on red/green for critical information (already have colorblind mode)
- [ ] Settings persist across sessions

---

## Out of Scope

- Icon art assets from external artists (use colored shapes/text abbreviations as placeholders)
- Animation/transitions between screens (slide-in, fade)
- Responsive layout for different resolutions (fixed 1600×1000 for beta)
- Gamepad/controller support
- Custom fonts (use Godot default with size hierarchy)
- Sound effects for UI interactions (already handled by SoundManager)

---

## Dependencies

- None — can be developed in parallel with other milestones
- Milestone 3 (Tutorial) benefits from tooltips and notification system added here
- Milestone 2 (Seasonal Calendar) UI elements should use the theme

---

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Theme changes break panel layouts | Medium | Medium | Test all 20+ panels after theme application; use `CenteredPanel.show_centered()` for layout correction |
| Toast notifications are distracting during fast gameplay | Medium | Medium | Configurable frequency (FR-6 notification preference); max 4 visible at once |
| Emoji/Unicode rendering differs across platforms | Medium | Low | Use ASCII fallbacks; test in web build |
| Theme colors don't work with all 10 course themes | Low | Medium | Theme palette is for UI chrome, not terrain; verify contrast with each course theme's accent color |

---

## Estimated Effort

- Custom theme resource: 100–200 lines (procedural) or theme editor work
- HUD improvements (money, reputation, weather): 100–150 lines
- Toolbar grouping and indicators: 100–150 lines
- Toast notification system: 150–200 lines
- Main menu polish: 50–100 lines
- Settings Gameplay tab: 50–80 lines
- Theme application across all panels: 50–100 lines (mostly style overrides)
- **Total: ~600–1,000 lines of code**
