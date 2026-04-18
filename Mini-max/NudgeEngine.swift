import Foundation
import Observation

enum Nudge: Equatable {
    case streakAtRisk
    case overdueTask(Int)
    case endOfDay
    case morningBrief
}

@Observable
@MainActor
final class NudgeEngine {
    static let shared = NudgeEngine()

    var activeNudge: Nudge?

    private var timer: Timer?
    private var cooldowns: [String: Date] = [:]

    private init() {
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.evaluate() }
        }
    }

    func dismiss() {
        guard let nudge = activeNudge else { return }
        let key = cooldownKey(for: nudge)
        let window: TimeInterval = nudge == .endOfDay ? 23 * 3600 : 3600
        cooldowns[key] = Date().addingTimeInterval(window)
        activeNudge = nil
    }

    private func evaluate() {
        let now = Date()
        let cal = Calendar.current
        let hour = cal.component(.hour, from: now)
        let min  = cal.component(.minute, from: now)

        // endOfDay: 17:30–17:34, first-match priority
        if hour == 17, (30...34).contains(min), !isCoolingDown(.endOfDay) {
            activeNudge = .endOfDay; return
        }

        // overdueTask
        let overdue = TaskStore.shared.tasks.filter {
            guard let due = $0.deadline else { return false }
            return due < now && !$0.isCompleted
        }.count
        if overdue > 0, !isCoolingDown(.overdueTask(overdue)) {
            activeNudge = .overdueTask(overdue); return
        }

        // streakAtRisk: 18:00–22:59
        if (18...22).contains(hour), !isCoolingDown(.streakAtRisk) {
            activeNudge = .streakAtRisk
        }
    }

    private func isCoolingDown(_ nudge: Nudge) -> Bool {
        guard let until = cooldowns[cooldownKey(for: nudge)] else { return false }
        return Date() < until
    }

    private func cooldownKey(for nudge: Nudge) -> String {
        switch nudge {
        case .streakAtRisk:       return "streakAtRisk"
        case .overdueTask:        return "overdueTask"
        case .endOfDay:           return "endOfDay"
        case .morningBrief:       return "morningBrief"
        }
    }
}
