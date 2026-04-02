import Testing
@testable import Mini_max

@MainActor
struct MiniMaxViewModelTests {

    @Test func startsHidden() {
        let vm = MiniMaxViewModel()
        #expect(vm.isPanelVisible == false)
    }

    @Test func showPanelSetsVisible() {
        let vm = MiniMaxViewModel()
        vm.showPanel()
        #expect(vm.isPanelVisible == true)
    }

    @Test func hidePanelSetsHidden() {
        let vm = MiniMaxViewModel()
        vm.showPanel()
        vm.hidePanel()
        #expect(vm.isPanelVisible == false)
    }

    @Test func toggleFlipsState() {
        let vm = MiniMaxViewModel()
        vm.togglePanel()
        #expect(vm.isPanelVisible == true)
        vm.togglePanel()
        #expect(vm.isPanelVisible == false)
    }
}
