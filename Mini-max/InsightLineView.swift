import SwiftUI

/// Single-line AI insight strip shown at the bottom of each panel.
/// Fixed 14pt height — no layout shift on load.
struct InsightLineView: View {
    let tab: NotchTab

    @State private var insight: String? = nil
    @State private var pulse = false

    private let engine = InsightEngine.shared

    var body: some View {
        Group {
            if let text = insight {
                // Loaded
                Text(text)
                    .font(.system(size: 10))
                    .foregroundStyle(Color(white: 0.42))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if engine.lastError != nil {
                // Error — tap to retry
                Button {
                    insight = nil
                    Task { insight = try? await engine.fetch(for: tab) }
                } label: {
                    Text("· · ·  tap to retry")
                        .font(.system(size: 10))
                        .foregroundStyle(Color(white: 0.25))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            } else {
                // Loading — pulsing dots
                Text("· · ·")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(white: 0.28))
                    .opacity(pulse ? 0.7 : 0.3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                            pulse = true
                        }
                    }
            }
        }
        .frame(height: 14, alignment: .leading)
        .task(id: tab) {
            insight = nil
            insight = try? await engine.fetch(for: tab)
        }
    }
}
