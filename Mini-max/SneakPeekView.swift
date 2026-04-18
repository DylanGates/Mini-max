import SwiftUI

struct SneakPeekView: View {
    let nudge: Nudge
    var onDismiss: (() -> Void)? = nil

    private func message(for nudge: Nudge) -> String {
        switch nudge {
        case .streakAtRisk: return "⚠️ Streak at risk — commit today"
        case .overdueTask(let count): return "\(count) overdue task\(count == 1 ? "" : "s") — take a moment"
        case .endOfDay: return "🕔 End of day — wrap up & reflect"
        case .morningBrief: return "☀️ Morning brief ready — check Home"
        }
    }

    var body: some View {
        HStack {
            Text(message(for: nudge))
                .font(.system(size: 11))
                .foregroundStyle(Color(white: 0.96))
                .lineLimit(2)
            Spacer()
            Button(action: { onDismiss?() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(white: 0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(Color.black.opacity(0.85))
        .cornerRadius(10)
    }
}
