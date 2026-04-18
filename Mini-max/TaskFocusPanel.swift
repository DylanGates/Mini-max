import SwiftUI

// Merged Tasks + Focus panel — 60% Pomodoro (left) / 40% Tasks (right)
struct TaskFocusPanel: View {
    @State private var eyesTrigger = UUID()

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Left: Pomodoro / Focus UI — fills remaining space
            FocusPanel(eyesTrigger: $eyesTrigger)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            // Right: Tasks list — fixed width
            TasksPanel(eyesTrigger: $eyesTrigger)
                .frame(width: 210)
                .frame(maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
