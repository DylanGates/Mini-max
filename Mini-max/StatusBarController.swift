import AppKit

// MARK: - Layout Mode

enum StatusBarLayout: String, CaseIterable {
    case primary      = "primary"       // ● 18:42  ● 12  ● 5  ● 3  ● 2
    case ultraCompact = "ultraCompact"  // ● ● ● ● ●  (hover for values)
    case badge        = "badge"         // ● 18:42  ● 12d  ● 5d  ● 3 events  ● 2 tasks

    var displayName: String {
        switch self {
        case .primary:      return "Primary  ● 18:42  ● 12 …"
        case .ultraCompact: return "Ultra Compact  ● ● ● ● ●"
        case .badge:        return "Badge  ● 12d streak  ● 3 events …"
        }
    }
}

// MARK: - StatusBarController

@MainActor
final class StatusBarController {
    private let statusItem: NSStatusItem
    private var refreshTimer: Timer?

    var onToggle: (() -> Void)?

    var layout: StatusBarLayout {
        get {
            let raw = UserDefaults.standard.string(forKey: "minimax.statusbar.layout") ?? "primary"
            return StatusBarLayout(rawValue: raw) ?? .primary
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "minimax.statusbar.layout")
            updateDisplay()
        }
    }

    // macOS system-style accent colors
    private enum IndicatorColor {
        static let pomodoro = NSColor(red: 1.0,   green: 0.271, blue: 0.227, alpha: 1) // #FF453A
        static let streak   = NSColor(red: 1.0,   green: 0.624, blue: 0.039, alpha: 1) // #FF9F0A
        static let learning = NSColor(red: 0.749, green: 0.353, blue: 0.949, alpha: 1) // #BF5AF2
        static let events   = NSColor(red: 0.039, green: 0.518, blue: 1.0,   alpha: 1) // #0A84FF
        static let tasks    = NSColor(red: 0.188, green: 0.820, blue: 0.345, alpha: 1) // #30D158
    }

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        configureButton()
        updateDisplay()
        startRefreshTimer()
    }

    deinit {
        refreshTimer?.invalidate()
    }

    // MARK: - Timer

    private func startRefreshTimer() {
        // 1s tick for live Pomodoro countdown; also refreshes streak/event counts
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateDisplay()
            }
        }
        refreshTimer?.tolerance = 0.1
    }

    // MARK: - Display

    func updateDisplay() {
        guard let button = statusItem.button else { return }
        let indicators = currentIndicators()
        button.attributedTitle = buildAttributedTitle(indicators)

        // Ultra-compact: show all values as tooltip on hover
        if layout == .ultraCompact {
            button.toolTip = indicators.map(\.tooltip).joined(separator: "\n")
        } else {
            button.toolTip = nil
        }
    }

    private struct Indicator {
        let color: NSColor
        let label: String   // text shown next to dot (empty in ultraCompact)
        let tooltip: String // shown in ultra-compact hover
    }

    private func currentIndicators() -> [Indicator] {
        [
            Indicator(
                color: IndicatorColor.pomodoro,
                label: layout == .ultraCompact ? "" : pomodoroLabel(),
                tooltip: "Pomodoro: \(pomodoroLabel())"
            ),
            Indicator(
                color: IndicatorColor.streak,
                label: layout == .ultraCompact ? "" : streakLabel(),
                tooltip: "GitHub streak: \(githubStreak())d"
            ),
            Indicator(
                color: IndicatorColor.learning,
                label: layout == .ultraCompact ? "" : learningLabel(),
                tooltip: "Learning today: \(LearningStore.shared.todayTopics.count) topics"
            ),
            Indicator(
                color: IndicatorColor.events,
                label: layout == .ultraCompact ? "" : eventsLabel(),
                tooltip: "Events today: \(CalendarManager.shared.events.count)"
            ),
            Indicator(
                color: IndicatorColor.tasks,
                label: layout == .ultraCompact ? "" : tasksLabel(),
                tooltip: "Tasks pending: \(TaskStore.shared.pending.count)"
            ),
        ]
    }

    private func buildAttributedTitle(_ indicators: [Indicator]) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        let gapStr = layout == .ultraCompact ? "  " : "   "

        for (i, indicator) in indicators.enumerated() {
            // Colored dot
            result.append(NSAttributedString(string: "●", attributes: [
                .foregroundColor: indicator.color,
                .font: font
            ]))

            // Label (empty string in ultraCompact, so nothing added)
            if !indicator.label.isEmpty {
                result.append(NSAttributedString(string: " \(indicator.label)", attributes: [
                    .foregroundColor: NSColor.labelColor,
                    .font: font
                ]))
            }

            // Gap between segments
            if i < indicators.count - 1 {
                result.append(NSAttributedString(string: gapStr, attributes: [
                    .font: font,
                    .foregroundColor: NSColor.clear
                ]))
            }
        }

        return result
    }

    // MARK: - Data helpers

    private func pomodoroLabel() -> String {
        let phase = PomodoroManager.shared.phase
        guard !phase.isIdle else { return "–" }
        let r = phase.remaining
        let m = Int(r) / 60
        let s = Int(r) % 60
        return String(format: "%d:%02d", m, s)
    }

    private func githubStreak() -> Int {
        let contributions = GitHubContributionStore.shared.contributionsByUser
        guard !contributions.isEmpty else { return 0 }
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = TimeZone(identifier: "UTC")
        var streak = 0
        var date = Date()
        let cal = Calendar(identifier: .gregorian)
        while true {
            let key = df.string(from: date)
            let hasCommit = contributions.values.contains { $0[key]?.count ?? 0 > 0 }
            if !hasCommit { break }
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: date) else { break }
            date = prev
        }
        return streak
    }

    private func streakLabel() -> String {
        let n = githubStreak()
        return layout == .badge ? "\(n)d" : "\(n)"
    }

    private func learningLabel() -> String {
        // LearningTopic has no completion timestamp yet — shows today's scheduled count
        let n = LearningStore.shared.todayTopics.count
        return layout == .badge ? "\(n) topics" : "\(n)"
    }

    private func eventsLabel() -> String {
        let n = CalendarManager.shared.events.count
        return layout == .badge ? "\(n) events" : "\(n)"
    }

    private func tasksLabel() -> String {
        let n = TaskStore.shared.pending.count
        return layout == .badge ? "\(n) tasks" : "\(n)"
    }

    // MARK: - Button & Menu

    private func configureButton() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(handleClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            // Show context menu on right-click, then nil it out so left-click keeps its action
            statusItem.menu = buildContextMenu()
            statusItem.button?.performClick(nil)
            DispatchQueue.main.async { [weak self] in self?.statusItem.menu = nil }
        } else {
            onToggle?()
        }
    }

    private func buildContextMenu() -> NSMenu {
        let menu = NSMenu()

        // Layout submenu
        let layoutItem = NSMenuItem(title: "Indicator Style", action: nil, keyEquivalent: "")
        let layoutSubmenu = NSMenu()
        for mode in StatusBarLayout.allCases {
            let item = NSMenuItem(title: mode.displayName, action: #selector(handleLayoutChange(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mode.rawValue
            item.state = layout == mode ? .on : .off
            layoutSubmenu.addItem(item)
        }
        layoutItem.submenu = layoutSubmenu
        menu.addItem(layoutItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings", action: #selector(handleSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let updatesItem = NSMenuItem(title: "Check for Updates…", action: #selector(handleUpdates), keyEquivalent: "")
        updatesItem.target = self
        menu.addItem(updatesItem)

        menu.addItem(.separator())

        let restartItem = NSMenuItem(title: "Restart Mini-Max", action: #selector(handleRestart), keyEquivalent: "")
        restartItem.target = self
        menu.addItem(restartItem)

        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        return menu
    }

    @objc private func handleLayoutChange(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let mode = StatusBarLayout(rawValue: raw) else { return }
        layout = mode
    }

    @objc private func handleSettings() {
        SettingsWindowController.shared.showWindow()
    }

    @objc private func handleUpdates() {
        if let url = URL(string: "https://github.com/DylanGates/mini-max/releases") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func handleRestart() {
        let config = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: config)
        NSApp.terminate(nil)
    }
}
