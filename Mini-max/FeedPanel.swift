import SwiftUI

struct FeedPanel: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            FeedNewsColumn()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            FeedLearningColumn()
                .frame(width: 200)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - News Column

private struct FeedNewsColumn: View {
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
                HStack {
                    Spacer()
                    ProgressView().scaleEffect(0.6)
                    Spacer()
                }
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
                ForEach(engine.items) { item in
                    FeedNewsItem(item: item)
                }
                Spacer(minLength: 0)
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

private struct FeedNewsItem: View {
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
                HStack {
                    Spacer()
                    Button(saved ? "Saved ✓" : "Save") {
                        Task {
                            await ObsidianStore.shared.saveNote(
                                title: "Feed Clip",
                                content: item.title
                            )
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

// MARK: - Learning Column

private struct FeedLearningColumn: View {
    private let store = LearningStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: "book.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.white)
                Text("Learning")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(store.todayTopics.count) topics")
                    .font(.system(size: 9))
                    .foregroundStyle(Color(white: 0.35))
            }

            if store.todayTopics.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 18))
                        .foregroundStyle(Color(white: 0.2))
                    Text("No topics today")
                        .font(.system(size: 10))
                        .foregroundStyle(Color(white: 0.3))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ForEach(store.todayTopics.prefix(3)) { topic in
                    FeedTopicCard(topic: topic)
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct FeedTopicCard: View {
    let topic: LearningTopic

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(topic.title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(white: 0.88))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(topic.category)
                    .font(.system(size: 8))
                    .foregroundStyle(Color(white: 0.5))
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 3).fill(Color(white: 0.09)))
            }
            HStack(spacing: 4) {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(Color(white: 0.10))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(progressColor)
                        .scaleEffect(x: CGFloat(topic.progress) / 100, y: 1, anchor: .leading)
                }
                .frame(height: 3)
                Text("\(topic.progress)%")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(progressColor)
                    .frame(width: 28, alignment: .trailing)
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(white: 0.06)))
    }

    private var progressColor: Color {
        switch topic.progress {
        case 0..<30:  return Color(red: 0.98, green: 0.58, blue: 0.20)
        case 30..<70: return Color(red: 0.66, green: 0.46, blue: 0.98)
        default:      return Color(red: 0.20, green: 0.74, blue: 0.43)
        }
    }
}
