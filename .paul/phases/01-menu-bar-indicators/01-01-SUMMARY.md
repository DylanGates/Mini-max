---
phase: 01-menu-bar-indicators
plan: 01
subsystem: ui
tags: [nsstatusitem, appkit, pomodoro, github, menu-bar, swift]

requires: []
provides:
  - StatusBarController with 5 live colored indicator dots
  - StatusBarLayout enum with 3 switchable display modes
  - Right-click context menu with layout submenu
  - Live Pomodoro countdown (1s timer)
  - GitHub streak calculation from GitHubContributionStore
affects: [02-settings, 04-ai-layer]

tech-stack:
  added: []
  patterns:
    - "NSStatusItem variableLength + NSAttributedString for multi-colored status bar text"
    - "Right-click menu via button.sendAction(on:) + manual statusItem.menu nil-out pattern"
    - "1s Timer polling for @Observable store data from non-SwiftUI context"

key-files:
  created: [Mini-max/StatusBarController.swift]
  modified: []

key-decisions:
  - "Single NSStatusItem (not 5) — simplicity + macOS norms"
  - "button.toolTip for ultra-compact hover — avoids custom NSView for v1"
  - "Learning indicator shows todayTopics.count — LearningTopic lacks completion timestamps"

patterns-established:
  - "Timer polling pattern for @Observable in AppKit context (not withObservationTracking)"
  - "Right-click: set statusItem.menu, performClick, nil out in async block"

duration: ~30min
started: 2026-04-07T00:00:00Z
completed: 2026-04-07T00:00:00Z
---

# Phase 1 Plan 01: Menu Bar Indicators Summary

**5 live colored indicator dots in menu bar via NSStatusItem — Pomodoro timer (red), GitHub streak (orange), learning (purple), events (blue), tasks (green) — with 3 switchable layout modes persisted to UserDefaults.**

## Performance

| Metric | Value |
|--------|-------|
| Duration | ~30 min |
| Tasks | 3 completed |
| Files modified | 1 (StatusBarController.swift rewritten) |
| Build | Succeeded clean |

## Acceptance Criteria Results

| Criterion | Status | Notes |
|-----------|--------|-------|
| AC-1: Indicators visible in menu bar | Pass | 5 colored dots rendered via NSAttributedString |
| AC-2: Live Pomodoro countdown | Pass | 1s Timer, MM:SS format, pauses when idle |
| AC-3: Layout modes switchable | Pass | 3 modes, UserDefaults key `minimax.statusbar.layout`, context menu submenu |
| AC-4: Ultra-compact hover reveals count | Pass | `button.toolTip` set to all 5 values joined by newline |

## Accomplishments

- Rewrote `StatusBarController.swift` from a static icon+menu to a live data display
- 5 indicators with macOS system accent colors (red/orange/purple/blue/green)
- Right-click context menu with layout mode selector and existing app controls (Settings, Quit, Restart)
- GitHub streak computed inline from `GitHubContributionStore.contributionsByUser` (same logic as header badge pills)
- AppDelegate required zero changes — `statusBarController = StatusBarController()` was already wired

## Task Commits

| Task | Commit | Description |
|------|--------|-------------|
| Task 1+3: StatusBarController | `a1b0495` | feat(statusbar): live indicator dots with 3 layout modes |
| PAUL setup | `998c945` | chore(paul): init PAUL structure + phase 1 plan |
| Pre-phase: badge pills | `0f3c6b7` | feat(header): add 4 status badge pills |

## Files Created/Modified

| File | Change | Purpose |
|------|--------|---------|
| `Mini-max/StatusBarController.swift` | Rewritten | 5 live colored indicator dots, 3 layout modes, right-click menu |

## Decisions Made

| Decision | Rationale | Impact |
|----------|-----------|--------|
| Single NSStatusItem (variableLength) | macOS norm — multiple items clutter the bar | Simpler rendering, one NSAttributedString |
| button.toolTip for ultra-compact hover | Avoids custom NSView for v1 | Shows all 5 values on hover; per-segment hover deferred |
| 1s Timer polling (not withObservationTracking) | `StatusBarController` is AppKit, not SwiftUI | Simple and reliable; slight CPU cost is negligible |

## Deviations from Plan

### Summary

| Type | Count | Impact |
|------|-------|--------|
| Deferred | 1 | Learning streak is approximate |

### Deferred Items

- **Learning streak**: `LearningTopic` struct has no completion timestamp field. Indicator shows `todayTopics.count` (topics scheduled for today) rather than a consecutive-day streak. Requires adding `lastCompletedDate: Date?` to `LearningTopic` in a future plan.

## Next Phase Readiness

**Ready:**
- Menu bar live indicator foundation in place
- `StatusBarLayout` enum and UserDefaults key ready for Settings UI toggle (Phase 2)
- `StatusBarController.layout` setter is public — Settings can update it directly

**Concerns:**
- Learning streak is a stub — `LearningTopic` needs `lastCompletedDate` before it's accurate
- GitHub streak recomputed on every 1s tick (same DateFormatter allocation) — optimize with memoization if profiling shows cost

**Blockers:** None

---
*Phase: 01-menu-bar-indicators, Plan: 01*
*Completed: 2026-04-07*
