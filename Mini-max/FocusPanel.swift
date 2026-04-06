import SwiftUI

struct FocusPanel: View {
    private let pomodoro = PomodoroManager.shared

    private var timeString: String {
        let secs = Int(pomodoro.phase.remaining)
        return String(format: "%02d:%02d", secs / 60, secs % 60)
    }

    private var progress: Double {
        let total: TimeInterval
        switch pomodoro.phase {
        case .focus:      total = pomodoro.focusDuration
        case .shortBreak: total = pomodoro.shortBreakDuration
        case .longBreak:  total = pomodoro.longBreakDuration
        case .idle:       return 0
        }
        return 1 - (pomodoro.phase.remaining / total)
    }

    private var accent: Color {
        switch pomodoro.phase {
        case .focus:                return Color(red: 0.48, green: 0.70, blue: 0.91)
        case .shortBreak, .longBreak: return Color(red: 0.27, green: 0.75, blue: 0.43)
        case .idle:                 return Color(white: 0.3)
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            timerRing
            controls
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Ring

    private var timerRing: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(Color(white: 0.12), lineWidth: 6)
                    .frame(width: 90, height: 90)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 90, height: 90)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)

                VStack(spacing: 2) {
                    Text(timeString)
                        .font(.system(size: 20, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                    Text(pomodoro.phase.label)
                        .font(.system(size: 9))
                        .foregroundStyle(Color(white: 0.4))
                }
            }

            // Session dots
            HStack(spacing: 5) {
                ForEach(0..<4, id: \.self) { i in
                    Circle()
                        .fill(pomodoro.sessionDots.indices.contains(i) && pomodoro.sessionDots[i]
                              ? accent : Color(white: 0.18))
                        .frame(width: 6, height: 6)
                }
            }
        }
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Focus Timer")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)

            Text("\(pomodoro.completedSessions) sessions completed")
                .font(.system(size: 10))
                .foregroundStyle(Color(white: 0.4))

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                if pomodoro.phase.isIdle {
                    FocusButton(label: "Start", icon: "play.fill", color: accent) {
                        pomodoro.start()
                    }
                } else if pomodoro.isPaused {
                    FocusButton(label: "Resume", icon: "play.fill", color: accent) {
                        pomodoro.resume()
                    }
                    FocusButton(label: "Stop", icon: "stop.fill", color: Color(white: 0.3)) {
                        pomodoro.stop()
                    }
                } else {
                    FocusButton(label: "Pause", icon: "pause.fill", color: accent) {
                        pomodoro.pause()
                    }
                    FocusButton(label: "Skip", icon: "forward.fill", color: Color(white: 0.3)) {
                        pomodoro.skip()
                    }
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct FocusButton: View {
    let label: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 9))
                Text(label).font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 6).fill(color.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }
}
