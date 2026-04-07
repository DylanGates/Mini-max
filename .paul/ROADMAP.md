# Mini-Max Roadmap

## Milestone v0.1 — Core Loop (In progress)

### Phase 0 — Foundation ✅ Complete
All 6 tabs scaffolded. Stores wired. GitHub multi-account heatmap. Header badge pills.

### Phase 1 — Menu Bar Indicators 🔵 In progress
NSStatusItem with live Pomodoro/streak/events/tasks indicators (Raycast-style).

- [ ] `StatusBarController` — NSStatusItem, custom NSView, 3 layout modes
- [ ] Pomodoro dot: red ● + countdown from PomodoroManager (live tick)
- [ ] GitHub streak dot: orange ● + count from GitHubContributionStore
- [ ] Learning streak dot: purple ● + days from LearningStore
- [ ] Events dot: blue ● + count from CalendarManager
- [ ] Tasks dot: green ● + pending count from TaskStore
- [ ] Hover reveal in ultra-compact mode (NSTrackingArea)
- [ ] Layout mode persisted to UserDefaults; toggle in Settings

### Phase 2 — Settings Panel Content
- [ ] GitHub PAT entry per account (Keychain storage)
- [ ] Layout mode selector (primary / ultra-compact / badge)
- [ ] Obsidian vault path picker
- [ ] Notification toggles

### Phase 3 — Integrations
- [ ] Obsidian auto-log (Pomodoro sessions → daily note)
- [ ] Apple Reminders sync (EKReminder in Tasks tab)
- [ ] Tech news morning brief (RSS + Claude summary)
- [ ] Git checkpoint (refs/notch-snapshots)
- [ ] Sound notifications (AVAudioPlayer)

### Phase 4 — AI & Proactive Layer
- [ ] Claude API streaming chat (AI tab)
- [ ] Context injection (sessions + tasks + brain dumps)
- [ ] EmbeddingEngine (Core ML, all-MiniLM-L6-v2)
- [ ] Proactive nudges (streak risk, morning brief)
- [ ] Recurring blocker detection (cosine similarity)

### Phase 5 — Polish & Ports
- [ ] Music player (MusicKit, album art, controls)
- [ ] Sneak peek (2s pop-up on nudge/track change)
- [ ] Fullscreen auto-hide
- [ ] Sleep prevention (IOPMAssertion while Pomodoro active)
- [ ] Volume/brightness HUD
