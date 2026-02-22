# Algorithm Documentation

Reference documentation for all simulation algorithms in OpenGolf Tycoon. Each document has two sections:

1. **Plain English** — What the algorithm does and why it works that way
2. **Algorithm** — The actual math, formulas, constants, and code

Every document also includes a **Tuning Levers** table at the bottom listing all configurable parameters, their locations, current values, and what changing them does.

## Documents

### Core Golf Simulation
- [Shot Accuracy & Angular Dispersion](shot-accuracy.md) — How shots miss: gaussian angular error, hook/slice tendency, shanks, distance loss
- [Putting System](putting-system.md) — Make rates (exponential decay), miss characteristics, green reading
- [Shot AI & Target Finding](shot-ai-target-finding.md) — Club selection, multi-shot planning, wind compensation, recovery mode, risk analysis
- [Ball Physics & Rollout](ball-physics.md) — Flight arc animation, rollout mechanics, backspin, slope effects, terrain interaction
- [Wind System](wind-system.md) — Daily wind generation, hourly drift, crosswind displacement, distance modifiers
- [Weather System](weather-system.md) — State machine transitions, spawn/accuracy modifiers, seasonal weights

### Course Design
- [Difficulty Calculator](difficulty-calculator.md) — Per-hole difficulty from hazards, elevation, doglegs, green size, landing zones
- [Course Rating (Stars)](course-rating.md) — 4-category weighted rating: condition, design, value, pace. Slope and course rating

### Economy & Progression
- [Economy & Financial System](economy.md) — Green fees, operating costs, loans, staff tiers, profit calculation
- [Reputation System](reputation.md) — Daily decay, per-golfer mood-based gains, tournament bonuses, prestige multiplier
- [Golfer Spawning & Tier System](golfer-spawning.md) — Spawn rates, tier selection weights, group sizes, landing zone safety
- [Satisfaction & Feedback](satisfaction-feedback.md) — Thought bubble triggers, price sensitivity, daily satisfaction metric
- [Golfer Needs](golfer-needs.md) — Energy, comfort, hunger, pace needs that decay over time and are satisfied by buildings

### Events & Time
- [Tournament System](tournament-system.md) — 4 tiers, qualification, scheduling, live scoring, revenue/reputation rewards
- [Day/Night Cycle](day-night-cycle.md) — Time progression, sunrise/sunset tinting, weather tint blending, course hours

## How to Use for Tuning

1. Find the algorithm you want to tune in the list above
2. Read the "Plain English" section to understand what it does
3. Look at the "Algorithm" section for the exact formulas
4. Check the "Tuning Levers" table for the parameter, its file location, and current value
5. Edit the tuning lever values in this document to describe your desired change
6. Have Claude update the code to match

## System Interactions

Many algorithms feed into each other. Key dependency chains:

```
Course Rating ← Difficulty Calculator + Terrain + Stats + Pricing
     ↓
Golfer Spawning ← Course Rating + Reputation + Weather + Season
     ↓
Golfer Play ← Shot AI → Shot Accuracy → Ball Physics → Rollout
     ↓
Golfer Needs ← Holes Played + Wait Time + Buildings (energy/comfort/hunger/pace)
     ↓
Satisfaction ← Feedback Triggers ← Scoring + Pricing + Needs
     ↓
Reputation ← Satisfaction + Tier + Prestige Multiplier
     ↓
(feeds back into Course Rating via Value Rating)
```
