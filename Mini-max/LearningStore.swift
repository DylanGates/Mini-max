import Foundation
import Observation
import SwiftUI

// Weekday indices matching Calendar: 1=Sun 2=Mon 3=Tue 4=Wed 5=Thu 6=Fri 7=Sat
struct LearningTopic: Identifiable, Codable {
    var id = UUID()
    var title: String
    var category: String
    var notes: String
    var progress: Int        // 0–100
    var scheduledDays: Set<Int>  // Calendar weekday values; empty = any day
    var dateAdded: Date
}

@Observable
final class LearningStore {
    static let shared = LearningStore()

    var topics: [LearningTopic] = []

    private let key = "minimax.learning.topics"

    private init() { load() }

    // MARK: - Today

    var todayTopics: [LearningTopic] {
        let today = Calendar.current.component(.weekday, from: Date())
        return topics.filter { $0.scheduledDays.isEmpty || $0.scheduledDays.contains(today) }
    }

    // MARK: - Mutations

    func add(title: String, category: String, scheduledDays: Set<Int> = []) {
        topics.append(LearningTopic(
            title: title, category: category, notes: "",
            progress: 0, scheduledDays: scheduledDays, dateAdded: Date()
        ))
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

    func updateDays(_ topic: LearningTopic, days: Set<Int>) {
        guard let idx = topics.firstIndex(where: { $0.id == topic.id }) else { return }
        topics[idx].scheduledDays = days
        save()
    }

    func updateNotes(_ topic: LearningTopic, notes: String) {
        guard let idx = topics.firstIndex(where: { $0.id == topic.id }) else { return }
        topics[idx].notes = notes
        save()
    }

    var completedTopics: [LearningTopic] { topics.filter { $0.progress == 100 } }
    var activeTopics:    [LearningTopic] { topics.filter { $0.progress  < 100 } }

    func moveActive(fromOffsets: IndexSet, toOffset: Int) {
        var active = topics.filter { $0.progress < 100 }
        let completed = topics.filter { $0.progress == 100 }
        active.move(fromOffsets: fromOffsets, toOffset: toOffset)
        topics = active + completed
        save()
    }

    // MARK: - Persistence

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
