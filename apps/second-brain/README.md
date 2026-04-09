# Second Brain

> Mini-Max's AI layer — contextual insights on every tab, verbose analysis, and a companion personality activated by wake word.

**Type:** Application (embedded feature — Mini-Max macOS)
**Stack:** Swift 5.9 · SwiftUI · Claude API (Sonnet) · SFSpeechRecognizer · AVAudioEngine
**Skill Loadout:** paul:plan, paul:audit, claude-api
**Quality Gates:** build passes, API key never logged, voice permission flow tested, personality prompt reviewed

---

## Overview

Mini-Max sees everything — projects, tasks, streak, focus sessions — but says nothing. Second Brain turns it from a passive tracker into an active companion. It surfaces insights contextually on every tab, analyses what it sees verbosely when given space, and becomes conversational when called by name.

Three layers:
1. **Insight line** — single-line observation at the bottom of each tab, auto-loaded on switch
2. **Verbose mode** — paragraph-depth analysis with animated Mini-Max eyes in the corner
3. **Conversation mode** — full Baymax-personality companion, triggered by clicking the eyes

No new tab. Everything surfaces within existing panels.

---

## Stack

| Layer | Choice | Rationale |
|-------|--------|-----------|
| Language | Swift 5.9 | Existing Mini-Max codebase |
| AI | Claude API — Sonnet | Capable of verbose paragraph insights and conversation |
| Voice (future) | SFSpeechRecognizer + AVAudioEngine | Native macOS, no third-party dependency |
| Config | UserDefaults | API key alongside existing GitHub PAT |
| UI | SwiftUI | Matches existing Mini-Max panel style |

---

## Architecture

### InsightEngine

Central service. Accepts a tab + context snapshot, calls Claude API, caches per tab (5min TTL).

```swift
final class InsightEngine {
    static let shared = InsightEngine()
    func insight(for tab: NotchTab, verbose: Bool) async -> String?
    func regenerate(for tab: NotchTab, verbose: Bool) async -> String?
}
```

### Per-tab context

Each tab builds its own `InsightContext` from local stores — no cross-tab data leakage.

| Tab | Context |
|-----|---------|
| Focus | active task, project, sessions on task, last commit age, streak |
| Projects | all projects with activity scores, most/least active |
| Tasks | pending, overdue, completion rate, nearest deadline |
| Streak | current streak, longest, days active this week |
| Home | today's sessions, tasks completed, commits, streak day |

### Prompt architecture

**Brief** — one sharp observation under 15 words.
**Verbose** — 2–4 sentences referencing actual data values.
**Conversation** — Baymax personality: caring, slightly formal, warm, occasionally literal.

### ConversationSession

In-memory only. Clears on app background.

```swift
final class ConversationSession {
    var messages: [ConversationMessage] = []
    var isActive: Bool = false
    func send(_ text: String) async
}
```

---

## UI/UX

### Insight line
Single dimmed line (`Color(white: 0.28)`, size 9) at the bottom of each tab. Loads via `.task` on tab switch.

### Mini-Max Eyes overlay
4×4px capsule eyes in the **top-right corner** of Focus, Projects, Tasks, and Streak tabs (not Home).

| State | Appearance |
|-------|-----------|
| Loading | Visible + glow pulse + vertical float |
| Loaded | Steady float, no glow |
| Tap | Regenerates insight (bypasses cache) |
| No insight | Hidden |

### Verbose mode
Paragraph block with subtle divider above, scrollable on overflow. Same dimmed colour.

### Conversation overlay
Slides up over current tab. Input field at bottom, message thread above, `×` to dismiss. Mini-Max messages reference live store data.

---

## Integration Points

| Integration | Purpose |
|------------|---------|
| Claude API | Insight generation + conversation responses |
| PomodoroManager.shared | Focus tab context |
| TaskStore.shared | Tasks tab context |
| ProjectStore.shared | Projects tab context |
| GitHubContributionStore.shared | Streak tab context |
| CalendarManager.shared | Home tab context |

---

## Implementation Phases

### Phase 1 — InsightEngine Core
Add Claude API key to Settings. Build `InsightEngine` with API client, per-tab context builders, 5min cache. Render brief insight line at bottom of all 5 tabs.

**Done when:** Every tab surfaces a single-line insight on switch. Cached responses load instantly. New call fires after 5min or on manual regenerate.

### Phase 2 — Verbose Mode + Eyes
Verbose paragraph rendering. `MiniMaxEyes` SwiftUI component with float + glow animations. Overlay on 4 tabs. Tap-to-regenerate.

**Done when:** Verbose mode shows a paragraph. Eyes animate while loading, steady when loaded, disappear on error. Tap regenerates.

### Phase 3 — Conversation Mode
`ConversationSession` model. Conversation overlay UI with Baymax system prompt. Trigger: tap the eyes. (Voice trigger post-feature-complete.)

**Done when:** Tapping eyes opens conversation overlay. Mini-Max responds in character referencing live data. Dismisses cleanly.

---

## Design Decisions

1. **No Brain tab** — AI surfaces within existing tabs. Notch stays lean.
2. **Verbose on all five tabs** — each tab earns a paragraph. Sonnet over Haiku accepted for quality.
3. **Eyes not on Home** — Home is a summary view; Mini-Max commenting on its own summary is recursive.
4. **Tap eyes = regenerate** — eyes have a function, not just decoration.
5. **Baymax personality** — caring, slightly formal, occasionally literal. Never breaks character.
6. **5min cache** — balances API cost vs freshness.
7. **Click-to-open conversation first, voice after** — voice trigger added after all features ship.

---

## Open Questions

1. Brief vs verbose as default — start brief, unlock verbose in Settings?
2. Should conversation history survive app restarts?
3. Rate limiting on regenerate taps — add debounce?
4. What happens on first launch with no API key — silent or onboarding prompt?
5. Obsidian vault feature (Mini-Max writes structured markdown) — separate project or Phase 4 here?

---

## References

- Mini-Max source: `mini-max/Mini-max/`
- GitButler branch: `second-brain`
- Existing stores: `PomodoroManager.swift`, `TaskStore.swift`, `ProjectStore.swift`, `GitHubContributionStore.swift`, `CalendarManager.swift`
- Planning doc: `projects/second-brain/PLANNING.md`
