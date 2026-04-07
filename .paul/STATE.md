# STATE.md

## Current Position

Milestone: v0.1 Core Loop
Phase: 1 of 5 (Menu Bar Indicators) — Planning
Plan: 01-01 created, awaiting approval
Status: PLAN created, ready for APPLY
Last activity: 2026-04-07 — Created .paul/phases/01-menu-bar-indicators/01-01-PLAN.md

Progress:
- Milestone: [██░░░░░░░░] 20%
- Phase 1:   [░░░░░░░░░░] 0%

## Loop Position

```
PLAN ──▶ APPLY ──▶ UNIFY
  ✓        ○        ○     [Plan created, awaiting approval]
```

## Session Continuity

Last session: 2026-04-07
Stopped at: Plan 01-01 created
Next action: Approve plan, then run /paul:apply
Resume file: .paul/phases/01-menu-bar-indicators/01-01-PLAN.md

## Decisions

| # | Decision | Rationale |
|---|----------|-----------|
| 1 | Status indicators in menu bar (not notch pill) | Raycast-style — notch = eyes only |
| 2 | UserDefaults JSON for persistence (not CoreData yet) | Already built, migration deferred |
| 3 | PATs in Keychain | Security — never UserDefaults |
| 4 | Header badge pills in expanded view | Design from expanded.pen — 4 colored pill borders |
| 5 | Commit with `but commit` | GitButler manages this repo |
