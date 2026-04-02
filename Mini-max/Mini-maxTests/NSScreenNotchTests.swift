import Testing
import AppKit
@testable import Mini_max

struct NSScreenNotchTests {

    // MacBook Pro 14"/16" display: 3456 wide, side areas each 1410 wide → 636 notch
    private let mbp16 = (frameWidth: CGFloat(3456), frameMinX: CGFloat(0), frameMaxY: CGFloat(900),
                         topLeftWidth: CGFloat(1410), topLeftHeight: CGFloat(32),
                         topRightWidth: CGFloat(1410), topRightHeight: CGFloat(32))

    @Test func notchRectHasCorrectWidth() throws {
        let rect = try #require(NSScreen.notchRect(
            frameWidth: mbp16.frameWidth, frameMinX: mbp16.frameMinX, frameMaxY: mbp16.frameMaxY,
            topLeftWidth: mbp16.topLeftWidth, topLeftHeight: mbp16.topLeftHeight,
            topRightWidth: mbp16.topRightWidth, topRightHeight: mbp16.topRightHeight
        ))
        #expect(rect.width == 636)
    }

    @Test func notchRectHasCorrectOrigin() throws {
        let rect = try #require(NSScreen.notchRect(
            frameWidth: mbp16.frameWidth, frameMinX: mbp16.frameMinX, frameMaxY: mbp16.frameMaxY,
            topLeftWidth: mbp16.topLeftWidth, topLeftHeight: mbp16.topLeftHeight,
            topRightWidth: mbp16.topRightWidth, topRightHeight: mbp16.topRightHeight
        ))
        #expect(rect.minX == 1410)  // frameMinX + topLeftWidth
        #expect(rect.minY == 868)   // frameMaxY - notchHeight = 900 - 32
    }

    @Test func returnsNilWhenNoNotch() {
        // Left + right exactly fills the screen width → no notch gap
        let result = NSScreen.notchRect(
            frameWidth: 2560, frameMinX: 0, frameMaxY: 800,
            topLeftWidth: 1280, topLeftHeight: 24,
            topRightWidth: 1280, topRightHeight: 24
        )
        #expect(result == nil)
    }

    @Test func notchXAccountsForMultiMonitorOffset() throws {
        // On a secondary monitor, frameMinX may not be 0
        let rect = try #require(NSScreen.notchRect(
            frameWidth: 3456, frameMinX: 2560, frameMaxY: 900,
            topLeftWidth: 1410, topLeftHeight: 32,
            topRightWidth: 1410, topRightHeight: 32
        ))
        #expect(rect.minX == 2560 + 1410)  // frameMinX + topLeftWidth
    }
}
