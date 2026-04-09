# Second Brain

> Mini-Max's AI layer — contextual insights on every tab, verbose analysis, and a companion personality activated by wake word.

**Created:** 2026-04-09
**Type:** Application (embedded feature — Mini-Max macOS)
**Stack:** Swift 5.9 · SwiftUI · Claude API (Sonnet) · SFSpeechRecognizer · AVAudioEngine
**Skill Loadout:** paul:plan, paul:audit, claude-api
**Quality Gates:** build passes, API key never logged, voice permission flow tested, personality prompt reviewed

---

## Problem Statement

Mini-Max sees everything you're doing — your projects, tasks, streak, focus sessions — but says nothing. All that context sits in stores, silently. The second brain turns Mini-Max from a passive tracker into an active companion: it surfaces insights in context, analyses what it sees verbosely when given space, and becomes conversational when called by name.

Audience: solo developer (the user). Not a feature for others to configure deeply — it should just work.

---

## Tech Stack

Embedded Swift feature module inside Mini-Max.app. No separate service.

| Layer | Choice | Rationale |
|-------|--------|-----------|
| Language | Swift 5.9 | Existing Mini-Max codebase |
| AI | Claude API — Sonnet | Capable enough for verbose paragraph insights and conversation |
| Voice | SFSpeechRecognizer + AVAudioEngine | Native macOS, no third-party dependency |
| Config | UserDefaults | API key stored alongside GitHub PAT |
| UI | SwiftUI | Matches existing Mini-Max panel style |

### Research Needed
- `SFSpeechRecognizer` on-device vs server — confirm which model handles continuous wake-word detection reliably on macOS without excessive battery drain.
- Whether macOS sandbox allows continuous `AVAudioEngine` input — may need `com.apple.security.device.audio-input` entitlement.

---

## Data Model

### InsightEngine

```swift
final class InsightEngine {
    static let shared = InsightEngine()

    // Per-tab cache: tab → (text, cachedAt)
    private var cache: [NotchTab: (text: String, cachedAt: Date)] = [:]
    private let ttl: TimeInterval = 300  // 5 minutes

    func insight(for tab: NotchTab, verbose: Bool) async -> String?
    func regenerate(for tab: NotchTab, verbose: Bool) async -> String?  // bypasses cache
}
```

### InsightContext (per tab)

Each tab builds its own context snapshot passed to the API call. No cross-tab leakage.

| Tab | Context Fields |
|-----|---------------|
| Focus | active task, project name, sessions on this task, last commit age, current streak |
| Projects | all projects with activity scores, most/least active, total sessions per project |
| Tasks | pending count, overdue count, completion rate this week, nearest deadline |
| Streak | current streak, longest streak, days active this week, contribution pattern |
| Home | today's sessions, tasks completed today, commits today, streak day |

### ConversationSession

```swift
struct ConversationMessage {
    let role: Role  // user / assistant
    let content: String
    let timestamp: Date
}

final class ConversationSession: ObservableObject {
    var messages: [ConversationMessage] = []
    var isActive: Bool = false

    func send(_ text: String) async
    func clear()
}
```

---

## API Surface

No HTTP API. Internal Swift module boundaries.

### InsightEngine interface

```swift
// Called by each panel's .task on tab load
func insight(for tab: NotchTab, verbose: Bool) async -> String?

// Called by tapping the eyes overlay
func regenerate(for tab: NotchTab, verbose: Bool) async -> String?
```

### Prompt architecture

**Brief mode** (single line):
```
System: You are Mini-Max, a focused productivity assistant. 
        Respond with one sharp observation under 15 words. No filler.
User:   {structured context JSON}
```

**Verbose mode** (paragraph):
```
System: You are Mini-Max, a focused productivity assistant.
        Respond with 2-4 sentences of genuine insight. Be specific, not generic.
        Reference actual values from the data.
User:   {structured context JSON}
```

**Conversation mode** (Baymax personality):
```
System: You are Mini-Max — a personal companion assistant for a developer.
        Your personality mirrors Baymax from Big Hero 6: caring, slightly formal,
        warm, occasionally literal, quietly funny. You have full awareness of the
        user's current work context. Never break character.
        Current context: {full snapshot of all stores}
User:   {spoken or typed message}
```

---

## Deployment Strategy

Embedded in Mini-Max.app — no separate process, no server.

### API Key
Stored in UserDefaults under `minimax.claude.apiKey`. Entered once in Settings panel alongside GitHub PAT. Never logged. Cleared if blank string is saved.

### Entitlements Required
- `com.apple.security.device.audio-input` — microphone for wake word
- Existing entitlements unchanged

---

## Security Considerations

- **API key**: stored in UserDefaults, never included in logs, never sent anywhere except `api.anthropic.com`
- **Context data**: only local store data sent to API — no file system paths, no PATs, no tokens
- **Microphone**: used only for wake-word detection; audio stream is processed locally by SFSpeechRecognizer, not recorded
- **Conversation history**: kept in memory only (`ConversationSession`), not persisted to disk

---

## UI/UX Needs

### Design System
SwiftUI — dark panel aesthetic, matches existing Mini-Max components.

### Insight line (all 5 tabs)

Single dimmed line at the bottom of each tab's content area:

```swift
Text(insight)
    .font(.system(size: 9))
    .foregroundStyle(Color(white: 0.28))
    .lineLimit(1)  // brief mode
    // lineLimit(nil) + fixedSize in verbose mode
    .padding(.bottom, 4)
```

### Mini-Max Eyes overlay (Focus, Projects, Tasks, Streak — not Home)

Small animated eyes appear in the **top-right corner** of the tab when an insight is loaded or loading.

```
Behaviour:
  Loading  → eyes visible + gentle glow pulse + vertical float animation
  Loaded   → eyes steady (float only, no glow)
  Tap      → regenerate insight (bypasses cache, triggers new API call)
  No insight / error → eyes hidden
```

Eye size: 4×4px capsules (down from 6×6px pill eyes), spacing 6px. Matches the collapsed pill eye motif.

### Verbose mode rendering

Verbose insight replaces the single line with a paragraph block — scrollable if it overflows, subtle divider above it, same dimmed color style.

### Conversation overlay

Triggered by wake word ("hi, mini-max") or tapping the eyes. Slides up as an overlay over the current tab content:

- Input field at bottom (text fallback if voice unavailable)
- Message thread above — Mini-Max messages left-aligned, user right-aligned
- Mini-Max avatar: animated eyes (same capsule motif, slightly larger)
- `×` to dismiss and return to tab view
- Conversation persists for the session; clears on app background

---

## Integration Points

| Integration | Type | Purpose |
|------------|------|---------|
| Claude API | HTTPS REST | Insight generation + conversation |
| SFSpeechRecognizer | Native macOS | Wake word "hi, mini-max" detection |
| PomodoroManager.shared | Internal Swift | Focus tab context |
| TaskStore.shared | Internal Swift | Tasks tab context |
| ProjectStore.shared | Internal Swift | Projects tab context |
| GitHubContributionStore.shared | Internal Swift | Streak tab context |
| CalendarManager.shared | Internal Swift | Home tab context |

---

## Phase Breakdown

### Phase 1: InsightEngine Core
- **Build:** `InsightEngine.swift` with Claude API client, per-tab context builders, 5min cache. API key field in Settings panel. Brief single-line insight rendered at bottom of all 5 tabs. `.task` on each panel loads insight on tab switch.
- **Testable:** Switch to each tab → single-line insight appears within 2s. Switch away and back within 5min → cached response (no API call). Clear cache → new call fires.
- **Outcome:** Mini-Max has something to say on every tab.

### Phase 2: Verbose Mode + Eyes Overlay
- **Build:** Verbose mode toggle (per-tab or global setting). Paragraph rendering for insights. `MiniMaxEyes` SwiftUI component — 4×4px capsules, float + glow animations. Overlay positioned top-right on Focus, Projects, Tasks, Streak tabs. Tap-to-regenerate wired to `InsightEngine.regenerate()`.
- **Testable:** Verbose mode on → paragraph insight loads, eyes appear animating in corner. Tap eyes → insight refreshes. Insight error → eyes disappear.
- **Outcome:** Mini-Max visibly "sees" what you see. Verbose analysis available on demand.

### Phase 3: Wake Word + Conversation Mode
- **Build:** `WakeWordDetector` using `SFSpeechRecognizer` + `AVAudioEngine` listening for "hi, mini-max". Fallback: tap eyes to open conversation. `ConversationSession` model. Conversation overlay UI with Baymax system prompt. Full store snapshot sent as context on conversation open.
- **Testable:** Say "hi, mini-max" → overlay slides up, Mini-Max greets in character. Send a message → response references actual data ("You have 3 overdue tasks. This is not ideal."). Dismiss → returns to tab.
- **Outcome:** Mini-Max is a companion, not just a display.

---

## Design Decisions

1. **No Brain tab**: AI surfaces within existing tabs contextually. The notch stays lean — no new navigation destination.
2. **Verbose on all five tabs**: Each tab earns a paragraph. Richer output requires Sonnet (not Haiku), accepted tradeoff for quality.
3. **Eyes in corner (not Home)**: Home is a summary view — Mini-Max commenting on its own summary is recursive. Eyes only where Mini-Max is observing live data.
4. **Tap eyes = regenerate**: Eyes have a function, not just decoration. Consistent with Mini-Max's interactive personality.
5. **Baymax personality**: System prompt anchors the character. Caring, slightly formal, occasionally literal. Never breaks character in conversation mode.
6. **5min cache**: Balances API cost vs freshness. Tab-load should feel instant on repeat visits, but context refreshes often enough to stay relevant.
7. **Voice trigger**: "hi, mini-max" is the full experience. Click-the-eyes is the fallback if microphone permission is denied.

---

## Open Questions

1. **Voice vs click as primary trigger**: Is microphone permission worth requiring for the wake word, or should click-the-eyes be the primary and voice be the bonus?
2. **Brief vs verbose as default**: Should verbose be the default from day one, or start brief and let the user unlock verbose in Settings?
3. **Conversation history persistence**: Currently in-memory only. Should it survive app restarts? (Adds UserDefaults/file complexity.)
4. **Rate limiting**: No rate limiting implemented. If the user taps regenerate rapidly, multiple API calls fire. Add debounce?
5. **API key onboarding**: What happens on first launch with no API key set — silent (no insight lines) or a prompt to set up?

---

## Next Actions

- [ ] Add `minimax.claude.apiKey` field to Settings panel
- [ ] Create `InsightEngine.swift` — API client + per-tab context builders + cache
- [ ] Add insight line to `FocusPanel`, `ProjectsPanel`, `TasksPanel`, `StreakPanel`, `MiniMaxHomePanel`
- [ ] Create `MiniMaxEyes.swift` — reusable animated eyes component
- [ ] Wire eyes overlay to Focus, Projects, Tasks, Streak panels

---

## References

- Mini-Max project: `mini-max/Mini-max/`
- GitButler branch: `second-brain`
- Existing stores: `PomodoroManager.swift`, `TaskStore.swift`, `ProjectStore.swift`, `GitHubContributionStore.swift`, `CalendarManager.swift`
- Claude API docs: [api.anthropic.com](https://api.anthropic.com)
- SFSpeechRecognizer: [Apple Developer — Speech](https://developer.apple.com/documentation/speech)

---

*Last updated: 2026-04-09*
