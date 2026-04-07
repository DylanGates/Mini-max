import SwiftUI

/// Flat-top, rounded-bottom rectangle — matches the macOS notch geometry.
/// Top edge is flush with the screen bezel (hardware handles the blend).
/// Bottom corners are rounded with `bottomCornerRadius`.
struct NotchShape: Shape {
    var bottomCornerRadius: CGFloat = 10

    var animatableData: CGFloat {
        get { bottomCornerRadius }
        set { bottomCornerRadius = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let r = bottomCornerRadius
        var p = Path()
        p.move(to:    CGPoint(x: rect.minX,     y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX,     y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX,     y: rect.maxY - r))
        p.addQuadCurve(to:      CGPoint(x: rect.maxX - r, y: rect.maxY),
                       control: CGPoint(x: rect.maxX,     y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        p.addQuadCurve(to:      CGPoint(x: rect.minX,     y: rect.maxY - r),
                       control: CGPoint(x: rect.minX,     y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Pill View

struct NotchPillView: View {
    var body: some View {
        ZStack {
            NotchShape(bottomCornerRadius: 10)
                .fill(.black)

            HStack(spacing: 10) {
                Capsule().fill(.white.opacity(0.72)).frame(width: 6, height: 6)
                Capsule().fill(.white.opacity(0.72)).frame(width: 6, height: 6)
            }
            .padding(.bottom, 3)
        }
    }
}

#Preview {
    NotchPillView()
        .frame(width: 200, height: 48)
        .background(Color(white: 0.2))
}
