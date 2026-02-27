# Phase 3 Verification & Documentation Sync — Product Spec

**Author:** Claude (Product)
**Date:** 2026-02-27
**Status:** Proposal
**Milestone:** Beta Milestone 1
**Priority:** P0 — Housekeeping
**Est. Scope:** Small

---

## Problem Statement

Phase 3 systems (Land Purchase, Staff Management, Marketing) were implemented and integrated into the game, but the project documentation still marks Phase 3 as "Pending." This documentation drift creates two risks:

1. **Wasted effort** — A developer reads DEVELOPMENT_MILESTONES.md, sees Phase 3 as incomplete, and spends time re-implementing or investigating features that already work.
2. **Unverified integration** — The three systems were wired into `main.gd`, end-of-day processing, save/load, and the financial summary individually, but their combined interaction hasn't been manually verified in a real play session. Edge cases at the seams (e.g., firing staff while marketing campaigns are active, buying land while near bankruptcy) may harbor bugs.

This milestone is a prerequisite gate: verify what exists, fix what's broken, align the docs, then move forward confidently.

---

## Background

### Current Implementation

Code exploration confirms all three Phase 3 systems are present and integrated:

| System | Script | Integration Points |
|--------|--------|--------------------|
| **LandManager** | `scripts/managers/land_manager.gd` | 40×40 starting plot, 6×6 parcel grid, progressive pricing ($5,000 base + 30% escalation), adjacent-only purchases, boundary enforcement, terrain tools blocked on unowned land |
| **StaffManager** | `scripts/managers/staff_manager.gd` | 4 staff types (Groundskeeper, Marshal, Cart Operator, Pro), hire/fire, course condition tracking, daily payroll integration |
| **MarketingManager** | `scripts/managers/marketing_manager.gd` | 5 channels, campaign duration/cost, diminishing returns, spawn rate modifiers |

All three are:
- Instantiated in `main.gd` `_ready()`
- Processed in end-of-day calculations
- Serialized/deserialized in `SaveManager`
- Reflected in the financial summary panel

### Documentation Gap

`DEVELOPMENT_MILESTONES.md` shows Phase 3 as "Pending." The README does not mention land expansion, staff management, or marketing as implemented features.

---

## User Stories

1. **As a developer**, I want the milestones doc to accurately reflect what's implemented, so I don't waste time re-implementing existing features.
2. **As a playtester**, I want to verify that land purchase, staff hiring, and marketing campaigns all work correctly in a real play session.
3. **As a contributor**, I want the README to list all implemented features so I can assess the project's scope before contributing.

---

## Functional Requirements

### FR-1: Manual Verification Protocol

Play through a full 10-day session exercising all Phase 3 features. Each action must be verified as working correctly:

#### Land Purchase Verification
- [ ] Purchase at least 2 land parcels from the Land panel
- [ ] Verify progressive pricing is applied (second parcel costs more than first)
- [ ] Verify only parcels adjacent to owned land are available for purchase
- [ ] Verify terrain tools (paint, elevation, hole creation) are blocked on unowned tiles
- [ ] Verify terrain tools work normally on newly purchased land
- [ ] Verify land ownership boundaries are visually indicated on the map
- [ ] Verify land purchase cost appears in the financial summary

#### Staff Management Verification
- [ ] Hire at least 1 of each staff type (Groundskeeper, Marshal, Cart Operator, Pro)
- [ ] Verify daily payroll appears in end-of-day summary as an expense line item
- [ ] Verify Groundskeeper affects course condition rating
- [ ] Verify firing a staff member stops their payroll immediately
- [ ] Verify staff count persists across save/load
- [ ] Verify staff panel displays all hired staff with their roles and daily cost

#### Marketing Campaign Verification
- [ ] Launch at least 2 marketing campaigns on different channels
- [ ] Verify campaign duration counts down correctly day by day
- [ ] Verify spawn rate increases while campaigns are active
- [ ] Verify campaigns expire when their duration ends
- [ ] Verify campaign costs appear in end-of-day financial summary
- [ ] Verify diminishing returns: a second campaign on the same channel produces less effect
- [ ] Verify active campaigns persist across save/load

#### Cross-System Integration
- [ ] Save game with all Phase 3 features active (owned land, hired staff, running campaigns)
- [ ] Quit to main menu and reload — verify all Phase 3 state persists correctly
- [ ] Verify financial summary shows combined costs: operating + staff payroll + marketing + maintenance
- [ ] Verify no crashes when firing all staff during simulation
- [ ] Verify no crashes when marketing campaigns expire during simulation

### FR-2: Documentation Updates

#### DEVELOPMENT_MILESTONES.md
- Mark Phase 3 as ✅ COMPLETE
- List completed deliverables under Phase 3:
  - Land Purchase system (parcel grid, progressive pricing, boundary enforcement)
  - Staff Management (4 types, hire/fire, condition tracking, payroll)
  - Marketing (5 channels, campaigns, spawn rate modifiers)
- Update Phase 3 summary table from "Pending" to "✅ Complete"

#### README.md
- Add land expansion, staff management, and marketing to the features list
- Ensure feature descriptions match actual implementation (not aspirational)

#### CLAUDE.md
- Verify the project structure section includes references to Phase 3 managers
- Verify the architecture section mentions Phase 3 systems under Manager pattern

### FR-3: Bug Fixes

Any bugs discovered during verification should be:
1. Documented with reproduction steps
2. Fixed in this milestone (if small: <1 hour)
3. Deferred with a note (if large: >1 hour) to Milestone 6 (Bug Bash)

---

## Acceptance Criteria

- [ ] All verification checkboxes in FR-1 pass without bugs or crashes
- [ ] `DEVELOPMENT_MILESTONES.md` shows Phase 3 as complete with deliverables listed
- [ ] `README.md` mentions land expansion, staff management, and marketing as implemented
- [ ] Any bugs found during verification are fixed or documented with deferral notes
- [ ] Save/load round-trip with all Phase 3 features active produces identical game state

---

## Out of Scope

- New features for Phase 3 systems (e.g., staff skill levels, new marketing channels, land terrain presets)
- Automated test coverage for Phase 3 systems (deferred to Milestone 6)
- Balance tuning of Phase 3 values (deferred to Milestone 4)

---

## Dependencies

- None — this is the first milestone and prerequisite for all others

---

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Phase 3 systems have subtle integration bugs | Medium | Low | Manual verification protocol covers key interactions |
| Documentation updates miss some references | Low | Low | Grep for "Phase 3", "land", "staff", "marketing" across all .md files |
| Bugs found require more than small fixes | Low | Medium | Defer to Milestone 6 if >1 hour fix; document clearly |

---

## Estimated Effort

- Manual verification: 1–2 hours of gameplay
- Documentation updates: 30 minutes
- Bug fixes (if any): 0–2 hours
- **Total: 2–4 hours**
