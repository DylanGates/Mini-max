# Mini-Max — Phase Plan

> Version 1.0 — April 2026  
> Walking skeleton approach. Optimised for a beginner learning macOS dev at a casual pace.

---

## Context

**Project:** Mini-Max — a macOS notch app that is a personal AI-powered developer companion.  
**Stack:** Swift, SwiftUI + AppKit hybrid, CoreData, Claude API.  
**Starting point:** Bare Xcode scaffold (CoreData template, `ContentView`, `Mini_maxApp`).  
**Developer profile:** New to Swift/macOS. A few hours per week. Goal: learn properly AND build something real.  
**Reference repos:** `boring` (GPL-3.0 — study patterns only) and `notchy` (MIT — can reference freely).

---

## Approach: Walking Skeleton

Get the two things that matter most working first — the notch shell and the AI chat — even in a thin, minimal form. Then layer in the productivity features on top of a foundation you have already validated.

```
Phase 0 — The Shell        Notch pill + panel. Nothing inside yet.
Phase 1 — The Brain        AI chat. Thin but real end-to-end.
Phase 2 — The Memory       CoreData. Projects, brain dump, Pomodoro, stand-up.
Phase 3 — The Eyes         IDE detection + GitHub. Mini-Max knows your work.
Phase 4 — The Voice        AI goes proactive. Context, digests, commit messages.
Phase 5 — The Launch       Polish, updater, onboarding, distribution.
Phase 6 — Expansion        Post-launch. No deadline.
```

**Rough pace at a few hours/week:**
- Phase 0: 3–4 weeks
- Phase 1: 3–4 weeks
- Phases 2–4: 6–8 weeks each
- Phase 5: 4–6 weeks
- Phase 6: ongoing, no pressure

---

## Phase 0 — The Shell

**Goal:** App launches, blank panel drops below the notch on hover, global hotkey works. Nothing inside the panel yet — just the container.

**This is the hardest phase.** It teaches the core AppKit patterns everything else builds on. Get this right and all future phases are SwiftUI inside a container you already understand.

### What to build

| Component | Purpose |
|---|---|
| `StatusBarController` | `NSStatusItem` in the menu bar — fallback trigger for non-notch Macs |
| `NotchOverlayWindow` | Transparent `NSPanel` sitting over the notch area at all times |
| `NSTrackingArea` hover | Mouse enter/exit triggers panel show/hide |
| `NotchWindow` | The main floating panel — `NSPanel` with `.nonactivatingPanel` |
| Bounce animation | Panel slides down with spring easing on show |
| `HotkeyManager` | Global backtick hotkey via `CGEventTap` |
| `MiniMaxViewModel` | Skeleton `@Observable` class — Combine state hub |
| `NotchPillView` | Static "M" dot in the notch pill |
| `ActionBar` | Tab bar with placeholder tabs (no content yet) |

### What you'll learn

- AppKit vs SwiftUI: why `NSPanel` is needed instead of a SwiftUI `WindowGroup`
- `NSScreen.auxiliaryTopLeftArea` / `auxiliaryTopRightArea` — how to read notch dimensions
- `NSTrackingArea` — mouse tracking without polling
- `CGEventTap` — intercepting global keyboard events
- `@NSApplicationDelegateAdaptor` — bridging SwiftUI app lifecycle to AppKit delegate
- Core Animation spring animations

### Key reference files (study before building)

- `notchy/Notchy/NotchWindow.swift` — copy this NSPanel setup pattern directly (MIT)
- `notchy/Notchy/AppDelegate.swift` — dual hover + click interaction model
- `boring/boringNotch/animations/drop.swift` — spring animation reference (study only, GPL)
- `boring/boringNotch/managers/NotchViewModel.swift` — Combine hub pattern (study only)

### Exit criterion

App launches silently. A dot appears in the notch area. Hovering over the notch drops a blank panel down with a spring animation. Moving the mouse away hides it. Pressing backtick toggles it. Menu bar icon also triggers it.

---

## Phase 1 — The Brain

**Goal:** A working AI chat inside the panel. Type a message, get a streaming response from Claude. The two things you care most about (notch shell + AI) are now both real.

### What to build

| Component | Purpose |
|---|---|
| `KeychainStore` | Secure storage for Claude API key — never `UserDefaults` |
| `ClaudeClient` | `URLSession` streaming chat via Anthropic Messages API |
| `ContextBuilder` (stub) | Assembles system prompt — minimal for now, expands in Phase 4 |
| `AIPanelView` | Root view of the AI tab |
| `ChatBubbleView` | Individual message bubble (user / assistant) |
| `AIInputBar` | Text input + send button at the bottom |
| `SettingsWindow` (stub) | API key entry field only — expands in later phases |
| `AIMessage` model | In-memory message list (no persistence yet) |

### What you'll learn

- `async`/`await` in Swift — structured concurrency basics
- `URLSession` with `AsyncBytes` — streaming HTTP responses
- Server-Sent Events (SSE) parsing — the Claude API streaming format
- macOS Keychain via `SecItemAdd` / `SecItemCopyMatching`
- SwiftUI `ScrollViewReader` — auto-scroll to latest message
- `@MainActor` — updating UI from async contexts

### Key reference files

- `docs.md §7` — Claude streaming API spec and request format
- `mini-maximus_personality.md §9` — the system prompt template to implement in `ContextBuilder`
- `notchy/Notchy/SettingsManager.swift` — UserDefaults wrapper pattern to adapt for settings

### Exit criterion

Open the settings tab, paste a Claude API key. Open the AI tab. Type a message. See a streaming response appear token by token. Mini-Maximus responds in character (short, calm, no hype).

---

## Phase 2 — The Memory

**Goal:** CoreData persistence layer + all the productivity features. Projects, brain dump, Pomodoro, and stand-up. The AI now has real data to reference when you eventually wire context in Phase 4.

### What to build

| Component | Purpose |
|---|---|
| CoreData schema | `Project`, `ProjectEntry`, `PomodoroSession`, `DailyStandup` entities |
| `PersistenceController` | CoreData stack setup, shared singleton |
| `ProjectStore` | CRUD operations for projects |
| `EntryStore` | CRUD for brain dump entries |
| `SessionStore` | Pomodoro session history |
| `ProjectView` | List, create, archive projects |
| `BrainDumpView` | Quick entry capture + tag picker (bug/idea/blocker/note) |
| `PomodoroEngine` | Timer logic: start, pause, skip, 25/5 cycle |
| `PomodoroView` | Visual ring timer + session count |
| Live timer in `NotchPillView` | Countdown shown in the pill during active session |
| `StandupView` | Three-field form: Yesterday / Today / Blockers |
| `NotificationManager` | Pomodoro transitions + standup daily reminder |
| `SleepManager` | `IOPMAssertion` — prevent sleep during active Pomodoro |
| `SettingsManager` | `UserDefaults` wrapper for Pomodoro durations, theme, etc. |

### What you'll learn

- CoreData: `NSManagedObject`, `@FetchRequest`, `NSPersistentContainer`
- `@Observable` vs `@ObservableObject` — when to use each
- `Timer.publish` and `Cancellable` in Combine
- `UNUserNotificationCenter` — scheduling local notifications
- IOKit power assertions — preventing system sleep

### Exit criterion

Can create a project, add brain dump entries with tags, run Pomodoro sessions (with notch pill countdown), and fill in a daily stand-up form. All data survives app restarts. Stand-up reminder fires at a configured time.

---

## Phase 3 — The Eyes

**Goal:** Mini-Max knows which project you're in and tracks your GitHub activity. Context switches automatically when you switch IDE windows.

### What to build

| Component | Purpose |
|---|---|
| `IDEDetector` | Multi-IDE detection: VS Code, Xcode, Cursor, JetBrains, Windsurf |
| VS Code / Cursor / Windsurf detection | Read `storage.json` via `DispatchSource` file watcher |
| Xcode detection | `NSWorkspace` + `CGWindowListCopyWindowInfo` window title parsing |
| JetBrains detection | Parse `recentProjects.xml` |
| Git fallback | `.git` directory walk from window title paths |
| Auto project-switching | `IDEDetector` output → `MiniMaxViewModel.activeProject` |
| "New project detected" prompt | Non-intrusive pill notification with Add/Dismiss |
| `GitHubManager` | GitHub GraphQL API: contribution graph + streak count |
| `ContributionGraphView` | Heatmap grid in the GitHub tab |
| GitHub streak in `NotchPillView` | Streak count + amber colour when no commits yet today |
| `KeychainStore` additions | GitHub PAT storage |

### What you'll learn

- `NSWorkspace` notifications — reacting to app switches
- `DispatchSource.makeFileSystemObjectSource` — file change watching without polling
- `CGWindowListCopyWindowInfo` — reading other apps' window titles
- GitHub GraphQL API — querying contribution data
- XML parsing — `XMLParser` for JetBrains project files
- Keychain additions — storing a second secret

### Exit criterion

Open VS Code on a project. Mini-Max automatically switches to that project. Open GitHub tab — see your contribution graph and streak count. If no commit today, pill turns amber. GitHub PAT stored securely in Keychain.

---

## Phase 4 — The Voice

**Goal:** The AI stops being a blank chat and becomes a genuine assistant with knowledge of your day. It can also proactively generate useful outputs.

### What to build

| Component | Purpose |
|---|---|
| `ContextBuilder` (full) | Injects active project, entries, stand-up, Pomodoro state, GitHub streak into system prompt |
| `AIRouter` | Switches between Claude and Ollama backends |
| `OllamaClient` | Local Ollama REST streaming (`/api/generate`) |
| "Summarise my day" command | Generates a digest from today's stand-up + entries + Pomodoro sessions |
| Commit message generation | Reads `git diff --staged` from active project, generates commit message |
| Weekly retrospective | Generates retro from the week's entries, sessions, and blocker tags |
| Auto-tagging entries | AI classifies new brain dump entries as bug/idea/blocker/note |
| Smart break suggestions | Suggests break based on consecutive session count |
| AI mode buttons | Quick-action buttons: "Summarise", "Commit msg", "Draft retro" |

### What you'll learn

- Prompt engineering — constructing effective system prompts from structured data
- Git integration — running `git diff` via `Process` / `Shell`
- Background task scheduling — triggering AI tasks without blocking UI
- `AIRouter` abstraction — clean backend switching pattern
- Ollama REST API — local model inference

### Exit criterion

Open AI tab after a full working day. Press "Summarise my day" — get a Mini-Maximus digest of your stand-up, blockers, and session count. Stage some changes in a project, press "Commit msg" — get a well-formed commit message. Ollama works as offline fallback.

---

## Phase 5 — The Launch

**Goal:** The app is ready for other people to install and use. It updates itself. It makes a good first impression.

### What to build

| Component | Purpose |
|---|---|
| Onboarding flow | First-launch wizard: set API key, link GitHub, configure hotkey |
| Sparkle auto-updater | In-app updates via `appcast.xml` |
| DMG creation + notarisation | `hdiutil` + `notarytool` script |
| Homebrew cask formula | `brew install --cask mini-max` |
| GitHub Actions CI | Build + test on every push to `main` |
| Accessibility | VoiceOver labels on all interactive elements |
| Reduced motion | Respect `NSAccessibilityReduceMotionEnabled` |
| Memory + CPU profiling | Target: < 150 MB RAM, < 1% CPU idle |
| Analytics (opt-in) | TelemetryDeck — privacy-preserving usage stats |
| Crash reporting | Sentry — symbolicated crash reports |
| README + landing page | GitHub README with screenshot, install instructions |

### What you'll learn

- macOS notarisation and code signing
- Sparkle update framework
- Homebrew tap/cask setup
- GitHub Actions for macOS builds
- VoiceOver and accessibility APIs
- Instruments — memory and CPU profiling

### Exit criterion

A stranger can run `brew install --cask mini-max`, complete onboarding, and have a working app. The app updates itself when a new version ships. Passes basic VoiceOver navigation. Memory under 150 MB after 1 hour of use.

---

## Phase 6 — Expansion

**Post-launch. No deadline. Pick up items as interest and time allow.**

| Feature | Complexity | Notes |
|---|---|---|
| Simulated notch for non-notch Macs | High | Phase 5 deferred |
| CloudKit iCloud sync | High | One-line CoreData addition, but sync conflicts are hard |
| iOS companion app | Very High | New project, shares CoreData model via CloudKit |
| VS Code extension | High | Separate TypeScript project — sends selection to Mini-Max AI |
| Widget plugin API | Very High | Third-party notch widgets — requires XPC + sandboxing |
| Pair programming mode | Very High | Local network session sharing |
| System health widget | Medium | CPU, RAM, battery in notch pill |

---

## Key Decisions (carried over from PRD)

| Decision | Rationale |
|---|---|
| Drop-down NSPanel, not expand-in-place | Too much content for in-notch expand |
| CoreData for persistence | SwiftUI `@FetchRequest` bindings, iCloud-ready |
| Not sandboxed (v1) | IDE file detection requires reading third-party app storage |
| Claude API first, Ollama in Phase 4 | Better v1 UX; Ollama requires user setup |
| macOS 14+ minimum | Broadest notch Mac coverage with modern SwiftUI |
| MIT licence | Community visibility > copyleft at this stage |
| XPC helper deferred to Phase 5+ | Unnecessary without sandbox |

---

## Reference Repos Quick Reference

| Repo | Licence | Key files |
|---|---|---|
| `boring` (boring.notch) | GPL-3.0 ⚠️ study only | `NotchView.swift`, `drop.swift`, `NotchViewModel.swift`, `ActionBar.swift` |
| `notchy` | MIT ✅ reference freely | `NotchWindow.swift`, `XcodeDetector.swift`, `SessionStore.swift`, `BotFaceView.swift` |
| DynamicNotchKit | MIT ✅ | Notch sizing helpers — adopt if `NSScreen` detection is unreliable |
| SwiftTerm | MIT ✅ | Terminal emulator — add in Phase 4 for NL shell feature |

---

*Phase plan maintained alongside `docs.md` PRD.*  
*Start date: April 2026. Currently: beginning Phase 0.*
