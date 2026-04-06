import AppKit

final class StatusBarController {
    private var statusItem: NSStatusItem
    var onToggle: (() -> Void)?

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "m.square.fill", accessibilityDescription: "Mini-Max")
            button.action = #selector(handleClick)
            button.target = self
        }
    }

    @objc private func handleClick() {
        onToggle?()
    }
}
