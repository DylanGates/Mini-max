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
        hostingView.layer?.backgroundColor = .clear
        contentView = hostingView
    }

    /// How many points the pill extends below the real hardware notch.
    static let bottomExtension: CGFloat = 12

    /// Position the overlay to cover the real notch + extend below it.
    /// The window top is flush with the screen top so the black fill merges with the bezel.
    func positionOver(notchRect: CGRect) {
        // Extend downward so the rounded bottom corners are visible
        let extendedRect = CGRect(
            x: notchRect.minX,
            y: notchRect.minY - NotchOverlayWindow.bottomExtension,
            width: notchRect.width,
            height: notchRect.height + NotchOverlayWindow.bottomExtension
        )
        setFrame(extendedRect, display: true)
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
