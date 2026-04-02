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
