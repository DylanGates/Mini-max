import Foundation
import Observation

enum PomodoroPhase {
    case idle
    case focus(remaining: TimeInterval)
    case shortBreak(remaining: TimeInterval)
    case longBreak(remaining: TimeInterval)

    var remaining: TimeInterval {
        switch self {
        case .idle:                         return 0
        case .focus(let r),
             .shortBreak(let r),
             .longBreak(let r):             return r
        }
    }

    var label: String {
        switch self {
        case .idle:        return "Ready"
        case .focus:       return "Focus"
        case .shortBreak:  return "Short Break"
        case .longBreak:   return "Long Break"
        }
    }

    var isIdle: Bool { if case .idle = self { return true }; return false }
}

@Observable
final class PomodoroManager {
    static let shared = PomodoroManager()

    let focusDuration:      TimeInterval = 25 * 60
    let shortBreakDuration: TimeInterval =  5 * 60
    let longBreakDuration:  TimeInterval = 15 * 60
    let sessionsBeforeLong  = 4

    var phase: PomodoroPhase = .idle
    var isPaused = false
    var completedSessions: Int = 0

    // Slot dots: true = filled
    var sessionDots: [Bool] {
        (0..<sessionsBeforeLong).map { $0 < (completedSessions % sessionsBeforeLong) }
    }

    private var timer: Timer?
    private let sessionsKey = "minimax.pomodoro.sessions"

    private init() {
        completedSessions = UserDefaults.standard.integer(forKey: sessionsKey)
    }

    // MARK: - Controls

    func start() {
        isPaused = false
        phase = .focus(remaining: focusDuration)
        scheduleTick()
    }

    func pause() {
        isPaused = true
        timer?.invalidate()
    }

    func resume() {
        isPaused = false
        scheduleTick()
    }

    func skip() { advance() }

    func stop() {
        timer?.invalidate()
        phase = .idle
        isPaused = false
    }

    // MARK: - Timer

    private func scheduleTick() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func tick() {
        let next = phase.remaining - 1
        if next <= 0 {
            advance()
        } else {
            switch phase {
            case .focus:      phase = .focus(remaining: next)
            case .shortBreak: phase = .shortBreak(remaining: next)
            case .longBreak:  phase = .longBreak(remaining: next)
            case .idle:       break
            }
        }
    }

    private func advance() {
        timer?.invalidate()
        switch phase {
        case .focus:
            completedSessions += 1
            UserDefaults.standard.set(completedSessions, forKey: sessionsKey)
            let isLong = completedSessions % sessionsBeforeLong == 0
            phase = isLong
                ? .longBreak(remaining: longBreakDuration)
                : .shortBreak(remaining: shortBreakDuration)
            scheduleTick()
        case .shortBreak, .longBreak:
            phase = .focus(remaining: focusDuration)
            scheduleTick()
        case .idle:
            break
        }
    }
}
