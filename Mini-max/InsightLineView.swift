import SwiftUI

/// Single-line (brief) or paragraph (verbose) AI insight strip shown at the bottom of each panel.
/// Brief mode: fixed 14pt height, single line.
/// Verbose mode: dynamic height, up to 4 lines, with a subtle divider above.
struct InsightLineView: View {
    let tab: NotchTab
    var verbose: Bool = false

    @State private var insight: String? = nil
    @State private var pulse = false

    private let engine = InsightEngine.shared

    var body: some View {
        Group {
            if let text = insight {
                // Loaded
                if verbose {
                    VStack(alignment: .leading, spacing: 4) {
                        Divider().opacity(0.15)
                        Text(text)
                            .font(.system(size: 10))
                            .foregroundStyle(Color(white: 0.42))
                            .lineLimit(4)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    Text(text)
                        .font(.system(size: 10))
                        .foregroundStyle(Color(white: 0.42))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: 14, alignment: .leading)
                }
            } else if engine.lastError != nil {
                // Error — tap to retry
                Button {
                    insight = nil
                    Task { insight = try? await engine.fetch(for: tab, verbose: verbose) }
                } label: {
                    Text("· · ·  tap to retry")
                        .font(.system(size: 10))
                        .foregroundStyle(Color(white: 0.25))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .frame(height: verbose ? nil : 14, alignment: .leading)
            } else {
                // Loading — pulsing dots
                Text("· · ·")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(white: 0.28))
                    .opacity(pulse ? 0.7 : 0.3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: verbose ? nil : 14, alignment: .leading)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                            pulse = true
                        }
                    }
            }
        }
        .task(id: tab) {
            insight = nil
            insight = try? await engine.fetch(for: tab, verbose: verbose)
        }
    }
}
