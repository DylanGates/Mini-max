import SwiftUI

/// Black notch pill shape.
/// In SwiftUI coords: minY = top of view (flush with screen bezel, NO rounding)
///                    maxY = bottom of view (rounded corners, visible below hardware notch)
struct NotchShape: Shape {
    var bottomCornerRadius: CGFloat = 10

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r = bottomCornerRadius
        // Flat top-left corner (flush with screen bezel above)
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        // Flat across the top
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        // Right side straight down to bottom-right curve start
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        // Bottom-right rounded corner
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - r, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        // Bottom straight across
        path.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        // Bottom-left rounded corner
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - r),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        // Left side back up
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

/// The always-visible notch pill.
/// Black fill blends with the hardware notch bezel above it.
/// Mini-Maximus eyes sit inside.
struct NotchPillView: View {
    var body: some View {
        ZStack {
            NotchShape()
                .fill(.black)

            HStack(spacing: 8) {
                Circle().fill(.white.opacity(0.8)).frame(width: 5, height: 5)
                Circle().fill(.white.opacity(0.8)).frame(width: 5, height: 5)
            }
            .padding(.bottom, 4)
        }
    }
}

#Preview {
    // Simulate how it looks: grey background = screen, black pill = notch extension
    NotchPillView()
        .frame(width: 180, height: 44)
        .background(Color(white: 0.15))
}
