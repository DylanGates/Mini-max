import AppKit

extension NSScreen {
    /// The built-in MacBook display — the one that has the notch.
    /// Falls back to main screen (e.g. when used with an external monitor only).
    static var builtIn: NSScreen? {
        screens.first {
            let id = $0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
            return CGDisplayIsBuiltin(id) != 0
        } ?? main
    }


    /// The rect occupied by the notch, in screen coordinates.
    /// Returns nil on Macs without a notch.
    var notchRect: CGRect? {
        guard let topLeft = auxiliaryTopLeftArea,
              let topRight = auxiliaryTopRightArea else { return nil }
        return NSScreen.notchRect(
            frameWidth: frame.width,
            frameMinX: frame.minX,
            frameMaxY: frame.maxY,
            topLeftWidth: topLeft.width,
            topLeftHeight: topLeft.height,
            topRightWidth: topRight.width,
            topRightHeight: topRight.height
        )
    }

    /// True if this screen has a notch.
    var hasNotch: Bool { notchRect != nil }

    /// Pure geometry helper — internal so tests can call it directly.
    /// `max` of the two side heights used as notch height (symmetric on all current hardware).
    static func notchRect(
        frameWidth: CGFloat,
        frameMinX: CGFloat,
        frameMaxY: CGFloat,
        topLeftWidth: CGFloat,
        topLeftHeight: CGFloat,
        topRightWidth: CGFloat,
        topRightHeight: CGFloat
    ) -> CGRect? {
        let notchWidth = frameWidth - topLeftWidth - topRightWidth
        guard notchWidth > 0 else { return nil }
        let notchHeight = max(topLeftHeight, topRightHeight)
        let notchX = frameMinX + topLeftWidth
        let notchY = frameMaxY - notchHeight
        return CGRect(x: notchX, y: notchY, width: notchWidth, height: notchHeight)
    }
}
