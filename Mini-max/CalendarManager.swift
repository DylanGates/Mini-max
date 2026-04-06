import EventKit
import SwiftUI

// MARK: - Event Model

struct CalEvent: Identifiable, Equatable {
    let id: String
    let title: String
    let calendarName: String
    let startDate: Date
    let endDate: Date
    let calendarColor: NSColor
    let isAllDay: Bool
    let location: String?

    var isEnded: Bool      { endDate < Date() }
    var isInProgress: Bool { startDate <= Date() && endDate > Date() }

    /// Human-readable duration string e.g. "9:00 – 10:30 AM"
    var timeRange: String {
        guard !isAllDay else { return "All day" }
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm"
        let amPm = DateFormatter()
        amPm.dateFormat = "a"
        let start = fmt.string(from: startDate)
        let end   = fmt.string(from: endDate) + " " + amPm.string(from: endDate)
        return "\(start) – \(end)"
    }
}

// MARK: - Auth State

enum CalAuthState {
    case unknown
    case authorized
    case denied
    case restricted
}

// MARK: - CalendarManager

@MainActor
@Observable
final class CalendarManager {
    static let shared = CalendarManager()

    var events: [CalEvent]   = []
    var authState: CalAuthState = .unknown
    var selectedDate: Date   = Calendar.current.startOfDay(for: Date())

    private let store = EKEventStore()

    private init() {
        NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: store,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.reloadEvents()
            }
        }
        Task { await requestAccessIfNeeded() }
    }

    // MARK: - Access

    func requestAccessIfNeeded() async {
        authState = currentAuthState()
        switch authState {
        case .unknown:
            do {
                let granted: Bool
                if #available(macOS 14.0, *) {
                    granted = try await store.requestFullAccessToEvents()
                } else {
                    granted = try await store.requestAccess(to: .event)
                }
                authState = granted ? .authorized : .denied
                if granted { await reloadEvents() }
            } catch {
                print("[CalendarManager] access request failed: \(error)")
                authState = .denied
            }
        case .authorized:
            await reloadEvents()
        case .denied, .restricted:
            break
        }
    }

    func openSystemSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!)
    }

    // MARK: - Date Selection

    func selectDate(_ date: Date) async {
        selectedDate = Calendar.current.startOfDay(for: date)
        await reloadEvents()
    }

    // MARK: - Private

    private func reloadEvents() async {
        guard authState == .authorized else { return }
        let start = selectedDate
        guard let end = Calendar.current.date(byAdding: .day, value: 1, to: start) else { return }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        events = store.events(matching: predicate)
            .map { CalEvent(from: $0) }
            .sorted {
                // in-progress first, then by start time, ended last
                if $0.isInProgress != $1.isInProgress { return $0.isInProgress }
                if $0.isEnded != $1.isEnded { return !$0.isEnded }
                return $0.startDate < $1.startDate
            }
    }

    private func currentAuthState() -> CalAuthState {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(macOS 14.0, *) {
            switch status {
            case .fullAccess:             return .authorized
            case .writeOnly, .denied:     return .denied
            case .restricted:             return .restricted
            case .notDetermined:          return .unknown
            @unknown default:             return .unknown
            }
        } else {
            switch status {
            case .authorized, .fullAccess: return .authorized
            case .writeOnly, .denied:      return .denied
            case .restricted:              return .restricted
            case .notDetermined:           return .unknown
            @unknown default:              return .unknown
            }
        }
    }
}

// MARK: - CalEvent init from EKEvent

private extension CalEvent {
    init(from event: EKEvent) {
        self.id           = event.calendarItemIdentifier
        self.title        = event.title ?? "Untitled"
        self.calendarName = event.calendar?.title ?? ""
        self.startDate    = event.startDate
        self.endDate      = event.endDate
        self.calendarColor = event.calendar?.color ?? .systemBlue
        self.isAllDay     = event.isAllDay
        self.location     = event.location
    }
}
