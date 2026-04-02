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
