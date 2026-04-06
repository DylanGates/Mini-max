import Foundation
import Observation

struct LearningTopic: Identifiable, Codable {
    var id = UUID()
    var title: String
    var category: String
    var notes: String
    var progress: Int  // 0-100
    var dateAdded: Date
}

@Observable
final class LearningStore {
    static let shared = LearningStore()

    var topics: [LearningTopic] = []

    private let key = "minimax.learning.topics"

    private init() { load() }

    func add(title: String, category: String) {
        topics.append(LearningTopic(title: title, category: category, notes: "", progress: 0, dateAdded: Date()))
        save()
    }

    func delete(_ topic: LearningTopic) {
        topics.removeAll { $0.id == topic.id }
        save()
    }

    func updateProgress(_ topic: LearningTopic, progress: Int) {
        guard let idx = topics.firstIndex(where: { $0.id == topic.id }) else { return }
        topics[idx].progress = max(0, min(100, progress))
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(topics) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([LearningTopic].self, from: data)
        else { return }
        topics = decoded
    }
}
