import Foundation
import Observation

enum Nudge: Equatable {
    case streakAtRisk
    case overdueTask(Int)
    case endOfDay
}

@Observable
@MainActor
final class NudgeEngine {
    static let shared = NudgeEngine()

    var activeNudge: Nudge? = nil

    private var dismissedAt: [String: Date] = [:]
    private var timer: Timer?

    private init() {
        startTimer()
    }

    @MainActor deinit {
        timer?.invalidate()
    }

    private func startTimer() {
        // Evaluate immediately, then every 60s
        Task { await evaluate() }
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { await self?.evaluate() }
        }
    }

    func dismiss() {
        guard let n = activeNudge else { return }
        let key = keyFor(n)
        dismissedAt[key] = Date()
        activeNudge = nil
    }

    private func keyFor(_ nudge: Nudge) -> String {
        switch nudge {
        case .streakAtRisk: return "streakAtRisk"
        case .overdueTask:  return "overdueTask"
        case .endOfDay:     return "endOfDay"
        }
    }

    private func isCooledDown(_ key: String, hours: Int) -> Bool {
        guard let last = dismissedAt[key] else { return true }
        return Date().timeIntervalSince(last) > TimeInterval(hours * 3600)
    }

    func evaluate() async {
        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute], from: Date())
        let hour = comps.hour ?? 0
        let minute = comps.minute ?? 0

        // 1) End of day: 17:30 - 17:34
        if hour == 17 && (30...34).contains(minute) {
            let key = "endOfDay"
            if isCooledDown(key, hours: 23) {
                activeNudge = .endOfDay
                return
            }
        }

        // 2) Overdue tasks
        let overdueCount = TaskStore.shared.pending.filter { $0.urgency == .overdue }.count
        if overdueCount > 0 {
            let key = "overdueTask"
            if isCooledDown(key, hours: 1) {
                activeNudge = .overdueTask(count: overdueCount)
                return
            }
        }

        // 3) Streak at risk: 18:00 - 22:59 and 0 commits today
        if (18...22).contains(hour) {
            let commits = todayCommits()
            if commits == 0 {
                let key = "streakAtRisk"
                if isCooledDown(key, hours: 1) {
                    activeNudge = .streakAtRisk(daysLeft: 1)
                    return
                }
            }
        }

        // No match
        activeNudge = nil
    }

    private func todayCommits() -> Int {
        let contributions = GitHubContributionStore.shared.contributionsByUser
        if contributions.isEmpty { return 0 }
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = TimeZone(identifier: "UTC")
        let todayKey = df.string(from: Date())
        var total = 0
        for (_, map) in contributions {
            total += map[todayKey]?.count ?? 0
        }
        return total
    }
}
