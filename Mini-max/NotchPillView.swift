import SwiftUI

/// Notch shape with optional outer blend curves.
///
/// Coordinate system: y=0 at top (screen bezel), y=maxY at bottom.
///
/// When `outerGutterRadius > 0`, the window rect must be wider than the pill
/// by `outerGutterRadius` on each side. The extra space is filled with concave
/// anti-corner fillets — matching the chamfer Apple uses on real notch hardware.
///
/// Anti-corner geometry (right side):
///   wall arrives at  (maxX, maxY − g)   ← downward tangent
///   quad control:    (maxX, maxY)        ← outer corner
///   lands at         (pMaxX, maxY)       ← leftward tangent
///
/// That single quad control point ensures C1 continuity at both endpoints.
struct NotchShape: Shape {
    var bottomCornerRadius: CGFloat = 10
    var outerGutterRadius:  CGFloat = 0

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(bottomCornerRadius, outerGutterRadius) }
        set { bottomCornerRadius = newValue.first; outerGutterRadius = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        let r = bottomCornerRadius
        let g = outerGutterRadius

        // When g≈0 the anti-corner segments collapse and self-intersect,
        // punching transparent holes via even-odd winding. Use a plain
        // flat-top / rounded-bottom rect instead.
        if g < 0.5 {
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

        let pMinX = rect.minX + g  // pill left wall
        let pMaxX = rect.maxX - g  // pill right wall

        var p = Path()

        // ─── Top edge (full window width, flush with screen bezel) ────────
        p.move(to:    CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))

        // ─── Right: wall → anti-corner → pill inner corner → up ──────────

        // Right outer wall down to anti-corner zone
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - g))

        // Right outer anti-corner (concave fillet, g radius)
        p.addQuadCurve(
            to:      CGPoint(x: pMaxX,     y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )

        // Pill bottom — right segment before inner corner
        p.addLine(to: CGPoint(x: pMaxX - r, y: rect.maxY))

        // Pill bottom-right inner corner (convex, r radius)
        p.addQuadCurve(
            to:      CGPoint(x: pMaxX, y: rect.maxY - r),
            control: CGPoint(x: pMaxX, y: rect.maxY)
        )

        // Pill right wall up to top
        p.addLine(to: CGPoint(x: pMaxX, y: rect.minY))

        // ─── Inner top bridge (inside the notch, hidden by bezel above) ──
        p.addLine(to: CGPoint(x: pMinX, y: rect.minY))

        // ─── Left: down → pill inner corner → anti-corner → wall ─────────

        // Pill left wall down to inner corner zone
        p.addLine(to: CGPoint(x: pMinX, y: rect.maxY - r))

        // Pill bottom-left inner corner (convex, r radius)
        p.addQuadCurve(
            to:      CGPoint(x: pMinX + r, y: rect.maxY),
            control: CGPoint(x: pMinX,     y: rect.maxY)
        )

        // Pill bottom — left segment after inner corner
        p.addLine(to: CGPoint(x: pMinX, y: rect.maxY))

        // Left outer anti-corner (concave fillet, g radius)
        p.addQuadCurve(
            to:      CGPoint(x: rect.minX, y: rect.maxY - g),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )

        // Left outer wall up to top
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))

        p.closeSubpath()
        return p
    }
}

// MARK: - Pill View

struct NotchPillView: View {
    var body: some View {
        ZStack {
            NotchShape(bottomCornerRadius: 10, outerGutterRadius: 10)
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
