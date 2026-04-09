import SwiftUI

// MARK: - Eye size

enum EyeSize {
    case regular   // 14×8pt per eye, 5pt gap
    case small     // 9×5pt per eye, 3pt gap
}

// MARK: - MiniMaxEyes

/// Animated pair of Baymax-style capsule eyes.
/// Drop-in overlay: `MiniMaxEyes(onTap: { })`.
/// State is driven by InsightEngine.shared (@Observable — no manual wiring needed).
struct MiniMaxEyes: View {
    var size  : EyeSize        = .regular
    var onTap : (() -> Void)?  = nil

    // Continuous animation drivers — both start in .onAppear and loop forever
    @State private var float  = false   // Y offset oscillation (idle only)
    @State private var glow   = false   // opacity / shadow pulse (loading only)
    @State private var tapped = false   // scale spring on tap

    var body: some View {
        let engine          = InsightEngine.shared
        let loading         = engine.isLoading
        let errored         = engine.lastError != nil
        let (w, h, gap)     = size == .regular ? (14.0, 8.0, 5.0) : (9.0, 5.0, 3.0)

        HStack(spacing: gap) {
            eye(w: w, h: h)
            eye(w: w, h: h)
        }
        // ── Opacity ────────────────────────────────────────────────
        // error  → 40% fixed
        // loading → pulses 0.3 ↔ 1.0  (glow bool drives interpolation)
        // idle   → full 1.0
        .opacity(
            errored  ? 0.4 :
            loading  ? (glow ? 1.0 : 0.3) :
            1.0
        )
        // ── Glow shadow ────────────────────────────────────────────
        // error  → none
        // loading → pulses radius 4, opacity 0.4
        // idle   → constant radius 3, opacity 0.25
        .shadow(
            color: errored ? .clear : .white.opacity(loading ? (glow ? 0.4 : 0.05) : 0.25),
            radius: loading ? 4 : 3
        )
        // ── Float offset ───────────────────────────────────────────
        // error  → +1 (drooped)
        // loading → locked at 0
        // idle   → oscillates −2 ↔ +2
        .offset(y: errored ? 1 : (loading ? 0 : (float ? -2 : 2)))
        // ── Tap spring ─────────────────────────────────────────────
        .scaleEffect(tapped ? 0.88 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.5), value: tapped)
        .onTapGesture {
            guard let onTap else { return }
            tapped = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { tapped = false }
            onTap()
        }
        // ── Start continuous animations once ───────────────────────
        // Both run forever. Which expression they feed into switches when
        // engine.isLoading / engine.lastError changes — no animation restart needed.
        .onAppear {
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { glow  = true }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { float = true }
        }
    }

    // MARK: - Eye capsule

    @ViewBuilder
    private func eye(w: CGFloat, h: CGFloat) -> some View {
        Capsule()
            .fill(.white)
            .frame(width: w, height: h)
    }
}
