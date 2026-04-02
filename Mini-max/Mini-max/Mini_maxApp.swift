import SwiftUI

@main
struct Mini_maxApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No WindowGroup — all UI lives in NSPanels managed by AppDelegate.
        // Settings scene keeps the app alive in the background.
        Settings { EmptyView() }
    }
}
