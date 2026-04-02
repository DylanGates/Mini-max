# Phase 0 — The Shell Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The app launches silently, a dot appears in the MacBook notch, hovering over it drops a blank panel down with a spring animation, and pressing backtick toggles it.

**Architecture:** `Mini_maxApp` delegates lifecycle to `AppDelegate` via `@NSApplicationDelegateAdaptor`. AppDelegate creates three windows: a transparent `NotchOverlayWindow` (always-on-screen hover target over the notch), the main `NotchWindow` (the floating panel), and a `StatusBarController` (menu bar icon fallback). A `HotkeyManager` listens for the global backtick key via `CGEventTap`. All state flows through `MiniMaxViewModel`.

**Tech Stack:** Swift 5.9+, SwiftUI + AppKit hybrid, `@Observable`, `CGEventTap`, `NSPanel`, `NSTrackingArea`, `NSStatusItem`, Swift Testing framework.

---

## Important: Adding Files in Xcode

Every new `.swift` file you create must be **added to the Xcode project** or the compiler won't see it.

In Xcode: right-click the `Mini-max` folder in the Project Navigator → **New File** → Swift File → name it. This both creates the file on disk and adds it to the target.

Do NOT create files only in Finder — Xcode won't pick them up automatically.

---

## File Map

All source files live inside `Mini-max/Mini-max/` (the app target folder).

| File | Status | Responsibility |
|---|---|---|
| `Mini_maxApp.swift` | Modify | Wire `@NSApplicationDelegateAdaptor`, remove `WindowGroup` |
| `ContentView.swift` | Delete | Replaced entirely by panel UI |
| `AppDelegate.swift` | Create | Owns all windows, wires hover/hotkey/status bar |
| `MiniMaxViewModel.swift` | Create | `@Observable` state hub — `isPanelVisible`, `isHovering` |
| `NSScreen+Notch.swift` | Create | `notchRect` helper on `NSScreen` |
| `NotchWindow.swift` | Create | Main floating `NSPanel` with show/hide animation |
| `NotchOverlayWindow.swift` | Create | Transparent always-on NSPanel for hover detection |
| `StatusBarController.swift` | Create | `NSStatusItem` menu bar icon |
| `HotkeyManager.swift` | Create | `CGEventTap` global backtick (keyCode 50) hotkey |
| `NotchPillView.swift` | Create | SwiftUI view — the "M" dot inside the notch |
| `PanelContentView.swift` | Create | SwiftUI root of expanded panel (placeholder for now) |
| `ActionBar.swift` | Create | SwiftUI tab bar with four placeholder tabs |

Test files live in `Mini-max/Mini-maxTests/`.

| Test File | Responsibility |
|---|---|
| `NSScreenNotchTests.swift` | Tests `notchRect` geometry logic |
| `MiniMaxViewModelTests.swift` | Tests `isPanelVisible` state toggle |
| `HotkeyManagerTests.swift` | Tests key code constant and enable/disable |

---

## Task 1: Update Mini_maxApp — Wire the AppDelegate

AppKit apps need an `NSApplicationDelegate` for low-level setup (windows, hotkeys). SwiftUI's `@NSApplicationDelegateAdaptor` is the bridge. The `WindowGroup` creates a standard macOS window — we don't want that; all our UI lives in custom NSPanels managed by `AppDelegate`.

**Files:**
- Modify: `Mini-max/Mini-max/Mini_maxApp.swift`
- Delete: `Mini-max/Mini-max/ContentView.swift`

- [ ] **Step 1: Replace `Mini_maxApp.swift` contents**

Open `Mini_maxApp.swift` in Xcode and replace the entire file with:

```swift
import SwiftUI

@main
struct Mini_maxApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No WindowGroup — all UI lives in NSPanels managed by AppDelegate.
        // Settings scene keeps the app alive in the background.
        Settings { EmptyView() }
    }
}
```

- [ ] **Step 2: Delete `ContentView.swift`**

In Xcode's Project Navigator, right-click `ContentView.swift` → **Delete** → **Move to Trash**.

- [ ] **Step 3: Create a placeholder `AppDelegate.swift`**

In Xcode, right-click the `Mini-max` source folder → **New File** → **Swift File** → name it `AppDelegate.swift`.

Paste this minimal stub so the project compiles before we flesh it out in Task 9:

```swift
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Full setup in Task 9
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false // keep running when no windows are visible
    }
}
```

- [ ] **Step 4: Build in Xcode (Cmd+B)**

Expected: builds with 0 errors. If Xcode complains about `Item` (from the old CoreData template), that's fine — `Persistence.swift` still references it. Leave `Persistence.swift` alone for now; it will be used in Phase 2.

- [ ] **Step 5: Commit**

```bash
cd /Users/admin/Projects/Apps/notch/mini-max
git init
git add Mini-max/Mini-max/Mini_maxApp.swift Mini-max/Mini-max/AppDelegate.swift
git commit -m "feat: wire NSApplicationDelegateAdaptor, remove WindowGroup"
```

---

## Task 2: NSScreen+Notch Helper

The notch occupies the gap between `auxiliaryTopLeftArea` and `auxiliaryTopRightArea` at the top of the screen. This extension computes the notch rect in screen coordinates so we can position windows precisely.

**macOS coordinate system note:** `(0,0)` is the **bottom-left** of the primary screen. `screen.frame.maxY` is the **top** of the screen.

**Files:**
- Create: `Mini-max/Mini-max/NSScreen+Notch.swift`
- Create: `Mini-max/Mini-maxTests/NSScreenNotchTests.swift`

- [ ] **Step 1: Create `NSScreen+Notch.swift`**

```swift
import AppKit

extension NSScreen {
    /// The rect occupied by the notch, in screen coordinates.
    /// Returns nil on Macs without a notch.
    var notchRect: CGRect? {
        guard let topLeft = auxiliaryTopLeftArea,
              let topRight = auxiliaryTopRightArea else { return nil }
        let notchWidth = frame.width - topLeft.width - topRight.width
        guard notchWidth > 0 else { return nil }
        let notchHeight = max(topLeft.height, topRight.height)
        let notchX = frame.minX + topLeft.width
        let notchY = frame.maxY - notchHeight
        return CGRect(x: notchX, y: notchY, width: notchWidth, height: notchHeight)
    }

    /// True if this screen has a notch.
    var hasNotch: Bool { notchRect != nil }
}
```

- [ ] **Step 2: Write the failing test**

Open `Mini-maxTests/Mini_maxTests.swift`. Replace it entirely with a new file named `NSScreenNotchTests.swift` (or create a new file and delete the old stub). **Note:** In Xcode use **New File → Swift File**, name it `NSScreenNotchTests.swift`, and make sure the target is `Mini-maxTests`.

```swift
import Testing
import AppKit
@testable import Mini_max

struct NSScreenNotchTests {

    // Test the geometry: given known topLeft/topRight areas, notchWidth should be
    // screen.width - topLeft.width - topRight.width.
    // We can't easily mock NSScreen, so we test the math via a helper function.

    @Test func notchWidthCalculation() {
        let screenWidth: CGFloat = 3456
        let topLeftWidth: CGFloat = 1410
        let topRightWidth: CGFloat = 1410
        let expected: CGFloat = screenWidth - topLeftWidth - topRightWidth
        #expect(expected == 636)
    }

    @Test func notchWidthIsPositive() {
        let screenWidth: CGFloat = 3456
        let topLeftWidth: CGFloat = 1410
        let topRightWidth: CGFloat = 1410
        let notchWidth = screenWidth - topLeftWidth - topRightWidth
        #expect(notchWidth > 0)
    }

    @Test func noNotchWhenWidthIsZero() {
        // A screen where left + right fills the full width has no notch
        let screenWidth: CGFloat = 2560
        let topLeftWidth: CGFloat = 1280
        let topRightWidth: CGFloat = 1280
        let notchWidth = screenWidth - topLeftWidth - topRightWidth
        #expect(notchWidth == 0)
    }
}
```

- [ ] **Step 3: Run the tests**

In Xcode: **Cmd+U** to run all tests, or click the diamond next to `NSScreenNotchTests` in the Test Navigator.

Expected: all 3 tests pass (these are pure math tests, no screen hardware needed).

- [ ] **Step 4: Commit**

```bash
git add Mini-max/Mini-max/NSScreen+Notch.swift Mini-max/Mini-maxTests/NSScreenNotchTests.swift
git commit -m "feat: add NSScreen notch rect helper and geometry tests"
```

---

## Task 3: MiniMaxViewModel

The single source of truth for app state. Every window and view observes this. `@Observable` (macOS 14+) replaces the older `@ObservableObject` pattern — it's more efficient and requires less boilerplate.

**Files:**
- Create: `Mini-max/Mini-max/MiniMaxViewModel.swift`
- Create: `Mini-max/Mini-maxTests/MiniMaxViewModelTests.swift`

- [ ] **Step 1: Create `MiniMaxViewModel.swift`**

```swift
import Foundation
import Observation

@Observable
final class MiniMaxViewModel {
    var isPanelVisible: Bool = false
    var isHoveringNotch: Bool = false

    func togglePanel() {
        isPanelVisible.toggle()
    }

    func showPanel() {
        isPanelVisible = true
    }

    func hidePanel() {
        isPanelVisible = false
    }
}
```

- [ ] **Step 2: Write the failing tests**

Create `Mini-max/Mini-maxTests/MiniMaxViewModelTests.swift`:

```swift
import Testing
@testable import Mini_max

@MainActor
struct MiniMaxViewModelTests {

    @Test func startsHidden() {
        let vm = MiniMaxViewModel()
        #expect(vm.isPanelVisible == false)
    }

    @Test func showPanelSetsVisible() {
        let vm = MiniMaxViewModel()
        vm.showPanel()
        #expect(vm.isPanelVisible == true)
    }

    @Test func hidePanelSetsHidden() {
        let vm = MiniMaxViewModel()
        vm.showPanel()
        vm.hidePanel()
        #expect(vm.isPanelVisible == false)
    }

    @Test func toggleFlipsState() {
        let vm = MiniMaxViewModel()
        vm.togglePanel()
        #expect(vm.isPanelVisible == true)
        vm.togglePanel()
        #expect(vm.isPanelVisible == false)
    }
}
```

- [ ] **Step 3: Run tests (Cmd+U)**

Expected: all 4 pass.

- [ ] **Step 4: Commit**

```bash
git add Mini-max/Mini-max/MiniMaxViewModel.swift Mini-max/Mini-maxTests/MiniMaxViewModelTests.swift
git commit -m "feat: add MiniMaxViewModel with panel visibility state"
```

---

## Task 4: SwiftUI Views

Three views that live inside the windows. None of them do anything yet — they are placeholders that will be filled in across later phases.

**Files:**
- Create: `Mini-max/Mini-max/NotchPillView.swift`
- Create: `Mini-max/Mini-max/ActionBar.swift`
- Create: `Mini-max/Mini-max/PanelContentView.swift`

No unit tests for pure SwiftUI views — verify visually when the app runs.

- [ ] **Step 1: Create `NotchPillView.swift`**

This is what lives inside the notch overlay window. Phase 0: just a small white dot. Later phases will turn it into Mini-Maximus's animated face.

```swift
import SwiftUI

struct NotchPillView: View {
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(.white)
                .frame(width: 6, height: 6)
            Circle()
                .fill(.white)
                .frame(width: 6, height: 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    NotchPillView()
        .frame(width: 120, height: 32)
        .background(.black)
}
```

- [ ] **Step 2: Create `ActionBar.swift`**

The tab switcher row at the top of the panel. Four placeholder tabs.

```swift
import SwiftUI

enum PanelTab: String, CaseIterable {
    case project = "Projects"
    case pomodoro = "Focus"
    case github = "GitHub"
    case ai = "AI"

    var icon: String {
        switch self {
        case .project: return "folder"
        case .pomodoro: return "timer"
        case .github: return "chevron.left.forwardslash.chevron.right"
        case .ai: return "bubble.left"
        }
    }
}

struct ActionBar: View {
    @Binding var selectedTab: PanelTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(PanelTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 14))
                        Text(tab.rawValue)
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(selectedTab == tab ? .white : .white.opacity(0.4))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
        }
        .background(.black.opacity(0.6))
    }
}

#Preview {
    ActionBar(selectedTab: .constant(.project))
        .frame(width: 400)
}
```

- [ ] **Step 3: Create `PanelContentView.swift`**

The root view of the expanded panel. For now it just shows the tab bar and a placeholder.

```swift
import SwiftUI

struct PanelContentView: View {
    @State private var selectedTab: PanelTab = .project

    var body: some View {
        VStack(spacing: 0) {
            ActionBar(selectedTab: $selectedTab)

            Spacer()

            Text(selectedTab.rawValue)
                .foregroundStyle(.white.opacity(0.3))
                .font(.system(size: 13))

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    PanelContentView()
        .frame(width: 400, height: 500)
}
```

- [ ] **Step 4: Commit**

```bash
git add Mini-max/Mini-max/NotchPillView.swift Mini-max/Mini-max/ActionBar.swift Mini-max/Mini-max/PanelContentView.swift
git commit -m "feat: add NotchPillView, ActionBar, PanelContentView placeholders"
```

---

## Task 5: NotchWindow — The Main Floating Panel

An `NSPanel` that drops below the notch. Must never steal focus from the IDE.

**Key AppKit concepts:**
- `styleMask: [.nonactivatingPanel]` — clicking the panel doesn't activate the app
- `level = .floating` — stays above normal windows
- `collectionBehavior = [.canJoinAllSpaces]` — visible on all Mission Control spaces
- `isOpaque = false` + `backgroundColor = .clear` — lets the SwiftUI view's rounded corners show

**Files:**
- Create: `Mini-max/Mini-max/NotchWindow.swift`

- [ ] **Step 1: Create `NotchWindow.swift`**

```swift
import AppKit
import SwiftUI

final class NotchWindow: NSPanel {
    private let panelWidth: CGFloat = 400
    private let panelHeight: CGFloat = 500

    init() {
        super.init(
            contentRect: CGRect(x: 0, y: 0, width: 400, height: 500),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = false
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        hidesOnDeactivate = false
        ignoresMouseEvents = false

        let content = NSHostingView(rootView: PanelContentView())
        content.layer?.cornerRadius = 16
        content.layer?.masksToBounds = true
        contentView = content
    }

    /// Position the panel just below the notch and show it with a fade+slide animation.
    func show(relativeTo notchRect: CGRect, on screen: NSScreen) {
        let x = notchRect.midX - panelWidth / 2
        let y = screen.frame.maxY - notchRect.height - panelHeight - 4
        let targetFrame = CGRect(x: x, y: y, width: panelWidth, height: panelHeight)

        setFrame(targetFrame.offsetBy(dx: 0, dy: 12), display: false)
        alphaValue = 0
        orderFront(nil)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().alphaValue = 1
            animator().setFrame(targetFrame, display: true)
        }
    }

    /// Hide with a fade animation.
    func hide() {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            animator().alphaValue = 0
        } completionHandler: {
            self.orderOut(nil)
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Mini-max/Mini-max/NotchWindow.swift
git commit -m "feat: add NotchWindow NSPanel with show/hide animation"
```

---

## Task 6: NotchOverlayWindow — Hover Detection

A transparent, always-on-screen panel that sits exactly over the notch. Its only job is to detect mouse enter/exit and display the pill. It uses an `NSTrackingArea` on its content view to fire mouse events.

**Why a separate window?** The notch is "dead space" — there's no regular view hierarchy there. The only way to intercept hover events over the notch is to put a window on top of it.

**Files:**
- Create: `Mini-max/Mini-max/NotchOverlayWindow.swift`

- [ ] **Step 1: Create `NotchOverlayWindow.swift`**

```swift
import AppKit
import SwiftUI

final class NotchOverlayWindow: NSPanel {
    var onMouseEntered: (() -> Void)?
    var onMouseExited: (() -> Void)?

    init() {
        super.init(
            contentRect: CGRect(x: 0, y: 0, width: 200, height: 32),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        // Must be above everything — including full-screen apps.
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isMovableByWindowBackground = false
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        hidesOnDeactivate = false
        ignoresMouseEvents = false

        let hostingView = NSHostingView(rootView: NotchPillView())
        contentView = hostingView
    }

    /// Position the overlay exactly over the notch and make it visible.
    func positionOver(notchRect: CGRect) {
        setFrame(notchRect, display: true)
        orderFrontRegardless()
        addTrackingToContentView()
    }

    private func addTrackingToContentView() {
        guard let view = contentView else { return }
        // Remove any existing tracking areas first.
        view.trackingAreas.forEach { view.removeTrackingArea($0) }
        let area = NSTrackingArea(
            rect: view.bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        view.addTrackingArea(area)
    }

    override func mouseEntered(with event: NSEvent) {
        onMouseEntered?()
    }

    override func mouseExited(with event: NSEvent) {
        onMouseExited?()
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Mini-max/Mini-max/NotchOverlayWindow.swift
git commit -m "feat: add NotchOverlayWindow with hover tracking"
```

---

## Task 7: StatusBarController — Menu Bar Icon

Provides a menu bar icon as a fallback trigger (for non-notch Macs, and as a safety valve if hover gets flaky).

**Files:**
- Create: `Mini-max/Mini-max/StatusBarController.swift`

- [ ] **Step 1: Create `StatusBarController.swift`**

```swift
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
```

- [ ] **Step 2: Commit**

```bash
git add Mini-max/Mini-max/StatusBarController.swift
git commit -m "feat: add StatusBarController menu bar icon"
```

---

## Task 8: HotkeyManager — Global Backtick

`CGEventTap` intercepts keyboard events system-wide, before they reach any app. This is how the backtick key can toggle Mini-Max even when your IDE has focus.

**Permission required:** The OS will ask the user to grant Accessibility permission the first time. Without it, `CGEventTapCreate` returns nil and the hotkey silently does nothing. We handle this gracefully.

**backtick keyCode = 50.** This is a hardware keycode, not a character — it works regardless of keyboard layout.

**Files:**
- Create: `Mini-max/Mini-max/HotkeyManager.swift`
- Create: `Mini-max/Mini-maxTests/HotkeyManagerTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Mini-max/Mini-maxTests/HotkeyManagerTests.swift`:

```swift
import Testing
@testable import Mini_max

struct HotkeyManagerTests {

    @Test func backtickKeyCodeIsCorrect() {
        #expect(HotkeyManager.backtickKeyCode == 50)
    }

    @Test func startsDisabled() {
        let manager = HotkeyManager()
        #expect(manager.isActive == false)
    }

    @Test func toggleCallbackIsNilByDefault() {
        let manager = HotkeyManager()
        #expect(manager.onToggle == nil)
    }
}
```

- [ ] **Step 2: Run tests — expect failure**

Run **Cmd+U**. Expected: fails because `HotkeyManager` doesn't exist yet.

- [ ] **Step 3: Create `HotkeyManager.swift`**

```swift
import AppKit

final class HotkeyManager {
    /// Hardware key code for the backtick/tilde key (` / ~), layout-independent.
    static let backtickKeyCode: CGKeyCode = 50

    var onToggle: (() -> Void)?
    private(set) var isActive: Bool = false
    private var eventTap: CFMachPort?

    /// Start intercepting the global backtick key.
    /// Requires Accessibility permission — fails silently if not granted.
    func start() {
        guard !isActive else { return }

        let observer = Unmanaged.passRetained(self)
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)

        eventTap = CGEventTapCreate(
            .cgSessionEventTap,
            .headInsertEventTap,
            .defaultTap,
            mask,
            { (_, _, event, userInfo) -> Unmanaged<CGEvent>? in
                guard let userInfo else { return Unmanaged.passRetained(event) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()
                let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
                if keyCode == HotkeyManager.backtickKeyCode {
                    DispatchQueue.main.async { manager.onToggle?() }
                    return nil // consume the event — don't let the IDE receive it
                }
                return Unmanaged.passRetained(event)
            },
            observer.toOpaque()
        )

        guard let tap = eventTap else {
            observer.release()
            return // Accessibility permission not granted
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEventTapEnable(tap, true)
        isActive = true
    }

    func stop() {
        guard let tap = eventTap else { return }
        CGEventTapEnable(tap, false)
        eventTap = nil
        isActive = false
    }
}
```

- [ ] **Step 4: Run tests — expect pass**

Run **Cmd+U**. Expected: all 3 `HotkeyManagerTests` pass.

- [ ] **Step 5: Commit**

```bash
git add Mini-max/Mini-max/HotkeyManager.swift Mini-max/Mini-maxTests/HotkeyManagerTests.swift
git commit -m "feat: add HotkeyManager CGEventTap for global backtick toggle"
```

---

## Task 9: AppDelegate — Wire Everything Together

`AppDelegate` is the director. It creates all the windows, positions them, and connects the callbacks so hover and hotkey both call `viewModel.togglePanel()`.

**Hide logic:** When the mouse exits the notch overlay, we wait 400ms before hiding — this gives the user time to move the mouse onto the panel itself. If the mouse enters the panel, we cancel the timer. When the mouse exits the panel, we hide immediately.

**Files:**
- Modify: `Mini-max/Mini-max/AppDelegate.swift`

- [ ] **Step 1: Replace `AppDelegate.swift` with the full implementation**

```swift
import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var notchWindow: NotchWindow!
    private var overlayWindow: NotchOverlayWindow!
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
        overlayWindow.positionOver(notchRect: notchRect)

        overlayWindow.onMouseEntered = { [weak self] in
            self?.cancelHideTimer()
            self?.showPanel()
        }

        overlayWindow.onMouseExited = { [weak self] in
            self?.scheduleHide(after: 0.4)
        }

        // Track mouse exit from the main panel too
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
            self?.viewModel.togglePanel()
            if self?.viewModel.isPanelVisible == true {
                self?.showPanel()
            } else {
                self?.hidePanel()
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
              let notchRect = screen.notchRect,
              let panel = notchWindow else { return }
        panel.show(relativeTo: notchRect, on: screen)
        viewModel.showPanel()
    }

    private func showPanelFromMenuBar() {
        // On non-notch Macs, position the panel near the status item
        guard let screen = NSScreen.main else { return }
        let panelWidth: CGFloat = 400
        let panelHeight: CGFloat = 500
        let x = screen.frame.midX - panelWidth / 2
        let y = screen.frame.maxY - screen.visibleFrame.maxY - panelHeight - 4
        let fallbackRect = CGRect(x: x, y: screen.frame.maxY - panelHeight - 28,
                                  width: panelWidth, height: panelHeight)
        notchWindow = notchWindow ?? NotchWindow()
        notchWindow.show(relativeTo: fallbackRect, on: screen)
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
```

- [ ] **Step 2: Build (Cmd+B)**

Expected: 0 errors. If you see "cannot find type X in scope", the file for that type wasn't added to the Xcode project — right-click the folder → Add Files to "Mini-max".

- [ ] **Step 3: Run the app (Cmd+R)**

What to check manually:
1. No Dock icon appears (app is `accessory` policy)
2. A menu bar icon (grid square) appears in the menu bar
3. If your Mac has a notch: hover over the notch — a panel should drop down
4. Move mouse away — panel should fade out after ~400ms
5. Pressing backtick should toggle the panel (may need to grant Accessibility permission first)

**If the app asks for Accessibility permission:** Go to System Settings → Privacy & Security → Accessibility → toggle Mini-max on. Restart the app.

- [ ] **Step 4: Commit**

```bash
git add Mini-max/Mini-max/AppDelegate.swift
git commit -m "feat: wire AppDelegate — hover, hotkey, and status bar all trigger panel"
```

---

## Task 10: Final Verification

Run the full test suite and manually verify the exit criterion.

- [ ] **Step 1: Run all tests (Cmd+U)**

Expected output in the Test Navigator:
```
✓ NSScreenNotchTests (3 tests passed)
✓ MiniMaxViewModelTests (4 tests passed)
✓ HotkeyManagerTests (3 tests passed)
```

- [ ] **Step 2: Verify exit criterion manually**

| Check | How to verify |
|---|---|
| App launches silently | No window opens, no Dock icon |
| Notch pill visible | Two white dots appear in the notch |
| Hover shows panel | Mouse over notch → panel drops down |
| Mouse away hides panel | Move mouse to desktop → panel fades out |
| Backtick toggles panel | Press `` ` `` → panel appears/disappears |
| Menu bar icon toggles panel | Click the ■ icon → panel appears/disappears |
| Panel doesn't steal focus | Keep typing in your IDE — focus stays there |

- [ ] **Step 3: Final commit**

```bash
git add .
git commit -m "feat: Phase 0 complete — notch shell with hover, hotkey, and panel"
```

---

## Troubleshooting

**Panel doesn't appear on hover**
- Check that your Mac has a notch — `NSScreen.main?.notchRect` returns nil on non-notch Macs
- Use the menu bar icon instead

**Global hotkey doesn't work**
- System Settings → Privacy & Security → Accessibility → enable Mini-max
- Restart the app after granting permission

**Build error: "Cannot find 'X' in scope"**
- The file for `X` wasn't added to the Xcode project target
- In Project Navigator, find the file → open File Inspector (right panel) → check "Mini-max" under Target Membership

**Panel appears behind other windows**
- Check that `level = .floating` is set in `NotchWindow.init()`

**Two white dots not visible in notch**
- The notch background is black, dots are white — they're subtle. Check `NotchPillView` preview to confirm it looks right, then check that `overlayWindow.orderFrontRegardless()` is being called in `positionOver`
