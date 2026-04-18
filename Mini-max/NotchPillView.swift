import SwiftUI

// MARK: - NotchShape
/// Flat-top, rounded-bottom rectangle matching macOS notch geometry.
/// Uses proper circular arcs (addArc) instead of quadratic curves so the
/// bottom corners are smooth circular fillets — identical to the hardware notch.
///
/// `bottomCornerRadius` — convex fillet on the two bottom corners.
/// `outerCornerRadius`  — concave shoulder flare where the notch meets the
///                        menu bar. Set to 0 for a clean flat top.
/// Both values animate via `AnimatablePair`.
struct NotchShape: Shape {

    var bottomCornerRadius: CGFloat = 10
    var outerCornerRadius:  CGFloat = 6

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(bottomCornerRadius, outerCornerRadius) }
        set { bottomCornerRadius = newValue.first; outerCornerRadius = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        let br = max(bottomCornerRadius, 0)
        let or = max(outerCornerRadius,  0)
        var p  = Path()

        if or > 0 {
            // ── With concave shoulder flare ──────────────────────────────────
            // Top-left: begin just inside the shoulder
            p.move(to: CGPoint(x: rect.minX + or, y: rect.minY))

            // Top edge
            p.addLine(to: CGPoint(x: rect.maxX - or, y: rect.minY))

            // Top-right concave shoulder
            p.addArc(
                center:     CGPoint(x: rect.maxX + or, y: rect.minY + or),
                radius:     or * 1.414,
                startAngle: .degrees(225),
                endAngle:   .degrees(270),
                clockwise:  false
            )

            // Right edge
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))

            // Bottom-right convex corner
            p.addArc(
                center:     CGPoint(x: rect.maxX - br, y: rect.maxY - br),
                radius:     br,
                startAngle: .degrees(0),
                endAngle:   .degrees(90),
                clockwise:  false
            )

            // Bottom edge
            p.addLine(to: CGPoint(x: rect.minX + br, y: rect.maxY))

            // Bottom-left convex corner
            p.addArc(
                center:     CGPoint(x: rect.minX + br, y: rect.maxY - br),
                radius:     br,
                startAngle: .degrees(90),
                endAngle:   .degrees(180),
                clockwise:  false
            )

            // Left edge
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + or))

            // Top-left concave shoulder
            p.addArc(
                center:     CGPoint(x: rect.minX - or, y: rect.minY + or),
                radius:     or * 1.414,
                startAngle: .degrees(270),
                endAngle:   .degrees(315),
                clockwise:  false
            )

        } else {
            // ── Clean flat top, no shoulder ──────────────────────────────────
            p.move(to:    CGPoint(x: rect.minX,      y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX,      y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX,      y: rect.maxY - br))

            p.addArc(
                center:     CGPoint(x: rect.maxX - br, y: rect.maxY - br),
                radius:     br,
                startAngle: .degrees(0),
                endAngle:   .degrees(90),
                clockwise:  false
            )

            p.addLine(to: CGPoint(x: rect.minX + br, y: rect.maxY))

            p.addArc(
                center:     CGPoint(x: rect.minX + br, y: rect.maxY - br),
                radius:     br,
                startAngle: .degrees(90),
                endAngle:   .degrees(180),
                clockwise:  false
            )

            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        }

        p.closeSubpath()
        return p
    }
}

// MARK: - NotchPillView
/// Notch-shaped black pill. Eyes are composed by the caller via an overlay
/// so this view has zero dependency on MiniMaxEyes or EyeMood.
///
/// Usage:
///   NotchPillView()
///     .frame(width: 180, height: 40)
///     .overlay { MiniMaxEyes(mood: currentMood).padding(.bottom, 3) }
struct NotchPillView: View {

    var bottomCornerRadius: CGFloat = 10
    var outerCornerRadius:  CGFloat = 6

    var body: some View {
        NotchShape(
            bottomCornerRadius: bottomCornerRadius,
            outerCornerRadius:  outerCornerRadius
        )
        .fill(.black)
    }
}

// MARK: - Previews

#Preview("Pill — no shoulder") {
    NotchPillView(outerCornerRadius: 0)
        .frame(width: 180, height: 40)
        .background(Color(white: 0.2))
}

#Preview("Pill — with shoulder") {
    NotchPillView(outerCornerRadius: 6)
        .frame(width: 180, height: 40)
        .background(Color(white: 0.2))
}

#Preview("Animated expand") {
    AnimatedExpandPreview()
}

private struct AnimatedExpandPreview: View {
    @State private var expanded = false
    var body: some View {
        VStack(spacing: 20) {
            NotchShape(
                bottomCornerRadius: expanded ? 20 : 6,
                outerCornerRadius:  expanded ? 10 : 4
            )
            .fill(.black)
            .frame(
                width:  expanded ? 320 : 180,
                height: expanded ? 80  : 40
            )
            .animation(.spring(response: 0.5, dampingFraction: 0.72), value: expanded)

            Button(expanded ? "collapse" : "expand") { expanded.toggle() }
        }
        .padding(40)
        .background(Color(white: 0.2))
    }
}