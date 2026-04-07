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

## Docs
- Full plan: `~/.claude/plans/synthetic-knitting-avalanche.md`
- Designs: `/Users/admin/Projects/Apps/notch/designs/notch/expanded.pen`
