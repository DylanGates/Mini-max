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
    var deadline: Date? = nil
    var notes: String   = ""

    // Deadline urgency relative to now
    enum Urgency { case overdue, dueToday, dueSoon, later, none }

    var urgency: Urgency {
        guard let d = deadline, !isCompleted else { return .none }
        let cal = Calendar.current
        if d < Date()                           { return .overdue  }
        if cal.isDateInToday(d)                 { return .dueToday }
        if let days = cal.dateComponents([.day], from: Date(), to: d).day, days <= 2 { return .dueSoon }
        return .later
    }

    var deadlineLabel: String? {
        guard let d = deadline else { return nil }
        let cal = Calendar.current
        if d < Date()              { return "overdue" }
        if cal.isDateInToday(d)    { return "today" }
        if cal.isDateInTomorrow(d) { return "tomorrow" }
        let days = cal.dateComponents([.day], from: Date(), to: d).day ?? 0
        return "in \(days)d"
    }
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

    var completed: [DailyTask] { tasks.filter {  $0.isCompleted } }

    /// Pending tasks sorted: overdue → due today → due soon → by priority → no deadline
    var pending: [DailyTask] {
        tasks.filter { !$0.isCompleted }.sorted { a, b in
            let ua = urgencyRank(a), ub = urgencyRank(b)
            if ua != ub { return ua < ub }
            return a.priority.rawValue > b.priority.rawValue
        }
    }

    private func urgencyRank(_ t: DailyTask) -> Int {
        switch t.urgency {
        case .overdue:  return 0
        case .dueToday: return 1
        case .dueSoon:  return 2
        case .later:    return 3
        case .none:     return 4
        }
    }

    func add(title: String, priority: TaskPriority = .medium, deadline: Date? = nil, notes: String = "") {
        tasks.append(DailyTask(
            title: title, isCompleted: false, priority: priority,
            completedAt: nil, dateAdded: Date(), deadline: deadline, notes: notes
        ))
        save()
    }

    func update(_ task: DailyTask) {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[idx] = task
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
