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
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
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
        // Allow text fields to receive keyboard input when user clicks inside
        acceptsMouseMovedEvents = true

        let hostingView = NSHostingView(rootView: NotchShellView(state: displayState))
        hostingView.layer?.backgroundColor = .clear
        contentView = hostingView
    }

    /// How many points the pill extends below the real hardware notch.
    static let bottomExtension: CGFloat = 12
    /// Extra width on each side for the outer gutter blend curves.
    static let gutterWidth: CGFloat = 10

    /// Position the overlay to cover the notch + extend below it + gutter on each side.
    func positionOver(notchRect: CGRect) {
        let g = NotchOverlayWindow.gutterWidth
        let extendedRect = CGRect(
            x: notchRect.minX - g,
            y: notchRect.minY - NotchOverlayWindow.bottomExtension,
            width: notchRect.width + 2 * g,
            height: notchRect.height + NotchOverlayWindow.bottomExtension
        )
        collapsedRect = extendedRect
        setFrame(extendedRect, display: true)
        orderFrontRegardless()
        addTrackingToContentView()
    }

    /// Expand the overlay to fill the notch area with content (640 × 230).
    func expand(on screen: NSScreen) {
        let expandedWidth: CGFloat = 640
        let expandedHeight: CGFloat = 230
        let x = screen.frame.midX - expandedWidth / 2
        let y = screen.frame.maxY - expandedHeight
        let expandedFrame = CGRect(x: x, y: y, width: expandedWidth, height: expandedHeight)

        displayState.isExpanded = true

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().setFrame(expandedFrame, display: true)
        } completionHandler: {
            self.addTrackingToContentView()
        }
    }

    /// Collapse back to the pill over the hardware notch.
    func collapse() {
        guard collapsedRect != .zero else { return }
        displayState.isExpanded = false
        resignKey()  // Release keyboard focus so the previous app can type again

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            animator().setFrame(collapsedRect, display: true)
        } completionHandler: {
            self.addTrackingToContentView()
        }
    }

    private func addTrackingToContentView() {
        guard let view = contentView else { return }
        view.trackingAreas.forEach { view.removeTrackingArea($0) }
        let area = NSTrackingArea(
            rect: view.bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        view.addTrackingArea(area)
    }

    // Allow text fields and buttons to receive keyboard events
    override var canBecomeKey: Bool { true }

    // Activate on click so text fields work immediately
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
