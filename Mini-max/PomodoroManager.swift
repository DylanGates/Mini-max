import Foundation
import Observation
import UserNotifications

enum PomodoroPhase {
    case idle
    case focus(remaining: TimeInterval)
    case shortBreak(remaining: TimeInterval)
    case longBreak(remaining: TimeInterval)

    var remaining: TimeInterval {
        switch self {
        case .idle:                                 return 0
        case .focus(let r), .shortBreak(let r),
             .longBreak(let r):                     return r
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

    // MARK: - Config (user-configurable, persisted)

    var focusMinutes: Int {
        didSet { UserDefaults.standard.set(focusMinutes, forKey: "minimax.pomodoro.focusMin") }
    }
    var shortBreakMinutes: Int {
        didSet { UserDefaults.standard.set(shortBreakMinutes, forKey: "minimax.pomodoro.shortMin") }
    }
    var longBreakMinutes: Int {
        didSet { UserDefaults.standard.set(longBreakMinutes, forKey: "minimax.pomodoro.longMin") }
    }
    var sessionsBeforeLong: Int {
        didSet { UserDefaults.standard.set(sessionsBeforeLong, forKey: "minimax.pomodoro.sessBeforeLong") }
    }

    var focusDuration:      TimeInterval { TimeInterval(focusMinutes * 60) }
    var shortBreakDuration: TimeInterval { TimeInterval(shortBreakMinutes * 60) }
    var longBreakDuration:  TimeInterval { TimeInterval(longBreakMinutes * 60) }

    // MARK: - State

    var phase: PomodoroPhase = .idle
    var isPaused = false
    var completedSessions: Int = 0

    var sessionDots: [Bool] {
        (0..<sessionsBeforeLong).map { $0 < (completedSessions % sessionsBeforeLong) }
    }

    private var timer: Timer?
    private let sessionsKey = "minimax.pomodoro.sessions"

    private init() {
        let d = UserDefaults.standard
        focusMinutes       = d.object(forKey: "minimax.pomodoro.focusMin")      != nil ? d.integer(forKey: "minimax.pomodoro.focusMin")      : 25
        shortBreakMinutes  = d.object(forKey: "minimax.pomodoro.shortMin")      != nil ? d.integer(forKey: "minimax.pomodoro.shortMin")      : 5
        longBreakMinutes   = d.object(forKey: "minimax.pomodoro.longMin")       != nil ? d.integer(forKey: "minimax.pomodoro.longMin")       : 15
        sessionsBeforeLong = d.object(forKey: "minimax.pomodoro.sessBeforeLong") != nil ? d.integer(forKey: "minimax.pomodoro.sessBeforeLong") : 4
        completedSessions  = d.integer(forKey: sessionsKey)
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
            // Credit the active project with one completed session
            if let active = ProjectStore.shared.active {
                ProjectStore.shared.incrementSession(active)
            }
            sendPhaseNotification(title: "Focus complete", body: nextBreakLabel())
            let isLong = completedSessions % sessionsBeforeLong == 0
            phase = isLong
                ? .longBreak(remaining: longBreakDuration)
                : .shortBreak(remaining: shortBreakDuration)
            scheduleTick()
        case .shortBreak, .longBreak:
            sendPhaseNotification(title: "Break over", body: "Back to focus.")
            phase = .focus(remaining: focusDuration)
            scheduleTick()
        case .idle:
            break
        }
    }

    private func nextBreakLabel() -> String {
        completedSessions % sessionsBeforeLong == 0 ? "Time for a long break." : "Time for a short break."
    }

    private func sendPhaseNotification(title: String, body: String) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            center.add(req)
        }
    }
}
