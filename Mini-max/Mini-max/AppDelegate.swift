import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var notchWindow: NotchWindow?
    private var overlayWindow: NotchOverlayWindow?
    private var statusBarController: StatusBarController!
    private var hotkeyManager: HotkeyManager!
    let viewModel = MiniMaxViewModel()

    private var hideWorkItem: DispatchWorkItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // no Dock icon

        requestAccessibilityIfNeeded()
        setupWindows()
        setupHotkey()
        setupStatusBar()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    // MARK: - Setup

    private func setupWindows() {
        guard let screen = NSScreen.main,
              let notchRect = screen.notchRect else {
            // No notch — menu bar icon is the only trigger
            return
        }

        notchWindow = NotchWindow()
        overlayWindow = NotchOverlayWindow()
        overlayWindow?.positionOver(notchRect: notchRect)

        overlayWindow?.onMouseEntered = { [weak self] in
            self?.cancelHideTimer()
            self?.showPanel()
        }

        overlayWindow?.onMouseExited = { [weak self] in
            self?.scheduleHide(after: 0.4)
        }

        addPanelMouseTracking()
    }

    private func addPanelMouseTracking() {
        guard let panel = notchWindow,
              let contentView = panel.contentView else { return }

        let area = NSTrackingArea(
            rect: contentView.bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: ["source": "panel"]
        )
        contentView.addTrackingArea(area)
    }

    private func setupHotkey() {
        hotkeyManager = HotkeyManager()
        hotkeyManager.onToggle = { [weak self] in
            guard let self else { return }
            viewModel.togglePanel()
            if viewModel.isPanelVisible {
                showPanel()
            } else {
                hidePanel()
            }
        }
        hotkeyManager.start()
    }

    private func setupStatusBar() {
        statusBarController = StatusBarController()
        statusBarController.onToggle = { [weak self] in
            guard let self else { return }
            viewModel.togglePanel()
            if viewModel.isPanelVisible {
                showPanelFromMenuBar()
            } else {
                hidePanel()
            }
        }
    }

    // MARK: - Show / Hide

    private func showPanel() {
        guard let screen = NSScreen.main,
              let notchRect = screen.notchRect else { return }
        if notchWindow == nil { notchWindow = NotchWindow() }
        notchWindow?.show(relativeTo: notchRect, on: screen)
        viewModel.showPanel()
    }

    private func showPanelFromMenuBar() {
        guard let screen = NSScreen.main else { return }
        if notchWindow == nil { notchWindow = NotchWindow() }
        let panelWidth: CGFloat = 400
        let panelHeight: CGFloat = 500
        let fallbackRect = CGRect(
            x: screen.frame.midX - panelWidth / 2,
            y: screen.frame.maxY - panelHeight - 28,
            width: panelWidth,
            height: panelHeight
        )
        notchWindow?.show(relativeTo: fallbackRect, on: screen)
        viewModel.showPanel()
    }

    private func hidePanel() {
        notchWindow?.hide()
        viewModel.hidePanel()
    }

    // MARK: - Mouse Tracking (Panel)

    override func mouseEntered(with event: NSEvent) {
        cancelHideTimer()
    }

    override func mouseExited(with event: NSEvent) {
        hidePanel()
    }

    // MARK: - Hide Timer

    private func scheduleHide(after delay: TimeInterval) {
        let item = DispatchWorkItem { [weak self] in
            self?.hidePanel()
        }
        hideWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    private func cancelHideTimer() {
        hideWorkItem?.cancel()
        hideWorkItem = nil
    }

    // MARK: - Accessibility

    private func requestAccessibilityIfNeeded() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
        let trusted = AXIsProcessTrustedWithOptions(options)
        if !trusted {
            print("Mini-Max: Accessibility permission not granted — global hotkey disabled.")
        }
    }
}
