import SwiftUI

/// Procedural kozo paper: long soft fibres, fine grain and a few sumi specks.
/// Seeded so the sheet looks the same on every launch.
struct WashiBackground: View {
    var body: some View {
        Canvas { context, size in
            var rng = SeededRandom(seed: 0x6B7630)
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Ink.washi))

            for _ in 0..<1400 {
                let x = rng.next() * size.width
                let y = rng.next() * size.height
                let length = 4 + rng.next() * 22
                let angle = (rng.next() - 0.5) * .pi * 0.35
                let bend = (rng.next() - 0.5) * 0.15
                var fibre = Path()
                fibre.move(to: CGPoint(x: x, y: y))
                fibre.addQuadCurve(
                    to: CGPoint(x: x + cos(angle) * length, y: y + sin(angle) * length),
                    control: CGPoint(
                        x: x + cos(angle + bend) * length * 0.5,
                        y: y + sin(angle + bend) * length * 0.5
                    )
                )
                let tone = rng.next() > 0.5 ? Ink.washiDeep : Color.white
                context.stroke(fibre, with: .color(tone.opacity(0.35 + rng.next() * 0.4)),
                               lineWidth: 0.4 + rng.next() * 0.8)
            }

            for _ in 0..<4000 {
                let rect = CGRect(x: rng.next() * size.width, y: rng.next() * size.height,
                                  width: 1, height: 1)
                context.fill(Path(rect), with: .color(Ink.inkSoft.opacity(0.04 + rng.next() * 0.05)))
            }

            for _ in 0..<14 {
                let r = 0.4 + rng.next() * 1.1
                let rect = CGRect(x: rng.next() * size.width, y: rng.next() * size.height,
                                  width: r * 2, height: r * 2)
                context.fill(Path(ellipseIn: rect), with: .color(Ink.sumi.opacity(0.25)))
            }
        }
        .drawingGroup()
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// A single tapered stroke used as the only divider on the page.
struct BrushRule: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            let mid = size.height / 2
            path.move(to: CGPoint(x: 0, y: mid))
            path.addCurve(
                to: CGPoint(x: size.width, y: mid - 0.6),
                control1: CGPoint(x: size.width * 0.3, y: mid - 1.4),
                control2: CGPoint(x: size.width * 0.7, y: mid + 1.0)
            )
            context.stroke(path, with: .linearGradient(
                Gradient(colors: [Ink.sumi.opacity(0.55), Ink.sumi.opacity(0.05)]),
                startPoint: .zero, endPoint: CGPoint(x: size.width, y: 0)
            ), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
        }
        .frame(height: 4)
        .accessibilityHidden(true)
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
