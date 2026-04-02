import SwiftUI

/// The black pill that visually extends the hardware notch downward.
/// Top edge is flush with the screen top (blends with real notch).
/// Bottom corners are rounded to create the pill shape.
struct NotchShape: Shape {
    var bottomCornerRadius: CGFloat = 12

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r = bottomCornerRadius
        // Start top-left — no rounding (flush with bezel)
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        // Bottom-left ear (concave curve outward, like boring.notch)
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + r, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        // Bottom straight
        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        // Bottom-right ear
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + r),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct NotchPillView: View {
    var body: some View {
        ZStack {
            // Black fill — blends with the real hardware notch above
            NotchShape()
                .fill(.black)

            // Mini-Maximus eyes
            HStack(spacing: 8) {
                Circle().fill(.white.opacity(0.85)).frame(width: 5, height: 5)
                Circle().fill(.white.opacity(0.85)).frame(width: 5, height: 5)
            }
            // Push eyes toward the bottom of the pill
            .padding(.top, 8)
        }
    }
}

#Preview {
    NotchPillView()
        .frame(width: 180, height: 44)
        .background(.gray)
}
