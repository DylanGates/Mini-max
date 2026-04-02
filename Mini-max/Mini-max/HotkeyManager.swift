import AppKit

final class HotkeyManager {
    /// Hardware key code for the backtick/tilde key (` / ~), layout-independent.
    static let backtickKeyCode: CGKeyCode = 50

    var onToggle: (() -> Void)?
    private(set) var isActive: Bool = false
    private var eventTap: CFMachPort?

    /// Start intercepting the global backtick key.
    /// Requires Accessibility permission — fails silently if not granted.
    func start() {
        guard !isActive else { return }

        let observer = Unmanaged.passRetained(self)
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)

        eventTap = CGEventTapCreate(
            .cgSessionEventTap,
            .headInsertEventTap,
            .defaultTap,
            mask,
            { (_, _, event, userInfo) -> Unmanaged<CGEvent>? in
                guard let userInfo else { return Unmanaged.passRetained(event) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()
                let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
                if keyCode == HotkeyManager.backtickKeyCode {
                    DispatchQueue.main.async { manager.onToggle?() }
                    return nil // consume the event — don't let the IDE receive it
                }
                return Unmanaged.passRetained(event)
            },
            observer.toOpaque()
        )

        guard let tap = eventTap else {
            observer.release()
            return // Accessibility permission not granted
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEventTapEnable(tap, true)
        isActive = true
    }

    func stop() {
        guard let tap = eventTap else { return }
        CGEventTapEnable(tap, false)
        eventTap = nil
        isActive = false
    }
}
