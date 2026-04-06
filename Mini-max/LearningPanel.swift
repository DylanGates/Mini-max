import SwiftUI

struct LearningPanel: View {
    private let store = LearningStore.shared
    @State private var showingAdd = false
    @State private var newTitle = ""
    @State private var newCategory = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Learning")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                Button { showingAdd.toggle() } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(white: 0.5))
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 8)

            if showingAdd {
                HStack(spacing: 6) {
                    TextField("Topic", text: $newTitle)
                        .font(.system(size: 11))
                        .textFieldStyle(.plain)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color(white: 0.1)))

                    TextField("Category", text: $newCategory)
                        .font(.system(size: 11))
                        .textFieldStyle(.plain)
                        .foregroundStyle(.white)
                        .frame(width: 72)
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color(white: 0.1)))

                    Button(action: commitAdd) {
                        Image(systemName: "return")
                            .font(.system(size: 11))
                            .foregroundStyle(Color(red: 0.48, green: 0.70, blue: 0.91))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 6)
            }

            if store.topics.isEmpty {
                emptyState
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 4) {
                        ForEach(store.topics) { topic in
                            TopicRow(topic: topic)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "book.closed")
                .font(.system(size: 18))
                .foregroundStyle(Color(white: 0.28))
            Text("Nothing tracked yet")
                .font(.system(size: 11))
                .foregroundStyle(Color(white: 0.28))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func commitAdd() {
        guard !newTitle.isEmpty else { showingAdd = false; return }
        store.add(title: newTitle, category: newCategory)
        newTitle = ""
        newCategory = ""
        showingAdd = false
    }
}

private struct TopicRow: View {
    let topic: LearningTopic
    private let store = LearningStore.shared

    private let accent = Color(red: 0.48, green: 0.70, blue: 0.91)
    private let milestones = [0, 25, 50, 75, 100]

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(topic.title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white)
                    if !topic.category.isEmpty {
                        Text(topic.category)
                            .font(.system(size: 9))
                            .foregroundStyle(Color(white: 0.38))
                    }
                }
                Spacer()
                Text("\(topic.progress)%")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color(white: 0.45))

                Button { store.delete(topic) } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8))
                        .foregroundStyle(Color(white: 0.28))
                }
                .buttonStyle(.plain)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(Color(white: 0.1)).frame(height: 3)
                    RoundedRectangle(cornerRadius: 2).fill(accent)
                        .frame(width: geo.size.width * CGFloat(topic.progress) / 100, height: 3)
                }
            }
            .frame(height: 3)

            HStack(spacing: 6) {
                ForEach(milestones, id: \.self) { val in
                    Button { store.updateProgress(topic, progress: val) } label: {
                        Text("\(val)%")
                            .font(.system(size: 8))
                            .foregroundStyle(topic.progress == val ? accent : Color(white: 0.28))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 7).fill(Color(white: 0.06)))
    }
}
