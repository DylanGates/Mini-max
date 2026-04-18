# Roadmap — Second Brain (v0.1 Aware)

## Milestone: v0.1 Aware
**Status:** In progress
**Goal:** Mini-Max surfaces contextual AI insights on every tab, proactively.

---

## Phase 1 — InsightEngine Core ✓ COMPLETE
Build the AI engine: API client, per-tab context builders, 5min cache. Render brief insight line at bottom of all tabs.

**Done:** Every tab surfaces a single-line insight on switch. Cached. Manual regenerate works.

| Plan | Description | Status |
|------|-------------|--------|
| 01-01 | InsightEngine multi-AI + cache | ✓ done |
| 01-02 | Context-aware prompt builders | ✓ done |
| 01-03 | InsightLineView wired to all 6 panels | ✓ done |

---

## Phase 2 — Verbose Mode + Eyes ✓ COMPLETE
Verbose paragraph rendering. MiniMaxEyes overlay on 5 tabs. Tap-to-regenerate.

**Done:** Verbose 2–4 sentence insights on all panels. Eyes animate (float/glow/load states). Tap regenerates insight with fresh API call bypassing cache.

| Plan | Description | Status |
|------|-------------|--------|
| 02-01 | MiniMaxEyes SwiftUI component | ✓ done |
| 02-02 | Verbose paragraph mode in all panels | ✓ done |
| 02-03 | Eyes overlay + tap-to-regenerate wiring | ✓ done |

**Completed:** 2026-04-11 — 3/3 plans

---

## Phase 3 — Tool Engine  ← CURRENT
Give Mini-Max's AI the ability to call tools (shell, file read, app context) so insights are grounded in live data rather than static prompts. Claude decides when to call tools; results feed back into the final response.

**Done when:** Insights can reference live `git log`, file contents, directory structure, and structured app data fetched at call time. Tool calls are transparent (shown in insight display). Both Claude and OpenAI tool-use paths work.

| Plan | Description | Status |
|------|-------------|--------|
| 03-01 | ToolEngine + Claude tool-use loop in InsightEngine | ✓ done |
| 03-02 | write_file + fetch_url + tool activity display | ✓ done |

**Completed:** 2026-04-16 — 2/2 plans

---

## Phase 6 — Feed Tab ✅ COMPLETE
Replace Streak tab with a Feed tab: two-column layout with morning news brief (left) and learning queue (right). HN headlines summarised by Claude daily; GitHub heatmap moved to Projects tab.

| Plan | Description | Status |
|------|-------------|--------|
| 06-01 | FeedPanel shell: tab rename + news placeholder + streak column | ✓ done |
| 06-02 | MorningBriefEngine + FeedLearningColumn | ✓ done |

**Completed:** 2026-04-18 — 2/2 plans
