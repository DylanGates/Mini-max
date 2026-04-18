import AppKit

// MARK: - StatusBarController

@MainActor
final class StatusBarController {
    private let statusItem: NSStatusItem
    private var refreshTimer: Timer?

    var onToggle: (() -> Void)?

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
        // 1s tick — live Pomodoro countdown
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.updateDisplay() }
        }
        refreshTimer?.tolerance = 0.1
    }

    // MARK: - Display

    func updateDisplay() {
        guard let button = statusItem.button else { return }
        button.attributedTitle = buildTitle()
        button.toolTip = buildTooltip()
    }

    private func buildTitle() -> NSAttributedString {
        let result = NSMutableAttributedString()
        let font   = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)

        // Eyes — always present, the brand mark
        let eyeAttachment = NSTextAttachment()
        eyeAttachment.image = makeEyesImage()
        eyeAttachment.bounds = CGRect(x: 0, y: -2.5, width: 30, height: 10)
        result.append(NSAttributedString(attachment: eyeAttachment))

        // Pomodoro countdown — only when a session is running
        if !PomodoroManager.shared.phase.isIdle {
            let label = pomodoroLabel()
            result.append(NSAttributedString(
                string: "  \(label)",
                attributes: [
                    .font: font,
                    .foregroundColor: NSColor(red: 1.0, green: 0.45, blue: 0.36, alpha: 1) // #FF7460
                ]
            ))
        }

        // Streak — only when streak is active (> 0)
        let streak = githubStreak()
        if streak > 0 {
            result.append(NSAttributedString(
                string: "  \(streak)",
                attributes: [
                    .font: font,
                    .foregroundColor: NSColor(red: 1.0, green: 0.624, blue: 0.039, alpha: 1) // #FF9F0A
                ]
            ))
        }

        return result
    }

    private func buildTooltip() -> String {
        var lines: [String] = []
        if !PomodoroManager.shared.phase.isIdle {
            lines.append("Pomodoro: \(pomodoroLabel())")
        }
        let streak = githubStreak()
        if streak > 0 {
            lines.append("GitHub streak: \(streak)d")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Eyes image

    /// Two circles joined by a thick horizontal bridge.
    /// Circle radius = 5pt. Bridge height = half the radius = 2.5pt.
    private func makeEyesImage() -> NSImage {
        let r: CGFloat = 5          // circle radius
        let bridge: CGFloat = r / 2 // 2.5pt — half the radius
        let gap: CGFloat = 6        // space between the two circle edges
        let d = r * 2               // diameter = 10
        let w = d + gap + d         // total width = 26
        let h = d                   // total height = 10

        let size = NSSize(width: w, height: h)
        return NSImage(size: size, flipped: false) { rect in
            NSColor.white.withAlphaComponent(0.82).setFill()

            // Left circle
            NSBezierPath(ovalIn: NSRect(x: 0, y: 0, width: d, height: d)).fill()

            // Right circle
            NSBezierPath(ovalIn: NSRect(x: d + gap, y: 0, width: d, height: d)).fill()

            // Bridge — centered vertically, spanning between the two circle centers
            let bridgeY = (h - bridge) / 2
            NSBezierPath(rect: NSRect(x: r, y: bridgeY, width: gap + d, height: bridge)).fill()
            
            return true
        }
    }

    // MARK: - Data helpers

    private func pomodoroLabel() -> String {
        let phase = PomodoroManager.shared.phase
        guard !phase.isIdle else { return "–" }
        let r = phase.remaining
        return String(format: "%d:%02d", Int(r) / 60, Int(r) % 60)
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
            statusItem.menu = buildContextMenu()
            statusItem.button?.performClick(nil)
            DispatchQueue.main.async { [weak self] in self?.statusItem.menu = nil }
        } else {
            onToggle?()
        }
    }

    private func buildContextMenu() -> NSMenu {
        let menu = NSMenu()

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

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Mini-Max", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        return menu
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
