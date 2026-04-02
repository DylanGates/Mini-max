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
