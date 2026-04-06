import Foundation
import Observation

@Observable
final class MiniMaxViewModel {
    var isPanelVisible: Bool = false
    var isHoveringNotch: Bool = false

    func togglePanel() {
        isPanelVisible.toggle()
    }

    func showPanel() {
        isPanelVisible = true
    }

    func hidePanel() {
        isPanelVisible = false
    }
}
