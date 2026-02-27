# Web Build & Distribution — Product Spec

**Author:** Claude (Product)
**Date:** 2026-02-27
**Status:** Proposal
**Priority:** MEDIUM-LOW (spec) / HIGH (execution)
**Version:** 0.1.0-alpha context

---

## Problem Statement

The web build is the primary distribution channel — zero install friction, instant play, cross-platform. The CI/CD pipeline (`export-game.yml`) already exports to web and deploys to Cloudflare Workers. A custom HTML shell (`web/custom_shell.html`) handles cross-origin isolation, input blocking, and a golf-themed loading screen.

However, there is no quality bar defined for the web experience. Browser compatibility is untested beyond Chrome. IndexedDB save persistence is unvalidated. Audio autoplay handling exists in the code but has no acceptance criteria. Performance targets are assumed, not measured. The landing page is a raw Godot canvas with no context for first-time visitors.

This spec defines the quality bars, test plans, and distribution infrastructure for a public web beta.

---

## Design Principles

- **First impression matters.** A visitor's first 10 seconds determine whether they play or leave. The loading experience, landing page, and initial performance set expectations.
- **Saves must be reliable.** Losing a multi-hour save file to browser storage eviction is unacceptable. Players need to trust that their progress persists.
- **Performance over features.** If a feature causes the web build to drop below 30 FPS, it gets cut from the web build, not the frame rate target.
- **Progressive enhancement.** The game should work in the most common browser scenario first, then add features for browsers that support them.

---

## Current System Analysis

### Web Export Infrastructure
- **Godot 4.6**: Export target configured in `export_presets.cfg`
- **Renderer**: Forward+ (web variant with lighter shaders)
- **Custom shell**: `web/custom_shell.html` with:
  - Full-screen WebGL 2.0 canvas
  - Service worker for cross-origin isolation headers
  - Input blocking (right-click, scroll zoom, Tab, F1–F3)
  - Dark green golf-themed loading screen with SVG logo
  - Progress bar during WASM module load
  - Fallback notice if SharedArrayBuffer/Workers unavailable
- **Deployment**: Cloudflare Workers via GitHub Actions on version tags

### Save System
- `SaveManager` uses `FileAccess` which maps to IndexedDB on web
- Auto-saves on day change
- JSON format (versioned, v2)
- Save file location: `user://saves/` → IndexedDB virtual filesystem

### Audio
- `SoundManager.is_muted = true` by default
- `ProceduralAudio` generates all sounds at runtime (no asset download)
- No browser autoplay gate implemented yet

---

## Feature Design

### 1. Browser Compatibility Matrix

Define and test supported browsers:

| Browser | Version | Priority | Status |
|---------|---------|----------|--------|
| Chrome (Desktop) | 110+ | P0 | Primary development target |
| Firefox (Desktop) | 115+ | P0 | Must work |
| Safari (Desktop) | 16+ | P1 | Should work |
| Edge (Desktop) | 110+ | P0 | Chromium-based, same as Chrome |
| Chrome (Android) | 110+ | P2 | Nice to have |
| Safari (iOS) | 16+ | P2 | Nice to have, known WebGL issues |

**Known browser-specific issues to test:**
- **Firefox**: SharedArrayBuffer requires cross-origin isolation headers (already handled by service worker)
- **Safari**: WebGL 2.0 support varies by version. `OffscreenCanvas` not supported in older versions. Audio context requires user interaction.
- **Mobile browsers**: Touch input not supported (out of scope), but the page should load and display a "Desktop recommended" message.

**Test protocol per browser:**
1. Page loads without console errors
2. Loading progress bar displays and completes
3. Main menu renders correctly
4. New game starts and terrain renders
5. Save/load cycle works (save, refresh, load)
6. Audio enables on click (when audio is enabled)
7. 30+ FPS with 4 golfers on a 3-hole course
8. No input capture issues (scrolling, right-click, keyboard shortcuts)

---

### 2. IndexedDB Save Reliability

**Persistence concerns:**
| Scenario | Risk | Mitigation |
|----------|------|------------|
| Normal browsing | Low | IndexedDB persists across sessions |
| Private/incognito browsing | High | Data cleared on window close |
| Browser storage pressure | Medium | IndexedDB may be evicted by browser |
| Cross-origin isolation | Low | Service worker already handles this |
| Multiple tabs | Medium | Concurrent writes could corrupt saves |

**Mitigations:**

**2.1 Private browsing detection:**
```javascript
// In custom shell, detect private browsing and warn
try {
    const db = indexedDB.open('test');
    db.onerror = function() {
        showWarning("Private browsing detected. Your saves will not persist after closing this tab.");
    };
} catch(e) {
    showWarning("Storage unavailable.");
}
```

**2.2 Storage persistence API:**
Request persistent storage to prevent browser eviction:
```javascript
if (navigator.storage && navigator.storage.persist) {
    navigator.storage.persist().then(function(persistent) {
        if (!persistent) {
            console.log("Storage may be evicted under pressure");
        }
    });
}
```

**2.3 Storage quota monitoring:**
Display available storage in the save/load UI:
```javascript
if (navigator.storage && navigator.storage.estimate) {
    navigator.storage.estimate().then(function(estimate) {
        var usedMB = (estimate.usage / 1024 / 1024).toFixed(1);
        var totalMB = (estimate.quota / 1024 / 1024).toFixed(0);
        // Display: "Storage: 2.3 MB / 100 MB"
    });
}
```

**2.4 Multi-tab protection:**
Use `BroadcastChannel` to prevent concurrent game sessions:
```javascript
const channel = new BroadcastChannel('opengolf-tycoon');
channel.postMessage('active');
channel.onmessage = function(e) {
    if (e.data === 'active') {
        showWarning("Another tab is running OpenGolf Tycoon. Multiple tabs may corrupt save data.");
    }
};
```

**2.5 Save export/import:**
Allow manual save backup as a JSON file download:
- "Export Save" button in save/load panel → downloads `course_name_day_N.json`
- "Import Save" button → file picker to upload JSON save file
- This is the ultimate fallback for save reliability concerns

---

### 3. Audio Autoplay Handling

Browsers require user interaction before playing audio. Implementation plan:

**User interaction gate:**
```javascript
// In custom shell
var audioEnabled = false;
var audioPromptShown = false;

function enableAudio() {
    if (audioEnabled) return;
    audioEnabled = true;
    // Resume AudioContext
    if (window.Godot && window.Godot.audio) {
        window.Godot.audio.ctx.resume();
    }
    hideAudioPrompt();
    localStorage.setItem('audio_enabled', 'true');
}

// Show subtle prompt after game loads
function showAudioPrompt() {
    if (localStorage.getItem('audio_enabled') === 'true') {
        // User previously enabled audio — auto-enable on first interaction
        document.addEventListener('click', enableAudio, { once: true });
        document.addEventListener('keydown', enableAudio, { once: true });
        return;
    }
    // First-time visitor: show prompt
    audioPromptShown = true;
    // Small banner at top: "🔊 Click anywhere to enable audio"
}
```

**Audio prompt UI:**
- Small, non-intrusive banner at the top of the canvas
- Dark background, white text: "Click anywhere to enable audio"
- Disappears after first click/keypress
- Remembers preference via localStorage
- If user previously enabled audio, auto-enables on first interaction without showing banner

---

### 4. Performance Targets

**Frame rate targets:**
| Scenario | Target FPS | Test Configuration |
|----------|-----------|-------------------|
| Main menu | 60 FPS | Static screen |
| 3-hole course, 0 golfers | 60 FPS | Terrain rendered, no simulation |
| 9-hole course, 4 golfers | 30 FPS | Normal gameplay |
| 18-hole course, 8 golfers | 30 FPS | Full course, max concurrent |
| 18-hole course, 8 golfers, all overlays | 25 FPS | Worst case |
| Tournament, 8 live golfers + leaderboard | 30 FPS | Tournament play |

**Test hardware baseline:**
- "Mid-range laptop" = Intel i5 (2020+) or equivalent, integrated graphics, 8GB RAM
- Chrome latest stable on Windows/macOS/Linux
- 1080p display

**Performance monitoring:**
Add a debug FPS counter (togglable via settings or hidden key combo):
```gdscript
# In main.gd or HUD
if OS.has_feature("web"):
    var fps_label = Label.new()
    fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
    # Update every 0.5s to avoid layout thrash
```

**Performance optimization levers (web-specific):**
1. `DayNightSystem` already throttles to 10 FPS on web
2. Overlay rendering: skip overlays not visible in viewport
3. Golfer detail: reduce polygon count at zoom levels <0.7×
4. Water shimmer: reduce animation frequency on web (every 3rd frame)
5. Tileset resolution: consider 32×16 tiles instead of 64×32 for web (half resolution)

---

### 5. Custom HTML Shell Improvements

**5.1 Loading experience:**
```
┌─────────────────────────────────────────────────┐
│                                                  │
│            ⛳ OpenGolf Tycoon                    │
│                                                  │
│       Design. Build. Play.                       │
│                                                  │
│     [████████████░░░░░░░░] 62%                   │
│     Loading game engine...                       │
│                                                  │
│     v0.1.0-alpha                                 │
└─────────────────────────────────────────────────┘
```

Already partially implemented. Ensure:
- Progress bar is accurate (not stuck at 0% then jumping to 100%)
- Status text updates: "Downloading..." → "Initializing..." → "Starting..."
- Graceful error display if download fails

**5.2 Mobile detection:**
```javascript
if (/Mobi|Android|iPhone|iPad/i.test(navigator.userAgent)) {
    showMobileWarning("OpenGolf Tycoon is designed for desktop browsers. " +
                      "Touch input is not supported. " +
                      "For the best experience, visit on a computer.");
}
```

Show warning but don't block — let curious mobile users try.

**5.3 Minimum requirements check:**
```javascript
// Check WebGL 2.0 support
var canvas = document.createElement('canvas');
var gl = canvas.getContext('webgl2');
if (!gl) {
    showError("WebGL 2.0 is required. Please update your browser.");
    return;
}

// Check SharedArrayBuffer (needed for threads)
if (typeof SharedArrayBuffer === 'undefined') {
    showWarning("Multi-threading unavailable. Performance may be reduced.");
}
```

---

### 6. Landing Page

The URL that visitors first reach should provide context, not just dump them into a WebGL canvas.

**Landing page structure:**
```
┌──────────────────────────────────────────────────┐
│  ⛳ OpenGolf Tycoon          [Play Now]           │
│                                                   │
│  A SimGolf-inspired golf course tycoon game.      │
│  Design courses, attract golfers, host            │
│  tournaments, and build your reputation.          │
│                                                   │
│  ┌───────────────────────────────────┐            │
│  │                                   │            │
│  │      [Game Canvas / Screenshot]   │            │
│  │                                   │            │
│  └───────────────────────────────────┘            │
│                                                   │
│  Features:                                        │
│  • Design courses with 14 terrain types           │
│  • 10 unique course themes                        │
│  • Watch AI golfers play your creation             │
│  • Host tournaments at 4 tiers                     │
│  • Manage finances, staff, and reputation          │
│                                                   │
│  [GitHub] [MIT License] [v0.1.0-alpha]            │
└──────────────────────────────────────────────────┘
```

**Implementation options:**
1. **Above-the-fold approach**: Static HTML above the canvas with a "Play Now" button that initializes the Godot engine. Advantage: fast initial load, SEO-friendly context.
2. **Splash-and-redirect**: Separate landing HTML page that links to the game page. Advantage: clean separation.
3. **Integrated shell**: Enhance `custom_shell.html` to show landing content while the engine loads, then replace with canvas. Advantage: single page, content visible during load.

**Recommendation:** Option 3 (integrated shell). The loading screen already shows for 2–5 seconds — use that time to show game information. When engine is ready, fade the info and reveal the canvas.

---

### 7. Deployment & Versioning

**Cloudflare Workers deployment:**
- URL structure: `https://opengolf.example.com/` (root = latest version)
- Version archive: `https://opengolf.example.com/v/0.1.0/` (optional)
- Cache headers: WASM and JS files cacheable for 1 hour, HTML for 5 minutes
- Source maps: disabled in production builds

**Version display:**
- Show version number in bottom-left of loading screen
- Show version in main menu (already implemented)
- Show version in save file metadata (for debugging)

**Deployment pipeline (existing, verify):**
1. Tag version in git: `v0.1.0`
2. GitHub Actions triggers `export-game.yml`
3. Godot headless exports web build
4. Upload to Cloudflare Workers
5. Verify deployment (basic health check)

---

### 8. Analytics (Optional)

Minimal, privacy-respecting analytics for playtesting feedback:

**Track:**
- Session count (unique page loads)
- Play duration (time from game start to page unload)
- Browser/OS breakdown
- Error count (JavaScript console errors)

**Do NOT track:**
- Personal information
- Course designs or save data
- Keystroke or click patterns
- Any PII

**Implementation:** Lightweight, self-hosted analytics (e.g., Plausible, Umami) or Cloudflare Web Analytics (built-in, no tracking scripts). No third-party analytics services.

**Privacy policy:** If any analytics are added, display a brief notice: "Anonymous usage statistics are collected to improve the game. No personal data is stored."

---

## Implementation Sequence

```
Phase 1 (Quality Bars):
  1. Browser compatibility testing (Chrome, Firefox, Safari, Edge)
  2. Performance benchmarking per scenario
  3. IndexedDB save reliability testing
  4. Document known issues per browser

Phase 2 (Shell Improvements):
  5. Loading experience refinement (progress accuracy, status text)
  6. Mobile detection warning
  7. Minimum requirements check (WebGL 2.0, SharedArrayBuffer)
  8. Audio autoplay gate with localStorage persistence

Phase 3 (Save Reliability):
  9. Private browsing detection and warning
  10. Storage persistence API request
  11. Multi-tab protection (BroadcastChannel)
  12. Save export/import functionality

Phase 4 (Distribution):
  13. Landing page content in custom shell
  14. Deployment verification script
  15. Version display and cache configuration
  16. Analytics setup (optional)
```

---

## Success Criteria

- Game loads and plays correctly in Chrome, Firefox, Safari, and Edge (latest versions)
- Save/load cycle works reliably: save on day 10, refresh browser, load game, arrive at day 10
- Private browsing users see a warning about save persistence
- Audio enables cleanly after first user interaction (no errors, no unexpected sounds)
- 30 FPS maintained on mid-range laptop with 9 holes and 4 golfers
- Loading screen provides game context (not just a blank canvas with a spinner)
- Mobile visitors see a "desktop recommended" message
- Save export/import works as a fallback for save reliability

---

## Out of Scope

| Feature | Reason |
|---------|--------|
| Mobile/touch input | Fundamentally different input model — separate project |
| PWA / offline mode | Requires service worker caching of WASM — complex |
| Native app wrapper (Electron/Tauri) | Desktop exports already exist |
| Multiplayer/networking | Single-player game |
| Cloud save sync | Requires user accounts and backend infrastructure |
| CDN optimization / edge caching | Cloudflare Workers handles this inherently |
| A/B testing framework | Premature for alpha |
| SEO optimization | Game is not content-indexed; direct link sharing is sufficient |
