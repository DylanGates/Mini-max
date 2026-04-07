import AppKit

// MARK: - Layout Mode

enum StatusBarLayout: String, CaseIterable {
    case primary      = "primary"       // ● 18:42  ● 12  ● 5  ● 3  ● 2
    case ultraCompact = "ultraCompact"  // ● ● ● ● ●  (hover for values)
    case badge        = "badge"         // ● 18:42  ● 12d  ● 5d  ● 3 events  ● 2 tasks

    var displayName: String {
        switch self {
        case .primary:      return "Primary — icon + value"
        case .ultraCompact: return "Ultra Compact — icons only"
        case .badge:        return "Badge — icon + labeled value"
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
        let symbol: String  // SF Symbol name
        let color: NSColor
        let label: String   // text shown next to icon (empty in ultraCompact)
        let tooltip: String
    }

    private func currentIndicators() -> [Indicator] {
        var indicators: [Indicator] = []

        // Pomodoro — only shown when a session is active
        if !PomodoroManager.shared.phase.isIdle {
            indicators.append(Indicator(
                symbol: "hourglass",
                color: IndicatorColor.pomodoro,
                label: layout == .ultraCompact ? "" : pomodoroLabel(),
                tooltip: "Pomodoro: \(pomodoroLabel())"
            ))
        }

        // GitHub streak — always shown; dimmed outline flame + nudge when no streak
        let streak = githubStreak()
        if streak > 0 {
            indicators.append(Indicator(
                symbol: "flame.fill",
                color: IndicatorColor.streak,
                label: layout == .ultraCompact ? "" : streakLabel(),
                tooltip: "GitHub streak: \(streak)d"
            ))
        } else {
            indicators.append(Indicator(
                symbol: "flame",          // outline = no active streak
                color: IndicatorColor.streak.withAlphaComponent(0.4),
                label: layout == .ultraCompact ? "" : "push?",
                tooltip: "No streak — push a commit today to start one"
            ))
        }

        return indicators
    }

    private func buildAttributedTitle(_ indicators: [Indicator]) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let font   = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        let iconPt: CGFloat = 11
        let gap    = layout == .ultraCompact ? "  " : "  "

        for (i, indicator) in indicators.enumerated() {
            // SF Symbol as NSTextAttachment
            result.append(makeSymbolAttachment(indicator.symbol, color: indicator.color, size: iconPt))

            // Label
            if !indicator.label.isEmpty {
                result.append(NSAttributedString(string: " \(indicator.label)", attributes: [
                    .foregroundColor: NSColor.labelColor,
                    .font: font
                ]))
            }

            if i < indicators.count - 1 {
                result.append(NSAttributedString(string: gap, attributes: [
                    .font: font,
                    .foregroundColor: NSColor.clear
                ]))
            }
        }

        return result
    }

    /// Renders an SF Symbol at `size` points, tinted with `color`, as an inline NSTextAttachment.
    private func makeSymbolAttachment(_ name: String, color: NSColor, size: CGFloat) -> NSAttributedString {
        let config = NSImage.SymbolConfiguration(pointSize: size, weight: .regular)
            .applying(NSImage.SymbolConfiguration(paletteColors: [color]))
        guard let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
                .withSymbolConfiguration(config) else {
            // Fallback to a colored dot if symbol unavailable
            return NSAttributedString(string: "●", attributes: [
                .foregroundColor: color,
                .font: NSFont.systemFont(ofSize: size)
            ])
        }
        let attachment = NSTextAttachment()
        attachment.image = image
        // Nudge baseline down by ~2pt so icon sits on the text baseline
        attachment.bounds = CGRect(x: 0, y: -2, width: size, height: size)
        return NSAttributedString(attachment: attachment)
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
