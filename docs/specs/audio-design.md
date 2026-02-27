# Audio Design Document — Product Spec

**Author:** Claude (Product)
**Date:** 2026-02-27
**Status:** Proposal
**Priority:** MEDIUM
**Version:** 0.1.0-alpha context

---

## Problem Statement

The audio system is fully built. `SoundManager` (602 LOC) manages a 6-slot SFX pool, 3 ambient tracks (wind, rain, birds), and volume control. `ProceduralAudio` synthesizes every sound mathematically — swing whooshes, impact thuds, bunker crunches, water splashes, cup rattles, record chimes, 6 bird species, wind noise, and rain ambience. All at 44,100 Hz with no external audio files.

But `is_muted = true` by default. The audio was turned off because the quality was deemed insufficient for a good player experience. No spec exists for what "good enough" means, what the path to enabling audio is, or whether the pure-procedural approach should be supplemented with recorded samples.

The goal is clear: **audio defaults to ON** in the next release.

---

## Design Principles

- **Audio should enhance, not distract.** Bad audio is worse than no audio. The bar is "does this make the game better?"
- **Procedural-first.** The zero-dependency, zero-download-size procedural approach is a project strength. Only supplement with samples if procedural quality can't meet the bar.
- **Spatial awareness.** Sounds should communicate game state — hearing a distant splash tells you someone hit water without looking. Hearing birds means good weather.
- **Web-first.** Browser autoplay restrictions mean audio must be gated behind user interaction. This is a technical requirement, not a design choice.

---

## Current System Analysis

### SoundManager Architecture
- **SFX pool**: 6 `AudioStreamPlayer` instances for one-shot sounds
- **Ambient tracks**: 3 separate looping players for wind, rain, birds
- **Cooldowns**: Swing (0.3s), impact (0.2s) prevent sound spam
- **Distance culling**: Sounds fade based on screen distance from camera center
- **Off-screen culling**: Golfers off-screen don't play swing sounds
- **Volume levels**: Master 0.8, SFX 1.0, Ambient 0.6
- **Mute signal**: `mute_state_changed(muted: bool)` for UI sync

### ProceduralAudio Synthesis
| Sound | Technique | Current Quality |
|-------|-----------|----------------|
| Driver swing | Layered whoosh + high-freq crack | Decent — recognizable as a golf swing |
| Iron swing | Shorter, sharper whoosh | Decent |
| Putter swing | Soft click | Good — subtle and appropriate |
| Fairway impact | Thud (sine + decay) | OK — generic |
| Green landing | Crisp thud variant | OK |
| Bunker impact | Muffled crunch + scatter noise | Good — distinctive |
| Water splash | Noise burst + bubbling tail | Good — clearly water |
| Cup rattle | Metallic rattle + descending pitch | Good — satisfying |
| Record chime | C major arpeggio (C5, E5, G5, C6) | Good — celebratory |
| Wind ambient | Filtered noise with slow modulation | OK — steady, needs gusting |
| Rain ambient | Filtered noise (lower freq) | OK — monotone |
| Bird calls (6 species) | Multi-harmonic oscillators + vibrato | Mixed — robin/cardinal good, sparrow/wren need work |
| UI click | 1000 Hz sine burst | Good |

### Known Issues
1. **Swing sounds lack punch.** The whoosh is present but the "crack" of club-on-ball is weak. Real golf swings have a sharp transient at impact.
2. **Impact sounds are too similar.** Fairway, rough, and green landings sound nearly identical. Terrain distinction is muddled.
3. **Wind doesn't gust.** The ambient wind loop is a steady filtered noise. Real wind has dynamic gusting that correlates with in-game wind speed.
4. **Rain lacks variation.** Light rain and heavy rain have different volume but similar timbre. Heavy rain should have droplet impacts and thunder.
5. **Bird calls fire randomly.** They should correlate with time of day (dawn/dusk chorus) and weather (suppressed in rain — partially implemented).
6. **No crowd/applause sounds.** Tournament play has no ambient crowd noise.
7. **No building proximity sounds.** Walking past the restaurant should have subtle kitchen/dining ambience.

---

## Audio Quality Targets

### Tier 1: Must Fix (Required for audio-on default)

**1.1 Swing impact transient**
- Add a sharp 0.5ms noise burst at the moment of club-ball contact
- Layer on top of the existing whoosh
- Different timbre per club: Driver (deep thump), Iron (sharp crack), Wedge (clean click)
- Reference: The "thwack" of a well-struck iron — the most satisfying sound in golf

**1.2 Terrain-distinct impact sounds**
- Fairway: Firm thud with brief grass rustle (noise tail, 50ms)
- Rough: Muffled thud with longer grass rustle (100ms)
- Bunker: Existing is good — keep it
- Water: Existing is good — keep it
- Green: Soft, higher-pitched landing (existing is close)

**1.3 Wind gusting**
- Modulate wind noise amplitude with a slow sine wave (period 4–8s)
- Gust intensity proportional to `WindSystem` speed
- Add occasional sharp gust peaks (2× amplitude for 0.5s, random interval 15–30s)
- At high wind (>20 mph): add a low-frequency moan (80–120 Hz filtered noise)

**1.4 Browser autoplay handling**
- On web build: start with audio muted
- Show unobtrusive "Click to enable audio" prompt on first user interaction
- After any click/key press, unmute and play a subtle test tone (chime at 20% volume)
- Store audio preference in localStorage to persist across sessions

### Tier 2: Should Fix (Significant quality improvement)

**2.1 Rain variation**
- Light rain: Gentle patter (randomized impulses at 5–15 Hz)
- Rain: Steady patter (15–30 Hz impulses) + underlying noise
- Heavy rain: Dense patter (30+ Hz) + low rumble + occasional thunder crack
- Thunder: Low-frequency impulse (40–80 Hz) with long decay (2–3s)

**2.2 Bird call timing**
- Dawn (6–8 AM): Increased bird activity (2× frequency, multiple species)
- Midday (11 AM–2 PM): Reduced activity (0.5× frequency)
- Dusk (5–7 PM): Evening chorus (1.5× frequency)
- Night (8 PM+): Silent
- Rain: Suppress birds entirely (already partially implemented)

**2.3 Improved sparrow and wren calls**
- Sparrow: Add slight frequency wobble between chips (current is too mechanical)
- Wren: Slow down trill slightly, add more harmonic richness (second overtone)

**2.4 Putt roll sound**
- While ball is rolling on green: soft continuous rumble (low-pass filtered noise)
- Duration proportional to putt distance
- Volume proportional to ball speed (fades as ball decelerates)

### Tier 3: Nice to Have (Polish)

**3.1 Crowd/applause for tournaments**
- Background murmur: Low filtered noise at very low volume (−20 dB from SFX)
- Applause on birdie/eagle: 1–2s burst of broadband noise shaped like clapping
- Louder applause for hole-in-one

**3.2 Building proximity ambience**
- Restaurant: Quiet dining sounds (utensil clinks, murmur) at −25 dB
- Pro Shop: Register chime
- Snack Bar: Cash register + light chatter
- Trigger radius: 3 tiles from building center
- Only audible in follow mode or when camera is close

**3.3 Ball-in-cup enhancement**
- Add a brief "crowd gasp → cheer" pattern after hole-in-one cup sound
- For eagle: lighter applause
- For normal holes: keep existing cup rattle only

---

## Decision: Procedural vs. Hybrid

### Recommendation: Stay Procedural (Improved)

**Rationale:**
1. The procedural system already produces 80% quality sounds. The gap is specific weaknesses (impact transients, wind dynamics), not systemic failure.
2. Zero external assets keeps the web build tiny (~2 MB total) — adding samples could double the download.
3. The ProceduralAudio class is well-structured for enhancement. Adding a noise burst or modifying an envelope is a few lines of code, not an asset pipeline.
4. All 6 bird species are already recognizable. The sparrow and wren just need parameter tuning.
5. The project philosophy ("zero external assets") is a unique strength. Maintaining it differentiates the game.

**If procedural falls short:** Consider hybrid for exactly 3 sounds:
- Club-ball impact transient (real golf impact is very hard to synthesize convincingly)
- Thunder crack (explosive transients are difficult procedurally)
- Crowd applause (broadband organic sounds)

Even these could potentially be improved procedurally — try procedural fixes first, hybrid only as fallback.

**Sample sourcing (if needed):** CC0-licensed sounds from Freesound.org or similar. Keep to <500KB total. MIT-compatible license required.

---

## Volume Mixing

### Reference levels (relative to master):

| Category | Volume | Notes |
|----------|--------|-------|
| Master | 0.8 | User-adjustable |
| SFX - Swing | 1.0 | Primary gameplay feedback |
| SFX - Impact | 0.9 | Slightly below swing (arrival, not departure) |
| SFX - Cup/Hole | 1.0 | Rewarding, full volume |
| SFX - Penalty | 0.85 | Water splash — noticeable but not jarring |
| SFX - UI | 0.6 | Subtle clicks, non-intrusive |
| Ambient - Wind | 0.5 | Background texture, not foreground |
| Ambient - Rain | 0.6 | Higher than wind (rain is more present) |
| Ambient - Birds | 0.35 | Barely noticeable — subliminal nature feel |
| Ambient - Crowd | 0.25 | Tournament only — distant murmur |
| SFX - Record/Chime | 1.0 | Celebratory, full presence |

### Spatial attenuation:
- Sounds at camera center: full volume
- Sounds at screen edge: 70% volume
- Sounds 1 screen-width away: 30% volume
- Sounds beyond 1.5 screen-widths: culled (not played)

### Follow mode adjustment:
When following a golfer (Spectator Camera spec), the followed golfer's sounds play at full volume. Other golfers' sounds are reduced to 50% of distance-attenuated level.

---

## Settings UI

### Audio settings panel:

```
┌─────────────────────────────┐
│  AUDIO SETTINGS             │
│                             │
│  Master Volume    [====--]  │
│  SFX Volume       [=====]   │
│  Ambient Volume   [===---]  │
│                             │
│  [x] Enable Audio           │
│  [ ] Mute when unfocused    │
│                             │
│  [Apply]  [Defaults]        │
└─────────────────────────────┘
```

- Volume sliders: 0% to 100% in 5% increments
- "Enable Audio" checkbox replaces the current `is_muted` toggle
- "Mute when unfocused" — pause audio when browser tab is backgrounded (web build)
- Settings persisted to `user://settings.json`

---

## Implementation Sequence

```
Phase 1 (Critical Fixes — Required for Audio ON):
  1. Swing impact transient (sharp noise burst per club type)
  2. Terrain-distinct impact sounds (fairway/rough/green differentiation)
  3. Wind gusting dynamics (sine modulation + gust peaks)
  4. Browser autoplay gate (click-to-enable, localStorage persistence)
  5. Set is_muted = false as default
  6. QA pass: play 30 minutes with audio on, note anything annoying

Phase 2 (Quality Improvements):
  7. Rain variation (light/medium/heavy with impulse patter)
  8. Bird call timing (dawn/dusk chorus, midday reduction)
  9. Sparrow and wren call improvements
  10. Putt roll sound

Phase 3 (Polish):
  11. Tournament crowd ambience (if tournament spec is implemented)
  12. Building proximity sounds (follow mode only)
  13. Ball-in-cup celebration enhancement
  14. Audio settings panel UI
  15. Mute-when-unfocused for web build

Phase 4 (Hybrid Fallback — Only If Needed):
  16. Evaluate: do Tier 1 improvements sound good enough?
  17. If not: source CC0 samples for impact transient, thunder, applause
  18. Integrate sample playback alongside procedural system
```

---

## Success Criteria

The single success metric: **`is_muted = false` ships as default and nobody turns it off in the first 5 minutes of play.**

Specific criteria:
- Swing sounds have a satisfying impact "crack" that varies by club
- Fairway, rough, and green landings sound distinctly different
- Wind ambient dynamically gusts and matches the displayed wind speed
- Rain intensity is audible (can tell light rain from heavy rain without looking)
- Bird calls are pleasant background texture, not annoying or mechanical
- Web build handles autoplay correctly (no errors, clean enable flow)
- Volume levels are balanced (no single sound overwhelms others)
- Audio settings are persistent across sessions

---

## Out of Scope

| Feature | Reason |
|---------|--------|
| Background music / soundtrack | Intentionally music-free design — ambient nature sounds are the soundtrack |
| Voice acting / commentary | No dialogue system; text-only game |
| 3D positional audio | 2D game — screen-space attenuation is sufficient |
| Dynamic music system | No music at all by design |
| MIDI / instrument synthesis | Golf doesn't need musical instruments |
| Audio for menu navigation | UI clicks are sufficient; no menu music planned |
