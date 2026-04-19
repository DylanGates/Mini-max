import AppKit
import SwiftUI

final class NotchOverlayWindow: NSPanel {
    var onMouseEntered: (() -> Void)?
    var onMouseExited: (() -> Void)?

    let displayState = NotchDisplayState()
    private var collapsedRect: CGRect = .zero

    init() {
        super.init(
            contentRect: CGRect(x: 0, y: 0, width: 200, height: 32),
            styleMask: [.borderless, .nonactivatingPanel, .utilityWindow, .hudWindow, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 3)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isMovableByWindowBackground = false
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        hidesOnDeactivate = false
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true

        let hostingView = NSHostingView(rootView: NotchShellView(state: displayState))
        hostingView.layer?.backgroundColor = .clear
        hostingView.autoresizingMask = [.width, .height]
        
        if #available(macOS 13.0, *) {
            hostingView.sizingOptions = []
        }
        contentView = hostingView
    }

    /// How many points the pill extends below the real hardware notch.
    static let bottomExtension: CGFloat = 6
    /// Extra width on each side for the outer gutter blend curves.
    static let gutterWidth: CGFloat = 0

    func positionOver(notchRect: CGRect) {
        let g = NotchOverlayWindow.gutterWidth
        let extendedRect = CGRect(
            x: notchRect.minX - g,
            y: notchRect.minY - NotchOverlayWindow.bottomExtension,
            width: notchRect.width + 2 * g,
            height: notchRect.height + NotchOverlayWindow.bottomExtension
        )
        collapsedRect = extendedRect
        setFrame(extendedRect, display: false)
        orderFrontRegardless()
        addTracking(for: extendedRect.size)
    }

    func expand(on screen: NSScreen) {
        guard !displayState.isExpanded else { return }
        let expandedWidth: CGFloat = 580
        let expandedHeight: CGFloat = 212
        let x = screen.frame.midX - expandedWidth / 2
        let y = screen.frame.maxY - expandedHeight
        let expandedFrame = CGRect(x: x, y: y, width: expandedWidth, height: expandedHeight)

        setFrame(expandedFrame, display: false)
        displayState.isExpanded = true
        // Use explicit size — view.bounds is stale after display:false (layout pass deferred)
        addTracking(for: CGSize(width: expandedWidth, height: expandedHeight))
    }

    func collapse() {
        guard collapsedRect != .zero else { return }
        displayState.isExpanded = false
        resignKey()

        // Wait for the close spring (response:0.45, df:1.0) to settle before snapping
        // the frame — a mid-animation frame change triggers the constraint loop.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { [weak self] in
            guard let self else { return }
            self.setFrame(self.collapsedRect, display: false)
            self.addTracking(for: self.collapsedRect.size)
        }
    }

    /// Replaces all tracking areas on the content view with one covering `size`.
    /// Takes an explicit size because view.bounds can be stale after setFrame(..., display:false).
    private func addTracking(for size: CGSize) {
        guard let view = contentView else { return }
        view.trackingAreas.forEach { view.removeTrackingArea($0) }
        let area = NSTrackingArea(
            rect: CGRect(origin: .zero, size: size),
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        view.addTrackingArea(area)
    }

    override var canBecomeKey: Bool { true }

    override func mouseDown(with event: NSEvent) {
        if displayState.isExpanded {
            NSApp.activate(ignoringOtherApps: true)
            makeKey()
        }
        super.mouseDown(with: event)
    }

    override func mouseEntered(with event: NSEvent) {
        onMouseEntered?()
    }

    override func mouseExited(with event: NSEvent) {
        onMouseExited?()
    }
}
