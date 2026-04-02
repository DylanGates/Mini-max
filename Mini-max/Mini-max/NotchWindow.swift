import AppKit
import SwiftUI

final class NotchWindow: NSPanel {
    private let panelWidth: CGFloat = 400
    private let panelHeight: CGFloat = 500

    var onMouseEntered: (() -> Void)?
    var onMouseExited: (() -> Void)?

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

    /// Call after the window is shown so bounds are valid.
    func setupMouseTracking() {
        guard let view = contentView else { return }
        view.trackingAreas.forEach { view.removeTrackingArea($0) }
        view.addTrackingArea(NSTrackingArea(
            rect: view.bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    override func mouseEntered(with event: NSEvent) { onMouseEntered?() }
    override func mouseExited(with event: NSEvent) { onMouseExited?() }

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
