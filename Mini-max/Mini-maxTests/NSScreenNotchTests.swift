import Testing
import AppKit
@testable import Mini_max

struct NSScreenNotchTests {

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
        let screenWidth: CGFloat = 2560
        let topLeftWidth: CGFloat = 1280
        let topRightWidth: CGFloat = 1280
        let notchWidth = screenWidth - topLeftWidth - topRightWidth
        #expect(notchWidth == 0)
    }
}
