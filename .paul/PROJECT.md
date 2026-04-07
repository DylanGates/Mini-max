# Mini-Max

## Overview
macOS notch app that lives in the hardware notch. Watches work rhythm (Pomodoro, GitHub commits, tasks, learning) and surfaces insights proactively. Baymax-style animated eyes express state. SwiftUI + AppKit hybrid.

## 🚨 Critical Rules
1. Never change notch pill or expanded view UI without stating reason + new design first
2. Notch pill = eyes only — no indicators, no pills inside the notch shape
3. Status indicators go in the menu bar (Raycast-style NSStatusItem)
4. PATs stored in Keychain only — never UserDefaults
5. Commit each completed task using `but commit`

## Tech Stack
- Swift 5.9+, SwiftUI + AppKit hybrid
- Persistence: UserDefaults JSON (current), CoreData (future)
- AI: Claude API streaming + Core ML embeddings
- Calendar/Reminders: EventKit
- GitHub: GraphQL API, per-account PAT
- Obsidian: FSEvents + FileManager
- Window: NSPanel at .screenSaver level

## Key Files
```
Mini-max/
├── ExpandedNotchView.swift     — 1,500+ lines, 6 tabs, header badge pills
├── CalendarManager.swift       — EventKit, live events
├── GitHubContributionStore.swift — GraphQL, multi-account, 1h cache
├── GitHubAccountManager.swift  — SSH config parsing, 3 accounts
├── PomodoroManager.swift       — Focus/break phases, UNNotifications
├── TaskStore.swift             — CRUD, priority, 24h auto-clear
├── LearningStore.swift         — Topics, progress, schedule
├── ProjectStore.swift          — CRUD, daily reset, session tracking
├── BatteryMonitor.swift        — IOKit polling
└── NotchOverlayWindow.swift    — NSPanel, hover, spring animations
```

## Validated (Phase 1)
- ✓ NSStatusItem with live indicator dots — single variableLength item with NSAttributedString
- ✓ 3 layout modes (primary / ultraCompact / badge) persisted via UserDefaults
- ✓ 1s Timer polling pattern for @Observable stores in AppKit context
- ✓ Right-click context menu pattern (set menu → performClick → nil out in async)

## Deferred
- [ ] `LearningTopic.lastCompletedDate` — needed for real learning streak (currently shows todayTopics.count)

## Key Decisions
| Decision | Phase | Rationale |
|---|---|---|
| Single NSStatusItem (not 5) | 1 | macOS norm, simpler |
| Notch pill = eyes only | 0 | Design constraint — status in menu bar |
| PATs in Keychain only | 0 | Security |
| UserDefaults JSON (not CoreData) | 0 | Already built, migration deferred |
| `but commit` for all commits | 0 | GitButler manages this repo |

## Docs
- Full plan: `~/.claude/plans/synthetic-knitting-avalanche.md`
- Designs: `/Users/admin/Projects/Apps/notch/designs/notch/expanded.pen`

---
*Last updated: 2026-04-07 after Phase 1*
