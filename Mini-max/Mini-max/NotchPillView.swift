import SwiftUI

struct NotchPillView: View {
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(.white)
                .frame(width: 6, height: 6)
            Circle()
                .fill(.white)
                .frame(width: 6, height: 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    NotchPillView()
        .frame(width: 120, height: 32)
        .background(.black)
}
