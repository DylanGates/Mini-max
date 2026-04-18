import SwiftUI

// Merged Feed + Learn panel — 60% news (left) / 40% learning (right)
struct FeedLearnPanel: View {
    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .top, spacing: 12) {
                // Left: news feed (60%)
                NewsFeedView()
                    .frame(width: max(280, geo.size.width * 0.60))
                    .frame(maxHeight: .infinity, alignment: .topLeading)

                // Right: full LearningPanel (40%)
                LearningPanel()
                    .frame(width: max(200, geo.size.width * 0.40))
                    .frame(maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// --- News feed implementation (duplicated from FeedPanel's internal column)
private struct NewsFeedView: View {
    private let engine = MorningBriefEngine.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "newspaper.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.white)
                Text("Morning Brief")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text(todayLabel)
                    .font(.system(size: 10))
                    .foregroundStyle(Color(white: 0.35))
            }

            if engine.isLoading && engine.items.isEmpty {
                HStack { Spacer(); ProgressView().scaleEffect(0.6); Spacer() }
                    .frame(maxHeight: .infinity)
            } else if engine.items.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 18))
                        .foregroundStyle(Color(white: 0.25))
                    Text(engine.error != nil ? "Could not load brief" : "No items yet")
                        .font(.system(size: 10))
                        .foregroundStyle(Color(white: 0.3))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 8) {
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

    private var todayLabel: String {
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        return df.string(from: Date())
    }
}

private struct NewsItemView: View {
    let item: BriefItem
    @State private var saved = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Text(item.source)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(Color(red: 0.99, green: 0.60, blue: 0.20))
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 3).fill(Color(white: 0.10)))
                if !item.timeAgo.isEmpty {
                    Text(item.timeAgo)
                        .font(.system(size: 9))
                        .foregroundStyle(Color(white: 0.35))
                }
            }
            Text(item.title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color(white: 0.85))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if ObsidianStore.shared.vaultURL != nil {
                HStack { Spacer()
                    Button(saved ? "Saved ✓" : "Save") {
                        Task {
                            await ObsidianStore.shared.saveNote(title: "Feed Clip", content: item.title)
                            saved = true
                        }
                    }
                    .font(.system(size: 9))
                    .foregroundStyle(saved ? Color(white: 0.4) : Color(white: 0.35))
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(white: 0.06)))
    }
}
