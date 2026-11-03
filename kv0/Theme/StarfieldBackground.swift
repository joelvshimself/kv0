import SwiftUI

/// Near-black sky with sparse bone stars and Nova's two faint radial glows.
/// Seeded so the sky is the same on every launch.
struct StarfieldBackground: View {
    var body: some View {
        ZStack {
            Nova.void

            RadialGradient(colors: [Nova.rust.opacity(0.12), .clear],
                           center: UnitPoint(x: 0.2, y: 0.3), startRadius: 0, endRadius: 360)
            RadialGradient(colors: [Nova.ember.opacity(0.10), .clear],
                           center: UnitPoint(x: 0.8, y: 0.7), startRadius: 0, endRadius: 380)

            Canvas { context, size in
                var rng = SeededRandom(seed: 0x6E6F7661)
                for _ in 0..<90 {
                    let r = 0.3 + pow(rng.next(), 3) * 1.4
                    let rect = CGRect(x: rng.next() * size.width, y: rng.next() * size.height,
                                      width: r * 2, height: r * 2)
                    context.fill(Path(ellipseIn: rect),
                                 with: .color(Nova.bone.opacity(0.15 + rng.next() * 0.45)))
                }
            }
        }
        .drawingGroup()
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// Nova's frosted card: 20pt radius, white at 3% over a light blur, hairline edge.
struct GlassCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Space.cardRadius, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(0.35))
                    .background(
                        RoundedRectangle(cornerRadius: Space.cardRadius, style: .continuous)
                            .fill(Color.white.opacity(0.03))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: Space.cardRadius, style: .continuous)
                    .strokeBorder(Nova.hairline, lineWidth: 1)
            )
    }
}

struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> CGFloat {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat(state >> 33) / CGFloat(UInt32.max >> 1)
    }
}
