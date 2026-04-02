import SwiftUI

struct PanelContentView: View {
    @State private var selectedTab: PanelTab = .project

    var body: some View {
        VStack(spacing: 0) {
            ActionBar(selectedTab: $selectedTab)

            Spacer()

            Text(selectedTab.rawValue)
                .foregroundStyle(.white.opacity(0.3))
                .font(.system(size: 13))

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    PanelContentView()
        .frame(width: 400, height: 500)
}
