import Foundation
import Observation

enum ProjectPhase: String, Codable, CaseIterable {
    case planning = "Planning"
    case building = "Building"
    case testing = "Testing"
    case shipping = "Shipping"
}

struct Project: Identifiable, Codable {
    var id = UUID()
    var name: String
    var subtitle: String = ""
    var language: String
    var path: String        // file system path, empty if not set
    var phase: ProjectPhase = .building
    var milestonesTotal: Int = 5
    var milestonesCompleted: Int = 0
    var tasksTotal: Int = 0
    var tasksCompleted: Int = 0
    var sessionsToday: Int
    var totalMinutes: Int   // persisted work time in minutes
    var isActive: Bool
    var dateAdded: Date

    var totalHoursDisplay: String {
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        if h == 0 { return "\(m)m" }
        if m == 0 { return "\(h)h" }
        return "\(h)h \(m)m"
    }

    var progress: Double {
        let milestoneWeight = 0.7
        let taskWeight = 0.3
        
        let mProgress = milestonesTotal > 0 ? Double(milestonesCompleted) / Double(milestonesTotal) : 0
        let tProgress = tasksTotal > 0 ? Double(tasksCompleted) / Double(tasksTotal) : 0
        
        if tasksTotal == 0 { return mProgress }
        return (mProgress * milestoneWeight) + (tProgress * taskWeight)
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

    func add(name: String, language: String, path: String) {
        // Deactivate others when adding a new active project
        let project = Project(
            name: name, language: language, path: path,
            sessionsToday: 0, totalMinutes: 0,
            isActive: projects.isEmpty,
            dateAdded: Date()
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
