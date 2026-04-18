# Project State

## Project Reference

See: apps/second-brain/README.md

**Core value:** Mini-Max stops being a passive tracker and starts saying something useful about what you're looking at.
**Current focus:** v0.2 Proactive + v0.3 Obsidian (parallel)

## Current Position

Milestone: v0.2 Proactive (feature/v0.2-proactive) + v0.3 Obsidian (feature/v0.3-obsidian)
Phase: 07-projects-redesign → Planning (1/1 plans)
Status: PLAN created, ready for APPLY
Last activity: 2026-04-18 — Created phases/07-projects-redesign/07-01-PLAN.md

Progress:
- Milestone: [██████████] 100%
- Phase 3: [██████████] 100%

## Loop Position

Current loop state:
```
PLAN ──▶ APPLY ──▶ UNIFY
  ✓        ✓        ✓     [Phase 06 complete — all loops closed]
```

## Accumulated Context

### Decisions
See README.md Design Decisions — 7 decisions recorded at init.

Key carried forward:
- Decision 2: Verbose on all 5 tabs (shipped Phase 2)
- Decision 3: Eyes NOT on Home tab (shipped Phase 2)
- Decision 4: Tap eyes = regenerate (shipped Phase 2)
- Phase 3: Tapping eyes triggers conversation overlay (not a new tap target — same eyes)

### Phase 2 Summary (COMPLETE)
| Plan | Description | Status |
|------|-------------|--------|
| 02-01 | MiniMaxEyes animated component | ✓ COMPLETE |
| 02-02 | Verbose paragraph mode in all panels | ✓ COMPLETE |
| 02-03 | Eyes overlay + tap-to-regenerate | ✓ COMPLETE |

### Phase 3 (Tool Engine) — COMPLETE
| Plan | Description | Status |
|------|-------------|--------|
| 03-01 | ToolEngine + Claude tool-use loop | ✓ COMPLETE |
| 03-02 | Tool result display + write_file + fetch_url | ✓ COMPLETE |

### Phase 4 Progress (Proactive)
| Plan | Description | Status |
|------|-------------|--------|
| 04-01 | NudgeEngine — streak/task/endOfDay nudges | ✓ COMPLETE |
| 04-02 | SneakPeekView + NotchOverlayWindow wiring | ✓ COMPLETE |
| 04-03 | Morning brief nudge type | ✓ COMPLETE |

### Phase 5 Progress (Obsidian)
| Plan | Description | Status |
|------|-------------|--------|
| 05-01 | ObsidianStore + vault picker | ✓ COMPLETE |
| 05-02 | appendToDaily + Pomodoro session log | ✓ COMPLETE |
| 05-03 | AI clip save to vault | ✓ COMPLETE |

### Deferred Issues
| Issue | Origin | Effort | Revisit |
|-------|--------|--------|---------|
| Voice wake word trigger | Design | M | After all 3 phases ship |
| Conversation history persistence | Design | S | Phase 3 review |
| Per-project task filtering (needs projectId on DailyTask) | Design | M | When Tasks tab gets projectId |

### Blockers/Concerns
| Blocker | Impact | Resolution Path |
|---------|--------|-----------------|
| macOS sandbox entitlement for mic | Blocks voice trigger | Verify entitlements before Phase 3 voice work |
| Phase 3 tap conflict | Tap eyes now regenerates — Phase 3 needs to change this to open conversation | Design before 03-01 |

## Session Continuity

Last session: 2026-04-18
Stopped at: Phase 06 complete — all loops closed
Next action: /paul:plan (choose next phase from ROADMAP.md)
Resume file: .paul/ROADMAP.md

---
*STATE.md — Updated after every significant action*
