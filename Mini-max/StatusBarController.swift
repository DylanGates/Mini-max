import AppKit

final class StatusBarController {
    private var statusItem: NSStatusItem
    var onToggle: (() -> Void)?

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "m.square.fill", accessibilityDescription: "Mini-Max")
        }
        statusItem.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let settings = NSMenuItem(title: "Settings", action: #selector(handleSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let updates = NSMenuItem(title: "Check for Updates…", action: #selector(handleUpdates), keyEquivalent: "")
        updates.target = self
        menu.addItem(updates)

        menu.addItem(.separator())

        let restart = NSMenuItem(title: "Restart Mini-Max", action: #selector(handleRestart), keyEquivalent: "")
        restart.target = self
        menu.addItem(restart)

        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        return menu
    }

    @objc private func handleSettings() {
        SettingsWindowController.shared.showWindow()
    }

    @objc private func handleUpdates() {
        if let url = URL(string: "https://github.com/your-repo/mini-max/releases") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func handleRestart() {
        let config = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: config)
        NSApp.terminate(nil)
    }
}
