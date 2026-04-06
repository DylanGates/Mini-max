import Foundation
import Observation
import SwiftUI

enum TaskPriority: Int, Codable, CaseIterable {
    case low = 0, medium = 1, high = 2
}

struct DailyTask: Identifiable, Codable {
    var id = UUID()
    var title: String
    var isCompleted: Bool
    var priority: TaskPriority
    var completedAt: Date?
    var dateAdded: Date
}

@Observable
final class TaskStore {
    static let shared = TaskStore()

    var tasks: [DailyTask] = []

    private let key = "minimax.tasks"

    private init() {
        load()
        clearOldCompleted()
    }

    var pending: [DailyTask]   { tasks.filter { !$0.isCompleted } }
    var completed: [DailyTask] { tasks.filter {  $0.isCompleted } }

    func add(title: String, priority: TaskPriority = .medium) {
        tasks.append(DailyTask(title: title, isCompleted: false, priority: priority, completedAt: nil, dateAdded: Date()))
        save()
    }

    func toggle(_ task: DailyTask) {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[idx].isCompleted.toggle()
        tasks[idx].completedAt = tasks[idx].isCompleted ? Date() : nil
        save()
    }

    func delete(_ task: DailyTask) {
        tasks.removeAll { $0.id == task.id }
        save()
    }

    func movePending(fromOffsets: IndexSet, toOffset: Int) {
        var pending   = tasks.filter { !$0.isCompleted }
        let completed = tasks.filter {  $0.isCompleted }
        pending.move(fromOffsets: fromOffsets, toOffset: toOffset)
        tasks = pending + completed
        save()
    }

    // Auto-clear tasks completed more than 24h ago
    private func clearOldCompleted() {
        let cutoff = Date().addingTimeInterval(-86400)
        tasks.removeAll { $0.isCompleted && ($0.completedAt ?? .distantPast) < cutoff }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(tasks) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([DailyTask].self, from: data)
        else { return }
        tasks = decoded
    }
}
