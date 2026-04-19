import SwiftUI

// Merged Feed + Learn panel — 60% news (left) / 40% learning (right)
struct FeedLearnPanel: View {
    @State private var eyesTrigger = UUID()

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Left: news feed — fills remaining space
            NewsFeedView()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            // Right: learning panel — fixed width
            LearningPanel(eyesTrigger: $eyesTrigger)
                .frame(width: 210)
                .frame(maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// --- News feed implementation
private struct NewsFeedView: View {
    private let engine = MorningBriefEngine.shared
    @State private var isPulsing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(.red)
                        .frame(width: 4, height: 4)
                        .opacity(isPulsing ? 1.0 : 0.3)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                                isPulsing = true
                            }
                        }
                    Text("LIVE FEED")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Capsule().fill(.white.opacity(0.05)))
                
                Spacer()
                
                Button {
                    Task { await engine.load(force: true) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(engine.isLoading ? 0.8 : 0.35))
                        .rotationEffect(.degrees(engine.isLoading ? 360 : 0))
                        .animation(engine.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: engine.isLoading)
                }
                .buttonStyle(.plain)
                .disabled(engine.isLoading)
            }

            if engine.isLoading && engine.items.isEmpty {
                HStack { Spacer(); ProgressView().scaleEffect(0.6); Spacer() }
                    .frame(maxHeight: .infinity)
            } else if engine.items.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 18))
                        .foregroundStyle(Color(white: 0.25))
                    Text(engine.error != nil ? "Sync error" : "Initializing feed...")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color(white: 0.3))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 7) {
                        ForEach(engine.items) { item in
                            NewsItemView(item: item)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task { await engine.load() }
    }
}

private struct NewsItemView: View {
    let item: BriefItem
    @State private var saved = false

    var sourceColor: Color {
        let src = item.source.lowercased()
        if src.contains("techcrunch") { return Color(red: 0.13, green: 0.80, blue: 0.35) }
        if src.contains("verge")      { return Color(red: 0.90, green: 0.15, blue: 0.35) }
        if src.contains("hn")         { return Color(red: 1.00, green: 0.40, blue: 0.00) }
        if src.contains("bbc")        { return Color(red: 0.70, green: 0.00, blue: 0.00) }
        if src.contains("cnn")        { return Color(red: 0.80, green: 0.10, blue: 0.10) }
        if src.contains("forbes")     { return Color(red: 0.00, green: 0.30, blue: 0.60) }
        if src.contains("techmeme")   { return Color(red: 0.20, green: 0.40, blue: 0.80) }
        if src.contains("dev.to")     { return Color(white: 0.8) }
        if src.contains("guardian")   { return Color(red: 0.02, green: 0.27, blue: 0.45) }
        return Color(red: 0.48, green: 0.70, blue: 0.91)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text(item.source.uppercased())
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(sourceColor)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(sourceColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                
                Spacer()
                
                Text(item.timeAgo)
                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.25))
            }
            
            Text(item.title)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)

            if ObsidianStore.shared.vaultURL != nil {
                HStack {
                    Spacer()
                    Button {
                        Task {
                            await ObsidianStore.shared.saveNote(title: "Clip: \(item.source)", content: item.title)
                            withAnimation { saved = true }
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: saved ? "checkmark" : "plus.square")
                            Text(saved ? "SAVED" : "CLIP")
                        }
                        .font(.system(size: 8, weight: .black))
                        .foregroundStyle(.white.opacity(saved ? 0.6 : 0.3))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(LinearGradient(colors: [Color(white: 0.08), Color(white: 0.05)], startPoint: .top, endPoint: .bottom))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(.white.opacity(0.06), lineWidth: 0.5)
        )
    }
}
