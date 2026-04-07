import SwiftUI

struct FocusPanel: View {
    private let pomodoro  = PomodoroManager.shared
    private let taskStore = TaskStore.shared
    @State private var showSettings = false

    private var timeString: String {
        let secs = Int(pomodoro.phase.remaining)
        return String(format: "%02d:%02d", secs / 60, secs % 60)
    }

    private var progress: Double {
        let total: TimeInterval
        switch pomodoro.phase {
        case .focus:        total = pomodoro.focusDuration
        case .shortBreak:   total = pomodoro.shortBreakDuration
        case .longBreak:    total = pomodoro.longBreakDuration
        case .idle:         return 0
        }
        return 1 - (pomodoro.phase.remaining / total)
    }

    private var accent: Color {
        switch pomodoro.phase {
        case .focus:                  return Color(red: 0.48, green: 0.70, blue: 0.91)
        case .shortBreak, .longBreak: return Color(red: 0.27, green: 0.75, blue: 0.50)
        case .idle:                   return Color(white: 0.22)
        }
    }

    private var nextPhaseHint: String {
        switch pomodoro.phase {
        case .focus:
            let sessAfter = (pomodoro.completedSessions + 1) % pomodoro.sessionsBeforeLong
            return sessAfter == 0 ? "→ long break" : "→ short break"
        case .shortBreak, .longBreak: return "→ focus"
        case .idle: return "\(pomodoro.focusMinutes)m focus · \(pomodoro.shortBreakMinutes)m break"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Settings panel — slides in above
            if showSettings {
                SettingsPanel(pomodoro: pomodoro)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.bottom, 10)
            }

            HStack(alignment: .center, spacing: 0) {
                timerColumn
                    .frame(width: 120)

                Rectangle()
                    .fill(Color(white: 0.09))
                    .frame(width: 1)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 18)

                controlsColumn
            }
            .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(.easeInOut(duration: 0.2), value: showSettings)
    }

    // MARK: - Timer Column

    private var timerColumn: some View {
        VStack(alignment: .center, spacing: 10) {
            ZStack {
                Circle()
                    .stroke(Color(white: 0.1), lineWidth: 5)
                    .frame(width: 100, height: 100)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(accent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)

                VStack(spacing: 1) {
                    Text(timeString)
                        .font(.system(size: 22, weight: .semibold, design: .monospaced))
                        .foregroundStyle(pomodoro.phase.isIdle ? Color(white: 0.3) : .white)

                    Text(pomodoro.phase.label.uppercased())
                        .font(.system(size: 7, weight: .semibold))
                        .foregroundStyle(accent.opacity(pomodoro.phase.isIdle ? 0.4 : 0.8))
                        .kerning(1.2)
                }
            }

            HStack(spacing: 6) {
                ForEach(0..<pomodoro.sessionsBeforeLong, id: \.self) { i in
                    let filled = pomodoro.sessionDots.indices.contains(i) && pomodoro.sessionDots[i]
                    Circle()
                        .fill(filled ? accent : Color(white: 0.14))
                        .frame(width: 7, height: 7)
                        .overlay(Circle().stroke(filled ? .clear : Color(white: 0.22), lineWidth: 0.5))
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Controls Column

    private var controlsColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Session count + settings gear
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(pomodoro.completedSessions)")
                        .font(.system(size: 26, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                    Text("sessions")
                        .font(.system(size: 9))
                        .foregroundStyle(Color(white: 0.32))
                }

                Spacer()

                if pomodoro.phase.isIdle {
                    Button { showSettings.toggle() } label: {
                        Image(systemName: showSettings ? "xmark" : "gearshape")
                            .font(.system(size: 10))
                            .foregroundStyle(showSettings ? accent : Color(white: 0.3))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 8)

            Text(nextPhaseHint)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(accent.opacity(0.6))
                .padding(.bottom, 10)

            // ── Linked task ──────────────────────────────────
            linkedTaskSection
                .padding(.bottom, 10)
            // ─────────────────────────────────────────────────

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                if pomodoro.phase.isIdle {
                    FocusButton(label: "Start", icon: "play.fill", color: accent) { pomodoro.start() }
                } else if pomodoro.isPaused {
                    FocusButton(label: "Resume", icon: "play.fill", color: accent) { pomodoro.resume() }
                    FocusButton(label: "Stop", icon: "stop.fill", color: Color(white: 0.25)) { pomodoro.stop() }
                } else {
                    FocusButton(label: "Pause", icon: "pause.fill", color: accent) { pomodoro.pause() }
                    FocusButton(label: "Skip", icon: "forward.fill", color: Color(white: 0.25)) { pomodoro.skip() }
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Linked Task Section

    @ViewBuilder
    private var linkedTaskSection: some View {
        let pending = taskStore.pending

        if let task = pomodoro.currentTask {
            // Task is linked — show it with unlink + done buttons
            HStack(spacing: 6) {
                // Priority color bar
                RoundedRectangle(cornerRadius: 1)
                    .fill(priorityColor(task.priority))
                    .frame(width: 2, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Working on")
                        .font(.system(size: 8))
                        .foregroundStyle(Color(white: 0.32))
                    Text(task.title)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                }

                Spacer(minLength: 4)

                VStack(spacing: 4) {
                    // Mark done
                    Button {
                        taskStore.toggle(task)
                        pomodoro.currentTaskId = nil
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color(red: 0.27, green: 0.75, blue: 0.43))
                    }
                    .buttonStyle(.plain)
                    .help("Mark done")

                    // Unlink
                    Button { pomodoro.currentTaskId = nil } label: {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 11))
                            .foregroundStyle(Color(white: 0.28))
                    }
                    .buttonStyle(.plain)
                    .help("Unlink task")
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color(white: 0.07)))

        } else if pomodoro.phase.isIdle && !pending.isEmpty {
            // Idle + no task linked — show picker
            Menu {
                ForEach(pending) { task in
                    Button {
                        pomodoro.currentTaskId = task.id
                    } label: {
                        Label(task.title, systemImage: priorityIcon(task.priority))
                    }
                }
                Divider()
                Button("No task", role: .destructive) { pomodoro.currentTaskId = nil }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "link")
                        .font(.system(size: 9))
                        .foregroundStyle(Color(white: 0.30))
                    Text("Link a task…")
                        .font(.system(size: 10))
                        .foregroundStyle(Color(white: 0.30))
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 7))
                        .foregroundStyle(Color(white: 0.22))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color(white: 0.07)))
            }
            .buttonStyle(.plain)
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)

        } else if !pomodoro.phase.isIdle {
            // Active session, no task — subtle prompt
            Text("no task linked")
                .font(.system(size: 9))
                .foregroundStyle(Color(white: 0.20))
        }
    }

    private func priorityColor(_ priority: TaskPriority) -> Color {
        switch priority {
        case .high:   return Color(red: 0.91, green: 0.32, blue: 0.27)
        case .medium: return Color(red: 1.0,  green: 0.62, blue: 0.04)
        case .low:    return Color(white: 0.28)
        }
    }

    private func priorityIcon(_ priority: TaskPriority) -> String {
        switch priority {
        case .high:   return "exclamationmark.circle.fill"
        case .medium: return "minus.circle.fill"
        case .low:    return "circle"
        }
    }
}

// MARK: - Settings Panel

private struct SettingsPanel: View {
    let pomodoro: PomodoroManager

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Session config")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color(white: 0.35))
                    .kerning(0.5)
                Spacer()
            }

            HStack(spacing: 8) {
                DurationStepper(
                    label: "Focus",
                    value: Binding(get: { pomodoro.focusMinutes }, set: { pomodoro.focusMinutes = $0 }),
                    range: 5...90,
                    step: 5,
                    accent: Color(red: 0.48, green: 0.70, blue: 0.91)
                )

                Rectangle().fill(Color(white: 0.1)).frame(width: 1).padding(.vertical, 2)

                DurationStepper(
                    label: "Short",
                    value: Binding(get: { pomodoro.shortBreakMinutes }, set: { pomodoro.shortBreakMinutes = $0 }),
                    range: 1...30,
                    step: 1,
                    accent: Color(red: 0.27, green: 0.75, blue: 0.50)
                )

                Rectangle().fill(Color(white: 0.1)).frame(width: 1).padding(.vertical, 2)

                DurationStepper(
                    label: "Long",
                    value: Binding(get: { pomodoro.longBreakMinutes }, set: { pomodoro.longBreakMinutes = $0 }),
                    range: 5...60,
                    step: 5,
                    accent: Color(red: 0.27, green: 0.75, blue: 0.50)
                )

                Rectangle().fill(Color(white: 0.1)).frame(width: 1).padding(.vertical, 2)

                DurationStepper(
                    label: "Sets",
                    value: Binding(get: { pomodoro.sessionsBeforeLong }, set: { pomodoro.sessionsBeforeLong = $0 }),
                    range: 2...8,
                    step: 1,
                    accent: Color(white: 0.45)
                )
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(white: 0.06)))
    }
}

private struct DurationStepper: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let accent: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 8))
                .foregroundStyle(Color(white: 0.32))

            Text("\(value)m")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(accent)

            HStack(spacing: 4) {
                Button {
                    if value - step >= range.lowerBound { value -= step }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(Color(white: 0.3))
                }
                .buttonStyle(.plain)

                Button {
                    if value + step <= range.upperBound { value += step }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(Color(white: 0.3))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Button

private struct FocusButton: View {
    let label: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 8, weight: .semibold))
                Text(label).font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(color.opacity(0.1))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(color.opacity(0.2), lineWidth: 0.5))
            )
        }
        .buttonStyle(.plain)
    }
}
