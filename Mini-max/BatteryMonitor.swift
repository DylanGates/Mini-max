import IOKit.ps
import AppKit
import SwiftUI

/// Polls IOKit power sources for live battery data.
@Observable
final class BatteryMonitor {
    static let shared = BatteryMonitor()

    var level: Int = 0
    var isCharging: Bool = false
    var isPluggedIn: Bool = false
    var isInLowPowerMode: Bool = false

    private var timer: Timer?

    private init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        isInLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name.NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isInLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
    }

    func refresh() {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources  = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as [CFTypeRef]
        guard let source = sources.first,
              let info = IOPSGetPowerSourceDescription(snapshot, source)
                .takeUnretainedValue() as? [String: Any]
        else { return }

        level = (info[kIOPSCurrentCapacityKey] as? Int) ?? level
        isCharging = (info[kIOPSIsChargingKey] as? Bool) ?? false
        let state = info[kIOPSPowerSourceStateKey] as? String
        isPluggedIn = (state == kIOPSACPowerValue)
    }

    /// SF Symbol name matching current level (0, 25, 50, 75, 100).
    var symbolName: String {
        switch level {
        case 0..<13:  return "battery.0"
        case 13..<38: return "battery.25"
        case 38..<63: return "battery.50"
        case 63..<88: return "battery.75"
        default:      return "battery.100"
        }
    }

    /// Colour matching boring.notch's batteryColor logic.
    var color: Color {
        if isInLowPowerMode { return .yellow }
        if level <= 20 && !isCharging && !isPluggedIn { return .red }
        if isCharging || isPluggedIn || level == 100 { return .green }
        return .white
    }
}
