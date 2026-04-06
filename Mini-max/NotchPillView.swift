import SwiftUI

/// Black notch pill shape.
///
/// Coordinate system (SwiftUI): y=0 at top, y=maxY at bottom.
/// - Top edge is flat — flush with the hardware bezel above.
/// - Bottom corners are rounded with `bottomCornerRadius`.
/// - When `outerGutterRadius > 0`, concave outer-blend curves are drawn
///   on each side of the bottom corners, seamlessly connecting the pill
///   wall to the flat display surface below the notch.
///   The view rect is expected to be wider than the notch by `outerGutterRadius`
///   on each side so the gutter curves have room to render.
struct NotchShape: Shape {
    var bottomCornerRadius: CGFloat = 10
    var outerGutterRadius:  CGFloat = 0

    // Animate both radii so collapsed ↔ expanded transitions are smooth.
    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(bottomCornerRadius, outerGutterRadius) }
        set { bottomCornerRadius = newValue.first; outerGutterRadius = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        let r = bottomCornerRadius
        let g = outerGutterRadius

        var p = Path()

        // ── Top edge (full window width) ──────────────────────────────────
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))

        // ── Right outer wall ─────────────────────────────────────────────
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))

        if g > 0 {
            // RIGHT OUTER GUTTER — concave blend from display surface into pill
            // Cubic bezier derived from the design reference (normalized):
            //   CP1 ≈ (1 - 0.024, 0.794)  → pulling near outer edge, slightly inward
            //   CP2 ≈ (1 - 0.256, 1.004)  → pulling near pill corner, at display level
            //   End:  pill right wall, r above display surface
            let pillMaxX = rect.maxX - g
            let cp1 = CGPoint(x: rect.maxX - g * 0.024, y: rect.maxY - g * 0.794)
            let cp2 = CGPoint(x: rect.maxX - g * 0.256, y: rect.maxY)
            p.addCurve(to: CGPoint(x: pillMaxX, y: rect.maxY - r),
                       control1: cp1, control2: cp2)
        } else {
            // No gutter — straight down to inner corner start
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        }

        // BOTTOM-RIGHT inner rounded corner of pill
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX - g - r, y: rect.maxY),
            control: CGPoint(x: rect.maxX - g, y: rect.maxY)
        )

        // ── Pill bottom edge ──────────────────────────────────────────────
        p.addLine(to: CGPoint(x: rect.minX + g + r, y: rect.maxY))

        // BOTTOM-LEFT inner rounded corner of pill
        p.addQuadCurve(
            to: CGPoint(x: rect.minX + g, y: rect.maxY - r),
            control: CGPoint(x: rect.minX + g, y: rect.maxY)
        )

        if g > 0 {
            // LEFT OUTER GUTTER — mirror of right gutter
            let cp1 = CGPoint(x: rect.minX + g * 0.256, y: rect.maxY)
            let cp2 = CGPoint(x: rect.minX + g * 0.024, y: rect.maxY - g * 0.794)
            p.addCurve(to: CGPoint(x: rect.minX, y: rect.maxY),
                       control1: cp1, control2: cp2)
        }

        // ── Left outer wall back to top ───────────────────────────────────
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Pill View

/// The always-visible collapsed notch pill.
/// Renders the shape + mini-max eyes. Window must extend `outerGutterRadius`
/// beyond the hardware notch on each side for the gutter curves to be visible.
struct NotchPillView: View {
    var body: some View {
        ZStack {
            NotchShape(bottomCornerRadius: 10, outerGutterRadius: 10)
                .fill(.black)

            HStack(spacing: 10) {
                Capsule()
                    .fill(.white.opacity(0.75))
                    .frame(width: 6, height: 6)
                Capsule()
                    .fill(.white.opacity(0.75))
                    .frame(width: 6, height: 6)
            }
            .padding(.bottom, 3)
        }
    }
}

#Preview {
    // Grey bg = screen; black pill + gutters on each side
    NotchPillView()
        .frame(width: 200, height: 48)   // 180 notch + 10 gutter each side
        .background(Color(white: 0.2))
}
