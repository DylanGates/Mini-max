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
        let screen = NSScreen.builtIn
        print("[MiniMax] builtIn screen: \(screen?.localizedName ?? "nil")")
        print("[MiniMax] screen.frame: \(screen?.frame as Any)")
        print("[MiniMax] auxiliaryTopLeft: \(screen?.auxiliaryTopLeftArea as Any)")
        print("[MiniMax] auxiliaryTopRight: \(screen?.auxiliaryTopRightArea as Any)")
        print("[MiniMax] safeAreaInsets.top: \(screen?.safeAreaInsets.top as Any)")

        guard let screen = screen, let notchRect = screen.notchRect else {
            print("[MiniMax] ⚠️ No notch detected — overlay window skipped")
            return
        }

        print("[MiniMax] ✅ Notch rect: \(notchRect)")

        notchWindow = NotchWindow()
        overlayWindow = NotchOverlayWindow()
        overlayWindow?.positionOver(notchRect: notchRect)
        print("[MiniMax] Overlay window frame: \(overlayWindow?.frame as Any)")

        overlayWindow?.onMouseEntered = { [weak self] in
            self?.cancelHideTimer()
            self?.showPanel()
        }

        overlayWindow?.onMouseExited = { [weak self] in
            self?.scheduleHide(after: 0.4)
        }

        notchWindow?.onMouseEntered = { [weak self] in self?.cancelHideTimer() }
        notchWindow?.onMouseExited = { [weak self] in self?.hidePanel() }
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
        guard let screen = NSScreen.builtIn,
              let notchRect = screen.notchRect else { return }
        if notchWindow == nil { notchWindow = NotchWindow() }
        notchWindow?.show(relativeTo: notchRect, on: screen)
        notchWindow?.setupMouseTracking()
        viewModel.showPanel()
    }

    private func showPanelFromMenuBar() {
        guard let screen = NSScreen.builtIn else { return }
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
        notchWindow?.setupMouseTracking()
        viewModel.showPanel()
    }

    private func hidePanel() {
        notchWindow?.hide()
        viewModel.hidePanel()
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

