import SwiftUI

enum PanelTab: String, CaseIterable {
    case project = "Projects"
    case pomodoro = "Focus"
    case github = "GitHub"
    case ai = "AI"

    var icon: String {
        switch self {
        case .project: return "folder"
        case .pomodoro: return "timer"
        case .github: return "chevron.left.forwardslash.chevron.right"
        case .ai: return "bubble.left"
        }
    }
}

struct ActionBar: View {
    @Binding var selectedTab: PanelTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(PanelTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 14))
                        Text(tab.rawValue)
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(selectedTab == tab ? .white : .white.opacity(0.4))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
        }
        .background(.black.opacity(0.6))
    }
}

#Preview {
    ActionBar(selectedTab: .constant(.project))
        .frame(width: 400)
}
