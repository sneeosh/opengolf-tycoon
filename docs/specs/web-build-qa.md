# Web Build & Cross-Platform QA — Product Spec

**Author:** Claude (Product)
**Date:** 2026-02-27
**Status:** Proposal
**Milestone:** Beta Milestone 7
**Priority:** P2 — Release
**Est. Scope:** Small-Medium

---

## Problem Statement

The web build is the primary distribution channel for beta testing — zero install friction means any potential tester can play within seconds. The game already has CI/CD that exports to 4 platforms and deploys to Cloudflare Pages, plus a custom HTML shell that suppresses browser input conflicts. However, the web build has not been systematically tested with all current features (Phase 3, seasons, tutorial, UI theme, notifications).

A broken web build means no beta testing. This milestone is the release gate.

---

## Current State

### What Already Exists

#### CI/CD Pipeline (`.github/workflows/export-game.yml`, 205 lines)

| Job | Trigger | Targets | Deploy |
|-----|---------|---------|--------|
| `export` | `v*` tags | Windows, macOS, Linux, Web (matrix) | GitHub Release artifacts |
| `deploy-web` | Tags + workflow_dispatch | All 4 platforms | Cloudflare Workers (web), R2 bucket (desktop zips) |
| `release` | After `export` | — | GitHub Release with zipped artifacts |

- Godot 4.6-stable, headless export
- Binary and export templates cached at `~/.local/share/godot/export_templates/4.6.stable`
- `fail-fast: false` — all platforms attempt even if one fails

#### Custom HTML Shell (`web/custom_shell.html`, 295 lines)

- Golf-themed loading screen (dark green background, SVG logo, Georgia serif title)
- Progress bar (220px, dark-to-bright green)
- Browser input conflict suppression:
  - Right-click context menu blocked on canvas
  - Scroll wheel `preventDefault()` (non-passive) — only game zooms, not page
  - Middle-click autoscroll suppressed
  - Safari pinch-to-zoom suppressed
  - Multi-touch `touchmove` (>1 finger) suppressed
  - `Ctrl/Cmd+S`, `Ctrl/Cmd+Z`, `Ctrl/Cmd+Y`, `Tab`, `F1`, `F2`, `F3` intercepted

#### Web Optimizations Already Present

- `DayNightSystem`: CanvasModulate updates throttled to 100ms on web (vs. every frame on desktop)
- `OS.get_name() == "Web"` checks in multiple files for platform-specific behavior
- Forward+ renderer (Godot 4.6 default for web)

### What Needs Verification

- All Milestone 1–6 features working in web build
- Browser compatibility across Chrome, Firefox, Safari
- Save/load via IndexedDB (browser storage)
- Audio via Web Audio API (browser autoplay policies)
- Performance at 30+ FPS during active simulation
- Desktop builds launching without errors

---

## User Stories

1. **As a beta tester**, I want to play the game in my browser without installing anything.
2. **As a beta tester**, I want the web build to perform acceptably (30+ FPS on a modern laptop).
3. **As a beta tester**, I want my browser save data to persist across sessions (page refresh, tab close/reopen).
4. **As a desktop beta tester**, I want the downloaded build to launch and run without errors.
5. **As a beta tester**, I want clear instructions on how to access and play the game.

---

## Functional Requirements

### FR-1: Web Build Functional Testing

#### Browser Matrix

| Browser | OS | Priority | Notes |
|---------|-----|----------|-------|
| Chrome (latest) | Windows/macOS/Linux | P0 | Primary target, largest user base |
| Firefox (latest) | Windows/macOS/Linux | P0 | Second largest; different WebGL implementation |
| Safari (latest) | macOS | P1 | WebKit engine; known Godot quirks |
| Edge (latest) | Windows | P2 | Chromium-based, should match Chrome |

#### Input Testing (per browser)

| Input | Test | Expected |
|-------|------|----------|
| Left click | Paint terrain, select buttons, click minimap | Works, no browser interference |
| Right click | Deselect/cancel in game | Context menu suppressed (custom_shell.html handles this) |
| Click + drag | Paint large terrain areas, pan camera | Smooth, no accidental text selection |
| Scroll wheel | Camera zoom in/out | Game zooms, page doesn't scroll |
| Middle click | (if any game use) | Browser autoscroll suppressed |
| WASD | Camera pan | No browser search/action triggers |
| Spacebar | Start/pause simulation | Page doesn't scroll down |
| Escape | Pause menu / close panel | No browser "exit fullscreen" interference |
| Ctrl+S | Quick save | Browser save dialog suppressed |
| Ctrl+Z / Ctrl+Y | Undo / Redo | Browser undo suppressed |
| F1 | Help panel | Browser help page suppressed |
| Tab | (if any game use) | Browser focus cycling suppressed |
| Number keys 1-9 | (toolbar shortcuts if any) | No browser tab switching |

#### Feature Testing (per browser)

| Feature | Test | Expected |
|---------|------|----------|
| New Game | Create course, select theme, start | Works end-to-end |
| Quick Start | Pre-built 3-hole course | Loads and is playable |
| Terrain painting | All 14 terrain types | Render correctly; theme colors applied |
| Hole creation | 3-step: tee → green → flag | All steps complete; hole appears in stats |
| Building placement | All 8 types | Place, proximity revenue works |
| Simulation | Start, watch golfers, end of day | Golfers spawn, play, finish; day advances |
| Save/Load | Save game, refresh page, load game | Data persists via IndexedDB |
| Settings | Change audio, display, gameplay settings | Settings persist via IndexedDB |
| Tutorial | Complete all 7 steps | Steps advance on signals; completion persists |
| Seasonal calendar | Observe season changes over multiple days | UI updates; modifiers apply |
| Toast notifications | Trigger revenue/event notifications | Appear, stack, auto-dismiss |
| Staff panel | Hire, fire, verify payroll | Full lifecycle works |
| Marketing panel | Start campaign, observe effect | Spawn rate changes visibly |
| Land panel | Purchase parcels, paint new land | Boundary updates; terrain paintable |
| Tournament | Schedule and complete | Results display; revenue awarded |
| Pause menu | Esc → Resume/Save/Load/Settings/Quit | All options functional |
| Main menu | New/Continue/Load/Settings/Credits/Quit | All navigation works |

### FR-2: Web Performance Testing

#### Performance Targets

| Metric | Target | How to Measure |
|--------|--------|---------------|
| Initial load time | < 10 seconds on broadband | Time from URL to interactive |
| FPS during simulation | 30+ FPS | Godot debug monitor or browser DevTools |
| FPS with 8 golfers + weather | 25+ FPS | Stress scenario |
| Memory usage after 1 hour | < 500MB | Browser DevTools memory tab |
| Memory growth per day | Stable (no leak) | Compare memory at Day 1 vs. Day 100 |

#### Performance Test Scenarios

| # | Scenario | Measure |
|---|----------|---------|
| 1 | Empty new game, build mode | Baseline FPS |
| 2 | 9-hole course, 8 golfers, weather active | Typical gameplay FPS |
| 3 | 18-hole course, max golfers, Ultra speed | Maximum stress FPS |
| 4 | 100-day fast-forward at Ultra speed | Memory stability, no leak |
| 5 | Open all UI panels simultaneously | UI rendering performance |
| 6 | Rapid zoom in/out (scroll wheel) | No stuttering or lag |

### FR-3: Web Audio Testing

Browsers enforce autoplay policies — audio must start after a user gesture.

| Test | Expected |
|------|----------|
| Page load | No audio until first click/interaction |
| First click (start game) | Ambient audio begins |
| SFX (golf swing, ball impact) | Play correctly when triggered |
| Weather audio (rain) | Activates when weather changes |
| Volume sliders in Settings | Affect audio levels in real-time |
| Mute All toggle | Silences everything; unmute restores |
| Tab away and return | Audio resumes (or re-triggers on interaction) |

### FR-4: Web Save/Load Testing

Browser saves use IndexedDB (Godot's `user://` maps to IndexedDB in web builds).

| Test | Expected |
|------|----------|
| Save game | Data persists (verify in DevTools → Application → IndexedDB) |
| Refresh page → Load game | Save data present and loadable |
| Close tab → Reopen → Load | Save data persists across tab sessions |
| Clear browser data → Load | Save data lost (expected); graceful "no saves found" |
| Save 5 separate save files | All appear in load list; all loadable |
| Auto-save at end of day | Auto-save file created; appears in load list |
| Private/Incognito browsing | Save works during session; lost on window close (expected browser behavior) |

### FR-5: Desktop Build Testing

#### Windows
- [ ] `.exe` launches without errors
- [ ] Play for 10 minutes — no crashes
- [ ] Save/load works (verify save location: `%APPDATA%/Godot/app_userdata/OpenGolfTycoon/`)
- [ ] Audio works
- [ ] All keyboard shortcuts work

#### macOS
- [ ] `.app` bundle launches (may require Gatekeeper bypass: right-click → Open)
- [ ] Document Gatekeeper workaround in README
- [ ] Play for 10 minutes — no crashes
- [ ] Save/load works (verify save location: `~/Library/Application Support/Godot/app_userdata/OpenGolfTycoon/`)

#### Linux
- [ ] Binary launches without missing dependencies
- [ ] Play for 10 minutes — no crashes
- [ ] Save/load works (verify save location: `~/.local/share/godot/app_userdata/OpenGolfTycoon/`)

### FR-6: CI/CD Pipeline Verification

| Test | Expected |
|------|----------|
| Trigger workflow via `workflow_dispatch` | All 4 platforms export successfully |
| Web build deploys to Cloudflare | Accessible at configured URL |
| Desktop builds upload to R2 | Download links work |
| Create a `v*` tag | Full export + release + deploy pipeline runs |
| Release artifacts | All 4 platform ZIPs present in GitHub Release |

### FR-7: Distribution & Landing

#### Beta Landing Page / README
- Clear "Beta — Expect Bugs" labeling
- Link to web build URL
- Desktop download links (Windows, macOS, Linux)
- Minimum system requirements:
  - Web: Modern browser (Chrome/Firefox/Safari), WebGL 2.0 support
  - Desktop: Any modern OS, 200MB disk space, integrated GPU or better
- Known issues list
- Feedback channel (GitHub Issues link)

#### macOS Gatekeeper Instructions
Document in README:
```
macOS users: The app is not code-signed. To open:
1. Right-click the .app file
2. Select "Open" from the context menu
3. Click "Open" in the security dialog
This is only required the first time.
```

---

## Acceptance Criteria

- [ ] Web build loads in Chrome, Firefox, Safari within 10 seconds
- [ ] All keyboard shortcuts work in web build (no browser shortcut conflicts)
- [ ] Save/load works in web build (persists across browser refresh)
- [ ] Audio plays in web build after first user interaction
- [ ] 30+ FPS in web build during active simulation (9-hole, 8 golfers)
- [ ] No memory leak over 100-day fast-forward session
- [ ] Desktop builds launch on Windows, macOS, Linux without errors
- [ ] CI/CD pipeline successfully produces all 4 export targets
- [ ] Web build deployed and accessible at public URL
- [ ] Desktop builds available as downloads
- [ ] Beta README/landing page with play instructions, system requirements, and known issues
- [ ] All Milestone 1–6 features verified working in web build

---

## Out of Scope

- Mobile browser support (touch controls not implemented)
- Offline/PWA support (service worker caching)
- Steam or itch.io distribution (post-beta)
- Code signing for desktop builds (post-beta)
- Automated cross-browser testing (manual testing only)
- Performance optimization beyond identifying bottlenecks (optimization is a separate effort)

---

## Dependencies

- All gameplay milestones (1–6) should be complete before final web/desktop QA
- CI/CD pipeline must be functional (currently working)
- Cloudflare account and secrets must be configured (currently working)

---

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Web build has browser-specific rendering bugs | Medium | Medium | Test all 3 browsers; document known issues |
| IndexedDB save fails silently in some browsers | Low | High | Test save/load explicitly; add error handling toast |
| Audio doesn't work in Safari | Medium | Medium | Safari has strict autoplay policies; test and document |
| Large terrain grid causes WebGL memory pressure | Low | High | Monitor memory in DevTools; reduce overlay count if needed |
| Godot 4.6 web export has upstream bugs | Low | High | Check Godot issue tracker; document workarounds |
| Desktop macOS build blocked by Gatekeeper | Certain | Low | Document workaround in README; provide clear instructions |

---

## Browser-Specific Known Issues to Watch For

| Browser | Potential Issue | Check |
|---------|----------------|-------|
| Chrome | SharedArrayBuffer requires cross-origin isolation headers | Verify `wrangler.toml` or Cloudflare headers |
| Firefox | WebGL context loss on tab switch | Test tab-away and return behavior |
| Safari | WebAudio context requires user gesture to resume | Test audio after tab-away |
| Safari | CSS `overflow: hidden` doesn't prevent elastic scrolling | Already handled in custom_shell.html |
| All | Ctrl+W closes tab (can't intercept) | Document in known issues; game auto-saves daily |

---

## Estimated Effort

- Web build testing (3 browsers × feature matrix): 4–6 hours
- Performance testing: 1–2 hours
- Audio testing: 30 minutes
- Save/load testing: 1 hour
- Desktop build testing (3 platforms): 2–3 hours
- CI/CD verification: 30 minutes
- Beta README/landing page: 1–2 hours
- Bug fixes (browser-specific): 2–6 hours (variable)
- **Total: 12–22 hours**
