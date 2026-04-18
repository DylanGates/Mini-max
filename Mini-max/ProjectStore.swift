import Foundation
import Observation

struct Project: Identifiable, Codable {
    var id = UUID()
    var name: String
    var language: String
    var path: String        // file system path, empty if not set
    var sessionsToday: Int
    var totalMinutes: Int   // persisted work time in minutes
    var isActive: Bool
    var dateAdded: Date
    var deadline: Date? = nil

    var totalHoursDisplay: String {
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        if h == 0 { return "\(m)m" }
        if m == 0 { return "\(h)h" }
        return "\(h)h \(m)m"
    }
}

@Observable
final class ProjectStore {
    static let shared = ProjectStore()

    var projects: [Project] = []

    private let key = "minimax.projects"

    private init() {
        load()
        resetDailySessionsIfNeeded()
    }

    // MARK: - Queries

    var active: Project? { projects.first { $0.isActive } }

    // MARK: - Mutations

    func add(name: String, subtitle: String = "", language: String, path: String, phase: ProjectPhase = .building, milestonesTotal: Int = 5, deadline: Date? = nil) {
        // Deactivate others when adding a new active project
        let project = Project(
            name: name,
            subtitle: subtitle,
            language: language,
            path: path,
            phase: phase,
            milestonesTotal: milestonesTotal,
            milestonesCompleted: 0,
            tasksTotal: 0,
            tasksCompleted: 0,
            sessionsToday: 0,
            totalMinutes: 0,
            isActive: projects.isEmpty,
            dateAdded: Date(),
            deadline: deadline
        )
        projects.append(project)
        save()
    }

    func delete(_ project: Project) {
        projects.removeAll { $0.id == project.id }
        save()
    }

    func setActive(_ project: Project) {
        for i in projects.indices { projects[i].isActive = false }
        if let idx = projects.firstIndex(where: { $0.id == project.id }) {
            projects[idx].isActive = true
        }
        save()
    }

    func incrementSession(_ project: Project) {
        guard let idx = projects.firstIndex(where: { $0.id == project.id }) else { return }
        projects[idx].sessionsToday += 1
        projects[idx].totalMinutes += 25   // assume 1 pomodoro = 25 min
        save()
    }

    // MARK: - Daily Reset

    private let lastResetKey = "minimax.projects.lastReset"

    private func resetDailySessionsIfNeeded() {
        let cal = Calendar.current
        let lastReset = UserDefaults.standard.object(forKey: lastResetKey) as? Date ?? .distantPast
        guard !cal.isDateInToday(lastReset) else { return }
        for i in projects.indices { projects[i].sessionsToday = 0 }
        UserDefaults.standard.set(Date(), forKey: lastResetKey)
        save()
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(projects) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Project].self, from: data)
        else { return }
        projects = decoded
    }
}
