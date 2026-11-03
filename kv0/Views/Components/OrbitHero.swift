import SwiftUI

/// The hero number sitting inside Nova's dashed orbits. The orange planet travels the outer
/// orbit with the time of day; a grey moon keeps the inner ring company.
struct OrbitHero: View {
    let snapshot: DaySnapshot

    private let orbits: [CGFloat] = [340, 250, 160]

    private var dayProgress: Double {
        (snapshot.nowHour - snapshot.dayStart) / (snapshot.dayEnd - snapshot.dayStart)
    }

    var body: some View {
        ZStack {
            ForEach(orbits, id: \.self) { diameter in
                Circle()
                    .stroke(Nova.orange.opacity(0.35),
                            style: StrokeStyle(lineWidth: 1, dash: [3, 5]))
                    .frame(width: diameter, height: diameter)
            }

            satellite(on: orbits[0], angle: dayProgress * 2 * .pi - .pi / 2) {
                Circle()
                    .fill(Nova.ember)
                    .frame(width: 18, height: 18)
                    .shadow(color: Nova.orange.opacity(0.7), radius: 10)
            }
            satellite(on: orbits[1], angle: dayProgress * 2 * .pi + .pi * 0.7) {
                Circle().fill(Nova.surface).frame(width: 26, height: 26)
            }
            satellite(on: orbits[2], angle: -dayProgress * 2 * .pi + .pi * 0.15) {
                Circle().fill(Nova.orange).frame(width: 6, height: 6)
            }

            VStack(spacing: 0) {
                Text(snapshot.heroText)
                    .font(Typeface.hero)
                    .tracking(Typeface.tracking(for: 140))
                    .foregroundStyle(Nova.bone)
                    .contentTransition(.numericText(value: snapshot.heroValue))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(snapshot.heroLabel)
                    .font(Typeface.body)
                    .foregroundStyle(Nova.bone.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 200)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: orbits[0] + 20)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(snapshot.heroText) \(snapshot.heroLabel)")
    }

    private func satellite<Planet: View>(on diameter: CGFloat, angle: Double,
                                    @ViewBuilder planet: () -> Planet) -> some View {
        planet()
            .offset(x: cos(angle) * diameter / 2, y: sin(angle) * diameter / 2)
    }
}
